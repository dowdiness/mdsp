///|
let compiled_graph : @ref.Ref[@lib.CompiledDsp?] = @ref.new(None)

///|
let compiled_context : @ref.Ref[@lib.DspContext?] = @ref.new(None)

///|
let compiled_output : @ref.Ref[@lib.AudioBuffer?] = @ref.new(None)

///|
let compiled_sample_rate : @ref.Ref[Double] = @ref.new(0.0)

///|
let compiled_block_size : @ref.Ref[Int] = @ref.new(0)

///|
/// Initialize the browser proof graph that runs through `CompiledDsp`.
pub fn init_compiled_graph(sample_rate : Double, block_size : Int) -> Bool {
  ensure_compiled_graph(sample_rate, block_size)
}

///|
/// Run one render quantum through the browser proof `CompiledDsp` graph.
pub fn process_compiled_block(
  freq : Double,
  gain : Double,
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if !ensure_compiled_graph(sample_rate, block_size) {
    return false
  }
  let graph = compiled_graph.val.unwrap()
  if !graph.apply_controls([
      @lib.GraphControl::set_param(0, @lib.GraphParamSlot::Value0, freq),
      @lib.GraphControl::set_param(1, @lib.GraphParamSlot::Value0, gain),
    ]) {
    return false
  }
  graph.process(compiled_context.val.unwrap(), compiled_output.val.unwrap())
  true
}

///|
/// Read one sample from the most recent compiled browser output block.
pub fn compiled_output_sample(index : Int) -> Double {
  checked_sample(index, compiled_output.val)
}

///|
/// Lazy-init with cache invalidation: rebuilds the graph only when
/// sample_rate or block_size changes. Avoids allocation on every
/// process call while allowing the JS side to re-init at any time.
/// All other ensure_* functions follow this same pattern.
fn ensure_compiled_graph(sample_rate : Double, block_size : Int) -> Bool {
  if sample_rate <= 0.0 || block_size <= 0 {
    reset_compiled_graph()
    return false
  }
  if compiled_graph.val is Some(_) &&
    compiled_sample_rate.val == sample_rate &&
    compiled_block_size.val == block_size {
    return true
  }

  let context = @lib.DspContext::new(sample_rate, block_size)
  let output = @lib.AudioBuffer::filled(block_size)
  let nodes = [
    @lib.DspNode::oscillator(
      @lib.Waveform::Triangle,
      BROWSER_COMPILED_DEFAULT_FREQ,
    ),
    @lib.DspNode::gain(0, BROWSER_COMPILED_DEFAULT_GAIN),
    @lib.DspNode::clip(1, BROWSER_COMPILED_CLIP_THRESHOLD),
    @lib.DspNode::output(2),
  ]
  match @lib.CompiledDsp::compile(nodes, context) {
    Some(graph) => {
      compiled_graph.val = Some(graph)
      compiled_context.val = Some(context)
      compiled_output.val = Some(output)
      compiled_sample_rate.val = sample_rate
      compiled_block_size.val = block_size
      true
    }
    None => {
      reset_compiled_graph()
      false
    }
  }
}

///|
fn reset_compiled_graph() -> Unit {
  compiled_graph.val = None
  compiled_context.val = None
  compiled_output.val = None
  compiled_sample_rate.val = 0.0
  compiled_block_size.val = 0
}
