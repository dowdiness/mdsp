# Unified pattern lowering — 2026-09-09

Source: local changes on PR #235 head `1146159`, together with the named-pattern
contract-test cleanup. Toolchain: moon 0.1.20260907 (7aabba5).

Each document subtree now compiles once into playback and provenance views.
Both views use one dependency-keyed cache. The separate provenance memo and
compilation-time revision traversal are removed. Public interfaces and runtime
query semantics remain unchanged; playback does not construct source paths.

The dependency token includes every reachable node generation, including
reference targets. Replacing a node assigns a fresh generation. The public
revision value therefore does not provide additional cache discrimination.
Document-local traversal memos do not cross reference scopes.

The cache now retains both views until cleared or released. This trades
persistent provenance storage for removing reconstruction on cache hits; no
heap-size improvement is claimed. Arbitrary transformation callbacks retain
the existing conservative provenance rule for reachable children.

## Correctness evidence

- JS, wasm-gc and native full suites: 1,086 tests passed per target.
- Named-versus-inline Light Orbit equivalence remains covered across 240 cycles
  and the two cycles after the ending.
- Divergent definition revisions preserve independent playback and source results.
- A shared-definition test observes transformation construction while comparing
  complete playback and sourced events. It also repeats lowering with the same
  cache. The original implementation fails with two constructions instead of
  one; the unified implementation passes.
- Public, architecture, incremental-import, graph-facade and browser ABI checks pass.
- Release wasm-gc and TypeScript/Vite builds pass. Public interface files have no intentional changes.
- Live UI/AudioWorklet: 30 tests passed.
- Browser/demo/controller/audio comparison: 25 tests passed on the initial
  attempt; the scheduler-start test passed on its second retry. Both earlier
  attempts timed out after five seconds waiting for `#patternStatus` to show
  `Pattern updated` (it remained empty). This is not evidence of a clean
  first-attempt browser run, and its cause is not established by the retry.
  The same test subsequently passed three isolated repetitions with one worker
  and retries disabled. The initial timeout remains recorded, not classified
  as resolved or attributed to a specific cause.

The baseline compiler warnings remain; this is not a warning-cleanup change.

## Benchmark snapshot

`NEW_MOON_MOD=0 moon bench --release` passed all 59 existing benchmark groups.
[Raw results](2026-09-09-unified-pattern-lowering-benchmarks.txt) were collected
after the MoonBit tests and boundary checks, before the browser tests. No other
validation command was deliberately run concurrently with the measurement.
This is an environment-specific snapshot, not a controlled speed comparison
or a dedicated measurement of reference lowering or heap retention.
