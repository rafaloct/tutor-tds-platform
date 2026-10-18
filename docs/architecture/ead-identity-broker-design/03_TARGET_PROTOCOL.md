# 03 — Protocolo TARGET (rev.2 — B1 condicional, BLOCKED)

Este documento registra **o que uma alternativa B1 exigiria** caso exista um
mecanismo WP auditado de proof/consentimento recente. Nada aqui é
implementável hoje — a primitiva central não existe no WP/LP.

## Por que a variante "introspecção de JWT LP" foi rejeitada

A versão inicial propunha: Flutter posta senha EAD em
`/learnpress/v1/token`, recebe JWT LP (7d) e o envia ao broker, que valida
via `token/validate` + `users/{id}` e grava o vínculo. **Três falhas
fatais**, apontadas na revisão de segurança:

1. **Viola a ADR #249**: captura de senha WP no Flutter/FastAPI é proibida
   explicitamente. O fluxo exigiria o app digitando a credencial EAD.
2. **Prova não é recente**: `token/validate` comprova apenas que o JWT é
   válido e não expirou — um token emitido 6 dias antes (ou roubado)
   completaria um challenge criado agora. `iat` mais recente é defesa
   parcial contra tokens velhos, **não** contra token já roubado.
3. **Logout WP não revoga**: o JWT de 7 dias permanece válido após logout —
   a "sessão EAD" não pode ser derivada dele.

Conclusão: sem um endpoint WP de **confirmação recente de posse** (browser
flow ou provider auditado), **não existe caminho seguro para vínculo** —
fallback é B0 (dois logins separados).

## Fronteiras de confiança (B1 hipotético)

```
[Flutter] --(JWT-TDS)--> [FastAPI]            # já existe
[browser sistema] <--> [WP consent provider]  # AUSENTE — provider auditado
[WP provider] --(auth-code/PKCE)--> [broker]  # troca server-side
[broker] --(link row)--> [DB]                 # vínculo auditável/revogável
[Flutter] <--(proof_id opaco)-- [broker]      # NUNCA claims do cliente
```

> Senha WP **nunca** trafega Flutter/FastAPI. JWT LP **nunca** é insumo de
> vínculo nem chega ao broker — a prova é o code/PKCE do provider, não um
> token de sessão de 7 dias.

## Artefato de sessão — correção do modelo `EadSessionProof`

A revisão identificou que `EadSessionProof` do Flutter é um **modelo/estado**,
não um bearer confiável: um dict forjado com `brokerVerified=true` é
indistinguível para o reader. Dois desenhos válidos (escolher um na
implementação futura):

| Desenho | Como funciona |
|---|---|
| **Artefato assinado** | broker emite JWT/opaco com `iss=broker`, `aud=ead-reader`, `scope=read`, `jti` único, `exp≤15min`, `wpUserId` em claim **verificada por assinatura** server-side |
| **Id opaco + lookup** | app recebe `proof_id`; cada leitura do reader faz `lookup(proof_id)` server-side → valida link ativo, exp, wp_user **e a sessão TDS dona do proof** — nada no cliente é autorizador |

> ⚠️ **Bearer capability (ressalva de revisão):** um `proof_id` opaco *sem*
> vínculo à sessão autenticada é uma capability — posse + `wpUserId`
> conhecido bastam para ler. Obrigatório na implementação: token gerado por
> **CSPRNG** (nunca id incremental), armazenado só como **digest**, associado
> à sessão TDS (`subject`, `audience`, `environment`, `scope`), **verificação
> de `tds_user_id` a cada GET**, link ativo e expiração. Nunca em URL/log.

**Vedado:** aceitar `wpUserId`, `environmentId` ou `brokerVerified` vindos do
cliente como autorização. O reader nunca confia em campos do modelo.

## Revogação — correção exigida

Proof emitido antes da revogação deve falhar se a política for "revogação
imediata":

- **Imediata (recomendada):** `read_snapshot` valida no servidor, a cada
  leitura, link ativo + `session_version` (bump em revoke/unlink/logout) —
  proof antigo morre mesmo dentro do TTL.
- **Janela residual (alternativa declarada):** se se aceitar proof residual
  até `exp`, o limite precisa ser **explícito e aprovado** (ex.: ≤15min) —
  nunca deixar implícito.

## Fluxo B1 (apenas quando primitiva existir)

```
1. App (sessão TDS) → broker: POST link/start {env, nonce} → challenge 10min
2. App abre browser do sistema → provider WP: login+consent (prova recente)
3. Provider → broker: auth code + PKCE (server-side, uso único, state bound)
4. Broker: valida code + nonce + env + wp_user recém-autenticado → grava link
5. Broker → app: proof_id opaco (ou artefato assinado curto)
6. Reader: a cada leitura, resolve proof_id server-side → link ativo? exp?
   wp_user == solicitado? → snapshot ou reject
```

## Propriedades exigidas (checklist de implementação futura)

- [ ] Provider WP auditado com auth-code+PKCE e consentimento explícito
- [ ] Challenge single-use, TTL≤10min, `state` bound à sessão TDS
- [ ] `proof_id`/artefato verificável **server-side** por leitura
- [ ] `proof_id` CSPRNG + digest-only + bound à sessão TDS (subject/aud/env/scope), `tds_user_id` checado a cada GET — bearer capability nunca basta
- [ ] Revogação: `session_version` bump → proofs antigos morrem na hora
- [ ] `UNIQUE(env, wp_user_id)` + `UNIQUE(env, tds_user_id)` → 409 colisão
- [ ] `environment_id` bindado ao issuer do provider — env errado → reject
- [ ] Consentimento UI com LGPD (finalidade, controlador, revogável)
- [ ] Nenhum segredo WP em URL, log, analytics ou cliente

**Status: NOT IMPLEMENTED / BLOCKED até mecanismo de proof recente existir.**
