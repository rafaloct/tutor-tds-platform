import test from 'node:test';
import assert from 'node:assert/strict';
import {validateRegistration,validateRuntime,validateContainer,verifyRoundtrip,digest,main} from './backup-dokploy.mjs';
const imageRef = 'sha256:'+'a'.repeat(64);
const r = {composeId:'test-compose',environmentId:'test-env',appName:'tds-drupal-production',imageRef};
const entry = {...r,name:'Portal Drupal'};
const c = {schema:1,bucket:'tds-backups',endpoint:'https://8b1d9dad829dd6927091666a1f186717.r2.cloudflarestorage.com',destinationId:'8mVX4789RC3FO4dS7dxHD',accessKey:'a'.repeat(32),secretAccessKey:'b'.repeat(64),recipient:'age1'+'q'.repeat(58)};
const info = (service='web') => ({Image:imageRef,State:{Running:true},Config:{Labels:{'com.docker.compose.project':r.appName,'com.docker.compose.service':service}},Mounts:(service==='web'?['/var/www/html/web/sites/default/files','/var/www/private']:['/var/lib/mysql']).map(Destination=>({Destination,Type:'volume',Name:r.appName+'_test'}))});
test('registration cannot select another project, environment or mutable image',()=>{
  assert.equal(validateRegistration(r,entry),r);
  for(const change of [{name:'Other'},{composeId:'other'},{appName:'other'},{environmentId:'other'}]) assert.throws(()=>validateRegistration(r,{...entry,...change}));
  for(const change of [{appName:'../other'},{imageRef:'drupal:latest'},{imageRef:''}]) assert.throws(()=>validateRegistration({...r,...change},entry));
});
test('runtime destination and public age recipient pinned; private identity refused',()=>{
  assert.equal(validateRuntime(c),c);
  for(const change of [{bucket:'other'},{endpoint:'http://example.test'},{destinationId:'other'},{recipient:'AGE-SECRET-KEY-1x'},{accessKey:''},{secretAccessKey:''},{identity:'secret'},{BACKUP_AGE_IDENTITY:'secret'}]) assert.throws(()=>validateRuntime({...c,...change}));
});
test('container labels, image and all dedicated volume mounts required',()=>{
  assert.ok(validateContainer(info(),r.appName,'web',imageRef));
  assert.ok(validateContainer(info('db'),r.appName,'db',imageRef));
  for(const mutate of [i=>i.State.Running=false,i=>i.Image='sha256:'+'b'.repeat(64),i=>i.Config.Labels['com.docker.compose.project']='other',i=>i.Config.Labels['com.docker.compose.service']='db',i=>i.Mounts.pop(),i=>i.Mounts[0].Type='bind',i=>i.Mounts[0].Name='unrelated_volume']) {
    const i=info(); mutate(i); assert.throws(()=>validateContainer(i,r.appName,'web',imageRef));
  }
});
test('transport roundtrip detects same-length corruption and truncation',()=>{
  const sent=Buffer.from('synthetic encrypted archive');
  const mockStorage={download:()=>Buffer.from(sent)};
  assert.equal(verifyRoundtrip(sent,mockStorage.download()),digest(sent));
  const corrupt=Buffer.from(sent); corrupt[2]^=1;
  assert.throws(()=>verifyRoundtrip(sent,corrupt));
  assert.throws(()=>verifyRoundtrip(sent,sent.subarray(1)));
});
test('default mode is inert and does not access Dokploy/runtime configuration',async()=>{
  assert.equal(await main('plan'),0);
});
