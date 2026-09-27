///|
test "command instruction cleanup retains and compacts a body-only signature" {
  let input = "(module (type (func (param i64))) (type (func (result i32))) (type (func (param i32) (result i32))) (func (export \"run\") (type 1) i32.const 7 block (type 2) end))"
  let output = cmd_deep_audit_run(input, "optimize-instructions")
  @validate.validate_module(output).unwrap()
  let types = match output.type_sec {
    Some(@lib.TypeSec(types)) => types
    None => fail("missing types")
  }
  assert_eq(types.length(), 2)
  let body = cmd_deep_audit_body(output)
  assert_true(body[0] is @lib.I32Const(@lib.I32(7)))
  assert_true(
    body[body.length() - 1]
    is @lib.Block(@lib.TypeIdxBlockType(@lib.TypeIdx(1U)), _),
  )
}
