///|
test "campaign SIMD numeric profile emits valid randomized local alias shapes" {
  let profile = gen_valid_profile_by_name("campaign-simd-numeric").unwrap()
  let config = GenValidConfig::for_profile(profile)
  let seen_aliases = Array::make(5, false)
  let mut first_body : Array[Instruction]? = None
  for seed = 0UL; seed < 96UL; seed = seed + 1UL {
    let generated = gen_valid_module_from_seed(seed, config).unwrap()
    let module_ = generated.wasm_module
    match validate_module(module_) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    let Func(_, Expr(body)) = module_.code_sec.unwrap().0[0]
    if seed == 0UL {
      first_body = Some(body)
    }
    if seed == 12UL {
      assert_true(Some(body) != first_body)
    }
    for i = 3; i < body.length(); i = i + 1 {
      if body[i] is V128Bitselect {
        match (body[i - 3], body[i - 2], body[i - 1]) {
          (LocalGet(a), LocalGet(b), LocalGet(c)) =>
            if a == b && b == c {
              seen_aliases[4] = true
            } else if a == b {
              seen_aliases[0] = true
            } else if a == c {
              seen_aliases[1] = true
            } else if b == c {
              seen_aliases[2] = true
            } else {
              seen_aliases[3] = true
            }
          _ => ()
        }
      }
    }
  }
  assert_true(seen_aliases.iter().all(fn(seen) { seen }))
}

///|
test "campaign SIMD numeric profile combines vector lanes with numeric and control flow" {
  let profile = gen_valid_profile_by_name("campaign-simd-numeric").unwrap()
  let config = GenValidConfig::for_profile(profile)
  let seen = Array::make(8, false)
  for seed = 0UL; seed < 96UL; seed = seed + 1UL {
    let module_ = gen_valid_module_from_seed(seed, config).unwrap().wasm_module
    assert_true(validate_module(module_) is Ok(_))
    let Func(_, Expr(body)) = module_.code_sec.unwrap().0[0]
    for instruction in body {
      match instruction {
        I32x4ReplaceLane(_) => seen[0] = true
        I8x16ExtractLaneS(_) => seen[1] = true
        I8x16ExtractLaneU(_) => seen[2] = true
        F32x4ConvertI32x4S => seen[3] = true
        I32ReinterpretF32 => seen[4] = true
        I32x4Splat => seen[5] = true
        If(_, _, _) => seen[6] = true
        Select(_) => seen[7] = true
        _ => ()
      }
    }
  }
  assert_true(seen.iter().all(fn(value) { value }))
}
