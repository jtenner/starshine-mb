///|
test "review r1 validation accepts array.len with a virtual bottom operand" {
  let module_ = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::unreachable_(),
            Instruction::array_len(),
            Instruction::drop(),
          ]),
        ),
      ]),
    )
  match validate_module(module_) {
    Ok(_) => ()
    Err(error) => fail(validation_error_message(error))
  }
}


///|
test "R1-05 array.len virtual bottom produces i32" {
  let state = assert_ok(Typecheck::typecheck(
    Instruction::unreachable_(), make_state(empty_env(), []),
  ))
  let result = assert_ok(Typecheck::typecheck(Instruction::array_len(), state))
  assert_stack(result, [ValType::i32()])
  assert_eq(result.polymorphic, true)
}

///|
test "R1-05 array.len rejects invalid concrete operands even after unreachable" {
  for operand in [ValType::i32(), ValType::ref_type(RefType::new(true, HeapType::abs(AbsHeapType::func())))] {
    for dead in [false, true] {
      let state = make_state(empty_env(), [])
      let state = if dead { assert_ok(Typecheck::typecheck(Instruction::unreachable_(), state)) } else { state }
      tcneg_assert_err_contains(
        Typecheck::typecheck(Instruction::array_len(), state.push1(operand)),
        "array.len requires an array reference",
      )
    }
  }
  tcneg_assert_err_contains(
    Typecheck::typecheck(Instruction::array_len(), make_state(empty_env(), [])),
    "stack underflow",
  )
}

///|
test "R1-05 array.len accepts concrete array references" {
  let array_type = SubType::comp_type(CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)))
  let env = { ..empty_env(), global_types: [array_type], }
  for nullable in [false, true] {
    let operand = ValType::ref_type(RefType::new(nullable, HeapType::new(TypeIdx::new(0))))
    let result = assert_ok(Typecheck::typecheck(Instruction::array_len(), make_state(env, [operand])))
    assert_stack(result, [ValType::i32()])
  }
}

///|
// wasm-tools 1.262.0 encoding of tests/repros/hunt-r1/array-len-bottom.wat.
test "R1-05 accepts the original encoded WAT repro" {
  let bytes : Bytes = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x0a\x08\x01\x06\x00\x00\xfb\x0f\x1a\x0b"
  let module_ = @binary.decode_module(bytes).unwrap()
  match validate_module(module_) {
    Ok(_) => ()
    Err(error) => fail(validation_error_message(error))
  }
}
