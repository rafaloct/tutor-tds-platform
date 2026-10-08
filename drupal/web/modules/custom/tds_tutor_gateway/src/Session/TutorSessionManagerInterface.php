<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Session;

/**
 * Sessao TDS server-side associada a sessao Drupal atual.
 */
interface TutorSessionManagerInterface {

  /**
   * Autentica e troca o dono local da sessao.
   *
   * @return array{id: string, name: string, role: string}
   *   Usuario publico.
   */
  public function login(string $cpf, string $password): array;

  /**
   * Retorna contexto atual, renovando uma unica vez quando necessario.
   *
   * @return array{id: string, name: string, role: string}
   *   Usuario publico.
   */
  public function context(): array;

  /**
   * Invalida imediatamente o contexto local.
   */
  public function logout(): void;

}
