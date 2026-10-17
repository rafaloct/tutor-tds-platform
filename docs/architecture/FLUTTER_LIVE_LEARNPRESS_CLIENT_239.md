# Flutter: cliente de conteúdo vivo LearnPress (Issue #239)

**Dependências**: catálogo PR #226 → percurso PR #234 → grade/quiz PR #237 → esta fatia Flutter, com plugin WordPress separado PR #238. Nenhum deles foi mesclado automaticamente.

## Fonte única editorial

O WordPress/LearnPress continua sendo a fonte das lições, seções, títulos, revisões e mídias explicitamente autorizadas para visualização pública. A FastAPI guarda identidade, turma, atividades oficiais, tentativas, evidências e certificados. **Não se importam gabaritos/provas ou matrículas por GET.**

- `EadEditorialBridgeRepository` chama HTTPS fixo `tds-learning/v1/courses/{id}/curriculum` e `/lessons/{lesson_id}`, com validação de IDs, autoridade LearnPress, versão, tamanho, revisão SHA256 e ETag.
- A revisão é reconsultada ao abrir/atualizar a tela. Um HTTP 304 reaproveita somente currículo já validado nesta sessão; mudanças reais no WordPress atualizam a representação sem novo build.
- Se o plugin não foi instalado (404), o app **continua consultando somente a grade pública LearnPress antiga** e não presume permissão de texto/vídeo. 401/403/502 não liberam dados por fallback.
- Uma lição só é clicável em tela nativa se o adaptador marcou `mobile_content=true`. HTML limitado e saneado pela origem é convertido em títulos, parágrafos e listas com widgets nativos Poppins e tema `AppTheme`. O Flutter não executa script, plugin shortcode ou embed do WordPress.
- Vídeo aparece somente quando a resposta traz videoId YouTube validado pelo plugin com direitos aprovados. Nesta etapa abre vídeo via aplicativo/navegador YouTube; **playback nativo rastreado pela FastAPI ainda pertence à integração de mídia PR #217**.
- Quiz autenticado continua no LearnPress com navegador e sessão própria. Nenhuma sincronização de gabaritos, resultado, nota, presença ou certificado foi implementada.
- Poster e legenda são validados por host/HTTPS se presentes, mas **não são ainda renderizados nem baixados pelo Flutter desta fatia**. Imagens privadas e conteúdo inscrito não são capturados por REST público.

## Testes e evidência

Executados no DESKTOP-8T5DRBS com Flutter 3.44.9, checkout separado `agent/issue-239-flutter-editorial-20261017`: unit/widget tests do novo contrato, ETag 304, mudança sem recompilar, 404 fallback, 401/403, HTML de lição, YouTube, bloqueio de payload malicioso, renderização Poppins, erro e regressões do catálogo anterior.

Golden `cartilhas_app/test/goldens/ead_authorized_lesson_blue.png` foi gerado com dados **sintéticos** na cor institucional azul. Não confundir com prova de app publicado nem screenshot do Android em produção. MaterialIcons do runner de golden podem aparecer como quadrados; os vídeos reais dos AVDs da fatia anterior seguem arquivados separadamente.

## Próximos gates

1. Instalar PR #238 em WordPress staging restaurável e habilitar opt-in **somente em lição sintética**, conferindo ETag 200/304, ausência de vazamento, nonce, direitos e assinatura das permissões.
2. Emular Android 35/36 com AAB/APK QA específico desta branch e gravar tela de aula real. O Android 36.1 teve ANR de System UI sob RAM baixa anteriormente; não declarar passe sem nova prova.
3. Refinar a fidelidade de HTML autorizado ao conteúdo do site por blocos Flutter com negrito/link/figuras acessíveis, sem introduzir WebView desprotegida. Não considerar formatação integral já equivalente nesta entrega.
4. Atualizar as nove cartilhas integralmente a partir do LearnPress após as fontes estarem autorizadas e estender ao Tutor IA somente quando o binding RAG estiver validado pelo instrutor.
5. Associar vídeo YouTube, VTT/poster e atividades à lição real e decidir a autoridade de conclusão/prova com a equipe, preservando assinatura/autenticidade de tentativas existentes.

Sem produção, alterações no WordPress real, certificados, Play Store, force-push ou merge automático. `MERGE_ALLOWED=NO`.
## Novo teste de interoperabilidade com dados de WordPress real (ambiente sintético)

- WordPress 6.7.2, LearnPress 4.3.6 e plugin candidato PR #238 foram instalados em uma área isolada da VM Linux, com SQLite e somente materiais sintéticos de SAF; servidor PHP local limitado a `127.0.0.1:18731`, já encerrado.
- HTTP real: GET currículo **200**, `If-None-Match` **304**, aula 12 explicitamente autorizada **200** e aula privada 13 **404**; sem código script ou shortcode residual.
- Fixtures capturadas literalmente das respostas HTTP, com formatação JSON para leitura, em `test/fixtures/ead_editorial/curriculum-wp672-lp436-synthetic.json` e `lesson-wp672-lp436-synthetic.json`. Ambos os arquivos contêm somente curso, quiz e aula sintéticos; não incluem pessoas, gabaritos, cookies ou credenciais.
- `test/ead_editorial_real_wp_fixture_test.dart` reexecuta o parser e o tratamento de ETag contra **esses JSON reais**, com transporte HTTP simulado dentro do teste. Isto é uma **prova de compatibilidade de formato**, não teste ponta a ponta do APK acessando diretamente o WordPress.
- `test/ead_editorial_real_wp_golden_test.dart` cria uma captura golden do conteúdo sintético na UI `AppTheme.light()`; arquivo `test/goldens/ead_wp_synthetic_real_http_blue.png`. **Imagem gerada por teste Flutter, não screenshot Android**. A fonte de Material Icons no runner de teste pode aparecer como quadrados; a legibilidade real precisa de AVD.
- O próprio plugin WordPress descobriu um caso que os mocks não capturavam: `wp_kses()` remove tags `script` mas deixa conteúdo em texto. Isso foi corrigido no PR #238 antes da captura do JSON, e o teste WordPress real foi repetido com 27 condições aprovadas.
- A instalação WordPress com SQLite **não confirma** compatibilidade MySQL/MariaDB, roles reais dos instrutores ou autenticação/autorização num servidor HTTPS de staging. Estes gates não foram ignorados.
