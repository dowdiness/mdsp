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
  position : Rational            // current playback position in cycles (exact)
  block_advance : Rational       // cycles per block — precomputed from bpm + sample_rate + block_size
  active_notes : Array[ActiveNote]
  bindings : ControlBindingMap
}
```

Constructor: `PatternScheduler::new(bpm~ : Double, bindings~ : ControlBindingMap, sample_rate~ : Int, block_size~ : Int) -> PatternScheduler`

`block_advance` is precomputed as `Rational::new(block_size * bpm_num, sample_rate * 60 * bpm_den)` where `bpm_num/bpm_den` is the rational approximation of BPM. This keeps all timing in exact rational arithmetic — no floating-point drift.

### midi_to_hz

Standalone utility: `fn midi_to_hz(midi : Double) -> Double`

Formula: `440.0 * 2^((midi - 69) / 12)`

## process_block Flow

`PatternScheduler::process_block(self, pat : Pat[ControlMap], pool : VoicePool, ctx : DspContext, left : AudioBuffer, right : AudioBuffer) -> Unit`

Called once per audio block (128 samples at 48kHz). Six steps:

### Step 1: Compute block arc

Convert the current position to a cycle-time arc `[start, end)` using exact rational arithmetic.

```
arc_start = position                          // Rational, in cycles
arc_end = position + block_advance            // Rational, precomputed
arc = TimeSpan::new(arc_start, arc_end)
```

No floating-point conversion — position and arc boundaries are exact `Rational` values throughout.

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

For each event where `whole` is `Some` and `arc.contains(whole.begin)` (onset detection):

1. Extract the inner `Map[String, Double]` from the event's `ControlMap`
2. If a `"note"` key exists, convert its value via `midi_to_hz` and write the Hz value back
3. Call `bindings.resolve_controls(map)` to produce `Array[GraphControl]`
4. Call `pool.note_on(controls)`
5. If `Some(handle)`, push `ActiveNote { handle, end_time: whole.end_ }` to `active_notes`
6. If `None`, silent skip — pattern continues

Each event onset fires a new voice (stacking). No pitch deduplication.

### Step 5: Advance position

```
position = position + block_advance
```

Position grows monotonically as exact `Rational`. No floating-point drift. The pattern engine's `whole_cycles` handles arbitrary cycle numbers.

### Step 6: Render audio

```
pool.process(ctx, left, right)
```

## Error Handling & Edge Cases

| Scenario | Behavior |
|----------|----------|
| Empty pattern | `query` returns `[]`. No note-ons, existing voices continue rendering. |
| Overlapping same-pitch notes | Each event onset fires a new voice (stacking). |
| Voices exhausted | `VoicePool` steals oldest voice via priority system. Scheduler doesn't intervene. |
| `note_on` returns `None` | Silent skip. Pattern continues, next event may succeed. |
| Event with no `"note"` key | Binding resolves whatever keys exist. No frequency change — voice uses oscillator default. |
| Event with `whole = None` | Skipped — continuous signal, no onset, no gate-off to schedule. |
| Multiple onsets per block | All processed in order. Dense patterns fire multiple `note_on` calls per block. |
| Gate-off after voice stolen | `VoiceHandle` generation mismatch -> `note_off` returns false, harmless no-op. |

## Testing Plan

All tests use real `VoicePool` with a minimal template (single oscillator + ADSR). No mocks.

### Unit tests

- `midi_to_hz`: A4=69 -> 440Hz, C4=60 -> 261.63Hz, edge values (0, 127)
- Arc computation: block size 128 at 48kHz / 120 BPM -> correct cycle-time span
- Gate-off expiry: ActiveNote removed when `end_time <= arc.begin`

### Integration tests

- `note(60)` into PatternScheduler + VoicePool -> 1 active voice after `process_block`
- `fast(2, note(60))` -> 2 note-ons per cycle, verify voice count after enough blocks
- Enough `process_block` iterations to cross a gate-off boundary -> voice transitions to Releasing then Idle

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
- Per-event velocity or dynamics (future enhancement)
- Pattern editor or live-coding interface
