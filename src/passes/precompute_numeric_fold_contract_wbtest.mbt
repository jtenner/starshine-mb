///|
// Compare opcodes and literal bits, including signed zero and canonical NaNs.
// The expected constants below are fixed arithmetic results, not folder calls.
fn precompute_assert_numeric_fold_cases(
  cases : Array[(String, String, String)],
) -> Unit raise {
  let mut source = "(module"
  let mut expected = "(module"
  for (ty, expression, result) in cases {
    source += " (func (result \{ty}) \{expression})"
    expected += " (func (result \{ty}) \{result})"
  }
  source += ")"
  expected += ")"
  let input = pass_test_module_from_wat(source)
  let expected = pass_test_module_from_wat(expected)
  let expected_funcs = expected.code_sec.unwrap().0
  for pass_name in ["precompute", "precompute-propagate"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_), msg=pass_name)
    let funcs = output.code_sec.unwrap().0
    assert_eq(funcs.length(), cases.length())
    for index, actual in funcs {
      let @lib.Func(_, @lib.Expr(body)) = actual
      let @lib.Func(_, @lib.Expr(wanted)) = expected_funcs[index]
      assert_eq(body.length(), 1, msg="\{pass_name}: \{cases[index].1}")
      assert_true(
        pass_const_instruction_vectors_bits_equal(body, wanted),
        msg="\{pass_name}: \{cases[index].1}; got \{body}",
      )
    }
  }
}

///|
test "precompute folds integer wraparound comparisons and masked rotations" {
  precompute_assert_numeric_fold_cases([
    ("i32", "i32.const 85 i32.const 15 i32.xor", "i32.const 90"),
    ("i32", "i32.const -7 i32.const 2 i32.lt_s", "i32.const 1"),
    ("i32", "i32.const -7 i32.const -8 i32.gt_s", "i32.const 1"),
    ("i32", "i32.const -7 i32.const -7 i32.le_s", "i32.const 1"),
    ("i32", "i32.const -1 i32.const 1 i32.le_u", "i32.const 0"),
    ("i32", "i32.const -7 i32.const -8 i32.ge_s", "i32.const 1"),
    ("i32", "i32.const -1 i32.const 2 i32.div_u", "i32.const 2147483647"),
    ("i32", "i32.const -7 i32.const 3 i32.rem_s", "i32.const -1"),
    ("i32", "i32.const -1 i32.const 10 i32.rem_u", "i32.const 5"),
    (
      "i32", "i32.const -2147483647 i32.const 32 i32.rotl", "i32.const -2147483647",
    ),
    (
      "i32", "i32.const -2147483647 i32.const 64 i32.rotr", "i32.const -2147483647",
    ),
    (
      "i64", "i64.const -9223372036854775808 i64.const 1 i64.sub", "i64.const 9223372036854775807",
    ),
    (
      "i64", "i64.const -9223372036854775807 i64.const 64 i64.rotl", "i64.const -9223372036854775807",
    ),
    (
      "i64", "i64.const -9223372036854775807 i64.const 128 i64.rotr", "i64.const -9223372036854775807",
    ),
    ("i32", "i64.const -1 i64.const -1 i64.eq", "i32.const 1"),
    ("i32", "i64.const -1 i64.const 1 i64.ne", "i32.const 1"),
    ("i32", "i64.const -7 i64.const 2 i64.lt_s", "i32.const 1"),
    ("i32", "i64.const -1 i64.const 1 i64.lt_u", "i32.const 0"),
    ("i32", "i64.const -7 i64.const -8 i64.gt_s", "i32.const 1"),
    ("i32", "i64.const -1 i64.const 1 i64.gt_u", "i32.const 1"),
    ("i32", "i64.const -7 i64.const -7 i64.le_s", "i32.const 1"),
    ("i32", "i64.const -1 i64.const 1 i64.le_u", "i32.const 0"),
    ("i32", "i64.const -7 i64.const -8 i64.ge_s", "i32.const 1"),
    ("i32", "i64.const -1 i64.const 1 i64.ge_u", "i32.const 1"),
    ("i64", "i64.const -7 i64.const 3 i64.div_s", "i64.const -2"),
    (
      "i64", "i64.const -1 i64.const 2 i64.div_u", "i64.const 9223372036854775807",
    ),
    ("i64", "i64.const -7 i64.const 3 i64.rem_s", "i64.const -1"),
    (
      "i64", "i64.const -9223372036854775808 i64.const -1 i64.rem_s", "i64.const 0",
    ),
    ("i64", "i64.const -1 i64.const 10 i64.rem_u", "i64.const 5"),
  ])
}

///|
test "precompute folds floating operations conversions and exact result bits" {
  precompute_assert_numeric_fold_cases([
    ("f32", "f32.const 5.5 f32.const 1.25 f32.sub", "f32.const 4.25"),
    (
      "i32", "f32.const inf f32.const -inf f32.add i32.reinterpret_f32", "i32.const 2143289344",
    ),
    (
      "i32", "f32.const inf f32.const 0 f32.mul i32.reinterpret_f32", "i32.const 2143289344",
    ),
    (
      "i32", "f32.const 0 f32.const 0 f32.div i32.reinterpret_f32", "i32.const 2143289344",
    ),
    ("f32", "f32.const 7 f32.const 2 f32.min", "f32.const 2"),
    (
      "i32", "f32.const -0 f32.const -0 f32.max i32.reinterpret_f32", "i32.const -2147483648",
    ),
    ("f32", "f32.const 5 f32.const 5 f32.max", "f32.const 5"),
    (
      "i32", "f32.const 3 f32.const -0 f32.copysign i32.reinterpret_f32", "i32.const -1069547520",
    ),
    ("f64", "f64.const 5.5 f64.const 1.25 f64.sub", "f64.const 4.25"),
    (
      "i64", "f64.const inf f64.const -inf f64.add i64.reinterpret_f64", "i64.const 9221120237041090560",
    ),
    (
      "i64", "f64.const inf f64.const 0 f64.mul i64.reinterpret_f64", "i64.const 9221120237041090560",
    ),
    ("f64", "f64.const 7 f64.const 2 f64.div", "f64.const 3.5"),
    (
      "i64", "f64.const nan f64.const 2 f64.min i64.reinterpret_f64", "i64.const 9221120237041090560",
    ),
    ("f64", "f64.const 5 f64.const 5 f64.min", "f64.const 5"),
    ("f64", "f64.const 7 f64.const 2 f64.min", "f64.const 2"),
    (
      "i64", "f64.const -0 f64.const -0 f64.max i64.reinterpret_f64", "i64.const -9223372036854775808",
    ),
    ("f64", "f64.const 7 f64.const 2 f64.max", "f64.const 7"),
    ("f64", "f64.const 2 f64.const 7 f64.max", "f64.const 7"),
    ("f32", "i32.const -17 f32.convert_i32_s", "f32.const -17"),
    ("f32", "i32.const -1 f32.convert_i32_u", "f32.const 4294967296"),
    ("f64", "i32.const -17 f64.convert_i32_s", "f64.const -17"),
    ("f64", "i32.const -1 f64.convert_i32_u", "f64.const 4294967295"),
    ("f32", "i64.const -17 f32.convert_i64_s", "f32.const -17"),
    ("f32", "i64.const -1 f32.convert_i64_u", "f32.const 18446744073709551616"),
    ("f64", "i64.const -17 f64.convert_i64_s", "f64.const -17"),
    ("f64", "i64.const -1 f64.convert_i64_u", "f64.const 18446744073709551616"),
    ("i32", "i32.const 32768 i32.extend16_s", "i32.const -32768"),
    ("i64", "i64.const 128 i64.extend8_s", "i64.const -128"),
    ("i64", "i64.const 32768 i64.extend16_s", "i64.const -32768"),
    ("i64", "i64.const 2147483648 i64.extend32_s", "i64.const -2147483648"),
    ("i32", "f32.const 0 f32.neg i32.reinterpret_f32", "i32.const -2147483648"),
    ("i64", "f64.const -0 f64.abs i64.reinterpret_f64", "i64.const 0"),
    (
      "i64", "f64.const 0 f64.neg i64.reinterpret_f64", "i64.const -9223372036854775808",
    ),
    (
      "i64", "f64.const -3.75 f64.trunc i64.reinterpret_f64", "i64.const -4609434218613702656",
    ),
    ("f32", "f32.const 1.25 f32.nearest", "f32.const 1"),
    ("f32", "f32.const 2.5 f32.nearest", "f32.const 2"),
    ("f32", "f32.const 3.5 f32.nearest", "f32.const 4"),
    ("f32", "f32.const inf f32.nearest", "f32.const inf"),
    ("f64", "f64.const 1.25 f64.nearest", "f64.const 1"),
    ("f64", "f64.const 3.5 f64.nearest", "f64.const 4"),
    ("f64", "f64.const inf f64.nearest", "f64.const inf"),
    ("i32", "f32.const -inf i32.trunc_sat_f32_u", "i32.const 0"),
    (
      "i64", "f32.const -inf i64.trunc_sat_f32_s", "i64.const -9223372036854775808",
    ),
    (
      "i64", "f64.const inf i64.trunc_sat_f64_s", "i64.const 9223372036854775807",
    ),
  ])
}

///|
test "precompute retains numeric zero-divisor and conversion traps" {
  let cases = [
    ("i32", "i32.const -2147483648 i32.const -1 i32.div_s"),
    ("i32", "i32.const 1 i32.const 0 i32.rem_s"),
    ("i32", "i32.const 1 i32.const 0 i32.rem_u"),
    ("i64", "i64.const 1 i64.const 0 i64.div_u"),
    ("i64", "i64.const 1 i64.const 0 i64.rem_s"),
    ("i64", "i64.const 1 i64.const 0 i64.rem_u"),
    ("i32", "f64.const -1 i32.trunc_f64_u"),
    ("i64", "f64.const 9223372036854775808 i64.trunc_f64_s"),
  ]
  let mut source = "(module"
  for (ty, expression) in cases {
    source += " (func (result \{ty}) \{expression})"
  }
  source += ")"
  let input = pass_test_module_from_wat(source)
  let original = input.code_sec.unwrap().0
  for pass_name in ["precompute", "precompute-propagate"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_), msg=pass_name)
    let funcs = output.code_sec.unwrap().0
    assert_eq(funcs.length(), cases.length())
    for index, actual in funcs {
      let @lib.Func(_, @lib.Expr(body)) = actual
      let @lib.Func(_, @lib.Expr(wanted)) = original[index]
      assert_true(
        pass_const_instruction_vectors_bits_equal(body, wanted),
        msg="\{pass_name}: \{cases[index].1}; trap must remain",
      )
    }
  }
}

///|
test "precompute folds saturating limits NaN bits and integer vector lanes" {
  precompute_assert_numeric_fold_cases([
    (
      "i32", "f32.const -nan:0x400123 f32.abs i32.reinterpret_f32", "i32.const 2143289635",
    ),
    (
      "i32", "f32.const nan f32.floor i32.reinterpret_f32", "i32.const 2143289344",
    ),
    (
      "i64", "f64.const nan f64.ceil i64.reinterpret_f64", "i64.const 9221120237041090560",
    ),
    (
      "i64", "f64.const nan f64.trunc i64.reinterpret_f64", "i64.const 9221120237041090560",
    ),
    ("f32", "f32.const 9 f32.sqrt", "f32.const 3"),
    ("f32", "f32.const 7 f32.const 2 f32.div", "f32.const 3.5"),
    (
      "i32", "f32.const nan f32.const 2 f32.max i32.reinterpret_f32", "i32.const 2143289344",
    ),
    (
      "i64", "f64.const 0 f64.const 0 f64.div i64.reinterpret_f64", "i64.const 9221120237041090560",
    ),
    (
      "i64", "f64.const nan f64.const 2 f64.max i64.reinterpret_f64", "i64.const 9221120237041090560",
    ),
    ("f64", "f64.const 5 f64.const 5 f64.max", "f64.const 5"),
    (
      "i32", "f32.const inf f32.const inf f32.sub i32.reinterpret_f32", "i32.const 2143289344",
    ),
    (
      "i64", "f64.const inf f64.const inf f64.sub i64.reinterpret_f64", "i64.const 9221120237041090560",
    ),
    ("i32", "f32.const -1 f32.sqrt i32.reinterpret_f32", "i32.const 2143289344"),
    (
      "i64", "f64.const nan f64.sqrt i64.reinterpret_f64", "i64.const 9221120237041090560",
    ),
    ("i32", "f32.const 42.75 i32.trunc_sat_f32_u", "i32.const 42"),
    ("i64", "f32.const nan i64.trunc_sat_f32_s", "i64.const 0"),
    ("i64", "f32.const 42.75 i64.trunc_sat_f32_u", "i64.const 42"),
    ("i32", "f64.const nan i32.trunc_sat_f64_s", "i32.const 0"),
    ("i32", "f64.const -inf i32.trunc_sat_f64_s", "i32.const -2147483648"),
    ("i32", "f64.const 42.75 i32.trunc_sat_f64_u", "i32.const 42"),
    ("i64", "f64.const nan i64.trunc_sat_f64_s", "i64.const 0"),
    ("i64", "f64.const 42.75 i64.trunc_sat_f64_u", "i64.const 42"),
    ("i64", "f32.const -inf i64.trunc_sat_f32_u", "i64.const 0"),
    ("i64", "f64.const inf i64.trunc_sat_f64_u", "i64.const -1"),
    ("i32", "f64.const nan i32.trunc_sat_f64_u", "i32.const 0"),
    ("i32", "f32.const -inf i32.trunc_sat_f32_s", "i32.const -2147483648"),
    (
      "v128", "v128.const i8x16 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 i32.const 291 i8x16.replace_lane 15",
      "v128.const i8x16 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 35",
    ),
    (
      "v128", "v128.const i16x8 0 0 0 0 0 0 0 0 i32.const 74565 i16x8.replace_lane 7",
      "v128.const i16x8 0 0 0 0 0 0 0 9029",
    ),
    (
      "v128", "v128.const i32x4 1 2 3 4 i32.const -1 i32x4.replace_lane 2", "v128.const i32x4 1 2 -1 4",
    ),
    (
      "v128", "v128.const i64x2 1 2 i64.const -9223372036854775808 i64x2.replace_lane 1",
      "v128.const i64x2 1 -9223372036854775808",
    ),
  ])
}

///|
test "precompute folds unary and ordered binary parents over dynamic selects" {
  // Keep the parameter-controlled choice and fold each distinct numeric arm.
  // Subtraction has the select on the right, so operand order is observable.
  let cases = [
    (
      "f32", "i32.const -3 i32.const 5 local.get 0 select f32.convert_i32_s", "f32.const -3 f32.const 5 local.get 0 select",
    ),
    (
      "i32", "f32.const 1.25 f32.const 2.75 local.get 0 select i32.trunc_f32_s",
      "i32.const 1 i32.const 2 local.get 0 select",
    ),
    (
      "i64", "f64.const nan f64.const inf local.get 0 select i64.trunc_sat_f64_s",
      "i64.const 0 i64.const 9223372036854775807 local.get 0 select",
    ),
    (
      "i32", "i32.const 100 i32.const 10 i32.const 20 local.get 0 select i32.sub",
      "i32.const 90 i32.const 80 local.get 0 select",
    ),
    (
      "f64", "f64.const 10 f64.const 1.25 f64.const 2.5 local.get 0 select f64.sub",
      "f64.const 8.75 f64.const 7.5 local.get 0 select",
    ),
  ]
  let mut source = "(module"
  let mut expected = "(module"
  for (ty, expression, result) in cases {
    source += " (func (param i32) (result \{ty}) \{expression})"
    expected += " (func (param i32) (result \{ty}) \{result})"
  }
  source += ")"
  expected += ")"
  let input = pass_test_module_from_wat(source)
  let expected_funcs = pass_test_module_from_wat(expected).code_sec.unwrap().0
  for pass_name in ["precompute", "precompute-propagate"] {
    let output = run_hot_pipeline(
      input,
      HotPipelineOptions::new(optimize_level=2),
      [pass_name],
    ).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_), msg=pass_name)
    let funcs = output.code_sec.unwrap().0
    assert_eq(funcs.length(), cases.length())
    for index, actual in funcs {
      let @lib.Func(_, @lib.Expr(body)) = actual
      let @lib.Func(_, @lib.Expr(wanted)) = expected_funcs[index]
      assert_true(
        pass_const_instruction_vectors_bits_equal(body, wanted),
        msg="\{pass_name}: \{cases[index].1}; got \{body}",
      )
    }
  }
}
