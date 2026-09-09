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
fn starshine_bytes_builder_append_body(base : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let source_type = @lib.TypeIdx::new((base + 2).reinterpret_as_uint())
  let builder_type = @lib.TypeIdx::new((base + 5).reinterpret_as_uint())
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
      text_runtime_ref(base + 5),
      text_runtime_ref(base + 2),
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
fn starshine_bytes_builder_append_byte_body(base : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let builder_type = @lib.TypeIdx::new((base + 5).reinterpret_as_uint())
  let builder_ref = 2
  let chunks = 3
  let old_length = 4
  let required_length = 5
  let capacity_chunks = 6
  let new_chunks = 7
  let copy_index = 8
  let body : Array[@lib.Instruction] = []
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
      text_runtime_ref(base + 5),
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
fn emit_starshine_text_runtime_function(
  name : Bytes,
  base : Int,
) -> @lib.Func? {
  if name == b"dew_string_view" {
    Some(starshine_string_view_body(base, 1))
  } else if name == b"dew_string_view_view" {
    Some(starshine_string_view_body(base, 3))
  } else if name == b"dew_string_builder_with_capacity" {
    Some(starshine_text_builder_new_body(base, 4))
  } else if name == b"dew_string_builder_append_scalar" {
    Some(starshine_string_builder_append_scalar_body(base))
  } else if name == b"dew_string_builder_finish" {
    Some(starshine_text_builder_finish_body(base, 4, 1))
  } else if name == b"dew_bytes_builder_with_capacity" {
    Some(starshine_text_builder_new_body(base, 5))
  } else if name == b"dew_bytes_builder_append" {
    Some(starshine_bytes_builder_append_body(base))
  } else if name == b"dew_bytes_builder_append_byte" {
    Some(starshine_bytes_builder_append_byte_body(base))
  } else if name == b"dew_bytes_builder_finish" {
    Some(starshine_text_builder_finish_body(base, 5, 2))
  } else if name == b"dew_bytes_byte_at" {
    Some(starshine_text_byte_at_type_body(base, 2))
  } else if name == b"dew_bytes_view" {
    Some(starshine_bytes_view_body(base))
  } else {
    None
  }
}
