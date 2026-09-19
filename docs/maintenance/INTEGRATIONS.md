# Tutor TDS — Mapeamento de Integrações Externas

> **Onda 0 — Auditoria Técnica**
> Data: 2026-09-19

---

## Resumo de Integrações

| Integração | Tipo | Finalidade | Configuração | Status |
|---|---|---|---|---|
| AnythingLLM | REST HTTP | Motor RAG do Tutor IA | ANYTHINGLLM_URL + KEY + WORKSPACE (no Cloudflare) | ✅ Ativo |
| Cloudflare Worker | Serverless edge | Gateway de IA + emissão de certificados | Wrangler secrets | ✅ Ativo |
| Cloudflare KV | KV Store | Armazenamento público de certificados | namespace CERTIFICATES | ✅ Ativo |
| Google Apps Script | Webhook HTTP | Analytics operacional → Sheets | URL da implantação (no app) | ✅ Ativo |
| Google Sheets | Planilha | Espelho operacional + gestão | tdsdados@gmail.com | ✅ Ativo |
| Google Play Store | Store | Distribuição do APK | com.tutortds_cartilhas | ✅ Publicado |
| Dokploy API | REST HTTP | Redeploy de containers na VPS | DOKPLOY_API_TOKEN + URL | ✅ Configurado |
| Hostinger VPS | SSH/SCP | Hospedagem de AnythingLLM + PWA | id_ed25519 | ✅ Ativo |
| Chatwoot/WhatsApp | WebView | Suporte ao usuário final | URL configurada | ✅ Ativo |
| flutter_tts | SDK nativo | Text-to-Speech pt-BR | Nativo Android | ✅ Ativo |
| speech_to_text | SDK nativo | Reconhecimento de voz | Permissão microfone | ✅ Ativo |

---

## 1. AnythingLLM (Motor de IA)

**Tipo:** API REST interna (acessada somente pelo Cloudflare Worker)
**Localização:** VPS Hostinger 46.202.150.132 (container Docker via Dokploy)
**Acesso:** NUNCA diretamente pelo app Flutter — sempre via gateway Cloudflare

**Configuração no Cloudflare (secrets):**
- `ANYTHINGLLM_URL` = configurado (URL interna da VPS)
- `ANYTHINGLLM_API_KEY` = configurado
- `ANYTHINGLLM_WORKSPACE` = configurado

**Dependências do RAG:**
- As 9 cartilhas em PDF devem estar indexadas no workspace do AnythingLLM
- Reindexação necessária quando novo conteúdo for adicionado

**Riscos:**
- Latência da VPS afeta tempo de resposta ao usuário
- Se VPS cair, o Tutor IA fica indisponível (app continua funcionando com mensagem amigável)
- Sem health check automatizado da instância AnythingLLM

---

## 2. Cloudflare Worker — tutor-tds-gateway

**Tipo:** Serverless Edge Function (Wrangler / JS)
**Repositório:** `cartilhas_app/cloudflare/tutor-tds-gateway/`

**Endpoints expostos:**

| Endpoint | Método | Descrição |
|---|---|---|
| `/health` | GET | Health check simples |
| `/v1/chat` | POST | Proxy autenticado para AnythingLLM |
| `/v1/study` | POST | Geração de material pedagógico via IA |
| `/v1/certificates` | POST | Emissão de certificado com HMAC |
| `/v1/certificates/{id}` | GET | Verificação de autenticidade (API) |
| `/verify/{id}` | GET | Página HTML pública de verificação |

**Secrets Cloudflare (não expostos):**
- `ANYTHINGLLM_URL` = configurado
- `ANYTHINGLLM_API_KEY` = configurado
- `ANYTHINGLLM_WORKSPACE` = configurado
- `CERTIFICATE_SIGNING_SECRET` = configurado
- `ALLOWED_ORIGINS` = configurado

**KV Bindings:**
- `CERTIFICATES` — armazena certificados públicos (sem CPF)

**Proteções ativas:**
- CORS com lista de origens permitidas
- Limite de tamanho do body (16.384 bytes)
- Limite de mensagem (8.000 chars)
- Timeout upstream de 25s
- Anti-duplicata de certificado via HMAC do CPF

---

## 3. Google Apps Script / Google Sheets

**Conta gestora:** tdsdados@gmail.com
**Arquivo script:** `google_apps_script.js`
**Tipo:** Web App pública (HTTP POST)

**Dados recebidos do app:**
```json
{
  "name": "Nome do Participante",
  "phone": "+55 (63) 9XXXX-XXXX",
  "cpf": "XXX.XXX.XXX-XX",
  "eventType": "STARTED|COMPLETED|QUIZ_ANSWERED|REGISTERED",
  "detail": "nome-da-cartilha",
  "adminEmail": "tdsdados@gmail.com",
  "timestamp": "2026-09-19T14:00:00.000Z"
}
```

**⚠️ RISCO LGPD:** CPF trafega em plaintext nesta integração. Avaliação pendente na Onda 1.

**Planilhas gerenciadas:**
- `Eventos` — log bruto de todos os eventos
- `Alunos` — 1 linha por CPF com timestamps e contadores
- `Por Cartilha` — métricas agregadas por cartilha

**Ações automáticas:**
- `COMPLETED` → dispara email de certificado via Gmail API para o participante (se email disponível)

---

## 4. Google Play Store

**Package:** `com.tutortds_cartilhas`
**Versão publicada atual:** 1.2.0+11
**Conta:** conta de desenvolvedor da UFT/projeto TDS
**Assinatura:** nova chave de upload criada, certificado em `upload_certificate.pem`
**AAB publicado:** `Tutor-TDS-1.2.0+11-signed.aab` (62 MB)

**⚠️ IMPORTANTE:** A chave de upload NUNCA deve ser commitada no Git.
O arquivo `android/upload-keystore.jks` e `key.properties` estão protegidos pelo `.gitignore`.

---

## 5. Hostinger VPS / Dokploy

**IP:** 46.202.150.132
**Painel:** http://46.202.150.132 (Dokploy)
**Acesso SSH configurado:** chave `~/.ssh/id_ed25519` (usada no deploy_dokploy.sh)
**Compose ID:** referenciado em `.env.deploy` (não versionado)

**Deploy atual:**
1. Build Flutter web local
2. rsync dos arquivos web para a VPS
3. POST na API do Dokploy para redeploy do compose

**Auditoria somente leitura concluída em 2026-09-19.** A topologia confirmada, os riscos e as pendências estão em `docs/infrastructure/`.

---

## 6. Integrações Futuras Planejadas

| Integração | Onda | Finalidade |
|---|---|---|
| PostgreSQL / Neon | Onda 1 | Banco relacional centralizado |
| API REST Tutor TDS | Onda 1 | Backend unificado |
| GitHub Actions | Onda 1 | CI/CD automatizado |
| Google Drive (metadados) | Onda 2 | Acervo de materiais pedagógicos |
| LearnPress (avaliar) | Onda 2 | Motor LMS editorial |
| MercadoPago / outro | Onda 4 | Pagamentos (adapter) |
| Play Integrity API | Pós Onda 5 | Verificação de integridade do APK |

---

_Atualizar quando integrações forem adicionadas, removidas ou modificadas._
