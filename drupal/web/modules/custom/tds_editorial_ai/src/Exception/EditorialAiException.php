<?php

declare(strict_types=1);

namespace Drupal\tds_editorial_ai\Exception;

/**
 * An allowlisted public failure, without chained upstream exception or payload.
 */
final class EditorialAiException extends \RuntimeException {

  /**
   * Constructs a sanitized failure.
   */
  public function __construct(public readonly string $errorCode, public readonly int $status) {
    parent::__construct($errorCode);
  }

}
