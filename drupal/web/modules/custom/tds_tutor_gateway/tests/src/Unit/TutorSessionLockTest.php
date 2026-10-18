<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_tutor_gateway\Unit;

use Drupal\Core\Session\SessionConfigurationInterface;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_tutor_gateway\Lock\SessionMutexInterface;
use Drupal\tds_tutor_gateway\StackMiddleware\TutorSessionLock;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\Session\SessionInterface;
use Symfony\Component\HttpKernel\HttpKernelInterface;

/**
 * Reproduces overlapping refresh/logout requests at the persistence boundary.
 */
#[CoversClass(TutorSessionLock::class)]
#[Group('tds_tutor_gateway')]
final class TutorSessionLockTest extends UnitTestCase {

  /**
   * B cannot read while A owns the refresh, and retries only after A persisted.
   */
  public function testConcurrentRefreshReadsPersistedRotation(): void {
    $persisted = 'refresh-old';
    $read = [];
    $refreshes = 0;
    $mutex = $this->mutex();
    $configuration = $this->configuration();
    $requestA = $this->request();
    $requestB = $this->request('https://alias.example.test/private');
    $kernelB = $this->createMock(HttpKernelInterface::class);
    $kernelB->expects(self::once())->method('handle')->willReturnCallback(function () use (&$persisted, &$read): Response {
      $read[] = $persisted;
      return new Response('B');
    });
    $boundaryB = new TutorSessionLock($kernelB, $configuration, static fn () => $mutex);
    $sessionA = $this->createMock(SessionInterface::class);
    $sessionA->method('isStarted')->willReturn(TRUE);
    $sessionA->expects(self::once())->method('save')->willReturnCallback(function () use (&$persisted, $mutex): void {
      self::assertTrue($mutex->held);
      $persisted = 'refresh-new';
    });
    $kernelA = $this->createMock(HttpKernelInterface::class);
    $kernelA->method('handle')->willReturnCallback(function () use (&$read, &$persisted, &$refreshes, $boundaryB, $requestB, $requestA, $sessionA): Response {
      // Drupal initializes/reads the session inside the outer boundary.
      $read[] = $persisted;
      $requestA->setSession($sessionA);
      $refreshes++;
      self::assertSame(503, $boundaryB->handle($requestB)->getStatusCode());
      self::assertSame(['refresh-old'], $read, 'Contending request must not read a snapshot.');
      return new Response('A');
    });
    $boundaryA = new TutorSessionLock($kernelA, $configuration, static fn () => $mutex);
    self::assertSame('A', $boundaryA->handle($requestA)->getContent());
    self::assertSame('B', $boundaryB->handle($requestB)->getContent());
    self::assertSame(['refresh-old', 'refresh-new'], $read);
    self::assertSame(1, $refreshes);
    self::assertFalse($mutex->held);
  }

  /**
   * A waiting request cannot resurrect tokens removed by logout.
   */
  public function testLogoutPersistsBeforeNextRequestReads(): void {
    $persisted = 'refresh-old';
    $mutex = $this->mutex();
    $configuration = $this->configuration();
    $logout = $this->request();
    $session = $this->createMock(SessionInterface::class);
    $session->method('isStarted')->willReturn(TRUE);
    $session->method('save')->willReturnCallback(function () use (&$persisted): void {
      $persisted = NULL;
    });
    $kernel = $this->createMock(HttpKernelInterface::class);
    $kernel->method('handle')->willReturnCallback(function (Request $request) use ($session, &$persisted): Response {
      $request->setSession($session);
      self::assertSame('refresh-old', $persisted);
      return new Response('logged out');
    });
    (new TutorSessionLock($kernel, $configuration, static fn () => $mutex))->handle($logout);
    $reader = $this->createMock(HttpKernelInterface::class);
    $reader->method('handle')->willReturnCallback(function () use (&$persisted): Response {
      self::assertNull($persisted);
      return new Response('session_required', 401);
    });
    self::assertSame(401, (new TutorSessionLock($reader, $configuration, static fn () => $mutex))->handle($this->request())->getStatusCode());
  }

  /**
   * Handler failure still saves an already-rotated token before release.
   */
  public function testExceptionPersistsBeforeRelease(): void {
    $mutex = $this->mutex();
    $request = $this->request();
    $session = $this->createMock(SessionInterface::class);
    $session->method('isStarted')->willReturn(TRUE);
    $session->expects(self::once())->method('save')->willReturnCallback(function () use ($mutex): void {
      self::assertTrue($mutex->held);
    });
    $kernel = $this->createMock(HttpKernelInterface::class);
    $kernel->method('handle')->willReturnCallback(function (Request $request) use ($session): never {
      $request->setSession($session);
      throw new \RuntimeException('private upstream detail');
    });
    $response = (new TutorSessionLock($kernel, $this->configuration(), static fn () => $mutex))->handle($request);
    self::assertSame(503, $response->getStatusCode());
    self::assertStringNotContainsString('private upstream', $response->getContent());
    self::assertFalse($mutex->held);
  }

  /**
   * Backend failure does not initialize the session or invoke any API request.
   */
  public function testLockFailureIsPrivateAndDoesNotReadSession(): void {
    $mutex = $this->createMock(SessionMutexInterface::class);
    $mutex->method('acquire')->willThrowException(new \RuntimeException('database credentials'));
    $mutex->expects(self::never())->method('release');
    $kernel = $this->createMock(HttpKernelInterface::class);
    $kernel->expects(self::never())->method('handle');
    $response = (new TutorSessionLock($kernel, $this->configuration(), static fn () => $mutex))->handle($this->request());
    self::assertSame(503, $response->getStatusCode());
    self::assertTrue($response->headers->hasCacheControlDirective('no-store'));
    self::assertSame('1', $response->headers->get('Retry-After'));
    self::assertStringNotContainsString('credentials', $response->getContent());
  }

  /**
   * Public requests without session cookies do not touch the mutex/database.
   */
  public function testAnonymousBypass(): void {
    $mutex = $this->createMock(SessionMutexInterface::class);
    $mutex->expects(self::never())->method('acquire');
    $kernel = $this->createMock(HttpKernelInterface::class);
    $kernel->expects(self::once())->method('handle')->willReturn(new Response('public'));
    $response = (new TutorSessionLock($kernel, $this->configuration(), static fn () => $mutex))->handle(new Request());
    self::assertSame('public', $response->getContent());
  }

  /**
   * Service construction failure is caught before session initialization.
   */
  public function testProviderConstructionFailure(): void {
    $kernel = $this->createMock(HttpKernelInterface::class);
    $kernel->expects(self::never())->method('handle');
    $provider = static function (): never {
      throw new \RuntimeException('private connection options');
    };
    $boundary = new TutorSessionLock($kernel, $this->configuration(), $provider);
    $response = $boundary->handle($this->request());
    self::assertSame(503, $response->getStatusCode());
    self::assertTrue($response->headers->hasCacheControlDirective('no-store'));
    self::assertStringNotContainsString('private connection', $response->getContent());
  }

  /**
   * Anonymous bypass must not even instantiate a database-dependent service.
   */
  public function testAnonymousDoesNotConstructMutex(): void {
    $kernel = $this->createMock(HttpKernelInterface::class);
    $kernel->method('handle')->willReturn(new Response('public'));
    $provider = static function (): never {
      throw new \RuntimeException('provider must not be constructed');
    };
    $response = (new TutorSessionLock($kernel, $this->configuration(), $provider))->handle(new Request());
    self::assertSame('public', $response->getContent());
  }

  /**
   * Stable synthetic cookie shared across host aliases by explicit site config.
   */
  private function request(string $url = 'https://portal.example.test/private'): Request {
    return Request::create($url, 'GET', [], ['SSESS_site' => 'synthetic-session']);
  }

  /**
   * Session-cookie configuration without booting Drupal's session service.
   */
  private function configuration(): SessionConfigurationInterface {
    $configuration = $this->createMock(SessionConfigurationInterface::class);
    $configuration->method('hasSession')->willReturnCallback(static fn (Request $request): bool => $request->cookies->has('SSESS_site'));
    $configuration->method('getOptions')->willReturn(['name' => 'SSESS_site']);
    return $configuration;
  }

  /**
   * Deterministic independent-request mutex; real DB coverage lives in script.
   */
  private function mutex(): SessionMutexInterface {
    return new class() implements SessionMutexInterface {

      /**
       * Whether another synthetic request owns the mutex.
       *
       * @var bool
       */
      public bool $held = FALSE;

      /**
       * Opaque session key currently held.
       *
       * @var string|null
       */
      private ?string $key = NULL;

      /**
       * {@inheritdoc}
       */
      public function acquire(string $key): bool {
        if ($this->held) {
          TutorSessionLockTest::assertSame($this->key, $key);
          return FALSE;
        }
        $this->held = TRUE;
        $this->key = $key;
        return TRUE;
      }

      /**
       * {@inheritdoc}
       */
      public function release(string $key): void {
        $this->held = FALSE;
      }

    };
  }

}
