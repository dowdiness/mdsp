///|
/// Browser-export wrapper package that preserves the original Phase 0/1 wasm ABI.
fn main {
  ()
}

///|
/// Reset browser demo state.
pub fn reset_phase() -> Unit {
  @lib.reset_phase()
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
