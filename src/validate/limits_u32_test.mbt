///|
test "i32 limits accept high unsigned minima and optional maxima" {
  let env = @validate.Env::new()
  for
    (minimum, maximum) in [
      (0U, 0x7fffffffU),
      (0U, 0x80000000U),
      (0U, 0xffffffffU),
      (0x80000000U, 0x80000000U),
      (0xffffffffU, 0xffffffffU),
    ] {
    @debug.assert_eq(
      @validate.ValidateMax::validate_max(
        @lib.Limits::i32(minimum, Some(maximum)),
        env,
        0xffffffffUL,
      ),
      Ok(()),
    )
  }
}

///|
test "table32 accepts high unsigned minima and optional maxima" {
  let env = @validate.Env::new()
  for
    limits in [
      @lib.Limits::i32(0U, Some(0x7fffffffU)),
      @lib.Limits::i32(0U, Some(0x80000000U)),
      @lib.Limits::i32(0U, Some(0xffffffffU)),
      @lib.Limits::i32(0x80000000U, Some(0x80000000U)),
      @lib.Limits::i32(0xffffffffU, Some(0xffffffffU)),
      @lib.Limits::i32(0x80000000U, None),
      @lib.Limits::i32(0xffffffffU, None),
    ] {
    let table = @lib.TableType::new(
      @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
      limits,
    )
    @debug.assert_eq(@validate.Validate::validate(table, env), Ok(()))
  }
}

///|
test "i32 limits reject reversed unsigned ranges" {
  let env = @validate.Env::new()
  for
    (minimum, maximum) in [
      (1U, 0U),
      (0x80000000U, 0x7fffffffU),
      (0xffffffffU, 0x80000000U),
    ] {
    @debug.assert_eq(
      @validate.ValidateMax::validate_max(
        @lib.Limits::i32(minimum, Some(maximum)),
        env,
        0xffffffffUL,
      ),
      Err("Invalid range for limits"),
    )
  }
}

///|
test "i32 limits preserve exact bounds below and above the unsigned range" {
  let env = @validate.Env::new()
  for
    (minimum, maximum, bound, expected) in [
      (65536U, None, 65536UL, Ok(())),
      (0U, Some(65536U), 65536UL, Ok(())),
      (65537U, None, 65536UL, Err("Invalid range for limits")),
      (0U, Some(65537U), 65536UL, Err("Invalid range for limits")),
      (0U, Some(0x80000000U), 0x7fffffffUL, Err("Invalid range for limits")),
      (0U, Some(0x80000000U), 0x80000000UL, Ok(())),
      (0xffffffffU, Some(0xffffffffU), 0x100000000UL, Ok(())),
      (
        0xffffffffU,
        Some(0x80000000U),
        0xffffffffffffffffUL,
        Err("Invalid range for limits"),
      ),
      (
        0x80000001U,
        Some(0x80000000U),
        0xffffffffffffffffUL,
        Err("Invalid range for limits"),
      ),
    ] {
    @debug.assert_eq(
      @validate.ValidateMax::validate_max(
        @lib.Limits::i32(minimum, maximum),
        env,
        bound,
      ),
      expected,
    )
  }
}
