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
fn starshine_debug_i32_body(
  width : Int,
  signed : Bool,
  fd_write_function_index : Int,
) -> @lib.Func {
  let cursor = 1
  let magnitude = 2
  let negative = 3
  let length = 4
  let written = 5
  let host_written = 6
  let end = wasi_scratch_address() + 32
  let body : Array[@lib.Instruction] = []
  if signed {
    body.push(@lib.Instruction::local_get(text_local(0)))
    if width == 8 {
      body.push(@lib.Instruction::i32_extend8s())
    } else if width == 16 {
      body.push(@lib.Instruction::i32_extend16s())
    }
    body.push(@lib.Instruction::local_set(text_local(0)))
  } else if width < 32 {
    body.push(@lib.Instruction::local_get(text_local(0)))
    body.push(text_i32(if width == 8 { 255 } else { 65535 }))
    body.push(@lib.Instruction::i32_and())
    body.push(@lib.Instruction::local_set(text_local(0)))
  }
  body.push(text_i32(end))
  body.push(@lib.Instruction::local_set(text_local(cursor)))
  if signed {
    body.push(@lib.Instruction::local_get(text_local(0)))
    body.push(text_i32(0))
    body.push(@lib.Instruction::i32_lt_s())
    body.push(@lib.Instruction::local_tee(text_local(negative)))
    body.push(
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [
          text_i32(0),
          @lib.Instruction::local_get(text_local(0)),
          @lib.Instruction::i32_sub(),
        ],
        Some([@lib.Instruction::local_get(text_local(0))]),
      ),
    )
  } else {
    body.push(@lib.Instruction::local_get(text_local(0)))
  }
  body.push(@lib.Instruction::local_set(text_local(magnitude)))
  let digits : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(cursor)),
    text_i32(1),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_tee(text_local(cursor)),
    @lib.Instruction::local_get(text_local(magnitude)),
    text_i32(10),
    @lib.Instruction::i32_rem_u(),
    text_i32(48),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_store8(starshine_memory_argument(0U)),
    @lib.Instruction::local_get(text_local(magnitude)),
    text_i32(10),
    @lib.Instruction::i32_div_u(),
    @lib.Instruction::local_tee(text_local(magnitude)),
    @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
  ]
  body.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(digits)),
  )
  if signed {
    body.push(@lib.Instruction::local_get(text_local(negative)))
    body.push(
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(text_local(cursor)),
          text_i32(1),
          @lib.Instruction::i32_sub(),
          @lib.Instruction::local_tee(text_local(cursor)),
          text_i32(45),
          @lib.Instruction::i32_store8(starshine_memory_argument(0U)),
        ],
        None,
      ),
    )
  }
  body.push(text_i32(end))
  body.push(@lib.Instruction::local_get(text_local(cursor)))
  body.push(@lib.Instruction::i32_sub())
  body.push(@lib.Instruction::local_set(text_local(length)))
  starshine_debug_write_scratch(
    body, cursor, length, written, host_written, fd_write_function_index,
  )
  @lib.Func::new(
    @lib.Locals::from_types([
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
fn starshine_debug_i64_body(
  signed : Bool,
  fd_write_function_index : Int,
) -> @lib.Func {
  let cursor = 1
  let magnitude = 2
  let negative = 3
  let length = 4
  let written = 5
  let host_written = 6
  let end = wasi_scratch_address() + 32
  let body : Array[@lib.Instruction] = [
    text_i32(end),
    @lib.Instruction::local_set(text_local(cursor)),
  ]
  if signed {
    body.push(@lib.Instruction::local_get(text_local(0)))
    body.push(@lib.Instruction::i64_const(@lib.I64::new(0L)))
    body.push(@lib.Instruction::i64_lt_s())
    body.push(@lib.Instruction::local_tee(text_local(negative)))
    body.push(
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::i64()),
        [
          @lib.Instruction::i64_const(@lib.I64::new(0L)),
          @lib.Instruction::local_get(text_local(0)),
          @lib.Instruction::i64_sub(),
        ],
        Some([@lib.Instruction::local_get(text_local(0))]),
      ),
    )
  } else {
    body.push(@lib.Instruction::local_get(text_local(0)))
  }
  body.push(@lib.Instruction::local_set(text_local(magnitude)))
  let digits : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(cursor)),
    text_i32(1),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_tee(text_local(cursor)),
    @lib.Instruction::local_get(text_local(magnitude)),
    @lib.Instruction::i64_const(@lib.I64::new(10L)),
    @lib.Instruction::i64_rem_u(),
    @lib.Instruction::i32_wrap_i64(),
    text_i32(48),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_store8(starshine_memory_argument(0U)),
    @lib.Instruction::local_get(text_local(magnitude)),
    @lib.Instruction::i64_const(@lib.I64::new(10L)),
    @lib.Instruction::i64_div_u(),
    @lib.Instruction::local_tee(text_local(magnitude)),
    @lib.Instruction::i64_const(@lib.I64::new(0L)),
    @lib.Instruction::i64_ne(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
  ]
  body.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(digits)),
  )
  if signed {
    body.push(@lib.Instruction::local_get(text_local(negative)))
    body.push(
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(text_local(cursor)),
          text_i32(1),
          @lib.Instruction::i32_sub(),
          @lib.Instruction::local_tee(text_local(cursor)),
          text_i32(45),
          @lib.Instruction::i32_store8(starshine_memory_argument(0U)),
        ],
        None,
      ),
    )
  }
  body.push(text_i32(end))
  body.push(@lib.Instruction::local_get(text_local(cursor)))
  body.push(@lib.Instruction::i32_sub())
  body.push(@lib.Instruction::local_set(text_local(length)))
  starshine_debug_write_scratch(
    body, cursor, length, written, host_written, fd_write_function_index,
  )
  @lib.Func::new(
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn starshine_debug_float_body(
  wide : Bool,
  fd_write_function_index : Int,
) -> @lib.Func {
  let bits = 1
  let cursor = 2
  let remaining = 3
  let nibble = 4
  let length = 5
  let written = 6
  let host_written = 7
  let output_start = 8
  let start = wasi_scratch_address()
  let digits = if wide { 16 } else { 8 }
  let prefix = if wide { b"f64(0x" } else { b"f32(0x" }
  let body : Array[@lib.Instruction] = []
  for index, byte in prefix {
    body.push(text_i32(start + index))
    body.push(text_i32(byte.to_int()))
    body.push(@lib.Instruction::i32_store8(starshine_memory_argument(0U)))
  }
  body.push(text_i32(start))
  body.push(@lib.Instruction::local_set(text_local(output_start)))
  body.push(@lib.Instruction::local_get(text_local(0)))
  if wide {
    body.push(@lib.Instruction::i64_reinterpret_f64())
  } else {
    body.push(@lib.Instruction::i32_reinterpret_f32())
  }
  body.push(@lib.Instruction::local_set(text_local(bits)))
  body.push(text_i32(start + prefix.length() + digits))
  body.push(@lib.Instruction::local_set(text_local(cursor)))
  body.push(text_i32(digits))
  body.push(@lib.Instruction::local_set(text_local(remaining)))
  let hex_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(cursor)),
    text_i32(1),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_tee(text_local(cursor)),
    @lib.Instruction::local_get(text_local(bits)),
  ]
  if wide {
    hex_loop.push(@lib.Instruction::i64_const(@lib.I64::new(15L)))
    hex_loop.push(@lib.Instruction::i64_and())
    hex_loop.push(@lib.Instruction::i32_wrap_i64())
  } else {
    hex_loop.push(text_i32(15))
    hex_loop.push(@lib.Instruction::i32_and())
  }
  hex_loop.push(@lib.Instruction::local_tee(text_local(nibble)))
  hex_loop.push(text_i32(10))
  hex_loop.push(@lib.Instruction::i32_lt_u())
  hex_loop.push(
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
  hex_loop.push(@lib.Instruction::i32_store8(starshine_memory_argument(0U)))
  hex_loop.push(@lib.Instruction::local_get(text_local(bits)))
  if wide {
    hex_loop.push(@lib.Instruction::i64_const(@lib.I64::new(4L)))
    hex_loop.push(@lib.Instruction::i64_shr_u())
  } else {
    hex_loop.push(text_i32(4))
    hex_loop.push(@lib.Instruction::i32_shr_u())
  }
  hex_loop.push(@lib.Instruction::local_set(text_local(bits)))
  hex_loop.push(@lib.Instruction::local_get(text_local(remaining)))
  hex_loop.push(text_i32(1))
  hex_loop.push(@lib.Instruction::i32_sub())
  hex_loop.push(@lib.Instruction::local_tee(text_local(remaining)))
  hex_loop.push(@lib.Instruction::br_if(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(hex_loop)),
  )
  let total_length = prefix.length() + digits + 1
  body.push(text_i32(start + total_length - 1))
  body.push(text_i32(41))
  body.push(@lib.Instruction::i32_store8(starshine_memory_argument(0U)))
  body.push(text_i32(total_length))
  body.push(@lib.Instruction::local_set(text_local(length)))
  starshine_debug_write_scratch(
    body, output_start, length, written, host_written, fd_write_function_index,
  )
  let locals = if wide {
    [
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]
  } else {
    [
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]
  }
  @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(body))
}

///|
fn starshine_debug_write_i64_hex(
  output : Array[@lib.Instruction],
  bits : Int,
  cursor : Int,
  remaining : Int,
  nibble : Int,
) -> Unit {
  output.push(text_i32(16))
  output.push(@lib.Instruction::local_set(text_local(remaining)))
  let hex_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(cursor)),
    text_i32(1),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_tee(text_local(cursor)),
    @lib.Instruction::local_get(text_local(bits)),
    @lib.Instruction::i64_const(@lib.I64::new(15L)),
    @lib.Instruction::i64_and(),
    @lib.Instruction::i32_wrap_i64(),
    @lib.Instruction::local_tee(text_local(nibble)),
    text_i32(10),
    @lib.Instruction::i32_lt_u(),
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
    @lib.Instruction::i32_store8(starshine_memory_argument(0U)),
    @lib.Instruction::local_get(text_local(bits)),
    @lib.Instruction::i64_const(@lib.I64::new(4L)),
    @lib.Instruction::i64_shr_u(),
    @lib.Instruction::local_set(text_local(bits)),
    @lib.Instruction::local_get(text_local(remaining)),
    text_i32(1),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_tee(text_local(remaining)),
    @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
  ]
  output.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(hex_loop)),
  )
}

///|
fn starshine_debug_v128_body(fd_write_function_index : Int) -> @lib.Func {
  let low = 1
  let high = 2
  let cursor = 3
  let remaining = 4
  let nibble = 5
  let length = 6
  let written = 7
  let host_written = 8
  let scratch_start = 9
  let start = wasi_scratch_address()
  let prefix = b"v128(0x"
  let body : Array[@lib.Instruction] = []
  for index, byte in prefix {
    body.push(text_i32(start + index))
    body.push(text_i32(byte.to_int()))
    body.push(@lib.Instruction::i32_store8(starshine_memory_argument(0U)))
  }
  body.push(text_i32(start))
  body.push(@lib.Instruction::local_set(text_local(scratch_start)))
  body.push(@lib.Instruction::local_get(text_local(0)))
  body.push(@lib.Instruction::i64x2_extract_lane(@lib.LaneIdx::new(b'\x00')))
  body.push(@lib.Instruction::local_set(text_local(low)))
  body.push(@lib.Instruction::local_get(text_local(0)))
  body.push(@lib.Instruction::i64x2_extract_lane(@lib.LaneIdx::new(b'\x01')))
  body.push(@lib.Instruction::local_set(text_local(high)))
  body.push(text_i32(start + prefix.length() + 32))
  body.push(@lib.Instruction::local_set(text_local(cursor)))
  starshine_debug_write_i64_hex(body, low, cursor, remaining, nibble)
  starshine_debug_write_i64_hex(body, high, cursor, remaining, nibble)
  let total_length = prefix.length() + 32 + 1
  body.push(text_i32(start + total_length - 1))
  body.push(text_i32(41))
  body.push(@lib.Instruction::i32_store8(starshine_memory_argument(0U)))
  body.push(text_i32(total_length))
  body.push(@lib.Instruction::local_set(text_local(length)))
  starshine_debug_write_scratch(
    body, scratch_start, length, written, host_written, fd_write_function_index,
  )
  @lib.Func::new(
    @lib.Locals::from_types([
      @lib.ValType::i64(),
      @lib.ValType::i64(),
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

///|
fn wasi_store_i32(
  output : Array[@lib.Instruction],
  address : Int,
  value : Int,
) -> Unit {
  output.push(text_i32(address))
  output.push(text_i32(value))
  output.push(@lib.Instruction::i32_store(starshine_memory_argument(2U)))
}

///|
fn wasi_store_i32_local(
  output : Array[@lib.Instruction],
  address : Int,
  local_index : Int,
) -> Unit {
  output.push(text_i32(address))
  output.push(@lib.Instruction::local_get(text_local(local_index)))
  output.push(@lib.Instruction::i32_store(starshine_memory_argument(2U)))
}

///|
/// Copy a bounded logical Bytes range into the reusable linear-memory window.
fn wasi_copy_bytes_to_scratch(
  output : Array[@lib.Instruction],
  array_type : @lib.TypeIdx,
  chunks : Int,
  start : Int,
  range_base : Int,
  range_length : Int,
  copy_index : Int,
  source_index : Int,
  byte : Int,
  vector : Int,
) -> Unit {
  output.push(text_i32(0))
  output.push(@lib.Instruction::local_set(text_local(copy_index)))
  let copy_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::local_get(text_local(range_length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(start)),
    @lib.Instruction::local_get(text_local(range_base)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(source_index)),
    @lib.Instruction::local_get(text_local(source_index)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::local_get(text_local(copy_index)),
    text_i32(64),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(text_local(range_length)),
    @lib.Instruction::i32_le_u(),
    @lib.Instruction::i32_and(),
  ]
  let copy_64 : Array[@lib.Instruction] = []
  for offset in [0, 16, 32, 48] {
    copy_64.push(text_i32(wasi_scratch_address()))
    copy_64.push(@lib.Instruction::local_get(text_local(copy_index)))
    if offset != 0 {
      copy_64.push(text_i32(offset))
      copy_64.push(@lib.Instruction::i32_add())
    }
    copy_64.push(@lib.Instruction::i32_add())
    copy_64.push(@lib.Instruction::local_get(text_local(chunks)))
    copy_64.push(@lib.Instruction::local_get(text_local(source_index)))
    if offset != 0 {
      copy_64.push(text_i32(offset))
      copy_64.push(@lib.Instruction::i32_add())
    }
    copy_64.push(text_i32(4))
    copy_64.push(@lib.Instruction::i32_shr_u())
    copy_64.push(@lib.Instruction::array_get(array_type))
    copy_64.push(@lib.Instruction::v128_store(starshine_memory_argument(4U)))
  }
  copy_64.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_64.push(text_i32(64))
  copy_64.push(@lib.Instruction::i32_add())
  copy_64.push(@lib.Instruction::local_set(text_local(copy_index)))
  copy_64.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  copy_loop.push(@lib.Instruction::if_(@lib.BlockType::void_(), copy_64, None))
  copy_loop.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_loop.push(text_i32(16))
  copy_loop.push(@lib.Instruction::i32_add())
  copy_loop.push(@lib.Instruction::local_get(text_local(range_length)))
  copy_loop.push(@lib.Instruction::i32_le_u())
  let copy_full : Array[@lib.Instruction] = []
  text_load_logical_v128(copy_full, array_type, chunks, source_index, vector)
  copy_full.push(text_i32(wasi_scratch_address()))
  copy_full.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_full.push(@lib.Instruction::i32_add())
  copy_full.push(@lib.Instruction::local_get(text_local(vector)))
  copy_full.push(@lib.Instruction::v128_store(starshine_memory_argument(4U)))
  copy_full.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_full.push(text_i32(16))
  copy_full.push(@lib.Instruction::i32_add())
  copy_full.push(@lib.Instruction::local_set(text_local(copy_index)))
  copy_full.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  copy_loop.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), copy_full, None),
  )
  for instruction in text_byte_at(array_type, chunks, source_index, 0) {
    copy_loop.push(instruction)
  }
  copy_loop.push(@lib.Instruction::local_set(text_local(byte)))
  copy_loop.push(text_i32(wasi_scratch_address()))
  copy_loop.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_loop.push(@lib.Instruction::i32_add())
  copy_loop.push(@lib.Instruction::local_get(text_local(byte)))
  copy_loop.push(@lib.Instruction::i32_store8(starshine_memory_argument(0U)))
  copy_loop.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_loop.push(text_i32(1))
  copy_loop.push(@lib.Instruction::i32_add())
  copy_loop.push(@lib.Instruction::local_set(text_local(copy_index)))
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

///| Benchmark-only GC-to-linear phase used to separate copy cost from the

///| Preview 1 host callback. It is reachable only from an explicit builtin

///|
/// declaration in the benchmark source.
fn starshine_wasi_stage_write_body(base : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let bytes_type = @lib.TypeIdx::new((base + 2).reinterpret_as_uint())
  let bytes_ref = 1
  let chunks = 2
  let start = 3
  let length = 4
  let range_base = 5
  let copy_index = 6
  let source_index = 7
  let byte = 8
  let vector = 9
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
    @lib.Instruction::local_tee(text_local(length)),
    text_i32(wasi_scratch_capacity()),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    text_i32(0),
    @lib.Instruction::local_set(text_local(range_base)),
  ]
  wasi_copy_bytes_to_scratch(
    body, array_type, chunks, start, range_base, length, copy_index, source_index,
    byte, vector,
  )
  body.push(@lib.Instruction::local_get(text_local(length)))
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
      @lib.ValType::v128(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
fn starshine_test_assert_body(
  string_as_bytes_function_index : Int,
  wasi_write_function_index : Int,
) -> @lib.Func {
  let failure : Array[@lib.Instruction] = [
    text_i32(1),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::call(
      @lib.FuncIdx::new(string_as_bytes_function_index.reinterpret_as_uint()),
    ),
    @lib.Instruction::call(
      @lib.FuncIdx::new(wasi_write_function_index.reinterpret_as_uint()),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::unreachable_(),
  ]
  @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(text_local(0)),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::if_(@lib.BlockType::void_(), failure, None),
    ]),
  )
}

///|
fn starshine_wasi_fd_write_body(
  base : Int,
  fd_write_function_index : Int,
) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let bytes_type = @lib.TypeIdx::new((base + 2).reinterpret_as_uint())
  let bytes_ref = 2
  let chunks = 3
  let start = 4
  let length = 5
  let written_total = 6
  let chunk_length = 7
  let copy_index = 8
  let source_index = 9
  let byte = 10
  let vector = 11
  let host_written = 12
  let chunk_written = 13
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(1)),
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
    @lib.Instruction::local_set(text_local(written_total)),
  ]
  let write_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(written_total)),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(length)),
    @lib.Instruction::local_get(text_local(written_total)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_tee(text_local(chunk_length)),
    text_i32(wasi_scratch_capacity()),
    @lib.Instruction::i32_gt_u(),
  ]
  write_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        text_i32(wasi_scratch_capacity()),
        @lib.Instruction::local_set(text_local(chunk_length)),
      ],
      None,
    ),
  )
  wasi_copy_bytes_to_scratch(
    write_loop, array_type, chunks, start, written_total, chunk_length, copy_index,
    source_index, byte, vector,
  )
  write_loop.push(text_i32(0))
  write_loop.push(@lib.Instruction::local_set(text_local(chunk_written)))
  let partial_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(chunk_written)),
    @lib.Instruction::local_get(text_local(chunk_length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    text_i32(wasi_iovec_address()),
    text_i32(wasi_scratch_address()),
    @lib.Instruction::local_get(text_local(chunk_written)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_store(starshine_memory_argument(2U)),
    text_i32(wasi_iovec_address() + 4),
    @lib.Instruction::local_get(text_local(chunk_length)),
    @lib.Instruction::local_get(text_local(chunk_written)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::i32_store(starshine_memory_argument(2U)),
    @lib.Instruction::local_get(text_local(0)),
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
    @lib.Instruction::local_get(text_local(chunk_length)),
    @lib.Instruction::local_get(text_local(chunk_written)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::i32_or(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(chunk_written)),
    @lib.Instruction::local_get(text_local(host_written)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(chunk_written)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]
  write_loop.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(partial_loop),
        ),
      ]),
    ),
  )
  write_loop.push(@lib.Instruction::local_get(text_local(written_total)))
  write_loop.push(@lib.Instruction::local_get(text_local(chunk_length)))
  write_loop.push(@lib.Instruction::i32_add())
  write_loop.push(@lib.Instruction::local_set(text_local(written_total)))
  write_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
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
  body.push(@lib.Instruction::local_get(text_local(written_total)))
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
      @lib.ValType::i32(),
      @lib.ValType::v128(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(body),
  )
}

///|
/// Copy one host-filled scratch range into a start-zero mutable GC backing.
fn wasi_copy_scratch_to_bytes(
  output : Array[@lib.Instruction],
  array_type : @lib.TypeIdx,
  chunks : Int,
  destination_base : Int,
  range_length : Int,
  copy_index : Int,
  destination_index : Int,
  byte : Int,
  vector : Int,
  mask : Int,
) -> Unit {
  output.push(text_i32(0))
  output.push(@lib.Instruction::local_set(text_local(copy_index)))
  let copy_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::local_get(text_local(range_length)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(destination_base)),
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(destination_index)),
    @lib.Instruction::local_get(text_local(destination_index)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::local_get(text_local(copy_index)),
    text_i32(64),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(text_local(range_length)),
    @lib.Instruction::i32_le_u(),
    @lib.Instruction::i32_and(),
  ]
  let copy_64 : Array[@lib.Instruction] = []
  for offset in [0, 16, 32, 48] {
    copy_64.push(@lib.Instruction::local_get(text_local(chunks)))
    copy_64.push(@lib.Instruction::local_get(text_local(destination_index)))
    if offset != 0 {
      copy_64.push(text_i32(offset))
      copy_64.push(@lib.Instruction::i32_add())
    }
    copy_64.push(text_i32(4))
    copy_64.push(@lib.Instruction::i32_shr_u())
    copy_64.push(text_i32(wasi_scratch_address()))
    copy_64.push(@lib.Instruction::local_get(text_local(copy_index)))
    if offset != 0 {
      copy_64.push(text_i32(offset))
      copy_64.push(@lib.Instruction::i32_add())
    }
    copy_64.push(@lib.Instruction::i32_add())
    copy_64.push(@lib.Instruction::v128_load(starshine_memory_argument(4U)))
    copy_64.push(@lib.Instruction::array_set(array_type))
  }
  copy_64.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_64.push(text_i32(64))
  copy_64.push(@lib.Instruction::i32_add())
  copy_64.push(@lib.Instruction::local_set(text_local(copy_index)))
  copy_64.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  copy_loop.push(@lib.Instruction::if_(@lib.BlockType::void_(), copy_64, None))
  copy_loop.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_loop.push(text_i32(16))
  copy_loop.push(@lib.Instruction::i32_add())
  copy_loop.push(@lib.Instruction::local_get(text_local(range_length)))
  copy_loop.push(@lib.Instruction::i32_le_u())
  let copy_full : Array[@lib.Instruction] = [
    text_i32(wasi_scratch_address()),
    @lib.Instruction::local_get(text_local(copy_index)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::v128_load(starshine_memory_argument(4U)),
    @lib.Instruction::local_set(text_local(vector)),
  ]
  text_write_logical_v128(
    copy_full, array_type, chunks, destination_index, vector, mask,
  )
  copy_full.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_full.push(text_i32(16))
  copy_full.push(@lib.Instruction::i32_add())
  copy_full.push(@lib.Instruction::local_set(text_local(copy_index)))
  copy_full.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  copy_loop.push(
    @lib.Instruction::if_(@lib.BlockType::void_(), copy_full, None),
  )
  copy_loop.push(text_i32(wasi_scratch_address()))
  copy_loop.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_loop.push(@lib.Instruction::i32_add())
  copy_loop.push(@lib.Instruction::i32_load8u(starshine_memory_argument(0U)))
  copy_loop.push(@lib.Instruction::local_set(text_local(byte)))
  text_write_byte(copy_loop, array_type, chunks, destination_index, byte)
  copy_loop.push(@lib.Instruction::local_get(text_local(copy_index)))
  copy_loop.push(text_i32(1))
  copy_loop.push(@lib.Instruction::i32_add())
  copy_loop.push(@lib.Instruction::local_set(text_local(copy_index)))
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

///| Benchmark-only linear-to-GC phase used to isolate immutable Bytes

///|
/// construction from the Preview 1 host callback.
fn starshine_wasi_stage_read_body(base : Int) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let bytes_type = @lib.TypeIdx::new((base + 2).reinterpret_as_uint())
  let chunks = 1
  let required_chunks = 2
  let destination_base = 3
  let copy_index = 4
  let destination_index = 5
  let byte = 6
  let vector = 7
  let mask = 8
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(0)),
    text_i32(wasi_scratch_capacity()),
    @lib.Instruction::i32_gt_u(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
    @lib.Instruction::local_get(text_local(0)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::local_get(text_local(0)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    text_i32(0),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_tee(text_local(required_chunks)),
    @lib.Instruction::array_new_default(array_type),
    @lib.Instruction::local_set(text_local(chunks)),
    text_i32(0),
    @lib.Instruction::local_set(text_local(destination_base)),
  ]
  wasi_copy_scratch_to_bytes(
    body, array_type, chunks, destination_base, 0, copy_index, destination_index,
    byte, vector, mask,
  )
  body.push(@lib.Instruction::local_get(text_local(chunks)))
  body.push(text_i32(0))
  body.push(@lib.Instruction::local_get(text_local(0)))
  body.push(@lib.Instruction::struct_new(bytes_type))
  @lib.Func::new(
    @lib.Locals::from_types([
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
fn starshine_wasi_fd_read_body(
  base : Int,
  fd_read_function_index : Int,
) -> @lib.Func {
  let array_type = @lib.TypeIdx::new(base.reinterpret_as_uint())
  let bytes_type = @lib.TypeIdx::new((base + 2).reinterpret_as_uint())
  let chunks = 2
  let total = 3
  let capacity_chunks = 4
  let request = 5
  let read_count = 6
  let required_length = 7
  let required_chunks = 8
  let new_capacity = 9
  let new_chunks = 10
  let old_copy_index = 11
  let copy_index = 12
  let destination_index = 13
  let byte = 14
  let vector = 15
  let mask = 16
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(1)),
    text_i32(wasi_scratch_capacity()),
    @lib.Instruction::i32_gt_u(),
  ]
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [text_i32(wasi_scratch_capacity())],
      Some([@lib.Instruction::local_get(text_local(1))]),
    ),
  )
  body.push(text_i32(4))
  body.push(@lib.Instruction::i32_shr_u())
  body.push(@lib.Instruction::local_get(text_local(1)))
  body.push(text_i32(wasi_scratch_capacity()))
  body.push(@lib.Instruction::i32_gt_u())
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [text_i32(wasi_scratch_capacity())],
      Some([@lib.Instruction::local_get(text_local(1))]),
    ),
  )
  body.push(text_i32(15))
  body.push(@lib.Instruction::i32_and())
  body.push(text_i32(0))
  body.push(@lib.Instruction::i32_ne())
  body.push(@lib.Instruction::i32_add())
  body.push(@lib.Instruction::local_tee(text_local(capacity_chunks)))
  body.push(@lib.Instruction::array_new_default(array_type))
  body.push(@lib.Instruction::local_set(text_local(chunks)))
  body.push(text_i32(0))
  body.push(@lib.Instruction::local_set(text_local(total)))
  wasi_store_i32(body, wasi_iovec_address(), wasi_scratch_address())
  let read_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(total)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(1)),
    @lib.Instruction::local_get(text_local(total)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_tee(text_local(request)),
    text_i32(wasi_scratch_capacity()),
    @lib.Instruction::i32_gt_u(),
  ]
  read_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        text_i32(wasi_scratch_capacity()),
        @lib.Instruction::local_set(text_local(request)),
      ],
      None,
    ),
  )
  wasi_store_i32_local(read_loop, wasi_iovec_address() + 4, request)
  read_loop.push(@lib.Instruction::local_get(text_local(0)))
  read_loop.push(text_i32(wasi_iovec_address()))
  read_loop.push(text_i32(1))
  read_loop.push(text_i32(wasi_result_address()))
  read_loop.push(
    @lib.Instruction::call(
      @lib.FuncIdx::new(fd_read_function_index.reinterpret_as_uint()),
    ),
  )
  read_loop.push(text_i32(0))
  read_loop.push(@lib.Instruction::i32_ne())
  read_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
  )
  read_loop.push(text_i32(wasi_result_address()))
  read_loop.push(@lib.Instruction::i32_load(starshine_memory_argument(2U)))
  read_loop.push(@lib.Instruction::local_tee(text_local(read_count)))
  read_loop.push(@lib.Instruction::local_get(text_local(request)))
  read_loop.push(@lib.Instruction::i32_gt_u())
  read_loop.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::unreachable_()],
      None,
    ),
  )
  read_loop.push(@lib.Instruction::local_get(text_local(read_count)))
  read_loop.push(@lib.Instruction::i32_eqz())
  read_loop.push(@lib.Instruction::br_if(@lib.LabelIdx::new(1U)))
  read_loop.push(@lib.Instruction::local_get(text_local(total)))
  read_loop.push(@lib.Instruction::local_get(text_local(read_count)))
  read_loop.push(@lib.Instruction::i32_add())
  read_loop.push(@lib.Instruction::local_tee(text_local(required_length)))
  read_loop.push(text_i32(4))
  read_loop.push(@lib.Instruction::i32_shr_u())
  read_loop.push(@lib.Instruction::local_get(text_local(required_length)))
  read_loop.push(text_i32(15))
  read_loop.push(@lib.Instruction::i32_and())
  read_loop.push(text_i32(0))
  read_loop.push(@lib.Instruction::i32_ne())
  read_loop.push(@lib.Instruction::i32_add())
  read_loop.push(@lib.Instruction::local_tee(text_local(required_chunks)))
  read_loop.push(@lib.Instruction::local_get(text_local(capacity_chunks)))
  read_loop.push(@lib.Instruction::i32_gt_u())
  let grow : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    text_i32(1),
    @lib.Instruction::i32_shl(),
    @lib.Instruction::local_tee(text_local(new_capacity)),
    @lib.Instruction::local_get(text_local(capacity_chunks)),
    @lib.Instruction::i32_lt_u(),
    @lib.Instruction::local_get(text_local(new_capacity)),
    @lib.Instruction::local_get(text_local(required_chunks)),
    @lib.Instruction::i32_lt_u(),
    @lib.Instruction::i32_or(),
  ]
  grow.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(text_local(required_chunks)),
        @lib.Instruction::local_set(text_local(new_capacity)),
      ],
      None,
    ),
  )
  grow.push(@lib.Instruction::local_get(text_local(new_capacity)))
  grow.push(@lib.Instruction::array_new_default(array_type))
  grow.push(@lib.Instruction::local_set(text_local(new_chunks)))
  grow.push(text_i32(0))
  grow.push(@lib.Instruction::local_set(text_local(old_copy_index)))
  let old_copy_loop : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(text_local(old_copy_index)),
    @lib.Instruction::local_get(text_local(total)),
    text_i32(4),
    @lib.Instruction::i32_shr_u(),
    @lib.Instruction::local_get(text_local(total)),
    text_i32(15),
    @lib.Instruction::i32_and(),
    text_i32(0),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_ge_u(),
    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
    @lib.Instruction::local_get(text_local(new_chunks)),
    @lib.Instruction::local_get(text_local(old_copy_index)),
    @lib.Instruction::local_get(text_local(chunks)),
    @lib.Instruction::local_get(text_local(old_copy_index)),
    @lib.Instruction::array_get(array_type),
    @lib.Instruction::array_set(array_type),
    @lib.Instruction::local_get(text_local(old_copy_index)),
    text_i32(1),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(text_local(old_copy_index)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]
  grow.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(old_copy_loop),
        ),
      ]),
    ),
  )
  grow.push(@lib.Instruction::local_get(text_local(new_chunks)))
  grow.push(@lib.Instruction::local_set(text_local(chunks)))
  grow.push(@lib.Instruction::local_get(text_local(new_capacity)))
  grow.push(@lib.Instruction::local_set(text_local(capacity_chunks)))
  read_loop.push(@lib.Instruction::if_(@lib.BlockType::void_(), grow, None))
  wasi_copy_scratch_to_bytes(
    read_loop, array_type, chunks, total, read_count, copy_index, destination_index,
    byte, vector, mask,
  )
  read_loop.push(@lib.Instruction::local_get(text_local(required_length)))
  read_loop.push(@lib.Instruction::local_set(text_local(total)))
  read_loop.push(@lib.Instruction::local_get(text_local(read_count)))
  read_loop.push(@lib.Instruction::local_get(text_local(request)))
  read_loop.push(@lib.Instruction::i32_lt_u())
  read_loop.push(@lib.Instruction::br_if(@lib.LabelIdx::new(1U)))
  read_loop.push(@lib.Instruction::br(@lib.LabelIdx::new(0U)))
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(read_loop),
        ),
      ]),
    ),
  )
  body.push(@lib.Instruction::local_get(text_local(chunks)))
  body.push(text_i32(0))
  body.push(@lib.Instruction::local_get(text_local(total)))
  body.push(@lib.Instruction::struct_new(bytes_type))
  @lib.Func::new(
    @lib.Locals::from_types([
      text_runtime_ref(base),
      @lib.ValType::i32(),
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
      @lib.ValType::v128(),
      @lib.ValType::v128(),
    ]),
    @lib.Expr::new(body),
  )
}
