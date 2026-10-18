# F3a | Minha área: apresentação isolada LearnPress e TDS

**Status:** IMPLEMENTED + TESTED-LOCAL com modelos sintéticos, **não conectado à Home nem ao login EAD real**.
**Issue:** #262, derivada do PR #260 (política de ações) e da ADR #249/PR #250.
**Snapshot de decisões:** 18/10/2026. Devin executa F0b em MySQL sintético na máquina dfd627; não depender de resultado antecipado.

## O que esta fatia entrega

Um componente Flutter de apresentação, `EadMyAreaPreview`, com modelo `EadMyAreaModel` injetado, estados acessíveis e navegação apenas por **callbacks explícitos**. **Nenhuma chamada HTTP, credential store, matrícula, progresso ou certificado é gravado.** O componente não foi registrado na Home e não aparece em APK de produção.

| Área | Origem autorizada | Estado desta fatia |
|---|---|---|
| Conta EAD | WordPress/LearnPress, por broker de vinculação ainda TARGET | Disconnected/linking/linked/reautenticar, todos honestos, sem SSO simulado |
| Meus cursos no EAD | LearnPress autenticado, em conta e ambiente verificados | Lista injetada, fontes identificadas, nenhuma inferência pelo catálogo público |
| Progresso EAD | Valor retornado pelo LearnPress, quando conhecido | `null` = ainda não disponível; **0% só quando explicitamente recebido** |
| Retomar aula EAD | Lições/autorização LearnPress | Botão desativado sem estado atual, permissão da lição e callback fornecidos |
| Turmas/frequência TDS | FastAPI institucional | Card próprio, sem tentar sintetizar dados do LMS |
| Certificados oficiais | Tutor TDS, API/Worker e revisão humana | Card separado, sem converter conclusão EAD em certificado |
| Suporte | Chatwoot/TDS | Entrada separada e callback opcional |

O modelo tem três verificações obrigatórias **de apresentação**, nunca substitutas da autorização no servidor: `authenticatedSourceVerified=true`, `viewerWpUserId=snapshotWpUserId` e `environmentId=snapshotEnvironmentId`. Se qualquer requisito falhar, a tela **não renderiza dados privados**, ainda que receba uma lista de cursos sintética. A aplicação futura só poderá definir `authenticatedSourceVerified` por meio de um broker auditado e teste de duas contas, nunca por dados públicos.

A tela distingue `current`, `stale`, `offline`, `loading`, `unknown` e `error`. Stale/offline exibem aviso explícito e desabilitam **Continuar aula**. Erro não significa 0% nem matrícula inexistente. Cursos concluídos no EAD continuam aparecendo como EAD, sem qualquer declaração de emissão institucional.

## Integração futura, não implementada

```text
Sessão TDS (FastAPI) + conta EAD verificada pelo broker
  -> broker responde vínculo opaco, auditoria e ambiente
  -> GET seguro do próprio usuário LearnPress (nenhuma rota presumida)
  -> validação de fonte/progresso/autorização e timestamp
  -> EadMyAreaModel (somente leitura e identificadores WP)
  -> EadMyAreaPreview (UI)
  -> callback solicita ação ao controlador
  -> política fail-closed do PR #260 (nunca prova sucesso)
  -> execução autorizada LP e nova leitura da origem
```

**F0b obrigatório** para validar os schemas, duplicações, conclusão de curso, sessão, segurança e respostas **em MySQL sintético**. Os resultados observados em SQLite no PR #254 não autorizam automaticamente o runtime real. A ligação TDS↔WP exige consentimento, escopo, TTL, logout/revogação, defesa IDOR/CSRF, isolamento A/B e revisão de segurança.

**Sem avanço automático:** um clique da UI não marca presença, não conclui aula pelo tempo do player, não emite certificado nem alimenta CourseVersion TDS. O mapeamento público 11↔9 do PR #257 continua candidato até curadoria e não autoriza matrícula.

## Assets visuais aprovados, aguardando ligação

A nota A2A da Issue #249 registra aprovação visual de assets nos PRs #255 (splash/erro/loading/empty) e #259 (curiosidades/ilustrações de assentamento), **ambos draft**. Nenhum asset desses PRs foi copiado ou referenciado na F3a, para evitar dependência de arquivo não integrado. Após revisão/merge explícitos, a UI pode receber imagens por componentes aprovados, respeitando a regra de faixa/card não dominante e texto fora da imagem. A marca oficial nunca é gerada por IA.

## Testes e critérios

```bash
cd cartilhas_app
flutter test --no-pub test/ead_my_area_preview_test.dart
flutter test --no-pub test/ead_my_area_preview_test.dart test/ead_learner_action_policy_test.dart
flutter analyze --no-pub lib/features/ead_account test/ead_my_area_preview_test.dart
```

Cobertura focal: conta desconectada (sem dados), vinculação pendente, necessidade de login, usuário A vs B, staging vs production, falta de identidade, fonte não verificada, 0/40/null/200% de progresso, lista vazia autenticada, offline/stale sem continuar, loading/error/retry, curso EAD concluído separado de certificado oficial, callback autorizado, callback ausente desabilitado, tema escuro, escala de fonte alta e rolagem 390 px.

**Não testado:** session broker real, dados de aluno, WordPress com MySQL, Flutter Home, Chatwoot real, screenshots Android, integração de certificados e Play. O PR é **TESTED-LOCAL** e não deve ser descrito como `RELEASE_READY` ou `TESTED-ANDROID`.

## Próximo handoff para humanos/agentes

1. Aguardar recibo F0b MySQL sintético em PR draft separado do Devin.
2. Revisar segurança/protocolo de autenticação do broker, tokens, rotas WP/LP reais e arquitetura de cache privado, com aprovação humana.
3. Criar nova Issue para integração adapter/controlador com PR #260 (sem uso de API WP genérica com JWT LP).
4. Só após E2E com aluno A/B, logout, consentimento, curso/matrícula real e rollback, ligar a tela na Home, revisar assets e executar QA no emulador. Xiaomi reservado para smoke final pré-AAB.
5. Integrar PRs empilhados em sequência com autorização individual; preservar operações de produção separadas.

**Gates:** `MERGE_ALLOWED=NO`; `PRODUCTION_ALLOWED=NO`; `FORCE_PUSH_ALLOWED=NO`. Nenhuma escrita no EAD, emissão de certificado, merge, assinatura AAB ou publicação Play nesta entrega.
