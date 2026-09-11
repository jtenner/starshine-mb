///|
fn waitqueue_test_ref(shared : Bool, bottom : Bool) -> ValType {
  let abs = if bottom {
    AbsHeapType::no_waitqueue()
  } else {
    AbsHeapType::waitqueue()
  }
  ValType::ref_null(
    if shared {
      HeapType::shared_abs(abs)
    } else {
      HeapType::abs(abs)
    },
  )
}

///|
test "Binaryen 132 waitqueue typing accepts explicit queue and bottom operands" {
  let env = {
    ..empty_env(),
    global_types: [
      SubType::comp_type(
        CompType::struct_([
          FieldType::new(StorageType::val_type(ValType::i32()), Mut::var_()),
        ]),
      ),
    ],
  }
  let receiver = ValType::ref_null(HeapType::new(TypeIdx::new(0U)))
  for bottom in [false, true] {
    let queue = waitqueue_test_ref(true, bottom)
    assert_stack(
      assert_ok(
        Typecheck::typecheck(
          Instruction::waitqueue_notify(),
          make_state(env, [queue, ValType::i32()]),
        ),
      ),
      [ValType::i32()],
    )
    assert_stack(
      assert_ok(
        Typecheck::typecheck(
          Instruction::struct_wait(TypeIdx::new(0U), U32(0U)),
          make_state(env, [receiver, queue, ValType::i32(), ValType::i64()]),
        ),
      ),
      [ValType::i32()],
    )
  }
  assert_stack(
    assert_ok(
      Typecheck::typecheck(Instruction::waitqueue_new(), make_state(env, [])),
    ),
    [
      ValType::ref_type(
        RefType::new(false, HeapType::shared_abs(AbsHeapType::waitqueue())),
      ),
    ],
  )
}

///|
test "Binaryen 132 waitqueue new is valid in constant expressions" {
  let queue = waitqueue_test_ref(true, false)
  let input = Module::new().with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(queue, false),
        Expr::new([Instruction::waitqueue_new()]),
      ),
    ]),
  )
  match validate_module(input) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
}

///|
test "Binaryen 132 waitqueue typing rejects invalid queue domains and field indices" {
  let env = {
    ..empty_env(),
    global_types: [
      SubType::comp_type(
        CompType::struct_([
          FieldType::new(StorageType::val_type(ValType::i32()), Mut::var_()),
        ]),
      ),
    ],
  }
  for
    queue in [
      waitqueue_test_ref(false, false),
      waitqueue_test_ref(false, true),
      ValType::externref(),
    ] {
    match
      Typecheck::typecheck(
        Instruction::waitqueue_notify(),
        make_state(env, [queue, ValType::i32()]),
      ) {
      Err(_) => ()
      Ok(_) => fail("invalid waitqueue domain accepted")
    }
  }
  let stack = [
    ValType::ref_null(HeapType::new(TypeIdx::new(0U))),
    waitqueue_test_ref(true, false),
    ValType::i32(),
    ValType::i64(),
  ]
  match
    Typecheck::typecheck(
      Instruction::struct_wait(TypeIdx::new(0U), U32(1U)),
      make_state(env, stack),
    ) {
    Err(_) => ()
    Ok(_) => fail("invalid struct.wait field accepted")
  }
}
