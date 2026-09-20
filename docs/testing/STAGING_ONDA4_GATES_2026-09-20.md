# Evidência dos gates sintéticos da Onda 4 em staging

Data: 2026-09-20

Alvo: `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`

Imagem: `tutor-tds-api:staging-0014-playback-prefix-20260920`
Migration: `20260920_0014 (head)`

## Escopo e guardas

O script `api/ops/staging_media_gates_smoke.py` aceita somente URL HTTPS que
contenha `staging`, usa a linhagem sintética fixa do seed e exige a confirmação
efêmera `STAGING_SYNTHETIC_DB_MUTATION_CONFIRM` antes de qualquer SQL. As
credenciais vêm do arquivo sintético modo `0600` e não são impressas.

As únicas mutações diretas no PostgreSQL foram delimitadas pelo UUID da mídia
criada pelo próprio smoke:

- tentativa de `UPDATE` e `DELETE` na trilha editorial, ambas obrigatoriamente
  rejeitadas pelo trigger append-only;
- antecipação de `expires_at` do grant sintético para provar expiração sem
  aguardar cinco minutos;
- remoção do grant já expirado após a prova.

O script não chama ledger/payout, não muda configuração comercial e sempre
tenta arquivar a mídia sintética no `finally`.

## Resultado observado

- criação editorial por professor sem papel creator/coordinator: HTTP 403;
- histórico editorial pelo aluno: HTTP 403;
- cálculo do Creator Score pelo aluno: HTTP 403;
- tentativas diretas de alterar/excluir a trilha: rejeitadas com a mensagem
  append-only do PostgreSQL;
- grant expirado controladamente: HTTP 401;
- eventos qualificados, follow-up, salvamento e rating 5 geraram
  `creator-score-v2` de 10.000 basis points;
- repetição da mesma janela: HTTP 200 e mesmo `score_id`;
- janela sobreposta: HTTP 201 e novo `score_id`, sem lançamento financeiro;
- mídia terminou `archived`, com quatro transições e dois scores v2;
- grant sintético removido e zero linhas de ledger para a mídia.

Leitura final resumida do banco:

```text
archived | transitions=4 | scores=2 | score_v2_10000=2 | grants=0 | ledger=0
```

O container permaneceu com `COMMERCIAL_SIMULATION_ENABLED=false` e
`PAYMENT_ADAPTER=disabled`. O health público continuou disponível. Produção não
foi acessada nem alterada.

## Execução reproduzível

No diretório isolado de staging, após carregar as credenciais sintéticas sem
ecoá-las:

```bash
STAGING_SYNTHETIC_DB_MUTATION_CONFIRM=expire-synthetic-grant-and-check-trigger \
  python3 ops/staging_media_gates_smoke.py \
  https://ead.ipexdesenvolvimento.cloud/tutor-staging-api
```

Não usar esse script contra produção nem trocar o compose autorizado pelo
script. A confirmação não deve ser persistida no `.env`.
