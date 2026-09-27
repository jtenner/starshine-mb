///|
test "precompute cleanup shares a module snapshot without flattening parameter blocks" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $out (func (result i32)))
      #|  (type $inout (func (param i32) (result i32)))
      #|  (func (param i32) (result i32)
      #|    block (type $out) local.get 0 end)
      #|  (func (param i32) (result i32)
      #|    local.get 0 block (type $inout) end)
      #|  (func (param i32) (result i32)
      #|    block (result i32) local.get 0 br 0 end))
    ),
  )
  for descriptor in [precompute_descriptor(), precompute_propagate_descriptor()] {
    let state = HotPipelineModuleState::new()
    let trace : Array[String] = []
    let perf = HotPerfSession::new(trace=fn(line) { trace.push(line) })
    let options = HotPipelineOptions::new(perf=Some(perf))
    let outputs : Array[@lib.Func] = []
    for index in [0U, 1U, 2U] {
      let result = run_hot_pipeline_func(
        mod_,
        @lib.FuncIdx::new(index),
        descriptor,
        state,
        { next_type_sec: mod_.type_sec, type_sec_changed: false, },
        options,
      ).unwrap()
      outputs.push(result.func)
    }
    @validate.validate_module(mod_.with_code_sec(@lib.CodeSec::new(outputs))).unwrap()
    let @lib.Func(_, @lib.Expr(first_body)) = outputs[0]
    assert_eq(first_body, [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))])
    assert_eq(outputs[1], mod_.code_sec.unwrap().0[1])
    assert_true(state.validation_module_env is Some(_), msg=descriptor.name)
    assert_eq(
      trace
      .filter(fn(line) {
        line.contains(
          "perf:timer name=analysis:optimize-instructions-validation-module-env",
        )
      })
      .length(),
      1,
      msg=descriptor.name,
    )
  }
}

///|
test "precompute cleanup resolves block types from each new module snapshot" {
  for
    text in [
      "(module (type (func (result i32))) (func (param i32) (result i32) block (type 0) local.get 0 end))",
      "(module (type (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 block (type 0) end))",
    ] {
    let mod_ = pass_test_module_from_wat(text)
    let expected = pass_lower_cleanup_branchless_blocks(
        mod_.code_sec.unwrap().0[0],
        mod_,
      ).0
    for name in ["precompute", "precompute-propagate"] {
      let output = run_hot_pipeline(mod_, HotPipelineOptions::new(), [name]).unwrap()
      assert_eq(output.code_sec.unwrap().0[0], expected)
      @validate.validate_module(output).unwrap()
    }
  }
}
