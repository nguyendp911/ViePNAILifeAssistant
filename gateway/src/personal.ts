import {randomUUID} from 'node:crypto';
import type {Store} from './core.ts';
import {createMemory,createTask} from './core.ts';

export type Profile = {id:string; name:string; style:string; createdAt:string};
export type Automation = {id:string; title:string; intervalMinutes:number; nextRunAt:string; enabled:boolean; skill:'create_note'|'create_task'; payload:Record<string,string>; lastRunAt?:string; lastResult?:string};
export type RunLog = {id:string; at:string; automationId:string; outcome:string; resultId?:string};
export interface PersonalStore extends Store {profiles:Profile[];automations:Automation[];automationRuns:RunLog[];}
export const enhanced = (s:Store): PersonalStore => {const v=s as PersonalStore;v.profiles??=[];v.automations??=[];v.automationRuns??=[];return v;};
const bounded=(s:unknown,max:number)=> {if(typeof s!=='string'||!s.trim()||s.length>max)throw Error('invalid text');return s.trim()};
export function addProfile(s:PersonalStore,name:unknown,style:unknown):Profile {const item={id:randomUUID(),name:bounded(name,100),style:bounded(style,500),createdAt:new Date().toISOString()};s.profiles.push(item);return item}
export const normalizeVietnamese=(value:string)=>value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/đ/g,'d').replace(/Đ/g,'D').toLocaleLowerCase('vi');
export function searchMemory(s:PersonalStore,term:string,limit=20){
  if(term.length>100)throw Error('query too long');
  const tokens=normalizeVietnamese(term).trim().split(/\s+/).filter(Boolean);
  if(tokens.length===0)return s.memories.slice(-Math.min(50,Math.max(1,limit))).reverse();
  return s.memories.map(m=>{
    const haystack=normalizeVietnamese(m.text);
    const matches=tokens.filter(t=>haystack.includes(t)).length;
    const exact=haystack.includes(tokens.join(' ')) ? 3 : 0;
    return {memory:m,score:matches+exact};
  }).filter(x=>x.score>0).sort((a,b)=>b.score-a.score||b.memory.createdAt.localeCompare(a.memory.createdAt))
    .slice(0,Math.min(50,Math.max(1,limit))).map(x=>x.memory);
}
export function suggestReply(s:PersonalStore,message:string,profileId?:string){const input=bounded(message,4000);const profile=s.profiles.find(p=>p.id===profileId);return {instruction:`Hãy soạn bản nháp trả lời bằng tiếng Việt. Phong cách: ${profile?.style??'lịch sự, rõ ràng'}. Không tự gửi tin nhắn.`,input};}
export const SKILLS=[{id:'create_task',title:'Tạo công việc',requiresApproval:true},{id:'create_note',title:'Tạo ghi chú',requiresApproval:true},{id:'save_memory',title:'Lưu bộ nhớ',requiresApproval:true},{id:'draft_reply',title:'Soạn tin nhắn',requiresApproval:false}] as const;
export function addAutomation(s:PersonalStore,request:{title:unknown;intervalMinutes:unknown;skill:unknown;payload:unknown;enabled?:unknown},now=new Date()):Automation{
  const title=bounded(request.title,200);const interval=request.intervalMinutes;
  if(!Number.isInteger(interval)|| (interval as number)<60||(interval as number)>43200)throw Error('interval must be 60–43200 minutes');
  if(request.skill!=='create_note'&&request.skill!=='create_task')throw Error('unsupported automation skill');
  if(!request.payload||typeof request.payload!=='object'||Array.isArray(request.payload))throw Error('invalid payload');
  const p=request.payload as Record<string,unknown>;
  const payload:Record<string,string>=request.skill==='create_note'?{title:bounded(p.title,200),content:bounded(p.content,12000)}:{title:bounded(p.title,300)};
  if(request.enabled!==undefined && typeof request.enabled!=='boolean')throw Error('invalid enabled');
  const item:Automation={id:randomUUID(),title,intervalMinutes:interval as number,skill:request.skill,payload,enabled:request.enabled===true,nextRunAt:new Date(now.getTime()+(interval as number)*60000).toISOString()};
  s.automations.push(item);return item;
}
export function dueAutomations(s:PersonalStore,now=new Date()){
  return s.automations.filter(x=>x.enabled && Date.parse(x.nextRunAt)<=now.getTime());
}
export function markAutomationRun(s:PersonalStore,id:string,outcome:string,resultId:string|undefined,now=new Date()){
  const item=s.automations.find(a=>a.id===id);if(!item)throw Error('automation not found');
  item.nextRunAt=new Date(now.getTime()+item.intervalMinutes*60000).toISOString();item.lastRunAt=now.toISOString();item.lastResult=outcome;
  const record:RunLog={id:randomUUID(),at:now.toISOString(),automationId:id,outcome,resultId};s.automationRuns.push(record);return record;
}
// Deliberately do not execute actions in the scheduler: each due job becomes a pending approval request.
export function prepareDueAutomations(s:PersonalStore,now=new Date()){
  const prepared=[];
  for(const task of dueAutomations(s,now)){
    const queued=s.automationRuns.some(log=>log.automationId===task.id && log.at===task.lastRunAt && log.outcome==='awaiting_approval');
    if(queued)continue;
    const result=task.skill==='create_task'?{kind:'create_task',payload:{title:task.payload.title,dueAt:null}}:{kind:'create_note',payload:task.payload};
    const approval={id:randomUUID(),automationId:task.id,title:task.title,result,createdAt:now.toISOString(),status:'awaiting_approval'};
    prepared.push(approval);
    markAutomationRun(s,task.id,'awaiting_approval',approval.id,now);
  }
  return prepared;
}
export function safeMemorySave(s:PersonalStore,text:string,consent:boolean){if(!consent)throw Error('explicit consent required');return createMemory(s,text)}
export interface PendingAutomation {id:string;automationId:string;title:string;result:{kind:string;payload:Record<string,unknown>};createdAt:string;status:'awaiting_approval'|'approved'|'rejected';resultId?:string}
export function getPending(s:PersonalStore):PendingAutomation[] {const v=s as PersonalStore&{pendingAutomations?:PendingAutomation[]};v.pendingAutomations??=[];return v.pendingAutomations;}
export function queueDue(s:PersonalStore,now=new Date()):PendingAutomation[] {
  const queue=getPending(s);const jobs=prepareDueAutomations(s,now) as PendingAutomation[];
  queue.push(...jobs);return jobs;
}
export function resolvePending(s:PersonalStore,id:string,approve:boolean):PendingAutomation {
  const job=getPending(s).find(x=>x.id===id);if(!job)throw Error('approval not found');
  if(job.status!=='awaiting_approval')throw Error('approval already resolved');
  if(approve) {
    if(job.result.kind==='create_task')job.resultId=createTask(s,job.result.payload.title,null).id;
    else if(job.result.kind==='create_note'){
      const notes=(s as PersonalStore&{notes?:{id:string;title:string;content:string;createdAt:string}[]}).notes??=[];
      const note={id:randomUUID(),title:String(job.result.payload.title),content:String(job.result.payload.content),createdAt:new Date().toISOString()};notes.push(note);job.resultId=note.id;
    } else throw Error('unsupported pending skill');
  }
  job.status=approve?'approved':'rejected';return job;
}
