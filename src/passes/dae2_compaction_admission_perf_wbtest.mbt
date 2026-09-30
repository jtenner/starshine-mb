///|
fn compaction_admission_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
  alias : Bool,
  active? : Int = 0,
) -> Unit raise {
  let body = Array::makei(width, fn(i) {
    match active {
      1 => "i32.const 7 local.set \{i + 1} local.get \{i + 1} drop"
      2 =>
        "local.get 0 local.set \{i + 1} local.get \{i + 1} drop local.get \{i + 1} drop"
      _ =>
        "i32.const 7 local.set \{i + 1} local.get \{i + 1} drop local.get \{i + 1} drop"
    }
  }).join(" ")
  let locals = Array::make(width, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (local \{locals}) \{body}))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let func = input.code_sec.unwrap().0[0]
  let empty = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let params = [@lib.ValType::i32()]
  let (out, indices) = pass_lower_compact_captures_with_map(
    func,
    empty,
    params,
    propagate_parameter_aliases=alias,
  )
  let (old, old_indices) = compaction_admission_reference_compact(
    func,
    empty,
    params,
    propagate_parameter_aliases=alias,
  )
  assert_eq(indices, old_indices)
  let @lib.Func(out_locals, out_body) = out
  let @lib.Func(old_locals, old_body) = old
  assert_eq(out_body, old_body)
  assert_eq(out_locals.runs(), old_locals.runs())
  it.bench(fn() {
    it.keep(
      if reference {
        compaction_admission_reference_compact(
          func,
          empty,
          params,
          propagate_parameter_aliases=alias,
        )
      } else {
        pass_lower_compact_captures_with_map(
          func,
          empty,
          params,
          propagate_parameter_aliases=alias,
        )
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench capture admission 8 original" (it : @bench.T) {
  compaction_admission_bench(it, 8, true, false)
}

///|
test "bench capture admission 8 admitted" (it : @bench.T) {
  compaction_admission_bench(it, 8, false, false)
}

///|
test "bench capture admission 512 original" (it : @bench.T) {
  compaction_admission_bench(it, 512, true, false)
}

///|
test "bench capture admission 512 admitted" (it : @bench.T) {
  compaction_admission_bench(it, 512, false, false)
}

///|
test "bench capture admission 8 alias guard original" (it : @bench.T) {
  compaction_admission_bench(it, 8, true, true)
}

///|
test "bench capture admission 8 alias guard admitted" (it : @bench.T) {
  compaction_admission_bench(it, 8, false, true)
}

///|
test "bench capture admission 512 alias guard original" (it : @bench.T) {
  compaction_admission_bench(it, 512, true, true)
}

///|
test "bench capture admission 512 alias guard admitted" (it : @bench.T) {
  compaction_admission_bench(it, 512, false, true)
}

///|
test "bench capture admission 8 active capture original" (it : @bench.T) {
  compaction_admission_bench(it, 8, true, true, active=1)
}

///|
test "bench capture admission 8 active capture admitted" (it : @bench.T) {
  compaction_admission_bench(it, 8, false, true, active=1)
}

///|
test "bench capture admission 8 active alias original" (it : @bench.T) {
  compaction_admission_bench(it, 8, true, true, active=2)
}

///|
test "bench capture admission 8 active alias admitted" (it : @bench.T) {
  compaction_admission_bench(it, 8, false, true, active=2)
}

///|
test "bench capture admission 512 active capture original" (it : @bench.T) {
  compaction_admission_bench(it, 512, true, true, active=1)
}

///|
test "bench capture admission 512 active capture admitted" (it : @bench.T) {
  compaction_admission_bench(it, 512, false, true, active=1)
}

///|
test "bench capture admission 512 active alias original" (it : @bench.T) {
  compaction_admission_bench(it, 512, true, true, active=2)
}

///|
test "bench capture admission 512 active alias admitted" (it : @bench.T) {
  compaction_admission_bench(it, 512, false, true, active=2)
}
