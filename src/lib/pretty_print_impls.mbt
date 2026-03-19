///|
fn pretty_join(parts : Array[String], sep : String) -> String {
  let out = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      out.write_string(sep)
    }
    out.write_string(parts[i])
  }
  out.to_string()
}

///|
fn pretty_num_type(num_type : NumType) -> String {
  match num_type {
    I32NumType => "I32"
    I64NumType => "I64"
    F32NumType => "F32"
    F64NumType => "F64"
  }
}

///|
fn pretty_abs_heap_type(abs_heap_type : AbsHeapType) -> String {
  match abs_heap_type {
    ExnAbsHeapType => "Exn"
    ArrayAbsHeapType => "Array"
    StructAbsHeapType => "Struct"
    I31AbsHeapType => "I31"
    EqAbsHeapType => "Eq"
    AnyAbsHeapType => "Any"
    ExternAbsHeapType => "Extern"
    FuncAbsHeapType => "Func"
    NoneAbsHeapType => "None"
    NoExternAbsHeapType => "NoExtern"
    NoFuncAbsHeapType => "NoFunc"
    NoExnAbsHeapType => "NoExn"
  }
}

///|
fn pretty_type_idx(type_idx : TypeIdx) -> String {
  match type_idx {
    TypeIdx(i) => "(Type \{i})"
    RecIdx(i) => "(Rec \{i})"
  }
}

///|
fn pretty_type_idx_list(type_idxs : Array[TypeIdx]) -> String {
  let items : Array[String] = []
  for type_idx in type_idxs {
    items.push(pretty_type_idx(type_idx))
  }
  "[" + pretty_join(items, ", ") + "]"
}

///|
fn pretty_storage_type(storage_type : StorageType) -> String {
  match storage_type {
    ValTypeStorageType(val_type) => pretty_val_type(val_type)
    PackTypeStorageType(pack_type) => pack_type.to_string()
  }
}

///|
fn pretty_field_type(field_type : FieldType) -> String {
  let FieldType(storage_type, mutability) = field_type
  let rendered = pretty_storage_type(storage_type)
  match mutability {
    Const => rendered
    Var => "(Mut " + rendered + ")"
  }
}

///|
fn pretty_func_type(func_type : FuncType) -> String {
  let FuncType(params, results) = func_type
  "(Func " +
  pretty_result_type(params) +
  " -> " +
  pretty_result_type(results) +
  ")"
}

///|
fn pretty_comp_type(comp_type : CompType) -> String {
  match comp_type {
    FuncCompType(params, results) =>
      pretty_func_type(FuncType::new(params, results))
    StructCompType(field_types) => {
      let items : Array[String] = []
      for field_type in field_types {
        items.push(pretty_field_type(field_type))
      }
      "(Struct [" + pretty_join(items, ", ") + "])"
    }
    ArrayCompType(field_type) => "(Array " + pretty_field_type(field_type) + ")"
  }
}

///|
fn pretty_sub_type(sub_type : SubType) -> String {
  match sub_type {
    CompTypeSubType(comp_type) => pretty_comp_type(comp_type)
    SubType(is_final, super_types, comp_type) => {
      if super_types.is_empty() && !is_final {
        return pretty_comp_type(comp_type)
      }
      let prefix = if is_final { "(Sub Final " } else { "(Sub " }
      if super_types.is_empty() {
        prefix + pretty_comp_type(comp_type) + ")"
      } else {
        prefix +
        pretty_type_idx_list(super_types) +
        " " +
        pretty_comp_type(comp_type) +
        ")"
      }
    }
  }
}

///|
fn pretty_rec_type(rec_type : RecType) -> String {
  match rec_type {
    SingleRecType(sub_type) => pretty_sub_type(sub_type)
    GroupRecType(sub_types) => {
      let items : Array[String] = []
      for sub_type in sub_types {
        items.push(pretty_sub_type(sub_type))
      }
      "(RecGroup [" + pretty_join(items, ", ") + "])"
    }
  }
}

///|
fn pretty_def_type(def_type : DefType) -> String {
  let DefType(rec_type, idx) = def_type
  "(DefType " + pretty_rec_type(rec_type) + " " + idx.to_string() + ")"
}

///|
fn pretty_heap_type(heap_type : HeapType) -> String {
  match heap_type {
    AbsHeapTypeHeapType(abs_heap_type) => pretty_abs_heap_type(abs_heap_type)
    HeapType(type_idx) => pretty_type_idx(type_idx)
    DefTypeHeapType(def_type) => pretty_def_type(def_type)
  }
}

///|
fn pretty_ref_type(ref_type : RefType) -> String {
  match ref_type {
    HeapTypeRefType(nullable, heap_type) =>
      if nullable {
        "(Ref Null " + pretty_heap_type(heap_type) + ")"
      } else {
        "(Ref " + pretty_heap_type(heap_type) + ")"
      }
    AbsHeapTypeRefType(abs_heap_type) =>
      "(Ref Null " + pretty_abs_heap_type(abs_heap_type) + ")"
  }
}

///|
fn pretty_val_type(val_type : ValType) -> String {
  match val_type {
    NumTypeValType(num_type) => pretty_num_type(num_type)
    VecTypeValType => "V128"
    RefTypeValType(ref_type) => pretty_ref_type(ref_type)
    BotValType => "Bot"
  }
}

///|
fn pretty_result_type(result_type : ResultType) -> String {
  let items : Array[String] = []
  for val_type in result_type {
    items.push(pretty_val_type(val_type))
  }
  "[" + pretty_join(items, ", ") + "]"
}

///|
fn flatten_type_sec(type_sec : TypeSec) -> Array[SubType] {
  let TypeSec(rec_types) = type_sec
  let subtypes : Array[SubType] = []
  for rec_type in rec_types {
    match rec_type {
      SingleRecType(sub_type) => subtypes.push(sub_type)
      GroupRecType(group) =>
        for sub_type in group {
          subtypes.push(sub_type)
        }
    }
  }
  subtypes
}

///|
fn pretty_resolved_type_idx(
  subtypes : Array[SubType],
  type_idx : TypeIdx,
) -> String {
  match type_idx {
    TypeIdx(i) =>
      match subtypes.get(i.reinterpret_as_int()) {
        Some(sub_type) => "(Type \{i} " + pretty_sub_type(sub_type) + ")"
        None => pretty_type_idx(type_idx)
      }
    RecIdx(_) => pretty_type_idx(type_idx)
  }
}

///|
fn pretty_type_sec(type_sec : TypeSec) -> String {
  let subtypes = flatten_type_sec(type_sec)
  let out = StringBuilder::new()
  out.write_string("[Types")
  if subtypes.is_empty() {
    out.write_char(']')
    return out.to_string()
  }
  out.write_string(":\n")
  for i in 0..<subtypes.length() {
    out.write_string("  ")
    out.write_string(
      pretty_resolved_type_idx(subtypes, TypeIdx::new(i.reinterpret_as_uint())),
    )
    out.write_char('\n')
  }
  out.write_char(']')
  out.to_string()
}

///|
fn pretty_from_show(value : &Show, ctx : PrettyPrintContext) -> String {
  apply_pretty_context(value.to_string(), ctx)
}

///|
pub impl PrettyPrint for AbsHeapType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for BinaryOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for BlockType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for CastOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Catch with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for CodeSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for CompType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_comp_type(self), ctx)
}

///|
pub impl PrettyPrint for CustomSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for NameAssoc with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for NameMap with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for IndirectNameAssoc with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for IndirectNameMap with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for NameSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Data with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataCntSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataMode with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DefType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_def_type(self), ctx)
}

///|
pub impl PrettyPrint for Elem with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemKind with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemMode with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Export with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExportSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Expr with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExternIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExternType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExtractLaneOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for F32 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for F64 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FieldType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_field_type(self), ctx)
}

///|
pub impl PrettyPrint for Func with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_func_type(self), ctx)
}

///|
pub impl PrettyPrint for Global with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for HeapType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_heap_type(self), ctx)
}

///|
pub impl PrettyPrint for I32 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for I64 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Import with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ImportSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Instruction with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LabelIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LaneIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Limits with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LoadOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LocalIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Locals with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemArg with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Module with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Mut with pretty_print(self, ctx) {
  apply_pretty_context(self.to_string(), ctx)
}

///|
pub impl PrettyPrint for Name with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for NumType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_num_type(self), ctx)
}

///|
pub impl PrettyPrint for PackType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for RecType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_rec_type(self), ctx)
}

///|
pub impl PrettyPrint for RefType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_ref_type(self), ctx)
}

///|
pub impl PrettyPrint for ReplaceLaneOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for S33 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for StartSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for StorageType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_storage_type(self), ctx)
}

///|
pub impl PrettyPrint for StoreOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for SubType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_sub_type(self), ctx)
}

///|
pub impl PrettyPrint for TExpr with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TInstr with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Table with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TagIdx with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TagSec with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TagType with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TypeIdx with pretty_print(self, ctx) {
  apply_pretty_context(pretty_type_idx(self), ctx)
}

///|
pub impl PrettyPrint for TypeSec with pretty_print(self, ctx) {
  apply_pretty_context(pretty_type_sec(self), ctx)
}

///|
pub impl PrettyPrint for U32 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for U64 with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for UnaryOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128LoadLaneOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128ShiftOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128StoreLaneOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128TernaryOp with pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ValType with pretty_print(self, ctx) {
  apply_pretty_context(pretty_val_type(self), ctx)
}
