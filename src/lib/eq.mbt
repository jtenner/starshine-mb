///|
pub impl Eq for Module with equal(l, r) {
  let l_custom = l.0
  let r_custom = r.0
  if l_custom.length() != r_custom.length() {
    return false
  }
  for lc in l_custom {
    if !r_custom.contains(lc) {
      return false
    }
  }
  for rc in r_custom {
    if !l_custom.contains(rc) {
      return false
    }
  }
  l.1 == r.1 &&
  l.2 == r.2 &&
  l.3 == r.3 &&
  l.4 == r.4 &&
  l.5 == r.5 &&
  l.6 == r.6 &&
  l.7 == r.7 &&
  l.8 == r.8 &&
  l.9 == r.9 &&
  l.10 == r.10 &&
  l.11 == r.11 &&
  l.12 == r.12 &&
  l.13 == r.13
}

///|
pub impl Eq for RecType with equal(l, r) {
  match (l, r) {
    (SingleRecType(stl), GroupRecType([str])) => stl == str
    (GroupRecType([stl]), SingleRecType(str)) => stl == str
    (SingleRecType(stl), SingleRecType(str)) => stl == str
    (GroupRecType(stl), GroupRecType(str)) => stl == str
    _ => false
  }
}

///|
pub impl Eq for RefType with equal(l, r) {
  match (l, r) {
    (HeapTypeRefType(l0, l1), HeapTypeRefType(r0, r1)) => l0 == r0 && l1 == r1
    (AbsHeapTypeRefType(l0), AbsHeapTypeRefType(r0)) => l0 == r0
    (AbsHeapTypeRefType(l0), HeapTypeRefType(true, AbsHeapTypeHeapType(r0))) =>
      l0 == r0
    (HeapTypeRefType(true, AbsHeapTypeHeapType(l0)), AbsHeapTypeRefType(r0)) =>
      l0 == r0
    _ => false
  }
}

///|
pub impl Eq for MemArg with equal(l, r) {
  l.0 == r.0 &&
  l.1.unwrap_or(MemIdx(0)) == r.1.unwrap_or(MemIdx(0)) &&
  l.2 == r.2
}

///|
test "RecType equality edge cases" {
  let st = CompTypeSubType(FuncCompType([], []))

  // SingleRecType should equal GroupRecType with single element
  assert_eq(SingleRecType(st), GroupRecType([st]))
  assert_eq(GroupRecType([st]), SingleRecType(st))

  // But different subtypes should not be equal
  let st2 = CompTypeSubType(FuncCompType([NumTypeValType(I32NumType)], []))
  assert_not_eq(SingleRecType(st), SingleRecType(st2))
  assert_not_eq(SingleRecType(st), GroupRecType([st2]))

  // Multiple elements should not equal single
  assert_not_eq(GroupRecType([st, st]), SingleRecType(st))
}

///|
test "RefType equality edge cases" {
  // AbsHeapTypeRefType should equal HeapTypeRefType with nullable + AbsHeapTypeHeapType
  assert_eq(
    AbsHeapTypeRefType(FuncAbsHeapType),
    HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
  )
  assert_eq(
    HeapTypeRefType(true, AbsHeapTypeHeapType(ExternAbsHeapType)),
    AbsHeapTypeRefType(ExternAbsHeapType),
  )

  // Non-nullable should NOT equal AbsHeapTypeRefType
  assert_not_eq(
    AbsHeapTypeRefType(FuncAbsHeapType),
    HeapTypeRefType(false, AbsHeapTypeHeapType(FuncAbsHeapType)),
  )

  // Different heap types should not be equal
  assert_not_eq(
    AbsHeapTypeRefType(FuncAbsHeapType),
    AbsHeapTypeRefType(ExternAbsHeapType),
  )
  assert_not_eq(
    AbsHeapTypeRefType(FuncAbsHeapType),
    HeapTypeRefType(true, AbsHeapTypeHeapType(ExternAbsHeapType)),
  )
}

///|
test "MemArg equality edge cases" {
  // None memidx should equal Some(MemIdx(0))
  assert_eq(
    MemArg(U32(0), None, U64(0)),
    MemArg(U32(0), Some(MemIdx(0)), U64(0)),
  )
  assert_eq(
    MemArg(U32(4), None, U64(8)),
    MemArg(U32(4), Some(MemIdx(0)), U64(8)),
  )

  // But Some(MemIdx(1)) should NOT equal None
  assert_not_eq(
    MemArg(U32(0), None, U64(0)),
    MemArg(U32(0), Some(MemIdx(1)), U64(0)),
  )

  // Different align/offset should not be equal
  assert_not_eq(MemArg(U32(0), None, U64(0)), MemArg(U32(1), None, U64(0)))
  assert_not_eq(MemArg(U32(0), None, U64(0)), MemArg(U32(0), None, U64(1)))
}

///|
test "HeapType equality - verify transformer changes are detected" {
  // These should NOT be equal - this is what HeapTypeSwap produces
  let before : HeapType = AbsHeapTypeHeapType(FuncAbsHeapType)
  let after : HeapType = AbsHeapTypeHeapType(ExternAbsHeapType)
  assert_not_eq(before, after)

  // TypeIdx changes should be detected
  let idx_before : HeapType = HeapType(TypeIdx(0))
  let idx_after : HeapType = HeapType(TypeIdx(1000))
  assert_not_eq(idx_before, idx_after)
}

///|
test "RefType with transformed HeapType should not be equal" {
  // The transformer changes HeapType inside RefType
  let before = HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType))
  let after = HeapTypeRefType(true, AbsHeapTypeHeapType(ExternAbsHeapType))
  assert_not_eq(before, after)

  // But AbsHeapTypeRefType doesn't contain HeapType - verify these are different
  let abs_func = AbsHeapTypeRefType(FuncAbsHeapType)
  let abs_extern = AbsHeapTypeRefType(ExternAbsHeapType)
  assert_not_eq(abs_func, abs_extern)
}
