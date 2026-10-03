# WP-1 — Plano de staging, deploy e rollback

## Objetivo

Criar uma bancada WordPress isolada que permita WP-2..WP-7 sem editar `ead.ipexdesenvolvimento.cloud`.

## Staging proposto

Nome lógico: `ead-wordpress-staging`.
Domínio candidato: `ead-staging.ipexdesenvolvimento.cloud` (criação depende de autorização/DNS).

O staging deve usar:
- banco MySQL próprio;
- uploads próprios;
- Redis próprio;
- nenhuma cópia de usuários/PII de produção;
- `WP_ENVIRONMENT_TYPE=staging`;
- indexação desabilitada e header noindex;
- acesso restrito quando possível;
- SMTP desabilitado/sink ou inbox de teste;
- Chatwoot desabilitado ou inbox exclusiva de staging;
- n8n acadêmico desabilitado;
- analytics desabilitado/debug;
- API pública apontando somente ao endpoint aprovado para staging;
- acesso ao app em estado `unavailable` até configuração.

## Conteúdo inicial

Não clonar o banco contaminado de produção. Subir WordPress limpo e importar somente páginas/posts TDS revisados que forem necessários para teste editorial.

A pasta Drive `1cagbyKQHMALaa9_tiZu3H3T_VBQNNMDU` é fonte de identidade visual (logos/ícones/assets), não fonte operacional.

## Código

Fonte: GitHub `tutor-tds-platform`, diretório `wordpress/`.

Estrutura alvo:
- `wordpress/legacy-runtime/`: referência sanitizada; não evoluir.
- `wordpress/tds-child-theme/`: child theme futuro, derivado seletivamente do legado.
- `wordpress/tds-portal-core/`: plugin do portal.
- `wordpress/staging/`: compose/bootstrap e documentação de ambiente.

O Dokploy futuro deve consumir Git/commit identificável ou artefato construído. Não repetir `cp -r` manual de `/root/tds-wordpress`.

## Dependências determinísticas

Fixar versões de WordPress, PHP/base image, Astra e plugins necessários. LearnPress não é dependência do portal público novo.

Evitar depender de plugins instalados manualmente em volume anônimo. Se um plugin for necessário, sua instalação/versão precisa estar codificada no bootstrap/image e comprovada no smoke.

## Backup antes de mudança produtiva

Antes da primeira promoção:
1. backup MySQL do WordPress para destino externo aprovado;
2. backup do volume de uploads;
3. captura versionada do compose/config não secreta;
4. manifesto do commit/tag a promover;
5. teste de restauração em ambiente isolado.

Segredos permanecem no gestor de ambiente/Dokploy, nunca no Git.

## Rollback

Rollback de código:
- redeploy do commit/tag anterior.

Rollback editorial:
- restaurar banco somente quando a alteração envolver schema/conteúdo incompatível; preferir reversão editorial normal quando possível.

Rollback de mídia:
- restaurar uploads apenas quando necessário, evitando substituir arquivos posteriores sem avaliação.

Rollback deve ser ensaiado em staging antes da primeira promoção.

## Processo de promoção

PR draft -> CI/testes -> staging -> smoke visual/funcional -> revisão humana -> backup comprovado -> autorização explícita -> deploy produção -> smoke pós-deploy.

Produção nunca recebe merge/deploy automático a partir de PR de desenvolvimento.

## Human gates

- criação do domínio/DNS de staging;
- configuração de eventual proteção de acesso;
- credenciais de staging e secrets;
- autorização da primeira promoção.
