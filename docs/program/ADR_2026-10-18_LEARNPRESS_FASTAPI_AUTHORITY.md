# ADR 2026-10-18 | LearnPress + Tutor TDS: uma experiência, autoridades distintas

**Estado:** DECISION aprovada pelo responsável do projeto em 18/10/2026, para orientar arquitetura e documentação. **Implementação, homologação e publicação: NÃO APROVADAS por esta decisão.**
**Origem:** Issue #249, vinculada à Epic #224; evidência de lacunas na Issue #224 e auditoria local de 18/10.
**Escopo:** cursos EAD em `ead.ipexdesenvolvimento.cloud` e experiências correspondentes no aplicativo Flutter Tutor TDS.
**Precedência:** para inscrições e progresso **da oferta LearnPress**, esta ADR substitui as proibições genéricas anteriores de que WordPress seria somente público/editorial. Não substitui os contratos de matrícula institucional, CourseVersion, frequência, certificados oficiais ou o fluxo de aprovação humana da Issue #5.

## 1. Decisão, em linguagem operacional

O **LearnPress** é a fonte de verdade das **inscrições no curso EAD**, do acesso às lições conforme as regras do LMS, das tentativas de quiz do LearnPress e do **andamento das lições/quizzes no EAD**. O WordPress mantém o usuário/autenticação necessários a esse domínio, além da edição curricular publicada.

A **FastAPI/PostgreSQL Tutor TDS** é a fonte de verdade da **identidade institucional e dos vínculos do programa**, Course/CourseVersion formal, turmas, matrícula na turma TDS, baseline, presença/frequência, evidências, revisão humana e decisões que fundamentam os **certificados institucionais TDS**, preservando o Worker/KV e o contrato de emissão já existente.

O **Flutter é a experiência integrada**, não uma nova base acadêmica: oferece Minha área, continuar curso, inscrições, progresso, atividades, certificados e suporte a partir das autoridades correspondentes. Usa o LearnPress já existente onde for viável e seguro, sem reproduzir seu banco, mecanismos de quiz, editor ou emissão. Dados públicos, privados e institucionais devem ser claramente identificados.

**NÃO equivalem entre si:** `lp_enrollment` e `class_enrollment`; `lp_lesson_completed` e evidência de frequência; progresso do LearnPress e `StudyProgress` local da cartilha; quiz do EAD e prova validada do programa; certificado eventualmente apresentado pelo site e certificado institucional TDS. Converter um no outro exige regra aprovada, comprovação e comando autorizado, nunca inferência por abertura de tela ou vídeo.

## 2. Evidências em 18/10/2026 e limites de afirmação

| Ref | OBSERVED | O que **não** se comprovou |
|---|---|---|
| WP | WordPress 6.7.2, LearnPress ativo; `/minha-area/` e `/certificados/` devolvem HTTP 200 | Jornada de estudante logado, progresso e lista autenticada de certificados |
| API LP | REST anuncia `/learnpress/v1/token`, `courses/enroll`, `lessons/finish`, `quiz/start`, `quiz/finish`, `users` | Autorização, representação e idempotência reais desses comandos para o app |
| EAD | 11 ofertas LearnPress públicas; entre elas #1474 Automações com o Celular para o Pequeno Negócio e #1709 IA aplicada a Processos Internos | Vinculação dessas duas ofertas a CourseVersion TDS ou critérios de certificação institucional |
| TDS | 9 cursos em `/tutor-api/public/courses` e `/tutor-api/courses` | Mapa automático dos 11 cursos EAD para os 9 cursos TDS |
| Bridge | `/wp-json/tds-learning/v1/courses/1298/curriculum` público HTTP 404; PR #238 contém candidato de adapter | Adapter instalado/homologado em WordPress real ou autorização editorial pública |
| Flutter | `EadCatalogScreen`, percurso, player YouTube em QA; `CertificateWalletScreen` e `StudyProgressRepository` existentes | SSO, matrícula LP, progresso LP autenticado ou certificados LP unificados |
| QA | PR #248, 734 testes Flutter PASS e smoke Xiaomi do catálogo/percurso; vídeo QA sintético em PR #246 | Jornada real autenticada WP↔app↔API ou AAB de produção integrado |

Essas constatações são **snapshot**, não promessa de serviço ou teste completo; revalidar antes da execução. Consulte `docs/program/EAD_SITE_FIRST_EXPERIMENT_225.md`, `EAD_LEARNING_PATH_231.md`, relatórios PR #246/#248 e Epic #224.

## 3. Glossário que deve ser usado no código e nas telas

| Termo exposto | Identificador e autoridade | Definição |
|---|---|---|
| Conta EAD | `wp_user_id` (WordPress/LearnPress) | Identidade de acesso ao LMS. Não é automaticamente pessoa/vínculo institucional |
| Conta Tutor TDS | `tds_user_id` ou UUID existente (FastAPI) | Identidade de programa; não é token válido do WP |
| Curso EAD | `wp_course_id` (LearnPress) | Oferta LMS, grade publicada e conteúdo conforme políticas WP |
| Curso TDS e edição | `course_id` e `course_version_id` (FastAPI) | Identidade formal do currículo aprovado institucionalmente |
| Inscrição EAD | ID/status de inscrição LearnPress verificado | Direito de acesso à oferta no LMS, inclusive curso espontâneo |
| Matrícula institucional | `class_enrollments`, `membership_id`, `class_id` (FastAPI) | Vínculo em turma/programa, com regras próprias |
| Progresso no EAD | Lições e quizzes atribuídos ao usuário do LearnPress | Só o LMS altera seu estado primário |
| Progresso da cartilha | `StudyProgress` local e/ou eventos TDS autorizados | Ajuda a retomar estudo, não confirma conclusão EAD ou frequência |
| Frequência oficial | Registros revisados por fluxo TDS autorizado | Não nasce de tempo de vídeo, visualização de página ou quiz LP |
| Certificado oficial | Pedido/revisão/emissão/validação institucional FastAPI + Worker/KV | Único caminho de validade para o Programa TDS |
| Registro de conclusão no EAD | Resultado/certificado, **se comprovado** no LearnPress | Mostrar origem distinta, nunca chamar de certificado institucional por inferência |

## 4. Fronteiras de autoridade (comandos e consultas)

| Ação ou consulta | Escrita/decisão canônica | Leitura/projeção no app | Proibição |
|---|---|---|---|
| Publicar/editar curso, lição ou vídeo EAD | Editor + LearnPress, direitos explícitos | Catálogo, lição e vídeo autorizados | Segundo CMS no Flutter |
| Inscrever-se/retomar curso EAD | Endpoint autorizado LearnPress | Minha área e percurso autenticados | POST público inventado ou matrícula TDS automática |
| Marcar lição concluída | LearnPress, somente ação autorizada | Status atual de lição e avanço EAD | Registrar por autoplay, onPageFinished ou watch time |
| Quiz do LearnPress | Motor LearnPress e regras de acesso | Executar/retomar e mostrar resultado permitido | Copiar gabarito ou alterar nota pela IA |
| Cadastro e vínculo no programa | FastAPI/PostgreSQL | Perfil institucional e turmas | Trocar `wp_user_id` por CPF/nome/telefone |
| Frequência/baseline/evidências | Fluxo FastAPI com escopo e validação humana | Painel TDS separado | Tratar “concluído no EAD” como presença |
| Pedido/revisão/certificado oficial | API + fluxo humano + Worker/KV da Issue #5 | Carteira, status, verificação e download | Emissão automática pelo LearnPress ou clique |
| Certificado legado de WP, se existir | Origem legada auditada | Somente referência rotulada e verificável | Misturar com carteira institucional sem proveniência |

Dados derivados devem sempre carregar `source_system`, `source_id`, `observed_at` e escopo de usuário, em modelo a ser aprovado. Ausência de resposta da origem é **desconhecido/temporariamente indisponível**, não `0%`, `não matriculado` ou `certificado recusado`.

## 5. Minha área: contrato de experiência alvo

O aluno autentica-se no Tutor TDS, pode **vincular voluntariamente** sua conta EAD e deve ter uma interface clara mesmo antes do vínculo:

1. **Minha área:** qual conta está conectada, estado da vinculação EAD, cursos inscritos e ação “Continuar aula”; sem vínculo, mostrar CTA explícito e acesso público ao EAD.
2. **Meus cursos:** distinguir “Inscrição no EAD” de “Turma/programa TDS”, com ID/estado de origem e opções autorizadas.
3. **Progresso:** lições/quizzes LearnPress com percentual definido e calculado pelo próprio LMS; separado do progresso local da cartilha e da frequência TDS. Nunca somar percentuais distintos.
4. **Aulas e avaliações:** percurso nativo quando há autorização editorial, ou runtime LearnPress autenticado e confiável como alternativa; preservar mesmo `lesson_id`, matrícula, status e retorno contextual.
5. **Meus certificados:** lista de certificados TDS verificáveis e seus pedidos em separado de eventual conclusão/documento EAD, cada item com origem, emissor, estado e verificação.
6. **Tutor IA, cartilha e suporte:** continuar acessíveis no contexto autorizado do curso; IA não cria matrícula, nota nem certificação.
7. **Perfil/privacidade:** visualizar vínculos, revogar vínculo EAD, sair de todas as sessões necessárias e consultar direitos de dados; não misturar conta em aparelho compartilhado.

**Estratégia de UX:** primeiro reutilizar rotas/controles LearnPress de maneira segura, depois nativizar apenas telas de maior fricção com APIs documentadas. WebView é candidata, não aprovação automática: testar sessão, cookies, logout, foco, links, segurança e acessibilidade. Não prometer login único enquanto broker seguro e testes não existirem.

## 6. Identidade: decisão e controles mínimos

A conta institucional `tds_user_id` continua distinta de `wp_user_id`. Vinculação é dado transacional próprio, sujeito a auditoria e consentimento, com pares únicos por ambiente/tenant; nenhum vínculo por nome, telefone ou correspondência suposta de CPF.

**Design TARGET, não implementado:** iniciar vínculo autenticado na FastAPI; redirecionar a canal de autenticação EAD confiável (navegador do sistema, protocolo formal OIDC/OAuth com PKCE ou adaptador de troca de código de uso único sob auditoria), validar **prova recente das duas sessões**, `state`/`nonce`, origem e redirect URI permitidos, TTL curto, uso único, verificação contra replay/CSRF e confirmar a conta associada antes de gravar. Se o provedor WordPress não disponibilizar federação auditável, manter dois logins separados, explicitamente identificados; não criar SSO caseiro ou transplantar cookies pelo app.

**Vedado:** capturar senha WP no Flutter/FastAPI; guardar token de admin WP/API key no APK; transmitir JWT TDS ao WebView; compartilhar cookies entre perfis sem isolamento; converter WP user em institucional por similaridade cadastral; usar CPF/telefone/segredos como query param, logs ou eventos analíticos. Tokens exclusivos por audiência, TLS validado, armazenamento seguro, sessão revogável, throttling, RBAC, logs sanitizados.

**Abuso a testar:** account takeover por vincular conta de terceiro, troca A↔B no mesmo aparelho, reuso de código, 401/403, logout WP e TDS, expiração, vínculo revogado, diferença staging/prod, curso privado e acesso indevido por ID direto (IDOR).

## 7. Regras de consistência, operação e offline

- Uma operação muda **somente sua autoridade**; UI com optimistic state, se existir, nunca declara matrícula/conclusão antes da confirmação canônica.
- `GET` de curso/progresso autenticado deve ter cache por `environment + tds_user_id + wp_user_id` (ou chave derivada opaca), expiração, indicador de atualização e invalidação após mutation/logout/revogação. Sem cache compartilhado entre usuários.
- Mutações LMS exigem token do usuário e escopo real; somente após entender semântica de replay/idempotência do LearnPress considerar fila offline. Sem isso, offline permite **leitura local identificada**, não botão “Concluir lição” fictício.
- Retry com backoff, limite de tamanho, timeout e correlation id sanitizado; diferenciar `401` (precisa login), `403` (sem direito), `404` (não existe/não liberado), `409` (estado conflitante), `5xx` (instabilidade).
- Auditoria institucional nunca copia gabarito privado, payload de senha, cookie EAD, CPF, histórico completo de estudo ou chat para BI/Chatwoot.
- Deleção de conta TDS não apaga automaticamente a conta WP: mostrar abrangência e coordenar pedidos de privacidade por controlador dos dados; preservar somente retenções legais autorizadas.
- **Certificado TDS** permanece condicionado aos requisitos institucionais aprovados, incluindo baseline/frequência e revisão humana onde aplicáveis; PDF/registro EAD não substitui prova de frequência.

## 8. Consequências e limites

**Benefícios:** reuso do LMS e editor existentes, progresso fiel à origem, experiência menos fragmentada, atualização sem rebuild, preservação do backend TDS institucional e melhor suporte.

**Custos:** duas contas inicialmente possíveis, necessidade de vinculação/federação auditada, histórico de alunos a reconciliar com consentimento, dependência de políticas do LearnPress, matrículas com semânticas diferentes, suporte a revogação, testes E2E e documentação editorial.

**Pontos ainda UNKNOWN:** comportamento de `/minha-area/` e `/certificados/` com usuário sintético autenticado, modelos reais das respostas LP de progresso e certificados, capacidade de SSO do WP atual, configuração de inscrição espontânea, direitos de vídeos, integridade da grade de quizzes, consistência do plugin customizado `tds/v1`, correspondência das 11 ofertas com 9 CourseVersions.

**Não autoriza:** merge dos PRs #226→#248, implantação do plugin #238, publicação no EAD, modificação de contas/alunos, migração de banco, geração de AAB final ou promoção à Play. Cada uma exige seus próprios gates.

## 9. Encaminhamento verificável

O roteiro humano/agente e a matriz de testes estão em `LEARNPRESS_TDS_DELIVERY_RUNBOOK.md` e `LEARNPRESS_TDS_ACCEPTANCE_MATRIX.md`. Devem ser lidos com `AGENTS.md`, `docs/CURRENT_STATE.md`, `docs/DOMAIN_CONTRACT.md`, `docs/DECISIONS.md`, `TARGET_ARCHITECTURE.md`, `INTEROPERABILITY.md` e Issues #224/#229/#249.

**Regra de status:** cada PR e etapa deve distinguir **DECISION**, **OBSERVED**, **IMPLEMENTED**, **TESTED-LOCAL**, **TESTED-STAGING**, **TESTED-ANDROID**, **UNKNOWN/BLOCKED**. Nenhum teste sintético/CI constitui prova de dados reais, SSO real ou AAB pronto.

**Gates:** `MERGE_ALLOWED=NO`, `PRODUCTION_ALLOWED=NO`, `FORCE_PUSH_ALLOWED=NO` até autorizações separadas; revisão humana para ativação de matrícula, conclusão, dados e certificação.
