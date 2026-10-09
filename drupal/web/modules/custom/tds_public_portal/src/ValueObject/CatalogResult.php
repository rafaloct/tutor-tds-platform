<?php

declare(strict_types=1);

namespace Drupal\tds_public_portal\ValueObject;

/**
 * Resultado sanitizado da projecao publica da FastAPI.
 */
final class CatalogResult {

  public const FRESH = 'fresh';
  public const STALE = 'stale';
  public const NOT_FOUND = 'not_found';
  public const UNAVAILABLE = 'unavailable';

  /**
   * Construtor.
   *
   * @param string $state
   *   Estado fresh, stale, not_found ou unavailable.
   * @param array<string, mixed> $payload
   *   Payload limitado ao contrato publico.
   */
  public function __construct(
    public readonly string $state,
    public readonly array $payload = [],
  ) {}

  /**
   * Indica se ha payload renderizavel.
   */
  public function hasPayload(): bool {
    return in_array($this->state, [self::FRESH, self::STALE], TRUE);
  }

}
