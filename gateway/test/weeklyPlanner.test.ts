import test from 'node:test';
import assert from 'node:assert/strict';
import {createTask,fresh} from '../src/core.ts';
import {setFocusConsent,recordFocus,focusHistory,focusInsights} from '../src/focusHabits.ts';
import {parseWeekOptions,previewWeek} from '../src/weeklyPlanner.ts';

const now=new Date('2026-11-13T09:00:00.000Z'); // Friday 16:00 Vietnam
const opts=(x:Record<string,unknown>={})=>parseWeekOptions({offsetMinutes:420,weekOffset:1,startTime:'08:00',endTime:'12:00',focusMinutes:25,breakMinutes:5,maxTasksPerDay:2,workdays:[1,2,3,4,5],...x});

test('focus tracking requires explicit opt-in; disable securely wipes aggregate history',()=>{
 const store=fresh();const old=JSON.stringify(store);
 assert.throws(()=>recordFocus(store,{minutes:25,offsetMinutes:420,hour:16},now),/consent/);
 assert.equal(JSON.stringify(store),old);
 setFocusConsent(store,true);
 const first=recordFocus(store,{minutes:25,offsetMinutes:420,hour:16},now);
 assert.equal(first.days[0].date,'2026-11-13');assert.equal(first.days[0].minutes,25);
 recordFocus(store,{minutes:45,offsetMinutes:420,hour:9},now);
 recordFocus(store,{minutes:25,offsetMinutes:420,hour:16},now);
 assert.equal(focusInsights(store).preferredHour,16);
 const detached=focusHistory(store);detached.days[0].hours['16']=999;
 assert.equal(focusHistory(store).days[0].hours['16'],2);
 setFocusConsent(store,false);
 assert.deepEqual(focusHistory(store),{enabled:false,days:[]});
 assert.deepEqual(focusInsights(store),{enabled:false,sessions:0,totalMinutes:0,days:0,preferredHour:null});
});

test('invalid/abusive manual focus records are rejected',()=>{
 const store=fresh();setFocusConsent(store,true);
 for(const record of [{minutes:0,offsetMinutes:420,hour:8},{minutes:181,offsetMinutes:420,hour:8},{minutes:25,offsetMinutes:999,hour:8},{minutes:25,offsetMinutes:420,hour:24},{minutes:'25',offsetMinutes:420,hour:8}])
   assert.throws(()=>recordFocus(store,record,now));
 assert.equal(focusHistory(store).days.length,0);
 for(let i=0;i<20;i++)recordFocus(store,{minutes:15,offsetMinutes:420,hour:8},now);
 assert.throws(()=>recordFocus(store,{minutes:15,offsetMinutes:420,hour:8},now),/limit/);
});

test('weekly planner uses Monday in Vietnam and produces read-only load-balanced preview',()=>{
 const s=fresh();
 const overdue=createTask(s,'Quá hạn','2026-11-01T00:00:00Z');
 const thisWeek=createTask(s,'Hạn gần','2026-11-17T09:00:00Z');
 createTask(s,'Không hạn',null);
 const orig=JSON.stringify(s);
 const plan=previewWeek(s,opts(),now);
 assert.equal(plan.weekStart,'2026-11-16');
 assert.equal(plan.weekEnd,'2026-11-22');
 assert.equal(plan.days.length,7);
 assert.equal(plan.scheduledCount,3);
 assert.equal(plan.unscheduledCount,0);
 assert.equal(plan.days[0].slots[0].taskId,overdue.id);
 assert.ok(plan.days.some(d=>d.slots.some(x=>x.taskId===thisWeek.id)));
 assert.equal(JSON.stringify(s),orig);
 assert.equal(plan.days[5].slots.length,0);
});

test('no scheduling in the past in current week; deadline risks surfaced',()=>{
 const s=fresh();createTask(s,'Việc đã trễ','2026-11-12T09:00:00Z');
 const p=previewWeek(s,opts({weekOffset:0,workdays:[1,2,3,4,5],startTime:'09:00',endTime:'17:00'}),now);
 assert.equal(p.weekStart,'2026-11-09');
 assert.equal(p.scheduledCount,1);
 assert.equal(p.atRiskCount,1);
 assert.equal(p.days[0].slots.length,0);
 const slot=p.days.flatMap(d=>d.slots)[0];
 assert.ok(Date.parse(slot.startAt)>=now.getTime());
 assert.equal(slot.deadlineAtRisk,true);
});

test('opt-in habits nudge future focus hour but do not affect default plan',()=>{
 const s=fresh();setFocusConsent(s,true);
 for(let i=0;i<3;i++)recordFocus(s,{minutes:25,offsetMinutes:420,hour:10},now);
 createTask(s,'Sắp xếp',null);
 const a=previewWeek(s,opts({useHabits:false}),now);
 const b=previewWeek(s,opts({useHabits:true}),now);
 assert.equal(a.habitSuggestedHour,null);
 assert.equal(b.habitSuggestedHour,10);
 assert.equal(new Date(a.days.flatMap(x=>x.slots)[0].startAt).toISOString(),'2026-11-16T01:00:00.000Z');
 assert.equal(new Date(b.days.flatMap(x=>x.slots)[0].startAt).toISOString(),'2026-11-16T03:00:00.000Z');
});

test('bounds, weekday duplication and output quota',()=>{
 const invalid=[null,[],{weekOffset:2},{offsetMinutes:900},{startTime:'25:00'},{startTime:'18:00',endTime:'09:00'},{startTime:'00:00',endTime:'13:00'},
   {workdays:[]},{workdays:[1,1]},{workdays:[0]},{workdays:[1,8]},{focusMinutes:10},{maxTasksPerDay:9},{useHabits:'yes'}];
 for(const v of invalid)assert.throws(()=>parseWeekOptions(v));
 const s=fresh();for(let i=0;i<100;i++)createTask(s,'Việc '+i,null);
 const p=previewWeek(s,opts({maxTasksPerDay:1}),now);
 assert.equal(p.scheduledCount,5);
 assert.equal(p.unscheduledCount,95);
 assert.ok(p.days.every(d=>d.slots.length<=1));
});
