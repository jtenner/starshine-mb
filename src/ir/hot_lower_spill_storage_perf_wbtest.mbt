///|
fn hot_lower_spill_storage_bench(
  it : @bench.T,
  kind : Int,
  original : Bool,
) -> Unit raise {
  let mut body : Array[Instruction] = []
  let width = if kind == 0 { 1 } else if kind == 3 { 16 } else { 128 }
  let func = if kind == 3 {
    HotFunc::new(
      locals=HotLocals::new(locals=Array::make(width + 1, @lib.ValType::i32())),
    )
  } else {
    hot_lower_spill_storage_fixture()
  }
  for index in 0..<width {
    if kind == 3 || kind == 4 {
      let candidate = hot_lower_spill_storage_active()
      if kind == 3 {
        let target = @lib.LocalIdx::new((index + 1).reinterpret_as_uint())
        candidate[3] = Instruction::local_set(target)
        candidate[4] = Instruction::local_get(target)
      }
      for instr in candidate {
        body.push(instr)
      }
    } else {
      body.push(Instruction::i32_const(I32(index)))
      body.push(Instruction::drop())
    }
  }
  if kind == 5 {
    body = [
      Instruction::if_(
        @lib.BlockType::void_(),
        hot_lower_spill_storage_active(),
        Some(body),
      ),
    ]
  }
  if kind == 2 {
    for _ in 0..<4 {
      body = [Instruction::block(@lib.BlockType::void_(), Expr::new(body))]
    }
  }
  if kind == 4 {
    body.push(Instruction::local_get(@lib.LocalIdx::new(1U)))
    body.push(Instruction::drop())
  }
  let saved = body.copy()
  assert_eq(
    hot_lower_impl_rewrite_binary_const_result_spills_in_body(func, body),
    hot_lower_spill_storage_original_body(func, body),
  )
  it.bench(fn() {
    it.keep(
      if original {
        hot_lower_spill_storage_original_body(func, body)
      } else {
        hot_lower_impl_rewrite_binary_const_result_spills_in_body(func, body)
      },
    )
  })
  assert_eq(body, saved)
}

///|
test "bench lower spill tiny original" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 0, true)
}

///|
test "bench lower spill tiny retained" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 0, false)
}

///|
test "bench lower spill wide128 original" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 1, true)
}

///|
test "bench lower spill wide128 retained" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 1, false)
}

///|
test "bench lower spill nested128 original" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 2, true)
}

///|
test "bench lower spill nested128 retained" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 2, false)
}

///|
test "bench lower spill active16 original" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 3, true)
}

///|
test "bench lower spill active16 retained" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 3, false)
}

///|
test "bench lower spill guarded128 original" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 4, true)
}

///|
test "bench lower spill guarded128 retained" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 4, false)
}

///|
test "bench lower spill nested-sibling128 original" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 5, true)
}

///|
test "bench lower spill nested-sibling128 retained" (it : @bench.T) {
  hot_lower_spill_storage_bench(it, 5, false)
}
