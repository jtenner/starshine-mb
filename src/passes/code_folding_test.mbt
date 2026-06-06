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
fn code_folding_test_repeated_i32_drops(count : Int) -> String {
  let mut text = ""
  for i = 0; i < count; i = i + 1 {
    text = text + " (i32.const " + i.to_string() + ") (drop)"
  }
  text
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
test "code-folding folds full multi-root non-block value arms" {
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
      #|        (nop)
      #|        (f32.const 0)))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "drop"),
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
test "code-folding folds embedded select full multi-root value if arms" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (select
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (nop)
      #|          (f32.const 0))
      #|        (else
      #|          (nop)
      #|          (f32.const 0)))
      #|      (f32.const 1)
      #|      (local.get 0))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded select partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (select
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0)))
      #|      (f32.const 1)
      #|      (local.get 0))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded drop partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (drop
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0))))))
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
test "code-folding skips oversized functions" {
  let prefix = code_folding_test_repeated_i32_drops(520)
  let optimized = code_folding_test_run(
    "(module (func (param i32) " +
    prefix +
    " (local.get 0) (if (then (i32.const 1) (drop) (i32.const 9999) (drop)) (else (i32.const 2) (drop) (i32.const 9999) (drop)))))",
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(9999)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding skips oversized if-arm suffix scan" {
  let prefix = code_folding_test_repeated_i32_drops(130)
  let optimized = code_folding_test_run(
    "(module (func (param i32) (local.get 0) (if (then " +
    prefix +
    " (i32.const 9999) (drop)) (else " +
    prefix +
    " (i32.const 9999) (drop)))))",
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(9999)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding skips oversized terminating-tail search" {
  let prefix = code_folding_test_repeated_i32_drops(150)
  let optimized = code_folding_test_run(
    "(module (func $sink) (func (param i32) (result i32) " +
    prefix +
    " (if (local.get 0) (then (call $sink) (i32.const 7) (return))) (call $sink) (i32.const 7) (return)))",
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("br (Label"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding skips oversized embedded call value-if scan" {
  let prefix = code_folding_test_repeated_i32_drops(260)
  let optimized = code_folding_test_run(
    "(module (func $sink (param i32)) (func (param i32) (call $sink (if (result i32) (local.get 0) (then " +
    prefix +
    " (i32.const 9999)) (else " +
    prefix +
    " (i32.const 9999))))))",
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(9999)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded call partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $use (param f32))
      #|  (func (param i32)
      #|    (call $use
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded binary partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (f32.add
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0)))
      #|      (f32.const 1))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("f32.add"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded local.set partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (local f32)
      #|    (local.set 1
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0))))
      #|    (drop (local.get 1))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded local.tee partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32) (local f32)
      #|    (local.tee 1
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0))))))
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
test "code-folding folds embedded global.set partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (global $g (mut f32) (f32.const 0))
      #|  (func (param i32)
      #|    (global.set $g
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded store partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32)
      #|    (f32.store
      #|      (i32.const 0)
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("f32.store"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded return partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (return
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded br payload partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (block $out (result f32)
      #|      (br $out
      #|        (if (result f32)
      #|          (local.get 0)
      #|          (then
      #|            (i32.const 1)
      #|            (drop)
      #|            (f32.const 0))
      #|          (else
      #|            (i32.const 2)
      #|            (drop)
      #|            (f32.const 0))))
      #|      (f32.const 1))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded br_if payload partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (block $out (result f32)
      #|      (drop
      #|        (br_if $out
      #|          (if (result f32)
      #|            (local.get 0)
      #|            (then
      #|              (i32.const 1)
      #|              (drop)
      #|              (f32.const 0))
      #|            (else
      #|              (i32.const 2)
      #|              (drop)
      #|              (f32.const 0)))
      #|          (i32.const 1)))
      #|      (f32.const 1))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const F32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded br_if condition partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (block $out
      #|      (br_if $out
      #|        (if (result i32)
      #|          (local.get 0)
      #|          (then
      #|            (i32.const 1)
      #|            (drop)
      #|            (i32.const 0))
      #|          (else
      #|            (i32.const 2)
      #|            (drop)
      #|            (i32.const 0))))))
      #|)
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded unary partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (f32.neg
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("f32.neg"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded convert partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f64)
      #|    (f64.promote_f32
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0))))))
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
test "code-folding folds embedded load partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32) (result i32)
      #|    (i32.load
      #|      (if (result i32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (i32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (i32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded compare partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    (i32.eq
      #|      (if (result i32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (i32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (i32.const 0)))
      #|      (i32.const 0))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.eq"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded ref.is_null partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    (ref.is_null
      #|      (if (result funcref)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (ref.null func))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (ref.null func))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "(ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded ref.as_non_null partial value if suffixes" {
  let ref_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let ref_heap = @lib.HeapType::new(ref_type_idx)
  let nullable_func_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, ref_heap),
  )
  let nonnull_func_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, ref_heap),
  )
  let ref_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [nonnull_func_ref]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([ref_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(nullable_func_ref),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(ref_heap),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(ref_heap),
              ]),
            ),
            @lib.Instruction::ref_as_non_null(),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "(ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded ref.eq partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result i32)
      #|    (ref.eq
      #|      (if (result eqref)
      #|        (local.get 0)
      #|        (then (i32.const 1) (drop) (ref.null eq))
      #|        (else (i32.const 2) (drop) (ref.null eq)))
      #|      (ref.null eq))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "(ref.null"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded any.convert_extern partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result anyref)
      #|    (any.convert_extern
      #|      (if (result externref)
      #|        (local.get 0)
      #|        (then (i32.const 1) (drop) (ref.null extern))
      #|        (else (i32.const 2) (drop) (ref.null extern))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("any.convert_extern"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "(ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded extern.convert_any partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result externref)
      #|    (extern.convert_any
      #|      (if (result anyref)
      #|        (local.get 0)
      #|        (then (i32.const 1) (drop) (ref.null any))
      #|        (else (i32.const 2) (drop) (ref.null any))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("extern.convert_any"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "(ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded ref.i31 partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result (ref i31))
      #|    (ref.i31
      #|      (if (result i32)
      #|        (local.get 0)
      #|        (then (i32.const 1) (drop) (i32.const 7))
      #|        (else (i32.const 2) (drop) (i32.const 7))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("ref.i31"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded ref.test partial value if suffixes" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let func_heap = @lib.HeapType::abs(@lib.AbsHeapType::func())
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::funcref()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(func_heap),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(func_heap),
              ]),
            ),
            @lib.Instruction::ref_test(true, func_heap),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("ref.test"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "(ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded ref.cast partial value if suffixes" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::funcref()]),
    ),
  )
  let func_heap = @lib.HeapType::abs(@lib.AbsHeapType::func())
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::funcref()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(func_heap),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(func_heap),
              ]),
            ),
            @lib.Instruction::ref_cast(true, func_heap),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("ref.cast"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "(ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded table.copy dest partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (table 4 funcref)
      #|  (func (param i32)
      #|    (table.copy 0 0
      #|      (if (result i32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (i32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (i32.const 0)))
      #|      (i32.const 1)
      #|      (i32.const 1))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded table.init dest partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (table 4 funcref)
      #|  (elem func)
      #|  (func (param i32)
      #|    (table.init 0 0
      #|      (if (result i32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (i32.const 42))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (i32.const 42)))
      #|      (i32.const 0)
      #|      (i32.const 1))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.init"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded table.get partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (func (param i32) (result funcref)
      #|    (table.get 0
      #|      (if (result i32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (i32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (i32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.get"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded table.set index partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (func (param i32)
      #|    (table.set 0
      #|      (if (result i32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (i32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (i32.const 0)))
      #|      (ref.null func))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded call_indirect partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (result i32)))
      #|  (table 1 funcref)
      #|  (func (type $t) (i32.const 9))
      #|  (elem (i32.const 0) 0)
      #|  (func (param i32) (result i32)
      #|    (call_indirect (type $t)
      #|      (if (result i32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (i32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (i32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded call_ref partial value if suffixes" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let callee_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(callee_type_idx)),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type, caller_type]))
    .with_func_sec(@lib.FuncSec::new([callee_type_idx, caller_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(9))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(callee_ref),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::call_ref(callee_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call_ref"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "ref.func"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded return_call_ref partial value if suffixes" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let callee_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(callee_type_idx)),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type, caller_type]))
    .with_func_sec(@lib.FuncSec::new([callee_type_idx, caller_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(9))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(callee_ref),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::return_call_ref(callee_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "ref.func"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded return_call partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param f32) (result i32)))
      #|  (func $use (type $t) (param f32) (result i32)
      #|    (i32.const 7))
      #|  (func (param i32) (result i32)
      #|    (return_call $use
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0))))))
      #|)
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded return_call_indirect partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param f32) (result i32)))
      #|  (table 1 funcref)
      #|  (func $use (type $t) (param f32) (result i32)
      #|    (i32.const 7))
      #|  (elem (i32.const 0) $use)
      #|  (func (param i32) (result i32)
      #|    (return_call_indirect (type $t)
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (f32.const 0)))
      #|      (i32.const 0))))
      #|)
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded struct.new field partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $s (struct (field (mut i32))))
      #|  (func (param i32) (result (ref $s))
      #|    (struct.new $s
      #|      (if (result i32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (i32.const 42))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (i32.const 42))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.new value partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(array_type_idx)),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [array_ref]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
            @lib.Instruction::array_new(array_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.new"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.new_default length partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(array_type_idx)),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [array_ref]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(2)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(3)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(2)),
              ]),
            ),
            @lib.Instruction::array_new_default(array_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.new_default"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(2)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.new_elem offset partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let dummy_type_idx = @lib.TypeIdx::new(1U)
  let func_type_idx = @lib.TypeIdx::new(2U)
  let elem_idx = @lib.ElemIdx::new(0U)
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(array_type_idx)),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::funcref()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let dummy_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [array_ref]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, dummy_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([dummy_type_idx, func_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
            @lib.Instruction::array_new_elem(array_type_idx, elem_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("array.new_elem"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.new_data offset partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let data_idx = @lib.DataIdx::new(0U)
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(array_type_idx)),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [array_ref]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_data_sec(
      @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), b"abc")]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32::new(2)),
            @lib.Instruction::array_new_data(array_type_idx, data_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.new_data"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded struct.set value partial value if suffixes" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(struct_type_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
              ]),
            ),
            @lib.Instruction::struct_set(struct_type_idx, @lib.U32::new(0U)),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.get index partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(7)),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
            @lib.Instruction::array_new(array_type_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
              ]),
            ),
            @lib.Instruction::array_get(array_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.get"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.get_s index partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(7)),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
            @lib.Instruction::array_new(array_type_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
              ]),
            ),
            @lib.Instruction::array_get_s(array_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.get_s"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.get_u index partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(7)),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
            @lib.Instruction::array_new(array_type_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
              ]),
            ),
            @lib.Instruction::array_get_u(array_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.get_u"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.set value partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(7)),
            @lib.Instruction::i32_const(@lib.I32::new(2)),
            @lib.Instruction::array_new(array_type_idx),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
              ]),
            ),
            @lib.Instruction::array_set(array_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.set"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.fill value partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(7)),
            @lib.Instruction::i32_const(@lib.I32::new(4)),
            @lib.Instruction::array_new(array_type_idx),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
            @lib.Instruction::array_fill(array_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.fill"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.copy length partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(7)),
            @lib.Instruction::i32_const(@lib.I32::new(4)),
            @lib.Instruction::array_new(array_type_idx),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::i32_const(@lib.I32::new(8)),
            @lib.Instruction::i32_const(@lib.I32::new(4)),
            @lib.Instruction::array_new(array_type_idx),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(11)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(3)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(12)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(3)),
              ]),
            ),
            @lib.Instruction::array_copy(array_type_idx, array_type_idx),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.copy"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(3)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.init_data length partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let data_idx = @lib.DataIdx::new(0U)
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(array_type_idx)),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [array_ref]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
    .with_data_sec(
      @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), b"abc")]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([@lib.LocalRun::new(1U, array_ref)]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(3)),
            @lib.Instruction::array_new_default(array_type_idx),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(2)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(3)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(2)),
              ]),
            ),
            @lib.Instruction::array_init_data(array_type_idx, data_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.init_data"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(2)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.init_elem length partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let dummy_type_idx = @lib.TypeIdx::new(1U)
  let func_type_idx = @lib.TypeIdx::new(2U)
  let elem_idx = @lib.ElemIdx::new(0U)
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(array_type_idx)),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::funcref()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let dummy_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [array_ref]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, dummy_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([dummy_type_idx, func_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::new([@lib.LocalRun::new(1U, array_ref)]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(2)),
            @lib.Instruction::array_new_default(array_type_idx),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(4)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(3)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(4)),
              ]),
            ),
            @lib.Instruction::array_init_elem(array_type_idx, elem_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("array.init_elem"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(4)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded struct.get operand partial value if suffixes" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let struct_ref = @lib.RefType::new(true, @lib.HeapType::new(struct_type_idx))
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::ref_null_type(struct_ref)),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null_type(struct_ref),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null_type(struct_ref),
              ]),
            ),
            @lib.Instruction::struct_get(struct_type_idx, @lib.U32::new(0U)),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded struct.get_s operand partial value if suffixes" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let struct_ref = @lib.RefType::new(true, @lib.HeapType::new(struct_type_idx))
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::ref_null_type(struct_ref)),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null_type(struct_ref),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null_type(struct_ref),
              ]),
            ),
            @lib.Instruction::struct_get_s(struct_type_idx, @lib.U32::new(0U)),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.get_s"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded struct.get_u operand partial value if suffixes" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let struct_ref = @lib.RefType::new(true, @lib.HeapType::new(struct_type_idx))
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i16()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::ref_null_type(struct_ref)),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null_type(struct_ref),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null_type(struct_ref),
              ]),
            ),
            @lib.Instruction::struct_get_u(struct_type_idx, @lib.U32::new(0U)),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.get_u"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.new_fixed element partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(array_type_idx)),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [array_ref]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
            @lib.Instruction::array_new_fixed(array_type_idx, @lib.U32::new(2U)),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.new_fixed"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded array.len operand partial value if suffixes" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_ref = @lib.RefType::new(true, @lib.HeapType::new(array_type_idx))
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::ref_null_type(array_ref)),
              [
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null_type(array_ref),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32::new(2)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null_type(array_ref),
              ]),
            ),
            @lib.Instruction::array_len(),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("array.len"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded memory.grow partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32) (result i32)
      #|    (memory.grow
      #|      (if (result i32)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (i32.const 0))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (i32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(0)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded table.grow partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (func (param i32) (result i32)
      #|    (table.grow 0
      #|      (if (result funcref)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (ref.null func))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (ref.null func)))
      #|      (i32.const 1))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "(ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded table.fill value partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (table 4 funcref)
      #|  (func (param i32)
      #|    (table.fill 0
      #|      (i32.const 0)
      #|      (if (result funcref)
      #|        (local.get 0)
      #|        (then
      #|          (i32.const 1)
      #|          (drop)
      #|          (ref.null func))
      #|        (else
      #|          (i32.const 2)
      #|          (drop)
      #|          (ref.null func)))
      #|      (i32.const 1))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.fill"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "(ref.null"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded memory.fill dest partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32)
      #|    (if (result i32)
      #|      (local.get 0)
      #|      (then
      #|        (i32.const 1)
      #|        (drop)
      #|        (i32.const 42))
      #|      (else
      #|        (i32.const 2)
      #|        (drop)
      #|        (i32.const 42)))
      #|    (i32.const 7)
      #|    (i32.const 1)
      #|    memory.fill))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded memory.copy dest partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (func (param i32)
      #|    (if (result i32)
      #|      (local.get 0)
      #|      (then
      #|        (i32.const 1)
      #|        (drop)
      #|        (i32.const 42))
      #|      (else
      #|        (i32.const 2)
      #|        (drop)
      #|        (i32.const 42)))
      #|    (i32.const 4)
      #|    (i32.const 1)
      #|    memory.copy))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded memory.init dest partial value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (data "abc")
      #|  (func (param i32)
      #|    (if (result i32)
      #|      (local.get 0)
      #|      (then
      #|        (i32.const 1)
      #|        (drop)
      #|        (i32.const 42))
      #|      (else
      #|        (i32.const 2)
      #|        (drop)
      #|        (i32.const 42)))
      #|    (i32.const 0)
      #|    (i32.const 1)
      #|    memory.init 0))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.init"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded call full multi-root value if arms" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $use (param f32))
      #|  (func (param i32)
      #|    (call $use
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (nop)
      #|          (f32.const 0))
      #|        (else
      #|          (nop)
      #|          (f32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds embedded binary full multi-root value if arms" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (f32.add
      #|      (if (result f32)
      #|        (local.get 0)
      #|        (then
      #|          (nop)
      #|          (f32.const 0))
      #|        (else
      #|          (nop)
      #|          (f32.const 0)))
      #|      (f32.const 1))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("f32.add"), msg=pretty)
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
test "code-folding hoists one-block multi-root value suffix" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32) (result f32)
      #|    (if (result f32)
      #|      (local.get 0)
      #|      (then
      #|        (block (result f32)
      #|          (i32.const 1)
      #|          (drop)
      #|          (local.get 1)
      #|          (call $sink)
      #|          (f32.const 0)))
      #|      (else
      #|        (local.get 1)
      #|        (call $sink)
      #|        (f32.const 0)))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(1)"),
    1,
    msg=pretty,
  )
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
test "code-folding hoists one-block else-arm multi-root value suffix" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32) (result f32)
      #|    (if (result f32)
      #|      (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $sink)
      #|        (f32.const 0))
      #|      (else
      #|        (block (result f32)
      #|          (i32.const 2)
      #|          (drop)
      #|          (local.get 1)
      #|          (call $sink)
      #|          (f32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(2)"),
    1,
    msg=pretty,
  )
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
test "code-folding hoists one-block value suffixes with both arm prefixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (if (result f32)
      #|      (local.get 0)
      #|      (then
      #|        (block (result f32)
      #|          (i32.const 1)
      #|          (drop)
      #|          (f32.const 0)))
      #|      (else
      #|        (i32.const 2)
      #|        (drop)
      #|        (f32.const 0)))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(2)"),
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
test "code-folding folds tiny full one-block void arms" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block
      #|          (i32.const 7)
      #|          (drop)))
      #|      (else
      #|        (i32.const 7)
      #|        (drop)))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding folds full one-block void arms" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block
      #|          (local.get 0)
      #|          (call $sink)
      #|          (i32.const 7)
      #|          (drop)))
      #|      (else
      #|        (local.get 0)
      #|        (call $sink)
      #|        (i32.const 7)
      #|        (drop)))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "drop"),
    2,
    msg=pretty,
  )
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
test "code-folding folds full one-block value arms" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32) (result f32)
      #|    (if (result f32)
      #|      (local.get 0)
      #|      (then
      #|        (block (result f32)
      #|          (f32.const 0)))
      #|      (else
      #|        (f32.const 0)))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "drop"),
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
test "code-folding hoists two-block value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32) (result f32)
      #|    (if (result f32)
      #|      (local.get 0)
      #|      (then
      #|        (block (result f32)
      #|          (local.get 1)
      #|          (call $sink)
      #|          (f32.const 0)))
      #|      (else
      #|        (block (result f32)
      #|          (i32.const 42)
      #|          (drop)
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
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
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
test "code-folding hoists two-block multi-root value if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32) (result f32)
      #|    (if (result f32)
      #|      (local.get 0)
      #|      (then
      #|        (block (result f32)
      #|          (i32.const 1)
      #|          (drop)
      #|          (local.get 1)
      #|          (call $sink)
      #|          (f32.const 0)))
      #|      (else
      #|        (block (result f32)
      #|          (i32.const 42)
      #|          (drop)
      #|          (local.get 1)
      #|          (call $sink)
      #|          (f32.const 0))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(1)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(42)"),
    1,
    msg=pretty,
  )
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
test "code-folding hoists multi-value block-exit payload suffix with fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32) (result i32 f32)
      #|    (block $out (result i32 f32)
      #|      (if (local.get 0)
      #|        (then
      #|          (local.get 1)
      #|          (call $sink)
      #|          (br $out (i32.const 7) (f32.const 0))))
      #|      (local.get 1)
      #|      (call $sink)
      #|      (i32.const 7)
      #|      (f32.const 0))))
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
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding hoists multi-value block-exit payload suffixes without fallthrough" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32 i32) (result i32 f32)
      #|    (block $out (result i32 f32)
      #|      (if (local.get 0)
      #|        (then
      #|          (local.get 2)
      #|          (call $sink)
      #|          (br $out (i32.const 7) (f32.const 0))))
      #|      (if (local.get 1)
      #|        (then
      #|          (local.get 2)
      #|          (call $sink)
      #|          (br $out (i32.const 7) (f32.const 0))))
      #|      (unreachable))))
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
    code_folding_test_count_substring(pretty, "f32.const"),
    1,
    msg=pretty,
  )
  assert_true(pretty.contains("unreachable"), msg=pretty)
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
test "code-folding shares arbitrary non-root return subset among distractor tails" {
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
      #|        (call $other)
      #|        (i32.const 8)
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
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
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
test "code-folding shares arbitrary non-root unreachable subset among distractor tails" {
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
      #|        (unreachable)))
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (call $other)
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
    code_folding_test_count_substring(pretty, "unreachable"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding keeps simple return operand tails unshared" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32 i32) (result i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (return)))
      #|    (if (local.get 0)
      #|      (then
      #|        (local.get 1)
      #|        (return)))
      #|    (i32.const 99)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br (Label"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "local.get (Local 1)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(99)"),
    1,
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
test "code-folding shares non-root nested self-branch block unreachable suffixes" {
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
      #|        (unreachable)))
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
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
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
test "code-folding keeps crossed nested self-branch unreachable suffixes" {
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
      #|        (unreachable)))
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
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding keeps return suffixes that branch to an outside target" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (block $exit
      #|      (if (local.get 0)
      #|        (then
      #|          (block
      #|            (i32.const 7)
      #|            (drop)
      #|            (br $exit))
      #|          (return)))
      #|      (if (local.get 0)
      #|        (then
      #|          (block
      #|            (i32.const 7)
      #|            (drop)
      #|            (br $exit))
      #|          (return))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
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
test "code-folding shares safe return subset past outside-target distractor" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (block $exit
      #|      (if (local.get 0)
      #|        (then
      #|          (local.get 1)
      #|          (call $sink)
      #|          (i32.const 7)
      #|          (drop)
      #|          (return)))
      #|      (if (local.get 0)
      #|        (then
      #|          (block
      #|            (local.get 0)
      #|            (br_if $exit)
      #|            (i32.const 8)
      #|            (drop))
      #|          (return)))
      #|      (if (local.get 0)
      #|        (then
      #|          (local.get 1)
      #|          (call $sink)
      #|          (i32.const 7)
      #|          (drop)
      #|          (return))))))
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
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
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
test "code-folding keeps simple result return-call sibling tails unshared" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $target (param i32) (result i32)
      #|    (local.get 0))
      #|  (func (param i32 i32) (result i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (i32.const 7)
      #|        (drop)
      #|        (local.get 1)
      #|        (return_call $target)))
      #|    (if (local.get 0)
      #|      (then
      #|        (i32.const 7)
      #|        (drop)
      #|        (local.get 1)
      #|        (return_call $target)))
      #|    (i32.const 99)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("br (Label"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call (Func 0)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(99)"),
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
test "code-folding shares arbitrary non-root direct return-call subset among distractor tails" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32)))
      #|  (func $target (type $t))
      #|  (func $other_target (type $t))
      #|  (func $sink (param i32))
      #|  (func $other (param i32))
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
      #|        (call $other)
      #|        (local.get 1)
      #|        (return_call $other_target)))
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

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 2)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 3)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call (Func 0)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call (Func 1)"),
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
test "code-folding shares non-root nested self-branch return-call suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $target (param i32))
      #|  (func (param i32 i32)
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
      #|        (local.get 1)
      #|        (return_call $target)))
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
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
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
test "code-folding keeps crossed nested self-branch return-call suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $target (param i32))
      #|  (func (param i32 i32)
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
      #|        (local.get 1)
      #|        (return_call $target)))
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
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call (Func 0)"),
    2,
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
test "code-folding keeps simple result return-call-indirect sibling tails unshared" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32) (result i32)))
      #|  (table 1 funcref)
      #|  (func $target (type $t)
      #|    (local.get 0))
      #|  (elem (i32.const 0) $target)
      #|  (func (param i32 i32 i32) (result i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (i32.const 7)
      #|        (drop)
      #|        (local.get 1)
      #|        (local.get 2)
      #|        (return_call_indirect (type $t))))
      #|    (if (local.get 0)
      #|      (then
      #|        (i32.const 7)
      #|        (drop)
      #|        (local.get 1)
      #|        (local.get 2)
      #|        (return_call_indirect (type $t))))
      #|    (i32.const 99)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("br (Label"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call_indirect"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(99)"),
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
test "code-folding shares arbitrary non-root return-call-indirect subset among distractor tails" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32)))
      #|  (table 2 funcref)
      #|  (func $target (type $t))
      #|  (func $other_target (type $t))
      #|  (func $sink (param i32))
      #|  (func $other (param i32))
      #|  (elem (i32.const 0) $target $other_target)
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
      #|        (call $other)
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

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 2)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 3)"),
    1,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call_indirect"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding prefers deeper return-call-indirect subset over shallow all-tail suffix" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32)))
      #|  (table 1 funcref)
      #|  (func $target (type $t))
      #|  (func $sink (param i32))
      #|  (func $other (param i32))
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
      #|        (call $other)
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

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
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
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call_indirect"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root nested self-branch return-call-indirect suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32)))
      #|  (table 1 funcref)
      #|  (func $target (type $t))
      #|  (elem (i32.const 0) $target)
      #|  (func (param i32 i32 i32)
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
      #|        (local.get 1)
      #|        (local.get 2)
      #|        (return_call_indirect (type $t))))
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
      #|        (local.get 1)
      #|        (local.get 2)
      #|        (return_call_indirect (type $t))))
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
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
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
test "code-folding keeps crossed nested self-branch return-call-indirect suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $t (func (param i32)))
      #|  (table 1 funcref)
      #|  (func $target (type $t))
      #|  (elem (i32.const 0) $target)
      #|  (func (param i32 i32 i32)
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
      #|        (local.get 1)
      #|        (local.get 2)
      #|        (return_call_indirect (type $t))))
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
      #|        (local.get 1)
      #|        (local.get 2)
      #|        (return_call_indirect (type $t))))
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
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call_indirect"),
    2,
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
test "code-folding shares arbitrary non-root return-call-ref subset among distractor tails" {
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
  let matching_tail = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::ref_null(@lib.HeapType::new(callee_type_idx)),
    @lib.Instruction::return_call_ref(callee_type_idx),
  ]
  let distractor_tail = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::ref_null(@lib.HeapType::new(callee_type_idx)),
    @lib.Instruction::return_call_ref(callee_type_idx),
  ]
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type, caller_type, sink_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        callee_type_idx, sink_type_idx, sink_type_idx, caller_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(@lib.BlockType::void_(), matching_tail, None),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              distractor_tail,
              None,
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(@lib.BlockType::void_(), matching_tail, None),
            @lib.Instruction::i32_const(@lib.I32::new(99)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("i32.const I32(99)"), msg=pretty)
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
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call_ref"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding shares non-root nested self-branch return-call-ref suffixes" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let nested_tail = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32::new(7)),
          @lib.Instruction::drop(),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
      @lib.Instruction::i32_const(@lib.I32::new(8)),
      @lib.Instruction::drop(),
      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
    ]),
  )
  let then_tail = [
    nested_tail,
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
    @lib.Instruction::return_call_ref(callee_type_idx),
  ]
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type, caller_type]))
    .with_func_sec(@lib.FuncSec::new([callee_type_idx, caller_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
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

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
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
test "code-folding late branch-cleanup neighborhood keeps arbitrary non-root return subset valid" {
  let optimized = match
    pass_test_run_pipeline(
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
        #|        (call $other)
        #|        (i32.const 8)
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
        "expected arbitrary non-root late code-folding neighborhood success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
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
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(8)"),
    1,
    msg=pretty,
  )
}

///|
test "code-folding late branch-cleanup neighborhood keeps simple return-call bailout valid" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func $target (param i32) (result i32)
        #|    (local.get 0))
        #|  (func (param i32 i32) (result i32)
        #|    (if (local.get 0)
        #|      (then
        #|        (i32.const 7)
        #|        (drop)
        #|        (local.get 1)
        #|        (return_call $target)))
        #|    (if (local.get 0)
        #|      (then
        #|        (i32.const 7)
        #|        (drop)
        #|        (local.get 1)
        #|        (return_call $target)))
        #|    (i32.const 99)))
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
        "expected simple tail-call late code-folding neighborhood success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return_call (Func 0)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    2,
    msg=pretty,
  )
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "i32.const I32(99)"),
    1,
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
test "code-folding keeps br-if-poisoned block-exit payload suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32 i32) (result i32)
      #|    (block $out (result i32)
      #|      (local.get 1)
      #|      (call $sink)
      #|      (drop (br_if $out (i32.const 7) (local.get 0)))
      #|      (local.get 1)
      #|      (call $sink)
      #|      (i32.const 7))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("br_if"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
    2,
    msg=pretty,
  )
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
test "code-folding folds catch try-table if-arm body suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (try_table (catch $e 0)
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
test "code-folding folds catch-ref try-table throwing-body if-arm suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (block $h (result exnref)
      #|      (try_table (catch_ref $e $h)
      #|        (if (local.get 0)
      #|          (then
      #|            (i32.const 1)
      #|            (drop)
      #|            (local.get 1)
      #|            (call $sink)
      #|            (i32.const 7)
      #|            (drop))
      #|          (else
      #|            (i32.const 2)
      #|            (drop)
      #|            (local.get 1)
      #|            (call $sink)
      #|            (i32.const 7)
      #|            (drop)))
      #|        (throw $e))
      #|      (unreachable))
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("catch_ref"), msg=pretty)
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
test "code-folding folds catch-all-ref try-table throwing-body if-arm suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (block $h (result exnref)
      #|      (try_table (catch_all_ref $h)
      #|        (if (local.get 0)
      #|          (then
      #|            (i32.const 1)
      #|            (drop)
      #|            (local.get 1)
      #|            (call $sink)
      #|            (i32.const 7)
      #|            (drop))
      #|          (else
      #|            (i32.const 2)
      #|            (drop)
      #|            (local.get 1)
      #|            (call $sink)
      #|            (i32.const 7)
      #|            (drop)))
      #|        (throw $e))
      #|      (unreachable))
      #|    (drop)))
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
test "code-folding keeps catch-ref try-table terminal tails as EH bailout" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (block $h (result exnref)
      #|      (try_table (catch_ref $e $h)
      #|        (if (local.get 0)
      #|          (then
      #|            (local.get 1)
      #|            (call $sink)
      #|            (return)))
      #|        (local.get 1)
      #|        (call $sink)
      #|        (return))
      #|      (unreachable))
      #|    (drop)))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("catch_ref"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "call (Func 0)"),
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
test "code-folding keeps catch-all-ref try-table terminal tails as EH bailout" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (block $h (result exnref)
      #|      (try_table (catch_all_ref $h)
      #|        (if (local.get 0)
      #|          (then
      #|            (local.get 1)
      #|            (call $sink)
      #|            (return)))
      #|        (local.get 1)
      #|        (call $sink)
      #|        (return))
      #|      (unreachable))
      #|    (drop)))
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
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "return"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding folds nested try-table if-arm body suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (func $sink (param i32))
      #|  (func (param i32 i32)
      #|    (try_table (catch_all 0)
      #|      (try_table (catch_all 0)
      #|        (if (local.get 0)
      #|          (then
      #|            (local.get 1)
      #|            (call $sink)
      #|            (i32.const 7)
      #|            (drop))
      #|          (else
      #|            (local.get 1)
      #|            (call $sink)
      #|            (i32.const 7)
      #|            (drop)))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "try_table"),
    2,
    msg=pretty,
  )
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
test "code-folding keeps crossed live-label structured if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block $then_outer
      #|          (block $then_inner
      #|            (i32.const 7)
      #|            (drop)
      #|            (br $then_inner))
      #|          (i32.const 8)
      #|          (drop)
      #|          (br $then_outer)))
      #|      (else
      #|        (block $else_outer
      #|          (block $else_inner
      #|            (i32.const 7)
      #|            (drop)
      #|            (br $else_outer))
      #|          (i32.const 8)
      #|          (drop)
      #|          (br $else_outer))))))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
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
test "code-folding keeps multi-result exiting block valid before bottom tail" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func
      #|    (block (result i32 i64)
      #|      (block)
      #|      unreachable)
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "code-folding removes size-losing dead multi-result wrapper before root unreachable" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (type $arr (sub (array i32)))
      #|  (type $f (sub (func)))
      #|  (type $block_result (func (result (ref null $arr) i32)))
      #|  (func (type $f)
      #|    (block (type $block_result) (result (ref null $arr) i32)
      #|      (block)
      #|      unreachable)
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "code-folding removes duplicate bottom tail in typed dead block" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (result v128)
      #|    (block (result f64)
      #|      v128.const i32x4 0 0 0 0
      #|      i32x4.trunc_sat_f64x2_s_zero
      #|      unreachable
      #|      unreachable)
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "code-folding removes pure simd debris after bottom in typed dead block" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (result v128)
      #|    (block (result f64)
      #|      v128.const i32x4 0x8477c514 0x9702b3f3 0x11fe0a74 0xee94920a
      #|      i32x4.trunc_sat_f64x2_s_zero
      #|      unreachable
      #|      unreachable)
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("trunc_sat"), msg=pretty)
  assert_false(pretty.contains("v128.const"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "code-folding keeps typed loop bottom tail until enclosing unreachable" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (result i64)
      #|    (loop (result f32)
      #|      unreachable
      #|      unreachable)
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("loop"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    3,
    msg=pretty,
  )
}

///|
test "code-folding removes pure float debris after loop bottom" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (result i64)
      #|    (loop
      #|      f32.const -0.020934515
      #|      f32.ceil
      #|      (block (result f64)
      #|        unreachable
      #|        unreachable)
      #|      unreachable)
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("f32.ceil"), msg=pretty)
  assert_false(pretty.contains("f32.const"), msg=pretty)
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "code-folding handles root branch after typed dead operands" {
  let void_func = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let optimized = code_folding_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([void_func]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(1)),
            @lib.Instruction::f64_const(@lib.F64(0.0)),
            @lib.Instruction::f64_abs(),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            @lib.Instruction::unreachable_(),
          ]),
        ),
      ]),
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
}

///|
test "code-folding accepts typed try-table bottom before root unreachable" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func
      #|    (try_table (result v128)
      #|      unreachable)
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    2,
    msg=pretty,
  )
}

///|
test "code-folding keeps root bottom sentinel before trailing typed debris" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func (result f64)
      #|    v128.const i32x4 0 0 0 0
      #|    unreachable
      #|    unreachable))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("v128.const"), msg=pretty)
  @debug.assert_eq(
    code_folding_test_count_substring(pretty, "unreachable"),
    2,
    msg=pretty,
  )
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

///|
test "code-folding hoists two-block void if suffixes" {
  let optimized = code_folding_test_run(
    (
      #|(module
      #|  (func $sink (param i32))
      #|  (func (param i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (block
      #|          i32.const 1
      #|          drop
      #|          i32.const 9
      #|          call $sink
      #|          i32.const 7
      #|          drop))
      #|      (else
      #|        (block
      #|          i32.const 2
      #|          drop
      #|          i32.const 9
      #|          call $sink
      #|          i32.const 7
      #|          drop)))))
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
    code_folding_test_count_substring(pretty, "i32.const I32(7)"),
    1,
    msg=pretty,
  )
}
