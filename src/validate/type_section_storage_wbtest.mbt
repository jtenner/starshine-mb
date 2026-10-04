///|
// Frozen incremental boundary: independent environments for validation and
// publication of every group. Used to check scope and exact first errors.
fn typesec_storage_reference(
  section : TypeSec?,
  initial : Env,
) -> Result[Env, String] {
  let mut env = initial
  if section is Some(TypeSec(groups)) {
    for group in groups {
      let scoped = env_with_rectype(env, group)
      if Validate::validate(group, scoped) is Err(error) {
        return Err(error)
      }
      let normalized = normalize_rectype_for_global_env(
        group,
        env.global_types.length(),
      )
      env = env.append_rectype_types_with_scope(normalized, group)
    }
  }
  Ok(env)
}

///|
fn typesec_storage_section(count : Int, width : Int) -> TypeSec {
  TypeSec::new(
    Array::makei(count, fn(_) {
      let st = SubType::comp_type(
        CompType::func([ValType::i32()], [ValType::i64()]),
      )
      if width == 1 {
        RecType::new(st)
      } else {
        RecType::group(Array::make(width, st))
      }
    }),
  )
}

///|
test "type section storage preserves prefix ownership and original recursive scope" {
  let prefix = SubType::new(false, [], CompType::struct_([]))
  let initial = Env::new().with_rectype(RecType::new(prefix))
  let globals = initial.global_types.copy()
  let scopes = initial.rec_stack.copy()
  let group = RecType::group([
    SubType::new(false, [], CompType::struct_([])),
    SubType::new(true, [TypeIdx::rec(0U)], CompType::struct_([])),
  ])
  let described = SubType::comp_type(
    CompType::struct_([]),
    metadata=TypeMetadata::new(descriptor=Some(TypeIdx::rec(1U))),
  )
  let descriptor = SubType::comp_type(
    CompType::struct_([]),
    metadata=TypeMetadata::new(describes=Some(TypeIdx::rec(0U))),
  )
  let section = Some(
    TypeSec::new([
      group,
      RecType::new(SubType::comp_type(CompType::func([], []))),
      RecType::new(SubType::comp_type(CompType::cont(TypeIdx::new(3U)))),
      RecType::group([described, descriptor]),
    ]),
  )
  let actual = validate_typesec(section, initial).unwrap()
  let expected = typesec_storage_reference(section, initial).unwrap()
  assert_eq(actual.global_types, expected.global_types)
  assert_eq(actual.rec_stack, expected.rec_stack)
  assert_eq(actual.global_types[2].super_types(), [TypeIdx::new(1U)])
  assert_eq(actual.global_types[5].descriptor_type(), Some(TypeIdx::new(6U)))
  assert_eq(actual.global_types[6].describes_type(), Some(TypeIdx::new(5U)))
  assert_eq(initial.global_types, globals)
  assert_eq(initial.rec_stack, scopes)
  let saved = actual.global_types.copy()
  ignore(validate_typesec(Some(typesec_storage_section(2, 1)), actual).unwrap())
  assert_eq(actual.global_types, saved)
}

///|
test "type section storage rejects later invalid groups without publishing a prefix" {
  let initial = validate_typesec(
    Some(typesec_storage_section(1, 1)),
    Env::new(),
  ).unwrap()
  let globals = initial.global_types.copy()
  let scopes = initial.rec_stack.copy()
  let section = Some(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], []))),
      RecType::new(SubType::comp_type(CompType::cont(TypeIdx::new(99U)))),
      RecType::new(SubType::comp_type(CompType::cont(TypeIdx::rec(9U)))),
    ]),
  )
  guard typesec_storage_reference(section, initial) is Err(expected) else {
    fail("invalid reference must fail")
  }
  guard validate_typesec(section, initial) is Err(actual) else {
    fail("invalid group must fail")
  }
  assert_eq(actual, expected)
  assert_eq(initial.global_types, globals)
  assert_eq(initial.rec_stack, scopes)
}

///|
test "type section storage exposes only the current recursive group" {
  let continuation = SubType::comp_type(CompType::cont(TypeIdx::new(1U)))
  let function = SubType::comp_type(CompType::func([], []))
  let separate = Some(
    TypeSec::new([RecType::new(continuation), RecType::new(function)]),
  )
  assert_true(validate_typesec(separate, Env::new()) is Err(_))
  let together = Some(TypeSec::new([RecType::group([continuation, function])]))
  let actual = validate_typesec(together, Env::new()).unwrap()
  let expected = typesec_storage_reference(together, Env::new()).unwrap()
  assert_eq(actual.global_types, expected.global_types)
  assert_eq(actual.rec_stack, expected.rec_stack)
}

///|
test "type section storage preserves absent and empty environment identity" {
  let initial = Env::new()
  assert_true(physical_equal(validate_typesec(None, initial).unwrap(), initial))
  assert_true(
    physical_equal(
      validate_typesec(Some(TypeSec::new([])), initial).unwrap(),
      initial,
    ),
  )
}
