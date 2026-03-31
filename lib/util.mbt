///|
/// Check whether a floating-point value is finite (not NaN, not Inf).
pub fn is_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
/// Check whether a floating-point value is finite and strictly positive.
pub fn is_finite_positive(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf() && value > 0.0
}

///|
/// Compute the effective number of samples to process, bounded by both
/// the context block size and the buffer length.
pub fn effective_sample_count(
  context : DspContext,
  buffer : AudioBuffer,
) -> Int {
  if buffer.length() < context.block_size() {
    buffer.length()
  } else {
    context.block_size()
  }
}
