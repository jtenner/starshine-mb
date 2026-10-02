///|
fn hot_lower_strip_storage_bench(
  it : @bench.T,
  kind : Int,
  original : Bool,
) -> Unit raise {
  let local = @lib.LocalIdx::new(0U)
  let body : Array[Instruction] = []
  let options = if kind == 2 {
    HotLowerOptions::new(
      preserve_nontrailing_nops=true,
      preserve_trailing_nops=true,
    )
  } else {
    HotLowerOptions::new()
  }
  let width = if kind == 0 {
    1
  } else if kind == 3 {
    16
  } else if kind == 5 {
    32
  } else {
    128
  }
  if kind == 4 {
    body.push(Instruction::unreachable_())
  }
  for index in 0..<width {
    if kind == 4 {
      body.push(Instruction::nop())
    } else {
      if kind == 2 {
        body.push(Instruction::nop())
      }
      body.push(Instruction::i32_const(I32(index)))
      if kind == 3 || kind == 5 {
        body.push(Instruction::local_tee(local))
      }
      body.push(Instruction::drop())
    }
  }
  if kind == 5 {
    body.push(Instruction::local_get(local))
    body.push(Instruction::drop())
  }
  let saved = body.copy()
  assert_eq(
    hot_lower_impl_strip_redundant_nops_and_dead_local_tee_drops(body, options),
    hot_lower_strip_storage_reference(body, options),
  )
  it.bench(fn() {
    it.keep(
      if original {
        hot_lower_strip_storage_reference(body, options)
      } else {
        hot_lower_impl_strip_redundant_nops_and_dead_local_tee_drops(
          body, options,
        )
      },
    )
  })
  assert_eq(body, saved)
}

///|
test "bench lower strip tiny original" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 0, true)
}

///|
test "bench lower strip tiny retained" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 0, false)
}

///|
test "bench lower strip wide128 original" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 1, true)
}

///|
test "bench lower strip wide128 retained" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 1, false)
}

///|
test "bench lower strip preserved-nops128 original" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 2, true)
}

///|
test "bench lower strip preserved-nops128 retained" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 2, false)
}

///|
test "bench lower strip active-tee16 original" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 3, true)
}

///|
test "bench lower strip active-tee16 retained" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 3, false)
}

///|
test "bench lower strip unreachable128 original" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 4, true)
}

///|
test "bench lower strip unreachable128 retained" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 4, false)
}

///|
test "bench lower strip guarded-tee32 original" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 5, true)
}

///|
test "bench lower strip guarded-tee32 retained" (it : @bench.T) {
  hot_lower_strip_storage_bench(it, 5, false)
}
