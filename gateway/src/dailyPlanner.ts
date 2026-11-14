/** V4.2 Smart Daily Planner.
 * Generates a bounded, deterministic plan from the authenticated user's tasks.
 * Preview ONLY: never mutates tasks, creates events, submits a workflow or contacts AI.
 */
import type {Store,Task} from './core.ts';
import {taskPriorityRank} from './core.ts';

export interface PlanningOptions {
  offsetMinutes:number;
  startTime:string;
  endTime:string;
  focusMinutes:number;
  breakMinutes:number;
  maxTasks:number;
  includeCalendar:boolean;
  useAI:boolean;
}
export interface BusyInterval {start:string;end:string}
export interface DailyPlanSlot {
  taskId:string;
  title:string;
  startAt:string;
  endAt:string;
  estimatedMinutes:number;
  priority:'overdue'|'today'|'tomorrow'|'later'|'no_due';
  reason:string;
  dueAt:string|null;
}
export interface DailyPlanPreview {
  generatedAt:string;
  localDate:string;
  timezoneOffsetMinutes:number;
  window:{startAt:string;endAt:string};
  settings:{focusMinutes:number;breakMinutes:number;maxTasks:number};
  calendarUsed:boolean;
  busyTimes:{startAt:string;endAt:string}[];
  slots:DailyPlanSlot[];
  unscheduledCount:number;
  unscheduledTitles:string[];
  notice:string;
}
const MINUTE=60_000;
const DAY=24*60*MINUTE;
const hhmm=(name:string,value:unknown):number=>{
  if(typeof value!=='string'||!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(value))throw new Error('invalid '+name+' (HH:MM)');
  const [hours,minutes]=value.split(':').map(Number);
  return hours*60+minutes;
};
const integer=(name:string,value:unknown,lower:number,upper:number):number=>{
  if(!Number.isInteger(value)||Number(value)<lower||Number(value)>upper)throw new Error('invalid '+name);
  return Number(value);
};
export function parsePlanningOptions(value:unknown):PlanningOptions {
  if(value===null||typeof value!=='object'||Array.isArray(value))throw new Error('invalid daily plan request');
  const v=value as Record<string,unknown>;
  const offsetMinutes=integer('timezone offset',v.offsetMinutes??0,-720,840);
  const startTime=String(v.startTime??'09:00'),endTime=String(v.endTime??'17:00');
  const start=hhmm('startTime',startTime),end=hhmm('endTime',endTime);
  if(end<=start||end-start>12*60)throw new Error('work window must be positive and at most 12 hours');
  if(v.includeCalendar!==undefined&&typeof v.includeCalendar!=='boolean')throw new Error('invalid includeCalendar');
  if(v.useAI!==undefined&&typeof v.useAI!=='boolean')throw new Error('invalid useAI');
  return {
    offsetMinutes,startTime,endTime,
    focusMinutes:integer('focusMinutes',v.focusMinutes??25,15,90),
    breakMinutes:integer('breakMinutes',v.breakMinutes??5,0,30),
    maxTasks:integer('maxTasks',v.maxTasks??8,1,12),
    includeCalendar:v.includeCalendar===true,
    useAI:v.useAI===true,
  };
}
function localDay(now:Date,offsetMinutes:number) {
  const local=new Date(now.getTime()+offsetMinutes*MINUTE);
  const midnight=Date.UTC(local.getUTCFullYear(),local.getUTCMonth(),local.getUTCDate())-offsetMinutes*MINUTE;
  return {start:midnight,date:local.toISOString().slice(0,10)};
}
function timeFromLocal(dayStart:number,hhmmValue:string) {
  return dayStart+hhmm('time',hhmmValue)*MINUTE;
}
/** Google all-day event dates (YYYY-MM-DD) are dates in the requested local day, not UTC instants. */
function busyTimestamp(value:string,offsetMinutes:number):number {
  if(/^\d{4}-\d\d-\d\d$/.test(value)) {
    const [y,m,d]=value.split('-').map(Number);
    const v=Date.UTC(y,m-1,d);
    if(new Date(v).toISOString().slice(0,10)!==value)return NaN;
    return v-offsetMinutes*MINUTE;
  }
  return Date.parse(value);
}
function mergedBusy(entries:BusyInterval[],start:number,end:number,offsetMinutes:number) {
  if(!Array.isArray(entries)||entries.length>200)throw new Error('invalid calendar events');
  const intervals:{start:number;end:number}[]=[];
  for(const entry of entries) {
    if(typeof entry?.start!=='string'||typeof entry?.end!=='string')continue;
    const a=busyTimestamp(entry.start,offsetMinutes),b=busyTimestamp(entry.end,offsetMinutes);
    if(!Number.isFinite(a)||!Number.isFinite(b)||b<=a||a>=end||b<=start)continue;
    intervals.push({start:Math.max(start,a),end:Math.min(end,b)});
  }
  intervals.sort((a,b)=>a.start-b.start||a.end-b.end);
  const result:{start:number;end:number}[]=[];
  for(const item of intervals) {
    const last=result[result.length-1];
    if(last&&item.start<=last.end)last.end=Math.max(last.end,item.end);
    else result.push({...item});
  }
  return result;
}
function importance(task:Task,start:number):{rank:number;kind:DailyPlanSlot['priority'];reason:string;at:number} {
  const parsed=task.dueAt?Date.parse(task.dueAt):NaN;
  const at=Number.isFinite(parsed)?parsed:Number.MAX_SAFE_INTEGER;
  if(at<start)return {rank:0,kind:'overdue',reason:'Công việc đã quá hạn',at};
  if(at<start+DAY)return {rank:1,kind:'today',reason:'Hạn hoàn thành hôm nay',at};
  if(at<start+2*DAY)return {rank:2,kind:'tomorrow',reason:'Cần chuẩn bị cho ngày mai',at};
  if(at<Number.MAX_SAFE_INTEGER)return {rank:3,kind:'later',reason:'Chuẩn bị trước thời hạn',at};
  return {rank:4,kind:'no_due',reason:'Chưa đặt hạn hoàn thành',at};
}
export function previewDailyPlan(
  store:Store,
  options:PlanningOptions,
  calendarBusy:BusyInterval[]=[],
  now:Date=new Date(),
):DailyPlanPreview {
  if(!Number.isFinite(now.getTime()))throw new Error('invalid current time');
  const local=localDay(now,options.offsetMinutes);
  const windowStart=timeFromLocal(local.start,options.startTime);
  const windowEnd=timeFromLocal(local.start,options.endTime);
  const busy=mergedBusy(calendarBusy,windowStart,windowEnd,options.offsetMinutes);
  const sorted=store.tasks.filter(t=>!t.done).map(task=>({task,importance:importance(task,local.start)}))
    .sort((a,b)=>a.importance.rank-b.importance.rank||taskPriorityRank(a.task)-taskPriorityRank(b.task)||a.importance.at-b.importance.at||
      a.task.createdAt.localeCompare(b.task.createdAt)||a.task.id.localeCompare(b.task.id));
  const slots:DailyPlanSlot[]=[];
  const slotLength=options.focusMinutes*MINUTE;
  let cursor=Math.max(windowStart,Math.ceil(now.getTime()/MINUTE)*MINUTE);
  for(const {task,importance:priority} of sorted) {
    if(slots.length>=options.maxTasks)break;
    let candidate=cursor;
    while(candidate+slotLength<=windowEnd) {
      const conflict=busy.find(item=>item.start<candidate+slotLength&&item.end>candidate);
      if(!conflict)break;
      candidate=conflict.end;
    }
    if(candidate+slotLength>windowEnd)break;
    slots.push({
      taskId:task.id,title:task.title,startAt:new Date(candidate).toISOString(),
      endAt:new Date(candidate+slotLength).toISOString(),estimatedMinutes:options.focusMinutes,
      priority:priority.kind,reason:priority.reason,dueAt:task.dueAt,
    });
    cursor=candidate+slotLength+options.breakMinutes*MINUTE;
  }
  const planned=new Set(slots.map(slot=>slot.taskId));
  const remaining=sorted.filter(entry=>!planned.has(entry.task.id));
  return {
    generatedAt:now.toISOString(),localDate:local.date,timezoneOffsetMinutes:options.offsetMinutes,
    window:{startAt:new Date(windowStart).toISOString(),endAt:new Date(windowEnd).toISOString()},
    settings:{focusMinutes:options.focusMinutes,breakMinutes:options.breakMinutes,maxTasks:options.maxTasks},
    calendarUsed:options.includeCalendar,
    busyTimes:busy.map(item=>({startAt:new Date(item.start).toISOString(),endAt:new Date(item.end).toISOString()})),
    slots,unscheduledCount:remaining.length,unscheduledTitles:remaining.slice(0,5).map(entry=>entry.task.title),
    notice:'Các khung giờ chỉ là gợi ý dựa trên ước tính, không đặt lịch, không gửi email và không hoàn thành công việc tự động.',
  };
}
