# Revisão de compatibilidade HTTP — 13/10/2026

## Conclusão e escopo

ACEITE CONDICIONAL para o contrato utilizado pela fonte publicada `1.2.0+11`
(`7c22045`) e pela fonte candidata `1.4.0+13`, árvore API
`dc32d081dffd4d778e51871a85ae4077eb75f6ce`, mantendo as features de rollout
desativadas. **Não há aceite de compatibilidade universal/aditividade global da
API.** A mudança de `PrepareClassCommand` é incompatível para um consumidor HTTP
antigo dessa operação.

Base: ensaio restaurado `20261013T141953Z-f5948745ff6593fe`, imagem candidata
`sha256:4ed8a189b3741d8b8f536a0b790cc0215f997f05c4254ea65d9e67826b1a858b`,
imagem anterior
`sha256:d6701c77b8a48b84fa4b9cea7bbc1c2858bf69aa75dd2367c9a3a4f6fb30666c`.
Imagem candidata informada pelo executor: label Git
`d3b1331a14ec77b37a8b05e9f5f19e2ccfe57c2e`.

## Evidência examinada

- Receipt `postgres-upgrade-20261013T141953Z-f5948745ff6593fe.json`: 126 operações
  produtivas → 133 candidatas; `only_production=[]`; nenhuma operação do contrato
  AAB 1.4 ausente; sete alterações em schemas comuns. São **operações**, não
  126→133 paths distintos.
- O mesmo receipt registra restore 0028, upgrade 0030, colunas originais
  preservadas, catálogo legado compatível, imagem antiga iniciando no banco
  atualizado e limpeza dos recursos isolados. Produção ainda inalterada nessa
  execução. Os booleanos foram complementados por revisão estrutural e código.
- `docs/production/evidence/published-apk-compatibility-2026-10-06.json` vincula
  a referência publicada à fonte `7c22045`/pubspec `1.2.0+11`, com baseline física
  histórica Xiaomi. A revisão Git confirmou ausência de `TUTOR_API_URL`,
  `/auth/login`, `/courses`, assessment e lifecycle nessa fonte.
- Serviços online antigos usam somente o gateway legado `/v1/chat`, `/v1/study`
  e `/v1/certificates`; a API FastAPI não é dependência desse app antigo.
- Confirmação read-only Docker enviada pelo executor: `TUTOR_ENVIRONMENT=production`,
  `MINIMUM_SUPPORTED_APP_VERSION=1.2.0+11`, `COMPATIBILITY_VERIFIED=false`,
  `LEARNING_CONTEXT_ENABLED=false`, `JOURNEY_TRACEABILITY_ENABLED=false`,
  `PAYMENT_ADAPTER=disabled`. `DYNAMIC_ACTIVITY_ENABLED`, `CLASS_LIFECYCLE_ENABLED`
  e `CPF_ACTIVATION_REQUIRED` estão ausentes e possuem default false no candidato.
  A promoção deve manter mínimo 11 e essas flags false explicitamente.

## Os sete schemas

| Schema | Delta e decisão |
| --- | --- |
| AssessmentAttemptUpsert | Acrescenta origin com default practice e 11 campos contextuais opcionais/nulos; nenhum required antigo muda. Request antigo foi aceito no modelo candidato. |
| AssessmentAttemptResponse | Mesmas adições, nenhum campo removido. Rotas antigas filtram practice; parser candidato lê campos conhecidos e tolera as adições. Consumidor externo que aplique extra-forbid ao schema antigo pode rejeitar campos novos e não está coberto pelo aceite. |
| AssessmentContentResponse | answer_key admite PublishedBlockAnswerKeyItem (correct_indices/explanation/graded). Serializer de practice continua retornando correct_index/explanation. Ramos published_block exigem LEARNING_CONTEXT_ENABLED e DYNAMIC_ACTIVITY_ENABLED; ambos false nesta promoção. |
| EligibleStudentPage | occupancy, capacity_reference=30 e capacity_warning=false são adições sem novos required; parser candidato suporta defaults. |
| EventResponse | O schema de resposta amplia enum para assessment_completed e payload para valores JSON, relaxa limites e explicita active_seconds/payload como presentes. EventCreate conserva o contrato de entrada. Serializer mantém os eventos/payloads antigos; assessment_completed nasce exclusivamente de conclusão published_block. Sync de eventos do app usa status HTTP, sem decodificar esse enum na resposta POST. |
| PrepareClassCommand | **Breaking change:** version_id passa a ser required. Consumidor antigo de POST /operations/classes sem esse campo recebe 422; a validação FastAPI ocorre antes do handler/flag, portanto mesmo lifecycle false não torna essa chamada antiga compatível. App publicado 1.2 não chama a rota; candidato envia version_id e esconde a superfície quando bootstrap não concede capacidade. |
| SessionResponse | Adiciona checkin_code opcional/null, preservando token e todos os campos/required antigos. Parser candidato aceita ausência/null. |

## Conferência da implementação

- `api/app/assessment_sync.py`: default practice; modelo recusa contexto em
  practice; list/get legados restringem origem; `_require_dynamic_activity`
  exige as duas flags; `_content_response` mantém o gabarito de prática.
- `api/migrations/versions/20261007_0030_dynamic_activity_context.py`: origem
  server_default practice e linhagem nullable; dados antigos permanecem no ramo
  practice. Não há geração automática de eventos novos pela migration.
- `api/app/events.py`: `EventCreate` não aceita assessment_completed;
  `_serialize` preserva tipo/payload/duração. O tipo novo é produzido apenas
  por `_record_completion_evidence` de assessment published_block.
- `cartilhas_app/lib/features/study_ai/models/assessment_sync_models.dart`:
  parser aceita prática/contexto e os dois formatos de gabarito.
- `cartilhas_app/lib/features/classrooms/models/classroom_models.dart` e
  `features/evidence/models/evidence_models.dart`: campos adicionais/defaults
  de capacidade e código de sessão suportados.
- `cartilhas_app/lib/features/class_lifecycle/data/class_lifecycle_repository.dart:203`:
  envio explícito de version_id. `home_screen.dart` faz bootstrap e esconde
  gerenciamento quando não recebe capacidades autorizadas.

Probes locais somente leitura, usando modelos/serializers reais e namespaces
sintéticos, passaram: request antigo de prática/default origin; resposta de
prática; gabarito correct_index; eventos page_viewed e study_activity; rejeição
do prepare antigo sem version_id; aceitação do prepare candidato. Sem endpoint,
banco, dados de produção ou arquivos do projeto alterados por esta revisão.

## Limites e promoção

O aceite permite registrar compatibilidade do contrato usado pelos apps
suportados, preservando mínimo `1.2.0+11`. Não comprova atualização física do novo
AAB, funcionamento de todos os consumidores externos, features ativadas ou o
estado pós-deploy. Nova ativação de lifecycle/dynamic/context/jornada exige nova
avaliação do consumidor e seus gates. O executor deve verificar imagem/flags,
health, version/schema/minimum e catálogo depois da promoção.

Rollback da imagem mantém banco 0030: o ensaio iniciou a imagem antiga com
uvicorn diretamente. Um compose antigo cujo command execute `alembic upgrade head`
pode falhar por não conhecer revision 0030; o rollback deve sobrescrever somente
o startup para uvicorn e nunca aplicar downgrade automático.
