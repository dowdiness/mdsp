///|
test "is_voice_finished returns false during active envelope" {
  let ctx = DspContext::new(48000.0, 16)
  let nodes = [
    DspNode::oscillator(Waveform::Sine, 440.0),
    DspNode::adsr(5.0, 5.0, 0.5, 50.0),
    DspNode::mul(0, 1),
    DspNode::output(2),
  ]
  let compiled = CompiledDsp::compile(nodes, ctx).unwrap()
  ignore(compiled.gate_on(1))
  let buf = AudioBuffer::filled(16)
  compiled.process(ctx, buf)
  assert_true(!compiled.is_voice_finished())
}

///|
test "is_voice_finished returns true after envelope completes release" {
  let ctx = DspContext::new(1000.0, 8)
  let nodes = [
    DspNode::oscillator(Waveform::Sine, 100.0),
    DspNode::adsr(0.0, 0.0, 1.0, 1.0),
    DspNode::mul(0, 1),
    DspNode::output(2),
  ]
  let compiled = CompiledDsp::compile(nodes, ctx).unwrap()
  ignore(compiled.gate_on(1))
  let buf = AudioBuffer::filled(8)
  compiled.process(ctx, buf)
  ignore(compiled.gate_off(1))
  for i = 0; i < 10; i = i + 1 {
    compiled.process(ctx, buf)
  }
  assert_true(compiled.is_voice_finished())
}

///|
test "is_voice_finished returns true for graph with no ADSR when output is silent" {
  let ctx = DspContext::new(48000.0, 4)
  let nodes = [DspNode::constant(0.0), DspNode::output(0)]
  let compiled = CompiledDsp::compile(nodes, ctx).unwrap()
  let buf = AudioBuffer::filled(4)
  compiled.process(ctx, buf)
  assert_true(compiled.is_voice_finished())
}

///|
test "is_voice_finished returns false when delay tail is audible" {
  let ctx = DspContext::new(48000.0, 16)
  let nodes = [
    DspNode::oscillator(Waveform::Sine, 440.0),
    DspNode::adsr(0.0, 0.0, 1.0, 0.0),
    DspNode::mul(0, 1),
    DspNode::delay(2, 4800, delay_samples=16, feedback=0.9),
    DspNode::output(3),
  ]
  let compiled = CompiledDsp::compile(nodes, ctx).unwrap()
  ignore(compiled.gate_on(1))
  let buf = AudioBuffer::filled(16)
  compiled.process(ctx, buf)
  ignore(compiled.gate_off(1))
  compiled.process(ctx, buf)
  assert_true(!compiled.is_voice_finished())
}

///|
test "voice pool constructor accepts valid template" {
  let ctx = DspContext::new(48000.0, 128)
  let nodes = [DspNode::constant(440.0), DspNode::output(0)]
  let pool = VoicePool::new(nodes, ctx)
  assert_true(pool is Some(_))
  assert_true(pool.unwrap().active_voice_count() == 0)
}

///|
test "voice pool constructor rejects invalid template" {
  let ctx = DspContext::new(48000.0, 128)
  let nodes : Array[DspNode] = []
  let pool = VoicePool::new(nodes, ctx)
  assert_true(pool is None)
}

///|
test "set_template accepts valid template" {
  let ctx = DspContext::new(48000.0, 128)
  let nodes = [DspNode::constant(440.0), DspNode::output(0)]
  let pool = VoicePool::new(nodes, ctx).unwrap()
  let new_nodes = [DspNode::constant(880.0), DspNode::output(0)]
  assert_true(pool.set_template(new_nodes))
}

///|
test "set_template rejects invalid template" {
  let ctx = DspContext::new(48000.0, 128)
  let nodes = [DspNode::constant(440.0), DspNode::output(0)]
  let pool = VoicePool::new(nodes, ctx).unwrap()
  assert_true(!pool.set_template([]))
}

///|
test "note_on allocates a voice and returns valid handle" {
  let ctx = DspContext::new(48000.0, 16)
  let nodes = [DspNode::constant(440.0), DspNode::output(0)]
  let pool = VoicePool::new(nodes, ctx, max_voices=4).unwrap()
  let handle = pool.note_on([])
  assert_true(handle is Some(_))
  assert_true(pool.active_voice_count() == 1)
}

///|
test "note_on fills pool to capacity" {
  let ctx = DspContext::new(48000.0, 16)
  let nodes = [DspNode::constant(440.0), DspNode::output(0)]
  let pool = VoicePool::new(nodes, ctx, max_voices=4).unwrap()
  for i = 0; i < 4; i = i + 1 {
    let h = pool.note_on([])
    assert_true(h is Some(_))
  }
  assert_true(pool.active_voice_count() == 4)
}

///|
test "note_on steals oldest active when pool is full" {
  let ctx = DspContext::new(48000.0, 16)
  let nodes = [DspNode::constant(440.0), DspNode::output(0)]
  let pool = VoicePool::new(nodes, ctx, max_voices=2).unwrap()
  let h1 = pool.note_on([]).unwrap()
  ignore(pool.note_on([]))
  let h3 = pool.note_on([]).unwrap()
  // h1's slot was stolen
  assert_true(h3.slot == h1.slot)
}

///|
test "note_off transitions voice to Releasing" {
  let ctx = DspContext::new(48000.0, 16)
  let nodes = [
    DspNode::constant(440.0),
    DspNode::adsr(5.0, 5.0, 0.5, 50.0),
    DspNode::output(1),
  ]
  let pool = VoicePool::new(nodes, ctx, max_voices=4).unwrap()
  let handle = pool.note_on([]).unwrap()
  assert_true(pool.voice_state(handle) is VoiceState::Active)
  assert_true(pool.note_off(handle))
  assert_true(pool.voice_state(handle) is VoiceState::Releasing)
}

///|
test "stale handle note_off returns false" {
  let ctx = DspContext::new(48000.0, 16)
  let nodes = [DspNode::constant(440.0), DspNode::output(0)]
  let pool = VoicePool::new(nodes, ctx, max_voices=1).unwrap()
  let h1 = pool.note_on([]).unwrap()
  ignore(pool.note_on([]))
  assert_true(!pool.note_off(h1))
}

///|
test "stale handle voice_state returns Idle" {
  let ctx = DspContext::new(48000.0, 16)
  let nodes = [DspNode::constant(440.0), DspNode::output(0)]
  let pool = VoicePool::new(nodes, ctx, max_voices=1).unwrap()
  let h1 = pool.note_on([]).unwrap()
  ignore(pool.note_on([]))
  assert_true(pool.voice_state(h1) is VoiceState::Idle)
}

///|
test "set_voice_pan with stale handle returns false" {
  let ctx = DspContext::new(48000.0, 16)
  let nodes = [DspNode::constant(440.0), DspNode::output(0)]
  let pool = VoicePool::new(nodes, ctx, max_voices=1).unwrap()
  let h1 = pool.note_on([]).unwrap()
  ignore(pool.note_on([]))
  assert_true(!pool.set_voice_pan(h1, 0.5))
}
