# QA sintético do RAG do Tutor IA

Este diretório contém somente uma prova **staging-only**, sem credenciais e sem
persistir perguntas ou respostas. Ele não executa automaticamente e não altera
Worker, AnythingLLM, workspace, provider ou billing.

## Pré-requisito humano

Criar, no workspace de staging autorizado do AnythingLLM, um documento de QA
sem PII contendo um marcador versionado único, por exemplo:

```text
TDS_AI_SENTINEL=2026-10-05-r1
```

Depois confirmar a indexação desse documento no workspace que o Worker de
staging usa. Não inserir o marcador em cartilha pedagógica ou workspace de
produção.

## Execução autorizada

Em uma sessão com a URL de **staging** já autorizada, use variáveis de ambiente
efêmeras (sem secret):

```powershell
$env:TDS_AI_QA_ENV = 'staging'
$env:TDS_AI_SENTINEL_URL = 'https://SEU-WORKER-STAGING.example'
$env:TDS_AI_SENTINEL_MARKER = 'TDS_AI_SENTINEL=2026-10-05-r1'
node tooling/ai_qa/verify_rag_sentinel.mjs
```

O script recusa qualquer ambiente que não seja literalmente `staging` e qualquer
hostname sem o rótulo `staging` (por exemplo, `worker-staging.example`). Isso
impede que uma variável local mal configurada aponte para produção. Ele
envia uma pergunta sintética, imprime somente timestamp, status HTTP, latência,
`X-Request-Id`, categoria de erro e PASS/FAIL do marcador. Não imprime prompt,
resposta, endpoint nem segredo.

## Interpretação

| Resultado | Conclusão limitada |
| --- | --- |
| HTTP 200 + `rag_sentinel=PASS` | Gateway, AnythingLLM, provider e recuperação do documento sentinela responderam nessa chamada. |
| HTTP 200 + `rag_sentinel=FAIL` | O modelo respondeu, mas não há prova de que recuperou o workspace/documento TDS correto. |
| 429 | Limite de taxa observável; investigar Cloudflare, AnythingLLM e provider com `request_id`. |
| 504 / `upstream_timeout` | O Worker alcançou seu limite de upstream; não prova indisponibilidade permanente. |
| 503 / `service_unavailable` | Falha sanitizada de configuração, rede ou upstream; correlacionar o `request_id` nos logs do Worker. |

Um PASS é uma evidência pontual de staging — não autoriza produção, merge ou
mudança de configuração.
