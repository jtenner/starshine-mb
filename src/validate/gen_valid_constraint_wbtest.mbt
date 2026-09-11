///|
test "constraint GenValid aggregate covers solver and post-release correctness families" {
  let aggregate = match gen_valid_profile_by_name("constraint-analysis") {
    Ok(profile) => profile
    Err(err) => fail(err)
  }
  assert_true(gen_valid_profile_is_composite(aggregate))
  let members = gen_valid_profile_members(aggregate)
  for
    name in [
      "constraint-integer", "constraint-joins", "constraint-loops", "constraint-tees",
      "constraint-wraparound", "constraint-i64", "constraint-logical", "constraint-references",
      "constraint-unreachable", "constraint-relations", "constraint-effects", "constraint-float-boundary",
    ] {
    let profile = match gen_valid_profile_by_name(name) {
      Ok(profile) => profile
      Err(err) => fail(err)
    }
    assert_true(members.any(fn(entry) { entry.profile == profile }))
    for seed in [0UL, 1UL, 0x5eedUL, 0xffffffffffffffffUL] {
      let generated = match
        gen_valid_module_result(
          @splitmix.new(seed~),
          GenValidConfig::for_profile(profile),
        ) {
        Ok(generated) => generated.wasm_module
        Err(err) => fail(err.validation_error_message)
      }
      match validate_module(generated) {
        Ok(_) => ()
        Err(err) => fail(validation_error_message(err))
      }
      match generated.code_sec {
        Some(CodeSec(funcs)) => assert_true(!funcs.is_empty())
        None => fail("missing constraint body")
      }
    }
  }
}

///|
fn constraint_gen_has_handler(body : Array[Instruction]) -> Bool {
  for instr in body {
    match instr {
      Instruction::TryTable(_, catches, _) if !catches.is_empty() => return true
      Instruction::Block(_, Expr(nested))
      | Instruction::Loop(_, Expr(nested)) =>
        if constraint_gen_has_handler(nested) {
          return true
        }
      Instruction::If(_, yes, no) => {
        if constraint_gen_has_handler(yes) {
          return true
        }
        if no is Some(no) && constraint_gen_has_handler(no) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
test "constraint effects generator includes handlers that bypass later local writes" {
  let profile = match gen_valid_profile_by_name("constraint-effects") {
    Ok(profile) => profile
    Err(err) => fail(err)
  }
  let mut handler_cases = 0
  for seed in [0UL, 1UL, 2UL, 3UL, 0x5eedUL, 0xffffffffffffffffUL] {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed~),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(generated) => generated.wasm_module
      Err(err) => fail(err.validation_error_message)
    }
    if generated.code_sec is Some(CodeSec(bodies)) {
      for body in bodies {
        let Func(_, Expr(body)) = body
        if constraint_gen_has_handler(body) {
          handler_cases += 1
        }
      }
    }
  }
  assert_true(handler_cases > 0)
}

///|
test "constraint effects generator covers calls held across conditional clobbers" {
  let mut found = false
  for seed = 0; seed < 24; seed = seed + 1 {
    let input = gen_valid_module_from_seed(
        seed.to_uint64(),
        GenValidConfig::for_profile(ConstraintEffectsProfile),
      ).unwrap().wasm_module
    if input.code_sec is Some(CodeSec(bodies)) && bodies.length() == 3 {
      let Func(_, Expr(body)) = bodies[2]
      found = found ||
        (
          body.contains(Instruction::call(FuncIdx::new(0U))) &&
          body.any(fn(op) { op is Instruction::If(_, _, _) })
        )
    }
  }
  assert_true(found)
}

///|
test "constraint loop GenValid includes multi-result control and local tees" {
  let input = gen_valid_module_from_seed(
      2UL,
      GenValidConfig::for_profile(ConstraintLoopsProfile),
    ).unwrap().wasm_module
  let types = input.type_sec.unwrap().0
  assert_true(
    types.any(fn(rec) {
      match rec {
        SingleRecType(CompTypeSubType(_, FuncCompType(_, results))) =>
          results.length() == 2
        _ => false
      }
    }),
  )
  match validate_module(input) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
}

///|
test "constraint loop GenValid includes values carried by stack parameters" {
  let input = gen_valid_module_from_seed(
      4UL,
      GenValidConfig::for_profile(ConstraintLoopsProfile),
    ).unwrap().wasm_module
  assert_true(
    input.type_sec.unwrap().0.any(fn(rec) {
      match rec {
        SingleRecType(CompTypeSubType(_, FuncCompType(params, results))) =>
          params.length() == 1 && results.is_empty()
        _ => false
      }
    }),
  )
  match validate_module(input) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
}

///|
fn constraint_gen_has_branch(body : Array[Instruction], form : Int) -> Bool {
  for instruction in body {
    match instruction {
      BrIf(_) if form == 1 => return true
      BrTable(_, _) if form == 2 => return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) =>
        if constraint_gen_has_branch(body, form) {
          return true
        }
      If(_, yes, no) => {
        if constraint_gen_has_branch(yes, form) {
          return true
        }
        if no is Some(no) && constraint_gen_has_branch(no, form) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
test "constraint parameter loop GenValid covers conditional and table backedges" {
  for entry in [(12UL, 1), (20UL, 2)] {
    let (seed, form) = entry
    let input = gen_valid_module_from_seed(
        seed,
        GenValidConfig::for_profile(ConstraintLoopsProfile),
      ).unwrap().wasm_module
    let Func(_, Expr(body)) = input.code_sec.unwrap().0[0]
    assert_true(constraint_gen_has_branch(body, form))
    match validate_module(input) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
  }
}

///|
test "constraint effects GenValid includes one arm control inside copied values" {
  let config = GenValidConfig::for_profile(ConstraintEffectsProfile)
  let mut found = false
  for seed = 0UL; seed < 24UL; seed = seed + 1UL {
    let input = gen_valid_module_from_seed(seed, config).unwrap().wasm_module
    assert_true(validate_module(input) is Ok(_))
    for func in input.code_sec.unwrap().0 {
      let Func(_, Expr(body)) = func
      for i = 0; i + 1 < body.length(); i = i + 1 {
        if body[i] is Block(ValTypeBlockType(_), Expr(nested)) &&
          body[i + 1] is LocalSet(_) &&
          nested.any(fn(instr) { instr is If(_, _, None) }) {
          found = true
        }
      }
    }
  }
  assert_true(found)
}

///|
test "constraint aggregate emits both logical polarities and call and handler regressions" {
  let mut and_case = false
  let mut or_case = false
  let mut handler_case = false
  let mut call_case = false
  // Bound this admission check; the dedicated lane owns large seed sweeps.
  for index = 1; index <= 64; index = index + 1 {
    let profile = gen_valid_profile_leaf_for_case(
      ConstraintAllProfile,
      0x5eedUL,
      index,
    )
    if profile != ConstraintLogicalProfile &&
      profile != ConstraintEffectsProfile {
      continue
    }
    let module_ = gen_valid_module_from_seed(
        gen_valid_case_seed(0x5eedUL, index),
        GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    assert_true(validate_module(module_) is Ok(_))
    handler_case = handler_case || module_.tag_sec is Some(_)
    for func in module_.code_sec.unwrap().0 {
      let Func(_, Expr(body)) = func
      and_case = and_case || body.contains(Instruction::i32_and())
      or_case = or_case || body.contains(Instruction::i32_or())
      call_case = call_case || body.any(fn(instr) { instr is Call(_) })
    }
  }
  assert_true(and_case, msg="aggregate missed logical AND")
  assert_true(or_case, msg="aggregate missed logical OR")
  assert_true(handler_case, msg="aggregate missed exception propagation")
  assert_true(call_case, msg="aggregate missed pending call values")
}

///|
test "constraint effects emits throwing stack values before handler-visible local writes" {
  let config = GenValidConfig::for_profile(ConstraintEffectsProfile)
  let mut found = false
  for seed = 0UL; seed < 16UL; seed = seed + 1UL {
    let input = gen_valid_module_from_seed(seed, config).unwrap().wasm_module
    assert_true(validate_module(input) is Ok(_))
    for func in input.code_sec.unwrap().0 {
      let Func(_, Expr(body)) = func
      for instr in body {
        if instr is Try(_, Expr(nested), _, _) {
          for i = 0; i + 3 < nested.length(); i = i + 1 {
            if nested[i] is Call(_) &&
              nested[i + 1] is LocalGet(_) &&
              nested[i + 2] is I32Const(_) &&
              nested[i + 3] is LocalSet(_) {
              found = true
            }
          }
        }
      }
    }
  }
  assert_true(found, msg="missing pending throwing-call/local-overwrite case")
}
