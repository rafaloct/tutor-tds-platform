<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * Restricts cookie-authenticated mutations to the browser's own origin.
 */
final class BrowserSessionSubscriber implements EventSubscriberInterface {

  /**
   * {@inheritdoc}
   */
  public static function getSubscribedEvents(): array {
    return [
      KernelEvents::REQUEST => ['onRequest', 29],
      KernelEvents::RESPONSE => ['onResponse', -2050],
    ];
  }

  /**
   * Applies an origin check in addition to Drupal's route-specific CSRF token.
   */
  public function onRequest(RequestEvent $event): void {
    $request = $event->getRequest();
    $route = $request->attributes->get('_route');
    if (!in_array($route, ['tds_tutor_gateway.bootstrap', 'tds_tutor_gateway.login', 'tds_tutor_gateway.logout'], TRUE)) {
      return;
    }
    if (!self::sameOrigin($request)
      || ($route === 'tds_tutor_gateway.bootstrap' && $request->headers->get('X-TDS-Bootstrap') !== '1')) {
      $event->setResponse(new JsonResponse(['error' => 'invalid_request_origin'], 403));
    }
  }

  /**
   * Validates Origin; Referer is a fallback only when Origin is absent.
   */
  public static function sameOrigin(Request $request): bool {
    if ($request->headers->get('Sec-Fetch-Site') === 'cross-site') {
      return FALSE;
    }
    $origin = $request->headers->get('Origin');
    $reference = $origin ?? $request->headers->get('Referer', '');
    $parts = parse_url($reference);
    if (!is_array($parts) || isset($parts['user']) || isset($parts['pass'])
      || !isset($parts['scheme'], $parts['host'])) {
      return FALSE;
    }
    $scheme = strtolower($parts['scheme']);
    $host = strtolower($parts['host']);
    $port = $parts['port'] ?? ($scheme === 'https' ? 443 : 80);
    if ($origin !== NULL && (isset($parts['query']) || isset($parts['fragment']) || !empty($parts['path']))) {
      return FALSE;
    }
    return $scheme === $request->getScheme() && $host === strtolower($request->getHost())
      && $port === $request->getPort();
  }

  /**
   * Overrides final Drupal cache policy for the entire gateway browser surface.
   */
  public function onResponse(ResponseEvent $event): void {
    $request = $event->getRequest();
    $path = rawurldecode($request->getPathInfo());
    if (str_starts_with((string) $request->attributes->get('_route'), 'tds_tutor_gateway.')
      || str_starts_with($path, '/tds/session/') || rtrim($path, '/') === '/entrar') {
      $headers = $event->getResponse()->headers;
      $headers->set('Cache-Control', 'no-store, private');
      $headers->set('Pragma', 'no-cache');
      $headers->set('Referrer-Policy', 'no-referrer');
    }
  }

}
