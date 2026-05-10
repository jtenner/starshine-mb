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
