<?php

declare(strict_types=1);

namespace Drupal\tds_editorial_ai\Quota;

use Drupal\Core\Flood\FloodInterface;
use Drupal\Core\Lock\LockBackendInterface;
use Drupal\tds_editorial_ai\Exception\EditorialAiException;

/**
 * Serializes quota check/register and holds a bounded global inference lease.
 */
final class EditorialAiQuota implements EditorialAiQuotaInterface {

  /**
   * Site-wide slot; unrelated to academic session locking.
   */
  public const LOCK_NAME = 'tds_editorial_ai.inference';

  /**
   * Tracks ownership within this request.
   */
  private bool $reserved = FALSE;

  /**
   * Constructs the reservation service.
   */
  public function __construct(
    private readonly LockBackendInterface $lock,
    private readonly FloodInterface $flood,
  ) {}

  /**
   * {@inheritdoc}
   */
  public function reserve(string $accountId): void {
    if ($this->reserved || !$this->lock->acquire(self::LOCK_NAME, 60.0)) {
      throw new EditorialAiException('editorial_busy', 429);
    }
    $this->reserved = TRUE;
    try {
      // Explicit account key: quota is per editor, not implicit IP address.
      if (!$this->flood->isAllowed('tds_editorial_ai.attempt', 10, 3600, $accountId)) {
        throw new EditorialAiException('editorial_quota_exceeded', 429);
      }
      // Check/register share the global lock. Provider failures count.
      $this->flood->register('tds_editorial_ai.attempt', 3600, $accountId);
    }
    catch (\Throwable $error) {
      $this->release();
      if ($error instanceof EditorialAiException) {
        throw $error;
      }
      throw new EditorialAiException('editorial_unavailable', 503);
    }
  }

  /**
   * {@inheritdoc}
   */
  public function release(): void {
    if ($this->reserved) {
      $this->reserved = FALSE;
      $this->lock->release(self::LOCK_NAME);
    }
  }

}
