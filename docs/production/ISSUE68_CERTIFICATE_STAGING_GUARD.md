# Issue #68 — guard de homologação do certificado candidato em staging

Status: **IMPLEMENTED candidate guard; staging externo ainda BLOCKED**.

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
- Nenhum binding KV, namespace, secret ou deploy foi criado neste recorte.

## Configuração externa ainda necessária

Antes de declarar TESTED-STAGING:

1. criar o Worker de staging separado `tutor-tds-cert-staging` na conta
   `tdsipex.workers.dev`, sem rota ou binding de produção;
2. criar namespace KV de staging exclusivo com binding `CERTIFICATE_CANDIDATES`;
3. configurar `TUTOR_ENVIRONMENT=staging`;
4. configurar `CERTIFICATE_CANDIDATE_ENABLED=true`;
5. configurar `CERTIFICATE_CANDIDATE_SECRET` no secret store do Worker e da API
   de staging, nunca no Git ou no app;
6. configurar `CERTIFICATE_CANDIDATE_URL` na API apontando para o endpoint HTTPS
   de staging;
7. executar emissão/reconciliação com dados sintéticos e registrar evidência
   sanitizada.

O `wrangler.jsonc` produtivo existente não deve receber um ID fictício ou o
binding candidato de staging. A criação do recurso externo permanece HUMAN-GATE.

## Segurança

Push, Chatwoot, Flutter e estados acadêmicos não participam deste guard. O
candidato continua sintético e fora da carteira/export oficial; este recorte não
autoriza assinatura institucional, SMTP, Play/AAB ou produção.
