///|
test "Binaryen 132 suspension tags may return values" {
  let env = Env::{
    ..empty_env(),
    global_types: [SubType::comp_type(CompType::func([], [ValType::i64()]))],
  }
  match Validate::validate(TagType::new(TypeIdx::new(0U)), env) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "Binaryen 132 exception instructions reject suspension tags with results" {
  let env = Env::{
      ..empty_env(),
      global_types: [SubType::comp_type(CompType::func([], [ValType::i64()]))],
    }
    .push_tag(TagType::new(TypeIdx::new(0U)))
    .with_label([])
  for
    instr in [
      Instruction::throw_(TagIdx::new(0U)),
      Instruction::try_table(
        BlockType::void_(),
        [Catch::new(TagIdx::new(0U), LabelIdx::new(0U))],
        Expr::new([]),
      ),
      Instruction::try_(BlockType::void_(), Expr::new([]), [
        @lib.LegacyCatch::tagged(TagIdx::new(0U), Expr::new([])),
      ]),
    ] {
    match Typecheck::typecheck(instr, make_state(env, [])) {
      Ok(_) =>
        fail("exception operation accepted a result-bearing suspension tag")
      Err(_) => ()
    }
  }
}

///|
test "resume handler edges keep the target block reachable after terminal fallthrough" {
  let cont = TypeIdx::new(1U)
  let reference = ValType::ref_type(RefType::new(true, HeapType::new(cont)))
  let env = Env::{
    ..empty_env(),
    global_types: [
      SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
      SubType::comp_type(CompType::cont(TypeIdx::new(0U))),
      SubType::comp_type(CompType::func([], [ValType::i32()])),
    ],
  }.push_tag(TagType::new(TypeIdx::new(2U)))
  let body = Instruction::block(
    BlockType::val_type(reference),
    Expr::new([
      Instruction::i32_const(I32(7)),
      Instruction::ref_null(HeapType::new(cont)),
      Instruction::resume_(cont, [
        @lib.ResumeHandler::on_label(TagIdx::new(0U), LabelIdx::new(0U)),
      ]),
      Instruction::unreachable_(),
    ]),
  )
  let result = match Typecheck::typecheck(body, make_state(env, [])) {
    Ok(result) => result
    Err(err) => fail(err)
  }
  @debug.assert_eq(result.reachable, true)
  @debug.assert_eq(result.stack, [reference])
}
