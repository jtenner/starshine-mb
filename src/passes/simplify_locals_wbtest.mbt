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
  @debug.assert_eq(
    @ir.hot_node_get(func, fallthrough_set).op.to_string(),
    "LocalSet",
  )
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
      2,
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

  @debug.assert_eq(effects.local_reads.length(), 2)
  assert_true(effects.local_reads.contains(0))
  assert_true(effects.local_reads.contains(3))
  @debug.assert_eq(effects.local_writes.length(), 2)
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
    global_reads: [],
    global_writes: [],
  }

  assert_false(simplify_locals_sinkables_should_bulk_clear(sinkables))

  simplify_locals_sinkables_set(sinkables, 1, { node_id: 1, effects })
  simplify_locals_sinkables_set(sinkables, 2, { node_id: 2, effects })
  assert_false(simplify_locals_sinkables_should_bulk_clear(sinkables))

  simplify_locals_sinkables_set(sinkables, 3, { node_id: 3, effects })
  assert_true(simplify_locals_sinkables_should_bulk_clear(sinkables))

  simplify_locals_clear_sinkables(sinkables)
  @debug.assert_eq(sinkables.active_locals.length(), 0)
  @debug.assert_eq(sinkables.local_read_counts[0], 0)
  @debug.assert_eq(sinkables.local_write_counts[1], 0)
}

///|
test "simplify-locals deferred follow-up records only scanned first-cycle sets" {
  // Protected embedded-tee child regions are intentionally skipped by the
  // root-only SLNS path. Their internal multi-use local.set traffic must not be
  // counted as a deferred root follow-up candidate, otherwise the pass pays for
  // a second protected root scan that cannot touch those child nodes.
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (func (param i32) (local i32 i32)
      #|    local.get 0
      #|    if
      #|      i32.const 7
      #|      local.set 1
      #|      local.get 1
      #|      drop
      #|      local.get 1
      #|      drop
      #|      i32.const 9
      #|      local.tee 2
      #|      i32.eqz
      #|      drop
      #|      local.get 2
      #|      drop
      #|    end))
      #|),
    ),
  )
  let detached : Array[Int] = []
  let deferred_sets : Array[Int] = []
  assert_false(
    simplify_locals_scan_region(
      func,
      @ir.HotRegionRef::root(),
      simplify_locals_new_sinkables(func),
      true,
      simplify_locals_count_local_gets(func),
      detached,
      true,
      true,
      false,
      deferred_sets,
    ),
  )
  @debug.assert_eq(deferred_sets.length(), 0)
}

///|
fn simplify_locals_wbtest_run_nostructure(func : @ir.HotFunc) -> Unit {
  let ctx = HotPassContext::new(
    simplify_locals_nostructure_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      abort("expected simplify-locals-nostructure success, got \{err}")
  }
}

///|
fn simplify_locals_wbtest_try_fixture(throwing : Bool) -> @ir.HotFunc {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let value_id = if throwing {
    @ir.hot_build_call(func, 0, [i32_type], [])
  } else {
    @ir.hot_build_const_i32(func, @lib.I32(7))
  }
  @ir.hot_root_append(func, @ir.hot_build_local_set(func, 0, value_id))
  @ir.hot_root_append(
    func,
    @ir.hot_build_try(
      func,
      @lib.BlockType::val_type(i32_type),
      [@ir.hot_build_local_get(func, 0)],
      catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(9))]),
    ),
  )
  func
}

///|
fn simplify_locals_wbtest_try_catch_parent_fixture() -> @ir.HotFunc {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  @ir.hot_root_append(
    func,
    @ir.hot_build_local_set(func, 0, @ir.hot_build_const_i32(func, @lib.I32(7))),
  )
  @ir.hot_root_append(
    func,
    @ir.hot_build_try(
      func,
      @lib.BlockType::val_type(i32_type),
      [
        @ir.hot_build_throw(func, @lib.TagIdx::new(0U), []),
        @ir.hot_build_const_i32(func, @lib.I32(0)),
      ],
      catch_body=Some([@ir.hot_build_local_get(func, 0)]),
    ),
  )
  func
}

///|
fn simplify_locals_wbtest_try_catch_inner_fixture() -> @ir.HotFunc {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  @ir.hot_root_append(
    func,
    @ir.hot_build_try(
      func,
      @lib.BlockType::val_type(i32_type),
      [
        @ir.hot_build_throw(func, @lib.TagIdx::new(0U), []),
        @ir.hot_build_const_i32(func, @lib.I32(0)),
      ],
      catch_body=Some([
        @ir.hot_build_local_set(
          func,
          0,
          @ir.hot_build_const_i32(func, @lib.I32(7)),
        ),
        @ir.hot_build_local_get(func, 0),
      ]),
    ),
  )
  func
}

///|
fn simplify_locals_wbtest_try_table_catch_list_parent_fixture() -> @ir.HotFunc {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  @ir.hot_root_append(
    func,
    @ir.hot_build_local_set(func, 0, @ir.hot_build_const_i32(func, @lib.I32(7))),
  )
  @ir.hot_root_append(
    func,
    @ir.hot_build_try_table(
      func,
      @lib.BlockType::val_type(i32_type),
      [],
      [@ir.hot_build_const_i32(func, @lib.I32(0))],
      catch_list_body=[@ir.hot_build_local_get(func, 0)],
    ),
  )
  func
}

///|
fn simplify_locals_wbtest_try_table_catch_list_inner_fixture() -> @ir.HotFunc {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new(locals=@ir.HotLocals::new(locals=[i32_type]))
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  @ir.hot_root_append(
    func,
    @ir.hot_build_try_table(
      func,
      @lib.BlockType::val_type(i32_type),
      [],
      [@ir.hot_build_const_i32(func, @lib.I32(0))],
      catch_list_body=[
        @ir.hot_build_local_set(
          func,
          0,
          @ir.hot_build_const_i32(func, @lib.I32(7)),
        ),
        @ir.hot_build_local_get(func, 0),
      ],
    ),
  )
  func
}

///|
test "simplify-locals-nostructure sinks nonthrowing set into legacy try body" {
  // Binaryen version_130 sinks a pure pending value into a legacy `try` body.
  // The public WAT path desugars legacy `try` before HOT, so this direct-HOT
  // fixture locks the existing `HotOp::Try` implementation rather than adding a
  // red-first behavior fix.
  let func = simplify_locals_wbtest_try_fixture(false)
  simplify_locals_wbtest_run_nostructure(func)

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::Nop => ()
    other => fail("expected dead root local.set to become nop, got \{other}")
  }
  let try_id = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, try_id).op {
    @ir.HotOp::Try => ()
    other => fail("expected legacy try root, got \{other}")
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 1)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 0)).op {
    @ir.HotOp::Const => ()
    other => fail("expected try body local.get replaced by const, got \{other}")
  }
}

///|
test "simplify-locals-nostructure keeps throwing set before legacy try body" {
  // Calls may throw, so the pending value must stay outside the legacy try
  // handler just as Binaryen version_130 keeps `local.set(call)` before `try`.
  let func = simplify_locals_wbtest_try_fixture(true)
  simplify_locals_wbtest_run_nostructure(func)

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::LocalSet => ()
    other => fail("expected throwing root local.set to remain, got \{other}")
  }
  let try_id = @ir.hot_root_get(func, 1)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 1)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 0)).op {
    @ir.HotOp::LocalGet => ()
    other => fail("expected try body local.get to remain, got \{other}")
  }
}

///|
test "simplify-locals-nostructure keeps parent set out of legacy try catch" {
  // Binaryen version_130 does not sink a pending pre-try value into a legacy
  // catch body. The catch region is scanned with fresh sinkables, so the parent
  // carrier remains available to exceptional control without moving into it.
  let func = simplify_locals_wbtest_try_catch_parent_fixture()
  simplify_locals_wbtest_run_nostructure(func)

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::LocalSet => ()
    other => fail("expected parent local.set to remain, got \{other}")
  }
  let try_id = @ir.hot_root_get(func, 1)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).op {
    @ir.HotOp::LocalGet => ()
    other => fail("expected catch local.get to remain, got \{other}")
  }
}

///|
test "simplify-locals-nostructure optimizes local traffic inside legacy try catch" {
  // The catch boundary is fresh, not disabled: Binaryen version_130 still sinks
  // local traffic that is produced and consumed wholly inside the catch body.
  let func = simplify_locals_wbtest_try_catch_inner_fixture()
  simplify_locals_wbtest_run_nostructure(func)

  let try_id = @ir.hot_root_get(func, 0)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).op {
    @ir.HotOp::Nop => ()
    other => fail("expected catch local.set to become nop, got \{other}")
  }
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).op {
    @ir.HotOp::Const => ()
    other => fail("expected catch local.get replaced by const, got \{other}")
  }
}

///|
test "simplify-locals-nostructure keeps parent set out of try_table catch list" {
  // Starshine's HOT `try_table` catch-list region is a branch-target region, not
  // ordinary fallthrough body code. Keep parent sinkables out of that region just
  // as public Binaryen catch bodies do not inherit pre-try sinkables.
  let func = simplify_locals_wbtest_try_table_catch_list_parent_fixture()
  simplify_locals_wbtest_run_nostructure(func)

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::LocalSet => ()
    other => fail("expected parent local.set to remain, got \{other}")
  }
  let try_id = @ir.hot_root_get(func, 1)
  let catch_ref = @ir.hot_region_catch_list_ref(func, try_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 1)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).op {
    @ir.HotOp::LocalGet => ()
    other => fail("expected catch-list local.get to remain, got \{other}")
  }
}

///|
test "simplify-locals-nostructure optimizes local traffic inside try_table catch list" {
  // The catch-list scan is fresh but still active for local traffic whose
  // producer and consumer both live inside Starshine's HOT catch-list region.
  let func = simplify_locals_wbtest_try_table_catch_list_inner_fixture()
  simplify_locals_wbtest_run_nostructure(func)

  let try_id = @ir.hot_root_get(func, 0)
  let catch_ref = @ir.hot_region_catch_list_ref(func, try_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 2)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 0)).op {
    @ir.HotOp::Nop => ()
    other => fail("expected catch-list local.set to become nop, got \{other}")
  }
  match @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 1)).op {
    @ir.HotOp::Const => ()
    other =>
      fail("expected catch-list local.get replaced by const, got \{other}")
  }
}
