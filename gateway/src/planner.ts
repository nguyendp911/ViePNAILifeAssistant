import {validateDate} from './core.ts';

export type ProposedStep={kind:'create_note'|'create_task'|'save_memory';payload:Record<string,unknown>};
export interface PlanPreview{title:string;steps:ProposedStep[];requiresApproval:true;executed:false;origin:'structured_user_request'|'ai_generated'}
const text=(value:unknown,max:number,label:string):string=>{
  if(typeof value!=='string'||!value.trim()||value.length>max)throw new Error('invalid '+label);
  return value.trim();
};
/** Deterministic, limited planner. No model-generated commands are executed. */
export function previewPlan(input:unknown):PlanPreview {
  if(!input||typeof input!=='object'||Array.isArray(input))throw new Error('invalid plan');
  const p=input as Record<string,unknown>;
  const title=text(p.title,200,'title');
  const steps:ProposedStep[]=[];
  if(p.note!==undefined&&p.note!==null&&p.note!==''){
    steps.push({kind:'create_note',payload:{title,content:text(p.note,12000,'note')}});
  }
  if(p.task!==undefined&&p.task!==null&&p.task!==''){
    steps.push({kind:'create_task',payload:{title:text(p.task,300,'task'),dueAt:validateDate(p.dueAt)}});
  }
  if(p.memory!==undefined&&p.memory!==null&&p.memory!==''){
    if(p.memoryConsent!==true)throw new Error('explicit memory consent required');
    steps.push({kind:'save_memory',payload:{text:text(p.memory,2000,'memory')}});
  }
  if(steps.length<1)throw new Error('at least one step is required');
  return {title,steps,requiresApproval:true,executed:false,origin:'structured_user_request'|'ai_generated'};
}

/** Convert untrusted model output into allowlisted, preview-only operations. */
export function previewFromModel(raw:string):PlanPreview {
  if(raw.length>20000)throw new Error('AI plan too large');
  const clean=raw.trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'');
  let parsed:unknown;
  try {parsed=JSON.parse(clean)}catch{throw new Error('AI did not return valid JSON')}
  if(!parsed||typeof parsed!=='object'||Array.isArray(parsed))throw new Error('invalid AI response');
  const data=parsed as Record<string,unknown>;
  // AI is restricted to note and task drafts; memory saving must be initiated manually.
  if(data.memory!==undefined||data.memoryConsent!==undefined||data.command!==undefined||data.steps!==undefined)
    throw new Error('AI plan contains unsupported operations');
  const preview=previewPlan({title:data.title,note:data.note,task:data.task,dueAt:data.dueAt});
  return {...preview,origin:'structured_user_request'|'ai_generated'};
}
