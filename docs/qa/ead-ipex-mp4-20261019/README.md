# Issue #286 — MP4 e VTT hospedados no IPEX no Tutor TDS

**Data:** 19/10/2026. Branch `agent/issue-286-ipex-mp4-player-20261019`,
base PR #284 HEAD `7112d098891aef357c47ab70707d0d5e8a686a47`.
**User approval:** usuário confirmou expressamente autorização de todas as videoaulas,
mas não autorizou alteração indiscriminada de produção ou Play.

## Descoberta no WordPress institucional (somente leitura)

Inventário WordPress/learnpress oficial em
`https://ead.ipexdesenvolvimento.cloud`:

| Curso | Lições publicadas | MP4 no corpo da aula | VTT pt-BR |
| --- | ---: | ---: | ---: |
| #614 | 17 | 12 | 12 |
| #1298 | 13 | 6 | 6 |
| #1307 | 9 | 4 | 4 |
| #1314 | 9 | 4 | 4 |
| #1321 | 10 | 5 | 5 |
| #1328 | 9 | 4 | 4 |
| #1335 | 11 | 5 | 5 |
| #1343 | 9 | 4 | 4 |
| #1356 | 8 | 4 | 4 |
| **Total** | **95** | **48** | **48** |

Todas as 48 referências MP4 das grades públicas seguem o padrão
`https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/...mp4`
e cada aula tem `<track kind="captions" ... .vtt srclang="pt-BR">`.
Este inventário comprova referências e estrutura; **não é inspeção byte a byte
dos 48 arquivos**. Um MP4 amostrado retornou HTTP **206 Partial Content**
com `Content-Type: video/mp4` e `Content-Range`. A VTT correspondente
retornou HTTP **200, text/vtt**.

Houve 55 referências MP4 no WordPress todo, mas **48** pertencem exatamente
aos nove cursos TDS do recorte. A quota de upload do YouTube **não bloqueia**
estes arquivos já publicados no IPEX.

## Mudança no contrato editorial

O plugin-base do PR #238 é importado nesta branch para possibilitar
integração/sandbox de ponta a ponta; preserva o controle do WordPress como
fonte do currículo, ordem, publicação de aula e respostas HTTP/ETag.

A resposta `media` de uma aula publicada e **explicitamente liberada**
por ambas as metas `_tds_mobile_public=1` e
`_tds_mobile_rights_approved=1` passa a aceitar:

- `provider=youtube, video_id` (existente);
- `provider=ipex_mp4, source_url=https://ead.ipexdesenvolvimento.cloud/
  wp-content/uploads/tutor-tds/...mp4`, com `captions_url=...vtt`
  quando a faixa pt-BR é encontrada no HTML original LearnPress.

URLs devem ser HTTPS, mesmo hostname institucional, sem userinfo,
porta, query, fragmento, traversal ou extensão indevida. O plugin
**não** transforma a presença de `<video>` em autorização: sem os dois
flags a resposta de mídia é `null`. Textos de aluno, notas,
certificados, uploads privados e quiz permanecem fora da projeção.

## Player Flutter

Nova tela EAD com `webview_flutter` já instalado; HTML construído
localmente com `<video controls playsinline preload="metadata">`,
fonte MP4 do IPEX, faixa `<track kind="captions" srclang="pt-BR">`
e fallback de abertura manual no navegador. Sem autoplay, download
de mídia, cookies/CPF/tokens da API, MediaItem, eventos acadêmicos,
progresso, presença, avaliação ou certificado. YouTube continua opção
para aulas que o LearnPress forneça com seu ID.

## Evidência / limites

- Teste de contrato PHP standalone: **43 verificações PASS**, incluindo
  liberação MP4 e VTT, negação sem direitos e negação de host externo.
- Testes Flutter focais: 5 novas verificações de URL, mídia, HTML5 e
  UI, mais 21 existentes de repositório/aula/YouTube — **PASS**.
- Flutter analyze focal: **0 problemas**, Dart/Flutter **3.44.9**.
- QA Android: build de pacote debug com `DYNAMIC_QA_ISOLATED_PACKAGE`
  e `TDS_EDITORIAL_QA_HTTP_BASE` direcionado a **fixture sintética local**
  com MP4/VTT já públicos; nenhuma escrita no WordPress.
- **Ainda necessário antes do release:** smoke Android WebView com arquivo
  IPEX de verdade, HTTP dos MP4/VTT, configuração das metas editoriais
  dos 48 cursos no ambiente institucional em rollout controlado,
  implantação do plugin em staging/produção sob gate, AAB assinado,
  smoke autenticado e QA acadêmica.
- O plugin no WordPress público **não** foi instalado nem
  suas metas editadas nesta tarefa; o retorno dos vídeos no aplicativo
  depende do novo contrato estar publicado.
- **MERGE_ALLOWED=NO; PRODUCTION_ALLOWED=NO;** nenhum deploy ou auto-merge.
