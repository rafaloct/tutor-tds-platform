# Handoff para Antigravity IDE

Copie o bloco abaixo como o próximo prompt do Antigravity.

```text
Continue autonomamente a evolução produtiva do Tutor TDS neste repositório.

CONTEXTO OBRIGATÓRIO
- Workspace: C:\Users\Usuario\Downloads\Cartilhas (Versão Chatbot)\Cartilhas (Versão Chatbot)
- Branch atual: codex/onda-0-consolidacao
- Leia primeiro docs/maintenance/MIGRATION_PLAN.md,
  docs/maintenance/ACCEPTANCE_CRITERIA.md,
  docs/maintenance/SECURITY_FINDINGS.md e docs/maintenance/AGENT_LOG.md.
- Preserve todo trabalho existente. Antes de editar, execute git status e git log -6 --oneline.
- NÃO use DeepSeek. NÃO altere nem remova modelos do Ollama compartilhado.
- NÃO acesse ou modifique VPS, Dokploy, produção, firewall, containers remotos,
  logs remotos ou credenciais. Trabalhe apenas localmente.
- NÃO altere o Google Apps Script legado nem o Cloudflare Worker de certificados.
- Economize contexto: inspecione somente arquivos relacionados, execute testes focados
  durante a implementação e a suíte completa apenas ao fechar a fatia.

ESTADO ATUAL VALIDADO
- Commit baa51a0: importador idempotente dos 9 cursos e GET /courses/{id}.
- Commit 6ee89db: FastAPI + SQLAlchemy + Alembic + Compose PostgreSQL.
- Commit a947068: Flutter consulta TUTOR_API_URL com cache e fallback local.
- Commit 34b328e: fila local idempotente de LearningEvents.
- Commit f295f14: retomada offline de quiz/simulado.
- API local: 14 testes Python aprovados; migrations upgrade/downgrade aprovadas em SQLite;
  SQL PostgreSQL gerado offline; docker compose config válido.
- Autenticação local concluída: registro, login, refresh rotativo e `/auth/me`,
  com CPF em HMAC-SHA256, senha Argon2id e erros de validação sanitizados.
- Flutter: baseline de 43 testes e flutter analyze limpo no último fechamento.
- Docker Desktop estava instalado, mas o daemon não estava rodando. Não marque teste
  integrado PostgreSQL como concluído sem executá-lo de fato.

PRÓXIMA FATIA: INGESTÃO AUTENTICADA DE LEARNING EVENTS
Implemente em api/ uma fatia pequena e revisável para:
1. POST /events protegido por Bearer access token.
2. Aceitar exatamente o contrato Flutter: event_id, event_type, course_id,
   session_id e occurred_at.
3. Derivar user_id exclusivamente do claim sub; nunca aceitar user_id do cliente.
4. Permitir inicialmente lesson_started e lesson_completed.
5. Tornar event_id idempotente: o mesmo evento do mesmo usuário deve retornar
   sucesso sem criar segunda linha; colisão entre usuários deve ser rejeitada.
6. GET /events?course_id=... protegido, limitado ao usuário autenticado, com
   paginação e limite máximo seguro.
7. Não iniciar ainda o worker do Google Sheets.

TESTES MÍNIMOS
- requisição sem token ou com token expirado é 401;
- evento válido persiste com user_id do token;
- retry do mesmo event_id permanece com uma linha;
- event_type desconhecido é 422 sem ecoar payload sensível;
- um estudante não consegue listar eventos de outro;
- filtros e paginação possuem testes de limite.

LIMITES DE ESCOPO
- Não sincronizar ainda a fila Flutter nesta mesma fatia.
- Não implementar o worker do Google Sheets.
- Não iniciar deploy ou staging.
- Se uma biblioteca de segurança for adicionada, fixe intervalo de versão no
  pyproject.toml e use sua API atual documentada.

VALIDAÇÃO E ENTREGA
- Use C:\...\api\.venv\Scripts\python.exe para testes.
- Rode testes focados, depois todos os testes de api/ e compileall.
- Rode git diff --check e busca de padrões de segredo antes do commit.
- Atualize docs/maintenance/AGENT_LOG.md com evidências reais e pendências.
- Faça um commit pequeno com mensagem: feat: ingest authenticated learning events
- Termine com git status limpo e informe commit, testes e limitações.
```
