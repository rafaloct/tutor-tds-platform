# 04 — Threat model e casos negativos (Issue #272)

Matriz de ameaças do protocolo TARGET + vetores negativos obrigatórios.
Os vetores são exercidos offline por
`tooling/qa/ead_identity_broker_design/test_vectors.py` num simulador de
estado puro (sem rede/DB/segredo).

## Matriz de ameaças

| # | Ameaça | Mitigação no design | Verificação |
|---|---|---|---|
| T1 | **Replay** de `link/complete` (mesmo challenge 2×) | `used_at` único + TTL 10min | N-01 |
| T2 | **Cross-account**: JWT LP de B apresentado no challenge de A | introspecção `users/{id}` exige o JWT abrir o próprio recurso; link grava o `wp_user_id` **verificado**, não o reivindicado | N-02 |
| T3 | **JWT LP velho** reutilizado como prova | proof exige `verifiedAt` fresco; JWT só é insumo de verificação, nunca sessão | N-03 |
| T4 | **Logout WP** não revoga JWT → sessão zumbi | proof tem TTL 15min e exige link não-revogado; `signOutLocally` zera `brokerVerified` | N-04 |
| T5 | **Environment errado** (token de staging em prod) | `iss` do JWT tem que estar na allowlist do `environment_id` | N-05 |
| T6 | **Consentimento cancelado** / fluxo abandonado | sem `link/complete` íntegro, nada é gravado; challenge expira | N-06 |
| T7 | **Conta já vinculada** a outro tds_user (colisão) | `UNIQUE(env, wp_user_id)` → 409, não sobrescreve | N-07 |
| T8 | **IDOR no reader**: proof de A usado p/ ler conta B | snapshot é scoped pelo `wpUserId` do proof/link, não por parâmetro | N-08 |
| T9 | **Token roubado** (JWT LP vazado do device) | prova de vínculo já gravada limita estrago a leitura própria; proof novo exige vínculo válido; revogação corta emissão | N-09 |
| T10 | **Escopo excedido**: proof usado p/ escrita LP | `EadMyAreaReader` é read-only; nenhuma rota de escrita consome proof | N-10 |
| T11 | Vazamento de segredo em URL/log | JWT só em body TLS; broker loga `link_id`, nunca token | code review |
| T12 | Match por CPF/nome/email | vetado pela ADR — vínculo só por prova de controle | code review |

## Casos negativos codificados (vetores offline)

| Vetor | Espera |
|---|---|
| N-01 replay do mesmo challenge | reject (`used`) |
| N-02 challenge de A + JWT que valida p/ outro wp_user | reject cross-account |
| N-03 JWT LP (7d) apresentado **como** proof | reject — não é `EadSessionProof` |
| N-04 proof com `expiresAt` passado | reject expirado |
| N-05 `iss` fora da allowlist do env | reject wrong-environment |
| N-06 `complete` sem `start` válido | reject no-challenge |
| N-07 segundo vínculo p/ mesmo wp_user no env | reject collision |
| N-08 reader com wpUserId ≠ link | reject scope |
| N-09 link revogado → refresh de proof | reject revoked |
| N-10 challenge expirado | reject expired |
| N-11 consentimento ausente | reject no-consent |

Cada vetor é determinístico e assertivo — `exit !=0` em qualquer violação.
