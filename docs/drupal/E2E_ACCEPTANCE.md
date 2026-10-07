# Aceite E2E do portal Drupal

Status: especificação **TARGET** para a implementação posterior.

Base auditada: `staging@d2da096fe13dd18641aa8b557b3702622baa3b34`.

Este documento não autoriza deploy, criação de secrets, alteração de produção ou uso de dados reais.

## Objetivo

Comprovar que o Drupal funciona como CMS + BFF sem assumir autoridade acadêmica, sem expor tokens/PII e preservando autorização, feature flags, idempotência e erros do FastAPI.

## Pré-condições e fixtures

Ambiente isolado de teste com origem FastAPI controlada, TLS ou equivalente local seguro e flags explicitamente registradas. As fixtures não usam credenciais reais.

| Persona/fixture | Vínculo esperado | Uso |
| --- | --- | --- |
| Visitante | Nenhum | Catálogo e detalhe públicos |
| `student-a` | Estudante ativo em `class-a` | Sessão, curso, contexto, carteira e solicitação |
| `student-b` | Estudante ativo em `class-b`, sem acesso a `class-a` | Isolamento entre pessoas/turmas |
| `teacher-a` | Professor ativo em `class-a` | Dashboard e observação |
| `monitor-a` | Monitor ativo em `class-a` | Exceções/observação permitida |
| `operator-a` | Operador/coordenador com escopo em `class-a` | Busca, inspeção e comando |
| `admin-a` | Admin TDS | Hierarquia e administração |
| `editor` | Conta Drupal editorial sem sessão TDS | Provar separação de identidades |

Cada execução registra base SHA, imagem/configuração de teste, flags, horário, suite, resultado e artefato redigido. Nenhum artefato contém token, senha, CPF, telefone ou corpo acadêmico integral.

## Cenários públicos

### P-01 — Lista e detalhe publicados

1. Visitante abre catálogo e um curso publicado.
2. BFF chama `GET /public/courses` e `GET /public/courses/{slug}`.
3. Verificar título/conteúdo da projeção, ausência de campos internos e cache conforme `public, max-age=60, stale-while-revalidate=300`.
4. Repetir durante TTL e confirmar que não há chamada indevida nem cookie de sessão TDS.

Aceite: somente dados publicados; slug compõe a chave; nenhuma PII; cache expira/revalida.

### P-02 — Ausência e indisponibilidade não se confundem

- slug inexistente retorna estado de não encontrado após `404`;
- API indisponível retorna indisponibilidade ou cache ainda válido, nunca `404` fabricado;
- cache expirado não se torna autoridade permanente.

### P-03 — Verificação de certificado bloqueada com segurança

Sem origem externa aprovada, o portal não cria validador, não consulta banco acadêmico e não mostra resultado sintético. Quando a configuração aprovada existir, o teste deve apenas confirmar redirect/encaminhamento para host allowlisted, sem tokens.

## Sessão e autenticação

### A-01 — Login mediado

1. Enviar credenciais de teste ao endpoint Drupal com CSRF/origem válidos.
2. Confirmar chamada servidor-side a `POST /auth/login` e sessão criada.
3. Inspecionar resposta, cookie, HTML, storage do navegador, rede, log e analytics.

Aceite: cookie opaco `Secure`/`HttpOnly`/`SameSite`; identificador rotacionado; access/refresh tokens visíveis somente no armazenamento protegido do servidor; resposta `no-store`.

### A-02 — Credencial inválida e rate limit

Credencial inválida não revela se o CPF existe. Resposta `429` respeita espera, não repete automaticamente e não registra o corpo.

### A-03 — Refresh concorrente

Expirar o access token e disparar duas requisições paralelas. Aceite: um único `POST /auth/refresh`, troca atômica dos dois tokens e cada requisição original repetida no máximo uma vez.

### A-04 — Refresh inválido

Invalidar o refresh token. Aceite: sessão e cookie destruídos, redirecionamento interno para login, nenhum loop e nenhum conteúdo autenticado de cache.

### A-05 — CSRF, origem e redirect

Login e mutações com CSRF ausente ou origem externa falham antes da API. Destino pós-login externo é rejeitado. Redirect de host na chamada API não recebe `Authorization`.

### A-06 — Logout local e lacuna remota

Logout remove registro servidor-side e cookie. A evidência marca revogação remota como BLOCKED enquanto não houver endpoint; o teste não afirma revogação inexistente.

### A-07 — Conta editorial isolada

`editor` autenticado no Drupal, sem sessão TDS, não acessa páginas acadêmicas. `student-a` autenticado no TDS não recebe privilégios editoriais nem cria usuário Drupal.

## Jornada do participante

### S-01 — Turma, edição e contexto próprios

1. `student-a` lista `GET /classes?enrolled_only=true`.
2. Abre `GET /classes/class-a/course`.
3. Abre `GET /classes/class-a/learning-context`.

Aceite: mesma turma/edição/contexto; `contract_version=cohort-enrollment-v2`; resposta `private, no-store`; IDs acadêmicos não aparecem em analytics/log; nenhuma gravação ocorre durante leitura.

### S-02 — Isolamento

`student-b` tenta `class-a` e recebe `403`; o Drupal não devolve cache de `student-a`, não mascara como dado vazio e não consulta banco próprio.

### S-03 — Feature flag e inconsistência

- contexto desligado: `404` é mostrado como recurso indisponível no ambiente, sem mock permanente;
- linhagem inconsistente: `409` orienta contato/reconciliação e não seleciona outra edição;
- vínculo revogado: `403` remove a ação imediatamente.

### S-04 — Solicitação de certificado

`student-a` consulta contextos, cria uma solicitação, lista/detalha e, quando permitido, ressubmete. Aceite: `409` de revisão força releitura; `422` de elegibilidade é preservado; aprovação humana não é apresentada como certificado emitido.

### S-05 — Carteira própria

`student-a` abre `GET /certificates`; `student-b` não vê seus itens. A página pode exibir apenas o snapshot autorizado e link para `verification_url` allowlisted. CPF/telefone não aparecem.

## Equipe, operação e administração

### T-01 — Dashboard e observação

`teacher-a` e `monitor-a` acessam recursos permitidos de `class-a`; pessoa sem vínculo recebe `403`. Progresso observado coincide com a projeção do contexto e não é recalculado no Drupal.

### O-01 — Busca com dado sensível

`operator-a` pesquisa por critério aceito (inclusive CPF/nome quando necessário). Aceite: entrada não entra em URL, analytics, cache ou log; resultado mínimo; outra turma retorna `403`/escopo negado.

### O-02 — Inspeção e comando idempotente

1. Inspecionar item e guardar contexto transitório.
2. Enviar comando com chave idempotente e contexto.
3. Repetir a mesma entrega e confirmar efeito único.
4. Alterar contexto no servidor e reenviar o antigo.

Aceite: repetição não duplica efeito; contexto antigo retorna `409`; UI exige nova inspeção; segredo/HMAC não chega ao navegador.

### D-01 — Admin permitido e negado

`admin-a` lê hierarquia e executa uma operação administrativa de fixture; usuário sem papel recebe `403`. Conflitos `409` e validações `422` não são convertidos em sucesso parcial.

## Falhas e resiliência

| Caso | Resultado obrigatório |
| --- | --- |
| Timeout/`503` da API | Estado indisponível, sem resposta inventada; escrita não é repetida automaticamente |
| `401` com sessão renovável | Um refresh coordenado e uma repetição máxima |
| `401` após refresh | Sessão encerrada |
| `403` | Ação negada, sem elevação de papel nem fallback editorial |
| `404` | Ausência ou flag preservada; não criar contrato falso |
| `409` | Releitura obrigatória antes de nova tentativa |
| `422` | Pendência/entrada de domínio exibida de forma segura |
| `429` | Respeitar `Retry-After`; sem tempestade de chamadas |
| JSON incompatível/campo obrigatório ausente | Fail closed, correlação registrada, sem renderização parcial enganosa |

## Testes técnicos mínimos da implementação Drupal

### Unitários

- cliente HTTP: allowlist, timeout, redirect sem credenciais e mapeamento de status;
- armazenamento/rotação de sessão e exclusão segura;
- coordenação de refresh;
- sanitização/redaction de logs;
- chaves e TTL de cache público;
- validação de esquemas obrigatórios;
- preservação de idempotência e contexto.

### Kernel/integração

- separação entre conta editorial e sessão TDS;
- exclusão de rotas autenticadas do cache Drupal;
- CSRF/origem em todas as mutações;
- nenhuma persistência acadêmica no banco Drupal;
- configuração ausente falha fechada.

### Browser/E2E

- P-01 a P-03, A-01 a A-07, S-01 a S-05, T-01, O-01/O-02 e D-01;
- duas sessões simultâneas provam ausência de vazamento de cache;
- varredura automatizada prova ausência de token/PII em DOM, storage, URL, console e requests de analytics.

## Evidência de origem já existente

Os contratos FastAPI são cobertos por:

- [`api/tests/test_auth.py`](../../api/tests/test_auth.py)
- [`api/tests/test_public_api.py`](../../api/tests/test_public_api.py)
- [`api/tests/test_classrooms.py`](../../api/tests/test_classrooms.py)
- [`api/tests/test_learning_context.py`](../../api/tests/test_learning_context.py)
- [`api/tests/test_operator_operations.py`](../../api/tests/test_operator_operations.py)
- [`api/tests/test_organizations.py`](../../api/tests/test_organizations.py)
- [`api/tests/test_certificate_requests.py`](../../api/tests/test_certificate_requests.py)
- [`api/tests/test_certificates.py`](../../api/tests/test_certificates.py)
- [`api/tests/test_support.py`](../../api/tests/test_support.py)
- [`api/tests/test_journey_traceability.py`](../../api/tests/test_journey_traceability.py)
- [`api/tests/test_journey_export_tools.py`](../../api/tests/test_journey_export_tools.py)

Esses testes não substituem os testes Drupal: eles provam o lado OBSERVED da fronteira.

## Critério de conclusão da etapa Drupal futura

1. Todos os cenários aplicáveis passam em ambiente isolado e estão ligados ao head SHA.
2. Nenhum BLOCKED foi contornado por mock permanente, leitura direta de banco ou dado manual.
3. Diff contém apenas paths autorizados da Issue da etapa.
4. Revisão confirma ausência de secrets, PII, alteração Flutter e produção.
5. CI e threads estão verdes/resolvidos.
6. O checkpoint declara `MERGE_RECOMENDADO`, `HUMAN_GATE` e bloqueios honestamente.

CI verde é evidência técnica, nunca autorização de merge, ativação ou produção.
