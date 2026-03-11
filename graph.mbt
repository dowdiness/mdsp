///|
/// Minimal Phase 2 graph node kinds for compiled mono DSP graphs.
pub(all) enum DspNodeKind {
  Constant
  Oscillator
  Noise
  Gain
  Mix
  Clip
  Output
}

///|
/// Declarative DSP graph node in authoring order.
pub struct DspNode {
  kind : DspNodeKind
  input0 : Int
  input1 : Int
  value0 : Double
  waveform : Waveform
  seed : UInt

  fn new(
    kind : DspNodeKind,
    input0 : Int,
    input1 : Int,
    value0 : Double,
    waveform : Waveform,
    seed : UInt,
  ) -> DspNode
}

///|
fn DspNode::new(
  kind : DspNodeKind,
  input0 : Int,
  input1 : Int,
  value0 : Double,
  waveform : Waveform,
  seed : UInt,
) -> DspNode {
  { kind, input0, input1, value0, waveform, seed }
}

///|
/// Executable buffer-based DSP graph compiled from `DspNode`s.
struct CompiledDsp {
  nodes : FixedArray[DspNode]
  buffers : FixedArray[AudioBuffer]
  osc_states : FixedArray[Oscillator?]
  noise_states : FixedArray[Noise?]
}

///|
/// Create a constant-value node.
pub fn DspNode::constant(value : Double) -> DspNode {
  DspNode(DspNodeKind::Constant, -1, -1, value, Waveform::Sine, 0U)
}

///|
/// Create an oscillator node with a fixed frequency.
pub fn DspNode::oscillator(waveform : Waveform, freq : Double) -> DspNode {
  DspNode(DspNodeKind::Oscillator, -1, -1, freq, waveform, 0U)
}

///|
/// Create a white-noise source node.
pub fn DspNode::noise(seed : UInt) -> DspNode {
  DspNode(DspNodeKind::Noise, -1, -1, 0.0, Waveform::Sine, seed)
}

///|
/// Create an in-place gain node from one upstream node.
pub fn DspNode::gain(input : Int, amount : Double) -> DspNode {
  DspNode(DspNodeKind::Gain, input, -1, amount, Waveform::Sine, 0U)
}

///|
/// Create a mix node from two upstream nodes.
pub fn DspNode::mix(left : Int, right : Int) -> DspNode {
  DspNode(DspNodeKind::Mix, left, right, 0.0, Waveform::Sine, 0U)
}

///|
/// Create a clip node from one upstream node.
pub fn DspNode::clip(input : Int, threshold : Double) -> DspNode {
  DspNode(DspNodeKind::Clip, input, -1, threshold, Waveform::Sine, 0U)
}

///|
/// Mark the final output node.
pub fn DspNode::output(input : Int) -> DspNode {
  DspNode(DspNodeKind::Output, input, -1, 0.0, Waveform::Sine, 0U)
}

///|
/// Compile a declarative mono graph into an executable buffer graph.
///
/// This first Phase 2 slice accepts nodes in authoring order, requires exactly
/// one reachable `Output` node, rejects cycles, and rejects graphs containing
/// unreachable nodes.
pub fn CompiledDsp::compile(
  nodes : Array[DspNode],
  context : DspContext,
) -> CompiledDsp? {
  let sorted_nodes = match topo_sorted_nodes(nodes) {
    Some(sorted_nodes) => sorted_nodes
    None => return None
  }
  let node_count = nodes.length()
  let block_size = compiled_block_size(context)
  let fixed_nodes = FixedArray::makei(node_count, index => sorted_nodes[index])
  let buffers = FixedArray::makei(node_count, _ => {
    AudioBuffer::filled(block_size)
  })
  let osc_states = FixedArray::makei(node_count, index => {
    make_graph_osc_state(sorted_nodes[index])
  })
  let noise_states = FixedArray::makei(node_count, index => {
    make_graph_noise_state(sorted_nodes[index])
  })
  Some({ nodes: fixed_nodes, buffers, osc_states, noise_states })
}

///|
/// Run the compiled graph for one buffer and write the final output into
/// `output`.
pub fn CompiledDsp::process(
  self : CompiledDsp,
  context : DspContext,
  output : AudioBuffer,
) -> Unit {
  let sample_rate = context.sample_rate()
  let sample_count = compiled_sample_count(context, output)
  if !valid_compiled_context(sample_rate) ||
    sample_count <= 0 ||
    sample_count > self.compiled_buffer_capacity() {
    clear_compiled_buffers(self.buffers)
    output.fill(0.0)
    return
  }

  for index = 0; index < self.nodes.length(); index = index + 1 {
    let node = self.nodes[index]
    let buffer = self.buffers[index]
    match node.kind {
      Constant => fill_constant_buffer(buffer, sample_count, node.value0)
      Oscillator =>
        self.osc_states[index]
        .unwrap()
        .process_waveform(context, buffer, node.waveform, node.value0)
      Noise => self.noise_states[index].unwrap().process(context, buffer)
      Gain => {
        copy_buffer(self.buffers[node.input0], buffer, sample_count)
        apply_gain_buffer(buffer, sample_count, node.value0)
      }
      Mix =>
        mix_buffers(
          self.buffers[node.input0],
          self.buffers[node.input1],
          buffer,
          sample_count,
        )
      Clip => {
        copy_buffer(self.buffers[node.input0], buffer, sample_count)
        clip_buffer(buffer, sample_count, node.value0)
      }
      Output => copy_buffer(self.buffers[node.input0], buffer, sample_count)
    }
  }

  copy_buffer(self.buffers[self.buffers.length() - 1], output, sample_count)
}

///|
fn valid_compiled_graph(nodes : Array[DspNode]) -> Bool {
  let output_index = match find_single_output_index(nodes) {
    Some(output_index) => output_index
    None => return false
  }
  if nodes.is_empty() {
    return false
  }

  for index = 0; index < nodes.length(); index = index + 1 {
    let node = nodes[index]
    if !valid_node_inputs(node, nodes.length()) {
      return false
    }
  }

  has_reachable_acyclic_graph(nodes, output_index)
}

///|
fn valid_node_inputs(node : DspNode, node_count : Int) -> Bool {
  match node.kind {
    Constant => valid_finite_value(node.value0)
    Oscillator => valid_finite_value(node.value0)
    Noise => true
    Gain =>
      valid_reference(node.input0, node_count) &&
      valid_finite_value(node.value0)
    Mix =>
      valid_reference(node.input0, node_count) &&
      valid_reference(node.input1, node_count)
    Clip =>
      valid_reference(node.input0, node_count) &&
      valid_finite_value(node.value0) &&
      node.value0 > 0.0
    Output => valid_reference(node.input0, node_count)
  }
}

///|
fn valid_reference(input : Int, node_count : Int) -> Bool {
  input >= 0 && input < node_count
}

///|
fn CompiledDsp::compiled_buffer_capacity(self : CompiledDsp) -> Int {
  if self.buffers.length() == 0 {
    0
  } else {
    self.buffers[0].length()
  }
}

///|
fn valid_finite_value(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn topo_sorted_nodes(nodes : Array[DspNode]) -> Array[DspNode]? {
  if !valid_compiled_graph(nodes) {
    return None
  }

  let output_index = find_single_output_index(nodes).unwrap()
  let marks = FixedArray::make(nodes.length(), 0)
  let order = Array::new()
  if !visit_graph_node(output_index, nodes, marks, order) {
    return None
  }
  if order.length() != nodes.length() {
    return None
  }

  let remap = FixedArray::make(nodes.length(), -1)
  for new_index = 0; new_index < order.length(); new_index = new_index + 1 {
    remap[order[new_index]] = new_index
  }

  let sorted = Array::new()
  for new_index = 0; new_index < order.length(); new_index = new_index + 1 {
    sorted.push(remap_node_inputs(nodes[order[new_index]], remap))
  }
  Some(sorted)
}

///|
fn find_single_output_index(nodes : Array[DspNode]) -> Int? {
  let mut output_index = -1
  for index = 0; index < nodes.length(); index = index + 1 {
    if nodes[index].kind is DspNodeKind::Output {
      if output_index >= 0 {
        return None
      }
      output_index = index
    }
  }
  if output_index >= 0 {
    Some(output_index)
  } else {
    None
  }
}

///|
fn has_reachable_acyclic_graph(
  nodes : Array[DspNode],
  output_index : Int,
) -> Bool {
  let marks = FixedArray::make(nodes.length(), 0)
  let order = Array::new()
  if !visit_graph_node(output_index, nodes, marks, order) {
    return false
  }
  order.length() == nodes.length()
}

///|
fn visit_graph_node(
  index : Int,
  nodes : Array[DspNode],
  marks : FixedArray[Int],
  order : Array[Int],
) -> Bool {
  match marks[index] {
    1 => false
    2 => true
    _ => {
      marks[index] = 1
      if !visit_graph_dependencies(nodes[index], nodes, marks, order) {
        return false
      }
      marks[index] = 2
      order.push(index)
      true
    }
  }
}

///|
fn visit_graph_dependencies(
  node : DspNode,
  nodes : Array[DspNode],
  marks : FixedArray[Int],
  order : Array[Int],
) -> Bool {
  match node.kind {
    Constant => true
    Oscillator => true
    Noise => true
    Gain => visit_graph_node(node.input0, nodes, marks, order)
    Mix =>
      visit_graph_node(node.input0, nodes, marks, order) &&
      visit_graph_node(node.input1, nodes, marks, order)
    Clip => visit_graph_node(node.input0, nodes, marks, order)
    Output => visit_graph_node(node.input0, nodes, marks, order)
  }
}

///|
fn remap_node_inputs(node : DspNode, remap : FixedArray[Int]) -> DspNode {
  DspNode(
    node.kind,
    remapped_input(node.input0, remap),
    remapped_input(node.input1, remap),
    node.value0,
    node.waveform,
    node.seed,
  )
}

///|
fn remapped_input(input : Int, remap : FixedArray[Int]) -> Int {
  if input >= 0 {
    remap[input]
  } else {
    -1
  }
}

///|
fn compiled_block_size(context : DspContext) -> Int {
  if context.block_size() > 0 {
    context.block_size()
  } else {
    1
  }
}

///|
fn compiled_sample_count(context : DspContext, output : AudioBuffer) -> Int {
  if output.length() < context.block_size() {
    output.length()
  } else {
    context.block_size()
  }
}

///|
fn valid_compiled_context(sample_rate : Double) -> Bool {
  !sample_rate.is_nan() && !sample_rate.is_inf() && sample_rate > 0.0
}

///|
fn copy_buffer(
  source : AudioBuffer,
  target : AudioBuffer,
  sample_count : Int,
) -> Unit {
  let bounded = if sample_count < source.length() {
    if sample_count < target.length() {
      sample_count
    } else {
      target.length()
    }
  } else if source.length() < target.length() {
    source.length()
  } else {
    target.length()
  }

  for index = 0; index < bounded; index = index + 1 {
    target.set(index, source.get(index))
  }

  for index = bounded; index < target.length(); index = index + 1 {
    target.set(index, 0.0)
  }
}

///|
fn fill_constant_buffer(
  buffer : AudioBuffer,
  sample_count : Int,
  value : Double,
) -> Unit {
  let bounded = if sample_count < buffer.length() {
    sample_count
  } else {
    buffer.length()
  }
  for index = 0; index < bounded; index = index + 1 {
    buffer.set(index, value)
  }
  for index = bounded; index < buffer.length(); index = index + 1 {
    buffer.set(index, 0.0)
  }
}

///|
fn apply_gain_buffer(
  buffer : AudioBuffer,
  sample_count : Int,
  amount : Double,
) -> Unit {
  let bounded = if sample_count < buffer.length() {
    sample_count
  } else {
    buffer.length()
  }
  for index = 0; index < bounded; index = index + 1 {
    buffer.set(index, buffer.get(index) * amount)
  }
  for index = bounded; index < buffer.length(); index = index + 1 {
    buffer.set(index, 0.0)
  }
}

///|
fn mix_buffers(
  left : AudioBuffer,
  right : AudioBuffer,
  output : AudioBuffer,
  sample_count : Int,
) -> Unit {
  let bounded = min_buffer_length(
    sample_count,
    left.length(),
    right.length(),
    output.length(),
  )
  for index = 0; index < bounded; index = index + 1 {
    output.set(index, left.get(index) + right.get(index))
  }
  for index = bounded; index < output.length(); index = index + 1 {
    output.set(index, 0.0)
  }
}

///|
fn clip_buffer(
  buffer : AudioBuffer,
  sample_count : Int,
  threshold : Double,
) -> Unit {
  let bounded = if sample_count < buffer.length() {
    sample_count
  } else {
    buffer.length()
  }
  for index = 0; index < bounded; index = index + 1 {
    let sample = buffer.get(index)
    let clipped = if sample > threshold {
      threshold
    } else if sample < -threshold {
      -threshold
    } else {
      sample
    }
    buffer.set(index, clipped)
  }
  for index = bounded; index < buffer.length(); index = index + 1 {
    buffer.set(index, 0.0)
  }
}

///|
fn min_buffer_length(a : Int, b : Int, c : Int, d : Int) -> Int {
  let ab = if a < b { a } else { b }
  let cd = if c < d { c } else { d }
  if ab < cd {
    ab
  } else {
    cd
  }
}

///|
fn make_graph_osc_state(node : DspNode) -> Oscillator? {
  match node.kind {
    Oscillator => Some(Oscillator::new())
    _ => None
  }
}

///|
fn make_graph_noise_state(node : DspNode) -> Noise? {
  match node.kind {
    Noise => Some(Noise::new(node.seed))
    _ => None
  }
}

///|
fn clear_compiled_buffers(buffers : FixedArray[AudioBuffer]) -> Unit {
  for index = 0; index < buffers.length(); index = index + 1 {
    buffers[index].fill(0.0)
  }
}
