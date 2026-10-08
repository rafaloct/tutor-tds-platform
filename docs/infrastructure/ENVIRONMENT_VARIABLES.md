# Variáveis de Ambiente

> Somente nomes e finalidade. Valores secretos não devem ser registrados.

| Variável | Finalidade | Local |
|---|---|---|
| `TUTOR_GATEWAY_URL` | URL pública do gateway | build Flutter |
| `TUTOR_API_URL` | API HTTPS obrigatória no build de produção | build Flutter |
| `PRIVACY_POLICY_URL` | política pública HTTPS | build Flutter |
| `ACCOUNT_DELETION_URL` | página externa de exclusão | build Flutter |
| `ANYTHING_LLM_BASE_URL` | upstream do RAG | Cloudflare Worker |
| `ANYTHING_LLM_API_KEY` | autenticação do upstream | secret Cloudflare |
| `ANYTHING_LLM_WORKSPACE` | workspace RAG | Cloudflare Worker |
| `CERTIFICATE_SIGNING_SECRET` | assinatura de certificados | secret Cloudflare |
| `ALLOWED_ORIGINS` | origens web autorizadas | Cloudflare Worker |
| `DATABASE_URL` | banco da API Tutor TDS | Dokploy secret |
| `PUBLIC_API_BASE_URL` | base HTTPS pública canônica da API, incluindo prefixo do reverse proxy; usada nos grants de playback | Dokploy env |
| `POSTGRES_PASSWORD` | senha do PostgreSQL dedicado à API | VPS secret |
| `JWT_SECRET` | assinatura de access tokens (mínimo 32 caracteres) | Dokploy secret |
| `CPF_PEPPER` | HMAC irreversível de CPF (mínimo 32 caracteres) | Dokploy secret |
| `ACCESS_TOKEN_MINUTES` | validade curta do access token; padrão 15 | Dokploy env |
| `REFRESH_TOKEN_DAYS` | validade do refresh token; padrão 30 | Dokploy env |
| `GOOGLE_SHEET_ID` | ID da planilha operacional | Dokploy env |
| `GOOGLE_SHEET_RANGE` | aba/range exclusiva do worker; padrão `EventosAPI!A:J` | Dokploy env |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | credencial JSON da conta de serviço do Sheets | Dokploy secret |
| `GOOGLE_SERVICE_ACCOUNT_FILE` | alternativa local por arquivo, não usada junto do JSON | arquivo montado |
| `SHEETS_PSEUDONYM_SECRET` | HMAC separado para pseudonimizar evento/usuário/sessão no Sheets; mínimo 32 caracteres | Dokploy secret |
| `SYNC_BATCH_SIZE` | eventos por lote; padrão 100 | Dokploy env |
| `SYNC_POLL_SECONDS` | intervalo ocioso; padrão 30 s | Dokploy env |
| `SYNC_MAX_ATTEMPTS` | limite de tentativas; padrão 3 | Dokploy env |
| `SYNC_LEASE_SECONDS` | recupera lote abandonado; padrão 300 s | Dokploy env |
| `CERTIFICATE_VERIFICATION_URL_PREFIX` | prefixo HTTPS autorizado do Worker/KV para registrar referências | Dokploy env |
| `CERTIFICATE_CANDIDATE_ENABLED` | opt-in do candidato de emissão; deve permanecer `false` no RC enxuto | API staging |
| `CERTIFICATE_CANDIDATE_URL` | URL HTTPS fixa do Worker candidato, exigida somente quando o opt-in estiver ativo | API staging |
| `CERTIFICATE_CANDIDATE_SECRET` | segredo HMAC compartilhado com o Worker candidato, exigido somente quando o opt-in estiver ativo | secret staging |
| `STAGING_CERTIFICATE_CANDIDATE_ENABLED` | valor do host encaminhado para `CERTIFICATE_CANDIDATE_ENABLED`; padrão `false` | Dokploy staging |
| `STAGING_CERTIFICATE_CANDIDATE_URL` | valor do host encaminhado para a URL candidata; vazio com a flag desligada | Dokploy staging |
| `STAGING_CERTIFICATE_CANDIDATE_SECRET` | valor do host encaminhado para o HMAC candidato; vazio com a flag desligada | secret Dokploy staging |
| `STAGING_TRAEFIK_ENABLED` | publica opcionalmente a API staging via Traefik; padrão `false` | Dokploy staging |
| `STAGING_PUBLIC_HOST` | host HTTPS compartilhado de staging | Dokploy staging |
| `STAGING_PUBLIC_PATH` | prefixo exclusivo; padrão `/tutor-staging-api` | Dokploy staging |
| `STAGING_PUBLIC_API_BASE_URL` | base HTTPS completa do staging; deve corresponder ao host/path públicos | Dokploy staging |
| `STAGING_SHEETS_SYNC_ENABLED` | habilita explicitamente o profile `sheets-sync`; padrão `false` | Dokploy staging |
| `STAGING_GOOGLE_SHEET_ID` | ID da planilha, exigido somente com sync staging habilitado | Dokploy staging |
| `STAGING_GOOGLE_SERVICE_ACCOUNT_JSON` | credencial JSON real, exigida somente com sync staging habilitado | secret Dokploy staging |
| `STAGING_SHEETS_PSEUDONYM_SECRET` | HMAC exclusivo do staging, mínimo 32 caracteres | secret Dokploy staging |
| `TUTOR_ENVIRONMENT` | deve ser `staging` para liberar o seed sintético | execução isolada do seed |
| `STAGING_SEED_CONFIRM` | frase exata de confirmação do seed | arquivo local do seed no host |
| `STAGING_SEED_{ROLE}_{CPF,PHONE,PASSWORD}` | credenciais sintéticas de `ADMIN`, `TEACHER`, `MONITOR` e `STUDENT` | arquivo local do seed no host |
| `STAGING_SEED_CHECKIN_TOKEN` | token sintético inicial da sessão de evidência | arquivo local do seed no host |
| `CLOUDFLARE_STREAM_DELIVERY_BASE_URL` | base pública de entrega Stream; sem token administrativo | Dokploy env |
| `COMMERCIAL_SIMULATION_ENABLED` | expõe ledger exclusivamente simulado; padrão `false` | Dokploy env |
| `PAYMENT_ADAPTER` | deve permanecer `disabled` nesta fase | Dokploy env |

DeepSeek não é provider/model permitido para o Tutor TDS.

No PWA, o armazenamento seguro de tokens exige que o aplicativo seja servido
por HTTPS (localhost é permitido apenas para desenvolvimento).
