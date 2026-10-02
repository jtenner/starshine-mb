///|
test "cleanup read copies retain packed membership with independent ordered rows" {
  for base in [0, 64, -64, 2147483584] {
    let parent = SlCleanupReadSet::new(
      Array::makei(32, fn(index) { base + index }),
    )
    assert_true(parent.contains(base + 31))
    let child = parent.copy()
    assert_eq(child.bits, parent.bits)
    assert_eq(child.word, parent.word)
    assert_true(child.members is None)
    assert_false(physical_equal(child.reads, parent.reads))
    child.insert(base + 63)
    parent.insert(base + 62)
    assert_true(child.contains(base + 63))
    assert_false(parent.contains(base + 63))
    assert_true(parent.contains(base + 62))
    assert_false(child.contains(base + 62))
    assert_eq(child.reads[32], base + 63)
    assert_eq(parent.reads[32], base + 62)
  }
}

///|
test "cleanup read copies detach overflow indexes across sibling updates" {
  let values = Array::makei(9, fn(index) { index }) +
    [64, 95, 96, 127, 2147483647, -1]
  let parent = SlCleanupReadSet::new(values.copy())
  assert_true(parent.contains(-1))
  let child = parent.copy()
  assert_eq(child.bits, parent.bits)
  assert_eq(child.word, parent.word)
  guard child.members is Some(child_members) else {
    fail("expected the copied overflow membership index")
  }
  let parent_members = parent.members.unwrap()
  assert_eq(child_members, parent_members)
  assert_true(physical_equal(child_members, parent_members))
  parent.insert(67)
  assert_true(parent.contains(67))
  assert_false(child.contains(67))
  child.insert(65)
  parent.insert(66)
  child.insert(-2)
  parent.insert(2147483646)
  assert_false(physical_equal(child.members.unwrap(), parent.members.unwrap()))
  for read in values {
    assert_true(child.contains(read))
    assert_true(parent.contains(read))
  }
  for read in [65, -2] {
    assert_true(child.contains(read))
    assert_false(parent.contains(read))
  }
  for read in [66, 2147483646] {
    assert_true(parent.contains(read))
    assert_false(child.contains(read))
  }
  let grandchild = child.copy()
  grandchild.insert(1000)
  assert_true(grandchild.contains(1000))
  assert_false(child.contains(1000))
  assert_false(parent.contains(1000))
  child.insert(1001)
  assert_false(grandchild.contains(1001))
}

///|
test "cleanup read copies preserve lazy tiny and unqueried membership" {
  for width in [0, 1, 8, 32] {
    let parent = SlCleanupReadSet::new(Array::makei(width, fn(index) { index }))
    let child = parent.copy()
    assert_eq(child.bits, 0UL)
    assert_true(child.members is None)
    assert_eq(child.reads, parent.reads)
    child.insert(1000)
    assert_false(parent.contains(1000))
    assert_true(child.contains(1000))
  }
  let duplicate = SlCleanupReadSet::new([4, 4])
  let child = duplicate.copy()
  child.insert(6)
  assert_eq(duplicate.reads, [4, 4])
  assert_eq(child.reads, [4, 4, 6])
}

///|
test "cached continuation copies keep loop reads out of sibling cleanup" {
  for
    (local_type, producer) in [
      ("i32", "i32.const 7"),
      ("i32", "i32.const 1 i32.const 0 i32.div_s"),
      ("(ref null $s)", "ref.null $s"),
    ] {
    let types = Array::make(64, "i32").join(" ") +
      " " +
      local_type +
      " " +
      Array::make(63, "i32").join(" ")
    let input = pass_test_module_from_wat(
      "(module (type $s (struct (field i32))) (func (param i32) (local \{types}) local.get 0 if loop local.get 65 drop end else \{producer} local.set 65 local.get 65 drop end))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let inherited = SlCleanupReadSet::new(
      Array::makei(32, fn(index) { index }) + [64, 128],
    )
    assert_true(inherited.contains(128))
    let saved_members = inherited.members.unwrap().copy()
    let actual = sl_cleanup_drop_dead_pairs_with_reads(body, inherited)
    guard body[1] is @lib.If(_, then_body, Some(else_body)) else {
      fail("expected source conditional")
    }
    guard actual[1] is @lib.If(_, actual_then, Some(actual_else)) else {
      fail("expected cleaned conditional")
    }
    assert_eq(actual_then, then_body)
    assert_eq(
      actual_else,
      else_body[0:else_body.length() - 3].to_owned() +
      [@lib.Instruction::drop()],
    )
    assert_false(inherited.contains(65))
    assert_eq(inherited.members.unwrap(), saved_members)
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
