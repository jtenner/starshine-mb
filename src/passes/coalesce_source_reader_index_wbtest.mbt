///|
fn cl_reader_index_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #|(module
      #| (func (export "run") (param i32)
      #|  (local i32 i32 i64 i64 f32 f32 f64 v128 i32)
      #|  i32.const 1 local.set 1 local.get 1 local.set 2
      #|  i32.const 2 local.set 1 local.get 2 drop
      #|  i64.const 1 local.set 3 local.get 3 local.set 4
      #|  i64.const 2 local.set 3 local.get 4 drop
      #|  f32.const 1 local.set 5 local.get 5 local.set 6
      #|  f32.const 2 local.set 5 local.get 6 drop
      #|  local.get 7 drop local.get 8 drop))
    ),
  )
}

///|
test "coalesce reader index reduces real candidate checks with exact interference and valid rewrite output" {
  let input = cl_reader_index_fixture()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let types = cl_all_local_types([@lib.ValType::i32()], locals)
  assert_eq(types.length(), 10)
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, types.length())
  let effective = Array::make(actions.length(), true)
  let reference = CLBitMatrix::new(types.length())
  let actual = CLBitMatrix::new(types.length())
  let old_visits = [0]
  let visits = [0]
  cl_add_source_write_dest_read_interferences(
    body,
    actions,
    effective,
    types,
    1,
    reference,
    candidate_visits=Some(old_visits),
    indexed_readers=false,
  )
  cl_add_source_write_dest_read_interferences(
    body,
    actions,
    effective,
    types,
    1,
    actual,
    candidate_visits=Some(visits),
  )
  for source in 0..<types.length() {
    for dest in 0..<types.length() {
      assert_eq(
        cl_bit_matrix_get(actual, source, dest),
        cl_bit_matrix_get(reference, source, dest),
      )
    }
  }
  assert_true(cl_bit_matrix_get(actual, 1, 2))
  assert_true(cl_bit_matrix_get(actual, 3, 4))
  assert_true(cl_bit_matrix_get(actual, 5, 6))
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "coalesce-locals",
  ]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(next_locals, _) = output.code_sec.unwrap().0[0]
  assert_true(next_locals.length() < locals.length())
  assert_true(@binary.encode_module(output).unwrap().length() <= saved.length())
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(old_visits[0], 60)
  assert_eq(visits[0], 12)
}

///|
test "coalesce reader index preserves destination order time filters and existing interferences" {
  let types = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::f32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
  ]
  let readers = [true, true, true, true, true, false, true, true]
  let first_write = [2, 2, 2, 2, 2, 2, 2, 2]
  let latest_get = [5, 5, 5, 2, 5, 5, 5, 5]
  let matrix = CLBitMatrix::new(types.length())
  cl_bit_matrix_set_symmetric(matrix, 2, 6, true)
  let saved_types = types.copy()
  let saved_readers = readers.copy()
  let saved_first_write = first_write.copy()
  let saved_latest_get = latest_get.copy()
  let index = cl_source_hazard_reader_index(types, readers)
  let expected = cl_source_write_dest_read_candidate_dests(
    2, readers, types, matrix, first_write, latest_get,
  )
  let actual = cl_source_write_dest_read_candidate_dests_indexed(
    2, index, matrix, first_write, latest_get,
  )
  assert_eq(expected, [0, 7])
  assert_eq(actual, expected)
  assert_eq(types, saved_types)
  for i in 0..<types.length() {
    assert_true(physical_equal(types[i], saved_types[i]))
  }
  assert_eq(readers, saved_readers)
  assert_eq(first_write, saved_first_write)
  assert_eq(latest_get, saved_latest_get)
  assert_true(cl_bit_matrix_get(matrix, 2, 6))
  assert_false(cl_bit_matrix_get(matrix, 2, 7))
}

///|
test "coalesce reader index uses exact reference equality including shorthand aliases nullability exactness and indexed types" {
  let heap = @lib.HeapType::abs(@lib.AbsHeapType::func())
  let shorthand = @lib.ValType::ref_type(
    @lib.RefType::abs(@lib.AbsHeapType::func()),
  )
  let expanded = @lib.ValType::ref_type(@lib.RefType::new(true, heap))
  assert_eq(shorthand, expanded)
  let types = [
    shorthand,
    expanded,
    @lib.ValType::ref_type(@lib.RefType::new(false, heap)),
    @lib.ValType::ref_type(@lib.RefType::new(true, heap, exact=true)),
    @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U))),
    @lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
    shorthand,
    expanded,
    @lib.ValType::ref_null(@lib.HeapType::shared_abs(@lib.AbsHeapType::func())),
  ]
  let readers = Array::make(types.length(), true)
  let first_write = Array::make(types.length(), 0)
  let latest_get = Array::make(types.length(), 1)
  let matrix = CLBitMatrix::new(types.length())
  let index = cl_source_hazard_reader_index(types, readers)
  for source in 0..<types.length() {
    let reference = cl_source_write_dest_read_candidate_dests(
      source, readers, types, matrix, first_write, latest_get,
    )
    let actual = cl_source_write_dest_read_candidate_dests_indexed(
      source, index, matrix, first_write, latest_get,
    )
    assert_eq(actual, reference)
    if source == 0 {
      assert_eq(actual, [1, 6, 7])
    }
  }
}

///|
test "coalesce reader index builds once for distinct reference types and scans only readers with the original exact filter" {
  let types = Array::makei(24, fn(index) {
    @lib.ValType::ref_null(
      @lib.HeapType::new(@lib.TypeIdx::new(index.to_uint())),
    )
  })
  // Only two readers share the writer's exact type. A different reference
  // reader still enters the coarse bucket and must fail the original Eq test.
  types[7] = types[0]
  types[19] = types[0]
  let readers = Array::make(types.length(), false)
  readers[7] = true
  readers[11] = true
  readers[19] = true
  let first_write = Array::make(types.length(), -1)
  first_write[0] = 0
  let latest_get = Array::make(types.length(), 1)
  let matrix = CLBitMatrix::new(types.length())
  let builds = [0]
  let index = cl_source_hazard_reader_index(
    types,
    readers,
    local_visits=Some(builds),
  )
  let old_visits = [0]
  let visits = [0]
  let reference = cl_source_write_dest_read_candidate_dests(
    0,
    readers,
    types,
    matrix,
    first_write,
    latest_get,
    candidate_visits=Some(old_visits),
  )
  let actual = cl_source_write_dest_read_candidate_dests_indexed(
    0,
    index,
    matrix,
    first_write,
    latest_get,
    candidate_visits=Some(visits),
  )
  assert_eq(reference, [7, 19])
  assert_eq(actual, reference)
  assert_eq(builds[0], types.length())
  assert_eq(old_visits[0], 24)
  assert_eq(visits[0], 3)
  assert_true(readers[11])
  assert_false(types[0] == types[11])
}
