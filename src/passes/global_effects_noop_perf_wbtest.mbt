///|
fn ge_noop_perf_fixture(function_count : Int) -> @lib.Module {
  let type_idxs : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  let body = Array::make(64, @lib.Instruction::nop())
  let nested = [
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body)),
  ]
  for _ in 0..<function_count {
    type_idxs.push(@lib.TypeIdx::new(0U))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(nested)))
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn ge_noop_perf_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = ge_noop_perf_fixture(count)
  if global_effects_run_module_pass(fixture) != fixture {
    abort("GlobalEffects no-op fixture changed")
  }
  it.bench(fn() { it.keep(global_effects_run_module_pass(fixture)) })
}

///|
fn ge_positive_perf_fixture() -> @lib.Module {
  match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x02, 0x60, 0x00,
        0x00, 0x5d, 0x00, 0x03, 0x03, 0x02, 0x00, 0x00, 0x07, 0x07, 0x01, 0x03, 0x72,
        0x75, 0x6e, 0x00, 0x01, 0x09, 0x05, 0x01, 0x03, 0x00, 0x01, 0x00, 0x0a, 0x0f,
        0x02, 0x03, 0x00, 0x01, 0x0b, 0x09, 0x00, 0xd2, 0x00, 0xe0, 0x01, 0xe3, 0x01,
        0x00, 0x0b,
      ]),
    ) {
    Ok(input) => input
    Err(_) => abort("GlobalEffects positive benchmark cannot decode")
  }
}

///|
fn ge_mixed_perf_fixture(extra_functions : Int) -> @lib.Module {
  let positive = ge_positive_perf_fixture()
  let type_idxs = match positive.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.copy()
    None => abort("GlobalEffects positive fixture lacks function types")
  }
  let funcs = match positive.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => abort("GlobalEffects positive fixture lacks code")
  }
  let nested = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new(Array::make(64, @lib.Instruction::nop())),
    ),
  ]
  for _ in 0..<extra_functions {
    type_idxs.push(@lib.TypeIdx::new(0U))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(nested)))
  }
  positive
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn ge_mixed_perf_bench(it : @bench.T, extra_functions : Int) -> Unit {
  let fixture = ge_mixed_perf_fixture(extra_functions)
  let rewritten = global_effects_run_module_pass(fixture)
  if rewritten == fixture || @validate.validate_module(rewritten).is_err() {
    abort("GlobalEffects mixed fixture did not rewrite validly")
  }
  match (fixture.code_sec, rewritten.code_sec) {
    (Some(@lib.CodeSec(before)), Some(@lib.CodeSec(after))) =>
      for idx in 2..<before.length() {
        if before[idx] != after[idx] {
          abort("GlobalEffects changed an unrelated function")
        }
      }
    _ => abort("GlobalEffects mixed fixture lacks code")
  }
  it.bench(fn() { it.keep(global_effects_run_module_pass(fixture)) })
}

///|
test "GlobalEffects resume guard visits nested block bodies" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::resume_(@lib.TypeIdx::new(0U), [])]),
    ),
  ])
  assert_true(ge_body_has_rewritable_resume(body))
  assert_false(
    ge_body_has_rewritable_resume(@lib.Expr::new([@lib.Instruction::nop()])),
  )
}

///|
test "bench GlobalEffects no-resume funcs=256" (it : @bench.T) {
  ge_noop_perf_bench(it, 256)
}

///|
test "bench GlobalEffects no-resume funcs=512" (it : @bench.T) {
  ge_noop_perf_bench(it, 512)
}

///|
test "bench GlobalEffects fresh-resume rewrite" (it : @bench.T) {
  let fixture = ge_positive_perf_fixture()
  let rewritten = global_effects_run_module_pass(fixture)
  if rewritten == fixture || @validate.validate_module(rewritten).is_err() {
    abort("GlobalEffects positive benchmark did not rewrite validly")
  }
  it.bench(fn() { it.keep(global_effects_run_module_pass(fixture)) })
}

///|
test "bench GlobalEffects mixed funcs=256" (it : @bench.T) {
  ge_mixed_perf_bench(it, 256)
}

///|
test "bench GlobalEffects mixed funcs=512" (it : @bench.T) {
  ge_mixed_perf_bench(it, 512)
}
