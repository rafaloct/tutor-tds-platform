# Tutor TDS API

Fundação local da API transacional. Nada deste diretório é publicado
automaticamente na VPS.

## Desenvolvimento

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".[test]"
$env:DATABASE_URL = "sqlite+pysqlite:///./local.db"
$env:JWT_SECRET = .\.venv\Scripts\python.exe -c "import secrets; print(secrets.token_hex(32))"
$env:CPF_PEPPER = .\.venv\Scripts\python.exe -c "import secrets; print(secrets.token_hex(32))"
.\.venv\Scripts\alembic.exe upgrade head
.\.venv\Scripts\uvicorn.exe app.main:app --reload
```

Ou use `docker compose up --build` para PostgreSQL 16 e a API na porta 8000.

Endpoints iniciais:

- `GET /live`: confirma somente que o processo HTTP está vivo, sem depender do banco.
- `GET /health`: readiness; confirma processo e conexão com o banco.
- `GET /courses`: lista somente cursos ativos, no contrato esperado pelo app.
- `GET /courses/{id}`: retorna um curso ativo ou 404.
- `POST /auth/register`: cria estudante sem persistir CPF em texto puro.
- `POST /auth/login`: autentica CPF e senha.
- `POST /auth/refresh`: rotaciona o refresh token de uso único.
- `GET /auth/me`: valida o access token e retorna apenas dados públicos.
- `DELETE /auth/me`: exclui a conta do estudante e seus dados transacionais,
  incluindo sessões, matrículas, eventos, analytics e referências de certificado.
- `POST /events`: recebe aprendizagem e telemetria tipada (`page_viewed`,
  `resource_opened`, `feature_used`) de forma autenticada e idempotente. O
  payload de telemetria aceita somente um identificador técnico estável.
- `GET /events`: lista somente eventos do usuário autenticado, com filtro por
  curso e paginação limitada a 100 itens.
- `POST /admin/institutions`: cria uma instituição (somente administrador).
- `POST /admin/programs`: cria programa ligado a uma instituição.
- `POST /admin/programs/{id}/courses/{course_id}`: oferta curso no programa.
- `PUT /admin/programs/{id}/courses/{course_id}/workload`: configura a carga
  horária planejada daquela oferta.
- `POST /admin/programs/{id}/memberships`: associa usuário e função ao programa.
- `POST /admin/enrollments`: matricula somente quando participação e oferta existem.
- `GET /admin/hierarchy`: consulta a hierarquia institucional configurada.
- `POST /admin/classes`: cria turma somente com professor vinculado ao programa.
- `POST /admin/classes/{id}/students/{user_id}`: associa matrícula ativa à turma.
- `POST /admin/classes/{id}/monitors/{user_id}`: associa monitor do programa.
- `GET /classes/{id}`: entrega a turma somente ao administrador, professor ou
  monitor associado.
- `GET /classes`: descobre as turmas visíveis pelos vínculos do usuário, sem
  expor a lista de participantes.
- `GET /classes/{id}/dashboard`: painel de exceções para professor, monitor ou
  administrador, com horas, progresso esperado e alertas por estudante.
- `GET /users/{id}/hours?course_id=...`: consolida uso ativo e horas validadas
  para o próprio estudante ou sua equipe pedagógica autorizada.
- `GET /analytics/usage`: agrega páginas, recursos e funcionalidades por até
  90 dias, preservando `course_id`. Estudante vê os próprios eventos; professor e monitor precisam
  informar uma turma associada; administrador pode usar escopo global ou filtros.
- `GET /admin/sync/status`: saúde da fila banco → Sheets (somente administrador).
- `POST /certificates/references`: registra idempotentemente no PostgreSQL a
  referência emitida pelo Worker/KV, vinculada a programa e turma opcional.
- `GET /certificates`: lista a carteira remota do estudante autenticado.

O registro do certificado congela nome do titular, curso, instituição e carga
horária no instante da emissão. O KV continua sendo a fonte da verificação
pública; a API aceita somente URLs sob `CERTIFICATE_VERIFICATION_URL_PREFIX`
(HTTPS e com `/` final), evitando referências arbitrárias.

### Mídia e Creator (Onda 4)

- `POST/PATCH /admin/media`: creator vinculado cria/edita somente rascunho
  próprio; coordenador do programa ou admin também pode editar.
- `POST /admin/media/{id}/publish`: somente coordenador vinculado ou admin;
  exige direitos confirmados.
- `GET /media` e `GET /media/{id}`: somente publicados e respeitando
  visibilidade/matrícula; nunca retornam `master_drive_file_id`.
- `GET /creators/me/media` e `/creators/me/analytics`: acervo e resumo do
  creator autenticado.
- `POST /media/{id}/playback-authorizations`: devolve grant curto sob a base
  pública HTTPS configurada em `PUBLIC_API_BASE_URL`; essa base inclui qualquer
  prefixo removido pelo reverse proxy, como `/tutor-api`.
- `POST /events`: também aceita `video_started`, `video_checkpoint`,
  `video_completed`, `video_followup_completed` e `video_saved`. O
  `LearningEvent` continua sendo a fonte idempotente e sincronizável; a
  projeção `media_events` é gravada na mesma transação.
- `POST /admin/creator-scores/calculate`: score versionado e reprodutível por
  janela, sem efeito financeiro.
- `POST /admin/ledger/simulate` e `GET /admin/ledger`: ledger append-only,
  exposto somente quando `COMMERCIAL_SIMULATION_ENABLED=true`.

O adapter de pagamento permanece obrigatoriamente `disabled`: não existem
chamadas externas, cobranças, payouts ou webhooks nesta fase. YouTube usa
`youtube-nocookie`; `external_hls` exige HTTPS e rejeita Google Drive. Drive é
somente acervo/master e sua referência nunca é retornada ao aluno.

Em staging/produção, `PUBLIC_API_BASE_URL` é obrigatória, HTTPS, sem query,
fragmento ou credenciais. Ela é a fonte autoritativa para URLs de playback e
não é substituída por headers encaminhados pelo cliente.

## Espelho Google Sheets

O worker usa uma aba exclusiva (padrão `EventosAPI`) e nunca envia CPF, telefone
ou nome. Evento, usuário e sessão são pseudonimizados por HMAC com
`SHEETS_PSEUDONYM_SECRET`. A coluna A contém o pseudônimo do `event_id` e impede duplicatas mesmo
quando há timeout depois do append. Para executar uma vez ou reconciliar:

```powershell
$env:GOOGLE_SHEET_ID = "id-da-planilha"
$env:GOOGLE_SERVICE_ACCOUNT_FILE = "C:\caminho\service-account.json"
python -m app.sync_worker --once
python -m app.sync_worker --reconcile
```

A planilha precisa ser compartilhada como editora com o `client_email` da conta
de serviço e a aba configurada em `GOOGLE_SHEET_RANGE` deve existir. Em Docker,
injete preferencialmente `GOOGLE_SERVICE_ACCOUNT_JSON` como secret. O retry usa
backoff e para após três tentativas; a reconciliação é somente leitura.
Na exclusão de conta, tombstones são criados antes do cascade. O worker limpa
as linhas correspondentes no Sheets e preserva somente o estado auditável do
purge, com retry idempotente.

### Evidence Engine

Sessões de turma usam token curto (10 minutos), rotativo e armazenado apenas
como SHA-256. Check-in/out, importações explícitas, revisão humana, exceções e
relatório de fechamento são auditáveis. Importações WhatsApp/Drive aceitam
somente digest, referência privada e metadados estruturados; conteúdo bruto,
OAuth e inferência automática de presença permanecem desativados.

Antes de usar os endpoints administrativos pela primeira vez, crie o primeiro
administrador no terminal interativo do container. CPF e senha são solicitados
sem aparecerem no comando nem serem gravados no repositório:

```powershell
docker compose exec api python -m app.bootstrap_admin `
  --name "Administrador Tutor TDS" `
  --phone "63999990000"
```

O bootstrap é repetível com as mesmas credenciais e não duplica a conta. Em
automação sem terminal, `BOOTSTRAP_ADMIN_CPF` e `BOOTSTRAP_ADMIN_PASSWORD`
podem ser injetadas apenas durante a execução e removidas em seguida.

Para carregar ou atualizar explicitamente as cartilhas locais:

```powershell
$env:DATABASE_URL = "sqlite+pysqlite:///./local.db"
.\.venv\Scripts\python.exe -m app.course_seed `
  ..\cartilhas_app\assets\data\lessons
```

O importador valida todos os arquivos antes de gravar e faz upsert por ID. Ele
não é executado automaticamente no boot da API.

`JWT_SECRET` e `CPF_PEPPER` são obrigatórios, independentes e devem ter pelo
menos 32 caracteres aleatórios. O CPF é validado e persistido somente como
HMAC-SHA256; senhas usam Argon2id. Não reutilize valores de desenvolvimento em
staging ou produção.

Antes de qualquer staging, substitua as credenciais locais, configure TLS pelo
proxy do Dokploy e execute backup/restore do banco de teste.

## Produção na VPS

`docker-compose.production.yml` publica a API por Traefik em
`https://ead.ipexdesenvolvimento.cloud/tutor-api`, mantém o PostgreSQL em rede
interna e serve as páginas públicas de privacidade/exclusão no domínio do app.
O arquivo `.env` produtivo permanece somente na VPS, com permissão restrita, e
deve definir `POSTGRES_PASSWORD`, `JWT_SECRET` e `CPF_PEPPER` independentes.
