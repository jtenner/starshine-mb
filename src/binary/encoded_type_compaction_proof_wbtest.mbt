///|
fn encoded_compaction_proof_fixture(
  width : Int32,
  mixed~ : Bool = false,
  type_count~ : Int32 = 2,
) -> (Module, Module) {
  let scalar = Func::new(
    Locals::empty(),
    Expr::new(Array::make(width, Instruction::nop())),
  )
  let bodies = [scalar]
  if mixed {
    bodies.push(
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i32_const(7),
          Instruction::i8x16_splat(),
          Instruction::drop(),
        ]),
      ),
    )
  }
  let before_types = Array::make(
    type_count,
    RecType::new(SubType::comp_type(CompType::func([], []))),
  )
  let after_types = Array::make(
    type_count - 1,
    RecType::new(SubType::comp_type(CompType::func([], []))),
  )
  let before = Module::new()
    .with_type_sec(TypeSec::new(before_types))
    .with_func_sec(
      FuncSec::new(
        Array::make(bodies.length(), TypeIdx::new((type_count - 1).to_uint())),
      ),
    )
    .with_code_sec(CodeSec::new(bodies))
  let after = before
    .with_type_sec(TypeSec::new(after_types))
    .with_func_sec(
      FuncSec::new(
        Array::make(bodies.length(), TypeIdx::new((type_count - 2).to_uint())),
      ),
    )
  (before, after)
}

///|
fn encoded_compaction_proof_assert(
  before : Module,
  after : Module,
  fallback_limit : Int32,
) -> Unit raise {
  @validate.validate_module(before).unwrap()
  @validate.validate_module(after).unwrap()
  let original = encode_module(before).unwrap()
  let expected = encode_module(after).unwrap()
  assert_true(expected.length() < original.length())
  let fallbacks = [0]
  assert_true(
    encoded_type_compaction_is_strictly_smaller_impl(
      before,
      after,
      fallback_body_encodes=Some(fallbacks),
    ),
  )
  // The bound accompanies actual transformation and exact size/ownership facts.
  assert_true(fallbacks[0] <= fallback_limit)
  assert_eq(
    encoded_module_sizes(before, after).unwrap(),
    (original.length(), expected.length()),
  )
  assert_eq(encode_module(before).unwrap(), original)
  assert_eq(encode_module(after).unwrap(), expected)
}

///|
test "type compaction proof admits scalar bodies with bounded body buffers and exact bytes" {
  let (before, after) = encoded_compaction_proof_fixture(32)
  encoded_compaction_proof_assert(before, after, 0)
}

///|
#skip
test "type compaction proof admits long scalar bodies with bounded body buffers and exact bytes" {
  let (before, after) = encoded_compaction_proof_fixture(4096)
  encoded_compaction_proof_assert(before, after, 0)
}

///|
test "type compaction proof measures only uncertain SIMD siblings while preserving exact bytes" {
  let (before, after) = encoded_compaction_proof_fixture(32, mixed=true)
  encoded_compaction_proof_assert(before, after, 2)
}

///|
test "type compaction proof preserves signed control unsigned type and body framing boundaries" {
  for pair in [(43, 0), (65, 122), (128, 0), (129, 127)] {
    let (count, width) = pair
    let (before, after) = encoded_compaction_proof_fixture(
      width,
      type_count=count,
    )
    let old = TypeIdx::new((count - 1).to_uint())
    let next = TypeIdx::new((count - 2).to_uint())
    let body = Expr::new(Array::make(width, Instruction::nop()))
    let before = before.with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([Instruction::block(BlockType::type_idx(old), body)]),
        ),
      ]),
    )
    let after = after.with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([Instruction::block(BlockType::type_idx(next), body)]),
        ),
      ]),
    )
    encoded_compaction_proof_assert(before, after, 0)
  }
}

///|
test "type compaction proof retains encoder fallback for intentionally invalid original bodies and metadata" {
  let (before, after) = encoded_compaction_proof_fixture(3)
  let invalid_bodies = [
    Func::new(Locals::from_types([ValType::bottom()]), Expr::new([])),
    Func::new(
      Locals::empty(),
      Expr::new([
        Instruction::block(BlockType::type_idx(TypeIdx::rec(0U)), Expr::new([])),
      ]),
    ),
    Func::new(
      Locals::empty(),
      Expr::new([Instruction::i32_load(MemArg::new(U32(9U), None, U64(0UL)))]),
    ),
  ]
  for invalid in invalid_bodies {
    let bad = before.with_code_sec(CodeSec::new([invalid]))
    assert_true(encoded_module_sizes(bad, after) is Err(_))
    assert_true(!encoded_type_compaction_is_strictly_smaller_impl(bad, after))
    let bad_after = after.with_code_sec(CodeSec::new([invalid]))
    assert_true(encoded_module_sizes(before, bad_after) is Err(_))
    assert_true(
      !encoded_type_compaction_is_strictly_smaller_impl(before, bad_after),
    )
  }
  for reserved in ["name", "compiler.facts"] {
    let bad = before.with_custom_secs([
      CustomSec::new(Name::from_string(reserved), b"bad"),
    ])
    assert_true(encoded_module_sizes(bad, after) is Err(_))
    assert_true(!encoded_type_compaction_is_strictly_smaller_impl(bad, after))
  }
  let bad_names = before.with_name_sec(
    NameSec::new(
      type_names=Some(
        NameMap::new([
          NameAssoc::new(1U, Name::from_string("second")),
          NameAssoc::new(0U, Name::from_string("first")),
        ]),
      ),
    ),
  )
  assert_true(encoded_module_sizes(bad_names, after) is Err(_))
  assert_true(
    !encoded_type_compaction_is_strictly_smaller_impl(bad_names, after),
  )
}

///|
test "type compaction proof intentionally defers nonmonotone bodies and oversized shared data to exact encoder" {
  let (before, after) = encoded_compaction_proof_fixture(1)
  assert_true(!encoded_type_compaction_is_strictly_smaller_impl(before, before))
  let larger_body = after.with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new(Array::make(64, Instruction::nop()))),
    ]),
  )
  let sizes = encoded_module_sizes(before, larger_body).unwrap()
  assert_true(sizes.1 > sizes.0)
  assert_true(
    !encoded_type_compaction_is_strictly_smaller_impl(before, larger_body),
  )
  // Only2MiB is allocated; shared segments expose the existing Int32 limit.
  let payload = Bytes::make(2 * 1024 * 1024, 0)
  let data = DataSec::new(
    Array::make(1024, Data::new(DataMode::passive(), payload)),
  )
  let too_large = before.with_data_sec(data)
  let smaller_types = after.with_data_sec(data)
  assert_eq(
    encoded_module_sizes(too_large, smaller_types),
    Err(EncodeError::Encode(BinaryEncodeError::UnsignedLebValueOutOfRange)),
  )
  assert_true(
    !encoded_type_compaction_is_strictly_smaller_impl(too_large, smaller_types),
  )
}

///|
test "type compaction proof retains exact valid type names and unrelated metadata" {
  let (before, after) = encoded_compaction_proof_fixture(3)
  let before = before.with_name_sec(
    NameSec::new(
      type_names=Some(
        NameMap::new([
          NameAssoc::new(0U, Name::from_string("first")),
          NameAssoc::new(1U, Name::from_string("second")),
        ]),
      ),
    ),
  )
  let after = after.with_name_sec(
    NameSec::new(
      type_names=Some(
        NameMap::new([NameAssoc::new(0U, Name::from_string("first"))]),
      ),
    ),
  )
  encoded_compaction_proof_assert(before, after, 0)
  let facts = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(),
  )
  let with_facts = before.with_compiler_fact_custom_section(facts)
  assert_true(
    !encoded_type_compaction_is_strictly_smaller_impl(
      with_facts,
      after.with_compiler_fact_custom_section(facts),
    ),
  )
  let raw = before.with_raw_name_sec_payload(b"\x01\x01\x80")
  assert_true(
    !encoded_type_compaction_is_strictly_smaller_impl(
      raw,
      after.with_raw_name_sec_payload(b"\x01\x01\x80"),
    ),
  )
}

///|
#skip
test "type compaction proof retains sixteen kibibyte body framing in the dedicated lane" {
  let (before, after) = encoded_compaction_proof_fixture(16378, type_count=65)
  let body = Expr::new(Array::make(16378, Instruction::nop()))
  let before = before.with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::block(BlockType::type_idx(TypeIdx::new(64U)), body),
        ]),
      ),
    ]),
  )
  let after = after.with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::block(BlockType::type_idx(TypeIdx::new(63U)), body),
        ]),
      ),
    ]),
  )
  encoded_compaction_proof_assert(before, after, 0)
}

///|
test "type compaction proof measures code literals already in the unchanged header pool" {
  let (before, after) = encoded_compaction_proof_fixture(0)
  let body = Func::new(
    Locals::empty(),
    Expr::new([Instruction::string_const(b"shared"), Instruction::drop()]),
  )
  let before = before
    .with_stringrefs_sec(StringRefsSec::new([b"shared"]))
    .with_code_sec(CodeSec::new([body]))
  let after = after
    .with_stringrefs_sec(StringRefsSec::new([b"shared"]))
    .with_code_sec(CodeSec::new([body]))
  encoded_compaction_proof_assert(before, after, 2)
}

///|
test "type compaction proof intentionally defers missing code literals and restores enclosing encoder context" {
  let (before, after) = encoded_compaction_proof_fixture(0)
  let body = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::string_const(b"missing from header"),
      Instruction::drop(),
    ]),
  )
  let before = before.with_code_sec(CodeSec::new([body]))
  let after = after.with_code_sec(CodeSec::new([body]))
  // The full encoder builds the code pool and still performs this transform.
  let sizes = encoded_module_sizes(before, after).unwrap()
  assert_true(sizes.1 < sizes.0)
  let result = with_binary_encode_stringrefs_context(Some([b"outer"]), fn() {
    if encoded_type_compaction_is_strictly_smaller_impl(before, after) {
      return Ok(false)
    }
    Ok(encode_string_const_index(b"outer") == Ok(U32(0U)))
  })
  assert_eq(result, Ok(true))
  assert_true(encode_string_const_index(b"outer") is Err(_))
}
