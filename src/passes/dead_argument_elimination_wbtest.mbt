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
test "dae raw cleanup strips nops and dropped pure leaves after any DAE touch" {
  let noisy_body = [
    @lib.Instruction::nop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::drop(),
    @lib.Instruction::i64_const(@lib.I64(9L)),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(1.5)),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(2.25)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(16.75)),
    @lib.Instruction::f64_sqrt(),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32(9.25)),
    @lib.Instruction::f32_const(@lib.F32(2.5)),
    @lib.Instruction::f32_max(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(84)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_div_s(),
    @lib.Instruction::drop(),
    @lib.Instruction::return_(),
  ]
  let mod_ = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(noisy_body)),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(noisy_body)),
    ]),
  )
  let no_touch_result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [
    false, false,
  ])
  assert_false(no_touch_result.changed)
  let result = dae_strip_module_nops_and_dropped_pure_leaf_once(mod_, [
    true, false,
  ])
  assert_true(result.changed)
  assert_eq(result.primary_def, 0)
  assert_eq(result.touched, [true, false])
  match result.mod_out.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(cleaned0)) = funcs[0]
      let @lib.Func(_, @lib.Expr(cleaned1)) = funcs[1]
      let preserved_trapping = [
        @lib.Instruction::i32_const(@lib.I32(84)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_div_s(),
        @lib.Instruction::drop(),
        @lib.Instruction::return_(),
      ]
      assert_eq(cleaned0, preserved_trapping)
      assert_eq(cleaned1, preserved_trapping)
    }
    None => fail("expected rewritten code section")
  }
}
