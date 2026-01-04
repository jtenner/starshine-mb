///|
/// Transformer callbacks - all optional. Return `None` to use default recursion.
pub struct ModuleTransformer[T] {
  on_typesec : ((T, TypeSec) -> (T, TypeSec)?)?
  on_funcsec : ((T, FuncSec) -> (T, FuncSec)?)?
  on_tablesec : ((T, TableSec) -> (T, TableSec)?)?
  on_memsec : ((T, MemSec) -> (T, MemSec)?)?
  on_tagsec : ((T, TagSec) -> (T, TagSec)?)?
  on_globalsec : ((T, GlobalSec) -> (T, GlobalSec)?)?
  on_exportsec : ((T, ExportSec) -> (T, ExportSec)?)?
  on_startsec : ((T, StartSec) -> (T, StartSec)?)?
  on_elemsec : ((T, ElemSec) -> (T, ElemSec)?)?
  on_elemkind : ((T, ElemKind) -> (T, ElemKind)?)?
  on_datacntsec : ((T, DataCntSec) -> (T, DataCntSec)?)?
  on_codesec : ((T, CodeSec) -> (T, CodeSec)?)?
  on_datasec : ((T, DataSec) -> (T, DataSec)?)?
  on_instruction : ((T, Instruction) -> (T, Instruction)?)?
  on_expr : ((T, Expr) -> (T, Expr)?)?
  on_valtype : ((T, ValType) -> (T, ValType)?)?
  on_reftype : ((T, RefType) -> (T, RefType)?)?
  on_heaptype : ((T, HeapType) -> (T, HeapType)?)?
  on_blocktype : ((T, BlockType) -> (T, BlockType)?)?
  on_funcidx : ((T, FuncIdx) -> (T, FuncIdx)?)?
  on_typeidx : ((T, TypeIdx) -> (T, TypeIdx)?)?
  on_localidx : ((T, LocalIdx) -> (T, LocalIdx)?)?
  on_globalidx : ((T, GlobalIdx) -> (T, GlobalIdx)?)?
  on_tableidx : ((T, TableIdx) -> (T, TableIdx)?)?
  on_memidx : ((T, MemIdx) -> (T, MemIdx)?)?
  on_labelidx : ((T, LabelIdx) -> (T, LabelIdx)?)?
  on_dataidx : ((T, DataIdx) -> (T, DataIdx)?)?
  on_elemidx : ((T, ElemIdx) -> (T, ElemIdx)?)?
  on_tagidx : ((T, TagIdx) -> (T, TagIdx)?)?
  on_name : ((T, Name) -> (T, Name)?)?
  on_externtype : ((T, ExternType) -> (T, ExternType)?)?
  on_limits : ((T, Limits) -> (T, Limits)?)?
  on_memtype : ((T, MemType) -> (T, MemType)?)?
  on_tagtype : ((T, TagType) -> (T, TagType)?)?
  on_export : ((T, Export) -> (T, Export)?)?
  on_global : ((T, Global) -> (T, Global)?)?
  on_globaltype : ((T, GlobalType) -> (T, GlobalType)?)?
  on_func : ((T, Func) -> (T, Func)?)?
  on_locals : ((T, Array[Locals]) -> T?)?
  on_externidx : ((T, ExternIdx) -> (T, ExternIdx)?)?
  on_fieldtype : ((T, FieldType) -> (T, FieldType)?)?
  on_storagetype : ((T, StorageType) -> (T, StorageType)?)?
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
    on_expr: None,
    on_valtype: None,
    on_reftype: None,
    on_heaptype: None,
    on_blocktype: None,
    on_funcidx: None,
    on_typeidx: None,
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
  }
}

pub fn [T, E] ModuleTransformer::walk_array(
  self : ModuleTransformer[T],
  t : T,
  e : (ModuleTransformer[T], T, E) -> (T, E),
  a : Array[E]
) -> (T, Array[E]) {
  let a = a.copy()
  let mut t = t
  let end = a.length()
  loop 0 {
    n if n == end => break (t, a)
    n => {
      let item = a[n]
      let (next_t, item) = e(self, t, item)
      t = next_t
      a[n] = item
      continue n + 1
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_name(
  self : ModuleTransformer[T],
  t : T,
  name : Name,
) -> (T, Name) {
  match self.on_name {
    Some(f) => f(t, name).unwrap_or((t, name))
    None => (t, name)
  }
}

///|
pub fn[T] ModuleTransformer::walk_expr(
  self : ModuleTransformer[T],
  t : T,
  expr : Expr,
) -> (T, Expr) {
  // Check if user wants to override
  match self.on_expr {
    Some(f) =>
      match f(t, expr) {
        Some(e) => e
        None => self.walk_expr_default(t, expr)
      }
    None => self.walk_expr_default(t, expr)
  }
}

///|
pub fn[T] ModuleTransformer::walk_expr_default(
  self : ModuleTransformer[T],
  t : T,
  expr : Expr,
) -> (T, Expr) {
  let Expr(instructions) = expr
  let (t, instructions) = self.walk_array(t, ModuleTransformer::walk_instruction, instructions)
  (t, Expr(instructions))
}

///|
pub fn[T] ModuleTransformer::walk_instruction(
  self : ModuleTransformer[T],
  t : T,
  instr : Instruction,
) -> (T, Instruction) {
  match self.on_instruction {
    Some(f) =>
      match f(t, instr) {
        Some(i) => i
        None => self.walk_instruction_default(t, instr)
      }
    None => self.walk_instruction_default(t, instr)
  }
}

///|
pub fn[T] ModuleTransformer::walk_instruction_default(
  self : ModuleTransformer[T],
  t : T,
  instr : Instruction,
) -> (T, Instruction) {
  match instr {
    // Control instructions with nested structure
    Block(bt, body) => {
      let (t, bt) = self.walk_blocktype(t, bt)
      let (t, body) = self.walk_expr(t, body)
      (t, Block(bt, body))
    }
    Loop(bt, body) => {
      let (t, bt) = self.walk_blocktype(t, bt)
      let (t, body) = self.walk_expr(t, body)
      (t, Loop(bt, body))
    }
    If(bt, then_body, else_body) => {
      let (t, bt) = self.walk_blocktype(t, bt)
      let (t, then_body) = self.walk_array(t, ModuleTransformer::walk_instruction, then_body)
      if else_body is Some(else_body) {
        let (t, else_body) = self.walk_array(t, ModuleTransformer::walk_instruction, else_body)
        (t, If(bt, then_body, Some(else_body)))
      } else {
        (t, If(bt, then_body, None))
      }
    }
    TryTable(bt, catches, body) => {
      let (t, bt) = self.walk_blocktype(t, bt)
      let (t, catches) = self.walk_array(t, ModuleTransformer::walk_catch, catches)
      let (t, body) = self.walk_expr(t, body)
      (t, TryTable(bt, catches, body))
    }

    // Branch instructions
    Br(l) => {
      let (t, l) = self.walk_labelidx(t, l)
      (t, Br(l))
    }
    BrIf(l) => {
      let (t, l) = self.walk_labelidx(t, l)
      (t, BrIf(l))
    }
    BrTable(labels, default) => {
      let (t, labels) = self.walk_array(t, ModuleTransformer::walk_labelidx, labels)
      let (t, default) = self.walk_labelidx(t, default)
      (t, BrTable(labels, default))
    }
    BrOnNull(l) => {
      let (t, l) = self.walk_labelidx(t, l)
      (t, BrOnNull(l))
    }
    BrOnNonNull(l) => {
      let (t, l) = self.walk_labelidx(t, l)
      (t, BrOnNonNull(l))
    }
    BrOnCast(l, op, ht1, ht2) => {
      let (t, l) = self.walk_labelidx(t, l)
      let (t, ht1) = self.walk_heaptype(t, ht1)
      let (t, ht2) = self.walk_heaptype(t, ht2)
      (t, BrOnCast(l, op, ht1, ht2))
    }
    BrOnCastFail(l, op, ht1, ht2) => {
      let (t, l) = self.walk_labelidx(t, l)
      let (t, ht1) = self.walk_heaptype(t, ht1)
      let (t, ht2) = self.walk_heaptype(t, ht2)
      (t, BrOnCastFail(l, op, ht1, ht2))
    }

    // Call instructions
    Call(f) => {
      let (t, f) = self.walk_funcidx(t, f)
      (t, Call(f))
    }
    CallIndirect(ty, tbl) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      let (t, tbl) = self.walk_tableidx(t, tbl)
      (t, CallIndirect(ty, tbl))
    }
    ReturnCall(f) => {
      let (t, f) = self.walk_funcidx(t, f)
      (t, ReturnCall(f))
    }
    ReturnCallIndirect(ty, tbl) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      let (t, tbl) = self.walk_tableidx(t, tbl)
      (t, ReturnCallIndirect(ty, tbl))
    }
    CallRef(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, CallRef(ty))
    }
    ReturnCallRef(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, ReturnCallRef(ty))
    }

    // Variable instructions
    LocalGet(l) => {
      let (t, l) = self.walk_localidx(t, l)
      (t, LocalGet(l))
    }
    LocalSet(l) => {
      let (t, l) = self.walk_localidx(t, l)
      (t, LocalSet(l))
    }
    LocalTee(l) => {
      let (t, l) = self.walk_localidx(t, l)
      (t, LocalTee(l))
    }
    GlobalGet(g) => {
      let (t, g) = self.walk_globalidx(t, g)
      (t, GlobalGet(g))
    }
    GlobalSet(g) => {
      let (t, g) = self.walk_globalidx(t, g)
      (t, GlobalSet(g))
    }

    // Table instructions
    TableGet(tbl) => {
      let (t, tbl) = self.walk_tableidx(t, tbl)
      (t, TableGet(tbl))
    }
    TableSet(tbl) => {
      let (t, tbl) = self.walk_tableidx(t, tbl)
      (t, TableSet(tbl))
    }
    TableGrow(tbl) => {
      let (t, tbl) = self.walk_tableidx(t, tbl)
      (t, TableGrow(tbl))
    }
    TableSize(tbl) => {
      let (t, tbl) = self.walk_tableidx(t, tbl)
      (t, TableSize(tbl))
    }
    TableFill(tbl) => {
      let (t, tbl) = self.walk_tableidx(t, tbl)
      (t, TableFill(tbl))
    }
    TableCopy(t1, t2) => {
      let (t, t1) = self.walk_tableidx(t, t1)
      let (t, t2) = self.walk_tableidx(t, t2)
      (t, TableCopy(t1, t2))
    }
    TableInit(e, tbl) => {
      let (t, e) = self.walk_elemidx(t, e)
      let (t, tbl) = self.walk_tableidx(t, tbl)
      (t, TableInit(e, tbl))
    }
    ElemDrop(e) => {
      let (t, e) = self.walk_elemidx(t, e)
      (t, ElemDrop(e))
    }

    // Reference instructions
    RefNull(ht) => {
      let (t, ht) = self.walk_heaptype(t, ht)
      (t, RefNull(ht))
    }
    RefFunc(f) => {
      let (t, f) = self.walk_funcidx(t, f)
      (t, RefFunc(f))
    }
    RefTest(nullable, ht) => {
      let (t, ht) = self.walk_heaptype(t, ht)
      (t, RefTest(nullable, ht))
    }
    RefCast(nullable, ht) => {
      let (t, ht) = self.walk_heaptype(t, ht)
      (t, RefCast(nullable, ht))
    }

    // Struct/Array instructions
    StructNew(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, StructNew(ty))
    }
    StructNewDefault(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, StructNewDefault(ty))
    }
    StructGet(ty, f) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, StructGet(ty, f))
    }
    StructGetS(ty, f) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, StructGetS(ty, f))
    }
    StructGetU(ty, f) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, StructGetU(ty, f))
    }
    StructSet(ty, f) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, StructSet(ty, f))
    }
    ArrayNew(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, ArrayNew(ty))
    }
    ArrayNewDefault(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, ArrayNewDefault(ty))
    }
    ArrayNewFixed(ty, n) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, ArrayNewFixed(ty, n))
    }
    ArrayNewData(ty, n) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, ArrayNewData(ty, n))
    }
    ArrayNewElem(ty, e) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      let (t, e) = self.walk_elemidx(t, e)
      (t, ArrayNewElem(ty, e))
    }
    ArrayGet(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, ArrayGet(ty))
    }
    ArrayGetS(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, ArrayGetS(ty))
    }
    ArrayGetU(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, ArrayGetU(ty))
    }
    ArraySet(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, ArraySet(ty))
    }
    ArrayFill(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, ArrayFill(ty))
    }
    ArrayCopy(t1, t2) => {
      let (t, t1) = self.walk_typeidx(t, t1)
      let (t, t2) = self.walk_typeidx(t, t2)
      (t, ArrayCopy(t1, t2))
    }
    ArrayInitData(ty, d) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      let (t, d) = self.walk_dataidx(t, d)
      (t, ArrayInitData(ty, d))
    }
    ArrayInitElem(ty, e) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      let (t, e) = self.walk_elemidx(t, e)
      (t, ArrayInitElem(ty, e))
    }

    // Memory instructions
    MemorySize(m) => {
      let (t, m) = self.walk_memidx(t, m)
      (t, MemorySize(m))
    }
    MemoryGrow(m) => {
      let (t, m) = self.walk_memidx(t, m)
      (t, MemoryGrow(m))
    }
    MemoryFill(m) => {
      let (t, m) = self.walk_memidx(t, m)
      (t, MemoryFill(m))
    }
    MemoryCopy(m1, m2) => {
      let (t, m1) = self.walk_memidx(t, m1)
      let (t, m2) = self.walk_memidx(t, m2)
      (t, MemoryCopy(m1, m2))
    }
    MemoryInit(d, m) => {
      let (t, d) = self.walk_dataidx(t, d)
      let (t, m) = self.walk_memidx(t, m)
      (t, MemoryInit(d, m))
    }
    DataDrop(d) => {
      let (t, d) = self.walk_dataidx(t, d)
      (t, DataDrop(d))
    }

    // Exception instructions
    Throw(ty) => {
      let (t, ty) = self.walk_tagidx(t, ty)
      (t, Throw(ty))
    }

    // Select with types
    Select(types) =>
      match types {
        Some(types) => {
          let (t, types) = self.walk_array(t, ModuleTransformer::walk_valtype, types)
          (t, Select(Some(types)))
        }
        None => (t, Select(None))
      }

    // All other instructions pass through unchanged
    other => (t, other)
  }
}

///|
pub fn[T] ModuleTransformer::walk_blocktype(
  self : ModuleTransformer[T],
  t : T,
  bt : BlockType,
) -> (T, BlockType) {
  match self.on_blocktype {
    Some(f) =>
      match f(t, bt) {
        Some(b) => b
        None => self.walk_blocktype_default(t, bt)
      }
    None => self.walk_blocktype_default(t, bt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_blocktype_default(
  self : ModuleTransformer[T],
  t : T,
  bt : BlockType,
) -> (T, BlockType) {
  match bt {
    ValTypeBlockType(vt) => {
      let (t, vt) = self.walk_valtype(t, vt)
      (t, ValTypeBlockType(vt))
    }
    TypeIdxBlockType(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, TypeIdxBlockType(ty))
    }
    _ => (t, bt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_catch(
  self : ModuleTransformer[T],
  t : T,
  c : Catch,
) -> (T, Catch) {
  match c {
    Catch(tag, label) => {
      let (t, tag) = self.walk_tagidx(t, tag)
      let (t, label) = self.walk_labelidx(t, label)
      (t, Catch(tag, label))
    }
    CatchRef(tag, label) => {
      let (t, tag) = self.walk_tagidx(t, tag)
      let (t, label) = self.walk_labelidx(t, label)
      (t, CatchRef(tag, label))
    }
    CatchAll(label) => {
      let (t, label) = self.walk_labelidx(t, label)
      (t, CatchAll(label))
    }
    CatchAllRef(label) => {
      let (t, label) = self.walk_labelidx(t, label)
      (t, CatchAllRef(label))
    }
  }
}

// Index walkers - leaf nodes

///|
pub fn[T] ModuleTransformer::walk_funcidx(
  self : ModuleTransformer[T],
  t : T,
  idx : FuncIdx,
) -> (T, FuncIdx) {
  match self.on_funcidx {
    Some(f) => f(t, idx).unwrap_or((t, idx))
    None => (t, idx)
  }
}

///|
pub fn[T] ModuleTransformer::walk_typeidx(
  self : ModuleTransformer[T],
  t : T,
  idx : TypeIdx,
) -> (T, TypeIdx) {
  match self.on_typeidx {
    Some(f) => f(t, idx).unwrap_or((t, idx))
    None => (t, idx)
  }
}

///|
pub fn[T] ModuleTransformer::walk_localidx(
  self : ModuleTransformer[T],
  t : T,
  idx : LocalIdx,
) -> (T, LocalIdx) {
  match self.on_localidx {
    Some(f) => f(t, idx).unwrap_or((t, idx))
    None => (t, idx)
  }
}

///|
pub fn[T] ModuleTransformer::walk_globalidx(
  self : ModuleTransformer[T],
  t : T,
  idx : GlobalIdx,
) -> (T, GlobalIdx) {
  match self.on_globalidx {
    Some(f) => f(t, idx).unwrap_or((t, idx))
    None => (t, idx)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tableidx(
  self : ModuleTransformer[T],
  t : T,
  idx : TableIdx,
) -> (T, TableIdx) {
  match self.on_tableidx {
    Some(f) => f(t, idx).unwrap_or((t, idx))
    None => (t, idx)
  }
}

///|
pub fn[T] ModuleTransformer::walk_memidx(
  self : ModuleTransformer[T],
  t : T,
  idx : MemIdx,
) -> (T, MemIdx) {
  match self.on_memidx {
    Some(f) => f(t, idx).unwrap_or((t, idx))
    None => (t, idx)
  }
}

///|
pub fn[T] ModuleTransformer::walk_labelidx(
  self : ModuleTransformer[T],
  t : T,
  idx : LabelIdx,
) -> (T, LabelIdx) {
  match self.on_labelidx {
    Some(f) => f(t, idx).unwrap_or((t, idx))
    None => (t, idx)
  }
}

///|
pub fn[T] ModuleTransformer::walk_dataidx(
  self : ModuleTransformer[T],
  t : T,
  idx : DataIdx,
) -> (T, DataIdx) {
  match self.on_dataidx {
    Some(f) => f(t, idx).unwrap_or((t, idx))
    None => (t, idx)
  }
}

///|
pub fn[T] ModuleTransformer::walk_elemidx(
  self : ModuleTransformer[T],
  t : T,
  idx : ElemIdx,
) -> (T, ElemIdx) {
  match self.on_elemidx {
    Some(f) => f(t, idx).unwrap_or((t, idx))
    None => (t, idx)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tagidx(
  self : ModuleTransformer[T],
  t : T,
  idx : TagIdx,
) -> (T, TagIdx) {
  match self.on_tagidx {
    Some(f) => f(t, idx).unwrap_or((t, idx))
    None => (t, idx)
  }
}

///|
pub fn[T] ModuleTransformer::walk_valtype(
  self : ModuleTransformer[T],
  t : T,
  vt : ValType,
) -> (T, ValType) {
  match self.on_valtype {
    Some(f) =>
      match f(t, vt) {
        Some(v) => v
        None => self.walk_valtype_default(t, vt)
      }
    None => self.walk_valtype_default(t, vt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_valtype_default(
  self : ModuleTransformer[T],
  t : T,
  vt : ValType,
) -> (T, ValType) {
  match vt {
    RefTypeValType(rt) => {
      let (t, rt) = self.walk_reftype(t, rt)
      (t, RefTypeValType(rt))
    }
    other => (t, other)
  }
}

///|
pub fn[T] ModuleTransformer::walk_reftype(
  self : ModuleTransformer[T],
  t : T,
  rt : RefType,
) -> (T, RefType) {
  match self.on_reftype {
    Some(f) =>
      match f(t, rt) {
        Some(r) => r
        None => self.walk_reftype_default(t, rt)
      }
    None => self.walk_reftype_default(t, rt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_reftype_default(
  self : ModuleTransformer[T],
  t : T,
  rt : RefType,
) -> (T, RefType) {
  match rt {
    HeapTypeRefType(nullable, ht) => {
      let (t, ht) = self.walk_heaptype(t, ht)
      (t, HeapTypeRefType(nullable, ht))
    }
    _ => (t, rt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_heaptype(
  self : ModuleTransformer[T],
  t : T,
  ht : HeapType,
) -> (T, HeapType) {
  match self.on_heaptype {
    Some(f) =>
      match f(t, ht) {
        Some(h) => h
        None => self.walk_heaptype_default(t, ht)
      }
    None => self.walk_heaptype_default(t, ht)
  }
}

///|
pub fn[T] ModuleTransformer::walk_heaptype_default(
  self : ModuleTransformer[T],
  t : T,
  ht : HeapType,
) -> (T, HeapType) {
  match ht {
    HeapType(ty) => {
      let (t, ty) = self.walk_typeidx(t, ty)
      (t, HeapType(ty))
    }
    other => (t, other)
  }
}

///|
pub fn[T] ModuleTransformer::walk_customsec(
  self : ModuleTransformer[T],
  t : T,
  sec : CustomSec,
) -> (T, CustomSec) {
  let CustomSec(n, d) = sec
  let (t, n) = self.walk_name(t, n)
  (t, CustomSec(n, d))
}

///|
pub fn[T] ModuleTransformer::walk_customsecs(
  self : ModuleTransformer[T],
  t : T,
  secs : Array[CustomSec],
) -> T {
  let end = secs.length()
  let mut t = t
  loop 0 {
    n if n == end => break t
    n => {
      let sec = secs[n]
      let (next_t, sec) = self.walk_customsec(t, sec)
      secs[n] = sec
      t = next_t
      continue n + 1
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_module(
  self : ModuleTransformer[T],
  t : T,
  mod : Module,
) -> (T, Module) {
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
  let t = self.walk_customsecs(t, custom)
  let (t, type_sec) = match type_sec {
    Some(type_sec) => {
      let (t, type_sec) = self.walk_typesec(t, type_sec)
      (t, Some(type_sec))
    }
    _ => (t, type_sec)
  }
  let (t, import_sec) = match import_sec {
    Some(import_sec) => {
      let (t, import_sec) = self.walk_importsec(t, import_sec)
      (t, Some(import_sec))
    }
    _ => (t, import_sec)
  }
  let (t, func_sec) = match func_sec {
    Some(func_sec) => {
      let (t, func_sec) = self.walk_funcsec(t, func_sec)
      (t, Some(func_sec))
    }
    _ => (t, func_sec)
  }
  let (t, table_sec) = match table_sec {
    Some(table_sec) => {
      let (t, table_sec) = self.walk_tablesec(t, table_sec)
      (t, Some(table_sec))
    }
    _ => (t, table_sec)
  }
  let (t, mem_sec) = match mem_sec {
    Some(mem_sec) => {
      let (t, mem_sec) = self.walk_memsec(t, mem_sec)
      (t, Some(mem_sec))
    }
    _ => (t, mem_sec)
  }
  let (t, tag_sec) = match tag_sec {
    Some(tag_sec) => {
      let (t, tag_sec) = self.walk_tagsec(t, tag_sec)
      (t, Some(tag_sec))
    }
    _ => (t, tag_sec)
  }
  let (t, global_sec) = match global_sec {
    Some(global_sec) => {
      let (t, global_sec) = self.walk_globalsec(t, global_sec)
      (t, Some(global_sec))
    }
    _ => (t, global_sec)
  }
  let (t, export_sec) = match export_sec {
    Some(export_sec) => {
      let (t, export_sec) = self.walk_exportsec(t, export_sec)
      (t, Some(export_sec))
    }
    _ => (t, export_sec)
  }
  let (t, start_sec) = match start_sec {
    Some(start_sec) => {
      let (t, start_sec) = self.walk_startsec(t, start_sec)
      (t, Some(start_sec))
    }
    _ => (t, start_sec)
  }
  let (t, elem_sec) = match elem_sec {
    Some(elem_sec) => {
      let (t, elem_sec) = self.walk_elemsec(t, elem_sec)
      (t, Some(elem_sec))
    }
    _ => (t, elem_sec)
  }
  let (t, datacnt_sec) = match datacnt_sec {
    Some(datacnt_sec) => {
      let (t, datacnt_sec) = self.walk_datacntsec(t, datacnt_sec)
      (t, Some(datacnt_sec))
    }
    _ => (t, datacnt_sec)
  }
  let (t, code_sec) = match code_sec {
    Some(code_sec) => {
      let (t, code_sec) = self.walk_codesec(t, code_sec)
      (t, Some(code_sec))
    }
    _ => (t, code_sec)
  }
  let (t, data_sec) = match data_sec {
    Some(data_sec) => {
      let (t, data_sec) = self.walk_datasec(t, data_sec)
      (t, Some(data_sec))
    }
    _ => (t, data_sec)
  }
  (
    t,
    Module(
      custom, type_sec, import_sec, func_sec, table_sec, mem_sec, tag_sec, global_sec,
      export_sec, start_sec, elem_sec, datacnt_sec, code_sec, data_sec,
    ),
  )
}

///|
pub fn[T] ModuleTransformer::walk_datasec(
  self : ModuleTransformer[T],
  t : T,
  ds : DataSec,
) -> (T, DataSec) {
  match self.on_datasec {
    Some(f) => f(t, ds).unwrap_or((t, ds))
    None => self.walk_datasec_default(t, ds)
  }
}

///|
pub fn[T] ModuleTransformer::walk_datasec_default(
  self : ModuleTransformer[T],
  t : T,
  ds : DataSec,
) -> (T, DataSec) {
  let DataSec(ds) = ds
  let (t, ds) = self.walk_array(t, ModuleTransformer::walk_data, ds)
  (t, DataSec(ds))
}

///|
pub fn[T] ModuleTransformer::walk_codesec(
  self : ModuleTransformer[T],
  t : T,
  cs : CodeSec,
) -> (T, CodeSec) {
  match self.on_codesec {
    Some(f) => f(t, cs).unwrap_or((t, cs))
    None => self.walk_codesec_default(t, cs)
  }
}

///|
pub fn[T] ModuleTransformer::walk_codesec_default(
  self : ModuleTransformer[T],
  t : T,
  cs : CodeSec,
) -> (T, CodeSec) {
  let CodeSec(fs) = cs
  let (t, fs) = self.walk_array(t, ModuleTransformer::walk_func, fs)
  (t, CodeSec(fs))
}


///|
pub fn[T] ModuleTransformer::walk_datacntsec(
  self : ModuleTransformer[T],
  t : T,
  dcs : DataCntSec,
) -> (T, DataCntSec) {
  match self.on_datacntsec {
    Some(f) => f(t, dcs).unwrap_or((t, dcs))
    None => (t, dcs)
  }
}

///|
pub fn[T] ModuleTransformer::walk_elemsec(
  self : ModuleTransformer[T],
  t : T,
  es : ElemSec,
) -> (T, ElemSec) {
  match self.on_elemsec {
    Some(f) => f(t, es).unwrap_or((t, es))
    None => self.walk_elemsec_default(t, es)
  }
}

///|
pub fn[T] ModuleTransformer::walk_elemsec_default(
  self : ModuleTransformer[T],
  t : T,
  es : ElemSec,
) -> (T, ElemSec) {
  let ElemSec(es) = es
  let (t, es) = self.walk_array(t, ModuleTransformer::walk_elem, es)
  (t, ElemSec(es))
}

///|
pub fn[T] ModuleTransformer::walk_startsec(
  self : ModuleTransformer[T],
  t : T,
  ss : StartSec,
) -> (T, StartSec) {
  match self.on_startsec {
    Some(f) => f(t, ss).unwrap_or((t, ss))
    None => self.walk_startsec_default(t, ss)
  }
}

///|
pub fn[T] ModuleTransformer::walk_startsec_default(
  self : ModuleTransformer[T],
  t : T,
  ss : StartSec,
) -> (T, StartSec) {
  let StartSec(fidx) = ss
  let (t, fidx) = self.walk_funcidx(t, fidx)
  (t, StartSec(fidx))
}

///|
pub fn[T] ModuleTransformer::walk_exportsec(
  self : ModuleTransformer[T],
  t : T,
  es : ExportSec,
) -> (T, ExportSec) {
  match self.on_exportsec {
    Some(f) => f(t, es).unwrap_or((t, es))
    None => self.walk_exportsec_default(t, es)
  }
}

///|
pub fn[T] ModuleTransformer::walk_exportsec_default(
  self : ModuleTransformer[T],
  t : T,
  es : ExportSec,
) -> (T, ExportSec) {
  let ExportSec(es) = es
  let (t, es) = self.walk_array(t, ModuleTransformer::walk_export, es)
  (t, ExportSec(es))
}

///|
pub fn[T] ModuleTransformer::walk_tagsec(
  self : ModuleTransformer[T],
  t : T,
  ts : TagSec,
) -> (T, TagSec) {
  match self.on_tagsec {
    Some(f) => f(t, ts).unwrap_or((t, ts))
    None => self.walk_tagsec_default(t, ts)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tagsec_default(
  self : ModuleTransformer[T],
  t : T,
  ts : TagSec,
) -> (T, TagSec) {
  let TagSec(tags) = ts
  let (t, tags) = self.walk_array(t, ModuleTransformer::walk_tagtype, tags)
  (t, TagSec(tags))
}

///|
pub fn[T] ModuleTransformer::walk_memsec(
  self : ModuleTransformer[T],
  t : T,
  ms : MemSec,
) -> (T, MemSec) {
  match self.on_memsec {
    Some(f) => f(t, ms).unwrap_or((t, ms))
    None => self.walk_memsec_default(t, ms)
  }
}

///|
pub fn[T] ModuleTransformer::walk_memsec_default(
  self : ModuleTransformer[T],
  t : T,
  ms : MemSec,
) -> (T, MemSec) {
  let MemSec(m) = ms
  let (t, m) = self.walk_array(t, ModuleTransformer::walk_memtype, m)
  (t, MemSec(m))
}

///|
pub fn[T] ModuleTransformer::walk_tablesec(
  self : ModuleTransformer[T],
  t : T,
  ts : TableSec,
) -> (T, TableSec) {
  match self.on_tablesec {
    Some(f) => f(t, ts).unwrap_or((t, ts))
    None => self.walk_tablesec_default(t, ts)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tablesec_default(
  self : ModuleTransformer[T],
  t : T,
  ts : TableSec,
) -> (T, TableSec) {
  let TableSec(tts) = ts
  let (t, tts) = self.walk_array(t, ModuleTransformer::walk_table, tts)
  (t, TableSec(tts))
}

///|
pub fn[T] ModuleTransformer::walk_func(
  self : ModuleTransformer[T],
  t : T,
  func : Func,
) -> (T, Func) {
  match self.on_func {
    Some(f) => f(t, func).unwrap_or((t, func))
    None => self.walk_func_default(t, func)
  }
}

///|
pub fn[T] ModuleTransformer::walk_func_default(
  self : ModuleTransformer[T],
  t : T,
  f : Func,
) -> (T, Func) {
  let Func(locals, body) = f
  let t = self.walk_locals(t, locals)
  let (t, body) = self.walk_expr(t, body)
  (t, Func(locals, body))
}

///|
pub fn[T] ModuleTransformer::walk_locals(
  self : ModuleTransformer[T],
  t : T,
  l : Array[Locals],
) -> T {
  match self.on_locals {
    Some(f) => f(t, l).unwrap_or(t)
    None => self.walk_locals_default(t, l)
  }
}

///|
pub fn[T] ModuleTransformer::walk_locals_default(
  self : ModuleTransformer[T],
  t : T,
  ls : Array[Locals],
) -> T {
  let end = ls.length()
  let mut t = t
  loop 0 {
    n if n == end => break t
    n => {
      let Locals(count, vt) = ls[n]
      let (next_t, vt) = self.walk_valtype(t, vt)
      ls[n] = Locals(count, vt)
      t = next_t
      continue n + 1
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_importsec(
  self : ModuleTransformer[T],
  t : T,
  ims : ImportSec,
) -> (T, ImportSec) {
  let ImportSec(ims) = ims
  let (t, ims) = self.walk_array(t, ModuleTransformer::walk_import, ims)
  (t, ImportSec(ims))
}

///|
pub fn[T] ModuleTransformer::walk_export(
  self : ModuleTransformer[T],
  t : T,
  expt : Export,
) -> (T, Export) {
  match self.on_export {
    Some(f) => f(t, expt).unwrap_or((t, expt))
    None => self.walk_export_default(t, expt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_export_default(
  self : ModuleTransformer[T],
  t : T,
  ex : Export,
) -> (T, Export) {
  let Export(n, ei) = ex
  let (t, n) = self.walk_name(t, n)
  let (t, ei) = self.walk_externidx(t, ei)
  (t, Export(n, ei))
}

///|
pub fn[T] ModuleTransformer::walk_externidx(
  self : ModuleTransformer[T],
  t : T,
  ex : ExternIdx,
) -> (T, ExternIdx) {
  match self.on_externidx {
    Some(f) => f(t, ex).unwrap_or((t, ex))
    None => self.walk_externidx(t, ex)
  }
}

///|
pub fn[T] ModuleTransformer::walk_externidx_default(
  self : ModuleTransformer[T],
  t : T,
  ex : ExternIdx,
) -> (T, ExternIdx) {
  match ex {
    FuncExternIdx(fi) => {
      let (t, fi) = self.walk_funcidx(t, fi)
      (t, FuncExternIdx(fi))
    }
    TableExternIdx(ti) => {
      let (t, ti) = self.walk_tableidx(t, ti)
      (t, TableExternIdx(ti))
    }
    MemExternIdx(mi) => {
      let (t, mi) = self.walk_memidx(t, mi)
      (t, MemExternIdx(mi))
    }
    GlobalExternIdx(gi) => {
      let (t, gi) = self.walk_globalidx(t, gi)
      (t, GlobalExternIdx(gi))
    }
    TagExternIdx(ti) => {
      let (t, ti) = self.walk_tagidx(t, ti)
      (t, TagExternIdx(ti))
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_table(
  self : ModuleTransformer[T],
  t : T,
  tbl : Table,
) -> (T, Table) {
  let Table(tt, e_option) = tbl
  let (t, tt) = self.walk_tabletype(t, tt)
  let (t, e_option) = match e_option {
    Some(e) => {
      let (t, e) = self.walk_expr(t, e)
      (t, Some(e))
    }
    None => (t, None)
  }
  (t, Table(tt, e_option))
}

///|
pub fn[T] ModuleTransformer::walk_import(
  self : ModuleTransformer[T],
  t : T,
  im : Import,
) -> (T, Import) {
  let Import(n1, n2, ty) = im
  let (t, n1) = self.walk_name(t, n1)
  let (t, n2) = self.walk_name(t, n2)
  let (t, ty) = self.walk_externtype(t, ty)
  (t, Import(n1, n2, ty))
}

///|
pub fn[T] ModuleTransformer::walk_externtype(
  self : ModuleTransformer[T],
  t : T,
  ex : ExternType,
) -> (T, ExternType) {
  match ex {
    FuncExternType(ti) => {
      let (t, ti) = self.walk_typeidx(t, ti)
      (t, FuncExternType(ti))
    }
    TableExternType(tt) => {
      let (t, tt) = self.walk_tabletype(t, tt)
      (t, TableExternType(tt))
    }
    MemExternType(mt) => {
      let (t, mt) = self.walk_memtype(t, mt)
      (t, MemExternType(mt))
    }
    GlobalExternType(gt) => {
      let (t, gt) = self.walk_globaltype(t, gt)
      (t, GlobalExternType(gt))
    }
    TagExternType(tt) => {
      let (t, tt) = self.walk_tagtype(t, tt)
      (t, TagExternType(tt))
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_tagtype(
  self : ModuleTransformer[T],
  t : T,
  tt : TagType,
) -> (T, TagType) {
  match self.on_tagtype {
    Some(f) => f(t, tt).unwrap_or((t, tt))
    None => self.walk_tagtype_default(t, tt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_tagtype_default(
  self : ModuleTransformer[T],
  t : T,
  tt : TagType,
) -> (T, TagType) {
  let TagType(ti) = tt
  let (t, ti) = self.walk_typeidx(t, ti)
  (t, TagType(ti))
}

///|
pub fn[T] ModuleTransformer::walk_memtype(
  self : ModuleTransformer[T],
  t : T,
  mt : MemType,
) -> (T, MemType) {
  match self.on_memtype {
    Some(f) => f(t, mt).unwrap_or((t, mt))
    None => self.walk_memtype_default(t, mt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_memtype_default(
  self : ModuleTransformer[T],
  t : T,
  mt : MemType,
) -> (T, MemType) {
  let MemType(l) = mt
  let (t, l) = self.walk_limits(t, l)
  (t, MemType(l))
}

///|
pub fn[T] ModuleTransformer::walk_tabletype(
  self : ModuleTransformer[T],
  t : T,
  tt : TableType,
) -> (T, TableType) {
  let TableType(rt, l) = tt
  let (t, rt) = self.walk_reftype(t, rt)
  let (t, l) = self.walk_limits(t, l)
  (t, TableType(rt, l))
}

///|
pub fn[T] ModuleTransformer::walk_limits(
  self : ModuleTransformer[T],
  t : T,
  l : Limits,
) -> (T, Limits) {
  match self.on_limits {
    Some(f) => f(t, l).unwrap_or((t, l))
    None => (t, l)
  }
}

///|
pub fn[T] ModuleTransformer::walk_typesec(
  self : ModuleTransformer[T],
  t : T,
  ts : TypeSec,
) -> (T, TypeSec) {
  match self.on_typesec {
    Some(f) => f(t, ts).unwrap_or((t, ts))
    _ => self.walk_typesec_default(t, ts)
  }
}

///|
pub fn[T] ModuleTransformer::walk_typesec_default(
  self : ModuleTransformer[T],
  t : T,
  ts : TypeSec,
) -> (T, TypeSec) {
  let TypeSec(rectypes) = ts
  let (t, rectypes) = self.walk_array(t, ModuleTransformer::walk_rectype, rectypes)
  (t, TypeSec(rectypes))
}

///|
pub fn[T] ModuleTransformer::walk_rectype(
  self : ModuleTransformer[T],
  t : T,
  rt : RecType,
) -> (T, RecType) {
  match rt {
    SingleRecType(st) => {
      let (t, st) = self.walk_subtype(t, st)
      (t, SingleRecType(st))
    }
    GroupRecType(sts) => {
      let (t, sts) = self.walk_array(t, ModuleTransformer::walk_subtype, sts)
      (t, GroupRecType(sts))
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_subtype(
  self : ModuleTransformer[T],
  t : T,
  st : SubType,
) -> (T, SubType) {
  match st {
    SubType(f, supers, ct) => {
      let (t, supers) = self.walk_array(t, ModuleTransformer::walk_typeidx, supers)
      let (t, ct) = self.walk_comptype(t, ct)
      (t, SubType(f, supers, ct))
    }
    CompTypeSubType(ct) => {
      let (t, ct) = self.walk_comptype(t, ct)
      (t, CompTypeSubType(ct))
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_comptype(
  self : ModuleTransformer[T],
  t : T,
  ct : CompType,
) -> (T, CompType) {
  match ct {
    FuncCompType(params, results) => {
      let (t, params) = self.walk_array(t, ModuleTransformer::walk_valtype, params)
      let (t, results) = self.walk_array(t, ModuleTransformer::walk_valtype, results)
      (t, FuncCompType(params, results))
    }
    StructCompType(fields) => {
      let (t, fields) = self.walk_array(t, ModuleTransformer::walk_fieldtype, fields)
      (t, StructCompType(fields))
    }
    ArrayCompType(ft) => {
      let (t, ft) = self.walk_fieldtype(t, ft)
      (t, ArrayCompType(ft))
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_fieldtype(
  self : ModuleTransformer[T],
  t : T,
  ft : FieldType,
) -> (T, FieldType) {
  match self.on_fieldtype {
    Some(f) => f(t, ft).unwrap_or((t, ft))
    None => self.walk_fieldtype_default(t, ft)
  }
}

///|
pub fn[T] ModuleTransformer::walk_fieldtype_default(
  self : ModuleTransformer[T],
  t : T,
  ft : FieldType,
) -> (T, FieldType) {
  let FieldType(st, mut_) = ft
  let (t, st) = self.walk_storagetype(t, st)
  (t, FieldType(st, mut_))
}

///|
pub fn[T] ModuleTransformer::walk_storagetype(
  self : ModuleTransformer[T],
  t : T,
  st : StorageType,
) -> (T, StorageType) {
  match self.on_storagetype {
    Some(f) => f(t, st).unwrap_or((t, st))
    None => self.walk_storagetype_default(t, st)
  }
}

///|
pub fn[T] ModuleTransformer::walk_storagetype_default(
  self : ModuleTransformer[T],
  t : T,
  st : StorageType,
) -> (T, StorageType) {
  match st {
    ValTypeStorageType(vt) => {
      let (t, vt) = self.walk_valtype(t, vt)
      (t, ValTypeStorageType(vt))
    }
    PackTypeStorageType(_) => (t, st)
  }
}

///|
pub fn[T] ModuleTransformer::walk_globalsec(
  self : ModuleTransformer[T],
  t : T,
  gs : GlobalSec,
) -> (T, GlobalSec) {
  match self.on_globalsec {
    Some(f) => f(t, gs).unwrap_or((t, gs))
    None => self.walk_globalsec_default(t, gs)
  }
}

///|
pub fn[T] ModuleTransformer::walk_globalsec_default(
  self : ModuleTransformer[T],
  t : T,
  gs : GlobalSec,
) -> (T, GlobalSec) {
  let GlobalSec(gs) = gs
  let (t, gs) = self.walk_array(t, ModuleTransformer::walk_global, gs)
  (t, GlobalSec(gs))
}

///|
pub fn[T] ModuleTransformer::walk_global(
  self : ModuleTransformer[T],
  t : T,
  g : Global,
) -> (T, Global) {
  match self.on_global {
    Some(f) => f(t, g).unwrap_or((t, g))
    None => self.walk_global_default(t, g)
  }
}

///|
pub fn[T] ModuleTransformer::walk_global_default(
  self : ModuleTransformer[T],
  t : T,
  g : Global,
) -> (T, Global) {
  let Global(gt, init) = g
  let (t, gt) = self.walk_globaltype(t, gt)
  let (t, init) = self.walk_expr(t, init)
  (t, Global(gt, init))
}

///|
pub fn[T] ModuleTransformer::walk_globaltype(
  self : ModuleTransformer[T],
  t : T,
  gt : GlobalType,
) -> (T, GlobalType) {
  match self.on_globaltype {
    Some(f) => f(t, gt).unwrap_or((t, gt))
    None => self.walk_globaltype_default(t, gt)
  }
}

///|
pub fn[T] ModuleTransformer::walk_globaltype_default(
  self : ModuleTransformer[T],
  t : T,
  gt : GlobalType,
) -> (T, GlobalType) {
  let GlobalType(vt, mutable) = gt
  let (t, vt) = self.walk_valtype(t, vt)
  (t, GlobalType(vt, mutable))
}

///|
pub fn[T] ModuleTransformer::walk_elem(
  self : ModuleTransformer[T],
  t : T,
  e : Elem,
) -> (T, Elem) {
  let Elem(mode, kind) = e
  let (t, mode) = self.walk_elemmode(t, mode)
  let (t, kind) = self.walk_elemkind(t, kind)
  (t, Elem(mode, kind))
}

///|
pub fn[T] ModuleTransformer::walk_elemmode(
  self : ModuleTransformer[T],
  t : T,
  mode : ElemMode,
) -> (T, ElemMode) {
  match mode {
    Active(tidx, offset) => {
      let (t, tidx) = self.walk_tableidx(t, tidx)
      let (t, offset) = self.walk_expr(t, offset)
      (t, Active(tidx, offset))
    }
    other => (t, other)
  }
}

///|
pub fn[T] ModuleTransformer::walk_elemkind(
  self : ModuleTransformer[T],
  t : T,
  ek : ElemKind,
) -> (T, ElemKind) {
  match self.on_elemkind {
    Some(f) => f(t, ek).unwrap_or((t, ek))
    _ => self.walk_elemkind_default(t, ek)
  }
}

///|
pub fn[T] ModuleTransformer::walk_elemkind_default(
  self : ModuleTransformer[T],
  t : T,
  kind : ElemKind,
) -> (T, ElemKind) {
  match kind {
    FuncsElemKind(idxs) => {
      let (t, idxs) = self.walk_array(t, ModuleTransformer::walk_funcidx, idxs)
      (t, FuncsElemKind(idxs))
    }
    FuncExprsElemKind(exprs) => {
      let (t, exprs) = self.walk_array(t, ModuleTransformer::walk_expr, exprs)
      (t, FuncExprsElemKind(exprs))
    }
    TypedExprsElemKind(rt, exprs) => {
      let (t, rt) = self.walk_reftype(t, rt)
      let (t, exprs) = self.walk_array(t, ModuleTransformer::walk_expr, exprs)
      (t, TypedExprsElemKind(rt, exprs))
    }
  }
}

///|
pub fn[T] ModuleTransformer::walk_data(
  self : ModuleTransformer[T],
  t : T,
  d : Data,
) -> (T, Data) {
  let Data(mode, bytes) = d
  let (t, mode) = self.walk_datamode(t, mode)
  (t, Data(mode, bytes))
}

///|
pub fn[T] ModuleTransformer::walk_datamode(
  self : ModuleTransformer[T],
  t : T,
  mode : DataMode,
) -> (T, DataMode) {
  match mode {
    Active(midx, offset) => {
      let (t, midx) = self.walk_memidx(t, midx)
      let (t, offset) = self.walk_expr(t, offset)
      (t, Active(midx, offset))
    }
    Passive => (t, Passive)
  }
}

///|
pub fn[T] ModuleTransformer::walk_funcsec(
  self : ModuleTransformer[T],
  t : T,
  fs : FuncSec,
) -> (T, FuncSec) {
  match self.on_funcsec {
    Some(f) => f(t, fs).unwrap_or((t, fs))
    _ => self.walk_funcsec_default(t, fs)
  }
}

///|
pub fn[T] ModuleTransformer::walk_funcsec_default(
  self : ModuleTransformer[T],
  t : T,
  fs : FuncSec,
) -> (T, FuncSec) {
  let FuncSec(idxs) = fs
  let (t, idxs) = self.walk_array(t, ModuleTransformer::walk_typeidx, idxs)
  (t, FuncSec(idxs))
}
