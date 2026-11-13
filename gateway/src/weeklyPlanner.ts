/** V4.3 deterministic read-only weekly plan (Monday through Sunday).
 * No AI calls, external calendars or data changes. All task slots are suggestions.
 */
import type {Store,Task} from './core.ts';
import {focusInsights} from './focusHabits.ts';

const DAY=86400000, MIN=60000;
export interface WeekOptions {
  offsetMinutes:number;weekOffset:0|1;startTime:string;endTime:string;
  workdays:number[];focusMinutes:number;breakMinutes:number;maxTasksPerDay:number;useHabits:boolean;
}
export interface WeekSlot {taskId:string;title:string;startAt:string;endAt:string;priority:string;reason:string;dueAt:string|null;deadlineAtRisk:boolean}
export interface WeekDay {date:string;weekday:number;slots:WeekSlot[]}
export interface WeekPreview {weekStart:string;weekEnd:string;generatedAt:string;timezoneOffsetMinutes:number;settings:{focusMinutes:number;breakMinutes:number;maxTasksPerDay:number;useHabits:boolean};habitSuggestedHour:number|null;days:WeekDay[];scheduledCount:number;unscheduledCount:number;atRiskCount:number;notice:string}
function int(label:string,v:unknown,min:number,max:number):number {
  if(!Number.isInteger(v)||Number(v)<min||Number(v)>max)throw new Error('invalid '+label);
  return Number(v);
}
function minuteOfDay(label:string,value:unknown):number {
  if(typeof value!=='string'||!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(value))throw new Error('invalid '+label);
  const [h,m]=value.split(':').map(Number);return h*60+m;
}
export function parseWeekOptions(input:unknown):WeekOptions {
  if(!input||typeof input!=='object'||Array.isArray(input))throw new Error('invalid weekly plan request');
  const o=input as Record<string,unknown>;
  const startTime=o.startTime??'09:00',endTime=o.endTime??'17:00';
  const s=minuteOfDay('startTime',startTime),e=minuteOfDay('endTime',endTime);
  if(e<=s||e-s>720)throw new Error('invalid work window (max 12h)');
  const weekOffset=int('weekOffset',o.weekOffset??0,0,1) as 0|1;
  const offsetMinutes=int('offsetMinutes',o.offsetMinutes??0,-720,840);
  if(o.useHabits!==undefined&&typeof o.useHabits!=='boolean')throw new Error('invalid useHabits');
  const days=o.workdays??[1,2,3,4,5];
  if(!Array.isArray(days)||days.length===0||days.length>7||days.some(d=>!Number.isInteger(d)||d<1||d>7)||new Set(days).size!==days.length)
    throw new Error('invalid workdays');
  return {weekOffset,offsetMinutes,startTime:startTime as string,endTime:endTime as string,workdays:[...days].sort() as number[],
    focusMinutes:int('focusMinutes',o.focusMinutes??25,15,90),
    breakMinutes:int('breakMinutes',o.breakMinutes??5,0,30),
    maxTasksPerDay:int('maxTasksPerDay',o.maxTasksPerDay??5,1,8),
    useHabits:o.useHabits===true};
}
function rank(task:Task,start:number,end:number) {
  const due=task.dueAt ? Date.parse(task.dueAt):NaN;
  const at=Number.isFinite(due)?due:Number.POSITIVE_INFINITY;
  if(at<start)return {n:0,reason:'Đã quá hạn',priority:'overdue',due:at};
  if(at<end)return {n:1,reason:'Hạn trong tuần',priority:'this_week',due:at};
  if(Number.isFinite(at))return {n:2,reason:'Chuẩn bị trước thời hạn',priority:'later',due:at};
  return {n:3,reason:'Chưa đặt hạn',priority:'no_due',due:at};
}
export function previewWeek(store:Store,options:WeekOptions,now=new Date()):WeekPreview {
  if(!Number.isFinite(now.getTime()))throw new Error('invalid current time');
  const shifted=new Date(now.getTime()+options.offsetMinutes*MIN);
  const today=Date.UTC(shifted.getUTCFullYear(),shifted.getUTCMonth(),shifted.getUTCDate())-options.offsetMinutes*MIN;
  const weekday=(shifted.getUTCDay()+6)%7; // Monday = 0
  const monday=today-weekday*DAY+options.weekOffset*7*DAY;
  const end=monday+7*DAY;
  const date=(day:number)=>new Date(day+options.offsetMinutes*MIN).toISOString().slice(0,10);
  const habits=options.useHabits?focusInsights(store):null;
  const preferred=habits?.enabled ? habits.preferredHour : null;
  const baseline=minuteOfDay('startTime',options.startTime),last=minuteOfDay('endTime',options.endTime);
  const startMinute=preferred!==null&&preferred*60>=baseline&&preferred*60+options.focusMinutes<=last?preferred*60:baseline;
  const length=options.focusMinutes*MIN;
  const days:WeekDay[]=Array.from({length:7},(_,i)=>{
    const d=monday+i*DAY;return {date:date(d),weekday:i+1,slots:[]};
  });
  const positions=days.map((_,i)=>{
    const dayStart=monday+i*DAY;
    const at=dayStart+startMinute*MIN;
    return options.workdays.includes(i+1) ? Math.max(at,Math.ceil(now.getTime()/MIN)*MIN):Number.POSITIVE_INFINITY;
  });
  const candidates=store.tasks.filter(t=>!t.done).map(t=>({task:t,score:rank(t,monday,end)}))
    .sort((a,b)=>a.score.n-b.score.n||a.score.due-b.score.due||a.task.createdAt.localeCompare(b.task.createdAt)||a.task.id.localeCompare(b.task.id));
  let scheduledCount=0,atRiskCount=0;
  for(const {task,score} of candidates) {
    const valid=days.map((d,i)=>({d,i,at:positions[i]})).filter(x=>{
      const workdayEnd=monday+x.i*DAY+last*MIN;
      return x.d.slots.length<options.maxTasksPerDay && x.at+length<=workdayEnd && x.at<end;
    });
    if(valid.length===0)break;
    // Prefer slots before a deadline; balance unscheduled work among eligible days.
    const before=Number.isFinite(score.due)?valid.filter(x=>x.at+length<=score.due):valid;
    const pool=before.length?before:valid;
    pool.sort((a,b)=>a.d.slots.length-b.d.slots.length||a.at-b.at||a.i-b.i);
    const chosen=pool[0],risk=Number.isFinite(score.due)&&chosen.at+length>score.due;
    chosen.d.slots.push({taskId:task.id,title:task.title,startAt:new Date(chosen.at).toISOString(),
      endAt:new Date(chosen.at+length).toISOString(),priority:score.priority,reason:score.reason,
      dueAt:task.dueAt,deadlineAtRisk:risk});
    positions[chosen.i]=chosen.at+(options.focusMinutes+options.breakMinutes)*MIN;
    scheduledCount++;if(risk)atRiskCount++;
  }
  return {weekStart:date(monday),weekEnd:date(monday+6*DAY),generatedAt:now.toISOString(),
    timezoneOffsetMinutes:options.offsetMinutes,
    settings:{focusMinutes:options.focusMinutes,breakMinutes:options.breakMinutes,maxTasksPerDay:options.maxTasksPerDay,useHabits:options.useHabits},
    habitSuggestedHour:preferred,days,scheduledCount,unscheduledCount:candidates.length-scheduledCount,atRiskCount,
    notice:'Chỉ là kế hoạch dự kiến. Không thay đổi hạn việc, không tạo lịch, không tự thực thi. Lịch Google chưa được kết hợp trong kế hoạch tuần.'};
}
