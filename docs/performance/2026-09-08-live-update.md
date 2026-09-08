# Performance snapshot — 2026-09-08: Browser live updates

The browser playback host prepares routed pattern/song snapshots and commits
all routes at the next render block. Ordinary edits preserve transport and
existing voices. Explicit restart keeps the legacy reset behavior.

## Environment and command

- CPU: AMD Ryzen 7 6800H with Radeon Graphics.
- OS: Linux 6.18.33.2-microsoft-standard-WSL2.
- MoonBit: moon 0.1.20260907 (7aabba5).
- Base: 737dbf1, with the live-update working tree changes.
- Command: `NEW_MOON_MOD=0 moon bench`.
- Result: 59 benchmark groups passed, zero failures.
- [Raw benchmark results](2026-09-08-live-update-benchmarks.txt).

## Selected results

| Case | Mean |
|---|---:|
| Minimal voice, 128 samples | 3.50 µs |
| Dispatch eight jux events | 52.34 µs |
| Render eight panned jux voices | 99.76 µs |
| Scheduler process block, jux/rev | 38.70 µs |

These are existing suite cases, not measurements of the new browser preparation
or commit path. There is no paired baseline run. Browser verification briefly
ran concurrently, so this snapshot is a suite-completion record rather than a
controlled performance comparison. It does not establish an improvement or a
regression in live-update latency.

## Structural cost and limits

Each accepted edit reparses text, routes the result and lowers one snapshot per
route. Only the latest prepared update remains pending. At the next block,
all route snapshots are queued before any route renders. Following blocks use
the existing snapshot scheduler path.

Parsing and preparation remain in the AudioWorklet owner and allocate. The
change preserves musical state across edits; it does not establish freedom
from GC pauses or audio underruns. Measuring preparation and render deadlines
with representative long songs is required before claiming real-time safety or
choosing a worker/transport redesign.

## Functional evidence

- Playback-host tests: 10 passed, including five new update tests covering
  transport, sounding audio, invalid edits, coalescing, tempo/layout admission,
  and explicit restart.
- Normal live UI: 26 Playwright tests passed with actual WASM/AudioWorklet.
  The update test also passed after extension to song updates and layout
  rejection followed by explicit restart.
- Full JS suite: 1,066 tests, 1,062 passed. Four existing feedback-graph property
  tests fail at `graph/graph_property_test.mbt` lines 548, 561, 987 and 1125,
  in the `compile_mono` unwrap path. The same four failures were observed on
  the unmodified main baseline; they are not attributed to live updates.

At unchanged tempo, sample and musical position continue across updates.
Changing embedded song BPM or song layout requires explicit restart. The
separate global BPM control retains its existing behavior and does not yet
provide phase-continuous tempo changes.
