///|
/// Core algebra for the Finally Tagless DSP representation.
/// Downstream packages implement this trait to provide different
/// interpretations (evaluation, code generation, pretty printing, etc.).
pub(open) trait ArithSym {
  constant(Double) -> Self
  mul(Self, Self) -> Self
  mix(Self, Self) -> Self
  clip(Self, Double) -> Self
}
