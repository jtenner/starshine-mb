///|
fn text_runtime_ref(type_index : Int) -> @lib.ValType {
  @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(type_index.reinterpret_as_uint())),
    ),
  )
}

///|
fn text_i32(value : Int) -> @lib.Instruction {
  @lib.Instruction::i32_const(@lib.I32::new(value))
}

///|
fn text_local(index : Int) -> @lib.LocalIdx {
  @lib.LocalIdx::new(index.reinterpret_as_uint())
}

///|
fn text_false_return() -> Array[@lib.Instruction] {
  [text_i32(0), @lib.Instruction::return_()]
}

///|
fn text_invalid_if(
  output : Array[@lib.Instruction],
  condition : Array[@lib.Instruction],
) -> Unit {
  for instruction in condition {
    output.push(instruction)
  }
  output.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), text_false_return(), None),
  )
}

///| Load one byte from the v128 chunk array. The caller supplies the logical

///|
/// byte index as local `index_local`; the result is an i32 in 0..255.
fn text_byte_at(
  array_type : @lib.TypeIdx,
  chunks_local : Int,
  index_local : Int,
  offset : Int,
) -> Array[@lib.Instruction] {
  let output : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(index_local)),
  ]
  if offset != 0 {
    output.push(text_i32(offset))
    output.push(@lib.Instruction::i32_add())
  }
  output.push(text_i32(4))
  output.push(@lib.Instruction::i32_shr_u())
  output.push(@lib.Instruction::array_get(array_type))
  output.push(@lib.Instruction::local_get(text_local(index_local)))
  if offset != 0 {
    output.push(text_i32(offset))
    output.push(@lib.Instruction::i32_add())
  }
  output.push(text_i32(15))
  output.push(@lib.Instruction::i32_and())
  output.push(@lib.Instruction::i8x16_splat())
  output.push(@lib.Instruction::i8x16_swizzle())
  output.push(
    @lib.Instruction::i8x16_extract_lane_u(@lib.LaneIdx::new(b'\x00')),
  )
  output
}

///|
fn text_load_logical_v128(
  output : Array[@lib.Instruction],
  array_type : @lib.TypeIdx,
  chunks_local : Int,
  index_local : Int,
  vector_local : Int,
) -> Unit {
  output.push(@lib.Instruction::local_get(text_local(index_local)))
  output.push(text_i32(15))
  output.push(@lib.Instruction::i32_and())
  output.push(@lib.Instruction::i32_eqz())
  let aligned : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::local_set(text_local(vector_local)),
  ]
  let unaligned : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::v128_const(
      b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
      b'\x09', b'\x0A', b'\x0B', b'\x0C', b'\x0D', b'\x0E', b'\x0F',
    ),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::i8x16_add(),
    @lib.Instruction::i8x16_swizzle(),
    @lib.Instruction::local_get(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    text_i32(1),
    @lib.Instruction::i32_add(),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::v128_const(
      b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
      b'\x09', b'\x0A', b'\x0B', b'\x0C', b'\x0D', b'\x0E', b'\x0F',
    ),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::i8x16_add(),
    text_i32(16),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::i8x16_sub(),
    @lib.Instruction::i8x16_swizzle(),
    @lib.Instruction::v128_or(),
    @lib.Instruction::local_set(text_local(vector_local)),
  ]
  output.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), aligned, Some(unaligned)),
  )
}

///|
fn text_set_byte_local(
  output : Array[@lib.Instruction],
  array_type : @lib.TypeIdx,
  chunks_local : Int,
  index_local : Int,
  offset : Int,
  target_local : Int,
) -> Unit {
  for instruction in text_byte_at(array_type, chunks_local, index_local, offset) {
    output.push(instruction)
  }
  output.push(@lib.Instruction::local_set(text_local(target_local)))
}

///|
fn text_continuation_invalid(local_index : Int) -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(text_local(local_index)),
    text_i32(0xC0),
    @lib.Instruction::i32_and(),
    text_i32(0x80),
    @lib.Instruction::i32_ne(),
  ]
}

///|
fn text_remaining_less_than(
  index_local : Int,
  length_local : Int,
  needed : Int,
) -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(needed),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(text_local(length_local)),
    @lib.Instruction::i32_gt_u(),
  ]
}

///|
fn text_increment_and_continue(
  index_local : Int,
  count : Int,
) -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(count),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(index_local)),
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
}

///| Strict RFC 3629 validation adapted from JairusSW/utf-as. Whole aligned

///| ASCII chunks use one v128 bitmask; dirty chunks validate one sequence at a

///|
/// time while byte extraction remains allocation-free over the same v128.
fn starshine_utf8_validate_body(base : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let bytes_type = @lib.TypeIdx::new((base + 2).reinterpret_as_uint())
  // Parameters: 0 = nullable eqref Bytes. Locals: text, chunks, len, index,
  // b0, b1, b2, b3.
  let text_local_index = 1
  let chunks_local = 2
  let length_local = 3
  let index_local = 4
  let b0_local = 5
  let b1_local = 6
  let b2_local = 7
  let b3_local = 8
  let init : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(bytes_type)),
    @lib.Instruction::local_set(text_local(text_local_index)),
    @lib.Instruction::local_get(text_local(text_local_index)),
    @lib.Instruction::struct_get(bytes_type, 0U),
    @lib.Instruction::local_set(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(text_local_index)),
    @lib.Instruction::struct_get(bytes_type, 1U),
    @lib.Instruction::local_set(text_local(index_local)),
    @lib.Instruction::local_get(text_local(text_local_index)),
    @lib.Instruction::struct_get(bytes_type, 2U),
    @lib.Instruction::local_get(text_local(index_local)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(length_local)),
  ]
  let loop_body : Array[@lib.Instruction] = []
  // End of input.
  loop_body.push(@lib.Instruction::local_get(text_local(index_local)))
  loop_body.push(@lib.Instruction::local_get(text_local(length_local)))
  loop_body.push(@lib.Instruction::i32_ge_u())
  loop_body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [text_i32(1), @lib.Instruction::return_()],
      None,
    ),
  )
  // Aligned 16-byte ASCII fast path.
  loop_body.push(@lib.Instruction::local_get(text_local(index_local)))
  loop_body.push(text_i32(15))
  loop_body.push(@lib.Instruction::i32_and())
  loop_body.push(@lib.Instruction::i32_eqz())
  loop_body.push(@lib.Instruction::local_get(text_local(index_local)))
  loop_body.push(text_i32(16))
  loop_body.push(@lib.Instruction::i32_add())
  loop_body.push(@lib.Instruction::local_get(text_local(length_local)))
  loop_body.push(@lib.Instruction::i32_le_u())
  loop_body.push(@lib.Instruction::i32_and())
  let aligned_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::i8x16_bitmask(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(index_local)),
        text_i32(16),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_set(text_local(index_local)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ],
      None,
    ),
  ]
  loop_body.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), aligned_body, None),
  )
  text_set_byte_local(
    loop_body, array_type, chunks_local, index_local, 0, b0_local,
  )
  // ASCII byte.
  loop_body.push(@lib.Instruction::local_get(text_local(b0_local)))
  loop_body.push(text_i32(0x80))
  loop_body.push(@lib.Instruction::i32_lt_u())
  loop_body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      text_increment_and_continue(index_local, 1),
      None,
    ),
  )
  // Stray continuation and overlong two-byte leads.
  text_invalid_if(loop_body, [
    @lib.Instruction::local_get(text_local(b0_local)),
    text_i32(0xC2),
    @lib.Instruction::i32_lt_u(),
  ])
  // C2..DF.
  loop_body.push(@lib.Instruction::local_get(text_local(b0_local)))
  loop_body.push(text_i32(0xE0))
  loop_body.push(@lib.Instruction::i32_lt_u())
  let two : Array[@lib.Instruction] = []
  text_invalid_if(two, text_remaining_less_than(index_local, length_local, 2))
  text_set_byte_local(two, array_type, chunks_local, index_local, 1, b1_local)
  text_invalid_if(two, text_continuation_invalid(b1_local))
  for instruction in text_increment_and_continue(index_local, 2) {
    two.push(instruction)
  }
  loop_body.push(@lib.Instruction::if_(@lib.BlockType::void_(), two, None))
  // E0..EF.
  loop_body.push(@lib.Instruction::local_get(text_local(b0_local)))
  loop_body.push(text_i32(0xF0))
  loop_body.push(@lib.Instruction::i32_lt_u())
  let three : Array[@lib.Instruction] = []
  text_invalid_if(three, text_remaining_less_than(index_local, length_local, 3))
  text_set_byte_local(three, array_type, chunks_local, index_local, 1, b1_local)
  text_set_byte_local(three, array_type, chunks_local, index_local, 2, b2_local)
  // E0 requires A0..BF.
  three.push(@lib.Instruction::local_get(text_local(b0_local)))
  three.push(text_i32(0xE0))
  three.push(@lib.Instruction::i32_eq())
  let e0 : Array[@lib.Instruction] = []
  text_invalid_if(e0, [
    @lib.Instruction::local_get(text_local(b1_local)),
    text_i32(0xA0),
    @lib.Instruction::i32_lt_u(),
  ])
  text_invalid_if(e0, [
    @lib.Instruction::local_get(text_local(b1_local)),
    text_i32(0xBF),
    @lib.Instruction::i32_gt_u(),
  ])
  three.push(@lib.Instruction::if_(@lib.BlockType::void_(), e0, None))
  // ED rejects UTF-8 encoded surrogates.
  three.push(@lib.Instruction::local_get(text_local(b0_local)))
  three.push(text_i32(0xED))
  three.push(@lib.Instruction::i32_eq())
  let ed : Array[@lib.Instruction] = []
  text_invalid_if(ed, [
    @lib.Instruction::local_get(text_local(b1_local)),
    text_i32(0x80),
    @lib.Instruction::i32_lt_u(),
  ])
  text_invalid_if(ed, [
    @lib.Instruction::local_get(text_local(b1_local)),
    text_i32(0x9F),
    @lib.Instruction::i32_gt_u(),
  ])
  three.push(@lib.Instruction::if_(@lib.BlockType::void_(), ed, None))
  // Other three-byte leads require a continuation second byte.
  three.push(@lib.Instruction::local_get(text_local(b0_local)))
  three.push(text_i32(0xE0))
  three.push(@lib.Instruction::i32_ne())
  three.push(@lib.Instruction::local_get(text_local(b0_local)))
  three.push(text_i32(0xED))
  three.push(@lib.Instruction::i32_ne())
  three.push(@lib.Instruction::i32_and())
  three.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      text_continuation_invalid(b1_local) +
      [
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          text_false_return(),
          None,
        ),
      ],
      None,
    ),
  )
  text_invalid_if(three, text_continuation_invalid(b2_local))
  for instruction in text_increment_and_continue(index_local, 3) {
    three.push(instruction)
  }
  loop_body.push(@lib.Instruction::if_(@lib.BlockType::void_(), three, None))
  // F0..F4.
  loop_body.push(@lib.Instruction::local_get(text_local(b0_local)))
  loop_body.push(text_i32(0xF4))
  loop_body.push(@lib.Instruction::i32_le_u())
  let four : Array[@lib.Instruction] = []
  text_invalid_if(four, text_remaining_less_than(index_local, length_local, 4))
  text_set_byte_local(four, array_type, chunks_local, index_local, 1, b1_local)
  text_set_byte_local(four, array_type, chunks_local, index_local, 2, b2_local)
  text_set_byte_local(four, array_type, chunks_local, index_local, 3, b3_local)
  four.push(@lib.Instruction::local_get(text_local(b0_local)))
  four.push(text_i32(0xF0))
  four.push(@lib.Instruction::i32_eq())
  let f0 : Array[@lib.Instruction] = []
  text_invalid_if(f0, [
    @lib.Instruction::local_get(text_local(b1_local)),
    text_i32(0x90),
    @lib.Instruction::i32_lt_u(),
  ])
  text_invalid_if(f0, [
    @lib.Instruction::local_get(text_local(b1_local)),
    text_i32(0xBF),
    @lib.Instruction::i32_gt_u(),
  ])
  four.push(@lib.Instruction::if_(@lib.BlockType::void_(), f0, None))
  four.push(@lib.Instruction::local_get(text_local(b0_local)))
  four.push(text_i32(0xF4))
  four.push(@lib.Instruction::i32_eq())
  let f4 : Array[@lib.Instruction] = []
  text_invalid_if(f4, [
    @lib.Instruction::local_get(text_local(b1_local)),
    text_i32(0x80),
    @lib.Instruction::i32_lt_u(),
  ])
  text_invalid_if(f4, [
    @lib.Instruction::local_get(text_local(b1_local)),
    text_i32(0x8F),
    @lib.Instruction::i32_gt_u(),
  ])
  four.push(@lib.Instruction::if_(@lib.BlockType::void_(), f4, None))
  four.push(@lib.Instruction::local_get(text_local(b0_local)))
  four.push(text_i32(0xF0))
  four.push(@lib.Instruction::i32_ne())
  four.push(@lib.Instruction::local_get(text_local(b0_local)))
  four.push(text_i32(0xF4))
  four.push(@lib.Instruction::i32_ne())
  four.push(@lib.Instruction::i32_and())
  four.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      text_continuation_invalid(b1_local) +
      [
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          text_false_return(),
          None,
        ),
      ],
      None,
    ),
  )
  text_invalid_if(four, text_continuation_invalid(b2_local))
  text_invalid_if(four, text_continuation_invalid(b3_local))
  for instruction in text_increment_and_continue(index_local, 4) {
    four.push(instruction)
  }
  loop_body.push(@lib.Instruction::if_(@lib.BlockType::void_(), four, None))
  loop_body.push(text_i32(0))
  loop_body.push(@lib.Instruction::return_())
  loop_body.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  let body : Array[@lib.Instruction] = []
  for instruction in init {
    body.push(instruction)
  }
  body.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(loop_body)),
  )
  body.push(text_i32(1))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + 2),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(body),
  )
}

///| Count UTF-16 code units from known-valid UTF-8. This is the utf-as

///| identity `bytes - continuation_bytes + four_byte_leads`, processing full

///|
/// backing chunks with native SIMD and only the final partial chunk scalar.
fn starshine_utf16_length_type_body(base : Int, type_offset : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let string_type = @lib.TypeIdx::new(
    (base + type_offset).reinterpret_as_uint(),
  )
  let text_ref = 1
  let chunks = 2
  let length = 3
  let index = 4
  let vector = 5
  let continuations = 6
  let four_byte = 7
  let byte = 8
  let end_offset = 9
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(string_type)),
    @lib.Instruction::local_set(text_local(text_ref)),
    @lib.Instruction::local_get(text_local(text_ref)),
    @lib.Instruction::struct_get(string_type, 0U),
    @lib.Instruction::local_set(text_local(chunks)),
    @lib.Instruction::local_get(text_local(text_ref)),
    @lib.Instruction::struct_get(string_type, 2U),
    @lib.Instruction::local_set(text_local(length)),
    @lib.Instruction::local_get(text_local(text_ref)),
    @lib.Instruction::struct_get(string_type, 1U),
    @lib.Instruction::local_tee(text_local(index)),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(end_offset)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(continuations)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(four_byte)),
  ]
  let loop_body : Array[@lib.Instruction] = []
  loop_body.push(@lib.Instruction::local_get(text_local(index)))
  loop_body.push(@lib.Instruction::local_get(text_local(end_offset)))
  loop_body.push(@lib.Instruction::i32_ge_u())
  loop_body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(length)),
        @lib.Instruction::local_get(text_local(continuations)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::local_get(text_local(four_byte)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::return_(),
      ],
      None,
    ),
  )
  loop_body.push(@lib.Instruction::local_get(text_local(index)))
  loop_body.push(text_i32(16))
  loop_body.push(@lib.Instruction::i32_add())
  loop_body.push(@lib.Instruction::local_get(text_local(end_offset)))
  loop_body.push(@lib.Instruction::i32_le_u())
  let full : Array[@lib.Instruction] = []
  text_load_logical_v128(full, array_type, chunks, index, vector)
  for
    instruction in [
      @lib.Instruction::local_get(text_local(continuations)),
      @lib.Instruction::local_get(text_local(vector)),
      text_i32(-64),
      @lib.Instruction::i8x16_splat(),
      @lib.Instruction::i8x16_lt_s(),
      @lib.Instruction::i8x16_bitmask(),
      @lib.Instruction::i32_popcnt(),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(text_local(continuations)),
      @lib.Instruction::local_get(text_local(four_byte)),
      @lib.Instruction::local_get(text_local(vector)),
      text_i32(0xF8),
      @lib.Instruction::i8x16_splat(),
      @lib.Instruction::v128_and(),
      text_i32(0xF0),
      @lib.Instruction::i8x16_splat(),
      @lib.Instruction::i8x16_eq(),
      @lib.Instruction::i8x16_bitmask(),
      @lib.Instruction::i32_popcnt(),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(text_local(four_byte)),
      @lib.Instruction::local_get(text_local(index)),
      text_i32(16),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(text_local(index)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ] {
    full.push(instruction)
  }
  loop_body.push(@lib.Instruction::if_(@lib.BlockType::void_(), full, None))
  text_set_byte_local(loop_body, array_type, chunks, index, 0, byte)
  loop_body.push(@lib.Instruction::local_get(text_local(byte)))
  loop_body.push(text_i32(0xC0))
  loop_body.push(@lib.Instruction::i32_and())
  loop_body.push(text_i32(0x80))
  loop_body.push(@lib.Instruction::i32_eq())
  loop_body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(continuations)),
        text_i32(1),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_set(text_local(continuations)),
      ],
      None,
    ),
  )
  loop_body.push(@lib.Instruction::local_get(text_local(byte)))
  loop_body.push(text_i32(0xF8))
  loop_body.push(@lib.Instruction::i32_and())
  loop_body.push(text_i32(0xF0))
  loop_body.push(@lib.Instruction::i32_eq())
  loop_body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(four_byte)),
        text_i32(1),
        @lib.Instruction::i32_add(),
        @lib.Instruction::local_set(text_local(four_byte)),
      ],
      None,
    ),
  )
  loop_body.push(@lib.Instruction::local_get(text_local(index)))
  loop_body.push(text_i32(1))
  loop_body.push(@lib.Instruction::i32_add())
  loop_body.push(@lib.Instruction::local_set(text_local(index)))
  loop_body.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(loop_body)),
  )
  body.push(text_i32(0))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + type_offset),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::v128(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn starshine_utf16_length_body(base : Int) -> @lib.Func {
  starshine_utf16_length_type_body(base, 1)
}

///|
fn starshine_text_length_type_body(base : Int, type_offset : Int) -> @lib.Func {
  let type_index = @lib.TypeIdx::new((base + type_offset).reinterpret_as_uint())
  @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(text_local(0)),
      @lib.Instruction::ref_cast(false, @lib.HeapType::new(type_index)),
      @lib.Instruction::struct_get(type_index, 2U),
    ]),
  )
}

///|
fn starshine_text_length_body(base : Int, string_ : Bool) -> @lib.Func {
  starshine_text_length_type_body(base, if string_ { 1 } else { 2 })
}

///|
fn starshine_string_as_bytes_body(base : Int) -> @lib.Func {
  let string_type = @lib.TypeIdx::new((base + 1).reinterpret_as_uint())
  let bytes_type = @lib.TypeIdx::new((base + 2).reinterpret_as_uint())
  @lib.Func::new(
    @lib.Locals::from_types([text_runtime_ref(base + 1)]),
    @lib.Expr::new([
      @lib.Instruction::local_get(text_local(0)),
      @lib.Instruction::ref_cast(false, @lib.HeapType::new(string_type)),
      @lib.Instruction::local_tee(text_local(1)),
      @lib.Instruction::struct_get(string_type, 0U),
      @lib.Instruction::local_get(text_local(1)),
      @lib.Instruction::struct_get(string_type, 1U),
      @lib.Instruction::local_get(text_local(1)),
      @lib.Instruction::struct_get(string_type, 2U),
      @lib.Instruction::struct_new(bytes_type),
    ]),
  )
}

///| Validate once, trap on malformed UTF-8, and publish a nominal String

///|
/// wrapper that shares the immutable Bytes backing without copying content.
fn starshine_bytes_to_string_body(
  base : Int,
  validator_function_index : Int,
) -> @lib.Func {
  let string_type = @lib.TypeIdx::new((base + 1).reinterpret_as_uint())
  let bytes_type = @lib.TypeIdx::new((base + 2).reinterpret_as_uint())
  let bytes_ref = 1
  @lib.Func::new(
    @lib.Locals::from_types([text_runtime_ref(base + 2)]),
    @lib.Expr::new([
      @lib.Instruction::local_get(text_local(0)),
      @lib.Instruction::call(
        @lib.FuncIdx::new(validator_function_index.reinterpret_as_uint()),
      ),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::unreachable_()],
        None,
      ),
      @lib.Instruction::local_get(text_local(0)),
      @lib.Instruction::ref_cast(false, @lib.HeapType::new(bytes_type)),
      @lib.Instruction::local_tee(text_local(bytes_ref)),
      @lib.Instruction::struct_get(bytes_type, 0U),
      @lib.Instruction::local_get(text_local(bytes_ref)),
      @lib.Instruction::struct_get(bytes_type, 1U),
      @lib.Instruction::local_get(text_local(bytes_ref)),
      @lib.Instruction::struct_get(bytes_type, 2U),
      @lib.Instruction::struct_new(string_type),
    ]),
  )
}

///|
/// Compare exact logical bytes across flat values and shared views.
fn starshine_text_equals_type_body(base : Int, type_offset : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let value_type = @lib.TypeIdx::new((base + type_offset).reinterpret_as_uint())
  let left_ref = 2
  let right_ref = 3
  let left_chunks = 4
  let right_chunks = 5
  let length = 6
  let left_index = 7
  let right_index = 8
  let index = 9
  let left_vector = 10
  let right_vector = 11
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(value_type)),
    @lib.Instruction::local_set(text_local(left_ref)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(value_type)),
    @lib.Instruction::local_set(text_local(right_ref)),
    @lib.Instruction::local_get(text_local(left_ref)),
    @lib.Instruction::struct_get(value_type, 2U),
    @lib.Instruction::local_tee(text_local(length)),
    @lib.Instruction::local_get(text_local(right_ref)),
    @lib.Instruction::struct_get(value_type, 2U),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::if_(@lib.BlockType::void_(), text_false_return(), None),
    @lib.Instruction::local_get(text_local(left_ref)),
    @lib.Instruction::struct_get(value_type, 0U),
    @lib.Instruction::local_set(text_local(left_chunks)),
    @lib.Instruction::local_get(text_local(right_ref)),
    @lib.Instruction::struct_get(value_type, 0U),
    @lib.Instruction::local_set(text_local(right_chunks)),
    @lib.Instruction::local_get(text_local(left_ref)),
    @lib.Instruction::struct_get(value_type, 1U),
    @lib.Instruction::local_set(text_local(left_index)),
    @lib.Instruction::local_get(text_local(right_ref)),
    @lib.Instruction::struct_get(value_type, 1U),
    @lib.Instruction::local_set(text_local(right_index)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(index)),
  ]
  let loop_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [text_i32(1), @lib.Instruction::return_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(index)),
    text_i32(16),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::i32_le_u(),
  ]
  let full : Array[@lib.Instruction] = []
  text_load_logical_v128(full, array_type, left_chunks, left_index, left_vector)
  text_load_logical_v128(
    full, array_type, right_chunks, right_index, right_vector,
  )
  for
    instruction in [
      @lib.Instruction::local_get(text_local(left_vector)),
      @lib.Instruction::local_get(text_local(right_vector)),
      @lib.Instruction::v128_xor(),
      @lib.Instruction::v128_any_true(),
      @lib.Instruction::if_(@lib.BlockType::void_(), text_false_return(), None),
    ] {
    full.push(instruction)
  }
  for physical_index in [left_index, right_index] {
    full.push(@lib.Instruction::local_get(text_local(physical_index)))
    full.push(text_i32(16))
    full.push(@lib.Instruction::i32_add())
    full.push(@lib.Instruction::local_set(text_local(physical_index)))
  }
  full.push(@lib.Instruction::local_get(text_local(index)))
  full.push(text_i32(16))
  full.push(@lib.Instruction::i32_add())
  full.push(@lib.Instruction::local_set(text_local(index)))
  full.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  loop_body.push(@lib.Instruction::if_(@lib.BlockType::void_(), full, None))
  for instruction in text_byte_at(array_type, left_chunks, left_index, 0) {
    loop_body.push(instruction)
  }
  for instruction in text_byte_at(array_type, right_chunks, right_index, 0) {
    loop_body.push(instruction)
  }
  loop_body.push(@lib.Instruction::i32_ne())
  loop_body.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), text_false_return(), None),
  )
  for physical_index in [left_index, right_index] {
    loop_body.push(@lib.Instruction::local_get(text_local(physical_index)))
    loop_body.push(text_i32(1))
    loop_body.push(@lib.Instruction::i32_add())
    loop_body.push(@lib.Instruction::local_set(text_local(physical_index)))
  }
  loop_body.push(@lib.Instruction::local_get(text_local(index)))
  loop_body.push(text_i32(1))
  loop_body.push(@lib.Instruction::i32_add())
  loop_body.push(@lib.Instruction::local_set(text_local(index)))
  loop_body.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(loop_body)),
  )
  body.push(text_i32(1))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + type_offset),
      text_runtime_ref(base + type_offset),
      text_runtime_ref(base),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::v128(),
      @lib.ValType::v128(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn starshine_text_equals_body(base : Int, string_ : Bool) -> @lib.Func {
  starshine_text_equals_type_body(base, if string_ { 1 } else { 2 })
}

///| Return the first logical byte index or U32::MAX when absent. A short scalar

///| prefix reaches physical V128 alignment, complete chunks use SIMD equality

///|
/// plus a bitmask/ctz first-lane selection, and the exact tail remains scalar.
fn starshine_bytes_find_byte_body(base : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let bytes_type = @lib.TypeIdx::new((base + 2).reinterpret_as_uint())
  let bytes_ref = 2
  let chunks = 3
  let start = 4
  let length = 5
  let index = 6
  let physical_index = 7
  let mask = 8
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(bytes_type)),
    @lib.Instruction::local_set(text_local(bytes_ref)),
    @lib.Instruction::local_get(text_local(bytes_ref)),
    @lib.Instruction::struct_get(bytes_type, 0U),
    @lib.Instruction::local_set(text_local(chunks)),
    @lib.Instruction::local_get(text_local(bytes_ref)),
    @lib.Instruction::struct_get(bytes_type, 1U),
    @lib.Instruction::local_set(text_local(start)),
    @lib.Instruction::local_get(text_local(bytes_ref)),
    @lib.Instruction::struct_get(bytes_type, 2U),
    @lib.Instruction::local_set(text_local(length)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(index)),
  ]
  let prefix_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [text_i32(-1), @lib.Instruction::return_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(start)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_tee(text_local(physical_index)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
  ]
  for instruction in text_byte_at(array_type, chunks, physical_index, 0) {
    prefix_loop.push(instruction)
  }
  prefix_loop.push(@lib.Instruction::local_get(text_local(1)))
  prefix_loop.push(@lib.Instruction::i32_eq())
  prefix_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(index)),
        @lib.Instruction::return_(),
      ],
      None,
    ),
  )
  prefix_loop.push(@lib.Instruction::local_get(text_local(index)))
  prefix_loop.push(text_i32(1))
  prefix_loop.push(@lib.Instruction::i32_add())
  prefix_loop.push(@lib.Instruction::local_set(text_local(index)))
  prefix_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(prefix_loop),
        ),
      ]),
    ),
  )
  let vector_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_sub(),
    text_i32(16),
    @lib.Instruction::i32_lt_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(chunks)),
    @lib.Instruction::local_get(text_local(physical_index)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::i8x16_eq(),
    @lib.Instruction::i8x16_bitmask(),
    @lib.Instruction::local_tee(text_local(mask)),
    @lib.Instruction::i32_eqz(),
  ]
  let found_vector : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(mask)),
    @lib.Instruction::i32_ctz(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::return_(),
  ]
  vector_loop.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), [], Some(found_vector)),
  )
  for local_index in [index, physical_index] {
    vector_loop.push(@lib.Instruction::local_get(text_local(local_index)))
    vector_loop.push(text_i32(16))
    vector_loop.push(@lib.Instruction::i32_add())
    vector_loop.push(@lib.Instruction::local_set(text_local(local_index)))
  }
  vector_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(vector_loop),
        ),
      ]),
    ),
  )
  let tail_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [text_i32(-1), @lib.Instruction::return_()],
      None,
    ),
  ]
  for instruction in text_byte_at(array_type, chunks, physical_index, 0) {
    tail_loop.push(instruction)
  }
  tail_loop.push(@lib.Instruction::local_get(text_local(1)))
  tail_loop.push(@lib.Instruction::i32_eq())
  tail_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(index)),
        @lib.Instruction::return_(),
      ],
      None,
    ),
  )
  for local_index in [index, physical_index] {
    tail_loop.push(@lib.Instruction::local_get(text_local(local_index)))
    tail_loop.push(text_i32(1))
    tail_loop.push(@lib.Instruction::i32_add())
    tail_loop.push(@lib.Instruction::local_set(text_local(local_index)))
  }
  tail_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(tail_loop)),
  )
  body.push(text_i32(-1))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + 2),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(body),
  )
}

///| Verify one candidate substring exactly and return its logical index on a

///| match. The candidate and all scratch state live in locals; no range wrapper

///|
/// or temporary storage is created.
fn text_verify_bytes_candidate(
  output : Array[@lib.Instruction],
  array_type : @lib.TypeIdx,
  value_chunks : Int,
  needle_chunks : Int,
  value_start : Int,
  needle_start : Int,
  needle_length : Int,
  candidate : Int,
  index : Int,
  value_index : Int,
  needle_index : Int,
  matched : Int,
) -> Unit {
  output.push(text_i32(1))
  output.push(@lib.Instruction::local_set(text_local(matched)))
  output.push(text_i32(0))
  output.push(@lib.Instruction::local_set(text_local(index)))
  let verify_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(needle_length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(value_start)),
    @lib.Instruction::local_get(text_local(candidate)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(value_index)),
    @lib.Instruction::local_get(text_local(needle_start)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(needle_index)),
  ]
  for instruction in text_byte_at(array_type, value_chunks, value_index, 0) {
    verify_loop.push(instruction)
  }
  for instruction in text_byte_at(array_type, needle_chunks, needle_index, 0) {
    verify_loop.push(instruction)
  }
  verify_loop.push(@lib.Instruction::i32_ne())
  verify_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        text_i32(0),
        @lib.Instruction::local_set(text_local(matched)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ],
      None,
    ),
  )
  verify_loop.push(@lib.Instruction::local_get(text_local(index)))
  verify_loop.push(text_i32(1))
  verify_loop.push(@lib.Instruction::i32_add())
  verify_loop.push(@lib.Instruction::local_set(text_local(index)))
  verify_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  output.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(verify_loop),
        ),
      ]),
    ),
  )
  output.push(@lib.Instruction::local_get(text_local(matched)))
  output.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(candidate)),
        @lib.Instruction::return_(),
      ],
      None,
    ),
  )
}

///| Allocation-free exact substring search. Short needles filter sixteen

///| candidates at once by their first and last bytes; longer needles use a

///| base-257 rolling fingerprint. Every candidate is verified byte-for-byte,

///| so arithmetic collisions cannot change the result.

///| gives linear scanning work over long and repetitive inputs; every matching

///| fingerprint is verified byte-for-byte, so arithmetic collisions cannot

///| change the result. The standard wrapper keeps one-byte needles on the SIMD

///|
/// `find_byte` path.
fn starshine_text_find_body(
  base : Int,
  value_offset : Int,
  needle_offset : Int,
) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let value_type = @lib.TypeIdx::new(
    (base + value_offset).reinterpret_as_uint(),
  )
  let needle_type = @lib.TypeIdx::new(
    (base + needle_offset).reinterpret_as_uint(),
  )
  let value_ref = 2
  let needle_ref = 3
  let value_chunks = 4
  let needle_chunks = 5
  let value_start = 6
  let needle_start = 7
  let value_length = 8
  let needle_length = 9
  let limit = 10
  let candidate = 11
  let index = 12
  let value_index = 13
  let needle_index = 14
  let matched = 15
  let old_byte = 16
  let new_byte = 17
  let needle_hash = 18
  let window_hash = 19
  let power = 20
  let probe = 21
  let mask = 22
  let lane = 23
  let first_vector = 24
  let last_vector = 25
  let hash_base = @lib.Instruction::i64_const(@lib.I64::new(257L))
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(value_type)),
    @lib.Instruction::local_set(text_local(value_ref)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(needle_type)),
    @lib.Instruction::local_set(text_local(needle_ref)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 0U),
    @lib.Instruction::local_set(text_local(value_chunks)),
    @lib.Instruction::local_get(text_local(needle_ref)),
    @lib.Instruction::struct_get(needle_type, 0U),
    @lib.Instruction::local_set(text_local(needle_chunks)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 1U),
    @lib.Instruction::local_set(text_local(value_start)),
    @lib.Instruction::local_get(text_local(needle_ref)),
    @lib.Instruction::struct_get(needle_type, 1U),
    @lib.Instruction::local_set(text_local(needle_start)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 2U),
    @lib.Instruction::local_set(text_local(value_length)),
    @lib.Instruction::local_get(text_local(needle_ref)),
    @lib.Instruction::struct_get(needle_type, 2U),
    @lib.Instruction::local_tee(text_local(needle_length)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [text_i32(0), @lib.Instruction::return_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(needle_length)),
    @lib.Instruction::local_get(text_local(value_length)),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [text_i32(-1), @lib.Instruction::return_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(value_length)),
    @lib.Instruction::local_get(text_local(needle_length)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_set(text_local(limit)),
    @lib.Instruction::i64_const(@lib.I64::new(0L)),
    @lib.Instruction::local_set(text_local(needle_hash)),
    @lib.Instruction::i64_const(@lib.I64::new(0L)),
    @lib.Instruction::local_set(text_local(window_hash)),
    @lib.Instruction::i64_const(@lib.I64::new(1L)),
    @lib.Instruction::local_set(text_local(power)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(index)),
  ]
  let short_path : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(needle_start)),
    @lib.Instruction::local_set(text_local(needle_index)),
  ]
  for instruction in text_byte_at(array_type, needle_chunks, needle_index, 0) {
    short_path.push(instruction)
  }
  short_path.push(@lib.Instruction::local_set(text_local(old_byte)))
  short_path.push(@lib.Instruction::local_get(text_local(needle_start)))
  short_path.push(@lib.Instruction::local_get(text_local(needle_length)))
  short_path.push(@lib.Instruction::i32_add())
  short_path.push(text_i32(1))
  short_path.push(@lib.Instruction::i32_sub())
  short_path.push(@lib.Instruction::local_set(text_local(needle_index)))
  for instruction in text_byte_at(array_type, needle_chunks, needle_index, 0) {
    short_path.push(instruction)
  }
  short_path.push(@lib.Instruction::local_set(text_local(new_byte)))
  short_path.push(text_i32(0))
  short_path.push(@lib.Instruction::local_set(text_local(candidate)))
  let short_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(limit)),
    @lib.Instruction::local_get(text_local(candidate)),
    @lib.Instruction::i32_sub(),
    text_i32(1),
    @lib.Instruction::i32_add(),
    text_i32(16),
    @lib.Instruction::i32_ge_u(),
  ]
  let batch : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(value_start)),
    @lib.Instruction::local_get(text_local(candidate)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(value_index)),
  ]
  text_load_logical_v128(
    batch, array_type, value_chunks, value_index, first_vector,
  )
  for
    instruction in [
      @lib.Instruction::local_get(text_local(value_start)),
      @lib.Instruction::local_get(text_local(candidate)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_get(text_local(needle_length)),
      @lib.Instruction::i32_add(),
      text_i32(1),
      @lib.Instruction::i32_sub(),
      @lib.Instruction::local_set(text_local(value_index)),
    ] {
    batch.push(instruction)
  }
  text_load_logical_v128(
    batch, array_type, value_chunks, value_index, last_vector,
  )
  for
    instruction in [
      @lib.Instruction::local_get(text_local(first_vector)),
      @lib.Instruction::local_get(text_local(old_byte)),
      @lib.Instruction::i8x16_splat(),
      @lib.Instruction::i8x16_eq(),
      @lib.Instruction::i8x16_bitmask(),
      @lib.Instruction::local_get(text_local(last_vector)),
      @lib.Instruction::local_get(text_local(new_byte)),
      @lib.Instruction::i8x16_splat(),
      @lib.Instruction::i8x16_eq(),
      @lib.Instruction::i8x16_bitmask(),
      @lib.Instruction::i32_and(),
      @lib.Instruction::local_set(text_local(mask)),
    ] {
    batch.push(instruction)
  }
  let candidate_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(mask)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(mask)),
    @lib.Instruction::i32_ctz(),
    @lib.Instruction::local_set(text_local(lane)),
    @lib.Instruction::local_get(text_local(candidate)),
    @lib.Instruction::local_get(text_local(lane)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(probe)),
  ]
  text_verify_bytes_candidate(
    candidate_loop, array_type, value_chunks, needle_chunks, value_start, needle_start,
    needle_length, probe, index, value_index, needle_index, matched,
  )
  for
    instruction in [
      @lib.Instruction::local_get(text_local(mask)),
      @lib.Instruction::local_get(text_local(mask)),
      text_i32(1),
      @lib.Instruction::i32_sub(),
      @lib.Instruction::i32_and(),
      @lib.Instruction::local_set(text_local(mask)),
      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
    ] {
    candidate_loop.push(instruction)
  }
  batch.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(candidate_loop),
        ),
      ]),
    ),
  )
  batch.push(@lib.Instruction::local_get(text_local(candidate)))
  batch.push(text_i32(16))
  batch.push(@lib.Instruction::i32_add())
  batch.push(@lib.Instruction::local_set(text_local(candidate)))
  batch.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  short_loop.push(@lib.Instruction::if_(@lib.BlockType::void_(), batch, None))
  short_loop.push(@lib.Instruction::local_get(text_local(candidate)))
  short_loop.push(@lib.Instruction::local_get(text_local(limit)))
  short_loop.push(@lib.Instruction::i32_gt_u())
  short_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [text_i32(-1), @lib.Instruction::return_()],
      None,
    ),
  )
  short_loop.push(@lib.Instruction::local_get(text_local(candidate)))
  short_loop.push(@lib.Instruction::local_set(text_local(probe)))
  text_verify_bytes_candidate(
    short_loop, array_type, value_chunks, needle_chunks, value_start, needle_start,
    needle_length, probe, index, value_index, needle_index, matched,
  )
  short_loop.push(@lib.Instruction::local_get(text_local(candidate)))
  short_loop.push(text_i32(1))
  short_loop.push(@lib.Instruction::i32_add())
  short_loop.push(@lib.Instruction::local_set(text_local(candidate)))
  short_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  short_path.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(short_loop)),
  )
  body.push(@lib.Instruction::local_get(text_local(needle_length)))
  body.push(text_i32(16))
  body.push(@lib.Instruction::i32_le_u())
  body.push(@lib.Instruction::if_(@lib.BlockType::void_(), short_path, None))
  let hash_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(needle_length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(needle_start)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(needle_index)),
    @lib.Instruction::local_get(text_local(value_start)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(value_index)),
    @lib.Instruction::local_get(text_local(needle_hash)),
    hash_base,
    @lib.Instruction::i64_mul(),
  ]
  for instruction in text_byte_at(array_type, needle_chunks, needle_index, 0) {
    hash_loop.push(instruction)
  }
  hash_loop.push(@lib.Instruction::i64_extend_i32u())
  hash_loop.push(@lib.Instruction::i64_add())
  hash_loop.push(@lib.Instruction::local_set(text_local(needle_hash)))
  hash_loop.push(@lib.Instruction::local_get(text_local(window_hash)))
  hash_loop.push(hash_base)
  hash_loop.push(@lib.Instruction::i64_mul())
  for instruction in text_byte_at(array_type, value_chunks, value_index, 0) {
    hash_loop.push(instruction)
  }
  hash_loop.push(@lib.Instruction::i64_extend_i32u())
  hash_loop.push(@lib.Instruction::i64_add())
  hash_loop.push(@lib.Instruction::local_set(text_local(window_hash)))
  hash_loop.push(@lib.Instruction::local_get(text_local(index)))
  hash_loop.push(@lib.Instruction::local_get(text_local(needle_length)))
  hash_loop.push(text_i32(1))
  hash_loop.push(@lib.Instruction::i32_sub())
  hash_loop.push(@lib.Instruction::i32_lt_u())
  hash_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(power)),
        hash_base,
        @lib.Instruction::i64_mul(),
        @lib.Instruction::local_set(text_local(power)),
      ],
      None,
    ),
  )
  hash_loop.push(@lib.Instruction::local_get(text_local(index)))
  hash_loop.push(text_i32(1))
  hash_loop.push(@lib.Instruction::i32_add())
  hash_loop.push(@lib.Instruction::local_set(text_local(index)))
  hash_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(hash_loop),
        ),
      ]),
    ),
  )
  body.push(text_i32(0))
  body.push(@lib.Instruction::local_set(text_local(candidate)))
  let search_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(needle_hash)),
    @lib.Instruction::local_get(text_local(window_hash)),
    @lib.Instruction::i64_eq(),
  ]
  let verify : Array[@lib.Instruction] = [
    text_i32(1),
    @lib.Instruction::local_set(text_local(matched)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(index)),
  ]
  let verify_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(needle_length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(value_start)),
    @lib.Instruction::local_get(text_local(candidate)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(value_index)),
    @lib.Instruction::local_get(text_local(needle_start)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(needle_index)),
  ]
  for instruction in text_byte_at(array_type, value_chunks, value_index, 0) {
    verify_loop.push(instruction)
  }
  for instruction in text_byte_at(array_type, needle_chunks, needle_index, 0) {
    verify_loop.push(instruction)
  }
  verify_loop.push(@lib.Instruction::i32_ne())
  verify_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        text_i32(0),
        @lib.Instruction::local_set(text_local(matched)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ],
      None,
    ),
  )
  verify_loop.push(@lib.Instruction::local_get(text_local(index)))
  verify_loop.push(text_i32(1))
  verify_loop.push(@lib.Instruction::i32_add())
  verify_loop.push(@lib.Instruction::local_set(text_local(index)))
  verify_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  verify.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(verify_loop),
        ),
      ]),
    ),
  )
  verify.push(@lib.Instruction::local_get(text_local(matched)))
  verify.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(candidate)),
        @lib.Instruction::return_(),
      ],
      None,
    ),
  )
  search_loop.push(@lib.Instruction::if_(@lib.BlockType::void_(), verify, None))
  search_loop.push(@lib.Instruction::local_get(text_local(candidate)))
  search_loop.push(@lib.Instruction::local_get(text_local(limit)))
  search_loop.push(@lib.Instruction::i32_ge_u())
  search_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [text_i32(-1), @lib.Instruction::return_()],
      None,
    ),
  )
  search_loop.push(@lib.Instruction::local_get(text_local(value_start)))
  search_loop.push(@lib.Instruction::local_get(text_local(candidate)))
  search_loop.push(@lib.Instruction::i32_add())
  search_loop.push(@lib.Instruction::local_set(text_local(value_index)))
  for instruction in text_byte_at(array_type, value_chunks, value_index, 0) {
    search_loop.push(instruction)
  }
  search_loop.push(@lib.Instruction::local_set(text_local(old_byte)))
  search_loop.push(@lib.Instruction::local_get(text_local(value_start)))
  search_loop.push(@lib.Instruction::local_get(text_local(candidate)))
  search_loop.push(@lib.Instruction::i32_add())
  search_loop.push(@lib.Instruction::local_get(text_local(needle_length)))
  search_loop.push(@lib.Instruction::i32_add())
  search_loop.push(@lib.Instruction::local_set(text_local(value_index)))
  for instruction in text_byte_at(array_type, value_chunks, value_index, 0) {
    search_loop.push(instruction)
  }
  search_loop.push(@lib.Instruction::local_set(text_local(new_byte)))
  search_loop.push(@lib.Instruction::local_get(text_local(window_hash)))
  search_loop.push(@lib.Instruction::local_get(text_local(old_byte)))
  search_loop.push(@lib.Instruction::i64_extend_i32u())
  search_loop.push(@lib.Instruction::local_get(text_local(power)))
  search_loop.push(@lib.Instruction::i64_mul())
  search_loop.push(@lib.Instruction::i64_sub())
  search_loop.push(hash_base)
  search_loop.push(@lib.Instruction::i64_mul())
  search_loop.push(@lib.Instruction::local_get(text_local(new_byte)))
  search_loop.push(@lib.Instruction::i64_extend_i32u())
  search_loop.push(@lib.Instruction::i64_add())
  search_loop.push(@lib.Instruction::local_set(text_local(window_hash)))
  search_loop.push(@lib.Instruction::local_get(text_local(candidate)))
  search_loop.push(text_i32(1))
  search_loop.push(@lib.Instruction::i32_add())
  search_loop.push(@lib.Instruction::local_set(text_local(candidate)))
  search_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new(search_loop),
    ),
  )
  body.push(text_i32(-1))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + value_offset),
      text_runtime_ref(base + needle_offset),
      text_runtime_ref(base),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::v128(),
      @lib.ValType::v128(),
    ]),
    @lib.Expr::new(body),
  )
}

///| Exact allocation-free prefix or suffix matching over arbitrary logical

///|
/// Bytes ranges. Empty needles match and longer needles fail immediately.
fn starshine_text_affix_body(
  base : Int,
  value_offset : Int,
  needle_offset : Int,
  suffix : Bool,
) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let value_type = @lib.TypeIdx::new(
    (base + value_offset).reinterpret_as_uint(),
  )
  let needle_type = @lib.TypeIdx::new(
    (base + needle_offset).reinterpret_as_uint(),
  )
  let value_ref = 2
  let needle_ref = 3
  let value_chunks = 4
  let needle_chunks = 5
  let value_length = 6
  let needle_length = 7
  let value_index = 8
  let needle_index = 9
  let index = 10
  let value_vector = 11
  let needle_vector = 12
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(value_type)),
    @lib.Instruction::local_set(text_local(value_ref)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(needle_type)),
    @lib.Instruction::local_set(text_local(needle_ref)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 2U),
    @lib.Instruction::local_set(text_local(value_length)),
    @lib.Instruction::local_get(text_local(needle_ref)),
    @lib.Instruction::struct_get(needle_type, 2U),
    @lib.Instruction::local_tee(text_local(needle_length)),
    @lib.Instruction::local_get(text_local(value_length)),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::if_(@lib.BlockType::void_(), text_false_return(), None),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 0U),
    @lib.Instruction::local_set(text_local(value_chunks)),
    @lib.Instruction::local_get(text_local(needle_ref)),
    @lib.Instruction::struct_get(needle_type, 0U),
    @lib.Instruction::local_set(text_local(needle_chunks)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 1U),
  ]
  if suffix {
    body.push(@lib.Instruction::local_get(text_local(value_length)))
    body.push(@lib.Instruction::local_get(text_local(needle_length)))
    body.push(@lib.Instruction::i32_sub())
    body.push(@lib.Instruction::i32_add())
  }
  body.push(@lib.Instruction::local_set(text_local(value_index)))
  for
    instruction in [
      @lib.Instruction::local_get(text_local(needle_ref)),
      @lib.Instruction::struct_get(needle_type, 1U),
      @lib.Instruction::local_set(text_local(needle_index)),
      text_i32(0),
      @lib.Instruction::local_set(text_local(index)),
    ] {
    body.push(instruction)
  }
  let loop_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(needle_length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [text_i32(1), @lib.Instruction::return_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(needle_length)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_sub(),
    text_i32(16),
    @lib.Instruction::i32_ge_u(),
  ]
  let full : Array[@lib.Instruction] = []
  text_load_logical_v128(
    full, array_type, value_chunks, value_index, value_vector,
  )
  text_load_logical_v128(
    full, array_type, needle_chunks, needle_index, needle_vector,
  )
  for
    instruction in [
      @lib.Instruction::local_get(text_local(value_vector)),
      @lib.Instruction::local_get(text_local(needle_vector)),
      @lib.Instruction::v128_xor(),
      @lib.Instruction::v128_any_true(),
      @lib.Instruction::if_(@lib.BlockType::void_(), text_false_return(), None),
    ] {
    full.push(instruction)
  }
  for physical_index in [value_index, needle_index] {
    full.push(@lib.Instruction::local_get(text_local(physical_index)))
    full.push(text_i32(16))
    full.push(@lib.Instruction::i32_add())
    full.push(@lib.Instruction::local_set(text_local(physical_index)))
  }
  full.push(@lib.Instruction::local_get(text_local(index)))
  full.push(text_i32(16))
  full.push(@lib.Instruction::i32_add())
  full.push(@lib.Instruction::local_set(text_local(index)))
  full.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  loop_body.push(@lib.Instruction::if_(@lib.BlockType::void_(), full, None))
  for instruction in text_byte_at(array_type, value_chunks, value_index, 0) {
    loop_body.push(instruction)
  }
  for instruction in text_byte_at(array_type, needle_chunks, needle_index, 0) {
    loop_body.push(instruction)
  }
  loop_body.push(@lib.Instruction::i32_ne())
  loop_body.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), text_false_return(), None),
  )
  for physical_index in [value_index, needle_index] {
    loop_body.push(@lib.Instruction::local_get(text_local(physical_index)))
    loop_body.push(text_i32(1))
    loop_body.push(@lib.Instruction::i32_add())
    loop_body.push(@lib.Instruction::local_set(text_local(physical_index)))
  }
  loop_body.push(@lib.Instruction::local_get(text_local(index)))
  loop_body.push(text_i32(1))
  loop_body.push(@lib.Instruction::i32_add())
  loop_body.push(@lib.Instruction::local_set(text_local(index)))
  loop_body.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(loop_body)),
  )
  body.push(text_i32(1))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + value_offset),
      text_runtime_ref(base + needle_offset),
      text_runtime_ref(base),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::v128(),
      @lib.ValType::v128(),
    ]),
    @lib.Expr::new(body),
  )
}

///| Bounds-checked dynamic byte access over V128 chunks. Out-of-range access

///|
/// follows Wasm's trapping index semantics.
fn starshine_text_byte_at_type_body(base : Int, type_offset : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let value_type = @lib.TypeIdx::new((base + type_offset).reinterpret_as_uint())
  let value_ref = 2
  let chunks = 3
  let physical_index = 4
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(value_type)),
    @lib.Instruction::local_set(text_local(value_ref)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 2U),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 0U),
    @lib.Instruction::local_set(text_local(chunks)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 1U),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(physical_index)),
  ]
  for instruction in text_byte_at(array_type, chunks, physical_index, 0) {
    body.push(instruction)
  }
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + type_offset),
      text_runtime_ref(base),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn starshine_text_byte_at_body(base : Int, string_ : Bool) -> @lib.Func {
  starshine_text_byte_at_type_body(base, if string_ { 1 } else { 2 })
}

///|
fn starshine_text_hash_body(base : Int, type_offset : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let value_type = @lib.TypeIdx::new((base + type_offset).reinterpret_as_uint())
  let value_ref = 1
  let chunks = 2
  let physical_index = 3
  let length = 4
  let index = 5
  let hash = 6
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(value_type)),
    @lib.Instruction::local_set(text_local(value_ref)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 0U),
    @lib.Instruction::local_set(text_local(chunks)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 1U),
    @lib.Instruction::local_set(text_local(physical_index)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 2U),
    @lib.Instruction::local_set(text_local(length)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(index)),
    @lib.Instruction::i64_const(
      @lib.I64::new(14695981039346656037UL.reinterpret_as_int64()),
    ),
    @lib.Instruction::local_set(text_local(hash)),
  ]
  let loop_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(hash)),
        @lib.Instruction::return_(),
      ],
      None,
    ),
    @lib.Instruction::local_get(text_local(hash)),
  ]
  for instruction in text_byte_at(array_type, chunks, physical_index, 0) {
    loop_body.push(instruction)
  }
  for
    instruction in [
      @lib.Instruction::i64_extend_i32u(),
      @lib.Instruction::i64_xor(),
      @lib.Instruction::i64_const(@lib.I64::new(1099511628211L)),
      @lib.Instruction::i64_mul(),
      @lib.Instruction::local_set(text_local(hash)),
      @lib.Instruction::local_get(text_local(physical_index)),
      text_i32(1),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(text_local(physical_index)),
      @lib.Instruction::local_get(text_local(index)),
      text_i32(1),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(text_local(index)),
      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
    ] {
    loop_body.push(instruction)
  }
  body.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(loop_body)),
  )
  body.push(@lib.Instruction::local_get(text_local(hash)))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + type_offset),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
/// Construct a bounds-checked shared range over arbitrary Bytes.
fn starshine_bytes_view_body(base : Int) -> @lib.Func {
  let bytes_type = @lib.TypeIdx::new((base + 2).reinterpret_as_uint())
  let bytes_ref = 3
  let source_length = 4
  @lib.Func::new(
    @lib.Locals::from_types([text_runtime_ref(base + 2), @lib.ValType::i32()]),
    @lib.Expr::new([
      @lib.Instruction::local_get(text_local(0)),
      @lib.Instruction::ref_cast(false, @lib.HeapType::new(bytes_type)),
      @lib.Instruction::local_set(text_local(bytes_ref)),
      @lib.Instruction::local_get(text_local(bytes_ref)),
      @lib.Instruction::struct_get(bytes_type, 2U),
      @lib.Instruction::local_set(text_local(source_length)),
      @lib.Instruction::local_get(text_local(1)),
      @lib.Instruction::local_get(text_local(source_length)),
      @lib.Instruction::i32_gt_u(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::unreachable_()],
        None,
      ),
      @lib.Instruction::local_get(text_local(2)),
      @lib.Instruction::local_get(text_local(source_length)),
      @lib.Instruction::local_get(text_local(1)),
      @lib.Instruction::i32_sub(),
      @lib.Instruction::i32_gt_u(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::unreachable_()],
        None,
      ),
      @lib.Instruction::local_get(text_local(bytes_ref)),
      @lib.Instruction::struct_get(bytes_type, 0U),
      @lib.Instruction::local_get(text_local(bytes_ref)),
      @lib.Instruction::struct_get(bytes_type, 1U),
      @lib.Instruction::local_get(text_local(1)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_get(text_local(2)),
      @lib.Instruction::struct_new(bytes_type),
    ]),
  )
}

///|
/// Construct a UTF-8-boundary-checked shared view over a String.
fn starshine_string_view_body(base : Int, source_offset : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let source_type = @lib.TypeIdx::new(
    (base + source_offset).reinterpret_as_uint(),
  )
  let view_type = @lib.TypeIdx::new((base + 3).reinterpret_as_uint())
  let string_ref = 3
  let chunks = 4
  let source_length = 5
  let absolute_start = 6
  let relative_end = 7
  let boundary_byte = 8
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(source_type)),
    @lib.Instruction::local_set(text_local(string_ref)),
    @lib.Instruction::local_get(text_local(string_ref)),
    @lib.Instruction::struct_get(source_type, 2U),
    @lib.Instruction::local_set(text_local(source_length)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::local_get(text_local(source_length)),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(2)),
    @lib.Instruction::local_get(text_local(source_length)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(string_ref)),
    @lib.Instruction::struct_get(source_type, 0U),
    @lib.Instruction::local_set(text_local(chunks)),
    @lib.Instruction::local_get(text_local(string_ref)),
    @lib.Instruction::struct_get(source_type, 1U),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(absolute_start)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::local_get(text_local(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(relative_end)),
  ]
  let start_check : Array[@lib.Instruction] = []
  for instruction in text_byte_at(array_type, chunks, absolute_start, 0) {
    start_check.push(instruction)
  }
  start_check.push(@lib.Instruction::local_set(text_local(boundary_byte)))
  start_check.push(@lib.Instruction::local_get(text_local(boundary_byte)))
  start_check.push(text_i32(0xC0))
  start_check.push(@lib.Instruction::i32_and())
  start_check.push(text_i32(0x80))
  start_check.push(@lib.Instruction::i32_eq())
  start_check.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
  )
  body.push(@lib.Instruction::local_get(text_local(1)))
  body.push(@lib.Instruction::i32_eqz())
  body.push(@lib.Instruction::i32_eqz())
  body.push(@lib.Instruction::if_(@lib.BlockType::void_(), start_check, None))
  let end_check : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(absolute_start)),
    @lib.Instruction::local_get(text_local(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(absolute_start)),
  ]
  for instruction in text_byte_at(array_type, chunks, absolute_start, 0) {
    end_check.push(instruction)
  }
  end_check.push(@lib.Instruction::local_set(text_local(boundary_byte)))
  end_check.push(@lib.Instruction::local_get(text_local(boundary_byte)))
  end_check.push(text_i32(0xC0))
  end_check.push(@lib.Instruction::i32_and())
  end_check.push(text_i32(0x80))
  end_check.push(@lib.Instruction::i32_eq())
  end_check.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
  )
  body.push(@lib.Instruction::local_get(text_local(relative_end)))
  body.push(@lib.Instruction::local_get(text_local(source_length)))
  body.push(@lib.Instruction::i32_lt_u())
  body.push(@lib.Instruction::if_(@lib.BlockType::void_(), end_check, None))
  body.push(@lib.Instruction::local_get(text_local(chunks)))
  body.push(@lib.Instruction::local_get(text_local(string_ref)))
  body.push(@lib.Instruction::struct_get(source_type, 1U))
  body.push(@lib.Instruction::local_get(text_local(1)))
  body.push(@lib.Instruction::i32_add())
  body.push(@lib.Instruction::local_get(text_local(2)))
  body.push(@lib.Instruction::struct_new(view_type))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + source_offset),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn starshine_text_rewrap_body(
  base : Int,
  source_offset : Int,
  target_offset : Int,
) -> @lib.Func {
  let source_type = @lib.TypeIdx::new(
    (base + source_offset).reinterpret_as_uint(),
  )
  let target_type = @lib.TypeIdx::new(
    (base + target_offset).reinterpret_as_uint(),
  )
  @lib.Func::new(
    @lib.Locals::from_types([text_runtime_ref(base + source_offset)]),
    @lib.Expr::new([
      @lib.Instruction::local_get(text_local(0)),
      @lib.Instruction::ref_cast(false, @lib.HeapType::new(source_type)),
      @lib.Instruction::local_tee(text_local(1)),
      @lib.Instruction::struct_get(source_type, 0U),
      @lib.Instruction::local_get(text_local(1)),
      @lib.Instruction::struct_get(source_type, 1U),
      @lib.Instruction::local_get(text_local(1)),
      @lib.Instruction::struct_get(source_type, 2U),
      @lib.Instruction::struct_new(target_type),
    ]),
  )
}

///|
fn starshine_text_builder_new_body(
  base : Int,
  builder_offset : Int,
  default_ : Bool,
) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let builder_type = @lib.TypeIdx::new(
    (base + builder_offset).reinterpret_as_uint(),
  )
  let body : Array[@lib.Instruction] = []
  if default_ {
    body.push(text_i32(4))
  } else {
    body.push(@lib.Instruction::local_get(text_local(0)))
    body.push(text_i32(4))
    body.push(@lib.Instruction::i32_shr_u())
    body.push(@lib.Instruction::local_get(text_local(0)))
    body.push(text_i32(15))
    body.push(@lib.Instruction::i32_and())
    body.push(text_i32(0))
    body.push(@lib.Instruction::i32_ne())
    body.push(@lib.Instruction::i32_add())
  }
  body.push(@lib.Instruction::array_new_default(array_type))
  body.push(text_i32(0))
  body.push(text_i32(0))
  body.push(@lib.Instruction::struct_new(builder_type))
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn starshine_text_builder_length_body(
  base : Int,
  builder_offset : Int,
) -> @lib.Func {
  let builder_type = @lib.TypeIdx::new(
    (base + builder_offset).reinterpret_as_uint(),
  )
  let builder_ref = 1
  @lib.Func::new(
    @lib.Locals::from_types([text_runtime_ref(base + builder_offset)]),
    @lib.Expr::new([
      @lib.Instruction::local_get(text_local(0)),
      @lib.Instruction::ref_cast(false, @lib.HeapType::new(builder_type)),
      @lib.Instruction::local_tee(text_local(builder_ref)),
      @lib.Instruction::struct_get(builder_type, 2U),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::unreachable_()],
        None,
      ),
      @lib.Instruction::local_get(text_local(builder_ref)),
      @lib.Instruction::struct_get(builder_type, 1U),
    ]),
  )
}

///|
/// Write one logical V128 into a possibly unaligned mutable chunk range.
fn text_write_logical_v128(
  output : Array[@lib.Instruction],
  array_type : @lib.TypeIdx,
  chunks_local : Int,
  index_local : Int,
  vector_local : Int,
  mask_local : Int,
) -> Unit {
  output.push(@lib.Instruction::local_get(text_local(index_local)))
  output.push(text_i32(15))
  output.push(@lib.Instruction::i32_and())
  output.push(@lib.Instruction::i32_eqz())
  let aligned : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::local_get(text_local(vector_local)),
    @lib.Instruction::array_set(array_type),
  ]
  let unaligned : Array[@lib.Instruction] = [
    @lib.Instruction::v128_const(
      b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
      b'\x09', b'\x0A', b'\x0B', b'\x0C', b'\x0D', b'\x0E', b'\x0F',
    ),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::i8x16_lt_u(),
    @lib.Instruction::local_set(text_local(mask_local)),
    @lib.Instruction::local_get(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::local_get(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::local_get(text_local(vector_local)),
    @lib.Instruction::v128_const(
      b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
      b'\x09', b'\x0A', b'\x0B', b'\x0C', b'\x0D', b'\x0E', b'\x0F',
    ),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::i8x16_sub(),
    @lib.Instruction::i8x16_swizzle(),
    @lib.Instruction::local_get(text_local(mask_local)),
    @lib.Instruction::v128_bitselect(),
    @lib.Instruction::array_set(array_type),
    @lib.Instruction::local_get(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    text_i32(1),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(text_local(vector_local)),
    @lib.Instruction::v128_const(
      b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
      b'\x09', b'\x0A', b'\x0B', b'\x0C', b'\x0D', b'\x0E', b'\x0F',
    ),
    text_i32(16),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::i8x16_splat(),
    @lib.Instruction::i8x16_add(),
    @lib.Instruction::i8x16_swizzle(),
    @lib.Instruction::local_get(text_local(chunks_local)),
    @lib.Instruction::local_get(text_local(index_local)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    text_i32(1),
    @lib.Instruction::i32_add(),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::local_get(text_local(mask_local)),
    @lib.Instruction::v128_bitselect(),
    @lib.Instruction::array_set(array_type),
  ]
  output.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), aligned, Some(unaligned)),
  )
}

///|
/// Write one byte into a mutable V128 chunk array.
fn text_write_byte(
  output : Array[@lib.Instruction],
  array_type : @lib.TypeIdx,
  chunks_local : Int,
  index_local : Int,
  byte_local : Int,
) -> Unit {
  output.push(@lib.Instruction::local_get(text_local(chunks_local)))
  output.push(@lib.Instruction::local_get(text_local(index_local)))
  output.push(text_i32(4))
  output.push(@lib.Instruction::i32_shr_u())
  output.push(@lib.Instruction::local_get(text_local(byte_local)))
  output.push(@lib.Instruction::i8x16_splat())
  output.push(@lib.Instruction::local_get(text_local(chunks_local)))
  output.push(@lib.Instruction::local_get(text_local(index_local)))
  output.push(text_i32(4))
  output.push(@lib.Instruction::i32_shr_u())
  output.push(@lib.Instruction::array_get(array_type))
  output.push(
    @lib.Instruction::v128_const(
      b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
      b'\x09', b'\x0A', b'\x0B', b'\x0C', b'\x0D', b'\x0E', b'\x0F',
    ),
  )
  output.push(@lib.Instruction::local_get(text_local(index_local)))
  output.push(text_i32(15))
  output.push(@lib.Instruction::i32_and())
  output.push(@lib.Instruction::i8x16_splat())
  output.push(@lib.Instruction::i8x16_eq())
  output.push(@lib.Instruction::v128_bitselect())
  output.push(@lib.Instruction::array_set(array_type))
}

///| Copy one logical byte range into a start-zero destination range. Complete

///| vectors use dynamic aligned/unaligned V128 loads and masked V128 writes;

///|
/// the exact tail remains scalar so zero padding is preserved.
fn text_copy_logical_range(
  output : Array[@lib.Instruction],
  array_type : @lib.TypeIdx,
  source_chunks : Int,
  source_start : Int,
  source_length : Int,
  destination_chunks : Int,
  destination_base : Int,
  index : Int,
  source_index : Int,
  destination_index : Int,
  byte : Int,
  vector : Int,
  mask : Int,
) -> Unit {
  output.push(text_i32(0))
  output.push(@lib.Instruction::local_set(text_local(index)))
  let copy_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(source_length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(source_start)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(source_index)),
    @lib.Instruction::local_get(text_local(destination_base)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(destination_index)),
    @lib.Instruction::local_get(text_local(index)),
    text_i32(16),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(text_local(source_length)),
    @lib.Instruction::i32_le_u(),
  ]
  let copy_full : Array[@lib.Instruction] = []
  text_load_logical_v128(
    copy_full, array_type, source_chunks, source_index, vector,
  )
  text_write_logical_v128(
    copy_full, array_type, destination_chunks, destination_index, vector, mask,
  )
  copy_full.push(@lib.Instruction::local_get(text_local(index)))
  copy_full.push(text_i32(16))
  copy_full.push(@lib.Instruction::i32_add())
  copy_full.push(@lib.Instruction::local_set(text_local(index)))
  copy_full.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  copy_loop.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), copy_full, None),
  )
  for instruction in text_byte_at(array_type, source_chunks, source_index, 0) {
    copy_loop.push(instruction)
  }
  copy_loop.push(@lib.Instruction::local_set(text_local(byte)))
  text_write_byte(
    copy_loop, array_type, destination_chunks, destination_index, byte,
  )
  copy_loop.push(@lib.Instruction::local_get(text_local(index)))
  copy_loop.push(text_i32(1))
  copy_loop.push(@lib.Instruction::i32_add())
  copy_loop.push(@lib.Instruction::local_set(text_local(index)))
  copy_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  output.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(copy_loop),
        ),
      ]),
    ),
  )
}

///|
fn starshine_text_concat_body(
  base : Int,
  left_offset : Int,
  right_offset : Int,
  target_offset : Int,
) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let left_type = @lib.TypeIdx::new((base + left_offset).reinterpret_as_uint())
  let right_type = @lib.TypeIdx::new(
    (base + right_offset).reinterpret_as_uint(),
  )
  let target_type = @lib.TypeIdx::new(
    (base + target_offset).reinterpret_as_uint(),
  )
  let left_ref = 2
  let right_ref = 3
  let left_chunks = 4
  let right_chunks = 5
  let destination_chunks = 6
  let left_start = 7
  let left_length = 8
  let right_start = 9
  let right_length = 10
  let total_length = 11
  let required_chunks = 12
  let destination_base = 13
  let index = 14
  let source_index = 15
  let destination_index = 16
  let byte = 17
  let vector = 18
  let mask = 19
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(left_type)),
    @lib.Instruction::local_set(text_local(left_ref)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(right_type)),
    @lib.Instruction::local_set(text_local(right_ref)),
    @lib.Instruction::local_get(text_local(left_ref)),
    @lib.Instruction::struct_get(left_type, 0U),
    @lib.Instruction::local_set(text_local(left_chunks)),
    @lib.Instruction::local_get(text_local(left_ref)),
    @lib.Instruction::struct_get(left_type, 1U),
    @lib.Instruction::local_set(text_local(left_start)),
    @lib.Instruction::local_get(text_local(left_ref)),
    @lib.Instruction::struct_get(left_type, 2U),
    @lib.Instruction::local_set(text_local(left_length)),
    @lib.Instruction::local_get(text_local(right_ref)),
    @lib.Instruction::struct_get(right_type, 0U),
    @lib.Instruction::local_set(text_local(right_chunks)),
    @lib.Instruction::local_get(text_local(right_ref)),
    @lib.Instruction::struct_get(right_type, 1U),
    @lib.Instruction::local_set(text_local(right_start)),
    @lib.Instruction::local_get(text_local(right_ref)),
    @lib.Instruction::struct_get(right_type, 2U),
    @lib.Instruction::local_set(text_local(right_length)),
    @lib.Instruction::local_get(text_local(left_length)),
    @lib.Instruction::local_get(text_local(right_length)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_tee(text_local(total_length)),
    @lib.Instruction::local_get(text_local(left_length)),
    @lib.Instruction::i32_lt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(total_length)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::local_get(text_local(total_length)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    text_i32(0),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_tee(text_local(required_chunks)),
    @lib.Instruction::array_new_default(array_type),
    @lib.Instruction::local_set(text_local(destination_chunks)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(destination_base)),
  ]
  text_copy_logical_range(
    body, array_type, left_chunks, left_start, left_length, destination_chunks, destination_base,
    index, source_index, destination_index, byte, vector, mask,
  )
  body.push(@lib.Instruction::local_get(text_local(left_length)))
  body.push(@lib.Instruction::local_set(text_local(destination_base)))
  text_copy_logical_range(
    body, array_type, right_chunks, right_start, right_length, destination_chunks,
    destination_base, index, source_index, destination_index, byte, vector, mask,
  )
  body.push(@lib.Instruction::local_get(text_local(destination_chunks)))
  body.push(text_i32(0))
  body.push(@lib.Instruction::local_get(text_local(total_length)))
  body.push(@lib.Instruction::struct_new(target_type))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + left_offset),
      text_runtime_ref(base + right_offset),
      text_runtime_ref(base),
      text_runtime_ref(base),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::v128(),
      @lib.ValType::v128(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn starshine_text_builder_append_body(
  base : Int,
  builder_offset : Int,
  source_offset : Int,
) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let source_type = @lib.TypeIdx::new(
    (base + source_offset).reinterpret_as_uint(),
  )
  let builder_type = @lib.TypeIdx::new(
    (base + builder_offset).reinterpret_as_uint(),
  )
  let builder_ref = 2
  let source_ref = 3
  let chunks = 4
  let source_chunks = 5
  let old_length = 6
  let source_start = 7
  let source_length = 8
  let required_length = 9
  let required_chunks = 10
  let capacity_chunks = 11
  let new_chunks = 12
  let copy_index = 13
  let index = 14
  let source_index = 15
  let destination_index = 16
  let byte = 17
  let vector = 18
  let mask = 19
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(builder_type)),
    @lib.Instruction::local_set(text_local(builder_ref)),
    @lib.Instruction::local_get(text_local(builder_ref)),
    @lib.Instruction::struct_get(builder_type, 2U),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(source_type)),
    @lib.Instruction::local_set(text_local(source_ref)),
    @lib.Instruction::local_get(text_local(builder_ref)),
    @lib.Instruction::struct_get(builder_type, 0U),
    @lib.Instruction::local_set(text_local(chunks)),
    @lib.Instruction::local_get(text_local(source_ref)),
    @lib.Instruction::struct_get(source_type, 0U),
    @lib.Instruction::local_set(text_local(source_chunks)),
    @lib.Instruction::local_get(text_local(builder_ref)),
    @lib.Instruction::struct_get(builder_type, 1U),
    @lib.Instruction::local_set(text_local(old_length)),
    @lib.Instruction::local_get(text_local(source_ref)),
    @lib.Instruction::struct_get(source_type, 1U),
    @lib.Instruction::local_set(text_local(source_start)),
    @lib.Instruction::local_get(text_local(source_ref)),
    @lib.Instruction::struct_get(source_type, 2U),
    @lib.Instruction::local_set(text_local(source_length)),
    @lib.Instruction::local_get(text_local(old_length)),
    @lib.Instruction::local_get(text_local(source_length)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_tee(text_local(required_length)),
    @lib.Instruction::local_get(text_local(old_length)),
    @lib.Instruction::i32_lt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(required_length)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::local_get(text_local(required_length)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    text_i32(0),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(required_chunks)),
    @lib.Instruction::local_get(text_local(chunks)),
    @lib.Instruction::array_len(),
    @lib.Instruction::local_set(text_local(capacity_chunks)),
  ]
  let grow : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    text_i32(1),
    @lib.Instruction::i32_shl(),
    @lib.Instruction::local_set(text_local(capacity_chunks)),
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    @lib.Instruction::local_get(text_local(required_chunks)),
    @lib.Instruction::i32_lt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(required_chunks)),
        @lib.Instruction::local_set(text_local(capacity_chunks)),
      ],
      None,
    ),
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    @lib.Instruction::array_new_default(array_type),
    @lib.Instruction::local_set(text_local(new_chunks)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(copy_index)),
  ]
  let copy_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::local_get(text_local(old_length)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::local_get(text_local(old_length)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    text_i32(0),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(new_chunks)),
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::local_get(text_local(chunks)),
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::array_set(array_type),
    @lib.Instruction::local_get(text_local(copy_index)),
    text_i32(1),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(copy_index)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]
  grow.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(copy_loop),
        ),
      ]),
    ),
  )
  grow.push(@lib.Instruction::local_get(text_local(builder_ref)))
  grow.push(@lib.Instruction::local_get(text_local(new_chunks)))
  grow.push(@lib.Instruction::struct_set(builder_type, 0U))
  grow.push(@lib.Instruction::local_get(text_local(new_chunks)))
  grow.push(@lib.Instruction::local_set(text_local(chunks)))
  body.push(@lib.Instruction::local_get(text_local(required_chunks)))
  body.push(@lib.Instruction::local_get(text_local(capacity_chunks)))
  body.push(@lib.Instruction::i32_gt_u())
  body.push(@lib.Instruction::if_(@lib.BlockType::void_(), grow, None))
  body.push(text_i32(0))
  body.push(@lib.Instruction::local_set(text_local(index)))
  let append_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::local_get(text_local(source_length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(source_start)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(source_index)),
    @lib.Instruction::local_get(text_local(old_length)),
    @lib.Instruction::local_get(text_local(index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(destination_index)),
    @lib.Instruction::local_get(text_local(index)),
    text_i32(16),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(text_local(source_length)),
    @lib.Instruction::i32_le_u(),
  ]
  let append_full : Array[@lib.Instruction] = []
  text_load_logical_v128(
    append_full, array_type, source_chunks, source_index, vector,
  )
  text_write_logical_v128(
    append_full, array_type, chunks, destination_index, vector, mask,
  )
  append_full.push(@lib.Instruction::local_get(text_local(index)))
  append_full.push(text_i32(16))
  append_full.push(@lib.Instruction::i32_add())
  append_full.push(@lib.Instruction::local_set(text_local(index)))
  append_full.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  append_loop.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), append_full, None),
  )
  for instruction in text_byte_at(array_type, source_chunks, source_index, 0) {
    append_loop.push(instruction)
  }
  append_loop.push(@lib.Instruction::local_set(text_local(byte)))
  text_write_byte(append_loop, array_type, chunks, destination_index, byte)
  append_loop.push(@lib.Instruction::local_get(text_local(index)))
  append_loop.push(text_i32(1))
  append_loop.push(@lib.Instruction::i32_add())
  append_loop.push(@lib.Instruction::local_set(text_local(index)))
  append_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(append_loop),
        ),
      ]),
    ),
  )
  body.push(@lib.Instruction::local_get(text_local(builder_ref)))
  body.push(@lib.Instruction::local_get(text_local(required_length)))
  body.push(@lib.Instruction::struct_set(builder_type, 1U))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + builder_offset),
      text_runtime_ref(base + source_offset),
      text_runtime_ref(base),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::v128(),
      @lib.ValType::v128(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn starshine_text_builder_append_byte_body(
  base : Int,
  builder_offset : Int,
  ascii_only : Bool,
) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let builder_type = @lib.TypeIdx::new(
    (base + builder_offset).reinterpret_as_uint(),
  )
  let builder_ref = 2
  let chunks = 3
  let old_length = 4
  let required_length = 5
  let capacity_chunks = 6
  let new_chunks = 7
  let copy_index = 8
  let body : Array[@lib.Instruction] = []
  if ascii_only {
    body.push(@lib.Instruction::local_get(text_local(1)))
    body.push(text_i32(0x7F))
    body.push(@lib.Instruction::i32_gt_u())
    body.push(
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::unreachable_()],
        None,
      ),
    )
  }
  for
    instruction in [
      @lib.Instruction::local_get(text_local(0)),
      @lib.Instruction::ref_cast(false, @lib.HeapType::new(builder_type)),
      @lib.Instruction::local_set(text_local(builder_ref)),
      @lib.Instruction::local_get(text_local(builder_ref)),
      @lib.Instruction::struct_get(builder_type, 2U),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::unreachable_()],
        None,
      ),
      @lib.Instruction::local_get(text_local(builder_ref)),
      @lib.Instruction::struct_get(builder_type, 0U),
      @lib.Instruction::local_set(text_local(chunks)),
      @lib.Instruction::local_get(text_local(builder_ref)),
      @lib.Instruction::struct_get(builder_type, 1U),
      @lib.Instruction::local_tee(text_local(old_length)),
      text_i32(1),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_tee(text_local(required_length)),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::unreachable_()],
        None,
      ),
      @lib.Instruction::local_get(text_local(chunks)),
      @lib.Instruction::array_len(),
      @lib.Instruction::local_set(text_local(capacity_chunks)),
    ] {
    body.push(instruction)
  }
  let grow : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    text_i32(1),
    @lib.Instruction::i32_shl(),
    @lib.Instruction::local_set(text_local(capacity_chunks)),
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [text_i32(1), @lib.Instruction::local_set(text_local(capacity_chunks))],
      None,
    ),
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    @lib.Instruction::array_new_default(array_type),
    @lib.Instruction::local_set(text_local(new_chunks)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(copy_index)),
  ]
  let copy_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::local_get(text_local(old_length)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::local_get(text_local(old_length)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    text_i32(0),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(new_chunks)),
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::local_get(text_local(chunks)),
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::array_set(array_type),
    @lib.Instruction::local_get(text_local(copy_index)),
    text_i32(1),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(copy_index)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]
  grow.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(copy_loop),
        ),
      ]),
    ),
  )
  grow.push(@lib.Instruction::local_get(text_local(builder_ref)))
  grow.push(@lib.Instruction::local_get(text_local(new_chunks)))
  grow.push(@lib.Instruction::struct_set(builder_type, 0U))
  grow.push(@lib.Instruction::local_get(text_local(new_chunks)))
  grow.push(@lib.Instruction::local_set(text_local(chunks)))
  body.push(@lib.Instruction::local_get(text_local(required_length)))
  body.push(@lib.Instruction::local_get(text_local(capacity_chunks)))
  body.push(text_i32(4))
  body.push(@lib.Instruction::i32_shl())
  body.push(@lib.Instruction::i32_gt_u())
  body.push(@lib.Instruction::if_(@lib.BlockType::void_(), grow, None))
  text_write_byte(body, array_type, chunks, old_length, 1)
  body.push(@lib.Instruction::local_get(text_local(builder_ref)))
  body.push(@lib.Instruction::local_get(text_local(required_length)))
  body.push(@lib.Instruction::struct_set(builder_type, 1U))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + builder_offset),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      text_runtime_ref(base),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn starshine_string_builder_append_scalar_body(base : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let builder_type = @lib.TypeIdx::new((base + 4).reinterpret_as_uint())
  let builder_ref = 2
  let chunks = 3
  let old_length = 4
  let encoded_length = 5
  let required_length = 6
  let required_chunks = 7
  let capacity_chunks = 8
  let new_chunks = 9
  let copy_index = 10
  let b0 = 11
  let b1 = 12
  let b2 = 13
  let b3 = 14
  let write_index = 15
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(builder_type)),
    @lib.Instruction::local_set(text_local(builder_ref)),
    @lib.Instruction::local_get(text_local(builder_ref)),
    @lib.Instruction::struct_get(builder_type, 2U),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(builder_ref)),
    @lib.Instruction::struct_get(builder_type, 0U),
    @lib.Instruction::local_set(text_local(chunks)),
    @lib.Instruction::local_get(text_local(builder_ref)),
    @lib.Instruction::struct_get(builder_type, 1U),
    @lib.Instruction::local_set(text_local(old_length)),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(0x7F),
    @lib.Instruction::i32_le_u(),
  ]
  let one : Array[@lib.Instruction] = [
    text_i32(1),
    @lib.Instruction::local_set(text_local(encoded_length)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::local_set(text_local(b0)),
  ]
  let two : Array[@lib.Instruction] = [
    text_i32(2),
    @lib.Instruction::local_set(text_local(encoded_length)),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(6),
    @lib.Instruction::i32_shr_u(),
    text_i32(0xC0),
    @lib.Instruction::i32_or(),
    @lib.Instruction::local_set(text_local(b0)),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(0x3F),
    @lib.Instruction::i32_and(),
    text_i32(0x80),
    @lib.Instruction::i32_or(),
    @lib.Instruction::local_set(text_local(b1)),
  ]
  let three : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(1)),
    text_i32(0xD800),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(0xDFFF),
    @lib.Instruction::i32_le_u(),
    @lib.Instruction::i32_and(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    text_i32(3),
    @lib.Instruction::local_set(text_local(encoded_length)),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(12),
    @lib.Instruction::i32_shr_u(),
    text_i32(0xE0),
    @lib.Instruction::i32_or(),
    @lib.Instruction::local_set(text_local(b0)),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(6),
    @lib.Instruction::i32_shr_u(),
    text_i32(0x3F),
    @lib.Instruction::i32_and(),
    text_i32(0x80),
    @lib.Instruction::i32_or(),
    @lib.Instruction::local_set(text_local(b1)),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(0x3F),
    @lib.Instruction::i32_and(),
    text_i32(0x80),
    @lib.Instruction::i32_or(),
    @lib.Instruction::local_set(text_local(b2)),
  ]
  let four : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(1)),
    text_i32(0x10FFFF),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    text_i32(4),
    @lib.Instruction::local_set(text_local(encoded_length)),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(18),
    @lib.Instruction::i32_shr_u(),
    text_i32(0xF0),
    @lib.Instruction::i32_or(),
    @lib.Instruction::local_set(text_local(b0)),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(12),
    @lib.Instruction::i32_shr_u(),
    text_i32(0x3F),
    @lib.Instruction::i32_and(),
    text_i32(0x80),
    @lib.Instruction::i32_or(),
    @lib.Instruction::local_set(text_local(b1)),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(6),
    @lib.Instruction::i32_shr_u(),
    text_i32(0x3F),
    @lib.Instruction::i32_and(),
    text_i32(0x80),
    @lib.Instruction::i32_or(),
    @lib.Instruction::local_set(text_local(b2)),
    @lib.Instruction::local_get(text_local(1)),
    text_i32(0x3F),
    @lib.Instruction::i32_and(),
    text_i32(0x80),
    @lib.Instruction::i32_or(),
    @lib.Instruction::local_set(text_local(b3)),
  ]
  three.push(@lib.Instruction::local_get(text_local(1)))
  three.push(text_i32(0xFFFF))
  three.push(@lib.Instruction::i32_le_u())
  three.push(@lib.Instruction::if_(@lib.BlockType::void_(), [], Some(four)))
  let more_than_one : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(1)),
    text_i32(0x7FF),
    @lib.Instruction::i32_le_u(),
    @lib.Instruction::if_(@lib.BlockType::void_(), two, Some(three)),
  ]
  body.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), one, Some(more_than_one)),
  )
  for
    instruction in [
      @lib.Instruction::local_get(text_local(old_length)),
      @lib.Instruction::local_get(text_local(encoded_length)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_tee(text_local(required_length)),
      @lib.Instruction::local_get(text_local(old_length)),
      @lib.Instruction::i32_lt_u(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::unreachable_()],
        None,
      ),
      @lib.Instruction::local_get(text_local(required_length)),
      text_i32(4),
      @lib.Instruction::i32_shr_u(),
      @lib.Instruction::local_get(text_local(required_length)),
      text_i32(15),
      @lib.Instruction::i32_and(),
      text_i32(0),
      @lib.Instruction::i32_ne(),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(text_local(required_chunks)),
      @lib.Instruction::local_get(text_local(chunks)),
      @lib.Instruction::array_len(),
      @lib.Instruction::local_set(text_local(capacity_chunks)),
    ] {
    body.push(instruction)
  }
  let grow : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    text_i32(1),
    @lib.Instruction::i32_shl(),
    @lib.Instruction::local_set(text_local(capacity_chunks)),
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    @lib.Instruction::local_get(text_local(required_chunks)),
    @lib.Instruction::i32_lt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(required_chunks)),
        @lib.Instruction::local_set(text_local(capacity_chunks)),
      ],
      None,
    ),
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    @lib.Instruction::array_new_default(array_type),
    @lib.Instruction::local_set(text_local(new_chunks)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(copy_index)),
  ]
  let copy_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::local_get(text_local(old_length)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::local_get(text_local(old_length)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    text_i32(0),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(new_chunks)),
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::local_get(text_local(chunks)),
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::array_set(array_type),
    @lib.Instruction::local_get(text_local(copy_index)),
    text_i32(1),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(copy_index)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]
  grow.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(copy_loop),
        ),
      ]),
    ),
  )
  grow.push(@lib.Instruction::local_get(text_local(builder_ref)))
  grow.push(@lib.Instruction::local_get(text_local(new_chunks)))
  grow.push(@lib.Instruction::struct_set(builder_type, 0U))
  grow.push(@lib.Instruction::local_get(text_local(new_chunks)))
  grow.push(@lib.Instruction::local_set(text_local(chunks)))
  body.push(@lib.Instruction::local_get(text_local(required_chunks)))
  body.push(@lib.Instruction::local_get(text_local(capacity_chunks)))
  body.push(@lib.Instruction::i32_gt_u())
  body.push(@lib.Instruction::if_(@lib.BlockType::void_(), grow, None))
  body.push(@lib.Instruction::local_get(text_local(old_length)))
  body.push(@lib.Instruction::local_set(text_local(write_index)))
  text_write_byte(body, array_type, chunks, write_index, b0)
  let thresholds = [1, 2, 3]
  let byte_locals = [b1, b2, b3]
  for byte_index in 0..<3 {
    body.push(@lib.Instruction::local_get(text_local(encoded_length)))
    body.push(text_i32(thresholds[byte_index]))
    body.push(@lib.Instruction::i32_gt_u())
    let write_more : Array[@lib.Instruction] = [
      @lib.Instruction::local_get(text_local(write_index)),
      text_i32(1),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(text_local(write_index)),
    ]
    text_write_byte(
      write_more,
      array_type,
      chunks,
      write_index,
      byte_locals[byte_index],
    )
    body.push(@lib.Instruction::if_(@lib.BlockType::void_(), write_more, None))
  }
  body.push(@lib.Instruction::local_get(text_local(builder_ref)))
  body.push(@lib.Instruction::local_get(text_local(required_length)))
  body.push(@lib.Instruction::struct_set(builder_type, 1U))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + 4),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn starshine_text_builder_finish_body(
  base : Int,
  builder_offset : Int,
  target_offset : Int,
) -> @lib.Func {
  let string_type = @lib.TypeIdx::new(
    (base + target_offset).reinterpret_as_uint(),
  )
  let builder_type = @lib.TypeIdx::new(
    (base + builder_offset).reinterpret_as_uint(),
  )
  let builder_ref = 1
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(builder_type)),
    @lib.Instruction::local_set(text_local(builder_ref)),
    @lib.Instruction::local_get(text_local(builder_ref)),
    @lib.Instruction::struct_get(builder_type, 2U),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(builder_ref)),
    text_i32(1),
    @lib.Instruction::struct_set(builder_type, 2U),
    @lib.Instruction::local_get(text_local(builder_ref)),
    @lib.Instruction::struct_get(builder_type, 0U),
    text_i32(0),
    @lib.Instruction::local_get(text_local(builder_ref)),
    @lib.Instruction::struct_get(builder_type, 1U),
    @lib.Instruction::struct_new(string_type),
  ]
  @lib.Func::new(
    @lib.Locals::from_types([text_runtime_ref(base + builder_offset)]),
    @lib.Expr::new(body),
  )
}

///|
/// Load sixteen logical bytes from a bounds-checked text value. This is the
/// representation bridge used by Dew source SIMD algorithms; it performs no
/// domain-specific classification or scanning.
fn starshine_text_load_u8x16_body(base : Int, type_offset : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let value_type = @lib.TypeIdx::new((base + type_offset).reinterpret_as_uint())
  let value_ref = 2
  let chunks = 3
  let physical_index = 4
  let vector = 5
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(value_type)),
    @lib.Instruction::local_set(text_local(value_ref)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 2U),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 2U),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::i32_sub(),
    text_i32(16),
    @lib.Instruction::i32_lt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 0U),
    @lib.Instruction::local_set(text_local(chunks)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 1U),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(physical_index)),
  ]
  text_load_logical_v128(body, array_type, chunks, physical_index, vector)
  body.push(@lib.Instruction::local_get(text_local(vector)))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + type_offset),
      text_runtime_ref(base),
      @lib.ValType::i32(),
      @lib.ValType::v128(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn emit_starshine_text_runtime_function(
  name : Bytes,
  base : Int,
  utf8_validator_function_index : Int,
  wasi_fd_write_function_index : Int,
  wasi_fd_read_function_index : Int,
) -> @lib.Func? {
  if name == b"dew_string_byte_length" {
    Some(starshine_text_length_body(base, true))
  } else if name == b"dew_bytes_byte_length" {
    Some(starshine_text_length_body(base, false))
  } else if name == b"dew_string_as_bytes" {
    Some(starshine_string_as_bytes_body(base))
  } else if name == b"dew_string_utf16_length" {
    Some(starshine_utf16_length_body(base))
  } else if name == b"dew_string_equals" {
    Some(starshine_text_equals_body(base, true))
  } else if name == b"dew_string_hash" {
    Some(starshine_text_hash_body(base, 1))
  } else if name == b"dew_string_byte_at" {
    Some(starshine_text_byte_at_body(base, true))
  } else if name == b"dew_string_view" {
    Some(starshine_string_view_body(base, 1))
  } else if name == b"dew_string_concat" {
    Some(starshine_text_concat_body(base, 1, 1, 1))
  } else if name == b"dew_string_concat_view" {
    Some(starshine_text_concat_body(base, 1, 3, 1))
  } else if name == b"dew_string_find" {
    Some(starshine_text_find_body(base, 1, 1))
  } else if name == b"dew_string_find_view" {
    Some(starshine_text_find_body(base, 1, 3))
  } else if name == b"dew_string_starts_with" {
    Some(starshine_text_affix_body(base, 1, 1, false))
  } else if name == b"dew_string_starts_with_view" {
    Some(starshine_text_affix_body(base, 1, 3, false))
  } else if name == b"dew_string_ends_with" {
    Some(starshine_text_affix_body(base, 1, 1, true))
  } else if name == b"dew_string_ends_with_view" {
    Some(starshine_text_affix_body(base, 1, 3, true))
  } else if name == b"dew_string_view_byte_length" {
    Some(starshine_text_length_type_body(base, 3))
  } else if name == b"dew_string_view_byte_at" {
    Some(starshine_text_byte_at_type_body(base, 3))
  } else if name == b"dew_string_view_to_string" {
    Some(starshine_text_rewrap_body(base, 3, 1))
  } else if name == b"dew_string_view_as_bytes" {
    Some(starshine_text_rewrap_body(base, 3, 2))
  } else if name == b"dew_string_view_utf16_length" {
    Some(starshine_utf16_length_type_body(base, 3))
  } else if name == b"dew_string_view_equals" {
    Some(starshine_text_equals_type_body(base, 3))
  } else if name == b"dew_string_view_hash" {
    Some(starshine_text_hash_body(base, 3))
  } else if name == b"dew_string_view_view" {
    Some(starshine_string_view_body(base, 3))
  } else if name == b"dew_string_view_find" {
    Some(starshine_text_find_body(base, 3, 3))
  } else if name == b"dew_string_view_find_string" {
    Some(starshine_text_find_body(base, 3, 1))
  } else if name == b"dew_string_view_starts_with" {
    Some(starshine_text_affix_body(base, 3, 3, false))
  } else if name == b"dew_string_view_starts_with_string" {
    Some(starshine_text_affix_body(base, 3, 1, false))
  } else if name == b"dew_string_view_ends_with" {
    Some(starshine_text_affix_body(base, 3, 3, true))
  } else if name == b"dew_string_view_ends_with_string" {
    Some(starshine_text_affix_body(base, 3, 1, true))
  } else if name == b"dew_string_builder_new" {
    Some(starshine_text_builder_new_body(base, 4, true))
  } else if name == b"dew_string_builder_with_capacity" {
    Some(starshine_text_builder_new_body(base, 4, false))
  } else if name == b"dew_string_builder_byte_length" {
    Some(starshine_text_builder_length_body(base, 4))
  } else if name == b"dew_string_builder_append" {
    Some(starshine_text_builder_append_body(base, 4, 1))
  } else if name == b"dew_string_builder_append_view" {
    Some(starshine_text_builder_append_body(base, 4, 3))
  } else if name == b"dew_string_builder_append_ascii" {
    Some(starshine_text_builder_append_byte_body(base, 4, true))
  } else if name == b"dew_string_builder_append_scalar" {
    Some(starshine_string_builder_append_scalar_body(base))
  } else if name == b"dew_string_builder_finish" {
    Some(starshine_text_builder_finish_body(base, 4, 1))
  } else if name == b"dew_bytes_builder_new" {
    Some(starshine_text_builder_new_body(base, 5, true))
  } else if name == b"dew_bytes_builder_with_capacity" {
    Some(starshine_text_builder_new_body(base, 5, false))
  } else if name == b"dew_bytes_builder_byte_length" {
    Some(starshine_text_builder_length_body(base, 5))
  } else if name == b"dew_bytes_builder_append" {
    Some(starshine_text_builder_append_body(base, 5, 2))
  } else if name == b"dew_bytes_builder_append_byte" {
    Some(starshine_text_builder_append_byte_body(base, 5, false))
  } else if name == b"dew_bytes_builder_finish" {
    Some(starshine_text_builder_finish_body(base, 5, 2))
  } else if name == b"dew_bytes_is_valid_utf8" {
    Some(starshine_utf8_validate_body(base))
  } else if name == b"dew_bytes_to_string" {
    if utf8_validator_function_index < 0 {
      None
    } else {
      Some(starshine_bytes_to_string_body(base, utf8_validator_function_index))
    }
  } else if name == b"dew_bytes_to_string_unchecked" {
    Some(starshine_text_rewrap_body(base, 2, 1))
  } else if name == b"dew_bytes_equals" {
    Some(starshine_text_equals_body(base, false))
  } else if name == b"dew_bytes_hash" {
    Some(starshine_text_hash_body(base, 2))
  } else if name == b"dew_bytes_byte_at" {
    Some(starshine_text_byte_at_body(base, false))
  } else if name == b"dew_bytes_view" {
    Some(starshine_bytes_view_body(base))
  } else if name == b"dew_bytes_concat" {
    Some(starshine_text_concat_body(base, 2, 2, 2))
  } else if name == b"dew_bytes_find_byte" {
    Some(starshine_bytes_find_byte_body(base))
  } else if name == b"dew_bytes_find" {
    Some(starshine_text_find_body(base, 2, 2))
  } else if name == b"dew_bytes_starts_with" {
    Some(starshine_text_affix_body(base, 2, 2, false))
  } else if name == b"dew_bytes_ends_with" {
    Some(starshine_text_affix_body(base, 2, 2, true))
  } else if name == b"dew_bytes_load_u8x16" {
    Some(starshine_text_load_u8x16_body(base, 2))
  } else if name == b"dew_string_load_u8x16" {
    Some(starshine_text_load_u8x16_body(base, 1))
  } else if name == b"dew_debug_i8" {
    Some(starshine_debug_i32_body(8, true, wasi_fd_write_function_index))
  } else if name == b"dew_debug_i16" {
    Some(starshine_debug_i32_body(16, true, wasi_fd_write_function_index))
  } else if name == b"dew_debug_i32" {
    Some(starshine_debug_i32_body(32, true, wasi_fd_write_function_index))
  } else if name == b"dew_debug_i64" {
    Some(starshine_debug_i64_body(true, wasi_fd_write_function_index))
  } else if name == b"dew_debug_u8" {
    Some(starshine_debug_i32_body(8, false, wasi_fd_write_function_index))
  } else if name == b"dew_debug_u16" {
    Some(starshine_debug_i32_body(16, false, wasi_fd_write_function_index))
  } else if name == b"dew_debug_u32" {
    Some(starshine_debug_i32_body(32, false, wasi_fd_write_function_index))
  } else if name == b"dew_debug_u64" {
    Some(starshine_debug_i64_body(false, wasi_fd_write_function_index))
  } else if name == b"dew_debug_f32" {
    Some(starshine_debug_float_body(false, wasi_fd_write_function_index))
  } else if name == b"dew_debug_f64" {
    Some(starshine_debug_float_body(true, wasi_fd_write_function_index))
  } else if name == b"dew_debug_string" {
    Some(starshine_debug_text_body(base, false, wasi_fd_write_function_index))
  } else if name == b"dew_debug_bytes" {
    Some(starshine_debug_text_body(base, true, wasi_fd_write_function_index))
  } else if name == b"dew_debug_v128" {
    Some(starshine_debug_v128_body(wasi_fd_write_function_index))
  } else if name == b"dew_wasi_fd_write" {
    Some(starshine_wasi_fd_write_body(base, wasi_fd_write_function_index))
  } else if name == b"dew_wasi_fd_read" {
    Some(starshine_wasi_fd_read_body(base, wasi_fd_read_function_index))
  } else if name == b"dew_bench_wasi_stage_write" {
    Some(starshine_wasi_stage_write_body(base))
  } else if name == b"dew_bench_wasi_stage_read" {
    Some(starshine_wasi_stage_read_body(base))
  } else {
    None
  }
}
