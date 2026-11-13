import test from 'node:test';
import assert from 'node:assert/strict';
import {previewPlan,previewFromModel} from '../src/planner.ts';
import {fresh,createTask,setTaskDone} from '../src/core.ts';
import {enhanced,searchMemory} from '../src/personal.ts';

test('plan preview never runs any operation',()=>{
 const plan=previewPlan({title:'Báo cáo',note:'Nội dung',task:'Gửi báo cáo'});
 assert.equal(plan.executed,false);assert.equal(plan.requiresApproval,true);assert.deepEqual(plan.steps.map(x=>x.kind),['create_note','create_task']);
});
test('plan rejects unsupported commands, empty steps and memory without consent',()=>{
 assert.throws(()=>previewPlan({title:'X',command:'send_email'}));
 assert.throws(()=>previewPlan({title:'X',memory:'Địa chỉ'}),/consent/);
 assert.equal(previewPlan({title:'X',memory:'Thói quen',memoryConsent:true}).steps[0].kind,'save_memory');
});
test('completion rejects nonboolean and missing tasks',()=>{
 const store=fresh();const task=createTask(store,'Đọc tài liệu',null);
 assert.throws(()=>setTaskDone(store,task.id,'true'));
 assert.equal(setTaskDone(store,task.id,true).done,true);
 assert.throws(()=>setTaskDone(store,'missing',true));
});
test('accent insensitive Vietnamese memory ranking',()=>{
 const store=enhanced(fresh());store.memories=[
 {id:'1',text:'Lịch họp tuần',createdAt:'2026-01-01T00:00:00Z'},
 {id:'2',text:'Gặp khách hàng tại Hà Nội',createdAt:'2026-01-02T00:00:00Z'},
 {id:'3',text:'Khách hàng ở Đà Nẵng',createdAt:'2026-01-03T00:00:00Z'}];
 assert.deepEqual(searchMemory(store,'khach hang').map(x=>x.id),['3','2']);
 assert.deepEqual(searchMemory(store,'da nang').map(x=>x.id),['3']);
});

test('untrusted AI JSON is always an unexecuted preview',()=>{
 const result=previewFromModel('```json\n{"title":"Kế hoạch tuần","task":"Chuẩn bị tài liệu","note":null,"dueAt":null}\n```');
 assert.equal(result.executed,false);assert.deepEqual(result.steps.map(x=>x.kind),['create_task']);
 assert.throws(()=>previewFromModel('{"title":"X","task":"Y","memory":"bí mật"}'),/unsupported/);
 assert.throws(()=>previewFromModel('{"title":"X","steps":[{"kind":"send_email"}]}'),/unsupported/);
 assert.throws(()=>previewFromModel('not json'),/JSON/);
});
