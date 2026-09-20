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

- `GET /health`: confirma processo e conexão com o banco.
- `GET /courses`: lista somente cursos ativos, no contrato esperado pelo app.
- `GET /courses/{id}`: retorna um curso ativo ou 404.
- `POST /auth/register`: cria estudante sem persistir CPF em texto puro.
- `POST /auth/login`: autentica CPF e senha.
- `POST /auth/refresh`: rotaciona o refresh token de uso único.
- `GET /auth/me`: valida o access token e retorna apenas dados públicos.
- `POST /events`: recebe `lesson_started` e `lesson_completed` autenticados e
  idempotentes.
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
- `GET /users/{id}/hours?course_id=...`: consolida uso ativo e horas validadas
  para o próprio estudante ou sua equipe pedagógica autorizada.

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
