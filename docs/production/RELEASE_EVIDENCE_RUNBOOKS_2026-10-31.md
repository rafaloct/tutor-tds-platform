# Roteiros E2E físicos — gates pendentes de release 1.4.0+13

**Status:** preparados, aguardando execução humana em dispositivo Xiaomi.
**Data:** 2026-10-31. **Autor:** preparação automatizada para execução POCO.

Gates que estes roteiros destravam em
`cartilhas_app/release/release_status.json`:

| Gate | Estado | Roteiro |
|---|---|---|
| `certificate_human_approval_e2e` | pending | Seção A |
| `evidence_offline_xiaomi` | pending | Seção B |

Após cada execução aprovada, preencher `verified_at`, `evidence` e
`evidence_sha256` no `release_status.json` (modelo ao final). Somente quando
**todos** os `required_physical_evidence` estiverem `passed`, flipar
`release_build_allowed: true` e rodar `C:\Users\Usuario\tds-build-aab.ps1`.

---

## 0. Precondições comuns

| Item | Valor |
|---|---|
| Dispositivo | Xiaomi `2311DRK48G` (o mesmo dos gates anteriores) ou equivalente físico |
| Host | `DESKTOP-8T5DRBS` com ADB no PATH (`flutter-3.44.9` validado) |
| API | **staging** `https://tutor-tds-staging.fastapicloud.dev` — nunca produção |
| Pacote QA | debug, `applicationIdSuffix=.dev.dynamicqa.r<run_id>` (mesmo padrão dos gates aprovados) |
| Contas | contas QA sintéticas do staging (7 preservadas); instrutor + aluno |
| `run_id` | `powershell: [guid]::NewGuid().ToString("N")` — gerar novo por roteiro |

Build do pacote QA (no desktop, dentro do worktree ou checkout atual):

```powershell
cd <checkout>\cartilhas_app
C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat build apk --debug `
  --dart-define=APP_ID_SUFFIX=.dev.dynamicqa.r<run_id>
```

Instalar: `adb install -r build\app\outputs\flutter-apk\app-debug.apk`
Registrar `apk_sha256` (ver `sha256sum` / `Get-FileHash`) no JSON final.

**Regra de ouro:** nenhum passo pode tocar produção, conta real ou dados de
aluno real. Cada fase precisa de artefato capturado (screenshot +
`adb shell`/`curl` de verificação) em
`docs/production/evidence/<gate>-<run_id>-<fase>.json`.

---

## A. `certificate_human_approval_e2e`

**Objetivo do gate:** provar em dispositivo físico o fluxo pedido → revisão
humana por matrícula/edição → emissão autenticada API→Worker→KV → carteira
isolada, sem confundir *aprovação humana* com *emissão*, e com certificados
legados preservados.

**Contexto já comprovado (não repetir):** Issue #68 homologou em staging
API→HMAC→Worker→KV exclusivo, contexto divergente 422, replay idempotente,
receipt autenticado e candidato fora de `GET /certificates`. Este gate é a
prova **física via app** do fluxo humano. Guard de staging exige
`CERTIFICATE_CANDIDATE_ENABLED=true` no staging — confirmar antes de começar.

### Fases

| # | Fase | Ação no dispositivo/host | Esperado | Artefato |
|---|---|---|---|---|
| A1 | `prepare` | Semear no staging: aluno QA com matrícula/edição elegível + candidato de certificado pendente | Registros existem; nada emitido | `cert-<run>-prepare.json` |
| A2 | `request` | No app: aluno abre área de certificado e pede emissão | Pedido registrado com status `PENDING_INSTRUCTOR_VALIDATION`; **zero emissão** | screenshot + `GET` do pedido |
| A3 | `instructor_review` | Conta QA de instrutor revisa e aprova o pedido **daquela matrícula/edição** | Status `PENDING_COORDINATOR_SIGNATURE`; aprovação ≠ emissão | screenshot + registro |
| A4 | `coordinator_sign` | Conta QA de coordenador assina | Lifecycle avança para emissão; dispatch `pending_dispatch` criado | screenshot + registro |
| A5 | `worker_emission` | Host: disparar/observar dispatch API→Worker→KV de staging | Receipt autenticado gravado; mesma emissão lógica em replay (idempotente) | response + receipt JSON |
| A6 | `wallet_isolation` | No app: abrir carteira do aluno | Certificado aparece na **carteira isolada** do aluno; `GET /certificates` oficial não lista candidato | screenshot carteira |
| A7 | `legacy_preserved` | Conferir lista de certificados legados do aluno | Legados intactos, nenhum sobrescrito/revogado | diff antes/depois |
| A8 | `wrong_scope` | Repetir aprovação para matrícula/edição divergente (se semeável) | 422 / recusa fechada | response de erro |

**Critério de aprovação:** todas as fases passam; emissão ocorre somente após
assinatura humana da matrícula/edição correta; replay não duplica; legado
intacto.

---

## B. `evidence_offline_xiaomi`

**Objetivo do gate:** provar que o envio de evidência sobrevive a perda de
rede com retry **idempotente** (sem duplicar registro) e que a reabertura
usa **novo código** — no Xiaomi.

API envolvida: `POST /classes/{class_id}/evidence-imports`,
`GET .../{import_id}`, `POST .../evidence/{evidence_id}/review`.

### Fases

| # | Fase | Ação | Esperado | Artefato |
|---|---|---|---|---|
| B1 | `baseline` | App online: abrir turma QA, listar evidências existentes | Lista `n` registros | `evid-<run>-baseline.json` |
| B2 | `submit_online` | Submeter evidência simples online | 201 + `import_id`; conta vira `n+1` | response |
| B3 | `offline_queue` | **Modo avião** → submeter segunda evidência | UI confirma enfileiramento local, sem erro fatal | screenshot |
| B4 | `offline_retry` | Tentar reenviar ainda offline | Retry seguro, **nenhuma duplicata local** | log/queue state |
| B5 | `reconnect` | Restaurar rede → outbox drena | `import_id` único no servidor; **conta = `n+2`** (não `n+3`) | `GET` da lista |
| B6 | `idempotent_replay` | Forçar reenvio do mesmo payload (replay) | Servidor devolve a mesma import, sem novo registro | response/DB check |
| B7 | `cold_reopen` | Forçar fechamento do app → reabrir frio | Sessão, turma e evidências íntegras; nada perdido | screenshot |
| B8 | `new_code` | Reabrir com novo código/refresh do fluxo de verificação | Novo código aceito/fluxo correto; sem reuse de código expirado | log + screenshot |

**Critério de aprovação:** evidência offline é entregue **exatamente uma
vez** após reconexão; replay não cria registro novo; cold restart preserva
estado; novo código funciona sem reuso indevido.

---

## C. Modelo de JSON de evidência (preencher por roteiro)

```json
{
  "status": "<GATE>_PHYSICAL_STAGING_PASSED",
  "release_gate": "certificate_human_approval_e2e | evidence_offline_xiaomi",
  "verified_at": "<ISO 8601 UTC>",
  "run_id": "<guid>",
  "device": "<serial adb>",
  "device_model": "2311DRK48G",
  "app_package": "com.tutortds_cartilhas.dev.dynamicqa.r<run_id>",
  "apk_sha256": "<hash do apk instalado>",
  "api_url": "https://tutor-tds-staging.fastapicloud.dev",
  "phases": { "<fase>": {"result": "passed", "artifact": "evidence/<arquivo>"} },
  "scope": "POCO físico; staging sintético; não libera release por si só"
}
```

Atualização do `release_status.json` após aprovação:

```json
{ "id": "certificate_human_approval_e2e", "status": "passed",
  "verified_at": "...", "evidence": "docs/production/evidence/<arquivo>.json",
  "evidence_sha256": "<sha256 do arquivo>" }
```

## D. Limites

- Estes roteiros **não** autorizam release; só completam evidências do gate.
- Se alguma fase falhar, registrar Observed/Expected/Boundary/Evidence/Root
  cause em `BOUNDARY_DIAGNOSTICS.md` — não contornar o gate.
- AAB assinado somente após `release_build_allowed: true` + gates completos.
