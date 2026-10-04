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

## Runbook mínimo antes de provisionar staging externo

Este runbook não autoriza provisionamento. Ele apenas define a sequência que deve ser seguida depois de uma autorização humana explícita.

### Gate A — fonte e escopo

Antes de criar qualquer serviço externo:

1. registrar o SHA canônico que será homologado;
2. confirmar que `wordpress/legacy-runtime/**` não aparece no artefato de deploy;
3. limitar o pacote a `wordpress/tds-child-theme/**`, `wordpress/tds-portal-core/**` e bootstrap de staging aprovado;
4. confirmar que LearnPress e `tds-lms-core` permanecem ausentes/inativos;
5. manter `privacy.html` e `account-deletion.html` independentes do WordPress e validar HTTP 200 antes e depois do ensaio.

Se qualquer item falhar, parar sem provisionar.

### Gate B — isolamento obrigatório

O staging externo só pode existir quando houver:

- banco MySQL exclusivo;
- volumes de uploads e Redis exclusivos;
- credenciais exclusivas de staging;
- conteúdo sintético ou editorial revisado, sem usuários/PII copiados de produção;
- `WP_ENVIRONMENT_TYPE=staging`;
- `noindex` e bloqueio de indexação;
- SMTP em sink/inbox de teste;
- analytics desabilitado;
- Chatwoot, n8n acadêmico e integrações de certificado desabilitados;
- acesso ao app e API em estado `unavailable` até configuração deliberada.

Nunca reutilizar banco, volume, secrets ou domínio administrativo de produção.

### Gate C — evidência de backup antes de produção

Nenhuma promoção produtiva pode ocorrer sem evidência registrada de:

- dump MySQL íntegro e armazenado fora da VPS;
- backup verificável de uploads;
- captura do compose/configuração não secreta;
- SHA/tag do código anterior e do candidato;
- restauração do dump em ambiente isolado;
- comparação de integridade dos uploads restaurados;
- teste de rollback do código para o SHA anterior.

A existência do arquivo de backup, sozinha, não é aceite. A restauração precisa funcionar.

### Gate D — smoke de staging

O aceite mínimo do staging deve comprovar, em desktop e mobile:

- Home e páginas públicas sem erro fatal;
- `/privacy.html` e `/account-deletion.html` continuam públicas e coerentes;
- ausência de mixed content e links de staging publicados como produção;
- nenhum cadastro, matrícula, progresso, certificado ou fluxo acadêmico exposto pelo WordPress;
- nenhum dado pessoal em HTML, logs de teste ou analytics;
- ausência de conteúdo proveniente de `legacy-runtime`;
- navegação por teclado e foco básico;
- comportamento seguro quando API pública estiver indisponível.

### Gate E — autorização de produção

Somente após os Gates A–D:

1. apresentar SHA, evidências, backup e plano de rollback;
2. obter autorização humana explícita;
3. executar a menor alteração produtiva possível;
4. repetir smoke imediatamente após o deploy;
5. em regressão crítica, reverter o código primeiro; restaurar banco/uploads somente se a mudança realmente os afetou.

DNS, hospedagem, plugins, tema ativo e conteúdo jurídico continuam sendo gates humanos separados.

### Condições de parada

Parar e retornar ao P0 do app se surgir qualquer alteração que dependa de:

- regra de exclusão/retenção de dados pessoais;
- autenticação;
- certificado ou autoridade acadêmica;
- conteúdo jurídico que descreva comportamento ainda não estabilizado no app;
- nova coleta de dados ou integração que exija PII.

Parar e pedir autorização antes de qualquer ação em produção, DNS, Dokploy, secrets, domínio, plugin ou tema ativo.
