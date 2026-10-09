<?php

declare(strict_types=1);

namespace Drupal\tds_public_portal\Exception;

/**
 * Falha interna sanitizada do adapter publico.
 */
final class CatalogException extends \RuntimeException {

  /**
   * Construtor.
   */
  public function __construct(
    public readonly string $publicCode,
    public readonly int $httpStatus,
    ?\Throwable $previous = NULL,
  ) {
    parent::__construct($publicCode, 0, $previous);
  }

}
