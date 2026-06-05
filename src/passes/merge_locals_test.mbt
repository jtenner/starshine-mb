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

///|
test "merge-locals retargets same-typed source gets after copy" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32 i32) i32.const 1 local.set 0 local.get 0 local.set 1 local.get 0 local.get 1 i32.add))",
      ["merge-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(
    pretty.contains("local.get (Local 0))(local.get (Local 1)"),
    msg=pretty,
  )
  assert_true(
    pretty.contains("local.get (Local 1))(local.get (Local 1)"),
    msg=pretty,
  )
}

///|
test "merge-locals stops retargeting across control that writes destination" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 loop local.get 1 i32.const 1 i32.add local.set 1 end local.get 0))",
      ["merge-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(end))(local.get (Local 0))(end)"), msg=pretty)
}

///|
test "merge-locals stops retargeting after destination write" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32 i32) i32.const 1 local.set 0 local.get 0 local.set 1 i32.const 2 local.set 1 local.get 0))",
      ["merge-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}
