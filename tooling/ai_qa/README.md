# QA sintético contextual do RAG do Tutor IA

Este diretório contém tooling **staging-only** para provar isolamento contextual
A/B sem credenciais, PII ou persistência de perguntas/respostas. Ele não executa
automaticamente e não altera Worker, AnythingLLM, workspace, provider ou billing.

## Pré-requisito humano

Preparar dois conteúdos QA distintos, cada um vinculado a uma CourseVersion
diferente e ao workspace de staging correspondente. Exemplo:

```text
contexto A -> TDS_CTX_A_v1
contexto B -> TDS_CTX_B_v3
```

Os marcadores devem existir somente nos documentos QA do respectivo contexto.
Não inserir os marcadores em cartilhas ou workspaces de produção.

O Worker staging também precisa resolver as duas CourseVersions pelo
`TUTOR_RAG_SCOPE_MAP` temporário do candidato. Isso é bootstrap de QA, não
registro acadêmico autoritativo.

## Execução autorizada

Somente depois de autorização explícita de staging, usar variáveis efêmeras:

```powershell
$env:TDS_AI_QA_ENV = 'staging'
$env:TDS_AI_SENTINEL_URL = 'https://SEU-WORKER-STAGING.example'
$env:TDS_AI_SENTINEL_MARKER_A = 'TDS_CTX_A_v1'
$env:TDS_AI_SENTINEL_MARKER_B = 'TDS_CTX_B_v3'
$env:TDS_AI_SENTINEL_CONTEXT_A = '{"course_id":"curso-a","course_version_id":"versao-a"}'
$env:TDS_AI_SENTINEL_CONTEXT_B = '{"course_id":"curso-b","course_version_id":"versao-b"}'
node tooling/ai_qa/verify_rag_sentinel.mjs
```

O sentinel remoto deste gate aceita deliberadamente **somente** `course_id` e
`course_version_id`. Módulo e experiência continuam no contrato geral do
`learning_context`, porém seu isolamento ainda é `BLOCKED`; incluí-los nesta
prova produziria uma conclusão mais forte do que o AnythingLLM auditado permite.

O script recusa:

- ambiente diferente de `staging`;
- URL sem HTTPS ou hostname sem rótulo `staging`;
- marcadores iguais;
- contextos inválidos ou iguais;
- contexto que tente ampliar a prova além de CourseVersion;
- resposta sem sources compatíveis com a CourseVersion;
- marcador A ausente em A ou marcador B aparecendo em A;
- marcador B ausente em B ou marcador A aparecendo em B.

A pergunta enviada não contém o marcador esperado, para impedir um PASS por
simples eco do prompt.

## Evidência emitida

A saída contém somente:

- timestamp e ambiente;
- rótulo A/B;
- status HTTP e latência;
- `X-Request-Id`;
- quantidade de sources;
- PASS/FAIL da compatibilidade de sources;
- PASS/FAIL do sentinel;
- categoria de erro sanitizada.

Não imprime prompt, resposta, marcador, endpoint, título de source, metadata
privada ou segredo.

## Interpretação

`contextual_rag_sentinel=PASS` exige PASS em A e B. Isso comprova pontualmente
que o gateway staging recuperou o marcador da CourseVersion correta e que as
sources declaradas correspondem ao binding CourseVersion → workspace. Não prova
isolamento de módulo/experiência e ainda não transforma AnythingLLM
em autoridade acadêmica e não autoriza produção ou merge.

Os testes locais deste diretório validam apenas os guardrails pré-rede. A prova
real A/B depende de Worker e documentos QA de staging autorizados.
