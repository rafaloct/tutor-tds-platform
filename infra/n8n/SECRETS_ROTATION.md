# Rotação de segredos — Tutor TDS (kreativ-n8n / provedores)

Estado após a sessão de refatoração (OBSERVED vs pendente).

## JÁ ROTACIONADOS nesta sessão (contidos ao escopo TDS)

| Segredo | Onde vive | Ação feita | Consumidores |
|---|---|---|---|
| `TDS_SESSION_SALT` | n8n `variables` (`$vars`) | novo hex 64 | só `Hash Sessao` no worker |
| AnythingLLM dev key (`kreativ-rag`) | tabela `api_keys` do container `kreativ-rag` | mint nova via prisma + revoke da antiga (`W5M4…`) | cred `tdsAllmCred001` → worker + AI helper |
| Chatwoot `api_access_token` | `access_tokens` (User 1) | novo token base58(24) + delete do `w8BYLTQc…` | cred `tdsCwCred001xx` → fluxos Chatwoot |
| Evolution `apikey` (valor) | cred `tdsEvoCred001x` | corrigida p/ `AUTHENTICATION_API_KEY` global | 9 workflows TDS |

## PENDENTES — rotação exige ação humana / janela

### `AUTHENTICATION_API_KEY` (kreativ-evolution) — blast radius: ALTO
- Fonte: env do container (compose `projeto-tds` / `kmj9v7`,
  `/etc/dokploy/compose/compose-parse-primary-array-kmj9v7/code/docker/docker-compose.yml:213`).
- Consumidores dentro do n8n: 9 workflows via `tdsEvoCred001x` (atualizam
  sozinhos ao trocar a credencial).
- **UNKNOWN**: consumidores externos (Manager UI, outras integrações fora
  do n8n). Rotacionar = atualizar env no registro Dokploy `projeto-tds` +
  `compose.deploy` (recria o stack → ~30-60s downtime por serviço).
- Depois: reimportar `tdsEvoCred001x` com a nova key.

### `N8N_ENCRYPTION_KEY` (kreativ-n8n) — blast radius: ALTO
- Rotacionar **quebra a decriptografia de TODAS as credentials** (TDS e
  não-TDS: SMTP, Postgres, etc.).
- Procedimento: (1) inventariar `credentials_entity` (backup antes),
  (2) nova key no env do n8n, (3) restart, (4) `n8n import:credentials`
  de TODAS as credenciais com valores novos.

### `DB_POSTGRESDB_PASSWORD` (kreativ-postgres) — blast radius: ALTO
- Consumidores: n8n, Chatwoot, sync workers — coordenar troca simultânea.

### Provider-side (console humano, sem API)
- Meta Graph `WA_CLOUD_TOKEN` / `tdsMetaCred001` — Meta Business Suite.
- OpenRouter keys (`sk-or-…`) — painel OpenRouter.
- SMTP `EMAIL_PASSWORD` — provedor de e-mail.
- Supabase `service_role` JWT (`tdsSupaCred001`) — projeto Supabase.

## Regra para novos segredos

1. **Nunca** literal em nó/body/header/URL/code de workflow.
2. Consumidor n8n → credential nativa (`tds*Cred*`) ou `$vars.*` para
   valores não-credenciais.
3. Consumidor de container → env do Dokploy (campo `env` do compose
   record) — **não** hardcode no `docker-compose.yml` versionado.
4. Export de workflow → verificar 0 hits nos padrões (bearer/sk-/EAA/JWT).
