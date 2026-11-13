import test from 'node:test';
import assert from 'node:assert/strict';
import {fresh,createTask,planAction} from '../src/core.ts';
import {createWorkflow,ensureWorkflowStore} from '../src/workflows.ts';
import {getProactiveFeed,hideProactiveItem,resetProactiveItems,queueProactiveProposal} from '../src/proactive.ts';

const now=new Date('2026-11-14T03:00:00.000Z'); // 10:00 Saturday Vietnam
const offset=420;
test('task urgency and approval recommendations are correctly bounded and read-only',()=>{
 const s=fresh();
 const late=createTask(s,'Việc quá hạn','2026-11-12T08:00:00Z');
 const today=createTask(s,'Việc hôm nay','2026-11-14T10:00:00Z');
 const soon=createTask(s,'Sắp tới','2026-11-15T15:00:00Z');
 const later=createTask(s,'Tháng sau','2026-12-30T00:00:00Z');
 const done=createTask(s,'Đã xong','2026-11-10T08:00:00Z');done.done=true;
 planAction(s,'create_task',{title:'Chờ duyệt',dueAt:null});
 createWorkflow(ensureWorkflowStore(s),'Ghi chú',[{kind:'create_note',payload:{title:'A',content:'B'}}]);
 const before=JSON.stringify(s);
 const feed=getProactiveFeed(s,offset,now);
 assert.equal(feed.localDate,'2026-11-14');
 assert.equal(feed.totalCount,4);
 assert.equal(feed.items[0].id,'task-'+late.id);
 assert.equal(feed.items.find(x=>x.id==='task-'+today.id)?.level,'important');
 assert.equal(feed.items.find(x=>x.id==='task-'+soon.id)?.level,'info');
 assert.ok(feed.items.some(x=>x.id==='approvals'));
 assert.equal(feed.items.some(x=>x.id==='task-'+later.id),false);
 assert.equal(feed.items.some(x=>x.id==='task-'+done.id),false);
 assert.equal(JSON.stringify(s),before);
});
test('4-hour and 7-day snoozes suppress but auto-expire, reset restores',()=>{
 const s=fresh();const task=createTask(s,'Việc quan trọng','2026-11-13T16:30:00Z');
 const id='task-'+task.id;
 let feed=hideProactiveItem(s,id,4,offset,now);
 assert.equal(feed.items.length,0);
 assert.equal(feed.hiddenCount,1);
 assert.equal(getProactiveFeed(s,offset,new Date(now.getTime()+4*3600000)).items.length,1);
 feed=hideProactiveItem(s,id,168,offset,now);
 assert.equal(feed.items.length,0);
 assert.equal(getProactiveFeed(s,offset,new Date(now.getTime()+24*3600000)).items.length,0);
 feed=resetProactiveItems(s,offset,now);
 assert.equal(feed.hiddenCount,0);
 assert.equal(feed.items.length,1);
});
test('invalid IDs and periods cannot create arbitrary state or bypass quota',()=>{
 const s=fresh();const before=JSON.stringify(s);
 for(const id of ['other','task-fake','','x'.repeat(101)])
   assert.throws(()=>hideProactiveItem(s,id,4,offset,now),/suggestion|id/);
 for(const hours of [0,1,8,169,'4',null])
   assert.throws(()=>hideProactiveItem(s,'approvals',hours,offset,now),/duration/);
 for(const offset of [841,-721,420.1,NaN,Infinity])
   assert.throws(()=>getProactiveFeed(s,offset,now),/offset/);
 assert.equal(JSON.stringify(s),before);
});
test('more than five open tasks prompts planning; at most 15 visible entries',()=>{
 const s=fresh();
 for(let i=0;i<30;i++)createTask(s,'Việc '+i,'2026-11-12T15:00:00Z');
 const feed=getProactiveFeed(s,offset,now);
 assert.ok(feed.items.some(x=>x.id==='weekly-plan')===false); // lower priority is beyond first 15
 assert.equal(feed.totalCount,31);
 assert.equal(feed.items.length,15);
 const prefsBefore=JSON.stringify(s);
 getProactiveFeed(s,offset,now);
 assert.equal(JSON.stringify(s),prefsBefore);
});
test('completed tasks cease to appear even while suppression is stored',()=>{
 const s=fresh();const task=createTask(s,'Hôm nay','2026-11-14T12:00:00Z');
 hideProactiveItem(s,'task-'+task.id,24,offset,now);
 task.done=true;
 const feed=getProactiveFeed(s,offset,now);
 assert.equal(feed.totalCount,0);
 assert.equal(feed.hiddenCount,0);
});

test('task proposals queue an approval-only note exactly once',()=>{
 const s=fresh();const task=createTask(s,'Làm hồ sơ','2026-11-13T16:00:00Z');
 const id='task-'+task.id;
 const proposal=queueProactiveProposal(s,id,offset,now);
 assert.equal(proposal.status,'awaiting_approval');
 assert.equal(proposal.steps[0].kind,'create_note');
 assert.equal(proposal.steps[0].status,'awaiting_approval');
 assert.equal((s as typeof s & {notes?:unknown[]}).notes?.length,0);
 assert.equal(queueProactiveProposal(s,id,offset,now).id,proposal.id);
 assert.equal((s as typeof s & {workflows?:unknown[]}).workflows?.length,1);
 assert.throws(()=>queueProactiveProposal(s,'approvals',offset,now),/no task proposal/);
 assert.throws(()=>queueProactiveProposal(s,'task-not-real',offset,now),/no task proposal/);
 task.done=true;
 assert.throws(()=>queueProactiveProposal(s,id,offset,now),/no task proposal/);
});
