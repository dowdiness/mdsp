///|
/// Stateful integer-sample delay line backed by a circular buffer.
pub struct DelayLine {
  buffer : FixedArray[Double]
  mut write_pos : Int
  mut delay_samples : Int

  fn new(max_delay_samples : Int, delay_samples? : Int) -> DelayLine
}

///|
/// Create a delay line with preallocated storage and a normalized delay length.
pub fn DelayLine::new(
  max_delay_samples : Int,
  delay_samples? : Int = default_delay_samples(max_delay_samples),
) -> DelayLine {
  let capacity = max_delay_capacity(max_delay_samples)
  {
    buffer: FixedArray::make(capacity, 0.0),
    write_pos: 0,
    delay_samples: normalize_delay_samples(delay_samples, capacity),
  }
}

///|
/// Return the maximum representable delay length in samples.
pub fn DelayLine::max_delay_samples(self : DelayLine) -> Int {
  self.buffer.length()
}

///|
/// Return the active delay length in samples.
pub fn DelayLine::delay_samples(self : DelayLine) -> Int {
  self.delay_samples
}

///|
/// Update the active delay length, clamping to the allocated storage range.
pub fn DelayLine::set_delay_samples(
  self : DelayLine,
  delay_samples : Int,
) -> Unit {
  self.delay_samples = normalize_delay_samples(
    delay_samples,
    self.buffer.length(),
  )
}

///|
/// Clear the circular buffer state without changing the configured delay.
pub fn DelayLine::reset(self : DelayLine) -> Unit {
  self.buffer.fill(0.0)
  self.write_pos = 0
}

///|
/// Process one input sample and return the delayed output sample.
pub fn DelayLine::tick(self : DelayLine, input : Double) -> Double {
  if self.delay_samples == 0 {
    self.buffer[self.write_pos] = input
    self.advance_write_pos()
    input
  } else {
    let read_pos = delayed_read_pos(
      self.write_pos,
      self.delay_samples,
      self.buffer.length(),
    )
    let output = self.buffer[read_pos]
    self.buffer[self.write_pos] = input
    self.advance_write_pos()
    output
  }
}

///|
/// Process one block of samples in place.
pub fn DelayLine::process(
  self : DelayLine,
  context : DspContext,
  buffer : AudioBuffer,
) -> Unit {
  let sample_rate = context.sample_rate()
  let sample_count = delay_sample_count(context, buffer)
  if !is_valid_delay_sample_rate(sample_rate) {
    buffer.fill(0.0)
    return
  }
  if sample_count <= 0 {
    buffer.fill(0.0)
    return
  }

  for index = 0; index < sample_count; index = index + 1 {
    let input = buffer.get(index)
    buffer.set(index, self.tick(input))
  }

  for index = sample_count; index < buffer.length(); index = index + 1 {
    buffer.set(index, 0.0)
  }
}

///|
fn DelayLine::advance_write_pos(self : DelayLine) -> Unit {
  self.write_pos = self.write_pos + 1
  if self.write_pos >= self.buffer.length() {
    self.write_pos = 0
  }
}

///|
fn delayed_read_pos(
  write_pos : Int,
  delay_samples : Int,
  capacity : Int,
) -> Int {
  let read_pos = write_pos - delay_samples
  if read_pos < 0 {
    read_pos + capacity
  } else {
    read_pos
  }
}

///|
fn max_delay_capacity(value : Int) -> Int {
  if value > 0 {
    value
  } else {
    1
  }
}

///|
fn default_delay_samples(value : Int) -> Int {
  if value > 0 {
    value
  } else {
    0
  }
}

///|
fn normalize_delay_samples(value : Int, capacity : Int) -> Int {
  if value < 0 {
    0
  } else if value > capacity {
    capacity
  } else {
    value
  }
}

///|
fn is_valid_delay_sample_rate(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf() && value > 0.0
}

///|
fn delay_sample_count(context : DspContext, buffer : AudioBuffer) -> Int {
  if buffer.length() < context.block_size() {
    buffer.length()
  } else {
    context.block_size()
  }
}
