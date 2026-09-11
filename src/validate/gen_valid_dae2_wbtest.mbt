///|
test "dae2 GenValid aggregate exposes each release semantic family" {
  let aggregate = match gen_valid_profile_by_name("dae2") {
    Ok(profile) => profile
    Err(err) => fail(err)
  }
  assert_true(gen_valid_profile_is_composite(aggregate))
  let members = gen_valid_profile_members(aggregate)
  for
    name in [
      "dae2-forwarded-results", "dae2-cycles", "dae2-control-flow", "dae2-effectful-arguments",
      "dae2-tuple-results", "dae2-tail-calls", "dae2-indirect", "dae2-open-world",
      "dae2-reference-types", "dae2-locals", "dae2-continuations", "dae2-exceptions",
      "dae2-call-ref", "dae2-intrinsics",
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
        Ok(generated) => generated
        Err(err) => fail(err.validation_error_message)
      }
      match validate_module(generated.wasm_module) {
        Ok(_) => ()
        Err(err) => fail(validation_error_message(err))
      }
      // Every case contains a private producer/consumer boundary, rather than
      // an arbitrary valid body that never exercises signature elimination.
      match generated.wasm_module.code_sec {
        Some(CodeSec(funcs)) => assert_true(funcs.length() >= 3)
        None => fail("DAE2 generator did not emit function bodies")
      }
    }
  }
}

///|
test "dae2 forwarded results GenValid emits a call result as an argument" {
  let profile = match gen_valid_profile_by_name("dae2-forwarded-results") {
    Ok(profile) => profile
    Err(err) => fail(err)
  }
  let generated = match
    gen_valid_module_result(
      @splitmix.new(seed=0x5eedUL),
      GenValidConfig::for_profile(profile),
    ) {
    Ok(generated) => generated.wasm_module
    Err(err) => fail(err.validation_error_message)
  }
  match generated.code_sec {
    Some(CodeSec(funcs)) => {
      let Func(_, Expr(body)) = funcs[funcs.length() - 1]
      assert_true(body.contains(Instruction::call(FuncIdx::new(0U))))
      assert_true(body.contains(Instruction::call(FuncIdx::new(1U))))
    }
    None => fail("missing DAE2 caller")
  }
}

///|
fn dae2_gen_continuation_kinds(
  body : Array[Instruction],
  seen : Array[Bool],
) -> Unit {
  for instr in body {
    match instr {
      Instruction::ContNew(_) => seen[0] = true
      Instruction::ContBind(_, _) => seen[1] = true
      Instruction::Resume(_, handlers) => {
        seen[2] = true
        if !handlers.is_empty() {
          seen[5] = true
        }
      }
      Instruction::ResumeThrow(_, _, _) => seen[3] = true
      Instruction::Suspend(_) => seen[4] = true
      Instruction::Block(_, Expr(nested))
      | Instruction::Loop(_, Expr(nested)) =>
        dae2_gen_continuation_kinds(nested, seen)
      _ => ()
    }
  }
}

///|
test "dae2 continuation GenValid varies construction binding execution and handler edges" {
  let profile = gen_valid_profile_by_name("dae2-continuations").unwrap()
  let seen = Array::make(6, false)
  for seed = 0; seed < 48; seed = seed + 1 {
    let input = match
      gen_valid_module_from_seed(
        seed.to_uint64(),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(generated) => generated.wasm_module
      Err(err) => fail(err.validation_error_message)
    }
    let funcs = match input.code_sec {
      Some(CodeSec(funcs)) => funcs
      None => fail("missing code")
    }
    for func in funcs {
      let Func(_, Expr(body)) = func
      dae2_gen_continuation_kinds(body, seen)
    }
  }
  @debug.assert_eq(seen, [true, true, true, true, true, true])
}

///|
test "dae2 tuple and exception generators expose producer effects to the oracle" {
  for profile in [Dae2TupleResultsProfile, Dae2ExceptionsProfile] {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed=0x5eedUL),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(generated) => generated.wasm_module
      Err(err) => fail(err.validation_error_message)
    }
    let bodies = match generated.code_sec {
      Some(CodeSec(bodies)) => bodies
      None => fail("missing bodies")
    }
    let Func(_, Expr(producer)) = bodies[0]
    assert_true(producer.contains(Instruction::global_set(GlobalIdx::new(0U))))
    let exports = match generated.export_sec {
      Some(ExportSec(exports)) => exports
      None => fail("missing observable state export")
    }
    assert_true(
      exports.any(fn(item) {
        let Export(_, kind) = item
        kind == ExternIdx::global(GlobalIdx::new(0U))
      }),
    )
  }
}

///|
test "dae2 effect generator includes loads held across clobbering calls" {
  let mut found = false
  for seed in [0UL, 1UL, 2UL, 3UL, 0x5eedUL, 0xffffffffffffffffUL] {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed~),
        GenValidConfig::for_profile(Dae2EffectfulArgumentsProfile),
      ) {
      Ok(generated) => generated.wasm_module
      Err(err) => fail(err.validation_error_message)
    }
    if generated.code_sec is Some(CodeSec(bodies)) {
      let Func(_, Expr(body)) = bodies[bodies.length() - 1]
      let mut pending_load = false
      for instr in body {
        match instr {
          Instruction::I32Load(_) => pending_load = true
          Instruction::Call(FuncIdx(0U)) if pending_load => found = true
          _ => ()
        }
      }
    }
  }
  assert_true(found)
}

///|
test "dae2 locals generator covers conditional assignments and ordered stack captures" {
  let mut conditional = false
  let mut capture = false
  for seed = 0; seed < 24; seed = seed + 1 {
    let input = gen_valid_module_from_seed(
        seed.to_uint64(),
        GenValidConfig::for_profile(Dae2LocalsProfile),
      ).unwrap().wasm_module
    let CodeSec(bodies) = input.code_sec.unwrap()
    for body in bodies {
      let Func(_, Expr(ops)) = body
      conditional = conditional ||
        ops.any(fn(op) { op is Instruction::If(_, _, _) })
      capture = capture ||
        (
          ops.any(fn(op) { op is Instruction::MemorySize(_) }) &&
          ops.any(fn(op) { op is Instruction::I32Load(_) })
        )
    }
  }
  assert_true(conditional)
  assert_true(capture)
}

///|
test "dae2 tuple GenValid includes nested producers with reads before writes" {
  let input = gen_valid_module_from_seed(
      4UL,
      GenValidConfig::for_profile(Dae2TupleResultsProfile),
    ).unwrap().wasm_module
  let Func(_, Expr(body)) = input.code_sec.unwrap().0[0]
  assert_true(body.any(fn(op) { op is Instruction::If(_, _, _) }))
  match validate_module(input) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
}

///|
test "dae2 aggregate emits pending memory reads and ordered argument effects" {
  let mut memory_case = false
  let mut argument_case = false
  for index = 1; index <= 64; index = index + 1 {
    let profile = gen_valid_profile_leaf_for_case(
      Dae2AllProfile,
      0x5eedUL,
      index,
    )
    if profile != Dae2EffectfulArgumentsProfile {
      continue
    }
    let module_ = gen_valid_module_from_seed(
        gen_valid_case_seed(0x5eedUL, index),
        GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    assert_true(validate_module(module_) is Ok(_))
    memory_case = memory_case || module_.mem_sec is Some(_)
    argument_case = argument_case ||
      (module_.mem_sec is None && module_.global_sec is Some(_))
  }
  assert_true(
    memory_case,
    msg="aggregate missed reads held across clobbering calls",
  )
  assert_true(argument_case, msg="aggregate missed ordered effectful arguments")
}

///|
test "dae2 tuple GenValid varies overlapping captures and swapped copyback lanes" {
  let config = GenValidConfig::for_profile(Dae2TupleResultsProfile)
  assert_true(config.max_results >= 3 && config.max_locals >= 11)
  let mut same_lane = false
  let mut swapped_lane = false
  for seed in 0..<32 {
    let input = gen_valid_module_from_seed(
        seed.to_uint64(),
        GenValidConfig::for_profile(Dae2TupleResultsProfile),
      ).unwrap().wasm_module
    let bodies = input.code_sec.unwrap().0
    let Func(_, Expr(body)) = bodies[bodies.length() - 1]
    for index = 0; index + 3 < body.length(); index = index + 1 {
      if body[index] is Instruction::Block(_, _) &&
        body[index + 3] == Instruction::local_set(LocalIdx::new(9U)) {
        same_lane = same_lane ||
          (
            body[index + 1] == Instruction::local_set(LocalIdx::new(6U)) &&
            body[index + 2] == Instruction::local_set(LocalIdx::new(10U))
          )
        swapped_lane = swapped_lane ||
          (
            body[index + 1] == Instruction::local_set(LocalIdx::new(10U)) &&
            body[index + 2] == Instruction::local_set(LocalIdx::new(6U))
          )
      }
    }
  }
  assert_true(same_lane, msg="missing same-lane overlapping tuple capture")
  assert_true(swapped_lane, msg="missing different-lane copyback")
}

///|
test "dae2 tuple GenValid varies label metadata on overlapping captures" {
  for seed in [8UL, 9UL, 24UL, 25UL] {
    let input = gen_valid_module_from_seed(
        seed,
        GenValidConfig::for_profile(Dae2TupleResultsProfile),
      ).unwrap().wasm_module
    assert_true(validate_module(input) is Ok(_))
    if seed >= 16UL {
      let names = match input.name_sec {
        Some(names) => names
        None => fail("named tuple variant must carry its forwarding label")
      }
      @debug.assert_eq(
        names.label_names,
        Some(
          IndirectNameMap::new([
            IndirectNameAssoc::new(
              2U,
              NameMap::new([
                NameAssoc::new(0U, Name::from_string("forwarded-tuple")),
              ]),
            ),
          ]),
        ),
      )
    } else {
      assert_true(input.name_sec is None)
    }
  }
}

///|
test "dae2 continuation declarations vary index and typed expression forms" {
  let profile = gen_valid_profile_by_name("dae2-continuations").unwrap()
  for seed in [4UL, 28UL] {
    let input = gen_valid_module_from_seed(
        seed,
        GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    assert_true(validate_module(input) is Ok(_))
    let ElemSec(elems) = input.elem_sec.unwrap()
    if seed == 28UL {
      assert_true(
        elems[0]
        is Elem(
          Declarative,
          TypedExprsElemKind(_, [Expr([RefFunc(FuncIdx(0U))])])
        ),
      )
    } else {
      assert_true(elems[0] is Elem(Declarative, FuncsElemKind([FuncIdx(0U)])))
    }
  }
}

///|
test "dae2 locals GenValid covers inserted control before a later parameter tee" {
  assert_true(
    gen_valid_profile_members(SimplifyLocalsAllProfile).any(fn(entry) {
      entry.profile == Dae2LocalsProfile
    }),
  )
  for seed in [0UL, 6UL, 12UL, 18UL] {
    let generated = gen_valid_module_from_seed(
        seed,
        GenValidConfig::for_profile(Dae2LocalsProfile),
      ).unwrap().wasm_module
    validate_module(generated).unwrap()
    let CodeSec(funcs) = generated.code_sec.unwrap()
    let Func(_, Expr(body)) = funcs[1]
    assert_true(body.any(fn(instruction) { instruction is If(_, _, None) }))
    assert_true(body.contains(Instruction::local_tee(LocalIdx::new(0U))))
    let Func(_, Expr(observer)) = funcs[0]
    assert_true(observer.contains(Instruction::global_set(GlobalIdx::new(1U))))
    assert_true(
      generated.export_sec.unwrap().0.any(fn(export_) {
        export_.1 == ExternIdx::global(GlobalIdx::new(0U))
      }),
    )
  }
}

///|
test "dae2 locals GenValid covers a derived pointer carried across its header store" {
  for seed in [3UL, 15UL, 27UL, 39UL] {
    let input = gen_valid_module_from_seed(
        seed,
        GenValidConfig::for_profile(Dae2LocalsProfile),
      ).unwrap().wasm_module
    validate_module(input).unwrap()
    assert_true(input.mem_sec is Some(_))
    let CodeSec(funcs) = input.code_sec.unwrap()
    let Func(_, Expr(body)) = funcs[1]
    assert_true(body.any(fn(instruction) { instruction is I32Store(_) }))
    assert_true(body.contains(Instruction::local_set(LocalIdx::new(1U))))
    assert_true(body.contains(Instruction::local_set(LocalIdx::new(2U))))
    @debug.assert_eq(
      body[body.length() - 1],
      Instruction::local_get(LocalIdx::new(2U)),
    )
  }
}
