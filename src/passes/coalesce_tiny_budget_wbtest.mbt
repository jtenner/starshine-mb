///|
test "tiny flat coalescing accepts exact fixed budgets and removes unused local slots" {
  let seed = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0))",
  )
  let instrs = Array::make(119, @lib.Instruction::nop())
  instrs.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(32U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(32U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(33U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(33U)),
  ])
  let params = Array::make(32, @lib.ValType::i32())
  let func = @lib.Func::new(
    @lib.Locals::from_types(Array::make(64, @lib.ValType::i32())),
    @lib.Expr::new(instrs),
  )
  let input = seed
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(params, [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_code_sec(@lib.CodeSec::new([func]))
  @validate.validate_module(input).unwrap()
  assert_true(run_hot_pipeline_tiny_flat_coalesce_selected(func, 32))
  let rewrite = cl_rewrite_func(func, params)
  assert_true(rewrite.changed)
  let @lib.Func(locals, _) = rewrite.func
  assert_eq(locals.length(), 0)
  @validate.validate_module(
    input.with_code_sec(@lib.CodeSec::new([rewrite.func])),
  ).unwrap()
  assert_false(run_hot_pipeline_tiny_flat_coalesce_selected(func, 33))
  assert_false(
    run_hot_pipeline_tiny_flat_coalesce_selected(
      @lib.Func::new(
        @lib.Locals::from_types(Array::make(65, @lib.ValType::i32())),
        @lib.Expr::new(instrs),
      ),
      32,
    ),
  )
  let too_long = instrs.copy()
  too_long.push(@lib.Instruction::nop())
  assert_false(
    run_hot_pipeline_tiny_flat_coalesce_selected(
      @lib.Func::new(
        @lib.Locals::from_types(Array::make(64, @lib.ValType::i32())),
        @lib.Expr::new(too_long),
      ),
      32,
    ),
  )
}

///|
test "artifact-scale flat coalescing intentionally excludes control and continuation bodies" {
  // These forms stay on the preexisting conservative module-size lane. This
  // check guards the fixed analysis budget, not general proposal support.
  let excluded = [
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([])),
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([])),
    @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
    @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new([]), []),
    @lib.Instruction::try_table(@lib.BlockType::void_(), [], @lib.Expr::new([])),
    @lib.Instruction::return_(),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::suspend(@lib.TagIdx::new(0U)),
    @lib.Instruction::resume_(@lib.TypeIdx::new(0U), []),
    @lib.Instruction::resume_throw(
      @lib.TypeIdx::new(0U),
      @lib.TagIdx::new(0U),
      [],
    ),
    @lib.Instruction::resume_throw_ref(@lib.TypeIdx::new(0U), []),
    @lib.Instruction::stack_switch(@lib.TypeIdx::new(0U), @lib.TagIdx::new(0U)),
  ]
  for instr in excluded {
    let func = @lib.Func::new(
      @lib.Locals::from_types([@lib.ValType::i32()]),
      @lib.Expr::new([instr]),
    )
    assert_false(run_hot_pipeline_tiny_flat_coalesce_selected(func, 0))
  }
}
