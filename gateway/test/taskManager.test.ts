import test from 'node:test';
import assert from 'node:assert/strict';
import {createTask,deleteTask,fresh,updateTask} from '../src/core.ts';

const now=new Date('2026-11-14T03:00:00Z');
test('priority, labels and subtasks can be created and edited without losing existing IDs',()=>{
 const s=fresh();
 const t=createTask(s,'Soạn bài','2026-11-15T03:00:00Z',{
   priority:'high',labels:['Giảng dạy','7A3'],subtasks:[{title:'Chuẩn bị slide',done:false},{title:'In phiếu',done:false}]
 });
 assert.equal(t.priority,'high');assert.deepEqual(t.labels,['Giảng dạy','7A3']);
 assert.equal(t.subtasks?.length,2);
 assert.equal(t.subtasks?.[0]?.done,false);
 assert.throws(()=>updateTask(s,t.id,{done:true}),/subtasks/);
 const id=t.subtasks![0].id;
 updateTask(s,t.id,{subtasks:[{...t.subtasks![0],done:true},t.subtasks![1]]});
 assert.equal(t.subtasks?.[0].id,id);assert.equal(t.subtasks?.[0].done,true);
 updateTask(s,t.id,{subtasks:t.subtasks!.map(c=>({...c,done:true})),done:true});
 assert.equal(t.done,true);assert.equal(s.tasks.length,1);
 assert.equal(deleteTask(s,t.id),true);assert.equal(deleteTask(s,t.id),false);
});
test('invalid priority/recurrence/labels/subtask updates do not mutate task',()=>{
 const s=fresh(),t=createTask(s,'Công việc',null);
 const before=JSON.stringify(t);
 const inputs=[
   {priority:'highest'},{recurrence:'daily'},{labels:['a','A']},
   {labels:Array.from({length:9},(_,i)=>String(i))},
   {subtasks:[{id:'injected',title:'X',done:false}]},
   {subtasks:[{title:'X',done:'false'}]},
   {dueAt:'2026-99-99T00:00:00Z'},{createdAt:'abc'},{title:''},{done:1}
 ];
 for(const patch of inputs)assert.throws(()=>updateTask(s,t.id,patch));
 assert.equal(JSON.stringify(t),before);
 assert.equal(s.tasks.length,1);
 assert.throws(()=>updateTask(s,'absent',{done:true}),/not found/);
});
test('daily and weekly recurrence advances to next future due, once per completion',()=>{
 const s=fresh();
 const daily=createTask(s,'Daily','2026-11-10T08:00:00Z',{recurrence:'daily',priority:'urgent',labels:['Personal']});
 updateTask(s,daily.id,{done:true},now);
 assert.equal(s.tasks.length,2);
 const next=s.tasks[1];
 assert.equal(next.dueAt,'2026-11-14T08:00:00.000Z');
 assert.equal(next.done,false);
 assert.equal(next.seriesId,daily.id);
 assert.equal(next.priority,'urgent');
 assert.deepEqual(next.labels,['Personal']);
 updateTask(s,daily.id,{done:true},now);
 assert.equal(s.tasks.length,2);
 const weekly=createTask(s,'Weekly','2026-11-08T08:00:00Z',{recurrence:'weekly'});
 updateTask(s,weekly.id,{done:true},now);
 assert.equal(s.tasks[3].dueAt,'2026-11-15T08:00:00.000Z');
});
test('monthly recurrence keeps the original day across shorter months, reset subtasks',()=>{
 const s=fresh();
 const task=createTask(s,'Month end','2027-01-31T10:00:00Z',{recurrence:'monthly',
   subtasks:[{title:'A',done:false}]});
 updateTask(s,task.id,{subtasks:task.subtasks!.map(x=>({...x,done:true})),done:true},new Date('2027-01-31T11:00:00Z'));
 const feb=s.tasks[1];
 assert.equal(feb.dueAt,'2027-02-28T10:00:00.000Z');
 assert.equal(feb.subtasks?.[0]?.done,false);
 assert.notEqual(feb.subtasks?.[0]?.id,task.subtasks?.[0]?.id);
 updateTask(s,feb.id,{subtasks:feb.subtasks!.map(x=>({...x,done:true})),done:true},new Date('2027-02-28T11:00:00Z'));
 assert.equal(s.tasks[2].dueAt,'2027-03-31T10:00:00.000Z');
 assert.equal(s.tasks[2].seriesId,task.id);
});
test('edits preserve backward-compatible legacy tasks and deletion is isolated',()=>{
 const s=fresh();
 const t=createTask(s,'Legacy',null);delete t.priority;delete t.labels;delete t.subtasks;delete t.recurrence;
 updateTask(s,t.id,{priority:'low',labels:['Việc nhà'],dueAt:'2026-11-18T10:00:00Z'});
 assert.equal(t.recurrence,'none');
 assert.equal(t.labels?.[0],'Việc nhà');
});
