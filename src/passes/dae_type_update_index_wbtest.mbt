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

///|
test "dae lookup group absolutization preserves reference bounds and flags" {
  let group = Array::make(
    3,
    @lib.SubType::comp_type(@lib.CompType::struct_([])),
  )
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(group[0]),
    @lib.RecType::group(group),
    @lib.RecType::new(group[0]),
  ])
  for (base, length) in [(0, 1), (1, 3), (4, 1)] {
    for member in 0..<length {
      for nullable in [false, true] {
        for exact in [false, true] {
          let value = @lib.ValType::ref_type(
            @lib.RefType::new(
              nullable,
              @lib.HeapType::new(@lib.rec_idx(member.reinterpret_as_uint())),
              exact~,
            ),
          )
          let expected = @lib.ValType::ref_type(
            @lib.RefType::new(
              nullable,
              @lib.HeapType::new(
                @lib.TypeIdx::new((base + member).reinterpret_as_uint()),
              ),
              exact~,
            ),
          )
          assert_eq(
            dae_absolutize_lookup_signature_val_type(base, length, value),
            expected,
          )
          for owner in base..<(base + length) {
            assert_eq(
              dae_absolutize_signature_val_type(
                type_sec,
                @lib.TypeIdx::new(owner.reinterpret_as_uint()),
                value,
              ),
              expected,
            )
          }
        }
      }
    }
    for
      value in [
        @lib.ValType::i32(),
        @lib.ValType::f64(),
        @lib.ValType::ref_type(
          @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(99U))),
        ),
      ] {
      assert_eq(
        dae_absolutize_lookup_signature_val_type(base, length, value),
        value,
      )
    }
  }
}

///|
test "dae lookup keeps first signatures across late recursive groups" {
  let groups : Array[@lib.RecType] = []
  let relative_param = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.rec_idx(0U))),
  )
  let relative_result = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.rec_idx(2U)), exact=true),
  )
  let signature = @lib.SubType::comp_type(
    @lib.CompType::func([relative_param], [relative_result]),
  )
  for _ in 0..<12 {
    groups.push(
      @lib.RecType::group([
        @lib.SubType::comp_type(@lib.CompType::struct_([])),
        signature,
        signature,
      ]),
    )
  }
  let singleton_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.rec_idx(0U))),
  )
  groups.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [singleton_ref])),
    ),
  )
  let absolute_param = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let absolute_result = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(2U)),
      exact=true,
    ),
  )
  groups.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([absolute_param], [absolute_result]),
      ),
    ),
  )
  for _ in 0..<2 {
    groups.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i64()])),
      ),
    )
  }
  let type_sec = @lib.TypeSec::new(groups)
  let index = DaeTypeUpdateIndex::new(type_sec)
  assert_eq(index.flat_count, 40)
  assert_eq(index.signatures.length(), 14)
  for group in 0..<12 {
    let owner = @lib.TypeIdx::new((group * 3 + 1).reinterpret_as_uint())
    let (params, results) = dae_absolutize_signature(
      type_sec,
      owner,
      [relative_param],
      [relative_result],
    )
    assert_eq(
      index.signatures.get(dae_simple_func_type_key(params, results)),
      Some(owner),
    )
    // Relative heap indices are not directly encodable. Check the borrowed
    // signature fields instead, including the duplicate member's arrays.
    for member in [1, 2] {
      assert_eq(
        dae_type_sec_func_type(
          type_sec,
          @lib.TypeIdx::new((group * 3 + member).reinterpret_as_uint()),
        ),
        Some(@lib.FuncType::new([relative_param], [relative_result])),
      )
    }
  }
  let (_, singleton_results) = dae_absolutize_signature(
    type_sec,
    @lib.TypeIdx::new(36U),
    [],
    [singleton_ref],
  )
  assert_eq(
    index.signatures.get(dae_simple_func_type_key([], singleton_results)),
    Some(@lib.TypeIdx::new(36U)),
  )
  assert_eq(
    index.signatures.get(
      dae_simple_func_type_key([absolute_param], [absolute_result]),
    ),
    Some(@lib.TypeIdx::new(1U)),
  )
  assert_eq(
    index.signatures.get(dae_simple_func_type_key([], [@lib.ValType::i64()])),
    Some(@lib.TypeIdx::new(38U)),
  )
  assert_eq(
    dae_type_sec_func_type(type_sec, @lib.TypeIdx::new(36U)),
    Some(@lib.FuncType::new([], [singleton_ref])),
  )
  assert_eq(groups.length(), 16)
}

///|
test "panic dae lookup rejects an invalid singleton relative reference" {
  // RecIdx(1) is invalid in a singleton, even if a following type exists.
  let invalid = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.rec_idx(1U))),
  )
  let _ = dae_simple_func_type_lookup(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([invalid], [])),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
    ]),
  )
}

///|
test "panic dae lookup rejects a relative reference at the group length" {
  // The owner is member 1; using its index as the base would accept this.
  let invalid = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.rec_idx(2U))),
  )
  let _ = dae_simple_func_type_lookup(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
      @lib.RecType::group([
        @lib.SubType::comp_type(@lib.CompType::struct_([])),
        @lib.SubType::comp_type(@lib.CompType::func([], [invalid])),
      ]),
    ]),
  )
}

///|
test "panic dae lookup rejects a relative reference with a negative signed slot" {
  // Reinterpreting this malformed unsigned member gives -1.
  let invalid = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.rec_idx(0xffffffffU))),
  )
  let _ = dae_simple_func_type_lookup(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [invalid])),
      ),
    ]),
  )
}
