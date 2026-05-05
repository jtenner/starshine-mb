///|
test "merge-locals accepts the O4z copy-balancing pass spelling" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1))",
      ["merge-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}
