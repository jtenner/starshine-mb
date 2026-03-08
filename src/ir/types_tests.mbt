///|
test "GVNKey struct-get hashing preserves type and field identity" {
  let key0 = GVNKey::StructGet(TypeIdx::new(0), U32(0), SSAValue(0))
  let key1 = GVNKey::StructGet(TypeIdx::new(1), U32(0), SSAValue(0))
  let key2 = GVNKey::StructGet(TypeIdx::new(0), U32(1), SSAValue(0))
  let map : Map[GVNKey, Int] = {}
  map[key0] = 10
  map[key1] = 20
  map[key2] = 30
  assert_eq(map[key0], 10)
  assert_eq(map[key1], 20)
  assert_eq(map[key2], 30)
}

///|
test "GVNKey array-get hashing preserves array type index identity" {
  let key0 = GVNKey::ArrayGet(TypeIdx::new(0), SSAValue(0), SSAValue(1))
  let key1 = GVNKey::ArrayGet(TypeIdx::new(1), SSAValue(0), SSAValue(1))
  let map : Map[GVNKey, Int] = {}
  map[key0] = 1
  map[key1] = 2
  assert_eq(map[key0], 1)
  assert_eq(map[key1], 2)
}
