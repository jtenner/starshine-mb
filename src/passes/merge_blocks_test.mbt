///|
fn merge_blocks_test_count_substring(text : String, needle : String) -> Int {
  if needle.length() == 0 {
    return 0
  }
  let mut count = 0
  let limit = text.length() - needle.length()
  let mut i = 0
  while i <= limit {
    if text.sub(start=i, end=i + needle.length()).to_string() == needle {
      count += 1
      i += needle.length()
    } else {
      i += 1
    }
  }
  count
}

///|
test "merge-blocks flattens nested block roots in parent regions" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (block (nop) (block (nop) (nop)) (nop))))",
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-blocks success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_eq(merge_blocks_test_count_substring(pretty, "(block"), 0, msg=pretty)
  assert_eq(merge_blocks_test_count_substring(pretty, "nop"), 4, msg=pretty)
}

///|
test "merge-blocks flattens inner blocks inside loops without dropping continue targets" {
  let optimized = match
    pass_test_run_pipeline("(module (func (loop $l (block (nop)) (br $l))))", [
      "merge-blocks",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-blocks loop success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(loop"), msg=pretty)
  assert_eq(merge_blocks_test_count_substring(pretty, "(block"), 0, msg=pretty)
  assert_eq(merge_blocks_test_count_substring(pretty, "nop"), 1, msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
}

///|
test "merge-blocks preserves blocks with incoming branch targets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (block (result i32) (block $inner (result i32) (br $inner (i32.const 7))))))",
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks incoming-branch success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(
    merge_blocks_test_count_substring(pretty, "(block") >= 1,
    msg=pretty,
  )
  assert_true(pretty.contains("br"), msg=pretty)
}
