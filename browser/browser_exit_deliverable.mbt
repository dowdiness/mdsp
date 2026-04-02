///|
let exit_deliverable_graph : @ref.Ref[@lib.CompiledDsp?] = @ref.new(None)

///|
let exit_deliverable_context : @ref.Ref[@lib.DspContext?] = @ref.new(None)

///|
let exit_deliverable_output : @ref.Ref[@lib.AudioBuffer?] = @ref.new(None)

///|
let exit_deliverable_sample_rate : @ref.Ref[Double] = @ref.new(0.0)

///|
let exit_deliverable_block_size : @ref.Ref[Int] = @ref.new(0)

///|
// WHY this map: node indices are positional after GraphBuilder flattening.
// apply_control targets nodes by index, so this map is needed to aim correctly.
// [0] Constant(2.0)       — LFO rate
// [1] Oscillator(Sine)    — LFO
// [2] Constant(1.0)       — range offset
// [3] Mix(1,2)            — lfo + 1
// [4] Constant(100.0)     — range scale = 0.5*(hi-lo)
// [5] Mul(3,4)            — (lfo+1)*scale
// [6] Constant(200.0)     — range lo
// [7] Mix(5,6)            — modulated freq
// [8] Oscillator(Sine)    — carrier
// [9] Biquad(LowPass)     — filter
// [10] Gain(0.3)          — master gain
// [11] Output
const EXIT_LFO_RATE_NODE : Int = 0

///|
const EXIT_BIQUAD_NODE : Int = 9

///|
const EXIT_GAIN_NODE : Int = 10

///|
let exit_lfo_rate : @ref.Ref[Double] = @ref.new(2.0)

///|
let exit_cutoff : @ref.Ref[Double] = @ref.new(800.0)

///|
let exit_gain : @ref.Ref[Double] = @ref.new(0.3)

///|
/// Initialize the exit deliverable graph: FM synthesis via tagless composition.
pub fn init_exit_deliverable_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  ensure_exit_deliverable_graph(sample_rate, block_size)
}

///|
/// Set the LFO rate (Hz) for the exit deliverable.
pub fn set_exit_deliverable_lfo_rate(rate : Double) -> Bool {
  if rate.is_nan() || rate.is_inf() {
    return false
  }
  exit_lfo_rate.val = rate
  true
}

///|
/// Set the filter cutoff (Hz) for the exit deliverable.
pub fn set_exit_deliverable_cutoff(cutoff : Double) -> Bool {
  if cutoff.is_nan() || cutoff.is_inf() || cutoff < 0.0 {
    return false
  }
  exit_cutoff.val = cutoff
  true
}

///|
/// Set the master gain for the exit deliverable.
pub fn set_exit_deliverable_gain(gain : Double) -> Bool {
  if gain.is_nan() || gain.is_inf() || gain < 0.0 {
    return false
  }
  exit_gain.val = gain
  true
}

///|
/// Run one render quantum through the exit deliverable graph.
pub fn process_exit_deliverable_block(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if !ensure_exit_deliverable_graph(sample_rate, block_size) {
    return false
  }
  let graph = exit_deliverable_graph.val.unwrap()
  // Apply controls individually — batch is transactional and one failure
  // rejects all. Individual controls are independent.
  ignore(
    graph.apply_control(
      @lib.GraphControl::set_param(
        EXIT_LFO_RATE_NODE,
        @lib.GraphParamSlot::Value0,
        exit_lfo_rate.val,
      ),
    ),
  )
  ignore(
    graph.apply_control(
      @lib.GraphControl::set_param(
        EXIT_BIQUAD_NODE,
        @lib.GraphParamSlot::Value0,
        exit_cutoff.val,
      ),
    ),
  )
  ignore(
    graph.apply_control(
      @lib.GraphControl::set_param(
        EXIT_GAIN_NODE,
        @lib.GraphParamSlot::Value0,
        exit_gain.val,
      ),
    ),
  )
  graph.process(
    exit_deliverable_context.val.unwrap(),
    exit_deliverable_output.val.unwrap(),
  )
  true
}

///|
/// Read one sample from the most recent exit deliverable output block.
pub fn exit_deliverable_output_sample(index : Int) -> Double {
  checked_sample(index, exit_deliverable_output.val)
}

///|
fn ensure_exit_deliverable_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if sample_rate <= 0.0 || block_size <= 0 {
    reset_exit_deliverable_graph()
    return false
  }
  if exit_deliverable_graph.val is Some(_) &&
    exit_deliverable_sample_rate.val == sample_rate &&
    exit_deliverable_block_size.val == block_size {
    return true
  }

  let context = @lib.DspContext::new(sample_rate, block_size)
  let output = @lib.AudioBuffer::filled(block_size)
  let builder : @lib.GraphBuilder = @lib.exit_deliverable()
  match @lib.CompiledDsp::compile(builder.nodes(), context) {
    Some(graph) => {
      exit_deliverable_graph.val = Some(graph)
      exit_deliverable_context.val = Some(context)
      exit_deliverable_output.val = Some(output)
      exit_deliverable_sample_rate.val = sample_rate
      exit_deliverable_block_size.val = block_size
      true
    }
    None => {
      reset_exit_deliverable_graph()
      false
    }
  }
}

///|
fn reset_exit_deliverable_graph() -> Unit {
  exit_deliverable_graph.val = None
  exit_deliverable_context.val = None
  exit_deliverable_output.val = None
  exit_deliverable_sample_rate.val = 0.0
  exit_deliverable_block_size.val = 0
  exit_lfo_rate.val = 2.0
  exit_cutoff.val = 800.0
  exit_gain.val = 0.3
}
