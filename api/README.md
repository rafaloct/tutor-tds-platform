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
