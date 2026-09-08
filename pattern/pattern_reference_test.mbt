///|
test "references share compilation while retaining use-site and definition paths" {
  let definition = PatternDoc::pure(id=pid("note"), value=60).slow(
    id=pid("phrase"),
    factor=Rational::from_int(3),
  )
  let left = PatternDoc::reference(id=pid("left"), definition~)
  let right = PatternDoc::reference(id=pid("right"), definition~)
  let doc = PatternDoc::stack(id=pid("mix"), docs=[left, right])
  let cache : PatternLoweringCache[Int] = PatternLoweringCache::new()
  let snapshot = doc.lower_with_cache(cache)
  // Three use-site nodes plus the two shared definition nodes, each compiled once.
  inspect(cache.miss_count(), content="5")
  let events = snapshot.query_sourced_events(doc_span(0, 1, 3, 1))
  inspect(events.length(), content="2")
  assert_pattern_event_path(events[0], ["mix", "left", "phrase", "note"])
  assert_pattern_event_path(events[1], ["mix", "right", "phrase", "note"])
  guard left.referenced_definition(pid("left")) is Some(target) else {
    fail("missing reference target")
  }
  assert_true(target.contains_node(pid("note")))
}

///|
test "references to divergent definition revisions never share stale values" {
  let original = PatternDoc::pure(id=pid("note"), value=60).slow(
    id=pid("phrase"),
    factor=Rational::from_int(3),
  )
  let edited = original.replace_with_pure(id=pid("note"), value=72)
  let doc = PatternDoc::stack(id=pid("mix"), docs=[
    PatternDoc::reference(id=pid("original"), definition=original),
    PatternDoc::reference(id=pid("edited"), definition=edited),
  ])
  let snapshot = doc.lower()
  @debug.assert_eq(
    snapshot.query(doc_span(0, 1, 3, 1)).map(event => event.value),
    [60, 72],
  )
  @debug.assert_eq(
    snapshot
    .query_sourced_events(doc_span(0, 1, 3, 1))
    .map(event => event.event().value),
    [60, 72],
  )
}

///|
test "rebuilding references to an edited definition invalidates a persistent cache" {
  let original = PatternDoc::pure(id=pid("note"), value=60)
  let cache : PatternLoweringCache[Int] = PatternLoweringCache::new()
  let before = PatternDoc::reference(id=pid("use"), definition=original).lower_with_cache(
    cache,
  )
  let edited = original.replace_with_pure(id=pid("note"), value=72)
  let after = PatternDoc::reference(id=pid("use"), definition=edited).lower_with_cache(
    cache,
  )
  inspect(before.query(doc_span(0, 1, 1, 1))[0].value, content="60")
  inspect(after.query(doc_span(0, 1, 1, 1))[0].value, content="72")
  assert_pattern_event_path(
    after.query_sourced_events(doc_span(0, 1, 1, 1))[0],
    ["use", "note"],
  )
}
