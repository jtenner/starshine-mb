///|
fn sl_leaf_bytes(body : Array[@lib.Instruction]) -> Bytes {
  let out = @buffer.new()
  @binary.Encode::encode(@lib.Expr::new(body), out).unwrap()
  out.to_bytes()
}

///|
test "single leaf suffixes preserve scalar bits and avoid full state setup" {
  let env = @validate.Env::new()
  for
    leaf in [
      @lib.Instruction::i32_const(@lib.I32(-1)),
      @lib.Instruction::i64_const(@lib.I64(-1L)),
      @lib.Instruction::f32_const(@lib.F32(-0.0)),
      @lib.Instruction::f32_const(@lib.F32(0x7fc00001U.reinterpret_as_float())),
      @lib.Instruction::f64_const(@lib.F64(-0.0)),
      @lib.Instruction::f64_const(
        @lib.F64(0x7ff8000000000001UL.reinterpret_as_double()),
      ),
    ] {
    let body = [@lib.Instruction::nop(), leaf, @lib.Instruction::drop()]
    let saved = sl_leaf_bytes(body)
    let typed = [0]
    let actual = sl_value_suffix_at(
      body,
      2,
      1,
      env,
      typed_instructions=Some(typed),
    )
    let expected = sl_value_suffix_reference([body[0], leaf], 1, env).1
    assert_eq(sl_leaf_bytes(actual), sl_leaf_bytes(expected))
    assert_eq(actual.length(), 1)
    actual[0] = @lib.Instruction::nop()
    assert_eq(sl_leaf_bytes(body), saved)
    assert_eq(typed[0], 0)
  }
}

///|
test "single local reads preserve prevalidated scalar and reference typing" {
  for ty in ["i32", "i64", "externref", "(ref extern)"] {
    let seed = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func (result \{ty}))) (func (local \{ty}) call 0 local.set 0 local.get 0 drop))",
    )
    @validate.validate_module(seed).unwrap()
    let @lib.Func(locals, _) = seed.code_sec.unwrap().0[0]
    let env = @validate.Env::new().with_module(seed).with_locals(locals)
    let body = [
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ]
    let typed = [0]
    let actual = sl_value_suffix_at(
      body,
      2,
      1,
      env,
      typed_instructions=Some(typed),
    )
    assert_eq(actual, sl_value_suffix_reference(body, 1, env).1)
    ignore(
      @validate.Typecheck::typecheck(
        @lib.Expr::new(actual),
        @validate.make_state(env, []),
      ).unwrap(),
    )
    assert_eq(typed[0], 0)
  }
}

///|
test "single leaf shortcuts retain bounds and compound validation fallback" {
  let env = @validate.Env::new().with_locals(
    @lib.Locals::from_types([@lib.ValType::i32()]),
  )
  for
    body in [
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ],
      // Intentionally invalid local indices must remain rejected.
      [@lib.Instruction::local_get(@lib.LocalIdx::new(1U))],
      [@lib.Instruction::local_get(@lib.LocalIdx::new(0xffffffffU))],
      // Intentionally invalid: simple leaf admission cannot admit mixed operand types.
      [@lib.Instruction::i64_const(@lib.I64(7L)), @lib.Instruction::i32_eqz()],
      [@lib.Instruction::i32_const(@lib.I32(7)), @lib.Instruction::i32_eqz()],
      [
        @lib.Instruction::ref_null(
          @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
        ),
      ],
      [],
    ] {
    let saved = sl_leaf_bytes(body)
    for end in 0..<(body.length() + 1) {
      let prefix = Array::makei(end, fn(index) { body[index] })
      for count in [0, 1, 2] {
        assert_eq(
          sl_leaf_bytes(sl_value_suffix_at(body, end, count, env)),
          sl_leaf_bytes(sl_value_suffix_reference(prefix, count, env).1),
        )
      }
    }
    assert_eq(sl_leaf_bytes(body), saved)
  }
}
