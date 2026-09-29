///|
fn cl_hazard_program_fixture() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::drop(),
  ]
}

///|
test "coalesce compiles hazard facts once and preserves source-clobber conflicts" {
  let body = cl_hazard_program_fixture()
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, 5)
  let effective = Array::make(actions.length(), true)
  let types = Array::make(5, @lib.ValType::i32())
  let matrix = CLBitMatrix::new(5)
  let reference = CLBitMatrix::new(5)
  cl_add_source_write_dest_read_interferences_reference(
    body, actions, effective, types, 1, reference,
  )
  let visits = [0]
  cl_add_source_write_dest_read_interferences(
    body,
    actions,
    effective,
    types,
    1,
    matrix,
    instruction_visits=Some(visits),
  )
  for source = 0; source < 5; source = source + 1 {
    for dest = source + 1; dest < 5; dest = dest + 1 {
      assert_eq(
        cl_bit_matrix_get(matrix, source, dest),
        cl_bit_matrix_get(reference, source, dest),
      )
    }
  }
  assert_true(cl_bit_matrix_get(matrix, 1, 2))
  assert_true(cl_bit_matrix_get(matrix, 3, 4))
  assert_true(visits[0] <= body.length())
  assert_eq(body, cl_hazard_program_fixture())
}

///|
test "coalesce compiled hazards preserve branch merges copy exceptions and barriers" {
  let fixtures = [
    pass_test_module_from_wat(
      "(module (func (param i32) (local i32 i32 i32 i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 2 drop local.get 1 local.set 3 local.get 3 local.set 1 local.get 3 drop))",
    ),
    pass_test_module_from_wat(
      "(module (func (param i32) (local i32 i32 i32 i32) i32.const 1 local.set 1 block i32.const 2 local.set 1 local.get 0 br_if 0 local.get 2 drop end i32.const 3 local.set 3 loop local.get 3 drop end local.get 4 drop))",
    ),
    pass_test_module_from_wat(
      "(module (func (param i32) (local i32 i32 i32 i32) i32.const 1 local.set 1 block i32.const 2 local.set 1 br 0 end local.get 2 drop i32.const 3 local.set 3 return local.get 4 drop))",
    ),
  ]
  for mod_ in fixtures {
    @validate.validate_module(mod_).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
    let actions : Array[CLAction] = []
    cl_collect_instrs(body, actions, 5)
    for pattern in [0, 1] {
      let effective = Array::makei(actions.length(), fn(index) {
        pattern == 0 || index % 2 == 0
      })
      let types = Array::make(5, @lib.ValType::i32())
      let expected = CLBitMatrix::new(5)
      let actual = CLBitMatrix::new(5)
      cl_add_source_write_dest_read_interferences_reference(
        body, actions, effective, types, 1, expected,
      )
      cl_add_source_write_dest_read_interferences(
        body, actions, effective, types, 1, actual,
      )
      for source = 0; source < 5; source = source + 1 {
        for dest = source + 1; dest < 5; dest = dest + 1 {
          assert_eq(
            cl_bit_matrix_get(actual, source, dest),
            cl_bit_matrix_get(expected, source, dest),
          )
        }
      }
    }
    let output = run_hot_pipeline(mod_, HotPipelineOptions::new(), [
      "coalesce-locals",
    ]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(locals.length(), 4)
  }
}
