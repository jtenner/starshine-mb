// Nested void loops have no incoming continues, so every label can demote.
// Fixture validation and output checks stay outside the timed pass run.

///|
fn remove_unused_names_loop_fixture(depth : Int) -> @lib.Module {
  let mut body : Array[@lib.Instruction] = [@lib.Instruction::nop()]
  for _ in 0..<depth {
    body = [
      @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(body)),
    ]
  }
  opportunity_module(body, [], [])
}

///|
fn remove_unused_names_loop_bench(it : @bench.T, depth : Int) -> Unit {
  let fixture = remove_unused_names_loop_fixture(depth)
  ignore(opportunity_run(fixture, "remove-unused-names", true))
  let ctx = @passes.HotPassContext::new(
    @passes.remove_unused_names_descriptor(),
    @ir.HotAnalysisCache::new(),
    @passes.HotPipelineVerifyPolicy::final_module_only(),
    false,
    fn(_) { () },
  )
  let preflight = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  if !@passes.hot_pass_run(ctx, preflight).is_ok() {
    abort("remove-unused-names HOT preflight failed")
  }
  let expected = @ir.hot_lower_func_unverified(preflight)
  let original = match fixture.code_sec {
    Some(@lib.CodeSec([func])) => func
    _ => abort("expected one remove-unused-names fixture function")
  }
  if expected == original {
    abort("remove-unused-names loop fixture did not transform")
  }
  it.bench(fn() {
    let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
    it.keep(@passes.hot_pass_run(ctx, hot))
  })
  let replay = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  if !@passes.hot_pass_run(ctx, replay).is_ok() ||
    @ir.hot_lower_func_unverified(replay) != expected {
    abort("remove-unused-names loop fixture changed across runs")
  }
}

///|
test "bench remove-unused-names nested loops depth=48" (it : @bench.T) {
  remove_unused_names_loop_bench(it, 48)
}

///|
test "bench remove-unused-names nested loops depth=96" (it : @bench.T) {
  remove_unused_names_loop_bench(it, 96)
}

///|
test "bench remove-unused-names nested loops depth=256" (it : @bench.T) {
  remove_unused_names_loop_bench(it, 256)
}
