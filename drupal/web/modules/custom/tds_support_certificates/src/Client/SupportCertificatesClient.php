<?php

declare(strict_types=1);

namespace Drupal\tds_support_certificates\Client;

use Drupal\Core\Lock\LockBackendInterface;
use Drupal\Core\Site\Settings;
use Drupal\tds_support_certificates\Security\ExternalUrlPolicy;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Session\TutorSessionManagerInterface;
use Drupal\tds_tutor_gateway\Storage\TutorTokenStoreInterface;
use GuzzleHttp\ClientInterface;
use GuzzleHttp\Exception\GuzzleException;
use Symfony\Component\HttpFoundation\RequestStack;

/**
 * Read-only API adapter; no certificate issuance or conversation creation.
 */
final class SupportCertificatesClient implements SupportCertificatesClientInterface {

  /**
   * Constructs the isolated adapter.
   */
  public function __construct(
    private readonly ClientInterface $http,
    private readonly Settings $settings,
    private readonly TutorSessionManagerInterface $session,
    private readonly TutorTokenStoreInterface $store,
    private readonly ExternalUrlPolicy $urls,
    private readonly LockBackendInterface $lock,
    private readonly RequestStack $requests,
  ) {}

  /**
   * Returns presentation fields only, excluding hashes and other identities.
   */
  public function certificates(): array {
    [$data, $user] = $this->request('/certificates');
    if (!is_array($data['certificates'] ?? NULL) || !array_is_list($data['certificates'])) {
      throw new GatewayException('invalid_api_response', 502);
    }
    $result = [];
    foreach ($data['certificates'] as $record) {
      if (!is_array($record) || ($record['user_id'] ?? NULL) !== $user['id']) {
        throw new GatewayException('certificate_context_mismatch', 502);
      }
      if (!is_string($record['id'] ?? NULL) || !is_string($record['issued_at'] ?? NULL)) {
        throw new GatewayException('invalid_api_response', 502);
      }
      $title = $record['course_title'] ?? NULL;
      if ($title !== NULL && !is_string($title)) {
        throw new GatewayException('invalid_api_response', 502);
      }
      $result[] = [
        'title' => $title ?: 'Certificado',
        'issued_at' => $record['issued_at'],
        'verification_url' => $this->urls->approved($record['verification_url'] ?? NULL, 'tds_certificate_allowed_origins'),
      ];
    }
    return $result;
  }

  /**
   * Returns a signed widget identity for one ephemeral runtime only.
   */
  public function identity(): array {
    [$data, $user] = $this->request('/support/identity');
    $identifier = $data['identifier'] ?? NULL;
    $hash = $data['identifier_hash'] ?? NULL;
    if (!is_string($identifier) || strlen($identifier) > 256 || !preg_match('/^[a-z0-9-]{1,64}:(.+)$/D', $identifier, $matches) || $matches[1] !== $user['id'] || !is_string($hash) || !preg_match('/^[a-f0-9]{64}$/D', $hash)) {
      throw new GatewayException('invalid_support_identity', 502);
    }
    return ['identifier' => $identifier, 'identifier_hash' => $hash];
  }

  /**
   * Reads one fixed endpoint, refreshing through the existing session service.
   */
  private function request(string $path): array {
    $request = $this->requests->getCurrentRequest();
    if (!$request || !$request->hasSession() || !$request->getSession()->getId()) {
      throw new GatewayException('session_required', 401);
    }
    // Best-effort exclusion during this call, NOT a refresh-safety guarantee:
    // Drupal reads the session before acquire and saves after release. Even
    // this module's concurrent requests can hold stale refresh snapshots.
    // Authenticated deployment is blocked until the gateway/session middleware
    // shares a lock across the complete read-refresh-save lifecycle.
    $key = 'tds_support_session:' . hash('sha256', $request->getSession()->getId());
    if (!$this->lock->acquire($key, 30.0)) {
      throw new GatewayException('session_busy', 503);
    }
    try {
      $user = $this->session->context();
      $tokens = $this->store->load();
      if ($tokens === NULL) {
        throw new GatewayException('session_required', 401);
      }
      $base = (string) $this->settings->get('tutor_api_base_url', '');
      $parts = parse_url($base);
      $loopback = ['localhost', '127.0.0.1', '::1', '[::1]'];
      $local = $this->settings->get('tds_environment') === 'local' && in_array($parts['host'] ?? '', $loopback, TRUE);
      if (!$parts || empty($parts['host']) || (!in_array($parts['scheme'] ?? '', $local ? ['https', 'http'] : ['https'], TRUE)) || isset($parts['user']) || isset($parts['pass']) || isset($parts['query']) || isset($parts['fragment']) || preg_match('/[\x00-\x20\x7f\\\\]/', $base)) {
        throw new GatewayException('api_configuration_invalid', 503);
      }
      try {
        $response = $this->http->request('GET', rtrim($base, '/') . $path, [
          'headers' => ['Accept' => 'application/json', 'Authorization' => 'Bearer ' . $tokens->accessToken],
          'timeout' => 10,
          'connect_timeout' => 3,
          'allow_redirects' => FALSE,
          'http_errors' => FALSE,
        ]);
      }
      catch (GuzzleException) {
        // Never chain an exception that can retain an Authorization header.
        throw new GatewayException('api_unavailable', 503);
      }
      $status = $response->getStatusCode();
      if ($status === 401) {
        $this->session->logout();
        throw new GatewayException('session_required', 401);
      }
      if ($status !== 200) {
        throw new GatewayException(match ($status) {
          403 => 'access_denied',
          429 => 'rate_limited',
          default => 'api_unavailable',
        }, in_array($status, [403, 429], TRUE) ? $status : 503);
      }
      $body = $response->getBody()->read(1048577);
      if (strlen($body) > 1048576) {
        throw new GatewayException('invalid_api_response', 502);
      }
      try {
        $data = json_decode($body, TRUE, 32, JSON_THROW_ON_ERROR);
      }
      catch (\JsonException) {
        throw new GatewayException('invalid_api_response', 502);
      }
      if (!is_array($data) || array_is_list($data)) {
        throw new GatewayException('invalid_api_response', 502);
      }
      return [$data, $user];
    }
    finally {
      $this->lock->release($key);
    }
  }

}
