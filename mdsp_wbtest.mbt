///|
test "reset rewinds phase to zero" {
  let osc = Oscillator::new()

  ignore(osc.tick(440.0, 48000.0))
  ignore(osc.tick(440.0, 48000.0))
  assert_true(osc.phase() > 0.0)

  osc.reset()

  assert_eq(osc.phase(), 0.0)
  assert_eq(osc.tick(440.0, 48000.0), 0.0)
}

///|
test "process with invalid sample rate writes silence" {
  let osc = Oscillator::new()
  let context = DspContext::new(0.0, 8)
  let buffer = AudioBuffer::filled(8, init=1.0)

  osc.process(context, buffer, 440.0)

  assert_true(buffer.as_fixed_array().every(sample => sample == 0.0))
  assert_eq(osc.phase(), 0.0)
}

///|
test "process respects context block size" {
  let osc = Oscillator::new()
  let context = DspContext::new(48000.0, 2)
  let buffer = AudioBuffer::filled(4, init=1.0)

  osc.process(context, buffer, 440.0)

  assert_eq(buffer.get(0), 0.0)
  assert_true(buffer.get(1) != 0.0)
  assert_eq(buffer.get(2), 0.0)
  assert_eq(buffer.get(3), 0.0)
}

///|
test "gain with invalid context writes silence" {
  let gain = Gain::new()
  let context = DspContext::new(0.0, 4)
  let buffer = AudioBuffer::new(make_gain_test_samples_wb())

  gain.process(context, buffer, 0.5)

  assert_true(buffer.as_fixed_array().every(sample => sample == 0.0))
}

///|
test "gain with invalid amount writes silence" {
  let gain = Gain::new()
  let context = DspContext::new(48000.0, 4)
  let buffer = AudioBuffer::new(make_gain_test_samples_wb())

  gain.process(context, buffer, 0.0 / 0.0)

  assert_true(buffer.as_fixed_array().every(sample => sample == 0.0))
}

///|
test "gain respects context block size" {
  let gain = Gain::new()
  let context = DspContext::new(48000.0, 2)
  let buffer = AudioBuffer::new(make_gain_block_samples_wb())

  gain.process(context, buffer, 0.5)

  assert_eq(buffer.get(0), 0.5)
  assert_eq(buffer.get(1), -0.5)
  assert_eq(buffer.get(2), 0.0)
  assert_eq(buffer.get(3), 0.0)
}

///|
fn make_gain_test_samples_wb() -> FixedArray[Double] {
  let samples = FixedArray::make(4, 0.0)
  samples[0] = 0.25
  samples[1] = -0.5
  samples[2] = 1.0
  samples[3] = -1.0
  samples
}

///|
fn make_gain_block_samples_wb() -> FixedArray[Double] {
  let samples = FixedArray::make(4, 0.0)
  samples[0] = 1.0
  samples[1] = -1.0
  samples[2] = 1.0
  samples[3] = -1.0
  samples
}
