# Named pattern validation — 2026-09-09

Base: merged playback API PR #233 (`3baacc7`). This change adds ordered,
immutable pattern definitions to the existing preparation parser. No audio
rendering loop or scheduling policy changes.

`NEW_MOON_MOD=0 moon bench --release` completed all 59 existing benchmark
groups. [Raw results](2026-09-09-named-patterns-benchmarks.txt) are a local
snapshot, not a controlled before/after speed comparison or an AudioWorklet
deadline guarantee. This run overlapped other validation work.

Validation also passed:

- JS, wasm-gc, native: 1,078 tests each.
- Live UI/AudioWorklet: 30 tests, including named song edits, rejection of an
  undefined reference while retaining the applied score, and name completion.
- Browser/demo/controller/audio comparison: 26 tests.
- Release WASM and TypeScript/Vite builds.
- Public, architecture, incr-import, graph-facade and browser ABI boundaries.

The compiler reports pre-existing deprecation warnings (511 on both the initial
and final default check); this is not a warning-free toolchain migration.

The Light Orbit test compares the named and inline versions over 484 half-cycle
queries, covering the entire 240-cycle song and two cycles after its end.
It compares event whole/part spans and every control value, including the
existing deterministic thinning. This establishes musical event equivalence,
not physical-output or listening equivalence.

The additional AudioWorklet measurements are preserved separately in PR #234;
their recorded source revision and environment remain unchanged.
