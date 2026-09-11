///|
fn array_memory_test_env(storage : StorageType, mutable_ : Bool) -> Env {
  let field = FieldType::new(
    storage,
    if mutable_ {
      Mut::var_()
    } else {
      Mut::const_()
    },
  )
  { ..empty_env(), global_types: [SubType::comp_type(CompType::array(field))], }
}

///|
test "Binaryen 132 multibyte arrays accept every numeric storage and immutable loads" {
  let ti = TypeIdx::new(0U)
  let array_ref = ValType::ref_array_nullable(ti)
  for
    storage in [
      StorageType::pack_type(PackType::i8()),
      StorageType::pack_type(PackType::i16()),
      StorageType::val_type(ValType::i32()),
      StorageType::val_type(ValType::i64()),
      StorageType::val_type(ValType::f32()),
      StorageType::val_type(ValType::f64()),
      StorageType::val_type(ValType::v128()),
    ] {
    for mutable_ in [false, true] {
      let env = array_memory_test_env(storage, mutable_)
      for
        entry in [
          (@lib.LoadOp::i32_load(), ValType::i32()),
          (@lib.LoadOp::i64_load32u(), ValType::i64()),
          (@lib.LoadOp::v128_load(), ValType::v128()),
        ] {
        let (op, result) = entry
        let state = make_state(env, [array_ref, ValType::i32()])
        assert_stack(
          assert_ok(
            Typecheck::typecheck(Instruction::array_load(op, ti), state),
          ),
          [result],
        )
      }
      if mutable_ {
        for
          entry in [
            (@lib.StoreOp::i32_store(), ValType::i32()),
            (@lib.StoreOp::v128_store(), ValType::v128()),
          ] {
          let (op, value) = entry
          let state = make_state(env, [array_ref, ValType::i32(), value])
          assert_stack(
            assert_ok(
              Typecheck::typecheck(Instruction::array_store(op, ti), state),
            ),
            [],
          )
        }
      }
    }
  }
}

///|
test "Binaryen 132 multibyte arrays reject reference storage and immutable stores" {
  let ti = TypeIdx::new(0U)
  let array_ref = ValType::ref_array_nullable(ti)
  let ref_env = array_memory_test_env(
    StorageType::val_type(ValType::funcref()),
    true,
  )
  let load = Instruction::array_load(@lib.LoadOp::i32_load(), ti)
  match
    Typecheck::typecheck(load, make_state(ref_env, [array_ref, ValType::i32()])) {
    Err(_) => ()
    Ok(_) => fail("invalid reference array memory access accepted")
  }
  let immutable = array_memory_test_env(
    StorageType::val_type(ValType::i32()),
    false,
  )
  let store = Instruction::array_store(@lib.StoreOp::i32_store(), ti)
  match
    Typecheck::typecheck(
      store,
      make_state(immutable, [array_ref, ValType::i32(), ValType::i32()]),
    ) {
    Err(_) => ()
    Ok(_) => fail("invalid immutable array store accepted")
  }
}

///|
test "Binaryen 132 array memory arguments enforce access width and u32 offsets" {
  let ti = TypeIdx::new(0U)
  let env = array_memory_test_env(StorageType::pack_type(PackType::i8()), true)
  let stack = [ValType::ref_array_nullable(ti), ValType::i32()]
  for
    entry in [
      (@lib.LoadOp::i32_load8s(), MemArg::new(1U, None, 0UL)),
      (@lib.LoadOp::i64_load32u(), MemArg::new(3U, None, 0UL)),
      (@lib.LoadOp::i32_load(), MemArg::new(2U, None, 0x100000000UL)),
      (@lib.LoadOp::i32_load(), MemArg::new(2U, Some(MemIdx::new(0U)), 0UL)),
    ] {
    let (op, ma) = entry
    match
      Typecheck::typecheck(
        Instruction::array_load(op, ti, memarg=ma),
        make_state(env, stack),
      ) {
      Err(_) => ()
      Ok(_) =>
        fail("invalid array access width offset or memory index accepted")
    }
  }
  let valid = Instruction::array_load(
    @lib.LoadOp::i64_load32u(),
    ti,
    memarg=MemArg::new(2U, None, 0xffffffffUL),
  )
  assert_stack(assert_ok(Typecheck::typecheck(valid, make_state(env, stack))), [
    ValType::i64(),
  ])
}
