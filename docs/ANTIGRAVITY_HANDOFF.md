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
- API local: 6 testes Python aprovados; migration upgrade/downgrade aprovada em SQLite;
  SQL PostgreSQL gerado offline; docker compose config válido.
- Flutter: baseline de 43 testes e flutter analyze limpo no último fechamento.
- Docker Desktop estava instalado, mas o daemon não estava rodando. Não marque teste
  integrado PostgreSQL como concluído sem executá-lo de fato.

PRÓXIMA FATIA: AUTENTICAÇÃO LOCAL SEGURA DA ONDA 1
Implemente em api/ uma fatia pequena e revisável para:
1. POST /auth/register com name, cpf, phone e password.
2. POST /auth/login com cpf e password.
3. POST /auth/refresh com rotação de refresh token.
4. Access JWT curto (15 minutos) e refresh token opaco, aleatório, armazenado apenas
   como digest na tabela sessions. Reuso de refresh revogado deve retornar 401.
5. CPF deve ser normalizado e ter dígitos verificadores validados. Nunca armazenar,
   registrar ou retornar CPF puro. Persistir somente HMAC-SHA256 com CPF_PEPPER secreto;
   hash simples de CPF não é aceitável.
6. Senha com Argon2id. Nunca logar nem retornar senha/digest.
7. JWT_SECRET e CPF_PEPPER obrigatórios fora dos testes, sem valor produtivo padrão.
8. Claim de role deve aceitar somente student, teacher, monitor e admin; registro público
   sempre cria student.
9. Criar migration Alembic 0002, sem reescrever a migration 0001 já consolidada.
10. Atualizar .env.example e documentação sem inserir segredos reais.

TESTES MÍNIMOS
- registro válido não revela CPF nem password;
- CPF inválido é 422;
- CPF duplicado é 409;
- login correto emite tokens; senha errada é 401 genérico;
- access token expirado é 401;
- refresh rotaciona e o token anterior não pode ser reutilizado;
- migration 0002 sobe e desce em banco temporário;
- nenhuma informação sensível aparece em respostas/erros.

LIMITES DE ESCOPO
- Não integrar ainda a autenticação no Flutter.
- Não implementar POST /events nesta mesma fatia.
- Não iniciar deploy ou staging.
- Se uma biblioteca de segurança for adicionada, fixe intervalo de versão no
  pyproject.toml e use sua API atual documentada.

VALIDAÇÃO E ENTREGA
- Use C:\...\api\.venv\Scripts\python.exe para testes.
- Rode testes focados, depois todos os testes de api/ e compileall.
- Rode git diff --check e busca de padrões de segredo antes do commit.
- Atualize docs/maintenance/AGENT_LOG.md com evidências reais e pendências.
- Faça um commit pequeno com mensagem: feat: add secure API authentication
- Termine com git status limpo e informe commit, testes e limitações.
```
