<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_tutor_gateway\Unit;

use Drupal\Core\Access\CsrfTokenGenerator;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_tutor_gateway\Controller\BrowserSessionController;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Session\Session;
use Symfony\Component\HttpFoundation\Session\Storage\MockArraySessionStorage;

/**
 * Anonymous bootstrap persists only the marker and issues path-specific CSRF.
 */
#[CoversClass(BrowserSessionController::class)]
#[Group('tds_tutor_gateway')]
final class BrowserSessionControllerTest extends UnitTestCase {

  /**
   * Metadata alone is insufficient for core to persist an anonymous session.
   */
  public function testAnonymousBootstrap(): void {
    $request = Request::create('/tds/session/bootstrap', 'POST');
    $session = new Session(new MockArraySessionStorage());
    $request->setSession($session);
    $csrf = $this->createMock(CsrfTokenGenerator::class);
    $csrf->expects(self::exactly(2))->method('get')->willReturnMap([
      ['tds/session/login', 'synthetic-login-csrf'],
      ['tds/session/logout', 'synthetic-logout-csrf'],
    ]);
    $response = (new BrowserSessionController($csrf))->bootstrap($request);
    self::assertSame(['tds_tutor_gateway.browser_initialized' => TRUE], $session->all());
    self::assertSame(['login_token' => 'synthetic-login-csrf', 'logout_token' => 'synthetic-logout-csrf'], json_decode($response->getContent(), TRUE));
    self::assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
    self::assertFalse($response->headers->has('Access-Control-Allow-Origin'));
  }

}
