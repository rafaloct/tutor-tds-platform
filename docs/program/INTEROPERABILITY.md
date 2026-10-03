# Interoperabilidade e contratos

## 1. Regra geral

Integração é contrato, não “cola”. Cada integração deve registrar:

- sistema origem;
- sistema destino;
- direção;
- autoridade do dado;
- autenticação;
- esquema/versionamento;
- idempotência;
- retry;
- timeout;
- observabilidade;
- retenção;
- comportamento offline;
- fallback;
- dados proibidos;
- owner operacional.

## 2. Matriz

| Origem | Destino | Tipo | Autoridade |
|---|---|---|---|
| Flutter | FastAPI | HTTPS JSON | FastAPI |
| Portal | FastAPI | HTTPS read-only público | FastAPI |
| FastAPI | PostgreSQL | SQLAlchemy/Alembic | PostgreSQL |
| Flutter | Chatwoot | widget/WebView após identidade | Chatwoot conversa; API contexto |
| FastAPI | Chatwoot | server-to-server/webhook futuro | cada domínio mantém sua autoridade |
| FastAPI | Gateway | HTTPS | FastAPI decide autorização; gateway executa |
| Gateway | AnythingLLM | HTTPS | RAG, sem decisão acadêmica |
| Gateway | KV | binding | certificado público conforme contrato |
| FastAPI | Sync Worker | DB/queue | PostgreSQL |
| Sync Worker | Sheets | API | Sheets é projeção |
| Sheets | Power BI | leitura | BI é projeção |
| Drive | Media pipeline | asset master | Drive master; API metadados |
| Media provider/R2 | Flutter | playback/download autorizado | API autoriza |
| WordPress | Flutter | feed público | WordPress conteúdo editorial |

## 3. Envelope recomendado

Para comandos/eventos server-side:

```json
{
  "schema_version": "1",
  "event_id": "uuid",
  "event_type": "domain.action",
  "occurred_at": "UTC ISO-8601",
  "environment": "staging|production",
  "actor_id": "uuid-or-null",
  "subject_id": "uuid-or-null",
  "context": {
    "institution_id": null,
    "program_id": null,
    "course_id": null,
    "course_version_id": null,
    "class_id": null,
    "enrollment_id": null
  },
  "payload": {},
  "correlation_id": "uuid"
}
```

PII não deve ser repetida no envelope se IDs canônicos bastam.

## 4. Idempotência

POST/commands que podem ser repetidos devem aceitar `Idempotency-Key` ou equivalente. O servidor associa chave + ator + endpoint + contexto e devolve o mesmo resultado para replay válido.

Nunca usar timestamp aleatório para “resolver duplicata”.

## 5. Webhooks

Todo webhook deve:
1. validar assinatura/autenticação suportada pelo produto real;
2. validar account/inbox/origem/event type;
3. limitar body;
4. persistir receipt/dedup;
5. retornar rápido;
6. processar de forma idempotente;
7. ter dead-letter/retry observável;
8. não executar decisão humana automaticamente.

## 6. Identidade

Chave intersistemas preferida: UUID interno ou referência opaca. CPF pode existir no domínio autorizado, mas não é chave de URL, analytics ou Chatwoot.

Não unir registros por nome/telefone.

## 7. Sheets e Power BI

### Permitido
- IDs pseudonimizados;
- eventos necessários;
- dimensões de programa/curso/turma;
- métricas agregadas;
- status explicitamente derivados do domínio.

### Proibido por padrão
- CPF;
- baseline integral;
- texto de chat;
- prompt/resposta de IA;
- localização precisa;
- segredo/token.

Correção no BI não escreve de volta na origem.

## 8. Chatwoot

Chatwoot recebe apenas contexto mínimo necessário para atendimento. Um status `resolved` significa somente atendimento fechado.

Se atendimento precisa acionar domínio TDS, usa comando API autenticado, com ator e autorização, nunca etiqueta/macro como atalho.

## 9. Portal

Portal só consome endpoints públicos. Formulários de interesse que criem registro transacional devem postar para endpoint Tutor TDS ou serviço de coleta formal aprovado, não para tabela WordPress improvisada.

## 10. Mídia

Metadado e autorização na API; blob no provider. `provider_asset_id` não deve virar segredo. URLs assinadas expiram.

## 11. Versionamento

- API: versão compatível e `/version`.
- banco: Alembic revision.
- eventos: `schema_version`.
- app: semver + versionCode.
- portal: release do tema/plugin.
- curso: CourseVersion imutável publicada.

## 12. Timeouts e retry

Cliente:
- timeout explícito;
- retry apenas para operação segura/idempotente;
- backoff;
- feedback de pendência;
- não duplicar submissão.

Servidor:
- circuit breaker/timeout para upstream;
- erro de upstream não vira sucesso acadêmico.

## 13. Observabilidade

Toda integração crítica deve expor:
- health técnico;
- último sucesso;
- último erro sanitizado;
- backlog/fila;
- idade do item mais antigo;
- taxa de retry;
- versão do componente.

## 14. Contrato de falha

Cada feature deve responder:
- o que o usuário vê sem rede?
- o que fica em cache?
- o que pode ser enfileirado?
- quando revalida autorização?
- o que ocorre após logout/troca de conta?
- como evita replay de outro usuário?
- qual é o fallback?
- o fallback pode causar decisão errada?

## 15. Testes mínimos por integração

- happy path;
- credencial ausente;
- autorização negada;
- timeout;
- resposta inválida;
- duplicata;
- retry;
- troca de ambiente;
- troca de usuário;
- revogação;
- payload grande;
- versão incompatível.
