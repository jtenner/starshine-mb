///|
pub fn lookup_keyword(text : String) -> TokenType? {
  @wast.lookup_keyword(text)
}

///|
pub fn wat_to_module(
  source : String,
  filename? : String = "<input>",
) -> Result[Module, String] {
  @wast.wast_to_module(source, filename~)
}

///|
pub fn module_to_wat(mod : Module) -> Result[String, String] {
  @wast.module_to_wast(mod)
}

///|
fn lib_val_type_to_wat(vt : @lib.ValType) -> Result[String, String] {
  match vt {
    @lib.NumTypeValType(@lib.I32NumType) => Ok("i32")
    @lib.NumTypeValType(@lib.I64NumType) => Ok("i64")
    @lib.NumTypeValType(@lib.F32NumType) => Ok("f32")
    @lib.NumTypeValType(@lib.F64NumType) => Ok("f64")
    @lib.VecTypeValType => Ok("v128")
    @lib.RefTypeValType(@lib.AbsHeapTypeRefType(@lib.FuncAbsHeapType)) =>
      Ok("funcref")
    @lib.RefTypeValType(@lib.AbsHeapTypeRefType(@lib.ExternAbsHeapType)) =>
      Ok("externref")
    @lib.RefTypeValType(_) =>
      Err("lib_module_to_wat does not yet print typed reference values")
    @lib.BotValType => Err("lib_module_to_wat cannot print bottom value type")
  }
}

///|
fn lib_func_type_to_wat(
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> Result[String, String] {
  let out = StringBuilder::new()
  out.write_string("(func")
  if params.length() > 0 {
    out.write_string(" (param")
    for param in params {
      out.write_char(' ')
      match lib_val_type_to_wat(param) {
        Ok(text) => out.write_string(text)
        Err(e) => return Err(e)
      }
    }
    out.write_char(')')
  }
  if results.length() > 0 {
    out.write_string(" (result")
    for result in results {
      out.write_char(' ')
      match lib_val_type_to_wat(result) {
        Ok(text) => out.write_string(text)
        Err(e) => return Err(e)
      }
    }
    out.write_char(')')
  }
  out.write_char(')')
  Ok(out.to_string())
}

///|
fn lib_subtype_to_wat(subtype : @lib.SubType) -> Result[String, String] {
  match subtype {
    @lib.SubType(_, supers, metadata, @lib.FuncCompType(params, results)) => {
      if supers.length() > 0 ||
        metadata.describes is Some(_) ||
        metadata.descriptor is Some(_) {
        return Err("lib_module_to_wat does not yet print subtype metadata")
      }
      lib_func_type_to_wat(params, results)
    }
    @lib.CompTypeSubType(metadata, @lib.FuncCompType(params, results)) => {
      if metadata.describes is Some(_) || metadata.descriptor is Some(_) {
        return Err("lib_module_to_wat does not yet print subtype metadata")
      }
      lib_func_type_to_wat(params, results)
    }
    _ => Err("lib_module_to_wat currently supports function types only")
  }
}

///|
fn lib_rec_type_to_wat_fields(
  rec_type : @lib.RecType,
) -> Result[Array[String], String] {
  match rec_type {
    @lib.SingleRecType(subtype) =>
      match lib_subtype_to_wat(subtype) {
        Ok(text) => Ok([text])
        Err(e) => Err(e)
      }
    @lib.GroupRecType(subtypes) => {
      let fields : Array[String] = []
      for subtype in subtypes {
        match lib_subtype_to_wat(subtype) {
          Ok(text) => fields.push(text)
          Err(e) => return Err(e)
        }
      }
      Ok(fields)
    }
  }
}

///|
fn lib_module_has_unsupported_sections(mod : @lib.Module) -> Bool {
  if mod.custom_secs.length() > 0 ||
    mod.name_sec is Some(_) ||
    mod.raw_name_sec_payload is Some(_) ||
    mod.func_annotation_sec is Some(_) ||
    mod.start_sec is Some(_) ||
    mod.data_cnt_sec is Some(_) {
    return true
  }
  match mod.import_sec {
    Some(@lib.ImportSec(items)) => if items.length() > 0 { return true }
    None => ()
  }
  match mod.table_sec {
    Some(@lib.TableSec(items)) => if items.length() > 0 { return true }
    None => ()
  }
  match mod.mem_sec {
    Some(@lib.MemSec(items)) => if items.length() > 0 { return true }
    None => ()
  }
  match mod.tag_sec {
    Some(@lib.TagSec(items)) => if items.length() > 0 { return true }
    None => ()
  }
  match mod.stringrefs_sec {
    Some(@lib.StringRefsSec(items)) => if items.length() > 0 { return true }
    None => ()
  }
  match mod.global_sec {
    Some(@lib.GlobalSec(items)) => if items.length() > 0 { return true }
    None => ()
  }
  match mod.elem_sec {
    Some(@lib.ElemSec(items)) => if items.length() > 0 { return true }
    None => ()
  }
  match mod.data_sec {
    Some(@lib.DataSec(items)) => if items.length() > 0 { return true }
    None => ()
  }
  false
}

///|
fn lib_type_idx_to_uint(idx : @lib.TypeIdx) -> Result[UInt, String] {
  match idx {
    @lib.TypeIdx(raw) => Ok(raw)
    @lib.RecIdx(_) =>
      Err("lib_module_to_wat does not yet print rec-index type uses")
  }
}

///|
fn lib_func_idx_to_uint(idx : @lib.FuncIdx) -> UInt {
  let @lib.FuncIdx(raw) = idx
  raw
}

///|
fn lib_local_idx_to_uint(idx : @lib.LocalIdx) -> UInt {
  let @lib.LocalIdx(raw) = idx
  raw
}

///|
fn lib_label_idx_to_uint(idx : @lib.LabelIdx) -> UInt {
  let @lib.LabelIdx(raw) = idx
  raw
}

///|
fn lib_block_type_suffix(bt : @lib.BlockType) -> Result[String, String] {
  match bt {
    @lib.VoidBlockType => Ok("")
    @lib.ValTypeBlockType(vt) =>
      match lib_val_type_to_wat(vt) {
        Ok(text) => Ok(" (result \{text})")
        Err(e) => Err(e)
      }
    @lib.TypeIdxBlockType(idx) =>
      match lib_type_idx_to_uint(idx) {
        Ok(raw) => Ok(" (type \{raw})")
        Err(e) => Err(e)
      }
  }
}

///|
fn lib_expr_instrs_to_wat(
  instrs : Array[@lib.Instruction],
) -> Result[String, String] {
  let out = StringBuilder::new()
  let mut first = true
  for instr in instrs {
    match lib_instruction_to_wat(instr) {
      Ok(text) => {
        if first {
          first = false
        } else {
          out.write_char(' ')
        }
        if text.length() > 0 && text[0] == '(' {
          out.write_string(text)
        } else {
          out.write_char('(')
          out.write_string(text)
          out.write_char(')')
        }
      }
      Err(e) => return Err(e)
    }
  }
  Ok(out.to_string())
}

///|
fn lib_instruction_to_wat(instr : @lib.Instruction) -> Result[String, String] {
  match instr {
    @lib.Nop => Ok("nop")
    @lib.Unreachable => Ok("unreachable")
    @lib.Drop => Ok("drop")
    @lib.Return => Ok("return")
    @lib.Block(bt, @lib.Expr(body)) => {
      let suffix = match lib_block_type_suffix(bt) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let body_text = match lib_expr_instrs_to_wat(body) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let body_suffix = if body_text.length() > 0 {
        " \{body_text}"
      } else {
        ""
      }
      Ok("(block\{suffix}\{body_suffix})")
    }
    @lib.Loop(bt, @lib.Expr(body)) => {
      let suffix = match lib_block_type_suffix(bt) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let body_text = match lib_expr_instrs_to_wat(body) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let body_suffix = if body_text.length() > 0 {
        " \{body_text}"
      } else {
        ""
      }
      Ok("(loop\{suffix}\{body_suffix})")
    }
    @lib.If(bt, then_body, else_body) => {
      let suffix = match lib_block_type_suffix(bt) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let then_text = match lib_expr_instrs_to_wat(then_body) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let else_text = match else_body {
        Some(body) =>
          match lib_expr_instrs_to_wat(body) {
            Ok(v) => " (else \{v})"
            Err(e) => return Err(e)
          }
        None => ""
      }
      Ok("(if\{suffix} (then \{then_text})\{else_text})")
    }
    @lib.Br(idx) => Ok("(br \{lib_label_idx_to_uint(idx)})")
    @lib.BrIf(idx) => Ok("(br_if \{lib_label_idx_to_uint(idx)})")
    @lib.BrTable(labels, default_) => {
      let out = StringBuilder::new()
      out.write_string("(br_table")
      for label in labels {
        out.write_string(" \{lib_label_idx_to_uint(label)}")
      }
      out.write_string(" \{lib_label_idx_to_uint(default_)})")
      Ok(out.to_string())
    }
    @lib.LocalGet(idx) => Ok("(local.get \{lib_local_idx_to_uint(idx)})")
    @lib.LocalSet(idx) => Ok("(local.set \{lib_local_idx_to_uint(idx)})")
    @lib.LocalTee(idx) => Ok("(local.tee \{lib_local_idx_to_uint(idx)})")
    @lib.I32Const(@lib.I32(v)) => Ok("(i32.const \{v})")
    @lib.I64Const(@lib.I64(v)) => Ok("(i64.const \{v})")
    @lib.F32Const(@lib.F32(v)) => Ok("(f32.const \{v})")
    @lib.F64Const(@lib.F64(v)) => Ok("(f64.const \{v})")
    @lib.I32Eqz => Ok("i32.eqz")
    @lib.I32Eq => Ok("i32.eq")
    @lib.I32Ne => Ok("i32.ne")
    @lib.I32LtS => Ok("i32.lt_s")
    @lib.I32LtU => Ok("i32.lt_u")
    @lib.I32GtS => Ok("i32.gt_s")
    @lib.I32GtU => Ok("i32.gt_u")
    @lib.I32LeS => Ok("i32.le_s")
    @lib.I32LeU => Ok("i32.le_u")
    @lib.I32GeS => Ok("i32.ge_s")
    @lib.I32GeU => Ok("i32.ge_u")
    @lib.I64Eqz => Ok("i64.eqz")
    @lib.I64Eq => Ok("i64.eq")
    @lib.I64Ne => Ok("i64.ne")
    @lib.I64LtS => Ok("i64.lt_s")
    @lib.I64LtU => Ok("i64.lt_u")
    @lib.I64GtS => Ok("i64.gt_s")
    @lib.I64GtU => Ok("i64.gt_u")
    @lib.I64LeS => Ok("i64.le_s")
    @lib.I64LeU => Ok("i64.le_u")
    @lib.I64GeS => Ok("i64.ge_s")
    @lib.I64GeU => Ok("i64.ge_u")
    @lib.F32Eq => Ok("f32.eq")
    @lib.F32Ne => Ok("f32.ne")
    @lib.F32Lt => Ok("f32.lt")
    @lib.F32Gt => Ok("f32.gt")
    @lib.F32Le => Ok("f32.le")
    @lib.F32Ge => Ok("f32.ge")
    @lib.F64Eq => Ok("f64.eq")
    @lib.F64Ne => Ok("f64.ne")
    @lib.F64Lt => Ok("f64.lt")
    @lib.F64Gt => Ok("f64.gt")
    @lib.F64Le => Ok("f64.le")
    @lib.F64Ge => Ok("f64.ge")
    @lib.I32Clz => Ok("i32.clz")
    @lib.I32Ctz => Ok("i32.ctz")
    @lib.I32Popcnt => Ok("i32.popcnt")
    @lib.I32Add => Ok("i32.add")
    @lib.I32Sub => Ok("i32.sub")
    @lib.I32Mul => Ok("i32.mul")
    @lib.I32DivS => Ok("i32.div_s")
    @lib.I32DivU => Ok("i32.div_u")
    @lib.I32RemS => Ok("i32.rem_s")
    @lib.I32RemU => Ok("i32.rem_u")
    @lib.I32And => Ok("i32.and")
    @lib.I32Or => Ok("i32.or")
    @lib.I32Xor => Ok("i32.xor")
    @lib.I32Shl => Ok("i32.shl")
    @lib.I32ShrS => Ok("i32.shr_s")
    @lib.I32ShrU => Ok("i32.shr_u")
    @lib.I32Rotl => Ok("i32.rotl")
    @lib.I32Rotr => Ok("i32.rotr")
    @lib.I64Clz => Ok("i64.clz")
    @lib.I64Ctz => Ok("i64.ctz")
    @lib.I64Popcnt => Ok("i64.popcnt")
    @lib.I64Add => Ok("i64.add")
    @lib.I64Sub => Ok("i64.sub")
    @lib.I64Mul => Ok("i64.mul")
    @lib.I64DivS => Ok("i64.div_s")
    @lib.I64DivU => Ok("i64.div_u")
    @lib.I64RemS => Ok("i64.rem_s")
    @lib.I64RemU => Ok("i64.rem_u")
    @lib.I64And => Ok("i64.and")
    @lib.I64Or => Ok("i64.or")
    @lib.I64Xor => Ok("i64.xor")
    @lib.I64Shl => Ok("i64.shl")
    @lib.I64ShrS => Ok("i64.shr_s")
    @lib.I64ShrU => Ok("i64.shr_u")
    @lib.I64Rotl => Ok("i64.rotl")
    @lib.I64Rotr => Ok("i64.rotr")
    @lib.F32Abs => Ok("f32.abs")
    @lib.F32Neg => Ok("f32.neg")
    @lib.F32Ceil => Ok("f32.ceil")
    @lib.F32Floor => Ok("f32.floor")
    @lib.F32Trunc => Ok("f32.trunc")
    @lib.F32Nearest => Ok("f32.nearest")
    @lib.F32Sqrt => Ok("f32.sqrt")
    @lib.F32Add => Ok("f32.add")
    @lib.F32Sub => Ok("f32.sub")
    @lib.F32Mul => Ok("f32.mul")
    @lib.F32Div => Ok("f32.div")
    @lib.F32Min => Ok("f32.min")
    @lib.F32Max => Ok("f32.max")
    @lib.F32Copysign => Ok("f32.copysign")
    @lib.F64Abs => Ok("f64.abs")
    @lib.F64Neg => Ok("f64.neg")
    @lib.F64Ceil => Ok("f64.ceil")
    @lib.F64Floor => Ok("f64.floor")
    @lib.F64Trunc => Ok("f64.trunc")
    @lib.F64Nearest => Ok("f64.nearest")
    @lib.F64Sqrt => Ok("f64.sqrt")
    @lib.F64Add => Ok("f64.add")
    @lib.F64Sub => Ok("f64.sub")
    @lib.F64Mul => Ok("f64.mul")
    @lib.F64Div => Ok("f64.div")
    @lib.F64Min => Ok("f64.min")
    @lib.F64Max => Ok("f64.max")
    @lib.F64Copysign => Ok("f64.copysign")
    @lib.I32WrapI64 => Ok("i32.wrap_i64")
    @lib.I32TruncF32S => Ok("i32.trunc_f32_s")
    @lib.I32TruncF32U => Ok("i32.trunc_f32_u")
    @lib.I32TruncF64S => Ok("i32.trunc_f64_s")
    @lib.I32TruncF64U => Ok("i32.trunc_f64_u")
    @lib.I64ExtendI32S => Ok("i64.extend_i32_s")
    @lib.I64ExtendI32U => Ok("i64.extend_i32_u")
    @lib.I64TruncF32S => Ok("i64.trunc_f32_s")
    @lib.I64TruncF32U => Ok("i64.trunc_f32_u")
    @lib.I64TruncF64S => Ok("i64.trunc_f64_s")
    @lib.I64TruncF64U => Ok("i64.trunc_f64_u")
    @lib.F32ConvertI32S => Ok("f32.convert_i32_s")
    @lib.F32ConvertI32U => Ok("f32.convert_i32_u")
    @lib.F32ConvertI64S => Ok("f32.convert_i64_s")
    @lib.F32ConvertI64U => Ok("f32.convert_i64_u")
    @lib.F32DemoteF64 => Ok("f32.demote_f64")
    @lib.F64ConvertI32S => Ok("f64.convert_i32_s")
    @lib.F64ConvertI32U => Ok("f64.convert_i32_u")
    @lib.F64ConvertI64S => Ok("f64.convert_i64_s")
    @lib.F64ConvertI64U => Ok("f64.convert_i64_u")
    @lib.F64PromoteF32 => Ok("f64.promote_f32")
    @lib.I32ReinterpretF32 => Ok("i32.reinterpret_f32")
    @lib.I64ReinterpretF64 => Ok("i64.reinterpret_f64")
    @lib.F32ReinterpretI32 => Ok("f32.reinterpret_i32")
    @lib.F64ReinterpretI64 => Ok("f64.reinterpret_i64")
    @lib.I32Extend8S => Ok("i32.extend8_s")
    @lib.I32Extend16S => Ok("i32.extend16_s")
    @lib.I64Extend8S => Ok("i64.extend8_s")
    @lib.I64Extend16S => Ok("i64.extend16_s")
    @lib.I64Extend32S => Ok("i64.extend32_s")
    @lib.I32TruncSatF32S => Ok("i32.trunc_sat_f32_s")
    @lib.I32TruncSatF32U => Ok("i32.trunc_sat_f32_u")
    @lib.I32TruncSatF64S => Ok("i32.trunc_sat_f64_s")
    @lib.I32TruncSatF64U => Ok("i32.trunc_sat_f64_u")
    @lib.I64TruncSatF32S => Ok("i64.trunc_sat_f32_s")
    @lib.I64TruncSatF32U => Ok("i64.trunc_sat_f32_u")
    @lib.I64TruncSatF64S => Ok("i64.trunc_sat_f64_s")
    @lib.I64TruncSatF64U => Ok("i64.trunc_sat_f64_u")
    _ => Err("lib_module_to_wat does not yet print instruction: \{instr}")
  }
}

///|
fn lib_func_to_wat(
  type_idx : @lib.TypeIdx,
  func : @lib.Func,
) -> Result[String, String] {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  let local_runs = locals.runs()
  let raw_type_idx = match lib_type_idx_to_uint(type_idx) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let out = StringBuilder::new()
  out.write_string("(func (type \{raw_type_idx})")
  for run in local_runs {
    out.write_string(" (local")
    let local_type = match lib_val_type_to_wat(run.vt) {
      Ok(text) => text
      Err(e) => return Err(e)
    }
    let mut remaining = run.count
    while remaining > 0 {
      out.write_char(' ')
      out.write_string(local_type)
      remaining = remaining - 1
    }
    out.write_char(')')
  }
  match lib_expr_instrs_to_wat(instrs) {
    Ok(body_text) =>
      if body_text.length() > 0 {
        out.write_char(' ')
        out.write_string(body_text)
      }
    Err(e) => return Err(e)
  }
  out.write_char(')')
  Ok(out.to_string())
}

///|
fn lib_name_to_wat(name : @lib.Name) -> String {
  let @lib.Name(raw) = name
  let out = StringBuilder::new()
  out.write_char('"')
  for c in raw.to_owned() {
    if c == '"' || c == '\\' {
      out.write_char('\\')
    }
    out.write_char(c)
  }
  out.write_char('"')
  out.to_string()
}

///|
fn lib_export_to_wat(export_ : @lib.Export) -> Result[String, String] {
  let @lib.Export(name, idx) = export_
  match idx {
    @lib.FuncExternIdx(func_idx) =>
      Ok(
        "(export \{lib_name_to_wat(name)} (func \{lib_func_idx_to_uint(func_idx)}))",
      )
    _ => Err("lib_module_to_wat does not yet print non-function exports")
  }
}

///|
pub fn lib_module_to_wat(mod : @lib.Module) -> Result[String, String] {
  if lib_module_has_unsupported_sections(mod) {
    return Err(
      "lib_module_to_wat currently supports type/function/export-only lib modules",
    )
  }
  let out = StringBuilder::new()
  out.write_string("(module")
  match mod.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match lib_rec_type_to_wat_fields(rec_type) {
          Ok(fields) =>
            for field in fields {
              out.write_string("\n  (type ")
              out.write_string(field)
              out.write_char(')')
            }
          Err(e) => return Err(e)
        }
      }
    None => ()
  }
  match (mod.func_sec, mod.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) => {
      if type_idxs.length() != funcs.length() {
        return Err("lib_module_to_wat func/code length mismatch")
      }
      for i = 0; i < funcs.length(); i = i + 1 {
        match lib_func_to_wat(type_idxs[i], funcs[i]) {
          Ok(text) => {
            out.write_string("\n  ")
            out.write_string(text)
          }
          Err(e) => return Err(e)
        }
      }
    }
    (None, None) => ()
    (Some(@lib.FuncSec([])), None) => ()
    (None, Some(@lib.CodeSec([]))) => ()
    _ =>
      return Err("lib_module_to_wat requires func and code sections together")
  }
  match mod.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match lib_export_to_wat(export_) {
          Ok(text) => {
            out.write_string("\n  ")
            out.write_string(text)
          }
          Err(e) => return Err(e)
        }
      }
    None => ()
  }
  out.write_string("\n)")
  Ok(out.to_string())
}

///|
pub fn module_to_wat_with_context(
  mod : Module,
  ctx : PrettyPrintContext,
) -> Result[String, String] {
  @wast.module_to_wast_with_context(mod, ctx)
}

///|
pub fn wat_to_script(
  source : String,
  filename? : String = "<input>",
) -> Result[WastScript, String] {
  @wast.wast_to_script(source, filename~)
}

///|
pub fn script_to_wat(script : WastScript) -> Result[String, String] {
  @wast.script_to_wast(script)
}

///|
pub fn script_to_wat_with_context(
  script : WastScript,
  ctx : PrettyPrintContext,
) -> Result[String, String] {
  @wast.script_to_wast_with_context(script, ctx)
}
