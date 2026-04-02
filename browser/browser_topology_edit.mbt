///|
let compiled_topology_edit : @ref.Ref[@lib.CompiledDspTopologyController?] = @ref.new(
  None,
)

///|
let compiled_topology_edit_context : @ref.Ref[@lib.DspContext?] = @ref.new(None)

///|
let compiled_topology_edit_output : @ref.Ref[@lib.AudioBuffer?] = @ref.new(None)

///|
let compiled_topology_edit_sample_rate : @ref.Ref[Double] = @ref.new(0.0)

///|
let compiled_topology_edit_block_size : @ref.Ref[Int] = @ref.new(0)

///|
let compiled_topology_edit_gain : @ref.Ref[Double] = @ref.new(
  BROWSER_COMPILED_DEFAULT_GAIN,
)

///|
let compiled_topology_edit_inserted : @ref.Ref[Bool] = @ref.new(false)

///|
/// Initialize the browser proof graph that runs through
/// `CompiledDspTopologyController`.
pub fn init_compiled_topology_edit_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  ensure_compiled_topology_edit_graph(sample_rate, block_size)
}

///|
/// Queue the fixed browser topology edit insertion that appends one gain node
/// before the output.
pub fn queue_compiled_topology_edit() -> Bool {
  let topology = match compiled_topology_edit.val {
    Some(topology) => topology
    None => return false
  }
  if compiled_topology_edit_inserted.val {
    return false
  }
  let queued = topology.queue_topology_edit(
    @lib.GraphTopologyEdit::insert_node(
      1,
      @lib.GraphTopologyInputSlot::Input0,
      @lib.DspNode::gain(0, BROWSER_TOPOLOGY_EDIT_INSERTED_GAIN),
    ),
  )
  if queued {
    compiled_topology_edit_inserted.val = true
  }
  queued
}

///|
/// Queue the fixed browser topology edit deletion that removes the inserted
/// gain node and returns to the baseline graph.
pub fn queue_compiled_topology_delete_edit() -> Bool {
  let topology = match compiled_topology_edit.val {
    Some(topology) => topology
    None => return false
  }
  if !compiled_topology_edit_inserted.val {
    return false
  }
  let queued = topology.queue_topology_edit(
    @lib.GraphTopologyEdit::delete_node(
      2,
      1,
      @lib.GraphTopologyInputSlot::Input0,
      2,
    ),
  )
  if queued {
    compiled_topology_edit_inserted.val = false
  }
  queued
}

///|
/// Update the fixed browser topology-edit gain control.
pub fn set_compiled_topology_edit_gain(gain : Double) -> Bool {
  if compiled_topology_edit.val is None {
    return false
  }
  compiled_topology_edit_gain.val = gain
  true
}

///|
/// Run one render quantum through the browser proof `CompiledDspTopologyController`
/// graph.
pub fn process_compiled_topology_edit_block(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if !ensure_compiled_topology_edit_graph(sample_rate, block_size) {
    return false
  }
  let topology = compiled_topology_edit.val.unwrap()
  if !topology.apply_control(
      @lib.GraphControl::set_param(
        0,
        @lib.GraphParamSlot::Value0,
        compiled_topology_edit_gain.val,
      ),
    ) {
    return false
  }
  topology.process(
    compiled_topology_edit_context.val.unwrap(),
    compiled_topology_edit_output.val.unwrap(),
  )
  true
}

///|
/// Read one sample from the most recent topology-edit browser output block.
pub fn compiled_topology_edit_output_sample(index : Int) -> Double {
  checked_sample(index, compiled_topology_edit_output.val)
}

///|
fn ensure_compiled_topology_edit_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if sample_rate <= 0.0 || block_size <= 0 {
    reset_compiled_topology_edit_graph()
    return false
  }
  if compiled_topology_edit.val is Some(_) &&
    compiled_topology_edit_sample_rate.val == sample_rate &&
    compiled_topology_edit_block_size.val == block_size {
    return true
  }

  let context = @lib.DspContext::new(sample_rate, block_size)
  let output = @lib.AudioBuffer::filled(block_size)
  let topology = match
    @lib.CompiledDspTopologyController::from_nodes(
      [
        @lib.DspNode::constant(BROWSER_COMPILED_DEFAULT_GAIN),
        @lib.DspNode::output(0),
      ],
      context,
      crossfade_samples=BROWSER_TOPOLOGY_EDIT_CROSSFADE_SAMPLES,
    ) {
    Some(topology) => topology
    None => {
      reset_compiled_topology_edit_graph()
      return false
    }
  }
  compiled_topology_edit.val = Some(topology)
  compiled_topology_edit_context.val = Some(context)
  compiled_topology_edit_output.val = Some(output)
  compiled_topology_edit_sample_rate.val = sample_rate
  compiled_topology_edit_block_size.val = block_size
  compiled_topology_edit_gain.val = BROWSER_COMPILED_DEFAULT_GAIN
  compiled_topology_edit_inserted.val = false
  true
}

///|
fn reset_compiled_topology_edit_graph() -> Unit {
  compiled_topology_edit.val = None
  compiled_topology_edit_context.val = None
  compiled_topology_edit_output.val = None
  compiled_topology_edit_sample_rate.val = 0.0
  compiled_topology_edit_block_size.val = 0
  compiled_topology_edit_gain.val = BROWSER_COMPILED_DEFAULT_GAIN
  compiled_topology_edit_inserted.val = false
}
