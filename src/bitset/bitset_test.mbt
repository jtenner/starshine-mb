///|
fn bitset_test_collect(values : BitSet) -> Array[Bool] {
  let out : Array[Bool] = []
  for i = 0; i < values.length(); i = i + 1 {
    out.push(values[i])
  }
  out
}

///|
fn bitset_test_mark(values : BitSet, index : Int, value : Bool) -> Unit {
  values[index] = value
}

///|
test "bitset supports indexed reads and writes across word boundaries" {
  let values = BitSet::new(130)
  assert_eq(values.length(), 130)
  assert_false(values[0])
  assert_false(values[64])
  assert_false(values[129])

  values[0] = true
  values[64] = true
  values[129] = true

  assert_true(values[0])
  assert_true(values[64])
  assert_true(values[129])

  values[64] = false
  assert_false(values[64])
}

///|
test "bitset copy keeps independent packed values" {
  let values = BitSet::new(130)
  for i = 0; i < values.length(); i = i + 1 {
    values[i] = i % 3 == 0
  }
  let copied = values.copy()
  copied[1] = true
  copied[3] = false

  assert_eq(values.length(), 130)
  assert_eq(copied.length(), 130)
  assert_false(values[1])
  assert_true(copied[1])
  assert_true(values[3])
  assert_false(copied[3])
}

///|
test "bitset make true masks unused trailing bits" {
  let values = BitSet::make(70, true)
  assert_eq(bitset_test_collect(values), Array::make(70, true))
  values[69] = false
  assert_false(values[69])
}

///|
test "bitset mutations survive helper calls" {
  let values = BitSet::new(130)
  bitset_test_mark(values, 1, true)
  bitset_test_mark(values, 65, true)
  assert_true(values[1])
  assert_true(values[65])
  bitset_test_mark(values, 1, false)
  assert_false(values[1])
  assert_true(values[65])
}
