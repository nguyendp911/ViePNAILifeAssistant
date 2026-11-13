// Minimal end-to-end API test: run against gateway on loopback, no external AI account required.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
const dir=await mkdtemp(join(tmpdir(),'viepn-api-'));
const token='test_token_1234567890_ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const port=31000+Math.floor(Math.random()*10000);
const base=`http://127.0.0.1:${port}`;
const child=spawn(process.execPath,['--experimental-strip-types','src/server.ts'],{cwd:new URL('../',import.meta.url).pathname,env:{...process.env,PORT:String(port),VIEPN_GATEWAY_TOKEN:token,VIEPN_DATA_FILE:join(dir,'db.json')},stdio:['ignore','pipe','pipe']});
async function req(path,method='GET',body,auth=true) {
 const r=await fetch(base+path,{method,headers:{...(auth?{authorization:'Bearer '+token}:{}),'content-type':'application/json'},body:body?JSON.stringify(body):undefined});
 return {status:r.status,body:await r.json()};
}
try {
 let ready=false;
 for(let i=0;i<60;i++){try{if((await req('/health')).status===200){ready=true;break}}catch{}await new Promise(r=>setTimeout(r,100))}
 assert.ok(ready,'server did not start');
 assert.equal((await req('/v1/skills','GET',undefined,false)).status,401);
 let r=await req('/v1/profiles','POST',{name:'Khách hàng',style:'lịch sự'});assert.equal(r.status,201);
 const profile=r.body.id;
 r=await req('/v1/profiles');assert.equal(r.body.items[0].id,profile);
 r=await req('/v1/memories','POST',{text:'Nội dung quan trọng',consent:false});assert.equal(r.status,400);
 r=await req('/v1/memories','POST',{text:'Nội dung quan trọng',consent:true});assert.equal(r.status,201);
 r=await req('/v1/memories/search?q=quan');assert.equal(r.body.items.length,1);
 r=await req('/v1/automations','POST',{title:'Điểm danh',intervalMinutes:60,skill:'create_task',payload:{title:'Gọi khách'},enabled:false});assert.equal(r.status,201);
 const id=r.body.id;
 r=await req('/v1/automations/'+id+'/enable','POST');assert.equal(r.body.enabled,true);
 r=await req('/v1/automations/tick','POST');assert.equal(r.body.created,0);
 r=await req('/v1/replies/draft','POST',{message:'Xin chào',profileId:profile});assert.equal(r.status,200);assert.equal(r.body.configured,false);
 r=await req('/v1/workflows/preview','POST',{title:'Kế hoạch thử nghiệm',note:'Tài liệu A',task:'Gửi tài liệu A'});
 assert.equal(r.status,200);assert.equal(r.body.executed,false);assert.equal(r.body.requiresApproval,true);
 assert.equal(r.body.steps.length,2);
 const draft=r.body;
 r=await req('/v1/workflows','POST',{title:draft.title,steps:draft.steps});assert.equal(r.status,201);
 const flowId=r.body.id;
 let flow=r.body;
 r=await req(`/v1/workflows/${flowId}/steps/${flow.steps[0].id}/approve`,'POST');assert.equal(r.status,200);
 flow=r.body;
 r=await req(`/v1/workflows/${flowId}/steps/${flow.steps[1].id}/approve`,'POST');assert.equal(r.status,200);
 assert.equal(r.body.status,'completed');
 r=await req('/v1/tasks');assert.equal(r.status,200);assert.equal(r.body.items.length,1);
 const taskId=r.body.items[0].id;
 r=await req(`/v1/tasks/${taskId}`,'PATCH',{done:true});assert.equal(r.status,200);assert.equal(r.body.done,true);
 r=await req('/v1/export');assert.equal(r.status,200);assert.equal(r.body.schemaVersion,1);
 assert.equal(r.body.tasks[0].done,true);assert.equal(r.body.notes.length,1);
 assert.equal(Object.hasOwn(r.body,'token'),false);
 r=await req('/v1/workflows/ai-preview','POST',{request:'Lập lịch tuần này'});assert.equal(r.status,503);
 r=await req('/v1/workflows/preview','POST',{title:'Không duyệt',memory:'Thông tin cá nhân'});
 assert.equal(r.status,400);
 console.log('API_INTEGRATION_PASS: auth, profiles, memory consent/search, automation, draft, plan preview, approval, completed task, personal export');
}finally{child.kill('SIGTERM');await rm(dir,{recursive:true,force:true})}
