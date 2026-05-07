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

///|
test "optimize-casts turns guaranteed-success br_on_cast into br" {
  let child_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_module(child_ref, child_ref, [
      @lib.Instruction::block(
        @lib.BlockType::val_type(child_ref),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br_on_cast(
            @lib.LabelIdx::new(0U),
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(0U)),
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(1U)),
          ),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  assert_false(pretty.contains("br_on_cast"), msg=pretty)
  assert_true(pretty.contains("br (Label 0)"), msg=pretty)
}

///|
test "optimize-casts removes guaranteed-success br_on_cast_fail" {
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let child_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_module(child_ref, base_ref, [
      @lib.Instruction::block(
        @lib.BlockType::val_type(base_ref),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br_on_cast_fail(
            @lib.LabelIdx::new(0U),
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(0U)),
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(1U)),
          ),
        ]),
      ),
    ]),
  )
  assert_false(pretty.contains("br_on_cast_fail"), msg=pretty)
}

///|
fn oc_test_ordered_neighborhood_fixture() -> @lib.Module {
  let box = @lib.TypeIdx::new(0U)
  let temp = @lib.LocalIdx::new(0U)
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::anyref()]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(11)),
          @lib.Instruction::i32_const(@lib.I32(22)),
          @lib.Instruction::struct_new(box),
          @lib.Instruction::local_tee(temp),
          @lib.Instruction::ref_cast(false, @lib.HeapType::new(box)),
          @lib.Instruction::struct_get(box, @lib.U32(0U)),
        ]),
      ),
    ]),
  )
}

///|
test "optimize-casts ordered neighborhood stays valid through local cleanup consumers" {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      oc_test_ordered_neighborhood_fixture(),
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      [
        "heap2local", "optimize-casts", "local-subtyping", "coalesce-locals", "local-cse",
      ],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected heap2local/optimize-casts/local-subtyping/coalesce-locals/local-cse success, got \{err}",
      )
  }
  let starts = trace.filter(fn(line) {
    line.contains("pass[") && line.contains(":start")
  })
  assert_true(
    starts.length() >= 5 &&
    starts[0].contains("pass[heap2local]:start") &&
    starts[1].contains("pass[optimize-casts]:start") &&
    starts[2].contains("pass[local-subtyping]:start") &&
    starts[3].contains("pass[coalesce-locals]:start") &&
    starts[4].contains("pass[local-cse]:start"),
    msg=starts.to_string(),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-casts ordered neighborhood output to validate, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("ref.cast"), msg=pretty)
}
