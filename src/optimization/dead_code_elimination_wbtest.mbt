///|
fn dead_code_elimination_test_module(
  instrs : Array[@lib.TInstr],
) -> Module {
  Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::t_func([], @lib.Locals::empty(), @lib.TExpr::new(instrs)),
    ]),
  )
}

///|
test "dead code elimination pipeline dispatch uses dedicated runner shell" {
  let pipeline : Array[PipelineEntry] = []
  add_pass_to_pipeline(pipeline, OptimizePass::DeadCodeElimination)
  let mod = dead_code_elimination_test_module([@lib.TInstr::nop()])
  match pipeline {
    [{ group: PassGroup(FuncLocalGroup([runner]), _), .. }] => {
      let (_, scratch) = runner(mod, PipelineScratch::new())
      assert_eq(scratch.funcs_visited, 1)
      assert_eq(scratch.funcs_changed, 0)
      assert_false(scratch.changed)
    }
    _ => fail("expected dead code elimination func-local pipeline entry")
  }
}

///|
test "run_dead_code_elimination shell preserves empty typed function bodies" {
  let mod = dead_code_elimination_test_module([])
  let (optimized, scratch) = run_dead_code_elimination(
    mod,
    PipelineScratch::new(),
  )
  assert_eq(optimized, mod)
  assert_eq(scratch.funcs_visited, 1)
  assert_eq(scratch.funcs_changed, 0)
  assert_false(scratch.changed)
}
