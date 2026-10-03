# WordPress do Portal TDS

Este diretório inicia o versionamento canônico do portal público no monorepo.

## `legacy-runtime/`

Snapshot sanitizado do código customizado observado no WordPress de produção em 03/10/2026. Serve para auditoria, comparação e reaproveitamento seletivo. **Não é um artefato autorizado para deploy.**

A origem instalada possui Git local sem remote e drift em relação ao HEAD histórico. O manifesto correspondente está em `docs/portal/WP1_LEGACY_SOURCE_MANIFEST.json`.

Não adicionar secrets, `.env`, uploads, banco, `vendor` ou caches.

## Arquitetura alvo

WP-2 deve criar:
- `tds-child-theme/`: camada visual;
- `tds-portal-core/`: domínio editorial/adapters/config;
- `staging/`: infraestrutura de staging reproduzível.

`tds-lms-core` é legado acadêmico congelado. O novo portal não deve expandi-lo.

## Evidência local do tema WP-2

O candidate `tds-child-theme/` foi implementado e testado apenas em uma
instalação WordPress/SQLite descartável. A evidência, os comandos e os limites
estão em `../docs/portal/WP2_THEME_EVIDENCE_2026-10-03.md`. Isso não comprova
staging, configuração institucional ou produção.
