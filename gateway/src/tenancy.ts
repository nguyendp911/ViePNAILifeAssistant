import {timingSafeEqual} from 'node:crypto';

export type Account={id:string;displayName:string;token:string};
export function safeUserId(value:string):string {
  if(!/^[a-zA-Z0-9_-]{1,60}$/.test(value)||value==='.'||value==='..')throw Error('invalid account ID');
  return value;
}
export function parseAccountConfig(raw?:string,legacyToken?:string):Account[] {
  if(raw?.trim()) {
    let parsed:unknown;
    try {parsed=JSON.parse(raw)}catch{throw Error('invalid VIEPN_ACCOUNTS_JSON')}
    if(!Array.isArray(parsed)||parsed.length===0||parsed.length>1000)throw Error('invalid accounts config');
    const ids=new Set<string>(),tokens=new Set<string>();
    return parsed.map((item:unknown)=>{
      if(!item||typeof item!=='object')throw Error('invalid account');
      const x=item as Record<string,unknown>;
      const id=safeUserId(String(x.id??''));
      if(typeof x.token!=='string'||x.token.length<32||!/^[-_a-zA-Z0-9.]+$/.test(x.token))throw Error('invalid account token');
      if(ids.has(id)||tokens.has(x.token))throw Error('duplicate account credentials');
      ids.add(id);tokens.add(x.token);
      if(typeof x.displayName!=='string'||!x.displayName.trim()||x.displayName.length>100)throw Error('invalid display name');
      return {id,token:x.token,displayName:x.displayName.trim()};
    });
  }
  if(!legacyToken||legacyToken.length<24)throw Error('Set VIEPN_ACCOUNTS_JSON or VIEPN_GATEWAY_TOKEN');
  return [{id:'legacy',token:legacyToken,displayName:'ViePN Personal'}];
}
function equal(a:string,b:string):boolean{
  const left=Buffer.from(a),right=Buffer.from(b);
  return left.length===right.length&&timingSafeEqual(left,right);
}
export function resolveAccount(accounts:Account[],authorization:string|string[]|undefined):Account|null {
  if(typeof authorization!=='string'||!authorization.startsWith('Bearer '))return null;
  const token=authorization.slice(7);
  // Avoid early return: compare each valid token for consistent behavior.
  let matched:Account|null=null;
  for(const a of accounts)if(equal(token,a.token))matched=a;
  return matched;
}
