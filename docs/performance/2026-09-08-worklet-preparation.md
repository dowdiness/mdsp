# AudioWorklet preparation measurements — 2026-09-08

## Decision

These runs found no output underruns associated with preparing or applying a
score during playback. They do not justify requiring a Worker migration.
Keep preparation and application separate, and revisit the execution model if
real output measurements show a problem.

This is a record of one experiment, not a maintained benchmark or a release gate.
It adds no runtime code, test setup, dependencies, or CI jobs.

## Evidence

All runs used release wasm-gc from engine commit
[`d7a6975`](https://github.com/dowdiness/moondsp/commit/d7a69754f91e04bc98afa190bdc9835212267272),
48 kHz AudioContexts, 128-sample blocks, and interactive latency.
Each data file records the browser, source commit, and WASM SHA-256.

| Data | Conditions and observations |
| --- | --- |
| [Preparation comparison](2026-09-08-worklet-preparation.json) | HeadlessChrome 145 on Linux/WSL2; experimental output statistics enabled. Three rounds of baseline, prepare-only, apply-score, and a known 100 ms stall. Baseline, preparation, and application reported zero underruns. Stall rounds reported 29, 32, and 33 events. |
| [Playback trials](2026-09-08-playback-acceptance.json) | Headed Chrome 148, unmuted, through WSLg RDPSink. Three initial-play/edit trials, three baseline/edit pairs under four busy Web Workers, and one full-score trial. All reported zero underruns. |
| [Output calibration](2026-09-08-playback-acceptance-calibration.json) | Same headed browser and output path. Known 100 ms stalls produced 138 underrun events and 1,604.25 ms of reported missing output; baseline, preparation, and application reported zero. |

The preparation comparison alternated two synthetic 12-section, 240-cycle
scores. Each round sent 24 operations at 250 ms intervals after two seconds of
warmup, then waited 1.5 seconds for output statistics. It played only the opening
of the score. Prepare-only discarded the prepared token; apply-score continued
playback. Round order rotated. Recorded preparation p95 and maximum were 1 ms.

The full-score trial played the original 240-cycle composition at 120 BPM for
about 121 seconds, with 20 gain edits. It reached the ending, became silent,
and restarted the applied score at sample zero. Output became nonzero again.
Initial-play/edit trials used new AudioContexts after WASM compilation, without
preparation warmup; their preparation maxima were 3, 1, and 1 ms.

## Limits

- No physical speaker recording or listening assessment was made. RDPSink is a
  virtual output path. Maximum reported latency reached about 1.416 seconds;
  zero underruns does not establish low latency or explain that delay.
- Worklet timing used `Date.now()` with 1 ms resolution. Render timings also
  include the measurement's peak scan. These values are not exact time bounds.
- Callback gaps were often grouped around 24 ms. The raw `over_block_budget`
  count is a numeric comparison, not a count of audio glitches or missed deadlines.
- Output counters include causes outside the worklet. The baseline and known
  stalls help interpret them; missing or frozen counters are not zero underruns.
  Detecting a 100 ms stall does not establish sensitivity to shorter stalls.
- Four busy Workers do not establish behavior under every CPU load. Edit trials
  waited for acknowledgements, so their windows differed from baseline trials.

## Experiment source

The original harness, fixture, analyzer, tests, and run commands remain in
[commit `fed34ba`](https://github.com/dowdiness/moondsp/tree/fed34ba483848b59fc1f2874e374c86aa01fb903/scripts/worklet-measurement),
preserved by tag `archive/worklet-measurements-2026-09-08`. Its
[original report](https://github.com/dowdiness/moondsp/blob/fed34ba483848b59fc1f2874e374c86aa01fb903/docs/performance/2026-09-08-playback-acceptance.md)
contains the invocation details. The harness archive and measured engine commit
are distinct; running the harness on a newer engine is a new experiment.

During consolidation, the original analyzer tests passed and both calibration
comparisons were rechecked from saved data. The ten playback trials were also
checked against their saved output counters. The three raw files are unchanged.
No browser or physical-output measurements were rerun for this cleanup.
