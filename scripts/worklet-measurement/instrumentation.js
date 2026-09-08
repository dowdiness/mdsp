// Appended to the production scheduler processor by the measurement server.
// No production source, scheduling policy or render implementation is replaced.
const clock = typeof performance !== 'undefined' ? () => performance.now() : () => Date.now();
class MeasuredScheduler extends MoonDspSchedulerProcessor {
  constructor(options) {
    super(options);
    this.measuring = false;
    this.renderTimes = new Float64Array(65536);
    this.gaps = new Float64Array(65536);
    this.preparations = new Float64Array(1024);
    this.handlers = new Float64Array(1024);
    this.requests = 0;
    this.renders = 0;
    this.prepares = 0;
    this.previous = 0;
    const handle = this.port.onmessage;
    this.port.onmessage = event => {
      const d = event.data;
      const timed = this.measuring && ['prepare-only', 'apply-score', 'positive-control'].includes(d.type);
      const start = timed ? clock() : 0;
      if (d.type === 'measure-position') {
        this.port.postMessage({type:'position',position:this.wasm.scheduler_sample_position(),peak:this.lastPeak || 0});
      } else if (d.type === 'measure-start') {
        this.renders = this.prepares = this.requests = 0;
        this.previous = 0;
        this.measuring = true;
        this.port.postMessage({ type: 'measure-started' });
      } else if (d.type === 'measure-stop') {
        this.measuring = false;
        this.port.postMessage({ type: 'measurement', clock: typeof performance !== 'undefined' ? 'performance.now' : 'Date.now',
          renders: this.renders, prepares: this.prepares, position:this.wasm.scheduler_sample_position(),
          renderTimes: this.renderTimes.slice(0, this.renders), gaps: this.gaps.slice(0, this.renders),
          preparations: this.preparations.slice(0, this.prepares), handlers: this.handlers.slice(0, this.requests),
          overflow: this.renders > this.renderTimes.length || this.prepares > this.preparations.length || this.requests > this.handlers.length });
      } else if (d.type === 'prepare-only') {
        this.wasm.clear_playback_input();
        for (let i = 0; i < d.text.length; i++) this.wasm.push_playback_char(d.text.charCodeAt(i));
        const token = this.playback.wasm.prepare_song_input();
        if (!token) this.port.postMessage({ type: 'error', message: 'prepare-only failed' });
        else this.wasm.discard_prepared_playback(token);
      } else if (d.type === 'positive-control') {
        const start = clock();
        while (clock() - start < 100) {} // Intentional known audio-thread stall.
      } else handle(event);
      if (timed) this.handlers[this.requests++] = clock() - start;
    };
  }
  async initWasm(module) {
    await super.initWasm(module);
    if (!this.playback) return;
    const exports = { ...this.wasm };
    exports.prepare_song_input = () => {
      const start = clock();
      const token = this.wasm.prepare_song_input();
      if (this.measuring) this.preparations[this.prepares++] = clock() - start;
      return token;
    };
    this.playback.wasm = exports;
  }
  process(inputs, outputs) {
    if (!this.measuring) return super.process(inputs, outputs);
    const start = clock();
    const result = super.process(inputs, outputs);
    this.lastPeak = 0;
    for (const channel of outputs[0] || []) for (const value of channel) this.lastPeak = Math.max(this.lastPeak, Math.abs(value));
    this.renderTimes[this.renders] = clock() - start;
    this.gaps[this.renders++] = this.previous ? start - this.previous : 0;
    this.previous = start;
    return result;
  }
}
registerProcessor('moondsp-measured', MeasuredScheduler);
