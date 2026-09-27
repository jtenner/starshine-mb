///|
fn inl_retention_signature_bench(
  it : @bench.T,
  count : Int,
  retain : Bool,
) -> Unit {
  let (base, indices) = inl_signature_keys_perf_fixture(count, count)
  let mod_ = base
    .with_func_sec(@lib.FuncSec::new(indices))
    .with_code_sec(
      @lib.CodeSec::new(
        Array::makei(count, fn(_) {
          @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
        }),
      ),
    )
  let infos = inl_build_function_infos(mod_)
  let touched = Array::make(count, true)
  let quotas : @hashmap.HashMap[String, Int] = @hashmap.new()
  if retain {
    quotas.set("p:r:", 1)
  }
  let result = inl_remove_dead_inlined_helpers(
    mod_, infos, touched, touched, quotas,
  )
  if result.mod_out.code_sec.unwrap().0.length() != (if retain { 1 } else { 0 }) {
    abort("retention benchmark removed the wrong helpers")
  }
  it.bench(fn() {
    it.keep(
      inl_remove_dead_inlined_helpers(mod_, infos, touched, touched, quotas),
    )
  })
}

///|
test "bench campaign retention funcs=256 no quota" (it : @bench.T) {
  inl_retention_signature_bench(it, 256, false)
}

///|
test "bench campaign retention funcs=256 quota" (it : @bench.T) {
  inl_retention_signature_bench(it, 256, true)
}

///|
test "bench campaign retention funcs=512 no quota" (it : @bench.T) {
  inl_retention_signature_bench(it, 512, false)
}

///|
test "bench campaign retention funcs=512 quota" (it : @bench.T) {
  inl_retention_signature_bench(it, 512, true)
}
