///|
test "dispatcher code-folding hoists equal arithmetic payloads" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 1 drop
    #|      local.get 1 i32.const 7 i32.add
    #|    else
    #|      i32.const 2 drop
    #|      local.get 1 i32.const 7 i32.add
    #|    end))
  let input = @passes.pass_test_module_from_wat(source)
  let output = optimize_module_with_pass_flags(
    input,
    ["code-folding"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(
    cmd_deep_audit_count(body, fn(instr) { instr is @lib.I32Add }),
    1,
  )
}
