///|
fn cl_structured_live_bench(
  it : @bench.T,
  width : Int,
  repetitions : Int,
  reference : Bool,
) -> Unit {
  let (actions, liveness, types) = cl_structured_live_fixture(
    width, repetitions,
  )
  let expected = cl_structured_live_reference(actions, liveness, types, 2)
  if cl_compute_interferences(actions, liveness, types, 2).bits != expected.bits {
    abort("structured live benchmark mismatch")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        cl_structured_live_reference(actions, liveness, types, 2)
      } else {
        cl_compute_interferences(actions, liveness, types, 2)
      },
    )
  })
}

///|
test "bench coalesce structured dense scan locals=8" (it : @bench.T) {
  cl_structured_live_bench(it, 8, 8, true)
}

///|
test "bench coalesce structured member scan locals=8" (it : @bench.T) {
  cl_structured_live_bench(it, 8, 8, false)
}

///|
test "bench coalesce structured dense scan locals=2048" (it : @bench.T) {
  cl_structured_live_bench(it, 2048, 128, true)
}

///|
test "bench coalesce structured member scan locals=2048" (it : @bench.T) {
  cl_structured_live_bench(it, 2048, 128, false)
}
