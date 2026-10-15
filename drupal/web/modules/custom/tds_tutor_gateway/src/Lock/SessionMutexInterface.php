<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Lock;

/**
 * A non-expiring mutex held by one request until session persistence completes.
 */
interface SessionMutexInterface {

  /**
   * Tries once to acquire a site/session key without waiting or stealing locks.
   */
  public function acquire(string $key): bool;

  /**
   * Releases a key owned by this request's pinned connection.
   */
  public function release(string $key): void;

}
