# Flutter F2 | Política segura de comandos LearnPress (Issue #258)

**Estado em 18/10/2026:** `IMPLEMENTED` como **modelo puro/testável**, sem conexão a rede, identidade WordPress, tela, SSO ou escrita em backend. **Não é uma Minha área autenticada.** A arquitetura EAD/identidade TDS foi decidida na [Issue #249](https://github.com/rafaloct/tutor-tds-platform/issues/249) e formalizada no [PR #250](https://github.com/rafaloct/tutor-tds-platform/pull/250), ainda draft.

**F0 utilizada:** [PR #254](https://github.com/rafaloct/tutor-tds-platform/pull/254) / Issue #252: LearnPress em **sandbox sintético com SQLite**, sem comprovar a mesma semântica no MySQL do EAD de produção. A política F2 contém salvaguardas conservadoras, não código que autentica no ambiente real.

## O que o F0 comprovou no ambiente sintético

| Operação/tema | OBSERVED em SQLite QA | Consequência para o Flutter |
|---|---|---|
| JWT LearnPress | token LP top-level, não autentica WP core REST; validade simulada 7 dias | Não confundir JWT LP com FastAPI TDS, nem guardar tokens por conta própria nesta fatia |
| Inscrever-se | `POST courses/enroll` usa campo `id`; dupla inscrição dá erro, `user_id` explícito é ignorado | Não repetir POST às cegas, usar estado LP confirmado, reconciliar após retorno |
| Concluir lição | `POST lessons/finish` permitido apenas ao inscrito; guest 401, não inscrito 403 | Exigir prova de sessão e inscrição, lesson ID realmente disponível |
| Quiz | `quiz/start` e `quiz/finish` são independentes; `check_answer` incerto | Exigir estado LMS e jamais enviar gabarito por projeção pública |
| Concluir curso | `courses/finish` impede quizzes/lessons posteriores (403) | Só permitir tentativa com inventário completo verificado e permissão do LMS |
| Logout | logout da interface WordPress não revoga automaticamente JWT LP stateless | Invalidar possibilidade de comando local, mas não alegar revogação no servidor |
| Directory | `/learnpress/v1/users` pode responder 200 anonimamente | Diretório público **não é prova** de que alguém controla aquela conta |
| Certificado | plugin LP de certificados ausente na fixture | Permanecer no fluxo **institucional TDS**, não emitir por curso finalizado LP |

## Código e limites de autoridade

- `cartilhas_app/lib/features/ead_account/domain/ead_learner_action_policy.dart`: dados mínimos para EAD `wpUserId`, `wpCourseId`, `environmentId`, `observedAt`, estado de matrícula, lições, quizzes e indicação de inventário/permissão de conclusão conferidos **na própria autoridade LearnPress**. Nenhum ID de turma TDS, CPF, token, cookie ou senha.
- `EadSessionProof` é um **contrato esperado de um broker futuro**, não prova criptográfica construída pelo Flutter. A política aceita apenas provas com validade máxima de 15 minutos, independentemente do JWT LearnPress de sete dias, e nunca confunde validade local com revogação remota. `brokerVerified=true` deve ser atribuído exclusivamente por um componente de autenticação auditado, após validar servidor/sessão. **Este broker ainda não foi implementado.**
- `EadLearnerActionPolicy.evaluate()` retorna `eligibleToRequest` somente se identidade, ambiente, curso, frescor, matrícula, unidades e eventuais pré-requisitos autorizarem a tentativa. Nunca escreve estado acadêmico, e nunca diz que o comando já produziu um fato.
- `EadRemoteResponsePolicy.classify()` não trata HTTP 200 como comprovação de matrícula/progresso; exige **nova leitura canônica** do LearnPress. HTTP 200 com `status:error`, 401, 403, 404, 409, 429, 5xx e falha de conexão são distintos. Timeout/5xx num POST não autoriza repetir operação não idempotente.
- `signOutLocally()` invalida elegibilidade local, sem afirmar que o JWT LP remoto foi revogado.
- Nenhum objeto desta feature define progresso percentual, frequência, nota ou certificado TDS. Catálogo público e crosswalk [PR #257](https://github.com/rafaloct/tutor-tds-platform/pull/257) nunca se transformam em permissão por correspondência de títulos.

## Sequência permitida no futuro (TARGET, não runtime atual)

```text
Tutor TDS autenticado
  -> vinculação consentida com conta EAD (broker sob revisão de segurança)
  -> leitura da autoridade LearnPress autenticada, curso/lesson/quiz escopados
  -> snapshot confiável e recente (wpUserId, wpCourseId, ambiente)
  -> política F2 decide somente se ação PODE ser solicitada
  -> usuário confirma a ação; broker faz POST com credencial autorizada
  -> servidor retorna recibo; nunca inferir sucesso apenas de HTTP
  -> GET autenticado de estado canônico e atualização atômica da UI
  -> cada tela mostra a origem LearnPress ou TDS, sem somar percentuais
```

O comando `finishCourse` requer `requirementsVerified=true`, ao menos um item obrigatório, todos os itens já concluídos **segundo snapshot autorizado**, ausência de escrita pendente e `learnPressAllowsFinish=true` vindo de contrato seguro que ainda não existe. Com isso, a finalização permanece bloqueada no aplicativo real até a integração adequada.

## Testes de regressão

```text
flutter pub get --offline
flutter test --no-pub test/ead_learner_action_policy_test.dart
flutter analyze --no-pub lib/features/ead_account/domain test/ead_learner_action_policy_test.dart
```

Casos: contas sintéticas A/B, ambientes distintos, curso errado, fonte pública versus autorizada, sessão expirada, logout, snapshot velho, offline, operação pendente, inscrição duplicada/desconhecida, aula/quiz indisponíveis, quiz antes de finalizar curso, inventário incompleto, permissão LMS ausente, HTTP 200 erro de aplicação, 401/403/404/409/429/5xx/timeout e ausência de sucesso presumido.

**Não testado:** MySQL real, cookies WebView, broker, SSO, Play, comunicação HTTPS com WordPress, frontend Minha área, edição de lições, acessibilidade e aluno real. Exigir ensaios de autoridade com duas contas **sintéticas** em MySQL staging, incluindo duplicatas/expiração/IDOR, antes de permitir writes.

## Handoff e gates

- **F0/Devin (#254):** contrato observado SQLite, continua exigindo MySQL.
- **F1/ChatGPT (#257):** crosswalk público 11↔9, ainda sem revisão editorial.
- **F2 (este PR):** política de elegibilidade/resultado sem qualquer chamada real.
- **F3 futuro:** broker de identidade opaca e consentida, depois adapter de consultas e comandos autenticados, telas Minha área e cache por dono/ambiente com política de revogação. Não inventar OAuth num patch Flutter; aprovação de arquitetura de segurança e testes precede isso.
- **Human gate:** revisar o PR, escolher protocolo de autenticação, verificar MySQL staging, aprovar integração real e depois merges. `MERGE_ALLOWED=NO`, `PRODUCTION_ALLOWED=NO`, `FORCE_PUSH_ALLOWED=NO`.

**Regra:** `TESTED-LOCAL` de política pura não é `TESTED-STAGING` do LMS nem `PRODUCTION_READY`. O APK QA #248 não contém essa política até que PRs sejam integrados e novo build executado.
