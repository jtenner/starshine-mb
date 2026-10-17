///|
test "DAE2 raw forward labels preserve entry overwritten and branch-local definitions" {
  for
    body in [
      "block $out local.get 0 if local.get 1 local.set 4 br $out end local.get 2 local.set 4 end local.get 4",
      "local.get 1 local.set 4 block $out local.get 0 if br $out end local.get 2 local.set 4 end local.get 4",
      "block $out local.get 0 if local.get 1 local.set 4 br $out else local.get 2 local.set 4 br $out end end local.get 4",
      "block $out local.get 1 local.set 4 local.get 0 if local.get 2 local.set 4 br $out end i32.const 9 local.set 4 end local.get 4",
      "block $outer block $inner local.get 0 if local.get 1 local.set 4 br $outer end local.get 2 local.set 4 br $inner end local.get 4 i32.const 1 i32.add local.set 4 end local.get 4",
      "block $out local.get 0 if br $out end local.get 1 local.set 4 end local.get 4",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
    let lifts = [0]
    ignore(
      dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap(),
    )
    assert_eq(lifts[0], 0)
  }
}

///|
test "DAE2 raw forward labels preserve br_if fallthrough and target result demand" {
  for
    body in [
      "block $out local.get 1 local.set 4 local.get 0 br_if $out local.get 2 local.set 4 end local.get 4",
      "block $out (result i32) local.get 1 local.get 0 br_if $out drop local.get 2 end",
      "block $out (result i32) local.get 0 if local.get 1 br $out end local.get 2 end",
      "local.get 0 if $out (result i32) local.get 1 br $out else local.get 2 end",
      "local.get 1 local.get 0 br_if 0 drop local.get 2",
    ] {
    // Dropping the function result must not remove a branch payload or the
    // observed target's fallthrough value, including the implicit func label.
    for discard in [false, true] {
      let result = if discard { "" } else { "(result i32)" }
      let tail = if discard { "drop" } else { "" }
      let input = pass_test_module_from_wat(
        "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) \{result} local.get 0 local.get 1 local.get 2 i64.const 9 call $h \{tail}))",
      )
      raw_conditional_compare_boundaries(input, 2)
    }
  }
}

///|
test "DAE2 raw forward labels preserve br_table exits and shared target snapshots" {
  for
    body in [
      "block $out block $inner local.get 1 local.set 4 local.get 0 br_table $inner $out end local.get 2 local.set 4 end local.get 4",
      "block $out block $inner local.get 0 br_table $inner $out end local.get 1 local.set 4 end local.get 4",
      "block $out block $inner local.get 1 local.set 4 local.get 0 br_table $inner $inner $out end local.get 2 local.set 4 end local.get 4",
      "block $out (result i32) block $inner (result i32) local.get 1 local.get 0 br_table $inner $out end drop local.get 2 end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
  }
}

///|
test "DAE2 raw forward labels preserve effects traps and terminated branch arms" {
  for
    body in [
      "block $out local.get 0 if local.get 1 i32.load local.set 4 br $out end local.get 2 i32.const 7 i32.store i32.const 5 local.set 4 end local.get 4",
      "block $out (result i32) local.get 0 if local.get 1 i32.const 0 i32.div_s br $out end local.get 2 end",
      "block $out local.get 0 if unreachable else local.get 1 local.set 4 br $out end end local.get 4",
      "block $out (result i32) local.get 0 if (result i32) unreachable else local.get 1 br $out end end",
      "block $out local.get 0 if local.get 1 return else local.get 2 local.set 4 br $out end end local.get 4",
    ] {
    let input = pass_test_module_from_wat(
      "(module (memory 1) (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
  }
}

///|
test "DAE2 raw forward labels intentionally retain HOT for virtual unreachable branch payloads" {
  // The current raw contract excludes concrete dead tails and virtual stack
  // operands. Validate these cases through HOT instead of inventing payloads.
  for
    body in [
      "block $out (result i32) unreachable br $out end", "block $out (result i32) unreachable i32.const 0 br_if $out end",
      "block $out (result i32) unreachable i32.const 0 br_table $out end", "block $out local.get 1 local.get 0 br_table $out end i32.const 7",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 1)
  }
}
