# Phase 1 Long-Stretch Task: AudioBuffer Wrapper

This document is the execution brief for the next long autonomous coding run.
It follows the oscillator primitive work and focuses on the next reusable DSP
building block: an audio buffer abstraction.

## Goal

Introduce an `AudioBuffer` wrapper around `FixedArray[Double]`, refactor the
oscillator to process through that wrapper, and add tests that establish the
buffer abstraction as the standard Phase 1 data path for sample blocks.

## Source Of Truth

- `AGENTS.md`
- `docs/salat-engine-blueprint.md`
- `docs/salat-engine-technical-reference.md`
- `phase1-oscillator-long-stretch.md`
- `RESULTS.md`

## Why This Task

The project now has an explicit oscillator primitive, but its block-processing
API still exposes raw `FixedArray[Double]`. The blueprint already calls for a
`buffer.mbt` abstraction, and Phase 1 will become easier to extend if the
project standardizes the block container before filters, envelopes, or delay
arrive.

This task is narrower than “continue Phase 1.” It only establishes the buffer
surface and migrates the oscillator to it.

## Scope

In scope:

- Add a buffer abstraction file, for example `buffer.mbt`
- Wrap `FixedArray[Double]` in a project-specific `AudioBuffer` type
- Provide a minimal, useful API for buffer creation and mutation
- Refactor oscillator block processing to use `AudioBuffer`
- Add tests for the buffer type and the refactored oscillator path
- Keep the browser demo operational

Out of scope:

- Filters, envelopes, delay, mix, graph compilation
- Multichannel abstractions
- Shared buffer pools
- Browser UI redesign
- Changing the confirmed `tick`/`reset_phase` browser export shape unless
  strictly necessary

## Success Criteria

- There is a public `AudioBuffer` type in the package API
- `AudioBuffer` wraps `FixedArray[Double]` rather than replacing it with a more
  complex storage design
- Oscillator block processing uses `AudioBuffer`
- There are passing tests for buffer initialization and basic mutation/fill
- `moon check` passes
- `moon test` passes
- `moon info` reflects the intended public API
- `moon build --target wasm-gc --release` still passes

## Design Constraints

- No allocation inside audio-rate processing loops
- Keep the wrapper thin and explicit
- Do not overdesign toward future graph compilation yet
- Preserve direct one-sample oscillator `tick` for the browser demo path
- Prefer API names that will still make sense for filter, envelope, and delay
  processors later

## Proposed Work Plan

1. Add `buffer.mbt` with `AudioBuffer`
2. Implement a minimal API:
   - constructor/new
   - length
   - fill
   - element access helpers if useful
3. Refactor `Oscillator::process` to accept `AudioBuffer`
4. Update oscillator tests to use `AudioBuffer`
5. Add direct buffer tests
6. Run `moon check`, `moon test`, `moon info`, `moon fmt`,
   `moon build --target wasm-gc --release`

## Suggested API Direction

Preferred shape:

- `type AudioBuffer`
- `AudioBuffer::new(size, init?)`
- `AudioBuffer::length`
- `AudioBuffer::fill`
- indexed get/set support or equivalent methods

The wrapper should remain cheap enough that processors can operate on it
without introducing hidden allocations or ownership complexity.

## Verification

Run at minimum:

- `moon fmt`
- `moon check`
- `moon test`
- `moon info`
- `moon build --target wasm-gc --release`

Optional browser smoke test if demo wiring changes:

- `./serve.sh`
- open the printed URL
- click `Start Audio`
- confirm audible output or at least live meter activity

## Autonomy Policy

During the long-stretch run:

- Continue without asking about minor API naming choices
- Prefer the smallest coherent wrapper that satisfies current Phase 1 needs
- Stop only for:
  - contradictory source docs
  - destructive actions
  - missing external prerequisites
  - a public API decision that would obviously constrain later DSP blocks

## Deliverables

- `AudioBuffer` implementation
- oscillator refactor onto that abstraction
- tests
- updated generated interface files
- concise summary of what changed and which Phase 1 primitive should come next
