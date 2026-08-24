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
test "merge-blocks intentionally fails closed for measured emscripten stateful runtime shapes" {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (func (export \"_main\")) (func (export \"runPostSets\")) (func (export \"stackAlloc\")) (func (export \"stackSave\")) (func (export \"stackRestore\"))",
  )
  for idx = 5; idx < 44; idx = idx + 1 {
    wat.write_string(" (func)")
  }
  wat.write_string(")")
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      wat.to_string(),
      ["merge-blocks"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=4,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected guarded merge-blocks success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("emscripten-main-stateful-runtime-merge-blocks-noop")
    }),
    msg="\{trace}",
  )
}

///|
test "merge-blocks defers structured load-local carriers" {
  let input = StringBuilder::new()
  input.write_string("(module (memory 1) (func")
  // The cumulative O4z pipeline reduces the production parser to 14 body
  // locals before merge-blocks; isolated pass replay retained 15.
  for i = 0; i < 14; i = i + 1 {
    let _ = i
    input.write_string(" (local i32)")
  }
  input.write_string(
    " block loop i32.const 0 i32.load local.set 0 br 1 end end))",
  )
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input.to_string(),
      ["merge-blocks"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected load-local carrier boundary, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=structured-load-local-merge-blocks-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "merge-blocks defers structured call-local carriers" {
  let input = StringBuilder::new()
  input.write_string("(module (func $callee) (func")
  for i = 0; i < 18; i = i + 1 {
    let _ = i
    input.write_string(" (local i32)")
  }
  input.write_string(" block call $callee i32.const 1 local.set 0 end))")
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input.to_string(),
      ["merge-blocks"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected call-local carrier boundary, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=large-call-structured-merge-blocks-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "merge-blocks defers large structured SIMD local carriers" {
  let input = StringBuilder::new()
  input.write_string("(module (func")
  for i = 0; i < 32; i = i + 1 {
    let _ = i
    input.write_string(" (local v128)")
  }
  input.write_string(" block end))")
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input.to_string(),
      ["merge-blocks"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected SIMD carrier boundary, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=large-simd-structured-merge-blocks-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "merge-blocks scans deeply nested AssemblyScript dispatchers once per structured edge" {
  let input = StringBuilder::new()
  input.write_string("(module (func (param i32)")
  for _ in 0..<60 {
    input.write_string(" block")
  }
  input.write_string(" local.get 0 br_table")
  for label = 0; label < 60; label = label + 1 {
    input.write_string(" ")
    input.write_string(label.to_string())
  }
  input.write_string(" 59")
  for _ in 0..<60 {
    input.write_string(" end")
  }
  input.write_string("))")
  match pass_test_run_pipeline(input.to_string(), ["merge-blocks"]) {
    Ok(_) => ()
    Err(err) => fail("expected bounded nested-dispatch cleanup, got \{err}")
  }
}

///|
test "merge-blocks preserves stack-carried accumulator read before sibling local write" {
  let input =
    #|(module
    #|  (func (export "fib") (param i32) (result i64) (local i64 i64)
    #|    i64.const 0
    #|    local.set 1
    #|    i64.const 1
    #|    local.set 2
    #|    loop
    #|      block
    #|        block
    #|          local.get 0
    #|          i32.eqz
    #|          br_if 1
    #|          local.get 1
    #|          local.get 2
    #|          i64.add
    #|          local.get 2
    #|          local.set 1
    #|          local.set 2
    #|          local.get 0
    #|          i32.const 1
    #|          i32.sub
    #|          local.set 0
    #|          br 2
    #|        end
    #|        unreachable
    #|      end
    #|    end
    #|    local.get 1))
  let optimized = match pass_test_run_pipeline(input, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected stack-carried accumulator preservation, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(
    pretty.contains(
      "(local.get (Local 1))(local.get (Local 2))i64.add(local.get (Local 2))(local.set (Local 1))(local.set (Local 2))",
    ),
    msg=pretty,
  )
}

///|
test "merge-blocks preserves stack-carried locals overwritten before a later call" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func $use (param i32 i32 i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32) (local i32)
    #|    block (result i32)
    #|      i32.const 17216
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 0
    #|      local.get 0
    #|      local.set 1
    #|      i32.const 0
    #|      local.get 1
    #|      i32.store
    #|      local.get 1
    #|      call $use
    #|    end))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["merge-blocks"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected stack-carried local preservation, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=stack-carried-overwritten-local-merge-blocks-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "merge-blocks defers call-result locals beside memory copy" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func $alloc (param i32 i32) (result i32) local.get 0)
    #|  (func (param i32) (local i32)
    #|    block
    #|      local.get 0
    #|      i32.const 2
    #|      call $alloc
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 0
    #|      local.get 0
    #|      memory.copy
    #|    end))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["merge-blocks"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected call-result memory-copy boundary, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=call-result-memory-copy-merge-blocks-noop")
    }),
    msg=trace.to_string(),
  )
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
test "merge-blocks defers the drop-parent index when no multivalue block needs it" {
  let trace : Array[String] = []
  let trace_fn = fn(line) { trace.push(line) }
  let perf = HotPerfSession::new(
    trace=trace_fn,
    dump_options=HotPerfDumpOptions::new(),
  )
  match
    pass_test_run_pipeline(
      "(module (func (block (nop) (block (nop)) (nop))))",
      ["merge-blocks"],
      options=HotPipelineOptions::new(trace=Some(trace_fn), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar merge-blocks perf fixture success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[merge-blocks]:drop-parent-index") }),
    msg=trace.to_string(),
  )
}

///|
test "merge-blocks re-lifts multivalue call blocks with trailing drop" {
  let source =
    #|(module
    #|  (type $pair (func (result i32 i32)))
    #|  (type $callee (func (param i32 i32 i32) (result i32 i32)))
    #|  (func $target (type $callee) (param i32 i32 i32) (result i32 i32)
    #|    local.get 0
    #|    i32.const 9)
    #|  (func (param i32 i32 i32) (result i32)
    #|    block (type $pair)
    #|      i32.const 0
    #|      local.get 1
    #|      local.get 2
    #|      call $target
    #|    end
    #|    drop))
  ignore(
    match pass_test_run_pipeline(source, ["merge-blocks", "merge-blocks"]) {
      Ok(mod_) => mod_
      Err(err) =>
        fail(
          "expected multivalue block merge-blocks relift success, got \{err}",
        )
    },
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
test "merge-blocks removes branch-free untyped loops with explicit block bodies like Binaryen" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (loop (block (drop (i32.const 7))))))",
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks branch-free loop success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(loop"),
    0,
    msg=pretty,
  )
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "merge-blocks removes branch-free untyped loops without wrapper blocks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (loop (drop (i32.const 7)) (drop (i32.const 8)))))",
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected plain branch-free loop cleanup, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(loop"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
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
test "merge-blocks keeps prefixes inside live-label blocks" {
  let source =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     (block $live
    #|       (local.set 0 (i32.const 1))
    #|       (br $live))
    #|     (i32.const 7)))
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks live-label-prefix success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
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
test "merge-blocks moves effectful block prefixes across pure earlier call operands like Binaryen" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (type $r (func (result i32)))
        #|   (type $p (func (param i32 i32) (result i32)))
        #|   (global $g (mut i32) (i32.const 0))
        #|   (func $pick (type $p) (param i32 i32) (result i32) (local.get 1))
        #|   (func (type $r) (result i32)
        #|     (call $pick
        #|       (i32.add (i32.const 1) (i32.const 2))
        #|       (block (result i32)
        #|         (global.set $g (i32.const 99))
        #|         (i32.const 7)))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks pure-call-operand success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("(call"), msg=pretty)
}

///|
test "merge-blocks lifts flat stack call operand prefixes reconstructed as blocks like Binaryen" {
  let result_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let pick_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    ),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([result_type, pick_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), true),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::i32_const(@lib.I32(99)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::memory_grow(@lib.MemIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(100)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_load(@lib.MemArg::new(2U, None, 0UL)),
            @lib.Instruction::i32_const(@lib.I32(101)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::new([@lib.LocalRun::new(1U, @lib.ValType::i32())]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(10)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::i32_const(@lib.I32(102)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::i32_const(@lib.I32(4)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::i32_const(@lib.I32(103)),
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(12)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["merge-blocks"]) {
    Ok(result) => result
    Err(err) =>
      fail("expected merge-blocks flat-stack call success, got \{err}")
  }
  let funcs = match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected merge-blocks flat-stack code section")
  }
  let pure_body = match funcs[1] {
    @lib.Func(_, @lib.Expr(body)) => body
  }
  match pure_body {
    [
      @lib.I32Const(@lib.I32(99)),
      @lib.GlobalSet(@lib.GlobalIdx(0U)),
      @lib.I32Const(@lib.I32(1)),
      @lib.I32Const(@lib.I32(2)),
      @lib.I32Add,
      @lib.I32Const(@lib.I32(7)),
      @lib.Call(@lib.FuncIdx(0U)),
    ] => ()
    _ =>
      fail(
        "expected global.set before the pure first operand, got \{pure_body}",
      )
  }
  let memory_grow_body = match funcs[2] {
    @lib.Func(_, @lib.Expr(body)) => body
  }
  match memory_grow_body {
    [
      @lib.I32Const(@lib.I32(100)),
      @lib.GlobalSet(@lib.GlobalIdx(0U)),
      @lib.I32Const(@lib.I32(0)),
      @lib.MemoryGrow(@lib.MemIdx(0U)),
      @lib.I32Const(@lib.I32(8)),
      @lib.Call(@lib.FuncIdx(0U)),
    ] => ()
    _ =>
      fail(
        "expected global.set before the disjoint memory.grow operand, got \{memory_grow_body}",
      )
  }
  let trapping_load_body = match funcs[3] {
    @lib.Func(_, @lib.Expr(body)) => body
  }
  match trapping_load_body {
    [
      @lib.I32Const(@lib.I32(0)),
      @lib.I32Load(_),
      @lib.I32Const(@lib.I32(101)),
      @lib.GlobalSet(@lib.GlobalIdx(0U)),
      @lib.I32Const(@lib.I32(9)),
      @lib.Call(@lib.FuncIdx(0U)),
    ] => ()
    _ =>
      fail(
        "expected trapping load to remain before global.set, got \{trapping_load_body}",
      )
  }
  let local_conflict_body = match funcs[4] {
    @lib.Func(_, @lib.Expr(body)) => body
  }
  match local_conflict_body {
    [
      @lib.I32Const(@lib.I32(1)),
      @lib.LocalTee(@lib.LocalIdx(0U)),
      @lib.LocalGet(@lib.LocalIdx(0U)),
      @lib.GlobalSet(@lib.GlobalIdx(0U)),
      @lib.I32Const(@lib.I32(10)),
      @lib.Call(@lib.FuncIdx(0U)),
    ] => ()
    _ =>
      fail(
        "expected local-dependent prefix to remain after the earlier local write, got \{local_conflict_body}",
      )
  }
  let repeated_body = match funcs[5] {
    @lib.Func(_, @lib.Expr(body)) => body
  }
  match repeated_body {
    [
      @lib.I32Const(@lib.I32(102)),
      @lib.GlobalSet(@lib.GlobalIdx(0U)),
      @lib.I32Const(@lib.I32(1)),
      @lib.I32Const(@lib.I32(2)),
      @lib.I32Add,
      @lib.I32Const(@lib.I32(11)),
      @lib.Call(@lib.FuncIdx(0U)),
      @lib.Drop,
      @lib.I32Const(@lib.I32(103)),
      @lib.GlobalSet(@lib.GlobalIdx(0U)),
      @lib.I32Const(@lib.I32(3)),
      @lib.I32Const(@lib.I32(4)),
      @lib.I32Add,
      @lib.I32Const(@lib.I32(12)),
      @lib.Call(@lib.FuncIdx(0U)),
    ] => ()
    _ =>
      fail(
        "expected every eligible flat call prefix to move in one pass, got \{repeated_body}",
      )
  }
}

///|
test "merge-blocks moves global writes across disjoint earlier memory effects like Binaryen" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (type $r (func (result i32)))
        #|   (type $p (func (param i32 i32) (result i32)))
        #|   (memory 1)
        #|   (global $g (mut i32) (i32.const 0))
        #|   (func $pick (type $p) (param i32 i32) (result i32) (local.get 1))
        #|   (func (type $r) (result i32)
        #|     (call $pick
        #|       (memory.grow (i32.const 0))
        #|       (block (result i32)
        #|         (global.set $g (i32.const 100))
        #|         (i32.const 8)))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks disjoint-effect success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "(block"),
    0,
    msg=pretty,
  )
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("(call"), msg=pretty)
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

///|
test "merge-blocks removes pure values from dropped self-target branches" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (drop (block $exit (result i32) (br $exit (i32.const 42))))))",
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks dropped-branch cleanup success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr([@lib.Block(_, _)]))])) => ()
    _ =>
      fail(
        "expected Binaryen-shaped top-level void block after dropped branch cleanup, got \{optimized.pretty_print_func(@lib.FuncIdx::new(0U))}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(42)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
}

///|
test "merge-blocks removes pure scalar values from dropped self-target branches" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (func (drop (block $i64 (result i64) (br $i64 (i64.const 42)))))
        #|   (func (drop (block $f32 (result f32) (br $f32 (f32.const 4)))))
        #|   (func (drop (block $f64 (result f64) (br $f64 (f64.const 4))))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected scalar dropped-branch cleanup success, got \{err}")
  }
  for func_idx = 0U; func_idx < 3U; func_idx = func_idx + 1U {
    let body = match optimized.code_sec {
      Some(@lib.CodeSec(funcs)) =>
        match funcs[func_idx.reinterpret_as_int()] {
          @lib.Func(_, @lib.Expr(body)) => body
        }
      None => fail("expected scalar dropped-branch code section")
    }
    match body {
      [@lib.Block(@lib.VoidBlockType, _)] => ()
      _ => fail("expected scalar dropped branch to become void: \{body}")
    }
  }
}

///|
test "merge-blocks drops pure multivalue block results without spill locals" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (func
        #|     (block (result i32 i64)
        #|       (i32.const 11)
        #|       (i64.const 13)
        #|     )
        #|     (drop)
        #|     (drop)
        #|   )
        #| )
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dropped multivalue cleanup success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, @lib.Expr(body))])) => {
      assert_eq(locals.length(), 0)
      assert_eq(body.length(), 4)
      assert_true(body[0] is @lib.I32Const(_))
      assert_true(body[1] is @lib.Drop)
      assert_true(body[2] is @lib.I64Const(_))
      assert_true(body[3] is @lib.Drop)
    }
    _ => fail("expected one optimized multivalue function")
  }
}

///|
test "merge-blocks preserves stacked arguments around multi-parameter dropped calls" {
  let source =
    #| (module
    #|   (func $pair (param i32 i32) (result i32) (local.get 0))
    #|   (func (result i32)
    #|     (i32.const 7)
    #|     (i32.const 8)
    #|     (call $pair)
    #|     (drop)
    #|     (i32.const 9)
    #|     (i32.const 10)
    #|     (call $pair)
    #|   )
    #| )
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected stacked call arguments to remain valid, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected stacked call argument validity, got \{@validate.validation_error_message(err)}",
      )
  }
}

///|
test "merge-blocks removes pure values from nested dropped self-target branches" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (func
        #|     (drop
        #|       (block $exit (result i64)
        #|         (block
        #|           (br $exit (i64.const 42))
        #|         )
        #|         unreachable
        #|       )
        #|     )
        #|   )
        #| )
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested dropped-branch cleanup success, got \{err}")
  }
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr([@lib.Block(@lib.VoidBlockType, _)]))]
      )
    ) => ()
    _ =>
      fail(
        "expected nested dropped branch to become a void block, got \{optimized.pretty_print_func(@lib.FuncIdx::new(0U))}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I64(42)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("(block (I64)"), msg=pretty)
}

///|
test "merge-blocks keeps effectful values on dropped self-target branches" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (func $effect (result i32) (i32.const 7))
        #|   (func
        #|     (drop
        #|       (block $exit (result i32)
        #|         (br $exit (call $effect))))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected merge-blocks effectful branch bailout, got \{err}")
  }
  match optimized.code_sec {
    Some(
      @lib.CodeSec([_, @lib.Func(_, @lib.Expr([@lib.Block(_, _), @lib.Drop]))])
    ) => ()
    _ =>
      fail(
        "expected effectful branch payload to keep the dropped result block, got \{optimized.pretty_print_func(@lib.FuncIdx::new(1U))}",
      )
  }
}

///|
fn merge_blocks_ordered_atomic_test_module() -> @lib.Module {
  let shared_struct = @lib.TypeIdx::new(0U)
  let shared_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(shared_struct)),
  )
  let shared_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let memarg = @lib.MemArg::new(2U, None, 0UL)
  let call_body = fn(ordered_prefix : Array[@lib.Instruction]) -> @lib.Func {
    let first_arg = ordered_prefix.copy()
    first_arg.push(@lib.Instruction::i32_const(@lib.I32(0)))
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new(first_arg),
        ),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_get(shared_struct, @lib.U32(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(0)),
          ]),
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ]),
    )
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::struct_([shared_field]),
          metadata=@lib.TypeMetadata::new(shared=true),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([shared_ref], [])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
        ),
      ),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([
      @lib.TypeIdx::new(2U),
      @lib.TypeIdx::new(1U),
      @lib.TypeIdx::new(1U),
    ]),
  )
  .with_mem_sec(
    @lib.MemSec::new([
      @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      call_body([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_atomic_load(
          memarg,
          order=@lib.AtomicOrder::acq_rel(),
        ),
        @lib.Instruction::drop(),
      ]),
      call_body([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(42)),
        @lib.Instruction::i32_atomic_store(
          memarg,
          order=@lib.AtomicOrder::acq_rel(),
        ),
      ]),
    ]),
  )
}

///|
fn merge_blocks_test_top_level_instr_index(
  body : Array[@lib.Instruction],
  predicate : (@lib.Instruction) -> Bool,
) -> Int {
  for idx = 0; idx < body.length(); idx = idx + 1 {
    if predicate(body[idx]) {
      return idx
    }
  }
  -1
}

///|
test "merge-blocks respects acquire loads while keeping release-store motion" {
  let optimized = match
    run_hot_pipeline(
      merge_blocks_ordered_atomic_test_module(),
      HotPipelineOptions::new(),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ordered merge-blocks success, got \{err}")
  }
  let funcs = match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected ordered merge-blocks code section")
  }
  let disallowed = match funcs[1] {
    @lib.Func(_, @lib.Expr(body)) => body
  }
  let allowed = match funcs[2] {
    @lib.Func(_, @lib.Expr(body)) => body
  }
  let is_struct_get = fn(instr : @lib.Instruction) -> Bool {
    match instr {
      @lib.StructGet(_, _) => true
      _ => false
    }
  }
  let is_atomic_load = fn(instr : @lib.Instruction) -> Bool {
    match instr {
      @lib.I32AtomicLoad(_, _) => true
      _ => false
    }
  }
  let is_atomic_store = fn(instr : @lib.Instruction) -> Bool {
    match instr {
      @lib.I32AtomicStore(_, _) => true
      _ => false
    }
  }
  let disallowed_load = merge_blocks_test_top_level_instr_index(
    disallowed, is_atomic_load,
  )
  let disallowed_struct = merge_blocks_test_top_level_instr_index(
    disallowed, is_struct_get,
  )
  assert_true(disallowed_load >= 0, msg=disallowed.to_string())
  assert_true(
    disallowed_struct < 0 || disallowed_load < disallowed_struct,
    msg=disallowed.to_string(),
  )
  assert_true(
    merge_blocks_test_top_level_instr_index(allowed, is_atomic_store) >= 0,
    msg=allowed.to_string(),
  )
  assert_true(
    merge_blocks_test_top_level_instr_index(allowed, is_struct_get) >= 0,
    msg=allowed.to_string(),
  )
}

///|
test "merge-blocks does not execute effectful roots after unreachable" {
  let source =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $set (result i32)
    #|     i32.const 1
    #|     global.set $g
    #|     i32.const 7)
    #|   (func (result i32)
    #|     block (result i32)
    #|       unreachable
    #|       call $set
    #|     end))
    #|
  let baseline = match pass_test_run_pipeline(source, []) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-blocks baseline success, got \{err}")
  }
  let optimized = match pass_test_run_pipeline(source, ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-blocks dead suffix success, got \{err}")
  }

  @debug.assert_eq(optimized, baseline)
}

///|
test "merge-blocks preserves load-before-division trap order" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (type $pick_t (func (param i32 i32) (result i32)))
        #|   (memory 1)
        #|   (func $pick (type $pick_t) (param i32 i32) (result i32)
        #|     (local.get 1))
        #|   (func (result i32)
        #|     (call $pick
        #|       (i32.load (i32.const 65536))
        #|       (block (result i32)
        #|         (drop (i32.div_s (i32.const 1) (i32.const 0)))
        #|         (i32.const 7)))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected load/division trap-order success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(block"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("i32.div_s"), msg=pretty)
}

///|
test "merge-blocks preserves the order of two trapping loads" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (type $pick_t (func (param i32 i32) (result i32)))
        #|   (memory 1)
        #|   (func $pick (type $pick_t) (param i32 i32) (result i32)
        #|     (local.get 1))
        #|   (func (result i32)
        #|     (call $pick
        #|       (i32.load (i32.const 65536))
        #|       (block (result i32)
        #|         (drop (i32.load (i32.const 65540)))
        #|         (i32.const 7)))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected two-load trap-order success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(block"), msg=pretty)
  @debug.assert_eq(
    merge_blocks_test_count_substring(pretty, "i32.load"),
    2,
    msg=pretty,
  )
}

///|
test "merge-blocks preserves table-access-before-division trap order" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #| (module
        #|   (type $pick_t (func (param funcref i32) (result i32)))
        #|   (table 1 funcref)
        #|   (func $pick (type $pick_t) (param funcref i32) (result i32)
        #|     (local.get 1))
        #|   (func (result i32)
        #|     (call $pick
        #|       (table.get 0 (i32.const 1))
        #|       (block (result i32)
        #|         (drop (i32.div_s (i32.const 1) (i32.const 0)))
        #|         (i32.const 7)))))
      ),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected table/division trap-order success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(block"), msg=pretty)
  assert_true(pretty.contains("table.get"), msg=pretty)
  assert_true(pretty.contains("i32.div_s"), msg=pretty)
}

///|
fn merge_blocks_atomic_trap_order_module() -> @lib.Module {
  let pick_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    ),
  )
  let result_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([pick_type, result_type]))
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
  )
  .with_mem_sec(
    @lib.MemSec::new([
      @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(65536)),
          @lib.Instruction::i32_atomic_load(
            @lib.MemArg::new(2U, None, 0UL),
            order=@lib.AtomicOrder::acq_rel(),
          ),
          @lib.Instruction::block(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::i32_div_s(),
              @lib.Instruction::drop(),
              @lib.Instruction::i32_const(@lib.I32(7)),
            ]),
          ),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
test "merge-blocks preserves atomic-access-before-division trap order" {
  let optimized = match
    run_hot_pipeline(
      merge_blocks_atomic_trap_order_module(),
      HotPipelineOptions::new(),
      ["merge-blocks"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected atomic/division trap-order success, got \{err}")
  }
  let body = match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[1] {
        @lib.Func(_, @lib.Expr(body)) => body
      }
    None => fail("expected atomic trap-order code section")
  }
  assert_true(
    body.any(fn(instr) {
      match instr {
        @lib.Block(_, _) => true
        _ => false
      }
    }),
    msg=body.to_string(),
  )
}
