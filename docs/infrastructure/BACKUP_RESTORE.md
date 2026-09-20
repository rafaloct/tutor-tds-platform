# Backup e Restauração

## Estado auditado

Para os serviços legados não foi encontrada rotina local abrangente.
Backups/snapshots da Hostinger ainda precisam ser verificados no painel.

A API Tutor TDS publicada em 2026-09-20 possui:

- script `/opt/tutor-tds-api/ops/backup.sh`;
- execução diária às 03:20 UTC via `/etc/cron.d/tutor-tds-api-backup`;
- dump PostgreSQL gravado primeiro em arquivo temporário restrito e não vazio;
- compressão promovida atomicamente e validada por `gzip -t`, sem pipeline que
  possa mascarar falha do `pg_dump`;
- retenção local de 14 dias em diretório restrito.
- checksum SHA-256 para cada artefato;
- criptografia opcional e fail-closed com `age`/`BACKUP_AGE_RECIPIENT`;
- cópia externa opcional para volume montado em `BACKUP_OFFSITE_DIR`, validada
  byte a byte com `cmp`.

Restauração segura proposta em uma base vazia de staging:

```bash
gzip -dc tutor_tds_AAAAMMDDTHHMMSSZ.sql.gz |
  docker compose -f docker-compose.production.yml exec -T db \
  psql -U tutor_tds -d tutor_tds
```

Não executar esse comando contra produção sem janela, backup atual e
autorização, pois o dump contém `--clean`.

## Antes da Onda 1

1. Definir RPO e RTO para banco, certificados, RAG e configuração.
2. Criar dump consistente dos bancos e cópia versionada dos volumes essenciais.
3. Armazenar cópia fora da VPS.
4. Criptografar o backup e manter a chave fora do arquivo.
5. Executar restauração em staging e registrar tempo/resultado.

## Dados mínimos

- PostgreSQL/pgvector relacionado ao TDS.
- Volumes AnythingLLM e Weaviate usados pelo workspace `cartilhas`.
- Cloudflare Worker/configuração e exportação lógica dos certificados quando suportada.
- Google Sheets operacional.
- Configuração Dokploy e manifestos de deploy sem segredos.

Nenhum procedimento de restauração deve ser considerado pronto antes de um teste fora de produção.

O endurecimento do script está no repositório, mas só passa a proteger a rotina
remota depois de uma atualização operacional autorizada. A existência de um
arquivo `.sql.gz` ou de um cron ativo não substitui o restore drill.

## Variáveis operacionais do script

| Variável | Padrão | Finalidade |
|---|---:|---|
| `APP_DIR` | `/opt/tutor-tds-api` | diretório do compose |
| `BACKUP_DIR` | `$APP_DIR/backups` | retenção local |
| `BACKUP_RETENTION_DAYS` | `14` | expiração local |
| `BACKUP_AGE_RECIPIENT` | vazio | chave pública age; se informada, falha sem criptografar |
| `BACKUP_OFFSITE_DIR` | vazio | volume externo já montado; falha se indisponível |

Para restaurar `.age`, descriptografe somente no ambiente isolado de staging:

```bash
age -d -i /run/secrets/backup_age_identity tutor_tds_AAAAMMDDTHHMMSSZ.sql.gz.age |
  gzip -dc |
  docker compose -f docker-compose.staging.yml exec -T db-staging \
  psql -U tutor_tds_staging -d tutor_tds_staging
```

Intervenções ainda necessárias: escolher RPO/RTO, provisionar a chave age,
montar armazenamento externo e executar/registrar o primeiro restore drill.
Também é necessário instalar a versão endurecida do script na VPS em uma
janela autorizada; esta auditoria não modificou o host.
