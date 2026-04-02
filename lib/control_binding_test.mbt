///|
test "build: valid bindings produce Ok" {
  let template = [
    DspNode::oscillator(Waveform::Sine, 440.0),
    DspNode::gain(0, 0.3),
    DspNode::output(1),
  ]
  let result = ControlBindingBuilder::new()
    .bind(key="note", node_index=0, slot=GraphParamSlot::Value0)
    .bind(key="gain", node_index=1, slot=GraphParamSlot::Value0)
    .build(template)
  assert_true(result is Ok(_))
}

///|
test "build: invalid node index returns InvalidNodeIndex" {
  let template = [DspNode::constant(1.0), DspNode::output(0)]
  let result = ControlBindingBuilder::new()
    .bind(key="note", node_index=5, slot=GraphParamSlot::Value0)
    .build(template)
  assert_eq(result, Err(ControlBindingError::InvalidNodeIndex(5)))
}

///|
test "build: negative node index returns InvalidNodeIndex" {
  let template = [DspNode::constant(1.0), DspNode::output(0)]
  let result = ControlBindingBuilder::new()
    .bind(key="note", node_index=-1, slot=GraphParamSlot::Value0)
    .build(template)
  assert_eq(result, Err(ControlBindingError::InvalidNodeIndex(-1)))
}

///|
test "build: invalid slot for node returns InvalidSlotForNode" {
  let template = [DspNode::constant(1.0), DspNode::output(0)]
  let result = ControlBindingBuilder::new()
    .bind(key="x", node_index=1, slot=GraphParamSlot::Value0)
    .build(template)
  assert_eq(
    result,
    Err(ControlBindingError::InvalidSlotForNode(1, GraphParamSlot::Value0)),
  )
}

///|
test "build: duplicate keys returns DuplicateKey" {
  let template = [
    DspNode::constant(1.0),
    DspNode::gain(0, 0.3),
    DspNode::output(1),
  ]
  let result = ControlBindingBuilder::new()
    .bind(key="gain", node_index=0, slot=GraphParamSlot::Value0)
    .bind(key="gain", node_index=1, slot=GraphParamSlot::Value0)
    .build(template)
  assert_eq(result, Err(ControlBindingError::DuplicateKey("gain")))
}

///|
test "build: duplicate targets allowed" {
  let template = [
    DspNode::oscillator(Waveform::Sine, 440.0),
    DspNode::output(0),
  ]
  let result = ControlBindingBuilder::new()
    .bind(key="freq", node_index=0, slot=GraphParamSlot::Value0)
    .bind(key="note", node_index=0, slot=GraphParamSlot::Value0)
    .build(template)
  assert_true(result is Ok(_))
}

///|
test "build: empty builder produces Ok with empty map" {
  let template = [DspNode::constant(1.0), DspNode::output(0)]
  let result = ControlBindingBuilder::new().build(template)
  assert_true(result is Ok(_))
}
