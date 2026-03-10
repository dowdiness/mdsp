# Instruction: MoonBit wasm-gc → AudioWorklet Proof of Concept

## Goal

Build the **minimum viable prototype** that proves MoonBit compiled to wasm-gc can generate audio in a browser via AudioWorklet. The end result: a web page that plays a sine wave whose frequency can be changed with a slider.

This is a **technical risk reduction experiment**, not a product. Prioritize getting sound output over code quality or architecture.

## Success Criteria

1. A 440 Hz sine wave plays in the browser when the user clicks "Start"
2. A slider changes the frequency in real time (no clicks/pops)
3. The DSP computation runs inside MoonBit code compiled to wasm-gc
4. The wasm-gc module runs inside an AudioWorkletProcessor
5. No audible glitches during 30 seconds of continuous playback (confirms GC is not firing in the hot path)

## Non-Goals

- No fancy DSP (no filters, envelopes, effects)
- No type abstractions (no traits, no Finally Tagless)
- No build system sophistication
- No tests beyond "it plays sound"
- No mobile support
- No npm packaging

---

## Architecture Overview

```
┌─ Browser Main Thread ─────────────────────────┐
│                                                │
│  index.html                                    │
│  ├─ "Start" button (resumes AudioContext)       │
│  ├─ Frequency slider (20-2000 Hz)              │
│  └─ <script>                                   │
│       ├─ Create AudioContext (sampleRate: 48000)│
│       ├─ audioCtx.audioWorklet.addModule(...)   │
│       ├─ Create AudioWorkletNode                │
│       └─ slider.oninput → port.postMessage()    │
│                                                │
└────────────────┬───────────────────────────────┘
                 │ postMessage({ freq: 440 })
                 ▼
┌─ AudioWorklet Thread ──────────────────────────┐
│                                                │
│  processor.js                                  │
│  ├─ Imports MoonBit wasm-gc module             │
│  ├─ port.onmessage → update freq parameter     │
│  └─ process() called every 128 samples:        │
│       for i in 0..127:                         │
│         output[i] = wasmExports.tick(freq, sr) │
│                                                │
│  MoonBit wasm-gc module (moonbit_dsp.wasm)     │
│  └─ pub fn tick(freq, sample_rate) -> Double   │
│       └─ phase accumulator sine oscillator     │
│                                                │
└────────────────────────────────────────────────┘
```

---

## Project Structure

```
moonbit-dsp-step0/
├── moon.mod.json
├── src/
│   └── main/
│       ├── moon.pkg          ← Package config (new DSL format, replaces moon.pkg.json)
│       └── dsp.mbt           ← MoonBit DSP code
├── web/
│   ├── index.html            ← Main page with Start button + slider
│   └── processor.js          ← AudioWorkletProcessor
└── serve.sh                  ← Simple HTTP server script
```

> **NOTE on moon.pkg vs moon.pkg.json**: MoonBit has introduced a new `moon.pkg` configuration
> format (DSL syntax) to replace the old `moon.pkg.json` (JSON syntax). If a `moon.pkg` file
> exists in a package directory, MoonBit will use it as the configuration. You can auto-migrate
> old JSON files by running `NEW_MOON_PKG=1 moon fmt`. Both formats are currently supported,
> but `moon.pkg` is the recommended going forward. This instruction uses the **new `moon.pkg`
> format**. If your toolchain version does not support it yet, use the equivalent JSON shown
> in comments.

---

## Step-by-Step Implementation

### Phase 1: MoonBit Module

#### 1.1 Create MoonBit project

```bash
moon new moonbit-dsp-step0
cd moonbit-dsp-step0
```

Edit `moon.mod.json`:
```json
{
  "name": "moonbit-dsp-step0",
  "version": "0.0.1",
  "backends": ["wasm-gc"]
}
```

#### 1.2 Write the DSP code

Create `src/main/dsp.mbt`:

```moonbit
///|
/// Global mutable state for the oscillator.
/// This is intentionally simple - a single phase accumulator.
/// Using primitive Double avoids any GC allocation in the hot path.
let mut phase : Double = 0.0

///|
/// Generate one sample of a sine wave.
/// Called 48000 times per second from the AudioWorkletProcessor.
///
/// CRITICAL: This function must not allocate any heap objects.
/// Only uses Double arithmetic (stack-allocated / register).
///
/// Parameters:
/// - freq: oscillator frequency in Hz (e.g. 440.0)
/// - sample_rate: audio sample rate in Hz (e.g. 48000.0)
///
/// Returns: sample value in range [-1.0, 1.0]
pub fn tick(freq : Double, sample_rate : Double) -> Double {
  let two_pi = 6.283185307179586
  let out = @math.sin(phase * two_pi)
  phase = phase + freq / sample_rate
  // Wrap phase to avoid floating point precision loss over time
  if phase >= 1.0 {
    phase = phase - 1.0
  }
  out
}
```

Configure `src/main/moon.pkg` (new DSL format):

```
// moon.pkg — Package configuration for the DSP module
// Uses the new moon.pkg DSL syntax (replaces moon.pkg.json)

config {
  "is_main": true,
}

// Equivalent moon.pkg.json (if your toolchain doesn't support moon.pkg yet):
// {
//   "is-main": true,
//   "link": {
//     "wasm-gc": {
//       "exports": ["tick"]
//     }
//   }
// }
```

> **IMPORTANT — Exporting functions from wasm-gc**:
>
> The proven pattern for exporting MoonBit functions to JavaScript via wasm-gc is
> to configure the `exports` field under `link.wasm-gc` in the package config.
> A working example from the MoonBit blog (cmark library):
>
> ```json
> {
>   "link": {
>     "wasm-gc": {
>       "exports": ["render", "result_unwrap", "result_is_ok"],
>       "use-js-builtin-string": true
>     }
>   }
> }
> ```
>
> For our case we only export numeric functions (no strings), so `use-js-builtin-string`
> may not be needed. The minimal config is:
>
> ```json
> { "link": { "wasm-gc": { "exports": ["tick"] } } }
> ```
>
> In the new `moon.pkg` DSL, this would be expressed via the `options(...)` declaration.
> **Consult the latest docs** at https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html
> to confirm the exact syntax. The `moon.pkg` format supports all options from `moon.pkg.json`
> via `options(...)` blocks.
>
> If the `moon.pkg` DSL format is unclear, **fall back to `moon.pkg.json`** — both are
> supported and the JSON format is well-documented.
>
> **Fallback**: If wasm-gc export proves difficult, try `--target js` instead and import
> the generated JS module. The critical experiment is whether MoonBit-generated code runs
> in AudioWorkletGlobalScope, not which backend is used.

#### 1.3 Build

```bash
moon build --target wasm-gc
```

Locate the generated `.wasm` file. It will be somewhere under `target/wasm-gc/`. Copy or symlink it to `web/moonbit_dsp.wasm`.

#### 1.4 Verify the export

Use a quick Node.js or browser console check:

```javascript
const bytes = await fetch('moonbit_dsp.wasm').then(r => r.arrayBuffer());
const module = await WebAssembly.compile(bytes);
console.log(WebAssembly.Module.exports(module));
// Should show: [{ name: "tick", kind: "function" }, ...]
```

If `tick` is NOT in the exports list, the build configuration needs adjustment. See the IMPORTANT note above.

---

### Phase 2: AudioWorklet Integration

#### 2.1 Create `web/processor.js`

```javascript
// processor.js — runs in AudioWorkletGlobalScope

class MoonBitDspProcessor extends AudioWorkletProcessor {
  constructor(options) {
    super();
    this.freq = 440.0;
    this.ready = false;

    // Receive the compiled wasm module from the main thread
    // Pattern B from Chrome's AudioWorklet design patterns:
    // compile on main thread, transfer to worklet
    const wasmModule = options.processorOptions?.wasmModule;
    if (wasmModule) {
      this._initWasm(wasmModule);
    }

    // Listen for parameter changes
    this.port.onmessage = (e) => {
      if (e.data.type === 'set-freq') {
        this.freq = e.data.value;
      }
      if (e.data.type === 'init-wasm' && e.data.module) {
        this._initWasm(e.data.module);
      }
    };
  }

  async _initWasm(wasmModule) {
    try {
      // For wasm-gc modules, instantiation may require specific imports.
      // MoonBit wasm-gc typically needs:
      // - moonbit:ffi / make_closure (for closures passed to JS)
      // - spectest / print_char (for println)
      //
      // For our minimal case (pure numeric function), we may need
      // only minimal or empty imports. Adjust based on actual errors.
      //
      // PROVEN PATTERN from MoonBit blog (cmark example):
      //   const { instance } = await WebAssembly.instantiateStreaming(
      //     fetch("lib.wasm"), {},
      //     { builtins: ["js-string"], importedStringConstants: "_" }
      //   );
      // For numeric-only exports, the third argument may not be needed.

      const importObject = {
        // MoonBit runtime imports - adjust as needed based on build errors
        "spectest": {
          "print_char": (ch) => {} // no-op, we don't need printing
        },
        "moonbit:ffi": {
          "make_closure": (funcref, closure) => funcref.bind(null, closure)
        }
      };

      // Try instantiation. If it fails due to missing imports,
      // check the error message and add the required imports.
      const instance = await WebAssembly.instantiate(wasmModule, importObject);
      this.wasm = instance.exports;

      // Verify tick function exists
      if (typeof this.wasm.tick !== 'function') {
        console.error('tick function not found in wasm exports:', Object.keys(this.wasm));
        return;
      }

      this.ready = true;
      this.port.postMessage({ type: 'ready' });
      console.log('[MoonBitDsp] wasm module initialized, exports:', Object.keys(this.wasm));
    } catch (err) {
      console.error('[MoonBitDsp] wasm init failed:', err);
      this.port.postMessage({ type: 'error', message: err.message });
    }
  }

  process(inputs, outputs, parameters) {
    if (!this.ready) return true;

    const output = outputs[0];
    const channel = output[0]; // mono output, left channel
    const sampleRate = 48000.0; // matches AudioContext sampleRate

    for (let i = 0; i < channel.length; i++) {
      channel[i] = this.wasm.tick(this.freq, sampleRate) * 0.3; // -10dB headroom
    }

    // Copy to right channel if stereo
    if (output[1]) {
      output[1].set(channel);
    }

    return true; // keep processor alive
  }
}

registerProcessor('moonbit-dsp', MoonBitDspProcessor);
```

> **TROUBLESHOOTING GUIDE for wasm-gc in AudioWorklet**:
>
> **Problem**: `WebAssembly.instantiate` fails with "import not found"
> **Solution**: Check the error for the exact module/function name. Add it to `importObject`. MoonBit wasm-gc may require runtime support functions. List all required imports with:
> ```javascript
> WebAssembly.Module.imports(wasmModule).forEach(i => console.log(i));
> ```
>
> **Problem**: `tick` returns `undefined` or an externref instead of a number
> **Solution**: wasm-gc may wrap return values. Check if the function returns f64 directly or via externref. If the latter, you may need to use `--target wasm` (linear memory) instead of `--target wasm-gc`.
>
> **Problem**: Audio glitches / dropouts after a few seconds
> **Solution**: This likely means GC is collecting during process(). Check if the MoonBit code is accidentally allocating. Possible causes:
> - String operations in the hot path
> - Closure creation
> - Array creation (use FixedArray with pre-allocation instead)
> - Box/unbox of numeric types
>
> **Problem**: `audioWorklet.addModule()` fails
> **Solution**: Ensure the server sends correct MIME type for .js files and correct CORS headers. Use a proper HTTP server, not `file://`.
>
> **CRITICAL FALLBACK**: If wasm-gc proves incompatible with AudioWorkletGlobalScope (e.g., GC integration issues), switch to `--target js` and import the generated JS file instead. This is still a valid proof of concept — kabelsalat proved that JS in AudioWorklet achieves good DSP performance.

#### 2.2 Create `web/index.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>MoonBit DSP Step 0</title>
  <style>
    body {
      font-family: system-ui, sans-serif;
      max-width: 600px;
      margin: 40px auto;
      padding: 0 20px;
    }
    button {
      font-size: 1.2em;
      padding: 10px 24px;
      cursor: pointer;
    }
    .controls { margin-top: 20px; }
    label { display: block; margin: 10px 0; }
    input[type=range] { width: 100%; }
    #status {
      margin-top: 10px;
      padding: 8px;
      background: #f0f0f0;
      border-radius: 4px;
      font-size: 0.9em;
    }
    #status.error { background: #ffe0e0; }
    #status.ok { background: #e0ffe0; }
  </style>
</head>
<body>
  <h1>MoonBit DSP — Step 0</h1>
  <p>Sine oscillator running in MoonBit (wasm-gc) inside AudioWorklet.</p>

  <button id="startBtn">▶ Start</button>
  <button id="stopBtn" disabled>■ Stop</button>

  <div class="controls">
    <label>
      Frequency: <span id="freqDisplay">440</span> Hz
      <input type="range" id="freqSlider" min="20" max="2000" value="440" step="1">
    </label>
    <label>
      Volume: <span id="volDisplay">30</span>%
      <input type="range" id="volSlider" min="0" max="100" value="30" step="1">
    </label>
  </div>

  <div id="status">Ready. Click Start to begin.</div>

  <script>
    const startBtn = document.getElementById('startBtn');
    const stopBtn = document.getElementById('stopBtn');
    const freqSlider = document.getElementById('freqSlider');
    const freqDisplay = document.getElementById('freqDisplay');
    const volSlider = document.getElementById('volSlider');
    const volDisplay = document.getElementById('volDisplay');
    const status = document.getElementById('status');

    let audioCtx = null;
    let workletNode = null;
    let gainNode = null;

    function log(msg, isError = false) {
      status.textContent = msg;
      status.className = isError ? 'error' : 'ok';
      console.log('[main]', msg);
    }

    startBtn.addEventListener('click', async () => {
      try {
        log('Creating AudioContext...');
        audioCtx = new AudioContext({ sampleRate: 48000 });

        log('Loading AudioWorklet module...');
        await audioCtx.audioWorklet.addModule('processor.js');

        log('Compiling MoonBit wasm module...');
        // Fetch and compile on main thread (Pattern B)
        const wasmBytes = await fetch('moonbit_dsp.wasm').then(r => r.arrayBuffer());
        const wasmModule = await WebAssembly.compile(wasmBytes);

        // Inspect the module
        const exports = WebAssembly.Module.exports(wasmModule);
        const imports = WebAssembly.Module.imports(wasmModule);
        console.log('wasm exports:', exports);
        console.log('wasm imports:', imports);

        log('Creating AudioWorkletNode...');
        workletNode = new AudioWorkletNode(audioCtx, 'moonbit-dsp', {
          processorOptions: { wasmModule }
        });

        // Volume control via GainNode
        gainNode = audioCtx.createGain();
        gainNode.gain.value = volSlider.value / 100;
        workletNode.connect(gainNode).connect(audioCtx.destination);

        // Listen for messages from the processor
        workletNode.port.onmessage = (e) => {
          if (e.data.type === 'ready') {
            log('✓ MoonBit DSP is running!');
          }
          if (e.data.type === 'error') {
            log('Processor error: ' + e.data.message, true);
          }
        };

        // Resume context (required after user gesture)
        await audioCtx.resume();

        startBtn.disabled = true;
        stopBtn.disabled = false;

        // Send initial frequency
        workletNode.port.postMessage({
          type: 'set-freq',
          value: parseFloat(freqSlider.value)
        });

      } catch (err) {
        log('Error: ' + err.message, true);
        console.error(err);
      }
    });

    stopBtn.addEventListener('click', () => {
      if (audioCtx) {
        audioCtx.close();
        audioCtx = null;
        workletNode = null;
        gainNode = null;
        startBtn.disabled = false;
        stopBtn.disabled = true;
        log('Stopped.');
      }
    });

    freqSlider.addEventListener('input', () => {
      const freq = parseFloat(freqSlider.value);
      freqDisplay.textContent = freq;
      if (workletNode) {
        workletNode.port.postMessage({ type: 'set-freq', value: freq });
      }
    });

    volSlider.addEventListener('input', () => {
      const vol = parseFloat(volSlider.value);
      volDisplay.textContent = vol;
      if (gainNode) {
        gainNode.gain.value = vol / 100;
      }
    });
  </script>
</body>
</html>
```

---

### Phase 3: Serve and Test

#### 3.1 HTTP Server

AudioWorklet requires HTTPS or localhost. Create `serve.sh`:

```bash
#!/bin/bash
# Simple HTTP server for testing
# Requires: python3
cd web
python3 -m http.server 8080
```

Or use any static file server (e.g., `npx serve web`).

> **IMPORTANT**: Before serving, copy the built wasm file to the web directory:
> ```bash
> cp target/wasm-gc/release/build/main/main.wasm web/moonbit_dsp.wasm
> ```
> The exact path of the output wasm file depends on your project structure. Find it with:
> ```bash
> find target/ -name "*.wasm" -type f
> ```

#### 3.2 Verification Checklist

Open `http://localhost:8080` in Chrome (best wasm-gc support) and verify:

- [ ] Page loads without console errors
- [ ] Clicking "Start" produces a sine tone
- [ ] Moving the frequency slider changes the pitch in real time
- [ ] No audio glitches during 30 seconds of playback
- [ ] DevTools → Performance tab shows no GC events during audio playback
- [ ] DevTools → Console shows `wasm exports:` listing the `tick` function

#### 3.3 Known Issues and Workarounds

**If wasm-gc module cannot be instantiated in AudioWorkletGlobalScope:**

Some browsers may not support wasm-gc in worker contexts. Workaround:

```javascript
// In processor.js, instead of WebAssembly.instantiate with wasm-gc,
// use a plain wasm approach:
// Option A: Compile MoonBit with --target js, import as ES module
// Option B: Compile MoonBit with --target wasm (linear memory, non-GC)
// Option C: Inline the tick function as pure JS (defeats the purpose
//           but validates the AudioWorklet pipeline)
```

**If MoonBit's wasm-gc output requires imports you cannot provide:**

List all imports and provide stubs:

```javascript
const imports = WebAssembly.Module.imports(wasmModule);
const importObject = {};
for (const imp of imports) {
  if (!importObject[imp.module]) importObject[imp.module] = {};
  if (imp.kind === 'function') {
    importObject[imp.module][imp.name] = (...args) => {
      console.warn(`[stub] ${imp.module}.${imp.name}(`, args, ')');
    };
  }
}
```

---

## Decision Points

After completing the prototype, record answers to these questions:

1. **Does wasm-gc work in AudioWorklet?**
   - Yes → Continue with wasm-gc for the DSP engine
   - No → Use JS backend for AudioWorklet, wasm-gc for main thread

2. **Is GC a problem during audio processing?**
   - No glitches → MoonBit's GC is safe for numeric-only DSP
   - Occasional glitches → Need to audit for hidden allocations
   - Frequent glitches → Must use linear memory wasm or JS backend

3. **How are function exports handled?**
   - Direct f64 return → Clean FFI, proceed as planned
   - externref wrapping → Need unwrapping layer, adds complexity
   - Not exportable → Need different FFI strategy

4. **What imports does the wasm-gc module require?**
   - None or minimal → Easy to deploy
   - MoonBit runtime functions → Need to bundle runtime in AudioWorklet
   - Extensive JS interop → May need to rethink the boundary

Record these findings in a `RESULTS.md` file for future reference.

---

## Context for the AI

This prototype is Step 0 of a larger project to build a DSP audio engine in MoonBit. The eventual architecture includes:

- A pattern engine (Strudel/TidalCycles-inspired) for temporal structure
- A DSP engine with Finally Tagless design (DspSym trait) for signal processing
- An incremental computation layer (incr library) for efficient updates
- Multiple compilation targets: browser (WebAudio), native (CLAP/VST)

None of that matters now. The only question is: **can MoonBit generate audio samples in a browser AudioWorklet?**

The developer (Koji) has deep expertise in MoonBit, type systems, and compiler design, but this is the first time combining MoonBit with WebAudio. Prioritize clear error reporting and fallback paths over elegant code.

## Reference

- MoonBit FFI docs: https://docs.moonbitlang.com/en/latest/language/ffi.html
- MoonBit package config (moon.pkg / moon.pkg.json): https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html
- MoonBit packages overview: https://docs.moonbitlang.com/en/latest/language/packages.html
- MoonBit wasm-gc + JS string builtins blog: https://www.moonbitlang.com/blog/js-string-builtins
- MoonBit consuming wasm from JS blog (cmark example): https://www.moonbitlang.com/blog/call-wasm-from-js
- Chrome AudioWorklet design patterns: https://developer.chrome.com/blog/audio-worklet-design-pattern
- MDN AudioWorklet guide: https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Using_AudioWorklet
- kabelsalat (reference implementation in JS): https://codeberg.org/froos/kabelsalat
- kabelsalat internals: https://kabel.salat.dev/internals/
- MoonBit monthly updates (moon.pkg introduced in Vol.07): https://www.moonbitlang.com/updates
