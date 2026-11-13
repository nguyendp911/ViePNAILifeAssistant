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
 assert.equal((await call(bob,'/v1/memories')).data.items.length,0);
 assert.equal((await call(bob,'/v1/export')).data.memories.length,0);
 assert.equal((await call(alice,'/v1/export')).data.tasks.length,0);
 assert.equal((await call('incorrect','/v1/tasks')).status,401);
 child.kill('SIGTERM');await new Promise(r=>child.once('exit',r));
 await start();
 assert.equal((await call(bob,'/v1/tasks')).data.items[0].title,'Private Bob task');
 assert.equal((await call(alice,'/v1/memories')).data.items[0].text,'Private Alice memory');
 assert.equal(JSON.parse(await readFile(join(dir,'users','alice.json'),'utf8')).tasks.length,0);
 console.log('TENANT_INTEGRATION_PASS: identity, isolation, exports, auth, restart persistence');
}finally {child?.kill('SIGTERM');await rm(dir,{recursive:true,force:true})}
