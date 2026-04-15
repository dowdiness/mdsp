///|
let demo : @ref.Ref[@lib.DemoSource] = @ref.new(@lib.DemoSource::new())

///|
/// Entry point required because the root package is built as a main package for
/// the exported wasm/js prototype.
fn main {
  ()
}

///|
/// Reset oscillator and noise state to the start of the waveform.
pub fn demo_reset_phase() -> Unit {
  demo.val.reset()
}

///|
/// Generate one sine sample for the current frequency.
///
/// This function is exported for the `wasm-gc` and `js` backends so the
/// browser prototype can call it from the AudioWorklet processor.
pub fn demo_tick(freq : Double, sample_rate : Double) -> Double {
  demo.val.tick_source(0, freq, sample_rate)
}

///|
/// Browser demo source selector entrypoint exported for wasm/js builds.
pub fn demo_tick_source(
  source_id : Int,
  freq : Double,
  sample_rate : Double,
) -> Double {
  demo.val.tick_source(source_id, freq, sample_rate)
}

///|
/// Backward-compatible browser demo alias for the old prototype name.
pub fn reset_phase() -> Unit {
  demo.val.reset()
}

///|
/// Backward-compatible browser demo alias for the old prototype name.
pub fn tick(freq : Double, sample_rate : Double) -> Double {
  demo.val.tick_source(0, freq, sample_rate)
}

///|
/// Backward-compatible browser demo alias.
pub fn tick_source(
  source_id : Int,
  freq : Double,
  sample_rate : Double,
) -> Double {
  demo.val.tick_source(source_id, freq, sample_rate)
}
