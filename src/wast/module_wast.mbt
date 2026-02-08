///|
pub suberror WastTextError {
  Unsupported(String)
}

///|
fn hex_digit(v : Int) -> Char {
  if v < 10 {
    (v + '0').unsafe_to_char()
  } else {
    (v - 10 + 'a').unsafe_to_char()
  }
}

///|
fn quote_wast_string(s : String) -> String {
  let out = StringBuilder::new()
  out.write_char('"')
  for c in s {
    if c == '"' {
      out.write_string("\\\"")
    } else if c == '\\' {
      out.write_string("\\\\")
    } else if c == '\n' {
      out.write_string("\\n")
    } else if c == '\r' {
      out.write_string("\\r")
    } else if c == '\t' {
      out.write_string("\\t")
    } else {
      out.write_char(c)
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn quote_wast_bytes(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  out.write_char('"')
  for b in bytes {
    if b >= 0x20 && b <= 0x7e && b != 0x22 && b != 0x5c {
      out.write_char(b.to_int().unsafe_to_char())
    } else if b == 0x22 {
      out.write_string("\\\"")
    } else if b == 0x5c {
      out.write_string("\\\\")
    } else {
      out.write_char('\\')
      out.write_char(hex_digit((b >> 4).to_int()))
      out.write_char(hex_digit((b & 0x0f).to_int()))
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn string_to_bytes_for_parser(s : String) -> Bytes {
  let bytes = @buffer.new(size_hint=s.length())
  for i = 0; i < s.length(); i = i + 1 {
    bytes.write_byte(s[i].to_int().to_byte())
  }
  bytes.to_bytes()
}

///|
fn lower_snake_from_pascal(name : String) -> String {
  if name.length() == 0 {
    return ""
  }
  let out = StringBuilder::new()
  let mut i = 0
  while i < name.length() {
    let c = name[i]
    let is_upper = c >= 'A' && c <= 'Z'
    if i > 0 && is_upper {
      let prev = name[i - 1]
      let prev_is_lower_or_digit = (prev >= 'a' && prev <= 'z') ||
        (prev >= '0' && prev <= '9')
      let next_is_lower = if i + 1 < name.length() {
        let n = name[i + 1]
        n >= 'a' && n <= 'z'
      } else {
        false
      }
      if prev_is_lower_or_digit || next_is_lower {
        out.write_char('_')
      }
    }
    if is_upper {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      out.write_char(c.unsafe_to_char())
    }
    i += 1
  }
  out.to_string()
}

///|
fn split_first_underscore(s : String) -> (String, String?) {
  let mut i = 0
  while i < s.length() {
    if s[i] == '_' {
      let head = s.sub(end=i).to_string() catch { _ => s }
      let tail = s.sub(start=i + 1).to_string() catch { _ => "" }
      return (head, Some(tail))
    }
    i += 1
  }
  (s, None)
}

///|
fn keyword_from_opcode(op : Opcode) -> String {
  let raw = lower_snake_from_pascal("\{op}")
  let (head, tail) = split_first_underscore(raw)
  match tail {
    Some(t) => "\{head}.\{t}"
    None => head
  }
}

///|
fn keyword_from_value_type(vt : ValueType) -> String {
  match vt {
    I32 => "i32"
    I64 => "i64"
    F32 => "f32"
    F64 => "f64"
    V128 => "v128"
    FuncRef => "funcref"
    ExternRef => "externref"
  }
}

///|
fn keyword_from_simd_shape(shape : SimdShape) -> String {
  lower_snake_from_pascal("\{shape}").replace(old="_", new="")
}

///|
fn index_text(idx : Index) -> String {
  match idx {
    Num(n) => "\{n}"
    Id(name) => name
  }
}

///|
fn render_type_use(type_use : TypeUse) -> String {
  let out = StringBuilder::new()
  match type_use.type_index {
    Some(idx) => {
      out.write_string(" (type ")
      out.write_string(index_text(idx))
      out.write_char(')')
    }
    None => ()
  }
  if type_use.func_type.params.length() > 0 {
    out.write_string(" (param")
    for p in type_use.func_type.params {
      out.write_char(' ')
      out.write_string(keyword_from_value_type(p))
    }
    out.write_char(')')
  }
  if type_use.func_type.results.length() > 0 {
    out.write_string(" (result")
    for r in type_use.func_type.results {
      out.write_char(' ')
      out.write_string(keyword_from_value_type(r))
    }
    out.write_char(')')
  }
  out.to_string()
}

///|
fn render_block_type(bt : BlockType) -> String {
  let out = StringBuilder::new()
  match bt.label {
    Some(label) => {
      out.write_char(' ')
      out.write_string(label)
    }
    None => ()
  }
  match bt.type_use {
    Some(type_use) => out.write_string(render_type_use(type_use))
    None => ()
  }
  out.to_string()
}

///|
fn render_memarg(ma : MemArg) -> String {
  let out = StringBuilder::new()
  if ma.offset != 0 {
    out.write_string(" offset=")
    out.write_string("\{ma.offset}")
  }
  out.write_string(" align=")
  out.write_string("\{ma.align}")
  out.to_string()
}

///|
fn render_v128_const(v : V128Const) -> String {
  let out = StringBuilder::new()
  out.write_string("v128.const ")
  out.write_string(keyword_from_simd_shape(v.shape))
  for value in v.values {
    out.write_char(' ')
    out.write_string(value)
  }
  out.to_string()
}

///|
fn render_shuffle_lanes(lanes : ShuffleLanes) -> String {
  let out = StringBuilder::new()
  for i = 0; i < 16; i = i + 1 {
    if i > 0 {
      out.write_char(' ')
    }
    out.write_string("\{lanes.lanes[i]}")
  }
  out.to_string()
}

///|
fn render_instruction_head(instr : Instruction) -> String raise WastTextError {
  match instr {
    Unreachable => "unreachable"
    Nop => "nop"
    Br(idx) => "br \{index_text(idx)}"
    BrIf(idx) => "br_if \{index_text(idx)}"
    BrTable(targets, fallback) => {
      let out = StringBuilder::new()
      out.write_string("br_table")
      for idx in targets {
        out.write_char(' ')
        out.write_string(index_text(idx))
      }
      out.write_char(' ')
      out.write_string(index_text(fallback))
      out.to_string()
    }
    Return => "return"
    Call(idx) => "call \{index_text(idx)}"
    CallIndirect(table_idx, type_use) =>
      "call_indirect \{index_text(table_idx)}\{render_type_use(type_use)}"
    Drop => "drop"
    Select(None) => "select"
    Select(Some(vts)) => {
      let out = StringBuilder::new()
      out.write_string("select (result")
      for vt in vts {
        out.write_char(' ')
        out.write_string(keyword_from_value_type(vt))
      }
      out.write_char(')')
      out.to_string()
    }
    LocalGet(idx) => "local.get \{index_text(idx)}"
    LocalSet(idx) => "local.set \{index_text(idx)}"
    LocalTee(idx) => "local.tee \{index_text(idx)}"
    GlobalGet(idx) => "global.get \{index_text(idx)}"
    GlobalSet(idx) => "global.set \{index_text(idx)}"
    TableGet(idx) => "table.get \{index_text(idx)}"
    TableSet(idx) => "table.set \{index_text(idx)}"
    TableSize(idx) => "table.size \{index_text(idx)}"
    TableGrow(idx) => "table.grow \{index_text(idx)}"
    TableFill(idx) => "table.fill \{index_text(idx)}"
    TableCopy(dst, src) => "table.copy \{index_text(dst)} \{index_text(src)}"
    TableInit(table_idx, elem_idx) =>
      "table.init \{index_text(table_idx)} \{index_text(elem_idx)}"
    ElemDrop(idx) => "elem.drop \{index_text(idx)}"
    Load(op, ma) => "\{keyword_from_opcode(op)}\{render_memarg(ma)}"
    Store(op, ma) => "\{keyword_from_opcode(op)}\{render_memarg(ma)}"
    MemorySize => "memory.size"
    MemoryGrow => "memory.grow"
    MemoryFill => "memory.fill"
    MemoryCopy => "memory.copy"
    MemoryInit(idx) => "memory.init \{index_text(idx)}"
    DataDrop(idx) => "data.drop \{index_text(idx)}"
    Const(op, text) => "\{keyword_from_opcode(op)} \{text}"
    Unary(op) => keyword_from_opcode(op)
    Binary(op) => keyword_from_opcode(op)
    Test(op) => keyword_from_opcode(op)
    Compare(op) => keyword_from_opcode(op)
    Convert(op) => keyword_from_opcode(op)
    RefNull(vt) => "ref.null \{keyword_from_value_type(vt)}"
    RefIsNull => "ref.is_null"
    RefFunc(idx) => "ref.func \{index_text(idx)}"
    V128Const(v) => render_v128_const(v)
    V128Load(ma) => "v128.load\{render_memarg(ma)}"
    V128Load8x8S(ma) => "v128.load8x8_s\{render_memarg(ma)}"
    V128Load8x8U(ma) => "v128.load8x8_u\{render_memarg(ma)}"
    V128Load16x4S(ma) => "v128.load16x4_s\{render_memarg(ma)}"
    V128Load16x4U(ma) => "v128.load16x4_u\{render_memarg(ma)}"
    V128Load32x2S(ma) => "v128.load32x2_s\{render_memarg(ma)}"
    V128Load32x2U(ma) => "v128.load32x2_u\{render_memarg(ma)}"
    V128Load8Splat(ma) => "v128.load8_splat\{render_memarg(ma)}"
    V128Load16Splat(ma) => "v128.load16_splat\{render_memarg(ma)}"
    V128Load32Splat(ma) => "v128.load32_splat\{render_memarg(ma)}"
    V128Load64Splat(ma) => "v128.load64_splat\{render_memarg(ma)}"
    V128Load32Zero(ma) => "v128.load32_zero\{render_memarg(ma)}"
    V128Load64Zero(ma) => "v128.load64_zero\{render_memarg(ma)}"
    V128Store(ma) => "v128.store\{render_memarg(ma)}"
    V128Load8Lane(ma, lane) => "v128.load8_lane\{render_memarg(ma)} \{lane}"
    V128Load16Lane(ma, lane) => "v128.load16_lane\{render_memarg(ma)} \{lane}"
    V128Load32Lane(ma, lane) => "v128.load32_lane\{render_memarg(ma)} \{lane}"
    V128Load64Lane(ma, lane) => "v128.load64_lane\{render_memarg(ma)} \{lane}"
    V128Store8Lane(ma, lane) => "v128.store8_lane\{render_memarg(ma)} \{lane}"
    V128Store16Lane(ma, lane) => "v128.store16_lane\{render_memarg(ma)} \{lane}"
    V128Store32Lane(ma, lane) => "v128.store32_lane\{render_memarg(ma)} \{lane}"
    V128Store64Lane(ma, lane) => "v128.store64_lane\{render_memarg(ma)} \{lane}"
    I8x16Shuffle(lanes) => "i8x16.shuffle \{render_shuffle_lanes(lanes)}"
    I8x16Swizzle => "i8x16.swizzle"
    I8x16Splat => "i8x16.splat"
    I16x8Splat => "i16x8.splat"
    I32x4Splat => "i32x4.splat"
    I64x2Splat => "i64x2.splat"
    F32x4Splat => "f32x4.splat"
    F64x2Splat => "f64x2.splat"
    I8x16ExtractLaneS(lane) => "i8x16.extract_lane_s \{lane}"
    I8x16ExtractLaneU(lane) => "i8x16.extract_lane_u \{lane}"
    I8x16ReplaceLane(lane) => "i8x16.replace_lane \{lane}"
    I16x8ExtractLaneS(lane) => "i16x8.extract_lane_s \{lane}"
    I16x8ExtractLaneU(lane) => "i16x8.extract_lane_u \{lane}"
    I16x8ReplaceLane(lane) => "i16x8.replace_lane \{lane}"
    I32x4ExtractLane(lane) => "i32x4.extract_lane \{lane}"
    I32x4ReplaceLane(lane) => "i32x4.replace_lane \{lane}"
    I64x2ExtractLane(lane) => "i64x2.extract_lane \{lane}"
    I64x2ReplaceLane(lane) => "i64x2.replace_lane \{lane}"
    F32x4ExtractLane(lane) => "f32x4.extract_lane \{lane}"
    F32x4ReplaceLane(lane) => "f32x4.replace_lane \{lane}"
    F64x2ExtractLane(lane) => "f64x2.extract_lane \{lane}"
    F64x2ReplaceLane(lane) => "f64x2.replace_lane \{lane}"
    SimdUnary(op) => keyword_from_opcode(op)
    SimdBinary(op) => keyword_from_opcode(op)
    SimdTernary(op) => keyword_from_opcode(op)
    SimdShift(op) => keyword_from_opcode(op)
    SimdTest(op) => keyword_from_opcode(op)
    SimdCompare(op) => keyword_from_opcode(op)
    SimdConvert(op) => keyword_from_opcode(op)
    SimdRelaxed(op) => keyword_from_opcode(op)
    Block(_, _) | Loop(_, _) | If(_, _, _) =>
      raise Unsupported(
        "structured instructions must be rendered with body context",
      )
  }
}

///|
fn write_instruction(
  out : StringBuilder,
  instr : Instruction,
  indent : Int,
) -> Unit raise WastTextError {
  let pad = " ".repeat(indent)
  match instr {
    Block(bt, body) => {
      out.write_string("\{pad}block\{render_block_type(bt)}\n")
      write_instructions(out, body, indent + 2)
      out.write_string("\{pad}end\n")
    }
    Loop(bt, body) => {
      out.write_string("\{pad}loop\{render_block_type(bt)}\n")
      write_instructions(out, body, indent + 2)
      out.write_string("\{pad}end\n")
    }
    If(bt, then_body, else_body) => {
      out.write_string("\{pad}if\{render_block_type(bt)}\n")
      write_instructions(out, then_body, indent + 2)
      if else_body.length() > 0 {
        out.write_string("\{pad}else\n")
        write_instructions(out, else_body, indent + 2)
      }
      out.write_string("\{pad}end\n")
    }
    _ => {
      out.write_string(pad)
      out.write_string(render_instruction_head(instr))
      out.write_char('\n')
    }
  }
}

///|
fn write_instructions(
  out : StringBuilder,
  instrs : Array[Instruction],
  indent : Int,
) -> Unit raise WastTextError {
  for instr in instrs {
    write_instruction(out, instr, indent)
  }
}

///|
fn write_inline_exports(
  out : StringBuilder,
  exports : Array[InlineExport],
) -> Unit {
  for ex in exports {
    match ex {
      Export(name) => out.write_string(" (export \{quote_wast_string(name)})")
    }
  }
}

///|
fn write_module_field(
  out : StringBuilder,
  field : ModuleField,
  indent : Int,
) -> Unit raise WastTextError {
  let pad = " ".repeat(indent)
  match field {
    TypeField(td) => {
      out.write_string("\{pad}(type")
      if td.id is Some(id) {
        out.write_char(' ')
        out.write_string(id)
      }
      out.write_string(" (func")
      let tu = { type_index: None, func_type: td.func_type }
      out.write_string(render_type_use(tu))
      out.write_string("))\n")
    }
    FuncField(func) => {
      out.write_string("\{pad}(func")
      if func.id is Some(id) {
        out.write_char(' ')
        out.write_string(id)
      }
      write_inline_exports(out, func.exports)
      out.write_string(render_type_use(func.type_use))
      for loc in func.locals {
        out.write_string(" (local")
        if loc.id is Some(id) {
          out.write_char(' ')
          out.write_string(id)
        }
        out.write_char(' ')
        out.write_string(keyword_from_value_type(loc.val_type))
        out.write_char(')')
      }
      out.write_char('\n')
      write_instructions(out, func.body, indent + 2)
      out.write_string("\{pad})\n")
    }
    TableField(tbl) => {
      out.write_string("\{pad}(table")
      if tbl.id is Some(id) {
        out.write_char(' ')
        out.write_string(id)
      }
      write_inline_exports(out, tbl.exports)
      out.write_string(" \{tbl.table_type.limits.min}")
      if tbl.table_type.limits.max is Some(max) {
        out.write_string(" \{max}")
      }
      out.write_string(
        " \{keyword_from_value_type(tbl.table_type.elem_type)})\n",
      )
    }
    MemoryField(mem) => {
      out.write_string("\{pad}(memory")
      if mem.id is Some(id) {
        out.write_char(' ')
        out.write_string(id)
      }
      write_inline_exports(out, mem.exports)
      let lim = mem.memory_type.0
      out.write_string(" \{lim.min}")
      if lim.max is Some(max) {
        out.write_string(" \{max}")
      }
      out.write_string(")\n")
    }
    GlobalField(global) => {
      out.write_string("\{pad}(global")
      if global.id is Some(id) {
        out.write_char(' ')
        out.write_string(id)
      }
      write_inline_exports(out, global.exports)
      if global.global_type.mutable_ {
        out.write_string(
          " (mut \{keyword_from_value_type(global.global_type.val_type)})",
        )
      } else {
        out.write_string(
          " \{keyword_from_value_type(global.global_type.val_type)}",
        )
      }
      out.write_char('\n')
      write_instructions(out, global.init, indent + 2)
      out.write_string("\{pad})\n")
    }
    ImportField(im) => {
      out.write_string(
        "\{pad}(import \{quote_wast_string(im.module_name)} \{quote_wast_string(im.field_name)} (",
      )
      match im.desc {
        Func(type_use) => {
          out.write_string("func")
          if im.id is Some(id) {
            out.write_char(' ')
            out.write_string(id)
          }
          out.write_string(render_type_use(type_use))
        }
        Table(tt) => {
          out.write_string("table")
          if im.id is Some(id) {
            out.write_char(' ')
            out.write_string(id)
          }
          out.write_string(" \{tt.limits.min}")
          if tt.limits.max is Some(max) {
            out.write_string(" \{max}")
          }
          out.write_string(" \{keyword_from_value_type(tt.elem_type)}")
        }
        Memory(mt) => {
          out.write_string("memory")
          if im.id is Some(id) {
            out.write_char(' ')
            out.write_string(id)
          }
          let lim = mt.0
          out.write_string(" \{lim.min}")
          if lim.max is Some(max) {
            out.write_string(" \{max}")
          }
        }
        Global(gt) => {
          out.write_string("global")
          if im.id is Some(id) {
            out.write_char(' ')
            out.write_string(id)
          }
          if gt.mutable_ {
            out.write_string(" (mut \{keyword_from_value_type(gt.val_type)})")
          } else {
            out.write_string(" \{keyword_from_value_type(gt.val_type)}")
          }
        }
      }
      out.write_string("))\n")
    }
    ExportField(ex) => {
      out.write_string("\{pad}(export \{quote_wast_string(ex.name)} (")
      match ex.desc {
        Func(idx) => out.write_string("func \{index_text(idx)}")
        Table(idx) => out.write_string("table \{index_text(idx)}")
        Memory(idx) => out.write_string("memory \{index_text(idx)}")
        Global(idx) => out.write_string("global \{index_text(idx)}")
      }
      out.write_string("))\n")
    }
    StartField(start) =>
      out.write_string("\{pad}(start \{index_text(start.func_index)})\n")
    ElemField(elem) => {
      out.write_string("\{pad}(elem")
      if elem.id is Some(id) {
        out.write_char(' ')
        out.write_string(id)
      }
      out.write_char(' ')
      out.write_string(index_text(elem.table_index))
      if elem.offset.length() > 0 {
        out.write_string(" (offset\n")
        write_instructions(out, elem.offset, indent + 4)
        out.write_string("\{pad}  )")
      }
      for idx in elem.func_indices {
        out.write_char(' ')
        out.write_string(index_text(idx))
      }
      out.write_string(")\n")
    }
    DataField(data) => {
      out.write_string("\{pad}(data")
      if data.id is Some(id) {
        out.write_char(' ')
        out.write_string(id)
      }
      out.write_char(' ')
      out.write_string(index_text(data.memory_index))
      if data.offset.length() > 0 {
        out.write_string(" (offset\n")
        write_instructions(out, data.offset, indent + 4)
        out.write_string("\{pad}  )")
      }
      out.write_char(' ')
      out.write_string(quote_wast_bytes(data.data))
      out.write_string(")\n")
    }
  }
}

///|
fn render_module(mod : Module) -> String raise WastTextError {
  let out = StringBuilder::new()
  out.write_string("(module")
  if mod.id is Some(id) {
    out.write_char(' ')
    out.write_string(id)
  }
  out.write_char('\n')
  for field in mod.fields {
    write_module_field(out, field, 2)
  }
  out.write_string(")\n")
  out.to_string()
}

///|
fn render_wast_value(v : WastValue) -> String {
  match v {
    I32(x) => "(i32.const \{x})"
    I64(x) => "(i64.const \{x})"
    F32(x) => "(f32.const \{x})"
    F64(x) => "(f64.const \{x})"
    RefNull(vt) => "(ref.null \{keyword_from_value_type(vt)})"
    RefFunc => "(ref.func 0)"
  }
}

///|
fn render_wast_result(r : WastResult) -> String {
  match r {
    Value(v) => render_wast_value(v)
    F32NanCanonical => "(f32.const nan:canonical)"
    F32NanArithmetic => "(f32.const nan:arithmetic)"
    F64NanCanonical => "(f64.const nan:canonical)"
    F64NanArithmetic => "(f64.const nan:arithmetic)"
    RefNull(None) => "(ref.null)"
    RefNull(Some(vt)) => "(ref.null \{keyword_from_value_type(vt)})"
    RefFunc => "(ref.func 0)"
  }
}

///|
fn render_action(a : WastActionType) -> String {
  match a {
    Invoke(act) => {
      let out = StringBuilder::new()
      out.write_string("(invoke")
      if act.module_name is Some(m) {
        out.write_char(' ')
        out.write_string(m)
      }
      out.write_char(' ')
      out.write_string(quote_wast_string(act.name))
      for arg in act.args {
        out.write_char(' ')
        out.write_string(render_wast_value(arg))
      }
      out.write_char(')')
      out.to_string()
    }
    Get(module_name, global_name) => {
      let out = StringBuilder::new()
      out.write_string("(get")
      if module_name is Some(m) {
        out.write_char(' ')
        out.write_string(m)
      }
      out.write_char(' ')
      out.write_string(quote_wast_string(global_name))
      out.write_char(')')
      out.to_string()
    }
  }
}

///|
fn render_command(cmd : WastCommand) -> String raise WastTextError {
  match cmd {
    Module(mod) => render_module(mod)
    ModuleBinary(id, bytes) => {
      let out = StringBuilder::new()
      out.write_string("(module")
      if id is Some(x) {
        out.write_char(' ')
        out.write_string(x)
      }
      out.write_string(" binary ")
      out.write_string(quote_wast_bytes(bytes))
      out.write_string(")\n")
      out.to_string()
    }
    ModuleQuote(id, strings) => {
      let out = StringBuilder::new()
      out.write_string("(module")
      if id is Some(x) {
        out.write_char(' ')
        out.write_string(x)
      }
      out.write_string(" quote")
      for s in strings {
        out.write_char(' ')
        out.write_string(quote_wast_string(s))
      }
      out.write_string(")\n")
      out.to_string()
    }
    Register(name, module_id) => {
      let out = StringBuilder::new()
      out.write_string("(register ")
      out.write_string(quote_wast_string(name))
      if module_id is Some(id) {
        out.write_char(' ')
        out.write_string(id)
      }
      out.write_string(")\n")
      out.to_string()
    }
    Action(action) => "\{render_action(action)}\n"
    AssertReturn(action, results) => {
      let out = StringBuilder::new()
      out.write_string("(assert_return ")
      out.write_string(render_action(action))
      for r in results {
        out.write_char(' ')
        out.write_string(render_wast_result(r))
      }
      out.write_string(")\n")
      out.to_string()
    }
    AssertTrap(action, msg) =>
      "(assert_trap \{render_action(action)} \{quote_wast_string(msg)})\n"
    AssertExhaustion(action, msg) =>
      "(assert_exhaustion \{render_action(action)} \{quote_wast_string(msg)})\n"
    AssertMalformed(mod_def, msg) =>
      "(assert_malformed \{render_module_def(mod_def)} \{quote_wast_string(msg)})\n"
    AssertInvalid(mod_def, msg) =>
      "(assert_invalid \{render_module_def(mod_def)} \{quote_wast_string(msg)})\n"
    AssertUnlinkable(mod_def, msg) =>
      "(assert_unlinkable \{render_module_def(mod_def)} \{quote_wast_string(msg)})\n"
  }
}

///|
fn render_module_def(mod_def : WastModuleDef) -> String raise WastTextError {
  match mod_def {
    Inline(mod) => render_module(mod).trim().to_string()
    Binary(bytes) => "(module binary \{quote_wast_bytes(bytes)})"
    Quote(lines) => {
      let out = StringBuilder::new()
      out.write_string("(module quote")
      for line in lines {
        out.write_char(' ')
        out.write_string(quote_wast_string(line))
      }
      out.write_char(')')
      out.to_string()
    }
  }
}

///|
fn render_script(script : WastScript) -> String raise WastTextError {
  let out = StringBuilder::new()
  for cmd in script.commands {
    out.write_string(render_command(cmd))
  }
  out.to_string()
}

///|
pub fn module_to_wast(mod : Module) -> Result[String, String] {
  Result::Ok(render_module(mod)) catch {
    WastTextError::Unsupported(msg) => Err(msg)
  }
}

///|
pub fn script_to_wast(script : WastScript) -> Result[String, String] {
  Result::Ok(render_script(script)) catch {
    WastTextError::Unsupported(msg) => Err(msg)
  }
}

///|
pub fn wast_to_module(
  source : String,
  filename? : String = "<memory>",
) -> Result[Module, String] {
  let lexer = WastLexer::new(string_to_bytes_for_parser(source), filename)
  let parser = WastParser::new(lexer)
  Result::Ok(parser.parse_module()) catch {
    ParserError::UnexpectedToken(tok, msg) =>
      Err("\{msg} at \{tok.location.filename}:\{tok.location.line}")
    ParserError::InvalidInstruction(msg) => Err(msg)
    ParserError::Custom(msg) => Err(msg)
  }
}

///|
pub fn wast_to_script(
  source : String,
  filename? : String = "<memory>",
) -> Result[WastScript, String] {
  let lexer = WastLexer::new(string_to_bytes_for_parser(source), filename)
  let parser = WastParser::new(lexer)
  Result::Ok(parser.parse_script()) catch {
    ParserError::UnexpectedToken(tok, msg) =>
      Err("\{msg} at \{tok.location.filename}:\{tok.location.line}")
    ParserError::InvalidInstruction(msg) => Err(msg)
    ParserError::Custom(msg) => Err(msg)
  }
}
