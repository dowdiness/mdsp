///|
test "live update preserves transport and sounding notes across every route" {
  assert_true(init_scheduler_graph_for_test())
  push_pattern_text_for_test("note(\"60\").slow(8)")
  assert_eq(eval_pattern_input(), 0)
  for _ in 0..<8 {
    assert_true(process_scheduler_block())
  }
  assert_eq(scheduler_sample_position(), 1024.0)
  push_pattern_text_for_test("s(\"bd\").degradeBy(1)")
  assert_eq(update_pattern_input(), 0)
  assert_eq(scheduler_sample_position(), 1024.0)
  assert_true(process_scheduler_block())
  assert_eq(scheduler_sample_position(), 1152.0)
  for counter in route_sample_counters_for_test() {
    assert_eq(counter, 1152L)
  }
  let mut energy = 0.0
  for i in 0..<128 {
    energy = energy + scheduler_left_sample(i).abs()
  }
  assert_true(energy > 0.01)
  assert_true(sched_active_playback.val is Some(ActiveSnapshots(_)))
}

///|
test "invalid update keeps accepted pending update and restart clears it" {
  assert_true(init_scheduler_graph_for_test())
  push_pattern_text_for_test("s(\"bd\").degradeBy(1)")
  assert_eq(eval_pattern_input(), 0)
  assert_true(process_scheduler_block())
  push_pattern_text_for_test("note(\"60\")")
  assert_eq(update_pattern_input(), 0)
  push_pattern_text_for_test("note(")
  assert_true(update_pattern_input() != 0)
  assert_true(sched_pending_update.val is Some(_))
  assert_eq(scheduler_sample_position(), 128.0)
  assert_true(process_scheduler_block())
  assert_true(sched_pending_update.val is None)
  assert_true(sched_active_playback.val is Some(ActiveSnapshots(_)))
  push_pattern_text_for_test("note(\"72\")")
  assert_eq(update_pattern_input(), 0)
  push_pattern_text_for_test("s(\"bd\").degradeBy(1)")
  assert_eq(eval_pattern_input(), 0)
  assert_eq(scheduler_sample_position(), 0.0)
  assert_true(sched_pending_update.val is None)
  assert_true(process_scheduler_block())
  assert_true(active_playback_is_pattern_for_test())
}

///|
test "song update preserves tempo and rejects tempo or layout changes" {
  assert_true(init_scheduler_graph_for_test())
  push_song_text_for_test(
    "song(bpm(120),section(\"a\",8,note(\"60\")),part(\"a1\",\"a\"))",
  )
  assert_eq(eval_song_input(), 0)
  assert_true(process_scheduler_block())
  push_song_text_for_test(
    "song(bpm(120),section(\"a\",8,note(\"72\")),part(\"a1\",\"a\"))",
  )
  assert_eq(update_song_input(), 0)
  assert_true(routes_have_bpm_for_test(120.0))
  push_song_text_for_test(
    "song(bpm(60),section(\"a\",9,note(\"72\")),part(\"a1\",\"a\"))",
  )
  assert_true(update_song_input() != 0)
  assert_true(process_scheduler_block())
  assert_true(routes_have_bpm_for_test(120.0))
  assert_eq(scheduler_sample_position(), 256.0)
  push_song_text_for_test(
    "song(bpm(90),section(\"a\",8,note(\"72\")),part(\"a1\",\"a\"))",
  )
  assert_true(update_song_input() != 0)
  assert_true(routes_have_bpm_for_test(120.0))
  push_pattern_text_for_test("s(\"bd\")")
  assert_true(update_pattern_input() != 0)
}

///|
test "update requires playback to be started" {
  assert_true(init_scheduler_graph_for_test())
  push_pattern_text_for_test("s(\"bd\")")
  assert_true(update_pattern_input() != 0)
  assert_true(sched_pending_update.val is None)
}

///|
test "latest successful update wins and failed edits do not erase it" {
  assert_true(init_scheduler_graph_for_test())
  push_pattern_text_for_test("s(\"bd\").degradeBy(1)")
  assert_eq(eval_pattern_input(), 0)
  assert_true(process_scheduler_block())
  push_pattern_text_for_test("s(\"bd\").degradeBy(1)")
  assert_eq(update_pattern_input(), 0)
  push_pattern_text_for_test("note(\"60\").fast(375)")
  assert_eq(update_pattern_input(), 0)
  push_pattern_text_for_test("note(")
  assert_true(update_pattern_input() != 0)
  assert_true(process_scheduler_block())
  let mut energy = 0.0
  for i in 0..<128 {
    energy = energy + scheduler_left_sample(i).abs()
  }
  assert_true(energy > 0.01)
  assert_eq(scheduler_sample_position(), 256.0)
}
