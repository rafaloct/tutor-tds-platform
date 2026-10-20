# Promoção institucional autorizada — 19/10/2026 local

Base e runtime PHP promovido: `16a57e66303e2b7bea2aef9d179976283c4e933f` (PR302).
Branch: `agent/issue-197-institutional-promotion-20261019`, worktree exclusiva LARGeo.
PRs296/298/300/301/302 continuam draft, nos HEADs informados, CI3/3 PASS em cada.
Nenhum merge/force-push/auto-merge. Autorização desta rodada inclui implantação,
contas institucionais, publicação individual comprovada e assinatura/Play após gates.
Não converte essas decisões em evidência de aceite.

## Estado final efetivo

| Gate | Estado | Evidência/limite |
|---|---|---|
| Backup produtivo real | PASS | Banco, filesystem completo, uploads, tema, plugins, config e compose protegidos |
| Restore de arquivos | PASS | Extração e comparação tar dos bytes, sem WordPress ativo |
| Restore banco | PASS com ressalva explícita | 73 tabelas; INSERTs idênticos; 14 diferenças de escrita de charset, não igualdade bruta |
| Patch299 institucional | PASS implantação/GET | Dois arquivos + helper; preservada credencial original, tema2.0.0 e política de cadastro |
| Cadastro/login/matrícula POST produtivo | UNKNOWN | HTTP32/32 histórico sintético preservado; nenhuma conta fictícia criada em produção |
| Adaptador0.1.0 | BLOCKED/rollback | Instalado exato, ativado, HTTP42/42; depois desativado por incompatibilidade Android303 |
| REST nove currículos | PASS durante ativação | 9×200 e 9×304; estado final namespace desativado,404 |
| Privacidade projeção | PASS no recorte | Campos proibidos ausentes; aula sem opt-in404 em cada curso; users/me401 |
| Arquivos de mídia | PASS disponibilidade | 48MP4+48VTT,96HEAD200, hashes de cópia restaurada |
| Direitos/publicação individual | HUMAN_GATE | Nenhuma comprovação individual localizada; zero autorizações adicionadas |
| Android catálogo | PASS | APK histórico abre visitante e catálogo11; captura real desta rodada |
| Android percurso editorial | FAIL/BLOCKED | Duas falhas, STOP; ETag comprimido fraco rejeitado pelo cliente |
| MP4/VTT produtivo ponta a ponta | BLOCKED | Sem conteúdo autorizado; não reutilizar QA anterior como prova produtiva |
| Nove tutores/autoria | HUMAN_GATE | Títulos/pais auditados; faltam nove e-mails/aliases controlados; zero contas criadas |
| #297 | BLOCKED independente | Sem bypass, vendor/core, permissões globais ou nova tentativa |
| Chave upload local | PASS | Cópias Desktop/LARGeo idênticas; keytool coincide com PEM |
| Certificado e versionCode atuais Play | UNKNOWN | Nenhuma sessão Play controlável verificada; maior código não inferido |
| Xiaomi/áudio/TalkBack | HUMAN_GATE | ADB LARGeo só emulador; Desktop nenhum aparelho; audibilidade não inferida |
| Declarações Play/Famílias | HUMAN_GATE | Aprovação e adequação específicas pendentes; não declarar ausência de coleta |
| AAB assinado/teste interno/rollout | BLOCKED | Não gerados/enviados nesta rodada; nenhum novo build Flutter |

## Backup e integridade

Host confirmado via Hostinger: VPS1533541 `srv1533541`, Dokploy0.29.1,
WordPress6.7.2, LearnPress4.3.6. Fonte efetiva do tema:
`/etc/dokploy/compose/compose-program-open-source-monitor-szkpni/code/tds-child-theme`.
WordPress: `compose-program-open-source-monitor-szkpni-wordpress-1`;
MySQL: `compose-program-open-source-monitor-szkpni-mysql-1`.
Uploads em volume separado; restante WP em volume Docker; tema e MU institucional em binds.

Backup recuperável restrito root700/umask077 no VPS:
`/opt/tds-institutional-backups/20261020T003715Z`.
Contém dados reais/segredos: não copiar para Git, chat ou área compartilhada.
Esta rodada comprova restore local, não cópia offsite deste novo backup.

| Arquivo | SHA256 |
|---|---|
| wordpress.sql | d18078c5b646bd592dded73fcbaf4b1c742e7f9e42b32c8ec44a23dc104374ab |
| wordpress-files.tar.gz | 014b8368d50abeb7a23ef92f7b62dfb235ac1f49fc0b7ca5cb430ddae5a9c8db |
| dokploy-compose.private.tar.gz | d245316fa93e8e14a400b07cb02f8068f888ece79b233fadef4fb2e426aaa170 |

Primeiro restore MySQL falhou: mysqladmin ping indicou prontidão antes da
autenticação disponível. Cópia descartável removida. Segunda execução exigiu
SELECT1 autenticado e restaurou o banco, mas cmp bruto recusou14 linhas.
Investigação somente leitura comprovou exclusivamente a explicitação
CHARACTER SET utf8mb4 em colunas que já tinham COLLATE utf8mb4_unicode_520_ci;
information_schema.COLLATIONS confirmou a associação. Nenhum INSERT difere.
Os dois dumps foram preservados, sem normalização ou aceite silencioso de hash.
Ver [restore-equivalence.json](restore-equivalence.json). Não houve terceiro restore.
Isso não resolve as divergências sintéticas históricas4dc→1ffe/M1.

Drills: MySQL mesma imagem da produção, network=none, sem portas, tmpfs;
nenhum runtime WordPress/cron/e-mail sobre cópia produtiva. Containers removidos.
Cópias de restore e logs privados permanecem protegidos para recuperação.
Depois de implantação/rollback, somente wp_options mudou entre dumps;
29 blocos de tabelas não vazias idênticos. Não declarar site vivo imutável.
[data-integrity.json](data-integrity.json). IDs/imagens/StartedAt de WP/MySQL/Traefik
iguais antes/depois. Nenhuma alteração de Traefik, redes ou outros serviços.

## Promoção mínima e rollback

Pacote extraído de Git com core.autocrlf=false; primeira preparação foi barrada
pelo hash porque git archive herdou CRLF do Windows, antes de escrita produtiva.
Os três blobs finais correspondem exatamente aos pins em runtime-hashes.json.
O patch gerado contra tema real corresponde ao diff aprovado SHA256a7d67bb7…;
PHP lint passou na mesma imagem, networknone. Nenhum tema WP-2/snapshot legado,
MU de QA, fixture, usuário sintético ou token sanitizado foi implantado.

[promotion.json](promotion.json) descreve o instante de ativação, não o estado final.
Plugin0.1.0 está **instalado e inativo** após rollback, arquivos exatos preservados.
Desativação nativa WP-CLI concluída; rota editorial404 e nativa200 confirmadas.
Não reativar antes de tratar303 e obter nova rodada após STOP.

Patch299 continua ativo:
- functions.php: b81056a9f50c2fb5f9ef418024e39790f3ef074508e58bf54bec8e03db3c1409
- pages/cadastro.php: 3908ec22f9517d6e59178decaa979a6692090d04579be9204621738ee8231142
- includes/tds-registration-course.php: 7a689746226916f7f9eb82522b4b5914ee3bc70a6309f1418b02e75b76664176

Rollback específico do patch: conferir hashes atuais; restaurar atomicamente
functions.php e pages/cadastro.php de `promotion-rollback/` no backup; remover
somente helper novo após verificar seu hash e ausência de consumidores restantes.
Nunca restaurar o banco inteiro para desfazer esse patch: preserva cadastros
e matrículas legítimos posteriores. Os originais estão também no tar restaurado.

## Android STOP303

APK existente b05eaa0, versão1.4.0-dev/code13, SHA256
F5BD7623521E7ACC115E68994F55497862DC78BE9525A3BDFD20E789F4C5596A.
LARGeo: `D:\AI-Shared\builds\tutor-tds\pr295-b05eaa058fb4b0c86c5569215652b893c55b517d\tutor-tds-pr295-b05eaa0-qa-debug.apk`.
Emulator5554 API35; pacote isolado `.dev.dynamicqa.rb05eaa058fb4b0c86c5569215652b893`.
Cold launch→visitante→catálogo11 PASS. Banner de laboratório pertence a esse APK
debug histórico e não indica conteúdo fictício instalado no portal.
Percurso1298 falhou e retry falhou; não houve terceiro ensaio Android.
Capturas/XML em `android/`. Logcat focal não forneceu stack útil.

GET institucional com Accept-Encoding:gzip e UA Dart recebe200, gzip,
ETag `W/"8de662b34322bba5c3831b61f613a0365816d6ed6d5c74eaa22617ddb0f102a9"`.
Sem compressão, ETag forte. `EadEditorialBridgeRepository.fetch` exige exatamente
`"revision"`, rejeitando W/. É uma incompatibilidade objetiva, mas atribuição
exclusiva da transformação ao Cloudflare versus Apache permanece UNKNOWN.
Nenhum patch Flutter ou cache/header foi aplicado após STOP.
Issue [303](https://github.com/rafaloct/tutor-tds-platform/issues/303) concentra
teste strong/weak/mismatch/missing, compressão e nova homologação necessária.
Não mascarar essa falha com fallback como integração concluída.

## Cursos e tutores

95 itens lp_lesson,48 títulos AulaNN,48MP4 e48VTT. Nenhum item compartilhado entre
cursos foi retornado pela varredura global de todos os pais;95 autores de aula=1.
Matriz integral com URLs, hashes e estado individual: [media-checked.json](media-checked.json).
HEAD200 e WEBVTT não comprovam direitos nem playback individual.

| ID | Curso real | Aulas | Autor atual | Tutor/credencial |
|---|---|---:|---:|---|
|614|Inteligência Artificial e Inclusão Digital|17|0|Não criado; alias pendente|
|1298|Agricultura Sustentável|13|1|Não criado; alias pendente|
|1307|Atendimento ao Cliente|9|1|Não criado; alias pendente|
|1314|Audiovisual para o Dia a Dia|9|1|Não criado; alias pendente|
|1321|Cooperativismo e Crédito|10|1|Não criado; alias pendente|
|1328|Economia do Lar|9|1|Não criado; alias pendente|
|1335|Educação Financeira|11|1|Não criado; alias pendente|
|1343|Inspeção e Certificação (SIM/SIMA)|9|1|Não criado; alias pendente|
|1356|Sistemas Agroflorestais (SAF)|8|1|Não criado; alias pendente|

Papel alvo lp_teacher, sem edit_others_* adicionais. Nenhuma autoria alterada.
Não inventados aliases, logins existentes ou referência de segredo inexistente.
Dokploy mostrou apenas docker secret de Postgres; consulta de metadados não
encontrou tabela de secret provider. Provider integrado continua UNKNOWN,
não equivale a prova de inexistência. Sem contas, não foi criado cofre paralelo.

## Play, fonte e gates humanos mínimos

Keystores Desktop e LARGeo têm mesmos2253bytes/SHA256
7B1B1A489EA42DEA50F9ACCD144BF2A5056C3806449CC8799CB8B0F18DCF2719.
keytool no LARGeo usou senha custodiada por variável efêmera e a removeu;
certificado SHA25616:44:39:F5:EF:57:F6:E9:C7:B8:58:A3:4F:59:2C:26:1D:CC:EC:AD:B3:B3:59:98:F0:7C:40:1F:6C:34:3F:50
coincide com PEM Git. Nenhum segredo/chave copiado para Git ou relatório.
Não prova comparação com Play atual. Interface conectada não expôs Play/browser;
HTTP localhost9222 do Chrome não ofereceu CDP/json. Não contornar sessão/permissões.
Não identificado maior versionCode; não escolhido código nem executado build.

API produtiva health200/databaseavailable; version200/schema0030/compatibilitytrue.
Não é novo teste completo API. Flutter e APK/AAB anteriores não foram reconstruídos.
AAB antigo unsigned/NOT_FOR_UPLOAD permanece inalterado; não há AAB oficial novo.

Próximas ações mínimas:
1. Autorizar nova rodada focal303 após STOP, preservando validação de revisão;
   se Flutter mudar, testes e novo APK antes de build oficial.
2. Fornecer nove aliases institucionais realmente controlados e registro de direitos
   individual. Continuar demais cursos sem inventar aprovação dos pendentes.
3. Disponibilizar Play Console controlável/inventário de trilhas/certificado e Xiaomi;
   confirmar áudio/TalkBack no ensaio, não apenas via logs.
4. Aprovar declarações corretas de dados/público-alvo. Público amplo não equivale
   a conformidade infantil; não restringimos idades silenciosamente.

O inventário `PLAY_CONSOLE_HUMAN_REVIEW_1.4.0+13.md` demonstra coleta opcional:
cadastro/autenticação, IA/voz, suporte e atividade. Não submeter declaração “não coleta”.
Retenção/contratos e controles para crianças não comprovados. Requisitos oficiais:
[público-alvo](https://support.google.com/googleplay/android-developer/answer/9867159),
[Famílias](https://support.google.com/googleplay/android-developer/answer/9893335).
As respostas legais finais e a conformidade dos provedores precisam do responsável;
nenhum checkbox ou aceite legal foi preenchido nesta rodada.

## Recursos e limites

`/status` executado:11% semanal restante,reset24/10 17:48; aviso posterior<10%.
Sem agentes concorrentes adicionais, nova VM/GPU, compra ou build intermediário.
Custo incremental financeiro não medido. Não há estimativa confiável de horas
até Play sem os gates acima. Histórico32/32 e30/30 não foi repetido nem somado
aos42 checkpoints produtivos e96 verificações de disponibilidade desta rodada.
