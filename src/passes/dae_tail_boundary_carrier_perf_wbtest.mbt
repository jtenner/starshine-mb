///|
fn dae_tail_carrier_bench(
  it : @bench.T,
  width : Int32,
  mode : Int32,
) -> Unit raise {
  let input = dae_tail_carrier_fixture(width, mode)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let funcs = input.code_sec.unwrap().0
  assert_eq(
    dae_tail_carrier_flags(dae_tail_call_boundary_evidence(funcs)),
    dae_tail_carrier_expected(mode),
  )
  it.bench(fn() {
    let evidence = dae_tail_call_boundary_evidence(funcs)
    // Keep a primitive so this measurement does not box the value carrier.
    let flags = (if evidence.has_direct_tail_call { 1 } else { 0 }) +
      (if evidence.has_indirect_tail_call { 2 } else { 0 }) +
      (if evidence.blocks_direct_call_rewrite { 4 } else { 0 }) +
      (if evidence.blocks_result_removal { 8 } else { 0 })
    it.keep(flags)
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native cold tail carrier control")
test "bench tail carrier cold32" (it : @bench.T) {
  dae_tail_carrier_bench(it, 32, 0)
}

///|
#skip("paired native active tail carrier control")
test "bench tail carrier active32" (it : @bench.T) {
  dae_tail_carrier_bench(it, 32, 1)
}

///|
#skip("paired native inactive tail carrier control")
test "bench tail carrier dead32" (it : @bench.T) {
  dae_tail_carrier_bench(it, 32, 3)
}

///|
#skip("paired native cold tail carrier stress")
test "bench tail carrier cold4096" (it : @bench.T) {
  dae_tail_carrier_bench(it, 4096, 0)
}

///|
#skip("paired native active tail carrier stress")
test "bench tail carrier active4096" (it : @bench.T) {
  dae_tail_carrier_bench(it, 4096, 1)
}

///|
#skip("paired native inactive tail carrier stress")
test "bench tail carrier dead4096" (it : @bench.T) {
  dae_tail_carrier_bench(it, 4096, 3)
}
