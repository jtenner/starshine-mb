///|
fn dae_reverse_signature_bench(
  it : @bench.T,
  types : Int,
  helpers : Int,
  active : Bool,
  reference : Bool,
) -> Unit {
  let input = dae_reverse_signature_fixture(types, helpers, active)
  let original = dae_collect_original_boundary_snapshot(input)
  let saved = @binary.encode_module(input).unwrap()
  let output = dae_literal_replay_fixture_run(input, original, [0])
  let expected = dae_literal_replay_fixture_run(
    input,
    original,
    [0],
    reuse_function_types=false,
  )
  if @binary.encode_module(output.mod_out).unwrap() !=
    @binary.encode_module(expected.mod_out).unwrap() ||
    output.changed != active {
    abort("reverse signature benchmark changed output or active admission")
  }
  @validate.validate_module(output.mod_out).unwrap()
  it.bench(fn() {
    it.keep(
      dae_literal_replay_fixture_run(
        input,
        original,
        [0],
        reuse_function_types=!reference,
      ),
    )
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("reverse signature benchmark mutated input")
  }
}

///|
test "bench DAE reverse signatures types=1 helpers=1 nonconstant reference" (
  it : @bench.T,
) {
  dae_reverse_signature_bench(it, 1, 1, false, true)
}

///|
test "bench DAE reverse signatures types=1 helpers=1 nonconstant snapshot" (
  it : @bench.T,
) {
  dae_reverse_signature_bench(it, 1, 1, false, false)
}

///|
test "bench DAE reverse signatures types=1 helpers=1 active reference" (
  it : @bench.T,
) {
  dae_reverse_signature_bench(it, 1, 1, true, true)
}

///|
test "bench DAE reverse signatures types=1 helpers=1 active snapshot" (
  it : @bench.T,
) {
  dae_reverse_signature_bench(it, 1, 1, true, false)
}

///|
test "bench DAE reverse signatures types=256 helpers=32 nonconstant reference" (
  it : @bench.T,
) {
  dae_reverse_signature_bench(it, 256, 32, false, true)
}

///|
test "bench DAE reverse signatures types=256 helpers=32 nonconstant snapshot" (
  it : @bench.T,
) {
  dae_reverse_signature_bench(it, 256, 32, false, false)
}

///|
test "bench DAE reverse signatures types=256 helpers=32 active reference" (
  it : @bench.T,
) {
  dae_reverse_signature_bench(it, 256, 32, true, true)
}

///|
test "bench DAE reverse signatures types=256 helpers=32 active snapshot" (
  it : @bench.T,
) {
  dae_reverse_signature_bench(it, 256, 32, true, false)
}
