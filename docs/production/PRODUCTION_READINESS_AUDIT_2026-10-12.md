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
As correções desta branch ainda não formam um SHA de release aprovado.
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
| 2 | GitHub atualizado | PARTIAL | A integração está na branch remota `agent/production-readiness-20261012` e no PR #194 sobre `staging`. Em `f5f679e`, todos os checks aplicáveis passaram; os jobs de deploy foram ignorados conforme configuração. Confirmar a CI do SHA final no PR, além de revisão e promoção. |
| 3 | árvore limpa | PARTIAL | Base `9b5778d` estava limpa. Verificar novamente na worktree de release congelada, após testes e manifesto. |
| 4 | API canônica | PARTIAL | `/tutor-api/health` e `/version` responderam via HTTPS em 12/10. O SHA implantado e a proveniência da API não foram confirmados. |
| 5 | API e banco saudáveis | PARTIAL | `/health` declarou `status=ok` e consulta ao banco disponível em probe pontual de 12/10. Repetir na janela de promoção e conferir monitoramento contínuo. |
| 6 | PostgreSQL persistente | PARTIAL | Compose declara volume; inventário do volume/runtime e recuperação do candidato não estão versionados integralmente. |
| 7 | DATABASE_URL correto | UNKNOWN | Compose candidato é protegido; conexão efetiva do runtime não foi auditada nesta sessão. Conferir sem revelar a URL. |
| 8 | build sem staging/flags indevidas | BLOCKED | Flags de risco são false no candidato, mas `config/production.json` é local/ignorado e o preflight exato não foi executado. |
| 9 | schema/backend ↔ app | BLOCKED | Consulta pública de 12/10: produção `0028`, staging `0029`, candidato `0030`; produção declara `compatibility_verified=false`. Exigir comparação e upgrade compatível no SHA congelado. |
| 10 | migrations no destino correto | BLOCKED | `0030` foi testada localmente em PostgreSQL; produção segue em `0028`. Aplicação e compatibilidade no destino de produção não foram comprovadas. |
| 11 | backup configurado e monitorado | PARTIAL | O apontador `last-success.json` do Dokploy indicou o backup `20261012T034000Z-80e0615f8a9a453a9a4936c60b420e17`, concluído às 03:40:08 UTC com estado `verified`. Recibo e arquivo criptografado foram baixados em modo somente leitura do R2; 249216 bytes e SHA-256 coincidiram. Prova sanitizada em `evidence/scheduled-postgres-backup-custody-20261012.json`. Ainda faltam teste de entrega do alerta e nova verificação de idade na janela de promoção. |
| 12 | restauração independente | BLOCKED | `production-restore-acceptance.json` existe, com cinco booleans, mas sem referências. Track B comprova o volume AnythingLLM; o ensaio PostgreSQL versionado vai até `0020`. O verificador exige recibo agendado ligado ao dump restaurado, um ensaio PostgreSQL único, árvore Git da API e drill recente; o aceite histórico falha. Há runner opt-in para restaurar o objeto agendado em container descartável e gerar prova parcial. O par criptografado mais recente está conferido, mas ainda não foi descriptografado nem restaurado: falta o caminho da identidade age privada e a execução supervisionada com `sudo` no avellaria. |
| 13 | secrets fora do Git | PARTIAL | O scanner local com gitleaks 8.28.0 não encontrou vazamentos em 52 commits da base de PR #194 até `f5f679e`; o digest histórico que gerava falso positivo recebeu exceção fixada ao valor exato. O check de CI passou nesse head. Repetir no SHA final, sem copiar credenciais para evidências. |
| 14 | HTTPS/domínio/SSL | PARTIAL | TLS passou em probes históricos; repetir validade e rota durante a janela de promoção. |
| 15 | testes de release | PARTIAL | Suíte completa da API passou localmente; PostgreSQL 16 descartável na porta local passou 4/4 testes opcionais de turma/migration; gate de restore e runner opt-in 29 testes unitários passaram (1 integração opt-in ignorada nessa execução), com restore Docker sintético separado incluindo cleanup; harness 20/20, preflight RAG 8/8, promoção curricular 10/10 e Worker 32/32 passaram. No checkout Windows do candidato, recorte Flutter 61/61, widget do Tutor contextual 7/7 e análise Flutter 3.44.9 sem achados. A CI aplicável passou em `f5f679e`; confirmar a CI do SHA final no PR #194. Seis contratos backend do E2E de turma passaram, mas a compilação Android foi interrompida antes do APK por pressão de swap no avellaria; ver `evidence/class-lifecycle-e2e-attempt-20261012.json`. Faltam concorrência PostgreSQL específica e E2E Android completo. |
| 16 | upgrade do app publicado | BLOCKED | Evidência de 06/10 cobre o app publicado `1.2.0+11` contra backend anterior; falta upgrade real do candidato `1.4.0+13` preservando dados/sessão. |
| 17 | manifesto do build | BLOCKED | Só é produzido após preflight e AAB do SHA congelado; nenhum manifesto atual foi gerado. |
| 18 | SHA-256 do AAB | BLOCKED | O AAB registrado está `superseded`, não corresponde à fonte atual e tem `upload_allowed=false`. |

## Gates adicionais para aulas reais

- **Turma:** backend, app e E2E da #138–#140 foram exercitados com dados
  sintéticos em API/banco descartáveis. A decisão de 12/10 altera autoridade do
  operador e capacidade; os PASS de 05/10 não aceitam essa regra nova. Testes
  locais de API e Flutter exercitaram a nova regra. A candidata prende a
  edição revisada, preserva recibo de preparo antes do POST em armazenamento
  seguro com escopo API/conta e reconcilia ao reabrir a tela, inclusive após
  resposta perdida. O validador agora rejeita o PASS antigo de capacidade rígida.
  A execução isolada de 12/10 passou seis contratos backend, mas o Gradle
  consumiu quase todo o swap no avellaria antes do APK ou resultado Flutter;
  o harness limpou API e arquivos temporários. O emulador alternativo LARGeo
  estava em uso pela pessoa usuária. Não há manifesto PASS do Android.
  Reexecutar o E2E em host com recursos livres, depois em staging.
  `CLASS_LIFECYCLE_ENABLED` segue false até promoção.
- **Tutor contextual:** o sentinel A/B prova isolamento CourseVersion com
  documentos sintéticos em staging. As cartilhas curriculares ainda não têm
  ingestão versionada, workspaces por edição nem mapa produtivo comprovado.
  Em 12/10, os nove PDFs obtidos pelos IDs do Drive conectado coincidiram em
  SHA-256, tamanho e assinatura PDF com os originais históricos; a prova
  sanitizada está em `evidence/curricular-drive-bytes-20261012.json`. Os nove
  PDFs da pasta Drive `Cartilhas (Versão Chatbot)` também coincidiram byte a
  byte (`evidence/curricular-drive-folder-20261012.json`). Rafael atribuiu a
  diagramação a Gabriela e a produção a estagiários; não foi localizada uma
  decisão editorial por edição. Os PDFs não estão versionados no checkout.
  Ainda faltam exports atuais das CourseVersions publicadas e indexação. O
  Worker rejeita contexto
  sem fonte (`503`) de forma
  deliberada; validar o caminho cartilha → Tutor antes de aulas.
- **Observabilidade:** o watchdog atual mede API/banco. O candidato de probes
  públicos cobre somente os dois Workers, sem inferência ou saúde do túnel,
  AnythingLLM/OpenRouter; ativação e teste de entrega do alerta ainda faltam.
- **Continuidade:** Rafael assumiu a responsabilidade principal por VPS,
  Dokploy, túnel, Worker, AnythingLLM, OpenRouter, backups e release em 12/10.
  Ainda faltam substituto, teste de recuperação de acesso, reboot e
  orçamento/quotas.

## Próxima evidência necessária

1. Reexecutar o E2E Android da política nova de turma em host com recursos
   livres e comprovar a tela de ativação e o aviso acima de 30, sem tocar dados reais.
2. Versionar prova sanitizada de restore PostgreSQL e offsite agendado para o
   schema candidato; revisar custódia humana dos recibos e a idade do backup.
3. Obter exports atuais das CourseVersions publicadas e aprovação editorial;
   preparar corpus por edição com os nove PDFs verificados, ingestão isolada e
   reconciliação; validar citações e revogação na rota real do app.
4. Validar probes, donos e canal de alerta; conferir saúde do upstream/modelo
   por sinal próprio antes de declarar o Tutor monitorado.
5. Só então congelar SHA/tag, aplicar gates de compatibilidade e upgrade,
   executar suíte de release, gerar novo AAB/manifesto e submeter à revisão de
   promoção. Nenhum PASS local autoriza deploy ou Play por si só.
