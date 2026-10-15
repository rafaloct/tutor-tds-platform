/** Save the chosen domain in Dokploy; do not deploy or request a certificate. */
import {readFileSync} from 'node:fs';
import {db} from '/app/node_modules/@dokploy/server/dist/db/index.js';
import {createDomain} from '/app/node_modules/@dokploy/server/dist/services/domain.js';
import {findComposeById} from '/app/node_modules/@dokploy/server/dist/services/compose.js';
const r=JSON.parse(readFileSync(process.argv[2],'utf8'));
const entry=await findComposeById(r.composeId);
if(entry.appName!==r.appName || entry.name!=='Portal Drupal' || r.host!=='portal.ipexdesenvolvimento.cloud') throw Error('Service mismatch');
const existing=await db.query.domains.findMany({columns:{domainId:true,host:true,composeId:true}});
const found=existing.find(d=>d.host===r.host);
if(found && found.composeId!==r.composeId) throw Error('Domain already belongs to another service');
const domain=found ?? await createDomain({host:r.host,https:true,port:80,path:'/',internalPath:'/',stripPath:false,serviceName:'web',domainType:'compose',composeId:r.composeId,certificateType:'letsencrypt'});
console.log(JSON.stringify({domainId:domain.domainId,host:r.host,status:'configured_not_deployed',dnsChanged:false,certificateRequested:false}));
process.exit(0);
