///|
fn ca_loop_plan_perf_fixture(loop_count : Int) -> @lib.Module {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<loop_count {
    body.push(@lib.Instruction::i32_const(@lib.I32(1)))
    body.push(
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
        @lib.Expr::new([@lib.Instruction::local_set(@lib.LocalIdx::new(0U))]),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn ca_loop_plan_perf_bench(it : @bench.T, loop_count : Int) -> Unit {
  let fixture = ca_loop_plan_perf_fixture(loop_count)
  if @validate.validate_module(fixture).is_err() {
    abort("ConstraintAnalysis typed-loop fixture is invalid")
  }
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let cfg = @ir.cache_get_or_build_cfg(@ir.HotAnalysisCache::new(), hot)
  let preflight = ca_loop_plan(hot, cfg)
  let mut found = 0
  for slots in preflight.loop_slots {
    if !slots.is_empty() {
      found += 1
    }
  }
  if found != loop_count {
    abort("ConstraintAnalysis typed-loop fixture did not plan every loop")
  }
  it.bench(fn() { it.keep(ca_loop_plan(hot, cfg)) })
}

///|
test "bench constraint loop plan sibling loops=32" (it : @bench.T) {
  ca_loop_plan_perf_bench(it, 32)
}

///|
test "bench constraint loop plan sibling loops=64" (it : @bench.T) {
  ca_loop_plan_perf_bench(it, 64)
}
