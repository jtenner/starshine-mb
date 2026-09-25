///|
fn i64_lower_noop_perf_bench(it : @bench.T, function_count : Int) -> Unit {
  let fixture = il_no_target_perf_module(function_count)
  if i64_to_i32_lowering_run_module_pass(fixture) != fixture {
    abort("i64 lowering no-op fixture unexpectedly changed")
  }
  it.bench(fn() { it.keep(i64_to_i32_lowering_run_module_pass(fixture)) })
}

///|
test "bench I64ToI32Lowering no saturation funcs=128" (it : @bench.T) {
  i64_lower_noop_perf_bench(it, 128)
}

///|
test "bench I64ToI32Lowering no saturation funcs=256" (it : @bench.T) {
  i64_lower_noop_perf_bench(it, 256)
}

///|
test "I64ToI32Lowering preflight still lowers saturating conversion" {
  let source = "(module (func (param f32) (drop (i64.trunc_sat_f32_s (local.get 0)))))"
  let output = match
    pass_test_run_pipeline(source, ["flatten", "i64-to-i32-lowering"]) {
    Ok(output) => output
    Err(err) => fail("saturating conversion lowering failed: \{err}")
  }
  assert_eq(
    ca_test_opcode_count(output, @lib.Instruction::i64_trunc_sat_f32s()),
    0,
  )
  assert_true(@validate.validate_module(output).is_ok())
}
