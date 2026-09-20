# Tutor TDS — Arquitetura Atual

> **Onda 0 — Auditoria Técnica**
> Data: 2026-09-19
> Agente: Antigravity (Onda 0)
> Status: ATIVO EM PRODUÇÃO (versão 1.2.0+11)

---

## Visão Geral

O **Tutor TDS** é uma plataforma educacional móvel desenvolvida pela Universidade Federal do Tocantins (UFT), destinada à qualificação profissional de beneficiários do CadÚnico no estado do Tocantins, no âmbito do Programa Territórios de Desenvolvimento Social e Inclusão Produtiva (TDS/MDS).

O aplicativo está **publicado na Google Play Store** com o package `com.tutortds_cartilhas` e possui registro de software em andamento junto ao INPI/UFT (depósito documentado em agosto de 2026).

---

## Stack Técnica Confirmada

| Camada | Tecnologia | Versão / Detalhe |
|---|---|---|
| Mobile App | Flutter + Dart | SDK Dart ^3.12.0 / Flutter 3.44.x |
| UI Design System | Material Design 3 | com suporte a tema claro/escuro |
| State Management | Provider | ^6.1.5+1 |
| Serialização | json_annotation + json_serializable | ^4.12.0 / ^6.14.0 |
| Acessibilidade | flutter_tts + speech_to_text | TTS/STT integrado |
| PDF/Impressão | pdf + printing | geração de certificados A4 landscape |
| Compartilhamento | share_plus | ^13.3.0 |
| QR Code | qr_flutter | ^4.1.0 |
| WebView | webview_flutter | ^4.13.1 |
| Armazenamento Local | shared_preferences | ^2.5.5 |
| Criptografia local | crypto (SHA-256) | ^3.0.7 |
| Web Frontend (aux) | React 18 + TypeScript + Vite | landing page complementar |
| Gateway de IA | Cloudflare Workers (JS/Wrangler) | serverless edge |
| KV Store (certificados) | Cloudflare KV | namespace `CERTIFICATES` |
| LLM / RAG | AnythingLLM | hospedado na VPS Hostinger |
| Analytics Backend | Google Apps Script | planilha tdsdados@gmail.com |
| VPS / Orquestração | Hostinger VPS + Dokploy + Docker | IP 46.202.150.132 |
| Reverse Proxy | Nginx | configurado no container |
| Android | SDK 36/36, minSDK 24, NDK 28.2 | AGP 9.0.1, Gradle 9.1.0 |

---

## Diagrama de Fluxo Atual

```
                  ┌─────────────────────────────────────────┐
                  │         USUÁRIO FINAL (Android)         │
                  │   com.tutortds_cartilhas v1.2.0+11      │
                  └──────────────┬──────────────────────────┘
                                 │
              ┌──────────────────┼─────────────────────┐
              │                  │                     │
              ▼                  ▼                     ▼
   ┌──────────────────┐ ┌──────────────────┐  ┌─────────────────────┐
   │  Conteúdo Local  │ │  Tutor IA (chat) │  │ Analytics (eventos) │
   │  (assets JSON)   │ │  /v1/chat        │  │ Google Sheets       │
   │  9 cartilhas     │ │  /v1/study       │  │ via Webhook HTTP    │
   │  estáticas no    │ │  /v1/certificates│  │ (com consentimento) │
   │  APK/AAB         │ └────────┬─────────┘  └─────────┬───────────┘
   └──────────────────┘          │                       │
                                 ▼                       ▼
                    ┌────────────────────────┐  ┌──────────────────────┐
                    │  Cloudflare Worker     │  │  Google Apps Script  │
                    │  tutor-tds-gateway     │  │  TDS Analytics       │
                    │  - CORS/auth proxy     │  │  - Aba Eventos       │
                    │  - rate limiting       │  │  - Aba Alunos        │
                    │  - HMAC signing        │  │  - Aba Por Cartilha  │
                    │  - KV certificates     │  │  - Email certificado │
                    └────────────┬───────────┘  └──────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │  VPS Hostinger         │
                    │  46.202.150.132        │
                    │  Dokploy + Docker      │
                    │  ┌──────────────────┐  │
                    │  │   AnythingLLM    │  │
                    │  │   (RAG sobre     │  │
                    │  │   9 cartilhas)   │  │
                    │  └──────────────────┘  │
                    │  ┌──────────────────┐  │
                    │  │   Flutter PWA    │  │
                    │  │   Nginx :80      │  │
                    │  └──────────────────┘  │
                    └────────────────────────┘
```

---

## Módulos do Aplicativo Flutter

### Fluxo de Navegação

```
WelcomeScreen (cadastro + LGPD)
        │
        ├─► PrivacyConsentScreen (consentimento explícito)
        │
        └─► OnboardingScreen (tutorial 3 páginas)
                │
                └─► HomeScreen (hub principal)
                        │
                        ├─► ChatExperienceScreen   (Tutor IA conversacional)
                        ├─► AIAssistantScreen       (assistente ATUI/GenUI)
                        ├─► GenUIAssistantScreen    (protocolo GenUI avançado)
                        ├─► StudyHubScreen          (Central de Estudos com IA)
                        │       ├─► FlashcardsScreen
                        │       ├─► AssessmentScreen (quiz + simulado)
                        │       └─► SummaryScreen
                        ├─► CertificateWalletScreen (carteira de certificados)
                        │       └─► CertificateDetailsScreen
                        ├─► CadUnicoScreen          (informações CadÚnico)
                        ├─► GlossaryScreen          (glossário TDS)
                        ├─► GuideScreen             (guia de uso)
                        ├─► AboutScreen             (sobre o projeto)
                        ├─► ChatwootScreen          (suporte via Chatwoot)
                        └─► SettingsScreen          (configurações)
```

### Features Implementadas e Confirmadas

| Feature | Status | Observações |
|---|---|---|
| Cadastro de usuário (nome, CPF, WhatsApp) | ✅ Produção | SharedPreferences local |
| Consentimento LGPD explícito | ✅ Produção | Bloqueia analytics se negado |
| Onboarding 3 páginas | ✅ Produção | Marcado como visto após 1ª vez |
| Catálogo de 9 cartilhas | ✅ Produção | JSON estático no APK |
| Chat interativo por seção (tipo chatbot) | ✅ Produção | ChatExperienceScreen |
| Tutor IA com RAG | ✅ Produção | Via Gateway Cloudflare → AnythingLLM |
| TTS (texto para voz) | ✅ Produção | flutter_tts, pt-BR |
| STT (voz para texto) | ✅ Produção | speech_to_text |
| GenUI / ATUI renderer | ✅ Produção | Renderização dinâmica de componentes |
| Flashcards gerados por IA | ✅ Produção | StudyAiService → /v1/study |
| Quiz com correção imediata | ✅ Produção | AssessmentScreen |
| Simulado com cronômetro | ✅ Produção | kind=exam no StudyAiService |
| Resumo rápido/detalhado por IA | ✅ Produção | SummaryScreen |
| Emissão de certificados (HMAC/SHA-256) | ✅ Produção | Via Worker, armazenado em KV |
| Carteira de certificados local | ✅ Produção | SharedPreferences + PDF local |
| PDF de certificado (A4 landscape) | ✅ Produção | CertificatePdfService |
| Compartilhamento/impressão de PDF | ✅ Produção | share_plus + printing |
| QR Code de validação | ✅ Produção | Aponta para /verify/{id} |
| Verificação online de certificado | ✅ Produção | GET /v1/certificates/{id} |
| Analytics para Google Sheets | ✅ Produção | DataSyncService → Apps Script |
| Glossário TDS | ✅ Produção | GlossaryScreen |
| Tema claro/escuro | ✅ Produção | ThemeController + SharedPreferences |
| Suporte Chatwoot/WhatsApp | ✅ Produção | WebView + ChatwootScreen |
| Informações CadÚnico | ✅ Produção | CadUnicoScreen |
| PWA / Web Flutter | ✅ Deploy VPS | web_build.tar.gz no Nginx |
| APK direto (sideload) | ✅ Hospedado | Na VPS via Nginx |

### O Que Não Existe Ainda (Gap para Demandas Futuras)

| Funcionalidade | Onda | Prioridade |
|---|---|---|
| API REST centralizada publicada (PostgreSQL) | Onda 1 | Alta |
| Autenticação JWT com RBAC | Onda 1 | Alta |
| Cursos dinâmicos (sem rebuild APK) | Onda 2 | Alta |
| LearningEvents persistidos no servidor | Onda 2 | Alta |
| Controle de 40h (planned/validated/active) | Onda 2 | Alta |
| Multi-Instituição (tenant isolado) | Onda 1/3 | Alta |
| TDS Classroom (turmas) | Onda 3 | Média |
| Painel Professor/Monitor | Onda 3 | Média |
| Sync idempotente banco → Sheets | Onda 1 | Média |
| Certificados acadêmicos verificáveis por instituição | Onda 3 | Média |
| Offline sync com fila de retry | Onda 2 | Alta |
| Creator Studio | Onda 4 | Baixa |
| Ledger financeiro | Onda 4 | Baixa |
| Integração de pagamentos | Onda 4 | Baixa |

### Fundação local da API (ainda não publicada)

A Onda 1 possui agora um projeto FastAPI isolado em `api/`, com SQLAlchemy,
Alembic, Docker Compose para PostgreSQL 16 e os endpoints iniciais
`GET /health` e `GET /courses`. A migration inicial cobre institutions,
programs, users, sessions, enrollments, learning_events, certificates e
sync_log. Essa base foi validada apenas localmente; staging, autenticação,
worker e publicação continuam pendentes.

A autenticação local da API já possui registro, login, access JWT de curta
duração e refresh token opaco com rotação. CPF é armazenado somente como
HMAC-SHA256 com pepper e senhas usam Argon2id. A integração dessa autenticação
com o Flutter ainda não foi iniciada.

A API também recebe e lista LearningEvents autenticados. A identidade vem
sempre do access token, o `event_id` é idempotente e as consultas são isoladas
por estudante. A fila Flutter permanece somente local até a integração de
autenticação no aplicativo.

O Flutter possui agora uma fundação de cliente para register, login, refresh e
`/auth/me`. Access e refresh tokens ficam somente no armazenamento seguro da
plataforma; 401 dispara no máximo uma renovação, compartilhada entre chamadas
concorrentes. O cliente ainda não está ligado à WelcomeScreen nem transmite a
fila local de eventos.

---

## Componentes de Infraestrutura

### VPS Hostinger

- **IP:** 46.202.150.132
- **Orquestração:** Dokploy
- **Serviços confirmados em 2026-09-19:**
  - AnythingLLM do Tutor TDS e uma segunda instância RAG
  - Nginx em container servindo a aplicação web
  - Dokploy, Traefik, PostgreSQL, Redis, Ollama, Chatwoot e serviços auxiliares
- **Deploy atual:** rsync + Dokploy API (via `deploy_dokploy.sh`)
- **Auditoria direta da VPS:** concluída em modo somente leitura; ver `docs/infrastructure/`.

### Cloudflare Worker — `tutor-tds-gateway`

Endpoints expostos:
- `GET /health` — health check
- `POST /v1/chat` — proxy para AnythingLLM com prompt contextualizado
- `POST /v1/study` — geração de flashcards, quiz, simulado e resumo
- `POST /v1/certificates` — emissão de certificado (HMAC + KV)
- `GET /v1/certificates/{id}` — verificação pública de autenticidade
- `GET /verify/{id}` — página HTML pública de verificação

Segredos gerenciados no Cloudflare (não expostos):
- `ANYTHINGLLM_URL` = configurado
- `ANYTHINGLLM_API_KEY` = configurado
- `ANYTHINGLLM_WORKSPACE` = configurado
- `CERTIFICATE_SIGNING_SECRET` = configurado
- `ALLOWED_ORIGINS` = configurado

---

## Dados Locais do Usuário (SharedPreferences)

| Chave | Conteúdo | Sensibilidade |
|---|---|---|
| `user_name` | Nome do participante | Moderada |
| `user_phone` | WhatsApp do participante | Alta |
| `user_cpf` | CPF (mascarado na UI) | Alta — o analytics legado ainda o envia em texto puro ao Apps Script |
| `privacy_consent` | Booleano de consentimento | Controle de analytics |
| `onboarding_seen_v1` | Booleano de tutorial visto | Baixa |
| `certificates` | JSON lista de CertificateRecord | Moderada (nome + curso, sem CPF) |
| `theme_mode` | system/light/dark | Baixa |

---

## Google Apps Script (Backend Operacional Atual)

**Arquivo:** `google_apps_script.js`
**Conta:** tdsdados@gmail.com
**Implantação:** Web App Google (URL pública segura)

Abas da planilha controladas:
1. `Eventos` — Log bruto de todos os eventos do app
2. `Alunos` — Um registro por CPF com contadores de acesso e conclusão
3. `Por Cartilha` — Métricas agregadas por cartilha (iniciadas/concluídas)

Eventos que disparam email de certificado:
- `COMPLETED` → `_enviarCertificado(data)` → Gmail API

---

## Segurança — Estado Atual

| Item | Status |
|---|---|
| CPF não armazenado no servidor | ✅ Somente HMAC hash no KV |
| CPF não incluído no PDF/QR Code | ✅ Confirmado no código |
| Chaves de modelo não no APK | ✅ Permanecem no Cloudflare |
| HTTPS obrigatório para certificados | ✅ Validado no CertificateService |
| Consentimento LGPD antes de analytics | ✅ PrivacyPreferences.hasConsent() |
| Keystore Android protegido | ✅ gitignore + não versionado |
| key.properties protegido | ✅ gitignore + confirmado |
| Validação local de hash do certificado | ✅ hasValidLocalHash |

---

## Riscos Identificados

| Risco | Severidade | Ação |
|---|---|---|
| Conteúdo das cartilhas hardcoded no APK | Alta | Onda 2: API remota de cursos |
| Sem banco relacional centralizado | Alta | Onda 1: PostgreSQL + API |
| Ausência de autenticação real no servidor | Alta | Onda 1: JWT + RBAC |
| Git não inicializado (histórico ausente) | Média | ✅ Resolvido na Onda 0 |
| Deploy manual via rsync | Média | Onda 1: CI/CD via Dokploy |
| LearningEvents não persistem no servidor | Alta | Onda 2: API de eventos |
| Sem ambiente de staging | Média | Onda 1: staging no Dokploy |
| Auditoria VPS pendente | Média | Requer SSH — solicitar acesso |
| CPF em SharedPreferences (plaintext) | Média | Avaliar criptografia local |

---

_Documento gerado pela Onda 0 de auditoria técnica. Atualizar a cada mudança arquitetural relevante._
