///|
fn dae_validation_reuse_bench(
  it : @bench.T,
  siblings : Int32,
  reference : Bool,
) -> Unit raise {
  let input = dae_validation_reuse_fixture(siblings)
  let saved = @binary.encode_module(input).unwrap()
  let (expected, expected_effects, _) = dae_validation_reuse_round(input, true)
  let (actual, effects, _) = dae_validation_reuse_round(input, false)
  assert_true(actual.changed && expected.changed)
  assert_eq(effects, expected_effects)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  @validate.validate_module(actual.mod_out).unwrap()
  it.bench(fn() { it.keep(dae_validation_reuse_round(input, reference)) })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native validation reuse cost; dedicated performance lane")
test "bench DAE validation reuse siblings=0 double gate" (it : @bench.T) {
  dae_validation_reuse_bench(it, 0, true)
}

///|
#skip("paired native validation reuse cost; dedicated performance lane")
test "bench DAE validation reuse siblings=0 local report" (it : @bench.T) {
  dae_validation_reuse_bench(it, 0, false)
}

///|
#skip("paired native validation reuse cost; dedicated performance lane")
test "bench DAE validation reuse siblings=32 double gate" (it : @bench.T) {
  dae_validation_reuse_bench(it, 32, true)
}

///|
#skip("paired native validation reuse cost; dedicated performance lane")
test "bench DAE validation reuse siblings=32 local report" (it : @bench.T) {
  dae_validation_reuse_bench(it, 32, false)
}
