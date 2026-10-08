# Observabilidade operacional — Issue #32

Estado: IMPLEMENTED candidato local, não monitor externo instalado. Base
`1a577a6e9417772753beb1525e25757f4e97b7ea`, 03/10/2026. Limiares abaixo são
TARGET de operação, não SLA. [Continuidade](../program/OPERATIONS_CONTINUITY.md)
define tiers; [interoperabilidade](../program/INTEROPERABILITY.md) define os dados
proibidos. Nenhum payload, CPF, nome, conversa, prompt, resposta ou segredo entra
nos snapshots. Não acrescentar endpoint público de métricas de infraestrutura.

## Evidência disponível

- OBSERVED no código: middleware [API](../../api/app/observability.py) registra
  rota-template, status e duração, sem body. Não comprova agregação/alerta instalado.
- OBSERVED: watchdog de backup da #2 executou externamente no GitHub Actions,
  [run 37123913929](https://github.com/rafaloct/tutor-tds-platform/actions/runs/37123913929),
  com health aprovado e e-mail SKIPPED. Não prova recebimento nem cobertura de todos
  os Tier 1. Reutilizar [automação existente](../../tooling/backup_automation/backup.mjs);
  este candidato não altera sua agenda, política ou transporte.
- Histórico: API produção `/health=200`, `/version=404`, documentado em
  [estado atual](../CURRENT_STATE.md). Não é observação runtime desta implementação.
- UNKNOWN: monitor externo de API/autenticação/Play, coletores host/DB, dashboard,
  métricas agregadas e instalação das demais regras. Não comprar SaaS nem configurar
  credenciais para preencher essa lacuna sem o gate de acesso.

## Matriz serviço → SLI/check

Cada amostra contém número e `observed_at` UTC; proporções de erros exigem também `sample_count` inteiro (mínimo 100, ou UNKNOWN). Ausência, timestamp futuro
ou observação com mais de 10 minutos é UNKNOWN, nunca sucesso. Idade de backup/sync
é calculada pelo coletor a partir do último sucesso, com observação fresca;
não confundir idade do evento com frescor da coleta. Timeouts devem virar
indisponibilidade no coletor, sem serializar exceção/URL/body.

| Serviço / tier | Check / condição candidata | Janela/coleta alvo | Severidade | Runbook / recuperação |
|---|---|---|---|---|
| API / 1 | api_http: HTTP diferente de 200; api_latency: >2000ms | sintético externo 1min; avaliar falha por amostra | SEV1 / SEV2 | [configuração](../program/CONFIGURATION_RUNBOOK.md): verificar rota/versão/dependências, restauração só com gate |
| API / 1 | api_5xx: proporção >5% | agregado 5min, mínimo100 requests; sem amostra suficiente UNKNOWN | SEV2 | configuração: correlacionar versão e logs sanitizados |
| PostgreSQL / 1 | postgres: available=0 | readiness interno 1min, sem SQL público | SEV1 | [backup/restore](../infrastructure/BACKUP_RESTORE.md): validar DB e recuperação isolada |
| Backup / 0 | backup: idade >26h | recibo diário consultado 5min | SEV1 | backup/restore e #2; semanal >8dias permanece no watchdog existente |
| VPS / 1 | disk: uso >85%; memory: uso >90% | agregado 5min via coletor autorizado | SEV2 | continuidade: investigar crescimento, sem apagar volumes/dados |
| TLS/DNS / 0 | tls: validade restante <14dias | monitor externo diário; snapshot da consulta precisa ser fresco | SEV2 | configuração: conferir domínio e renovação; sem mudar DNS automaticamente |
| WordPress / 2 | wordpress: HTTP diferente de 200 | público sintético externo 5min | SEV3 | #42/#47: rollback de artefato isolado; #48 preserva conteúdo para triagem |
| Chatwoot / 2 | chatwoot: HTTP diferente de 200 | health técnico 5min, sem abrir conversa | SEV3 | configuração: verificar serviço/inbox, não reenviar mensagens |
| Gateway / 2 | gateway: erros upstream >5% | agregado 5min, mínimo100 requests | SEV3 | configuração: flags/fallback, não produzir prompt de usuário |
| AnythingLLM / 2 | anythingllm: available=0 | health sem geração, 5min | SEV3 | configuração: upstream degradado não altera autorização |
| Sheets / 3 | sheets_sync: último sucesso >2h; queue: item mais antigo >1h | coletor interno 5min | SEV3 | interoperabilidade: revisar retry/idempotência; nunca corrigir cadastro na planilha |
| Media / 2 | media: available=0 | fake local agora; provider futuro 5min | SEV3 | #52/#31: provider indisponível, sem registrar URL assinada |
| Autenticação / 1 | fluxo sintético com conta dedicada | TARGET externo 5min; não implementado pelo avaliador | SEV1 | configuração: login indisponível sem nova conta real automática |
| App publicado / 1 | disponibilidade Play + versão/proveniência | TARGET externo diário + gates físicos | SEV2 | #3: app instalado não é provado por HTTP200 da loja |
| GitHub / 0 | CI e acesso ao repositório/custódia | TARGET externo; provedor independente | SEV2 | continuidade: segundo administrador e break-glass #36 |

O avaliador não calcula séries/percentis nem instala coletores. Cabe ao coletor
autorizado entregar agregados da janela declarada. Falta de coletor, ausência de
conta QA ou provider não implantado ficam UNKNOWN, sem inventar zeros.

## Roteamento, deduplicação e silêncio

Destinatário funcional de cada regra: plantão técnico para SEV1/SEV2; responsável
do serviço para SEV3, escalando ao plantão se afetar o núcleo. Nomes, canal e segundo
responsável são UNKNOWN até indicação institucional no inventário #26. Nenhum
envio é implementado aqui. O e-mail existente da #2 mantém autorização própria.

Chave de deduplicação: ambiente + check. O estado local gera `opened` uma vez,
`unchanged` nas repetições e `resolved` após uma observação saudável. Perda de
telemetria conserva incidente aberto; nunca gera recovery falso. O adaptador de
entrega futuro deve persistir estado atomicamente e confirmar recibo antes de
promover notificação para enviada. O JSON emitido não é comprovante de entrega.

Silêncio TARGET para todas as regras: manutenção aprovada com responsável,
motivo, ambiente, checks e expiração (máximo2h), preservando coleta e histórico;
sem silêncio automático de SEV1 ou de monitor desconhecido. O avaliador não
suprime alertas. Configuração de silêncio/roteamento pertence ao monitor externo
após gate; recuperação deve fechar a mesma chave, mantendo registro do incidente.

## Uso local e contrato sanitizado

Requer Python3 com biblioteca padrão. O avaliador `evaluate.py` não acessa rede nem variáveis de ambiente; o runner sintético acessa somente os endpoints HTTPS declarados no manifesto.

```powershell
python -m unittest discover -s tools/observability -p 'test_*.py' -v
python tools/observability/evaluate.py snapshot.json
python tools/observability/evaluate.py snapshot.json --previous previous.json
python tools/observability/synthetic_runner.py manifest.json
```

O runner Tier 1 local/versionado está em
[synthetic_runner.py](../../tools/observability/synthetic_runner.py), com exemplo
de contrato em
[synthetic_manifest.example.json](../../tools/observability/synthetic_manifest.example.json).
O manifesto aceita somente HTTPS sem credenciais, query, fragmento ou headers
customizados; a sonda usa apenas GET, não segue redirect, não usa proxy de ambiente
e limita o corpo lido a 64 KiB. O exemplo usa `example.invalid` de propósito e não
é um alvo para smoke real. Copiar o contrato somente para endpoints explicitamente
autorizados.

Cada serviço gera checks sanitizados de reachability, status HTTP, latência e
validade TLS. `health_json` e `content_allowlist` são opcionais e só verificam
chaves/marcadores estáticos não sensíveis; nenhum valor de resposta, URL, exceção,
token, cookie ou header é serializado. Saída contém apenas `service_id`,
`check_id`, `PASS/FAIL/UNKNOWN`, `observed_at`, `safe_reason` categórica e
`latency_ms` quando disponível. Timeout, TLS inválido, HTTP inesperado, JSON
malformado e conteúdo ausente falham de forma fechada. Os testes unitários injetam
probes locais/mock e não abrem rede real.

Exemplo parcial: demais checks retornam UNKNOWN por ausência deliberada.

```json
{"environment":"local","checks":{"api_http":{"value":500,"observed_at":"2026-10-03T16:00:00Z"}}}
```

IDs permitidos são fixos em [evaluate.py](../../tools/observability/evaluate.py).
Estado anterior é o objeto `next_state` da execução anterior, não o output inteiro.
Ambientes não podem compartilhar estado. Saída possui enums fixos, sem valores,
URLs ou campos livres da entrada. Campos extras são rejeitados. Exit0 significa
todos os checks saudáveis; exit1 indica firing/unknown; exit2 entrada inválida.
Mesmo exit0 não atesta integridade da fonte: o coletor deve ter custódia/autorização
própria. Executar com snapshots confiáveis, sem PII, e guardar estado por ambiente.

## Aceite e gates restantes

- Matriz e avaliador local cobrem falha500, atraso backup/sync, dedup e recuperação.
- Runner sintético local cobre reachability HTTPS, status, latência, JSON de health,
  validade TLS e conteúdo mínimo allowlisted, com saída sanitizada e fail-closed.
- Runner e avaliador permanecem IMPLEMENTED e TESTED-LOCAL neste candidato. A
  evidência A19 abaixo acrescenta TESTED-STAGING somente ao recorte público e
  read-only executado no SHA exato do PR #88; não valida o SHA convergido atual,
  checks autenticados/internos, alert routing ou monitor recorrente.
- Rollback local: remover o uso do runner/avaliador; nenhum serviço, workflow,
  agenda, destino de alerta ou regra remota foi alterado nesta reconciliação.

## Consolidação seletiva do PR #88 — evidência de 05/10/2026

Esta seção preserva a matriz consolidada no PR #88 sem substituir fatos mais
recentes de `CURRENT_STATE.md` nem promover o candidato atual. Os papéis de owner
são TARGET do [SERVICE_REGISTRY](SERVICE_REGISTRY.md); owners nominais continuam
UNKNOWN até registro institucional.

### Evidência OBSERVED e limites

- FastAPI: GET `/live` prova processo; GET `/health` executa `SELECT 1` no
  PostgreSQL; GET `/version` consulta `alembic_version` e retorna identidade
  sanitizada. A existência desses contratos no código não substitui o fato
  histórico de que produção respondeu `/version=404` na observação de 02/10.
- Cloudflare gateway: existe GET `/health` no Worker versionado. Esse check prova
  somente Worker/edge e não prova AnythingLLM, workspace, modelo ou provider.
- Sync Sheets: GET `/admin/sync/status` exige papel admin e retorna `pending`,
  `processing`, `synced`, `failed`, `exhausted`, `last_success_at` e
  `last_failure_at`. A idade do item mais antigo da fila ainda não é exposta.
- Backup: `tooling/backup_automation/backup.mjs` valida recibos offsite e
  classifica backup diário com mais de 26h como problema. A rotina pertence à
  Issue #2 e não é alterada pelo PR #88.
- Monitor fora da VPS: `tds-vps-watchdog.yml` roda em runner hospedado pelo
  GitHub, consulta o health público da API e está agendado duas vezes por hora.
  Alertas por e-mail dependem de configuração SMTP protegida. O PR #85 altera
  essa frente; o PR #88 não deve editar o workflow.
- PR #88 A19: smoke read-only real contra staging em `/health` e `/version`,
  HEAD `1f59f74812be012ea4e8514c0090f152fba68843`. HTTPS, health, version,
  latência, TLS e sanitização passaram sem credencial, escrita, deploy, alerta
  ou mutação. Essa prova pertence somente àquele SHA e àquele recorte.
- Não foi encontrado health automatizado canônico versionado do AnythingLLM,
  health dedicado do WordPress, health dedicado do Chatwoot ou health de provider
  de mídia. Esses checks permanecem UNKNOWN em vez de receber endpoints inventados.

### Matriz serviço → check → SLI → condição → severidade → owner → runbook → recovery

| Serviço / tier | Check e SLI | Condição / janela TARGET | Severidade | Owner funcional TARGET | Runbook | Recovery |
|---|---|---|---|---|---|---|
| FastAPI / 1 | `/health`: disponibilidade + DB indireto; `/version`: identidade/schema; latência HTTPS; 5xx agregado quando houver coletor | `/health` diferente de 200; latência acima de 2000ms; `/version` inválido; 5xx acima de 5% em 5min somente com pelo menos 100 requests | SEV1 health; SEV2 latência/version/5xx | Técnico + infra | [CONFIGURATION_RUNBOOK](../program/CONFIGURATION_RUNBOOK.md) | Isolar API versus DB; reimplantar somente artefato/config aprovado; restore apenas em gate próprio |
| PostgreSQL / 1 | `/health` como conectividade indireta; internamente `SELECT 1`, revision, storage/conexões | indisponível em 1min interno; revision incompatível no gate de release; storage sem coletor fica UNKNOWN | SEV1 | Infra + dados | [BACKUP_RESTORE](../infrastructure/BACKUP_RESTORE.md) | Recuperação isolada, integridade/schema e depois smoke da API |
| Backup / 0 | idade do recibo offsite, integridade e execução; semanal Dokploy quando aplicável | diário acima de 26h; semanal acima de 8 dias | SEV1 | Infra | [BACKUP_RESTORE](../infrastructure/BACKUP_RESTORE.md) + Issue #2 | Reexecutar fluxo autorizado e confirmar objeto/recibo; restore drill é prova separada |
| VPS host / 1 | disk/memory internos; queda total inferida externamente pelos endpoints públicos | disk acima de 85% ou memory acima de 90% por 5min; perda do endpoint público conforme política Tier 1 | SEV2 recurso; SEV1 queda total | Infra | [OPERATIONS_CONTINUITY](../program/OPERATIONS_CONTINUITY.md) | Investigar consumo/processos; nunca apagar volumes ou dados automaticamente |
| DNS/TLS / 0 | resolução, handshake HTTPS e dias restantes | resolução/handshake falha; validade abaixo de 14 dias | SEV1 indisponibilidade; SEV2 expiração | Infra | [SERVICE_SETUP_GUIDES](../program/SERVICE_SETUP_GUIDES.md) | Conferir DNS/renovação e owner; nenhuma alteração automática de zona |
| WordPress / 2 | Home pública e `/wp-json/` podem ser sintéticos sem login; não existe health dedicado versionado | HTTP diferente de 200 ou TLS inválido após URL canônica aprovada | SEV3 | Editorial + infra | [WP1_STAGING_ROLLBACK_PLAN](../portal/WP1_STAGING_ROLLBACK_PLAN.md) | Verificar runtime/cache/DB; rollback de tema/plugin/conteúdo conforme escopo |
| Chatwoot / 2 | URL/check público canônico UNKNOWN; workers/WebSocket/SMTP/storage são checks internos | não automatizar condição até mapear endpoint e topologia reais | UNKNOWN até check aprovado; impacto tende a SEV3 | Suporte + infra | [CHATWOOT_TDS_CURRENT_STATE](../production/CHATWOOT_TDS_CURRENT_STATE.md) + [SERVICE_SETUP_GUIDES](../program/SERVICE_SETUP_GUIDES.md) | Diagnosticar serviço/inbox/workers sem reenviar mensagens; restore específico pertence ao DR |
| Cloudflare gateway / 2 | GET `/health`: Worker/edge, latência e TLS | health diferente de 200 ou TLS inválido; upstream precisa de métrica separada | SEV3 | Infra + técnico | [SERVICE_SETUP_GUIDES](../program/SERVICE_SETUP_GUIDES.md) | Verificar Worker/bindings/config; degradação da IA não altera autorização acadêmica |
| AnythingLLM / 2 | health automatizado canônico não encontrado | UNKNOWN até check técnico autorizado sem prompt real | UNKNOWN | Técnico | [SERVICE_SETUP_GUIDES](../program/SERVICE_SETUP_GUIDES.md) | Verificar container/workspace/provider; reindexar masters aprovados quando aplicável |
| Sync Sheets / 3 | `/admin/sync/status`: contagens, exhausted, último sucesso/falha | `last_success_at` acima de 2h é TARGET quando sync habilitado; `exhausted` maior que 0 requer triagem; queue oldest acima de 1h ainda sem check direto | SEV3 | Dados + técnico | [INTEROPERABILITY](../program/INTEROPERABILITY.md) | Revisar retry/idempotência/origem; nunca corrigir fonte mestre na planilha |
| Mídia / 2 | `/media` prova API/metadados, não provider; não existe provider health dedicado e provider real ainda não é canônico | UNKNOWN até provider/target autorizado existir | UNKNOWN; SEV3 quando provider operacional | Editorial + técnico | [MEDIA_PLATFORM](../architecture/MEDIA_PLATFORM.md) | Fail-closed/fallback; trocar provider via adapter sem mudar autoridade da API |

### Fronteira de acesso dos checks

| Serviço | Público sem secret | Interno | Exige secret | Fora da VPS | Check/gap ainda inadequado |
|---|---|---|---|---|---|
| FastAPI | SIM: `/health`, `/version`, `/live` | SIM para 5xx/host | NÃO nos públicos | SIM, obrigatório para queda total | agregação 5xx/host não instalada nesta frente |
| PostgreSQL | somente indireto via `/health` | SIM: conexão/revision/storage | SIM para check direto | SIM via sinal público indireto | sem coletor interno versionado nesta issue |
| Backup | NÃO há endpoint público | SIM: recibos/offsite/runtime | SIM para storage/alerta | SIM | monitor offsite ampliado e alert routing não instalados |
| VPS host | somente efeito nos endpoints públicos | SIM: disk/memory/processos | SIM para acesso host | SIM | coletor host não instalado |
| DNS/TLS | SIM | NÃO para check básico | NÃO | SIM | owner/inventário nominal UNKNOWN |
| WordPress | SIM: Home e `/wp-json/` | SIM para DB/cache/plugin | SIM para administração | SIM | sem health dedicado; staging WP é frente própria |
| Chatwoot | UNKNOWN até URL/check canônico | SIM: workers/WebSocket/SMTP/storage | SIM para API/admin | SIM quando check público seguro existir | endpoint e topologia real a homologar |
| Gateway | SIM: `/health` após URL autorizada | SIM para métricas/bindings | NÃO no health; SIM para upstream | SIM | health não prova AnythingLLM/upstream |
| AnythingLLM | NÃO comprovado | SIM | SIM para API/workspace/provider | desejável após check definido | sem health automatizado canônico |
| Sync Sheets | NÃO: status é admin | SIM via `/admin/sync/status` ou DB | SIM: auth/admin e integração | opcional; Tier 3 não bloqueia núcleo | queue oldest age não exposta |
| Mídia | API pública não prova provider | SIM para config/provider/grants | depende do provider | SIM quando provider existir | provider/URL/check real UNKNOWN |

### Decisão técnica do monitor externo

`EXTERNAL_MONITOR_MINIMUM=runner fora da VPS executando GET HTTPS sanitizado de Tier 1 e registrando falha sem depender do host monitorado`

`CANDIDATE_LOCATION=GitHub-hosted Actions runner, reaproveitando o padrão existente do tds-vps-watchdog`

`CHECK_FREQUENCY=TARGET 5min para Tier 1; watchdog atual observado em aproximadamente 30min; qualquer mudança de agenda exige gate próprio`

`ALERT_DESTINATION_ROLE=plantão técnico/infra para SEV1-SEV2; owner funcional para SEV3; nomes e canal institucional permanecem UNKNOWN`

`SECRETS_REQUIRED=NÃO para probes públicos; SIM para entrega SMTP atual e checks internos/autenticados`

`COST_REQUIRED=UNKNOWN; nenhuma compra de SaaS ou premissa de cota/custo GitHub/SMTP é autorizada`

`FAILURE_IF_VPS_DOWN=SIM para checks públicos porque o runner GitHub permanece fora da VPS; GitHub, DNS e Internet continuam dependências externas`

`MONITOR_INSTALLATION_PERFORMED=NO`

Transformar o runner em monitor recorrente, mudar frequência, aprovar destino de
alerta, cadastrar secrets ou assumir custo depende de decisão externa.
`HUMAN_GATE=SIM`. O monitor ampliado, alert routing e dashboard continuam fora
desta execução. O PR #88 não deve alterar o PR #85 nem instalar qualquer monitor.

#32 permanece aberta até monitor externo Tier 1, responsáveis/destinos aprovados
e prova controlada de indisponibilidade sintética, sem derrubar produção. Registrar
SHA/config, timestamps e recibos sanitizados; não repetir restores da #2.
