///|
struct Eval {
  value : Double
} derive(Eq, Show)

///|
pub impl @mdsp.ArithSym for Eval with constant(v) -> Eval {
  { value: v }
}

///|
pub impl @mdsp.ArithSym for Eval with mul(a, b) -> Eval {
  { value: a.value * b.value }
}

///|
pub impl @mdsp.ArithSym for Eval with mix(a, b) -> Eval {
  { value: a.value + b.value }
}

///|
pub impl @mdsp.ArithSym for Eval with clip(a, t) -> Eval {
  let v = a.value
  let clamped = if v > t { t } else if v < -t { -t } else { v }
  { value: clamped }
}

///|
test "ArithSym Eval: constant" {
  let result : Eval = @mdsp.ArithSym::constant(42.0)
  assert_eq(result.value, 42.0)
}

///|
test "ArithSym Eval: mul" {
  let a : Eval = @mdsp.ArithSym::constant(3.0)
  let b : Eval = @mdsp.ArithSym::constant(4.0)
  let result = @mdsp.ArithSym::mul(a, b)
  assert_eq(result.value, 12.0)
}

///|
test "ArithSym Eval: mix" {
  let a : Eval = @mdsp.ArithSym::constant(3.0)
  let b : Eval = @mdsp.ArithSym::constant(4.0)
  let result = @mdsp.ArithSym::mix(a, b)
  assert_eq(result.value, 7.0)
}

///|
test "ArithSym Eval: clip" {
  let a : Eval = @mdsp.ArithSym::constant(5.0)
  let result = @mdsp.ArithSym::clip(a, 3.0)
  assert_eq(result.value, 3.0)
}
