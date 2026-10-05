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

## Escolha de implementação local

Sem filtro de documento/metadata, a busca por workspace é a única fronteira de
recuperação documentada que o gateway consegue selecionar. Chamadas estruturadas
usam um allowlist de configuração `TUTOR_RAG_SCOPE_MAP`, indexado pela tupla
exata curso/edição/módulo/experiência/tipo. Cada chave precisa resolver a um
workspace exclusivo; aliases entre tuplas são rejeitados. Não há fallback para
`ANYTHING_LLM_WORKSPACE`. O Worker executa `vector-search`, exige metadata
compatível nas fontes, só então chama o chat em `mode=query` e confere as
citações antes de devolver o texto. Fonte sem vínculo, resultado ambíguo ou
metadata incompatível falha com `503 rag_context_unresolved`.

`TUTOR_RAG_SCOPE_MAP` está ausente da configuração versionada e não foi
instalado em qualquer ambiente. O caminho estruturado, portanto, fica
deliberadamente indisponível até existir um mapa e conteúdo isolado aprovados.
Nenhum workspace, documento, binding, secret, DNS ou Worker foi criado ou
alterado. Clientes sem `learning_context` mantêm o comportamento legado.

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
  mistura A+B, fonte ausente, metadata ausente/incompatível, citação cruzada e
  whitelisting de fontes. **TESTED-LOCAL**, não staging.
- `REAL_STAGING_E2E=NO`. PR #132 permanece aberto e draft; seu RAG smoke real
  ainda não foi executado. O PR #135 de Dynamic Learning permanece aberto e
  contém a integração de experiência que não está nesta base local.
- A base do PR #136 observada no GitHub é `codex/onda-0-consolidacao`, não a
  base canônica `staging` registrada na Issue. Esse empilhamento precisa ser
  corrigido pelo fluxo do PR depois das dependências; não foi alterada outra
  branch nem outro PR.
- Nenhuma chamada estruturada foi testada contra a instalação real. Nenhuma
  mutação de staging ou produção foi executada.

## Human gate

- **Reason:** sentinel contextual e metadata só podem ser comprovados em Worker
  staging isolado e com documentos QA; nenhum Worker apto nem gate para mutação
  de staging foram autorizados nesta execução.
- **Exact human action:** emitir gate específico autorizando Worker/escopo staging
  isolado, mapa e indexação dos dois documentos QA `TDS_CTX_A_<versão>` e
  `TDS_CTX_B_<versão>`, sem uso de workspace ou documento de produção.
- **What remains unblocked:** testes locais, revisão de código e integração
  futura após PR #132 e Dynamic Learning #135; staging E2E, merge e produção
  permanecem bloqueados.
