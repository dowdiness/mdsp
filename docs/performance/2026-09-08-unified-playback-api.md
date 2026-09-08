# Unified playback API measurement — 2026-09-08

## Workload and method

The production browser WASM runs in a Chromium page on Linux. This measures
preparation and rendering separately; it does not measure AudioWorklet deadline
misses. The synthetic score has 12 sections, 240 cycles and 2,842 characters,
with different melodic periods, chords, bass, drums and deterministic thinning.
It resembles the orbit composition's structure but is not its exact score.

Run `node scripts/measure-playback-api.cjs http://127.0.0.1:5181` against a built
live preview after a release WASM build and asset sync. The script records its
workload and browser version in [the raw result](2026-09-08-unified-playback-api.json).
This run used HeadlessChrome 145.0.7632.6, 48 kHz and 128 samples per block.

After 10 warm-up preparations, 60 iterations each prepare and apply a score,
render the commit block, then render 750 ordinary blocks. Transport advances
through 240.325 cycles, covering every section and the score end. A separate
60-iteration loop measures restarting the applied snapshot. Input character
transfer and the apply/restart queue calls are outside these timings.

## Results

| Operation | Mean (ms) | p50 (ms) | p95 (ms) | Maximum (ms) |
|---|---:|---:|---:|---:|
| Preparation | 0.718 | 0.500 | 3.300 | 4.800 |
| Commit and render | 0.172 | 0.200 | 0.300 | 0.900 |
| Restart and render | 0.147 | 0.100 | 0.300 | 0.300 |
| Ordinary render, 750-block batch means | 0.134 | 0.126 | 0.175 | 0.209 |

The ordinary-render row is a distribution of batch means, **not per-block
latency percentiles**. Short individual measurements are limited by browser
timer resolution. This is one run without a paired baseline; it establishes
neither a speedup nor a regression relative to the previous API.

## Interpretation

Preparation p95 exceeds the 2.667 ms audio-block budget. Preparation still runs
in the audio owner and allocates memory, so this implementation does not establish
glitch-free live editing. Page-local timing also cannot establish scheduling or
GC behavior in an AudioWorklet. The separate API makes preparation ownership
explicit, but does not by itself move that work off the audio thread.

The next performance investigation should measure actual AudioWorklet deadline
misses during preparation, then evaluate an off-thread, transferable preparation
representation or bounded preparation against those results. Snapshots contain
functions and cannot simply be posted to a Worker. That investigation is a
separate task from the playback API unification.

Correctness evidence is provided by state-transition tests, real-WASM protocol
tests and UI/AudioWorklet integration tests; timing results do not replace them.

## Existing benchmark suite

`NEW_MOON_MOD=0 moon bench` passed all 59 groups. See the
[raw suite results](2026-09-08-unified-playback-benchmarks.txt). This run used
MoonBit 0.1.20260907 on an AMD Ryzen 7 6800H, Linux WSL2. No browser tests or
other task benchmarks were launched during this suite run; the machine was
not reserved exclusively for measurement. These existing cases do not measure
the browser preparation boundary, and there is no paired baseline comparison.
