///|
fn rub_constant_effects_count(
  instrs : Array[@lib.Instruction],
  target : @lib.Instruction,
) -> Int {
  let mut count = 0
  for instr in instrs {
    if instr == target {
      count += 1
    }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        count += rub_constant_effects_count(body, target)
      @lib.If(_, then_body, else_body) => {
        count += rub_constant_effects_count(then_body, target)
        if else_body is Some(body) {
          count += rub_constant_effects_count(body, target)
        }
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
  @debug.assert_eq(
    rub_constant_effects_count(
      body,
      @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
    ),
    0,
  )
  @debug.assert_eq(
    rub_constant_effects_count(
      body,
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
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
  @debug.assert_eq(
    rub_constant_effects_count(
      body,
      @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
    ),
    0,
  )
  @debug.assert_eq(
    rub_constant_effects_count(body, @lib.Instruction::drop()),
    1,
  )
  let input = pass_test_module_from_wat(
    "(module (memory 1) (func (param i32) (result i32) local.get 0 i32.load))",
  )
  let @lib.CodeSec(input_codes) = input.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(input_body)) = input_codes[0]
  @debug.assert_eq(rub_constant_effects_count(body, input_body[1]), 1)
  @validate.validate_module(output).unwrap()
}

///|
test "remove-unused-brs retains nested condition exit with a different carried value" {
  let output = pass_test_run_pipeline(
    "(module (func (param i32) (result i32) (block $exit (result i32) (drop (br_if $exit (i32.const 7) (block (result i32) (br_if $exit (i32.const 9) (local.get 0)) drop (i32.const 0)))) (i32.const 7))))",
    ["remove-unused-brs"],
  ).unwrap()
  let @lib.CodeSec(codes) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = codes[0]
  // Only the outer equal-constant branch may disappear. The inner exit carries
  // 9 and must keep its target and evaluation order.
  @debug.assert_eq(
    rub_constant_effects_count(
      body,
      @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    ),
    1,
  )
  @debug.assert_eq(
    rub_constant_effects_count(body, @lib.Instruction::i32_const(@lib.I32(9))),
    1,
  )
  @validate.validate_module(output).unwrap()
}
