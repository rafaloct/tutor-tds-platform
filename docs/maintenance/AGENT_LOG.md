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
