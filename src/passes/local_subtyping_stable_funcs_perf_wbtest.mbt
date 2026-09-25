///|
fn ls_stable_funcs_perf_fixture(
  chain_count : Int,
  stable_count : Int,
) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string("(module\n")
  wat.write_string("(type $base (sub (struct)))\n")
  wat.write_string("(type $child (sub $base (struct)))\n")
  wat.write_string("(func $chain")
  for _ in 0..<chain_count {
    wat.write_string(" (local (ref null $base))")
  }
  wat.write_string(" ref.null $child local.set 0")
  for idx in 1..<chain_count {
    wat.write_string(" local.get \{idx - 1} local.set \{idx}")
  }
  wat.write_string(" local.get \{chain_count - 1} drop)\n")
  for _ in 0..<stable_count {
    wat.write_string("(func")
    for _ in 0..<32 {
      wat.write_string(" nop")
    }
    wat.write_string(")\n")
  }
  wat.write_string(")")
  pass_test_module_from_wat(wat.to_string())
}

///|
fn ls_stable_funcs_perf_bench(it : @bench.T, stable_count : Int) -> Unit {
  let fixture = ls_stable_funcs_perf_fixture(16, stable_count)
  let output = local_subtyping_run_module_pass(fixture)
  if output == fixture || @validate.validate_module(output).is_err() {
    abort("LocalSubtyping stable-function fixture did not refine validly")
  }
  it.bench(fn() { it.keep(local_subtyping_run_module_pass(fixture)) })
}

///|
test "LocalSubtyping stable-function skip preserves chain refinement" {
  let fixture = ls_stable_funcs_perf_fixture(8, 4)
  let output = local_subtyping_run_module_pass(fixture)
  let @lib.CodeSec(before) = fixture.code_sec.unwrap()
  let @lib.CodeSec(after) = output.code_sec.unwrap()
  let @lib.Func(locals, _) = after[0]
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  for idx in 0..<8 {
    assert_eq(locals[idx], expected)
  }
  for idx in 1..<after.length() {
    assert_eq(after[idx], before[idx])
  }
}

///|
test "bench LocalSubtyping stable funcs=64" (it : @bench.T) {
  ls_stable_funcs_perf_bench(it, 64)
}

///|
test "bench LocalSubtyping stable funcs=128" (it : @bench.T) {
  ls_stable_funcs_perf_bench(it, 128)
}
