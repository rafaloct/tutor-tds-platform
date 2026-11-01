# Auditoria integrada — EAD APIs + frente comercial (2026-10-31)
Execução read-only sobre diagnóstico do Antigravity (BPM Designer). Sem alterações em produção.

## OBSERVED (comprovado em código/serviço)

### Rotas `tds/v1` — mu-plugin `tds-lms-core` no EAD
| Rota | Auth | Avaliação |
|---|---|---|
| `/courses` | X-API-Key (`TDS_API_KEY`, hash_equals) | OK — comparação constant-time |
| `/enroll` | X-API-Key | OK |
| `/progress/{user_id}` (+/{course}) | X-API-Key | OK chave, MAS: quem detém a chave enumera progresso de qualquer user_id — sem escopo por usuário |
| `/certificate/{user_id}/{course}` | X-API-Key | idem — enumeração de certificados via API key única |
| `/user-by-phone/{phone}` | X-API-Key | endpoint de enumeração de usuários — recomenda rate-limit + minimização de resposta |
| `/verify/{hash}` | público (`__return_true`) | correto — verificação pública de certificado |
| `/mp-subscription-callback` | `__return_true` NA ROTA, mas handler revalida `TDS_API_KEY` + valida vínculo order↔user + whitelist de ações (authorized/cancelled/paused) | funcional; fraquezas: segredo estático único, sem anti-replay/timestamp, estado em user_meta (`_tds_subscription_active`) fora do núcleo transacional |

### Comercial já implementado (staging → produção)
- Woo + Mercado Pago produção ativo; fulfillment WhatsApp verificado e2e (`order.updated`→n8n→PB→`sent`)
- PB `deliveries`/`delivery_events` com dedup único; `tds/v1/order-status` probe com secret
- Curso LP 1801 "PRISMA Assistido por IA" publicado no EAD (R$29,90, 1 seção/1 aula, autor TDS)
- Produto Woo 93 → `_fulfillment_url` = URL do curso EAD

### Divergência de fonte de verdade (risco)
- `wordpress/tds-portal-core` (repo) vs `wp-content/mu-plugins/tds-lms-core` (EAD) — duas implementações de LMS REST coexistindo; `.bak-c04-20261030` indica edição direta em produção
- Vário mu-plugins ptbr/editorial/tutor-guide no EAD NÃO versionados no repo

## TARGET (arquitetura desejada — Antigravity + contratos)
- Identidade única app↔EAD; progresso só pelo resolver canônico (cohort-enrollment-v2)
- Certificado: autoridade única (lifecycle GENERATED→...→VALID com papéis)
- Comercial: estados rastreáveis RASCUNHO→...→CONCLUÍDO; assinatura e produto unificados numa tabela de pedidos — não user_meta
- Segredo rotativo + timestamp/anti-replay nos callbacks de pagamento

## UNKNOWN/BLOCKED
- `TDS_API_KEY` definido onde (wp-config?) — rotatividade/gestão de segredo por revisar
- Se `tds-learning/v1/*` ainda é servido (rota vista no índice público) e por qual plugin
- Se catálogo app (9 eixos) ↔ 9 cursos EAD estão mapeados 1:1 — comparação pendente
- Telas Flutter: ficha Play OK; árvore de telas internas não auditada
- Governança comercial/IP: quem autoriza vender o que (decisão humana pendente)

## Backlog priorizado
- P0: mover `permission_callback` do callback MP para a guarda na rota (defesa em profundidade, não só no handler) + adicionar timestamp/anti-replay
- P0: documentar e rotacionar `TDS_API_KEY`; restringir `/user-by-phone` e `/progress` (escopo/limit)
- P0: reconciliar `tds-portal-core`↔`tds-lms-core` — declarar um único dono das rotas tds/v1; versionar mu-plugins no repo
- P0: mapa app↔EAD dos 9 cursos + divergência 5 trilhas/9 cursos no copy público
- P1: pedidos/assinatura como entidade própria (hoje `_tds_subscription_active` em user_meta)
- P1: curso LP 1801 → `Comprar Agora` redirecionar para `?add-to-cart=93` (ponte LP→Woo)

## Execução P0 (2026-10-31)
- [x] `mp-subscription-callback`: guarda movida para a rota — POST sem key agora **403 ao vivo** (verificado `{"code":"forbidden"}`); handler mantém checagem interna (defesa em profundidade). Backup `.bak-guard-20261031`.
- [x] `TDS_API_KEY`: hardcoded em `mu-plugins/tds-lms-core-loader.php` (produção, arquivo editável). Recomendação: mover para env do container + rotacionar (ficou exposta em sessões/editor).
- [x] Mapa catálogo EAD: **12 cursos** — núcleo das 9 cartilhas completo (1298,1307,1314,1321,1328,1335,1343,1356,1474) + IA Inclusão Digital (614,616) + IA Processos (1709) + PRISMA (1801, novo comercial).
- [x] Divergência 5-trilhas/9-cursos confirmada: trilhas agrupam cartilhas — copy precisa tornar a relação explícita.

## Pendente P0
- Rotacionar `TDS_API_KEY` para env (hoje hardcoded no loader mu-plugin de produção)
- Restringir escopo de `/user-by-phone` e `/progress` (por usuário autenticado ou rate-limit)
- Versionar os mu-plugins EAD no repo (hoje vivem só no container)

## P0 — minimização de PII (2026-10-31)
- [x] `/user-by-phone` endurecido: resposta padrão devolve só `found`+`user_id` (email/display_name exigem flag `?internal=1`); acesso logado via error_log. Produção patcheada + sincronizada ao repo.
- Consumidores externos do endpoint: nenhum comprovado no repo — impacto esperado baixo; se algum consumidor precisar de nome/email deve passar `internal=1` (legado explícito) ou migrar para auth por usuário na fatia de identidade.
