# Google Analytics no app — Issue #195

Base: `dd928ff6b58788af930aa6722557728d74dfe97c` (`staging`, PR #194 integrado).
Branch: `codex/finalize-analytics-production`.
Objetivo único: medição Google Analytics for Firebase no Android, preservando
o painel pedagógico da API TDS. Rafael solicitou painel, medição e ativação
de produção em 13/10/2026; informou que ainda não existe projeto Firebase.

## Contrato implementado

- `GOOGLE_ANALYTICS_ENABLED` é false por padrão. A factory exige ambiente
  staging/production, Android e opções Firebase completas de app Android.
- Opções públicas do cliente: `FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID`,
  `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_API_KEY`, reaproveitando o contrato
  Firebase já existente para push. Não incluir service account, segredo GA
  Measurement Protocol nem credenciais administrativas no app.
- Consentimento Google novo, independente do acompanhamento pedagógico, salvo
  por ambiente/projeto/app. Controle nas Configurações e aviso de privacidade.
  Consentimento anterior de progresso nunca ativa Google automaticamente.
- Android desativa coleta e consentimentos por padrão, desativa screen reporting
  automático e remove permissões de advertising ID/AdServices. Flag false
  desativa a coleta nativa, inclusive se uma versão anterior a habilitou.
  iOS permanece nativamente desativado até sua validação própria.
- Só categorias constantes de telas/recursos/funcionalidades atravessam o adapter.
  `page_viewed` vira `screen_view`; `resource_opened` e `feature_used` carregam
  somente `target`. Não enviar curso, pessoa, matrícula, turma, CPF, nome,
  mensagens, respostas, notas ou payload arbitrário. Sem `user_id` Google.
- SDK Firebase pode medir dados técnicos, identificador de instalação e eventos
  automáticos após consentimento. Isso não é anonimização garantida.
- Revogação cancela eventos do app ainda na fila, nega consentimento nativo,
  desativa coleta e redefine dados analíticos locais. Término de sessão revoga
  também. Não promete apagar automaticamente dados já enviados ao Google.
- Falha do Google não impede fila TDS, leitura, autenticação ou resultado
  acadêmico. SDK gerencia sua própria entrega offline; não há replay da outbox
  pedagógica para o Google.
- Painel da turma continua em `/analytics/usage`, com autorização do backend.
  Não consulta Google com credenciais embutidas. Falha da consulta aparece como
  indisponibilidade, sem afirmar que não houve uso.

## Validação e limites desta sessão

TESTED-LOCAL: API `uv run --frozen --extra test pytest tests/test_analytics.py
tests/test_promotion_preflight.py`: 3 passed. `git diff --check` passou.

IMPLEMENTED: testes Flutter para consentimento, revogação, startup concorrente,
falha do SDK, categorias proibidas, independência da fila e painel indisponível.
Flutter analyze/test ainda não executados: download do SDK Dart pelo Flutter
3.44.9 recebeu CONNECT 403 no proxy desta sessão. Lock das três dependências
Analytics preparado com versões/hashes publicados no pub.dev; ainda exige
`flutter pub get --enforce-lockfile` pelo SDK validado/CI.

UNKNOWN/BLOCKED: Firebase/GA não provisionados, recebimento em DebugView não
verificado, nenhum novo AAB, nenhuma promoção de produção. Probes do domínio
produtivo receberam CONNECT 403 do proxy (não é evidência de serviço fora do ar).
LARGeo apareceu online, mas `start_process` expirou e `get_config` ficou pendente.

## Sequência de ativação

1. No host autorizado, verificar conta Google/Firebase acessível; criar ou
   selecionar projetos distintos por ambiente e vincular GA4. Não contratar
   plano pago nem aceitar termos em nome do titular sem decisão específica.
2. Registrar Android com package exato: produção `com.tutortds_cartilhas`;
   staging normal `com.tutortds_cartilhas.dev`. Não usar stream produtivo para QA.
   Obter as opções públicas, conferir projeto/app/stream e guardar config local
   conforme as regras existentes. Nenhuma opção é adivinhada por nome.
3. Em staging, executar `flutter pub get --enforce-lockfile`, analyze e testes
   focais `google_usage_analytics_test`, `app_telemetry_service_test`,
   `classroom_dashboard_screen_test`, `settings_logout_test`,
   `validate_production_config_test`; conferir manifesto Android mesclado.
4. Habilitar a flag no build staging, validar recusa (sem coleta), aceite,
   tela/recurso no DebugView, revogação, reinício, logout, offline/reconexão
   e ausência de parâmetros proibidos. Retirar debug mode depois do ensaio.
5. Configurar retenção mínima adequada (2 meses para eventos), sem Google
   signals/ads personalization, revisar política pública e Data Safety.
6. Somente com os IDs e evidência reais, atualizar as allowlists de produção
   em `tool/validate_production_config.dart` e Gradle, seus testes e a config
   aprovada. Hoje essas travas continuam recusando a ativação produtiva nova.
7. Concluir gates existentes de backup agendado/restore, compatibilidade,
   upgrade, SHA/tag, assinatura e manifesto; gerar artefato atual, publicar
   pelo mecanismo do projeto e verificar API/app/GA ao vivo.

## Continuidade e recuperação

Reason: acesso operacional sem resposta, projeto Google inexistente e gates
de release ainda sem evidência atual. Exact human action: reconectar Desktop
Commander Remote no LARGeo; se necessário, autenticar a conta Google titular
no fluxo oficial sem compartilhar senha/token. What remains unblocked:
revisão do código, CI, testes sintéticos e documentação.

Rollback de coleta: desativar escolha nas Configurações; para rollback de build,
publicar versão com `GOOGLE_ANALYTICS_ENABLED=false` e conferir metadata nativa
`firebase_analytics_collection_deactivated=true`. Dados pedagógicos não dependem
do Google. Não remover dados, tabelas ou evidências para reverter analytics.
