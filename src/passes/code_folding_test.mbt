///|
fn code_folding_test_run(text : String) -> @lib.Module {
  match pass_test_run_pipeline(text, ["code-folding"]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected code-folding pipeline success, got \{err}")
  }
}

///|
fn code_folding_test_count_substring(text : String, needle : String) -> Int {
  if needle.length() == 0 {
    return 0
  }
  let mut count = 0
  let limit = text.length() - needle.length()
  let mut i = 0
  while i <= limit {
    if text.sub(start=i, end=i + needle.length()).to_owned() == needle {
      count += 1
      i += needle.length()
    } else {
      i += 1
    }
  }
  count
}

///|
test "code-folding hoists identical if-arm suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    local.get 0
      #|    if
      #|      i32.const 1
      #|      drop
      #|      i32.const 7
      #|      drop
      #|    else
      #|      i32.const 2
      #|      drop
      #|      i32.const 7
      #|      drop
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(1)"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(2)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
  )
}

///|
test "code-folding replaces identical full void arms with condition drop plus shared suffix" {
  let optimized = code_folding_test_run(
    "(module (func (param i32) local.get 0 if i32.const 7 drop else i32.const 7 drop end))",
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(7)"), msg=pretty)
}

///|
test "code-folding keeps value if arms unchanged" {
  let optimized = code_folding_test_run(
    "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 7 else i32.const 7 end))",
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
}

///|
test "code-folding flattens exiting dead value blocks" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (result i32)
      #|    block (result i64)
      #|      f64.const 0
      #|      unreachable
      #|    end
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("f64.const"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    1,
    msg=pretty,
  )
}
