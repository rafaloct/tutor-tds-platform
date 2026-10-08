<?php

declare(strict_types=1);

namespace Drupal\tds_participant_portal\Service;

use Drupal\tds_participant_portal\Cache\ParticipantSessionCacheInterface;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Session\TutorSessionManagerInterface;

/**
 * Agrega somente projecoes allowlisted da FastAPI para o proprio participante.
 */
final class ParticipantAreaProvider implements ParticipantAreaProviderInterface {

  /**
   * Construtor.
   */
  public function __construct(
    private readonly TutorSessionManagerInterface $sessionManager,
    private readonly ParticipantSessionCacheInterface $cache,
  ) {}

  /**
   * {@inheritdoc}
   */
  public function dashboard(): array {
    try {
      $user = $this->sessionManager->context();
    }
    catch (GatewayException $error) {
      if ($error->httpStatus() === 503 && ($stale = $this->cache->stale()) !== NULL) {
        return $stale + ['state' => 'stale'];
      }
      throw $error;
    }

    $fresh = $this->cache->fresh($user['id']);
    if ($fresh !== NULL) {
      return $fresh + ['state' => 'fresh'];
    }

    try {
      $dashboard = $this->fetch($user);
      $this->cache->set($user['id'], $dashboard);
      return $dashboard + ['state' => 'fresh'];
    }
    catch (GatewayException $error) {
      if ($error->httpStatus() === 503 && ($stale = $this->cache->stale($user['id'])) !== NULL) {
        return $stale + ['state' => 'stale'];
      }
      throw $error;
    }
  }

  /**
   * Consulta os tres contratos e reduz cada payload ao necessario para a UI.
   *
   * @param array{id: string, name: string, role: string} $user
   *   Usuario retornado por /auth/me.
   *
   * @return array<string, mixed>
   *   Dashboard sanitizado, sem state de cache.
   */
  private function fetch(array $user): array {
    $page = $this->sessionManager->get('/classes', ['enrolled_only' => 'true']);
    $rawClasses = $page['classes'] ?? NULL;
    if (!is_array($rawClasses) || !array_is_list($rawClasses)) {
      throw new GatewayException('invalid_api_response', 502);
    }

    $classes = [];
    foreach ($rawClasses as $rawClass) {
      $class = $this->classroom($rawClass);
      try {
        $snapshot = $this->sessionManager->get('/classes/' . $class['id'] . '/learning-context');
        $course = $this->sessionManager->get('/classes/' . $class['id'] . '/course');
        $class['progress'] = $this->progress($snapshot, $user['id']);
        $class['course'] = $this->course($course);
        $class['state'] = 'available';
      }
      catch (GatewayException $error) {
        if (in_array($error->httpStatus(), [403, 404], TRUE)) {
          // Revogacao/escopo negado vence a listagem recebida anteriormente.
          continue;
        }
        if ($error->httpStatus() === 409) {
          $class['progress'] = NULL;
          $class['course'] = NULL;
          $class['state'] = 'needs_review';
        }
        else {
          throw $error;
        }
      }
      $classes[] = $class;
    }

    $certificatePage = $this->sessionManager->get('/certificates');
    $rawCertificates = $certificatePage['certificates'] ?? NULL;
    if (!is_array($rawCertificates) || !array_is_list($rawCertificates)) {
      throw new GatewayException('invalid_api_response', 502);
    }
    $certificates = [];
    foreach ($rawCertificates as $rawCertificate) {
      $certificates[] = $this->certificate($rawCertificate, $user['id']);
    }

    return [
      'user' => [
        'name' => $user['name'],
        'role' => $user['role'],
      ],
      'classes' => $classes,
      'certificates' => $certificates,
    ];
  }

  /**
   * Valida e reduz uma turma.
   *
   * @return array<string, mixed>
   *   Turma allowlisted.
   */
  private function classroom(mixed $payload): array {
    if (!is_array($payload)) {
      throw new GatewayException('invalid_api_response', 502);
    }
    $required = ['id', 'name', 'course_id', 'status', 'start_date', 'end_date'];
    foreach ($required as $key) {
      if (!is_string($payload[$key] ?? NULL) || $payload[$key] === '') {
        throw new GatewayException('invalid_api_response', 502);
      }
    }
    if (preg_match('/^[A-Za-z0-9][A-Za-z0-9_-]{0,119}$/D', $payload['id']) !== 1) {
      throw new GatewayException('invalid_api_response', 502);
    }
    return [
      'id' => $payload['id'],
      'name' => $payload['name'],
      'status' => $payload['status'],
      'start_date' => $payload['start_date'],
      'end_date' => $payload['end_date'],
      'municipality' => is_string($payload['offer_municipality'] ?? NULL) ? $payload['offer_municipality'] : NULL,
      'location' => is_string($payload['offer_location'] ?? NULL) ? $payload['offer_location'] : NULL,
    ];
  }

  /**
   * Valida a projecao de progresso do proprio participante.
   *
   * @return array<string, mixed>
   *   Progresso calculado exclusivamente pela FastAPI.
   */
  private function progress(mixed $payload, string $userId): array {
    if (!is_array($payload)
      || !is_array($payload['context'] ?? NULL)
      || ($payload['context']['user_id'] ?? NULL) !== $userId
      || ($payload['context']['role'] ?? NULL) !== 'student'
      || !is_array($payload['progress'] ?? NULL)) {
      throw new GatewayException('invalid_api_response', 502);
    }
    $progress = $payload['progress'];
    $percent = $progress['progress_percent'] ?? NULL;
    if ((!is_int($percent) && !is_float($percent)) || $percent < 0 || $percent > 100) {
      throw new GatewayException('invalid_api_response', 502);
    }
    return [
      'status' => is_string($progress['status'] ?? NULL) ? $progress['status'] : 'unknown',
      'planned_hours' => $this->numberOrNull($progress['planned_hours'] ?? NULL),
      'validated_hours' => $this->numberOrNull($progress['validated_hours'] ?? NULL),
      'progress_percent' => $percent,
      'last_activity_at' => is_string($progress['last_activity_at'] ?? NULL) ? $progress['last_activity_at'] : NULL,
    ];
  }

  /**
   * Reduz o curso fixado pela turma.
   *
   * @return array<string, string|null>
   *   Metadados de curso permitidos para a area web.
   */
  private function course(mixed $payload): array {
    if (!is_array($payload) || !is_string($payload['title'] ?? NULL) || $payload['title'] === '') {
      throw new GatewayException('invalid_api_response', 502);
    }
    return [
      'title' => $payload['title'],
      'author' => is_string($payload['author'] ?? NULL) ? $payload['author'] : NULL,
      'summary' => is_string($payload['summary'] ?? NULL) ? $payload['summary'] : NULL,
    ];
  }

  /**
   * Valida e reduz uma referencia oficial de certificado.
   *
   * @return array<string, mixed>
   *   Referencia publica do proprio titular, sem hash ou IDs internos.
   */
  private function certificate(mixed $payload, string $userId): array {
    if (!is_array($payload)
      || ($payload['user_id'] ?? NULL) !== $userId
      || !is_string($payload['issued_at'] ?? NULL)
      || !is_string($payload['verification_url'] ?? NULL)) {
      throw new GatewayException('invalid_api_response', 502);
    }
    $parts = parse_url($payload['verification_url']);
    if (!is_array($parts)
      || strtolower((string) ($parts['scheme'] ?? '')) !== 'https'
      || ($parts['host'] ?? '') === ''
      || isset($parts['user'])
      || isset($parts['pass'])) {
      throw new GatewayException('invalid_api_response', 502);
    }
    return [
      'course_title' => is_string($payload['course_title'] ?? NULL) ? $payload['course_title'] : 'Curso TDS',
      'institution_name' => is_string($payload['institution_name'] ?? NULL) ? $payload['institution_name'] : NULL,
      'planned_hours' => $this->numberOrNull($payload['planned_hours'] ?? NULL),
      'issued_at' => $payload['issued_at'],
      'verification_url' => $payload['verification_url'],
    ];
  }

  /**
   * Converte numero finito ou retorna NULL.
   */
  private function numberOrNull(mixed $value): int|float|null {
    return is_int($value) || (is_float($value) && is_finite($value)) ? $value : NULL;
  }

}
