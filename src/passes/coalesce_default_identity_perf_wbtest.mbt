///|
fn cl_default_identity_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let actions : Array[CLAction] = []
  let types = Array::make(width, @lib.ValType::i32())
  let liveness = cl_compute_liveness(actions, width)
  if cl_default_identity_reference_compute(actions, liveness, types, 2).bits !=
    cl_compute_interferences(actions, liveness, types, 2).bits {
    abort("default identity matrix drift")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        cl_default_identity_reference_compute(actions, liveness, types, 2)
      } else {
        cl_compute_interferences(actions, liveness, types, 2)
      },
    )
  })
}

///|
test "bench coalesce repeated default formatting locals=8" (it : @bench.T) {
  cl_default_identity_bench(it, 8, true)
}

///|
test "bench coalesce cached default identities locals=8" (it : @bench.T) {
  cl_default_identity_bench(it, 8, false)
}

///|
test "bench coalesce repeated default formatting locals=2048" (it : @bench.T) {
  cl_default_identity_bench(it, 2048, true)
}

///|
test "bench coalesce cached default identities locals=2048" (it : @bench.T) {
  cl_default_identity_bench(it, 2048, false)
}
