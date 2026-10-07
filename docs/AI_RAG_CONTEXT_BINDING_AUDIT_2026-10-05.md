# Auditoria de vínculo contextual do Tutor IA

Estado do código auditado: endpoint já usado pelo gateway:
`POST /api/v1/workspace/:slug/chat`; workspace configurado historicamente como
`cartilhas` em `cartilhas_app/cloudflare/tutor-tds-gateway/README.md`.

## Capabilities auditadas

**ANYTHINGLLM_SCOPE_CAPABILITIES**

- **SUPPORTED (contrato oficial público auditado):**
  - seleção de workspace pelo `:slug` na rota chat e na rota
    `/api/v1/workspace/:slug/vector-search`;
  - modos `chat`, `query` e `automatic`; a documentação de rota descreve `query`
    como sem histórico e sem invocar LLM quando não há fontes relevantes;
  - `vector-search` aceita `query`, `topN` e `scoreThreshold`;
  - as respostas da busca incluem `results` com `metadata`, e respostas do chat
    incluem `sources`.
- **UNSUPPORTED (no contrato/código oficial auditado):**
  - `metadataFilters` e `documentFilter` para restringir a busca no endpoint de
    chat ou `vector-search`. Upload e presença de metadata não demonstram filtro
    de recuperação.
- **UNKNOWN/BLOCKED:**
  - versão efetivamente instalada no VPS/Dokploy;
  - metadata e composição dos documentos atualmente indexados;
  - se existe workspace isolado por escopo acadêmico;
  - se as sources finais do chat instalado carregam metadata de escopo suficiente;
  - registry RAG permanente e fronteira acadêmica autoritativa.

Fontes oficiais consultadas em 2026-10-05:

- [Workspace API, revisão `feb04ca0a57cda6d0b3a69c62578f0af44d388fc`](https://github.com/Mintplex-Labs/anything-llm/blob/feb04ca0a57cda6d0b3a69c62578f0af44d388fc/server/endpoints/api/workspace/index.js):
  contrato chat lista `message`, `mode`, `sessionId`, anexos e reset; o comentário
  da rota `query` diz que não reutiliza histórico. O handler de `vector-search`
  usa `query`, `topN` e `scoreThreshold`, sem filtro por documento/metadata.
- [OpenAPI, mesma revisão](https://github.com/Mintplex-Labs/anything-llm/blob/feb04ca0a57cda6d0b3a69c62578f0af44d388fc/server/swagger/openapi.json):
  contrato publicado não declara `metadataFilters` nem `documentFilter`.

O repositório não fixa nem comprova a versão do servidor AnythingLLM. A
capacidade acima é evidência do contrato oficial consultado, não prova da
instalação remota.

## Estado observado e arquitetura alvo

**OBSERVED:** a mudança no gateway resolve o workspace temporariamente por
`course_id|course_version_id` e exige um binding 1:1: duas CourseVersions não
podem reutilizar o mesmo workspace. O Worker faz `vector-search` nesse workspace
e chama o mesmo workspace em `mode=query`; não há fallback para
`ANYTHING_LLM_WORKSPACE` quando `learning_context` está presente.

A auditoria do contrato upstream mostrou que `vector-search` serializa somente
metadata documental genérica (`url`, `title`, `author`, `description`,
`docSource`, `chunkSource`, `published`, `wordCount`, `tokenCount`) e
não preserva IDs acadêmicos arbitrários. O chat, por sua vez, devolve os sources
brutos do vector DB com campos no topo do objeto. O gateway foi alinhado a esse
shape: deriva `course_id` e `course_version_id` do binding
CourseVersion → workspace, correlaciona citations com fontes observadas na
pré-busca por ID privado quando disponível e por título/document source como
evidência adicional, e só então publica título + curso + edição + score.
Identificadores privados, path, URL, chunk e metadata interna não saem do Worker.

`TUTOR_RAG_SCOPE_MAP` é somente bootstrap temporário/test fixture, não fonte de
verdade acadêmica permanente. Durante o sentinel de 2026-10-06, apontou somente
para workspaces QA isolados em staging. Nenhum registry acadêmico permanente
foi criado. Produção e o workspace `cartilhas` não foram alterados; apenas
recursos QA isolados de staging foram criados. Clientes sem `learning_context`
mantêm o comportamento legado.

**RAG_SCOPE_ARCHITECTURE=DEFERRED.** A API consultada não permite provar
isolamento por módulo dentro de um workspace compartilhado: `vector-search`
não aceita filtro documentado por metadata/documento e o chat não recebe como
fronteira fechada apenas os chunks verificados na pré-busca. Por isso
`module_id`, `experience_id` e `experience_type` continuam estruturados no
request, mas não são fabricados como atributos das sources nem promovidos a
isolamento comprovado. Os testes locais provam a política CourseVersion do
gateway e a compatibilidade com o shape público do AnythingLLM, não o isolamento
real por módulo/experiência.

**RAG_SCOPE_GRANULARITY:** workspace por CourseVersion é a granularidade
temporária configurada; isolamento de módulo/experiência permanece DEFERRED. A
menor fronteira de recuperação documentada para isolamento de módulo exigiria
uma fronteira física distinta por módulo, se não houver capacidade upstream
adicional. Isso não está implementado, não foi provado e não autoriza
provisionamento nesta execução. Nenhum workspace por experiência é necessário
ou aceitável.

**TUTOR_RAG_SCOPE_MAP_ROLE=TEMPORARY.**
**FASTAPI_CHANGE_REQUIRED=NÃO.** Este recorte do PR #136 não altera FastAPI nem
`course_promotion`.

**RAG_REGISTRY_FASTAPI_CHANGE=UNKNOWN.** Lifecycle permanente documentado como
**TARGET, não implementação observada**:

```text
CourseVersion publicada
        ↓
materiais aprovados
        ↓
ingestão/indexação IA
        ↓
metadata vinculada à CourseVersion
        ↓
rag_scope registrado
        ↓
gateway resolve contexto
```

O fluxo alvo deve ser automático para novas CourseVersions e não exigir
configuração por experiência. O registry autoritativo e sua fronteira ainda
dependem de decisão técnica; nenhum endpoint ou persistência foi criado.

O objeto é somente escopo de conteúdo e não é autorização. O gateway usa somente
IDs estáveis allowlisted; não recebe identidade, matrícula, frequência,
baseline ou reflection como contexto. No caminho estruturado, texto `context`
livre é descartado antes de AnythingLLM. `mode=query` não usa histórico e este
código não envia `sessionId`. A resposta expõe somente título público,
`course_id`, `course_version_id` e score opcional das fontes correlacionadas;
`module_id`/experiência não são fabricados na source. Chunk, caminho, URL,
storage ID e metadata privada não são retornados.

## Prova local e limites

- `LOCAL_CONTEXT_BINDING_READY=PARCIAL`
- `CONTEXT_BINDING_READY=SIM_COURSEVERSION`
- `AI_SERVICE_READY=SIM (escopo CourseVersion, staging)`
- `RAG_SCOPE_GRANULARITY=CourseVersion`
- `WORKSPACE_PER_EXPERIENCE=NO`
- `MODULE_ISOLATION=DEFERRED`
- `EXPERIENCE_ISOLATION=DEFERRED`
- `TUTOR_RAG_SCOPE_MAP_ROLE=TEMPORARY`
- `FASTAPI_CHANGE_REQUIRED=NÃO`
- `RAG_REGISTRY_FASTAPI_CHANGE=UNKNOWN`
- `RAG_REGISTRY_PERMANENT=DEFERRED`
- `INGESTION_LIFECYCLE_DOCUMENTED=TARGET`

- Fixtures de `gateway.test.js` usam o shape público auditado do
  AnythingLLM: `vector-search` com `id + metadata documental` e chat sources
  com campos no topo. Os casos provam roteamento A/B para workspaces distintos,
  rejeição de alias entre CourseVersions, correlação da citation com a
  pré-busca, descarte de identificadores privados e fail-closed para sources
  ausentes/estruturalmente inseguras. O sentinel real em staging também provou
  o binding CourseVersion; módulo/experiência permanecem estruturados no request
  sem serem fabricados como atributos da source ou tratados como isolamento
  comprovado. O contrato mantém campos opcionais de experiência; não há chamador
  de experiência neste PR.
- A chamada geral do Tutor envia `course_id`, `course_version_id` e `module_id`.
  Os campos opcionais de experiência permanecem em `TutorLearningContext`
  porque são aceitos pelo contrato do gateway, mas não têm caller neste PR.
- Camada Experience Blocks do PR #135 removida do PR #136 por decisão humana em
  2026-10-06; permanece no PR #135. Chamador geral do Tutor envia
  course_id/course_version_id/module_id; nenhum chamador de experiência neste PR.
- Validação local do sync anterior com `staging=9577541`: gateway `31/31` e
  sentinel tooling `5/5`. A cobertura do caller geral fica em
  `chat_experience_progress_test.dart`; não há evidência de `course_promotion`
  ou de caller de experiência neste PR.
- O tooling `verify_rag_sentinel.mjs` exige dois escopos CourseVersion
  distintos, dois marcadores A/B e sources compatíveis; rejeita módulo/
  experiência para não produzir uma prova além da capacidade upstream auditada.
  Não inclui o marcador esperado na pergunta e não imprime prompt, resposta,
  endpoint ou metadata privada. A prova real remota está registrada abaixo.
- GitHub Actions disparados durante o incidente de disponibilidade do GitHub
  retornaram `action_required` com zero jobs; esse estado não é CI PASS nem
  falha de implementação. CI deverá ser observado novamente quando o serviço
  normalizar.
- O sentinel A/B real PASS em staging em 2026-10-06; `REAL_STAGING_E2E=YES`
  para escopo CourseVersion. A evidência está em
  `production/evidence/ai-rag-courseversion-sentinel-staging-2026-10-06.json`.
  Produção e o workspace `cartilhas` não foram alterados.

## Adendo 2026-10-07 — binding de módulo

Sob a autorização Phase A de 07/10, o `TUTOR_RAG_SCOPE_MAP` passa a aceitar
chaves de três segmentos `course_id|course_version_id|module_id` além das
chaves de CourseVersion. Com `module_id` no contexto, o gateway tenta primeiro
o binding exato de módulo; se o mapa declara granularidade de módulo para aquela
CourseVersion mas o módulo pedido não está mapeado, falha fechada com
`rag_context_unresolved` em vez de ampliar silenciosamente para o workspace da
edição. Sem chaves de módulo para a CourseVersion, a resolução permanece na
granularidade CourseVersion (compatível com o comportamento já provado em
staging em 06/10). O invariante 1:1 escopo → workspace continua valendo entre
todas as chaves. As sources passam a declarar exatamente o escopo resolvido:
`module_id` aparece somente quando um binding de módulo foi usado;
`experience_id`/`experience_type` nunca participam da resolução nem viram
atributo de fonte (`WORKSPACE_PER_EXPERIENCE=NO` mantido). O sentinel
`verify_rag_sentinel.mjs` aceita `module_id` opcional e exige `module_id` nas
sources para provar isolamento de módulo.

`MODULE_ISOLATION=SUPPORTED_BY_MODULE_BINDINGS` (TESTED-LOCAL, gateway 38/38,
sentinel tooling 8/8). `MODULE_ISOLATION_STAGING_PROOF=PENDING_GATE`: prova
real exige workspaces/bindings de módulo QA e deploy do HEAD revisado, ambos
fora desta autorização. Nenhum workspace foi criado nem provisionado; nenhuma
mutação de staging foi executada nesta execução. Chamador de experiência e
registry RAG permanente permanecem DEFERRED.

## Human gate

- **Reason:** isolamento de módulo/experiência e lifecycle/registry RAG
  permanente não foram implementados nem provados pelo sentinel CourseVersion.
- **Exact human action:** definir separadamente o lifecycle e a fronteira
  autoritativa para registry RAG permanente antes de qualquer implementação.
- **What remains unblocked:** o binding CourseVersion tem prova real A/B em
  staging; módulo/experiência e registry permanente permanecem DEFERRED.

## Prova real em staging — 2026-10-06

- Sentinel A PASS e B PASS no Worker `tutor-tds-gateway-staging`, com uma source
  cada e correspondência à CourseVersion respectiva nos workspaces QA
  `tds-qa-ctx-a-v1` e `tds-qa-ctx-b-v1`.
- Contexto A→B e troca de conta não reutilizaram sources entre escopos.
- CourseVersion desconhecida e alias curso/versão retornaram 503
  `rag_context_unresolved`.
- Versão ausente e campo extra `user_id` retornaram 400
  `invalid_learning_context`.
- Chamada legada sem contexto não fez fallback para `cartilhas`.
- O gateway chamou somente AnythingLLM; nenhum endpoint acadêmico foi chamado.
- A primeira execução revelou o header Authorization mascarado no
  `vector-search`; correção em `9994565` com teste de regressão.
- Evidência: [ai-rag-courseversion-sentinel-staging-2026-10-06.json](production/evidence/ai-rag-courseversion-sentinel-staging-2026-10-06.json).
- `AI_SERVICE_READY=SIM` somente para CourseVersion; isolamento de
  módulo/experiência e registry RAG permanente: DEFERRED.
