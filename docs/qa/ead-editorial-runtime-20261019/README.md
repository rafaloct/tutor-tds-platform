# Issue #290 — validação editorial MP4/VTT, 2026-10-19

## Estado e fronteiras

- **OBSERVED:** base `1de5e9e6f55c161e433cbf5882cb5e62a80eebc3` do PR #289; Docker Desktop local não respondeu (`dockerDesktopLinuxEngine` ausente). PHP portátil 8.4.26 e instalação descartável local do WordPress 7.1.2 com SQLite estavam disponíveis. Não foi encontrado LearnPress instalado ou arquivo local do plugin.
- **DECISION:** o fluxo editorial exige duas submissões para aprovar MP4/VTT; WordPress não concede direitos acadêmicos. Produção, VPS, dados reais, DNS, Play e publicação das 48 aulas ficam fora deste QA.
- **TARGET:** provar a integração do plugin com os hooks de salvamento e a API REST do WordPress/LearnPress sintético, além de resposta e política HTTP da origem IPEX.
- **TESTED-LOCAL:** clone descartável do WordPress real, banco SQLite sintético persistido, posts `lp_course` e `lp_lesson`, hook `save_post_lp_lesson`, rota REST do plugin e uma rota de currículo **simulada** com o formato LearnPress. O teste `test-wp-runtime.php` passou. O teste de contrato PHP com stubs passou `63/63`; lint dos quatro arquivos PHP do recorte e `git diff --check` passaram.
- **UNKNOWN/BLOCKED:** este ensaio não carregou o plugin LearnPress real. A rota `/learnpress/v1/courses/{id}` foi simulada, logo a compatibilidade com a versão LearnPress instalada no ambiente institucional não está comprovada. A URL IPEX HTTPS foi validada como string/origem de projeção; não se fez requisição à rede pública e não há prova nova de `Range` MP4 ou `Content-Type` VTT. A prova Android de áudio/legenda cabe ao #291. Nenhum TESTED-STAGING ou aceite de produção foi declarado.

## Resultado focal

| Cenário | Resultado local |
| --- | --- |
| Primeira submissão MP4 sem YouTube, segunda confirmação | Primeira `media: null`; segunda `ipex_mp4` com MP4 HTTPS e VTT `pt-BR` |
| REST autorizado | Aula e currículo 200; aula com ETag condicional 304 |
| Troca MP4/VTT | Primeira submissão revoga, segunda reaprova; ETag antigo retorna 200 |
| Alteração fora do metabox | Conteúdo editado diretamente, fingerprint divergente, `media: null` |
| Revogação | Direitos desmarcados dão `media: null`; opt-in público revogado dá REST 404 |
| Fontes inválidas | Host externo, HTTP, path fora de `tutor-tds`, traversal codificado e VTT de host externo bloqueados após duas submissões |
| YouTube legado | Troca de origem revoga; segunda confirmação reaprova ID de 11 caracteres |

O teste usa a origem sintética `https://ead.ipexdesenvolvimento.cloud` apenas na configuração e nos valores dos posts; o WordPress bloqueia chamadas HTTP externas. Os arquivos MP4/VTT são nomes fictícios, sem upload ou acesso à mídia.

## Reprodução e rollback

Em PowerShell, copiar uma instalação **descartável** do WordPress com SQLite para um diretório temporário novo, configurar `WP_HOME`/`WP_SITEURL` como a origem HTTPS IPEX e manter `WP_HTTP_BLOCK_EXTERNAL=true`. Usamos a instalação QA preexistente em `C:/Users/Usuario/.codex/tmp/wp2-real-20261003/wordpress`, copiada para `$env:TEMP/tds-agent290-wp-qa-20261019/wordpress`; o original permaneceu intacto. O script exige `TDS_WP_QA_ROOT` apontando ao clone e carrega o plugin diretamente do checkout.

```powershell
$php = 'C:/Users/Usuario/.codex/tmp/php-8.4.26-wp2/php.exe'
$ext = 'C:/Users/Usuario/.codex/tmp/php-8.4.26-wp2/ext'
$env:TDS_WP_QA_ROOT = Join-Path $env:TEMP 'tds-agent290-wp-qa-20261019/wordpress'
& $php -n -d "extension_dir=$ext" -d extension=pdo_sqlite -d extension=sqlite3 -d extension=openssl -d extension=mbstring docs/qa/ead-editorial-runtime-20261019/test-wp-runtime.php
& $php wordpress/tds-learnpress-editorial/tests/test-contract.php
& $php -l docs/qa/ead-editorial-runtime-20261019/test-wp-runtime.php
git diff --check
```

Saída final do runtime: `WP_CORE_RUNTIME_QA_PASS` e exit 0. Saída do stub: `PHP_EDITORIAL_CONTRACT_TESTS_PASS=63`. A limpeza/rollback consiste em remover somente o clone temporário `tds-agent290-wp-qa-20261019`, depois de conferir seu caminho absoluto; não há migração, deploy, flag ou alteração no WordPress institucional para reverter.

**Gate seguinte:** executar a mesma prova com LearnPress real em instalação sintética isolada e checar `Range`/`Content-Type` da mídia em ambiente autorizado; obter do #291 recibo Android de áudio e VTT. Instalação institucional ou aprovação editorial das 48 aulas exige HUMAN_GATE separado.
