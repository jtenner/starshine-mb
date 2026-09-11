///|
test "Binaryen 132 atomic GenValid samples every order on linear struct and array stores" {
  let profile = gen_valid_profile_by_name("binaryen132-atomic-orders").unwrap()
  let seen = Array::make(9, false)
  for seed = 0UL; seed < 36UL; seed = seed + 1UL {
    let input = gen_valid_module_from_seed(
        seed,
        GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    match validate_module(input) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    for func in input.code_sec.unwrap().0 {
      let Func(_, Expr(body)) = func
      for instruction in body {
        let (kind, order) = match instruction {
          I32AtomicStore(order, _) => (0, order)
          StructAtomicSet(order, _, _) => (1, order)
          ArrayAtomicSet(order, _) => (2, order)
          _ => continue
        }
        let order_index = match order {
          SeqCst => 0
          AcqRel => 1
          Relaxed => 2
        }
        seen[kind * 3 + order_index] = true
      }
    }
  }
  assert_true(seen.iter().all(fn(value) { value }))
}

///|
test "Binaryen 132 atomic GenValid covers shared and unshared identity and changing aggregate RMWs" {
  let config = GenValidConfig::for_profile(
    gen_valid_profile_by_name("binaryen132-atomic-orders").unwrap(),
  )
  let seen = Array::make(48, false)
  for seed = 0UL; seed < 180UL; seed = seed + 1UL {
    let input = gen_valid_module_from_seed(seed, config).unwrap().wasm_module
    assert_true(validate_module(input) is Ok(_))
    let variant = (seed / 36UL % 5UL).to_int()
    if variant == 0 {
      continue
    }
    let kind = (seed % 3UL).to_int()
    if kind == 0 {
      continue
    }
    let order = (seed / 3UL % 3UL).to_int()
    let shared = if ((seed / 9UL) & 1UL) == 0UL { 0 } else { 1 }
    let Func(_, Expr(body)) = input.code_sec.unwrap().0[0]
    let expected_kind = if variant <= 2 { 0 } else { 1 }
    let mut count = 0
    for instr in body {
      let actual_kind = match instr {
        StructAtomicRmw(_, _, _, _) | ArrayAtomicRmw(_, _, _) => 0
        StructAtomicCmpxchg(_, _, _) | ArrayAtomicCmpxchg(_, _) => 1
        _ => continue
      }
      assert_eq(actual_kind, expected_kind)
      count += 1
    }
    assert_eq(count, 1)
    seen[(((kind - 1) * 3 + order) * 2 + shared) * 4 + variant - 1] = true
  }
  assert_true(seen.iter().all(fn(value) { value }))
}
