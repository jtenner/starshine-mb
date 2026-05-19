///|
fn dae_wbtest_call_summary_fixture() -> @lib.Module {
  let void_type = @lib.TypeIdx::new(0U)
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([void_type, void_type, void_type]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("entry"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        ]),
      ),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    ]),
  )
}

///|
test "dae original call summary counts repeated undropped callees once per caller" {
  let mod_ = dae_wbtest_call_summary_fixture()
  let summary = dae_collect_original_call_summary_with_type_indices(
    mod_,
    dae_collect_func_type_indices(mod_),
  )
  assert_eq(summary.call_counts, [0, 2, 2])
  assert_eq(summary.prior_call_counts, [0, 1, 2])
  assert_eq(summary.self_call_counts, [0, 1, 0])
  assert_eq(summary.nonself_undropped_call_counts, [0, 1, 1])
  assert_eq(summary.prior_undropped_call_counts, [0, 1, 1])
  assert_eq(summary.active_nonself_call_counts, [0, 1, 2])
}

///|
test "dae touched raw cleanup strips nops and dropped zero only from touched functions" {
  let noisy_body = [
    @lib.Instruction::nop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::drop(),
  ]
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(noisy_body)),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(noisy_body)),
    ]),
  )
  let result = dae_strip_touched_nops_and_dropped_zero_once(mod_, [true, false])
  assert_true(result.changed)
  assert_eq(result.primary_def, 0)
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned)) = funcs[0]
      let @lib.Func(_, @lib.Expr(untouched)) = funcs[1]
      assert_eq(cleaned, [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::drop(),
      ])
      assert_eq(untouched, noisy_body)
    }
    None => fail("expected rewritten code section")
  }
}
