class MoonBitDspProcessor extends AudioWorkletProcessor {
  constructor(options) {
    super();
    this.freq = 440.0;
    this.gain = 0.3;
    this.ready = false;
    this.initError = null;
    this.wasm = null;
    this.usesCompiledGraph = false;
    this.reportedRuntimeError = false;

    this.port.onmessage = (event) => {
      const data = event.data;
      if (!data || typeof data !== "object") {
        return;
      }
      if (data.type === "set-freq") {
        this.freq = Number(data.value);
      } else if (data.type === "set-gain") {
        this.gain = Number(data.value);
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
      }

      this.usesCompiledGraph =
        typeof this.wasm.init_compiled_graph === "function" &&
        typeof this.wasm.process_compiled_block === "function" &&
        typeof this.wasm.compiled_output_sample === "function";

      if (this.usesCompiledGraph) {
        const initialized = this.wasm.init_compiled_graph(sampleRate, 128);
        if (!initialized) {
          throw new Error("CompiledDsp browser graph failed to initialize");
        }
      } else if (
        typeof this.wasm.tick !== "function" &&
        typeof this.wasm.tick_source !== "function" &&
        typeof this.wasm.demo_tick !== "function" &&
        typeof this.wasm.demo_tick_source !== "function"
      ) {
        throw new Error("No supported browser DSP exports found");
      }

      this.ready = true;
      this.port.postMessage({
        type: "ready",
        exports: Object.keys(this.wasm),
        mode: this.usesCompiledGraph ? "compiled-dsp" : "legacy-tick",
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

    if (this.usesCompiledGraph) {
      const processed = this.wasm.process_compiled_block(
        this.freq,
        this.gain,
        sampleRate,
        left.length,
      );
      if (!processed) {
        this.fillSilence(left, right);
        if (!this.reportedRuntimeError) {
          this.reportedRuntimeError = true;
          this.port.postMessage({
            type: "error",
            message: "CompiledDsp browser block processing failed",
          });
        }
        return true;
      }

      for (let index = 0; index < left.length; index += 1) {
        const sample = this.wasm.compiled_output_sample(index);
        left[index] = sample;
        if (right) {
          right[index] = sample;
        }
      }

      return true;
    }

    for (let index = 0; index < left.length; index += 1) {
      const raw = typeof this.wasm.tick_source === "function"
        ? this.wasm.tick_source(0, this.freq, sampleRate)
        : typeof this.wasm.demo_tick_source === "function"
          ? this.wasm.demo_tick_source(0, this.freq, sampleRate)
          : typeof this.wasm.tick === "function"
            ? this.wasm.tick(this.freq, sampleRate)
            : this.wasm.demo_tick(this.freq, sampleRate);
      const sample = raw * this.gain;
      left[index] = sample;
      if (right) {
        right[index] = sample;
      }
    }

    return true;
  }

  fillSilence(left, right) {
    left.fill(0);
    if (right) {
      right.fill(0);
    }
  }
}

registerProcessor("moonbit-dsp", MoonBitDspProcessor);
