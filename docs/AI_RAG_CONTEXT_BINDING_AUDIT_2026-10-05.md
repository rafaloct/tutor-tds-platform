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

## Estado da arquitetura e implementação local

Sem filtro de documento/metadata, a busca por workspace é a única fronteira de
recuperação documentada que o gateway consegue selecionar. A seleção temporária
foi reduzida a `course_id|course_version_id → workspace`; módulo e experiência
são validações de sources, não seletores de workspace. CourseVersions diferentes
não podem compartilhar workspace nesse mapa. Não há fallback para
`ANYTHING_LLM_WORKSPACE`. O Worker executa `vector-search`, exige metadata
compatível nas sources, só então chama o chat em `mode=query` e confere as
citações antes de devolver o texto. Mapeamento ausente, fonte sem vínculo,
metadata incompatível ou resposta sem citação falha com
`503 rag_context_unresolved`.

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
fronteira de recuperação documentada para isolamento de módulo seria
CourseVersion + módulo em workspace separado. Nenhum workspace por experiência
é necessário ou aceitável. O workspace por módulo também não foi provisionado
nem autorizado nesta execução.

**TUTOR_RAG_SCOPE_MAP_ROLE=TEMPORARY.**
**FASTAPI_CHANGE_REQUIRED=SIM para interoperabilidade de conteúdo:** o manifesto
existente de promoção CourseVersion rejeitava campos de experiência; sua
allowlist agora valida e preserva o bloco tipado sem conceder autoridade à IA ou
criar endpoint. **FASTAPI_CHANGE_REQUIRED=UNKNOWN para o registro RAG:** o
vínculo permanente depende do lifecycle de publicação/ingestão e não pode ser
deduzido sem duplicar o catálogo. Contrato futuro a definir: CourseVersion
publicada → material aprovado → ingestão/indexação AnythingLLM com metadata
estável → registro autoritativo de `rag_scope` → gateway resolve
versão/módulo. Nenhum endpoint RAG foi criado.

O objeto é somente escopo de conteúdo e não é autorização. O gateway usa somente
IDs estáveis allowlisted; não recebe identidade, matrícula, frequência,
baseline ou reflection como contexto. No caminho estruturado, texto `context`
livre é descartado antes de AnythingLLM. `mode=query` não usa histórico e este
código não envia `sessionId`. A resposta expõe somente título público, curso,
edição, módulo e score opcional de fontes verificadas; chunk, caminho, URL,
storage ID e metadata privada não são retornados.

`FASTAPI_CHANGE_REQUIRED=NO` para o vínculo local por allowlist. Isso não
comprova que uma futura edição publicada esteja mapeada; contexto não resolvido
continua falhando fechado e não autoriza acesso acadêmico.

## Prova local e limites

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
  Actions para HEAD `2c223c0` retornou `action_required`, com zero jobs: não é
  CI PASS. O PR ainda aponta para base não canônica.
- `REAL_STAGING_E2E=NO`. O PR #132 ainda não teve seu RAG smoke real executado.
- A base do PR #136 observada no GitHub é `codex/onda-0-consolidacao`, não a
  base canônica `staging` registrada na Issue. O branch inclui a composição
  dos HEADs de #132/#135, mas o diff/CI do PR só será válido após retarget da
  base para `staging`; este agente não alterou outros PRs.
- Nenhuma chamada estruturada foi testada contra a instalação real. Nenhuma
  mutação de staging ou produção foi executada.

## Human gate

- **Reason:** sentinel contextual e metadata só podem ser comprovados em Worker
  staging isolado e com documentos QA; nenhum Worker apto nem gate para mutação
  de staging foram autorizados nesta execução.
- **Exact human action:** (1) retarget PR #136 para a base `staging`; (2) definir
  o lifecycle autoritativo de publicação/ingestão e a fronteira por módulo; (3)
  somente após isso, emitir gate específico para Worker/escopo staging isolado e
  indexação dos documentos QA `TDS_CTX_A_<versão>` e `TDS_CTX_B_<versão>`.
- **What remains unblocked:** testes locais e revisão do contrato de cliente/
  gateway. Isolamento contextual real, REAL_STAGING_E2E, merge e produção
  permanecem bloqueados.
