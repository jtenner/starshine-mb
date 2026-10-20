///|
test "ssa destruction traverses typed loop entry operands" {
  let func = HotFunc::new()
  let ty = hot_type_intern_resolved_block_result(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [@lib.ValType::i32()],
    [],
  )
  let entry = hot_build_const_i32(func, @lib.I32(7))
  let body = hot_build_nop(func)
  let loop_id = hot_build_node(func, HotOp::Loop, ty, children=[entry, body])
  let label = hot_label_alloc(func, HotLabelKind::LoopLabel, ty, loop_id, 1)
  hot_node_set(func, loop_id, { ..hot_node_get(func, loop_id), imm0: label, })
  hot_root_append(func, loop_id)

  let reachable = ssa_destroy_reachable_nodes(func)
  assert_true(reachable[entry])
  assert_true(reachable[body])
}

///|
test "direct ssa destruction preserves a phi source inside a branch operand" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  hot_body_result_type_set(
    func,
    hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let initial_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  let independent_set = hot_build_local_set(
    func,
    2,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let block = hot_build_block(func, @lib.BlockType::void_(), [])
  let label = hot_control_node_label(func, block)
  let first_branch = hot_build_br_if(func, label, hot_build_local_get(func, 0))
  let branch_tee = hot_build_local_tee(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(3)),
  )
  let second_branch = hot_build_br_if(func, label, branch_tee)
  let fallthrough_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(5)),
  )
  hot_region_replace_body(func, hot_region_body_ref(func, block), [
    first_branch, second_branch, fallthrough_set,
  ])
  let independent_get = hot_build_local_get(func, 2)
  let merge_get = hot_build_local_get(func, 1)
  for
    root in [
      initial_set,
      independent_set,
      block,
      hot_build_drop(func, independent_get),
      merge_get,
    ] {
    hot_root_append(func, root)
  }

  let cfg = cfg_build(func, expand_operand_control=true)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let live = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, live, use_def)
  ignore(ssa_destroy_into_hot(func, cfg, ssa))

  assert_eq(hot_node_get(func, branch_tee).imm0, 1)
  assert_eq(hot_node_get(func, merge_get).imm0, 1)
  let independent_local = hot_node_get(func, independent_set).imm0
  assert_true(independent_local != 2)
  assert_eq(hot_node_get(func, independent_get).imm0, independent_local)
  hot_verify_all_or_abort(func)
}
