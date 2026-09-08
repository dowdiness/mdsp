///|
/// Opaque routed value, constructed before the audio callback.
pub struct PreparedPattern {
  priv routes : Array[@pattern.Pat[@pattern.ControlMap]]
}

///|
pub fn prepare_pattern(
  pat : @pattern.Pat[@pattern.ControlMap],
) -> PreparedPattern? {
  if sched_routes.val.length() == 0 {
    return None
  }
  Some({ routes: route_patterns_for_current_routes(pat), })
}

///| Caller owns the musical commit boundary. Preserve transport and sounding voices.

///|
/// No parsing, routing, reset, or note cancellation occurs at publication.
pub fn publish_pattern(prepared : PreparedPattern) -> Bool {
  if sched_routes.val.length() == 0 ||
    prepared.routes.length() != sched_routes.val.length() {
    return false
  }
  sched_active_playback.val = Some(ActivePattern(prepared.routes))
  true
}
