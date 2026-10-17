# EAD como fonte editorial dinâmica: contrato da primeira integração (#235)

## Objetivo

Ao inserir, reordenar, editar ou retirar uma aula/quiz nas seções publicadas do LearnPress, o aplicativo Tutor TDS deve refletir **a grade** na próxima consulta ou no botão Atualizar, sem rebuild. O visual usa sempre `AppTheme.light()`/`AppTheme.dark()`, não um tema paralelo verde. O backend FastAPI permanece responsável pela identidade e pelas evidências do Tutor; não assume edição curricular concorrente.

## Constatações 17/10/2026, somente leitura

- `GET /wp-json/learnpress/v1/courses/{id}` tem 9 cursos originais (95 itens) e itens `lp_lesson`; nenhuma questão `lp_quiz` atualmente conectada aos módulos dos 11 cursos publicados. No WordPress há 29 posts `lp_quiz` e 282 posts `lp_question`, mas estão fora da grade publicada (PR #232).
- `GET /wp-json/wp/v2/lp_quiz/{id}?_fields=id,status,link` retorna ID/status/URL pública quando autorizado, sem perguntas ou respostas. Desktop verificou 200 com quiz 640. A VM L4 obteve 403 na mesma URL, apesar de GET de cursos funcionar: acesso precisa de teste Android e política Cloudflare/WordPress; não inventar sucesso cross-device.
- Detalhes de uma aula e quiz em `/learnpress/v1/lessons/{id}` e `/learnpress/v1/quizzes/{id}` retornam 401 sem autenticação. A grade pública **não disponibiliza o conteúdo completo das lições, vídeo de provedores ou provas autenticadas**.
- O golden verde anterior usava manualmente `ThemeData(colorSchemeSeed: Colors.green)`; foi corrigido no PR #234 para `AppTheme.light()`, com Poppins e azul institucional.

## Código em candidato empilhado

- O Flutter consulta grade LearnPress ao abrir/atualizar; detecta itens `lp_quiz` na seção de origem e renderiza CTA. O clique verifica publicação/identidade/URL canônica em `wp/v2/lp_quiz/{id}` naquele instante, abrindo o navegador para manter autenticação do LMS. Nenhuma pergunta ou gabarito passa por endpoint público.
- Se o quiz sair da grade, o próximo `fetch`/refresh o remove da tela; se mudar título/ordem, a sequência exibida muda. Testes simulam atualizações na mesma sessão do app, sem recompilar.
- Para vídeo novo em seção `Assista em vídeo` ou `Videoaulas`, o título da seção determina a marcação. Um marcador `tds_content_type=video` é entendido caso um adaptador oficial venha a fornecê-lo. IA mantém exceção legada para 4 seções verificadas, **não** é um contrato editorial escalável.
- As nove cartilhas Flutter e suas 38 perguntas continuam preservadas; **seus textos e respostas não são ainda atualizados pelo LearnPress**. Não declarar sincronização completa.

## Arquitetura alvo sem cópia congelada

1. **WordPress/LearnPress = edição e publicação**. A equipe edita lições, quiz, sequência, links/legendas e estado de publicação uma única vez no site.
2. **Adaptador editorial WordPress (próxima frente)**: endpoint read-only autenticado ou público restrito por visibilidade para `course_id`, `revision`, `sections`, `lessons`, `video_asset_id`, `media_policy`, `quiz_id`, `lesson_html` saneado e `last_modified`, derivado dos objetos originais LearnPress, sem salvar clones. Publicar apenas conteúdo autorizado e nunca gabaritos.
3. **Flutter = apresentação móvel**: agenda de módulos e conteúdos carregados do adaptador (ETag/revalidation), playback YouTube via vínculo editorial, questionário delegando tentativa ao LearnPress com SSO/federação aprovada ou usando FastAPI com sincronização transacional idempotente formalmente definida. Tutor contextual pelo ID de lição/módulo e RAG aprovado.
4. **FastAPI = autoridade transacional TDS**: credenciais próprias, turmas, evidências, certificados, proteção de gabaritos, registros e auditoria. Não inventar presença/nota derivada de vídeo ou clique.
5. **Sem site disponível**: manter cartilhas previamente autorizadas/cache local e informar que podem estar desatualizadas; não afirmar que uma aula/quiz mudou quando não houve refresh.

## Gates de aceitação completa (ainda pendentes)

- Revisar com instrutores o destino dos 29 quizzes e 282 questões antes de vincular às 48 videoaulas; respeito aos papéis e direitos.
- Construir e homologar o adaptador LearnPress com critérios de segurança, versionamento e cache, e depois renderizar blocos/cartilhas realmente vindos dele.
- Resolver as consultas 401 de lesson/quiz por acesso autorizado em vez de burlar endpoints; verificar 403 de metadados de quiz no Android (Cloudflare/WP).
- Concluir YouTube 48/48, direitos, legendas, vínculo mídia↔lesson e testes de vídeo; PR #217 não foi integrado.
- Definir fonte oficial de progresso, tentativa e certificado quando o aluno alterna navegador WordPress e app. Não duplicar notas sem SSO.
- Capturas Android em duas dimensões e tema claro/escuro, testes de acessibilidade, nenhum Play deploy antes do aceite.

## Evidências desta etapa

- PR #234: golden com `AppTheme.light` e Poppins, teste visual PASS.
- PR dependente #235: parser/quiz link/refresh tests, que não acessam gabarito nem dados pessoais. `flutter analyze` e regressão focal devem ser registrados com exit status.
- Auditoria VM L4 em paralelo do contrato público dos nove cursos; não houve inferência paga nem interrupção do pipeline GPU.

## Reversão

Reverter a branch proposta. Não foram escritas alterações no WordPress, na FastAPI, na Play Store ou no sistema de matrículas. `MERGE_ALLOWED=NO` até revisão.