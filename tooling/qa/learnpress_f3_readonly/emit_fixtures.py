"""Emite fixtures tipadas EadAccountReadSnapshot a partir dos recibos F3c.

Uso: emit_fixtures.py <evidence_dir> <fixture_out_dir> <USER_A_ID> <USER_B_ID> <USER_C_ID>
Fixtures OBSERVED só são escritas quando o recibo comprova o estado; demais
estados saem como "synthetic target" com a observação de suporte.
"""
import datetime
import json
import os
import sys

EV, OUT = sys.argv[1], sys.argv[2]
UA, UB, UC = int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
ENV_ID = "wp-lp-mysql-qa-sandbox"
NOW = datetime.datetime.now(datetime.timezone.utc).isoformat()


def load(name):
    with open(os.path.join(EV, name)) as fh:
        return json.load(fh)


def snapshot(uid, courses, origin=True):
    return {
        "_schema": "EadAccountReadSnapshot/v1",
        "wpUserId": uid,
        "environmentId": ENV_ID,
        "observedAt": NOW,
        "authenticatedLearnPressOrigin": origin,
        "courses": courses,
    }


def course(rec):
    der = rec["derived"]
    return {
        "wpCourseId": rec["wpCourseId"],
        "title": rec["title"],
        "enrollment": der["enrollment"],
        "progressPercent": der["progressPercent"],
        "nextLesson": der["nextLessonTitle"],
        # Autorização TARGET: false até o broker TDS↔EAD comprovar vínculo.
        # Elegibilidade OBSERVED do sandbox fica como candidato em _derived.
        "resumeAuthorized": False,
        "_derived": {
            "resumeCandidate": der["resumeAuthorized"],
            "nextPendingItemId": der["nextPendingItemId"],
            "nextPendingItemType": der["nextPendingItemType"],
        },
    }


def write(name, obj):
    with open(os.path.join(OUT, name), "w") as fh:
        json.dump(obj, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def require(cond, name, detail):
    """Fixture OBSERVED só sai quando o recibo comprova o estado esperado."""
    if not cond:
        print(f"ERRO: recibo não comprova estado esperado para {name}: {detail}",
              file=sys.stderr)
        sys.exit(1)


# OBSERVED — aluno B matriculado, progresso 0, próxima lição derivável
b = load("R09.body")
require(b["derived"]["enrollment"] == "enrolled", "linked-enrolled",
        f"R09 derived.enrollment={b['derived']['enrollment']!r} (esperado 'enrolled')")
write("linked-enrolled.json", {
    **snapshot(UB, [course(b)]),
    "_provenance": "OBSERVED",
    "_evidence": "f3c R09 (student-B, course_data.status=enrolled)",
    "_resume_note": "resumeAuthorized=false até broker TDS↔EAD comprovar "
                    "vínculo; _derived.resumeCandidate=true observa que no "
                    "sandbox o próximo item está destravado (status=enrolled).",
})

# OBSERVED — aluno A curso finalizado (lock pós-finish)
a = load("R08.body")
require(a["derived"]["enrollment"] == "completed", "finished",
        f"R08 derived.enrollment={a['derived']['enrollment']!r} (esperado 'completed')")
write("finished.json", {
    **snapshot(UA, [course(a)]),
    "_provenance": "OBSERVED",
    "_evidence": "f3c R08 (student-A, status=finished, result=100, itens locked)",
})

# OBSERVED — aluno C vínculo LP válido sem matrícula
c = load("R10.body")
require(c["derived"]["enrollment"] is None, "linked-no-enrollments",
        f"R10 derived.enrollment={c['derived']['enrollment']!r} (esperado None)")
write("linked-no-enrollments.json", {
    **snapshot(UC, []),
    "_provenance": "OBSERVED",
    "_evidence": "f3c R07+R10 (student-C: users/5 200, course_data.status vazio)",
})

# SYNTHETIC TARGET — enrollment existe mas percentual ausente (result nulo)
write("linked-enrolled-progress-unknown.json", {
    "_label": "synthetic target",
    "_note": "Emitir quando course_data.status==enrolled porém result.result "
             "ausente/não-numérico — nunca substituir por 0.",
    **snapshot(UB, [{
        "wpCourseId": 11,
        "title": "<title>",
        "enrollment": "enrolled",
        "progressPercent": None,
        "nextLesson": "<first unlocked lp_lesson>",
        "resumeAuthorized": False,
        "_derived": {"resumeCandidate": True, "nextPendingItemId": 12,
                     "nextPendingItemType": "lp_lesson"},
    }]),
})

# SYNTHETIC TARGET — sem prova de sessão (guest não tem escopo: comprovado)
write("disconnected.json", {
    "_label": "synthetic target",
    "_supporting_observation": "guest courses/{id} → course_data vazio "
                               "(status='', count_items=0); users/* → 401. "
                               "Sem escopo autenticado não há snapshot.",
    "linkState": "disconnected",
    "courses": None,
})

# SYNTHETIC TARGET — snapshot ainda não lido / leitura inconclusiva
write("unknown.json", {
    "_label": "synthetic target",
    "_supporting_observation": "servidor não expõe conceito 'unknown'; estado "
                               "é exclusivamente do cliente (antes de read()).",
    "snapshotState": "unknown",
    "courses": None,
})

# SYNTHETIC TARGET — snapshot verificado porém fora da janela de frescor
write("stale-offline.json", {
    "_label": "synthetic target",
    "_supporting_observation": "TTL definido pelo controller do app "
                               "(maxFreshAge/maxOfflineAge); servidor não "
                               "expõe 'staleness' — derivado de observedAt.",
    "snapshotState": "stale",
    "courses": "último snapshot verificado do mesmo wpUserId+environmentId",
})
