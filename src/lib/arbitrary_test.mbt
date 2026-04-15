///|
test "arbitrary ref types stay in binary-roundtrippable canonical form" {
  let state = @splitmix.new(seed=0x5eedUL)
  for _ in 0..<512 {
    let rt : RefType = @quickcheck.Arbitrary::arbitrary(8, state)
    match rt {
      HeapTypeRefType(true, false, AbsHeapTypeHeapType(_)) =>
        fail("expected canonical nullable abstract ref type")
      HeapTypeRefType(_, true, AbsHeapTypeHeapType(_)) =>
        fail("expected arbitrary ref type to avoid exact abstract heap types")
      _ => ()
    }
  }
}

///|
test "arbitrary ref.null instructions always use nullable ref types" {
  let state = @splitmix.new(seed=0x51eedUL)
  for _ in 0..<1024 {
    let instr : Instruction = @quickcheck.Arbitrary::arbitrary(8, state)
    match instr {
      RefNull(rt) => assert_true(rt.is_nullable())
      _ => ()
    }
  }
}
