///|
fn gen_valid_ssa_test_module(
  accepts : Array[ValType],
  locals : Array[ValType],
  body : Array[Instruction],
) -> Module {
  let func = Func::new(Locals::from_types(locals), Expr::new(body))
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func(accepts, [])))]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_code_sec(CodeSec::new([func]))
}

///|
test "ssa scanner detects if-join phi candidate" {
  let mod_ = gen_valid_ssa_test_module([], [ValType::i32()], [
    Instruction::i32_const(I32(0)),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::i32_const(I32(1)),
        Instruction::local_set(LocalIdx::new(0U)),
      ],
      Some([
        Instruction::i32_const(I32(2)),
        Instruction::local_set(LocalIdx::new(0U)),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_if_join_phi_candidate)
}

///|
test "ssa scanner detects loop backedge phi candidate" {
  let mod_ = gen_valid_ssa_test_module([], [ValType::i32()], [
    Instruction::i32_const(I32(0)),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::loop_(
          BlockType::void_(),
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::drop(),
            Instruction::i32_const(I32(1)),
            Instruction::local_set(LocalIdx::new(0U)),
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::br_if(LabelIdx::new(0U)),
          ]),
        ),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_loop_backedge_phi_candidate)
}

///|
test "ssa scanner detects typed loop-param fail-closed shape" {
  let mod_ = gen_valid_ssa_test_module([ValType::i32()], [ValType::i32()], [
    Instruction::i32_const(I32(0)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::loop_(
      BlockType::type_idx(TypeIdx::new(0U)),
      Expr::new([
        Instruction::drop(),
        Instruction::i32_const(I32(1)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
        Instruction::br(LabelIdx::new(0U)),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_typed_loop_param_fail_closed_shape)
  assert_true(facts.has_ssa_loop_backedge_phi_candidate)
}

///|
test "ssa scanner detects exceptional fail-closed shape" {
  let mod_ = gen_valid_ssa_test_module([], [ValType::i32()], [
    Instruction::try_table(
      BlockType::void_(),
      [Catch::all(LabelIdx::new(0U))],
      Expr::new([
        Instruction::i32_const(I32(7)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::ref_null(HeapType::abs(AbsHeapType::exn())),
        Instruction::throw_ref(),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_exceptional_fail_closed_shape)
}

///|
test "ssa scanner detects dropped increment guarded shape" {
  let mod_ = gen_valid_ssa_test_module([], [ValType::i32()], [
    Instruction::i32_const(I32(10)),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::i32_const(I32(1)),
    Instruction::i32_add(),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_dropped_increment_guard_shape)
}

///|
test "ssa scanner detects reversed dropped increment boundary" {
  let mod_ = gen_valid_ssa_test_module([], [ValType::i32()], [
    Instruction::i32_const(I32(10)),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::i32_const(I32(1)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::i32_add(),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_dropped_increment_reversed_boundary)
}

///|
test "ssa scanner detects nested CFG fail-closed shape" {
  let mod_ = gen_valid_ssa_test_module([], [ValType::i32()], [
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i32_const(I32(7)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ]),
    ),
    Instruction::drop(),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_nested_cfg_fail_closed_shape)
}

///|
test "ssa scanner detects parallel copy candidate" {
  let mod_ = gen_valid_ssa_test_module([], [ValType::i32(), ValType::i32()], [
    Instruction::i32_const(I32(1)),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::i32_const(I32(2)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::local_get(LocalIdx::new(1U)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::local_set(LocalIdx::new(1U)),
      ],
      Some([
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
        Instruction::local_set(LocalIdx::new(0U)),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::drop(),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_parallel_copy_candidate)
}

///|
fn gen_valid_ssa_nested_result_if_i32_slice(
  condition : Array[Instruction],
  then_body : Array[Instruction],
  else_body : Array[Instruction],
  tail : Array[Instruction],
) -> Array[Instruction] {
  let out = condition
  out.push(
    Instruction::if_(
      BlockType::val_type(ValType::i32()),
      then_body,
      Some(else_body),
    ),
  )
  out.push(Instruction::drop())
  for instr in tail {
    out.push(instr)
  }
  out
}

///|
test "ssa scanner detects nested result-if supported shape" {
  let mod_ = gen_valid_ssa_test_module(
    [ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_nested_result_if_i32_slice(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::i32_const(I32(7)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
      [Instruction::local_get(LocalIdx::new(1U)), Instruction::drop()],
    ),
  )
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_nested_result_if_supported_shape)
  assert_false(facts.has_ssa_nested_cfg_fail_closed_shape)
  assert_false(facts.has_ssa_nested_result_if_condition_write)
  assert_false(facts.has_ssa_nested_result_if_condition_value_block)
  assert_false(facts.has_ssa_nested_result_if_arm_value_block)
  assert_false(facts.has_ssa_nested_result_if_mixed_arm_value_block)
  assert_false(facts.has_ssa_nested_result_if_scalar_result)
}

///|
test "ssa scanner detects nested result-if condition write" {
  let mod_ = gen_valid_ssa_test_module(
    [],
    [ValType::i32()],
    gen_valid_ssa_nested_result_if_i32_slice(
      [
        Instruction::i32_const(I32(1)),
        Instruction::local_tee(LocalIdx::new(0U)),
      ],
      [
        Instruction::i32_const(I32(7)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ],
      [Instruction::local_get(LocalIdx::new(0U)), Instruction::drop()],
    ),
  )
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_nested_result_if_supported_shape)
  assert_true(facts.has_ssa_nested_result_if_condition_write)
  assert_false(facts.has_ssa_nested_result_if_condition_value_block)
}

///|
test "ssa scanner detects nested result-if condition value-block" {
  let mod_ = gen_valid_ssa_test_module(
    [],
    [ValType::i32()],
    gen_valid_ssa_nested_result_if_i32_slice(
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::local_set(LocalIdx::new(0U)),
            Instruction::local_get(LocalIdx::new(0U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(7)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ],
      [Instruction::local_get(LocalIdx::new(0U)), Instruction::drop()],
    ),
  )
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_nested_result_if_condition_value_block)
  assert_false(facts.has_ssa_nested_result_if_condition_write)
}

///|
test "ssa scanner detects nested result-if arm value-block" {
  let mod_ = gen_valid_ssa_test_module(
    [ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_nested_result_if_i32_slice(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
      ],
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(9)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
      ],
      [Instruction::local_get(LocalIdx::new(1U)), Instruction::drop()],
    ),
  )
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_nested_result_if_arm_value_block)
  assert_false(facts.has_ssa_nested_result_if_mixed_arm_value_block)
}

///|
test "ssa scanner detects nested result-if mixed arm value-block" {
  let mod_ = gen_valid_ssa_test_module(
    [ValType::i32()],
    [ValType::i32(), ValType::i32()],
    gen_valid_ssa_nested_result_if_i32_slice(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::i32_const(I32(1)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::local_set(LocalIdx::new(2U)),
            Instruction::local_get(LocalIdx::new(2U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(2)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(9)),
            Instruction::local_set(LocalIdx::new(2U)),
            Instruction::local_get(LocalIdx::new(2U)),
          ]),
        ),
      ],
      [
        Instruction::local_get(LocalIdx::new(1U)),
        Instruction::drop(),
        Instruction::local_get(LocalIdx::new(2U)),
        Instruction::drop(),
      ],
    ),
  )
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_nested_result_if_mixed_arm_value_block)
  assert_false(facts.has_ssa_nested_result_if_arm_value_block)
}

///|
fn gen_valid_ssa_assert_nested_result_if_scalar_variant(
  result_vt : ValType,
  then_const : Instruction,
  else_const : Instruction,
) -> Unit raise {
  let local_idx = LocalIdx::new(0U)
  let mod_ = gen_valid_ssa_test_module([], [result_vt], [
    Instruction::i32_const(I32(1)),
    Instruction::if_(
      BlockType::val_type(result_vt),
      [
        then_const,
        Instruction::local_set(local_idx),
        Instruction::local_get(local_idx),
      ],
      Some([
        else_const,
        Instruction::local_set(local_idx),
        Instruction::local_get(local_idx),
      ]),
    ),
    Instruction::drop(),
    Instruction::local_get(local_idx),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_nested_result_if_supported_shape)
  assert_true(facts.has_ssa_nested_result_if_scalar_result)
}

///|
test "ssa scanner detects nested result-if scalar result variants" {
  gen_valid_ssa_assert_nested_result_if_scalar_variant(
    ValType::i64(),
    Instruction::i64_const(I64(7L)),
    Instruction::i64_const(I64(9L)),
  )
  gen_valid_ssa_assert_nested_result_if_scalar_variant(
    ValType::f32(),
    Instruction::f32_const(F32(7.0)),
    Instruction::f32_const(F32(9.0)),
  )
  gen_valid_ssa_assert_nested_result_if_scalar_variant(
    ValType::f64(),
    Instruction::f64_const(F64(7.0)),
    Instruction::f64_const(F64(9.0)),
  )
}

///|
test "ssa straight-line local chain is not nested result-if supported shape" {
  let mod_ = gen_valid_ssa_test_module([], [ValType::i32()], [
    Instruction::i32_const(I32(1)),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_straight_line_local_chain)
  assert_false(facts.has_ssa_nested_result_if_supported_shape)
}

///|
test "ssa nested CFG fail-closed shape stays distinct from supported result-if" {
  let mod_ = gen_valid_ssa_test_module([], [ValType::i32()], [
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i32_const(I32(7)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ]),
    ),
    Instruction::drop(),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_nested_cfg_fail_closed_shape)
  assert_false(facts.has_ssa_nested_result_if_supported_shape)
}

///|
fn gen_valid_ssa_assert_unsupported_nested_result_if(
  accepts : Array[ValType],
  locals : Array[ValType],
  body : Array[Instruction],
) -> Unit raise {
  let mod_ = gen_valid_ssa_test_module(accepts, locals, body)
  let facts = gen_valid_feature_facts(mod_, CoverageForced)

  assert_false(
    facts.has_ssa_nested_result_if_supported_shape,
    msg="unsupported dropped result-if must not scan as supported",
  )
}

///|
fn gen_valid_ssa_unsupported_drop_result_if_body(
  condition : Array[Instruction],
  then_body : Array[Instruction],
  else_body : Array[Instruction],
) -> Array[Instruction] {
  let out = condition
  out.push(
    Instruction::if_(
      BlockType::val_type(ValType::i32()),
      then_body,
      Some(else_body),
    ),
  )
  out.push(Instruction::drop())
  out.push(Instruction::local_get(LocalIdx::new(1U)))
  out.push(Instruction::drop())
  out
}

///|
test "ssa scanner rejects dropped result-if with branch in arm value-block" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::block(
              BlockType::void_(),
              Expr::new([Instruction::br(LabelIdx::new(0U))]),
            ),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with br_if in arm value-block" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::block(
              BlockType::void_(),
              Expr::new([
                Instruction::i32_const(I32(0)),
                Instruction::br_if(LabelIdx::new(0U)),
              ]),
            ),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with nested if in arm value-block" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [ValType::i32(), ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::local_get(LocalIdx::new(2U)),
            Instruction::if_(
              BlockType::void_(),
              [
                Instruction::i32_const(I32(7)),
                Instruction::local_set(LocalIdx::new(1U)),
              ],
              None,
            ),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with value-producing prefix root" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::i32_const(I32(111)),
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with two arm value-blocks" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([Instruction::i32_const(I32(7))]),
        ),
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(8)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with root after final arm value-block" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
        Instruction::drop(),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with branch in condition value-block" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::local_set(LocalIdx::new(0U)),
            Instruction::block(
              BlockType::void_(),
              Expr::new([Instruction::br(LabelIdx::new(0U))]),
            ),
            Instruction::local_get(LocalIdx::new(0U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(7)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with nested loop in arm value-block" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::loop_(
              BlockType::void_(),
              Expr::new([
                Instruction::local_get(LocalIdx::new(1U)),
                Instruction::br_if(LabelIdx::new(0U)),
              ]),
            ),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with nested block in arm value-block" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::block(
              BlockType::void_(),
              Expr::new([Instruction::i32_const(I32(0)), Instruction::drop()]),
            ),
            Instruction::i32_const(I32(7)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with br_if in condition value-block" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::local_set(LocalIdx::new(0U)),
            Instruction::block(
              BlockType::void_(),
              Expr::new([
                Instruction::i32_const(I32(0)),
                Instruction::br_if(LabelIdx::new(0U)),
              ]),
            ),
            Instruction::local_get(LocalIdx::new(0U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(7)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with nested if in condition value-block" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [
        Instruction::block(
          BlockType::val_type(ValType::i32()),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::local_set(LocalIdx::new(0U)),
            Instruction::if_(
              BlockType::void_(),
              [
                Instruction::i32_const(I32(1)),
                Instruction::local_set(LocalIdx::new(0U)),
              ],
              None,
            ),
            Instruction::local_get(LocalIdx::new(0U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(7)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(0U)),
        Instruction::local_get(LocalIdx::new(0U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with result type mismatch" {
  gen_valid_ssa_assert_unsupported_nested_result_if(
    [ValType::i32()],
    [ValType::i32()],
    gen_valid_ssa_unsupported_drop_result_if_body(
      [Instruction::local_get(LocalIdx::new(0U))],
      [
        Instruction::block(
          BlockType::val_type(ValType::f32()),
          Expr::new([
            Instruction::f32_const(F32(7.0)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::local_get(LocalIdx::new(1U)),
          ]),
        ),
      ],
      [
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
      ],
    ),
  )
}

///|
test "ssa scanner rejects dropped result-if with multi-value result" {
  let mod_ = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        RecType::new(
          SubType::comp_type(
            CompType::func([], [ValType::i32(), ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::if_(
              BlockType::type_idx(TypeIdx::new(1U)),
              [Instruction::i32_const(I32(7)), Instruction::i32_const(I32(8))],
              Some([
                Instruction::i32_const(I32(9)),
                Instruction::i32_const(I32(10)),
              ]),
            ),
            Instruction::drop(),
            Instruction::drop(),
          ]),
        ),
      ]),
    )
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_false(facts.has_ssa_nested_result_if_supported_shape)
  assert_false(facts.has_ssa_nested_result_if_arm_value_block)
  assert_false(facts.has_ssa_nested_result_if_mixed_arm_value_block)
  assert_false(facts.has_ssa_nested_result_if_condition_value_block)
}

///|
test "ssa coverage template slices scan as supported shapes" {
  // O. nested result-if straight-line arms (i32)
  {
    let mod_ = gen_valid_ssa_test_module([ValType::i32()], [ValType::i32()], [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(7)),
          Instruction::local_set(LocalIdx::new(1U)),
          Instruction::local_get(LocalIdx::new(1U)),
        ],
        Some([
          Instruction::i32_const(I32(9)),
          Instruction::local_set(LocalIdx::new(1U)),
          Instruction::local_get(LocalIdx::new(1U)),
        ]),
      ),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
    ])
    let facts = gen_valid_feature_facts(mod_, CoverageForced)
    assert_true(
      facts.has_ssa_nested_result_if_supported_shape,
      msg="template O should scan as supported nested result-if",
    )
    assert_false(facts.has_ssa_nested_result_if_condition_write)
    assert_false(facts.has_ssa_nested_result_if_condition_value_block)
    assert_false(facts.has_ssa_nested_result_if_arm_value_block)
    assert_false(facts.has_ssa_nested_result_if_mixed_arm_value_block)
    assert_false(facts.has_ssa_nested_result_if_scalar_result)
  }

  // S. nested result-if condition local write
  {
    let mod_ = gen_valid_ssa_test_module([], [ValType::i32()], [
      Instruction::i32_const(I32(1)),
      Instruction::local_tee(LocalIdx::new(0U)),
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(7)),
          Instruction::local_set(LocalIdx::new(0U)),
          Instruction::local_get(LocalIdx::new(0U)),
        ],
        Some([
          Instruction::i32_const(I32(9)),
          Instruction::local_set(LocalIdx::new(0U)),
          Instruction::local_get(LocalIdx::new(0U)),
        ]),
      ),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
    ])
    let facts = gen_valid_feature_facts(mod_, CoverageForced)
    assert_true(
      facts.has_ssa_nested_result_if_supported_shape,
      msg="template S should scan as supported nested result-if",
    )
    assert_true(
      facts.has_ssa_nested_result_if_condition_write,
      msg="template S should scan condition-write fact",
    )
    assert_false(facts.has_ssa_nested_result_if_condition_value_block)
    assert_false(facts.has_ssa_nested_result_if_arm_value_block)
    assert_false(facts.has_ssa_nested_result_if_mixed_arm_value_block)
  }

  // T. nested result-if condition value-block
  {
    let mod_ = gen_valid_ssa_test_module([], [ValType::i32()], [
      Instruction::block(
        BlockType::val_type(ValType::i32()),
        Expr::new([
          Instruction::i32_const(I32(1)),
          Instruction::local_set(LocalIdx::new(0U)),
          Instruction::local_get(LocalIdx::new(0U)),
        ]),
      ),
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(7)),
          Instruction::local_set(LocalIdx::new(0U)),
          Instruction::local_get(LocalIdx::new(0U)),
        ],
        Some([
          Instruction::i32_const(I32(9)),
          Instruction::local_set(LocalIdx::new(0U)),
          Instruction::local_get(LocalIdx::new(0U)),
        ]),
      ),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
    ])
    let facts = gen_valid_feature_facts(mod_, CoverageForced)
    assert_true(
      facts.has_ssa_nested_result_if_supported_shape,
      msg="template T should scan as supported nested result-if",
    )
    assert_true(
      facts.has_ssa_nested_result_if_condition_value_block,
      msg="template T should scan condition-value-block fact",
    )
    assert_false(facts.has_ssa_nested_result_if_condition_write)
    assert_false(facts.has_ssa_nested_result_if_arm_value_block)
    assert_false(facts.has_ssa_nested_result_if_mixed_arm_value_block)
  }

  // U. nested result-if arm value-blocks
  {
    let mod_ = gen_valid_ssa_test_module([ValType::i32()], [ValType::i32()], [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([
              Instruction::i32_const(I32(7)),
              Instruction::local_set(LocalIdx::new(1U)),
              Instruction::local_get(LocalIdx::new(1U)),
            ]),
          ),
        ],
        Some([
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([
              Instruction::i32_const(I32(9)),
              Instruction::local_set(LocalIdx::new(1U)),
              Instruction::local_get(LocalIdx::new(1U)),
            ]),
          ),
        ]),
      ),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
    ])
    let facts = gen_valid_feature_facts(mod_, CoverageForced)
    assert_true(
      facts.has_ssa_nested_result_if_supported_shape,
      msg="template U should scan as supported nested result-if",
    )
    assert_true(
      facts.has_ssa_nested_result_if_arm_value_block,
      msg="template U should scan arm-value-block fact",
    )
    assert_false(facts.has_ssa_nested_result_if_mixed_arm_value_block)
  }

  // V. nested result-if mixed arm roots
  {
    let mod_ = gen_valid_ssa_test_module(
      [ValType::i32()],
      [ValType::i32(), ValType::i32()],
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::if_(
          BlockType::val_type(ValType::i32()),
          [
            Instruction::i32_const(I32(1)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::block(
              BlockType::val_type(ValType::i32()),
              Expr::new([
                Instruction::i32_const(I32(7)),
                Instruction::local_set(LocalIdx::new(2U)),
                Instruction::local_get(LocalIdx::new(2U)),
              ]),
            ),
          ],
          Some([
            Instruction::i32_const(I32(2)),
            Instruction::local_set(LocalIdx::new(1U)),
            Instruction::block(
              BlockType::val_type(ValType::i32()),
              Expr::new([
                Instruction::i32_const(I32(9)),
                Instruction::local_set(LocalIdx::new(2U)),
                Instruction::local_get(LocalIdx::new(2U)),
              ]),
            ),
          ]),
        ),
        Instruction::drop(),
        Instruction::local_get(LocalIdx::new(1U)),
        Instruction::drop(),
        Instruction::local_get(LocalIdx::new(2U)),
        Instruction::drop(),
      ],
    )
    let facts = gen_valid_feature_facts(mod_, CoverageForced)
    assert_true(
      facts.has_ssa_nested_result_if_supported_shape,
      msg="template V should scan as supported nested result-if",
    )
    assert_true(
      facts.has_ssa_nested_result_if_mixed_arm_value_block,
      msg="template V should scan mixed-arm-value-block fact",
    )
    assert_false(facts.has_ssa_nested_result_if_arm_value_block)
  }

  // W. condition value-block + mixed arm roots
  let mod_ = gen_valid_ssa_test_module(
    [ValType::i32()],
    [ValType::i32(), ValType::i32(), ValType::i32()],
    [
      Instruction::block(
        BlockType::val_type(ValType::i32()),
        Expr::new([
          Instruction::i32_const(I32(1)),
          Instruction::local_set(LocalIdx::new(1U)),
          Instruction::local_get(LocalIdx::new(1U)),
        ]),
      ),
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(4)),
          Instruction::local_set(LocalIdx::new(2U)),
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([
              Instruction::i32_const(I32(7)),
              Instruction::local_set(LocalIdx::new(3U)),
              Instruction::local_get(LocalIdx::new(3U)),
            ]),
          ),
        ],
        Some([
          Instruction::i32_const(I32(5)),
          Instruction::local_set(LocalIdx::new(2U)),
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([
              Instruction::i32_const(I32(9)),
              Instruction::local_set(LocalIdx::new(3U)),
              Instruction::local_get(LocalIdx::new(3U)),
            ]),
          ),
        ]),
      ),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(2U)),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(3U)),
      Instruction::drop(),
    ],
  )
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(
    facts.has_ssa_nested_result_if_supported_shape,
    msg="template W should scan as supported nested result-if",
  )
  assert_true(
    facts.has_ssa_nested_result_if_condition_value_block,
    msg="template W should scan condition-value-block fact",
  )
  assert_true(
    facts.has_ssa_nested_result_if_mixed_arm_value_block,
    msg="template W should scan mixed-arm-value-block fact",
  )
  assert_false(facts.has_ssa_nested_result_if_arm_value_block)
}

///|
test "ssa-nomerge coverage profile emits nested result-if supported shape" {
  let config = GenValidConfig::for_profile(SsaNomergeCoverageProfile)
  let generated = match gen_valid_module_result_from_seed(0x5eedUL, config) {
    Ok(v) => v
    Err(failure) =>
      fail("ssa-nomerge generation failed: \{failure.validation_error_message}")
  }
  assert_true(
    generated.facts.has_ssa_nested_result_if_supported_shape,
    msg="expected nested result-if supported shape in coverage profile",
  )
  assert_true(generated.facts.has_ssa_nested_result_if_condition_write)
  assert_true(generated.facts.has_ssa_nested_result_if_condition_value_block)
  assert_true(generated.facts.has_ssa_nested_result_if_arm_value_block)
  assert_true(generated.facts.has_ssa_nested_result_if_mixed_arm_value_block)
  assert_true(generated.facts.has_ssa_nested_result_if_scalar_result)
}

///|
fn gen_valid_ssa_first_func_scan_facts(
  mod_ : Module,
  param_count : Int,
) -> GenValidSsaFuncFacts raise {
  let (locals, expr) = match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(Func(locals, expr)) => (locals, expr)
        None => fail("expected first generated function body")
      }
    _ => fail("expected generated module with code section")
  }
  gen_valid_scan_func_ssa_facts(param_count, locals, expr)
}

///|
test "ssa scanner detects newer structured raw ssa-nomerge variants" {
  let mod_ = gen_valid_ssa_test_module(
    [ValType::i32()],
    [ValType::i32(), ValType::i32(), ValType::i32()],
    [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::if_(
        BlockType::void_(),
        [
          Instruction::i32_const(I32(7)),
          Instruction::local_set(LocalIdx::new(1U)),
          Instruction::return_(),
        ],
        Some([
          Instruction::i32_const(I32(9)),
          Instruction::local_set(LocalIdx::new(1U)),
        ]),
      ),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::i32_const(I32(0)),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::if_(
            BlockType::void_(),
            [
              Instruction::i32_const(I32(7)),
              Instruction::local_set(LocalIdx::new(1U)),
              Instruction::br(LabelIdx::new(1U)),
            ],
            None,
          ),
          Instruction::i32_const(I32(9)),
          Instruction::local_set(LocalIdx::new(1U)),
        ]),
      ),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::i32_const(I32(7)),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::br_if(LabelIdx::new(0U)),
          Instruction::i32_const(I32(9)),
          Instruction::local_set(LocalIdx::new(1U)),
        ]),
      ),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(7)),
          Instruction::local_set(LocalIdx::new(0U)),
          Instruction::i32_const(I32(1)),
        ],
        Some([
          Instruction::i32_const(I32(9)),
          Instruction::local_set(LocalIdx::new(0U)),
          Instruction::i32_const(I32(2)),
        ]),
      ),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::drop(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [
          Instruction::i32_const(I32(20)),
          Instruction::local_set(LocalIdx::new(2U)),
          Instruction::i32_const(I32(2)),
        ],
        Some([
          Instruction::i32_const(I32(30)),
          Instruction::local_set(LocalIdx::new(3U)),
          Instruction::i32_const(I32(3)),
        ]),
      ),
      Instruction::drop(),
    ],
  )
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_if_join_phi_candidate)
  let direct = try! gen_valid_ssa_first_func_scan_facts(mod_, 1)
  assert_true(direct.has_ssa_structured_early_return_local)
  assert_true(direct.has_ssa_block_branch_merge_copy)
  assert_true(direct.has_ssa_block_br_if_merge_copy)
  assert_true(direct.has_ssa_structured_param_merge)
  assert_true(direct.has_ssa_branch_local_not_read_later)
}

///|
test "ssa scanner detects recent raw structured ssa-nomerge coverage families" {
  let mod_ = gen_valid_ssa_test_module([ValType::i32()], [ValType::i32()], [
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(0)),
        Instruction::br_table([LabelIdx::new(0U)], LabelIdx::new(0U)),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::drop(),
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([Instruction::unreachable_(), Instruction::unreachable_()]),
    ),
    Instruction::unreachable_(),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::i32_const(I32(5)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::local_get(LocalIdx::new(1U)),
        Instruction::drop(),
      ],
      None,
    ),
    Instruction::i32_const(I32(2)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::drop(),
    Instruction::i32_const(I32(0)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(7)),
        Instruction::local_set(LocalIdx::new(1U)),
        Instruction::br(LabelIdx::new(0U)),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_default_local_read_after_branchy_control)
  assert_true(facts.has_ssa_dropped_unreachable_debris_before_hard_unreachable)
  assert_true(facts.has_ssa_canonical_body_local_next_read)
  assert_true(facts.has_ssa_immediate_block_exit_canonical_set_br)
}

///|
test "ssa scanner detects enclosing label and void br_table copy families" {
  let mod_ = gen_valid_ssa_test_module([ValType::i32()], [ValType::i32()], [
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::if_(
          BlockType::void_(),
          [
            Instruction::i32_const(I32(7)),
            Instruction::local_set(LocalIdx::new(1U)),
          ],
          Some([
            Instruction::i32_const(I32(8)),
            Instruction::local_set(LocalIdx::new(1U)),
          ]),
        ),
        Instruction::block(
          BlockType::void_(),
          Expr::new([Instruction::br(LabelIdx::new(1U))]),
        ),
        Instruction::i32_const(I32(9)),
        Instruction::local_set(LocalIdx::new(1U)),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::drop(),
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::if_(
          BlockType::void_(),
          [
            Instruction::i32_const(I32(17)),
            Instruction::local_set(LocalIdx::new(1U)),
          ],
          Some([
            Instruction::i32_const(I32(18)),
            Instruction::local_set(LocalIdx::new(1U)),
          ]),
        ),
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::br_table([LabelIdx::new(1U)], LabelIdx::new(1U)),
          ]),
        ),
        Instruction::i32_const(I32(19)),
        Instruction::local_set(LocalIdx::new(1U)),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::drop(),
  ])
  let facts = gen_valid_feature_facts(mod_, CoverageForced)
  assert_true(facts.has_ssa_enclosing_label_copy_before_exit)
  assert_true(facts.has_ssa_void_br_table_canonical_copies)
}

///|
test "ssa-nomerge coverage profile emits newer structured raw variants" {
  let config = GenValidConfig::for_profile(SsaNomergeCoverageProfile)
  let generated = match gen_valid_module_result_from_seed(0x5eedUL, config) {
    Ok(v) => v
    Err(failure) =>
      fail("ssa-nomerge generation failed: \{failure.validation_error_message}")
  }
  let facts = try! gen_valid_ssa_first_func_scan_facts(generated.wasm_module, 1)
  assert_true(facts.has_ssa_structured_early_return_local)
  assert_true(facts.has_ssa_block_branch_merge_copy)
  assert_true(facts.has_ssa_block_br_if_merge_copy)
  assert_true(facts.has_ssa_structured_param_merge)
  assert_true(facts.has_ssa_branch_local_not_read_later)
  assert_true(facts.has_ssa_default_local_read_after_branchy_control)
  assert_true(facts.has_ssa_dropped_unreachable_debris_before_hard_unreachable)
  assert_true(facts.has_ssa_canonical_body_local_next_read)
  assert_true(facts.has_ssa_immediate_block_exit_canonical_set_br)
  assert_true(facts.has_ssa_enclosing_label_copy_before_exit)
  assert_true(facts.has_ssa_void_br_table_canonical_copies)
  assert_true(generated.facts.has_ssa_structured_early_return_local)
  assert_true(generated.facts.has_ssa_block_branch_merge_copy)
  assert_true(generated.facts.has_ssa_block_br_if_merge_copy)
  assert_true(generated.facts.has_ssa_structured_param_merge)
  assert_true(generated.facts.has_ssa_branch_local_not_read_later)
  assert_true(generated.facts.has_ssa_default_local_read_after_branchy_control)
  assert_true(
    generated.facts.has_ssa_dropped_unreachable_debris_before_hard_unreachable,
  )
  assert_true(generated.facts.has_ssa_canonical_body_local_next_read)
  assert_true(generated.facts.has_ssa_immediate_block_exit_canonical_set_br)
  assert_true(generated.facts.has_ssa_enclosing_label_copy_before_exit)
  assert_true(generated.facts.has_ssa_void_br_table_canonical_copies)
}
