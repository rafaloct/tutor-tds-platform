# CW-1 — Central TDS visível, isolada e simulada

Execução local em 02/10/2026. Este registro cobre somente o primeiro diff executável
de CW-1 definido em `CHATWOOT_TDS_SUPPORT_CONTRACT.md`. Não ativa integração,
não comprova atendimento real e não altera produção.

## Proveniência

- Worktree: `C:\Users\Usuario\tds-agents\cw-1`
- Branch: `codex/cw1-offline-entry-20261003`
- Base/HEAD inicial: `82ea2f05cc4762671d7b1ef2ae941adf03e363b0`
- Destino previsto do PR: `codex/onda-0-consolidacao`
- Contrato integrado de referência: PR #22.
- Preflight: árvore limpa; pasta principal em worktree separada e não usada para edição.
- SDK usado: `C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat`.
- O junction histórico ASCII aponta para a worktree principal; não foi usado neste recorte.

## Implementação

A Central TDS de demonstração usa composição UI -> controller/estado -> interface
injetada -> fake local. O fake só é importado pelo bootstrap de demonstração e
pelos testes. A rota/main produtivos, `ChatwootScreen`, SDK/reset/serializador,
`AppConfig`, autenticação e flags existentes permaneceram intactos.

Assuntos expostos:

1. Ajuda com o aplicativo
2. Dúvida sobre o curso
3. Frequência/certificado
4. Interesse em mentoria
5. Dados/conta/privacidade
6. Ainda não sei

A interface apresenta ajuda textual curta, aviso persistente de DEMONSTRAÇÃO,
rascunho somente em memória e contexto acadêmico demonstrativo corrigível/removível.
Duas turmas sem contexto legítimo pré-selecionado não escolhem a primeira
silenciosamente. Ajuda de acesso funciona no perfil visitante sem CPF ou identidade
acadêmica e não expõe histórico ou vínculos de outra pessoa.

Estados injetáveis: carregando, pronto, rascunho, enviando, confirmação simulada,
erro/retentar e indisponível. Não há timer para fingir resposta. Abrir a tela,
escolher assunto ou ler a ajuda não envia nada. A prontidão é registrada pela
geração da sessão corrente e não pelo estado visual: editar rascunho/contexto
durante preparação ou indisponibilidade não libera envio. Retry de preparação
reexecuta `prepare()` sem limpar o rascunho nem enviar mensagem; retry de envio
reutiliza o mesmo `commandId`. Durante envio, novo toque é bloqueado antes do
primeiro await. Offline mantém somente o rascunho da sessão e informa `Não enviado`.

A confirmação usa texto explícito:
`DEMONSTRAÇÃO: confirmação simulada. Nenhuma equipe recebeu esta mensagem.`
Não existe estado ou texto `Recebido` nesta fatia.

Troca de sessão/dono invalida o rascunho e qualquer retorno assíncrono anterior.
Logout simulado limpa sessão, assunto, contexto, mensagem e confirmação. Nome,
telefone e diagnóstico extra não são transportados. Consentimento opcional negado
não bloqueia ajuda básica. O contexto local representa intenção de demonstração,
não autorização, presença, certificado, elegibilidade ou mentoria.

## Arquivos

- `cartilhas_app/lib/features/support/support_models.dart`
- `cartilhas_app/lib/features/support/support_gateway.dart`
- `cartilhas_app/lib/features/support/support_controller.dart`
- `cartilhas_app/lib/features/support/support_demo_screen.dart`
- `cartilhas_app/test/support_entry_test.dart`
- `cartilhas_app/test/support_controller_test.dart`
- `cartilhas_app/tool/support_preview.dart`
- `docs/production/CHATWOOT_CW1_IMPLEMENTATION.md`

## Validação focal

Analyze dos sete arquivos Dart afetados: PASS, zero issues. Após ajuste pontual dos
testes, `support_entry_test.dart` também passou isoladamente no analyze.

Testes executados:
`flutter test test\support_entry_test.dart test\support_controller_test.dart`.

Resultado inicial do PR: **17/17 PASS** (11 widget + 6 controller). A primeira execução funcional encontrou seis falhas
de teste por tentativa de tocar controles fora da viewport rolável de 600 px.
A correção limitou-se a `ensureVisible` nos testes. A segunda rodada focal passou
integralmente. Não foram repetidas suítes globais, API ou E2E históricos.

O processo remoto não fornecia `ProgramFiles(x86)`; a variável foi definida somente
no processo de teste como `C:\Program Files (x86)`, sem mudança persistente no host.

### Revisão focal do PR #23

Após o comentário `5964467939`, foram reproduzidas duas falhas sintéticas do estado
de preparação: retry após `prepare()` indisponível e edição liberando `canSend`
antes da prontidão. A correção ficou restrita ao controller, teste focal e este
registro. A prontidão agora pertence à geração/sessão corrente; conclusão tardia
de `prepare()` de A não pode liberar B.

Regressões versionadas acrescentadas ao teste de controller:

- retry de preparação preserva assunto, rascunho e contexto e não chama `send()`;
- edição durante preparação pendente mantém `loading` e `canSend=false`;
- `prepare()` tardio de A após troca A→B não libera B antes do prepare de B.

Validação após a correção:

- `flutter analyze lib\\features\\support\\support_controller.dart test\\support_controller_test.dart`: **PASS, 0 issues**;
- `flutter test test\\support_entry_test.dart test\\support_controller_test.dart`: **20/20 PASS** (11 widget + 9 controller).

Os testes existentes de resposta tardia de envio A→B, logout/retorno, toque duplo
e reutilização do `commandId` no retry de envio continuam dentro dos 20 testes e
passaram sem alteração de contrato. A pendência de validação visual permanece aberta.

## Demonstração local

Com Chrome já disponível:

```powershell
cd C:\Users\Usuario\tds-agents\cw-1\cartilhas_app
C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat run -d chrome -t tool\support_preview.dart
```

O bootstrap contém um guard que lança erro em `dart.vm.product`, impedindo seu uso
como release. O smoke local alcançou `Launching tool\support_preview.dart on Chrome
in debug mode` e `Waiting for connection from debug service on Chrome`, mas o
Chrome remoto não completou a conexão. Nenhum SDK, emulador ou pacote extra foi
instalado para contornar isso.

A ferramenta remota usada nesta sessão não expõe captura de tela. Portanto,
validação visual/captura permanece pendente. Os testes de semântica, foco por teclado,
rolagem estreita e escala de texto 2.0 não equivalem a TalkBack real testado.

## Limites preservados

- Nenhuma conexão com Chatwoot real, SDK real ou API de suporte.
- Nenhum backend, banco, migration, outbox persistente, telemetria real, notificação
  ou anexo.
- Nenhum `SIGNED_SUPPORT_IDENTITY` ou flag produtiva alterada/ativada.
- Nenhum dado, conta, credencial, `.env` ou cofre lido.

- Nenhum deploy, AAB, APK, instalação, merge, tag ou release.
- Nenhuma mudança em PR #21, workflows, certificados, backup, SMTP, WordPress,
  R2, Dokploy ou VPS.
- `ChatwootScreen`, serviços SDK/reset/serializador, `AppConfig` e autenticação
  real não foram modificados.
- CW-2 permanece necessário para identidade/transporte real e ciclo A→B no widget.
- CW-3 permanece necessário para inventário/competências/isolamento do Chatwoot.
- CW-6 permanece necessário para homologação instalada, restore e prova ponta a ponta.

PASS local significa somente comportamento do protótipo/testes. Não significa
instalação, mensagem entregue, atendimento humano ou aceite de produção.
