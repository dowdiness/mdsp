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
