import test from 'node:test';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { validateConfig, validateReceipt, expiredReceipts, overdue, PREFIX, BUCKET, ENDPOINT } from './backup.mjs';
const config = () => ({ schema: 1, bucket: BUCKET, endpoint: ENDPOINT, destinationId: '8mVX4789RC3FO4dS7dxHD',
  accessKey: 'a'.repeat(32), secretAccessKey: 'b'.repeat(64), recipient: 'age1' + 'q'.repeat(58), keepDaily: 30, weeklyPrefix: null });
function receipt(n, time = '03:40:00') {
  const day = new Date(Date.UTC(2026, 0, n)).toISOString().slice(0, 10), id = day.replaceAll('-', '') + 'T' + time.replaceAll(':', '') + 'Z-' + 'c'.repeat(32);
  return { schema: 1, owner: 'tutor-tds-issue2-scheduled-v1', id, status: 'verified', bucket: BUCKET, key: PREFIX + id + '/archive.dump.age', sha256: 'd'.repeat(64), bytes: 500, day, completedAt: `${day}T${time}.000Z` };
}
test('plan is safe and works without config, credentials or runtime path', () => {
  const result = JSON.parse(execFileSync(process.execPath, [fileURLToPath(new URL('./backup.mjs', import.meta.url))], { encoding: 'utf8' }));
  assert.equal(result.status, 'PLAN_ONLY'); assert.equal(result.network, false); assert.equal(result.fileWrites, false);
});
test('accepts only approved config', () => assert.equal(validateConfig(config()).keepDaily, 30));
for (const patch of [{ bucket: 'other' }, { endpoint: 'http://localhost' }, { destinationId: 'other' }, { keepDaily: 1 },
  { accessKey: 'name-not-key' }, { secretAccessKey: 'short' }, { recipient: 'AGE-SECRET-KEY-not-allowed' },
  { identity: 'must-not-be-here' }, { BACKUP_AGE_IDENTITY: 'must-not-be-here' }, { weeklyPrefix: '../manual/' }]) {
  test(`rejects unsafe config ${Object.keys(patch)[0]}`, () => assert.throws(() => validateConfig({ ...config(), ...patch })));
}
test('valid receipt accepted', () => assert.equal(validateReceipt(receipt(1), receipt(1).id).bytes, 500));
for (const patch of [{ owner: 'foreign' }, { status: 'failed' }, { bucket: 'other' }, { key: 'postgres/encrypted/manual/archive.age' },
  { sha256: 'not-a-hash' }, { bytes: 0 }, { bytes: '500' }, { day: '2025-12-31' }, { completedAt: 'invalid' }]) {
  test(`rejects foreign or failed receipt ${Object.keys(patch)[0]}`, () => assert.throws(() => validateReceipt({ ...receipt(1), ...patch }, receipt(1).id)));
}
test('30 distinct valid days have no expiration', () => assert.equal(expiredReceipts(Array.from({ length: 30 }, (_, n) => receipt(n + 1))).length, 0));
test('31 days expire only the oldest', () => assert.deepEqual(expiredReceipts(Array.from({ length: 31 }, (_, n) => receipt(n + 1))).map(x => x.day), ['2026-01-01']));
test('retains latest run on each day', () => assert.deepEqual(expiredReceipts([receipt(1), receipt(1, '04:40:00')]).map(x => x.completedAt), [receipt(1).completedAt]));
test('duplicate receipt IDs fail closed', () => assert.throws(() => expiredReceipts([receipt(1), receipt(1)])));
test('does not mutate source receipt list', () => { const records = [receipt(1), receipt(2)]; expiredReceipts(records); assert.equal(records[0].day, '2026-01-01'); });
test('missing, stale and future timestamps are actionable', () => {
  const now = Date.parse('2026-01-03T00:00:00Z');
  for (const time of [undefined, 'invalid', '2026-01-01T00:00:00Z', '2026-01-04T00:00:00Z']) assert.equal(overdue(time, now, 26), true);
  assert.equal(overdue('2026-01-02T00:00:00Z', now, 26), false);
});
