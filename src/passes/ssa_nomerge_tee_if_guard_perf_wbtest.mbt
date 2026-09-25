///|
fn ssa_tee_if_guard_fixture(
  prefixes : Int,
  distinct_targets : Bool,
) -> Array[@lib.Instruction] {
  let instrs : Array[@lib.Instruction] = []
  for idx in 0..<prefixes {
    instrs.push(@lib.Instruction::i32_const(@lib.I32(idx)))
    instrs.push(
      @lib.Instruction::local_tee(
        @lib.LocalIdx::new(
          if distinct_targets {
            (idx + 1).to_uint()
          } else {
            1U
          },
        ),
      ),
    )
    instrs.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
  }
  let then_body = Array::make(512, @lib.Instruction::nop())
  then_body.push(
    @lib.Instruction::local_get(@lib.LocalIdx::new((prefixes + 1).to_uint())),
  )
  then_body.push(@lib.Instruction::drop())
  instrs.push(@lib.Instruction::i32_const(@lib.I32(1)))
  instrs.push(@lib.Instruction::if_(@lib.BlockType::void_(), then_body, None))
  instrs
}

///|
fn ssa_tee_if_guard_bench(
  it : @bench.T,
  prefixes : Int,
  distinct_targets : Bool,
) -> Unit {
  let fixture = ssa_tee_if_guard_fixture(prefixes, distinct_targets)
  if run_hot_pipeline_raw_ssa_nomerge_has_structured_partial_write_tee_lifetime(
      fixture, 0,
    ) {
    abort("SSA tee/If negative fixture unexpectedly matched")
  }
  it.bench(fn() {
    it.keep(
      run_hot_pipeline_raw_ssa_nomerge_has_structured_partial_write_tee_lifetime(
        fixture, 0,
      ),
    )
  })
}

///|
test "bench SSA tee/If guard same target prefixes=64" (it : @bench.T) {
  ssa_tee_if_guard_bench(it, 64, false)
}

///|
test "bench SSA tee/If guard distinct targets prefixes=128" (it : @bench.T) {
  ssa_tee_if_guard_bench(it, 128, true)
}

///|
test "SSA tee/If guard requires read and write in one arm" {
  let prefix = [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ]
  let reads = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let writes = [
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let then_match = prefix.copy()
  let then_body = reads.copy()
  then_body.append(writes)
  then_match.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
  )
  assert_true(
    run_hot_pipeline_raw_ssa_nomerge_has_structured_partial_write_tee_lifetime(
      then_match, 0,
    ),
  )
  let split_arms = prefix.copy()
  split_arms.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), reads, Some(writes)),
  )
  assert_false(
    run_hot_pipeline_raw_ssa_nomerge_has_structured_partial_write_tee_lifetime(
      split_arms, 0,
    ),
  )
}
