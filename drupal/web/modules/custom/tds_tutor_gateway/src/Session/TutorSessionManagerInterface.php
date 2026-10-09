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
   * GET autenticado com refresh transparente e um unico replay seguro.
   *
   * @param string $path
   *   Path operacional allowlisted.
   *
   * @return array<string, mixed>
   *   Resposta operacional.
   */
  public function operationsGet(string $path): array;

  /**
   * POST autenticado com no maximo um replay apos refresh por 401.
   *
   * @param string $path
   *   Path operacional allowlisted.
   * @param array<string, mixed> $payload
   *   Corpo que deve conter idempotencia quando representar comando.
   *
   * @return array<string, mixed>
   *   Resposta operacional.
   */
  public function operationsPost(string $path, array $payload): array;

  /**
   * Invalida imediatamente o contexto local.
   */
  public function logout(): void;

}
