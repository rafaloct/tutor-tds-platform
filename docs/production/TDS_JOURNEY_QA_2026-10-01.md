# Identidade e jornada — verificação de 01/10/2026

Recorte implementado e validado com contas sintéticas. Não é acceptance de
produção nem aprovação integral do BI. Refresh/filtros do rastreio sintético
passaram no Desktop; há erros de dados legados pendentes. `JOURNEY_TRACEABILITY_ENABLED`
permanece false por padrão na API e Flutter; release_status.json continua com
release_build_allowed=false. Play 1.2.0+11 preservada no POCO; assinatura e KV
não foram alterados. Oferta/equipe do piloto ainda não provisionadas.

## Resultado funcional

- Sessão rejeita respostas tardias de login/refresh/requests após logout/troca.
- Identidade usa a conta online existente e HMAC estável para acompanhamento.
- Baseline ausente permanece pendente. Vínculo exige equipe no escopo, revisão,
  data real, motivo e histórico; ID real do BI pode ser referência sem tablet.
- Reservas anteriores e vínculo exclusivo impedem reassociação silenciosa.
- Consentimento novo para a jornada; escolha antiga não ativa esse escopo.
- Tempo de tela pausa em segundo plano/modal e limita inatividade; ajuda não
  exporta texto da pergunta. Fila por dono/API preserva eventos offline.
- Telemetria recebe zero crédito acadêmico. Resultado humano/KV não identificado
  permanece desconhecido, sem completar frequência/mentoria/certificação.
- Export autorizado sanitizado produz participantes, jornada e atividade diária.

## Gates do recorte

| Verificação | Resultado | Evidência/limite |
| --- | --- | --- |
| Flutter local | 73 testes distintos passaram, em execuções do recorte | Sessão, telemetria/clock/consentimento, outbox, formulário/repository, resumo/assessment/Tutor; não é suíte completa de release |
| API locked local | 37 passaram | Journey/followup/events, export tools e migrations afetadas; SQLite |
| PostgreSQL 16 | 1 gate passou | evidence/journey-final-postgres-gate-2026-10-01.json; base vazia e populada, guards/replay/conflito/rollback |
| Analyze Flutter | Sem problemas nos arquivos afetados | Última execução inclui formulário e integração baseline/driver; sem upgrade de SDK/dependências |
| POCO online/offline/reconexão | Três fases passaram | evidence/journey-android-2026-10-01.json; dez eventos offline entregues uma vez; sessão anterior restaurada |
| POCO conferência real pela UI/HTTPS | Passou | evidence/journey-baseline-android-2026-10-01.json; pendente antes da ficha, mesmo ID depois, source BI-only e revisão auditada |
| CSV final por HTTPS | Passou | outputs/TDS_Journey_Final_QA_Export_2026-10-01; três CSVs, uma participação/inscrição sintética e zero atividade nesse gate específico |
| Cópia BI | 18 páginas abertas; contas/tempo/ajuda e filtros sintéticos validados | JornadaApp vazia; vínculo confirmado/certificado e qualidade legada ainda fora deste aceite |
| Limpeza QA/restauração | Concluída | evidence/journey-cleanup-2026-10-01.json; recursos próprios removidos, staging original e produção GET /health 200 |

A primeira tentativa do teste físico de baseline falhou no acionamento do
checkbox após animação do teclado, antes de qualquer PUT. Estado vazio foi
conferido; uma correção apenas na automação estabilizou o acionamento e a
segunda tentativa passou. Primeira evidência preservada separadamente. Outros
diagnósticos de fronteira estão em TDS_JOURNEY_TRACEABILITY_DIAGNOSTICS.md.

## Artefatos e hashes

API final do gate: `tutor-tds-context-gate:09b1045fc39b`; arquivo de source
SHA256 `09b1045fc39be11afa5d19a9c4a07e9b21ad5f86e5d344b0a835a0a0d698f06c`.
PostgreSQL tmpfs e APIs temporárias encerrados após exportação e teste físico.

APK DEV normal sem credenciais de QA:
`outputs/Tutor-TDS-Journey-2026-10-01-staging-dev.apk`.
SHA256 `e195a7f93b0781d2c24455c893c23897f45168b3b9e5f7e08b553e053d2ffa26`.
É variante DEV/debug para revisão, não AAB assinado de Play. A API temporária
que o validou foi removida; não promete funcionamento contra o staging anterior.

Os APKs de instrumentação são exclusivos de QA e contêm contas sintéticas:
atividade `4f54429f51bbfec9b1f5b0c9f88fb71640114ee92ef0214e29bd7d083225801e`;
baseline `7725d3d47e8ade656c2b71282bc6922ab54c06bbd4f8545a97483e12b78ed026`.
O binário DEV anterior, SHA256
`8ceccdf33d42dbb60979eca761aa680f92598cf5999508e2012ca9706563b349`, foi restaurado.
Produção com package com.tutortds_cartilhas/11 não foi substituída.

BI: `outputs/TDS_Journey_Pilot_2026-10-11/TDS_Rastreio.pbip` e
`pilot-registration-plan.json`. Quatro tabelas e uma página acrescentadas;
17 páginas preservadas byte a byte (529 arquivos JSON). Baseline original SHA256
`a07a8fa56e264d9859993acb1297780b66ddd63b756201cfaa34c8e2e7bf4469`;
após fixar tipos na saída da consulta, candidato SHA256
`c0f7fe9dc2f7d63447c04f81f742d7fb1fb84faa882b818a39a10f104cb45559`.
ComplementoBaseline recebeu a mesma correção; tipos originais verificados após
save/refresh. Fontes, valores, joins e regras de respostas não foram alterados.
Jornada SHA256 `895f89cadde4b10b398f89fcedfe5ae5364e525c56eeb2cc61014e475b1b54b2`.
Até o gate Android não houve escrita externa. Na continuação Astra, foi criada
uma cópia privada de homologação do Google Sheets com três abas novas; apenas
dados de uso sintéticos foram escritos nessas abas. A planilha de produção,
o relatório Fabric e o fluxo recorrente continuam inalterados.

## Continuação técnica executada por Astra

| Verificação | Resultado | Evidência/limite |
| --- | --- | --- |
| Flutter completo | 367 passaram; analyze sem problemas | journey-expanded-validation-2026-10-01.json |
| API completa | 346 passaram; um falhou por janela fixa de setembro versus relógio atual | Corrigida somente a fixture; rerun desse teste passou; não declarar execução completa 347/347 |
| Restore e migração real isolada | 0005→0020; valores originais preservados | journey-production-rehearsal-2026-10-01.json, run cec516308697; fonte com nove cursos e zero contas |
| Retorno à imagem antiga | health e catálogo preservados na base atualizada | Não cobre todos os fluxos autenticados do app antigo |
| Backup fora do VPS | Cópia criptografada, hash e roundtrip verificados | journey-off-vps-backup-2026-10-01.json; DPAPI depende deste perfil Windows |
| Compose | Produção/staging válidos, flags false, pseudônimo na API, worker opt-in | journey-compose-config-2026-10-01.json; sem deploy |
| Power BI Desktop | Login concluído pelo titular; refresh, render e filtros sintéticos passaram | journey-bi-desktop-2026-10-01.json; 2 contas/2 pendências/3 minutos/1 ajuda; cartões legados corrigidos |
| Qualidade legada | 510 linhas carregadas; 68 com erro em Baseline/65 em Jornada | DataFormat.Error em data_inicio observado; não inferir datas nem somar os erros como pessoas distintas |
| Google Sheets | Cópia privada nativa; 66 abas preservadas + três novas; readback consistente | Duas pessoas QA pendentes, três linhas de atividade, zero inscrições; nunca promover como participantes reais |

Gerador reproduz os quatro TMDLs e permite --app-spreadsheet-id e
--stabilize-legacy-numeric-types. As 17 páginas originais e Jornada continuam
idênticas ao template. Baseline/ComplementoBaseline fixam tipos int64 na saída,
após falha real SUM/string no refresh; o resumo voltou a calcular (CadÚnico
418/505; rural 396/503; atividade produtiva 199/499; internet 401/502; política
produtiva 69/483). Esses denominadores respeitam respostas válidas, sem imputar
ausência como não. O delimitador
verbatim TMDL foi corrigido após erro real no Desktop, conforme documentação
Microsoft. Detalhes das falhas/correções em TDS_JOURNEY_TRACEABILITY_DIAGNOSTICS.

Auditoria de build executada: bloqueada somente por physical_evidence_pending
e release_build_frozen, sem apontar divergência de configuração ou assinatura.
Na preparação inicial, gates exigidos: certificate_human_approval_e2e, classroom_cold_offline_xiaomi,
course_versioning_xiaomi e evidence_offline_xiaomi. Nenhum foi marcado aprovado
por equivalência com os gates de rastreio. Produção e staging originais retornaram
health 200 no fechamento da preparação. Não houve nova publicação na Play.

## Próximas fronteiras

Continuação: staging Cloud restaurado da pausa, backup verificado e schema
0019→0020 com 42 tabelas preservadas. Deploy f060ca99-4715-4265-8466-9249329a8e1a
saudável; 62 dependências conferidas no lock. Dockerfile do VPS agora também
usa lock e bases por digest: candidato 6d2dd96f3b40 passou oito testes de
rastreio/migração/export com PostgreSQL real no teste de migração; cinco testes
locais de proveniência passaram. Imagem não implantada e revisão Git de release
ainda pendente. Ambiente Android passou 14 casos, inclusive pacote QA separado
e release congelada. Primeira instalação física exigiu confirmação MIUI; run
preservado e novo ensaio iniciado após Rafael informar que estava pronto.

Fechamento físico: run 3c2d38851f024a1eb50667aa86dc7ce0 concluiu oito fases e
quatro verificações host no POCO. Uma única instalação do APK isolado foi usada;
após falha de leitura pré-lançamento, recuperação verificou hash/notLaunched e
executou todas as fases, sem reinstalar/resetar. V1 chegou a 5%, v2 ficou em 0%;
replay sem duplicata e paridade professor/aluno passaram. Preservados 224 eventos,
57 registros anteriores, Play 1.2.0+11 e DEV. Rede restaurada e QA encerrado.
Evidência wave2a-physical-acceptance-2026-10-01.json fecha somente
course_versioning_xiaomi; os outros três gates e freeze continuam. API de produção,
staging VPS e staging Cloud retornaram health 200 no fechamento.

Reinspeção do Worker confirmou pendência já documentada em
maintenance/CLASSROOM_OFFLINE_AND_CERTIFICATE_DECISION_2026-09-21.md: emissão
legada ainda usa declarações do cliente, sem canal autenticado API→Worker.
Esse gate exige implementação/compatibilidade na fatia Certificates, não apenas
executar um teste pendente. Preservar KV e política de revisão humana; não
alterar produção nem marcar certificado emitido a partir de um pedido aprovado.

Piloto confirmado: Palmas, Itaguatins e Augustinópolis, 11–30/10/2026, 40 horas,
conferência por Rafael. Curso `ia-cartilha` localizado no catálogo público da
API de produção, sem presumir oferta/edição/matrícula autorizadas.

Intervenções humanas com Reason/Exact human action/What remains unblocked no
TDS_JOURNEY_PILOT.md: provisionar oferta/edição e conta de equipe; conferir dados
legados e vínculo confirmado no BI, com destino restrito; acceptance da release, política de privacidade,
Data Safety e promoção do AAB preservando assinatura. Não reclassificar este
recorte como PRODUCTION_READY a partir de UI, JSON ou testes isolados.
