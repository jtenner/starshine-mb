///| WASI Preview 1 scratch layout. One fixed page is sufficient for the

///|
/// iovec, host result, and the bounded data window.
fn wasi_iovec_address() -> Int {
  wasi_preview1_scratch_layout().iovec_address
}

///|
fn wasi_result_address() -> Int {
  wasi_preview1_scratch_layout().result_address
}

///|
fn wasi_scratch_address() -> Int {
  wasi_preview1_scratch_layout().scratch_address
}

///|
fn wasi_scratch_capacity() -> Int {
  wasi_preview1_scratch_layout().scratch_capacity
}

///|
fn starshine_debug_write_scratch(
  output : Array[@lib.Instruction],
  start : Int,
  length : Int,
  written : Int,
  host_written : Int,
  fd_write_function_index : Int,
) -> Unit {
  output.push(text_i32(0))
  output.push(@lib.Instruction::local_set(text_local(written)))
  let write_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(written)),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    text_i32(wasi_iovec_address()),
    @lib.Instruction::local_get(text_local(start)),
    @lib.Instruction::local_get(text_local(written)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_store(starshine_memory_argument(2U)),
    text_i32(wasi_iovec_address() + 4),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::local_get(text_local(written)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::i32_store(starshine_memory_argument(2U)),
    text_i32(1),
    text_i32(wasi_iovec_address()),
    text_i32(1),
    text_i32(wasi_result_address()),
    @lib.Instruction::call(
      @lib.FuncIdx::new(fd_write_function_index.reinterpret_as_uint()),
    ),
    text_i32(0),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    text_i32(wasi_result_address()),
    @lib.Instruction::i32_load(starshine_memory_argument(2U)),
    @lib.Instruction::local_tee(text_local(host_written)),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::local_get(text_local(host_written)),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::local_get(text_local(written)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::i32_or(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(written)),
    @lib.Instruction::local_get(text_local(host_written)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(written)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]
  output.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(write_loop),
        ),
      ]),
    ),
  )
  output.push(@lib.Instruction::local_get(text_local(length)))
}

///|
fn starshine_debug_append_constant(
  output : Array[@lib.Instruction],
  output_index : Int,
  total : Int,
  value : Int,
) -> Unit {
  output.push(text_i32(wasi_scratch_address()))
  output.push(@lib.Instruction::local_get(text_local(output_index)))
  output.push(@lib.Instruction::i32_add())
  output.push(text_i32(value))
  output.push(@lib.Instruction::i32_store8(starshine_memory_argument(0U)))
  output.push(@lib.Instruction::local_get(text_local(output_index)))
  output.push(text_i32(1))
  output.push(@lib.Instruction::i32_add())
  output.push(@lib.Instruction::local_set(text_local(output_index)))
  output.push(@lib.Instruction::local_get(text_local(total)))
  output.push(text_i32(1))
  output.push(@lib.Instruction::i32_add())
  output.push(@lib.Instruction::local_set(text_local(total)))
}

///|
fn starshine_debug_append_local(
  output : Array[@lib.Instruction],
  output_index : Int,
  total : Int,
  value : Int,
) -> Unit {
  output.push(text_i32(wasi_scratch_address()))
  output.push(@lib.Instruction::local_get(text_local(output_index)))
  output.push(@lib.Instruction::i32_add())
  output.push(@lib.Instruction::local_get(text_local(value)))
  output.push(@lib.Instruction::i32_store8(starshine_memory_argument(0U)))
  output.push(@lib.Instruction::local_get(text_local(output_index)))
  output.push(text_i32(1))
  output.push(@lib.Instruction::i32_add())
  output.push(@lib.Instruction::local_set(text_local(output_index)))
  output.push(@lib.Instruction::local_get(text_local(total)))
  output.push(text_i32(1))
  output.push(@lib.Instruction::i32_add())
  output.push(@lib.Instruction::local_set(text_local(total)))
}

///|
fn starshine_debug_append_hex_nibble(
  output : Array[@lib.Instruction],
  output_index : Int,
  total : Int,
  nibble : Int,
) -> Unit {
  output.push(text_i32(wasi_scratch_address()))
  output.push(@lib.Instruction::local_get(text_local(output_index)))
  output.push(@lib.Instruction::i32_add())
  output.push(@lib.Instruction::local_get(text_local(nibble)))
  output.push(text_i32(10))
  output.push(@lib.Instruction::i32_lt_u())
  output.push(
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [
        @lib.Instruction::local_get(text_local(nibble)),
        text_i32(48),
        @lib.Instruction::i32_add(),
      ],
      Some([
        @lib.Instruction::local_get(text_local(nibble)),
        text_i32(87),
        @lib.Instruction::i32_add(),
      ]),
    ),
  )
  output.push(@lib.Instruction::i32_store8(starshine_memory_argument(0U)))
  output.push(@lib.Instruction::local_get(text_local(output_index)))
  output.push(text_i32(1))
  output.push(@lib.Instruction::i32_add())
  output.push(@lib.Instruction::local_set(text_local(output_index)))
  output.push(@lib.Instruction::local_get(text_local(total)))
  output.push(text_i32(1))
  output.push(@lib.Instruction::i32_add())
  output.push(@lib.Instruction::local_set(text_local(total)))
}

///|
fn starshine_debug_append_escape(
  output : Array[@lib.Instruction],
  output_index : Int,
  total : Int,
  escaped : Int,
) -> Unit {
  starshine_debug_append_constant(output, output_index, total, 92)
  starshine_debug_append_constant(output, output_index, total, escaped)
}

///|
fn starshine_debug_append_hex_escape(
  output : Array[@lib.Instruction],
  output_index : Int,
  total : Int,
  byte : Int,
  nibble : Int,
) -> Unit {
  starshine_debug_append_constant(output, output_index, total, 92)
  starshine_debug_append_constant(output, output_index, total, 120)
  output.push(@lib.Instruction::local_get(text_local(byte)))
  output.push(text_i32(4))
  output.push(@lib.Instruction::i32_shr_u())
  output.push(@lib.Instruction::local_set(text_local(nibble)))
  starshine_debug_append_hex_nibble(output, output_index, total, nibble)
  output.push(@lib.Instruction::local_get(text_local(byte)))
  output.push(text_i32(15))
  output.push(@lib.Instruction::i32_and())
  output.push(@lib.Instruction::local_set(text_local(nibble)))
  starshine_debug_append_hex_nibble(output, output_index, total, nibble)
}

///|
fn starshine_debug_flush_scratch(
  output : Array[@lib.Instruction],
  scratch_start : Int,
  output_index : Int,
  written : Int,
  host_written : Int,
  fd_write_function_index : Int,
) -> Unit {
  starshine_debug_write_scratch(
    output, scratch_start, output_index, written, host_written, fd_write_function_index,
  )
  output.push(@lib.Instruction::drop())
  output.push(text_i32(0))
  output.push(@lib.Instruction::local_set(text_local(output_index)))
}

///|
fn starshine_debug_escaped_byte(
  byte : Int,
  nibble : Int,
  output_index : Int,
  total : Int,
  bytes_ : Bool,
) -> Array[@lib.Instruction] {
  let raw : Array[@lib.Instruction] = []
  starshine_debug_append_local(raw, output_index, total, byte)
  let hex : Array[@lib.Instruction] = []
  starshine_debug_append_hex_escape(hex, output_index, total, byte, nibble)
  let fallback : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(byte)),
    text_i32(32),
    @lib.Instruction::i32_lt_u(),
  ]
  if bytes_ {
    fallback.push(@lib.Instruction::local_get(text_local(byte)))
    fallback.push(text_i32(126))
    fallback.push(@lib.Instruction::i32_gt_u())
    fallback.push(@lib.Instruction::i32_or())
  } else {
    fallback.push(@lib.Instruction::local_get(text_local(byte)))
    fallback.push(text_i32(127))
    fallback.push(@lib.Instruction::i32_eq())
    fallback.push(@lib.Instruction::i32_or())
  }
  fallback.push(@lib.Instruction::if_(@lib.BlockType::void_(), hex, Some(raw)))
  let tab : Array[@lib.Instruction] = []
  starshine_debug_append_escape(tab, output_index, total, 116)
  let tab_branch : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(byte)),
    text_i32(9),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(@lib.BlockType::void_(), tab, Some(fallback)),
  ]
  let carriage : Array[@lib.Instruction] = []
  starshine_debug_append_escape(carriage, output_index, total, 114)
  let carriage_branch : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(byte)),
    text_i32(13),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(@lib.BlockType::void_(), carriage, Some(tab_branch)),
  ]
  let newline : Array[@lib.Instruction] = []
  starshine_debug_append_escape(newline, output_index, total, 110)
  let newline_branch : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(byte)),
    text_i32(10),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      newline,
      Some(carriage_branch),
    ),
  ]
  let slash : Array[@lib.Instruction] = []
  starshine_debug_append_escape(slash, output_index, total, 92)
  let slash_branch : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(byte)),
    text_i32(92),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(@lib.BlockType::void_(), slash, Some(newline_branch)),
  ]
  let quote : Array[@lib.Instruction] = []
  starshine_debug_append_escape(quote, output_index, total, 34)
  [
    @lib.Instruction::local_get(text_local(byte)),
    text_i32(34),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(@lib.BlockType::void_(), quote, Some(slash_branch)),
  ]
}

///|
fn starshine_debug_text_body(
  base : Int,
  bytes_ : Bool,
  fd_write_function_index : Int,
) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let type_offset = if bytes_ { 2 } else { 1 }
  let value_type = @lib.TypeIdx::new((base + type_offset).reinterpret_as_uint())
  let value_ref = 1
  let chunks = 2
  let source_index = 3
  let source_limit = 4
  let output_index = 5
  let scratch_start = 6
  let byte = 7
  let nibble = 8
  let written = 9
  let host_written = 10
  let total = 11
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(value_type)),
    @lib.Instruction::local_tee(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 0U),
    @lib.Instruction::local_set(text_local(chunks)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 1U),
    @lib.Instruction::local_tee(text_local(source_index)),
    @lib.Instruction::local_get(text_local(value_ref)),
    @lib.Instruction::struct_get(value_type, 2U),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(source_limit)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(output_index)),
    text_i32(wasi_scratch_address()),
    @lib.Instruction::local_set(text_local(scratch_start)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(total)),
  ]
  if bytes_ {
    starshine_debug_append_constant(body, output_index, total, 98)
  }
  starshine_debug_append_constant(body, output_index, total, 34)
  let loop_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(source_index)),
    @lib.Instruction::local_get(text_local(source_limit)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(output_index)),
    text_i32(wasi_scratch_capacity() - 4),
    @lib.Instruction::i32_gt_u(),
  ]
  let flush : Array[@lib.Instruction] = []
  starshine_debug_flush_scratch(
    flush, scratch_start, output_index, written, host_written, fd_write_function_index,
  )
  loop_body.push(@lib.Instruction::if_(@lib.BlockType::void_(), flush, None))
  for instruction in text_byte_at(array_type, chunks, source_index, 0) {
    loop_body.push(instruction)
  }
  loop_body.push(@lib.Instruction::local_set(text_local(byte)))
  for
    instruction in starshine_debug_escaped_byte(
      byte, nibble, output_index, total, bytes_,
    ) {
    loop_body.push(instruction)
  }
  loop_body.push(@lib.Instruction::local_get(text_local(source_index)))
  loop_body.push(text_i32(1))
  loop_body.push(@lib.Instruction::i32_add())
  loop_body.push(@lib.Instruction::local_set(text_local(source_index)))
  loop_body.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(loop_body),
        ),
      ]),
    ),
  )
  body.push(@lib.Instruction::local_get(text_local(output_index)))
  body.push(text_i32(wasi_scratch_capacity()))
  body.push(@lib.Instruction::i32_ge_u())
  let suffix_flush : Array[@lib.Instruction] = []
  starshine_debug_flush_scratch(
    suffix_flush, scratch_start, output_index, written, host_written, fd_write_function_index,
  )
  body.push(@lib.Instruction::if_(@lib.BlockType::void_(), suffix_flush, None))
  starshine_debug_append_constant(body, output_index, total, 34)
  starshine_debug_flush_scratch(
    body, scratch_start, output_index, written, host_written, fd_write_function_index,
  )
  body.push(@lib.Instruction::local_get(text_local(total)))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base + type_offset),
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
    ]),
    @lib.Expr::new(body),
  )
}
