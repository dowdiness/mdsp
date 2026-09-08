///|
test "named groups preserve cycles and transformations without mutating definitions" {
  let source =
    #|let motif = note("E4 G4 A4").slow(3);
    #|let beat = s("bd");
    #|let groove = stack(motif, beat);
    #|stack(groove.gain(0.2), motif)
  let inline = "stack(stack(note(\"E4 G4 A4\").slow(3),s(\"bd\")).gain(0.2),note(\"E4 G4 A4\").slow(3))"
  let span = song_span(0L, 1L, 12L, 1L)
  assert_named_events(
    unwrap_ok(@mini.parse(source)).query(span),
    unwrap_ok(@mini.parse(inline)).query(span),
  )
  let snapshot = named_snapshot(source)
  assert_named_events(
    snapshot.query(span),
    unwrap_ok(@mini.parse(inline)).query(span),
  )
}

///|
test "definitions work with dollar stack lines and do not leak across parses" {
  let source = "let tone = note(\"60\");\n$: tone\n$: tone.gain(0.2)"
  let inline = "stack(note(\"60\"),note(\"60\").gain(0.2))"
  let span = song_span(0L, 1L, 1L, 1L)
  assert_named_events(
    unwrap_ok(@mini.parse(source)).query(span),
    unwrap_ok(@mini.parse(inline)).query(span),
  )
  assert_named_events(
    named_snapshot(source).query(span),
    unwrap_ok(@mini.parse(inline)).query(span),
  )
  assert_true(@mini.parse("tone") is Err(_))
}

///|
test "binding diagnostics reject duplicates unresolved names and recursive definitions" {
  let cases = [
    ("let a = note(\"60\"); let a = note(\"62\"); a", "duplicate pattern 'a'"),
    ("let a = missing; a", "undefined pattern 'missing'"),
    ("let a = a; a", "undefined pattern 'a'"),
    ("let a = b; let b = a; a", "undefined pattern 'b'"),
    ("let s = note(\"60\"); s", "reserved pattern name 's'"),
    ("let a = note(\"60\") a", "expected ';'"),
  ]
  for item in cases {
    let (source, message) = item
    for
      result in [
        @mini.parse(source).map(_ => ()),
        @mini.parse_song(source).map(_ => ()),
        @mini.parse_doc(source).map(_ => ()),
      ] {
      match result {
        Err(error) => assert_true(error.contains(message))
        Ok(_) => fail("expected binding error: \{source}")
      }
    }
  }
}

///|
test "one definition edit changes every section while preserving song layout" {
  let suffix = "song(section(\"a\",3,theme),section(\"b\",4,theme),part(\"a1\",\"a\"),part(\"b1\",\"b\"))"
  let before = unwrap_parsed_song(
    @mini.parse_song("let theme = note(\"60\").slow(3); " + suffix),
  )
  let after = unwrap_parsed_song(
    @mini.parse_song("let theme = note(\"72\").slow(3); " + suffix),
  )
  @debug.assert_eq(before.duration(), after.duration())
  let span = song_span(0L, 1L, 7L, 1L)
  let old_events = before.query(span)
  let events = after.query(span)
  @debug.assert_eq(events.length(), old_events.length())
  for i in 0..<events.length() {
    @debug.assert_eq(events[i].whole, old_events[i].whole)
    @debug.assert_eq(events[i].part, old_events[i].part)
    @debug.assert_eq(events[i].value.get("note"), Some(72.0))
  }
}

///|
fn assert_named_events(
  actual : Array[@pattern.Event[@pattern.ControlMap]],
  expected : Array[@pattern.Event[@pattern.ControlMap]],
) -> Unit raise {
  @debug.assert_eq(actual.length(), expected.length())
  for i in 0..<actual.length() {
    @debug.assert_eq(actual[i].whole, expected[i].whole)
    @debug.assert_eq(actual[i].part, expected[i].part)
    @debug.assert_eq(actual[i].value.entries(), expected[i].value.entries())
  }
}

///|
fn named_snapshot(
  source : String,
) -> @pattern.PatternSnapshot[@pattern.ControlMap] raise {
  match @mini.parse_snapshot(source) {
    Ok(snapshot) => snapshot
    Err(message) => fail(message)
  }
}

///|
test "cached authoring sees definition edits through nested named groups" {
  let tail = "let group = stack(tone,tone.gain(0.2)); group.slow(3)"
  let pipeline = @mini.MiniAuthoringPipeline::new(
    "let tone = note(\"60\"); " + tail,
  )
  let span = song_span(0L, 1L, 3L, 1L)
  for
    prefix in [
      "let tone = note(\"60\"); ", "let tone = note(\"72\"); ", "let tone = note(\"67\"); ",
    ] {
    let source = prefix + tail
    pipeline.set_input(source)
    let snapshot = match pipeline.parse_snapshot() {
      Ok(snapshot) => snapshot
      Err(error) => fail(error)
    }
    assert_named_events(
      snapshot.query(span),
      unwrap_ok(@mini.parse(source)).query(span),
    )
  }
  pipeline.dispose()
}

///|
test "named document events retain distinct references and their shared definition source" {
  let doc = unwrap_doc(
    @mini.parse_doc("let phrase = note(\"60\").slow(3); stack(phrase,phrase)"),
  )
  let snapshot = doc.lower()
  let events = snapshot.query_sourced_events(song_span(0L, 1L, 3L, 1L))
  @debug.assert_eq(events.length(), 2)
  let first = events[0].pattern_nodes()
  let second = events[1].pattern_nodes()
  assert_true(first[1] != second[1])
  @debug.assert_eq(first[first.length() - 1], second[second.length() - 1])
  guard doc.referenced_definition(first[1]) is Some(definition) else {
    fail("reference became opaque")
  }
  assert_true(definition.contains_node(first[first.length() - 1]))
}

///|
test "both compilation paths report the original unresolved use position" {
  let source = "let tone = note(\"60\");\nstack(tone, missing)"
  let expected = "position 35: undefined pattern 'missing'; define it before use"
  match @mini.parse(source) {
    Err(message) => @debug.assert_eq(message, expected)
    Ok(_) => fail("unresolved use accepted")
  }
  match @mini.parse_doc(source) {
    Err(message) => @debug.assert_eq(message, expected)
    Ok(_) => fail("unresolved document use accepted")
  }
}

///|
test "unused definitions are validated by both compilation paths" {
  let source = "let unused = note(\"NotANote\"); note(\"60\")"
  assert_true(@mini.parse(source) is Err(_))
  assert_true(@mini.parse_doc(source) is Err(_))
}
