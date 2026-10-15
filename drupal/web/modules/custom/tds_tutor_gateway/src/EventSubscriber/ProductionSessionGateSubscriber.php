<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\EventSubscriber;

use Drupal\Core\Site\Settings;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * Keeps the academic session surface closed until production acceptance.
 */
final class ProductionSessionGateSubscriber implements EventSubscriberInterface {

  /**
   * Constructs the gate.
   */
  public function __construct(private readonly Settings $settings) {}

  /**
   * {@inheritdoc}
   */
  public static function getSubscribedEvents(): array {
    return [
      KernelEvents::REQUEST => ['onRequest', 30],
      KernelEvents::RESPONSE => ['onResponse', -2048],
    ];
  }

  /**
   * Checks both routed names and paths after the router, before controllers.
   */
  public function onRequest(RequestEvent $event): void {
    if ($this->settings->get('tds_environment') !== 'production'
      || $this->settings->get('tds_production_sessions_enabled', FALSE) === TRUE) {
      return;
    }
    $request = $event->getRequest();
    $path = rawurldecode($request->getPathInfo());
    $route = (string) $request->attributes->get('_route', '');
    if ($path !== '/tds/session' && !str_starts_with($path, '/tds/session/')
      && !in_array($route, ['tds_tutor_gateway.login', 'tds_tutor_gateway.context', 'tds_tutor_gateway.logout'], TRUE)) {
      return;
    }
    $request->attributes->set('_tds_production_session_blocked', TRUE);
    $event->setResponse(new JsonResponse(['error' => 'production_sessions_disabled'], 403, [
      'Cache-Control' => 'no-store, private',
    ]));
  }

  /**
   * Preserve no-store after Drupal response policy subscribers have run.
   */
  public function onResponse(ResponseEvent $event): void {
    if ($event->getRequest()->attributes->get('_tds_production_session_blocked') === TRUE) {
      $event->getResponse()->headers->set('Cache-Control', 'no-store, private');
    }
  }

}
