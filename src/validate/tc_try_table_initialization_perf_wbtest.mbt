///|
fn tc_try_initialization_bench(
  it : @bench.T,
  width : Int32,
  writes : Bool,
  reference : Bool,
  already_initialized~ : Bool = false,
) -> Unit raise {
  let entry = tc_try_mask_fixture(width)
  if already_initialized {
    entry.initialized_locals.fill(true)
  }
  let body = if writes {
    Expr::new([
      Instruction::i32_const(I32(7)),
      Instruction::local_set(LocalIdx::new((width - 1).to_uint())),
      Instruction::local_get(LocalIdx::new((width - 1).to_uint())),
      Instruction::drop(),
    ])
  } else {
    Expr::new([Instruction::nop()])
  }
  let block_type = BlockType::void_()
  let catches = [Catch::all(LabelIdx::new(0U))]
  ignore(
    tc_try_mask_assert_equivalent(entry, block_type, catches, body).unwrap(),
  )
  // A count of one keeps each calibrated sample visible without winsorization.
  for sample in 0..<7 {
    it.bench(
      fn() {
        let state = tc_state_with_stack(entry, [])
        let output = if reference {
          tc_try_table_owned_reference(state, block_type, catches, body)
        } else {
          typecheck_try_table(state, block_type, catches, body)
        }
        it.keep(output)
      },
      name="raw-\{sample}",
      count=1,
    )
  }
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=0 unchanged reference" (it : @bench.T) {
  tc_try_initialization_bench(it, 0, false, true)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=0 unchanged current" (it : @bench.T) {
  tc_try_initialization_bench(it, 0, false, false)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=1 unchanged reference" (it : @bench.T) {
  tc_try_initialization_bench(it, 1, false, true)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=1 unchanged current" (it : @bench.T) {
  tc_try_initialization_bench(it, 1, false, false)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=1 writes reference" (it : @bench.T) {
  tc_try_initialization_bench(it, 1, true, true)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=1 writes current" (it : @bench.T) {
  tc_try_initialization_bench(it, 1, true, false)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=256 unchanged reference" (it : @bench.T) {
  tc_try_initialization_bench(it, 256, false, true)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=256 unchanged current" (it : @bench.T) {
  tc_try_initialization_bench(it, 256, false, false)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=256 writes reference" (it : @bench.T) {
  tc_try_initialization_bench(it, 256, true, true)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=256 writes current" (it : @bench.T) {
  tc_try_initialization_bench(it, 256, true, false)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=4096 unchanged reference" (it : @bench.T) {
  tc_try_initialization_bench(it, 4096, false, true)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=4096 unchanged current" (it : @bench.T) {
  tc_try_initialization_bench(it, 4096, false, false)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=4096 writes reference" (it : @bench.T) {
  tc_try_initialization_bench(it, 4096, true, true)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=4096 writes current" (it : @bench.T) {
  tc_try_initialization_bench(it, 4096, true, false)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=1 idempotent reference" (it : @bench.T) {
  tc_try_initialization_bench(it, 1, true, true, already_initialized=true)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=1 idempotent current" (it : @bench.T) {
  tc_try_initialization_bench(it, 1, true, false, already_initialized=true)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=4096 idempotent reference" (it : @bench.T) {
  tc_try_initialization_bench(it, 4096, true, true, already_initialized=true)
}

///|
#skip("paired native validator benchmark; run in the dedicated performance lane")
test "bench try initialization width=4096 idempotent current" (it : @bench.T) {
  tc_try_initialization_bench(it, 4096, true, false, already_initialized=true)
}
