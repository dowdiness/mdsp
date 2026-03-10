# Step 0 Results

This file records the outcome of the Phase 0 MoonBit `wasm-gc` AudioWorklet
experiment.

## Current Status

- MoonBit exports `tick` and `reset_phase` from the root package for the
  `wasm-gc` and `js` backends.
- `web/index.html` and `web/processor.js` provide the browser demo scaffold.
- `serve.sh` copies the built `.wasm` into `web/` and starts a local server.
- Browser validation is complete for the current prototype.

## Confirmed Outcome

Confirmed on 2026-03-10:

- The page loads in the browser and the `Start Audio` button successfully
  unlocks `AudioContext`.
- `processor.js` loads and `moonbit_dsp.wasm` instantiates inside
  `AudioWorkletProcessor`.
- The exported MoonBit functions are visible in the browser:
  `tick`, `reset_phase`, and `_start`.
- The page reports `Audio running`.
- The live signal meter shows non-zero output while the app is running.
- Audible sound is confirmed manually from the current app.
- The frequency slider updates pitch while the demo is running.

This means the core Phase 0 viability question has a positive answer for the
current setup: MoonBit `wasm-gc` can generate audible audio in a browser
`AudioWorklet`.

## How To Run

1. `moon build --target wasm-gc --release`
2. `./serve.sh`
3. Open the URL printed by `serve.sh` (for example `http://127.0.0.1:8080` or
   the next free port if `8080` is occupied)
4. Click `Start Audio`
5. Move the frequency slider and listen for smooth pitch change
6. Watch the signal meter if you need visual confirmation that samples are
   flowing

## Verified Checks

- The page loads without blocking initialization errors
- The processor reports `ready`
- `tick` appears in the wasm exports logged in the browser console
- Audible sine-wave output is confirmed manually
- The frequency slider changes pitch in real time
- The signal meter shows non-zero output while running

## Remaining Checks

- Run a dedicated 30-second glitch test and record whether playback stays clean
- Inspect browser performance tooling for any GC-related spikes during playback
- Test one or two additional browsers after the Chrome-path prototype is stable

## Open Questions

- Does the generated `wasm-gc` module continue to instantiate in other target
  browsers without additional imports beyond the current stubs?
- Does the browser show any GC-related glitches during extended sustained
  playback?
- Is the current `wasm-gc` path viable enough to keep as the default browser
  backend, or should the project prefer the `js` backend for AudioWorklet?
