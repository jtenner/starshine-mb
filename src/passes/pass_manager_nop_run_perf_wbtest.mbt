///|
fn nop_run_bench(it : @bench.T, width : Int, kind : Int) -> Unit {
  let body = Array::makei(width, fn(i) {
    if kind == 0 || (kind == 2 && i % 2 == 0) {
      @lib.Instruction::nop()
    } else {
      @lib.Instruction::i32_const(@lib.I32::new(i))
    }
  })
  it.bench(fn() {
    let (output, changed) = run_hot_pipeline_simplify_locals_lowered_hoist_nops_across_dupable_values_with_changed(
      body,
    )
    it.keep(output)
    it.keep(changed)
  })
}

///|
test "bench nop-run tiny" (it : @bench.T) {
  nop_run_bench(it, 4, 1)
}

///|
test "bench nop-run nops128" (it : @bench.T) {
  nop_run_bench(it, 128, 0)
}

///|
test "bench nop-run nops1024" (it : @bench.T) {
  nop_run_bench(it, 1024, 0)
}

///|
test "bench nop-run values128" (it : @bench.T) {
  nop_run_bench(it, 128, 1)
}

///|
test "bench nop-run values1024" (it : @bench.T) {
  nop_run_bench(it, 1024, 1)
}

///|
test "bench nop-run mixed1024" (it : @bench.T) {
  nop_run_bench(it, 1024, 2)
}
