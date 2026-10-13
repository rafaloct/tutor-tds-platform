# Documentação da API Tutor TDS

Esta documentação cobre **todas as operações HTTP do candidato** que usa a
árvore da API registrada em [coverage.json](coverage.json). Os dados de exemplo
são sintéticos. A existência de uma
rota no código não comprova implantação nem autorização para usá-la no ambiente
produtivo.

- [Referência de endpoints](ENDPOINTS.md): métodos, autorização, flags,
  parâmetros, bodies, respostas e erros de todas as operações.
- [Schemas completos](SCHEMAS.md): cada campo, obrigatoriedade, enum, default,
  formato e limite do contrato JSON.
- [OpenAPI 3.1](openapi.json): exportação integral gerada do FastAPI candidato,
  importável em Swagger Editor, Postman e ferramentas de integração.
- [Exemplos em JSON](examples.json): requisição/resposta por `METHOD PATH`.
- [Cobertura verificável](coverage.json): árvore Git, número de operações,
  schemas e exemplos validados.
- [Notas de contrato por operação](operation-notes.json): escopo, regras e gates
  revistos contra os handlers e helpers reais.

## Ambientes e URLs

| Ambiente | Base HTTP | Estado da evidência |
| --- | --- | --- |
| Desenvolvimento | `http://127.0.0.1:8000` | Dados sintéticos, PostgreSQL/SQLite local conforme o teste. Exemplos deste guia são destinados a este ambiente. |
| Staging canônico | `https://tutor-tds-staging.fastapicloud.dev` | Ambiente de homologação; exigir versão/schema/flags e fixture explícita da execução. |
| Staging VPS | `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api` | Lane de pré-aceitação separada; não substitui staging canônico. |
| Produção | `https://ead.ipexdesenvolvimento.cloud/tutor-api` | HTTPS verificado em 13/10/2026 às 15:39 UTC: schema `20261007_0030`, `compatibility_verified=true`, mínimo `1.2.0+11`; [recibo de promoção](../production/API_PROMOTION_2026-10-13.md). A geração documental é offline e não revalida o serviço ao vivo. |
| Candidato documentado | Árvore Git em `coverage.json` | Head Alembic `20261007_0030`; contrato de fonte, sem inferência de deploy. |

A base inclui o prefixo externo removido pelo reverse proxy (`/tutor-api` em
produção); os paths da referência começam depois dessa base. Evite duplicar o
prefixo. Não reutilize banco, tokens, IDs, outbox ou fixtures entre ambientes.

No serviço, `/openapi.json`, `/docs` (Swagger UI) e `/redoc` são as superfícies
automáticas padrão do FastAPI quando o proxy as expõe. A exportação versionada
aqui não depende da disponibilidade dessas superfícies em produção.

Antes de integrar uma versão nova, consulte `GET /live`, `GET /health` e
`GET /version` separadamente: vida do processo, conexão de banco e identidade do
deployment são sinais distintos. A versão HTTP da API é atualmente `0.1.0` e não
é a versão do app nem a revisão Alembic. A produção precisa passar o
[gate de compatibilidade e recuperação](../production/PRODUCTION_READINESS_AUDIT_2026-10-12.md)
antes da promoção.

## Autenticação e autorização

O header é `Authorization: Bearer <access_token>`. O token de acesso contém
identidade/papel e é revalidado contra a conta atual no banco. Tempo padrão:
15 minutos; refresh: 30 dias, ambos configuráveis. `POST /auth/refresh` rotaciona
o refresh token de uso único; persista o par novo de forma atômica e descarte o
antigo. Tokens fictícios da documentação não autenticam.

**O OpenAPI não descreve essa autenticação como um security scheme:** o código
usa `Header` + `Depends`. Por isso `authorization` pode aparecer como opcional
no schema de parâmetros, mas as rotas protegidas o exigem no runtime. A coluna
de autenticação e as notas de permissão da referência prevalecem para integração.

`User.role` global e vínculos no programa/turma são conceitos diferentes. Um
papel global não autoriza consultar qualquer turma. Cadastro público cria
`student`; atribuição administrativa de equipe exige administrador. Editor,
creator, coordinator e program_operator são avaliados por vínculo ativo no
programa, conforme a operação. Monitor possui acesso a alguns painéis e revisões,
mas não ao gabarito pedagógico de atividade publicada ou decisões de presença
oficial. A política de cada endpoint está na referência completa.

Produção pode exigir ativação de CPF (`CPF_ACTIVATION_REQUIRED`): um admin emite
convite vinculado ao CPF com `POST /auth/activation-invites`; o cadastro consome
o token válido. Não cadastre usuários fictícios em produção para testar o fluxo.
Bootstrap do primeiro admin é um comando operacional interativo, não um endpoint
público: consulte [api/README](../../api/README.md).

CPF enviado em auth é normalizado, validado por dígitos verificadores e
persistido como HMAC; senha usa Argon2id. Senha de cadastro possui 12–128
caracteres; telefone normalizado exige 10–15 dígitos. Esses limites adicionais
estão no serviço e não em todos os schemas OpenAPI. O CPF `12345678909`, telefone
`00000000000` e nomes QA usados nos exemplos servem somente para fixtures
sintéticas controladas; não representam uma pessoa nem autorização de cadastro.

## Primeira integração local

Prepare o ambiente conforme [api/README](../../api/README.md) e migre um banco
local descartável. Exporte a base explicitamente:

```bash
export TDS_API_BASE='http://127.0.0.1:8000'
curl "$TDS_API_BASE/live"
curl "$TDS_API_BASE/health"
curl "$TDS_API_BASE/version"
```

```bash
curl --request POST "$TDS_API_BASE/auth/register" \
  --header 'Content-Type: application/json' \
  --data '{"name":"Pessoa Sintética QA","cpf":"12345678909","phone":"00000000000","password":"Apenas-exemplo-nao-utilizar-2026"}'
```

Resposta sintética HTTP 201:

```json
{
  "access_token": "ACCESS_TOKEN_SINTETICO",
  "refresh_token": "REFRESH_TOKEN_SINTETICO",
  "token_type": "bearer",
  "expires_in": 900,
  "user": {
    "id": "00000000-0000-4000-8000-000000000004",
    "name": "Pessoa Sintética QA",
    "role": "student"
  }
}
```

Armazene o access token em memória/armazenamento seguro do cliente; o exemplo
abaixo supõe a variável `TDS_ACCESS_TOKEN` preenchida localmente. Não grave tokens
em logs, repositórios, planilhas ou mensagens.

```bash
curl "$TDS_API_BASE/auth/me" \
  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"
curl --request POST "$TDS_API_BASE/auth/refresh" \
  --header 'Content-Type: application/json' \
  --data '{"refresh_token":"REFRESH_TOKEN_OBTIDO_LOCALMENTE"}'
```

`DELETE /auth/me` é destrutivo e restrito ao estudante autenticado: apaga a conta
e dados transacionais associados; retorna 204 sem body. Purge de projeções Sheets
usa tombstones/retry. Não execute esse comando como teste fora de fixture local.

## Fluxos de domínio

| Fluxo | Ordem de operações e restrições |
| --- | --- |
| Catálogo público | `GET /public/courses` → `GET /public/courses/{slug}`. Somente projeção pública publicada, sem conteúdo acadêmico/PII; cache público é separado do catálogo legado `/courses`. |
| Preparação administrativa legada | Admin cria instituição → programa → oferta de curso → membership → matrícula → turma → vínculo do estudante/monitor. Relacionamentos existentes devem ser reusados. |
| Operação de turma | Com `CLASS_LIFECYCLE_ENABLED`, consultar options/equipe → preparar turma → ajustar plano/equipe → readiness → transição planned→active→closed. Receipts e revisão impedem replays divergentes; turma encerrada e sessão aberta impõem guards. |
| Operador | Com `OPERATOR_OPERATIONS_ENABLED`, scopes → search → inspect com prova de identidade → commands register/enroll/assign/revoke. A prova é vinculada ao ator/programa/pessoa e precisa ser emitida pelo servidor. |
| Estudo contextual | `GET /classes` → `/classes/{id}/course` → `/classes/{id}/learning-context`. Contexto canônico exige matrícula/vínculos ativos e edição da turma; professor consulta aluno pela rota explícita de staff. |
| Eventos/analytics | Cliente envia `POST /events` com ID estável; consulta os próprios `GET /events`; `GET /analytics/usage` agrega o escopo permitido. Evento mede uso; nunca concede matrícula, presença, certificado ou carga formal. |
| Atividade publicada | Flags contextual/dynamic ativas → conteúdo da edição da turma → `PUT /assessment-attempts/{attempt_id}` com ID e linhagem canônicos → consulta contextual da tentativa/conteúdo. O servidor deriva snapshot/gabarito/nota; não recebe gabarito publicado do cliente. |
| Encontro/evidência | Equipe cria encontro → abre/rotaciona token → estudante faz check-in/out → equipe importa/revisa metadados → decide presença em rotas autorizadas → fecha encontro/consulta relatório. Check-in é evidência, não frequência oficial automática. |
| Baseline/mentoria | Staff no escopo consulta aluno/baseline → registra revisão com motivo, chave idempotente e origem → cria/acompanhamento do caso de mentoria. Não envia conteúdo bruto de ficha ou chat. |
| Curso editorial | Editor autorizado cria draft → PATCH conteúdo+revision → submit → coordinator/admin publish; edição publicada é imutável. Criar nova versão preserva turmas já fixadas. |
| Mídia | Creator/editor autorizado cria draft → direitos e metadados revisados → coordinator/admin publica → catálogo visível → playback grant de 300s → URL de resolução/grant. Master Drive nunca é retornado ao aluno. |
| Pedido de certificado | Consultar contexts → criar pedido → review-queue/review por equipe autorizada → resubmit explícito após rejeição. Referências legadas e carteira não equivalem à emissão institucional candidata. |
| Candidato institucional | Política fixa 80h e encontros/checkpoints; lifecycle distingue GENERATED, validação do instrutor, assinatura da coordenação e VALID. Rotas candidatas possuem gates próprios; `/emit` final retorna 503 por homologação institucional pendente. |

O pacote MCP de cadastro discutido no PR #200 é uma camada de integração separada;
não adiciona endpoints a esta árvore de API. Sua instalação/conexão não concede
papel, membership, matrícula ou acesso novo: os comandos continuam passando pela
mesma fronteira FastAPI.

<a id="regras-semanticas"></a>

## Regras semânticas além do OpenAPI

Schemas mostram tipos e limites por campo. Relações, permissões, flags, revisões e
estado persistido são conferidos no servidor e exigem fixtures coerentes. Assim,
JSON tipado válido pode retornar 403/404/409/422 por regras do domínio.

- UUIDs/IDs dos exemplos são referências sintéticas; substitua-os pelos IDs
  retornados pelas operações anteriores no **mesmo ambiente**. Não concatene IDs
  entre turmas/programas/edições. Curso e ID de bloco não precisam ser UUID.
- Timestamps de eventos/evidências incluem timezone (`Z`/offset). `occurred_at`
  de evento não pode estar mais de cinco minutos no futuro. Intervalos de sessão,
  datas de turma, janelas de score e analytics têm validação cruzada própria.
- Commands de turma usam `id`, escopo completo e `expected_revision`. Baseline,
  mentoria, presença e check-ins usam `idempotency_key` no **body**. Não há um
  header `Idempotency-Key` universal implementado. IDs de evento/tentativa têm
  suas próprias regras; enviar uma chave desconhecida não cria idempotência.
- `published_block` exige `LEARNING_CONTEXT_ENABLED` e
  `DYNAMIC_ACTIVITY_ENABLED`, linhagem completa e ID determinístico. Os exemplos
  genéricos de attempt documentam `practice`; copiar UUID aleatório para uma
  tentativa publicada causa conflito. Contrato e cálculo do ID:
  [Wave 2B](../production/API_MATRIX.md#atividades-contextuais-publicadas--candidato-local-wave-2b).
- Conteúdo publicado protege respostas. Aluno não recebe gabarito/explicação nem
  após conclusão; professor/admin da turma exata consultam somente depois da
  conclusão. Monitor e outsider são recusados. O conteúdo legacy practice
  mantém o contrato próprio.
- CourseVersion draft permite conteúdo incompleto; revisão/publicação exigem ao
  menos um módulo com título e mensagem válida. Tipos `bot`, `user`, `question`,
  `quiz`; question/quiz requerem ao menos duas opções; quiz exige alternativa
  correta. Materiais PDF/link exigem URL pública HTTPS e vídeos somente media_id
  publicado da mesma linhagem. Até 50 materiais por módulo; sem segredo de
  provider ou URL temporária no snapshot. IDs/versões são fixados pelo servidor.
- YouTube aceita ID de vídeo; HLS externo exige HTTPS e recusa Google Drive.
  Publicação exige direitos confirmados. Grant expira, respeita visibilidade e
  matrícula; URL master e credenciais de provider não pertencem à resposta.
- Importações WhatsApp/Drive recebem somente digest, referência privada e
  metadados permitidos (`message_count`, `mime_type`, `source_item_id`,
  `page_count`). Não envie transcrição, documentos, OAuth ou conteúdo bruto.
- Emissões candidatas usam reserva durável e reconciliação por lookup. Timeout
  não autoriza reenviar/resetar emissão. Geração, capacitação e validade são
  estados distintos; tempo analítico não satisfaz 80h formais nem 70% de presença.
- `COMMERCIAL_SIMULATION_ENABLED` apenas libera ledger de simulação, append-only;
  adapter de pagamento permanece `disabled`. Nenhuma cobrança/payout é executado.

### Payloads de evento

`event_id`, `course_id`, `session_id` e `occurred_at` são obrigatórios.
`active_seconds` só aparece em `study_activity`/`screen_engagement` e aceita
1–60. `payload` possui valores string e chaves estritas por tipo:

| event_type | Payload permitido | Crédito validado |
| --- | --- | --- |
| lesson_started / lesson_completed / study_activity | `{}` ou `course_version_id`; `class_id` exige edição; nenhum campo extra | Calculado pela política existente, nunca pelo cliente. |
| page_viewed | `{"page_id":"classroom"}` | 0 |
| resource_opened | `{"resource_id":"course_pdf"}` | 0 |
| feature_used | `{"feature_id":"course_pdf_open_requested"}` | 0 |
| screen_engagement | `{"page_id":"classroom"}`; flag jornada e duração 1–60 | 0 |
| video_started / video_saved | `{"media_id":"media-qa","module_id":"modulo-qa"}` | Política de mídia; sem presença oficial automática. |
| video_checkpoint | Mesmo par + `checkpoint`: `"25"`, `"50"` ou `"75"`, `position_seconds`: string de inteiro não negativo | Calculado no backend. |
| video_completed | Par + `position_seconds` string de inteiro não negativo | Calculado no backend. |
| video_followup_completed | Par + `followup_type`: `quiz`, `reflection` ou `activity` | Calculado no backend. |

`assessment_completed` é gerado no backend ao concluir atividade publicada; não
é um tipo aceito em `EventCreate`. Identificadores de telemetria usam caracteres
estáveis (`a-z0-9_.-`, início alfanumérico, até 80 caracteres). Não envie CPF,
nome, texto de chat, prompt, resposta de IA ou localização no payload.

## Paginação, erros e headers

Nem todas as coleções são paginadas. Onde presentes, `limit` e `offset`, defaults
e limites constam em cada operação; não suponha um cursor universal. Envie filtros
por nome exatamente como no schema. `GET /analytics/usage` aceita janela de até
90 dias; `since`/`until` de exportação usam timezone e escopo autorizado.

| HTTP | Tratamento do cliente |
| --- | --- |
| 200 / 201 / 204 | Leitura/ação/recurso criado; 204 não tem JSON. Alguns replays idênticos mudam 201 para 200 conforme operação. |
| 307 | Resolução de playback redireciona; o URL de destino depende de grant/provider válido. |
| 400 | Parâmetro/contexto válido sintaticamente, mas combinação recusada pela operação. |
| 401 | Token ausente/inválido/expirado; renovar uma vez com refresh válido, sem loop. Algumas rotas de mídia públicas aceitam ausência, mas recusam Bearer inválido enviado. |
| 403 | Ator/papel/vínculo sem permissão; não retry automático como autorização nova. |
| 404 | Recurso ausente ou deliberadamente ocultado por escopo/flag; não revela existência fora da permissão. |
| 409 | Revisão, replay divergente, ID canônico, estado ou unicidade em conflito; buscar estado atual e reconciliar. |
| 422 | Validação de entrada ou regra de domínio; corrigir o campo/contexto sem substituir uma chave idempotente para esconder conflito. |
| 429 | Tentativas excessivas de login/código de check-in; respeitar janela e feedback de bloqueio. |
| 503 | Feature/transporte/configuração/gate indisponível ou identidade de schema indisponível; não apresentar sucesso ao usuário. |
| 500 | Falha inesperada; conservar request ID e metadados mínimos para suporte, sem dados sensíveis. |

Erro de domínio normalmente usa `{"detail":"mensagem"}`. Erro de validação
retorna 422 com lista, removendo `input` e `ctx` para não repetir CPF/senha/body:

```json
{
  "detail": [
    {"loc":["body","name"],"msg":"Field required","type":"missing"}
  ]
}
```

OpenAPI pode declarar apenas o sucesso e 422; as tabelas de exceções da referência
complementam o export com literals presentes no handler/helpers. Detalhes montados
dinamicamente aparecem como expressão de fonte, sem inventar texto. Erros vindos
do proxy/provedor/banco não possuem necessariamente esse envelope.

O middleware aceita `X-Request-ID` em formato limitado ou cria ID novo, devolve
`X-Request-ID` e registra rota normalizada/tempo/status sem body/CPF/token.
Catálogo público envia `Cache-Control: public, max-age=60, stale-while-revalidate=300`; não aplique esse
cache a respostas autenticadas. CORS configurado admite `Authorization` e
`Content-Type`; `X-Request-ID` não está na allowlist CORS atual. Cliente browser
que o envie precisa tratar essa restrição; não presumir suporte pelo header HTTP.

## Offline, retry e isolamento

Cache local não concede autorização. Outbox conserva dono, base da API,
turma/matrícula/edição, chave estável e timestamp original. Ao reconectar,
revalide vínculos e flags antes de considerar efeito oficial. Replay idêntico
não duplica; replay divergente produz conflito. Revogação conhecida bloqueia
cache/contexto; logout/troca de conta não transfere registros para o novo dono.

Use timeout explícito e backoff nos consumidores. Retente automaticamente apenas
leituras/operações cuja idempotência esteja demonstrada. Não regenere ID/chave
após timeout. Para certificados, consulte reconcile e mantenha resultado
indeterminado até confirmação; evento, UI, IA ou receipt local não prova emissão.

## Reproduzir e manter a documentação

Use o lock da API; não precisa de serviço, credenciais, migrations nem rede de
produção. O gerador define banco SQLite em memória e environment development
antes de importar o app, e não inicia lifespan ou endpoints.

```bash
cd api
uv sync --frozen --extra test
uv run --frozen --extra test python ../tooling/generate_api_reference.py
uv run --frozen --extra test python ../tooling/generate_api_reference.py --check
uv run --frozen --extra test python -m unittest discover -s ../tooling -p test_api_reference.py -v
```

`--check` compara a cobertura entre rotas reais, OpenAPI e notas de operação,
exige resposta explícita para cada operação sem modelo JSON preciso, valida os
52 exemplos de body com os modelos reais e todas as respostas tipadas, e detecta
artefatos desatualizados e verifica os links locais. `coverage.json` registra
quantidades exatas. O workflow independente [API reference validation](../../.github/workflows/api-reference.yml)
executa esse check em mudanças de código, documentação ou gerador, com permissão
somente de leitura e sem publicar imagem ou implantar staging. Os exemplos
sem response_model são revisados contra serializers, não contra schemas
inexistentes. `typed-response-overrides.json` cura respostas cujos estados,
metadados ou projeções não podem ser deduzidos só do schema. Os testes focados
conferem exemplos anônimos e transições de mídia contra a API em SQLite sintético
descartável. Nenhuma verificação local equivale a smoke/deploy produtivo.

Ao alterar uma rota, atualize `operation-notes.json`, os exemplos curados em
`request-overrides.json`, `response-overrides.json` e
`typed-response-overrides.json`, rode os testes e o gerador e revise o diff.
Datas de retenção em importações precisam estar no futuro ao executar o exemplo;
a data sintética fixa evita alterar os artefatos todos os dias.
Não acrescente dados reais ou chaves. A documentação deve mudar junto com o
contrato e manter explícito o estado da implantação.
