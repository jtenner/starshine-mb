///|
fn reverse_alias_perf_run(
  it : @bench.T,
  width : Int,
  shape : Int,
  reference : Bool,
) -> Unit raise {
  let locals = Array::make(width * 2, "i32").join(" ")
  let body = Array::makei(width, fn(i) {
    let source = if shape == 1 { i * 2 } else { i * 2 + 1 }
    let target = if shape == 1 { i * 2 + 1 } else { i * 2 }
    let copy = if shape == 2 { "i32.const 7" } else { "local.get \{source}" }
    let extra = if shape == 2 {
      "local.get \{source} call $consume"
    } else {
      ""
    }
    "call $produce local.set \{source} local.get \{source} call $consume \{extra} \{copy} local.set \{target} local.get \{target} call $consume local.get \{target} call $consume"
  }).join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (local \{locals}) \{body}))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let func = input.code_sec.unwrap().0[0]
  let seed = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let old = reverse_alias_reference_compact(
      func,
      seed,
      [],
      propagate_parameter_aliases=true,
    ).0
  let out = pass_lower_compact_captures_with_map(
      func,
      seed,
      [],
      propagate_parameter_aliases=true,
    ).0
  let @lib.Func(old_locals, _) = old
  let @lib.Func(locals, _) = out
  assert_eq(old_locals.length(), if shape == 1 { width } else { width * 2 })
  assert_eq(locals.length(), if shape == 2 { width * 2 } else { width })
  let old_module = input.with_code_sec(@lib.CodeSec::new([old]))
  let output = input.with_code_sec(@lib.CodeSec::new([out]))
  @validate.validate_module(old_module).unwrap()
  @validate.validate_module(output).unwrap()
  assert_true(
    @binary.encode_module(output).unwrap().length() <=
    @binary.encode_module(old_module).unwrap().length(),
  )
  if shape != 0 {
    assert_eq(out, old)
  }
  it.bench(fn() {
    it.keep(
      if reference {
        reverse_alias_reference_compact(
          func,
          seed,
          [],
          propagate_parameter_aliases=true,
        )
      } else {
        pass_lower_compact_captures_with_map(
          func,
          seed,
          [],
          propagate_parameter_aliases=true,
        )
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench reverse alias 8 reverse copy original" (it : @bench.T) {
  reverse_alias_perf_run(it, 8, 0, true)
}

///|
test "bench reverse alias 8 reverse copy ranged" (it : @bench.T) {
  reverse_alias_perf_run(it, 8, 0, false)
}

///|
test "bench reverse alias 8 forward copy original" (it : @bench.T) {
  reverse_alias_perf_run(it, 8, 1, true)
}

///|
test "bench reverse alias 8 forward copy ranged" (it : @bench.T) {
  reverse_alias_perf_run(it, 8, 1, false)
}

///|
test "bench reverse alias 8 no alias original" (it : @bench.T) {
  reverse_alias_perf_run(it, 8, 2, true)
}

///|
test "bench reverse alias 8 no alias ranged" (it : @bench.T) {
  reverse_alias_perf_run(it, 8, 2, false)
}

///|
test "bench reverse alias 64 reverse copy original" (it : @bench.T) {
  reverse_alias_perf_run(it, 64, 0, true)
}

///|
test "bench reverse alias 64 reverse copy ranged" (it : @bench.T) {
  reverse_alias_perf_run(it, 64, 0, false)
}

///|
test "bench reverse alias 64 forward copy original" (it : @bench.T) {
  reverse_alias_perf_run(it, 64, 1, true)
}

///|
test "bench reverse alias 64 forward copy ranged" (it : @bench.T) {
  reverse_alias_perf_run(it, 64, 1, false)
}

///|
test "bench reverse alias 64 no alias original" (it : @bench.T) {
  reverse_alias_perf_run(it, 64, 2, true)
}

///|
test "bench reverse alias 64 no alias ranged" (it : @bench.T) {
  reverse_alias_perf_run(it, 64, 2, false)
}
