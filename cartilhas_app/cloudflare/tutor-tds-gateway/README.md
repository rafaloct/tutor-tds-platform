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
próprio. Cada CourseVersion precisa apontar para um workspace distinto, já
provisionado. Módulo e experiência não criam workspaces; suas referências são
validadas nas sources. O formato temporário da chave é
`course_id|course_version_id`. Exemplo exclusivamente sintético:

```json
{
  "course-a|version-1": "course-a-v1",
  "course-b|version-3": "course-b-v3"
}
```

O Worker faz `vector-search` antes do chat, exige metadata exata de
curso/edição/módulo e, em chamadas de experiência, experiência/tipo; usa
`mode: "query"` sem session ID. Citações do chat devem corresponder às fontes
verificadas. O retorno inclui somente título público, IDs acadêmicos verificados
e score numérico opcional; paths, IDs privados, URLs e chunks são descartados.
Mapeamento ausente, fonte sem metadata, fonte incompatível ou resposta sem
citação retorna `rag_context_unresolved`. O mapa é conteúdo de configuração,
não autorização acadêmica, e não pode conter PII.

O código oficial auditado do AnythingLLM expõe seleção por workspace, `query`
e `vector-search`, mas não documenta filtro de metadata/documento nesses
endpoints nem uma forma de fornecer ao chat somente os chunks verificados pela
busca vetorial. A instalação efetiva e a metadata dos documentos continuam
desconhecidas. Assim, validar as sources recebidas não prova que o texto gerado
não usou conteúdo de outro módulo. `RAG_SCOPE_ARCHITECTURE=BLOCKED` para
isolamento de módulo/experiência: workspace CourseVersion compartilhado é
somente uma aproximação local; workspace por versão e módulo é a menor fronteira
de recuperação documentada para isolar módulos, mas não foi configurado nem
testado remotamente. `WORKSPACE_PER_EXPERIENCE=NO`.

A arquitetura permanente deve derivar o vínculo do ciclo de publicação:
CourseVersion publicada → material aprovado → ingestão/indexação → registro de
`rag_scope` → resolução pelo gateway. `TUTOR_RAG_SCOPE_MAP` permanece
temporário até esse lifecycle ser definido. `FASTAPI_CHANGE_REQUIRED=UNKNOWN`:
depende de como ingestão e o registro autoritativo serão integrados; nenhum
endpoint foi inventado nesta mudança. Nenhum workspace foi criado ou alterado.

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
