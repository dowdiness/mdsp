import {preparationQueue} from './preparation-queue.mjs';
const $=id=>document.getElementById(id);
let doc=await (await fetch('../../examples/light-orbit/named.json')).json(), session, revision=0;
const draw=()=>{
  const name=$('pattern').value;
  $('expression').value=doc.patterns[name];
  $('uses').textContent='参照先: '+Object.entries(doc.scenes).filter(([,refs])=>refs.includes(name)).map(([name])=>name).join('、');
  $('document').textContent=JSON.stringify(doc,null,2);
};
for(const name of Object.keys(doc.patterns))$('pattern').add(new Option(name,name));
for(const [name] of doc.song)$('section').add(new Option(name,name));
$('pattern').onchange=draw;draw();
function record(data){session.log.push(data);if(session.log.length>100)session.log.shift();$('log').textContent=JSON.stringify(session.log.slice(-8),null,2);}
function command(action){
  if(!session || session.closed || session.stopping)return Promise.reject(Error('先に再生してください'));
  if(session.requests.size>=4)return Promise.reject(Error('操作の受付待ちです'));
  const id=++session.sequence;
  return new Promise(resolve=>{session.requests.set(id,resolve);session.node.port.postMessage({...action,id,sentMs:Date.now()});});
}
async function prepare(nextDoc){
  if(!session || session.closed || session.stopping)throw Error('先に再生してください');
  const s=session, version=++revision;s.editVersion=version;
  doc=nextDoc; // new edits build on the latest draft, including queued changes
  $('error').textContent='';$('preparation').textContent='準備中 — 次の編集で置換、取消し可能';
  try {
    const result=await s.queue.submit(nextDoc,version);
    if(result.kind==='retired'||s.editVersion!==version)return {decision:'superseded'};
    const receipt=await command({kind:'install',bundle:result.bundle});
    if(s.editVersion!==version)return receipt;
    if(!['started','reserved'].includes(receipt.decision))throw Error(receipt.error??receipt.decision);
    draw();record({kind:'preparation',ms:result.prepareMs,revision:version,...result.cacheStats,timing:{...result.timing,...receipt.timing,target:receipt.target,receiptAt:receipt.at,mainReceiptMs:Date.now()}});return receipt;
  }finally{if(s.editVersion===version)$('preparation').textContent='準備待ちなし（予約は再生状態を参照）';}
}
async function cancel(){
  if(!session || session.closed)return;
  session.editVersion=++revision;session.queue.cancel();
  $('preparation').textContent='準備結果を取消しました。予約の取消結果は下の記録を参照';
  return command({kind:'cancel'});
}
async function start(captureFrames=0){
  if(session && !session.closed)throw Error('既に再生中です');
  if(!Number.isSafeInteger(captureFrames)||captureFrames<0||captureFrames>864000||captureFrames%128)throw Error('invalid capture');
  const ctx=new AudioContext({sampleRate:48000,latencyHint:'interactive'}),worker=new Worker('./worker.mjs',{type:'module'});
  const s=session={ctx,worker,closed:false,requests:new Map(),sequence:0,log:[],latest:null};
  s.result=new Promise((resolve,reject)=>{s.resolve=resolve;s.reject=reject;});s.result.catch(()=>{});
  const fail=error=>{worker.terminate();void ctx.close();s.closed=true;s.queue.close();for(const resolve of s.requests.values())resolve({decision:'stopped'});s.requests.clear();s.reject(error);$('error').textContent=String(error);};
  s.queue=preparationQueue(worker);
  worker.onerror=e=>fail(Error(e.message));
  try{
    await ctx.audioWorklet.addModule('./processor.mjs');
    const node=s.node=new AudioWorkletNode(ctx,'composition-prototype',{numberOfInputs:0,numberOfOutputs:1,outputChannelCount:[2],processorOptions:{captureFrames}});
    node.onprocessorerror=()=>fail(Error('audio processor error'));
    node.port.onmessage=async({data})=>{
      if(data.kind==='status'){if(data.decision==='applied')record({kind:'applied',revision:data.revision,at:data.appliedAt,wallMs:data.appliedMs});s.latest=data;$('state').textContent=`${(data.sample/48000).toFixed(2)}秒 / ${data.mode} / ${data.scene}\n適用済み revision ${data.revision}\n予約 ${JSON.stringify(data.pending)}\n最大同時発音開始 ${data.stats.maxOnsets}`;}
      else if(data.kind==='receipt'){record(data);s.requests.get(data.id)?.(data);s.requests.delete(data.id);}
      else if(data.kind==='interrupted'){$('error').textContent='音声時計が不連続になりました。保留から再開してください。';}
      else if(data.kind==='fatal')fail(Error(data.error));
      else if(data.kind==='complete'){
        s.stopping=true;
        s.queue.close();for(const resolve of s.requests.values())resolve({decision:'stopped'});s.requests.clear();
        worker.terminate();await new Promise(r=>setTimeout(r,1200));
        const outputStats=ctx.playbackStats?.toJSON()??null;await ctx.close();s.closed=true;s.resolve({...data,outputStats,log:s.log});$('state').textContent='停止しました';
      }
    };
    node.connect(ctx.destination);await ctx.resume();await prepare(structuredClone(doc));
  }catch(e){fail(e);throw e;}
}
const run=fn=>()=>Promise.resolve().then(fn).catch(e=>{$('error').textContent=String(e);});
$('start').onclick=run(()=>start());$('stop').onclick=run(()=>session?.node?.port.postMessage({kind:'stop'}));
$('resume').onclick=run(()=>command({kind:'resume'}));$('cancel').onclick=run(cancel);
$('calm').onclick=run(()=>command({kind:'game',event:'calm'}));$('combat').onclick=run(()=>command({kind:'game',event:'combat'}));
$('score').onclick=run(()=>command({kind:'score',section:$('section').value,offsetBeats:Number($('offset').value)}));
$('edit').onclick=run(()=>{const next=structuredClone(doc);next.patterns[$('pattern').value]=$('expression').value;return prepare(next);});
window.composition={start,command,cancel,edit:async(name,source)=>{if(!Object.hasOwn(doc.patterns,name))throw Error('unknown pattern');const next=structuredClone(doc);next.patterns[name]=source;return prepare(next);},get doc(){return structuredClone(doc);},get latest(){return session?.latest;},get result(){return session?.result;}};
