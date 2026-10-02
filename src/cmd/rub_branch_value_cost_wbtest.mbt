///|
test "explicit remove-unused-brs dispatch respects branch payload cost" {
  let wat = "(module (func (param i32 i32) (result i32) (local i32) (block $carry (result i32) (local.set 2 (i32.const 7)) (if (local.get 0) (then (br $carry (i32.rem_u (local.get 1) (i32.const 3))))) (local.get 2))))"
  let input = match
    @wast.wast_to_binary_module(wat, filename="rub-branch-payload-cost-cmd.wat") {
    Ok(mod_) => mod_
    Err(err) => fail("expected branch payload cost fixture: \{err}")
  }
  for shrink_level in [0, 1, 2] {
    let optimized = match
      optimize_module_with_pass_flags(
        input,
        ["remove-unused-brs"],
        OptimizeOptions::new(shrink_level~),
      ) {
      Ok(mod_) => mod_
      Err(err) => fail("expected branch payload cost dispatch: \{err}")
    }
    match @validate.validate_module(optimized) {
      Ok(_) => ()
      Err(err) =>
        fail("expected branch payload cost output to validate: \{err}")
    }
    let body = match optimized.code_sec {
      Some(
        @lib.CodeSec(
          [@lib.Func(_, @lib.Expr([@lib.Block(_, @lib.Expr(body))]))]
        )
      ) => body
      other =>
        fail(
          "expected result block in branch payload cost output: \{@debug.to_string(other)}",
        )
    }
    let mut if_count = 0
    let mut br_if_count = 0
    for instr in body {
      match instr {
        @lib.If(_, _, _) => if_count += 1
        @lib.BrIf(_) => br_if_count += 1
        _ => ()
      }
    }
    assert_eq(if_count, if shrink_level == 0 { 1 } else { 0 })
    assert_eq(br_if_count, if shrink_level == 0 { 0 } else { 1 })
  }
}
