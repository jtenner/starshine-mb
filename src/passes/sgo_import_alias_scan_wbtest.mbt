///|
test "SGO invalidates same-type imported alias facts after another import write" {
  let input = match
    @wast.wast_to_binary_module(
      (
        #|(module
        #|  (import "env" "a" (global $a (mut i32)))
        #|  (import "env" "b" (global $b (mut i32)))
        #|  (global (mut i32) (i32.const 0))
        #|  (func (export "run") (result i32)
        #|    i32.const 7
        #|    global.set $a
        #|    i32.const 8
        #|    global.set $b
        #|    global.get $a))
      ),
    ) {
    Ok(input) => input
    Err(err) => fail("SGO alias fixture parse failed: \{err}")
  }
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "simplify-globals-optimizing",
    ]) {
    Ok(output) => output
    Err(err) => fail("SGO alias fixture failed: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  match output.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(
        body[body.length() - 1],
        @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      )
    _ => fail("SGO alias fixture lost its function")
  }
}
