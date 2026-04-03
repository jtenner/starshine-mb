///|
test "simplify-locals does not collect block exits through typed child carriers" {
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (func (param i32 i32) (result i32) (local i32)
      #|    (block $outer
      #|      (block $inner_res (result i32)
      #|        (block $inner
      #|          (local.get 0)
      #|          (if (result i32)
      #|            (then
      #|              (local.get 1)
      #|              (local.set 2)
      #|              (br $inner)
      #|            )
      #|            (else
      #|              (local.get 1)
      #|              (local.set 2)
      #|              (br $outer)
      #|            )
      #|          )
      #|          (br $inner_res)
      #|        )
      #|        (local.get 2)
      #|      )
      #|      (local.set 2)
      #|    )
      #|    (local.get 2))
      #|),
    ),
  )
  let outer_id = @ir.hot_root_get(func, 0)
  let outer_body = @ir.hot_region_body_ref(func, outer_id)
  let fallthrough_set = @ir.hot_region_get(func, outer_body, 0)
  assert_eq(@ir.hot_node_get(func, fallthrough_set).op.to_string(), "LocalSet")
  let inner_res_id = @ir.hot_child_get(func, fallthrough_set, 0)
  assert_true(
    simplify_locals_control_has_typed_branch_payload(func, inner_res_id),
  )
  assert_true(
    simplify_locals_subtree_has_branch_to_label(
      func,
      fallthrough_set,
      @ir.hot_control_node_label(func, outer_id),
    ),
  )
  let exits : Array[SimplifyLocalsBranchExit] = []
  assert_false(
    simplify_locals_collect_block_branch_exits(
      func,
      outer_body,
      @ir.hot_control_node_label(func, outer_id),
      exits,
    ),
  )
}

///|
test "simplify-locals does not rewrite block returns when the fallthrough value branches back" {
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (func (param i32 i32) (result i32) (local i32)
      #|    (block $outer
      #|      (block $inner_res (result i32)
      #|        (block $inner
      #|          (local.get 0)
      #|          (if (result i32)
      #|            (then
      #|              (local.get 1)
      #|              (local.set 2)
      #|              (br $inner)
      #|            )
      #|            (else
      #|              (local.get 1)
      #|              (local.set 2)
      #|              (br $outer)
      #|            )
      #|          )
      #|          (br $inner_res)
      #|        )
      #|        (local.get 2)
      #|      )
      #|      (local.set 2)
      #|    )
      #|    (local.get 2))
      #|),
    ),
  )
  let detached : Array[Int] = []
  assert_false(
    simplify_locals_try_rewrite_block_return(
      func,
      @ir.HotRegionRef::root(),
      0,
      @ir.hot_root_get(func, 0),
      simplify_locals_count_local_gets(func),
      detached,
    ),
  )
}

///|
test "simplify-locals records sparse pending local effects" {
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (func (param i32 i32) (result i32) (local i32 i32)
      #|    local.get 0
      #|    local.tee 3
      #|    local.get 3
      #|    i32.add
      #|    local.set 2
      #|    local.get 2))
      #|),
    ),
  )
  let set_id = @ir.hot_root_get(func, 0)
  let set_node = @ir.hot_node_get(func, set_id)
  let sinkables = simplify_locals_new_sinkables(func)
  let effects = simplify_locals_effects_for_pending_local_set(
    func, set_id, set_node, sinkables,
  )

  assert_eq(effects.local_reads.length(), 2)
  assert_true(effects.local_reads.contains(0))
  assert_true(effects.local_reads.contains(3))
  assert_eq(effects.local_writes.length(), 2)
  assert_true(effects.local_writes.contains(2))
  assert_true(effects.local_writes.contains(3))
}

///|
test "simplify-locals bulk-clear gate follows active sinkable density" {
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (func
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
      #|    nop))
      #|),
    ),
  )
  let sinkables = simplify_locals_new_sinkables(func)
  let effects = {
    mask: @ir.EFFECT_MASK_LOCAL_STATE,
    local_reads: [0],
    local_writes: [1],
  }

  assert_false(simplify_locals_sinkables_should_bulk_clear(sinkables))

  simplify_locals_sinkables_set(sinkables, 1, { node_id: 1, effects })
  simplify_locals_sinkables_set(sinkables, 2, { node_id: 2, effects })
  assert_false(simplify_locals_sinkables_should_bulk_clear(sinkables))

  simplify_locals_sinkables_set(sinkables, 3, { node_id: 3, effects })
  assert_true(simplify_locals_sinkables_should_bulk_clear(sinkables))

  simplify_locals_clear_sinkables(sinkables)
  assert_eq(sinkables.active_locals.length(), 0)
  assert_eq(sinkables.local_read_counts[0], 0)
  assert_eq(sinkables.local_write_counts[1], 0)
}
