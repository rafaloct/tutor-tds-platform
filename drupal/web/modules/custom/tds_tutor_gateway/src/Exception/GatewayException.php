<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Exception;

/**
 * Erro sanitizado do gateway, sem payload ou credencial upstream.
 */
final class GatewayException extends \RuntimeException {

  /**
   * Construtor.
   */
  public function __construct(
    private readonly string $publicCode,
    private readonly int $httpStatus,
  ) {
    parent::__construct($publicCode);
  }

  /**
   * Codigo estavel e seguro para a resposta web.
   */
  public function publicCode(): string {
    return $this->publicCode;
  }

  /**
   * Status HTTP seguro para a resposta web.
   */
  public function httpStatus(): int {
    return $this->httpStatus;
  }

}
