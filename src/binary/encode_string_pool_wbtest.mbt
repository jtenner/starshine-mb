///|
test "large encoder string pools use indexed membership after bounded admission" {
  let strings : Array[Bytes] = []
  for index = 0; index < 128; index = index + 1 {
    strings.push(@utf8.encode("literal-\{index}"))
  }
  let mod_ = Module::new().with_stringrefs_sec(StringRefsSec::new(strings))
  let work = [0]
  let pool = encode_module_stringrefs(mod_, membership_work=Some(work))
  assert_eq(pool, strings)
  assert_false(physical_equal(pool, strings))
  assert_true(work[0] <= 700)
  assert_eq(mod_.stringrefs_sec.unwrap().0, strings)
  let repeated = strings.copy()
  // Fresh byte values exercise content equality after the index is admitted.
  for index = 127; index >= 0; index = index - 1 {
    repeated.push(@utf8.encode("literal-\{index}"))
  }
  let repeated_mod = mod_.with_stringrefs_sec(StringRefsSec::new(repeated))
  assert_eq(encode_module_stringrefs(repeated_mod), strings)
  assert_eq(
    encode_module_stringrefs(repeated_mod),
    encode_module_stringrefs_before_index(repeated_mod),
  )
}

///|
test "encoder string pool keeps declaration global control and catch order" {
  let prefix = b"declared"
  let body = [
    Instruction::string_const(b"body"),
    Instruction::drop(),
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::string_const(prefix),
        Instruction::drop(),
        Instruction::string_const(b"block"),
        Instruction::drop(),
      ]),
    ),
    Instruction::i32_const(I32(0)),
    Instruction::if_(
      BlockType::void_(),
      [Instruction::string_const(b"yes"), Instruction::drop()],
      Some([Instruction::string_const(b"no"), Instruction::drop()]),
    ),
    Instruction::try_(
      BlockType::void_(),
      Expr::new([Instruction::string_const(b"try"), Instruction::drop()]),
      [
        @lib.LegacyCatch::all(
          Expr::new([Instruction::string_const(b"catch"), Instruction::drop()]),
        ),
      ],
    ),
  ]
  let mod_ = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_stringrefs_sec(StringRefsSec::new([prefix, prefix]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::stringref(), false),
          Expr::new([Instruction::string_const(b"global")]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new(body))]))
  @validate.validate_module(mod_).unwrap()
  assert_eq(encode_module_stringrefs(mod_), [
    prefix, b"global", b"body", b"block", b"yes", b"no", b"try", b"catch",
  ])
  assert_eq(
    encode_module_stringrefs(mod_),
    encode_module_stringrefs_before_index(mod_),
  )
  let bytes = encode_module(mod_).unwrap()
  let decoded = decode_module(bytes).unwrap()
  assert_eq(decoded.stringrefs_sec.unwrap().0, encode_module_stringrefs(mod_))
  @validate.validate_module(decoded).unwrap()
}

///|
test "string pool indexing retains string index LEB boundaries and exact sizes" {
  for count in [127, 128, 129] {
    let strings : Array[Bytes] = []
    for index = 0; index < count; index = index + 1 {
      strings.push(@utf8.encode("declared-\{index}"))
    }
    let literal = b"new-literal"
    let mod_ = Module::new()
      .with_type_sec(
        TypeSec::new([
          RecType::new(
            SubType::comp_type(CompType::func([], [ValType::stringref()])),
          ),
        ]),
      )
      .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
      .with_stringrefs_sec(StringRefsSec::new(strings))
      .with_code_sec(
        CodeSec::new([
          Func::new(
            Locals::empty(),
            Expr::new([Instruction::string_const(literal)]),
          ),
        ]),
      )
    @validate.validate_module(mod_).unwrap()
    let pool = encode_module_stringrefs(mod_)
    assert_eq(pool.length(), count + 1)
    assert_eq(pool[count], literal)
    let buffer = @buffer.new()
    with_binary_encode_stringrefs_context(Some(pool), fn() {
      Encode::encode(Instruction::string_const(literal), buffer)
    }).unwrap()
    let encoded = buffer.to_bytes()
    let tail = match count {
      127 => b"\x7f"
      128 => b"\x80\x01"
      _ => b"\x81\x01"
    }
    for offset = 0; offset < tail.length(); offset = offset + 1 {
      assert_eq(
        encoded[encoded.length() - tail.length() + offset],
        tail[offset],
      )
    }
    let bytes = encode_module(mod_).unwrap()
    assert_eq(compiler_fact_module_opcode_offsets(mod_).unwrap(), [[0U]])
    let sizes = encoded_module_sizes(mod_, mod_).unwrap()
    assert_eq(sizes, (bytes.length(), bytes.length()))
    let decoded = decode_module(bytes).unwrap()
    assert_eq(decoded.stringrefs_sec.unwrap().0, pool)
    let Func(_, Expr(body)) = decoded.code_sec.unwrap().0[0]
    assert_eq(body, [Instruction::string_const(literal)])
    @validate.validate_module(decoded).unwrap()
    assert_eq(mod_.stringrefs_sec.unwrap().0, strings)
  }
}
