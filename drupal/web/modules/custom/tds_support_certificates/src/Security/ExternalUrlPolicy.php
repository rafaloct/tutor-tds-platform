<?php

declare(strict_types=1);

namespace Drupal\tds_support_certificates\Security;

use Drupal\Core\Site\Settings;

/**
 * Exact HTTPS origins configured by operators, never by request parameters.
 */
final class ExternalUrlPolicy {

  /**
   * Constructs the URL policy.
   */
  public function __construct(private readonly Settings $settings) {}

  /**
   * Returns an approved URL, or NULL without echoing a rejected value.
   */
  public function approved(mixed $url, string $setting): ?string {
    if (!is_string($url) || strlen($url) > 2048 || preg_match('/[\x00-\x20\x7f\\\\]/', $url)) {
      return NULL;
    }
    $parts = parse_url($url);
    if (!$parts || ($parts['scheme'] ?? '') !== 'https' || empty($parts['host']) || isset($parts['user']) || isset($parts['pass']) || isset($parts['fragment'])) {
      return NULL;
    }
    $origin = 'https://' . strtolower($parts['host']) . (isset($parts['port']) ? ':' . $parts['port'] : '');
    $origins = $this->settings->get($setting, []);
    return is_array($origins) && in_array($origin, $origins, TRUE) ? $url : NULL;
  }

  /**
   * Returns only a configured HTTPS origin, without paths or queries.
   */
  public function widgetOrigin(): ?string {
    $url = $this->approved($this->settings->get('tds_chatwoot_origin'), 'tds_chatwoot_allowed_origins');
    if ($url === NULL || preg_match('~^https://[^/?#]+$~D', $url) !== 1) {
      return NULL;
    }
    return $url;
  }

}
