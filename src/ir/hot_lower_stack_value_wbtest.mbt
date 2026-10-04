///|
test "lower stack updates preserve saturating discard and terminal clearing" {
  let func = HotFunc::new()
  let value = hot_build_const_i32(func, @lib.I32(7))
  let terminal = hot_build_unreachable(func)
  let reference = @lib.ValType::ref_null(
    @lib.HeapType::abs(@lib.AbsHeapType::any()),
  )
  let seed : Array[HotLowerStackValue] = [
    { node_id: 31, val_type: reference, },
    { node_id: 37, val_type: @lib.ValType::i64(), },
    { node_id: 41, val_type: @lib.ValType::i32(), },
  ]
  for width in [0, 1, 3] {
    for consumed in [-1, 0, 1, 2, 3, 4] {
      let stack = seed[0:width].to_owned()
      let saved = stack.copy()
      let expected = stack.copy()
      for _ in 0..<consumed {
        ignore(expected.pop())
      }
      expected.push({ node_id: value, val_type: @lib.ValType::i32(), })
      hot_lower_impl_update_stack(func, value, consumed, stack)
      assert_eq(
        stack.map(fn(x) { (x.node_id, x.val_type) }),
        expected.map(fn(x) { (x.node_id, x.val_type) }),
      )
      assert_eq(
        saved.map(fn(x) { (x.node_id, x.val_type) }),
        seed[0:width].to_owned().map(fn(x) { (x.node_id, x.val_type) }),
      )
      hot_lower_impl_update_stack(func, terminal, consumed, stack)
      assert_true(stack.is_empty())
    }
  }
}

///|
test "lower stack values retain scalar and reference snapshots across writes and pops" {
  let reference = @lib.ValType::ref_null(
    @lib.HeapType::abs(@lib.AbsHeapType::any()),
  )
  let first : HotLowerStackValue = {
    node_id: 7,
    val_type: @lib.ValType::i32(),
  }
  let second : HotLowerStackValue = { node_id: 9, val_type: reference, }
  let stack = [first, second]
  let saved = stack.copy()
  let last = stack.last().unwrap()
  stack[1] = { node_id: 11, val_type: @lib.ValType::i64(), }
  assert_eq(last.node_id, 9)
  assert_eq(last.val_type, reference)
  assert_eq(saved[1].node_id, 9)
  assert_eq(saved[1].val_type, reference)
  let popped = stack.pop().unwrap()
  assert_eq(popped.node_id, 11)
  assert_eq(popped.val_type, @lib.ValType::i64())
  stack.clear()
  assert_true(stack.pop() is None)
  assert_eq(saved.length(), 2)
  assert_eq(saved[0].node_id, 7)
  assert_eq(saved[0].val_type, @lib.ValType::i32())
  saved[0] = second
  assert_eq(first.node_id, 7)
  assert_eq(first.val_type, @lib.ValType::i32())
}

///|
test "lower stack values preserve typed branch inputs and repeated lowering bytes" {
  for
    source in [
      "(module (func (param i32) (result i32 i64) i32.const 4 i64.const 7 local.get 0 if (param i32 i64) (result i32 i64) i64.const 3 i64.add else i64.const 2 i64.add end))",
      "(module (func (param i32) (result i32 externref) i32.const 4 ref.null extern local.get 0 if (param i32 externref) (result i32 externref) else end))",
    ] {
    let input = @wast.wast_to_binary_module(source).unwrap()
    @validate.validate_module(input).unwrap()
    let before = @binary.encode_module(input).unwrap()
    let hot = hot_lift_func(input, @lib.FuncIdx::new(0U))
    let revision = hot_revision_current(hot)
    let first = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(hot)]))
    let second = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(hot)]))
    @validate.validate_module(first).unwrap()
    @validate.validate_module(second).unwrap()
    assert_eq(@binary.encode_module(first).unwrap(), before)
    assert_eq(@binary.encode_module(second).unwrap(), before)
    assert_eq(@binary.encode_module(input).unwrap(), before)
    assert_eq(hot_revision_current(hot), revision)
  }
}
