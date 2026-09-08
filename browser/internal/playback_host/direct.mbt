///|
/// Fixed-capacity experiment. All mutation here belongs to the audio owner.
let direct_banks : FixedArray[FixedArray[Double]] = FixedArray::makei(2, fn(_) {
  FixedArray::make(1024 * 6, 0.0)
})

///|
let direct_count : FixedArray[Int] = FixedArray::make(2, 0)

///|
let direct_active : @ref.Ref[Int] = @ref.new(0)

///|
let direct_valid : @ref.Ref[Bool] = @ref.new(true)

///|
let direct_ready : @ref.Ref[Bool] = @ref.new(false)

///|
let direct_cursor : @ref.Ref[Int] = @ref.new(0)

///|
let direct_sample : @ref.Ref[Int] = @ref.new(0)

///|
let direct_handles : FixedArray[Int64] = FixedArray::make(144, -1L)

///|
let direct_ends : FixedArray[Int] = FixedArray::make(144, 0)

///|
let direct_context : @moondsp.DspContext = @moondsp.DspContext::new(
  sample_rate=48000.0,
  block_size=128,
)

///|
pub fn direct_reset() -> Unit {
  direct_active.val = 0
  direct_count[0] = 0
  direct_count[1] = 0
  direct_cursor.val = 0
  direct_sample.val = 0
  for i in 0..<144 {
    direct_handles[i] = -1L
  }
  direct_begin()
}

///|
pub fn direct_begin() -> Unit {
  direct_count[1 - direct_active.val] = 0
  direct_valid.val = true
  direct_ready.val = false
}

///|
pub fn direct_row(
  at : Int,
  end : Int,
  route : Int,
  frequency : Double,
  gain : Double,
  pan : Double,
) -> Bool {
  let bank = 1 - direct_active.val
  let count = direct_count[bank]
  let data = direct_banks[bank]
  if !direct_valid.val ||
    count >= 1024 ||
    at < 0 ||
    at >= 1000000000 ||
    at % 128 != 0 ||
    end <= at ||
    end > 2000000000 ||
    route < 0 ||
    route >= 6 ||
    !(frequency >= 0.0 && frequency <= 20000.0) ||
    !(gain >= 0.0 && gain <= 4.0) ||
    !(pan == 2.0 || (pan >= -1.0 && pan <= 1.0)) ||
    (count > 0 && at < data[(count - 1) * 6].to_int()) {
    direct_valid.val = false
    return false
  }
  let i = count * 6
  data[i] = at.to_double()
  data[i + 1] = end.to_double()
  data[i + 2] = route.to_double()
  data[i + 3] = frequency
  data[i + 4] = gain
  data[i + 5] = pan
  direct_count[bank] = count + 1
  true
}

///|
pub fn direct_seal() -> Bool {
  direct_ready.val = direct_valid.val
  direct_ready.val
}

///|
pub fn direct_publish() -> Bool {
  if !direct_ready.val {
    return false
  }
  direct_active.val = 1 - direct_active.val
  direct_cursor.val = 0
  // Skip old events once at publication, bounded by page capacity.
  let data = direct_banks[direct_active.val]
  while direct_cursor.val < direct_count[direct_active.val] &&
        data[direct_cursor.val * 6] < direct_sample.val.to_double() {
    direct_cursor.val += 1
  }
  direct_ready.val = false
  true
}

///|
pub fn direct_process() -> Bool {
  // Bounded prototype clock: stop before Int arithmetic can overflow.
  if direct_sample.val >= 1000000000 {
    return false
  }
  if sched_routes.val.length() != 6 {
    return false
  }
  let left = match sched_left.val {
    Some(b) => b
    None => return false
  }
  let right = match sched_right.val {
    Some(b) => b
    None => return false
  }
  left.fill(0.0)
  right.fill(0.0)
  let data = direct_banks[direct_active.val]
  let first = direct_cursor.val
  let mut end = first
  while end < direct_count[direct_active.val] &&
        data[end * 6] < (direct_sample.val + 128).to_double() {
    end += 1
  }
  for route in 0..<6 {
    let sp = sched_routes.val[route].pool
    for slot in 0..<24 {
      let index = route * 24 + slot
      let handle = direct_handles[index]
      if handle >= 0L && direct_ends[index] <= direct_sample.val {
        ignore(
          sp.pool.note_off_bool(
            @moondsp.VoiceHandle::from_parts(
              slot=@moondsp.VoiceHandle::packed_slot(handle),
              generation=@moondsp.VoiceHandle::packed_generation(handle),
            ),
          ),
        )
        direct_handles[index] = -1L
      }
    }
    for event in first..<end {
      let i = event * 6
      if data[i + 2].to_int() == route {
        let pan = data[i + 5]
        let handle = sp.pool.note_on_prevalidated_pair_id(
          sp.gain_index,
          data[i + 4],
          if route == 5 {
            0
          } else {
            -1
          },
          data[i + 3],
          pan != 2.0,
          if pan == 2.0 {
            0.0
          } else {
            pan
          },
        )
        if handle < 0L {
          return false
        }
        let index = route * 24 + @moondsp.VoiceHandle::packed_slot(handle)
        direct_handles[index] = handle
        direct_ends[index] = data[i + 1].to_int()
      }
    }
    sp.tmp_left.fill(0.0)
    sp.tmp_right.fill(0.0)
    sp.pool.process(direct_context, sp.tmp_left, sp.tmp_right)
    accumulate_sub_pool(sp, left, right)
  }
  direct_cursor.val = end
  direct_sample.val += 128
  for i in 0..<128 {
    left.set(i, left.get(i) * sched_gain.val)
    right.set(i, right.get(i) * sched_gain.val)
  }
  true
}
