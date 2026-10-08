<?php

declare(strict_types=1);

namespace Drupal\tds_participant_portal\Service;

/**
 * Monta a projecao web read-only da area do participante.
 */
interface ParticipantAreaProviderInterface {

  /**
   * Retorna dashboard sanitizado para a sessao TDS atual.
   *
   * @return array<string, mixed>
   *   Dashboard com state, user, classes e certificates.
   */
  public function dashboard(): array;

}
