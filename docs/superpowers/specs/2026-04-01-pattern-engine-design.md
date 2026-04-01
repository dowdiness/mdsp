# Phase 4: Pattern Engine — Design Spec

> **Date:** 2026-04-01
> **Scope:** Strudel-inspired pattern algebra in a standalone `pattern/` package with rational time, 6 combinators, and ControlMap output.

---

## Goal

Implement a pattern algebra where patterns are query functions over time arcs, producing events with control maps. Musical time uses exact rational arithmetic to prevent subdivision drift.

**Deliverable:** `sequence([note_name("c3"), note_name("e3"), note_name("g3")]).fast(2)` queries correctly over a time arc, producing 6 events per cycle with exact rational time boundaries.

---

## Architecture

### Strudel's Core Insight

A pattern is not a data structure — it's a function from time to events:

```
Pat[A] = (TimeSpan) -> Array[Event[A]]
```

Combinators compose these functions. `sequence` divides time. `stack` layers time. `fast`/`slow` scale time. This is Church encoding — the pattern's behavior IS its representation.

### Concrete Now, Tagless Later

Phase 4 uses concrete function composition only (no traits, no AST). The API is designed to be compatible with adding a `PatternSym` trait layer in Phase 6 when `incr` needs the AST for memoization. The tagless layer would wrap these concrete combinators, not replace them.

### Package Independence

The `pattern/` package has zero dependency on the DSP engine (`lib/`). It knows about time, events, and control maps, but nothing about audio, oscillators, or voices. Phase 5 (Pattern × DSP Integration) bridges the two.

---

## Core Types

### Rational

Exact fraction arithmetic for musical time. Always simplified (GCD), denominator always positive.

```
struct Rational { num: Int, den: Int }

Arithmetic: add, sub, mul, div
Comparison: Eq, Compare (cross-multiply to avoid float)
Conversion: to_double(), from_int()
Construction: new(num, den) — simplifies and normalizes sign
```

WHY rational: musical subdivisions like 1/3, 1/5, 1/7 cannot be represented exactly in floating point. Over long-running patterns (live performance), the accumulated drift causes events to shift relative to the beat grid. Strudel and TidalCycles both use rationals for this reason.

### TimeSpan (Arc)

Half-open time interval `[begin, end)` with rational boundaries.

```
struct TimeSpan { begin: Rational, end_: Rational }

duration() -> Rational                // end_ - begin
contains(time: Rational) -> Bool      // begin <= time < end_
intersect(other: TimeSpan) -> TimeSpan?  // None if disjoint
whole_cycles() -> Array[TimeSpan]     // split into per-cycle arcs
```

WHY `whole_cycles`: patterns repeat every cycle (Rational 1). Querying arc `[0, 5/2)` needs to be split into `[0,1)`, `[1,2)`, `[2,5/2)` so each cycle's events can be generated independently with correct positions.

WHY `end_` not `end`: `end` may be a reserved word or cause ambiguity in MoonBit.

### Event[A]

A value positioned in time with both "ideal" and "actual" time spans.

```
struct Event[A] { whole: TimeSpan?, part: TimeSpan, value: A }
```

WHY two time spans:
- `whole` — the event's ideal duration (e.g., a full quarter note). Used by the DSP integration layer (Phase 5) to determine gate-on/gate-off timing.
- `part` — the portion of the event intersecting the query arc. When a query slices through the middle of an event, `part` is the intersection.
- `whole` is `None` for continuous (non-onset) signals — these don't trigger note events.

### Pat[A]

A pattern is a query function over time.

```
struct Pat[A] { query: (TimeSpan) -> Array[Event[A]] }
```

---

## Combinators (6)

### `pure(value: A) -> Pat[A]`

Constant pattern — one event per cycle spanning the full cycle `[n, n+1)`. The "inject a value into pattern context" operation (Applicative `pure`).

### `sequence(pats: Array[Pat[A]]) -> Pat[A]`

Divide each cycle equally among the patterns. `sequence([a, b, c])` gives each pattern 1/3 of a cycle. Each sub-pattern is queried over its compressed time window and events are shifted to the correct position.

Implementation: for N patterns, each occupies `[i/N, (i+1)/N)` within a cycle. Scale each sub-pattern's time by N (like `fast`) and offset.

### `stack(pats: Array[Pat[A]]) -> Pat[A]`

Layer patterns simultaneously. All produce events over the same time span. The results are concatenated. This is polyphony — multiple notes at the same time.

Implementation: query all patterns with the same arc, concatenate results.

### `fast(factor: Rational, pat: Pat[A]) -> Pat[A]`

Speed up by compressing time. `fast(2, pat)` plays the pattern twice per cycle.

Implementation: scale the query arc by `factor`, query the inner pattern, then scale event times back by `1/factor`. The inner pattern sees compressed time, but the events are reported in the caller's time frame.

### `slow(factor: Rational, pat: Pat[A]) -> Pat[A]`

Slow down. `slow(2, pat)` = `fast(1/factor, pat)`. Sugar for readability.

### `every(n: Int, f: (Pat[A]) -> Pat[A], pat: Pat[A]) -> Pat[A]`

Apply transformation `f` every nth cycle. `every(4, fn(p) { rev(p) }, pat)` reverses the pattern every 4th cycle.

Implementation: for each queried cycle, check `floor(cycle_begin) % n == 0`. If true, apply `f` to the pattern for that cycle's query. Otherwise, query the original.

### `rev(pat: Pat[A]) -> Pat[A]`

Reverse event order within each cycle. Mirror event times around the cycle midpoint.

Implementation: for each event, `new_begin = 1 - old_end`, `new_end = 1 - old_begin` (within the cycle).

---

## ControlMap

The contract between the Pattern Engine and the DSP Engine (consumed in Phase 5).

```
type ControlMap = Map[String, Double]
```

### Helper Constructors

```
fn note(n: Double) -> Pat[ControlMap]           // { "note": n }
fn note_name(name: String) -> Pat[ControlMap]   // "c3" → { "note": 48.0 }
fn s_cutoff(f: Double) -> Pat[ControlMap]       // { "cutoff": f }
fn s_gain(g: Double) -> Pat[ControlMap]         // { "gain": g }
fn s_pan(p: Double) -> Pat[ControlMap]          // { "pan": p }
```

WHY `s_` prefix for cutoff/gain/pan: avoids name collision with the DSP primitives (`Gain`, `Pan`, `Clip`) in future cross-package usage. `note` and `note_name` are unambiguous.

### Note Name Conversion

Standard MIDI mapping: `c0` = 12, each octave = 12 semitones, each letter maps to a semitone offset. Supports sharps (`cs3`, `fs4`) and flats (`eb3`, `bf4`).

```
"c3" → 48.0, "e3" → 52.0, "g3" → 55.0, "a4" → 69.0
```

### ControlMap Merging

When patterns of `ControlMap` are stacked, events at the same time should merge their maps (union, right-biased). A dedicated `merge_control` combinator:

```
fn merge_control(
  a: Pat[ControlMap],
  b: Pat[ControlMap],
) -> Pat[ControlMap]
```

This enables `merge_control(note(60), s_cutoff(800))` → events with `{ "note": 60, "cutoff": 800 }`.

---

## File Structure

```
pattern/
├── moon.pkg              — package config (no dependencies on lib/)
├── rational.mbt          — Rational struct + arithmetic + comparison
├── time.mbt              — TimeSpan struct + duration/contains/intersect/whole_cycles
├── event.mbt             — Event[A] struct
├── pattern.mbt           — Pat[A] struct + pure + fast + slow + rev
├── combinators.mbt       — sequence + stack + every
├── control.mbt           — ControlMap type, note/note_name/s_cutoff/s_gain/s_pan helpers, merge_control
├── rational_test.mbt     — Rational arithmetic, simplification, edge cases
├── time_test.mbt         — Arc overlap, intersection, whole_cycles splitting
├── pattern_test.mbt      — pure, fast, slow, rev, sequence, stack, every
└── control_test.mbt      — note_name conversion, ControlMap merge, end-to-end deliverable
```

Also modify:
- `moon.mod.json` — no new deps needed (Map is in core)

---

## Testing

| File | Key Tests |
|------|-----------|
| `rational_test.mbt` | `2/4 simplifies to 1/2`, `1/3 + 1/3 = 2/3`, `negative denominator normalizes`, `division by zero` |
| `time_test.mbt` | `[0,1) intersect [0.5,1.5) = [0.5,1)`, `disjoint arcs → None`, `whole_cycles([0, 2.5)) = 3 arcs` |
| `pattern_test.mbt` | `pure(x) over [0,1) → 1 event`, `sequence([a,b]) over [0,1) → 2 events at [0,1/2) and [1/2,1)`, `fast(2, pat) over [0,1) → 2x events`, `rev mirrors within cycle`, `every(2, rev, pat)` applies rev on even cycles only |
| `control_test.mbt` | `note_name("c3") → 48.0`, `note_name("fs4") → 66.0`, deliverable end-to-end: `sequence([note_name("c3"), note_name("e3"), note_name("g3")]).fast(2)` over `[0,1)` → 6 events |

---

## Success Criteria

1. The deliverable expression produces exactly 6 events per cycle with correct rational time boundaries
2. All time computations use Rational — no floating point in time representation
3. The `pattern/` package compiles and tests independently from `lib/`
4. Existing 331 DSP tests are unaffected
5. Combinators compose correctly: `fast(2, sequence([a, b]))` ≠ `sequence([fast(2, a), fast(2, b)])`

---

## What Is NOT in Scope (Phase 5+)

- DSP integration (`event_to_dsp`, voice allocation from events)
- `PatternSym` trait / concrete `PatternNode` AST (Phase 6, `incr` integration)
- Real-time scheduling (clock, audio callback timing)
- Text parsing / REPL
- Browser UI
