# Auditoria de prontidão — 12/10/2026

Base examinada: `codex/rc-reconverged-20261009` em `9b5778d`. Esta é uma
fotografia de código e evidências versionadas, sem consulta atual aos serviços
produtivos na auditoria inicial. Em 12/10 às 14:54 UTC, uma consulta pública
somente leitura, sem credenciais, confirmou `/tutor-api/health` 200 com
`status=ok`, `/tutor-api/version` 200, e `/health` 200 com `status=ok` nos dois
Workers. A API produtiva declarou `schema_version=20261005_0028`,
`environment=production`, `minimum_supported_app_version=1.2.0+11` e
`compatibility_verified=false`; a API staging declarou `0029`. Esses probes
são pontuais e não identificam o SHA implantado nem comprovam upstream de IA.
As correções desta branch ainda não formam um SHA de release.
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
| 2 | GitHub atualizado | BLOCKED | A integração está na branch remota `agent/production-readiness-20261012`, ainda sem SHA de release/revisão final. PR #194 permanece aberto sobre `staging`; seus três checks falharam no SHA `9b5778d`. As causas observadas de seleção de alvo e secret scan foram corrigidas localmente; CI novo ainda precisa executar no candidato final. |
| 3 | árvore limpa | PARTIAL | Base `9b5778d` estava limpa. Verificar novamente na worktree de release congelada, após testes e manifesto. |
| 4 | API canônica | PARTIAL | `/tutor-api/health` e `/version` responderam via HTTPS em 12/10. O SHA implantado e a proveniência da API não foram confirmados. |
| 5 | API e banco saudáveis | PARTIAL | `/health` declarou `status=ok` e consulta ao banco disponível em probe pontual de 12/10. Repetir na janela de promoção e conferir monitoramento contínuo. |
| 6 | PostgreSQL persistente | PARTIAL | Compose declara volume; inventário do volume/runtime e recuperação do candidato não estão versionados integralmente. |
| 7 | DATABASE_URL correto | UNKNOWN | Compose candidato é protegido; conexão efetiva do runtime não foi auditada nesta sessão. Conferir sem revelar a URL. |
| 8 | build sem staging/flags indevidas | BLOCKED | Flags de risco são false no candidato, mas `config/production.json` é local/ignorado e o preflight exato não foi executado. |
| 9 | schema/backend ↔ app | BLOCKED | Consulta pública de 12/10: produção `0028`, staging `0029`, candidato `0030`; produção declara `compatibility_verified=false`. Exigir comparação e upgrade compatível no SHA congelado. |
| 10 | migrations no destino correto | BLOCKED | `0030` foi testada localmente em PostgreSQL; produção segue em `0028`. Aplicação e compatibilidade no destino de produção não foram comprovadas. |
| 11 | backup configurado e monitorado | PARTIAL | Há automação e recibos históricos. Idade atual, alerta recebido e restauração de objeto PostgreSQL agendado do offsite seguem sem prova versionada. |
| 12 | restauração independente | BLOCKED | `production-restore-acceptance.json` existe, com cinco booleans, mas sem referências. Track B comprova o volume AnythingLLM; o ensaio PostgreSQL versionado vai até `0020`. O verificador exige recibo agendado ligado ao dump restaurado, um ensaio PostgreSQL único, árvore Git da API e drill recente; o aceite histórico falha. |
| 13 | secrets fora do Git | PARTIAL | O scanner local com gitleaks 8.28.0 não encontrou vazamentos no histórico da candidata a partir da base de PR #194; o digest histórico que gerava falso positivo recebeu exceção fixada ao valor exato. Repetir em CI e no SHA final, sem copiar credenciais para evidências. |
| 14 | HTTPS/domínio/SSL | PARTIAL | TLS passou em probes históricos; repetir validade e rota durante a janela de promoção. |
| 15 | testes de release | PARTIAL | Suíte completa da API passou localmente; PostgreSQL 16 descartável na porta local passou 4/4 testes opcionais de turma/migration; gate de restore 17/17, harness 20/20, preflight RAG 8/8, promoção curricular 10/10, Worker 32/32 e análise Flutter 3.44.9 passaram. O recorte de telas Flutter passou 6/6 após corrigir rolagem dos testes. Reexecutar recorte afetado e CI no SHA final, inclusive concorrência PostgreSQL específica e Android. |
| 16 | upgrade do app publicado | BLOCKED | Evidência de 06/10 cobre o app publicado `1.2.0+11` contra backend anterior; falta upgrade real do candidato `1.4.0+13` preservando dados/sessão. |
| 17 | manifesto do build | BLOCKED | Só é produzido após preflight e AAB do SHA congelado; nenhum manifesto atual foi gerado. |
| 18 | SHA-256 do AAB | BLOCKED | O AAB registrado está `superseded`, não corresponde à fonte atual e tem `upload_allowed=false`. |

## Gates adicionais para aulas reais

- **Turma:** backend, app e E2E da #138–#140 foram exercitados com dados
  sintéticos em API/banco descartáveis. A decisão de 12/10 altera autoridade do
  operador e capacidade; os PASS de 05/10 não aceitam essa regra nova. Testes
  locais de API e Flutter exercitaram a nova regra; revisão ainda encontrou
  retries ambíguos e reconfirmação de versão; a candidata corrigiu a versão
  revisada e o replay na mesma instância, e está fechando replay após recriar
  a tela. O validador agora rejeita o PASS antigo de capacidade rígida.
  Reexecutar o E2E
  depois da mudança, primeiro em ambiente isolado, depois em staging.
  `CLASS_LIFECYCLE_ENABLED` segue false até promoção.
- **Tutor contextual:** o sentinel A/B prova isolamento CourseVersion com
  documentos sintéticos em staging. As cartilhas curriculares ainda não têm
  ingestão versionada, bytes atuais do Drive validados, workspaces por edição
  nem mapa produtivo comprovado. Um preflight offline confere nove PDFs locais
  contra os hashes históricos, mas não há PDFs neste checkout; ele não prova
  origem no Drive, aprovação editorial ou indexação. O Worker rejeita contexto
  sem fonte (`503`) de forma
  deliberada; validar o caminho cartilha → Tutor antes de aulas.
- **Observabilidade:** o watchdog atual mede API/banco. O candidato de probes
  públicos cobre somente os dois Workers, sem inferência ou saúde do túnel,
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
