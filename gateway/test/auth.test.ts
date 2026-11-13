import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeUsername,validPassword,hashPassword,verifyPassword} from '../src/authCrypto.ts';
test('normalizes username and rejects unsafe names',()=>{
 assert.equal(normalizeUsername(' Test_User '),'test_user');
 assert.throws(()=>normalizeUsername('../other'));
 assert.throws(()=>normalizeUsername('a'));
});
test('enforces meaningful password length',()=>{
 assert.equal(validPassword('short'),false);
 assert.equal(validPassword('twelvechars!'),true);
 assert.equal(validPassword('x'.repeat(257)),false);
});
test('scrypt password hash has random salt and verifies',async()=>{
 const one=await hashPassword('my-secret-password-123');
 const two=await hashPassword('my-secret-password-123');
 assert.notEqual(one,two);
 assert.equal(await verifyPassword('my-secret-password-123',one),true);
 assert.equal(await verifyPassword('incorrectpassword',one),false);
 assert.equal(await verifyPassword('my-secret-password-123','corrupted'),false);
});
