///|
fn global_effects_target_summary_fixture(count : Int) -> @lib.Module {
  let target_body : Array[@lib.Instruction] = []
  for _ in 0..<count {
    target_body.push(@lib.Instruction::nop())
  }
  let caller_body : Array[@lib.Instruction] = []
  for _ in 0..<count {
    caller_body.push(@lib.Instruction::ref_func(@lib.FuncIdx::new(0U)))
    caller_body.push(@lib.Instruction::cont_new(@lib.TypeIdx::new(1U)))
    caller_body.push(@lib.Instruction::resume_(@lib.TypeIdx::new(1U), []))
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
      ),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::declarative(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(target_body)),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(caller_body)),
    ]),
  )
}

///|
fn global_effects_target_summary_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = global_effects_target_summary_fixture(count)
  let expected = opportunity_run(fixture, "global-effects", true)
  let @lib.Func(_, @lib.Expr(body)) = expected.code_sec.unwrap().0[1]
  if body.filter(fn(instr) { instr is @lib.Call(_) }).length() != count {
    abort("GlobalEffects fixture did not rewrite every resume")
  }
  it.bench(fn() { it.keep(opportunity_run(fixture, "global-effects", false)) })
}

///|
test "bench global-effects repeated resume=128" (it : @bench.T) {
  global_effects_target_summary_bench(it, 128)
}

///|
test "bench global-effects repeated resume=256" (it : @bench.T) {
  global_effects_target_summary_bench(it, 256)
}
