///|
let compiled_hot_swap : @ref.Ref[@lib.CompiledDspHotSwap?] = @ref.new(None)

///|
let compiled_hot_swap_context : @ref.Ref[@lib.DspContext?] = @ref.new(None)

///|
let compiled_hot_swap_output : @ref.Ref[@lib.AudioBuffer?] = @ref.new(None)

///|
let compiled_hot_swap_sample_rate : @ref.Ref[Double] = @ref.new(0.0)

///|
let compiled_hot_swap_block_size : @ref.Ref[Int] = @ref.new(0)

///|
/// Initialize the browser proof graph that runs through `CompiledDspHotSwap`.
pub fn init_compiled_hot_swap_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  ensure_compiled_hot_swap_graph(sample_rate, block_size)
}

///|
/// Queue the fixed browser hot-swap replacement graph.
pub fn queue_compiled_hot_swap() -> Bool {
  let context = match compiled_hot_swap_context.val {
    Some(context) => context
    None => return false
  }
  let hot_swap = match compiled_hot_swap.val {
    Some(hot_swap) => hot_swap
    None => return false
  }
  let replacement = match
    @lib.CompiledDsp::compile(
      [
        @lib.DspNode::constant(BROWSER_HOT_SWAP_NEW_CONSTANT),
        @lib.DspNode::output(0),
      ],
      context,
    ) {
    Some(replacement) => replacement
    None => return false
  }
  hot_swap.queue_swap(replacement)
}

///|
/// Run one render quantum through the browser proof `CompiledDspHotSwap` graph.
pub fn process_compiled_hot_swap_block(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if !ensure_compiled_hot_swap_graph(sample_rate, block_size) {
    return false
  }
  let hot_swap = compiled_hot_swap.val.unwrap()
  hot_swap.process(
    compiled_hot_swap_context.val.unwrap(),
    compiled_hot_swap_output.val.unwrap(),
  )
  true
}

///|
/// Read one sample from the most recent hot-swap browser output block.
pub fn compiled_hot_swap_output_sample(index : Int) -> Double {
  checked_sample(index, compiled_hot_swap_output.val)
}

///|
fn ensure_compiled_hot_swap_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if sample_rate <= 0.0 || block_size <= 0 {
    reset_compiled_hot_swap_graph()
    return false
  }
  if compiled_hot_swap.val is Some(_) &&
    compiled_hot_swap_sample_rate.val == sample_rate &&
    compiled_hot_swap_block_size.val == block_size {
    return true
  }

  let context = @lib.DspContext::new(sample_rate, block_size)
  let output = @lib.AudioBuffer::filled(block_size)
  let active = match
    @lib.CompiledDsp::compile(
      [
        @lib.DspNode::constant(BROWSER_HOT_SWAP_OLD_CONSTANT),
        @lib.DspNode::output(0),
      ],
      context,
    ) {
    Some(active) => active
    None => {
      reset_compiled_hot_swap_graph()
      return false
    }
  }
  let hot_swap = @lib.CompiledDspHotSwap::from_graph(
    active,
    crossfade_samples=BROWSER_HOT_SWAP_CROSSFADE_SAMPLES,
  )
  compiled_hot_swap.val = Some(hot_swap)
  compiled_hot_swap_context.val = Some(context)
  compiled_hot_swap_output.val = Some(output)
  compiled_hot_swap_sample_rate.val = sample_rate
  compiled_hot_swap_block_size.val = block_size
  true
}

///|
fn reset_compiled_hot_swap_graph() -> Unit {
  compiled_hot_swap.val = None
  compiled_hot_swap_context.val = None
  compiled_hot_swap_output.val = None
  compiled_hot_swap_sample_rate.val = 0.0
  compiled_hot_swap_block_size.val = 0
}
