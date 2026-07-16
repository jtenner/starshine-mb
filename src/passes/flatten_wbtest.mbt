///|
fn flatten_test_build_rich_drop(func : @ir.HotFunc) -> Array[Int] {
  let rich = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  @ir.hot_node_exact_instr_set(func, rich, @lib.Instruction::i32_add())
  [rich, @ir.hot_build_drop(func, rich)]
}

///|
fn flatten_test_assert_hard_unsupported_no_mutation(
  func : @ir.HotFunc,
  rich : Int,
  drop_id : Int,
  unsupported_id : Int,
) -> Unit raise {
  @ir.hot_root_append(func, drop_id)
  @ir.hot_root_append(func, unsupported_id)
  let before = flatten_classify_hot(func)
  @debug.assert_eq(before.rich_operand_count, 1)
  @debug.assert_eq(before.unsupported_count, 1)
  match flatten_run_admission(func, before) {
    FlattenRunAdmission::UpstreamHardUnsupported => ()
    _ => fail("expected upstream-hard-unsupported flatten admission")
  }
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_local_count(func), 0)
  @debug.assert_eq(@ir.hot_root_count(func), 2)
  @debug.assert_eq(@ir.hot_root_get(func, 0), drop_id)
  @debug.assert_eq(@ir.hot_root_get(func, 1), unsupported_id)
  @debug.assert_eq(@ir.hot_child_get(func, drop_id, 0), rich)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, rich),
    Some(@lib.Instruction::i32_add()),
  )
  let after = flatten_classify_hot(func)
  @debug.assert_eq(after, before)
}

///|
test "flatten hard unsupported admission prevents partial mutation" {
  let unsupported_ops = [
    @ir.HotOp::br_on_null(),
    @ir.HotOp::br_on_non_null(),
    @ir.HotOp::br_on_cast(),
    @ir.HotOp::br_on_cast_fail(),
  ]
  for unsupported_op in unsupported_ops {
    let func = @ir.HotFunc::new()
    let rich_drop = flatten_test_build_rich_drop(func)
    let unsupported_id = @ir.hot_build_node(
      func,
      unsupported_op,
      @ir.hot_type_void(func),
    )
    flatten_test_assert_hard_unsupported_no_mutation(
      func,
      rich_drop[0],
      rich_drop[1],
      unsupported_id,
    )
  }
  let func = @ir.HotFunc::new()
  let rich_drop = flatten_test_build_rich_drop(func)
  let try_table = @ir.hot_build_try_table(func, @lib.BlockType::void_(), [], [
    @ir.hot_build_nop(func),
  ])
  flatten_test_assert_hard_unsupported_no_mutation(
    func,
    rich_drop[0],
    rich_drop[1],
    try_table,
  )
}

///|
test "flatten intentionally gates missing legacy EH repair before any mutation" {
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  let catch_func = @ir.HotFunc::new()
  let empty = flatten_eh_repair_requirement(catch_func)
  assert_true(empty.is_clear())
  @debug.assert_eq(empty.needs_catch_payload_tracking, false)
  @debug.assert_eq(empty.needs_exceptional_transfer_repair, false)
  let catch_rich = flatten_test_build_rich_drop(catch_func)
  let catch_id = @ir.hot_build_node(
    catch_func,
    @ir.HotOp::catch_(),
    @ir.hot_type_void(catch_func),
  )
  @ir.hot_root_append(catch_func, catch_rich[1])
  @ir.hot_root_append(catch_func, catch_id)
  let catch_requirement = flatten_eh_repair_requirement(catch_func)
  @debug.assert_eq(catch_requirement.needs_catch_payload_tracking, true)
  @debug.assert_eq(catch_requirement.needs_exceptional_transfer_repair, false)
  match flatten_run_admission(catch_func, flatten_classify_hot(catch_func)) {
    FlattenRunAdmission::DeferredCatchPayloadRepair => ()
    _ => fail("expected typed-catch payload repair admission gate")
  }
  @debug.assert_eq(flatten_run(ctx, catch_func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_local_count(catch_func), 0)
  @debug.assert_eq(
    @ir.hot_child_get(catch_func, catch_rich[1], 0),
    catch_rich[0],
  )

  let transfer_func = @ir.HotFunc::new()
  let transfer_rich = flatten_test_build_rich_drop(transfer_func)
  let rethrow_id = @ir.hot_build_node(
    transfer_func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(transfer_func),
  )
  @ir.hot_root_append(transfer_func, transfer_rich[1])
  @ir.hot_root_append(transfer_func, rethrow_id)
  let transfer_requirement = flatten_eh_repair_requirement(transfer_func)
  @debug.assert_eq(transfer_requirement.needs_catch_payload_tracking, false)
  @debug.assert_eq(transfer_requirement.needs_exceptional_transfer_repair, true)
  match
    flatten_run_admission(transfer_func, flatten_classify_hot(transfer_func)) {
    FlattenRunAdmission::DeferredExceptionalTransferRepair => ()
    _ => fail("expected exceptional-transfer repair admission gate")
  }
  @debug.assert_eq(flatten_run(ctx, transfer_func), HotPassResult::unchanged())
  @debug.assert_eq(@ir.hot_local_count(transfer_func), 0)
  @debug.assert_eq(
    @ir.hot_child_get(transfer_func, transfer_rich[1], 0),
    transfer_rich[0],
  )
}

///|
test "flatten repairs one scalar typed catch payload before nested block flattening" {
  let func = @ir.HotFunc::new()
  let outer = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let payload = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let payload_drop = @ir.hot_build_drop(func, payload)
  let branch = @ir.hot_build_br(func, @ir.hot_control_node_label(func, outer))
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    payload_drop, branch,
  ])
  let nested = @ir.hot_build_block(func, @lib.BlockType::void_(), [inner])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ]),
    ],
    catch_body=Some([payload, nested]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, outer), [
    try_id,
  ])
  @ir.hot_root_append(func, outer)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected scalar catch repair admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_count(func), 1)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 0), payload)
  let capture = @ir.hot_region_get(func, catch_ref, 1)
  @debug.assert_eq(@ir.hot_node_get(func, capture).op.to_string(), "LocalSet")
  @debug.assert_eq(@ir.hot_child_get(func, capture, 0), payload)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 2), nested)
  let replacement = @ir.hot_child_get(func, payload_drop, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, replacement).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(@ir.hot_node_get(func, replacement).imm0, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, branch).imm0,
    @ir.hot_control_node_label(func, outer),
  )
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected repaired flatten HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten repairs a scalar typed catch payload in a nested if condition" {
  let func = @ir.HotFunc::new()
  let payload = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    payload,
    [@ir.hot_build_nop(func)],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let nested = @ir.hot_build_block(func, @lib.BlockType::void_(), [if_id])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [
        @ir.hot_build_const_i32(func, @lib.I32(1)),
      ]),
    ],
    catch_body=Some([payload, nested]),
  )
  @ir.hot_root_append(func, try_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected nested if-condition catch repair admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_count(func), 1)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 3)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 0), payload)
  let capture = @ir.hot_region_get(func, catch_ref, 1)
  @debug.assert_eq(@ir.hot_node_get(func, capture).imm0, 0)
  @debug.assert_eq(@ir.hot_child_get(func, capture, 0), payload)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 2), nested)
  let condition = @ir.hot_child_get(func, if_id, 0)
  @debug.assert_eq(@ir.hot_node_get(func, condition).op.to_string(), "LocalGet")
  @debug.assert_eq(@ir.hot_node_get(func, condition).imm0, 0)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested if-condition catch repair to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten repairs ordered two-lane typed catch payloads before nested blocks" {
  let func = @ir.HotFunc::new()
  ignore(
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      [@lib.ValType::i32(), @lib.ValType::f32()],
    ),
  )
  let outer = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let first = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let second = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::f32(),
  )
  let first_drop = @ir.hot_build_drop(func, first)
  let second_drop = @ir.hot_build_drop(func, second)
  let branch = @ir.hot_build_br(func, @ir.hot_control_node_label(func, outer))
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    first_drop, second_drop, branch,
  ])
  let nested = @ir.hot_build_block(func, @lib.BlockType::void_(), [inner])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [
        @ir.hot_build_const_i32(func, @lib.I32(7)),
        @ir.hot_build_const_f32(func, @lib.F32(3.5)),
      ]),
    ],
    catch_body=Some([first, second, nested]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, outer), [
    try_id,
  ])
  @ir.hot_root_append(func, outer)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected ordered two-lane catch repair admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_count(func), 2)
  @debug.assert_eq(@ir.hot_local_type(func, 0), Some(@lib.ValType::i32()))
  @debug.assert_eq(@ir.hot_local_type(func, 1), Some(@lib.ValType::f32()))
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 5)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 0), first)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 1), second)
  let second_capture = @ir.hot_region_get(func, catch_ref, 2)
  let first_capture = @ir.hot_region_get(func, catch_ref, 3)
  @debug.assert_eq(@ir.hot_node_get(func, second_capture).imm0, 1)
  @debug.assert_eq(@ir.hot_child_get(func, second_capture, 0), second)
  @debug.assert_eq(@ir.hot_node_get(func, first_capture).imm0, 0)
  @debug.assert_eq(@ir.hot_child_get(func, first_capture, 0), first)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 4), nested)
  let first_get = @ir.hot_child_get(func, first_drop, 0)
  let second_get = @ir.hot_child_get(func, second_drop, 0)
  @debug.assert_eq(@ir.hot_node_get(func, first_get).imm0, 0)
  @debug.assert_eq(@ir.hot_node_get(func, second_get).imm0, 1)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected ordered repaired flatten HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::f32()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::f32()]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten repairs ordered three-lane typed catch payloads before nested blocks" {
  let func = @ir.HotFunc::new()
  ignore(
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      [@lib.ValType::i32(), @lib.ValType::f32(), @lib.ValType::i64()],
    ),
  )
  let outer = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let first = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let second = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::f32(),
  )
  let third = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i64(),
  )
  let first_drop = @ir.hot_build_drop(func, first)
  let second_drop = @ir.hot_build_drop(func, second)
  let third_drop = @ir.hot_build_drop(func, third)
  let branch = @ir.hot_build_br(func, @ir.hot_control_node_label(func, outer))
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    first_drop, second_drop, third_drop, branch,
  ])
  let nested = @ir.hot_build_block(func, @lib.BlockType::void_(), [inner])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [
        @ir.hot_build_const_i32(func, @lib.I32(7)),
        @ir.hot_build_const_f32(func, @lib.F32(3.5)),
        @ir.hot_build_const_i64(func, @lib.I64(9L)),
      ]),
    ],
    catch_body=Some([first, second, third, nested]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, outer), [
    try_id,
  ])
  @ir.hot_root_append(func, outer)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected ordered three-lane catch repair admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_count(func), 3)
  @debug.assert_eq(@ir.hot_local_type(func, 0), Some(@lib.ValType::i32()))
  @debug.assert_eq(@ir.hot_local_type(func, 1), Some(@lib.ValType::f32()))
  @debug.assert_eq(@ir.hot_local_type(func, 2), Some(@lib.ValType::i64()))
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 7)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 0), first)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 1), second)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 2), third)
  let third_capture = @ir.hot_region_get(func, catch_ref, 3)
  let second_capture = @ir.hot_region_get(func, catch_ref, 4)
  let first_capture = @ir.hot_region_get(func, catch_ref, 5)
  @debug.assert_eq(@ir.hot_node_get(func, third_capture).imm0, 2)
  @debug.assert_eq(@ir.hot_child_get(func, third_capture, 0), third)
  @debug.assert_eq(@ir.hot_node_get(func, second_capture).imm0, 1)
  @debug.assert_eq(@ir.hot_child_get(func, second_capture, 0), second)
  @debug.assert_eq(@ir.hot_node_get(func, first_capture).imm0, 0)
  @debug.assert_eq(@ir.hot_child_get(func, first_capture, 0), first)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 6), nested)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, first_drop, 0)).imm0,
    0,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, second_drop, 0)).imm0,
    1,
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, third_drop, 0)).imm0,
    2,
  )
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected ordered three-lane repaired flatten HOT to verify, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::f32(), @lib.ValType::i64()],
              [],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [
              @lib.ValType::i32(),
              @lib.ValType::f32(),
              @lib.ValType::i64(),
            ]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten repairs ordered catch payloads through first-child binary paths" {
  let func = @ir.HotFunc::new()
  ignore(
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      [@lib.ValType::i32(), @lib.ValType::i32()],
    ),
  )
  let outer = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let first = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let second = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let first_right = @ir.hot_build_const_i32(func, @lib.I32(3))
  let first_add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    first,
    first_right,
  )
  @ir.hot_node_exact_instr_set(func, first_add, @lib.Instruction::i32_add())
  let second_right = @ir.hot_build_const_i32(func, @lib.I32(4))
  let second_add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    second,
    second_right,
  )
  @ir.hot_node_exact_instr_set(func, second_add, @lib.Instruction::i32_add())
  let first_drop = @ir.hot_build_drop(func, first_add)
  let second_drop = @ir.hot_build_drop(func, second_add)
  let branch = @ir.hot_build_br(func, @ir.hot_control_node_label(func, outer))
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    first_drop, second_drop, branch,
  ])
  let nested = @ir.hot_build_block(func, @lib.BlockType::void_(), [inner])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [
        @ir.hot_build_const_i32(func, @lib.I32(7)),
        @ir.hot_build_const_i32(func, @lib.I32(8)),
      ]),
    ],
    catch_body=Some([first, second, nested]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, outer), [
    try_id,
  ])
  @ir.hot_root_append(func, outer)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected ordered first-child binary catch repair admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_count(func), 4)
  @debug.assert_eq(@ir.hot_local_type(func, 0), Some(@lib.ValType::i32()))
  @debug.assert_eq(@ir.hot_local_type(func, 1), Some(@lib.ValType::i32()))
  let first_get = @ir.hot_child_get(func, first_add, 0)
  let second_get = @ir.hot_child_get(func, second_add, 0)
  @debug.assert_eq(@ir.hot_node_get(func, first_get).op.to_string(), "LocalGet")
  @debug.assert_eq(@ir.hot_node_get(func, first_get).imm0, 0)
  @debug.assert_eq(@ir.hot_child_get(func, first_add, 1), first_right)
  @debug.assert_eq(
    @ir.hot_node_get(func, second_get).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(@ir.hot_node_get(func, second_get).imm0, 1)
  @debug.assert_eq(@ir.hot_child_get(func, second_add, 1), second_right)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected first-child binary catch repair to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten repairs ordered catch payloads across independent direct roots" {
  let func = @ir.HotFunc::new()
  ignore(
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      [@lib.ValType::i32(), @lib.ValType::i32()],
    ),
  )
  let first = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let second = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let first_right = @ir.hot_build_const_i32(func, @lib.I32(3))
  let first_add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    first,
    first_right,
  )
  @ir.hot_node_exact_instr_set(func, first_add, @lib.Instruction::i32_add())
  let first_drop = @ir.hot_build_drop(func, first_add)
  let second_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    second,
    [@ir.hot_build_nop(func)],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let later_root = @ir.hot_build_nop(func)
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [
        @ir.hot_build_const_i32(func, @lib.I32(7)),
        @ir.hot_build_const_i32(func, @lib.I32(8)),
      ]),
    ],
    catch_body=Some([first, second, first_drop, second_if, later_root]),
  )
  @ir.hot_root_append(func, try_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected independent direct-root catch repair admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_type(func, 0), Some(@lib.ValType::i32()))
  @debug.assert_eq(@ir.hot_local_type(func, 1), Some(@lib.ValType::i32()))
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 8)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 0), first)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 1), second)
  let second_capture = @ir.hot_region_get(func, catch_ref, 2)
  let first_capture = @ir.hot_region_get(func, catch_ref, 3)
  @debug.assert_eq(@ir.hot_node_get(func, second_capture).imm0, 1)
  @debug.assert_eq(@ir.hot_child_get(func, second_capture, 0), second)
  @debug.assert_eq(@ir.hot_node_get(func, first_capture).imm0, 0)
  @debug.assert_eq(@ir.hot_child_get(func, first_capture, 0), first)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, 4)).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 5), first_drop)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 6), second_if)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 7), later_root)
  let first_get = @ir.hot_child_get(func, first_add, 0)
  @debug.assert_eq(@ir.hot_node_get(func, first_get).op.to_string(), "LocalGet")
  @debug.assert_eq(@ir.hot_node_get(func, first_get).imm0, 0)
  @debug.assert_eq(@ir.hot_child_get(func, first_add, 1), first_right)
  let second_get = @ir.hot_child_get(func, second_if, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, second_get).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(@ir.hot_node_get(func, second_get).imm0, 1)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected direct-root catch repair to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten repairs ordered catch payloads across interleaved direct roots" {
  let func = @ir.HotFunc::new()
  ignore(
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [],
      [@lib.ValType::i32(), @lib.ValType::i32()],
    ),
  )
  let first = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let second = @ir.hot_build_catch_payload(
    func,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let first_right = @ir.hot_build_const_i32(func, @lib.I32(3))
  let first_add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    first,
    first_right,
  )
  @ir.hot_node_exact_instr_set(func, first_add, @lib.Instruction::i32_add())
  let first_drop = @ir.hot_build_drop(func, first_add)
  let gap_root = @ir.hot_build_nop(func)
  let second_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    second,
    [@ir.hot_build_nop(func)],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let later_root = @ir.hot_build_nop(func)
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [
        @ir.hot_build_const_i32(func, @lib.I32(7)),
        @ir.hot_build_const_i32(func, @lib.I32(8)),
      ]),
    ],
    catch_body=Some([first, second, first_drop, gap_root, second_if, later_root]),
  )
  @ir.hot_root_append(func, try_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    FlattenRunAdmission::DeferredCatchPayloadRepair =>
      fail("interleaved direct-root catch payloads remained deferred")
    _ => fail("interleaved direct-root catch payloads failed an unrelated gate")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_local_type(func, 0), Some(@lib.ValType::i32()))
  @debug.assert_eq(@ir.hot_local_type(func, 1), Some(@lib.ValType::i32()))
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, catch_ref), 9)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 0), first)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 1), second)
  let second_capture = @ir.hot_region_get(func, catch_ref, 2)
  let first_capture = @ir.hot_region_get(func, catch_ref, 3)
  @debug.assert_eq(@ir.hot_node_get(func, second_capture).imm0, 1)
  @debug.assert_eq(@ir.hot_child_get(func, second_capture, 0), second)
  @debug.assert_eq(@ir.hot_node_get(func, first_capture).imm0, 0)
  @debug.assert_eq(@ir.hot_child_get(func, first_capture, 0), first)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 5), first_drop)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 6), gap_root)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 7), second_if)
  @debug.assert_eq(@ir.hot_region_get(func, catch_ref, 8), later_root)
  let first_get = @ir.hot_child_get(func, first_add, 0)
  @debug.assert_eq(@ir.hot_node_get(func, first_get).op.to_string(), "LocalGet")
  @debug.assert_eq(@ir.hot_node_get(func, first_get).imm0, 0)
  @debug.assert_eq(@ir.hot_child_get(func, first_add, 1), first_right)
  let second_get = @ir.hot_child_get(func, second_if, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, second_get).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(@ir.hot_node_get(func, second_get).imm0, 1)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected interleaved direct-root catch repair to verify, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves direct catch-all rethrow through nested block lowering" {
  let func = @ir.HotFunc::new()
  let rich_drop = flatten_test_build_rich_drop(func)
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=0,
  )
  let nested = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    rich_drop[1],
    rethrow_id,
  ])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([nested]),
  )
  @ir.hot_root_append(func, try_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected direct catch-all rethrow admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, rethrow_id).imm0, 0)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected rethrow flatten HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("catch_all_ref"), msg=pretty)
  assert_true(pretty.contains("throw_ref"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves multiple direct catch-all rethrows with one captured exception" {
  let func = @ir.HotFunc::new()
  let first_rich_drop = flatten_test_build_rich_drop(func)
  let first_rethrow = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=0,
  )
  let first_nested = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    first_rich_drop[1],
    first_rethrow,
  ])
  let second_rich_drop = flatten_test_build_rich_drop(func)
  let second_rethrow = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=0,
  )
  let second_nested = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    second_rich_drop[1],
    second_rethrow,
  ])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([first_nested, second_nested]),
  )
  @ir.hot_root_append(func, try_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected multiple direct catch-all rethrow admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, first_rethrow).imm0, 0)
  @debug.assert_eq(@ir.hot_node_get(func, second_rethrow).imm0, 0)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected multiple rethrow flatten HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("catch_all_ref"), msg=pretty)
  let mut throw_ref_parts = 0
  for _ in pretty.split("throw_ref") {
    throw_ref_parts += 1
  }
  @debug.assert_eq(throw_ref_parts, 3)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a catch-all rethrow through one nested if arm" {
  let func = @ir.HotFunc::new()
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=0,
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [rethrow_id],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let rich_drop = flatten_test_build_rich_drop(func)
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([rich_drop[1], if_id]),
  )
  @ir.hot_root_append(func, try_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected nested-if catch-all rethrow admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, rethrow_id).imm0, 0)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested-if rethrow flatten HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("catch_all_ref"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("throw_ref"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a catch-all rethrow through a strict nested if chain" {
  let func = @ir.HotFunc::new()
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=0,
  )
  let inner_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    rethrow_id,
  ])
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [inner_block],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let middle_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_if,
  ])
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [middle_block],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let rich_drop = flatten_test_build_rich_drop(func)
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([rich_drop[1], outer_if]),
  )
  @ir.hot_root_append(func, try_id)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected strict nested-if-chain catch-all rethrow admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, rethrow_id).imm0, 0)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested-if-chain rethrow flatten HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("catch_all_ref"), msg=pretty)
  let mut if_parts = 0
  for _ in pretty.split("if") {
    if_parts += 1
  }
  assert_true(if_parts >= 3, msg=pretty)
  assert_true(pretty.contains("throw_ref"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a direct rethrow through a value-carrying if arm" {
  let func = @ir.HotFunc::new()
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=0,
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [rethrow_id],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(7))]),
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_call(func, 0, [@lib.ValType::i32()], [])],
    catch_body=Some([if_id]),
  )
  let result_drop = @ir.hot_build_drop(func, try_id)
  @ir.hot_root_append(func, result_drop)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    FlattenRunAdmission::UpstreamHardUnsupported =>
      fail("value-carrying-if rethrow was classified hard unsupported")
    FlattenRunAdmission::DeferredCatchPayloadRepair =>
      fail("value-carrying-if rethrow was deferred for catch payload repair")
    FlattenRunAdmission::DeferredExceptionalTransferRepair =>
      fail("value-carrying-if rethrow was deferred for exceptional transfer")
    FlattenRunAdmission::DeferredInputfulLoop =>
      fail("value-carrying-if rethrow was deferred for an inputful loop")
    FlattenRunAdmission::DeferredLegacyTry =>
      fail("value-carrying-if rethrow was deferred for legacy try routing")
    FlattenRunAdmission::DeferredBranchPayload =>
      fail("value-carrying-if rethrow was deferred for branch payload routing")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 0)
  @debug.assert_eq(@ir.hot_node_result_arity(func, try_id), 0)
  @debug.assert_eq(@ir.hot_node_get(func, rethrow_id).imm0, 0)
  let result_get = @ir.hot_child_get(func, result_drop, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, result_get).op.to_string(),
    "LocalGet",
  )
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected value-carrying-if rethrow flatten HOT to verify, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let callee = @lib.Func::new(
    @lib.Locals::from_types([]),
    @lib.Expr::new([@lib.Instruction::i32_const(7)]),
  )
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(1U), @lib.TypeIdx::new(0U)]),
    )
    .with_code_sec(@lib.CodeSec::new([callee, lowered]))
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a depth-two rethrow through direct nested catches" {
  let func = @ir.HotFunc::new()
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=2,
    children=[],
  )
  let inner_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(2U), [])],
    catch_body=Some([rethrow_id]),
  )
  let middle_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(1U), [])],
    catch_body=Some([inner_try]),
  )
  let rich_drop = flatten_test_build_rich_drop(func)
  let outer_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([rich_drop[1], middle_try]),
  )
  @ir.hot_root_append(func, outer_try)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    FlattenRunAdmission::DeferredExceptionalTransferRepair =>
      fail("depth-two rethrow remained deferred for exceptional transfer")
    _ => fail("depth-two rethrow failed an unrelated flatten admission gate")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, rethrow_id).imm0, 2)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected depth-two rethrow HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(
      @lib.TagSec::new([
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("catch_all_ref"), msg=pretty)
  assert_true(pretty.contains("throw_ref"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a depth-one rethrow through strict catch block wrappers" {
  let func = @ir.HotFunc::new()
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=1,
    children=[],
  )
  let inner_catch_root = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    rethrow_id,
  ])
  let inner_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(1U), [])],
    catch_body=Some([inner_catch_root]),
  )
  let outer_catch_root = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_try,
  ])
  let rich_drop = flatten_test_build_rich_drop(func)
  let outer_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([rich_drop[1], outer_catch_root]),
  )
  @ir.hot_root_append(func, outer_try)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    FlattenRunAdmission::DeferredExceptionalTransferRepair =>
      fail(
        "wrapped depth-one rethrow remained deferred for exceptional transfer",
      )
    _ => fail("wrapped depth-one rethrow failed an unrelated admission gate")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, rethrow_id).imm0, 1)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected wrapped depth-one rethrow HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(
      @lib.TagSec::new([
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("catch_all_ref"), msg=pretty)
  assert_true(pretty.contains("throw_ref"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a depth-one rethrow through mixed catch control wrappers" {
  let func = @ir.HotFunc::new()
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=1,
    children=[],
  )
  let inner_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    rethrow_id,
  ])
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [inner_block],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let inner_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(1U), [])],
    catch_body=Some([inner_if]),
  )
  let outer_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_try,
  ])
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [@ir.hot_build_nop(func)],
    else_body=Some([outer_block]),
  )
  let rich_drop = flatten_test_build_rich_drop(func)
  let outer_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([rich_drop[1], outer_if]),
  )
  @ir.hot_root_append(func, outer_try)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    FlattenRunAdmission::DeferredExceptionalTransferRepair =>
      fail("mixed-wrapper depth-one rethrow remained deferred")
    _ => fail("mixed-wrapper depth-one rethrow failed an unrelated gate")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, rethrow_id).imm0, 1)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected mixed-wrapper depth-one rethrow HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(
      @lib.TagSec::new([
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("catch_all_ref"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("throw_ref"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a depth-one rethrow through a plain-targeted catch if wrapper" {
  let func = @ir.HotFunc::new()
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=1,
    children=[],
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [rethrow_id],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let if_label = @ir.hot_control_node_label(func, if_id)
  let opposite_exit = @ir.hot_build_br(func, if_label)
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_else_ref(func, if_id).unwrap(),
    [opposite_exit],
  )
  let inner_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(1U), [])],
    catch_body=Some([if_id]),
  )
  let rich_drop = flatten_test_build_rich_drop(func)
  let outer_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([rich_drop[1], inner_try]),
  )
  @ir.hot_root_append(func, outer_try)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    FlattenRunAdmission::DeferredExceptionalTransferRepair =>
      fail("plain-targeted catch-if rethrow remained deferred")
    _ => fail("plain-targeted catch-if rethrow failed an unrelated gate")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, rethrow_id).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, opposite_exit).op.to_string(), "Br")
  @debug.assert_eq(@ir.hot_node_get(func, opposite_exit).imm0, if_label)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected plain-targeted catch-if rethrow HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(
      @lib.TagSec::new([
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("catch_all_ref"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("throw_ref"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a depth-one rethrow through a conditional-targeted catch if wrapper" {
  let func = @ir.HotFunc::new()
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=1,
    children=[],
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [@ir.hot_build_nop(func)],
    else_body=Some([rethrow_id]),
  )
  let if_label = @ir.hot_control_node_label(func, if_id)
  let exit_condition = @ir.hot_build_const_i32(func, @lib.I32(0))
  let opposite_exit = @ir.hot_build_br_if(func, if_label, exit_condition)
  @ir.hot_region_replace_body(func, @ir.hot_region_then_ref(func, if_id), [
    opposite_exit,
  ])
  let inner_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(1U), [])],
    catch_body=Some([if_id]),
  )
  let rich_drop = flatten_test_build_rich_drop(func)
  let outer_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([rich_drop[1], inner_try]),
  )
  @ir.hot_root_append(func, outer_try)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    FlattenRunAdmission::DeferredExceptionalTransferRepair =>
      fail("conditional-targeted catch-if rethrow remained deferred")
    _ => fail("conditional-targeted catch-if rethrow failed an unrelated gate")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, rethrow_id).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, opposite_exit).op.to_string(), "BrIf")
  @debug.assert_eq(@ir.hot_node_get(func, opposite_exit).imm0, if_label)
  @debug.assert_eq(@ir.hot_child_get(func, opposite_exit, 0), exit_condition)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected conditional-targeted catch-if rethrow HOT to verify, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(
      @lib.TagSec::new([
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("catch_all_ref"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("throw_ref"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a depth-one rethrow through a rich-conditional targeted catch if wrapper" {
  let func = @ir.HotFunc::new()
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
    imm0=1,
    children=[],
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [@ir.hot_build_nop(func)],
    else_body=Some([rethrow_id]),
  )
  let if_label = @ir.hot_control_node_label(func, if_id)
  let exit_condition = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_const_i32(func, @lib.I32(2)),
    @ir.hot_build_const_i32(func, @lib.I32(3)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    exit_condition,
    @lib.Instruction::i32_add(),
  )
  let opposite_exit = @ir.hot_build_br_if(func, if_label, exit_condition)
  @ir.hot_region_replace_body(func, @ir.hot_region_then_ref(func, if_id), [
    opposite_exit,
  ])
  let inner_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(1U), [])],
    catch_body=Some([if_id]),
  )
  let outer_try = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([inner_try]),
  )
  @ir.hot_root_append(func, outer_try)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    FlattenRunAdmission::DeferredExceptionalTransferRepair =>
      fail("rich-conditional targeted catch-if rethrow remained deferred")
    _ =>
      fail(
        "rich-conditional targeted catch-if rethrow failed an unrelated gate",
      )
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, rethrow_id).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, opposite_exit).op.to_string(), "BrIf")
  @debug.assert_eq(@ir.hot_node_get(func, opposite_exit).imm0, if_label)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  let condition_set = @ir.hot_region_get(func, then_ref, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, condition_set).op.to_string(),
    "LocalSet",
  )
  @debug.assert_eq(@ir.hot_child_get(func, condition_set, 0), exit_condition)
  @debug.assert_eq(@ir.hot_region_get(func, then_ref, 1), opposite_exit)
  let condition_get = @ir.hot_child_get(func, opposite_exit, 0)
  @debug.assert_eq(
    @ir.hot_node_get(func, condition_get).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(
    @ir.hot_node_get(func, condition_get).imm0,
    @ir.hot_node_get(func, condition_set).imm0,
  )
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected rich-conditional targeted catch-if rethrow HOT to verify, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(
      @lib.TagSec::new([
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("catch_all_ref"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("throw_ref"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves direct delegate target through nested block lowering" {
  let func = @ir.HotFunc::new()
  let outer = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let target = @ir.hot_control_node_label(func, outer)
  let delegate_id = @ir.hot_build_delegate(func, target)
  let rich_drop = flatten_test_build_rich_drop(func)
  let inner = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [rich_drop[1], @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([delegate_id]),
  )
  let nested = @ir.hot_build_block(func, @lib.BlockType::void_(), [inner])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, outer), [
    nested,
  ])
  @ir.hot_root_append(func, outer)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected direct delegate admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, delegate_id).imm0, target)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected delegate flatten HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("catch_all"), msg=pretty)
  assert_true(pretty.contains("throw"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a delegate through a strict catch block chain" {
  let func = @ir.HotFunc::new()
  let outer = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let target = @ir.hot_control_node_label(func, outer)
  let delegate_id = @ir.hot_build_delegate(func, target)
  let inner_catch_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    delegate_id,
  ])
  let outer_catch_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    inner_catch_block,
  ])
  let rich_drop = flatten_test_build_rich_drop(func)
  let inner = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [rich_drop[1], @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([outer_catch_block]),
  )
  let nested = @ir.hot_build_block(func, @lib.BlockType::void_(), [inner])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, outer), [
    nested,
  ])
  @ir.hot_root_append(func, outer)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected strict catch-block-chain delegate admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, delegate_id).imm0, target)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected catch-block-chain delegate flatten HOT to verify, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("catch_all"), msg=pretty)
  assert_true(pretty.contains("throw"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten preserves a delegate through strict outer block and if ancestry" {
  let func = @ir.HotFunc::new()
  let outer = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let target = @ir.hot_control_node_label(func, outer)
  let delegate_id = @ir.hot_build_delegate(func, target)
  let catch_inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    delegate_id,
  ])
  let catch_outer = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    catch_inner,
  ])
  let rich_drop = flatten_test_build_rich_drop(func)
  let inner = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [rich_drop[1], @ir.hot_build_throw(func, @lib.TagIdx::new(0U), [])],
    catch_body=Some([catch_outer]),
  )
  let body_inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [inner])
  let body_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [body_inner],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let body_outer = @ir.hot_build_block(func, @lib.BlockType::void_(), [body_if])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, outer), [
    body_outer,
  ])
  @ir.hot_root_append(func, outer)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected strict outer block/if delegate admission")
  }
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::changed())
  @debug.assert_eq(@ir.hot_node_get(func, delegate_id).imm0, target)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected outer-chain delegate flatten HOT to verify, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  let pretty = module_.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("catch_all"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("throw"), msg=pretty)
  match @validate.validate_module(module_) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "flatten extracts direct try target ancestry in structural order" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [try_id])
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [block_id],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(func, try_id, [if_id, block_id]),
    Some([block_id, if_id]),
  )
}

///|
test "flatten rejects skipped direct try target ancestry" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let skipped_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    try_id,
  ])
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [skipped_block],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(func, try_id, [outer_if]),
    None,
  )
}

///|
test "flatten extracts reverse if-inside-block target ancestry in structural order" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [try_id],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [if_id])
  let chain = flatten_direct_enclosing_target_controls(func, try_id, [
    block_id, if_id,
  ])
  @debug.assert_eq(chain, Some([if_id, block_id]))
}

///|
test "flatten extracts a direct enclosing loop from try target ancestry" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let loop_id = @ir.hot_build_loop(func, @lib.BlockType::void_(), [try_id])
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(func, try_id, [loop_id]),
    Some([loop_id]),
  )
}

///|
test "flatten rejects a skipped enclosing loop from try target ancestry" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let loop_id = @ir.hot_build_loop(func, @lib.BlockType::void_(), [try_id])
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [loop_id])
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(func, try_id, [block_id]),
    None,
  )
}

///|
test "flatten rejects non-root try containment from direct target ancestry" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let drop_id = @ir.hot_build_drop(func, try_id)
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [drop_id])
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(func, try_id, [block_id]),
    None,
  )
}

///|
test "flatten admits exclusively tuple-made try-to-loop table preflight" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) call 1 call 2 loop $loop (type $carrier) drop drop i32.const 11 i64.const 12 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2))",
  )
  let mut loop_id = -1
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Loop => loop_id = node_id
      _ => ()
    }
  }
  assert_true(loop_id >= 0)
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(13)),
      @ir.hot_build_const_i64(func, @lib.I64(14L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_results(func, result_types),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i64(func, @lib.I64(9L)),
  ])
  let try_label = @ir.hot_control_node_label(func, try_id)
  let loop_label = @ir.hot_control_node_label(func, loop_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [try_label, loop_label],
    try_label,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[tuple_id, tuple_id],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
  ])
  let loop_ref = @ir.hot_region_body_ref(func, loop_id)
  let root_count = @ir.hot_region_root_count(func, loop_ref)
  ignore(@ir.hot_region_set(func, loop_ref, root_count - 2, try_id))
  ignore(@ir.hot_region_set(func, loop_ref, root_count - 1, try_id))
  assert_true(flatten_multivalue_legacy_try_is_supported(func, try_id))
  assert_true(flatten_inputful_loop_is_supported(func, loop_id))
  assert_true(
    flatten_tuple_mixed_try_table_is_supported(
      func,
      table_id,
      result_types,
      flatten_br_table_targets(func, @ir.hot_node_get(func, table_id).imm0).unwrap(),
    ),
  )
  match flatten_run_admission(func, flatten_classify_hot(func)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected tuple try-to-loop table admission")
  }
}

///|
test "flatten admits only unreachable roots after a legacy try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    @ir.hot_build_unreachable(func),
    @ir.hot_build_unreachable(func),
  ])
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned pure drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, dead_value)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  let use_def = @ir.use_def_build_node_uses(func)
  @debug.assert_eq(@ir.node_use_count(use_def, dead_drop), 1)
  @debug.assert_eq(@ir.node_use_count(use_def, dead_value), 1)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, dead_value]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes exactly two exclusively owned direct drop-const try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_drop = @ir.hot_build_drop(func, first_value)
  let second_value = @ir.hot_build_const_i32(func, @lib.I32(10))
  let second_drop = @ir.hot_build_drop(func, second_value)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id, first_drop, second_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([first_drop, first_value, second_drop, second_value]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps two drop-const suffix roots gated when their child is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_drop = @ir.hot_build_drop(func, shared_value)
  let second_drop = @ir.hot_build_drop(func, shared_value)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, first_drop, second_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a repeated drop-const suffix root gated" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let repeated_drop = @ir.hot_build_drop(
    func,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, repeated_drop, repeated_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes three exclusively owned direct drop-const try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_drop = @ir.hot_build_drop(func, first_value)
  let second_value = @ir.hot_build_const_i32(func, @lib.I32(10))
  let second_drop = @ir.hot_build_drop(func, second_value)
  let third_value = @ir.hot_build_const_i32(func, @lib.I32(11))
  let third_drop = @ir.hot_build_drop(func, third_value)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id, first_drop, second_drop, third_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first_drop, first_value, second_drop, second_value, third_drop, third_value,
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one direct drop-const then unreachable try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, dead_value)
  let dead_unreachable = @ir.hot_build_unreachable(func)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id, dead_drop, dead_unreachable,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, dead_value, dead_unreachable]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one direct unreachable then drop-const try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_unreachable = @ir.hot_build_unreachable(func)
  let dead_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, dead_value)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id, dead_unreachable, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_unreachable, dead_drop, dead_value]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one direct add-drop then unreachable try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let add_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let add = @ir.hot_build_binary(func, i32_type, add_left, add_right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let dead_unreachable = @ir.hot_build_unreachable(func)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id, dead_drop, dead_unreachable,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, add, add_left, add_right, dead_unreachable]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one direct unreachable then add-drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_unreachable = @ir.hot_build_unreachable(func)
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let add_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let add = @ir.hot_build_binary(func, i32_type, add_left, add_right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id, dead_unreachable, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_unreachable, dead_drop, add, add_left, add_right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes add-drop followed by two unreachable try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
    @ir.hot_build_unreachable(func),
    @ir.hot_build_unreachable(func),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes unreachable add-drop unreachable try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_unreachable(func),
    @ir.hot_build_drop(func, add),
    @ir.hot_build_unreachable(func),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes three-root mixed drop-const unreachable try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(9))),
    @ir.hot_build_unreachable(func),
    @ir.hot_build_unreachable(func),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes exactly two independently owned add-drop try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let first_add = @ir.hot_build_binary(func, i32_type, first_left, first_right)
  @ir.hot_node_exact_instr_set(func, first_add, @lib.Instruction::i32_add())
  let first_drop = @ir.hot_build_drop(func, first_add)
  let second_left = @ir.hot_build_const_i32(func, @lib.I32(11))
  let second_right = @ir.hot_build_const_i32(func, @lib.I32(12))
  let second_add = @ir.hot_build_binary(
    func, i32_type, second_left, second_right,
  )
  @ir.hot_node_exact_instr_set(func, second_add, @lib.Instruction::i32_add())
  let second_drop = @ir.hot_build_drop(func, second_add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id, first_drop, second_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first_drop, first_add, first_left, first_right, second_drop, second_add, second_left,
      second_right,
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps two add-drop suffix roots unsupported when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_add = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, first_add, @lib.Instruction::i32_add())
  let second_add = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, second_add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, first_add),
    @ir.hot_build_drop(func, second_add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a repeated add-drop suffix root unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let repeated_drop = @ir.hot_build_drop(func, add)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, repeated_drop, repeated_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes three independently owned add-drop try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let second = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  let third = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    13,
    14,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    first[0],
    second[0],
    third[0],
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first[0],
      first[1],
      first[2],
      first[3],
      second[0],
      second[1],
      second[2],
      second[3],
      third[0],
      third[1],
      third[2],
      third[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes exactly two independently owned multiply-drop try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let first_multiply = @ir.hot_build_binary(
    func, i32_type, first_left, first_right,
  )
  @ir.hot_node_exact_instr_set(
    func,
    first_multiply,
    @lib.Instruction::i32_mul(),
  )
  let first_drop = @ir.hot_build_drop(func, first_multiply)
  let second_left = @ir.hot_build_const_i32(func, @lib.I32(11))
  let second_right = @ir.hot_build_const_i32(func, @lib.I32(12))
  let second_multiply = @ir.hot_build_binary(
    func, i32_type, second_left, second_right,
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_multiply,
    @lib.Instruction::i32_mul(),
  )
  let second_drop = @ir.hot_build_drop(func, second_multiply)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id, first_drop, second_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first_drop, first_multiply, first_left, first_right, second_drop, second_multiply,
      second_left, second_right,
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps two multiply-drop suffix roots unsupported when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let first_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    first_multiply,
    @lib.Instruction::i32_mul(),
  )
  let second_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    second_multiply,
    @lib.Instruction::i32_mul(),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, first_multiply),
    @ir.hot_build_drop(func, second_multiply),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a repeated multiply-drop suffix root unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let multiply = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let repeated_drop = @ir.hot_build_drop(func, multiply)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, repeated_drop, repeated_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes three independently owned multiply-drop try-table suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let second = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    11,
    12,
  )
  let third = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    13,
    14,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    first[0],
    second[0],
    third[0],
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first[0],
      first[1],
      first[2],
      first[3],
      second[0],
      second[1],
      second[2],
      second[3],
      third[0],
      third[1],
      third[2],
      third[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned scalar-argument void call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_arg = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_call = @ir.hot_build_call(func, 99, [], [dead_arg])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_call])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_call, dead_arg]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned add-argument void call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let argument = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_add())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_call])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_call, argument, left, right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps an add-argument call suffix gated when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let argument = @ir.hot_build_binary(func, i32_type, shared_left, right)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_add())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_left))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes a three-constant-argument call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let first_arg = @ir.hot_build_const_i32(func, @lib.I32(9))
  let second_arg = @ir.hot_build_const_i32(func, @lib.I32(10))
  let third_arg = @ir.hot_build_const_i32(func, @lib.I32(11))
  let dead_call = @ir.hot_build_call(func, 99, [], [
    first_arg, second_arg, third_arg,
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a scalar-argument call try-table suffix gated when its argument is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_arg = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_call = @ir.hot_build_call(func, 99, [], [shared_arg])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_arg))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a result-carrying call try-table suffix gated" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_call = @ir.hot_build_call(func, 99, [i32_type], [])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned nested add-multiply drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply_left = @ir.hot_build_const_i32(func, @lib.I32(10))
  let multiply_right = @ir.hot_build_const_i32(func, @lib.I32(11))
  let multiply = @ir.hot_build_binary(
    func, i32_type, multiply_left, multiply_right,
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(func, i32_type, add_left, multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, add, add_left, multiply, multiply_left, multiply_right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a nested add-multiply try-table suffix unsupported when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let shared = @ir.hot_build_const_i32(func, @lib.I32(10))
  let multiply_right = @ir.hot_build_const_i32(func, @lib.I32(11))
  let multiply = @ir.hot_build_binary(func, i32_type, shared, multiply_right)
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(func, i32_type, add_left, multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps repeated nested add-multiply descendants unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let add_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let repeated = @ir.hot_build_const_i32(func, @lib.I32(10))
  let multiply = @ir.hot_build_binary(func, i32_type, repeated, repeated)
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(func, i32_type, add_left, multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned nested multiply-add drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let multiply_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let multiply = @ir.hot_build_binary(
    func, i32_type, multiply_left, multiply_right,
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add_right = @ir.hot_build_const_i32(func, @lib.I32(11))
  let add = @ir.hot_build_binary(func, i32_type, multiply, add_right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, add, multiply, add_right, multiply_left, multiply_right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a nested multiply-add try-table suffix unsupported when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(
    func,
    i32_type,
    multiply,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps repeated nested multiply-add descendants unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let repeated = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = @ir.hot_build_binary(func, i32_type, repeated, repeated)
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(
    func,
    i32_type,
    multiply,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned add-of-two-multiplies drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let left_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let left_multiply = @ir.hot_build_binary(
    func, i32_type, left_left, left_right,
  )
  @ir.hot_node_exact_instr_set(func, left_multiply, @lib.Instruction::i32_mul())
  let right_left = @ir.hot_build_const_i32(func, @lib.I32(11))
  let right_right = @ir.hot_build_const_i32(func, @lib.I32(12))
  let right_multiply = @ir.hot_build_binary(
    func, i32_type, right_left, right_right,
  )
  @ir.hot_node_exact_instr_set(
    func,
    right_multiply,
    @lib.Instruction::i32_mul(),
  )
  let add = @ir.hot_build_binary(func, i32_type, left_multiply, right_multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      dead_drop, add, left_multiply, right_multiply, left_left, left_right, right_left,
      right_right,
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps an add-of-two-multiplies suffix unsupported when the multiply trees share a descendant" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let left_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, left_multiply, @lib.Instruction::i32_mul())
  let right_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    right_multiply,
    @lib.Instruction::i32_mul(),
  )
  let add = @ir.hot_build_binary(func, i32_type, left_multiply, right_multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps repeated descendants inside an add-of-two-multiplies suffix unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let repeated = @ir.hot_build_const_i32(func, @lib.I32(9))
  let left_multiply = @ir.hot_build_binary(func, i32_type, repeated, repeated)
  @ir.hot_node_exact_instr_set(func, left_multiply, @lib.Instruction::i32_mul())
  let right_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    right_multiply,
    @lib.Instruction::i32_mul(),
  )
  let add = @ir.hot_build_binary(func, i32_type, left_multiply, right_multiply)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes two add-of-two-multiplies suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let drops : Array[Int] = []
  for base in [9, 13] {
    let left_multiply = @ir.hot_build_binary(
      func,
      i32_type,
      @ir.hot_build_const_i32(func, @lib.I32(base)),
      @ir.hot_build_const_i32(func, @lib.I32(base + 1)),
    )
    @ir.hot_node_exact_instr_set(
      func,
      left_multiply,
      @lib.Instruction::i32_mul(),
    )
    let right_multiply = @ir.hot_build_binary(
      func,
      i32_type,
      @ir.hot_build_const_i32(func, @lib.I32(base + 2)),
      @ir.hot_build_const_i32(func, @lib.I32(base + 3)),
    )
    @ir.hot_node_exact_instr_set(
      func,
      right_multiply,
      @lib.Instruction::i32_mul(),
    )
    let add = @ir.hot_build_binary(
      func, i32_type, left_multiply, right_multiply,
    )
    @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
    drops.push(@ir.hot_build_drop(func, add))
  }
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    drops[0],
    drops[1],
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned subtract-const-multiply drop try-table suffix" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let outer_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    10,
    11,
  )
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    outer_left,
    multiply[0],
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  let dead_drop = @ir.hot_build_drop(func, subtract)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      dead_drop,
      subtract,
      outer_left,
      multiply[0],
      multiply[1],
      multiply[2],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps subtract-const-multiply suffix unsupported when a descendant is shared" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    multiply,
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned subtract-multiply-const drop try-table suffix" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let multiply = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let outer_right = @ir.hot_build_const_i32(func, @lib.I32(11))
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    multiply[0],
    outer_right,
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  let dead_drop = @ir.hot_build_drop(func, subtract)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      dead_drop,
      subtract,
      multiply[0],
      outer_right,
      multiply[1],
      multiply[2],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps subtract-multiply-const suffix unsupported when a descendant is shared" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    multiply,
    shared,
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps subtract-add-const suffix unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    add[0],
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes two subtract-multiply-const suffix roots" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let drops : Array[Int] = []
  for base in [9, 12] {
    let multiply = flatten_test_build_direct_binary(
      func,
      @lib.Instruction::i32_mul(),
      base,
      base + 1,
    )
    let subtract = @ir.hot_build_binary(
      func,
      @lib.ValType::i32(),
      multiply[0],
      @ir.hot_build_const_i32(func, @lib.I32(base + 2)),
    )
    @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
    drops.push(@ir.hot_build_drop(func, subtract))
  }
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    drops[0],
    drops[1],
  ])
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps subtract-const-add suffix unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let outer_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let add = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    10,
    11,
  )
  let subtract = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    outer_left,
    add[0],
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes two subtract-const-multiply suffix roots" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let drops : Array[Int] = []
  for base in [9, 12] {
    let multiply = flatten_test_build_direct_binary(
      func,
      @lib.Instruction::i32_mul(),
      base + 1,
      base + 2,
    )
    let subtract = @ir.hot_build_binary(
      func,
      @lib.ValType::i32(),
      @ir.hot_build_const_i32(func, @lib.I32(base)),
      multiply[0],
    )
    @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
    drops.push(@ir.hot_build_drop(func, subtract))
  }
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    drops[0],
    drops[1],
  ])
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned subtract-of-two-multiplies drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let left_right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let left_multiply = @ir.hot_build_binary(
    func, i32_type, left_left, left_right,
  )
  @ir.hot_node_exact_instr_set(func, left_multiply, @lib.Instruction::i32_mul())
  let right_left = @ir.hot_build_const_i32(func, @lib.I32(11))
  let right_right = @ir.hot_build_const_i32(func, @lib.I32(12))
  let right_multiply = @ir.hot_build_binary(
    func, i32_type, right_left, right_right,
  )
  @ir.hot_node_exact_instr_set(
    func,
    right_multiply,
    @lib.Instruction::i32_mul(),
  )
  let subtract = @ir.hot_build_binary(
    func, i32_type, left_multiply, right_multiply,
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  let dead_drop = @ir.hot_build_drop(func, subtract)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      dead_drop, subtract, left_multiply, right_multiply, left_left, left_right,
      right_left, right_right,
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a subtract-of-two-multiplies suffix unsupported when the multiply trees share a descendant" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let left_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, left_multiply, @lib.Instruction::i32_mul())
  let right_multiply = @ir.hot_build_binary(
    func,
    i32_type,
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(
    func,
    right_multiply,
    @lib.Instruction::i32_mul(),
  )
  let subtract = @ir.hot_build_binary(
    func, i32_type, left_multiply, right_multiply,
  )
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps subtract of multiply and add suffix trees unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let left = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let right = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  let subtract = @ir.hot_build_binary(func, i32_type, left[0], right[0])
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a deeper subtract-of-two-multiplies suffix unsupported" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let left = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let nested = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
    @ir.hot_build_const_i32(func, @lib.I32(12)),
  )
  @ir.hot_node_exact_instr_set(func, nested, @lib.Instruction::i32_add())
  let right = @ir.hot_build_binary(
    func,
    i32_type,
    nested,
    @ir.hot_build_const_i32(func, @lib.I32(13)),
  )
  @ir.hot_node_exact_instr_set(func, right, @lib.Instruction::i32_mul())
  let subtract = @ir.hot_build_binary(func, i32_type, left[0], right)
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, subtract),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes two subtract-of-two-multiplies suffix roots" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let drops : Array[Int] = []
  for base in [9, 13] {
    let left = flatten_test_build_direct_binary(
      func,
      @lib.Instruction::i32_mul(),
      base,
      base + 1,
    )
    let right = flatten_test_build_direct_binary(
      func,
      @lib.Instruction::i32_mul(),
      base + 2,
      base + 3,
    )
    let subtract = @ir.hot_build_binary(func, i32_type, left[0], right[0])
    @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
    drops.push(@ir.hot_build_drop(func, subtract))
  }
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    drops[0],
    drops[1],
  ])
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned pure binary drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let add = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, add, left, right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned subtract drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let subtract = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, subtract, @lib.Instruction::i32_sub())
  let dead_drop = @ir.hot_build_drop(func, subtract)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, subtract, left, right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned multiply drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let multiply = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let dead_drop = @ir.hot_build_drop(func, multiply)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, multiply, left, right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned bitwise-and drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let bitwise_and = @ir.hot_build_binary(func, i32_type, left, right)
  @ir.hot_node_exact_instr_set(func, bitwise_and, @lib.Instruction::i32_and())
  let dead_drop = @ir.hot_build_drop(func, bitwise_and)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, bitwise_and, left, right]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps repeated bitwise-and operands gated after a try table" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let repeated = @ir.hot_build_const_i32(func, @lib.I32(9))
  let bitwise_and = @ir.hot_build_binary(func, i32_type, repeated, repeated)
  @ir.hot_node_exact_instr_set(func, bitwise_and, @lib.Instruction::i32_and())
  let dead_drop = @ir.hot_build_drop(func, bitwise_and)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a bitwise-and try-table suffix gated when one operand is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let bitwise_and = @ir.hot_build_binary(func, i32_type, shared_left, right)
  @ir.hot_node_exact_instr_set(func, bitwise_and, @lib.Instruction::i32_and())
  let dead_drop = @ir.hot_build_drop(func, bitwise_and)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_left))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps externally targeted structured dead suffix roots gated" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dead_const = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, dead_const)
  let dead_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    dead_drop,
  ])
  let dead_label = @ir.hot_control_node_label(func, dead_block)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_block,
  ])
  @ir.hot_root_append(func, @ir.hot_build_br(func, dead_label))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a pure binary try-table suffix gated when one operand is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_left = @ir.hot_build_const_i32(func, @lib.I32(9))
  let right = @ir.hot_build_const_i32(func, @lib.I32(10))
  let add = @ir.hot_build_binary(func, i32_type, shared_left, right)
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let dead_drop = @ir.hot_build_drop(func, add)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_left))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned unary drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let clz = @ir.hot_build_unary(func, i32_type, input)
  @ir.hot_node_exact_instr_set(func, clz, @lib.Instruction::i32_clz())
  let dead_drop = @ir.hot_build_drop(func, clz)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, clz, input]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a unary try-table suffix gated when its input is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let clz = @ir.hot_build_unary(func, i32_type, shared_input)
  @ir.hot_node_exact_instr_set(func, clz, @lib.Instruction::i32_clz())
  let dead_drop = @ir.hot_build_drop(func, clz)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_input))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned conversion drop try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let conversion = @ir.hot_build_convert(func, i64_type, input)
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let dead_drop = @ir.hot_build_drop(func, conversion)
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_drop])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_drop, conversion, input]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a conversion try-table suffix gated when its input is shared" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let conversion = @ir.hot_build_convert(func, i64_type, shared_input)
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let dead_drop = @ir.hot_build_drop(func, conversion)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_input))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps other conversion opcodes gated after a try table" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let conversion = @ir.hot_build_convert(func, i64_type, input)
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32u(),
  )
  let dead_drop = @ir.hot_build_drop(func, conversion)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a trapping try-table suffix gated when its binary is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let trap = @ir.hot_build_binary(
    func,
    i32_type,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
  )
  @ir.hot_node_exact_instr_set(func, trap, @lib.Instruction::i32_div_s())
  let dead_drop = @ir.hot_build_drop(func, trap)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, trap))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a pure try-table suffix gated when its value is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_value = @ir.hot_build_const_i32(func, @lib.I32(9))
  let dead_drop = @ir.hot_build_drop(func, shared_value)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_drop,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_value))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned conversion-argument void call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_convert(func, i64_type, input)
  @ir.hot_node_exact_instr_set(
    func,
    argument,
    @lib.Instruction::i64_extend_i32s(),
  )
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_call])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_call, argument, input]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a conversion-argument call suffix gated when its input is shared" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_convert(func, i64_type, shared_input)
  @ir.hot_node_exact_instr_set(
    func,
    argument,
    @lib.Instruction::i64_extend_i32s(),
  )
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_input))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps unsigned conversion-argument call suffixes gated" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_convert(func, i64_type, input)
  @ir.hot_node_exact_instr_set(
    func,
    argument,
    @lib.Instruction::i64_extend_i32u(),
  )
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned unary-argument void call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_unary(func, i32_type, input)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_clz())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_call])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_call, argument, input]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a unary-argument call suffix gated when its input is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_unary(func, i32_type, shared_input)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_clz())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_input))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps other unary-argument call suffix opcodes gated" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(9))
  let argument = @ir.hot_build_unary(func, i32_type, input)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_ctz())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one exclusively owned trapping-binary-argument void call try-table suffix" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dividend = @ir.hot_build_const_i32(func, @lib.I32(1))
  let divisor = @ir.hot_build_const_i32(func, @lib.I32(0))
  let argument = @ir.hot_build_binary(func, i32_type, dividend, divisor)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_div_s())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, dead_call])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([dead_call, argument, dividend, divisor]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a trapping-binary-argument call suffix gated when a descendant is shared" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let shared_dividend = @ir.hot_build_const_i32(func, @lib.I32(1))
  let divisor = @ir.hot_build_const_i32(func, @lib.I32(0))
  let argument = @ir.hot_build_binary(func, i32_type, shared_dividend, divisor)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_div_s())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared_dividend))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps other trapping-binary-argument call opcodes gated" {
  let i32_type = @lib.ValType::i32()
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let dividend = @ir.hot_build_const_i32(func, @lib.I32(1))
  let divisor = @ir.hot_build_const_i32(func, @lib.I32(0))
  let argument = @ir.hot_build_binary(func, i32_type, dividend, divisor)
  @ir.hot_node_exact_instr_set(func, argument, @lib.Instruction::i32_div_u())
  let dead_call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, dead_call,
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_test_build_scalar_try_table_suffix_fixture(
  func : @ir.HotFunc,
) -> Array[Int] {
  let i32_type = @lib.ValType::i32()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  [try_id, label_id, table_id]
}

///|
fn flatten_test_build_direct_binary(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  left_value : Int,
  right_value : Int,
) -> Array[Int] {
  let left = @ir.hot_build_const_i32(func, @lib.I32(left_value))
  let right = @ir.hot_build_const_i32(func, @lib.I32(right_value))
  let binary = @ir.hot_build_binary(func, @lib.ValType::i32(), left, right)
  @ir.hot_node_exact_instr_set(func, binary, instr)
  [binary, left, right]
}

///|
fn flatten_test_build_direct_binary_drop(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  left_value : Int,
  right_value : Int,
) -> Array[Int] {
  let binary = flatten_test_build_direct_binary(
    func, instr, left_value, right_value,
  )
  [@ir.hot_build_drop(func, binary[0]), binary[0], binary[1], binary[2]]
}

///|
test "flatten recognizes one add-drop then multiply-drop try-table suffix" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    11,
    12,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, add[0], multiply[0]])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      add[0],
      add[1],
      add[2],
      add[3],
      multiply[0],
      multiply[1],
      multiply[2],
      multiply[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes one multiply-drop then add-drop try-table suffix" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [table_id, multiply[0], add[0]])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      multiply[0],
      multiply[1],
      multiply[2],
      multiply[3],
      add[0],
      add[1],
      add[2],
      add[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps add-drop then multiply-drop suffix unsupported when a descendant is shared" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let multiply = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, add),
    @ir.hot_build_drop(func, multiply),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a repeated multiply root after an add-multiply suffix pair unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    11,
    12,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    add[0],
    multiply[0],
    multiply[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-multiply-add try-table suffix sequence" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    11,
    12,
  )
  let third = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    13,
    14,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    add[0],
    multiply[0],
    third[0],
  ])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      add[0],
      add[1],
      add[2],
      add[3],
      multiply[0],
      multiply[1],
      multiply[2],
      multiply[3],
      third[0],
      third[1],
      third[2],
      third[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps an add-xor-multiply suffix sequence unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let xor = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_xor(),
    11,
    12,
  )
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    13,
    14,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    add[0],
    xor[0],
    multiply[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps multiply-add suffix roots unsupported when a descendant is shared" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let multiply = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    shared,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    @ir.hot_build_drop(func, multiply),
    @ir.hot_build_drop(func, add),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a repeated add root after a multiply-add suffix pair unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    multiply[0],
    add[0],
    add[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes a multiply-add-multiply try-table suffix sequence" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let multiply = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    9,
    10,
  )
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  let third = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_mul(),
    13,
    14,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    multiply[0],
    add[0],
    third[0],
  ])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      multiply[0],
      multiply[1],
      multiply[2],
      multiply[3],
      add[0],
      add[1],
      add[2],
      add[3],
      third[0],
      third[1],
      third[2],
      third[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_test_recognize_four_direct_binary_suffix_roots(
  reverse : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let instructions = if reverse {
    [
      @lib.Instruction::i32_and(),
      @lib.Instruction::i32_mul(),
      @lib.Instruction::i32_sub(),
      @lib.Instruction::i32_add(),
    ]
  } else {
    [
      @lib.Instruction::i32_add(),
      @lib.Instruction::i32_sub(),
      @lib.Instruction::i32_mul(),
      @lib.Instruction::i32_and(),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root_index = 0
      root_index < instructions.length()
      root_index = root_index + 1 {
    let value = 9 + root_index * 2
    let root = flatten_test_build_direct_binary_drop(
      func,
      instructions[root_index],
      value,
      value + 1,
    )
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-subtract-multiply-and try-table suffix sequence" {
  flatten_test_recognize_four_direct_binary_suffix_roots(false)
}

///|
test "flatten recognizes an and-multiply-subtract-add try-table suffix sequence" {
  flatten_test_recognize_four_direct_binary_suffix_roots(true)
}

///|
fn flatten_wbtest_build_direct_unary_drop(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  input_value : Int,
  result_type : @lib.ValType,
  convert : Bool,
) -> Array[Int] {
  let input = @ir.hot_build_const_i32(func, @lib.I32(input_value))
  let value = if convert {
    @ir.hot_build_convert(func, result_type, input)
  } else {
    @ir.hot_build_unary(func, result_type, input)
  }
  @ir.hot_node_exact_instr_set(func, value, instr)
  let drop = @ir.hot_build_drop(func, value)
  [drop, value, input]
}

///|
fn flatten_wbtest_recognize_mixed_nontrapping_suffix_roots(
  reverse : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if reverse {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_mul(),
        10,
        11,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        12,
        @lib.ValType::i32(),
        false,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_sub(),
        13,
        14,
      ),
    ]
  } else {
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        11,
        @lib.ValType::i32(),
        false,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        12,
        @lib.ValType::i64(),
        true,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        13,
        14,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-clz-extend-and try-table suffix sequence" {
  flatten_wbtest_recognize_mixed_nontrapping_suffix_roots(false)
}

///|
test "flatten recognizes an extend-multiply-clz-subtract try-table suffix sequence" {
  flatten_wbtest_recognize_mixed_nontrapping_suffix_roots(true)
}

///|
test "flatten keeps a sequence with i32 ctz unsupported after a try table" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let ctz = flatten_wbtest_build_direct_unary_drop(
    func,
    @lib.Instruction::i32_ctz(),
    9,
    @lib.ValType::i32(),
    false,
  )
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    10,
    11,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    ctz[0],
    add[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a sequence with unsigned i32 extension unsupported after a try table" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let conversion = flatten_wbtest_build_direct_unary_drop(
    func,
    @lib.Instruction::i64_extend_i32u(),
    9,
    @lib.ValType::i64(),
    true,
  )
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    10,
    11,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    conversion[0],
    add[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_wbtest_recognize_middle_divzero_suffix_roots(
  conversion_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if conversion_first {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_div_s(),
        10,
        0,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        11,
        12,
      ),
    ]
  } else {
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_div_s(),
        11,
        0,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        12,
        @lib.ValType::i32(),
        false,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-divzero-clz try-table suffix sequence" {
  flatten_wbtest_recognize_middle_divzero_suffix_roots(false)
}

///|
test "flatten recognizes an extend-divzero-and try-table suffix sequence" {
  flatten_wbtest_recognize_middle_divzero_suffix_roots(true)
}

///|
test "flatten keeps a sequence with unsigned division unsupported after a try table" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let division = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_div_u(),
    11,
    0,
  )
  let clz = flatten_wbtest_build_direct_unary_drop(
    func,
    @lib.Instruction::i32_clz(),
    12,
    @lib.ValType::i32(),
    false,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    add[0],
    division[0],
    clz[0],
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_wbtest_recognize_sequence_with_unreachable_root(
  unreachable_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let unreachable_root = @ir.hot_build_unreachable(func)
  let roots = if unreachable_first {
    [
      [unreachable_root],
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_div_s(),
        11,
        0,
      ),
    ]
  } else {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      [unreachable_root],
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        10,
        11,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an unreachable-add-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unreachable_root(true)
}

///|
test "flatten recognizes an extend-unreachable-and try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unreachable_root(false)
}

///|
fn flatten_wbtest_recognize_sequence_with_direct_call(
  call_has_argument : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if call_has_argument {
    let argument = @ir.hot_build_const_i32(func, @lib.I32(10))
    let call = @ir.hot_build_call(func, 99, [], [argument])
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      [call, argument],
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        11,
        12,
      ),
    ]
  } else {
    let call = @ir.hot_build_call(func, 99, [], [])
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      [call],
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        11,
        @lib.ValType::i32(),
        false,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-call0-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_direct_call(false)
}

///|
test "flatten recognizes an extend-callarg-and try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_direct_call(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_binary_argument_call(
  argument_instr : @lib.Instruction,
  right_value : Int,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let argument = flatten_test_build_direct_binary(
    func, argument_instr, 11, right_value,
  )
  let call = @ir.hot_build_call(func, 99, [], [argument[0]])
  let last = flatten_wbtest_build_direct_unary_drop(
    func,
    @lib.Instruction::i32_clz(),
    13,
    @lib.ValType::i32(),
    false,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    first[0],
    call,
    last[0],
  ])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      first[0],
      first[1],
      first[2],
      first[3],
      call,
      argument[0],
      argument[1],
      argument[2],
      last[0],
      last[1],
      last[2],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-calladd-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_argument_call(
    @lib.Instruction::i32_add(),
    12,
  )
}

///|
test "flatten recognizes an add-calldivzero-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_argument_call(
    @lib.Instruction::i32_div_s(),
    0,
  )
}

///|
fn flatten_wbtest_recognize_sequence_with_unary_or_conversion_argument_call(
  conversion : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = flatten_test_build_direct_binary_drop(
    func,
    if conversion {
      @lib.Instruction::i32_and()
    } else {
      @lib.Instruction::i32_add()
    },
    9,
    10,
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(11))
  let argument = if conversion {
    @ir.hot_build_convert(func, @lib.ValType::i64(), input)
  } else {
    @ir.hot_build_unary(func, @lib.ValType::i32(), input)
  }
  @ir.hot_node_exact_instr_set(
    func,
    argument,
    if conversion {
      @lib.Instruction::i64_extend_i32s()
    } else {
      @lib.Instruction::i32_clz()
    },
  )
  let call = @ir.hot_build_call(func, 99, [], [argument])
  let last = if conversion {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      12,
      0,
    )
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    first[0],
    call,
    last[0],
  ])
  let expected : Array[Int] = [
    first[0],
    first[1],
    first[2],
    first[3],
    call,
    argument,
    input,
  ]
  for node_id in last {
    expected.push(node_id)
  }
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-callclz-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unary_or_conversion_argument_call(
    false,
  )
}

///|
test "flatten recognizes an and-callextend-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unary_or_conversion_argument_call(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_two_constant_argument_call(
  reverse_types : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if reverse_types {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let first_argument = if reverse_types {
    @ir.hot_build_const_i64(func, @lib.I64(10L))
  } else {
    @ir.hot_build_const_i32(func, @lib.I32(11))
  }
  let second_argument = if reverse_types {
    @ir.hot_build_const_i32(func, @lib.I32(11))
  } else {
    @ir.hot_build_const_i64(func, @lib.I64(12L))
  }
  let call = @ir.hot_build_call(func, 99, [], [first_argument, second_argument])
  let last = if reverse_types {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      12,
      0,
    )
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      13,
      @lib.ValType::i32(),
      false,
    )
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, [call, first_argument, second_argument], last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-call2-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_constant_argument_call(false)
}

///|
test "flatten recognizes an extend-call2-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_constant_argument_call(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_constant_argument_vector(
  four_arguments : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if four_arguments {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let arguments : Array[Int] = if four_arguments {
    [
      @ir.hot_build_const_i64(func, @lib.I64(10L)),
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
      @ir.hot_build_const_i32(func, @lib.I32(13)),
    ]
  } else {
    [
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
      @ir.hot_build_const_i32(func, @lib.I32(13)),
    ]
  }
  let call = @ir.hot_build_call(func, 99, [], arguments)
  let last = if four_arguments {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      14,
      0,
    )
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      14,
      @lib.ValType::i32(),
      false,
    )
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  body.push(first[0])
  for node_id in first {
    expected.push(node_id)
  }
  body.push(call)
  expected.push(call)
  for argument in arguments {
    expected.push(argument)
  }
  body.push(last[0])
  for node_id in last {
    expected.push(node_id)
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-call3-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_constant_argument_vector(false)
}

///|
test "flatten recognizes an extend-call4-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_constant_argument_vector(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_binary_and_constant_arguments(
  rich_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if rich_first {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  }
  let rich = flatten_test_build_direct_binary(
    func,
    if rich_first {
      @lib.Instruction::i32_add()
    } else {
      @lib.Instruction::i32_div_s()
    },
    11,
    if rich_first {
      12
    } else {
      0
    },
  )
  let constant = @ir.hot_build_const_i64(
    func,
    if rich_first {
      @lib.I64(13L)
    } else {
      @lib.I64(10L)
    },
  )
  let call = @ir.hot_build_call(
    func,
    99,
    [],
    if rich_first {
      [rich[0], constant]
    } else {
      [constant, rich[0]]
    },
  )
  let last = if rich_first {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      14,
      @lib.ValType::i32(),
      false,
    )
  } else {
    [@ir.hot_build_unreachable(func)]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  let call_nodes = if rich_first {
    [call, rich[0], constant, rich[1], rich[2]]
  } else {
    [call, constant, rich[0], rich[1], rich[2]]
  }
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-calladdconst-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_constant_arguments(true)
}

///|
test "flatten recognizes an extend-callconstdiv-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_constant_arguments(false)
}

///|
fn flatten_wbtest_recognize_sequence_with_unary_or_conversion_and_constant_arguments(
  conversion : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = flatten_test_build_direct_binary_drop(
    func,
    if conversion {
      @lib.Instruction::i32_and()
    } else {
      @lib.Instruction::i32_add()
    },
    9,
    10,
  )
  let rich = flatten_wbtest_build_direct_unary_drop(
    func,
    if conversion {
      @lib.Instruction::i64_extend_i32s()
    } else {
      @lib.Instruction::i32_clz()
    },
    if conversion {
      12
    } else {
      11
    },
    if conversion {
      @lib.ValType::i64()
    } else {
      @lib.ValType::i32()
    },
    conversion,
  )
  let constant = if conversion {
    @ir.hot_build_const_i32(func, @lib.I32(11))
  } else {
    @ir.hot_build_const_i64(func, @lib.I64(12L))
  }
  let call = @ir.hot_build_call(
    func,
    99,
    [],
    if conversion {
      [constant, rich[1]]
    } else {
      [rich[1], constant]
    },
  )
  let last = if conversion {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      13,
      0,
    )
  }
  let call_nodes = if conversion {
    [call, constant, rich[1], rich[2]]
  } else {
    [call, rich[1], constant, rich[2]]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @ir.hot_delete_node(func, rich[0])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-callclzconst-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unary_or_conversion_and_constant_arguments(
    false,
  )
}

///|
test "flatten recognizes an and-callconstextend-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_unary_or_conversion_and_constant_arguments(
    true,
  )
}

///|
test "flatten keeps a two-argument call sequence gated when arguments repeat" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let argument = @ir.hot_build_const_i32(func, @lib.I32(9))
  let call = @ir.hot_build_call(func, 99, [], [argument, argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    call,
    @ir.hot_build_unreachable(func),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_wbtest_recognize_sequence_with_one_rich_argument_vector(
  conversion : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if conversion {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let rich = if conversion {
    let input = @ir.hot_build_const_i32(func, @lib.I32(13))
    let argument = @ir.hot_build_convert(func, @lib.ValType::i64(), input)
    @ir.hot_node_exact_instr_set(
      func,
      argument,
      @lib.Instruction::i64_extend_i32s(),
    )
    [argument, input]
  } else {
    flatten_test_build_direct_binary(func, @lib.Instruction::i32_add(), 12, 13)
  }
  let arguments : Array[Int] = if conversion {
    [
      @ir.hot_build_const_i32(func, @lib.I32(10)),
      @ir.hot_build_const_i64(func, @lib.I64(11L)),
      @ir.hot_build_const_i32(func, @lib.I32(12)),
      rich[0],
    ]
  } else {
    [
      @ir.hot_build_const_i64(func, @lib.I64(11L)),
      rich[0],
      @ir.hot_build_const_i32(func, @lib.I32(14)),
    ]
  }
  let call = @ir.hot_build_call(func, 99, [], arguments)
  let last = if conversion {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      14,
      0,
    )
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      15,
      @lib.ValType::i32(),
      false,
    )
  }
  let body : Array[Int] = [table_id, first[0], call, last[0]]
  let expected : Array[Int] = []
  for node_id in first {
    expected.push(node_id)
  }
  expected.push(call)
  for argument in arguments {
    expected.push(argument)
  }
  for node_idx = 1; node_idx < rich.length(); node_idx = node_idx + 1 {
    expected.push(rich[node_idx])
  }
  for node_id in last {
    expected.push(node_id)
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-callconstaddconst-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_one_rich_argument_vector(false)
}

///|
test "flatten recognizes an extend-call3constextend-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_one_rich_argument_vector(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_binary_and_unary_arguments(
  unary_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if unary_first {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let binary = flatten_test_build_direct_binary(
    func,
    if unary_first {
      @lib.Instruction::i32_div_s()
    } else {
      @lib.Instruction::i32_add()
    },
    11,
    if unary_first {
      0
    } else {
      12
    },
  )
  let unary_input = @ir.hot_build_const_i32(
    func,
    @lib.I32(if unary_first { 10 } else { 13 }),
  )
  let unary = @ir.hot_build_unary(func, @lib.ValType::i32(), unary_input)
  @ir.hot_node_exact_instr_set(func, unary, @lib.Instruction::i32_clz())
  let call = @ir.hot_build_call(
    func,
    99,
    [],
    if unary_first {
      [unary, binary[0]]
    } else {
      [binary[0], unary]
    },
  )
  let last = if unary_first {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      14,
      0,
    )
  }
  let call_nodes = if unary_first {
    [call, unary, binary[0], unary_input, binary[1], binary[2]]
  } else {
    [call, binary[0], unary, binary[1], binary[2], unary_input]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-calladdclz-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_unary_arguments(false)
}

///|
test "flatten recognizes an extend-callclzdiv-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_unary_arguments(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_binary_and_conversion_arguments(
  conversion_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if conversion_first {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let binary = flatten_test_build_direct_binary(
    func,
    if conversion_first {
      @lib.Instruction::i32_div_s()
    } else {
      @lib.Instruction::i32_add()
    },
    11,
    if conversion_first {
      0
    } else {
      12
    },
  )
  let conversion_input = @ir.hot_build_const_i32(
    func,
    @lib.I32(if conversion_first { 10 } else { 13 }),
  )
  let conversion = @ir.hot_build_convert(
    func,
    @lib.ValType::i64(),
    conversion_input,
  )
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let call = @ir.hot_build_call(
    func,
    99,
    [],
    if conversion_first {
      [conversion, binary[0]]
    } else {
      [binary[0], conversion]
    },
  )
  let last = if conversion_first {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      14,
      @lib.ValType::i32(),
      false,
    )
  }
  let call_nodes = if conversion_first {
    [call, conversion, binary[0], conversion_input, binary[1], binary[2]]
  } else {
    [call, binary[0], conversion, binary[1], binary[2], conversion_input]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-calladdextend-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_conversion_arguments(false)
}

///|
test "flatten recognizes an extend-callextenddiv-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_binary_and_conversion_arguments(true)
}

///|
fn flatten_wbtest_recognize_sequence_with_two_binary_arguments(
  division_first : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if division_first {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let add = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    11,
    12,
  )
  let division = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_div_s(),
    if division_first {
      10
    } else {
      13
    },
    0,
  )
  let call = @ir.hot_build_call(
    func,
    99,
    [],
    if division_first {
      [division[0], add[0]]
    } else {
      [add[0], division[0]]
    },
  )
  let last = if division_first {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i32_clz(),
      14,
      @lib.ValType::i32(),
      false,
    )
  }
  let call_nodes = if division_first {
    [call, division[0], add[0], division[1], division[2], add[1], add[2]]
  } else {
    [call, add[0], division[0], add[1], add[2], division[1], division[2]]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-calladddiv-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_binary_arguments(false)
}

///|
test "flatten recognizes an extend-calldivadd-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_binary_arguments(true)
}

///|
test "flatten keeps a binary-rich call pair gated when one opcode is outside the roster" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first_add = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let shift = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_rotl(),
    11,
    12,
  )
  let call = @ir.hot_build_call(func, 99, [], [first_add[0], shift[0]])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    call,
    @ir.hot_build_unreachable(func),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_wbtest_recognize_sequence_with_two_unary_or_conversion_arguments(
  first_conversion : Bool,
  second_conversion : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let first = if first_conversion {
    flatten_wbtest_build_direct_unary_drop(
      func,
      @lib.Instruction::i64_extend_i32s(),
      9,
      @lib.ValType::i64(),
      true,
    )
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      9,
      10,
    )
  }
  let first_input = @ir.hot_build_const_i32(func, @lib.I32(11))
  let first_argument = if first_conversion {
    @ir.hot_build_convert(func, @lib.ValType::i64(), first_input)
  } else {
    @ir.hot_build_unary(func, @lib.ValType::i32(), first_input)
  }
  @ir.hot_node_exact_instr_set(
    func,
    first_argument,
    if first_conversion {
      @lib.Instruction::i64_extend_i32s()
    } else {
      @lib.Instruction::i32_clz()
    },
  )
  let second_input = @ir.hot_build_const_i32(func, @lib.I32(12))
  let second_argument = if second_conversion {
    @ir.hot_build_convert(func, @lib.ValType::i64(), second_input)
  } else {
    @ir.hot_build_unary(func, @lib.ValType::i32(), second_input)
  }
  @ir.hot_node_exact_instr_set(
    func,
    second_argument,
    if second_conversion {
      @lib.Instruction::i64_extend_i32s()
    } else {
      @lib.Instruction::i32_clz()
    },
  )
  let call = @ir.hot_build_call(func, 99, [], [first_argument, second_argument])
  let last = if first_conversion {
    [@ir.hot_build_unreachable(func)]
  } else {
    flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_div_s(),
      13,
      0,
    )
  }
  let call_nodes = [
    call, first_argument, second_argument, first_input, second_input,
  ]
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in [first, call_nodes, last] {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-callclzextend-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_unary_or_conversion_arguments(
    false, true,
  )
}

///|
test "flatten recognizes an extend-callextendclz-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_unary_or_conversion_arguments(
    true, false,
  )
}

///|
test "flatten recognizes an add-callclzclz-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_unary_or_conversion_arguments(
    false, false,
  )
}

///|
test "flatten recognizes an extend-callextendextend-unreachable try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_unary_or_conversion_arguments(
    true, true,
  )
}

///|
test "flatten keeps a three-rich call gated when one opcode is outside the roster" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let binary = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let unary_input = @ir.hot_build_const_i32(func, @lib.I32(11))
  let unary = @ir.hot_build_unary(func, @lib.ValType::i32(), unary_input)
  @ir.hot_node_exact_instr_set(func, unary, @lib.Instruction::i32_ctz())
  let conversion_input = @ir.hot_build_const_i32(func, @lib.I32(12))
  let conversion = @ir.hot_build_convert(
    func,
    @lib.ValType::i64(),
    conversion_input,
  )
  @ir.hot_node_exact_instr_set(
    func,
    conversion,
    @lib.Instruction::i64_extend_i32s(),
  )
  let call = @ir.hot_build_call(func, 99, [], [binary[0], unary, conversion])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    call,
    @ir.hot_build_unreachable(func),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
fn flatten_wbtest_sequence_with_other_unary_or_conversion_argument_is_gated(
  conversion : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let add = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let input = @ir.hot_build_const_i32(func, @lib.I32(11))
  let argument = if conversion {
    @ir.hot_build_convert(func, @lib.ValType::i64(), input)
  } else {
    @ir.hot_build_unary(func, @lib.ValType::i32(), input)
  }
  @ir.hot_node_exact_instr_set(
    func,
    argument,
    if conversion {
      @lib.Instruction::i64_extend_i32u()
    } else {
      @lib.Instruction::i32_ctz()
    },
  )
  let call = @ir.hot_build_call(func, 99, [], [argument])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    add[0],
    call,
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten keeps a sequence with another unary-argument call unsupported" {
  flatten_wbtest_sequence_with_other_unary_or_conversion_argument_is_gated(
    false,
  )
}

///|
test "flatten keeps a sequence with another conversion-argument call unsupported" {
  flatten_wbtest_sequence_with_other_unary_or_conversion_argument_is_gated(true)
}

///|
fn flatten_wbtest_build_one_multiply_child_drop(
  func : @ir.HotFunc,
  outer_instr : @lib.Instruction,
  multiply_on_left : Bool,
  base : Int,
) -> Array[Int] {
  let multiply_left = @ir.hot_build_const_i32(func, @lib.I32(base))
  let multiply_right = @ir.hot_build_const_i32(func, @lib.I32(base + 1))
  let multiply = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    multiply_left,
    multiply_right,
  )
  @ir.hot_node_exact_instr_set(func, multiply, @lib.Instruction::i32_mul())
  let outer_const = @ir.hot_build_const_i32(func, @lib.I32(base + 2))
  let outer = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    if multiply_on_left {
      multiply
    } else {
      outer_const
    },
    if multiply_on_left {
      outer_const
    } else {
      multiply
    },
  )
  @ir.hot_node_exact_instr_set(func, outer, outer_instr)
  [
    @ir.hot_build_drop(func, outer),
    outer,
    if multiply_on_left {
      multiply
    } else {
      outer_const
    },
    if multiply_on_left {
      outer_const
    } else {
      multiply
    },
    multiply_left,
    multiply_right,
  ]
}

///|
fn flatten_wbtest_recognize_sequence_with_one_multiply_child_drop(
  subtract_tree : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if subtract_tree {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      flatten_wbtest_build_one_multiply_child_drop(
        func,
        @lib.Instruction::i32_sub(),
        true,
        10,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        13,
        14,
      ),
    ]
  } else {
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      flatten_wbtest_build_one_multiply_child_drop(
        func,
        @lib.Instruction::i32_add(),
        false,
        11,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        14,
        @lib.ValType::i32(),
        false,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-nested-addmul-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_one_multiply_child_drop(false)
}

///|
test "flatten recognizes an extend-nested-submul-and try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_one_multiply_child_drop(true)
}

///|
fn flatten_wbtest_build_two_multiply_children_drop(
  func : @ir.HotFunc,
  outer_instr : @lib.Instruction,
  base : Int,
) -> Array[Int] {
  let left = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    base,
    base + 1,
  )
  let right = flatten_test_build_direct_binary(
    func,
    @lib.Instruction::i32_mul(),
    base + 2,
    base + 3,
  )
  let outer = @ir.hot_build_binary(func, @lib.ValType::i32(), left[0], right[0])
  @ir.hot_node_exact_instr_set(func, outer, outer_instr)
  [
    @ir.hot_build_drop(func, outer),
    outer,
    left[0],
    right[0],
    left[1],
    left[2],
    right[1],
    right[2],
  ]
}

///|
fn flatten_wbtest_recognize_sequence_with_two_multiply_children_drop(
  subtract_tree : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if subtract_tree {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      flatten_wbtest_build_two_multiply_children_drop(
        func,
        @lib.Instruction::i32_sub(),
        10,
      ),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        14,
        15,
      ),
    ]
  } else {
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_add(),
        9,
        10,
      ),
      flatten_wbtest_build_two_multiply_children_drop(
        func,
        @lib.Instruction::i32_add(),
        11,
      ),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        15,
        @lib.ValType::i32(),
        false,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an add-tworichadd-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_multiply_children_drop(false)
}

///|
test "flatten recognizes an extend-tworichsub-and try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_two_multiply_children_drop(true)
}

///|
fn flatten_wbtest_build_deeper_two_multiply_children_drop(
  func : @ir.HotFunc,
  subtract_tree : Bool,
  base : Int,
) -> Array[Int] {
  let rich = flatten_wbtest_build_two_multiply_children_drop(
    func,
    if subtract_tree {
      @lib.Instruction::i32_sub()
    } else {
      @lib.Instruction::i32_add()
    },
    base,
  )
  let constant = @ir.hot_build_const_i32(func, @lib.I32(base + 4))
  let outer = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    if subtract_tree {
      constant
    } else {
      rich[1]
    },
    if subtract_tree {
      rich[1]
    } else {
      constant
    },
  )
  @ir.hot_node_exact_instr_set(
    func,
    outer,
    if subtract_tree {
      @lib.Instruction::i32_sub()
    } else {
      @lib.Instruction::i32_add()
    },
  )
  [
    @ir.hot_build_drop(func, outer),
    outer,
    if subtract_tree {
      constant
    } else {
      rich[1]
    },
    if subtract_tree {
      rich[1]
    } else {
      constant
    },
    rich[2],
    rich[3],
    rich[4],
    rich[5],
    rich[6],
    rich[7],
  ]
}

///|
fn flatten_wbtest_recognize_sequence_with_deeper_two_multiply_children_drop(
  subtract_tree : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let roots = if subtract_tree {
    [
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i64_extend_i32s(),
        9,
        @lib.ValType::i64(),
        true,
      ),
      flatten_wbtest_build_deeper_two_multiply_children_drop(func, true, 10),
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_div_s(),
        16,
        0,
      ),
    ]
  } else {
    [
      flatten_test_build_direct_binary_drop(
        func,
        @lib.Instruction::i32_and(),
        9,
        10,
      ),
      flatten_wbtest_build_deeper_two_multiply_children_drop(func, false, 11),
      flatten_wbtest_build_direct_unary_drop(
        func,
        @lib.Instruction::i32_clz(),
        16,
        @lib.ValType::i32(),
        false,
      ),
    ]
  }
  let body : Array[Int] = [table_id]
  let expected : Array[Int] = []
  for root in roots {
    body.push(root[0])
    for node_id in root {
      expected.push(node_id)
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, body)
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some(expected),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes an and-deepadd-clz try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_deeper_two_multiply_children_drop(
    false,
  )
}

///|
test "flatten recognizes an extend-deepsub-divzero try-table suffix sequence" {
  flatten_wbtest_recognize_sequence_with_deeper_two_multiply_children_drop(true)
}

///|
test "flatten keeps a sequence with an alternate deeper two-rich-child root unsupported" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let direct = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  let rich = flatten_wbtest_build_two_multiply_children_drop(
    func,
    @lib.Instruction::i32_add(),
    11,
  )
  let outer_const = @ir.hot_build_const_i32(func, @lib.I32(15))
  let deeper = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    rich[1],
    outer_const,
  )
  @ir.hot_node_exact_instr_set(func, deeper, @lib.Instruction::i32_mul())
  @ir.hot_delete_node(func, rich[0])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    direct[0],
    @ir.hot_build_drop(func, deeper),
  ])
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten recognizes a submul-dropconst-and try-table suffix sequence" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let rich = flatten_wbtest_build_one_multiply_child_drop(
    func,
    @lib.Instruction::i32_sub(),
    true,
    9,
  )
  let constant = @ir.hot_build_const_i32(func, @lib.I32(12))
  let drop_const = @ir.hot_build_drop(func, constant)
  let last = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_and(),
    13,
    14,
  )
  let body_ref = @ir.hot_region_body_ref(func, try_id)
  @ir.hot_region_replace_body(func, body_ref, [
    table_id,
    rich[0],
    drop_const,
    last[0],
  ])
  @debug.assert_eq(
    flatten_try_table_dead_suffix_nodes(func, body_ref, table_id),
    Some([
      rich[0],
      rich[1],
      rich[2],
      rich[3],
      rich[4],
      rich[5],
      drop_const,
      constant,
      last[0],
      last[1],
      last[2],
      last[3],
    ]),
  )
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func, table_id, label_id, 1, false,
    ),
  )
}

///|
test "flatten terminal proof caches allocate only inspected owners" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let suffix = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    suffix[0],
  ])
  let scalar_try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_const_i32(func, @lib.I32(3))],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(4))]),
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, scalar_try_id))
  for i = 0; i < 256; i = i + 1 {
    @ir.hot_root_append(func, @ir.hot_build_nop(func))
  }
  let state = FlattenRewriteState::new(func)
  @debug.assert_eq(state.dead_suffix_entries.length(), 0)
  @debug.assert_eq(state.terminal_table_entries.length(), 0)
  @debug.assert_eq(state.scalar_try_entries.length(), 0)
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func,
      table_id,
      label_id,
      1,
      false,
      state=Some(state),
    ),
  )
  @debug.assert_eq(state.dead_suffix_entries.length(), 1)
  @debug.assert_eq(state.terminal_table_entries.length(), 1)
  assert_true(
    flatten_scalar_legacy_try_is_supported(
      func,
      scalar_try_id,
      state=Some(state),
    ),
  )
  @debug.assert_eq(state.scalar_try_entries.length(), 1)
}

///|
test "flatten terminal proof caches keep sparse entries sorted" {
  let func = @ir.HotFunc::new()
  let label_ids : Array[Int] = []
  let table_ids : Array[Int] = []
  for value in [1, 3, 5] {
    let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
    let try_id = fixture[0]
    let table_id = fixture[2]
    let suffix = flatten_test_build_direct_binary_drop(
      func,
      @lib.Instruction::i32_add(),
      value,
      value + 1,
    )
    @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
      table_id,
      suffix[0],
    ])
    label_ids.push(fixture[1])
    table_ids.push(table_id)
  }
  let state = FlattenRewriteState::new(func)
  for index in [2, 0, 1] {
    assert_true(
      flatten_try_terminal_br_table_targets_label(
        func,
        table_ids[index],
        label_ids[index],
        1,
        false,
        state=Some(state),
      ),
    )
  }
  @debug.assert_eq(
    state.dead_suffix_entries.map(fn(entry) { entry.table_id }),
    table_ids,
  )
  @debug.assert_eq(
    state.terminal_table_entries.map(fn(entry) { entry.node_id }),
    table_ids,
  )
  for table_id in table_ids {
    assert_true(
      flatten_dead_suffix_entry_index(state.dead_suffix_entries, table_id) >= 0,
    )
    assert_true(
      flatten_terminal_table_entry_index(state.terminal_table_entries, table_id) >=
      0,
    )
  }
}

///|
test "flatten scalar try proof cache keeps sparse entries sorted" {
  let func = @ir.HotFunc::new()
  let try_ids : Array[Int] = []
  for value in [1, 3, 5] {
    let try_id = @ir.hot_build_try(
      func,
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@ir.hot_build_const_i32(func, @lib.I32(value))],
      catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(value + 1))]),
    )
    try_ids.push(try_id)
    @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  }
  let state = FlattenRewriteState::new(func)
  for try_id in [try_ids[2], try_ids[0], try_ids[1]] {
    assert_true(
      flatten_scalar_legacy_try_is_supported(func, try_id, state=Some(state)),
    )
  }
  @debug.assert_eq(
    state.scalar_try_entries.map(fn(entry) { entry.try_id }),
    try_ids,
  )
  for try_id in try_ids {
    let entry_index = flatten_scalar_try_entry_index(
      state.scalar_try_entries,
      try_id,
    )
    assert_true(entry_index >= 0)
    @debug.assert_eq(state.scalar_try_entries[entry_index].try_id, try_id)
  }
}

///|
test "flatten terminal table proofs require an exact pre-mutation cache" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let label_id = fixture[1]
  let table_id = fixture[2]
  let suffix = flatten_test_build_direct_binary_drop(
    func,
    @lib.Instruction::i32_add(),
    9,
    10,
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id,
    suffix[0],
  ])
  let cached = FlattenRewriteState::new(func)
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func,
      table_id,
      label_id,
      1,
      false,
      state=Some(cached),
    ),
  )
  cached.rewrites_started = true
  assert_true(
    flatten_try_terminal_br_table_targets_label(
      func,
      table_id,
      label_id,
      1,
      false,
      state=Some(cached),
    ),
  )
  let missing = FlattenRewriteState::new(func)
  assert_true(
    flatten_try_table_dead_suffix_nodes(
      func,
      @ir.hot_region_body_ref(func, try_id),
      table_id,
      state=Some(missing),
    )
    is Some(_),
  )
  missing.rewrites_started = true
  assert_false(
    flatten_try_terminal_br_table_targets_label(
      func,
      table_id,
      label_id,
      1,
      false,
      state=Some(missing),
    ),
  )
}

///|
test "flatten lightweight use counts match exact pre-mutation ownership" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_id = fixture[0]
  let table_id = fixture[2]
  let shared = @ir.hot_build_const_i32(func, @lib.I32(9))
  let sum = @ir.hot_build_binary(func, @lib.ValType::i32(), shared, shared)
  @ir.hot_node_exact_instr_set(func, sum, @lib.Instruction::i32_add())
  let call = @ir.hot_build_call(func, 99, [], [sum])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table_id, call,
  ])
  let expected = @ir.use_def_build_node_uses(func)
  let actual = flatten_build_node_use_counts(func)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      @debug.assert_eq(
        @ir.hot_node_use_count(actual, node_id),
        @ir.node_use_count(expected, node_id),
      )
    }
  }
  @debug.assert_eq(@ir.hot_node_use_count(actual, try_id), 1)
  @debug.assert_eq(@ir.hot_node_use_count(actual, table_id), 1)
  @debug.assert_eq(@ir.hot_node_use_count(actual, call), 1)
  @debug.assert_eq(@ir.hot_node_use_count(actual, sum), 1)
  @debug.assert_eq(@ir.hot_node_use_count(actual, shared), 2)
}

///|
test "flatten pre-mutation node index shares flatness classification" {
  let func = @ir.HotFunc::new()
  let rich_drop = flatten_test_build_rich_drop(func)
  @ir.hot_root_append(func, rich_drop[1])
  let block_id = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, block_id))
  @ir.hot_root_append(
    func,
    @ir.hot_build_node(func, @ir.HotOp::br_on_null(), @ir.hot_type_void(func)),
  )
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(9)))
  let expected = flatten_classify_hot(func)
  let index = flatten_build_pre_mutation_node_index(func)
  @debug.assert_eq(index.flatness_report, expected)
  let state = FlattenRewriteState::new(func)
  @debug.assert_eq(state.flatness_report, expected)
}

///|
test "flatten pre-mutation node index shares EH prerequisite classification" {
  let func = @ir.HotFunc::new()
  let catch_id = @ir.hot_build_node(
    func,
    @ir.HotOp::catch_(),
    @ir.hot_type_void(func),
  )
  let rethrow_id = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
  )
  @ir.hot_root_append(func, catch_id)
  @ir.hot_root_append(func, rethrow_id)
  for i = 0; i < 256; i = i + 1 {
    @ir.hot_root_append(func, @ir.hot_build_nop(func))
  }
  let index = flatten_build_pre_mutation_node_index(func)
  @debug.assert_eq(
    index.eh_repair_requirement.needs_catch_payload_tracking,
    true,
  )
  @debug.assert_eq(
    index.eh_repair_requirement.needs_exceptional_transfer_repair,
    true,
  )
  let state = FlattenRewriteState::new(func)
  @debug.assert_eq(
    state.eh_repair_requirement.needs_catch_payload_tracking,
    index.eh_repair_requirement.needs_catch_payload_tracking,
  )
  @debug.assert_eq(
    state.eh_repair_requirement.needs_exceptional_transfer_repair,
    index.eh_repair_requirement.needs_exceptional_transfer_repair,
  )
}

///|
test "flatten admission node index shares the exact live-node scan" {
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let label_id = @ir.hot_control_node_label(func, block_id)
  let branch_id = @ir.hot_build_br(func, label_id)
  let branch_if_id = @ir.hot_build_br_if(
    func,
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
  )
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id, label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
  )
  let loop_id = @ir.hot_build_loop(func, @lib.BlockType::void_(), [])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block_id), [
    branch_id, branch_if_id, table_id, loop_id, try_id,
  ])
  for i = 0; i < 256; i = i + 1 {
    @ir.hot_root_append(func, @ir.hot_build_nop(func))
  }
  @ir.hot_root_append(func, block_id)
  let index = flatten_build_pre_mutation_node_index(func)
  @debug.assert_eq(index.label_branch_nodes[label_id], [
    branch_id, branch_if_id, table_id,
  ])
  @debug.assert_eq(index.loop_nodes, [loop_id])
  @debug.assert_eq(index.try_nodes, [try_id])
  @debug.assert_eq(index.branch_payload_nodes, [
    branch_id, branch_if_id, table_id,
  ])
}

///|
test "flatten branch index deduplicates only the current node target" {
  let branch_nodes : Array[Array[Int]] = [[], []]
  let last_recorded_node = [-1, -1]
  flatten_record_label_branch_node(branch_nodes, last_recorded_node, 1, 5)
  flatten_record_label_branch_node(branch_nodes, last_recorded_node, 1, 5)
  flatten_record_label_branch_node(branch_nodes, last_recorded_node, 1, 6)
  @debug.assert_eq(branch_nodes[0], [])
  @debug.assert_eq(branch_nodes[1], [5, 6])
  @debug.assert_eq(last_recorded_node, [-1, 6])
}

///|
test "flatten label branch cache records each exact targeting node once" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let try_label = fixture[1]
  let table_id = fixture[2]
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let block_label = @ir.hot_control_node_label(func, block_id)
  let branch_id = @ir.hot_build_br(func, block_label)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, fixture[0]), [
    table_id, branch_id,
  ])
  let branches = flatten_build_label_branch_nodes(func)
  @debug.assert_eq(branches[try_label], [table_id])
  @debug.assert_eq(branches[block_label], [branch_id])
}

///|
test "flatten replaces one region root without rebuilding its siblings" {
  let func = @ir.HotFunc::new()
  let value = @ir.hot_build_const_i32(func, @lib.I32(7))
  let sibling = @ir.hot_build_nop(func)
  @ir.hot_root_append(func, value)
  @ir.hot_root_append(func, sibling)
  let local_id = @ir.hot_append_body_local(func, @lib.ValType::i32())
  let replacement = @ir.hot_build_local_set(func, local_id, value)
  let revision = @ir.hot_revision_current(func)
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(
    flatten_set_region_root(ctx, func, @ir.HotRegionRef::root(), 0, replacement),
    value,
  )
  @debug.assert_eq(@ir.hot_root_get(func, 0), replacement)
  @debug.assert_eq(@ir.hot_root_get(func, 1), sibling)
  @debug.assert_eq(@ir.hot_child_get(func, replacement, 0), value)
  @debug.assert_eq(@ir.hot_revision_current(func), revision + 1)
}

///|
test "flatten rewrite scalar target proof uses the pre-mutation branch index" {
  let func = @ir.HotFunc::new()
  let fixture = flatten_test_build_scalar_try_table_suffix_fixture(func)
  let label_id = fixture[1]
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, fixture[0]), [
    fixture[2],
  ])
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_target_can_route_scalar_branches(
      func,
      label_id,
      @lib.ValType::i32(),
      state=Some(state),
    ),
  )
  let left = @ir.hot_build_const_i32(func, @lib.I32(1))
  let right = @ir.hot_build_const_i32(func, @lib.I32(2))
  let rogue = @ir.hot_build_br(func, label_id)
  ignore(@ir.hot_replace_child_span(func, rogue, [left, right]))
  assert_false(
    flatten_target_can_route_scalar_branches(
      func,
      label_id,
      @lib.ValType::i32(),
    ),
  )
  state.rewrites_started = true
  assert_true(
    flatten_rewrite_target_can_route_scalar_branches(
      func,
      state,
      label_id,
      @lib.ValType::i32(),
    ),
  )
}

///|
test "flatten rewrite multivalue target proof uses the pre-mutation branch index" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (block (result i32 i64) (br 0 (i32.const 7) (i64.const 9))) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let block_id = @ir.hot_child_get(func, return_id, 0)
  let label_id = @ir.hot_control_node_label(func, block_id)
  let target_types = @ir.hot_type_results(
    func,
    @ir.hot_label_result_type(func, label_id),
  )
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_multivalue_branch_target_is_supported_with_table(
      func,
      label_id,
      target_types,
      -1,
      state=Some(state),
    ),
  )
  let rogue = @ir.hot_build_br(func, label_id, values=[
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  ])
  assert_false(
    flatten_multivalue_branch_target_is_supported_with_table(
      func, label_id, target_types, -1,
    ),
  )
  state.rewrites_started = true
  assert_true(
    flatten_rewrite_multivalue_branch_target_is_supported(
      func, state, label_id, target_types, -1,
    ),
  )
  assert_true(@ir.hot_node_is_live(func, rogue))
}

///|
test "flatten resolves each br_table target local vector once" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (block (result i32 i64) (block (result i32 i64) (br_table 0 1 (i32.const 7) (i64.const 9) (i32.const 0)))) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let outer_id = @ir.hot_child_get(func, return_id, 0)
  let inner_id = @ir.hot_region_get(
    func,
    @ir.hot_region_body_ref(func, outer_id),
    0,
  )
  let targets = [
    @ir.hot_control_node_label(func, inner_id),
    @ir.hot_control_node_label(func, outer_id),
  ]
  let target_types = @ir.hot_type_results(
    func,
    @ir.hot_label_result_type(func, targets[0]),
  )
  let state = FlattenRewriteState::new(func)
  state.rewrites_started = true
  let target_view = FlattenBrTableTargets::new(targets, 0, targets.length())
  let local_count = @ir.hot_local_count(func)
  assert_true(
    flatten_prepare_br_table_target_locals(
      func, state, target_view, target_types,
    ),
  )
  @debug.assert_eq(@ir.hot_local_count(func), local_count + 4)
  @debug.assert_eq(state.label_temps[targets[0]].length(), 2)
  @debug.assert_eq(state.label_temps[targets[1]].length(), 2)
  assert_true(
    flatten_prepare_br_table_target_locals(
      func, state, target_view, target_types,
    ),
  )
  @debug.assert_eq(@ir.hot_local_count(func), local_count + 4)
}

///|
test "flatten single-target table stages in the exact target vector" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (block (result i32 i64) (block (result i32 i64) (br_table 0 1 (i32.const 7) (i64.const 9) (i32.const 0)))) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let outer_id = @ir.hot_child_get(func, return_id, 0)
  let inner_id = @ir.hot_region_get(
    func,
    @ir.hot_region_body_ref(func, outer_id),
    0,
  )
  let targets = [
    @ir.hot_control_node_label(func, inner_id),
    @ir.hot_control_node_label(func, outer_id),
  ]
  let target_types = @ir.hot_type_results(
    func,
    @ir.hot_label_result_type(func, targets[0]),
  )
  let state = FlattenRewriteState::new(func)
  state.rewrites_started = true
  let target_view = FlattenBrTableTargets::new(targets, 0, targets.length())
  assert_true(
    flatten_prepare_br_table_target_locals(
      func, state, target_view, target_types,
    ),
  )
  let first_target_locals = state.label_temps[targets[0]]
  let second_target_locals = state.label_temps[targets[1]]
  let local_count = @ir.hot_local_count(func)
  let single_targets = [targets[0]]
  let single = flatten_br_table_staging_locals(
    func,
    state,
    FlattenBrTableTargets::new(single_targets, 0, 1),
    target_types,
  )
  @debug.assert_eq(single, first_target_locals)
  @debug.assert_eq(@ir.hot_local_count(func), local_count)
  let multiple = flatten_br_table_staging_locals(
    func, state, target_view, target_types,
  )
  @debug.assert_eq(@ir.hot_local_count(func), local_count + 2)
  assert_true(multiple != first_target_locals)
  assert_true(multiple != second_target_locals)
}

///|
test "flatten rewrite multivalue try proof uses the pre-mutation branch index" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, [i32_type, i64_type]),
  )
  let body_first = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second = @ir.hot_build_const_i64(func, @lib.I64(10L))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first, body_second],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      [i32_type, i64_type],
    ),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let first_payload = @ir.hot_build_const_i32(func, @lib.I32(7))
  let second_payload = @ir.hot_build_const_i64(func, @lib.I64(8L))
  let branch = @ir.hot_build_br_if(
    func,
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[first_payload, second_payload],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    branch,
    @ir.hot_build_drop(func, second_payload),
    @ir.hot_build_drop(func, first_payload),
    body_first,
    body_second,
  ])
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id, try_id]))
  let result_types = [i32_type, i64_type]
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_multivalue_legacy_try_label_uses_are_supported(
      func,
      try_id,
      result_types,
      state=Some(state),
    ),
  )
  let rogue = @ir.hot_build_br(func, label_id, values=[
    @ir.hot_build_const_i32(func, @lib.I32(13)),
  ])
  @ir.hot_root_append(func, rogue)
  assert_false(
    flatten_multivalue_legacy_try_label_uses_are_supported(
      func, try_id, result_types,
    ),
  )
  state.rewrites_started = true
  assert_true(
    flatten_multivalue_legacy_try_label_uses_are_supported(
      func,
      try_id,
      result_types,
      state=Some(state),
    ),
  )
}

///|
test "flatten rewrite multivalue try flow uses pre-mutation ownership counts" {
  let i32_type = @lib.ValType::i32()
  let i64_type = @lib.ValType::i64()
  let result_types = [i32_type, i64_type]
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, result_types),
  )
  let body_first = @ir.hot_build_const_i32(func, @lib.I32(9))
  let body_second = @ir.hot_build_const_i64(func, @lib.I64(10L))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [body_first, body_second],
    catch_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(11)),
      @ir.hot_build_const_i64(func, @lib.I64(12L)),
    ]),
  )
  @ir.hot_control_result_type_set(
    func,
    try_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let first_payload = @ir.hot_build_const_i32(func, @lib.I32(7))
  let second_payload = @ir.hot_build_const_i64(func, @lib.I64(8L))
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    first_payload, second_payload,
  ])
  let branch = @ir.hot_build_br_if(
    func,
    @ir.hot_control_node_label(func, try_id),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[tuple_id, tuple_id],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    branch,
    @ir.hot_build_drop(func, tuple_id),
    @ir.hot_build_drop(func, tuple_id),
    body_first,
    body_second,
  ])
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id, try_id]))
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_multivalue_try_br_if_flow_is_exact(
      func,
      try_id,
      branch,
      result_types,
      state=Some(state),
    )
    is Some(_),
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, tuple_id))
  assert_true(
    flatten_multivalue_try_br_if_flow_is_exact(
      func, try_id, branch, result_types,
    )
    is None,
  )
  state.rewrites_started = true
  assert_true(
    flatten_rewrite_multivalue_try_br_if_flow_is_exact(
      func, state, try_id, branch, result_types,
    )
    is Some(_),
  )
}

///|
test "flatten rewrite region tail tuple proof uses pre-mutation ownership counts" {
  let result_types = [@lib.ValType::i32(), @lib.ValType::i64()]
  let func = @ir.HotFunc::new()
  let first = @ir.hot_build_const_i32(func, @lib.I32(7))
  let second = @ir.hot_build_const_i64(func, @lib.I64(9L))
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [first, second])
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [tuple_id])
  @ir.hot_control_result_type_set(
    func,
    block_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  @ir.hot_root_append(func, block_id)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_multivalue_region_tail_tuple_make_values(
      func,
      body_ref,
      result_types,
      state=Some(state),
    )
    is Some(_),
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, tuple_id))
  assert_true(
    flatten_multivalue_region_tail_tuple_make_values(
      func, body_ref, result_types,
    )
    is None,
  )
  state.rewrites_started = true
  assert_true(
    flatten_rewrite_multivalue_region_tail_tuple_make_values(
      func, state, body_ref, result_types,
    )
    is Some(_),
  )
}

///|
test "flatten rewrite multivalue loop proof uses the pre-mutation branch index" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32 i64))) (func (result i32 i64) call 1 call 2 loop $loop (type $carrier) drop drop call 3 call 4 call 5 br_if $loop drop drop i32.const 11 i64.const 13 end return) (func (result i32) i32.const 1) (func (result i64) i64.const 2) (func (result i32) i32.const 7) (func (result i64) i64.const 9) (func (result i32) i32.const 0))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let loop_id = @ir.hot_child_get(func, return_id, 0)
  let label_id = @ir.hot_control_node_label(func, loop_id)
  let payload_count = @ir.hot_label_branch_arity(func, label_id)
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_multivalue_loop_br_if_flows_are_exact(
      func,
      loop_id,
      label_id,
      payload_count,
      state=Some(state),
    ),
  )
  let rogue = @ir.hot_build_br_if(
    func,
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(17))],
  )
  @ir.hot_root_append(func, rogue)
  assert_false(
    flatten_multivalue_loop_br_if_flows_are_exact(
      func, loop_id, label_id, payload_count,
    ),
  )
  state.rewrites_started = true
  assert_true(
    flatten_rewrite_multivalue_loop_br_if_flows_are_exact(
      func, state, loop_id, label_id, payload_count,
    ),
  )
}

///|
test "flatten inputful loop support freezes the exact admission result" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32) (result i32))) (func call 1 loop $loop (type $carrier) drop i32.const 7 end drop) (func (result i32) i32.const 1))",
  )
  let loop_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let label_id = @ir.hot_control_node_label(func, loop_id)
  let state = FlattenRewriteState::new(func)
  @debug.assert_eq(state.inputful_loop_support_entries.length(), 0)
  assert_true(
    flatten_inputful_loop_is_supported(func, loop_id, state=Some(state)),
  )
  @debug.assert_eq(state.inputful_loop_support_entries.length(), 1)
  @ir.hot_root_append(func, @ir.hot_build_br(func, label_id))
  assert_false(flatten_inputful_loop_is_supported(func, loop_id))
  state.rewrites_started = true
  assert_true(
    flatten_inputful_loop_is_supported(func, loop_id, state=Some(state)),
  )
}

///|
test "flatten inputful loop proof cache keeps sparse entries sorted" {
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32) (result i32))) (func call 1 loop (type $carrier) drop i32.const 7 end drop call 1 loop (type $carrier) drop i32.const 8 end drop call 1 loop (type $carrier) drop i32.const 9 end drop) (func (result i32) i32.const 1))",
  )
  let loop_ids : Array[Int] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Loop => loop_ids.push(node_id)
      _ => ()
    }
  }
  @debug.assert_eq(loop_ids.length(), 3)
  let state = FlattenRewriteState::new(func)
  for index in [2, 0, 1] {
    assert_true(
      flatten_inputful_loop_is_supported(
        func,
        loop_ids[index],
        state=Some(state),
      ),
    )
  }
  @debug.assert_eq(
    state.inputful_loop_support_entries.map(fn(entry) { entry.loop_id }),
    loop_ids,
  )
}

///|
test "flatten rewrite tuple loop entry proof uses pre-mutation ownership counts" {
  let result_types = [@lib.ValType::i32(), @lib.ValType::i64()]
  let func = pass_test_lift_first_func(
    "(module (type $carrier (func (param i32 i64) (result i32))) (func call 1 loop (type $carrier) drop drop i32.const 7 end drop) (func (result i32 i64) i32.const 5 i64.const 6))",
  )
  let loop_id = @ir.hot_child_get(func, @ir.hot_root_get(func, 0), 0)
  let old_entry = @ir.hot_child_get(func, loop_id, 0)
  let first = @ir.hot_build_const_i32(func, @lib.I32(11))
  let second = @ir.hot_build_const_i64(func, @lib.I64(13L))
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [first, second])
  @ir.hot_child_set(func, loop_id, 0, tuple_id)
  @ir.hot_child_set(func, loop_id, 1, tuple_id)
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  for root_idx = 0; root_idx < 2; root_idx = root_idx + 1 {
    let drop_id = @ir.hot_region_get(func, body_ref, root_idx)
    @debug.assert_eq(@ir.hot_child_get(func, drop_id, 0), old_entry)
    @ir.hot_child_set(func, drop_id, 0, tuple_id)
  }
  @ir.hot_delete_node(func, old_entry)
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_inputful_loop_tuple_entry_values(
      func,
      loop_id,
      result_types,
      state=Some(state),
    )
    is Some(_),
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, tuple_id))
  assert_true(
    flatten_inputful_loop_tuple_entry_values(func, loop_id, result_types)
    is None,
  )
  state.rewrites_started = true
  assert_true(
    flatten_rewrite_inputful_loop_tuple_entry_values(
      func, state, loop_id, result_types,
    )
    is Some(_),
  )
}

///|
test "flatten rewrite tuple branch payload proof uses pre-mutation ownership counts" {
  let result_types = [@lib.ValType::i32(), @lib.ValType::i64()]
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i64(func, @lib.I64(9L)),
  ])
  let branch_id = @ir.hot_build_br(
    func,
    @ir.hot_control_node_label(func, block_id),
    values=[tuple_id, tuple_id],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block_id), [
    branch_id,
  ])
  @ir.hot_root_append(func, block_id)
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_multivalue_tuple_branch_payload_values(
      func,
      branch_id,
      result_types.length(),
      result_types,
      state=Some(state),
    )
    is Some(_),
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, tuple_id))
  assert_true(
    flatten_multivalue_tuple_branch_payload_values(
      func,
      branch_id,
      result_types.length(),
      result_types,
    )
    is None,
  )
  state.rewrites_started = true
  assert_true(
    flatten_rewrite_multivalue_tuple_branch_payload_values(
      func,
      state,
      branch_id,
      result_types.length(),
      result_types,
    )
    is Some(_),
  )
}

///|
test "flatten rewrite tuple br_if flow uses pre-mutation exact site cache" {
  let result_types = [@lib.ValType::i32(), @lib.ValType::i64()]
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  @ir.hot_control_result_type_set(
    func,
    block_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
    @ir.hot_build_const_i32(func, @lib.I32(7)),
    @ir.hot_build_const_i64(func, @lib.I64(9L)),
  ])
  let branch_id = @ir.hot_build_br_if(
    func,
    @ir.hot_control_node_label(func, block_id),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[tuple_id, tuple_id],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block_id), [
    branch_id, tuple_id, tuple_id,
  ])
  @ir.hot_root_append(func, block_id)
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_multivalue_tuple_br_if_flow(
      func,
      branch_id,
      result_types.length(),
      result_types,
      state=Some(state),
    )
    is Some(_),
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, tuple_id))
  assert_true(
    flatten_multivalue_tuple_br_if_flow(
      func,
      branch_id,
      result_types.length(),
      result_types,
    )
    is None,
  )
  state.rewrites_started = true
  assert_true(
    flatten_rewrite_multivalue_tuple_br_if_flow(
      func,
      state,
      branch_id,
      result_types.length(),
      result_types,
    )
    is Some(_),
  )
}

///|
test "flatten rewrite multivalue br_if flow uses pre-mutation exact site cache" {
  let result_types = [@lib.ValType::i32(), @lib.ValType::i64()]
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  @ir.hot_control_result_type_set(
    func,
    block_id,
    @ir.hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      result_types,
    ),
  )
  let first = @ir.hot_build_const_i32(func, @lib.I32(7))
  let second = @ir.hot_build_const_i64(func, @lib.I64(9L))
  let branch_id = @ir.hot_build_br_if(
    func,
    @ir.hot_control_node_label(func, block_id),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[first, second],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block_id), [
    branch_id, first, second,
  ])
  @ir.hot_root_append(func, block_id)
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_multivalue_br_if_flow_span(
      func,
      branch_id,
      result_types.length(),
      state=Some(state),
    )
    is Some(_),
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, first))
  assert_true(
    flatten_multivalue_br_if_flow_span(func, branch_id, result_types.length())
    is None,
  )
  state.rewrites_started = true
  assert_true(
    flatten_rewrite_multivalue_br_if_flow_span(
      func,
      state,
      branch_id,
      result_types.length(),
    )
    is Some(_),
  )
}

///|
test "flatten conditional proof caches allocate only admitted entries" {
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  @ir.hot_control_result_type_set(
    func,
    block_id,
    @ir.hot_type_intern_results(func, [@lib.ValType::i32()]),
  )
  let value_id = @ir.hot_build_const_i32(func, @lib.I32(7))
  let branch_id = @ir.hot_build_br_if(
    func,
    @ir.hot_control_node_label(func, block_id),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[value_id],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block_id), [
    branch_id, value_id,
  ])
  for i = 0; i < 256; i = i + 1 {
    @ir.hot_root_append(func, @ir.hot_build_nop(func))
  }
  @ir.hot_root_append(func, block_id)
  let state = FlattenRewriteState::new(func)
  @debug.assert_eq(state.tuple_br_if_flow_entries.length(), 0)
  @debug.assert_eq(state.multivalue_br_if_flow_entries.length(), 0)
  @debug.assert_eq(state.scalar_br_if_flow_entries.length(), 0)
  @debug.assert_eq(state.scalar_flow_replacement_entries.length(), 0)
  assert_true(
    flatten_scalar_br_if_flow_sites(
      func,
      branch_id,
      value_id,
      state=Some(state),
    )
    is Some(_),
  )
  @debug.assert_eq(state.scalar_br_if_flow_entries.length(), 1)
  state.rewrites_started = true
  let local_id = @ir.hot_append_body_local(func, @lib.ValType::i32())
  assert_true(
    flatten_replace_cached_flowing_value_uses(
      func, state, branch_id, value_id, local_id,
    ),
  )
  @debug.assert_eq(state.scalar_flow_replacement_entries.length(), 1)
}

///|
test "flatten multivalue conditional proof cache keeps sparse entries sorted" {
  let result_types = [@lib.ValType::i32(), @lib.ValType::i64()]
  let func = @ir.HotFunc::new()
  let branch_ids : Array[Int] = []
  for candidate = 0; candidate < 3; candidate = candidate + 1 {
    let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
    @ir.hot_control_result_type_set(
      func,
      block_id,
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        [],
        result_types,
      ),
    )
    let first = @ir.hot_build_const_i32(func, @lib.I32(candidate))
    let second = @ir.hot_build_const_i64(func, @lib.I64(candidate.to_int64()))
    let branch_id = @ir.hot_build_br_if(
      func,
      @ir.hot_control_node_label(func, block_id),
      @ir.hot_build_const_i32(func, @lib.I32(0)),
      values=[first, second],
    )
    branch_ids.push(branch_id)
    @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block_id), [
      branch_id, first, second,
    ])
    @ir.hot_root_append(func, block_id)
  }
  let state = FlattenRewriteState::new(func)
  for index in [2, 0, 1] {
    assert_true(
      flatten_multivalue_br_if_flow_span(
        func,
        branch_ids[index],
        result_types.length(),
        state=Some(state),
      )
      is Some(_),
    )
  }
  @debug.assert_eq(
    state.multivalue_br_if_flow_entries.map(fn(entry) { entry.branch_id }),
    branch_ids,
  )
  state.rewrites_started = true
  for branch_id in branch_ids {
    assert_true(
      flatten_rewrite_multivalue_br_if_flow_span(
        func,
        state,
        branch_id,
        result_types.length(),
      )
      is Some(_),
    )
  }
}

///|
test "flatten tuple conditional proof cache keeps sparse entries sorted" {
  let result_types = [@lib.ValType::i32(), @lib.ValType::i64()]
  let func = @ir.HotFunc::new()
  let branch_ids : Array[Int] = []
  for candidate = 0; candidate < 3; candidate = candidate + 1 {
    let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
    @ir.hot_control_result_type_set(
      func,
      block_id,
      @ir.hot_type_intern_resolved_block_result(
        func,
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        [],
        result_types,
      ),
    )
    let tuple_id = @ir.hot_build_tuple_make(func, result_types, [
      @ir.hot_build_const_i32(func, @lib.I32(candidate)),
      @ir.hot_build_const_i64(func, @lib.I64(candidate.to_int64())),
    ])
    let branch_id = @ir.hot_build_br_if(
      func,
      @ir.hot_control_node_label(func, block_id),
      @ir.hot_build_const_i32(func, @lib.I32(0)),
      values=[tuple_id, tuple_id],
    )
    branch_ids.push(branch_id)
    @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block_id), [
      branch_id, tuple_id, tuple_id,
    ])
    @ir.hot_root_append(func, block_id)
  }
  let state = FlattenRewriteState::new(func)
  for index in [2, 0, 1] {
    assert_true(
      flatten_multivalue_tuple_br_if_flow(
        func,
        branch_ids[index],
        result_types.length(),
        result_types,
        state=Some(state),
      )
      is Some(_),
    )
  }
  @debug.assert_eq(
    state.tuple_br_if_flow_entries.map(fn(entry) { entry.branch_id }),
    branch_ids,
  )
  state.rewrites_started = true
  for branch_id in branch_ids {
    assert_true(
      flatten_rewrite_multivalue_tuple_br_if_flow(
        func,
        state,
        branch_id,
        result_types.length(),
        result_types,
      )
      is Some(_),
    )
  }
}

///|
test "flatten scalar conditional proof caches keep sparse entries sorted" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (drop (block (result i32) i32.const 7 local.get 0 br_if 0 drop i32.const 9)) (drop (block (result i32) i32.const 11 local.get 0 br_if 0 drop i32.const 13)) (drop (block (result i32) i32.const 15 local.get 0 br_if 0 drop i32.const 17))))",
  )
  let branch_ids : Array[Int] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::BrIf => branch_ids.push(node_id)
      _ => ()
    }
  }
  @debug.assert_eq(branch_ids.length(), 3)
  let state = FlattenRewriteState::new(func)
  for index in [2, 0, 1] {
    let branch_id = branch_ids[index]
    assert_true(
      flatten_scalar_br_if_flow_sites(
        func,
        branch_id,
        @ir.hot_child_get(func, branch_id, 0),
        state=Some(state),
      )
      is Some(_),
    )
  }
  @debug.assert_eq(
    state.scalar_br_if_flow_entries.map(fn(entry) { entry.branch_id }),
    branch_ids,
  )
  state.rewrites_started = true
  let value_ids = branch_ids.map(fn(branch_id) {
    @ir.hot_child_get(func, branch_id, 0)
  })
  for index in [2, 0, 1] {
    assert_true(
      flatten_replace_cached_flowing_value_uses(
        func,
        state,
        branch_ids[index],
        value_ids[index],
        @ir.hot_append_body_local(func, @lib.ValType::i32()),
      ),
    )
  }
  @debug.assert_eq(
    state.scalar_flow_replacement_entries.map(fn(entry) { entry.value_id }),
    value_ids,
  )
}

///|
test "flatten rewrite scalar br_if flow uses pre-mutation exact site cache" {
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  @ir.hot_control_result_type_set(
    func,
    block_id,
    @ir.hot_type_intern_results(func, [@lib.ValType::i32()]),
  )
  let value_id = @ir.hot_build_const_i32(func, @lib.I32(7))
  let branch_id = @ir.hot_build_br_if(
    func,
    @ir.hot_control_node_label(func, block_id),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[value_id],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block_id), [
    branch_id, value_id,
  ])
  @ir.hot_root_append(func, block_id)
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_scalar_br_if_flow_sites(
      func,
      branch_id,
      value_id,
      state=Some(state),
    )
    is Some(_),
  )
  let extra_drop = @ir.hot_build_drop(func, value_id)
  @ir.hot_root_append(func, extra_drop)
  state.rewrites_started = true
  let local_id = @ir.hot_append_body_local(func, @lib.ValType::i32())
  assert_true(
    flatten_replace_cached_flowing_value_uses(
      func, state, branch_id, value_id, local_id,
    ),
  )
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_region_get(func, body_ref, 1)).op.to_string(),
    "LocalGet",
  )
  @debug.assert_eq(@ir.hot_child_get(func, extra_drop, 0), value_id)
}

///|
test "flatten rewrite scalar try flow uses pre-mutation ownership counts" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let value_id = @ir.hot_build_const_i32(func, @lib.I32(7))
  let branch_id = @ir.hot_build_br_if(
    func,
    @ir.hot_control_node_label(func, try_id),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[value_id],
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    branch_id,
    @ir.hot_build_drop(func, value_id),
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  ])
  @ir.hot_root_append(func, try_id)
  let state = FlattenRewriteState::new(func)
  assert_true(
    flatten_scalar_try_br_if_flow_is_exact(
      func,
      try_id,
      branch_id,
      value_id,
      state=Some(state),
    ),
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, value_id))
  assert_false(
    flatten_scalar_try_br_if_flow_is_exact(func, try_id, branch_id, value_id),
  )
  state.rewrites_started = true
  assert_true(
    flatten_rewrite_scalar_try_br_if_flow_is_exact(
      func, state, try_id, branch_id, value_id,
    ),
  )
}

///|
test "flatten postorder branch routing admits only carried br nodes" {
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let label_id = @ir.hot_control_node_label(func, block_id)
  let payload = @ir.hot_build_const_i32(func, @lib.I32(7))
  let carried_br = @ir.hot_build_br(func, label_id, values=[payload])
  let payloadless_br = @ir.hot_build_br(func, label_id)
  let carried_br_if = @ir.hot_build_br_if(
    func,
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[payload],
  )
  let table_id = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[payload],
  )
  assert_true(flatten_node_needs_postorder_branch_routing(func, carried_br))
  assert_false(
    flatten_node_needs_postorder_branch_routing(func, payloadless_br),
  )
  assert_false(flatten_node_needs_postorder_branch_routing(func, carried_br_if))
  assert_false(flatten_node_needs_postorder_branch_routing(func, table_id))
  assert_false(
    flatten_node_needs_postorder_branch_routing(func, @ir.hot_build_nop(func)),
  )
}

///|
test "flatten sequenced roots track only pre-mutation shared nodes" {
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let label_id = @ir.hot_control_node_label(func, block_id)
  let branch_id = @ir.hot_build_br(func, label_id, values=[
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  ])
  let roots : Array[Int] = []
  for i = 0; i < 256; i = i + 1 {
    roots.push(@ir.hot_build_nop(func))
  }
  let unique_root = roots[0]
  roots.push(branch_id)
  let select_id = @ir.hot_build_select(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    branch_id,
  )
  roots.push(select_id)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  @ir.hot_region_replace_body(func, body_ref, roots)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, block_id))
  let state = FlattenRewriteState::new(func)
  assert_false(flatten_root_needs_sequence_tracking(state, unique_root))
  assert_true(flatten_root_needs_sequence_tracking(state, branch_id))
  let post_snapshot_root = @ir.hot_build_nop(func)
  assert_false(flatten_root_needs_sequence_tracking(state, post_snapshot_root))
  match
    flatten_run_admission(func, flatten_classify_hot(func), state=Some(state)) {
    FlattenRunAdmission::Admitted => ()
    _ => fail("expected the shared-root fixture to be admitted")
  }
  state.rewrites_started = true
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::final_module_only(),
    false,
    fn(_) { () },
  )
  assert_true(flatten_rewrite_region_operands(ctx, func, state, body_ref))
  @debug.assert_eq(state.sequenced_root_holders, [body_ref.holder])
  @debug.assert_eq(state.sequenced_root_nodes, [branch_id])
  @debug.assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, select_id, 2)).op.to_string(),
    "Unreachable",
  )
}

///|
test "flatten sequenced root cache keeps sparse pairs sorted" {
  let holders : Array[Int] = []
  let nodes : Array[Int] = []
  assert_true(flatten_sequenced_root_record(holders, nodes, 4, 19))
  assert_true(flatten_sequenced_root_record(holders, nodes, 1, 12))
  assert_true(flatten_sequenced_root_record(holders, nodes, 4, 3))
  assert_false(flatten_sequenced_root_record(holders, nodes, 4, 19))
  @debug.assert_eq(holders, [1, 4, 4])
  @debug.assert_eq(nodes, [12, 3, 19])
  assert_true(flatten_sequenced_root_contains(holders, nodes, 1, 12))
  assert_true(flatten_sequenced_root_contains(holders, nodes, 4, 3))
  assert_true(flatten_sequenced_root_contains(holders, nodes, 4, 19))
  assert_false(flatten_sequenced_root_contains(holders, nodes, 1, 19))
  assert_false(flatten_sequenced_root_contains(holders, nodes, 4, 12))
}

///|
test "flatten multivalue flow payload marks preserve exact distinct ids" {
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let label_id = @ir.hot_control_node_label(func, block_id)
  let first = @ir.hot_build_const_i32(func, @lib.I32(7))
  let second = @ir.hot_build_const_i64(func, @lib.I64(9L))
  let distinct = @ir.hot_build_br_if(
    func,
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[first, second],
  )
  let distinct_seen = @bitset.BitSet::new(@ir.hot_node_count(func))
  @debug.assert_eq(
    flatten_collect_distinct_branch_payloads(func, distinct, 2, distinct_seen),
    Some([first, second]),
  )
  assert_true(distinct_seen[first])
  assert_true(distinct_seen[second])
  let duplicate = @ir.hot_build_br_if(
    func,
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[first, first],
  )
  let duplicate_seen = @bitset.BitSet::new(@ir.hot_node_count(func))
  assert_true(
    flatten_collect_distinct_branch_payloads(func, duplicate, 2, duplicate_seen)
    is None,
  )
}

///|
test "flatten multivalue flow payload slots preserve exact source positions" {
  let func = @ir.HotFunc::new()
  let block_id = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let label_id = @ir.hot_control_node_label(func, block_id)
  let first = @ir.hot_build_const_i32(func, @lib.I32(7))
  ignore(@ir.hot_build_nop(func))
  let second = @ir.hot_build_const_i64(func, @lib.I64(9L))
  let distinct = @ir.hot_build_br_if(
    func,
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[first, second],
  )
  let distinct_slots = Array::make(@ir.hot_node_count(func), -1)
  @debug.assert_eq(
    flatten_collect_distinct_branch_payload_slots(
      func, distinct, 2, distinct_slots,
    ),
    Some([first, second]),
  )
  @debug.assert_eq(distinct_slots[first], 0)
  @debug.assert_eq(distinct_slots[second], 1)
  @debug.assert_eq(distinct_slots[first + 1], -1)
  let duplicate = @ir.hot_build_br_if(
    func,
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[first, first],
  )
  assert_true(
    flatten_collect_distinct_branch_payload_slots(
      func,
      duplicate,
      2,
      Array::make(@ir.hot_node_count(func), -1),
    )
    is None,
  )
}

///|
test "flatten unique table target marks preserve first source order" {
  let targets : Array[Int] = []
  let seen = @bitset.BitSet::new(8)
  assert_true(flatten_record_unique_br_table_target(targets, seen, 5))
  assert_false(flatten_record_unique_br_table_target(targets, seen, 5))
  assert_true(flatten_record_unique_br_table_target(targets, seen, 2))
  assert_true(flatten_record_unique_br_table_target(targets, seen, 7))
  assert_false(flatten_record_unique_br_table_target(targets, seen, 2))
  assert_false(flatten_record_unique_br_table_target(targets, seen, -1))
  assert_false(flatten_record_unique_br_table_target(targets, seen, 8))
  @debug.assert_eq(targets, [5, 2, 7])
  assert_true(seen[5])
  assert_true(seen[2])
  assert_true(seen[7])
}

///|
test "flatten tuple flow slot marks preserve exact first positions" {
  let slots : Array[Int] = []
  let seen = Array::make(8, false)
  assert_true(flatten_record_distinct_flow_slot(slots, seen, 5))
  assert_true(flatten_record_distinct_flow_slot(slots, seen, 2))
  assert_false(flatten_record_distinct_flow_slot(slots, seen, 5))
  assert_true(flatten_record_distinct_flow_slot(slots, seen, 7))
  assert_false(flatten_record_distinct_flow_slot(slots, seen, -1))
  assert_false(flatten_record_distinct_flow_slot(slots, seen, 8))
  @debug.assert_eq(slots, [5, 2, 7])
  assert_true(seen[5])
  assert_true(seen[2])
  assert_true(seen[7])
  assert_false(seen[4])
}

///|
test "flatten terminal payload cache keeps sparse entries sorted" {
  let payloads : Array[Int] = []
  assert_true(flatten_terminal_payload_record(payloads, 19))
  assert_true(flatten_terminal_payload_record(payloads, 4))
  assert_true(flatten_terminal_payload_record(payloads, 12))
  assert_false(flatten_terminal_payload_record(payloads, 4))
  @debug.assert_eq(payloads, [4, 12, 19])
  assert_true(flatten_terminal_payload_contains(payloads, 4))
  assert_true(flatten_terminal_payload_contains(payloads, 12))
  assert_true(flatten_terminal_payload_contains(payloads, 19))
  assert_false(flatten_terminal_payload_contains(payloads, 7))
}

///|
test "flatten freezes unique br_table targets in one sparse pre-mutation pool" {
  let func = @ir.HotFunc::new()
  let first = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    @ir.hot_build_nop(func),
  ])
  let second = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    @ir.hot_build_nop(func),
  ])
  let first_label = @ir.hot_control_node_label(func, first)
  let second_label = @ir.hot_control_node_label(func, second)
  let table = @ir.hot_build_br_table(
    func,
    [second_label, first_label, second_label],
    first_label,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
  )
  @ir.hot_root_append(func, table)
  let table_side_id = @ir.hot_node_get(func, table).imm0
  let state = FlattenRewriteState::new(func)
  @debug.assert_eq(state.br_table_target_entries.length(), 1)
  @debug.assert_eq(state.br_table_targets, [second_label, first_label])
  let view = flatten_br_table_targets(func, table_side_id, state=Some(state)).unwrap()
  @debug.assert_eq(view.start, 0)
  @debug.assert_eq(view.count, 2)
  @debug.assert_eq(view.targets[view.start], second_label)
  @debug.assert_eq(view.targets[view.start + 1], first_label)

  state.rewrites_started = true
  let late_table = @ir.hot_build_br_table(
    func,
    [first_label],
    first_label,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  assert_true(
    flatten_br_table_targets(
      func,
      @ir.hot_node_get(func, late_table).imm0,
      state=Some(state),
    )
    is None,
  )
}

///|
test "flatten reuses frozen structural parents and generation marks" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([@ir.hot_build_nop(func)]),
  )
  let block_id = @ir.hot_build_block(func, @lib.BlockType::void_(), [try_id])
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [block_id],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  @ir.hot_root_append(func, if_id)
  let state = FlattenRewriteState::new(func)
  assert_false(state.direct_parent_built)
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(
      func,
      try_id,
      [if_id, block_id],
      state=Some(state),
    ),
    Some([block_id, if_id]),
  )
  assert_true(state.direct_parent_built)
  @debug.assert_eq(state.direct_parent[try_id], block_id)
  @debug.assert_eq(state.direct_parent[block_id], if_id)
  let first_epoch = state.next_node_mark
  @debug.assert_eq(
    flatten_direct_enclosing_target_controls(
      func,
      try_id,
      [block_id, if_id],
      state=Some(state),
    ),
    Some([block_id, if_id]),
  )
  assert_true(state.next_node_mark > first_epoch)

  let late_state = FlattenRewriteState::new(func)
  late_state.rewrites_started = true
  assert_true(
    flatten_direct_enclosing_target_controls(
      func,
      try_id,
      [block_id, if_id],
      state=Some(late_state),
    )
    is None,
  )
  assert_false(late_state.direct_parent_built)
}

///|
test "flatten reuses one prelude buffer per active region depth" {
  let func = @ir.HotFunc::new()
  let inner_roots : Array[Int] = []
  for idx = 0; idx < 128; idx = idx + 1 {
    inner_roots.push(@ir.hot_build_nop(func))
  }
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), inner_roots)
  let outer_roots : Array[Int] = [inner]
  for idx = 0; idx < 128; idx = idx + 1 {
    outer_roots.push(@ir.hot_build_nop(func))
  }
  let outer = @ir.hot_build_block(func, @lib.BlockType::void_(), outer_roots)
  @ir.hot_root_append(func, outer)
  let state = FlattenRewriteState::new(func)
  state.rewrites_started = true
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::final_module_only(),
    false,
    fn(_) { () },
  )
  assert_false(
    flatten_rewrite_region_operands(
      ctx,
      func,
      state,
      @ir.hot_region_body_ref(func, outer),
    ),
  )
  @debug.assert_eq(state.prelude_buffers.length(), 2)
  @debug.assert_eq(state.prelude_depth, 0)
}

///|
test "flatten caches repeated type result queries once per type" {
  let func = @ir.HotFunc::new()
  let type_id = @ir.hot_type_intern_results(func, [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ])
  let state = FlattenRewriteState::new(func)
  @debug.assert_eq(state.type_result_cache.length(), 0)
  @debug.assert_eq(flatten_type_results(func, type_id, state=Some(state)), [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ])
  assert_true(state.type_result_cache.length() > type_id)
  assert_true(state.type_result_cache[type_id] is Some(_))
  let cache_length = state.type_result_cache.length()
  @debug.assert_eq(flatten_type_results(func, type_id, state=Some(state)), [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ])
  @debug.assert_eq(state.type_result_cache.length(), cache_length)
}

///|
test "flatten prepares table target locals without an outer resolved vector" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32 i64) (block (result i32 i64) (block (result i32 i64) (br_table 0 1 (i32.const 7) (i64.const 9) (i32.const 0)))) return))",
  )
  let return_id = @ir.hot_root_get(func, 0)
  let outer_id = @ir.hot_child_get(func, return_id, 0)
  let inner_id = @ir.hot_region_get(
    func,
    @ir.hot_region_body_ref(func, outer_id),
    0,
  )
  let targets = [
    @ir.hot_control_node_label(func, inner_id),
    @ir.hot_control_node_label(func, outer_id),
  ]
  let target_types = @ir.hot_type_results(
    func,
    @ir.hot_label_result_type(func, targets[0]),
  )
  let state = FlattenRewriteState::new(func)
  state.rewrites_started = true
  let target_view = FlattenBrTableTargets::new(targets, 0, targets.length())
  let local_count = @ir.hot_local_count(func)
  assert_true(
    flatten_prepare_br_table_target_locals(
      func, state, target_view, target_types,
    ),
  )
  @debug.assert_eq(@ir.hot_local_count(func), local_count + 4)
  @debug.assert_eq(state.label_temps[targets[0]].length(), 2)
  @debug.assert_eq(state.label_temps[targets[1]].length(), 2)
  assert_true(
    flatten_prepare_br_table_target_locals(
      func, state, target_view, target_types,
    ),
  )
  @debug.assert_eq(@ir.hot_local_count(func), local_count + 4)
}
