# Issue #282 • Fallback público de lições EAD no Flutter

**Escopo:** alteração incremental na tela `EadLearningPathScreen`, empilhada sobre o PR #246 (que já inclui os PRs #244, #242 e #240). Nenhuma alteração de backend, WordPress, identidade, matrícula, quiz, progresso, certificado ou Tutor/RAG.

## Contexto observado

O app consome a grade pública LearnPress pelo adaptador do PR #238, mantendo `mobileContent=false` por padrão até o instrutor liberar explicitamente o texto para o app. A versão anterior deixava `ListTile.onTap=null` para todas essas lições; a pessoa via o título mas não tinha um caminho acionável para continuar o curso.

## Mudança

- Lição `lp_lesson` com `mobileContent=true`: continua abrindo a visualização interna `EadMobileLessonScreen`, sujeita ao HTTP 200 do adaptador e suas próprias verificações de autorização.
- Lição `lp_lesson` sem opt-in: abre apenas **a URL HTTPS canônica do curso publicado**, `https://ead.ipexdesenvolvimento.cloud/courses/{slug}/`, já validada pelo catálogo público. O subtítulo informa que a leitura no app não foi liberada; ícone de link externo identifica a saída.
- Item `lp_quiz`: mantém o contrato anterior de verificar publicação/canonical URL no LearnPress antes de abrir, sem importar questões/nota.
- Nunca fabrica URL direta de aula, permissões, progresso, inscrição, certificado, vídeo, SSO ou ID de CourseVersion. Não envia CPF, token ou cookies ao atalho.

## Testes de aceitação

`cartilhas_app/test/ead_unreleased_lesson_fallback_test.dart`:

1. Título de lição não liberada chama exclusivamente `openCourse` com host EAD esperado e esquema HTTPS; a tela interna nunca é aberta e o loader da aula privada não é chamado.
2. Lição explicitamente liberada navega à tela interna com loader injetado e conteúdo autorizado; não aciona o link externo.

Regressões: `ead_learning_path_screen_test.dart`, `ead_learning_path_golden_test.dart`, `ead_youtube_player_screen_test.dart`, `ead_mobile_lesson_screen_test.dart`.

**OBSERVED no DESKTOP-8T5DRBS (Flutter 3.44.9):** dois novos testes PASS;
`flutter analyze --no-pub` nos dois arquivos alterados: **0 issues**;
regressão conjunta dos cinco arquivos: **67/67 PASS**. O golden sintético
mudou intencionalmente com o subtítulo de ação e o ícone externo (10,36%
de pixels de diferença); imagens antiga/nova foram revisadas, golden
atualizado e novamente aprovado. O diff inicial foi preservado em
`C:\AI-Shared\evidence\tds-issue282-golden-diff-20261018`.
Um golden não é um screenshot capturado no Android.

## Fontes compartilhadas e limites

As referências LearnPress fornecidas sobre add-ons, webhooks e HMAC são úteis para planejamento de integrações autenticadas futuras, mas **nenhum webhook foi instalado/ativado**, pois a verificação de identidade e a autorização institucional ainda exigem backend auditado. As referências Flutter sobre métodos internos do embedder e inicialização do primeiro frame não justificam alterar código nativo de baixo nível para este fallback; o componente Material e seus testes de widget bastam.

**Produção/Play preservados**; alterações apenas em branch isolada, sem merge ou deploy. A aprovação acadêmica do material e direitos das 48 videoaulas continua necessária.
