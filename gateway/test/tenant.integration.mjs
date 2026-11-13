import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtemp,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
const dir=await mkdtemp(join(tmpdir(),'viepn-tenant-'));
const alice='AliceToken_'+ 'A'.repeat(40),bob='BobToken_'+ 'B'.repeat(40);
const port=35000+Math.floor(Math.random()*14000),base=`http://127.0.0.1:${port}`;
const accounts=[{id:'alice',displayName:'Alice',token:alice},{id:'bob',displayName:'Bob',token:bob}];
const env={...process.env,PORT:String(port),VIEPN_ACCOUNTS_JSON:JSON.stringify(accounts),VIEPN_GATEWAY_TOKEN:'',VIEPN_DATA_FILE:join(dir,'state.json')};
let child;
async function call(token,path,method='GET',payload){const r=await fetch(base+path,{method,headers:{authorization:'Bearer '+token,'content-type':'application/json'},body:payload?JSON.stringify(payload):undefined});return {status:r.status,data:await r.json()}}
async function start(){child=spawn(process.execPath,['--experimental-strip-types','src/server.ts'],{cwd:new URL('../',import.meta.url).pathname,env,stdio:'ignore'});for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok)return}catch{}await new Promise(r=>setTimeout(r,50))}throw Error('server not ready')}
try{
 await start();
 assert.equal((await call(alice,'/v1/me')).data.id,'alice');
 assert.equal((await call(bob,'/v1/me')).data.id,'bob');
 assert.equal((await call(bob,'/v1/tasks','POST',{title:'Private Bob task'})).status,201);
 assert.equal((await call(alice,'/v1/memories','POST',{text:'Private Alice memory',consent:true})).status,201);
 assert.equal((await call(alice,'/v1/tasks')).data.items.length,0);
 // V4.4: server-side insights must never expose another tenant's task names.
 const aliceInsights=await call(alice,'/v1/insights?offsetMinutes=420');
 const bobInsights=await call(bob,'/v1/insights?offsetMinutes=420');
 assert.equal(aliceInsights.status,200);
 assert.equal(bobInsights.status,200);
 assert.equal(aliceInsights.data.progress.total,0);
 assert.equal(bobInsights.data.progress.total,1);
 assert.equal(JSON.stringify(aliceInsights.data).includes('Private Bob task'),false);
 assert.equal((await call(alice,'/v1/ai/personal-ask','POST',{
   question:'Công việc gì?',consent:false,includeTasks:true,includeMemories:false,includeDocuments:false
 })).status,400);
 assert.equal((await call(bob,'/v1/ai/personal-ask','POST',{
   question:'Công việc gì?',consent:true,includeTasks:true,includeMemories:false,includeDocuments:false
 })).status,503);

 // V4.2: plans must only include tasks owned by the authenticated tenant.
 const options={offsetMinutes:420,startTime:'08:00',endTime:'20:00',focusMinutes:25,breakMinutes:5};
 const alicePlan=await call(alice,'/v1/daily-plan/preview','POST',options);
 const bobPlan=await call(bob,'/v1/daily-plan/preview','POST',options);
 assert.equal(alicePlan.status,200);
 assert.equal(bobPlan.status,200);
 assert.equal(alicePlan.data.slots.length+alicePlan.data.unscheduledCount,0);
 assert.equal(bobPlan.data.slots.length+bobPlan.data.unscheduledCount,1);
 assert.equal(JSON.stringify(alicePlan.data).includes('Private Bob task'),false);
 // V4.3: weekly plans and explicitly opt-in focus aggregates are tenant-scoped.
 const week={offsetMinutes:420,weekOffset:1,startTime:'08:00',endTime:'16:00'};
 const aliceWeek=await call(alice,'/v1/weekly-plan/preview','POST',week);
 const bobWeek=await call(bob,'/v1/weekly-plan/preview','POST',week);
 assert.equal(aliceWeek.status,200);
 assert.equal(bobWeek.status,200);
 assert.equal(aliceWeek.data.scheduledCount,0);
 assert.equal(bobWeek.data.scheduledCount,1);
 assert.equal(JSON.stringify(aliceWeek.data).includes('Private Bob task'),false);
 assert.equal((await call(alice,'/v1/focus-history/consent','POST',{enabled:true})).status,200);
 assert.equal((await call(alice,'/v1/focus-history/record','POST',{minutes:25,offsetMinutes:420,hour:9})).status,201);
 assert.equal((await call(alice,'/v1/focus-history')).data.insights.sessions,1);
 assert.equal((await call(bob,'/v1/focus-history')).data.insights.sessions,0);
 assert.equal((await call(bob,'/v1/focus-history')).data.enabled,false);
 assert.equal((await call(bob,'/v1/memories')).data.items.length,0);
 assert.equal((await call(bob,'/v1/export')).data.memories.length,0);
 assert.equal((await call(alice,'/v1/export')).data.tasks.length,0);
 assert.equal((await call('incorrect','/v1/tasks')).status,401);
 child.kill('SIGTERM');await new Promise(r=>child.once('exit',r));
 await start();
 assert.equal((await call(bob,'/v1/tasks')).data.items[0].title,'Private Bob task');
 assert.equal((await call(alice,'/v1/memories')).data.items[0].text,'Private Alice memory');
 assert.equal((await call(alice,'/v1/focus-history')).data.insights.sessions,1);
 assert.equal((await call(bob,'/v1/focus-history')).data.enabled,false);
 assert.equal((await call(alice,'/v1/focus-history/consent','POST',{enabled:false})).status,200);
 assert.equal((await call(alice,'/v1/focus-history')).data.days.length,0);
 assert.equal(JSON.parse(await readFile(join(dir,'users','alice.json'),'utf8')).tasks.length,0);
 console.log('TENANT_INTEGRATION_PASS: identity, weekly/daily planning isolation, focus opt-in/erasure, exports, auth, restart persistence');
}finally {child?.kill('SIGTERM');await rm(dir,{recursive:true,force:true})}
