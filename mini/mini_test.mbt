///|
test "drum_midi returns correct GM numbers" {
  inspect(@mini.drum_midi("bd"), content="Some(36)")
  inspect(@mini.drum_midi("sd"), content="Some(38)")
  inspect(@mini.drum_midi("hh"), content="Some(42)")
}

///|
test "drum_midi returns None for unknown names" {
  inspect(@mini.drum_midi("snare"), content="None")
  inspect(@mini.drum_midi(""), content="None")
  inspect(@mini.drum_midi("123"), content="None")
}
