///|
// Frozen finalization order: reject the reconstructed module before either
// type cleanup, and let the DFE wrapper validate its speculative replacement.
fn dae2_final_validation_reference(
  candidate : @lib.Module,
) -> Result[@lib.Module, String] {
  match @validate.validate_module(candidate) {
    Ok(_) =>
      Ok(
        dfe_cleanup_simple_type_encoding(
          dae_prune_unused_simple_func_types(candidate, preserve_names=true),
        ),
      )
    Err(error) => Err("dae2: invalid rewritten module: \{error}")
  }
}

///|
fn dae2_final_validation_fixture() -> @lib.Module {
  let input = pass_test_module_from_wat(
    "(module (type (func (result i32))) (type (func (result i32))) (func (type 0) (result i32) i32.const 7) (func (type 1) (result i32) i32.const 9))",
  )
  input.without_name_sec()
}

///|
test "DAE2 final validation checks active exact cleaned output once without mutating its source" {
  let input = dae2_final_validation_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let expected = dae2_final_validation_reference(input).unwrap()
  let calls = [0]
  let actual = dae2_finalize_candidate(input, validation_calls=Some(calls)).unwrap()
  assert_eq(calls[0], 1)
  assert_true(
    actual.type_sec.unwrap().0.length() < input.type_sec.unwrap().0.length(),
  )
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  @validate.validate_module(actual).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(actual.code_sec.unwrap().0, input.code_sec.unwrap().0)
}

///|
test "DAE2 final validation rejects intentionally invalid unused exact abstract declarations before pruning" {
  let input = dae2_final_validation_fixture()
  let invalid_ref = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::abs(@lib.AbsHeapType::func()),
      exact=true,
    ),
  )
  let groups = input.type_sec.unwrap().0.copy()
  groups.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([invalid_ref], [])),
    ),
  )
  let input = input.with_type_sec(@lib.TypeSec::new(groups))
  let expected = dae2_final_validation_reference(input)
  assert_true(expected is Err(_))
  // The declaration is unused and would disappear if validation came later.
  assert_true(
    @validate.validate_module(dae_prune_unused_simple_func_types(input))
    is Ok(_),
  )
  assert_eq(dae2_finalize_candidate(input), expected)
  assert_eq(input.type_sec.unwrap().0.length(), 3)
}

///|
test "DAE2 final validation retains first body and name errors on intentionally invalid named modules" {
  let input = dae2_final_validation_fixture()
  let names = @lib.NameSec::new(
    type_names=Some(
      @lib.NameMap::new([
        @lib.NameAssoc::new(99U, @lib.Name::from_string("missing")),
      ]),
    ),
  )
  let named = input.with_name_sec(names)
  let expected = dae2_final_validation_reference(named)
  assert_true(expected is Err(_))
  // Both cleanup stages can erase this invalid original name index.
  assert_true(
    @validate.validate_module(
      dfe_cleanup_simple_type_encoding(
        dae_prune_unused_simple_func_types(named, preserve_names=true),
      ),
    )
    is Ok(_),
  )
  assert_eq(dae2_finalize_candidate(named), expected)
  let bodies = named.code_sec.unwrap().0.copy()
  bodies[0] = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let both_invalid = named.with_code_sec(@lib.CodeSec::new(bodies))
  let body_error = dae2_final_validation_reference(both_invalid)
  assert_true(body_error is Err(_))
  assert_true(body_error != expected)
  assert_eq(dae2_finalize_candidate(both_invalid), body_error)
}

///|
test "DFE public encoding cleanup preserves validation and encoding rollback for intentionally invalid input" {
  let input = dae2_final_validation_fixture()
  let bodies = input.code_sec.unwrap().0.copy()
  bodies[0] = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let invalid_body = input.with_code_sec(@lib.CodeSec::new(bodies))
  assert_true(
    physical_equal(dfe_cleanup_simple_type_encoding(invalid_body), invalid_body),
  )
  let invalid_custom = input.with_custom_secs([
    @lib.CustomSec::new(@lib.Name::from_string("name"), b""),
  ])
  assert_true(
    physical_equal(
      dfe_cleanup_simple_type_encoding(invalid_custom),
      invalid_custom,
    ),
  )
}

///|
test "DAE2 final validation preserves original type-index diagnostics after speculative remapping" {
  // This intentionally invalid body lacks the call_indirect selector. Type
  // cleanup remaps type 1 to 0, but the error must describe the original body.
  let input = pass_test_module_from_wat(
    "(module (type (func (result i32))) (type (func (result i32))) (table 1 funcref) (func (type 0) (result i32) i32.const 7) (func (type 1) (result i32) i32.const 9))",
  ).without_name_sec()
  let bodies = input.code_sec.unwrap().0.copy()
  bodies[0] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::call_indirect(
        @lib.TypeIdx::new(1U),
        @lib.TableIdx::new(0U),
      ),
    ]),
  )
  let input = input.with_code_sec(@lib.CodeSec::new(bodies))
  let expected = dae2_final_validation_reference(input)
  assert_true(expected is Err(_))
  assert_eq(dae2_finalize_candidate(input), expected)
}

///|
test "DAE2 final validation preserves live distinct signatures and unchanged ownership" {
  let input = dae2_final_validation_live_types_fixture(4)
  let saved = @binary.encode_module(input).unwrap()
  let calls = [0]
  let actual = dae2_finalize_candidate(input, validation_calls=Some(calls)).unwrap()
  assert_true(physical_equal(actual, input))
  assert_eq(calls[0], 1)
  assert_eq(actual.type_sec.unwrap().0.length(), 4)
  assert_eq(actual.func_sec.unwrap().0, input.func_sec.unwrap().0)
  assert_eq(@binary.encode_module(actual).unwrap(), saved)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 final validation compacts named signatures while retaining exact names and input ownership" {
  let input = dae2_final_validation_fixture().with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("named")),
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("first")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("second")),
        ]),
      ),
      type_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("signature")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("duplicate")),
        ]),
      ),
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let expected = dae2_final_validation_reference(input).unwrap()
  let actual = dae2_finalize_candidate(input).unwrap()
  @validate.validate_module(actual).unwrap()
  assert_eq(actual.type_sec.unwrap().0.length(), 1)
  assert_eq(actual.name_sec, expected.name_sec)
  assert_eq(
    actual.name_sec.unwrap().func_names,
    input.name_sec.unwrap().func_names,
  )
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 final validation rejects intentionally invalid field names erased by unused type cleanup" {
  let input = dae2_final_validation_fixture()
  let types = input.type_sec.unwrap().0.copy()
  types.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i64()], [])),
    ),
  )
  let input = input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_name_sec(
      @lib.NameSec::new(
        field_names=Some(
          @lib.IndirectNameMap::new([
            @lib.IndirectNameAssoc::new(2U, @lib.NameMap::new([])),
          ]),
        ),
      ),
    )
  // Function types cannot own field names, even when the field-name row is empty.
  let expected = dae2_final_validation_reference(input)
  assert_true(expected is Err(_))
  assert_true(
    @validate.validate_module(
      dae_prune_unused_simple_func_types(input, preserve_names=true),
    )
    is Ok(_),
  )
  assert_eq(dae2_finalize_candidate(input), expected)
}
