// Validation, HOT lifting, and LocalGraph construction stay outside timing.

///|
fn ssa_nomerge_param_tee_fixture(pairs : Int) -> @lib.Module {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<pairs {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::i32_const(@lib.I32(1)))
    body.push(@lib.Instruction::i32_add())
    body.push(@lib.Instruction::local_tee(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::drop())
  }
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn ssa_nomerge_param_tee_bench(it : @bench.T, pairs : Int) -> Unit {
  let fixture = ssa_nomerge_param_tee_fixture(pairs)
  ignore(opportunity_run(fixture, "ssa-nomerge", true))
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let graph = @ir.local_graph_build(hot, @ir.cfg_build(hot))
  let plan = @passes.ssa_nomerge_build_rewrite_plan(hot, graph)
  if plan.write_rewrites.length() != pairs ||
    plan.get_rewrites.length() != pairs + 1 {
    abort("SSA no-merge parameter-tee fixture missed its writes or reads")
  }
  it.bench(fn() { it.keep(@passes.ssa_nomerge_build_rewrite_plan(hot, graph)) })
}

///|
test "bench SSA no-merge parameter tees=128" (it : @bench.T) {
  ssa_nomerge_param_tee_bench(it, 128)
}

///|
test "bench SSA no-merge parameter tees=256" (it : @bench.T) {
  ssa_nomerge_param_tee_bench(it, 256)
}
