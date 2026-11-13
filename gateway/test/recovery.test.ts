import test from 'node:test';
import assert from 'node:assert/strict';
import {fresh} from '../src/core.ts';
import {createWorkflow,decideWorkflowStep,retryFailedStep,ensureWorkflowStore} from '../src/workflows.ts';
test('faulted local workflow requires manual re-approval before retry',()=>{
  const store=ensureWorkflowStore(fresh());
  const flow=createWorkflow(store,'Safety test',[{kind:'create_task',payload:{title:'original'}}]);
  flow.steps[0].payload.title=''; // tampering with persisted state provokes a recoverable local validation error
  const failure=decideWorkflowStep(store,flow.id,flow.steps[0].id,true);
  assert.equal(failure.status,'failed');assert.equal(store.tasks.length,0);
  assert.throws(()=>decideWorkflowStep(store,flow.id,flow.steps[0].id,true));
  flow.steps[0].payload.title='restored';
  retryFailedStep(store,flow.id,flow.steps[0].id);
  assert.equal(flow.status,'awaiting_approval');assert.equal(store.tasks.length,0);
  decideWorkflowStep(store,flow.id,flow.steps[0].id,true);
  assert.equal(flow.status,'completed');assert.equal(store.tasks.length,1);
  assert.throws(()=>retryFailedStep(store,flow.id,flow.steps[0].id));
});
