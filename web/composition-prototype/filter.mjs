// Pure time-addressed automation. Hz interpolation is logarithmic.
const BEAT=24000;
export const OPEN=12000,CLOSED=600,BRIDGE=1440;
const mix=(a,b,t)=>a*Math.pow(b/a,Math.max(0,Math.min(1,t)));
export function ramp(from,to,start,end){return Object.freeze({from,to,start,end});}
export function rampAt(r,at){return mix(r.from,r.to,r.end===r.start?1:(at-r.start)/(r.end-r.start));}
export function scoreCutoff(active,at){
 if(!active)return OPEN;
 const local=at-active.origin;
 let name=null,length=0,t=0;
 if(active.mode==='score'){
   const rows=active.bundle.arrangement;
   for(let i=0;i<rows.length;i++){const row=rows[i];if(local>=row.from&&local<row.from+row.length){name=row.name;length=row.length;t=local-row.from;break;}}
 }else{name=active.mode;length=active.bundle.scenes[name].length;t=((local%length)+length)%length;}
 if(name===null)return OPEN;
 const span=4*BEAT;
 if(name==='suspension'){
   if(t<span)return mix(OPEN,CLOSED,t/span);
   if(t>length-span)return mix(CLOSED,OPEN,(t-length+span)/span);
   return CLOSED;
 }
 if(name==='one_breath')return mix(OPEN,CLOSED,t/length);
 if(name==='confluence')return mix(CLOSED,OPEN,t/span);
 return OPEN;
}
export function cutoffAt(filter,active,at){
 const target=filter.mode==='score'?scoreCutoff(active,at):rampAt(filter.ramp,at);
 return filter.bridge&&at<filter.bridge.end?mix(filter.bridge.from,target,(at-filter.bridge.start)/(filter.bridge.end-filter.bridge.start)):target;
}
// Persistent, stereo one-pole low-pass. No per-sample allocations.
// A short dry/wet fade also makes enabling the filter continuous.
export class SharedLowpass{
 constructor(){this.l=0;this.r=0;this.wet=0;}
 process(left,right,filter,active,at){
  for(let i=0;i<left.length;i++){
   const hz=cutoffAt(filter,active,at+i),a=1-Math.exp(-2*Math.PI*hz/48000);
   this.l+=a*(left[i]-this.l);this.r+=a*(right[i]-this.r);
   this.wet=Math.min(1,this.wet+1/BRIDGE);
   left[i]+=this.wet*(this.l-left[i]);right[i]+=this.wet*(this.r-right[i]);
  }
 }
}
