///|
fn code_folding_test_run(text : String) -> @lib.Module {
  match pass_test_run_pipeline(text, ["code-folding"]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected code-folding pipeline success, got \{err}")
  }
}

///|
fn code_folding_test_run_module(mod_ : @lib.Module) -> @lib.Module {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => abort("unexpected invalid code-folding fixture: \{err}")
  }
  match run_hot_pipeline(mod_, HotPipelineOptions::new(), ["code-folding"]) {
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
test "code-folding keeps unprofitable full void if arms" {
  let optimized = code_folding_test_run(
    "(module (func (param i32) local.get 0 if i32.const 7 drop else i32.const 7 drop end))",
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding replaces worthwhile identical full void arms with condition drop plus shared suffix" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    local.get 0
      #|    if
      #|      i32.const 7
      #|      drop
      #|      i32.const 8
      #|      drop
      #|    else
      #|      i32.const 7
      #|      drop
      #|      i32.const 8
      #|      drop
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists identical full value if arms" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    local.get 0
      #|    if (result i32)
      #|      block (result i32)
      #|        i32.const 7
      #|      end
      #|    else
      #|      block (result i32)
      #|        i32.const 7
      #|      end
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding keeps simple full value if arms for optimize-instructions" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (if (result f32)
      #|      (local.get 0)
      #|      (then
      #|        (f32.const 0))
      #|      (else
      #|        (f32.const 0)))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding hoists identical partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    local.get 0
      #|    if (result i32)
      #|      i32.const 1
      #|      drop
      #|      i32.const 9
      #|    else
      #|      i32.const 2
      #|      drop
      #|      i32.const 9
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(9)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists exact partial non-block value if suffix" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (if (result f32)
      #|      (local.get 0)
      #|      (then
      #|        (nop)
      #|        (f32.const 0))
      #|      (else
      #|        (f32.const 0)))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists one-block then-arm value suffix" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32) (result f32)
      #|    (if (result f32)
      #|      (local.get 0)
      #|      (then
      #|        (block (result f32)
      #|          (local.get 0)
      #|          (call $sink)
      #|          (f32.const 0)))
      #|      (else
      #|        (f32.const 0)))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists one-block else-arm value suffix" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32) (result f32)
      #|    (if (result f32)
      #|      (local.get 0)
      #|      (then
      #|        (f32.const 0))
      #|      (else
      #|        (block (result f32)
      #|          (local.get 0)
      #|          (call $sink)
      #|          (f32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists identical structured suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    local.get 0
      #|    if
      #|      i32.const 1
      #|      drop
      #|      block
      #|        i32.const 7
      #|        drop
      #|      end
      #|    else
      #|      i32.const 2
      #|      drop
      #|      block
      #|        i32.const 7
      #|        drop
      #|      end
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists identical outer-branch tails" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    block $out
      #|      local.get 0
      #|      if
      #|        i32.const 7
      #|        drop
      #|        br $out
      #|      else
      #|        i32.const 7
      #|        drop
      #|        br $out
      #|      end
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists block-exit tail shared with fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    block $out
      #|      local.get 0
      #|      if
      #|        i32.const 7
      #|        drop
      #|        br $out
      #|      end
      #|      i32.const 7
      #|      drop
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists typed block-exit branch payload shared with fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    (block $out (result i32)
      #|      (if (local.get 0)
      #|        (then
      #|          (br $out (i32.const 7))))
      #|      (i32.const 7))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists typed block-exit branch payloads without fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32 i32) (result i32)
      #|    (block $out (result i32)
      #|      (if (local.get 0)
      #|        (then
      #|          (br $out (i32.const 7))))
      #|      (if (local.get 1)
      #|        (then
      #|          (br $out (i32.const 7))))
      #|      (i32.const 9)
      #|      (return))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(9)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists typed block-exit multi-root payload suffix with fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32) (result i32)
      #|    (block $out (result i32)
      #|      (if (local.get 0)
      #|        (then
      #|          (local.get 1)
      #|          (call $sink)
      #|          (br $out (i32.const 7))))
      #|      (local.get 1)
      #|      (call $sink)
      #|      (i32.const 7))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists typed block-exit multi-root payload suffixes without fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32 i32) (result i32)
      #|    (block $out (result i32)
      #|      (if (local.get 0)
      #|        (then
      #|          (local.get 2)
      #|          (call $sink)
      #|          (br $out (i32.const 7))))
      #|      (if (local.get 1)
      #|        (then
      #|          (local.get 2)
      #|          (call $sink)
      #|          (br $out (i32.const 7))))
      #|      (i32.const 9)
      #|      (return))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(9)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists block-exit tail before outer branch fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32 i32 i32)
      #|    (drop
      #|      (block $outer (result i32)
      #|        (block
      #|          (br $outer
      #|            (block $mid (result i32)
      #|              (block $out
      #|                (if (local.get 0)
      #|                  (then
      #|                    (local.get 2)
      #|                    (call $sink)
      #|                    (br $out))
      #|                  (else
      #|                    (if (local.get 1)
      #|                      (then
      #|                        (local.get 2)
      #|                        (call $sink)
      #|                        (br $out)))))
      #|                (br $mid (i32.const 0)))
      #|              (i32.const 1)))))))
      #|  (func $sink (param i32)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares full if arms ending in return" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return))
      #|      (else
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return))))
      #|  (func $sink (param i32)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares full if arms ending in unreachable" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (unreachable))
      #|      (else
      #|        (local.get 1)
      #|        (call $sink)
      #|        (unreachable))))
      #|  (func $sink (param i32)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares if-then and fallthrough return tails" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (local.get 1)
      #|    (call $sink)
      #|    (i32.const 7)
      #|    (drop)
      #|    (return)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares if-then and fallthrough unreachable tails" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (unreachable)))
      #|    (local.get 1)
      #|    (call $sink)
      #|    (unreachable)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-adjacent return tails" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (i32.const 99)
      #|    (drop)
      #|    (local.get 1)
      #|    (call $sink)
      #|    (i32.const 7)
      #|    (drop)
      #|    (return)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root return tail subsets" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (unreachable)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root return subsets excluding a different root return" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func $other (param i32))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (local.get 1)
      #|    (call $other)
      #|    (return)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding folds deeper non-root return subset then shallow fixpoint" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func $other (param i32))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $other)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root structured block return suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block
      #|          (i32.const 7)
      #|          (drop))
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (block
      #|          (i32.const 7)
      #|          (drop))
      #|        (return)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root structured if return suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (if (local.get 0)
      #|          (then
      #|            (i32.const 7)
      #|            (drop))
      #|          (else
      #|            (i32.const 8)
      #|            (drop)))
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (if (local.get 0)
      #|          (then
      #|            (i32.const 7)
      #|            (drop))
      #|          (else
      #|            (i32.const 8)
      #|            (drop)))
      #|        (return)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root structured loop return suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (loop
      #|          (i32.const 7)
      #|          (drop))
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (loop
      #|          (i32.const 7)
      #|          (drop))
      #|        (return)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root self-branch block return suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block $left
      #|          (i32.const 7)
      #|          (drop)
      #|          (br $left))
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (block $right
      #|          (i32.const 7)
      #|          (drop)
      #|          (br $right))
      #|        (return)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root nested self-branch block return suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block $left_outer
      #|          (block $left_inner
      #|            (i32.const 7)
      #|            (drop)
      #|            (br $left_inner))
      #|          (i32.const 8)
      #|          (drop)
      #|          (br $left_outer))
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (block $right_outer
      #|          (block $right_inner
      #|            (i32.const 7)
      #|            (drop)
      #|            (br $right_inner))
      #|          (i32.const 8)
      #|          (drop)
      #|          (br $right_outer))
      #|        (return)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding keeps crossed nested self-branch return suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block $left_outer
      #|          (block $left_inner
      #|            (i32.const 7)
      #|            (drop)
      #|            (br $left_inner))
      #|          (i32.const 8)
      #|          (drop)
      #|          (br $left_outer))
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (block $right_outer
      #|          (block $right_inner
      #|            (i32.const 7)
      #|            (drop)
      #|            (br $right_outer))
      #|          (i32.const 8)
      #|          (drop)
      #|          (br $right_outer))
      #|        (return)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root self-branch block unreachable suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block $left
      #|          (i32.const 7)
      #|          (drop)
      #|          (br $left))
      #|        (unreachable)))
      #|    (if (local.get 0)
      #|      (then
      #|        (block $right
      #|          (i32.const 7)
      #|          (drop)
      #|          (br $right))
      #|        (unreachable)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root return tail subsets with root fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)
      #|        (return)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares block-backed unreachable tails" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block
      #|          (local.get 1)
      #|          (call $sink)
      #|          (unreachable))))
      #|    (i32.const 99)
      #|    (drop)
      #|    (local.get 1)
      #|    (call $sink)
      #|    (unreachable)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root unreachable tail subsets with root fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (unreachable)))
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (unreachable)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares direct return-call tails with typed results" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32) (result i32)))
      #|  (func $target (type $t)
      #|    (local.get 0))
      #|  (func $sink (param i32))
      #|  (func (param i32 i32) (result i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (local.get 1)
      #|        (return_call $target)))
      #|    (i32.const 99)
      #|    (drop)
      #|    (local.get 1)
      #|    (call $sink)
      #|    (local.get 1)
      #|    (return_call $target)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call (Func 0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root direct return-call tail subsets with root fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32)))
      #|  (func $target (type $t))
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (local.get 1)
      #|        (return_call $target)))
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (local.get 1)
      #|        (return_call $target)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call (Func 0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root self-branch block return-call suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32)))
      #|  (func $target (type $t))
      #|  (func (param i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block $left
      #|          (i32.const 7)
      #|          (drop)
      #|          (br $left))
      #|        (local.get 1)
      #|        (return_call $target)))
      #|    (if (local.get 0)
      #|      (then
      #|        (block $right
      #|          (i32.const 7)
      #|          (drop)
      #|          (br $right))
      #|        (local.get 1)
      #|        (return_call $target)))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call (Func 0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares return-call-indirect tails" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32)))
      #|  (table 1 funcref)
      #|  (func $target (type $t))
      #|  (func $sink (param i32))
      #|  (elem (i32.const 0) $target)
      #|  (func (param i32 i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (local.get 1)
      #|        (local.get 2)
      #|        (return_call_indirect (type $t))))
      #|    (i32.const 99)
      #|    (drop)
      #|    (local.get 1)
      #|    (call $sink)
      #|    (local.get 1)
      #|    (local.get 2)
      #|    (return_call_indirect (type $t))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call_indirect"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root return-call-indirect tail subsets with root fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32)))
      #|  (table 1 funcref)
      #|  (func $target (type $t))
      #|  (func $sink (param i32))
      #|  (elem (i32.const 0) $target)
      #|  (func (param i32 i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (local.get 1)
      #|        (local.get 2)
      #|        (return_call_indirect (type $t))))
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (local.get 1)
      #|        (local.get 2)
      #|        (return_call_indirect (type $t))))
      #|    (i32.const 99)
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call_indirect"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares return-call-ref tails" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let sink_type_idx = @lib.TypeIdx::new(2U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let sink_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type, caller_type, sink_type]))
    .with_func_sec(
      @lib.FuncSec::new([callee_type_idx, sink_type_idx, caller_type_idx]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_null(@lib.HeapType::new(callee_type_idx)),
                @lib.Instruction::return_call_ref(callee_type_idx),
              ],
              None,
            ),
            @lib.Instruction::i32_const(@lib.I32::new(99)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::ref_null(@lib.HeapType::new(callee_type_idx)),
            @lib.Instruction::return_call_ref(callee_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call_ref"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root return-call-ref tail subsets with root fallthrough" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let sink_type_idx = @lib.TypeIdx::new(2U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let sink_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let then_tail = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::ref_null(@lib.HeapType::new(callee_type_idx)),
    @lib.Instruction::return_call_ref(callee_type_idx),
  ]
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type, caller_type, sink_type]))
    .with_func_sec(
      @lib.FuncSec::new([callee_type_idx, sink_type_idx, caller_type_idx]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(@lib.BlockType::void_(), then_tail, None),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(@lib.BlockType::void_(), then_tail, None),
            @lib.Instruction::i32_const(@lib.I32::new(99)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call_ref"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding reaches a root-anchored terminating-tail fixpoint" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $a (param i32))
      #|  (func $b (param i32))
      #|  (func $c (param i32))
      #|  (func (param i32 i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 2)
      #|        (call $a)
      #|        (local.get 2)
      #|        (call $b)
      #|        (local.get 2)
      #|        (call $c)
      #|        (return)))
      #|    (if (local.get 1)
      #|      (then
      #|        (local.get 2)
      #|        (call $b)
      #|        (local.get 2)
      #|        (call $c)
      #|        (return)))
      #|    (local.get 2)
      #|    (call $a)
      #|    (local.get 2)
      #|    (call $b)
      #|    (local.get 2)
      #|    (call $c)
      #|    (return)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 2)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding late branch-cleanup neighborhood keeps shared return tail valid" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func $sink (param i32))
        #|  (func (param i32 i32)
        #|    (if (local.get 0)
        #|      (then
        #|        (local.get 1)
        #|        (call $sink)
        #|        (i32.const 7)
        #|        (drop)
        #|        (return)))
        #|    (i32.const 99)
        #|    (drop)
        #|    (local.get 1)
        #|    (call $sink)
        #|    (i32.const 7)
        #|    (drop)
        #|    (return)))
        #|,
      ),
      [
        "code-folding", "merge-blocks", "remove-unused-brs", "remove-unused-names",
        "merge-blocks",
      ],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected late code-folding neighborhood success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  assert_true(
    code_folding_test_count_substring(pretty, "return") <= 1,
    msg=pretty,
  )
}

///|
test "code-folding late branch-cleanup neighborhood keeps non-root return subset valid" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func $sink (param i32))
        #|  (func (param i32 i32)
        #|    (if (local.get 0)
        #|      (then
        #|        (local.get 1)
        #|        (call $sink)
        #|        (i32.const 7)
        #|        (drop)
        #|        (return)))
        #|    (if (local.get 0)
        #|      (then
        #|        (local.get 1)
        #|        (call $sink)
        #|        (i32.const 7)
        #|        (drop)
        #|        (return)))
        #|    (i32.const 99)
        #|    (drop)))
        #|,
      ),
      [
        "code-folding", "merge-blocks", "remove-unused-brs", "remove-unused-names",
        "merge-blocks",
      ],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected non-root late code-folding neighborhood success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
  assert_true(
    code_folding_test_count_substring(pretty, "return") <= 1,
    msg=pretty,
  )
}

///|
test "code-folding keeps br-on-null-poisoned block-exit suffixes" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::anyref()], [])),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(7)),
                @lib.Instruction::drop(),
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::i32_const(@lib.I32::new(7)),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_on_null"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding keeps br-table-poisoned block-exit suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32 i32)
      #|    (block $out
      #|      (if (local.get 0)
      #|        (then
      #|          (local.get 1)
      #|          (br_table $out)))
      #|      (block
      #|        (i32.const 7)
      #|        (drop)
      #|        (br $out))
      #|      (i32.const 7)
      #|      (drop))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_table"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding keeps outside-target switch-like return tails" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32 i32)
      #|    (block $label$A
      #|      (if
      #|        (local.get 0)
      #|        (then
      #|          (block
      #|            (block
      #|              (block $label$B
      #|                (if
      #|                  (local.get 0)
      #|                  (then
      #|                    (br_table $label$A $label$B
      #|                      (local.get 1)))))
      #|              (return))))
      #|        (else
      #|          (block
      #|            (block $label$C
      #|              (if
      #|                (local.get 0)
      #|                (then
      #|                  (br_table $label$A $label$C
      #|                    (local.get 1)))))
      #|            (return))))))
      #|)
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "br_table"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding keeps careful switch target scopes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (block $label$1
      #|      (block $label$3
      #|        (block $label$5
      #|          (block $label$7
      #|            (br_table $label$3 $label$7
      #|              (i32.const 0)))
      #|          (br $label$1))
      #|        (block $label$8
      #|          (br_table $label$3 $label$8
      #|            (i32.const 0)))
      #|        (br $label$1))
      #|      (unreachable)))
      #|)
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "br_table"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "br (Label"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding folds non-terminal try-table if-arm body suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (try_table (catch_all 0)
      #|      (if (local.get 0)
      #|        (then
      #|          (local.get 1)
      #|          (call $sink)
      #|          (i32.const 7)
      #|          (drop))
      #|        (else
      #|          (local.get 1)
      #|          (call $sink)
      #|          (i32.const 7)
      #|          (drop))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding keeps outer-catch try-table terminal tails as EH bailout" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (block $exit
      #|      (try_table (catch_all $exit)
      #|        (if (local.get 0)
      #|          (then
      #|            (local.get 1)
      #|            (call $sink)
      #|            (return)))
      #|        (local.get 1)
      #|        (call $sink)
      #|        (return)))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding keeps try-table terminal tails as EH bailout" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (try_table (catch_all 0)
      #|      (if (local.get 0)
      #|        (then
      #|          (local.get 1)
      #|          (call $sink)
      #|          (return)))
      #|      (local.get 1)
      #|      (call $sink)
      #|      (return))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding keeps try-table block-exit suffixes as EH bailout" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func (param i32)
      #|    (block $exit
      #|      (try_table (catch_all $exit)
      #|        (if (local.get 0)
      #|          (then
      #|            (i32.const 7)
      #|            (drop)
      #|            (br $exit))))
      #|      (i32.const 7)
      #|      (drop))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding keeps live-label structured if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block $then_tail
      #|          (i32.const 7)
      #|          (drop)
      #|          (br $then_tail)))
      #|      (else
      #|        (block $else_tail
      #|          (i32.const 7)
      #|          (drop)
      #|          (br $else_tail))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding shares nested value branch helper-wrapper tails" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32 i32 i32 i32) (result i32)
      #|    (drop
      #|      (block $outer (result i32)
      #|        (block $b1
      #|          (br $outer
      #|            (block $b2 (result i32)
      #|              (block $b0
      #|                local.get 0
      #|                if
      #|                  local.get 4
      #|                  call $sink
      #|                  br $b0
      #|                else
      #|                  local.get 1
      #|                  if
      #|                    local.get 4
      #|                    call $sink
      #|                    br $b0
      #|                  else
      #|                    local.get 2
      #|                    if
      #|                      local.get 4
      #|                      call $sink
      #|                      br $b1
      #|                    else
      #|                      local.get 3
      #|                      if
      #|                        local.get 4
      #|                        call $sink
      #|                        br $b1
      #|                      end
      #|                    end
      #|                  end
      #|                end
      #|                i32.const 0
      #|                br $b2
      #|              )
      #|              local.get 4
      #|              call $sink
      #|              i32.const 3)))
      #|        local.get 4
      #|        call $sink
      #|        i32.const 4))
      #|    i32.const 9)
      #|)
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    4,
    msg=pretty,
  )
}

///|
test "code-folding removes trailing unreachable after exiting root without crashing" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    local.get 0
      #|    if
      #|      return
      #|    else
      #|      return
      #|    end
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("unreachable"), msg=pretty)
}

///|
test "code-folding removes nested loop trailing unreachable after exiting control" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    local.get 0
      #|    if
      #|      loop $again
      #|        local.get 0
      #|        if
      #|          br $again
      #|        else
      #|          i32.const 1
      #|          return
      #|        end
      #|        unreachable
      #|      end
      #|      unreachable
      #|    else
      #|      i32.const 0
      #|      return
      #|    end
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding keeps root trailing unreachable for exiting result functions" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    local.get 0
      #|    if
      #|      i32.const 1
      #|      return
      #|    else
      #|      i32.const 2
      #|      return
      #|    end
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "code-folding keeps exiting blocks with live branch labels" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    block $out
      #|      local.get 0
      #|      if
      #|        i32.const 1
      #|        return
      #|      else
      #|        br $out
      #|      end
      #|      unreachable
      #|    end
      #|    i32.const 2))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
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
