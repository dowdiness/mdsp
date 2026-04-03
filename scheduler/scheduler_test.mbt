///|
test "midi_to_hz: A4 (69) = 440 Hz" {
  let hz = @scheduler.midi_to_hz(69.0)
  assert_true((hz - 440.0).abs() < 0.001)
}

///|
test "midi_to_hz: C4 (60) = 261.63 Hz" {
  let hz = @scheduler.midi_to_hz(60.0)
  assert_true(hz - 261.6255653006 < 0.01)
}

///|
test "midi_to_hz: MIDI 0" {
  let hz = @scheduler.midi_to_hz(0.0)
  assert_true(hz - 8.1758 < 0.01)
}

///|
test "midi_to_hz: MIDI 127" {
  let hz = @scheduler.midi_to_hz(127.0)
  assert_true(hz - 12543.85 < 1.0)
}

///|
test "PatternScheduler::new initializes with zero position" {
  let template : Array[@lib.DspNode] = [
    @lib.DspNode::oscillator(@lib.Waveform::Sine, 440.0),
    @lib.DspNode::gain(0, 1.0),
    @lib.DspNode::adsr(0.01, 0.1, 0.7, 0.3),
    @lib.DspNode::output(1),
  ]
  let ctx = @lib.DspContext::new(48000.0, 128)
  let bindings = @lib.ControlBindingBuilder::new()
    .bind(key="note", node_index=0, slot=@lib.GraphParamSlot::Value0)
    .build(template)
  match bindings {
    Ok(b) => {
      let sched = @scheduler.PatternScheduler::new(bpm=120.0, bindings=b, ctx~)
      inspect(sched.sample_counter(), content="0")
      inspect(sched.active_note_count(), content="0")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "compute_arc: first block at 120 BPM" {
  let arc = @scheduler.compute_arc(0L, 120.0, 48000, 128)
  let zero = @pattern.Rational::from_int(0)
  assert_true(arc.begin == zero)
  let expected_end = @pattern.Rational::new(15360L, 2880000L)
  assert_true(arc.end_ == expected_end)
}

///|
test "compute_arc: second block at 120 BPM" {
  let arc = @scheduler.compute_arc(128L, 120.0, 48000, 128)
  let expected_start = @pattern.Rational::new(15360L, 2880000L)
  let expected_end = @pattern.Rational::new(30720L, 2880000L)
  assert_true(arc.begin == expected_start)
  assert_true(arc.end_ == expected_end)
}
