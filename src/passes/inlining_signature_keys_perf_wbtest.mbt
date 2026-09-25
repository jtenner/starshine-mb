///|
fn inl_signature_keys_perf_fixture(
  type_count : Int,
  func_count : Int,
) -> (@lib.Module, Array[@lib.TypeIdx]) {
  let rec_types : Array[@lib.RecType] = []
  for _ in 0..<type_count {
    rec_types.push(
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    )
  }
  let mod_ = @lib.Module::new().with_type_sec(@lib.TypeSec::new(rec_types))
  let type_idx = @lib.TypeIdx::new((type_count - 1).reinterpret_as_uint())
  (mod_, Array::make(func_count, type_idx))
}

///|
fn inl_signature_keys_perf_bench(
  it : @bench.T,
  type_count : Int,
  func_count : Int,
) -> Unit {
  let (mod_, indices) = inl_signature_keys_perf_fixture(type_count, func_count)
  let preflight = inl_build_func_signature_keys(mod_, indices, func_count)
  if preflight.length() != func_count ||
    preflight[0] != "p:r:" ||
    preflight[func_count - 1] != "p:r:" {
    abort("inlining signature-key fixture produced unexpected keys")
  }
  it.bench(fn() {
    it.keep(inl_build_func_signature_keys(mod_, indices, func_count))
  })
}

///|
test "bench inlining signature keys types=256 funcs=256" (it : @bench.T) {
  inl_signature_keys_perf_bench(it, 256, 256)
}

///|
test "bench inlining signature keys types=512 funcs=512" (it : @bench.T) {
  inl_signature_keys_perf_bench(it, 512, 512)
}

///|
test "inlining signature key builder matches resolver across grouped types" {
  let void_func = @lib.SubType::comp_type(@lib.CompType::func([], []))
  let i32_func = @lib.SubType::comp_type(
    @lib.CompType::func([@lib.ValType::i32()], []),
  )
  let mod_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(void_func),
      @lib.RecType::group([i32_func, void_func]),
    ]),
  )
  let indices = [
    @lib.TypeIdx::new(0U),
    @lib.TypeIdx::new(1U),
    @lib.TypeIdx::new(2U),
    @lib.TypeIdx::new(3U),
    @lib.TypeIdx::rec(0U),
  ]
  let actual = inl_build_func_signature_keys(mod_, indices, 6)
  for abs = 0; abs < actual.length(); abs = abs + 1 {
    @debug.assert_eq(actual[abs], inl_func_signature_key(mod_, indices, abs))
  }
}
