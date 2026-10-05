///|
test "dae batch type updates reuse a signature index without uniqueness scans" {
  let input = signature_lookup_fixture(16)
  let saved = @binary.encode_module(input).unwrap()
  let type_idxs = match input.func_sec {
    Some(@lib.FuncSec(indices)) => indices.copy()
    None => fail("missing function section")
  }
  let mut type_sec = input.type_sec.unwrap()
  let index = DaeTypeUpdateIndex::new(type_sec)
  let scans = [0]
  for def_idx in 0..<type_idxs.length() {
    let params = Array::make(def_idx + 1, @lib.ValType::i64())
    let (next, type_idx) = dae_update_defined_func_type(
      input,
      type_sec,
      type_idxs,
      def_idx,
      params,
      [],
      type_update_index=Some(index),
      unique_scan_count=Some(scans),
    )
    type_sec = next
    type_idxs[def_idx] = type_idx
  }
  assert_eq(scans[0], 0)
  @validate.validate_module(
    input.with_type_sec(type_sec).with_func_sec(@lib.FuncSec::new(type_idxs)),
  ).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
