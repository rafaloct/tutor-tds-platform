# Gateway do Tutor TDS — Cloudflare Workers

Este Worker mantém o endereço usado pelo aplicativo estável e encaminha as
perguntas para o AnythingLLM hospedado no VPS/Dokploy. Nenhuma chave de IA é
incluída no Flutter ou no AAB.

## Onde cada configuração fica

| Configuração | Onde alterar | Exige novo AAB? |
| --- | --- | --- |
| Chave e provedor do modelo | Painel administrativo do AnythingLLM no VPS | Não |
| Modelo usado pelo workspace | Workspace `cartilhas` no AnythingLLM | Não |
| Chave de acesso do Worker ao AnythingLLM | Secret `ANYTHING_LLM_API_KEY` na Cloudflare | Não |
| URL do AnythingLLM | Variável `ANYTHING_LLM_BASE_URL` na Cloudflare | Não |
| Workspace | Variável `ANYTHING_LLM_WORKSPACE` na Cloudflare | Não |
| URL pública do Worker | `TUTOR_GATEWAY_URL` no build Flutter | Sim, apenas se a URL mudar |
| Assinatura dos certificados | Secret `CERTIFICATE_SIGNING_SECRET` na Cloudflare | Não |
| Registros dos certificados | KV binding `CERTIFICATES` | Não |

## Primeira publicação

No diretório deste Worker:

```powershell
npm install
npx wrangler login
npx wrangler deploy
```

Depois, abra **Cloudflare Dashboard > Workers & Pages > tutor-tds-gateway >
Settings > Variables and Secrets** e cadastre:

- `ANYTHING_LLM_API_KEY`: tipo **Secret**;
- `ANYTHING_LLM_BASE_URL`: texto, por exemplo
  `https://ia-tutor.ipexdesenvolvimento.cloud`;
- `ANYTHING_LLM_WORKSPACE`: texto, normalmente `cartilhas`;
- `TUTOR_SYSTEM_PROMPT`: texto opcional para o gestor ajustar as instruções do
  Tutor sem atualizar o app;
- `ALLOWED_ORIGINS`: opcional e útil apenas para Flutter Web, com origens
  separadas por vírgula.
- `CERTIFICATE_SIGNING_SECRET`: Secret aleatório de alta entropia, separado da
  chave de IA. Não troque sem planejar a migração dos registros existentes.

O `wrangler.jsonc` também precisa manter o binding KV `CERTIFICATES`. A versão
atual já aponta para o namespace de produção criado para este Worker.

Não coloque o valor da chave em arquivos versionados nem em comandos que a
gravem no histórico. Como alternativa ao painel, `npx wrangler secret put
ANYTHING_LLM_API_KEY` solicita o valor de forma interativa.

O `keep_vars` do `wrangler.jsonc` preserva as variáveis cadastradas no painel
quando uma nova versão do código do Worker for publicada.

## Testar

```powershell
npm test
Invoke-RestMethod https://SEU-WORKER.workers.dev/health
```

Teste do chat, sem nenhuma chave no computador cliente:

```powershell
$body = @{ message = 'Explique o que é agricultura familiar'; mode = 'tutor' } |
  ConvertTo-Json
Invoke-RestMethod https://SEU-WORKER.workers.dev/v1/chat `
  -Method Post -ContentType 'application/json' -Body $body
```

O endpoint `POST /v1/study` gera materiais estruturados. Os tipos aceitos são
`flashcards`, `quiz`, `summary` e `exam`; o Flutter envia apenas o título da
cartilha, dificuldade, quantidade e tamanho do resumo. Exemplo:

```powershell
$body = @{
  kind = 'flashcards'
  topic = 'Cooperativismo'
  difficulty = 'basic'
  count = 5
} | ConvertTo-Json
Invoke-RestMethod https://SEU-WORKER.workers.dev/v1/study `
  -Method Post -ContentType 'application/json' -Body $body
```

Os prompts, o workspace e os esquemas JSON ficam no servidor. A resposta do
modelo só é entregue ao app depois de passar pela normalização estrutural e
pelos limites de tamanho do Worker.

## Vínculo contextual do Tutor

`POST /v1/chat` aceita opcionalmente `learning_context` com IDs acadêmicos
estáveis de curso e edição, módulo e experiência. O cliente legado sem esse
objeto continua usando o workspace configurado em `ANYTHING_LLM_WORKSPACE`.
Para chamadas estruturadas, o Worker exige uma entrada exata para
`course_id|course_version_id` em `TUTOR_RAG_SCOPE_MAP`; não usa o workspace
legado como fallback. O mapa é somente bootstrap temporário e não é catálogo
acadêmico nem fonte de verdade permanente.

`TUTOR_RAG_SCOPE_MAP` é uma variável JSON do Worker administrada após um gate
próprio. Cada escopo precisa apontar para um workspace distinto, já
provisionado; o mapa rejeita duas chaves diferentes apontando para o mesmo
workspace. O formato da chave é `course_id|course_version_id` ou, quando a
implantação declara granularidade de módulo,
`course_id|course_version_id|module_id`. Exemplo exclusivamente sintético:

```json
{
  "course-a|version-1|module-a1": "course-a-v1-m1",
  "course-a|version-1|module-a2": "course-a-v1-m2",
  "course-b|version-3": "course-b-v3"
}
```

Com `module_id` no contexto, o Worker tenta primeiro a chave de três segmentos.
Se o mapa contém qualquer binding de módulo para aquela CourseVersion mas não
para o módulo pedido, a chamada falha fechada com `rag_context_unresolved`:
ampliar silenciosamente para o workspace da edição quebraria o isolamento de
módulo declarado. Se nenhuma chave de módulo existe para a CourseVersion, a
granularidade declarada é CourseVersion e a chave de dois segmentos resolve o
pedido. Contexto sem `module_id` resolve somente pela chave de dois segmentos.

O Worker faz `vector-search` no workspace do escopo resolvido antes do
chat e depois chama o mesmo workspace em `mode: "query"`, sem session ID. O
contrato público auditado do AnythingLLM devolve no `vector-search` somente
metadata documental genérica, como `title`, `docSource` e `chunkSource`;
ele não preserva `course_id`, `course_version_id`, `module_id` ou
`experience_id`. Por isso, o escopo é derivado do binding 1:1
escopo → workspace, e nunca de metadata acadêmica inventada.

As citations do chat usam o shape real de source do AnythingLLM, com campos no
topo do objeto. O gateway exige correspondência com uma fonte já observada no
`vector-search`, usando ID privado quando presente e título/document source
como evidência adicional. Esses identificadores servem apenas internamente e
não são devolvidos ao app. O retorno público contém somente título,
`course_id`, `course_version_id`, score opcional e, somente quando a resolução
usou um binding de módulo, `module_id` — a source declara exatamente o escopo
efetivamente resolvido. Paths, IDs privados, URLs, chunks e metadata interna
são descartados.

`module_id`, `experience_id` e `experience_type` continuam aceitos e
validados no `learning_context`. `module_id` participa da resolução de escopo
quando existe um binding de módulo para a CourseVersion; sem binding, a
granularidade efetiva permanece CourseVersion e a fonte não declara
`module_id`. `experience_id` e `experience_type` nunca participam da resolução
de escopo nem aparecem como atributos da fonte: não há workspace por
experiência. O AnythingLLM auditado não oferece filtro documentado por
metadata/documento capaz de fechar essa fronteira dentro de um workspace
compartilhado. Assim, `RAG_SCOPE_GRANULARITY=CourseVersion|Module (por
binding)`, `MODULE_ISOLATION=SUPPORTED_BY_MODULE_BINDINGS`,
`EXPERIENCE_ISOLATION=BLOCKED` e `WORKSPACE_PER_EXPERIENCE=NO`.

Mapeamento ausente, source estruturalmente insegura, citation que não corresponde
à pré-busca ou erro upstream falha fechado com `rag_context_unresolved` ou o
erro sanitizado aplicável. O mapa é configuração temporária de conteúdo, não
autorização acadêmica, e não pode conter PII.

A arquitetura permanente deve derivar o vínculo do ciclo de publicação:
CourseVersion publicada → material aprovado → ingestão/indexação → registro de
`rag_scope` → resolução pelo gateway. `TUTOR_RAG_SCOPE_MAP` permanece
temporário até esse lifecycle ser definido. O contrato existente de promoção
CourseVersion agora valida e preserva Experience Blocks tipados. A necessidade
de mudança FastAPI para o futuro registro autoritativo de RAG continua
`UNKNOWN`; nenhum endpoint RAG foi inventado. Nenhum workspace foi criado ou
alterado.

## Certificados

`POST /v1/certificates` aceita somente cartilhas presentes na lista fechada do
Worker e exige que a quantidade de perguntas respondidas corresponda ao
catálogo. Exemplo de corpo da requisição:

```json
{
  "holderName": "Nome da pessoa",
  "cpf": "000.000.000-00",
  "courseId": "cooperativismo",
  "answeredQuestions": 4,
  "totalQuestions": 4
}
```

O CPF é validado, usado em um HMAC de deduplicação e descartado. O KV armazena
somente o HMAC e os campos públicos: nome, cartilha, emissão, identificador,
URL, hash e assinatura. Nunca registre o corpo dessa requisição em logs.

- `GET /v1/certificates/ID` retorna JSON e `valid: true` somente após recompor
  SHA-256 e HMAC.
- `GET /verify/ID` entrega a página pública usada pelo QR Code.

O QR e a assinatura comprovam que o registro foi emitido pelo Worker e não foi
alterado. A conclusão ainda é declarada pelo app cliente; para elevar o nível de
garantia, integre Play Integrity e progresso assinado no servidor em uma versão
posterior.

## Operação e segurança

- O Worker valida tamanho, formato, tipo de estudo e modo; usa timeout e não devolve erros
  internos do VPS.
- O código não registra perguntas, respostas ou dados pessoais.
- O certificado guarda nome e dados públicos de conclusão no KV mediante
  consentimento específico no app; CPF e WhatsApp não são armazenados.
- CORS não autentica um aplicativo Android. Configure limites de gasto no
  provedor do modelo e monitore as requisições na Cloudflare/AnythingLLM.
- Antes de ampliar a divulgação, aplique rate limiting na conta Cloudflare.
  Se houver abuso relevante, a próxima etapa é validar Play Integrity no
  gateway; isso pode ser acrescentado sem mudar o contrato `/v1/chat`.
- Para um serviço de segurança, prefira comportamento *fail closed* quando o
  limite da Cloudflare for atingido.

## Trocar a chave futuramente

1. Gere/revogque a credencial no AnythingLLM ou no provedor correspondente.
2. Se for a chave do provedor do modelo, atualize-a no painel do AnythingLLM.
3. Se for a chave da API do AnythingLLM, edite o Secret
   `ANYTHING_LLM_API_KEY` na Cloudflare e publique a alteração.
4. Faça uma chamada a `/health` e uma pergunta de teste.

O AAB instalado pelos usuários continua funcionando porque a URL pública do
Worker não mudou.
