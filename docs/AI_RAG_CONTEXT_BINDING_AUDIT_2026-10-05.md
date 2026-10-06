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
verdade acadêmica permanente. Não foi configurado ou instalado em qualquer
ambiente. Nenhum workspace, documento, binding, secret, DNS ou Worker foi criado
ou alterado. Clientes sem `learning_context` mantêm o comportamento legado.

**RAG_SCOPE_ARCHITECTURE=BLOCKED.** A API consultada não permite provar
isolamento por módulo dentro de um workspace compartilhado: `vector-search`
não aceita filtro documentado por metadata/documento e o chat não recebe como
fronteira fechada apenas os chunks verificados na pré-busca. Por isso
`module_id`, `experience_id` e `experience_type` continuam estruturados no
request, mas não são fabricados como atributos das sources nem promovidos a
isolamento comprovado. Os testes locais provam a política CourseVersion do
gateway e a compatibilidade com o shape público do AnythingLLM, não o isolamento
real por módulo/experiência.

**RAG_SCOPE_GRANULARITY:** workspace por CourseVersion é a granularidade
temporária configurada; módulo/experiência continuam bloqueados. A menor
fronteira de recuperação documentada para isolamento de módulo exigiria uma
fronteira física distinta por módulo, se não houver capacidade upstream adicional.
Isso não está implementado, não foi provado e não autoriza provisionamento nesta
execução. Nenhum workspace por experiência é necessário ou aceitável.

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

- Fixtures de `gateway.test.js` usam o shape público auditado do
  AnythingLLM: `vector-search` com `id + metadata documental` e chat sources
  com campos no topo. Os casos provam roteamento A/B para workspaces distintos,
  rejeição de alias entre CourseVersions, correlação da citation com a
  pré-busca, descarte de identificadores privados e fail-closed para sources
  ausentes/estruturalmente inseguras. Módulo/experiência permanecem estruturados
  no request sem serem fabricados como atributos da source. O contrato mantém
  campos opcionais de experiência; não há chamador de experiência neste PR.
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
  endpoint ou metadata privada. Isso prepara a prova remota, mas não a executa.
- GitHub Actions disparados durante o incidente de disponibilidade do GitHub
  retornaram `action_required` com zero jobs; esse estado não é CI PASS nem
  falha de implementação. CI deverá ser observado novamente quando o serviço
  normalizar.
- O PR #136 permanece baseado em `staging`; a branch foi sincronizada por
  merge normal com o HEAD canônico `8f60b01`, preservando a composição dos
  HEADs #132/#135 e sem trazer WordPress/observabilidade da task quebrada.
- `REAL_STAGING_E2E=NO`. Nenhuma chamada estruturada foi feita contra a
  instalação real e nenhuma mutação de staging ou produção foi executada.

## Human gate

- **Reason:** o sentinel contextual A/B e a metadata real só podem ser
  comprovados em Worker staging isolado com dois conteúdos QA vinculados a
  CourseVersions distintas.
- **Exact human action:** autorizar um gate separado de staging para preparar os
  dois conteúdos/workspaces QA, configurar temporariamente o
  `TUTOR_RAG_SCOPE_MAP` de staging e executar o sentinel contextual A/B.
- **What remains unblocked:** revisão/CI do código e do contrato local. O
  registry autoritativo permanente continua TARGET/UNKNOWN; isolamento real de
  módulo/experiência, REAL_STAGING_E2E, merge e produção permanecem bloqueados.
