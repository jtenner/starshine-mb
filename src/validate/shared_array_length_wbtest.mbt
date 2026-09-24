///|
test "array.len accepts a shared array reference" {
  let array = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::val_type(ValType::i32()), Mut::var_()),
    ),
    metadata=TypeMetadata::new(shared=true),
  )
  let env = Env::new().with_rectype(RecType::new(array))
  let state = tcneg_make_state(env, [
    ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::new(0U)))),
  ])
  match Typecheck::typecheck(Instruction::array_len(), state) {
    Ok(next) => assert_eq(next.stack, [ValType::i32()])
    Err(error) => fail(error)
  }
}

///|
test "ref.eq accepts two shared equality references" {
  let shared = ValType::ref_type(
    RefType::new(true, HeapType::shared_abs(AbsHeapType::eq())),
  )
  let state = tcneg_make_state(Env::new(), [shared, shared])
  match Typecheck::typecheck(Instruction::ref_eq(), state) {
    Ok(next) => assert_eq(next.stack, [ValType::i32()])
    Err(error) => fail(error)
  }
}

///|
test "ref.eq intentionally rejects mixed sharedness" {
  let shared = ValType::ref_type(
    RefType::new(true, HeapType::shared_abs(AbsHeapType::eq())),
  )
  let state = tcneg_make_state(Env::new(), [ValType::eqref_null(), shared])
  assert_true(Typecheck::typecheck(Instruction::ref_eq(), state).is_err())
}

///|
test "i31.get accepts shared bottom references that trap at runtime" {
  let bottom = ValType::ref_type(
    RefType::new(true, HeapType::shared_abs(AbsHeapType::none())),
  )
  for instr in [Instruction::i31_get_s(), Instruction::i31_get_u()] {
    let state = tcneg_make_state(Env::new(), [bottom])
    match Typecheck::typecheck(instr, state) {
      Ok(next) => assert_eq(next.stack, [ValType::i32()])
      Err(error) => fail(error)
    }
  }
}

///|
test "i31.get accepts nullable unshared i31 and bottom references" {
  for
    heap in [
      HeapType::abs(AbsHeapType::i31()),
      HeapType::abs(AbsHeapType::none()),
    ] {
    let state = tcneg_make_state(Env::new(), [
      ValType::ref_type(RefType::new(true, heap)),
    ])
    match Typecheck::typecheck(Instruction::i31_get_u(), state) {
      Ok(next) => assert_eq(next.stack, [ValType::i32()])
      Err(error) => fail(error)
    }
  }
}
