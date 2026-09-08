# Named pattern validation — 2026-09-09

Base: merged playback API PR #233 (`3baacc7`). This change adds ordered,
immutable pattern definitions through shared expression syntax and name resolution.
References preserve document structure and use dependency-aware lowering caches. No audio
rendering loop or scheduling policy changes.

`NEW_MOON_MOD=0 moon bench --release` completed all 59 existing benchmark
groups. [Raw results](2026-09-09-named-patterns-benchmarks.txt) are a local
snapshot, not a controlled before/after speed comparison or an AudioWorklet
deadline guarantee. This run overlapped other validation work.

Validation also passed:

- JS, wasm-gc, native: 1,084 tests each.
- Live UI/AudioWorklet: 30 tests, including named song edits, rejection of an
  undefined reference while retaining the applied score, and name completion.
- Browser/demo/controller/audio comparison: 26 tests.
- Release WASM and TypeScript/Vite builds.
- Public, architecture, incr-import, graph-facade and browser ABI boundaries.

The compiler reports pre-existing deprecation warnings (511 on the baseline default check); this is not a warning-free toolchain migration.

Reference tests also verify definition inspection, separate use-site source paths,
compiling a shared definition once, and invalidation for divergent revisions
that retain parent identities. Runtime and document paths report the same
original position for unresolved references.

The Light Orbit test compares the named and inline versions over 484 half-cycle
queries, covering the entire 240-cycle song and two cycles after its end.
It compares event whole/part spans and every control value, including the
existing deterministic thinning. This establishes musical event equivalence,
not physical-output or listening equivalence.

The additional AudioWorklet measurements are preserved separately in PR #234;
their recorded source revision and environment remain unchanged.

The small existing mini parse benchmarks observed additional preparation cost:
`s_rev` 3.48 → 4.04 µs, `s_fast` 3.76 → 4.90 µs, and `stack_rev`
4.11 → 5.45 µs compared with the recorded pre-refactor run at `6a952ba`.
The shared syntax and resolved expression representations add preparation work;
these separate runs do not establish an exact slowdown factor. This change
prioritizes inspectable references and one grammar over a speed claim. No
runtime name resolution or audio rendering traversal is added.
