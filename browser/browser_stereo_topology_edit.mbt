///|
let compiled_stereo_topology_edit : @ref.Ref[
  @lib.CompiledStereoDspTopologyController?,
] = @ref.new(None)

///|
let compiled_stereo_topology_edit_context : @ref.Ref[@lib.DspContext?] = @ref.new(
  None,
)

///|
let compiled_stereo_topology_edit_left : @ref.Ref[@lib.AudioBuffer?] = @ref.new(
  None,
)

///|
let compiled_stereo_topology_edit_right : @ref.Ref[@lib.AudioBuffer?] = @ref.new(
  None,
)

///|
let compiled_stereo_topology_edit_sample_rate : @ref.Ref[Double] = @ref.new(0.0)

///|
let compiled_stereo_topology_edit_block_size : @ref.Ref[Int] = @ref.new(0)

///|
let compiled_stereo_topology_edit_level : @ref.Ref[Double] = @ref.new(1.0)

///|
/// Initialize the browser proof graph that runs through
/// `CompiledStereoDspTopologyController`.
pub fn init_compiled_stereo_topology_edit_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  ensure_compiled_stereo_topology_edit_graph(sample_rate, block_size)
}

///|
/// Queue the fixed browser stereo topology edit that replaces the pan node.
/// WHY no idempotency guard (unlike mono topology_edit's `inserted` bool):
/// replace_node is inherently idempotent — replacing with the same node is a no-op.
pub fn queue_compiled_stereo_topology_edit() -> Bool {
  let topology = match compiled_stereo_topology_edit.val {
    Some(topology) => topology
    None => return false
  }
  topology.queue_topology_edit(
    @lib.GraphTopologyEdit::replace_node(
      1,
      @lib.DspNode::pan(0, BROWSER_STEREO_TOPOLOGY_EDIT_NEW_PAN),
    ),
  )
}

///|
/// Update the fixed browser stereo topology-edit level control.
pub fn set_compiled_stereo_topology_edit_level(level : Double) -> Bool {
  if compiled_stereo_topology_edit.val is None {
    return false
  }
  compiled_stereo_topology_edit_level.val = level
  true
}

///|
/// Run one render quantum through the browser proof
/// `CompiledStereoDspTopologyController` graph.
pub fn process_compiled_stereo_topology_edit_block(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if !ensure_compiled_stereo_topology_edit_graph(sample_rate, block_size) {
    return false
  }
  let topology = compiled_stereo_topology_edit.val.unwrap()
  if !topology.apply_control(
      @lib.GraphControl::set_param(
        0,
        @lib.GraphParamSlot::Value0,
        compiled_stereo_topology_edit_level.val,
      ),
    ) {
    return false
  }
  topology.process(
    compiled_stereo_topology_edit_context.val.unwrap(),
    compiled_stereo_topology_edit_left.val.unwrap(),
    compiled_stereo_topology_edit_right.val.unwrap(),
  )
  true
}

///|
/// Read one sample from the most recent stereo topology-edit browser left block.
pub fn compiled_stereo_topology_edit_left_sample(index : Int) -> Double {
  checked_sample(index, compiled_stereo_topology_edit_left.val)
}

///|
/// Read one sample from the most recent stereo topology-edit browser right block.
pub fn compiled_stereo_topology_edit_right_sample(index : Int) -> Double {
  checked_sample(index, compiled_stereo_topology_edit_right.val)
}

///|
fn ensure_compiled_stereo_topology_edit_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if sample_rate <= 0.0 || block_size <= 0 {
    reset_compiled_stereo_topology_edit_graph()
    return false
  }
  if compiled_stereo_topology_edit.val is Some(_) &&
    compiled_stereo_topology_edit_sample_rate.val == sample_rate &&
    compiled_stereo_topology_edit_block_size.val == block_size {
    return true
  }

  let context = @lib.DspContext::new(sample_rate, block_size)
  let left = @lib.AudioBuffer::filled(block_size)
  let right = @lib.AudioBuffer::filled(block_size)
  let topology = match
    @lib.CompiledStereoDspTopologyController::from_nodes(
      [
        @lib.DspNode::constant(1.0),
        @lib.DspNode::pan(0, BROWSER_STEREO_TOPOLOGY_EDIT_OLD_PAN),
        @lib.DspNode::stereo_output(1),
      ],
      context,
      crossfade_samples=BROWSER_STEREO_TOPOLOGY_EDIT_CROSSFADE_SAMPLES,
    ) {
    Some(topology) => topology
    None => {
      reset_compiled_stereo_topology_edit_graph()
      return false
    }
  }
  compiled_stereo_topology_edit.val = Some(topology)
  compiled_stereo_topology_edit_context.val = Some(context)
  compiled_stereo_topology_edit_left.val = Some(left)
  compiled_stereo_topology_edit_right.val = Some(right)
  compiled_stereo_topology_edit_sample_rate.val = sample_rate
  compiled_stereo_topology_edit_block_size.val = block_size
  compiled_stereo_topology_edit_level.val = 1.0
  true
}

///|
fn reset_compiled_stereo_topology_edit_graph() -> Unit {
  compiled_stereo_topology_edit.val = None
  compiled_stereo_topology_edit_context.val = None
  compiled_stereo_topology_edit_left.val = None
  compiled_stereo_topology_edit_right.val = None
  compiled_stereo_topology_edit_sample_rate.val = 0.0
  compiled_stereo_topology_edit_block_size.val = 0
  compiled_stereo_topology_edit_level.val = 1.0
}
