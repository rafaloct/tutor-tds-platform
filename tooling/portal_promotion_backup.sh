#!/usr/bin/env bash
# Authorized production read-only backup and offline restore drill. No WP runtime.
set -Eeuo pipefail
umask 077
test "$(hostname)" = srv1533541
WP=compose-program-open-source-monitor-szkpni-wordpress-1
DB=compose-program-open-source-monitor-szkpni-mysql-1
RUN=$(date -u +%Y%m%dT%H%M%SZ)
OUT=/opt/tds-institutional-backups/$RUN
CLONE=tds-release-restore-$RUN
mkdir -p "$OUT"
chmod 700 /opt/tds-institutional-backups "$OUT"
exec > >(tee "$OUT/receipt.log") 2>&1
echo "BACKUP_PATH=$OUT"
docker inspect "$WP" "$DB" > "$OUT/containers.private.json"
docker inspect dokploy-traefik --format '{{.Id}} {{.Image}} {{.State.StartedAt}}' > "$OUT/traefik.before.txt"
docker inspect "$WP" "$DB" --format '{{.Id}} {{.Image}} {{.State.StartedAt}}' > "$OUT/services.before.txt"
docker exec "$DB" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --single-transaction --quick --skip-comments --skip-dump-date --set-gtid-purged=OFF --column-statistics=0 --order-by-primary wordpress' > "$OUT/wordpress.sql"
test -s "$OUT/wordpress.sql"
docker exec "$WP" tar -C /var/www/html -cf - . | gzip -1 > "$OUT/wordpress-files.tar.gz"
tar -C /etc/dokploy/compose/compose-program-open-source-monitor-szkpni -czf "$OUT/dokploy-compose.private.tar.gz" .
sha256sum "$OUT/wordpress.sql" "$OUT/wordpress-files.tar.gz" "$OUT/dokploy-compose.private.tar.gz" > "$OUT/SHA256SUMS"
echo BACKUP_COMPLETE
mkdir "$OUT/restore-files"
tar -xzf "$OUT/wordpress-files.tar.gz" -C "$OUT/restore-files"
tar -df <(gzip -dc "$OUT/wordpress-files.tar.gz") -C "$OUT/restore-files"
echo FILE_RESTORE_BYTE_COMPARE_PASS
openssl rand -hex 32 > "$OUT/restore-password"
printf 'MYSQL_ROOT_PASSWORD=%s\nMYSQL_DATABASE=wordpress\n' "$(cat "$OUT/restore-password")" > "$OUT/restore.env"
IMAGE=$(docker inspect "$DB" --format '{{.Image}}')
cleanup() {
  docker rm -f "$CLONE" >/dev/null 2>&1 || true
  # Retain protected restore and backup evidence; no broad filesystem deletion.
}
trap cleanup EXIT
docker run -d --name "$CLONE" --network none --tmpfs /var/lib/mysql:rw,size=1g --env-file "$OUT/restore.env" "$IMAGE" > "$OUT/restore-container-id.txt"
for n in $(seq 1 60); do
  if docker exec "$CLONE" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N -e "SELECT 1"' >/dev/null 2>&1; then break; fi
  sleep 2
done
test "$(docker inspect "$CLONE" --format '{{.HostConfig.NetworkMode}}')" = none
test "$(docker port "$CLONE" | wc -l)" = 0
docker exec -i "$CLONE" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot wordpress' < "$OUT/wordpress.sql"
docker exec "$CLONE" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --single-transaction --quick --skip-comments --skip-dump-date --set-gtid-purged=OFF --column-statistics=0 --order-by-primary wordpress' > "$OUT/restored.sql"
cmp "$OUT/wordpress.sql" "$OUT/restored.sql"
echo DATABASE_RESTORE_EXACT_PASS
docker exec "$CLONE" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=\"wordpress\""' > "$OUT/restored-table-count.txt"
docker rm -f "$CLONE" >/dev/null
trap - EXIT
docker inspect dokploy-traefik --format '{{.Id}} {{.Image}} {{.State.StartedAt}}' > "$OUT/traefik.after.txt"
docker inspect "$WP" "$DB" --format '{{.Id}} {{.Image}} {{.State.StartedAt}}' > "$OUT/services.after.txt"
cmp "$OUT/traefik.before.txt" "$OUT/traefik.after.txt"
cmp "$OUT/services.before.txt" "$OUT/services.after.txt"
sha256sum -c "$OUT/SHA256SUMS"
echo PASS_BACKUP_RESTORE_NO_PRODUCTION_WRITE
