import {SharedLowpass,cutoffAt} from '../web/composition-prototype/filter.mjs';
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import * as engine from '../_build/js/release/build/browser/direct_audio/direct_audio.js';
import {initial,reduce,ownBundle,Q} from '../web/composition-prototype/model.mjs';
import {SharedDelay} from '../web/composition-prototype/delay.mjs';
const stem=process.argv.includes('--filter')?'composition-filter-browser':process.argv.includes('--definition')?'composition-definition-browser':'composition-browser';
const raw=JSON.parse(await readFile(`artifacts/audio-profile/${stem}.json`,'utf8'));
const bytes=await readFile(`artifacts/audio-profile/${stem}.pcm`);
if(process.argv.includes('--incremental')||process.argv.includes('--definition')) {
  const compiler=await import('../_build/js/release/build/cmd/composition_prepare/composition_prepare.js');
  const {prepare}=await import('../web/composition-prototype/prepare.mjs');
  const doc=JSON.parse(await readFile('examples/light-orbit/named.json'));
  for(const entry of raw.trace.filter(e=>e.action.kind==='install')) {
    const revision=entry.action.bundle.revision;
    assert.ok(revision===1||revision===2);
    const source=structuredClone(doc);
    if(revision===2)source.patterns.orbit='note("E4 G4 A4").slow(3).gain(0.075)';
    const reference=prepare(compiler,source,revision);
    assert.deepEqual(entry.action.bundle,reference);
    entry.action.bundle=reference;
  }
}

const pcm=new Float32Array(bytes.buffer,bytes.byteOffset,bytes.byteLength/4);
assert.equal(raw.frames,864000);assert.equal(pcm.length,raw.frames);assert.equal(raw.error,'');assert.equal(raw.stats.clockGaps,0);
let s=initial(),cursor=0,mismatches=0,resetBusDifference=0;
const events=[],applied=[],delay=new SharedDelay();let resetDelay=new SharedDelay();const lowpass=new SharedLowpass();
const l=new Float64Array(Q),r=new Float64Array(Q),nl=new Float64Array(Q),nr=new Float64Array(Q);
assert.ok(engine.initialize());
for(let at=0;at<raw.frames;at+=Q){
  while(cursor<raw.trace.length&&raw.trace[cursor].at===at){const entry=raw.trace[cursor++];if(entry.action.kind==='install')entry.action.bundle=ownBundle(entry.action.bundle);const next=reduce(s,entry.action);assert.equal(next.decision,entry.decision);if(entry.action.kind==='install'&&s.active)assert.equal(next.state.filter,s.filter,'edit must preserve automation');s=next.state;}
  const before=s.filter?.enabled?cutoffAt(s.filter,s.active,at):null;const result=reduce(s,{kind:'tick'});s=result.state;if(result.decision==='applied'&&before!==null)assert.ok(Math.abs(cutoffAt(s.filter,s.active,at)-before)<1e-8,'transition must start at current cutoff');events.push(...result.events);
  if(result.decision==='applied'){applied.push({at,mode:s.active.mode,revision:s.active.bundle.revision});resetDelay=new SharedDelay();}
  engine.begin();for(const e of result.events)assert.ok(engine.row(e.at,e.end,e.route,e.hz,e.gain,e.pan));
  assert.ok(engine.seal());assert.ok(engine.publish());assert.ok(engine.process());
  for(let i=0;i<Q;i++){l[i]=nl[i]=engine.left(i);r[i]=nr[i]=engine.right(i);}
  if(s.filter?.enabled){lowpass.process(l,r,s.filter,s.active,at);nl.set(l);nr.set(r);}
  delay.process(l,r);resetDelay.process(nl,nr);
  for(let i=0;i<Q;i++){assert.ok(Number.isFinite(pcm[at+i]));if(pcm[at+i]!==Math.fround(l[i]))mismatches++;resetBusDifference=Math.max(resetBusDifference,Math.abs(l[i]-nl[i]));}
}
assert.equal(cursor,raw.trace.length);assert.deepEqual(events,raw.events);assert.equal(mismatches,0);
assert.ok(applied.some(a=>a.revision===2));assert.ok(applied.some(a=>a.mode==='suspension'));assert.ok(applied.some(a=>a.mode==='confluence'));assert.equal(applied.at(-1).mode,'score');
assert.ok(resetBusDifference>1e-5,'fixture must detect resetting shared delay');
const result={passed:true,frames:raw.frames,events:events.length,pcmMismatches:mismatches,resetBusDifference,applied,stats:raw.stats,outputStats:raw.outputStats,preparations:(raw.log??[]).filter(e=>e.kind==='preparation')};
await writeFile(`artifacts/audio-profile/${stem}-verification.json`,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
