///|
/// Browser-export wrapper package that preserves the original Phase 0/1 wasm ABI.
fn main {
  ()
}

///|
const BROWSER_COMPILED_DEFAULT_FREQ : Double = 440.0

///|
const BROWSER_COMPILED_DEFAULT_GAIN : Double = 0.3

///|
const BROWSER_COMPILED_CLIP_THRESHOLD : Double = 0.95

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
/// Reset browser demo state.
pub fn reset_phase() -> Unit {
  @lib.reset_phase()
  reset_compiled_graph()
}

///|
/// Generate one sine sample for the browser demo.
pub fn tick(freq : Double, sample_rate : Double) -> Double {
  @lib.tick(freq, sample_rate)
}

///|
/// Generate one sample from the selected browser demo source.
pub fn tick_source(
  source_id : Int,
  freq : Double,
  sample_rate : Double,
) -> Double {
  @lib.tick_source(source_id, freq, sample_rate)
}

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
  match compiled_output.val {
    Some(output) =>
      if index >= 0 && index < output.length() {
        output.get(index)
      } else {
        0.0
      }
    None => 0.0
  }
}

///|
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
