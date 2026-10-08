<?php

declare(strict_types=1);

namespace Drupal\tds_operator_portal\Form;

use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\tds_operator_portal\Service\OperationsControlPlane;
use Drupal\tds_operator_portal\State\OperationsState;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Jornada web: escopo, busca, inspeção, confirmação, comando e histórico.
 */
final class OperationsForm extends FormBase {

  public function __construct(
    private readonly OperationsControlPlane $controlPlane,
    private readonly OperationsState $operationsState,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static(
      $container->get('tds_operator_portal.control_plane'),
      $container->get('tds_operator_portal.state'),
    );
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId(): string {
    return 'tds_operator_portal_operations';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state): array {
    $form['#attached']['library'][] = 'tds_operator_portal/operations';
    $form['#attributes']['class'][] = 'tds-operations';
    $form['intro'] = [
      '#markup' => '<p>' . $this->t('Selecione um escopo autorizado, localize a pessoa, confira o estado e confirme uma única operação. A autorização final é sempre da API acadêmica.') . '</p>',
    ];

    try {
      $context = $this->controlPlane->context();
      $scopes = $this->controlPlane->scopes();
    }
    catch (GatewayException $error) {
      if ($error->httpStatus() === 401 || $error->httpStatus() === 403) {
        $this->operationsState->clear();
      }
      $form['blocked'] = $this->errorBox($error);
      return $form;
    }

    $state = $this->operationsState->load();
    $scopeOptions = [];
    $scopeMap = [];
    foreach ($scopes as $scope) {
      $scopeOptions[$scope['class_id']] = $scope['label'];
      $scopeMap[$scope['class_id']] = $scope;
    }
    if ($scopeOptions === []) {
      $form['blocked'] = ['#markup' => '<p class="tds-operations__status">' . $this->t('Nenhum escopo operacional foi autorizado para esta sessão.') . '</p>'];
      return $form;
    }

    $selectedScope = (string) ($state['scope_id'] ?? array_key_first($scopeOptions));
    if (!isset($scopeMap[$selectedScope])) {
      $selectedScope = (string) array_key_first($scopeOptions);
      $state = [];
    }
    $state['scope_id'] = $selectedScope;
    $state['scope'] = $scopeMap[$selectedScope];
    $this->operationsState->save($state);

    $form['actor'] = [
      '#markup' => '<p class="tds-operations__status">' . $this->t('Sessão: @name (@role)', [
        '@name' => $context['name'],
        '@role' => $context['role'],
      ]) . '</p>',
    ];
    $form['scope_id'] = [
      '#type' => 'select',
      '#title' => $this->t('Escopo'),
      '#options' => $scopeOptions,
      '#default_value' => $selectedScope,
      '#required' => TRUE,
    ];
    $form['change_scope'] = [
      '#type' => 'submit',
      '#value' => $this->t('Aplicar escopo'),
      '#submit' => ['::changeScope'],
      '#limit_validation_errors' => [['scope_id']],
    ];

    $form['search_group'] = [
      '#type' => 'fieldset',
      '#title' => $this->t('1. Busca exata'),
      '#tree' => TRUE,
    ];
    $form['search_group']['query'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Nome no programa ou CPF exato'),
      '#description' => $this->t('Use CPF somente quando necessário para localizar uma identidade fora do programa.'),
      '#maxlength' => 100,
      '#default_value' => '',
      '#autocomplete' => 'off',
    ];
    $form['search_group']['search'] = [
      '#type' => 'submit',
      '#value' => $this->t('Buscar'),
      '#submit' => ['::search'],
      '#limit_validation_errors' => [['search_group', 'query']],
    ];

    $people = is_array($state['people'] ?? NULL) ? $state['people'] : [];
    if ($people !== []) {
      $options = [];
      foreach ($people as $person) {
        if (is_array($person) && is_string($person['id'] ?? NULL) && is_string($person['name'] ?? NULL)) {
          $options[$person['id']] = $person['name'];
        }
      }
      $form['search_group']['person_id'] = [
        '#type' => 'radios',
        '#title' => $this->t('Resultado'),
        '#options' => $options,
        '#default_value' => $state['person_id'] ?? NULL,
        '#required' => TRUE,
      ];
      $form['search_group']['inspect'] = [
        '#type' => 'submit',
        '#value' => $this->t('Inspecionar pessoa'),
        '#submit' => ['::inspect'],
        '#limit_validation_errors' => [['search_group', 'person_id']],
      ];
    }
    elseif (array_key_exists('people', $state)) {
      $form['search_group']['empty'] = ['#markup' => '<p>' . $this->t('Nenhuma pessoa localizada. Para criar uma identidade, use o comando cadastrar abaixo.') . '</p>'];
    }

    $snapshot = is_array($state['snapshot'] ?? NULL) ? $state['snapshot'] : NULL;
    if ($snapshot !== NULL) {
      $form['snapshot'] = $this->snapshot($snapshot);
    }
    $form['command'] = $this->commandElements($snapshot, $state);
    return $form;
  }

  /**
   * Troca de escopo invalida toda prova e snapshot anteriores.
   */
  public function changeScope(array &$form, FormStateInterface $form_state): void {
    $this->operationsState->save(['scope_id' => (string) $form_state->getValue('scope_id')]);
    $form_state->setRebuild();
  }

  /**
   * Executa busca e conserva provas somente na sessao server-side.
   */
  public function search(array &$form, FormStateInterface $form_state): void {
    $state = $this->operationsState->load();
    try {
      $state['people'] = $this->controlPlane->search(
        $state['scope'],
        (string) $form_state->getValue(['search_group', 'query']),
      );
      unset($state['person_id'], $state['snapshot'], $state['command_id']);
      $this->operationsState->save($state);
    }
    catch (GatewayException $error) {
      $this->messenger()->addError($this->message($error));
    }
    $form_state->setRebuild();
  }

  /**
   * Inspeciona a pessoa selecionada usando a prova guardada no servidor.
   */
  public function inspect(array &$form, FormStateInterface $form_state): void {
    $state = $this->operationsState->load();
    $personId = (string) $form_state->getValue(['search_group', 'person_id']);
    $proof = NULL;
    foreach (($state['people'] ?? []) as $person) {
      if (is_array($person) && ($person['id'] ?? NULL) === $personId) {
        $proof = is_string($person['identity_proof'] ?? NULL) ? $person['identity_proof'] : NULL;
        break;
      }
    }
    try {
      $state['snapshot'] = $this->controlPlane->inspect($state['scope'], $personId, $proof);
      $state['person_id'] = $personId;
      $state['identity_proof'] = $proof;
      unset($state['command_id']);
      $this->operationsState->save($state);
    }
    catch (GatewayException $error) {
      $this->messenger()->addError($this->message($error));
    }
    $form_state->setRebuild();
  }

  /**
   * {@inheritdoc}
   */
  public function validateForm(array &$form, FormStateInterface $form_state): void {
    $trigger = $form_state->getTriggeringElement()['#name'] ?? '';
    if ($trigger !== 'op') {
      return;
    }
    $action = (string) $form_state->getValue(['command', 'action']);
    if ($form_state->getValue(['command', 'confirm']) !== 1) {
      $form_state->setErrorByName('command][confirm', $this->t('Confirme que revisou o escopo e o estado atual.'));
    }
    if ($action === 'revoke' && $form_state->getValue(['command', 'confirm_revoke']) !== 1) {
      $form_state->setErrorByName('command][confirm_revoke', $this->t('Revogação exige confirmação específica.'));
    }
    if ($action !== 'register' && !is_array($this->operationsState->load()['snapshot'] ?? NULL)) {
      $form_state->setErrorByName('command', $this->t('Inspecione a pessoa antes desta operação.'));
    }
    if ($action === 'register') {
      foreach (['registration_name', 'registration_cpf', 'registration_phone', 'registration_password'] as $field) {
        if (trim((string) $form_state->getValue(['command', $field])) === '') {
          $form_state->setErrorByName('command][' . $field, $this->t('Preencha todos os dados do cadastro.'));
        }
      }
    }
  }

  /**
   * Envia o comando confirmado e apresenta o snapshot retornado pela API.
   */
  public function submitForm(array &$form, FormStateInterface $form_state): void {
    $state = $this->operationsState->load();
    $action = (string) $form_state->getValue(['command', 'action']);
    $commandId = is_string($state['command_id'] ?? NULL) ? $state['command_id'] : $this->controlPlane->commandId();
    $state['command_id'] = $commandId;
    $this->operationsState->save($state);
    $command = [
      'id' => $commandId,
      'action' => $action,
      'reason' => (string) $form_state->getValue(['command', 'reason']),
    ];
    if ($action === 'register') {
      $command['registration'] = [
        'name' => (string) $form_state->getValue(['command', 'registration_name']),
        'cpf' => (string) $form_state->getValue(['command', 'registration_cpf']),
        'phone' => (string) $form_state->getValue(['command', 'registration_phone']),
        'password' => (string) $form_state->getValue(['command', 'registration_password']),
      ];
    }
    else {
      $command += [
        'person_id' => $state['person_id'],
        'identity_proof' => $state['identity_proof'] ?? NULL,
        'expected_revision' => $state['snapshot']['revision'],
      ];
    }
    try {
      $state['snapshot'] = $this->controlPlane->command($state['scope'], $command);
      $state['person_id'] = $state['snapshot']['person']['id'];
      unset($state['command_id']);
      $this->operationsState->save($state);
      $this->messenger()->addStatus($this->t('Operação concluída e estado atualizado pela API.'));
    }
    catch (GatewayException $error) {
      // command_id fica estável para replay idêntico após conflito de rede.
      $this->messenger()->addError($this->message($error));
    }
    $form_state->setRebuild();
  }

  /**
   * Monta controles de comando com confirmação explícita.
   *
   * @param array<string, mixed>|null $snapshot
   *   Estado inspecionado.
   * @param array<string, mixed> $state
   *   Fluxo privado.
   *
   * @return array<string, mixed>
   *   Elementos Form API.
   */
  private function commandElements(?array $snapshot, array $state): array {
    $elements = [
      '#type' => 'fieldset',
      '#title' => $this->t('3. Confirmar operação'),
      '#tree' => TRUE,
      'action' => [
        '#type' => 'select',
        '#title' => $this->t('Ação'),
        '#options' => [
          'enroll' => $this->t('Matricular no curso'),
          'assign' => $this->t('Vincular à turma'),
          'revoke' => $this->t('Revogar vínculo'),
          'register' => $this->t('Cadastrar nova identidade'),
        ],
      ],
      'reason' => [
        '#type' => 'textarea',
        '#title' => $this->t('Motivo auditável'),
        '#required' => TRUE,
        '#maxlength' => 500,
      ],
    ];
    foreach ([
      'registration_name' => [$this->t('Nome completo'), 'textfield'],
      'registration_cpf' => [$this->t('CPF'), 'textfield'],
      'registration_phone' => [$this->t('Telefone'), 'tel'],
      'registration_password' => [$this->t('Senha inicial'), 'password'],
    ] as $key => [$title, $type]) {
      $elements[$key] = [
        '#type' => $type,
        '#title' => $title,
        '#states' => [
          'visible' => [
            ':input[name="command[action]"]' => ['value' => 'register'],
          ],
        ],
        '#autocomplete' => 'off',
      ];
    }
    $elements['confirm'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Revisei o escopo, a pessoa e o estado atual.'),
      '#required' => TRUE,
    ];
    $elements['confirm_revoke'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Confirmo especificamente a revogação deste vínculo.'),
      '#states' => [
        'visible' => [
          ':input[name="command[action]"]' => ['value' => 'revoke'],
        ],
      ],
    ];
    $elements['op'] = [
      '#type' => 'submit',
      '#name' => 'op',
      '#value' => $this->t('Executar operação'),
    ];
    if ($snapshot === NULL) {
      $elements['notice'] = [
        '#markup' => '<p>' . $this->t('Ações sobre pessoa existente exigem inspeção. Cadastro pode ser confirmado sem resultado prévio.') . '</p>',
        '#weight' => -10,
      ];
    }
    if (isset($state['command_id'])) {
      $elements['retry'] = [
        '#markup' => '<p>' . $this->t('Uma tentativa anterior não teve conclusão confirmada. Reenvie sem alterar os dados para preservar a idempotência.') . '</p>',
        '#weight' => -9,
      ];
    }
    return $elements;
  }

  /**
   * Renderiza somente campos publicos do snapshot.
   *
   * @param array<string, mixed> $snapshot
   *   Snapshot da API.
   *
   * @return array<string, mixed>
   *   Render array.
   */
  private function snapshot(array $snapshot): array {
    $rows = [];
    foreach ($snapshot['history'] as $item) {
      if (is_array($item)) {
        $rows[] = [
          (string) ($item['action'] ?? ''),
          (string) ($item['reason'] ?? ''),
          (string) ($item['actor_label'] ?? ''),
          (string) ($item['occurred_at'] ?? ''),
        ];
      }
    }
    return [
      '#type' => 'container',
      '#attributes' => ['class' => ['tds-operations__status']],
      'title' => ['#markup' => '<h2>' . $this->t('2. Estado atual') . '</h2>'],
      'summary' => [
        '#theme' => 'item_list',
        '#items' => [
          $this->t('Pessoa: @name', ['@name' => $snapshot['person']['name']]),
          $this->t('Revisão: @revision', ['@revision' => $snapshot['revision']]),
          $this->t('Matrícula: @value', [
            '@value' => $snapshot['enrolled'] ? $this->t('ativa') : $this->t('inativa'),
          ]),
          $this->t('Turma: @value', [
            '@value' => $snapshot['assigned'] ? $this->t('vinculada') : $this->t('não vinculada'),
          ]),
        ],
      ],
      'history' => [
        '#type' => 'table',
        '#attributes' => ['class' => ['tds-operations__history']],
        '#header' => [$this->t('Ação'), $this->t('Motivo'), $this->t('Ator'), $this->t('Data')],
        '#rows' => $rows,
        '#empty' => $this->t('Sem histórico neste escopo.'),
      ],
    ];
  }

  /**
   * Mapeia codigos sanitizados para mensagens acionaveis.
   */
  private function message(GatewayException $error): string {
    return match ($error->publicCode()) {
      'session_required', 'invalid_or_expired_session' => (string) $this->t('A sessão expirou. Entre novamente antes de continuar.'),
      'access_denied' => (string) $this->t('A API recusou esta pessoa ou este escopo.'),
      'operation_conflict' => (string) $this->t('O estado mudou ou há conflito. Inspecione novamente antes de decidir.'),
      'not_found' => (string) $this->t('O recurso não está disponível neste escopo.'),
      'invalid_request' => (string) $this->t('Revise os dados informados.'),
      'api_unavailable' => (string) $this->t('A API está indisponível. Nenhuma conclusão foi presumida.'),
      default => (string) $this->t('Não foi possível concluir a operação com segurança.'),
    };
  }

  /**
   * Caixa de bloqueio sem detalhes upstream.
   *
   * @return array<string, mixed>
   *   Render array.
   */
  private function errorBox(GatewayException $error): array {
    return [
      '#type' => 'container',
      '#attributes' => ['class' => ['tds-operations__status']],
      'message' => ['#plain_text' => $this->message($error)],
    ];
  }

}
