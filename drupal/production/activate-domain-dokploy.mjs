/** Explicit domain activation; run inside the existing Dokploy container. */
import {readFileSync, writeFileSync} from 'node:fs';
import {lookup} from 'node:dns/promises';
import {createRequire} from 'node:module';
import {findComposeById, updateCompose} from '/app/node_modules/@dokploy/server/dist/services/compose.js';
import {findDomainsByComposeId} from '/app/node_modules/@dokploy/server/dist/services/domain.js';
import {createDomainLabels} from '/app/node_modules/@dokploy/server/dist/utils/docker/domain.js';
const require=createRequire('/app/package.json');
const {parse,stringify}=require('yaml');
async function main(){
  const r=JSON.parse(readFileSync('/etc/dokploy/tds-drupal-ops/source/registration.json','utf8'));
  const entry=await findComposeById(r.composeId);
  if(entry.appName!==r.appName || entry.name!=='Portal Drupal' || r.host!=='portal.ipexdesenvolvimento.cloud' || entry.sourceType!=='raw' || entry.randomize || entry.isolatedDeployment) throw Error('identity');
  const addresses=await lookup(r.host,{all:true,family:4});
  if(!addresses.length || addresses.some(a=>a.address!=='46.202.150.132')) throw Error('dns');
  const domains=await findDomainsByComposeId(r.composeId);
  if(domains.length!==1) throw Error('domain_count');
  const d=domains[0];
  if(d.host!==r.host || d.serviceName!=='web' || !d.https || d.port!==80 || d.certificateType!=='letsencrypt') throw Error('domain_contract');
  const path=`/etc/dokploy/compose/${r.appName}/code/docker-compose.yml`;
  const original=readFileSync(path,'utf8');
  if(JSON.stringify(parse(original))!==JSON.stringify(parse(entry.composeFile))) throw Error('panel_file_drift');
  const spec=parse(original);
  if(!spec.services.web || !spec.services.db || spec.services.web.environment.TDS_ACADEMIC_SESSION_ENABLED!=='false') throw Error('service_contract');
  const labels={'traefik.enable':'true','traefik.docker.network':'dokploy-network'};
  for(const value of [...createDomainLabels(r.appName,d,'web'),...createDomainLabels(r.appName,d,'websecure')]){
    const i=value.indexOf('='); labels[value.slice(0,i)]=value.slice(i+1);
  }
  spec.services.web.labels=labels;
  const content=stringify(spec,{lineWidth:1000});
  if(process.argv[2]!=='--apply') return {status:'PLAN_ONLY',host:r.host,labelCount:Object.keys(labels).length};
  const backup='/etc/dokploy/tds-drupal-ops/pre-domain-compose.yml';
  try{writeFileSync(backup,original,{mode:0o600,flag:'wx'});}catch(e){if(e.code!=='EEXIST')throw e;}
  await updateCompose(r.composeId,{composeFile:content});
  writeFileSync(path,content,{mode:0o600});
  const saved=await findComposeById(r.composeId);
  if(saved.env!==entry.env || saved.composeFile!==content) throw Error('readback');
  return {status:'DOMAIN_CONFIGURED',host:r.host,requiresWebReconcile:true,secretsUnchanged:true};
}
try{console.log(JSON.stringify(await main()));process.exit(0);}catch{console.log(JSON.stringify({status:'DOMAIN_ACTIVATION_FAILED',detailsSuppressed:true}));process.exit(1);}
