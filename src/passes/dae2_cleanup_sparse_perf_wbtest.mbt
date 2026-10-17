///|
fn dae2_cleanup_sparse_bench(
  it : @bench.T,
  count : Int32,
  dense : Bool,
  reference~ : Bool = false,
) -> Unit {
  let active = "(func (result i32) (local i32) i32.const 7 local.set 0 local.get 0)"
  let retained = "(func (param i32) (local i32) local.get 0 local.set 1 local.get 1 drop local.get 0 local.set 1 local.get 1 drop)"
  let input = pass_test_module_from_wat(
    "(module \{active} \{Array::make(count, if dense { active } else { retained }).join(" ")})",
  )
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  if output.code_sec.unwrap().0.length() != count + 1 {
    abort("capture cleanup changed the function count")
  }
  let expected = dae2_cleanup_sparse_reference(input)
  if output != expected {
    abort("per-function capture admission changed module contents")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae2_cleanup_sparse_reference(input)
      } else {
        dae2_cleanup_captures(input)
      },
    )
  })
}

///|
test "bench DAE2 capture cleanup sparse siblings=32" (it : @bench.T) {
  dae2_cleanup_sparse_bench(it, 32, false)
}

///|
test "bench DAE2 capture cleanup sparse siblings=512" (it : @bench.T) {
  dae2_cleanup_sparse_bench(it, 512, false)
}

///|
test "bench DAE2 capture cleanup dense siblings=32" (it : @bench.T) {
  dae2_cleanup_sparse_bench(it, 32, true)
}

///|
test "bench DAE2 capture cleanup dense siblings=512" (it : @bench.T) {
  dae2_cleanup_sparse_bench(it, 512, true)
}

///|
test "bench DAE2 capture cleanup sparse siblings=32 reference" (it : @bench.T) {
  dae2_cleanup_sparse_bench(it, 32, false, reference=true)
}

///|
test "bench DAE2 capture cleanup dense siblings=32 reference" (it : @bench.T) {
  dae2_cleanup_sparse_bench(it, 32, true, reference=true)
}

///|
test "bench DAE2 capture cleanup sparse siblings=512 reference" (it : @bench.T) {
  dae2_cleanup_sparse_bench(it, 512, false, reference=true)
}

///|
test "bench DAE2 capture cleanup dense siblings=512 reference" (it : @bench.T) {
  dae2_cleanup_sparse_bench(it, 512, true, reference=true)
}
