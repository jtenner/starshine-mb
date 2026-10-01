///|
fn table64_tail_env(limits : Limits) -> Env {
  Env::new()
  .with_rectype(RecType::new(tcneg_single_functype_subtype([], [])))
  .with_tables([TableType::new(RefType::abs(AbsHeapType::func()), limits)])
  .with_return_type(Some([]))
}

///|
test "return_call_indirect accepts the table address width" {
  for limits in [Limits::i32(1, None), Limits::i64(1UL, None)] {
    let state = tcneg_make_state(table64_tail_env(limits), [
      limits.addr_valtype(),
    ])
    match
      Typecheck::typecheck(
        Instruction::return_call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
        state,
      ) {
      Ok(_) => ()
      Err(error) => fail(error)
    }
  }
}

///|
test "return_call_indirect intentionally rejects the wrong table address width" {
  for limits in [Limits::i32(1, None), Limits::i64(1UL, None)] {
    let wrong = if limits.addr_valtype() == ValType::i32() {
      ValType::i64()
    } else {
      ValType::i32()
    }
    let state = tcneg_make_state(table64_tail_env(limits), [wrong])
    tcneg_assert_err_contains(
      Typecheck::typecheck(
        Instruction::return_call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
        state,
      ),
      "type mismatch",
    )
  }
}
