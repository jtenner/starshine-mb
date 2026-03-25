///|
test "global-struct-inference folds immutable struct fields only in closed world" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 7)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let unchanged = match
    pass_test_run_pipeline(input, ["global-struct-inference"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected non-closed-world global-struct-inference success, got \{err}",
      )
  }
  assert_true(
    unchanged.pretty_print_func(@lib.FuncIdx::new(0U)).contains("struct.get"),
  )

  let optimized = match
    pass_test_run_pipeline(
      input,
      ["global-struct-inference"],
      options=HotPipelineOptions::new(closed_world=true),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected closed-world global-struct-inference success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.get"))
  assert_true(pretty.contains("global.get"))
  assert_true(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "global-struct-inference leaves non-global ref producers unchanged" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 7)))
    #|   (func (export "read") (param (ref $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["global-struct-inference"],
      options=HotPipelineOptions::new(closed_world=true),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected non-global producer global-struct-inference success, got \{err}",
      )
  }

  assert_true(
    optimized.pretty_print_func(@lib.FuncIdx::new(0U)).contains("struct.get"),
  )
}
