# Tutor TDS — gate de dados e rastreabilidade

Data: 2026-09-21. Escopo: **um** evento de telemetria sintético no Xiaomi `com.tutortds_cartilhas.dev` → API/PostgreSQL de **staging**. Não é aceite da versão 1.4 em produção, nem de todos os tipos de dados do app.

## Resultado

**DATA GATE: FAIL.** O sentinela chegou íntegro e único ao PostgreSQL após offline/reabertura, mas o staging em execução não registra `event_id` nos logs de `POST /events`. O mesmo ID não pode ser pesquisado de ponta a ponta. A correção mínima foi implementada e testada **localmente**, não implantada. O worker Sheets de staging está desligado e não foi testado. Produção 1.4 continua NO-GO; não usar contagem de rotas como prova de compatibilidade.

## Mapa curto do fluxo observado

| Origem → destino | Identificador | Evidência | Status |
|---|---|---|---|
| Ação de abrir Home → `LearningEvent` no Flutter | `event_id` abaixo | Navegação física offline gerou `page_viewed` | PASS |
| Flutter → `SharedPreferences` privada (`learning_events:pending:v1`) | mesmo `event_id` | `run-as` no package `.dev`: fila tinha 1 registro integral; permaneceu após `force-stop` | PASS |
| Fila → `POST /events` via HTTPS | mesmo `event_id` no JSON | Após rede restaurada e reabertura, fila 1 → 0; staging registrou `POST /events 201`, sem ID no log | PASS para saída; FAIL para correlação do POST específico |
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

`docker logs` do container staging mostra diversos `POST /events HTTP/1.1 201 Created` na janela, sem `event_id` nem `request_id` associados. A classe `observability.py` local gerava `X-Request-ID`, mas usava logger INFO sem handler efetivo no processo Uvicorn; o endpoint não anexava o `event_id`. Logo, não é possível atribuir **um POST específico** ao sentinela só pelos logs. O banco/API permitem busca por `event_id`, mas isso não satisfaz o gate dos logs de ponta a ponta.

Correção estritamente limitada: middleware passa a usar logger ativo `uvicorn.error`, registrar timestamp, `request_id`, `trace_id` (`event_id`), rota, status, tentativa semântica (`new`/`retry`/`conflict`), resultado e classe de erro sem payload ou credenciais. `POST /events` define o ID/estado de tentativa. Teste direcionado `api/tests/test_events.py::test_event_trace_links_request_to_idempotent_record`: **PASS**, verificando 201/new e 200/retry com o mesmo trace ID e ausência de senha no log. **Não implantado no staging neste checkpoint.** O usuário confirmou que há Git apenas no PC e no VPS, sem remoto hospedado. O verificador de imagem agora aceita também `urn:sha256:<hash do arquivo fonte>` como origem endereçada por conteúdo, mantendo a revisão Git completa e a comparação exata do hash do pacote transferido. Testes de proveniência: **5/5 PASS**. Não fazer patch direto no container, inventar URL de repositório ou tocar produção.

## Gate obrigatório

| Item | Estado |
|---|---|
| Origem, persistência local, saída do dispositivo | PASS no sentinela |
| API, backend, persistência final PostgreSQL | PASS no sentinela |
| Campos comparados | PASS, 6/6 |
| Configuração/conectividade de rede | PASS em staging no recorte; produção 1.4 NÃO VERIFICADA |
| Comportamento offline/retry | PASS no corte/reabertura executado; demais erros NÃO VERIFICADOS |
| Rastreabilidade pelo mesmo ID nos logs **em execução** | **FAIL** |
| Sheets e demais destinos/funcionalidades | NÃO VERIFICADO |

**Próxima ação mínima:** empacotar o commit Git local, verificar SHA-256 antes/depois da transferência ao VPS, construir/implantar essa imagem com origem `urn:sha256` **somente no staging** e repetir apenas o sentinela de logs. Não retomar as ondas nem promover produção antes de fechar o gate.
