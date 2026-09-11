///|
test "constraint bit-pattern domain preserves all small-width increment values" {
  for lo = 0; lo < 16; lo = lo + 1 {
    for hi = lo; hi < 16; hi = hi + 1 {
      let range = ca_range(4, [{ lo: lo.to_uint64(), hi: hi.to_uint64(), }])
      for increment = 0; increment < 16; increment = increment + 1 {
        let transferred = ca_add(range, increment.to_uint64())
        for value = lo; value <= hi; value = value + 1 {
          @debug.assert_eq(
            ca_contains(transferred, ((value + increment) & 15).to_uint64()),
            true,
          )
        }
      }
    }
  }
}

///|
test "constraint relation swap negation and signed ranges agree with exhaustive small-width values" {
  for signed in [false, true] {
    for relation = 1; relation < 7; relation = relation + 1 {
      @debug.assert_eq(ca_flip(ca_flip(relation)), relation)
      @debug.assert_eq(ca_not(ca_not(relation)), relation)
      for constant = 0; constant < 16; constant = constant + 1 {
        let range = ca_relation_range(4, relation, signed, constant.to_uint64())
        for value = 0; value < 16; value = value + 1 {
          let a = if signed && value >= 8 { value - 16 } else { value }
          let b = if signed && constant >= 8 { constant - 16 } else { constant }
          let outcome = if a < b { 1 } else if a == b { 2 } else { 4 }
          @debug.assert_eq(
            ca_contains(range, value.to_uint64()),
            (outcome & relation) != 0,
          )
        }
      }
    }
  }
  @debug.assert_eq(ca_flip(1), 4)
  @debug.assert_eq(ca_not(1), 6)
}

///|
test "constraint i64 wrap and mixed signedness retain the all-ones bit pattern" {
  let maximum = ca_exact(64, 0xffffffffffffffffUL)
  @debug.assert_eq(ca_single(ca_add(maximum, 1UL)), Some(0UL))
  let signed_less = ca_relation_range(64, 1, true, 5UL)
  @debug.assert_eq(ca_contains(signed_less, 0xffffffffffffffffUL), true)
  @debug.assert_eq(ca_contains(signed_less, 0UL), true)
  let unsigned_less = ca_relation_range(64, 1, false, 5UL)
  @debug.assert_eq(ca_contains(unsigned_less, 0xffffffffffffffffUL), false)
  @debug.assert_eq(ca_intersect(signed_less, unsigned_less), unsigned_less)
}
