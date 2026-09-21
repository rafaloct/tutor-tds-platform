# Preflight de promoção — API para o AAB 1.4

Data da fotografia: 2026-09-20

Decisão: **NO-GO para promoção imediata; produção e staging não são equivalentes.**

Esta inspeção foi somente leitura. Não houve deploy, restart, migration, backup,
leitura de segredo ou alteração de produção. O Compose remoto foi apenas
validado com `config --quiet`; o Compose local foi validado com placeholders.

## Evidência observada

| Item | Produção atual | Candidato observado em staging |
|---|---|---|
| URL | `https://ead.ipexdesenvolvimento.cloud/tutor-api` | `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api` |
| OpenAPI | 21 paths / 23 operações / 27 schemas | 59 paths / 64 operações / 70 schemas |
| Alembic | `20260920_0005` | `20260920_0014` |
| Container | `healthy` | `healthy` |
| Imagem | `tutor-tds-api-api` | `tutor-tds-api:staging-0014-certificate-seed-20260920` |
| Image ID | `sha256:6b19c35e8164…fe5d6af` | `sha256:65a5506836f9…c521d08` |
| Proveniência | sem label de commit e sem `.deployed-image` | tag manual, sem label de commit |

O container produtivo atual é a única referência de rollback observável. Ele
não tem tag imutável/marker durável; uma limpeza de imagens poderia eliminá-lo.
A imagem de staging tem digest conhecido, mas foi construída manualmente a
partir de worktree compartilhada e não pode ser promovida como release até ser
reproduzida de um commit congelado, testado e identificado por digest.

## Delta de contrato

Produção não possui 41 operações existentes no candidato. Não há operação
exclusiva de produção, portanto o delta é aditivo nas rotas. Entre as operações
adicionais, **26 são chamadas diretamente pelo cliente Flutter 1.4**:

```text
GET /assessment-attempts
GET /assessment-attempts/{attempt_id}
GET /assessment-attempts/{attempt_id}/content
GET /assessment-contents/{content_id}
PUT /assessment-attempts/{attempt_id}
PUT /assessment-contents/{content_id}
GET /classes
GET /classes/{class_id}/dashboard
POST /admin/classes/{class_id}/sessions
GET /classes/{class_id}/sessions
GET /classes/{class_id}/sessions/open
GET /classes/{class_id}/sessions/{session_id}
POST /classes/{class_id}/sessions/{session_id}/token
POST /classes/{class_id}/sessions/{session_id}/checkins
POST /classes/{class_id}/evidence-imports
GET /classes/{class_id}/evidence-imports/{import_id}
GET /classes/{class_id}/exceptions
POST /classes/{class_id}/evidence/{evidence_id}/review
POST /classes/{class_id}/sessions/{session_id}/close
GET /classes/{class_id}/reports/{report_id}
GET /media
GET /media/{media_id}
POST /media/{media_id}/playback-authorizations
GET /media/{media_id}/playback/{token}
GET /media/{media_id}/rating
PUT /media/{media_id}/rating
```

Além das rotas ausentes, quatro schemas já existentes mudaram:

- `EventCreate` e `EventResponse` acrescentam os cinco eventos de vídeo;
- `MembershipCreate` e `MembershipResponse` acrescentam `creator`,
  `coordinator` e `finance`.

Os demais endpoints novos são suporte operacional, certificados, sync,
editorial e comercial. Emissão de certificado do aplicativo não pertence à API
transacional: `/v1/certificates` continua sendo contrato do gateway externo.

O comparador reproduzível é:

```bash
python api/ops/promotion_preflight.py \
  https://ead.ipexdesenvolvimento.cloud/tutor-api/openapi.json \
  https://ead.ipexdesenvolvimento.cloud/tutor-staging-api/openapi.json \
  --fail-if-production-behind
```

O exit code `3` é esperado enquanto produção não contiver todas as operações
exigidas pelo AAB. O script é somente leitura e rejeita URLs sem HTTPS.

## Delta de migrations

A promoção aplicará, nesta ordem, o trecho `0005 -> 0014`:

1. `0006`: estado/índice da fila confiável de sync;
2. `0007`: linhagem e snapshots de certificados, com backfill;
3. `0008`: mídia, eventos de vídeo, Creator Score e ledger simulado;
4. `0009`: sessões, check-in, evidências, decisões e relatórios;
5. `0011`: solicitações auditáveis de purge no Sheets;
6. `0012`: tentativas de assessment com revisão;
7. `0013`: trilha editorial append-only, rating e grants de playback;
8. `0014`: conteúdo imutável de assessment e vínculo da tentativa.

Os testes locais cobrem upgrade/downgrade, constraints e inserts, mas isso não
substitui backup/restore nem ensaio sobre uma cópia da base produtiva. Rollback
de imagem **não** executa downgrade de banco automaticamente.

## Delta de configuração

Sem ler segredos, a inspeção do processo atual mostrou:

- `ALLOWED_ORIGINS` aponta para o domínio web aprovado;
- `PUBLIC_API_BASE_URL` não está configurado na imagem atual;
- origem de certificado e delivery Cloudflare não estão configurados;
- flags comercial/payment não existem na imagem atual;
- não há container `sync-worker` no projeto produtivo observado.

Para 1.4, `PUBLIC_API_BASE_URL` deve ser exatamente
`https://ead.ipexdesenvolvimento.cloud/tutor-api`; sem isso o grant de playback
perde o prefixo ou falha fechado. `PAYMENT_ADAPTER=disabled` deve permanecer.
Sheets e certificado só podem ser habilitados com contas/recursos produtivos
aprovados e seus testes específicos; não usar valores de staging.

O Compose local agora aceita `PRODUCTION_API_IMAGE` e usa a mesma imagem para
API e worker. Com placeholders, `docker compose config` confirmou imagem única,
banco sem porta publicada, rede interna e pagamento desabilitado. O Compose
presente no host também passou `config --quiet`, sem imprimir valores.

## Runbook de promoção — executar apenas após GO humano

### 1. Congelar e provar o candidato

1. Congelar um commit sem alterações pendentes.
2. Executar suíte API, migrations, Flutter e scans no mesmo SHA.
3. Construir/publicar uma única imagem imutável por SHA; registrar digest e
   SBOM/scan. Não promover a tag manual de staging desta fotografia.
4. Implantar esse digest primeiro em staging, repetir smokes por papel,
   assessment cross-device, Evidence e mídia.
5. Rodar o comparador OpenAPI; o candidato não pode perder rota produtiva nem
   operação exigida pelo AAB.

### 2. Preparar janela e rollback

1. Aprovar janela, responsáveis, tempo máximo e critério de abortar.
2. Registrar `docker inspect` do container produtivo, head Alembic e health.
3. Antes de qualquer troca, aplicar uma tag de rollback imutável ao image ID
   atual `sha256:6b19c35e8164…fe5d6af` e registrar a tag/digest fora da VPS.
4. Configurar `PRODUCTION_API_IMAGE` com o digest candidato, sem alterar os
   demais secrets; confirmar `PUBLIC_API_BASE_URL` e `PAYMENT_ADAPTER=disabled`.
5. Confirmar espaço em disco, banco healthy e ausência de migration concorrente.

### 3. Backup obrigatório

1. Com autorização explícita, executar `api/ops/backup.sh` no host antes da
   migration, preferencialmente com `BACKUP_AGE_RECIPIENT` e offsite montado.
2. Exigir artefato não vazio, `gzip -t`, SHA-256 e cópia offsite conferida.
3. Registrar timestamp, hash e RPO. Se o backup falhar, abortar a promoção.
4. Um restore drill em base isolada deve ter sido concluído antes da janela;
   não testar restauração pela primeira vez sobre produção.

### 4. Migration e troca

1. Colocar o rollout em manutenção controlada para impedir duas instâncias
   concorrendo pela migration.
2. Rodar `alembic upgrade head` uma única vez usando o digest candidato.
3. Exigir `alembic current == 20260920_0014`.
4. Subir API e, somente se Sheets produtivo estiver homologado, o worker usando
   o mesmo digest. Não habilitar pagamentos/comercial durante a promoção.

### 5. Gates pós-deploy

1. Confirmar container healthy, `GET /live`, `GET /health` e banco disponível.
2. Executar `ops/smoke_test.py` no prefixo `/tutor-api`.
3. Confirmar 401 sem token em rotas protegidas e login/refresh com conta QA
   produtiva autorizada.
4. Com dados descartáveis aprovados, testar catálogo, retomada de assessment,
   classes/dashboard, Evidence e mídia/playback/rating.
5. Reexecutar o comparador OpenAPI contra produção.
6. Observar 5xx, latência, conexões e logs sem PII durante a janela.

O QA físico de staging já confirmou duas chamadas ao playback authorization,
ambas HTTP 201. O log interno registra a rota depois do middleware remover
`/tutor-staging-api`; nenhum header, token ou payload foi exposto. Essa prova
fecha o access-log do staging, mas deve ser repetida no prefixo produtivo após a
promoção autorizada.

### 6. Rollback

Abortar por migration/health/smoke falho, aumento de 5xx, quebra de autenticação
ou perda de uma rota exigida. Parar o candidato e restaurar API/worker para a
tag imutável criada no passo 2. Como as migrations são aditivas, o primeiro
rollback é somente de imagem, mantendo schema avançado. Não executar downgrade
ou restore automaticamente. Se houver corrupção/incompatibilidade de dados,
manter manutenção e solicitar autorização específica para restaurar o backup.

## Autorizações mínimas ainda necessárias

1. Aprovação do commit/digest candidato e da janela produtiva.
2. Autorização para criar a tag durável de rollback da imagem atual.
3. Autorização para executar e armazenar backup criptografado/offsite.
4. Confirmação de que restore drill isolado passou e RPO/RTO são aceitáveis.
5. Fornecimento/validação de `PUBLIC_API_BASE_URL` e secrets produtivos pelo
   operador, sem compartilhá-los no chat.
6. Conta/dados QA produtivos descartáveis para smokes autenticados.
7. Decisão separada para Sheets, certificado e mídia/provider. Pagamentos
   continuam desabilitados.
8. GO explícito para migration, restart/troca de imagem e, depois, rollout Play.
