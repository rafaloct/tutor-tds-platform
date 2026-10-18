# Issue #245 — reprodução editorial YouTube no app (candidato local)

TASK_ID=CODEX-L4-VIDEO-20261018
BASE_SHA=1ba43abb4c89a35ca4f37beb0dcafaa5967f1d05
Branch: agent/issue-245-codex-l4-youtube-20261018
MERGE_ALLOWED=NO; PRODUCTION_ALLOWED=NO

OBSERVED: base e branch conferidos; botão da aula abria YouTube externo.
Issue245 e descrições PR217/238/240/242/244 lidas via GitHub API read-only.
O embed FastAPI usa MediaItem, tracker, progresso e rating; seu delegate
aceita qualquer subframe. Reutilizá-lo aqui ampliaria o acoplamento e a
superfície permitida. DECISION: opção B autorizada na missão, componente EAD
isolado, sem alterar media nem dependências. Tema/Poppins são herdados do app.
Digest Stitch local consultado (9731628404551462355) refere-se à Home;
não é referência de player nem prova visual desta implementação.

IMPLEMENTED: botão existente abre rota interna com curso/aula, Voltar,
viewport 16:9 e endpoint HTTPS youtube-nocookie/embed para reprodução manual
(autoplay=0, playsinline=1, cc_load_policy=1, rel=0). Usa o documento embed
diretamente no WebView, sem HTML editorial executável e sem canal JavaScript.
Apenas o youtubeId recebido da consulta lesson autorizada habilita o botão;
ID é revalidado na UI e no player, inclusive tamanho exato para recusar newline.
Sem MediaItem sintético, watch time, fila, armazenamento de progresso,
eventos de play/conclusão, rating, quiz, presença, nota ou certificado.

Proteções: navegações de main frame e subframes passam pela mesma política:
HTTPS, host exato www.youtube-nocookie.com, path /embed/{ID autorizado}, query
canônica; sem userinfo, porta explícita ou fragmento. Esquemas javascript/file/
data/intent, outros vídeos, páginas watch, domínios/subdomínios arbitrários e
redirects com parâmetros extras são bloqueados. Isso controla navegação,
não intercepta todos os subrecursos de rede carregados pelo próprio YouTube.
Não são enviados cookies/tokens da API ou dados pessoais pelo código EAD.
O WebView pode manter dados próprios do provedor; não promete reprodução offline.

Referer HTTPS identifica o pacote Android, incluindo suffix debug/QA já definido
pelo Gradle (sem mudar configuração). Fonte técnica consultada:
[YouTube — Client identity / WebView](https://developers.google.com/youtube/terms/required-minimum-functionality#api-client-identity-and-credentials).
Não usa origem fictícia como autorização. Loader fica fora do player.

Offline/falha: erro da plataforma, inicialização indisponível ou timeout de 20s
até carregar o documento mostra aviso em pt-BR. Não há download/cache/fila EAD
novos nem reprodução offline. Sem rede na consulta lesson, bloqueio existente
é preservado. Revogação é reconsultada ao abrir/atualizar aula; não há polling
nem revogação instantânea de uma sessão de player já aberta.
"Abrir no YouTube" é sempre manual e usa URL oficial construída do mesmo ID.
Falha de launch exibe SnackBar. Voltar preserva a aula na pilha.

UNKNOWN: onPageFinished comprova documento carregado, não vídeo reproduzido.
Erro interno do YouTube (direitos, embedding desabilitado, região, identificação)
pode aparecer apenas dentro do player e não disparar erro WebView; CTA externo
permanece disponível. Não promete trilhas/legendas inexistentes nem inventa VTT.
Validação de áudio, controles, fullscreen, TalkBack/teclado e Referer do pacote
QA precisa de dispositivo. Não há captura nova ou evidência de play nesta VM.

## Memória compacta / matriz focal

| Contrato | Implementação / teste focal escrito | Evidência atual |
| --- | --- | --- |
| Autorização editorial lesson; sem vídeo não há player | ead_mobile_lesson_screen + testes null/inválido/403 | IMPLEMENTED, Flutter NOT_RUN |
| ID/URL/allowlist exatos para todas as navegações | EadYoutubePolicy + testes negativos | IMPLEMENTED, Flutter NOT_RUN |
| Navegação interna/Voltar/contexto/fallback manual | testes widget com fábrica sem plataforma | IMPLEMENTED, Flutter NOT_RUN |
| Loader/ready/falha/launch recusado/temas claro e escuro | ead_youtube_player_screen_test | IMPLEMENTED, Flutter NOT_RUN |
| Sem acoplamento acadêmico/API media | imports revisados + guard estrutural | Inspeção de fonte; execução Flutter NOT_RUN |
| Player Android real/legendas/ausência de autoplay | roteiro abaixo | UNKNOWN, desktop gate |

## QA executada e gate humano

TESTS_FLUTTER=NOT_RUN. `command -v flutter` e `command -v dart`: ausentes.
`flutter analyze`, `flutter test` e `dart format`: NOT_RUN; nenhum widget PASS.
`git diff --check`: PASS (whitespace apenas). Sem instalar SDK ou executar ADB.

Reason: SDK Flutter 3.44.9 validado está no desktop, não nesta VM.
Exact human action: coordenador aplica este commit num checkout desktop isolado,
usa o junction ASCII/SDK indicado no AGENTS.md e executa, em cartilhas_app:

```text
dart format lib/features/ead_catalog/learning_path/ead_youtube_player_screen.dart lib/features/ead_catalog/learning_path/ead_mobile_lesson_screen.dart test/ead_youtube_player_screen_test.dart test/ead_mobile_lesson_screen_test.dart
flutter analyze --no-pub lib/features/ead_catalog/learning_path test/ead_youtube_player_screen_test.dart test/ead_mobile_lesson_screen_test.dart
flutter test --no-pub test/ead_youtube_player_screen_test.dart test/ead_mobile_lesson_screen_test.dart test/ead_editorial_bridge_repository_test.dart test/ead_mobile_lesson_golden_test.dart test/ead_learning_path_screen_test.dart
```

Depois compila APK QA isolado conforme EAD_PRIVATE_ANDROID_E2E_241.md; abre
lesson opt-in da fixture autorizada, clica Assistir e verifica player no próprio
app, sem autoplay; inicia play manual e captura vídeo/áudio/controles reais.
Confere Voltar → mesmo texto/curso; claro/escuro, 360/390/450px, escala 1,5,
TalkBack e teclado; legendas só quando disponíveis. Testa modo avião após
abertura e vídeo sem permissão de embed; CTA manual oficial e falha do launcher.
Confere links do player bloqueados sem saída automática; aula sem vídeo/revogada
não oferece CTA após atualizar. Confere nenhum request de mídia/evento FastAPI
relacionado ao play. Registra SHA/APK/pacote/AVD/prints e resultados reais.
Não alterar WP público nem ampliar opt-in para obter evidência.

What remains unblocked: revisão de código e transferência do commit local.
Merge/produção seguem proibidos. Rollback: reverter este commit, retomando
abertura externa anterior, sem dados a migrar.
