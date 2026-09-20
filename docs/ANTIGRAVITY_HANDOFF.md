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
- Flutter: cliente de autenticação segura concluído; baseline de 50 testes e
  `flutter analyze` limpo no último fechamento.
- Docker Desktop estava instalado, mas o daemon não estava rodando. Não marque teste
  integrado PostgreSQL como concluído sem executá-lo de fato.

PRÓXIMA FATIA: INTEGRAÇÃO VISUAL DE CONTA NO FLUTTER
Implemente no Flutter uma fatia pequena e revisável para:
1. Quando TUTOR_API_URL estiver configurada, oferecer criar conta e entrar sem
   bloquear o uso offline atual.
2. Reutilizar AuthRepository; não duplicar HTTP nem acesso ao cofre seguro.
3. Senha deve usar campo obscurecido e nunca ser salva em SharedPreferences.
4. Erros devem ser genéricos, acessíveis e nunca repetir CPF ou senha.
5. TUTOR_API_URL vazia deve preservar pixel e fluxo atuais da WelcomeScreen.
6. Não remover ainda user_cpf legado: Chatwoot, certificados e analytics ainda
   dependem dele e exigem uma migração separada e testada.

TESTES MÍNIMOS
- modo offline permanece idêntico quando a API está vazia;
- registro e login possuem estados de carregamento, sucesso e erro testados;
- senha não aparece em SharedPreferences nem em mensagens;
- navegação segue funcionando após autenticar e após escolher uso offline;
- semântica e foco dos novos campos possuem teste de widget.

LIMITES DE ESCOPO
- Não tornar conta obrigatória nesta fatia.
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
- Faça um commit pequeno com mensagem: feat: add optional account onboarding
- Termine com git status limpo e informe commit, testes e limitações.
```
