<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_support_certificates\Unit;

use Drupal\Core\Lock\LockBackendInterface;
use Drupal\Core\Site\Settings;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_support_certificates\Client\SupportCertificatesClient;
use Drupal\tds_support_certificates\Security\ExternalUrlPolicy;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Session\TutorSessionManagerInterface;
use Drupal\tds_tutor_gateway\Storage\TutorTokenStoreInterface;
use Drupal\tds_tutor_gateway\ValueObject\TutorTokenSet;
use GuzzleHttp\Client;
use GuzzleHttp\Handler\MockHandler;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Middleware;
use GuzzleHttp\Psr7\Response;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\HttpFoundation\Session\Session;
use Symfony\Component\HttpFoundation\Session\Storage\MockArraySessionStorage;

/**
 * HTTP contracts, session isolation, safe fields and failure modes.
 */
#[CoversClass(SupportCertificatesClient::class)]
#[Group('tds_support_certificates')]
final class SupportCertificatesClientTest extends UnitTestCase {

  /**
   * Only own certificate fields survive; unsafe verifier URL is not a link.
   */
  public function testCertificateProjection(): void {
    $record = [
      'id' => 'cert-1',
      'user_id' => 'user-1',
      'issued_at' => '2026-10-15T12:00:00Z',
      'course_title' => 'Curso QA',
      'verification_url' => 'https://verify.example.test/check/code',
      'content_hash' => 'private-hash',
      'holder_name' => 'Private Name',
    ];
    $history = [];
    $client = $this->client(new Response(200, [], json_encode(['certificates' => [$record]], JSON_THROW_ON_ERROR)), $history);
    $expected = [
      'title' => 'Curso QA',
      'issued_at' => $record['issued_at'],
      'verification_url' => $record['verification_url'],
    ];
    self::assertSame([$expected], $client->certificates());
    self::assertSame('/tutor-api/certificates', $history[0]['request']->getUri()->getPath());
    self::assertSame('Bearer rotated-access', $history[0]['request']->getHeaderLine('Authorization'));
    self::assertFalse($history[0]['options']['allow_redirects']);
    $record['verification_url'] = 'https://evil.example.test/check/code';
    $client = $this->client(new Response(200, [], json_encode(['certificates' => [$record]], JSON_THROW_ON_ERROR)), $history);
    self::assertNull($client->certificates()[0]['verification_url']);
  }

  /**
   * Empty API result is authoritative and not an unavailable/stale response.
   */
  public function testEmptyCertificates(): void {
    $history = [];
    self::assertSame([], $this->client(new Response(200, [], '{"certificates":[]}'), $history)->certificates());
  }

  /**
   * Never display records belonging to a different authenticated context.
   */
  public function testDivergentOwner(): void {
    $history = [];
    $this->expectExceptionMessage('certificate_context_mismatch');
    $this->client(new Response(200, [], '{"certificates":[{"user_id":"user-2"}]}'), $history)->certificates();
  }

  /**
   * Signed identity is validated and unknown upstream fields are stripped.
   */
  public function testSignedIdentity(): void {
    $history = [];
    $identity = ['identifier' => 'staging:user-1', 'identifier_hash' => str_repeat('a', 64)];
    $payload = $identity + ['email' => 'private@example.test'];
    self::assertSame($identity, $this->client(new Response(200, [], json_encode($payload, JSON_THROW_ON_ERROR)), $history)->identity());
    self::assertSame('/tutor-api/support/identity', $history[0]['request']->getUri()->getPath());
  }

  /**
   * Missing, malformed or other-user identities fail closed.
   */
  #[DataProvider('invalidIdentities')]
  public function testInvalidIdentity(array $payload): void {
    $history = [];
    $this->expectExceptionMessage('invalid_support_identity');
    $this->client(new Response(200, [], json_encode($payload, JSON_THROW_ON_ERROR)), $history)->identity();
  }

  /**
   * Invalid identity examples.
   */
  public static function invalidIdentities(): array {
    return [
      [['other' => 'field']],
      [['identifier' => 'staging:user-2', 'identifier_hash' => str_repeat('a', 64)]],
      [['identifier' => 'staging:user-1', 'identifier_hash' => 'bad']],
    ];
  }

  /**
   * No retry or upstream payload leak for access, overload and service errors.
   */
  #[DataProvider('failures')]
  public function testFailure(int $upstream, int $expected): void {
    $history = [];
    $client = $this->client(new Response($upstream, [], '{"detail":"SECRET"}'), $history, $upstream === 401);
    try {
      $client->identity();
      self::fail('Expected safe failure.');
    }
    catch (GatewayException $error) {
      self::assertSame($expected, $error->httpStatus());
      self::assertStringNotContainsString('SECRET', $error->getMessage());
      self::assertNull($error->getPrevious());
      self::assertCount(1, $history);
    }
  }

  /**
   * API failures, including redirect refusal.
   */
  public static function failures(): array {
    return [[401, 401], [403, 403], [429, 429], [503, 503], [302, 503]];
  }

  /**
   * A missing local session causes no authenticated upstream request.
   */
  public function testMissingSession(): void {
    $history = [];
    $this->expectExceptionMessage('session_required');
    $this->client(new Response(200), $history, FALSE, FALSE)->identity();
  }

  /**
   * Builds a real Guzzle adapter with synthetic session and locked context.
   */
  private function client(Response $response, array &$history, bool $logout = FALSE, bool $withSession = TRUE): SupportCertificatesClient {
    $handler = HandlerStack::create(new MockHandler([$response]));
    $handler->push(Middleware::history($history));
    $settings = new Settings([
      'tutor_api_base_url' => 'https://api.example.test/tutor-api',
      'tds_environment' => 'staging',
      'tds_certificate_allowed_origins' => ['https://verify.example.test'],
    ]);
    $session = $this->createMock(TutorSessionManagerInterface::class);
    $session->expects($withSession ? self::once() : self::never())->method('context')->willReturn(['id' => 'user-1']);
    $session->expects($logout ? self::once() : self::never())->method('logout');
    $store = $this->createMock(TutorTokenStoreInterface::class);
    $store->method('load')->willReturn(new TutorTokenSet('rotated-access', 'private-refresh', 2000));
    $lock = $this->createMock(LockBackendInterface::class);
    $lock->method('acquire')->willReturn(TRUE);
    $lock->expects($withSession ? self::once() : self::never())->method('release');
    $requests = new RequestStack();
    $request = new Request();
    if ($withSession) {
      $webSession = new Session(new MockArraySessionStorage());
      $webSession->start();
      $request->setSession($webSession);
    }
    $requests->push($request);
    return new SupportCertificatesClient(new Client(['handler' => $handler]), $settings, $session, $store, new ExternalUrlPolicy($settings), $lock, $requests);
  }

}
