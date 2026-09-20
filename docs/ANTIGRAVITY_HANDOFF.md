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
- API local: 19 testes Python aprovados; migrations upgrade/downgrade aprovadas em SQLite;
  SQL PostgreSQL gerado offline; docker compose config válido.
- Autenticação local concluída: registro, login, refresh rotativo e `/auth/me`,
  com CPF em HMAC-SHA256, senha Argon2id e erros de validação sanitizados.
- Ingestão autenticada concluída: POST/GET `/events`, idempotência e isolamento
  por estudante.
- Flutter: baseline de 43 testes e flutter analyze limpo no último fechamento.
- Docker Desktop estava instalado, mas o daemon não estava rodando. Não marque teste
  integrado PostgreSQL como concluído sem executá-lo de fato.

PRÓXIMA FATIA: CLIENTE DE AUTENTICAÇÃO FLUTTER
Implemente no Flutter uma fundação pequena e revisável para:
1. AuthRepository para register, login, refresh e `/auth/me` usando TUTOR_API_URL.
2. Armazenar access e refresh tokens somente com flutter_secure_storage.
3. Nunca salvar senha em nenhum armazenamento.
4. Renovar access token uma vez após 401 e impedir loops de refresh.
5. API vazia deve manter exatamente o comportamento offline atual.
6. Não alterar ainda WelcomeScreen, Google Apps Script, Chatwoot ou certificados.

TESTES MÍNIMOS
- tokens nunca aparecem em SharedPreferences;
- register/login/refresh interpretam sucesso e erros genéricos sem ecoar senha;
- 401 dispara no máximo um refresh e repete a requisição uma vez;
- refresh rejeitado limpa somente tokens da API;
- TUTOR_API_URL vazia não gera chamada de rede.

LIMITES DE ESCOPO
- Não mudar ainda o fluxo visual de onboarding/login.
- Não sincronizar a fila de eventos nesta mesma fatia.
- Não implementar o worker do Google Sheets.
- Não iniciar deploy ou staging.
- Se uma biblioteca de segurança for adicionada, fixe intervalo de versão no
  pyproject.toml e use sua API atual documentada.

VALIDAÇÃO E ENTREGA
- Use C:\...\api\.venv\Scripts\python.exe para testes.
- Rode testes focados, depois todos os testes de api/ e compileall.
- Rode git diff --check e busca de padrões de segredo antes do commit.
- Atualize docs/maintenance/AGENT_LOG.md com evidências reais e pendências.
- Faça um commit pequeno com mensagem: feat: add Flutter auth client foundation
- Termine com git status limpo e informe commit, testes e limitações.
```
