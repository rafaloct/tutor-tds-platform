# Tutor TDS API

Fundação local da API transacional. Nada deste diretório é publicado
automaticamente na VPS.

## Desenvolvimento

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".[test]"
$env:DATABASE_URL = "sqlite+pysqlite:///./local.db"
.\.venv\Scripts\alembic.exe upgrade head
.\.venv\Scripts\uvicorn.exe app.main:app --reload
```

Ou use `docker compose up --build` para PostgreSQL 16 e a API na porta 8000.

Endpoints iniciais:

- `GET /health`: confirma processo e conexão com o banco.
- `GET /courses`: lista somente cursos ativos, no contrato esperado pelo app.
- `GET /courses/{id}`: retorna um curso ativo ou 404.

Para carregar ou atualizar explicitamente as cartilhas locais:

```powershell
$env:DATABASE_URL = "sqlite+pysqlite:///./local.db"
.\.venv\Scripts\python.exe -m app.course_seed `
  ..\cartilhas_app\assets\data\lessons
```

O importador valida todos os arquivos antes de gravar e faz upsert por ID. Ele
não é executado automaticamente no boot da API.

Antes de qualquer staging, substitua as credenciais locais, configure TLS pelo
proxy do Dokploy e execute backup/restore do banco de teste.
