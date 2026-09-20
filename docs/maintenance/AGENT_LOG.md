# Tutor TDS — Log do Agente

> Registro contínuo de decisões, alterações e pendências durante o desenvolvimento assistido por agente.

---

## [2026-09-19] — Onda 0: Auditoria Técnica e Configuração do Repositório

**Agente:** Antigravity (Onda 0)
**Fase:** ONDA 0 — Auditoria e Documentação

### Tarefa
Primeira leitura completa da base de código do Tutor TDS, identificação da stack, integrações, riscos e criação de toda a documentação de base.

### Arquivos Criados
- `.gitignore` (raiz do monorepo)
- `docs/maintenance/CURRENT_ARCHITECTURE.md`
- `docs/maintenance/CURRENT_DATA_FLOW.md`
- `docs/maintenance/INTEGRATIONS.md`
- `docs/maintenance/SECURITY_FINDINGS.md`
- `docs/maintenance/TECH_DEBT.md`
- `docs/maintenance/MIGRATION_PLAN.md`
- `docs/maintenance/ACCEPTANCE_CRITERIA.md`
- `docs/maintenance/AGENT_LOG.md` (este arquivo)
- `docs/infrastructure/SSH_ACCESS.md`
- `docs/infrastructure/VPS_INVENTORY.md` (parcial — aguarda SSH)

### Arquivos Analisados (somente leitura)
- `cartilhas_app/pubspec.yaml`
- `cartilhas_app/lib/main.dart`
- `cartilhas_app/lib/config/app_config.dart`
- `cartilhas_app/lib/models/cartilha.dart`
- `cartilhas_app/lib/screens/welcome_screen.dart`
- `cartilhas_app/lib/screens/home_screen.dart`
- `cartilhas_app/lib/screens/onboarding_screen.dart`
- `cartilhas_app/lib/services/anything_llm_service.dart`
- `cartilhas_app/lib/services/data_sync_service.dart`
- `cartilhas_app/lib/features/certificates/data/certificate_service.dart`
- `cartilhas_app/lib/features/certificates/models/certificate_record.dart`
- `cartilhas_app/lib/features/study_ai/data/study_ai_service.dart`
- `cartilhas_app/lib/features/study_ai/models/study_models.dart`
- `cartilhas_app/lib/genui/genui_renderer.dart`
- `cartilhas_app/cloudflare/tutor-tds-gateway/src/index.js`
- `cartilhas_app/nginx.conf`
- `cartilhas_app/docker-compose.yml`
- `cartilhas_app/PRODUCTION_RELEASE.md`
- `cartilhas_app/.gitignore`
- `google_apps_script.js`
- `deploy_dokploy.sh`
- `registro softawre/dump_Formulário de Comunicado Programa de Computador - Tutor TDS.docx.txt`

### Decisões Tomadas
1. **Git inicializado** na raiz do monorepo (`Cartilhas (Versão Chatbot)/`).
   - Razão: o diretório era um snapshot sem histórico. Git é pré-requisito de qualquer fluxo de CI/CD.
   - Risco: nenhum. Reversível com `rm -rf .git`.

2. **`.gitignore` criado na raiz** do monorepo cobrindo Flutter, Android (keystore), Node, logs e segredos.
   - Razão: a proteção do keystore deve existir desde o primeiro commit.

3. **Documentação criada em `docs/`** sem alterar nenhum código funcional.
   - Razão: Onda 0 é somente leitura e documentação.

### Testes Realizados
- Nenhuma alteração de código; nenhum teste executado nesta onda.

### Riscos Identificados
- CPF em plaintext para Google Apps Script (🟠 Alto)
- Sem banco relacional centralizado (🔴 Crítico)
- Sem autenticação JWT (🔴 Crítico)
- Catálogo de cursos no APK (🔴 Crítico)
- VPS não auditada diretamente (pendente SSH)

### Custo Criado
- Nenhum. Todas as ações desta onda são gratuitas e reversíveis.

### Serviços Externos Acionados
- Nenhum.

### Ações Humanas Necessárias
1. **Autorização SSH para a VPS** — ver formato de solicitação abaixo.
2. **Revisão e aprovação do Plano de Migração** (MIGRATION_PLAN.md) antes de iniciar a Onda 1.

### Pendências para a Próxima Onda
- [ ] Auditoria da VPS via SSH (requer autorização do usuário)
- [ ] Criar `docs/infrastructure/VPS_INVENTORY.md` (requer SSH)
- [ ] Criar `docs/infrastructure/DOKPLOY_ARCHITECTURE.md` (requer SSH)
- [ ] Commit inicial do repositório
- [ ] Iniciar Onda 1: projeto da API REST Tutor TDS

### Próxima Ação Automática
Aguardando autorização SSH para continuar com o inventário da VPS.
Sem o SSH, iniciar o **projeto da API Tutor TDS** (Onda 1) com:
- Modelagem do banco PostgreSQL
- Estrutura da API REST (FastAPI ou Node.js/Express)
- Docker Compose para desenvolvimento local

---

_Adicionar nova entrada para cada sessão ou conjunto significativo de alterações._

---

## [2026-09-19] - Consolidação autônoma da Onda 0

**Agente:** Codex

### Concluído

- Leitura integral da especificação visual de 34 páginas.
- Validação independente da documentação criada pelo Antigravity.
- Correção da contradição sobre CPF no fluxo legado do Google Apps Script.
- Instalação isolada do Flutter 3.44.9/Dart 3.12.2 e criação do junction `C:\Dev\tutor-tds`.
- `flutter analyze` sem achados; 14 testes Flutter e 14 testes do gateway aprovados.
- Acesso SSH dedicado validado e auditoria somente leitura da VPS concluída.
- Provider do Tutor confirmado como OpenRouter/Gemini; DeepSeek proibido no plano e não ativo no AnythingLLM do app.
- Topologia, riscos, backups e fluxo de deploy documentados.

### Bloqueios de produção

- Log de aproximadamente 235,9 GB exige correção controlada.
- Firewall/bindings exigem plano e rollback antes de alteração.
- Backup de aplicação ainda não foi demonstrado.

### Primeiro incremento visual seguro

- Criado o componente compartilhado `TdsWaitExperience` com região semântica acessível, skeleton estático e dica pedagógica local.
- Substituídos spinners vazios na Home, no Tutor IA legado, no Tutor GenUI e nos materiais de estudo.
- Nenhuma chamada de IA foi adicionada e nenhuma porcentagem fictícia é exibida.
- Validação: `flutter analyze` sem achados e suíte completa com 15 testes aprovados.

### Tutor contextual e início orientado

- Cabeçalho e campo de mensagem agora identificam o conteúdo em estudo e o modo da conversa.
- Adicionadas três ações iniciais locais: explicação simples, exemplo prático do Tocantins e prática com feedback.
- Removido o envio automático de contexto ao abrir o Tutor; a primeira chamada ocorre somente após ação explícita do estudante.
- Bloqueado envio concorrente enquanto uma resposta está em andamento.
- Validação: `flutter analyze` sem achados e suíte completa com 16 testes aprovados.

### Continuidade local de estudo

- Persistência local por cartilha para seção, mensagem, estado da pergunta, respostas acumuladas e conclusão.
- A Home agora apresenta a última cartilha como próxima ação, com progresso e retomada direta.
- Estados corrompidos ou incompatíveis são ignorados com fallback seguro para o início da cartilha.
- Escritas de progresso são serializadas para preservar a ordem mesmo durante navegação rápida.
- Validação: `flutter analyze` sem achados e suíte completa com 19 testes aprovados.

### Configuração explícita das atividades

- A assinatura cromática TDS foi consolidada em um componente baseado nos tokens de `AppTheme`.
- Flashcards, quiz e simulado agora exibem fonte, dificuldade e quantidade antes da chamada de IA.
- Resumos exibem fonte e tamanho antes da geração.
- Os controles têm rolagem horizontal segura em telas estreitas e teste de interação.
- O contrato de geração é testado para garantir o envio de fonte, dificuldade e quantidade.
- Validação: `flutter analyze` sem achados e 21 testes aprovados.

### Autoavaliação dos cartões

- A sessão de flashcards mostra a cartilha de origem junto ao material gerado.
- As escolhas “Eu lembrei” e “Revisar novamente” agora mantêm contadores mutuamente consistentes.
- O estado é apresentado em componente acessível e coberto por widget test.
- Validação: `flutter analyze` sem achados e 22 testes aprovados.

### Feedback pedagógico do quiz

- O retorno imediato reúne acerto/erro, explicação, cartilha de origem e próxima ação.
- A orientação muda na última questão para encaminhar o estudante ao resultado e à revisão.
- O bloco usa região semântica dinâmica e não realiza chamada adicional de IA.
- Validação: `flutter analyze` sem achados e 23 testes aprovados.

### Persistência e retomada offline de resumos

- Criado o repositório local `StudySummaryRepository` e modelo `SavedStudySummary` sobre SharedPreferences.
- Armazenados ID/título da cartilha, tamanho selecionado, conteúdo estruturado e data da síntese.
- Ao abrir a tela de resumo, se houver resumo salvo, o estudante pode escolher entre "Abrir último resumo" ou "Gerar novo resumo".
- Nenhuma chamada de IA é disparada automaticamente ao abrir a tela.
- Corrupção de dados locais é tratada com fallback seguro para a tela inicial.
- Exibição de cabeçalho informativo de conteúdo offline quando visualizando material salvo.
- Coberto por testes unitários de repositório/serialização e testes de widget da tela de resumo.
- Validação: `flutter analyze` sem achados e 30 testes aprovados.

---

## [2026-09-20] - Retomada offline de avaliações

**Agentes:** Antigravity e Codex

### Concluído

- Criados `AssessmentAttempt` e `AssessmentAttemptRepository` para quiz e simulado.
- A tentativa mantém cartilha, modo, dificuldade, questões geradas, respostas, posição, cronômetro, pontuação, temas de revisão e datas.
- Tentativas em andamento são retomadas sem nova chamada de IA; resultados concluídos também podem ser reabertos offline.
- A Home compara as datas locais e prioriza a próxima ação mais recente entre cartilha e avaliação.
- Corrigido o seletor de quantidade para aceitar decks cujo total retornado difere das opções predefinidas.
- Gravações rápidas e atualizações do cronômetro são serializadas para impedir sobrescrita por estado antigo.
- Testes ajustados para rolagem real da avaliação e para títulos que aparecem tanto na próxima ação quanto no catálogo.

### Validação

- `flutter analyze --no-pub`: sem achados.
- Suíte Flutter completa: 37 testes aprovados.
- Nenhuma chamada automática de IA foi adicionada.
- VPS e produção não foram alteradas.

### Fila local idempotente de eventos

- Criados `LearningEvent` e `LearningEventQueue` para início e conclusão real de cartilhas.
- `event_id` determinístico por sessão/tipo impede duplicação em retries.
- A fila é serializada, tolera armazenamento corrompido e limita-se aos 500 eventos mais recentes.
- O payload local não contém nome, telefone ou CPF e ainda não é transmitido para nenhum servidor.
- O Google Apps Script legado permanece isolado e inalterado até a API autenticada estar disponível.
- Validação: `flutter analyze --no-pub` sem achados e 40 testes aprovados.

### Catálogo remoto com fallback offline

- A Home passou a usar `CourseRepository` em vez de carregar diretamente uma lista fixa de assets.
- `TUTOR_API_URL` é opcional: vazia não gera chamada de rede e preserva o comportamento atual.
- Quando configurado, o cliente consulta `GET /courses`, valida catálogo não vazio, salva cache e ordena os cursos.
- Falhas remotas usam primeiro o último cache válido e depois os nove assets embarcados.
- A validação de produção rejeita `TUTOR_API_URL` não HTTPS quando houver valor.
- Validação: configuração de exemplo aprovada e suíte Flutter completa com 43 testes.

### Fundação local da API Tutor TDS

- Criado o projeto `api/` com FastAPI, SQLAlchemy, Alembic e configuração por ambiente.
- A migration inicial cria as tabelas mínimas da Onda 1: institutions, programs,
  users, sessions, enrollments, learning_events, certificates e sync_log, além
  do catálogo de courses.
- `GET /health` consulta de fato o banco; `GET /courses` entrega somente cursos
  ativos no contrato esperado pelo Flutter.
- Docker Compose local fornece PostgreSQL 16 e executa migrations antes da API.
- Upgrade e downgrade foram exercitados em SQLite temporário; o modelo ORM e a
  migration possuem o mesmo conjunto de tabelas.
- Validação local: 3 testes Python aprovados, bytecode compilado e
  `docker compose config` válido.
- O SQL PostgreSQL foi gerado offline; o teste integrado em container ficou
  pendente porque o daemon do Docker Desktop local não estava em execução.
- Nenhuma publicação, conexão com staging ou alteração na VPS foi realizada.

### Importação do catálogo para a API

- Adicionado importador explícito e idempotente de cartilhas JSON, sem carga
  automática no boot da API.
- Os nove assets atuais foram validados e importados em banco efêmero (`9/9`).
- Criado `GET /courses/{id}`, que omite cursos inativos e responde 404 para IDs
  inexistentes.
- Validação local ampliada para 6 testes Python aprovados.

### Autenticação segura da API

- Criados registro, login, rotação de refresh token e endpoint autenticado
  `/auth/me`.
- CPF é normalizado, validado e persistido somente como HMAC-SHA256 com
  `CPF_PEPPER`; respostas não expõem CPF, telefone ou credenciais.
- Senhas usam Argon2id via pwdlib; access JWT expira em 15 minutos por padrão.
- Refresh tokens são aleatórios, persistidos somente como digest, rotacionados
  sob lock transacional e rejeitados após o primeiro uso.
- `JWT_SECRET` e `CPF_PEPPER` são obrigatórios no startup e não possuem valor
  produtivo padrão.
- Adicionada migration reversível `20260920_0002` para o digest de senha.
- Erros de validação foram sanitizados para não repetir valores recebidos.
- Validação local: 14 testes Python aprovados, `compileall`, SQL PostgreSQL
  offline e configuração Compose aprovados.

### Ingestão autenticada de LearningEvents

- Criados `POST /events` e `GET /events`, ambos protegidos por access token.
- `user_id` é derivado exclusivamente do JWT e nunca aceito no payload.
- Retries idênticos retornam sucesso sem duplicar; colisões de conteúdo ou de
  outro usuário retornam 409.
- A listagem é isolada por estudante, aceita filtro de curso e limita a página
  a no máximo 100 eventos.
- Apenas `lesson_started` e `lesson_completed` são aceitos nesta etapa; o worker
  do Google Sheets e a transmissão da fila Flutter continuam desativados.
- Validação local: 19 testes Python aprovados e bytecode compilado.

### Fundação do cliente de autenticação Flutter

- Criados `AuthRepository`, modelos de sessão e `SecureAuthTokenStore` para
  register, login, refresh e `/auth/me`.
- Access e refresh tokens são gravados juntos por `flutter_secure_storage`;
  senha nunca é persistida.
- Uma resposta 401 executa no máximo um refresh e repete a requisição uma vez;
  chamadas concorrentes compartilham a mesma renovação.
- Refresh rejeitado limpa somente a sessão segura da API. Respostas remotas e
  erros de plataforma não são expostos ao estudante.
- `TUTOR_API_URL` vazia preserva o modo offline sem chamada de rede.
- O repositório foi registrado no Provider, mas o onboarding e a fila de eventos
  ainda não o utilizam.
- Validação: `flutter analyze` limpo, 50 testes Flutter aprovados, configuração
  de produção aprovada e build Web concluído.
- O dry-run opcional de WebAssembly ainda alerta sobre casts no pacote externo
  `flutter_tts 4.2.5`; a compilação JavaScript usada atualmente foi concluída.

### Conta online opcional no onboarding

- A WelcomeScreen mostra criar conta e login somente quando `TUTOR_API_URL`
  está configurada; sem API, o layout e o fluxo offline permanecem iguais.
- Criar conta reutiliza nome, WhatsApp e CPF já validados e solicita senha em
  campo obscurecido. Login solicita apenas CPF e senha.
- A senha não é persistida nem repetida em mensagens de erro; loading e erros
  são anunciados visualmente e por região semântica.
- O uso sem conta continua explícito. Login bem-sucedido segue para a decisão
  de privacidade e não grava novamente o CPF em SharedPreferences.
- Textos de privacidade passaram a separar cadastro online, acompanhamento
  pedagógico e emissão de certificado. A tela de consentimento tornou-se
  rolável para telas menores.
- Validação: `flutter analyze` limpo, 54 testes Flutter aprovados.

### Sincronização autenticada da fila de LearningEvents

- A fila local passou a enviar `POST /events` somente quando a API está
  configurada, existe consentimento e há uma sessão segura disponível.
- O envio reutiliza `AuthRepository.authorized`, incluindo uma única renovação
  e repetição em resposta 401, sem criar um segundo fluxo de autenticação.
- Somente respostas 200 ou 201 removem o `event_id` confirmado. Respostas 409,
  5xx e exceções preservam o evento atual e os seguintes e interrompem o lote.
- Flushes concorrentes compartilham a mesma operação, evitando transmissão
  duplicada. Enfileiramento e remoção continuam serializados no armazenamento.
- O Google Apps Script legado, o worker do Google Sheets e a infraestrutura
  remota permaneceram inalterados.
- Validação: 63 testes Flutter aprovados e `dart analyze lib test` sem
  achados. O comando `flutter analyze --no-pub` foi tentado, mas o servidor de
  análise do SDK encerrou antes da análise por JSON LSP truncado neste caminho
  do Windows.

### Retomada automática da sincronização

- Eventos pendentes agora tentam sincronizar no primeiro frame do aplicativo e
  sempre que ele volta ao primeiro plano.
- O gatilho reutiliza o mesmo flush serializado; retomada do app e evento novo
  não criam transmissões paralelas nem um segundo fluxo de autenticação.
- Falhas ao consultar consentimento, sessão, armazenamento ou rede também são
  contidas pelo serviço e preservam a fila para a retomada seguinte.
- Teste de ciclo de vida demonstra uma falha 503 no primeiro frame, preservação
  local e envio bem-sucedido após `paused`/`resumed`.
- Validação: 64 testes Flutter aprovados e `dart analyze lib test` sem achados.

### Autorização por função na API

- Criada uma dependência RBAC reutilizável que autentica o JWT antes de validar
  a função autorizada e responde 403 para usuários autenticados sem permissão.
- `POST /events` e `GET /events` pessoais foram limitados a estudantes, mantendo
  professor, monitor e administrador autenticáveis para os recursos futuros de
  gestão sem permitir que usem endpoints destinados ao estudo do aluno.
- Testes parametrizados demonstram a distinção entre `student`, `teacher`,
  `monitor` e `admin` sem depender de infraestrutura ou credenciais externas.
- Validação: 22 testes Python aprovados e `compileall` concluído.

### Integridade da hierarquia institucional

- A hierarquia agora liga explicitamente instituição, programa, oferta de
  curso, participação do usuário no programa e matrícula.
- A função organizacional passou a existir na associação usuário-programa,
  permitindo que a mesma pessoa participe de programas distintos sem depender
  apenas da função global da conta.
- Novas matrículas exigem simultaneamente uma oferta do curso pelo programa e
  uma participação do usuário naquele programa, com unicidade por tripla.
- A migration `20260920_0003` retroassocia matrículas preexistentes a uma
  instituição/programa legado, sem descartar ou deixar registros órfãos.
- Validação: upgrade, backfill e downgrade exercitados; SQL PostgreSQL gerado
  offline; 23 testes Python aprovados e `compileall` concluído.

### Operação administrativa da hierarquia

- Adicionados endpoints protegidos por função global `admin` para criar
  instituições e programas, ofertar cursos, associar usuários com função local
  e matricular somente quando oferta e participação ativa existem.
- `GET /admin/hierarchy` permite auditar a configuração institucional sem
  consultar o PostgreSQL manualmente.
- Criado bootstrap repetível do primeiro administrador. CPF e senha são lidos
  de prompt oculto ou variáveis transitórias, nunca de argumentos de linha de
  comando nem de valores versionados.
- O README documenta a sequência operacional para container local ou futuro
  console do Dokploy; nenhuma conexão remota foi necessária nesta etapa.
- Validação: 26 testes Python aprovados, `compileall` e
  `docker compose config --quiet` concluídos.

### Hierarquia de turmas e equipe pedagógica

- A migration `20260920_0004` adiciona turmas, estudantes da turma e monitores,
  ligando cada turma a uma oferta real de curso dentro de um programa.
- O professor precisa ter participação ativa com função `teacher`; monitores
  precisam de função `monitor`; estudantes precisam de matrícula ativa no mesmo
  programa e curso.
- Chaves compostas preservam a linhagem também no PostgreSQL: uma associação
  manual inconsistente entre turma, programa, curso, usuário e matrícula é
  rejeitada pelo banco, não apenas pela API.
- Administradores criam e compõem turmas. A consulta da turma aceita somente
  administrador global, professor responsável ou monitor associado; estudantes
  não recebem a lista da turma.
- Validação: 27 testes Python aprovados, migration com upgrade/downgrade,
  `compileall` e SQL PostgreSQL offline concluídos.
