///|
fn local_cse_assert_structural_fact_bound(func : @ir.HotFunc) -> Unit raise {
  let ctx = HotPassContext::new(
    local_cse_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let fact_visits = [0]
  ignore(local_cse_run_with_fact_visits(ctx, func, fact_visits))
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => fail("expected local-cse HOT core to verify, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected local-cse HOT control to verify, got \{err}")
  }
  assert_true(
    fact_visits[0] <= @ir.hot_node_count(func) * 2,
    msg="fact visits=\{fact_visits[0]} nodes=\{@ir.hot_node_count(func)}",
  )
}

///|
test "HOT local cse computes structural facts once per deep node" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let mut value = @ir.hot_build_local_get(func, 0)
  for idx in 0..<512 {
    let next = @ir.hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      @ir.hot_build_const_i32(func, @lib.I32(idx)),
    )
    @ir.hot_node_exact_instr_set(func, next, @lib.Instruction::i32_add())
    value = next
  }
  @ir.hot_root_append(func, @ir.hot_build_drop(func, value))
  local_cse_assert_structural_fact_bound(func)
}

///|
test "HOT local cse computes structural facts once per shared DAG node" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let mut value = @ir.hot_build_local_get(func, 0)
  for _ in 0..<18 {
    let next = @ir.hot_build_binary(func, @lib.ValType::i32(), value, value)
    @ir.hot_node_exact_instr_set(func, next, @lib.Instruction::i32_add())
    value = next
  }
  @ir.hot_root_append(func, @ir.hot_build_drop(func, value))
  local_cse_assert_structural_fact_bound(func)
}
