// Nullable reference locals route nested loops through the general raw RSE
// rewrite. The body has no branches, so loop entry backedge probing is unused.

///|
fn rse_nested_loop_fixture(depth : Int) -> @lib.Module {
  let heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  for _ in 0..<depth {
    let nested = body.copy()
    body.clear()
    body.push(
      @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(nested)),
    )
  }
  opportunity_module(body, [@lib.ValType::eqref_null()], [])
}

///|
fn rse_nested_loop_bench(it : @bench.T, depth : Int) -> Unit {
  let fixture = rse_nested_loop_fixture(depth)
  let expected = opportunity_run(fixture, "redundant-set-elimination", true)
  let original_code = fixture.code_sec
  it.bench(fn() {
    it.keep(opportunity_run(fixture, "redundant-set-elimination", false))
  })
  if opportunity_run(fixture, "redundant-set-elimination", false) != expected ||
    fixture.code_sec != original_code {
    abort("RSE nested-loop fixture changed across runs")
  }
}

///|
test "bench RSE nested loops depth=6" (it : @bench.T) {
  rse_nested_loop_bench(it, 6)
}

///|
test "bench RSE nested loops depth=8" (it : @bench.T) {
  rse_nested_loop_bench(it, 8)
}
