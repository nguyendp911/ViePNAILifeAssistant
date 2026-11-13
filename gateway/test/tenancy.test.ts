import {test} from 'node:test';
import assert from 'node:assert/strict';
import {parseAccountConfig,resolveAccount,safeUserId} from '../src/tenancy.ts';
const a='A'.repeat(48),b='B'.repeat(48);
test('independent accounts and distinct bearer tokens',()=>{
 const accounts=parseAccountConfig(JSON.stringify([{id:'alice',displayName:'Alice',token:a},{id:'bob',displayName:'Bob',token:b}]));
 assert.equal(resolveAccount(accounts,'Bearer '+a)?.id,'alice');
 assert.equal(resolveAccount(accounts,'Bearer '+b)?.id,'bob');
 assert.equal(resolveAccount(accounts,'Bearer '+a+'x'),null);
 assert.equal(resolveAccount(accounts,undefined),null);
});
test('reject traversal IDs and duplicate credentials',()=>{
 assert.throws(()=>safeUserId('../private'));
 assert.throws(()=>parseAccountConfig(JSON.stringify([{id:'a',displayName:'A',token:a},{id:'b',displayName:'B',token:a}])));
});
test('legacy mode preserved for existing installs',()=>{
 assert.equal(parseAccountConfig(undefined,'X'.repeat(30))[0].id,'legacy');
});
