"""Rollback-only PostgreSQL checks on the synthetic certificate request."""
import json
import os

from sqlalchemy import create_engine, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session

from app.models import CertificateRequest, CertificateRequestTransition


def run():
    url = os.environ["DATABASE_URL"]
    if make_url(url).database != "tutor_tds_staging":
        raise SystemExit("Only tutor_tds_staging is permitted.")
    engine = create_engine(url)
    with Session(engine) as session:
        row = session.scalar(select(CertificateRequest).where(
            CertificateRequest.user_id == "staging-qa-student",
            CertificateRequest.class_id == "8d7e5869-cdd6-4ebe-a94e-2de91c0e7399"))
        assert row is not None and row.status == "rejected"
        history = session.scalars(select(CertificateRequestTransition).where(
            CertificateRequestTransition.request_id == row.id).order_by(CertificateRequestTransition.revision)).all()
        assert [item.to_status for item in history] == ["pending", "rejected"]
        assert history[-1].actor_user_id == "staging-qa-teacher"
        assert history[-1].reason == row.review_reason
        request_id, audit_id = row.id, history[-1].id
    checks = [
        ("snapshot", "UPDATE certificate_requests SET holder_name='ROLLBACK ONLY' WHERE id=:id", request_id, "immutable request snapshot"),
        ("history_update", "UPDATE certificate_request_transitions SET reason='ROLLBACK ONLY' WHERE id=:id", audit_id, "immutable request history"),
        ("history_delete", "DELETE FROM certificate_request_transitions WHERE id=:id", audit_id, "request history requires owner erasure"),
    ]
    with engine.connect() as connection:
        for name, sql, identity, expected in checks:
            transaction = connection.begin()
            blocked = False
            try:
                connection.execute(text(sql), {"id": identity})
            except DBAPIError as error:
                if expected not in str(error.orig):
                    raise
                blocked = True
            finally:
                transaction.rollback()
            assert blocked, name + " guard missing"
    engine.dispose()
    print(json.dumps({"request_id": request_id, "persisted_history": "pass",
                      "postgres_triggers": [item[0] for item in checks], "all_probes_rolled_back": True}))


if __name__ == "__main__":
    run()
