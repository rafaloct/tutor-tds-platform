<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_participant_portal\Unit;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Core\Site\Settings;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_participant_portal\Cache\ParticipantSessionCache;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\HttpFoundation\Session\Session;
use Symfony\Component\HttpFoundation\Session\Storage\MockArraySessionStorage;

/**
 * Cobre isolamento por sessao, conta, ambiente e janela stale.
 */
#[CoversClass(ParticipantSessionCache::class)]
#[Group('tds_participant_portal')]
final class ParticipantSessionCacheTest extends UnitTestCase {

  /**
   * Outra conta e outro ambiente nunca reutilizam o snapshot.
   */
  public function testOwnerAndEnvironmentIsolation(): void {
    $session = new Session(new MockArraySessionStorage());
    $cache = $this->cache($session, 1000, 'qa-a');
    $cache->set('user-a', ['classes' => []]);

    self::assertSame(['classes' => []], $cache->fresh('user-a'));
    self::assertNull($cache->fresh('user-b'));
    self::assertNull($this->cache($session, 1000, 'qa-b')->fresh('user-a'));
  }

  /**
   * Fresh expira em 60s, stale em 360s e clear remove imediatamente.
   */
  public function testFreshStaleAndClearWindows(): void {
    $session = new Session(new MockArraySessionStorage());
    $this->cache($session, 1000, 'qa')->set('user-a', ['classes' => []]);

    self::assertNull($this->cache($session, 1061, 'qa')->fresh('user-a'));
    self::assertSame(['classes' => []], $this->cache($session, 1360, 'qa')->stale('user-a'));
    self::assertNull($this->cache($session, 1361, 'qa')->stale('user-a'));

    $cache = $this->cache($session, 1001, 'qa');
    $cache->clear();
    self::assertNull($cache->stale());
  }

  /**
   * Cria cache com sessao e tempo deterministas.
   */
  private function cache(Session $session, int $now, string $environment): ParticipantSessionCache {
    $request = Request::create('/minha-area');
    $request->setSession($session);
    $stack = new RequestStack();
    $stack->push($request);
    $time = $this->createMock(TimeInterface::class);
    $time->method('getCurrentTime')->willReturn($now);
    return new ParticipantSessionCache(
      $stack,
      new Settings([
        'tds_environment' => $environment,
        'tutor_api_base_url' => 'https://api.example.test/tutor-api',
      ]),
      $time,
    );
  }

}
