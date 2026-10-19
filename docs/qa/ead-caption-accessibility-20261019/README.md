# Issue #294 — legendas acessíveis no MP4 IPEX

Data: 19/10/2026. Base exata: `91c5934eb071d8decc8d26e12eeb50e63bd72846`.
Branch exclusiva: `agent/issue-294-caption-accessibility-20261019`.
HEAD final do PR e SHA dos commits: registrados no handoff da Issue #294, pois o
SHA do commit que contém este arquivo não pode constar nele próprio.

## Estado e contrato

- **OBSERVED:** a captura Android 35 original `22s.png`, SHA-256
  `C6088C2B8BA8652C09B88C86B3420502FA2B96D3EA7F0C3EE155CAD46F90959C`,
  mostra legenda pt-BR sobre componentes da animação. A reprodução visual do
  candidato anterior foi registrada no PR #287; áudio e seleção manual de VTT
  não foram comprovados.
- **TARGET:** legenda em painel separado abaixo do elemento `<video>`, controle
  PT-BR de mostrar/ocultar e nenhum controle de legenda quando não há VTT.
- **DECISION:** preservar URLs públicas MP4/VTT, fluxo editorial, fallback YouTube,
  controles nativos de play/pause e abertura externa. Sem autoplay ou crédito
  acadêmico por visualização. Não tocar produção ou emulador reservado.
- **UNKNOWN:** renderização, leitura por tecnologia assistiva, áudio e seleção do
  controle no Android WebView do novo build; nenhuma captura desse build existe.

## Implementação e segurança

A tela gera somente HTML local. A política existente aceita MP4 e VTT apenas sob
`https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/`, sem
userinfo, porta, query, fragmento ou traversal; as URLs entram no HTML após
escape de atributo. O script estático local lê `textTracks`/`cuechange`, mantém
o modo `hidden` para impedir a sobreposição nativa e escreve texto de cues em
`textContent`, nunca `innerHTML` ou `eval`. O botão de 44 px tem nome visível,
`aria-pressed` e `aria-controls`; o painel usa `role=status`, `aria-live=polite`,
contraste claro/escuro e rolagem para cues longas. O vídeo preserva a proporção
16:9; o contêiner com VTT reserva altura adicional abaixo dele.

JavaScript só é habilitado quando a URL VTT validada existe. CSP limita script a
um nonce aleatório por carga, mídia ao host institucional e `connect-src` a
`none`; o caso sem VTT usa `script-src 'none'` e JavaScript desabilitado. A
NavigationDelegate aceita `about:blank`/base HTTPS apenas na carga inicial do
documento local e fecha navegação de página depois. Nenhum HTML remoto é
executado como script, e o script não lê cookies, não chama `fetch`, não envia
URL arbitrária nem dados acadêmicos. Nenhum cookie, token ou dado pessoal é
passado pelo código Flutter ao documento. O comportamento de cookies que a
WebView possa anexar automaticamente a requisições de mídia same-origin não foi
medido; requer inspeção de rede em QA isolado antes de alegar ausência absoluta
de cookies na camada do navegador.

Risco residual: suporte real do Android WebView a `textTracks`, evento
`cuechange`, CSP e comportamento de controle nativo só pode ser confirmado no
novo build. Se VTT falhar, o MP4 continua com controles e abertura externa;
legenda não será exibida. Este PR não promove prontidão de produção.

## Matriz focal, offline e QA

| Caso | Esperado | Evidência nesta fatia |
| --- | --- | --- |
| VTT presente | Painel fora do vídeo; botão PT-BR alterna legenda | HTML e widget TESTED-LOCAL; Android UNKNOWN |
| VTT ausente | Sem botão/faixa/script; MP4 com play/pause | 1 teste Dart PASS; Android UNKNOWN |
| URL maliciosa | Rejeição antes da WebView; atributos escapados | 2 testes Dart PASS |
| Play/progresso | Sem autoplay, callback acadêmico ou certificado | inspeção de fonte + teste Dart PASS |
| YouTube | Caminho editorial existente preservado | diff restrito à tela MP4/teste/docs; não retestado |
| Offline | Online-only; sem download, cache próprio ou fila; indisponibilidade mantém fallback externo manual | contrato de código; Android offline NOT_RUN |

QA Android pendente em build novo e ambiente não reservado: abrir aula MP4/VTT
autorizada, capturar cue longa sem cobertura da animação, alternar mostrar/ocultar
com TalkBack, confirmar foco e contraste, testar sem VTT, play/pause e abertura
externa, e verificar no tráfego se VTT/MP4 recebem cookies. Registrar SHA do
APK, screenshot e versão Android. Não inferir áudio nem VTT a partir de HTML ou
teste unitário. Não usar `emulator-5554` reservado ao PR #287.

## Testes e rollback

- `flutter pub get --offline` com SDK `D:\flutter-3.44.9` e
  `PUB_CACHE=D:\DevTools\pub-cache`: **PASS**.
- `flutter test --no-pub --concurrency=1 test/ead_ipex_mp4_player_test.dart`:
  **9/9 PASS**. A primeira execução teve 1 falha em asserção de seletor CSS;
  a verificação foi corrigida para o elemento `<button>` e a segunda passou.
- `flutter analyze --no-pub` nos dois arquivos Dart: **PASS**, 0 issues.
- Script local extraído e validado por `node --check -`: **PASS**.
- Android do novo build, áudio, seleção manual VTT, captura e tráfego: **NOT_RUN**.
- Suíte completa, AAB assinado, staging/produção: **NOT_RUN**.

Rollback: reverter o commit deste PR na branch de integração, restaurando o
HTML5 original e JavaScript desabilitado. URLs, MP4/VTT, dados, matrículas e
serviços não foram alterados. Gate humano: revisão do QA Android novo, da cadeia
stacked e da segurança de cookies antes de qualquer promoção.

Esta linha serve como atualização compacta de memória e matriz deste recorte;
os caminhos canônicos fora do escopo autorizado pela Issue #294 permanecem
inalterados.
