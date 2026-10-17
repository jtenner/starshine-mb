///|
test "coalesce reader matrices match behavior and the copied probe uses one Boolean row" {
  cl_combined_native_noop_case_0()
  cl_combined_native_noop_case_1()
  cl_combined_native_noop_case_2()
  cl_combined_native_noop_case_3()
  cl_combined_native_done_case_0()
  cl_combined_native_done_case_1()
  cl_combined_native_done_case_2()
  let (body, types) = cl_done_fixture(1, 0)
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, 4)
  let effective = Array::make(actions.length(), true)
  let before_body = body.copy()
  let before_effective = effective.copy()
  let before_types = types.copy()
  let actual = CLBitMatrix::new(4)
  let counted = CLBitMatrix::new(4)
  let work = [0]
  cl_add_linear_source_write_dest_read_interferences(
    body, actions, effective, types, 0, actual,
  )
  cl_reader_row_instrumented(
    body,
    actions,
    effective,
    types,
    0,
    counted,
    bool_rows=Some(work),
  )
  for source in 0..<4 {
    for dest in 0..<4 {
      assert_eq(cl_bit_matrix_get(actual, source, dest), source != dest)
      assert_eq(
        cl_bit_matrix_get(counted, source, dest),
        cl_bit_matrix_get(actual, source, dest),
      )
    }
  }
  assert_eq(body, before_body)
  assert_eq(effective, before_effective)
  assert_eq(types, before_types)
  // The copied probe counts its one completed Array::make<Bool> call.
  // Normal matrices and frozen behavior are checked above. A production-only
  // cost regression needs a new source binding and compiled resource check;
  // this copied probe alone cannot detect that regression.
  assert_eq(work, [1])
}

///|
// Intentionally invalid private action: the public collector already filters
// invalid local indices. Preserve the old Get-array bounds rejection anyway.
test "panic coalesce reader row retains negative private Get rejection" {
  let actions = [
    { kind: CLActionKind::Get, local_idx: -1, source: CLValueSource::Unique, },
  ]
  cl_add_linear_source_write_dest_read_interferences(
    [],
    actions,
    [true],
    [@lib.ValType::i32()],
    0,
    CLBitMatrix::new(1),
  )
}

///|
// Intentionally invalid private action, not a newly supported input.
test "panic coalesce reader row retains equal-length private Get rejection" {
  let actions = [
    { kind: CLActionKind::Get, local_idx: 1, source: CLValueSource::Unique, },
  ]
  cl_add_linear_source_write_dest_read_interferences(
    [],
    actions,
    [true],
    [@lib.ValType::i32()],
    0,
    CLBitMatrix::new(1),
  )
}
