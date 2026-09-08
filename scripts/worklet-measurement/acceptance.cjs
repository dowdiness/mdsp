exports.run = async function run(score) {
  const wait=ms=>new Promise(r=>setTimeout(r,ms));
  const module=await WebAssembly.compile(await (await fetch('/engine.wasm')).arrayBuffer());
  const output=ctx=>{const s=ctx.playbackStats??ctx.playoutStats;return s?{api:ctx.playbackStats?'playbackStats':'playoutStats',...s.toJSON()}:null;};
  const stats=a=>{a=Array.from(a).sort((a,b)=>a-b);return {count:a.length,p95_ms:a.length?a[Math.ceil(a.length*.95)-1]:null,max_ms:a.length?a.at(-1):null};};
  async function setup() {
    const ctx=new AudioContext({sampleRate:48000,latencyHint:'interactive'});
    await ctx.audioWorklet.addModule('/processor.js');
    const node=new AudioWorkletNode(ctx,'moondsp-measured',{outputChannelCount:[2],processorOptions:{wasmModule:module,initialGain:.1}});
    const replies=[],errors=[];
    node.port.onmessage=({data})=>{replies.push(data);if(data.type==='error'||data.type.endsWith('-error'))errors.push(data);};
    node.onprocessorerror=()=>errors.push({type:'processorerror'});
    node.connect(ctx.destination);await ctx.resume();
    const send=data=>node.port.postMessage(data);
    async function receive(type) {
      const until=performance.now()+15000;
      while(!replies.some(r=>r.type===type)) {if(errors.length||performance.now()>until)throw Error(JSON.stringify({type,errors}));await wait(10);}
      return replies.splice(replies.findIndex(r=>r.type===type),1)[0];
    }
    await receive('ready');
    async function apply(revision,policy='continue') {
      send({type:'apply-score',mode:'song',policy,revision,text:revision%2?score.text.replaceAll('.gain(0.105)','.gain(0.104)'):score.text});
      const r=await receive('song-updated');
      if(r.revision!==revision || (policy==='restart' ? r.appliedAtSample!==0 : r.appliedAtSample<=0))throw Error('invalid apply receipt');
      return r;
    }
    async function startMeasure(){send({type:'measure-start'});await receive('measure-started');}
    async function finish(){send({type:'measure-stop'});const m=await receive('measurement');if(m.overflow||errors.length)throw Error('measurement failed');return {position:m.position,render:stats(m.renderTimes),preparation:stats(m.preparations),handler:stats(m.handlers)};}
    return {ctx,send,receive,apply,startMeasure,finish};
  }
  const trials=[];
  // Startup is explicitly included, with no render/JIT warmup before first application.
  for(let round=0;round<3;round++) {
    const h=await setup();const before=output(h.ctx);await h.startMeasure();
    const initial=await h.apply(0,'restart'),edit=await h.apply(1);
    await wait(2000);trials.push({mode:'cold-start-and-first-edit',round,before,after:output(h.ctx),initial,edit,measurement:await h.finish()});await h.ctx.close();
  }
  // Same bounded four CPU workers in both baseline and editing conditions.
  for(let round=0;round<3;round++) for(const editing of (round%2?[true,false]:[false,true])) {
    const h=await setup();await h.apply(0,'restart');await wait(2000);
    const url=URL.createObjectURL(new Blob(['let x=1;while(true){x=Math.sin(x)+1;}'],{type:'text/javascript'}));
    const workers=Array.from({length:4},()=>new Worker(url));
    try {
      await wait(500);const before=output(h.ctx);await h.startMeasure();
      for(let i=1;i<=24;i++){if(editing)await h.apply(i);await wait(250);}
      await wait(1500);trials.push({mode:editing?'loaded-edit':'loaded-baseline',round,workers:4,before,after:output(h.ctx),measurement:await h.finish()});
    } finally {workers.forEach(w=>w.terminate());URL.revokeObjectURL(url);await h.ctx.close();}
  }
  // Play the full original score, editing at multiple sections; restart only after its end.
  const h=await setup();await h.startMeasure();const before=output(h.ctx);await h.apply(0,'restart');
  const milestones=[];let revision=0;
  while(true) {
    h.send({type:'measure-position'});const p=await h.receive('position');
    milestones.push(p);
    if(p.position>=242*24000)break;
    if(milestones.length%3===0)await h.apply(++revision);
    await wait(2000);
  }
  const full=await h.finish();
  if(milestones.at(-1).peak>1e-8)throw Error('finite score did not become silent');
  const after=output(h.ctx);
  h.send({type:'restart-playback',revision:999});const restart=await h.receive('playback-restarted');
  if(restart.appliedAtSample!==0||restart.scoreRevision!==revision)throw Error('restart did not use applied score');
  await h.startMeasure();await wait(2000);h.send({type:'measure-position'});const resumed=await h.receive('position');
  if(resumed.position<=0||resumed.position>3*48000)throw Error('restart position invalid');
  await h.finish();await h.ctx.close();
  trials.push({mode:'full-original-score',before,after,measurement:full,milestones,edits:revision,restart,resumed});
  return {schema_version:2,user_agent:navigator.userAgent,visibility:document.visibilityState,hardware_concurrency:navigator.hardwareConcurrency,score_sections:score.sections,trials};
};
