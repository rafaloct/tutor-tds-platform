# n8n — Workflows TDS (infra as code)

Exports versionados dos workflows TDS da instância `kreativ-n8n`
(`https://n8n.ipexdesenvolvimento.cloud`). Gerados via
`n8n export:workflow --all` + filtro por ids TDS. **Não contêm segredos** —
credenciais aparecem apenas como referência `{id, name}`.

## Arquitetura RAG (WhatsApp ↔ AnythingLLM)

```
Evolution webhook ──POST──▶ tds-evo-wa (200 imediato)
                              │ Extrair Dados (filtra fromMe/grupo/vazio)
                              │ Dedup msg_id (INSERT tds_dedup ON CONFLICT)
                              │ RAG Worker (executeWorkflow, onError→fallback)
                              ▼
                    ┌─── tds-rag-worker ───┐
                    │ Entrada (passthrough)│
                    │ Sanitizar PII        │  CPF/e-mail/telefone → [*_removido]
                    │ Hash Sessao (Crypto) │  SHA256(user_key + $vars.TDS_SESSION_SALT)
                    │ Consultar AnythingLLM│  POST /api/v1/workspace/{ws}/chat (15s, cred tdsAllmCred001)
                    │ Normalizar           │  strip <think>, métricas, ok/err
                    │ Telemetria           │  POST PocketBase rag_interactions (onError: continua)
                    │ Saida                │
                    └──────────────────────┘
                              │ ok? ──não──▶ Enviar Fallback (msg amigável)
                              ▼ sim
                        Enviar Resposta (Evolution sendText, cred tdsEvoCred001x)
```

- `tds-error-fallback` — Error Trigger global; captura falhas de qualquer
  execução TDS (log/telemetria; a msg amigável ao usuário sai pelo ramo
  `RAG ok?=false` do workflow de origem).
- `tds-telemetry` — webhook `POST /webhook/tds-telemetry`, grava em
  `rag_interactions` (fire-and-forget).
- Chatwoot RAG Flow usa o mesmo worker; confiança baixa → handoff humano.
  **Rotação de chave global removida** (não muta `system/update-env`).

## Credenciais n8n exigidas (ids)

| id | nome | tipo | uso |
|---|---|---|---|
| `tdsAllmCred001` | TDS AnythingLLM Bearer | httpHeaderAuth | `Authorization: Bearer <anyllm-key>` |
| `tdsEvoCred001x` | TDS Evolution apikey | httpHeaderAuth | `apikey: <global-api-key>` |
| `tdsCwCred001xx` | TDS Chatwoot Token | httpHeaderAuth | `api_access_token` |
| `tdsMetaCred001` | TDS Meta Graph Bearer | httpHeaderAuth | `Authorization: Bearer <meta-token>` |
| `tdsSupaCred001` | TDS Supabase Headers | httpCustomAuth | apikey+Authorization JWT |

## Variáveis n8n (tabela `variables`, `$vars.*`)

| chave | uso |
|---|---|
| `TDS_SESSION_SALT` | salt do SHA256 do sessionId (LGPD — nunca enviar número cru) |

## PostgreSQL auxiliar

- `tds_dedup (msg_id text primary key)` — dedup de `key.id` Evolution (TTL
  natural via novos ids; opcionalmente limpar >7d).

## PocketBase `rag_interactions` (`:8090`, collection `pbc_3194194142`)

Campos: `ts, user_hash, channel, workspace, route, outcome, latency_ms,
chars_in, chars_out, tokens_in, tokens_out, pii_stripped, error, workflow`.
`createRule` aberto (server-side via workflow); list/view/update/delete
restritos a superuser.

## Re-importar

```bash
n8n import:workflow --input=infra/n8n/workflows/<arquivo>.json
# após import: ativar (active=true + activeVersionId=versionId) e
# publicar (workflow_published_version → novo versionId em workflow_history).
```

> ⚠ n8n 2.x executa a versão em `workflow_history` apontada por
> `activeVersionId`, **não** a row de `workflow_entity`. Update direto em
> `nodes` sem bump de `versionId` não entra no ar.
