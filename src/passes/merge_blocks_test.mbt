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

///|
test "merge-blocks preserves lowered drop local.tee roots on changed functions" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (local i32) (block (drop (local.tee 0 (i32.const 1))))))",
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-blocks tee-drop success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_eq(merge_blocks_test_count_substring(pretty, "(block"), 0, msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
test "merge-blocks preserves outer typed param block lowering for single-result parity" {
  let source =
    #| (module
    #|   (type $t (func (param i32) (result i32)))
    #|   (func (result i32)
    #|     i32.const 4
    #|     (block (type $t)
    #|       (block (type $t)
    #|         i32.const 1
    #|         i32.add))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks typed single-result success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_eq(merge_blocks_test_count_substring(pretty, "(block"), 0, msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-result param block lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32) (result i32 i32)))
    #|   (func (result i32 i32)
    #|     i32.const 4
    #|     i32.const 5
    #|     (block (type $t)
    #|       (block (type $t)
    #|         i32.add
    #|         i32.const 9))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks typed multi-result success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(
    merge_blocks_test_count_substring(pretty, "(block") >= 2,
    msg=pretty,
  )
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}
