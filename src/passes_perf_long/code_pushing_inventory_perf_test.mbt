// The fixture is validated and lifted before timing. Repeated direct HOT runs
// measure inventory construction without lift, lower, or final validation.

///|
fn code_pushing_inventory_fixture(
  local_count : Int,
  read_count : Int,
) -> @lib.Module {
  let body : Array[@lib.Instruction] = []
  for idx = 0; idx < read_count; idx = idx + 1 {
    body.push(
      @lib.Instruction::local_get(
        @lib.LocalIdx::new((idx % local_count).to_uint()),
      ),
    )
    body.push(@lib.Instruction::drop())
  }
  opportunity_module(body, Array::make(local_count, @lib.ValType::i32()), [])
}

///|
fn code_pushing_inventory_bench(
  it : @bench.T,
  local_count : Int,
  read_count : Int,
) -> Unit {
  let fixture = code_pushing_inventory_fixture(local_count, read_count)
  ignore(opportunity_run(fixture, "code-pushing", true))
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let ctx = @passes.HotPassContext::new(
    @passes.code_pushing_descriptor(),
    @ir.HotAnalysisCache::new(),
    @passes.HotPipelineVerifyPolicy::final_module_only(),
    false,
    fn(_) { () },
  )
  if !@passes.hot_pass_run(ctx, hot).is_ok() {
    abort("code-pushing inventory preflight failed")
  }
  let before = @ir.hot_lower_func_unverified(hot)
  it.bench(fn() { it.keep(@passes.hot_pass_run(ctx, hot)) })
  if @ir.hot_lower_func_unverified(hot) != before {
    abort("code-pushing inventory fixture changed on replay")
  }
}

///|
test "bench code-pushing inventory locals=16 reads=64" (it : @bench.T) {
  code_pushing_inventory_bench(it, 16, 64)
}

///|
test "bench code-pushing inventory locals=32 reads=128" (it : @bench.T) {
  code_pushing_inventory_bench(it, 32, 128)
}
