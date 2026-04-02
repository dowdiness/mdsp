///|
let compiled_stereo_hot_swap : @ref.Ref[@lib.CompiledStereoDspHotSwap?] = @ref.new(
  None,
)

///|
let compiled_stereo_hot_swap_context : @ref.Ref[@lib.DspContext?] = @ref.new(
  None,
)

///|
let compiled_stereo_hot_swap_left : @ref.Ref[@lib.AudioBuffer?] = @ref.new(None)

///|
let compiled_stereo_hot_swap_right : @ref.Ref[@lib.AudioBuffer?] = @ref.new(
  None,
)

///|
let compiled_stereo_hot_swap_sample_rate : @ref.Ref[Double] = @ref.new(0.0)

///|
let compiled_stereo_hot_swap_block_size : @ref.Ref[Int] = @ref.new(0)

///|
/// Initialize the browser proof graph that runs through `CompiledStereoDspHotSwap`.
pub fn init_compiled_stereo_hot_swap_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  ensure_compiled_stereo_hot_swap_graph(sample_rate, block_size)
}

///|
/// Queue the fixed browser stereo hot-swap replacement graph.
pub fn queue_compiled_stereo_hot_swap() -> Bool {
  let context = match compiled_stereo_hot_swap_context.val {
    Some(context) => context
    None => return false
  }
  let hot_swap = match compiled_stereo_hot_swap.val {
    Some(hot_swap) => hot_swap
    None => return false
  }
  let replacement = match
    @lib.CompiledStereoDsp::compile(
      [
        @lib.DspNode::constant(BROWSER_STEREO_HOT_SWAP_NEW_CONSTANT),
        @lib.DspNode::pan(0, 0.0),
        @lib.DspNode::stereo_output(1),
      ],
      context,
    ) {
    Some(replacement) => replacement
    None => return false
  }
  hot_swap.queue_swap(replacement)
}

///|
/// Run one render quantum through the browser proof `CompiledStereoDspHotSwap`
/// graph.
pub fn process_compiled_stereo_hot_swap_block(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if !ensure_compiled_stereo_hot_swap_graph(sample_rate, block_size) {
    return false
  }
  let hot_swap = compiled_stereo_hot_swap.val.unwrap()
  hot_swap.process(
    compiled_stereo_hot_swap_context.val.unwrap(),
    compiled_stereo_hot_swap_left.val.unwrap(),
    compiled_stereo_hot_swap_right.val.unwrap(),
  )
  true
}

///|
/// Read one sample from the most recent stereo hot-swap browser left block.
pub fn compiled_stereo_hot_swap_left_sample(index : Int) -> Double {
  checked_sample(index, compiled_stereo_hot_swap_left.val)
}

///|
/// Read one sample from the most recent stereo hot-swap browser right block.
pub fn compiled_stereo_hot_swap_right_sample(index : Int) -> Double {
  checked_sample(index, compiled_stereo_hot_swap_right.val)
}

///|
fn ensure_compiled_stereo_hot_swap_graph(
  sample_rate : Double,
  block_size : Int,
) -> Bool {
  if sample_rate <= 0.0 || block_size <= 0 {
    reset_compiled_stereo_hot_swap_graph()
    return false
  }
  if compiled_stereo_hot_swap.val is Some(_) &&
    compiled_stereo_hot_swap_sample_rate.val == sample_rate &&
    compiled_stereo_hot_swap_block_size.val == block_size {
    return true
  }

  let context = @lib.DspContext::new(sample_rate, block_size)
  let left = @lib.AudioBuffer::filled(block_size)
  let right = @lib.AudioBuffer::filled(block_size)
  let active = match
    @lib.CompiledStereoDsp::compile(
      [
        @lib.DspNode::constant(BROWSER_STEREO_HOT_SWAP_OLD_CONSTANT),
        @lib.DspNode::pan(0, 0.0),
        @lib.DspNode::stereo_output(1),
      ],
      context,
    ) {
    Some(active) => active
    None => {
      reset_compiled_stereo_hot_swap_graph()
      return false
    }
  }
  let hot_swap = @lib.CompiledStereoDspHotSwap::from_graph(
    active,
    crossfade_samples=BROWSER_STEREO_HOT_SWAP_CROSSFADE_SAMPLES,
  )
  compiled_stereo_hot_swap.val = Some(hot_swap)
  compiled_stereo_hot_swap_context.val = Some(context)
  compiled_stereo_hot_swap_left.val = Some(left)
  compiled_stereo_hot_swap_right.val = Some(right)
  compiled_stereo_hot_swap_sample_rate.val = sample_rate
  compiled_stereo_hot_swap_block_size.val = block_size
  true
}

///|
fn reset_compiled_stereo_hot_swap_graph() -> Unit {
  compiled_stereo_hot_swap.val = None
  compiled_stereo_hot_swap_context.val = None
  compiled_stereo_hot_swap_left.val = None
  compiled_stereo_hot_swap_right.val = None
  compiled_stereo_hot_swap_sample_rate.val = 0.0
  compiled_stereo_hot_swap_block_size.val = 0
}
