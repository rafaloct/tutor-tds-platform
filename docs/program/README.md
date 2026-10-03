# Tutor TDS — Programa técnico permanente

Status: **contrato canônico de planejamento**. Este diretório descreve como o ecossistema Tutor TDS deve evoluir sem criar plataformas paralelas, duplicar fontes de verdade ou depender do conhecimento de uma única pessoa.

## 1. Objetivo

Transformar o Tutor TDS de um aplicativo com integrações pontuais em uma plataforma institucional operável no longo prazo, com:

- app Flutter para participante e equipe;
- FastAPI/PostgreSQL como núcleo transacional;
- portal público para acesso, consulta e notícias;
- suporte humano via Chatwoot;
- IA mediada por gateway, sem autoridade acadêmica;
- mídia desacoplada do app;
- analytics/BI como projeção, nunca como cadastro mestre;
- backup, restauração, observabilidade, auditoria e continuidade;
- governança explícita para humanos e agentes de desenvolvimento.

## 2. Ordem obrigatória de leitura por agentes

1. `AGENTS.md`
2. `docs/CURRENT_STATE.md`
3. `docs/DOMAIN_CONTRACT.md`
4. `docs/ARCHITECTURE.md`
5. `docs/DECISIONS.md`
6. este arquivo
7. `TARGET_ARCHITECTURE.md`
8. `INTEROPERABILITY.md`
9. documento da área da issue
10. testes e código do recorte

Documentos históricos em `docs/maintenance/` e evidências datadas não substituem o estado atual.

## 3. Princípios não negociáveis

1. **Uma entidade, uma autoridade.** Antes de criar tabela, serviço ou cadastro, procurar equivalente existente.
2. **Eventos não concedem direitos.** Telemetria, chat, IA, clique, tempo de tela e abertura de material não criam matrícula, presença, capacitação, certificado ou mentoria.
3. **PostgreSQL é transacional.** Google Sheets/Power BI são projeções analíticas.
4. **WordPress é público/editorial.** Não se torna cadastro de aluno, frequência, certificado, baseline ou autorização.
5. **Chatwoot é atendimento.** Estado de conversa não altera jornada acadêmica.
6. **R2/Drive guardam arquivos.** Não substituem metadados relacionais e autorização.
7. **Offline é parte do contrato.** Cada feature declara cache, fila, revalidação e comportamento de revogação.
8. **Produção é protegida.** Nenhum agente altera produção, secrets, Play, DNS, Dokploy ou dados reais sem issue e autorização explícita.
9. **Mudança reversível primeiro.** Feature flag, migração aditiva, rollback/forward recovery e evidência antes de promoção.
10. **Sem perpetuidade por pessoa.** Contas, documentação, backups e acessos devem sobreviver à troca de equipe.

## 4. Fontes de verdade por domínio

| Domínio | Autoridade | Sistemas que apenas projetam/consomem |
|---|---|---|
| Pessoa, autenticação, vínculos | FastAPI/PostgreSQL | Flutter, portal, BI, Chatwoot |
| Instituição/programa/oferta/turma | FastAPI/PostgreSQL | Flutter, BI, portal público quando aplicável |
| Curso/edição pedagógica | FastAPI/PostgreSQL + lifecycle editorial | Flutter, portal, BI |
| Matrícula | FastAPI/PostgreSQL | Flutter, BI, suporte |
| Presença/frequência oficial | domínio específico a concluir na Issue #6 | BI, Flutter |
| Certificado | fluxo API + Worker/KV conforme Issue #5 | Flutter, portal de verificação |
| Mentoria/evidência | domínio FastAPI com revisão humana | Flutter, BI, Chatwoot |
| Conversas de suporte | Chatwoot | Flutter, API com referências mínimas, BI agregado |
| Notícias/páginas públicas | WordPress/portal editorial | app pode consumir feed público |
| Mídia pedagógica | metadados FastAPI; master em Drive; entrega por provider/R2 | Flutter, portal |
| Analytics | PostgreSQL/eventos → projeções | Sheets/Power BI |
| Backup | cópia externa verificada + runbooks | Dokploy é operador, não autoridade do dado |

## 5. Estado atual que deve ser preservado

O repositório já contém Flutter, FastAPI, PostgreSQL alvo, Alembic, catálogo remoto, CourseVersion, LearningContext, CI Flutter/API, preflight de release, gateway Cloudflare, certificados legados, Sheets, WordPress legado, Chatwoot, arquitetura de mídia e rotinas de backup em evolução.

Agentes devem **migrar o existente**, não recriar o produto.

## 6. Documentos deste programa

- `TARGET_ARCHITECTURE.md`: arquitetura alvo e fronteiras.
- `PORTAL_AND_CONTENT.md`: site/WordPress, consulta pública e notícias.
- `INTEROPERABILITY.md`: contratos entre serviços, eventos e dados.
- `GOVERNANCE_RACI.md`: papéis, decisões e responsabilidades.
- `CONFIGURATION_RUNBOOK.md`: ordem de configuração por ambiente.
- `OPERATIONS_CONTINUITY.md`: operação, incidentes, backup e continuidade.
- `AGENT_EXECUTION_PLAYBOOK.md`: protocolo para agentes.
- `PROJECT_BOARD_SCHEMA.md`: estrutura do GitHub Project.
- `ROADMAP.md`: epics, dependências e gates.

## 7. Regra para lacunas

Se código e documentação não provarem um fato, registrar **UNKNOWN/BLOCKED**. Não preencher por suposição. Uma decisão institucional deve ser registrada em `docs/DECISIONS.md` antes de virar comportamento automático.

## 8. Definição de perpetuidade

O programa é considerado sustentável quando um novo responsável consegue, usando GitHub + runbooks + contas institucionais:

1. identificar todos os serviços e proprietários;
2. recuperar acessos sem depender de senha pessoal;
3. restaurar dados em ambiente isolado;
4. publicar conteúdo e notícias sem recompilar o app;
5. criar curso/oferta/turma/aluno por fluxos autorizados;
6. auditar quem mudou o quê;
7. atualizar app/API/portal com CI e rollback;
8. atender usuário sem expor dados indevidos;
9. reconstruir ambientes a partir de documentação;
10. transferir a operação para outra equipe sem perda de conhecimento.
