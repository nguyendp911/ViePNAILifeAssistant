import {createCipheriv,createDecipheriv,createHash,randomBytes,randomUUID} from 'node:crypto';
import type {Store} from './core.ts';

export type GoogleService = 'gmail'|'calendar';
type Pending = {accountId:string;service:GoogleService;expires:number};
type SecretToken = {access_token:string;refresh_token?:string;expires_at:number};
type GoogleStore = Store & {googleConnections?:Partial<Record<GoogleService,string>>};
const pending = new Map<string,Pending>();
const SCOPES:Record<GoogleService,string> = {
  gmail:'https://www.googleapis.com/auth/gmail.readonly',
  calendar:'https://www.googleapis.com/auth/calendar.events.readonly'
};
const clientId=()=>process.env.GOOGLE_CLIENT_ID||'';
const clientSecret=()=>process.env.GOOGLE_CLIENT_SECRET||'';
const redirectURI=()=>process.env.GOOGLE_REDIRECT_URI||'';
function key():Buffer {
  const input=process.env.GOOGLE_TOKEN_ENCRYPTION_KEY||'';
  if(!/^[0-9a-fA-F]{64}$/.test(input))throw new Error('GOOGLE_TOKEN_ENCRYPTION_KEY must be 64 hex characters');
  return Buffer.from(input,'hex');
}
export function configured():boolean {
  return Boolean(clientId()&&clientSecret()&&redirectURI()&&/^[0-9a-fA-F]{64}$/.test(process.env.GOOGLE_TOKEN_ENCRYPTION_KEY||''));
}
export function seal(value:SecretToken):string {
  const iv=randomBytes(12);const cipher=createCipheriv('aes-256-gcm',key(),iv);
  const encrypted=Buffer.concat([cipher.update(JSON.stringify(value),'utf8'),cipher.final()]);
  return Buffer.concat([iv,cipher.getAuthTag(),encrypted]).toString('base64url');
}
export function unseal(encrypted:string):SecretToken {
  const data=Buffer.from(encrypted,'base64url');
  if(data.length<29)throw new Error('invalid encrypted token');
  const decipher=createDecipheriv('aes-256-gcm',key(),data.subarray(0,12));
  decipher.setAuthTag(data.subarray(12,28));
  return JSON.parse(Buffer.concat([decipher.update(data.subarray(28)),decipher.final()]).toString('utf8')) as SecretToken;
}
export function startOAuth(accountId:string,service:GoogleService):string {
  if(!configured())throw new Error('Google OAuth has not been configured');
  const uri=new URL(redirectURI());if(uri.protocol!=='https:')throw new Error('OAuth redirect must use HTTPS');
  const state=randomBytes(32).toString('base64url');
  for(const [id,p] of pending)if(p.expires<Date.now())pending.delete(id);
  pending.set(createHash('sha256').update(state).digest('hex'),{accountId,service,expires:Date.now()+10*60_000});
  const url=new URL('https://accounts.google.com/o/oauth2/v2/auth');
  url.searchParams.set('client_id',clientId());url.searchParams.set('redirect_uri',redirectURI());
  url.searchParams.set('response_type','code');url.searchParams.set('scope',SCOPES[service]);
  url.searchParams.set('state',state);url.searchParams.set('access_type','offline');
  url.searchParams.set('prompt','consent');
  return url.toString();
}
export function consumeOAuthState(state:string):Pending {
  const hash=createHash('sha256').update(state).digest('hex');
  const result=pending.get(hash);pending.delete(hash);
  if(!result||result.expires<Date.now())throw new Error('invalid or expired OAuth state');
  return result;
}
async function tokenRequest(params:URLSearchParams):Promise<any> {
  const response=await fetch('https://oauth2.googleapis.com/token',{
    method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},
    body:params,signal:AbortSignal.timeout(15_000)
  });
  if(!response.ok)throw new Error('Google token exchange failed: '+response.status);
  return response.json();
}
export async function exchangeCode(code:string):Promise<SecretToken> {
  const params=new URLSearchParams({code,client_id:clientId(),client_secret:clientSecret(),redirect_uri:redirectURI(),grant_type:'authorization_code'});
  const result=await tokenRequest(params);
  if(!result.access_token)throw new Error('missing access token');
  return {access_token:result.access_token,refresh_token:result.refresh_token,expires_at:Date.now()+Number(result.expires_in||3600)*1000};
}
export function saveConnection(store:Store,service:GoogleService,token:SecretToken):void {
  const s=store as GoogleStore;s.googleConnections??={};s.googleConnections[service]=seal(token);
}
export function disconnect(store:Store,service:GoogleService):void {
  delete (store as GoogleStore).googleConnections?.[service];
}
export function connectionStatus(store:Store):Record<GoogleService,boolean> {
  const c=(store as GoogleStore).googleConnections||{};
  return {gmail:Boolean(c.gmail),calendar:Boolean(c.calendar)};
}
async function accessToken(store:Store,service:GoogleService,persist:()=>Promise<void>):Promise<string> {
  const s=store as GoogleStore;const sealed=s.googleConnections?.[service];
  if(!sealed)throw new Error('Google account not connected');
  let token=unseal(sealed);
  if(token.expires_at>Date.now()+60_000)return token.access_token;
  if(!token.refresh_token)throw new Error('Google authorization expired; reconnect account');
  const result=await tokenRequest(new URLSearchParams({refresh_token:token.refresh_token,client_id:clientId(),client_secret:clientSecret(),grant_type:'refresh_token'}));
  token={access_token:result.access_token,refresh_token:result.refresh_token||token.refresh_token,expires_at:Date.now()+Number(result.expires_in||3600)*1000};
  saveConnection(store,service,token);await persist();return token.access_token;
}
async function googleGET(store:Store,service:GoogleService,url:string,persist:()=>Promise<void>):Promise<any> {
  const access=await accessToken(store,service,persist);
  const response=await fetch(url,{headers:{authorization:'Bearer '+access},signal:AbortSignal.timeout(15_000)});
  if(!response.ok)throw new Error('Google API error '+response.status);
  return response.json();
}
export async function gmailSummaries(store:Store,persist:()=>Promise<void>) {
  const list=await googleGET(store,'gmail','https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=10',persist);
  const messages=[] as {id:string;subject:string;from:string;date:string;snippet:string}[];
  for(const item of list.messages||[]) {
    const id=encodeURIComponent(item.id);
    const m=await googleGET(store,'gmail',`https://gmail.googleapis.com/gmail/v1/users/me/messages/${id}?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date`,persist);
    const h=(name:string)=>m.payload?.headers?.find((v:any)=>v.name?.toLowerCase()===name.toLowerCase())?.value||'';
    messages.push({id:item.id,subject:h('Subject'),from:h('From'),date:h('Date'),snippet:m.snippet||''});
  }
  return {items:messages};
}
export async function calendarEvents(store:Store,persist:()=>Promise<void>) {
  const url=new URL('https://www.googleapis.com/calendar/v3/calendars/primary/events');
  url.searchParams.set('singleEvents','true');url.searchParams.set('orderBy','startTime');
  url.searchParams.set('maxResults','25');url.searchParams.set('timeMin',new Date().toISOString());
  const result=await googleGET(store,'calendar',url.toString(),persist);
  return {items:(result.items||[]).map((e:any)=>({id:e.id,summary:e.summary||'(Không có tiêu đề)',start:e.start?.dateTime||e.start?.date||'',end:e.end?.dateTime||e.end?.date||''}))};
}
