///|
test "catch repair preserves a payload-free function without building node uses" {
  let func = HotFunc::new()
  for i = 0; i < 32; i = i + 1 {
    hot_root_append(
      func,
      hot_build_drop(func, hot_build_const_i32(func, @lib.I32(i))),
    )
  }
  let original = hot_lower_func(func)
  let revision = hot_revision_current(func)
  let builds = [0]
  let plan = hot_catch_payload_repair_plan(
    func,
    -1,
    use_def_builds=Some(builds),
  ).unwrap()
  assert_eq(plan.length(), 0)
  assert_eq(hot_revision_current(func), revision)
  assert_eq(hot_lower_func(func), original)
  assert_eq(builds[0], 0)
}

///|
test "catch repair still plans and captures a typed payload after preflight" {
  let func = HotFunc::new()
  let payload = hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let drop = hot_build_drop(func, payload)
  let block = hot_build_block(func, @lib.BlockType::void_(), [drop])
  let try_id = hot_build_try(
    func,
    @lib.BlockType::void_(),
    [hot_build_nop(func)],
    catch_body=Some([payload, block]),
  )
  hot_root_append(func, try_id)
  let builds = [0]
  let plan = hot_catch_payload_repair_plan(
    func,
    -1,
    use_def_builds=Some(builds),
  ).unwrap()
  assert_eq(plan.length(), 1)
  assert_eq(plan[0].lanes.length(), 1)
  assert_eq(plan[0].lanes[0].payload_id, payload)
  assert_eq(builds[0], 1)
  assert_true(hot_repair_ordered_catch_payloads(func))
  assert_eq(hot_local_type(func, 0), Some(@lib.ValType::i32()))
  let get = hot_child_get(func, drop, 0)
  assert_eq(hot_node_get(func, get).op, HotOp::LocalGet)
  assert_eq(hot_node_get(func, get).imm0, 0)
  let catch_ref = hot_region_catch_ref(func, try_id).unwrap()
  let capture = hot_region_get(func, catch_ref, 1)
  assert_eq(hot_node_get(func, capture).op, HotOp::LocalSet)
  assert_eq(hot_child_get(func, capture, 0), payload)
  hot_verify_control(func).unwrap()
}
