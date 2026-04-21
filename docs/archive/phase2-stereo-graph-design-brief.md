# Phase 2 Stereo Graph Design Brief

This document defines the first stereo-graph design for `mdsp`.

It is not the full multichannel design. The goal is to solve stereo-graph
semantics first in a way that can later generalize to wider channel counts.

## Goal

Introduce a clear Phase 2 stereo-graph model that:

- preserves the current mono compiled-graph path
- keeps one `DspNode` authoring language
- defines how `Pan` enters the graph
- defines mono-to-stereo and stereo-to-stereo connection rules
- defines the first stereo graph output shape
- avoids premature full multichannel complexity

## Source Of Truth

- `AGENTS.md`
- `docs/salat-engine-blueprint.md`
- `docs/salat-engine-technical-reference.md`
- `pan.mbt`
- `graph.mbt`
- `integration_test.mbt`

## Problem

The current compiled graph is explicitly mono:

- every node writes one `AudioBuffer`
- `Output` is mono
- `Pan` exists only as a standalone Phase 1 primitive
- the graph runtime has no channel-shape semantics

This blocks the first real stereo graph path even though the primitive layer
already has mono-to-stereo pan behavior.

## Design Decision

Use a channel-explicit stereo design first, not a generic multichannel system.

That means:

- the graph model distinguishes mono and stereo shapes explicitly
- `Pan` is the first graph node that changes channel shape
- the first stereo slice is terminal stereo only
- stereo support is intentionally limited to left/right output, not arbitrary
  `N`-channel routing

This is the smallest design that solves the real Phase 2 stereo problem without
locking the project into a premature multichannel abstraction.

## Proposed Semantics

### 1. Channel Shapes

Define two logical graph signal shapes:

- `Mono`
- `Stereo`

For the first stereo slice, every graph node has one of these fixed shapes.

Examples:

- `Constant`, `Oscillator`, `Noise`, `Adsr`, `Biquad`, `Delay`, `Gain`,
  `Clip`:
  - `Mono -> Mono`
- `Mul`, `Mix`:
  - `Mono + Mono -> Mono`
- `Pan`:
  - `Mono -> Stereo`
- `StereoOutput`:
  - `Stereo -> Output`
- stereo output:
  - terminal only in the first slice

Do not add generic `N -> N` nodes in this slice.

### 2. Connection Rules

Use strict connection rules at compile time:

- `Mono` output may connect to `Mono` input
- `Stereo` output may connect to `Stereo` input
- `Mono -> Stereo` implicit duplication is rejected
- `Stereo -> Mono` implicit downmix is rejected

Why strict rules first:

- avoids hidden channel expansion semantics
- keeps compile errors understandable
- avoids accidental policy choices that are hard to undo later

If the user wants `Mono -> Stereo`, they must use an explicit node such as
`Pan`.

If the user wants `Stereo -> Mono` later, that should be a dedicated node such
as `StereoMixDown`, not an implicit graph rule.

For the first stereo slice, no node may appear after `Pan` except
`StereoOutput`.

### 3. `Pan` in the Graph

`Pan` becomes the first channel-shape-changing graph node.

Suggested node form:

```moonbit
DspNode::pan(input, position)
```

Semantics:

- input must be `Mono`
- output shape is `Stereo`
- `position` remains the current equal-power `[-1.0, 1.0]` control
- invalid position handling should match the standalone `Pan` primitive

Runtime control:

- if `Pan` is made graph-dynamic, its position should fit the existing
  `GraphControl::set_param(...)` model
- if not, keep it fixed-parameter in the first stereo slice

In the first stereo slice, `Pan` is terminal stereo only:

```text
Mono graph -> Pan -> StereoOutput
```

Stereo post-processing is explicitly deferred.

### 4. Stereo Output Shape

Do not overload the current mono `CompiledDsp::process(context, output)` API.

Instead, introduce an explicit stereo compiled-graph path, for example:

- a separate `CompiledStereoDsp`
- or a stereo-specific process method that writes two buffers

Preferred direction:

- keep the current mono `CompiledDsp` unchanged
- keep the existing `DspNode` authoring type
- add shape inference/validation on that graph
- add a dedicated `CompiledStereoDsp` output type

Reason:

- avoids weakening the simple mono path
- makes channel shape visible in public API
- keeps tests and performance assumptions clearer
- avoids inventing a separate stereo node language too early

### 5. Buffer Layout

For the first stereo slice, prefer planar buffers:

- one `AudioBuffer` for left
- one `AudioBuffer` for right

Avoid interleaved internal graph buffers in this phase.

Reason:

- matches the existing `Pan` primitive
- keeps mono code reusable
- avoids introducing a new low-level storage abstraction at the same time as
  graph channel semantics

## Recommended Implementation Strategy

### Option A: Separate Stereo Graph Type

Keep one `DspNode` graph language, but introduce a new stereo compiled graph
type.

Pros:

- cleanest semantics
- no ambiguity in process/output shape
- easier to review and test
- avoids splitting authoring into separate mono and stereo node languages

Cons:

- some duplicated compile/process logic

### Option B: One Graph Type with Shape-Aware Output

Keep one compiled graph type, but allow mono or stereo output methods.

Pros:

- less duplicated compile pipeline

Cons:

- more internal complexity now
- easier to blur mono/stereo semantics

Recommendation:

- start with Option A if implementation begins soon
- if code sharing becomes painful, refactor later around a shared internal graph
  compiler core

## Explicit Non-Goals

Not in scope for the first stereo-graph slice:

- full multichannel expansion
- implicit broadcasting or downmix rules
- surround or arbitrary bus counts
- stereo effect node set beyond what is needed to prove the model
- stereo post-processing after `Pan`
- graph hot-swap redesign
- sample-accurate control events

## Suggested First Stereo Slice

1. Add graph-level shape inference/checking on `DspNode`
2. Add graph `Pan`
3. Add `StereoOutput`
4. Add `CompiledStereoDsp`
5. Compile and run one stereo graph:
   - `Oscillator -> Gain -> Pan -> StereoOutput`
6. Add integration coverage for:
   - hard left
   - center
   - hard right
   - invalid shape rejection

## Success Criteria

- The stereo graph model is explicit and documented
- `Pan` is the first graph node that changes shape from mono to stereo
- Stereo is terminal-only in the first slice: `Pan -> StereoOutput`
- Invalid mono/stereo connections are rejected at compile time
- A compiled stereo graph can render separate left/right buffers
- The current mono graph path remains unchanged

## Open Questions

- Should `StereoOutput` be one dedicated node kind or two output nodes with a
  compile-time pairing rule?
- Should `Pan` position be fixed-parameter in the first slice or immediately
  support `GraphControl::set_param(...)`?
- Should shape inference live directly in the existing `DspNode` compiler, or
  in a small shared analysis pass used by both `CompiledDsp` and
  `CompiledStereoDsp`?

## Recommendation

Do not jump to full multichannel support yet.

Solve stereo graph semantics first with:

- explicit `Mono` / `Stereo` graph shapes
- strict compile-time connection rules
- one `DspNode` authoring language
- planar left/right outputs
- `Pan` as the first channel-shape-changing node
- a dedicated `CompiledStereoDsp`
- terminal stereo only: `Pan -> StereoOutput`

If that works cleanly, generalize later toward multichannel from a proven stereo
model instead of guessing a generic abstraction now.
