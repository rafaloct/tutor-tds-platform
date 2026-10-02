# Wave 2 — Dynamic Learning

Status: fatia 2A STAGING, aceite em `WAVE2A_ACCEPTANCE.md`; Wave 2 ainda PARTIAL.
Base: Wave 1 aprovada em `0081ab0`; preservar LearningContext v2,
matrícula contextual, fila e os três golden paths. Auditoria de código identifica
editor/publicação reais; não criar outro Studio ou outra representação de curso.

## Fatia 2A — publicação e consumo remoto

Curso/CourseVersion já persistem em `courses`, `course_versions` e
`course_version_transitions`. O snapshot JSON existente representa módulos em
`sections[]` e blocos/atividades em `messages[]`, com IDs e versões no servidor.
Tipos suportados: `bot`, `user`, `question`, `quiz`. Não ampliar formato nesta fatia.
Publicação é imutável; nova edição usa fork. Turma mantém seu course_version_id.
Não há necessidade demonstrada de nova migration/tabela/endpoint.

| Screen contract | Comportamento |
| --- | --- |
| Purpose | criar/publicar conteúdo remoto e recebê-lo no mesmo APK, preservando turmas anteriores |
| Actor | autor/professor ou creator do programa; coordenador autorizado publica; aluno consome |
| Required Context | AuthRepository; ProgramMembership editorial resolvida na API; LearningContext v2 no estudo matriculado |
| Reads | programas/permissões, rascunho/revisão, catálogo publicado, edição imutável da turma |
| Displays | catálogo e editor existentes; estado editorial/revisão; preview estático explicitamente sem progresso |
| Commands | criar, salvar, preview, enviar à revisão, publicar, fork; atualizar catálogo; abrir conteúdo/continuar turma |
| Writes | CourseVersion e transição auditada; cache público por API; evidência pelo fluxo contextual aprovado |
| Repositories | CourseEditorGateway/Repository e Fake dos testes; CourseRepository com HTTP/localLoader injetáveis; gateways/contexto da Wave 1 |
| Endpoints | GET /editor/context, /editor/courses, /editor/courses/{id}; POST /courses; PATCH /courses/{id}; POST /courses/{id}/{submit,publish,archive,versions}; GET /courses e rotas de turma existentes |
| Events | page_viewed/feature_used das rotas existentes; course_version_transitions registra ator; estudo mantém LearningEvent; atualizar catálogo não concede progresso |
| Loading State | espera contextual existente; impedir refresh concorrente; catálogo não faz a Home perder matrícula/contexto |
| Ready State | somente publicação remota válida; retorno do editor recarrega catálogo; atualização explícita durante a sessão |
| Empty State | lista remota vazia é válida e permanece vazia offline; não ressuscitar curso retirado |
| Offline State | edição ONLINE_ONLY; catálogo CACHE_READ no mesmo ambiente; turma CACHE_READ/OFFLINE_WRITE_SYNC já aprovados |
| Error State | 403 nega ação; 409 pede recarga sem sobrescrever revisão; falha de catálogo preserva cache do mesmo ambiente ou fallback de assets existente |
| Permissions | programa ativo e ownership do rascunho; publicação só coordenador/admin permitido; aluno não edita; seleção/cache não concede acesso |
| Acceptance Criteria | gate abaixo, negativas e regressões de cache/Home; mesma assinatura/hash do APK entre publicação e consumo |
| Must Not | rebuild para incluir conteúdo; trocar edição de turma pelo catálogo; misturar caches de APIs; resetar histórico; simular publicação/progresso |

Recorte isolado de catálogo público (02/10/2026): `REMOTE_CATALOG_ENABLED=false`
por padrão usa somente os nove assets locais, independentemente de
`TUTOR_API_URL`. Com flag true e URL de staging, o fluxo é GET /courses sem
login → cache por URL → assets. Sem rede, os nove assets complementam o cache
remoto por ID para que continuem disponíveis; um catálogo remoto vazio com a
flag ligada também recorre aos assets. Essa exceção opt-in **difere** do Empty
State de 2A, que preserva retirada editorial como lista vazia. Não promover
esta política de fallback para produção sem decidir explicitamente como
conciliar retirada editorial e garantia offline dos nove cursos. O QA separado
em `evidence/remote-catalog-qa-2026-10-02.json` não ativa LearningContext,
outbox, telemetria de jornada, certificados ou matrícula.

## Menores correções identificadas

1. `CourseRepository` usa chave global `courses:remote_cache:v1`. Evoluir para
   chave v2 por URL completa da API (trim e barras finais normalizados, mantendo
   caminho/ambiente). Cache v1 não tem origem comprovável: preservar a chave,
   mas não atribuí-la a uma API por inferência. Recarregamento online preenche v2;
   cache privado da turma continua intacto. Testar ambiente A/B, mesma URL com
   barra final, catálogo vazio e resposta inválida sem perder cache válido.
2. Home carrega catálogo somente na criação. Acrescentar comando de atualização
   no menu existente e atualizar após retorno do editor. Reusar estado/Future e
   esperas existentes, sem HTTP no widget. Serializar refresh; navegação inferior
   deve usar a lista recarregada. Matrícula/progresso não são reinicializados.

Referência visual: composição `9731628404551462355`, Home aluno (região 7) e
Home creator (região 11); índice das dez telas do projeto conferido e salvo em
`.stitch/project-index.json`, sem tela editorial independente identificada.
Home funcional `75ac62c1bb3241aba1b3092f908b7c5f` já em
cache. A imagem `9731628404551461273` foi inspecionada e mostra uma sessão de
Classroom, não um editor; registrada para Wave 3/4. Esta fatia mantém as telas
editoriais existentes e acrescenta ação utilitária no menu, sem nova tela visual.
Redesenho de Studio/Home creator exige referência/derivado próprio na sua fatia.

## Gate 2A

APK instalado, ainda sem o curso → professor cria/salva/preview → coordenador
publica v1 → mesmo APK atualiza catálogo e abre conteúdo → turma fixa v1 → aluno
registra estudo persistido → autor cria nova edição → coordenador publica v2 →
catálogo recebe v2 → turma anterior/reinício/cache preservam v1 e progresso →
nova turma recebe v2. Hash do APK deve permanecer igual durante publicação/consumo.

Comprovar JWT real, rascunho ausente do catálogo, aluno/autor sem permissão de
publicar, revisão obsoleta 409, dono/ambiente de cache e preservação do histórico
da Wave 1. Usar curso/atores sintéticos próprios em staging; não executar o smoke
legado que fixa VPS/programa e modifica todos os vínculos do catálogo.

Execução Android: oito processos, `author_v1`, `publisher_v1`, `learner_v1`,
`author_v2`, `publisher_v2`, `learner_after_v2`, `learner_offline`,
`learner_reconnect`; fase resolvida por checkpoint QA, mesmo APK. A última fase
verifica a fila criada offline em outro processo e reconexão sem duplicata;
o reinício ainda offline já possui evidência própria no gate da Wave 1.
Sete blocos bot exercitam publicação/leitura; ActivityAttempt segue na fatia 2B.

Fixture: autor e publicador têm User.role=student, com Membership editorial
teacher/coordinator. Operador administrativo permanece exclusivamente no host,
sem credenciais no APK e sem publicar cursos. Após cada publicação, usa APIs
legadas existentes para matrícula/turma; carga sintética de 120 segundos somente
no programa/curso QA, antes do primeiro estudo. A turma anterior e seus eventos
devem permanecer intactos. Nenhuma conta, curso ou evento de produção é usado.

Cada ensaio completo usa `qa-dynamic-course-<run_id>` e títulos identificados pela
execução, reutilizando os mesmos atores/programa sintéticos. O alvo deve estar
ausente no banco e no catálogo antes da instalação. Rascunhos de ensaios falhos
permanecem preservados e entram no baseline de hashes da próxima execução.
Isso permite revalidar criação/publicação no mesmo APK sem apagar evidências nem
retomar automaticamente uma fase incompleta. Não altera entidades do aplicativo.

Testes: repository/cache; Home widget/retorno; contrato editorial existente;
integração real de publicação com PostgreSQL/HTTPS/Android. Suíte completa somente
no gate ou se a extensão afetar o núcleo. Defaults de produção permanecem seguros.

## Limites e sequência da Wave 2

### Extensão física do gate 2A — 01/10/2026

Reutilizar as oito fases no POCO autorizado `ZT6HPRHQHATSEQPR`, modelo
`2311DRK48G`. `DYNAMIC_QA_ISOLATED_PACKAGE=true` cria somente em debug o
pacote `com.tutortds_cartilhas.dev.dynamicqa.r<run_id>`, rótulo Tutor TDS QA. Exige o
staging Cloud aprovado e run ID; defines sintéticos são proibidos no gate de
release. O runner exige pacote QA ausente e compara todos os APKs e metadados
de instalação dos aplicativos Play/DEV antes/depois, sem abrir suas sessões.
Cada execução nova tem sandbox própria; o primeiro ensaio físico usou o sufixo
fixo `.dev.dynamicqa`, preservado após falha. Não desinstalar, limpar dados ou
retomar automaticamente uma fase falha. Preservar evidências
e restaurar a rede inicial, inclusive em falha. Offline usa o mesmo teste
existente e não altera autorização. Aprovação deste recorte pode fechar apenas
`course_versioning_xiaomi`; revogação de cache, Evidence e emissão de certificados
continuam exigindo suas evidências próprias. Nenhuma promoção automática.

Recuperação excepcional registrada no run 3c2d38851f024a1eb50667aa86dc7ce0:
falha de leitura ADB ocorreu após instalar e antes de lançar qualquer fase.
Hash instalado/local e notLaunched=true foram conferidos antes de iniciar;
execução em subdiretório próprio, baseline novo somente leitura, sem recompilar,
reinstalar ou repetir fase Android. Original preservado. Esse procedimento
delimitado não autoriza retomar uma fase com mutações ou limpar checkpoints.

O gate 2A não encerra sozinho a Wave 2. Atividades `quiz/question` embutidas ainda
não persistem resposta por bloco como ActivityAttempt contextual; o leitor perde
IDs/versões de componentes e mantém posição/tempo. Auditar e fechar essa linhagem
na fatia seguinte reutilizando AssessmentAttemptRecord/Repository/Sync existentes,
antes de declarar aprendizagem dinâmica completa. Não creditar quiz oficial por
tempo de estudo. Preview atual é conferência estática, sem simulação de progresso.
Fluxo editorial de devolver revisão para correção também permanece fora de 2A;
qualquer extensão terá contrato/migration próprios e preservará snapshots.

Fronteira legada a tratar na próxima fatia: `SettingsScreen._logout` ainda limpa
`AssessmentSyncQueue` e o rascunho de check-in; perfil/estudos antigos não são todos
separados por usuário. O gate 2A recusa troca de conta se existirem essas pendências,
sem apagá-las para viabilizar o teste. A outbox contextual aceita na Wave 1 preserva
eventos identificados; esse aceite não se estende automaticamente às filas legadas.
