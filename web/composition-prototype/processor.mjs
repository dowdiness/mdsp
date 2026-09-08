import * as engine from '../../_build/js/release/build/browser/direct_audio/direct_audio.js';
import {initial, reduce, position, ownBundle, Q} from './model.mjs';
import {SharedDelay} from './delay.mjs';
class Composition extends AudioWorkletProcessor {
  constructor(options) {
    super();
    if (sampleRate !== 48000 || !engine.initialize()) throw Error('48kHz required');
    this.state = initial(); this.delay = new SharedDelay(); this.left = new Float64Array(Q); this.right = new Float64Array(Q);
    this.inbox = []; this.frame = null; this.paused = false; this.stopped = false; this.trace = []; this.events = [];
    this.frames = options.processorOptions?.captureFrames ?? 0; this.pcm = new Float32Array(this.frames);
    this.stats = {maxOnsets:0, maxCallbackMs:0, clockGaps:0, wetPeak:0};
    this.port.onmessage = ({data}) => {
      if (data.kind === 'stop') {this.finish(); return;}
      if (this.inbox.length >= 4) {this.port.postMessage({kind:'receipt',id:data.id,decision:'queue-full'}); return;}
      this.inbox.push({...data,audioReceivedMs:Date.now()});
    };
  }
  finish() {
    if (this.stopped) return;
    this.stopped = true;
    this.port.postMessage({kind:'complete',frames:this.state.now,stats:this.stats,trace:this.trace,events:this.events,pcm:this.pcm},[this.pcm.buffer]);
  }
  process(_inputs, outputs) {
    const l = outputs[0][0], r = outputs[0][1]; l.fill(0); r.fill(0);
    if (this.stopped) return false;
    const start = Date.now();
    try {
      if(l.length !== Q) throw Error('128-frame blocks required');
      if(this.inbox.length) {
        const action = this.inbox.shift();
        try {
          if(action.kind === 'resume') {this.frame=null;this.paused=false;this.port.postMessage({kind:'receipt',id:action.id,decision:'resumed'});}
          else {
            const validationStart=Date.now();
            if(action.kind === 'install') action.bundle = ownBundle(action.bundle);
            const validatedMs=Date.now();
            const result = reduce(this.state, action);
            if(this.frames) this.trace.push({at:this.state.now, action, decision:result.decision});
            this.state = result.state;
            this.port.postMessage({kind:'receipt',id:action.id,at:this.state.now,decision:result.decision,target:this.state.pending?.at,timing:{installSentMs:action.sentMs,audioReceivedMs:action.audioReceivedMs,admittedMs:Date.now(),validationMs:validatedMs-validationStart}});
          }
        } catch(error) {this.port.postMessage({kind:'receipt',id:action.id,decision:'invalid',error:String(error)});}
      }
      if(!this.state.active || this.paused) return true;
      if(this.frame !== null && currentFrame !== this.frame + Q) {
        this.stats.clockGaps++; this.paused=true;this.port.postMessage({kind:'interrupted'});return true;
      }
      this.frame=currentFrame;
      const at=this.state.now, result=reduce(this.state,{kind:'tick'});this.state=result.state;
      engine.begin();
      for(const e of result.events) if(!engine.row(e.at,e.end,e.route,e.hz,e.gain,e.pan)) throw Error('row rejected');
      if(!engine.seal() || !engine.publish() || !engine.process()) throw Error('DSP stopped');
      for(let i=0;i<Q;i++){this.left[i]=engine.left(i);this.right[i]=engine.right(i);}
      l.set(this.left);this.delay.process(this.left,this.right);
      for(let i=0;i<Q;i++)this.stats.wetPeak=Math.max(this.stats.wetPeak,Math.abs(this.left[i]-l[i]));
      l.set(this.left);r.set(this.right);
      if(this.frames){this.pcm.set(l,at);this.events.push(...result.events);}
      this.stats.maxOnsets=Math.max(this.stats.maxOnsets,result.events.length);
      this.stats.maxCallbackMs=Math.max(this.stats.maxCallbackMs,Date.now()-start);
      if(result.decision === 'applied' || this.state.now % 4096 === 0) this.port.postMessage({kind:'status',sample:this.state.now,...position(this.state),revision:this.state.active.bundle.revision,
        pending:this.state.pending && {at:this.state.pending.at,mode:this.state.pending.next.mode,revision:this.state.pending.next.bundle.revision},stats:this.stats,decision:result.decision,appliedAt:at,appliedMs:Date.now()});
      if(this.frames && this.state.now >= this.frames)this.finish();
      return !this.stopped;
    }catch(error){this.port.postMessage({kind:'fatal',error:String(error)});this.stopped=true;return false;}
  }
}
registerProcessor('composition-prototype',Composition);
