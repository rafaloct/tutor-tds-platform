/** Run inside the existing Dokploy container, as an authorized administrator.
 * Uses its versioned service layer. Never prints environment values.
 * Creation only: reruns preserve all existing credentials and configuration.
 */
import { randomBytes } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, chmodSync } from 'node:fs';
import { db } from '/app/node_modules/@dokploy/server/dist/db/index.js';
import { createCompose, updateCompose } from '/app/node_modules/@dokploy/server/dist/services/compose.js';
const [environmentId, imageRef, proxyAddress, sourceRoot] = process.argv.slice(2);
if (!environmentId || !/^sha256:[a-f0-9]{64}$/.test(imageRef ?? '') || !/^\d+\.\d+\.\d+\.\d+$/.test(proxyAddress ?? '') || !sourceRoot?.startsWith('/etc/dokploy/')) throw Error('Invalid deployment inputs');
const name = 'Portal Drupal';
const description = 'Tutor TDS public Drupal; issue #210; academic sessions and AI disabled.';
const entries = await db.query.compose.findMany({columns:{composeId:true,name:true,environmentId:true,description:true,appName:true}});
let entry = entries.find(c => c.environmentId === environmentId && c.name === name);
if (entry) {
  if (entry.description !== description) throw Error('Existing unrelated service; refusing overwrite');
  console.log(JSON.stringify({status:'exists_unchanged',composeId:entry.composeId,appName:entry.appName}));
  process.exit(0);
}
const secret = () => randomBytes(48).toString('hex');
const values = {
  DRUPAL_IMAGE_REF:imageRef,
  PORTAL_HOST:'portal.ipexdesenvolvimento.cloud',
  DRUPAL_TRUSTED_HOSTS:'^portal\\.ipexdesenvolvimento\\.cloud$',
  DRUPAL_REVERSE_PROXY_ADDRESSES:proxyAddress,
  DRUPAL_DB_NAME:'tds_portal', DRUPAL_DB_USER:'tds_portal',
  DRUPAL_DB_PASSWORD:secret(), DRUPAL_DB_ROOT_PASSWORD:secret(),
  DRUPAL_HASH_SALT:secret(), DRUPAL_ADMIN_USER:'editorial_admin',
  DRUPAL_ADMIN_PASSWORD:secret(),
  TUTOR_API_BASE_URL:'https://ead.ipexdesenvolvimento.cloud/tutor-api',
};
const env = Object.entries(values).map(([k,v]) => `${k}='${v}'`).join('\n')+'\n';
const composeFile = readFileSync(`${sourceRoot}/drupal/production/compose.yml`,'utf8');
entry = await createCompose({name,description,environmentId,appName:'tds-drupal-production',sourceType:'raw',composeType:'docker-compose',composeFile,env,autoDeploy:false,randomize:false});
// Limit future panel deployments to this application, without rebuilding/pruning.
await updateCompose(entry.composeId,{command:`compose -p ${entry.appName} -f docker-compose.yml up -d --no-build`});
const dir = `/etc/dokploy/compose/${entry.appName}/code`;
mkdirSync(dir,{recursive:true,mode:0o700});
chmodSync(`/etc/dokploy/compose/${entry.appName}`,0o700);
chmodSync(dir,0o700);
writeFileSync(`${dir}/docker-compose.yml`,composeFile,{mode:0o600});
writeFileSync(`${dir}/.env`,env,{mode:0o600});
writeFileSync(`${sourceRoot}/registration.json`,JSON.stringify({composeId:entry.composeId,appName:entry.appName,environmentId,imageRef,host:values.PORTAL_HOST}),{mode:0o600});
console.log(JSON.stringify({status:'registered',composeId:entry.composeId,appName:entry.appName,secretValuesPrinted:false}));
process.exit(0);
