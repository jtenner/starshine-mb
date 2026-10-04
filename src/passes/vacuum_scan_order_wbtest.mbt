///|
fn vacuum_scan_order_probe_body() -> Array[@lib.Instruction] {
  let load12 = @lib.MemArg::new(0U, None, 12UL)
  let load20 = @lib.MemArg::new(0U, None, 20UL)
  let slot = @lib.LocalIdx::new(18U)
  let root = @lib.LocalIdx::new(1U)
  let ctx = @lib.LocalIdx::new(2U)
  let mask = @lib.LocalIdx::new(7U)
  let increment = @lib.LocalIdx::new(50U)
  let probe = @lib.LocalIdx::new(49U)
  let result = @lib.LocalIdx::new(68U)
  let tagged = @lib.LocalIdx::new(384U)
  let child = [
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(slot),
    @lib.Instruction::i32_load(load20),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(increment),
    @lib.Instruction::local_get(root),
    @lib.Instruction::i32_load(load12),
    @lib.Instruction::local_tee(probe),
    @lib.Instruction::call(@lib.FuncIdx::new(4U)),
    @lib.Instruction::local_get(probe),
    @lib.Instruction::local_get(increment),
    @lib.Instruction::call(@lib.FuncIdx::new(18U)),
    @lib.Instruction::local_set(result),
    @lib.Instruction::local_get(probe),
    @lib.Instruction::call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::local_get(root),
    @lib.Instruction::local_get(ctx),
    @lib.Instruction::local_get(result),
    @lib.Instruction::call(@lib.FuncIdx::new(10U)),
    @lib.Instruction::local_tee(tagged),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
    @lib.Instruction::i64_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(slot),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ],
      Some([
        @lib.Instruction::local_get(mask),
        @lib.Instruction::local_get(mask),
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::i32_wrap_i64(),
        @lib.Instruction::i32_and(),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(slot),
            @lib.Instruction::call(@lib.FuncIdx::new(5U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ],
          None,
        ),
      ]),
    ),
  ]
  child
}

///|
fn vacuum_scan_order_parent() -> Array[@lib.Instruction] {
  let parent_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5369_load_call_tag_refcount_dispatch_body(),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(12U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
    @lib.Instruction::call(@lib.FuncIdx::new(7104U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(60U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::i32_const(@lib.I32(202440)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(60U)),
    @lib.Instruction::call(@lib.FuncIdx::new(34U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(61U)),
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  parent_body
}

///|
fn vacuum_scan_order_result(
  kind : Int,
  body : Array[@lib.Instruction],
  parent : Array[@lib.Instruction],
  reference : Bool,
) -> UInt? {
  if kind == 0 {
    if reference {
      vacuum_scan_order_reference_0(body)
    } else {
      run_hot_pipeline_raw_vacuum_f1900_increment_probe_release_prefix_slot(
        body,
      )
    }
  } else {
    let admitted = if kind == 1 {
      if reference {
        vacuum_scan_order_reference_1(body, parent, 0)
      } else {
        run_hot_pipeline_raw_vacuum_body_is_f5369_load_call_tag_refcount_dispatch_before_allocation_continuation_preserve_candidate(
          body, parent, 0,
        )
      }
    } else if reference {
      vacuum_scan_order_reference_2(body)
    } else {
      run_hot_pipeline_raw_vacuum_body_is_call_local_set_tag_cascade_if_wrapper_candidate(
        body,
      )
    }
    if admitted {
      Some(0U)
    } else {
      None
    }
  }
}

///|
fn vacuum_scan_order_bodies() -> Array[Array[@lib.Instruction]] {
  [
    vacuum_scan_order_probe_body(),
    pass_manager_test_vacuum_f5369_load_call_tag_refcount_dispatch_body(),
    pass_manager_test_vacuum_tag_cascade_body(4, 0, 20),
    pass_manager_test_vacuum_tag_cascade_body(2, 4, 72),
  ]
}

///|
test "vacuum shape-first queries preserve all admitted shapes nops and ownership" {
  let parent = vacuum_scan_order_parent()
  for index, original in vacuum_scan_order_bodies() {
    let kind = Int::min(index, 2)
    let body = run_hot_pipeline_raw_vacuum_strip_top_level_nops(original)
    let padded : Array[@lib.Instruction] = [@lib.Instruction::nop()]
    for instr in body {
      padded.push(instr)
      padded.push(@lib.Instruction::nop())
    }
    let expected = if kind == 0 { Some(18U) } else { Some(0U) }
    for fixture in [body, padded] {
      let saved = fixture.copy()
      assert_eq(
        vacuum_scan_order_result(kind, fixture, parent, false),
        expected,
      )
      assert_eq(vacuum_scan_order_result(kind, fixture, parent, true), expected)
      assert_eq(fixture, saved)
    }
  }
}

///|
test "vacuum shape-first queries intentionally reject mismatched fixed prefixes" {
  let parent = vacuum_scan_order_parent()
  for index, original in vacuum_scan_order_bodies() {
    let kind = Int::min(index, 2)
    let body = run_hot_pipeline_raw_vacuum_strip_top_level_nops(original)
    let prefix_len = if kind == 0 { 15 } else if kind == 1 { 13 } else { 4 }
    for offset in 0..<prefix_len {
      let changed = body.copy()
      changed[offset] = @lib.Instruction::drop()
      assert_eq(vacuum_scan_order_result(kind, changed, parent, false), None)
      assert_eq(vacuum_scan_order_result(kind, changed, parent, true), None)
    }
    for width in [0, 1, 12, 22] {
      let mismatched = Array::make(width, @lib.Instruction::drop())
      assert_eq(vacuum_scan_order_result(kind, mismatched, parent, false), None)
      assert_eq(vacuum_scan_order_result(kind, mismatched, parent, true), None)
    }
  }
}

///|
test "vacuum shape-first queries retain nested unreachable barriers on matching prefixes" {
  let parent = vacuum_scan_order_parent()
  let trap = [@lib.Instruction::unreachable_()]
  let nested_traps = [
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(trap)),
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(trap)),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new(trap),
    ),
    @lib.Instruction::if_(@lib.BlockType::void_(), [], Some(trap)),
  ]
  for index, original in vacuum_scan_order_bodies() {
    let kind = Int::min(index, 2)
    let body = run_hot_pipeline_raw_vacuum_strip_top_level_nops(original)
    let last = body.length() - 1
    guard body[last] is @lib.If(bt, then_body, else_body) else {
      fail("expected conditional")
    }
    for nested in nested_traps {
      let changed = body.copy()
      changed[last] = @lib.Instruction::if_(bt, then_body + [nested], else_body)
      assert_eq(vacuum_scan_order_result(kind, changed, parent, false), None)
      assert_eq(vacuum_scan_order_result(kind, changed, parent, true), None)
      assert_true(
        vacuum_scan_order_result(kind, body, parent, false) is Some(_),
      )
    }
  }
}
