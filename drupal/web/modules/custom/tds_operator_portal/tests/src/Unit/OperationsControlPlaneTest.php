<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_operator_portal\Unit;

use Drupal\Component\Uuid\UuidInterface;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_operator_portal\Service\OperationsControlPlane;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Session\TutorSessionManagerInterface;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Group;

/**
 * Verifica que o Drupal preserva contratos, escopo, CAS e idempotencia.
 */
#[CoversClass(OperationsControlPlane::class)]
#[Group('tds_operator_portal')]
final class OperationsControlPlaneTest extends UnitTestCase {

  /**
   * Personas operacionais sao exibidas, mas continuam autorizadas pela API.
   */
  #[DataProvider('allowedRoleProvider')]
  public function testOperatorCoordinatorAndAdminCanEnter(string $role): void {
    $session = $this->createMock(TutorSessionManagerInterface::class);
    $session->method('context')->willReturn(['id' => 'actor', 'name' => 'Ator QA', 'role' => $role]);
    self::assertSame($role, $this->service($session)->context()['role']);
  }

  /**
   * Papeis nao operacionais nunca ganham autoridade local no Drupal.
   */
  public function testStudentIsDeniedLocallyBeforeOperations(): void {
    $session = $this->createMock(TutorSessionManagerInterface::class);
    $session->method('context')->willReturn(['id' => 'student', 'name' => 'Aluno QA', 'role' => 'student']);
    $session->expects(self::never())->method('operationsGet');
    $this->expectException(GatewayException::class);
    $this->expectExceptionMessage('access_denied');
    $this->service($session)->context();
  }

  /**
   * Busca e inspeção propagam a prova sem apresenta-la ao browser.
   */
  public function testExactSearchAndInspectPreserveIdentityProof(): void {
    $session = $this->createMock(TutorSessionManagerInterface::class);
    $session->expects(self::exactly(2))->method('operationsPost')
      ->willReturnCallback(function (string $path, array $payload): array {
        if (str_ends_with($path, '/search')) {
          self::assertSame(['query' => '00000000000'], $payload);
          return ['people' => [['id' => 'person-1', 'name' => 'Pessoa QA', 'identity_proof' => 'signed-proof']]];
        }
        self::assertSame(['person_id' => 'person-1', 'identity_proof' => 'signed-proof'], $payload);
        return $this->snapshot();
      });
    $service = $this->service($session);
    $people = $service->search($this->scope(), '00000000000');
    self::assertSame('person-1', $service->inspect($this->scope(), $people[0]['id'], $people[0]['identity_proof'])['person']['id']);
  }

  /**
   * O payload inclui escopo completo, revisao esperada e id estável.
   */
  public function testCommandPreservesScopeCasAndIdempotency(): void {
    $session = $this->createMock(TutorSessionManagerInterface::class);
    $session->expects(self::exactly(2))->method('operationsPost')
      ->with('/operations/class-1/commands', self::callback(function (array $payload): bool {
        self::assertSame('fixed-command-id-0001', $payload['id']);
        self::assertSame(4, $payload['expected_revision']);
        self::assertSame('institution-1', $payload['institution_id']);
        self::assertSame('program-1', $payload['program_id']);
        self::assertSame('course-1', $payload['course_id']);
        self::assertSame('version-1', $payload['version_id']);
        return TRUE;
      }))
      ->willReturn($this->snapshot());
    $command = [
      'id' => 'fixed-command-id-0001',
      'action' => 'assign',
      'reason' => 'evidencia sintetica',
      'person_id' => 'person-1',
      'identity_proof' => 'proof',
      'expected_revision' => 4,
    ];
    $service = $this->service($session);
    // O segundo retorno representa replay identico resolvido pela FastAPI.
    self::assertSame($service->command($this->scope(), $command), $service->command($this->scope(), $command));
  }

  /**
   * Escopo errado, stale revision, replay divergente e capacidade ficam 409.
   */
  #[DataProvider('conflictProvider')]
  public function testApiConflictsRemainConflicts(string $case): void {
    $session = $this->createMock(TutorSessionManagerInterface::class);
    $session->method('operationsPost')->willThrowException(new GatewayException('operation_conflict', 409));
    try {
      $this->service($session)->command($this->scope(), [
        'id' => 'conflict-command-0001',
        'action' => 'enroll',
        'reason' => 'cenario ' . $case,
        'person_id' => 'person-1',
        'expected_revision' => 3,
      ]);
      self::fail('Era esperado conflito: ' . $case);
    }
    catch (GatewayException $error) {
      self::assertSame(409, $error->httpStatus());
      self::assertSame('operation_conflict', $error->publicCode());
    }
  }

  /**
   * Escopo malformado e bloqueado antes da rede.
   */
  public function testUnsafeScopeIsRejectedBeforeRequest(): void {
    $session = $this->createMock(TutorSessionManagerInterface::class);
    $session->expects(self::never())->method('operationsPost');
    $scope = $this->scope();
    $scope['class_id'] = '../other';
    $this->expectException(GatewayException::class);
    $this->service($session)->search($scope, 'Pessoa QA');
  }

  /**
   * Registro nao aceita papel local e encaminha senha uma vez.
   */
  public function testRegistrationPayloadIsForwardedWithoutRoleEscalation(): void {
    $session = $this->createMock(TutorSessionManagerInterface::class);
    $session->expects(self::once())->method('operationsPost')
      ->with('/operations/class-1/commands', self::callback(function (array $payload): bool {
        self::assertArrayNotHasKey('role', $payload['registration']);
        self::assertSame('synthetic-password', $payload['registration']['password']);
        self::assertArrayNotHasKey('person_id', $payload);
        return TRUE;
      }))
      ->willReturn($this->snapshot());
    $this->service($session)->command($this->scope(), [
      'id' => 'register-command-0001',
      'action' => 'register',
      'reason' => 'cadastro sintetico',
      'registration' => [
        'name' => 'Pessoa QA',
        'cpf' => '00000000000',
        'phone' => '00000000000',
        'password' => 'synthetic-password',
        'role' => 'admin',
      ],
    ]);
  }

  /**
   * Personas aceitas para apresentacao.
   *
   * @return array<string, array{string}>
   *   Casos.
   */
  public static function allowedRoleProvider(): array {
    return [
      'operator' => ['program_operator'],
      'coordinator' => ['coordinator'],
      'admin' => ['admin'],
    ];
  }

  /**
   * Gates 409 mantidos pela camada web.
   *
   * @return array<string, array{string}>
   *   Casos.
   */
  public static function conflictProvider(): array {
    return [
      'wrong scope' => ['wrong-scope'],
      'stale revision' => ['stale-revision'],
      'divergent replay' => ['divergent-replay'],
      'capacity' => ['capacity'],
    ];
  }

  /**
   * Cria o servico com UUID deterministico.
   */
  private function service(TutorSessionManagerInterface $session): OperationsControlPlane {
    $uuid = $this->createMock(UuidInterface::class);
    $uuid->method('generate')->willReturn('00000000-0000-4000-8000-000000000167');
    return new OperationsControlPlane($session, $uuid);
  }

  /**
   * Retorna um escopo sintetico.
   *
   * @return array<string, string>
   *   Escopo sintetico.
   */
  private function scope(): array {
    return [
      'institution_id' => 'institution-1',
      'program_id' => 'program-1',
      'course_id' => 'course-1',
      'class_id' => 'class-1',
      'version_id' => 'version-1',
      'label' => 'Programa QA / Turma QA',
    ];
  }

  /**
   * Retorna um snapshot sintetico.
   *
   * @return array<string, mixed>
   *   Snapshot sintetico.
   */
  private function snapshot(): array {
    return [
      'person' => ['id' => 'person-1', 'name' => 'Pessoa QA'],
      'scope' => $this->scope(),
      'revision' => 4,
      'enrolled' => TRUE,
      'assigned' => TRUE,
      'baseline_linked' => FALSE,
      'history' => [],
    ];
  }

}
