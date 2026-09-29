///|
fn dae_loop_signature_reference(
  mod_ : @lib.Module,
  count : Int,
  infos : Array[DaeFunctionInfo],
) -> Array[Bool] {
  let admitted = Array::make(count, true)
  for index = 0; index < count; index = index + 1 {
    for type_idx in infos[index].loop_type_indices {
      match dae_type_sec_func_type(mod_.type_sec.unwrap(), type_idx) {
        Some(@lib.FuncType(params, _)) if !params.is_empty() => {
          admitted[index] = false
          break
        }
        _ => ()
      }
    }
  }
  admitted
}

///|
fn dae_loop_signature_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let mod_ = dae_loop_signature_fixture(count, true)
  let infos = dae_collect_current_function_analysis(mod_, count).function_infos
  let expected = dae_loop_signature_reference(mod_, count, infos)
  if dae_parameter_loop_admission(mod_, 0, count, infos) != expected {
    abort("loop signature index changed admission")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae_loop_signature_reference(mod_, count, infos)
      } else {
        dae_parameter_loop_admission(mod_, 0, count, infos)
      },
    )
  })
}

///|
test "bench DAE loop signature admission count=16 reference" (it : @bench.T) {
  dae_loop_signature_bench(it, 16, true)
}

///|
test "bench DAE loop signature admission count=16 indexed" (it : @bench.T) {
  dae_loop_signature_bench(it, 16, false)
}

///|
test "bench DAE loop signature admission count=128 reference" (it : @bench.T) {
  dae_loop_signature_bench(it, 128, true)
}

///|
test "bench DAE loop signature admission count=128 indexed" (it : @bench.T) {
  dae_loop_signature_bench(it, 128, false)
}

///|
test "bench DAE loop signature admission count=1024 reference" (it : @bench.T) {
  dae_loop_signature_bench(it, 1024, true)
}

///|
test "bench DAE loop signature admission count=1024 indexed" (it : @bench.T) {
  dae_loop_signature_bench(it, 1024, false)
}
