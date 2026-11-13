import test from 'node:test';import assert from 'node:assert/strict';
import {fresh,planAction,resolveAction,createTask,createMemory,validateDate} from '../src/core.ts';
test('task input validation and UTC date',()=>{const s=fresh();assert.throws(()=>createTask(s,'',null));assert.throws(()=>validateDate('tomorrow'));assert.equal(createTask(s,'Buy groceries','2026-11-13T10:00:00Z').dueAt,'2026-11-13T10:00:00Z')});
test('action requires approval before execution',()=>{const s=fresh(),p=planAction(s,'create_task',{title:'Meeting',dueAt:null});assert.equal(s.tasks.length,0);resolveAction(s,p.id,true);assert.equal(s.tasks.length,1);assert.throws(()=>resolveAction(s,p.id,true))});
test('rejected action never executes',()=>{const s=fresh(),p=planAction(s,'save_memory',{text:'Prefers short notes'});resolveAction(s,p.id,false);assert.equal(s.memories.length,0)});
test('memory validation',()=>{const s=fresh();assert.throws(()=>createMemory(s,' '));assert.equal(createMemory(s,'Vietnamese').text,'Vietnamese')});
