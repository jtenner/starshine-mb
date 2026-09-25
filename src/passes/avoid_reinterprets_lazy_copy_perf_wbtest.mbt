///|
fn ar_lazy_copy_perf_fixture(extra_functions : Int) -> @lib.Module {
  let positive = pass_test_module_from_wat(
    "(module (memory 1) (func i32.const 0 f32.load i32.reinterpret_f32 drop))",
  )
  let type_idxs = match positive.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.copy()
    None => abort("AvoidReinterprets positive fixture lacks function types")
  }
  let funcs = match positive.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => abort("AvoidReinterprets positive fixture lacks code")
  }
  let body : Array[@lib.Instruction] = []
  for idx in 0..<128 {
    body.push(@lib.Instruction::i32_const(@lib.I32(idx)))
    body.push(@lib.Instruction::drop())
  }
  for _ in 0..<extra_functions {
    type_idxs.push(@lib.TypeIdx::new(0U))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)))
  }
  positive
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn ar_lazy_copy_perf_bench(it : @bench.T, extra_functions : Int) -> Unit {
  let fixture = ar_lazy_copy_perf_fixture(extra_functions)
  let output = avoid_reinterprets_run_module_pass(fixture)
  if output == fixture || @validate.validate_module(output).is_err() {
    abort("AvoidReinterprets mixed fixture did not rewrite validly")
  }
  match (fixture.code_sec, output.code_sec) {
    (Some(@lib.CodeSec(before)), Some(@lib.CodeSec(after))) =>
      for idx in 1..<before.length() {
        if before[idx] != after[idx] {
          abort("AvoidReinterprets changed an unrelated function")
        }
      }
    _ => abort("AvoidReinterprets mixed fixture lacks code")
  }
  it.bench(fn() { it.keep(avoid_reinterprets_run_module_pass(fixture)) })
}

///|
test "bench AvoidReinterprets mixed funcs=128" (it : @bench.T) {
  ar_lazy_copy_perf_bench(it, 128)
}

///|
test "bench AvoidReinterprets mixed funcs=256" (it : @bench.T) {
  ar_lazy_copy_perf_bench(it, 256)
}
