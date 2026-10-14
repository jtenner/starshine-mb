///|
test "dispatcher make-shared-objects wraps multi-result import and export" {
  let source =
    #|(module
    #|  (import "m" "pair" (func $pair (result externref i32)))
    #|  (func (export "run") (result externref i32) (call $pair)))
  let input = @passes.pass_test_module_from_wat(source)
  let output = optimize_module_with_pass_flags(
    input,
    ["make-shared-objects"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let funcs = output.code_sec.unwrap().0
  @debug.assert_eq(funcs.length(), 5)
  let @lib.Func(_, @lib.Expr(body)) = funcs[0]
  @debug.assert_eq(body, [@lib.Instruction::call(@lib.FuncIdx::new(2U))])
  let idx = match output.export_sec.unwrap().0[0] {
    @lib.Export(_, @lib.FuncExternIdx(idx)) => idx
    _ => fail("expected function export")
  }
  @debug.assert_eq(idx, @lib.FuncIdx::new(3U))
}

///|
test "dispatcher make-shared-objects avoids an adjacent conversion handle" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (export \"roundtrip\") (result anyref) i32.const 7 ref.i31 extern.convert_any any.convert_extern))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["make-shared-objects"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  @debug.assert_eq(output.table_sec, None)
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 1)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::ref_i31_shared(),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
}
