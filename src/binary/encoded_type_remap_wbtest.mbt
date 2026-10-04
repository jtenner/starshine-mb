///|
fn encoded_type_remap_fixture(index : UInt, width : Int) -> Func {
  let bt = BlockType::type_idx(TypeIdx::new(index))
  let body = Array::make(width, Instruction::nop())
  Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::block(bt, Expr::new(body)),
      Instruction::loop_(bt, Expr::new(body)),
      Instruction::i32_const(1),
      Instruction::if_(bt, body, Some(body)),
      Instruction::try_table(bt, [], Expr::new(body)),
    ]),
  )
}

///|
test "exact type-index deltas preserve signed control and unsigned call widths" {
  let indices = [
    0U, 63U, 64U, 127U, 128U, 8191U, 8192U, 16383U, 16384U, 0xffffffffU,
  ]
  for old in indices {
    for next in indices {
      let a = TypeIdx::new(old)
      let b = TypeIdx::new(next)
      let empty = Expr::new([])
      for
        pair in [
          (
            Instruction::block(BlockType::type_idx(a), empty),
            Instruction::block(BlockType::type_idx(b), empty),
          ),
          (
            Instruction::loop_(BlockType::type_idx(a), empty),
            Instruction::loop_(BlockType::type_idx(b), empty),
          ),
          (
            Instruction::if_(BlockType::type_idx(a), [], None),
            Instruction::if_(BlockType::type_idx(b), [], None),
          ),
          (
            Instruction::try_table(BlockType::type_idx(a), [], empty),
            Instruction::try_table(BlockType::type_idx(b), [], empty),
          ),
          (
            Instruction::call_indirect(a, TableIdx::new(0U)),
            Instruction::call_indirect(b, TableIdx::new(0U)),
          ),
          (
            Instruction::return_call_indirect(a, TableIdx::new(0U)),
            Instruction::return_call_indirect(b, TableIdx::new(0U)),
          ),
          (Instruction::call_ref(a), Instruction::call_ref(b)),
          (Instruction::return_call_ref(a), Instruction::return_call_ref(b)),
        ] {
        let (left, right) = pair
        let before = @buffer.new()
        let after = @buffer.new()
        Encode::encode(left, before).unwrap()
        Encode::encode(right, after).unwrap()
        assert_eq(
          encoded_local_remap_size_delta([left], [right]),
          Some(after.length() - before.length()),
        )
      }
    }
  }
}

///|
test "exact type-remap sizing retains body and section framing with owned snapshots" {
  for width in [0, 22, 23, 24, 125, 126, 127, 128] {
    for pair in [(63U, 64U), (127U, 128U), (128U, 63U)] {
      let (old, next) = pair
      let before = encoded_type_remap_fixture(old, width)
      let after = encoded_type_remap_fixture(next, width)
      let types = TypeSec::new(
        Array::make(
          129,
          RecType::new(SubType::comp_type(CompType::func([], []))),
        ),
      )
      let a = encoded_local_remap_module(before).with_type_sec(types)
      let b = encoded_local_remap_module(after).with_type_sec(types)
      @validate.validate_module(a).unwrap()
      @validate.validate_module(b).unwrap()
      let saved = encode_module(a).unwrap()
      assert_eq(
        encoded_module_sizes(a, b).unwrap(),
        (saved.length(), encode_module(b).unwrap().length()),
      )
      assert_eq(encode_module(a).unwrap(), saved)
    }
  }
}

///|
test "type-index sizing intentionally falls back for different table and control shapes" {
  let a = TypeIdx::new(63U)
  let b = TypeIdx::new(64U)
  assert_eq(
    encoded_local_remap_size_delta(
      [Instruction::call_indirect(a, TableIdx::new(0U))],
      [Instruction::call_indirect(b, TableIdx::new(1U))],
    ),
    None,
  )
  assert_eq(
    encoded_local_remap_size_delta(
      [Instruction::if_(BlockType::type_idx(a), [], None)],
      [Instruction::if_(BlockType::type_idx(b), [], Some([]))],
    ),
    None,
  )
  assert_eq(
    encoded_local_remap_size_delta(
      [
        Instruction::block(
          BlockType::type_idx(a),
          Expr::new([Instruction::nop()]),
        ),
      ],
      [
        Instruction::block(
          BlockType::type_idx(b),
          Expr::new([Instruction::unreachable_()]),
        ),
      ],
    ),
    None,
  )
}

///|
test "type-remap reuse intentionally rejects unencodable recursive indices" {
  let valid = TypeIdx::new(0U)
  let invalid = TypeIdx::rec(0U)
  let table = TableIdx::new(0U)
  let body = Expr::new([])
  for
    pair in [
      (
        Instruction::block(BlockType::type_idx(valid), body),
        Instruction::block(BlockType::type_idx(invalid), body),
      ),
      (
        Instruction::call_indirect(valid, table),
        Instruction::call_indirect(invalid, table),
      ),
      (
        Instruction::return_call_indirect(valid, table),
        Instruction::return_call_indirect(invalid, table),
      ),
      (Instruction::call_ref(valid), Instruction::call_ref(invalid)),
      (
        Instruction::return_call_ref(valid),
        Instruction::return_call_ref(invalid),
      ),
    ] {
    let (left, right) = pair
    let before = Func::new(Locals::empty(), Expr::new([left]))
    let after = Func::new(Locals::empty(), Expr::new([right]))
    let first = EncodedModuleSizeState::new(None)
    measure_module_code([before], [], first).unwrap()
    let reference = Encode::encode(after, @buffer.new())
    assert_true(reference is Err(_))
    assert_eq(
      measure_module_code([after], [], EncodedModuleSizeState::new(Some(first))),
      reference,
    )
  }
}
