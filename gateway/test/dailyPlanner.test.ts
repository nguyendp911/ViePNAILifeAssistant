import test from 'node:test';
import assert from 'node:assert/strict';
import {createTask,fresh} from '../src/core.ts';
import {parsePlanningOptions,previewDailyPlan} from '../src/dailyPlanner.ts';

const now=new Date('2026-11-13T01:30:00.000Z'); // 08:30 VN
const opts=(values:Record<string,unknown>={})=>parsePlanningOptions({
  offsetMinutes:420,startTime:'09:00',endTime:'12:00',
  focusMinutes:25,breakMinutes:5,maxTasks:8,...values
});

test('daily plan prioritizes overdue/today and remains strictly read-only',()=>{
  const store=fresh();
  const later=createTask(store,'Tài liệu tháng sau','2026-12-01T09:00:00Z');
  const overdue=createTask(store,'Việc quá hạn','2026-11-12T16:00:00Z');
  const today=createTask(store,'Hạn hôm nay','2026-11-13T16:30:00Z');
  const done=createTask(store,'Đã hoàn thành','2026-11-12T10:00:00Z');done.done=true;
  const saved=JSON.stringify(store);
  const plan=previewDailyPlan(store,opts(),[],now);
  assert.equal(plan.localDate,'2026-11-13');
  assert.equal(plan.slots.length,3);
  assert.deepEqual(plan.slots.map(x=>x.taskId),[overdue.id,today.id,later.id]);
  assert.deepEqual(plan.slots.map(x=>x.priority),['overdue','today','later']);
  assert.equal(plan.slots[0].startAt,'2026-11-13T02:00:00.000Z');
  assert.equal(plan.slots[0].endAt,'2026-11-13T02:25:00.000Z');
  assert.equal(plan.slots[1].startAt,'2026-11-13T02:30:00.000Z');
  assert.equal(plan.calendarUsed,false);
  assert.equal(JSON.stringify(store),saved);
});

test('overlapping Google events merge, avoid collisions and do not include event titles',()=>{
  const store=fresh();
  createTask(store,'Dạy học',null);
  createTask(store,'Chuẩn bị giáo án',null);
  const plan=previewDailyPlan(store,opts({includeCalendar:true}),[
    {start:'2026-11-13T09:00:00+07:00',end:'2026-11-13T09:15:00+07:00'},
    {start:'2026-11-13T09:10:00+07:00',end:'2026-11-13T09:30:00+07:00'},
    {start:'2026-11-13T10:00:00+07:00',end:'2026-11-13T10:45:00+07:00'},
  ],now);
  assert.equal(plan.busyTimes.length,2);
  assert.equal(plan.slots[0].startAt,'2026-11-13T02:30:00.000Z');
  assert.equal(plan.slots[1].startAt,'2026-11-13T03:45:00.000Z');
  assert.equal(JSON.stringify(plan).includes('meeting title'),false);
});

test('all-day Google event blocks selected local workday',()=>{
  const store=fresh();createTask(store,'Đi làm',null);
  const p=previewDailyPlan(store,opts({includeCalendar:true}),[
    {start:'2026-11-13',end:'2026-11-14'}
  ],now);
  assert.equal(p.slots.length,0);
  assert.equal(p.unscheduledCount,1);
  assert.equal(p.busyTimes.length,1);
});

test('after end of work window, preview does not schedule tasks in the past',()=>{
  const store=fresh();createTask(store,'Thử',null);
  const p=previewDailyPlan(store,opts(),[],new Date('2026-11-13T16:59:00Z'));
  assert.equal(p.slots.length,0);
  assert.equal(p.unscheduledCount,1);
});

test('bounds and malformed input are rejected before any changes',()=>{
  for(const request of [
    null,[],{offsetMinutes:841},{offsetMinutes:-721},{offsetMinutes:420.5},
    {startTime:'24:00'},{startTime:'17:00',endTime:'09:00'},
    {startTime:'00:00',endTime:'13:00'},
    {focusMinutes:14},{focusMinutes:91},{breakMinutes:-1},{breakMinutes:31},
    {maxTasks:0},{maxTasks:99},{includeCalendar:'true'},{useAI:1}
  ])assert.throws(()=>parsePlanningOptions(request));
  const store=fresh();const before=JSON.stringify(store);
  assert.throws(()=>previewDailyPlan(store,opts(),Array.from({length:201},()=>({start:'',end:''})),now));
  assert.equal(JSON.stringify(store),before);
});

test('limited focus slots and unscheduled tasks are explicitly disclosed',()=>{
  const store=fresh();for(let i=0;i<20;i++)createTask(store,'Việc '+i,null);
  const plan=previewDailyPlan(store,opts({focusMinutes:60,breakMinutes:15,maxTasks:3}),[],now);
  assert.equal(plan.slots.length,2);
  assert.equal(plan.unscheduledCount,18);
  assert.equal(plan.unscheduledTitles.length,5);
  assert.equal(plan.settings.focusMinutes,60);
});
