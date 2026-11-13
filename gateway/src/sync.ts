import {createHash} from 'node:crypto';
import type {Store} from './core.ts';
import {ensureWorkflowStore} from './workflows.ts';
import {enhanced} from './personal.ts';
import {knowledge} from './knowledge.ts';

export interface SyncState {revision:number;updatedAt:string}
export function syncState(store:Store):SyncState {
  const s=store as Store & {syncMetadata?:SyncState};
  s.syncMetadata??={revision:0,updatedAt:new Date(0).toISOString()};
  return s.syncMetadata;
}
export function bumpRevision(store:Store):SyncState {
  const meta=syncState(store);
  meta.revision+=1;meta.updatedAt=new Date().toISOString();return meta;
}
export function syncSnapshot(store:Store) {
  const meta=syncState(store),ws=ensureWorkflowStore(store),p=enhanced(store),k=knowledge(store);
  return {schemaVersion:1,revision:meta.revision,updatedAt:meta.updatedAt,tasks:store.tasks,memories:store.memories,
    actions:store.actions,workflows:ws.workflows,notes:ws.notes,profiles:p.profiles,automations:p.automations,
    documents:k.documents};
}
export function snapshotETag(store:Store):string {
  const data=JSON.stringify(syncSnapshot(store));
  return '"'+createHash('sha256').update(data).digest('hex')+'"';
}
export function checkRevision(store:Store, expected:unknown):void {
  if(!Number.isSafeInteger(expected)||expected!==syncState(store).revision)
    throw new Error('sync revision conflict');
}
