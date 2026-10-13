# Ensaio isolado do backup PostgreSQL agendado

## Escopo e custódia

`tooling/rehearse_scheduled_postgres_backup.py` é um runner **opt-in** para
restaurar um objeto `archive.dump.age` do fluxo agendado
`postgres/scheduled/v1/` em PostgreSQL 16 descartável. Ele recebe um
`receipt.json`, o objeto criptografado e a identidade age **já fornecidos
localmente pelo operador**. O runner não consulta R2, VPS nem produção. Antes
de usá-lo como evidência, o operador deve atestar fora do runner a custódia do
download do bucket privado `tds-backups`, a identidade do objeto e do recibo,
e que o par veio da mesma execução agendada. Um hash coincidente com um recibo
local, sozinho, não autentica a origem remota.

O runner verifica formato e campos exatos do recibo nativo, hash SHA-256 e
tamanho do objeto criptografado, cabeçalho age, decriptação e assinatura
`PGDMP` do dump. A identidade age precisa ser arquivo regular do operador,
sem permissão de grupo/outros (`chmod 600`). Sob `sudo`, o runner exige dono
igual ao `SUDO_UID` confirmado pelo `SUDO_USER` local; não copie nem altere o
dono da chave para root. Ele abre a identidade uma vez, sem seguir symlink, e
passa o descritor aberto ao age. O dump descriptografado
fica em memória; não se escreve dump, identidade nem secret nos relatórios.
O processo age e o Docker recebem os bytes por stdin; erros de subprocessos
não imprimem argumentos ou stderr. O operador deve manter os três arquivos de
entrada em diretório privado e remover as cópias temporárias após a revisão.

## Pré-requisitos

- Host POSIX com `/proc/self/fd` ou `/dev/fd`, `python3`, `git`, `age` e Docker
  locais. Se o socket Docker exigir privilégio, execute a CLI com `sudo --`;
  não use `sudo -E` nem preencha `SUDO_UID`/`SUDO_USER` manualmente.
- Sob `sudo`, instale tanto o runner revisado quanto o executável age como
  arquivos root-owned em diretórios sem escrita para outros usuários. O runner
  rejeita um binário age do home do operador ao executar como root.
- Imagem `postgres:16-alpine` já presente no Docker local; o runner usa
  `--pull=never`.
- Checkout candidato de propriedade do mesmo operador que invocou `sudo`,
  com `api/` limpa e uma única head Alembic versionada. As leituras Git usam
  `safe.directory` somente para esse caminho, sem alterar configuração global.
- Diretório de saída privado, já criado. Cada execução cria uma subpasta
  `0700`; os três JSON são `0600`.
- Capacidade de memória: container limitado a 2 GiB; tmpfs do banco entre
  256 e 1536 MiB, padrão 1024 MiB. Dumps descriptografados acima de
  **64 MiB** ou objetos criptografados acima de 64 MiB + 64 KiB falham
  fechado. Se o backup real ultrapassar o limite, o runner precisa de revisão
  de recursos e novo teste antes do ensaio; não reduza o arquivo.

O alvo Docker é criado com nome aleatório, `--network none`, sem porta
publicada ou diretório host montado. O caminho de dados do PostgreSQL é
explicitamente tmpfs; o runner confere essa configuração e o filesystem em
execução para impedir que o `VOLUME` declarado pela imagem crie um volume
anônimo persistente. Após êxito ou falha de `pg_restore`, remove somente o
container criado, mediante conferência de ID e labels. Esse runner não aplica
migração nem acessa banco de produção.
Se o daemon Docker ficar indisponível durante a limpeza, conferir depois
`docker ps -a --filter label=tds.purpose=scheduled-offsite-restore` e remover
somente o container cujo `tds.run` corresponda à execução; a falha não gera
manifesto de aceite.

## Execução supervisionada

No terminal do container Dokploy, o operador pode localizar o ID e horário do
último recibo local sem abrir configuração ou credenciais:

```sh
node -e 'const r=require("/etc/dokploy/tds-backup-ops/last-success.json"); console.log(r.id, r.completedAt, r.status)'
```

Esse apontador local não substitui a conferência do recibo e objeto no R2
privado. Com os arquivos de entrada já obtidos e sob custódia do operador, no
host de ensaio com socket Docker restrito:

```sh
cd /caminho/do/checkout-candidato
git rev-parse HEAD  # conferir com o commit revisado
sudo install -D -o root -g root -m 0755 tooling/rehearse_scheduled_postgres_backup.py /usr/local/libexec/tds/rehearse_scheduled_postgres_backup.py
expected_script_sha=$(git show HEAD:tooling/rehearse_scheduled_postgres_backup.py | sha256sum | cut -d' ' -f1)
printf '%s  %s\n' "$expected_script_sha" /usr/local/libexec/tds/rehearse_scheduled_postgres_backup.py | sha256sum -c -
sudo install -o root -g root -m 0755 /home/rafael/.cache/tds-restore-tools/age-v1.3.2 /usr/local/bin/age
printf '%s  %s\n' eb7dd1b518f0a307c99cd97782623c5321da049154b04acd2d98d21aa7bc9b2c /usr/local/bin/age | sha256sum -c -
sudo -- python3 /usr/local/libexec/tds/rehearse_scheduled_postgres_backup.py \
  --execute \
  --receipt /caminho/privado/receipt.json \
  --archive /caminho/privado/archive.dump.age \
  --identity /caminho/privado/age-identity \
  --candidate-root /caminho/do/checkout-candidato \
  --output-dir /caminho/privado/relatorios \
  --age-bin /usr/local/bin/age \
  --tmpfs-mib 1024
```

Os JSON de saída ficam na subpasta `0700` criada por root; o operador pode
revisá-los com `sudo` e só copiar o conteúdo sanitizado após essa revisão.

Sem `--execute`, a CLI falha antes de decriptar ou criar container. A saída
`RESTORE_VERIFIED_PENDING_UPGRADE` aponta o manifesto `recovery-run-*.json`.
Esse manifesto inclui referência e SHA-256 para o relatório de offsite e o
relatório **parcial** PostgreSQL, a revision candidata e o OID da árvore
`HEAD:api`. O relatório PostgreSQL registra a revision observada no dump e o
ID da imagem isolada; ele tem `status=restore_verified_pending_upgrade` e
**não** satisfaz o gate 12 completo. A saída de sucesso comprova apenas que
o dump fornecido pôde ser restaurado no PostgreSQL 16 descartável e que as
tabelas centrais e uma revision Alembic foram encontradas.

Para fechar o gate 12, ainda é necessário ensaio separado e versionado que
aplique migrações até a revision candidata no banco restaurado, teste a imagem
anterior contra o banco atualizado, compare catálogo, colunas e OpenAPI com
produção e AAB publicado, e faça a revisão dos volumes críticos. A evidência
de upgrade deve citar o mesmo `source_backup.receipt_id`, `object_key` e
`plaintext_sha256` deste ensaio. O aceite final e os hashes precisam ser
revisados por humano e copiados para `docs/production/evidence/` apenas após
sanitização. O último recibo agendado com menos de 26 horas continua sendo
uma verificação operacional separada na janela de promoção.

## Testes sem dados produtivos

```sh
python3 -m unittest tooling/test_rehearse_scheduled_postgres_backup.py -v
TDS_RUN_DOCKER_RESTORE_TESTS=1 python3 -m unittest \
  tooling.test_rehearse_scheduled_postgres_backup.ScheduledPostgresDrillTests.test_docker_restore_is_networkless_tmpfs_and_cleans_on_success_or_failure -v
```

O segundo teste constrói um dump sintético numa instância PostgreSQL 16
descartável e verifica restore, tmpfs e limpeza após sucesso e erro. Ele não
usa age real, R2, VPS nem dados produtivos.

## Ensaio completo do mesmo objeto offsite — Issue #202

`tooling/rehearse_scheduled_postgres_upgrade.py` fecha a lacuna entre o restore
parcial acima e o ensaio histórico `api/ops/rehearse_production_upgrade.py`,
que sempre obtém um dump novo ao vivo. O companheiro usa o mesmo recibo e
objeto age já baixados: decripta em memória, restaura, toma o fingerprint das
colunas existentes **do banco restaurado**, migra e compara esse fingerprint.
Não exige que um backup de horas atrás corresponda ao estado atual da produção.
Separadamente, registra antes/depois os IDs dos containers produtivos, sua
revision e os fingerprints de suas colunas, sempre via SQL com
`default_transaction_read_only=on`; qualquer mudança durante o ensaio faz o
ensaio falhar. Só solicita Id, Image, state e labels ao Docker produtivo,
sem carregar `Config.Env`.
Escritas normais de usuários durante o intervalo também mudam fingerprints;
programar o ensaio em intervalo operacional sem escrita para que essa
comparação rigorosa seja significativa. Falha dessa comparação não autoriza
restaurar nem sobrescrever a produção.

O candidato deve estar congelado e com `api/` limpa. A imagem é inspecionada
antes da execução e todos os containers usam seu digest observado; labels
`revision` e `version` precisam coincidir com o HEAD Git completo, `source`
com o repositório Tutor TDS e `created` com `git show -s --format=%cI HEAD`.
Os JSON associam a árvore `HEAD:api`, a head Alembic e esse digest. Alterar
`api/` depois invalida a evidência; alterar somente documentação fora de
`api/` preserva a identidade da árvore (a imagem continua vinculada ao commit
do ensaio, que deve constar no registro da promoção).

O banco usa PostgreSQL 16 em tmpfs, sem volume/bind/porta; a rede é `--internal`.
Containers de migration, API candidata e imagem anterior têm nome aleatório,
labels de proprietário, credenciais sintéticas e limites de recursos. O
companheiro controla e remove também o migrator, mesmo após timeout; ele não
usa a URL/DSN produtiva no clone. Nenhum `pg_dump` novo é executado. Imagem
anterior precisa iniciar contra o banco atualizado, `/health` precisa indicar
banco disponível, nenhuma rota legada ou exigida pelo AAB pode desaparecer e
o catálogo precisa preservar valores, tipos e ordem legados. Schemas OpenAPI
alterados e suas definições antes/depois são listados para revisão; presença
de rotas, sozinha, não comprova compatibilidade semântica de todos os campos.
Além dos labels OCI, o runner compara os bytes e o bit executável de todos
os arquivos materializados de `app/`, `migrations/`, `alembic.ini`,
`pyproject.toml` e `uv.lock` com os blobs de `HEAD`. Um container descartável
nunca iniciado fornece os arquivos via `docker cp`; arquivos extras, ausentes,
alterados e links falham fechado. Essa prova cobre os fontes copiados pelo
Dockerfile atual, não uma attestation de toda a cadeia de dependências da imagem.
Antes/depois da migração, tipos, nullability, defaults, collation,
identity/generated, constraints e índices existentes precisam ser iguais.
Adições em tabelas antigas também precisam aceitar campos omitidos pelo cliente
legado: defaults não nulos, checks satisfeitos pelos defaults, FKs MATCH SIMPLE
com nova chave nullable e unicidade NULLS DISTINCT com nova chave nullable.
As adições e os deltas OpenAPI ainda ficam sujeitos à revisão semântica final.

O comando precisa de acesso Docker local no VPS onde existem
`tutor-tds-api-api-1` e `tutor-tds-api-db-1`; esse acesso é usado apenas para
inspeção e leitura da produção. O Avellaria não é requisito. A identidade
age pode ser uma nova identidade custodiada fora da VPS, com cópia temporária
0600 para o ensaio, desde que o novo objeto agendado tenha sido criptografado
para sua chave pública. Uma identidade nova não recupera objetos antigos.
Preservar a configuração/chave pública antiga e todos os backups antigos;
o produtor `backup.mjs` suporta apenas um `recipient`. Se um novo backup for
gerado por esse produtor, revisar a troca da chave pública e impedir que a
execução de retenção apague objetos anteriores (`retentionEnabled=false`
durante essa operação). Configuração do produtor nunca recebe chave privada.

Instalar **ambos** os scripts revisados como root-owned no mesmo diretório e
conferir seus hashes contra o commit antes de invocar com sudo:

```sh
set -eu
reviewed_runner_commit=$(git rev-parse HEAD)
printf '%s\n' "$reviewed_runner_commit"  # conferir com o commit revisado
for runner_script in rehearse_scheduled_postgres_backup.py rehearse_scheduled_postgres_upgrade.py; do
  git cat-file -e "$reviewed_runner_commit:tooling/$runner_script"
  expected_runner_sha=$(git show "$reviewed_runner_commit:tooling/$runner_script" | sha256sum | cut -d' ' -f1)
  printf '%s  %s\n' "$expected_runner_sha" "tooling/$runner_script" | sha256sum -c -
  sudo install -D -o root -g root -m 0755 \
    "tooling/$runner_script" "/usr/local/libexec/tds/$runner_script"
  printf '%s  %s\n' "$expected_runner_sha" "/usr/local/libexec/tds/$runner_script" | sha256sum -c -
done
sudo -- python3 /usr/local/libexec/tds/rehearse_scheduled_postgres_upgrade.py \
  --execute \
  --receipt /caminho/privado/receipt.json \
  --archive /caminho/privado/archive.dump.age \
  --identity /caminho/privado/age-identity \
  --candidate-root /caminho/do/checkout-candidato \
  --candidate-image tutor-tds-candidate:COMMIT_CURTO \
  --output-dir /caminho/privado/relatorios \
  --age-bin /usr/local/bin/age
```

Depois de uma promoção, passar `--rollback-image sha256:...` com o digest
imutável comprovado da imagem produtiva anterior. Sem essa opção, o runner
testa a imagem da produção observada no início do ensaio. O relatório separa
`production_image_id` de `rollback_image_id`, sem reescrever a identidade atual.

Saída de sucesso:
`OFFSITE_POSTGRES_UPGRADE=COMPATIBILITY_VERIFIED_PENDING_REVIEW; manifest=...`.
A subpasta privada contém `scheduled-postgres-offsite-*.json`,
`postgres-upgrade-*.json` e `recovery-run-*.json`. O manifesto fornece os hashes
dos quatro gates PostgreSQL/offsite, com restore/upgrade/schema apontando para
um único relatório. Ele **não** gera aceite final nem declara promoção.
Após revisar recibo remoto, custódia dos inputs, deltas OpenAPI e volume
crítico, copiar somente os JSON sanitizados para `docs/production/evidence/`.
O aceite final precisa dos cinco booleans verdadeiros, schema/tree do
manifesto e mapa de evidências `{file, sha256}` dos cinco gates. Acrescentar
`critical_volumes_restore` com o hash do drill real revisado; não usar um
recibo PostgreSQL para sustentar o volume AnythingLLM. O relatório Track B de
06/10 está dentro de 30 dias em 13/10; só pode ser reutilizado após conferência
de custódia/escopo, sem inventar restauração nova ou acesso à chave perdida.

```sh
python3 tooling/verify_production_recovery_evidence.py \
  --acceptance docs/production/evidence/production-restore-acceptance.json \
  --evidence-dir docs/production/evidence \
  --expected-schema 20261007_0030 \
  --expected-api-tree ARVORE_GIT_API_CONFERIDA
python3 -m unittest tooling.test_rehearse_scheduled_postgres_upgrade \
  tooling.test_rehearse_scheduled_postgres_backup \
  tooling.test_verify_production_recovery_evidence -q
```

Se o comando falhar, nenhum manifesto de aceite é produzido. Conferir os
recursos `docker ps -a --filter label=tds.purpose=scheduled-offsite-upgrade`
e redes com o mesmo label; remover somente os IDs/labels daquele run quando
uma falha de comunicação impedir a limpeza automática. A suíte sintética
valida gates negativos, apagamento do buffer, isolamento e vínculo de prova;
a execução real sobre R2/produção ainda precisa de seu próprio registro.
