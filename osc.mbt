///|
/// Stateful sine oscillator for the first reusable Phase 1 DSP primitive.
pub struct Oscillator {
  mut phase : Double
}

///|
/// Create a new oscillator at phase zero.
pub fn Oscillator::new() -> Oscillator {
  { phase: 0.0 }
}

///|
/// Reset the oscillator to the start of the waveform.
pub fn Oscillator::reset(self : Oscillator) -> Unit {
  self.phase = 0.0
}

///|
/// Expose the current phase for testing and diagnostics.
pub fn Oscillator::phase(self : Oscillator) -> Double {
  self.phase
}

///|
/// Generate one sine sample and advance the oscillator state.
pub fn Oscillator::tick(
  self : Oscillator,
  freq : Double,
  sample_rate : Double,
) -> Double {
  if sample_rate <= 0.0 {
    return 0.0
  }
  let two_pi = 6.283185307179586
  let out = @math.sin(self.phase * two_pi)
  self.phase = wrap_phase(self.phase + freq / sample_rate)
  out
}

///|
/// Fill an output buffer with oscillator samples.
pub fn Oscillator::process(
  self : Oscillator,
  context : DspContext,
  output : AudioBuffer,
  freq : Double,
) -> Unit {
  let sample_rate = context.sample_rate()
  let sample_count = if output.length() < context.block_size() {
    output.length()
  } else {
    context.block_size()
  }

  if sample_rate <= 0.0 || sample_count <= 0 {
    output.fill(0.0)
    return
  }

  for index = 0; index < sample_count; index = index + 1 {
    output.set(index, self.tick(freq, sample_rate))
  }

  for index = sample_count; index < output.length(); index = index + 1 {
    output.set(index, 0.0)
  }
}

///|
fn wrap_phase(phase : Double) -> Double {
  if phase >= 1.0 {
    phase - @math.floor(phase)
  } else if phase < 0.0 {
    phase - @math.floor(phase)
  } else {
    phase
  }
}
