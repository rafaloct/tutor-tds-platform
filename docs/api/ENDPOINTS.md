# Referência completa de endpoints

Gerada pelo contrato candidato. Leia primeiro [o guia](README.md). Exemplos são sintéticos; IDs devem apontar para fixtures do mesmo ambiente. A validação Pydantic confirma tipos/validadores dos exemplos tipados, sem executar comandos ou comprovar autorização relacional.

Árvore Git da fonte: `b55db91a49bd70f8263c2dfed64edd8246cec768`. Operações: **134**.

## Índice

- [DELETE /auth/me](#operacao-001)
- [GET /admin/hierarchy](#operacao-002)
- [GET /admin/ledger](#operacao-003)
- [GET /admin/media/{media_id}/history](#operacao-004)
- [GET /admin/sync/status](#operacao-005)
- [GET /analytics/usage](#operacao-006)
- [GET /assessment-attempts](#operacao-007)
- [GET /assessment-attempts/{attempt_id}](#operacao-008)
- [GET /assessment-attempts/{attempt_id}/content](#operacao-009)
- [GET /assessment-contents/{content_id}](#operacao-010)
- [GET /auth/me](#operacao-011)
- [GET /certificate-requests](#operacao-012)
- [GET /certificate-requests/contexts](#operacao-013)
- [GET /certificate-requests/review-queue](#operacao-014)
- [GET /certificate-requests/{request_id}](#operacao-015)
- [GET /certificate-requests/{request_id}/candidate-status](#operacao-016)
- [GET /certificates](#operacao-017)
- [GET /classes](#operacao-018)
- [GET /classes/{class_id}](#operacao-019)
- [GET /classes/{class_id}/assessment-attempts](#operacao-020)
- [GET /classes/{class_id}/assessment-attempts/{attempt_id}](#operacao-021)
- [GET /classes/{class_id}/assessment-attempts/{attempt_id}/content](#operacao-022)
- [GET /classes/{class_id}/course](#operacao-023)
- [GET /classes/{class_id}/dashboard](#operacao-024)
- [GET /classes/{class_id}/eligible-students](#operacao-025)
- [GET /classes/{class_id}/evidence-imports/{import_id}](#operacao-026)
- [GET /classes/{class_id}/exceptions](#operacao-027)
- [GET /classes/{class_id}/journey-activity](#operacao-028)
- [GET /classes/{class_id}/journey-export](#operacao-029)
- [GET /classes/{class_id}/learning-context](#operacao-030)
- [GET /classes/{class_id}/mentorship-cases](#operacao-031)
- [GET /classes/{class_id}/mentorship-cases/{case_id}](#operacao-032)
- [GET /classes/{class_id}/monitor-exceptions](#operacao-033)
- [GET /classes/{class_id}/reports/{report_id}](#operacao-034)
- [GET /classes/{class_id}/sessions](#operacao-035)
- [GET /classes/{class_id}/sessions/open](#operacao-036)
- [GET /classes/{class_id}/sessions/{session_id}](#operacao-037)
- [GET /classes/{class_id}/sessions/{session_id}/attendance/{user_id}](#operacao-038)
- [GET /classes/{class_id}/sessions/{session_id}/presence](#operacao-039)
- [GET /classes/{class_id}/students/{owner_id}/assessment-attempts](#operacao-040)
- [GET /classes/{class_id}/students/{owner_id}/assessment-attempts/{attempt_id}](#operacao-041)
- [GET /classes/{class_id}/students/{owner_id}/assessment-attempts/{attempt_id}/content](#operacao-042)
- [GET /classes/{class_id}/students/{user_id}/baseline](#operacao-043)
- [GET /classes/{class_id}/students/{user_id}/learning-context](#operacao-044)
- [GET /classes/{class_id}/students/{user_id}/mentors](#operacao-045)
- [GET /courses](#operacao-046)
- [GET /courses/{course_id}](#operacao-047)
- [GET /creators/me/analytics](#operacao-048)
- [GET /creators/me/media](#operacao-049)
- [GET /creators/me/scores](#operacao-050)
- [GET /editor/context](#operacao-051)
- [GET /editor/courses](#operacao-052)
- [GET /editor/courses/{course_id}](#operacao-053)
- [GET /events](#operacao-054)
- [GET /health](#operacao-055)
- [GET /live](#operacao-056)
- [GET /media](#operacao-057)
- [GET /media/{media_id}](#operacao-058)
- [GET /media/{media_id}/playback/{token}](#operacao-059)
- [GET /media/{media_id}/rating](#operacao-060)
- [GET /operations/classes](#operacao-061)
- [GET /operations/classes/options](#operacao-062)
- [GET /operations/classes/team-candidates](#operacao-063)
- [GET /operations/classes/{class_id}/readiness](#operacao-064)
- [GET /operations/scopes](#operacao-065)
- [GET /public/courses](#operacao-066)
- [GET /public/courses/{slug}](#operacao-067)
- [GET /support/config](#operacao-068)
- [GET /support/identity](#operacao-069)
- [GET /users/{user_id}/hours](#operacao-070)
- [GET /version](#operacao-071)
- [PATCH /admin/media/{media_id}](#operacao-072)
- [PATCH /classes/{class_id}/mentorship-cases/{case_id}](#operacao-073)
- [PATCH /courses/{course_id}](#operacao-074)
- [POST /admin/accounts](#operacao-075)
- [POST /admin/classes](#operacao-076)
- [POST /admin/classes/{class_id}/monitors/{user_id}](#operacao-077)
- [POST /admin/classes/{class_id}/sessions](#operacao-078)
- [POST /admin/classes/{class_id}/students/{user_id}](#operacao-079)
- [POST /admin/creator-scores/calculate](#operacao-080)
- [POST /admin/enrollments](#operacao-081)
- [POST /admin/institutions](#operacao-082)
- [POST /admin/ledger/simulate](#operacao-083)
- [POST /admin/media](#operacao-084)
- [POST /admin/media/{media_id}/archive](#operacao-085)
- [POST /admin/media/{media_id}/block](#operacao-086)
- [POST /admin/media/{media_id}/publish](#operacao-087)
- [POST /admin/programs](#operacao-088)
- [POST /admin/programs/{program_id}/courses/{course_id}](#operacao-089)
- [POST /admin/programs/{program_id}/memberships](#operacao-090)
- [POST /auth/activation-invites](#operacao-091)
- [POST /auth/login](#operacao-092)
- [POST /auth/refresh](#operacao-093)
- [POST /auth/register](#operacao-094)
- [POST /certificate-requests](#operacao-095)
- [POST /certificate-requests/{request_id}/candidate-checkpoints/{checkpoint_id}](#operacao-096)
- [POST /certificate-requests/{request_id}/candidate-evidence](#operacao-097)
- [POST /certificate-requests/{request_id}/candidate-lifecycle](#operacao-098)
- [POST /certificate-requests/{request_id}/emission-candidate](#operacao-099)
- [POST /certificate-requests/{request_id}/emit](#operacao-100)
- [POST /certificate-requests/{request_id}/reconcile-candidate](#operacao-101)
- [POST /certificate-requests/{request_id}/resubmit](#operacao-102)
- [POST /certificate-requests/{request_id}/review](#operacao-103)
- [POST /certificates/references](#operacao-104)
- [POST /checkins/code](#operacao-105)
- [POST /classes/{class_id}/evidence-imports](#operacao-106)
- [POST /classes/{class_id}/evidence/{evidence_id}/review](#operacao-107)
- [POST /classes/{class_id}/mentorship-cases](#operacao-108)
- [POST /classes/{class_id}/sessions/{session_id}/attendance/{user_id}](#operacao-109)
- [POST /classes/{class_id}/sessions/{session_id}/checkins](#operacao-110)
- [POST /classes/{class_id}/sessions/{session_id}/close](#operacao-111)
- [POST /classes/{class_id}/sessions/{session_id}/presence/{user_id}](#operacao-112)
- [POST /classes/{class_id}/sessions/{session_id}/token](#operacao-113)
- [POST /courses](#operacao-114)
- [POST /courses/{course_id}/archive](#operacao-115)
- [POST /courses/{course_id}/publish](#operacao-116)
- [POST /courses/{course_id}/submit](#operacao-117)
- [POST /courses/{course_id}/versions](#operacao-118)
- [POST /events](#operacao-119)
- [POST /media/{media_id}/playback-authorizations](#operacao-120)
- [POST /operations/classes](#operacao-121)
- [POST /operations/classes/{class_id}/plan](#operacao-122)
- [POST /operations/classes/{class_id}/team](#operacao-123)
- [POST /operations/classes/{class_id}/transition](#operacao-124)
- [POST /operations/{class_id}/commands](#operacao-125)
- [POST /operations/{class_id}/inspect](#operacao-126)
- [POST /operations/{class_id}/search](#operacao-127)
- [PUT /admin/programs/{program_id}/courses/{course_id}/workload](#operacao-128)
- [PUT /assessment-attempts/{attempt_id}](#operacao-129)
- [PUT /assessment-contents/{content_id}](#operacao-130)
- [PUT /classes/{class_id}/certificate-policy-candidate](#operacao-131)
- [PUT /classes/{class_id}/students/{user_id}](#operacao-132)
- [PUT /classes/{class_id}/students/{user_id}/baseline](#operacao-133)
- [PUT /media/{media_id}/rating](#operacao-134)

<a id="operacao-001"></a>

## `DELETE /auth/me`

Delete Me. Fonte: [api/app/auth.py:237](../../api/app/auth.py).

**Autenticação:** Bearer obrigatório; papel global: student.

**Permissão:** Token Bearer com papel global student; acesso somente aos dados do próprio titular.

**Comportamento:** Exclui a própria conta e os dados transacionais associados; retorna 204 sem corpo. Vínculo docente, monitor ou equipe/creator ativa exige exclusão assistida e produz 409; agenda remoção da sincronização externa.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request DELETE "${TDS_API_BASE}/auth/me" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 204 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **204**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Sem corpo de resposta após exclusão autorizada. Há proteção contra autoexclusão de contas de equipe.

Sem body JSON.

### Status e erros

Status declarados no OpenAPI: 204, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Acesso não autorizado para esta função. |
| 409 | A conta possui vínculos que exigem atendimento da equipe TDS. |
| 409 | Conta de equipe/creator exige exclusão assistida para preservar registros institucionais. |
| 409 | Conta vinculada a uma turma. Solicite a exclusão à equipe TDS. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-002"></a>

## `GET /admin/hierarchy`

Hierarchy. Fonte: [api/app/organizations.py:335](../../api/app/organizations.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Consulta instituições, programas, ofertas e participações; filtro de instituição opcional.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `institution_id` | query | não | string / null | maxLength=36 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/admin/hierarchy" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | array de [InstitutionHierarchy](SCHEMAS.md#schema-InstitutionHierarchy) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
[
  {
    "name": "Pessoa Sintética QA",
    "id": "00000000-0000-4000-8000-000000000001",
    "programs": [
      {
        "institution_id": "00000000-0000-4000-8000-000000000001",
        "name": "Pessoa Sintética QA",
        "id": "00000000-0000-4000-8000-000000000001",
        "course_ids": [
          "curso-qa"
        ],
        "memberships": [
          {
            "user_id": "00000000-0000-4000-8000-000000000004",
            "role": "student",
            "program_id": "00000000-0000-4000-8000-000000000002",
            "status": "active"
          }
        ]
      }
    ]
  }
]
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-003"></a>

## `GET /admin/ledger`

List Ledger. Fonte: [api/app/commercial.py:283](../../api/app/commercial.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou finance ativo no programa solicitado.

**Comportamento:** Consulta lançamentos de simulação do programa; não registra aprovação financeira nem efetua pagamento.

**Flags/gates:** `COMMERCIAL_SIMULATION_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `program_id` | query | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/admin/ledger?program_id=00000000-0000-4000-8000-000000000002" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | array de [LedgerResponse](SCHEMAS.md#schema-LedgerResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Exige COMMERCIAL_SIMULATION_ENABLED=true, PAYMENT_ADAPTER=disabled, escopo financeiro autorizado e source_event_id da mídia do score. Exemplo de simulação; o evento-fonte da fixture pode estar fora da janela do score. Nunca representa pagamento/payout real.

```json
[
  {
    "id": "00000000-0000-4000-8000-000000000001",
    "institution_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "creator_user_id": "00000000-0000-4000-8000-000000000001",
    "media_id": "00000000-0000-4000-8000-000000000001",
    "source_event_id": "00000000-0000-4000-8000-000000000001",
    "rule_version": "creator-score-v2",
    "entry_type": "accrual",
    "amount_minor": 100,
    "currency": "BRL",
    "status": "simulated",
    "idempotency_key": "qa-command-20261013-0001",
    "calculation_snapshot": {
      "creator_score_id": "00000000-0000-4000-8000-000000000001",
      "score_basis_points": 0,
      "mode": "simulated",
      "payment_adapter": "disabled"
    },
    "created_at": "2026-10-13T12:00:00Z"
  }
]
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Função não autorizada neste programa. |
| 404 | Simulação comercial desativada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-004"></a>

## `GET /admin/media/{media_id}/history`

Media Editorial History. Fonte: [api/app/media.py:330](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global, coordinator ativo no programa ou creator ativo proprietário da mídia.

**Comportamento:** Lista histórico de transições editoriais em ordem de ocorrência, com ator/papel/motivo.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `media_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/admin/media/00000000-0000-4000-8000-000000000001/history" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | array de [EditorialTransitionResponse](SCHEMAS.md#schema-EditorialTransitionResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Histórico da fixture após criação por creator com vínculo ativo: transição inicial null → draft e motivo fixado pela rota. Publicação/bloqueio/arquivamento acrescentam novas transições em vez de reescrever este histórico.

```json
[
  {
    "id": "00000000-0000-4000-8000-000000000021",
    "media_id": "00000000-0000-4000-8000-000000000001",
    "from_status": null,
    "to_status": "draft",
    "actor_user_id": "00000000-0000-4000-8000-000000000001",
    "actor_role": "creator",
    "reason": "Mídia criada como rascunho.",
    "occurred_at": "2026-10-13T12:00:00Z"
  }
]
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Vínculo editorial não autorizado. |
| 404 | Mídia não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-005"></a>

## `GET /admin/sync/status`

Sync Status. Fonte: [api/app/sync_api.py:28](../../api/app/sync_api.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Consulta contagens da fila e horários da última sincronização/falha; exhausted conta falhas que atingiram SYNC_MAX_ATTEMPTS. Não executa sincronização.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/admin/sync/status" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [SyncQueueStatus](SCHEMAS.md#schema-SyncQueueStatus) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "pending": 0,
  "processing": 0,
  "synced": 0,
  "failed": 0,
  "exhausted": 0,
  "last_success_at": null,
  "last_failure_at": null
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-006"></a>

## `GET /analytics/usage`

Usage Summary. Fonte: [api/app/analytics.py:39](../../api/app/analytics.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin pode consultar todo o escopo ou uma turma. Instrutor designado pode consultar alunos ativos de sua turma; monitor não pode consultar analytics da turma. Outros usuários acessam apenas a si mesmos.

**Comportamento:** Agrega page_viewed, resource_opened e feature_used por curso/alvo nos últimos 1 a 90 dias. Quem possui vínculo docente/monitor precisa informar class_id. user_id fora da turma ativa retorna 404; telemetria não concede resultado acadêmico.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `days` | query | não | integer | default=30; minimum=1; maximum=90 |
| `user_id` | query | não | string / null | maxLength=36 |
| `class_id` | query | não | string / null | maxLength=36 |
| `course_id` | query | não | string / null | maxLength=120 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/analytics/usage" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [UsageSummary](SCHEMAS.md#schema-UsageSummary) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "period_start": "2026-10-01T00:00:00Z",
  "period_end": "2026-10-02T00:00:00Z",
  "items": [
    {
      "course_id": "curso-qa",
      "event_type": "page_viewed",
      "target_id": "00000000-0000-4000-8000-000000000001",
      "count": 1,
      "unique_users": 1,
      "last_occurred_at": "2026-10-01T12:00:00Z"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Analytics não autorizado para monitor. |
| 403 | Analytics não autorizado. |
| 404 | Estudante ativo não encontrado nesta turma. |
| 404 | Turma não encontrada. |
| 422 | Professor ou monitor deve informar class_id. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-007"></a>

## `GET /assessment-attempts`

List Attempts. Fonte: [api/app/assessment_sync.py:598](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; papel global: student.

**Permissão:** Token Bearer com papel global student; acesso somente aos dados do próprio titular.

**Comportamento:** Consulta somente tentativas próprias de origem practice; tentativas editoriais devem usar rotas contextuais da turma.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | query | não | string / null | minLength=1; maxLength=120 |
| `mode` | query | não | enum ["quiz", "exam"] / null | — |
| `completed` | query | não | boolean / null | — |
| `limit` | query | não | integer | default=50; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/assessment-attempts" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentAttemptPage](SCHEMAS.md#schema-AssessmentAttemptPage) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "attempts": [
    {
      "course_id": "curso-qa",
      "origin": "practice",
      "topic": "Tema sintético",
      "mode": "quiz",
      "revision": 1,
      "current_index": 0,
      "remaining_seconds": 0,
      "completed": false,
      "score": 0,
      "updated_at": "2026-10-01T12:00:00Z",
      "attempt_id": "00000000-0000-4000-8000-000000000001"
    }
  ],
  "total": 1,
  "limit": 20,
  "offset": 0
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-008"></a>

## `GET /assessment-attempts/{attempt_id}`

Get Attempt. Fonte: [api/app/assessment_sync.py:576](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; papel global: student.

**Permissão:** Token Bearer com papel global student; acesso somente aos dados do próprio titular.

**Comportamento:** Consulta somente tentativas próprias de origem practice; tentativas editoriais devem usar rotas contextuais da turma.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `attempt_id` | path | sim | string | minLength=1; maxLength=180; pattern="^[A-Za-z0-9][A-Za-z0-9_.:-]*$" |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/assessment-attempts/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentAttemptResponse](SCHEMAS.md#schema-AssessmentAttemptResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "course_id": "curso-qa",
  "origin": "practice",
  "topic": "Tema sintético",
  "mode": "quiz",
  "revision": 1,
  "current_index": 0,
  "remaining_seconds": 0,
  "completed": false,
  "score": 0,
  "updated_at": "2026-10-01T12:00:00Z",
  "attempt_id": "00000000-0000-4000-8000-000000000001"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Tentativa não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-009"></a>

## `GET /assessment-attempts/{attempt_id}/content`

Get Attempt Content. Fonte: [api/app/assessment_sync.py:538](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; papel global: student.

**Permissão:** Token Bearer com papel global student; acesso somente aos dados do próprio titular.

**Comportamento:** Retorna conteúdo imutável da tentativa própria practice; inclui gabarito apenas após completed=true. Tentativa legado sem conteúdo associado retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `attempt_id` | path | sim | string | minLength=1; maxLength=180; pattern="^[A-Za-z0-9][A-Za-z0-9_.:-]*$" |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/assessment-attempts/00000000-0000-4000-8000-000000000001/content" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentContentResponse](SCHEMAS.md#schema-AssessmentContentResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "assessment_content_id": "00000000-0000-4000-8000-000000000001",
  "course_id": "curso-qa",
  "topic": "Tema sintético",
  "mode": "quiz",
  "title": "Curso Sintético QA",
  "duration_seconds": 0,
  "questions": [
    {
      "question": "Questão sintética?",
      "options": [
        "qa-example"
      ],
      "topic": "Tema sintético"
    }
  ],
  "answer_key": null,
  "created_at": "2026-10-01T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Conteúdo de avaliação não encontrado. |
| 404 | Tentativa não encontrada. |
| 409 | Expressão: {'code': 'legacy_attempt_without_content'} |
| 409 | Expressão: {'code': 'published_block_content_is_server_owned'} |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-010"></a>

## `GET /assessment-contents/{content_id}`

Get Assessment Content Preview. Fonte: [api/app/assessment_sync.py:323](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; papel global: student.

**Permissão:** Token Bearer com papel global student; acesso somente aos dados do próprio titular.

**Comportamento:** Consulta preview de conteúdo próprio practice sem gabarito; conteúdo de outra pessoa/outra origem retorna 404.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `content_id` | path | sim | string | minLength=1; maxLength=180; pattern="^[A-Za-z0-9][A-Za-z0-9_.:-]*$" |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/assessment-contents/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentContentResponse](SCHEMAS.md#schema-AssessmentContentResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Prévia de prática do próprio aluno sempre retorna answer_key null e questions sem correct_index/explanation. Gabarito possui fluxo próprio separado.

```json
{
  "assessment_content_id": "00000000-0000-4000-8000-000000000001",
  "course_id": "curso-exemplo",
  "topic": "Tema sintético",
  "mode": "quiz",
  "title": "Curso Sintético QA",
  "duration_seconds": 0,
  "questions": [
    {
      "question": "Questão sintética?",
      "options": [
        "qa-example",
        "qa-example"
      ],
      "topic": "Tema sintético"
    }
  ],
  "answer_key": null,
  "created_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Conteúdo de avaliação não encontrado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-011"></a>

## `GET /auth/me`

Me. Fonte: [api/app/auth.py:221](../../api/app/auth.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco.

**Comportamento:** Retorna id, nome e papel global da conta autenticada.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/auth/me" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [PublicUser](SCHEMAS.md#schema-PublicUser) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "name": "Pessoa Sintética QA",
  "role": "student"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Expressão: detail |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-012"></a>

## `GET /certificate-requests`

Own. Fonte: [api/app/certificate_requests.py:190](../../api/app/certificate_requests.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco.

**Comportamento:** Lista pedidos privados do próprio titular com estado e projeção de elegibilidade.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/certificate-requests" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Visibilidade do autor ou revisor autorizado; aprovação/rejeição são decisões humanas e não emissão.

```json
{
  "requests": [
    {
      "id": "00000000-0000-4000-8000-000000000019",
      "enrollment_id": "00000000-0000-4000-8000-000000000007",
      "course_id": "curso-exemplo",
      "course_version_id": "00000000-0000-4000-8000-000000000008",
      "class_id": "00000000-0000-4000-8000-000000000003",
      "program_id": "00000000-0000-4000-8000-000000000002",
      "holder_name": "Pessoa Exemplo",
      "course_title": "Curso Exemplo",
      "program_name": "Programa Exemplo",
      "institution_name": "Instituição Exemplo",
      "status": "pending",
      "revision": 1,
      "requested_at": "2026-10-13T12:00:00Z",
      "reviewed_at": null,
      "review_reason": null,
      "class_name": "Turma Exemplo",
      "eligibility": {
        "required_seconds": 288000,
        "validated_seconds": 0,
        "completed": false,
        "eligible": false
      }
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Matrícula não encontrada. |
| 409 | Hierarquia acadêmica inconsistente. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-013"></a>

## `GET /certificate-requests/contexts`

Contexts. Fonte: [api/app/certificate_requests.py:145](../../api/app/certificate_requests.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco.

**Comportamento:** Lista contextos de matrícula próprios ativos compatíveis com curso/edição e calcula elegibilidade. Sem turma exige edição publicamente publicada; turma exige edição fixada e linhagem correspondente.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | query | sim | string | minLength=1; maxLength=120 |
| `course_version_id` | query | sim | string | minLength=1; maxLength=36 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/certificate-requests/contexts?course_id=curso-qa&course_version_id=00000000-0000-4000-8000-000000000008" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "contexts": [
    {
      "enrollment_id": "00000000-0000-4000-8000-000000000007",
      "program_name": "Programa Exemplo",
      "class_id": "00000000-0000-4000-8000-000000000003",
      "class_name": "Turma Exemplo",
      "course_version_id": "00000000-0000-4000-8000-000000000008",
      "course_title": "Curso Exemplo",
      "eligibility": {
        "required_seconds": 288000,
        "validated_seconds": 0,
        "completed": false,
        "eligible": false
      }
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Matrícula não encontrada. |
| 409 | Hierarquia acadêmica inconsistente. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-014"></a>

## `GET /certificate-requests/review-queue`

Queue. Fonte: [api/app/certificate_requests.py:196](../../api/app/certificate_requests.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global, coordinator/admin com participação ativa no programa ou teacher ativo designado à turma do pedido.

**Comportamento:** Lista pedidos pending no escopo de revisão e de outra pessoa; sem escopo retorna 403. Monitor não recebe a fila por papel de monitor.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/certificate-requests/review-queue" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Visibilidade do autor ou revisor autorizado; aprovação/rejeição são decisões humanas e não emissão.

```json
{
  "requests": [
    {
      "id": "00000000-0000-4000-8000-000000000019",
      "enrollment_id": "00000000-0000-4000-8000-000000000007",
      "course_id": "curso-exemplo",
      "course_version_id": "00000000-0000-4000-8000-000000000008",
      "class_id": "00000000-0000-4000-8000-000000000003",
      "program_id": "00000000-0000-4000-8000-000000000002",
      "holder_name": "Pessoa Exemplo",
      "course_title": "Curso Exemplo",
      "program_name": "Programa Exemplo",
      "institution_name": "Instituição Exemplo",
      "status": "pending",
      "revision": 1,
      "requested_at": "2026-10-13T12:00:00Z",
      "reviewed_at": null,
      "review_reason": null,
      "class_name": "Turma Exemplo",
      "eligibility": {
        "required_seconds": 288000,
        "validated_seconds": 0,
        "completed": false,
        "eligible": false
      }
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Sem escopo de revisão autorizado. |
| 404 | Matrícula não encontrada. |
| 409 | Hierarquia acadêmica inconsistente. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-015"></a>

## `GET /certificate-requests/{request_id}`

Detail. Fonte: [api/app/certificate_requests.py:223](../../api/app/certificate_requests.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Titular ou revisor autorizado: Token Bearer; admin global, coordinator/admin com participação ativa no programa ou teacher ativo designado à turma do pedido.

**Comportamento:** Consulta pedido visível com histórico/eligibilidade; pedido fora do escopo retorna 404.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `request_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/certificate-requests/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "id": "00000000-0000-4000-8000-000000000019",
  "enrollment_id": "00000000-0000-4000-8000-000000000007",
  "course_id": "curso-exemplo",
  "course_version_id": "00000000-0000-4000-8000-000000000008",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "holder_name": "Pessoa Exemplo",
  "course_title": "Curso Exemplo",
  "program_name": "Programa Exemplo",
  "institution_name": "Instituição Exemplo",
  "status": "pending",
  "revision": 1,
  "requested_at": "2026-10-13T12:00:00Z",
  "reviewed_at": null,
  "review_reason": null,
  "class_name": "Turma Exemplo",
  "eligibility": {
    "required_seconds": 288000,
    "validated_seconds": 0,
    "completed": false,
    "eligible": false
  }
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Matrícula não encontrada. |
| 404 | Pedido não encontrado. |
| 409 | Hierarquia acadêmica inconsistente. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-016"></a>

## `GET /certificate-requests/{request_id}/candidate-status`

Candidate Status. Fonte: [api/app/certificate_policy.py:326](../../api/app/certificate_policy.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; titular do pedido ou admin global/coordinator/admin ativo no programa/instrutor teacher ativo designado à turma. Exige matrícula contextual do titular ativa e consistente.

**Comportamento:** Somente development. Projeta trilha, baseline, frequência oficial, fichas e ciclo do candidato. CAPACITADO/VALID são estados do contrato candidato; institutional_release permanece blocked.

**Flags/gates:** `CERTIFICATE_CANDIDATE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `request_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/certificate-requests/00000000-0000-4000-8000-000000000001/candidate-status" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **503**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Resposta padrão e em staging/produção. Contrato institucional candidato exige TUTOR_ENVIRONMENT=development e CERTIFICATE_CANDIDATE_ENABLED=true, autorização contextual e política imutável reconciliada. A conclusão de todos os checkpoints também depende do transporte candidato. Provas sintéticas não liberam emissão institucional final.

```json
{
  "detail": "Contrato candidato desativado neste ambiente."
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Matrícula não encontrada. |
| 404 | Pedido contextual não encontrado. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 409 | Encontro configurado divergente ou ausente. |
| 409 | Encontros oficiais divergentes da turma. |
| 409 | Encontros oficiais não configurados de forma única. |
| 409 | Fonte editorial de checkpoint alterada ou ausente. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Política inconsistente ou divergente da edição. |
| 409 | Tipo de checkpoint sem representação validada. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Pedido diverge do contexto vigente. |
| 422 | Pedido rejeitado exige reenvio explícito pelo fluxo existente. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Contrato candidato desativado neste ambiente. |
| 503 | Oferta sem política institucional configurada. |

<a id="operacao-017"></a>

## `GET /certificates`

Own Certificates. Fonte: [api/app/certificates.py:258](../../api/app/certificates.py).

**Autenticação:** Bearer obrigatório; papel global: student.

**Permissão:** Token Bearer com papel global student; acesso somente aos dados do próprio titular.

**Comportamento:** Lista somente referências oficiais do titular por data de emissão; referências sintéticas candidatas são excluídas.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/certificates" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [CertificatePage](SCHEMAS.md#schema-CertificatePage) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "certificates": [
    {
      "id": "00000000-0000-4000-8000-000000000001",
      "user_id": "00000000-0000-4000-8000-000000000004",
      "program_id": null,
      "course_id": "curso-qa",
      "class_id": null,
      "holder_name": null,
      "course_title": null,
      "institution_name": null,
      "planned_hours": null,
      "issued_at": "2026-10-01T12:00:00Z",
      "verification_url": "https://example.org/verify/qa-certificate",
      "content_hash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-018"></a>

## `GET /classes`

Visible Classes. Fonte: [api/app/classrooms.py:471](../../api/app/classrooms.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco.

**Comportamento:** Lista turmas segundo vínculos ativos: admin global vê todas, equipe atribuída e aluno ativo veem seus escopos. enrolled_only=true restringe também o admin às próprias matrículas ativas e consistentes.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `enrolled_only` | query | não | boolean | default=false |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [ClassroomPage](SCHEMAS.md#schema-ClassroomPage) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "classes": [
    {
      "program_id": "00000000-0000-4000-8000-000000000002",
      "course_id": "curso-qa",
      "teacher_id": "00000000-0000-4000-8000-000000000005",
      "name": "Pessoa Sintética QA",
      "start_date": "2026-10-13",
      "end_date": "2026-10-14",
      "status": "planned",
      "id": "00000000-0000-4000-8000-000000000001"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-019"></a>

## `GET /classes/{class_id}`

Class Detail. Fonte: [api/app/classrooms.py:440](../../api/app/classrooms.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Consulta detalhe de turma com IDs dos participantes/monitores; aluno comum não recebe esta visão da equipe.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [ClassroomDetail](SCHEMAS.md#schema-ClassroomDetail) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-qa",
  "teacher_id": "00000000-0000-4000-8000-000000000005",
  "name": "Pessoa Sintética QA",
  "start_date": "2026-10-13",
  "end_date": "2026-10-14",
  "status": "planned",
  "id": "00000000-0000-4000-8000-000000000001",
  "student_ids": [
    "00000000-0000-4000-8000-000000000001"
  ],
  "monitor_ids": [
    "00000000-0000-4000-8000-000000000001"
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-020"></a>

## `GET /classes/{class_id}/assessment-attempts`

List Own Published Attempts. Fonte: [api/app/assessment_sync.py:641](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Exige contexto próprio resolvido com matrícula e vínculos ativos.

**Comportamento:** Consulta tentativas published_block cuja linhagem corresponde ao contexto atual da turma e titular. Não mistura tentativas practice.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `limit` | query | não | integer | default=50; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/assessment-attempts" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentAttemptPage](SCHEMAS.md#schema-AssessmentAttemptPage) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "attempts": [
    {
      "course_id": "curso-qa",
      "origin": "practice",
      "topic": "Tema sintético",
      "mode": "quiz",
      "revision": 1,
      "current_index": 0,
      "remaining_seconds": 0,
      "completed": false,
      "score": 0,
      "updated_at": "2026-10-01T12:00:00Z",
      "attempt_id": "00000000-0000-4000-8000-000000000001"
    }
  ],
  "total": 1,
  "limit": 20,
  "offset": 0
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Atividades dinâmicas contextuais não habilitadas neste ambiente. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-021"></a>

## `GET /classes/{class_id}/assessment-attempts/{attempt_id}`

Get Own Published Attempt. Fonte: [api/app/assessment_sync.py:660](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Exige contexto próprio resolvido com matrícula e vínculos ativos.

**Comportamento:** Consulta tentativas published_block cuja linhagem corresponde ao contexto atual da turma e titular. Não mistura tentativas practice.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `attempt_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/assessment-attempts/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentAttemptResponse](SCHEMAS.md#schema-AssessmentAttemptResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "course_id": "curso-qa",
  "origin": "practice",
  "topic": "Tema sintético",
  "mode": "quiz",
  "revision": 1,
  "current_index": 0,
  "remaining_seconds": 0,
  "completed": false,
  "score": 0,
  "updated_at": "2026-10-01T12:00:00Z",
  "attempt_id": "00000000-0000-4000-8000-000000000001"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Atividades dinâmicas contextuais não habilitadas neste ambiente. |
| 404 | Tentativa contextual não encontrada. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 409 | Expressão: {'code': 'stored_learning_context_conflict'} |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-022"></a>

## `GET /classes/{class_id}/assessment-attempts/{attempt_id}/content`

Get Own Published Attempt Content. Fonte: [api/app/assessment_sync.py:678](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Exige contexto próprio ativo e tentativa correspondente.

**Comportamento:** Consulta conteúdo editorial imutável da própria tentativa; gabarito não é exposto por este endpoint, inclusive após conclusão.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `attempt_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/assessment-attempts/00000000-0000-4000-8000-000000000001/content" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentContentResponse](SCHEMAS.md#schema-AssessmentContentResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "assessment_content_id": "00000000-0000-4000-8000-000000000001",
  "course_id": "curso-qa",
  "topic": "Tema sintético",
  "mode": "quiz",
  "title": "Curso Sintético QA",
  "duration_seconds": 0,
  "questions": [
    {
      "question": "Questão sintética?",
      "options": [
        "qa-example"
      ],
      "topic": "Tema sintético"
    }
  ],
  "answer_key": null,
  "created_at": "2026-10-01T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Atividades dinâmicas contextuais não habilitadas neste ambiente. |
| 404 | Tentativa contextual não encontrada. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 409 | Conteúdo contextual não pôde ser conferido. |
| 409 | Conteúdo contextual possui origem inválida. |
| 409 | Expressão: {'code': 'stored_learning_context_conflict'} |
| 409 | Tentativa contextual sem conteúdo imutável. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-023"></a>

## `GET /classes/{class_id}/course`

Classroom Course. Fonte: [api/app/classrooms.py:525](../../api/app/classrooms.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; equipe autorizada da turma ou aluno com matrícula e vínculos ativos e linhagem consistente.

**Comportamento:** Retorna snapshot imutável da edição published/archived fixada à turma, sem fallback silencioso ao catálogo público. Instrutor/admin autorizado vê gabarito; demais têm gabarito removido quando as duas flags estão ativas.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/course" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Snapshot da edição fixada na turma; inclui campos de conteúdo editorial. Sem edição consistente retorna 409. A projeção de aluno protege gabaritos quando as flags contextuais/dinâmicas estão ativas.

```json
{
  "sections": [
    {
      "id": "modulo-1",
      "title": "Introdução",
      "messages": [
        {
          "id": "mensagem-1",
          "type": "bot",
          "content": "Bem-vindo ao curso de exemplo.",
          "version_id": "d4e2d145-d35b-5d37-a62e-415008018a8d"
        }
      ],
      "version_id": "4ee7532d-fe21-5972-9720-2e3e863a53c4"
    }
  ],
  "id": "curso-exemplo",
  "title": "Curso Exemplo",
  "author": "Autoria Exemplo",
  "course_version_id": "00000000-0000-4000-8000-000000000008",
  "version_id": "00000000-0000-4000-8000-000000000008",
  "version_number": 1,
  "legacy_progress_compatible": false,
  "class_id": "00000000-0000-4000-8000-000000000003"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Turma não encontrada. |
| 409 | A versão do curso desta turma precisa ser conferida pela equipe. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-024"></a>

## `GET /classes/{class_id}/dashboard`

Class Dashboard. Fonte: [api/app/classrooms.py:563](../../api/app/classrooms.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou instrutor designado com participação ativa teacher/coordinator/admin no programa e vínculo contextual docente ativo quando existente. Monitor isoladamente não autoriza.

**Comportamento:** Retorna projeção pedagógica completa dos alunos ativos com o mesmo cálculo canônico de progresso usado pelo contexto do aluno; monitor usa o fluxo de exceções.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/dashboard" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [ClassroomDashboard](SCHEMAS.md#schema-ClassroomDashboard) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "classroom": {
    "program_id": "00000000-0000-4000-8000-000000000002",
    "course_id": "curso-qa",
    "teacher_id": "00000000-0000-4000-8000-000000000005",
    "name": "Pessoa Sintética QA",
    "start_date": "2026-10-13",
    "end_date": "2026-10-14",
    "status": "planned",
    "id": "00000000-0000-4000-8000-000000000001"
  },
  "generated_at": "2026-10-01T12:00:00Z",
  "expected_progress_percent": 0,
  "summary": {
    "total_students": 0,
    "inactive_students": 0,
    "pending_students": 0,
    "below_expected_students": 0,
    "baseline_linked_students": 0,
    "confirmed_participations": 0,
    "open_mentorship_cases": 0
  },
  "students": [
    {
      "user_id": "00000000-0000-4000-8000-000000000004",
      "name": "Pessoa Sintética QA",
      "enrollment_id": "00000000-0000-4000-8000-000000000007",
      "status": "active",
      "planned_hours": 0,
      "validated_hours": 0,
      "progress_percent": 0,
      "last_activity_at": null,
      "inactive_days": 0,
      "alerts": [
        {
          "code": "inactive_7_days"
        }
      ],
      "baseline_linked": false,
      "confirmed_sessions": 0,
      "open_mentorship_cases": 0
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Turma não encontrada. |
| 409 | Oferta da turma inconsistente. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-025"></a>

## `GET /classes/{class_id}/eligible-students`

Eligible Students. Fonte: [api/app/classrooms.py:311](../../api/app/classrooms.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou instrutor designado com participação ativa teacher/coordinator/admin no programa e vínculo contextual docente ativo quando existente. Monitor isoladamente não autoriza.

**Comportamento:** Busca candidatos com matrícula ativa no mesmo programa/curso e sem inclusão ativa na turma. Turma closed recusa consulta; paginação por next_offset e aviso de ocupação.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `q` | query | não | string | default=""; maxLength=100 |
| `offset` | query | não | integer | default=0; minimum=0; maximum=100000 |
| `limit` | query | não | integer | default=20; minimum=1; maximum=50 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/eligible-students" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [EligibleStudentPage](SCHEMAS.md#schema-EligibleStudentPage) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "students": [
    {
      "user_id": "00000000-0000-4000-8000-000000000004",
      "name": "Pessoa Sintética QA"
    }
  ],
  "next_offset": null,
  "occupancy": 0,
  "capacity_reference": 30,
  "capacity_warning": false
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Turma não encontrada. |
| 409 | Expressão: f'Esta turma está encerrada e não pode receber {member_type}.' |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-026"></a>

## `GET /classes/{class_id}/evidence-imports/{import_id}`

Get Import. Fonte: [api/app/evidence.py:311](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Consulta importação e IDs das evidências somente na turma da rota.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `import_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/evidence-imports/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [ImportResponse](SCHEMAS.md#schema-ImportResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Consulta da mesma importação sintética criada: source_type whatsapp_export, status pending_review e evidências pendentes de revisão humana. A leitura não realiza integração externa nem muda o status.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "source_type": "whatsapp_export",
  "status": "pending_review",
  "retention_until": "2030-10-01T12:00:00Z",
  "source_digest": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "evidence_ids": [
    "00000000-0000-4000-8000-000000000010"
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Importação não encontrada. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-027"></a>

## `GET /classes/{class_id}/exceptions`

Exceptions. Fonte: [api/app/evidence.py:333](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; equipe autorizada da turma ou aluno com matrícula e vínculos ativos e linhagem consistente.

**Comportamento:** Equipe vê pendências da turma; aluno ativo vê apenas suas próprias evidências pendentes.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/exceptions" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. A visibilidade depende do vínculo; um item ainda sem pessoa associada pode ter user_id null e ser visível somente à equipe.

```json
{
  "exceptions": [
    {
      "code": "evidence_needs_review",
      "user_id": "00000000-0000-4000-8000-000000000004",
      "evidence_id": "00000000-0000-4000-8000-000000000010"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Turma não autorizada. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-028"></a>

## `GET /classes/{class_id}/journey-activity`

Export Activity. Fonte: [api/app/journey_export.py:137](../../api/app/journey_export.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Exporta telemetria de contas dos participantes ativos; atribuicao_turma permanece null. Consumidor deve deduplicar event_id entre turmas. Janela since/until exige fuso; limite até 500; segredo de pseudonimização é obrigatório.

**Flags/gates:** `JOURNEY_TRACEABILITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `limit` | query | não | integer | default=100; minimum=1; maximum=500 |
| `offset` | query | não | integer | default=0; minimum=0 |
| `since` | query | não | string (date-time) / null | — |
| `until` | query | não | string (date-time) / null | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/journey-activity" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige JOURNEY_TRACEABILITY_ENABLED=true e SHEETS_PSEUDONYM_SECRET com pelo menos 32 caracteres; flag desligada retorna 404: Exportação de rastreio ainda não habilitada. Somente projeção analítica; null preserva resultados desconhecidos. O consumidor deduplica por event_id entre turmas; telemetria de conta não atribui atividade acadêmica à turma.

```json
{
  "contract": "tds-activity-v1",
  "total": 1,
  "offset": 0,
  "limit": 100,
  "items": [
    {
      "event_id": "00000000-0000-4000-8000-000000000018",
      "pessoa_id": "pseudonimo-sintetico-exemplo",
      "evento": "page_viewed",
      "alvo_tipo": "page_id",
      "alvo_id": "home",
      "ocorreu_em": "2026-10-13T12:00:00Z",
      "segundos_tela": null,
      "escopo": "conta_autenticada",
      "atribuicao_turma": null
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Exportação de rastreio ainda não habilitada. |
| 404 | Turma não encontrada. |
| 422 | Janela de atividade exige fuso horário. |
| 422 | Janela de atividade inválida. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Identificação analítica não configurada. |

<a id="operacao-029"></a>

## `GET /classes/{class_id}/journey-export`

Export Journey. Fonte: [api/app/journey_export.py:43](../../api/app/journey_export.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Exporta projeção tds-journey-v1 para BI usando pseudônimo e vínculos confirmados. Pendências/inconsistências são explícitas; resultados não comprovados permanecem null. Exige segredo de pseudonimização configurado; certificados candidatos não entram na exportação.

**Flags/gates:** `JOURNEY_TRACEABILITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `limit` | query | não | integer | default=100; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/journey-export" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige JOURNEY_TRACEABILITY_ENABLED=true e SHEETS_PSEUDONYM_SECRET com pelo menos 32 caracteres; flag desligada retorna 404: Exportação de rastreio ainda não habilitada. Somente projeção analítica; null preserva resultados desconhecidos. items exige baseline reconciliada à inscrição fabric:tds-inscription-v1; demais participantes aparecem em pending.

```json
{
  "contract": "tds-journey-v1",
  "generated_at": "2026-10-13T12:00:00Z",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "total": 1,
  "offset": 0,
  "limit": 100,
  "items": [
    {
      "registro_id": "inscricao-exemplo-001",
      "pessoa_id": "pseudonimo-sintetico-exemplo",
      "turma_id": "00000000-0000-4000-8000-000000000003",
      "programa_id": "00000000-0000-4000-8000-000000000002",
      "curso_id": "curso-exemplo",
      "curso": "Curso Exemplo",
      "curso_versao_id": "00000000-0000-4000-8000-000000000008",
      "matricula_contextual_id": "00000000-0000-4000-8000-000000000017",
      "status_baseline": "Vínculo conferido",
      "vinculo_revisao": 1,
      "vinculo_conferido_em": "2026-10-13T12:00:00Z",
      "carga_horaria_prevista": 80.0,
      "horas_estudo_validadas": 1.0,
      "progresso_estudo_percentual": 1.25,
      "frequencia_percentual": null,
      "concluiu_frequencia_flag": null,
      "certificado_flag": null,
      "certificado_emitido_em": null,
      "certificado_cobertura": "api_class_references_only",
      "elegivel_mentoria": null,
      "status_convite_mentoria": null,
      "mentor_id": null,
      "status_mentoria": null,
      "data_ultima_interacao": "2026-10-13T12:00:00Z",
      "interacoes_qtd": 1,
      "plano_aplicacao_status": null,
      "aplicacao_iniciada_flag": null,
      "evidencia_validada_flag": null,
      "acompanhamento_30d": null,
      "acompanhamento_60d": null,
      "acompanhamento_90d": null,
      "encaminhamentos_qtd": null,
      "estagio_jornada": null,
      "data_proxima_acao": null,
      "status_qualidade": "confirmed_identity_partial_outcomes",
      "atualizado_em": "2026-10-13T12:00:00Z"
    }
  ],
  "pending": []
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Exportação de rastreio ainda não habilitada. |
| 404 | Turma não encontrada. |
| 409 | Encontros oficiais divergentes da turma. |
| 409 | Encontros oficiais não configurados de forma única. |
| 409 | Política inconsistente ou divergente da edição. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Identificação analítica não configurada. |
| 503 | Oferta sem política institucional configurada. |

<a id="operacao-030"></a>

## `GET /classes/{class_id}/learning-context`

Own Context. Fonte: [api/app/learning_context.py:91](../../api/app/learning_context.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Exige matrícula própria, vínculos ativos e linhagem contextual persistida; papel global não substitui matrícula.

**Comportamento:** Resolve contrato cohort-enrollment-v2 com edição published/archived fixada e progresso canônico. Contexto ausente/inconsistente exige reconciliação e retorna 409.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/learning-context" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [LearningContextSnapshot](SCHEMAS.md#schema-LearningContextSnapshot) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "context": {
    "user_id": "00000000-0000-4000-8000-000000000004",
    "organization_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "cohort_id": "00000000-0000-4000-8000-000000000003",
    "membership_id": "00000000-0000-4000-8000-000000000001",
    "role": "student",
    "course_id": "curso-qa",
    "course_version_id": "00000000-0000-4000-8000-000000000008",
    "enrollment_id": "00000000-0000-4000-8000-000000000007",
    "legacy_enrollment_id": "00000000-0000-4000-8000-000000000007",
    "permissions": [
      "qa-example"
    ]
  },
  "progress": {
    "user_id": "00000000-0000-4000-8000-000000000004",
    "name": "Pessoa Sintética QA",
    "enrollment_id": "00000000-0000-4000-8000-000000000007",
    "status": "active",
    "planned_hours": 0,
    "validated_hours": 0,
    "progress_percent": 0,
    "last_activity_at": null,
    "inactive_days": 0,
    "alerts": [
      {
        "code": "inactive_7_days"
      }
    ],
    "baseline_linked": false,
    "confirmed_sessions": 0,
    "open_mentorship_cases": 0
  },
  "resolved_at": "2026-10-01T12:00:00Z",
  "contract_version": "cohort-enrollment-v2"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Contexto de aprendizagem não habilitado neste ambiente. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-031"></a>

## `GET /classes/{class_id}/mentorship-cases`

List Cases. Fonte: [api/app/student_followup.py:247](../../api/app/student_followup.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Consulta casos de mentoria associados à turma e matrícula ativa consistente; detalhe inclui histórico. Não concede presença, matrícula ou certificado.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `user_id` | query | não | string / null | minLength=1; maxLength=36 |
| `limit` | query | não | integer | default=50; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/mentorship-cases" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "items": [
    {
      "id": "00000000-0000-4000-8000-000000000013",
      "class_id": "00000000-0000-4000-8000-000000000003",
      "user_id": "00000000-0000-4000-8000-000000000004",
      "enrollment_id": "00000000-0000-4000-8000-000000000007",
      "objective": "Revisar o conteúdo da aula de exemplo.",
      "next_action": "Agendar revisão com a mentora.",
      "status": "open",
      "revision": 1,
      "opened_at": "2026-10-13T12:00:00Z",
      "updated_at": "2026-10-13T12:00:00Z",
      "closed_at": null,
      "mentor_id": "00000000-0000-4000-8000-000000000005",
      "mentor_name": "Instrutora Exemplo"
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 403 | Vínculo ativo e consistente do estudante obrigatório. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-032"></a>

## `GET /classes/{class_id}/mentorship-cases/{case_id}`

Get Case. Fonte: [api/app/student_followup.py:281](../../api/app/student_followup.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Consulta casos de mentoria associados à turma e matrícula ativa consistente; detalhe inclui histórico. Não concede presença, matrícula ou certificado.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `case_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/mentorship-cases/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "id": "00000000-0000-4000-8000-000000000013",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "user_id": "00000000-0000-4000-8000-000000000004",
  "enrollment_id": "00000000-0000-4000-8000-000000000007",
  "objective": "Revisar o conteúdo da aula de exemplo.",
  "next_action": "Agendar revisão com a mentora.",
  "status": "open",
  "revision": 1,
  "opened_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-13T12:00:00Z",
  "closed_at": null,
  "mentor_id": "00000000-0000-4000-8000-000000000005",
  "mentor_name": "Instrutora Exemplo",
  "history": [
    {
      "revision": 1,
      "actor_user_id": "00000000-0000-4000-8000-000000000005",
      "actor_role": "teacher",
      "reason": "Acompanhamento solicitado.",
      "occurred_at": "2026-10-13T12:00:00Z",
      "snapshot": {
        "id": "00000000-0000-4000-8000-000000000013",
        "class_id": "00000000-0000-4000-8000-000000000003",
        "user_id": "00000000-0000-4000-8000-000000000004",
        "enrollment_id": "00000000-0000-4000-8000-000000000007",
        "objective": "Revisar o conteúdo da aula de exemplo.",
        "next_action": "Agendar revisão com a mentora.",
        "status": "open",
        "revision": 1,
        "opened_at": "2026-10-13T12:00:00Z",
        "updated_at": "2026-10-13T12:00:00Z",
        "closed_at": null,
        "mentor_id": "00000000-0000-4000-8000-000000000005",
        "mentor_name": "Instrutora Exemplo"
      }
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 403 | Vínculo ativo e consistente do estudante obrigatório. |
| 404 | Caso não encontrado. |
| 404 | Turma não encontrada. |
| 409 | Matrícula alterada; associação histórica preservada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-033"></a>

## `GET /classes/{class_id}/monitor-exceptions`

Monitor Exceptions. Fonte: [api/app/classrooms.py:637](../../api/app/classrooms.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Retorna sinais acionáveis de acompanhamento da turma com escopo reduzido; não concede a visão pedagógica completa de tentativas/gabaritos.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/monitor-exceptions" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [MonitorExceptionsResponse](SCHEMAS.md#schema-MonitorExceptionsResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "generated_at": "2026-10-01T12:00:00Z",
  "total_students": 0,
  "attention_students": 0,
  "students": [
    {
      "user_id": "00000000-0000-4000-8000-000000000004",
      "name": "Pessoa Sintética QA",
      "alerts": [
        {
          "code": "inactive_7_days"
        }
      ]
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Turma não encontrada. |
| 409 | Oferta da turma inconsistente. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-034"></a>

## `GET /classes/{class_id}/reports/{report_id}`

Get Report. Fonte: [api/app/evidence.py:365](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Consulta relatório congelado de encontro; report_id de outra turma retorna 404.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `report_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/reports/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [ReportResponse](SCHEMAS.md#schema-ReportResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Retorna o relatório persistido pelo fechamento, preservando resumo e report_digest. A fixture possui participante confirmado, sem evidências/presenças pendentes, e external_integrations disabled.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "session_id": "00000000-0000-4000-8000-000000000009",
  "generated_at": "2026-10-13T12:00:00Z",
  "report_digest": "b997d3e91db08f65ceb64a9e9638ea5feb8692686003f65217f920f156c1f310",
  "summary": {
    "checkin_count": 1,
    "pending_evidence_ids": [],
    "pending_explicitly_confirmed": false,
    "presence": {
      "total": 1,
      "counts": {
        "pending": 0,
        "suggested_present": 0,
        "confirmed_present": 1,
        "justified_absence": 0,
        "absent": 0
      },
      "pending_count": 0
    },
    "external_integrations": "disabled"
  }
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Relatório não encontrado. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-035"></a>

## `GET /classes/{class_id}/sessions`

List Sessions. Fonte: [api/app/evidence.py:137](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; equipe autorizada da turma ou aluno com matrícula e vínculos ativos e linhagem consistente.

**Comportamento:** Consulta encontros da turma sem expor token/código secreto. /open retorna o encontro aberto mais recente ou 404.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `status` | query | não | enum ["open", "closed"] / null | — |
| `limit` | query | não | integer | default=50; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/sessions" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [SessionPage](SCHEMAS.md#schema-SessionPage) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Página da fixture recém-criada antes de rotação/fechamento: status open e token_version 1. Sem parâmetros de paginação a rota usa limit=50/offset=0. A projeção pública de sessão omite token e código de check-in.

```json
{
  "sessions": [
    {
      "id": "00000000-0000-4000-8000-000000000009",
      "class_id": "00000000-0000-4000-8000-000000000003",
      "starts_at": "2026-10-13T12:00:00Z",
      "ends_at": "2026-10-13T13:00:00Z",
      "status": "open",
      "token_expires_at": "2026-10-13T12:10:00Z",
      "token_version": 1
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Vínculo com a turma não autorizado. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-036"></a>

## `GET /classes/{class_id}/sessions/open`

Open Session. Fonte: [api/app/evidence.py:170](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; equipe autorizada da turma ou aluno com matrícula e vínculos ativos e linhagem consistente.

**Comportamento:** Consulta encontros da turma sem expor token/código secreto. /open retorna o encontro aberto mais recente ou 404.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/sessions/open" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [SessionView](SCHEMAS.md#schema-SessionView) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Encontro open mais recente da turma, nesta fixture recém-criada. A projeção pública omite token/código; sem encontro aberto autorizado a rota retorna 404.

```json
{
  "id": "00000000-0000-4000-8000-000000000009",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "starts_at": "2026-10-13T12:00:00Z",
  "ends_at": "2026-10-13T13:00:00Z",
  "status": "open",
  "token_expires_at": "2026-10-13T12:10:00Z",
  "token_version": 1
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Vínculo com a turma não autorizado. |
| 404 | Sessão aberta não encontrada. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-037"></a>

## `GET /classes/{class_id}/sessions/{session_id}`

Get Session. Fonte: [api/app/evidence.py:188](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; equipe autorizada da turma ou aluno com matrícula e vínculos ativos e linhagem consistente.

**Comportamento:** Consulta encontros da turma sem expor token/código secreto. /open retorna o encontro aberto mais recente ou 404.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `session_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/sessions/00000000-0000-4000-8000-000000000009" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [SessionView](SCHEMAS.md#schema-SessionView) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Detalhe da fixture recém-criada antes de rotação/fechamento, com o mesmo ID do parâmetro de caminho. A projeção pública omite token e código de check-in; leitura não renova a expiração.

```json
{
  "id": "00000000-0000-4000-8000-000000000009",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "starts_at": "2026-10-13T12:00:00Z",
  "ends_at": "2026-10-13T13:00:00Z",
  "status": "open",
  "token_expires_at": "2026-10-13T12:10:00Z",
  "token_version": 1
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Vínculo com a turma não autorizado. |
| 404 | Sessão não encontrada. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-038"></a>

## `GET /classes/{class_id}/sessions/{session_id}/attendance/{user_id}`

Official History. Fonte: [api/app/presence.py:80](../../api/app/presence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo. Alvo precisa manter matrícula ativa.

**Comportamento:** Lista histórico imutável de decisões oficiais. can_decide só é verdadeiro para o instrutor designado com vínculo ativo e alvo diferente do próprio instrutor.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `session_id` | path | sim | string | — |
| `user_id` | path | sim | string | — |
| `limit` | query | não | integer | default=50; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/sessions/00000000-0000-4000-8000-000000000009/attendance/00000000-0000-4000-8000-000000000004" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "items": [
    {
      "id": "00000000-0000-4000-8000-000000000011",
      "original_session_id": "00000000-0000-4000-8000-000000000009",
      "makeup_session_id": null,
      "class_id": "00000000-0000-4000-8000-000000000003",
      "user_id": "00000000-0000-4000-8000-000000000004",
      "enrollment_id": "00000000-0000-4000-8000-000000000007",
      "revision": 1,
      "status": "VALID",
      "reason": "Presença conferida pelo instrutor.",
      "actor_user_id": "00000000-0000-4000-8000-000000000005",
      "decided_at": "2026-10-13T12:00:00Z"
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0,
  "can_decide": true
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 403 | Vínculo ativo obrigatório. |
| 404 | Sessão não encontrada. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-039"></a>

## `GET /classes/{class_id}/sessions/{session_id}/presence`

List Presence. Fonte: [api/app/presence.py:220](../../api/app/presence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Lista roster ativo e sugestão derivada de evidências. Check-in/atividade só sugerem presença; decisão humana é separada.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `session_id` | path | sim | string | — |
| `limit` | query | não | integer | default=50; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/sessions/00000000-0000-4000-8000-000000000009/presence" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "items": [
    {
      "user_id": "00000000-0000-4000-8000-000000000004",
      "user_name": "Pessoa Exemplo",
      "enrollment_id": "00000000-0000-4000-8000-000000000007",
      "status": "confirmed_present",
      "revision": 1,
      "checkin_count": 1,
      "checkout_count": 0,
      "activity_count": 0,
      "reason": "Presença conferida pelo instrutor.",
      "decided_at": "2026-10-13T12:00:00Z"
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0,
  "session_status": "open"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Sessão não encontrada. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-040"></a>

## `GET /classes/{class_id}/students/{owner_id}/assessment-attempts`

List Student Published Attempts. Fonte: [api/app/assessment_sync.py:697](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou instrutor designado com participação ativa teacher/coordinator/admin no programa e vínculo contextual docente ativo quando existente. Monitor isoladamente não autoriza.

**Comportamento:** Consulta tentativas editoriais contextuais do aluno na turma. Monitor não recebe a visão pedagógica de respostas/notas.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `owner_id` | path | sim | string | — |
| `limit` | query | não | integer | default=50; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/students/00000000-0000-4000-8000-000000000004/assessment-attempts" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentAttemptPage](SCHEMAS.md#schema-AssessmentAttemptPage) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "attempts": [
    {
      "course_id": "curso-qa",
      "origin": "practice",
      "topic": "Tema sintético",
      "mode": "quiz",
      "revision": 1,
      "current_index": 0,
      "remaining_seconds": 0,
      "completed": false,
      "score": 0,
      "updated_at": "2026-10-01T12:00:00Z",
      "attempt_id": "00000000-0000-4000-8000-000000000001"
    }
  ],
  "total": 1,
  "limit": 20,
  "offset": 0
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Atividades dinâmicas contextuais não habilitadas neste ambiente. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-041"></a>

## `GET /classes/{class_id}/students/{owner_id}/assessment-attempts/{attempt_id}`

Get Student Published Attempt. Fonte: [api/app/assessment_sync.py:717](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou instrutor designado com participação ativa teacher/coordinator/admin no programa e vínculo contextual docente ativo quando existente. Monitor isoladamente não autoriza.

**Comportamento:** Consulta tentativas editoriais contextuais do aluno na turma. Monitor não recebe a visão pedagógica de respostas/notas.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `owner_id` | path | sim | string | — |
| `attempt_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/students/00000000-0000-4000-8000-000000000004/assessment-attempts/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentAttemptResponse](SCHEMAS.md#schema-AssessmentAttemptResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "course_id": "curso-qa",
  "origin": "practice",
  "topic": "Tema sintético",
  "mode": "quiz",
  "revision": 1,
  "current_index": 0,
  "remaining_seconds": 0,
  "completed": false,
  "score": 0,
  "updated_at": "2026-10-01T12:00:00Z",
  "attempt_id": "00000000-0000-4000-8000-000000000001"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Atividades dinâmicas contextuais não habilitadas neste ambiente. |
| 404 | Tentativa contextual não encontrada. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-042"></a>

## `GET /classes/{class_id}/students/{owner_id}/assessment-attempts/{attempt_id}/content`

Get Student Published Attempt Content. Fonte: [api/app/assessment_sync.py:738](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou instrutor designado com participação ativa teacher/coordinator/admin no programa e vínculo contextual docente ativo quando existente. Monitor isoladamente não autoriza.

**Comportamento:** Consulta snapshot editorial imutável da tentativa contextual; equipe docente autorizada recebe gabarito somente após completed=true.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `owner_id` | path | sim | string | — |
| `attempt_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/students/00000000-0000-4000-8000-000000000004/assessment-attempts/00000000-0000-4000-8000-000000000001/content" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentContentResponse](SCHEMAS.md#schema-AssessmentContentResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "assessment_content_id": "00000000-0000-4000-8000-000000000001",
  "course_id": "curso-qa",
  "topic": "Tema sintético",
  "mode": "quiz",
  "title": "Curso Sintético QA",
  "duration_seconds": 0,
  "questions": [
    {
      "question": "Questão sintética?",
      "options": [
        "qa-example"
      ],
      "topic": "Tema sintético"
    }
  ],
  "answer_key": null,
  "created_at": "2026-10-01T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Atividades dinâmicas contextuais não habilitadas neste ambiente. |
| 404 | Tentativa contextual não encontrada. |
| 404 | Turma não encontrada. |
| 409 | Conteúdo contextual não pôde ser conferido. |
| 409 | Conteúdo contextual possui origem inválida. |
| 409 | Tentativa contextual sem conteúdo imutável. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-043"></a>

## `GET /classes/{class_id}/students/{user_id}/baseline`

Get Baseline. Fonte: [api/app/student_followup.py:159](../../api/app/student_followup.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo. Aluno alvo precisa ter matrícula ativa e consistente.

**Comportamento:** Consulta vínculo da baseline e histórico; vínculo ausente retorna baseline=null e history=[]. pessoa_id pseudônimo só é acrescentado quando rastreio e segredo analítico estão configurados.

**Flags/gates:** `JOURNEY_TRACEABILITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `user_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/students/00000000-0000-4000-8000-000000000004/baseline" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Sem baseline a resposta é {"baseline":null,"history":[]}. Com JOURNEY_TRACEABILITY_ENABLED e SHEETS_PSEUDONYM_SECRET válido, acrescenta pessoa_id pseudonimizado.

```json
{
  "baseline": {
    "id": "00000000-0000-4000-8000-000000000012",
    "class_id": "00000000-0000-4000-8000-000000000003",
    "user_id": "00000000-0000-4000-8000-000000000004",
    "enrollment_id": "00000000-0000-4000-8000-000000000007",
    "source": "forms:exemplo",
    "record_id": "baseline-exemplo-001",
    "baseline_date": "2026-10-13",
    "territory_id": "territorio-exemplo",
    "revision": 1,
    "reviewed_at": "2026-10-13T12:00:00Z",
    "reviewed_by": "00000000-0000-4000-8000-000000000005"
  },
  "history": [
    {
      "revision": 1,
      "actor_user_id": "00000000-0000-4000-8000-000000000005",
      "actor_role": "teacher",
      "reason": "Referência conferida no ambiente de exemplo.",
      "occurred_at": "2026-10-13T12:00:00Z",
      "snapshot": {
        "id": "00000000-0000-4000-8000-000000000012",
        "class_id": "00000000-0000-4000-8000-000000000003",
        "user_id": "00000000-0000-4000-8000-000000000004",
        "enrollment_id": "00000000-0000-4000-8000-000000000007",
        "source": "forms:exemplo",
        "record_id": "baseline-exemplo-001",
        "baseline_date": "2026-10-13",
        "territory_id": "territorio-exemplo",
        "revision": 1,
        "reviewed_at": "2026-10-13T12:00:00Z"
      }
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 403 | Vínculo ativo e consistente do estudante obrigatório. |
| 404 | Turma não encontrada. |
| 409 | Matrícula alterada; associação histórica preservada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-044"></a>

## `GET /classes/{class_id}/students/{user_id}/learning-context`

Observed Context. Fonte: [api/app/learning_context.py:98](../../api/app/learning_context.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo. Aluno alvo precisa ter matrícula contextual ativa e consistente.

**Comportamento:** Resolve o mesmo snapshot/progresso canônico usado pelo aluno; não cria matrícula fictícia para professor/monitor.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `user_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/students/00000000-0000-4000-8000-000000000004/learning-context" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [LearningContextSnapshot](SCHEMAS.md#schema-LearningContextSnapshot) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "context": {
    "user_id": "00000000-0000-4000-8000-000000000004",
    "organization_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "cohort_id": "00000000-0000-4000-8000-000000000003",
    "membership_id": "00000000-0000-4000-8000-000000000001",
    "role": "student",
    "course_id": "curso-qa",
    "course_version_id": "00000000-0000-4000-8000-000000000008",
    "enrollment_id": "00000000-0000-4000-8000-000000000007",
    "legacy_enrollment_id": "00000000-0000-4000-8000-000000000007",
    "permissions": [
      "qa-example"
    ]
  },
  "progress": {
    "user_id": "00000000-0000-4000-8000-000000000004",
    "name": "Pessoa Sintética QA",
    "enrollment_id": "00000000-0000-4000-8000-000000000007",
    "status": "active",
    "planned_hours": 0,
    "validated_hours": 0,
    "progress_percent": 0,
    "last_activity_at": null,
    "inactive_days": 0,
    "alerts": [
      {
        "code": "inactive_7_days"
      }
    ],
    "baseline_linked": false,
    "confirmed_sessions": 0,
    "open_mentorship_cases": 0
  },
  "resolved_at": "2026-10-01T12:00:00Z",
  "contract_version": "cohort-enrollment-v2"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Contexto de aprendizagem não habilitado neste ambiente. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-045"></a>

## `GET /classes/{class_id}/students/{user_id}/mentors`

List Mentors. Fonte: [api/app/student_followup.py:148](../../api/app/student_followup.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo. Aluno alvo precisa ter matrícula ativa e consistente.

**Comportamento:** Lista instrutor/monitores ativos da turma, excluindo o aluno alvo. Admin global sem atribuição contextual não é mentor automaticamente.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `user_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/students/00000000-0000-4000-8000-000000000004/mentors" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "mentors": [
    {
      "user_id": "00000000-0000-4000-8000-000000000005",
      "name": "Instrutora Exemplo"
    },
    {
      "user_id": "00000000-0000-4000-8000-000000000006",
      "name": "Monitor Exemplo"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 403 | Vínculo ativo e consistente do estudante obrigatório. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-046"></a>

## `GET /courses`

Courses. Fonte: [api/app/main.py:171](../../api/app/main.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer.

**Comportamento:** Catálogo legado de cursos ativos com a edição publicada mais recente, quando existente. LEARNING_CONTEXT_ENABLED e DYNAMIC_ACTIVITY_ENABLED juntos removem gabaritos da projeção pública; curso inexistente/inativo retorna 404.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/courses"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Somente Course.active=true. Conteúdo editorial preserva campos legados; campos de versão são adicionados quando há edição published. Gabaritos protegidos quando flags contextuais/dinâmicas estão ativas.

```json
{
  "courses": [
    {
      "sections": [
        {
          "id": "modulo-1",
          "title": "Introdução",
          "messages": [
            {
              "id": "mensagem-1",
              "type": "bot",
              "content": "Bem-vindo ao curso de exemplo.",
              "version_id": "d4e2d145-d35b-5d37-a62e-415008018a8d"
            }
          ],
          "version_id": "4ee7532d-fe21-5972-9720-2e3e863a53c4"
        }
      ],
      "id": "curso-exemplo",
      "title": "Curso Exemplo",
      "author": "Autoria Exemplo",
      "course_version_id": "00000000-0000-4000-8000-000000000008",
      "version_id": "00000000-0000-4000-8000-000000000008",
      "version_number": 1,
      "legacy_progress_compatible": false
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| — | Sem HTTPException literal identificada nesta operação. Falhas inesperadas seguem o guia. |

<a id="operacao-047"></a>

## `GET /courses/{course_id}`

Course. Fonte: [api/app/main.py:193](../../api/app/main.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer.

**Comportamento:** Catálogo legado de cursos ativos com a edição publicada mais recente, quando existente. LEARNING_CONTEXT_ENABLED e DYNAMIC_ACTIVITY_ENABLED juntos removem gabaritos da projeção pública; curso inexistente/inativo retorna 404.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | path | sim | string | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/courses/curso-qa"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Curso inexistente/inativo retorna 404. Os campos além de id/title/author provêm do snapshot editorial e podem variar entre cursos.

```json
{
  "sections": [
    {
      "id": "modulo-1",
      "title": "Introdução",
      "messages": [
        {
          "id": "mensagem-1",
          "type": "bot",
          "content": "Bem-vindo ao curso de exemplo.",
          "version_id": "d4e2d145-d35b-5d37-a62e-415008018a8d"
        }
      ],
      "version_id": "4ee7532d-fe21-5972-9720-2e3e863a53c4"
    }
  ],
  "id": "curso-exemplo",
  "title": "Curso Exemplo",
  "author": "Autoria Exemplo",
  "course_version_id": "00000000-0000-4000-8000-000000000008",
  "version_id": "00000000-0000-4000-8000-000000000008",
  "version_number": 1,
  "legacy_progress_compatible": false
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 404 | Curso não encontrado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-048"></a>

## `GET /creators/me/analytics`

Creator Analytics. Fonte: [api/app/media.py:549](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco.

**Comportamento:** Agrega sinais somente das mídias próprias: starts, participantes únicos, conclusões/follow-ups qualificados, saves e avaliações explícitas. Não efetua pagamento nem concede certificado.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/creators/me/analytics" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | array de [CreatorMediaAnalytics](SCHEMAS.md#schema-CreatorMediaAnalytics) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
[
  {
    "media_id": "00000000-0000-4000-8000-000000000001",
    "started": 0,
    "unique_participants": 0,
    "qualified_completions": 0,
    "followups": 0,
    "saves": 0,
    "ratings": 0,
    "average_rating": null
  }
]
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-049"></a>

## `GET /creators/me/media`

Creator Media. Fonte: [api/app/media.py:536](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco.

**Comportamento:** Lista mídias cujo creator_user_id é o titular, inclusive rascunhos e estados editoriais; não aceita escolher outro creator.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/creators/me/media" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [MediaPage](SCHEMAS.md#schema-MediaPage) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Lista mídias do creator autenticado, incluindo rascunhos. O exemplo preserva a fixture de criação: status draft, captions [], duração 1s e playback_url/published_at null; as respostas não contêm credenciais ou IDs do asset no provedor.

```json
{
  "media": [
    {
      "id": "00000000-0000-4000-8000-000000000001",
      "institution_id": "00000000-0000-4000-8000-000000000001",
      "program_id": "00000000-0000-4000-8000-000000000002",
      "course_id": "curso-exemplo",
      "module_id": "modulo-qa",
      "creator_user_id": "00000000-0000-4000-8000-000000000001",
      "title": "Curso Sintético QA",
      "description": "",
      "competency_id": "00000000-0000-4000-8000-000000000001",
      "provider": "youtube",
      "duration_seconds": 1,
      "thumbnail_url": null,
      "captions": [],
      "visibility": "public",
      "offline_policy": "forbidden",
      "status": "draft",
      "followup_activity_id": "00000000-0000-4000-8000-000000000001",
      "playback_url": null,
      "published_at": null
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-050"></a>

## `GET /creators/me/scores`

Own Scores. Fonte: [api/app/commercial.py:203](../../api/app/commercial.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco.

**Comportamento:** Consulta scores do próprio creator_user_id; não há autorização para escolher outro titular.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/creators/me/scores" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | array de [ScoreResponse](SCHEMAS.md#schema-ScoreResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Lista somente scores pertencentes ao creator autenticado. O snapshot deste exemplo corresponde à janela sintética sem sinais.

```json
[
  {
    "id": "00000000-0000-4000-8000-000000000001",
    "creator_user_id": "00000000-0000-4000-8000-000000000001",
    "media_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "rule_version": "creator-score-v2",
    "window_start": "2026-10-01T00:00:00Z",
    "window_end": "2026-10-02T00:00:00Z",
    "score_basis_points": 0,
    "calculation_snapshot": {
      "participants_started": 0,
      "qualified_completions": 0,
      "qualified_followups": 0,
      "saves": 0,
      "explicit_rating": {
        "weight_basis_points": 1500,
        "ratings": 0,
        "rating_sum": 0,
        "awarded_basis_points": 0
      },
      "operational_quality": false,
      "weights_basis_points": {
        "completion": 3500,
        "followup": 3500,
        "explicit_rating": 1500,
        "save": 1000,
        "operational": 500
      }
    },
    "created_at": "2026-10-13T12:00:00Z"
  }
]
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-051"></a>

## `GET /editor/context`

Editor Context. Fonte: [api/app/course_editor.py:353](../../api/app/course_editor.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou participação ativa teacher/creator/coordinator/admin no programa do curso.

**Comportamento:** Lista programas em que o titular pode editar e capacidades de criação/publicação; sem vínculo editorial a lista é vazia.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/editor/context" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "programs": [
    {
      "id": "00000000-0000-4000-8000-000000000002",
      "name": "Programa Exemplo",
      "role": "coordinator",
      "can_create": true,
      "can_publish": true
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-052"></a>

## `GET /editor/courses`

Editor Courses. Fonte: [api/app/course_editor.py:359](../../api/app/course_editor.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou participação ativa teacher/creator/coordinator/admin no programa do curso. Edições published/archived são visíveis; rascunhos/revisões são restritos ao autor ou coordinator/admin autorizado.

**Comportamento:** Consulta a versão visível mais recente de cada curso ofertado no program_id; vínculo editorial fora do programa retorna 403.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `program_id` | query | sim | string | minLength=1; maxLength=36 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/editor/courses?program_id=00000000-0000-4000-8000-000000000002" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Lista apenas versões editoriais visíveis no programa solicitado.

```json
{
  "courses": [
    {
      "sections": [
        {
          "id": "modulo-1",
          "title": "Introdução",
          "messages": [
            {
              "id": "mensagem-1",
              "type": "bot",
              "content": "Bem-vindo ao curso de exemplo.",
              "version_id": "d4e2d145-d35b-5d37-a62e-415008018a8d"
            }
          ],
          "version_id": "4ee7532d-fe21-5972-9720-2e3e863a53c4"
        }
      ],
      "id": "curso-exemplo",
      "title": "Curso Exemplo",
      "author": "Autoria Exemplo",
      "course_id": "curso-exemplo",
      "program_id": "00000000-0000-4000-8000-000000000002",
      "version_id": "00000000-0000-4000-8000-000000000008",
      "version_number": 1,
      "revision": 1,
      "status": "draft",
      "created_at": "2026-10-13T12:00:00Z",
      "updated_at": "2026-10-13T12:00:00Z",
      "can_edit": true,
      "can_submit": true,
      "can_publish": false,
      "can_archive": false,
      "can_fork": false
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Vínculo editorial não autorizado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-053"></a>

## `GET /editor/courses/{course_id}`

Editor Course. Fonte: [api/app/course_editor.py:372](../../api/app/course_editor.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou participação ativa teacher/creator/coordinator/admin no programa do curso. Edições published/archived são visíveis; rascunhos/revisões são restritos ao autor ou coordinator/admin autorizado.

**Comportamento:** Consulta edição visível selecionada por version_id ou a mais recente visível, com versões/capacidades. Edição fora do escopo retorna 404.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | path | sim | string | — |
| `version_id` | query | não | string / null | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/editor/courses/curso-qa" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "sections": [
    {
      "id": "modulo-1",
      "title": "Introdução",
      "messages": [
        {
          "id": "mensagem-1",
          "type": "bot",
          "content": "Bem-vindo ao curso de exemplo.",
          "version_id": "d4e2d145-d35b-5d37-a62e-415008018a8d"
        }
      ],
      "version_id": "4ee7532d-fe21-5972-9720-2e3e863a53c4"
    }
  ],
  "id": "curso-exemplo",
  "title": "Curso Exemplo",
  "author": "Autoria Exemplo",
  "course_id": "curso-exemplo",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "version_id": "00000000-0000-4000-8000-000000000008",
  "version_number": 1,
  "revision": 1,
  "status": "draft",
  "created_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-13T12:00:00Z",
  "can_edit": true,
  "can_submit": true,
  "can_publish": false,
  "can_archive": false,
  "can_fork": false,
  "versions": [
    {
      "version_id": "00000000-0000-4000-8000-000000000008",
      "version_number": 1,
      "status": "draft",
      "revision": 1
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Curso não encontrado. |
| 404 | Versão não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-054"></a>

## `GET /events`

List Events. Fonte: [api/app/events.py:273](../../api/app/events.py).

**Autenticação:** Bearer obrigatório; papel global: student.

**Permissão:** Token Bearer com papel global student; acesso somente aos dados do próprio titular.

**Comportamento:** Lista eventos do titular com filtro opcional de curso e paginação offset/limit; ordenação por occurred_at decrescente.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | query | não | string / null | minLength=1; maxLength=120 |
| `offset` | query | não | integer | default=0; minimum=0 |
| `limit` | query | não | integer | default=50; minimum=1; maximum=100 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/events" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [EventPage](SCHEMAS.md#schema-EventPage) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "events": [
    {
      "event_id": "00000000-0000-4000-8000-000000000001",
      "event_type": "lesson_started",
      "course_id": "curso-qa",
      "session_id": "00000000-0000-4000-8000-000000000009",
      "occurred_at": "2026-10-01T12:00:00Z",
      "active_seconds": null,
      "payload": {},
      "sync_status": "pending",
      "validated_seconds": 0
    }
  ],
  "offset": 0,
  "limit": 20
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-055"></a>

## `GET /health`

Health. Fonte: [api/app/main.py:136](../../api/app/main.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer.

**Comportamento:** Executa SELECT 1 no banco e retorna disponibilidade; falha de conexão não é ocultada.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/health"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exemplo de SELECT 1 bem-sucedido no banco; não declara prontidão de release.

```json
{
  "status": "ok",
  "database": "available"
}
```

### Status e erros

Status declarados no OpenAPI: 200. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| — | Sem HTTPException literal identificada nesta operação. Falhas inesperadas seguem o guia. |

<a id="operacao-056"></a>

## `GET /live`

Live. Fonte: [api/app/main.py:131](../../api/app/main.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer.

**Comportamento:** Verifica processo sem depender do PostgreSQL; status ok não comprova disponibilidade do banco.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/live"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Liveness do processo sem depender do banco.

```json
{
  "status": "ok"
}
```

### Status e erros

Status declarados no OpenAPI: 200. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| — | Sem HTTPException literal identificada nesta operação. Falhas inesperadas seguem o guia. |

<a id="operacao-057"></a>

## `GET /media`

Published Media. Fonte: [api/app/media.py:351](../../api/app/media.py).

**Autenticação:** Bearer opcional; visibilidade revalidada no servidor.

**Permissão:** Bearer opcional. public/unlisted são acessíveis sem login; institution exige participação ativa no programa da mídia; enrolled exige matrícula ativa no programa/curso. Token presente é validado normalmente, inclusive em mídia pública.

**Comportamento:** Lista somente mídias published visíveis ao solicitante. unlisted é omitida do catálogo, mesmo quando seu link direto é acessível; filtros de curso/módulo são opcionais.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | query | não | string / null | maxLength=120 |
| `module_id` | query | não | string / null | maxLength=120 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/media"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [MediaPage](SCHEMAS.md#schema-MediaPage) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Esta rota lista somente mídias published visíveis para o solicitante; não retorna draft/blocked/archived.

```json
{
  "media": [
    {
      "id": "00000000-0000-4000-8000-000000000001",
      "institution_id": "00000000-0000-4000-8000-000000000001",
      "program_id": "00000000-0000-4000-8000-000000000002",
      "course_id": "curso-exemplo",
      "module_id": "modulo-qa",
      "creator_user_id": "00000000-0000-4000-8000-000000000001",
      "title": "Curso Sintético QA",
      "description": "",
      "competency_id": "00000000-0000-4000-8000-000000000001",
      "provider": "youtube",
      "duration_seconds": 1,
      "thumbnail_url": null,
      "captions": [],
      "visibility": "public",
      "offline_policy": "forbidden",
      "status": "published",
      "followup_activity_id": "00000000-0000-4000-8000-000000000001",
      "playback_url": "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
      "published_at": "2026-10-13T12:00:00Z"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Bearer fornecido inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-058"></a>

## `GET /media/{media_id}`

Published Media Detail. Fonte: [api/app/media.py:374](../../api/app/media.py).

**Autenticação:** Bearer opcional; visibilidade revalidada no servidor.

**Permissão:** Bearer opcional. public/unlisted são acessíveis sem login; institution exige participação ativa no programa da mídia; enrolled exige matrícula ativa no programa/curso. Token presente é validado normalmente, inclusive em mídia pública.

**Comportamento:** Consulta mídia published autorizada. Estado não publicado ou falta de vínculo necessário retorna 404; detalhe direto de unlisted é permitido.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `media_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/media/00000000-0000-4000-8000-000000000001"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [MediaResponse](SCHEMAS.md#schema-MediaResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. O detalhe exige status published e visibilidade autorizada; estados editoriais não publicados recebem 404.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "institution_id": "00000000-0000-4000-8000-000000000001",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo",
  "module_id": "modulo-qa",
  "creator_user_id": "00000000-0000-4000-8000-000000000001",
  "title": "Curso Sintético QA",
  "description": "",
  "competency_id": "00000000-0000-4000-8000-000000000001",
  "provider": "youtube",
  "duration_seconds": 1,
  "thumbnail_url": null,
  "captions": [],
  "visibility": "public",
  "offline_policy": "forbidden",
  "status": "published",
  "followup_activity_id": "00000000-0000-4000-8000-000000000001",
  "playback_url": "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
  "published_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Bearer fornecido inválido ou expirado. |
| 404 | Mídia não encontrada. |
| 404 | Mídia publicada não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-059"></a>

## `GET /media/{media_id}/playback/{token}`

Resolve Media Playback. Fonte: [api/app/media.py:503](../../api/app/media.py).

**Autenticação:** Sem Bearer.

**Permissão:** Sem Bearer; exige token de playback vigente para a mídia da rota, emitido para usuário cuja autorização continua válida.

**Comportamento:** Revalida mídia publicada e vínculo do usuário vinculado ao token; redireciona 307 ao provedor. Token inválido/expirado retorna 401, acesso revogado 404, entrega indisponível 503.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `media_id` | path | sim | string | — |
| `token` | path | sim | string | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/media/00000000-0000-4000-8000-000000000001/playback/TOKEN_SINTETICO"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 307 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **307**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Resposta de redirecionamento, corpo vazio; cabeçalho Location aponta para URL do provedor configurado, por exemplo https://video.example.com/playback-sintetico. Exige grant válido, mídia publicada e autorização ainda ativa; URL demonstrativa não é um playback real.

Sem body JSON.

### Status e erros

Status declarados no OpenAPI: 307, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Autorização de playback inválida ou expirada. |
| 404 | Mídia não encontrada. |
| 404 | Mídia publicada não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Entrega da mídia não configurada. |

<a id="operacao-060"></a>

## `GET /media/{media_id}/rating`

Own Media Rating. Fonte: [api/app/media.py:440](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco.

**Comportamento:** Consulta apenas avaliação do titular; inexistente retorna 404. Não altera avaliação nem exige novo envio de evento.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `media_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/media/00000000-0000-4000-8000-000000000001/rating" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [MediaRatingResponse](SCHEMAS.md#schema-MediaRatingResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "media_id": "00000000-0000-4000-8000-000000000001",
  "rating": 0,
  "submitted_at": "2026-10-01T12:00:00Z",
  "updated_at": "2026-10-01T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Avaliação não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-061"></a>

## `GET /operations/classes`

Manageable Classes. Fonte: [api/app/class_lifecycle.py:621](../../api/app/class_lifecycle.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator ou coordinator. Papel global admin não substitui esse vínculo. Instrutor designado com participação teacher ativa pode apenas consultar suas turmas/readiness.

**Comportamento:** Lista até 250 turmas no escopo contextual, com readiness e capacidades do ator; omite histórico completo.

**Flags/gates:** `CLASS_LIFECYCLE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/operations/classes" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige CLASS_LIFECYCLE_ENABLED=true e escopo de programa autorizado. Com a flag desligada responde 404: Ciclo de turma indisponível.

```json
{
  "classes": [
    {
      "classroom": {
        "id": "00000000-0000-4000-8000-000000000003",
        "institution_id": "00000000-0000-4000-8000-000000000001",
        "program_id": "00000000-0000-4000-8000-000000000002",
        "course_id": "curso-exemplo",
        "course_version_id": "00000000-0000-4000-8000-000000000008",
        "teacher_id": "00000000-0000-4000-8000-000000000005",
        "monitor_ids": [
          "00000000-0000-4000-8000-000000000006"
        ],
        "name": "Turma Exemplo",
        "offer_municipality": "Município Exemplo",
        "offer_location": "Sala Exemplo",
        "start_date": "2026-11-01",
        "end_date": "2026-11-30",
        "status": "planned",
        "revision": 1
      },
      "capacity": {
        "limit": 30,
        "occupancy": 0,
        "remaining": 30,
        "over_capacity": false,
        "policy": "soft_alert",
        "warning": false,
        "exception": null
      },
      "readiness": {
        "activation_blockers": [],
        "can_activate": true,
        "can_close": false,
        "closure_blockers": [],
        "closure_warnings": {
          "open_sessions": 0,
          "pending_evidence": 0,
          "pending_makeup": 0,
          "pending_certificate_requests": 0
        },
        "closure_warnings_block_close": false,
        "close_open_session_policy": "BLOCK_CLOSE_WITH_OPEN_SESSION"
      },
      "capabilities": {
        "role": "coordinator",
        "can_prepare": true,
        "can_change_team": true,
        "can_activate": true,
        "can_close": false,
        "can_override_capacity": false
      }
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Ciclo de turma indisponível. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-062"></a>

## `GET /operations/classes/options`

Options. Fonte: [api/app/class_lifecycle.py:541](../../api/app/class_lifecycle.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator ou coordinator. Papel global admin não substitui esse vínculo.

**Comportamento:** Lista programas/ofertas para preparação de turmas no escopo do ator, com edições publicadas elegíveis.

**Flags/gates:** `CLASS_LIFECYCLE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/operations/classes/options" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige CLASS_LIFECYCLE_ENABLED=true e escopo de programa autorizado. Com a flag desligada responde 404: Ciclo de turma indisponível.

```json
{
  "options": [
    {
      "institution_id": "00000000-0000-4000-8000-000000000001",
      "program_id": "00000000-0000-4000-8000-000000000002",
      "program_name": "Programa Exemplo",
      "course_id": "curso-exemplo",
      "course_title": "Curso Exemplo",
      "course_version_id": "00000000-0000-4000-8000-000000000008",
      "version_number": 1,
      "role": "coordinator",
      "can_prepare": true,
      "can_activate": true,
      "can_close": true,
      "can_override_capacity": false
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Ciclo de turma indisponível. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-063"></a>

## `GET /operations/classes/team-candidates`

Team Candidates. Fonte: [api/app/class_lifecycle.py:584](../../api/app/class_lifecycle.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator ou coordinator. Papel global admin não substitui esse vínculo.

**Comportamento:** Lista até 250 candidatos teacher/monitor ativos do programa informado, com ID/nome/papel seguros para exibição.

**Flags/gates:** `CLASS_LIFECYCLE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `program_id` | query | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/operations/classes/team-candidates?program_id=00000000-0000-4000-8000-000000000002" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige CLASS_LIFECYCLE_ENABLED=true e escopo de programa autorizado. Com a flag desligada responde 404: Ciclo de turma indisponível.

```json
{
  "program_id": "00000000-0000-4000-8000-000000000002",
  "candidates": [
    {
      "user_id": "00000000-0000-4000-8000-000000000005",
      "display_name": "Instrutora Exemplo",
      "role": "teacher"
    },
    {
      "user_id": "00000000-0000-4000-8000-000000000006",
      "display_name": "Monitor Exemplo",
      "role": "monitor"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Ator não autorizado para este programa. |
| 404 | Ciclo de turma indisponível. |
| 404 | Programa não encontrado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-064"></a>

## `GET /operations/classes/{class_id}/readiness`

Readiness. Fonte: [api/app/class_lifecycle.py:975](../../api/app/class_lifecycle.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator ou coordinator. Papel global admin não substitui esse vínculo. Instrutor designado com participação teacher ativa pode apenas consultar suas turmas/readiness.

**Comportamento:** Consulta snapshot com revisão, bloqueios de ativação/fechamento, ocupação, capacidades e histórico. Um aviso de capacidade não concede override.

**Flags/gates:** `CLASS_LIFECYCLE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/operations/classes/00000000-0000-4000-8000-000000000003/readiness" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige CLASS_LIFECYCLE_ENABLED=true e escopo de programa autorizado. Com a flag desligada responde 404: Ciclo de turma indisponível.

```json
{
  "classroom": {
    "id": "00000000-0000-4000-8000-000000000003",
    "institution_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "course_id": "curso-exemplo",
    "course_version_id": "00000000-0000-4000-8000-000000000008",
    "teacher_id": "00000000-0000-4000-8000-000000000005",
    "monitor_ids": [
      "00000000-0000-4000-8000-000000000006"
    ],
    "name": "Turma Exemplo",
    "offer_municipality": "Município Exemplo",
    "offer_location": "Sala Exemplo",
    "start_date": "2026-11-01",
    "end_date": "2026-11-30",
    "status": "planned",
    "revision": 1
  },
  "capacity": {
    "limit": 30,
    "occupancy": 0,
    "remaining": 30,
    "over_capacity": false,
    "policy": "soft_alert",
    "warning": false,
    "exception": null
  },
  "readiness": {
    "activation_blockers": [],
    "can_activate": true,
    "can_close": false,
    "closure_blockers": [],
    "closure_warnings": {
      "open_sessions": 0,
      "pending_evidence": 0,
      "pending_makeup": 0,
      "pending_certificate_requests": 0
    },
    "closure_warnings_block_close": false,
    "close_open_session_policy": "BLOCK_CLOSE_WITH_OPEN_SESSION"
  },
  "capabilities": {
    "role": "coordinator",
    "can_prepare": true,
    "can_change_team": true,
    "can_activate": true,
    "can_close": false,
    "can_override_capacity": false
  },
  "history": [
    {
      "id": "00000000-0000-4000-8000-000000000015",
      "revision": 1,
      "action": "prepare",
      "actor_id": "00000000-0000-4000-8000-000000000014",
      "reason": "Preparação da turma de exemplo.",
      "occurred_at": "2026-10-13T12:00:00Z"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Ator não autorizado para esta turma. |
| 404 | Ciclo de turma indisponível. |
| 404 | Turma não encontrada. |
| 409 | Programa da turma inconsistente. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-065"></a>

## `GET /operations/scopes`

Scopes. Fonte: [api/app/operator_operations.py:152](../../api/app/operator_operations.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator, coordinator ou admin. Papel global admin sem vínculo de programa não autoriza.

**Comportamento:** Lista até 100 turmas dos programas autorizados que possuem edição fixada. Ausência de escopos retorna lista vazia.

**Flags/gates:** `OPERATOR_OPERATIONS_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/operations/scopes" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige OPERATOR_OPERATIONS_ENABLED=true e vínculo ativo autorizado no programa. Com a flag desligada responde 404: Operação indisponível.

```json
{
  "scopes": [
    {
      "institution_id": "00000000-0000-4000-8000-000000000001",
      "program_id": "00000000-0000-4000-8000-000000000002",
      "course_id": "curso-exemplo",
      "class_id": "00000000-0000-4000-8000-000000000003",
      "version_id": "00000000-0000-4000-8000-000000000008",
      "label": "Programa Exemplo / Turma Exemplo"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Operação indisponível. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-066"></a>

## `GET /public/courses`

Public Courses. Fonte: [api/app/public_api.py:102](../../api/app/public_api.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer.

**Comportamento:** Projeção pública somente de curso ativo com edição publicada; expõe metadados editoriais aprovados, omite campos nulos. Cache-Control: public, max-age=60, stale-while-revalidate=300; detalhe sem publicação retorna 404.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `limit` | query | não | integer | default=50; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0 |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/public/courses"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [PublicCourseCatalog](SCHEMAS.md#schema-PublicCourseCatalog) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "courses": [
    {
      "slug": "curso-qa",
      "title": "Curso Sintético QA",
      "status": "published",
      "published_version_label": "qa-example",
      "updated_at": "2026-10-01T12:00:00Z"
    }
  ],
  "offset": 0,
  "limit": 20,
  "total": 1
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-067"></a>

## `GET /public/courses/{slug}`

Public Course. Fonte: [api/app/public_api.py:129](../../api/app/public_api.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer.

**Comportamento:** Projeção pública somente de curso ativo com edição publicada; expõe metadados editoriais aprovados, omite campos nulos. Cache-Control: public, max-age=60, stale-while-revalidate=300; detalhe sem publicação retorna 404.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `slug` | path | sim | string | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/public/courses/curso-qa"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [PublicCourseProjection](SCHEMAS.md#schema-PublicCourseProjection) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "slug": "curso-qa",
  "title": "Curso Sintético QA",
  "status": "published",
  "published_version_label": "qa-example",
  "updated_at": "2026-10-01T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 404 | Curso não encontrado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-068"></a>

## `GET /support/config`

Support Config. Fonte: [api/app/support.py:21](../../api/app/support.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer nem identidade acadêmica. Qualquer cliente pode consultar; o pedido não escolhe configuração.

**Comportamento:** Projeta somente base_url HTTPS e website_token público do widget Chatwoot a partir da configuração opcional do servidor. Não expõe credenciais administrativas, JWT, CPF pepper ou segredo/namespace HMAC. Configuração ausente ou inválida falha de modo fechado com 503 genérico; respostas 200 e 503 usam Cache-Control: no-store e Pragma: no-cache. Não concede matrícula, progresso, frequência ou certificado.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/support/config"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [SupportWidgetConfig](SCHEMAS.md#schema-SupportWidgetConfig) |
| 503 | Configuração pública do suporte ausente ou inválida. | Sem schema JSON declarado. |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "base_url": "qa-example",
  "website_token": "qa-example"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 503. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 503 | Configuração do suporte indisponível. |

<a id="operacao-069"></a>

## `GET /support/identity`

Support Identity. Fonte: [api/app/support.py:40](../../api/app/support.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco.

**Comportamento:** Assina somente a identidade do titular para Chatwoot; não recebe identidade alvo nem expõe CPF/telefone. Retorna 503 se segredo/namespace do suporte não estão configurados; Cache-Control: no-store.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/support/identity" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige CHATWOOT_IDENTITY_SECRET e CHATWOOT_IDENTITY_NAMESPACE. O hash mostrado foi calculado apenas com segredo sintético e não autentica nenhum ambiente; resposta Cache-Control: no-store.

```json
{
  "identifier": "tds-exemplo:00000000-0000-4000-8000-000000000004",
  "identifier_hash": "86c8cab63067f9c6325631e2ae6a51ed70e9479a2ac03d71d26b7af5e48fb37d"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Identificação do suporte indisponível. |

<a id="operacao-070"></a>

## `GET /users/{user_id}/hours`

User Hours. Fonte: [api/app/hours.py:33](../../api/app/hours.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Titular, admin global ou instrutor/monitor atribuído a turma que contenha a matrícula ativa do alvo.

**Comportamento:** Agrega active_seconds e validated_seconds somente de study_activity da matrícula selecionada. Matrículas paralelas exigem program_id. Tempo medido não equivale a frequência nem às horas formais do certificado.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `user_id` | path | sim | string | — |
| `course_id` | query | sim | string | minLength=1; maxLength=120 |
| `program_id` | query | não | string / null | maxLength=36 |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/users/00000000-0000-4000-8000-000000000004/hours?course_id=curso-qa" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [HoursResponse](SCHEMAS.md#schema-HoursResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "user_id": "00000000-0000-4000-8000-000000000004",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-qa",
  "planned_hours": 0,
  "validated_hours": 0,
  "active_usage": 0
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Acesso não autorizado à carga horária. |
| 404 | Matrícula ativa não encontrada. |
| 409 | Informe program_id para selecionar a matrícula. |
| 409 | Oferta de curso inconsistente. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-071"></a>

## `GET /version`

Version. Fonte: [api/app/main.py:143](../../api/app/main.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer.

**Comportamento:** Retorna versão da API, revisão única do Alembic, ambiente, versão mínima do app e compatibility_verified. Schema indisponível ou múltiplas revisões retornam 503.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

### Exemplo de requisição

```bash
curl --request GET "${TDS_API_BASE}/version"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exemplo hipotético de deployment após migração; não é observação da produção atual. compatibility_verified depende de COMPATIBILITY_VERIFIED e não é calculado por esta rota. Falta de revisão Alembic única retorna 503.

```json
{
  "api_version": "0.1.0",
  "schema_version": "20261007_0030",
  "minimum_supported_app_version": "1.2.0+11",
  "environment": "production",
  "compatibility_verified": false
}
```

### Status e erros

Status declarados no OpenAPI: 200. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 503 | Schema version unavailable. |

<a id="operacao-072"></a>

## `PATCH /admin/media/{media_id}`

Patch Media. Fonte: [api/app/media.py:216](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global, coordinator ativo no programa ou creator ativo proprietário da mídia.

**Comportamento:** Edita somente draft; outros estados retornam 409. Valida provedor, HTTPS de thumbnail/legendas e rejeita hosts Drive/Google usados como entrega de mídia.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `media_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [MediaPatch](SCHEMAS.md#schema-MediaPatch). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request PATCH "${TDS_API_BASE}/admin/media/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [MediaResponse](SCHEMAS.md#schema-MediaResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Somente draft pode ser editado. Com patch vazio a fixture permanece inalterada; a duração válida de criação é preservada.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "institution_id": "00000000-0000-4000-8000-000000000001",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo",
  "module_id": "modulo-qa",
  "creator_user_id": "00000000-0000-4000-8000-000000000001",
  "title": "Curso Sintético QA",
  "description": "",
  "competency_id": "00000000-0000-4000-8000-000000000001",
  "provider": "youtube",
  "duration_seconds": 1,
  "thumbnail_url": null,
  "captions": [],
  "visibility": "public",
  "offline_policy": "forbidden",
  "status": "draft",
  "followup_activity_id": "00000000-0000-4000-8000-000000000001",
  "playback_url": null,
  "published_at": null
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Vínculo editorial não autorizado. |
| 404 | Mídia não encontrada. |
| 409 | Somente rascunho pode ser editado. |
| 422 | Expressão: str(exc) |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-073"></a>

## `PATCH /classes/{class_id}/mentorship-cases/{case_id}`

Patch Case. Fonte: [api/app/student_followup.py:313](../../api/app/student_followup.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Atualiza campos explícitos não nulos com expected_revision, motivo e idempotency_key; replay retorna snapshot da revisão original. Revalida mentor ativo; fechamento registra closed_at e reabertura o remove.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `case_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [CasePatch](SCHEMAS.md#schema-CasePatch). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request PATCH "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/mentorship-cases/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"expected_revision": 1, "idempotency_key": "qa-command-20261013-0001", "next_action": "Registrar acompanhamento sintético", "reason": "Validação com dados sintéticos"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. expected_revision precisa coincidir com a revisão atual; replay retorna o snapshot da revisão original.

```json
{
  "id": "00000000-0000-4000-8000-000000000013",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "user_id": "00000000-0000-4000-8000-000000000004",
  "enrollment_id": "00000000-0000-4000-8000-000000000007",
  "objective": "Revisar o conteúdo da aula de exemplo.",
  "next_action": "Agendar revisão com a mentora.",
  "status": "in_progress",
  "revision": 2,
  "opened_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-13T12:00:00Z",
  "closed_at": null,
  "mentor_id": "00000000-0000-4000-8000-000000000005",
  "mentor_name": "Instrutora Exemplo"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 403 | Vínculo ativo e consistente do estudante obrigatório. |
| 404 | Caso não encontrado. |
| 404 | Turma não encontrada. |
| 409 | Alteração concorrente ou referência conflitante; recarregue. |
| 409 | Caso alterado; recarregue a revisão. |
| 409 | Caso alterado; recarregue. |
| 409 | Idempotência divergente. |
| 409 | Matrícula alterada; associação histórica preservada. |
| 422 | Mentor deve ser outra pessoa da equipe ativa vinculada à turma. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-074"></a>

## `PATCH /courses/{course_id}`

Update Course. Fonte: [api/app/course_editor.py:411](../../api/app/course_editor.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou participação ativa teacher/creator/coordinator/admin no programa do curso. Somente autor do draft ou coordinator/admin autorizado.

**Comportamento:** Edita edição draft com version_id e expected_revision; publicada/arquivada é imutável. Conflito de revisão retorna 409; snapshot normaliza IDs/versões de componentes.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [DraftUpdate](SCHEMAS.md#schema-DraftUpdate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request PATCH "${TDS_API_BASE}/courses/curso-qa" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"author": "Equipe Sintética QA", "expected_revision": 1, "sections": [{"id": "modulo-qa", "messages": [{"content": "Conteúdo sintético para validar o contrato.", "id": "mensagem-qa", "type": "bot"}], "title": "Módulo sintético"}], "title": "Curso Sintético QA", "version_id": "00000000-0000-4000-8000-000000000008"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Somente draft autorizado; version_id e expected_revision controlam concorrência. IDs/version_id dos componentes pertencem ao snapshot do conteúdo.

```json
{
  "sections": [
    {
      "id": "modulo-1",
      "title": "Introdução",
      "messages": [
        {
          "id": "mensagem-1",
          "type": "bot",
          "content": "Bem-vindo ao curso de exemplo.",
          "version_id": "d4e2d145-d35b-5d37-a62e-415008018a8d"
        }
      ],
      "version_id": "4ee7532d-fe21-5972-9720-2e3e863a53c4"
    }
  ],
  "id": "curso-exemplo",
  "title": "Curso Exemplo",
  "author": "Autoria Exemplo",
  "course_id": "curso-exemplo",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "version_id": "00000000-0000-4000-8000-000000000008",
  "version_number": 1,
  "revision": 2,
  "status": "draft",
  "created_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-13T12:00:00Z",
  "can_edit": true,
  "can_submit": true,
  "can_publish": false,
  "can_archive": false,
  "can_fork": false
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Somente rascunhos autorizados podem ser editados. |
| 404 | Versão não encontrada. |
| 409 | Curso alterado por outra pessoa ou identificador já existente. Recarregue. |
| 409 | Versão alterada por outra pessoa. Recarregue antes de salvar. |
| 422 | Curso excede o limite de 2 MB. |
| 422 | IDs de conteúdos devem ser únicos. |
| 422 | IDs de materiais devem ser únicos no módulo. |
| 422 | IDs de módulos devem ser únicos e não vazios. |
| 422 | Inclua até 50 materiais por módulo. |
| 422 | Material inválido: use id, kind, title e URL pública HTTPS ou media_id. |
| 422 | Mensagem requer type e content textuais. |
| 422 | Mensagens do módulo inválidas. |
| 422 | Módulo inválido. |
| 422 | Opções de mensagem inválidas. |
| 422 | Título do módulo obrigatório. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 422 | sections deve ser uma lista. |

<a id="operacao-075"></a>

## `POST /admin/accounts`

Create Managed Account. Fonte: [api/app/organizations.py:239](../../api/app/organizations.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Cria conta e participação ativa no programa em uma única transação; atribui o papel global solicitado. Reutiliza validação de cadastro, incluindo convite de ativação quando exigido, embora este payload não exponha activation_token.

**Flags/gates:** `CPF_ACTIVATION_REQUIRED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [ManagedAccountCreate](SCHEMAS.md#schema-ManagedAccountCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/accounts" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"cpf": "12345678909", "name": "Pessoa Sintética QA", "password": "Apenas-exemplo-nao-utilizar-2026", "phone": "00000000000", "program_id": "00000000-0000-4000-8000-000000000002", "role": "student"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [ManagedAccountResponse](SCHEMAS.md#schema-ManagedAccountResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Conta e vínculo no programa são criados atomicamente; membership_status do novo vínculo é active. O papel depende do payload autorizado.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "name": "Pessoa Sintética QA",
  "role": "student",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "membership_status": "active"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Cadastro exige convite de ativação verificada. |
| 403 | Convite de ativação inválido ou expirado. |
| 404 | Expressão: detail |
| 409 | Expressão: detail |
| 409 | Usuário já cadastrado. |
| 422 | A senha deve ter entre 12 e 128 caracteres. |
| 422 | CPF inválido. |
| 422 | Nome inválido. |
| 422 | Telefone inválido. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-076"></a>

## `POST /admin/classes`

Create Classroom. Fonte: [api/app/classrooms.py:153](../../api/app/classrooms.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Cria turma para oferta e professor com vínculo teacher ativo; fixa edição publicada do curso e vínculo contextual docente. Com CLASS_LIFECYCLE_ENABLED, novas turmas devem iniciar em planned.

**Flags/gates:** `CLASS_LIFECYCLE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [ClassroomCreate](SCHEMAS.md#schema-ClassroomCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/classes" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"course_id": "curso-exemplo", "end_date": "2026-10-14", "name": "Pessoa Sintética QA", "program_id": "00000000-0000-4000-8000-000000000002", "start_date": "2026-10-13", "status": "planned", "teacher_id": "00000000-0000-4000-8000-000000000005"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [ClassroomResponse](SCHEMAS.md#schema-ClassroomResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético do modelo de resposta.

```json
{
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo",
  "teacher_id": "00000000-0000-4000-8000-000000000005",
  "name": "Pessoa Sintética QA",
  "start_date": "2026-10-13",
  "end_date": "2026-10-14",
  "status": "planned",
  "id": "00000000-0000-4000-8000-000000000001"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 409 | Curso não possui versão publicada. |
| 409 | Expressão: detail |
| 422 | Curso excede o limite de 2 MB. |
| 422 | Curso não está publicado para novas turmas. |
| 422 | Curso não é ofertado por este programa. |
| 422 | IDs de conteúdos devem ser únicos. |
| 422 | IDs de materiais devem ser únicos no módulo. |
| 422 | IDs de módulos devem ser únicos e não vazios. |
| 422 | Inclua até 50 materiais por módulo. |
| 422 | Material inválido: use id, kind, title e URL pública HTTPS ou media_id. |
| 422 | Mensagem requer type e content textuais. |
| 422 | Mensagens do módulo inválidas. |
| 422 | Módulo inválido. |
| 422 | Novas turmas devem iniciar em planned e ser ativadas pela coordenação. |
| 422 | Opções de mensagem inválidas. |
| 422 | Professor não possui vínculo ativo neste programa. |
| 422 | Título do módulo obrigatório. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 422 | sections deve ser uma lista. |

<a id="operacao-077"></a>

## `POST /admin/classes/{class_id}/monitors/{user_id}`

Add Monitor. Fonte: [api/app/classrooms.py:263](../../api/app/classrooms.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Adiciona monitor com vínculo monitor ativo no programa. Turma closed recusa; monitor existente retorna 409. Com CLASS_LIFECYCLE_ENABLED, mudança de equipe após planned usa o fluxo contextual de coordenação.

**Flags/gates:** `CLASS_LIFECYCLE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `user_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/classes/00000000-0000-4000-8000-000000000003/monitors/00000000-0000-4000-8000-000000000004" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **201**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "class_id": "00000000-0000-4000-8000-000000000003",
  "user_id": "00000000-0000-4000-8000-000000000006"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Turma não encontrada. |
| 409 | Equipe de turma iniciada deve ser alterada pelo fluxo contextual da coordenação. |
| 409 | Expressão: detail |
| 409 | Expressão: f'Esta turma está encerrada e não pode receber {member_type}.' |
| 409 | Monitor já está na turma. |
| 422 | Monitor não possui vínculo ativo neste programa. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-078"></a>

## `POST /admin/classes/{class_id}/sessions`

Create Session. Fonte: [api/app/evidence.py:114](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou instrutor designado com participação ativa teacher/coordinator/admin no programa e vínculo contextual docente ativo quando existente. Monitor isoladamente não autoriza.

**Comportamento:** Abre encontro somente em turma active. Gera token de check-in e código de seis dígitos; validade limitada a dez minutos ou ao fim do encontro.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [SessionCreate](SCHEMAS.md#schema-SessionCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/classes/00000000-0000-4000-8000-000000000003/sessions" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"ends_at": "2026-10-13T13:00:00Z", "starts_at": "2026-10-13T12:00:00Z"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [SessionResponse](SCHEMAS.md#schema-SessionResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Nova sessão exige turma active e retorna status open/token_version=1. Expiração é min(ends_at, agora+10min). Token/código são demonstrativos e não concedem acesso real.

```json
{
  "id": "00000000-0000-4000-8000-000000000009",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "starts_at": "2026-10-13T12:00:00Z",
  "ends_at": "2026-10-13T13:00:00Z",
  "status": "open",
  "token_expires_at": "2026-10-13T12:10:00Z",
  "token_version": 1,
  "checkin_token": "TOKEN_SINTETICO_DO_ENCONTRO",
  "checkin_code": "000000"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Turma não encontrada. |
| 409 | Somente turma ativa aceita nova sessão. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Não foi possível gerar o código do encontro. |

<a id="operacao-079"></a>

## `POST /admin/classes/{class_id}/students/{user_id}`

Add Student. Fonte: [api/app/classrooms.py:219](../../api/app/classrooms.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Adiciona aluno com matrícula legado ativa compatível; turma closed recusa inclusão e vínculo existente retorna 409. Materializa contexto da edição quando disponível; capacidade 30 é aviso, sem impedir inclusão.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `user_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/classes/00000000-0000-4000-8000-000000000003/students/00000000-0000-4000-8000-000000000004" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **201**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "class_id": "00000000-0000-4000-8000-000000000003",
  "user_id": "00000000-0000-4000-8000-000000000004",
  "status": "active",
  "occupancy": 1,
  "capacity_warning": false
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Turma não encontrada. |
| 409 | Estudante já está na turma. |
| 409 | Expressão: detail |
| 409 | Expressão: f'Esta turma está encerrada e não pode receber {member_type}.' |
| 409 | Matrícula contextual inconsistente; confira a edição da turma. |
| 422 | Estudante não possui matrícula ativa para esta turma. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-080"></a>

## `POST /admin/creator-scores/calculate`

Calculate Score. Fonte: [api/app/commercial.py:117](../../api/app/commercial.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou coordinator ativo no programa da mídia.

**Comportamento:** Calcula score por janela e versão de regra com sinais pedagógicos qualificados e avaliações explícitas. Mesma mídia/creator/regra/janela retorna 200; nova janela 201. Não executa pagamento.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [ScoreRequest](SCHEMAS.md#schema-ScoreRequest). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/creator-scores/calculate" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"media_id": "00000000-0000-4000-8000-000000000001", "window_end": "2026-10-02T00:00:00Z", "window_start": "2026-10-01T00:00:00Z"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [ScoreResponse](SCHEMAS.md#schema-ScoreResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Novo cálculo sempre grava rule_version=creator-score-v2 e o snapshot dos pesos/sinais. Exemplo de janela sem eventos/ratings: score zero com snapshot completo. Repetição da mesma mídia/creator/regra/janela retorna 200 e o cálculo existente.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "creator_user_id": "00000000-0000-4000-8000-000000000001",
  "media_id": "00000000-0000-4000-8000-000000000001",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "rule_version": "creator-score-v2",
  "window_start": "2026-10-01T00:00:00Z",
  "window_end": "2026-10-02T00:00:00Z",
  "score_basis_points": 0,
  "calculation_snapshot": {
    "participants_started": 0,
    "qualified_completions": 0,
    "qualified_followups": 0,
    "saves": 0,
    "explicit_rating": {
      "weight_basis_points": 1500,
      "ratings": 0,
      "rating_sum": 0,
      "awarded_basis_points": 0
    },
    "operational_quality": false,
    "weights_basis_points": {
      "completion": 3500,
      "followup": 3500,
      "explicit_rating": 1500,
      "save": 1000,
      "operational": 500
    }
  },
  "created_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Função não autorizada neste programa. |
| 404 | Mídia não encontrada. |
| 409 | Expressão: detail |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-081"></a>

## `POST /admin/enrollments`

Create Enrollment. Fonte: [api/app/organizations.py:276](../../api/app/organizations.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Cria matrícula legado para participante ativo e curso ofertado; duplicata retorna 409. Associa eventos study_activity anteriormente sem matrícula. Não cria automaticamente matrícula contextual de turma.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [EnrollmentCreate](SCHEMAS.md#schema-EnrollmentCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/enrollments" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"course_id": "curso-exemplo", "program_id": "00000000-0000-4000-8000-000000000002", "user_id": "00000000-0000-4000-8000-000000000004"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [EnrollmentResponse](SCHEMAS.md#schema-EnrollmentResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético do modelo de resposta.

```json
{
  "user_id": "00000000-0000-4000-8000-000000000004",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo",
  "id": "00000000-0000-4000-8000-000000000001",
  "status": "active"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 409 | Expressão: detail |
| 409 | Matrícula já cadastrada. |
| 422 | Curso não é ofertado por este programa. |
| 422 | Usuário não participa ativamente do programa. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-082"></a>

## `POST /admin/institutions`

Create Institution. Fonte: [api/app/organizations.py:115](../../api/app/organizations.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Cria instituição com nome único; duplicata retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [InstitutionCreate](SCHEMAS.md#schema-InstitutionCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/institutions" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"name": "Pessoa Sintética QA"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [InstitutionResponse](SCHEMAS.md#schema-InstitutionResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético do modelo de resposta.

```json
{
  "name": "Pessoa Sintética QA",
  "id": "00000000-0000-4000-8000-000000000001"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 409 | Expressão: detail |
| 409 | Instituição já cadastrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-083"></a>

## `POST /admin/ledger/simulate`

Simulate Ledger. Fonte: [api/app/commercial.py:216](../../api/app/commercial.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou finance ativo no programa.

**Comportamento:** Cria somente lançamento simulated; PAYMENT_ADAPTER deve ser disabled. idempotency_key idêntica retorna 200; nova simulação 201; payload divergente 409. Evento-fonte deve pertencer à mídia do score; não movimenta dinheiro.

**Flags/gates:** `COMMERCIAL_SIMULATION_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [LedgerCreate](SCHEMAS.md#schema-LedgerCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/ledger/simulate" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"amount_minor": 100, "creator_score_id": "00000000-0000-4000-8000-000000000001", "currency": "BRL", "entry_type": "accrual", "idempotency_key": "qa-command-20261013-0001", "source_event_id": "00000000-0000-4000-8000-000000000001"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [LedgerResponse](SCHEMAS.md#schema-LedgerResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Exige COMMERCIAL_SIMULATION_ENABLED=true, PAYMENT_ADAPTER=disabled, escopo financeiro autorizado e source_event_id da mídia do score. Exemplo de simulação; o evento-fonte da fixture pode estar fora da janela do score. Nunca representa pagamento/payout real. Novo lançamento tem status simulated e snapshot com mode simulated/payment_adapter disabled. Replay idêntico retorna 200; payload divergente na mesma chave retorna 409.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "institution_id": "00000000-0000-4000-8000-000000000001",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "creator_user_id": "00000000-0000-4000-8000-000000000001",
  "media_id": "00000000-0000-4000-8000-000000000001",
  "source_event_id": "00000000-0000-4000-8000-000000000001",
  "rule_version": "creator-score-v2",
  "entry_type": "accrual",
  "amount_minor": 100,
  "currency": "BRL",
  "status": "simulated",
  "idempotency_key": "qa-command-20261013-0001",
  "calculation_snapshot": {
    "creator_score_id": "00000000-0000-4000-8000-000000000001",
    "score_basis_points": 0,
    "mode": "simulated",
    "payment_adapter": "disabled"
  },
  "created_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Função não autorizada neste programa. |
| 404 | Creator Score não encontrado. |
| 404 | Simulação comercial desativada. |
| 409 | Chave de idempotência usada com payload divergente. |
| 409 | Expressão: detail |
| 422 | Evento-fonte não pertence à mídia do score. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Somente adapter disabled é permitido nesta fase. |

<a id="operacao-084"></a>

## `POST /admin/media`

Create Media. Fonte: [api/app/media.py:181](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou creator ativo no programa; creator só cria conteúdo próprio. Creator alvo sempre precisa de participação creator ativa.

**Comportamento:** Cria metadados de mídia draft e transição editorial. Valida linhagem institucional/oferta e IDs/URLs do provedor; não faz upload do vídeo nem publica automaticamente.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [MediaCreate](SCHEMAS.md#schema-MediaCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/media" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"competency_id": "00000000-0000-4000-8000-000000000001", "course_id": "curso-exemplo", "description": "", "duration_seconds": 1, "followup_activity_id": "00000000-0000-4000-8000-000000000001", "institution_id": "00000000-0000-4000-8000-000000000001", "module_id": "modulo-qa", "offline_policy": "forbidden", "program_id": "00000000-0000-4000-8000-000000000002", "provider": "youtube", "provider_asset_id": "dQw4w9WgXcQ", "rights_confirmed": false, "title": "Curso Sintético QA", "visibility": "public"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [MediaResponse](SCHEMAS.md#schema-MediaResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Criação sempre começa em draft, com playback_url/published_at null. captions contém objetos com language/label/format/url quando fornecidas; este request não possui legendas, então retorna [].

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "institution_id": "00000000-0000-4000-8000-000000000001",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo",
  "module_id": "modulo-qa",
  "creator_user_id": "00000000-0000-4000-8000-000000000001",
  "title": "Curso Sintético QA",
  "description": "",
  "competency_id": "00000000-0000-4000-8000-000000000001",
  "provider": "youtube",
  "duration_seconds": 1,
  "thumbnail_url": null,
  "captions": [],
  "visibility": "public",
  "offline_policy": "forbidden",
  "status": "draft",
  "followup_activity_id": "00000000-0000-4000-8000-000000000001",
  "playback_url": null,
  "published_at": null
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Creator só pode criar conteúdo próprio. |
| 403 | Vínculo editorial não autorizado. |
| 409 | Expressão: detail |
| 422 | Creator sem vínculo ativo no programa. |
| 422 | Curso não ofertado pelo programa. |
| 422 | Programa fora da instituição. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-085"></a>

## `POST /admin/media/{media_id}/archive`

Archive Media. Fonte: [api/app/media.py:303](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou coordinator ativo no programa da mídia; creator isoladamente não autoriza.

**Comportamento:** Arquiva mídia com motivo auditável; mídia já archived retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `media_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [EditorialTransitionRequest](SCHEMAS.md#schema-EditorialTransitionRequest). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/media/00000000-0000-4000-8000-000000000001/archive" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"reason": "Validação com dados sintéticos"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [MediaResponse](SCHEMAS.md#schema-MediaResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Exemplo de blocked → archived: conserva published_at histórico e playback_url null. Qualquer estado exceto archived pode ser arquivado; uma mídia nunca publicada pode conservar published_at null.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "institution_id": "00000000-0000-4000-8000-000000000001",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo",
  "module_id": "modulo-qa",
  "creator_user_id": "00000000-0000-4000-8000-000000000001",
  "title": "Curso Sintético QA",
  "description": "",
  "competency_id": "00000000-0000-4000-8000-000000000001",
  "provider": "youtube",
  "duration_seconds": 1,
  "thumbnail_url": null,
  "captions": [],
  "visibility": "public",
  "offline_policy": "forbidden",
  "status": "archived",
  "followup_activity_id": "00000000-0000-4000-8000-000000000001",
  "playback_url": null,
  "published_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Vínculo editorial não autorizado. |
| 404 | Mídia não encontrada. |
| 409 | Mídia já está arquivada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-086"></a>

## `POST /admin/media/{media_id}/block`

Block Media. Fonte: [api/app/media.py:276](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou coordinator ativo no programa da mídia; creator isoladamente não autoriza.

**Comportamento:** Bloqueia mídia published/processing com motivo auditável, retirando-a do consumo publicado; outro estado retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `media_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [EditorialTransitionRequest](SCHEMAS.md#schema-EditorialTransitionRequest). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/media/00000000-0000-4000-8000-000000000001/block" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"reason": "Validação com dados sintéticos"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [MediaResponse](SCHEMAS.md#schema-MediaResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Exemplo de published → blocked: conserva published_at histórico e remove playback_url da resposta. Também admite processing → blocked, quando published_at pode continuar null. Exige motivo e autoridade editorial.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "institution_id": "00000000-0000-4000-8000-000000000001",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo",
  "module_id": "modulo-qa",
  "creator_user_id": "00000000-0000-4000-8000-000000000001",
  "title": "Curso Sintético QA",
  "description": "",
  "competency_id": "00000000-0000-4000-8000-000000000001",
  "provider": "youtube",
  "duration_seconds": 1,
  "thumbnail_url": null,
  "captions": [],
  "visibility": "public",
  "offline_policy": "forbidden",
  "status": "blocked",
  "followup_activity_id": "00000000-0000-4000-8000-000000000001",
  "playback_url": null,
  "published_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Vínculo editorial não autorizado. |
| 404 | Mídia não encontrada. |
| 409 | Mídia não pode ser bloqueada neste estado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-087"></a>

## `POST /admin/media/{media_id}/publish`

Publish Media. Fonte: [api/app/media.py:246](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou coordinator ativo no programa da mídia; creator isoladamente não autoriza.

**Comportamento:** Publica draft/processing apenas com direitos confirmados; registra ator/horário/transição editorial. Não implanta provedor externo.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `media_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/media/00000000-0000-4000-8000-000000000001/publish" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [MediaResponse](SCHEMAS.md#schema-MediaResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Sucesso exige estado inicial draft/processing, autoridade editorial e rights_confirmed=true na fixture. Retorna status published e published_at não nulo; em visibilidade public/unlisted, playback_url vem do provedor. A criação ilustrada tem rights_confirmed=false e requer atualização explícita antes de publicar.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "institution_id": "00000000-0000-4000-8000-000000000001",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo",
  "module_id": "modulo-qa",
  "creator_user_id": "00000000-0000-4000-8000-000000000001",
  "title": "Curso Sintético QA",
  "description": "",
  "competency_id": "00000000-0000-4000-8000-000000000001",
  "provider": "youtube",
  "duration_seconds": 1,
  "thumbnail_url": null,
  "captions": [],
  "visibility": "public",
  "offline_policy": "forbidden",
  "status": "published",
  "followup_activity_id": "00000000-0000-4000-8000-000000000001",
  "playback_url": "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
  "published_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Vínculo editorial não autorizado. |
| 404 | Mídia não encontrada. |
| 409 | Mídia não está publicável. |
| 422 | Direitos da mídia não confirmados. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-088"></a>

## `POST /admin/programs`

Create Program. Fonte: [api/app/organizations.py:133](../../api/app/organizations.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Cria programa de instituição existente; nome duplicado na mesma instituição retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [ProgramCreate](SCHEMAS.md#schema-ProgramCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/programs" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"institution_id": "00000000-0000-4000-8000-000000000001", "name": "Pessoa Sintética QA"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [ProgramResponse](SCHEMAS.md#schema-ProgramResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético do modelo de resposta.

```json
{
  "institution_id": "00000000-0000-4000-8000-000000000001",
  "name": "Pessoa Sintética QA",
  "id": "00000000-0000-4000-8000-000000000001"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Instituição não encontrada. |
| 409 | Expressão: detail |
| 409 | Programa já cadastrado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-089"></a>

## `POST /admin/programs/{program_id}/courses/{course_id}`

Offer Course. Fonte: [api/app/organizations.py:166](../../api/app/organizations.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Vincula curso existente a programa existente; oferta já cadastrada retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `program_id` | path | sim | string | — |
| `course_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/programs/00000000-0000-4000-8000-000000000002/courses/curso-qa" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **201**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Expressão: detail |
| 409 | Curso já ofertado no programa. |
| 409 | Expressão: detail |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-090"></a>

## `POST /admin/programs/{program_id}/memberships`

Create Membership. Fonte: [api/app/organizations.py:206](../../api/app/organizations.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Cria participação ativa de conta existente no programa. Participação já existente retorna 409; papel do programa não altera automaticamente o papel global.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `program_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [MembershipCreate](SCHEMAS.md#schema-MembershipCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/admin/programs/00000000-0000-4000-8000-000000000002/memberships" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"role": "student", "user_id": "00000000-0000-4000-8000-000000000004"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [MembershipResponse](SCHEMAS.md#schema-MembershipResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético do modelo de resposta.

```json
{
  "user_id": "00000000-0000-4000-8000-000000000004",
  "role": "student",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "status": "active"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Expressão: detail |
| 409 | Expressão: detail |
| 409 | Participação já cadastrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-091"></a>

## `POST /auth/activation-invites`

Issue Activation Invite. Fonte: [api/app/auth.py:192](../../api/app/auth.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Emite convite de ativação vinculado ao CPF, válido por 1 a 168 horas. O segredo retornado deve ser entregue por canal privado.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [ActivationInviteRequest](SCHEMAS.md#schema-ActivationInviteRequest). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/auth/activation-invites" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"cpf": "12345678909", "expires_in_hours": 24}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **201**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Somente admin. O token retornado é secreto; o texto aqui não é um token real.

```json
{
  "activation_token": "TOKEN_DE_ATIVACAO_SINTETICO_NAO_UTILIZAVEL",
  "expires_in_hours": 24
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Acesso não autorizado para esta função. |
| 422 | CPF inválido. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-092"></a>

## `POST /auth/login`

Login. Fonte: [api/app/auth.py:119](../../api/app/auth.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer.

**Comportamento:** Autentica por CPF e senha, aplica limite compartilhado de tentativas inclusive nas falhas e emite access/refresh tokens. Conta sem ativação é recusada quando a ativação por CPF é exigida.

**Flags/gates:** `CPF_ACTIVATION_REQUIRED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

**Body JSON:** [LoginRequest](SCHEMAS.md#schema-LoginRequest). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/auth/login" \
  --header 'Content-Type: application/json' \
  --data '{"cpf": "12345678909", "password": "Apenas-exemplo-nao-utilizar-2026"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [TokenResponse](SCHEMAS.md#schema-TokenResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "access_token": "ACCESS_TOKEN_SINTETICO",
  "refresh_token": "REFRESH_TOKEN_SINTETICO",
  "token_type": "bearer",
  "expires_in": 900,
  "user": {
    "id": "00000000-0000-4000-8000-000000000001",
    "name": "Pessoa Sintética QA",
    "role": "student"
  }
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Expressão: detail |
| 403 | Conta aguardando ativação verificada. |
| 422 | CPF inválido. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 429 | Muitas tentativas. Tente novamente mais tarde. |
| 503 | Rate limit temporariamente indisponível. |

<a id="operacao-093"></a>

## `POST /auth/refresh`

Refresh. Fonte: [api/app/auth.py:139](../../api/app/auth.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer.

**Comportamento:** Exige refresh_token válido no corpo, revoga o token anterior e emite um novo par. Não reutilize o refresh_token após rotação.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

**Body JSON:** [RefreshRequest](SCHEMAS.md#schema-RefreshRequest). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/auth/refresh" \
  --header 'Content-Type: application/json' \
  --data '{"refresh_token": "REFRESH_TOKEN_SINTETICO"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [TokenResponse](SCHEMAS.md#schema-TokenResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "access_token": "ACCESS_TOKEN_SINTETICO",
  "refresh_token": "REFRESH_TOKEN_SINTETICO",
  "token_type": "bearer",
  "expires_in": 900,
  "user": {
    "id": "00000000-0000-4000-8000-000000000001",
    "name": "Pessoa Sintética QA",
    "role": "student"
  }
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Expressão: detail |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-094"></a>

## `POST /auth/register`

Register. Fonte: [api/app/auth.py:104](../../api/app/auth.py).

**Autenticação:** Sem Bearer.

**Permissão:** Público, sem token Bearer.

**Comportamento:** Cria conta student e emite tokens. CPF único, senha de 12 a 128 caracteres e telefone de 10 a 15 dígitos. Com CPF_ACTIVATION_REQUIRED, exige convite válido, não utilizado e associado ao CPF; não concede matrícula.

**Flags/gates:** `CPF_ACTIVATION_REQUIRED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

**Body JSON:** [RegisterRequest](SCHEMAS.md#schema-RegisterRequest). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/auth/register" \
  --header 'Content-Type: application/json' \
  --data '{"cpf": "12345678909", "name": "Pessoa Sintética QA", "password": "Apenas-exemplo-nao-utilizar-2026", "phone": "00000000000"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [TokenResponse](SCHEMAS.md#schema-TokenResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético do modelo de resposta.

```json
{
  "access_token": "ACCESS_TOKEN_SINTETICO",
  "refresh_token": "REFRESH_TOKEN_SINTETICO",
  "token_type": "bearer",
  "expires_in": 900,
  "user": {
    "id": "00000000-0000-4000-8000-000000000001",
    "name": "Pessoa Sintética QA",
    "role": "student"
  }
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 403 | Cadastro exige convite de ativação verificada. |
| 403 | Convite de ativação inválido ou expirado. |
| 409 | Usuário já cadastrado. |
| 422 | A senha deve ter entre 12 e 128 caracteres. |
| 422 | CPF inválido. |
| 422 | Nome inválido. |
| 422 | Telefone inválido. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-095"></a>

## `POST /certificate-requests`

Create. Fonte: [api/app/certificate_requests.py:162](../../api/app/certificate_requests.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Matrícula/participação próprias devem estar ativas, com edição published/archived autorizada e turma correspondente quando informada.

**Comportamento:** Cria pedido pending revisão 1; unicidade matrícula+edição torna retry no mesmo contexto idempotente (200). Pedido do mesmo par com outra turma retorna 409. Pedido pendente não equivale a certificado emitido.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [RequestCreate](SCHEMAS.md#schema-RequestCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/certificate-requests" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"course_version_id": "00000000-0000-4000-8000-000000000008", "enrollment_id": "00000000-0000-4000-8000-000000000007"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **201**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Pedido novo é pending. Replay da mesma matrícula/edição e contexto retorna 200; contexto de turma divergente retorna 409. Criação não emite certificado.

```json
{
  "id": "00000000-0000-4000-8000-000000000019",
  "enrollment_id": "00000000-0000-4000-8000-000000000007",
  "course_id": "curso-exemplo",
  "course_version_id": "00000000-0000-4000-8000-000000000008",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "holder_name": "Pessoa Exemplo",
  "course_title": "Curso Exemplo",
  "program_name": "Programa Exemplo",
  "institution_name": "Instituição Exemplo",
  "status": "pending",
  "revision": 1,
  "requested_at": "2026-10-13T12:00:00Z",
  "reviewed_at": null,
  "review_reason": null,
  "class_name": "Turma Exemplo",
  "eligibility": {
    "required_seconds": 288000,
    "validated_seconds": 0,
    "completed": false,
    "eligible": false
  }
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Matrícula não encontrada. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Pedido concorrente/inconsistente. Recarregue. |
| 409 | Pedido já existe para esta matrícula/edição com outro contexto de turma. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-096"></a>

## `POST /certificate-requests/{request_id}/candidate-checkpoints/{checkpoint_id}`

Complete Checkpoint. Fonte: [api/app/certificate_policy.py:248](../../api/app/certificate_policy.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Somente titular do pedido contextual ativo e não rejeitado.

**Comportamento:** Somente development. Recebe todas as respostas do checkpoint configurado, calcula conclusão/nota no backend e registra prova idempotente. Resposta divergente após conclusão retorna 409. Último checkpoint dispara geração sintética candidata, sem aguardar baseline/frequência/assinaturas posteriores.

**Flags/gates:** `CERTIFICATE_CANDIDATE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `request_id` | path | sim | string | — |
| `checkpoint_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [CheckpointComplete](SCHEMAS.md#schema-CheckpointComplete). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/certificate-requests/00000000-0000-4000-8000-000000000001/candidate-checkpoints/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"answers": {}}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **503**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Resposta padrão e em staging/produção. Contrato institucional candidato exige TUTOR_ENVIRONMENT=development e CERTIFICATE_CANDIDATE_ENABLED=true, autorização contextual e política imutável reconciliada. A conclusão de todos os checkpoints também depende do transporte candidato. Provas sintéticas não liberam emissão institucional final.

```json
{
  "detail": "Contrato candidato desativado neste ambiente."
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Matrícula não encontrada. |
| 404 | Pedido contextual não encontrado. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 409 | Checkpoint já concluído com outra resposta. |
| 409 | Encontro configurado divergente ou ausente. |
| 409 | Encontros oficiais divergentes da turma. |
| 409 | Encontros oficiais não configurados de forma única. |
| 409 | Fonte do checkpoint mudou. |
| 409 | Fonte editorial de checkpoint alterada ou ausente. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Política inconsistente ou divergente da edição. |
| 409 | Tipo de checkpoint sem representação validada. |
| 422 | Checkpoint não configurado ou representação não suportada. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Pedido diverge do contexto vigente. |
| 422 | Pedido rejeitado exige reenvio explícito pelo fluxo existente. |
| 422 | Todas as respostas configuradas são obrigatórias; sem completed/score do cliente. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Contrato candidato desativado neste ambiente. |
| 503 | Oferta sem política institucional configurada. |

<a id="operacao-097"></a>

## `POST /certificate-requests/{request_id}/candidate-evidence`

Record Evidence. Fonte: [api/app/certificate_policy.py:305](../../api/app/certificate_policy.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; titular do pedido ou admin global/coordinator/admin ativo no programa/instrutor teacher ativo designado à turma. Exige matrícula contextual do titular ativa e consistente. Registro exige revisor autorizado; attendance_sheet exige instrutor teacher ativo designado.

**Comportamento:** Somente development. Registra referência privada/digest e atestação humana, sem ler documento externo nem assinar PDF criptograficamente. attendance_exception fica pending_human_validation e não cria presença; ficha deve cobrir encontros configurados.

**Flags/gates:** `CERTIFICATE_CANDIDATE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `request_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [EvidenceCreate](SCHEMAS.md#schema-EvidenceCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/certificate-requests/00000000-0000-4000-8000-000000000001/candidate-evidence" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"document_digest": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "document_reference": "qa-example", "kind": "baseline", "origin": "qa-example", "reason": "Validação com dados sintéticos"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **503**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Resposta padrão e em staging/produção. Contrato institucional candidato exige TUTOR_ENVIRONMENT=development e CERTIFICATE_CANDIDATE_ENABLED=true, autorização contextual e política imutável reconciliada. A conclusão de todos os checkpoints também depende do transporte candidato. Provas sintéticas não liberam emissão institucional final.

```json
{
  "detail": "Contrato candidato desativado neste ambiente."
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Registro exige responsável autorizado; fichas exigem instrutor da turma. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Matrícula não encontrada. |
| 404 | Pedido contextual não encontrado. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Política inconsistente ou divergente da edição. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Ficha assinada precisa vincular os encontros configurados que cobre. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Pedido diverge do contexto vigente. |
| 422 | Pedido rejeitado exige reenvio explícito pelo fluxo existente. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Contrato candidato desativado neste ambiente. |
| 503 | Oferta sem política institucional configurada. |

<a id="operacao-098"></a>

## `POST /certificate-requests/{request_id}/candidate-lifecycle`

Transition. Fonte: [api/app/certificate_policy.py:350](../../api/app/certificate_policy.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; titular do pedido ou admin global/coordinator/admin ativo no programa/instrutor teacher ativo designado à turma. Exige matrícula contextual do titular ativa e consistente. submit: titular ou revisor; instructor_validate: instrutor teacher ativo designado; coordinator_sign: participação coordinator ativa, sem override admin global.

**Comportamento:** Somente development. Exige expected_state e ordem GENERATED→PENDING_INSTRUCTOR_VALIDATION→PENDING_COORDINATOR_SIGNATURE→VALID. Validação/assinatura exigem capacitação e fichas; assinatura exige referência documental privada/digest. Estado candidato não libera emissão institucional.

**Flags/gates:** `CERTIFICATE_CANDIDATE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `request_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [LifecycleAction](SCHEMAS.md#schema-LifecycleAction). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/certificate-requests/00000000-0000-4000-8000-000000000001/candidate-lifecycle" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"action": "submit", "expected_state": "GENERATED"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **503**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Resposta padrão e em staging/produção. Contrato institucional candidato exige TUTOR_ENVIRONMENT=development e CERTIFICATE_CANDIDATE_ENABLED=true, autorização contextual e política imutável reconciliada. A conclusão de todos os checkpoints também depende do transporte candidato. Provas sintéticas não liberam emissão institucional final.

```json
{
  "detail": "Contrato candidato desativado neste ambiente."
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Assinatura exige coordenação ativa autorizada. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Sem autorização para encaminhar validação. |
| 403 | Somente instrutor responsável valida fichas. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Matrícula não encontrada. |
| 404 | Pedido contextual não encontrado. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 409 | Certificado de trilha ainda não gerado. |
| 409 | Encontro configurado divergente ou ausente. |
| 409 | Encontros oficiais divergentes da turma. |
| 409 | Encontros oficiais não configurados de forma única. |
| 409 | Estado de validação alterado ou transição fora de ordem. |
| 409 | Fonte editorial de checkpoint alterada ou ausente. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Política inconsistente ou divergente da edição. |
| 409 | Tipo de checkpoint sem representação validada. |
| 409 | Transição concorrente; recarregue. |
| 422 | Capacitação e fichas assinadas pelo instrutor são obrigatórias. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Pedido diverge do contexto vigente. |
| 422 | Pedido rejeitado exige reenvio explícito pelo fluxo existente. |
| 422 | Referência/digest de assinatura documental da coordenação obrigatórios. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Contrato candidato desativado neste ambiente. |
| 503 | Oferta sem política institucional configurada. |

<a id="operacao-099"></a>

## `POST /certificate-requests/{request_id}/emission-candidate`

Emit Candidate. Fonte: [api/app/certificate_emission.py:163](../../api/app/certificate_emission.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Somente titular com matrícula contextual reconciliada, pedido não rejeitado e trilha completa da política; adaptador legado adicionalmente exige aprovação/elegibilidade e baseline.

**Comportamento:** Candidato sintético: reserva comando duravelmente antes do envio autenticado ao Worker isolado. development exige HTTP loopback; staging exige host HTTPS exato permitido. Produção retorna 503. Timeout/resposta perdida preserva estado indeterminado; não reenviar/resetar automaticamente.

**Flags/gates:** `CERTIFICATE_CANDIDATE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `request_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/certificate-requests/00000000-0000-4000-8000-000000000001/emission-candidate" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **503**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Resposta com candidato desativado ou em produção. Ativação de ensaio exige CERTIFICATE_CANDIDATE_ENABLED=true, ambiente development ou staging, CERTIFICATE_CANDIDATE_SECRET com pelo menos 32 caracteres e URL específica isolada. Development: HTTP loopback; staging: HTTPS em tutor-tds-cert-staging.tdsipex.workers.dev, sem transporte injetado. Pedido/vínculos, elegibilidade e provas continuam autorizados no backend. Referência candidata não integra carteira oficial.

```json
{
  "detail": "Candidato sintético desativado neste ambiente."
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Matrícula não encontrada. |
| 404 | Pedido não encontrado. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 409 | Contexto alterado após reserva; conferência manual necessária. |
| 409 | Contexto mudou durante transporte; referência não registrada. |
| 409 | Encontro configurado divergente ou ausente. |
| 409 | Encontros oficiais divergentes da turma. |
| 409 | Encontros oficiais não configurados de forma única. |
| 409 | Fonte editorial de checkpoint alterada ou ausente. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Não existe tentativa reservada para reconciliar. |
| 409 | Política inconsistente ou divergente da edição. |
| 409 | Referência concorrente em conflito. |
| 409 | Referência em conflito. |
| 409 | Reserva concorrente inconsistente. |
| 409 | Tipo de checkpoint sem representação validada. |
| 422 | Aprovação humana pendente no adaptador legado. |
| 422 | Aprovação/elegibilidade do adaptador legado pendente. |
| 422 | Baseline contextual obrigatório antes da emissão. |
| 422 | Candidato exige turma e matrícula contextual reconciliadas. |
| 422 | Contexto/evidência elegível não confirmado. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Linhagem contextual divergente do pedido. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Pedido rejeitado exige reenvio explícito pelo fluxo existente. |
| 422 | Responsável operacional revogado. |
| 422 | Todos os checkpoints configurados da trilha são obrigatórios. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Candidato em development exige transporte local isolado. |
| 503 | Candidato em staging exige endpoint HTTPS isolado de staging. |
| 503 | Candidato sintético desativado neste ambiente. |
| 503 | Oferta sem política institucional configurada. |
| 503 | Resultado indeterminado; reconciliar por consulta autenticada, sem reenviar emissão. |
| 503 | Transporte autenticado do candidato não configurado. |
| 503 | URL do transporte do candidato inválida. |

<a id="operacao-100"></a>

## `POST /certificate-requests/{request_id}/emit`

Emit Final. Fonte: [api/app/certificate_emission.py:155](../../api/app/certificate_emission.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Somente titular com contexto/elegibilidade exigidos pelo adaptador.

**Comportamento:** Emissão institucional final permanece bloqueada deliberadamente: após validações, retorna 503; nenhuma flag abre este gate ou autoriza publicação real de certificado.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `request_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/certificate-requests/00000000-0000-4000-8000-000000000001/emit" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **503**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Mesmo um pedido autorizado e elegível alcança este bloqueio permanente. Nenhuma flag ou payload abre a emissão institucional final; autenticação e _authorized podem falhar antes deste gate.

```json
{
  "detail": "Emissão final bloqueada pelo gate de ativação institucional: candidato sintético não homologa provedor instalado, assinatura institucional nem liberação em ambiente real."
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Matrícula não encontrada. |
| 404 | Pedido não encontrado. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 409 | Encontro configurado divergente ou ausente. |
| 409 | Encontros oficiais divergentes da turma. |
| 409 | Encontros oficiais não configurados de forma única. |
| 409 | Fonte editorial de checkpoint alterada ou ausente. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Política inconsistente ou divergente da edição. |
| 409 | Tipo de checkpoint sem representação validada. |
| 422 | Aprovação humana pendente no adaptador legado. |
| 422 | Aprovação/elegibilidade do adaptador legado pendente. |
| 422 | Baseline contextual obrigatório antes da emissão. |
| 422 | Candidato exige turma e matrícula contextual reconciliadas. |
| 422 | Contexto/evidência elegível não confirmado. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Linhagem contextual divergente do pedido. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Pedido rejeitado exige reenvio explícito pelo fluxo existente. |
| 422 | Responsável operacional revogado. |
| 422 | Todos os checkpoints configurados da trilha são obrigatórios. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Emissão final bloqueada pelo gate de ativação institucional: candidato sintético não homologa provedor instalado, assinatura institucional nem liberação em ambiente real. |
| 503 | Oferta sem política institucional configurada. |

<a id="operacao-101"></a>

## `POST /certificate-requests/{request_id}/reconcile-candidate`

Reconcile Candidate. Fonte: [api/app/certificate_emission.py:168](../../api/app/certificate_emission.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Somente titular com contexto candidato autorizado.

**Comportamento:** Reconcilia reserva existente exclusivamente por lookup no Worker; não inicia primeiro envio nem transforma ausência em autorização de reenvio. development/staging isolados; produção permanece bloqueada.

**Flags/gates:** `CERTIFICATE_CANDIDATE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `request_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/certificate-requests/00000000-0000-4000-8000-000000000001/reconcile-candidate" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **503**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Resposta com candidato desativado ou em produção. Ativação de ensaio exige CERTIFICATE_CANDIDATE_ENABLED=true, ambiente development ou staging, CERTIFICATE_CANDIDATE_SECRET com pelo menos 32 caracteres e URL específica isolada. Development: HTTP loopback; staging: HTTPS em tutor-tds-cert-staging.tdsipex.workers.dev, sem transporte injetado. Pedido/vínculos, elegibilidade e provas continuam autorizados no backend. Referência candidata não integra carteira oficial.

```json
{
  "detail": "Candidato sintético desativado neste ambiente."
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Matrícula não encontrada. |
| 404 | Pedido não encontrado. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 409 | Contexto alterado após reserva; conferência manual necessária. |
| 409 | Contexto mudou durante transporte; referência não registrada. |
| 409 | Encontro configurado divergente ou ausente. |
| 409 | Encontros oficiais divergentes da turma. |
| 409 | Encontros oficiais não configurados de forma única. |
| 409 | Fonte editorial de checkpoint alterada ou ausente. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Não existe tentativa reservada para reconciliar. |
| 409 | Política inconsistente ou divergente da edição. |
| 409 | Referência concorrente em conflito. |
| 409 | Referência em conflito. |
| 409 | Reserva concorrente inconsistente. |
| 409 | Tipo de checkpoint sem representação validada. |
| 422 | Aprovação humana pendente no adaptador legado. |
| 422 | Aprovação/elegibilidade do adaptador legado pendente. |
| 422 | Baseline contextual obrigatório antes da emissão. |
| 422 | Candidato exige turma e matrícula contextual reconciliadas. |
| 422 | Contexto/evidência elegível não confirmado. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Linhagem contextual divergente do pedido. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Pedido rejeitado exige reenvio explícito pelo fluxo existente. |
| 422 | Responsável operacional revogado. |
| 422 | Todos os checkpoints configurados da trilha são obrigatórios. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Candidato em development exige transporte local isolado. |
| 503 | Candidato em staging exige endpoint HTTPS isolado de staging. |
| 503 | Candidato sintético desativado neste ambiente. |
| 503 | Oferta sem política institucional configurada. |
| 503 | Resultado indeterminado; reconciliar por consulta autenticada, sem reenviar emissão. |
| 503 | Transporte autenticado do candidato não configurado. |
| 503 | URL do transporte do candidato inválida. |

<a id="operacao-102"></a>

## `POST /certificate-requests/{request_id}/resubmit`

Resubmit. Fonte: [api/app/certificate_requests.py:261](../../api/app/certificate_requests.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Somente titular do pedido.

**Comportamento:** Reapresenta pedido rejected na expected_revision para pending; revalida contexto e registra auditoria. Pedido aprovado/pendente ou revisão divergente retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `request_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [RevisionAction](SCHEMAS.md#schema-RevisionAction). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/certificate-requests/00000000-0000-4000-8000-000000000001/resubmit" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"expected_revision": 1}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exemplo após rejeição na revisão 2. Somente autor; deve fornecer expected_revision atual.

```json
{
  "id": "00000000-0000-4000-8000-000000000019",
  "enrollment_id": "00000000-0000-4000-8000-000000000007",
  "course_id": "curso-exemplo",
  "course_version_id": "00000000-0000-4000-8000-000000000008",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "holder_name": "Pessoa Exemplo",
  "course_title": "Curso Exemplo",
  "program_name": "Programa Exemplo",
  "institution_name": "Instituição Exemplo",
  "status": "pending",
  "revision": 3,
  "requested_at": "2026-10-13T12:00:00Z",
  "reviewed_at": null,
  "review_reason": null,
  "class_name": "Turma Exemplo",
  "eligibility": {
    "required_seconds": 288000,
    "validated_seconds": 0,
    "completed": false,
    "eligible": false
  }
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Somente o autor pode reapresentar o pedido. |
| 404 | Matrícula não encontrada. |
| 404 | Pedido não encontrado. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Pedido alterado por outra pessoa. Recarregue. |
| 409 | Somente pedido rejeitado nesta revisão pode ser reapresentado. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-103"></a>

## `POST /certificate-requests/{request_id}/review`

Review. Fonte: [api/app/certificate_requests.py:236](../../api/app/certificate_requests.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global, coordinator/admin com participação ativa no programa ou teacher ativo designado à turma do pedido. Pedido deve pertencer a outra pessoa; autoaprovação é recusada.

**Comportamento:** Aprova/rejeita somente pending na expected_revision. Aprovação revalida contexto, instituição e elegibilidade deterministicamente. Atualiza revisão e registra auditoria; conflito 409, inelegibilidade 422.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `request_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [app__certificate_requests__ReviewCreate](SCHEMAS.md#schema-app__certificate_requests__ReviewCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/certificate-requests/00000000-0000-4000-8000-000000000001/review" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"decision": "approve", "expected_revision": 1, "reason": "Validação com dados sintéticos"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exemplo de decision=approve com elegibilidade comprovada na fixture. Exige outra pessoa autorizada no programa/turma. Aprovação não emite certificado.

```json
{
  "id": "00000000-0000-4000-8000-000000000019",
  "enrollment_id": "00000000-0000-4000-8000-000000000007",
  "course_id": "curso-exemplo",
  "course_version_id": "00000000-0000-4000-8000-000000000008",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "holder_name": "Pessoa Exemplo",
  "course_title": "Curso Exemplo",
  "program_name": "Programa Exemplo",
  "institution_name": "Instituição Exemplo",
  "status": "approved",
  "revision": 2,
  "requested_at": "2026-10-13T12:00:00Z",
  "reviewed_at": "2026-10-13T12:00:00Z",
  "review_reason": "Conclusão e carga horária conferidas.",
  "class_name": "Turma Exemplo",
  "eligibility": {
    "required_seconds": 288000,
    "validated_seconds": 288000,
    "completed": true,
    "eligible": true
  }
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Revisão exige outra pessoa autorizada no programa/turma. |
| 404 | Matrícula não encontrada. |
| 404 | Pedido não encontrado. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Instituição do programa mudou; revisão exige conferência institucional. |
| 409 | Pedido alterado por outra pessoa. Recarregue. |
| 409 | Pedido não está pendente nesta revisão. |
| 422 | Carga horária/conclusão desta matrícula e edição ainda não elegível. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-104"></a>

## `POST /certificates/references`

Create Reference. Fonte: [api/app/certificates.py:83](../../api/app/certificates.py).

**Autenticação:** Bearer obrigatório; papel global: student.

**Permissão:** Token Bearer com papel global student; acesso somente aos dados do próprio titular. Exige matrícula ativa no programa/curso e turma compatível quando fornecida.

**Comportamento:** Registra referência oficial legado, após elegibilidade de carga/conclusão e verificação pública na origem configurada. Mesmo ID/payload retorna 200; nova referência 201; conflito 409. Com CERTIFICATE_APPROVAL_REQUIRED exige aprovação humana única correspondente à matrícula/edição/turma. Referência candidata é recusada.

**Flags/gates:** `CERTIFICATE_APPROVAL_REQUIRED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [CertificateReferenceCreate](SCHEMAS.md#schema-CertificateReferenceCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/certificates/references" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"content_hash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "course_id": "curso-exemplo", "id": "00000000-0000-4000-8000-000000000001", "issued_at": "2026-10-01T12:00:00Z", "program_id": "00000000-0000-4000-8000-000000000002", "verification_url": "https://example.org/verify/qa-certificate"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [CertificateReferenceResponse](SCHEMAS.md#schema-CertificateReferenceResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Exemplo hipotético de referência oficial previamente emitida e validada no provedor autorizado. Novo registro preenche holder_name/course_title/institution_name/planned_hours do contexto autorizado; não emite certificado. Exige matrícula/elegibilidade e verificação pública de nome/curso/hash; approval_required acrescenta aprovação humana. Nenhum provedor foi consultado para este exemplo.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "user_id": "00000000-0000-4000-8000-000000000004",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo",
  "class_id": null,
  "holder_name": "Pessoa Sintética QA",
  "course_title": "Curso Sintético QA",
  "institution_name": "Instituição Sintética QA",
  "planned_hours": 80.0,
  "issued_at": "2026-10-01T12:00:00Z",
  "verification_url": "https://example.org/verify/qa-certificate",
  "content_hash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Matrícula não encontrada. |
| 409 | Código de certificado em conflito. |
| 409 | Hierarquia acadêmica inconsistente. |
| 409 | Instituição inconsistente. |
| 409 | Não foi possível registrar o certificado. |
| 409 | Referência sintética não é certificado oficial. |
| 422 | A aprovação não corresponde ao contexto informado. |
| 422 | Aprovação sem contexto ativo para emissão. |
| 422 | Carga horária/conclusão ainda não elegível para certificado. |
| 422 | Carga horária/conclusão desta matrícula e edição ainda não elegível. |
| 422 | Certificado não pertence a uma turma ativa do estudante. |
| 422 | Certificado público divergente. |
| 422 | Certificado público inválido. |
| 422 | Data de emissão futura. |
| 422 | Edição não publicada ou incompatível com a matrícula. |
| 422 | Edição sem publicação pública comprovada. |
| 422 | Emissão exige aprovação humana da matrícula e edição. |
| 422 | Emissão exige um contexto ativo de matrícula não ambíguo. |
| 422 | Matrícula ativa não encontrada. |
| 422 | Matrícula/vínculo de programa inativo. |
| 422 | Turma, matrícula e edição não correspondem a um vínculo ativo. |
| 422 | URL de verificação fora da origem autorizada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Origem de verificação de certificados não configurada. |
| 503 | Verificação pública indisponível. |

<a id="operacao-105"></a>

## `POST /checkins/code`

Checkin By Code. Fonte: [api/app/evidence.py:242](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Titular precisa de matrícula ativa na turma resolvida pelo código.

**Comportamento:** Resolve código vigente de seis dígitos de encontro aberto e registra o próprio check-in, com limite compartilhado de tentativas (429 ao exceder). Código expirado/inválido retorna 401, rotação concorrente 409. Exige janela do encontro; mesmo idempotency_key/aluno/kind/encontro retorna registro existente. Não concede presença oficial.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [CodeCheckinCreate](SCHEMAS.md#schema-CodeCheckinCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/checkins/code" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"code": "000000", "idempotency_key": "qa-command-20261013-0001", "kind": "checkin"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [CheckinResponse](SCHEMAS.md#schema-CheckinResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Método do exemplo: code. O endpoint por turma usa qr com token, ou manual para equipe informando alvo; o endpoint por código sempre grava code. A evidência de check-in começa pendente e não concede presença formal. Replay idêntico retorna 200.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "session_id": "00000000-0000-4000-8000-000000000009",
  "user_id": "00000000-0000-4000-8000-000000000004",
  "kind": "checkin",
  "occurred_at": "2026-10-13T12:00:00Z",
  "method": "code",
  "evidence_id": "00000000-0000-4000-8000-000000000010"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Código inválido ou expirado. Use o código atual exibido pelo instrutor. |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula na turma não autorizada. |
| 404 | Turma não encontrada. |
| 409 | Check-in fora da janela da sessão. |
| 409 | Código em rotação. Peça o novo código ao instrutor. |
| 409 | Registro duplicado ou divergente. |
| 409 | Sessão encerrada. |
| 422 | Informe os 6 dígitos do encontro. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 429 | Muitas tentativas. Tente novamente mais tarde. |
| 503 | Rate limit temporariamente indisponível. |

<a id="operacao-106"></a>

## `POST /classes/{class_id}/evidence-imports`

Import Evidence. Fonte: [api/app/evidence.py:279](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Importa metadados de evidências com retenção futura, digest e idempotency_key. Retry com mesma turma, ator, source_type, source_digest e retenção retorna 200 com a importação original; divergência desses campos retorna 409. Aluno/encontro fora da turma é recusado. Não faz upload do arquivo original.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [ImportCreate](SCHEMAS.md#schema-ImportCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/evidence-imports" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"idempotency_key": "qa-command-20261013-0001", "items": [{"evidence_type": "observation", "item_digest": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "occurred_at": "2026-10-01T12:00:00Z"}], "retention_until": "2030-10-01T12:00:00Z", "source_digest": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "source_type": "whatsapp_export"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [ImportResponse](SCHEMAS.md#schema-ImportResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Nova importação tem status pending_review; cada evidência começa pending e aguarda revisão humana. A retenção da fixture é 2030-10-01T12:00:00Z e precisa continuar futura ao executar o exemplo. Replay idêntico retorna 200.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "source_type": "whatsapp_export",
  "status": "pending_review",
  "retention_until": "2030-10-01T12:00:00Z",
  "source_digest": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "evidence_ids": [
    "00000000-0000-4000-8000-000000000010"
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Turma não encontrada. |
| 409 | Importação divergente. |
| 409 | Registro duplicado ou divergente. |
| 422 | Retenção deve ser futura. |
| 422 | Sessão fora da turma. |
| 422 | Usuário fora da turma ou matrícula inativa. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-107"></a>

## `POST /classes/{class_id}/evidence/{evidence_id}/review`

Review. Fonte: [api/app/evidence.py:320](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Registra decisão humana sobre evidência da turma e histórico de revisão; evidência revisada não equivale automaticamente a frequência oficial.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `evidence_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [app__evidence__ReviewCreate](SCHEMAS.md#schema-app__evidence__ReviewCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/evidence/00000000-0000-4000-8000-000000000001/review" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"decision": "accepted", "reason_code": "verified"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "evidence_id": "00000000-0000-4000-8000-000000000010",
  "decision": "accepted",
  "reason_code": "verified",
  "decided_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Evidência não encontrada. |
| 404 | Turma não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-108"></a>

## `POST /classes/{class_id}/mentorship-cases`

Create Case. Fonte: [api/app/student_followup.py:288](../../api/app/student_followup.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo. Aluno alvo precisa ter matrícula ativa e mentor deve ser outra pessoa da equipe contextual ativa.

**Comportamento:** Cria caso open na revisão 1. idempotency_key idêntica retorna 200; nova criação 201; divergência/conflito retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [CaseCreate](SCHEMAS.md#schema-CaseCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/mentorship-cases" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"idempotency_key": "qa-command-20261013-0001", "mentor_id": "00000000-0000-4000-8000-000000000005", "next_action": "qa-example", "objective": "qa-example", "reason": "Validação com dados sintéticos", "user_id": "00000000-0000-4000-8000-000000000004"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **201**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Replay idêntico de idempotency_key retorna 200 e o snapshot previamente gravado.

```json
{
  "id": "00000000-0000-4000-8000-000000000013",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "user_id": "00000000-0000-4000-8000-000000000004",
  "enrollment_id": "00000000-0000-4000-8000-000000000007",
  "objective": "Revisar o conteúdo da aula de exemplo.",
  "next_action": "Agendar revisão com a mentora.",
  "status": "open",
  "revision": 1,
  "opened_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-13T12:00:00Z",
  "closed_at": null,
  "mentor_id": "00000000-0000-4000-8000-000000000005",
  "mentor_name": "Instrutora Exemplo"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 403 | Vínculo ativo e consistente do estudante obrigatório. |
| 404 | Turma não encontrada. |
| 409 | Alteração concorrente ou referência conflitante; recarregue. |
| 409 | Caso concorrente; recarregue. |
| 409 | Idempotência divergente. |
| 422 | Mentor deve ser outra pessoa da equipe ativa vinculada à turma. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-109"></a>

## `POST /classes/{class_id}/sessions/{session_id}/attendance/{user_id}`

Decide Official Attendance. Fonte: [api/app/presence.py:97](../../api/app/presence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; somente instrutor designado da turma com vínculo ativo no programa/coorte, inclusive quando tem papel global admin; alvo deve ser outra pessoa com matrícula ativa. Admin global isoladamente não autoriza.

**Comportamento:** Append-only por revisão. Exige expected_revision, motivo e idempotency_key; replay idêntico retorna decisão existente e divergência/conflito concorrente 409. Reposição precisa referenciar outro encontro da mesma turma; histórico preserva linhagem da matrícula.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `session_id` | path | sim | string | — |
| `user_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [OfficialAttendanceCreate](SCHEMAS.md#schema-OfficialAttendanceCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/sessions/00000000-0000-4000-8000-000000000009/attendance/00000000-0000-4000-8000-000000000004" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"expected_revision": 0, "idempotency_key": "qa-command-20261013-0001", "reason": "Validação com dados sintéticos", "status": "VALID"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Somente o instrutor da turma pode decidir sobre outra pessoa. required expected_revision controla concorrência e idempotency_key preserva replay.

```json
{
  "id": "00000000-0000-4000-8000-000000000011",
  "original_session_id": "00000000-0000-4000-8000-000000000009",
  "makeup_session_id": null,
  "class_id": "00000000-0000-4000-8000-000000000003",
  "user_id": "00000000-0000-4000-8000-000000000004",
  "enrollment_id": "00000000-0000-4000-8000-000000000007",
  "revision": 1,
  "status": "VALID",
  "reason": "Presença conferida pelo instrutor.",
  "actor_user_id": "00000000-0000-4000-8000-000000000005",
  "decided_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Decisão oficial exige instrutor da turma e outra pessoa como alvo. |
| 403 | Equipe da turma não autorizada. |
| 403 | Matrícula/vínculo ativo e consistente obrigatório. |
| 404 | Sessão não encontrada. |
| 404 | Turma não encontrada. |
| 409 | Decisão concorrente/inconsistente; recarregue. |
| 409 | Decisão oficial alterada; recarregue a revisão. |
| 409 | Idempotência divergente. |
| 409 | Linhagem de matrícula mudou; histórico preservado. |
| 422 | Reposição deve referenciar outro encontro da mesma turma. |
| 422 | Reposição pendente exige encontro de reposição. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-110"></a>

## `POST /classes/{class_id}/sessions/{session_id}/checkins`

Checkin. Fonte: [api/app/evidence.py:211](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Aluno só registra a si mesmo; equipe autorizada da turma pode informar outro user_id. O alvo precisa ter matrícula ativa.

**Comportamento:** idempotency_key idêntica para encontro/aluno/kind retorna 200; divergência 409. Novo registro exige encontro aberto e janela de 15 minutos antes do início até o fim. QR exige token atual válido; registro manual pela equipe dispensa token. Check-in é evidência, não presença oficial.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `session_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [CheckinCreate](SCHEMAS.md#schema-CheckinCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/sessions/00000000-0000-4000-8000-000000000009/checkins" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"idempotency_key": "qa-command-20261013-0001", "kind": "checkin", "token": "TOKEN_SINTETICO_DO_ENCONTRO"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [CheckinResponse](SCHEMAS.md#schema-CheckinResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Método do exemplo: qr. O endpoint por turma usa qr com token, ou manual para equipe informando alvo; o endpoint por código sempre grava code. A evidência de check-in começa pendente e não concede presença formal. Replay idêntico retorna 200.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "session_id": "00000000-0000-4000-8000-000000000009",
  "user_id": "00000000-0000-4000-8000-000000000004",
  "kind": "checkin",
  "occurred_at": "2026-10-13T12:00:00Z",
  "method": "qr",
  "evidence_id": "00000000-0000-4000-8000-000000000010"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 401 | Token de check-in inválido ou expirado. |
| 403 | Check-in não autorizado. |
| 403 | Matrícula na turma não autorizada. |
| 403 | Não é permitido registrar presença de outra pessoa. |
| 404 | Sessão não encontrada. |
| 404 | Turma não encontrada. |
| 409 | Check-in fora da janela da sessão. |
| 409 | Idempotência divergente. |
| 409 | Registro duplicado ou divergente. |
| 409 | Sessão encerrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-111"></a>

## `POST /classes/{class_id}/sessions/{session_id}/close`

Close. Fonte: [api/app/evidence.py:345](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou instrutor designado com participação ativa teacher/coordinator/admin no programa e vínculo contextual docente ativo quando existente. Monitor isoladamente não autoriza.

**Comportamento:** Fecha encontro e congela relatório. Pendências de evidência/presença exigem confirm_pending=true; repetição retorna o relatório já existente. Integrações externas permanecem disabled no resumo.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `session_id` | path | sim | string | — |
| `confirm_pending` | query | não | boolean | default=false |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/sessions/00000000-0000-4000-8000-000000000009/close" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [ReportResponse](SCHEMAS.md#schema-ReportResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Exemplo sem pendências de evidência/presença, com participante já confirmado. O relatório inclui resumo/presença e marca external_integrations disabled; a sessão passa a closed. Relatório existente é replay; pendências exigem confirm_pending=true.

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "session_id": "00000000-0000-4000-8000-000000000009",
  "generated_at": "2026-10-13T12:00:00Z",
  "report_digest": "b997d3e91db08f65ceb64a9e9638ea5feb8692686003f65217f920f156c1f310",
  "summary": {
    "checkin_count": 1,
    "pending_evidence_ids": [],
    "pending_explicitly_confirmed": false,
    "presence": {
      "total": 1,
      "counts": {
        "pending": 0,
        "suggested_present": 0,
        "confirmed_present": 1,
        "justified_absence": 0,
        "absent": 0
      },
      "pending_count": 0
    },
    "external_integrations": "disabled"
  }
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Sessão não encontrada. |
| 404 | Turma não encontrada. |
| 409 | Há evidências/presenças pendentes; confirme o fechamento explicitamente. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-112"></a>

## `POST /classes/{class_id}/sessions/{session_id}/presence/{user_id}`

Decide Presence. Fonte: [api/app/presence.py:233](../../api/app/presence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo. Alvo deve ser outra pessoa com matrícula ativa.

**Comportamento:** Decide presença formal em encontro aberto com expected_revision, reason e idempotency_key. Replay idêntico preserva decisão; divergência ou revisão concorrente retorna 409. Retificação append-only preserva contagens de evidência usadas na decisão.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `session_id` | path | sim | string | — |
| `user_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [PresenceCreate](SCHEMAS.md#schema-PresenceCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/sessions/00000000-0000-4000-8000-000000000009/presence/00000000-0000-4000-8000-000000000004" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"expected_revision": 0, "idempotency_key": "qa-command-20261013-0001", "reason": "Validação com dados sintéticos", "status": "confirmed_present"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Check-in e atividade são sugestões, não presença formal; a resposta mostra uma decisão humana autorizada.

```json
{
  "user_id": "00000000-0000-4000-8000-000000000004",
  "user_name": "Pessoa Exemplo",
  "enrollment_id": "00000000-0000-4000-8000-000000000007",
  "status": "confirmed_present",
  "revision": 1,
  "checkin_count": 1,
  "checkout_count": 0,
  "activity_count": 0,
  "reason": "Presença conferida pelo instrutor.",
  "decided_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | A decisão exige outra pessoa da equipe. |
| 403 | Equipe da turma não autorizada. |
| 403 | Matrícula/vínculo ativo e consistente obrigatório. |
| 404 | Sessão não encontrada. |
| 404 | Turma não encontrada. |
| 409 | Decisão concorrente/inconsistente; recarregue. |
| 409 | Idempotência divergente. |
| 409 | Matrícula do vínculo mudou; associação histórica preservada. |
| 409 | Presença alterada; recarregue a revisão. |
| 409 | Sessão encerrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-113"></a>

## `POST /classes/{class_id}/sessions/{session_id}/token`

Rotate Token. Fonte: [api/app/evidence.py:196](../../api/app/evidence.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo.

**Comportamento:** Rotaciona token e código de encontro aberto; incrementa token_version e invalida os valores anteriores. Encontro encerrado retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `session_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/sessions/00000000-0000-4000-8000-000000000009/token" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [SessionResponse](SCHEMAS.md#schema-SessionResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Somente sessão open pode rotacionar. O exemplo parte da versão 1 e retorna versão 2 com novo token/código e janela de até 10 minutos.

```json
{
  "id": "00000000-0000-4000-8000-000000000009",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "starts_at": "2026-10-13T12:00:00Z",
  "ends_at": "2026-10-13T13:00:00Z",
  "status": "open",
  "token_expires_at": "2026-10-13T12:10:00Z",
  "token_version": 2,
  "checkin_token": "TOKEN_SINTETICO_ROTACIONADO",
  "checkin_code": "111111"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Sessão não encontrada. |
| 404 | Turma não encontrada. |
| 409 | Sessão encerrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Não foi possível gerar o código do encontro. |

<a id="operacao-114"></a>

## `POST /courses`

Create Course. Fonte: [api/app/course_editor.py:386](../../api/app/course_editor.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou participação ativa teacher/creator/coordinator/admin no programa do curso.

**Comportamento:** Cria curso inativo e primeira edição draft revisão 1, vinculados ao programa; course_id existente retorna 409. Não aparece no catálogo até publicação.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [CourseCreate](SCHEMAS.md#schema-CourseCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/courses" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"author": "Equipe Sintética QA", "course_id": "curso-exemplo", "program_id": "00000000-0000-4000-8000-000000000002", "title": "Curso Sintético QA"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **201**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Curso novo começa em draft, com sections vazias, e ainda não entra no catálogo público.

```json
{
  "sections": [],
  "id": "curso-exemplo",
  "title": "Curso Exemplo",
  "author": "Autoria Exemplo",
  "course_id": "curso-exemplo",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "version_id": "00000000-0000-4000-8000-000000000008",
  "version_number": 1,
  "revision": 1,
  "status": "draft",
  "created_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-13T12:00:00Z",
  "can_edit": true,
  "can_submit": true,
  "can_publish": false,
  "can_archive": false,
  "can_fork": false
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Vínculo editorial não autorizado. |
| 404 | Programa não encontrado. |
| 409 | Curso alterado por outra pessoa ou identificador já existente. Recarregue. |
| 409 | Identificador de curso já cadastrado. |
| 422 | Curso excede o limite de 2 MB. |
| 422 | IDs de conteúdos devem ser únicos. |
| 422 | IDs de materiais devem ser únicos no módulo. |
| 422 | IDs de módulos devem ser únicos e não vazios. |
| 422 | Inclua até 50 materiais por módulo. |
| 422 | Material inválido: use id, kind, title e URL pública HTTPS ou media_id. |
| 422 | Mensagem requer type e content textuais. |
| 422 | Mensagens do módulo inválidas. |
| 422 | Módulo inválido. |
| 422 | Opções de mensagem inválidas. |
| 422 | Título do módulo obrigatório. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 422 | sections deve ser uma lista. |

<a id="operacao-115"></a>

## `POST /courses/{course_id}/archive`

Archive Course. Fonte: [api/app/course_editor.py:487](../../api/app/course_editor.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou coordinator/admin com participação ativa em TODOS os programas que ofertam o curso.

**Comportamento:** Transição published→archived na expected_revision, desativa catálogo público. Snapshot arquivado permanece acessível a turmas que o fixaram; não migra seus dados/progresso.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [VersionAction](SCHEMAS.md#schema-VersionAction). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/courses/curso-qa/archive" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"expected_revision": 1, "version_id": "00000000-0000-4000-8000-000000000008"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige published e autoridade de publicação; desativa a projeção pública. Snapshot já fixado em turma permanece histórico.

```json
{
  "sections": [
    {
      "id": "modulo-1",
      "title": "Introdução",
      "messages": [
        {
          "id": "mensagem-1",
          "type": "bot",
          "content": "Bem-vindo ao curso de exemplo.",
          "version_id": "d4e2d145-d35b-5d37-a62e-415008018a8d"
        }
      ],
      "version_id": "4ee7532d-fe21-5972-9720-2e3e863a53c4"
    }
  ],
  "id": "curso-exemplo",
  "title": "Curso Exemplo",
  "author": "Autoria Exemplo",
  "course_id": "curso-exemplo",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "version_id": "00000000-0000-4000-8000-000000000008",
  "version_number": 1,
  "revision": 5,
  "status": "archived",
  "created_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-13T12:00:00Z",
  "can_edit": false,
  "can_submit": false,
  "can_publish": false,
  "can_archive": false,
  "can_fork": true
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Transição editorial não autorizada. |
| 404 | Versão não encontrada. |
| 409 | Curso alterado por outra pessoa ou identificador já existente. Recarregue. |
| 409 | Uma versão mais recente já foi publicada. |
| 409 | Versão alterada por outra pessoa. Recarregue antes de salvar. |
| 409 | Versão alterada por outra pessoa. Recarregue. |
| 422 | Expressão: f'Módulo {section_index}: inclua pelo menos uma mensagem.' |
| 422 | Expressão: f'Módulo {section_index}: título deve ter até {MAX_DYNAMIC_SECTION_TITLE} caracteres sem controles.' |
| 422 | Expressão: f'{location}: cada opção exige rótulo não vazio.' |
| 422 | Expressão: f'{location}: inclua no máximo {MAX_DYNAMIC_OPTIONS} opções.' |
| 422 | Expressão: f'{location}: inclua pelo menos {minimum} opção(ões).' |
| 422 | Expressão: f'{location}: isCorrect da opção deve ser booleano.' |
| 422 | Expressão: f'{location}: quiz exige pelo menos uma alternativa correta.' |
| 422 | Expressão: f'{location}: texto obrigatório.' |
| 422 | Expressão: f'{location}: tipo deve ser bot, question, quiz ou user.' |
| 422 | Expressão: f'{location}: {field} da opção deve ser texto.' |
| 422 | Expressão: f'{location}: {field} deve ser texto.' |
| 422 | IDs de materiais devem ser únicos no módulo. |
| 422 | Inclua até 50 materiais por módulo. |
| 422 | Inclua pelo menos um módulo antes da revisão/publicação. |
| 422 | Material inválido: use id, kind, title e URL pública HTTPS ou media_id. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 422 | Vídeo deve estar publicado e pertencer ao programa, curso e módulo desta edição. |

<a id="operacao-116"></a>

## `POST /courses/{course_id}/publish`

Publish Course. Fonte: [api/app/course_editor.py:482](../../api/app/course_editor.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou coordinator/admin com participação ativa em TODOS os programas que ofertam o curso.

**Comportamento:** Transição in_review→published na expected_revision; exige conteúdo/material válidos e número posterior à última release. Arquiva edição pública anterior e atualiza projeção pública; turmas mantêm edição fixada.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [VersionAction](SCHEMAS.md#schema-VersionAction). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/courses/curso-qa/publish" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"expected_revision": 1, "version_id": "00000000-0000-4000-8000-000000000008"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige in_review e autoridade de publicação em todos os programas que ofertam o curso. Atualiza a projeção pública do Course e arquiva a edição anterior.

```json
{
  "sections": [
    {
      "id": "modulo-1",
      "title": "Introdução",
      "messages": [
        {
          "id": "mensagem-1",
          "type": "bot",
          "content": "Bem-vindo ao curso de exemplo.",
          "version_id": "d4e2d145-d35b-5d37-a62e-415008018a8d"
        }
      ],
      "version_id": "4ee7532d-fe21-5972-9720-2e3e863a53c4"
    }
  ],
  "id": "curso-exemplo",
  "title": "Curso Exemplo",
  "author": "Autoria Exemplo",
  "course_id": "curso-exemplo",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "version_id": "00000000-0000-4000-8000-000000000008",
  "version_number": 1,
  "revision": 4,
  "status": "published",
  "created_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-13T12:00:00Z",
  "can_edit": false,
  "can_submit": false,
  "can_publish": false,
  "can_archive": true,
  "can_fork": true
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Transição editorial não autorizada. |
| 404 | Versão não encontrada. |
| 409 | Curso alterado por outra pessoa ou identificador já existente. Recarregue. |
| 409 | Uma versão mais recente já foi publicada. |
| 409 | Versão alterada por outra pessoa. Recarregue antes de salvar. |
| 409 | Versão alterada por outra pessoa. Recarregue. |
| 422 | Expressão: f'Módulo {section_index}: inclua pelo menos uma mensagem.' |
| 422 | Expressão: f'Módulo {section_index}: título deve ter até {MAX_DYNAMIC_SECTION_TITLE} caracteres sem controles.' |
| 422 | Expressão: f'{location}: cada opção exige rótulo não vazio.' |
| 422 | Expressão: f'{location}: inclua no máximo {MAX_DYNAMIC_OPTIONS} opções.' |
| 422 | Expressão: f'{location}: inclua pelo menos {minimum} opção(ões).' |
| 422 | Expressão: f'{location}: isCorrect da opção deve ser booleano.' |
| 422 | Expressão: f'{location}: quiz exige pelo menos uma alternativa correta.' |
| 422 | Expressão: f'{location}: texto obrigatório.' |
| 422 | Expressão: f'{location}: tipo deve ser bot, question, quiz ou user.' |
| 422 | Expressão: f'{location}: {field} da opção deve ser texto.' |
| 422 | Expressão: f'{location}: {field} deve ser texto.' |
| 422 | IDs de materiais devem ser únicos no módulo. |
| 422 | Inclua até 50 materiais por módulo. |
| 422 | Inclua pelo menos um módulo antes da revisão/publicação. |
| 422 | Material inválido: use id, kind, title e URL pública HTTPS ou media_id. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 422 | Vídeo deve estar publicado e pertencer ao programa, curso e módulo desta edição. |

<a id="operacao-117"></a>

## `POST /courses/{course_id}/submit`

Submit Course. Fonte: [api/app/course_editor.py:477](../../api/app/course_editor.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou participação ativa teacher/creator/coordinator/admin no programa do curso. Somente autor do draft ou coordinator/admin autorizado.

**Comportamento:** Transição draft→in_review na expected_revision; valida estrutura publicável e linhagem de materiais. Não publica no catálogo; conflito de revisão retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [VersionAction](SCHEMAS.md#schema-VersionAction). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/courses/curso-qa/submit" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"expected_revision": 1, "version_id": "00000000-0000-4000-8000-000000000008"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige draft autorizado e conteúdo publicável. A mudança de estado não publica no catálogo.

```json
{
  "sections": [
    {
      "id": "modulo-1",
      "title": "Introdução",
      "messages": [
        {
          "id": "mensagem-1",
          "type": "bot",
          "content": "Bem-vindo ao curso de exemplo.",
          "version_id": "d4e2d145-d35b-5d37-a62e-415008018a8d"
        }
      ],
      "version_id": "4ee7532d-fe21-5972-9720-2e3e863a53c4"
    }
  ],
  "id": "curso-exemplo",
  "title": "Curso Exemplo",
  "author": "Autoria Exemplo",
  "course_id": "curso-exemplo",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "version_id": "00000000-0000-4000-8000-000000000008",
  "version_number": 1,
  "revision": 3,
  "status": "in_review",
  "created_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-13T12:00:00Z",
  "can_edit": false,
  "can_submit": false,
  "can_publish": true,
  "can_archive": false,
  "can_fork": false
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Transição editorial não autorizada. |
| 404 | Versão não encontrada. |
| 409 | Curso alterado por outra pessoa ou identificador já existente. Recarregue. |
| 409 | Uma versão mais recente já foi publicada. |
| 409 | Versão alterada por outra pessoa. Recarregue antes de salvar. |
| 409 | Versão alterada por outra pessoa. Recarregue. |
| 422 | Expressão: f'Módulo {section_index}: inclua pelo menos uma mensagem.' |
| 422 | Expressão: f'Módulo {section_index}: título deve ter até {MAX_DYNAMIC_SECTION_TITLE} caracteres sem controles.' |
| 422 | Expressão: f'{location}: cada opção exige rótulo não vazio.' |
| 422 | Expressão: f'{location}: inclua no máximo {MAX_DYNAMIC_OPTIONS} opções.' |
| 422 | Expressão: f'{location}: inclua pelo menos {minimum} opção(ões).' |
| 422 | Expressão: f'{location}: isCorrect da opção deve ser booleano.' |
| 422 | Expressão: f'{location}: quiz exige pelo menos uma alternativa correta.' |
| 422 | Expressão: f'{location}: texto obrigatório.' |
| 422 | Expressão: f'{location}: tipo deve ser bot, question, quiz ou user.' |
| 422 | Expressão: f'{location}: {field} da opção deve ser texto.' |
| 422 | Expressão: f'{location}: {field} deve ser texto.' |
| 422 | IDs de materiais devem ser únicos no módulo. |
| 422 | Inclua até 50 materiais por módulo. |
| 422 | Inclua pelo menos um módulo antes da revisão/publicação. |
| 422 | Material inválido: use id, kind, title e URL pública HTTPS ou media_id. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 422 | Vídeo deve estar publicado e pertencer ao programa, curso e módulo desta edição. |

<a id="operacao-118"></a>

## `POST /courses/{course_id}/versions`

Fork Course. Fonte: [api/app/course_editor.py:424](../../api/app/course_editor.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Admin global ou participação ativa teacher/creator/coordinator/admin no programa do curso. Edições published/archived são visíveis; rascunhos/revisões são restritos ao autor ou coordinator/admin autorizado.

**Comportamento:** Cria fork draft de edição published/archived visível e incrementa version_number; não modifica edição origem nem turma já fixada. Conflito de criação paralela retorna 409.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `course_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [VersionFork](SCHEMAS.md#schema-VersionFork). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/courses/curso-qa/versions" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"source_version_id": "00000000-0000-4000-8000-000000000008"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **201**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Cria novo draft a partir de edição published/archived. O exemplo pressupõe a edição 1 publicada na fixture.

```json
{
  "sections": [
    {
      "id": "modulo-1",
      "title": "Introdução",
      "messages": [
        {
          "id": "mensagem-1",
          "type": "bot",
          "content": "Bem-vindo ao curso de exemplo.",
          "version_id": "d4e2d145-d35b-5d37-a62e-415008018a8d"
        }
      ],
      "version_id": "4ee7532d-fe21-5972-9720-2e3e863a53c4"
    }
  ],
  "id": "curso-exemplo",
  "title": "Curso Exemplo",
  "author": "Autoria Exemplo",
  "course_id": "curso-exemplo",
  "program_id": "00000000-0000-4000-8000-000000000002",
  "version_id": "00000000-0000-4000-8000-000000000008",
  "version_number": 2,
  "revision": 1,
  "status": "draft",
  "created_at": "2026-10-13T12:00:00Z",
  "updated_at": "2026-10-13T12:00:00Z",
  "can_edit": true,
  "can_submit": true,
  "can_publish": false,
  "can_archive": false,
  "can_fork": false
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Somente versões publicadas ou arquivadas podem originar rascunho. |
| 404 | Versão não encontrada. |
| 409 | Curso alterado por outra pessoa ou identificador já existente. Recarregue. |
| 409 | Outra versão foi criada. Recarregue. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-119"></a>

## `POST /events`

Create Event. Fonte: [api/app/events.py:168](../../api/app/events.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer. Papel global student no caminho legado; outros papéis podem enviar telemetria com JOURNEY_TRACEABILITY_ENABLED ou eventos versionados de turma com LEARNING_CONTEXT_ENABLED, sempre sujeitos à autorização relacional.

**Comportamento:** event_id é idempotente: repetição idêntica do mesmo titular retorna 200; nova inserção 201; divergência retorna 409. screen_engagement exige JOURNEY_TRACEABILITY_ENABLED. Evento de edição/turma deve corresponder à matrícula ativa e edição fixada; eventos não concedem autorização, presença ou certificado.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `JOURNEY_TRACEABILITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [EventCreate](SCHEMAS.md#schema-EventCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/events" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"course_id": "curso-exemplo", "event_id": "00000000-0000-4000-8000-000000000001", "event_type": "page_viewed", "occurred_at": "2026-10-01T12:00:00Z", "payload": {"page_id": "classroom"}, "session_id": "00000000-0000-4000-8000-000000000009"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [EventResponse](SCHEMAS.md#schema-EventResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético do modelo de resposta.

```json
{
  "event_id": "00000000-0000-4000-8000-000000000001",
  "event_type": "page_viewed",
  "course_id": "curso-exemplo",
  "session_id": "00000000-0000-4000-8000-000000000009",
  "occurred_at": "2026-10-01T12:00:00Z",
  "active_seconds": null,
  "payload": {
    "page_id": "classroom"
  },
  "sync_status": "pending",
  "validated_seconds": 0
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Acesso/matrícula da mídia não autorizado. |
| 403 | Versão/turma sem matrícula ativa autorizada. |
| 404 | Curso publicado não encontrado. |
| 404 | Mídia publicada não encontrada. |
| 404 | Tempo de tela ainda não habilitado. |
| 404 | Versão de curso publicada não encontrada. |
| 409 | event_id em conflito. |
| 422 | Atividade possui mais de uma matrícula ativa para o curso. |
| 422 | Checkpoint incompatível com a posição. |
| 422 | Curso/módulo não corresponde à mídia. |
| 422 | Informe class_id para identificar a matrícula desta versão. |
| 422 | Posição incompatível com a duração. |
| 422 | Sequência de checkpoint inválida. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-120"></a>

## `POST /media/{media_id}/playback-authorizations`

Authorize Media Playback. Fonte: [api/app/media.py:454](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Revalida visibilidade e vínculos da mídia publicada.

**Comportamento:** Emite URL de autorização de playback de cinco minutos, com token aleatório armazenado por digest. Entrega não configurada retorna 503. Autorização não modifica offline_policy nem concede acesso acadêmico.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `media_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/media/00000000-0000-4000-8000-000000000001/playback-authorizations" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | [PlaybackAuthorizationResponse](SCHEMAS.md#schema-PlaybackAuthorizationResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Grant criado somente após mídia published, entrega configurada e acesso vigente. expires_at é agora+300s; playback_url aponta para o endpoint autenticado do grant, não diretamente para o provedor. URL/token demonstrativos não funcionam em ambiente real.

```json
{
  "media_id": "00000000-0000-4000-8000-000000000001",
  "playback_url": "https://example.org/tutor-api/media/00000000-0000-4000-8000-000000000001/playback/TOKEN_DE_PLAYBACK_SINTETICO_NAO_UTILIZAVEL",
  "expires_at": "2026-10-13T12:05:00Z",
  "token_type": "media_playback"
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Mídia não encontrada. |
| 404 | Mídia publicada não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Entrega da mídia não configurada. |

<a id="operacao-121"></a>

## `POST /operations/classes`

Prepare Class. Fonte: [api/app/class_lifecycle.py:661](../../api/app/class_lifecycle.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator ou coordinator. Papel global admin não substitui esse vínculo.

**Comportamento:** Prepara turma planned para oferta/edição publicada e equipe válida. id é chave do recibo: mesma requisição e ator retornam snapshot original; divergência retorna 409. Valida instituição/programa e registra motivo/histórico.

**Flags/gates:** `CLASS_LIFECYCLE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `authorization` | header | não | string / null | — |

**Body JSON:** [PrepareClassCommand](SCHEMAS.md#schema-PrepareClassCommand). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/operations/classes" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"course_id": "curso-exemplo", "end_date": "2026-10-14", "id": "00000000-0000-4000-8000-000000000001", "institution_id": "00000000-0000-4000-8000-000000000001", "name": "Pessoa Sintética QA", "offer_location": "qa-example", "offer_municipality": "qa-example", "program_id": "00000000-0000-4000-8000-000000000002", "reason": "Validação com dados sintéticos", "start_date": "2026-10-13", "teacher_id": "00000000-0000-4000-8000-000000000005", "version_id": "00000000-0000-4000-8000-000000000008"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 201 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **201**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige CLASS_LIFECYCLE_ENABLED=true e escopo de programa autorizado. Com a flag desligada responde 404: Ciclo de turma indisponível. Replay idêntico retorna o snapshot original. Permissão de preparação exige program_operator ou coordinator.

```json
{
  "classroom": {
    "id": "00000000-0000-4000-8000-000000000003",
    "institution_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "course_id": "curso-exemplo",
    "course_version_id": "00000000-0000-4000-8000-000000000008",
    "teacher_id": "00000000-0000-4000-8000-000000000005",
    "monitor_ids": [
      "00000000-0000-4000-8000-000000000006"
    ],
    "name": "Turma Exemplo",
    "offer_municipality": "Município Exemplo",
    "offer_location": "Sala Exemplo",
    "start_date": "2026-11-01",
    "end_date": "2026-11-30",
    "status": "planned",
    "revision": 1
  },
  "capacity": {
    "limit": 30,
    "occupancy": 0,
    "remaining": 30,
    "over_capacity": false,
    "policy": "soft_alert",
    "warning": false,
    "exception": null
  },
  "readiness": {
    "activation_blockers": [],
    "can_activate": true,
    "can_close": false,
    "closure_blockers": [],
    "closure_warnings": {
      "open_sessions": 0,
      "pending_evidence": 0,
      "pending_makeup": 0,
      "pending_certificate_requests": 0
    },
    "closure_warnings_block_close": false,
    "close_open_session_policy": "BLOCK_CLOSE_WITH_OPEN_SESSION"
  },
  "capabilities": {
    "role": "coordinator",
    "can_prepare": true,
    "can_change_team": true,
    "can_activate": true,
    "can_close": false,
    "can_override_capacity": false
  },
  "history": [
    {
      "id": "00000000-0000-4000-8000-000000000015",
      "revision": 1,
      "action": "prepare",
      "actor_id": "00000000-0000-4000-8000-000000000014",
      "reason": "Preparação da turma de exemplo.",
      "occurred_at": "2026-10-13T12:00:00Z"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 201, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Ator não autorizado para este programa. |
| 403 | Programa não pertence à instituição informada. |
| 404 | Ciclo de turma indisponível. |
| 404 | Programa não encontrado. |
| 409 | Conflito ao preparar a turma; consulte novamente. |
| 409 | Curso não possui versão publicada. |
| 409 | Expressão: {'code': 'course_version_changed', 'message': 'A edição publicada mudou. Confira e selecione a formação novamente.'} |
| 409 | Replay de lifecycle divergente. |
| 409 | Replay de programa divergente. |
| 422 | Curso excede o limite de 2 MB. |
| 422 | Curso não está publicado para novas turmas. |
| 422 | Curso não é ofertado por este programa. |
| 422 | Expressão: f'{role} não possui vínculo ativo neste programa.' |
| 422 | IDs de conteúdos devem ser únicos. |
| 422 | IDs de materiais devem ser únicos no módulo. |
| 422 | IDs de módulos devem ser únicos e não vazios. |
| 422 | Inclua até 50 materiais por módulo. |
| 422 | Material inválido: use id, kind, title e URL pública HTTPS ou media_id. |
| 422 | Mensagem requer type e content textuais. |
| 422 | Mensagens do módulo inválidas. |
| 422 | Módulo inválido. |
| 422 | Opções de mensagem inválidas. |
| 422 | Título do módulo obrigatório. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 422 | sections deve ser uma lista. |

<a id="operacao-122"></a>

## `POST /operations/classes/{class_id}/plan`

Update Plan. Fonte: [api/app/class_lifecycle.py:815](../../api/app/class_lifecycle.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator ou coordinator. Papel global admin não substitui esse vínculo.

**Comportamento:** Altera planejamento territorial somente em planned, com contexto exato e expected_revision. id de comando idempotente devolve snapshot original; alteração aumenta lifecycle_revision.

**Flags/gates:** `CLASS_LIFECYCLE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [PlanClassCommand](SCHEMAS.md#schema-PlanClassCommand). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/operations/classes/00000000-0000-4000-8000-000000000003/plan" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"course_id": "curso-exemplo", "end_date": "2026-10-14", "expected_revision": 0, "id": "00000000-0000-4000-8000-000000000001", "institution_id": "00000000-0000-4000-8000-000000000001", "name": "Pessoa Sintética QA", "offer_location": "qa-example", "offer_municipality": "qa-example", "program_id": "00000000-0000-4000-8000-000000000002", "reason": "Validação com dados sintéticos", "start_date": "2026-10-13", "version_id": "00000000-0000-4000-8000-000000000008"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige CLASS_LIFECYCLE_ENABLED=true e escopo de programa autorizado. Com a flag desligada responde 404: Ciclo de turma indisponível.

```json
{
  "classroom": {
    "id": "00000000-0000-4000-8000-000000000003",
    "institution_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "course_id": "curso-exemplo",
    "course_version_id": "00000000-0000-4000-8000-000000000008",
    "teacher_id": "00000000-0000-4000-8000-000000000005",
    "monitor_ids": [
      "00000000-0000-4000-8000-000000000006"
    ],
    "name": "Turma Exemplo",
    "offer_municipality": "Município Exemplo",
    "offer_location": "Sala Exemplo",
    "start_date": "2026-11-01",
    "end_date": "2026-11-30",
    "status": "planned",
    "revision": 2
  },
  "capacity": {
    "limit": 30,
    "occupancy": 0,
    "remaining": 30,
    "over_capacity": false,
    "policy": "soft_alert",
    "warning": false,
    "exception": null
  },
  "readiness": {
    "activation_blockers": [],
    "can_activate": true,
    "can_close": false,
    "closure_blockers": [],
    "closure_warnings": {
      "open_sessions": 0,
      "pending_evidence": 0,
      "pending_makeup": 0,
      "pending_certificate_requests": 0
    },
    "closure_warnings_block_close": false,
    "close_open_session_policy": "BLOCK_CLOSE_WITH_OPEN_SESSION"
  },
  "capabilities": {
    "role": "coordinator",
    "can_prepare": true,
    "can_change_team": true,
    "can_activate": true,
    "can_close": false,
    "can_override_capacity": false
  },
  "history": [
    {
      "id": "00000000-0000-4000-8000-000000000015",
      "revision": 1,
      "action": "prepare",
      "actor_id": "00000000-0000-4000-8000-000000000014",
      "reason": "Preparação da turma de exemplo.",
      "occurred_at": "2026-10-13T12:00:00Z"
    },
    {
      "id": "00000000-0000-4000-8000-000000000016",
      "revision": 2,
      "action": "plan",
      "actor_id": "00000000-0000-4000-8000-000000000014",
      "reason": "Ajuste autorizado de exemplo.",
      "occurred_at": "2026-10-13T12:00:00Z"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Ator não autorizado para esta turma. |
| 403 | Comando fora do contexto territorial autorizado. |
| 404 | Ciclo de turma indisponível. |
| 404 | Turma não encontrada. |
| 409 | A turma mudou; consulte o readiness antes de reenviar. |
| 409 | Planejamento territorial só pode ser alterado em planned. |
| 409 | Programa da turma inconsistente. |
| 409 | Replay de lifecycle divergente. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-123"></a>

## `POST /operations/classes/{class_id}/team`

Update Team. Fonte: [api/app/class_lifecycle.py:858](../../api/app/class_lifecycle.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator ou coordinator. Papel global admin não substitui esse vínculo. program_operator altera equipe somente em planned; após ativação exige coordinator.

**Comportamento:** Substitui instrutor/monitores validando vínculos teacher/monitor ativos; turma closed é imutável. Exige contexto exato, expected_revision, motivo e idempotência por id.

**Flags/gates:** `CLASS_LIFECYCLE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [TeamClassCommand](SCHEMAS.md#schema-TeamClassCommand). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/operations/classes/00000000-0000-4000-8000-000000000003/team" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"course_id": "curso-exemplo", "expected_revision": 0, "id": "00000000-0000-4000-8000-000000000001", "institution_id": "00000000-0000-4000-8000-000000000001", "program_id": "00000000-0000-4000-8000-000000000002", "reason": "Validação com dados sintéticos", "teacher_id": "00000000-0000-4000-8000-000000000005", "version_id": "00000000-0000-4000-8000-000000000008"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige CLASS_LIFECYCLE_ENABLED=true e escopo de programa autorizado. Com a flag desligada responde 404: Ciclo de turma indisponível.

```json
{
  "classroom": {
    "id": "00000000-0000-4000-8000-000000000003",
    "institution_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "course_id": "curso-exemplo",
    "course_version_id": "00000000-0000-4000-8000-000000000008",
    "teacher_id": "00000000-0000-4000-8000-000000000005",
    "monitor_ids": [
      "00000000-0000-4000-8000-000000000006"
    ],
    "name": "Turma Exemplo",
    "offer_municipality": "Município Exemplo",
    "offer_location": "Sala Exemplo",
    "start_date": "2026-11-01",
    "end_date": "2026-11-30",
    "status": "planned",
    "revision": 2
  },
  "capacity": {
    "limit": 30,
    "occupancy": 0,
    "remaining": 30,
    "over_capacity": false,
    "policy": "soft_alert",
    "warning": false,
    "exception": null
  },
  "readiness": {
    "activation_blockers": [],
    "can_activate": true,
    "can_close": false,
    "closure_blockers": [],
    "closure_warnings": {
      "open_sessions": 0,
      "pending_evidence": 0,
      "pending_makeup": 0,
      "pending_certificate_requests": 0
    },
    "closure_warnings_block_close": false,
    "close_open_session_policy": "BLOCK_CLOSE_WITH_OPEN_SESSION"
  },
  "capabilities": {
    "role": "coordinator",
    "can_prepare": true,
    "can_change_team": true,
    "can_activate": true,
    "can_close": false,
    "can_override_capacity": false
  },
  "history": [
    {
      "id": "00000000-0000-4000-8000-000000000015",
      "revision": 1,
      "action": "prepare",
      "actor_id": "00000000-0000-4000-8000-000000000014",
      "reason": "Preparação da turma de exemplo.",
      "occurred_at": "2026-10-13T12:00:00Z"
    },
    {
      "id": "00000000-0000-4000-8000-000000000016",
      "revision": 2,
      "action": "team",
      "actor_id": "00000000-0000-4000-8000-000000000014",
      "reason": "Ajuste autorizado de exemplo.",
      "occurred_at": "2026-10-13T12:00:00Z"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Após ativação, somente a coordenação pode alterar a equipe. |
| 403 | Ator não autorizado para esta turma. |
| 403 | Comando fora do contexto territorial autorizado. |
| 404 | Ciclo de turma indisponível. |
| 404 | Turma não encontrada. |
| 409 | A turma mudou; consulte o readiness antes de reenviar. |
| 409 | Programa da turma inconsistente. |
| 409 | Replay de lifecycle divergente. |
| 409 | Turma encerrada é imutável. |
| 422 | Expressão: f'{role} não possui vínculo ativo neste programa.' |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-124"></a>

## `POST /operations/classes/{class_id}/transition`

Transition Class. Fonte: [api/app/class_lifecycle.py:904](../../api/app/class_lifecycle.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator ou coordinator. Papel global admin não substitui esse vínculo.

**Comportamento:** Transições planned→active e active→closed com expected_revision e idempotência. Ativação exige readiness sem bloqueios; fechamento exige ausência de encontros abertos. Demais pendências são avisos preservados no snapshot.

**Flags/gates:** `CLASS_LIFECYCLE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [TransitionClassCommand](SCHEMAS.md#schema-TransitionClassCommand). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/operations/classes/00000000-0000-4000-8000-000000000003/transition" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"course_id": "curso-exemplo", "expected_revision": 0, "id": "00000000-0000-4000-8000-000000000001", "institution_id": "00000000-0000-4000-8000-000000000001", "program_id": "00000000-0000-4000-8000-000000000002", "reason": "Validação com dados sintéticos", "target_status": "active", "version_id": "00000000-0000-4000-8000-000000000008"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige CLASS_LIFECYCLE_ENABLED=true e escopo de programa autorizado. Com a flag desligada responde 404: Ciclo de turma indisponível. Exemplo de transição planned → active com blockers vazios. Encerramento é bloqueado quando há encontro aberto.

```json
{
  "classroom": {
    "id": "00000000-0000-4000-8000-000000000003",
    "institution_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "course_id": "curso-exemplo",
    "course_version_id": "00000000-0000-4000-8000-000000000008",
    "teacher_id": "00000000-0000-4000-8000-000000000005",
    "monitor_ids": [
      "00000000-0000-4000-8000-000000000006"
    ],
    "name": "Turma Exemplo",
    "offer_municipality": "Município Exemplo",
    "offer_location": "Sala Exemplo",
    "start_date": "2026-11-01",
    "end_date": "2026-11-30",
    "status": "active",
    "revision": 2
  },
  "capacity": {
    "limit": 30,
    "occupancy": 0,
    "remaining": 30,
    "over_capacity": false,
    "policy": "soft_alert",
    "warning": false,
    "exception": null
  },
  "readiness": {
    "activation_blockers": [],
    "can_activate": false,
    "can_close": true,
    "closure_blockers": [],
    "closure_warnings": {
      "open_sessions": 0,
      "pending_evidence": 0,
      "pending_makeup": 0,
      "pending_certificate_requests": 0
    },
    "closure_warnings_block_close": false,
    "close_open_session_policy": "BLOCK_CLOSE_WITH_OPEN_SESSION"
  },
  "capabilities": {
    "role": "coordinator",
    "can_prepare": false,
    "can_change_team": true,
    "can_activate": false,
    "can_close": true,
    "can_override_capacity": false
  },
  "history": [
    {
      "id": "00000000-0000-4000-8000-000000000015",
      "revision": 1,
      "action": "prepare",
      "actor_id": "00000000-0000-4000-8000-000000000014",
      "reason": "Preparação da turma de exemplo.",
      "occurred_at": "2026-10-13T12:00:00Z"
    },
    {
      "id": "00000000-0000-4000-8000-000000000016",
      "revision": 2,
      "action": "transition_active",
      "actor_id": "00000000-0000-4000-8000-000000000014",
      "reason": "Ativação autorizada da turma.",
      "occurred_at": "2026-10-13T12:00:00Z"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Ator não autorizado para ativar ou encerrar turmas. |
| 403 | Ator não autorizado para esta turma. |
| 403 | Comando fora do contexto territorial autorizado. |
| 404 | Ciclo de turma indisponível. |
| 404 | Turma não encontrada. |
| 409 | A turma mudou; consulte o readiness antes de reenviar. |
| 409 | Ativação exige estado planned. |
| 409 | Encerramento exige estado active. |
| 409 | Expressão: {'message': 'Encerre todas as sessões antes de encerrar a turma.', 'blockers': ['open_sessions'], 'open_sessions': warnings['open_sessions']} |
| 409 | Expressão: {'message': 'Turma ainda não está pronta para ativação.', 'blockers': blockers} |
| 409 | Programa da turma inconsistente. |
| 409 | Replay de lifecycle divergente. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-125"></a>

## `POST /operations/{class_id}/commands`

Execute. Fonte: [api/app/operator_operations.py:190](../../api/app/operator_operations.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator, coordinator ou admin. Papel global admin sem vínculo de programa não autoriza.

**Comportamento:** Executa register/enroll/assign/revoke em escopo instituição/programa/curso/edição exato. id identifica recibo idempotente; replay divergente retorna 409. Comandos de pessoa existente exigem expected_revision e identity_proof se ainda fora do programa; turma closed bloqueia novos comandos. Cadastro cria identidade/participação, sem fabricar baseline.

**Flags/gates:** `OPERATOR_OPERATIONS_ENABLED`, `CPF_ACTIVATION_REQUIRED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [Command](SCHEMAS.md#schema-Command). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/operations/00000000-0000-4000-8000-000000000003/commands" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"action": "register", "course_id": "curso-exemplo", "id": "00000000-0000-4000-8000-000000000001", "institution_id": "00000000-0000-4000-8000-000000000001", "program_id": "00000000-0000-4000-8000-000000000002", "reason": "Validação com dados sintéticos", "registration": {"cpf": "12345678909", "name": "Pessoa Sintética QA", "password": "Apenas-exemplo-nao-utilizar-2026", "phone": "00000000000"}, "version_id": "00000000-0000-4000-8000-000000000008"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige OPERATOR_OPERATIONS_ENABLED=true e vínculo ativo autorizado no programa. Com a flag desligada responde 404: Operação indisponível. Exemplo de resultado de action=enroll; outras ações mudam enrolled/assigned/history. Não cria resultado acadêmico.

```json
{
  "person": {
    "id": "00000000-0000-4000-8000-000000000004",
    "name": "Pessoa Exemplo"
  },
  "scope": {
    "institution_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "course_id": "curso-exemplo",
    "class_id": "00000000-0000-4000-8000-000000000003",
    "version_id": "00000000-0000-4000-8000-000000000008",
    "label": "Programa Exemplo / Turma Exemplo"
  },
  "revision": 1,
  "enrolled": true,
  "assigned": false,
  "baseline_linked": false,
  "capacity": {
    "limit": 30,
    "occupancy": 0,
    "warning": false,
    "policy": "soft_alert"
  },
  "history": [
    {
      "action": "enroll",
      "reason": "Matrícula solicitada pelo operador.",
      "actor_label": "00000000-0000-4000-8000-000000000014",
      "occurred_at": "2026-10-13T12:00:00Z"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Cadastro exige convite de ativação verificada. |
| 403 | Confirme a identidade por busca exata antes do vínculo. |
| 403 | Convite de ativação inválido ou expirado. |
| 403 | Operador não autorizado neste programa. |
| 404 | Contexto indisponível. |
| 404 | Operação indisponível. |
| 404 | Pessoa não localizada. |
| 409 | Conflito de cadastro ou operação. Consulte novamente. |
| 409 | Contexto mudou; consulte novamente. |
| 409 | Curso não ofertado no programa. |
| 409 | Edição ou vínculo inconsistente. |
| 409 | Linhagem divergente. |
| 409 | Matrícula ativa necessária. |
| 409 | Matrícula inativa exige revisão específica. |
| 409 | Outra operação alterou os vínculos; consulte novamente. |
| 409 | Replay divergente. |
| 409 | Turma encerrada. |
| 409 | Turma sem edição fixada. |
| 409 | Usuário já cadastrado. |
| 409 | Vínculo de programa inativo exige revisão específica. |
| 409 | Vínculo não existe. |
| 422 | A senha deve ter entre 12 e 128 caracteres. |
| 422 | CPF inválido. |
| 422 | Cadastro inválido. |
| 422 | Comando inválido. |
| 422 | Nome inválido. |
| 422 | Telefone inválido. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-126"></a>

## `POST /operations/{class_id}/inspect`

Inspect. Fonte: [api/app/operator_operations.py:181](../../api/app/operator_operations.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator, coordinator ou admin. Papel global admin sem vínculo de programa não autoriza.

**Comportamento:** Consulta identidade e vínculos acadêmicos. Pessoa ainda fora do programa exige identity_proof de busca exata; resposta inclui revisão, histórico e aviso de capacidade.

**Flags/gates:** `OPERATOR_OPERATIONS_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [PersonLookup](SCHEMAS.md#schema-PersonLookup). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/operations/00000000-0000-4000-8000-000000000003/inspect" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"person_id": "00000000-0000-4000-8000-000000000004"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige OPERATOR_OPERATIONS_ENABLED=true e vínculo ativo autorizado no programa. Com a flag desligada responde 404: Operação indisponível.

```json
{
  "person": {
    "id": "00000000-0000-4000-8000-000000000004",
    "name": "Pessoa Exemplo"
  },
  "scope": {
    "institution_id": "00000000-0000-4000-8000-000000000001",
    "program_id": "00000000-0000-4000-8000-000000000002",
    "course_id": "curso-exemplo",
    "class_id": "00000000-0000-4000-8000-000000000003",
    "version_id": "00000000-0000-4000-8000-000000000008",
    "label": "Programa Exemplo / Turma Exemplo"
  },
  "revision": 0,
  "enrolled": false,
  "assigned": false,
  "baseline_linked": false,
  "capacity": {
    "limit": 30,
    "occupancy": 0,
    "warning": false,
    "policy": "soft_alert"
  },
  "history": []
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Confirme a identidade por busca exata antes do vínculo. |
| 403 | Operador não autorizado neste programa. |
| 404 | Contexto indisponível. |
| 404 | Operação indisponível. |
| 404 | Pessoa não localizada. |
| 409 | Turma sem edição fixada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-127"></a>

## `POST /operations/{class_id}/search`

Search. Fonte: [api/app/operator_operations.py:164](../../api/app/operator_operations.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; participação ativa no programa com papel program_operator, coordinator ou admin. Papel global admin sem vínculo de programa não autoriza.

**Comportamento:** Busca CPF exato em contas existentes ou nome somente no programa; devolve identity_proof com validade de dez minutos, vinculado ao operador/programa/pessoa. Não retorna CPF nem senha.

**Flags/gates:** `OPERATOR_OPERATIONS_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [Search](SCHEMAS.md#schema-Search). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request POST "${TDS_API_BASE}/operations/00000000-0000-4000-8000-000000000003/search" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"query": "qa-example"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige OPERATOR_OPERATIONS_ENABLED=true e vínculo ativo autorizado no programa. Com a flag desligada responde 404: Operação indisponível. identity_proof real é um JWT de dez minutos vinculado a pessoa, operador e programa; o texto de exemplo não é uma prova válida.

```json
{
  "people": [
    {
      "id": "00000000-0000-4000-8000-000000000004",
      "name": "Pessoa Exemplo",
      "identity_proof": "PROVA_SINTETICA_NAO_UTILIZAVEL"
    }
  ]
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Operador não autorizado neste programa. |
| 404 | Contexto indisponível. |
| 404 | Operação indisponível. |
| 409 | Turma sem edição fixada. |
| 422 | CPF inválido. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-128"></a>

## `PUT /admin/programs/{program_id}/courses/{course_id}/workload`

Update Workload. Fonte: [api/app/organizations.py:184](../../api/app/organizations.py).

**Autenticação:** Bearer obrigatório; papel global: admin.

**Permissão:** Token Bearer com papel global admin.

**Comportamento:** Atualiza carga prevista da oferta em horas, armazenada em segundos; oferta inexistente retorna 404. Carga formal não equivale a tempo medido.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `program_id` | path | sim | string | — |
| `course_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [WorkloadUpdate](SCHEMAS.md#schema-WorkloadUpdate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request PUT "${TDS_API_BASE}/admin/programs/00000000-0000-4000-8000-000000000002/courses/curso-qa/workload" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"planned_hours": 1.0}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado.

```json
{
  "program_id": "00000000-0000-4000-8000-000000000002",
  "course_id": "curso-exemplo",
  "planned_hours": 80.0
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 404 | Oferta de curso não encontrada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-129"></a>

## `PUT /assessment-attempts/{attempt_id}`

Upsert Attempt. Fonte: [api/app/assessment_sync.py:344](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. practice exige papel global student e matrícula legado ativa em curso ativo; published_block exige matrícula contextual própria ativa e edição fixada, sem depender do papel global.

**Comportamento:** score deve ser zero: servidor calcula a nota. Nova tentativa começa na revisão 1 e retorna 201; replay idêntico retorna 200. Atualização exige revisão consecutiva e timestamp não regressivo; tentativa concluída é imutável. published_block exige ID canônico, contexto exato e conteúdo editorial do servidor; conclusão grava evidência determinística na mesma transação.

**Flags/gates:** `LEARNING_CONTEXT_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `attempt_id` | path | sim | string | minLength=1; maxLength=180; pattern="^[A-Za-z0-9][A-Za-z0-9_.:-]*$" |
| `authorization` | header | não | string / null | — |

**Body JSON:** [AssessmentAttemptUpsert](SCHEMAS.md#schema-AssessmentAttemptUpsert). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request PUT "${TDS_API_BASE}/assessment-attempts/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"assessment_content_id": "qa-assessment-content", "completed": false, "course_id": "curso-exemplo", "current_index": 0, "mode": "quiz", "origin": "practice", "remaining_seconds": 0, "revision": 1, "score": 0, "topic": "Tema sintético", "updated_at": "2026-10-01T12:00:00Z"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentAttemptResponse](SCHEMAS.md#schema-AssessmentAttemptResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "course_id": "curso-exemplo",
  "origin": "practice",
  "topic": "Tema sintético",
  "mode": "quiz",
  "revision": 1,
  "current_index": 0,
  "remaining_seconds": 0,
  "completed": false,
  "score": 0,
  "updated_at": "2026-10-01T12:00:00Z",
  "attempt_id": "00000000-0000-4000-8000-000000000001"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Acesso não autorizado para esta função. |
| 403 | Matrícula ativa no curso é obrigatória. |
| 403 | Matrícula e vínculo ativos são necessários. |
| 403 | Vínculo contextual inativo ou inconsistente. |
| 404 | Atividades dinâmicas contextuais não habilitadas neste ambiente. |
| 404 | Bloco publicado não encontrado. |
| 404 | Conteúdo de avaliação não encontrado. |
| 404 | Tentativa não encontrada. |
| 404 | Turma não encontrada. |
| 409 | A edição desta turma precisa ser conferida pela equipe. |
| 409 | A edição fixada da turma não está disponível. |
| 409 | A linhagem da matrícula precisa ser conferida pela equipe. |
| 409 | A matrícula contextual precisa ser reconciliada pela equipe. |
| 409 | Expressão: {'code': 'assessment_completion_evidence_conflict'} |
| 409 | Expressão: {'code': 'assessment_content_identity_conflict'} |
| 409 | Expressão: {'code': 'attempt_identity_conflict', 'current_revision': existing.revision} |
| 409 | Expressão: {'code': 'canonical_attempt_id_required', 'expected_attempt_id': expected_attempt_id} |
| 409 | Expressão: {'code': 'completed_attempt', 'current_revision': existing.revision} |
| 409 | Expressão: {'code': 'learning_context_conflict'} |
| 409 | Expressão: {'code': 'published_block_attempt_exists', 'attempt_id': record.attempt_id, 'current_revision': record.revision} |
| 409 | Expressão: {'code': 'published_block_content_conflict'} |
| 409 | Expressão: {'code': 'published_block_content_is_server_owned'} |
| 409 | Expressão: {'code': 'published_block_identity_conflict'} |
| 409 | Expressão: {'code': 'published_block_snapshot_conflict'} |
| 409 | Expressão: {'code': 'revision_conflict', 'current_revision': current_revision, 'expected_revision': current_revision + 1} |
| 409 | Expressão: {'code': 'updated_at_conflict', 'current_revision': existing.revision, 'current_updated_at': existing_updated_at.isoformat()} |
| 409 | Quiz publicado não possui gabarito válido. |
| 409 | Snapshot publicado possui alternativas inválidas. |
| 409 | Snapshot publicado possui estrutura inválida. |
| 409 | Snapshot publicado possui texto inválido. |
| 409 | Tentativa não pôde ser recuperada após atualização. |
| 422 | Conclusão do bloco publicado exige uma resposta. |
| 422 | Expressão: {'code': 'assessment_content_required'} |
| 422 | Expressão: {'code': 'future_updated_at', 'server_time': server_time.isoformat().replace('+00:00', 'Z'), 'max_future_seconds': 300} |
| 422 | Expressão: {'code': 'published_block_content_is_server_owned'} |
| 422 | O bloco publicado não é uma atividade suportada. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 422 | answers referencia questão/alternativa inexistente. |
| 422 | current_index fora do conteúdo versionado. |
| 422 | marked referencia questão inexistente. |
| 422 | remaining_seconds excede a duração versionada. |
| 422 | score é calculado pelo servidor; envie zero. |

<a id="operacao-130"></a>

## `PUT /assessment-contents/{content_id}`

Register Assessment Content. Fonte: [api/app/assessment_sync.py:257](../../api/app/assessment_sync.py).

**Autenticação:** Bearer obrigatório; papel global: student.

**Permissão:** Token Bearer com papel global student; acesso somente aos dados do próprio titular. Exige curso ativo e matrícula legado ativa no curso.

**Comportamento:** Cria conteúdo practice imutável pertencente ao titular. ID publicado reservado é recusado. Primeiro PUT retorna 201; mesmo digest 200; digest divergente 409. Preview omite gabarito.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `content_id` | path | sim | string | minLength=1; maxLength=180; pattern="^[A-Za-z0-9][A-Za-z0-9_.:-]*$" |
| `authorization` | header | não | string / null | — |

**Body JSON:** [AssessmentContentUpsert](SCHEMAS.md#schema-AssessmentContentUpsert). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request PUT "${TDS_API_BASE}/assessment-contents/00000000-0000-4000-8000-000000000001" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"course_id": "curso-exemplo", "duration_seconds": 0, "mode": "quiz", "questions": [{"correct_index": 0, "explanation": "", "options": ["qa-example", "qa-example"], "question": "Questão sintética?", "topic": "Tema sintético"}], "title": "Curso Sintético QA", "topic": "Tema sintético"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [AssessmentContentResponse](SCHEMAS.md#schema-AssessmentContentResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **201**. Exemplo sintético derivado do comportamento da rota e do serializer, sem chamada à API. IDs e pré-condições representam fixtures próprias em ambiente autorizado; não demonstram estado real de produção. Conteúdo de prática novo retorna 201; replay idêntico retorna 200. questions contém apenas question/options/topic e answer_key é null; correct_index/explanation enviados no request não vazam na resposta.

```json
{
  "assessment_content_id": "00000000-0000-4000-8000-000000000001",
  "course_id": "curso-exemplo",
  "topic": "Tema sintético",
  "mode": "quiz",
  "title": "Curso Sintético QA",
  "duration_seconds": 0,
  "questions": [
    {
      "question": "Questão sintética?",
      "options": [
        "qa-example",
        "qa-example"
      ],
      "topic": "Tema sintético"
    }
  ],
  "answer_key": null,
  "created_at": "2026-10-13T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula ativa no curso é obrigatória. |
| 404 | Conteúdo de avaliação não encontrado. |
| 409 | Expressão: {'code': 'assessment_content_immutable'} |
| 422 | Expressão: {'code': 'assessment_content_namespace_reserved'} |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-131"></a>

## `PUT /classes/{class_id}/certificate-policy-candidate`

Configure Policy. Fonte: [api/app/certificate_policy.py:83](../../api/app/certificate_policy.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou participação ativa coordinator/admin no programa da oferta.

**Comportamento:** Somente development. Configura política imutável da edição com 80 horas formais, encontros/checkpoints distintos e responsável autorizado. Mesma política retorna documento; mudança retroativa ou transporte anterior sem reconciliação retorna 409. Só assessment possui adaptador determinístico nesta versão.

**Flags/gates:** `CERTIFICATE_CANDIDATE_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [PolicyCreate](SCHEMAS.md#schema-PolicyCreate). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request PUT "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/certificate-policy-candidate" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"checkpoints": [{"id": "00000000-0000-4000-8000-000000000001", "kind": "assessment", "source_id": "00000000-0000-4000-8000-000000000001"}], "course_version_id": "00000000-0000-4000-8000-000000000008", "formal_hours": 80, "operational_owner_id": "00000000-0000-4000-8000-000000000001", "session_ids": ["00000000-0000-4000-8000-000000000001"]}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **503**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Resposta padrão e em staging/produção. Contrato institucional candidato exige TUTOR_ENVIRONMENT=development e CERTIFICATE_CANDIDATE_ENABLED=true, autorização contextual e política imutável reconciliada. A conclusão de todos os checkpoints também depende do transporte candidato. Provas sintéticas não liberam emissão institucional final.

```json
{
  "detail": "Contrato candidato desativado neste ambiente."
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Configuração exige coordenação autorizada da oferta. |
| 409 | Política fixada; não alterar retroativamente a trilha/denominador. |
| 409 | Transporte anterior precisa ser reconciliado antes de configurar nova regra. |
| 422 | Edição configurada diverge da turma. |
| 422 | Encontro configurado não pertence à oferta. |
| 422 | Fonte do checkpoint precisa ser editorial e da oferta. |
| 422 | Política exige edição publicada ou arquivada da oferta. |
| 422 | Representação determinística deste tipo de checkpoint ainda não suportada. |
| 422 | Responsável operacional autorizado precisa ser identificado. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
| 503 | Contrato candidato desativado neste ambiente. |

<a id="operacao-132"></a>

## `PUT /classes/{class_id}/students/{user_id}`

Include Student. Fonte: [api/app/classrooms.py:358](../../api/app/classrooms.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou instrutor designado com participação ativa teacher/coordinator/admin no programa e vínculo contextual docente ativo quando existente. Monitor isoladamente não autoriza.

**Comportamento:** Inclui ou reativa vínculo de aluno com matrícula ativa no programa/curso. Vínculo já ativo retorna representação existente; turma closed é recusada. Capacidade 30 é referência indicativa, não limite bloqueante.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `user_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

### Exemplo de requisição

```bash
curl --request PUT "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/students/00000000-0000-4000-8000-000000000004" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | object |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Operação idempotente para inclusão autorizada em turma aberta; preserva vínculo contextual e alertas de capacidade.

```json
{
  "class_id": "00000000-0000-4000-8000-000000000003",
  "user_id": "00000000-0000-4000-8000-000000000004",
  "status": "active",
  "occupancy": 1,
  "capacity_warning": false
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 404 | Turma não encontrada. |
| 409 | Expressão: detail |
| 409 | Expressão: f'Esta turma está encerrada e não pode receber {member_type}.' |
| 409 | Matrícula contextual inconsistente; confira a edição da turma. |
| 422 | Estudante não possui matrícula ativa para esta turma. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-133"></a>

## `PUT /classes/{class_id}/students/{user_id}/baseline`

Put Baseline. Fonte: [api/app/student_followup.py:174](../../api/app/student_followup.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer; admin global ou equipe vinculada à turma. Instrutor designado exige participação ativa teacher/coordinator/admin no programa; monitor atribuído exige monitor/teacher/coordinator/admin ativo. Vínculo contextual de equipe, quando existente, precisa estar ativo. Aluno alvo precisa ter matrícula ativa e consistente.

**Comportamento:** Concilia referência de baseline com revisão, motivo e idempotency_key; referência reservada a outra pessoa, mudança da linhagem e conflito de revisão retornam 409. Não consulta o documento externo. bi_record_id explicitamente enviado exige JOURNEY_TRACEABILITY_ENABLED.

**Flags/gates:** `JOURNEY_TRACEABILITY_ENABLED`

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `class_id` | path | sim | string | — |
| `user_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [BaselinePut](SCHEMAS.md#schema-BaselinePut). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request PUT "${TDS_API_BASE}/classes/00000000-0000-4000-8000-000000000003/students/00000000-0000-4000-8000-000000000004/baseline" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"baseline_date": "2026-10-01", "expected_revision": 0, "idempotency_key": "qa-command-20261013-0001", "reason": "Validação com dados sintéticos", "record_id": "00000000-0000-4000-8000-000000000001", "source": "app"}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | Sem schema JSON declarado. |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |

Esta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.

### Exemplo de resposta

HTTP **200**. Exemplo ilustrativo derivado do serializer no código; dados inteiramente sintéticos. Os IDs representam fixtures que precisam existir em ambiente autorizado. Exige JOURNEY_TRACEABILITY_ENABLED=true; em estado desligado responde 404: Vínculo de rastreio ainda não habilitado. Não consulta a fonte externa; registra referência humana auditável.

```json
{
  "id": "00000000-0000-4000-8000-000000000012",
  "class_id": "00000000-0000-4000-8000-000000000003",
  "user_id": "00000000-0000-4000-8000-000000000004",
  "enrollment_id": "00000000-0000-4000-8000-000000000007",
  "source": "forms:exemplo",
  "record_id": "baseline-exemplo-001",
  "baseline_date": "2026-10-13",
  "territory_id": "territorio-exemplo",
  "revision": 1,
  "reviewed_at": "2026-10-13T12:00:00Z",
  "reviewed_by": "00000000-0000-4000-8000-000000000005"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Equipe da turma não autorizada. |
| 403 | Vínculo ativo e consistente do estudante obrigatório. |
| 404 | Turma não encontrada. |
| 404 | Vínculo de rastreio ainda não habilitado. |
| 409 | Alteração concorrente ou referência conflitante; recarregue. |
| 409 | Idempotência divergente. |
| 409 | Inscrição do BI já reservada a outra pessoa; revisão humana necessária. |
| 409 | Matrícula alterada; associação histórica preservada. |
| 409 | Referência conflitante; recarregue. |
| 409 | Referência já vinculada; revisão humana necessária. |
| 409 | Vínculo alterado; recarregue a revisão. |
| 409 | Vínculo alterado; recarregue. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |

<a id="operacao-134"></a>

## `PUT /media/{media_id}/rating`

Rate Media. Fonte: [api/app/media.py:389](../../api/app/media.py).

**Autenticação:** Bearer obrigatório; vínculos e permissões adicionais abaixo.

**Permissão:** Token Bearer de conta existente; o papel do token deve coincidir com o papel atual no banco. Exige matrícula ativa no programa/curso da mídia e conclusão qualificada registrada para essa matrícula.

**Comportamento:** Avaliação explícita de 1 a 5; primeira gravação 201, substituição/repetição 200. Sem conclusão qualificada retorna 409. Não infere avaliação por conclusão ou evento.

**Flags/gates:** Nenhuma flag adicional.

### Parâmetros

| Nome | Local | Obrigatório | Tipo | Default / limites |
| --- | --- | --- | --- | --- |
| `media_id` | path | sim | string | — |
| `authorization` | header | não | string / null | — |

**Body JSON:** [MediaRatingRequest](SCHEMAS.md#schema-MediaRatingRequest). Todos os campos e limites estão no schema vinculado.


### Exemplo de requisição

```bash
curl --request PUT "${TDS_API_BASE}/media/00000000-0000-4000-8000-000000000001/rating" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data '{"rating": 1}'
```

### Contrato de resposta

| HTTP declarado | Descrição | Schema |
| --- | --- | --- |
| 200 | Successful Response | [MediaRatingResponse](SCHEMAS.md#schema-MediaRatingResponse) |
| 422 | Validation Error | [HTTPValidationError](SCHEMAS.md#schema-HTTPValidationError) |
### Exemplo de resposta

HTTP **200**. Exemplo sintético do modelo de resposta.

```json
{
  "media_id": "00000000-0000-4000-8000-000000000001",
  "rating": 1,
  "submitted_at": "2026-10-01T12:00:00Z",
  "updated_at": "2026-10-01T12:00:00Z"
}
```

### Status e erros

Status declarados no OpenAPI: 200, 422. As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.

| HTTP | `detail` / condição |
| --- | --- |
| 401 | Token ausente, inválido ou expirado. |
| 403 | Matrícula ativa obrigatória para avaliar. |
| 404 | Mídia não encontrada. |
| 404 | Mídia publicada não encontrada. |
| 409 | Avaliação exige conclusão qualificada da mídia. |
| 422 | Validação de path/query/body; envelope detail sanitizado. |
