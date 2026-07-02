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
fn optimize_casts_void_module(
  param_type : @lib.ValType,
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
    @lib.SubType::comp_type(@lib.CompType::func([param_type], [])),
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
fn optimize_casts_two_func_void_module(
  param_type : @lib.ValType,
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
  let target_func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([param_type], [])),
  )
  let helper_func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([base, child, target_func_type, helper_func_type]),
  )
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(2U), @lib.TypeIdx::new(3U)]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new(body)),
      @lib.Func::new(
        @lib.Locals::new([]),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    ]),
  )
}

///|
fn optimize_casts_memory_void_module(
  param_type : @lib.ValType,
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
    @lib.SubType::comp_type(@lib.CompType::func([param_type], [])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([base, child, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(0U, None))]),
  )
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
fn optimize_casts_count_substring(text : String, needle : String) -> Int {
  if needle.length() == 0 {
    return 0
  }
  let mut count = 0
  let limit = text.length() - needle.length()
  let mut i = 0
  while i <= limit {
    if text.sub(start=i, end=i + needle.length()).to_owned() == needle {
      count += 1
      i += needle.length()
    } else {
      i += 1
    }
  }
  count
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
test "optimize-casts reuses an already computed ref.cast for later local gets" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "optimize-casts reuses an already computed ref.as_non_null for later local gets" {
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(nullable_struct_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_as_non_null(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "optimize-casts duplicates later ref.cast to previous adjacent local get" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    2,
    msg=pretty,
  )
}

///|
test "optimize-casts does not duplicate ref.cast earlier across same-local writes" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    1,
    msg=pretty,
  )
}

///|
test "optimize-casts duplicates later ref.cast across a dropped const root" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    2,
    msg=pretty,
  )
}

///|
test "optimize-casts does not duplicate ref.cast earlier across calls" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_two_func_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    1,
    msg=pretty,
  )
}

///|
test "optimize-casts duplicates later ref.cast across a dropped unary pure root" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    2,
    msg=pretty,
  )
}

///|
test "optimize-casts does not duplicate ref.cast earlier across trapping numeric roots" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_div_s(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    1,
    msg=pretty,
  )
}

///|
test "optimize-casts duplicates later ref.cast across a dropped binary pure root" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(11)),
      @lib.Instruction::i32_const(@lib.I32(31)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    2,
    msg=pretty,
  )
}

///|
test "optimize-casts duplicates later ref.cast across a dropped multiplication pure root" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(11)),
      @lib.Instruction::i32_const(@lib.I32(31)),
      @lib.Instruction::i32_mul(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    2,
    msg=pretty,
  )
}

///|
test "optimize-casts duplicates later ref.cast across dropped bitwise pure roots" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(11)),
      @lib.Instruction::i32_const(@lib.I32(31)),
      @lib.Instruction::i32_and(),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(5)),
      @lib.Instruction::i32_const(@lib.I32(12)),
      @lib.Instruction::i32_or(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    2,
    msg=pretty,
  )
}

///|
test "optimize-casts duplicates later ref.cast across dropped xor and shift pure roots" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(11)),
      @lib.Instruction::i32_const(@lib.I32(31)),
      @lib.Instruction::i32_xor(),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(5)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_shl(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    2,
    msg=pretty,
  )
}

///|
test "optimize-casts duplicates later ref.cast across dropped sub shift and rotate pure roots" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(31)),
      @lib.Instruction::i32_const(@lib.I32(11)),
      @lib.Instruction::i32_sub(),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(32)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_shr_u(),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(32)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_shr_s(),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(32)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_rotl(),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(32)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_rotr(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    2,
    msg=pretty,
  )
}

///|
test "optimize-casts keeps sub shift and rotate motion behind same-local writes" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(31)),
      @lib.Instruction::i32_const(@lib.I32(11)),
      @lib.Instruction::i32_sub(),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(32)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_rotr(),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    1,
    msg=pretty,
  )
}

///|
test "optimize-casts does not duplicate ref.cast earlier across memory loads" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_memory_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_load(
        @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    1,
    msg=pretty,
  )
}

///|
test "optimize-casts does not duplicate ref.cast earlier across same-local sets after bitwise roots" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(11)),
      @lib.Instruction::i32_const(@lib.I32(31)),
      @lib.Instruction::i32_and(),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    1,
    msg=pretty,
  )
}

///|
test "optimize-casts does not duplicate ref.cast earlier across same-local sets after multiplication roots" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(11)),
      @lib.Instruction::i32_const(@lib.I32(31)),
      @lib.Instruction::i32_mul(),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    1,
    msg=pretty,
  )
}

///|
test "optimize-casts does not duplicate ref.cast earlier across same-local tee writes after binary pure roots" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(11)),
      @lib.Instruction::i32_const(@lib.I32(31)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "ref.cast"),
    1,
    msg=pretty,
  )
}

///|
test "optimize-casts does not materialize ref.as_non_null reuse for non-nullable locals" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_as_non_null(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "optimize-casts reuses a ref.cast fed by a same-local tee" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "optimize-casts leaves repeated cast sources on the original local" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "local.get (Local 1)"),
    1,
  )
}

///|
test "optimize-casts uses the narrower later cast for subsequent local reads" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "local.get (Local 1)"),
    1,
  )
}

///|
test "optimize-casts uses an earlier narrower cast for later broader cast sources" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "local.get (Local 1)"),
    3,
  )
}

///|
test "optimize-casts uses an earlier nullable cast for later ref.as_non_null source" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        true,
        @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_as_non_null(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "local.get (Local 1)"),
    3,
  )
}

///|
test "optimize-casts keeps nullable cast facts behind same-local writes before ref.as_non_null" {
  let any_ref = @lib.ValType::anyref()
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(any_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        true,
        @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_as_non_null(),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "local.get (Local 1)"),
    1,
  )
}

///|
fn optimize_casts_unrelated_module(
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::new(false, [], @lib.CompType::struct_([])),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [],
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::anyref()], [])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([struct_type, array_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new(body)),
    ]),
  )
}

///|
test "optimize-casts does not use an unrelated best cast for later cast sources" {
  let pretty = optimize_casts_run_pretty(
    optimize_casts_unrelated_module([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "local.get (Local 1)"),
    2,
  )
}

///|
test "optimize-casts reuses a cast inside a fallthrough block" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::ref_cast(
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "optimize-casts carries reuse through a branch-free value block" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::ref_cast(
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(7)),
        ]),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "optimize-casts does not carry a branch-skipped value block cast" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::ref_cast(
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(8)),
        ]),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "optimize-casts does not carry a branch-skipped cast out of a block" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::ref_cast(
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          ),
          @lib.Instruction::drop(),
        ]),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "optimize-casts does not reuse a cast through a same-local tee write" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "local.get (Local 1)"),
    1,
  )
}

///|
test "optimize-casts does not reuse a cast past a same-local write" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
  )
  let pretty = optimize_casts_run_pretty(
    optimize_casts_void_module(struct_ref, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::abs(@lib.AbsHeapType::struct_()),
      ),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  assert_true(pretty.contains("local.tee"), msg=pretty)
  @debug.assert_eq(
    optimize_casts_count_substring(pretty, "local.get (Local 1)"),
    1,
  )
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
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
