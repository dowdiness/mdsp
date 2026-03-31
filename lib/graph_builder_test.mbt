///|
test "GraphBuilder: constant produces one node" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(440.0)
  assert_eq(c.nodes().length(), 1)
}

///|
test "GraphBuilder: mul merges two constants" {
  let a : @lib.GraphBuilder = @lib.ArithSym::constant(3.0)
  let b : @lib.GraphBuilder = @lib.ArithSym::constant(4.0)
  let product : @lib.GraphBuilder = @lib.ArithSym::mul(a, b)
  let nodes = product.nodes()
  assert_eq(nodes.length(), 3) // const(3), const(4), mul(0,1)
  assert_true(nodes[0].kind is @lib.DspNodeKind::Constant)
  assert_eq(nodes[0].value0, 3.0)
  assert_true(nodes[1].kind is @lib.DspNodeKind::Constant)
  assert_eq(nodes[1].value0, 4.0)
  assert_true(nodes[2].kind is @lib.DspNodeKind::Mul)
  assert_eq(nodes[2].input0, 0)
  assert_eq(nodes[2].input1, 1)
}

///|
test "GraphBuilder: mix merges two constants" {
  let a : @lib.GraphBuilder = @lib.ArithSym::constant(3.0)
  let b : @lib.GraphBuilder = @lib.ArithSym::constant(4.0)
  let result : @lib.GraphBuilder = @lib.ArithSym::mix(a, b)
  let nodes = result.nodes()
  assert_eq(nodes.length(), 3)
  assert_true(nodes[2].kind is @lib.DspNodeKind::Mix)
  assert_eq(nodes[2].input0, 0)
  assert_eq(nodes[2].input1, 1)
}

///|
test "GraphBuilder: unary chain shares array" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let g : @lib.GraphBuilder = @lib.DspSym::gain(c, 0.5)
  let o : @lib.GraphBuilder = @lib.DspSym::output(g)
  assert_eq(o.nodes().length(), 3) // const, gain, output
}

///|
test "GraphBuilder: oscillator with frequency input" {
  let freq : @lib.GraphBuilder = @lib.ArithSym::constant(440.0)
  let osc : @lib.GraphBuilder = @lib.DspSym::oscillator(
    freq,
    @lib.Waveform::Sine,
  )
  let nodes = osc.nodes()
  assert_eq(nodes.length(), 2) // const, oscillator
  assert_true(nodes[1].kind is @lib.DspNodeKind::Oscillator)
  assert_eq(nodes[1].input0, 0)
  assert_true(nodes[1].waveform is @lib.Waveform::Sine)
}

///|
test "GraphBuilder: noise source" {
  let n : @lib.GraphBuilder = @lib.DspSym::noise(42U)
  let nodes = n.nodes()
  assert_eq(nodes.length(), 1)
  assert_true(nodes[0].kind is @lib.DspNodeKind::Noise)
  assert_eq(nodes[0].seed, 42U)
}

///|
test "GraphBuilder: adsr source" {
  let e : @lib.GraphBuilder = @lib.DspSym::adsr(10.0, 50.0, 0.7, 200.0)
  let nodes = e.nodes()
  assert_eq(nodes.length(), 1)
  assert_true(nodes[0].kind is @lib.DspNodeKind::Adsr)
  assert_eq(nodes[0].value0, 10.0)
  assert_eq(nodes[0].value1, 50.0)
  assert_eq(nodes[0].value2, 0.7)
  assert_eq(nodes[0].value3, 200.0)
}

///|
test "GraphBuilder: clip" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let clipped : @lib.GraphBuilder = @lib.ArithSym::clip(c, 0.5)
  let nodes = clipped.nodes()
  assert_eq(nodes.length(), 2)
  assert_true(nodes[1].kind is @lib.DspNodeKind::Clip)
  assert_eq(nodes[1].input0, 0)
  assert_eq(nodes[1].value0, 0.5)
}

///|
test "GraphBuilder: biquad filter" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let filtered : @lib.GraphBuilder = @lib.FilterSym::biquad(
    c,
    @lib.BiquadMode::LowPass,
    1000.0,
    0.707,
  )
  let nodes = filtered.nodes()
  assert_eq(nodes.length(), 2)
  assert_true(nodes[1].kind is @lib.DspNodeKind::Biquad)
  assert_eq(nodes[1].input0, 0)
  assert_eq(nodes[1].value0, 1000.0)
  assert_eq(nodes[1].value1, 0.707)
  assert_true(nodes[1].filter_mode is @lib.BiquadMode::LowPass)
}

///|
test "GraphBuilder: delay" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let delayed : @lib.GraphBuilder = @lib.DelaySym::delay(c, 48000, 24000, 0.5)
  let nodes = delayed.nodes()
  assert_eq(nodes.length(), 2)
  assert_true(nodes[1].kind is @lib.DspNodeKind::Delay)
  assert_eq(nodes[1].input0, 0)
  assert_eq(nodes[1].delay_max_samples, 48000)
  assert_eq(nodes[1].delay_samples, 24000)
  assert_eq(nodes[1].value0, 0.5)
}

///|
test "GraphBuilder: pan" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let panned : @lib.GraphBuilder = @lib.StereoSym::pan(c, 0.3)
  let nodes = panned.nodes()
  assert_eq(nodes.length(), 2)
  assert_true(nodes[1].kind is @lib.DspNodeKind::Pan)
  assert_eq(nodes[1].input0, 0)
  assert_eq(nodes[1].value0, 0.3)
}

///|
test "GraphBuilder: stereo_gain" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let p : @lib.GraphBuilder = @lib.StereoSym::pan(c, 0.0)
  let sg : @lib.GraphBuilder = @lib.StereoSym::stereo_gain(p, 0.8)
  let nodes = sg.nodes()
  assert_eq(nodes.length(), 3)
  assert_true(nodes[2].kind is @lib.DspNodeKind::StereoGain)
  assert_eq(nodes[2].input0, 1)
  assert_eq(nodes[2].value0, 0.8)
}

///|
test "GraphBuilder: stereo_clip" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let p : @lib.GraphBuilder = @lib.StereoSym::pan(c, 0.0)
  let sc : @lib.GraphBuilder = @lib.StereoSym::stereo_clip(p, 0.5)
  let nodes = sc.nodes()
  assert_eq(nodes.length(), 3)
  assert_true(nodes[2].kind is @lib.DspNodeKind::StereoClip)
  assert_eq(nodes[2].input0, 1)
  assert_eq(nodes[2].value0, 0.5)
}

///|
test "GraphBuilder: stereo_biquad" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let p : @lib.GraphBuilder = @lib.StereoSym::pan(c, 0.0)
  let sb : @lib.GraphBuilder = @lib.StereoFilterSym::stereo_biquad(
    p,
    @lib.BiquadMode::HighPass,
    500.0,
    1.0,
  )
  let nodes = sb.nodes()
  assert_eq(nodes.length(), 3)
  assert_true(nodes[2].kind is @lib.DspNodeKind::StereoBiquad)
  assert_eq(nodes[2].input0, 1)
  assert_eq(nodes[2].value0, 500.0)
  assert_eq(nodes[2].value1, 1.0)
  assert_true(nodes[2].filter_mode is @lib.BiquadMode::HighPass)
}

///|
test "GraphBuilder: stereo_delay" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let p : @lib.GraphBuilder = @lib.StereoSym::pan(c, 0.0)
  let sd : @lib.GraphBuilder = @lib.StereoDelaySym::stereo_delay(
    p, 48000, 12000, 0.3,
  )
  let nodes = sd.nodes()
  assert_eq(nodes.length(), 3)
  assert_true(nodes[2].kind is @lib.DspNodeKind::StereoDelay)
  assert_eq(nodes[2].input0, 1)
  assert_eq(nodes[2].delay_max_samples, 48000)
  assert_eq(nodes[2].delay_samples, 12000)
  assert_eq(nodes[2].value0, 0.3)
}

///|
test "GraphBuilder: stereo_mixdown unary" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let p : @lib.GraphBuilder = @lib.StereoSym::pan(c, -1.0)
  let mixed : @lib.GraphBuilder = @lib.StereoSym::stereo_mixdown(p)
  let nodes = mixed.nodes()
  // const(1.0)=0, pan(0)=1, stereo_mixdown(1)=2
  assert_eq(nodes.length(), 3)
  assert_true(nodes[2].kind is @lib.DspNodeKind::StereoMixDown)
  assert_eq(nodes[2].input0, 1)
  assert_eq(nodes[2].input1, -1)
}

///|
test "GraphBuilder: stereo_output unary" {
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let p : @lib.GraphBuilder = @lib.StereoSym::pan(c, -1.0)
  let out : @lib.GraphBuilder = @lib.StereoSym::stereo_output(p)
  let nodes = out.nodes()
  assert_eq(nodes.length(), 3)
  assert_true(nodes[2].kind is @lib.DspNodeKind::StereoOutput)
  assert_eq(nodes[2].input0, 1)
  assert_eq(nodes[2].input1, -1)
}

///|
test "GraphBuilder: remap preserves correct indices during merge" {
  // Build a chain: const -> gain -> clip
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let g : @lib.GraphBuilder = @lib.DspSym::gain(c, 0.5)
  let clipped : @lib.GraphBuilder = @lib.ArithSym::clip(g, 0.8)
  // Build another chain
  let c2 : @lib.GraphBuilder = @lib.ArithSym::constant(2.0)
  let g2 : @lib.GraphBuilder = @lib.DspSym::gain(c2, 0.3)
  // Multiply them: merges c2,g2 into c,g,clip array with offset 3
  let result : @lib.GraphBuilder = @lib.ArithSym::mul(clipped, g2)
  let nodes = result.nodes()
  // Original: const(1)=0, gain(0)=1, clip(1)=2
  // Merged:   const(2)=3, gain(3)=4
  // Mul(2,4)=5
  assert_eq(nodes.length(), 6)
  assert_true(nodes[3].kind is @lib.DspNodeKind::Constant)
  assert_eq(nodes[3].value0, 2.0)
  assert_true(nodes[4].kind is @lib.DspNodeKind::Gain)
  assert_eq(nodes[4].input0, 3) // remapped from 0 to 0+3=3
  assert_true(nodes[5].kind is @lib.DspNodeKind::Mul)
  assert_eq(nodes[5].input0, 2)
  assert_eq(nodes[5].input1, 4)
}

///|
test "GraphBuilder: same-array binary op does not duplicate" {
  // When both operands share the same array (from same source chain),
  // no duplication should occur
  let c : @lib.GraphBuilder = @lib.ArithSym::constant(1.0)
  let g : @lib.GraphBuilder = @lib.DspSym::gain(c, 0.5)
  // g shares the same array as c
  // mul(c, g) should just append without merging
  let result : @lib.GraphBuilder = @lib.ArithSym::mul(c, g)
  let nodes = result.nodes()
  // const=0, gain(0)=1, mul(0,1)=2
  assert_eq(nodes.length(), 3)
  assert_true(nodes[2].kind is @lib.DspNodeKind::Mul)
  assert_eq(nodes[2].input0, 0)
  assert_eq(nodes[2].input1, 1)
}

///|
test "GraphBuilder: full mono pipeline" {
  // const -> osc -> gain -> biquad -> output
  let freq : @lib.GraphBuilder = @lib.ArithSym::constant(440.0)
  let osc : @lib.GraphBuilder = @lib.DspSym::oscillator(
    freq,
    @lib.Waveform::Saw,
  )
  let gained : @lib.GraphBuilder = @lib.DspSym::gain(osc, 0.7)
  let filtered : @lib.GraphBuilder = @lib.FilterSym::biquad(
    gained,
    @lib.BiquadMode::LowPass,
    2000.0,
    0.707,
  )
  let out : @lib.GraphBuilder = @lib.DspSym::output(filtered)
  let nodes = out.nodes()
  assert_eq(nodes.length(), 5) // const, osc, gain, biquad, output
  assert_true(nodes[0].kind is @lib.DspNodeKind::Constant)
  assert_true(nodes[1].kind is @lib.DspNodeKind::Oscillator)
  assert_true(nodes[2].kind is @lib.DspNodeKind::Gain)
  assert_true(nodes[3].kind is @lib.DspNodeKind::Biquad)
  assert_true(nodes[4].kind is @lib.DspNodeKind::Output)
}

///|
test "GraphBuilder: adsr * osc pipeline" {
  let env : @lib.GraphBuilder = @lib.DspSym::adsr(10.0, 50.0, 0.7, 200.0)
  let freq : @lib.GraphBuilder = @lib.ArithSym::constant(440.0)
  let osc : @lib.GraphBuilder = @lib.DspSym::oscillator(
    freq,
    @lib.Waveform::Sine,
  )
  let modulated : @lib.GraphBuilder = @lib.ArithSym::mul(env, osc)
  let out : @lib.GraphBuilder = @lib.DspSym::output(modulated)
  let nodes = out.nodes()
  // adsr=0 | const(440)=0, osc(0)=1 -> merged at offset 1
  // result: adsr=0, const(440)=1, osc(1)=2, mul(0,2)=3, output(3)=4
  assert_eq(nodes.length(), 5)
  assert_true(nodes[0].kind is @lib.DspNodeKind::Adsr)
  assert_true(nodes[1].kind is @lib.DspNodeKind::Constant)
  assert_true(nodes[2].kind is @lib.DspNodeKind::Oscillator)
  assert_eq(nodes[2].input0, 1) // remapped: was 0, offset 1, so 1
  assert_true(nodes[3].kind is @lib.DspNodeKind::Mul)
  assert_eq(nodes[3].input0, 0)
  assert_eq(nodes[3].input1, 2)
  assert_true(nodes[4].kind is @lib.DspNodeKind::Output)
  assert_eq(nodes[4].input0, 3)
}

///|
test "replay: Constant+Mul through Eval" {
  let nodes : Array[@lib.DspNode] = [
    @lib.DspNode::constant(3.0),
    @lib.DspNode::constant(4.0),
    @lib.DspNode::mul(0, 1),
  ]
  let result : Eval = @lib.replay(nodes).unwrap()
  assert_eq(result.value, 12.0)
}

///|
test "replay: Gain+Clip+Output through Eval" {
  let nodes : Array[@lib.DspNode] = [
    @lib.DspNode::constant(5.0),
    @lib.DspNode::gain(0, 0.5),
    @lib.DspNode::clip(1, 2.0),
    @lib.DspNode::output(2),
  ]
  let result : Eval = @lib.replay(nodes).unwrap()
  // 5.0 * 0.5 = 2.5, clipped to 2.0
  assert_eq(result.value, 2.0)
}

///|
test "replay: tagless -> GraphBuilder -> replay roundtrip" {
  let a : @lib.GraphBuilder = @lib.ArithSym::constant(3.0)
  let b : @lib.GraphBuilder = @lib.ArithSym::constant(4.0)
  let product : @lib.GraphBuilder = @lib.ArithSym::mul(a, b)
  let result : Eval = @lib.replay(product.nodes()).unwrap()
  assert_eq(result.value, 12.0)
}
