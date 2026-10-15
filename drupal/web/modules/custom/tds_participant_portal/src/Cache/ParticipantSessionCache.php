<?php

declare(strict_types=1);

namespace Drupal\tds_participant_portal\Cache;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Core\Site\Settings;
use Symfony\Component\HttpFoundation\RequestStack;

/**
 * Snapshot no backend da sessao Drupal; nunca usa cache publico compartilhado.
 */
final class ParticipantSessionCache implements ParticipantSessionCacheInterface {

  private const KEY = 'tds_participant_portal.dashboard';
  private const FRESH_SECONDS = 60;
  private const STALE_SECONDS = 360;

  /**
   * Construtor.
   */
  public function __construct(
    private readonly RequestStack $requestStack,
    private readonly Settings $settings,
    private readonly TimeInterface $time,
  ) {}

  /**
   * {@inheritdoc}
   */
  public function fresh(string $userId): ?array {
    return $this->read($userId, self::FRESH_SECONDS);
  }

  /**
   * {@inheritdoc}
   */
  public function stale(?string $userId = NULL): ?array {
    return $this->read($userId, self::STALE_SECONDS);
  }

  /**
   * {@inheritdoc}
   */
  public function set(string $userId, array $dashboard): void {
    $this->requestStack->getSession()->set(self::KEY, [
      'owner' => $userId,
      'environment' => $this->environmentFingerprint(),
      'fetched_at' => $this->time->getCurrentTime(),
      'dashboard' => $dashboard,
    ]);
  }

  /**
   * {@inheritdoc}
   */
  public function clear(): void {
    $this->requestStack->getSession()->remove(self::KEY);
  }

  /**
   * Le e valida owner, ambiente, idade e forma do snapshot.
   *
   * @return array<string, mixed>|null
   *   Dashboard ou NULL.
   */
  private function read(?string $userId, int $maximumAge): ?array {
    $entry = $this->requestStack->getSession()->get(self::KEY);
    if (!is_array($entry)
      || !is_string($entry['owner'] ?? NULL)
      || ($userId !== NULL && !hash_equals($entry['owner'], $userId))
      || !is_string($entry['environment'] ?? NULL)
      || !hash_equals($this->environmentFingerprint(), $entry['environment'])
      || !is_int($entry['fetched_at'] ?? NULL)
      || !is_array($entry['dashboard'] ?? NULL)) {
      return NULL;
    }
    $age = $this->time->getCurrentTime() - $entry['fetched_at'];
    if ($age < 0 || $age > $maximumAge) {
      return NULL;
    }
    return $entry['dashboard'];
  }

  /**
   * Isola cache entre ambiente e origem FastAPI sem persistir a URL em claro.
   */
  private function environmentFingerprint(): string {
    return hash('sha256', implode('|', [
      (string) $this->settings->get('tds_environment', 'local'),
      (string) $this->settings->get('tutor_api_base_url', ''),
    ]));
  }

}
