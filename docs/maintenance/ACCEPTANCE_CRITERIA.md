# Tutor TDS — Critérios de Aceite

> **Onda 0 — Auditoria Técnica**
> Data: 2026-09-19

---

## Critérios Gerais de Aceite por Onda

A evolução só avança para a próxima onda quando **todos** os critérios da onda atual forem demonstrados, não apenas declarados.

---

## Onda 1 — Fundação

### API e Banco
- [ ] API Tutor TDS responde em `GET /health` com banco disponível
- [ ] Migrations executam do zero sem erro
- [ ] Rollback da migration funciona sem perda de dados

### Autenticação
- [ ] Usuário consegue se registrar com CPF + telefone
- [ ] JWT é emitido e validado corretamente
- [ ] Token expirado resulta em 401, não em erro genérico
- [ ] RBAC distingue student, teacher, monitor e admin

### Sync Worker
- [ ] Evento registrado no banco aparece no Google Sheets em ≤ 60 segundos (ambiente de staging)
- [ ] Falha transitória gera retry automático (máximo 3 tentativas)
- [ ] Evento duplicado não gera linha duplicada na planilha
- [ ] Reconciliação manual detecta divergências entre banco e planilha

### Deploy
- [ ] Push para branch `staging` dispara pipeline automatizado
- [ ] Health check pós-deploy é executado automaticamente
- [ ] Falha no health check impede promoção para produção
- [ ] Deploy pode ser revertido (rollback para imagem anterior)

### Segurança
- [ ] CPF não trafega em plaintext para nenhum destino (substituído por HMAC ou removido)
- [ ] Nenhum secret hardcoded no código-fonte
- [ ] `flutter_secure_storage` em uso para JWT local no app
- [ ] API rejeita requisições sem token válido nos endpoints protegidos

---

## Onda 2 — Aprendizagem Dinâmica

### Cursos Remotos
- [ ] Novo curso criado pela API aparece no app em ≤ 30 segundos (sem rebuild)
- [ ] App com conectividade usa cursos da API
- [ ] App sem conectividade usa cursos em cache local
- [ ] Cursos locais do APK funcionam como fallback quando API retorna vazio

### LearningEvents
- [ ] Evento `lesson_started` é registrado no banco com latência ≤ 5s
- [ ] Evento gerado offline é salvo localmente e sincronizado ao reconectar
- [ ] Evento duplicado (retry) é ignorado (idempotência por `event_id`)
- [ ] Fila local de eventos não cresce indefinidamente (limite de tentativas)

### 40 Horas
- [ ] Endpoint `/users/:id/hours` retorna `planned_hours`, `validated_hours`, `active_usage`
- [ ] `active_usage` não conta tela aberta sem interação (previne fraude de tempo)
- [ ] Professor consegue ver carga horária individual de cada aluno

---

## Onda 3 — Classroom

### Turmas
- [ ] Nova turma pode ser criada sem alteração de código
- [ ] Aluno pode ser matriculado em uma turma
- [ ] Professor/monitor é associado à turma
- [ ] Turma tem data início, data fim e status (ativa/encerrada)

### Painel Professor
- [ ] Professor vê lista de alunos da turma com progresso individual
- [ ] Alertas de inatividade (≥ 7 dias sem atividade) são destacados
- [ ] Alunos com atividade obrigatória pendente são destacados
- [ ] Carga horária abaixo do esperado é destacada (gestão por exceção)

### Certificados
- [ ] Certificado emitido possui código verificável único
- [ ] QR Code abre página pública de verificação sem exigir login
- [ ] Página de verificação pública não exibe CPF do titular
- [ ] Certificado tem: aluno, curso, instituição, carga horária, data, QR Code

---

## Onda 5 — QA / Release

### Qualidade de Código
- [ ] `flutter analyze` sem erros
- [ ] `dart analyze` sem erros
- [ ] Todos os testes unitários passam (`flutter test test`)
- [ ] Cobertura de testes nos módulos críticos (certificates, study_ai, sync) ≥ 80%

### Testes de Integração
- [ ] Fluxo completo: cadastro → estudo → conclusão → certificado (integration_test)
- [ ] Fluxo offline: estudo sem conexão → sincronização ao reconectar
- [ ] Fluxo de sync: evento no app → banco → Google Sheets

### Segurança
- [ ] Nenhuma credencial ou CPF real em logs ou respostas de API
- [ ] Scan de segredos no repositório não encontra chaves privadas
- [ ] HTTPS obrigatório em todos os endpoints de produção

### Performance
- [ ] Tempo de carregamento inicial do app ≤ 3s em conexão 3G
- [ ] Resposta do Tutor IA ≤ 10s em 90% das requisições

### Publicação
- [ ] AAB gerado com a nova chave de upload aprovada pela Play Console
- [ ] Release notes atualizadas
- [ ] Política de Privacidade publicada em URL HTTPS
- [ ] Declaração de Segurança dos Dados coerente com o app

---

## Critério de Aceite Global (Sistema Completo)

A evolução está concluída quando **todos** estes pontos puderem ser demonstrados ao vivo:

| Critério | Demonstração |
|---|---|
| Novo curso sem APK | Criar curso na API → abrir app → curso aparece |
| Nova instituição sem código | Criar institution na API → funcionar |
| Nova turma sem dev | Criar class na API → alunos matriculáveis |
| Eventos no banco | Registrar evento → verificar no banco |
| Sheets sincronizado | Evento no banco → linha na planilha em ≤ 60s |
| Offline funciona | Avião mode → estudar → reconectar → evento sincronizado |
| 40h registradas | Estudar 1h → `/users/:id/hours` retorna 1h |
| Professor acompanha | Login professor → ver alunos + pendências |
| Certificado verificável | Emitir → QR Code → página pública → "Válido" |
| Sem secrets expostos | grep de secrets no repo → resultado vazio |
| Deploy reproduzível | Novo dev segue README → app rodando em ≤ 30min |

---

_Estes critérios devem ser revisados e aprovados pelo responsável pelo projeto antes da publicação de cada onda._
