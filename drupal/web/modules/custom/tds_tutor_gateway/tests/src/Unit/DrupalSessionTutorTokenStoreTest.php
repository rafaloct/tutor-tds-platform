<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_tutor_gateway\Unit;

use Drupal\Tests\UnitTestCase;
use Drupal\tds_tutor_gateway\Storage\DrupalSessionTutorTokenStore;
use Drupal\tds_tutor_gateway\ValueObject\TutorTokenSet;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\HttpFoundation\Session\Session;
use Symfony\Component\HttpFoundation\Session\Storage\MockArraySessionStorage;

/**
 * Testa isolamento dos tokens pelo backend da sessao Drupal.
 */
#[CoversClass(DrupalSessionTutorTokenStore::class)]
#[Group('tds_tutor_gateway')]
final class DrupalSessionTutorTokenStoreTest extends UnitTestCase {

  /**
   * Dois cookies/sessoes concorrentes nunca compartilham tokens.
   */
  public function testConcurrentBrowserSessionsAreIsolated(): void {
    [$first, $firstSession] = $this->store();
    [$second, $secondSession] = $this->store();
    $firstTokens = new TutorTokenSet('access-a', 'refresh-a', 2000);
    $secondTokens = new TutorTokenSet('access-b', 'refresh-b', 3000);

    $first->save($firstTokens);
    $second->save($secondTokens);

    self::assertEquals($firstTokens, $first->load());
    self::assertEquals($secondTokens, $second->load());
    self::assertIsArray($firstSession->get('tds_tutor_gateway.tokens'));
    self::assertIsArray($secondSession->get('tds_tutor_gateway.tokens'));

    $first->clear();
    self::assertNull($first->load());
    self::assertEquals($secondTokens, $second->load());
  }

  /**
   * Cria um store com sessao sintetica independente.
   *
   * @return array{DrupalSessionTutorTokenStore, Session}
   *   Store e sessao subjacente.
   */
  private function store(): array {
    $session = new Session(new MockArraySessionStorage());
    $request = Request::create('/');
    $request->setSession($session);
    $stack = new RequestStack();
    $stack->push($request);
    return [new DrupalSessionTutorTokenStore($stack), $session];
  }

}
