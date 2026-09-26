///|
test "command inlining variants remove a tiny helper after body classification" {
  for pass in ["inlining", "inlining-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (func $helper (param i32) (result i32) local.get 0 i32.eqz) (func (export \"run\") (param i32) (result i32) local.get 0 call $helper))",
      pass,
    )
    assert_true(@validate.validate_module(output) is Ok(_))
    assert_eq(output.code_sec.unwrap().0.length(), 1)
  }
}
