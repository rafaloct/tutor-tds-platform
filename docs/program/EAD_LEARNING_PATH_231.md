# Tutor TDS | EAD: prévia de percurso e convergência pedagógica

**Parent**: [Issue #229](https://github.com/rafaloct/tutor-tds-platform/issues/229) | **Vertical slice**: [Issue #231](https://github.com/rafaloct/tutor-tds-platform/issues/231) | Dependência de catálogo: PR #226.

## Decisão que esta fatia testa

O site WordPress/LearnPress publica a grade visível; o Flutter preserva os nove cursos locais, perguntas de fixação e o Tutor com contexto quando de fato configurado. O backend FastAPI mantém contas, turma, versões, notas de provas reais, certificados e auditoria. Não implantar uma Lambda adicional nem duplicar matrícula.

**Esta fatia é uma prévia read-only, não a integração pedagógica final**: reúne em uma tela a grade editorial do site e a navegação para cartilha/Tutor nativos, mas **ainda não intercala vídeo, questão e explicação aula a aula** nem sincroniza conclusão.

## Evidência de 17/10/2026

- GET público dos 11 cursos no LearnPress: 103 itens de grade, todos `lp_lesson`, nenhum `lp_quiz` ou prova exposta nas grades REST consultadas. Isso não prova inexistência de avaliações fora dessa superfície.
- A auditoria independente do PR #232 / Issue #230 confirmou 29 posts `lp_quiz` e 282 `lp_question` existentes no WordPress; zero desses quizzes está vinculado às seções dos cursos publicados. O banco de questões existe, mas precisa de curadoria e vinculação editorial antes de aparecer nos percursos.
- Nove cursos originais: 95 itens do LearnPress, dos quais 48 videoaulas em seções identificadas no manifesto anterior; os nove assets JSON Flutter somam 47 seções e 38 questões de prática.
- Curso IA (#614) exige exceção: 12 videoaulas em 4 módulos de vídeo, mais 5 lições de cartilha de referência.
- A API FastAPI já diferencia quiz/exam e administra tentativas. Essas respostas não devem ser copiadas para REST anônimo.
- Smoke real via `dart run tool/ead_learning_path_probe.dart`: **9 cursos, 95 itens, 48 videoaulas por IDs de seção, PASS**. O teste detectou 50 por heurística textual inicialmente; a seção 41 de Audiovisual contém leitura chamada 'O Poder do Vídeo' e foi falsamente classificada. Correção passou a usar a lista fechada de IDs auditados e ganhou regressão automatizada.
- Videoaulas ainda não publicadas como 48 `media_assets` no backend; PR #217 depende de upload YouTube, revisão editorial de direitos, associação a módulo/competência e `CourseVersion`.

## O que entrou neste PR

- Repository `EadCurriculumRepository`: HTTPS público no host fixo, `GET /learnpress/v1/courses/{id}`; valida identidade, tamanhos, seções, itens e duplicatas; sem token/cookie/identificador pessoal.
- Tela `EadLearningPathScreen`: grade de lições na ordem LearnPress, sinalização de seções com vídeo, abertura do curso pelo navegador, entrada independente para a cartilha Flutter e o Tutor existente. O exercício local preserva seu percurso de progresso.
- Para as duas ofertas fora dos nove cursos originais, não cria cartilha nem Tutor RAG falsos.
- O catálogo EAD-first mantém seu clique original de abertura no site; adiciona opção secundária **Ver percurso e prática no app**.
- Golden screenshot `cartilhas_app/test/goldens/ead_saf_learning_path_preview.png`: **fixture visual sintética**, nunca declarar como screenshot de app rodando em Android.

## Testes

Executar no desktop (Flutter 3.44.9, JDK 21):

    flutter pub get
    flutter analyze --no-pub lib/features/ead_catalog test/ead_curriculum_repository_test.dart test/ead_learning_path_screen_test.dart test/ead_learning_path_golden_test.dart
    flutter test --no-pub test/ead_curriculum_repository_test.dart test/ead_learning_path_screen_test.dart test/ead_learning_path_golden_test.dart test/ead_catalog_repository_test.dart test/ead_catalog_screen_test.dart

QA Android existente: o PR #226 (candidato pai) instalou APK isolado x86_64 no desktop e mostrou 11 cursos reais em dois perfis Android35; Android36 ficou BLOCKED por ANR do System UI com pouca RAM. **A prévia nova não foi compilada ou filmada em Android**.

## Próxima etapa com revisão dos instrutores

1. Aprovar um mapa versionado WP section/lesson -> curso/section/message Flutter -> YouTube video ID e fonte da cartilha, começando por SAF e Agricultura Sustentável.
2. Introduzir navegação por módulo real no `ChatExperienceScreen` (que hoje inicia por progresso e não recebe `initialSectionId`) preservando estado de aprendizagem e identidade.
3. Definir posição das questões de prática depois de cada vídeo com base no conteúdo homologado, não na semelhança lexical dos títulos. Repassar a decisão ao pipeline de publicações do site.
4. Publicar quizzes e provas no LearnPress **somente** se a equipe desejar: a grade atual não os contém. Não transferir notas entre plataformas sem SSO/federação validada, idempotência e revisão institucional.
5. Tutor IA: vincular RAG estritamente a CourseVersion, lesson/módulo real e fonte aprovada; se faltar binding, explicar a indisponibilidade em vez de alucinar.
6. Roteiros de gravação e prints reais nos AVDs do desktop/LARGeo somente quando houver memória suficiente, mantendo o Play e dispositivos físicos intactos.

### IA de apoio

O modelo local NVIDIA Nemotron Nano 9B v2 na VM L4 foi consultado como experimento para alinhar títulos SAF, mas a inferência ultrapassou o timeout (100 segundos) e não retornou uma proposta. Nada foi aprovado nem publicado por ele. Manter a L4 dedicada ao vídeo; futuros executores podem testar um modelo mais rápido só para **sugestões** de correspondência, nunca para alterar grades automaticamente.

### Regras

Sem merge automático, deploy, alteração de aulas no WordPress, emissão de certificados ou regravação de notas. Mutações do conteúdo institucional exigem consentimento e evidência de rollback.
