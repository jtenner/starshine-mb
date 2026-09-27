///|
fn tc_fork_bench(
  it : @bench.T,
  width : Int,
  writes : Bool,
  reference : Bool,
  body_count? : Int = 2,
) -> Unit {
  let mask = Array::make(width, true)
  mask[0] = false
  let body = if writes {
    [Instruction::local_set(LocalIdx::new(0U))]
  } else {
    Array::make(body_count, Instruction::nop())
  }
  if tc_fork_initialized_for_body(mask, body) != mask {
    abort("fork changed initialization")
  }
  it.bench(fn() {
    for _ in 0..<128 {
      it.keep(
        if reference {
          mask.copy()
        } else {
          tc_fork_initialized_for_body(mask, body)
        },
      )
    }
  })
}

///|
test "bench reuse-campaign initialization fork width=4096 reference" (
  it : @bench.T,
) {
  tc_fork_bench(it, 4096, false, true)
}

///|
test "bench reuse-campaign initialization fork width=4096 borrowed" (
  it : @bench.T,
) {
  tc_fork_bench(it, 4096, false, false)
}

///|
test "bench reuse-campaign initialization fork writes width=4096 reference" (
  it : @bench.T,
) {
  tc_fork_bench(it, 4096, true, true)
}

///|
test "bench reuse-campaign initialization fork writes width=4096 candidate" (
  it : @bench.T,
) {
  tc_fork_bench(it, 4096, true, false)
}

///|
test "bench reuse-campaign initialization fork width=17 reference" (
  it : @bench.T,
) {
  tc_fork_bench(it, 17, false, true)
}

///|
test "bench reuse-campaign initialization fork width=17 candidate" (
  it : @bench.T,
) {
  tc_fork_bench(it, 17, false, false)
}

///|
test "bench reuse-campaign initialization fork width=128 body=2 reference" (
  it : @bench.T,
) {
  tc_fork_bench(it, 128, false, true, body_count=2)
}

///|
test "bench reuse-campaign initialization fork width=128 body=2 candidate" (
  it : @bench.T,
) {
  tc_fork_bench(it, 128, false, false, body_count=2)
}

///|
test "bench reuse-campaign initialization fork width=4096 body=32 reference" (
  it : @bench.T,
) {
  tc_fork_bench(it, 4096, false, true, body_count=32)
}

///|
test "bench reuse-campaign initialization fork width=4096 body=32 candidate" (
  it : @bench.T,
) {
  tc_fork_bench(it, 4096, false, false, body_count=32)
}

///|
test "bench reuse-campaign initialization fork width=4096 body=64 reference" (
  it : @bench.T,
) {
  tc_fork_bench(it, 4096, false, true, body_count=64)
}

///|
test "bench reuse-campaign initialization fork width=4096 body=64 candidate" (
  it : @bench.T,
) {
  tc_fork_bench(it, 4096, false, false, body_count=64)
}
