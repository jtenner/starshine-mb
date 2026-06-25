///|
fn code_pushing_wbtest_lift_hot_raw(text : String) -> @ir.HotFunc {
  pass_test_lift_first_func(text)
}

///|
test "code-pushing segment inventory recognizes if push-point windows" {
  let func = code_pushing_wbtest_lift_hot_raw(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
  )

  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(func, @ir.HotRegionRef::root(), 0),
    "candidate:if",
  )
}

///|
test "code-pushing segment inventory recognizes dropped if push-point windows" {
  let func = code_pushing_wbtest_lift_hot_raw(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    i32.const 7
      #|    local.set 1
      #|    (drop
      #|      (if (result i32) (local.get 0)
      #|        (then (local.get 1))
      #|        (else (i32.const 0))))))
      #|
    ),
  )

  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(func, @ir.HotRegionRef::root(), 0),
    "candidate:dropped-if",
  )
}

///|
test "code-pushing segment inventory recognizes conditional branch push-point windows" {
  let func = code_pushing_wbtest_lift_hot_raw(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    (drop
      #|      (block (result i32)
      #|        i32.const 7
      #|        local.set 1
      #|        local.get 1
      #|        local.get 0
      #|        br_if 0))))
      #|
    ),
  )

  let drop_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, drop_id, 0)
  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(
      func,
      @ir.hot_region_body_ref(func, block_id),
      0,
    ),
    "candidate:conditional-branch",
  )
}

///|
test "code-pushing segment inventory reports SFA rejection reasons" {
  let prefix_read = code_pushing_wbtest_lift_hot_raw(
    "(module (func (param i32) (local i32) local.get 1 drop i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
  )
  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(
      prefix_read,
      @ir.HotRegionRef::root(),
      1,
    ),
    "reject:prefix-local-read",
  )

  let multiple_writes = code_pushing_wbtest_lift_hot_raw(
    "(module (func (param i32) (local i32) i32.const 6 local.set 1 i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
  )
  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(
      multiple_writes,
      @ir.HotRegionRef::root(),
      1,
    ),
    "reject:multiple-local-writes",
  )
}

///|
test "code-pushing segment inventory reports ordered-before barriers" {
  let func = code_pushing_wbtest_lift_hot_raw(
    (
      #|(module
      #|  (global i32 (i32.const 9))
      #|  (memory 1)
      #|  (func (param i32) (local i32)
      #|    global.get 0
      #|    local.set 1
      #|    i32.const 0
      #|    i32.const 1
      #|    i32.store
      #|    local.get 0
      #|    if
      #|      local.get 1
      #|      drop
      #|    end))
      #|
    ),
  )

  @debug.assert_eq(
    code_pushing_segment_window_diagnostic(func, @ir.HotRegionRef::root(), 0),
    "reject:ordered-before-barrier",
  )
}

///|
fn code_pushing_wbtest_run_hot_func(func : @ir.HotFunc) -> @ir.HotFunc {
  let ctx = HotPassContext::new(
    code_pushing_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) => abort("expected code-pushing hot pass success, got \{err}")
  }
}

///|
fn code_pushing_wbtest_expect_op(
  func : @ir.HotFunc,
  node_id : Int,
  expected : String,
) -> Unit {
  let op = @ir.hot_node_get(func, node_id).op
  match (expected, op) {
    ("nop", @ir.HotOp::Nop) => ()
    ("drop", @ir.HotOp::Drop) => ()
    ("local.set", @ir.HotOp::LocalSet) => ()
    ("br_on_non_null", @ir.HotOp::BrOnNonNull) => ()
    _ => abort("expected \{expected}, got \{op}")
  }
}

///|
fn code_pushing_wbtest_br_on_non_null_prefix_payload_fixture(
  prefix_reads_moved : Bool,
  guard_reads_moved : Bool,
  second_set? : Bool = false,
) -> @ir.HotFunc {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::externref()
  let nullable_extern = @lib.RefType::new(true, extern_heap)
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(
      params=[extern_ref],
      locals=if guard_reads_moved {
        [extern_ref]
      } else if second_set {
        [@lib.ValType::i32(), @lib.ValType::i32()]
      } else {
        [@lib.ValType::i32()]
      },
    ),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [@lib.ValType::i32(), extern_ref]),
  )
  let block_id = @ir.hot_build_resolved_block(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [],
    [@lib.ValType::i32(), extern_ref],
    [],
  )
  let target = @ir.hot_control_node_label(func, block_id)
  let body : Array[Int] = []
  body.push(
    @ir.hot_build_local_set(
      func,
      1,
      if guard_reads_moved {
        @ir.hot_build_ref_null(func, nullable_extern)
      } else {
        @ir.hot_build_const_i32(func, @lib.I32(7))
      },
    ),
  )
  if second_set {
    body.push(
      @ir.hot_build_local_set(
        func,
        2,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
    )
  }
  let prefix_payload = if prefix_reads_moved {
    @ir.hot_build_local_get(func, 1)
  } else {
    @ir.hot_build_const_i32(func, @lib.I32(42))
  }
  let guard_ref = if guard_reads_moved {
    @ir.hot_build_local_get(func, 1)
  } else {
    @ir.hot_build_local_get(func, 0)
  }
  let branch = @ir.hot_build_node(
    func,
    @ir.HotOp::br_on_non_null(),
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
    imm0=target,
    children=[prefix_payload, guard_ref],
  )
  body.push(@ir.hot_build_drop(func, branch))
  body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)))
  if second_set {
    body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 2)))
  }
  body.push(@ir.hot_build_const_i32(func, @lib.I32(13)))
  body.push(@ir.hot_build_ref_null(func, nullable_extern))
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, block_id),
    body,
  )
  @ir.hot_root_append(func, block_id)
  code_pushing_wbtest_run_hot_func(func)
}

///|
fn code_pushing_wbtest_find_first_block(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block => return node_id
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let found = code_pushing_wbtest_find_first_block(
      func,
      @ir.hot_child_get(func, node_id, slot),
    )
    if found >= 0 {
      return found
    }
  }
  -1
}

///|
fn code_pushing_wbtest_root_block(func : @ir.HotFunc) -> Int {
  for slot = 0; slot < @ir.hot_root_count(func); slot = slot + 1 {
    let found = code_pushing_wbtest_find_first_block(
      func,
      @ir.hot_root_get(func, slot),
    )
    if found >= 0 {
      return found
    }
  }
  abort("expected block root")
}

///|
test "code-pushing moves pure SFA set after br_on_non_null prefix payload before later same-block use" {
  let func = code_pushing_wbtest_br_on_non_null_prefix_payload_fixture(
    false, false,
  )

  let block_id = code_pushing_wbtest_root_block(func)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 6)
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "nop",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_wbtest_expect_op(func, branch_drop, "drop")
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_non_null",
  )
  let moved_set = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_wbtest_expect_op(func, moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, moved_set).imm0, 1)
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 3),
    "drop",
  )
}

///|
test "code-pushing moves adjacent pure SFA sets after br_on_non_null prefix payload in source order" {
  let func = code_pushing_wbtest_br_on_non_null_prefix_payload_fixture(
    false,
    false,
    second_set=true,
  )

  let block_id = code_pushing_wbtest_root_block(func)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 9)
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "nop",
  )
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 1),
    "nop",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 2)
  code_pushing_wbtest_expect_op(func, branch_drop, "drop")
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_non_null",
  )
  let first_moved_set = @ir.hot_region_get(func, body_ref, 3)
  code_pushing_wbtest_expect_op(func, first_moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, first_moved_set).imm0, 1)
  let second_moved_set = @ir.hot_region_get(func, body_ref, 4)
  code_pushing_wbtest_expect_op(func, second_moved_set, "local.set")
  @debug.assert_eq(@ir.hot_node_get(func, second_moved_set).imm0, 2)
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 5),
    "drop",
  )
}

///|
test "code-pushing keeps SFA set before br_on_non_null prefix payload that reads it" {
  let func = code_pushing_wbtest_br_on_non_null_prefix_payload_fixture(
    true, false,
  )

  let block_id = code_pushing_wbtest_root_block(func)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_wbtest_expect_op(func, branch_drop, "drop")
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_non_null",
  )
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 2),
    "drop",
  )
}

///|
test "code-pushing moves lowered generated br_on_non_null prefix payload sets after branch" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::externref()
  let nullable_extern = @lib.RefType::new(true, extern_heap)
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[extern_ref], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      extern_ref,
    ]),
  )
  let block_id = @ir.hot_build_resolved_block(
    func,
    @lib.BlockType::val_type(extern_ref),
    [],
    [extern_ref],
    [],
  )
  let target = @ir.hot_control_node_label(func, block_id)
  let body : Array[Int] = []
  body.push(
    @ir.hot_build_local_set(func, 1, @ir.hot_build_const_i32(func, @lib.I32(7))),
  )
  body.push(
    @ir.hot_build_local_set(func, 2, @ir.hot_build_const_i32(func, @lib.I32(9))),
  )
  body.push(
    @ir.hot_build_local_set(
      func,
      3,
      @ir.hot_build_const_i32(func, @lib.I32(42)),
    ),
  )
  body.push(@ir.hot_build_local_set(func, 5, @ir.hot_build_local_get(func, 0)))
  body.push(@ir.hot_build_local_set(func, 4, @ir.hot_build_local_get(func, 3)))
  body.push(
    @ir.hot_build_node(
      func,
      @ir.HotOp::br_on_non_null(),
      @ir.hot_type_intern_value(func, extern_ref),
      imm0=target,
      children=[@ir.hot_build_local_get(func, 5)],
    ),
  )
  body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 4)))
  body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)))
  body.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 2)))
  body.push(@ir.hot_build_ref_null(func, nullable_extern))
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, block_id),
    body,
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, block_id))
  ignore(code_pushing_wbtest_run_hot_func(func))
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let mut branch_idx = -1
  let mut first_set_idx = -1
  let mut second_set_idx = -1
  for idx = 0; idx < @ir.hot_region_root_count(func, body_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, body_ref, idx)
    if root_id >= 0 && @ir.hot_node_is_live(func, root_id) {
      let root = @ir.hot_node_get(func, root_id)
      match root.op {
        @ir.HotOp::BrOnNonNull => branch_idx = idx
        @ir.HotOp::LocalSet =>
          if root.imm0 == 1 {
            first_set_idx = idx
          } else if root.imm0 == 2 {
            second_set_idx = idx
          }
        _ => ()
      }
    }
  }
  if branch_idx < 0 || first_set_idx < 0 || second_set_idx < 0 {
    abort("expected branch and generated prefix local.set roots")
  }
  if !(branch_idx < first_set_idx && first_set_idx < second_set_idx) {
    abort(
      "expected generated prefix sets after br_on_non_null in source order; got branch=\{branch_idx}, first=\{first_set_idx}, second=\{second_set_idx}",
    )
  }
}

///|
test "code-pushing keeps SFA set before br_on_non_null guard that reads it" {
  let func = code_pushing_wbtest_br_on_non_null_prefix_payload_fixture(
    false, true,
  )

  let block_id = code_pushing_wbtest_root_block(func)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, body_ref), 5)
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 0),
    "local.set",
  )
  let branch_drop = @ir.hot_region_get(func, body_ref, 1)
  code_pushing_wbtest_expect_op(func, branch_drop, "drop")
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_child_get(func, branch_drop, 0),
    "br_on_non_null",
  )
  code_pushing_wbtest_expect_op(
    func,
    @ir.hot_region_get(func, body_ref, 2),
    "drop",
  )
}
