# Context Core — fatia incremental

Esta fatia acrescenta resolução contextual e progresso compartilhado ao caminho
existente. Recorte funcional da Wave 1 aceito em STAGING; resultados e limites em
`WAVE1_ACCEPTANCE.md`. Não autoriza publicação ou PRODUCTION_READY.

## Contrato implementado

- Flag `LEARNING_CONTEXT_ENABLED=false` no Flutter/API; compose usa
  `STAGING_LEARNING_CONTEXT_ENABLED=false`. Ativar em conjunto apenas no QA.
- GET `/classes/{class_id}/learning-context`: próprio aluno autenticado.
- GET `/classes/{class_id}/students/{user_id}/learning-context`: observação pela
  equipe autorizada, retornando o contexto do aluno observado.
- Resposta OpenAPI: `context`, `progress`, `resolved_at`,
  `contract_version=cohort-enrollment-v2`. Contexto contém todos os campos centrais.
- Papel student deriva de ClassEnrollment ativa, nunca de seleção visual.
  Professor acessa por `_staff`; programa revogado não autoriza o acesso.
- A projeção de progresso usa exatamente `_student_progress`, a mesma função
  utilizada no dashboard. Posição local de leitura continua separada das horas.
- `membership_id` aponta para cohort_memberships persistida. `enrollment_id`
  aponta para class_enrollments.context_id (Membership+CourseVersion), enquanto
  `legacy_enrollment_id` preserva a linhagem antiga. GET não faz backfill.
- StudentProgress mantém enrollment_id legado para consumidores existentes e
  acrescenta context_enrollment_id. A projeção compartilhada inclui contagens
  de acompanhamento, sem narrativas privadas. Revogação canônica é aplicada em
  leitura, eventos, roster e comandos; backfill não reativa vínculo revogado.

## Flutter

`LearningContextRepository` + implementação real/Fake + controller; a abertura
da turma valida identidade e edição antes de navegar ao leitor. Flag desligada
mantém o caminho existente. O leitor mostra progresso confirmado recebido do
servidor, separado da barra de posição de leitura. Sync coordenado pelo controller
recarrega o resolver; ack do ciclo global pode conservar progresso/data anteriores
até revalidar a tela. Sem rede, identifica a última sincronização.

Snapshot privado por conta, ambiente e turma, validade de sete dias. Respostas
negadas removem cache; troca de conta durante request é rejeitada. Cache guarda
somente identidade contextual e progresso necessário, sem copiar nome/roster.

Retomada contextual usa chave por ambiente, dono, turma, vínculo, matrícula e
edição. Histórico legado é preservado; dado ambíguo não é atribuído a uma turma.
Flutter aceita cache v1 e resposta v2 validando ambas as identidades. ResumeKey
mantém a linhagem explícita para conservar a posição exata do mesmo contexto;
outra turma/matrícula/edição não reutiliza essa posição. Nenhum ID é inferido.

## Offline incremental

- Eventos do leitor contextual recebem envelope local de dono/ambiente, nunca
  enviado como autorização à API. ID e timestamp sobrevivem a reabertura/retry.
- Sync pula eventos de outra conta/ambiente e revalida dono após refresh.
- Logout preserva esses eventos para o dono voltar; continua removendo filas
  antigas sem dono e as filas legadas de assessment/check-in conforme contrato
  anterior. Exclusão explícita dos dados locais continua sendo distinta.
- Caminho legado continua em SharedPreferences com limite suave. Nova opção
  SQLite usa `DURABLE_LEARNING_OUTBOX_ENABLED=false`; importa atomicamente e
  registra estado, tentativas/backoff e conflitos. Detalhes em OUTBOX_CONTRACT.
- LearningDeliveryStatus e LearningDeliveryController estão integrados à Home e
  ao leitor: contagem pedagógica isolada, erros explícitos e retry imutável;
  intenção de leitura aguarda commit local, sem aguardar HTTP. UI/recuperação
  validadas localmente e no Android; contrato em LEARNING_DELIVERY_CONTRACT.md.
  Política final de retenção dos recibos continua necessária antes da promoção.

## Riscos e recuperação

Migração aditiva 0019 aplicada e testada em staging; sem alteração de assinatura
ou promoção de produção. Desativar a flag volta ao leitor anterior;
dados/contexto novos são preservados.
Role global ainda existe no legado. POST `/events` com turma+edição e flag
ativa usa vínculo contextual; demais eventos e GET `/events` preservam
student_claims/política global até migração específica.
Não extrapolar teste com aluno para todos os papéis ou toda a migração.

## Validação

Resultados consolidados em `WAVE1_AUDIT.md` e evidências de QA. Testes locais
cobrem contratos, isolamento, revogação, controller, abertura correta, retomada,
outbox por dono e comparação aluno/professor. O teste API com login real recria
o app e relê o banco, mas não equivale à morte/reabertura do Android em staging.

Entrega: 42 testes da projeção/retry e 31 de controller/UI/regressão passaram,
com evidências em `evidence/learning-delivery-repository.json` e
`evidence/learning-delivery-local-verification.json`. Suíte Flutter completa:
344 passaram; análise global concluída sem problemas (exit 0), evidência em
`evidence/wave1-flutter-local-gate.json`. Aceite Android de seis fases aprovado,
com progresso 5% → 7,5% → 10%, histórico preservado e observação idêntica pelo
instrutor. Isolamento HTTPS aprovado: outra turma permanece em 0% e instrutor
externo recebe 403. Consolidação atual em `WAVE1_ACCEPTANCE.md`.

`flutter analyze --no-pub` deve usar o junction ASCII
`C:/Users/Usuario/.codex/tmp/tutor-tds-context-qa` apontando para `cartilhas_app`.
O caminho original reproduziu falha de framing JSON/LSP com Unicode; não alterar
código de produto para contornar esse defeito do toolchain. Nenhum SDK trocado.
