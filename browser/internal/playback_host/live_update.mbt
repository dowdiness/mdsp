///|
priv struct PlaybackLayoutRow {
  id : String
  name : String
  section : String
  start : @pattern.Rational
  length : @pattern.Rational
  rate : @pattern.Rational
} derive(Eq)

///|
priv enum PlaybackLayout {
  PatternLayout
  SongLayout(Array[PlaybackLayoutRow])
} derive(Eq)

///|
priv struct PreparedPlaybackUpdate {
  snapshots : Array[@scheduler.PlaybackSnapshot]
  layout : PlaybackLayout
  bpm : Double?
}

///|
/// Audio-owner state. Preparation completes before this slot is replaced.
let sched_pending_update : @ref.Ref[PreparedPlaybackUpdate?] = @ref.new(None)

///|
fn song_layout(song : @song.Song[@pattern.ControlMap]) -> PlaybackLayout {
  SongLayout(
    song
    .occurrences()
    .map(o => {
      id: o.id().value(),
      name: o.name(),
      section: o.section().name(),
      start: o.start(),
      length: o.section().length_cycles(),
      rate: o.section().scope().rate(),
    }),
  )
}

///|
fn active_layout() -> PlaybackLayout? {
  match sched_active_playback.val {
    Some(ActivePattern(_)) => Some(PatternLayout)
    Some(ActiveSong(songs)) => songs.get(0).map(song_layout)
    Some(ActiveSnapshots(layout)) => Some(layout)
    None => None
  }
}

///|
/// Deterministic admission policy. Restart remains an explicit operation.
fn update_layout_error(
  active : PlaybackLayout?,
  next : PlaybackLayout,
) -> String? {
  match active {
    None => Some("start playback before updating")
    Some(previous) if previous != next =>
      Some("playback mode or song layout changed; restart required")
    Some(_) => None
  }
}

///|
fn song_update_snapshot(
  song : @song.Song[@pattern.ControlMap],
) -> @song.SongSnapshot[@pattern.ControlMap] raise {
  let parts = song
    .occurrences()
    .map(o => {
      let section = @song.SectionDoc::single(
        id=@identity.SectionId::from_string("live:" + o.id().value()),
        name=o.section().name(),
        length_cycles=o.section().length_cycles(),
        scope=o.section().scope(),
        layer_id=@identity.SectionLayerId::from_string("live:body"),
        body=o.section().body(),
      )
      @song.SongOccurrenceDoc::at(
        id=o.id(),
        start=o.start(),
        name=o.name(),
        section~,
      )
    })
  @song.SongDoc(parts~).lower()
}

///|
fn prepare_pattern_update(
  text : String,
) -> Result[PreparedPlaybackUpdate, String] {
  match @mini.parse(text) {
    Err(msg) => Err(msg)
    Ok(pat) => {
      let snapshots = route_patterns_for_current_routes(pat).map(pat => {
        @scheduler.PlaybackSnapshot::pattern(
          @pattern.PatternDoc::from_pattern(
            id=@identity.PatternNodeId::from_string("live:pattern"),
            pat~,
          ).lower(),
        )
      }) catch {
        _ => return Err("could not prepare pattern update")
      }
      Ok({ snapshots, layout: PatternLayout, bpm: None, })
    }
  }
}

///|
fn prepare_song_update(text : String) -> Result[PreparedPlaybackUpdate, String] {
  match @mini.parse_song_with_bpm(text) {
    Err(msg) => Err(msg)
    Ok(parsed) =>
      match route_songs_for_current_routes(parsed.song()) {
        Err(msg) => Err(msg)
        Ok(songs) => {
          let snapshots = songs.map(song => {
            @scheduler.PlaybackSnapshot::song(song_update_snapshot(song))
          }) catch {
            _ => return Err("could not prepare song update")
          }
          Ok({
            snapshots,
            layout: song_layout(parsed.song()),
            bpm: parsed.bpm(),
          })
        }
      }
  }
}

///|
fn stage_playback_update(
  prepared : Result[PreparedPlaybackUpdate, String],
) -> Int {
  match prepared {
    Err(msg) => set_scheduler_parse_error(msg)
    Ok(next) =>
      match update_layout_error(active_layout(), next.layout) {
        Some(msg) => set_scheduler_parse_error(msg)
        None => {
          match next.bpm {
            Some(bpm) =>
              for route in sched_routes.val {
                if route.pool.scheduler.bpm() != bpm {
                  return set_scheduler_parse_error(
                    "song tempo changed; restart required",
                  )
                }
              }
            None => ()
          }
          sched_pending_update.val = Some(next)
          set_scheduler_parse_success()
        }
      }
  }
}

///|
/// All routes are queued together before any route renders the next block.
fn commit_playback_update() -> Unit {
  match sched_pending_update.val {
    None => ()
    Some(next) => {
      for i in 0..<sched_routes.val.length() {
        sched_routes.val[i].pool.scheduler.queue_playback_snapshot(
          next.snapshots[i],
        )
      }
      sched_active_playback.val = Some(ActiveSnapshots(next.layout))
      sched_pending_update.val = None
    }
  }
}

///|
fn process_snapshot_routes(
  left : @moondsp.AudioBuffer,
  right : @moondsp.AudioBuffer,
) -> Unit {
  for route in sched_routes.val {
    let sp = route.pool
    sp.tmp_left.fill(0.0)
    sp.tmp_right.fill(0.0)
    sp.scheduler.process_playback_snapshot_block(
      sp.pool,
      sp.tmp_left,
      sp.tmp_right,
    )
    accumulate_sub_pool(sp, left, right)
  }
}

///|
/// Successful return means prepared; application occurs on the next block.
pub fn update_pattern_input() -> Int {
  let text = input_chars_to_string(sched_pattern_input_chars)
  sched_pattern_input_chars.clear()
  stage_playback_update(prepare_pattern_update(text))
}

///|
pub fn update_song_input() -> Int {
  let text = input_chars_to_string(sched_song_input_chars)
  sched_song_input_chars.clear()
  stage_playback_update(prepare_song_update(text))
}

///|
/// Position of the next block, also used in application acknowledgements.
pub fn scheduler_sample_position() -> Double {
  match sched_routes.val.get(0) {
    Some(route) => route.pool.scheduler.sample_counter().to_double()
    None => 0.0
  }
}
