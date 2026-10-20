#!/usr/bin/env bash
# Retry only the discarded MySQL restore; preserve first attempt and live source.
set -Eeuo pipefail
umask 077
test "$(hostname)" = srv1533541
OUT=/opt/tds-institutional-backups/20261020T003715Z
CLONE=tds-release-restore-retry-20261020
exec > >(tee "$OUT/restore-retry.log") 2>&1
sha256sum -c "$OUT/SHA256SUMS"
IMAGE=$(docker inspect compose-program-open-source-monitor-szkpni-mysql-1 --format '{{.Image}}')
trap 'docker logs "$CLONE" > "$OUT/restore-retry.private.log" 2>&1 || true; docker rm -f "$CLONE" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$CLONE" --network none --tmpfs /var/lib/mysql:rw,size=1g --env-file "$OUT/restore.env" "$IMAGE" >/dev/null
READY=0
for n in $(seq 1 60); do
  if docker exec "$CLONE" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N -e "SELECT 1"' >/dev/null 2>&1; then READY=1; break; fi
  sleep 2
done
test "$READY" = 1
test "$(docker inspect "$CLONE" --format '{{.HostConfig.NetworkMode}}')" = none
test "$(docker port "$CLONE" | wc -l)" = 0
docker exec -i "$CLONE" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot wordpress' < "$OUT/wordpress.sql"
docker exec "$CLONE" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --single-transaction --quick --skip-comments --skip-dump-date --set-gtid-purged=OFF --column-statistics=0 --order-by-primary wordpress' > "$OUT/restored-retry.sql"
cmp "$OUT/wordpress.sql" "$OUT/restored-retry.sql"
echo DATABASE_RESTORE_EXACT_PASS
docker exec "$CLONE" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=\"wordpress\""' > "$OUT/restored-table-count.txt"
docker rm -f "$CLONE" >/dev/null
trap - EXIT
docker inspect dokploy-traefik --format '{{.Id}} {{.Image}} {{.State.StartedAt}}' > "$OUT/traefik.after.txt"
docker inspect compose-program-open-source-monitor-szkpni-wordpress-1 compose-program-open-source-monitor-szkpni-mysql-1 --format '{{.Id}} {{.Image}} {{.State.StartedAt}}' > "$OUT/services.after.txt"
cmp "$OUT/traefik.before.txt" "$OUT/traefik.after.txt"
cmp "$OUT/services.before.txt" "$OUT/services.after.txt"
echo PASS_BACKUP_RESTORE_NO_PRODUCTION_WRITE
