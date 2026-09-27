///|
fn dae_signature_bench(it : @bench.T, count : Int, reference : Bool) -> Unit {
  let input = dae_signature_fixture(count)
  @validate.validate_module(input).unwrap()
  let indices = dae_collect_func_type_indices(input)
  let expected = indices.mapi(fn(index, _) {
    dae_resolve_func_type(input, indices, index)
  })
  if dae_snapshot_function_types(input, indices) != expected {
    abort("signature mismatch")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        indices.mapi(fn(index, _) {
          dae_resolve_func_type(input, indices, index)
        })
      } else {
        dae_snapshot_function_types(input, indices)
      },
    )
  })
}

///|
test "bench reuse-campaign dae signature lookup types=64 reference" (
  it : @bench.T,
) {
  dae_signature_bench(it, 64, true)
}

///|
test "bench reuse-campaign dae signature lookup types=64 indexed" (
  it : @bench.T,
) {
  dae_signature_bench(it, 64, false)
}

///|
test "bench reuse-campaign dae signature lookup types=1024 reference" (
  it : @bench.T,
) {
  dae_signature_bench(it, 1024, true)
}

///|
test "bench reuse-campaign dae signature lookup types=1024 indexed" (
  it : @bench.T,
) {
  dae_signature_bench(it, 1024, false)
}

///|
fn dae_sparse_signature_bench(it : @bench.T, reference : Bool) -> Unit {
  let fixture = dae_signature_fixture(1024)
  let indices = [@lib.TypeIdx::new(0U)]
  let input = fixture
    .with_func_sec(@lib.FuncSec::new(indices))
    .with_code_sec(@lib.CodeSec::new([fixture.code_sec.unwrap().0[0]]))
  @validate.validate_module(input).unwrap()
  if dae_snapshot_function_types(input, indices) !=
    [dae_resolve_func_type(input, indices, 0)] {
    abort("sparse signature mismatch")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        indices.mapi(fn(index, _) {
          dae_resolve_func_type(input, indices, index)
        })
      } else {
        dae_snapshot_function_types(input, indices)
      },
    )
  })
}

///|
test "bench reuse-campaign dae sparse signature types=1024 reference" (
  it : @bench.T,
) {
  dae_sparse_signature_bench(it, true)
}

///|
test "bench reuse-campaign dae sparse signature types=1024 indexed" (
  it : @bench.T,
) {
  dae_sparse_signature_bench(it, false)
}
