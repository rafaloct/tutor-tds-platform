# Drupal no Dokploy — execução de 2026-10-15 / #210

## Decisão e fronteiras

DECISION: usuário autorizou configurar produção pelo acesso Tailscale existente,
gerar/custodiar credenciais no Dokploy e construir a imagem no VPS. Confirmou
`portal.ipexdesenvolvimento.cloud`. Esta autorização substitui os gates históricos
somente neste recorte; merge continua reservado a Rafael.

OBSERVED: srv1533541 acessível por SSH com host key verificada em 100.90.91.35;
Dokploy0.29.1, Traefik3.6.7, rede `dokploy-network`. Não existe rede Docker chamada
`tailscale-network`: Tailscale é o caminho administrativo. API produção saudável;
nenhum container Drupal anterior. Disco259GB livres, RAM disponível~17GB.

## Artefato e configuração

Fonte da imagem inicial: `27ec28857332dfe97d9cf2710c7e280c2ce10fb3`, base
staging207e2128. `drupal/Dockerfile.production`, lock Composer posteriormente corrigido para11.4.10,
`--no-dev`; bases fixadas por digest. Pacotes APT continuam dependentes do
repositório Debian no instante do build. Imagem construída no próprio VPS,
referenciada pelo image ID SHA256 real, `pull_policy: never`.

`drupal/production/compose.yml`: DB exclusivo em rede interna, volumes distintos
para banco, uploads e private fora do webroot; nenhum PostgreSQL Tutor acessado.
Web com2CPUs/1536MB, DB1CPU/1024MB, logs limitados. Porta de inspeção
127.0.0.1:18088. Somente web integra rede do Traefik.

Configuração no painel Environment da aplicação `Portal Drupal` no projeto
`cartilhas-tds`, ambiente `production`. Credenciais geradas por randomBytes no
servidor: DRUPAL_DB_PASSWORD, DRUPAL_DB_ROOT_PASSWORD, DRUPAL_HASH_SALT e
DRUPAL_ADMIN_PASSWORD. Usuário editorial `editorial_admin`; senha administrativa
não entra no ambiente permanente do web. Nenhum valor em chat/Git/log.

`register-dokploy.mjs` usa a camada de serviços da versão instalada do Dokploy.
Reexecução não substitui valores existentes. Antes de subir, conferir internamente
registro, compose e env completos: criação parcial exige reparo controlado.
Arquivos materializados têm diretório0700 e `.env`0600. O Dokploy mantém os valores
no seu banco e materializa `.env`; isto não é um cofre externo nem Docker Secrets.
Quem administra o painel/root pode acessar os valores.

`bootstrap-dokploy.mjs` lê a custódia internamente, valida service/image ID e passa
somente usuário/senha por stdin para `install-from-stdin.php`. Instalação recusa DB
não vazio; saída Drush é descartada porque contém URL de login. Settings original
restaurado ao terminar; verificar hash antes de abrir acesso público.

## Alterações posteriores

- Editar endpoints/hosts/proxy no painel, salvar e fazer deploy apenas desta aplicação.
- DB password: editar env sozinho não muda senha de banco já inicializado. Rotacionar
  usuário MariaDB de forma coordenada, verificar conexão e então atualizar/redeploy web.
- Admin password: editar custódia sozinho não muda hash Drupal. Usar comando controlado
  dentro do container, passando segredo por stdin, atualizar custódia e testar login.
- Salt: rotação deliberada pode invalidar links/sessões; não fazer em cada deploy.
- Imagem: construir candidato, testar e substituir DRUPAL_IMAGE_REF pelo ID real.
  Preservar imagem anterior e backup conjunto DB/files/config antes de upgrade.
- Proxy: endereço observado10.0.1.203; rever se Traefik for recriado com outro IP.

## Gates

TESTED:43 checks PHP8.3/Drupal11.4.10 na imagem do VPS, estrutura Compose e sintaxe Node PASS;
revisão independente sem blocker confirmado. CI via gh bloqueado por GraphQL403;
isto não é CI verde. PR211 permanece draft.

Login acadêmico desativado por gate server-side; catálogo público usa somente
/public/courses da API produtiva. IA/Chatwoot e PRs180/181/191/207/209 não ativados
nem incorporados por suposição. Nenhuma migração central ou chave Tutor alterada.

BLOCKED: DNS/HTTPS público. Wrangler desktop autenticado mas somente zone:read,
sem DNS Edit. DNS do novo hostname ainda ausente na inspeção inicial.

## Rollback

Retirar somente a rota nova do portal e parar web da aplicação; preservar DB e
volumes. Nunca docker system prune, down -v ou recriar projetos existentes.
Em futuras mudanças de schema, voltar imagem sozinho não reverte dados/config:
restaurar o conjunto compatível em ambiente isolado antes do corte.

### Diagnóstico do runner no VPS

OBSERVED: duas chamadas do teste standalone falharam antes dos checks por argumento
1 ausente e depois diretório em vez de arquivo. EXPECTED: carregar Composer e
executar43 checks. RESPONSIBLE BOUNDARY: invocação operacional, não runtime Drupal.
EVIDENCE: production-settings.php:4 recebe `require $argv[1]`.
LIKELY ROOT CAUSE: argumento do script não conferido antes da chamada.
AFFECTED FILE: scripts/tests/production-settings.php (sem alteração necessária).
STRUCTURAL FIX: comando explícito `php scripts/tests/production-settings.php
/var/www/html/vendor/autoload.php`; nenhuma recriação de serviço para esse erro.

## Correção de segurança observada durante implantação

Composer audit no VPS identificou SA-CORE-2026-014 (RCE crítica),015/016 (XSS),
publicadas14/10/2026 e corrigidas em11.4.10. O container web foi parado, sem
rota pública, e o candidato11.4.8 não foi aceito. Resolver oficial no VPS atualizou
core/core-recommended/dev/scaffold e transitivas; nova resolução sem advisories.
Build produtivo agora executa `composer audit --no-dev --locked` como gate.
Novo candidato: fonte215689c72c312187d506635aaffedc36e918f6f2.

O checkout privado(umask077) também expôs uma falha de permissões de fonte600.
O Dockerfile agora normaliza fonte antes do Composer(umask022) e testa leitura
como www-data. Uma tentativa de camada recursiva posterior foi cancelada por
ter sido superada pelo patch; nenhum serviço preexistente foi recriado.

OBSERVED: bootstrap inicial concluído; hash do settings idêntico ao Git após
instalação e ownership dos volumes conferido. Backup inicial age/R2 verificado:
`drupal/portal-production/v1/7349dbce-5419-42db-bbef-f95edcae2cea/archive.tar.age`,
1.352.200bytes, SHA2560dc131758fd9fff8bf08ccc04dd5528a074ccf2eaae6ad8c9667093de14a6048.
Cópia viva files não atômica; isto ainda não comprova restore/descriptografia.
Dokploy composeIdS0GkbE7Ll5mh1JqX_Q75v/appName tds-drupal-production-jad5fx.
Domínio cadastrado no painel(domainIdOZuCL65fUoqmcG0g2yAXk), sem deploy de rota
ou solicitação de certificado.

## Recibo final da origem isolada

- Imagem ativa: `sha256:68881b7d753aeddaa1399867dd71b761b776407529129b444f493a94704a2db0`,
  fonte215689c72c312187d506635aaffedc36e918f6f2, Drupal11.4.10. Auditoria Composer
  sem advisories. Não reverter ao candidato11.4.8 vulnerável.
- Referência do painel, `.env`, registration e imagem executada conferidas iguais.
  `updatedb`/`updatedb:status`: sem atualização pendente; cache rebuild PASS.
- 43 checks runtime como www-data +17 checks HTTP de origem PASS. Host inválido400;
  install.php/update.php403; sessão acadêmica403/no-store; health production/up.
- Chrome no LARGeo via túnel SSH temporário carregou /cursos e9 links de cursos;
  cliente público state=fresh,count=9. Screenshot inspecionada. Túnel encerrado.
  Aparência é o tema base atual; isto não comprova paridade visual ou conteúdo editorial completo.
- Backup atualizado16:24:52UTC: `drupal/portal-production/v1/1d1e6ae6-c3c2-40fe-bf3e-b203ac62e0f8/archive.tar.age`,
  4.681.016bytes, SHA256`39e0a6d51738a447a6fb825fc8d7ab9b82ffc5211cbbfcda0a2ee15f2c55c6b4`.
  Upload/download criptografado conferido. Identidade age privada não acessada;
  não há comprovação de descriptografia desse objeto offsite.
- Cron `/etc/cron.d/tds-drupal-portal-backup`: diariamente04:40UTC; serviço cron
  ativo. Runner com flock, saídas sanitizadas e recibos last-result/last-success
  em `/etc/dokploy/tds-drupal-ops/`. Primeiro disparo agendado ainda não observado.
  Limites atuais16MiB por componente/64MiB agregado; exceder falha sem backup parcial aceito.
  Cópia de arquivos vivos não é atômica; sem alerta externo configurado.

## Intervenção DNS e próximo gate

Reason: hostname sem registro e OAuth Wrangler com zone:read, sem DNS Edit.
Exact human action: na zona Cloudflare `ipexdesenvolvimento.cloud`, criar registro
A `portal` → `46.202.150.132` (DNS only para o primeiro teste de origem), ou indicar
custódia autorizada de token com Zone/DNS/Edit apenas nessa zona; não enviar chave
no chat. What remains unblocked: origem instalada/testável, catálogo público,
backup e preparação do domínio no Dokploy. Após resolver DNS, ativar somente a
rota desse compose, emitir certificado e repetir smoke externo HTTPS, redirects,
cache/cookies. Sem aceite público ou E2E autenticado nesta execução. SMTP,
publicação editorial real, IA e Chatwoot continuam sem validação de produção.

## Recuperação isolada executada

OBSERVED: `restore-smoke.py --run`, fonte14d1ab2, retornou
LIVE_COPY_RESTORE_VERIFIED:55 tabelas/961 registros/35 arquivos conferidos;
health production/up e home200. API upstream desativada no clone; nenhuma porta
publicada. Banco/arquivos de destino em tmpfs, rede interna exclusiva, limpeza
restrita aos recursos UUID do ensaio. Produção não recebeu import/restore.

Primeiro ensaio passou comparação do banco/arquivos e cache rebuild, mas falhou
no HTTP via porta publicada de uma rede exclusivamente interna. Hipótese de
fronteira de rede: não atribuir a falha ao Drupal sem evidência. Correção14d1ab2
consulta Apache por loopback dentro do próprio clone, mantém isolamento e
acrescenta diagnóstico sanitizado;4 testes focais PASS. Segundo ensaio PASS.
Isto comprova restauração de cópia viva; não descriptografia do objeto R2.
