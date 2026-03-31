///|
test "fold constants: Mul(Constant, Constant) -> Constant" {
  let nodes : Array[@lib.DspNode] = [
    @lib.DspNode::constant(3.0),
    @lib.DspNode::constant(4.0),
    @lib.DspNode::mul(0, 1),
    @lib.DspNode::output(2),
  ]
  let (optimized, _) = @lib.optimize_graph(nodes)
  assert_eq(optimized.length(), 2) // Constant(12) + Output
  assert_true(optimized[0].kind is @lib.DspNodeKind::Constant)
  assert_eq(optimized[0].value0, 12.0)
}

///|
test "fold constants: Gain(Constant, amount) -> Constant" {
  let nodes : Array[@lib.DspNode] = [
    @lib.DspNode::constant(10.0),
    @lib.DspNode::gain(0, 0.5),
    @lib.DspNode::output(1),
  ]
  let (optimized, _) = @lib.optimize_graph(nodes)
  assert_eq(optimized.length(), 2) // Constant(5) + Output
  assert_true(optimized[0].kind is @lib.DspNodeKind::Constant)
  assert_eq(optimized[0].value0, 5.0)
}

///|
test "fold constants: stateful nodes not folded" {
  let nodes : Array[@lib.DspNode] = [
    @lib.DspNode::oscillator(@lib.Waveform::Sine, 440.0),
    @lib.DspNode::output(0),
  ]
  let (optimized, _) = @lib.optimize_graph(nodes)
  assert_eq(optimized.length(), 2) // unchanged
}

///|
test "dead-node elimination: removes unreachable nodes" {
  let nodes : Array[@lib.DspNode] = [
    @lib.DspNode::constant(1.0), // 0: reachable
    @lib.DspNode::constant(999.0), // 1: dead (not referenced)
    @lib.DspNode::output(0), // 2: reachable
  ]
  let (optimized, _) = @lib.optimize_graph(nodes)
  assert_eq(optimized.length(), 2) // Constant(1) + Output
}

///|
test "optimize: range subgraph with constant input collapses" {
  // range(constant(-1.0), 200, 400) should fold to ~Constant(200.0)
  let input : @lib.GraphBuilder = @lib.ArithSym::constant(-1.0)
  let mapped = @lib.range(input, 200.0, 400.0)
  let output : @lib.GraphBuilder = @lib.DspSym::output(mapped)
  let (optimized, _) = @lib.optimize_graph(output.nodes())
  assert_true(optimized.length() < output.nodes().length())
}

///|
test "optimize: index_map tracks original to optimized indices" {
  let nodes : Array[@lib.DspNode] = [
    @lib.DspNode::constant(3.0), // 0 -> folds away
    @lib.DspNode::constant(4.0), // 1 -> folds away
    @lib.DspNode::mul(0, 1), // 2 -> becomes Constant(12.0) at index 0
    @lib.DspNode::output(2), // 3 -> Output at index 1
  ]
  let (_, index_map) = @lib.optimize_graph(nodes)
  // Original indices 0, 1 should map to -1 (eliminated)
  // Original index 2 should map to 0 (the folded Constant)
  // Original index 3 should map to 1 (the Output)
  assert_eq(index_map[0], -1)
  assert_eq(index_map[1], -1)
  assert_eq(index_map[2], 0)
  assert_eq(index_map[3], 1)
}
