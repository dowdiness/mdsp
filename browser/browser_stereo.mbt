///|
let compiled_stereo_graph : @ref.Ref[@lib.CompiledStereoDsp?] = @ref.new(None)

///|
let compiled_stereo_context : @ref.Ref[@lib.DspContext?] = @ref.new(None)

///|
let compiled_stereo_left : @ref.Ref[@lib.AudioBuffer?] = @ref.new(None)

///|
let compiled_stereo_right : @ref.Ref[@lib.AudioBuffer?] = @ref.new(None)

///|
let compiled_stereo_sample_rate : @ref.Ref[Double] = @ref.new(0.0)

///|
let compiled_stereo_block_size : @ref.Ref[Int] = @ref.new(0)

///|
/// Initialize the browser proof graph that runs through `CompiledStereoDsp`.
pub fn init_compiled_stereo_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  ensure_compiled_stereo_graph(sample_rate, block_size)
}

///|
/// Run one render quantum through the browser proof `CompiledStereoDsp` graph.
pub fn process_compiled_stereo_block(
  freq : Double,
  gain : Double,
  pan : Double,
  delay_samples : Double,
  cutoff : Double,
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if !ensure_compiled_stereo_graph(sample_rate, block_size) {
    return false
  }
  let graph = compiled_stereo_graph.val.unwrap()
  if !graph.apply_controls([
      @lib.GraphControl::set_param(1, @lib.GraphParamSlot::Value0, freq),
      @lib.GraphControl::set_param(
        5,
        @lib.GraphParamSlot::Value0,
        bounded_feedback_gain(gain),
      ),
      @lib.GraphControl::set_param(6, @lib.GraphParamSlot::Value0, pan),
      @lib.GraphControl::set_param(
        7,
        @lib.GraphParamSlot::DelaySamples,
        delay_samples,
      ),
      @lib.GraphControl::set_param(8, @lib.GraphParamSlot::Value0, cutoff),
    ]) {
    return false
  }
  graph.process(
    compiled_stereo_context.val.unwrap(),
    compiled_stereo_left.val.unwrap(),
    compiled_stereo_right.val.unwrap(),
  )
  true
}

///|
/// Read one sample from the most recent compiled stereo left block.
pub fn compiled_stereo_left_sample(index : Int) -> Double {
  checked_sample(index, compiled_stereo_left.val)
}

///|
/// Read one sample from the most recent compiled stereo right block.
pub fn compiled_stereo_right_sample(index : Int) -> Double {
  checked_sample(index, compiled_stereo_right.val)
}

///|
fn ensure_compiled_stereo_graph(sample_rate : Double, block_size : Int) -> Bool {
  if sample_rate <= 0.0 || block_size <= 0 {
    reset_compiled_stereo_graph()
    return false
  }
  if compiled_stereo_graph.val is Some(_) &&
    compiled_stereo_sample_rate.val == sample_rate &&
    compiled_stereo_block_size.val == block_size {
    return true
  }

  let context = @lib.DspContext::new(sample_rate, block_size)
  let left = @lib.AudioBuffer::filled(block_size)
  let right = @lib.AudioBuffer::filled(block_size)
  let nodes = [
    @lib.DspNode::constant(1.0),
    @lib.DspNode::oscillator(@lib.Waveform::Sine, BROWSER_COMPILED_DEFAULT_FREQ),
    @lib.DspNode::gain(1, BROWSER_COMPILED_OSC_GAIN),
    @lib.DspNode::mix(0, 2),
    @lib.DspNode::mix(3, 5),
    @lib.DspNode::gain(4, BROWSER_COMPILED_DEFAULT_GAIN),
    @lib.DspNode::pan(5, BROWSER_COMPILED_DEFAULT_PAN),
    @lib.DspNode::stereo_delay(
      6,
      BROWSER_COMPILED_DELAY_CAPACITY,
      delay_samples=BROWSER_COMPILED_DELAY_SAMPLES,
    ),
    @lib.DspNode::stereo_biquad(
      7,
      @lib.BiquadMode::LowPass,
      BROWSER_COMPILED_DEFAULT_CUTOFF,
      BROWSER_COMPILED_FILTER_Q,
    ),
    @lib.DspNode::stereo_clip(8, BROWSER_COMPILED_CLIP_THRESHOLD),
    @lib.DspNode::stereo_output(9),
  ]
  match @lib.CompiledStereoDsp::compile(nodes, context) {
    Some(graph) => {
      compiled_stereo_graph.val = Some(graph)
      compiled_stereo_context.val = Some(context)
      compiled_stereo_left.val = Some(left)
      compiled_stereo_right.val = Some(right)
      compiled_stereo_sample_rate.val = sample_rate
      compiled_stereo_block_size.val = block_size
      true
    }
    None => {
      reset_compiled_stereo_graph()
      false
    }
  }
}

///|
fn reset_compiled_stereo_graph() -> Unit {
  compiled_stereo_graph.val = None
  compiled_stereo_context.val = None
  compiled_stereo_left.val = None
  compiled_stereo_right.val = None
  compiled_stereo_sample_rate.val = 0.0
  compiled_stereo_block_size.val = 0
}
