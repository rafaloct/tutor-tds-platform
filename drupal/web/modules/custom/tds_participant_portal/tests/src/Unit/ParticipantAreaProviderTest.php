<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_participant_portal\Unit;

use Drupal\Tests\UnitTestCase;
use Drupal\tds_participant_portal\Cache\ParticipantSessionCacheInterface;
use Drupal\tds_participant_portal\Service\ParticipantAreaProvider;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Session\TutorSessionManagerInterface;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;

/**
 * Cobre autoridade, revogacao, carteira, cache e degradacao da area privada.
 */
#[CoversClass(ParticipantAreaProvider::class)]
#[Group('tds_participant_portal')]
final class ParticipantAreaProviderTest extends UnitTestCase {

  /**
   * Duas turmas e certificado usam somente campos allowlisted da FastAPI.
   */
  public function testTwoClassesAndCertificateAreProjectedWithoutPrivateFields(): void {
    $session = new FakeParticipantSessionManager($this->responses([
      $this->classroom('class-a', 'Turma A'),
      $this->classroom('class-b', 'Turma B'),
    ], [$this->certificate()]));
    $cache = new MemoryParticipantCache();

    $result = (new ParticipantAreaProvider($session, $cache))->dashboard();

    self::assertSame('fresh', $result['state']);
    self::assertCount(2, $result['classes']);
    self::assertSame(25.0, $result['classes'][0]['progress']['progress_percent']);
    self::assertArrayNotHasKey('membership_id', $result['classes'][0]['progress']);
    self::assertCount(1, $result['certificates']);
    self::assertArrayNotHasKey('content_hash', $result['certificates'][0]);
    self::assertArrayNotHasKey('user_id', $result['certificates'][0]);
    self::assertSame('user-1', $cache->owner);
  }

  /**
   * Conta sem turma/certificado preserva estados vazios honestos.
   */
  public function testEmptyAccountIsNotInvented(): void {
    $provider = new ParticipantAreaProvider(
      new FakeParticipantSessionManager($this->responses([], [])),
      new MemoryParticipantCache(),
    );

    $result = $provider->dashboard();

    self::assertSame([], $result['classes']);
    self::assertSame([], $result['certificates']);
  }

  /**
   * Revogacao/negacao vence uma listagem recebida anteriormente.
   */
  public function testRevokedClassIsNotRendered(): void {
    $responses = $this->responses([$this->classroom('revoked', 'Revogada')], []);
    $responses['/classes/revoked/learning-context'] = new GatewayException('access_denied', 403);
    $provider = new ParticipantAreaProvider(
      new FakeParticipantSessionManager($responses),
      new MemoryParticipantCache(),
    );

    self::assertSame([], $provider->dashboard()['classes']);
  }

  /**
   * Conflito de linhagem fica explicito e nao fabrica progresso.
   */
  public function testContextConflictDoesNotCalculateProgress(): void {
    $responses = $this->responses([$this->classroom('needs-review', 'Conferir')], []);
    $responses['/classes/needs-review/learning-context'] = new GatewayException('context_conflict', 409);
    $provider = new ParticipantAreaProvider(
      new FakeParticipantSessionManager($responses),
      new MemoryParticipantCache(),
    );

    $class = $provider->dashboard()['classes'][0];
    self::assertSame('needs_review', $class['state']);
    self::assertNull($class['progress']);
  }

  /**
   * Referencia pertencente a outra conta falha fechada.
   */
  public function testOtherUsersCertificateIsRejected(): void {
    $certificate = $this->certificate();
    $certificate['user_id'] = 'user-2';
    $provider = new ParticipantAreaProvider(
      new FakeParticipantSessionManager($this->responses([], [$certificate])),
      new MemoryParticipantCache(),
    );

    $this->expectException(GatewayException::class);
    $this->expectExceptionMessage('invalid_api_response');
    $provider->dashboard();
  }

  /**
   * API offline pode usar apenas stale privado ainda dentro da janela.
   */
  public function testOfflineUsesPrivateStaleSnapshot(): void {
    $session = new FakeParticipantSessionManager([]);
    $session->contextError = new GatewayException('api_unavailable', 503);
    $cache = new MemoryParticipantCache();
    $cache->stale = [
      'user' => ['name' => 'Pessoa QA', 'role' => 'student'],
      'classes' => [],
      'certificates' => [],
    ];

    $result = (new ParticipantAreaProvider($session, $cache))->dashboard();

    self::assertSame('stale', $result['state']);
    self::assertSame('Pessoa QA', $result['user']['name']);
  }

  /**
   * Retorna payloads sinteticos por rota.
   *
   * @param array<int, array<string, mixed>> $classes
   *   Turmas.
   * @param array<int, array<string, mixed>> $certificates
   *   Certificados.
   *
   * @return array<string, mixed>
   *   Mapa de respostas.
   */
  private function responses(array $classes, array $certificates): array {
    $responses = [
      '/classes?enrolled_only=true' => ['classes' => $classes],
      '/certificates' => ['certificates' => $certificates],
    ];
    foreach ($classes as $class) {
      $responses['/classes/' . $class['id'] . '/learning-context'] = [
        'context' => ['user_id' => 'user-1', 'role' => 'student'],
        'progress' => [
          'status' => 'active',
          'planned_hours' => 80.0,
          'validated_hours' => 20.0,
          'progress_percent' => 25.0,
          'last_activity_at' => '2026-10-08T12:00:00Z',
          'private_note' => 'never render',
        ],
      ];
      $responses['/classes/' . $class['id'] . '/course'] = [
        'title' => 'Curso ' . $class['id'],
        'author' => 'TDS',
        'summary' => 'Resumo permitido.',
        'sections' => [['private' => 'not rendered']],
      ];
    }
    return $responses;
  }

  /**
   * Cria uma turma sintetica.
   *
   * @return array<string, mixed>
   *   Turma sintetica.
   */
  private function classroom(string $id, string $name): array {
    return [
      'id' => $id,
      'name' => $name,
      'course_id' => 'course',
      'course_version_id' => 'version-private',
      'teacher_id' => 'teacher-private',
      'status' => 'active',
      'start_date' => '2026-10-01',
      'end_date' => '2026-10-31',
      'offer_municipality' => 'Palmas',
      'offer_location' => NULL,
    ];
  }

  /**
   * Cria um certificado sintetico.
   *
   * @return array<string, mixed>
   *   Certificado sintetico.
   */
  private function certificate(): array {
    return [
      'id' => 'certificate-private-id',
      'user_id' => 'user-1',
      'program_id' => 'program-private',
      'course_id' => 'course-private',
      'class_id' => 'class-private',
      'course_title' => 'Curso TDS',
      'institution_name' => 'IPEX',
      'planned_hours' => 80.0,
      'issued_at' => '2026-10-08T12:00:00Z',
      'verification_url' => 'https://cert.example.test/v1/certificates/reference',
      'content_hash' => str_repeat('a', 64),
    ];
  }

}

/**
 * Sessao fake deterministica por rota.
 */
final class FakeParticipantSessionManager implements TutorSessionManagerInterface {

  /**
   * Erro opcional de contexto.
   */
  public ?GatewayException $contextError = NULL;

  /**
   * Cria a sessao fake.
   *
   * @param array<string, mixed> $responses
   *   Respostas ou excecoes por rota.
   */
  public function __construct(
    private readonly array $responses,
  ) {}

  /**
   * {@inheritdoc}
   */
  public function login(string $cpf, string $password): array {
    throw new \LogicException('Nao usado.');
  }

  /**
   * {@inheritdoc}
   */
  public function context(): array {
    if ($this->contextError !== NULL) {
      throw $this->contextError;
    }
    return ['id' => 'user-1', 'name' => 'Pessoa QA', 'role' => 'student'];
  }

  /**
   * {@inheritdoc}
   */
  public function get(string $path, array $query = []): array {
    $key = $query === [] ? $path : $path . '?' . http_build_query($query);
    $response = $this->responses[$key] ?? NULL;
    if ($response instanceof GatewayException) {
      throw $response;
    }
    if (!is_array($response)) {
      throw new \LogicException('Resposta fake ausente: ' . $key);
    }
    return $response;
  }

  /**
   * {@inheritdoc}
   */
  public function logout(): void {}

}

/**
 * Cache fake sem persistencia externa.
 */
final class MemoryParticipantCache implements ParticipantSessionCacheInterface {

  /**
   * Snapshot stale opcional.
   *
   * @var array<string, mixed>|null
   */
  public ?array $stale = NULL;

  /**
   * Owner gravado.
   */
  public ?string $owner = NULL;

  /**
   * Snapshot gravado.
   *
   * @var array<string, mixed>|null
   */
  private ?array $dashboard = NULL;

  /**
   * {@inheritdoc}
   */
  public function fresh(string $userId): ?array {
    return $this->owner === $userId ? $this->dashboard : NULL;
  }

  /**
   * {@inheritdoc}
   */
  public function stale(?string $userId = NULL): ?array {
    return $this->stale;
  }

  /**
   * {@inheritdoc}
   */
  public function set(string $userId, array $dashboard): void {
    $this->owner = $userId;
    $this->dashboard = $dashboard;
  }

  /**
   * {@inheritdoc}
   */
  public function clear(): void {
    $this->owner = NULL;
    $this->dashboard = NULL;
    $this->stale = NULL;
  }

}
