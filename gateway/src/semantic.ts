import {createHash} from 'node:crypto';
import type {KnowledgeState, Evidence} from './knowledge.ts';
import {retrieve} from './knowledge.ts';

export interface VectorEntry {chunkId:string; digest:string; vector:number[]; model:string}
export interface VectorState {entries:VectorEntry[]}
export interface SemanticResult extends Evidence {lexicalScore:number; semanticScore:number}
export interface EmbeddingProvider {embed(text:string):Promise<number[]>; model:string}

export function semanticState(state:KnowledgeState):VectorState {
  const current=state as KnowledgeState & {vectors?:VectorState};
  current.vectors ??= {entries:[]};
  return current.vectors;
}
export function normalizeVector(vector:unknown):number[] {
  if(!Array.isArray(vector)||vector.length<4||vector.length>4096||vector.some(v=>typeof v!=='number'||!Number.isFinite(v)))
    throw new Error('invalid embedding vector');
  const magnitude=Math.hypot(...vector);
  if(magnitude<1e-12)throw new Error('zero embedding vector');
  return vector.map(x=>x/magnitude);
}
export function cosine(a:number[],b:number[]):number {
  if(a.length!==b.length)return 0;
  return a.reduce((sum,x,i)=>sum+x*b[i],0);
}
export function embeddingProvider():EmbeddingProvider|null {
  const endpoint=process.env.EMBEDDINGS_API_URL||'';
  const model=process.env.EMBEDDINGS_MODEL||'';
  const key=process.env.EMBEDDINGS_API_KEY||'';
  if(!endpoint||!model||!key)return null;
  const parsed=new URL(endpoint);
  if(parsed.protocol!=='https:')throw new Error('embeddings endpoint requires HTTPS');
  return {model,async embed(text:string):Promise<number[]> {
    const response=await fetch(parsed,{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+key},body:JSON.stringify({model,input:text}),signal:AbortSignal.timeout(20000)});
    if(!response.ok)throw new Error('embedding provider error: '+response.status);
    const responseBody=await response.json() as {data?:{embedding?:number[]}[]};
    return normalizeVector(responseBody.data?.[0]?.embedding);
  }};
}
export function digest(text:string):string {return createHash('sha256').update(text).digest('hex')}
/** Explicitly triggered by user/admin: never uploads stored documents silently. */
export async function rebuildIndex(state:KnowledgeState, provider:EmbeddingProvider, maxChunks=30):Promise<{indexed:number;remaining:number}> {
  const vectors=semanticState(state);
  const living=new Set(state.chunks.map(c=>c.id));
  vectors.entries=vectors.entries.filter(e=>living.has(e.chunkId)&&e.model===provider.model);
  const pending=state.chunks.filter(c=>!vectors.entries.some(e=>e.chunkId===c.id&&e.digest===digest(c.text)));
  const selected=pending.slice(0,Math.min(maxChunks,30));
  let indexed=0;
  for(const chunk of selected){
    const vector=normalizeVector(await provider.embed(chunk.text));
    const previous=vectors.entries.find(e=>e.model===provider.model&&e.vector.length!==vector.length);
    if(previous)throw new Error('embedding dimensions mismatch');
    vectors.entries=vectors.entries.filter(e=>e.chunkId!==chunk.id);
    vectors.entries.push({chunkId:chunk.id,digest:digest(chunk.text),vector,model:provider.model});
    indexed++;
  }
  return {indexed,remaining:pending.length-indexed};
}
export async function hybridSearch(state:KnowledgeState,query:string,provider:EmbeddingProvider,max=5):Promise<SemanticResult[]> {
  const lexical=retrieve(state,query,Math.max(max,10));
  const vector=normalizeVector(await provider.embed(query));
  const index=semanticState(state);
  const results=new Map<string,SemanticResult>();
  lexical.forEach((item,rank)=>results.set(item.id,{...item,lexicalScore:1/(60+rank),semanticScore:0,score:1/(60+rank)}));
  const semantic=index.entries.filter(e=>e.model===provider.model&&e.vector.length===vector.length).map(e=>({e,score:cosine(e.vector,vector)})).sort((a,b)=>b.score-a.score).slice(0,20);
  semantic.forEach(({e,score},rank)=>{
    const chunk=state.chunks.find(c=>c.id===e.chunkId);
    if(!chunk||e.digest!==digest(chunk.text))return;
    const document=state.documents.find(d=>d.id===chunk.documentId);
    const boost=score>0.1?1/(60+rank):0;
    const prev=results.get(e.chunkId);
    if(prev){prev.semanticScore=boost;prev.score+=boost}
    else results.set(e.chunkId,{id:chunk.id,documentId:chunk.documentId,title:document?.title||'Tài liệu',ordinal:chunk.ordinal,excerpt:chunk.text.slice(0,600),lexicalScore:0,semanticScore:boost,score:boost});
  });
  return [...results.values()].filter(x=>x.score>0).sort((a,b)=>b.score-a.score||a.id.localeCompare(b.id)).slice(0,max);
}
