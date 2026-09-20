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
  - Se TUTOR_API_URL existir: oferece conta online opcional
      - register/login via API
      - tokens somente no armazenamento seguro
  - Permite continuar apenas no dispositivo
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
- access/refresh tokens da conta → armazenamento seguro da plataforma
- `privacy_consent` → SharedPreferences
- `onboarding_seen_v1` → SharedPreferences

**Estado real do CPF:** no cadastro online, o servidor persiste somente HMAC do
CPF; no login, o CPF não é salvo novamente em SharedPreferences. O fluxo local
legado ainda pode manter `user_cpf` para certificados e Chatwoot. Na emissão de
certificado, o CPF é usado apenas para gerar um HMAC e não é persistido no KV.
Analytics não lê nem envia nome, telefone ou CPF.

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
      └─► LearningEventQueue
                ├──► lesson_started / lesson_completed / study_activity
                └──► page_viewed / resource_opened / feature_used
                         └──► API autenticada → PostgreSQL
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

**Catálogo remoto preparado:** `CourseRepository` consulta `GET /courses`
somente quando `TUTOR_API_URL` está configurada. Uma resposta válida é mantida
em cache; falha da API usa o cache e depois os nove assets locais. Enquanto a
API não existir, não há chamada de rede e o comportamento permanece local.

**Limitação atual:** a API ainda não foi publicada; portanto, novos cursos em
produção continuam exigindo rebuild até `TUTOR_API_URL` apontar para um ambiente
validado.

### Fila local de LearningEvents

Desde 2026-09-20, aprendizagem e uso do aplicativo compartilham uma fila local
idempotente:

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
- Com consentimento, os eventos são enviados à API autenticada e preservados
  offline para retomada. Sem consentimento, telemetria de uso não é persistida.
- Todas as rotas possuem IDs estáveis. Recursos e funcionalidades usam apenas
  identificadores técnicos validados, nunca texto digitado ou dados pessoais.
- `GET /analytics/usage` agrega uso por período e respeita a linhagem de turma:
  estudante vê a si mesmo; professor/monitor somente sua turma; administrador
  pode consultar o escopo global ou filtrado.

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

## 6. Fluxo de Analytics (API Tutor TDS)

```
Evento tipado no app (consentimento verificado)
  - page_viewed: página nomeada
  - resource_opened: recurso técnico
  - feature_used: funcionalidade acessada
      │
      ▼ LearningEventQueue (máximo 500; prioridade pedagógica)
Sincronização autenticada /events
      │
      ▼ PostgreSQL learning_events
GET /analytics/usage
  - agrega contagem, usuários únicos e último acesso
  - aplica escopo de aluno, turma, professor/monitor e administrador
```

O contrato aceita apenas IDs técnicos validados e não lê dados pessoais.

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
| API/PostgreSQL ainda não publicados na VPS | Recursos online novos não operam em produção | Onda 1 |
| Catálogo de cursos no APK → exige novo build | Sem agilidade para novos cursos | Onda 2 |
| Deploy manual via rsync | Propenso a erro, sem rollback | Onda 1 |
| Sem ambiente de staging | Sem zona segura para testar | Onda 1 |

---

_Atualizar este documento quando o fluxo real mudar._
