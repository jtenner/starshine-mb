///|
fn dae_batch_signature_bench(
  it : @bench.T,
  count : Int32,
  reference : Bool,
) -> Unit {
  let input = dae_signature_fixture(count)
  let indices = dae_collect_func_type_indices(input)
  let expected = dae_batch_signature_reference(input, 0, count, indices)
  if dae_collect_defined_function_types(input, 0, count, indices) != expected {
    abort("DAE batch signature mismatch")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae_batch_signature_reference(input, 0, count, indices)
      } else {
        dae_collect_defined_function_types(input, 0, count, indices)
      },
    )
  })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae batch signatures count=64 reference" (it : @bench.T) {
  dae_batch_signature_bench(it, 64, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae batch signatures count=64 indexed" (it : @bench.T) {
  dae_batch_signature_bench(it, 64, false)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae batch signatures count=1024 reference" (it : @bench.T) {
  dae_batch_signature_bench(it, 1024, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae batch signatures count=1024 indexed" (it : @bench.T) {
  dae_batch_signature_bench(it, 1024, false)
}
