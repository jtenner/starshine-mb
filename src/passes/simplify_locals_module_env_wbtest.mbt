///|
test "raw simplify-locals shares module facts while keeping function local types separate" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (param i32) (result i32) (local i32)
      #|    i32.const 7 local.set 1 nop local.get 1)
      #|  (func (param i64) (result i64) (local i64)
      #|    i64.const 9 local.set 1 nop local.get 1))
    ),
  )
  let state = HotPipelineModuleState::new()
  let trace : Array[String] = []
  let perf = HotPerfSession::new(
    trace=fn(line) { trace.push(line) },
    dump_options=HotPerfDumpOptions::new(),
  )
  let options = HotPipelineOptions::new(perf=Some(perf))
  for index in [0U, 1U] {
    let func_idx = @lib.FuncIdx::new(index)
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let result = run_hot_pipeline_raw_simplify_locals_rewrite_skipped_effectful_carriers(
      mod_,
      func_idx,
      state,
      @ir.HotPassDescriptor::new("simplify-locals"),
      options,
      locals,
      instrs,
      "shared-module-env-test",
    ).unwrap()
    assert_false(result.unchanged_original)
    let @lib.Func(_, @lib.Expr(body)) = result.func
    for offset = 0; offset + 1 < body.length(); offset = offset + 1 {
      assert_eq(body[offset], @lib.Instruction::nop())
    }
    assert_eq(
      body[body.length() - 1],
      if index == 0U {
        @lib.Instruction::i32_const(@lib.I32(7))
      } else {
        @lib.Instruction::i64_const(@lib.I64(9L))
      },
    )
  }
  assert_true(state.validation_module_env is Some(_))
  assert_eq(
    trace
    .filter(fn(line) {
      line.contains(
        "perf:timer name=analysis:optimize-instructions-validation-module-env",
      )
    })
    .length(),
    1,
  )
}
