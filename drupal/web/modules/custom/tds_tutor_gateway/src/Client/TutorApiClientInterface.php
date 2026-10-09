<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Client;

use Drupal\tds_tutor_gateway\ValueObject\TutorTokenSet;

/**
 * Contrato tipado minimo da FastAPI observado em staging.
 */
interface TutorApiClientInterface {

  /**
   * Autentica CPF/senha sem expor tokens ao chamador web.
   *
   * @return array{
   *   tokens: \Drupal\tds_tutor_gateway\ValueObject\TutorTokenSet,
   *   user: array{id: string, name: string, role: string}
   *   }
   *   Tokens e usuario publico validados.
   */
  public function login(string $cpf, string $password): array;

  /**
   * Rotaciona refresh token de uso unico.
   */
  public function refresh(string $refreshToken): TutorTokenSet;

  /**
   * Busca o contexto publico da identidade autenticada.
   *
   * @return array{id: string, name: string, role: string}
   *   Usuario publico.
   */
  public function me(string $accessToken): array;

  /**
   * Executa GET autenticado somente na superficie operacional permitida.
   *
   * @param string $path
   *   Path operacional allowlisted.
   * @param string $accessToken
   *   Bearer mantido no servidor.
   *
   * @return array<string, mixed>
   *   Objeto JSON sanitizado.
   */
  public function operationsGet(string $path, string $accessToken): array;

  /**
   * Executa POST autenticado somente na superficie operacional permitida.
   *
   * O transporte nunca repete POST automaticamente. Comandos carregam sua
   * propria chave de idempotencia definida pelo chamador.
   *
   * @param string $path
   *   Path operacional allowlisted.
   * @param array<string, mixed> $payload
   *   Corpo JSON.
   * @param string $accessToken
   *   Bearer mantido no servidor.
   *
   * @return array<string, mixed>
   *   Objeto JSON sanitizado.
   */
  public function operationsPost(string $path, array $payload, string $accessToken): array;

}
