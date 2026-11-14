import {randomUUID} from 'node:crypto';
export type ActionStatus='draft'|'awaiting_approval'|'completed'|'rejected';
export type TaskPriority='low'|'normal'|'high'|'urgent';
export type TaskRecurrence='none'|'daily'|'weekly'|'monthly';
export interface Subtask {id:string;title:string;done:boolean}
export interface Task {id:string;title:string;dueAt:string|null;done:boolean;createdAt:string;priority?:TaskPriority;labels?:string[];subtasks?:Subtask[];recurrence?:TaskRecurrence;recurrenceDay?:number;seriesId?:string}
export interface Memory {id:string;text:string;createdAt:string}
export interface Action {id:string;kind:'create_task'|'save_memory';payload:Record<string,unknown>;status:ActionStatus;createdAt:string}
export interface Store {tasks:Task[];memories:Memory[];actions:Action[]}
export const fresh=():Store=>({tasks:[],memories:[],actions:[]});
/** Rank explicit task priority within each deadline category (older tasks default to normal). */
export function taskPriorityRank(task:Pick<Task,'priority'>):number {
  return task.priority==='urgent'?0:task.priority==='high'?1:task.priority==='low'?3:2;
}

const now=()=>new Date().toISOString();
export function validateDate(value:unknown):string|null {
  if(value===null || value===undefined || value==='')return null;
  if(typeof value!=='string'||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z$/.test(value)||Number.isNaN(Date.parse(value)))throw new Error('dueAt must be ISO UTC or null');
  return value;
}
const priorityValues=['low','normal','high','urgent'] as const;
const recurrenceValues=['none','daily','weekly','monthly'] as const;
function validateLabels(input:unknown):string[] {
  if(!Array.isArray(input)||input.length>8)throw Error('invalid labels');
  const labels=input.map(x=>{
    if(typeof x!=='string'||!x.trim()||x.length>32)throw Error('invalid label');
    return x.trim();
  });
  if(new Set(labels.map(x=>x.toLocaleLowerCase('vi'))).size!==labels.length)throw Error('duplicate labels');
  return labels;
}
function validateSubtasks(input:unknown,existing:Subtask[]):Subtask[] {
  if(!Array.isArray(input)||input.length>20)throw Error('invalid subtasks');
  const ids=new Set<string>(),known=new Set(existing.map(x=>x.id));
  return input.map(v=>{
    if(!v||typeof v!=='object'||Array.isArray(v))throw Error('invalid subtask');
    const p=v as Record<string,unknown>;
    if(typeof p.title!=='string'||!p.title.trim()||p.title.length>120||typeof p.done!=='boolean')throw Error('invalid subtask');
    const id=p.id===undefined?randomUUID():p.id;
    if(typeof id!=='string'||ids.has(id)||(p.id!==undefined&&!known.has(id)))throw Error('invalid subtask id');
    ids.add(id);return {id,title:p.title.trim(),done:p.done};
  });
}
function details(input:unknown,base?:Task) {
  if(!input||typeof input!=='object'||Array.isArray(input))throw Error('invalid task payload');
  const p=input as Record<string,unknown>;
  if(!Object.keys(p).length)throw Error('empty task update');
  for(const field of Object.keys(p))
    if(!['title','dueAt','priority','labels','subtasks','recurrence','done'].includes(field))
      throw Error('unsupported task field: '+field);
  const title=p.title===undefined?base?.title:p.title;
  if(typeof title!=='string'||!title.trim()||title.length>300)throw Error('invalid task title');
  const dueAt=p.dueAt===undefined?(base?.dueAt??null):validateDate(p.dueAt);
  const priority=p.priority===undefined?(base?.priority??'normal'):p.priority;
  if(!priorityValues.includes(priority as TaskPriority))throw Error('invalid priority');
  const recurrence=p.recurrence===undefined?(base?.recurrence??'none'):p.recurrence;
  if(!recurrenceValues.includes(recurrence as TaskRecurrence))throw Error('invalid recurrence');
  if(recurrence!=='none'&&!dueAt)throw Error('recurring task requires dueAt');
  const done=p.done===undefined?(base?.done??false):p.done;
  if(typeof done!=='boolean')throw Error('done must be boolean');
  const labels=p.labels===undefined?(base?.labels??[]):validateLabels(p.labels);
  const subtasks=p.subtasks===undefined?(base?.subtasks??[]):validateSubtasks(p.subtasks,base?.subtasks??[]);
  if(done&&subtasks.some(x=>!x.done))throw Error('finish all subtasks first');
  const recurrenceDay=recurrence==='monthly'?
    (base?.recurrence==='monthly'&&p.dueAt===undefined&&base.recurrenceDay?
      base.recurrenceDay:new Date(dueAt!).getUTCDate()):undefined;
  return {title:title.trim(),dueAt,priority:priority as TaskPriority,
    recurrence:recurrence as TaskRecurrence,labels:[...labels],subtasks:[...subtasks],done,recurrenceDay};
}
export function createTask(store:Store,title:unknown,dueAt:unknown,extra:unknown={}):Task {
  if(!extra||typeof extra!=='object'||Array.isArray(extra))throw Error('invalid task details');
  const normalized=details({title,dueAt,...extra as Record<string,unknown>});
  if(normalized.done)throw Error('new task cannot start completed');
  const task:Task={id:randomUUID(),createdAt:now(),...normalized};
  store.tasks.push(task);return task;
}
function nextOccurrence(task:Task,at:Date):string {
  const first=new Date(task.dueAt!);
  if(task.recurrence==='daily'||task.recurrence==='weekly'){
    const interval=(task.recurrence==='daily'?1:7)*86400000;
    const step=Math.max(1,Math.floor((at.getTime()-first.getTime())/interval)+1);
    return new Date(first.getTime()+step*interval).toISOString();
  }
  let year=first.getUTCFullYear(),month=first.getUTCMonth();
  const targetDay=task.recurrenceDay??first.getUTCDate();
  for(let i=0;i<2400;i++){
    month++;if(month===12){year++;month=0}
    const lastDay=new Date(Date.UTC(year,month+1,0)).getUTCDate();
    const next=new Date(Date.UTC(year,month,Math.min(targetDay,lastDay),
      first.getUTCHours(),first.getUTCMinutes(),first.getUTCSeconds(),first.getUTCMilliseconds()));
    if(next>at)return next.toISOString();
  }
  throw Error('recurrence is outside supported range');
}
export function updateTask(store:Store,id:string,patch:unknown,at:Date=new Date()):Task {
  const task=store.tasks.find(t=>t.id===id);
  if(!task)throw Error('task not found');
  const normalized=details(patch,task);
  if(!Number.isFinite(at.getTime()))throw Error('invalid update time');
  const generate=!task.done&&normalized.done&&normalized.recurrence!=='none';
  if(generate){
    const next:Task={...task,...normalized,id:randomUUID(),createdAt:now(),done:false,
      dueAt:nextOccurrence({...task,...normalized},at),
      subtasks:normalized.subtasks.map(x=>({id:randomUUID(),title:x.title,done:false})),
      seriesId:task.seriesId??task.id};
    store.tasks.push(next);
  }
  Object.assign(task,normalized);
  return task;
}
export function deleteTask(store:Store,id:string):boolean {
  const index=store.tasks.findIndex(x=>x.id===id);
  if(index<0)return false;
  store.tasks.splice(index,1);return true;
}
export function createMemory(store:Store,value:unknown):Memory {
  if(typeof value!=='string'||!value.trim()||value.length>2000)throw new Error('invalid memory');
  const item={id:randomUUID(),text:value.trim(),createdAt:now()};store.memories.push(item);return item;
}
export function planAction(store:Store,kind:unknown,payload:unknown):Action {
  if(kind!=='create_task'&&kind!=='save_memory')throw new Error('unsupported action');
  if(!payload||typeof payload!=='object'||Array.isArray(payload))throw new Error('invalid payload');
  const p=payload as Record<string,unknown>;
  if(kind==='create_task') {if(typeof p.title!=='string'||!p.title.trim()||p.title.length>300)throw new Error('invalid title');validateDate(p.dueAt)}
  else if(typeof p.text!=='string'||!p.text.trim()||p.text.length>2000)throw new Error('invalid text');
  const action:Action={id:randomUUID(),kind,payload:p,status:'awaiting_approval',createdAt:now()};store.actions.push(action);return action;
}
export function resolveAction(store:Store,id:string,approved:boolean):Action {
  const action=store.actions.find(x=>x.id===id);
  if(!action)throw new Error('action not found');
  if(action.status!=='awaiting_approval')throw new Error('action already resolved');
  if(approved){if(action.kind==='create_task')createTask(store,action.payload.title,action.payload.dueAt);else createMemory(store,action.payload.text)}
  action.status=approved?'completed':'rejected';return action;
}

export function setTaskDone(store:Store,id:string,done:unknown):Task {
  return updateTask(store,id,{done});
}
