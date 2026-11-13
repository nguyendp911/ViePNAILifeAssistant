import {randomBytes, scrypt as rawScrypt, createHash, timingSafeEqual} from 'node:crypto';
import {promisify} from 'node:util';
const scrypt=promisify(rawScrypt);
export const sha=(value:string)=>createHash('sha256').update(value).digest('hex');
const usernamePattern=/^[a-z0-9_]{3,48}$/;
export function normalizeUsername(value:unknown):string {
  if(typeof value!=='string')throw Error('invalid credentials');
  const v=value.toLowerCase().trim();
  if(!usernamePattern.test(v))throw Error('invalid credentials');
  return v;
}
export function validPassword(password:unknown):password is string {return typeof password==='string'&&Buffer.byteLength(password,'utf8')>=12&&Buffer.byteLength(password,'utf8')<=256}
export async function hashPassword(password:string):Promise<string> {
  if(!validPassword(password))throw Error('invalid credentials');
  const salt=randomBytes(16).toString('hex');
  const derived=await scrypt(password,Buffer.from(salt,'hex'),64) as Buffer;
  return 'scrypt:'+salt+':'+derived.toString('hex');
}
export async function verifyPassword(password:string,stored:string):Promise<boolean> {
  if(!validPassword(password))return false;
  const parts=stored.split(':');
  if(parts.length!==3||parts[0]!=='scrypt'||!/^[0-9a-f]{32}$/.test(parts[1])||!/^[0-9a-f]{128}$/.test(parts[2]))return false;
  const derived=await scrypt(password,Buffer.from(parts[1],'hex'),64) as Buffer;
  return timingSafeEqual(derived,Buffer.from(parts[2],'hex'));
}
