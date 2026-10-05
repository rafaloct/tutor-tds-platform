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
  - execução remota do sentinel contextual A/B.

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
`course_id|course_version_id`, faz `vector-search`, exige metadata compatível nas
sources e chama o chat em `mode=query`. Mapeamento ausente, fonte sem vínculo,
metadata incompatível ou citação sem metadata suficiente falha com
`503 rag_context_unresolved`. Não há fallback para `ANYTHING_LLM_WORKSPACE`
quando `learning_context` está presente. Isso prova o comportamento das fixtures
locais, não o comportamento da instalação AnythingLLM.

`TUTOR_RAG_SCOPE_MAP` é somente bootstrap temporário/test fixture, não fonte de
verdade acadêmica permanente. Não foi configurado ou instalado em qualquer
ambiente. Nenhum workspace, documento, binding, secret, DNS ou Worker foi criado
ou alterado. Clientes sem `learning_context` mantêm o comportamento legado.

**RAG_SCOPE_ARCHITECTURE=BLOCKED.** A API consultada não permite provar
isolamento por módulo dentro de um workspace compartilhado: `vector-search`
retorna resultados e metadata, mas o contrato de chat não aceita filtro por
documento/metadata nem os chunks verificados como contexto fechado. A validação
de citations finais detecta fontes incompatíveis que o upstream declara, mas
não prova que o texto da resposta deixou de usar conteúdo não citado. Os testes
locais A/B provam a política do gateway para as fixtures, não o isolamento real
do retriever. Citation sem metadata que confirme curso/edição/módulo (e
experiência quando aplicável) também falha com `rag_context_unresolved`.

**RAG_SCOPE_GRANULARITY:** workspace por CourseVersion é a granularidade
temporária configurada; módulo/experiência continuam bloqueados. A menor
fronteira de recuperação documentada para isolamento de módulo exigiria uma
fronteira física distinta por módulo, se não houver capacidade upstream adicional.
Isso não está implementado, não foi provado e não autoriza provisionamento nesta
execução. Nenhum workspace por experiência é necessário ou aceitável.

**TUTOR_RAG_SCOPE_MAP_ROLE=TEMPORARY.**
**FASTAPI_CHANGE_REQUIRED=SIM_APENAS_PARA_COMPATIBILIDADE_DO_MANIFESTO.** O
delta limitado em `course_promotion` valida e preserva `Experience Blocks`
tipados no conteúdo promovido. Não adiciona campo/tabela persistente, migration,
autorização IA nem endpoint RAG.

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
código não envia `sessionId`. A resposta expõe somente título público, curso,
edição, módulo e score opcional de fontes verificadas; chunk, caminho, URL,
storage ID e metadata privada não são retornados.

## Prova local e limites

- `LOCAL_CONTEXT_BINDING_READY=PARCIAL`
- `CONTEXT_BINDING_READY=NÃO`
- `AI_SERVICE_READY=NÃO`
- `RAG_SCOPE_GRANULARITY=CourseVersion`
- `WORKSPACE_PER_EXPERIENCE=NO`
- `MODULE_ISOLATION=BLOCKED`
- `EXPERIENCE_ISOLATION=BLOCKED`
- `TUTOR_RAG_SCOPE_MAP_ROLE=TEMPORARY`
- `FASTAPI_CHANGE_REQUIRED=SIM_APENAS_PARA_COMPATIBILIDADE_DO_MANIFESTO`
- `RAG_REGISTRY_FASTAPI_CHANGE=UNKNOWN`
- `INGESTION_LIFECYCLE_DOCUMENTED=TARGET`

- Fixtures de `gateway.test.js` usam conteúdo QA distinto
  `TDS_CTX_A_v1`/`TDS_CTX_B_v3`; verificam A→A e B→B, rejeição cruzada,
  CourseVersion compartilhada por módulos com rejeição de source cruzada,
  metadata de experiência exata, fonte ausente, metadata ausente/incompatível,
  citação cruzada e whitelisting de sources. **TESTED-LOCAL** comprova o filtro
  de saída do gateway, não o isolamento do retriever.
- Os HEADs autorizados de PR #132
  (`0c1d80992d6fe60b4c3143677a923b7c64883429`) e PR #135
  (`039c247873ed6d08bc33d7040cdbdb781ab1c108`) foram integrados localmente ao
  branch do PR #136. A chamada geral passa curso/versão/módulo sem experiência;
  o botão de uma experiência fornece também seu ID/tipo estáveis e prompt
  inicial, sem dados da conta.
- O manifesto existente de promoção CourseVersion agora aceita somente Experience
  Blocks tipados e os preserva no snapshot; testes de contrato cobrem campos
  desconhecidos, IDs/tipos inválidos e configurações de IA malformadas.
- Validação local: gateway `32/32` e `api/tests/test_course_promotion.py` `10/10`;
  Flutter test/analyze não executados (`flutter`/`dart` ausentes). GitHub
  Actions mais recentes do PR #136 retornaram `action_required`, com zero jobs:
  não é CI PASS. A revisão automática não pôde carregar o modelo; CodeQL
  reportou zero alertas Python, mas a análise JavaScript expirou, então a
  validação de segurança ficou incompleta. O PR ainda aponta para base não
  canônica.
- `REAL_STAGING_E2E=NO`. O PR #132 ainda não teve seu RAG smoke real executado.
- A base do PR #136 observada no GitHub é `codex/onda-0-consolidacao`, não a
  base canônica `staging` registrada na Issue. O retarget e a atualização do
  corpo do PR não estão disponíveis pelas ferramentas desta execução; exigem
  ação do coordenador. O HEAD conserva a composição dos HEADs de #132/#135.
- Nenhuma chamada estruturada foi testada contra a instalação real. Nenhuma
  mutação de staging ou produção foi executada.

## Human gate

- **Reason:** sentinel contextual e metadata só podem ser comprovados em Worker
  staging isolado e com documentos QA; nenhum Worker apto nem gate para mutação
  de staging foram autorizados nesta execução.
- **Exact human action:** (1) retarget PR #136 para `staging` e atualizar seu
  corpo com o estado documentado; (2) confirmar o lifecycle automático e o
  registry autoritativo futuro; (3) liberar/autorizar Actions para a origem do
  agente, se exigido pela política do GitHub.
- **What remains unblocked:** testes locais e revisão do contrato de cliente/
  gateway. Após base correta e CI verde, um gate staging separado ainda será
  necessário. Isolamento real de módulo/experiência, REAL_STAGING_E2E, merge e
  produção permanecem bloqueados.
