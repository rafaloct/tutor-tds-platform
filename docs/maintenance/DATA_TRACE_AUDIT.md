# Tutor TDS — gate de dados e rastreabilidade

Data: 2026-09-21. Escopo: **um** evento de telemetria sintético no Xiaomi `com.tutortds_cartilhas.dev` → API/PostgreSQL de **staging**. Não é aceite da versão 1.4 em produção, nem de todos os tipos de dados do app.

## Resultado

**DATA GATE: PASS para um sentinela APP → PostgreSQL staging**, após a correção mínima de logging e novo ensaio físico. O mesmo `event_id` foi observado na fila local, no log do `POST /events 201` e em uma única linha do banco, com 6/6 campos íntegros. Isso **não** declara 100% dos tipos de dados ou a versão 1.4 pronta para produção. O worker Sheets de staging está desligado e não foi testado. Produção 1.4 continua NO-GO; não usar contagem de rotas como prova de compatibilidade.

## Mapa curto do fluxo observado

| Origem → destino | Identificador | Evidência | Status |
|---|---|---|---|
| Ação de abrir Home → `LearningEvent` no Flutter | `event_id` abaixo | Navegação física offline gerou `page_viewed` | PASS |
| Flutter → `SharedPreferences` privada (`learning_events:pending:v1`) | mesmo `event_id` | `run-as` no package `.dev`: fila tinha 1 registro integral; permaneceu após `force-stop` | PASS |
| Fila → `POST /events` via HTTPS | mesmo `event_id` no JSON | Primeiro ensaio: fila 1 → 0, log sem ID. Após correção em staging, segundo ensaio: fila 2 → 0; log `POST /events 201` com o ID do sentinela | PASS |
| API FastAPI → `learning_events` PostgreSQL staging | mesmo `event_id` | `GET /events` autenticado devolveu o registro; consulta SQL direta retornou exatamente 1 linha | PASS |
| PostgreSQL → Google Sheets staging | pseudônimo HMAC do `event_id` | profile `sheets-sync` desligado; nenhuma planilha/credencial de staging comprovada | NÃO VERIFICADO; fora do destino ativo neste ensaio |
| Flutter → gateway de IA/AnythingLLM; Evidence, mídia, certificado, suporte e comercial | IDs próprios | Não exercitados pelo único sentinela; resultados públicos relatados pelo usuário não substituem teste de payload | NÃO VERIFICADO |

## Sentinela e integridade

`event_id` / trace ID: `1789989097466881-9LqF-fqbwvNw4O8T:page_viewed:77`.

Payload capturado na fila **antes** do envio:

```json
{"event_id":"1789989097466881-9LqF-fqbwvNw4O8T:page_viewed:77","event_type":"page_viewed","course_id":"_app","session_id":"1789989097466881-9LqF-fqbwvNw4O8T","occurred_at":"2026-09-21T13:02:58.693303Z","payload":{"page_id":"home"}}
```

`GET /events?course_id=_app&limit=100` respondeu HTTP 200 com `X-Request-ID: data-gate-20260921-sentinel-get`, exatamente 1 match e os seis campos da origem iguais. Acrescentou `active_seconds: null`, `sync_status: pending`, `validated_seconds: 0` conforme contrato. SQL direto no container da API de staging retornou exatamente 1 linha com os mesmos seis campos; o banco normalizou a data para `2026-09-21T13:02:58.693303+00:00` (mesmo instante), `active_seconds=0`, `sync_status=pending`, `validated_seconds=0`.

Campos esperados/enviados/recebidos/persistidos corretamente: **6/6/6/6**. O objeto aninhado `payload.page_id` também coincidiu. Sem campo ausente, truncamento, duplicação ou perda de precisão temporal observados. Este tipo não contém arrays ou anexos, portanto esses formatos permanecem NÃO VERIFICADOS. Nenhum hash foi calculado porque a comparação exata campo a campo e a normalização UTC já foram registradas; não declarar 100% do aplicativo.

## Rede, autenticação e retry

- APK no Xiaomi: `1.4.0-dev+13`, `versionCode=13`, SHA-256 `9bc1fc7245c508b4c94141bb0722ffbfe2848497eb0082a4f85167098a842213`, igual à build DEV documentada como staging. `INTERNET` concedida; `usesCleartextTraffic=false`; não há `network_security_config` próprio localizado. `TUTOR_API_URL` é compile-time e o gate Gradle exige staging para debug; o destino efetivamente observado foi o PostgreSQL isolado de staging. Não foi extraída a string do binário para declarar a URL exata só pelo APK.
- Rota pública de staging `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api/health`: HTTPS 200, `database=available`, header `X-Request-ID` ecoado. Isso prova DNS/TLS do host de auditoria; o envio do Xiaomi e o registro no banco provam a conectividade do dispositivo para o endpoint de eventos.
- Conta sintética de aluno do staging autenticada no app; credenciais lidas em memória do arquivo protegido no VPS, não registradas neste documento. `AuthRepository.authorized` usa Bearer, refresh em 401 e timeout de 12 s. A sincronização envia JSON com `Content-Type`, serializa flushes, remove da fila somente em 200/201 e conserva o evento nos demais status/exceções. Não envia `X-Request-ID` próprio atualmente.
- Ao autenticar, a fila preexistente de **111 eventos de telemetria** do package DEV foi escoada automaticamente para staging (111 → 0). Esses registros não foram usados como prova de integridade; o ensaio controlado e a comparação abaixo referem-se somente ao novo sentinela `:page_viewed:77`. Nenhum pacote Play ou banco de produção foi alterado.
- Wi-Fi e dados móveis estavam ligados antes e foram restaurados depois do corte. Com ambos desligados, o evento ficou na fila. Sobreviveu a `force-stop`. Após reabrir conectado, a fila 1 → 0 e o banco recebeu uma linha. Isso prova o retry por ciclo de vida neste caso, não todos os backoffs/erros HTTP. Não há backoff temporizado no cliente; nova tentativa depende de acionamento do flush/lifecycle.
- `sync_status=pending` significa pendente **apenas para o espelho Sheets**; não significa falha de persistência no PostgreSQL. O worker de staging está desligado por configuração.

## Falha objetiva de rastreabilidade e correção mínima

Antes da correção, `docker logs` do container staging mostrava diversos `POST /events HTTP/1.1 201 Created` na janela, sem `event_id` nem `request_id` associados. A classe `observability.py` gerava `X-Request-ID`, mas usava logger INFO sem handler efetivo no processo Uvicorn; o endpoint não anexava o `event_id`. Não era possível atribuir **um POST específico** ao primeiro sentinela só pelos logs.

Correção estritamente limitada: middleware usa logger ativo `uvicorn.error` e registra timestamp, `request_id`, `trace_id` (`event_id`), rota, status, tentativa semântica (`new`/`retry`/`conflict`), resultado e classe de erro sem payload ou credenciais. `POST /events` define o ID/estado de tentativa. Teste direcionado `api/tests/test_events.py::test_event_trace_links_request_to_idempotent_record`: **PASS**, verificando 201/new e 200/retry com o mesmo trace ID e ausência de senha no log. O usuário confirmou Git local sem remoto hospedado. O verificador aceita `urn:sha256:<hash do arquivo fonte>` como origem endereçada por conteúdo, mantendo a revisão Git completa e a comparação exata do hash do pacote transferido. Testes de proveniência: **5/5 PASS**.

### Repetição física apenas do trecho afetado

- Commit fonte local: `01efa5404919c8c177b7605894b0075a80a5ba6e`; arquivo `git archive` SHA-256 `709695e81b2c68f0257fbd6ce2d0330628a6b9f83674648318342540b2765076` igual no PC e VPS. Nenhum segredo no arquivo. Imagem staging `sha256:65d9e49a4afa1fadc0d90b4132e0690958352309854b9f4c5ed4bef5c1775d90`, com revision/source/created verificados antes e depois do deploy. Imagem anterior preservada para rollback; Compose válido, banco no head `20260920_0014`, smoke de health/cursos aprovado. A transferência do script em CRLF exigiu normalização de linha na execução; a primeira tentativa falhou antes de qualquer mutação do container.
- Novo sentinela: `1789996700697338-6noKE7GFuU9DUYd9:page_viewed:2`. Capturado na fila com `event_type=page_viewed`, `course_id=_app`, `session_id=1789996700697338-6noKE7GFuU9DUYd9`, `occurred_at=2026-09-21T13:18:21.774964Z`, `payload={"page_id":"home"}`. Havia 0 pendentes antes; 2 eventos surgiram no relançamento offline e voltaram a 0 depois de reabrir online. Wi-Fi/dados móveis foram restaurados aos estados anteriores (`1`/`1`).
- Log do container staging: `timestamp=2026-09-21T13:18:24.199320+00:00`, `trace_id` igual ao sentinela, `request_id=ffef19771d044e96b46cd4b905707d4e`, `method=POST`, `route=/events`, `status=201`, `attempt=new`, `result=created`, `error=null`. Nenhum token, senha ou payload pessoal no log.
- SQL direto em `learning_events`: exatamente **1** linha para o ID, com os mesmos 6 campos da fila; `occurred_at=2026-09-21T13:18:21.774964+00:00` é o mesmo instante UTC, `active_seconds=0`, `sync_status=pending` (Sheets desligado), `validated_seconds=0`. Integridade do novo sentinela: **6/6**.
- Produção não foi implantada. `GET /tutor-api/health` após o staging permaneceu HTTP 200, `database=available`; isso não valida as rotas 1.4 em produção.

## Gate obrigatório

| Item | Estado |
|---|---|
| Origem, persistência local, saída do dispositivo | PASS no sentinela |
| API, backend, persistência final PostgreSQL | PASS no sentinela |
| Campos comparados | PASS, 6/6 |
| Configuração/conectividade de rede | PASS em staging no recorte; produção 1.4 NÃO VERIFICADA |
| Comportamento offline/retry | PASS no corte/reabertura executado; demais erros NÃO VERIFICADOS |
| Rastreabilidade pelo mesmo ID nos logs **em execução** | **PASS no staging após novo ensaio** |
| Sheets e demais destinos/funcionalidades | NÃO VERIFICADO |

**Condição de parada atingida para um registro APP → REDE → API → PostgreSQL staging.** Parar aqui. Próxima ação mínima, somente em nova etapa autorizada: definir se o Google Sheets deve ser destino ativo deste gate e fornecer planilha/conta de serviço exclusivas de staging; produção 1.4 permanece congelada até preflight próprio.
