import assert from 'node:assert/strict';
import {writeFile} from 'node:fs/promises';
import {initial,reduce} from '../web/composition-prototype/model.mjs';
import {cutoffAt,scoreCutoff,ramp,rampAt,SharedLowpass} from '../web/composition-prototype/filter.mjs';
const active={mode:'score',origin:0,bundle:{arrangement:[{name:'suspension',from:0,length:576000}]}};
assert.equal(scoreCutoff(active,12*24000),600);
assert.equal(scoreCutoff(active,22*24000),Math.sqrt(600*12000));
let s={...initial(),active,now:0};s=reduce(s,{kind:'filter',hz:600,beats:4}).state;
s={...s,now:24000};const before=cutoffAt(s.filter,s.active,s.now);s=reduce(s,{kind:'filter',hz:10000,beats:2}).state;
assert.equal(cutoffAt(s.filter,s.active,s.now),before);assert.ok(Math.abs(cutoffAt(s.filter,s.active,s.now+48000)-10000)<1e-8);
assert.equal(reduce(s,{kind:'filter',hz:0,beats:4}).decision,'invalid-filter');
s=reduce({...s,now:12*24000},{kind:'filter-score'}).state;
assert.equal(cutoffAt(s.filter,s.active,s.now+1440),600);
// Chunk partition invariance and the analytic impulse response of the filter.
const filter={enabled:true,mode:'ramp',ramp:ramp(600,600,0,0),bridge:null};
const a=1-Math.exp(-2*Math.PI*600/48000), impulse=new SharedLowpass();impulse.wet=1;
const l=new Float64Array(256),r=new Float64Array(256);l[0]=1;impulse.process(l,r,filter,active,0);
for(let i=0;i<l.length;i++)assert.ok(Math.abs(l[i]-a*(1-a)**i)<1e-14);
const changing={enabled:true,mode:'ramp',ramp:ramp(12000,600,0,96000),bridge:null};
const render=width=>{const dsp=new SharedLowpass(),out=[];for(let at=0;at<96000;at+=width){const l=Float64Array.from({length:Math.min(width,96000-at)},(_,i)=>Math.sin((at+i)*.9)),r=l.slice();dsp.process(l,r,changing,active,at);out.push(...l);}return out;};
assert.deepEqual(render(128),render(384));
// No parameter discontinuity when retargeted; no unstable or unbounded output.
const values=render(128);assert.ok(values.every(v=>Number.isFinite(v)&&Math.abs(v)<=1));
const report={passed:true,retargetStartsAtCurrentValue:true,midSectionTargetHz:600,impulseAnalyticMatch:true,partitionInvariant:true,boundedOutput:true};
await writeFile('docs/performance/2026-09-08-composition-filter-core.json',JSON.stringify(report,null,2)+'\n');console.log(report);
