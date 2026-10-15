<?php

declare(strict_types=1);

namespace Drupal\tds_operator_portal\Service;

use Drupal\Component\Uuid\UuidInterface;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Session\TutorSessionManagerInterface;

/**
 * Adaptador fino dos contratos /operations; a autoridade permanece na API.
 */
final class OperationsControlPlane {

  private const ROLES = ['program_operator', 'coordinator', 'admin'];

  public function __construct(
    private readonly TutorSessionManagerInterface $sessionManager,
    private readonly UuidInterface $uuid,
  ) {}

  /**
   * Confirma a persona exibida sem conceder permissao local.
   *
   * @return array{id: string, name: string, role: string}
   *   Contexto publico.
   */
  public function context(): array {
    $context = $this->sessionManager->context();
    if (!in_array($context['role'], self::ROLES, TRUE)) {
      throw new GatewayException('access_denied', 403);
    }
    return $context;
  }

  /**
   * Lista escopos autorizados pela FastAPI.
   *
   * @return array<int, array<string, string>>
   *   Escopos validados.
   */
  public function scopes(): array {
    $payload = $this->sessionManager->operationsGet('/operations/scopes');
    $rows = $payload['scopes'] ?? NULL;
    if (!is_array($rows)) {
      throw new GatewayException('invalid_api_response', 502);
    }
    $scopes = [];
    foreach ($rows as $row) {
      if (!is_array($row)) {
        throw new GatewayException('invalid_api_response', 502);
      }
      $scope = [];
      foreach (['institution_id', 'program_id', 'course_id', 'class_id', 'version_id', 'label'] as $key) {
        if (!is_string($row[$key] ?? NULL) || $row[$key] === '') {
          throw new GatewayException('invalid_api_response', 502);
        }
        $scope[$key] = $row[$key];
      }
      $this->classPath($scope['class_id']);
      $scopes[] = $scope;
    }
    return $scopes;
  }

  /**
   * Busca exata dentro do escopo selecionado.
   *
   * @param array<string, string> $scope
   *   Escopo retornado pela API.
   * @param string $query
   *   Nome no programa ou CPF exato.
   *
   * @return array<int, array{id: string, name: string, identity_proof: string|null}>
   *   Pessoas encontradas.
   */
  public function search(array $scope, string $query): array {
    $query = trim($query);
    if (mb_strlen($query) < 2 || mb_strlen($query) > 100) {
      throw new GatewayException('invalid_request', 422);
    }
    $payload = $this->sessionManager->operationsPost(
      $this->classPath($scope['class_id'] ?? '') . '/search',
      ['query' => $query],
    );
    $rows = $payload['people'] ?? NULL;
    if (!is_array($rows)) {
      throw new GatewayException('invalid_api_response', 502);
    }
    $people = [];
    foreach ($rows as $row) {
      if (!is_array($row) || !is_string($row['id'] ?? NULL) || !is_string($row['name'] ?? NULL)) {
        throw new GatewayException('invalid_api_response', 502);
      }
      $proof = $row['identity_proof'] ?? NULL;
      if ($proof !== NULL && !is_string($proof)) {
        throw new GatewayException('invalid_api_response', 502);
      }
      $people[] = ['id' => $row['id'], 'name' => $row['name'], 'identity_proof' => $proof];
    }
    return $people;
  }

  /**
   * Inspeciona estado e historico atuais.
   *
   * @param array<string, string> $scope
   *   Escopo autorizado.
   * @param string $personId
   *   Identificador opaco da pessoa.
   * @param string|null $identityProof
   *   Prova assinada devolvida pela busca exata.
   *
   * @return array<string, mixed>
   *   Snapshot validado minimamente.
   */
  public function inspect(array $scope, string $personId, ?string $identityProof): array {
    $payload = ['person_id' => $this->identifier($personId)];
    if ($identityProof !== NULL && $identityProof !== '') {
      $payload['identity_proof'] = $identityProof;
    }
    return $this->snapshot($this->sessionManager->operationsPost(
      $this->classPath($scope['class_id'] ?? '') . '/inspect',
      $payload,
    ));
  }

  /**
   * Executa um comando com idempotencia e CAS definidos no servidor web.
   *
   * @param array<string, string> $scope
   *   Escopo autorizado.
   * @param array<string, mixed> $command
   *   Campos especificos do comando.
   *
   * @return array<string, mixed>
   *   Snapshot resultante.
   */
  public function command(array $scope, array $command): array {
    $action = $command['action'] ?? NULL;
    if (!is_string($action) || !in_array($action, ['register', 'enroll', 'assign', 'revoke'], TRUE)) {
      throw new GatewayException('invalid_request', 422);
    }
    $reason = trim((string) ($command['reason'] ?? ''));
    if (mb_strlen($reason) < 3 || mb_strlen($reason) > 500) {
      throw new GatewayException('invalid_request', 422);
    }
    $payload = [
      'id' => is_string($command['id'] ?? NULL) ? $command['id'] : 'drupal-' . $this->uuid->generate(),
      'action' => $action,
      'reason' => $reason,
    ];
    foreach (['institution_id', 'program_id', 'course_id', 'version_id'] as $key) {
      $payload[$key] = $this->identifier((string) ($scope[$key] ?? ''));
    }
    if ($action === 'register') {
      if (!is_array($command['registration'] ?? NULL)) {
        throw new GatewayException('invalid_request', 422);
      }
      $registration = [];
      foreach (['name', 'cpf', 'phone', 'password'] as $key) {
        if (!is_string($command['registration'][$key] ?? NULL) || $command['registration'][$key] === '') {
          throw new GatewayException('invalid_request', 422);
        }
        $registration[$key] = $command['registration'][$key];
      }
      if (is_string($command['registration']['activation_token'] ?? NULL)
        && $command['registration']['activation_token'] !== '') {
        $registration['activation_token'] = $command['registration']['activation_token'];
      }
      $payload['registration'] = $registration;
    }
    else {
      $payload['person_id'] = $this->identifier((string) ($command['person_id'] ?? ''));
      $payload['expected_revision'] = $command['expected_revision'] ?? NULL;
      if (is_string($command['identity_proof'] ?? NULL) && $command['identity_proof'] !== '') {
        $payload['identity_proof'] = $command['identity_proof'];
      }
    }
    return $this->snapshot($this->sessionManager->operationsPost(
      $this->classPath($scope['class_id'] ?? '') . '/commands',
      $payload,
    ));
  }

  /**
   * Cria uma chave idempotente nova para uma intencao confirmada.
   */
  public function commandId(): string {
    return 'drupal-' . $this->uuid->generate();
  }

  /**
   * Retorna o prefixo de path seguro do escopo.
   */
  private function classPath(string $classId): string {
    if (preg_match('/^[A-Za-z0-9_-]{1,36}$/D', $classId) !== 1) {
      throw new GatewayException('invalid_request', 422);
    }
    return '/operations/' . $classId;
  }

  /**
   * Valida identificadores opacos sem permitir estrutura no path/payload.
   */
  private function identifier(string $value): string {
    if ($value === '' || strlen($value) > 36 || preg_match('/^[A-Za-z0-9_-]+$/D', $value) !== 1) {
      throw new GatewayException('invalid_request', 422);
    }
    return $value;
  }

  /**
   * Valida os campos usados pelo fluxo sem reinterpretar autorizacao.
   *
   * @param array<string, mixed> $payload
   *   Resposta da API.
   *
   * @return array<string, mixed>
   *   Snapshot.
   */
  private function snapshot(array $payload): array {
    if (!is_array($payload['person'] ?? NULL)
      || !is_string($payload['person']['id'] ?? NULL)
      || !is_string($payload['person']['name'] ?? NULL)
      || !is_int($payload['revision'] ?? NULL)
      || !is_bool($payload['enrolled'] ?? NULL)
      || !is_bool($payload['assigned'] ?? NULL)
      || !is_array($payload['history'] ?? NULL)) {
      throw new GatewayException('invalid_api_response', 502);
    }
    return $payload;
  }

}
