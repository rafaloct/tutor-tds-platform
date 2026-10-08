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
   * Executa GET autenticado em uma rota de leitura explicitamente permitida.
   *
   * @param string $path
   *   Path absoluto allowlisted, nunca uma URL.
   * @param array<string, scalar> $query
   *   Query allowlisted para a rota.
   * @param string $accessToken
   *   Token mantido exclusivamente no servidor.
   *
   * @return array<string, mixed>
   *   Objeto JSON validado.
   */
  public function get(string $path, array $query, string $accessToken): array;

}
