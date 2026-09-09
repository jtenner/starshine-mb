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
fn starshine_text_builder_new_body(
  base : Int,
  builder_offset : Int,
) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let builder_type = @lib.TypeIdx::new(
    (base + builder_offset).reinterpret_as_uint(),
  )
  let body : Array[@lib.Instruction] = []
  body.push(@lib.Instruction::local_get(text_local(0)))
  body.push(text_i32(4))
  body.push(@lib.Instruction::i32_shr_u())
  body.push(@lib.Instruction::local_get(text_local(0)))
  body.push(text_i32(15))
  body.push(@lib.Instruction::i32_and())
  body.push(text_i32(0))
  body.push(@lib.Instruction::i32_ne())
  body.push(@lib.Instruction::i32_add())
  body.push(@lib.Instruction::array_new_default(array_type))
  body.push(text_i32(0))
  body.push(text_i32(0))
  body.push(@lib.Instruction::struct_new(builder_type))
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
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
fn emit_starshine_text_runtime_function(
  name : Bytes,
  base : Int,
) -> @lib.Func? {
  if name == b"dew_string_builder_with_capacity" {
    Some(starshine_text_builder_new_body(base, 4))
  } else if name == b"dew_string_builder_append_scalar" {
    Some(starshine_string_builder_append_scalar_body(base))
  } else if name == b"dew_string_builder_finish" {
    Some(starshine_text_builder_finish_body(base, 4, 1))
  } else {
    None
  }
}
