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
