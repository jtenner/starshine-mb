///|
test "Binaryen 132 waitqueue GenValid covers allocation notify wait and queue nullability" {
  let profile = gen_valid_profile_by_name("binaryen132-waitqueue").unwrap()
  let seen = Array::make(4, false)
  for seed in [0UL, 1UL, 2UL, 3UL, 4UL, 5UL] {
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
      for op in body {
        match op {
          WaitqueueNew => seen[0] = true
          WaitqueueNotify => seen[1] = true
          StructWait(_, _) => seen[2] = true
          RefNull(_) => seen[3] = true
          _ => ()
        }
      }
    }
  }
  @debug.assert_eq(seen, [true, true, true, true])
}
