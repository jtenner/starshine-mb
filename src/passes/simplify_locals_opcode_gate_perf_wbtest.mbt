///|
fn sl_opcode_gate_cached_run(
  kind : Int32,
  body : Array[@lib.Instruction],
  stats : RawSimplifyLocalsGateStats,
) -> (Array[@lib.Instruction], Int32) {
  match kind {
    0 =>
      run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences(
        body,
        stats~,
      )
    1 =>
      run_hot_pipeline_raw_simplify_locals_rewrite_alternating_simd_recurrences(
        body,
        stats~,
      )
    2 =>
      run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries(
        body,
        stats~,
      )
    3 =>
      run_hot_pipeline_raw_simplify_locals_rewrite_commutative_simd_carriers(
        body,
        stats~,
      )
    _ => abort("unknown cached opcode gate control")
  }
}

///|
fn sl_opcode_gate_bench(
  it : @bench.T,
  kind : Int32,
  width : Int32,
  reference : Bool,
  active~ : Bool = false,
) -> Unit {
  let input = if active {
    sl_opcode_gate_active_fixture(kind)
  } else {
    sl_opcode_gate_scalar_fixture(width)
  }
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  // The dispatcher already owns this immutable shape summary. Measure its
  // reuse here; whole-command controls include the expanded census cost.
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(
    @lib.Locals::empty(),
    body,
  )
  let expected = sl_opcode_gate_run(kind, body, true)
  let actual = sl_opcode_gate_run(kind, body, false)
  if expected != actual {
    abort("opcode gate changed rewrite output or count")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        sl_opcode_gate_run(kind, body, true)
      } else {
        sl_opcode_gate_cached_run(kind, body, stats)
      },
    )
  })
}

///|
test "bench cleanup opcode gate additive scalar width=1 reference" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 0, 1, true)
}

///|
test "bench cleanup opcode gate additive scalar width=1 selected" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 0, 1, false)
}

///|
test "bench cleanup opcode gate additive scalar width=128 reference" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 0, 128, true)
}

///|
test "bench cleanup opcode gate additive scalar width=128 selected" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 0, 128, false)
}

///|
test "bench cleanup opcode gate additive active reference" (it : @bench.T) {
  sl_opcode_gate_bench(it, 0, 1, true, active=true)
}

///|
test "bench cleanup opcode gate additive active selected" (it : @bench.T) {
  sl_opcode_gate_bench(it, 0, 1, false, active=true)
}

///|
test "bench cleanup opcode gate alternating scalar width=1 reference" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 1, 1, true)
}

///|
test "bench cleanup opcode gate alternating scalar width=1 selected" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 1, 1, false)
}

///|
test "bench cleanup opcode gate alternating scalar width=128 reference" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 1, 128, true)
}

///|
test "bench cleanup opcode gate alternating scalar width=128 selected" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 1, 128, false)
}

///|
test "bench cleanup opcode gate alternating active reference" (it : @bench.T) {
  sl_opcode_gate_bench(it, 1, 1, true, active=true)
}

///|
test "bench cleanup opcode gate alternating active selected" (it : @bench.T) {
  sl_opcode_gate_bench(it, 1, 1, false, active=true)
}

///|
test "bench cleanup opcode gate rotate scalar width=1 reference" (it : @bench.T) {
  sl_opcode_gate_bench(it, 2, 1, true)
}

///|
test "bench cleanup opcode gate rotate scalar width=1 selected" (it : @bench.T) {
  sl_opcode_gate_bench(it, 2, 1, false)
}

///|
test "bench cleanup opcode gate rotate scalar width=128 reference" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 2, 128, true)
}

///|
test "bench cleanup opcode gate rotate scalar width=128 selected" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 2, 128, false)
}

///|
test "bench cleanup opcode gate rotate active reference" (it : @bench.T) {
  sl_opcode_gate_bench(it, 2, 1, true, active=true)
}

///|
test "bench cleanup opcode gate rotate active selected" (it : @bench.T) {
  sl_opcode_gate_bench(it, 2, 1, false, active=true)
}

///|
test "bench cleanup opcode gate carrier scalar width=1 reference" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 3, 1, true)
}

///|
test "bench cleanup opcode gate carrier scalar width=1 selected" (it : @bench.T) {
  sl_opcode_gate_bench(it, 3, 1, false)
}

///|
test "bench cleanup opcode gate carrier scalar width=128 reference" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 3, 128, true)
}

///|
test "bench cleanup opcode gate carrier scalar width=128 selected" (
  it : @bench.T,
) {
  sl_opcode_gate_bench(it, 3, 128, false)
}

///|
test "bench cleanup opcode gate carrier active reference" (it : @bench.T) {
  sl_opcode_gate_bench(it, 3, 1, true, active=true)
}

///|
test "bench cleanup opcode gate carrier active selected" (it : @bench.T) {
  sl_opcode_gate_bench(it, 3, 1, false, active=true)
}
