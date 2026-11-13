import test from 'node:test';
import assert from 'node:assert/strict';
import {fresh} from '../src/core.ts';
import {ensureWorkflowStore,createWorkflow,decideWorkflowStep} from '../src/workflows.ts';
test('multi-step workflow requires approval for each step',()=>{
  const s=ensureWorkflowStore(fresh());const w=createWorkflow(s,'Weekly prep',[
    {kind:'create_note',payload:{title:'Summary',content:'Agenda'}},
    {kind:'create_task',payload:{title:'Check summary',dueAt:null}},
    {kind:'save_memory',payload:{text:'User opted into keeping this preference'}}
  ]);
  assert.equal(s.notes.length,0); assert.equal(w.steps[1].status,'pending');
  decideWorkflowStep(s,w.id,w.steps[0].id,true);
  assert.equal(s.notes.length,1); assert.equal(s.tasks.length,0);
  decideWorkflowStep(s,w.id,w.steps[1].id,true);
  assert.equal(s.tasks.length,1); assert.equal(s.memories.length,0);
  decideWorkflowStep(s,w.id,w.steps[2].id,true);
  assert.equal(s.memories.length,1); assert.equal(w.status,'completed');
  assert.throws(()=>decideWorkflowStep(s,w.id,w.steps[2].id,true));
});
test('reject prevents further work',()=>{
  const s=ensureWorkflowStore(fresh());const w=createWorkflow(s,'test',[{kind:'create_task',payload:{title:'A'}},{kind:'create_task',payload:{title:'B'}}]);
  decideWorkflowStep(s,w.id,w.steps[0].id,false);
  assert.equal(w.status,'rejected');assert.equal(s.tasks.length,0);
  assert.throws(()=>decideWorkflowStep(s,w.id,w.steps[1].id,true));
});
test('invalid workflow leaves data unchanged',()=>{
  const s=ensureWorkflowStore(fresh());
  assert.throws(()=>createWorkflow(s,'test',[{kind:'create_task',payload:{title:'A'}},{kind:'run_shell',payload:{command:'rm -rf /'}}]));
  assert.equal(s.workflows.length,0);
});
test('legacy store gains safe empty collections',()=>{
  const s=ensureWorkflowStore(fresh());assert.deepEqual(s.notes,[]);assert.deepEqual(s.workflows,[]);
});

