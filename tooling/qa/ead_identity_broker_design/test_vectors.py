#!/usr/bin/env python3
"""Vetores negativos offline do design de vínculo TDS↔EAD (Issue #272, rev.2).

Simulador de estado PURO — sem rede, DB ou segredos. Dois modelos:

- `SimInsecure` — reproduz as três falhas demonstradas na revisão de
  segurança do PR #273 (JWT velho linka, proof sobrevive a revogação,
  dict forjado lê). Os vetores DEVEM falhar aqui — prova de que o modelo
  é inseguro.
- `SimSecure` — o modelo TARGET corrigido: challenge com consented_wp_user,
  MAX_JWT_AGE (defesa parcial), proof_id opaco com lookup server-side por
  leitura e checagem de link ativo.

Uso: python3 test_vectors.py  →  exit != 0 em qualquer violação.
"""
import sys

PASS = 0
FAIL = 0


def t(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"PASS {name}")
    else:
        FAIL += 1
        print(f"FAIL {name}")


CHALLENGE_TTL = 600        # 10 min
PROOF_TTL = 900            # 15 min
LP_JWT_TTL = 604800        # 7 dias — OBSERVED no sandbox
MAX_JWT_AGE = 900          # defesa parcial: JWT LP aceito p/ link só se <15min


def lp_issue(wp_user_id, iss, iat):
    return {"iss": iss, "iat": iat, "exp": iat + LP_JWT_TTL,
            "data": {"user": {"id": str(wp_user_id)}}}


# ---------------------------------------------------------------- inseguro
class SimInsecure:
    """Modelo ORIGINAL — prova que as falhas da revisão existem de verdade."""

    def __init__(self):
        self.links = {}
        self.challenges = {}

    def validate(self, jwt, now):
        return 200 if jwt and jwt["exp"] > now else 401

    def link_complete(self, cid, tds_user, lp_jwt, now):
        ch = self.challenges.get(cid)
        if not ch or ch["used"] or ch["exp"] <= now:
            return "reject"
        if self.validate(lp_jwt, now) != 200:
            return "reject"
        ch["used"] = True
        wp = int(lp_jwt["data"]["user"]["id"])
        self.links[wp] = {"tds_user": tds_user, "revoked": False}
        return "linked"

    def issue_proof(self, wp_user, now):
        link = self.links.get(wp_user)
        if not link or link["revoked"]:
            return None
        return {"wpUserId": wp_user, "verifiedAt": now,
                "expiresAt": now + PROOF_TTL, "brokerVerified": True}

    def read(self, proof, requested, now):
        # inseguro: confia nos campos vindos do "cliente"
        if (proof and proof.get("brokerVerified")
                and proof["expiresAt"] > now
                and proof["wpUserId"] == requested):
            return "snapshot"
        return "reject"


# ------------------------------------------------------------------ seguro
class SimSecure:
    """Modelo TARGET corrigido — regras que o revisor exigiu."""

    def __init__(self, env, iss_allowlist):
        self.env = env
        self.iss = set(iss_allowlist)
        self.challenges = {}
        self.links = {}           # (env, wp) -> {tds_user, revoked}
        self.proofs = {}          # proof_id -> {wp, tds, exp, link_key}
        self._n = 0

    def _new_id(self, p):
        self._n += 1
        return f"{p}{self._n}"

    def validate(self, jwt, now):
        return 200 if jwt and jwt["exp"] > now else 401

    def link_start(self, tds_user, env, nonce, consented_wp, now, consent=True):
        cid = self._new_id("ch")
        self.challenges[cid] = {"tds": tds_user, "env": env, "nonce": nonce,
                                "exp": now + CHALLENGE_TTL, "used": False,
                                "consent": consent, "consented_wp": consented_wp}
        return cid

    def link_complete(self, cid, tds_user, lp_jwt, now):
        ch = self.challenges.get(cid)
        if ch is None:
            return "reject:no-challenge"
        if ch["used"]:
            return "reject:used"
        if ch["exp"] <= now:
            return "reject:expired"
        if not ch["consent"]:
            return "reject:no-consent"
        if ch["tds"] != tds_user or ch["env"] != self.env:
            return "reject:cross-session"
        if not lp_jwt:
            return "reject:bad-jwt"
        if lp_jwt["iss"] not in self.iss:
            return "reject:wrong-env"
        if self.validate(lp_jwt, now) != 200:
            return "reject:bad-jwt"
        # defesa parcial — JWT velho não vale como prova fresca
        if now - lp_jwt["iat"] > MAX_JWT_AGE:
            return "reject:stale-jwt"
        claimed = int(lp_jwt["data"]["user"]["id"])
        if claimed != ch["consented_wp"]:
            return "reject:wrong-account"
        key = (self.env, claimed)
        if key in self.links and not self.links[key]["revoked"]:
            return "reject:collision"
        ch["used"] = True
        self.links[key] = {"tds_user": tds_user, "revoked": False}
        return "linked"

    def issue_proof(self, tds_user, wp_user, now):
        link = self.links.get((self.env, wp_user))
        if not link or link["revoked"] or link["tds_user"] != tds_user:
            return None
        pid = self._new_id("proof")
        self.proofs[pid] = {"wp": wp_user, "tds": tds_user,
                            "exp": now + PROOF_TTL,
                            "key": (self.env, wp_user)}
        return pid           # id opaco — NÃO é autorizador por si só

    def read(self, proof_id, requested_wp, requesting_tds, now):
        # reader resolve server-side; o cliente só manda o id (string opaca).
        # O proof_id é bearer capability — DEVE estar vinculado à sessão TDS
        # autenticada: sem checar requesting_tds, posse do id bastaria.
        if not isinstance(proof_id, str):
            return "reject:unknown-proof"
        p = self.proofs.get(proof_id)
        if not p:
            return "reject:unknown-proof"
        if p["exp"] <= now:
            return "reject:expired"
        if p["tds"] != requesting_tds:
            return "reject:wrong-session"
        link = self.links.get(p["key"])
        if not link or link["revoked"]:
            return "reject:revoked"
        if p["wp"] != requested_wp:
            return "reject:scope"
        return "snapshot"

    def revoke(self, wp_user):
        self.links[(self.env, wp_user)]["revoked"] = True


def main():
    now = 1_700_000_000
    ISS = "https://ead.example.test"

    # ---------- PARTE 1: provar que o modelo inseguro falha ----------
    bad = SimInsecure()
    bad.challenges["c1"] = {"used": False, "exp": now + CHALLENGE_TTL}
    stale_jwt = lp_issue(100, ISS, now - LP_JWT_TTL + 60)   # quase 7 dias
    insecure_linked = bad.link_complete("c1", 10, stale_jwt, now)
    t("INSECURE-DEMO: JWT quase 7d ainda linka (a falha existe)",
      insecure_linked == "linked")

    bad.links[200] = {"tds_user": 10, "revoked": False}
    pid = bad.issue_proof(200, now)
    bad.links[200]["revoked"] = True
    t("INSECURE-DEMO: proof antigo sobrevive à revogação",
      bad.read(pid, 200, now) == "snapshot")

    forged = {"wpUserId": 999, "verifiedAt": now,
              "expiresAt": now + PROOF_TTL, "brokerVerified": True}
    t("INSECURE-DEMO: dict forjado produz snapshot",
      bad.read(forged, 999, now) == "snapshot")

    # ---------- PARTE 2: modelo seguro — negativas ----------
    s = SimSecure("sandbox-qa", [ISS])

    # N-01 replay
    cid = s.link_start(10, "sandbox-qa", "n1", 100, now)
    t("N-01a primeiro complete vincula",
      s.link_complete(cid, 10, lp_issue(100, ISS, now), now) == "linked")
    t("N-01b replay rejeitado",
      s.link_complete(cid, 10, lp_issue(100, ISS, now), now) == "reject:used")

    # N-02 conta diferente da consentida
    cid2 = s.link_start(10, "sandbox-qa", "n2", 300, now)   # consentiu wp=300
    t("N-02 wp_user≠consentido rejeita",
      s.link_complete(cid2, 10, lp_issue(200, ISS, now), now) == "reject:wrong-account")
    cid2b = s.link_start(10, "sandbox-qa", "n2b", 200, now)
    t("N-02b conta consentida vincula",
      s.link_complete(cid2b, 10, lp_issue(200, ISS, now), now) == "linked")

    # N-03 JWT LP quase 7d rejeitado como prova fresca
    cid3 = s.link_start(10, "sandbox-qa", "n3", 400, now)
    t("N-03 stale-jwt rejeitado",
      s.link_complete(cid3, 10, stale_jwt, now) == "reject:stale-jwt")
    t("N-03c JWT LP não é proof",
      s.read(stale_jwt, 400, 10, now) == "reject:unknown-proof")

    # N-04 proof expirado
    pid4 = s.issue_proof(10, 200, now)
    t("N-04a proof fresco lê", s.read(pid4, 200, 10, now) == "snapshot")
    t("N-04b proof expirado rejeita",
      s.read(pid4, 200, 10, now + PROOF_TTL + 1) == "reject:expired")

    # N-05 iss errado
    cid5 = s.link_start(10, "sandbox-qa", "n5", 500, now)
    t("N-05 wrong-env",
      s.link_complete(cid5, 10, lp_issue(500, "https://evil.test", now), now) == "reject:wrong-env")

    # N-06 sem challenge
    t("N-06 no-challenge",
      s.link_complete("chX", 10, lp_issue(100, ISS, now), now) == "reject:no-challenge")

    # N-07 colisão
    cid7 = s.link_start(99, "sandbox-qa", "n7", 200, now)
    t("N-07 collision",
      s.link_complete(cid7, 99, lp_issue(200, ISS, now), now) == "reject:collision")

    # N-08 escopo: proof de 200 não lê 300
    t("N-08a scope", s.read(pid4, 300, 10, now) == "reject:scope")
    t("N-08b proof_id forjado/inexistente",
      s.read("proof-forjado", 200, 10, now) == "reject:unknown-proof")
    t("N-08c dict forjado não é proof_id",
      s.read({"wpUserId": 200, "brokerVerified": True}, 200, 10, now) == "reject:unknown-proof")
    t("N-08d proof_id roubado por outra sessão TDS",
      s.read(pid4, 200, 99, now) == "reject:wrong-session")

    # N-09 revogação: novo proof None + proof antigo morre
    pid9 = s.issue_proof(10, 200, now)
    t("N-09a proof emitido", pid9 is not None)
    s.revoke(200)
    t("N-09b proof antigo pós-revogação",
      s.read(pid9, 200, 10, now) == "reject:revoked")
    t("N-09c sem proof novo pós-revogação",
      s.issue_proof(10, 200, now) is None)

    # N-10 challenge expirado
    cid10 = s.link_start(10, "sandbox-qa", "n10", 600, now)
    t("N-10 challenge expirado",
      s.link_complete(cid10, 10, lp_issue(600, ISS, now), now + CHALLENGE_TTL + 1) == "reject:expired")

    # N-11 sem consentimento
    cid11 = s.link_start(10, "sandbox-qa", "n11", 700, now, consent=False)
    t("N-11 no-consent",
      s.link_complete(cid11, 10, lp_issue(700, ISS, now), now) == "reject:no-consent")

    # invariantes
    t("INV: TTL LP(7d) > TTL proof(15min)", LP_JWT_TTL > PROOF_TTL)
    t("INV: MAX_JWT_AGE < LP_JWT_TTL", MAX_JWT_AGE < LP_JWT_TTL)

    print(f"== vetores: PASS={PASS} FAIL={FAIL} ==")
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
