# Ensaio limitado do cliente Drupal contra staging

## Escopo e guardas

Candidato `scripts/probe-staging-participant.php`: CLI usa `TutorApiClient` e
`TutorSessionManager` reais, Guzzle TLS verificado e redirects desativados.
Store somente em memória e lifecycle falso: **não comprova sessão/cookie Drupal,
CSRF, interface, mutex ou E2E browser**. Gate `PASS_SAMPLED_HTTP` e scope
`staging_client_http_only` significam somente transporte/JSON aceito pelo cliente,
**não compatibilidade da projeção do dashboard**. Nenhuma chamada operacional ou escrita
acadêmica. Login cria sessão upstream; refresh opcional rotaciona credenciais.
Limpeza ao terminar é apenas local, sem alegar revogação do refresh na API.

Execução exige simultaneamente:

- `TDS_STAGING_QA=1`;
- `TDS_STAGING_PROBE_URL=https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`
  com igualdade exata (sem barra final, query, porta alternativa ou userinfo);
- `TDS_STAGING_PROBE_CREDENTIALS=stdin`, preferencial: JSON privado com somente
  `cpf` e `password`, pipe/redirecionamento protegido, máximo8192 bytes; recusa TTY.
  Alternativa explícita `env`: `TDS_STAGING_PROBE_CPF`/`TDS_STAGING_PROBE_PASSWORD`.
  Nunca passar credenciais em argv, terminal com echo ou comandos versionados;
- `TDS_STAGING_PROBE_REFRESH=1` somente para incluir rotação explícita; ausente/0
  não força refresh. O manager mantém seu comportamento normal de refresh em401.

O coordenador fornece o JSON pelo canal privado, sem copiar o arquivo de seed
para a árvore Git. Executar `php scripts/probe-staging-participant.php` com as
variáveis acima e stdin privado. Não executar com settings/credenciais produtivos.

Fluxo: login→`/auth/me`→`/classes?enrolled_only=true`→learning-context/course de
**até5 turmas retornadas**→certificates; refresh opcional→auth/me. Limite é
amostragem, não cobertura completa. O refresh opcional também compara internamente
a identidade retornada com a do login, sem emitir identificadores. IDs permanecem somente em memória e URLs
internas da chamada; nunca saem no resultado. Saída JSON contém enums de etapa,
status normalizado pelo cliente, contagens e gate. Contagem `null` significa
não obtida; zero indica apenas a lista recebida naquela resposta, não ausência
de turmas/matrículas no sistema. Contexto404 produz `BLOCKED_CONTEXT`, gate
final`BLOCKED` e exit2. Sem turma amostrada, cobertura de contexto também bloqueia.
Erros não imprimem mensagem, trace, corpo, token, CPF, senha ou identidade.

`php scripts/probe-staging-participant.php --self-test` valida guardas sem
carregar dependências, sem ler credenciais reais e sem rede. Validação local: sintaxe PHP PASS e20 checks de guardas PASS, zero chamadas de
rede. Runtime real do cliente Guzzle ainda pendente de execução pelo coordenador.

## Evidência anterior e bloqueio observado — 15/10/2026

OBSERVED pelo coordenador em staging: ambiente staging, learning_context=false,
operations=true. Arquivo de seed privado0600; seu conteúdo não é parte do recibo.
Prova backend por loopback com conta QA: login/me200,3 turmas retornadas,
3 course200,3 learning-context404, certificates200 com lista vazia. O contrato
de contexto está BLOCKED; não inferir falta de turmas ou sucesso acadêmico completo.

HTTPS público: urllib recebeu403; curl recebeu200 com TLS válido e origem direta
respondeu200. Há diferença de transporte/cliente na borda, não prova de rota
universalmente indisponível. O harness medirá especificamente Guzzle real.
Nenhuma flag ou dado foi alterado para contornar bloqueios. Produção permanece
com sessões acadêmicas desabilitadas; API/Worker/Chatwoot reais e aceite#170
não são aprovados por este ensaio limitado.

## Recibo real do cliente — 15/10/2026

`9e799c9` via Guzzle/HTTPS público: primeira execução autenticou, listou3 turmas,
leu3 cursos e certificates com lista vazia, renovou refresh;3 learning-context404
mantiveram `BLOCKED`/exit2. O coordenador comprovou separadamente3 contextos200
via ASGI em memória com flag habilitada contra o banco de staging.

Depois, o coordenador habilitou somente learning_context de staging, persistiu
`.env`, fixou a imagem existente `6e3cd5f31bb4` e reiniciou somente a API staging,
com backup privado. IDs dos serviços protegidos permaneceram iguais; portal e
API produtivos responderam HTTPS200/TLS válido. Nenhuma alteração de banco ou
flag produtiva nesta ação.

Segunda execução do mesmo harness: **`PASS_SAMPLED_HTTP`, exit0,11 etapas200**:
login/me, listagem com3 turmas,3 contextos,3 cursos, certificates com0 retornados
e refresh. Esta é prova do cliente HTTP real com amostragem, não projeção do
dashboard, cookie Drupal ou browser E2E.

## Candidato de prova browser com API real

`scripts/test-staging-browser-login.cjs` usa somente `http://127.0.0.1:18872`,
entrada local do túnel SSH para uma fixture Drupal descartável apontando à API
staging. Exige `TDS_STAGING_BROWSER_QA=1` e JSON privado `cpf`/`password` no stdin
(não TTY, máximo8192 bytes); não aceita argumentos de credenciais nem env secrets.
Requests browser para outras origens são bloqueadas, service workers desativados
e a origem final é conferida antes de preencher credenciais. Requests HTTP do
teste não seguem redirects. O coordenador deve comprovar o túnel e a configuração
da fixture/API staging antes da execução; o script não atesta essa configuração.
Runtime: `TDS_STAGING_PLAYWRIGHT_MODULE` aponta ao módulo Playwright instalado
(ou usa `require('playwright')`); `TDS_STAGING_CHROMIUM_PATH` é o executável
opcional, sem download automático.

Fluxo preparado: navegador vazio→bootstrap anônimo→login UI→turmas/progresso
visíveis→contexto200/uidCMS0→cookie antigo401→logout UI→cookie revogado401→voltar
e atualizar sem contexto. Não imprime HTML, nomes, IDs, tokens, credenciais,
URL de classes ou screenshots. Saída somente enums/contagens e código de rede
allowlisted em falha. Guardas locais negativas3 PASS e sintaxe Node PASS, sem
rede. Runtime browser real ainda UNKNOWN; produção permanece com gate desligado.
