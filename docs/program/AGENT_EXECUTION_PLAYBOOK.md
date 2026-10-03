# Playbook para agentes de desenvolvimento

## 1. Objetivo

Permitir trabalho paralelo sem colisão, alucinação de arquitetura ou alteração indevida de produção.

## 2. Antes de editar

Agente deve retornar uma auditoria curta:

```text
Base SHA:
Branch:
Issue:
Objetivo único:
Fonte de verdade afetada:
Arquivos prováveis:
Dependências:
Ambiente:
Risco:
Human gate:
Testes:
Fora de escopo:
```

Se não consegue preencher, não está READY.

## 3. Leitura obrigatória

Seguir `docs/program/README.md`. Ler apenas histórico necessário depois da base canônica.

## 4. Regra de escopo

Uma issue = um resultado verificável.

Proibido “aproveitar” para:
- refactor geral;
- trocar state management;
- trocar banco;
- criar segundo backend;
- reorganizar diretórios sem necessidade;
- atualizar dependências não relacionadas;
- corrigir bug vizinho sem issue.

## 5. Branch

Padrão:

```text
agent/issue-<N>-<slug>-YYYYMMDD
```

ou prefixo do executor já adotado pelo projeto.

Basear na branch indicada na issue. Nunca assumir `main`.

## 6. Workspace

- preservar arquivos locais;
- sem `reset --hard`;
- sem `clean`;
- sem stash destrutivo;
- sem apagar output/evidência não rastreada;
- cada escritor usa worktree própria; nunca dois escritores na mesma branch/worktree;
- sem force-push ou rebase destrutivo; integrar consolidação por merge que preserve histórico;
- PRs #21/#39 e arquivos reservados a outros executores devem ser preservados.

## 7. Secrets

Não ler nem imprimir segredo se o objetivo pode ser cumprido por contrato/mock. Se acesso real for necessário, parar no HUMAN-GATE.

## 8. Implementação

Ordem preferida:
1. teste que reproduz lacuna;
2. menor mudança de domínio;
3. repository/API;
4. controller/state;
5. UI;
6. docs/evidência;
7. testes direcionados.

Para integração externa, primeiro adapter/interface + fake; só depois provider real em fatia autorizada.

## 9. Banco

Antes de migration:
- buscar tabela/coluna equivalente;
- justificar;
- aditiva por padrão;
- upgrade de base vazia;
- upgrade de snapshot staging;
- ambiguidades de backfill falham explicitamente;
- downgrade ou forward recovery documentado;
- não apagar coluna/dado na mesma wave.

## 10. API

Endpoints novos precisam:
- auth/authorization;
- schema tipado;
- erro consistente;
- idempotência quando comando;
- paginação quando coleção;
- testes negativos;
- OpenAPI coerente;
- sem PII em logs.

## 11. Flutter

Feature deve ter:
- repository/interface;
- estado claro;
- loading/empty/error/offline;
- isolamento por usuário/ambiente;
- logout;
- acessibilidade;
- teste de widget/controller;
- nenhuma credencial embutida.

## 12. Web/portal

- nenhuma consulta direta ao DB Tutor;
- nenhuma PII em JS;
- integração pública read-only;
- fallback acessível;
- cache com invalidação;
- editor não precisa de deploy para notícia.

## 13. Evidência

Cada PR informa:
- base/head SHA;
- arquivos alterados;
- comandos executados;
- PASS/FAIL;
- quantidade de testes;
- ambiente;
- o que NÃO foi testado;
- screenshots/JSON sanitizados quando necessários;
- rollback.

Não declarar “produção validada” a partir de mock/local.

## 14. PR

Draft primeiro. Body mínimo:
- problema;
- solução;
- contrato;
- arquivos;
- testes;
- risco;
- segurança/privacidade;
- migrations;
- feature flags;
- evidência;
- limites;
- human gates;
- rollback;
- issue vinculada.

## 15. Stop conditions

Parar após duas tentativas do mesmo erro e registrar:

```text
Observed
Expected
Responsible Boundary
Evidence
Likely Root Cause
Affected Files
Structural Fix
```

Também parar se:
- precisa de secret;
- precisa alterar produção;
- decisão institucional não existe;
- conflito de contrato;
- migration central já está sendo alterada por outro agente;
- teste exigiria dado pessoal real.

## 16. Concorrência

Pode executar em paralelo:
- docs;
- testes isolados;
- portal público;
- observabilidade;
- media adapter;
- Chatwoot fake;
- BI projections.

Evitar paralelo no mesmo contrato:
- identity/enrollment;
- CourseVersion;
- migration head;
- certificate authority;
- release config;
- backup automation.

## 17. Definition of Done

Na META 04, no máximo dois escritores Codex simultâneos. Devin mantém os quatro
arquivos do PR #51; Windsurf recebe revisão semântica read-only e depois arquivos
exclusivos de tema/frontend. Não compartilhar contrato central, migration head,
release config, emissão, identidade/matrícula ou backup entre escritores.

GitHub é o canal de dispatch e retorno. Publicar packet autocontido e reservar
branch/worktree/arquivos antes da edição; mensagem publicada não comprova início
do executor. Referenciar resultados por SHA explícito: FETCH_HEAD é transitório
e pode ser substituído por fetch posterior na mesma worktree; refs remotas são
compartilhadas entre worktrees.

Em cada ciclo publicar CURRENT_FRONT, EXECUTOR, BASE_SHA, HEAD_SHA, STATUS, TESTS,
CI, REVIEW, BLOCKERS, HUMAN_GATE e NEXT_FRONT. CI verde não aceita semântica nem
prova staging. Merge de PR permanece reservado a Rafael. Se houver duas decisões
humanas vigentes incompatíveis, registrar SEMANTIC_HUMAN_GATE e uma pergunta
objetiva; continuar frentes independentes. Não gerar AAB nesta meta.

Código compilado + testes focais + docs + CI relevante + revisão + critérios de aceite. Para integração real, staging comprovado. Para produção, gate específico.

Issue pode estar “implementada” sem estar “promovida”.

## 18. Linguagem de status

Use somente:
- OBSERVED
- IMPLEMENTED
- TESTED-LOCAL
- TESTED-STAGING
- ACCEPTED
- DEPLOYED-PRODUCTION
- BLOCKED
- UNKNOWN

Não usar “pronto” sem qualificador.
