# 03 — Protocolo TARGET de vínculo (NOT IMPLEMENTED)

Alternativa **B**: dois logins explícitos + vínculo por introspecção única do
JWT LP. Todas as rotas/schemas abaixo são **TARGET** — não existem hoje.

## Fronteiras de confiança

```
[Flutter] --(senha EAD, TLS)--> [EAD WP/LP]        # FastAPI NUNCA vê a senha
[Flutter] <--(JWT LP 7d)------ [EAD WP/LP]         # JWT fica no device (secure storage)
[Flutter] --(JWT LP, 1 uso)--> [FastAPI broker]    # verificação transitória, descarte
[broker]  --(validate+users)--> [EAD WP/LP]        # introspecção + prova de id
[broker]  --(link row)-->      [DB FastAPI]        # vínculo auditável/revogável
[Flutter] <--(EadSessionProof)- [broker]           # artefato curto ~15min
```

## Fluxo de vínculo (sequence)

```
1. App: usuário já autenticado no TDS (JWT FastAPI 15min + refresh)
2. App: login EAD direto → WP emite JWT LP (7d) — guardado em secure storage,
   nunca enviado ao FastAPI nem exposto em URL/log
3. App → broker: POST /integrations/learnpress/link/start
   headers: Authorization: Bearer <JWT-TDS>
   body: { environment_id, nonce_cliente, redirect_uri? }
   broker gera: challenge {id, tds_user_id, env, nonce, iat, exp=+10min, used=false}
4. App → broker: POST /integrations/learnpress/link/complete
   body: { challenge_id, lp_jwt }            # JWT LP, uso único
   broker (server-side):
     a. challenge válido? (existe, não usado, não expirado, mesmo user+env)
     b. decode(claims) sem confiar → extrai data.user.id, iss, exp
     c. POST EAD /learnpress/v1/token/validate com o JWT → status 200?
     d. GET  EAD /learnpress/v1/users/{claimed_id} com o JWT → 200 e id bate?
        (prova IDOR real: o JWT tem que abrir o próprio recurso)
     e. iss ∈ allowlist de environment? exp razoável (≤ agora+7d)?
     f. conflito? wp_user_id já vinculado a outro tds_user_id → 409
     g. OK → grava vínculo {tds_user_id, wp_user_id, env, linked_at,
        linked_by:"self-consent", revoked_at:null} + marca challenge usado
        + descarta lp_jwt (nunca persistido)
5. broker → app: EadSessionProof { wpUserId, environmentId, verifiedAt,
   expiresAt=+15min, brokerVerified:true }
```

## Re-emissão de sessão (depois do vínculo)

```
App → broker: POST /integrations/learnpress/session/refresh
  headers: Bearer <JWT-TDS>
  body: { environment_id }
  broker: vínculo existe e não revogado? → introspecção fresca do JWT LP
          atual do device (relogin EAD se 401) → emite EadSessionProof novo
```

## Revogação / unlink

```
DELETE /integrations/learnpress/link
  broker: revoked_at=now + invalida proofs futuros
  Efeito: EadSessionProof deixa de ser emitido; nada é apagado no WP
  (a conta EAD continua existindo; ADR: deleção TDS não apaga WP)
```

## Schema do vínculo (TARGET — migration separada)

```
ead_account_links:
  id, tds_user_id (FK), wp_user_id, environment_id,
  linked_at, linked_by, revoked_at, revoked_by
  UNIQUE (environment_id, wp_user_id)          -- um WP só tem um TDS
  UNIQUE (environment_id, tds_user_id)         -- um TDS só tem um WP
ead_link_challenges:
  id, tds_user_id, environment_id, nonce, issued_at, expires_at,
  used_at NULL                                 -- uso único + TTL 10min
```

## O que cada artefato prova

| Artefato | Prova | NÃO prova |
|---|---|---|
| JWT LP 7d (device) | posse atual da conta WP | vínculo TDS, consentimento, escopo |
| `challenge` | intenção fresca + anti-replay/CSRF | autenticação |
| `token/validate`=200 | JWT assinado e não-expirado pelo LP | id do usuário (só devolve status+exp) |
| `users/{id}`=200 | o JWT abre o recurso do id reivindicado | identidade institucional |
| `ead_account_links` row | vínculo já consentido/auditado | sessão ativa |
| `EadSessionProof` | broker verificou link+jwt ≤15min atrás | autorização editorial/permanente |

## Propriedades de segurança exigidas

- `state`/`nonce` de uso único por tentativa; replay → reject.
- TTL challenge 10min; proof ≤15min; `verifiedAt` nunca aceita do cliente.
- `environment_id` bindado ao `iss` do JWT LP — token de outro ambiente falha.
- Vínculo único por (env, wp_user) e (env, tds_user) — colisão → 409.
- A/B no mesmo aparelho: proof carrega `wpUserId` — trocar de conta EAD exige
  novo challenge; reader rejeita proof cujo wpUserId ≠ link.
- Nenhum token em URL, log, analytics ou tela; JWT LP nunca chega ao DB.
- Consentimento explícito na UI TDS antes do `link/start` (LGPD: finalidade,
  controlador, revogabilidade, dados mínimos — só ids opacos).
