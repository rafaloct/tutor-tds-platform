# Fluxo de Deploy

## Atual da API Tutor TDS

```text
testes locais --> cópia controlada para /opt/tutor-tds-api
  --> docker compose build --> migration Alembic --> health check
  --> smoke test externo --> backup lógico diário
```

O repositório contém o pipeline de imagem imutável e staging. Em 20/09/2026 foi
implantado também um staging manual e isolado em `/opt/tutor-tds-staging`, com
banco e API próprios. Migrations destrutivas continuam proibidas sem backup e
autorização. A automação por GitHub ainda depende da configuração externa da
branch, environment e secrets descrita abaixo.

## Alvo

```text
branch
  --> testes Flutter + Worker + API
  --> imagem imutável
  --> Dokploy staging
  --> migrations não destrutivas
  --> health/smoke tests
  --> aprovação
  --> promoção da mesma imagem para produção
  --> health check e rollback automático
```

Produção não deve receber migrations destrutivas nem alteração de rede sem backup e autorização.

## Staging reproduzível

`api/docker-compose.staging.yml` cria banco e API isolados, sem rota pública
implícita e sem compartilhar volume com produção. O sync worker pertence ao
profile explícito `sheets-sync` e fica desligado por padrão. A porta padrão é
ligada apenas em `127.0.0.1:8001`; o proxy/TLS deve ser criado no Dokploy com um
host de staging aprovado. Secrets de staging têm prefixo `STAGING_` e não podem
reutilizar os de produção.

Após o deploy, o gate mínimo é:

```bash
python ops/smoke_test.py https://HOST-STAGING/tutor-staging-api/
```

O deploy padrão usa `STAGING_SHEETS_SYNC_ENABLED=false` e não exige nenhuma
credencial Google. Nesse modo, somente banco e API sobem; um worker que tenha
ficado ativo em execução anterior é parado explicitamente.

Ainda é necessário criar a branch protegida `staging`, o environment GitHub de
mesmo nome e suas credenciais SSH/GHCR. Nenhum token foi criado ou presumido no
repositório.

Para teste físico sem novo DNS, somente a API pode entrar também na rede externa
do Traefik. Configure `STAGING_TRAEFIK_ENABLED=true`,
`STAGING_PUBLIC_HOST=ead.ipexdesenvolvimento.cloud` e
`STAGING_PUBLIC_PATH=/tutor-staging-api`. A regra tem prioridade 210 e faz
strip do prefixo, portanto não coincide com a produção em `/tutor-api`. Banco e
worker permanecem exclusivamente em `staging-internal`. O endpoint esperado é:

```text
https://ead.ipexdesenvolvimento.cloud/tutor-staging-api
```

Configure também
`STAGING_PUBLIC_API_BASE_URL=https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`.
Essa base explícita preserva o prefixo nas autorizações efêmeras de playback;
ela deve ser alterada junto com `STAGING_PUBLIC_HOST`/`STAGING_PUBLIC_PATH`.
O deploy falha fechado se a variável estiver ausente ou se a aplicação receber
uma base não HTTPS, com credenciais, query, fragmento ou segmentos relativos.

### Staging operacional validado em 20/09/2026

O deploy autorizado usa `STAGING_TRAEFIK_ENABLED=true` e está disponível em:

```text
https://ead.ipexdesenvolvimento.cloud/tutor-staging-api
```

Evidências da implantação:

- banco e API de staging em containers e volume/rede separados da produção;
- imagem corretiva `tutor-tds-api:staging-0014-evidence-fk-20260920`
  registrada em `.deployed-image`;
- migrations aplicadas até `20260920_0014 (head)`, revalidadas por
  `alembic current` somente leitura;
- `/health` externo com API `ok` e banco `available`;
- endpoints protegidos recusando requisições sem token com HTTP 401;
- smoke público de saúde/cursos aprovado;
- smoke autenticado de administrador, professor, monitor e aluno aprovado com
  uma turma visível por papel, tentativa de avaliação e mídia;
- worker Sheets ausente, como exige o padrão seguro;
- logging Docker `json-file` limitado a `20m` e cinco arquivos nos containers
  de staging;
- API de produção permaneceu saudável durante e após a implantação.

A implantação corretiva mais recente de 20/09/2026 manteve API e PostgreSQL de
staging `healthy`, banco sem porta publicada e head `0014`. A imagem em execução
e a tag apontam para `sha256:bbc6c2…e8a3d5`; a imagem anterior
`staging-0014-playback-prefix-20260920` permaneceu disponível para rollback.
`STAGING_PUBLIC_API_BASE_URL` foi
configurada no `.env` modo `0600`, sem exibir as demais variáveis.

O smoke integral de mídia passou criação/publicação sintética, autorização com
prefixo `/tutor-staging-api`, resolução 307 para o provider, rejeição de token
adulterado, eventos ordenados/idempotentes, rating, bloqueio/revogação,
histórico e arquivamento final. Não ficaram arquivos `.incoming` nem containers
one-off. Produção não foi alterada.

O smoke complementar `staging_media_gates_smoke.py` comprovou RBAC negativo,
trigger editorial append-only para UPDATE/DELETE, expiração controlada do grant,
Creator Score v2, retry idempotente e janela sobreposta. A mídia sintética foi
arquivada, o grant expirado removido e não houve linha de ledger. A confirmação
de mutação DB foi efêmera e não foi gravada no `.env`.

O script `api/ops/staging_role_smoke.py` executa o smoke autenticado usando as
credenciais sintéticas somente no host. Ele não imprime CPF, senhas ou token de
check-in. A configuração do seed permanece em
`/opt/tutor-tds-staging/.staging-seed.env`, modo `0600`.

O script `api/ops/staging_evidence_smoke.py` cria e encerra uma sessão sintética
descartável e valida no PostgreSQL real a ordem transacional evidência antes de
check-in, retry idempotente, rotação de token e saída. Na correção acima ele
obteve `201/200` para entrada, `200` na rotação, `201/200` para saída e relatório
final com dois registros; a conferência direta encontrou duas linhas de
`class_checkins` e duas evidências de presença. Ele não imprime credenciais nem
tokens. O reteste da mesma jornada no Android foi concluído depois do deploy:
Entrada e Saída foram confirmadas, a repetição semântica não criou nova linha e
o PostgreSQL terminou com um `checkin`, um `checkout` e duas evidências.

Para habilitar Sheets, configure `STAGING_SHEETS_SYNC_ENABLED=true` no `.env`
remoto e forneça `STAGING_GOOGLE_SHEET_ID`,
`STAGING_GOOGLE_SERVICE_ACCOUNT_JSON` e
`STAGING_SHEETS_PSEUDONYM_SECRET` com pelo menos 32 caracteres. O script valida
esses campos e só então inicia/aguarda o worker. Antes de habilitá-lo, validar em
staging os cenários de exclusão antes do sync, exclusão depois do sync e retry
de purge após falha transitória. Até essa homologação, Sheets permanece um gate
externo pendente, não uma integração simulada.

## CI/CD da API

O workflow `.github/workflows/tutor-api.yml` executa em pull requests e pushes
que alterem a API. O gate compila o Python, roda toda a suíte, valida os três
manifests Compose e constrói uma imagem marcada exclusivamente pelo SHA do
commit. Pushes publicam a imagem imutável no GHCR; somente a branch `staging`
aciona o job de deploy protegido pelo environment GitHub `staging`.
As actions oficiais usadas pelo workflow estão fixadas por SHA, evitando que
uma tag mutável altere o pipeline sem revisão.

O deploy usa apenas `ssh`/`scp` nativos, aguarda o PostgreSQL, aplica migrations
antes de trocar os serviços, exige health check e roda o smoke test. Ele confirma
o worker somente quando Sheets foi habilitado explicitamente. Falha em qualquer
gate restaura automaticamente a imagem anterior; no primeiro deploy malsucedido,
API e eventual worker são parados.
Migrations desta fase são aditivas; o rollback automático não executa downgrade
de banco. Produção não é alvo deste workflow.

Secrets obrigatórios no environment `staging`:

| Secret | Finalidade |
|---|---|
| `STAGING_SSH_HOST` | host da VPS |
| `STAGING_SSH_PORT` | porta SSH |
| `STAGING_SSH_USER` | usuário restrito de deploy, com acesso ao Docker |
| `STAGING_SSH_PRIVATE_KEY` | chave Ed25519 dedicada ao CI |
| `STAGING_SSH_KNOWN_HOSTS` | linha `known_hosts` conferida fora do workflow |
| `STAGING_DEPLOY_PATH` | diretório absoluto dedicado, nunca `/` |
| `STAGING_REGISTRY_USER` | usuário de leitura do GHCR |
| `STAGING_REGISTRY_TOKEN` | token GHCR somente `read:packages` |

Para automatizar o staging já operacional, criar no GitHub os secrets apontando
para o diretório existente. Em uma instalação nova, a intervenção inicial na
VPS é criar `STAGING_DEPLOY_PATH/.env` com as variáveis
`STAGING_*` de `api/staging.env.example`, preenchendo os campos obrigatórios
somente no host, com permissão restrita, rede externa `dokploy-network` e nenhum
secret no repositório. Recomenda-se exigir aprovação humana no environment
`staging`.
