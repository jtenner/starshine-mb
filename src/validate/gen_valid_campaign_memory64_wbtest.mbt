///|
fn gen_valid_campaign_memory64_test_index(ma : MemArg) -> Int {
  let MemArg(_, memory, _) = ma
  match memory {
    Some(MemIdx(index)) => index.reinterpret_as_int()
    None => -1
  }
}

///|
test "campaign memory64 multi-memory covers indexed address and operation shapes" {
  let profile = match
    gen_valid_profile_by_name("campaign-memory64-multimemory") {
    Ok(profile) => profile
    Err(message) => fail(message)
  }
  let config = GenValidConfig::for_profile(profile)
  let seen_width = Array::make(6, false)
  let seen_ops = Array::make(12, false)
  let seen_values = Array::make(12, false)
  let seen_offsets = Array::make(4, false)
  let mut saw_two_memories = false
  let mut saw_three_memories = false
  for seed = 0UL; seed < 96UL; seed = seed + 1UL {
    let input = gen_valid_module_from_seed(seed, config).unwrap().wasm_module
    match validate_module(input) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    let MemSec(memories) = input.mem_sec.unwrap()
    assert_true(memories.length() == 2 || memories.length() == 3)
    if memories.length() == 2 {
      saw_two_memories = true
    } else {
      saw_three_memories = true
    }
    let widths = Array::make(memories.length(), false)
    for index = 0; index < memories.length(); index = index + 1 {
      let MemType(limits, shared) = memories[index]
      assert_false(shared)
      widths[index] = match limits {
        I32Limits(_, _) => false
        I64Limits(_, _) => true
      }
      let width_index = if widths[index] { 1 } else { 0 }
      seen_width[index * 2 + width_index] = true
    }
    let CodeSec(functions) = input.code_sec.unwrap()
    assert_eq(functions.length(), 1)
    let Func(_, Expr(body)) = functions[0]
    let observed = Array::make(memories.length() * 4, false)
    for pos = 0; pos < body.length(); pos = pos + 1 {
      let op = body[pos]
      match op {
        I32Load(ma) | I64Load(ma) | I32Store(ma) | I64Store(ma) => {
          let index = gen_valid_campaign_memory64_test_index(ma)
          assert_true(index >= 0 && index < memories.length())
          let MemArg(_, _, U64(offset)) = ma
          assert_true(offset <= 12UL && offset % 4UL == 0UL)
          seen_offsets[(offset / 4UL).to_int()] = true
          let is_store = op is I32Store(_) || op is I64Store(_)
          let is_i64_value = op is I64Load(_) || op is I64Store(_)
          let kind = if is_store { 1 } else { 0 }
          observed[index * 4 + kind] = true
          seen_ops[index * 4 + kind] = true
          let value_index = if is_i64_value { 1 } else { 0 }
          seen_values[index * 4 + kind * 2 + value_index] = true
          let address = if is_store { body[pos - 2] } else { body[pos - 1] }
          if widths[index] {
            assert_true(address is I64Const(_))
          } else {
            assert_true(address is I32Const(_))
          }
        }
        MemorySize(MemIdx(raw_index)) => {
          let index = raw_index.reinterpret_as_int()
          assert_true(index >= 0 && index < memories.length())
          observed[index * 4 + 2] = true
          seen_ops[index * 4 + 2] = true
          assert_true(body[pos + 1] is Drop)
        }
        MemoryGrow(MemIdx(raw_index)) => {
          let index = raw_index.reinterpret_as_int()
          assert_true(index >= 0 && index < memories.length())
          observed[index * 4 + 3] = true
          seen_ops[index * 4 + 3] = true
          if widths[index] {
            assert_true(body[pos - 1] is I64Const(_))
          } else {
            assert_true(body[pos - 1] is I32Const(_))
          }
          assert_true(body[pos + 1] is Drop)
        }
        _ => ()
      }
    }
    for observed_kind in observed {
      assert_true(observed_kind)
    }
  }
  assert_true(saw_two_memories && saw_three_memories)
  for width in seen_width {
    assert_true(width)
  }
  for operation in seen_ops {
    assert_true(operation)
  }
  for value in seen_values {
    assert_true(value)
  }
  for offset in seen_offsets {
    assert_true(offset)
  }
}
