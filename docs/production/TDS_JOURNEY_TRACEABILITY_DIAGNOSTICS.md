# Diagnóstico do recorte de rastreio — 01/10/2026

## Instalação do gate de acesso e PDF no POCO

- Observed: build passou; duas instalações ADB retornaram erro, pacote exclusivo
  ausente. Segunda saída: INSTALL_FAILED_USER_RESTRICTED: Install canceled by user.
- Expected: confirmação do instalador antes da primeira fase Android.
- Responsible Boundary: instalador Android/ADB, antes de qualquer fase do app.
- Evidence: classroom-access-abbdfe6c3fd54366b26c46d1d6075954-android.json,
  fase install, zero reports, Play/DEV intactos e rede restaurada; APK
  c1864113d395948e06c6fa95dc06d25204a3f10e4b42a99c3efa510440874ec2 preservado.
- Likely Root Cause: Android não recebeu/aceitou confirmação do instalador.
  A primeira versão do runner suprimiu a saída; a retomada registrou cancelamento
  pelo instalador. Não inferir se foi ação manual ou restrição automática do POCO.
- Affected Files: tooling/test_classroom_access_android.ps1 e artefatos QA.
- Structural Fix: gravar install.log; retomada explícita limitada ao APK ausente
  e nunca executado, mesmo hash e fontes do app, resultado anterior preservado,
  saída nova android-install-resume. Não recompilar nem repetir preparação.
  Retomada também parou em install; zero fases, APK idêntico, Play/DEV intactos,
  sem erros de cleanup. Aplicada regra de duas ocorrências: parar tentativas e
  alterações do harness; próxima execução depende de confirmação presencial.
- Reason: instalação física exige interação com o aviso do Android.
- Exact human action: manter POCO desbloqueado e tocar Instalar em Tutor TDS QA.
- What remains unblocked: documentação, auditoria de hospedagem e QA local do PDF.

Resolvido após nova mensagem humana ready: mesmo APK instalado com sucesso,
sem recompilar, recriar turma ou repetir fase Android. Saída separada
android-install-resume-human-ready mantém as duas tentativas anteriores intactas.
Oito fases Android passaram; relatórios, fontes e preservação conferidos em
classroom-access-physical-acceptance-2026-10-01.json. O nome da tentativa tornou-se
parâmetro restrito para preservar os diretórios; contrato do teste não mudou.

Tentativa independente de abrir o link público do PDF no POCO por Android VIEW
foi recusada pela revisão automática antes da execução (blocked by policy, sem
motivo detalhado). Nenhum caminho alternativo de automação foi tentado. Link
fornecido a Rafael para abertura manual; renderização segue não verificada.

Atualização posterior: o botão real foi acionado pela instrumentação Flutter e
abriu o seletor do Drive. Rafael escolheu sua conta no aparelho e respondeu
“Sim, o PDF abriu”; screenshot posterior mostra a cartilha renderizada. Não
houve repetição do comando direto anteriormente recusado.

## Diretório de execução do novo gate de acesso

- Observed: duas invocações usaram caminhos relativos da raiz em diretórios
  diferentes: marcador tmp sob api/ e parse de tooling sob o junction Flutter.
- Expected: artefatos operacionais na raiz; somente Flutter executado no junction.
- Responsible Boundary: diretório de trabalho do harness no host.
- Evidence: erros de caminho ausente; fixture abbdfe6c3fd54366b26c46d1d6075954
  foi preparada uma vez e preservada; nenhuma fase Android havia iniciado.
- Likely Root Cause: misturar operações da raiz e do app numa chamada de shell.
- Affected Files: marcador operacional em tmp; nenhuma regra de produto.
- Structural Fix: interromper repetição, separar chamadas da raiz e Flutter,
  conferir sintaxe na raiz e salvar o ID observado da fixture sem recriá-la.

## Power BI — aplicar alterações externas

- Observed: duas tentativas de clique no botão da cópia foram recusadas, por
  coordenada e por índice de acessibilidade; nenhum clique foi confirmado.
- Expected: aplicar as três consultas novas apontadas para a cópia privada.
- Responsible Boundary: alvo de entrada nativo versus filho WebView2 do Power BI.
- Evidence: ferramenta informa `Chrome Legacy Window`, processo msedgewebview2,
  sobre a janela PBIDesktop; mesmo resultado após ativação e observação nova.
- Likely Root Cause: validação de alvo não reconhece o modal WebView2 como filho.
- Affected Files: nenhum arquivo de produto; somente interação de homologação.
- Structural Fix: interromper cliques; observar foco e usar navegação por teclado
  do próprio modal, mantendo o destino retornado pela ferramenta.

## Ensaio de migração da cópia de produção

- Observed: primeiro ensaio restaurou/migrou, mas rede interna não publicou porta;
  segundo passou HTTP, mas comparação literal recusou campos aditivos; terceiro
  encontrou reinício normal do PostgreSQL entre bootstrap e servidor definitivo.
- Expected: verificar preservação do contrato legado e reversão de imagem sem
  acessar a produção por escrita ou publicar serviço de teste.
- Responsible Boundary: harness operacional de isolamento, readiness e comparação.
- Evidence: execuções 9b008dc1372c, 78d2edde905d, e4ec95545891; final cec516308697
  passou com original_columns_preserved, public_catalog_compatible e
  old_image_runs_on_upgraded_database. Recursos isolados removidos em todos.
- Likely Root Cause: probes no host; igualdade completa de JSON; pg_isready via
  socket detectava o servidor temporário do entrypoint.
- Affected Files: api/ops/rehearse_production_upgrade.py.
- Structural Fix: HTTP dentro do container; comparar todos os valores legados
  permitindo somente chaves extras; aguardar readiness TCP do PostgreSQL final.

## Abertura do modelo TMDL

- Observed: primeiro open recusou M com `Esperava-se o token Literal`.
- Expected: ler as quatro partições adicionadas pelo gerador.
- Responsible Boundary: delimitador de expressão verbatim TMDL.
- Evidence: documentação TMDL exige abertura de três crases imediatamente após
  `=`. Após correção o Desktop abriu as 18 páginas e quatro tabelas adicionais.
- Likely Root Cause: abertura das crases em outra linha era enviada como M.
- Affected Files: cartilhas_app/tool/build_tds_journey_bi.py e quatro TMDLs novos.
- Structural Fix: abertura na mesma linha de source; consultas originais intactas.

## Suíte API — janela temporal de avaliação

- Observed: 346 passaram, um teste retornou 8500 em vez de 10000.
- Expected: avaliação sintética de cinco estrelas dentro da janela de setembro.
- Responsible Boundary: relógio do cenário de teste, não cálculo comercial.
- Evidence: a avaliação usa horário do servidor; o teste encerra em 01/10 às
  00:00Z e era executado depois disso. Teste isolado passou após fixar seu relógio.
- Likely Root Cause: fixture misturava eventos históricos com avaliação de hoje.
- Affected Files: api/tests/test_media_commercial.py.
- Structural Fix: fixar somente o relógio das duas submissões sintéticas de
  avaliação; preservar autenticação, playback e regras reais.

## Conferência da ficha no POCO — primeira tentativa

- Observed: confirmação de formulário não recebeu toque; Salvar permaneceu
  desabilitado. Nenhuma escrita foi enviada/confirmada; GET mostrou baseline
  ausente e histórico vazio. Rede e APK DEV originais foram restaurados.
- Expected: tocar confirmação após o teclado/layout estabilizar e salvar online.
- Responsible Boundary: interação do integration_test com checkbox e teclado.
- Evidence: aviso de hit test perdido no checkbox no log do run
  7ce3b59a891940cda4387766627e3e14; API retornou history_count=0.
- Likely Root Cause: coordenada mudou durante animação do teclado/rolagem.
- Affected Files: integration_test/journey_baseline_control_test.dart.
- Structural Fix: finalizar edição, esperar layout e tocar CheckboxListTile;
  exigir onPressed habilitado antes de tocar Salvar. Não silenciar hit test.

## Preflight do runner físico

- Observed: duas execuções recusaram o APK DEV existente antes de build/install;
  nenhuma sessão, rede ou pacote do telefone foi alterado.
- Expected: reconhecer a identidade DEV e preservar seu binário para restauração.
- Responsible Boundary: resolução do executável aapt/inspeção do manifest no host.
- Evidence: inspeção direta com build-tools/36.1.0 confirmou .dev e debuggable;
  o helper retornou classificação incompatível. Execuções retidas em tmp.
- Likely Root Cause: aapt falha com caminho absoluto contendo acentos; a leitura
  relativa ASCII do mesmo APK retorna identidade correta. Confirmado isoladamente.
- Affected Files: tooling/test_journey_android.ps1.
- Structural Fix: arquivos nativos de QA pelo junction ASCII já aprovado;
  exigir identidade/versionamento antes de qualquer alteração no telefone.

## HTTPS do Android QA

- Observed: duas verificações públicas excederam o prazo; backend e acesso direto
  pelo Traefik retornaram health 200. API de produção continuou respondendo.
- Expected: rota temporária de staging usa dokploy-network e retorna health 200.
- Responsible Boundary: descoberta de rede do provider Docker do Traefik.
- Evidence: serviço tds-context-android-f31fc29a40@docker apontava para
  172.31.0.3 (rede interna), embora a rede pública já tivesse IP 10.0.1.34.
- Likely Root Cause: container foi descoberto antes de conectar a segunda rede;
  a conexão posterior não atualizou o destino em cache do provider.
- Affected Files: api/ops/context_android_staging.py; somente recursos
  temporários registrados em /opt/tutor-tds-context-android-qa-journey-20261001.
- Structural Fix: após conectar a rede autorizada, reiniciar exclusivamente o
  container QA registrado e verificar tanto o destino descoberto quanto HTTPS.
  Nunca reiniciar o Traefik global ou alterar o banco/containers existentes.

## Aplicação de patches

- Observed: patches com contexto desatualizado falharam na verificação, sem
  aplicação parcial; repetição interrompida.
- Expected: patch corresponde ao trecho atual inspecionado.
- Responsible Boundary: edição local, verificação de contexto da ferramenta.
- Evidence: mensagens de contexto ausente; código anterior preservado.
- Likely Root Cause: patch amplo e trechos presumidos.
- Affected Files: arquivos do recorte; sem escrita externa.
- Structural Fix: ler o trecho real e aplicar alterações pequenas e sequenciais.

## Refresh Desktop — tipos numéricos das consultas legadas

- Observed: após login e refresh, o novo rastreio filtrou duas contas QA, mas
  os cartões antigos de CadÚnico e outros flags falharam. Desktop salvou flags
  de Baseline/ComplementoBaseline como string, apesar do contrato int64 original.
- Expected: refresh preserva valores numéricos/nulos e as medidas originais.
- Responsible Boundary: tipo de saída Power Query depois de Table.FromRecords
  e expansão das respostas; não é autorização, evento ou dado escrito no Sheets.
- Evidence: Resumo Executivo manteve 510 inscrições, 421 digitais e 89 scans;
  detalhe CadÚnico: a função SUM não pode trabalhar com valores do tipo String.
  Arquivos anteriores à correção preservados em validation/desktop-before-numeric-fix
  no pacote do piloto; hashes em validation/legacy-numeric-fix.json.
- Likely Root Cause: expansão de registros sem schema explícito devolve colunas
  any; Desktop infere string no refresh e sobrescreve os tipos declarados.
- Affected Files: cópia Baseline.tmdl e ComplementoBaseline.tmdl; gerador do BI.
- Structural Fix: opção --stabilize-legacy-numeric-types aplica os tipos int64
  do template ao resultado final das duas consultas, preservando nulos e erros.
  Não altera fontes, IDs, respostas, joins nem planilhas. Novo refresh e cartões
  conferidos no Desktop; 510 inscrições preservadas e cinco indicadores do resumo
  calculando. Após salvar, tipos declarados iguais ao template nas duas tabelas.
  Persistem erros de dados legados: 68 linhas Baseline e 65 Jornada; inspeção de
  data_inicio mostrou DataFormat.Error para -684259. Não imputar data ou apagar
  registros. Erros das consultas podem se sobrepor; não são 133 pessoas distintas.

## Diálogos nativos e WebView2 do Power BI

- Observed: captura da janela principal ocasionalmente mostrou pixels da janela
  em primeiro plano; índices do diálogo de recuperação não estavam no cache.
  Clique no diálogo WebView2 via janela principal foi recusado por alvo distinto.
- Expected: ação e captura dirigidas à janela e ao screenshot corretos.
- Responsible Boundary: seleção de janela e captura do Computer Use.
- Evidence: alvo não correspondente e element not available; nenhum comando de
  exclusão ou publicação foi executado. Recuperação ficou em manter arquivos.
- Likely Root Cause: janelas secundárias e múltiplas capturas com origens diferentes.
- Affected Files: nenhum código de produto.
- Structural Fix: reativar a janela retornada, recapturar, selecionar diálogo
  retornado por list_windows ou seu screenshot secundário; não reutilizar índices.

## Instalação do QA separado no POCO — 01/10

- Observed: run b8530a06b49342aea2d6a4d59d252f33 compilou, mas a instalação
  foi cancelada pelo Android: INSTALL_FAILED_USER_RESTRICTED / Install canceled
  by user. Nenhuma fase Android iniciou; pacote QA ausente depois da recusa.
- Expected: o titular confirma a instalação USB do pacote Tutor TDS QA.
- Responsible Boundary: confirmação de segurança do MIUI/Android, antes do app.
- Evidence: APK 80be01be6ce6f3a053c286bb55762314c4de1bfad971495f7a89708c2f458b1c;
  run-state preservado, cleanup sem erros; log do PackageInstaller às 14:22:50.
- Likely Root Cause: confirmação no aparelho ausente/expirada. Não implica erro
  de login, código de curso ou autorização da API.
- Affected Files: runner/diagnóstico QA; nenhum dado dos aplicativos Play/DEV.
- Structural Fix: registrar somente código público de erro, preservar APK/run,
  avisar antes da instalação e solicitar presença do titular. Rafael respondeu
  pronto; novo run 21004481ad774d1e85a9f477ee661d37, sem reset ou retomada cega.

## Prévia editorial no POCO — execução 21004481

- Observed: login, criação e salvamento do rascunho ocorreram; acionamento da
  prévia falhou em tester.widget com StateError: No element após ensureVisible.
- Expected: alvo montado e alcançável depois da animação do teclado/rolagem.
- Responsible Boundary: sincronização do integration_test com o viewport físico.
- Evidence: dynamic-learning-poco-2026-10-01-attempt2.json; marcadores draft_save
  e preview_open, sem preview_verified. Rascunho, APK e sandbox preservados.
- Likely Root Cause: teclado/rolagem retiraram o botão da árvore entre localizar
  e tocar; hipótese compatível com o stack, sem falha de regra de publicação.
- Affected Files: integration_test/dynamic_learning_path_test.dart; runner e
  Gradle debug para sandbox própria por run, sem substituir aplicativo anterior.
- Structural Fix: finalizar foco, esperar insets do teclado e rolagem terminarem,
  revalidar presença do alvo. Analyze passou. Ensaio novo usa outro curso/pacote;
  não retoma mutações incompletas nem apaga o rascunho anterior.

## Conferência após instalação — execução 3c2d3885

- Observed: instalação concluída às 14:34:49; runner falhou em single_install
  antes de tentar qualquer fase Android. Mensagem original não identificou qual
  leitura shell falhou; não atribuir causa definitiva.
- Expected: conferir identidade/hash do APK antes do primeiro lançamento.
- Responsible Boundary: leitura ADB pós-instalação no host, antes do aplicativo.
- Evidence: run-state original preservado com attempted_phase=null; inspeção
  posterior confirmou installed=true, stopped=true, notLaunched=true e APK
  c59d4044e6a9718ec60f6f9dcb0c9d012117afe0693efd2aa6cafab0ce6a02dd.
- Likely Root Cause: falha transitória na leitura pós-instalação é hipótese;
  comando exato e causa não demonstrados pelo diagnóstico original.
- Affected Files: somente harness de QA; produto e estado Play/DEV preservados.
- Structural Fix: recuperação delimitada ao run exato, APK/hash idênticos e
  notLaunched=true, recusando qualquer app já iniciado. Novo diretório de
  evidências e baseline somente leitura; zero build, instalação ou reset nessa
  recuperação. Não automatizar retomada de uma fase Android com mutações.
  Script tmp/recover_dynamic_prelaunch_3c2.ps1 preservado e incluído nos hashes
  da execução. Resultado final deve ser conferido separadamente.
  Fechamento: oito fases e quatro verificações passaram; evidência completa
  dynamic-learning-poco-2026-10-01.json e aceite físico separado. Falha original
  continua registrada em dynamic-learning-poco-2026-10-01-attempt3-prelaunch.json;
  o sucesso posterior não determina retrospectivamente a causa da leitura ADB.

## Imagem candidata da API — dependências e base

- Observed: Dockerfile antigo instalava faixas do pyproject via pip e o digest
  Python 8d9d0b8… não passou na verificação do registro. Cliente Docker padrão
  também recusou GHCR; configuração pública isolada conseguiu consultar/puxar.
- Expected: base verificável por digest e dependências iguais ao uv.lock.
- Responsible Boundary: empacotamento da API, sem migração adicional.
- Evidence: journey-locked-api-candidate-2026-10-01.json; 62 dependências iguais
  ao lock, Python 3.13.15, oito testes de rastreio/migração/export e cinco testes
  locais de proveniência passaram. Migração populada executada em PostgreSQL 16
  descartável; recursos desse ensaio removidos.
- Likely Root Cause: referência de base indisponível/inválida e instalação sem
  lock; autenticação/configuração do cliente de registro exigia isolamento.
- Affected Files: api/Dockerfile; não alterar autenticação Docker global.
- Structural Fix: bases Python/uv por digests observados; uv sync --locked,
  sem instalar build backend flutuante. Runtime candidato ainda não implantado;
  identificador de working tree não satisfaz gate formal de revisão Git/release.
  Referência: https://docs.astral.sh/uv/guides/integration/docker/.
