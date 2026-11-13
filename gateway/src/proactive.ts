/** V4.5 Proactive Assistant.
 * Every recommendation is computed locally from the authenticated tenant.
 * Opening this preview never triggers an automation, external call or notification.
 * Suppression is user-initiated, tenant-scoped and automatically expires.
 */
import type {Store,Task} from './core.ts';
import type {WorkflowStore} from './workflows.ts';
import type {PersonalStore,PendingAutomation} from './personal.ts';

const HOUR=3_600_000;
type Preference={hiddenUntil:string};
type PreferenceStore=Store & {proactivePrefs?:Record<string,Preference>};
export type SuggestedAction='tasks'|'approvals'|'planner';
export interface ProactiveItem {
  id:string;
  title:string;
  detail:string;
  level:'critical'|'important'|'info';
  action:SuggestedAction;
  dueAt:string|null;
}
export interface ProactiveFeed {
  generatedAt:string;localDate:string;items:ProactiveItem[];
  hiddenCount:number;totalCount:number;
  notice:string;
}
function localStart(now:Date,offset:number) {
  if(!Number.isInteger(offset)||offset < -720||offset>840)throw new Error('invalid timezone offset');
  if(!Number.isFinite(now.getTime()))throw new Error('invalid time');
  const shifted=new Date(now.getTime()+offset*60_000);
  return {start:Date.UTC(shifted.getUTCFullYear(),shifted.getUTCMonth(),shifted.getUTCDate())-offset*60_000,
    date:shifted.toISOString().slice(0,10)};
}
function candidates(store:Store,offset:number,now:Date):ProactiveItem[] {
  const {start}=localStart(now,offset);
  const result:ProactiveItem[]=[];
  const tasks=store.tasks.filter(t=>!t.done);
  const pendingActions=store.actions.filter(a=>a.status==='awaiting_approval').length;
  const workflows=(store as Partial<WorkflowStore>).workflows??[];
  const pendingFlows=workflows.filter(w=>w.status==='awaiting_approval').length;
  const personal=store as Partial<PersonalStore> & {pendingAutomations?:PendingAutomation[]};
  const pendingAutomations=(personal.pendingAutomations??[]).filter(a=>a.status==='awaiting_approval').length;
  const pending=pendingActions+pendingFlows+pendingAutomations;
  if(pending)result.push({id:'approvals',title:'Có '+pending+' yêu cầu đang chờ duyệt',
    detail:'Xem lại trước khi phê duyệt; ViePN không tự thực hiện thao tác.',
    level:'important',action:'approvals',dueAt:null});
  for(const task of tasks) {
    const due=task.dueAt?Date.parse(task.dueAt):NaN;
    if(!Number.isFinite(due)||due>=start+3*86_400_000)continue;
    const category=due<start?'Quá hạn':due<start+86_400_000?'Đến hạn hôm nay':'Sắp đến hạn trong 3 ngày';
    const level:ProactiveItem['level']=due<start?'critical':due<start+86_400_000?'important':'info';
    result.push({id:'task-'+task.id,title:task.title,detail:category+' · Cân nhắc xử lý hoặc cập nhật kế hoạch.',
      level,action:'tasks',dueAt:task.dueAt});
  }
  if(tasks.length>=6)result.push({id:'weekly-plan',title:'Sắp xếp lại '+tasks.length+' công việc đang mở',
    detail:'Tạo kế hoạch tuần để phân bổ thời gian; bản nháp không tự thay đổi công việc.',
    level:'info',action:'planner',dueAt:null});
  const levels:{[key in ProactiveItem['level']]:number}={critical:0,important:1,info:2};
  result.sort((a,b)=>levels[a.level]-levels[b.level]||(a.dueAt??'9999').localeCompare(b.dueAt??'9999')||a.id.localeCompare(b.id));
  return result;
}
export function getProactiveFeed(store:Store,offset:number,now=new Date()):ProactiveFeed {
  const local=localStart(now,offset);
  const raw=candidates(store,offset,now);
  const prefs=(store as PreferenceStore).proactivePrefs??{};
  const active=raw.filter(item=> {
    const until=Date.parse(prefs[item.id]?.hiddenUntil??'');
    return !Number.isFinite(until)||until<=now.getTime();
  });
  return {
    generatedAt:now.toISOString(),localDate:local.date,items:active.slice(0,15),
    totalCount:raw.length,hiddenCount:raw.length-active.length,
    notice:'Gợi ý chỉ xuất hiện khi bạn mở hoặc làm mới màn hình. Không có AI, theo dõi nền, nhắc đẩy hoặc thực thi tự động.'
  };
}
export function hideProactiveItem(store:Store,id:unknown,hours:unknown,offset:number,now=new Date()):ProactiveFeed {
  localStart(now,offset);
  if(typeof id!=='string'||id.length>100)throw new Error('invalid suggestion id');
  if(hours!==4&&hours!==24&&hours!==168)throw new Error('invalid snooze duration');
  if(!candidates(store,offset,now).some(item=>item.id===id))throw new Error('suggestion is no longer available');
  const s=store as PreferenceStore;
  const old=s.proactivePrefs??{};
  const next:Record<string,Preference>={};
  // Compact expired entries and bound persistence to avoid unlimited user-supplied IDs.
  for(const [key,pref] of Object.entries(old).slice(-199)) {
    const expiration=Date.parse(pref.hiddenUntil);
    if(Number.isFinite(expiration)&&expiration>now.getTime())next[key]={hiddenUntil:pref.hiddenUntil};
  }
  next[id]={hiddenUntil:new Date(now.getTime()+Number(hours)*HOUR).toISOString()};
  s.proactivePrefs=next;
  return getProactiveFeed(store,offset,now);
}
export function resetProactiveItems(store:Store,offset:number,now=new Date()):ProactiveFeed {
  localStart(now,offset);
  (store as PreferenceStore).proactivePrefs={};
  return getProactiveFeed(store,offset,now);
}
