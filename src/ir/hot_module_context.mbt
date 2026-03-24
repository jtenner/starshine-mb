///|
pub struct HotModuleContext {
  subtypes : Array[SubType]
  func_type_idxs : Array[TypeIdx]
  tables : Array[TableType]
  mems : Array[@lib.MemType]
  globals : Array[GlobalType]
  tags : Array[TagType]
} derive(Eq, Debug)

///|
fn hot_module_context_flatten_subtypes(
  type_sec : @lib.TypeSec?,
) -> Array[SubType] {
  let out : Array[SubType] = []
  match type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) => out.push(subtype)
          @lib.GroupRecType(group) =>
            for subtype in group {
              out.push(subtype)
            }
        }
      }
    None => ()
  }
  out
}

///|
pub fn hot_module_context_from_module(mod_ : Module) -> HotModuleContext {
  let func_type_idxs : Array[TypeIdx] = []
  let tables : Array[TableType] = []
  let mems : Array[@lib.MemType] = []
  let globals : Array[GlobalType] = []
  let tags : Array[TagType] = []

  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) =>
            func_type_idxs.push(type_idx)
          @lib.Import(_, _, @lib.TableExternType(table_type)) =>
            tables.push(table_type)
          @lib.Import(_, _, @lib.MemExternType(mem_type)) => mems.push(mem_type)
          @lib.Import(_, _, @lib.GlobalExternType(global_type)) =>
            globals.push(global_type)
          @lib.Import(_, _, @lib.TagExternType(tag_type)) => tags.push(tag_type)
        }
      }
    None => ()
  }

  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        func_type_idxs.push(type_idx)
      }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(defs)) =>
      for table in defs {
        let @lib.Table(table_type, _) = table
        tables.push(table_type)
      }
    None => ()
  }
  match mod_.mem_sec {
    Some(@lib.MemSec(defs)) =>
      for mem_type in defs {
        mems.push(mem_type)
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(defs)) =>
      for global in defs {
        let @lib.Global(global_type, _) = global
        globals.push(global_type)
      }
    None => ()
  }
  match mod_.tag_sec {
    Some(@lib.TagSec(defs)) =>
      for tag_type in defs {
        tags.push(tag_type)
      }
    None => ()
  }

  {
    subtypes: hot_module_context_flatten_subtypes(mod_.type_sec),
    func_type_idxs,
    tables,
    mems,
    globals,
    tags,
  }
}

///|
pub fn hot_module_resolve_subtype(
  ctx : HotModuleContext,
  idx : TypeIdx,
) -> SubType? {
  match idx {
    @lib.TypeIdx(raw) => ctx.subtypes.get(raw.reinterpret_as_int())
    @lib.RecIdx(_) => None
  }
}

///|
pub fn hot_module_resolve_type_func_type(
  ctx : HotModuleContext,
  idx : TypeIdx,
) -> FuncType? {
  match hot_module_resolve_subtype(ctx, idx) {
    Some(subtype) =>
      match subtype.get_comptype() {
        @lib.FuncCompType(params, results) =>
          Some(@lib.FuncType::new(params, results))
        _ => None
      }
    None => None
  }
}

///|
pub fn hot_module_resolve_func_type_idx(
  ctx : HotModuleContext,
  func_idx : @lib.FuncIdx,
) -> TypeIdx? {
  let @lib.FuncIdx(raw) = func_idx
  ctx.func_type_idxs.get(raw.reinterpret_as_int())
}

///|
pub fn hot_module_resolve_func_type(
  ctx : HotModuleContext,
  func_idx : @lib.FuncIdx,
) -> FuncType? {
  match hot_module_resolve_func_type_idx(ctx, func_idx) {
    Some(type_idx) => hot_module_resolve_type_func_type(ctx, type_idx)
    None => None
  }
}

///|
pub fn hot_module_resolve_block_results(
  ctx : HotModuleContext,
  block_type : BlockType,
) -> Array[ValType]? {
  match block_type {
    @lib.VoidBlockType => Some([])
    @lib.ValTypeBlockType(val_type) => Some([val_type])
    @lib.TypeIdxBlockType(type_idx) =>
      match hot_module_resolve_type_func_type(ctx, type_idx) {
        Some(@lib.FuncType(_, results)) => Some(results)
        None => None
      }
  }
}

///|
pub fn hot_module_resolve_table_type(
  ctx : HotModuleContext,
  table_idx : @lib.TableIdx,
) -> TableType? {
  let @lib.TableIdx(raw) = table_idx
  ctx.tables.get(raw.reinterpret_as_int())
}

///|
pub fn hot_module_resolve_mem_type(
  ctx : HotModuleContext,
  mem_idx : @lib.MemIdx,
) -> @lib.MemType? {
  let @lib.MemIdx(raw) = mem_idx
  ctx.mems.get(raw.reinterpret_as_int())
}

///|
pub fn hot_module_resolve_global_type(
  ctx : HotModuleContext,
  global_idx : @lib.GlobalIdx,
) -> GlobalType? {
  let @lib.GlobalIdx(raw) = global_idx
  ctx.globals.get(raw.reinterpret_as_int())
}

///|
pub fn hot_module_resolve_tag_type(
  ctx : HotModuleContext,
  tag_idx : @lib.TagIdx,
) -> TagType? {
  let @lib.TagIdx(raw) = tag_idx
  ctx.tags.get(raw.reinterpret_as_int())
}

///|
pub fn hot_module_resolve_mem_index_type(
  ctx : HotModuleContext,
  mem_idx : @lib.MemIdx,
) -> ValType? {
  match hot_module_resolve_mem_type(ctx, mem_idx) {
    Some(@lib.MemType(limits)) => Some(limits.addr_valtype())
    None => None
  }
}

///|
pub fn hot_module_resolve_table_index_type(
  ctx : HotModuleContext,
  table_idx : @lib.TableIdx,
) -> ValType? {
  match hot_module_resolve_table_type(ctx, table_idx) {
    Some(@lib.TableType(_, limits)) => Some(limits.addr_valtype())
    None => None
  }
}

///|
pub fn hot_module_resolve_struct_fields(
  ctx : HotModuleContext,
  type_idx : TypeIdx,
) -> Array[FieldType]? {
  match hot_module_resolve_subtype(ctx, type_idx) {
    Some(subtype) =>
      match subtype.get_comptype() {
        @lib.StructCompType(fields) => Some(fields)
        _ => None
      }
    None => None
  }
}

///|
pub fn hot_module_resolve_array_field(
  ctx : HotModuleContext,
  type_idx : TypeIdx,
) -> FieldType? {
  match hot_module_resolve_subtype(ctx, type_idx) {
    Some(subtype) =>
      match subtype.get_comptype() {
        @lib.ArrayCompType(field) => Some(field)
        _ => None
      }
    None => None
  }
}

///|
pub fn hot_type_resolve_results(
  func : HotFunc,
  ctx : HotModuleContext,
  type_id : TypeId,
) -> Array[ValType]? {
  match hot_type_get(func, type_id) {
    VoidType => Some([])
    BlockResult(block_type) => hot_module_resolve_block_results(ctx, block_type)
    Value(val_type) => Some([val_type])
    Results(values) => Some(values)
  }
}
