///|
fn report_vector_size_fixture(count : Int32, candidate : Bool) -> @lib.Module {
  let seed = pass_test_module_from_wat(
    if candidate {
      "(module (func (result v128) v128.const i32x4 0 0 0 0))"
    } else {
      "(module (func (param i32) (result i32) local.get 0))"
    },
  )
  seed
  .with_func_sec(
    @lib.FuncSec::new(Array::make(count, seed.func_sec.unwrap().0[0])),
  )
  .with_code_sec(
    @lib.CodeSec::new(Array::make(count, seed.code_sec.unwrap().0[0])),
  )
}

///|
fn report_vector_size_bench(
  it : @bench.T,
  count : Int32,
  candidate : Bool,
  shrink_level : Int32,
) -> Unit raise {
  let fixture = report_vector_size_fixture(count, candidate)
  @validate.validate_module(fixture).unwrap()
  let result = precompute_materialize_vectors_for_size(fixture, shrink_level)
  @validate.validate_module(result).unwrap()
  if shrink_level <= 0 || !candidate {
    assert_true(physical_equal(result, fixture))
  } else {
    assert_true(
      @binary.encode_module(result).unwrap().length() <
      @binary.encode_module(fixture).unwrap().length(),
    )
  }
  it.bench(fn() {
    it.keep(precompute_materialize_vectors_for_size(fixture, shrink_level))
  })
}

///|
test "bench report vector sizing bypass functions=128" (it : @bench.T) {
  report_vector_size_bench(it, 128, true, 0)
}

///|
test "bench report vector sizing no candidates functions=128" (it : @bench.T) {
  report_vector_size_bench(it, 128, false, 1)
}

///|
test "bench report vector sizing candidates functions=128" (it : @bench.T) {
  report_vector_size_bench(it, 128, true, 1)
}

///|
fn report_cleanup_fixture(count : Int32) -> (@lib.Module, @lib.Module) {
  let seed = encoded_profitability_local_fixture()
  let funcs = Array::make(count, seed.code_sec.unwrap().0[0])
  let before = seed
    .with_func_sec(
      @lib.FuncSec::new(Array::make(count, seed.func_sec.unwrap().0[0])),
    )
    .with_code_sec(@lib.CodeSec::new(funcs))
  let changed = funcs.map(fn(func) {
    let @lib.Func(locals, @lib.Expr(body)) = func
    let next = body.copy()
    next.push(@lib.Instruction::nop())
    @lib.Func::new(locals, @lib.Expr::new(next))
  })
  (before, before.with_code_sec(@lib.CodeSec::new(changed)))
}

///|
fn report_cleanup_bench(
  it : @bench.T,
  count : Int32,
  changed : Bool,
) -> Unit raise {
  let (before, after) = report_cleanup_fixture(count)
  @validate.validate_module(before).unwrap()
  @validate.validate_module(after).unwrap()
  let input = if changed { after } else { before }
  let result = simplify_locals_cleanup_changed_module_encoding(before, input)
  @validate.validate_module(result).unwrap()
  if changed {
    assert_true(
      @binary.encode_module(result).unwrap().length() <
      @binary.encode_module(input).unwrap().length(),
    )
  } else {
    assert_true(physical_equal(result, before))
  }
  it.bench(fn() {
    it.keep(simplify_locals_cleanup_changed_module_encoding(before, input))
  })
}

///|
test "bench report SimplifyLocals cleanup unchanged functions=128" (
  it : @bench.T,
) {
  report_cleanup_bench(it, 128, false)
}

///|
test "bench report SimplifyLocals cleanup candidates functions=128" (
  it : @bench.T,
) {
  report_cleanup_bench(it, 128, true)
}

///|
fn report_simd_admission_bench(it : @bench.T, cold : Bool) -> Unit raise {
  let fixture = pass_test_module_from_wat("(module)").with_custom_secs([
    @lib.CustomSec::new(
      @lib.Name::new("target_features"),
      b"\x01\x2d\x07simd128",
    ),
  ])
  let shared = HotPipelineModuleState::new()
  assert_false(run_hot_pipeline_allows_simd_introduction(fixture, shared))
  it.bench(fn() {
    let state = if cold { HotPipelineModuleState::new() } else { shared }
    for _ in 0..<128 {
      it.keep(run_hot_pipeline_allows_simd_introduction(fixture, state))
    }
  })
}

///|
test "bench report SIMD admission cold queries=128" (it : @bench.T) {
  report_simd_admission_bench(it, true)
}

///|
test "bench report SIMD admission cached queries=128" (it : @bench.T) {
  report_simd_admission_bench(it, false)
}

///|
fn report_const_control_scan_bench(
  it : @bench.T,
  width : Int32,
  candidate : Bool,
) -> Unit raise {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<width {
    body.push(@lib.Instruction::nop())
  }
  if candidate {
    body.push(@lib.Instruction::i32_const(@lib.I32(2)))
    body.push(@lib.Instruction::i32_const(@lib.I32(3)))
    body.push(@lib.Instruction::i32_const(@lib.I32(1)))
    body.push(@lib.Instruction::select())
  }
  assert_eq(precompute_raw_instrs_have_const_control_candidate(body), candidate)
  it.bench(fn() {
    it.keep(precompute_raw_instrs_have_const_control_candidate(body))
  })
}

///|
test "bench report constant-control scan no candidate width=4096" (
  it : @bench.T,
) {
  report_const_control_scan_bench(it, 4096, false)
}

///|
test "bench report constant-control scan trailing select width=4096" (
  it : @bench.T,
) {
  report_const_control_scan_bench(it, 4096, true)
}

///|
fn report_structured_tee_exact_cleanup_bench(
  it : @bench.T,
  width : Int32,
  candidate : Bool,
) -> Unit raise {
  let source = StringBuilder()
  source.write_string(
    "(module (func (param f64) (result i32) (local i32 i32 i32 i32 i32 i64 f32 f64) ",
  )
  for _ in 0..<width {
    source.write_string("nop ")
  }
  source.write_string("i32.const 40 local.tee 1 drop block ")
  if candidate {
    source.write_string("nop end local.get 1 drop i32.const 0 ")
  } else {
    source.write_string("i32.const 0 drop end local.get 1 drop local.get 1 ")
  }
  source.write_string("))")
  let fixture = pass_test_module_from_wat(source.to_string())
  let @lib.CodeSec(funcs) = fixture.code_sec.unwrap()
  let (output, changed) = run_hot_pipeline_simplify_locals_cleanup_exact_func(
    funcs[0],
  )
  let @lib.Func(_, @lib.Expr(output_body)) = output
  let reads = Array::make(9, 0)
  let writes = Array::make(9, 0)
  pass_lower_count_locals(output_body, reads, writes)
  if candidate {
    assert_true(changed)
    assert_eq(reads[1], 0)
    assert_eq(writes[1], 0)
  } else {
    assert_true(reads[1] >= 1)
    assert_true(writes[1] >= 1)
  }
  let checked = fixture.with_code_sec(@lib.CodeSec::new([output]))
  @validate.validate_module(checked).unwrap()
  it.bench(fn() {
    it.keep(run_hot_pipeline_simplify_locals_cleanup_exact_func(funcs[0]))
  })
}

///|
test "bench report structured-tee exact cleanup no candidate width=4096" (
  it : @bench.T,
) {
  report_structured_tee_exact_cleanup_bench(it, 4096, false)
}

///|
test "bench report structured-tee exact cleanup candidate width=4096" (
  it : @bench.T,
) {
  report_structured_tee_exact_cleanup_bench(it, 4096, true)
}
