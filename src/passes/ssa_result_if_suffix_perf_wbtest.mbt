///|
fn ssa_result_if_suffix_perf_body(count : Int) -> Array[@lib.Instruction] {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<count {
    body.push(@lib.Instruction::i32_const(0))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  }
  body.push(@lib.Instruction::i32_const(0))
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::i32_const(1)],
      Some([@lib.Instruction::i32_const(2)]),
    ),
  )
  body.push(@lib.Instruction::drop())
  body
}

///|
fn ssa_result_if_suffix_perf_bench(it : @bench.T, count : Int) -> Unit {
  let body = ssa_result_if_suffix_perf_body(count)
  ssa_result_if_suffix_perf_check_positive(2)
  ssa_result_if_suffix_perf_check_positive(32)
  ssa_result_if_suffix_perf_check_before_set()
  if run_hot_pipeline_raw_ssa_nomerge_has_result_if_crossing_local_lifetime(
      body,
    ) ||
    run_hot_pipeline_raw_ssa_nomerge_has_any_result_if_crossing_local_read(body) {
    abort("SSA result-If suffix fixture unexpectedly crosses a read")
  }
  it.bench(fn() {
    it.keep(
      run_hot_pipeline_raw_ssa_nomerge_has_result_if_crossing_local_lifetime(
        body,
      ),
    )
    it.keep(
      run_hot_pipeline_raw_ssa_nomerge_has_any_result_if_crossing_local_read(
        body,
      ),
    )
  })
}

///|
test "bench SSA result-If new short preflight" (it : @bench.T) {
  let body = ssa_result_if_suffix_perf_body(4)
  it.bench(fn() {
    it.keep(
      run_hot_pipeline_raw_ssa_nomerge_has_any_result_if_crossing_local_read(
        body,
      ),
    )
  })
}

///|
fn ssa_result_if_suffix_perf_check_positive(count : Int) -> Unit {
  let body = ssa_result_if_suffix_perf_body(count)
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::return_()],
      None,
    ),
  )
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  body.push(@lib.Instruction::drop())
  if !run_hot_pipeline_raw_ssa_nomerge_has_result_if_crossing_local_lifetime(
      body,
    ) ||
    !run_hot_pipeline_raw_ssa_nomerge_has_any_result_if_crossing_local_read(
      body,
    ) {
    abort("SSA result-If suffix fixture missed a crossing read")
  }
}

///|
test "SSA result-If suffix predicates preserve event order" {
  ssa_result_if_suffix_perf_check_positive(2)
  ssa_result_if_suffix_perf_check_positive(32)
}

///|
fn ssa_result_if_suffix_perf_check_before_set() -> Unit {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<32 {
    body.push(@lib.Instruction::nop())
  }
  body.push(@lib.Instruction::i32_const(0))
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::i32_const(1)],
      Some([@lib.Instruction::i32_const(2)]),
    ),
  )
  body.push(@lib.Instruction::drop())
  body.push(@lib.Instruction::i32_const(0))
  body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::return_()],
      None,
    ),
  )
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  body.push(@lib.Instruction::drop())
  if run_hot_pipeline_raw_ssa_nomerge_has_result_if_crossing_local_lifetime(
      body,
    ) ||
    run_hot_pipeline_raw_ssa_nomerge_has_any_result_if_crossing_local_read(body) {
    abort("SSA result-If suffix fixture crossed an event before its set")
  }
}

///|
test "SSA result-If suffix predicates ignore events before first local set" {
  ssa_result_if_suffix_perf_check_before_set()
}

///|
test "bench SSA result-If suffix preflight sets=256" (it : @bench.T) {
  ssa_result_if_suffix_perf_bench(it, 256)
}

///|
test "bench SSA result-If suffix preflight sets=512" (it : @bench.T) {
  ssa_result_if_suffix_perf_bench(it, 512)
}
