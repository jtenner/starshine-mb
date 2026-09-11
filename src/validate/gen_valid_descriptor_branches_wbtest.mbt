///|
test "Binaryen 132 descriptor GenValid covers branch polarity exactness and bottom operands" {
  let profile = match
    gen_valid_profile_by_name("binaryen132-descriptor-branches") {
    Ok(profile) => profile
    Err(err) => fail(err)
  }
  let seen = Array::make(8, false)
  for seed = 0UL; seed < 32UL; seed = seed + 1UL {
    let generated = match
      gen_valid_module_from_seed(seed, GenValidConfig::for_profile(profile)) {
      Ok(value) => value.wasm_module
      Err(_) => fail("descriptor generation failed")
    }
    match validate_module(generated) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    let Func(_, Expr(body)) = generated.code_sec.unwrap().0[0]
    let inner = match body[0] {
      Block(_, Expr(inner)) => inner
      _ => fail("descriptor branch block")
    }
    let mut found = false
    for instr in inner {
      let (polarity, source, target) = match instr {
        BrOnCastDescEq(_, source, target) => (0, source, target)
        BrOnCastDescEqFail(_, source, target) => (1, source, target)
        _ => continue
      }
      assert_true(source.is_nullable())
      let key = polarity +
        (if target.is_exact() { 2 } else { 0 }) +
        (if target.is_nullable() { 4 } else { 0 })
      seen[key] = true
      found = true
    }
    assert_true(found)
  }
  assert_true(seen.iter().all(fn(value) { value }))
}

///|
test "descriptor GenValid exercises nonnullable locals fed by bottom descriptors" {
  let profile = gen_valid_profile_by_name("binaryen132-descriptor-branches").unwrap()
  let mut refinements = 0
  for seed = 0UL; seed < 64UL; seed = seed + 1UL {
    let module_ = gen_valid_module_from_seed(
        seed,
        GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    let Func(locals, Expr(body)) = module_.code_sec.unwrap().0[0]
    if locals.length() == 1 {
      refinements += 1
      assert_true(
        locals.at(0) is Some(RefTypeValType(ref_type)) &&
        !ref_type.is_nullable(),
      )
      let inner = match body[0] {
        Block(_, Expr(inner)) => inner
        _ => fail("expected descriptor control result")
      }
      assert_true(inner.contains(Instruction::local_set(LocalIdx::new(2U))))
      assert_true(inner.contains(Instruction::unreachable_()))
      assert_true(validate_module(module_) is Ok(_))
    }
  }
  assert_eq(refinements, 32)
}

///|
test "descriptor GenValid includes observable writes around nested branch targets" {
  let config = GenValidConfig::for_profile(Binaryen132DescriptorBranchesProfile)
  for seed in [64UL, 65UL, 66UL, 67UL] {
    let mod_ = gen_valid_module_from_seed(seed, config).unwrap().wasm_module
    assert_true(validate_module(mod_) is Ok(_))
    assert_true(mod_.global_sec is Some(_))
    let Func(_, Expr(body)) = mod_.code_sec.unwrap().0[0]
    let work = [body]
    let mut writes = 0
    let mut outer_branches = 0
    while !work.is_empty() {
      for instr in work.pop().unwrap() {
        match instr {
          Instruction::GlobalSet(_) => writes += 1
          Instruction::BrOnCastDescEq(LabelIdx(1U), _, _)
          | Instruction::BrOnCastDescEqFail(LabelIdx(1U), _, _) =>
            outer_branches += 1
          Instruction::Block(_, Expr(body)) => work.push(body)
          _ => ()
        }
      }
    }
    assert_eq(writes, 2)
    assert_eq(outer_branches, 1)
  }
}
