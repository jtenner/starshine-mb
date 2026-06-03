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
    StringAbsHeapType => "String"
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
    CompTypeSubType(_, comp_type) => pretty_comp_type(comp_type)
    SubType(is_final, super_types, _, comp_type) => {
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
    HeapTypeRefType(nullable, exact, heap_type) => {
      let heap_text = if exact {
        "(Exact " + pretty_heap_type(heap_type) + ")"
      } else {
        pretty_heap_type(heap_type)
      }
      if nullable {
        "(Ref Null " + heap_text + ")"
      } else {
        "(Ref " + heap_text + ")"
      }
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
pub impl PrettyPrint for AbsHeapType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for BinaryOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for BlockType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for CastOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Catch with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for CodeSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for CompType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_comp_type(self), ctx)
}

///|
pub impl PrettyPrint for CustomSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for NameAssoc with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for NameMap with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for IndirectNameAssoc with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for IndirectNameMap with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for NameSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Data with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataCntSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataMode with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DataSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for DefType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_def_type(self), ctx)
}

///|
pub impl PrettyPrint for Elem with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemKind with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemMode with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ElemSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Export with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExportSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Expr with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExternIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExternType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ExtractLaneOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for F32 with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for F64 with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FieldType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_field_type(self), ctx)
}

///|
pub impl PrettyPrint for Func with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for FuncType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_func_type(self), ctx)
}

///|
pub impl PrettyPrint for Global with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for GlobalType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for HeapType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_heap_type(self), ctx)
}

///|
pub impl PrettyPrint for I32 with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for I64 with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Import with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ImportSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Instruction with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LabelIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LaneIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Limits with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LoadOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for LocalIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Locals with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemArg with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for MemType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Module with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for Mut with fn pretty_print(self, ctx) {
  apply_pretty_context(self.to_string(), ctx)
}

///|
pub impl PrettyPrint for Name with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for NumType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_num_type(self), ctx)
}

///|
pub impl PrettyPrint for PackType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for RecType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_rec_type(self), ctx)
}

///|
pub impl PrettyPrint for RefType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_ref_type(self), ctx)
}

///|
pub impl PrettyPrint for ReplaceLaneOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for S33 with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for StartSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for StorageType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_storage_type(self), ctx)
}

///|
pub impl PrettyPrint for StoreOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for SubType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_sub_type(self), ctx)
}

///|
pub impl PrettyPrint for Table with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TableType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TagIdx with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TagSec with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TagType with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for TypeIdx with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_type_idx(self), ctx)
}

///|
pub impl PrettyPrint for TypeSec with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_type_sec(self), ctx)
}

///|
pub impl PrettyPrint for U32 with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for U64 with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for UnaryOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128LoadLaneOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128ShiftOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128StoreLaneOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for V128TernaryOp with fn pretty_print(self, ctx) {
  pretty_from_show(self, ctx)
}

///|
pub impl PrettyPrint for ValType with fn pretty_print(self, ctx) {
  apply_pretty_context(pretty_val_type(self), ctx)
}
