// The fixture is validated, lifted, and analyzed before timing. Only rewrite
// plan construction is timed; plans are read-only and may be rebuilt safely.

///|
fn ssa_plan_lookup_fixture(pairs : Int) -> @lib.Module {
  let body : Array[@lib.Instruction] = []
  for idx = 0; idx < pairs; idx = idx + 1 {
    body.push(@lib.Instruction::i32_const(@lib.I32(idx)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::drop())
  }
  opportunity_module(body, [@lib.ValType::i32()], [])
}

///|
fn ssa_plan_lookup_bench(it : @bench.T, pairs : Int, full : Bool) -> Unit {
  let fixture = ssa_plan_lookup_fixture(pairs)
  ignore(opportunity_run(fixture, "ssa-nomerge", true))
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let graph = @ir.local_graph_build(hot, @ir.cfg_build(hot))
  if full {
    let plan = @passes.ssa_full_build_merge_rewrite_plan(hot, graph)
    if plan.write_rewrites.length() != pairs ||
      plan.get_rewrites.length() != pairs {
      abort("SSA plan fixture did not reach every write and get")
    }
    it.bench(fn() {
      it.keep(@passes.ssa_full_build_merge_rewrite_plan(hot, graph))
    })
  } else {
    let plan = @passes.ssa_nomerge_build_rewrite_plan(hot, graph)
    if plan.write_rewrites.length() != pairs ||
      plan.get_rewrites.length() != pairs {
      abort("SSA no-merge plan fixture did not reach every write and get")
    }
    it.bench(fn() {
      it.keep(@passes.ssa_nomerge_build_rewrite_plan(hot, graph))
    })
  }
}

///|
test "bench SSA plan pairs=64" (it : @bench.T) {
  ssa_plan_lookup_bench(it, 64, true)
}

///|
test "bench SSA plan pairs=256" (it : @bench.T) {
  ssa_plan_lookup_bench(it, 256, true)
}

///|
test "bench SSA no-merge plan pairs=64" (it : @bench.T) {
  ssa_plan_lookup_bench(it, 64, false)
}

///|
test "bench SSA no-merge plan pairs=256" (it : @bench.T) {
  ssa_plan_lookup_bench(it, 256, false)
}
