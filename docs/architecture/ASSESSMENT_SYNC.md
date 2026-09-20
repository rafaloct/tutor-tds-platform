# Tutor TDS - Sincronização de quiz e simulado

## Objetivo e autoridade

`assessment_contents` preserva uma versão imutável do deck e
`assessment_attempts` guarda somente o estado mutável da tentativa. Isso
permite que o aluno continue uma tentativa em outro dispositivo sem colocar
enunciados, alternativas ou gabarito na fila de progresso. Cada registro tem
`owner_id` no banco
e só pode ser lido ou alterado pelo próprio token de estudante. Não há leitura
administrativa nesta fase: suporte e relatórios não justificam expor respostas
individuais.

O aluno precisa ter matrícula ativa em um curso ativo para criar ou atualizar
uma tentativa. Leituras continuam disponíveis ao titular para permitir acesso
a seus próprios dados. Um `attempt_id` pertencente a outra pessoa responde
`404`, inclusive no `PUT`, para não confirmar a existência do registro.

O `score` sincronizado é estado do cliente para retomada e feedback. Ele não é
prova autoritativa de conclusão, presença, certificado ou remuneração.

## Endpoints

```text
PUT /assessment-contents/{assessment_content_id}
GET /assessment-contents/{assessment_content_id}
PUT /assessment-attempts/{attempt_id}
GET /assessment-attempts/{attempt_id}
GET /assessment-attempts/{attempt_id}/content
GET /assessment-attempts?course_id={id}&mode=quiz|exam&completed=true|false&limit=50&offset=0
```

`exam` é o identificador canônico do modo exibido como **Simulado** no app.
A listagem é ordenada por `updated_at` decrescente e sempre retorna apenas os
registros do aluno autenticado.

## Conteúdo versionado e gabarito

O aparelho que gerou o deck escolhe um `assessment_content_id` estável e faz
um `PUT` antes da primeira tentativa. O corpo contém `course_id`, `topic`,
`mode`, `title`, `duration_seconds` e de 1 a 100 questões:

```json
{
  "course_id": "cooperativismo",
  "topic": "Princípios do cooperativismo",
  "mode": "exam",
  "title": "Simulado de cooperativismo",
  "duration_seconds": 1200,
  "questions": [{
    "question": "Qual é o princípio?",
    "options": ["A", "B", "C"],
    "correct_index": 1,
    "explanation": "Explicação pedagógica.",
    "topic": "Princípios"
  }]
}
```

A primeira gravação responde `201`; retry byte-semanticamente equivalente
responde `200`. Reutilizar o ID com conteúdo divergente responde `409` com
`assessment_content_immutable`. O banco armazena digest SHA-256 canônico e uma
trigger impede `UPDATE`; uma mudança de deck exige novo ID. O digest completo
é interno e não é enviado ao cliente, pois poderia ajudar a testar combinações
de gabarito.

As respostas de criação e `GET /assessment-contents/{id}` contêm apenas
`question`, `options` e `topic`; `answer_key` é `null`. Para hidratar outro
aparelho, use `GET /assessment-attempts/{attempt_id}/content`. Enquanto a
tentativa estiver aberta, esse endpoint também retorna `answer_key: null`.
Após conclusão imutável, passa a retornar uma lista alinhada às questões com
`correct_index` e `explanation`. Conteúdo e tentativa só podem ser acessados
pelo próprio aluno; IDs de terceiros respondem `404`.

O modelo atual é destinado a decks gerados para o próprio aluno e continua
não autoritativo para certificado/remuneração. O cliente de origem já conhece
o gabarito que enviou; o contrato evita vazá-lo ao segundo dispositivo antes
da conclusão. Bancos de questões institucionais futuros devem ter autoria e
publicação server-side separadas.

## Payload e resposta da tentativa

O `PUT` recebe somente estado estruturado. Não enviar deck, enunciados,
alternativas, respostas corretas, prompts, justificativas ou `weakTopics`.

```json
{
  "course_id": "cooperativismo",
  "assessment_content_id": "content_exam_01J...",
  "topic": "Princípios do cooperativismo",
  "mode": "exam",
  "revision": 2,
  "answers": {"0": 2, "1": 1},
  "marked": [3],
  "current_index": 2,
  "remaining_seconds": 420,
  "completed": false,
  "score": 0,
  "updated_at": "2026-09-20T15:30:00Z"
}
```

A resposta repete o payload e acrescenta `attempt_id`. Novas tentativas sem
`assessment_content_id` são recusadas com `assessment_content_required`.
`updated_at` exige fuso
horário. As chaves de `answers` são índices decimais canônicos; seus valores são
índices de alternativa. `marked` contém índices únicos e é normalizado em ordem
crescente. O cliente sempre envia `score: 0`; ao concluir, o servidor calcula
o score a partir de `answers` e do gabarito interno. Tentativa concluída exige
`remaining_seconds: 0` e se torna imutável. Índices de questão/alternativa,
marcadores, posição e tempo são validados contra o conteúdo versionado.

A listagem usa o envelope:

```json
{
  "attempts": [],
  "total": 0,
  "limit": 50,
  "offset": 0
}
```

## Revisão, idempotência e conflito

1. A primeira gravação de um `attempt_id` deve usar `revision: 1` e responde
   `201`.
2. Cada alteração subsequente envia exatamente a revisão anterior mais um.
3. Repetir o mesmo payload da revisão já persistida é retry idempotente e
   responde `200`, sem criar outra linha.
4. Reutilizar a mesma revisão com dados diferentes, enviar revisão antiga ou
   saltar uma revisão responde `409`:

```json
{
  "detail": {
    "code": "revision_conflict",
    "current_revision": 2,
    "expected_revision": 3
  }
}
```

Mudar `course_id`, `assessment_content_id`, `topic` ou `mode` sob o mesmo `attempt_id` responde
`attempt_identity_conflict`. Alterar uma tentativa concluída responde
`completed_attempt`. Uma nova revisão com `updated_at` anterior ao estado
persistido responde `updated_at_conflict`. Em conflito, o Flutter deve executar
`GET` do ID, comparar o estado local e oferecer continuidade a partir da revisão
mais recente; nunca deve sobrescrever silenciosamente o servidor.

## Fluxo offline recomendado para o Flutter

1. Criar IDs estáveis para conteúdo e tentativa no aparelho.
2. Persistir ambos localmente; ao recuperar rede, sincronizar o conteúdo antes
   da primeira revisão da tentativa.
3. Enfileirar o `PUT` da tentativa com `assessment_content_id`.
4. Repetir exatamente o mesmo `PUT` em timeout ou resposta de rede incerta.
5. Incrementar a revisão somente quando o estado local mudar.
6. Em `409`, buscar o registro e resolver a divergência explicitamente.
7. Na autenticação/retomada, listar tentativas incompletas, buscar
   `/assessment-attempts/{id}/content`, montar o deck remoto e reconciliar pelo
   `attempt_id` e `revision`.

Tentativas legadas migradas podem ter `assessment_content_id: null`; o endpoint
de conteúdo responde `legacy_attempt_without_content`, pois não é seguro
inventar perguntas ou gabarito ausentes. Na autoexclusão, tentativas e conteúdos
são apagados antes do usuário. A FK de ownership também usa `ON DELETE CASCADE`.
