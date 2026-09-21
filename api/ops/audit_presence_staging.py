"""Read synthetic presence history and rollback-only PostgreSQL guard probes."""
import json
import os
from sqlalchemy import create_engine, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session
from app.models import SessionPresence, SessionPresenceDecision


def run():
    url = os.environ["DATABASE_URL"]
    if make_url(url).database != "tutor_tds_staging":
        raise SystemExit("Only staging is permitted")
    engine = create_engine(url)
    with Session(engine) as session:
        record = session.scalar(select(SessionPresence).where(
            SessionPresence.session_id == "fd77e219-c001-462b-a10b-7581a71a1667",
            SessionPresence.user_id == "staging-qa-student"))
        assert record is not None and record.revision == 1
        history = session.scalars(select(SessionPresenceDecision).where(
            SessionPresenceDecision.presence_id == record.id)).all()
        assert len(history) == 1
        decision = history[0]
        assert decision.actor_user_id == "staging-qa-teacher"
        assert decision.status == record.status == "confirmed_present"
        assert decision.reason == record.reason
        record_id, decision_id = record.id, decision.id
    checks = [
        ("closed_decision", "UPDATE session_presence SET revision=revision+1 WHERE id=:id", record_id, "presence requires open session"),
        ("history_update", "UPDATE session_presence_decisions SET reason='ROLLBACK ONLY' WHERE id=:id", decision_id, "immutable presence history"),
        ("history_delete", "DELETE FROM session_presence_decisions WHERE id=:id", decision_id, "presence history requires owner erasure"),
    ]
    with engine.connect() as connection:
        for name, sql, identity, expected in checks:
            transaction = connection.begin()
            blocked = False
            try:
                result = connection.execute(text(sql), {"id": identity})
                assert result.rowcount == 1
            except DBAPIError as error:
                if expected not in str(error.orig):
                    raise
                blocked = True
            finally:
                transaction.rollback()
            assert blocked, name
    engine.dispose()
    print(json.dumps({"persisted_decisions": 1, "actor_verified": True,
                      "postgres_guards": [item[0] for item in checks],
                      "all_probes_rolled_back": True}))


if __name__ == "__main__":
    run()
