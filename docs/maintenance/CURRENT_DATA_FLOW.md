# Tutor TDS — Fluxo de Dados Atual

> **Onda 0 — Auditoria Técnica**
> Data: 2026-09-19

---

## 1. Fluxo de Onboarding do Usuário

```
Primeiro acesso
      │
      ▼
WelcomeScreen
  - Coleta: nome, WhatsApp, CPF
  - Valida CPF com algoritmo Mod 11 (client-side)
  - Pergunta consentimento de compartilhamento
  - Salva em SharedPreferences (local)
      │
      ▼
PrivacyConsentScreen (se não viu ainda)
  - Exibe política de privacidade
  - Exige consentimento explícito
  - Registra PrivacyPreferences.saveDecision()
      │
      ▼
OnboardingScreen (3 slides — visto 1 vez)
      │
      ▼
HomeScreen
```

**Dados persistidos localmente:**
- `user_name`, `user_phone`, `user_cpf` → SharedPreferences
- `privacy_consent` → SharedPreferences
- `onboarding_seen_v1` → SharedPreferences

**Estado real do CPF:** na emissão de certificado, o CPF é usado apenas para gerar um HMAC e não é persistido no KV. Entretanto, o fluxo legado de analytics envia o CPF em texto puro ao Google Apps Script. Esse fluxo deve ser substituído de forma compatível na Onda 1.

---

## 2. Fluxo de Estudo — Cartilhas

```
HomeScreen
  - Carrega 9 cartilhas de assets/data/lessons/*.json
  - Ordena alfabeticamente
      │
      ▼
ChatExperienceScreen (seleção de cartilha)
  - Renderiza seção por seção (tipo chat/chatbot)
  - Messages: tipo bot, user, question, quiz
  - Contabiliza perguntas respondidas
      │
      ├─► [se tem consentimento] DataSyncService.logEvent("STARTED", cartilha)
      │         └──► POST webhook → Google Apps Script → Planilha Alunos
      │
      └─► [ao concluir] DataSyncService.logEvent("COMPLETED", cartilha)
                └──► POST webhook → Google Apps Script
                         └──► _enviarCertificado() → Gmail
```

**Catálogo de cartilhas (9 — embutidas no APK):**
1. Agricultura Sustentável (6 perguntas)
2. Atendimento ao Cliente (4 perguntas)
3. Audiovisual para o Dia a Dia (4 perguntas)
4. Cooperativismo e Crédito (4 perguntas)
5. Economia do Lar (4 perguntas)
6. Educação Financeira (5 perguntas)
7. Inteligência Artificial e Inclusão Digital (4 perguntas)
8. Sistemas Agroflorestais — SAF (3 perguntas)
9. Inspeção e Certificação — SIM/SIMA (4 perguntas)

**Limitação atual:** novos cursos requerem rebuild e republicação do APK.

### Fila local de LearningEvents

Desde 2026-09-20, abrir ou concluir uma cartilha também cria um evento local independente do webhook legado:

```text
ChatExperienceScreen
      │
      ├─► lesson_started
      └─► lesson_completed (somente no fim real)
              │
              ▼
LearningEventQueue → SharedPreferences
```

- O `event_id` combina sessão e tipo, tornando retries idempotentes.
- O payload contém apenas IDs técnicos, tipo e horário; não contém nome, telefone ou CPF.
- A fila mantém no máximo 500 eventos e preserva os mais recentes.
- Os eventos ainda não são enviados: a sincronização depende da API autenticada da Onda 1.
- O webhook legado continua separado por compatibilidade e ainda obedece ao consentimento existente.

---

## 3. Fluxo do Tutor IA

```
HomeScreen → ChatExperienceScreen ou AIAssistantScreen
      │
      ▼
AnythingLLMService.getChatResponse(message, mode, context)
      │
      ▼ HTTPS POST
Cloudflare Worker /v1/chat
  - Valida CORS (origem permitida)
  - Valida tamanho da mensagem (max 8.000 chars)
  - Monta system prompt:
      "Tutor TDS especializado nas cartilhas do programa TDS do Tocantins.
       Responde em pt-BR com linguagem simples. Usa protocolo ATUI.
       Não inventa informações."
  - Modo adaptativo: faz até 2 perguntas antes de aconselhar
      │
      ▼ HTTPS (credencial no Cloudflare, nunca no APK)
AnythingLLM na VPS (46.202.150.132)
  - RAG sobre as 9 cartilhas indexadas
  - Resposta contextualizada
      │
      ▼
Cloudflare Worker → retorna { text: "..." }
      │
      ▼
Flutter → exibe na tela

Fallback: se gateway indisponível → mensagem amigável ao usuário
```

---

## 4. Fluxo da Central de Estudos com IA

```
HomeScreen → StudyHubScreen
  - Usuário seleciona uma das 9 cartilhas
  - Escolhe tipo de material e dificuldade
      │
      ▼
StudyAiService._generate(kind, topic, difficulty)
  POST /v1/study
      │
      ▼
Cloudflare Worker /v1/study
  - Valida kind: flashcards | quiz | summary | exam
  - Valida difficulty: basic | intermediate | advanced
  - Monta prompt específico para o tipo solicitado
      │
      ▼
AnythingLLM → gera material pedagógico
      │
      ▼ Cloudflare retorna JSON estruturado
      │
      ▼ Flutter renderiza:
         FlashcardsScreen → cartões frente/verso + revisão dos difíceis
         AssessmentScreen → quiz com correção imediata ou simulado com cronômetro
         SummaryScreen → texto de resumo com botão de copiar
```

---

## 5. Fluxo de Certificação

```
ChatExperienceScreen
  - Usuário responde TODAS as perguntas obrigatórias
  - answeredQuestions == totalQuestions
      │
      ▼
CertificateService.issue(holderName, cpf, courseId, answered, total)
      │
      ▼ HTTPS POST /v1/certificates
Cloudflare Worker
  - Verifica configuração do serviço (CERTIFICATE_SIGNING_SECRET)
  - Valida courseId na lista fechada de 9 cartilhas
  - Valida CPF (Mod 11)
  - Calcula claimDigest = HMAC-SHA256(secret, "claim|cpf|courseId")
  - Verifica duplicidade no KV (chave: claim_digest)
  - Se duplicado: retorna certificado existente
  - Se novo:
      ├─► Gera ID único (tipo TDS-2026-XXXXXXXX)
      ├─► Monta payload canônico (sem CPF)
      ├─► Calcula hash SHA-256 do payload
      ├─► Calcula signature HMAC-SHA256(secret, hash)
      ├─► Grava no KV: certificates:{id} → payload
      └─► Grava no KV: claim_digest:{digest} → id
      │
      ▼
Flutter CertificateService
  - Recebe { certificate: {...} }
  - Recalcula hash localmente (hasValidLocalHash)
  - Gera PDF A4 landscape (CertificatePdfService)
  - Salva PDF em area privada do app
  - Grava CertificateRecord no SharedPreferences
      │
      ▼
CertificateWalletScreen
  - Lista todos os certificados emitidos
  - Permite imprimir, compartilhar, exportar ou enviar por email
  - QR Code aponta para https://gateway.domain/verify/{id}
```

**Verificação pública:**
```
Qualquer pessoa com o QR Code
      │
      ▼ GET /verify/{id}
Cloudflare Worker
  - Busca no KV: certificates:{id}
  - Recalcula hash e signature
  - Exibe página HTML pública com resultado

Ou via API:
GET /v1/certificates/{id} → { valid: true/false, certificate: {...} }
```

---

## 6. Fluxo de Analytics (Google Sheets)

```
Evento no app (consentimento verificado)
  - REGISTERED: cadastro concluído
  - STARTED: iniciou cartilha
  - QUIZ_ANSWERED: respondeu pergunta
  - COMPLETED: concluiu cartilha
      │
      ▼ POST (timeout 15s)
Google Apps Script (Web App pública)
  - doPost(e)
      ├─► _logEvento() → Aba "Eventos" (timestamp, nome, WhatsApp, CPF, evento, detalhe)
      ├─► _atualizarAluno() → Aba "Alunos" (1 linha por CPF com contadores)
      ├─► _atualizarPorCartilha() → Aba "Por Cartilha" (métricas agregadas)
      └─► [se COMPLETED] _enviarCertificado() → Email via Gmail API

Fallback: se webhook falhar → app continua funcionando (fire-and-forget)
```

**⚠️ RISCO:** CPF trafega em plaintext para o Google Apps Script. Rever na Onda 1.

---

## 7. Fluxo de Deploy (Atual)

```
Desenvolvedor (local Windows)
      │
      ▼
flutter build web --base-href / --release
      │
      ▼ (deploy_dokploy.sh)
rsync build/web/ → root@46.202.150.132:/VPS_REMOTE_DIR/web/
      │
      ▼
POST $DOKPLOY_URL/api/compose.deploy
      │
      ▼
Dokploy → rebuildsa container Docker → Nginx serve novo build

Ou para o APK/AAB:
flutter build appbundle --release --dart-define-from-file=config/production.json
      │
      ▼ (manual)
Upload play.google.com/console → Google Play Store
```

---

## Lacunas Críticas no Fluxo Atual

| Lacuna | Impacto | Onda |
|---|---|---|
| Sem banco relacional → dados só no Sheets e local | Sem histórico confiável, sem multi-turma | Onda 1 |
| Sem API TDS → app acessa serviços dispersos | Difícil evoluir sem acoplamento | Onda 1 |
| LearningEvents sem servidor → 40h não confiáveis | Não comprova carga horária | Onda 2 |
| CPF vai ao Google Apps Script em plaintext | Risco LGPD | Onda 1 |
| Catálogo de cursos no APK → exige novo build | Sem agilidade para novos cursos | Onda 2 |
| Deploy manual via rsync | Propenso a erro, sem rollback | Onda 1 |
| Sem ambiente de staging | Sem zona segura para testar | Onda 1 |

---

_Atualizar este documento quando o fluxo real mudar._
