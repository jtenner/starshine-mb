///|
fn dae2_local_index_order_bench(
  it : @bench.T,
  count : Int32,
  reorder : Bool,
) -> Unit raise {
  let input = dae2_local_index_order_fixture(false, retained=count)
  let saved = @binary.encode_module(input).unwrap()
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let func = input.code_sec.unwrap().0[0]
  let run = fn(selected) {
    pass_lower_compact_captures_with_map(
      func,
      original,
      [@lib.ValType::i32()],
      propagate_parameter_aliases=true,
      reorder_body_locals=selected,
    )
  }
  let reference = run(false)
  let candidate = run(true)
  let expected = input.with_code_sec(@lib.CodeSec::new([reference.0]))
  let output = input.with_code_sec(@lib.CodeSec::new([candidate.0]))
  @validate.validate_module(output).unwrap()
  let old_bytes = @binary.encode_module(expected).unwrap()
  let new_bytes = @binary.encode_module(output).unwrap()
  if count < 128 {
    assert_eq(new_bytes, old_bytes)
  } else {
    assert_true(new_bytes.length() < old_bytes.length())
  }
  assert_eq(candidate.1[0], 0)
  it.bench(fn() { it.keep(run(reorder)) })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native local-index compaction cost")
test "bench DAE2 local order 16 reference" (it : @bench.T) {
  dae2_local_index_order_bench(it, 16, false)
}

///|
#skip("paired native local-index compaction cost")
test "bench DAE2 local order 16 candidate" (it : @bench.T) {
  dae2_local_index_order_bench(it, 16, true)
}

///|
#skip("paired native local-index compaction cost")
test "bench DAE2 local order 128 reference" (it : @bench.T) {
  dae2_local_index_order_bench(it, 128, false)
}

///|
#skip("paired native local-index compaction cost")
test "bench DAE2 local order 128 candidate" (it : @bench.T) {
  dae2_local_index_order_bench(it, 128, true)
}

///|
#skip("paired native local-index compaction cost")
test "bench DAE2 local order 256 reference" (it : @bench.T) {
  dae2_local_index_order_bench(it, 256, false)
}

///|
#skip("paired native local-index compaction cost")
test "bench DAE2 local order 256 candidate" (it : @bench.T) {
  dae2_local_index_order_bench(it, 256, true)
}

///|
#skip("paired native local-index compaction cost")
test "bench DAE2 local order 1024 reference" (it : @bench.T) {
  dae2_local_index_order_bench(it, 1024, false)
}

///|
#skip("paired native local-index compaction cost")
test "bench DAE2 local order 1024 candidate" (it : @bench.T) {
  dae2_local_index_order_bench(it, 1024, true)
}
