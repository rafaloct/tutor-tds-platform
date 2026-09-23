# Entrega da aprendizagem — complemento mínimo da Wave 1

Status: STAGING — implementação validada localmente e nas seis fases Android
com backend real. Resultados atuais e limites em `WAVE1_ACCEPTANCE.md`. Complementa
OUTBOX_CONTRACT.md e HOME_CONTEXT_CONTRACT.md, sem migration, endpoint ou rota
nova. Flag DURABLE_LEARNING_OUTBOX_ENABLED permanece desligada por padrão.

## Screen contract

| Campo | Contrato |
| --- | --- |
| Purpose | distinguir atividade salva, envio pendente, rejeição e falha ao salvar, sem inventar progresso |
| Actor | aluno autenticado no contexto resolvido; papel global não concede acesso |
| Required Context | LearningContext, dono da sessão e URL da API normalizada |
| Reads | projeção local da outbox, estado do envio, consentimento e sessão atual |
| Displays | resumo compacto na Home abaixo da última sincronização e no leitor abaixo do progresso confirmado |
| Commands | atualizar estado; registrar atividade; sincronizar envios elegíveis; tentar salvar novamente; reenviar registro bloqueado |
| Writes | mesmo LearningEvent na fila existente; transições de entrega e recibo existentes |
| Repositories | LearningEventQueue → LearningOutbox/SqliteLearningOutbox; LearningEventSyncService; AuthRepository; Fake para contrato/controller |
| Endpoints | POST /events existente; contexto existente é revalidado quando necessário; nenhum endpoint novo |
| Events | lesson_started, lesson_completed e study_activity existentes; não gerar evento pedagógico por clicar em retry |
| Loading State | conferindo envios; contagens desconhecidas nunca aparecem como zero/sucesso |
| Ready State | nenhuma atividade pedagógica pendente neste contexto; não afirmar conclusão do curso |
| Empty State | sem contexto resolvido, não consultar nem exibir dados de outra conta/turma |
| Offline State | informar somente atividades cujo commit local foi confirmado; envio automático quando elegível |
| Error State | distinguir rejeição preservada, falha de leitura local e atividade ainda não salva |
| Permissions | dono/ambiente/contexto exatos; consentimento e autorização real continuam exigidos pelo serviço/API |
| Acceptance Criteria | isolamento, imutabilidade, feedback honesto, recuperação e testes abaixo |
| Must Not | editar/excluir evidência para resolver erro; gerar novo ID no retry; interpretar fila como autorização/progresso; acessar SQLite/HTTP diretamente no widget |

## Projeção e estados

- Escopo obrigatório: ownerId + apiUrl sem barra final + cohortId + courseVersionId.
  Eventos pedagógicos também devem corresponder ao courseId do LearningContext.
  Registros sem dono, outra conta/ambiente/turma/edição e telemetria não entram
  nas contagens pedagógicas. São preservados pelo mecanismo existente.
- Expor DTO somente de leitura com pendingCount, retryCount, blockedCount,
  nextAttemptAt e referências dos registros bloqueados com lastStatus. Ler
  colunas já existentes; não criar outra fila nem reconstruir contexto no widget.
- pending/retry: commit confirmado, envio ainda não confirmado. blocked:
  rejeição definitiva preservada (inclui 409/422). synced: recibo existente,
  excluído das contagens pendentes. Atualizar projeção após enqueue/fail/ack/retry.
- Falha de leitura não permite afirmar que a fila está vazia. Falha de gravação
  é estado separado de pendência durável e tem prioridade na mensagem exibida.
- Controller entrega estado/comandos ao componente compartilhado. Conta/contexto
  alterado invalida respostas em andamento; não publicar resultado de outro dono.
  Fluxos com flag desligada mantêm o comportamento anterior.

## Comandos e recuperação

1. Registrar: capturar dono/contexto e construir LearningEvent uma única vez.
   Só informar "salva neste aparelho" depois de confirmação do commit local.
2. Falha de armazenamento: conservar o mesmo evento em memória no controller,
   informar que ainda não está salvo e impedir novas atividades até resolver.
   Não alegar que essa memória sobreviverá ao encerramento do app. Não descartar
   silenciosamente o evento ao trocar tela/contexto; preservar seu responsável
   ou informar explicitamente o risco antes de encerrar essa tentativa.
3. Tentar salvar novamente: repetir enqueue do mesmo corpo, ID, dono, contexto
   e timestamp. Não recriar a atividade nem creditar progresso. Sucesso local
   remove o bloqueio de novas atividades e permite o envio normal.
4. Sincronizar: reutilizar flush, consentimento, deduplicação, backoff e ciclo
   de retomada existentes. Não criar timer paralelo nem ignorar nextAttemptAt.
5. Reenviar bloqueado: ação explícita após tratar a causa, selecionando apenas
   registros do escopo atual e revalidando dono antes da alteração/envio.
   retryBlocked preserva corpo/ID/timestamp; uma nova rejeição continua visível.
   Serializar comandos concorrentes; nenhum botão permite editar ou apagar corpo.
6. HTTP 401/403 nunca concede acesso nem é sucesso: pedir renovação do acesso
   quando aplicável, preservar evidência e respeitar revogação/backoff. Ausência
   de consentimento mantém envio pausado; retry não modifica essa preferência.
7. Após 200/201 e recibo local, atualizar resumo. Quando o controller coordena o
   envio, consultar progresso pelo resolver existente; ack do ciclo global pode
   manter o último progresso/data até a próxima revalidação da tela. Nunca fazer
   HTTP por ack de telemetria. Fila vazia não substitui a projeção do servidor.

## Referência visual e verificação

Base compatível: Home 75ac62c1bb3241aba1b3092f908b7c5f, cache existente dentro de
`.stitch/designs/389e412e620c4c49841a5e9508cf6bfb/derivatives/`. Seu digest contém
somente ready. Variante offline/atenção 9d6e0e93f2c448058d3f4afac70a7c4a:
screenshot e HTML baixados/verificados; screenshot e digest inspecionados para
este componente. Cache em `.stitch/designs/75ac62c1bb3241aba1b3092f908b7c5f/derivatives/9d6e0e93f2c448058d3f4afac70a7c4a/`.
Usar contagem real e recipiente âmbar com ação de sincronização; falha ao salvar
usa o estado de erro do mesmo componente, sem alegar que a variante já demonstra
implementação, paridade integral ou recuperação testada.

- Repository/SQLite: projeção isolada; contagem exclui telemetria/synced; bloqueio
  persiste após reabrir; retry altera somente registro permitido, nunca o corpo.
- Controller/Fake: falha ao salvar preserva o evento exato e impede nova
  atividade; retry recupera sem duplicar; troca de conta e respostas atrasadas
  não vazam estado; leitura falha não vira zero; 401/403/consentimento preservados.
- Widget: textos distintos para salva/pendente/bloqueada/não salva, ações
  habilitadas conforme estado; progresso confirmado independente; 320px/fonte 200%.
- Integração: acrescentar à jornada Android existente a pendência visível offline
  e sua resolução após sincronizar, mantendo reinício e replay sem duplicata.
  Falhas de armazenamento/rejeição são exercitadas nos testes de fronteira acima;
  não simular esses estados como prova da jornada real com staging.
- Registrar resultados e matriz. Este complemento não aprova paridade visual
  integral, release ou política final de retenção de recibos.

Evidência local: `evidence/learning-delivery-local-verification.json`.
Aceite integrado: `evidence/context-android-gate.json`; estado pendente visível
offline e após reabertura, removido após sincronização. Não aprova release.
