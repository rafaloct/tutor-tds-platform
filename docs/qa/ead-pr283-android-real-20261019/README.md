# PR #283 — QA Android real do fallback para conteúdo do EAD

**Data:** 19/10/2026 (Palmas). **Classificação:** OBSERVED / TESTED-EMULATOR, Android 35.
**Base da branch:** `189cc9e4966da805098a0ddcb4db4ca339dcfae2` (PR #283, draft).
**Escopo:** conferir curso público institucional e comportamento de lição
sem autorização de leitura móvel; **não** testar dados privados de aluno.

## Identidade e ambiente reais

- **LARGeo**, AVD **Pixel_8_Pro**, Android **API 35**, GPU host/WHPX,
  `emulator-5554`, emulador descartável read-only.
- APK debug QA isolado, **não** Play:
  `com.tutortds_cartilhas.dev.dynamicqa.r189cc9e4966da805098a0ddcb4db4ca3`;
  versão `1.4.0-dev` / code 13, compila API 36, executa na API 35.
- APK reaproveitado sem build:
  `TutorTDS-EAD-Fallback-Android35-QA.apk` (90.571.112 bytes),
  SHA256 `D3FFAB0221D21ACDC465663DA46E277D6A0BE9A6D67B2CD646224B07699AFDB9`.
  Transferido no Tailscale do desktop para LARGeo via servidor privado
  temporário com allowlist e hash verificado; servidor de transferência
  desligado após uso.
- `flutter test` focal (DESKTOP-8T5DRBS, Flutter 3.47.6/Dart 3.13.5):
  `test/ead_unreleased_lesson_fallback_test.dart`,
  `test/ead_mobile_lesson_screen_test.dart`,
  `test/ead_youtube_player_screen_test.dart` — **15/15 PASS**.
  A primeira tentativa com Dart 3.10 foi inválida e não indica falha
  do aplicativo; checkout limpo após teste.

## Jornada Android verificada

| Etapa | Resultado | Evidência |
| --- | --- | --- |
| App QA abriu sem substituir Play | PASS | `01-welcome.png` |
| Catálogo publicado EAD | PASS, **11 ofertas** | `02-ead-catalog.png` |
| Agricultura Sustentável, percurso nativo | PASS, **8 seções, 13 itens, 6 aulas em seções de vídeo** | `03-learning-path.png` |
| Aula sem opt-in de HTML privado | PASS, texto **Abrir curso no site EAD • aula não liberada para leitura no app** | `04-fallback-before-tap.png` |
| Toque no fallback | PASS, abre Chrome `ChromeTabbedActivity` com intent canônico HTTPS | `android-e2e-receipt.json` |
| Página oficial real carregada | **Confirmado após o fluxo, em captura separada** | `06-official-course-fully-rendered.png` |
| Conteúdo de vídeo dentro do app | **NÃO COMPROVADO** | Opt-in de conteúdo nativo desligado no WordPress público |
| Matrícula/nota/progresso/SSO/certificados | **NÃO TESTADO** | Não pertencem ao GET público |

URL canônica comprovada no Android:
`https://ead.ipexdesenvolvimento.cloud/courses/agricultura-sustentavel/`.

O curso oficial real foi inspecionado em captura Android depois do
primeiro uso do Chrome, com página "Agricultura Sustentável",
13 aulas e instrução de inscrição opcional.

## Proveniência dos vídeos e limitações

`android-e2e-record-85s.mp4` é o **MP4 original Android**, sem áudio
do sistema, `screenrecord_exit=0`, duração **85,058 s** (caixa `mvhd`
do contêiner), 2.316.757 bytes e SHA256
`d811826bf540b5e078a3934c2adfc90c9c3fce3f8c0f989fdf821976636dc995`.
A gravação cobre a entrada → catálogo → percurso → toque no fallback,
**mas o Chrome exibiu um aviso de privacidade em cima da página**; o clipe
não mostra a página oficial completamente renderizada no mesmo fluxo.

`chrome-public-page-separate-7s.mp4` (57.559 bytes, duração **7,7052 s**,
SHA256 `6f23352301aeb99307bba0640362b41b05faca52f47eb620703f3b8106ef43e0`)
é captura Android **complementar, separada**, após os avisos do Chrome,
não concatenação nem vídeo E2E contínuo. O screenshot
`06-official-course-fully-rendered.png` comprova o conteúdo da página.

Todos os seis PNG da execução principal e seu MP4 passaram
SHA256 conforme `android-e2e-receipt.json`; `CAPTURED`, exit 0.
As tentativas intermediárias (`capture-v1`, `v2` e `capture-final`)
ficaram BLOCKED por seletor antigo ("Percurso de aprendizagem" vs
"Percurso") ou onboarding/DOM do Chrome; foram mantidas localmente,
não relatadas como passes completos. A baixa memória livre no LARGeo
(~0,7–1,3 GiB com o emulador) afetou tempo de renderização do Chrome.

## Integração pública real

Auditoria **HTTP read-only** do WordPress/LearnPress institucional,
realizada separadamente na VM da GPU, verificou:

- **11/11 cursos publicados** com API pública HTTP 200 e
  URL canônica de curso HTTP 200.
- **Nove cursos originais:** 55 seções, 95 itens de lição,
  estrutura igual à importada para staging privado.
- **Zero quizzes inseridos nas grades públicas**, apesar de questões
  administrativas existentes fora dessa estrutura.
- Endpoint de leitura editorial `/tds-learning/v1/courses/1298/curriculum`
  no WordPress público retorna **HTTP 403**: **não** está autorizada
  leitura editorial nativa do app contra produção.
- No staging sintético privado `127.0.0.1:18740`, currículo GET 200,
  ETag 304 e 95 aulas com leitura privada 404 por padrão. É servidor
  independente: o APK **não** foi apontado para ele nesta execução.

Não declarar E2E de reprodução YouTube nativa, notas, autenticação
LearnPress ou certificado a partir desses screenshots/GET.

## CI: problema preexistente e correção portada

HEAD do PR #283 `189cc9e`: analyze PASS, segurança/quarentena PASS,
**full Flutter test CI FAIL** por **três goldens sintéticos** no Linux:
`ead_learning_path_golden_test.dart` (5,52%),
`ead_editorial_real_wp_golden_test.dart` (3,21%) e
`ead_mobile_lesson_golden_test.dart` (4,63%).
Essas falhas **não são falhas observadas no emulador Android**.

A branch desta QA porta os commits `acb7878` e `b10e986` já
desenvolvidos no PR #248, com três PNG golden Linux separados dos
referenciais Windows e comparação estrita preservada. A correção
ainda depende do **CI no HEAD resultante**; não alegar CI verde
antes da confirmação. Nenhum `flutter test --update-goldens`
novo foi executado nessa sessão.

## Condições de aceitação remanescentes

1. Revisar/obter CI Flutter verde com imagens Linux corretas sem
   abrandar comparação visual.
2. QA de player YouTube real em aula que tenha **opt-in e direitos**
   aprovados; ausência de autorização deve continuar em fallback seguro.
3. Para integração com conta, progresso, quizzes/avaliações e certificados,
   contratos separados de identidade, sessão e aprovação humana.

**MERGE_ALLOWED=NO; PRODUCTION_ALLOWED=NO;** sem publicação Play,
sem alteração de dados/WordPress/YouTube institucional.
