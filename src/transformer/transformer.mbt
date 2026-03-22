///|
type TransformerOptResult[T, Elem, Err] = Result[(T, Elem)?, Err]

///|
pub type TransformerResult[T, Elem, Err] = Result[(Elem, T), Err]

///|
pub enum VisitAction[T, Elem, E] {
  Mutate(T?, Bool)
  Replace(Elem, T?, Bool)
  Skip
  Error(E)
}

///|
pub fn[T, Elem, Err] mutate(
  t : T,
  skip? : Bool = false,
) -> VisitAction[T, Elem, Err] {
  VisitAction::Mutate(Some(t), skip)
}

///|
pub fn[T, Elem, Err] replace(
  elem : Elem,
  t : T,
  skip? : Bool = false,
) -> VisitAction[T, Elem, Err] {
  VisitAction::Replace(elem, Some(t), skip)
}

///|
pub fn[T, Elem, Err] skip() -> VisitAction[T, Elem, Err] {
  VisitAction::Skip
}

///|
pub fn[T, Elem, Err] error(err : Err) -> VisitAction[T, Elem, Err] {
  VisitAction::Error(err)
}

///|
pub fn[T, Elem, Err] change(t : T, elem : Elem) -> VisitAction[T, Elem, Err] {
  replace(elem, t, skip=true)
}

///|
pub fn[T, Elem, Err] unchanged() -> VisitAction[T, Elem, Err] {
  VisitAction::Mutate(None, false)
}

///|
pub fn[T, Elem, Err] from_walk(
  out : TransformerResult[T, Elem, Err],
  skip? : Bool = true,
) -> VisitAction[T, Elem, Err] {
  match out {
    Ok((elem, t)) => replace(elem, t, skip~)
    Err(e) => error(e)
  }
}

///|
fn[T, Elem, Err] ModuleTransformer::apply_action_opt(
  self : ModuleTransformer[T, Err],
  t : T,
  elem : Elem,
  action : VisitAction[T, Elem, Err],
  default_walk : (ModuleTransformer[T, Err], T, Elem) -> TransformerOptResult[
    T,
    Elem,
    Err,
  ],
) -> TransformerOptResult[T, Elem, Err] {
  match action {
    Mutate(next_t_opt, skip_children) => {
      let next_t = match next_t_opt {
        Some(v) => v
        None => t
      }
      if skip_children {
        Ok(Some((next_t, elem)))
      } else {
        match default_walk(self, next_t, elem) {
          Ok(Some(v)) => Ok(Some(v))
          Ok(None) => Ok(Some((next_t, elem)))
          Err(e) => Err(e)
        }
      }
    }
    Replace(next_elem, next_t_opt, skip_children) => {
      let next_t = match next_t_opt {
        Some(v) => v
        None => t
      }
      if skip_children {
        Ok(Some((next_t, next_elem)))
      } else {
        match default_walk(self, next_t, next_elem) {
          Ok(Some(v)) => Ok(Some(v))
          Ok(None) => Ok(Some((next_t, next_elem)))
          Err(e) => Err(e)
        }
      }
    }
    Skip => Ok(Some((t, elem)))
    Error(e) => Err(e)
  }
}

///|
fn[T, Elem, Err] ModuleTransformer::no_children_opt(
  _self : ModuleTransformer[T, Err],
  _t : T,
  _elem : Elem,
) -> TransformerOptResult[T, Elem, Err] {
  Ok(None)
}

// Transformer Definition

///|

///|
pub struct ModuleTransformer[T, Err] {
  on_module : ((ModuleTransformer[T, Err], T, Module) -> VisitAction[
    T,
    Module,
    Err,
  ])?
  on_typesec : ((ModuleTransformer[T, Err], T, TypeSec) -> VisitAction[
    T,
    TypeSec,
    Err,
  ])?
  on_funcsec : ((ModuleTransformer[T, Err], T, FuncSec) -> VisitAction[
    T,
    FuncSec,
    Err,
  ])?
  on_tablesec : ((ModuleTransformer[T, Err], T, TableSec) -> VisitAction[
    T,
    TableSec,
    Err,
  ])?
  on_memsec : ((ModuleTransformer[T, Err], T, MemSec) -> VisitAction[
    T,
    MemSec,
    Err,
  ])?
  on_tagsec : ((ModuleTransformer[T, Err], T, TagSec) -> VisitAction[
    T,
    TagSec,
    Err,
  ])?
  on_globalsec : ((ModuleTransformer[T, Err], T, GlobalSec) -> VisitAction[
    T,
    GlobalSec,
    Err,
  ])?
  on_exportsec : ((ModuleTransformer[T, Err], T, ExportSec) -> VisitAction[
    T,
    ExportSec,
    Err,
  ])?
  on_importsec : ((ModuleTransformer[T, Err], T, ImportSec) -> VisitAction[
    T,
    ImportSec,
    Err,
  ])?
  on_startsec : ((ModuleTransformer[T, Err], T, StartSec) -> VisitAction[
    T,
    StartSec,
    Err,
  ])?
  on_elemsec : ((ModuleTransformer[T, Err], T, ElemSec) -> VisitAction[
    T,
    ElemSec,
    Err,
  ])?
  on_elemkind : ((ModuleTransformer[T, Err], T, ElemKind) -> VisitAction[
    T,
    ElemKind,
    Err,
  ])?
  on_datacntsec : ((ModuleTransformer[T, Err], T, DataCntSec) -> VisitAction[
    T,
    DataCntSec,
    Err,
  ])?
  on_codesec : ((ModuleTransformer[T, Err], T, CodeSec) -> VisitAction[
    T,
    CodeSec,
    Err,
  ])?
  on_datasec : ((ModuleTransformer[T, Err], T, DataSec) -> VisitAction[
    T,
    DataSec,
    Err,
  ])?
  on_instruction : ((ModuleTransformer[T, Err], T, Instruction) -> VisitAction[
    T,
    Instruction,
    Err,
  ])?
  on_tinstruction : ((ModuleTransformer[T, Err], T, TInstr) -> VisitAction[
    T,
    TInstr,
    Err,
  ])?
  on_expr : ((ModuleTransformer[T, Err], T, Expr) -> VisitAction[T, Expr, Err])?
  on_texpr : ((ModuleTransformer[T, Err], T, TExpr) -> VisitAction[
    T,
    TExpr,
    Err,
  ])?
  on_table : ((ModuleTransformer[T, Err], T, Table) -> VisitAction[
    T,
    Table,
    Err,
  ])?
  on_valtype : ((ModuleTransformer[T, Err], T, ValType) -> VisitAction[
    T,
    ValType,
    Err,
  ])?
  on_numtype : ((ModuleTransformer[T, Err], T, NumType) -> VisitAction[
    T,
    NumType,
    Err,
  ])?
  on_rectype : ((ModuleTransformer[T, Err], T, RecType) -> VisitAction[
    T,
    RecType,
    Err,
  ])?
  on_subtype : ((ModuleTransformer[T, Err], T, SubType) -> VisitAction[
    T,
    SubType,
    Err,
  ])?
  on_comptype : ((ModuleTransformer[T, Err], T, CompType) -> VisitAction[
    T,
    CompType,
    Err,
  ])?
  on_reftype : ((ModuleTransformer[T, Err], T, RefType) -> VisitAction[
    T,
    RefType,
    Err,
  ])?
  on_heaptype : ((ModuleTransformer[T, Err], T, HeapType) -> VisitAction[
    T,
    HeapType,
    Err,
  ])?
  on_blocktype : ((ModuleTransformer[T, Err], T, BlockType) -> VisitAction[
    T,
    BlockType,
    Err,
  ])?
  on_funcidx : ((ModuleTransformer[T, Err], T, FuncIdx) -> VisitAction[
    T,
    FuncIdx,
    Err,
  ])?
  on_typeidx : ((ModuleTransformer[T, Err], T, TypeIdx) -> VisitAction[
    T,
    TypeIdx,
    Err,
  ])?
  on_laneidx : ((ModuleTransformer[T, Err], T, LaneIdx) -> VisitAction[
    T,
    LaneIdx,
    Err,
  ])?
  on_localidx : ((ModuleTransformer[T, Err], T, LocalIdx) -> VisitAction[
    T,
    LocalIdx,
    Err,
  ])?
  on_globalidx : ((ModuleTransformer[T, Err], T, GlobalIdx) -> VisitAction[
    T,
    GlobalIdx,
    Err,
  ])?
  on_tableidx : ((ModuleTransformer[T, Err], T, TableIdx) -> VisitAction[
    T,
    TableIdx,
    Err,
  ])?
  on_memidx : ((ModuleTransformer[T, Err], T, MemIdx) -> VisitAction[
    T,
    MemIdx,
    Err,
  ])?
  on_labelidx : ((ModuleTransformer[T, Err], T, LabelIdx) -> VisitAction[
    T,
    LabelIdx,
    Err,
  ])?
  on_dataidx : ((ModuleTransformer[T, Err], T, DataIdx) -> VisitAction[
    T,
    DataIdx,
    Err,
  ])?
  on_elemidx : ((ModuleTransformer[T, Err], T, ElemIdx) -> VisitAction[
    T,
    ElemIdx,
    Err,
  ])?
  on_tagidx : ((ModuleTransformer[T, Err], T, TagIdx) -> VisitAction[
    T,
    TagIdx,
    Err,
  ])?
  on_name : ((ModuleTransformer[T, Err], T, Name) -> VisitAction[T, Name, Err])?
  on_externtype : ((ModuleTransformer[T, Err], T, ExternType) -> VisitAction[
    T,
    ExternType,
    Err,
  ])?
  on_limits : ((ModuleTransformer[T, Err], T, Limits) -> VisitAction[
    T,
    Limits,
    Err,
  ])?
  on_memtype : ((ModuleTransformer[T, Err], T, MemType) -> VisitAction[
    T,
    MemType,
    Err,
  ])?
  on_tagtype : ((ModuleTransformer[T, Err], T, TagType) -> VisitAction[
    T,
    TagType,
    Err,
  ])?
  on_export : ((ModuleTransformer[T, Err], T, Export) -> VisitAction[
    T,
    Export,
    Err,
  ])?
  on_global : ((ModuleTransformer[T, Err], T, Global) -> VisitAction[
    T,
    Global,
    Err,
  ])?
  on_globaltype : ((ModuleTransformer[T, Err], T, GlobalType) -> VisitAction[
    T,
    GlobalType,
    Err,
  ])?
  on_func : ((ModuleTransformer[T, Err], T, Func) -> VisitAction[T, Func, Err])?
  on_locals : ((ModuleTransformer[T, Err], T, Locals) -> VisitAction[
    T,
    Locals,
    Err,
  ])?
  on_externidx : ((ModuleTransformer[T, Err], T, ExternIdx) -> VisitAction[
    T,
    ExternIdx,
    Err,
  ])?
  on_fieldtype : ((ModuleTransformer[T, Err], T, FieldType) -> VisitAction[
    T,
    FieldType,
    Err,
  ])?
  on_storagetype : ((ModuleTransformer[T, Err], T, StorageType) -> VisitAction[
    T,
    StorageType,
    Err,
  ])?
  on_unaryop : ((ModuleTransformer[T, Err], T, UnaryOp) -> VisitAction[
    T,
    UnaryOp,
    Err,
  ])?
  on_binaryop : ((ModuleTransformer[T, Err], T, BinaryOp) -> VisitAction[
    T,
    BinaryOp,
    Err,
  ])?
  on_storeop : ((ModuleTransformer[T, Err], T, StoreOp) -> VisitAction[
    T,
    StoreOp,
    Err,
  ])?
  on_loadop : ((ModuleTransformer[T, Err], T, LoadOp) -> VisitAction[
    T,
    LoadOp,
    Err,
  ])?
  on_extractlaneop : ((ModuleTransformer[T, Err], T, ExtractLaneOp) -> VisitAction[
    T,
    ExtractLaneOp,
    Err,
  ])?
  on_replacelaneop : ((ModuleTransformer[T, Err], T, ReplaceLaneOp) -> VisitAction[
    T,
    ReplaceLaneOp,
    Err,
  ])?
  on_v128shiftop : ((ModuleTransformer[T, Err], T, V128ShiftOp) -> VisitAction[
    T,
    V128ShiftOp,
    Err,
  ])?
  on_v128ternaryop : ((ModuleTransformer[T, Err], T, V128TernaryOp) -> VisitAction[
    T,
    V128TernaryOp,
    Err,
  ])?
  on_v128loadlaneop : ((ModuleTransformer[T, Err], T, V128LoadLaneOp) -> VisitAction[
    T,
    V128LoadLaneOp,
    Err,
  ])?
  on_v128storelaneop : ((ModuleTransformer[T, Err], T, V128StoreLaneOp) -> VisitAction[
    T,
    V128StoreLaneOp,
    Err,
  ])?
  on_memarg : ((ModuleTransformer[T, Err], T, MemArg) -> VisitAction[
    T,
    MemArg,
    Err,
  ])?
}

///|
pub fn[T, Err] ModuleTransformer::new() -> ModuleTransformer[T, Err] {
  ModuleTransformer::{
    on_module: None,
    on_typesec: None,
    on_funcsec: None,
    on_tablesec: None,
    on_memsec: None,
    on_tagsec: None,
    on_globalsec: None,
    on_exportsec: None,
    on_importsec: None,
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
pub fn[T, Err] ModuleTransformer::on_module_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, Module) -> VisitAction[T, Module, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_module: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_typesec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, TypeSec) -> VisitAction[T, TypeSec, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_typesec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_funcsec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, FuncSec) -> VisitAction[T, FuncSec, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_funcsec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_tablesec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, TableSec) -> VisitAction[
    T,
    TableSec,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_tablesec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_memsec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, MemSec) -> VisitAction[T, MemSec, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_memsec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_tagsec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, TagSec) -> VisitAction[T, TagSec, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_tagsec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_globalsec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, GlobalSec) -> VisitAction[
    T,
    GlobalSec,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_globalsec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_exportsec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, ExportSec) -> VisitAction[
    T,
    ExportSec,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_exportsec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_importsec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, ImportSec) -> VisitAction[
    T,
    ImportSec,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_importsec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_startsec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, StartSec) -> VisitAction[
    T,
    StartSec,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_startsec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_elemsec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, ElemSec) -> VisitAction[T, ElemSec, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_elemsec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_elemkind_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, ElemKind) -> VisitAction[
    T,
    ElemKind,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_elemkind: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_datacntsec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, DataCntSec) -> VisitAction[
    T,
    DataCntSec,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_datacntsec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_codesec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, CodeSec) -> VisitAction[T, CodeSec, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_codesec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_datasec_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, DataSec) -> VisitAction[T, DataSec, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_datasec: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_instruction_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, Instruction) -> VisitAction[
    T,
    Instruction,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_instruction: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_tinstruction_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, TInstr) -> VisitAction[T, TInstr, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_tinstruction: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_expr_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, Expr) -> VisitAction[T, Expr, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_expr: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_texpr_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, TExpr) -> VisitAction[T, TExpr, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_texpr: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_table_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, Table) -> VisitAction[T, Table, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_table: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_valtype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, ValType) -> VisitAction[T, ValType, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_valtype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_numtype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, NumType) -> VisitAction[T, NumType, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_numtype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_rectype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, RecType) -> VisitAction[T, RecType, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_rectype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_subtype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, SubType) -> VisitAction[T, SubType, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_subtype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_comptype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, CompType) -> VisitAction[
    T,
    CompType,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_comptype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_reftype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, RefType) -> VisitAction[T, RefType, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_reftype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_heaptype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, HeapType) -> VisitAction[
    T,
    HeapType,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_heaptype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_blocktype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, BlockType) -> VisitAction[
    T,
    BlockType,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_blocktype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_funcidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, FuncIdx) -> VisitAction[T, FuncIdx, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_funcidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_typeidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, TypeIdx) -> VisitAction[T, TypeIdx, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_typeidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_laneidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, LaneIdx) -> VisitAction[T, LaneIdx, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_laneidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_localidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, LocalIdx) -> VisitAction[
    T,
    LocalIdx,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_localidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_globalidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, GlobalIdx) -> VisitAction[
    T,
    GlobalIdx,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_globalidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_tableidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, TableIdx) -> VisitAction[
    T,
    TableIdx,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_tableidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_memidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, MemIdx) -> VisitAction[T, MemIdx, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_memidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_labelidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, LabelIdx) -> VisitAction[
    T,
    LabelIdx,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_labelidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_dataidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, DataIdx) -> VisitAction[T, DataIdx, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_dataidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_elemidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, ElemIdx) -> VisitAction[T, ElemIdx, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_elemidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_tagidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, TagIdx) -> VisitAction[T, TagIdx, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_tagidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_name_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, Name) -> VisitAction[T, Name, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_name: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_externtype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, ExternType) -> VisitAction[
    T,
    ExternType,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_externtype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_limits_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, Limits) -> VisitAction[T, Limits, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_limits: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_memtype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, MemType) -> VisitAction[T, MemType, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_memtype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_tagtype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, TagType) -> VisitAction[T, TagType, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_tagtype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_export_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, Export) -> VisitAction[T, Export, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_export: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_global_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, Global) -> VisitAction[T, Global, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_global: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_globaltype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, GlobalType) -> VisitAction[
    T,
    GlobalType,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_globaltype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_func_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, Func) -> VisitAction[T, Func, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_func: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_locals_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, Locals) -> VisitAction[T, Locals, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_locals: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_externidx_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, ExternIdx) -> VisitAction[
    T,
    ExternIdx,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_externidx: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_fieldtype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, FieldType) -> VisitAction[
    T,
    FieldType,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_fieldtype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_storagetype_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, StorageType) -> VisitAction[
    T,
    StorageType,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_storagetype: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_unaryop_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, UnaryOp) -> VisitAction[T, UnaryOp, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_unaryop: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_binaryop_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, BinaryOp) -> VisitAction[
    T,
    BinaryOp,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_binaryop: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_storeop_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, StoreOp) -> VisitAction[T, StoreOp, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_storeop: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_loadop_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, LoadOp) -> VisitAction[T, LoadOp, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_loadop: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_extractlaneop_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, ExtractLaneOp) -> VisitAction[
    T,
    ExtractLaneOp,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_extractlaneop: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_replacelaneop_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, ReplaceLaneOp) -> VisitAction[
    T,
    ReplaceLaneOp,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_replacelaneop: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_v128shiftop_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, V128ShiftOp) -> VisitAction[
    T,
    V128ShiftOp,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_v128shiftop: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_v128ternaryop_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, V128TernaryOp) -> VisitAction[
    T,
    V128TernaryOp,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_v128ternaryop: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_v128loadlaneop_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, V128LoadLaneOp) -> VisitAction[
    T,
    V128LoadLaneOp,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_v128loadlaneop: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_v128storelaneop_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, V128StoreLaneOp) -> VisitAction[
    T,
    V128StoreLaneOp,
    Err,
  ],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_v128storelaneop: Some(evt) }
}

///|
pub fn[T, Err] ModuleTransformer::on_memarg_evt(
  self : ModuleTransformer[T, Err],
  evt : (ModuleTransformer[T, Err], T, MemArg) -> VisitAction[T, MemArg, Err],
) -> ModuleTransformer[T, Err] {
  ModuleTransformer::{ ..self, on_memarg: Some(evt) }
}

///|
fn[T, E, Err] ModuleTransformer::walk_opt_array(
  self : ModuleTransformer[T, Err],
  t : T,
  f : (ModuleTransformer[T, Err], T, E) -> TransformerOptResult[T, E, Err],
  a : Array[E],
) -> TransformerOptResult[T, Array[E], Err] {
  let mut t = t
  let mut changed = false
  let mut out : Array[E]? = None
  let end = a.length()
  loop 0 {
    n if n == end => break
    n => {
      let item = a[n]
      match f(self, t, item) {
        Ok(None) => continue n + 1 // No change
        Ok(Some((next_t, next_item))) => {
          t = next_t
          changed = true
          let items = match out {
            Some(items) => items
            None => a.copy()
          }
          items[n] = next_item
          out = Some(items)
          continue n + 1
        }
        Err(e) => return Err(e)
      }
    }
  }
  if changed {
    match out {
      Some(items) => Ok(Some((t, items)))
      None => Ok(None)
    }
  } else {
    Ok(None)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_name(
  self : ModuleTransformer[T, Err],
  t : T,
  name : Name,
) -> TransformerOptResult[T, Name, Err] {
  match self.on_name {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        name,
        f(self, t, name),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, name)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_expr(
  self : ModuleTransformer[T, Err],
  t : T,
  expr : Expr,
) -> TransformerOptResult[T, Expr, Err] {
  match self.on_expr {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        expr,
        f(self, t, expr),
        ModuleTransformer::walk_opt_expr_default,
      )
    None => ModuleTransformer::walk_opt_expr_default(self, t, expr)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_texpr(
  self : ModuleTransformer[T, Err],
  t : T,
  texpr : TExpr,
) -> TransformerOptResult[T, TExpr, Err] {
  match self.on_texpr {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        texpr,
        f(self, t, texpr),
        ModuleTransformer::walk_opt_texpr_default,
      )
    None => ModuleTransformer::walk_opt_texpr_default(self, t, texpr)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_expr_default(
  self : ModuleTransformer[T, Err],
  t : T,
  expr : Expr,
) -> TransformerOptResult[T, Expr, Err] {
  let Expr(instructions) = expr
  match
    self.walk_opt_array(
      t,
      ModuleTransformer::walk_opt_instruction,
      instructions,
    ) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, instructions))) => Ok(Some((t, Expr::new(instructions))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_texpr_default(
  self : ModuleTransformer[T, Err],
  t : T,
  expr : TExpr,
) -> TransformerOptResult[T, TExpr, Err] {
  let { instrs: instructions, .. } = expr
  let (t, instructions) = match
    self.walk_opt_array(
      t,
      ModuleTransformer::walk_opt_tinstruction,
      instructions,
    ) {
    Err(e) => return Err(e)
    Ok(None) => (t, instructions)
    Ok(Some(t)) => t
  }
  Ok(Some((t, TExpr::new(instructions))))
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tinstruction(
  self : ModuleTransformer[T, Err],
  t : T,
  tinstr : TInstr,
) -> TransformerOptResult[T, TInstr, Err] {
  match self.on_tinstruction {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        tinstr,
        f(self, t, tinstr),
        ModuleTransformer::walk_opt_tinstruction_default,
      )
    None => ModuleTransformer::walk_opt_tinstruction_default(self, t, tinstr)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tinstruction_default(
  self : ModuleTransformer[T, Err],
  t : T,
  tinstr : TInstr,
) -> TransformerOptResult[T, TInstr, Err] {
  match tinstr.kind {
    // === Constants (0 children, 1 result) ===

    TInstrKind::TRefNull(rt) => {
      let (t, rt) = match self.walk_opt_reftype(t, rt) {
        Ok(None) => (t, rt)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_null_type(rt))))
    }
    TInstrKind::TRefFunc(fi) => {
      let (t, fi) = match self.walk_opt_funcidx(t, fi) {
        Ok(None) => (t, fi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_func(fi))))
    }
    // === Nullary (0 children) ===

    TInstrKind::TLocalGet(li) => {
      let (t, li) = match self.walk_opt_localidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::local_get(li))))
    }
    TInstrKind::TGlobalGet(gi) => {
      let (t, gi) = match self.walk_opt_globalidx(t, gi) {
        Ok(None) => (t, gi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::global_get(gi))))
    }
    TInstrKind::TMemorySize(mi) => {
      let (t, mi) = match self.walk_opt_memidx(t, mi) {
        Ok(None) => (t, mi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_size(mi))))
    }
    TInstrKind::TTableSize(ti) => {
      let (t, ti) = match self.walk_opt_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_size(ti))))
    }

    // === Unary (1 child) ===
    TInstrKind::TUnary(op, i) => {
      let (t, op) = match self.walk_opt_unaryop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::unary(op, i))))
    }
    TInstrKind::TDrop(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::drop(i))))
    }
    TInstrKind::TLocalSet(li, i) => {
      let (t, li) = match self.walk_opt_localidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::local_set(li, i))))
    }
    TInstrKind::TLocalTee(li, i) => {
      let (t, li) = match self.walk_opt_localidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::local_tee(li, i))))
    }
    TInstrKind::TGlobalSet(gi, i) => {
      let (t, gi) = match self.walk_opt_globalidx(t, gi) {
        Ok(None) => (t, gi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::global_set(gi, i))))
    }
    TInstrKind::TRefIsNull(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_is_null(i))))
    }
    TInstrKind::TRefAsNonNull(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_as_non_null(i))))
    }
    TInstrKind::TI31GetS(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i31_get_s(i))))
    }
    TInstrKind::TI31GetU(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i31_get_u(i))))
    }
    TInstrKind::TRefI31(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_i31(i))))
    }
    TInstrKind::TArrayLen(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_len(i))))
    }
    TInstrKind::TAnyConvertExtern(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::any_convert_extern(i))))
    }
    TInstrKind::TExternConvertAny(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::extern_convert_any(i))))
    }
    TInstrKind::TThrowRef(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::throw_ref(i))))
    }

    // === Binary (2 children) ===
    TInstrKind::TBinary(op, i1, i2) => {
      let (t, op) = match self.walk_opt_binaryop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::binary(op, i1, i2))))
    }
    TInstrKind::TRefEq(i1, i2) => {
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_eq(i1, i2))))
    }
    TInstrKind::TStore(op, ma, i1, i2) => {
      let (t, op) = match self.walk_opt_storeop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ma) = match self.walk_opt_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::store(op, ma, i1, i2))))
    }
    TInstrKind::TMemoryAtomicNotify(ma, i1, i2) => {
      let (t, ma) = match self.walk_opt_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_atomic_notify(ma, i1, i2))))
    }
    TInstrKind::TAtomicRmw(op, ma, i1, i2) => {
      let (t, ma) = match self.walk_opt_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::atomic_rmw(op, ma, i1, i2))))
    }

    // === Load (1 child - address) ===
    TInstrKind::TLoad(op, ma, i) => {
      let (t, op) = match self.walk_opt_loadop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ma) = match self.walk_opt_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::load(op, ma, i))))
    }
    TInstrKind::TAtomicFence => Ok(Some((t, TInstr::atomic_fence())))

    // === Memory operations ===
    TInstrKind::TMemoryGrow(mi, i) => {
      let (t, mi) = match self.walk_opt_memidx(t, mi) {
        Ok(None) => (t, mi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_grow(mi, i))))
    }
    TInstrKind::TMemoryFill(mi, i1, i2, i3) => {
      let (t, mi) = match self.walk_opt_memidx(t, mi) {
        Ok(None) => (t, mi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_fill(mi, i1, i2, i3))))
    }
    TInstrKind::TMemoryCopy(mi1, mi2, i1, i2, i3) => {
      let (t, mi1) = match self.walk_opt_memidx(t, mi1) {
        Ok(None) => (t, mi1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, mi2) = match self.walk_opt_memidx(t, mi2) {
        Ok(None) => (t, mi2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_copy(mi1, mi2, i1, i2, i3))))
    }
    TInstrKind::TMemoryInit(di, mi, i1, i2, i3) => {
      let (t, di) = match self.walk_opt_dataidx(t, di) {
        Ok(None) => (t, di)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, mi) = match self.walk_opt_memidx(t, mi) {
        Ok(None) => (t, mi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_init(di, mi, i1, i2, i3))))
    }
    TInstrKind::TMemoryAtomicWait32(ma, i1, i2, i3) => {
      let (t, ma) = match self.walk_opt_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_atomic_wait32(ma, i1, i2, i3))))
    }
    TInstrKind::TMemoryAtomicWait64(ma, i1, i2, i3) => {
      let (t, ma) = match self.walk_opt_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::memory_atomic_wait64(ma, i1, i2, i3))))
    }
    TInstrKind::TAtomicCmpxchg(op, ma, i1, i2, i3) => {
      let (t, ma) = match self.walk_opt_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::atomic_cmpxchg(op, ma, i1, i2, i3))))
    }
    TInstrKind::TDataDrop(di) => {
      let (t, di) = match self.walk_opt_dataidx(t, di) {
        Ok(None) => (t, di)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::data_drop(di))))
    }

    // === Table operations ===
    TInstrKind::TTableGet(ti, i) => {
      let (t, ti) = match self.walk_opt_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_get(ti, i))))
    }
    TInstrKind::TTableSet(ti, i1, i2) => {
      let (t, ti) = match self.walk_opt_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_set(ti, i1, i2))))
    }
    TInstrKind::TTableGrow(ti, i1, i2) => {
      let (t, ti) = match self.walk_opt_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_grow(ti, i1, i2))))
    }
    TInstrKind::TTableFill(ti, i1, i2, i3) => {
      let (t, ti) = match self.walk_opt_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_fill(ti, i1, i2, i3))))
    }
    TInstrKind::TTableCopy(ti1, ti2, i1, i2, i3) => {
      let (t, ti1) = match self.walk_opt_tableidx(t, ti1) {
        Ok(None) => (t, ti1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ti2) = match self.walk_opt_tableidx(t, ti2) {
        Ok(None) => (t, ti2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_copy(ti1, ti2, i1, i2, i3))))
    }
    TInstrKind::TTableInit(ei, ti, i1, i2, i3) => {
      let (t, ei) = match self.walk_opt_elemidx(t, ei) {
        Ok(None) => (t, ei)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ti) = match self.walk_opt_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::table_init(ei, ti, i1, i2, i3))))
    }
    TInstrKind::TElemDrop(ei) => {
      let (t, ei) = match self.walk_opt_elemidx(t, ei) {
        Ok(None) => (t, ei)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::elem_drop(ei))))
    }

    // === Calls (N children based on function type) ===
    TInstrKind::TCall(fi, i) => {
      let (t, fi) = match self.walk_opt_funcidx(t, fi) {
        Ok(None) => (t, fi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::call(fi, i))))
    }
    TInstrKind::TCallIndirect(tyi, tai, i0, i) => {
      let (t, tyi) = match self.walk_opt_typeidx(t, tyi) {
        Ok(None) => (t, tyi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, tai) = match self.walk_opt_tableidx(t, tai) {
        Ok(None) => (t, tai)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::call_indirect(tyi, tai, i0, i))))
    }
    TInstrKind::TCallRef(tyi, i0, i) => {
      let (t, tyi) = match self.walk_opt_typeidx(t, tyi) {
        Ok(None) => (t, tyi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::call_ref(tyi, i0, i))))
    }
    TInstrKind::TReturnCall(fi, i) => {
      let (t, fi) = match self.walk_opt_funcidx(t, fi) {
        Ok(None) => (t, fi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::return_call(fi, i))))
    }
    TInstrKind::TReturnCallIndirect(tyi, tai, i0, i) => {
      let (t, tyi) = match self.walk_opt_typeidx(t, tyi) {
        Ok(None) => (t, tyi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, tai) = match self.walk_opt_tableidx(t, tai) {
        Ok(None) => (t, tai)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::return_call_indirect(tyi, tai, i0, i))))
    }
    TInstrKind::TReturnCallRef(tyi, i0, i) => {
      let (t, tyi) = match self.walk_opt_typeidx(t, tyi) {
        Ok(None) => (t, tyi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::return_call_ref(tyi, i0, i))))
    }

    // === Control flow ===
    TInstrKind::TBlock(bt, e) => {
      let (t, bt) = match self.walk_opt_blocktype(t, bt) {
        Ok(None) => (t, bt)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, e) = match self.walk_opt_texpr(t, e) {
        Ok(None) => (t, e)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::block(bt, e))))
    }
    TInstrKind::TLoop(bt, e) => {
      let (t, bt) = match self.walk_opt_blocktype(t, bt) {
        Ok(None) => (t, bt)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, e) = match self.walk_opt_texpr(t, e) {
        Ok(None) => (t, e)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::loop_(bt, e))))
    }
    TInstrKind::TIf(bt, i_if, e_then, e_else_option) => {
      let (t, bt) = match self.walk_opt_blocktype(t, bt) {
        Ok(None) => (t, bt)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i_if) = match self.walk_opt_tinstruction(t, i_if) {
        Ok(None) => (t, i_if)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, e_then) = match self.walk_opt_texpr(t, e_then) {
        Ok(None) => (t, e_then)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, e_else_option) = if e_else_option is Some(e_else) {
        match self.walk_opt_texpr(t, e_else) {
          Ok(None) => (t, e_else_option)
          Ok(Some((t, e_else))) => (t, Some(e_else))
          Err(t) => return Err(t)
        }
      } else {
        (t, e_else_option)
      }
      Ok(Some((t, TInstr::if_(bt, i_if, e_then, e_else_option))))
    }
    TInstrKind::TTryTable(bt, c, e) => {
      let (t, bt) = match self.walk_opt_blocktype(t, bt) {
        Ok(None) => (t, bt)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, c) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_catch, c) {
        Ok(None) => (t, c)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, e) = match self.walk_opt_texpr(t, e) {
        Ok(None) => (t, e)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::try_table(bt, c, e))))
    }
    TInstrKind::TThrow(ti, i) => {
      let (t, ti) = match self.walk_opt_tagidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::throw_(ti, i))))
    }

    // === Branches ===
    TInstrKind::TBr(li, i) => {
      let (t, li) = match self.walk_opt_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br(li, i))))
    }
    TInstrKind::TBrIf(li, i0, i) => {
      let (t, li) = match self.walk_opt_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_if(li, i0, i))))
    }
    TInstrKind::TBrTable(ls, li, i0, i) => {
      let (t, ls) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_labelidx, ls) {
        Ok(None) => (t, ls)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li) = match self.walk_opt_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_table(ls, li, i0, i))))
    }
    TInstrKind::TBrOnNull(li, i0, i) => {
      let (t, li) = match self.walk_opt_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_on_null(li, i0, i))))
    }
    TInstrKind::TBrOnNonNull(li, i0, i) => {
      let (t, li) = match self.walk_opt_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_on_non_null(li, i0, i))))
    }
    TInstrKind::TBrOnCast(li, co, ht0, ht1, i0, i) => {
      let (t, li) = match self.walk_opt_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ht0) = match self.walk_opt_heaptype(t, ht0) {
        Ok(None) => (t, ht0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ht1) = match self.walk_opt_heaptype(t, ht1) {
        Ok(None) => (t, ht1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_on_cast(li, co.0, ht0, co.1, ht1, i0, i))))
    }
    TInstrKind::TBrOnCastFail(li, co, ht0, ht1, i0, i) => {
      let (t, li) = match self.walk_opt_labelidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ht0) = match self.walk_opt_heaptype(t, ht0) {
        Ok(None) => (t, ht0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ht1) = match self.walk_opt_heaptype(t, ht1) {
        Ok(None) => (t, ht1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::br_on_cast_fail(li, co.0, ht0, co.1, ht1, i0, i))))
    }
    TInstrKind::TReturn(i) => {
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::return_(i))))
    }

    // === Select ===
    TInstrKind::TSelect(vts_option, i0, i1, i2) => {
      let (t, vts_option) = if vts_option is Some(vts) {
        match self.walk_opt_array(t, ModuleTransformer::walk_opt_valtype, vts) {
          Ok(None) => (t, vts_option)
          Ok(Some((t, vts))) => (t, Some(vts))
          Err(t) => return Err(t)
        }
      } else {
        (t, vts_option)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::select(vts_option, i0, i1, i2))))
    }

    // === GC: Structs ===
    TInstrKind::TStructNew(ti, i) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_new(ti, i))))
    }
    TInstrKind::TStructNewDefault(ti) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_new_default(ti))))
    }
    TInstrKind::TStructGet(ti, f, i) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_get(ti, f, i))))
    }
    TInstrKind::TStructGetS(ti, f, i) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_get_s(ti, f, i))))
    }
    TInstrKind::TStructGetU(ti, f, i) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_get_u(ti, f, i))))
    }
    TInstrKind::TStructSet(ti, f, i0, i1) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::struct_set(ti, f, i0, i1))))
    }

    // === GC: Arrays ===
    TInstrKind::TArrayNew(ti, i0, i1) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_new(ti, i0, i1))))
    }
    TInstrKind::TArrayNewDefault(ti, i) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_new_default(ti, i))))
    }
    TInstrKind::TArrayNewFixed(ti, i) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_new_fixed(ti, i))))
    }
    TInstrKind::TArrayNewData(ti, di, i0, i1) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, di) = match self.walk_opt_dataidx(t, di) {
        Ok(None) => (t, di)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_new_data(ti, di, i0, i1))))
    }
    TInstrKind::TArrayNewElem(ti, ei, i0, i1) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ei) = match self.walk_opt_elemidx(t, ei) {
        Ok(None) => (t, ei)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_new_elem(ti, ei, i0, i1))))
    }
    TInstrKind::TArrayGet(ti, i0, i1) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_get(ti, i0, i1))))
    }
    TInstrKind::TArrayGetS(ti, i0, i1) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_get_s(ti, i0, i1))))
    }
    TInstrKind::TArrayGetU(ti, i0, i1) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_get_u(ti, i0, i1))))
    }
    TInstrKind::TArraySet(ti, i0, i1, i2) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_set(ti, i0, i1, i2))))
    }
    TInstrKind::TArrayFill(ti, i0, i1, i2, i3) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_fill(ti, i0, i1, i2, i3))))
    }
    TInstrKind::TArrayCopy(ti0, ti1, i0, i1, i2, i3, i4) => {
      let (t, ti0) = match self.walk_opt_typeidx(t, ti0) {
        Ok(None) => (t, ti0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ti1) = match self.walk_opt_typeidx(t, ti1) {
        Ok(None) => (t, ti1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i4) = match self.walk_opt_tinstruction(t, i4) {
        Ok(None) => (t, i4)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_copy(ti0, ti1, i0, i1, i2, i3, i4))))
    }
    TInstrKind::TArrayInitData(ti, di, i0, i1, i2, i3) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, di) = match self.walk_opt_dataidx(t, di) {
        Ok(None) => (t, di)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_init_data(ti, di, i0, i1, i2, i3))))
    }
    TInstrKind::TArrayInitElem(ti, ei, i0, i1, i2, i3) => {
      let (t, ti) = match self.walk_opt_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ei) = match self.walk_opt_elemidx(t, ei) {
        Ok(None) => (t, ei)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i3) = match self.walk_opt_tinstruction(t, i3) {
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::array_init_elem(ti, ei, i0, i1, i2, i3))))
    }

    // === GC: Casts ===
    TInstrKind::TRefGetDesc(type_idx, i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_get_desc(type_idx, i))))
    }
    TInstrKind::TRefTest(b, ht, i) => {
      let (t, ht) = match self.walk_opt_heaptype(t, ht) {
        Ok(None) => (t, ht)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_test(b, ht, i))))
    }
    TInstrKind::TRefCast(b, ht, i) => {
      let (t, ht) = match self.walk_opt_heaptype(t, ht) {
        Ok(None) => (t, ht)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_cast(b, ht, i))))
    }
    TInstrKind::TRefTestDesc(b, ht, i) => {
      let (t, ht) = match self.walk_opt_heaptype(t, ht) {
        Ok(None) => (t, ht)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_test_desc(b, ht, i))))
    }
    TInstrKind::TRefCastDescEq(b, ht, i) => {
      let (t, ht) = match self.walk_opt_heaptype(t, ht) {
        Ok(None) => (t, ht)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::ref_cast_desc_eq(b, ht, i))))
    }

    // === SIMD: Splat (scalar -> v128) ===
    TInstrKind::TI8x16Splat(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i8x16_splat(i))))
    }
    TInstrKind::TI16x8Splat(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i16x8_splat(i))))
    }
    TInstrKind::TI32x4Splat(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i32x4_splat(i))))
    }
    TInstrKind::TI64x2Splat(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i64x2_splat(i))))
    }
    TInstrKind::TF32x4Splat(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::f32x4_splat(i))))
    }
    TInstrKind::TF64x2Splat(i) => {
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::f64x2_splat(i))))
    }

    // === SIMD: Extract lane (v128 -> scalar) ===
    TInstrKind::TExtractLane(op, li, i) => {
      let (t, op) = match self.walk_opt_extractlaneop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li) = match self.walk_opt_laneidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i) = match self.walk_opt_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::extract_lane(op, li, i))))
    }

    // === SIMD: Replace lane (v128, scalar -> v128) ===
    TInstrKind::TReplaceLane(op, li, i0, i1) => {
      let (t, op) = match self.walk_opt_replacelaneop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li) = match self.walk_opt_laneidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::replace_lane(op, li, i0, i1))))
    }

    // === SIMD: Shuffle (v128, v128 -> v128 with 16 lane indices) ===
    TInstrKind::TI8x16Shuffle(
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
      let (t, li0) = match self.walk_opt_laneidx(t, li0) {
        Ok(None) => (t, li0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li1) = match self.walk_opt_laneidx(t, li1) {
        Ok(None) => (t, li1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li2) = match self.walk_opt_laneidx(t, li2) {
        Ok(None) => (t, li2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li3) = match self.walk_opt_laneidx(t, li3) {
        Ok(None) => (t, li3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li4) = match self.walk_opt_laneidx(t, li4) {
        Ok(None) => (t, li4)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li5) = match self.walk_opt_laneidx(t, li5) {
        Ok(None) => (t, li5)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li6) = match self.walk_opt_laneidx(t, li6) {
        Ok(None) => (t, li6)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li7) = match self.walk_opt_laneidx(t, li7) {
        Ok(None) => (t, li7)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li8) = match self.walk_opt_laneidx(t, li8) {
        Ok(None) => (t, li8)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li9) = match self.walk_opt_laneidx(t, li9) {
        Ok(None) => (t, li9)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li10) = match self.walk_opt_laneidx(t, li10) {
        Ok(None) => (t, li10)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li11) = match self.walk_opt_laneidx(t, li11) {
        Ok(None) => (t, li11)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li12) = match self.walk_opt_laneidx(t, li12) {
        Ok(None) => (t, li12)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li13) = match self.walk_opt_laneidx(t, li13) {
        Ok(None) => (t, li13)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li14) = match self.walk_opt_laneidx(t, li14) {
        Ok(None) => (t, li14)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li15) = match self.walk_opt_laneidx(t, li15) {
        Ok(None) => (t, li15)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
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
    TInstrKind::TI8x16Swizzle(i0, i1) => {
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i8x16_swizzle(i0, i1))))
    }
    TInstrKind::TI8x16RelaxedSwizzle(i0, i1) => {
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::i8x16_relaxed_swizzle(i0, i1))))
    }

    // === SIMD: Shift (v128, i32 -> v128) ===
    TInstrKind::TV128Shift(op, i0, i1) => {
      let (t, op) = match self.walk_opt_v128shiftop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::v128_shift(op, i0, i1))))
    }

    // === SIMD: Ternary (v128, v128, v128 -> v128) ===
    TInstrKind::TV128Ternary(op, i0, i1, i2) => {
      let (t, op) = match self.walk_opt_v128ternaryop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i2) = match self.walk_opt_tinstruction(t, i2) {
        Ok(None) => (t, i2)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::v128_ternary(op, i0, i1, i2))))
    }

    // === SIMD: Lane load (v128, addr -> v128) ===
    TInstrKind::TV128LoadLane(op, ma, li, i0, i1) => {
      let (t, op) = match self.walk_opt_v128loadlaneop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ma) = match self.walk_opt_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li) = match self.walk_opt_laneidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
        Ok(None) => (t, i1)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TInstr::v128_load_lane(op, ma, li, i0, i1))))
    }

    // === SIMD: Lane store (v128, addr -> void) ===
    TInstrKind::TV128StoreLane(op, ma, li, i0, i1) => {
      let (t, op) = match self.walk_opt_v128storelaneop(t, op) {
        Ok(None) => (t, op)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, ma) = match self.walk_opt_memarg(t, ma) {
        Ok(None) => (t, ma)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, li) = match self.walk_opt_laneidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i0) = match self.walk_opt_tinstruction(t, i0) {
        Ok(None) => (t, i0)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      let (t, i1) = match self.walk_opt_tinstruction(t, i1) {
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
fn[T, Err] ModuleTransformer::walk_opt_instruction(
  self : ModuleTransformer[T, Err],
  t : T,
  instr : Instruction,
) -> TransformerOptResult[T, Instruction, Err] {
  match self.on_instruction {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        instr,
        f(self, t, instr),
        ModuleTransformer::walk_opt_instruction_default,
      )
    None => ModuleTransformer::walk_opt_instruction_default(self, t, instr)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_instruction_default(
  self : ModuleTransformer[T, Err],
  t : T,
  instr : Instruction,
) -> TransformerOptResult[T, Instruction, Err] {
  match instr {
    // Control instructions
    Block(bt, body) =>
      match self.walk_opt_blocktype(t, bt) {
        Err(e) => Err(e)
        Ok(None) =>
          match self.walk_opt_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, body))) => Ok(Some((t, Instruction::block(bt, body))))
          }
        Ok(Some((t, bt))) =>
          match self.walk_opt_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, Instruction::block(bt, body))))
            Ok(Some((t, body))) => Ok(Some((t, Instruction::block(bt, body))))
          }
      }
    Loop(bt, body) =>
      match self.walk_opt_blocktype(t, bt) {
        Err(e) => Err(e)
        Ok(None) =>
          match self.walk_opt_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, body))) => Ok(Some((t, Instruction::loop_(bt, body))))
          }
        Ok(Some((t, bt))) =>
          match self.walk_opt_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, Instruction::loop_(bt, body))))
            Ok(Some((t, body))) => Ok(Some((t, Instruction::loop_(bt, body))))
          }
      }
    If(bt, then_body, else_body_opt) => {
      let (t, bt) = match self.walk_opt_blocktype(t, bt) {
        Err(e) => return Err(e)
        Ok(None) => (t, bt)
        Ok(Some((t, bt))) => (t, bt)
      }
      let (t, then_body) = match
        self.walk_opt_array(
          t,
          ModuleTransformer::walk_opt_instruction,
          then_body,
        ) {
        Err(e) => return Err(e)
        Ok(None) => (t, then_body)
        Ok(Some((t, arr))) => (t, arr)
      }
      let (t, else_body_opt) = match else_body_opt {
        None => (t, None)
        Some(else_body) =>
          match
            self.walk_opt_array(
              t,
              ModuleTransformer::walk_opt_instruction,
              else_body,
            ) {
            Err(e) => return Err(e)
            Ok(None) => (t, Some(else_body))
            Ok(Some((t, arr))) => (t, Some(arr))
          }
      }
      Ok(Some((t, Instruction::if_(bt, then_body, else_body_opt))))
    }
    TryTable(bt, catches, body) =>
      match self.walk_opt_blocktype(t, bt) {
        Err(e) => Err(e)
        Ok(None) =>
          match
            self.walk_opt_array(t, ModuleTransformer::walk_opt_catch, catches) {
            Err(e) => Err(e)
            Ok(None) =>
              match self.walk_opt_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) => Ok(None)
                Ok(Some((t, body))) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
              }
            Ok(Some((t, catches))) =>
              match self.walk_opt_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
                Ok(Some((t, body))) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
              }
          }
        Ok(Some((t, bt))) =>
          match
            self.walk_opt_array(t, ModuleTransformer::walk_opt_catch, catches) {
            Err(e) => Err(e)
            Ok(None) =>
              match self.walk_opt_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
                Ok(Some((t, body))) =>
                  Ok(Some((t, Instruction::try_table(bt, catches, body))))
              }
            Ok(Some((t, catches))) =>
              match self.walk_opt_expr(t, body) {
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
      match self.walk_opt_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::br(l))))
      }
    BrIf(l) =>
      match self.walk_opt_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::br_if(l))))
      }
    BrTable(labels, default) =>
      match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_labelidx, labels) {
        Err(e) => Err(e)
        Ok(None) =>
          match self.walk_opt_labelidx(t, default) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, default))) =>
              Ok(Some((t, Instruction::br_table(labels, default))))
          }
        Ok(Some((t, labels))) =>
          match self.walk_opt_labelidx(t, default) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, Instruction::br_table(labels, default))))
            Ok(Some((t, default))) =>
              Ok(Some((t, Instruction::br_table(labels, default))))
          }
      }
    BrOnNull(l) =>
      match self.walk_opt_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::br_on_null(l))))
      }
    BrOnNonNull(l) =>
      match self.walk_opt_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::br_on_non_null(l))))
      }
    BrOnCast(l, op, ht1, ht2) => {
      let (t, l) = match self.walk_opt_labelidx(t, l) {
        Err(e) => return Err(e)
        Ok(None) => (t, l)
        Ok(Some((t, l))) => (t, l)
      }
      let (t, ht1) = match self.walk_opt_heaptype(t, ht1) {
        Err(e) => return Err(e)
        Ok(None) => (t, ht1)
        Ok(Some((t, ht1))) => (t, ht1)
      }
      let (t, ht2) = match self.walk_opt_heaptype(t, ht2) {
        Err(e) => return Err(e)
        Ok(None) => (t, ht2)
        Ok(Some((t, ht2))) => (t, ht2)
      }
      Ok(Some((t, Instruction::br_on_cast(l, op.0, ht1, op.1, ht2))))
    }
    BrOnCastFail(l, op, ht1, ht2) => {
      let (t, l) = match self.walk_opt_labelidx(t, l) {
        Err(e) => return Err(e)
        Ok(None) => (t, l)
        Ok(Some((t, l))) => (t, l)
      }
      let (t, ht1) = match self.walk_opt_heaptype(t, ht1) {
        Err(e) => return Err(e)
        Ok(None) => (t, ht1)
        Ok(Some((t, ht1))) => (t, ht1)
      }
      let (t, ht2) = match self.walk_opt_heaptype(t, ht2) {
        Err(e) => return Err(e)
        Ok(None) => (t, ht2)
        Ok(Some((t, ht2))) => (t, ht2)
      }
      Ok(Some((t, Instruction::br_on_cast_fail(l, op.0, ht1, op.1, ht2))))
    }

    // Call instructions
    Call(f) =>
      match self.walk_opt_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, Instruction::call(f))))
      }
    CallIndirect(ty, tbl) => {
      let (t, ty) = match self.walk_opt_typeidx(t, ty) {
        Err(e) => return Err(e)
        Ok(None) => (t, ty)
        Ok(Some((t, ty))) => (t, ty)
      }
      let (t, tbl) = match self.walk_opt_tableidx(t, tbl) {
        Err(e) => return Err(e)
        Ok(None) => (t, tbl)
        Ok(Some((t, tbl))) => (t, tbl)
      }
      Ok(Some((t, Instruction::call_indirect(ty, tbl))))
    }
    ReturnCall(f) =>
      match self.walk_opt_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, Instruction::return_call(f))))
      }
    ReturnCallIndirect(ty, tbl) => {
      let (t, ty) = match self.walk_opt_typeidx(t, ty) {
        Err(e) => return Err(e)
        Ok(None) => (t, ty)
        Ok(Some((t, ty))) => (t, ty)
      }
      let (t, tbl) = match self.walk_opt_tableidx(t, tbl) {
        Err(e) => return Err(e)
        Ok(None) => (t, tbl)
        Ok(Some((t, tbl))) => (t, tbl)
      }
      Ok(Some((t, Instruction::return_call_indirect(ty, tbl))))
    }
    CallRef(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::call_ref(ty))))
      }
    ReturnCallRef(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::return_call_ref(ty))))
      }

    // Variable instructions
    LocalGet(l) =>
      match self.walk_opt_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::local_get(l))))
      }
    LocalSet(l) =>
      match self.walk_opt_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::local_set(l))))
      }
    LocalTee(l) =>
      match self.walk_opt_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Instruction::local_tee(l))))
      }
    GlobalGet(g) =>
      match self.walk_opt_globalidx(t, g) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, g))) => Ok(Some((t, Instruction::global_get(g))))
      }
    GlobalSet(g) =>
      match self.walk_opt_globalidx(t, g) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, g))) => Ok(Some((t, Instruction::global_set(g))))
      }

    // Table instructions
    TableGet(tbl) =>
      match self.walk_opt_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, Instruction::table_get(tbl))))
      }
    TableSet(tbl) =>
      match self.walk_opt_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, Instruction::table_set(tbl))))
      }
    TableGrow(tbl) =>
      match self.walk_opt_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, Instruction::table_grow(tbl))))
      }
    TableSize(tbl) =>
      match self.walk_opt_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, Instruction::table_size(tbl))))
      }
    TableFill(tbl) =>
      match self.walk_opt_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, Instruction::table_fill(tbl))))
      }
    TableCopy(t1, t2) => {
      let (t, t1) = match self.walk_opt_tableidx(t, t1) {
        Err(e) => return Err(e)
        Ok(None) => (t, t1)
        Ok(Some((t, t1))) => (t, t1)
      }
      let (t, t2) = match self.walk_opt_tableidx(t, t2) {
        Err(e) => return Err(e)
        Ok(None) => (t, t2)
        Ok(Some((t, t2))) => (t, t2)
      }
      Ok(Some((t, Instruction::table_copy(t1, t2))))
    }
    TableInit(e, tbl) => {
      let (t, e) = match self.walk_opt_elemidx(t, e) {
        Err(e) => return Err(e)
        Ok(None) => (t, e)
        Ok(Some((t, e))) => (t, e)
      }
      let (t, tbl) = match self.walk_opt_tableidx(t, tbl) {
        Err(e) => return Err(e)
        Ok(None) => (t, tbl)
        Ok(Some((t, tbl))) => (t, tbl)
      }
      Ok(Some((t, Instruction::table_init(e, tbl))))
    }
    ElemDrop(e) =>
      match self.walk_opt_elemidx(t, e) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, e))) => Ok(Some((t, Instruction::elem_drop(e))))
      }

    // Reference instructions
    RefNull(rt) =>
      match self.walk_opt_reftype(t, rt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, rt))) => Ok(Some((t, Instruction::ref_null_type(rt))))
      }
    RefFunc(f) =>
      match self.walk_opt_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, Instruction::ref_func(f))))
      }
    RefTest(nullable, ht) =>
      match self.walk_opt_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, Instruction::ref_test(nullable, ht))))
      }
    RefCast(nullable, ht) =>
      match self.walk_opt_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, Instruction::ref_cast(nullable, ht))))
      }
    RefGetDesc(type_idx) => Ok(Some((t, Instruction::ref_get_desc(type_idx))))
    RefTestDesc(nullable, ht) =>
      match self.walk_opt_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) =>
          Ok(Some((t, Instruction::ref_test_desc(nullable, ht))))
      }
    RefCastDescEq(nullable, ht) =>
      match self.walk_opt_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) =>
          Ok(Some((t, Instruction::ref_cast_desc_eq(nullable, ht))))
      }

    // Struct/Array instructions
    StructNew(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_new(ty))))
      }
    StructNewDefault(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_new_default(ty))))
      }
    StructGet(ty, f) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_get(ty, f))))
      }
    StructGetS(ty, f) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_get_s(ty, f))))
      }
    StructGetU(ty, f) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_get_u(ty, f))))
      }
    StructSet(ty, f) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::struct_set(ty, f))))
      }
    ArrayNew(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_new(ty))))
      }
    ArrayNewDefault(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_new_default(ty))))
      }
    ArrayNewFixed(ty, n) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_new_fixed(ty, n))))
      }
    ArrayNewData(ty, n) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_new_data(ty, n))))
      }
    ArrayNewElem(ty, e) => {
      let (t, ty) = match self.walk_opt_typeidx(t, ty) {
        Err(e) => return Err(e)
        Ok(None) => (t, ty)
        Ok(Some((t, ty))) => (t, ty)
      }
      let (t, e) = match self.walk_opt_elemidx(t, e) {
        Err(e) => return Err(e)
        Ok(None) => (t, e)
        Ok(Some((t, e))) => (t, e)
      }
      Ok(Some((t, Instruction::array_new_elem(ty, e))))
    }
    ArrayGet(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_get(ty))))
      }
    ArrayGetS(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_get_s(ty))))
      }
    ArrayGetU(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_get_u(ty))))
      }
    ArraySet(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_set(ty))))
      }
    ArrayFill(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::array_fill(ty))))
      }
    ArrayCopy(t1, t2) => {
      let (t, t1) = match self.walk_opt_typeidx(t, t1) {
        Err(e) => return Err(e)
        Ok(None) => (t, t1)
        Ok(Some((t, t1))) => (t, t1)
      }
      let (t, t2) = match self.walk_opt_typeidx(t, t2) {
        Err(e) => return Err(e)
        Ok(None) => (t, t2)
        Ok(Some((t, t2))) => (t, t2)
      }
      Ok(Some((t, Instruction::array_copy(t1, t2))))
    }
    ArrayInitData(ty, d) => {
      let (t, ty) = match self.walk_opt_typeidx(t, ty) {
        Err(e) => return Err(e)
        Ok(None) => (t, ty)
        Ok(Some((t, ty))) => (t, ty)
      }
      let (t, d) = match self.walk_opt_dataidx(t, d) {
        Err(e) => return Err(e)
        Ok(None) => (t, d)
        Ok(Some((t, d))) => (t, d)
      }
      Ok(Some((t, Instruction::array_init_data(ty, d))))
    }
    ArrayInitElem(ty, e) => {
      let (t, ty) = match self.walk_opt_typeidx(t, ty) {
        Err(e) => return Err(e)
        Ok(None) => (t, ty)
        Ok(Some((t, ty))) => (t, ty)
      }
      let (t, e) = match self.walk_opt_elemidx(t, e) {
        Err(e) => return Err(e)
        Ok(None) => (t, e)
        Ok(Some((t, e))) => (t, e)
      }
      Ok(Some((t, Instruction::array_init_elem(ty, e))))
    }

    // Memory instructions
    MemoryAtomicNotify(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) =>
          Ok(Some((t, Instruction::memory_atomic_notify(ma))))
      }
    MemoryAtomicWait32(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) =>
          Ok(Some((t, Instruction::memory_atomic_wait32(ma))))
      }
    MemoryAtomicWait64(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) =>
          Ok(Some((t, Instruction::memory_atomic_wait64(ma))))
      }
    AtomicFence => Ok(Some((t, Instruction::atomic_fence())))
    I32AtomicLoad(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_load(ma))))
      }
    I64AtomicLoad(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_load(ma))))
      }
    I32AtomicLoad8U(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_load8_u(ma))))
      }
    I32AtomicLoad16U(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_load16_u(ma))))
      }
    I64AtomicLoad8U(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_load8_u(ma))))
      }
    I64AtomicLoad16U(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_load16_u(ma))))
      }
    I64AtomicLoad32U(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_load32_u(ma))))
      }
    I32AtomicStore(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_store(ma))))
      }
    I64AtomicStore(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_store(ma))))
      }
    I32AtomicStore8(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_store8(ma))))
      }
    I32AtomicStore16(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i32_atomic_store16(ma))))
      }
    I64AtomicStore8(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_store8(ma))))
      }
    I64AtomicStore16(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_store16(ma))))
      }
    I64AtomicStore32(ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::i64_atomic_store32(ma))))
      }
    AtomicRmw(op, ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::atomic_rmw(op, ma))))
      }
    AtomicCmpxchg(op, ma) =>
      match self.walk_opt_memarg(t, ma) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ma))) => Ok(Some((t, Instruction::atomic_cmpxchg(op, ma))))
      }
    MemorySize(m) =>
      match self.walk_opt_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, Instruction::memory_size(m))))
      }
    MemoryGrow(m) =>
      match self.walk_opt_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, Instruction::memory_grow(m))))
      }
    MemoryFill(m) =>
      match self.walk_opt_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, Instruction::memory_fill(m))))
      }
    MemoryCopy(m1, m2) => {
      let (t, m1) = match self.walk_opt_memidx(t, m1) {
        Err(e) => return Err(e)
        Ok(None) => (t, m1)
        Ok(Some((t, m1))) => (t, m1)
      }
      let (t, m2) = match self.walk_opt_memidx(t, m2) {
        Err(e) => return Err(e)
        Ok(None) => (t, m2)
        Ok(Some((t, m2))) => (t, m2)
      }
      Ok(Some((t, Instruction::memory_copy(m1, m2))))
    }
    MemoryInit(d, m) => {
      let (t, d) = match self.walk_opt_dataidx(t, d) {
        Err(e) => return Err(e)
        Ok(None) => (t, d)
        Ok(Some((t, d))) => (t, d)
      }
      let (t, m) = match self.walk_opt_memidx(t, m) {
        Err(e) => return Err(e)
        Ok(None) => (t, m)
        Ok(Some((t, m))) => (t, m)
      }
      Ok(Some((t, Instruction::memory_init(d, m))))
    }
    DataDrop(d) =>
      match self.walk_opt_dataidx(t, d) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, d))) => Ok(Some((t, Instruction::data_drop(d))))
      }

    // Exception instructions
    Throw(ty) =>
      match self.walk_opt_tagidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Instruction::throw_(ty))))
      }

    // Select with types
    Select(types) =>
      match types {
        None => Ok(None)
        Some(types) =>
          match
            self.walk_opt_array(t, ModuleTransformer::walk_opt_valtype, types) {
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
fn[T, Err] ModuleTransformer::walk_opt_blocktype(
  self : ModuleTransformer[T, Err],
  t : T,
  bt : BlockType,
) -> TransformerOptResult[T, BlockType, Err] {
  match self.on_blocktype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        bt,
        f(self, t, bt),
        ModuleTransformer::walk_opt_blocktype_default,
      )
    None => ModuleTransformer::walk_opt_blocktype_default(self, t, bt)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_blocktype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  bt : BlockType,
) -> TransformerOptResult[T, BlockType, Err] {
  match bt {
    ValTypeBlockType(vt) =>
      match self.walk_opt_valtype(t, vt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, vt))) => Ok(Some((t, BlockType::val_type(vt))))
      }
    TypeIdxBlockType(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, BlockType::type_idx(ty))))
      }
    _ => Ok(None)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_catch(
  self : ModuleTransformer[T, Err],
  t : T,
  c : Catch,
) -> TransformerOptResult[T, Catch, Err] {
  match c {
    Catch(tag, label) => {
      let (t, tag) = match self.walk_opt_tagidx(t, tag) {
        Err(e) => return Err(e)
        Ok(None) => (t, tag)
        Ok(Some((t, tag))) => (t, tag)
      }
      let (t, label) = match self.walk_opt_labelidx(t, label) {
        Err(e) => return Err(e)
        Ok(None) => (t, label)
        Ok(Some((t, label))) => (t, label)
      }
      Ok(Some((t, Catch::new(tag, label))))
    }
    CatchRef(tag, label) => {
      let (t, tag) = match self.walk_opt_tagidx(t, tag) {
        Err(e) => return Err(e)
        Ok(None) => (t, tag)
        Ok(Some((t, tag))) => (t, tag)
      }
      let (t, label) = match self.walk_opt_labelidx(t, label) {
        Err(e) => return Err(e)
        Ok(None) => (t, label)
        Ok(Some((t, label))) => (t, label)
      }
      Ok(Some((t, Catch::ref_(tag, label))))
    }
    CatchAll(label) =>
      match self.walk_opt_labelidx(t, label) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, label))) => Ok(Some((t, Catch::all(label))))
      }
    CatchAllRef(label) =>
      match self.walk_opt_labelidx(t, label) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, label))) => Ok(Some((t, Catch::all_ref(label))))
      }
  }
}

// Index walkers - leaf nodes

///|
fn[T, Err] ModuleTransformer::walk_opt_funcidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : FuncIdx,
) -> TransformerOptResult[T, FuncIdx, Err] {
  match self.on_funcidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_typeidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : TypeIdx,
) -> TransformerOptResult[T, TypeIdx, Err] {
  match self.on_typeidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_localidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : LocalIdx,
) -> TransformerOptResult[T, LocalIdx, Err] {
  match self.on_localidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_globalidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : GlobalIdx,
) -> TransformerOptResult[T, GlobalIdx, Err] {
  match self.on_globalidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tableidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : TableIdx,
) -> TransformerOptResult[T, TableIdx, Err] {
  match self.on_tableidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_memidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : MemIdx,
) -> TransformerOptResult[T, MemIdx, Err] {
  match self.on_memidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_labelidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : LabelIdx,
) -> TransformerOptResult[T, LabelIdx, Err] {
  match self.on_labelidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_laneidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : LaneIdx,
) -> TransformerOptResult[T, LaneIdx, Err] {
  match self.on_laneidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_dataidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : DataIdx,
) -> TransformerOptResult[T, DataIdx, Err] {
  match self.on_dataidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_elemidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : ElemIdx,
) -> TransformerOptResult[T, ElemIdx, Err] {
  match self.on_elemidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tagidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : TagIdx,
) -> TransformerOptResult[T, TagIdx, Err] {
  match self.on_tagidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        idx,
        f(self, t, idx),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, idx)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_valtype(
  self : ModuleTransformer[T, Err],
  t : T,
  vt : ValType,
) -> TransformerOptResult[T, ValType, Err] {
  match self.on_valtype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        vt,
        f(self, t, vt),
        ModuleTransformer::walk_opt_valtype_default,
      )
    None => ModuleTransformer::walk_opt_valtype_default(self, t, vt)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_valtype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  vt : ValType,
) -> TransformerOptResult[T, ValType, Err] {
  match vt {
    RefTypeValType(rt) =>
      match self.walk_opt_reftype(t, rt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, rt))) => Ok(Some((t, ValType::ref_type(rt))))
      }
    NumTypeValType(nt) =>
      match self.walk_opt_numtype(t, nt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, nt))) => Ok(Some((t, ValType::num_type(nt))))
      }
    _ => Ok(None)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_numtype(
  self : ModuleTransformer[T, Err],
  t : T,
  nt : NumType,
) -> TransformerOptResult[T, NumType, Err] {
  match self.on_numtype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        nt,
        f(self, t, nt),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, nt)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_reftype(
  self : ModuleTransformer[T, Err],
  t : T,
  rt : RefType,
) -> TransformerOptResult[T, RefType, Err] {
  match self.on_reftype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        rt,
        f(self, t, rt),
        ModuleTransformer::walk_opt_reftype_default,
      )
    None => ModuleTransformer::walk_opt_reftype_default(self, t, rt)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_reftype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  rt : RefType,
) -> TransformerOptResult[T, RefType, Err] {
  match rt {
    HeapTypeRefType(nullable, exact, ht) =>
      match self.walk_opt_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, RefType::new(nullable, ht, exact~))))
      }
    _ => Ok(None)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_type_metadata_default(
  self : ModuleTransformer[T, Err],
  t : T,
  meta : TypeMetadata,
) -> TransformerOptResult[T, TypeMetadata, Err] {
  let mut next_t = t
  let mut next_describes = meta.describes
  let mut next_descriptor = meta.descriptor
  match meta.describes {
    Some(idx) =>
      match self.walk_opt_typeidx(next_t, idx) {
        Err(e) => return Err(e)
        Ok(None) => ()
        Ok(Some((t2, idx2))) => {
          next_t = t2
          next_describes = Some(idx2)
        }
      }
    None => ()
  }
  match meta.descriptor {
    Some(idx) =>
      match self.walk_opt_typeidx(next_t, idx) {
        Err(e) => return Err(e)
        Ok(None) => ()
        Ok(Some((t2, idx2))) => {
          next_t = t2
          next_descriptor = Some(idx2)
        }
      }
    None => ()
  }
  Ok(
    (
      next_t,
      TypeMetadata::new(describes=next_describes, descriptor=next_descriptor),
    )
    |> Some,
  )
}

///|
fn[T, Err] ModuleTransformer::walk_opt_heaptype(
  self : ModuleTransformer[T, Err],
  t : T,
  ht : HeapType,
) -> TransformerOptResult[T, HeapType, Err] {
  match self.on_heaptype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ht,
        f(self, t, ht),
        ModuleTransformer::walk_opt_heaptype_default,
      )
    None => ModuleTransformer::walk_opt_heaptype_default(self, t, ht)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_heaptype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ht : HeapType,
) -> TransformerOptResult[T, HeapType, Err] {
  match ht {
    HeapType(ty) =>
      match self.walk_opt_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, HeapType::new(ty))))
      }
    _ => Ok(None)
  }
}

// Sections

///|
fn[T, Err] ModuleTransformer::walk_opt_customsec(
  self : ModuleTransformer[T, Err],
  t : T,
  sec : CustomSec,
) -> TransformerOptResult[T, CustomSec, Err] {
  let CustomSec(n, d) = sec
  match self.walk_opt_name(t, n) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, n))) => Ok(Some((t, CustomSec::new(n, d))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_customsecs(
  self : ModuleTransformer[T, Err],
  t : T,
  secs : Array[CustomSec],
) -> TransformerOptResult[T, Array[CustomSec], Err] {
  self.walk_opt_array(t, ModuleTransformer::walk_opt_customsec, secs)
}

///|
fn[T, Err] ModuleTransformer::walk_opt_module(
  self : ModuleTransformer[T, Err],
  t : T,
  mod : Module,
) -> TransformerOptResult[T, Module, Err] {
  match self.on_module {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        mod,
        f(self, t, mod),
        ModuleTransformer::walk_opt_module_default,
      )
    None => ModuleTransformer::walk_opt_module_default(self, t, mod)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_module_default(
  self : ModuleTransformer[T, Err],
  t : T,
  mod : Module,
) -> TransformerOptResult[T, Module, Err] {
  let {
    custom_secs,
    name_sec,
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
  let (t, custom_secs) = match self.walk_opt_customsecs(t, custom_secs) {
    Err(e) => return Err(e)
    Ok(None) => (t, custom_secs)
    Ok(Some(v)) => v
  }
  let (t, type_sec) = match type_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_typesec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, import_sec) = match import_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_importsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, func_sec) = match func_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_funcsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, table_sec) = match table_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_tablesec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, mem_sec) = match mem_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_memsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, tag_sec) = match tag_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_tagsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, global_sec) = match global_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_globalsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, export_sec) = match export_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_exportsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, start_sec) = match start_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_startsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, elem_sec) = match elem_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_elemsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, data_cnt_sec) = match data_cnt_sec {
    None => (t, None)
    Some(data_cnt_sec) =>
      match self.walk_opt_datacntsec(t, data_cnt_sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(data_cnt_sec))
        Ok(Some((t, data_cnt_sec))) => (t, Some(data_cnt_sec))
      }
  }
  let (t, code_sec) = match code_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_codesec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
      }
  }
  let (t, data_sec) = match data_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_opt_datasec(t, sec) {
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
          name_sec~,
        ),
      ),
    ),
  )
}

///|
fn[T, Err] ModuleTransformer::walk_opt_datasec(
  self : ModuleTransformer[T, Err],
  t : T,
  ds : DataSec,
) -> TransformerOptResult[T, DataSec, Err] {
  match self.on_datasec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ds,
        f(self, t, ds),
        ModuleTransformer::walk_opt_datasec_default,
      )
    None => ModuleTransformer::walk_opt_datasec_default(self, t, ds)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_datasec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ds : DataSec,
) -> TransformerOptResult[T, DataSec, Err] {
  let DataSec(ds) = ds
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_data, ds) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, ds))) => Ok(Some((t, DataSec::new(ds))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_codesec(
  self : ModuleTransformer[T, Err],
  t : T,
  cs : CodeSec,
) -> TransformerOptResult[T, CodeSec, Err] {
  match self.on_codesec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        cs,
        f(self, t, cs),
        ModuleTransformer::walk_opt_codesec_default,
      )
    None => ModuleTransformer::walk_opt_codesec_default(self, t, cs)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_codesec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  cs : CodeSec,
) -> TransformerOptResult[T, CodeSec, Err] {
  let CodeSec(fs) = cs
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_func, fs) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, fs))) => Ok(Some((t, CodeSec::new(fs))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_datacntsec(
  self : ModuleTransformer[T, Err],
  t : T,
  dcs : DataCntSec,
) -> TransformerOptResult[T, DataCntSec, Err] {
  match self.on_datacntsec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        dcs,
        f(self, t, dcs),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, dcs)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_elemsec(
  self : ModuleTransformer[T, Err],
  t : T,
  es : ElemSec,
) -> TransformerOptResult[T, ElemSec, Err] {
  match self.on_elemsec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        es,
        f(self, t, es),
        ModuleTransformer::walk_opt_elemsec_default,
      )
    None => ModuleTransformer::walk_opt_elemsec_default(self, t, es)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_elemsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  es : ElemSec,
) -> TransformerOptResult[T, ElemSec, Err] {
  let ElemSec(es) = es
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_elem, es) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, es))) => Ok(Some((t, ElemSec::new(es))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_startsec(
  self : ModuleTransformer[T, Err],
  t : T,
  ss : StartSec,
) -> TransformerOptResult[T, StartSec, Err] {
  match self.on_startsec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ss,
        f(self, t, ss),
        ModuleTransformer::walk_opt_startsec_default,
      )
    None => ModuleTransformer::walk_opt_startsec_default(self, t, ss)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_startsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ss : StartSec,
) -> TransformerOptResult[T, StartSec, Err] {
  let StartSec(fidx) = ss
  match self.walk_opt_funcidx(t, fidx) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, fidx))) => Ok(Some((t, StartSec::new(fidx))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_exportsec(
  self : ModuleTransformer[T, Err],
  t : T,
  es : ExportSec,
) -> TransformerOptResult[T, ExportSec, Err] {
  match self.on_exportsec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        es,
        f(self, t, es),
        ModuleTransformer::walk_opt_exportsec_default,
      )
    None => ModuleTransformer::walk_opt_exportsec_default(self, t, es)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_importsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  es : ImportSec,
) -> TransformerOptResult[T, ImportSec, Err] {
  let ImportSec(ims) = es
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_import, ims) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, ims))) => Ok(Some((t, ImportSec::new(ims))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_exportsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  es : ExportSec,
) -> TransformerOptResult[T, ExportSec, Err] {
  let ExportSec(es) = es
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_export, es) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, es))) => Ok(Some((t, ExportSec::new(es))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tagsec(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TagSec,
) -> TransformerOptResult[T, TagSec, Err] {
  match self.on_tagsec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ts,
        f(self, t, ts),
        ModuleTransformer::walk_opt_tagsec_default,
      )
    None => ModuleTransformer::walk_opt_tagsec_default(self, t, ts)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tagsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TagSec,
) -> TransformerOptResult[T, TagSec, Err] {
  let TagSec(tags) = ts
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_tagtype, tags) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, tags))) => Ok(Some((t, TagSec::new(tags))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_memsec(
  self : ModuleTransformer[T, Err],
  t : T,
  ms : MemSec,
) -> TransformerOptResult[T, MemSec, Err] {
  match self.on_memsec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ms,
        f(self, t, ms),
        ModuleTransformer::walk_opt_memsec_default,
      )
    None => ModuleTransformer::walk_opt_memsec_default(self, t, ms)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_memsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ms : MemSec,
) -> TransformerOptResult[T, MemSec, Err] {
  let MemSec(m) = ms
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_memtype, m) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, m))) => Ok(Some((t, MemSec::new(m))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tablesec(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TableSec,
) -> TransformerOptResult[T, TableSec, Err] {
  match self.on_tablesec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ts,
        f(self, t, ts),
        ModuleTransformer::walk_opt_tablesec_default,
      )
    None => ModuleTransformer::walk_opt_tablesec_default(self, t, ts)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tablesec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TableSec,
) -> TransformerOptResult[T, TableSec, Err] {
  let TableSec(tts) = ts
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_table, tts) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, tts))) => Ok(Some((t, TableSec::new(tts))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_func(
  self : ModuleTransformer[T, Err],
  t : T,
  func : Func,
) -> TransformerOptResult[T, Func, Err] {
  match self.on_func {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        func,
        f(self, t, func),
        ModuleTransformer::walk_opt_func_default,
      )
    None => ModuleTransformer::walk_opt_func_default(self, t, func)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_func_default(
  self : ModuleTransformer[T, Err],
  t : T,
  f : Func,
) -> TransformerOptResult[T, Func, Err] {
  match f {
    Func(locals, body) => {
      let mut locals = locals
      let t = match self.walk_opt_locals(t, locals) {
        Err(e) => return Err(e)
        Ok(None) => t
        Ok(Some((t, ls))) => {
          locals = ls
          t
        }
      }
      match self.walk_opt_expr(t, body) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, body))) => Ok(Some((t, Func::new(locals, body))))
      }
    }
    TFunc(params, locals, tbody) => {
      let (t, params) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_valtype, params) {
        Ok(None) => (t, params)
        Ok(Some((t, params))) => (t, params)
        Err(t) => return Err(t)
      }
      let (t, locals) = match self.walk_opt_locals(t, locals) {
        Ok(None) => (t, locals)
        Ok(Some((t, locals))) => (t, locals)
        Err(t) => return Err(t)
      }
      let (t, tbody) = match self.walk_opt_texpr(t, tbody) {
        Ok(None) => (t, tbody)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, Func::t_func(params, locals, tbody))))
    }
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_locals(
  self : ModuleTransformer[T, Err],
  t : T,
  l : Locals,
) -> TransformerOptResult[T, Locals, Err] {
  match self.on_locals {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        l,
        f(self, t, l),
        ModuleTransformer::walk_opt_locals_default,
      )
    None => ModuleTransformer::walk_opt_locals_default(self, t, l)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_locals_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ls : Locals,
) -> TransformerOptResult[T, Locals, Err] {
  match
    self.walk_opt_array(t, ModuleTransformer::walk_opt_local_run, ls.runs()) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, runs))) => Ok(Some((t, Locals::new(runs))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_local_run(
  self : ModuleTransformer[T, Err],
  t : T,
  run : LocalRun,
) -> TransformerOptResult[T, LocalRun, Err] {
  match self.walk_opt_valtype(t, run.vt) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, vt))) => Ok(Some((t, LocalRun::new(run.count, vt))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_importsec(
  self : ModuleTransformer[T, Err],
  t : T,
  ims : ImportSec,
) -> TransformerOptResult[T, ImportSec, Err] {
  match self.on_importsec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ims,
        f(self, t, ims),
        ModuleTransformer::walk_opt_importsec_default,
      )
    None => ModuleTransformer::walk_opt_importsec_default(self, t, ims)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_export(
  self : ModuleTransformer[T, Err],
  t : T,
  expt : Export,
) -> TransformerOptResult[T, Export, Err] {
  match self.on_export {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        expt,
        f(self, t, expt),
        ModuleTransformer::walk_opt_export_default,
      )
    None => ModuleTransformer::walk_opt_export_default(self, t, expt)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_export_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ex : Export,
) -> TransformerOptResult[T, Export, Err] {
  let Export(n, ei) = ex
  let (t, n) = match self.walk_opt_name(t, n) {
    Err(e) => return Err(e)
    Ok(None) => (t, n)
    Ok(Some((t, n))) => (t, n)
  }
  let (t, ei) = match self.walk_opt_externidx(t, ei) {
    Err(e) => return Err(e)
    Ok(None) => (t, ei)
    Ok(Some((t, ei))) => (t, ei)
  }
  Ok(Some((t, Export::new(n, ei))))
}

///|
fn[T, Err] ModuleTransformer::walk_opt_externidx(
  self : ModuleTransformer[T, Err],
  t : T,
  ex : ExternIdx,
) -> TransformerOptResult[T, ExternIdx, Err] {
  match self.on_externidx {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ex,
        f(self, t, ex),
        ModuleTransformer::walk_opt_externidx_default,
      )
    None => ModuleTransformer::walk_opt_externidx_default(self, t, ex)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_externidx_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ex : ExternIdx,
) -> TransformerOptResult[T, ExternIdx, Err] {
  match ex {
    FuncExternIdx(fi) =>
      match self.walk_opt_funcidx(t, fi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, fi))) => Ok(Some((t, ExternIdx::func(fi))))
      }
    TableExternIdx(ti) =>
      match self.walk_opt_tableidx(t, ti) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ti))) => Ok(Some((t, ExternIdx::table(ti))))
      }
    MemExternIdx(mi) =>
      match self.walk_opt_memidx(t, mi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, mi))) => Ok(Some((t, ExternIdx::mem(mi))))
      }
    GlobalExternIdx(gi) =>
      match self.walk_opt_globalidx(t, gi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, gi))) => Ok(Some((t, ExternIdx::global(gi))))
      }
    TagExternIdx(ti) =>
      match self.walk_opt_tagidx(t, ti) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ti))) => Ok(Some((t, ExternIdx::tag(ti))))
      }
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_table(
  self : ModuleTransformer[T, Err],
  t : T,
  tbl : Table,
) -> TransformerOptResult[T, Table, Err] {
  match self.on_table {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        tbl,
        f(self, t, tbl),
        ModuleTransformer::walk_opt_table_default,
      )
    None => ModuleTransformer::walk_opt_table_default(self, t, tbl)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_table_default(
  self : ModuleTransformer[T, Err],
  t : T,
  tbl : Table,
) -> TransformerOptResult[T, Table, Err] {
  let Table(tt, e_option) = tbl
  let (t, tt) = match self.walk_opt_tabletype(t, tt) {
    Err(e) => return Err(e)
    Ok(None) => (t, tt)
    Ok(Some((t, tt))) => (t, tt)
  }
  let (t, e_option) = match e_option {
    None => (t, None)
    Some(e) =>
      match self.walk_opt_expr(t, e) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(e))
        Ok(Some((t, e))) => (t, Some(e))
      }
  }
  Ok(Some((t, Table::new(tt, e_option))))
}

///|
fn[T, Err] ModuleTransformer::walk_opt_import(
  self : ModuleTransformer[T, Err],
  t : T,
  im : Import,
) -> TransformerOptResult[T, Import, Err] {
  let Import(n1, n2, ty) = im
  let (t, n1) = match self.walk_opt_name(t, n1) {
    Err(e) => return Err(e)
    Ok(None) => (t, n1)
    Ok(Some((t, n1))) => (t, n1)
  }
  let (t, n2) = match self.walk_opt_name(t, n2) {
    Err(e) => return Err(e)
    Ok(None) => (t, n2)
    Ok(Some((t, n2))) => (t, n2)
  }
  let (t, ty) = match self.walk_opt_externtype(t, ty) {
    Err(e) => return Err(e)
    Ok(None) => (t, ty)
    Ok(Some((t, ty))) => (t, ty)
  }
  Ok(Some((t, Import::new(n1, n2, ty))))
}

///|
fn[T, Err] ModuleTransformer::walk_opt_externtype(
  self : ModuleTransformer[T, Err],
  t : T,
  ex : ExternType,
) -> TransformerOptResult[T, ExternType, Err] {
  match self.on_externtype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ex,
        f(self, t, ex),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, ex)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tagtype(
  self : ModuleTransformer[T, Err],
  t : T,
  tt : TagType,
) -> TransformerOptResult[T, TagType, Err] {
  match self.on_tagtype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        tt,
        f(self, t, tt),
        ModuleTransformer::walk_opt_tagtype_default,
      )
    None => ModuleTransformer::walk_opt_tagtype_default(self, t, tt)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tagtype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  tt : TagType,
) -> TransformerOptResult[T, TagType, Err] {
  let TagType(ti) = tt
  match self.walk_opt_typeidx(t, ti) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, ti))) => Ok(Some((t, TagType::new(ti))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_memtype(
  self : ModuleTransformer[T, Err],
  t : T,
  mt : MemType,
) -> TransformerOptResult[T, MemType, Err] {
  match self.on_memtype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        mt,
        f(self, t, mt),
        ModuleTransformer::walk_opt_memtype_default,
      )
    None => ModuleTransformer::walk_opt_memtype_default(self, t, mt)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_memtype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  mt : MemType,
) -> TransformerOptResult[T, MemType, Err] {
  let MemType(l) = mt
  match self.walk_opt_limits(t, l) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, l))) => Ok(Some((t, MemType::new(l))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_tabletype(
  self : ModuleTransformer[T, Err],
  t : T,
  tt : TableType,
) -> TransformerOptResult[T, TableType, Err] {
  let TableType(rt, l) = tt
  let (t, rt) = match self.walk_opt_reftype(t, rt) {
    Err(e) => return Err(e)
    Ok(None) => (t, rt)
    Ok(Some((t, rt))) => (t, rt)
  }
  let (t, l) = match self.walk_opt_limits(t, l) {
    Err(e) => return Err(e)
    Ok(None) => (t, l)
    Ok(Some((t, l))) => (t, l)
  }
  Ok(Some((t, TableType::new(rt, l))))
}

///|
fn[T, Err] ModuleTransformer::walk_opt_limits(
  self : ModuleTransformer[T, Err],
  t : T,
  l : Limits,
) -> TransformerOptResult[T, Limits, Err] {
  match self.on_limits {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        l,
        f(self, t, l),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, l)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_typesec(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TypeSec,
) -> TransformerOptResult[T, TypeSec, Err] {
  match self.on_typesec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ts,
        f(self, t, ts),
        ModuleTransformer::walk_opt_typesec_default,
      )
    None => ModuleTransformer::walk_opt_typesec_default(self, t, ts)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_typesec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TypeSec,
) -> TransformerOptResult[T, TypeSec, Err] {
  let TypeSec(rectypes) = ts
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_rectype, rectypes) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, rectypes))) => Ok(Some((t, TypeSec::new(rectypes))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_rectype(
  self : ModuleTransformer[T, Err],
  t : T,
  rt : RecType,
) -> TransformerOptResult[T, RecType, Err] {
  match self.on_rectype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        rt,
        f(self, t, rt),
        ModuleTransformer::walk_opt_rectype_default,
      )
    None => ModuleTransformer::walk_opt_rectype_default(self, t, rt)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_rectype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  rt : RecType,
) -> TransformerOptResult[T, RecType, Err] {
  match rt {
    SingleRecType(st) =>
      match self.walk_opt_subtype(t, st) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, st))) => Ok(Some((t, RecType::new(st))))
      }
    GroupRecType(sts) =>
      match self.walk_opt_array(t, ModuleTransformer::walk_opt_subtype, sts) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, sts))) => Ok(Some((t, RecType::group(sts))))
      }
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_subtype(
  self : ModuleTransformer[T, Err],
  t : T,
  st : SubType,
) -> TransformerOptResult[T, SubType, Err] {
  match self.on_subtype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        st,
        f(self, t, st),
        ModuleTransformer::walk_opt_subtype_default,
      )
    None => ModuleTransformer::walk_opt_subtype_default(self, t, st)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_subtype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  st : SubType,
) -> TransformerOptResult[T, SubType, Err] {
  match st {
    SubType(f, supers, meta, ct) => {
      let (t, meta) = match self.walk_opt_type_metadata_default(t, meta) {
        Err(e) => return Err(e)
        Ok(None) => (t, meta)
        Ok(Some((t, meta))) => (t, meta)
      }
      let (t, supers) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_typeidx, supers) {
        Err(e) => return Err(e)
        Ok(None) => (t, supers)
        Ok(Some((t, supers))) => (t, supers)
      }
      let (t, ct) = match self.walk_opt_comptype(t, ct) {
        Err(e) => return Err(e)
        Ok(None) => (t, ct)
        Ok(Some((t, ct))) => (t, ct)
      }
      Ok(Some((t, SubType::new(f, supers, ct, metadata=meta))))
    }
    CompTypeSubType(meta, ct) => {
      let (t, meta) = match self.walk_opt_type_metadata_default(t, meta) {
        Err(e) => return Err(e)
        Ok(None) => (t, meta)
        Ok(Some((t, meta))) => (t, meta)
      }
      match self.walk_opt_comptype(t, ct) {
        Err(e) => Err(e)
        Ok(None) => Ok(Some((t, SubType::comp_type(ct, metadata=meta))))
        Ok(Some((t, ct))) =>
          Ok(Some((t, SubType::comp_type(ct, metadata=meta))))
      }
    }
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_comptype(
  self : ModuleTransformer[T, Err],
  t : T,
  ct : CompType,
) -> TransformerOptResult[T, CompType, Err] {
  match self.on_comptype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ct,
        f(self, t, ct),
        ModuleTransformer::walk_opt_comptype_default,
      )
    None => ModuleTransformer::walk_opt_comptype_default(self, t, ct)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_comptype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ct : CompType,
) -> TransformerOptResult[T, CompType, Err] {
  match ct {
    FuncCompType(params, results) => {
      let (t, params) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_valtype, params) {
        Err(e) => return Err(e)
        Ok(None) => (t, params)
        Ok(Some((t, params))) => (t, params)
      }
      let (t, results) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_valtype, results) {
        Err(e) => return Err(e)
        Ok(None) => (t, results)
        Ok(Some((t, results))) => (t, results)
      }
      Ok(Some((t, CompType::func(params, results))))
    }
    StructCompType(fields) =>
      match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_fieldtype, fields) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, fields))) => Ok(Some((t, CompType::struct_(fields))))
      }
    ArrayCompType(ft) =>
      match self.walk_opt_fieldtype(t, ft) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ft))) => Ok(Some((t, CompType::array(ft))))
      }
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_fieldtype(
  self : ModuleTransformer[T, Err],
  t : T,
  ft : FieldType,
) -> TransformerOptResult[T, FieldType, Err] {
  match self.on_fieldtype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ft,
        f(self, t, ft),
        ModuleTransformer::walk_opt_fieldtype_default,
      )
    None => ModuleTransformer::walk_opt_fieldtype_default(self, t, ft)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_fieldtype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ft : FieldType,
) -> TransformerOptResult[T, FieldType, Err] {
  let FieldType(st, mut_) = ft
  match self.walk_opt_storagetype(t, st) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, st))) => Ok(Some((t, FieldType::new(st, mut_))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_storagetype(
  self : ModuleTransformer[T, Err],
  t : T,
  st : StorageType,
) -> TransformerOptResult[T, StorageType, Err] {
  match self.on_storagetype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        st,
        f(self, t, st),
        ModuleTransformer::walk_opt_storagetype_default,
      )
    None => ModuleTransformer::walk_opt_storagetype_default(self, t, st)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_storagetype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  st : StorageType,
) -> TransformerOptResult[T, StorageType, Err] {
  match st {
    ValTypeStorageType(vt) =>
      match self.walk_opt_valtype(t, vt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, vt))) => Ok(Some((t, StorageType::val_type(vt))))
      }
    PackTypeStorageType(_) => Ok(None)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_globalsec(
  self : ModuleTransformer[T, Err],
  t : T,
  gs : GlobalSec,
) -> TransformerOptResult[T, GlobalSec, Err] {
  match self.on_globalsec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        gs,
        f(self, t, gs),
        ModuleTransformer::walk_opt_globalsec_default,
      )
    None => ModuleTransformer::walk_opt_globalsec_default(self, t, gs)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_globalsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  gs : GlobalSec,
) -> TransformerOptResult[T, GlobalSec, Err] {
  let GlobalSec(gs) = gs
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_global, gs) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, gs))) => Ok(Some((t, GlobalSec::new(gs))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_global(
  self : ModuleTransformer[T, Err],
  t : T,
  g : Global,
) -> TransformerOptResult[T, Global, Err] {
  match self.on_global {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        g,
        f(self, t, g),
        ModuleTransformer::walk_opt_global_default,
      )
    None => ModuleTransformer::walk_opt_global_default(self, t, g)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_global_default(
  self : ModuleTransformer[T, Err],
  t : T,
  g : Global,
) -> TransformerOptResult[T, Global, Err] {
  let Global(gt, init) = g
  let (t, gt) = match self.walk_opt_globaltype(t, gt) {
    Err(e) => return Err(e)
    Ok(None) => (t, gt)
    Ok(Some((t, gt))) => (t, gt)
  }
  let (t, init) = match self.walk_opt_expr(t, init) {
    Err(e) => return Err(e)
    Ok(None) => (t, init)
    Ok(Some((t, init))) => (t, init)
  }
  Ok(Some((t, Global::new(gt, init))))
}

///|
fn[T, Err] ModuleTransformer::walk_opt_globaltype(
  self : ModuleTransformer[T, Err],
  t : T,
  gt : GlobalType,
) -> TransformerOptResult[T, GlobalType, Err] {
  match self.on_globaltype {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        gt,
        f(self, t, gt),
        ModuleTransformer::walk_opt_globaltype_default,
      )
    None => ModuleTransformer::walk_opt_globaltype_default(self, t, gt)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_globaltype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  gt : GlobalType,
) -> TransformerOptResult[T, GlobalType, Err] {
  let GlobalType(vt, mutable) = gt
  match self.walk_opt_valtype(t, vt) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, vt))) => Ok(Some((t, GlobalType::new(vt, mutable))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_elem(
  self : ModuleTransformer[T, Err],
  t : T,
  e : Elem,
) -> TransformerOptResult[T, Elem, Err] {
  let Elem(mode, kind) = e
  let (t, mode) = match self.walk_opt_elemmode(t, mode) {
    Err(e) => return Err(e)
    Ok(None) => (t, mode)
    Ok(Some((t, mode))) => (t, mode)
  }
  let (t, kind) = match self.walk_opt_elemkind(t, kind) {
    Err(e) => return Err(e)
    Ok(None) => (t, kind)
    Ok(Some((t, kind))) => (t, kind)
  }
  Ok(Some((t, Elem::new(mode, kind))))
}

///|
fn[T, Err] ModuleTransformer::walk_opt_elemmode(
  self : ModuleTransformer[T, Err],
  t : T,
  mode : ElemMode,
) -> TransformerOptResult[T, ElemMode, Err] {
  match mode {
    Active(tidx, offset) => {
      let (t, tidx) = match self.walk_opt_tableidx(t, tidx) {
        Err(e) => return Err(e)
        Ok(None) => (t, tidx)
        Ok(Some((t, tidx))) => (t, tidx)
      }
      let (t, offset) = match self.walk_opt_expr(t, offset) {
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
fn[T, Err] ModuleTransformer::walk_opt_elemkind(
  self : ModuleTransformer[T, Err],
  t : T,
  ek : ElemKind,
) -> TransformerOptResult[T, ElemKind, Err] {
  match self.on_elemkind {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ek,
        f(self, t, ek),
        ModuleTransformer::walk_opt_elemkind_default,
      )
    None => ModuleTransformer::walk_opt_elemkind_default(self, t, ek)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_elemkind_default(
  self : ModuleTransformer[T, Err],
  t : T,
  kind : ElemKind,
) -> TransformerOptResult[T, ElemKind, Err] {
  match kind {
    FuncsElemKind(idxs) =>
      match self.walk_opt_array(t, ModuleTransformer::walk_opt_funcidx, idxs) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, idxs))) => Ok(Some((t, ElemKind::funcs(idxs))))
      }
    FuncExprsElemKind(exprs) =>
      match self.walk_opt_array(t, ModuleTransformer::walk_opt_expr, exprs) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, exprs))) => Ok(Some((t, ElemKind::func_exprs(exprs))))
      }
    TypedExprsElemKind(rt, exprs) => {
      let (t, rt) = match self.walk_opt_reftype(t, rt) {
        Err(e) => return Err(e)
        Ok(None) => (t, rt)
        Ok(Some((t, rt))) => (t, rt)
      }
      let (t, exprs) = match
        self.walk_opt_array(t, ModuleTransformer::walk_opt_expr, exprs) {
        Err(e) => return Err(e)
        Ok(None) => (t, exprs)
        Ok(Some((t, exprs))) => (t, exprs)
      }
      Ok(Some((t, ElemKind::typed_exprs(rt, exprs))))
    }
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_data(
  self : ModuleTransformer[T, Err],
  t : T,
  d : Data,
) -> TransformerOptResult[T, Data, Err] {
  let Data(mode, bytes) = d
  let (t, mode) = match self.walk_opt_datamode(t, mode) {
    Err(e) => return Err(e)
    Ok(None) => (t, mode)
    Ok(Some((t, mode))) => (t, mode)
  }
  Ok(Some((t, Data::new(mode, bytes))))
}

///|
fn[T, Err] ModuleTransformer::walk_opt_datamode(
  self : ModuleTransformer[T, Err],
  t : T,
  mode : DataMode,
) -> TransformerOptResult[T, DataMode, Err] {
  match mode {
    Active(midx, offset) => {
      let (t, midx) = match self.walk_opt_memidx(t, midx) {
        Err(e) => return Err(e)
        Ok(None) => (t, midx)
        Ok(Some((t, midx))) => (t, midx)
      }
      let (t, offset) = match self.walk_opt_expr(t, offset) {
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
fn[T, Err] ModuleTransformer::walk_opt_funcsec(
  self : ModuleTransformer[T, Err],
  t : T,
  fs : FuncSec,
) -> TransformerOptResult[T, FuncSec, Err] {
  match self.on_funcsec {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        fs,
        f(self, t, fs),
        ModuleTransformer::walk_opt_funcsec_default,
      )
    None => ModuleTransformer::walk_opt_funcsec_default(self, t, fs)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_funcsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  fs : FuncSec,
) -> TransformerOptResult[T, FuncSec, Err] {
  let FuncSec(idxs) = fs
  match self.walk_opt_array(t, ModuleTransformer::walk_opt_typeidx, idxs) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, idxs))) => Ok(Some((t, FuncSec::new(idxs))))
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_unaryop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : UnaryOp,
) -> TransformerOptResult[T, UnaryOp, Err] {
  match self.on_unaryop {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        op,
        f(self, t, op),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, op)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_binaryop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : BinaryOp,
) -> TransformerOptResult[T, BinaryOp, Err] {
  match self.on_binaryop {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        op,
        f(self, t, op),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, op)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_storeop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : StoreOp,
) -> TransformerOptResult[T, StoreOp, Err] {
  match self.on_storeop {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        op,
        f(self, t, op),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, op)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_memarg(
  self : ModuleTransformer[T, Err],
  t : T,
  ma : MemArg,
) -> TransformerOptResult[T, MemArg, Err] {
  match self.on_memarg {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        ma,
        f(self, t, ma),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, ma)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_loadop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : LoadOp,
) -> TransformerOptResult[T, LoadOp, Err] {
  match self.on_loadop {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        op,
        f(self, t, op),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, op)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_extractlaneop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : ExtractLaneOp,
) -> TransformerOptResult[T, ExtractLaneOp, Err] {
  match self.on_extractlaneop {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        op,
        f(self, t, op),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, op)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_replacelaneop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : ReplaceLaneOp,
) -> TransformerOptResult[T, ReplaceLaneOp, Err] {
  match self.on_replacelaneop {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        op,
        f(self, t, op),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, op)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_v128shiftop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : V128ShiftOp,
) -> TransformerOptResult[T, V128ShiftOp, Err] {
  match self.on_v128shiftop {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        op,
        f(self, t, op),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, op)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_v128ternaryop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : V128TernaryOp,
) -> TransformerOptResult[T, V128TernaryOp, Err] {
  match self.on_v128ternaryop {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        op,
        f(self, t, op),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, op)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_v128loadlaneop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : V128LoadLaneOp,
) -> TransformerOptResult[T, V128LoadLaneOp, Err] {
  match self.on_v128loadlaneop {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        op,
        f(self, t, op),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, op)
  }
}

///|
fn[T, Err] ModuleTransformer::walk_opt_v128storelaneop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : V128StoreLaneOp,
) -> TransformerOptResult[T, V128StoreLaneOp, Err] {
  match self.on_v128storelaneop {
    Some(f) =>
      ModuleTransformer::apply_action_opt(
        self,
        t,
        op,
        f(self, t, op),
        ModuleTransformer::no_children_opt,
      )
    None => ModuleTransformer::no_children_opt(self, t, op)
  }
}

// Public tuple-result wrappers

///|
pub fn[T, E, Err] ModuleTransformer::walk_array(
  self : ModuleTransformer[T, Err],
  t : T,
  f : (ModuleTransformer[T, Err], T, E) -> TransformerResult[T, E, Err],
  a : Array[E],
) -> TransformerResult[T, Array[E], Err] {
  match
    self.walk_opt_array(
      t,
      fn(self, t, item) {
        match f(self, t, item) {
          Ok((next_item, next_t)) => Ok(Some((next_t, next_item)))
          Err(e) => Err(e)
        }
      },
      a,
    ) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((a, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_name(
  self : ModuleTransformer[T, Err],
  t : T,
  name : Name,
) -> TransformerResult[T, Name, Err] {
  match self.walk_opt_name(t, name) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((name, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_expr(
  self : ModuleTransformer[T, Err],
  t : T,
  expr : Expr,
) -> TransformerResult[T, Expr, Err] {
  match self.walk_opt_expr(t, expr) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((expr, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_texpr(
  self : ModuleTransformer[T, Err],
  t : T,
  texpr : TExpr,
) -> TransformerResult[T, TExpr, Err] {
  match self.walk_opt_texpr(t, texpr) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((texpr, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_expr_default(
  self : ModuleTransformer[T, Err],
  t : T,
  expr : Expr,
) -> TransformerResult[T, Expr, Err] {
  match self.walk_opt_expr_default(t, expr) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((expr, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_texpr_default(
  self : ModuleTransformer[T, Err],
  t : T,
  expr : TExpr,
) -> TransformerResult[T, TExpr, Err] {
  match self.walk_opt_texpr_default(t, expr) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((expr, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tinstruction(
  self : ModuleTransformer[T, Err],
  t : T,
  tinstr : TInstr,
) -> TransformerResult[T, TInstr, Err] {
  match self.walk_opt_tinstruction(t, tinstr) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((tinstr, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tinstruction_default(
  self : ModuleTransformer[T, Err],
  t : T,
  tinstr : TInstr,
) -> TransformerResult[T, TInstr, Err] {
  match self.walk_opt_tinstruction_default(t, tinstr) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((tinstr, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_instruction(
  self : ModuleTransformer[T, Err],
  t : T,
  instr : Instruction,
) -> TransformerResult[T, Instruction, Err] {
  match self.walk_opt_instruction(t, instr) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((instr, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_instruction_default(
  self : ModuleTransformer[T, Err],
  t : T,
  instr : Instruction,
) -> TransformerResult[T, Instruction, Err] {
  match self.walk_opt_instruction_default(t, instr) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((instr, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_blocktype(
  self : ModuleTransformer[T, Err],
  t : T,
  bt : BlockType,
) -> TransformerResult[T, BlockType, Err] {
  match self.walk_opt_blocktype(t, bt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((bt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_blocktype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  bt : BlockType,
) -> TransformerResult[T, BlockType, Err] {
  match self.walk_opt_blocktype_default(t, bt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((bt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_catch(
  self : ModuleTransformer[T, Err],
  t : T,
  c : Catch,
) -> TransformerResult[T, Catch, Err] {
  match self.walk_opt_catch(t, c) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((c, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_funcidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : FuncIdx,
) -> TransformerResult[T, FuncIdx, Err] {
  match self.walk_opt_funcidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_typeidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : TypeIdx,
) -> TransformerResult[T, TypeIdx, Err] {
  match self.walk_opt_typeidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_localidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : LocalIdx,
) -> TransformerResult[T, LocalIdx, Err] {
  match self.walk_opt_localidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_globalidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : GlobalIdx,
) -> TransformerResult[T, GlobalIdx, Err] {
  match self.walk_opt_globalidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tableidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : TableIdx,
) -> TransformerResult[T, TableIdx, Err] {
  match self.walk_opt_tableidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_memidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : MemIdx,
) -> TransformerResult[T, MemIdx, Err] {
  match self.walk_opt_memidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_labelidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : LabelIdx,
) -> TransformerResult[T, LabelIdx, Err] {
  match self.walk_opt_labelidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_laneidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : LaneIdx,
) -> TransformerResult[T, LaneIdx, Err] {
  match self.walk_opt_laneidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_dataidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : DataIdx,
) -> TransformerResult[T, DataIdx, Err] {
  match self.walk_opt_dataidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_elemidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : ElemIdx,
) -> TransformerResult[T, ElemIdx, Err] {
  match self.walk_opt_elemidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tagidx(
  self : ModuleTransformer[T, Err],
  t : T,
  idx : TagIdx,
) -> TransformerResult[T, TagIdx, Err] {
  match self.walk_opt_tagidx(t, idx) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((idx, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_valtype(
  self : ModuleTransformer[T, Err],
  t : T,
  vt : ValType,
) -> TransformerResult[T, ValType, Err] {
  match self.walk_opt_valtype(t, vt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((vt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_valtype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  vt : ValType,
) -> TransformerResult[T, ValType, Err] {
  match self.walk_opt_valtype_default(t, vt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((vt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_numtype(
  self : ModuleTransformer[T, Err],
  t : T,
  nt : NumType,
) -> TransformerResult[T, NumType, Err] {
  match self.walk_opt_numtype(t, nt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((nt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_reftype(
  self : ModuleTransformer[T, Err],
  t : T,
  rt : RefType,
) -> TransformerResult[T, RefType, Err] {
  match self.walk_opt_reftype(t, rt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((rt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_reftype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  rt : RefType,
) -> TransformerResult[T, RefType, Err] {
  match self.walk_opt_reftype_default(t, rt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((rt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_heaptype(
  self : ModuleTransformer[T, Err],
  t : T,
  ht : HeapType,
) -> TransformerResult[T, HeapType, Err] {
  match self.walk_opt_heaptype(t, ht) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ht, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_heaptype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ht : HeapType,
) -> TransformerResult[T, HeapType, Err] {
  match self.walk_opt_heaptype_default(t, ht) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ht, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_customsec(
  self : ModuleTransformer[T, Err],
  t : T,
  sec : CustomSec,
) -> TransformerResult[T, CustomSec, Err] {
  match self.walk_opt_customsec(t, sec) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((sec, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_customsecs(
  self : ModuleTransformer[T, Err],
  t : T,
  secs : Array[CustomSec],
) -> TransformerResult[T, Array[CustomSec], Err] {
  match self.walk_opt_customsecs(t, secs) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((secs, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_module(
  self : ModuleTransformer[T, Err],
  t : T,
  mod : Module,
) -> TransformerResult[T, Module, Err] {
  match self.walk_opt_module(t, mod) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((mod, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_module_default(
  self : ModuleTransformer[T, Err],
  t : T,
  mod : Module,
) -> TransformerResult[T, Module, Err] {
  match self.walk_opt_module_default(t, mod) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((mod, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_datasec(
  self : ModuleTransformer[T, Err],
  t : T,
  ds : DataSec,
) -> TransformerResult[T, DataSec, Err] {
  match self.walk_opt_datasec(t, ds) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ds, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_datasec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ds : DataSec,
) -> TransformerResult[T, DataSec, Err] {
  match self.walk_opt_datasec_default(t, ds) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ds, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_codesec(
  self : ModuleTransformer[T, Err],
  t : T,
  cs : CodeSec,
) -> TransformerResult[T, CodeSec, Err] {
  match self.walk_opt_codesec(t, cs) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((cs, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_codesec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  cs : CodeSec,
) -> TransformerResult[T, CodeSec, Err] {
  match self.walk_opt_codesec_default(t, cs) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((cs, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_datacntsec(
  self : ModuleTransformer[T, Err],
  t : T,
  dcs : DataCntSec,
) -> TransformerResult[T, DataCntSec, Err] {
  match self.walk_opt_datacntsec(t, dcs) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((dcs, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_elemsec(
  self : ModuleTransformer[T, Err],
  t : T,
  es : ElemSec,
) -> TransformerResult[T, ElemSec, Err] {
  match self.walk_opt_elemsec(t, es) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((es, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_elemsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  es : ElemSec,
) -> TransformerResult[T, ElemSec, Err] {
  match self.walk_opt_elemsec_default(t, es) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((es, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_startsec(
  self : ModuleTransformer[T, Err],
  t : T,
  ss : StartSec,
) -> TransformerResult[T, StartSec, Err] {
  match self.walk_opt_startsec(t, ss) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ss, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_startsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ss : StartSec,
) -> TransformerResult[T, StartSec, Err] {
  match self.walk_opt_startsec_default(t, ss) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ss, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_exportsec(
  self : ModuleTransformer[T, Err],
  t : T,
  es : ExportSec,
) -> TransformerResult[T, ExportSec, Err] {
  match self.walk_opt_exportsec(t, es) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((es, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_importsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  es : ImportSec,
) -> TransformerResult[T, ImportSec, Err] {
  match self.walk_opt_importsec_default(t, es) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((es, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_exportsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  es : ExportSec,
) -> TransformerResult[T, ExportSec, Err] {
  match self.walk_opt_exportsec_default(t, es) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((es, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tagsec(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TagSec,
) -> TransformerResult[T, TagSec, Err] {
  match self.walk_opt_tagsec(t, ts) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ts, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tagsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TagSec,
) -> TransformerResult[T, TagSec, Err] {
  match self.walk_opt_tagsec_default(t, ts) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ts, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_memsec(
  self : ModuleTransformer[T, Err],
  t : T,
  ms : MemSec,
) -> TransformerResult[T, MemSec, Err] {
  match self.walk_opt_memsec(t, ms) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ms, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_memsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ms : MemSec,
) -> TransformerResult[T, MemSec, Err] {
  match self.walk_opt_memsec_default(t, ms) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ms, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tablesec(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TableSec,
) -> TransformerResult[T, TableSec, Err] {
  match self.walk_opt_tablesec(t, ts) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ts, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tablesec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TableSec,
) -> TransformerResult[T, TableSec, Err] {
  match self.walk_opt_tablesec_default(t, ts) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ts, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_func(
  self : ModuleTransformer[T, Err],
  t : T,
  func : Func,
) -> TransformerResult[T, Func, Err] {
  match self.walk_opt_func(t, func) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((func, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_func_default(
  self : ModuleTransformer[T, Err],
  t : T,
  f : Func,
) -> TransformerResult[T, Func, Err] {
  match self.walk_opt_func_default(t, f) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((f, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_locals(
  self : ModuleTransformer[T, Err],
  t : T,
  l : Locals,
) -> TransformerResult[T, Locals, Err] {
  match self.walk_opt_locals(t, l) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((l, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_locals_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ls : Locals,
) -> TransformerResult[T, Locals, Err] {
  match self.walk_opt_locals_default(t, ls) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ls, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_single_local(
  self : ModuleTransformer[T, Err],
  t : T,
  l : LocalRun,
) -> TransformerResult[T, LocalRun, Err] {
  match self.walk_opt_local_run(t, l) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((l, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_importsec(
  self : ModuleTransformer[T, Err],
  t : T,
  ims : ImportSec,
) -> TransformerResult[T, ImportSec, Err] {
  match self.walk_opt_importsec(t, ims) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ims, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_export(
  self : ModuleTransformer[T, Err],
  t : T,
  expt : Export,
) -> TransformerResult[T, Export, Err] {
  match self.walk_opt_export(t, expt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((expt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_export_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ex : Export,
) -> TransformerResult[T, Export, Err] {
  match self.walk_opt_export_default(t, ex) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ex, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_externidx(
  self : ModuleTransformer[T, Err],
  t : T,
  ex : ExternIdx,
) -> TransformerResult[T, ExternIdx, Err] {
  match self.walk_opt_externidx(t, ex) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ex, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_externidx_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ex : ExternIdx,
) -> TransformerResult[T, ExternIdx, Err] {
  match self.walk_opt_externidx_default(t, ex) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ex, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_table(
  self : ModuleTransformer[T, Err],
  t : T,
  tbl : Table,
) -> TransformerResult[T, Table, Err] {
  match self.walk_opt_table(t, tbl) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((tbl, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_table_default(
  self : ModuleTransformer[T, Err],
  t : T,
  tbl : Table,
) -> TransformerResult[T, Table, Err] {
  match self.walk_opt_table_default(t, tbl) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((tbl, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_import(
  self : ModuleTransformer[T, Err],
  t : T,
  im : Import,
) -> TransformerResult[T, Import, Err] {
  match self.walk_opt_import(t, im) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((im, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_externtype(
  self : ModuleTransformer[T, Err],
  t : T,
  ex : ExternType,
) -> TransformerResult[T, ExternType, Err] {
  match self.walk_opt_externtype(t, ex) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ex, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tagtype(
  self : ModuleTransformer[T, Err],
  t : T,
  tt : TagType,
) -> TransformerResult[T, TagType, Err] {
  match self.walk_opt_tagtype(t, tt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((tt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tagtype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  tt : TagType,
) -> TransformerResult[T, TagType, Err] {
  match self.walk_opt_tagtype_default(t, tt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((tt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_memtype(
  self : ModuleTransformer[T, Err],
  t : T,
  mt : MemType,
) -> TransformerResult[T, MemType, Err] {
  match self.walk_opt_memtype(t, mt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((mt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_memtype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  mt : MemType,
) -> TransformerResult[T, MemType, Err] {
  match self.walk_opt_memtype_default(t, mt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((mt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_tabletype(
  self : ModuleTransformer[T, Err],
  t : T,
  tt : TableType,
) -> TransformerResult[T, TableType, Err] {
  match self.walk_opt_tabletype(t, tt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((tt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_limits(
  self : ModuleTransformer[T, Err],
  t : T,
  l : Limits,
) -> TransformerResult[T, Limits, Err] {
  match self.walk_opt_limits(t, l) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((l, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_typesec(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TypeSec,
) -> TransformerResult[T, TypeSec, Err] {
  match self.walk_opt_typesec(t, ts) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ts, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_typesec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ts : TypeSec,
) -> TransformerResult[T, TypeSec, Err] {
  match self.walk_opt_typesec_default(t, ts) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ts, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_rectype(
  self : ModuleTransformer[T, Err],
  t : T,
  rt : RecType,
) -> TransformerResult[T, RecType, Err] {
  match self.walk_opt_rectype(t, rt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((rt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_rectype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  rt : RecType,
) -> TransformerResult[T, RecType, Err] {
  match self.walk_opt_rectype_default(t, rt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((rt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_subtype(
  self : ModuleTransformer[T, Err],
  t : T,
  st : SubType,
) -> TransformerResult[T, SubType, Err] {
  match self.walk_opt_subtype(t, st) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((st, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_subtype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  st : SubType,
) -> TransformerResult[T, SubType, Err] {
  match self.walk_opt_subtype_default(t, st) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((st, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_comptype(
  self : ModuleTransformer[T, Err],
  t : T,
  ct : CompType,
) -> TransformerResult[T, CompType, Err] {
  match self.walk_opt_comptype(t, ct) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ct, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_comptype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ct : CompType,
) -> TransformerResult[T, CompType, Err] {
  match self.walk_opt_comptype_default(t, ct) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ct, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_fieldtype(
  self : ModuleTransformer[T, Err],
  t : T,
  ft : FieldType,
) -> TransformerResult[T, FieldType, Err] {
  match self.walk_opt_fieldtype(t, ft) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ft, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_fieldtype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  ft : FieldType,
) -> TransformerResult[T, FieldType, Err] {
  match self.walk_opt_fieldtype_default(t, ft) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ft, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_storagetype(
  self : ModuleTransformer[T, Err],
  t : T,
  st : StorageType,
) -> TransformerResult[T, StorageType, Err] {
  match self.walk_opt_storagetype(t, st) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((st, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_storagetype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  st : StorageType,
) -> TransformerResult[T, StorageType, Err] {
  match self.walk_opt_storagetype_default(t, st) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((st, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_globalsec(
  self : ModuleTransformer[T, Err],
  t : T,
  gs : GlobalSec,
) -> TransformerResult[T, GlobalSec, Err] {
  match self.walk_opt_globalsec(t, gs) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((gs, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_globalsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  gs : GlobalSec,
) -> TransformerResult[T, GlobalSec, Err] {
  match self.walk_opt_globalsec_default(t, gs) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((gs, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_global(
  self : ModuleTransformer[T, Err],
  t : T,
  g : Global,
) -> TransformerResult[T, Global, Err] {
  match self.walk_opt_global(t, g) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((g, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_global_default(
  self : ModuleTransformer[T, Err],
  t : T,
  g : Global,
) -> TransformerResult[T, Global, Err] {
  match self.walk_opt_global_default(t, g) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((g, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_globaltype(
  self : ModuleTransformer[T, Err],
  t : T,
  gt : GlobalType,
) -> TransformerResult[T, GlobalType, Err] {
  match self.walk_opt_globaltype(t, gt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((gt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_globaltype_default(
  self : ModuleTransformer[T, Err],
  t : T,
  gt : GlobalType,
) -> TransformerResult[T, GlobalType, Err] {
  match self.walk_opt_globaltype_default(t, gt) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((gt, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_elem(
  self : ModuleTransformer[T, Err],
  t : T,
  e : Elem,
) -> TransformerResult[T, Elem, Err] {
  match self.walk_opt_elem(t, e) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((e, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_elemmode(
  self : ModuleTransformer[T, Err],
  t : T,
  mode : ElemMode,
) -> TransformerResult[T, ElemMode, Err] {
  match self.walk_opt_elemmode(t, mode) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((mode, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_elemkind(
  self : ModuleTransformer[T, Err],
  t : T,
  ek : ElemKind,
) -> TransformerResult[T, ElemKind, Err] {
  match self.walk_opt_elemkind(t, ek) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ek, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_elemkind_default(
  self : ModuleTransformer[T, Err],
  t : T,
  kind : ElemKind,
) -> TransformerResult[T, ElemKind, Err] {
  match self.walk_opt_elemkind_default(t, kind) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((kind, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_data(
  self : ModuleTransformer[T, Err],
  t : T,
  d : Data,
) -> TransformerResult[T, Data, Err] {
  match self.walk_opt_data(t, d) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((d, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_datamode(
  self : ModuleTransformer[T, Err],
  t : T,
  mode : DataMode,
) -> TransformerResult[T, DataMode, Err] {
  match self.walk_opt_datamode(t, mode) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((mode, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_funcsec(
  self : ModuleTransformer[T, Err],
  t : T,
  fs : FuncSec,
) -> TransformerResult[T, FuncSec, Err] {
  match self.walk_opt_funcsec(t, fs) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((fs, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_funcsec_default(
  self : ModuleTransformer[T, Err],
  t : T,
  fs : FuncSec,
) -> TransformerResult[T, FuncSec, Err] {
  match self.walk_opt_funcsec_default(t, fs) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((fs, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_unaryop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : UnaryOp,
) -> TransformerResult[T, UnaryOp, Err] {
  match self.walk_opt_unaryop(t, op) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((op, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_binaryop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : BinaryOp,
) -> TransformerResult[T, BinaryOp, Err] {
  match self.walk_opt_binaryop(t, op) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((op, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_storeop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : StoreOp,
) -> TransformerResult[T, StoreOp, Err] {
  match self.walk_opt_storeop(t, op) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((op, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_memarg(
  self : ModuleTransformer[T, Err],
  t : T,
  ma : MemArg,
) -> TransformerResult[T, MemArg, Err] {
  match self.walk_opt_memarg(t, ma) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((ma, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_loadop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : LoadOp,
) -> TransformerResult[T, LoadOp, Err] {
  match self.walk_opt_loadop(t, op) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((op, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_extractlaneop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : ExtractLaneOp,
) -> TransformerResult[T, ExtractLaneOp, Err] {
  match self.walk_opt_extractlaneop(t, op) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((op, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_replacelaneop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : ReplaceLaneOp,
) -> TransformerResult[T, ReplaceLaneOp, Err] {
  match self.walk_opt_replacelaneop(t, op) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((op, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_v128shiftop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : V128ShiftOp,
) -> TransformerResult[T, V128ShiftOp, Err] {
  match self.walk_opt_v128shiftop(t, op) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((op, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_v128ternaryop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : V128TernaryOp,
) -> TransformerResult[T, V128TernaryOp, Err] {
  match self.walk_opt_v128ternaryop(t, op) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((op, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_v128loadlaneop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : V128LoadLaneOp,
) -> TransformerResult[T, V128LoadLaneOp, Err] {
  match self.walk_opt_v128loadlaneop(t, op) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((op, t))
    Err(e) => Err(e)
  }
}

///|
pub fn[T, Err] ModuleTransformer::walk_v128storelaneop(
  self : ModuleTransformer[T, Err],
  t : T,
  op : V128StoreLaneOp,
) -> TransformerResult[T, V128StoreLaneOp, Err] {
  match self.walk_opt_v128storelaneop(t, op) {
    Ok(Some((t, next_elem))) => Ok((next_elem, t))
    Ok(None) => Ok((op, t))
    Err(e) => Err(e)
  }
}
