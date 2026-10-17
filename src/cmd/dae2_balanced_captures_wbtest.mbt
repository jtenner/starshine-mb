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

///|
test "dae2 optimizing command cleans one capture and preserves sibling effects" {
  let input = @wast.wast_to_binary_module(
    (
      #| (module
      #|   (import "env" "consume" (func $consume (param i32)))
      #|   (func $active (export "value") (result i32) (local i32)
      #|     i32.const 7 local.set 0 local.get 0)
      #|   (func $retained (export "run") (param i32) (local i32)
      #|     local.get 0 local.set 1 local.get 1 call $consume
      #|     i32.const 2 local.set 1 local.get 1 call $consume))
    ),
  ).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(value)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_eq(value, [@lib.Instruction::i32_const(@lib.I32(7))])
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  let calls = body.filter(fn(instr) { instr is @lib.Call(_) })
  assert_eq(calls, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  assert_true(input.code_sec.unwrap().0[0] != output.code_sec.unwrap().0[0])
}
