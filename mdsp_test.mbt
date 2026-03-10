///|
test "tick returns silence for non-positive sample rate" {
  let osc = Oscillator::new()
  let first = osc.tick(440.0, 0.0)
  let second = osc.tick(440.0, -1.0)
  assert_eq(first, 0.0)
  assert_eq(second, 0.0)
  assert_eq(osc.phase(), 0.0)
}

///|
test "tick advances phase continuously" {
  let osc = Oscillator::new()
  let first = osc.tick(440.0, 48000.0)
  let second = osc.tick(440.0, 48000.0)

  assert_eq(first, 0.0)
  assert_true(second > first)
  assert_eq(osc.phase(), 880.0 / 48000.0)
}

///|
test "process fills a block with bounded samples" {
  let osc = Oscillator::new()
  let context = DspContext::new(48000.0, 128)
  let buffer = AudioBuffer::filled(128)

  osc.process(context, buffer, 440.0)

  assert_eq(buffer.length(), 128)
  assert_eq(buffer.get(0), 0.0)
  assert_true(buffer.as_fixed_array().any(sample => sample != 0.0))
  assert_true(
    buffer.as_fixed_array().every(sample => sample >= -1.0 && sample <= 1.0),
  )
}

///|
test "audio buffer initializes and mutates samples" {
  let buffer = AudioBuffer::filled(4, init=0.25)

  assert_eq(buffer.length(), 4)
  assert_eq(buffer.get(0), 0.25)
  assert_eq(buffer.get(3), 0.25)

  buffer.set(1, -0.5)
  buffer.fill(0.75)

  assert_eq(buffer.get(0), 0.75)
  assert_eq(buffer.get(1), 0.75)
  assert_eq(buffer.get(3), 0.75)
}

///|
test "audio buffer can wrap an existing fixed array without copying" {
  let samples = FixedArray::make(4, 0.0)
  let buffer = AudioBuffer::new(samples)

  buffer.set(2, 0.5)

  assert_eq(samples[2], 0.5)
  samples[1] = -0.25
  assert_eq(buffer.get(1), -0.25)
}

///|
test "dsp context stores normalized runtime values" {
  let context = DspContext::new(48000.0, 128)

  assert_eq(context.sample_rate(), 48000.0)
  assert_eq(context.block_size(), 128)
}

///|
test "dsp context normalizes invalid runtime values" {
  let context = DspContext::new(-1.0, -64)

  assert_eq(context.sample_rate(), 0.0)
  assert_eq(context.block_size(), 0)
}

///|
test "gain with unity amount preserves samples" {
  let gain = Gain::new()
  let context = DspContext::new(48000.0, 4)
  let buffer = AudioBuffer::new(make_gain_test_samples())

  gain.process(context, buffer, 1.0)

  assert_eq(buffer.get(0), 0.25)
  assert_eq(buffer.get(1), -0.5)
  assert_eq(buffer.get(2), 1.0)
  assert_eq(buffer.get(3), -1.0)
}

///|
test "gain with zero amount silences samples" {
  let gain = Gain::new()
  let context = DspContext::new(48000.0, 4)
  let buffer = AudioBuffer::new(make_gain_test_samples())

  gain.process(context, buffer, 0.0)

  assert_true(buffer.as_fixed_array().every(sample => sample == 0.0))
}

///|
test "gain with negative amount inverts polarity" {
  let gain = Gain::new()
  let context = DspContext::new(48000.0, 4)
  let buffer = AudioBuffer::new(make_gain_test_samples())

  gain.process(context, buffer, -2.0)

  assert_eq(buffer.get(0), -0.5)
  assert_eq(buffer.get(1), 1.0)
  assert_eq(buffer.get(2), -2.0)
  assert_eq(buffer.get(3), 2.0)
}

///|
fn make_gain_test_samples() -> FixedArray[Double] {
  let samples = FixedArray::make(4, 0.0)
  samples[0] = 0.25
  samples[1] = -0.5
  samples[2] = 1.0
  samples[3] = -1.0
  samples
}
