///|
fn gen_valid_h2l_owner_test_profile() -> GenValidProfile raise {
  match gen_valid_profile_by_name("heap2local-owner-updates") {
    Ok(profile) => profile
    Err(message) => fail(message)
  }
}

///|
fn gen_valid_h2l_owner_test_fields(
  body : Array[Instruction],
) -> Array[UInt32] raise {
  let fields : Array[UInt32] = []
  for index = 0; index < body.length(); index = index + 1 {
    match body[index] {
      StructGet(type_idx, U32(field)) => {
        @debug.assert_eq(type_idx, TypeIdx::new(0U))
        assert_true(index > 0)
        @debug.assert_eq(
          body[index - 1],
          Instruction::local_get(LocalIdx::new(3U)),
        )
        fields.push(field)
      }
      _ => ()
    }
  }
  @debug.assert_eq(
    body[body.length() - 1],
    Instruction::struct_new(TypeIdx::new(0U)),
  )
  fields
}

///|
test "heap2local owner updates profile is a replayable aggregate leaf" {
  let profile = gen_valid_h2l_owner_test_profile()
  @debug.assert_eq(gen_valid_profile_name(profile), "heap2local-owner-updates")
  assert_true(gen_valid_profile_names().contains("heap2local-owner-updates"))
  assert_true(!gen_valid_profile_is_composite(profile))
  assert_true(
    gen_valid_profile_members(Heap2LocalAllProfile).any(fn(member) {
      member.profile == profile
    }),
    msg="heap2local-all must include the owner-update correctness family",
  )
}

///|
test "heap2local owner updates generate previous-owner reads before publication" {
  let config = GenValidConfig::for_profile(gen_valid_h2l_owner_test_profile())
  // Three seeds cover swaps, three-field cycles, and a constant first operand
  // followed by reads of the previous owner's first and second fields.
  for seed in [0x5eedUL, 0x5eeeUL, 0x5eefUL] {
    let generated = match gen_valid_module_result_from_seed(seed, config) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    @debug.assert_eq(generated.config_label, "heap2local-owner-updates")
    assert_true(validate_module(generated.wasm_module) is Ok(_))
    assert_true(generated.facts.has_gc_constructors)
    assert_true(generated.facts.has_gc_accessors)
    let replay = match gen_valid_module_result_from_seed(seed, config) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    @debug.assert_eq(generated.wasm_module, replay.wasm_module)
    let mod_ = generated.wasm_module
    match mod_.type_sec.unwrap().0[1] {
      SingleRecType(CompTypeSubType(_, FuncCompType(params, results))) => {
        @debug.assert_eq(params, [
          ValType::i32(),
          ValType::i32(),
          ValType::i32(),
        ])
        @debug.assert_eq(results, [
          ValType::i32(),
          ValType::i32(),
          ValType::i32(),
        ])
      }
      _ => fail("expected three numeric branch parameters and observations")
    }
    let Func(locals, Expr(body)) = gen_valid_test_first_func(mod_)
    @debug.assert_eq(locals.length(), 1)
    @debug.assert_eq(
      locals.get(0),
      ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::new(0U)))),
    )
    let mut epochs = 0
    for index = 0; index < body.length(); index = index + 1 {
      match body[index] {
        If(_, yes, Some(no)) => {
          assert_true(
            yes != no,
            msg="each branch parameter must affect numeric observations",
          )
          assert_true(index > 0 && index + 1 < body.length())
          @debug.assert_eq(
            body[index - 1],
            Instruction::local_get(LocalIdx::new(epochs.to_uint())),
          )
          @debug.assert_eq(
            body[index + 1],
            Instruction::local_set(LocalIdx::new(3U)),
          )
          let expected : Array[UInt32] = if epochs == 0 {
            []
          } else if epochs == 1 {
            match seed % 3UL {
              0UL => [1U, 0U, 2U]
              1UL => [1U, 2U, 0U]
              _ => [0U, 1U]
            }
          } else {
            [2U, 0U, 1U]
          }
          @debug.assert_eq(gen_valid_h2l_owner_test_fields(yes), expected)
          @debug.assert_eq(gen_valid_h2l_owner_test_fields(no), expected)
          epochs += 1
        }
        _ => ()
      }
    }
    @debug.assert_eq(epochs, 3)
    let tail = body.length() - 6
    for field = 0; field < 3; field = field + 1 {
      @debug.assert_eq(
        body[tail + field * 2],
        Instruction::local_get(LocalIdx::new(3U)),
      )
      @debug.assert_eq(
        body[tail + field * 2 + 1],
        Instruction::struct_get(TypeIdx::new(0U), U32::new(field.to_uint())),
      )
    }
    assert_true(
      mod_.export_sec is Some(ExportSec([Export(_, FuncExternIdx(_))])),
    )
  }
}
