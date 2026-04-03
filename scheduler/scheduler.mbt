///|
/// Tracks a sounding voice for gate-off scheduling.
struct ActiveNote {
  handle : @lib.VoiceHandle
  end_time : @pattern.Rational
}

///|
pub struct PatternScheduler {
  bpm : Double
  sample_counter : Int64
  sample_rate : Int
  block_size : Int
  active_notes : Array[ActiveNote]
  bindings : @lib.ControlBindingMap

  fn new(
    bpm~ : Double,
    bindings~ : @lib.ControlBindingMap,
    ctx~ : @lib.DspContext,
  ) -> PatternScheduler
}

///|
pub fn PatternScheduler::new(
  bpm~ : Double,
  bindings~ : @lib.ControlBindingMap,
  ctx~ : @lib.DspContext,
) -> PatternScheduler {
  {
    bpm,
    sample_counter: 0L,
    sample_rate: ctx.sample_rate().to_int(),
    block_size: ctx.block_size(),
    active_notes: [],
    bindings,
  }
}

///|
pub fn PatternScheduler::sample_counter(self : PatternScheduler) -> Int64 {
  self.sample_counter
}

///|
pub fn PatternScheduler::active_note_count(self : PatternScheduler) -> Int {
  self.active_notes.length()
}

///|
pub fn midi_to_hz(midi : Double) -> Double {
  440.0 * Double::pow(2.0, (midi - 69.0) / 12.0)
}

///|
/// Derive the cycle-time arc for a block from the integer sample counter.
/// Denominators are bounded by sample_rate * 60 — no overflow risk for
/// practical session lengths with Int64 numerators.
pub fn compute_arc(
  sample_counter : Int64,
  bpm : Double,
  sample_rate : Int,
  block_size : Int,
) -> @pattern.TimeSpan {
  let bpm_int = bpm.to_int().to_int64()
  let sr60 = sample_rate.to_int64() * 60L
  let arc_start = @pattern.Rational::new(sample_counter * bpm_int, sr60)
  let arc_end = @pattern.Rational::new(
    (sample_counter + block_size.to_int64()) * bpm_int,
    sr60,
  )
  @pattern.TimeSpan::new(arc_start, arc_end)
}
