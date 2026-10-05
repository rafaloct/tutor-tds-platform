# Contrato futuro de rastreio — experiências de aprendizagem

Status: **TARGET**. Esta frente não emite nem envia estes eventos e não altera
`api/**`. O contrato prepara conteúdo publicado para uma implementação futura
coordenada entre Flutter e FastAPI.

## Identidade de conteúdo

Cada `experience` publicado inclui `id`, `kind`, `objective`, `required` e
configuração opcional `ai`. O `id` é um slug estável, único dentro da cartilha e
da `CourseVersion`; não é derivado do texto nem da posição. `Section.id` é o
`module_id`. Nesta rodada, `required` tem default `false`; não cria avaliação,
presença, frequência, certificado ou `required_activity_pending`.

## Eventos propostos

| Evento | Significado limitado | Payload exato |
| --- | --- | --- |
| `experience_started` | abertura/interação inicial da experiência | `course_version_id`, `class_id`, `module_id`, `experience_id`, `experience_type` |
| `experience_completed` | conclusão declarada da prática; não domínio nem avaliação | mesmos campos |
| `experience_ai_invoked` | abertura do Tutor IA a partir da experiência; apenas sinal | mesmos campos |

`experience_type` é estritamente `scenario`, `reveal`, `reflection` ou
`action_challenge`. `active_seconds` permanece ausente. Idempotência futura
deve usar identificadores estáveis por sessão/experiência/tipo; invocações de IA
podem ter sufixo de sequência sem incluir conteúdo.

## Privacidade e projeções

O payload nunca contém reflexão em texto livre, prompt ou resposta da IA, nome,
CPF, telefone, baseline ou frequência. Professor pode receber agregados de
início/conclusão/uso de IA e tempo já validado pelo fluxo existente; monitor só
recebe os sinais acionáveis já autorizados. Nenhum recebe reflexão ou conversa.

Os atuais `lesson_started`, `study_activity` e `lesson_completed` permanecem os
únicos responsáveis por estudo/tempo/progresso. Dashboard, jornada, horas e
certificados não devem incluir os eventos propostos sem uma projeção
explicitamente versionada.

## Dependência de backend separada

**OBSERVED:** a API e o enum Flutter aceitam apenas os tipos e payloads atuais;
portanto os três eventos propostos seriam rejeitados hoje. A entrega futura deve
validar o payload exato, reutilizar a autorização contextual de matrícula e a
outbox idempotente, e provar que dashboards, horas e certificados não mudam.
Não exige migration de `LearningEventRecord` se o payload JSON existente for
mantido, mas exige mudança coordenada de backend e Flutter em uma PR própria.
