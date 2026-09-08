///|
pub fn initialize() -> Bool {
  @host.direct_reset()
  @host.init_scheduler_graph_with_templates(
    48000.0,
    128,
    @templates.bd_template(),
    @templates.sd_template(),
    @templates.hh_template(),
    @templates.cp_template(),
    @templates.oh_template(),
    @templates.synth_template(),
  )
}

///|
pub fn begin() -> Unit {
  @host.direct_begin()
}

///|
pub fn row(
  at : Int,
  end : Int,
  route : Int,
  frequency : Double,
  gain : Double,
  pan : Double,
) -> Bool {
  @host.direct_row(at, end, route, frequency, gain, pan)
}

///|
pub fn seal() -> Bool {
  @host.direct_seal()
}

///|
pub fn publish() -> Bool {
  @host.direct_publish()
}

///|
pub fn process() -> Bool {
  @host.direct_process()
}

///|
pub fn left(i : Int) -> Double {
  @host.scheduler_left_sample(i)
}

///|
pub fn right(i : Int) -> Double {
  @host.scheduler_right_sample(i)
}

///|
fn main {
  ()
}
