///|
fn gr_lazy_copy_perf_bench(it : @bench.T, instruction_count : Int) -> Unit {
  let instrs : Array[@lib.Instruction] = []
  for idx in 0..<instruction_count {
    instrs.push(@lib.Instruction::i32_const(@lib.I32(idx)))
    instrs.push(@lib.Instruction::drop())
  }
  let mod_ = @lib.Module::new()
  let refined_globals : Array[@lib.RefType?] = []
  let func_type_indices : Array[@lib.TypeIdx] = []
  let (_, changed) = gr_rewrite_ref_null_set_instrs(
    instrs, refined_globals, mod_, func_type_indices,
  )
  if changed {
    abort("numeric-only GlobalRefining fixture unexpectedly changed")
  }
  it.bench(fn() {
    it.keep(
      gr_rewrite_ref_null_set_instrs(
        instrs, refined_globals, mod_, func_type_indices,
      ),
    )
  })
}

///|
test "bench GlobalRefining unchanged numeric pairs=512" (it : @bench.T) {
  gr_lazy_copy_perf_bench(it, 512)
}

///|
test "bench GlobalRefining unchanged numeric pairs=1024" (it : @bench.T) {
  gr_lazy_copy_perf_bench(it, 1024)
}
