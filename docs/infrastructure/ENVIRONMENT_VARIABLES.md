# Variáveis de Ambiente

> Somente nomes e finalidade. Valores secretos não devem ser registrados.

| Variável | Finalidade | Local |
|---|---|---|
| `TUTOR_GATEWAY_URL` | URL pública do gateway | build Flutter |
| `TUTOR_API_URL` | API opcional de catálogo e conta; vazia mantém modo offline | build Flutter |
| `TDS_ANALYTICS_WEBHOOK_URL` | webhook legado de analytics | build Flutter |
| `ANYTHING_LLM_BASE_URL` | upstream do RAG | Cloudflare Worker |
| `ANYTHING_LLM_API_KEY` | autenticação do upstream | secret Cloudflare |
| `ANYTHING_LLM_WORKSPACE` | workspace RAG | Cloudflare Worker |
| `CERTIFICATE_SIGNING_SECRET` | assinatura de certificados | secret Cloudflare |
| `ALLOWED_ORIGINS` | origens web autorizadas | Cloudflare Worker |
| `DATABASE_URL` | banco da API Tutor TDS | Dokploy secret |
| `JWT_SECRET` | assinatura de access tokens (mínimo 32 caracteres) | Dokploy secret |
| `CPF_PEPPER` | HMAC irreversível de CPF (mínimo 32 caracteres) | Dokploy secret |
| `ACCESS_TOKEN_MINUTES` | validade curta do access token; padrão 15 | Dokploy env |
| `REFRESH_TOKEN_DAYS` | validade do refresh token; padrão 30 | Dokploy env |
| `GOOGLE_SERVICE_ACCOUNT` | sync com Sheets | Dokploy secret |

DeepSeek não é provider/model permitido para o Tutor TDS.

No PWA, o armazenamento seguro de tokens exige que o aplicativo seja servido
por HTTPS (localhost é permitido apenas para desenvolvimento).
