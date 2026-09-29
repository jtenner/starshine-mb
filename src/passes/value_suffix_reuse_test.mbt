///|
test "simplify-locals variants preserve scalar suffix execution through active dispatch" {
  let text = "(module (func (export \"value\") (result i32) (local i32) i32.const 1 i32.const 2 i32.add local.set 0 local.get 0))"
  for
    name in [
      "simplify-locals", "simplify-locals-nonesting", "simplify-locals-notee", "simplify-locals-nostructure",
      "simplify-locals-notee-nostructure",
    ] {
    let output = pass_test_run_pipeline(text, [name]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(scalar_fixture_run(output.code_sec.unwrap().0[0], []), [3L])
  }
}
