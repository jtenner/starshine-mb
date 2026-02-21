///|
pub type TransformerResult[T, Elem] = Result[(T, Elem)?, String]

///|
pub fn[T, Elem] change(t : T, elem : Elem) -> TransformerResult[T, Elem] {
  Ok(Some((t, elem)))
}

///|
pub fn[T, Elem] unchanged() -> TransformerResult[T, Elem] {
  Ok(None)
}

///|
pub fn[T, Elem] error(err : String) -> TransformerResult[T, Elem] {
  Err(err)
}

// Transformer Definition

///|
pub struct ModuleTransformer[T] {
  on_module : ((ModuleTransformer[T], T, Module) -> TransformerResult[T, Module])?
  on_typesec : ((ModuleTransformer[T], T, TypeSec) -> TransformerResult[
    T,
    TypeSec,
  ])?
  on_funcsec : ((ModuleTransformer[T], T, FuncSec) -> TransformerResult[
    T,
    FuncSec,
  ])?
  on_tablesec : ((ModuleTransformer[T], T, TableSec) -> TransformerResult[
    T,
    TableSec,
  ])?
  on_memsec : ((ModuleTransformer[T], T, MemSec) -> TransformerResult[T, MemSec])?
  on_tagsec : ((ModuleTransformer[T], T, TagSec) -> TransformerResult[T, TagSec])?
  on_globalsec : ((ModuleTransformer[T], T, GlobalSec) -> TransformerResult[
    T,
    GlobalSec,
  ])?
  on_exportsec : ((ModuleTransformer[T], T, ExportSec) -> TransformerResult[
    T,
    ExportSec,
  ])?
  on_importsec : ((ModuleTransformer[T], T, ImportSec) -> TransformerResult[
    T,
    ImportSec,
  ])?
  on_startsec : ((ModuleTransformer[T], T, StartSec) -> TransformerResult[
    T,
    StartSec,
  ])?
  on_elemsec : ((ModuleTransformer[T], T, ElemSec) -> TransformerResult[
    T,
    ElemSec,
  ])?
  on_elemkind : ((ModuleTransformer[T], T, ElemKind) -> TransformerResult[
    T,
    ElemKind,
  ])?
  on_datacntsec : ((ModuleTransformer[T], T, DataCntSec) -> TransformerResult[
    T,
    DataCntSec,
  ])?
  on_codesec : ((ModuleTransformer[T], T, CodeSec) -> TransformerResult[
    T,
    CodeSec,
  ])?
  on_datasec : ((ModuleTransformer[T], T, DataSec) -> TransformerResult[
    T,
    DataSec,
  ])?
  on_instruction : ((ModuleTransformer[T], T, Instruction) -> TransformerResult[
    T,
    Instruction,
  ])?
  on_tinstruction : ((ModuleTransformer[T], T, TInstr) -> TransformerResult[
    T,
    TInstr,
  ])?
  on_expr : ((ModuleTransformer[T], T, Expr) -> TransformerResult[T, Expr])?
  on_texpr : ((ModuleTransformer[T], T, TExpr) -> TransformerResult[T, TExpr])?
  on_table : ((ModuleTransformer[T], T, Table) -> TransformerResult[T, Table])?
  on_valtype : ((ModuleTransformer[T], T, ValType) -> TransformerResult[
    T,
    ValType,
  ])?
  on_numtype : ((ModuleTransformer[T], T, NumType) -> TransformerResult[
    T,
    NumType,
  ])?
  on_rectype : ((ModuleTransformer[T], T, RecType) -> TransformerResult[
    T,
    RecType,
  ])?
  on_subtype : ((ModuleTransformer[T], T, SubType) -> TransformerResult[
    T,
    SubType,
  ])?
  on_comptype : ((ModuleTransformer[T], T, CompType) -> TransformerResult[
    T,
    CompType,
  ])?
  on_reftype : ((ModuleTransformer[T], T, RefType) -> TransformerResult[
    T,
    RefType,
  ])?
  on_heaptype : ((ModuleTransformer[T], T, HeapType) -> TransformerResult[
    T,
    HeapType,
  ])?
  on_blocktype : ((ModuleTransformer[T], T, BlockType) -> TransformerResult[
    T,
    BlockType,
  ])?
  on_funcidx : ((ModuleTransformer[T], T, FuncIdx) -> TransformerResult[
    T,
    FuncIdx,
  ])?
  on_typeidx : ((ModuleTransformer[T], T, TypeIdx) -> TransformerResult[
    T,
    TypeIdx,
  ])?
  on_laneidx : ((ModuleTransformer[T], T, LaneIdx) -> TransformerResult[
    T,
    LaneIdx,
  ])?
  on_localidx : ((ModuleTransformer[T], T, LocalIdx) -> TransformerResult[
    T,
    LocalIdx,
  ])?
  on_globalidx : ((ModuleTransformer[T], T, GlobalIdx) -> TransformerResult[
    T,
    GlobalIdx,
  ])?
  on_tableidx : ((ModuleTransformer[T], T, TableIdx) -> TransformerResult[
    T,
    TableIdx,
  ])?
  on_memidx : ((ModuleTransformer[T], T, MemIdx) -> TransformerResult[T, MemIdx])?
  on_labelidx : ((ModuleTransformer[T], T, LabelIdx) -> TransformerResult[
    T,
    LabelIdx,
  ])?
  on_dataidx : ((ModuleTransformer[T], T, DataIdx) -> TransformerResult[
    T,
    DataIdx,
  ])?
  on_elemidx : ((ModuleTransformer[T], T, ElemIdx) -> TransformerResult[
    T,
    ElemIdx,
  ])?
  on_tagidx : ((ModuleTransformer[T], T, TagIdx) -> TransformerResult[T, TagIdx])?
  on_name : ((ModuleTransformer[T], T, Name) -> TransformerResult[T, Name])?
  on_externtype : ((ModuleTransformer[T], T, ExternType) -> TransformerResult[
    T,
    ExternType,
  ])?
  on_limits : ((ModuleTransformer[T], T, Limits) -> TransformerResult[T, Limits])?
  on_memtype : ((ModuleTransformer[T], T, MemType) -> TransformerResult[
    T,
    MemType,
  ])?
  on_tagtype : ((ModuleTransformer[T], T, TagType) -> TransformerResult[
    T,
    TagType,
  ])?
  on_export : ((ModuleTransformer[T], T, Export) -> TransformerResult[T, Export])?
  on_global : ((ModuleTransformer[T], T, Global) -> TransformerResult[T, Global])?
  on_globaltype : ((ModuleTransformer[T], T, GlobalType) -> TransformerResult[
    T,
    GlobalType,
  ])?
  on_func : ((ModuleTransformer[T], T, Func) -> TransformerResult[T, Func])?
  on_locals : ((ModuleTransformer[T], T, Array[Locals]) -> TransformerResult[
    T,
    Array[Locals],
  ])?
  on_externidx : ((ModuleTransformer[T], T, ExternIdx) -> TransformerResult[
    T,
    ExternIdx,
  ])?
  on_fieldtype : ((ModuleTransformer[T], T, FieldType) -> TransformerResult[
    T,
    FieldType,
  ])?
  on_storagetype : ((ModuleTransformer[T], T, StorageType) -> TransformerResult[
    T,
    StorageType,
  ])?
  on_unaryop : ((ModuleTransformer[T], T, UnaryOp) -> TransformerResult[
    T,
    UnaryOp,
  ])?
  on_binaryop : ((ModuleTransformer[T], T, BinaryOp) -> TransformerResult[
    T,
    BinaryOp,
  ])?
  on_storeop : ((ModuleTransformer[T], T, StoreOp) -> TransformerResult[
    T,
    StoreOp,
  ])?
  on_loadop : ((ModuleTransformer[T], T, LoadOp) -> TransformerResult[T, LoadOp])?
  on_extractlaneop : ((ModuleTransformer[T], T, ExtractLaneOp) -> TransformerResult[
    T,
    ExtractLaneOp,
  ])?
  on_replacelaneop : ((ModuleTransformer[T], T, ReplaceLaneOp) -> TransformerResult[
    T,
    ReplaceLaneOp,
  ])?
  on_v128shiftop : ((ModuleTransformer[T], T, V128ShiftOp) -> TransformerResult[
    T,
    V128ShiftOp,
  ])?
  on_v128ternaryop : ((ModuleTransformer[T], T, V128TernaryOp) -> TransformerResult[
    T,
    V128TernaryOp,
  ])?
  on_v128loadlaneop : ((ModuleTransformer[T], T, V128LoadLaneOp) -> TransformerResult[
    T,
    V128LoadLaneOp,
  ])?
  on_v128storelaneop : ((ModuleTransformer[T], T, V128StoreLaneOp) -> TransformerResult[
    T,
    V128StoreLaneOp,
  ])?
  on_memarg : ((ModuleTransformer[T], T, MemArg) -> TransformerResult[T, MemArg])?
}

///|
pub fn[T] ModuleTransformer::new() -> ModuleTransformer[T] {
  ModuleTransformer::{
    on_module: None,
    on_typesec: None,
    on_funcsec: None,
    on_tablesec: None,
    on_memsec: None,
    on_tagsec: None,
    on_globalsec: None,
    on_importsec: None,
    on_exportsec: None,
    on_startsec: None,
    on_elemsec: None,
    on_elemkind: None,
    on_datacntsec: None,
    on_codesec: None,
    on_datasec: None,
    on_instruction: None,
    on_tinstruction: None,
    on_expr: None,
    on_texpr: None,
    on_table: None,
    on_valtype: None,
    on_numtype: None,
    on_rectype: None,
    on_subtype: None,
    on_comptype: None,
    on_reftype: None,
    on_heaptype: None,
    on_blocktype: None,
    on_funcidx: None,
    on_typeidx: None,
    on_laneidx: None,
    on_localidx: None,
    on_globalidx: None,
    on_tableidx: None,
    on_memidx: None,
    on_labelidx: None,
    on_dataidx: None,
    on_elemidx: None,
    on_tagidx: None,
    on_name: None,
    on_externtype: None,
    on_limits: None,
    on_memtype: None,
    on_tagtype: None,
    on_export: None,
    on_global: None,
    on_globaltype: None,
    on_func: None,
    on_locals: None,
    on_externidx: None,
    on_fieldtype: None,
    on_storagetype: None,
    on_unaryop: None,
    on_binaryop: None,
    on_storeop: None,
    on_loadop: None,
    on_extractlaneop: None,
    on_replacelaneop: None,
    on_v128shiftop: None,
    on_v128ternaryop: None,
    on_v128loadlaneop: None,
    on_v128storelaneop: None,
    on_memarg: None,
  }
}

///|
pub fn[T] ModuleTransformer::on_module_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, Module) -> TransformerResult[T, Module],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_module: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_typesec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, TypeSec) -> TransformerResult[T, TypeSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_typesec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_funcsec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, FuncSec) -> TransformerResult[T, FuncSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_funcsec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_tablesec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, TableSec) -> TransformerResult[T, TableSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_tablesec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_memsec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, MemSec) -> TransformerResult[T, MemSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_memsec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_tagsec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, TagSec) -> TransformerResult[T, TagSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_tagsec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_globalsec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, GlobalSec) -> TransformerResult[T, GlobalSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_globalsec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_exportsec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, ExportSec) -> TransformerResult[T, ExportSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_exportsec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_importsec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, ImportSec) -> TransformerResult[T, ImportSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_importsec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_startsec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, StartSec) -> TransformerResult[T, StartSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_startsec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_elemsec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, ElemSec) -> TransformerResult[T, ElemSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_elemsec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_elemkind_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, ElemKind) -> TransformerResult[T, ElemKind],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_elemkind: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_datacntsec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, DataCntSec) -> TransformerResult[
    T,
    DataCntSec,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_datacntsec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_codesec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, CodeSec) -> TransformerResult[T, CodeSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_codesec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_datasec_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, DataSec) -> TransformerResult[T, DataSec],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_datasec: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_instruction_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, Instruction) -> TransformerResult[
    T,
    Instruction,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_instruction: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_tinstruction_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, TInstr) -> TransformerResult[T, TInstr],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_tinstruction: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_expr_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, Expr) -> TransformerResult[T, Expr],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_expr: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_texpr_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, TExpr) -> TransformerResult[T, TExpr],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_texpr: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_table_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, Table) -> TransformerResult[T, Table],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_table: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_valtype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, ValType) -> TransformerResult[T, ValType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_valtype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_numtype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, NumType) -> TransformerResult[T, NumType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_numtype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_rectype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, RecType) -> TransformerResult[T, RecType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_rectype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_subtype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, SubType) -> TransformerResult[T, SubType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_subtype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_comptype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, CompType) -> TransformerResult[T, CompType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_comptype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_reftype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, RefType) -> TransformerResult[T, RefType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_reftype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_heaptype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, HeapType) -> TransformerResult[T, HeapType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_heaptype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_blocktype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, BlockType) -> TransformerResult[T, BlockType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_blocktype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_funcidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, FuncIdx) -> TransformerResult[T, FuncIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_funcidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_typeidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, TypeIdx) -> TransformerResult[T, TypeIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_typeidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_laneidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, LaneIdx) -> TransformerResult[T, LaneIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_laneidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_localidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, LocalIdx) -> TransformerResult[T, LocalIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_localidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_globalidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, GlobalIdx) -> TransformerResult[T, GlobalIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_globalidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_tableidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, TableIdx) -> TransformerResult[T, TableIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_tableidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_memidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, MemIdx) -> TransformerResult[T, MemIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_memidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_labelidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, LabelIdx) -> TransformerResult[T, LabelIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_labelidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_dataidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, DataIdx) -> TransformerResult[T, DataIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_dataidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_elemidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, ElemIdx) -> TransformerResult[T, ElemIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_elemidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_tagidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, TagIdx) -> TransformerResult[T, TagIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_tagidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_name_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, Name) -> TransformerResult[T, Name],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_name: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_externtype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, ExternType) -> TransformerResult[
    T,
    ExternType,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_externtype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_limits_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, Limits) -> TransformerResult[T, Limits],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_limits: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_memtype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, MemType) -> TransformerResult[T, MemType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_memtype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_tagtype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, TagType) -> TransformerResult[T, TagType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_tagtype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_export_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, Export) -> TransformerResult[T, Export],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_export: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_global_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, Global) -> TransformerResult[T, Global],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_global: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_globaltype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, GlobalType) -> TransformerResult[
    T,
    GlobalType,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_globaltype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_func_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, Func) -> TransformerResult[T, Func],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_func: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_locals_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, Array[Locals]) -> TransformerResult[
    T,
    Array[Locals],
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_locals: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_externidx_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, ExternIdx) -> TransformerResult[T, ExternIdx],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_externidx: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_fieldtype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, FieldType) -> TransformerResult[T, FieldType],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_fieldtype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_storagetype_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, StorageType) -> TransformerResult[
    T,
    StorageType,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_storagetype: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_unaryop_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, UnaryOp) -> TransformerResult[T, UnaryOp],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_unaryop: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_binaryop_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, BinaryOp) -> TransformerResult[T, BinaryOp],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_binaryop: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_storeop_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, StoreOp) -> TransformerResult[T, StoreOp],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_storeop: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_loadop_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, LoadOp) -> TransformerResult[T, LoadOp],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_loadop: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_extractlaneop_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, ExtractLaneOp) -> TransformerResult[
    T,
    ExtractLaneOp,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_extractlaneop: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_replacelaneop_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, ReplaceLaneOp) -> TransformerResult[
    T,
    ReplaceLaneOp,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_replacelaneop: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_v128shiftop_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, V128ShiftOp) -> TransformerResult[
    T,
    V128ShiftOp,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_v128shiftop: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_v128ternaryop_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, V128TernaryOp) -> TransformerResult[
    T,
    V128TernaryOp,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_v128ternaryop: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_v128loadlaneop_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, V128LoadLaneOp) -> TransformerResult[
    T,
    V128LoadLaneOp,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_v128loadlaneop: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_v128storelaneop_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, V128StoreLaneOp) -> TransformerResult[
    T,
    V128StoreLaneOp,
  ],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_v128storelaneop: Some(evt) }
}

///|
pub fn[T] ModuleTransformer::on_memarg_evt(
  self : ModuleTransformer[T],
  evt : (ModuleTransformer[T], T, MemArg) -> TransformerResult[T, MemArg],
) -> ModuleTransformer[T] {
  ModuleTransformer::{ ..self, on_memarg: Some(evt) }
}

///|
pub fn[T, E] ModuleTransformer::walk_array(
  self : ModuleTransformer[T],
  t : T,
  f : (ModuleTransformer[T], T, E) -> TransformerResult[T, E],
  a : Array[E],
) -> TransformerResult[T, Array[E]] {
  let mut t = t
  let mut changed = false
  let a = a.copy()
  let end = a.length()
  loop 0 {
    n if n == end => break
    n => {
      let item = a[n]
      match f(self, t, item) {
        Ok(None) => continue n + 1 // No change
        Ok(Some((next_t, next_item))) => {
          t = next_t
          a[n] = next_item
          changed = true
          continue n + 1
        }
        Err(e) => return Err(e)
      }
    }
  }
  if changed {
    Ok(Some((t, a)))
  } else {
    Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_name(
  self : ModuleTransformer[T],
  t : T,
  name : Name,
) -> TransformerResult[T, Name] {
  match self.on_name {
    Some(f) => f(self, t, name)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_expr(
  self : ModuleTransformer[T],
  t : T,
  expr : Expr,
) -> TransformerResult[T, Expr] {
  match self.on_expr {
    Some(f) =>
      match f(self, t, expr) {
        Err(e) => Err(e)
        Ok(None) => self.walk_expr_default(t, expr)
        ok => ok
      }
    None => self.walk_expr_default(t, expr)
  }
}

///|
pub fn[T] ModuleTransformer::walk_texpr(
  self : ModuleTransformer[T],
  t : T,
  texpr : TExpr,
) -> TransformerResult[T, TExpr] {
  match self.on_texpr {
    Some(f) =>
      match f(self, t, texpr) {
        Err(e) => Err(e)
        Ok(None) => self.walk_texpr_default(t, texpr)
        ok => ok
      }
    None => self.walk_texpr_default(t, texpr)
  }
}

///|
pub fn[T] ModuleTransformer::walk_expr_default(
  self : ModuleTransformer[T],
  t : T,
  expr : Expr,
) -> TransformerResult[T, Expr] {
  let Expr(instructions) = expr
  match self.walk_array(t, ModuleTransformer::walk_instruction, instructions) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, instructions))) => Ok(Some((t, Expr::new(instructions))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_texpr_default(
  self : ModuleTransformer[T],
  t : T,
  expr : TExpr,
) -> TransformerResult[T, TExpr] {
  let TExpr(instructions) = expr
  let (t, instructions) = match
    self.walk_array(t, ModuleTransformer::walk_tinstruction, instructions) {
    Err(e) => return Err(e)
    Ok(None) => (t, instructions)
    Ok(Some(t)) => t
  }
  Ok(Some((t, TExpr::new(instructions))))
}

///|
pub fn[T] ModuleTransformer::walk_tinstruction(
  self : ModuleTransformer[T],
  t : T,
  tinstr : TInstr,
) -> TransformerResult[T, TInstr] {
  match self.on_tinstruction {
    Some(f) =>
      match f(self, t, tinstr) {
        Ok(None) => self.walk_tinstruction_default(t, tinstr)
        Ok(t) => Ok(t)
        Err(t) => Err(t)
      }
    None => self.walk_tinstruction_default(t, tinstr)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tinstruction_default(
  self : ModuleTransformer[T],
  t : T,
  tinstr : TInstr,
) -> TransformerResult[T, TInstr] {
  match tinstr {
    // === Constants (0 children, 1 result) ===

    TRefNull(ht) => {
      let (t, ht) = match self.walk_heaptype(t, ht) {
        Ok(None) => (t, ht)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_null(ht))))
    }
    TRefFunc(fi) => {
      let (t, fi) = match self.walk_funcidx(t, fi) {
        Ok(None) => (t, fi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_func(fi))))
    }
    // === Nullary (0 children) ===

    TLocalGet(li) => {
      let (t, li) = match self.walk_localidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::local_get(li))))
    }
    TGlobalGet(gi) => {
      let (t, gi) = match self.walk_globalidx(t, gi) {
        Ok(None) => (t, gi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::global_get(gi))))
    }
    TMemorySize(mi) => {
      let (t, mi) = match self.walk_memidx(t, mi) {
        Ok(None) => (t, mi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_size(mi))))
    }
    TTableSize(ti) => {
      let (t, ti) = match self.walk_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_size(ti))))
    }

    // === Unary (1 child) ===
    TUnary(op, i) => {
      let (t, op) = match self.walk_unaryop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::unary(op, i))))
    }
    TDrop(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::drop(i))))
    }
    TLocalSet(li, i) => {
      let (t, li) = match self.walk_localidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::local_set(li, i))))
    }
    TLocalTee(li, i) => {
      let (t, li) = match self.walk_localidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::local_tee(li, i))))
    }
    TGlobalSet(gi, i) => {
      let (t, gi) = match self.walk_globalidx(t, gi) {
        Ok(None) => (t, gi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::global_set(gi, i))))
    }
    TRefIsNull(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_is_null(i))))
    }
    TRefAsNonNull(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_as_non_null(i))))
    }
    TI31GetS(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i31_get_s(i))))
    }
    TI31GetU(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i31_get_u(i))))
    }
    TRefI31(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_i31(i))))
    }
    TArrayLen(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_len(i))))
    }
    TAnyConvertExtern(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::any_convert_extern(i))))
    }
    TExternConvertAny(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::extern_convert_any(i))))
    }
    TThrowRef(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::throw_ref(i))))
    }

    // === Binary (2 children) ===
    TBinary(op, i1, i2) => {
      let (t, op) = match self.walk_binaryop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::binary(op, i1, i2))))
    }
    TRefEq(i1, i2) => {
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_eq(i1, i2))))
    }
    TStore(op, ma, i1, i2) => {
      let (t, op) = match self.walk_storeop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ma) = match self.walk_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::store(op, ma, i1, i2))))
    }
    TMemoryAtomicNotify(ma, i1, i2) => {
      let (t, ma) = match self.walk_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_atomic_notify(ma, i1, i2))))
    }
    TAtomicRmw(op, ma, i1, i2) => {
      let (t, ma) = match self.walk_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::atomic_rmw(op, ma, i1, i2))))
    }

    // === Load (1 child - address) ===
    TLoad(op, ma, i) => {
      let (t, op) = match self.walk_loadop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ma) = match self.walk_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::load(op, ma, i))))
    }
    TAtomicFence => Ok(Some((t, TInstr::atomic_fence())))

    // === Memory operations ===
    TMemoryGrow(mi, i) => {
      let (t, mi) = match self.walk_memidx(t, mi) {
        Ok(None) => (t, mi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_grow(mi, i))))
    }
    TMemoryFill(mi, i1, i2, i3) => {
      let (t, mi) = match self.walk_memidx(t, mi) {
        Ok(None) => (t, mi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_fill(mi, i1, i2, i3))))
    }
    TMemoryCopy(mi1, mi2, i1, i2, i3) => {
      let (t, mi1) = match self.walk_memidx(t, mi1) {
        Ok(None) => (t, mi1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, mi2) = match self.walk_memidx(t, mi2) {
        Ok(None) => (t, mi2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_copy(mi1, mi2, i1, i2, i3))))
    }
    TMemoryInit(di, mi, i1, i2, i3) => {
      let (t, di) = match self.walk_dataidx(t, di) {
        Ok(None) => (t, di)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, mi) = match self.walk_memidx(t, mi) {
        Ok(None) => (t, mi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_init(di, mi, i1, i2, i3))))
    }
    TMemoryAtomicWait32(ma, i1, i2, i3) => {
      let (t, ma) = match self.walk_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_atomic_wait32(ma, i1, i2, i3))))
    }
    TMemoryAtomicWait64(ma, i1, i2, i3) => {
      let (t, ma) = match self.walk_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_atomic_wait64(ma, i1, i2, i3))))
    }
    TAtomicCmpxchg(op, ma, i1, i2, i3) => {
      let (t, ma) = match self.walk_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::atomic_cmpxchg(op, ma, i1, i2, i3))))
    }
    TDataDrop(di) => {
      let (t, di) = match self.walk_dataidx(t, di) {
        Ok(None) => (t, di)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::data_drop(di))))
    }

    // === Table operations ===
    TTableGet(ti, i) => {
      let (t, ti) = match self.walk_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_get(ti, i))))
    }
    TTableSet(ti, i1, i2) => {
      let (t, ti) = match self.walk_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_set(ti, i1, i2))))
    }
    TTableGrow(ti, i1, i2) => {
      let (t, ti) = match self.walk_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_grow(ti, i1, i2))))
    }
    TTableFill(ti, i1, i2, i3) => {
      let (t, ti) = match self.walk_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_fill(ti, i1, i2, i3))))
    }
    TTableCopy(ti1, ti2, i1, i2, i3) => {
      let (t, ti1) = match self.walk_tableidx(t, ti1) {
        Ok(None) => (t, ti1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ti2) = match self.walk_tableidx(t, ti2) {
        Ok(None) => (t, ti2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_copy(ti1, ti2, i1, i2, i3))))
    }
    TTableInit(ei, ti, i1, i2, i3) => {
      let (t, ei) = match self.walk_elemidx(t, ei) {
        Ok(None) => (t, ei)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ti) = match self.walk_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_init(ei, ti, i1, i2, i3))))
    }
    TElemDrop(ei) => {
      let (t, ei) = match self.walk_elemidx(t, ei) {
        Ok(None) => (t, ei)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::elem_drop(ei))))
    }

    // === Calls (N children based on function type) ===
    TCall(fi, i) => {
      let (t, fi) = match self.walk_funcidx(t, fi) {
        Ok(None) => (t, fi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::call(fi, i))))
    }
    TCallIndirect(tyi, tai, i0, i) => {
      let (t, tyi) = match self.walk_typeidx(t, tyi) {
        Ok(None) => (t, tyi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, tai) = match self.walk_tableidx(t, tai) {
        Ok(None) => (t, tai)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::call_indirect(tyi, tai, i0, i))))
    }
    TCallRef(tyi, i0, i) => {
      let (t, tyi) = match self.walk_typeidx(t, tyi) {
        Ok(None) => (t, tyi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::call_ref(tyi, i0, i))))
    }
    TReturnCall(fi, i) => {
      let (t, fi) = match self.walk_funcidx(t, fi) {
        Ok(None) => (t, fi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::return_call(fi, i))))
    }
    TReturnCallIndirect(tyi, tai, i0, i) => {
      let (t, tyi) = match self.walk_typeidx(t, tyi) {
        Ok(None) => (t, tyi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, tai) = match self.walk_tableidx(t, tai) {
        Ok(None) => (t, tai)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::return_call_indirect(tyi, tai, i0, i))))
    }
    TReturnCallRef(tyi, i0, i) => {
      let (t, tyi) = match self.walk_typeidx(t, tyi) {
        Ok(None) => (t, tyi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::return_call_ref(tyi, i0, i))))
    }

    // === Control flow ===
    TBlock(bt, e) => {
      let (t, bt) = match self.walk_blocktype(t, bt) {
        Ok(None) => (t, bt)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, e) = match self.walk_texpr(t, e) {
        Ok(None) => (t, e)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::block(bt, e))))
    }
    TLoop(bt, e) => {
      let (t, bt) = match self.walk_blocktype(t, bt) {
        Ok(None) => (t, bt)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, e) = match self.walk_texpr(t, e) {
        Ok(None) => (t, e)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::loop_(bt, e))))
    }
    TIf(bt, i_if, e_then, e_else_option) => {
      let (t, bt) = match self.walk_blocktype(t, bt) {
        Ok(None) => (t, bt)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i_if) = match self.walk_tinstruction(t, i_if) {
        Ok(None) => (t, i_if)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, e_then) = match self.walk_texpr(t, e_then) {
        Ok(None) => (t, e_then)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, e_else_option) = if e_else_option is Some(e_else) {
        match self.walk_texpr(t, e_else) {
          Ok(None) => (t, e_else_option)
          Ok(Some((t, e_else))) => (t, Some(e_else))
          Err(t) => return Err(t)
        }
      } else {
        (t, e_else_option)
      }
      Ok(Some((t, TInstr::if_(bt, i_if, e_then, e_else_option))))
    }
    TTryTable(bt, c, e) => {
      let (t, bt) = match self.walk_blocktype(t, bt) {
        Ok(None) => (t, bt)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, c) = match self.walk_array(t, ModuleTransformer::walk_catch, c) {
        Ok(None) => (t, c)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, e) = match self.walk_texpr(t, e) {
        Ok(None) => (t, e)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::try_table(bt, c, e))))
    }
    TThrow(ti, i) => {
      let (t, ti) = match self.walk_tagidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::throw_(ti, i))))
    }

    // === Branches ===
    TBr(li, i) => {
      let (t, li) = match self.walk_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br(li, i))))
    }
    TBrIf(li, i0, i) => {
      let (t, li) = match self.walk_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_if(li, i0, i))))
    }
    TBrTable(ls, li, i0, i) => {
      let (t, ls) = match
        self.walk_array(t, ModuleTransformer::walk_labelidx, ls) {
        Ok(None) => (t, ls)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li) = match self.walk_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_table(ls, li, i0, i))))
    }
    TBrOnNull(li, i0, i) => {
      let (t, li) = match self.walk_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_on_null(li, i0, i))))
    }
    TBrOnNonNull(li, i0, i) => {
      let (t, li) = match self.walk_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_on_non_null(li, i0, i))))
    }
    TBrOnCast(li, co, ht0, ht1, i0, i) => {
      let (t, li) = match self.walk_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ht0) = match self.walk_heaptype(t, ht0) {
        Ok(None) => (t, ht0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ht1) = match self.walk_heaptype(t, ht1) {
        Ok(None) => (t, ht1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_on_cast(li, co.0, ht0, co.1, ht1, i0, i))))
    }
    TBrOnCastFail(li, co, ht0, ht1, i0, i) => {
      let (t, li) = match self.walk_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ht0) = match self.walk_heaptype(t, ht0) {
        Ok(None) => (t, ht0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ht1) = match self.walk_heaptype(t, ht1) {
        Ok(None) => (t, ht1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_on_cast_fail(li, co.0, ht0, co.1, ht1, i0, i))))
    }
    TReturn(i) => {
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::return_(i))))
    }

    // === Select ===
    TSelect(vts_option, i0, i1, i2) => {
      let (t, vts_option) = if vts_option is Some(vts) {
        match self.walk_array(t, ModuleTransformer::walk_valtype, vts) {
          Ok(None) => (t, vts_option)
          Ok(Some((t, vts))) => (t, Some(vts))
          Err(t) => return Err(t)
        }
      } else {
        (t, vts_option)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::select(vts_option, i0, i1, i2))))
    }

    // === GC: Structs ===
    TStructNew(ti, i) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_new(ti, i))))
    }
    TStructNewDefault(ti) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_new_default(ti))))
    }
    TStructGet(ti, f, i) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_get(ti, f, i))))
    }
    TStructGetS(ti, f, i) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_get_s(ti, f, i))))
    }
    TStructGetU(ti, f, i) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_get_u(ti, f, i))))
    }
    TStructSet(ti, f, i0, i1) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_set(ti, f, i0, i1))))
    }

    // === GC: Arrays ===
    TArrayNew(ti, i0, i1) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_new(ti, i0, i1))))
    }
    TArrayNewDefault(ti, i) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_new_default(ti, i))))
    }
    TArrayNewFixed(ti, i) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_new_fixed(ti, i))))
    }
    TArrayNewData(ti, di, i0, i1) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, di) = match self.walk_dataidx(t, di) {
        Ok(None) => (t, di)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_new_data(ti, di, i0, i1))))
    }
    TArrayNewElem(ti, ei, i0, i1) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ei) = match self.walk_elemidx(t, ei) {
        Ok(None) => (t, ei)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_new_elem(ti, ei, i0, i1))))
    }
    TArrayGet(ti, i0, i1) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_get(ti, i0, i1))))
    }
    TArrayGetS(ti, i0, i1) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_get_s(ti, i0, i1))))
    }
    TArrayGetU(ti, i0, i1) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_get_u(ti, i0, i1))))
    }
    TArraySet(ti, i0, i1, i2) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_set(ti, i0, i1, i2))))
    }
    TArrayFill(ti, i0, i1, i2, i3) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_fill(ti, i0, i1, i2, i3))))
    }
    TArrayCopy(ti0, ti1, i0, i1, i2, i3, i4) => {
      let (t, ti0) = match self.walk_typeidx(t, ti0) {
        Ok(None) => (t, ti0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ti1) = match self.walk_typeidx(t, ti1) {
        Ok(None) => (t, ti1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i4) = match self.walk_tinstruction(t, i4) {
        Ok(None) => (t, i4)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_copy(ti0, ti1, i0, i1, i2, i3, i4))))
    }
    TArrayInitData(ti, di, i0, i1, i2, i3) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, di) = match self.walk_dataidx(t, di) {
        Ok(None) => (t, di)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_init_data(ti, di, i0, i1, i2, i3))))
    }
    TArrayInitElem(ti, ei, i0, i1, i2, i3) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ei) = match self.walk_elemidx(t, ei) {
        Ok(None) => (t, ei)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_init_elem(ti, ei, i0, i1, i2, i3))))
    }

    // === GC: Casts ===
    TRefGetDesc(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_get_desc(i))))
    }
    TRefTest(b, ht, i) => {
      let (t, ht) = match self.walk_heaptype(t, ht) {
        Ok(None) => (t, ht)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_test(b, ht, i))))
    }
    TRefCast(b, ht, i) => {
      let (t, ht) = match self.walk_heaptype(t, ht) {
        Ok(None) => (t, ht)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_cast(b, ht, i))))
    }
    TRefTestDesc(b, ht, i) => {
      let (t, ht) = match self.walk_heaptype(t, ht) {
        Ok(None) => (t, ht)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_test_desc(b, ht, i))))
    }
    TRefCastDescEq(b, ht, i) => {
      let (t, ht) = match self.walk_heaptype(t, ht) {
        Ok(None) => (t, ht)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_cast_desc_eq(b, ht, i))))
    }

    // === SIMD: Splat (scalar -> v128) ===
    TI8x16Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i8x16_splat(i))))
    }
    TI16x8Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i16x8_splat(i))))
    }
    TI32x4Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i32x4_splat(i))))
    }
    TI64x2Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i64x2_splat(i))))
    }
    TF32x4Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::f32x4_splat(i))))
    }
    TF64x2Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::f64x2_splat(i))))
    }

    // === SIMD: Extract lane (v128 -> scalar) ===
    TExtractLane(op, li, i) => {
      let (t, op) = match self.walk_extractlaneop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li) = match self.walk_laneidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::extract_lane(op, li, i))))
    }

    // === SIMD: Replace lane (v128, scalar -> v128) ===
    TReplaceLane(op, li, i0, i1) => {
      let (t, op) = match self.walk_replacelaneop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li) = match self.walk_laneidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::replace_lane(op, li, i0, i1))))
    }

    // === SIMD: Shuffle (v128, v128 -> v128 with 16 lane indices) ===
    TI8x16Shuffle(
      li0,
      li1,
      li2,
      li3,
      li4,
      li5,
      li6,
      li7,
      li8,
      li9,
      li10,
      li11,
      li12,
      li13,
      li14,
      li15,
      i0,
      i1
    ) => {
      let (t, li0) = match self.walk_laneidx(t, li0) {
        Ok(None) => (t, li0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li1) = match self.walk_laneidx(t, li1) {
        Ok(None) => (t, li1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li2) = match self.walk_laneidx(t, li2) {
        Ok(None) => (t, li2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li3) = match self.walk_laneidx(t, li3) {
        Ok(None) => (t, li3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li4) = match self.walk_laneidx(t, li4) {
        Ok(None) => (t, li4)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li5) = match self.walk_laneidx(t, li5) {
        Ok(None) => (t, li5)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li6) = match self.walk_laneidx(t, li6) {
        Ok(None) => (t, li6)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li7) = match self.walk_laneidx(t, li7) {
        Ok(None) => (t, li7)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li8) = match self.walk_laneidx(t, li8) {
        Ok(None) => (t, li8)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li9) = match self.walk_laneidx(t, li9) {
        Ok(None) => (t, li9)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li10) = match self.walk_laneidx(t, li10) {
        Ok(None) => (t, li10)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li11) = match self.walk_laneidx(t, li11) {
        Ok(None) => (t, li11)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li12) = match self.walk_laneidx(t, li12) {
        Ok(None) => (t, li12)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li13) = match self.walk_laneidx(t, li13) {
        Ok(None) => (t, li13)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li14) = match self.walk_laneidx(t, li14) {
        Ok(None) => (t, li14)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li15) = match self.walk_laneidx(t, li15) {
        Ok(None) => (t, li15)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(
        Some(
          (
            t,
            TInstr::i8x16_shuffle(
              li0, li1, li2, li3, li4, li5, li6, li7, li8, li9, li10, li11, li12,
              li13, li14, li15, i0, i1,
            ),
          ),
        ),
      )
    }

    // === SIMD: Swizzle (v128, v128 -> v128) ===
    TI8x16Swizzle(i0, i1) => {
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i8x16_swizzle(i0, i1))))
    }
    TI8x16RelaxedSwizzle(i0, i1) => {
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i8x16_relaxed_swizzle(i0, i1))))
    }

    // === SIMD: Shift (v128, i32 -> v128) ===
    TV128Shift(op, i0, i1) => {
      let (t, op) = match self.walk_v128shiftop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::v128_shift(op, i0, i1))))
    }

    // === SIMD: Ternary (v128, v128, v128 -> v128) ===
    TV128Ternary(op, i0, i1, i2) => {
      let (t, op) = match self.walk_v128ternaryop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::v128_ternary(op, i0, i1, i2))))
    }

    // === SIMD: Lane load (v128, addr -> v128) ===
    TV128LoadLane(op, ma, li, i0, i1) => {
      let (t, op) = match self.walk_v128loadlaneop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ma) = match self.walk_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li) = match self.walk_laneidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::v128_load_lane(op, ma, li, i0, i1))))
    }

    // === SIMD: Lane store (v128, addr -> void) ===
    TV128StoreLane(op, ma, li, i0, i1) => {
      let (t, op) = match self.walk_v128storelaneop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ma) = match self.walk_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li) = match self.walk_laneidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::v128_store_lane(op, ma, li, i0, i1))))
    }
    _ => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_instruction(
  self : ModuleTransformer[T],
  t : T,
  instr : Instruction,
) -> TransformerResult[T, Instruction] {
  match self.on_instruction {
    Some(f) =>
      match f(self, t, instr) {
        Err(e) => Err(e)
        Ok(None) => self.walk_instruction_default(t, instr)
        ok => ok
      }
    None => self.walk_instruction_default(t, instr)
  }
}

///|
pub fn[T] ModuleTransformer::walk_instruction_default(
  self : ModuleTransformer[T],
  t : T,
  instr : Instruction,
) -> TransformerResult[T, Instruction] {
  match instr {
    // Control instructions
    Block(bt, body) =>
      match self.walk_blocktype(t, bt) {
        Err(e) => Err(e)
        Ok(None) =>
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, body))) => Ok(Some((t, Instruction::block(bt, body))))
          }
        Ok(Some((t, bt))) =>
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, Instruction::block(bt, body))))
            Ok(Some((t, body))) => Ok(Some((t, Instruction::block(bt, body))))
          }
      }
    Loop(bt, body) =>
      match self.walk_blocktype(t, bt) {
        Err(e) => Err(e)
        Ok(None) =>
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, body))) => Ok(Some((t, Instruction::loop_(bt, body))))
          }
        Ok(Some((t, bt))) =>
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, Instruction::loop_(bt, body))))
            Ok(Some((t, body))) => Ok(Some((t, Instruction::loop_(bt, body))))
          }
      }
    If(bt, then_body, else_body_opt) => {
      let (t, bt) = match self.walk_blocktype(t, bt) {
        Err(e) => return Err(e)
        Ok(None) => (t, bt)
        Ok(Some((t, bt))) => (t, bt)
      }
      let (t, then_body) = match
        self.walk_array(t, ModuleTransformer::walk_instruction, then_body) {
        Err(e) => return Err(e)
        Ok(None) => (t, then_body)
        Ok(Some((t, arr))) => (t, arr)
      }
      let (t, else_body_opt) = match else_body_opt {
        None => (t, None)
        Some(else_body) =>
          match
            self.walk_array(t, ModuleTransformer::walk_instruction, else_body) {
            Err(e) => return Err(e)
            Ok(None) => (t, Some(else_body))
            Ok(Some((t, arr))) => (t, Some(arr))
          }
      }
      Ok(Some((t, Instruction::if_(bt, then_body, else_body_opt))))
    }
    TryTable(bt, catches, body) =>
      match self.walk_blocktype(t, bt) {
        Err(e) => Err(e)
        Ok(None) =>
          match self.walk_array(t, ModuleTransformer::walk_catch, catches) {
            Err(e) => Err(e)
            Ok(None) =>
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) => Ok(None)
                Ok(Some((t, body))) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
              }
            Ok(Some((t, catches))) =>
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
                Ok(Some((t, body))) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
              }
          }
        Ok(Some((t, bt))) =>
          match self.walk_array(t, ModuleTransformer::walk_catch, catches) {
            Err(e) => Err(e)
            Ok(None) =>
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
                Ok(Some((t, body))) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
              }
            Ok(Some((t, catches))) =>
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
                Ok(Some((t, body))) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
              }
          }
      }

    // Branch instructions
    Br(l) =>
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::br(l))))
      }
    BrIf(l) =>
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::br_if(l))))
      }
    BrTable(labels, default) =>
      match self.walk_array(t, ModuleTransformer::walk_labelidx, labels) {
        Err(e) => Err(e)
        Ok(None) =>
          match self.walk_labelidx(t, default) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, default))) =>
              Ok(Some((t, Instruction::br_table(labels, default))))
          }
        Ok(Some((t, labels))) =>
          match self.walk_labelidx(t, default) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, Instruction::br_table(labels, default))))
            Ok(Some((t, default))) =>
              Ok(Some((t, Instruction::br_table(labels, default))))
          }
      }
    BrOnNull(l) =>
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::br_on_null(l))))
      }
    BrOnNonNull(l) =>
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::br_on_non_null(l))))
      }
    BrOnCast(l, op, ht1, ht2) => {
      let (t, l) = match self.walk_labelidx(t, l) {
        Err(e) => return Err(e)
        Ok(None) => (t, l)
        Ok(Some((t, l))) => (t, l)
      }
      let (t, ht1) = match self.walk_heaptype(t, ht1) {
        Err(e) => return Err(e)
        Ok(None) => (t, ht1)
        Ok(Some((t, ht1))) => (t, ht1)
      }
      let (t, ht2) = match self.walk_heaptype(t, ht2) {
        Err(e) => return Err(e)
        Ok(None) => (t, ht2)
        Ok(Some((t, ht2))) => (t, ht2)
      }
      Ok(Some((t, Instruction::br_on_cast(l, op.0, ht1, op.1, ht2))))
    }
    BrOnCastFail(l, op, ht1, ht2) => {
      let (t, l) = match self.walk_labelidx(t, l) {
        Err(e) => return Err(e)
        Ok(None) => (t, l)
        Ok(Some((t, l))) => (t, l)
      }
      let (t, ht1) = match self.walk_heaptype(t, ht1) {
        Err(e) => return Err(e)
        Ok(None) => (t, ht1)
        Ok(Some((t, ht1))) => (t, ht1)
      }
      let (t, ht2) = match self.walk_heaptype(t, ht2) {
        Err(e) => return Err(e)
        Ok(None) => (t, ht2)
        Ok(Some((t, ht2))) => (t, ht2)
      }
      Ok(Some((t, Instruction::br_on_cast_fail(l, op.0, ht1, op.1, ht2))))
    }

    // Call instructions
    Call(f) =>
      match self.walk_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, Instruction::call(f))))
      }
    CallIndirect(ty, tbl) => {
      let (t, ty) = match self.walk_typeidx(t, ty) {
        Err(e) => return Err(e)
        Ok(None) => (t, ty)
        Ok(Some((t, ty))) => (t, ty)
      }
      let (t, tbl) = match self.walk_tableidx(t, tbl) {
        Err(e) => return Err(e)
        Ok(None) => (t, tbl)
        Ok(Some((t, tbl))) => (t, tbl)
      }
      Ok(Some((t, Instruction::call_indirect(ty, tbl))))
    }
    ReturnCall(f) =>
      match self.walk_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, Instruction::return_call(f))))
      }
    ReturnCallIndirect(ty, tbl) => {
      let (t, ty) = match self.walk_typeidx(t, ty) {
        Err(e) => return Err(e)
        Ok(None) => (t, ty)
        Ok(Some((t, ty))) => (t, ty)
      }
      let (t, tbl) = match self.walk_tableidx(t, tbl) {
        Err(e) => return Err(e)
        Ok(None) => (t, tbl)
        Ok(Some((t, tbl))) => (t, tbl)
      }
      Ok(Some((t, Instruction::return_call_indirect(ty, tbl))))
    }
    CallRef(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::call_ref(ty))))
      }
    ReturnCallRef(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::return_call_ref(ty))))
      }

    // Variable instructions
    LocalGet(l) =>
      match self.walk_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::local_get(l))))
      }
    LocalSet(l) =>
      match self.walk_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::local_set(l))))
      }
    LocalTee(l) =>
      match self.walk_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::local_tee(l))))
      }
    GlobalGet(g) =>
      match self.walk_globalidx(t, g) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, g))) => Ok(Some((t, Instruction::global_get(g))))
      }
    GlobalSet(g) =>
      match self.walk_globalidx(t, g) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, g))) => Ok(Some((t, Instruction::global_set(g))))
      }

    // Table instructions
    TableGet(tbl) =>
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, Instruction::table_get(tbl))))
      }
    TableSet(tbl) =>
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, Instruction::table_set(tbl))))
      }
    TableGrow(tbl) =>
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, Instruction::table_grow(tbl))))
      }
    TableSize(tbl) =>
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, Instruction::table_size(tbl))))
      }
    TableFill(tbl) =>
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, Instruction::table_fill(tbl))))
      }
    TableCopy(t1, t2) => {
      let (t, t1) = match self.walk_tableidx(t, t1) {
        Err(e) => return Err(e)
        Ok(None) => (t, t1)
        Ok(Some((t, t1))) => (t, t1)
      }
      let (t, t2) = match self.walk_tableidx(t, t2) {
        Err(e) => return Err(e)
        Ok(None) => (t, t2)
        Ok(Some((t, t2))) => (t, t2)
      }
      Ok(Some((t, Instruction::table_copy(t1, t2))))
    }
    TableInit(e, tbl) => {
      let (t, e) = match self.walk_elemidx(t, e) {
        Err(e) => return Err(e)
        Ok(None) => (t, e)
        Ok(Some((t, e))) => (t, e)
      }
      let (t, tbl) = match self.walk_tableidx(t, tbl) {
        Err(e) => return Err(e)
        Ok(None) => (t, tbl)
        Ok(Some((t, tbl))) => (t, tbl)
      }
      Ok(Some((t, Instruction::table_init(e, tbl))))
    }
    ElemDrop(e) =>
      match self.walk_elemidx(t, e) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, e))) => Ok(Some((t, Instruction::elem_drop(e))))
      }

    // Reference instructions
    RefNull(ht) =>
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, Instruction::ref_null(ht))))
      }
    RefFunc(f) =>
      match self.walk_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, Instruction::ref_func(f))))
      }
    RefTest(nullable, ht) =>
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, Instruction::ref_test(nullable, ht))))
      }
    RefCast(nullable, ht) =>
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, Instruction::ref_cast(nullable, ht))))
      }
    RefGetDesc => Ok(Some((t, Instruction::ref_get_desc())))
    RefTestDesc(nullable, ht) =>
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) =>
          Ok(Some((t, Instruction::ref_test_desc(nullable, ht))))
      }
    RefCastDescEq(nullable, ht) =>
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) =>
          Ok(Some((t, Instruction::ref_cast_desc_eq(nullable, ht))))
      }

    // Struct/Array instructions
    StructNew(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_new(ty))))
      }
    StructNewDefault(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_new_default(ty))))
      }
    StructGet(ty, f) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_get(ty, f))))
      }
    StructGetS(ty, f) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_get_s(ty, f))))
      }
    StructGetU(ty, f) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_get_u(ty, f))))
      }
    StructSet(ty, f) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_set(ty, f))))
      }
    ArrayNew(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_new(ty))))
      }
    ArrayNewDefault(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_new_default(ty))))
      }
    ArrayNewFixed(ty, n) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_new_fixed(ty, n))))
      }
    ArrayNewData(ty, n) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_new_data(ty, n))))
      }
    ArrayNewElem(ty, e) => {
      let (t, ty) = match self.walk_typeidx(t, ty) {
        Err(e) => return Err(e)
        Ok(None) => (t, ty)
        Ok(Some((t, ty))) => (t, ty)
      }
      let (t, e) = match self.walk_elemidx(t, e) {
        Err(e) => return Err(e)
        Ok(None) => (t, e)
        Ok(Some((t, e))) => (t, e)
      }
      Ok(Some((t, Instruction::array_new_elem(ty, e))))
    }
    ArrayGet(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_get(ty))))
      }
    ArrayGetS(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_get_s(ty))))
      }
    ArrayGetU(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_get_u(ty))))
      }
    ArraySet(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_set(ty))))
      }
    ArrayFill(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_fill(ty))))
      }
    ArrayCopy(t1, t2) => {
      let (t, t1) = match self.walk_typeidx(t, t1) {
        Err(e) => return Err(e)
        Ok(None) => (t, t1)
        Ok(Some((t, t1))) => (t, t1)
      }
      let (t, t2) = match self.walk_typeidx(t, t2) {
        Err(e) => return Err(e)
        Ok(None) => (t, t2)
        Ok(Some((t, t2))) => (t, t2)
      }
      Ok(Some((t, Instruction::array_copy(t1, t2))))
    }
    ArrayInitData(ty, d) => {
      let (t, ty) = match self.walk_typeidx(t, ty) {
        Err(e) => return Err(e)
        Ok(None) => (t, ty)
        Ok(Some((t, ty))) => (t, ty)
      }
      let (t, d) = match self.walk_dataidx(t, d) {
        Err(e) => return Err(e)
        Ok(None) => (t, d)
        Ok(Some((t, d))) => (t, d)
      }
      Ok(Some((t, Instruction::array_init_data(ty, d))))
    }
    ArrayInitElem(ty, e) => {
      let (t, ty) = match self.walk_typeidx(t, ty) {
        Err(e) => return Err(e)
        Ok(None) => (t, ty)
        Ok(Some((t, ty))) => (t, ty)
      }
      let (t, e) = match self.walk_elemidx(t, e) {
        Err(e) => return Err(e)
        Ok(None) => (t, e)
        Ok(Some((t, e))) => (t, e)
      }
      Ok(Some((t, Instruction::array_init_elem(ty, e))))
    }

    // Memory instructions
    MemoryAtomicNotify(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) =>
          Ok(Some((t, Instruction::memory_atomic_notify(ma))))
      }
    MemoryAtomicWait32(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) =>
          Ok(Some((t, Instruction::memory_atomic_wait32(ma))))
      }
    MemoryAtomicWait64(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) =>
          Ok(Some((t, Instruction::memory_atomic_wait64(ma))))
      }
    AtomicFence => Ok(Some((t, Instruction::atomic_fence())))
    I32AtomicLoad(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_load(ma))))
      }
    I64AtomicLoad(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_load(ma))))
      }
    I32AtomicLoad8U(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_load8_u(ma))))
      }
    I32AtomicLoad16U(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_load16_u(ma))))
      }
    I64AtomicLoad8U(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_load8_u(ma))))
      }
    I64AtomicLoad16U(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_load16_u(ma))))
      }
    I64AtomicLoad32U(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_load32_u(ma))))
      }
    I32AtomicStore(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_store(ma))))
      }
    I64AtomicStore(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_store(ma))))
      }
    I32AtomicStore8(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_store8(ma))))
      }
    I32AtomicStore16(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_store16(ma))))
      }
    I64AtomicStore8(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_store8(ma))))
      }
    I64AtomicStore16(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_store16(ma))))
      }
    I64AtomicStore32(ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_store32(ma))))
      }
    AtomicRmw(op, ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::atomic_rmw(op, ma))))
      }
    AtomicCmpxchg(op, ma) =>
      match self.walk_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::atomic_cmpxchg(op, ma))))
      }
    MemorySize(m) =>
      match self.walk_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, Instruction::memory_size(m))))
      }
    MemoryGrow(m) =>
      match self.walk_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, Instruction::memory_grow(m))))
      }
    MemoryFill(m) =>
      match self.walk_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, Instruction::memory_fill(m))))
      }
    MemoryCopy(m1, m2) => {
      let (t, m1) = match self.walk_memidx(t, m1) {
        Err(e) => return Err(e)
        Ok(None) => (t, m1)
        Ok(Some((t, m1))) => (t, m1)
      }
      let (t, m2) = match self.walk_memidx(t, m2) {
        Err(e) => return Err(e)
        Ok(None) => (t, m2)
        Ok(Some((t, m2))) => (t, m2)
      }
      Ok(Some((t, Instruction::memory_copy(m1, m2))))
    }
    MemoryInit(d, m) => {
      let (t, d) = match self.walk_dataidx(t, d) {
        Err(e) => return Err(e)
        Ok(None) => (t, d)
        Ok(Some((t, d))) => (t, d)
      }
      let (t, m) = match self.walk_memidx(t, m) {
        Err(e) => return Err(e)
        Ok(None) => (t, m)
        Ok(Some((t, m))) => (t, m)
      }
      Ok(Some((t, Instruction::memory_init(d, m))))
    }
    DataDrop(d) =>
      match self.walk_dataidx(t, d) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, d))) => Ok(Some((t, Instruction::data_drop(d))))
      }

    // Exception instructions
    Throw(ty) =>
      match self.walk_tagidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::throw_(ty))))
      }

    // Select with types
    Select(types) =>
      match types {
        None => Ok(None)
        Some(types) =>
          match self.walk_array(t, ModuleTransformer::walk_valtype, types) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, types))) =>
              Ok(Some((t, Instruction::select(types=Some(types)))))
          }
      }

    // All other instructions pass through unchanged
    _ => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_blocktype(
  self : ModuleTransformer[T],
  t : T,
  bt : BlockType,
) -> TransformerResult[T, BlockType] {
  match self.on_blocktype {
    Some(f) =>
      match f(self, t, bt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_blocktype_default(t, bt)
        ok => ok
      }
    None => self.walk_blocktype_default(t, bt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_blocktype_default(
  self : ModuleTransformer[T],
  t : T,
  bt : BlockType,
) -> TransformerResult[T, BlockType] {
  match bt {
    ValTypeBlockType(vt) =>
      match self.walk_valtype(t, vt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, vt))) => Ok(Some((t, BlockType::val_type(vt))))
      }
    TypeIdxBlockType(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, BlockType::type_idx(ty))))
      }
    _ => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_catch(
  self : ModuleTransformer[T],
  t : T,
  c : Catch,
) -> TransformerResult[T, Catch] {
  match c {
    Catch(tag, label) => {
      let (t, tag) = match self.walk_tagidx(t, tag) {
        Err(e) => return Err(e)
        Ok(None) => (t, tag)
        Ok(Some((t, tag))) => (t, tag)
      }
      let (t, label) = match self.walk_labelidx(t, label) {
        Err(e) => return Err(e)
        Ok(None) => (t, label)
        Ok(Some((t, label))) => (t, label)
      }
      Ok(Some((t, Catch::new(tag, label))))
    }
    CatchRef(tag, label) => {
      let (t, tag) = match self.walk_tagidx(t, tag) {
        Err(e) => return Err(e)
        Ok(None) => (t, tag)
        Ok(Some((t, tag))) => (t, tag)
      }
      let (t, label) = match self.walk_labelidx(t, label) {
        Err(e) => return Err(e)
        Ok(None) => (t, label)
        Ok(Some((t, label))) => (t, label)
      }
      Ok(Some((t, Catch::ref_(tag, label))))
    }
    CatchAll(label) =>
      match self.walk_labelidx(t, label) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, label))) => Ok(Some((t, Catch::all(label))))
      }
    CatchAllRef(label) =>
      match self.walk_labelidx(t, label) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, label))) => Ok(Some((t, Catch::all_ref(label))))
      }
  }
}

// Index walkers - leaf nodes

///|
pub fn[T] ModuleTransformer::walk_funcidx(
  self : ModuleTransformer[T],
  t : T,
  idx : FuncIdx,
) -> TransformerResult[T, FuncIdx] {
  match self.on_funcidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_typeidx(
  self : ModuleTransformer[T],
  t : T,
  idx : TypeIdx,
) -> TransformerResult[T, TypeIdx] {
  match self.on_typeidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_localidx(
  self : ModuleTransformer[T],
  t : T,
  idx : LocalIdx,
) -> TransformerResult[T, LocalIdx] {
  match self.on_localidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_globalidx(
  self : ModuleTransformer[T],
  t : T,
  idx : GlobalIdx,
) -> TransformerResult[T, GlobalIdx] {
  match self.on_globalidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tableidx(
  self : ModuleTransformer[T],
  t : T,
  idx : TableIdx,
) -> TransformerResult[T, TableIdx] {
  match self.on_tableidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_memidx(
  self : ModuleTransformer[T],
  t : T,
  idx : MemIdx,
) -> TransformerResult[T, MemIdx] {
  match self.on_memidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_labelidx(
  self : ModuleTransformer[T],
  t : T,
  idx : LabelIdx,
) -> TransformerResult[T, LabelIdx] {
  match self.on_labelidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_laneidx(
  self : ModuleTransformer[T],
  t : T,
  idx : LaneIdx,
) -> TransformerResult[T, LaneIdx] {
  match self.on_laneidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_dataidx(
  self : ModuleTransformer[T],
  t : T,
  idx : DataIdx,
) -> TransformerResult[T, DataIdx] {
  match self.on_dataidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_elemidx(
  self : ModuleTransformer[T],
  t : T,
  idx : ElemIdx,
) -> TransformerResult[T, ElemIdx] {
  match self.on_elemidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tagidx(
  self : ModuleTransformer[T],
  t : T,
  idx : TagIdx,
) -> TransformerResult[T, TagIdx] {
  match self.on_tagidx {
    Some(f) => f(self, t, idx)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_valtype(
  self : ModuleTransformer[T],
  t : T,
  vt : ValType,
) -> TransformerResult[T, ValType] {
  match self.on_valtype {
    Some(f) =>
      match f(self, t, vt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_valtype_default(t, vt)
        ok => ok
      }
    None => self.walk_valtype_default(t, vt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_valtype_default(
  self : ModuleTransformer[T],
  t : T,
  vt : ValType,
) -> TransformerResult[T, ValType] {
  match vt {
    RefTypeValType(rt) =>
      match self.walk_reftype(t, rt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, rt))) => Ok(Some((t, ValType::ref_type(rt))))
      }
    NumTypeValType(nt) =>
      match self.walk_numtype(t, nt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, nt))) => Ok(Some((t, ValType::num_type(nt))))
      }
    _ => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_numtype(
  self : ModuleTransformer[T],
  t : T,
  nt : NumType,
) -> TransformerResult[T, NumType] {
  match self.on_numtype {
    Some(f) => f(self, t, nt)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_reftype(
  self : ModuleTransformer[T],
  t : T,
  rt : RefType,
) -> TransformerResult[T, RefType] {
  match self.on_reftype {
    Some(f) =>
      match f(self, t, rt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_reftype_default(t, rt)
        ok => ok
      }
    None => self.walk_reftype_default(t, rt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_reftype_default(
  self : ModuleTransformer[T],
  t : T,
  rt : RefType,
) -> TransformerResult[T, RefType] {
  match rt {
    HeapTypeRefType(nullable, ht) =>
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, RefType::new(nullable, ht))))
      }
    _ => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_heaptype(
  self : ModuleTransformer[T],
  t : T,
  ht : HeapType,
) -> TransformerResult[T, HeapType] {
  match self.on_heaptype {
    Some(f) =>
      match f(self, t, ht) {
        Err(e) => Err(e)
        Ok(None) => self.walk_heaptype_default(t, ht)
        ok => ok
      }
    None => self.walk_heaptype_default(t, ht)
  }
}

///|
pub fn[T] ModuleTransformer::walk_heaptype_default(
  self : ModuleTransformer[T],
  t : T,
  ht : HeapType,
) -> TransformerResult[T, HeapType] {
  match ht {
    HeapType(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, HeapType::new(ty))))
      }
    _ => Ok(None)
  }
}

// Sections

///|
pub fn[T] ModuleTransformer::walk_customsec(
  self : ModuleTransformer[T],
  t : T,
  sec : CustomSec,
) -> TransformerResult[T, CustomSec] {
  let CustomSec(n, d) = sec
  match self.walk_name(t, n) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, n))) => Ok(Some((t, CustomSec::new(n, d))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_customsecs(
  self : ModuleTransformer[T],
  t : T,
  secs : Array[CustomSec],
) -> TransformerResult[T, Array[CustomSec]] {
  self.walk_array(t, ModuleTransformer::walk_customsec, secs)
}

///|
pub fn[T] ModuleTransformer::walk_module(
  self : ModuleTransformer[T],
  t : T,
  mod : Module,
) -> TransformerResult[T, Module] {
  match self.on_module {
    Some(f) =>
      match f(self, t, mod) {
        Err(e) => Err(e)
        Ok(None) => self.walk_module_default(t, mod)
        ok => ok
      }
    None => self.walk_module_default(t, mod)
  }
}

///|
pub fn[T] ModuleTransformer::walk_module_default(
  self : ModuleTransformer[T],
  t : T,
  mod : Module,
) -> TransformerResult[T, Module] {
  let {
    custom_secs,
    type_sec,
    import_sec,
    func_sec,
    table_sec,
    mem_sec,
    tag_sec,
    global_sec,
    export_sec,
    start_sec,
    elem_sec,
    data_cnt_sec,
    code_sec,
    data_sec,
  } = mod
  let (t, custom_secs) = match self.walk_customsecs(t, custom_secs) {
    Err(e) => return Err(e)
    Ok(None) => (t, custom_secs)
    Ok(Some(v)) => v
  }
  let (t, type_sec) = match type_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_typesec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, import_sec) = match import_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_importsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, func_sec) = match func_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_funcsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, table_sec) = match table_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_tablesec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, mem_sec) = match mem_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_memsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, tag_sec) = match tag_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_tagsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, global_sec) = match global_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_globalsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, export_sec) = match export_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_exportsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, start_sec) = match start_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_startsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, elem_sec) = match elem_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_elemsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, data_cnt_sec) = match data_cnt_sec {
    None => (t, None)
    Some(data_cnt_sec) =>
      match self.walk_datacntsec(t, data_cnt_sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(data_cnt_sec))
        Ok(Some((t, data_cnt_sec))) => (t, Some(data_cnt_sec))
      }
  }
  let (t, code_sec) = match code_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_codesec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, data_sec) = match data_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_datasec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  Ok(
    Some(
      (
        t,
        Module::new(
          custom_secs~,
          type_sec~,
          import_sec~,
          func_sec~,
          table_sec~,
          mem_sec~,
          tag_sec~,
          global_sec~,
          export_sec~,
          start_sec~,
          elem_sec~,
          data_cnt_sec~,
          code_sec~,
          data_sec~,
        ),
      ),
    ),
  )
}

///|
pub fn[T] ModuleTransformer::walk_datasec(
  self : ModuleTransformer[T],
  t : T,
  ds : DataSec,
) -> TransformerResult[T, DataSec] {
  match self.on_datasec {
    Some(f) =>
      match f(self, t, ds) {
        Err(e) => Err(e)
        Ok(None) => self.walk_datasec_default(t, ds)
        ok => ok
      }
    None => self.walk_datasec_default(t, ds)
  }
}

///|
pub fn[T] ModuleTransformer::walk_datasec_default(
  self : ModuleTransformer[T],
  t : T,
  ds : DataSec,
) -> TransformerResult[T, DataSec] {
  let DataSec(ds) = ds
  match self.walk_array(t, ModuleTransformer::walk_data, ds) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, ds))) => Ok(Some((t, DataSec::new(ds))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_codesec(
  self : ModuleTransformer[T],
  t : T,
  cs : CodeSec,
) -> TransformerResult[T, CodeSec] {
  match self.on_codesec {
    Some(f) =>
      match f(self, t, cs) {
        Err(e) => Err(e)
        Ok(None) => self.walk_codesec_default(t, cs)
        ok => ok
      }
    None => self.walk_codesec_default(t, cs)
  }
}

///|
pub fn[T] ModuleTransformer::walk_codesec_default(
  self : ModuleTransformer[T],
  t : T,
  cs : CodeSec,
) -> TransformerResult[T, CodeSec] {
  let CodeSec(fs) = cs
  match self.walk_array(t, ModuleTransformer::walk_func, fs) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, fs))) => Ok(Some((t, CodeSec::new(fs))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_datacntsec(
  self : ModuleTransformer[T],
  t : T,
  dcs : DataCntSec,
) -> TransformerResult[T, DataCntSec] {
  match self.on_datacntsec {
    Some(f) => f(self, t, dcs)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_elemsec(
  self : ModuleTransformer[T],
  t : T,
  es : ElemSec,
) -> TransformerResult[T, ElemSec] {
  match self.on_elemsec {
    Some(f) =>
      match f(self, t, es) {
        Err(e) => Err(e)
        Ok(None) => self.walk_elemsec_default(t, es)
        ok => ok
      }
    None => self.walk_elemsec_default(t, es)
  }
}

///|
pub fn[T] ModuleTransformer::walk_elemsec_default(
  self : ModuleTransformer[T],
  t : T,
  es : ElemSec,
) -> TransformerResult[T, ElemSec] {
  let ElemSec(es) = es
  match self.walk_array(t, ModuleTransformer::walk_elem, es) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, es))) => Ok(Some((t, ElemSec::new(es))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_startsec(
  self : ModuleTransformer[T],
  t : T,
  ss : StartSec,
) -> TransformerResult[T, StartSec] {
  match self.on_startsec {
    Some(f) =>
      match f(self, t, ss) {
        Err(e) => Err(e)
        Ok(None) => self.walk_startsec_default(t, ss)
        ok => ok
      }
    None => self.walk_startsec_default(t, ss)
  }
}

///|
pub fn[T] ModuleTransformer::walk_startsec_default(
  self : ModuleTransformer[T],
  t : T,
  ss : StartSec,
) -> TransformerResult[T, StartSec] {
  let StartSec(fidx) = ss
  match self.walk_funcidx(t, fidx) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, fidx))) => Ok(Some((t, StartSec::new(fidx))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_exportsec(
  self : ModuleTransformer[T],
  t : T,
  es : ExportSec,
) -> TransformerResult[T, ExportSec] {
  match self.on_exportsec {
    Some(f) =>
      match f(self, t, es) {
        Err(e) => Err(e)
        Ok(None) => self.walk_exportsec_default(t, es)
        ok => ok
      }
    None => self.walk_exportsec_default(t, es)
  }
}

///|
pub fn[T] ModuleTransformer::walk_importsec_default(
  self : ModuleTransformer[T],
  t : T,
  es : ImportSec,
) -> TransformerResult[T, ImportSec] {
  let ImportSec(ims) = es
  match self.walk_array(t, ModuleTransformer::walk_import, ims) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, ims))) => Ok(Some((t, ImportSec::new(ims))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_exportsec_default(
  self : ModuleTransformer[T],
  t : T,
  es : ExportSec,
) -> TransformerResult[T, ExportSec] {
  let ExportSec(es) = es
  match self.walk_array(t, ModuleTransformer::walk_export, es) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, es))) => Ok(Some((t, ExportSec::new(es))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_tagsec(
  self : ModuleTransformer[T],
  t : T,
  ts : TagSec,
) -> TransformerResult[T, TagSec] {
  match self.on_tagsec {
    Some(f) =>
      match f(self, t, ts) {
        Err(e) => Err(e)
        Ok(None) => self.walk_tagsec_default(t, ts)
        ok => ok
      }
    None => self.walk_tagsec_default(t, ts)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tagsec_default(
  self : ModuleTransformer[T],
  t : T,
  ts : TagSec,
) -> TransformerResult[T, TagSec] {
  let TagSec(tags) = ts
  match self.walk_array(t, ModuleTransformer::walk_tagtype, tags) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, tags))) => Ok(Some((t, TagSec::new(tags))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_memsec(
  self : ModuleTransformer[T],
  t : T,
  ms : MemSec,
) -> TransformerResult[T, MemSec] {
  match self.on_memsec {
    Some(f) =>
      match f(self, t, ms) {
        Err(e) => Err(e)
        Ok(None) => self.walk_memsec_default(t, ms)
        ok => ok
      }
    None => self.walk_memsec_default(t, ms)
  }
}

///|
pub fn[T] ModuleTransformer::walk_memsec_default(
  self : ModuleTransformer[T],
  t : T,
  ms : MemSec,
) -> TransformerResult[T, MemSec] {
  let MemSec(m) = ms
  match self.walk_array(t, ModuleTransformer::walk_memtype, m) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, m))) => Ok(Some((t, MemSec::new(m))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_tablesec(
  self : ModuleTransformer[T],
  t : T,
  ts : TableSec,
) -> TransformerResult[T, TableSec] {
  match self.on_tablesec {
    Some(f) =>
      match f(self, t, ts) {
        Err(e) => Err(e)
        Ok(None) => self.walk_tablesec_default(t, ts)
        ok => ok
      }
    None => self.walk_tablesec_default(t, ts)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tablesec_default(
  self : ModuleTransformer[T],
  t : T,
  ts : TableSec,
) -> TransformerResult[T, TableSec] {
  let TableSec(tts) = ts
  match self.walk_array(t, ModuleTransformer::walk_table, tts) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, tts))) => Ok(Some((t, TableSec::new(tts))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_func(
  self : ModuleTransformer[T],
  t : T,
  func : Func,
) -> TransformerResult[T, Func] {
  match self.on_func {
    Some(f) =>
      match f(self, t, func) {
        Err(e) => Err(e)
        Ok(None) => self.walk_func_default(t, func)
        ok => ok
      }
    None => self.walk_func_default(t, func)
  }
}

///|
pub fn[T] ModuleTransformer::walk_func_default(
  self : ModuleTransformer[T],
  t : T,
  f : Func,
) -> TransformerResult[T, Func] {
  match f {
    Func(locals, body) => {
      let mut locals = locals
      let t = match self.walk_locals(t, locals) {
        Err(e) => return Err(e)
        Ok(None) => t
        Ok(Some((t, ls))) => {
          locals = ls
          t
        }
      }
      match self.walk_expr(t, body) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, body))) => Ok(Some((t, Func::new(locals, body))))
      }
    }
    TFunc(locals, tbody) => {
      let (t, locals) = match
        self.walk_array(t, ModuleTransformer::walk_valtype, locals) {
        Ok(None) => (t, locals)
        Ok(Some((t, locals))) => (t, locals)
        Err(t) => return Err(t)
      }
      let (t, tbody) = match self.walk_texpr(t, tbody) {
        Ok(None) => (t, tbody)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, Func::t_func(locals, tbody))))
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_locals(
  self : ModuleTransformer[T],
  t : T,
  l : Array[Locals],
) -> TransformerResult[T, Array[Locals]] {
  match self.on_locals {
    Some(f) => f(self, t, l)
    None => self.walk_locals_default(t, l)
  }
}

///|
pub fn[T] ModuleTransformer::walk_locals_default(
  self : ModuleTransformer[T],
  t : T,
  ls : Array[Locals],
) -> TransformerResult[T, Array[Locals]] {
  self.walk_array(t, ModuleTransformer::walk_single_local, ls)
}

///|
pub fn[T] ModuleTransformer::walk_single_local(
  self : ModuleTransformer[T],
  t : T,
  l : Locals,
) -> TransformerResult[T, Locals] {
  let Locals(count, vt) = l
  match self.walk_valtype(t, vt) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, vt))) => Ok(Some((t, Locals::new(count, vt))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_importsec(
  self : ModuleTransformer[T],
  t : T,
  ims : ImportSec,
) -> TransformerResult[T, ImportSec] {
  match self.on_importsec {
    Some(f) =>
      match f(self, t, ims) {
        Err(e) => Err(e)
        Ok(None) => self.walk_importsec_default(t, ims)
        ok => ok
      }
    None => self.walk_importsec_default(t, ims)
  }
}

///|
pub fn[T] ModuleTransformer::walk_export(
  self : ModuleTransformer[T],
  t : T,
  expt : Export,
) -> TransformerResult[T, Export] {
  match self.on_export {
    Some(f) =>
      match f(self, t, expt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_export_default(t, expt)
        ok => ok
      }
    None => self.walk_export_default(t, expt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_export_default(
  self : ModuleTransformer[T],
  t : T,
  ex : Export,
) -> TransformerResult[T, Export] {
  let Export(n, ei) = ex
  let (t, n) = match self.walk_name(t, n) {
    Err(e) => return Err(e)
    Ok(None) => (t, n)
    Ok(Some((t, n))) => (t, n)
  }
  let (t, ei) = match self.walk_externidx(t, ei) {
    Err(e) => return Err(e)
    Ok(None) => (t, ei)
    Ok(Some((t, ei))) => (t, ei)
  }
  Ok(Some((t, Export::new(n, ei))))
}

///|
pub fn[T] ModuleTransformer::walk_externidx(
  self : ModuleTransformer[T],
  t : T,
  ex : ExternIdx,
) -> TransformerResult[T, ExternIdx] {
  match self.on_externidx {
    Some(f) =>
      match f(self, t, ex) {
        Err(e) => Err(e)
        Ok(None) => self.walk_externidx_default(t, ex)
        ok => ok
      }
    None => self.walk_externidx_default(t, ex)
  }
}

///|
pub fn[T] ModuleTransformer::walk_externidx_default(
  self : ModuleTransformer[T],
  t : T,
  ex : ExternIdx,
) -> TransformerResult[T, ExternIdx] {
  match ex {
    FuncExternIdx(fi) =>
      match self.walk_funcidx(t, fi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, fi))) => Ok(Some((t, ExternIdx::func(fi))))
      }
    TableExternIdx(ti) =>
      match self.walk_tableidx(t, ti) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ti))) => Ok(Some((t, ExternIdx::table(ti))))
      }
    MemExternIdx(mi) =>
      match self.walk_memidx(t, mi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, mi))) => Ok(Some((t, ExternIdx::mem(mi))))
      }
    GlobalExternIdx(gi) =>
      match self.walk_globalidx(t, gi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, gi))) => Ok(Some((t, ExternIdx::global(gi))))
      }
    TagExternIdx(ti) =>
      match self.walk_tagidx(t, ti) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ti))) => Ok(Some((t, ExternIdx::tag(ti))))
      }
  }
}

///|
pub fn[T] ModuleTransformer::walk_table(
  self : ModuleTransformer[T],
  t : T,
  tbl : Table,
) -> TransformerResult[T, Table] {
  match self.on_table {
    Some(f) =>
      match f(self, t, tbl) {
        Err(e) => Err(e)
        Ok(None) => self.walk_table_default(t, tbl)
        ok => ok
      }
    None => self.walk_table_default(t, tbl)
  }
}

///|
pub fn[T] ModuleTransformer::walk_table_default(
  self : ModuleTransformer[T],
  t : T,
  tbl : Table,
) -> TransformerResult[T, Table] {
  let Table(tt, e_option) = tbl
  let (t, tt) = match self.walk_tabletype(t, tt) {
    Err(e) => return Err(e)
    Ok(None) => (t, tt)
    Ok(Some((t, tt))) => (t, tt)
  }
  let (t, e_option) = match e_option {
    None => (t, None)
    Some(e) =>
      match self.walk_expr(t, e) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(e))
        Ok(Some((t, e))) => (t, Some(e))
      }
  }
  Ok(Some((t, Table::new(tt, e_option))))
}

///|
pub fn[T] ModuleTransformer::walk_import(
  self : ModuleTransformer[T],
  t : T,
  im : Import,
) -> TransformerResult[T, Import] {
  let Import(n1, n2, ty) = im
  let (t, n1) = match self.walk_name(t, n1) {
    Err(e) => return Err(e)
    Ok(None) => (t, n1)
    Ok(Some((t, n1))) => (t, n1)
  }
  let (t, n2) = match self.walk_name(t, n2) {
    Err(e) => return Err(e)
    Ok(None) => (t, n2)
    Ok(Some((t, n2))) => (t, n2)
  }
  let (t, ty) = match self.walk_externtype(t, ty) {
    Err(e) => return Err(e)
    Ok(None) => (t, ty)
    Ok(Some((t, ty))) => (t, ty)
  }
  Ok(Some((t, Import::new(n1, n2, ty))))
}

///|
pub fn[T] ModuleTransformer::walk_externtype(
  self : ModuleTransformer[T],
  t : T,
  ex : ExternType,
) -> TransformerResult[T, ExternType] {
  match self.on_externtype {
    Some(f) => f(self, t, ex)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tagtype(
  self : ModuleTransformer[T],
  t : T,
  tt : TagType,
) -> TransformerResult[T, TagType] {
  match self.on_tagtype {
    Some(f) =>
      match f(self, t, tt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_tagtype_default(t, tt)
        ok => ok
      }
    None => self.walk_tagtype_default(t, tt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tagtype_default(
  self : ModuleTransformer[T],
  t : T,
  tt : TagType,
) -> TransformerResult[T, TagType] {
  let TagType(ti) = tt
  match self.walk_typeidx(t, ti) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, ti))) => Ok(Some((t, TagType::new(ti))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_memtype(
  self : ModuleTransformer[T],
  t : T,
  mt : MemType,
) -> TransformerResult[T, MemType] {
  match self.on_memtype {
    Some(f) =>
      match f(self, t, mt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_memtype_default(t, mt)
        ok => ok
      }
    None => self.walk_memtype_default(t, mt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_memtype_default(
  self : ModuleTransformer[T],
  t : T,
  mt : MemType,
) -> TransformerResult[T, MemType] {
  let MemType(l) = mt
  match self.walk_limits(t, l) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, l))) => Ok(Some((t, MemType::new(l))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_tabletype(
  self : ModuleTransformer[T],
  t : T,
  tt : TableType,
) -> TransformerResult[T, TableType] {
  let TableType(rt, l) = tt
  let (t, rt) = match self.walk_reftype(t, rt) {
    Err(e) => return Err(e)
    Ok(None) => (t, rt)
    Ok(Some((t, rt))) => (t, rt)
  }
  let (t, l) = match self.walk_limits(t, l) {
    Err(e) => return Err(e)
    Ok(None) => (t, l)
    Ok(Some((t, l))) => (t, l)
  }
  Ok(Some((t, TableType::new(rt, l))))
}

///|
pub fn[T] ModuleTransformer::walk_limits(
  self : ModuleTransformer[T],
  t : T,
  l : Limits,
) -> TransformerResult[T, Limits] {
  match self.on_limits {
    Some(f) => f(self, t, l)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_typesec(
  self : ModuleTransformer[T],
  t : T,
  ts : TypeSec,
) -> TransformerResult[T, TypeSec] {
  match self.on_typesec {
    Some(f) =>
      match f(self, t, ts) {
        Err(e) => Err(e)
        Ok(None) => self.walk_typesec_default(t, ts)
        ok => ok
      }
    None => self.walk_typesec_default(t, ts)
  }
}

///|
pub fn[T] ModuleTransformer::walk_typesec_default(
  self : ModuleTransformer[T],
  t : T,
  ts : TypeSec,
) -> TransformerResult[T, TypeSec] {
  let TypeSec(rectypes) = ts
  match self.walk_array(t, ModuleTransformer::walk_rectype, rectypes) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, rectypes))) => Ok(Some((t, TypeSec::new(rectypes))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_rectype(
  self : ModuleTransformer[T],
  t : T,
  rt : RecType,
) -> TransformerResult[T, RecType] {
  match self.on_rectype {
    Some(f) =>
      match f(self, t, rt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_rectype_default(t, rt)
        ok => ok
      }
    None => self.walk_rectype_default(t, rt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_rectype_default(
  self : ModuleTransformer[T],
  t : T,
  rt : RecType,
) -> TransformerResult[T, RecType] {
  match rt {
    SingleRecType(st) =>
      match self.walk_subtype(t, st) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, st))) => Ok(Some((t, RecType::new(st))))
      }
    GroupRecType(sts) =>
      match self.walk_array(t, ModuleTransformer::walk_subtype, sts) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, sts))) => Ok(Some((t, RecType::group(sts))))
      }
  }
}

///|
pub fn[T] ModuleTransformer::walk_subtype(
  self : ModuleTransformer[T],
  t : T,
  st : SubType,
) -> TransformerResult[T, SubType] {
  match self.on_subtype {
    Some(f) =>
      match f(self, t, st) {
        Err(e) => Err(e)
        Ok(None) => self.walk_subtype_default(t, st)
        ok => ok
      }
    None => self.walk_subtype_default(t, st)
  }
}

///|
pub fn[T] ModuleTransformer::walk_subtype_default(
  self : ModuleTransformer[T],
  t : T,
  st : SubType,
) -> TransformerResult[T, SubType] {
  match st {
    SubType(f, supers, ct) => {
      let (t, supers) = match
        self.walk_array(t, ModuleTransformer::walk_typeidx, supers) {
        Err(e) => return Err(e)
        Ok(None) => (t, supers)
        Ok(Some((t, supers))) => (t, supers)
      }
      let (t, ct) = match self.walk_comptype(t, ct) {
        Err(e) => return Err(e)
        Ok(None) => (t, ct)
        Ok(Some((t, ct))) => (t, ct)
      }
      Ok(Some((t, SubType::new(f, supers, ct))))
    }
    CompTypeSubType(ct) =>
      match self.walk_comptype(t, ct) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ct))) => Ok(Some((t, SubType::comp_type(ct))))
      }
  }
}

///|
pub fn[T] ModuleTransformer::walk_comptype(
  self : ModuleTransformer[T],
  t : T,
  ct : CompType,
) -> TransformerResult[T, CompType] {
  match self.on_comptype {
    Some(f) =>
      match f(self, t, ct) {
        Err(e) => Err(e)
        Ok(None) => self.walk_comptype_default(t, ct)
        ok => ok
      }
    None => self.walk_comptype_default(t, ct)
  }
}

///|
pub fn[T] ModuleTransformer::walk_comptype_default(
  self : ModuleTransformer[T],
  t : T,
  ct : CompType,
) -> TransformerResult[T, CompType] {
  match ct {
    FuncCompType(params, results) => {
      let (t, params) = match
        self.walk_array(t, ModuleTransformer::walk_valtype, params) {
        Err(e) => return Err(e)
        Ok(None) => (t, params)
        Ok(Some((t, params))) => (t, params)
      }
      let (t, results) = match
        self.walk_array(t, ModuleTransformer::walk_valtype, results) {
        Err(e) => return Err(e)
        Ok(None) => (t, results)
        Ok(Some((t, results))) => (t, results)
      }
      Ok(Some((t, CompType::func(params, results))))
    }
    StructCompType(fields) =>
      match self.walk_array(t, ModuleTransformer::walk_fieldtype, fields) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, fields))) => Ok(Some((t, CompType::struct_(fields))))
      }
    ArrayCompType(ft) =>
      match self.walk_fieldtype(t, ft) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ft))) => Ok(Some((t, CompType::array(ft))))
      }
  }
}

///|
pub fn[T] ModuleTransformer::walk_fieldtype(
  self : ModuleTransformer[T],
  t : T,
  ft : FieldType,
) -> TransformerResult[T, FieldType] {
  match self.on_fieldtype {
    Some(f) =>
      match f(self, t, ft) {
        Err(e) => Err(e)
        Ok(None) => self.walk_fieldtype_default(t, ft)
        ok => ok
      }
    None => self.walk_fieldtype_default(t, ft)
  }
}

///|
pub fn[T] ModuleTransformer::walk_fieldtype_default(
  self : ModuleTransformer[T],
  t : T,
  ft : FieldType,
) -> TransformerResult[T, FieldType] {
  let FieldType(st, mut_) = ft
  match self.walk_storagetype(t, st) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, st))) => Ok(Some((t, FieldType::new(st, mut_))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_storagetype(
  self : ModuleTransformer[T],
  t : T,
  st : StorageType,
) -> TransformerResult[T, StorageType] {
  match self.on_storagetype {
    Some(f) =>
      match f(self, t, st) {
        Err(e) => Err(e)
        Ok(None) => self.walk_storagetype_default(t, st)
        ok => ok
      }
    None => self.walk_storagetype_default(t, st)
  }
}

///|
pub fn[T] ModuleTransformer::walk_storagetype_default(
  self : ModuleTransformer[T],
  t : T,
  st : StorageType,
) -> TransformerResult[T, StorageType] {
  match st {
    ValTypeStorageType(vt) =>
      match self.walk_valtype(t, vt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, vt))) => Ok(Some((t, StorageType::val_type(vt))))
      }
    PackTypeStorageType(_) => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_globalsec(
  self : ModuleTransformer[T],
  t : T,
  gs : GlobalSec,
) -> TransformerResult[T, GlobalSec] {
  match self.on_globalsec {
    Some(f) =>
      match f(self, t, gs) {
        Err(e) => Err(e)
        Ok(None) => self.walk_globalsec_default(t, gs)
        ok => ok
      }
    None => self.walk_globalsec_default(t, gs)
  }
}

///|
pub fn[T] ModuleTransformer::walk_globalsec_default(
  self : ModuleTransformer[T],
  t : T,
  gs : GlobalSec,
) -> TransformerResult[T, GlobalSec] {
  let GlobalSec(gs) = gs
  match self.walk_array(t, ModuleTransformer::walk_global, gs) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, gs))) => Ok(Some((t, GlobalSec::new(gs))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_global(
  self : ModuleTransformer[T],
  t : T,
  g : Global,
) -> TransformerResult[T, Global] {
  match self.on_global {
    Some(f) =>
      match f(self, t, g) {
        Err(e) => Err(e)
        Ok(None) => self.walk_global_default(t, g)
        ok => ok
      }
    None => self.walk_global_default(t, g)
  }
}

///|
pub fn[T] ModuleTransformer::walk_global_default(
  self : ModuleTransformer[T],
  t : T,
  g : Global,
) -> TransformerResult[T, Global] {
  let Global(gt, init) = g
  let (t, gt) = match self.walk_globaltype(t, gt) {
    Err(e) => return Err(e)
    Ok(None) => (t, gt)
    Ok(Some((t, gt))) => (t, gt)
  }
  let (t, init) = match self.walk_expr(t, init) {
    Err(e) => return Err(e)
    Ok(None) => (t, init)
    Ok(Some((t, init))) => (t, init)
  }
  Ok(Some((t, Global::new(gt, init))))
}

///|
pub fn[T] ModuleTransformer::walk_globaltype(
  self : ModuleTransformer[T],
  t : T,
  gt : GlobalType,
) -> TransformerResult[T, GlobalType] {
  match self.on_globaltype {
    Some(f) =>
      match f(self, t, gt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_globaltype_default(t, gt)
        ok => ok
      }
    None => self.walk_globaltype_default(t, gt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_globaltype_default(
  self : ModuleTransformer[T],
  t : T,
  gt : GlobalType,
) -> TransformerResult[T, GlobalType] {
  let GlobalType(vt, mutable) = gt
  match self.walk_valtype(t, vt) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, vt))) => Ok(Some((t, GlobalType::new(vt, mutable))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_elem(
  self : ModuleTransformer[T],
  t : T,
  e : Elem,
) -> TransformerResult[T, Elem] {
  let Elem(mode, kind) = e
  let (t, mode) = match self.walk_elemmode(t, mode) {
    Err(e) => return Err(e)
    Ok(None) => (t, mode)
    Ok(Some((t, mode))) => (t, mode)
  }
  let (t, kind) = match self.walk_elemkind(t, kind) {
    Err(e) => return Err(e)
    Ok(None) => (t, kind)
    Ok(Some((t, kind))) => (t, kind)
  }
  Ok(Some((t, Elem::new(mode, kind))))
}

///|
pub fn[T] ModuleTransformer::walk_elemmode(
  self : ModuleTransformer[T],
  t : T,
  mode : ElemMode,
) -> TransformerResult[T, ElemMode] {
  match mode {
    Active(tidx, offset) => {
      let (t, tidx) = match self.walk_tableidx(t, tidx) {
        Err(e) => return Err(e)
        Ok(None) => (t, tidx)
        Ok(Some((t, tidx))) => (t, tidx)
      }
      let (t, offset) = match self.walk_expr(t, offset) {
        Err(e) => return Err(e)
        Ok(None) => (t, offset)
        Ok(Some((t, offset))) => (t, offset)
      }
      Ok(Some((t, ElemMode::active(tidx, offset))))
    }
    _ => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_elemkind(
  self : ModuleTransformer[T],
  t : T,
  ek : ElemKind,
) -> TransformerResult[T, ElemKind] {
  match self.on_elemkind {
    Some(f) =>
      match f(self, t, ek) {
        Err(e) => Err(e)
        Ok(None) => self.walk_elemkind_default(t, ek)
        ok => ok
      }
    None => self.walk_elemkind_default(t, ek)
  }
}

///|
pub fn[T] ModuleTransformer::walk_elemkind_default(
  self : ModuleTransformer[T],
  t : T,
  kind : ElemKind,
) -> TransformerResult[T, ElemKind] {
  match kind {
    FuncsElemKind(idxs) =>
      match self.walk_array(t, ModuleTransformer::walk_funcidx, idxs) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, idxs))) => Ok(Some((t, ElemKind::funcs(idxs))))
      }
    FuncExprsElemKind(exprs) =>
      match self.walk_array(t, ModuleTransformer::walk_expr, exprs) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, exprs))) => Ok(Some((t, ElemKind::func_exprs(exprs))))
      }
    TypedExprsElemKind(rt, exprs) => {
      let (t, rt) = match self.walk_reftype(t, rt) {
        Err(e) => return Err(e)
        Ok(None) => (t, rt)
        Ok(Some((t, rt))) => (t, rt)
      }
      let (t, exprs) = match
        self.walk_array(t, ModuleTransformer::walk_expr, exprs) {
        Err(e) => return Err(e)
        Ok(None) => (t, exprs)
        Ok(Some((t, exprs))) => (t, exprs)
      }
      Ok(Some((t, ElemKind::typed_exprs(rt, exprs))))
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_data(
  self : ModuleTransformer[T],
  t : T,
  d : Data,
) -> TransformerResult[T, Data] {
  let Data(mode, bytes) = d
  let (t, mode) = match self.walk_datamode(t, mode) {
    Err(e) => return Err(e)
    Ok(None) => (t, mode)
    Ok(Some((t, mode))) => (t, mode)
  }
  Ok(Some((t, Data::new(mode, bytes))))
}

///|
pub fn[T] ModuleTransformer::walk_datamode(
  self : ModuleTransformer[T],
  t : T,
  mode : DataMode,
) -> TransformerResult[T, DataMode] {
  match mode {
    Active(midx, offset) => {
      let (t, midx) = match self.walk_memidx(t, midx) {
        Err(e) => return Err(e)
        Ok(None) => (t, midx)
        Ok(Some((t, midx))) => (t, midx)
      }
      let (t, offset) = match self.walk_expr(t, offset) {
        Err(e) => return Err(e)
        Ok(None) => (t, offset)
        Ok(Some((t, offset))) => (t, offset)
      }
      Ok(Some((t, DataMode::active(midx, offset))))
    }
    Passive => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_funcsec(
  self : ModuleTransformer[T],
  t : T,
  fs : FuncSec,
) -> TransformerResult[T, FuncSec] {
  match self.on_funcsec {
    Some(f) =>
      match f(self, t, fs) {
        Err(e) => Err(e)
        Ok(None) => self.walk_funcsec_default(t, fs)
        ok => ok
      }
    None => self.walk_funcsec_default(t, fs)
  }
}

///|
pub fn[T] ModuleTransformer::walk_funcsec_default(
  self : ModuleTransformer[T],
  t : T,
  fs : FuncSec,
) -> TransformerResult[T, FuncSec] {
  let FuncSec(idxs) = fs
  match self.walk_array(t, ModuleTransformer::walk_typeidx, idxs) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, idxs))) => Ok(Some((t, FuncSec::new(idxs))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_unaryop(
  self : ModuleTransformer[T],
  t : T,
  op : UnaryOp,
) -> TransformerResult[T, UnaryOp] {
  match self.on_unaryop {
    Some(f) => f(self, t, op)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_binaryop(
  self : ModuleTransformer[T],
  t : T,
  op : BinaryOp,
) -> TransformerResult[T, BinaryOp] {
  match self.on_binaryop {
    Some(f) => f(self, t, op)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_storeop(
  self : ModuleTransformer[T],
  t : T,
  op : StoreOp,
) -> TransformerResult[T, StoreOp] {
  match self.on_storeop {
    Some(f) => f(self, t, op)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_memarg(
  self : ModuleTransformer[T],
  t : T,
  ma : MemArg,
) -> TransformerResult[T, MemArg] {
  match self.on_memarg {
    Some(f) => f(self, t, ma)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_loadop(
  self : ModuleTransformer[T],
  t : T,
  op : LoadOp,
) -> TransformerResult[T, LoadOp] {
  match self.on_loadop {
    Some(f) => f(self, t, op)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_extractlaneop(
  self : ModuleTransformer[T],
  t : T,
  op : ExtractLaneOp,
) -> TransformerResult[T, ExtractLaneOp] {
  match self.on_extractlaneop {
    Some(f) => f(self, t, op)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_replacelaneop(
  self : ModuleTransformer[T],
  t : T,
  op : ReplaceLaneOp,
) -> TransformerResult[T, ReplaceLaneOp] {
  match self.on_replacelaneop {
    Some(f) => f(self, t, op)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_v128shiftop(
  self : ModuleTransformer[T],
  t : T,
  op : V128ShiftOp,
) -> TransformerResult[T, V128ShiftOp] {
  match self.on_v128shiftop {
    Some(f) => f(self, t, op)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_v128ternaryop(
  self : ModuleTransformer[T],
  t : T,
  op : V128TernaryOp,
) -> TransformerResult[T, V128TernaryOp] {
  match self.on_v128ternaryop {
    Some(f) => f(self, t, op)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_v128loadlaneop(
  self : ModuleTransformer[T],
  t : T,
  op : V128LoadLaneOp,
) -> TransformerResult[T, V128LoadLaneOp] {
  match self.on_v128loadlaneop {
    Some(f) => f(self, t, op)
    None => Ok(None)
  }
}

///|
pub fn[T] ModuleTransformer::walk_v128storelaneop(
  self : ModuleTransformer[T],
  t : T,
  op : V128StoreLaneOp,
) -> TransformerResult[T, V128StoreLaneOp] {
  match self.on_v128storelaneop {
    Some(f) => f(self, t, op)
    None => Ok(None)
  }
}
