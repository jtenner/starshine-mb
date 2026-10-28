///|
fn review_r1_20261025_ref(index : UInt32) -> ValType {
  ValType::ref_type(RefType::new(false, HeapType::new(TypeIdx::new(index))))
}

///|
fn review_r1_20261025_field(index : UInt32) -> FieldType {
  FieldType::new(
    StorageType::val_type(review_r1_20261025_ref(index)),
    Mut::const_(),
  )
}

///|
fn review_r1_20261025_identity_module(
  groups : Array[RecType],
  source : UInt32,
  target : UInt32,
  signature : UInt32,
) -> Module {
  groups.push(
    RecType::new(
      SubType::comp_type(
        CompType::func([review_r1_20261025_ref(source)], [
          review_r1_20261025_ref(target),
        ]),
      ),
    ),
  )
  Module::new()
  .with_type_sec(TypeSec::new(groups))
  .with_func_sec(FuncSec::new([TypeIdx::new(signature)]))
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::empty(),
        Expr::new([Instruction::local_get(LocalIdx::new(0U))]),
      ),
    ]),
  )
}

///|
test "review r1 validation accepts rec groups with equivalent external types" {
  let leaf = RecType::new(SubType::comp_type(CompType::struct_([])))
  let groups : Array[RecType] = [leaf, leaf]
  for (external, base) in [(0U, 2U), (1U, 4U)] {
    groups.push(
      RecType::group([
        SubType::comp_type(
          CompType::struct_([
            review_r1_20261025_field(external),
            review_r1_20261025_field(base + 1U),
          ]),
        ),
        SubType::comp_type(CompType::struct_([review_r1_20261025_field(base)])),
      ]),
    )
  }
  let module_ = review_r1_20261025_identity_module(groups, 2U, 4U, 6U)
  match validate_module(module_) {
    Ok(_) => ()
    Err(error) => fail(validation_error_message(error))
  }
}

///|
fn r1_07_groups(leaf1 : SubType, sibling1 : CompType) -> Array[RecType] {
  [
    RecType::new(SubType::comp_type(CompType::struct_([]))),
    RecType::new(leaf1),
    RecType::group([
      SubType::comp_type(
        CompType::struct_([
          review_r1_20261025_field(0U),
          review_r1_20261025_field(3U),
        ]),
      ),
      SubType::comp_type(CompType::struct_([review_r1_20261025_field(2U)])),
    ]),
    RecType::group([
      SubType::comp_type(
        CompType::struct_([
          review_r1_20261025_field(1U),
          review_r1_20261025_field(5U),
        ]),
      ),
      SubType::comp_type(sibling1),
    ]),
  ]
}

///|
test "r1 07 exact group identity accepts both offsets and directions" {
  let groups = r1_07_groups(
    SubType::comp_type(CompType::struct_([])),
    CompType::struct_([review_r1_20261025_field(4U)]),
  )
  let env = validate_typesec(Some(TypeSec::new(groups)), Env::new()).unwrap()
  for (a, b) in [(2U, 4U), (4U, 2U), (3U, 5U), (5U, 3U)] {
    assert_true(
      exact_heaptype_matches(
        HeapType::new(TypeIdx::new(a)),
        HeapType::new(TypeIdx::new(b)),
        env,
      ),
    )
  }
}

///|
test "r1 07 intentionally rejects unequal external leaves" {
  let groups = r1_07_groups(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Mut::const_()),
      ]),
    ),
    CompType::struct_([review_r1_20261025_field(4U)]),
  )
  let module_ = review_r1_20261025_identity_module(groups, 2U, 4U, 6U)
  match validate_module(module_) {
    Err(error) =>
      assert_true(
        validation_error_message(error).contains(
          "function body result type mismatch",
        ),
      )
    Ok(_) => fail("intentionally inequivalent result types must be rejected")
  }
}

///|
test "r1 07 intentionally rejects unequal sibling and recursive offset" {
  for
    sibling in [
      CompType::struct_([]),
      CompType::struct_([review_r1_20261025_field(5U)]),
    ] {
    let groups = r1_07_groups(
      SubType::comp_type(CompType::struct_([])),
      sibling,
    )
    let module_ = review_r1_20261025_identity_module(groups, 2U, 4U, 6U)
    match validate_module(module_) {
      Err(error) =>
        assert_true(
          validation_error_message(error).contains(
            "function body result type mismatch",
          ),
        )
      Ok(_) => fail("intentionally inequivalent result types must be rejected")
    }
  }
  let groups = r1_07_groups(
    SubType::comp_type(CompType::struct_([])),
    CompType::struct_([review_r1_20261025_field(4U)]),
  )
  let env = validate_typesec(Some(TypeSec::new(groups)), Env::new()).unwrap()
  assert_false(
    exact_heaptype_matches(
      HeapType::new(TypeIdx::new(2U)),
      HeapType::new(TypeIdx::new(5U)),
      env,
    ),
  )
}

///|
test "r1 07 accepts equivalent recursive external singleton types" {
  let groups = r1_07_groups(
    SubType::comp_type(CompType::struct_([review_r1_20261025_field(1U)])),
    CompType::struct_([review_r1_20261025_field(4U)]),
  )
  groups[0] = RecType::new(
    SubType::comp_type(CompType::struct_([review_r1_20261025_field(0U)])),
  )
  let module_ = review_r1_20261025_identity_module(groups, 2U, 4U, 6U)
  match validate_module(module_) {
    Ok(_) => ()
    Err(error) => fail(validation_error_message(error))
  }
}

///|
test "r1 07 intentionally rejects different group cardinality and disconnected siblings" {
  let empty = SubType::comp_type(CompType::struct_([]))
  let scalar = fn(value) {
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(value), Mut::const_()),
      ]),
    )
  }
  let env = validate_typesec(
    Some(
      TypeSec::new([
        RecType::group([empty, scalar(ValType::i32())]),
        RecType::group([empty, scalar(ValType::i64())]),
        RecType::new(empty),
      ]),
    ),
    Env::new(),
  ).unwrap()
  // Equal projected bodies do not erase other binders or group arity.
  for target in [2U, 4U] {
    assert_false(
      exact_heaptype_matches(
        HeapType::new(TypeIdx::new(0U)),
        HeapType::new(TypeIdx::new(target)),
        env,
      ),
    )
  }
}
