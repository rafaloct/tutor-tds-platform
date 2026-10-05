# Homologação de autorização por perfil — staging

Data: 2026-10-04
Escopo: API; não cria telas, conteúdo ou dados permanentes.

## Matriz esperada

| Perfil | Endpoint/ação | Escopo | Esperado |
| --- | --- | --- | --- |
| Aluno | `GET /classes` e rotas acadêmicas | somente a própria matrícula ativa | `200` apenas no próprio contexto; `403` fora dele |
| Professor | `GET /classes/{id}/dashboard`, `eligible-students`, `PUT students/{user_id}` | turma cujo `teacher_id` e vínculo ativo coincidam | `200`; outra turma `403` |
| Monitor | `GET /classes/{id}` e exceções explicitamente liberadas | monitor vinculado à turma | somente as exceções permitidas |
| Monitor | `GET /analytics/usage`, `GET /classes/{id}/dashboard`, `GET /classes/{id}/eligible-students`, `PUT students/{user_id}`, revisão/emissão de certificado | qualquer escopo | `403` |
| Admin | criar vínculo, turma e matrícula; repetir vínculo | escopo institucional autorizado | criação `201`; duplicidade `409` |
| Admin/operador | `POST /operations/{class_id}/commands` com `action=revoke` | vínculo de aluno na turma | vínculo fica inativo; token anterior perde rotas dependentes desse vínculo |
| Conta revogada | rotas de turma, evidência, horas, analytics, fila offline/requisições | token emitido antes da revogação | `401` ou `403`, nunca conteúdo/ação autorizada |

## Roteiro físico de staging

1. Usar contas de teste identificáveis (admin, professor, monitor, aluno A e aluno B), todas no mesmo programa, e uma segunda turma para o professor fora de escopo.
2. Com admin, criar vínculo de programa, matrícula e turma; repetir o vínculo para confirmar `409`.
3. Autenticar cada perfil e registrar somente código HTTP para todos os endpoints da matriz.
4. Com professor, validar a própria turma (`200`) e a segunda turma (`403`).
5. Com monitor, confirmar `403` para analytics, dashboard, listagem/inclusão de alunos, fila/revisão e emissão de certificado.
6. Emitir token do aluno A, revogar o vínculo por `POST /operations/{class_id}/commands` com `action: revoke`, e repetir chamadas de turma, eventos/evidências, horas e analytics usando **o token anterior**.
7. Remover exclusivamente as contas e vínculos de teste criados para este roteiro; não alterar contas gerenciadas.

## Observação executada em 2026-10-04

O container ativo respondeu `200` para login e `GET /auth/me` de admin, professor e monitor. A fila de revisão de certificado do monitor respondeu `403`.

Não havia turma retornada para professor ou monitor naquele ambiente; portanto não foi possível afirmar os resultados de escopo de turma, revogação, criação/duplicidade ou analytics com contexto real. Esses itens permanecem **pendentes de dados de teste isolados e do deploy deste PR**. Nenhum dado foi criado ou alterado durante a observação.

Em ambiente de teste da API, `tests/test_operator_operations.py` passou com 10 cenários, incluindo a revogação de um vínculo de aluno por turma e a rejeição de replay por operador revogado. Isto é cobertura automatizada; não substitui a execução física em staging.

## Limite conhecido

O comando operacional de revogação atualmente inativa o vínculo do aluno na turma. Ele não é prova de desativação global de uma conta de equipe; tal fluxo exige uma política e endpoint próprios antes de ser declarado como revogação total.
