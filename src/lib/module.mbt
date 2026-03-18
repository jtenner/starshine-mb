///|
pub fn Module::with_custom_secs(
  self : Module,
  custom_secs : Array[CustomSec],
) -> Module {
  Module::{ ..self, custom_secs, }
}

///|
pub fn Module::with_type_sec(self : Module, type_sec : TypeSec) -> Module {
  Module::{ ..self, type_sec: Some(type_sec) }
}

///|
pub fn Module::with_import_sec(self : Module, import_sec : ImportSec) -> Module {
  Module::{ ..self, import_sec: Some(import_sec) }
}

///|
pub fn Module::with_func_sec(self : Module, func_sec : FuncSec) -> Module {
  Module::{ ..self, func_sec: Some(func_sec) }
}

///|
pub fn Module::with_table_sec(self : Module, table_sec : TableSec) -> Module {
  Module::{ ..self, table_sec: Some(table_sec) }
}

///|
pub fn Module::with_mem_sec(self : Module, mem_sec : MemSec) -> Module {
  Module::{ ..self, mem_sec: Some(mem_sec) }
}

///|
pub fn Module::with_tag_sec(self : Module, tag_sec : TagSec) -> Module {
  Module::{ ..self, tag_sec: Some(tag_sec) }
}

///|
pub fn Module::with_global_sec(self : Module, global_sec : GlobalSec) -> Module {
  Module::{ ..self, global_sec: Some(global_sec) }
}

///|
pub fn Module::with_export_sec(self : Module, export_sec : ExportSec) -> Module {
  Module::{ ..self, export_sec: Some(export_sec) }
}

///|
pub fn Module::with_start_sec(self : Module, start_sec : StartSec) -> Module {
  Module::{ ..self, start_sec: Some(start_sec) }
}

///|
pub fn Module::with_elem_sec(self : Module, elem_sec : ElemSec) -> Module {
  Module::{ ..self, elem_sec: Some(elem_sec) }
}

///|
pub fn Module::with_data_cnt_sec(
  self : Module,
  data_cnt_sec : DataCntSec,
) -> Module {
  Module::{ ..self, data_cnt_sec: Some(data_cnt_sec) }
}

///|
pub fn Module::with_code_sec(self : Module, code_sec : CodeSec) -> Module {
  Module::{ ..self, code_sec: Some(code_sec) }
}

///|
pub fn Module::with_data_sec(self : Module, data_sec : DataSec) -> Module {
  Module::{ ..self, data_sec: Some(data_sec) }
}

///|
priv struct ModuleDebugContext {
  subtypes : Array[SubType]
  func_type_idxs : Array[TypeIdx]
  func_imports : Array[Import]
  tables : Array[TableType]
  mems : Array[MemType]
  globals : Array[GlobalType]
  tags : Array[TagType]
}

///|
fn md_build_context(mod : Module) -> ModuleDebugContext {
  let subtypes : Array[SubType] = []
  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(subtype) => subtypes.push(subtype)
          GroupRecType(group) =>
            for subtype in group {
              subtypes.push(subtype)
            }
        }
      }
    None => ()
  }

  let func_type_idxs : Array[TypeIdx] = []
  let func_imports : Array[Import] = []
  let tables : Array[TableType] = []
  let mems : Array[MemType] = []
  let globals : Array[GlobalType] = []
  let tags : Array[TagType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) => {
            func_type_idxs.push(type_idx)
            func_imports.push(import_)
          }
          Import(_, _, TableExternType(table_type)) => tables.push(table_type)
          Import(_, _, MemExternType(mem_type)) => mems.push(mem_type)
          Import(_, _, GlobalExternType(global_type)) =>
            globals.push(global_type)
          Import(_, _, TagExternType(tag_type)) => tags.push(tag_type)
        }
      }
    None => ()
  }

  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        func_type_idxs.push(type_idx)
      }
    None => ()
  }
  match mod.table_sec {
    Some(TableSec(defs)) =>
      for table in defs {
        let Table(table_type, _) = table
        tables.push(table_type)
      }
    None => ()
  }
  match mod.mem_sec {
    Some(MemSec(defs)) =>
      for mem_type in defs {
        mems.push(mem_type)
      }
    None => ()
  }
  match mod.global_sec {
    Some(GlobalSec(defs)) =>
      for global in defs {
        let Global(global_type, _) = global
        globals.push(global_type)
      }
    None => ()
  }
  match mod.tag_sec {
    Some(TagSec(defs)) =>
      for tag_type in defs {
        tags.push(tag_type)
      }
    None => ()
  }

  { subtypes, func_type_idxs, func_imports, tables, mems, globals, tags }
}

///|
fn md_resolve_subtype(ctx : ModuleDebugContext, idx : TypeIdx) -> SubType? {
  match idx {
    TypeIdx(i) => ctx.subtypes.get(i.reinterpret_as_int())
    RecIdx(_) => None
  }
}

///|
fn md_resolve_functype(ctx : ModuleDebugContext, idx : TypeIdx) -> FuncType? {
  match md_resolve_subtype(ctx, idx) {
    Some(subtype) =>
      match subtype.get_comptype() {
        FuncCompType(params, results) => Some(FuncType::new(params, results))
        _ => None
      }
    None => None
  }
}

///|
fn md_format_type_idx(ctx : ModuleDebugContext, idx : TypeIdx) -> String {
  pretty_resolved_type_idx(ctx.subtypes, idx)
}

///|
fn md_format_heap_type(
  ctx : ModuleDebugContext,
  heap_type : HeapType,
) -> String {
  match heap_type {
    HeapType(type_idx) => md_format_type_idx(ctx, type_idx)
    _ => pretty_heap_type(heap_type)
  }
}

///|
fn md_format_func_idx(ctx : ModuleDebugContext, idx : FuncIdx) -> String {
  let FuncIdx(i) = idx
  let raw = idx.to_string()
  match ctx.func_type_idxs.get(i.reinterpret_as_int()) {
    Some(type_idx) => raw + " => " + md_format_type_idx(ctx, type_idx)
    None => raw + " => <unknown func>"
  }
}

///|
fn md_format_table_idx(ctx : ModuleDebugContext, idx : TableIdx) -> String {
  let TableIdx(i) = idx
  let raw = idx.to_string()
  match ctx.tables.get(i.reinterpret_as_int()) {
    Some(table_type) => raw + " : " + table_type.to_string()
    None => raw + " : <unknown table>"
  }
}

///|
fn md_format_mem_idx(ctx : ModuleDebugContext, idx : MemIdx) -> String {
  let MemIdx(i) = idx
  let raw = idx.to_string()
  match ctx.mems.get(i.reinterpret_as_int()) {
    Some(mem_type) => raw + " : " + mem_type.to_string()
    None => raw + " : <unknown memory>"
  }
}

///|
fn md_format_global_idx(ctx : ModuleDebugContext, idx : GlobalIdx) -> String {
  let GlobalIdx(i) = idx
  let raw = idx.to_string()
  match ctx.globals.get(i.reinterpret_as_int()) {
    Some(global_type) => raw + " : " + global_type.to_string()
    None => raw + " : <unknown global>"
  }
}

///|
fn md_format_tag_idx(ctx : ModuleDebugContext, idx : TagIdx) -> String {
  let TagIdx(i) = idx
  let raw = idx.to_string()
  match ctx.tags.get(i.reinterpret_as_int()) {
    Some(TagType(type_idx)) =>
      raw +
      " : " +
      TagType(type_idx).to_string() +
      " => " +
      md_format_type_idx(ctx, type_idx)
    None => raw + " : <unknown tag>"
  }
}

///|
fn md_format_local_idx(
  locals : Locals,
  param_count : Int,
  idx : LocalIdx,
) -> String {
  let LocalIdx(i) = idx
  let raw = idx.to_string()
  match locals.at(i.reinterpret_as_int()) {
    Some(val_type) => {
      let role = if i.reinterpret_as_int() < param_count {
        "param"
      } else {
        "local"
      }
      raw + " : " + pretty_val_type(val_type) + " (" + role + ")"
    }
    None => raw + " : <unknown local>"
  }
}

///|
fn md_format_memarg(ctx : ModuleDebugContext, memarg : MemArg) -> String {
  let raw = memarg.to_string()
  let MemArg(_, mem_idx, _) = memarg
  match mem_idx {
    Some(idx) => raw + " [" + md_format_mem_idx(ctx, idx) + "]"
    None =>
      match ctx.mems.get(0) {
        Some(mem_type) => raw + " [default " + mem_type.to_string() + "]"
        None => raw
      }
  }
}

///|
fn md_indent(out : StringBuilder, depth : Int) -> Unit {
  for _ in 0..<depth {
    out.write_char(' ')
  }
}

///|
fn md_write_line(out : StringBuilder, depth : Int, line : String) -> Unit {
  md_indent(out, depth)
  out.write_string(line)
  out.write_char('\n')
}

///|
fn md_render_child(
  out : StringBuilder,
  depth : Int,
  label : String,
  ctx : ModuleDebugContext,
  locals : Locals,
  param_count : Int,
  child : TInstr,
) -> Unit {
  md_write_line(out, depth, label + ":")
  md_render_tinstr(out, depth + 2, ctx, locals, param_count, child)
}

///|
fn md_render_children(
  out : StringBuilder,
  depth : Int,
  label : String,
  ctx : ModuleDebugContext,
  locals : Locals,
  param_count : Int,
  children : Array[TInstr],
) -> Unit {
  if children.is_empty() {
    return
  }
  md_write_line(out, depth, label + ":")
  for i in 0..<children.length() {
    md_write_line(out, depth + 2, "[" + i.to_string() + "]")
    md_render_tinstr(out, depth + 4, ctx, locals, param_count, children[i])
  }
}

///|
fn md_render_texpr(
  out : StringBuilder,
  depth : Int,
  ctx : ModuleDebugContext,
  locals : Locals,
  param_count : Int,
  body : TExpr,
) -> Unit {
  if body.instrs.is_empty() {
    md_write_line(out, depth, "<empty>")
    return
  }
  for instr in body.instrs {
    md_render_tinstr(out, depth, ctx, locals, param_count, instr)
  }
}

///|
fn md_render_tinstr(
  out : StringBuilder,
  depth : Int,
  ctx : ModuleDebugContext,
  locals : Locals,
  param_count : Int,
  instr : TInstr,
) -> Unit {
  match instr.kind {
    TI32Const(v) => md_write_line(out, depth, "- i32.const " + v.to_string())
    TI64Const(v) => md_write_line(out, depth, "- i64.const " + v.to_string())
    TF32Const(v) => md_write_line(out, depth, "- f32.const " + v.to_string())
    TF64Const(v) => md_write_line(out, depth, "- f64.const " + v.to_string())
    TRefNull(heap_type) =>
      md_write_line(
        out,
        depth,
        "- ref.null " + md_format_heap_type(ctx, heap_type),
      )
    TRefFunc(func_idx) =>
      md_write_line(
        out,
        depth,
        "- ref.func " + md_format_func_idx(ctx, func_idx),
      )
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      md_write_line(out, depth, "- v128.const")
    TUnreachable => md_write_line(out, depth, "- unreachable")
    TNop => md_write_line(out, depth, "- nop")
    TLocalGet(local_idx) =>
      md_write_line(
        out,
        depth,
        "- local.get " + md_format_local_idx(locals, param_count, local_idx),
      )
    TGlobalGet(global_idx) =>
      md_write_line(
        out,
        depth,
        "- global.get " + md_format_global_idx(ctx, global_idx),
      )
    TMemorySize(mem_idx) =>
      md_write_line(
        out,
        depth,
        "- memory.size " + md_format_mem_idx(ctx, mem_idx),
      )
    TTableSize(table_idx) =>
      md_write_line(
        out,
        depth,
        "- table.size " + md_format_table_idx(ctx, table_idx),
      )
    TUnary(op, child) => {
      md_write_line(out, depth, "- unary " + op.to_string())
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, child)
    }
    TDrop(child) => {
      md_write_line(out, depth, "- drop")
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, child)
    }
    TLocalSet(local_idx, child) => {
      md_write_line(
        out,
        depth,
        "- local.set " + md_format_local_idx(locals, param_count, local_idx),
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, child)
    }
    TLocalTee(local_idx, child) => {
      md_write_line(
        out,
        depth,
        "- local.tee " + md_format_local_idx(locals, param_count, local_idx),
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, child)
    }
    TGlobalSet(global_idx, child) => {
      md_write_line(
        out,
        depth,
        "- global.set " + md_format_global_idx(ctx, global_idx),
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, child)
    }
    TRefIsNull(child)
    | TRefAsNonNull(child)
    | TI31GetS(child)
    | TI31GetU(child)
    | TRefI31(child)
    | TArrayLen(child)
    | TAnyConvertExtern(child)
    | TExternConvertAny(child)
    | TThrowRef(child)
    | TRefGetDesc(child)
    | TI8x16Splat(child)
    | TI16x8Splat(child)
    | TI32x4Splat(child)
    | TI64x2Splat(child)
    | TF32x4Splat(child)
    | TF64x2Splat(child) => {
      md_write_line(out, depth, "- " + instr.kind.to_string())
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, child)
    }
    TBinary(op, lhs, rhs) => {
      md_write_line(out, depth, "- binary " + op.to_string())
      md_render_child(out, depth + 2, "lhs", ctx, locals, param_count, lhs)
      md_render_child(out, depth + 2, "rhs", ctx, locals, param_count, rhs)
    }
    TRefEq(lhs, rhs) => {
      md_write_line(out, depth, "- ref.eq")
      md_render_child(out, depth + 2, "lhs", ctx, locals, param_count, lhs)
      md_render_child(out, depth + 2, "rhs", ctx, locals, param_count, rhs)
    }
    TStore(op, memarg, addr, value) => {
      md_write_line(
        out,
        depth,
        "- store " + op.to_string() + " " + md_format_memarg(ctx, memarg),
      )
      md_render_child(out, depth + 2, "addr", ctx, locals, param_count, addr)
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
    }
    TLoad(op, memarg, addr) => {
      md_write_line(
        out,
        depth,
        "- load " + op.to_string() + " " + md_format_memarg(ctx, memarg),
      )
      md_render_child(out, depth + 2, "addr", ctx, locals, param_count, addr)
    }
    TMemoryGrow(mem_idx, pages) => {
      md_write_line(
        out,
        depth,
        "- memory.grow " + md_format_mem_idx(ctx, mem_idx),
      )
      md_render_child(out, depth + 2, "pages", ctx, locals, param_count, pages)
    }
    TMemoryFill(mem_idx, dest, val, len) => {
      md_write_line(
        out,
        depth,
        "- memory.fill " + md_format_mem_idx(ctx, mem_idx),
      )
      md_render_child(out, depth + 2, "dest", ctx, locals, param_count, dest)
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, val)
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TMemoryCopy(dst, src, dest, source, len) => {
      md_write_line(
        out,
        depth,
        "- memory.copy dst=" +
        md_format_mem_idx(ctx, dst) +
        " src=" +
        md_format_mem_idx(ctx, src),
      )
      md_render_child(out, depth + 2, "dest", ctx, locals, param_count, dest)
      md_render_child(out, depth + 2, "src", ctx, locals, param_count, source)
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TMemoryInit(data_idx, mem_idx, dest, source, len) => {
      md_write_line(
        out,
        depth,
        "- memory.init " +
        data_idx.to_string() +
        " " +
        md_format_mem_idx(ctx, mem_idx),
      )
      md_render_child(out, depth + 2, "dest", ctx, locals, param_count, dest)
      md_render_child(out, depth + 2, "src", ctx, locals, param_count, source)
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TDataDrop(data_idx) =>
      md_write_line(out, depth, "- data.drop " + data_idx.to_string())
    TMemoryAtomicNotify(memarg, addr, count) => {
      md_write_line(
        out,
        depth,
        "- memory.atomic.notify " + md_format_memarg(ctx, memarg),
      )
      md_render_child(out, depth + 2, "addr", ctx, locals, param_count, addr)
      md_render_child(out, depth + 2, "count", ctx, locals, param_count, count)
    }
    TMemoryAtomicWait32(_, addr, expected, timeout)
    | TMemoryAtomicWait64(_, addr, expected, timeout) => {
      md_write_line(out, depth, "- " + instr.kind.to_string())
      md_render_child(out, depth + 2, "addr", ctx, locals, param_count, addr)
      md_render_child(
        out,
        depth + 2,
        "expected",
        ctx,
        locals,
        param_count,
        expected,
      )
      md_render_child(
        out,
        depth + 2,
        "timeout",
        ctx,
        locals,
        param_count,
        timeout,
      )
    }
    TAtomicFence => md_write_line(out, depth, "- atomic.fence")
    TAtomicRmw(op, memarg, addr, value) => {
      md_write_line(
        out,
        depth,
        "- atomic.rmw " + op.to_string() + " " + md_format_memarg(ctx, memarg),
      )
      md_render_child(out, depth + 2, "addr", ctx, locals, param_count, addr)
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
    }
    TAtomicCmpxchg(op, memarg, addr, expected, replacement) => {
      md_write_line(
        out,
        depth,
        "- atomic.cmpxchg " +
        op.to_string() +
        " " +
        md_format_memarg(ctx, memarg),
      )
      md_render_child(out, depth + 2, "addr", ctx, locals, param_count, addr)
      md_render_child(
        out,
        depth + 2,
        "expected",
        ctx,
        locals,
        param_count,
        expected,
      )
      md_render_child(
        out,
        depth + 2,
        "replacement",
        ctx,
        locals,
        param_count,
        replacement,
      )
    }
    TTableGet(table_idx, index) => {
      md_write_line(
        out,
        depth,
        "- table.get " + md_format_table_idx(ctx, table_idx),
      )
      md_render_child(out, depth + 2, "index", ctx, locals, param_count, index)
    }
    TTableSet(table_idx, index, value) => {
      md_write_line(
        out,
        depth,
        "- table.set " + md_format_table_idx(ctx, table_idx),
      )
      md_render_child(out, depth + 2, "index", ctx, locals, param_count, index)
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
    }
    TTableGrow(table_idx, value, count) => {
      md_write_line(
        out,
        depth,
        "- table.grow " + md_format_table_idx(ctx, table_idx),
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
      md_render_child(out, depth + 2, "count", ctx, locals, param_count, count)
    }
    TTableFill(table_idx, index, value, count) => {
      md_write_line(
        out,
        depth,
        "- table.fill " + md_format_table_idx(ctx, table_idx),
      )
      md_render_child(out, depth + 2, "index", ctx, locals, param_count, index)
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
      md_render_child(out, depth + 2, "count", ctx, locals, param_count, count)
    }
    TTableCopy(dst, src, dest, source, count) => {
      md_write_line(
        out,
        depth,
        "- table.copy dst=" +
        md_format_table_idx(ctx, dst) +
        " src=" +
        md_format_table_idx(ctx, src),
      )
      md_render_child(out, depth + 2, "dest", ctx, locals, param_count, dest)
      md_render_child(out, depth + 2, "src", ctx, locals, param_count, source)
      md_render_child(out, depth + 2, "count", ctx, locals, param_count, count)
    }
    TTableInit(elem_idx, table_idx, dest, source, count) => {
      md_write_line(
        out,
        depth,
        "- table.init " +
        elem_idx.to_string() +
        " " +
        md_format_table_idx(ctx, table_idx),
      )
      md_render_child(out, depth + 2, "dest", ctx, locals, param_count, dest)
      md_render_child(out, depth + 2, "src", ctx, locals, param_count, source)
      md_render_child(out, depth + 2, "count", ctx, locals, param_count, count)
    }
    TElemDrop(elem_idx) =>
      md_write_line(out, depth, "- elem.drop " + elem_idx.to_string())
    TCall(func_idx, args) => {
      md_write_line(out, depth, "- call " + md_format_func_idx(ctx, func_idx))
      md_render_children(out, depth + 2, "args", ctx, locals, param_count, args)
    }
    TCallIndirect(type_idx, table_idx, args, index) => {
      md_write_line(
        out,
        depth,
        "- call_indirect " +
        md_format_type_idx(ctx, type_idx) +
        " table=" +
        md_format_table_idx(ctx, table_idx),
      )
      md_render_children(out, depth + 2, "args", ctx, locals, param_count, args)
      md_render_child(out, depth + 2, "index", ctx, locals, param_count, index)
    }
    TCallRef(type_idx, args, ref_) => {
      md_write_line(
        out,
        depth,
        "- call_ref " + md_format_type_idx(ctx, type_idx),
      )
      md_render_children(out, depth + 2, "args", ctx, locals, param_count, args)
      md_render_child(out, depth + 2, "ref", ctx, locals, param_count, ref_)
    }
    TReturnCall(func_idx, args) => {
      md_write_line(
        out,
        depth,
        "- return_call " + md_format_func_idx(ctx, func_idx),
      )
      md_render_children(out, depth + 2, "args", ctx, locals, param_count, args)
    }
    TReturnCallIndirect(type_idx, table_idx, args, index) => {
      md_write_line(
        out,
        depth,
        "- return_call_indirect " +
        md_format_type_idx(ctx, type_idx) +
        " table=" +
        md_format_table_idx(ctx, table_idx),
      )
      md_render_children(out, depth + 2, "args", ctx, locals, param_count, args)
      md_render_child(out, depth + 2, "index", ctx, locals, param_count, index)
    }
    TReturnCallRef(type_idx, args, ref_) => {
      md_write_line(
        out,
        depth,
        "- return_call_ref " + md_format_type_idx(ctx, type_idx),
      )
      md_render_children(out, depth + 2, "args", ctx, locals, param_count, args)
      md_render_child(out, depth + 2, "ref", ctx, locals, param_count, ref_)
    }
    TBlock(block_type, body) => {
      md_write_line(
        out,
        depth,
        "- block bt=" + md_format_block_type(ctx, block_type),
      )
      md_render_texpr(out, depth + 2, ctx, locals, param_count, body)
    }
    TLoop(block_type, body) => {
      md_write_line(
        out,
        depth,
        "- loop bt=" + md_format_block_type(ctx, block_type),
      )
      md_render_texpr(out, depth + 2, ctx, locals, param_count, body)
    }
    TIf(block_type, cond, then_, else_) => {
      md_write_line(
        out,
        depth,
        "- if bt=" + md_format_block_type(ctx, block_type),
      )
      md_render_child(out, depth + 2, "cond", ctx, locals, param_count, cond)
      md_write_line(out, depth + 2, "then:")
      md_render_texpr(out, depth + 4, ctx, locals, param_count, then_)
      match else_ {
        Some(other) => {
          md_write_line(out, depth + 2, "else:")
          md_render_texpr(out, depth + 4, ctx, locals, param_count, other)
        }
        None => ()
      }
    }
    TTryTable(block_type, catches, body) => {
      md_write_line(
        out,
        depth,
        "- try_table bt=" +
        md_format_block_type(ctx, block_type) +
        " catches=" +
        catches.to_string(),
      )
      md_render_texpr(out, depth + 2, ctx, locals, param_count, body)
    }
    TThrow(tag_idx, values) => {
      md_write_line(out, depth, "- throw " + md_format_tag_idx(ctx, tag_idx))
      md_render_children(
        out,
        depth + 2,
        "args",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TBr(label_idx, values) => {
      md_write_line(out, depth, "- br " + label_idx.to_string())
      md_render_children(
        out,
        depth + 2,
        "values",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TBrIf(label_idx, cond, values) => {
      md_write_line(out, depth, "- br_if " + label_idx.to_string())
      md_render_child(out, depth + 2, "cond", ctx, locals, param_count, cond)
      md_render_children(
        out,
        depth + 2,
        "values",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TBrTable(targets, default_, index, values) => {
      md_write_line(
        out,
        depth,
        "- br_table targets=" +
        targets.to_string() +
        " default=" +
        default_.to_string(),
      )
      md_render_child(out, depth + 2, "index", ctx, locals, param_count, index)
      md_render_children(
        out,
        depth + 2,
        "values",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TBrOnNull(label_idx, value, values) => {
      md_write_line(out, depth, "- br_on_null " + label_idx.to_string())
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
      md_render_children(
        out,
        depth + 2,
        "values",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TBrOnNonNull(label_idx, value, values) => {
      md_write_line(out, depth, "- br_on_non_null " + label_idx.to_string())
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
      md_render_children(
        out,
        depth + 2,
        "values",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TBrOnCast(label_idx, cast_op, src, dst, value, values) => {
      md_write_line(
        out,
        depth,
        "- br_on_cast " +
        label_idx.to_string() +
        " " +
        cast_op.to_string() +
        " src=" +
        md_format_heap_type(ctx, src) +
        " dst=" +
        md_format_heap_type(ctx, dst),
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
      md_render_children(
        out,
        depth + 2,
        "values",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TBrOnCastFail(label_idx, cast_op, src, dst, value, values) => {
      md_write_line(
        out,
        depth,
        "- br_on_cast_fail " +
        label_idx.to_string() +
        " " +
        cast_op.to_string() +
        " src=" +
        md_format_heap_type(ctx, src) +
        " dst=" +
        md_format_heap_type(ctx, dst),
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
      md_render_children(
        out,
        depth + 2,
        "values",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TReturn(values) => {
      md_write_line(out, depth, "- return")
      md_render_children(
        out,
        depth + 2,
        "values",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TSelect(type_use, cond, if_true, if_false) => {
      md_write_line(out, depth, "- select types=" + type_use.to_string())
      md_render_child(out, depth + 2, "cond", ctx, locals, param_count, cond)
      md_render_child(out, depth + 2, "then", ctx, locals, param_count, if_true)
      md_render_child(
        out,
        depth + 2,
        "else",
        ctx,
        locals,
        param_count,
        if_false,
      )
    }
    TStructNew(type_idx, values) => {
      md_write_line(
        out,
        depth,
        "- struct.new " + md_format_type_idx(ctx, type_idx),
      )
      md_render_children(
        out,
        depth + 2,
        "fields",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TStructNewDefault(type_idx) =>
      md_write_line(
        out,
        depth,
        "- struct.new_default " + md_format_type_idx(ctx, type_idx),
      )
    TStructGet(type_idx, field_idx, value)
    | TStructGetS(type_idx, field_idx, value)
    | TStructGetU(type_idx, field_idx, value) => {
      md_write_line(
        out,
        depth,
        "- struct.get_like " +
        md_format_type_idx(ctx, type_idx) +
        " field=" +
        field_idx.to_string(),
      )
      md_render_child(out, depth + 2, "struct", ctx, locals, param_count, value)
    }
    TStructSet(type_idx, field_idx, struct_, value) => {
      md_write_line(
        out,
        depth,
        "- struct.set " +
        md_format_type_idx(ctx, type_idx) +
        " field=" +
        field_idx.to_string(),
      )
      md_render_child(
        out,
        depth + 2,
        "struct",
        ctx,
        locals,
        param_count,
        struct_,
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
    }
    TArrayNew(type_idx, init, len) => {
      md_write_line(
        out,
        depth,
        "- array.new " + md_format_type_idx(ctx, type_idx),
      )
      md_render_child(out, depth + 2, "init", ctx, locals, param_count, init)
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TArrayNewDefault(type_idx, len) => {
      md_write_line(
        out,
        depth,
        "- array.new_default " + md_format_type_idx(ctx, type_idx),
      )
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TArrayNewFixed(type_idx, values) => {
      md_write_line(
        out,
        depth,
        "- array.new_fixed " + md_format_type_idx(ctx, type_idx),
      )
      md_render_children(
        out,
        depth + 2,
        "values",
        ctx,
        locals,
        param_count,
        values,
      )
    }
    TArrayNewData(type_idx, data_idx, offset, len) => {
      md_write_line(
        out,
        depth,
        "- array.new_data " +
        md_format_type_idx(ctx, type_idx) +
        " data=" +
        data_idx.to_string(),
      )
      md_render_child(
        out,
        depth + 2,
        "offset",
        ctx,
        locals,
        param_count,
        offset,
      )
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TArrayNewElem(type_idx, elem_idx, offset, len) => {
      md_write_line(
        out,
        depth,
        "- array.new_elem " +
        md_format_type_idx(ctx, type_idx) +
        " elem=" +
        elem_idx.to_string(),
      )
      md_render_child(
        out,
        depth + 2,
        "offset",
        ctx,
        locals,
        param_count,
        offset,
      )
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TArrayGet(type_idx, arr, index)
    | TArrayGetS(type_idx, arr, index)
    | TArrayGetU(type_idx, arr, index) => {
      md_write_line(
        out,
        depth,
        "- array.get_like " + md_format_type_idx(ctx, type_idx),
      )
      md_render_child(out, depth + 2, "array", ctx, locals, param_count, arr)
      md_render_child(out, depth + 2, "index", ctx, locals, param_count, index)
    }
    TArraySet(type_idx, arr, index, value) => {
      md_write_line(
        out,
        depth,
        "- array.set " + md_format_type_idx(ctx, type_idx),
      )
      md_render_child(out, depth + 2, "array", ctx, locals, param_count, arr)
      md_render_child(out, depth + 2, "index", ctx, locals, param_count, index)
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
    }
    TArrayFill(type_idx, arr, offset, value, len) => {
      md_write_line(
        out,
        depth,
        "- array.fill " + md_format_type_idx(ctx, type_idx),
      )
      md_render_child(out, depth + 2, "array", ctx, locals, param_count, arr)
      md_render_child(
        out,
        depth + 2,
        "offset",
        ctx,
        locals,
        param_count,
        offset,
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TArrayCopy(dst, src, dst_arr, dst_index, src_arr, src_index, len) => {
      md_write_line(
        out,
        depth,
        "- array.copy dst=" +
        md_format_type_idx(ctx, dst) +
        " src=" +
        md_format_type_idx(ctx, src),
      )
      md_render_child(
        out,
        depth + 2,
        "dst_array",
        ctx,
        locals,
        param_count,
        dst_arr,
      )
      md_render_child(
        out,
        depth + 2,
        "dst_index",
        ctx,
        locals,
        param_count,
        dst_index,
      )
      md_render_child(
        out,
        depth + 2,
        "src_array",
        ctx,
        locals,
        param_count,
        src_arr,
      )
      md_render_child(
        out,
        depth + 2,
        "src_index",
        ctx,
        locals,
        param_count,
        src_index,
      )
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TArrayInitData(type_idx, data_idx, arr, arr_index, data_offset, len) => {
      md_write_line(
        out,
        depth,
        "- array.init_data " +
        md_format_type_idx(ctx, type_idx) +
        " data=" +
        data_idx.to_string(),
      )
      md_render_child(out, depth + 2, "array", ctx, locals, param_count, arr)
      md_render_child(
        out,
        depth + 2,
        "array_index",
        ctx,
        locals,
        param_count,
        arr_index,
      )
      md_render_child(
        out,
        depth + 2,
        "data_offset",
        ctx,
        locals,
        param_count,
        data_offset,
      )
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TArrayInitElem(type_idx, elem_idx, arr, arr_index, elem_offset, len) => {
      md_write_line(
        out,
        depth,
        "- array.init_elem " +
        md_format_type_idx(ctx, type_idx) +
        " elem=" +
        elem_idx.to_string(),
      )
      md_render_child(out, depth + 2, "array", ctx, locals, param_count, arr)
      md_render_child(
        out,
        depth + 2,
        "array_index",
        ctx,
        locals,
        param_count,
        arr_index,
      )
      md_render_child(
        out,
        depth + 2,
        "elem_offset",
        ctx,
        locals,
        param_count,
        elem_offset,
      )
      md_render_child(out, depth + 2, "len", ctx, locals, param_count, len)
    }
    TRefTest(nullable, heap_type, value)
    | TRefCast(nullable, heap_type, value)
    | TRefTestDesc(nullable, heap_type, value)
    | TRefCastDescEq(nullable, heap_type, value) => {
      md_write_line(
        out,
        depth,
        "- ref.type_check nullable=" +
        nullable.to_string() +
        " " +
        md_format_heap_type(ctx, heap_type),
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
    }
    TExtractLane(op, lane_idx, value) => {
      md_write_line(
        out,
        depth,
        "- extract_lane " + op.to_string() + " lane=" + lane_idx.to_string(),
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
    }
    TReplaceLane(op, lane_idx, vector, value) => {
      md_write_line(
        out,
        depth,
        "- replace_lane " + op.to_string() + " lane=" + lane_idx.to_string(),
      )
      md_render_child(
        out,
        depth + 2,
        "vector",
        ctx,
        locals,
        param_count,
        vector,
      )
      md_render_child(out, depth + 2, "value", ctx, locals, param_count, value)
    }
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, lhs, rhs) => {
      md_write_line(out, depth, "- i8x16.shuffle")
      md_render_child(out, depth + 2, "lhs", ctx, locals, param_count, lhs)
      md_render_child(out, depth + 2, "rhs", ctx, locals, param_count, rhs)
    }
    TI8x16Swizzle(lhs, rhs)
    | TI8x16RelaxedSwizzle(lhs, rhs)
    | TV128Shift(_, lhs, rhs) => {
      md_write_line(out, depth, "- simd.binary")
      md_render_child(out, depth + 2, "lhs", ctx, locals, param_count, lhs)
      md_render_child(out, depth + 2, "rhs", ctx, locals, param_count, rhs)
    }
    TV128Ternary(op, a, b, c) => {
      md_write_line(out, depth, "- v128.ternary " + op.to_string())
      md_render_child(out, depth + 2, "a", ctx, locals, param_count, a)
      md_render_child(out, depth + 2, "b", ctx, locals, param_count, b)
      md_render_child(out, depth + 2, "c", ctx, locals, param_count, c)
    }
    TV128LoadLane(op, memarg, lane_idx, vector, addr) => {
      md_write_line(
        out,
        depth,
        "- v128.load_lane " +
        op.to_string() +
        " lane=" +
        lane_idx.to_string() +
        " " +
        md_format_memarg(ctx, memarg),
      )
      md_render_child(
        out,
        depth + 2,
        "vector",
        ctx,
        locals,
        param_count,
        vector,
      )
      md_render_child(out, depth + 2, "addr", ctx, locals, param_count, addr)
    }
    TV128StoreLane(op, memarg, lane_idx, vector, addr) => {
      md_write_line(
        out,
        depth,
        "- v128.store_lane " +
        op.to_string() +
        " lane=" +
        lane_idx.to_string() +
        " " +
        md_format_memarg(ctx, memarg),
      )
      md_render_child(
        out,
        depth + 2,
        "vector",
        ctx,
        locals,
        param_count,
        vector,
      )
      md_render_child(out, depth + 2, "addr", ctx, locals, param_count, addr)
    }
  }
}

///|
fn md_format_block_type(
  ctx : ModuleDebugContext,
  block_type : BlockType,
) -> String {
  match block_type {
    VoidBlockType => "(Void)"
    ValTypeBlockType(val_type) => pretty_val_type(val_type)
    TypeIdxBlockType(type_idx) => md_format_type_idx(ctx, type_idx)
  }
}

///|
fn md_imported_func_count(ctx : ModuleDebugContext) -> Int {
  ctx.func_imports.length()
}

///|
pub fn Module::pretty_print_func(self : Module, func_idx : FuncIdx) -> String {
  let ctx = md_build_context(self)
  let FuncIdx(i) = func_idx
  let abs_idx = i.reinterpret_as_int()
  let imported = md_imported_func_count(ctx)
  if abs_idx < imported {
    let out = StringBuilder::new()
    md_write_line(out, 0, "func abs[\{abs_idx}] import")
    match ctx.func_imports.get(abs_idx) {
      Some(Import(module_name, field_name, FuncExternType(type_idx))) => {
        md_write_line(out, 2, "module: \"" + module_name.0.to_string() + "\"")
        md_write_line(out, 2, "field: \"" + field_name.0.to_string() + "\"")
        md_write_line(out, 2, "type_idx: " + md_format_type_idx(ctx, type_idx))
      }
      _ => md_write_line(out, 2, "<missing import metadata>")
    }
    return out.to_string()
  }
  self.pretty_print_defined_func((abs_idx - imported).reinterpret_as_uint())
}

///|
pub fn Module::pretty_print_defined_func(
  self : Module,
  def_idx : UInt,
) -> String {
  let ctx = md_build_context(self)
  let def_idx_i = def_idx.reinterpret_as_int()
  let imported = md_imported_func_count(ctx)
  let abs_idx = imported + def_idx_i
  let out = StringBuilder::new()
  let type_idx = match self.func_sec {
    Some(FuncSec(type_idxs)) => type_idxs.get(def_idx_i)
    None => None
  }
  let func = match self.code_sec {
    Some(CodeSec(funcs)) => funcs.get(def_idx_i)
    None => None
  }
  match (type_idx, func) {
    (Some(type_idx), Some(func)) => {
      md_write_line(out, 0, "func code[\{def_idx_i}] abs[\{abs_idx}]")
      md_write_line(out, 2, "type_idx: " + md_format_type_idx(ctx, type_idx))
      let FuncType(params, results) = match md_resolve_functype(ctx, type_idx) {
        Some(func_type) => func_type
        None => FuncType::new([], [])
      }
      md_write_line(out, 2, "params: " + pretty_result_type(params))
      md_write_line(out, 2, "results: " + pretty_result_type(results))
      match func {
        Func(grouped_locals, body) => {
          let full_locals = match
            FunctionLocals::from_local_decls(params, grouped_locals) {
            Ok(locals) => locals.all_locals()
            Err(err) => {
              md_write_line(out, 2, "locals_error: " + err)
              Locals::from_types(params)
            }
          }
          md_write_line(out, 2, "locals:")
          if full_locals.is_empty() {
            md_write_line(out, 4, "<none>")
          } else {
            for i in 0..<full_locals.length() {
              let role = if i < params.length() { "param" } else { "local" }
              md_write_line(
                out,
                4,
                "[\{i}] " +
                pretty_val_type(full_locals.unsafe_get(i)) +
                " (" + role + ")",
              )
            }
          }
          md_write_line(out, 2, "body_raw:")
          md_write_line(out, 4, body.to_string())
        }
        TFunc(func_params, local_vals, body) => {
          let resolved = FunctionLocals::from_typed_func(
            params, func_params, local_vals,
          )
          let local_info = match resolved {
            Ok(ls) => ls
            Err(err) => {
              md_write_line(out, 2, "locals_error: " + err)
              FunctionLocals::new(func_params, local_vals)
            }
          }
          let full_locals = local_info.all_locals()
          md_write_line(out, 2, "locals:")
          if full_locals.is_empty() {
            md_write_line(out, 4, "<none>")
          } else {
            for i in 0..<full_locals.length() {
              let role = if i < local_info.param_count() {
                "param"
              } else {
                "local"
              }
              md_write_line(
                out,
                4,
                "[\{i}] " +
                pretty_val_type(full_locals.unsafe_get(i)) +
                " (" + role + ")",
              )
            }
          }
          md_write_line(out, 2, "body:")
          md_render_texpr(
            out,
            4,
            ctx,
            full_locals,
            local_info.param_count(),
            body,
          )
        }
      }
    }
    _ => md_write_line(out, 0, "func code[\{def_idx_i}] <missing>")
  }
  out.to_string()
}
