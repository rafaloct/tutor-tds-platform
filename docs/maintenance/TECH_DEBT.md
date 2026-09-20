# Tutor TDS — Dívida Técnica

> **Onda 0 — Auditoria Técnica**
> Data: 2026-09-19

---

## Legenda de Prioridade

| Símbolo | Prioridade | Onda |
|---|---|---|
| 🔴 | Crítica — bloqueia evolução | Onda 1 |
| 🟠 | Alta — impacta segurança ou escalabilidade | Onda 1-2 |
| 🟡 | Média — impacta manutenibilidade | Onda 2-3 |
| 🟢 | Baixa — melhoria não urgente | Onda 4+ |

---

## 1. Catálogo de Cursos Estático no APK 🔴

**Problema:** As 9 cartilhas estão hardcoded como assets JSON no binário do aplicativo.
Qualquer novo curso, módulo, aula ou atualização de conteúdo exige:
1. Modificar o código/assets
2. Rebuild do APK/AAB
3. Republicação na Google Play Store
4. Esperar revisão da Google (horas a dias)
5. Aguardar usuários atualizarem o app

**Impacto:** Completamente inviável para um produto multi-instituição ou com atualização de conteúdo frequente.

**Solução (Onda 2):**
- API REST `/courses` retornando catálogo dinâmico
- Flutter busca catálogo na inicialização + cache local
- Assets locais como fallback offline
- Novos cursos se tornam configuração, não código

---

## 2. Banco Relacional Centralizado 🟡 Implementado, deploy pendente

**Situação original:** não existia banco de dados centralizado. Dados transacionais residiam em:
- Google Sheets (analytics e lista de alunos)
- SharedPreferences local do dispositivo (progresso, certificados)
- Cloudflare KV (certificados verificáveis)

**Impacto:**
- Sem histórico confiável de aprendizagem por servidor
- Sem suporte a multi-turma ou multi-instituição
- Impossível validar 40h de carga horária com dados auditáveis
- Professor/monitor não consegue acompanhar alunos
- Dados perdidos ao desinstalar o app ou trocar de dispositivo

**Solução (Onda 1):**
- PostgreSQL (Neon ou self-hosted na VPS)
- API REST Tutor TDS com migrations versionadas
- Migração progressiva dos dados do Sheets para o banco

**Estado atual:** modelos, migrations e PostgreSQL via Docker estão prontos;
falta publicar e validar backup/restore na VPS.

---

## 3. Autenticação Real no Servidor 🟡 Implementada, deploy pendente

**Situação original:** o aplicativo não possuía autenticação JWT.

**Impacto:**
- Impossível implementar RBAC (student, teacher, monitor, admin)
- Qualquer dado enviado ao servidor não tem identidade verificada
- Multi-instituição não é segura sem auth
- Certificados não são vinculados a uma sessão autenticada

**Solução (Onda 1):**
- Autenticação com phone/CPF + OTP ou credencial simples
- JWT com refresh token
- RBAC no backend (não confiar no Flutter para autorização)

**Estado atual:** access/refresh tokens, Argon2id e RBAC estão implementados e
cobertos por testes; falta publicação na VPS.

---

## 4. LearningEvents Persistidos no Servidor ✅ Implementado

**Situação original:** não existia registro de eventos de aprendizagem em
banco controlado pela plataforma.

**Impacto:**
- Impossível validar 40h de carga horária com rastreabilidade
- Não há diferença entre `planned_hours`, `validated_hours` e `active_usage`
- Professor não pode verificar progresso real do aluno
- Analytics dependem exclusivamente do Google Sheets

**Solução (Onda 2):**
- Tabela `learning_events` no banco PostgreSQL
- Offline queue local com sync posterior
- Idempotência via `event_id` UUID gerado no cliente

**Estado atual:** implementado com fila offline, autenticação, idempotência,
atividade validada e telemetria tipada.

---

## 5. Deploy Manual via rsync 🟠

**Problema:** O processo de deploy do PWA envolve build local, rsync para VPS e chamada manual à API do Dokploy.

**Impacto:**
- Propenso a erro humano
- Sem histórico de deploys
- Sem rollback automatizado
- Sem ambiente de staging isolado
- Sem testes automatizados antes de publicar

**Solução (Onda 1):**
- GitHub Actions com pipeline CI/CD
- Build automático no push para `main`
- Deploy em staging antes de produção
- Health check automatizado pós-deploy

---

## 6. Sem Ambiente de Staging 🟠

**Problema:** Existe apenas um ambiente de produção. Mudanças são testadas diretamente em produção.

**Impacto:**
- Alto risco de regressão
- Impossível testar migrations com dados reais sem afetar usuários
- APIs novas vão direto para produção

**Solução (Onda 1):**
- Segundo compose no Dokploy (staging)
- Banco de dados separado (ou schema isolado) para staging
- Worker Cloudflare em ambiente de preview

---

## 7. CPF em Plaintext para Google Apps Script ✅ Resolvido

**Resolvido em 2026-09-20:** `DataSyncService` e a variável do webhook foram
removidos do Flutter. A telemetria autenticada aceita somente IDs técnicos
tipados e não acessa nome, telefone ou CPF.

---

## 8. Repositório Git Sem Histórico 🟡

**Problema:** O diretório de trabalho foi entregue como snapshot sem `.git`. Todo o histórico de desenvolvimento está perdido ou inacessível.

**Impacto:** Não é possível rastrear quando funcionalidades foram adicionadas, auditar mudanças ou reverter regressões de código.

**Status:** ✅ Parcialmente resolvido na Onda 0 — Git inicializado. Histórico anterior indisponível.

---

## 9. Sem Testes de Integração End-to-End 🟡

**Problema:** Existem testes unitários Flutter (8 arquivos), mas sem cobertura de integração end-to-end.

**Lacunas:**
- Sem teste do fluxo completo de estudo + emissão de certificado
- Sem teste de sincronização offline
- Sem teste da integração com o gateway Cloudflare
- Sem teste de regressão do layout em diferentes tamanhos de tela

**Solução (Onda 5):** Expandir `integration_test/` com cenários críticos de usuário.

---

## 10. Estrutura de Dados Local Não Versionada 🟡

**Problema:** O esquema de dados do SharedPreferences não tem controle de versão.
Se a estrutura mudar (ex: novos campos no `CertificateRecord`), usuários com app antigo podem ter dados incompatíveis.

**Solução:** Adicionar `schema_version` às estruturas locais e implementar migração no boot do app.

---

## 11. AnythingLLM Sem Health Check Automatizado 🟡

**Problema:** Não existe monitoramento automatizado da instância AnythingLLM na VPS.
Se o container cair, os usuários recebem apenas a mensagem amigável de indisponibilidade, sem alerta para o time.

**Solução:** Cron job simples ou uptime monitor (ex: UptimeRobot free tier) com alerta por email/WhatsApp.

---

## 12. Sem Observabilidade Estruturada 🟡

**Problema:** Logs são apenas `debugPrint()` no Flutter e console do Worker no Cloudflare.
Não existe log estruturado com correlação de eventos, rastreabilidade de erros ou alertas.

**Solução (Onda 1):**
- Logs estruturados JSON na API Tutor TDS
- Integração com serviço de observabilidade (Loki/Grafana na VPS ou similar open-source)

---

## 13. Dependência do Google Apps Script ✅ Resolvida no Flutter

O Flutter não chama mais o Apps Script. Analytics usa a API Tutor TDS; o
script permanece somente como artefato histórico.

---

## 14. Ausência de Feature Flags 🟢

**Problema:** Não existe sistema de feature flags. Funcionalidades novas ou experimentais vão direto para todos os usuários.

**Solução (Onda 4):** Implementar feature flags configuráveis na API (ex: `unleash` ou implementação simples com tabela de configuração).

---

## Resumo da Dívida Técnica por Onda

### Onda 1 — Obrigatório resolver
- [x] Banco relacional (PostgreSQL) preparado para deploy
- [x] API REST centralizada implementada
- [x] Autenticação JWT + RBAC implementada
- [ ] Deploy automatizado (CI/CD)
- [ ] Ambiente de staging
- [x] Remover CPF e demais dados pessoais do analytics

### Onda 2 — Evolução de produto
- [ ] Catálogo de cursos dinâmico via API
- [x] LearningEvents persistidos no servidor
- [x] Offline sync com fila + retry
- [x] Controle de 40h (planned/validated/active)

### Onda 3 — Classroom
- [x] Turmas e matrículas
- [ ] Painel professor/monitor
- [ ] Certificados acadêmicos por instituição

### Onda 4+ — Sustentabilidade
- [ ] Multi-instituição completo
- [ ] Creator Studio
- [ ] Ledger financeiro
- [ ] Feature flags
- [x] Migração de dependência do Google Apps Script

---

_Atualizar conforme cada item for resolvido ou novas dívidas forem identificadas._
