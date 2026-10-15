<?php

declare(strict_types=1);

namespace Drupal\tds_support_certificates\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * Applies private headers after Drupal's final cache-header calculation.
 */
final class PrivateResponseSubscriber implements EventSubscriberInterface {

  /**
   * {@inheritdoc}
   */
  public static function getSubscribedEvents(): array {
    return [KernelEvents::RESPONSE => ['onResponse', -1000]];
  }

  /**
   * Protects only this module's routes, including error and rendered responses.
   */
  public function onResponse(ResponseEvent $event): void {
    if (!$event->isMainRequest() || !str_starts_with((string) $event->getRequest()->attributes->get('_route'), 'tds_support_certificates.')) {
      return;
    }
    $headers = $event->getResponse()->headers;
    $headers->set('Cache-Control', 'no-store, private');
    $headers->set('Pragma', 'no-cache');
    $headers->set('Referrer-Policy', 'no-referrer');
    $headers->set('X-Content-Type-Options', 'nosniff');
    $headers->remove('ETag');
    $headers->remove('Last-Modified');
  }

}
