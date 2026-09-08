///|
const BROWSER_SONG_TEST_INPUT : String = "song(bpm(72),section(\"intro\",1,s(\"bd\")),section(\"verse\",2,note(\"60\")),part(\"intro1\",\"intro\"),part(\"verse1\",\"verse\"))"

///|
fn test_drum_template(freq : Double) -> Array[@moondsp.DspNode] {
  [
    @moondsp.DspNode::oscillator(@moondsp.Waveform::Sine, freq),
    @moondsp.DspNode::adsr(
      attack_ms=0.5,
      decay_ms=60.0,
      sustain=0.0,
      release_ms=40.0,
    ),
    @moondsp.DspNode::envelope_gain(input=0, envelope=1, amount=1.0),
    @moondsp.DspNode::output(2),
  ]
}

///|
fn test_synth_template() -> Array[@moondsp.DspNode] {
  [
    @moondsp.DspNode::oscillator(@moondsp.Waveform::Sine, 440.0),
    @moondsp.DspNode::adsr(
      attack_ms=10.0,
      decay_ms=100.0,
      sustain=0.7,
      release_ms=300.0,
    ),
    @moondsp.DspNode::envelope_gain(input=0, envelope=1, amount=1.0),
    @moondsp.DspNode::output(2),
  ]
}

///|
fn init_scheduler_graph_for_test() -> Bool {
  init_scheduler_graph_with_templates(
    48000.0,
    128,
    test_drum_template(60.0),
    test_drum_template(180.0),
    test_drum_template(8000.0),
    test_drum_template(1200.0),
    test_drum_template(6000.0),
    test_synth_template(),
  )
}

///|
fn push_pattern_text_for_test(text : String) -> Unit {
  clear_pattern_input()
  for i in 0..<text.length() {
    push_pattern_char(text[i].to_int())
  }
}

///|
fn push_song_text_for_test(text : String) -> Unit {
  clear_song_input()
  for i in 0..<text.length() {
    push_song_char(text[i].to_int())
  }
}

///|
fn active_playback_is_pattern_for_test() -> Bool {
  sched_active_playback.val is Some(ActivePattern(_))
}

///|
fn active_playback_is_song_for_test() -> Bool {
  sched_active_playback.val is Some(ActiveSong(_))
}

///|
fn active_song_route_count_for_test() -> Int? {
  match sched_active_playback.val {
    Some(ActiveSong(route_songs)) => Some(route_songs.length())
    _ => None
  }
}

///|
fn route_count_for_test() -> Int {
  sched_routes.val.length()
}

///|
fn routes_have_bpm_for_test(bpm : Double) -> Bool {
  for route in sched_routes.val {
    if route.pool.scheduler.bpm() != bpm {
      return false
    }
  }
  true
}

///|
fn route_sample_counters_for_test() -> Array[Int64] {
  let counters : Array[Int64] = []
  for route in sched_routes.val {
    counters.push(route.pool.scheduler.sample_counter())
  }
  counters
}

///|
fn assert_error_transport_for_test(
  message : String,
  length : () -> Int,
  char_at : (Int) -> Int,
) -> Unit raise {
  assert_true(message.length() > 0)
  @debug.assert_eq(length(), message.length())
  @debug.assert_eq(char_at(0), message[0].to_int())
  @debug.assert_eq(char_at(-1), 0)
  @debug.assert_eq(char_at(message.length()), 0)
}

///|
fn assert_pattern_error_transport_for_test(message : String) -> Unit raise {
  assert_error_transport_for_test(
    message, get_pattern_error_length, get_pattern_error_char,
  )
}

///|
fn assert_song_error_transport_for_test(message : String) -> Unit raise {
  assert_error_transport_for_test(
    message, get_song_error_length, get_song_error_char,
  )
}

///|
test "browser scheduler parse status values stay ABI compatible" {
  @debug.assert_eq(SCHEDULER_PARSE_STATUS_OK, 0)
  @debug.assert_eq(SCHEDULER_PARSE_STATUS_ERROR, 1)
}

///|
test "browser scheduler song input switches active playback explicitly" {
  assert_true(init_scheduler_graph_for_test())

  push_song_text_for_test(BROWSER_SONG_TEST_INPUT)
  @debug.assert_eq(eval_song_input(), SCHEDULER_PARSE_STATUS_OK)
  @debug.assert_eq(get_song_error_length(), 0)
  assert_true(active_playback_is_song_for_test())
  @debug.assert_eq(
    active_song_route_count_for_test(),
    Some(route_count_for_test()),
  )
  assert_true(routes_have_bpm_for_test(72.0))

  push_pattern_text_for_test("invalid!!!")
  @debug.assert_eq(eval_pattern_input(), SCHEDULER_PARSE_STATUS_ERROR)
  assert_true(active_playback_is_song_for_test())

  push_pattern_text_for_test("s(\"bd\")")
  @debug.assert_eq(eval_pattern_input(), SCHEDULER_PARSE_STATUS_OK)
  assert_true(active_playback_is_pattern_for_test())
}

///|
test "browser scheduler direct parse helpers use stable error transport" {
  assert_true(init_scheduler_graph_for_test())
  @debug.assert_eq(
    parse_and_set_song(BROWSER_SONG_TEST_INPUT),
    SCHEDULER_PARSE_STATUS_OK,
  )
  assert_true(active_playback_is_song_for_test())

  @debug.assert_eq(
    parse_and_set_pattern("s(\"bogus_drum\")"),
    SCHEDULER_PARSE_STATUS_ERROR,
  )
  assert_true(active_playback_is_song_for_test())
  let pattern_message = get_scheduler_parse_error()
  assert_true(pattern_message.contains("bogus_drum"))
  @debug.assert_eq(get_song_parse_error(), pattern_message)
  assert_pattern_error_transport_for_test(pattern_message)

  @debug.assert_eq(
    parse_and_set_pattern("s(\"bd\")"),
    SCHEDULER_PARSE_STATUS_OK,
  )
  assert_true(active_playback_is_pattern_for_test())
  @debug.assert_eq(get_pattern_error_length(), 0)

  @debug.assert_eq(
    parse_and_set_song(
      "song(section(\"intro\",0,s(\"bd\")),part(\"intro1\",\"intro\"))",
    ),
    SCHEDULER_PARSE_STATUS_ERROR,
  )
  assert_true(active_playback_is_pattern_for_test())
  let song_message = get_song_parse_error()
  assert_true(
    song_message.contains("section 'intro' requires a positive length"),
  )
  @debug.assert_eq(get_scheduler_parse_error(), song_message)
  assert_song_error_transport_for_test(song_message)
}

///|
test "browser scheduler song start resets route transport" {
  assert_true(init_scheduler_graph_for_test())
  push_pattern_text_for_test("s(\"bd\")")
  @debug.assert_eq(eval_pattern_input(), SCHEDULER_PARSE_STATUS_OK)
  assert_true(process_scheduler_block())
  for counter in route_sample_counters_for_test() {
    @debug.assert_eq(counter, 128L)
  }

  push_song_text_for_test(BROWSER_SONG_TEST_INPUT)
  @debug.assert_eq(eval_song_input(), SCHEDULER_PARSE_STATUS_OK)
  for counter in route_sample_counters_for_test() {
    @debug.assert_eq(counter, 0L)
  }
}

///|
test "browser scheduler song parse error accessors preserve last good pattern" {
  assert_true(init_scheduler_graph_for_test())
  @debug.assert_eq(
    parse_and_set_pattern("s(\"bd\")"),
    SCHEDULER_PARSE_STATUS_OK,
  )

  push_song_text_for_test(
    "song(section(\"intro\",0,s(\"bd\")),part(\"intro1\",\"intro\"))",
  )
  @debug.assert_eq(eval_song_input(), SCHEDULER_PARSE_STATUS_ERROR)
  assert_true(active_playback_is_pattern_for_test())
  let message = get_song_parse_error()
  assert_true(message.contains("section 'intro' requires a positive length"))
  assert_song_error_transport_for_test(message)
}

///|
test "prepared publication preserves active notes and transport" {
  assert_true(init_scheduler_graph_for_test())
  let p = @mini.parse("note(\"60\").slow(8)").unwrap()
  assert_true(publish_pattern(prepare_pattern(p).unwrap()))
  assert_true(process_scheduler_block())
  let synth = sched_routes.val[5].pool
  let count = synth.scheduler.active_note_count()
  assert_true(count > 0)
  let frame = synth.scheduler.current_block()
  assert_true(
    publish_pattern(prepare_pattern(@pattern.Pat::silence()).unwrap()),
  )
  assert_eq(synth.scheduler.active_note_count(), count)
  assert_eq(synth.scheduler.current_block().sample_begin, frame.sample_begin)
  assert_true(process_scheduler_block())
  assert_eq(synth.scheduler.active_note_count(), count)
  let mut energy = 0.0
  for i in 0..<128 {
    energy += scheduler_left_sample(i).abs()
  }
  assert_true(energy > 0.0)
  reset_scheduler_graph()
}

///|
fn gain_test_render(
  source : String,
  replacement : String?,
) -> Array[Double] raise {
  assert_true(init_scheduler_graph_for_test())
  assert_eq(parse_and_set_pattern(source), 0)
  let output = []
  for block in 0..<4 {
    if block == 1 {
      match replacement {
        Some(text) =>
          assert_true(
            publish_pattern(
              prepare_pattern(@mini.parse(text).unwrap()).unwrap(),
            ),
          )
        None => ()
      }
    }
    assert_true(process_scheduler_block())
    for i in 0..<128 {
      output.push(scheduler_left_sample(i))
    }
  }
  output
}

///|
test "voice gain defaults to unity, scales each route, and permits silence" {
  for
    source in [
      "note(\"60\")", "s(\"bd\")", "s(\"sd\")", "s(\"hh\")", "s(\"cp\")", "s(\"oh\")",
    ] {
    let full = gain_test_render(source, None)
    let unity = gain_test_render(source + ".gain(1)", None)
    let half = gain_test_render(source + ".gain(0.5)", None)
    let zero = gain_test_render(source + ".gain(0)", None)
    let mut energy = 0.0
    for i in 0..<full.length() {
      assert_eq(full[i], unity[i])
      assert_true((half[i] - full[i] * 0.5).abs() < 0.000000001)
      assert_eq(zero[i], 0.0)
      energy += full[i].abs()
    }
    assert_true(energy > 0.0)
  }
}

///|
test "simultaneous gains are independent and publication retains old voice gain" {
  let base = gain_test_render("note(\"60\").slow(8)", None)
  let mixed = gain_test_render(
    "stack(note(\"60\").slow(8).gain(0.25),note(\"60\").slow(8).gain(0.75))",
    None,
  )
  let edited = gain_test_render(
    "note(\"60\").slow(8)",
    Some("note(\"60\").slow(8).gain(0)"),
  )
  for i in 0..<base.length() {
    assert_true((mixed[i] - base[i]).abs() < 0.000000001)
    assert_eq(edited[i], base[i])
  }
}
