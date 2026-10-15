/** Explicit backup only. No scheduling, restore, retention deletion or notification. */
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash, randomUUID} from 'node:crypto';
import {fileURLToPath} from 'node:url';
export const PREFIX = 'drupal/portal-production/v1/';
const ROOT = '/etc/dokploy/tds-backup-ops';
const REGISTRATION = '/etc/dokploy/tds-drupal-ops/source/registration.json';
const MAX = 64 * 1024 * 1024;
const PART_MAX = 16 * 1024 * 1024;
class SafeError extends Error {}
export const digest = value => createHash('sha256').update(value).digest('hex');
export function validateRegistration(r, entry) {
  if (!r || !/^[a-z0-9][a-z0-9_-]{1,99}$/.test(r.appName ?? '') || !r.composeId || !r.environmentId ||
    !entry || entry.name !== 'Portal Drupal' || entry.composeId !== r.composeId || entry.appName !== r.appName || entry.environmentId !== r.environmentId ||
    !/^sha256:[a-f0-9]{64}$/.test(r.imageRef ?? '')) throw new SafeError('source_registration');
  return r;
}
export function validateRuntime(c) {
  if (c?.schema !== 1 || c.bucket !== 'tds-backups' ||
    c.endpoint !== 'https://8b1d9dad829dd6927091666a1f186717.r2.cloudflarestorage.com' ||
    c.destinationId !== '8mVX4789RC3FO4dS7dxHD' ||
    !/^[a-f0-9]{32}$/i.test(c.accessKey ?? '') || !/^[a-f0-9]{64}$/i.test(c.secretAccessKey ?? '') ||
    !/^age1[023456789acdefghjklmnpqrstuvwxyz]{58}$/.test(c.recipient ?? '') ||
    'identity' in c || 'BACKUP_AGE_IDENTITY' in c) throw new SafeError('runtime_config');
  return c;
}
export function validateContainer(info, project, service, imageRef) {
  if (!info?.State?.Running || info.Config?.Labels?.['com.docker.compose.project'] !== project ||
    info.Config?.Labels?.['com.docker.compose.service'] !== service ||
    !/^sha256:[a-f0-9]{64}$/.test(info.Image ?? '') ||
    (service === 'web' && info.Image !== imageRef)) throw new SafeError('container_identity');
  const destinations = service === 'web' ? ['/var/www/html/web/sites/default/files', '/var/www/private'] : ['/var/lib/mysql'];
  if (destinations.some(d => !info.Mounts?.some(m => m.Destination === d && m.Type === 'volume' && m.Name?.startsWith(project + '_')))) throw new SafeError('volume_identity');
  return info;
}
export function verifyRoundtrip(sent, received) {
  if (sent.length !== received.length || digest(sent) !== digest(received)) throw new SafeError('roundtrip_integrity');
  return digest(sent);
}
function command(program, args, stage, input, env = process.env, maxBuffer = MAX) {
  try { return execFileSync(program, args, {input, env, timeout:180000, maxBuffer, stdio:['pipe','pipe','pipe']}); }
  catch { throw new SafeError(stage); }
}
function privateJson(file) {
  const s = fs.lstatSync(file);
  if (!s.isFile() || s.isSymbolicLink() || s.uid !== 0 || (s.mode & 0o077) || s.size > 1024 * 1024) throw new SafeError('private_config_permissions');
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}
function source(service, r) {
  const ids = command('docker', ['ps','--filter',`label=com.docker.compose.project=${r.appName}`,'--filter',`label=com.docker.compose.service=${service}`,'--format','{{.ID}}'], 'container_lookup', undefined, process.env, 4096).toString().trim().split('\n');
  if (ids.length !== 1 || !/^[a-f0-9]{12,64}$/.test(ids[0])) throw new SafeError('container_count');
  // Deliberately exclude Config.Env from inspect output.
  const info = JSON.parse(command('docker', ['inspect','--format','{"Image":{{json .Image}},"State":{"Running":{{json .State.Running}}},"Config":{"Labels":{{json .Config.Labels}}},"Mounts":{{json .Mounts}}}',ids[0]], 'container_inspect', undefined, process.env, 65536));
  return {id:ids[0], info:validateContainer(info,r.appName,service,r.imageRef)};
}
export async function performBackup({r, entry, c, run = command}) {
  validateRegistration(r,entry); validateRuntime(c);
  let dir;
  const sensitive = [];
  try {
    if (fs.statfsSync('/dev/shm').type !== 0x01021994) throw new SafeError('tmpfs_required');
    dir = fs.mkdtempSync('/dev/shm/tds-drupal-backup-'); fs.chmodSync(dir,0o700);
    const web = source('web',r), database = source('db',r);
    const startedAt = new Date().toISOString(), id = randomUUID();
    const files = {};
    function save(name, data) {
      sensitive.push(data);
      const stat = fs.statfsSync(dir);
      if (data.length > PART_MAX || stat.bavail * stat.bsize < data.length + 1024 * 1024) throw new SafeError('tmpfs_capacity');
      fs.writeFileSync(path.join(dir,name),data,{mode:0o600,flag:'wx'});
      files[name] = {bytes:data.length,sha256:digest(data)};
      data.fill(0);
    }
    const dump = run('docker',['exec',database.id,'sh','-ec',
      'export MYSQL_PWD="$MARIADB_PASSWORD"; exec mariadb-dump --user="$MARIADB_USER" --single-transaction --quick --skip-lock-tables --hex-blob --no-tablespaces "$MARIADB_DATABASE"'], 'database_dump',undefined,process.env,PART_MAX);
    if (dump.length < 100 || !dump.toString('utf8',0,4096).includes('MariaDB dump')) throw new SafeError('dump_format');
    save('database.sql',dump);
    for (const [name,mount] of [['public-files.tar','/var/www/html/web/sites/default/files'],['private-files.tar','/var/www/private']]) {
      save(name,run('docker',['exec',web.id,'tar','-C',mount,'-cf','-','.'],'files_archive',undefined,process.env,PART_MAX));
    }
    if (typeof entry.env !== 'string' || typeof entry.composeFile !== 'string' || !entry.env || !entry.composeFile) throw new SafeError('compose_custody');
    save('environment.env',Buffer.from(entry.env)); save('compose.yml',Buffer.from(entry.composeFile));
    const manifest = {schema:1,id,startedAt,source:{composeId:r.composeId,appName:r.appName,webImage:web.info.Image,dbImage:database.info.Image},files,
      consistency:{database:'single-transaction; requires transactional tables and no concurrent DDL',files:'non-atomic live copy; no maintenance or service stop'},restoreExecuted:false};
    save('manifest.json',Buffer.from(JSON.stringify(manifest)+'\n'));
    const archive = run('tar',['-C',dir,'-cf','-','database.sql','public-files.tar','private-files.tar','environment.env','compose.yml','manifest.json'],'archive'); sensitive.push(archive);
    const cipher = run(`${ROOT}/bin/age`,['--encrypt','--recipient',c.recipient],'encryption',archive); archive.fill(0);
    if (!cipher.subarray(0,22).toString().startsWith('age-encryption.org/v1\n')) throw new SafeError('cipher_format');
    const env = {...process.env};
    for (const [k,v] of Object.entries({TYPE:'s3',PROVIDER:'Cloudflare',ACCESS_KEY_ID:c.accessKey,SECRET_ACCESS_KEY:c.secretAccessKey,ENDPOINT:c.endpoint,REGION:'auto',NO_CHECK_BUCKET:'true',FORCE_PATH_STYLE:'true'})) env[`RCLONE_CONFIG_TDS_${k}`] = v;
    const flags = ['--config','/dev/null','--retries','1','--low-level-retries','1','--contimeout','15s','--timeout','90s'];
    const object = `tds:${c.bucket}/${PREFIX}${id}/archive.tar.age`;
    run('rclone',['rcat',object,'--immutable',...flags],'upload',cipher,env);
    const returned = run('rclone',['cat',object,...flags],'download',undefined,env);
    const sha256 = verifyRoundtrip(cipher,returned);
    const receipt = {schema:1,status:'BACKUP_TRANSPORT_VERIFIED',id,key:`${PREFIX}${id}/archive.tar.age`,sha256,bytes:cipher.length,completedAt:new Date().toISOString(),filesAtomic:false,restoreExecuted:false};
    const bytes = Buffer.from(JSON.stringify(receipt)+'\n');
    const receiptObject = `tds:${c.bucket}/${PREFIX}${id}/receipt.json`;
    run('rclone',['rcat',receiptObject,'--immutable',...flags],'receipt_upload',bytes,env);
    verifyRoundtrip(bytes,run('rclone',['cat',receiptObject,...flags],'receipt_download',undefined,env,16384));
    return receipt;
  } finally {
    for (const b of sensitive) b.fill(0);
    if (dir) fs.rmSync(dir,{recursive:true,force:true});
  }
}
export async function main(mode) {
  if (mode !== 'backup') { console.log(JSON.stringify({status:'PLAN_ONLY',prefix:PREFIX,fileWrites:false,network:false})); return 0; }
  try {
    const r = privateJson(REGISTRATION), c = validateRuntime(privateJson(`${ROOT}/runtime.json`));
    const {db} = await import('/app/node_modules/@dokploy/server/dist/db/index.js');
    const entry = await db.query.compose.findFirst({where:(compose,{eq})=>eq(compose.composeId,r.composeId),columns:{composeId:true,environmentId:true,appName:true,name:true,env:true,composeFile:true}});
    console.log(JSON.stringify(await performBackup({r,c,entry})));
    return 0;
  } catch (e) { console.log(JSON.stringify({status:'BACKUP_FAILED',stage:e instanceof SafeError ? e.message : 'local_or_contract_error',restoreExecuted:false})); return 1; }
}
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) process.exit(await main(process.argv[2]));
