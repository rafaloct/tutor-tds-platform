# Tutor TDS — Plano de Migração

> **Onda 0 — Auditoria Técnica**
> Data: 2026-09-19

---

## Princípio

**Não quebrar o que está funcionando.**

A versão 1.2.0+11 está em produção e atende participantes reais do Programa TDS/Tocantins.
Cada etapa de migração deve ser incremental, reversível e testada fora de produção antes de ser aplicada.

### Restrição de IA

- DeepSeek não será usado pelo Tutor TDS, diretamente nem por roteamento automático.
- A instância AnythingLLM do app foi auditada em 2026-09-19 e usa OpenRouter com `google/gemini-2.5-flash-lite`.
- Um modelo DeepSeek está apenas instalado no Ollama compartilhado da VPS; não está selecionado pelo Tutor TDS e não deve ser removido sem confirmar dependências de outros projetos.
- Qualquer troca futura de modelo deve usar allowlist explícita e teste em staging.

---

## Estado Atual (Baseline)

```
Flutter App (APK/AAB v1.2.0+11)
        │
        ├─► Cloudflare Worker (IA + Certificados)
        ├─► Google Apps Script (Analytics → Sheets)
        └─► AnythingLLM na VPS (RAG)
```

Dados transacionais residem em:
- SharedPreferences local (usuário, progresso, certificados)
- Google Sheets (analytics)
- Cloudflare KV (certificados públicos)

---

## Arquitetura-Alvo (ao final das Ondas 1-3)

```
Flutter App
        │
        ▼ HTTPS
Tutor TDS API (VPS / Dokploy)
        │
        ├─► PostgreSQL (banco relacional)
        │       └─► Sync Worker → Google Sheets (espelho)
        │
        ├─► Cloudflare Worker (gateway IA — mantido)
        │
        └─► AnythingLLM (mantido na VPS)
```

---

## Onda 1 — Fundação (Estimativa: 2-3 semanas)

### Objetivo
Criar a infraestrutura de dados e autenticação sem quebrar o app atual.

### Passos

#### 1.1 — Banco de Dados

```
Opção A: PostgreSQL na VPS Hostinger (custo: zero, latência mínima)
Opção B: Neon PostgreSQL (custo: free tier / consumo)
Recomendação: Opção A (VPS já paga, recursos disponíveis)
```

Migrations iniciais:
```sql
-- Tabelas mínimas para a Onda 1
institutions
programs
users
sessions
enrollments
learning_events
certificates (referência — KV permanece fonte para verificação)
sync_log
```

#### 1.2 — API REST Tutor TDS

**Stack adotada para a primeira implementação:** FastAPI (Python), SQLAlchemy e Alembic. A decisão evita manter duas alternativas abertas durante a execução e será validada em staging.
**Deploy:** Container Docker no Dokploy (VPS)
**Porta interna:** 8000 (proxy reverso via Nginx/Dokploy)

Endpoints mínimos Onda 1:
```
POST /auth/register
POST /auth/login
POST /auth/refresh

GET  /courses
GET  /courses/:id

POST /events          # LearningEvent
GET  /events?user_id&course_id

GET  /health
```

#### 1.3 — Sync Worker (Google Sheets)

Worker separado (mesmo container ou serviço Dokploy) que:
1. Lê `learning_events` com `sync_status = pending`
2. Formata linha para a planilha
3. Grava via Google Sheets API v4
4. Marca `sync_status = synced` ou `failed`
5. Retry automático em falhas transitórias

**Critério:** ≥ 99% dos eventos sincronizados ou reconciliados.

#### 1.4 — Autenticação no Flutter

Adicionar ao Flutter:
- Registro com CPF + telefone (ou OTP)
- JWT armazenado em `flutter_secure_storage`
- Interceptor HTTP para enviar token em todas as requisições

**IMPORTANTE:** Manter login pela tela de cadastro existente.
Não exigir nova autenticação de usuários que já configuraram o app.
Migração suave: se usuário tem `user_cpf` no SharedPreferences, auto-registrar na primeira conexão com a API.

#### 1.5 — CI/CD e Staging

Estrutura no Dokploy:
```
Projeto: tutor-tds-production
  ├── api (porta 8000)
  ├── sync-worker
  ├── pwa-nginx (porta 80)
  └── anythingllm

Projeto: tutor-tds-staging
  ├── api-staging (porta 8001)
  ├── sync-worker-staging
  └── pwa-staging (porta 8080)
```

---

## Onda 2 — Aprendizagem Dinâmica

### Objetivo
Fazer com que novos cursos não exijam rebuild do APK.

### Passos

#### 2.1 — API de Cursos

```
GET /courses → lista de cartilhas disponíveis
GET /courses/:id → detalhes + seções + mensagens
GET /courses/:id/progress?user_id → progresso atual
```

#### 2.2 — Flutter: Carregamento Remoto

Modificar `HomeScreen._loadCartilhas()`:
```dart
// Atual: carrega de assets/data/lessons/*.json
// Novo: tenta API primeiro, fallback para assets locais
Future<List<Cartilha>> _loadCartilhas() async {
  try {
    final remote = await CourseRepository.fetchAll();
    if (remote.isNotEmpty) return remote;
  } catch (_) {}
  return _loadLocalCartilhas(); // fallback offline
}
```

#### 2.3 — LearningEvents no Servidor

Substituir `DataSyncService.logEvent()` por requisição autenticada à API:
```
POST /events
{
  "event_type": "lesson_started",
  "course_id": "agricultura-sustentavel",
  "section_id": "secao-1",
  "started_at": "2026-09-19T14:00:00Z",
  "device_id": "uuid-local"
}
```

Manter queue local offline com sync posterior.

#### 2.4 — Controle de 40 Horas

Colunas na tabela `learning_events`:
```sql
active_seconds    -- tempo com interação real
validated_seconds -- aprovado por regra pedagógica
```

Endpoint:
```
GET /users/:id/hours?course_id
→ { planned_hours, validated_hours, active_usage }
```

---

## Onda 3 — Classroom

### Passos

#### 3.1 — Turmas

```sql
classes (id, institution_id, course_id, teacher_id, start_date, end_date, status)
class_enrollments (class_id, user_id, enrolled_at, status)
class_monitors (class_id, user_id)
```

#### 3.2 — Painel Professor

Endpoint:
```
GET /classes/:id/dashboard
→ alunos com progresso, alertas de inatividade, pendências
```

#### 3.3 — Certificados Migrados

Manter KV Cloudflare para verificação pública (não mudar URL de validação).
Adicionar referência no banco:
```sql
certificates (id, user_id, course_id, class_id, issued_at, verification_url, hash)
```

---

## Regras de Migração de Dados

| Origem | Destino | Estratégia |
|---|---|---|
| Google Sheets (Alunos) | users no PostgreSQL | Import via script, de-duplicação por CPF hash |
| SharedPreferences (certificados) | certificates no PostgreSQL | Auto-sync na primeira autenticação |
| Cloudflare KV | mantido + referência no banco | Não migrar — KV é fonte de verificação pública |
| Google Sheets (Eventos) | learning_events no banco | Opcional — dados históricos podem ficar no Sheets |

---

## Regras de Não-Regressão

1. O Google Sheets deve continuar recebendo dados até o Sync Worker estar comprovadamente estável (≥ 7 dias sem falha).
2. O Cloudflare Worker de certificados NÃO deve ser alterado sem teste em ambiente de preview primeiro.
3. O app na Play Store deve continuar funcionando com a API antiga enquanto a nova não for validada.
4. Nenhuma migration destrutiva será executada em produção sem backup verificado.
5. O usuário deve ser notificado de qualquer mudança que exija novo login.

---

## Cronograma Sugerido

| Onda | Prazo estimado | Bloqueadores |
|---|---|---|
| Onda 0 (Auditoria) | ✅ Concluído | — |
| Onda 1 (Fundação) | 2-3 semanas | Acesso SSH à VPS, aprovação do plano |
| Onda 2 (Aprendizagem) | 2-3 semanas | API da Onda 1 estável |
| Onda 3 (Classroom) | 2-3 semanas | Onda 2 estável |
| Onda 4 (Creator/Comercial) | 3-4 semanas | Aprovação de modelo de negócio |
| Onda 5 (QA/Release) | 1-2 semanas | Onda 3 estável |

---

_Este plano deve ser revisado e aprovado antes do início de cada onda._
