///|
pub fn Module::with_custom_secs(
  self : Module,
  custom_secs : Array[CustomSec],
) -> Module {
  Module::{ ..self, custom_secs, }
}

///|
pub fn Module::with_name_sec(self : Module, name_sec : NameSec) -> Module {
  Module::{ ..self, name_sec: Some(name_sec), raw_name_sec_payload: None }
}

///|
pub fn Module::without_name_sec(self : Module) -> Module {
  Module::{ ..self, name_sec: None, raw_name_sec_payload: None }
}

///|
pub fn Module::with_raw_name_sec_payload(
  self : Module,
  payload : Bytes,
) -> Module {
  Module::{ ..self, raw_name_sec_payload: Some(payload) }
}

///|
pub fn Module::without_name_sec(self : Module) -> Module {
  Module::{ ..self, name_sec: None }
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
pub fn Module::with_func_annotation_sec(
  self : Module,
  func_annotation_sec : FuncAnnotationSec,
) -> Module {
  Module::{ ..self, func_annotation_sec: Some(func_annotation_sec) }
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
pub fn Module::with_stringrefs_sec(
  self : Module,
  stringrefs_sec : StringRefsSec,
) -> Module {
  Module::{ ..self, stringrefs_sec: Some(stringrefs_sec) }
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
fn md_format_ref_null_type(
  ctx : ModuleDebugContext,
  ref_type : RefType,
) -> String {
  let heap_text = md_format_heap_type(ctx, ref_type.get_heap_type())
  if ref_type.is_exact() {
    "(exact \{heap_text})"
  } else {
    heap_text
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
                " (" +
                role +
                ")",
              )
            }
          }
          md_write_line(out, 2, "body_raw:")
          md_write_line(out, 4, body.to_string())
        }
      }
    }
    _ => md_write_line(out, 0, "func code[\{def_idx_i}] <missing>")
  }
  out.to_string()
}
