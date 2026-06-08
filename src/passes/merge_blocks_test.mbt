///|
fn merge_blocks_test_count_substring(text : String, needle : String) -> Int {
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
fn merge_blocks_large_jsonas_like_fixture() -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32")
  for i = 0; i < 129; i = i + 1 {
    let _ = i
    out.write_string(" i32")
  }
  out.write_string(")")
  for i = 0; i < 1001; i = i + 1 {
    let _ = i
    out.write_string(" nop")
  }
  out.write_string("))")
  out.to_string()
}

///|
test "merge-blocks skips large local-heavy json-as shaped functions" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      merge_blocks_large_jsonas_like_fixture(),
      ["merge-blocks"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected large merge-blocks skip success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[merge-blocks]:skip-raw reason=large-local-merge-blocks-noop",
      )
    }),
    msg=trace.to_string(),
  )
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
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "nop"),
    4,
    msg=pretty,
  )
}

///|
test "merge-blocks preserves loop wrapper blocks with continue targets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (block (loop $l local.get 0 if local.get 0 i32.const 1 i32.sub local.set 0 br $l end)) local.get 0))",
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-blocks loop-wrapper success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block"), msg=pretty)
  assert_true(pretty.contains("(loop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
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
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "nop"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("br"), msg=pretty)
}

///|
test "merge-blocks preserves typed single-param loop carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32) (result i32)))
    #|   (func (result i32)
    #|     i32.const 4
    #|     (loop (type $t)
    #|       (block (type $t)
    #|         i32.const 1
    #|         i32.add))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks typed single-param loop success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.add"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("(loop I32"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "merge-blocks preserves typed single-param multi-result loop carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32) (result i32 i64)))
    #|   (func (result i32 i64)
    #|     i32.const 4
    #|     (loop (type $t)
    #|       (block (type $t)
    #|         drop
    #|         i32.const 1
    #|         i64.const 2))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param multi-result loop success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i64.const"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("(loop"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I64(2)"), msg=pretty)
}

///|
test "merge-blocks keeps dead values dropped before unreachable exits" {
  let source =
    #| (module
    #|   (func (result v128)
    #|     (block (result i32)
    #|       (v128.const i32x4 0x00e37a44 0x00000000 0x00000000 0x00000000)
    #|       unreachable)
    #|     unreachable))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks unreachable-dead-value repro success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("v128.const"), msg=pretty)
  assert_false(
    pretty.contains("unreachable\n    unreachable\n    v128.const"),
    msg=pretty,
  )
}

///|
test "merge-blocks preserves typed single-param multi-result loop if-arm carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32) (result i32 i64)))
    #|   (func (param i32) (result i32 i64)
    #|     (if (result i32 i64)
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             drop
    #|             i32.const 1
    #|             i64.const 2)))
    #|       (else
    #|         i32.const 8
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             drop
    #|             i32.const 3
    #|             i64.const 4))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param multi-result loop if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    5,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i64.const"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("(loop"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
  assert_true(pretty.contains("I64(2)"), msg=pretty)
  assert_true(pretty.contains("I64(4)"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-param single-result loop lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32) (result i32)))
    #|   (func (result i32)
    #|     i32.const 4
    #|     i32.const 5
    #|     (loop (type $t)
    #|       (block (type $t)
    #|         i32.add))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param single-result loop success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.add"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("(loop"), msg=pretty)
  assert_true(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(5)"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-param multi-result loop lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32) (result i32 i64)))
    #|   (func (result i32 i64)
    #|     i32.const 4
    #|     i32.const 5
    #|     (loop (type $t)
    #|       (block (type $t)
    #|         i32.add
    #|         i64.const 7))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param multi-result loop success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "tuple.make"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.add"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i64.const"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("(loop"), msg=pretty)
  assert_true(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I64(7)"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-param single-result loop if-arm lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32) (result i32)))
    #|   (func (param i32) (result i32)
    #|     (if (result i32)
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         i32.const 5
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             i32.add)))
    #|       (else
    #|         i32.const 8
    #|         i32.const 9
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             i32.add))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param single-result loop if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.add"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-param multi-result loop if-arm lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32) (result i32 i64)))
    #|   (func (param i32) (result i32 i64)
    #|     (if (result i32 i64)
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         i32.const 5
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             i32.add
    #|             i64.const 7)))
    #|       (else
    #|         i32.const 8
    #|         i32.const 9
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             i32.add
    #|             i64.const 11))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param multi-result loop if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "tuple.make"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.add"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i64.const"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("Type 2"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I64(11)"), msg=pretty)
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
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
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
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
}

///|
test "merge-blocks preserves drop-leading typed single-param single-result block lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32) (result i32)))
    #|   (func (result i32)
    #|     i32.const 4
    #|     (block (type $t)
    #|       (block (type $t)
    #|         drop
    #|         i32.const 1))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks drop-leading typed single-result success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "merge-blocks preserves typed single-param externref single-result block lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param externref) (result externref)))
    #|   (func (result externref)
    #|     ref.null extern
    #|     (block (type $t)
    #|       (block (type $t)
    #|         drop
    #|         ref.null extern))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param externref single-result success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "ref.null"),
    2,
    msg=pretty,
  )
}

///|
test "merge-blocks preserves typed single-param externref single-result loop lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param externref) (result externref)))
    #|   (func (result externref)
    #|     ref.null extern
    #|     (loop (type $t)
    #|       (block (type $t)
    #|         drop
    #|         ref.null extern))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param externref single-result loop success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "ref.null"),
    2,
    msg=pretty,
  )
}

///|
test "merge-blocks preserves typed single-param void block carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32)))
    #|   (func
    #|     i32.const 4
    #|     (block (type $t)
    #|       (block (type $t)
    #|         drop))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param void block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
}

///|
test "merge-blocks preserves typed single-param void block if-arm carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32)))
    #|   (func (param i32)
    #|     (if
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop)))
    #|       (else
    #|         i32.const 8
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param void block if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    5,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-param void block carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32)))
    #|   (func
    #|     i32.const 4
    #|     i32.const 5
    #|     (block (type $t)
    #|       (block (type $t)
    #|         drop
    #|         drop))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param void block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(5)"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-param void block if-arm carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32)))
    #|   (func (param i32)
    #|     (if
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         i32.const 5
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop
    #|             drop)))
    #|       (else
    #|         i32.const 8
    #|         i32.const 9
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop
    #|             drop))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param void block if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    4,
    msg=pretty,
  )
  assert_true(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "merge-blocks drops branch-free typed single-param void loop carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32)))
    #|   (func
    #|     i32.const 4
    #|     (loop (type $t)
    #|       (block (type $t)
    #|         drop))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param void loop success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
}

///|
test "merge-blocks drops branch-free typed single-param void loop if-arm carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32)))
    #|   (func (param i32)
    #|     (if
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             drop)))
    #|       (else
    #|         i32.const 8
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             drop))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param void loop if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    5,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "merge-blocks drops branch-free typed multi-param void loop carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32)))
    #|   (func
    #|     i32.const 4
    #|     i32.const 5
    #|     (loop (type $t)
    #|       (block (type $t)
    #|         drop
    #|         drop))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param void loop success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(5)"), msg=pretty)
}

///|
test "merge-blocks drops branch-free typed multi-param void loop if-arm carriers Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32)))
    #|   (func (param i32)
    #|     (if
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         i32.const 5
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             drop
    #|             drop)))
    #|       (else
    #|         i32.const 8
    #|         i32.const 9
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             drop
    #|             drop))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param void loop if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    4,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "merge-blocks keeps typed single-result if-arm param block lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32) (result i32)))
    #|   (func (param i32) (result i32)
    #|     (if (result i32)
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         (block (type $t)
    #|           (block (type $t)
    #|             i32.const 1
    #|             i32.add)))
    #|       (else
    #|         i32.const 8
    #|         (block (type $t)
    #|           (block (type $t)
    #|             i32.const 2
    #|             i32.add))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-result if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    5,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.add"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "merge-blocks keeps drop-leading typed single-param single-result if-arm lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32) (result i32)))
    #|   (func (param i32) (result i32)
    #|     (if (result i32)
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop
    #|             i32.const 1)))
    #|       (else
    #|         i32.const 8
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop
    #|             i32.const 2))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks drop-leading typed single-result if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    5,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    4,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "merge-blocks flattens typed multi-result branch-free if-arm blocks into tuple.make results" {
  let source =
    #| (module
    #|   (func (param i32) (result i32 i64)
    #|     (if (result i32 i64)
    #|       (local.get 0)
    #|       (then
    #|         (block (result i32 i64)
    #|           (block (result i32 i64)
    #|             i32.const 1
    #|             i64.const 2)))
    #|       (else
    #|         (block (result i32 i64)
    #|           (block (result i32 i64)
    #|             i32.const 3
    #|             i64.const 4))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-result if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  assert_true(pretty.contains("(if (Type"), msg=pretty)
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i64.const"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I64(4)"), msg=pretty)
}

///|
test "merge-blocks preserves typed single-param externref single-result if-arm lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param externref) (result externref)))
    #|   (func (param i32) (result externref)
    #|     (if (result externref)
    #|       (local.get 0)
    #|       (then
    #|         ref.null extern
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop
    #|             ref.null extern)))
    #|       (else
    #|         ref.null extern
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop
    #|             ref.null extern))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param externref single-result if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    5,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "ref.null"),
    4,
    msg=pretty,
  )
}

///|
test "merge-blocks preserves typed single-param funcref single-result block lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param funcref) (result funcref)))
    #|   (func (result funcref)
    #|     ref.null func
    #|     (block (type $t)
    #|       (block (type $t)
    #|         drop
    #|         ref.null func))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param funcref single-result success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "ref.null"),
    2,
    msg=pretty,
  )
}

///|
test "merge-blocks preserves typed single-param funcref single-result loop lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param funcref) (result funcref)))
    #|   (func (result funcref)
    #|     ref.null func
    #|     (loop (type $t)
    #|       (block (type $t)
    #|         drop
    #|         ref.null func))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param funcref single-result loop success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "ref.null"),
    2,
    msg=pretty,
  )
}

///|
test "merge-blocks preserves typed single-param funcref multi-result if-arm lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param funcref) (result funcref i32)))
    #|   (func (param i32) (result funcref i32)
    #|     (if (result funcref i32)
    #|       (local.get 0)
    #|       (then
    #|         ref.null func
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop
    #|             ref.null func
    #|             i32.const 7)))
    #|       (else
    #|         ref.null func
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop
    #|             ref.null func
    #|             i32.const 9))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param funcref multi-result if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    5,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "ref.null"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "merge-blocks rewrites typed single-param externref multi-result loop if-arm carriers to Binaryen-stable result-only loops" {
  let source =
    #| (module
    #|   (type $t (func (param externref) (result externref i32)))
    #|   (func (param i32) (result externref i32)
    #|     (if (result externref i32)
    #|       (local.get 0)
    #|       (then
    #|         ref.null extern
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             drop
    #|             ref.null extern
    #|             i32.const 7)))
    #|       (else
    #|         ref.null extern
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             drop
    #|             ref.null extern
    #|             i32.const 9))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param externref multi-result loop if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    5,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "ref.null"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("Type 2"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "merge-blocks rewrites typed single-param funcref multi-result loop if-arm carriers to Binaryen-stable result-only loops" {
  let source =
    #| (module
    #|   (type $t (func (param funcref) (result funcref i32)))
    #|   (func (param i32) (result funcref i32)
    #|     (if (result funcref i32)
    #|       (local.get 0)
    #|       (then
    #|         ref.null func
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             drop
    #|             ref.null func
    #|             i32.const 7)))
    #|       (else
    #|         ref.null func
    #|         (loop (type $t)
    #|           (block (type $t)
    #|             drop
    #|             ref.null func
    #|             i32.const 9))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param funcref multi-result loop if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    5,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "ref.null"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("Type 2"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "merge-blocks rewrites typed single-param externref multi-result loop roots to Binaryen-stable result-only loops" {
  let source =
    #| (module
    #|   (type $t (func (param externref) (result externref i32)))
    #|   (type $u (func (result externref i32)))
    #|   (func (type $u) (result externref i32)
    #|     ref.null extern
    #|     (loop (type $t)
    #|       (block (type $t)
    #|         drop
    #|         ref.null extern
    #|         i32.const 7))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param externref multi-result loop root success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "ref.null"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("Type 1"), msg=pretty)
  assert_false(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "merge-blocks rewrites typed single-param funcref multi-result loop roots to Binaryen-stable result-only loops" {
  let source =
    #| (module
    #|   (type $t (func (param funcref) (result funcref i32)))
    #|   (type $u (func (result funcref i32)))
    #|   (func (type $u) (result funcref i32)
    #|     ref.null func
    #|     (loop (type $t)
    #|       (block (type $t)
    #|         drop
    #|         ref.null func
    #|         i32.const 7))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param funcref multi-result loop root success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "ref.null"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("Type 1"), msg=pretty)
  assert_false(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-param single-result block lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32) (result i32)))
    #|   (func (result i32)
    #|     i32.const 4
    #|     i32.const 5
    #|     (block (type $t)
    #|       (block (type $t)
    #|         i32.add))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param single-result success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.add"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(5)"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-param single-result if-arm lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32) (result i32)))
    #|   (func (param i32) (result i32)
    #|     (if (result i32)
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         i32.const 5
    #|         (block (type $t)
    #|           (block (type $t)
    #|             i32.add)))
    #|       (else
    #|         i32.const 8
    #|         i32.const 9
    #|         (block (type $t)
    #|           (block (type $t)
    #|             i32.add))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param single-result if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.add"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-param multi-result if-arm lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32 i32) (result i32 i64)))
    #|   (func (param i32) (result i32 i64)
    #|     (if (result i32 i64)
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         i32.const 5
    #|         (block (type $t)
    #|           (block (type $t)
    #|             i32.add
    #|             i64.const 7)))
    #|       (else
    #|         i32.const 8
    #|         i32.const 9
    #|         (block (type $t)
    #|           (block (type $t)
    #|             i32.add
    #|             i64.const 11))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed multi-param multi-result if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.add"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "tuple.make"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i64.const"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("Type 2"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I64(11)"), msg=pretty)
}

///|
test "merge-blocks keeps typed multi-param multi-result block lowering Binaryen-stable" {
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
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "tuple.make"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.add"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("Type 0"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "merge-blocks keeps typed single-param multi-result block lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32) (result i32 i64)))
    #|   (func (result i32 i64)
    #|     i32.const 4
    #|     (block (type $t)
    #|       (block (type $t)
    #|         drop
    #|         i32.const 1
    #|         i64.const 2))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param multi-result success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i64.const"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I64(2)"), msg=pretty)
}

///|
test "merge-blocks keeps typed single-param multi-result if-arm lowering Binaryen-stable" {
  let source =
    #| (module
    #|   (type $t (func (param i32) (result i32 i64)))
    #|   (func (param i32) (result i32 i64)
    #|     (if (result i32 i64)
    #|       (local.get 0)
    #|       (then
    #|         i32.const 4
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop
    #|             i32.const 1
    #|             i64.const 2)))
    #|       (else
    #|         i32.const 8
    #|         (block (type $t)
    #|           (block (type $t)
    #|             drop
    #|             i32.const 3
    #|             i64.const 4))))))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected merge-blocks typed single-param multi-result if-arm success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.set"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "local.get"),
    5,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.const"),
    4,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i64.const"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
  assert_true(pretty.contains("I64(2)"), msg=pretty)
  assert_true(pretty.contains("I64(4)"), msg=pretty)
}

///|
test "merge-blocks lifts safe prefixes before live-label block breaks like Binaryen" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (func
        #|     (block $exit
        #|       (drop (i32.const 7))
        #|       (br $exit)
        #|       (drop (i32.const 9)))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks live-label prefix success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    1,
    msg=pretty,
  )
}

///|
test "merge-blocks moves block prefixes out of if conditions like Binaryen" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (func (param i32) (result i32)
        #|     (if (result i32)
        #|       (block (result i32)
        #|         (drop (i32.const 7))
        #|         (local.get 0))
        #|       (then (i32.const 1))
        #|       (else (i32.const 2)))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks if-condition motion success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  assert_true(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
}

///|
test "merge-blocks moves block prefixes out of drop operands like Binaryen" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (func
        #|     (drop
        #|       (block (result i32)
        #|         (drop (i32.const 7))
        #|         (i32.const 9)))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks drop-block motion success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "merge-blocks moves block prefixes out of store operands without reordering effects" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (memory 1)
        #|   (func (param i32)
        #|     (i32.store
        #|       (block (result i32)
        #|         (drop (i32.const 7))
        #|         (i32.const 0))
        #|       (block (result i32)
        #|         (drop (i32.const 8))
        #|         (local.get 0)))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks store operand motion success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "merge-blocks moves pure block prefixes out of throw operands like Binaryen" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (tag $e (param i32))
        #|   (func
        #|     (throw $e
        #|       (block (result i32)
        #|         (drop (i32.const 7))
        #|         (i32.const 9)))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks throw operand motion success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  assert_true(pretty.contains("throw"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}
