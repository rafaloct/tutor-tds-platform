# CW-4 — eventos FastAPI → Chatwoot candidatos

Status: **TARGET / BLOCKED para integração**. O contrato não altera a FastAPI
nem instala webhook. A identidade assinada existente em `/support/identity`
continua separada deste contrato.

## Envelope mínimo

```json
{
  "event_id": "uuid-imutavel",
  "event_type": "certificate.issued",
  "occurred_at": "2026-10-03T18:00:00-03:00",
  "environment": "staging",
  "subject_ref": "opaque-user-reference",
  "context_ref": "opaque-context-reference",
  "case_ref": "optional-operational-case-reference",
  "payload": {"template_key": "certificate_available"}
}
```

`event_id` é a chave de idempotência. `subject_ref`, `context_ref` e `case_ref`
não são CPF, telefone ou IDs internos diretamente resolvíveis fora da API. A
integração de verdade deve obter o contato pela referência autorizada no servidor;
o Flutter, portal e widget nunca recebem a credencial do Chatwoot.

## Eventos e efeito permitido

| Evento | Origem autorizada | Ação Chatwoot permitida | Nunca faz |
| --- | --- | --- | --- |
| `certificate.issued` | fluxo de certificado API/Worker confirmado | abrir/atualizar caso e sugerir resposta `certificate_available` | tornar certificado válido, reemitir ou alterar assinatura |
| `attendance.risk_detected` | regra objetiva de frequência no domínio #6 | fila `acompanhamento`, etiqueta e contato humano sujeito a política | marcar falta/presença, reprovar ou aceitar reposição |
| `mobilization.notice` | publicação operacional autorizada | fila mobilização, mensagem padrão ou tarefa humana | criar matrícula ou confirmar comparecimento |
| `activity.published` | ciclo editorial FastAPI | aviso configurável para contexto autorizado | creditar atividade, progresso ou frequência |
| `course.published` | catálogo/oferta publicados pela API | aviso configurável sem expor inscritos fora do escopo | matricular alguém |
| `feedback.requested` | caso/atividade com regra e consentimento definidos | convite opcional e etiqueta `tds-feedback` | inferir satisfação por silêncio |
| `support.reply_required` | conversa/caso operacional já autorizado | atribuir time, avisar resposta pendente | encerrar caso ou afirmar resposta humana |

## Processamento futuro obrigatório

1. A API registra outbox próprio e somente então entrega ao adaptador.
2. O adaptador valida `environment`, schema, origem, contexto e deduplicação.
3. Falha/retry é observável; timeout não vira sucesso. Ordem não é presumida.
4. O adaptador cria/atualiza apenas referências operacionais e uma conversa/caso
   de suporte. A conversa não é fonte de retorno acadêmico.
5. Métricas e BI recebem tipo/timestamp/estado agregado; nunca texto integral.

Ainda faltam: inventário da versão do Chatwoot, mecanismo oficial de autenticação
de webhook/API, política de retenção, modelo canônico de OperationalCase e decisão
de quais notificações são essenciais versus opt-in. Esses itens são HUMAN-GATE,
não lacunas a preencher por este manifesto.
