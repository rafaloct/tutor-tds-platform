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
   * Executa uma leitura autenticada com refresh/replay no servidor.
   *
   * @param string $path
   *   Path absoluto allowlisted pelo cliente.
   * @param array<string, scalar> $query
   *   Query allowlisted pelo cliente.
   *
   * @return array<string, mixed>
   *   Objeto JSON sanitizado pelo cliente tipado.
   */
  public function get(string $path, array $query = []): array;

  /**
   * Invalida imediatamente o contexto local.
   */
  public function logout(): void;

}
