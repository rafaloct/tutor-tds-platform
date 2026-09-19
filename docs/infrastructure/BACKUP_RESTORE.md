# Backup e Restauração

## Estado auditado

Não foi encontrada rotina local de backup dos dados da aplicação. `/var/backups` contém apenas metadados do sistema. Backups/snapshots da Hostinger ainda precisam ser verificados no painel.

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
