///|
test "DAE2 raw summary records all call forms in nested controls and legacy catches" {
  let type_ = @lib.TypeIdx::new(0U)
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::return_call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::call_indirect(type_, @lib.TableIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::try_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::return_call_indirect(type_, @lib.TableIdx::new(0U)),
      ]),
      [
        @lib.LegacyCatch::all(
          @lib.Expr::new([
            @lib.Instruction::call_ref(type_),
            @lib.Instruction::return_call_ref(type_),
          ]),
        ),
      ],
    ),
  ]
  let callees = []
  let controls = []
  assert_true(
    dae2_collect_control_type_infos(
      body,
      [9],
      controls,
      call_infos=Some(callees),
    ),
  )
  assert_eq(callees, [4, 4, 9, 9, 9, 9])
  // Legacy control adaptation intentionally remains outside raw admission.
  assert_eq(controls, [-1])
  assert_true(body[0] is @lib.Block(_, _))
  assert_true(body[1] is @lib.Try(_, _, _, _))
}

///|
test "DAE2 raw summary marks intentionally invalid missing call types unknown" {
  let callees = []
  assert_true(
    dae2_collect_control_type_infos(
      [@lib.Instruction::call_ref(@lib.TypeIdx::new(2U))],
      [9],
      [],
      call_infos=Some(callees),
    ),
  )
  assert_eq(callees, [-1])
}
