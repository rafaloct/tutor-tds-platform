/** Read-only external HTTPS checks; no credentials or TLS bypass. */
import assert from 'node:assert/strict';
import {resolve4,resolve6} from 'node:dns/promises';
const host='portal.ipexdesenvolvimento.cloud';
const base=`https://${host}`;
const request=(url)=>fetch(url,{redirect:'manual',signal:AbortSignal.timeout(20000),headers:{'User-Agent':'TutorTDS-Portal/1.0'}});
let checks=0;
for(const path of ['/','/cursos','/programa','/noticias','/agenda','/materiais','/faq','/privacidade','/direitos-e-exclusao','/acessibilidade','/contato','/sitemap.xml']){
  const r=await request(base+path);assert.equal(r.status,200,path);
  const body=await r.text();assert(!body.includes('The website encountered an unexpected error'),path);
  if(path==='/cursos') assert((body.match(/href="\/cursos\//g)||[]).length===9,'catalog');
  assert(!/http:\/\/portal\.ipexdesenvolvimento\.cloud/.test(body),'insecure canonical link');
  checks++;
}
let r=await request(base+'/health');assert.equal(r.status,200);let data=await r.json();assert.equal(data.database,'up');assert.equal(data.environment,'production');assert.match(r.headers.get('cache-control'),/no-store/);checks++;
r=await request(base+'/tds/session/context');assert.equal(r.status,403);assert.equal((await r.json()).error,'production_sessions_disabled');assert.match(r.headers.get('cache-control'),/no-store/);checks++;
for(const path of ['/core/install.php','/update.php']){r=await request(base+path);assert.equal(r.status,403);await r.arrayBuffer();checks++;}
r=await request('http://'+host+'/cursos');assert([301,302,307,308].includes(r.status));assert.equal(r.headers.get('location'),base+'/cursos');await r.arrayBuffer();checks++;
r=await request('https://ead.ipexdesenvolvimento.cloud/tutor-api/health');assert.equal(r.status,200);await r.arrayBuffer();checks++;
console.log(JSON.stringify({status:'PUBLIC_HTTPS_PASS',checks,catalogCourses:9,dnsA:await resolve4(host),dnsAAAA:await resolve6(host).catch(e=>{if(['ENODATA','ENOTFOUND'].includes(e.code))return [];throw e;}),tlsVerification:true,authenticatedFlowsTested:false}));
