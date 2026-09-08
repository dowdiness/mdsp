import assert from 'node:assert/strict';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import * as compiler from '../_build/js/release/build/cmd/composition_prepare/composition_prepare.js';
import {prepare,compileRows} from '../web/composition-prototype/prepare.mjs';
import {initial,reduce,ownBundle,Q} from '../web/composition-prototype/model.mjs';
const doc=JSON.parse(await readFile(new URL('../examples/light-orbit/named.json',import.meta.url)));
const original=await readFile(new URL('../examples/light-orbit/original.song',import.meta.url),'utf8');
const began=performance.now(),bundle=ownBundle(prepare(compiler,doc,1)),prepareMs=performance.now()-began;
assert.deepEqual(bundle.score,compileRows(compiler,original));
const changed=structuredClone(doc);changed.patterns.orbit=changed.patterns.orbit.replace('0.105','0.075');
const edited=ownBundle(prepare(compiler,changed,2));
const affected=Object.keys(bundle.scenes).filter(name=>JSON.stringify(bundle.scenes[name])!==JSON.stringify(edited.scenes[name]));
assert.deepEqual(affected,Object.keys(doc.scenes).filter(name=>doc.scenes[name].includes('orbit')));
let s=reduce(initial(),{kind:'install',bundle}).state, count=0,maxOnsets=0;
for(let at=0;at<bundle.length;at+=Q){const r=reduce(s,{kind:'tick'});s=r.state;count+=r.events.length;maxOnsets=Math.max(maxOnsets,r.events.length);}
assert.equal(count,bundle.score.length);
s=reduce(initial(),{kind:'install',bundle}).state;
s=reduce(s,{kind:'game',event:'calm'}).state;
s=reduce(s,{kind:'install',bundle:edited}).state;
assert.equal(s.pending.next.mode,'suspension');assert.equal(s.pending.next.bundle.revision,2);
assert.equal(reduce(s,{kind:'cancel'}).state.pending,null);
while(s.now<96000){s=reduce(s,{kind:'tick'}).state;}
let r=reduce(s,{kind:'tick'});assert.equal(r.decision,'applied');s=r.state;
assert.equal(s.active.mode,'suspension');assert.equal(s.active.bundle.revision,2);
assert.equal(reduce(s,{kind:'install',bundle}).decision,'stale');
const mutable=structuredClone(bundle),owned=ownBundle(mutable);mutable.score[0].gain=4;assert.notEqual(owned.score[0].gain,4);
assert.throws(()=>ownBundle({...bundle,score:[{...bundle.score[0],route:9}]}));
// Exact boundary at one beat (not divisible by Q): no duplicated/missing loop onsets.
const short=ownBundle({...bundle,revision:3,length:24000,score:[{at:0,end:1000,route:5,hz:440,gain:.1,pan:0}],scenes:{suspension:{length:24000,rows:[{at:0,end:1000,route:5,hz:440,gain:.1,pan:0}]}},arrangement:[{name:'suspension',from:0,length:24000}]});
s=reduce(initial(),{kind:'install',bundle:short}).state;s=reduce(s,{kind:'game',event:'calm'}).state;
const onsets=[];while(s.now<168128){r=reduce(s,{kind:'tick'});s=r.state;onsets.push(...r.events.map(e=>e.at));}
assert.deepEqual(onsets,[0,96000,119936,144000,167936]);
const report={passed:true,prepareMs,sections:bundle.arrangement.length,beats:bundle.length/24000,events:count,maxOnsets,affectedScenes:affected,sharedDefinitionEditSites:1,originalEquality:true,loopBoundary:true};
await mkdir('artifacts/composition-prototype',{recursive:true});await writeFile('artifacts/composition-prototype/check.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
