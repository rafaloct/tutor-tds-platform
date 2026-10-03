# Pendências, encaminhamentos e notificações — contrato transversal

Status: **TARGET apoiado por decisões humanas de 03/10/2026**.

Este contrato evita criar uma feature diferente para cada situação operacional do TDS. O mecanismo central é um **caso operacional** que pode ser detectado por regras, triado por agente e resolvido por pessoa real.

## 1. Objeto central: OperationalCase

Antes de criar tabela nova, procurar equivalentes existentes em suporte/follow-up/evidence. Se não existir um objeto compatível, o modelo candidato é:

```text
id
environment
program_id
user_id
enrollment_id opcional
class_id opcional
course_id opcional
category
reason_code
status
priority
detected_by: system|human|agent
assigned_user_id opcional
assigned_team
created_at
due_at opcional
last_action_at
resolution_code opcional
resolved_at opcional
summary
context_snapshot_minimal
external_support_ref opcional
```

Status pequeno e genérico:

```text
detected
triaged
assigned
waiting_participant
waiting_instructor
waiting_secretariat
resolved
cancelled
```

## 2. Categorias

Manter poucas categorias estáveis:

1. registration_linkage
2. attendance_class
3. content_access
4. certification
5. mentorship_followup
6. data_privacy

`reason_code` detalha a ocorrência sem criar novo workflow.

Exemplos:

```text
BASELINE_MISSING
ENROLLMENT_DOCUMENT_MISSING
ATTENDANCE_RISK
MAKEUP_REQUIRED
SUPPORT_REPLY_PENDING
CERTIFICATE_REQUIREMENT_PENDING
FOLLOWUP_DUE
ACCESS_PROBLEM
```

## 3. Detecção automática

Uma regra automática só pode criar caso quando a condição é objetiva.

Exemplo baseline:

```text
matrícula/participação ativa
+ interação recente
+ nenhum baseline vinculado/localizado
=> BASELINE_MISSING
```

Isso não autoriza preencher baseline, cancelar matrícula ou declarar irregularidade definitiva.

## 4. Triagem por agente

O agente pode:

- deduplicar casos equivalentes;
- reunir contexto permitido;
- classificar categoria/reason;
- gerar resumo;
- propor próxima ação;
- responder pergunta simples baseada em procedimento aprovado;
- encaminhar para humano;
- lembrar SLA/prazo.

O agente não pode:

- marcar presença;
- aceitar justificativa;
- preencher baseline;
- conceder certificado;
- aprovar mentoria;
- encerrar por silêncio;
- inventar contato realizado.

## 5. Chatwoot

Chatwoot é a mesa humana para casos que exigem conversa ou julgamento.

Fluxo:

```text
OperationalCase
→ adapter de suporte
→ Chatwoot conversation/reference
→ estagiário/program_operator
→ interação humana
→ resolução estruturada
→ FastAPI
→ caso resolvido/encaminhado
```

O texto completo da conversa permanece no Chatwoot. PostgreSQL guarda somente referência e dados estruturados necessários.

## 6. Papel program_operator

Estagiários mudam ao longo do projeto e precisam executar ampla rotina operacional.

O papel `program_operator` é escopado ao programa, revogável e auditado. Ele pode operar casos, cadastros, vínculos, turmas, presença, evidências e rotinas de certificado/mentoria conforme autorização de domínio.

Não recebe privilégios de infraestrutura, secrets, deploy, DNS ou administração global.

## 7. SLA de atendimento

Meta: **primeira resposta em até 5 minutos em horário comercial**.

Separar métricas:

```text
time_to_first_ack
time_to_first_human_response
time_to_resolution
```

Resposta automática de recebimento/triagem pode cumprir `first_ack`, mas não deve ser apresentada como solução humana.

Janelas confirmadas de suporte humano:
- 08:00–12:00;
- 14:00–18:00;
- 19:00–21:00.

Fora dessas janelas, o Chatwoot pode oferecer atendimento inicial por IA/agente. Esse atendimento pode orientar, coletar contexto e registrar a demanda, mas decisões humanas ficam pendentes para a próxima janela de suporte humano.

Métricas devem separar resposta automática de resposta humana.

## 8. Notificações

Notificações são uma capacidade transversal do caso e dos domínios, não nova fonte de verdade.

### Essenciais confirmadas

- mudança/cancelamento de aula;
- resposta do suporte;
- pendência de matrícula/regularização;
- certificado disponível.

### Relação com o fechamento digital

A conclusão da etapa digital de uma formação de 80h não deve depender de uma única métrica. O contrato confirmado prevê combinação de:
- evidência de uso das funcionalidades obrigatórias do app;
- carteira de certificados;
- print/registro do certificado exibido na carteira;
- avaliação via Jotform;
- eventos digitais confiáveis registrados pelo backend.

Notificação pode lembrar o participante de critérios pendentes, mas não concede conclusão.

### Arquitetura

```text
evento de domínio / caso
→ notification policy
→ notification record
→ in-app inbox
→ adapter push (FCM no Android, quando ativado)
```

Firebase/FCM, se usado, funciona apenas como transporte push. Usuário, matrícula, preferência e histórico oficial permanecem no FastAPI/PostgreSQL.

## 9. Central in-app

A Central de Notificações deve existir mesmo com push desativado/falho.

Estados mínimos:

```text
unread
read
archived
expired
```

Uma notificação protegida abre deep link e revalida autorização na API.

## 10. Device registration

Modelo candidato, reutilizando equivalentes se existirem:

```text
user_id
device_reference
platform
provider
push_token protegido
environment
app_version
enabled
last_seen_at
revoked_at
```

Tokens nunca vão para logs, BI, Chatwoot ou WordPress.

## 11. Preferências

Categorias gerais podem ser configuráveis. Notificações essenciais devem seguir política institucional e ainda possuir registro in-app.

Quiet hours são desejáveis, mas mudanças/cancelamentos urgentes precisam de política própria.

## 12. Deep links

Exemplos conceituais:

```text
course/class
certificate
support case
news
mentorship/follow-up
```

O payload não concede acesso. Fluxo obrigatório:

```text
push → app → sessão/auth → API → autorização → destino
```

## 13. Eventos e estados de entrega

Separar:

```text
created
queued
sent
provider_accepted
delivered quando comprovável
opened
action_completed
failed
expired
```

`opened != action_completed` e nenhuma dessas etapas equivale a presença.

## 14. Notificações de notícias

Notícias gerais podem ser opt-in. WordPress não recebe tokens de dispositivo.

Fluxo futuro:

```text
WordPress publica
→ integração autenticada/polling backend
→ FastAPI cria evento editorial
→ política de notificação
→ push/in-app
```

## 15. Resposta Chatwoot

Resposta humana pode gerar notificação essencial do tipo suporte.

Na tela bloqueada, evitar conteúdo sensível. Preferir mensagem genérica como 'A equipe TDS respondeu sua solicitação'.

## 16. Evidência de turma incompleta

Quando uma turma chegar ao fechamento sem fotos ou relatório esperado, criar caso operacional em vez de inventar evidência.

Reason codes sugeridos:
```text
COURSE_PHOTOS_MISSING
EVENT_REPORT_MISSING
EVIDENCE_PACKAGE_INCOMPLETE
```

Destino típico: equipe de mobilização/campo ou secretaria, conforme contexto.

A ação esperada pode ser revisita/coleta complementar de imagens e relatório.

## 17. Autoridade de presença em conflito

Se evidência digital divergir da lista física assinada, a **lista física assinada prevalece** até correção humana formal.

A divergência vira caso operacional para conferência; o sistema não sobrescreve silenciosamente a presença oficial.

## 18. Não criar issue infinita

Este contrato deve ser implementado dentro das frentes já existentes sempre que possível:

- #30: casos de cadastro/baseline/matrícula e visão do operador;
- #34/CW-2+: integração Chatwoot e roteamento humano;
- #6: casos de presença/risco/reposição;
- #5: notificação de certificado;
- #7/#8: mentoria/follow-up;
- #29: notícias gerais quando portal existir.

Uma issue exclusiva de infraestrutura de push só deve ser criada quando houver execução concreta que não caiba nessas frentes.

## 19. Critério de sucesso

O sistema é bem-sucedido quando identifica que algo precisa de atenção, entrega contexto ao humano certo, registra o desfecho e não perde o caso, sem automatizar decisões que exigem julgamento.