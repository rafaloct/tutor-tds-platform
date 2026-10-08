<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_tutor_gateway\Unit;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_tutor_gateway\Client\TutorApiClientInterface;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Session\TutorSessionManager;
use Drupal\tds_tutor_gateway\Storage\TutorTokenStoreInterface;
use Drupal\tds_tutor_gateway\ValueObject\TutorTokenSet;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;

/**
 * Testa a orquestracao da sessao TDS server-side.
 */
#[CoversClass(TutorSessionManager::class)]
#[Group('tds_tutor_gateway')]
final class TutorSessionManagerTest extends UnitTestCase {

  /**
   * Login troca o dono e nunca conserva tokens anteriores.
   */
  public function testLoginReplacesPreviousSession(): void {
    $client = $this->createMock(TutorApiClientInterface::class);
    $store = new MemoryTutorTokenStore(new TutorTokenSet('old', 'old-r', 9999));
    $fresh = new TutorTokenSet('new', 'new-r', 1300);
    $user = ['id' => 'user-2', 'name' => 'Pessoa B', 'role' => 'teacher'];
    $client->expects(self::once())->method('login')->willReturn([
      'tokens' => $fresh,
      'user' => $user,
    ]);

    $manager = new TutorSessionManager($client, $store, $this->time(1000));
    self::assertSame($user, $manager->login('11111111111', 'synthetic-password'));
    self::assertSame(1, $store->clearCount);
    self::assertSame($fresh, $store->load());
  }

  /**
   * Falha de novo login nao restaura o contexto do usuario anterior.
   */
  public function testInvalidLoginLeavesPreviousSessionCleared(): void {
    $client = $this->createMock(TutorApiClientInterface::class);
    $store = new MemoryTutorTokenStore(new TutorTokenSet('old', 'old-r', 9999));
    $client->method('login')
      ->willThrowException(new GatewayException('invalid_credentials', 401));

    $manager = new TutorSessionManager($client, $store, $this->time(1000));
    try {
      $manager->login('11111111111', 'invalid-password');
      self::fail('Era esperado login invalido.');
    }
    catch (GatewayException $error) {
      self::assertSame('invalid_credentials', $error->publicCode());
      self::assertNull($store->load());
      self::assertSame(1, $store->clearCount);
    }
  }

  /**
   * Token perto da expiracao e rotacionado antes de /auth/me.
   */
  public function testExpiredAccessRefreshesBeforeContext(): void {
    $client = $this->createMock(TutorApiClientInterface::class);
    $store = new MemoryTutorTokenStore(new TutorTokenSet('old', 'refresh-old', 1010));
    $fresh = new TutorTokenSet('fresh', 'refresh-fresh', 2000);
    $client->expects(self::once())->method('refresh')->with('refresh-old')->willReturn($fresh);
    $client->expects(self::once())->method('me')->with('fresh')->willReturn([
      'id' => 'user-1',
      'name' => 'Pessoa QA',
      'role' => 'student',
    ]);

    $manager = new TutorSessionManager($client, $store, $this->time(1000));
    self::assertSame('user-1', $manager->context()['id']);
    self::assertSame($fresh, $store->load());
  }

  /**
   * Erro 401 em /auth/me permite exatamente um refresh e replay GET.
   */
  public function testUnauthorizedContextRefreshesOnce(): void {
    $client = $this->createMock(TutorApiClientInterface::class);
    $store = new MemoryTutorTokenStore(new TutorTokenSet('old', 'refresh-old', 2000));
    $fresh = new TutorTokenSet('fresh', 'refresh-fresh', 3000);
    $calls = 0;
    $client->expects(self::exactly(2))->method('me')
      ->willReturnCallback(function () use (&$calls): array {
        if ($calls++ === 0) {
          throw new GatewayException('invalid_or_expired_session', 401);
        }
        return ['id' => 'user-1', 'name' => 'Pessoa QA', 'role' => 'student'];
      });
    $client->expects(self::once())->method('refresh')->with('refresh-old')->willReturn($fresh);

    $manager = new TutorSessionManager($client, $store, $this->time(1000));
    self::assertSame('user-1', $manager->context()['id']);
  }

  /**
   * API offline nao descarta tokens potencialmente recuperaveis.
   */
  public function testOfflinePreservesSession(): void {
    $client = $this->createMock(TutorApiClientInterface::class);
    $tokens = new TutorTokenSet('access', 'refresh', 2000);
    $store = new MemoryTutorTokenStore($tokens);
    $client->method('me')->willThrowException(new GatewayException('api_unavailable', 503));

    $manager = new TutorSessionManager($client, $store, $this->time(1000));
    try {
      $manager->context();
      self::fail('Era esperado offline.');
    }
    catch (GatewayException $error) {
      self::assertSame('api_unavailable', $error->publicCode());
      self::assertSame($tokens, $store->load());
    }
  }

  /**
   * Refresh recusado limpa a sessao; logout tambem.
   */
  public function testRejectedRefreshAndLogoutClearSession(): void {
    $client = $this->createMock(TutorApiClientInterface::class);
    $store = new MemoryTutorTokenStore(new TutorTokenSet('old', 'refresh-old', 1000));
    $client->method('refresh')->willThrowException(new GatewayException('invalid_or_expired_session', 401));
    $manager = new TutorSessionManager($client, $store, $this->time(1000));

    try {
      $manager->context();
      self::fail('Era esperado refresh recusado.');
    }
    catch (GatewayException) {
      self::assertNull($store->load());
    }

    $store->save(new TutorTokenSet('other', 'other-r', 2000));
    $manager->logout();
    self::assertNull($store->load());
  }

  /**
   * Mock de relogio.
   */
  private function time(int $requestTime): TimeInterface {
    $time = $this->createMock(TimeInterface::class);
    $time->method('getRequestTime')->willReturn($requestTime);
    return $time;
  }

}

/**
 * Store em memoria para os testes de sessao.
 */
final class MemoryTutorTokenStore implements TutorTokenStoreInterface {

  /**
   * Numero de limpezas de sessao observadas.
   */
  public int $clearCount = 0;

  public function __construct(
    private ?TutorTokenSet $tokens = NULL,
  ) {}

  /**
   * {@inheritdoc}
   */
  public function load(): ?TutorTokenSet {
    return $this->tokens;
  }

  /**
   * {@inheritdoc}
   */
  public function save(TutorTokenSet $tokens): void {
    $this->tokens = $tokens;
  }

  /**
   * {@inheritdoc}
   */
  public function clear(): void {
    $this->clearCount++;
    $this->tokens = NULL;
  }

}
