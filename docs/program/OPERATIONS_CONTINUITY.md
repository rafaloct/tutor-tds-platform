# Operação, continuidade e recuperação

## 1. Objetivo

Manter serviço e conhecimento após falha técnica, troca de equipe, perda de credencial ou indisponibilidade de fornecedor.

## 2. Inventário mínimo operacional

Para cada serviço:
- nome;
- finalidade;
- URL/host;
- ambiente;
- owner;
- segundo admin;
- dependências;
- onde configura;
- versão;
- backup;
- monitor;
- custo/renovação;
- procedimento de recuperação;
- data da última verificação.

## 3. Serviços críticos

### Tier 0
GitHub, domínio/DNS, credenciais institucionais, backup e chave de recuperação.

### Tier 1
PostgreSQL, FastAPI, autenticação, app publicado.

### Tier 2
Chatwoot, WordPress, gateway/IA, certificado, media delivery.

### Tier 3
Sheets/BI, analytics auxiliares, automações não essenciais.

Falha Tier 3 não pode impedir estudo básico se o núcleo está saudável.

## 4. Backup

Issue #2 é a frente vigente para PostgreSQL/Dokploy e não deve ser duplicada.

Estado documentado no repo inclui política TDS diária com retenção e cópia Dokploy semanal; aceite total depende de alertas/custódia/restore conforme issue.

O programa ainda precisa inventariar:
- WordPress DB + `wp-content`;
- configuração Chatwoot e anexos;
- KV/certificados quando aplicável;
- configuração gateway;
- artefatos editoriais;
- manifests de mídia;
- documentos críticos do Drive.

## 5. Restore

Backup sem restore é hipótese.

Todo domínio crítico deve ter ensaio:
1. ambiente isolado;
2. versão do software registrada;
3. restore;
4. verificação de integridade;
5. smoke test;
6. evidência;
7. tempo real medido;
8. limpeza do ambiente de ensaio.

Nunca testar restauração destrutiva em produção.

## 6. Objetivos candidatos

Os valores abaixo são metas operacionais, não SLA até aprovação:

| Serviço | RPO candidato | RTO candidato |
|---|---:|---:|
| PostgreSQL | 24h ou melhor | 4h |
| WordPress | 24h | 8h |
| Chatwoot | 24h | 8h |
| metadados de mídia | 24h | 8h |
| BI/Sheets | reconstruível da origem quando possível | 24h |

A coordenação/infra deve aprovar valores finais.

## 7. Monitoramento

Mínimo:
- API health/readiness/version;
- DB connectivity/storage;
- backup age;
- cert expiration;
- disk/memory;
- HTTP 5xx;
- queue age;
- sync Sheets;
- Chatwoot/WordPress availability;
- provider de mídia;
- gateway/AnythingLLM;
- DNS/TLS expiry.

Alertas precisam sair da mesma VPS quando monitoram falha total da VPS.

## 8. Incidentes

Severidades:
- SEV1: perda/risco de dado, indisponibilidade total, segurança.
- SEV2: função central degradada.
- SEV3: função auxiliar ou grupo restrito.
- SEV4: bug sem impacto operacional imediato.

Registro:
- início;
- impacto;
- ambiente;
- versão;
- sintomas;
- ações;
- decisão;
- recuperação;
- causa;
- prevenção;
- links de evidência.

## 9. Change management

Janela de produção deve conter:
- versão/tag;
- migrations;
- config delta;
- backup status;
- deploy owner;
- rollback;
- smoke test;
- monitor pós-deploy;
- critério de abort.

## 10. Renovação e custos

Inventariar itens com expiração/limite:
- domínio;
- VPS;
- storage/R2;
- Cloudflare;
- Play Console;
- e-mail/Workspace;
- media provider;
- Chatwoot se pago;
- SSL se não automatizado;
- IA/model provider.

Registrar centro responsável, não cartão/senha no repo.

## 11. Bus factor

Para cada operação crítica deve existir:
- documento;
- pelo menos dois responsáveis capazes;
- conta institucional;
- procedimento testado.

## 12. Desligamento de serviço

Antes de remover fornecedor:
- exportar dados;
- validar formato;
- migrar referências;
- atualizar clientes;
- preservar redirects/IDs públicos;
- testar rollback;
- revogar credenciais depois;
- registrar decisão.

## 13. Continuidade do portal e app

Portal deve mostrar status/contato mesmo se IA falhar. App deve continuar com conteúdo/cache permitido quando API auxiliar falhar. Falha de BI nunca deve bloquear o aluno.

## 14. Revisões periódicas

Mensal:
- backups/alerts/space/health.

Trimestral:
- acessos e owners;
- restore amostral;
- dependências;
- plugins;
- custos;
- matriz de risco.

Antes de cada release:
- runbook e preflight específicos.
