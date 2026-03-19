///|
/// Deprecated: Old linked-list feedback edge index builder.
/// Replaced by self-register-based back_edge_input0_source / back_edge_input1_source
/// arrays initialized directly from feedback_edges during compilation.
fn build_feedback_edge_index(
  edges : FixedArray[(Int, Int, Int)],
  input0_edges : FixedArray[Int],
  input1_edges : FixedArray[Int],
  source_heads : FixedArray[Int],
  next_by_source : FixedArray[Int],
) -> Unit {
  for index = 0; index < edges.length(); index = index + 1 {
    let edge = edges[index]
    match edge.2 {
      0 => input0_edges[edge.1] = index
      _ => input1_edges[edge.1] = index
    }
    next_by_source[index] = source_heads[edge.0]
    source_heads[edge.0] = index
  }
}

///|
/// Deprecated: Old mono feedback per-node sample processor.
/// Replaced by inline processing in CompiledDsp::process_feedback_graph
/// which handles both mono and stereo node kinds.
fn process_feedback_graph_node_sample(
  compiled : CompiledDsp,
  context : DspContext,
  sample_rate : Double,
  node_index : Int,
  node : DspNode,
  input0 : Double,
  input1 : Double,
) -> Double {
  match node.kind {
    Constant => node.value0
    Oscillator => {
      let freq = if node.input0 >= 0 { input0 } else { node.value0 }
      compiled.osc_states[node_index]
      .unwrap()
      .tick_waveform(node.waveform, freq, sample_rate)
    }
    Noise => compiled.noise_states[node_index].unwrap().tick()
    Adsr => compiled.env_states[node_index].unwrap().tick(context)
    Biquad => compiled.biquad_states[node_index].unwrap().tick(input0)
    Delay => compiled.delay_states[node_index].unwrap().tick(input0)
    Gain => input0 * node.value0
    Mul => input0 * input1
    Mix => input0 + input1
    Clip => clip_feedback_sample(input0, node.value0)
    Output => input0
    _ => 0.0
  }
}
