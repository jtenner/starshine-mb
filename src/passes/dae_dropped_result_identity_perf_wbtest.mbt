///|
fn dae_dropped_identity_bench(
  it : @bench.T,
  count : Int,
  nested : Bool,
  active : Bool,
  reference : Bool,
) -> Unit {
  let body : Array[@lib.Instruction] = []
  for index = 0; index < count; index = index + 1 {
    body.push(
      if nested {
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        )
      } else {
        @lib.Instruction::nop()
      },
    )
  }
  if active {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
    body.push(@lib.Instruction::drop())
  }
  let expected = dae_dropped_result_cleanup_reference(body, 0, false)
  if dae_rewrite_dropped_result_calls_with_policy_instrs(body, 0, false) !=
    expected {
    abort("lazy DAE cleanup changed result")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae_dropped_result_cleanup_reference(body, 0, false)
      } else {
        dae_rewrite_dropped_result_calls_with_policy_instrs(body, 0, false)
      },
    )
  })
}

///|
test "bench DAE dropped cleanup count=4 flat unchanged reference" (
  it : @bench.T,
) {
  dae_dropped_identity_bench(it, 4, false, false, true)
}

///|
test "bench DAE dropped cleanup count=4 flat unchanged lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 4, false, false, false)
}

///|
test "bench DAE dropped cleanup count=4 flat active reference" (it : @bench.T) {
  dae_dropped_identity_bench(it, 4, false, true, true)
}

///|
test "bench DAE dropped cleanup count=4 flat active lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 4, false, true, false)
}

///|
test "bench DAE dropped cleanup count=4 nested unchanged reference" (
  it : @bench.T,
) {
  dae_dropped_identity_bench(it, 4, true, false, true)
}

///|
test "bench DAE dropped cleanup count=4 nested unchanged lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 4, true, false, false)
}

///|
test "bench DAE dropped cleanup count=4 nested active reference" (it : @bench.T) {
  dae_dropped_identity_bench(it, 4, true, true, true)
}

///|
test "bench DAE dropped cleanup count=4 nested active lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 4, true, true, false)
}

///|
test "bench DAE dropped cleanup count=128 flat unchanged reference" (
  it : @bench.T,
) {
  dae_dropped_identity_bench(it, 128, false, false, true)
}

///|
test "bench DAE dropped cleanup count=128 flat unchanged lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 128, false, false, false)
}

///|
test "bench DAE dropped cleanup count=128 flat active reference" (it : @bench.T) {
  dae_dropped_identity_bench(it, 128, false, true, true)
}

///|
test "bench DAE dropped cleanup count=128 flat active lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 128, false, true, false)
}

///|
test "bench DAE dropped cleanup count=128 nested unchanged reference" (
  it : @bench.T,
) {
  dae_dropped_identity_bench(it, 128, true, false, true)
}

///|
test "bench DAE dropped cleanup count=128 nested unchanged lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 128, true, false, false)
}

///|
test "bench DAE dropped cleanup count=128 nested active reference" (
  it : @bench.T,
) {
  dae_dropped_identity_bench(it, 128, true, true, true)
}

///|
test "bench DAE dropped cleanup count=128 nested active lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 128, true, true, false)
}

///|
test "bench DAE dropped cleanup count=4096 flat unchanged reference" (
  it : @bench.T,
) {
  dae_dropped_identity_bench(it, 4096, false, false, true)
}

///|
test "bench DAE dropped cleanup count=4096 flat unchanged lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 4096, false, false, false)
}

///|
test "bench DAE dropped cleanup count=4096 flat active reference" (
  it : @bench.T,
) {
  dae_dropped_identity_bench(it, 4096, false, true, true)
}

///|
test "bench DAE dropped cleanup count=4096 flat active lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 4096, false, true, false)
}

///|
test "bench DAE dropped cleanup count=4096 nested unchanged reference" (
  it : @bench.T,
) {
  dae_dropped_identity_bench(it, 4096, true, false, true)
}

///|
test "bench DAE dropped cleanup count=4096 nested unchanged lazy" (
  it : @bench.T,
) {
  dae_dropped_identity_bench(it, 4096, true, false, false)
}

///|
test "bench DAE dropped cleanup count=4096 nested active reference" (
  it : @bench.T,
) {
  dae_dropped_identity_bench(it, 4096, true, true, true)
}

///|
test "bench DAE dropped cleanup count=4096 nested active lazy" (it : @bench.T) {
  dae_dropped_identity_bench(it, 4096, true, true, false)
}
