# Arquitetura canônica — migração do existente

Base auditada: `fb50a57`, 2026-09-23. Histórico em
`maintenance/CURRENT_ARCHITECTURE.md`; suas afirmações de implantação são
históricas e não substituem verificação do candidato.

- Flutter em `cartilhas_app/`: Provider, repositories por feature,
  SharedPreferences/secure storage, SQLite opcional para outbox durável,
  rotas imperativas com `trackedRoute`.
- FastAPI em `api/app/`: SQLAlchemy, PostgreSQL alvo, Alembic, autenticação,
  vínculos, cursos/edições, events e dashboard. Testes locais usam SQLite;
  golden path da API também validado com PostgreSQL 16 isolado na VPS.
- Worker em `cartilhas_app/cloudflare/tutor-tds-gateway/`: IA e certificados
  legados. AnythingLLM é integração de IA, não fonte de autorização.
- Google Sheets é destino analítico. `learning_events` e sync worker já existem.
- Staging tem compose, env examples, seed e ops próprios. Documentação registra
  testes em 20/21-09; não equivalem ao aceite do contrato novo.

Fronteira alvo: UI → ViewModel/controller → LearningContext/domínio → Repository
→ API → autorização → PostgreSQL. FakeRepository valida contrato antes da
conexão real. Estados e política offline fazem parte do contrato da feature.

Menor migração: manter classes, institutions e CourseVersion; acrescentar vínculo
contextual com backfill verificável e resolver único; evoluir linhagem de matrícula
sem quebrar endpoints legados; compartilhar projeção de progresso; migrar uma
jornada Flutter e outbox por vez. Flag desligada até staging. Não alterar outras
waves nem trocar roteador ou state management durante esta fatia. Hospedagem
gerenciada em staging foi autorizada em DECISIONS, item 16; domínio preservado.

Fatia atual: `cohort-enrollment-v2` resolve LearningContext com vínculos físicos
da migration 0019 e compartilha `_student_progress` completo. Flutter usa repository
real/Fake, controller e cache contextual; flag `LEARNING_CONTEXT_ENABLED`
desligada por padrão em API/Flutter. Detalhes e limites em
`production/CONTEXT_CORE_SLICE.md`. Schema e backfill testados em PostgreSQL
isolado; candidato ativado em staging FastAPI Cloud + Supabase com flags,
HTTPS e contrato verificados. Wave 1 aprovada: seis fases Android e isolamento
HTTPS entre turmas, conforme `production/WAVE1_ACCEPTANCE.md`. Wave 2 deve
reutilizar CourseVersion/editor e preservar o núcleo aprovado.

Reversão: desativar flag e voltar ao caminho legado; preservar colunas/dados
aditivos. Migração deve suportar base vazia e cópia staging restaurada, detectar
ambiguidades antes de backfill e ter forward recovery documentado.
