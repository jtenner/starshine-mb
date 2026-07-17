///|
test "simplify-locals-notee sinks single-use locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-notee"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-notee success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee does not create a sink tee for multi-use locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 drop local.get 1))",
      ["simplify-locals-notee"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-notee success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-notee still synthesizes if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else i32.const 9 local.set 1 end local.get 1))",
      ["simplify-locals-notee"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-notee success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-no-tee aliases the canonical no-tee pass" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-no-tee"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-no-tee alias success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "no-tee variants finish exposed computed local cleanup in one run" {
  let input = "(module (func (local i32 i32) i32.const 70 local.set 0 local.get 0 local.set 1 local.get 1 drop i32.const 71 i32.const 1 i32.add local.set 0 local.get 0 local.set 1 local.get 1 drop i32.const 72 i32.const 2 i32.add local.set 0 local.get 0 drop))"
  for
    pass_name in ["simplify-locals-notee", "simplify-locals-notee-nostructure"] {
    let once = match pass_test_run_pipeline(input, [pass_name]) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
      Err(err) => fail("expected \{pass_name} success, got \{err}")
    }
    let twice = match pass_test_run_pipeline(input, [pass_name, pass_name]) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
      Err(err) => fail("expected repeated \{pass_name} success, got \{err}")
    }
    assert_false(once.contains("local.set"), msg="\{pass_name}: \{once}")
    assert_false(once.contains("local.get"), msg="\{pass_name}: \{once}")
    @debug.assert_eq(once, twice)
  }
}

///|
test "structure variants do not retain a scratch local around nested-loop result nops" {
  let bytes = Bytes::from_array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 7, 1, 80, 0, 96, 0, 1, 124, 2, 1, 0, 3, 3, 2,
    0, 0, 4, 8, 1, 99, 0, 1, 98, 152, 207, 57, 5, 6, 1, 1, 141, 21, 156, 41, 9, 4,
    1, 7, 115, 0, 10, 26, 2, 20, 1, 1, 123, 3, 0, 3, 0, 68, 255, 255, 255, 255, 1,
    0, 0, 0, 1, 11, 11, 11, 3, 0, 0, 11,
  ])
  for pass_name in ["simplify-locals", "simplify-locals-notee"] {
    let input = match @binary.decode_module(bytes) {
      Ok(mod_) => mod_
      Err(err) =>
        fail("expected nested-loop witness decode success, got \{err}")
    }
    let pretty = match
      run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
      Err(err) => fail("expected \{pass_name} success, got \{err}")
    }
    assert_false(pretty.contains("local.set"), msg="\{pass_name}: \{pretty}")
    assert_false(pretty.contains("local.get"), msg="\{pass_name}: \{pretty}")
    assert_true(
      pretty.contains("nopnop(f64.const"),
      msg="\{pass_name}: \{pretty}",
    )
  }
}

///|
test "nesting-enabled variants lower unread effectful sets before return to drops" {
  let input = "(module (type $s (struct)) (func (local anyref) struct.new_default $s local.set 0 local.get 0 drop return local.get 0 drop))"
  for
    pass_name in [
      "simplify-locals", "simplify-locals-notee", "simplify-locals-nostructure",
      "simplify-locals-notee-nostructure",
    ] {
    let pretty = match pass_test_run_pipeline(input, [pass_name]) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
      Err(err) => fail("expected \{pass_name} success, got \{err}")
    }
    assert_false(pretty.contains("local.set"), msg="\{pass_name}: \{pretty}")
    assert_true(pretty.contains("drop"), msg="\{pass_name}: \{pretty}")
  }
}

///|
test "structure variants lift loop copy-through values into loop results" {
  let input = "(module (func (local i32 i32) loop i32.const 44 local.set 0 i32.const 5 drop local.get 0 local.set 1 end local.get 1 drop))"
  for pass_name in ["simplify-locals", "simplify-locals-notee"] {
    let pretty = match pass_test_run_pipeline(input, [pass_name]) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
      Err(err) => fail("expected \{pass_name} success, got \{err}")
    }
    assert_true(pretty.contains("loop I32"), msg="\{pass_name}: \{pretty}")
    assert_false(pretty.contains("local.set"), msg="\{pass_name}: \{pretty}")
    assert_false(pretty.contains("local.get"), msg="\{pass_name}: \{pretty}")
  }
}

///|
test "no-tee variants reuse the existing reference carrier after self-copy" {
  let bytes = Bytes::from_array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 22, 6, 96, 0, 0, 96, 0, 0, 96, 0, 0, 96, 0, 0,
    96, 0, 0, 95, 2, 127, 1, 109, 0, 3, 2, 1, 0, 7, 8, 1, 4, 109, 97, 105, 110, 0,
    0, 8, 1, 0, 10, 52, 1, 50, 3, 1, 127, 1, 99, 0, 1, 99, 5, 65, 10, 208, 109, 251,
    0, 5, 33, 2, 32, 2, 65, 30, 251, 5, 5, 0, 32, 2, 251, 2, 5, 0, 26, 251, 1, 5,
    33, 2, 32, 2, 33, 2, 32, 2, 251, 2, 5, 0, 26, 11,
  ])
  for
    pass_name in ["simplify-locals-notee", "simplify-locals-notee-nostructure"] {
    let input = match @binary.decode_module(bytes) {
      Ok(mod_) => mod_
      Err(err) => fail("expected no-tee carrier witness decode, got \{err}")
    }
    let pretty = match
      run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
      Err(err) => fail("expected \{pass_name} success, got \{err}")
    }
    assert_false(
      pretty.contains("local.set (Local 1)"),
      msg="\{pass_name}: \{pretty}",
    )
    assert_false(
      pretty.contains("local.get (Local 1)"),
      msg="\{pass_name}: \{pretty}",
    )
  }
}

///|
test "simplify-locals-nonesting retargets flat local copies" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1))",
      ["simplify-locals-nonesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nonesting success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nonesting sinks computed values only into local sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 local.set 2 local.get 2))",
      ["simplify-locals-nonesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nonesting success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nonesting does not push computed values under drop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 drop))",
      ["simplify-locals-nonesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nonesting success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nonesting does not push computed values into calls" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $use (param i32)) (func (param i32) (local i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 call $use))",
      ["simplify-locals-nonesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nonesting success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nonesting does not synthesize if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else i32.const 9 local.set 1 end local.get 1))",
      ["simplify-locals-nonesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nonesting success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-no-nesting aliases the canonical flat pass" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1))",
      ["simplify-locals-no-nesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-no-nesting alias success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}
