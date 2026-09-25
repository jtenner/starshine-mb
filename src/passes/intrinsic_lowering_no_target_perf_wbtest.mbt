///|
fn il_no_target_perf_module(function_count : Int) -> @lib.Module {
  let type_indices : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  let body : Array[@lib.Instruction] = []
  for _ in 0..<32 {
    body.push(@lib.Instruction::i32_const(@lib.I32::new(1)))
    body.push(@lib.Instruction::drop())
  }
  let body = @lib.Expr::new([
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body)),
  ])
  for _ in 0..<function_count {
    type_indices.push(@lib.TypeIdx::new(0U))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), body))
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new(type_indices))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn il_no_target_perf_bench(it : @bench.T, function_count : Int) -> Unit {
  let fixture = il_no_target_perf_module(function_count)
  if intrinsic_lowering_run_module_pass(fixture) != fixture {
    abort("IntrinsicLowering no-target fixture unexpectedly changed")
  }
  it.bench(fn() { it.keep(intrinsic_lowering_run_module_pass(fixture)) })
}

///|
test "bench IntrinsicLowering no target funcs=128" (it : @bench.T) {
  il_no_target_perf_bench(it, 128)
}

///|
test "bench IntrinsicLowering no target funcs=256" (it : @bench.T) {
  il_no_target_perf_bench(it, 256)
}

///|
test "IntrinsicLowering still rewrites matching intrinsic imports" {
  let fixture = pass_test_module_from_wat(
    "(module (import \"binaryen-intrinsics\" \"call.without.effects\" (func $cwe (param funcref) (result i32))) (func $target (result i32) (i32.const 7)) (elem declare func $target) (func (export \"run\") (result i32) (call $cwe (ref.func $target))))",
  )
  let rewritten = intrinsic_lowering_run_module_pass(fixture)
  assert_true(rewritten != fixture)
  assert_true(@validate.validate_module(rewritten).is_ok())
  match rewritten.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [@lib.Instruction::call(@lib.FuncIdx::new(1U))])
    _ => fail("expected rewritten run function")
  }
}
