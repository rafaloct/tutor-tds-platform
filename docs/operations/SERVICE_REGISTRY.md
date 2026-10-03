# Inventário operacional de serviços Tutor TDS

Issue [#26](https://github.com/rafaloct/tutor-tds-platform/issues/26).
Revisão documental: **2026-10-03**, base
`1a577a6e9417772753beb1525e25757f4e97b7ea`. Estado da entrega: IMPLEMENTED;
aceite e integração dependem de revisão. Nenhuma conta, infraestrutura ou
produção foi acessada ou alterada para preencher este inventário.

## Como interpretar e manter

As três tabelas são projeções do mesmo registro, unidas por `service_id`.
Cada ID aparece uma vez em cada tabela. Os campos comuns abaixo também fazem
parte de **cada registro**, salvo substituição explícita na linha:

- `owner_functional`, `owner_technical`, `secondary_admin`: **UNKNOWN**.
  Os papéis de encaminhamento indicados são TARGET, não nomeações comprovadas.
- `account_type`: **unknown**; conta de serviço desejada não prova conta de
  automação instalada. Valores aceitos: institutional, automation, unknown.
- `renewal/cost owner`: **UNKNOWN**; centro pagador, vencimento e limites devem
  ser confirmados pela coordenação com o titular. Não registrar cartão ou e-mail pessoal.
- `last_verified_at`: **UNKNOWN para runtime**. A data desta revisão é somente
  a conferência dos documentos; datas históricas nas fontes não viram health atual.
- `monitor`: **UNKNOWN** quanto a execução atual, destino e recebimento de alerta.
  As verificações listadas na tabela são TARGET, salvo evidência datada explícita.

`status` classifica existência/atividade atual: `observed` exige evidência
atual explícita; `target` identifica implantação futura; `unknown` preserva
histórico sem promovê-lo. UNKNOWN não significa ausente nem autorização para
recriar. Versões históricas também não são inventário de versões instaladas hoje.
Tier segue [continuidade](../program/OPERATIONS_CONTINUITY.md); componentes de
suporte herdam o Tier do consumidor crítico. Os papéis seguem a
[RACI](../program/GOVERNANCE_RACI.md), sem conceder acesso.

Atualizar após mudança aceita, incidente, restore ou troca de equipe; revisar
acessos/custos trimestralmente e backups/alertas mensalmente. Quem atualizar deve
registrar data, fonte sanitizada e ambiente de cada fato; manter UNKNOWN nos
campos não verificados. Não anexar secrets, dumps, listas de usuários ou logs brutos.

## Identidade, finalidade, ambiente e dependências

Hosts abaixo são referências públicas/documentais, sem credenciais. UNKNOWN
preserva localização não comprovada; nome de container histórico não é endpoint.

| service_id | Nome / finalidade | Tier | environment | status | public_url/host | dependencies | evidence |
|---|---|---|---|---|---|---|---|
| github | GitHub: fonte, issues, revisão e CI | 0 | governança | observed | github.com/rafaloct/tutor-tds-platform | identity-custody | Issue #26 consultada em 2026-10-03; repositório/base acima; last_verified_at=2026-10-03 para acesso documental apenas |
| dns | Domínio/DNS/TLS: resolução e identidade pública | 0 | produção e staging separados | unknown | ead.ipexdesenvolvimento.cloud (referência histórica) | identity-custody; vps; cloud-staging | S2, S3; registrador/zona atual UNKNOWN |
| identity-custody | Credenciais institucionais, MFA e recuperação | 0 | todos, segregados | target | UNKNOWN | governança; github | S4, S5; custódia instalada UNKNOWN |
| backup | Backup offsite e chave de recuperação | 0 | produção; restore isolado | unknown | UNKNOWN | postgres-prod; dokploy; r2; identity-custody; smtp | S6; issue #2 é a frente vigente |
| vps | Hostinger VPS: compute compartilhado | 1 | produção histórica | unknown | srv1533541 (histórico) | dns; identity-custody; backup | S2; sem inspeção atual do painel |
| dokploy | Dokploy, PostgreSQL/Redis de controle e proxy Traefik | 1 | produção histórica | unknown | UNKNOWN; painel histórico não é acesso aprovado | vps; dns; backup | S2, S3 |
| api-prod | FastAPI Tutor: núcleo transacional | 1 | produção | unknown | https://ead.ipexdesenvolvimento.cloud/tutor-api | postgres-prod; dokploy; dns; identity-custody | S3, S7; health histórico não prova versão/schema atual |
| postgres-prod | PostgreSQL dedicado: persistência Tutor | 1 | produção | unknown | rede interna; host atual UNKNOWN | vps; dokploy; backup | S2, S3, S6; distinto de postgres-shared |
| auth | Autenticação e autorização FastAPI | 1 | produção/staging isolados | unknown | API de cada ambiente | api-prod; postgres-prod; identity-custody; cloud-staging; supabase-staging | S7, S8; código não prova flags/config instalada |
| cloud-staging | FastAPI Cloud: homologação isolada | 1 | staging | unknown | https://tutor-tds-staging.fastapicloud.dev | supabase-staging; identity-custody; github | S8; aceitações históricas não provam disponibilidade hoje |
| supabase-staging | PostgreSQL Supabase de homologação | 1 | staging | unknown | host de conexão UNKNOWN; não copiar DSN | cloud-staging; identity-custody; backup | S8; não é Auth/Storage/Data API do produto |
| flutter-play | Flutter Android e distribuição Play | 1 | produção; QA separado | unknown | package com.tutortds_cartilhas; ficha atual UNKNOWN | api-prod; gateway; drive; chatwoot; identity-custody; github | S7, S9; 1.2.0+11 é versão histórica, não auditoria Play atual |
| pwa | Flutter PWA / Nginx | 1 | produção histórica | unknown | UNKNOWN | dokploy; dns; api-prod; gateway | S1, S2 |
| policy-web | Páginas de privacidade/exclusão | 1 | produção histórica | unknown | host ead.ipexdesenvolvimento.cloud; caminhos atuais UNKNOWN | dokploy; dns | S2, S3 |
| gateway | Cloudflare Worker: gateway IA e certificados legados | 2 | produção; staging separado a confirmar | unknown | UNKNOWN | anythingllm; kv; identity-custody | S1, S9 |
| kv | Cloudflare KV: referências/verificação de certificados | 2 | produção histórica | unknown | binding CERTIFICATES; sem export de conteúdo | gateway; identity-custody; backup | S9; emissão autenticada segue #5/#39 |
| anythingllm | AnythingLLM: RAG das cartilhas | 2 | produção histórica | unknown | container anythingllm (histórico) | vps; weaviate; ai-provider; drive | S1, S2, S9 |
| weaviate | Índice vetorial das cartilhas | 2 | produção histórica | unknown | rede interna; host atual UNKNOWN | anythingllm; vps; backup | S1, S2 |
| ai-provider | OpenRouter/modelo Gemini: inferência | 2 | produção histórica | unknown | provider OpenRouter; endpoint configurado UNKNOWN | anythingllm; identity-custody | S2; modelo histórico não prova seleção atual |
| r2 | R2/S3: destino de backup; mídia futura separada | 0 | produção/staging segregados | unknown | bucket/endpoint UNKNOWN | identity-custody; backup | S5, S6; não presumir mesma credencial/prefixo para mídia |
| drive | Google Drive: cartilhas e masters | 2 | produção; QA separado | unknown | drive.google.com; objetos privados omitidos | identity-custody | S7, S9; leitura histórica de PDF não prova custódia |
| sheets-prod | Google Sheets: projeção/legado operacional | 3 | produção | unknown | docs.google.com; planilha não publicada aqui | apps-script; tds-sync; service-accounts; identity-custody | S7, S9; não autoriza matrícula/presença |
| sheets-staging | Sheets: homologação sintética | 3 | staging | unknown | docs.google.com; ID privado omitido | service-accounts; identity-custody; cloud-staging | S7; fonte original preservada |
| apps-script | Google Apps Script: transporte legado | 3 | produção histórica | unknown | URL de implantação UNKNOWN | sheets-prod; identity-custody; smtp | S1, S9; risco histórico de PII requer revisão, não reprodução |
| service-accounts | Contas de serviço por integração/ambiente | 0 | produção/staging segregados | unknown | UNKNOWN | identity-custody; sheets-prod; sheets-staging | S5; tipo automation desejado, não comprovado |
| tds-sync | TDS Sync / exportações de dados | 3 | produção histórica | unknown | kreativ-tds-sync (histórico) | sheets-prod; service-accounts; postgres-shared | S1, S2; ligação ao DB Tutor não presumida |
| wordpress | WordPress, banco próprio, wp-content e cache Redis | 2 | produção legada; staging WP-2 | unknown | URL atual UNKNOWN | dokploy; dns; backup; smtp; api-prod | S10; candidato #53 não equivale a staging/produção |
| chatwoot | Atendimento, workers, banco e anexos | 2 | produção legada; QA fake | unknown | UNKNOWN | dokploy; dns; backup; smtp; identity-custody | S11; CW-1 local não comprova instalação |
| bi | Power BI Desktop / Fabric: análise | 3 | cópia QA; publicação UNKNOWN | unknown | workspace Fabric UNKNOWN | sheets-prod; sheets-staging; drive; identity-custody | S7; cópia Desktop não prova Fabric publicado |
| media | Provider de mídia: processamento/entrega | 2 | alvo; fake primeiro | target | UNKNOWN | api-prod; drive; r2; identity-custody | S12; #31/#52, fornecedor/custo não decidido |
| lms-lite | LMS Lite API e Dashboard legados | 3 provisório | compartilhado histórico | unknown | kreativ-lms-lite-api; dashboard histórico | postgres-shared; dokploy | S1, S2; vínculo atual TDS UNKNOWN |
| postgres-shared | PostgreSQL/pgvector compartilhado | 3 provisório | compartilhado histórico | unknown | kreativ-postgres (histórico) | dokploy; backup | S1, S2; não confundir com DB Tutor |
| rag-aux | RAG auxiliar + Ollama | 3 provisório | compartilhado histórico | unknown | kreativ-rag; kreativ-ollama (históricos) | postgres-shared; ai-provider; dokploy | S1, S2; consumidores atuais UNKNOWN |
| n8n-evolution | n8n / Evolution: automações e canais compartilhados | 3 provisório | compartilhado; pertença TDS UNKNOWN | unknown | UNKNOWN | dokploy; identity-custody | S1, S2; incluídos como descoberta, não serviços TDS confirmados |
| smtp | E-mail: alertas e notificações | 0 para backup; 2 demais | ambientes a separar | unknown | provider/host UNKNOWN | identity-custody; dns | S5, S6, S11; configuração não comprova recebimento |

## Configuração, backup e recuperação

`config_location` indica código/runbook ou painel responsável, nunca valor secreto.
`backup_scope` é o conteúdo que precisa ser protegido; cobertura executada é
UNKNOWN salvo prova específica. `restore_runbook` abaixo é caminho de recuperação
proposto/documentado: **não equivale a restore testado**. Só executar em ambiente
isolado autorizado. Para tarefas sem receita específica, a lacuna está explícita.

| service_id | config_location | backup_scope | restore_runbook | monitor TARGET / lacuna |
|---|---|---|---|---|
| github | Repositório/.github e Settings com acesso autorizado | Git, issues/PRs e regras; export de metadados UNKNOWN | Clone independente + restauração de acesso conforme S4; export/restore de metadados UNKNOWN | CI, acesso de segundo admin, revisão de regras |
| dns | Painel registrador/DNS UNKNOWN; S5 | Zona, titularidade e referências TLS | Export sanitizado + plano de reversão S5; export vigente UNKNOWN | Expiração DNS/TLS e renovação |
| identity-custody | Gerenciador institucional UNKNOWN | Material de recuperação sob custódia separada | S4: recuperar conta por segundo admin; procedimento testado UNKNOWN | Revisão de acesso/MFA e substituto |
| backup | S6; tooling/backup_automation; secret store fora do Git | Dumps, manifestos, checksums, configuração e chave separada | S6 + issue #2; restore por recurso antes do aceite; DR ampliado #35 | Idade offsite; watchdog externo; recebimento UNKNOWN |
| vps | Painel Hostinger/Dokploy; S2/S3 | Manifestos, volumes e snapshot quando comprovado | S4/S6: reconstruir host isolado e restaurar serviços; snapshot atual UNKNOWN | Disco, memória, disponibilidade externa |
| dokploy | Painel e manifests; S3 | DB/config do controle e referências de secrets | S6/#2: restaurar controle isolado; não sobrescrever host compartilhado | Saúde controle/proxy e backup semanal |
| api-prod | api/; S5; compose de produção | Código/imagem versionada, config sem secrets; dados em postgres-prod | S6/S7: banco isolado + imagem compatível; rollback de flags/artefato | Health/version/readiness, 5xx e revision |
| postgres-prod | Compose/rede interna; S5 | Dump consistente e versão/schema; política em #2 | S6: restore isolado, integridade e smoke API; não usar produção como destino | Storage/conexões, idade de dump, restore |
| auth | api/app; S5 | DB e custódia de chaves/config por ambiente | Restore do DB + custódia autorizada; testar login/revogação sintéticos | Falhas agregadas sem identidade/PII |
| cloud-staging | S8; painel FastAPI Cloud autorizado | Manifesto/versionamento e DB separado | S8: reconstrução de homologação com DB próprio; preservar fixtures aprovadas | Health/version e estado do serviço |
| supabase-staging | S8; painel Supabase autorizado | Dump staging, revision e isolamento | S8/S6: DB isolado e migration compatível; sem migrar Auth/Storage | Conectividade, quota, pausa e backups |
| flutter-play | cartilhas_app; S7; Play Console | Artefatos/versionCode e custódia da assinatura fora do Git | S7: preflight/release; recuperação de acesso/assinatura UNKNOWN | Crash/ANR e versão distribuída; release bloqueada |
| pwa | Build Flutter web/Nginx; S3 | Artefato e config por versão | S3/S4: artefato anterior em ambiente isolado; ensaio UNKNOWN | HTTP e recursos/cache |
| policy-web | Compose/arquivos de política; S3 | Conteúdo jurídico e rotas versionados | Restaurar versão/rotas aprovadas, testar links; ensaio UNKNOWN | Disponibilidade e links de exclusão |
| gateway | cartilhas_app/cloudflare/tutor-tds-gateway; Wrangler | Fonte/config pública, bindings; secrets custodiados | S6: reconstrução em Worker isolado; export de KV separado; ensaio UNKNOWN | Health, timeout e erros upstream |
| kv | Binding Cloudflare; S9 | Export lógico autorizado + integridade e chaves separadas | S6/#5: restaurar namespace isolado e verificar referências; ensaio UNKNOWN | Falha de lookup e integridade; sem dados em logs |
| anythingllm | Painel/volumes; S2/S9 | Config/workspace/documentos e referências do índice | S6: volumes isolados ou reindexar masters aprovados; ensaio UNKNOWN | Health/upstream/latência |
| weaviate | Compose/volumes; S2 | Índice e versão/schema ou receita de reindexação | S6: restore isolado/reindexação; compatibilidade UNKNOWN | Disco/índice e consulta sintética |
| ai-provider | Secret store AnythingLLM; S5 | Config/model allowlist; sem arquivar prompts reais | S4/S5: recuperar conta/limites; fallback indisponível seguro | Quota/custo/timeout/modelo permitido |
| r2 | Painel Cloudflare/S3 e config server-side; S5 | Objetos, retenção, IAM e chave externa | S6/#2: download autorizado, checksum/decrypt e restore isolado; IAM mínimo UNKNOWN | Idade/quantidade, quota/custo e acesso negado |
| drive | Permissões/pastas Drive institucionais a confirmar | Masters/cartilhas, versões, manifesto e permissões | S4: export privado/restauração de master com hash; ensaio UNKNOWN | Disponibilidade/alteração dos materiais |
| sheets-prod | S5; scripts/sync; ranges exclusivos | Planilhas necessárias e schema; origem preservada | S4/S6: cópia privada e readback; reconstrução só das projeções com fonte comprovada | Último sync, erros e duplicatas |
| sheets-staging | S7; config separada | Fixtures sintéticas e schema | Restaurar cópia de QA separada; nunca sobrescrever produção | Readback sintético e isolamento |
| apps-script | Projeto Apps Script; S9 | Fonte/versionamento e manifesto de implantação | Restaurar projeto isolado; revisar PII antes de ativar; ensaio UNKNOWN | Erros/recebimento sem payloads pessoais |
| service-accounts | IAM e secret store autorizados; S5 | Inventário de escopos e recuperação; chaves fora do Git | S4/S5: substituir conta/credencial em janela própria; não copiar entre ambientes | Expiração, escopos e último uso sanitizado |
| tds-sync | Compose/config; S1/S2 | Fonte/config, cursor/checkpoint e schema | S6: restaurar cursor isolado e testar idempotência; ensaio UNKNOWN | Backlog, último sucesso, retries |
| wordpress | S10; tema/plugin versionados; painel staging | DB próprio + wp-content/uploads + versões/config | S10 rollback plan; #42/#35 exigem ensaio específico isolado | Home/REST/noindex staging, integridade/backup |
| chatwoot | S11; painel/compose autorizado | DB, anexos, config/inboxes/filas | S11/#35: restore isolado e conversa sintética; ensaio UNKNOWN | WebSocket/workers/fila/SMTP/storage |
| bi | S7; Desktop/workspace Fabric | PBIP/PBIX, queries, schema e permissões | Restaurar cópia e refresh de fonte autorizada; publicação Fabric UNKNOWN | Refresh e qualidade; null não vira zero |
| media | S12; adapter/config servidor futuro | Masters, manifests e metadados; delivery reconstruível | Definir provider e ensaio sintético em #31/#52; receita real UNKNOWN | Expiração/grant, disponibilidade e custo |
| lms-lite | S1/S2; compose legado | DB, código/config se vínculo TDS confirmado | S6 somente após mapear consumidor/owner; recipe específica UNKNOWN | Health/dependências somente após confirmar escopo |
| postgres-shared | S2; compose compartilhado | Bases/volumes com owners separados | S6: snapshot isolado com consentimento de cada consumidor; ensaio UNKNOWN | Disco/logs/conexões; risco histórico não é estado atual |
| rag-aux | S2; compose/modelos | Config/modelos/índice conforme consumidores | S6 após inventário de consumidores; nunca remover modelo por inferência | Health/quota/disco quando escopo confirmado |
| n8n-evolution | S2; painel compartilhado | Workflows, estado/canais conforme ownership | UNKNOWN até confirmar pertença e plano específico; não ativar/exportar workflows reais | UNKNOWN até confirmar consumidor TDS |
| smtp | Secret store/painel do provider; S5 | Config/identidade remetente e recuperação separada | S4/S5: recuperar acesso, ensaio autorizado e comprovação de recebimento | Envio + entrega; SKIPPED não é recebido |

## Owners, conta única e próxima ação humana

Cada linha herda owners/segundo admin/custo **UNKNOWN** definidos acima. O papel
abaixo deve receber o pedido; não se afirma que alguém já assumiu a operação.
Para **cada ID**, a ação H0 é obrigatória além da ação específica: coordenação
registra owner funcional, técnico e segundo administrador independentes, tipo de
conta, referência privada da custódia, responsável financeiro, vencimento/limite
ou ausência comprovada de custo recorrente. Confirmar acesso do substituto em
procedimento autorizado, sem publicar credenciais. Informar só função e evidência
sanitizada, nunca recuperação/MFA no Git.

| service_id | Encaminhamento TARGET | human_action_needed além de H0 | Risco de continuidade / o que permanece desbloqueado |
|---|---|---|---|
| github | Técnico + coordenação | Confirmar natureza institucional do namespace pessoal e segundo admin; registrar plano de recuperação/export de issues | Namespace sob usuário é dependência potencial de conta única; docs/CI/review continuam |
| dns | Infra + coordenação | Confirmar titular/registrador, export sanitizado da zona, validade e recuperação por substituto | Perda de domínio afeta todos; inventário e propostas continuam |
| identity-custody | Infra + dados | Definir gerenciador, custódios e ensaio de recuperação separado da VPS | Único perfil/dispositivo pode bloquear recuperação; runbook continua |
| backup | Infra | Na #2 confirmar custódia independente, e-mail recebido e primeiro semanal pelo relógio; anexar evidência sanitizada | Restore documentado não prova acesso por substituto; #26/#32 continuam |
| vps | Infra | Confirmar titular do contrato, segundo acesso e snapshot/cobertura por serviço em janela autorizada | Host compartilhado pode concentrar acesso e falha; plano de DR continua |
| dokploy | Infra | Confirmar segundo admin e recuperação do plano de controle sem a VPS original | Painel não substitui backup; documentação continua |
| api-prod | Técnico + infra | Confirmar owner, versão/schema instalados e vínculo com backup aceito, sem deploy | Health isolado não prova recuperabilidade; código/CI continuam |
| postgres-prod | Infra + dados | Confirmar owner do volume/dump, RPO/RTO aprovados e evidência de restore correspondente | Dados críticos; ensaios futuros somente isolados |
| auth | Técnico + dados | Confirmar custodiante e recuperação da configuração de autenticação por ambiente | Perda de chaves pode invalidar sessões; testes sintéticos continuam |
| cloud-staging | Técnico | Confirmar vigência/pausa, plano financeiro e admins do app de homologação | Conta única pode impedir QA; trabalho local continua |
| supabase-staging | Infra | Confirmar plano/retention/admins e evidência de isolamento do DB staging | Não reativar/expor tabelas para inventário; fakes continuam |
| flutter-play | Release manager | Confirmar titularidade Play, segundo admin, versão publicada e custódia da assinatura por procedimento privado | Histórico não prova conta institucional; nenhum AAB/deploy autorizado |
| pwa | Infra + release | Confirmar URL/versionamento e artefato recuperável | Mesmo host do backend; revisão de build continua |
| policy-web | Coordenação + dados | Confirmar URLs/conteúdo vigente e responsável por pedidos de exclusão | Ausência de owner afeta obrigações; revisão documental continua |
| gateway | Infra + técnico | Confirmar conta Cloudflare, substituto e procedimento de reconstrução sem exportar secrets | Conta única afeta IA/certificados; testes locais continuam |
| kv | Técnico + coordenação | Confirmar custódia/export autorizado e plano de preservação de certificados legados | Namespace não pode ser recriado/reemitido por inferência; #5/#39 seguem seus gates |
| anythingllm | Técnico | Confirmar workspace, versões, owner e masters necessários à reindexação | Conhecimento concentrado na VPS; contrato de fallback continua |
| weaviate | Infra | Confirmar volume/versão e receita de restore ou reindexação | Índice sem master verificável pode ser irrecuperável; documentação continua |
| ai-provider | Coordenação + infra | Confirmar titular/pagador, limites e allowlist atualmente aprovada | Quota/conta pessoal pode cortar IA; adapter/fake continuam |
| r2 | Infra | Confirmar owner/pagador, escopo mínimo de credencial e custódia separada na #2, sem mostrar segredo | Bucket acessível não prova privilégio mínimo; runbook continua |
| drive | Editorial + dados | Confirmar propriedade institucional dos masters e segundo gestor; validar recuperação sem conta pessoal | Material acessível por link não prova custódia; catálogo documental continua |
| sheets-prod | Dados | Confirmar conta gestora institucional, substituto e cópia privada recuperável | Conta histórica nominal não prova continuidade; contratos BI continuam |
| sheets-staging | Dados + técnico | Confirmar segregação de propriedade/dados e expiração das fixtures | QA não pode contaminar produção; testes locais continuam |
| apps-script | Dados + técnico | Identificar owner/implantação vigente, dependências e revisão da exposição histórica de PII | Não copiar payload real para prova; revisão de contrato continua |
| service-accounts | Infra | Inventariar nomes lógicos/escopos/ambientes e substituição sem export de chaves | Automação não pode depender do login de uma pessoa; fakes continuam |
| tds-sync | Dados + técnico | Confirmar consumidores/fontes/cursor e segundo operador antes de conectar DB Tutor | Fluxo legado independente; contrato de integração continua |
| wordpress | Editorial + infra | Confirmar admins/owner/custo e homologação isolada com DB/uploads/rollback (#42/#48) | Conta única e conteúdo legado requerem triagem; tema/plugin locais continuam |
| chatwoot | Suporte + infra | Confirmar admins/canais/retention e ensaio isolado de DB/anexos/SMTP | Fake não comprova atendimento; #46 continua com integrações inativas |
| bi | Dados | Confirmar owner/workspace/licença/refresh e cópia recuperável dos artefatos | Desktop pessoal não é publicação institucional; dicionário/projeções continuam |
| media | Editorial + técnico | Decidir provider/custo/custódia após contrato #52; identificar executor antes de redispatch | Nenhum fornecedor real escolhido por inferência; adapter fake continua |
| lms-lite | Técnico + infra | Identificar consumidor/owner TDS e decidir retenção; registrar se externo | Não desligar legado desconhecido; auditoria documental continua |
| postgres-shared | Infra + dados | Mapear todos consumidores/owners antes de qualquer recuperação/mudança | Pode afetar outros projetos; nenhuma limpeza de logs/dados autorizada |
| rag-aux | Técnico + infra | Confirmar se atende TDS; separar modelos/dados e ownership dos demais projetos | Não remover modelos por nome; mapa de dependências continua |
| n8n-evolution | Infra + suporte | Confirmar se existe consumidor TDS; se não, registrar recurso externo preservado | Inclusão não autoriza integração WhatsApp/automação; restante do programa continua |
| smtp | Infra + suporte | Confirmar provider/remetente/segundo gestor e autorizar teste separado com recibo de entrega (#2) | Envio ou configuração isolados não provam recebimento; revisão local continua |

H0 não bloqueia o aceite do **inventário documental**: a issue permite UNKNOWN.
A execução das ações que requerem contas/produção permanece HUMAN-GATE de acesso,
custo ou produção na issue apropriada. Sem owners comprovados, o inventário não
declara continuidade operacional aceita. A coordenação deve consolidar os pedidos
por titular em um pacote, evitando pedir o mesmo acesso a cada frente.

## Evidências e cobertura

- S1: [SERVICES_MAP](../infrastructure/SERVICES_MAP.md), topologia documental.
- S2: [VPS_INVENTORY](../infrastructure/VPS_INVENTORY.md), auditoria histórica de setembro; sem extrapolar saúde atual.
- S3: [DOKPLOY_ARCHITECTURE](../infrastructure/DOKPLOY_ARCHITECTURE.md), rotas e isolamento históricos.
- S4: [OPERATIONS_CONTINUITY](../program/OPERATIONS_CONTINUITY.md), política TARGET, tiers e recuperação.
- S5: [CONFIGURATION_RUNBOOK](../program/CONFIGURATION_RUNBOOK.md), nomes/localização lógica e separação de ambientes.
- S6: [BACKUP_RESTORE](../infrastructure/BACKUP_RESTORE.md) e [issue #2](https://github.com/rafaloct/tutor-tds-platform/issues/2), histórico/runbook e frente vigente; pendências antigas do arquivo não substituem evidência nova da issue.
- S7: [CURRENT_STATE](../CURRENT_STATE.md) e [ENVIRONMENT_CONTRACT](../production/ENVIRONMENT_CONTRACT.md), evidências datadas e limites de release.
- S8: [CLOUD_STAGING](../production/CLOUD_STAGING.md), configuração e homologação histórica.
- S9: [INTEGRATIONS](../maintenance/INTEGRATIONS.md), histórico 19/09; seus rótulos “ativo” não comprovam runtime hoje.
- S10: [WP1 audit](../portal/WP1_WORDPRESS_AUDIT_2026-10-03.md) e [rollback plan](../portal/WP1_STAGING_ROLLBACK_PLAN.md), escopo portal.
- S11: [Chatwoot CW-0](../production/CHATWOOT_TDS_CURRENT_STATE.md) e [CW-1](../production/CHATWOOT_CW1_IMPLEMENTATION.md), inventário parcial e fake local.
- S12: [TARGET_ARCHITECTURE](../program/TARGET_ARCHITECTURE.md) e [INTEROPERABILITY](../program/INTEROPERABILITY.md), contratos desejados.

Cobertura S1: Flutter Android/PWA → flutter-play/pwa; Tutor API → api-prod/auth;
PostgreSQL dedicado → postgres-prod; Worker → gateway; AnythingLLM → anythingllm;
OpenRouter/Gemini → ai-provider; Weaviate → weaviate; KV → kv; Apps Script/Sheets →
apps-script/sheets-prod; Chatwoot → chatwoot; VPS/Dokploy → vps/dokploy;
políticas → policy-web; TDS Sync → tds-sync; LMS Lite API/Dashboard → lms-lite;
PostgreSQL/pgvector → postgres-shared; RAG/Ollama → rag-aux;
n8n/Evolution/compartilhados → n8n-evolution, sem atribuição fictícia ao TDS.
PocketBase/Frappe citados em S2 são recursos de outros escopos não confirmados;
nunca removê-los por ausência nesta lista de serviços TDS.

Critérios da #26 cobertos: registro criado; Tier 0/1 com owner/recuperação ou
UNKNOWN; dependências explícitas; riscos de conta única; ação humana H0 mais
ação específica para cada lacuna crítica. Validação da PR deve conferir links,
cobertura, diff e Gitleaks no commit. Não executar suítes de app/API para este
delta documental. Rollback: reverter somente este documento, sem efeitos runtime.
