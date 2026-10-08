<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\ValueObject;

/**
 * Tokens TDS exclusivamente server-side.
 */
final readonly class TutorTokenSet {

  /**
   * Construtor.
   */
  public function __construct(
    public string $accessToken,
    public string $refreshToken,
    public int $expiresAt,
  ) {}

  /**
   * Serializa somente para o store privado do servidor.
   *
   * @return array{access_token: string, refresh_token: string, expires_at: int}
   *   Registro interno.
   */
  public function toPrivateStore(): array {
    return [
      'access_token' => $this->accessToken,
      'refresh_token' => $this->refreshToken,
      'expires_at' => $this->expiresAt,
    ];
  }

  /**
   * Reconstitui um registro privado validado.
   */
  public static function fromPrivateStore(mixed $value): ?self {
    if (!is_array($value)) {
      return NULL;
    }
    $access = $value['access_token'] ?? NULL;
    $refresh = $value['refresh_token'] ?? NULL;
    $expires = $value['expires_at'] ?? NULL;
    if (!is_string($access) || $access === '' || !is_string($refresh) || $refresh === '' || !is_int($expires)) {
      return NULL;
    }
    return new self($access, $refresh, $expires);
  }

}
