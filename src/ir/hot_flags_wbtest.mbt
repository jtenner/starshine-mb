///|
test "representative opcode families classify call memory branch and throw flags" {
  let func = HotFunc::new()

  let call = hot_alloc_node(
    func,
    hot_make_simple_node(HotOp::Call, hot_type_void(func), 0U, 0, 0, []),
  )
  let load = hot_alloc_node(
    func,
    hot_make_simple_node(HotOp::Load, hot_type_void(func), 0U, 0, 0, []),
  )
  let store = hot_alloc_node(
    func,
    hot_make_simple_node(HotOp::Store, hot_type_void(func), 0U, 0, 0, []),
  )
  let branch = hot_alloc_node(
    func,
    hot_make_simple_node(HotOp::Br, hot_type_void(func), 0U, 0, 0, []),
  )
  let throw_ = hot_alloc_node(
    func,
    hot_make_simple_node(HotOp::Throw, hot_type_void(func), 0U, 0, 0, []),
  )

  assert_true(hot_node_has_flag(func, call, HOT_FLAG_CALL))
  assert_true(hot_has_side_effect(func, call))
  assert_true(hot_may_trap(func, load))
  assert_true(hot_node_has_flag(func, load, HOT_FLAG_LOAD))
  assert_true(hot_node_has_flag(func, store, HOT_FLAG_STORE))
  assert_true(hot_has_side_effect(func, store))
  assert_true(hot_is_branch(func, branch))
  assert_true(hot_is_terminator_node(func, branch))
  assert_true(hot_node_may_throw_exception(func, throw_))
  assert_true(hot_has_exceptional_succ(func, throw_))
}

///|
test "node construction and replacement always canonicalize flags" {
  let func = HotFunc::new()
  let node = hot_alloc_node(
    func,
    hot_make_simple_node(
      HotOp::Nop,
      hot_type_void(func),
      HOT_FLAG_SIDE_EFFECT,
      0,
      0,
      [],
    ),
  )

  assert_eq(hot_node_flags(func, node), hot_default_flags_for_op(HotOp::Nop))
  assert_false(hot_has_side_effect(func, node))

  hot_replace_node(func, node, {
    op: HotOp::Return,
    ty: hot_type_void(func),
    flags: HOT_FLAG_VALUE,
    imm0: 0,
    imm1: 0,
    child_base: 0,
    child_count: 0,
  })

  assert_eq(hot_node_flags(func, node), hot_default_flags_for_op(HotOp::Return))
  assert_true(hot_is_terminator_node(func, node))
  assert_true(hot_has_side_effect(func, node))
}
