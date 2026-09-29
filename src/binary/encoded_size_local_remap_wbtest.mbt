///|
fn encoded_local_remap_fixture(
  width : Int,
  index : UInt,
  nested : Bool,
) -> Func {
  let local = LocalIdx::new(index)
  let access = [
    Instruction::local_get(local),
    Instruction::local_set(local),
    Instruction::local_get(local),
    Instruction::local_tee(local),
    Instruction::drop(),
  ]
  let body = Array::make(width, Instruction::nop())
  if nested {
    body.push(Instruction::block(BlockType::void_(), Expr::new(access)))
    body.push(Instruction::loop_(BlockType::void_(), Expr::new(access)))
    body.push(Instruction::i32_const(1))
    body.push(Instruction::if_(BlockType::void_(), access, Some(access)))
    body.push(Instruction::try_table(BlockType::void_(), [], Expr::new(access)))
  } else {
    for instruction in access {
      body.push(instruction)
    }
  }
  Func::new(Locals::single(130U, ValType::i32()), Expr::new(body))
}

///|
fn encoded_local_remap_module(func : Func) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_code_sec(CodeSec::new([func]))
}

///|
test "exact sizing reuses local remaps across body and local index LEB boundaries" {
  for width in [0, 111, 112, 113, 114, 115, 127, 128] {
    let before = encoded_local_remap_fixture(width, 127U, false)
    let after = encoded_local_remap_fixture(width, 128U, false)
    let first = EncodedModuleSizeState::new(None)
    measure_module_code([before], [], first).unwrap()
    let second = EncodedModuleSizeState::new(Some(first))
    let emissions = [0]
    measure_module_code([after], [], second, expression_encodes=Some(emissions)).unwrap()
    let expected = @buffer.new()
    Encode::encode(after, expected).unwrap()
    assert_eq(second.sizes, [expected.length()])
    let before_module = encoded_local_remap_module(before)
    let after_module = encoded_local_remap_module(after)
    @validate.validate_module(before_module).unwrap()
    @validate.validate_module(after_module).unwrap()
    assert_eq(
      encoded_module_sizes(before_module, after_module).unwrap(),
      (
        encode_module(before_module).unwrap().length(),
        encode_module(after_module).unwrap().length(),
      ),
    )
    assert_eq(emissions[0], 0)
  }
}

///|
test "exact local remap sizing covers nested controls and declaration changes" {
  let before = encoded_local_remap_fixture(1, 127U, true)
  let Func(_, expr) = encoded_local_remap_fixture(1, 128U, true)
  let after = Func::new(
    Locals::from_types(Array::make(131, ValType::i32())),
    expr,
  )
  let first = EncodedModuleSizeState::new(None)
  measure_module_code([before], [], first).unwrap()
  let saved = first.sizes.copy()
  let second = EncodedModuleSizeState::new(Some(first))
  let emissions = [0]
  measure_module_code([after], [], second, expression_encodes=Some(emissions)).unwrap()
  let expected = @buffer.new()
  Encode::encode(after, expected).unwrap()
  assert_eq(second.sizes, [expected.length()])
  assert_eq(first.sizes, saved)
  @validate.validate_module(encoded_local_remap_module(before)).unwrap()
  @validate.validate_module(encoded_local_remap_module(after)).unwrap()
  assert_eq(emissions[0], 0)
}

///|
test "local remap size reuse retains full encoding for changed operations and invalid types" {
  let before = encoded_local_remap_fixture(0, 127U, false)
  let first = EncodedModuleSizeState::new(None)
  measure_module_code([before], [], first).unwrap()
  let changed = Func::new(Locals::empty(), Expr::new([Instruction::nop()]))
  let second = EncodedModuleSizeState::new(Some(first))
  let emissions = [0]
  measure_module_code([changed], [], second, expression_encodes=Some(emissions)).unwrap()
  let expected = @buffer.new()
  Encode::encode(changed, expected).unwrap()
  assert_eq(second.sizes, [expected.length()])
  assert_eq(emissions[0], 1)
  // Bottom-valued declarations and select types are intentionally invalid.
  for
    invalid in [
      Func::new(Locals::from_types([ValType::bottom()]), Expr::new([])),
      Func::new(
        Locals::empty(),
        Expr::new([Instruction::select(types=Some([ValType::bottom()]))]),
      ),
    ] {
    let reference = Encode::encode(invalid, @buffer.new())
    assert_true(reference is Err(_))
    assert_eq(
      measure_module_code(
        [invalid],
        [],
        EncodedModuleSizeState::new(Some(first)),
      ),
      reference,
    )
  }
}

///|
test "local remap size reuse invalidates changed string pool indices" {
  let strings = Array::makei(128, fn(i) { @utf8.encode("literal-\{i}") })
  let later = [b"inserted"]
  for literal in strings {
    later.push(literal)
  }
  let funcs = [127U, 128U].map(fn(index) {
    Func::new(
      Locals::single(130U, ValType::i32()),
      Expr::new([
        Instruction::local_get(LocalIdx::new(index)),
        Instruction::drop(),
        Instruction::string_const(strings[127]),
        Instruction::drop(),
      ]),
    )
  })
  let first = EncodedModuleSizeState::new(None)
  with_binary_encode_stringrefs_context(Some(strings), fn() {
    measure_module_code([funcs[0]], strings, first)
  }).unwrap()
  let second = EncodedModuleSizeState::new(Some(first))
  let emissions = [0]
  with_binary_encode_stringrefs_context(Some(later), fn() {
    measure_module_code(
      [funcs[1]],
      later,
      second,
      expression_encodes=Some(emissions),
    )
  }).unwrap()
  let expected = @buffer.new()
  with_binary_encode_stringrefs_context(Some(later), fn() {
    Encode::encode(funcs[1], expected)
  }).unwrap()
  assert_eq(second.sizes, [expected.length()])
  assert_eq(emissions[0], 1)
  assert_eq(second.sizes[0] - first.sizes[0], 2)
}

///|
test "local remap delta matches unsigned local index encoding widths" {
  let indices = [
    0U, 127U, 128U, 16383U, 16384U, 2097151U, 2097152U, 268435455U, 268435456U, 0xffffffffU,
  ]
  for old in indices {
    for next in indices {
      let left = Instruction::local_get(LocalIdx::new(old))
      let right = Instruction::local_get(LocalIdx::new(next))
      let a = @buffer.new()
      let b = @buffer.new()
      Encode::encode(left, a).unwrap()
      Encode::encode(right, b).unwrap()
      assert_eq(
        encoded_local_remap_size_delta([left], [right]),
        Some(b.length() - a.length()),
      )
    }
  }
  // These custom semantic equalities must also preserve canonical encoding.
  // Resolved DefType heap types are unencodable and cannot seed the size cache.
  let short = RefType::abs(AbsHeapType::func())
  let expanded = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let absent = @lib.MemArg::new(U32(2U), None, U64(0UL))
  let explicit = @lib.MemArg::new(U32(2U), Some(@lib.MemIdx::new(0U)), U64(0UL))
  for
    pair in [
      (Instruction::i32_load(absent), Instruction::i32_load(explicit)),
      (Instruction::ref_null_type(short), Instruction::ref_null_type(expanded)),
      (
        Instruction::select(types=Some([ValType::ref_type(short)])),
        Instruction::select(types=Some([ValType::ref_type(expanded)])),
      ),
    ] {
    let (left, right) = pair
    assert_eq(left, right)
    let a = @buffer.new()
    let b = @buffer.new()
    Encode::encode(left, a).unwrap()
    Encode::encode(right, b).unwrap()
    assert_eq(a.to_bytes(), b.to_bytes())
    assert_eq(encoded_local_remap_size_delta([left], [right]), Some(0))
  }
}

///|
test "legacy try remaps intentionally use complete body encoding" {
  let funcs = [127U, 128U].map(fn(index) {
    Func::new(
      Locals::single(130U, ValType::i32()),
      Expr::new([
        Instruction::try_(
          BlockType::void_(),
          Expr::new([
            Instruction::local_get(LocalIdx::new(index)),
            Instruction::drop(),
          ]),
          [@lib.LegacyCatch::all(Expr::new([]))],
        ),
      ]),
    )
  })
  let first = EncodedModuleSizeState::new(None)
  measure_module_code([funcs[0]], [], first).unwrap()
  let second = EncodedModuleSizeState::new(Some(first))
  let emissions = [0]
  measure_module_code(
    [funcs[1]],
    [],
    second,
    expression_encodes=Some(emissions),
  ).unwrap()
  let expected = @buffer.new()
  Encode::encode(funcs[1], expected).unwrap()
  assert_eq(second.sizes, [expected.length()])
  assert_eq(emissions[0], 1)
  @validate.validate_module(encoded_local_remap_module(funcs[1])).unwrap()
}
