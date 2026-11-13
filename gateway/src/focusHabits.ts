/** Explicitly opt-in, manually self-reported focus sessions.
 * No device tracking, message contents, task names or automatic telemetry.
 * Only daily totals and hourly aggregate counts are stored per authenticated tenant.
 */
import type {Store} from './core.ts';

export interface FocusDay {date:string;minutes:number;sessions:number;hours:Record<string,number>}
export interface FocusHistory {enabled:boolean;days:FocusDay[]}
type FocusStore = Store & {focusHistory?:FocusHistory};
const DAY=86400000;
export function focusHistory(store:Store):FocusHistory {
  const data=(store as FocusStore).focusHistory;
  return data ? {enabled:data.enabled,days:data.days.map(d=>({...d,hours:{...d.hours}}))} : {enabled:false,days:[]};
}
export function setFocusConsent(store:Store,enabled:unknown):FocusHistory {
  if(typeof enabled!=='boolean')throw new Error('enabled must be a boolean');
  const s=store as FocusStore;
  if(!enabled) s.focusHistory={enabled:false,days:[]}; // disabling also erases past data
  else if(!s.focusHistory||!s.focusHistory.enabled) s.focusHistory={enabled:true,days:[]};
  return focusHistory(store);
}
export function recordFocus(store:Store,input:unknown,now=new Date()):FocusHistory {
  const s=store as FocusStore;
  if(s.focusHistory?.enabled!==true)throw new Error('focus history requires explicit consent');
  if(!input||typeof input!=='object'||Array.isArray(input))throw new Error('invalid focus session');
  const p=input as Record<string,unknown>;
  const minutes=p.minutes,offset=p.offsetMinutes,hour=p.hour;
  if(!Number.isInteger(minutes)||Number(minutes)<15||Number(minutes)>180)throw new Error('focus minutes must be 15–180');
  if(!Number.isInteger(offset)||Number(offset)<-720||Number(offset)>840)throw new Error('invalid timezone offset');
  if(!Number.isInteger(hour)||Number(hour)<0||Number(hour)>23)throw new Error('invalid local hour');
  if(!Number.isFinite(now.getTime()))throw new Error('invalid timestamp');
  const local=new Date(now.getTime()+Number(offset)*60000);
  const date=local.toISOString().slice(0,10);
  const entries=s.focusHistory.days;
  let day=entries.find(d=>d.date===date);
  if(!day){day={date,minutes:0,sessions:0,hours:{}};entries.push(day)}
  if(day.sessions>=20||day.minutes+Number(minutes)>1440)throw new Error('daily focus record limit reached');
  day.minutes+=Number(minutes);day.sessions+=1;
  const key=String(hour);day.hours[key]=(day.hours[key]||0)+1;
  const cutoff=new Date(Date.UTC(local.getUTCFullYear(),local.getUTCMonth(),local.getUTCDate())-89*DAY).toISOString().slice(0,10);
  s.focusHistory.days=entries.filter(d=>d.date>=cutoff).sort((a,b)=>a.date.localeCompare(b.date)).slice(-90);
  return focusHistory(store);
}
export function focusInsights(store:Store) {
  const history=focusHistory(store);
  if(!history.enabled)return {enabled:false,sessions:0,totalMinutes:0,days:0,preferredHour:null as number|null};
  const counts=Array.from({length:24},()=>0);
  let sessions=0,totalMinutes=0;
  for(const d of history.days){
    sessions+=d.sessions;totalMinutes+=d.minutes;
    for(const [key,count] of Object.entries(d.hours)){
      const hour=Number(key);if(Number.isInteger(hour)&&hour>=0&&hour<24)counts[hour]+=count;
    }
  }
  let preferredHour:number|null=null;
  if(sessions>=3){
    const best=Math.max(...counts);
    if(best>0)preferredHour=counts.indexOf(best);
  }
  return {enabled:true,sessions,totalMinutes,days:history.days.length,preferredHour};
}
