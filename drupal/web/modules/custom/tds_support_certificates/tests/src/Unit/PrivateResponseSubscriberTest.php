<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_support_certificates\Unit;

use Drupal\Tests\UnitTestCase;
use Drupal\tds_support_certificates\EventSubscriber\PrivateResponseSubscriber;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\HttpKernelInterface;

/**
 * Protects final headers without changing unrelated portal pages.
 */
#[CoversClass(PrivateResponseSubscriber::class)]
#[Group('tds_support_certificates')]
final class PrivateResponseSubscriberTest extends UnitTestCase {

  /**
   * Drupal's calculated headers are replaced after its priority-zero listener.
   */
  public function testPrivateFinalHeaders(): void {
    $request = new Request();
    $request->attributes->set('_route', 'tds_support_certificates.certificates');
    $response = new Response('', 200, ['Cache-Control' => 'no-cache, private', 'ETag' => 'private-hash']);
    $event = new ResponseEvent($this->createMock(HttpKernelInterface::class), $request, HttpKernelInterface::MAIN_REQUEST, $response);
    (new PrivateResponseSubscriber())->onResponse($event);
    self::assertTrue($response->headers->hasCacheControlDirective('no-store'));
    self::assertSame('no-referrer', $response->headers->get('Referrer-Policy'));
    self::assertFalse($response->headers->has('ETag'));
    self::assertLessThan(0, PrivateResponseSubscriber::getSubscribedEvents()['kernel.response'][1]);
  }

  /**
   * Other Drupal routes retain their existing cache policy.
   */
  public function testUnrelatedRoute(): void {
    $request = new Request();
    $request->attributes->set('_route', 'tds_public_portal.catalog');
    $response = new Response('', 200, ['Cache-Control' => 'public, max-age=300']);
    $before = $response->headers->get('Cache-Control');
    $event = new ResponseEvent($this->createMock(HttpKernelInterface::class), $request, HttpKernelInterface::MAIN_REQUEST, $response);
    (new PrivateResponseSubscriber())->onResponse($event);
    self::assertSame($before, $response->headers->get('Cache-Control'));
  }

}
