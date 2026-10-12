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
`PGDMP` do dump. A identidade age precisa ser arquivo regular do usuário
atual, sem permissão de grupo/outros (`chmod 600`). O dump descriptografado
fica em memória; não se escreve dump, identidade nem secret nos relatórios.
O processo age e o Docker recebem os bytes por stdin; erros de subprocessos
não imprimem argumentos ou stderr. O operador deve manter os três arquivos de
entrada em diretório privado e remover as cópias temporárias após a revisão.

## Pré-requisitos

- Host POSIX com `python3`, `git`, `age` e Docker locais.
- Imagem `postgres:16-alpine` já presente no Docker local; o runner usa
  `--pull=never`.
- Checkout candidato com `api/` limpa e com uma única head Alembic versionada.
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

Com os arquivos de entrada já obtidos e sob custódia do operador:

```sh
python3 tooling/rehearse_scheduled_postgres_backup.py \
  --execute \
  --receipt /caminho/privado/receipt.json \
  --archive /caminho/privado/archive.dump.age \
  --identity /caminho/privado/age-identity \
  --candidate-root /caminho/do/checkout-candidato \
  --output-dir /caminho/privado/relatorios \
  --tmpfs-mib 1024
```

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
