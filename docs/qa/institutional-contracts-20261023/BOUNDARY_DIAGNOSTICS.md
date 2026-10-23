# PostgreSQL fixture transport boundary

OBSERVED: first lifecycle run4 setup errors, connection refused127.0.0.1:15438.
Expected: disposable PostgreSQL reachable only by fixture's strict loopback URL.
Responsible boundary: Docker internal network/port publication, not API domain.
Evidence: container running and pg_isready inside PASS; requested HostConfig
PortBindings exist but actual NetworkSettings.Ports={} and docker port empty.
No fixture DB created; source code/guard untouched. Failed JUnit retained.
Structural correction: PostgreSQL listens on fixture's exact loopback port inside
its private namespace; pinned project Python-base client shares container network
namespace. No published ports/outbound network/host-network bypass, no shared
services. Read-only project/locked deps; separate writable QA output bind.

Attendance initial lane:11 PASS/3 FAIL. One imported migration proof deliberately
requires PostgreSQL17.11 (documented ENVIRONMENT_CONTRACT); development/production
compose uses16. Two candidate Worker failures returned503 because Python-base
runner has no Node; WorkerExchange invokes actual JS through Node. Host has
Node24.19.0. These are QA-boundary mismatches, not confirmed API defects. Do not
install Node into production API or relax the pinned migration assertion.
Correction: reuse host locked Python+existing Node with PostgreSQL published only
on127.0.0.1 in ordinary bridge mode, preserving strict fixture URLs. Run13 business
cases on production-compose16 and the exact17.11 migration proof in its own
sequential ephemeral lane. No shared/production DB upgrade or external exposure.
