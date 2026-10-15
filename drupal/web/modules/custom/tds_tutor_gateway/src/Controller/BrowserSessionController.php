<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Controller;

use Drupal\Core\Access\CsrfTokenGenerator;
use Drupal\Core\Controller\ControllerBase;
use Drupal\Core\Url;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

/**
 * Starts an anonymous browser session without creating a Drupal user account.
 */
final class BrowserSessionController extends ControllerBase {

  /**
   * Constructs the browser entrypoint.
   */
  public function __construct(private readonly CsrfTokenGenerator $csrf) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static($container->get('csrf_token'));
  }

  /**
   * Returns presentation only: credentials and CSRF are never in rendered HTML.
   */
  public function page(): array {
    return [
      '#theme' => 'tds_session_login',
      '#login_url' => Url::fromUri('base:tds/session/login')->toString(),
      '#destination' => Url::fromUri('base:minha-area')->toString(),
      '#attached' => ['library' => ['tds_tutor_gateway/browser-session']],
      '#cache' => ['max-age' => 0],
    ];
  }

  /**
   * Persists a harmless attribute so core retains anonymous session metadata.
   */
  public function bootstrap(Request $request): JsonResponse {
    $request->getSession()->set('tds_tutor_gateway.browser_initialized', TRUE);
    return new JsonResponse([
      'login_token' => $this->csrf->get('tds/session/login'),
      'logout_token' => $this->csrf->get('tds/session/logout'),
    ], 200, ['Cache-Control' => 'no-store, private']);
  }

}
