import {randomUUID} from 'node:crypto';
export type ActionStatus='draft'|'awaiting_approval'|'completed'|'rejected';
export interface Task {id:string;title:string;dueAt:string|null;done:boolean;createdAt:string}
export interface Memory {id:string;text:string;createdAt:string}
export interface Action {id:string;kind:'create_task'|'save_memory';payload:Record<string,unknown>;status:ActionStatus;createdAt:string}
export interface Store {tasks:Task[];memories:Memory[];actions:Action[]}
export const fresh=():Store=>({tasks:[],memories:[],actions:[]});
const now=()=>new Date().toISOString();
export function validateDate(value:unknown):string|null {
  if(value===null || value===undefined || value==='')return null;
  if(typeof value!=='string'||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z$/.test(value)||Number.isNaN(Date.parse(value)))throw new Error('dueAt must be ISO UTC or null');
  return value;
}
export function createTask(store:Store,title:unknown,dueAt:unknown):Task {
  if(typeof title!=='string'||title.trim().length<1||title.length>300)throw new Error('invalid task title');
  const task:Task={id:randomUUID(),title:title.trim(),dueAt:validateDate(dueAt),done:false,createdAt:now()};
  store.tasks.push(task);return task;
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
  if(typeof done!=='boolean')throw new Error('done must be boolean');
  const task=store.tasks.find(x=>x.id===id);
  if(!task)throw new Error('task not found');
  task.done=done;
  return task;
}
