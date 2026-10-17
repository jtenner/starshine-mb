///|
fn dfe_compaction_proof_fixture(strings~ : Bool = false) -> @lib.Module {
  let scalar = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new(Array::make(32, @lib.Instruction::nop())),
  )
  let opaque = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new(
      if strings {
        [
          @lib.Instruction::string_const(b"proof fallback"),
          @lib.Instruction::drop(),
        ]
      } else {
        [
          @lib.Instruction::i32_const(7),
          @lib.Instruction::i8x16_splat(),
          @lib.Instruction::drop(),
        ]
      },
    ),
  )
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new(
      Array::make(
        2,
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ),
    ),
  )
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
  )
  .with_code_sec(@lib.CodeSec::new([scalar, opaque]))
}

///|
test "DFE type compaction avoids full body comparison for scalar and uncertain SIMD siblings with exact output" {
  let input = dfe_compaction_proof_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let expected = input
    .with_type_sec(@lib.TypeSec::new([input.type_sec.unwrap().0[0]]))
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
    )
  let full = [0]
  let actual = dfe_cleanup_simple_type_encoding_candidate(
    input,
    full_size_comparisons=Some(full),
  ).unwrap()
  @validate.validate_module(actual).unwrap()
  let actual_bytes = @binary.encode_module(actual).unwrap()
  assert_eq(actual_bytes, @binary.encode_module(expected).unwrap())
  assert_true(actual_bytes.length() < saved.length())
  assert_eq(actual.code_sec.unwrap().0, input.code_sec.unwrap().0)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  // Resource bound is coupled to actual transformation, exact bytes and ownership.
  assert_eq(full[0], 0)
}

///|
test "DFE type compaction uses type-only proof for body string pools with exact output" {
  let input = dfe_compaction_proof_fixture(strings=true)
  let saved = @binary.encode_module(input).unwrap()
  let expected = input
    .with_type_sec(@lib.TypeSec::new([input.type_sec.unwrap().0[0]]))
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
    )
  let full = [0]
  let body_proofs = [0]
  let full_encodes = [0]
  let actual = dfe_cleanup_simple_type_encoding_candidate(
    input,
    full_size_comparisons=Some(full),
    body_size_proofs=Some(body_proofs),
    full_size_checks=Some(full_encodes),
  ).unwrap()
  @validate.validate_module(actual).unwrap()
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_true(@binary.encode_module(actual).unwrap().length() < saved.length())
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(full[0], 0)
  assert_eq(body_proofs[0], 0)
  assert_eq(full_encodes[0], 0)
}
