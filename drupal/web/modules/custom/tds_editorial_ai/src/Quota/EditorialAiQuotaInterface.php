<?php

declare(strict_types=1);

namespace Drupal\tds_editorial_ai\Quota;

/**
 * Reserves an attempt and holds the global inference slot until release.
 */
interface EditorialAiQuotaInterface {

  /**
   * Reserves a counted attempt or throws a sanitized public failure.
   */
  public function reserve(string $accountId): void;

  /**
   * Releases the slot without refunding a reserved attempt.
   */
  public function release(): void;

}
