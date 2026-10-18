<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_tutor_gateway\Unit;

use Drupal\Tests\UnitTestCase;
use Drupal\tds_tutor_gateway\EventSubscriber\BrowserSessionSubscriber;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\HttpKernelInterface;

/**
 * Ensures bootstrap and authenticated mutations reject foreign origins.
 */
#[CoversClass(BrowserSessionSubscriber::class)]
#[Group('tds_tutor_gateway')]
final class BrowserSessionSubscriberTest extends UnitTestCase {

  /**
   * Compares scheme, host and port without trusting forwarded headers.
   */
  #[DataProvider('origins')]
  public function testOrigins(array $headers, bool $expected): void {
    $request = Request::create('https://portal.example.test/tds/session/bootstrap');
    $request->headers->add($headers);
    self::assertSame($expected, BrowserSessionSubscriber::sameOrigin($request));
  }

  /**
   * Browser origins and hostile/non-browser variations.
   */
  public static function origins(): array {
    return [
      [['Origin' => 'https://portal.example.test'], TRUE],
      [['Origin' => 'https://portal.example.test:443'], TRUE],
      [['Referer' => 'https://portal.example.test/entrar?q=1'], TRUE],
      [[], FALSE],
      [['Origin' => 'null'], FALSE],
      [['Origin' => 'http://portal.example.test'], FALSE],
      [['Origin' => 'https://portal.example.test:444'], FALSE],
      [['Origin' => 'https://foreign.example', 'Referer' => 'https://portal.example.test/'], FALSE],
      [['Origin' => 'https://portal.example.test', 'Sec-Fetch-Site' => 'cross-site'], FALSE],
      [['Origin' => 'https://portal.example.test/path'], FALSE],
      [['Origin' => 'https://name@portal.example.test'], FALSE],
      [['Origin' => 'https://foreign.example', 'X-Forwarded-Host' => 'foreign.example'], FALSE],
    ];
  }

  /**
   * Bootstrap requires a non-simple header, but login still uses route CSRF.
   */
  public function testBootstrapHeader(): void {
    $request = Request::create('https://portal.example.test/tds/session/bootstrap', 'POST');
    $request->attributes->set('_route', 'tds_tutor_gateway.bootstrap');
    $request->headers->set('Origin', 'https://portal.example.test');
    $kernel = $this->createMock(HttpKernelInterface::class);
    $event = new RequestEvent($kernel, $request, HttpKernelInterface::MAIN_REQUEST);
    (new BrowserSessionSubscriber())->onRequest($event);
    self::assertSame(403, $event->getResponse()->getStatusCode());
    $request->headers->set('X-TDS-Bootstrap', '1');
    $event = new RequestEvent($kernel, $request, HttpKernelInterface::MAIN_REQUEST);
    (new BrowserSessionSubscriber())->onRequest($event);
    self::assertFalse($event->hasResponse());
  }

  /**
   * A router rejection may happen before the route attribute is available.
   */
  public function testDeniedRouteStillHasNoStore(): void {
    $request = Request::create('https://portal.example.test/tds/session/login');
    $response = new Response('', 403);
    $event = new ResponseEvent($this->createMock(HttpKernelInterface::class), $request, HttpKernelInterface::MAIN_REQUEST, $response);
    (new BrowserSessionSubscriber())->onResponse($event);
    self::assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
    self::assertSame('no-referrer', $response->headers->get('Referrer-Policy'));
  }

}
