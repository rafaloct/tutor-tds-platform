# META 06 — aceite de staging do aplicativo

Base da onda: `89624132a150def54c2bc61091fb69fee0e1de07`.

Este roteiro cobre somente as issues #30, #6 e #31 no ambiente isolado de
staging, com dados sintéticos. Ele não autoriza deploy de produção, AAB, acesso
a dados reais, alteração de flags de produção ou qualquer trabalho WordPress.

## Pré-condições únicas

- [ ] A imagem/API de staging corresponde à base desta onda e responde
  `GET /health` com banco de staging.
- [ ] As migrations já existentes da base foram aplicadas uma única vez no
  banco isolado; nenhuma migration nova é criada para esta onda.
- [ ] O seed contém apenas contas, turma, cursos e conteúdo sintéticos.
- [ ] `OPERATOR_OPERATIONS_ENABLED=true` somente no staging.
- [ ] `REMOTE_CATALOG_ENABLED=true` somente no staging, se a configuração
  existente o exigir.
- [ ] Demais integrações públicas e credenciais externas permanecem desligadas.
- [ ] A coleta de logs está sanitizada: sem senha, token, CPF ou URL assinada.

## #30 — operador, matrícula e turma

- [ ] Localizar ou criar pessoa sintética.
- [ ] Criar matrícula e turma sintéticas.
- [ ] Corrigir uma operação com a revisão esperada.
- [ ] Repetir a mesma chave de idempotência e confirmar uma única mutação.
- [ ] Confirmar rejeição de usuário sem autorização.
- [ ] Revogar a autoridade e confirmar que uma nova operação é rejeitada.
- [ ] Exercitar a interface Flutter contra essa mesma API de staging.

## #6 — frequência oficial e reposição

- [ ] Criar ou selecionar sessão oficial sintética.
- [ ] Registrar decisão de presença e decisão de ausência.
- [ ] Registrar reposição sintética.
- [ ] Confirmar que reposição não cria presença automaticamente.
- [ ] Conferir histórico, revisão e idempotência.
- [ ] Conferir projeção de 70% e a projeção de jornada/certificado.
- [ ] Exercitar a interface Flutter contra a mesma API.

## #31 — materiais remotos

- [ ] Publicar conteúdo sintético PDF, vídeo e link.
- [ ] Publicar edição posterior sem alterar a edição anterior.
- [ ] Confirmar que a nova publicação aparece no catálogo sem rebuild do app.
- [ ] Simular provider indisponível e confirmar fallback/offline.
- [ ] Inspecionar o delta de logs para ausência de URL assinada, segredo ou PII.
- [ ] Exercitar a interface Flutter contra a mesma API.

## Evidência e encerramento

Registrar somente IDs sintéticos, hash/commit, revision Alembic, flags pelos
nomes, horários, resultado de cada caso e hash do APK DEV, quando houver. O
aceite de #30, #6 e #31 exige todas as caixas aplicáveis; testes locais não
substituem staging. A validação no aparelho é um único `HUMAN_GATE_DEVICE` se
não houver Android físico conectado.

`RC_READY_FOR_AAB = NO`.