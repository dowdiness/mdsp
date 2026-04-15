///|
/// Re-export dsp/ types and traits so graph source and test files can use them
/// unqualified. `pub using` is needed because blackbox tests (`_test.mbt`)
/// only see the package's public API.
pub using @dsp {
  type AudioBuffer,
  type DspContext,
  type Oscillator,
  type Noise,
  type Adsr,
  type Biquad,
  type DelayLine,
  type Pan,
  type Waveform,
  type BiquadMode,
  type EnvStage,
  trait ArithSym,
  trait DspSym,
  trait FilterSym,
  trait DelaySym,
  trait StereoSym,
  trait StereoFilterSym,
  trait StereoDelaySym,

  // Utility functions
  is_finite,

  // Tagless compositions
  exit_deliverable,
  range,
}
