///|
fn dae2_legacy_setup_bench(
  it : @bench.T,
  count : Int,
  active : Bool,
  reference : Bool,
) -> Unit raise {
  let input = dae2_handler_admission_fixture(count, active, true)
  let bytes = @binary.encode_module(input).unwrap()
  let expected = dae2_legacy_setup_reference(input).unwrap()
  let actual = dae2_prepare_legacy_handlers(input).unwrap()
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  @validate.validate_module(actual).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), bytes)
  it.bench(fn() {
    it.keep(
      if reference {
        dae2_legacy_setup_reference(input)
      } else {
        dae2_prepare_legacy_handlers(input)
      },
    )
  })
}

///|
test "bench legacy setup count=1 cold V81 predecessor" (it : @bench.T) {
  dae2_legacy_setup_bench(it, 1, false, true)
}

///|
test "bench legacy setup count=1 cold lazy" (it : @bench.T) {
  dae2_legacy_setup_bench(it, 1, false, false)
}

///|
test "bench legacy setup count=64 cold V81 predecessor" (it : @bench.T) {
  dae2_legacy_setup_bench(it, 64, false, true)
}

///|
test "bench legacy setup count=64 cold lazy" (it : @bench.T) {
  dae2_legacy_setup_bench(it, 64, false, false)
}

///|
test "bench legacy setup count=4096 cold V81 predecessor" (it : @bench.T) {
  dae2_legacy_setup_bench(it, 4096, false, true)
}

///|
test "bench legacy setup count=4096 cold lazy" (it : @bench.T) {
  dae2_legacy_setup_bench(it, 4096, false, false)
}

///|
test "bench legacy setup count=64 active V81 predecessor" (it : @bench.T) {
  dae2_legacy_setup_bench(it, 64, true, true)
}

///|
test "bench legacy setup count=64 active lazy" (it : @bench.T) {
  dae2_legacy_setup_bench(it, 64, true, false)
}
