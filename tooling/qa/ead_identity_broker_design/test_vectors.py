#!/usr/bin/env python3
"""Vetores negativos offline do design de vínculo TDS↔EAD (Issue #272).

Simulador de estado PURO — sem rede, DB ou segredos. Modela as regras do
protocolo TARGET (docs/architecture/ead-identity-broker-design/03) e prova
que cada vetor de abuso é rejeitado. exit != 0 em qualquer falha.

Uso: python3 test_vectors.py
"""
import sys
import time

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


# --- modelo TARGET mínimo (só a lógica de decisão, nada de I/O) ---

CHALLENGE_TTL = 600        # 10 min
PROOF_TTL = 900            # 15 min
LP_JWT_TTL = 604800        # 7 dias — OBSERVED no sandbox


class Sim:
    """Estado do broker hipotético + do emissor LP, para exercitar regras."""

    def __init__(self, env, allowlisted_iss):
        self.env = env
        self.iss_allowlist = set(allowlisted_iss)
        self.challenges = {}      # id -> dict(tds_user, env, exp, used)
        self.links = {}           # (env, wp_user) -> dict(tds_user, revoked)
        self._next = 0

    # emissor LP (sintético): devolve "jwt" = dict(iss, iat, wp_user_id)
    @staticmethod
    def lp_issue(wp_user_id, iss, iat):
        return {"iss": iss, "iat": iat, "exp": iat + LP_JWT_TTL,
                "data": {"user": {"id": str(wp_user_id)}}}

    # introspecção LP simulada: válido se não expirado
    def lp_validate(self, jwt, now):
        return 200 if jwt and jwt["exp"] > now else 401

    # prova de posse: JWT abre o próprio /users/{id}? (IDOR real no LP)
    def lp_users_self(self, jwt, claimed_id, now):
        if self.lp_validate(jwt, now) != 200:
            return 403
        return 200 if int(jwt["data"]["user"]["id"]) == claimed_id else 403

    def link_start(self, tds_user, env, nonce, now):
        cid = f"ch{self._next}"; self._next += 1
        self.challenges[cid] = {"tds_user": tds_user, "env": env,
                                "nonce": nonce, "exp": now + CHALLENGE_TTL,
                                "used": False, "consent": True}
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
        if ch["tds_user"] != tds_user or ch["env"] != self.env:
            return "reject:cross-session"
        # verificação: decode claims (não confia) + introspecção + IDOR
        claimed = int(lp_jwt["data"]["user"]["id"]) if lp_jwt else 0
        if lp_jwt["iss"] not in self.iss_allowlist:
            return "reject:wrong-env"
        if self.lp_validate(lp_jwt, now) != 200:
            return "reject:bad-jwt"
        if self.lp_users_self(lp_jwt, claimed, now) != 200:
            return "reject:idor"
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
        return {"wpUserId": wp_user, "environmentId": self.env,
                "verifiedAt": now, "expiresAt": now + PROOF_TTL,
                "brokerVerified": True}

    def read_snapshot(self, proof, requested_wp_user, now):
        if (not proof or not proof["brokerVerified"]
                or proof["expiresAt"] <= now):
            return "reject:proof"
        if proof["wpUserId"] != requested_wp_user:
            return "reject:scope"
        return "snapshot"


def main():
    now = 1_700_000_000
    ISS = "https://ead.example.test"
    s = Sim("sandbox-qa", [ISS])

    # N-01 replay do mesmo challenge
    cid = s.link_start(10, "sandbox-qa", "n1", now)
    jwt_a = Sim.lp_issue(100, ISS, now)
    t("N-01a primeiro complete vincula", s.link_complete(cid, 10, jwt_a, now) == "linked")
    t("N-01b replay do challenge rejeitado", s.link_complete(cid, 10, jwt_a, now) == "reject:used")

    # N-02 challenge de A + JWT que valida como B (cross-account)
    cid = s.link_start(10, "sandbox-qa", "n2", now)
    jwt_b = Sim.lp_issue(200, ISS, now)
    # o link gravaria wp_user do JWT — mas aqui o challenge é do user 10 e o
    # wp 200 não está vinculado; a proteção real é: reader usa wp do link
    t("N-02 complete vincula wp do JWT verificado",
      s.link_complete(cid, 10, jwt_b, now) == "linked" and s.links[("sandbox-qa", 200)]["tds_user"] == 10)
    t("N-02b proof de 200 não lê 100",
      s.read_snapshot(s.issue_proof(10, 200, now), 100, now) == "reject:scope")

    # N-03 JWT LP 7d apresentado COMO proof
    fake_proof = {"wpUserId": 100, "environmentId": "sandbox-qa",
                  "verifiedAt": now, "expiresAt": now + LP_JWT_TTL,
                  "brokerVerified": False}   # sem verificação de broker
    t("N-03 JWT LP não é proof (brokerVerified=false)",
      s.read_snapshot(fake_proof, 100, now) == "reject:proof")
    t("N-03b TTL LP(7d) > TTL proof(15min)", LP_JWT_TTL > PROOF_TTL)

    # N-04 proof expirado
    p = s.issue_proof(10, 200, now)
    t("N-04a proof fresco ok", s.read_snapshot(p, 200, now) == "snapshot")
    t("N-04b proof expirado rejeita",
      s.read_snapshot(p, 200, now + PROOF_TTL + 1) == "reject:proof")
    # logout local: brokerVerified=false
    p2 = dict(p); p2["brokerVerified"] = False
    t("N-04c signOutLocal nega", s.read_snapshot(p2, 200, now) == "reject:proof")

    # N-05 iss fora da allowlist
    s5 = Sim("sandbox-qa", [ISS])
    cid5 = s5.link_start(10, "sandbox-qa", "n5", now)
    t("N-05 iss estranho rejeita",
      s5.link_complete(cid5, 10, Sim.lp_issue(300, "https://evil.test", now), now) == "reject:wrong-env")

    # N-06 complete sem challenge válido
    t("N-06 sem challenge", s.link_complete("ch999", 10, jwt_a, now) == "reject:no-challenge")

    # N-07 colisão: wp já vinculado a outro tds
    cid7 = s.link_start(99, "sandbox-qa", "n7", now)
    t("N-07 colisão rejeita",
      s.link_complete(cid7, 99, Sim.lp_issue(200, ISS, now), now) == "reject:collision")

    # N-09 revogação corta emissão de proof
    s.links[("sandbox-qa", 200)]["revoked"] = True
    t("N-09 link revogado -> sem proof", s.issue_proof(10, 200, now) is None)

    # N-10 challenge expirado
    cid10 = s.link_start(10, "sandbox-qa", "n10", now)
    t("N-10 challenge expirado",
      s.link_complete(cid10, 10, jwt_a, now + CHALLENGE_TTL + 1) == "reject:expired")

    # N-11 sem consentimento
    s.challenges.clear()
    cid11 = s.link_start(10, "sandbox-qa", "n11", now)
    s.challenges[cid11]["consent"] = False
    t("N-11 consentimento ausente",
      s.link_complete(cid11, 10, jwt_a, now) == "reject:no-consent")

    print(f"== vetores: PASS={PASS} FAIL={FAIL} ==")
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
