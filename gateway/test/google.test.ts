import {test} from 'node:test';
import {strict as assert} from 'node:assert';
import {fresh} from '../src/core.ts';
import {seal,unseal,saveConnection,connectionStatus,disconnect,startOAuth,consumeOAuthState} from '../src/google.ts';
const original={id:process.env.GOOGLE_CLIENT_ID,secret:process.env.GOOGLE_CLIENT_SECRET,redirect:process.env.GOOGLE_REDIRECT_URI,key:process.env.GOOGLE_TOKEN_ENCRYPTION_KEY};
process.env.GOOGLE_CLIENT_ID='client-for-testing';
process.env.GOOGLE_CLIENT_SECRET='test-secret';
process.env.GOOGLE_REDIRECT_URI='https://example.test/v1/integrations/google/callback';
process.env.GOOGLE_TOKEN_ENCRYPTION_KEY='11'.repeat(32);
test('encrypted token roundtrips, does not expose access token',()=>{
  const token={access_token:'token-secret',refresh_token:'refresh-secret',expires_at:123};
  const ciphertext=seal(token);
  assert.equal(ciphertext.includes('token-secret'),false);
  assert.deepEqual(unseal(ciphertext),token);
});
test('encryption detects tampered ciphertext',()=>{
  const input=seal({access_token:'abc',expires_at:123});
  const bytes=Buffer.from(input,'base64url');bytes[bytes.length-1]^=1;
  assert.throws(()=>unseal(bytes.toString('base64url')));
});
test('Google status isolated by Store, disconnect removes token',()=>{
  const a=fresh(),b=fresh();
  saveConnection(a,'gmail',{access_token:'abc',expires_at:100});
  assert.deepEqual(connectionStatus(a),{gmail:true,calendar:false});
  assert.deepEqual(connectionStatus(b),{gmail:false,calendar:false});
  disconnect(a,'gmail');assert.equal(connectionStatus(a).gmail,false);
});
test('OAuth state one-time use and service scope',()=>{
  const url=new URL(startOAuth('user-a','calendar'));
  assert.equal(url.hostname,'accounts.google.com');
  assert.ok(url.searchParams.get('scope')?.includes('calendar.events.readonly'));
  const state=url.searchParams.get('state')!;
  assert.deepEqual(consumeOAuthState(state).accountId,'user-a');
  assert.throws(()=>consumeOAuthState(state));
});
test('OAuth start rejects non-HTTPS redirect',()=>{
  process.env.GOOGLE_REDIRECT_URI='http://example.test/callback';
  assert.throws(()=>startOAuth('abc','gmail'));
  process.env.GOOGLE_REDIRECT_URI='https://example.test/v1/integrations/google/callback';
});
