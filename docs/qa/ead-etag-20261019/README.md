# Issue #303 — retomada focal após STOP

Executor exclusivo: Devin Desktop / LARGeo.
Branch: `agent/issue-303-weak-etag-20261019`.
Worktree: `D:/AI-Shared/work/tds-issue303-weak-etag-20261019`.
Base: `f9260a6d118e7142b0c9ec7f11a14b09440c725a`.

OBSERVED: em 19/10/2026 local, GitHub confirmou PR #304 OPEN/draft nesse
HEAD, CI 3/3 SUCCESS. O comentário técnico mais recente da #303 foi lido:
<https://github.com/rafaloct/tutor-tds-platform/issues/303#issuecomment-6280785878>.
O recibo da base registra rollback concluído: plugin instalado/inativo,
rota editorial 404 e LearnPress nativo 200. Não é uma nova consulta produtiva.

DECISION: autorização direta nesta sessão para retomar somente ETag Flutter,
testes focais, novo APK QA e homologação Android isolada. A autorização anterior
de promoção não é reutilizada. Reativação produtiva exige aprovação específica
posterior ao STOP, com teste focal e rollback preparados.

TARGET: aceitar exclusivamente `"revision"` ou `W/"revision"` para a mesma
revisão lowercase hexadecimal/64 validada no JSON. Preservar o ETag recebido
literalmente para `If-None-Match`, o cache em memória por curso e toda validação
de autorização, origem/schema, mídia e fingerprint. Não há alteração de UI;
nenhum novo digest Stitch ou aceite visual é reivindicado.

Fronteira: cliente GET editorial; nenhuma mudança em LearnPress, PHP, banco,
fingerprint de direitos, assinatura de produção, versão Play ou flags release.
Dependência: cadeia #304; #297 permanece independente. #299 e #302 não são
reexecutadas. Risco focal: aceitar validador divergente ou reutilizar cache
não validado; testes negativos cobrem essa fronteira. Offline policy preservada:
falha de rede não concede conteúdo; 304 exige objeto previamente validado
do mesmo curso, sem cache persistente novo.

## Ambiente e testes

Os caminhos históricos `C:/Users/Usuario/...` não existem neste host.
SDK explicitamente verificado: `D:/flutter-3.44.9`, framework `6b182d2c75`,
Flutter 3.44.9 / Dart 3.12.2. Worktree exclusiva em caminho ASCII.
O SDK não foi inferido do PATH. Android SDK: `D:/DevTools/AndroidSDK`.
Dependências resolvidas offline, sem mudança do lockfile.

TESTED-LOCAL: 40/40 testes do repository/fixtures e 5/5 testes focais MP4
passaram; analyze dos três arquivos Dart alterados passou sem achados.
Cobertura: forte/fraco 200/304, envio literal de If-None-Match,
divergente/ausente/malformado, schema/origem/curso/revisão inválidos,
304 sem cache e de outro curso, transições forte/fraco com novo conteúdo,
conteúdo não autorizado, 404 sem permissão, 401/403 e HTTP real gzip/identity.
Teste Android usa a tela existente, repository e transporte padrão, com
servidor HTTP sintético no loopback e ponte privada QA existente.
Isso não comprova WordPress vivo, mídia produtiva, áudio ou TalkBack.

## Rollback preparado — execução depende do gate

Estado a preservar: adaptador 0.1.0 instalado e **inativo**. Após autorização
específica, primeiro conferir estado/hashes e disponibilidade do backup
`/opt/tds-institutional-backups/20261020T003715Z` conforme PR #304.
Se a rodada autorizada falhar, desativar somente o adaptador pela operação
nativa WP-CLI: `wp plugin deactivate tds-learnpress-editorial --allow-root`,
no container `compose-program-open-source-monitor-szkpni-wordpress-1`,
diretório `/var/www/html` (usar o binário WP-CLI conferido no ambiente).
Confirmar plugin inativo, rota editorial 404 e rota LearnPress nativa 200.
Manter arquivos do plugin e patch #299; não restaurar banco inteiro,
alterar LearnPress, direitos, permissões ou registros acadêmicos.
Rollback do cliente QA: encerrar/remover apenas o pacote exclusivo desta rodada;
preservar APKs anteriores e aplicativos DEV/Play existentes.

UNKNOWN/BLOCKED: resultados e hashes dos novos artefatos serão registrados após
execução. Gate produtivo, Xiaomi/áudio/TalkBack, aliases institucionais,
direitos por aula, #297, declarações legais, certificado/versionCode Play,
merge, assinatura e publicação continuam separados.
