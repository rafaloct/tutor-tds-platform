# Execução LearnPress ↔ Tutor TDS | Guia humano e de agentes

**Entrada obrigatória:** [ADR de 18/10/2026](ADR_2026-10-18_LEARNPRESS_FASTAPI_AUTHORITY.md), [matriz de aceite](LEARNPRESS_TDS_ACCEPTANCE_MATRIX.md), `AGENTS.md`, `docs/program/AGENT_EXECUTION_PLAYBOOK.md`, Epic #224 e Issue #249.
**Quem aprovou o quê:** responsável aprovou a **divisão de autoridade e a documentação**. Não aprovou integração técnica concreta, SSO específico, merge, deploy, troca de credenciais ou novo release.

## 0. Como iniciar ou retomar uma sessão

1. Ler `docs/CURRENT_STATE.md`, `docs/DECISIONS.md`, `docs/DOMAIN_CONTRACT.md`, a ADR e a issue da fatia. Buscar PRs abertos e sobreposição de escritores.
2. Verificar `staging` atual e PRs empilhados #226, #234, #237, #240, #242, #244, #246, #248 e plugin WP #238. **Não** tratar código de PR draft como código já integrado.
3. Escolher **uma** fatia de objetivo único, com issue própria, dependências explícitas, rótulo de executor quando aplicável e `HUMAN_GATE`. Criar branch/worktree isolada; nunca editar worktree de outro agente.
4. Emitir cabeçalho de handoff: `BASE_SHA`, `BRANCH`, `ISSUE`, `OBJECTIVE`, `AUTHORITY`, `FILES`, `BLOCKERS`, `TESTS`, `ROLLBACK`, `HUMAN_GATE`. Consultar somente dados sintéticos e segredos referenciados, nunca imprimir credenciais.
5. Ao finalizar, registrar o estado real, execução de testes, hashes/artefatos e links verificáveis; abrir PR **draft**, sem auto-merge, sem publicar WordPress ou Play.

## 1. Inventário existente, não recriar

| Superfície | Implementação localizada | Uso correto |
|---|---|---|
| Catálogo público LP | `cartilhas_app/lib/features/ead_catalog/data/ead_catalog_repository.dart` | Reusar IDs WP e `/learnpress/v1/courses`; não declarar login |
| Percurso público | `ead_curriculum_repository.dart`, `ead_learning_path_screen.dart` | Somente grade pública, sem progresso autenticado |
| Conteúdo opt-in | `ead_editorial_bridge_repository.dart`, plugin PR #238 | Somente aula e vídeo autorizados; 404 público é bloqueio, não permissão |
| Player | `ead_youtube_player_screen.dart`, PR #246 | Player não cria presença/conclusão |
| Conta institucional | `features/auth/data/auth_repository.dart`, FastAPI `/auth/login`, `/auth/me` | Não autentica no WordPress |
| Leitura local | `features/study_progress/study_progress_repository.dart` | Persistência local da cartilha, diferente do LMS |
| Turmas | `features/classrooms/`, `features/learning_context/` | Fonte FastAPI, contexto validado |
| Certificado oficial | `features/certificates/`, carteira e pedidos | FastAPI/Worker; não é carteira LearnPress |
| Portal EAD | `/minha-area/`, `/certificados/` (HTTP 200 público) | Ver fluxo autenticado antes de adotar rota |
| API LP real | `/learnpress/v1/token`, `courses/enroll`, `lessons/finish`, `quiz/start e quiz/finish`, `users` | Endpoints **descobertos**, ainda não homologados/autorizados para o app |
| API TDS | `/tutor-api/public/courses` (9) | Fonte institucional, não duplicar matrícula LP |

## 2. Plano de fatias pequenas (não iniciar próxima sem gate)

| Fatia / owner proposto | Saída exata | Dependência | Gate humano |
|---|---|---|---|
| **F0 Evidência de LMS** / WP + QA | Clone WP/LearnPress staging com dois alunos QA e instrutor QA; inventário de “Minha área”, inscrição, status, quiz, progresso, certificados, redirects/cookies/roles. Capturas sanitizadas e rollback ensaiado | Backup e autorização de instalação **staging**; sem dados reais | Aprovar operação de clone WP, credenciais sintéticas |
| **F1 Contratos e crosswalk** / arquitetura + WP/API | Mapa versionado dos 11 `wp_course_id` e 9 `course_id/course_version_id`, relações de lesson/quiz e origem da evidência, inclusive 1474/1709 explicitamente sem mapeamento até revisão | F0, export de API/LP read-only | Aprovar mapeamento e visibilidade das duas ofertas |
| **F2 Identidade vinculada** / segurança + FastAPI + WP | Prova de controle de ambas as contas, vínculo persistido/auditado e revogável; nenhum segredo WP no app. Fake adapters e testes IDOR/CSRF/rollback antes de provider real | ADR, F0, modelo de autenticação realmente disponível | Aprovar protocolo de federação e consentimento |
| **F3 Minha Área** / Flutter | Home com conta EAD vinculada, “Meus cursos”, retomar aula e estados originados no LP; perfil, login/logout e erro/permissão distinguíveis; snapshot seguro | F1 + F2 ou fallback de login separado explicitamente aceito | Aceite UX, acessibilidade e privacidade |
| **F4 Matrícula, lição e quiz** / WP + Flutter | Comandos reais autenticados LP com recibos; equivalência site↔app após refresh; erros 401/403/409 e versão de curso correta | F2/F3, política LP de retry e acesso testada | Autorizar escritas em staging sintético; revisão pedagógica de quizzes |
| **F5 Certificados e status** / API + Flutter | Carteira separa “certificado oficial TDS”, pedidos, eventual conclusão EAD e documento WP legado; proveniência e verificador, sem emitir automaticamente | F1/F3/F4, fluxo oficial Issue #5 | Aprovar política editorial de exibição, nunca autoemissão |
| **F6 Release readiness** / QA + release | E2E 2 perfis, offline/conta compartilhada, TalkBack, presença/certificado, APIs, smoke Xiaomi, manifesto, APK/AAB assinados com gates | F0-F5 completos, CI e PRs integrados após autorização | Merge, deploy, assinatura e Play **separados** |

**Fallback consciente para entrega antecipada:** APK QA #248 é instalável e teve testes Flutter/smoke; não tem M4 autenticado. Se o cronograma exigir uso supervisionado antes de F2-F5, rotular “QA/staging, funcionalidade EAD autenticada não integrada”, manter CTAs para o site, sem prometer login único, progresso LP ou certificado LP no app.

## 3. Esquemas alvo para negociação, nunca endpoints implementados

Os exemplos abaixo são **TARGET** e precisam de ADR de autenticação, validação de OpenAPI, autorização e testes antes de código:

```text
GET  /integrations/learnpress/link-status       # TARGET; estado do vínculo por usuário FastAPI
POST /integrations/learnpress/link/start        # TARGET; iniciar autenticação/verificação
POST /integrations/learnpress/link/complete     # TARGET; confirmação segura server-side
DELETE /integrations/learnpress/link            # TARGET; revogar vínculo
GET  /me/ead/enrollments                       # TARGET; projeção limitada ao usuário
GET  /me/ead/courses/{wp_course_id}/progress    # TARGET; estado resolvido a partir LP
```

**Nunca adotar os caminhos acima como existentes só por estarem documentados.** Se a API LP autenticada atende o contrato com segurança, um proxy mínimo mediado pela FastAPI pode bastar. Não criar tabelas/mutações novas se já houver entidade apropriada; abrir ADR/migration própria para qualquer armazenamento de vínculo.

Modelo **TARGET** de resposta sem dados sensíveis:

```json
{
  "source_system": "learnpress",
  "wp_course_id": 1298,
  "link_state": "linked",
  "enrollment_state": "enrolled",
  "progress": {
    "unit": "learnpress_lessons",
    "value": null,
    "as_of": null
  },
  "tds_course_id": "agricultura-sustentavel",
  "tds_course_version_id": null,
  "is_institutional_enrollment": false
}
```

Campo `progress.value=null` significa ainda não observado, e nunca deve virar 0 por conveniência. `tds_course_id` é apenas candidato do mapa de títulos até aprovação da F1.

## 4. Padrões de implementação e segurança

- WordPress/LearnPress continua gerindo permissão de curso/livro e conclusão do LMS. O app não chama `POST /courses/enroll`, `/lessons/finish` ou `/quiz/finish` com token de administração ou usuário não verificado.
- Exigir proof of possession recente de ambas as contas e vínculo revogável; `state/nonce`, use-once, TTL curto, redirect allowlist, TLS, RBAC, rate-limit, CSRF e auditoria. Não acoplar Flutter diretamente a cookies internos, nem a senha institucional ao WP.
- Resposta autenticada deve ser isolada por usuário/ambiente, com cache limitado; `401` reautentica e `403` não expõe dados; `404` não autoriza fallback silencioso com dados de outro usuário.
- Simular “Aluno A” e “Aluno B” no mesmo Xiaomi; sair/entrar não mostra curso, certificado, nome ou percentuais do usuário anterior.
- “Inscrição EAD” jamais cria matrícula em turma TDS; inscrição/retorno do EAD não altera presença e certificado TDS.
- Permitir offline apenas para cartilhas e snapshots identificados como offline/defasados; mutação LMS sem recibo não é sucesso. Nenhum replay sem idempotência validada do fornecedor.
- Para quiz: manter questões, gabaritos e notas sob autorização LP; publicação de itens e mapeamento pedagógico dependem de revisão dos instrutores.
- Para IA: contexto `wp_course_id, lesson_id` é mapeado à `CourseVersion` somente com crosswalk aprovado; sem corpus validado (inclusive 1474/1709), mostrar indisponibilidade fundamentada.

## 5. Testes, evidências e gatilhos

Usar [LEARNPRESS_TDS_ACCEPTANCE_MATRIX.md](LEARNPRESS_TDS_ACCEPTANCE_MATRIX.md) como checklist por persona, fluxo, origem e comando, não somente contagem de testes. Os gates mínimos de cada PR incluem:

- Testes unitários/contrato de adapter com fixture LP anon/autenticada, sem gabarito vazado; validação de JSON/version/ID, ETag, 401/403/404 e retry.
- Testes de Flutter widget/semantics em 360/390/450px e 200% de fonte, dark/light, conectividade ruim e contas alternadas.
- E2E staging duas contas sintéticas, mesma matrícula/progresso LP no browser e no app, sem efeitos institucionais, antes de declarar `TESTED-STAGING`.
- Android real preferencialmente emulador, Xiaomi reservado ao `pre_aab_xiaomi_smoke` e smoke físico final do candidato congelado; capturas PNG/MP4/FLAC sem PII e hashes.
- Auditoria de scripts/Plugin WP em clone, status de cookies/token, endpoint público 404 e opt-in de conteúdo sem vazamento de quiz protegido.
- Falha em teste ou gate não vira `PASS` por atualizar screenshot sem inspeção; consolidar bloqueios na Issue e PR.

## 6. Quem decide e como retomar

- **Titular/coordenação TDS:** aprova critérios, autoridade e gates humanos, não executa validação técnica presumida.
- **Responsável editorial/instrutores LearnPress:** mapeia cursos/lessons/quizzes/direitos, opt-in público e revisões.
- **Responsável FastAPI/segurança:** identidade, vínculo, RBAC, auditoria e proteção de dados; não publica pelo WP.
- **Responsável Flutter:** Minha área, contextos, states UI, logout, acessibilidade e cache escopado.
- **Responsável QA:** staging/contas sintéticas, Android, evidências reprodutíveis e matriz de aceite.
- **Responsável release:** source freeze, config, keystore existente e gates, assinaturas, AAB/Play apenas com autorização.

Em toda transferência de tarefa, relatar **(a)** o que foi comprovado, **(b)** o que é alvo, **(c)** bloqueios e exata ação humana, **(d)** worktree e SHA, **(e)** próximo teste. O novo executor não começa reescrevendo o app ou criando outra LMS: pega a primeira fatia dependente liberada e prova a integração existente.

**STOP:** sem login sintético autorizado, certificado de upload conferido, backup/restore staging, decisão de SSO ou reviews, manter funcionalidade desligada. Sem auto-merge, force-push, dados reais ou deploy.


## 7. Guia rápido para secretaria, instrutores e suporte

| Pergunta do participante | O que responder e onde conferir | O que não fazer |
|---|---|---|
| "Onde encontro meus cursos?" | Identificar se ele procura cursos em que se inscreveu no **LearnPress** ou uma **turma TDS**. Conferir o domínio correto antes de orientar a Minha área. | Inventar matrícula TDS ao localizar uma inscrição EAD |
| "Concluí o vídeo, por que não tenho presença?" | A presença em encontros é apurada no fluxo TDS, por equipe autorizada, separadamente do vídeo. | Marcar frequência porque o vídeo tocou |
| "Meu curso aparece no site, mas não no app" | Verificar catalogação WP, revisão/opt-in editorial e a API; distinguir as ofertas adicionais #1474 e #1709 sem curso TDS correspondente. | Criar CourseVersion por título |
| "Meu progresso está diferente" | Comparar o **progresso da conta LearnPress** com o **histórico local de cartilha** e o **acompanhamento institucional**. Registrar cada origem/horário. | Somar percentuais ou copiar um sobre outro |
| "Já posso emitir certificado?" | Consultar o fluxo de pedidos e aprovação humana do TDS, a elegibilidade e o verificador institucional; documentos EAD, quando existirem, são outra categoria. | Declarar certificado oficial com base em quiz ou conclusão EAD |
| "Não consigo entrar" | Distinguir conta WordPress/LearnPress da conta institucional; encaminhar recuperação na autoridade correta e suporte Chatwoot. | Pedir senha por WhatsApp ou copiar token no app |
| "Quero sair ou apagar meus dados" | Explicar que vínculo, conta EAD e conta TDS têm controladores e retenções próprios; usar os canais de privacidade autorizados. | Apagar uma conta por mexer diretamente no banco da outra |

**Orientação de linguagem na interface:** chamar ações de “Inscrição no EAD”, “Progresso das aulas no EAD”, “Minha participação no TDS” e “Certificado oficial TDS”, nunca apenas “matrícula”, “progresso” ou “certificado” quando houver ambiguidade.

**Quem pode afirmar que foi concluído:** instrutor/editor confirma conteúdo publicado e direitos no LearnPress; QA comprova o comportamento no staging; coordenador/operador decide elegibilidade institucional; responsável de release aprova tecnicamente após gates. O time de suporte consulta estados, não altera decisões acadêmicas por mensagem.
