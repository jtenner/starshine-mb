///|
test "compat NaN classifiers follow IEEE payload semantics" {
  let nan32 : Array[Float] = [
    Float::reinterpret_from_uint(0x7FC00000),
    Float::reinterpret_from_uint(0x7F800001),
    Float::reinterpret_from_uint(0xFFC00000),
  ]
  for value in nan32 {
    assert_true(compat_is_f32_nan(value))
  }

  let non_nan32 : Array[Float] = [
    Float::reinterpret_from_uint(0x7F800000),
    Float::reinterpret_from_uint(0xFF800000),
    Float::reinterpret_from_uint(0x3F800000),
  ]
  for value in non_nan32 {
    assert_false(compat_is_f32_nan(value))
  }

  let nan64 : Array[Double] = [
    0x7FF8000000000000UL.reinterpret_as_double(),
    0x7FF0000000000001UL.reinterpret_as_double(),
    0xFFF8000000000000UL.reinterpret_as_double(),
  ]
  for value in nan64 {
    assert_true(compat_is_f64_nan(value))
  }

  let non_nan64 : Array[Double] = [
    0x7FF0000000000000UL.reinterpret_as_double(),
    0xFFF0000000000000UL.reinterpret_as_double(),
    0x3FF0000000000000UL.reinterpret_as_double(),
  ]
  for value in non_nan64 {
    assert_false(compat_is_f64_nan(value))
  }
}

///|
test "compat trunc f64->i64 signed keeps wasm bounds and canonicalization" {
  assert_eq(compat_trunc_f64_to_i64_s(3000000000.0), Some(3000000000L))
  assert_eq(compat_trunc_f64_to_i64_s(-3000000000.0), Some(-3000000000L))
  assert_eq(
    compat_trunc_f64_to_i64_s(-9223372036854775808.0),
    Some(-9223372036854775808L),
  )
  assert_eq(
    compat_trunc_f64_to_i64_s(9007199254740991.0),
    Some(9007199254740991L),
  )
  assert_eq(compat_trunc_f64_to_i64_s(9223372036854775808.0), None)
  assert_eq(compat_trunc_f64_to_i64_s(-1.0e20), None)
}

///|
test "compat trunc f64->i64 unsigned keeps wasm bounds and canonicalization" {
  assert_eq(compat_trunc_f64_to_i64_u(-0.7), Some(0L))
  assert_eq(compat_trunc_f64_to_i64_u(3000000000.0), Some(3000000000L))
  assert_eq(compat_trunc_f64_to_i64_u(18446744073709549568.0), Some(-2048L))
  assert_eq(compat_trunc_f64_to_i64_u(-1.0), None)
  assert_eq(compat_trunc_f64_to_i64_u(18446744073709551616.0), None)
}

///|
test "compat trunc f64->i64 rejects NaNs and infinities" {
  let nan_payloads : Array[Double] = [
    @double.not_a_number,
    0x7FF0000000000001UL.reinterpret_as_double(),
    0xFFF8000000000000UL.reinterpret_as_double(),
  ]
  for value in nan_payloads {
    assert_eq(compat_trunc_f64_to_i64_s(value), None)
    assert_eq(compat_trunc_f64_to_i64_u(value), None)
  }
  for value in [@double.infinity, @double.neg_infinity] {
    assert_eq(compat_trunc_f64_to_i64_s(value), None)
    assert_eq(compat_trunc_f64_to_i64_u(value), None)
  }
}
