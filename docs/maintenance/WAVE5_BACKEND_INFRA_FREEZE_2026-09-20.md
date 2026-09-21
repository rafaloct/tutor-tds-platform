# Freeze Onda 5 — Backend e Infraestrutura

Data da fotografia: 2026-09-20
Escopo: API, migrations, manifests, scripts operacionais e documentação.
Decisão: **NO-GO para promoção a produção/Play; GO somente para continuar QA em staging.**

## Limites da auditoria

A inspeção remota foi somente leitura, pelos endpoints HTTPS públicos e pelo
alias SSH `tutor-tds-vps`. Via SSH foram consultados somente `.deployed-image`,
estado do Compose, identidade da imagem, `alembic current` e health local. Não
houve leitura de `.env`/secrets/dados de usuário, deploy, restart, migration ou
alteração de produção/staging. Cron, conteúdo dos volumes e backups não são
inferidos como comprovados apenas porque `/health` responde.

O código local e o staging contêm migrations até `20260920_0014`. Após a
correção transacional do Evidence, `.deployed-image` apontava a imagem corretiva
`tutor-tds-api:staging-0014-certificate-seed-20260920`, o container usava o mesmo
digest `sha256:65a550…521d08` e `alembic current` retornou
`20260920_0014 (head)` sobre PostgreSQL. Seed idempotente, smoke público/quatro
papéis, conteúdo de avaliação cross-device e o smoke integral de mídia possuem
evidência operacional registrada. O smoke adicional do Evidence aprovou
entrada/saída, retries, rotação e relatório, com duas linhas FK-coerentes de
check-in e duas de evidência.

## Evidência observada

| Área | Estado | Evidência | Limite / risco residual |
|---|---|---|---|
| Produção pública | Parcial | `GET https://ead.ipexdesenvolvimento.cloud/tutor-api/health` retornou HTTP 200 e `{"status":"ok","database":"available"}` em 20/09/2026 | A resposta não trouxe `X-Request-ID`, sinal de que a imagem publicada está atrás do snapshot local de observabilidade. Não prova revision/migration head |
| Staging | Comprovado no recorte | HTTPS retornou API/banco disponíveis; container API `healthy`; imagem `staging-0014-certificate-seed-20260920`, digest `sha256:65a550…521d08`; seed/smokes por papel, assessment, mídia, Evidence e elegibilidade/isolamento de certificado registrados | Não substitui restore, carga, emissor de certificado, jornadas Android completas nem garante que futuras mudanças locais estejam nessa imagem |
| Segregação | Implementada e revalidada | Banco remoto estava apenas em `staging-internal`, sem porta publicada; API em `staging-internal` + `dokploy-network`, porta host apenas `127.0.0.1:8001`; prefixo `/tutor-staging-api` e prioridade 210 | Confirmar periodicamente no host que nomes/volumes reais continuam distintos |
| Migrations | Comprovada em staging | `alembic current` remoto retornou `20260920_0014 (head)`; cadeia local aditiva tem testes de upgrade/downgrade, FKs, constraints, triggers e inserts reais | Backup atual e promoção controlada antes de produção; migrations futuras exigem nova prova |
| Liveness/readiness | Corrigida localmente | `/live` não depende de PostgreSQL; `/health` mantém `SELECT 1`; ambos têm request ID no snapshot | Publicar apenas no próximo deploy normal e configurar orquestrador conscientemente; nada foi reiniciado nesta auditoria |
| Backup | Corrigido localmente, não comprovado remoto | Script passou a separar `pg_dump` da compressão, exigir dump não vazio, promover arquivo temporário e falhar fechado na criptografia | Instalar script no host, definir RPO/RTO, criptografia/offsite e executar restore drill isolado |
| Restore | Pendente externo | Procedimento documentado para base vazia de staging | Não existe evidência de restauração concluída, tempo medido ou integridade funcional pós-restore |
| Logs | Implementado | Logs HTTP JSON incluem request ID, template da rota, status e duração; Docker limita cada serviço a 20 MB × 5 arquivos | Sem agregador, métricas, alertas, dashboards, tracing, SLO ou retenção central comprovados |
| Analytics | Funcional, capacidade não aceita | Eventos tipados/idempotentes e RBAC por vínculo; projeções de mídia e horas possuem testes | Agregação de uso ainda percorre eventos na aplicação; requer plano de índice/agregação e ensaio de carga antes de escala |
| Sheets | Seguro por padrão em staging | Worker staging fica atrás do profile `sheets-sync`; pseudônimos HMAC, tombstones e purge têm testes | Credenciais reais, planilha dedicada e teste de append/retry/purge/reconcile são externos; não habilitar antes disso |
| Mídia/vídeo | Implementada no contrato | Abstração YouTube privacy-enhanced, Cloudflare Stream e HLS HTTPS; Drive só master; playback restrito usa grant opaco curto e revalida matrícula | Escolher provedor, quotas, CDN, signing real, retenção, direitos e canais institucionais; nenhuma credencial foi inventada |
| Segurança/LGPD | Parcial avançada | CPF por HMAC, Argon2id, refresh rotativo, payloads fechados, RBAC por vínculo, exclusão/purge, CORS explícito e respostas sem PII desnecessária | Rate limit/WAF, análise de imagem/dependências, teste de penetração, Data Safety e políticas humanas continuam gates |
| Comercial | Seguro por padrão | Ledger somente simulado, append-only e com origem auditável; `PAYMENT_ADAPTER=disabled` | Aprovação jurídica, tributária e comercial antes de qualquer integração/pagamento |
| DeepSeek | Ausente do produto | Busca no código/configuração encontrou apenas documentação que o proíbe; nenhum provider/model DeepSeek é configurado para Tutor TDS | A VPS compartilhada pode manter modelos de outros sistemas; confirmar allowlist efetiva do gateway Tutor sem remover ativos compartilhados |
| CI/CD | Pronto no repositório, não comprovado operacionalmente | CI testa API/Compose, publica imagem por SHA e deploya somente branch `staging`, com health/smoke/rollback; Compose produtivo aceita uma `PRODUCTION_API_IMAGE` única para API/worker | Configurar branch/environment/secrets no GitHub e ensaiar. Promoção produtiva por digest ainda é manual e exige aprovação |
| Supply chain/runtime | Parcial | Secrets não são versionados e actions oficiais estão fixadas por SHA | Imagens base estão por tag, não digest; container API usa usuário root. Endurecer e validar compatibilidade em uma onda controlada |
| Escala | Não aceita | Serviços são stateless onde aplicável e PostgreSQL/worker estão isolados | Sem load test, orçamento de conexões, múltiplas réplicas, pooling, filas externas, autoscaling ou teste de falha |

O preflight de promoção 1.4 confirmou produção em `0005` e staging em `0014`,
com 41 operações adicionais no candidato e 26 delas chamadas pelo AAB. A imagem
produtiva atual não possui marker/tag durável de rollback e a imagem manual de
staging não possui proveniência por commit; a promoção permanece NO-GO até
congelar/reconstruir um digest e executar o runbook documentado.

## Correções seguras deste freeze

1. O backup não usa mais `pg_dump | gzip` sob `sh`: o status do dump é
   verificado antes da compressão, o temporário é limpo por `trap` e a retenção
   aceita somente inteiro positivo.
2. Com `BACKUP_AGE_RECIPIENT`, a ausência/falha de `age` impede manter uma cópia
   em claro.
3. `GET /live` foi adicionado como liveness sem banco. `GET /health` continua
   sendo readiness compatível e consulta PostgreSQL.
4. Testes de regressão fixam os contratos acima.

Essas mudanças existem apenas no workspace e não autorizam publicação.

## Validação local do snapshot

- `pytest -q`: **59 testes aprovados**;
- migration tests incluídos na suíte: upgrade/downgrade, constraints e inserts;
- `compileall`: aplicação e testes compilados;
- `bash -n`: `backup.sh` e `deploy_staging.sh` válidos;
- workflow GitHub carregado por parser YAML;
- `docker compose config`: local, produção, staging padrão e staging com profile
  `sheets-sync` válidos usando somente placeholders de validação.

A validação inicial do manifest de produção sem placeholders recusou a
configuração pela ausência de Sheets. Isso é fail-closed, mas também confirma
que produção ainda acopla a subida do conjunto às credenciais do worker. Não
houve conexão Google nem persistência desses valores sintéticos.

## Gates externos obrigatórios

1. Congelar um commit candidato e repetir a suíte no mesmo SHA da imagem.
2. Criar backup verificado e produzir uma imagem candidata imutável que inclua
   também as correções locais posteriores à imagem corretiva de staging; provar sua origem
   por commit/digest antes de qualquer promoção.
3. Repetir os smokes já aprovados no candidato e completar mídia restrita com
   provider real e os recortes ainda abertos da matriz no Xiaomi. Entrada,
   duplicidade segura e Saída do Evidence já passaram fisicamente.
4. Instalar o backup endurecido, provisionar `age` e offsite, escolher RPO/RTO
   e restaurar em banco isolado, registrando duração e validações funcionais.
5. Homologar Sheets em staging com conta/planilha exclusivas, incluindo
   exclusão antes/depois do sync e retry de purge.
6. Definir provedor de vídeo/armazenamento, direitos, quotas, política de
   retenção e mecanismo de entrega assinada. Drive continua fora do playback.
7. Implantar agregação de logs/métricas/alertas, limites de taxa e SLOs; executar
   teste de carga com volume esperado e registrar capacidade/limites.
8. Configurar protections/environments/secrets do CI e ensaiar rollback. Definir
   promoção da mesma imagem por SHA para produção, com aprovação humana.
9. Verificar a allowlist do gateway de IA: DeepSeek permanece proibido para o
   Tutor TDS; qualquer modelo instalado para outra aplicação compartilhada não
   deve ficar selecionável por este produto.
10. Manter pagamentos desabilitados até decisões jurídicas/comerciais formais.

## Critério de saída

O backend/infra só pode sair do freeze para release quando migrations, restore,
observabilidade, integrações externas e capacidade tiverem evidência no ambiente
correto. Até lá, um HTTP 200 é sinal de disponibilidade pontual, não aceite de
produção em escala.
