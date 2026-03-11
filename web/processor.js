class MoonBitDspProcessor extends AudioWorkletProcessor {
  constructor(options) {
    super();
    this.freq = 440.0;
    this.gain = 0.3;
    this.pan = 0.0;
    this.sourceKind = 0;
    this.ready = false;
    this.initError = null;
    this.wasm = null;

    this.port.onmessage = (event) => {
      const data = event.data;
      if (!data || typeof data !== "object") {
        return;
      }
      if (data.type === "set-freq") {
        this.freq = Number(data.value);
      } else if (data.type === "set-gain") {
        this.gain = Number(data.value);
      } else if (data.type === "set-pan") {
        this.pan = Number(data.value);
      } else if (data.type === "set-source") {
        this.sourceKind = Number(data.value);
      }
    };

    const wasmModule = options?.processorOptions?.wasmModule;
    if (wasmModule) {
      this.initWasm(wasmModule);
    } else {
      this.initError = "Missing wasm module";
      this.port.postMessage({ type: "error", message: this.initError });
    }
  }

  async initWasm(wasmModule) {
    try {
      const importObject = {
        spectest: {
          print_char() {},
        },
        "moonbit:ffi": {
          make_closure(funcref, closure) {
            return funcref.bind(null, closure);
          },
        },
      };

      const instance = await WebAssembly.instantiate(wasmModule, importObject);
      this.wasm = instance.exports;
      if (typeof this.wasm.reset_phase === "function") {
        this.wasm.reset_phase();
      } else if (typeof this.wasm.demo_reset_phase === "function") {
        this.wasm.demo_reset_phase();
      }
      if (
        typeof this.wasm.tick !== "function" &&
        typeof this.wasm.tick_source !== "function" &&
        typeof this.wasm.demo_tick !== "function" &&
        typeof this.wasm.demo_tick_source !== "function"
      ) {
        throw new Error("tick export not found");
      }
      this.ready = true;
      this.port.postMessage({
        type: "ready",
        exports: Object.keys(this.wasm),
      });
    } catch (error) {
      this.initError = error instanceof Error ? error.message : String(error);
      this.port.postMessage({ type: "error", message: this.initError });
    }
  }

  process(_inputs, outputs) {
    const output = outputs[0];
    if (!output || output.length === 0) {
      return true;
    }

    const left = output[0];
    const right = output[1];

    if (!this.ready || !this.wasm) {
      left.fill(0);
      if (right) {
        right.fill(0);
      }
      return true;
    }

    const { leftGain, rightGain } = this.panGains(this.pan);

    for (let index = 0; index < left.length; index += 1) {
      const raw = typeof this.wasm.tick_source === "function"
        ? this.wasm.tick_source(this.sourceKind, this.freq, sampleRate)
        : typeof this.wasm.demo_tick_source === "function"
          ? this.wasm.demo_tick_source(this.sourceKind, this.freq, sampleRate)
          : typeof this.wasm.tick === "function"
            ? this.wasm.tick(this.freq, sampleRate)
            : this.wasm.demo_tick(this.freq, sampleRate);
      const sample = raw * this.gain;
      left[index] = sample * leftGain;
      if (right) {
        right[index] = sample * rightGain;
      }
    }

    return true;
  }

  panGains(position) {
    const clamped = Math.max(-1, Math.min(1, Number(position) || 0));
    if (clamped <= -1) {
      return { leftGain: 1, rightGain: 0 };
    }
    if (clamped >= 1) {
      return { leftGain: 0, rightGain: 1 };
    }
    const angle = (clamped + 1) * Math.PI * 0.25;
    return {
      leftGain: Math.cos(angle),
      rightGain: Math.sin(angle),
    };
  }
}

registerProcessor("moonbit-dsp", MoonBitDspProcessor);
