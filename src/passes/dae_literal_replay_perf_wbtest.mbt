///|
fn dae_literal_replay_benchmark(
  it : @bench.T,
  padding : Int,
  reference : Bool,
) -> Unit {
  let base = pass_test_module_from_wat(
    "(module (func $id (param i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) local.get 0 call $id))",
  )
  let funcs = base.code_sec.unwrap().0.copy()
  let body = Array::makei(padding, fn(_) { @lib.Instruction::nop() })
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  funcs[0] = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  let mod_ = base.with_code_sec(@lib.CodeSec::new(funcs))
  let original = dae_collect_original_boundary_snapshot(mod_)
  for control in [false, true] {
    let result = dae_literal_replay_fixture_run(
      mod_,
      original,
      [0],
      reference=control,
    )
    if result.changed || result.mod_out != mod_ {
      abort("literal replay changed a nonconstant call")
    }
  }
  it.bench(fn() {
    it.keep(dae_literal_replay_fixture_run(mod_, original, [0], reference~))
  })
}

///|
test "bench DAE eager literal replay instructions=512" (it : @bench.T) {
  dae_literal_replay_benchmark(it, 512, true)
}

///|
test "bench DAE lazy literal replay instructions=512" (it : @bench.T) {
  dae_literal_replay_benchmark(it, 512, false)
}

///|
test "bench DAE eager literal replay instructions=4096" (it : @bench.T) {
  dae_literal_replay_benchmark(it, 4096, true)
}

///|
test "bench DAE lazy literal replay instructions=4096" (it : @bench.T) {
  dae_literal_replay_benchmark(it, 4096, false)
}
