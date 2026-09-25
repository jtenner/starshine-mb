///|
fn gr_unrefined_write_perf_bench(it : @bench.T, writes : Int) -> Unit {
  let instrs : Array[@lib.Instruction] = []
  for idx in 0..<writes {
    instrs.push(@lib.Instruction::i32_const(@lib.I32(idx)))
    for _ in 0..<32 {
      instrs.push(@lib.Instruction::nop())
    }
    instrs.push(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
  }
  let refined_globals : Array[@lib.RefType?] = [None]
  let mod_ = @lib.Module::new()
  let func_type_indices : Array[@lib.TypeIdx] = []
  let (_, changed) = gr_rewrite_ref_null_set_instrs(
    instrs, refined_globals, mod_, func_type_indices,
  )
  if changed {
    abort("GlobalRefining unrefined-global fixture unexpectedly changed")
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
test "bench GlobalRefining unrefined writes=128" (it : @bench.T) {
  gr_unrefined_write_perf_bench(it, 128)
}

///|
test "bench GlobalRefining unrefined writes=256" (it : @bench.T) {
  gr_unrefined_write_perf_bench(it, 256)
}
