///|
fn rub_constant_effects_count(instrs : Array[@lib.Instruction], target : @lib.Instruction) -> Int {
  let mut count = 0
  for instr in instrs {
    if instr == target { count += 1 }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) => count += rub_constant_effects_count(body, target)
      @lib.If(_, then_body, else_body) => {
        count += rub_constant_effects_count(then_body, target)
        if else_body is Some(body) { count += rub_constant_effects_count(body, target) }
      }
      _ => ()
    }
  }
  count
}

///|
test "remove-unused-brs drops equal-constant branch and retains imported condition" {
  let output = pass_test_run_pipeline(
    "(module (import \"m\" \"condition\" (func (result i32))) (func (export \"run\") (result i32) (block $exit (result i32) (drop (br_if $exit (i32.const 7) (call 0))) (i32.const 7))))",
    ["remove-unused-brs"],
  ).unwrap()
  let @lib.CodeSec(codes) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = codes[0]
  @debug.assert_eq(rub_constant_effects_count(body, @lib.Instruction::br_if(@lib.LabelIdx::new(0U))), 0)
  @debug.assert_eq(rub_constant_effects_count(body, @lib.Instruction::call(@lib.FuncIdx::new(0U))), 1)
  @validate.validate_module(output).unwrap()
}

///|
test "remove-unused-brs drops equal-constant branch and retains trapping load" {
  let output = pass_test_run_pipeline(
    "(module (memory 1) (func (param i32) (result i32) (block $exit (result i32) (drop (br_if $exit (i32.const 7) (i32.load (local.get 0)))) (i32.const 7))))",
    ["remove-unused-brs"],
  ).unwrap()
  let @lib.CodeSec(codes) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = codes[0]
  @debug.assert_eq(rub_constant_effects_count(body, @lib.Instruction::br_if(@lib.LabelIdx::new(0U))), 0)
  @debug.assert_eq(rub_constant_effects_count(body, @lib.Instruction::drop()), 1)
  @validate.validate_module(output).unwrap()
}
