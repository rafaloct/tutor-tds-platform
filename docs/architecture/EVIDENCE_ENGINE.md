# Tutor TDS - Evidence Engine

## Objetivo

Transformar eventos do app, check-ins, atividades, certificados, observações e
importações autorizadas em evidências auditáveis. IA pode classificar e resumir;
nunca confirma presença, conclusão ou sanção sem revisão humana.

## Modelo mínimo

```text
class_sessions
  class_id, starts_at, ends_at, status, opened_by, closed_by

checkins
  session_id, user_id, kind, occurred_at, method, evidence_id

evidence_imports
  class_id, source_type, status, imported_by, retention_until, source_digest

evidence_items
  import_id, class_id, session_id, user_id?, type, occurred_at,
  confidence, review_status, object_reference?, metadata

evidence_links
  evidence_id, learning_event_id?, certificate_id?, activity_id?

review_decisions
  evidence_id, decision, reason_code, decided_by, decided_at
```

`source_digest` e chaves idempotentes impedem que o mesmo arquivo ou evento
seja importado duas vezes. O banco guarda metadados necessários; binários ficam
em object storage privado com expiração e controle de acesso.

## Fontes

- eventos autenticados do Tutor TDS;
- check-in/check-out por QR curto e rotativo;
- observação estruturada de professor/monitor;
- atividade e certificado verificável;
- arquivo de conversa exportado voluntariamente do WhatsApp;
- fotos/PDFs selecionados pelo usuário;
- arquivos de pasta institucional autorizada no Drive.

A primeira versão não exige WhatsApp Business API. Importação de arquivo
exportado ou Android Sharesheet é mais simples, explícita e reversível. Uma
integração oficial futura deve ter número institucional, consentimento, termos
e credenciais próprios.

## Privacidade e retenção

1. Exibir finalidade, turma e período antes de cada importação.
2. Processar conteúdo bruto em área temporária.
3. Extrair somente itens necessários e seus digests.
4. Permitir revisão e descarte de itens não relacionados.
5. Apagar o bruto na expiração ou após confirmação, conforme a política.
6. Não usar conversa importada para treinar modelos.
7. Registrar acesso, exportação, decisão e exclusão.

CPF e telefone não são chaves públicas de evidência. Conciliação usa usuário e
matrícula internos; telefone pode ser usado transitoriamente, com proteção e
registro de finalidade, quando a origem exigir.

## Gestão por exceção

O painel calcula sinais, não veredictos:

- `inactive_7_days`;
- `required_activity_pending`;
- `below_expected_hours`;
- `checkin_without_activity`;
- `sync_failed`;
- `evidence_needs_review`.

Professor ou monitor marca resolvido, registra motivo e pode abrir o perfil. O
fechamento da sessão lista somente pendências e produz um relatório com links
para as evidências de origem.

## Endpoints-alvo

```text
POST /admin/classes/{class_id}/sessions
GET  /classes/{class_id}/sessions?status=open|closed&limit=50&offset=0
GET  /classes/{class_id}/sessions/open
GET  /classes/{class_id}/sessions/{session_id}
POST /classes/{class_id}/sessions/{session_id}/checkins
POST /classes/{class_id}/evidence-imports
GET  /classes/{class_id}/evidence-imports/{id}
GET  /classes/{class_id}/exceptions
POST /classes/{class_id}/evidence/{id}/review
POST /classes/{class_id}/sessions/{session_id}/close
GET  /classes/{class_id}/reports/{id}
```

Autorização sempre deriva de vínculo real com a turma. Alunos não recebem a
lista da turma nem evidências de terceiros.

## Contrato de recuperação de sessão

Os três `GET` de sessão exigem autenticação e aceitam apenas administrador,
professor titular, monitor atribuído à turma ou estudante com
`class_enrollment` ativo. Um vínculo em outro programa ou em outra turma não
concede acesso. A busca de um `session_id` que pertence a outra turma responde
`404`, sem devolver o objeto cruzado.

A listagem é paginada e ordenada por `starts_at` decrescente. `status` é
opcional e aceita apenas `open` ou `closed`:

```json
{
  "sessions": [
    {
      "id": "uuid",
      "class_id": "uuid",
      "starts_at": "2026-09-20T12:00:00Z",
      "ends_at": "2026-09-20T14:00:00Z",
      "status": "open",
      "token_expires_at": "2026-09-20T12:10:00Z",
      "token_version": 1
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0
}
```

`GET /classes/{class_id}/sessions/open` recupera a sessão aberta mais recente
e responde `404` quando nenhuma existe. A leitura por ID e a leitura da sessão
aberta usam o mesmo objeto de sessão acima, sem envelope.

O token em claro nunca é persistido nem reaparece nos endpoints de leitura.
Ele é retornado somente ao criar ou rotacionar o token. Depois de reiniciar o
app, o Flutter deve recuperar a sessão por `/open` (ou pelo ID salvo) e, para
exibir um novo QR, um professor/monitor autorizado deve chamar o endpoint de
rotação. Estudantes precisam ler o QR novamente; `token_version` permite
invalidar um QR antigo no estado local.

### Limite offline do check-in no app

O envio exige conexão e somente uma resposta `2xx` pode ser apresentada como
presença confirmada. Em uma falha de rede, o Flutter mantém o token rotativo
apenas em memória e persiste por no máximo 24 horas somente `class_id`,
`session_id`, `kind`, `idempotency_key` e a data de criação. Assim:

- uma reconexão com a tela ainda aberta repete a mesma operação com a mesma
  chave idempotente;
- após morte ou reabertura do app, a pendência reaparece, mas um código atual
  da mesma sessão precisa ser lido ou colado novamente;
- trocar turma, sessão ou tipo de presença abandona a chave anterior e inicia
  outra operação;
- sucesso remove a pendência e o código da memória; pendências antigas ou
  inválidas são descartadas localmente;
- o app nunca agenda replay silencioso nem informa confirmação offline.

Retry automático após reinício não é compatível com o contrato atual: ele
exigiria persistir o token em claro e ainda poderia reenviar um token expirado
ou invalidado por rotação. Uma fila automática futura exigiria um grant offline
dedicado, limitado por aluno, sessão e ação, com validade verificável pelo
cliente e consumo idempotente no servidor; não deve reutilizar o token do QR.
