///|
fn dae2_mixed_group_expected_128(late_capture : Bool) -> @lib.Func {
  let locals = Array::make(125, "i32").join(" ")
  let tail = if late_capture {
    "local.get 2 call $c32 call $value local.set 125 call $value drop local.get 125 call $h"
  } else {
    "local.get 2 call $h"
  }
  pass_test_module_from_wat(
    "(module (import \"e\" \"value\" (func $value (result i32))) (import \"e\" \"effect\" (func $effect)) (import \"e\" \"c32\" (func $c32 (param i32))) (import \"e\" \"c64\" (func $c64 (param i64))) (func $h (param i32) (result i32) local.get 0) (func (param i32) (result i32) (local \{locals} i64 i64) call $value local.set 1 i64.const 7 local.set 126 i64.const 9 local.set 127 call $value local.get 0 if call $effect end local.set 2 local.get 1 call $c32 local.get 126 call $c64 local.get 127 call $c64 \{tail} local.get 0 if call $effect end))",
  ).code_sec.unwrap().0[1]
}

///|
// Dedicated threshold lane:128slots exercise the complete bounded grouping
// scan, rather than increasing the default behavior-test resource budget.
#skip
test "DAE2 mixed local grouping admits exactly128 original slots with exact grouped operands" {
  let input = dae2_raw_mixed_tail_fixture("call $value", body_locals=127)
  let expected = dae2_mixed_group_expected_128(false)
  let @lib.Func(expected_locals, _) = expected
  assert_eq(expected_locals.length() + 1, 128)
  raw_structured_held_shape_compare(
    input,
    expected,
    "exact128mixed",
    strict_gain=true,
  )
}

///|
fn dae2_mixed_group_late_capture_fixture(body_locals : Int32) -> @lib.Module {
  let tail = Array::make(body_locals - 3, "i32").join(" ")
  pass_test_module_from_wat(
    "(module (import \"e\" \"value\" (func $value (result i32))) (import \"e\" \"effect\" (func $effect)) (import \"e\" \"c32\" (func $c32 (param i32))) (import \"e\" \"c64\" (func $c64 (param i64))) (memory 1) (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) (local i32 i64 i64 \{tail}) call $value local.set 1 i64.const 7 local.set 2 i64.const 9 local.set 3 call $value local.get 0 if call $effect end local.set 4 local.get 1 call $c32 local.get 2 call $c64 local.get 3 call $c64 local.get 4 call $c32 call $value call $value call $h local.get 0 if call $effect end))",
  )
}

///|
// The second effectful argument prevents the newly allocated kept-argument
// capture from disappearing in balanced-prefix cleanup. Its surviving slot
// must be included in the final width check, after initial admission.
#skip
test "DAE2 mixed local grouping includes a late128th slot and intentionally falls back for a late129th slot" {
  let small = dae2_mixed_group_late_capture_fixture(126)
  let expected = dae2_mixed_group_expected_128(true)
  let @lib.Func(small_locals, _) = small.code_sec.unwrap().0[1]
  assert_eq(small_locals.length() + 1, 127)
  let @lib.Func(expected_locals, _) = expected
  assert_eq(expected_locals.length() + 1, 128)
  raw_structured_held_shape_compare(
    small,
    expected,
    "late128mixed",
    strict_gain=true,
  )
  let wide = dae2_mixed_group_late_capture_fixture(127)
  let @lib.Func(wide_locals, _) = wide.code_sec.unwrap().0[1]
  assert_eq(wide_locals.length() + 1, 128)
  let saved = @binary.encode_module(wide).unwrap()
  for closed_world in [false, true] {
    let lifts = [0]
    let actual = dae2_run_module_pass(
      wide,
      closed_world,
      stack_suffix_rewrite=false,
      rewrite_lifts=Some(lifts),
    ).unwrap()
    let reference = dae2_run_module_pass(
      wide,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_true(lifts[0] > 0)
    assert_eq(actual.code_sec, reference.code_sec)
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
  }
  assert_eq(@binary.encode_module(wide).unwrap(), saved)
}
