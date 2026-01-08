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
pub(all) struct ModuleTransformer[T] {
  on_typesec : ((ModuleTransformer[T], T, TypeSec) -> TransformerResult[T, TypeSec])?
  on_funcsec : ((ModuleTransformer[T], T, FuncSec) -> TransformerResult[T, FuncSec])?
  on_tablesec : ((ModuleTransformer[T], T, TableSec) -> TransformerResult[T, TableSec])?
  on_memsec : ((ModuleTransformer[T], T, MemSec) -> TransformerResult[T, MemSec])?
  on_tagsec : ((ModuleTransformer[T], T, TagSec) -> TransformerResult[T, TagSec])?
  on_globalsec : ((ModuleTransformer[T], T, GlobalSec) -> TransformerResult[T, GlobalSec])?
  on_exportsec : ((ModuleTransformer[T], T, ExportSec) -> TransformerResult[T, ExportSec])?
  on_startsec : ((ModuleTransformer[T], T, StartSec) -> TransformerResult[T, StartSec])?
  on_elemsec : ((ModuleTransformer[T], T, ElemSec) -> TransformerResult[T, ElemSec])?
  on_elemkind : ((ModuleTransformer[T], T, ElemKind) -> TransformerResult[T, ElemKind])?
  on_datacntsec : ((ModuleTransformer[T], T, DataCntSec) -> TransformerResult[T, DataCntSec])?
  on_codesec : ((ModuleTransformer[T], T, CodeSec) -> TransformerResult[T, CodeSec])?
  on_datasec : ((ModuleTransformer[T], T, DataSec) -> TransformerResult[T, DataSec])?
  on_instruction : ((ModuleTransformer[T], T, Instruction) -> TransformerResult[T, Instruction])?
  on_tinstruction : ((ModuleTransformer[T], T, TInstr) -> TransformerResult[T, TInstr])?
  on_expr : ((ModuleTransformer[T], T, Expr) -> TransformerResult[T, Expr])?
  on_texpr : ((ModuleTransformer[T], T, TExpr) -> TransformerResult[T, TExpr])?
  on_table : ((ModuleTransformer[T], T, Table) -> TransformerResult[T, Table])?
  on_valtype : ((ModuleTransformer[T], T, ValType) -> TransformerResult[T, ValType])?
  on_numtype : ((ModuleTransformer[T], T, NumType) -> TransformerResult[T, NumType])?
  on_rectype : ((ModuleTransformer[T], T, RecType) -> TransformerResult[T, RecType])?
  on_subtype : ((ModuleTransformer[T], T, SubType) -> TransformerResult[T, SubType])?
  on_comptype : ((ModuleTransformer[T], T, CompType) -> TransformerResult[T, CompType])?
  on_reftype : ((ModuleTransformer[T], T, RefType) -> TransformerResult[T, RefType])?
  on_heaptype : ((ModuleTransformer[T], T, HeapType) -> TransformerResult[T, HeapType])?
  on_blocktype : ((ModuleTransformer[T], T, BlockType) -> TransformerResult[T, BlockType])?
  on_funcidx : ((ModuleTransformer[T], T, FuncIdx) -> TransformerResult[T, FuncIdx])?
  on_typeidx : ((ModuleTransformer[T], T, TypeIdx) -> TransformerResult[T, TypeIdx])?
  on_laneidx : ((ModuleTransformer[T], T, LaneIdx) -> TransformerResult[T, LaneIdx])?
  on_localidx : ((ModuleTransformer[T], T, LocalIdx) -> TransformerResult[T, LocalIdx])?
  on_globalidx : ((ModuleTransformer[T], T, GlobalIdx) -> TransformerResult[T, GlobalIdx])?
  on_tableidx : ((ModuleTransformer[T], T, TableIdx) -> TransformerResult[T, TableIdx])?
  on_memidx : ((ModuleTransformer[T], T, MemIdx) -> TransformerResult[T, MemIdx])?
  on_labelidx : ((ModuleTransformer[T], T, LabelIdx) -> TransformerResult[T, LabelIdx])?
  on_dataidx : ((ModuleTransformer[T], T, DataIdx) -> TransformerResult[T, DataIdx])?
  on_elemidx : ((ModuleTransformer[T], T, ElemIdx) -> TransformerResult[T, ElemIdx])?
  on_tagidx : ((ModuleTransformer[T], T, TagIdx) -> TransformerResult[T, TagIdx])?
  on_name : ((ModuleTransformer[T], T, Name) -> TransformerResult[T, Name])?
  on_externtype : ((ModuleTransformer[T], T, ExternType) -> TransformerResult[T, ExternType])?
  on_limits : ((ModuleTransformer[T], T, Limits) -> TransformerResult[T, Limits])?
  on_memtype : ((ModuleTransformer[T], T, MemType) -> TransformerResult[T, MemType])?
  on_tagtype : ((ModuleTransformer[T], T, TagType) -> TransformerResult[T, TagType])?
  on_export : ((ModuleTransformer[T], T, Export) -> TransformerResult[T, Export])?
  on_global : ((ModuleTransformer[T], T, Global) -> TransformerResult[T, Global])?
  on_globaltype : ((ModuleTransformer[T], T, GlobalType) -> TransformerResult[T, GlobalType])?
  on_func : ((ModuleTransformer[T], T, Func) -> TransformerResult[T, Func])?
  on_locals : ((ModuleTransformer[T], T, Array[Locals]) -> TransformerResult[T, Array[Locals]])?
  on_externidx : ((ModuleTransformer[T], T, ExternIdx) -> TransformerResult[T, ExternIdx])?
  on_fieldtype : ((ModuleTransformer[T], T, FieldType) -> TransformerResult[T, FieldType])?
  on_storagetype : ((ModuleTransformer[T], T, StorageType) -> TransformerResult[T, StorageType])?
  on_unaryop : ((ModuleTransformer[T], T, UnaryOp) -> TransformerResult[T, UnaryOp])?
  on_binaryop : ((ModuleTransformer[T], T, BinaryOp) -> TransformerResult[T, BinaryOp])?
  on_storeop : ((ModuleTransformer[T], T, StoreOp) -> TransformerResult[T, StoreOp])?
  on_loadop : ((ModuleTransformer[T], T, LoadOp) -> TransformerResult[T, LoadOp])?
  on_extractlaneop : ((ModuleTransformer[T], T, ExtractLaneOp) -> TransformerResult[T, ExtractLaneOp])?
  on_replacelaneop : ((ModuleTransformer[T], T, ReplaceLaneOp) -> TransformerResult[T, ReplaceLaneOp])?
  on_v128shiftop : ((ModuleTransformer[T], T, V128ShiftOp) -> TransformerResult[T, V128ShiftOp])?
  on_v128ternaryop : ((ModuleTransformer[T], T, V128TernaryOp) -> TransformerResult[T, V128TernaryOp])?
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
    on_typesec: None,
    on_funcsec: None,
    on_tablesec: None,
    on_memsec: None,
    on_tagsec: None,
    on_globalsec: None,
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
    Ok(Some((t, instructions))) => Ok(Some((t, Expr(instructions))))
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
  Ok(Some((t, TExpr(instructions))))
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
      Ok(Some((t, TRefNull(ht))))
    }
    TRefFunc(fi) => {
      let (t, fi) = match self.walk_funcidx(t, fi) {
        Ok(None) => (t, fi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TRefFunc(fi))))
    }
    // === Nullary (0 children) ===

    TLocalGet(li) => {
      let (t, li) = match self.walk_localidx(t, li) {
        Ok(None) => (t, li)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TLocalGet(li))))
    }
    TGlobalGet(gi) => {
      let (t, gi) = match self.walk_globalidx(t, gi) {
        Ok(None) => (t, gi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TGlobalGet(gi))))
    }
    TMemorySize(mi) => {
      let (t, mi) = match self.walk_memidx(t, mi) {
        Ok(None) => (t, mi)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TMemorySize(mi))))
    }
    TTableSize(ti) => {
      let (t, ti) = match self.walk_tableidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TTableSize(ti))))
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
      Ok(Some((t, TUnary(op, i))))
    }
    TDrop(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TDrop(i))))
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
      Ok(Some((t, TLocalSet(li, i))))
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
      Ok(Some((t, TLocalTee(li, i))))
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
      Ok(Some((t, TGlobalSet(gi, i))))
    }
    TRefIsNull(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TRefIsNull(i))))
    }
    TRefAsNonNull(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TRefAsNonNull(i))))
    }
    TI31GetS(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TI31GetS(i))))
    }
    TI31GetU(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TI31GetU(i))))
    }
    TRefI31(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TRefI31(i))))
    }
    TArrayLen(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TArrayLen(i))))
    }
    TAnyConvertExtern(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TAnyConvertExtern(i))))
    }
    TExternConvertAny(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TExternConvertAny(i))))
    }
    TThrowRef(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TThrowRef(i))))
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
      Ok(Some((t, TBinary(op, i1, i2))))
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
      Ok(Some((t, TRefEq(i1, i2))))
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
      Ok(Some((t, TStore(op, ma, i1, i2))))
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
      Ok(Some((t, TLoad(op, ma, i))))
    }

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
      Ok(Some((t, TMemoryGrow(mi, i))))
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
      Ok(Some((t, TMemoryFill(mi, i1, i2, i3))))
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
      Ok(Some((t, TMemoryCopy(mi1, mi2, i1, i2, i3))))
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
      Ok(Some((t, TMemoryInit(di, mi, i1, i2, i3))))
    }
    TDataDrop(di) => {
      let (t, di) = match self.walk_dataidx(t, di) {
        Ok(None) => (t, di)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TDataDrop(di))))
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
      Ok(Some((t, TTableGet(ti, i))))
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
      Ok(Some((t, TTableSet(ti, i1, i2))))
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
      Ok(Some((t, TTableGrow(ti, i1, i2))))
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
      Ok(Some((t, TTableFill(ti, i1, i2, i3))))
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
      Ok(Some((t, TTableCopy(ti1, ti2, i1, i2, i3))))
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
      Ok(Some((t, TTableInit(ei, ti, i1, i2, i3))))
    }
    TElemDrop(ei) => {
      let (t, ei) = match self.walk_elemidx(t, ei) {
        Ok(None) => (t, ei)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TElemDrop(ei))))
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
      Ok(Some((t, TCall(fi, i))))
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
      Ok(Some((t, TCallIndirect(tyi, tai, i0, i))))
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
      Ok(Some((t, TCallRef(tyi, i0, i))))
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
      Ok(Some((t, TReturnCall(fi, i))))
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
      Ok(Some((t, TReturnCallIndirect(tyi, tai, i0, i))))
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
      Ok(Some((t, TReturnCallRef(tyi, i0, i))))
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
      Ok(Some((t, TBlock(bt, e))))
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
      Ok(Some((t, TLoop(bt, e))))
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
      Ok(Some((t, TIf(bt, i_if, e_then, e_else_option))))
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
      Ok(Some((t, TTryTable(bt, c, e))))
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
      Ok(Some((t, TThrow(ti, i))))
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
      Ok(Some((t, TBr(li, i))))
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
      Ok(Some((t, TBrIf(li, i0, i))))
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
      Ok(Some((t, TBrTable(ls, li, i0, i))))
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
      Ok(Some((t, TBrOnNull(li, i0, i))))
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
      Ok(Some((t, TBrOnNonNull(li, i0, i))))
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
      Ok(Some((t, TBrOnCast(li, co, ht0, ht1, i0, i))))
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
      Ok(Some((t, TBrOnCastFail(li, co, ht0, ht1, i0, i))))
    }
    TReturn(i) => {
      let (t, i) = match
        self.walk_array(t, ModuleTransformer::walk_tinstruction, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TReturn(i))))
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
      Ok(Some((t, TSelect(vts_option, i0, i1, i2))))
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
      Ok(Some((t, TStructNew(ti, i))))
    }
    TStructNewDefault(ti) => {
      let (t, ti) = match self.walk_typeidx(t, ti) {
        Ok(None) => (t, ti)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TStructNewDefault(ti))))
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
      Ok(Some((t, TStructGet(ti, f, i))))
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
      Ok(Some((t, TStructGetS(ti, f, i))))
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
      Ok(Some((t, TStructGetU(ti, f, i))))
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
      Ok(Some((t, TStructSet(ti, f, i0, i1))))
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
      Ok(Some((t, TArrayNew(ti, i0, i1))))
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
      Ok(Some((t, TArrayNewDefault(ti, i))))
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
      Ok(Some((t, TArrayNewFixed(ti, i))))
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
      Ok(Some((t, TArrayNewData(ti, di, i0, i1))))
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
      Ok(Some((t, TArrayNewElem(ti, ei, i0, i1))))
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
      Ok(Some((t, TArrayGet(ti, i0, i1))))
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
      Ok(Some((t, TArrayGetS(ti, i0, i1))))
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
      Ok(Some((t, TArrayGetU(ti, i0, i1))))
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
      Ok(Some((t, TArraySet(ti, i0, i1, i2))))
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
      Ok(Some((t, TArrayFill(ti, i0, i1, i2, i3))))
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
        Ok(None) => (t, i3)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TArrayCopy(ti0, ti1, i0, i1, i2, i3, i4))))
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
      Ok(Some((t, TArrayInitData(ti, di, i0, i1, i2, i3))))
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
      Ok(Some((t, TArrayInitElem(ti, ei, i0, i1, i2, i3))))
    }

    // === GC: Casts ===
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
      Ok(Some((t, TRefTest(b, ht, i))))
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
      Ok(Some((t, TRefCast(b, ht, i))))
    }

    // === SIMD: Splat (scalar -> v128) ===
    TI8x16Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TI8x16Splat(i))))
    }
    TI16x8Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TI16x8Splat(i))))
    }
    TI32x4Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TI32x4Splat(i))))
    }
    TI64x2Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TI64x2Splat(i))))
    }
    TF32x4Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TF32x4Splat(i))))
    }
    TF64x2Splat(i) => {
      let (t, i) = match self.walk_tinstruction(t, i) {
        Ok(None) => (t, i)
        Ok(Some(t)) => t
        Err(t) => return Err(t)
      }
      Ok(Some((t, TF64x2Splat(i))))
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
      Ok(Some((t, TExtractLane(op, li, i))))
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
      Ok(Some((t, TReplaceLane(op, li, i0, i1))))
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
            TI8x16Shuffle(
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
      Ok(Some((t, TI8x16Swizzle(i0, i1))))
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
      Ok(Some((t, TI8x16RelaxedSwizzle(i0, i1))))
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
      Ok(Some((t, TV128Shift(op, i0, i1))))
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
      Ok(Some((t, TV128Ternary(op, i0, i1, i2))))
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
      Ok(Some((t, TV128LoadLane(op, ma, li, i0, i1))))
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
      Ok(Some((t, TV128StoreLane(op, ma, li, i0, i1))))
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
            Ok(Some((t, body))) => Ok(Some((t, Block(bt, body))))
          }
        Ok(Some((t, bt))) =>
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, Block(bt, body))))
            Ok(Some((t, body))) => Ok(Some((t, Block(bt, body))))
          }
      }
    Loop(bt, body) =>
      match self.walk_blocktype(t, bt) {
        Err(e) => Err(e)
        Ok(None) =>
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, body))) => Ok(Some((t, Loop(bt, body))))
          }
        Ok(Some((t, bt))) =>
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, Loop(bt, body))))
            Ok(Some((t, body))) => Ok(Some((t, Loop(bt, body))))
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
      Ok(Some((t, If(bt, then_body, else_body_opt))))
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
                  Ok(Some((t, TryTable(bt, catches, body))))
              }
            Ok(Some((t, catches))) =>
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) => Ok(Some((t, TryTable(bt, catches, body))))
                Ok(Some((t, body))) =>
                  Ok(Some((t, TryTable(bt, catches, body))))
              }
          }
        Ok(Some((t, bt))) =>
          match self.walk_array(t, ModuleTransformer::walk_catch, catches) {
            Err(e) => Err(e)
            Ok(None) =>
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) => Ok(Some((t, TryTable(bt, catches, body))))
                Ok(Some((t, body))) =>
                  Ok(Some((t, TryTable(bt, catches, body))))
              }
            Ok(Some((t, catches))) =>
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) => Ok(Some((t, TryTable(bt, catches, body))))
                Ok(Some((t, body))) =>
                  Ok(Some((t, TryTable(bt, catches, body))))
              }
          }
      }

    // Branch instructions
    Br(l) =>
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Br(l))))
      }
    BrIf(l) =>
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, BrIf(l))))
      }
    BrTable(labels, default) =>
      match self.walk_array(t, ModuleTransformer::walk_labelidx, labels) {
        Err(e) => Err(e)
        Ok(None) =>
          match self.walk_labelidx(t, default) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, default))) => Ok(Some((t, BrTable(labels, default))))
          }
        Ok(Some((t, labels))) =>
          match self.walk_labelidx(t, default) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, BrTable(labels, default))))
            Ok(Some((t, default))) => Ok(Some((t, BrTable(labels, default))))
          }
      }
    BrOnNull(l) =>
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, BrOnNull(l))))
      }
    BrOnNonNull(l) =>
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, BrOnNonNull(l))))
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
      Ok(Some((t, BrOnCast(l, op, ht1, ht2))))
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
      Ok(Some((t, BrOnCastFail(l, op, ht1, ht2))))
    }

    // Call instructions
    Call(f) =>
      match self.walk_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, Call(f))))
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
      Ok(Some((t, CallIndirect(ty, tbl))))
    }
    ReturnCall(f) =>
      match self.walk_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, ReturnCall(f))))
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
      Ok(Some((t, ReturnCallIndirect(ty, tbl))))
    }
    CallRef(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, CallRef(ty))))
      }
    ReturnCallRef(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ReturnCallRef(ty))))
      }

    // Variable instructions
    LocalGet(l) =>
      match self.walk_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, LocalGet(l))))
      }
    LocalSet(l) =>
      match self.walk_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, LocalSet(l))))
      }
    LocalTee(l) =>
      match self.walk_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, LocalTee(l))))
      }
    GlobalGet(g) =>
      match self.walk_globalidx(t, g) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, g))) => Ok(Some((t, GlobalGet(g))))
      }
    GlobalSet(g) =>
      match self.walk_globalidx(t, g) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, g))) => Ok(Some((t, GlobalSet(g))))
      }

    // Table instructions
    TableGet(tbl) =>
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, TableGet(tbl))))
      }
    TableSet(tbl) =>
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, TableSet(tbl))))
      }
    TableGrow(tbl) =>
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, TableGrow(tbl))))
      }
    TableSize(tbl) =>
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, TableSize(tbl))))
      }
    TableFill(tbl) =>
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, TableFill(tbl))))
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
      Ok(Some((t, TableCopy(t1, t2))))
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
      Ok(Some((t, TableInit(e, tbl))))
    }
    ElemDrop(e) =>
      match self.walk_elemidx(t, e) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, e))) => Ok(Some((t, ElemDrop(e))))
      }

    // Reference instructions
    RefNull(ht) =>
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, RefNull(ht))))
      }
    RefFunc(f) =>
      match self.walk_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, RefFunc(f))))
      }
    RefTest(nullable, ht) =>
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, RefTest(nullable, ht))))
      }
    RefCast(nullable, ht) =>
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, RefCast(nullable, ht))))
      }

    // Struct/Array instructions
    StructNew(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructNew(ty))))
      }
    StructNewDefault(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructNewDefault(ty))))
      }
    StructGet(ty, f) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructGet(ty, f))))
      }
    StructGetS(ty, f) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructGetS(ty, f))))
      }
    StructGetU(ty, f) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructGetU(ty, f))))
      }
    StructSet(ty, f) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructSet(ty, f))))
      }
    ArrayNew(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayNew(ty))))
      }
    ArrayNewDefault(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayNewDefault(ty))))
      }
    ArrayNewFixed(ty, n) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayNewFixed(ty, n))))
      }
    ArrayNewData(ty, n) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayNewData(ty, n))))
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
      Ok(Some((t, ArrayNewElem(ty, e))))
    }
    ArrayGet(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayGet(ty))))
      }
    ArrayGetS(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayGetS(ty))))
      }
    ArrayGetU(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayGetU(ty))))
      }
    ArraySet(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArraySet(ty))))
      }
    ArrayFill(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayFill(ty))))
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
      Ok(Some((t, ArrayCopy(t1, t2))))
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
      Ok(Some((t, ArrayInitData(ty, d))))
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
      Ok(Some((t, ArrayInitElem(ty, e))))
    }

    // Memory instructions
    MemorySize(m) =>
      match self.walk_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, MemorySize(m))))
      }
    MemoryGrow(m) =>
      match self.walk_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, MemoryGrow(m))))
      }
    MemoryFill(m) =>
      match self.walk_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, MemoryFill(m))))
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
      Ok(Some((t, MemoryCopy(m1, m2))))
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
      Ok(Some((t, MemoryInit(d, m))))
    }
    DataDrop(d) =>
      match self.walk_dataidx(t, d) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, d))) => Ok(Some((t, DataDrop(d))))
      }

    // Exception instructions
    Throw(ty) =>
      match self.walk_tagidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Throw(ty))))
      }

    // Select with types
    Select(types) =>
      match types {
        None => Ok(None)
        Some(types) =>
          match self.walk_array(t, ModuleTransformer::walk_valtype, types) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, types))) => Ok(Some((t, Select(Some(types)))))
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
        Ok(Some((t, vt))) => Ok(Some((t, ValTypeBlockType(vt))))
      }
    TypeIdxBlockType(ty) =>
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, TypeIdxBlockType(ty))))
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
      Ok(Some((t, Catch(tag, label))))
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
      Ok(Some((t, CatchRef(tag, label))))
    }
    CatchAll(label) =>
      match self.walk_labelidx(t, label) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, label))) => Ok(Some((t, CatchAll(label))))
      }
    CatchAllRef(label) =>
      match self.walk_labelidx(t, label) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, label))) => Ok(Some((t, CatchAllRef(label))))
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
        Ok(Some((t, rt))) => Ok(Some((t, RefTypeValType(rt))))
      }
    NumTypeValType(nt) =>
      match self.walk_numtype(t, nt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, nt))) => Ok(Some((t, NumTypeValType(nt))))
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
        Ok(Some((t, ht))) => Ok(Some((t, HeapTypeRefType(nullable, ht))))
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
        Ok(Some((t, ty))) => Ok(Some((t, HeapType(ty))))
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
    Ok(Some((t, n))) => Ok(Some((t, CustomSec(n, d))))
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
  let Module(
    custom,
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
    datacnt_sec,
    code_sec,
    data_sec
  ) = mod
  let (t, custom) = match self.walk_customsecs(t, custom) {
    Err(e) => return Err(e)
    Ok(None) => (t, custom)
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
  let (t, datacnt_sec) = match datacnt_sec {
    None => (t, None)
    Some(sec) =>
      match self.walk_datacntsec(t, sec) {
        Err(e) => return Err(e)
        Ok(None) => (t, Some(sec))
        Ok(Some((t, sec))) => (t, Some(sec))
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
        Module(
          custom, type_sec, import_sec, func_sec, table_sec, mem_sec, tag_sec, global_sec,
          export_sec, start_sec, elem_sec, datacnt_sec, code_sec, data_sec,
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
    Ok(Some((t, ds))) => Ok(Some((t, DataSec(ds))))
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
    Ok(Some((t, fs))) => Ok(Some((t, CodeSec(fs))))
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
    Ok(Some((t, es))) => Ok(Some((t, ElemSec(es))))
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
    Ok(Some((t, fidx))) => Ok(Some((t, StartSec(fidx))))
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
pub fn[T] ModuleTransformer::walk_exportsec_default(
  self : ModuleTransformer[T],
  t : T,
  es : ExportSec,
) -> TransformerResult[T, ExportSec] {
  let ExportSec(es) = es
  match self.walk_array(t, ModuleTransformer::walk_export, es) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, es))) => Ok(Some((t, ExportSec(es))))
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
    Ok(Some((t, tags))) => Ok(Some((t, TagSec(tags))))
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
    Ok(Some((t, m))) => Ok(Some((t, MemSec(m))))
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
    Ok(Some((t, tts))) => Ok(Some((t, TableSec(tts))))
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
        Ok(Some((t, body))) => Ok(Some((t, Func(locals, body))))
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
      Ok(Some((t, TFunc(locals, tbody))))
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
    Ok(Some((t, vt))) => Ok(Some((t, Locals(count, vt))))
  }
}

///|
pub fn[T] ModuleTransformer::walk_importsec(
  self : ModuleTransformer[T],
  t : T,
  ims : ImportSec,
) -> TransformerResult[T, ImportSec] {
  let ImportSec(ims) = ims
  match self.walk_array(t, ModuleTransformer::walk_import, ims) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, ims))) => Ok(Some((t, ImportSec(ims))))
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
  Ok(Some((t, Export(n, ei))))
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
        Ok(Some((t, fi))) => Ok(Some((t, FuncExternIdx(fi))))
      }
    TableExternIdx(ti) =>
      match self.walk_tableidx(t, ti) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ti))) => Ok(Some((t, TableExternIdx(ti))))
      }
    MemExternIdx(mi) =>
      match self.walk_memidx(t, mi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, mi))) => Ok(Some((t, MemExternIdx(mi))))
      }
    GlobalExternIdx(gi) =>
      match self.walk_globalidx(t, gi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, gi))) => Ok(Some((t, GlobalExternIdx(gi))))
      }
    TagExternIdx(ti) =>
      match self.walk_tagidx(t, ti) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ti))) => Ok(Some((t, TagExternIdx(ti))))
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
  Ok(Some((t, Table(tt, e_option))))
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
  Ok(Some((t, Import(n1, n2, ty))))
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
    Ok(Some((t, ti))) => Ok(Some((t, TagType(ti))))
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
    Ok(Some((t, l))) => Ok(Some((t, MemType(l))))
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
  Ok(Some((t, TableType(rt, l))))
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
    Ok(Some((t, rectypes))) => Ok(Some((t, TypeSec(rectypes))))
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
        Ok(Some((t, st))) => Ok(Some((t, SingleRecType(st))))
      }
    GroupRecType(sts) =>
      match self.walk_array(t, ModuleTransformer::walk_subtype, sts) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, sts))) => Ok(Some((t, GroupRecType(sts))))
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
      Ok(Some((t, SubType(f, supers, ct))))
    }
    CompTypeSubType(ct) =>
      match self.walk_comptype(t, ct) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ct))) => Ok(Some((t, CompTypeSubType(ct))))
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
      Ok(Some((t, FuncCompType(params, results))))
    }
    StructCompType(fields) =>
      match self.walk_array(t, ModuleTransformer::walk_fieldtype, fields) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, fields))) => Ok(Some((t, StructCompType(fields))))
      }
    ArrayCompType(ft) =>
      match self.walk_fieldtype(t, ft) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ft))) => Ok(Some((t, ArrayCompType(ft))))
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
    Ok(Some((t, st))) => Ok(Some((t, FieldType(st, mut_))))
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
        Ok(Some((t, vt))) => Ok(Some((t, ValTypeStorageType(vt))))
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
    Ok(Some((t, gs))) => Ok(Some((t, GlobalSec(gs))))
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
  Ok(Some((t, Global(gt, init))))
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
    Ok(Some((t, vt))) => Ok(Some((t, GlobalType(vt, mutable))))
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
  Ok(Some((t, Elem(mode, kind))))
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
      Ok(Some((t, Active(tidx, offset))))
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
        Ok(Some((t, idxs))) => Ok(Some((t, FuncsElemKind(idxs))))
      }
    FuncExprsElemKind(exprs) =>
      match self.walk_array(t, ModuleTransformer::walk_expr, exprs) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, exprs))) => Ok(Some((t, FuncExprsElemKind(exprs))))
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
      Ok(Some((t, TypedExprsElemKind(rt, exprs))))
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
  Ok(Some((t, Data(mode, bytes))))
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
      Ok(Some((t, Active(midx, offset))))
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
    Ok(Some((t, idxs))) => Ok(Some((t, FuncSec(idxs))))
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
