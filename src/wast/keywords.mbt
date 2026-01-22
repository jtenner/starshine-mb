// ============================================================================
// keywords.mbt - Keyword Hash Table
// ============================================================================

// Simple hash function for keyword lookup

///|
fn hash_string(s : String) -> Int {
  let mut h = 0
  for i = 0; i < s.length(); i = i + 1 {
    h = (h * 31 + s[i].to_int()) % 0x7FFFFFFF
  }
  h
}

// Keyword hash table using a Map

///|
pub struct KeywordTable {
  map : @hashmap.HashMap[String, TokenType]
}

///|
fn KeywordTable::new() -> KeywordTable {
  let map = @hashmap.new(capacity=512)

  // Module structure
  map.set("module", Module)
  map.set("type", Type)
  map.set("func", Func)
  map.set("param", Param)
  map.set("result", Result)
  map.set("local", Local)
  map.set("global", Global)
  map.set("table", Table)
  map.set("memory", Memory)
  map.set("elem", Elem)
  map.set("data", Data)
  map.set("start", Start)
  map.set("import", Import)
  map.set("export", Export)
  map.set("mut", Mut)
  map.set("offset", Offset)
  map.set("item", Item)
  map.set("declare", Declare)
  map.set("quote", Quote)
  map.set("register", Register)
  map.set("invoke", Invoke)
  map.set("get", Get)
  map.set("binary", Binary)
  map.set("input", Input)
  map.set("output", Output)

  // Assertions
  map.set("assert_malformed", AssertMalformed)
  map.set("assert_invalid", AssertInvalid)
  map.set("assert_unlinkable", AssertUnlinkable)
  map.set("assert_return", AssertReturn)
  map.set("assert_trap", AssertTrap)
  map.set("assert_exhaustion", AssertExhaustion)

  // Control keywords
  map.set("block", Block)
  map.set("loop", Loop)
  map.set("if", If)
  map.set("then", Then)
  map.set("else", Else)
  map.set("end", End)

  // Value types
  map.set("i32", ValueType(I32))
  map.set("i64", ValueType(I64))
  map.set("f32", ValueType(F32))
  map.set("f64", ValueType(F64))
  map.set("v128", ValueType(V128))
  map.set("funcref", ValueType(FuncRef))
  map.set("externref", ValueType(ExternRef))

  // Control instructions
  map.set("unreachable", Opcode(Unreachable))
  map.set("nop", Opcode(Nop))
  map.set("br", Opcode(Br))
  map.set("br_if", Opcode(BrIf))
  map.set("br_table", Opcode(BrTable))
  map.set("return", Opcode(Return))
  map.set("call", Opcode(Call))
  map.set("call_indirect", Opcode(CallIndirect))

  // Reference instructions
  map.set("ref.null", Opcode(RefNull))
  map.set("ref.is_null", Opcode(RefIsNull))
  map.set("ref.func", Opcode(RefFunc))

  // Parametric instructions
  map.set("drop", Opcode(Drop))
  map.set("select", Opcode(Select))

  // Variable instructions
  map.set("local.get", Opcode(LocalGet))
  map.set("local.set", Opcode(LocalSet))
  map.set("local.tee", Opcode(LocalTee))
  map.set("global.get", Opcode(GlobalGet))
  map.set("global.set", Opcode(GlobalSet))

  // Table instructions
  map.set("table.get", Opcode(TableGet))
  map.set("table.set", Opcode(TableSet))
  map.set("table.size", Opcode(TableSize))
  map.set("table.grow", Opcode(TableGrow))
  map.set("table.fill", Opcode(TableFill))
  map.set("table.copy", Opcode(TableCopy))
  map.set("table.init", Opcode(TableInit))
  map.set("elem.drop", Opcode(ElemDrop))

  // Memory instructions
  map.set("i32.load", Opcode(I32Load))
  map.set("i64.load", Opcode(I64Load))
  map.set("f32.load", Opcode(F32Load))
  map.set("f64.load", Opcode(F64Load))
  map.set("i32.load8_s", Opcode(I32Load8S))
  map.set("i32.load8_u", Opcode(I32Load8U))
  map.set("i32.load16_s", Opcode(I32Load16S))
  map.set("i32.load16_u", Opcode(I32Load16U))
  map.set("i64.load8_s", Opcode(I64Load8S))
  map.set("i64.load8_u", Opcode(I64Load8U))
  map.set("i64.load16_s", Opcode(I64Load16S))
  map.set("i64.load16_u", Opcode(I64Load16U))
  map.set("i64.load32_s", Opcode(I64Load32S))
  map.set("i64.load32_u", Opcode(I64Load32U))
  map.set("i32.store", Opcode(I32Store))
  map.set("i64.store", Opcode(I64Store))
  map.set("f32.store", Opcode(F32Store))
  map.set("f64.store", Opcode(F64Store))
  map.set("i32.store8", Opcode(I32Store8))
  map.set("i32.store16", Opcode(I32Store16))
  map.set("i64.store8", Opcode(I64Store8))
  map.set("i64.store16", Opcode(I64Store16))
  map.set("i64.store32", Opcode(I64Store32))
  map.set("memory.size", Opcode(MemorySize))
  map.set("memory.grow", Opcode(MemoryGrow))
  map.set("memory.fill", Opcode(MemoryFill))
  map.set("memory.copy", Opcode(MemoryCopy))
  map.set("memory.init", Opcode(MemoryInit))
  map.set("data.drop", Opcode(DataDrop))

  // Numeric - Constants
  map.set("i32.const", Opcode(I32Const))
  map.set("i64.const", Opcode(I64Const))
  map.set("f32.const", Opcode(F32Const))
  map.set("f64.const", Opcode(F64Const))

  // i32 comparison
  map.set("i32.eqz", Opcode(I32Eqz))
  map.set("i32.eq", Opcode(I32Eq))
  map.set("i32.ne", Opcode(I32Ne))
  map.set("i32.lt_s", Opcode(I32LtS))
  map.set("i32.lt_u", Opcode(I32LtU))
  map.set("i32.gt_s", Opcode(I32GtS))
  map.set("i32.gt_u", Opcode(I32GtU))
  map.set("i32.le_s", Opcode(I32LeS))
  map.set("i32.le_u", Opcode(I32LeU))
  map.set("i32.ge_s", Opcode(I32GeS))
  map.set("i32.ge_u", Opcode(I32GeU))

  // i32 arithmetic
  map.set("i32.clz", Opcode(I32Clz))
  map.set("i32.ctz", Opcode(I32Ctz))
  map.set("i32.popcnt", Opcode(I32Popcnt))
  map.set("i32.add", Opcode(I32Add))
  map.set("i32.sub", Opcode(I32Sub))
  map.set("i32.mul", Opcode(I32Mul))
  map.set("i32.div_s", Opcode(I32DivS))
  map.set("i32.div_u", Opcode(I32DivU))
  map.set("i32.rem_s", Opcode(I32RemS))
  map.set("i32.rem_u", Opcode(I32RemU))
  map.set("i32.and", Opcode(I32And))
  map.set("i32.or", Opcode(I32Or))
  map.set("i32.xor", Opcode(I32Xor))
  map.set("i32.shl", Opcode(I32Shl))
  map.set("i32.shr_s", Opcode(I32ShrS))
  map.set("i32.shr_u", Opcode(I32ShrU))
  map.set("i32.rotl", Opcode(I32Rotl))
  map.set("i32.rotr", Opcode(I32Rotr))

  // i64 comparison
  map.set("i64.eqz", Opcode(I64Eqz))
  map.set("i64.eq", Opcode(I64Eq))
  map.set("i64.ne", Opcode(I64Ne))
  map.set("i64.lt_s", Opcode(I64LtS))
  map.set("i64.lt_u", Opcode(I64LtU))
  map.set("i64.gt_s", Opcode(I64GtS))
  map.set("i64.gt_u", Opcode(I64GtU))
  map.set("i64.le_s", Opcode(I64LeS))
  map.set("i64.le_u", Opcode(I64LeU))
  map.set("i64.ge_s", Opcode(I64GeS))
  map.set("i64.ge_u", Opcode(I64GeU))

  // i64 arithmetic
  map.set("i64.clz", Opcode(I64Clz))
  map.set("i64.ctz", Opcode(I64Ctz))
  map.set("i64.popcnt", Opcode(I64Popcnt))
  map.set("i64.add", Opcode(I64Add))
  map.set("i64.sub", Opcode(I64Sub))
  map.set("i64.mul", Opcode(I64Mul))
  map.set("i64.div_s", Opcode(I64DivS))
  map.set("i64.div_u", Opcode(I64DivU))
  map.set("i64.rem_s", Opcode(I64RemS))
  map.set("i64.rem_u", Opcode(I64RemU))
  map.set("i64.and", Opcode(I64And))
  map.set("i64.or", Opcode(I64Or))
  map.set("i64.xor", Opcode(I64Xor))
  map.set("i64.shl", Opcode(I64Shl))
  map.set("i64.shr_s", Opcode(I64ShrS))
  map.set("i64.shr_u", Opcode(I64ShrU))
  map.set("i64.rotl", Opcode(I64Rotl))
  map.set("i64.rotr", Opcode(I64Rotr))

  // f32 comparison
  map.set("f32.eq", Opcode(F32Eq))
  map.set("f32.ne", Opcode(F32Ne))
  map.set("f32.lt", Opcode(F32Lt))
  map.set("f32.gt", Opcode(F32Gt))
  map.set("f32.le", Opcode(F32Le))
  map.set("f32.ge", Opcode(F32Ge))

  // f32 arithmetic
  map.set("f32.abs", Opcode(F32Abs))
  map.set("f32.neg", Opcode(F32Neg))
  map.set("f32.ceil", Opcode(F32Ceil))
  map.set("f32.floor", Opcode(F32Floor))
  map.set("f32.trunc", Opcode(F32Trunc))
  map.set("f32.nearest", Opcode(F32Nearest))
  map.set("f32.sqrt", Opcode(F32Sqrt))
  map.set("f32.add", Opcode(F32Add))
  map.set("f32.sub", Opcode(F32Sub))
  map.set("f32.mul", Opcode(F32Mul))
  map.set("f32.div", Opcode(F32Div))
  map.set("f32.min", Opcode(F32Min))
  map.set("f32.max", Opcode(F32Max))
  map.set("f32.copysign", Opcode(F32Copysign))

  // f64 comparison
  map.set("f64.eq", Opcode(F64Eq))
  map.set("f64.ne", Opcode(F64Ne))
  map.set("f64.lt", Opcode(F64Lt))
  map.set("f64.gt", Opcode(F64Gt))
  map.set("f64.le", Opcode(F64Le))
  map.set("f64.ge", Opcode(F64Ge))

  // f64 arithmetic
  map.set("f64.abs", Opcode(F64Abs))
  map.set("f64.neg", Opcode(F64Neg))
  map.set("f64.ceil", Opcode(F64Ceil))
  map.set("f64.floor", Opcode(F64Floor))
  map.set("f64.trunc", Opcode(F64Trunc))
  map.set("f64.nearest", Opcode(F64Nearest))
  map.set("f64.sqrt", Opcode(F64Sqrt))
  map.set("f64.add", Opcode(F64Add))
  map.set("f64.sub", Opcode(F64Sub))
  map.set("f64.mul", Opcode(F64Mul))
  map.set("f64.div", Opcode(F64Div))
  map.set("f64.min", Opcode(F64Min))
  map.set("f64.max", Opcode(F64Max))
  map.set("f64.copysign", Opcode(F64Copysign))

  // Conversions
  map.set("i32.wrap_i64", Opcode(I32WrapI64))
  map.set("i32.trunc_f32_s", Opcode(I32TruncF32S))
  map.set("i32.trunc_f32_u", Opcode(I32TruncF32U))
  map.set("i32.trunc_f64_s", Opcode(I32TruncF64S))
  map.set("i32.trunc_f64_u", Opcode(I32TruncF64U))
  map.set("i64.extend_i32_s", Opcode(I64ExtendI32S))
  map.set("i64.extend_i32_u", Opcode(I64ExtendI32U))
  map.set("i64.trunc_f32_s", Opcode(I64TruncF32S))
  map.set("i64.trunc_f32_u", Opcode(I64TruncF32U))
  map.set("i64.trunc_f64_s", Opcode(I64TruncF64S))
  map.set("i64.trunc_f64_u", Opcode(I64TruncF64U))
  map.set("f32.convert_i32_s", Opcode(F32ConvertI32S))
  map.set("f32.convert_i32_u", Opcode(F32ConvertI32U))
  map.set("f32.convert_i64_s", Opcode(F32ConvertI64S))
  map.set("f32.convert_i64_u", Opcode(F32ConvertI64U))
  map.set("f32.demote_f64", Opcode(F32DemoteF64))
  map.set("f64.convert_i32_s", Opcode(F64ConvertI32S))
  map.set("f64.convert_i32_u", Opcode(F64ConvertI32U))
  map.set("f64.convert_i64_s", Opcode(F64ConvertI64S))
  map.set("f64.convert_i64_u", Opcode(F64ConvertI64U))
  map.set("f64.promote_f32", Opcode(F64PromoteF32))
  map.set("i32.reinterpret_f32", Opcode(I32ReinterpretF32))
  map.set("i64.reinterpret_f64", Opcode(I64ReinterpretF64))
  map.set("f32.reinterpret_i32", Opcode(F32ReinterpretI32))
  map.set("f64.reinterpret_i64", Opcode(F64ReinterpretI64))

  // Sign extension
  map.set("i32.extend8_s", Opcode(I32Extend8S))
  map.set("i32.extend16_s", Opcode(I32Extend16S))
  map.set("i64.extend8_s", Opcode(I64Extend8S))
  map.set("i64.extend16_s", Opcode(I64Extend16S))
  map.set("i64.extend32_s", Opcode(I64Extend32S))

  // Saturating truncation
  map.set("i32.trunc_sat_f32_s", Opcode(I32TruncSatF32S))
  map.set("i32.trunc_sat_f32_u", Opcode(I32TruncSatF32U))
  map.set("i32.trunc_sat_f64_s", Opcode(I32TruncSatF64S))
  map.set("i32.trunc_sat_f64_u", Opcode(I32TruncSatF64U))
  map.set("i64.trunc_sat_f32_s", Opcode(I64TruncSatF32S))
  map.set("i64.trunc_sat_f32_u", Opcode(I64TruncSatF32U))
  map.set("i64.trunc_sat_f64_s", Opcode(I64TruncSatF64S))
  map.set("i64.trunc_sat_f64_u", Opcode(I64TruncSatF64U))
  { map, }
}

// Use a lazy-initialized global

///|
let keyword_table : KeywordTable = KeywordTable::new()

///|
pub fn lookup_keyword(s : String) -> TokenType? {
  keyword_table.lookup(s)
}

///|
pub fn KeywordTable::lookup(self : KeywordTable, s : String) -> TokenType? {
  self.map.get(s)
}
