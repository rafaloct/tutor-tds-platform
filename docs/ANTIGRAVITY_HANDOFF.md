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
- Flutter: conta online opcional integrada à WelcomeScreen; baseline de 54 testes e
  `flutter analyze` limpo no último fechamento.
- Docker Desktop estava instalado, mas o daemon não estava rodando. Não marque teste
  integrado PostgreSQL como concluído sem executá-lo de fato.

PRÓXIMA FATIA: SINCRONIZAÇÃO DA FILA DE LEARNING EVENTS
Implemente no Flutter uma fatia pequena e revisável para:
1. Enviar eventos pendentes a POST /events usando AuthRepository.authorized.
2. Sincronizar somente quando TUTOR_API_URL estiver configurada, houver conta e
   PrivacyPreferences.hasConsent() for verdadeiro.
3. Remover da fila apenas eventos confirmados com 200 ou 201.
4. Parar no primeiro erro transitório, preservando o evento e os seguintes.
5. Serializar flushes concorrentes e manter idempotência por event_id.
6. Não alterar nem duplicar o webhook legado nesta fatia.

TESTES MÍNIMOS
- sem consentimento, sem API ou sem sessão não há envio nem perda local;
- 200/201 remove exatamente o event_id confirmado;
- 401 usa o refresh único já implementado;
- 409 ou 5xx preserva a fila e interrompe o flush;
- dois flushes simultâneos não duplicam requisições.

LIMITES DE ESCOPO
- Não tornar conta obrigatória.
- Não implementar o worker do Google Sheets.
- Não iniciar deploy ou staging.
- Se uma biblioteca de segurança for adicionada, fixe intervalo de versão no
  pyproject.toml e use sua API atual documentada.

VALIDAÇÃO E ENTREGA
- Use o Flutter dedicado em C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat.
- Rode testes focados, depois `flutter analyze --no-pub` e a suíte Flutter completa.
- Rode git diff --check e busca de padrões de segredo antes do commit.
- Atualize docs/maintenance/AGENT_LOG.md com evidências reais e pendências.
- Faça um commit pequeno com mensagem: feat: sync learning events to API
- Termine com git status limpo e informe commit, testes e limitações.
```
