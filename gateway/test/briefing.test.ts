import test from 'node:test';
import assert from 'node:assert/strict';
import {fresh,createTask,planAction} from '../src/core.ts';
import {enhanced,addAutomation,getPending} from '../src/personal.ts';
import {ensureWorkflowStore,createWorkflow} from '../src/workflows.ts';
import {dailyBriefing} from '../src/briefing.ts';

const now=new Date('2026-11-13T04:00:00.000Z'); // 11:00 in Vietnam (UTC+07)

test('Vietnamese local-day boundaries and task priority order',()=>{
  const s=fresh();
  const old=createTask(s,'Quá hạn','2026-11-12T16:59:59Z');
  const today=createTask(s,'Hôm nay','2026-11-13T16:59:59Z');
  const tomorrow=createTask(s,'Ngày mai','2026-11-13T17:00:00Z');
  createTask(s,'Không có hạn',null);
  const done=createTask(s,'Đã hoàn thành','2026-11-01T00:00:00Z');done.done=true;
  const v=dailyBriefing(s,420,now);
  assert.equal(v.localDate,'2026-11-13');
  assert.equal(v.summary.overdue,1);
  assert.equal(v.summary.dueToday,1);
  assert.equal(v.summary.upcoming,1);
  assert.equal(v.summary.completedTasks,1);
  assert.equal(v.summary.openTasks,4);
  assert.deepEqual(v.priorities.slice(0,3).map(t=>t.id),[old.id,today.id,tomorrow.id]);
  assert.equal(v.priorities.some(t=>t.id===done.id),false);
});

test('approval counts remain distinct and no actions execute',()=>{
  const s=fresh();const ws=ensureWorkflowStore(s),p=enhanced(s);
  planAction(s,'create_task',{title:'Phải duyệt',dueAt:null});
  createWorkflow(ws,'Quy trình',[{kind:'create_task',payload:{title:'Chưa chạy'}}]);
  getPending(p).push({id:'p1',automationId:'a1',title:'Lịch',createdAt:now.toISOString(),status:'awaiting_approval',result:{kind:'create_task',payload:{title:'Không chạy'}}});
  const before=JSON.stringify(s);
  const view=dailyBriefing(s,420,now);
  assert.equal(view.approvals.total,3);
  assert.equal(view.approvals.actions,1);
  assert.equal(view.approvals.workflows,1);
  assert.equal(view.approvals.automations,1);
  assert.equal(view.summary.pendingApprovals,3);
  assert.equal(s.tasks.length,0);
  assert.equal(JSON.stringify(s),before);
});

test('enabled schedules within 48h appear, without dispatching approvals',()=>{
  const s=fresh(),p=enhanced(s);
  const x=addAutomation(p,{title:'Nhắc ôn bài',intervalMinutes:60,skill:'create_task',payload:{title:'Ôn bài'},enabled:true},now);
  const y=addAutomation(p,{title:'Tắt lịch',intervalMinutes:60,skill:'create_task',payload:{title:'Bỏ qua'},enabled:false},now);
  const v=dailyBriefing(s,420,now);
  assert.equal(v.summary.scheduledSoon,1);
  assert.deepEqual(v.upcomingAutomations.map(a=>a.id),[x.id]);
  assert.equal(v.upcomingAutomations.some(a=>a.id===y.id),false);
  assert.equal(getPending(p).length,0);
});

test('empty state and invalid offsets are handled safely',()=>{
  const s=fresh();const v=dailyBriefing(s,420,now);
  assert.deepEqual(v.priorities,[]);
  assert.equal(v.summary.pendingApprovals,0);
  for(const offset of [-721,841,420.5,NaN,Infinity])
    assert.throws(()=>dailyBriefing(s,offset,now),/timezone offset/);
});

test('large task list is bounded and sorted without mutation',()=>{
  const s=fresh();
  for(let i=0;i<40;i++)createTask(s,'Task '+i,null);
  const before=JSON.stringify(s);
  const v=dailyBriefing(s,0,now);
  assert.equal(v.summary.openTasks,40);
  assert.equal(v.priorities.length,12);
  assert.equal(JSON.stringify(s),before);
});
