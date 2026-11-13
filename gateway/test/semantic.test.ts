import assert from 'node:assert/strict';
import test from 'node:test';
import {knowledge,addDocument,deleteDocument} from '../src/knowledge.ts';
import {fresh} from '../src/core.ts';
import {normalizeVector,cosine,rebuildIndex,hybridSearch,semanticState} from '../src/semantic.ts';

test('embedding rejects malformed and zero vectors',()=>{
  assert.throws(()=>normalizeVector([0,0,0,0]),/zero/);
  assert.throws(()=>normalizeVector([1,NaN,0,0]),/invalid/);
});
test('cosine recognizes orthogonal vectors',()=>{
  assert.equal(cosine([1,0,0,0],[0,1,0,0]),0);
});
test('semantic index supports true vector recall without lexical overlap',async()=>{
  const kb=knowledge(fresh());
  addDocument(kb,'Lịch','Cuộc họp hội đồng giáo viên sáng thứ hai');
  addDocument(kb,'Bếp','Hướng dẫn món canh chua');
  const provider={model:'test-embeddings',embed:async(text:string)=>text.includes('họp')||text.includes('meeting')?[1,0,0,0]:[0,1,0,0]};
  const count=await rebuildIndex(kb,provider);
  assert.equal(count.indexed,2);
  const answer=await hybridSearch(kb,'meeting',provider);
  assert.equal(answer[0].title,'Lịch');
  assert.ok(answer[0].semanticScore>0);
  assert.equal((await rebuildIndex(kb,provider)).indexed,0);
  deleteDocument(kb,kb.documents[0].id);
  await rebuildIndex(kb,provider);
  assert.equal(semanticState(kb).entries.length,1);
});
