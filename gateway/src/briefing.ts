/** Read-only, deterministic daily overview of a single tenant.
 * No model calls, no external providers, no task execution and no persistence.
 * Offsets are minutes east of UTC; callers pass the device's current offset.
 */
import type {Store,Task} from './core.ts';
import {ensureWorkflowStore} from './workflows.ts';
import {enhanced,getPending} from './personal.ts';

export type PriorityKind='overdue'|'today'|'upcoming'|'undated';
export type BriefingTask=Pick<Task,'id'|'title'|'dueAt'|'done'> & {kind:PriorityKind};
export interface DailyBriefing {
  generatedAt:string;
  localDate:string;
  timezoneOffsetMinutes:number;
  summary:{openTasks:number;completedTasks:number;overdue:number;dueToday:number;upcoming:number;pendingApprovals:number;scheduledSoon:number};
  approvals:{actions:number;workflows:number;automations:number;total:number};
  priorities:BriefingTask[];
  upcomingAutomations:{id:string;title:string;nextRunAt:string}[];
}

export function dailyBriefing(store:Store, offsetMinutes:number=0, now:Date=new Date()):DailyBriefing {
  if(!Number.isInteger(offsetMinutes)||offsetMinutes < -720||offsetMinutes > 840)
    throw new Error('timezone offset must be an integer from -720 to 840');
  if(!Number.isFinite(now.getTime()))throw new Error('invalid current time');
  const offsetMs=offsetMinutes*60_000;
  const local=new Date(now.getTime()+offsetMs);
  const start=Date.UTC(local.getUTCFullYear(),local.getUTCMonth(),local.getUTCDate())-offsetMs;
  const end=start+86_400_000;
  const tomorrow=end+86_400_000;
  const ws=ensureWorkflowStore(store),personal=enhanced(store);
  const waitingActions=store.actions.filter(item=>item.status==='awaiting_approval').length;
  const waitingWorkflows=ws.workflows.filter(item=>item.status==='awaiting_approval').length;
  const waitingAutomations=getPending(personal).filter(item=>item.status==='awaiting_approval').length;
  const due=(task:Task):number|null=>{
    if(!task.dueAt)return null;
    const at=Date.parse(task.dueAt);
    return Number.isFinite(at)?at:null;
  };
  const categorized=store.tasks.filter(item=>!item.done).map(task=>{
    const at=due(task);
    const kind:PriorityKind=at===null?'undated':at<start?'overdue':at<end?'today':at<tomorrow?'upcoming':'undated';
    return {...task,kind,sortAt:at??Number.MAX_SAFE_INTEGER};
  });
  const weight:Record<PriorityKind,number>={overdue:0,today:1,upcoming:2,undated:3};
  categorized.sort((a,b)=>weight[a.kind]-weight[b.kind]||a.sortAt-b.sortAt||a.createdAt.localeCompare(b.createdAt)||a.id.localeCompare(b.id));
  const soon=personal.automations
    .filter(item=>item.enabled&&Number.isFinite(Date.parse(item.nextRunAt))&&Date.parse(item.nextRunAt)>=now.getTime()&&Date.parse(item.nextRunAt)<now.getTime()+48*3_600_000)
    .sort((a,b)=>a.nextRunAt.localeCompare(b.nextRunAt)||a.id.localeCompare(b.id))
    .slice(0,5).map(({id,title,nextRunAt})=>({id,title,nextRunAt}));
  return {
    generatedAt:now.toISOString(),
    localDate:local.toISOString().slice(0,10),
    timezoneOffsetMinutes:offsetMinutes,
    summary:{
      openTasks:categorized.length,
      completedTasks:store.tasks.filter(item=>item.done).length,
      overdue:categorized.filter(item=>item.kind==='overdue').length,
      dueToday:categorized.filter(item=>item.kind==='today').length,
      upcoming:categorized.filter(item=>item.kind==='upcoming').length,
      pendingApprovals:waitingActions+waitingWorkflows+waitingAutomations,
      scheduledSoon:soon.length,
    },
    approvals:{actions:waitingActions,workflows:waitingWorkflows,automations:waitingAutomations,total:waitingActions+waitingWorkflows+waitingAutomations},
    priorities:categorized.slice(0,12).map(({id,title,dueAt,done,kind})=>({id,title,dueAt,done,kind})),
    upcomingAutomations:soon,
  };
}
