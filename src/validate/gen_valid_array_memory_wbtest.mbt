///|
test "Binaryen 132 array memory GenValid covers scalar vector and offset variants" {
  let profile = match gen_valid_profile_by_name("binaryen132-array-memory") {
    Ok(profile) => profile
    Err(err) => fail(err)
  }
  let mut loads = 0
  let mut stores = 0
  let mut vectors = 0
  let mut offsets = 0
  let seen : Array[Instruction] = []
  for seed = 0; seed < 100; seed = seed + 1 {
    let input = gen_valid_module_from_seed(
        seed.to_uint64(),
        GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    let CodeSec(bodies) = input.code_sec.unwrap()
    for body in bodies {
      let Func(_, Expr(ops)) = body
      for op in ops {
        match op {
          Instruction::ArrayLoad(load, _, MemArg(_, _, U64(offset))) => {
            loads += 1
            if load is @lib.V128LoadOp {
              vectors += 1
            }
            if offset > 0UL {
              offsets += 1
            }
            if !seen.contains(op) {
              seen.push(op)
            }
          }
          Instruction::ArrayStore(store, _, MemArg(_, _, U64(offset))) => {
            stores += 1
            if store is @lib.V128StoreOp {
              vectors += 1
            }
            if offset > 0UL {
              offsets += 1
            }
            if !seen.contains(op) {
              seen.push(op)
            }
          }
          _ => ()
        }
      }
    }
  }
  assert_true(loads > 0 && stores > 0 && vectors > 0 && offsets > 0)
  assert_true(seen.length() >= 25)
}
