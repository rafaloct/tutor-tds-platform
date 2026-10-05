# Auditoria da cadeia do Tutor IA — 2026-10-05

## Escopo e evidência

**OBSERVED:** auditoria estática no SHA `a5e3704c0b0de1e92c84e9623730c9480563fa87`
e testes unitários locais do Worker. Não houve leitura de secrets, deploy,
mudança em staging ou chamada para serviços reais.

**UNKNOWN/BLOCKED:** o GitHub CLI desta sessão retornou `401`; portanto, os
estados atuais de Issues/PRs #32, #88, #129/#130 e demais PRs não foram
confirmados. Nenhum arquivo em `tools/observability/**`, `api/**`, operações,
auth, migrações ou testes de emulador foi alterado.

## Mapa factual de `POST /v1/chat`

```text
Flutter AnythingLLMService (POST, timeout 30 s)
  -> TUTOR_GATEWAY_URL/v1/chat
  -> Cloudflare Worker tutor-tds-gateway
  -> HTTPS /api/v1/workspace/{ANYTHING_LLM_WORKSPACE}/chat
  -> AnythingLLM (mode=chat, system_prompt)
  -> provider/modelo e RAG configurados dentro do AnythingLLM
  -> { textResponse | text }
  -> { text } para o Flutter
```

| Aspecto | Classificação | Evidência |
| --- | --- | --- |
| Request | OBSERVED | JSON: `message` obrigatório (até 8.000 caracteres), `mode` opcional (`tutor`/`adaptive`) e `context` opcional string (até 1.000). Corpo máximo: 16.384 bytes. |
| Resposta de sucesso | OBSERVED | `200 {"text":"..."}`; o Flutter também aceita o legado `textResponse`. |
| Contexto | OBSERVED | É incorporado ao `system_prompt` apenas se não vazio, como dado não-instrucional. Não há seleção de workspace por contexto. |
| CORS | OBSERVED | `ALLOWED_ORIGINS` permite apenas origens listadas; se vazio, permite `*`. Não é autenticação Android. |
| Timeout | OBSERVED | Worker usa `AbortSignal.timeout(25.000)` no upstream; Flutter expira em 30 s. |
| Retry | OBSERVED | Não há retry no Worker nem no Flutter. |
| Upstream | OBSERVED | AnythingLLM: `POST /api/v1/workspace/{workspace}/chat`, Bearer secret, `mode: chat`. |
| Workspace | OBSERVED no contrato, UNKNOWN em ambiente | Obtido de `ANYTHING_LLM_WORKSPACE`; o valor efetivo não foi lido. README cita `cartilhas`. |
| Provider/modelo | TARGET/UNKNOWN | Mapa de serviços cita OpenRouter/Gemini 2.5 Flash Lite; código não conhece nem confirma o modelo efetivo. |
| RAG TDS | TARGET/UNKNOWN | Prompt pede conteúdo recuperado, mas a resposta da API não contém fonte, workspace ou sinal de recuperação. |
| 401/403/404 upstream | OBSERVED | Agora retornam `503 service_unavailable`, sem detalhes internos. |
| 408/504 ou abort | OBSERVED | Agora retornam `504 upstream_timeout`. |
| 429 upstream | OBSERVED | Agora retorna `429 rate_limited`. |
| 5xx upstream | OBSERVED | Retorna `503 service_unavailable`; payload interno é descartado. |
| JSON inválido/sem texto | OBSERVED | `502 invalid_upstream_response` ou `502 empty_upstream_response`. |
| Logs/métricas | UNKNOWN/BLOCKED | O código não registra logs nem emite métricas. `X-Request-Id` é gerado e encaminhado ao upstream, mas a retenção/consulta depende da configuração externa. |

## Matriz de homologação

| Camada | Resultado | Evidência / bloqueio |
| --- | --- | --- |
| Flutter -> `/v1/chat` | OBSERVED / BLOCKED | Serviço usa URL configurada, JSON e timeout de 30 s; ainda transforma todas as falhas em mensagem amigável. O novo teste focal não iniciou nesta máquina. |
| Worker recebe e valida | TESTED-LOCAL | 20 testes Node cobrem happy path, CORS, tamanho, contexto, timeout, 429, 5xx e payloads inválidos. |
| AnythingLLM disponível | UNKNOWN | Nenhum smoke real autorizado. |
| Workspace correto | UNKNOWN | Nome vem de secret; não há evidência de valor/configuração atuais. |
| Provider/modelo | UNKNOWN | Controlado fora do repositório. |
| RAG TDS | UNKNOWN | Sentinela implementada, mas documento/indexação/execução de staging dependem de gate humano. |
| Erro observável | IMPLEMENTED / BLOCKED | Contrato agora expõe categoria sanitizada e `X-Request-Id`; logs, métricas e alertas externos ainda não existem no código. |

## Mudança e testes desta auditoria

O Worker agora gera um `X-Request-Id` opaco por chamada e o envia também ao
AnythingLLM. Adicionou classificação sanitizada de timeout e rate limit, sem
retornar URL interna, corpo upstream ou segredo. `npm test` em
`cartilhas_app/cloudflare/tutor-tds-gateway` passou: **20/20**.

Foi adicionado o teste focal Flutter
`test/anything_llm_service_test.dart` para contrato, fallback e contexto vazio.
**BLOCKED:** nesta máquina, duas tentativas de `flutter test` pararam na carga
do arquivo após a resolução de dependências, antes de executar qualquer caso.
O junction histórico de SDK também aponta para uma cópia diferente do app. Não
foi alterado o SDK, o junction nem a configuração do projeto.

## Sentinela RAG

`tooling/ai_qa/verify_rag_sentinel.mjs` é uma prova read-only, bloqueada para
qualquer ambiente diferente de `staging`. O procedimento em
`tooling/ai_qa/README.md` exige um documento QA sem PII e um marcador
versionado. Ela distingue resposta do modelo sem marcador de recuperação
comprovada do marcador, sem imprimir a resposta.

## Observabilidade mínima proposta (sem implementar infraestrutura)

Registrar por evento somente: `request_id`, ambiente, revisão do Worker,
status, latência total/upstream, categoria sanitizada, timeout, rate limit,
alias de modelo aprovado, identificador/versionamento de workspace e
`rag_sentinel_ok`. Nunca registrar por padrão mensagem, contexto, resposta,
CPF, nome, telefone, user_id acadêmico, baseline, frequência, API keys, tokens
ou URL interna. A retenção, acesso e alertas são **DECISION/HUMAN_GATE** e não
podem ser escolhidos pelo Worker isoladamente.

## Impedimentos para `AI_SERVICE_READY=true`

1. **HUMAN_GATE:** autenticar GitHub e revalidar ownership/colisões de #32,
   #88 e #129/#130 antes de abrir o draft PR.
2. **HUMAN_GATE:** fornecer endpoint staging autorizado, confirmar que não é
   produção, e criar/indexar o documento sentinela no workspace staging.
3. **UNKNOWN:** executar a sentinela e guardar apenas a evidência sanitizada.
4. **HUMAN_GATE:** habilitar consulta a logs/métricas do Worker e decidir
   retenção, acesso e alertas para os campos sanitizados.
5. **UNKNOWN:** confirmar no AnythingLLM o workspace, provider/modelo,
   fallback e comportamento de RAG sem resultado.
6. **GAP Flutter:** o app ainda não mostra `request_id` nem categoria de erro;
   ele oferece somente fallback amigável. Alteração de UX não foi feita porque
   não foi comprovada necessária para a chamada em si.
