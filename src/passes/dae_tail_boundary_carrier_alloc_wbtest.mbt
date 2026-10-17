///|
// One target call per selected test lets Callgrind count direct carrier-to-
// allocator edges. Input parsing/validation/encoding remains outside that edge.
fn dae_tail_carrier_allocation_probe(mode : Int32) -> Unit raise {
  let input = dae_tail_carrier_fixture(4096, mode)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let evidence = dae_tail_call_boundary_evidence(input.code_sec.unwrap().0)
  assert_eq(dae_tail_carrier_flags(evidence), dae_tail_carrier_expected(mode))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  println("@TAIL_CARRIER_BYTES mode=\{mode} bytes=\{saved.to_array()}")
}

///|
#skip("Callgrind one-call cold carrier allocation proof")
test "allocation tail carrier cold4096" {
  dae_tail_carrier_allocation_probe(0)
}

///|
#skip("Callgrind one-call active carrier allocation proof")
test "allocation tail carrier active4096" {
  dae_tail_carrier_allocation_probe(1)
}

///|
#skip("Callgrind one-call inactive carrier allocation proof")
test "allocation tail carrier dead4096" {
  dae_tail_carrier_allocation_probe(3)
}
