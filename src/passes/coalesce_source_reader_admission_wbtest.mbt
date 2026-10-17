///|
fn cl_reader_admission_dense_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (func (export \"run\") (result i32) (local i32 i32 i32 i32) i32.const 7 local.set 0 local.get 0 local.set 1 i32.const 9 local.set 0 local.get 2 drop local.get 3 drop local.get 1))",
  )
}

///|
fn cl_reader_admission_sparse_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (func (export \"run\") (result i32) (local i32 i32 i32 i32) i32.const 7 local.set 0 local.get 0 local.set 1 i32.const 9 local.set 0 local.get 1))",
  )
}

///|
fn cl_reader_admission_mixed_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (func (export \"run\") (result i32) (local i32 i32 i64 i64) i32.const 7 local.set 0 local.get 0 local.set 1 i32.const 9 local.set 0 i64.const 1 local.set 2 local.get 2 local.set 3 i64.const 2 local.set 2 local.get 3 drop local.get 1))",
  )
}

///|
fn cl_reader_admission_reference_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (import \"m\" \"f\" (func)) (elem declare func 0) (func (export \"run\") (result funcref) (local funcref (ref null func) externref anyref) ref.func 0 local.set 0 local.get 0 local.set 1 ref.null func local.set 0 local.get 2 drop local.get 3 drop local.get 1))",
  )
}

///|
// Return the actual index constructor count only after all behavior and source
// ownership checks. The optional production counter has no default storage.
fn cl_reader_admission_check(
  input : @lib.Module,
  expected_readers : Array[Bool],
  expected_candidate_visits : Int32,
  scalar_result : Int32?,
  reference_groups : Bool,
) -> Int32 raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let original = input.code_sec.unwrap().0[0]
  let @lib.Func(locals, @lib.Expr(body)) = original
  let saved_body = body.copy()
  let types = cl_all_local_types([], locals)
  assert_eq(types.length(), 4)
  let saved_types = types.copy()
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, types.length())
  let saved_actions = actions.copy()
  let effective = Array::make(actions.length(), true)
  let saved_effective = effective.copy()
  let (_, readers) = cl_source_write_dest_read_active_flags(
    actions,
    effective,
    types.length(),
  )
  assert_eq(readers, expected_readers)
  if reference_groups {
    for type_ in types {
      assert_eq(cl_source_reader_type_group(type_), 5)
    }
    assert_eq(types[0], types[1])
    assert_false(types[0] == types[2])
  }
  let expected = CLBitMatrix::new(4)
  let actual = CLBitMatrix::new(4)
  cl_add_source_write_dest_read_interferences_reference(
    body, actions, effective, types, 0, expected,
  )
  let builds = [0]
  let visits = [0]
  cl_add_source_write_dest_read_interferences(
    body,
    actions,
    effective,
    types,
    0,
    actual,
    candidate_visits=Some(visits),
    index_builds=Some(builds),
  )
  // Check all sixteen bits, including symmetric and diagonal contracts.
  for source in 0..<4 {
    for dest in 0..<4 {
      assert_eq(
        cl_bit_matrix_get(actual, source, dest),
        cl_bit_matrix_get(expected, source, dest),
      )
    }
  }
  assert_true(cl_bit_matrix_get(actual, 0, 1))
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "coalesce-locals",
  ]).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec.unwrap().0.length(), 1)
  let @lib.Func(next_locals, @lib.Expr(next_body)) = output.code_sec.unwrap().0[0]
  assert_true(next_locals.length() <= locals.length())
  match scalar_result {
    Some(value) => {
      // Existing bounded evaluator: this checks the observable copied value,
      // independently of matrix construction and local numbering.
      assert_eq(cl_dew_execute_reduced_i32(original, []), value)
      assert_eq(
        cl_dew_execute_reduced_i32(output.code_sec.unwrap().0[0], []),
        value,
      )
    }
    None => ()
  }
  if reference_groups {
    assert_true(
      next_body.any(fn(instr) {
        match instr {
          @lib.RefFunc(@lib.FuncIdx(raw)) => raw == 0U
          _ => false
        }
      }),
    )
  }
  assert_eq(types, saved_types)
  for local in 0..<types.length() {
    assert_true(physical_equal(types[local], saved_types[local]))
  }
  assert_eq(effective, saved_effective)
  assert_eq(actions.length(), saved_actions.length())
  for index in 0..<actions.length() {
    assert_true(physical_equal(actions[index], saved_actions[index]))
  }
  assert_eq(body, saved_body)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(visits[0], expected_candidate_visits)
  builds[0]
}

///|
test "coalesce dense four-i32 readers keep copied result and exact matrix without an unfiltering index" {
  let builds = cl_reader_admission_check(
    cl_reader_admission_dense_fixture(),
    [true, true, true, true],
    8,
    Some(7),
    false,
  )
  assert_eq(builds, 0)
}

///|
test "coalesce mixed dense readers retain the filtering index and exact hazards" {
  let builds = cl_reader_admission_check(
    cl_reader_admission_mixed_fixture(),
    [true, true, true, true],
    8,
    None,
    false,
  )
  assert_eq(builds, 1)
}

///|
test "coalesce sparse single-group readers retain the filtering index and copied result" {
  let builds = cl_reader_admission_check(
    cl_reader_admission_sparse_fixture(),
    [true, true, false, false],
    4,
    Some(7),
    false,
  )
  assert_eq(builds, 1)
}

///|
test "coalesce dense distinct reference types share one coarse group and need no unfiltering index" {
  let builds = cl_reader_admission_check(
    cl_reader_admission_reference_fixture(),
    [true, true, true, true],
    8,
    None,
    true,
  )
  assert_eq(builds, 0)
}
