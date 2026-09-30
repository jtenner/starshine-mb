///|
test "dae2 optimizing command keeps balanced call evaluation without capture traffic" {
  let source =
    #|(module
    #| (import "env" "produce" (func $produce (result i32)))
    #| (import "env" "consume" (func $consume (param i32)))
    #| (func (export "run") (result i32) (local i32)
    #|  call $produce local.set 0 i32.const 7 call $consume local.get 0))
  let input = @wast.wast_to_binary_module(source).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_eq(body, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
}
