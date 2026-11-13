import pg from 'pg';
import {randomBytes, randomUUID} from 'node:crypto';
import {sha,normalizeUsername,validPassword,hashPassword,verifyPassword} from './authCrypto.ts';
import type {Store} from './core.ts';
import {fresh} from './core.ts';
const {Pool}=pg;
export const databaseURL=process.env.DATABASE_URL||'';
export const postgresEnabled=Boolean(databaseURL);
const pool=postgresEnabled?new Pool({connectionString:databaseURL,max:10,ssl:process.env.PGSSL==='require'?{rejectUnauthorized:true}:undefined}):null;
export type AuthAccount={id:string;displayName:string};
export async function initPostgres():Promise<void> {
  if(!pool)return;
  await pool.query(`CREATE TABLE IF NOT EXISTS viepn_users (
    id uuid PRIMARY KEY, username text UNIQUE NOT NULL, display_name text NOT NULL,
    password_hash text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
    failed_attempts integer NOT NULL DEFAULT 0, locked_until timestamptz);
    CREATE TABLE IF NOT EXISTS viepn_sessions (
    token_hash text PRIMARY KEY, user_id uuid NOT NULL REFERENCES viepn_users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL,
    revoked_at timestamptz);
    CREATE INDEX IF NOT EXISTS idx_viepn_sessions_user ON viepn_sessions(user_id);
    CREATE TABLE IF NOT EXISTS viepn_state (
    user_id uuid PRIMARY KEY REFERENCES viepn_users(id) ON DELETE CASCADE,
    document jsonb NOT NULL DEFAULT '{}'::jsonb, updated_at timestamptz NOT NULL DEFAULT now());`);
}
async function createSession(userId:string):Promise<{token:string;expiresAt:string}> {
  if(!pool)throw Error('PostgreSQL not configured');
  const token=randomBytes(32).toString('base64url');
  const expiresAt=new Date(Date.now()+7*24*3600_000).toISOString();
  await pool.query('INSERT INTO viepn_sessions(token_hash,user_id,expires_at) VALUES ($1,$2,$3)',[sha(token),userId,expiresAt]);
  return {token,expiresAt};
}
export async function registerUser(username:unknown,password:unknown,displayName:unknown) {
  if(!pool)throw Error('PostgreSQL not configured');
  const name=normalizeUsername(username);
  if(!validPassword(password)||typeof displayName!=='string'||!displayName.trim()||displayName.length>100)throw Error('invalid registration');
  const hash=await hashPassword(password);
  const userId=randomUUID();
  try {
    await pool.query('INSERT INTO viepn_users(id,username,display_name,password_hash) VALUES ($1,$2,$3,$4)',[userId,name,displayName.trim(),hash]);
  }catch(error:any){if(error.code==='23505')throw Error('username unavailable');throw error}
  return {account:{id:userId,displayName:displayName.trim()},...await createSession(userId)};
}
export async function loginUser(username:unknown,password:unknown) {
  if(!pool)throw Error('PostgreSQL not configured');
  const name=normalizeUsername(username);
  if(!validPassword(password))throw Error('invalid credentials');
  const result=await pool.query('SELECT id,display_name,password_hash,locked_until FROM viepn_users WHERE username=$1',[name]);
  const user=result.rows[0];
  if(!user)throw Error('invalid credentials');
  if(user.locked_until&&new Date(user.locked_until).getTime()>Date.now())throw Error('temporarily locked');
  const ok=await verifyPassword(password,user.password_hash);
  if(!ok){await pool.query(`UPDATE viepn_users SET failed_attempts=failed_attempts+1,
    locked_until=CASE WHEN failed_attempts+1>=5 THEN now()+interval '15 minutes' ELSE NULL END WHERE id=$1`,[user.id]);throw Error('invalid credentials')}
  await pool.query('UPDATE viepn_users SET failed_attempts=0,locked_until=NULL WHERE id=$1',[user.id]);
  return {account:{id:user.id,displayName:user.display_name},...await createSession(user.id)};
}
export async function resolveSession(header:string|string[]|undefined):Promise<AuthAccount|null> {
  if(!pool||typeof header!=='string'||!/^Bearer [A-Za-z0-9_-]{43}$/.test(header))return null;
  const result=await pool.query(`SELECT u.id,u.display_name FROM viepn_sessions s JOIN viepn_users u ON u.id=s.user_id
    WHERE s.token_hash=$1 AND s.revoked_at IS NULL AND s.expires_at>now() LIMIT 1`,[sha(header.slice(7))]);
  return result.rows.length?{id:result.rows[0].id,displayName:result.rows[0].display_name}:null;
}
export async function revokeSession(header:string|string[]|undefined):Promise<void>{
  if(!pool||typeof header!=='string'||!header.startsWith('Bearer '))return;
  await pool.query('UPDATE viepn_sessions SET revoked_at=now() WHERE token_hash=$1',[sha(header.slice(7))]);
}
export async function readUserState(userId:string):Promise<Store> {
  if(!pool)throw Error('PostgreSQL not configured');
  const result=await pool.query('SELECT document FROM viepn_state WHERE user_id=$1',[userId]);
  return result.rows.length?Object.assign(fresh(),result.rows[0].document):fresh();
}
export async function writeUserState(userId:string,store:Store):Promise<void> {
  if(!pool)throw Error('PostgreSQL not configured');
  await pool.query(`INSERT INTO viepn_state(user_id,document,updated_at) VALUES($1,$2::jsonb,now())
  ON CONFLICT(user_id) DO UPDATE SET document=EXCLUDED.document,updated_at=now()`,[userId,JSON.stringify(store)]);
}
export async function closePostgres(){await pool?.end()}
