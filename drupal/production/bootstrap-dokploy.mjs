/** Run within Dokploy after the isolated web/database have started. */
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { findComposeById } from '/app/node_modules/@dokploy/server/dist/services/compose.js';
const [registrationPath] = process.argv.slice(2);
const record = JSON.parse(readFileSync(registrationPath, 'utf8'));
const entry = await findComposeById(record.composeId);
if (entry.appName !== record.appName || entry.name !== 'Portal Drupal') throw Error('Service mismatch');
const values = Object.fromEntries(entry.env.split('\n').filter(Boolean).map(line => {
  const match = /^([A-Z_]+)='([^']*)'$/.exec(line);
  if (!match) throw Error('Unexpected environment format');
  return [match[1], match[2]];
}));
const cid = execFileSync('docker', ['ps','-q','--filter',`label=com.docker.compose.project=${entry.appName}`,'--filter','label=com.docker.compose.service=web'],{encoding:'utf8'}).trim();
if (!/^[a-f0-9]{12,64}$/.test(cid)) throw Error('Expected exactly one portal web container');
const image = execFileSync('docker',['inspect','--format','{{.Image}}',cid],{encoding:'utf8'}).trim();
if (image !== record.imageRef) throw Error('Running image mismatch');
try {
  execFileSync('docker',['exec','-i',cid,'php','production/install-from-stdin.php'],{
    input:JSON.stringify({username:values.DRUPAL_ADMIN_USER,password:values.DRUPAL_ADMIN_PASSWORD}),
    stdio:['pipe','ignore','ignore'],timeout:240000,
  });
  console.log(JSON.stringify({bootstrap:'completed',composeId:entry.composeId,secretsPrinted:false}));
} catch {
  console.log(JSON.stringify({bootstrap:'failed',detailsSuppressed:true}));
  process.exit(1);
}
process.exit(0);
