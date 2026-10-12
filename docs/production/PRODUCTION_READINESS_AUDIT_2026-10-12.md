# Auditoria de prontidão — 12/10/2026

Base examinada: `codex/rc-reconverged-20261009` em `9b5778d`. Esta é uma
fotografia de código e evidências versionadas, sem consulta atual aos serviços
produtivos. As correções desta branch ainda não formam um SHA de release.
**PRODUCTION_RELEASE_READY=false.** O AAB antigo está marcado como substituído
e `upload_allowed=false` em `cartilhas_app/release/release_status.json`.

`docs/production/PRODUCTION_READINESS.md` conserva a auditoria histórica de
02/10. Seu quadro de gates e a frase de que o aceite de restore não existe não
descrevem mais esta base. Os estados abaixo usam `OBSERVED` apenas para prova
inspecionável, `PARTIAL` para cobertura limitada e `BLOCKED` quando o próximo
release não satisfaz o gate. Histórico de serviço não é prova do SHA futuro.

| # | Gate | Estado em 12/10 | Evidência e prova restante |
| --- | --- | --- | --- |
| 1 | commit e tag | BLOCKED | `9b5778d` é identificável; não há tag de release no candidato. Congelar SHA e publicar tag após revisão. |
| 2 | GitHub atualizado | BLOCKED | A branch de reconvergência está no remoto, mas o SHA de release desta integração não está. API do GitHub indisponível neste executor; estado de PR, checks e proteção não foi confirmado. |
| 3 | árvore limpa | PARTIAL | Base `9b5778d` estava limpa. Verificar novamente na worktree de release congelada, após testes e manifesto. |
| 4 | API canônica | PARTIAL | Rota `/tutor-api` consta de evidências anteriores; SHA implantado e proveniência da API não foram confirmados agora. |
| 5 | API e banco saudáveis | PARTIAL | Probe histórico viu `/health` e TLS válidos. Repetir na janela de release e conferir banco. |
| 6 | PostgreSQL persistente | PARTIAL | Compose declara volume; inventário do volume/runtime e recuperação do candidato não estão versionados integralmente. |
| 7 | DATABASE_URL correto | UNKNOWN | Compose candidato é protegido; conexão efetiva do runtime não foi auditada nesta sessão. Conferir sem revelar a URL. |
| 8 | build sem staging/flags indevidas | BLOCKED | Flags de risco são false no candidato, mas `config/production.json` é local/ignorado e o preflight exato não foi executado. |
| 9 | schema/backend ↔ app | BLOCKED | Última observação: produção `0029`, candidato `0030`, `compatibility_verified=false`. Exigir `/version` atual e comparação no SHA congelado. |
| 10 | migrations no destino correto | BLOCKED | `0030` foi testada localmente em PostgreSQL; aplicação e compatibilidade no destino de produção não foram comprovadas. |
| 11 | backup configurado e monitorado | PARTIAL | Há automação e recibos históricos. Idade atual, alerta recebido e restauração de objeto PostgreSQL agendado do offsite seguem sem prova versionada. |
| 12 | restauração independente | BLOCKED | `production-restore-acceptance.json` existe, com cinco booleans, mas sem referências. Track B comprova o volume AnythingLLM; o ensaio PostgreSQL versionado vai até `0020`. O novo verificador rejeita esse aceite até prova rastreável do schema candidato e offsite agendado. |
| 13 | secrets fora do Git | PARTIAL | Existem guardas e scan; revisar diff, histórico e artefato no SHA final. Não copiar credenciais para evidências. |
| 14 | HTTPS/domínio/SSL | PARTIAL | TLS passou em probes históricos; repetir validade e rota durante a janela de promoção. |
| 15 | testes de release | PARTIAL | Suítes históricas cobrem outro SHA. Esta integração tem testes focais; executar gates completos API, Flutter, CI e PostgreSQL no SHA final. |
| 16 | upgrade do app publicado | BLOCKED | Evidência de 06/10 cobre o app publicado `1.2.0+11` contra backend anterior; falta upgrade real do candidato `1.4.0+13` preservando dados/sessão. |
| 17 | manifesto do build | BLOCKED | Só é produzido após preflight e AAB do SHA congelado; nenhum manifesto atual foi gerado. |
| 18 | SHA-256 do AAB | BLOCKED | O AAB registrado está `superseded`, não corresponde à fonte atual e tem `upload_allowed=false`. |

## Gates adicionais para aulas reais

- **Turma:** backend, app e E2E da #138–#140 foram exercitados com dados
  sintéticos em API/banco descartáveis. A decisão de 12/10 altera autoridade do
  operador e capacidade; os PASS de 05/10 não aceitam essa regra nova. Reexecutar
  testes e E2E depois da mudança, primeiro em ambiente isolado, depois em staging.
  `CLASS_LIFECYCLE_ENABLED` segue false até promoção.
- **Tutor contextual:** o sentinel A/B prova isolamento CourseVersion com
  documentos sintéticos em staging. As cartilhas curriculares ainda não têm
  ingestão versionada, digest imutável dos PDFs, workspaces por edição nem mapa
  produtivo comprovado. O Worker rejeita contexto sem fonte (`503`) de forma
  deliberada; validar o caminho cartilha → Tutor antes de aulas.
- **Observabilidade:** o watchdog atual mede API/banco. O candidato de probes
  públicos cobre Worker e roteamento HTTP de staging, sem inferência ou saúde do
  AnythingLLM/OpenRouter; ativação e teste de entrega do alerta ainda faltam.
- **Continuidade:** nomear owner e substituto de VPS, túnel, Worker, AnythingLLM,
  OpenRouter, backups e release; conferir reboot/recuperação e orçamento/quotas.

## Próxima evidência necessária

1. Fechar a política nova de turma em código e provar migração de comportamento
   por API, app e E2E, sem tocar dados reais.
2. Versionar prova sanitizada de restore PostgreSQL e offsite agendado para o
   schema candidato; revisar custódia humana dos recibos e a idade do backup.
3. Preparar corpus curricular aprovado por edição com hashes, ingestão isolada e
   reconciliação; validar citações e revogação na rota real do app.
4. Validar probes, donos e canal de alerta; conferir saúde do upstream/modelo
   por sinal próprio antes de declarar o Tutor monitorado.
5. Só então congelar SHA/tag, aplicar gates de compatibilidade e upgrade,
   executar suíte de release, gerar novo AAB/manifesto e submeter à revisão de
   promoção. Nenhum PASS local autoriza deploy ou Play por si só.
