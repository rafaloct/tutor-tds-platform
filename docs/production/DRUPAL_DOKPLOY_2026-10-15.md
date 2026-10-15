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
staging207e2128. `drupal/Dockerfile.production`, lock Composer preservado,
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

TESTED-LOCAL:43 checks PHP8.3/Drupal11.4.8, estrutura Compose e sintaxe Node PASS;
revisão independente sem blocker confirmado. CI via gh bloqueado por GraphQL403;
isto não é CI verde. PR211 permanece draft.

Login acadêmico desativado por gate server-side; catálogo público usa somente
/public/courses da API produtiva. IA/Chatwoot e PRs180/181/191/207/209 não ativados
nem incorporados por suposição. Nenhuma migração central ou chave Tutor alterada.

UNKNOWN: DNS/HTTPS público, instalação final, backup/restore e smoke serão
registrados após execução. Wrangler desktop autenticado mas somente zone:read,
sem DNS Edit. DNS do novo hostname ainda ausente na inspeção inicial.

## Rollback

Retirar somente a rota nova do portal e parar web da aplicação; preservar DB e
volumes. Nunca docker system prune, down -v ou recriar projetos existentes.
Em futuras mudanças de schema, voltar imagem sozinho não reverte dados/config:
restaurar o conjunto compatível em ambiente isolado antes do corte.
