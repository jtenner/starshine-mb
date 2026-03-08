///|
pub fn compat_is_f32_nan(x : Float) -> Bool {
  let bits = x.reinterpret_as_uint()
  let exp = bits & 0x7F800000U
  let frac = bits & 0x007FFFFFU
  exp == 0x7F800000U && frac != 0U
}

///|
pub fn compat_is_f64_nan(x : Double) -> Bool {
  let bits = x.reinterpret_as_uint64()
  let exp = bits & 0x7FF0000000000000UL
  let frac = bits & 0x000FFFFFFFFFFFFFUL
  exp == 0x7FF0000000000000UL && frac != 0UL
}

///|
pub fn compat_is_f64_non_finite(x : Double) -> Bool {
  (x.reinterpret_as_uint64() & 0x7FF0000000000000UL) == 0x7FF0000000000000UL
}

///|
fn compat_trunc_f64_to_u64_nonneg(x : Double) -> UInt64 {
  let two_pow_32 = 4294967296.0
  let hi = (x / two_pow_32).trunc().to_uint64()
  let lo = (x - hi.to_double() * two_pow_32).to_uint64()
  (hi << 32) | lo
}

///|
pub fn compat_trunc_f64_to_i64_s(x : Double) -> Int64? {
  if compat_is_f64_non_finite(x) {
    return None
  }
  let t = x.trunc()
  if t < -9223372036854775808.0 || t >= 9223372036854775808.0 {
    None
  } else if t < 0.0 {
    if t == -9223372036854775808.0 {
      Some(-9223372036854775808L)
    } else {
      let abs_u = compat_trunc_f64_to_u64_nonneg(-t)
      Some(-abs_u.reinterpret_as_int64())
    }
  } else {
    Some(compat_trunc_f64_to_u64_nonneg(t).reinterpret_as_int64())
  }
}

///|
pub fn compat_trunc_f64_to_i64_u(x : Double) -> Int64? {
  if compat_is_f64_non_finite(x) {
    return None
  }
  let t = x.trunc()
  if t < 0.0 || t >= 18446744073709551616.0 {
    None
  } else {
    Some(compat_trunc_f64_to_u64_nonneg(t).reinterpret_as_int64())
  }
}
