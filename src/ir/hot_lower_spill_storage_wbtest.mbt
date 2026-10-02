///|
fn hot_lower_spill_storage_fixture() -> HotFunc {
  HotFunc::new(
    locals=HotLocals::new(locals=Array::make(3, @lib.ValType::i32())),
  )
}

///|
fn hot_lower_spill_storage_active() -> Array[Instruction] {
  [
    Instruction::local_get(@lib.LocalIdx::new(0U)),
    Instruction::i32_const(I32(7)),
    Instruction::i32_add(),
    Instruction::local_set(@lib.LocalIdx::new(1U)),
    Instruction::local_get(@lib.LocalIdx::new(1U)),
    Instruction::drop(),
  ]
}

///|
test "lower binary-constant spill cleanup retains unchanged flat and nested rows" {
  let func = hot_lower_spill_storage_fixture()
  let leaf = [Instruction::i32_const(I32(7)), Instruction::drop()]
  for
    body in [
      [],
      leaf,
      [Instruction::block(@lib.BlockType::void_(), Expr::new(leaf))],
      [Instruction::loop_(@lib.BlockType::void_(), Expr::new(leaf))],
      [Instruction::if_(@lib.BlockType::void_(), leaf, Some(leaf))],
      [Instruction::try_table(@lib.BlockType::void_(), [], Expr::new(leaf))],
    ] {
    let saved = body.copy()
    let output = hot_lower_impl_rewrite_binary_const_result_spills_in_body(
      func, body,
    )
    assert_eq(output, hot_lower_spill_storage_original_body(func, body))
    assert_eq(body, saved)
    assert_true(physical_equal(output, body))
  }
}

///|
test "lower binary-constant spill cleanup owns changed paths and retains siblings" {
  let func = hot_lower_spill_storage_fixture()
  let active = hot_lower_spill_storage_active()
  let saved = active.copy()
  let sibling = [Instruction::i32_const(I32(9)), Instruction::drop()]
  let conditional = Instruction::if_(
    @lib.BlockType::void_(),
    active,
    Some(sibling),
  )
  let body = [
    Instruction::block(@lib.BlockType::void_(), Expr::new([conditional])),
  ]
  let output = hot_lower_impl_rewrite_binary_const_result_spills_in_body(
    func, body,
  )
  assert_eq(output, hot_lower_spill_storage_original_body(func, body))
  assert_false(physical_equal(output, body))
  guard output is [Block(_, Expr([If(_, yes, Some(no))]))] else {
    fail("expected nested conditional")
  }
  assert_false(physical_equal(yes, active))
  assert_true(physical_equal(no, sibling))
  assert_eq(yes[1], Instruction::local_set(@lib.LocalIdx::new(1U)))
  yes[0] = Instruction::nop()
  assert_eq(active, saved)
  assert_eq(sibling[0], Instruction::i32_const(I32(9)))
}

///|
test "lower binary-constant spill cleanup retains complete later-use and type guards" {
  let func = hot_lower_spill_storage_fixture()
  let later = hot_lower_spill_storage_active()
  later.push(Instruction::local_get(@lib.LocalIdx::new(1U)))
  later.push(Instruction::drop())
  let nested_later = hot_lower_spill_storage_active()
  nested_later.push(
    Instruction::block(
      @lib.BlockType::void_(),
      Expr::new([
        Instruction::local_get(@lib.LocalIdx::new(1U)),
        Instruction::drop(),
      ]),
    ),
  )
  let same = hot_lower_spill_storage_active()
  same[3] = Instruction::local_set(@lib.LocalIdx::new(0U))
  same[4] = Instruction::local_get(@lib.LocalIdx::new(0U))
  for body in [later, nested_later, same] {
    let output = hot_lower_impl_rewrite_binary_const_result_spills_in_body(
      func, body,
    )
    assert_eq(output, body)
    assert_true(physical_equal(output, body))
  }
  let mixed = HotFunc::new(
    locals=HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i64()]),
  )
  let body = hot_lower_spill_storage_active()
  assert_eq(
    hot_lower_impl_rewrite_binary_const_result_spills_in_body(mixed, body),
    body,
  )
}

///|
test "lower binary spill storage remains owned across public scalar trap and nested lowering" {
  for
    wat in [
      "(module (func (export \"run\") (param i32) (result i32) (local i32) local.get 0 i32.const 7 i32.add local.set 1 local.get 1))",
      "(module (func (export \"run\") (param i64) (result i64) (local i64) local.get 0 i64.const 7 i64.add local.set 1 local.get 1))",
      "(module (func (export \"run\") (param f64) (result f64) (local f64) local.get 0 f64.const 1.5 f64.add local.set 1 local.get 1))",
      "(module (func (export \"run\") (param i32) (result i32) (local i32) block (result i32) local.get 0 i32.const 0 i32.div_s local.set 1 local.get 1 end))",
    ] {
    let input = @wast.wast_to_binary_module(wat).unwrap()
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let lifted = hot_lift_func(input, @lib.FuncIdx::new(0U))
    let first = hot_lower_func(lifted)
    let output = input.with_code_sec(@lib.CodeSec::new([first]))
    @validate.validate_module(output).unwrap()
    let expected = @binary.encode_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = first
    assert_true(body.length() > 0)
    match body[0] {
      Block(_, Expr(nested)) if nested.length() > 0 =>
        nested[0] = Instruction::nop()
      _ => body[0] = Instruction::nop()
    }
    let second = input.with_code_sec(
      @lib.CodeSec::new([hot_lower_func(lifted)]),
    )
    @validate.validate_module(second).unwrap()
    assert_eq(@binary.encode_module(second).unwrap(), expected)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "lower binary-constant spill cleanup preserves typed scalar permutations" {
  for
    (ty, value, op) in [
      (
        @lib.ValType::i32(),
        Instruction::i32_const(I32(7)),
        Instruction::i32_div_s(),
      ),
      (
        @lib.ValType::i64(),
        Instruction::i64_const(@lib.I64(7L)),
        Instruction::i64_add(),
      ),
      (
        @lib.ValType::f64(),
        Instruction::f64_const(@lib.F64(1.5)),
        Instruction::f64_add(),
      ),
    ] {
    let func = HotFunc::new(locals=HotLocals::new(locals=[ty, ty]))
    let get = Instruction::local_get(@lib.LocalIdx::new(0U))
    let set = Instruction::local_set(@lib.LocalIdx::new(1U))
    let read = Instruction::local_get(@lib.LocalIdx::new(1U))
    let body = [get, value, op, set, read]
    let saved = body.copy()
    let output = hot_lower_impl_rewrite_binary_const_result_spills_in_body(
      func, body,
    )
    assert_eq(output, [get, set, read, value, op])
    assert_eq(output, hot_lower_spill_storage_original_body(func, body))
    assert_false(physical_equal(output, body))
    assert_eq(body, saved)
  }
}
