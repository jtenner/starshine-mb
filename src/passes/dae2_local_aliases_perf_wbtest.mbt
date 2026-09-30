///|
fn local_alias_perf_run(
  it : @bench.T,
  width : Int,
  shape : Int,
  reference : Bool,
) -> Unit raise {
  let locals = Array::make(if shape == 3 { width } else { width * 2 }, "i32").join(
    " ",
  )
  let body = Array::makei(width, fn(i) {
    if shape == 3 {
      return "local.get 0 local.set \{i + 1} local.get \{i + 1} call $consume local.get \{i + 1} call $consume"
    }
    let source = i * 2 + 1
    let target = source + 1
    let copy = if shape == 2 { "i32.const 7" } else { "local.get \{source}" }
    let extra_read = if shape == 2 {
      "local.get \{source} call $consume"
    } else {
      ""
    }
    let group = "call $produce local.set \{source} local.get \{source} call $consume \{extra_read} \{copy} local.set \{target} local.get \{target} call $consume local.get \{target} call $consume"
    if shape == 1 {
      "block \{group} end"
    } else {
      group
    }
  }).join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (local \{locals}) \{body}))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let func = input.code_sec.unwrap().0[0]
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let params = [@lib.ValType::i32()]
  let actual = pass_lower_compact_captures_with_map(
      func,
      original,
      params,
      propagate_parameter_aliases=true,
    ).0
  let old = compaction_admission_reference_compact(
      func,
      original,
      params,
      propagate_parameter_aliases=true,
    ).0
  let result = input.with_code_sec(@lib.CodeSec::new([actual]))
  @validate.validate_module(result).unwrap()
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([old]))).unwrap()
  let @lib.Func(actual_locals, _) = actual
  assert_eq(
    actual_locals.length(),
    if shape == 3 {
      0
    } else if shape == 2 {
      width * 2
    } else {
      width
    },
  )
  if shape >= 2 {
    assert_eq(
      @binary.encode_module(result).unwrap(),
      @binary.encode_module(input.with_code_sec(@lib.CodeSec::new([old]))).unwrap(),
    )
  }
  it.bench(fn() {
    it.keep(
      if reference {
        compaction_admission_reference_compact(
          func,
          original,
          params,
          propagate_parameter_aliases=true,
        )
      } else {
        pass_lower_compact_captures_with_map(
          func,
          original,
          params,
          propagate_parameter_aliases=true,
        )
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench local aliases 8 flat local original" (it : @bench.T) {
  local_alias_perf_run(it, 8, 0, true)
}

///|
test "bench local aliases 8 flat local forwarded" (it : @bench.T) {
  local_alias_perf_run(it, 8, 0, false)
}

///|
test "bench local aliases 8 nested local original" (it : @bench.T) {
  local_alias_perf_run(it, 8, 1, true)
}

///|
test "bench local aliases 8 nested local forwarded" (it : @bench.T) {
  local_alias_perf_run(it, 8, 1, false)
}

///|
test "bench local aliases 8 no alias original" (it : @bench.T) {
  local_alias_perf_run(it, 8, 2, true)
}

///|
test "bench local aliases 8 no alias forwarded" (it : @bench.T) {
  local_alias_perf_run(it, 8, 2, false)
}

///|
test "bench local aliases 8 parameter alias original" (it : @bench.T) {
  local_alias_perf_run(it, 8, 3, true)
}

///|
test "bench local aliases 8 parameter alias forwarded" (it : @bench.T) {
  local_alias_perf_run(it, 8, 3, false)
}

///|
test "bench local aliases 128 flat local original" (it : @bench.T) {
  local_alias_perf_run(it, 128, 0, true)
}

///|
test "bench local aliases 128 flat local forwarded" (it : @bench.T) {
  local_alias_perf_run(it, 128, 0, false)
}

///|
test "bench local aliases 128 nested local original" (it : @bench.T) {
  local_alias_perf_run(it, 128, 1, true)
}

///|
test "bench local aliases 128 nested local forwarded" (it : @bench.T) {
  local_alias_perf_run(it, 128, 1, false)
}

///|
test "bench local aliases 128 no alias original" (it : @bench.T) {
  local_alias_perf_run(it, 128, 2, true)
}

///|
test "bench local aliases 128 no alias forwarded" (it : @bench.T) {
  local_alias_perf_run(it, 128, 2, false)
}

///|
test "bench local aliases 128 parameter alias original" (it : @bench.T) {
  local_alias_perf_run(it, 128, 3, true)
}

///|
test "bench local aliases 128 parameter alias forwarded" (it : @bench.T) {
  local_alias_perf_run(it, 128, 3, false)
}
