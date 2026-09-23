# Diagnósticos de fronteira — 2026-09-23

## Persistência entre execuções Android — fronteira do testador identificada

- Observed: seed passou; execução verify encontrou banco vazio.
- Expected: pendência preservada depois de force-stop do pacote .dev.
- Responsible Boundary: Flutter integration test runner, não SQLite.
- Evidence: `flutter_tools/lib/src/test/integration_test_device.dart` kill()
  chama uninstallApp quando debuggingOptions.uninstallApp; `flutter test --help`
  documenta uninstall=true por padrão.
- Likely Root Cause: desinstalação automática remove dados entre os dois testes.
- Affected Files: protocolo de execução de outbox_persistence_test.dart.
- Structural Fix: usar --no-uninstall nas duas fases; manter mesmo pacote .dev,
  encerrar o processo via adb e verificar antes da limpeza explícita do banco QA.

## Exportação HTML Stitch — RESOLVIDO no navegador integrado

- Observed: download autenticado da metadata funciona; URL de HTML retorna
  login Google via HTTP/curl; navegador retorna ERR_BLOCKED_BY_CLIENT.
- Expected: HTML da tela Classroom, não página de autenticação.
- Responsible Boundary: exportação Google/Stitch e sessão de navegador.
- Evidence: metadata local htmlStatus=BLOCKED_GOOGLE_SIGN_IN; HTML rejeitado
  mantido somente em tmp ignorado; screenshot inspecionado com hash registrado.
- Likely Root Cause: URL de contribuição exige sessão Google/permissão distinta
  da chave MCP; causa do bloqueio do navegador não confirmada.
- Affected Files: `.stitch/designs/389e412e620c4c49841a5e9508cf6bfb/`.
- Structural Fix: sessão autorizada do navegador integrado permitiu Mostrar
  código → Copiar código. HTML original salvo, validado e hash registrado;
  nenhuma necessidade de repetir a URL de download bloqueada.

## Flutter analyzer no caminho Unicode — contornado no QA

- Observed: framing JSON/LSP inválido no caminho original.
- Expected: análise estática concluída com diagnósticos reais.
- Responsible Boundary: toolchain Flutter/Dart e transporte de saída no Windows.
- Evidence: mesmo código/SDK analisado pelo junction ASCII terminou sem issues.
- Likely Root Cause: interação com caminho Unicode/transporte; hipótese, não
  diagnóstico definitivo do SDK.
- Affected Files: nenhum arquivo funcional precisou de workaround.
- Structural Fix: executar QA pelo junction documentado em CONTEXT_CORE_SLICE;
  manter SDK, código e testes; não ocultar diagnósticos de produto.

## Supabase: seleção de região no navegador — resolvido

- Observed: duas tentativas de clique em opção visível expiraram.
- Expected: selecionar São Paulo uma única vez antes de criar projeto.
- Responsible Boundary: interação do navegador com dropdown.
- Evidence: DOM manteve Americas; opção São Paulo presente/ativa após teclado.
- Likely Root Cause: clique/rolagem do controle via automação; não confirmado.
- Affected Files: nenhum arquivo funcional.
- Structural Fix: selecionar pelo teclado no próprio controle, conferir DOM;
  São Paulo confirmado antes da criação do projeto de staging.

## HTTPS do candidato gerenciado — cliente de verificação

- Observed: urllib padrão recebeu Cloudflare 403/1010 em /live; deploy success.
- Expected: HTTP 200 no endpoint público de saúde.
- Responsible Boundary: borda do provedor/identificação do cliente HTTP.
- Evidence: cliente httpx identificado como TutorTDS-StagingAcceptance/1.0
  recebeu /live e /health 200, TLS válido; registro cloud-staging-http.json.
- Likely Root Cause: filtragem de User-Agent padrão urllib na borda.
- Affected Files: nenhuma mudança da API/autorização/TLS.
- Structural Fix: usar identificação verdadeira do verificador e verificar
  separadamente o cliente Android; não representar esse teste como aceite mobile.

## Catálogo atualizado → central de estudo — primeira falha identificada

- Observed: recorte 61568 passou 29 testes; navegação com edição nova produziu
  RenderFlex overflow de 18px na base de um card da central de estudo.
- Expected: recurso legível e acessível após atualizar o catálogo, inclusive
  quando título/descrição quebram linhas ou a fonte está ampliada.
- Responsible Boundary: StudyHubScreen / _ResourceCard, layout de altura fixa.
- Evidence: home_catalog_refresh_test, caso bottom learning destination waits;
  viewport 1000x1600/DPR1; SliverGrid mainAxisExtent=174 + Column com Spacer.
- Likely Root Cause: conteúdo exige cerca de 152px internos após quebra do
  título; margem/padding deixam cerca de 134px no card fixo. O mesmo limite
  não acompanha fonte ampliada. Não houve segunda tentativa desse erro.
- Affected Files: study_hub_screen.dart; study_hub_test.dart.
- Structural Fix: Wrap com os mesmos breakpoints/colunas, cards de altura
  natural e espaçamento fixo; descrição pode crescer. Preservar ordem/ações.
  Regressões 320/1000px, fonte 100%/200%; validar sem alterar o viewport do
  teste que revelou o problema ou ocultar exceções. Recorte Home/StudyHub passou
  9 casos; o décimo expôs apenas ensureVisible antes de construir o sliver no
  teste 320px/200%. Corrigido para scrollUntilVisible limitado; repetição isolada
  passou. O overflow original e os quatro cenários responsivos foram verificados.

## Gate 2A: primeira troca de conta — primeira tentativa

- Observed: execução `603b9cc65be945c1b9f17f6925b075bc` falhou em
  `_signedIn`/`_reveal`, procurando "Sair da conta" antes de criar o curso.
- Expected: aguardar a verificação da conta em Settings e usar a ação disponível.
- Responsible Boundary: integração Android; montagem assíncrona do estado da conta.
- Evidence: `author_v1.log`, hash em `evidence/dynamic-learning-first-attempt.json`;
  Settings inicia verificando e só monta logout depois de consultar a sessão/API.
- Likely Root Cause: helper usava a espera de 300ms do clique e tratava a ação
  ainda ausente como conteúdo fora da área visível, esgotando a rolagem.
- Affected Files: `integration_test/dynamic_learning_path_test.dart`; nenhuma
  alteração de produto demonstrada necessária.
- Structural Fix: revelar o status da conta, esperar conectado/sem sessão,
  reler identidade e então navegar pela ação correta. Preservar guardas de
  propriedade/pendências; registrar eventual invalidação de sessão. Não capturar
  a exceção para prosseguir nem limpar dados. Manter tentativa falha e verificar
  banco/histórico antes de novo ensaio completo; não reseedar o ambiente.
