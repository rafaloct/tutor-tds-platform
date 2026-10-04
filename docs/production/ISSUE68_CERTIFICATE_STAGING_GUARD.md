# Issue #68 — guard de homologação do certificado candidato em staging

Status: **TESTED-STAGING; emissão institucional final continua bloqueada**.

## Objetivo

Permitir que o protocolo candidato já integrado pelo PR #39 possa ser exercitado
em um ambiente de staging real sem abrir produção e sem transformar mocks locais
em evidência de homologação.

## Limites do recorte

- `development` continua aceitando somente transporte HTTP loopback e pode usar
  o exchange sintético injetado dos testes.
- `staging` exige `CERTIFICATE_CANDIDATE_ENABLED=true`, secret server-side com
  comprimento mínimo já exigido e o endpoint HTTPS canônico
  `tutor-tds-cert-staging.tdsipex.workers.dev` (sem porta, path, query ou
  credenciais); **não aceita exchange injetado**. Qualquer Worker de outra
  conta ou hostname apenas rotulado como staging falha fechado.
- `production` continua bloqueado independentemente da flag.
- O Worker aceita o handler candidato somente em development/staging e mantém
  produção bloqueada.
- Este PR não versiona namespace KV, binding, secret nem configuração de deploy.

## Homologação externa concluída

A evidência sanitizada da homologação real está registrada na Issue #68:
https://github.com/rafaloct/tutor-tds-platform/issues/68#issuecomment-5976124624

Foi comprovado em staging isolado:

1. API → HMAC → Worker → KV exclusivo de staging;
2. contexto divergente falha fechado com 422;
3. replay preserva a mesma emissão lógica/idempotente;
4. receipt autenticado é confirmado e a reconciliação posterior recupera o
   mesmo candidato;
5. a referência candidata permanece fora de `GET /certificates`;
6. a emissão institucional final continua bloqueada;
7. o runtime de staging voltou ao estado limpo após o teste;
8. nenhuma alteração foi feita em produção.

O `wrangler.jsonc` produtivo permanece sem binding candidato de staging.

## Segurança

Push, Chatwoot, Flutter e estados acadêmicos não participam deste guard. O
candidato continua sintético e fora da carteira/export oficial; este recorte não
autoriza assinatura institucional, SMTP, Play/AAB ou produção.
