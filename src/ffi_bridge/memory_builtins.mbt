///|
fn starshine_memory_argument(align : UInt) -> @lib.MemArg {
  @lib.MemArg::new(@lib.U32::new(align), None, @lib.U64::new(0UL))
}

///|
pub fn instruction_memory_builtin(opcode : Int) -> @lib.Instruction {
  match opcode {
    0 => @lib.Instruction::i32_load8s(starshine_memory_argument(0U))
    1 => @lib.Instruction::i32_store8(starshine_memory_argument(0U))
    2 => @lib.Instruction::i32_load8u(starshine_memory_argument(0U))
    3 => @lib.Instruction::i32_load16s(starshine_memory_argument(1U))
    4 => @lib.Instruction::i32_store16(starshine_memory_argument(1U))
    5 => @lib.Instruction::i32_load16u(starshine_memory_argument(1U))
    6 => @lib.Instruction::i32_load(starshine_memory_argument(2U))
    7 => @lib.Instruction::i32_store(starshine_memory_argument(2U))
    8 => @lib.Instruction::i64_load(starshine_memory_argument(3U))
    9 => @lib.Instruction::i64_store(starshine_memory_argument(3U))
    10 => @lib.Instruction::f32_load(starshine_memory_argument(2U))
    11 => @lib.Instruction::f32_store(starshine_memory_argument(2U))
    12 => @lib.Instruction::f64_load(starshine_memory_argument(3U))
    13 => @lib.Instruction::f64_store(starshine_memory_argument(3U))
    14 => @lib.Instruction::v128_load(starshine_memory_argument(4U))
    _ => @lib.Instruction::v128_store(starshine_memory_argument(4U))
  }
}

///|
fn starshine_memory_builtin_instructions(
  name : Bytes,
) -> Array[@lib.Instruction]? {
  if name == b"dew_i8_load" {
    Some([@lib.Instruction::i32_load8s(starshine_memory_argument(0U))])
  } else if name == b"dew_i8_store" {
    Some([@lib.Instruction::i32_store8(starshine_memory_argument(0U))])
  } else if name == b"dew_u8_load" {
    Some([@lib.Instruction::i32_load8u(starshine_memory_argument(0U))])
  } else if name == b"dew_u8_store" {
    Some([@lib.Instruction::i32_store8(starshine_memory_argument(0U))])
  } else if name == b"dew_i16_load" {
    Some([@lib.Instruction::i32_load16s(starshine_memory_argument(1U))])
  } else if name == b"dew_i16_store" {
    Some([@lib.Instruction::i32_store16(starshine_memory_argument(1U))])
  } else if name == b"dew_u16_load" {
    Some([@lib.Instruction::i32_load16u(starshine_memory_argument(1U))])
  } else if name == b"dew_u16_store" {
    Some([@lib.Instruction::i32_store16(starshine_memory_argument(1U))])
  } else if name == b"dew_i32_load" ||
    name == b"dew_u32_load" ||
    name == b"dew_swar32_load" {
    Some([@lib.Instruction::i32_load(starshine_memory_argument(2U))])
  } else if name == b"dew_i32_store" ||
    name == b"dew_u32_store" ||
    name == b"dew_swar32_store" {
    Some([@lib.Instruction::i32_store(starshine_memory_argument(2U))])
  } else if name == b"dew_i64_load" ||
    name == b"dew_u64_load" ||
    name == b"dew_swar64_load" {
    Some([@lib.Instruction::i64_load(starshine_memory_argument(3U))])
  } else if name == b"dew_i64_store" ||
    name == b"dew_u64_store" ||
    name == b"dew_swar64_store" {
    Some([@lib.Instruction::i64_store(starshine_memory_argument(3U))])
  } else if name == b"dew_f32_load" {
    Some([@lib.Instruction::f32_load(starshine_memory_argument(2U))])
  } else if name == b"dew_f32_store" {
    Some([@lib.Instruction::f32_store(starshine_memory_argument(2U))])
  } else if name == b"dew_f64_load" {
    Some([@lib.Instruction::f64_load(starshine_memory_argument(3U))])
  } else if name == b"dew_f64_store" {
    Some([@lib.Instruction::f64_store(starshine_memory_argument(3U))])
  } else if name == b"dew_v128_load" {
    Some([@lib.Instruction::v128_load(starshine_memory_argument(4U))])
  } else if name == b"dew_v128_store" {
    Some([@lib.Instruction::v128_store(starshine_memory_argument(4U))])
  } else {
    None
  }
}
