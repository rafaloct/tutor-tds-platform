# Diferença de rotas staging/produção — 2026-09-21

Comparação somente leitura dos documentos OpenAPI publicados em:

- staging: `/tutor-staging-api/openapi.json`
- produção: `/tutor-api/openapi.json`

Resultado observado: staging tinha 83 caminhos e produção 21; 62 caminhos do
staging não estavam presentes em produção. Esta fotografia não autoriza deploy
nem promoção.

## Famílias que exigem validação antes da promoção

- sessões, presença, check-in/out, evidências e relatórios de turma;
- baseline, mentoria e exceções;
- certificados e fila de revisão humana;
- editor, submissão, publicação, arquivamento e versões de cursos;
- mídia, playback assinado e avaliações;
- assessments e conteúdos de avaliação;
- analytics de criadores, pontuação e sincronização;
- identidade assinada do suporte Chatwoot;
- endpoint de liveness `/live`.

## Regra de promoção

Repetir a comparação contra o digest candidato, executar smoke autenticado por
papel e verificar que cada rota necessária ao APK está presente antes de
promover. Produção permanece no estado anterior até essa evidência existir.
