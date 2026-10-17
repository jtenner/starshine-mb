///|
test "DAE family effect guard public dispatcher prunes real literals with trace and source ownership" {
  let input = pass_test_module_from_wat(
    "(module (import \"m\" \"mark\" (func $mark (param i32))) " +
    "(func $h (param i32) local.get 0 call $mark) " +
    "(func (export \"run\") i32.const 7 call $h))",
  )
  let expected = pass_test_module_from_wat(
    "(module (import \"m\" \"mark\" (func $mark (param i32))) " +
    "(func $h i32.const 7 call $mark) (func (export \"run\") call $h))",
  )
  let saved = @binary.encode_module(input).unwrap()
  for pass in ["dae", "dae-optimizing"] {
    let observations : Array[Bool] = []
    let traced = run_hot_pipeline(
      input,
      HotPipelineOptions::new(
        trace=Some(fn(_ : String) {
          observations.push(@binary.encode_module(input).unwrap() == saved)
        }),
      ),
      [pass],
    ).unwrap()
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    @validate.validate_module(output).unwrap()
    @validate.validate_module(traced).unwrap()
    assert_eq(output.code_sec, expected.code_sec)
    assert_eq(traced.code_sec, expected.code_sec)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(traced).unwrap(),
    )
    let indices = dae_collect_func_type_indices(output)
    let @lib.FuncType(params, results) = dae_resolve_func_type(
      output, indices, 1,
    ).unwrap()
    assert_eq(params, [])
    assert_eq(results, [])
    assert_false(observations.is_empty())
    assert_true(observations.all(fn(value) { value }))
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    body.push(@lib.Instruction::nop())
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
