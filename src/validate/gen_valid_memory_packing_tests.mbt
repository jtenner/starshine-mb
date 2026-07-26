///|
fn gen_valid_memory_packing_test_has_profitable_zero_run(bytes : Bytes) -> Bool {
  let mut run = 0
  for byte in bytes {
    if byte == 0 {
      run += 1
      if run > 8 {
        return true
      }
    } else {
      run = 0
    }
  }
  false
}

///|
fn gen_valid_memory_packing_test_has_trigger(mod_ : Module) -> Bool {
  match mod_.data_sec {
    Some(DataSec(datas)) =>
      for data in datas {
        let Data(_, bytes) = data
        if gen_valid_memory_packing_test_has_profitable_zero_run(bytes) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_memory_packing_test_has_active_data(mod_ : Module) -> Bool {
  match mod_.data_sec {
    Some(DataSec(datas)) =>
      for data in datas {
        if data is Data(Active(_, _), _) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_memory_packing_test_instrs_have_memory_init(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      MemoryInit(_, _) => return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_memory_packing_test_instrs_have_memory_init(body) {
          return true
        }
      Try(_, Expr(body), catches, _) => {
        if gen_valid_memory_packing_test_instrs_have_memory_init(body) {
          return true
        }
        for catch_ in catches {
          let Expr(catch_body) = match catch_ {
            LegacyCatch(_, body) | LegacyCatchAll(body) => body
          }
          if gen_valid_memory_packing_test_instrs_have_memory_init(catch_body) {
            return true
          }
        }
      }
      If(_, then_body, else_body) => {
        if gen_valid_memory_packing_test_instrs_have_memory_init(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if gen_valid_memory_packing_test_instrs_have_memory_init(body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_memory_packing_test_has_memory_init(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(body)) = func
        if gen_valid_memory_packing_test_instrs_have_memory_init(body) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_memory_packing_test_instrs_have_legacy_try(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Try(_, _, _, _) => return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_memory_packing_test_instrs_have_legacy_try(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_memory_packing_test_instrs_have_legacy_try(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if gen_valid_memory_packing_test_instrs_have_legacy_try(body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_memory_packing_test_has_legacy_try(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(body)) = func
        if gen_valid_memory_packing_test_instrs_have_legacy_try(body) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
test "memory-packing GenValid aggregate resolves every owned family" {
  @debug.assert_eq(
    gen_valid_profile_name(MemoryPackingAllProfile),
    "memory-packing-all",
  )
  assert_true(gen_valid_profile_is_composite(MemoryPackingAllProfile))
  let members = gen_valid_profile_members(MemoryPackingAllProfile)
  @debug.assert_eq(members.length(), 3)
  assert_true(
    members.contains(GenValidProfileMember::new(MemoryPackingActiveProfile, 3)),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(MemoryPackingPassiveProfile, 3)),
  )
  assert_true(
    members.contains(
      GenValidProfileMember::new(MemoryPackingLegacyEhProfile, 2),
    ),
  )
  for
    name in ["memory-packing", "memory-packing-closeout", "memory-packing-all"] {
    match gen_valid_profile_by_name(name) {
      Ok(profile) => @debug.assert_eq(profile, MemoryPackingAllProfile)
      Err(msg) => fail(msg)
    }
  }
  assert_true(
    gen_valid_profile_members(RandomAllProfilesProfile).contains(
      GenValidProfileMember::new(MemoryPackingAllProfile, 1),
    ),
  )
}

///|
test "memory-packing GenValid leaves emit valid optimization triggers" {
  let profiles = [
    MemoryPackingActiveProfile,
    MemoryPackingPassiveProfile,
    MemoryPackingLegacyEhProfile,
  ]
  for i = 0; i < profiles.length(); i = i + 1 {
    let generated = match
      gen_valid_module_result_from_seed(
        0x4D5000UL + i.to_uint64(),
        GenValidConfig::for_profile(profiles[i]),
      ) {
      Ok(value) => value
      Err(failure) =>
        fail(
          "profile \{gen_valid_profile_name(profiles[i])}: \{failure.validation_error_message}",
        )
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    assert_true(
      gen_valid_memory_packing_test_has_trigger(generated.wasm_module),
      msg="profile \{gen_valid_profile_name(profiles[i])} must contain a profitable zero run",
    )
    match profiles[i] {
      MemoryPackingActiveProfile => {
        assert_true(
          gen_valid_memory_packing_test_has_active_data(generated.wasm_module),
        )
        assert_false(
          gen_valid_memory_packing_test_has_memory_init(generated.wasm_module),
        )
        assert_false(
          gen_valid_memory_packing_test_has_legacy_try(generated.wasm_module),
        )
      }
      MemoryPackingPassiveProfile => {
        assert_false(
          gen_valid_memory_packing_test_has_active_data(generated.wasm_module),
        )
        assert_true(
          gen_valid_memory_packing_test_has_memory_init(generated.wasm_module),
        )
        assert_false(
          gen_valid_memory_packing_test_has_legacy_try(generated.wasm_module),
        )
      }
      MemoryPackingLegacyEhProfile => {
        assert_false(
          gen_valid_memory_packing_test_has_active_data(generated.wasm_module),
        )
        assert_true(
          gen_valid_memory_packing_test_has_memory_init(generated.wasm_module),
        )
        assert_true(
          gen_valid_memory_packing_test_has_legacy_try(generated.wasm_module),
        )
      }
      _ => fail("unexpected memory-packing leaf profile")
    }
  }
}
