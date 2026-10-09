<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_operator_portal\Kernel;

use Drupal\Core\Form\FormState;
use Drupal\KernelTests\KernelTestBase;
use Drupal\tds_operator_portal\Form\OperationsForm;
use Drupal\tds_operator_portal\Service\OperationsControlPlane;
use Drupal\tds_operator_portal\State\OperationsState;
use Drupal\tds_tutor_gateway\Session\TutorSessionManagerInterface;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\MockObject\MockObject;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Session\Session;
use Symfony\Component\HttpFoundation\Session\Storage\MockArraySessionStorage;

/**
 * Exercita o Form API real sobre o fluxo operacional com gateway simulado.
 */
#[CoversClass(OperationsForm::class)]
#[Group('tds_operator_portal')]
final class OperationsFormKernelTest extends KernelTestBase {

  /**
   * {@inheritdoc}
   */
  protected static $modules = [
    'system',
    'user',
    'tds_tutor_gateway',
    'tds_operator_portal',
  ];

  /**
   * Gateway simulado; a autoridade permanece na API.
   */
  private TutorSessionManagerInterface&MockObject $sessionManager;

  /**
   * Estado privado do fluxo ligado à sessão de teste.
   */
  private OperationsState $state;

  /**
   * {@inheritdoc}
   */
  protected function setUp(): void {
    parent::setUp();
    $stack = $this->container->get('request_stack');
    $request = $stack->getCurrentRequest() ?? Request::create('/operacoes');
    $request->setSession(new Session(new MockArraySessionStorage()));
    if ($stack->getCurrentRequest() === NULL) {
      $stack->push($request);
    }
    $this->state = new OperationsState($stack);
    $this->sessionManager = $this->createMock(TutorSessionManagerInterface::class);
    $this->sessionManager->method('context')->willReturn([
      'id' => 'actor-1',
      'name' => 'Ator QA',
      'role' => 'program_operator',
    ]);
    $this->sessionManager->method('operationsGet')->willReturn([
      'scopes' => [$this->scope()],
    ]);
  }

  /**
   * Regressão: cadastro não pode ser bloqueado pelo radio de busca povoada.
   */
  public function testRegisterAfterPopulatedSearchWithoutPersonSelection(): void {
    $this->seedSearchedPeople();
    $this->sessionManager->expects($this->once())
      ->method('operationsPost')
      ->with('/operations/class-1/commands', self::callback(function (array $payload): bool {
        self::assertSame('register', $payload['action']);
        self::assertArrayNotHasKey('person_id', $payload);
        self::assertArrayNotHasKey('expected_revision', $payload);
        self::assertArrayNotHasKey('identity_proof', $payload);
        self::assertSame('synthetic-password', $payload['registration']['password']);
        self::assertArrayNotHasKey('role', $payload['registration']);
        return TRUE;
      }))
      ->willReturn($this->snapshot('person-new'));

    $form_state = $this->submit([
      'scope_id' => 'class-1',
      'search_group' => ['query' => 'Pessoa QA'],
      'command' => [
        'action' => 'register',
        'reason' => 'cadastro sintetico',
        'registration_name' => 'Pessoa Nova QA',
        'registration_cpf' => '00000000000',
        'registration_phone' => '11999990000',
        'registration_password' => 'synthetic-password',
        'confirm' => 1,
      ],
      'op' => 'Executar operação',
    ]);

    self::assertSame([], $form_state->getErrors());
    self::assertSame('person-new', $this->state->load()['person_id']);
  }

  /**
   * Fail-closed: inspeção sem seleção válida não alcança a API.
   */
  public function testInspectWithoutSelectionIsRejectedBeforeApi(): void {
    $this->seedSearchedPeople();
    $this->sessionManager->expects($this->never())->method('operationsPost');

    $form_state = $this->submit([
      'scope_id' => 'class-1',
      'search_group' => ['query' => 'Pessoa QA'],
      'op' => 'Inspecionar pessoa',
    ]);

    self::assertArrayHasKey('search_group][person_id', $form_state->getErrors());
    self::assertArrayNotHasKey('snapshot', $this->state->load());
  }

  /**
   * Caminho feliz: seleção válida segue para a API com a prova da sessão.
   */
  public function testInspectWithValidSelectionCallsApi(): void {
    $this->seedSearchedPeople();
    $this->sessionManager->expects($this->once())
      ->method('operationsPost')
      ->with('/operations/class-1/inspect', [
        'person_id' => 'person-1',
        'identity_proof' => 'signed-proof',
      ])
      ->willReturn($this->snapshot('person-1'));

    $form_state = $this->submit([
      'scope_id' => 'class-1',
      'search_group' => ['query' => 'Pessoa QA', 'person_id' => 'person-1'],
      'op' => 'Inspecionar pessoa',
    ]);

    self::assertSame([], $form_state->getErrors());
    $saved = $this->state->load();
    self::assertSame('person-1', $saved['person_id']);
    self::assertSame('signed-proof', $saved['identity_proof']);
    self::assertSame(4, $saved['snapshot']['revision']);
  }

  /**
   * Operação sobre pessoa existente continua exigindo inspeção prévia.
   */
  public function testCommandWithoutInspectionIsRejected(): void {
    $this->seedSearchedPeople();
    $this->sessionManager->expects($this->never())->method('operationsPost');

    $form_state = $this->submit([
      'scope_id' => 'class-1',
      'search_group' => ['query' => 'Pessoa QA', 'person_id' => 'person-1'],
      'command' => [
        'action' => 'enroll',
        'reason' => 'vinculo sintetico',
        'confirm' => 1,
      ],
      'op' => 'Executar operação',
    ]);

    self::assertArrayHasKey('command', $form_state->getErrors());
  }

  /**
   * Busca e cadastro usam atributo HTML; não existe '#autocomplete' em FAPI.
   */
  public function testSensitiveInputsUseAutocompleteAttribute(): void {
    $form = $this->form()->buildForm([], new FormState());
    self::assertSame('off', $form['search_group']['query']['#attributes']['autocomplete']);
    self::assertSame('off', $form['command']['registration_name']['#attributes']['autocomplete']);
    self::assertSame('off', $form['command']['registration_cpf']['#attributes']['autocomplete']);
    self::assertSame('off', $form['command']['registration_phone']['#attributes']['autocomplete']);
    self::assertSame('new-password', $form['command']['registration_password']['#attributes']['autocomplete']);
    self::assertArrayNotHasKey('#autocomplete', $form['search_group']['query']);
    self::assertArrayNotHasKey('#autocomplete', $form['command']['registration_password']);
  }

  /**
   * Monta o formulário com control plane real sobre o gateway simulado.
   */
  private function form(): OperationsForm {
    return new OperationsForm(
      new OperationsControlPlane($this->sessionManager, $this->container->get('uuid')),
      $this->state,
    );
  }

  /**
   * Envia o formulário pelo FormBuilder com validação completa.
   *
   * @param array<string, mixed> $values
   *   Valores submetidos, incluindo 'op' para escolher o botão.
   *
   * @return \Drupal\Core\Form\FormState
   *   Estado pós-processamento.
   */
  private function submit(array $values): FormState {
    $form_state = (new FormState())->setValues($values);
    $this->container->get('form_builder')->submitForm($this->form(), $form_state);
    return $form_state;
  }

  /**
   * Simula uma busca exata já concluída nesta sessão.
   */
  private function seedSearchedPeople(): void {
    $this->state->save([
      'scope_id' => 'class-1',
      'people' => [
        ['id' => 'person-1', 'name' => 'Pessoa QA', 'identity_proof' => 'signed-proof'],
      ],
    ]);
  }

  /**
   * Escopo sintético autorizado pela API.
   *
   * @return array<string, string>
   *   Escopo.
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
   * Snapshot sintético devolvido pela API.
   *
   * @param string $personId
   *   Pessoa do snapshot.
   *
   * @return array<string, mixed>
   *   Snapshot.
   */
  private function snapshot(string $personId = 'person-1'): array {
    return [
      'person' => ['id' => $personId, 'name' => 'Pessoa QA'],
      'scope' => $this->scope(),
      'revision' => 4,
      'enrolled' => TRUE,
      'assigned' => TRUE,
      'baseline_linked' => FALSE,
      'history' => [],
    ];
  }

}
