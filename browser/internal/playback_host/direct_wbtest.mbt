///|
test "direct page capacity and invalid replacement preserve active bank" {
  direct_reset()
  for i in 0..<1024 {
    assert_true(direct_row(0, 128, 5, 440.0, 0.1, 2.0))
  }
  assert_true(direct_seal())
  assert_true(direct_publish())
  let active = direct_active.val
  direct_begin()
  assert_true(direct_row(128, 256, 5, 440.0, 0.1, 2.0))
  assert_false(direct_row(0, 128, 5, 440.0, 0.1, 2.0))
  assert_false(direct_seal())
  assert_false(direct_publish())
  assert_eq(direct_active.val, active)
  assert_eq(direct_count[active], 1024)
  direct_begin()
  for i in 0..<1024 {
    assert_true(direct_row(0, 128, 5, 440.0, 0.1, 2.0))
  }
  assert_false(direct_row(0, 128, 5, 440.0, 0.1, 2.0))
  assert_false(direct_seal())
}

///|
test "direct streaming times extend past finite comparison and stop safely" {
  direct_reset()
  assert_true(direct_row(960000, 1104000, 5, 440.0, 0.1, 2.0))
  assert_true(direct_seal())
  direct_begin()
  assert_false(direct_row(1000000000, 1000000128, 5, 440.0, 0.1, 2.0))
  direct_sample.val = 1000000000
  assert_false(direct_process())
  assert_eq(direct_sample.val, 1000000000)
  direct_reset()
}
