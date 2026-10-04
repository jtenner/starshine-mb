///|
fn oi_directize_storage_bench(
  it : @bench.T,
  width : Int,
  rewrite : Bool,
) -> Unit {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<width {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::drop())
  }
  if rewrite {
    body.push(@lib.Instruction::ref_func(@lib.FuncIdx::new(7U)))
    body.push(@lib.Instruction::call_ref(@lib.TypeIdx::new(3U)))
  }
  it.bench(fn() {
    it.keep(
      run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body(body),
    )
  })
}

///|
test "bench OI directization empty" (it : @bench.T) {
  oi_directize_storage_bench(it, 0, false)
}

///|
test "bench OI directization unchanged tiny" (it : @bench.T) {
  oi_directize_storage_bench(it, 8, false)
}

///|
test "bench OI directization unchanged wide" (it : @bench.T) {
  oi_directize_storage_bench(it, 512, false)
}

///|
test "bench OI directization late rewrite" (it : @bench.T) {
  oi_directize_storage_bench(it, 512, true)
}
