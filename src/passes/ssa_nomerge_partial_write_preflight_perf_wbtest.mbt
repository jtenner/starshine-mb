///|
fn ssa_nomerge_partial_write_preflight_perf_body(
  pair_count : Int,
) -> Array[@lib.Instruction] {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<pair_count {
    body.push(@lib.Instruction::i32_const(1))
    body.push(@lib.Instruction::local_tee(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
  }
  body
}

///|
fn ssa_nomerge_partial_write_preflight_perf_bench(
  it : @bench.T,
  pair_count : Int,
) -> Unit {
  let body = ssa_nomerge_partial_write_preflight_perf_body(pair_count)
  if run_hot_pipeline_raw_ssa_nomerge_has_structured_partial_write_tee_lifetime(
      body, 0,
    ) {
    abort("SSA-nomerge no-if fixture unexpectedly has a partial-write lifetime")
  }
  it.bench(fn() {
    it.keep(
      run_hot_pipeline_raw_ssa_nomerge_has_structured_partial_write_tee_lifetime(
        body, 0,
      ),
    )
  })
}

///|
test "bench SSA-nomerge partial-write preflight pairs=256" (it : @bench.T) {
  ssa_nomerge_partial_write_preflight_perf_bench(it, 256)
}

///|
test "bench SSA-nomerge partial-write preflight pairs=512" (it : @bench.T) {
  ssa_nomerge_partial_write_preflight_perf_bench(it, 512)
}

///|
test "SSA-nomerge partial-write preflight observes first later if" {
  let hazardous_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(2),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    ],
    None,
  )
  let prefix = [
    @lib.Instruction::i32_const(1),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let positive = prefix + [hazardous_if]
  assert_true(
    run_hot_pipeline_raw_ssa_nomerge_has_structured_partial_write_tee_lifetime(
      positive, 0,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_ssa_nomerge_has_structured_partial_write_tee_lifetime(
      positive, 1,
    ),
  )
  let first_if_is_safe = prefix +
    [@lib.Instruction::if_(@lib.BlockType::void_(), [], None), hazardous_if]
  assert_false(
    run_hot_pipeline_raw_ssa_nomerge_has_structured_partial_write_tee_lifetime(
      first_if_is_safe, 0,
    ),
  )
}
