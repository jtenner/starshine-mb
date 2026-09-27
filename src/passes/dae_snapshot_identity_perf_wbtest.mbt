///|
fn dae_snapshot_identity_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let body : Array[@lib.Instruction] = []
  for i in 0..<count {
    body.push(@lib.Instruction::i32_const(i))
    body.push(@lib.Instruction::drop())
  }
  let original = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        original == original
      } else {
        dae_snapshot_module_unchanged(original, original)
      },
    )
  })
}

///|
test "bench campaign dae shared snapshot instructions=512 reference" (
  it : @bench.T,
) {
  dae_snapshot_identity_bench(it, 256, true)
}

///|
test "bench campaign dae shared snapshot instructions=512 identity" (
  it : @bench.T,
) {
  dae_snapshot_identity_bench(it, 256, false)
}

///|
test "bench campaign dae shared snapshot instructions=4096 reference" (
  it : @bench.T,
) {
  dae_snapshot_identity_bench(it, 2048, true)
}

///|
test "bench campaign dae shared snapshot instructions=4096 identity" (
  it : @bench.T,
) {
  dae_snapshot_identity_bench(it, 2048, false)
}
