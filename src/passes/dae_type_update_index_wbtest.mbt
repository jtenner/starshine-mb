///|
fn dae_test_recursive_payload_type_sec(include_existing : Bool) -> @lib.TypeSec {
  let payload_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.rec_idx(0U))),
  )
  let group = [@lib.SubType::comp_type(@lib.CompType::struct_([]))]
  if include_existing {
    group.push(@lib.SubType::comp_type(@lib.CompType::func([], [payload_ref])))
  }
  group.push(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [payload_ref]),
    ),
  )
  @lib.TypeSec::new([@lib.RecType::group(group)])
}

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

///|
test "dae batch type updates absolutize recursive group references" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (rec
      #|    (type $payload (struct))
      #|    (type $callee
      #|      (func (param i32) (result (ref null $payload)))))
      #|  (func (type $callee) (param i32) (result (ref null $payload))
      #|    ref.null $payload))
      #|
    ),
  ).with_type_sec(dae_test_recursive_payload_type_sec(false))
  let original_types = input.type_sec.unwrap()
  let original_indices = input.func_sec.unwrap().0
  let original_result = dae_type_sec_func_type(
      original_types,
      original_indices[0],
    ).unwrap().1[0]
  match original_result {
    @lib.RefTypeValType(
      @lib.HeapTypeRefType(_, _, @lib.HeapType(@lib.RecIdx(0U)))
    ) => ()
    other => fail("expected group-relative payload result, got {other}")
  }
  let type_indices = original_indices.copy()
  let index = DaeTypeUpdateIndex::new(original_types)
  let (next_types, next_idx) = dae_update_defined_func_type(
    input,
    original_types,
    type_indices,
    0,
    [],
    [original_result],
    type_update_index=Some(index),
  )
  type_indices[0] = next_idx
  let output = input
    .with_type_sec(next_types)
    .with_func_sec(@lib.FuncSec::new(type_indices))
  @validate.validate_module(output).unwrap()
  let result = dae_type_sec_func_type(next_types, next_idx).unwrap().1[0]
  match result {
    @lib.RefTypeValType(
      @lib.HeapTypeRefType(_, _, @lib.HeapType(@lib.TypeIdx(0U)))
    ) => ()
    other => fail("expected absolute payload result, got {other}")
  }
}

///|
test "dae batch type cache matches recursive signatures by absolute owner" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (rec
      #|    (type $payload (struct))
      #|    (type $existing (func (result (ref null $payload))))
      #|    (type $callee
      #|      (func (param i32) (result (ref null $payload)))))
      #|  (func (type $callee) (param i32) (result (ref null $payload))
      #|    ref.null $payload))
      #|
    ),
  ).with_type_sec(dae_test_recursive_payload_type_sec(true))
  let type_sec = input.type_sec.unwrap()
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("expected recursive cache input to validate, got \{err}")
  }
  let func_types = input.func_sec.unwrap().0.copy()
  let @lib.FuncType(_, results) = dae_type_sec_func_type(
    type_sec,
    func_types[0],
  ).unwrap()
  let index = DaeTypeUpdateIndex::new(type_sec)
  let (next_types, next_idx) = dae_update_defined_func_type(
    input,
    type_sec,
    func_types,
    0,
    [],
    results,
    type_update_index=Some(index),
  )
  assert_eq(next_idx, @lib.TypeIdx::new(1U))
  assert_eq(next_types, type_sec)
}
