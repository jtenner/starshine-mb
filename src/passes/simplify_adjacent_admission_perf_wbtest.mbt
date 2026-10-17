///|
fn sl_adjacent_admission_bench_fixture(
  width : Int32,
  mode : Int32,
  rewritten : Bool,
) -> @lib.Module {
  let regions = Array::makei(width, fn(index) {
    let active = mode == 1 || (mode == 2 && index + 1 == width)
    let pair = if !active {
      ""
    } else if rewritten {
      "i32.const 1 local.tee 1 nop drop"
    } else {
      "i32.const 1 local.set 1 nop local.get 1 drop"
    }
    "local.get 0 loop (type $entry) local.set 1 local.get 0 call 0 local.get 1 call 0 \{pair} end"
  }).join(" ")
  pass_test_module_from_wat(
    "(module (type $entry (func (param i32))) (import \"env\" \"mark\" (func (param i32))) (func (export \"run\") (param i32) (result i32) (local i32) \{regions} local.get 1))",
  )
}

///|
// Compile identical controls in frozen-before and candidate native snapshots.
fn sl_adjacent_admission_bench(
  it : @bench.T,
  width : Int32,
  mode : Int32,
) -> Unit raise {
  let input = sl_adjacent_admission_bench_fixture(width, mode, false)
  let expected = sl_adjacent_admission_bench_fixture(width, mode, true)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (actual, count) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_set_gets(
    body,
  )
  assert_eq(count, if mode == 0 { 0 } else if mode == 1 { width } else { 1 })
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
  )
  assert_eq(output.code_sec, expected.code_sec)
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  it.bench(fn() {
    it.keep(
      run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_set_gets(body),
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native adjacent cleanup cold control")
test "bench adjacent admission cold32" (it : @bench.T) {
  sl_adjacent_admission_bench(it, 32, 0)
}

///|
#skip("paired native adjacent cleanup active control")
test "bench adjacent admission active32" (it : @bench.T) {
  sl_adjacent_admission_bench(it, 32, 1)
}

///|
#skip("paired native adjacent cleanup mixed control")
test "bench adjacent admission mixed32" (it : @bench.T) {
  sl_adjacent_admission_bench(it, 32, 2)
}

///|
#skip("paired native adjacent cleanup cold control")
test "bench adjacent admission cold256" (it : @bench.T) {
  sl_adjacent_admission_bench(it, 256, 0)
}

///|
#skip("paired native adjacent cleanup active control")
test "bench adjacent admission active256" (it : @bench.T) {
  sl_adjacent_admission_bench(it, 256, 1)
}

///|
#skip("paired native adjacent cleanup mixed control")
test "bench adjacent admission mixed256" (it : @bench.T) {
  sl_adjacent_admission_bench(it, 256, 2)
}
