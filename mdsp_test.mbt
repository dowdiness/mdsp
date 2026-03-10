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
  let buffer = AudioBuffer::filled(128)

  osc.process(buffer, 440.0, 48000.0)

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
