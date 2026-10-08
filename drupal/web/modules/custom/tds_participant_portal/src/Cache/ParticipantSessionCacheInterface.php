<?php

declare(strict_types=1);

namespace Drupal\tds_participant_portal\Cache;

/**
 * Cache privado, curto e isolado pela sessao web atual.
 */
interface ParticipantSessionCacheInterface {

  /**
   * Retorna snapshot fresh apenas para o dono informado.
   *
   * @param string $userId
   *   Identificador opaco do dono retornado pela FastAPI.
   *
   * @return array<string, mixed>|null
   *   Dashboard ou NULL.
   */
  public function fresh(string $userId): ?array;

  /**
   * Retorna snapshot stale ainda valido para o dono, quando informado.
   *
   * @param string|null $userId
   *   Dono esperado ou NULL durante indisponibilidade de /auth/me.
   *
   * @return array<string, mixed>|null
   *   Dashboard ou NULL.
   */
  public function stale(?string $userId = NULL): ?array;

  /**
   * Substitui o snapshot privado da sessao atual.
   *
   * @param string $userId
   *   Identificador opaco do dono retornado pela FastAPI.
   * @param array<string, mixed> $dashboard
   *   Dashboard ja sanitizado.
   */
  public function set(string $userId, array $dashboard): void;

  /**
   * Remove imediatamente qualquer snapshot privado.
   */
  public function clear(): void;

}
