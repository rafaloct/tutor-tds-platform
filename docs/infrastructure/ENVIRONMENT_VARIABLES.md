# Variáveis de Ambiente

> Somente nomes e finalidade. Valores secretos não devem ser registrados.

| Variável | Finalidade | Local |
|---|---|---|
| `TUTOR_GATEWAY_URL` | URL pública do gateway | build Flutter |
| `TUTOR_API_URL` | API opcional de catálogo e dados; vazia mantém assets locais | build Flutter |
| `TDS_ANALYTICS_WEBHOOK_URL` | webhook legado de analytics | build Flutter |
| `ANYTHING_LLM_BASE_URL` | upstream do RAG | Cloudflare Worker |
| `ANYTHING_LLM_API_KEY` | autenticação do upstream | secret Cloudflare |
| `ANYTHING_LLM_WORKSPACE` | workspace RAG | Cloudflare Worker |
| `CERTIFICATE_SIGNING_SECRET` | assinatura de certificados | secret Cloudflare |
| `ALLOWED_ORIGINS` | origens web autorizadas | Cloudflare Worker |
| `DATABASE_URL` | banco da futura API | Dokploy secret |
| `JWT_SIGNING_KEY` | assinatura de tokens | Dokploy secret |
| `GOOGLE_SERVICE_ACCOUNT` | sync com Sheets | Dokploy secret |

DeepSeek não é provider/model permitido para o Tutor TDS.
