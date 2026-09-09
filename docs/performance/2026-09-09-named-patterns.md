# Named patterns — validation, 2026-09-09

Source: PR #235, `e0f0c63`. Toolchain: moon 0.1.20260907 (7aabba5).
The language and compilation contract is documented in
[the feature plan](../plans/2026-09-09-named-patterns.md).

## Evidence

| Check | Result |
| --- | --- |
| MoonBit full suites: JS, wasm-gc, native | 1,086 passed per target |
| Live UI/AudioWorklet | 30 passed |
| Browser/demo/controller/audio comparison | Latest CI: 26 passed without retries |
| Release WASM and TypeScript/Vite builds | Passed |
| Public, architecture, incremental-import, graph-facade and browser ABI checks | Passed |
| Existing benchmark suite | 59 groups passed |

The contract tests cover named-versus-inline event equivalence, independent
use-site transformations, scope and diagnostics, source paths, immutable old
snapshots, and cache separation for divergent definitions. Light Orbit is
compared over 484 half-cycle queries: the entire 240-cycle score and its ending.
The shared-construction test fails with the previous compiler (two constructions)
and passes with the unified compiler (one), including repeated cached lowering.

The local browser run initially timed out twice waiting five seconds for
`#patternStatus` to show `Pattern updated`; the scheduler-start test passed on
its second retry. Three subsequent isolated runs with retries disabled passed.
[The latest CI browser run](https://github.com/dowdiness/moondsp/actions/runs/34298879562/job/102301352585)
passed all 26 tests. The local timeout's cause remains unestablished.

## Measurement limits

[Raw benchmark results](2026-09-09-named-patterns-benchmarks.txt) come from
`NEW_MOON_MOD=0 moon bench --release`, after the MoonBit and boundary checks and
before browser validation. They are an environment-specific snapshot, not a
controlled speed comparison, a reference-lowering benchmark, or a real-time
deadline guarantee. Existing compiler deprecation warnings remain.

The cache retains playback and provenance together until cleared or released;
heap retention has not been measured. Event equivalence does not establish
physical-output or listening equivalence. Separate AudioWorklet measurements
and their reproduction tools belong to PR #234, not this feature's test setup.
