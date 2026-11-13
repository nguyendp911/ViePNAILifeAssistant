import {randomUUID} from 'node:crypto';
import {createMemory, createTask, validateDate, type Store} from './core.ts';

export type StepKind = 'create_task' | 'save_memory' | 'create_note';
export type WorkflowStatus = 'awaiting_approval' | 'in_progress' | 'completed' | 'rejected' | 'failed';
export type StepStatus = 'pending' | 'awaiting_approval' | 'completed' | 'rejected' | 'failed';
export interface WorkflowStep {
  id: string;
  kind: StepKind;
  payload: Record<string, unknown>;
  status: StepStatus;
  executedAt?: string;
  resultId?: string;
  error?: string;
  retryCount?: number;
}
export interface Workflow {
  id:string;
  title:string;
  createdAt:string;
  status:WorkflowStatus;
  currentStep:number;
  steps:WorkflowStep[];
  history:{at:string;event:string;stepId?:string}[];
}
export interface Note {id:string;title:string;content:string;createdAt:string}
export interface WorkflowStore extends Store { workflows:Workflow[];notes:Note[] }
const stamp=()=>new Date().toISOString();
export function ensureWorkflowStore(store:Store):WorkflowStore {
  const s=store as WorkflowStore;
  s.workflows??=[]; s.notes??=[];
  return s;
}
const str=(value:unknown,max:number,label:string):string=>{
  if(typeof value!=='string'||!value.trim()||value.length>max)throw new Error('invalid '+label);
  return value.trim();
};
function normalize(kind:unknown, payload:unknown):WorkflowStep {
  if(!payload||typeof payload!=='object'||Array.isArray(payload))throw new Error('invalid step payload');
  const input=payload as Record<string,unknown>;
  if(kind==='create_task')return {id:randomUUID(),kind,status:'pending',payload:{title:str(input.title,300,'task title'),dueAt:validateDate(input.dueAt)}};
  if(kind==='save_memory')return {id:randomUUID(),kind,status:'pending',payload:{text:str(input.text,2000,'memory text')}};
  if(kind==='create_note')return {id:randomUUID(),kind,status:'pending',payload:{title:str(input.title,200,'note title'),content:str(input.content,12000,'note content')}};
  throw new Error('unsupported step kind');
}
export function createWorkflow(store:WorkflowStore,title:unknown,steps:unknown):Workflow {
  const name=str(title,200,'workflow title');
  if(!Array.isArray(steps)||steps.length<1||steps.length>10)throw new Error('workflow requires 1-10 steps');
  // Validate all steps before modifying storage.
  const normalized=steps.map(step=>normalize(step?.kind,step?.payload));
  normalized[0].status='awaiting_approval';
  const workflow:Workflow={id:randomUUID(),title:name,createdAt:stamp(),status:'awaiting_approval',currentStep:0,steps:normalized,history:[{at:stamp(),event:'created'}]};
  store.workflows.push(workflow);
  return workflow;
}
export function decideWorkflowStep(store:WorkflowStore,workflowId:string,stepId:string,approve:boolean):Workflow {
  const workflow=store.workflows.find(x=>x.id===workflowId);
  if(!workflow)throw new Error('workflow not found');
  const current=workflow.steps[workflow.currentStep];
  if(!current||current.id!==stepId||current.status!=='awaiting_approval')throw new Error('step is not awaiting approval');
  if(!approve){current.status='rejected';workflow.status='rejected';workflow.history.push({at:stamp(),event:'rejected',stepId});return workflow;}
  // Every step is approved individually. No arbitrary code or external API execution.
  let resultId:string;
  try {
    if(current.kind==='create_task') resultId=createTask(store,current.payload.title,current.payload.dueAt).id;
    else if(current.kind==='save_memory') resultId=createMemory(store,current.payload.text).id;
    else {
      const note:Note={id:randomUUID(),title:current.payload.title as string,content:current.payload.content as string,createdAt:stamp()};
      store.notes.push(note);resultId=note.id;
    }
  } catch (cause) {
    current.error=cause instanceof Error ? cause.message : 'unknown execution error';
    current.status='failed';workflow.status='failed';
    workflow.history.push({at:stamp(),event:'failed',stepId});
    return workflow;
  }
  current.resultId=resultId;current.executedAt=stamp();current.status='completed';
  workflow.history.push({at:stamp(),event:'approved_and_executed',stepId});
  workflow.currentStep++;
  if(workflow.currentStep===workflow.steps.length)workflow.status='completed';
  else {workflow.steps[workflow.currentStep].status='awaiting_approval';workflow.status='awaiting_approval';}
  return workflow;
}

/** A failed local step may be re-opened for manual approval, never auto-executed.
 * Externally-effectful steps must not be introduced without an idempotency key. */
export function retryFailedStep(store:WorkflowStore,workflowId:string,stepId:string):Workflow {
  const workflow=store.workflows.find(x=>x.id===workflowId);
  if(!workflow)throw new Error('workflow not found');
  const current=workflow.steps[workflow.currentStep];
  if(workflow.status!=='failed'||!current||current.id!==stepId||current.status!=='failed'||current.resultId)
    throw new Error('step is not retryable');
  if((current.retryCount??0)>=3)throw new Error('retry limit exceeded');
  current.retryCount=(current.retryCount??0)+1;
  current.status='awaiting_approval';workflow.status='awaiting_approval';
  delete current.error;
  workflow.history.push({at:stamp(),event:'reopened_for_manual_approval',stepId});
  return workflow;
}
