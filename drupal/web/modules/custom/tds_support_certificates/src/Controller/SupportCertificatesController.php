<?php

declare(strict_types=1);

namespace Drupal\tds_support_certificates\Controller;

use Drupal\Component\Utility\Html;
use Drupal\Core\Controller\ControllerBase;
use Drupal\Core\Site\Settings;
use Drupal\Core\Url;
use Drupal\tds_support_certificates\Client\SupportCertificatesClientInterface;
use Drupal\tds_support_certificates\Security\ExternalUrlPolicy;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

/**
 * Safe presentation and isolated, ephemeral support runtime.
 */
final class SupportCertificatesController extends ControllerBase {

  /**
   * Constructs the presentation controller.
   */
  public function __construct(
    private readonly SupportCertificatesClientInterface $client,
    private readonly ExternalUrlPolicy $urls,
    private readonly Settings $settings,
    private readonly string $modulePath,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static(
      $container->get('tds_support_certificates.client'),
      $container->get('tds_support_certificates.urls'),
      $container->get('settings'),
      $container->get('extension.list.module')->getPath('tds_support_certificates'),
    );
  }

  /**
   * Public navigation only: no guessed verifier API or code collection.
   */
  public function verification(): array {
    return $this->page('tds_certificate_verification') + [
      '#verifier' => $this->urls->approved($this->settings->get('tds_certificate_verifier_url'), 'tds_certificate_allowed_origins'),
    ];
  }

  /**
   * Private list: validity belongs exclusively to the official verifier.
   */
  public function certificates(): array {
    $build = $this->page('tds_support_certificates');
    $build['#attached']['library'][] = 'tds_support_certificates/private_page';
    try {
      $build['#certificates'] = $this->client->certificates();
      $build['#state'] = $build['#certificates'] ? 'available' : 'empty';
    }
    catch (GatewayException $error) {
      $build['#certificates'] = [];
      $build['#state'] = match ($error->httpStatus()) {
        401 => 'session_required',
        403 => 'access_denied',
        default => 'unavailable',
      };
    }
    return $build;
  }

  /**
   * An anonymous page never starts a widget or creates a conversation.
   */
  public function support(): array {
    $build = $this->page('tds_support');
    $build['#fallback'] = $this->urls->approved($this->settings->get('tds_support_public_url'), 'tds_support_allowed_origins');
    $build['#identity_url'] = Url::fromRoute('tds_support_certificates.identity')->toString();
    $build['#frame_url'] = Url::fromRoute('tds_support_certificates.frame')->toString();
    $build['#attached']['library'][] = 'tds_support_certificates/support';
    return $build;
  }

  /**
   * No-store browser boundary: only the widget signature, never Tutor tokens.
   */
  public function identity(): JsonResponse {
    try {
      // Disabled by default; real SDK compatibility requires isolated staging.
      if ($this->settings->get('tds_chatwoot_enabled', FALSE) !== TRUE || $this->urls->widgetOrigin() === NULL) {
        throw new GatewayException('support_unavailable', 503);
      }
      $token = $this->settings->get('tds_chatwoot_website_token', '');
      if (!is_string($token) || !preg_match('/^[A-Za-z0-9_-]{1,256}$/D', $token)) {
        throw new GatewayException('support_unavailable', 503);
      }
      return new JsonResponse($this->client->identity() + [
        'base_url' => $this->urls->widgetOrigin(),
        // This is Chatwoot's public inbox token, never its identity secret.
        'website_token' => $token,
      ], 200, $this->headers());
    }
    catch (GatewayException $error) {
      return new JsonResponse(['error' => $error->publicCode()], $error->httpStatus(), $this->headers());
    }
  }

  /**
   * Opaque sandbox document, containing no signed identity in HTML.
   */
  public function frame(): Response {
    $origin = $this->urls->widgetOrigin();
    if ($origin === NULL || $this->settings->get('tds_chatwoot_enabled', FALSE) !== TRUE) {
      return new Response('', 503, $this->headers());
    }
    $script = Html::escape(base_path() . $this->modulePath . '/js/frame.js');
    $websocket = 'wss://' . substr($origin, strlen('https://'));
    $headers = $this->headers() + [
      'Content-Type' => 'text/html; charset=UTF-8',
      'Content-Security-Policy' => "default-src 'none'; script-src 'self' $origin; connect-src $origin $websocket; frame-src $origin; img-src $origin data:; style-src $origin 'unsafe-inline'; font-src $origin; base-uri 'none'; form-action $origin; frame-ancestors 'self'; sandbox allow-scripts allow-forms",
      'X-Frame-Options' => 'SAMEORIGIN',
    ];
    return new Response('<!doctype html><html lang="pt-br"><head><meta charset="utf-8"><title>Suporte autenticado</title></head><body><script src="' . $script . '"></script></body></html>', 200, $headers);
  }

  /**
   * Prevents shared cache and referrer leakage on all presentation pages.
   */
  private function page(string $theme): array {
    $headers = [];
    foreach ($this->headers() as $name => $value) {
      $headers[] = [$name, $value, TRUE];
    }
    return ['#theme' => $theme, '#cache' => ['max-age' => 0], '#attached' => ['http_header' => $headers]];
  }

  /**
   * Common security headers, including error responses.
   */
  private function headers(): array {
    return [
      'Cache-Control' => 'no-store, private',
      'Pragma' => 'no-cache',
      'Referrer-Policy' => 'no-referrer',
      'X-Content-Type-Options' => 'nosniff',
    ];
  }

}
