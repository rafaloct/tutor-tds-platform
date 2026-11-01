# Grafo de cobertura E2E — Cartilhas TDS em Flutter Web (staging)

Data: 2026-10-31 · Escopo: `config/staging.qa.json` (API `tutor-staging-api`,
`OPERATOR_OPERATIONS_ENABLED=true`, `REMOTE_CATALOG_ENABLED=true`).

## 0. Premissa estrutural: não há rotas de URL

`MaterialApp` usa `home: WelcomeScreen()` — **sem `go_router`, sem
`onGenerateRoute`, sem deep links** (busca repo-wide: zero ocorrências de
`Uri.base`, `go_router`, `routeInformationParser`, `app_links`). Toda
navegação é `Navigator.push` imperativo embrulhado em `trackedRoute`
(`lib/features/analytics/telemetry_route.dart`), que atribui `pageId` para
telemetria. Portanto:

- Vértice = tela (widget), identificada pelo `pageId` de telemetria.
- A URL do browser é sempre `/` — F5 e botão Voltar do navegador são
  arestas de **reinício**, não de navegação interna.
- Único "deep link" possível: payload de push `{destination:"support"}` →
  ChatwootScreen (`push_notification_service.dart`), e push está OFF em
  staging/web (`PUSH_NOTIFICATIONS_ENABLED` ausente → false).
- Sessão: `SharedPreferences` → `localStorage` no web, escopo por origem.
  `user_name`/`user_phone` + tokens do `AuthRepository` persistem entre
  reloads da MESMA origem.

## 1. Vértices (V) por categoria

### [Público] — sem sessão
| v | pageId | widget |
|---|--------|--------|
| v0 | `welcome` | WelcomeScreen (form nome/WhatsApp/CPF) |
| v1 | `account_login` | AccountLoginScreen |
| v2 | `privacy_policy` | PrivacyPolicyScreen |
| v3 | `onboarding` | OnboardingScreen |

### [Autenticado-Staging] — role student
| v | pageId | widget |
|---|--------|--------|
| v4 | `privacy_consent` | PrivacyConsentScreen |
| v5 | `home` | HomeScreen (hub) |
| v6 | `guided_lesson` | ChatExperienceScreen (cartilha) |
| v7 | (untracked) | ModuleMaterialsScreen |
| v8 | `ai_assistant`/`tutor` | GenUIAssistantScreen |
| v9 | `videos`/`content_catalog` | MediaCatalogScreen |
| v10 | `video_player` | MediaPlayerScreen |
| v11 | `study_hub` | StudyHubScreen |
| v12 | `flashcards` | FlashcardsScreen |
| v13 | `assessment` | AssessmentScreen (quiz/exam) |
| v14 | `summary` | SummaryScreen |
| v15 | `glossary` | GlossaryScreen |
| v16 | `user_guide` | GuideScreen |
| v17 | `support` | ChatwootScreen |
| v18 | `profile` | CadUnicoScreen |
| v19 | `settings` | SettingsScreen |
| v20 | `about` | AboutScreen |
| v21 | `certificate_wallet` | CertificateWalletScreen |
| v22 | `certificate_details` | CertificateDetailsScreen |
| v23 | `certificate_requests` | CertificateRequestsScreen |

### [Gestão-Condicional-Staging] — exige claims operator/teacher/monitor
(NÃO alcançáveis pela conta QA student; exigem conta com escopo)
| v | pageId | widget |
|---|--------|--------|
| v24 | `management_workspace` | ManagementWorkspaceScreen |
| v25 | `operator_operations` | OperationsEntry (flag `OPERATOR_OPERATIONS`) |
| v26 | `course_editor(_catalog)` | CourseEditorCatalogScreen → CourseStructureEditor |
| v27 | `classroom_dashboard` | ClassroomDashboardScreen |
| v28 | `classroom_roster` | ClassroomRosterScreen |
| v29 | `evidence_cockpit` | EvidenceStaffScreen |
| v30 | `session_presence` | SessionPresenceScreen |
| v31 | (untracked) | OfficialAttendanceScreen |
| v32 | `evidence_checkin` | EvidenceCheckinScreen |
| v33 | `student_followup` | StudentFollowupScreen |
| v34 | `certificate_review` | CertificateRequestsScreen(reviewMode) |
| v35 | `learner_classrooms` | LearnerClassroomsScreen |
| v36 | `monitor_exceptions` | MonitorExceptionsView |

### [Modal/Overlay] — sem pageId próprio
| m | origem → modal |
|---|----------------|
| m1 | welcome → AlertDialog "Criar conta Tutor TDS" (register) |
| m2 | settings → AccountLoginDialog |
| m3 | settings → "Sair da conta online?" / "Excluir conta e dados?" |
| m4 | guide/assistant → _HelpSheet (bottom sheet) → ChatwootScreen / wa.me |
| m5 | certificate_requests → "Solicitar análise?" / "Nova análise?" / _ReviewDialog |
| m6 | assessment → "Escolha como continuar" (conflict) / "Entregar simulado?" (exam) |
| m7 | evidence_staff → SimpleDialog motivo / _EvidenceImportDialog / "Pendências" |
| m8 | session_presence → _PresenceDialog |
| m9 | operations → "Revogar vínculo com esta turma?" |
| m10 | course_editor → _NewCourseDialog / material/message editor dialogs |

### [Estado Erro/Offline Web]
| e | condição |
|---|----------|
| e1 | MediaRepository sem HTTPS/CORS → "Vídeos indisponíveis agora" |
| e2 | Catálogo remoto falha → fallback assets/cache + aviso |
| e3 | API 401 → erros AuthException nas telas de auth |
| e4 | Sem rede → telas degradadas (catalog vazio, sync pendente) |
| e5 | Browser bloqueia (CORS) → request nunca sai; resolvido em staging via `STAGING_ALLOWED_ORIGINS` |

### [Fallback Web (divergência vs Android)]
| f | feature | web | android |
|---|---------|-----|---------|
| f1 | Mídia embed | `media_embed_view_web.dart` (iframe HtmlElementView) | webview_flutter |
| f2 | PDF certificado | `certificate_pdf_service` → browser download/aba | viewer externo/Drive |
| f3 | speech_to_text | SpeechRecognition do browser (pode falhar silencioso) | nativo |
| f4 | Push | ausente (flag off + sem service worker) | FCM |
| f5 | Outbox offline | sem sqflite durable (flag off) | sqlite nativo |
| f6 | Chatwoot | abre link/widget externo | in-app |
| f7 | Play Store/deletion | url_launcher → nova aba | market:// |

## 2. Arestas (E)

### Cadeia de entrada
```
v0 welcome ──[form+register m1]──> v3 onboarding ──> v5 home
v0 welcome ──["Já tenho conta"]──> v1 account_login ──[login ok]──> v4 privacy_consent ──> v5 home
v0 welcome ──[sessão salva]──────> v4|v5 (redirect automático)
v0 welcome ──[QA_AUTOLOGIN]──────> v5 home ──> v9 videos (só staging.qa.web.json)
```

### Spokes do hub v5 (home)
```
v5 ──[cartilha card]──> v6 guided_lesson
v6 ──[appbar "Materiais"]──> v7 module_materials
v6 ──[appbar "Perguntar ao Tutor"]──> v8 ai_assistant
v6 ──[FAB "Solicitar certificado" se _isCompleted]──> v23 certificate_requests
v5 ──["Vídeos" btn | nav "Conteúdos"]──> v9 media_catalog
v9 ──[media card]──> v10 video_player
v10 ──["Fazer quiz rápido"]──> v13 assessment(quiz)
v10 ──["Perguntar ao Tutor"]──> v8
v9 ──["Abrir cartilha" | chip Cartilha]──> v6
v9 ──[chip "Trilha de estudo"]──> v11 study_hub
v5 ──["Estudar com IA" | nav "Aprender"]──> v11
v11 ──[card]──> v8 / v12 flashcards / v13(quiz) / v14 summary / v13(exam)
v14 ──[chip]──> v12 / v13(quiz)
v13 ──[chip pergunta]──> v8(tutor)
v5 ──["Meus certificados"]──> v21 certificate_wallet
v21 ──[appbar icon]──> v23 certificate_requests
v21 ──[card]──> v22 certificate_details ──[f2 PDF]──> externo
v5 ──["Como usar"]──> v16 guide ──[m4 sheet]──> v17 support | wa.me externo
v5 ──[glossary icon]──> v15 glossary ──["Perguntar à IA"]──> v8
v5 ──[nav "Perfil"]──> v18 cadunico
v5 ──[menu]──> v16/v17/v19 settings/v20 about/v35/'refresh_catalog'
v19 ──> m2/m3 dialogs; ──> v2 privacy_policy; ──> v3 onboarding(review);
     ──> v17 support; ──[logout]──> v0; ──[delete]──> v0; externo f7
v8 ──[HumanHelpButton m4]──> v17 | wa.me
```

### Arestas condicionais de staging (escrita/flags)
- login/register/logout/delete → `POST /auth/*` staging (escrita real, baixa retenção)
- `REMOTE_CATALOG_ENABLED` → catálogo remoto (GET /courses)
- mídia → `GET /media` (https absoluto obrigatório)
- certificados → `/certificate-requests/*` (contexts sem versão resolvido em staging)
- `OPERATOR_OPERATIONS_ENABLED` → v25 visível (mas exige claim operator)
- v24-v36 → exigem claims (teacher/operator/monitor) — student não entra
- AI tutor → `TUTOR_GATEWAY_URL=""` → aresta degrada (composer abre, resposta remota fora de escopo web)
- `WORDPRESS_LOGIN_SYNC_ENABLED` → register/login provisiona usuário no site (transparente à UI)

### Arestas de ambiente browser
- RELOAD (F5): qualquer v ──> v0 → auto-redirect → v5 (sessão persiste)
- BACK do navegador: sai do app (sem rotas) — equivalente a reload
- Troca de origem (localhost↔IP↔porta): nova origem = novo storage → v0 sem sessão

## 3. Mermaid — grafo completo executado (V0→V4 + fallbacks web)

Legenda: aresta sólida = executada no web headless (staging real);
pontilhada = condicional/dados; classe `err` = estado de erro/fallback.

```mermaid
flowchart TD
  subgraph V0["[Público] V0 auth"]
    v0["welcome"]
    v1["account_login (rota)"]
    m1["register_dialog (modal)"]
  end
  subgraph V1["[Autenticado]"]
    v4["privacy_consent"]
    v5["home ⭐hub"]
  end
  subgraph V2["V2 mídia"]
    v9["media_catalog"]
    v10["video_player"]
  end
  subgraph V3["V3 estudo/spokes"]
    v11["study_hub"]
    v12["flashcards"]
    v14["summary"]
    v16["user_guide"]
    v17["support/chatwoot"]
    v19["settings"]
    v2["privacy_policy"]
    v3["onboarding_review"]
    v20["about"]
  end
  subgraph V4["V4 certificados/perfil"]
    v18["cadunico"]
    v21["cert_wallet"]
    v22["cert_details"]
  end
  subgraph COND["[Condicional gestão/dados]"]
    v24["mgmt_workspace +claims"]
    v13["assessment"]
  end
  subgraph FB["[Fallback Web]"]
    fbPdf["PDF → Printing.sharePdf/layoutPdf"]
    fbEmbed["embed iframe (postMessage)"]
    fbSp["storage: SharedPreferences"]
  end
  e1["login_error"]
  e2["wallet_error"]

  v0 -->|"Já tenho conta"| v1
  v1 -->|senha errada → 401| e1 -->|BackButton| v0
  v0 -->|"Criar conta"| m1
  m1 -->|"409 já existe"| v0
  m1 -.->|201 nova conta| v4
  v1 -->|e3: senha OK| v4
  v4 -->|"Concordar e continuar"| v5
  v0 -.->|"F5/reload: sessão persiste"| v5

  v5 -->|e6 Vídeos| v9 -->|"Aula 01"| v10
  v10 --> fbEmbed
  v10 -->|"e7a Salvar → snackbar+bookmark"| v10
  v10 -->|"e7b rating ★5"| v10
  v10 -.->|embed 'ended' (postMessage)| v10
  v10 -->|BackButton| v9 -->|back| v5
  v10 -.->|quiz| v13
  v5 -->|nav Aprender| v11
  v11 --> v12 -->|back| v11
  v11 --> v14 -->|back| v11
  v11 -->|back| v5
  v5 -->|nav Conteúdos| v9
  v5 -->|nav Perfil| v18 -->|"Nome/WhatsApp/CPF → certificado"| v18
  v18 -->|back| v5
  v5 -->|e10 certificados| v21
  v21 -->|seed cert| v22
  v22 -->|"e12a Compartilhar"| fbPdf
  v22 -->|"e12b Imprimir"| fbPdf
  v22 -->|back| v21 -->|back| v5
  v21 -->|repo falha| e2 -->|retry| v21
  v5 -->|"Como usar"| v16 -->|back| v5
  v5 -->|menu| v17 -->|back| v5
  v5 -->|menu| v19
  v19 --> v2 -->|back| v19
  v19 --> v3 -->|"Pular"| v19
  v19 -->|back| v5
  v5 -->|menu| v20 -->|back| v5
  v5 -.->|claims gestor| v24
  v18 & v21 & fbSp -.-> v5

  classDef err fill:#7f1d1d,stroke:#ef4444,color:#fff
  classDef fb fill:#1e3a5f,stroke:#3b82f6,color:#fff
  class e1,e2 err
  class fbPdf,fbEmbed,fbSp fb
```

**Execução:** e1..e10 (`account_qa`/`learning_qa`), e11..e12 (`wallet_qa`),
spokes completos (`web_postman`). Rating: API respondeu `403` (matrícula
no curso exigida) — aresta de dados. PDF: `shareCertificates` usa
`kIsWeb`→`Printing.sharePdf` (blob download); `printCertificates`→
`layoutPdf` (iframe print). Storage cert: web = SharedPreferences
`certificate_index_v1` (antes: filesystem → MissingPluginException →
wallet em erro).

## 4. Cobertura por algoritmo

### DFS — jornadas completas (sem interrupção)
- **J1 Onboarding**: welcome → register(m1) → onboarding → home → guided_lesson → (complete) → certificate_requests → solicitar análise(m5)
- **J2 Estudo**: home → study_hub → flashcards → back → quiz → back → summary → back
- **J3 Mídia**: home → videos → player → quiz/tutor → back → back
- **J4 Conta**: home → perfil(cadunico) → back → settings → privacy_policy → back → onboarding-review → suporte → back → logout(cancel)
- **J5 Sessão**: reload em qualquer v → welcome → auto-home (prova persistência localStorage)

### Carteiro Chinês — caminho mínimo de arestas
O grafo é **hub-and-spoke quase euleriano**: toda spoke é ciclo
home→v→home. Caminho mínimo = cadeia de entrada (1×) + Σ spokes (2 arestas
cada) + modais (abre+fecha). Para o subgrafo student (v0..v23):

```
ENTRADA (1×):  v0→v1→v4→v5   (4 arestas)
SPOKES (2× cada): home→v6→home, home→v9→v10→home, home→v11→v12→home,
  home→v11→v13→home, home→v11→v14→home, home→v16→v17→home,
  home→v15→home, home→v18→home, home→v21→v23→home, home→v21→v22→home,
  home→v19→v2→home→v19→v3→home, home→v20→home
RELOAD (1×): F5 → v0 → v5
```

≈ **40 arestas** cobrem 100% do subgrafo alcançável por student.
Vértices de gestão (v24-v36) ficam em suíte separada com conta operator —
não inflam o caminho student.

## 5. Restrições web vs Android + fallbacks/mocks

| nó | risco no web | fallback de teste |
|----|--------------|-------------------|
| f1 video embed | YouTube iframe pode não renderizar headless | assert no card/título, não no frame interno |
| f2 PDF cert | sem viewer externo; download via browser | assert no botão/response HTTP do endpoint |
| f3 speech_to_text | SpeechRecognition ausente headless | mockar input texto; não clicar no mic |
| f4 push | serviço off | vértice inexistente — fora do grafo web |
| f5 outbox | sem sqlite durable | flag já off; sync validado via API online |
| f6 chatwoot | widget externo pode não carregar | assert AppBar/landing da tela, não o widget |
| e5 CORS | request bloqueado antes de sair | `STAGING_ALLOWED_ORIGINS` inclui :9090/:8484 |
| login | captcha/rate-limit N/A em staging | credenciais QA via dart-define |

## 6. Automação — caminho do Carteiro executável

`integration_test/web_postman_test.dart` implementa o caminho mínimo
student (~40 arestas) contra `staging.qa.json`, usando o harness já
validado (`tooling/test_web_e2e.sh`, Chrome for Testing headless).

```bash
TEST=integration_test/web_postman_test.dart ./tooling/test_web_e2e.sh
```

Vértices de gestão permanecem fora — exigem conta operator dedicada e
estão documentados como suíte futura (mesma técnica, credencial própria).

**Status: EXECUTADO 2026-10-31 — PASSOU** no Chrome headless contra
staging real (`staging.qa.json`), sessão contínua única: entrada
welcome→account_login→privacy_consent→home + 9 spokes student + aresta
F5 (sessão persiste via SharedPreferences → home direto). Integrado ao
`tooling/web_qa.sh` (suite: 6 arquivos e2e, todos PASS).

`integration_test/learning_qa_test.dart` — **EXECUTADO 2026-10-31 —
PASSOU**: DFS V2(vídeos)→e6(Aula 01)→V3(player: e7a Salvar estado+
persistência, e7b rating→API 403 matrícula exigida, e8 retorno)→V4
(e9 perfil/dados-certificado, e10 wallet vazia). Divergências web
documentadas: sem botão "concluir" (conclusão = evento `ended` do
embed); share-PDF usa dart:io File (não-web); print usa `printing`
(suportado); edges de PDF condicionais a certificado emitido.

`integration_test/certificate_request_test.dart` — **EXECUTADO
2026-11-01 — PASSOU**: DFS V4b (pedido de certificado real, API
staging). e13: `CertificateRequestsScreen(courseId:'saf')` injetada
via Navigator (o FAB `v6→v23` exige `_isCompleted` — aresta
condicional de módulo concluído); e13a: `GET
/certificate-requests/contexts` retorna matrícula real
`qa-cert-enroll-1` → dropdown + evidência ("Tempo validado 0.00 h de
40.00 h", "Há critérios pendentes"); e13b: "Solicitar análise" →
dialog de confirmação (LGPD: "não emite nem publica") → `POST
/certificate-requests` **201** → pedido `f5ee9813` listado
"Aguardando análise da equipe" (pendente, revisão humana); e13c:
wallet → icon "Pedidos de certificado" → mesmo pedido visível fora
do contexto do curso (persistência server-side, sem seed local).
Limite do contrato: `approved`→emissão é aresta de gestor humano
(review-queue, claim coordinator/admin) — fora do escopo student;
o teste prova a jornada student até `pending`, sem dead-end.
