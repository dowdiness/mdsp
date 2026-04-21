# Phase 1 Long-Stretch Task: Oscillator Primitive

This document is the execution brief for the next long autonomous coding run.
It turns the broad Phase 1 roadmap into one concrete, testable task.

## Goal

Replace the current global-phase Step 0 oscillator export with a proper
Phase 1-ready oscillator primitive that has explicit state, buffer-based
processing, and tests, while keeping the browser demo working.

## Source Of Truth

- `AGENTS.md`
- `docs/salat-engine-blueprint.md`
- `docs/salat-engine-technical-reference.md`
- `RESULTS.md`

## Why This Task

The Step 0 prototype proved that MoonBit `wasm-gc` can produce audible audio
through `AudioWorklet`. The next highest-value step is to turn that prototype
into the first reusable DSP primitive instead of building more features on top
of global mutable demo code.

This task is intentionally narrower than “do Phase 1.” It focuses on the first
primitive only: oscillator state and processing shape.

## Scope

In scope:

- Introduce a dedicated oscillator implementation in MoonBit
- Make oscillator state explicit instead of relying on a global phase variable
- Add buffer-based processing for render-quantum-sized output
- Add tests for stable oscillator behavior
- Keep the browser demo operational, adapting it to the new API if needed

Out of scope:

- Filters, envelopes, delay, mixing, graph compilation
- Pattern engine work
- SharedArrayBuffer or low-latency control transport
- UI redesign beyond what is required to preserve the demo
- Broad architecture refactors unrelated to the oscillator primitive

## Success Criteria

- There is a reusable oscillator type or API in MoonBit with explicit state
- There is a buffer-oriented processing function suitable for 128-sample blocks
- `moon check` passes
- `moon test` contains real oscillator tests and passes
- The browser demo still builds and runs against the new oscillator path
- Public API changes are reflected in `.mbti` files and are intentional

## Design Constraints

- No allocation in audio-rate code paths
- Prefer `FixedArray[Double]` for audio buffers
- Keep phase-wrapping numerically simple and explicit
- Guard invalid inputs that could poison oscillator state
- Preserve the confirmed Step 0 browser viability while refactoring internals

## Proposed Work Plan

1. Add a focused oscillator implementation file, for example `osc.mbt`
2. Define explicit oscillator state
3. Add one-sample and buffer-based processing entry points
4. Refactor current exported demo hooks to use the oscillator implementation
5. Add tests:
   - reset behavior
   - output range
   - phase continuity across consecutive calls
   - non-positive sample-rate handling
6. Run verification and inspect `.mbti` output

## Suggested API Direction

This is not a strict required API, but it is the preferred shape:

- `type Oscillator`
- constructor for initial state
- `reset`
- one-sample `tick`
- buffer `process` for `FixedArray[Double]`

The browser demo can keep a minimal exported wrapper if direct stateful objects
are awkward across the JS boundary.

## Verification

Run at minimum:

- `moon check`
- `moon test`
- `moon info`
- `moon fmt`
- `moon build --target wasm-gc --release`

If the browser demo wiring changes materially, also run:

- `./serve.sh`
- browser smoke test: page loads, Start works, signal meter moves

## Autonomy Policy

During the long-stretch run:

- Continue without asking about routine implementation details
- Prefer the smallest coherent design that satisfies the criteria
- Stop only for:
  - contradictory source docs
  - destructive actions not already implied
  - missing external prerequisites
  - major public API tradeoffs that clearly affect later phases

## Deliverables

- oscillator implementation
- tests
- any needed demo adaptation
- updated generated interface files
- concise final summary of what changed, what was verified, and what Phase 1
  work should come next
