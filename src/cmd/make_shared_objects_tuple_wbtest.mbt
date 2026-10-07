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
