import test from 'node:test';
import assert from 'node:assert/strict';
import {fresh,createTask} from '../src/core.ts';
import {syncSnapshot,bumpRevision,checkRevision,snapshotETag} from '../src/sync.ts';
test('snapshot revision and hash detect updates',()=>{
  const store=fresh();const before=snapshotETag(store);
  checkRevision(store,0);createTask(store,'Việc A',null);bumpRevision(store);
  assert.equal(syncSnapshot(store).revision,1);
  assert.notEqual(snapshotETag(store),before);
  assert.throws(()=>checkRevision(store,0),/conflict/);
});
