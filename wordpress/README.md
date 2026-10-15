# WordPress do Portal TDS

Este diretório inicia o versionamento canônico do portal público no monorepo.

## `legacy-runtime/`

Snapshot sanitizado do código customizado observado no WordPress de produção em 03/10/2026. Serve para auditoria, comparação e reaproveitamento seletivo. **Não é um artefato autorizado para deploy.**

A origem instalada possui Git local sem remote e drift em relação ao HEAD histórico. O manifesto correspondente está em `docs/portal/WP1_LEGACY_SOURCE_MANIFEST.json`.

Não adicionar secrets, `.env`, uploads, banco, `vendor` ou caches.

## Direção vigente — 15/10/2026

Decisão posterior do usuário: aprimorar o WordPress existente. A estratégia
Drupal foi substituída como alvo de portal; histórico e serviços são preservados,
sem autorização implícita para desativação. Evolução nos diretórios canônicos:
- `tds-child-theme/`: camada visual;
- `tds-portal-core/`: domínio editorial/adapters/config;
- `staging/`: infraestrutura de staging reproduzível.

`tds-lms-core` é legado acadêmico congelado. O novo portal não deve expandi-lo.

A quarentena continua restrita ao snapshot legado e ao manifesto original;
`wp-legacy-quarantine.yml` permanece obrigatório. O tema atual não cria login
acadêmico ou equivalência automática com os ensaios Drupal. Veja a decisão34
em `docs/DECISIONS.md` e o recibo `docs/portal/WP_BRAND_REFRESH_2026-10-15.md`.
