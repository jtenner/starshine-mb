///|
fn atomic_pass_support_count_substring(text : String, needle : String) -> Int {
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
fn atomic_pass_support_assert_strings_in_order(
  text : String,
  needles : Array[String],
) -> Unit raise {
  let mut start = 0
  for needle in needles {
    let mut found : Int? = None
    let limit = text.length() - needle.length()
    let mut i = start
    while i <= limit {
      if text.sub(start=i, end=i + needle.length()).to_owned() == needle {
        found = Some(i)
        break
      }
      i += 1
    }
    match found {
      Some(pos) => start = pos + needle.length()
      None =>
        fail("expected to find `\{needle}` after byte \{start} in:\n\{text}")
    }
  }
}

///|
fn atomic_pass_support_struct_atomic_get_fixture(body : String) -> String {
  atomic_pass_support_struct_atomic_get_fixture_with_prefix("", body)
}

///|
fn atomic_pass_support_struct_atomic_get_fixture_with_prefix(
  prefix : String,
  body : String,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(prefix)
  out.write_string("\n")
  out.write_string("  (type $box (sub (struct (field (mut i32)))))\n")
  out.write_string("  (global $g (ref $box)\n")
  out.write_string("    (struct.new $box\n")
  out.write_string("      (i32.const 7)))\n")
  out.write_string(body)
  out.write_string("\n)")
  out.to_string()
}

///|
fn atomic_pass_support_hot_local_cse_pretty(text : String) -> String {
  let mod_ = pass_test_module_from_wat(text)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    local_cse_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(local_cse_run(ctx, func))
  @ir.hot_verify_all_or_abort(func)
  mod_
  .with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)]))
  .pretty_print_func(@lib.FuncIdx::new(0U))
}

///|
test "local-cse hot candidate path does not merge struct atomic gets" {
  let input = atomic_pass_support_struct_atomic_get_fixture(
    (
      #| (func (export "read-twice") (result i32)
      #|   global.get $g
      #|   struct.atomic.get acq_rel $box 0
      #|   drop
      #|   global.get $g
      #|   struct.atomic.get acq_rel $box 0)
    ),
  )
  let pretty = atomic_pass_support_hot_local_cse_pretty(input)
  @debug.assert_eq(
    atomic_pass_support_count_substring(pretty, "struct.atomic.get"),
    2,
  )
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.get (Local"), msg=pretty)
}

///|
test "local-cse public raw pass keeps repeated struct atomic gets distinct" {
  let input = atomic_pass_support_struct_atomic_get_fixture(
    (
      #| (func (export "read-twice")
      #|   global.get $g
      #|   struct.atomic.get acq_rel $box 0
      #|   drop
      #|   global.get $g
      #|   struct.atomic.get acq_rel $box 0
      #|   drop)
    ),
  )
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    atomic_pass_support_count_substring(pretty, "struct.atomic.get"),
    2,
  )
  assert_false(pretty.contains("local.tee"), msg=pretty)
}

///|
test "precompute preserves dropped struct atomic gets" {
  let input = atomic_pass_support_struct_atomic_get_fixture(
    (
      #| (func (export "dropped-atomic")
      #|   global.get $g
      #|   struct.atomic.get acq_rel $box 0
      #|   drop)
    ),
  )
  let optimized = match pass_test_run_pipeline(input, ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.atomic.get"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "optimize-instructions treats struct atomic gets as load-call barriers" {
  let trace : Array[String] = []
  let input = atomic_pass_support_struct_atomic_get_fixture_with_prefix(
    "  (import \"m\" \"touch\" (func $touch))\n",
    (
      #| (func (export "atomic-before-call")
      #|   global.get $g
      #|   struct.atomic.get acq_rel $box 0
      #|   drop
      #|   call $touch
      #|   i32.const 0
      #|   i32.eqz
      #|   drop)
    ),
  )
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected optimize-instructions success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=load-call-optimize-instructions-noop",
      )
    }),
    msg=trace.to_string(),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("struct.atomic.get"), msg=pretty)
}

///|
test "simplify-locals does not sink loads across struct atomic gets" {
  let input = atomic_pass_support_struct_atomic_get_fixture(
    (
      #| (memory 1)
      #| (func (export "load-before-atomic") (param $ptr i32) (result i32)
      #|   (local $tmp i32)
      #|   local.get $ptr
      #|   i32.load
      #|   local.set $tmp
      #|   global.get $g
      #|   struct.atomic.get acq_rel $box 0
      #|   drop
      #|   local.get $tmp)
    ),
  )
  let optimized = match pass_test_run_pipeline(input, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  atomic_pass_support_assert_strings_in_order(pretty, [
    "i32.load", "struct.atomic.get", "local.get (Local 1)",
  ])
}
