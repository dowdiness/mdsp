///|
test "preparation does not change playback even when applied later" {
  assert_true(init_scheduler_graph_for_test())
  assert_eq(submit_for_test("note(\"60\").slow(8)"), 0)
  render_for_test(8)
  let token = prepare_for_test("s(\"bd\").degradeBy(1)")
  assert_true(token > 0)
  assert_true(playback_state.val.pending is None)
  assert_position(1024)
  render_for_test(1)
  assert_true(output_energy() > 0.01)
  assert_eq(apply_prepared_playback(token, false), 0)
  assert_position(1152)
  render_for_test(1)
  assert_position(1280)
  assert_true(output_energy() > 0.01)
}

///|
test "failed preparation preserves active and accepted pending state" {
  assert_true(init_scheduler_graph_for_test())
  assert_eq(submit_for_test("s(\"bd\").degradeBy(1)"), 0)
  render_for_test(1)
  assert_eq(submit_for_test("note(\"60\").fast(375)", restart=false), 0)
  assert_eq(prepare_for_test("note("), 0)
  assert_true(playback_state.val.pending is Some(_))
  assert_position(128)
  render_for_test(1)
  assert_position(256)
  assert_true(output_energy() > 0.01)
}

///|
test "prepared tokens reject stale consumed discarded and failed results" {
  assert_true(init_scheduler_graph_for_test())
  let a = prepare_for_test("note(\"60\")")
  let b = prepare_for_test("note(\"72\")")
  assert_true(apply_prepared_playback(a, true) != 0)
  assert_eq(apply_prepared_playback(b, true), 0)
  assert_true(apply_prepared_playback(b, true) != 0)
  let c = prepare_for_test("note(\"60\")")
  assert_true(discard_prepared_playback(c))
  assert_true(apply_prepared_playback(c, true) != 0)
  let d = prepare_for_test("note(\"60\")")
  assert_eq(prepare_for_test("note("), 0)
  assert_true(apply_prepared_playback(d, true) != 0)
}

///|
test "restart uses applied snapshot cancels pending replacement and does not parse" {
  assert_true(init_scheduler_graph_for_test())
  assert_eq(submit_for_test("s(\"bd\").degradeBy(1)"), 0)
  render_for_test(8)
  assert_eq(submit_for_test("note(\"60\").fast(375)", restart=false), 0)
  clear_playback_input()
  push_playback_char(33)
  let sequence = prepared_sequence.val
  assert_eq(restart_playback(), 0)
  assert_eq(prepared_sequence.val, sequence)
  assert_eq(playback_input_chars.length(), 1)
  assert_position(1024)
  render_for_test(1)
  assert_position(128)
  assert_eq(output_energy(), 0.0)
  render_for_test(1)
  assert_eq(output_energy(), 0.0)
}

///|
test "replacement and reset apply atomically and kill previous voices" {
  assert_true(init_scheduler_graph_for_test())
  assert_eq(submit_for_test("note(\"60\").slow(8)"), 0)
  render_for_test(8)
  assert_true(output_energy() > 0.01)
  assert_eq(submit_for_test("s(\"bd\").degradeBy(1)"), 0)
  assert_position(1024)
  render_for_test(1)
  assert_position(128)
  assert_eq(output_energy(), 0.0)
}

///|
test "song layout and tempo can change only with reset and only at commit" {
  assert_true(init_scheduler_graph_for_test())
  assert_eq(
    submit_for_test(
      "song(bpm(120),section(\"a\",8,note(\"60\")),part(\"a1\",\"a\"))",
      song=true,
    ),
    0,
  )
  render_for_test(4)
  let token = prepare_for_test(
    "song(bpm(90),section(\"a\",9,note(\"72\")),part(\"a1\",\"a\"))",
    song=true,
  )
  assert_true(apply_prepared_playback(token, false) != 0)
  assert_eq(apply_prepared_playback(token, true), 0)
  assert_position(512)
  for route in sched_routes.val {
    assert_eq(route.pool.scheduler.bpm(), 120.0)
  }
  render_for_test(1)
  assert_position(128)
  for route in sched_routes.val {
    assert_eq(route.pool.scheduler.bpm(), 90.0)
  }
  let changed_tempo = prepare_for_test(
    "song(bpm(80),section(\"a\",9,note(\"72\")),part(\"a1\",\"a\"))",
    song=true,
  )
  assert_true(apply_prepared_playback(changed_tempo, false) != 0)
  set_scheduler_bpm(100.0)
  assert_eq(restart_playback(), 0)
  render_for_test(1)
  for route in sched_routes.val {
    assert_eq(route.pool.scheduler.bpm(), 100.0)
  }
}

///|
test "latest accepted apply wins and new preparation alone cannot replace it" {
  assert_true(init_scheduler_graph_for_test())
  assert_eq(submit_for_test("note(\"60\")"), 0)
  assert_eq(submit_for_test("s(\"bd\").degradeBy(1)"), 0)
  assert_true(prepare_for_test("note(\"72\")") > 0)
  render_for_test(1)
  assert_eq(output_energy(), 0.0)
}

///|
test "before first application continue and restart fail without cancelling start" {
  assert_true(init_scheduler_graph_for_test())
  assert_true(restart_playback() != 0)
  let token = prepare_for_test("note(\"60\")")
  assert_true(apply_prepared_playback(token, false) != 0)
  assert_eq(apply_prepared_playback(token, true), 0)
  assert_true(restart_playback() != 0)
  assert_true(playback_state.val.pending is Some(_))
  render_for_test(1)
  assert_true(playback_state.val.active is Some(_))
}

///|
test "reset invalidates prepared handles and clears queued playback" {
  assert_true(init_scheduler_graph_for_test())
  let token = prepare_for_test("note(\"60\")")
  reset_scheduler_graph()
  assert_true(init_scheduler_graph_for_test())
  assert_true(apply_prepared_playback(token, true) != 0)
  assert_eq(restart_playback(), 1)
  assert_eq(
    prepare_for_test(
      "song(section(\"a\",0,s(\"bd\")),part(\"a1\",\"a\"))",
      song=true,
    ),
    0,
  )
  let message = get_playback_error()
  assert_true(message.contains("positive length"))
  assert_eq(get_playback_error_length(), message.length())
  for i in 0..<message.length() {
    assert_eq(get_playback_error_char(i), message[i].to_int())
  }
  assert_eq(get_playback_error_char(-1), 0)
}

///|
test "prepared song respects section boundaries differing periods and finite end" {
  let song = @mini.parse_song(
    "song(section(\"a\",3,stack(note(\"60\").slow(3),note(\"72 74\").slow(4))),section(\"b\",2,note(\"67\").slow(2)),part(\"a1\",\"a\"),part(\"b1\",\"b\"))",
  ).unwrap()
  let snapshot = song_update_snapshot(song)
  let span = @pattern.TimeSpan::new(
    @pattern.Rational::from_int(0),
    @pattern.Rational::from_int(5),
  )
  let events = snapshot.query(span)
  assert_eq(events.map(e => e.value.get("note")), [
    Some(60.0),
    Some(72.0),
    Some(74.0),
    Some(67.0),
  ])
  assert_eq(events.map(e => e.part.begin), [
    @pattern.Rational::from_int(0),
    @pattern.Rational::from_int(0),
    @pattern.Rational::from_int(2),
    @pattern.Rational::from_int(3),
  ])
  assert_eq(events[2].part.end_, @pattern.Rational::from_int(3))
  assert_eq(events[3].part.end_, @pattern.Rational::from_int(5))
  assert_eq(
    snapshot
    .query(
      @pattern.TimeSpan::new(
        @pattern.Rational::from_int(5),
        @pattern.Rational::from_int(6),
      ),
    )
    .length(),
    0,
  )
}

///|
test "finite playback ends and restart returns to the first onset" {
  assert_true(init_scheduler_graph_for_test())
  assert_eq(
    submit_for_test(
      "song(section(\"a\",1,note(\"60\")),part(\"a1\",\"a\"))",
      song=true,
    ),
    0,
  )
  render_for_test(1000)
  assert_eq(output_energy(), 0.0)
  assert_eq(restart_playback(), 0)
  render_for_test(2)
  assert_position(256)
  assert_true(output_energy() > 0.01)
}

///|
test "snapshot thinning is deterministic across query partitions" {
  let song = @mini.parse_song(
    "song(section(\"a\",4,note(\"60*8\").degradeBy(0.5)),part(\"a1\",\"a\"))",
  ).unwrap()
  let snapshot = song_update_snapshot(song)
  let whole = snapshot.query(
    @pattern.TimeSpan::new(
      @pattern.Rational::from_int(0),
      @pattern.Rational::from_int(4),
    ),
  )
  let mut count = 0
  for cycle in 0..<4 {
    let events = snapshot.query(
      @pattern.TimeSpan::new(
        @pattern.Rational::from_int(cycle),
        @pattern.Rational::from_int(cycle + 1),
      ),
    )
    for event in events {
      assert_eq(event.part, whole[count].part)
      assert_eq(event.value.get("note"), whole[count].value.get("note"))
      count = count + 1
    }
  }
  assert_eq(count, whole.length())
  assert_true(count > 0 && count < 32)
}
