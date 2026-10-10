///|
fn lower_stack_value_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
  read : Bool,
) -> Unit {
  let val_type = if reference {
    @lib.ValType::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any()))
  } else {
    @lib.ValType::i32()
  }
  let stack : HotLowerValueStack = hot_lower_value_stack_new()
  it.bench(fn() {
    for node_id in 0..<width {
      stack.push({ node_id, val_type, })
    }
    let mut sum = 0
    for _ in 0..<width {
      if read {
        let value = stack.pop().unwrap()
        sum += value.node_id
        it.keep(value.val_type)
      } else {
        ignore(stack.pop())
      }
    }
    it.keep(sum)
    it.keep(stack)
  })
}

///|
test "bench lower stack scalar1 discard" (it : @bench.T) {
  lower_stack_value_bench(it, 1, false, false)
}

///|
test "bench lower stack scalar64 discard" (it : @bench.T) {
  lower_stack_value_bench(it, 64, false, false)
}

///|
test "bench lower stack scalar64 read" (it : @bench.T) {
  lower_stack_value_bench(it, 64, false, true)
}

///|
test "bench lower stack reference64 read" (it : @bench.T) {
  lower_stack_value_bench(it, 64, true, true)
}
