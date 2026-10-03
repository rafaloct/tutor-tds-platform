/** Tutor TDS: server-side logical backup. Never restores or upgrades a database. */
import fs from 'node:fs';
import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

export const ROOT = '/etc/dokploy/tds-backup-ops';
export const BUCKET = 'tds-backups';
export const ENDPOINT = 'https://8b1d9dad829dd6927091666a1f186717.r2.cloudflarestorage.com';
export const PREFIX = 'postgres/scheduled/v1/';
const OWNER = 'tutor-tds-issue2-scheduled-v1';
const ID = /^\d{8}T\d{6}Z-[0-9a-f]{32}$/;
const SHA = /^[0-9a-f]{64}$/;
const MAX = 64 * 1024 * 1024;
const NATIVE_NOTIFICATION = '7Oz5wKFr9S0vAy2XRE8Yw';
const NATIVE_ORGANIZATION = 'umP9kk1j8wuWbdVwcJk7b';
class StageError extends Error { constructor(stage) { super(stage); this.stage = stage; } }
const digest = b => createHash('sha256').update(b).digest('hex');
export function validateConfig(c) {
  if (c.schema !== 1 || c.bucket !== BUCKET || c.endpoint !== ENDPOINT ||
      c.destinationId !== '8mVX4789RC3FO4dS7dxHD' || c.keepDaily !== 30 ||
      !/^[0-9a-f]{32}$/i.test(c.accessKey) || !/^[0-9a-f]{64}$/i.test(c.secretAccessKey) ||
      !/^age1[023456789acdefghjklmnpqrstuvwxyz]{58}$/.test(c.recipient) ||
      'identity' in c || 'BACKUP_AGE_IDENTITY' in c ||
      (c.weeklyPrefix !== null && !/^backup-[a-z0-9-]+\/tds-control-plane-scheduled\/$/.test(c.weeklyPrefix)) ||
      (c.mail?.provider === 'dokploy_database_backup' &&
        (c.mail.notificationId !== NATIVE_NOTIFICATION || c.mail.organizationId !== NATIVE_ORGANIZATION ||
          'pass' in c.mail || 'password' in c.mail))) {
    throw new StageError('config_invalid');
  }
  return c;
}
export function validateReceipt(r, expectedId) {
  if (!ID.test(expectedId) || r.schema !== 1 || r.owner !== OWNER || r.id !== expectedId ||
      r.status !== 'verified' || r.bucket !== BUCKET || r.key !== `${PREFIX}${expectedId}/archive.dump.age` ||
      !SHA.test(r.sha256) || !Number.isInteger(r.bytes) || r.bytes <= 200 || r.bytes > MAX + 65536 ||
      !Number.isFinite(Date.parse(r.completedAt)) || r.day !== r.completedAt.slice(0, 10) ||
      expectedId.slice(0, 8) !== r.day.replaceAll('-', '')) throw new StageError('receipt_invalid');
  return r;
}
export function expiredReceipts(records, keep = 30) {
  if (keep !== 30) throw new StageError('retention_policy_invalid');
  const ids = new Set();
  for (const r of records) { validateReceipt(r, r.id); if (ids.has(r.id)) throw new StageError('duplicate_receipt'); ids.add(r.id); }
  const sorted = [...records].sort((a, b) => b.completedAt.localeCompare(a.completedAt) || b.id.localeCompare(a.id));
  const retained = new Set(), days = new Set();
  for (const r of sorted) { if (!days.has(r.day) && days.size < keep) { days.add(r.day); retained.add(r.id); } }
  return sorted.filter(r => !retained.has(r.id));
}
export function overdue(completedAt, now, hours) {
  const when = Date.parse(completedAt);
  return !Number.isFinite(when) || when > now + 300000 || now - when > hours * 3600000;
}
function command(program, args, stage, input, env = process.env, maxBuffer = MAX) {
  try { return execFileSync(program, args, { input, env, stdio: ['pipe', 'pipe', 'pipe'], timeout: 180000, maxBuffer }); }
  catch { throw new StageError(stage); } // Never forward process arguments, stderr or credentials.
}
function atomic(file, value) {
  const tmp = `${file}.${randomUUID()}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(value, null, 2) + '\n', { mode: 0o600, flag: 'wx' });
  fs.renameSync(tmp, file);
}
function loadConfig() {
  const info = fs.lstatSync(`${ROOT}/runtime.json`), dir = fs.lstatSync(ROOT);
  if (!info.isFile() || info.isSymbolicLink() || (info.mode & 0o077) || info.uid !== 0 ||
      !dir.isDirectory() || dir.isSymbolicLink() || (dir.mode & 0o077)) throw new StageError('private_config_required');
  return validateConfig(JSON.parse(fs.readFileSync(`${ROOT}/runtime.json`, 'utf8')));
}
function storage(c) {
  const env = { ...process.env };
  const values = { TYPE: 's3', PROVIDER: 'Cloudflare', ACCESS_KEY_ID: c.accessKey,
    SECRET_ACCESS_KEY: c.secretAccessKey, ENDPOINT, REGION: 'auto', NO_CHECK_BUCKET: 'true', FORCE_PATH_STYLE: 'true' };
  for (const [k, v] of Object.entries(values)) env[`RCLONE_CONFIG_TDS_${k}`] = v;
  const flags = ['--config', '/dev/null', '--retries', '1', '--low-level-retries', '1', '--contimeout', '15s', '--timeout', '90s'];
  return (args, stage, input, maxBuffer) => command('rclone', [...args, ...flags], stage, input, env, maxBuffer);
}
const object = key => `tds:${BUCKET}/${key}`;
async function email(c, text) {
  if (c.mail?.provider === 'dokploy_database_backup') {
    try {
      const [{ db }, { notifications }, { and, eq }] = await Promise.all([
        import('/app/node_modules/@dokploy/server/dist/db/index.js'),
        import('/app/node_modules/@dokploy/server/dist/db/schema/index.js'),
        import('/app/node_modules/drizzle-orm/index.js'),
      ]);
      const selected = await db.query.notifications.findMany({
        where: and(eq(notifications.databaseBackup, true), eq(notifications.organizationId, c.mail.organizationId)),
        columns: { notificationId: true },
      });
      if (selected.length !== 1 || selected[0].notificationId !== c.mail.notificationId) {
        return { status: 'native_notification_mismatch', delivered: false };
      }
      const { sendDatabaseBackupNotifications } = await import('/app/node_modules/@dokploy/server/dist/utils/notifications/database-backup.js');
      await sendDatabaseBackupNotifications({ projectName: 'Tutor TDS', applicationName: 'Backup agendado TDS',
        databaseType: 'postgres', databaseName: 'Tutor TDS', type: 'error', errorMessage: text,
        organizationId: c.mail.organizationId });
      // Dokploy v0.29.1 catches delivery errors internally. This confirms dispatch only.
      return { status: 'native_dispatch_unverified', delivered: false };
    } catch { return { status: 'native_dispatch_failed', delivered: false }; }
  }
  if (!c.mail?.deliveryVerified) return { status: 'not_configured', delivered: false };
  try {
    const m = c.mail;
    if (!m.host || ![465, 587].includes(m.port) || !m.user || !m.pass || !m.from || m.to !== 'tdsdados@gmail.com') throw new Error();
    const require = createRequire('/app/package.json');
    const smtp = require('nodemailer').createTransport({ host: m.host, port: m.port, secure: m.port === 465,
      requireTLS: true, auth: { user: m.user, pass: m.pass }, tls: { rejectUnauthorized: true },
      connectionTimeout: 15000, socketTimeout: 20000 });
    const sent = await smtp.sendMail({ from: m.from, to: m.to, subject: '[Tutor TDS] Alerta de backup', text });
    return { status: 'smtp_accepted', delivered: sent.accepted?.includes(m.to) === true };
  } catch { return { status: 'delivery_failed', delivered: false }; }
}
function collectReceipts(s3) {
  const listing = JSON.parse(s3(['lsjson', object(PREFIX), '--recursive', '--files-only', '--include', '*/receipt.json'], 'list_receipts', undefined, 2 * 1024 * 1024));
  if (!Array.isArray(listing) || listing.length > 2000) throw new StageError('receipt_inventory_limit');
  const records = [];
  for (const entry of listing) {
    const match = /^([^/]+)\/receipt.json$/.exec(entry.Path);
    if (!match || !ID.test(match[1])) continue; // Never touch foreign objects.
    const raw = s3(['cat', object(PREFIX + entry.Path)], 'read_receipt', undefined, 16384);
    const receipt = validateReceipt(JSON.parse(raw), match[1]);
    const stat = JSON.parse(s3(['lsjson', object(receipt.key), '--stat'], 'verify_retention_object', undefined, 16384));
    if (stat.IsDir || stat.Size !== receipt.bytes) throw new StageError('retention_object_missing_or_different');
    records.push(receipt);
  }
  return records;
}
async function backup(c) {
  const s3 = storage(c), started = new Date(), id = started.toISOString().replace(/[-:]/g, '').slice(0, 15) + 'Z-' + randomUUID().replaceAll('-', '');
  const before = JSON.parse(command('docker', ['inspect', '--format', '{{json .Config.Labels}}', 'tutor-tds-api-db-1'], 'source_identity'));
  if (before['com.docker.compose.project'] !== 'tutor-tds-api' || before['com.docker.compose.service'] !== 'db') throw new StageError('source_identity');
  const dump = command('docker', ['exec', '-e', 'PGOPTIONS=-c default_transaction_read_only=on -c statement_timeout=120000',
    'tutor-tds-api-db-1', 'pg_dump', '-U', 'tutor_tds', '-d', 'tutor_tds', '--format=custom', '--no-owner', '--no-privileges', '--lock-wait-timeout=5s'], 'pg_dump');
  if (dump.length < 5 || dump.subarray(0, 5).toString() !== 'PGDMP') throw new StageError('dump_format');
  const cipher = command(`${ROOT}/bin/age`, ['--encrypt', '--recipient', c.recipient], 'encryption', dump, process.env, MAX + 65536);
  dump.fill(0);
  if (!cipher.subarray(0, 22).toString().startsWith('age-encryption.org/v1\n')) throw new StageError('encryption_format');
  const key = `${PREFIX}${id}/archive.dump.age`, hash = digest(cipher);
  s3(['rcat', object(key), '--immutable'], 'upload', cipher);
  const returned = s3(['cat', object(key)], 'download', undefined, MAX + 65536);
  if (returned.length !== cipher.length || digest(returned) !== hash) throw new StageError('download_integrity');
  const completedAt = new Date().toISOString();
  // Retention day follows start time; refuse crossing midnight rather than mislabeling a receipt.
  if (completedAt.slice(0, 10) !== started.toISOString().slice(0, 10)) throw new StageError('utc_day_changed');
  const receipt = { schema: 1, owner: OWNER, id, key, bucket: BUCKET, status: 'verified', sha256: hash,
    bytes: cipher.length, completedAt, day: completedAt.slice(0, 10), source: 'tutor-tds-api-db-1/tutor_tds',
    sourceReadOnly: true, clientEncryption: 'age', privateKeyUsed: false, restoreExecuted: false };
  validateReceipt(receipt, id);
  const bytes = Buffer.from(JSON.stringify(receipt) + '\n');
  s3(['rcat', object(`${PREFIX}${id}/receipt.json`), '--immutable'], 'receipt_upload', bytes);
  if (!s3(['cat', object(`${PREFIX}${id}/receipt.json`)], 'receipt_download', undefined, 16384).equals(bytes)) throw new StageError('receipt_integrity');
  atomic(`${ROOT}/last-success.json`, receipt); // Only after ciphertext and receipt round trips.
  let deleted = 0;
  if (c.retentionEnabled === true) {
    for (const old of expiredReceipts(collectReceipts(s3))) {
      if (old.id === id) throw new StageError('current_backup_retention_guard');
      s3(['deletefile', object(old.key)], 'retention_archive');
      s3(['deletefile', object(`${PREFIX}${old.id}/receipt.json`)], 'retention_receipt');
      deleted++;
    }
  }
  return { status: 'BACKUP_TRANSPORT_VERIFIED', id, key, bytes: receipt.bytes, sha256: hash, deleted,
    retentionEnabled: c.retentionEnabled === true,
    emailConfigured: c.mail?.deliveryVerified === true || c.mail?.provider === 'dokploy_database_backup',
    noPlaintextFile: true, privateKeyUsed: false, restoreExecuted: false };
}
async function monitor(c) {
  const s3 = storage(c), now = Date.now(), problems = [];
  const receipts = collectReceipts(s3).sort((a, b) => b.completedAt.localeCompare(a.completedAt));
  if (!receipts.length || overdue(receipts[0].completedAt, now, 26)) problems.push('tds_backup_missing_or_older_than_26h');
  if (c.weeklyPrefix) {
    const files = JSON.parse(s3(['lsjson', object(c.weeklyPrefix), '--files-only'], 'list_weekly', undefined, 1024 * 1024));
    const dates = files.filter(x => !x.IsDir && x.Size > 0 && /^webserver-backup-.*\.zip$/.test(x.Name)).map(x => x.ModTime).filter(x => Number.isFinite(Date.parse(x))).sort();
    if (!dates.length || overdue(dates.at(-1), now, 8 * 24)) problems.push('dokploy_backup_missing_or_older_than_8d');
  } else problems.push('weekly_prefix_missing');
  if (!c.mail?.deliveryVerified && c.mail?.provider !== 'dokploy_database_backup') problems.push('email_delivery_not_configured');
  const report = { status: problems.length ? 'MONITOR_ACTION_REQUIRED' : 'MONITOR_OK', checkedAt: new Date().toISOString(), problems };
  if (problems.length) report.alert = await email(c, 'Problemas de backup: ' + problems.join(', ') + '. Consulte os logs do Dokploy. Nenhum dado pessoal incluido.');
  atomic(`${ROOT}/monitor-status.json`, report);
  return report;
}
export async function main(mode = 'plan') {
  if (mode === 'plan') { console.log(JSON.stringify({ status: 'PLAN_ONLY', network: false, fileWrites: false, keepDaily: 30, prefix: PREFIX })); return 0; }
  if (!['backup', 'monitor', 'probe-failure'].includes(mode)) { console.log('{"status":"INVALID_MODE"}'); return 2; }
  let c;
  try {
    c = loadConfig();
    if (mode === 'probe-failure') throw new StageError('controlled_failure_no_database_or_storage_access');
    const result = mode === 'backup' ? await backup(c) : await monitor(c);
    console.log(JSON.stringify(result));
    return result.status === 'MONITOR_ACTION_REQUIRED' ? 1 : 0;
  } catch (error) {
    const stage = error instanceof StageError ? error.stage : 'local_or_contract_error';
    const alert = c ? await email(c, 'Falha de backup TDS na etapa: ' + stage + '. Verifique o Dokploy.') : { status: 'config_unavailable', delivered: false };
    const result = { status: 'BACKUP_ACTION_REQUIRED', stage, mode, occurredAt: new Date().toISOString(), alert };
    try { atomic(`${ROOT}/last-failure.json`, result); } catch { /* preserve safe stdout even on filesystem failure */ }
    console.log(JSON.stringify(result)); return 1;
  }
}
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) process.exitCode = await main(process.argv[2]);
