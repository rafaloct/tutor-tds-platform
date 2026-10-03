# Runbook de configuração por ambiente

Este documento lista **ordem, dependências e nomes**, nunca valores secretos.

## 1. Ordem de implantação de um ambiente novo

1. definir owner e finalidade;
2. criar DNS/hosts;
3. criar rede/serviços base;
4. PostgreSQL;
5. FastAPI;
6. migrations;
7. storage/mídia;
8. gateway/IA/certificado;
9. Chatwoot;
10. WordPress/portal;
11. sync/Sheets/BI;
12. observabilidade;
13. backup/restore;
14. configurar app;
15. smoke tests;
16. registrar inventário e versões.

Não configurar app antes de existir endpoint canônico e TLS válido.

## 2. Categorias de configuração

### Flutter build
- `TUTOR_API_URL`
- `TUTOR_GATEWAY_URL`
- `PRIVACY_POLICY_URL`
- `ACCOUNT_DELETION_URL`
- feature flags aprovadas

Build de produção deve recusar localhost, staging e flags experimentais.

### FastAPI
- `DATABASE_URL`
- `PUBLIC_API_BASE_URL`
- `JWT_SECRET`
- `CPF_PEPPER`
- token lifetimes
- flags do domínio
- integrações Sheets/mídia/certificado quando habilitadas

### PostgreSQL
- usuário dedicado;
- senha secret;
- volume persistente;
- backup;
- network privada;
- sem porta pública salvo necessidade justificada;
- timezone/encoding padrão documentados.

### Sheets
- ID por ambiente;
- range exclusivo;
- service account com menor privilégio;
- `SHEETS_PSEUDONYM_SECRET` distinto por ambiente;
- worker desligado até validar schema.

### Gateway/IA
- upstream URL;
- API key secret;
- workspace;
- signing secret de certificado;
- allowed origins;
- rate limits/timeout.

### Mídia
- provider;
- delivery base;
- credencial admin somente servidor;
- bucket/prefixo por ambiente;
- CORS restrito;
- lifecycle/retention;
- master Drive institucional.

### Chatwoot
- URL/account/inbox por ambiente;
- website token público somente se apropriado;
- token administrativo somente backend;
- identidade assinada server-side;
- webhook secret/verificação conforme versão real;
- times/inboxes/competências definidos.

### WordPress
- URL pública;
- DB próprio;
- admin institucional;
- theme/plugin versions;
- SMTP se necessário;
- backup;
- API base pública do Tutor TDS;
- analytics ID sem PII.

### Backup R2/S3
- endpoint/account;
- bucket;
- access key/secret no secret store;
- chave de criptografia com custódia separada;
- prefixos fixos;
- retenção;
- teste de restore.

## 3. Naming recomendado

```text
tutor-tds-{service}-{environment}
```

Exemplos lógicos:
`tutor-tds-api-staging`, `tutor-tds-db-production`.

Não renomear recurso real existente apenas para alinhar estética.

## 4. Separação de ambiente

Obrigatório separar:
- database;
- JWT/peppers;
- buckets/prefixos;
- Sheets;
- Chatwoot inbox/account quando necessário;
- analytics;
- service accounts;
- feature flags;
- certificados/test data.

## 5. Secret handling

- nunca em Git;
- nunca em issue/PR;
- nunca em screenshot;
- nunca echo/log;
- nunca no bundle Flutter/JS;
- rotacionar após suspeita;
- documentar nome, owner e local de custódia, não valor;
- preferir secret store do runtime;
- arquivos temporários com permissão restrita e remoção segura.

## 6. Smoke test por serviço

### API
`/health`, `/version`, DB disponível, revision esperada.

### PostgreSQL
connect interno, migration current, leitura/escrita sintética.

### WordPress
home, REST de posts, login editorial, publicação draft em staging.

### Chatwoot
conta sintética, conversa, resposta, logout/troca de usuário.

### Mídia
asset sintético, grant, expiração, revogação.

### Sheets
sentinela sintético, readback, idempotência.

### Backup
objeto criado, download, decrypt autorizado e restore isolado.

## 7. Configuração de DNS

Toda mudança deve registrar:
- hostname;
- tipo de record;
- target;
- TTL;
- owner;
- serviço correspondente;
- data;
- rollback.

Automação existente `setup_dns_hostinger.sh` é referência histórica e requer revisão antes de executar. Não rodar automaticamente.

## 8. Checklist de novo responsável

A pessoa deve saber localizar:
- repo;
- runbooks;
- painel Dokploy;
- domínio/DNS;
- contas Cloudflare/R2;
- Google Workspace;
- WordPress;
- Chatwoot;
- Play Console;
- backup e chave;
- dashboard/alertas;
- responsáveis humanos.

Se um item só existe “na cabeça de alguém”, a configuração não está concluída.
