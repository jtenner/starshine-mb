///|
fn dae2_local_index_order_fixture(
  named : Bool,
  retained~ : Int32 = 130,
) -> @lib.Module {
  let source = StringBuilder()
  source.write_string(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (local",
  )
  for _ in 0..<(retained + 1) {
    source.write_string(" i32")
  }
  source.write_string(")")
  for index in 1..<(retained + 1) {
    source.write_string(" i32.const \{index} local.set \{index}")
  }
  for _ in 0..<2 {
    for index in 1..<(retained + 1) {
      source.write_string(" local.get \{index} call $consume")
    }
  }
  for _ in 0..<32 {
    source.write_string(" local.get \{retained} call $consume")
  }
  source.write_string("))")
  let input = pass_test_module_from_wat(source.to_string())
  if !named {
    return input.without_name_sec()
  }
  input.with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::new("parameter")),
              @lib.NameAssoc::new(127U, @lib.Name::new("edge")),
              @lib.NameAssoc::new(130U, @lib.Name::new("hot")),
              @lib.NameAssoc::new(131U, @lib.Name::new("unused")),
            ]),
          ),
        ]),
      ),
    ),
  )
}

///|
test "DAE2 compaction gives frequent same-type locals short indices with stable ties and names" {
  for named in [false, true] {
    let input = dae2_local_index_order_fixture(named)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let indices = Array::makei(132, fn(index) {
      if index == 0 {
        0
      } else if index == 130 {
        1
      } else if index == 131 {
        -1
      } else {
        index + 1
      }
    })
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let reference = input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types(Array::make(130, @lib.ValType::i32())),
          @lib.Expr::new(pass_lower_remap_locals(body, indices)),
        ),
      ]),
    )
    let reference = match
      rl_rewrite_name_sec(input.name_sec, 1, [Some(indices)]) {
      Some(names) => reference.with_name_sec(names)
      None => reference.without_name_sec()
    }
    let output = dae2_cleanup_captures(input)
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_true(
      @binary.encode_module(output).unwrap().length() < saved.length(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 frequency ordering retains its map when partial local names would grow" {
  let input = dae2_local_index_order_fixture(false).with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(127U, @lib.Name::new("edge")),
            ]),
          ),
        ]),
      ),
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let indices = Array::makei(132, fn(index) {
    if index == 131 {
      -1
    } else {
      index
    }
  })
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let reference = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types(Array::make(130, @lib.ValType::i32())),
        @lib.Expr::new(pass_lower_remap_locals(body, indices)),
      ),
    ]),
  )
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  assert_eq(output.name_sec, input.name_sec)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 frequency ordering keeps short indices mixed types and equal-cost ties" {
  for mode in 0..<3 {
    let count = if mode == 0 { 16 } else { 130 }
    let indices = Array::makei(count, fn(index) { index })
    let reads = Array::make(count, 2)
    let writes = Array::make(count, 1)
    let types = Array::make(count, @lib.ValType::i32())
    if mode == 1 {
      reads[count - 1] = 99
      types[count - 1] = @lib.ValType::i64()
    }
    let saved = indices.copy()
    assert_false(
      dae2_order_compacted_local_indices(
        indices,
        reads,
        writes,
        0,
        types,
        None,
        0,
      ),
    )
    assert_eq(indices, saved)
  }
}
