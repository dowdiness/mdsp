# Phase 5: Pattern Scheduler — Design Spec

> **Scope:** Core lib-side pattern-to-DSP bridge. Converts pattern events into voice pool operations with timing, MIDI-to-Hz conversion, and gate lifecycle management. Browser integration is a separate spec.

## Motivation

Phases 1–4 built the DSP graph engine (with compiled graphs, voice pool, stereo mixdown) and the pattern engine (rational time, combinators, ControlMap output). They are currently disconnected. The pattern scheduler bridges them: it queries patterns each audio block, triggers voices, and schedules gate-off at event boundaries.

## Package Structure

New `scheduler/` package with one-way dependencies:

```
scheduler/  ->  lib/      (VoicePool, ControlBindingMap, GraphControl, DspContext, AudioBuffer)
            ->  pattern/  (Pat, Event, ControlMap, TimeSpan, Rational)
```

`lib/` and `pattern/` remain independent of each other. The scheduler is the only coupling point.

## Core Types

### ActiveNote

Tracks a sounding voice for gate-off scheduling.

```moonbit
struct ActiveNote {
  handle : VoiceHandle
  end_time : Rational   // whole.end_ — cycle time when gate-off fires
}
```

### PatternScheduler

```moonbit
pub struct PatternScheduler {
  bpm : Double
  sample_counter : Int64         // total samples elapsed — monotonic, drift-free
  sample_rate : Int              // integer Hz (e.g. 48000)
  block_size : Int
  active_notes : Array[ActiveNote]
  bindings : ControlBindingMap
}
```

Constructor: `PatternScheduler::new(bpm~ : Double, bindings~ : ControlBindingMap, ctx~ : DspContext) -> PatternScheduler`

Takes `sample_rate` and `block_size` from the `DspContext`. BPM stays as `Double` — it is only used to compute the cycle-time arc each block, not accumulated.

**Timing model:** Position is derived each block from an integer `sample_counter`, not accumulated as `Rational`. The arc is computed as:
```
arc_start = Rational::new(sample_counter * bpm_int, sample_rate * 60)
arc_end   = Rational::new((sample_counter + block_size) * bpm_int, sample_rate * 60)
```
where `bpm_int` is BPM truncated to integer (e.g. 120). This avoids cumulative drift and keeps `Rational` denominators bounded. The sample counter is `Int64`, supporting ~6 million hours at 48kHz before overflow.

### midi_to_hz

Standalone utility: `fn midi_to_hz(midi : Double) -> Double`

Formula: `440.0 * 2^((midi - 69) / 12)`

## process_block Flow

`PatternScheduler::process_block(self, pat : Pat[ControlMap], pool : VoicePool, ctx : DspContext, left : AudioBuffer, right : AudioBuffer) -> Unit`

Called once per audio block (128 samples at 48kHz). Six steps:

### Step 1: Compute block arc

Derive the cycle-time arc `[start, end)` from the integer sample counter each block.

```
bpm_int = bpm.to_int()  // truncated integer BPM
arc_start = Rational::new(sample_counter * bpm_int, sample_rate * 60)
arc_end   = Rational::new((sample_counter + block_size) * bpm_int, sample_rate * 60)
arc = TimeSpan::new(arc_start, arc_end)
```

Position is derived, not accumulated — no floating-point drift. `Rational` denominators are bounded by `sample_rate * 60` (e.g. 2,880,000 for 48kHz).

### Step 2: Gate-off expired notes

Scan `active_notes`. For each note where `end_time <= arc.begin`:
- Call `pool.note_off(note.handle)`
- Remove from `active_notes`

Gate-off on a stolen voice is harmless — `VoiceHandle` generation mismatch causes `note_off` to return `false` (no-op).

### Step 3: Query pattern

```
let events = pat.query(arc)
```

Returns `Array[Event[ControlMap]]` — all events overlapping the current block arc.

### Step 4: Process note-ons

Sort events by onset time (`whole.begin`) to ensure deterministic voice allocation order — `Pat::query` does not guarantee sorted output.

For each event where `whole` is `Some` and `arc.contains(whole.begin)` (onset detection):

1. Extract the inner `Map[String, Double]` from the event's `ControlMap`
2. If a `"note"` key exists, convert its value via `midi_to_hz` and write the Hz value back
3. Call `bindings.resolve_controls(map)` to produce `Array[GraphControl]`
4. Call `pool.note_on(controls)`
5. If `Some(handle)`:
   - Push `ActiveNote { handle, end_time: whole.end_ }` to `active_notes`
   - If a `"pan"` key exists in the map, call `pool.set_voice_pan(handle, pan_value)` to use the engine's per-voice equal-power pan (bypasses graph controls)
6. If `None`, silent skip — pattern continues

Each event onset fires a new voice (stacking). No pitch deduplication.

**Pan handling:** The `"pan"` key is special-cased because `VoicePool` has dedicated per-voice pan with cached equal-power gains (`set_voice_pan`). Routing pan through graph controls would bypass this and duplicate the panning logic. The `"pan"` key is consumed by the scheduler and not passed to `resolve_controls`.

### Step 5: Advance sample counter

```
sample_counter = sample_counter + block_size.to_int64()
```

Integer counter — no drift, no overflow concern for practical session lengths.

### Step 6: Render audio

Zero `left` and `right` output buffers, then call `pool.process(ctx, left, right)`.

`VoicePool::process` mixes (adds) into output buffers — it does not zero them. The scheduler is responsible for clearing buffers each block before mixdown.

## Timing Resolution

Gate-off is **block-quantized**: a note ending mid-block stays active until the start of the next block. At 128 samples / 48kHz this is ~2.7ms of latency — inaudible for musical purposes. Sub-block sample-accurate scheduling is out of scope for Phase 5.

## Error Handling & Edge Cases

| Scenario | Behavior |
|----------|----------|
| Empty pattern | `query` returns `[]`. No note-ons, existing voices continue rendering. |
| Overlapping same-pitch notes | Each event onset fires a new voice (stacking). |
| Voices exhausted | `VoicePool` steals oldest voice via priority system. Scheduler doesn't intervene. |
| `note_on` returns `None` | Silent skip. Pattern continues, next event may succeed. |
| Event with no `"note"` key | Binding resolves whatever keys exist. No frequency change — voice uses oscillator default. |
| Event with `whole = None` | Skipped — continuous signal, no onset, no gate-off to schedule. |
| Multiple onsets per block | Sorted by onset time, then processed in order. Dense patterns fire multiple `note_on` calls per block. |
| Gate-off after voice stolen | `VoiceHandle` generation mismatch -> `note_off` returns false, harmless no-op. |

## Testing Plan

All tests use real `VoicePool` with a minimal template (single oscillator + ADSR). No mocks.

### Unit tests

- `midi_to_hz`: A4=69 -> 440Hz, C4=60 -> 261.63Hz, edge values (0, 127)
- Arc computation: block size 128 at 48kHz / 120 BPM -> correct cycle-time span
- Gate-off expiry: ActiveNote removed when `end_time <= arc.begin`

### Integration tests

- `note(60)` into PatternScheduler + VoicePool -> 1 active voice after `process_block`
- `note(60).fast(Rational::from_int(2))` -> 2 note-ons per cycle, verify voice count after enough blocks
- Enough `process_block` iterations to cross a gate-off boundary -> voice transitions to Releasing then Idle
- `s_pan(-1.0)` merged with `note(60)` -> voice pan set to -1.0 via `set_voice_pan`

### Edge case tests

- Empty pattern (`Pat::silence`) -> zero voices after `process_block`
- Pattern denser than block size -> multiple note-ons in a single `process_block`
- Gate-off on a stolen voice -> no crash, `note_off` returns false

## File Layout

```
scheduler/
  moon.pkg.json          — imports: ["dowdiness/mdsp/lib", "dowdiness/mdsp/pattern"]
  scheduler.mbt          — PatternScheduler, ActiveNote, midi_to_hz, process_block
  scheduler_test.mbt     — unit, integration, and edge case tests
```

## Out of Scope

- Browser/AudioWorklet integration (separate spec)
- Dynamic BPM changes (fixed BPM for now)
- Sub-block sample-accurate gate-off (~2.7ms block quantization is acceptable)
- Per-event velocity or dynamics (future enhancement)
- Pattern editor or live-coding interface
