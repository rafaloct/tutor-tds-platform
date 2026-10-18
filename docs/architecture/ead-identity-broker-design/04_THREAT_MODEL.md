# 04 — Threat model e casos negativos (rev.2)

Matriz de ameaças + vetores offline em
`tooling/qa/ead_identity_broker_design/test_vectors.py` — simulador de
estado puro (sem rede/DB/segredo) que exercita as regras TARGET e prova que
o **modelo inseguro falha** onde a revisão apontou.

## Correções da rev.2 (revisão de segurança do PR #273)

A versão inicial afirmava proteções que o simulador **não exercitava**.
Três casos adversariais demonstrados pelo revisor foram incorporados como
negativas obrigatórias:

| Falha demonstrada | Correção no modelo |
|---|---|
| JWT LP quase 7d completava challenge novo (`linked`) | `MAX_JWT_AGE` na verificação + negativa N-03b. **Defesa parcial, não solução** — o vetor prova que o controle existe, não que B1 é seguro |
| Proof emitido antes de `revoked` ainda lia | lookup server-side por leitura (`proof_registry`) + checagem de link ativo — N-09b |
| Dict forjado `brokerVerified=true` produzia snapshot | reader passa a receber **id opaco** resolvido server-side — claims do cliente nunca autorizam — N-08b |

## Matriz de ameaças

| # | Ameaça | Mitigação TARGET | Vetor |
|---|---|---|---|
| T1 | Replay de `link/complete` | `used_at` único + TTL 10min | N-01 |
| T2 | JWT de conta diferente da consentida | challenge grava `consented_wp_user`; verify rejeita divergente | N-02 |
| T3 | JWT LP velho reutilizado | `MAX_JWT_AGE` (parcial) — sem provider, B1 fica BLOCKED | N-03 |
| T4 | JWT LP apresentado como proof | proof é artefato do broker, não token LP | N-03c |
| T5 | Logout WP não revoga JWT | proof nunca deriva de JWT LP; revogação é do link TDS | N-04 |
| T6 | `iss` de outro ambiente | allowlist de iss por `environment_id` | N-05 |
| T7 | Consentimento cancelado | `consent=false` → reject | N-11 |
| T8 | Conta já vinculada a outro tds | `UNIQUE(env, wp_user)` → 409 | N-07 |
| T9 | Proof forjado pelo cliente | `proof_id` opaco + lookup server-side | N-08b |
| T10 | Revogação não invalida proof antigo | `session_version`/link-check por leitura | N-09b |
| T11 | Escopo: proof lê conta alheia | snapshot scoped pelo `wp_user` do link | N-08a |
| T12 | Token/segredo em URL/log | proof_id opaco; nada de token no cliente | code review |
| T13 | Match por CPF/nome/email | vetado ADR — só prova de controle | code review |
| T14 | Senha WP capturada no app | **fluxo removido** — B1 exige browser+provider | design |

## Vetores codificados

| Vetor | Descrição | Espera no modelo seguro |
|---|---|---|
| N-01 | replay do challenge | `reject:used` |
| N-02 | JWT de wp_user ≠ `consented_wp_user` | `reject:wrong-account` |
| N-03 | JWT LP com `iat` quase 7d atrás | `reject:stale-jwt` |
| N-03c | JWT LP direto como proof | `reject:not-a-proof` |
| N-04 | proof expirado / `brokerVerified=false` | `reject` |
| N-05 | `iss` fora da allowlist | `reject:wrong-env` |
| N-06 | complete sem challenge | `reject:no-challenge` |
| N-07 | vínculo duplicado | `reject:collision` |
| N-08 | leitura de wp_user ≠ link | `reject:scope` |
| N-08b | proof_id inexistente/forjado | `reject:unknown-proof` |
| N-09 | link revogado → sem proof novo | `None` |
| N-09b | proof antigo pós-revogação | `reject:revoked` |
| N-10 | challenge expirado | `reject:expired` |
| N-11 | sem consentimento | `reject:no-consent` |

**Nota de honestidade:** os vetores provam que as *regras* rejeitam abuso —
não provam que B1 seja seguro. B1 fica **BLOCKED** até existir provider WP
auditado de proof recente; o modelo inseguro original permanece reproduzível
nos vetores históricos como demonstração do que **não** fazer.
