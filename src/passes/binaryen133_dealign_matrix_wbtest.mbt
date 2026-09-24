///|
// Each fixture checks the active dispatcher, the exact replacement instruction,
// and its encoding. The nonzero offset and final SIMD lane must
// survive reducing the alignment hint to one byte.
fn binaryen133_check_dealign_memory(
  body : String,
  expected : @lib.Instruction,
  bytes : Bytes,
) -> Unit raise {
  let input = @wast.wast_to_binary_module(
    "(module (memory 1) (func (export \"run\") \{body}))",
  ).unwrap()
  assert_true(@validate.validate_module(input).is_ok())
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["dealign"]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.filter(fn(i) { i == expected }).length(), 1)
  let buf = @buffer.new()
  @binary.Encode::encode(expected, buf).unwrap()
  assert_eq(buf.to_bytes(), bytes)
  let encoded = @binary.encode_module(output).unwrap()
  let decoded = @binary.decode_module(encoded).unwrap()
  assert_true(@validate.validate_module(decoded).is_ok())
  assert_eq(decoded.code_sec, output.code_sec)
  let twice = run_hot_pipeline(output, HotPipelineOptions::new(), ["dealign"]).unwrap()
  assert_eq(twice.code_sec, output.code_sec)
}

///|
test "Binaryen 133 dealign rewrites nested control and legacy catch bodies" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (memory 1) (tag $e) (func))",
  )
  let original = @lib.Instruction::i64_load(
    @lib.MemArg::new(@lib.U32(3U), Some(@lib.MemIdx::new(1U)), @lib.U64(145UL)),
  )
  let expected = @lib.Instruction::i64_load(
    @lib.MemArg::new(@lib.U32(0U), Some(@lib.MemIdx::new(1U)), @lib.U64(145UL)),
  )
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(0)),
    original,
    @lib.Instruction::drop(),
  ])
  let void_ = @lib.BlockType::void_()
  let nested = @lib.Expr::new([
    @lib.Instruction::block(void_, body),
    @lib.Instruction::loop_(void_, body),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(void_, body.0, Some(body.0)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(void_, body.0, None),
    @lib.Instruction::try_(void_, body, [
      @lib.LegacyCatch::tagged(@lib.TagIdx::new(0U), body),
      @lib.LegacyCatch::all(body),
    ]),
    @lib.Instruction::try_table(void_, [], body),
  ])
  let input = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), nested)]),
  )
  assert_true(@validate.validate_module(input).is_ok())
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["dealign"]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(binaryen133_shared_opcode_count(output, original), 0)
  assert_eq(binaryen133_shared_opcode_count(output, expected), 9)
  let bytes = @buffer.new()
  @binary.Encode::encode(expected, bytes).unwrap()
  assert_eq(bytes.to_bytes(), b"\x29\x40\x01\x91\x01")
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  assert_eq(decoded.code_sec, output.code_sec)
  assert_true(@validate.validate_module(decoded).is_ok())
}

///|
test "Binaryen 133 dealign preserves offsets for scalar loads" {
  let ma = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(145UL))
  let cases : Array[(String, @lib.Instruction, Bytes)] = [
    (
      "i32.const 0 i32.load offset=145 align=4 drop",
      @lib.Instruction::i32_load(ma),
      b"\x28\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.load offset=145 align=8 drop",
      @lib.Instruction::i64_load(ma),
      b"\x29\x00\x91\x01",
    ),
    (
      "i32.const 0 f32.load offset=145 align=4 drop",
      @lib.Instruction::f32_load(ma),
      b"\x2a\x00\x91\x01",
    ),
    (
      "i32.const 0 f64.load offset=145 align=8 drop",
      @lib.Instruction::f64_load(ma),
      b"\x2b\x00\x91\x01",
    ),
    (
      "i32.const 0 i32.load8_s offset=145 align=1 drop",
      @lib.Instruction::i32_load8s(ma),
      b"\x2c\x00\x91\x01",
    ),
    (
      "i32.const 0 i32.load8_u offset=145 align=1 drop",
      @lib.Instruction::i32_load8u(ma),
      b"\x2d\x00\x91\x01",
    ),
    (
      "i32.const 0 i32.load16_s offset=145 align=2 drop",
      @lib.Instruction::i32_load16s(ma),
      b"\x2e\x00\x91\x01",
    ),
    (
      "i32.const 0 i32.load16_u offset=145 align=2 drop",
      @lib.Instruction::i32_load16u(ma),
      b"\x2f\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.load8_s offset=145 align=1 drop",
      @lib.Instruction::i64_load8s(ma),
      b"\x30\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.load8_u offset=145 align=1 drop",
      @lib.Instruction::i64_load8u(ma),
      b"\x31\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.load16_s offset=145 align=2 drop",
      @lib.Instruction::i64_load16s(ma),
      b"\x32\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.load16_u offset=145 align=2 drop",
      @lib.Instruction::i64_load16u(ma),
      b"\x33\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.load32_s offset=145 align=4 drop",
      @lib.Instruction::i64_load32s(ma),
      b"\x34\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.load32_u offset=145 align=4 drop",
      @lib.Instruction::i64_load32u(ma),
      b"\x35\x00\x91\x01",
    ),
  ]
  for (body, expected, bytes) in cases {
    binaryen133_check_dealign_memory(body, expected, bytes)
  }
}

///|
test "Binaryen 133 dealign preserves offsets for SIMD loads" {
  let ma = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(145UL))
  let cases : Array[(String, @lib.Instruction, Bytes)] = [
    (
      "i32.const 0 v128.load offset=145 align=16 drop",
      @lib.Instruction::v128_load(ma),
      b"\xfd\x00\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load8x8_s offset=145 align=8 drop",
      @lib.Instruction::v128_load8x8s(ma),
      b"\xfd\x01\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load8x8_u offset=145 align=8 drop",
      @lib.Instruction::v128_load8x8u(ma),
      b"\xfd\x02\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load16x4_s offset=145 align=8 drop",
      @lib.Instruction::v128_load16x4s(ma),
      b"\xfd\x03\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load16x4_u offset=145 align=8 drop",
      @lib.Instruction::v128_load16x4u(ma),
      b"\xfd\x04\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load32x2_s offset=145 align=8 drop",
      @lib.Instruction::v128_load32x2s(ma),
      b"\xfd\x05\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load32x2_u offset=145 align=8 drop",
      @lib.Instruction::v128_load32x2u(ma),
      b"\xfd\x06\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load8_splat offset=145 align=1 drop",
      @lib.Instruction::v128_load8_splat(ma),
      b"\xfd\x07\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load16_splat offset=145 align=2 drop",
      @lib.Instruction::v128_load16_splat(ma),
      b"\xfd\x08\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load32_splat offset=145 align=4 drop",
      @lib.Instruction::v128_load32_splat(ma),
      b"\xfd\x09\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load64_splat offset=145 align=8 drop",
      @lib.Instruction::v128_load64_splat(ma),
      b"\xfd\x0a\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load32_zero offset=145 align=4 drop",
      @lib.Instruction::v128_load32_zero(ma),
      b"\xfd\x5c\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.load64_zero offset=145 align=8 drop",
      @lib.Instruction::v128_load64_zero(ma),
      b"\xfd\x5d\x00\x91\x01",
    ),
  ]
  for (body, expected, bytes) in cases {
    binaryen133_check_dealign_memory(body, expected, bytes)
  }
}

///|
test "Binaryen 133 dealign preserves offsets for scalar and SIMD stores" {
  let ma = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(145UL))
  let cases : Array[(String, @lib.Instruction, Bytes)] = [
    (
      "i32.const 0 i32.const 91 i32.store offset=145 align=4",
      @lib.Instruction::i32_store(ma),
      b"\x36\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.const 91 i64.store offset=145 align=8",
      @lib.Instruction::i64_store(ma),
      b"\x37\x00\x91\x01",
    ),
    (
      "i32.const 0 f32.const 1.5 f32.store offset=145 align=4",
      @lib.Instruction::f32_store(ma),
      b"\x38\x00\x91\x01",
    ),
    (
      "i32.const 0 f64.const 1.5 f64.store offset=145 align=8",
      @lib.Instruction::f64_store(ma),
      b"\x39\x00\x91\x01",
    ),
    (
      "i32.const 0 i32.const 91 i32.store8 offset=145 align=1",
      @lib.Instruction::i32_store8(ma),
      b"\x3a\x00\x91\x01",
    ),
    (
      "i32.const 0 i32.const 91 i32.store16 offset=145 align=2",
      @lib.Instruction::i32_store16(ma),
      b"\x3b\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.const 91 i64.store8 offset=145 align=1",
      @lib.Instruction::i64_store8(ma),
      b"\x3c\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.const 91 i64.store16 offset=145 align=2",
      @lib.Instruction::i64_store16(ma),
      b"\x3d\x00\x91\x01",
    ),
    (
      "i32.const 0 i64.const 91 i64.store32 offset=145 align=4",
      @lib.Instruction::i64_store32(ma),
      b"\x3e\x00\x91\x01",
    ),
    (
      "i32.const 0 v128.const i32x4 1 2 3 4 v128.store offset=145 align=16",
      @lib.Instruction::v128_store(ma),
      b"\xfd\x0b\x00\x91\x01",
    ),
  ]
  for (body, expected, bytes) in cases {
    binaryen133_check_dealign_memory(body, expected, bytes)
  }
}

///|
test "Binaryen 133 dealign preserves SIMD lane indices" {
  let ma = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(145UL))
  let cases : Array[(String, @lib.Instruction, Bytes)] = [
    (
      "i32.const 0 v128.const i32x4 1 2 3 4 v128.load8_lane offset=145 align=1 15 drop",
      @lib.Instruction::v128_load8_lane(ma, @lib.LaneIdx::new(15)),
      b"\xfd\x54\x00\x91\x01\x0f",
    ),
    (
      "i32.const 0 v128.const i32x4 1 2 3 4 v128.load16_lane offset=145 align=2 7 drop",
      @lib.Instruction::v128_load16_lane(ma, @lib.LaneIdx::new(7)),
      b"\xfd\x55\x00\x91\x01\x07",
    ),
    (
      "i32.const 0 v128.const i32x4 1 2 3 4 v128.load32_lane offset=145 align=4 3 drop",
      @lib.Instruction::v128_load32_lane(ma, @lib.LaneIdx::new(3)),
      b"\xfd\x56\x00\x91\x01\x03",
    ),
    (
      "i32.const 0 v128.const i32x4 1 2 3 4 v128.load64_lane offset=145 align=8 1 drop",
      @lib.Instruction::v128_load64_lane(ma, @lib.LaneIdx::new(1)),
      b"\xfd\x57\x00\x91\x01\x01",
    ),
    (
      "i32.const 0 v128.const i32x4 1 2 3 4 v128.store8_lane offset=145 align=1 15",
      @lib.Instruction::v128_store8_lane(ma, @lib.LaneIdx::new(15)),
      b"\xfd\x58\x00\x91\x01\x0f",
    ),
    (
      "i32.const 0 v128.const i32x4 1 2 3 4 v128.store16_lane offset=145 align=2 7",
      @lib.Instruction::v128_store16_lane(ma, @lib.LaneIdx::new(7)),
      b"\xfd\x59\x00\x91\x01\x07",
    ),
    (
      "i32.const 0 v128.const i32x4 1 2 3 4 v128.store32_lane offset=145 align=4 3",
      @lib.Instruction::v128_store32_lane(ma, @lib.LaneIdx::new(3)),
      b"\xfd\x5a\x00\x91\x01\x03",
    ),
    (
      "i32.const 0 v128.const i32x4 1 2 3 4 v128.store64_lane offset=145 align=8 1",
      @lib.Instruction::v128_store64_lane(ma, @lib.LaneIdx::new(1)),
      b"\xfd\x5b\x00\x91\x01\x01",
    ),
  ]
  for (body, expected, bytes) in cases {
    binaryen133_check_dealign_memory(body, expected, bytes)
  }
}
