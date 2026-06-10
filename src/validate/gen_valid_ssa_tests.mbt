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
