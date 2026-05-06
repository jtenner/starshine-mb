///|
fn optimize_casts_module(
  param_type : @lib.ValType,
  result_type : @lib.ValType,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let base = @lib.RecType::new(
    @lib.SubType::new(false, [], @lib.CompType::struct_([])),
  )
  let child = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [@lib.TypeIdx::new(0U)],
      @lib.CompType::struct_([]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([param_type], [result_type])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([base, child, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn optimize_casts_run_pretty(mod_ : @lib.Module) -> String {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => abort("unexpected invalid optimize-casts fixture: \{err}")
  }
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["optimize-casts"]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected optimize-casts pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => optimized.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => abort("expected optimize-casts output to validate, got \{err}")
  }
}

///|
test "optimize-casts removes ref.cast when source already has the target non-null type" {
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_module(base_ref, base_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  assert_false(pretty.contains("ref.cast"), msg=pretty)
}

///|
test "optimize-casts folds ref.test that is guaranteed true" {
  let child_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_module(child_ref, @lib.ValType::i32(), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_test(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  assert_false(pretty.contains("ref.test"), msg=pretty)
  assert_true(pretty.contains("i32.const"), msg=pretty)
}

///|
test "optimize-casts removes ref.cast_desc_eq when source already has the target type" {
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_module(base_ref, base_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast_desc_eq(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  assert_false(pretty.contains("ref.cast_desc_eq"), msg=pretty)
}

///|
test "optimize-casts folds ref.test_desc that is guaranteed true" {
  let child_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_module(child_ref, @lib.ValType::i32(), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_test_desc(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  assert_false(pretty.contains("ref.test_desc"), msg=pretty)
  assert_true(pretty.contains("i32.const"), msg=pretty)
}

///|
test "optimize-casts preserves nullable-to-nonnull ref.cast trap" {
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let nullable_base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_module(nullable_base_ref, base_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  assert_true(pretty.contains("ref.cast"), msg=pretty)
}
