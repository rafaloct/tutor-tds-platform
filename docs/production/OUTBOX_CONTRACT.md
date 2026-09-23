# Fila de aprendizagem durável — Wave 1

Status: STAGING para o recorte funcional. Resultados atuais e limites em
`WAVE1_ACCEPTANCE.md`; retenção final de recibos continua requisito de promoção.

Política OFFLINE_WRITE_SYNC. Flag Flutter `DURABLE_LEARNING_OUTBOX_ENABLED`
desligada por padrão; ativar no Android de QA. SQLite via sqflite para Android,
iOS/macOS; Windows usa FFI somente nos testes; Web não é alvo desta ativação.
Não há fallback silencioso para preferências se SQLite falhar.

## Contrato

- LearningOutbox: importLegacy, enqueue, pending/ready, acknowledge, fail,
  deliveryStatus, retryBlocked, clear. UI usa LearningDeliveryController sobre
  LearningEventQueue; API mantém /events.
- Evento imutável; event_id é ID local e chave de idempotência. Persistir corpo,
  dono, ambiente, occurred_at, created_at, updated_at, state, attempts,
  next_attempt_at e código HTTP da última tentativa. Não guardar token/senha.
- Estados: pending → synced; falha transitória → retry; rejeição definitiva
  (inclui 409/422) → blocked. Conflito nunca sobrescreve corpo nem vira sucesso.
- Retry: 5s exponencial até 5min; 401/403/429 aguardam 5min. Em primeiro plano,
  ciclo a cada 30s e ao retomar app; eventos de outra conta/ambiente são ignorados.
- Sucesso 200/201 deixa recibo local synced para impedir reimportação depois de
  interrupção. Pendências bloqueadas continuam consultáveis; comando explícito
  retryBlocked permite reenvio do mesmo corpo após correção da causa.
- Não descartar evidência por limite numérico. Falha de armazenamento propaga;
  LearningDeliveryStatus informa pendência, bloqueio e falha local na Home/leitor.
  Projeção e retry são isolados por dono/API/turma/curso/edição. Evento não salvo
  mantém corpo/ID e intenção em memória; sua gravação precisa ser recuperada antes
  de sair. Contrato e limites: LEARNING_DELIVERY_CONTRACT.md.
- Commit local permite continuar sem aguardar HTTP. Recibo não concede progresso:
  envio coordenado pelo controller recarrega o resolver; ack do ciclo global pode
  manter progresso/data anteriores até revalidação normal da tela.

## Migração e recuperação

Cada conteúdo legado é importado em transação e identificado por SHA256.
Remover chave SharedPreferences somente depois do commit. Registro inválido ou
ID com conteúdo divergente aborta a transação inteira e conserva fonte antiga.
Reexecução após interrupção é idempotente, inclusive para evento já confirmado.
Logout conserva registros com dono; exclusão explícita local remove também o
arquivo SQLite, inclusive se restou de uma versão com a flag ativa.
Eventos legados sem dono permanecem locais e não são atribuídos à conta atual.
Novos eventos do leitor/mídia capturam a conta da sessão; telemetria captura
a conta no início da operação e não cria eventos duráveis anônimos.

Não desligar flag como forma de apagar pendências: rollback preserva arquivo
SQLite, mas cliente antigo não o sincroniza. Reativar versão corrigida para
continuar; não converter eventos de volta a uma fila ambígua. Arquivo de banco e
recibos precisam de política de retenção antes da promoção final.

## Validação

Testes usam SQLite real em arquivo: rollback de importação inválida, concorrência,
reabertura, dono, conflito, backoff e sync sem bloqueio global. Teste de integração
native usa banco QA separado, sem ler preferências de usuário. Reabrir conexão
não equivale ao acceptance gate completo de morte/reabertura do Android.

Teste separado em duas fases: `tooling/test_outbox_android.ps1`. Seed conserva
arquivo, force-stop encerra pacote .dev, verify lê a pendência sem criá-la,
confirma idempotência e apaga somente o banco QA. `--no-uninstall` é obrigatório:
o runner Flutter normalmente desinstala o app e remove seus dados ao terminar.
Este gate de componente ainda não substitui a jornada com backend/professor.

Projeção/retry passaram em 42 testes; controller/UI e regressões em 31 testes,
incluindo recuperação e leitor a 320px/fonte 200%. Evidências locais:
`evidence/learning-delivery-repository.json` e
`evidence/learning-delivery-local-verification.json`. Suíte Flutter completa:
344 passaram; análise global concluída sem problemas (exit 0), conforme
`evidence/wave1-flutter-local-gate.json`. Aceite Android das seis fases com a nova
UI aprovado: fila e corpo preservados entre processos, feedback offline e replay
200 sem duplicata. Evidência: `evidence/context-android-gate.json`.
Aceite funcional não resolve a política final de retenção nem autoriza release.

Referências técnicas consultadas: documentação oficial dos pacotes
[sqflite](https://pub.dev/packages/sqflite) e
[sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi).
