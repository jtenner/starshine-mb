///|
fn unread_write_bench(
  it : @bench.T,
  count : Int,
  mode : Int,
  reference : Bool,
) -> Unit raise {
  let locals = Array::make(count, "i32").join(" ")
  let statements = Array::makei(count, fn(i) {
    match mode {
      0 =>
        "call $produce local.set \{i} local.get \{i} drop local.get \{i} drop"
      1 => "call $produce local.tee \{i} drop"
      2 => "call $produce local.set \{i}"
      _ =>
        "call $produce local.set \{i} (try (do (nop)) (catch_all (drop (local.get \{i})) (drop (local.get \{i}))))"
    }
  }).join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (func (local \{locals}) \{statements}))",
  )
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let func = input.code_sec.unwrap().0[0]
  let result = pass_lower_compact_captures_with_map(
    func,
    original,
    [],
    propagate_parameter_aliases=true,
  )
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([result.0]))).unwrap()
  if mode == 0 || mode == 3 {
    let expected = unread_write_reference_compact(
      func,
      original,
      [],
      propagate_parameter_aliases=true,
    )
    assert_eq(result, expected)
  }
  it.bench(fn() {
    it.keep(
      if reference {
        unread_write_reference_compact(
          func,
          original,
          [],
          propagate_parameter_aliases=true,
        )
      } else {
        pass_lower_compact_captures_with_map(
          func,
          original,
          [],
          propagate_parameter_aliases=true,
        )
      },
    )
  })
}

///|
test "bench unread writes cold1 V82 predecessor" (it : @bench.T) {
  unread_write_bench(it, 1, 0, true)
}

///|
test "bench unread writes cold1 retired writes" (it : @bench.T) {
  unread_write_bench(it, 1, 0, false)
}

///|
test "bench unread writes cold64 V82 predecessor" (it : @bench.T) {
  unread_write_bench(it, 64, 0, true)
}

///|
test "bench unread writes cold64 retired writes" (it : @bench.T) {
  unread_write_bench(it, 64, 0, false)
}

///|
test "bench unread writes tee64 V82 predecessor" (it : @bench.T) {
  unread_write_bench(it, 64, 1, true)
}

///|
test "bench unread writes tee64 retired writes" (it : @bench.T) {
  unread_write_bench(it, 64, 1, false)
}

///|
test "bench unread writes set64 V82 predecessor" (it : @bench.T) {
  unread_write_bench(it, 64, 2, true)
}

///|
test "bench unread writes set64 retired writes" (it : @bench.T) {
  unread_write_bench(it, 64, 2, false)
}

///|
test "bench unread writes handler16 V82 predecessor" (it : @bench.T) {
  unread_write_bench(it, 16, 3, true)
}

///|
test "bench unread writes handler16 retired writes" (it : @bench.T) {
  unread_write_bench(it, 16, 3, false)
}
