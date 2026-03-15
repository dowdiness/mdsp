///|
/// Narrow topology-edit kinds for compiled mono graphs.
pub(all) enum GraphTopologyEditKind {
  ReplaceNode
}

///|
/// Declarative topology edit applied in authoring order before recompilation.
pub struct GraphTopologyEdit {
  kind : GraphTopologyEditKind
  node_index : Int
  replacement : DspNode

  fn new(
    kind : GraphTopologyEditKind,
    node_index : Int,
    replacement : DspNode,
  ) -> GraphTopologyEdit
}

///|
fn GraphTopologyEdit::new(
  kind : GraphTopologyEditKind,
  node_index : Int,
  replacement : DspNode,
) -> GraphTopologyEdit {
  { kind, node_index, replacement }
}

///|
/// Replace one authoring-order node, including its kind and input wiring.
pub fn GraphTopologyEdit::replace_node(
  node_index : Int,
  replacement : DspNode,
) -> GraphTopologyEdit {
  GraphTopologyEdit(GraphTopologyEditKind::ReplaceNode, node_index, replacement)
}

///|
/// Mono topology-edit wrapper that recompiles authoring nodes and stages the
/// replacement through `CompiledDspHotSwap`.
///
/// This first slice keeps edits narrow and deterministic: only `ReplaceNode`
/// frames are supported, the graph length stays fixed, and only one staged
/// topology replacement may be pending at a time.
struct CompiledDspTopologyController {
  mut authoring_nodes : Array[DspNode]
  compile_sample_rate : Double
  compile_block_size : Int
  hot_swap : CompiledDspHotSwap
}

///|
/// Build a topology-edit wrapper from authoring-order mono nodes.
pub fn CompiledDspTopologyController::from_nodes(
  nodes : Array[DspNode],
  context : DspContext,
  crossfade_samples? : Int = 0,
) -> CompiledDspTopologyController? {
  let compiled = match CompiledDsp::compile(nodes, context) {
    Some(compiled) => compiled
    None => return None
  }
  Some(
    make_compiled_dsp_topology_controller(
      nodes.copy(),
      context.sample_rate(),
      context.block_size(),
      CompiledDspHotSwap::from_graph(compiled, crossfade_samples~),
    ),
  )
}

///|
/// Apply one runtime control message to the active or in-flight mono graph.
pub fn CompiledDspTopologyController::apply_control(
  self : CompiledDspTopologyController,
  control : GraphControl,
) -> Bool {
  let updated_authoring_nodes = match
    topology_control_updated_nodes(
      self.authoring_nodes,
      self.compile_sample_rate,
      [control],
    ) {
    Some(updated_authoring_nodes) => updated_authoring_nodes
    None => return false
  }
  if !self.hot_swap.apply_control(control) {
    return false
  }
  self.authoring_nodes = updated_authoring_nodes
  true
}

///|
/// Apply a batch of runtime control messages to the active or in-flight mono
/// graph.
pub fn CompiledDspTopologyController::apply_controls(
  self : CompiledDspTopologyController,
  controls : Array[GraphControl],
) -> Bool {
  let updated_authoring_nodes = match
    topology_control_updated_nodes(
      self.authoring_nodes,
      self.compile_sample_rate,
      controls,
    ) {
    Some(updated_authoring_nodes) => updated_authoring_nodes
    None => return false
  }
  if !self.hot_swap.apply_controls(controls) {
    return false
  }
  self.authoring_nodes = updated_authoring_nodes
  true
}

///|
/// Queue one topology edit for the next hot-swap recompilation.
pub fn CompiledDspTopologyController::queue_topology_edit(
  self : CompiledDspTopologyController,
  edit : GraphTopologyEdit,
) -> Bool {
  self.queue_topology_edits([edit])
}

///|
/// Queue an ordered topology-edit batch.
///
/// The batch is transactional: invalid node indices or a recompilation failure
/// reject the whole edit set and leave the current graph unchanged.
pub fn CompiledDspTopologyController::queue_topology_edits(
  self : CompiledDspTopologyController,
  edits : Array[GraphTopologyEdit],
) -> Bool {
  if self.hot_swap.pending is Some(_) {
    return false
  }
  let edited_nodes = self.authoring_nodes.copy()
  if !apply_topology_edits(edited_nodes, edits) {
    return false
  }
  let compile_context = DspContext::new(
    self.compile_sample_rate,
    self.compile_block_size,
  )
  let replacement = match CompiledDsp::compile(edited_nodes, compile_context) {
    Some(replacement) => replacement
    None => return false
  }
  if !self.hot_swap.queue_swap(replacement) {
    return false
  }
  self.authoring_nodes = edited_nodes
  true
}

///|
/// Process one block through the active or crossfading mono graph.
pub fn CompiledDspTopologyController::process(
  self : CompiledDspTopologyController,
  context : DspContext,
  output : AudioBuffer,
) -> Unit {
  self.hot_swap.process(context, output)
}

///|
fn apply_topology_edits(
  nodes : Array[DspNode],
  edits : Array[GraphTopologyEdit],
) -> Bool {
  for index = 0; index < edits.length(); index = index + 1 {
    if !apply_topology_edit(nodes, edits[index]) {
      return false
    }
  }
  true
}

///|
fn apply_topology_edit(
  nodes : Array[DspNode],
  edit : GraphTopologyEdit,
) -> Bool {
  match edit.kind {
    GraphTopologyEditKind::ReplaceNode =>
      if edit.node_index < 0 || edit.node_index >= nodes.length() {
        false
      } else {
        nodes[edit.node_index] = edit.replacement
        true
      }
  }
}

///|
fn make_compiled_dsp_topology_controller(
  authoring_nodes : Array[DspNode],
  compile_sample_rate : Double,
  compile_block_size : Int,
  hot_swap : CompiledDspHotSwap,
) -> CompiledDspTopologyController {
  { authoring_nodes, compile_sample_rate, compile_block_size, hot_swap }
}

///|
/// Terminal-stereo topology-edit wrapper that recompiles authoring nodes and
/// stages the replacement through `CompiledStereoDspHotSwap`.
///
/// This stereo parity slice keeps the same narrow semantics as the mono
/// controller: only `ReplaceNode` frames are supported, graph length stays
/// fixed, and only one staged topology replacement may be pending at a time.
struct CompiledStereoDspTopologyController {
  mut authoring_nodes : Array[DspNode]
  compile_sample_rate : Double
  compile_block_size : Int
  hot_swap : CompiledStereoDspHotSwap
}

///|
/// Build a topology-edit wrapper from authoring-order terminal-stereo nodes.
pub fn CompiledStereoDspTopologyController::from_nodes(
  nodes : Array[DspNode],
  context : DspContext,
  crossfade_samples? : Int = 0,
) -> CompiledStereoDspTopologyController? {
  let compiled = match CompiledStereoDsp::compile(nodes, context) {
    Some(compiled) => compiled
    None => return None
  }
  Some(
    make_compiled_stereo_dsp_topology_controller(
      nodes.copy(),
      context.sample_rate(),
      context.block_size(),
      CompiledStereoDspHotSwap::from_graph(compiled, crossfade_samples~),
    ),
  )
}

///|
/// Apply one runtime control message to the active or in-flight stereo graph.
pub fn CompiledStereoDspTopologyController::apply_control(
  self : CompiledStereoDspTopologyController,
  control : GraphControl,
) -> Bool {
  let updated_authoring_nodes = match
    topology_control_updated_nodes(
      self.authoring_nodes,
      self.compile_sample_rate,
      [control],
    ) {
    Some(updated_authoring_nodes) => updated_authoring_nodes
    None => return false
  }
  if !self.hot_swap.apply_control(control) {
    return false
  }
  self.authoring_nodes = updated_authoring_nodes
  true
}

///|
/// Apply a batch of runtime control messages to the active or in-flight stereo
/// graph.
pub fn CompiledStereoDspTopologyController::apply_controls(
  self : CompiledStereoDspTopologyController,
  controls : Array[GraphControl],
) -> Bool {
  let updated_authoring_nodes = match
    topology_control_updated_nodes(
      self.authoring_nodes,
      self.compile_sample_rate,
      controls,
    ) {
    Some(updated_authoring_nodes) => updated_authoring_nodes
    None => return false
  }
  if !self.hot_swap.apply_controls(controls) {
    return false
  }
  self.authoring_nodes = updated_authoring_nodes
  true
}

///|
/// Queue one topology edit for the next stereo hot-swap recompilation.
pub fn CompiledStereoDspTopologyController::queue_topology_edit(
  self : CompiledStereoDspTopologyController,
  edit : GraphTopologyEdit,
) -> Bool {
  self.queue_topology_edits([edit])
}

///|
/// Queue an ordered stereo topology-edit batch.
///
/// The batch is transactional: invalid node indices or a recompilation failure
/// reject the whole edit set and leave the current graph unchanged.
pub fn CompiledStereoDspTopologyController::queue_topology_edits(
  self : CompiledStereoDspTopologyController,
  edits : Array[GraphTopologyEdit],
) -> Bool {
  if self.hot_swap.pending is Some(_) {
    return false
  }
  let edited_nodes = self.authoring_nodes.copy()
  if !apply_topology_edits(edited_nodes, edits) {
    return false
  }
  let compile_context = DspContext::new(
    self.compile_sample_rate,
    self.compile_block_size,
  )
  let replacement = match
    CompiledStereoDsp::compile(edited_nodes, compile_context) {
    Some(replacement) => replacement
    None => return false
  }
  if !self.hot_swap.queue_swap(replacement) {
    return false
  }
  self.authoring_nodes = edited_nodes
  true
}

///|
/// Process one block through the active or crossfading stereo graph.
pub fn CompiledStereoDspTopologyController::process(
  self : CompiledStereoDspTopologyController,
  context : DspContext,
  left_output : AudioBuffer,
  right_output : AudioBuffer,
) -> Unit {
  self.hot_swap.process(context, left_output, right_output)
}

///|
fn make_compiled_stereo_dsp_topology_controller(
  authoring_nodes : Array[DspNode],
  compile_sample_rate : Double,
  compile_block_size : Int,
  hot_swap : CompiledStereoDspHotSwap,
) -> CompiledStereoDspTopologyController {
  { authoring_nodes, compile_sample_rate, compile_block_size, hot_swap }
}

///|
fn topology_control_updated_nodes(
  authoring_nodes : Array[DspNode],
  compile_sample_rate : Double,
  controls : Array[GraphControl],
) -> Array[DspNode]? {
  let updated_nodes = authoring_nodes.copy()
  for index = 0; index < controls.length(); index = index + 1 {
    if !apply_topology_runtime_control(
        updated_nodes,
        compile_sample_rate,
        controls[index],
      ) {
      return None
    }
  }
  Some(updated_nodes)
}

///|
fn apply_topology_runtime_control(
  nodes : Array[DspNode],
  compile_sample_rate : Double,
  control : GraphControl,
) -> Bool {
  match control.kind {
    SetParam => {
      if control.node_index < 0 || control.node_index >= nodes.length() {
        return false
      }
      let updated = match
        updated_node_param(
          nodes[control.node_index],
          control.slot,
          control.value,
          compile_sample_rate,
        ) {
        Some(updated) => updated
        None => return false
      }
      nodes[control.node_index] = updated
      true
    }
    _ => true
  }
}
