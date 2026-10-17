# Experimento M1: EAD-first no aplicativo Tutor TDS

Parent: https://github.com/rafaloct/tutor-tds-platform/issues/224
Slice: https://github.com/rafaloct/tutor-tds-platform/issues/225
Estado: candidato em branch isolada, sem merge/deploy/novo AAB.

## Problema observado em 17/10/2026

- O WordPress /wp-json/wp/v2/lp_course publica **11 cursos**. FastAPI /tutor-api/courses retorna **9**, e Flutter staging contém **9 cartilhas JSON locais**.
- Além dos nove originais, o LearnPress publica Automações com o Celular (1474) e IA aplicada a Processos Internos (1709). Este segundo título precisa de revisão de audiência antes de **campanha** externa, ainda que o WordPress o sirva anonimamente.
- Versão instalada por Google Play no Samsung SM-T835: pacote com.tutortds_cartilhas 1.4.1+14, installer com.android.vending. Staging no Git b0c39b2 é código anterior 1.4.0+13; clone de Git não é binário idêntico ao Play.
- Base APK Play coletada por ADB, somente leitura, em D:\AI-Shared\work\tds-play14-readonly-audit-20261017. Separadores de APK completos ficaram pendentes porque o ADB retornou device offline numa checagem posterior.
- VM CUDA L4: GPU 23 GiB/40 CPUs/125 GiB de RAM; aproximadamente 17 GiB VRAM ocupados por render de vídeo. Checkout separado staging@b0c39b2 em /workspace/tds-app-site-convergence-20261017, com uv/venv próprios, sem interromper o render.
- Fontes YouTube: 48 aulas dos nove cursos originais no manifesto atualizado, 45 vídeos do uploader antigo com 10 enviados e 35 pendentes. HEAD HTTP 200 em 48/48 URLs; o tamanho dos 45 originais coincide com o mapa local, mas **tamanho não comprova igualdade de hash ou revisão pedagógica**. PlaylistItems 409 em scheduler anterior exige reconciliação idempotente.

## Competição de hipóteses

| Experimento | Benefício | Risco/custo | Condição para escolher |
| --- | --- | --- | --- |
| A. Catálogo público nativo + navegador EAD | EAD atualiza cursos sem relançar aplicativo, preserva cookies do browser | Transição de contexto | Primeiro piloto e QA Android real |
| B. Curso em WebView + Tutor sobreposto | Navegação integrada | Cookies/sessões, acessibilidade, deep link, instabilidade | Somente se taxa de matrícula justificar e testes passarem |
| C. LMS headless em Flutter | UX única | Duplicação de currículo, progresso, matrícula, conteúdo e suporte | Não escolher sem evidência de custo-benefício superior |

Escolha inicial: **A**, com avaliação posterior do funil real. O usuário escolhe o curso no EAD, matrícula e avaliação mantêm suas regras próprias, enquanto cartilhas e Tutor TDS permanecem no aplicativo.

## Código do protótipo A

- Repository público `EadCatalogRepository`: GET HTTPS do host fixo ead.ipexdesenvolvimento.cloud, tipo lp_course; status publish; valida id/slug/título, paginação, tamanho de resposta e duplicatas. Não recebe CPF, token, cookie nem redirecionamento arbitrário.
- `EadCatalogScreen`: atualização manual, lista responsiva, loading, vazio, erro/retry e handoff para navegador externo. Não usa WebView autenticada e nunca interpreta clique como matrícula.
- `HomeScreen`: CTA antes do cabeçalho das cartilhas; mantém as nove cartilhas offline e o Tutor TDS acessível nos fluxos existentes.
- `WelcomeScreen`: botão **Explorar cursos do EAD sem cadastro** antes de nome, WhatsApp e CPF, sem submeter o formulário nem criar conta. A personalização e o certificado mantêm seus controles específicos.
- O screen suporta injeção de loader/opener em testes. Não há suposto Tutor RAG para os dois novos cursos.

## Validação no recorte

- HTTP real pela VM L4: 11/11 destinos de curso retornaram status 200 sem sair do host oficial.
- `dart run tool/ead_catalog_probe.dart` no LARGeo: 11/11 cursos e URLs canônicos, exit 0.
- Testes Flutter após inclusão do Welcome público: **25/25 PASS, exit 0**, incluindo repository 7, screen 4, Home EAD 1, Welcome EAD sem CPF 1, welcome_account regressões e Home existentes. Não equivale a prova Android E2E.
- Flutter analyze focado sem issues antes do último ajuste de Home; repetir após mudanças.
- API FastAPI no clone VM: `uv sync --frozen --extra test` em venv isolado e pytest dos módulos public_api/media_commercial/course_editor, encerramento exit 0 com avisos de depreciação nas dependências.

## Regras operacionais e próximos experimentos

- Propriedade de curso, autenticação e progresso não foram migrados. Não usar WordPress como segunda fonte de autorização de presença/certificado.
- Não publicar campanhas automáticas para todos os 11: revisar audiência, link de inscrição e direitos, especialmente conteúdo de processos internos.
- Para campanha compartilhada: URL pública rastreável sem PII, CTA Play/app, digital asset links verificados no domínio, fallback para site quando não instalado.
- Para mídia: revalidar MP4/legenda/poster por hash/proveniência antes de reaproveitar uploader e marcar publish no banco; corrigir PlaylistItems 409 com leitura antes de repetir POST.
- Para Tutor: passar contexto de cartilha/módulo/lesson somente se indexado e validado; declarar indisponibilidade caso contrário.
- Para aceite: usar AVD LARGeo e APK candidato separado da versão Play, screenshots reais e teste de abertura no navegador/site; não inferir Play-ready de widget tests.

Fontes: https://developer.android.com/training/app-links/about ; https://docs.flutter.dev/cookbook/navigation/set-up-app-links ; https://developers.google.com/youtube/data/reference/rest/v3/playlistItems/insert ; https://learnpresslms.com/docs/learnpress/rest-api/
