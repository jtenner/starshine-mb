///|
test "remove-unused-brs removes trailing branch to the enclosing block" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) block (result i32) i32.const 7 br 0 end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "remove-unused-brs removes trailing return at function exit" {
  let optimized = match
    pass_test_run_pipeline("(module (func (result i32) i32.const 9 return))", [
      "remove-unused-brs",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs return success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "remove-unused-brs rewrites one-armed if break into br_if" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) block local.get 0 if br 1 end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs if success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs flattens block-local if-else break chains into br_if" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) block $exit local.get 0 if br $exit else local.get 1 if br $exit end end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs block chain success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs rewrites pure value if into select" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (if (result i32) (local.get 0) (then (i32.const 1)) (else (i32.const 0)))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs select success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs merges nested one-armed if conditions before branching" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) block $exit local.get 0 if local.get 1 if br $exit end end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs nested-if branch success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs rewrites nested condition if expressions under branches" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) block $exit local.get 0 if (result i32) local.get 1 else i32.const 0 end if br $exit end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs nested condition success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs flattens else-if ladders with embedded value-if conditions" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) block $exit local.get 0 i32.const 10 i32.ge_s if (result i32) local.get 0 i32.const 20 i32.le_s else i32.const 0 end if br $exit else local.get 0 i32.const 30 i32.ge_s if (result i32) local.get 0 i32.const 40 i32.le_s else i32.const 0 end if br $exit else local.get 0 i32.const 50 i32.eq if br $exit end end end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected remove-unused-brs ladder success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
}

///|
test "remove-unused-brs descends into control ladders nested under drop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (drop (block (result i32) (block $exit (if (local.get 0) (then (br $exit)) (else (if (local.get 1) (then (br $exit)))))) (i32.const 0)))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs nested-drop success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "remove-unused-brs rewrites local.set if copy arms into one-armed ifs" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) (local.set 1 (i32.const 0)) (local.set 1 (if (result i32) (local.get 0) (then (i32.const 1)) (else (local.get 1))))))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs local.set copy-arm success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 1))"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 1))"), msg=pretty)
}

///|
test "remove-unused-brs rewrites local.set if break arms into br_if plus set" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) block $exit (local.set 1 (if (result i32) (local.get 0) (then (br $exit)) (else (i32.const 7)))) end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs local.set br-arm success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 1))"), msg=pretty)
  assert_false(pretty.contains("(if (I32)"), msg=pretty)
}

///|
test "remove-unused-brs flattens block-local if chains when the else arm breaks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) block $exit local.get 0 if local.get 1 drop else br $exit end end))",
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected remove-unused-brs flipped block chain success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}
