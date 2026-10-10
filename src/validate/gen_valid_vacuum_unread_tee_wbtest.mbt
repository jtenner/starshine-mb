///|
fn gen_valid_unread_tee_test_count(body : Array[Instruction]) -> Int {
  let mut count = 0
  for instr in body {
    match instr {
      LocalTee(_) => count += 1
      Block(_, Expr(inner))
      | Loop(_, Expr(inner))
      | TryTable(_, _, Expr(inner)) =>
        count += gen_valid_unread_tee_test_count(inner)
      If(_, left, right) => {
        count += gen_valid_unread_tee_test_count(left)
        match right {
          Some(inner) => count += gen_valid_unread_tee_test_count(inner)
          None => ()
        }
      }
      Try(_, Expr(inner), catches, _) => {
        count += gen_valid_unread_tee_test_count(inner)
        for catch_ in catches {
          match catch_ {
            LegacyCatch(_, Expr(handler)) | LegacyCatchAll(Expr(handler)) =>
              count += gen_valid_unread_tee_test_count(handler)
          }
        }
      }
      _ => ()
    }
  }
  count
}

///|
test "vacuum unread tee profile is a stable distinct targeted lane" {
  let profile = gen_valid_profile_by_name("vacuum-unread-tee").unwrap()
  @debug.assert_eq(gen_valid_profile_name(profile), "vacuum-unread-tee")
  assert_true(gen_valid_profile_names().contains("vacuum-unread-tee"))
  @debug.assert_eq(
    gen_valid_config_label(GenValidConfig::for_profile(profile)),
    "vacuum-unread-tee",
  )
}

///|
test "vacuum unread tee every seeded family emits observable tees through binary roundtrip" {
  let profile = gen_valid_profile_by_name("vacuum-unread-tee").unwrap()
  for seed = 0; seed < 48; seed = seed + 1 {
    let generated = gen_valid_module_result_from_seed(
      seed.to_uint64(),
      GenValidConfig::for_profile(profile),
    ).unwrap()
    assert_true(
      generated.facts.has_local_tee,
      msg="expected tee feature at seed \{seed}",
    )
    assert_true(generated.facts.has_import_event_channel)
    assert_true(generated.facts.has_func_exports)
    assert_true(generated.facts.has_global_exports)
    let input = generated.wasm_module
    let family = seed % 13
    let Func(_, Expr(body)) = input.code_sec.unwrap().0[0]
    match family {
      0 => assert_true(body.last().unwrap() is I32Add)
      1 | 2 => @debug.assert_eq(body.length(), 3)
      3 => assert_true(generated.facts.has_gc_constructors)
      4 => assert_true(body.last().unwrap() is RefIsNull)
      5 => assert_true(body[0] is Block(_, _))
      6 => assert_true(body[5] is If(_, _, Some(_)))
      7 =>
        match body[0] {
          Block(_, Expr([TryTable(_, [CatchAll(LabelIdx(0U))], _)])) => ()
          _ => fail("expected preserved try-table catch target")
        }
      8 => assert_true(body[0] is Try(_, _, _, _))
      9 => assert_true(body[4] is Try(_, _, _, _))
      10 => assert_true(body.last().unwrap() is I32DivS)
      11 => assert_true(body[1] is If(_, _, Some(_)))
      _ => {
        assert_true(input.mem_sec is Some(_))
        assert_true(body.last().unwrap() is I32Load(_))
      }
    }
    validate_module(input).unwrap()
    let encoded = @binary.encode_module(input).unwrap()
    let decoded = @binary.decode_module(encoded).unwrap()
    validate_module(decoded).unwrap()
    for mod_ in [input, decoded] {
      let mut tees = 0
      for func in mod_.code_sec.unwrap().0 {
        let Func(_, Expr(body)) = func
        tees += gen_valid_unread_tee_test_count(body)
      }
      @debug.assert_eq(tees, if family == 11 { 2 } else { 1 })
    }
  }
}
