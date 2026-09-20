# Backup e Restauração

## Estado auditado

Para os serviços legados não foi encontrada rotina local abrangente.
Backups/snapshots da Hostinger ainda precisam ser verificados no painel.

A API Tutor TDS publicada em 2026-09-20 possui:

- script `/opt/tutor-tds-api/ops/backup.sh`;
- execução diária às 03:20 UTC via `/etc/cron.d/tutor-tds-api-backup`;
- dump PostgreSQL comprimido, validado por `gzip -t`;
- retenção local de 14 dias em diretório restrito.

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
