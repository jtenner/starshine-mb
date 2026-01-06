pub type TransformerResult[T, Elem] = Result[(T, Elem)?, String]

pub fn [T, Elem] change(t : T, elem : Elem) -> TransformerResult[T, Elem] {
  Ok(Some((t, elem)))
}

pub fn [T, Elem] unchanged() -> TransformerResult[T, Elem] {
  Ok(None)
}

pub fn [T, Elem] error(err : String) -> TransformerResult[T, Elem] {
  Err(err)
}

// Transformer Definition

pub struct ModuleTransformer[T] {
  on_typesec : ((T, TypeSec) -> TransformerResult[T, TypeSec])?
  on_funcsec : ((T, FuncSec) -> TransformerResult[T, FuncSec])?
  on_tablesec : ((T, TableSec) -> TransformerResult[T, TableSec])?
  on_memsec : ((T, MemSec) -> TransformerResult[T, MemSec])?
  on_tagsec : ((T, TagSec) -> TransformerResult[T, TagSec])?
  on_globalsec : ((T, GlobalSec) -> TransformerResult[T, GlobalSec])?
  on_exportsec : ((T, ExportSec) -> TransformerResult[T, ExportSec])?
  on_startsec : ((T, StartSec) -> TransformerResult[T, StartSec])?
  on_elemsec : ((T, ElemSec) -> TransformerResult[T, ElemSec])?
  on_elemkind : ((T, ElemKind) -> TransformerResult[T, ElemKind])?
  on_datacntsec : ((T, DataCntSec) -> TransformerResult[T, DataCntSec])?
  on_codesec : ((T, CodeSec) -> TransformerResult[T, CodeSec])?
  on_datasec : ((T, DataSec) -> TransformerResult[T, DataSec])?
  on_instruction : ((T, Instruction) -> TransformerResult[T, Instruction])?
  on_expr : ((T, Expr) -> TransformerResult[T, Expr])?
  on_table : ((T, Table) -> TransformerResult[T, Table])?
  on_valtype : ((T, ValType) -> TransformerResult[T, ValType])?
  on_numtype : ((T, NumType) -> TransformerResult[T, NumType])?
  on_rectype : ((T, RecType) -> TransformerResult[T, RecType])?
  on_subtype : ((T, SubType) -> TransformerResult[T, SubType])?
  on_comptype : ((T, CompType) -> TransformerResult[T, CompType])?
  on_reftype : ((T, RefType) -> TransformerResult[T, RefType])?
  on_heaptype : ((T, HeapType) -> TransformerResult[T, HeapType])?
  on_blocktype : ((T, BlockType) -> TransformerResult[T, BlockType])?
  on_funcidx : ((T, FuncIdx) -> TransformerResult[T, FuncIdx])?
  on_typeidx : ((T, TypeIdx) -> TransformerResult[T, TypeIdx])?
  on_localidx : ((T, LocalIdx) -> TransformerResult[T, LocalIdx])?
  on_globalidx : ((T, GlobalIdx) -> TransformerResult[T, GlobalIdx])?
  on_tableidx : ((T, TableIdx) -> TransformerResult[T, TableIdx])?
  on_memidx : ((T, MemIdx) -> TransformerResult[T, MemIdx])?
  on_labelidx : ((T, LabelIdx) -> TransformerResult[T, LabelIdx])?
  on_dataidx : ((T, DataIdx) -> TransformerResult[T, DataIdx])?
  on_elemidx : ((T, ElemIdx) -> TransformerResult[T, ElemIdx])?
  on_tagidx : ((T, TagIdx) -> TransformerResult[T, TagIdx])?
  on_name : ((T, Name) -> TransformerResult[T, Name])?
  on_externtype : ((T, ExternType) -> TransformerResult[T, ExternType])?
  on_limits : ((T, Limits) -> TransformerResult[T, Limits])?
  on_memtype : ((T, MemType) -> TransformerResult[T, MemType])?
  on_tagtype : ((T, TagType) -> TransformerResult[T, TagType])?
  on_export : ((T, Export) -> TransformerResult[T, Export])?
  on_global : ((T, Global) -> TransformerResult[T, Global])?
  on_globaltype : ((T, GlobalType) -> TransformerResult[T, GlobalType])?
  on_func : ((T, Func) -> TransformerResult[T, Func])?
  on_locals : ((T, Array[Locals]) -> TransformerResult[T, Array[Locals]])?
  on_externidx : ((T, ExternIdx) -> TransformerResult[T, ExternIdx])?
  on_fieldtype : ((T, FieldType) -> TransformerResult[T, FieldType])?
  on_storagetype : ((T, StorageType) -> TransformerResult[T, StorageType])?
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
  if changed { Ok(Some((t, a))) } else { Ok(None) }
}

pub fn[T] ModuleTransformer::walk_name(
  self : ModuleTransformer[T],
  t : T,
  name : Name,
) -> TransformerResult[T, Name] {
  match self.on_name {
    Some(f) => f(t, name)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_expr(
  self : ModuleTransformer[T],
  t : T,
  expr : Expr,
) -> TransformerResult[T, Expr] {
  match self.on_expr {
    Some(f) =>
      match f(t, expr) {
        Err(e) => Err(e)
        Ok(None) => self.walk_expr_default(t, expr)
        ok => ok
      }
    None => self.walk_expr_default(t, expr)
  }
}

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
pub fn[T] ModuleTransformer::walk_instruction(
  self : ModuleTransformer[T],
  t : T,
  instr : Instruction,
) -> TransformerResult[T, Instruction] {
  match self.on_instruction {
    Some(f) =>
      match f(t, instr) {
        Err(e) => Err(e)
        Ok(None) => self.walk_instruction_default(t, instr)
        ok => ok
      }
    None => self.walk_instruction_default(t, instr)
  }
}


pub fn[T] ModuleTransformer::walk_instruction_default(
  self : ModuleTransformer[T],
  t : T,
  instr : Instruction,
) -> TransformerResult[T, Instruction] {
  match instr {
    // Control instructions
    Block(bt, body) => {
      match self.walk_blocktype(t, bt) {
        Err(e) => Err(e)
        Ok(None) => {
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, body))) => Ok(Some((t, Block(bt, body))))
          }
        }
        Ok(Some((t, bt))) => {
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, Block(bt, body))))
            Ok(Some((t, body))) => Ok(Some((t, Block(bt, body))))
          }
        }
      }
    }
    Loop(bt, body) => {
      match self.walk_blocktype(t, bt) {
        Err(e) => Err(e)
        Ok(None) => {
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, body))) => Ok(Some((t, Loop(bt, body))))
          }
        }
        Ok(Some((t, bt))) => {
          match self.walk_expr(t, body) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, Loop(bt, body))))
            Ok(Some((t, body))) => Ok(Some((t, Loop(bt, body))))
          }
        }
      }
    }
    If(bt, then_body, else_body_opt) => {
      let (t, bt) = match self.walk_blocktype(t, bt) {
        Err(e) => return Err(e)
        Ok(None) => (t, bt)
        Ok(Some((t, bt))) => (t, bt)
      }
      let (t, then_body) = match self.walk_array(
        t,
        ModuleTransformer::walk_instruction,
        then_body,
      ) {
        Err(e) => return Err(e)
        Ok(None) => (t, then_body)
        Ok(Some((t, arr))) => (t, arr)
      }
      let (t, else_body_opt) = match else_body_opt {
        None => (t, None)
        Some(else_body) => match self.walk_array(
          t,
          ModuleTransformer::walk_instruction,
          else_body,
        ) {
          Err(e) => return Err(e)
          Ok(None) => (t, Some(else_body))
          Ok(Some((t, arr))) => (t, Some(arr))
        }
      }
      Ok(Some((t, If(bt, then_body, else_body_opt))))
    }
    TryTable(bt, catches, body) => {
      match self.walk_blocktype(t, bt) {
        Err(e) => Err(e)
        Ok(None) => {
          match self.walk_array(t, ModuleTransformer::walk_catch, catches) {
            Err(e) => Err(e)
            Ok(None) => {
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) => Ok(None)
                Ok(Some((t, body))) => Ok(Some((t, TryTable(bt, catches, body))))
              }
            }
            Ok(Some((t, catches))) => {
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) => Ok(Some((t, TryTable(bt, catches, body))))
                Ok(Some((t, body))) => Ok(Some((t, TryTable(bt, catches, body))))
              }
            }
          }
        }
        Ok(Some((t, bt))) => {
          match self.walk_array(t, ModuleTransformer::walk_catch, catches) {
            Err(e) => Err(e)
            Ok(None) => {
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) => Ok(Some((t, TryTable(bt, catches, body))))
                Ok(Some((t, body))) => Ok(Some((t, TryTable(bt, catches, body))))
              }
            }
            Ok(Some((t, catches))) => {
              match self.walk_expr(t, body) {
                Err(e) => Err(e)
                Ok(None) => Ok(Some((t, TryTable(bt, catches, body))))
                Ok(Some((t, body))) => Ok(Some((t, TryTable(bt, catches, body))))
              }
            }
          }
        }
      }
    }

    // Branch instructions
    Br(l) => {
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, Br(l))))
      }
    }
    BrIf(l) => {
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, BrIf(l))))
      }
    }
    BrTable(labels, default) => {
      match self.walk_array(t, ModuleTransformer::walk_labelidx, labels) {
        Err(e) => Err(e)
        Ok(None) => {
          match self.walk_labelidx(t, default) {
            Err(e) => Err(e)
            Ok(None) => Ok(None)
            Ok(Some((t, default))) => Ok(Some((t, BrTable(labels, default))))
          }
        }
        Ok(Some((t, labels))) => {
          match self.walk_labelidx(t, default) {
            Err(e) => Err(e)
            Ok(None) => Ok(Some((t, BrTable(labels, default))))
            Ok(Some((t, default))) => Ok(Some((t, BrTable(labels, default))))
          }
        }
      }
    }
    BrOnNull(l) => {
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, BrOnNull(l))))
      }
    }
    BrOnNonNull(l) => {
      match self.walk_labelidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, BrOnNonNull(l))))
      }
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
    Call(f) => {
      match self.walk_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, Call(f))))
      }
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
    ReturnCall(f) => {
      match self.walk_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, ReturnCall(f))))
      }
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
    CallRef(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, CallRef(ty))))
      }
    }
    ReturnCallRef(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ReturnCallRef(ty))))
      }
    }

    // Variable instructions
    LocalGet(l) => {
      match self.walk_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, LocalGet(l))))
      }
    }
    LocalSet(l) => {
      match self.walk_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, LocalSet(l))))
      }
    }
    LocalTee(l) => {
      match self.walk_localidx(t, l) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, l))) => Ok(Some((t, LocalTee(l))))
      }
    }
    GlobalGet(g) => {
      match self.walk_globalidx(t, g) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, g))) => Ok(Some((t, GlobalGet(g))))
      }
    }
    GlobalSet(g) => {
      match self.walk_globalidx(t, g) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, g))) => Ok(Some((t, GlobalSet(g))))
      }
    }

    // Table instructions
    TableGet(tbl) => {
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, TableGet(tbl))))
      }
    }
    TableSet(tbl) => {
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, TableSet(tbl))))
      }
    }
    TableGrow(tbl) => {
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, TableGrow(tbl))))
      }
    }
    TableSize(tbl) => {
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, TableSize(tbl))))
      }
    }
    TableFill(tbl) => {
      match self.walk_tableidx(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, tbl))) => Ok(Some((t, TableFill(tbl))))
      }
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
    ElemDrop(e) => {
      match self.walk_elemidx(t, e) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, e))) => Ok(Some((t, ElemDrop(e))))
      }
    }

    // Reference instructions
    RefNull(ht) => {
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, RefNull(ht))))
      }
    }
    RefFunc(f) => {
      match self.walk_funcidx(t, f) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, f))) => Ok(Some((t, RefFunc(f))))
      }
    }
    RefTest(nullable, ht) => {
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, RefTest(nullable, ht))))
      }
    }
    RefCast(nullable, ht) => {
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, RefCast(nullable, ht))))
      }
    }

    // Struct/Array instructions
    StructNew(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructNew(ty))))
      }
    }
    StructNewDefault(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructNewDefault(ty))))
      }
    }
    StructGet(ty, f) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructGet(ty, f))))
      }
    }
    StructGetS(ty, f) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructGetS(ty, f))))
      }
    }
    StructGetU(ty, f) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructGetU(ty, f))))
      }
    }
    StructSet(ty, f) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, StructSet(ty, f))))
      }
    }
    ArrayNew(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayNew(ty))))
      }
    }
    ArrayNewDefault(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayNewDefault(ty))))
      }
    }
    ArrayNewFixed(ty, n) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayNewFixed(ty, n))))
      }
    }
    ArrayNewData(ty, n) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayNewData(ty, n))))
      }
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
    ArrayGet(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayGet(ty))))
      }
    }
    ArrayGetS(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayGetS(ty))))
      }
    }
    ArrayGetU(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayGetU(ty))))
      }
    }
    ArraySet(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArraySet(ty))))
      }
    }
    ArrayFill(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, ArrayFill(ty))))
      }
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
    MemorySize(m) => {
      match self.walk_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, MemorySize(m))))
      }
    }
    MemoryGrow(m) => {
      match self.walk_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, MemoryGrow(m))))
      }
    }
    MemoryFill(m) => {
      match self.walk_memidx(t, m) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, m))) => Ok(Some((t, MemoryFill(m))))
      }
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
    DataDrop(d) => {
      match self.walk_dataidx(t, d) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, d))) => Ok(Some((t, DataDrop(d))))
      }
    }

    // Exception instructions
    Throw(ty) => {
      match self.walk_tagidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, Throw(ty))))
      }
    }

    // Select with types
    Select(types) =>
      match types {
        None => Ok(None)
        Some(types) => match self.walk_array(
          t,
          ModuleTransformer::walk_valtype,
          types,
        ) {
          Err(e) => Err(e)
          Ok(None) => Ok(None)
          Ok(Some((t, types))) => Ok(Some((t, Select(Some(types)))))
        }
      }

    // All other instructions pass through unchanged
    _ => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_blocktype(
  self : ModuleTransformer[T],
  t : T,
  bt : BlockType,
) -> TransformerResult[T, BlockType] {
  match self.on_blocktype {
    Some(f) =>
      match f(t, bt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_blocktype_default(t, bt)
        ok => ok
      }
    None => self.walk_blocktype_default(t, bt)
  }
}

pub fn[T] ModuleTransformer::walk_blocktype_default(
  self : ModuleTransformer[T],
  t : T,
  bt : BlockType,
) -> TransformerResult[T, BlockType] {
  match bt {
    ValTypeBlockType(vt) => {
      match self.walk_valtype(t, vt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, vt))) => Ok(Some((t, ValTypeBlockType(vt))))
      }
    }
    TypeIdxBlockType(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, TypeIdxBlockType(ty))))
      }
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
    CatchAll(label) => {
      match self.walk_labelidx(t, label) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, label))) => Ok(Some((t, CatchAll(label))))
      }
    }
    CatchAllRef(label) => {
      match self.walk_labelidx(t, label) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, label))) => Ok(Some((t, CatchAllRef(label))))
      }
    }
  }
}

// Index walkers - leaf nodes
pub fn[T] ModuleTransformer::walk_funcidx(
  self : ModuleTransformer[T],
  t : T,
  idx : FuncIdx,
) -> TransformerResult[T, FuncIdx] {
  match self.on_funcidx {
    Some(f) => f(t, idx)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_typeidx(
  self : ModuleTransformer[T],
  t : T,
  idx : TypeIdx,
) -> TransformerResult[T, TypeIdx] {
  match self.on_typeidx {
    Some(f) => f(t, idx)
    None => Ok(None)
  }
}


pub fn[T] ModuleTransformer::walk_localidx(
  self : ModuleTransformer[T],
  t : T,
  idx : LocalIdx,
) -> TransformerResult[T, LocalIdx] {
  match self.on_localidx {
    Some(f) => f(t, idx)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_globalidx(
  self : ModuleTransformer[T],
  t : T,
  idx : GlobalIdx,
) -> TransformerResult[T, GlobalIdx] {
  match self.on_globalidx {
    Some(f) => f(t, idx)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_tableidx(
  self : ModuleTransformer[T],
  t : T,
  idx : TableIdx,
) -> TransformerResult[T, TableIdx] {
  match self.on_tableidx {
    Some(f) => f(t, idx)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_memidx(
  self : ModuleTransformer[T],
  t : T,
  idx : MemIdx,
) -> TransformerResult[T, MemIdx] {
  match self.on_memidx {
    Some(f) => f(t, idx)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_labelidx(
  self : ModuleTransformer[T],
  t : T,
  idx : LabelIdx,
) -> TransformerResult[T, LabelIdx] {
  match self.on_labelidx {
    Some(f) => f(t, idx)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_dataidx(
  self : ModuleTransformer[T],
  t : T,
  idx : DataIdx,
) -> TransformerResult[T, DataIdx] {
  match self.on_dataidx {
    Some(f) => f(t, idx)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_elemidx(
  self : ModuleTransformer[T],
  t : T,
  idx : ElemIdx,
) -> TransformerResult[T, ElemIdx] {
  match self.on_elemidx {
    Some(f) => f(t, idx)
    None => Ok(None)
  }
}
pub fn[T] ModuleTransformer::walk_tagidx(
  self : ModuleTransformer[T],
  t : T,
  idx : TagIdx,
) -> TransformerResult[T, TagIdx] {
  match self.on_tagidx {
    Some(f) => f(t, idx)
    None => Ok(None)
  }
}


pub fn[T] ModuleTransformer::walk_valtype(
  self : ModuleTransformer[T],
  t : T,
  vt : ValType,
) -> TransformerResult[T, ValType] {
  match self.on_valtype {
    Some(f) =>
      match f(t, vt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_valtype_default(t, vt)
        ok => ok
      }
    None => self.walk_valtype_default(t, vt)
  }
}

pub fn[T] ModuleTransformer::walk_valtype_default(
  self : ModuleTransformer[T],
  t : T,
  vt : ValType,
) -> TransformerResult[T, ValType] {
  match vt {
    RefTypeValType(rt) => {
      match self.walk_reftype(t, rt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, rt))) => Ok(Some((t, RefTypeValType(rt))))
      }
    }
    NumTypeValType(nt) => {
      match self.walk_numtype(t, nt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, nt))) => Ok(Some((t, NumTypeValType(nt))))
      }
    }
    _ => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_numtype(
  self : ModuleTransformer[T],
  t : T,
  nt : NumType,
) -> TransformerResult[T, NumType] {
  match self.on_numtype {
    Some(f) => f(t, nt)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_reftype(
  self : ModuleTransformer[T],
  t : T,
  rt : RefType,
) -> TransformerResult[T, RefType] {
  match self.on_reftype {
    Some(f) =>
      match f(t, rt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_reftype_default(t, rt)
        ok => ok
      }
    None => self.walk_reftype_default(t, rt)
  }
}

pub fn[T] ModuleTransformer::walk_reftype_default(
  self : ModuleTransformer[T],
  t : T,
  rt : RefType,
) -> TransformerResult[T, RefType] {
  match rt {
    HeapTypeRefType(nullable, ht) => {
      match self.walk_heaptype(t, ht) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ht))) => Ok(Some((t, HeapTypeRefType(nullable, ht))))
      }
    }
    _ => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_heaptype(
  self : ModuleTransformer[T],
  t : T,
  ht : HeapType,
) -> TransformerResult[T, HeapType] {
  match self.on_heaptype {
    Some(f) =>
      match f(t, ht) {
        Err(e) => Err(e)
        Ok(None) => self.walk_heaptype_default(t, ht)
        ok => ok
      }
    None => self.walk_heaptype_default(t, ht)
  }
}

pub fn[T] ModuleTransformer::walk_heaptype_default(
  self : ModuleTransformer[T],
  t : T,
  ht : HeapType,
) -> TransformerResult[T, HeapType] {
  match ht {
    HeapType(ty) => {
      match self.walk_typeidx(t, ty) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ty))) => Ok(Some((t, HeapType(ty))))
      }
    }
    _ => Ok(None)
  }
}


// Sections

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
pub fn[T] ModuleTransformer::walk_customsecs(
  self : ModuleTransformer[T],
  t : T,
  secs : Array[CustomSec],
) -> TransformerResult[T, Array[CustomSec]] {
  self.walk_array(t, ModuleTransformer::walk_customsec, secs)
}

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
    Some(sec) => match self.walk_typesec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, import_sec) = match import_sec {
    None => (t, None)
    Some(sec) => match self.walk_importsec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, func_sec) = match func_sec {
    None => (t, None)
    Some(sec) => match self.walk_funcsec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, table_sec) = match table_sec {
    None => (t, None)
    Some(sec) => match self.walk_tablesec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, mem_sec) = match mem_sec {
    None => (t, None)
    Some(sec) => match self.walk_memsec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, tag_sec) = match tag_sec {
    None => (t, None)
    Some(sec) => match self.walk_tagsec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, global_sec) = match global_sec {
    None => (t, None)
    Some(sec) => match self.walk_globalsec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, export_sec) = match export_sec {
    None => (t, None)
    Some(sec) => match self.walk_exportsec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, start_sec) = match start_sec {
    None => (t, None)
    Some(sec) => match self.walk_startsec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, elem_sec) = match elem_sec {
    None => (t, None)
    Some(sec) => match self.walk_elemsec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, datacnt_sec) = match datacnt_sec {
    None => (t, None)
    Some(sec) => match self.walk_datacntsec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, code_sec) = match code_sec {
    None => (t, None)
    Some(sec) => match self.walk_codesec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  let (t, data_sec) = match data_sec {
    None => (t, None)
    Some(sec) => match self.walk_datasec(t, sec) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(sec))
      Ok(Some((t, sec))) => (t, Some(sec))
    }
  }

  Ok(Some((t, Module(
    custom, type_sec, import_sec, func_sec, table_sec, mem_sec, tag_sec, global_sec,
    export_sec, start_sec, elem_sec, datacnt_sec, code_sec, data_sec,
  ))))
}

pub fn[T] ModuleTransformer::walk_datasec(
  self : ModuleTransformer[T],
  t : T,
  ds : DataSec,
) -> TransformerResult[T, DataSec] {
  match self.on_datasec {
    Some(f) =>
      match f(t, ds) {
        Err(e) => Err(e)
        Ok(None) => self.walk_datasec_default(t, ds)
        ok => ok
      }
    None => self.walk_datasec_default(t, ds)
  }
}
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

pub fn[T] ModuleTransformer::walk_codesec(
  self : ModuleTransformer[T],
  t : T,
  cs : CodeSec,
) -> TransformerResult[T, CodeSec] {
  match self.on_codesec {
    Some(f) =>
      match f(t, cs) {
        Err(e) => Err(e)
        Ok(None) => self.walk_codesec_default(t, cs)
        ok => ok
      }
    None => self.walk_codesec_default(t, cs)
  }
}

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

pub fn[T] ModuleTransformer::walk_datacntsec(
  self : ModuleTransformer[T],
  t : T,
  dcs : DataCntSec,
) -> TransformerResult[T, DataCntSec] {
  match self.on_datacntsec {
    Some(f) => f(t, dcs)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_elemsec(
  self : ModuleTransformer[T],
  t : T,
  es : ElemSec,
) -> TransformerResult[T, ElemSec] {
  match self.on_elemsec {
    Some(f) =>
      match f(t, es) {
        Err(e) => Err(e)
        Ok(None) => self.walk_elemsec_default(t, es)
        ok => ok
      }
    None => self.walk_elemsec_default(t, es)
  }
}

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

pub fn[T] ModuleTransformer::walk_startsec(
  self : ModuleTransformer[T],
  t : T,
  ss : StartSec,
) -> TransformerResult[T, StartSec] {
  match self.on_startsec {
    Some(f) =>
      match f(t, ss) {
        Err(e) => Err(e)
        Ok(None) => self.walk_startsec_default(t, ss)
        ok => ok
      }
    None => self.walk_startsec_default(t, ss)
  }
}

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

pub fn[T] ModuleTransformer::walk_exportsec(
  self : ModuleTransformer[T],
  t : T,
  es : ExportSec,
) -> TransformerResult[T, ExportSec] {
  match self.on_exportsec {
    Some(f) =>
      match f(t, es) {
        Err(e) => Err(e)
        Ok(None) => self.walk_exportsec_default(t, es)
        ok => ok
      }
    None => self.walk_exportsec_default(t, es)
  }
}

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

pub fn[T] ModuleTransformer::walk_tagsec(
  self : ModuleTransformer[T],
  t : T,
  ts : TagSec,
) -> TransformerResult[T, TagSec] {
  match self.on_tagsec {
    Some(f) =>
      match f(t, ts) {
        Err(e) => Err(e)
        Ok(None) => self.walk_tagsec_default(t, ts)
        ok => ok
      }
    None => self.walk_tagsec_default(t, ts)
  }
}

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

pub fn[T] ModuleTransformer::walk_memsec(
  self : ModuleTransformer[T],
  t : T,
  ms : MemSec,
) -> TransformerResult[T, MemSec] {
  match self.on_memsec {
    Some(f) =>
      match f(t, ms) {
        Err(e) => Err(e)
        Ok(None) => self.walk_memsec_default(t, ms)
        ok => ok
      }
    None => self.walk_memsec_default(t, ms)
  }
}

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

pub fn[T] ModuleTransformer::walk_tablesec(
  self : ModuleTransformer[T],
  t : T,
  ts : TableSec,
) -> TransformerResult[T, TableSec] {
  match self.on_tablesec {
    Some(f) =>
      match f(t, ts) {
        Err(e) => Err(e)
        Ok(None) => self.walk_tablesec_default(t, ts)
        ok => ok
      }
    None => self.walk_tablesec_default(t, ts)
  }
}

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

pub fn[T] ModuleTransformer::walk_func(
  self : ModuleTransformer[T],
  t : T,
  func : Func,
) -> TransformerResult[T, Func] {
  match self.on_func {
    Some(f) =>
      match f(t, func) {
        Err(e) => Err(e)
        Ok(None) => self.walk_func_default(t, func)
        ok => ok
      }
    None => self.walk_func_default(t, func)
  }
}

pub fn[T] ModuleTransformer::walk_func_default(
  self : ModuleTransformer[T],
  t : T,
  f : Func,
) -> TransformerResult[T, Func] {
  let Func(locals, body) = f
  let mut locals = locals
  let t = match self.walk_locals(t, locals) {
    Err(e) => return Err(e)
    Ok(None) => t
    Ok(Some((t, ls))) => {
      locals = ls;
      t 
    }
  }
  match self.walk_expr(t, body) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((t, body))) => Ok(Some((t, Func(locals, body))))
  }
}

pub fn[T] ModuleTransformer::walk_locals(
  self : ModuleTransformer[T],
  t : T,
  l : Array[Locals],
) -> TransformerResult[T, Array[Locals]] {
  match self.on_locals {
    Some(f) => f(t, l)
    None => self.walk_locals_default(t, l)
  }
}


pub fn[T] ModuleTransformer::walk_locals_default(
  self : ModuleTransformer[T],
  t : T,
  ls : Array[Locals],
) -> TransformerResult[T, Array[Locals]] {
  self.walk_array(t, ModuleTransformer::walk_single_local, ls)
}

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

pub fn[T] ModuleTransformer::walk_export(
  self : ModuleTransformer[T],
  t : T,
  expt : Export,
) -> TransformerResult[T, Export] {
  match self.on_export {
    Some(f) =>
      match f(t, expt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_export_default(t, expt)
        ok => ok
      }
    None => self.walk_export_default(t, expt)
  }
}


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


pub fn[T] ModuleTransformer::walk_externidx(
  self : ModuleTransformer[T],
  t : T,
  ex : ExternIdx,
) -> TransformerResult[T, ExternIdx] {
  match self.on_externidx {
    Some(f) =>
      match f(t, ex) {
        Err(e) => Err(e)
        Ok(None) => self.walk_externidx_default(t, ex)
        ok => ok
      }
    None => self.walk_externidx_default(t, ex)
  }
}
pub fn[T] ModuleTransformer::walk_externidx_default(
  self : ModuleTransformer[T],
  t : T,
  ex : ExternIdx,
) -> TransformerResult[T, ExternIdx] {
  match ex {
    FuncExternIdx(fi) => {
      match self.walk_funcidx(t, fi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, fi))) => Ok(Some((t, FuncExternIdx(fi))))
      }
    }
    TableExternIdx(ti) => {
      match self.walk_tableidx(t, ti) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ti))) => Ok(Some((t, TableExternIdx(ti))))
      }
    }
    MemExternIdx(mi) => {
      match self.walk_memidx(t, mi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, mi))) => Ok(Some((t, MemExternIdx(mi))))
      }
    }
    GlobalExternIdx(gi) => {
      match self.walk_globalidx(t, gi) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, gi))) => Ok(Some((t, GlobalExternIdx(gi))))
      }
    }
    TagExternIdx(ti) => {
      match self.walk_tagidx(t, ti) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ti))) => Ok(Some((t, TagExternIdx(ti))))
      }
    }
  }
}


pub fn[T] ModuleTransformer::walk_table(
  self : ModuleTransformer[T],
  t : T,
  tbl : Table,
) -> TransformerResult[T, Table] {
  match self.on_table {
    Some(f) =>
      match f(t, tbl) {
        Err(e) => Err(e)
        Ok(None) => self.walk_table_default(t, tbl)
        ok => ok
      }
    None => self.walk_table_default(t, tbl)
  }
}

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
    Some(e) => match self.walk_expr(t, e) {
      Err(e) => return Err(e)
      Ok(None) => (t, Some(e))
      Ok(Some((t, e))) => (t, Some(e))
    }
  }
  Ok(Some((t, Table(tt, e_option))))
}

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

pub fn[T] ModuleTransformer::walk_externtype(
  self : ModuleTransformer[T],
  t : T,
  ex : ExternType,
) -> TransformerResult[T, ExternType] {
  match self.on_externtype {
    Some(f) => f(t, ex)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_tagtype(
  self : ModuleTransformer[T],
  t : T,
  tt : TagType,
) -> TransformerResult[T, TagType] {
  match self.on_tagtype {
    Some(f) =>
      match f(t, tt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_tagtype_default(t, tt)
        ok => ok
      }
    None => self.walk_tagtype_default(t, tt)
  }
}

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

pub fn[T] ModuleTransformer::walk_memtype(
  self : ModuleTransformer[T],
  t : T,
  mt : MemType,
) -> TransformerResult[T, MemType] {
  match self.on_memtype {
    Some(f) =>
      match f(t, mt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_memtype_default(t, mt)
        ok => ok
      }
    None => self.walk_memtype_default(t, mt)
  }
}

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

pub fn[T] ModuleTransformer::walk_limits(
  self : ModuleTransformer[T],
  t : T,
  l : Limits,
) -> TransformerResult[T, Limits] {
  match self.on_limits {
    Some(f) => f(t, l)
    None => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_typesec(
  self : ModuleTransformer[T],
  t : T,
  ts : TypeSec,
) -> TransformerResult[T, TypeSec] {
  match self.on_typesec {
    Some(f) =>
      match f(t, ts) {
        Err(e) => Err(e)
        Ok(None) => self.walk_typesec_default(t, ts)
        ok => ok
      }
    None => self.walk_typesec_default(t, ts)
  }
}

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

pub fn[T] ModuleTransformer::walk_rectype(
  self : ModuleTransformer[T],
  t : T,
  rt : RecType,
) -> TransformerResult[T, RecType] {
  match self.on_rectype {
    Some(f) =>
      match f(t, rt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_rectype_default(t, rt)
        ok => ok
      }
    None => self.walk_rectype_default(t, rt)
  }
}

pub fn[T] ModuleTransformer::walk_rectype_default(
  self : ModuleTransformer[T],
  t : T,
  rt : RecType,
) -> TransformerResult[T, RecType] {
  match rt {
    SingleRecType(st) => {
      match self.walk_subtype(t, st) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, st))) => Ok(Some((t, SingleRecType(st))))
      }
    }
    GroupRecType(sts) => {
      match self.walk_array(t, ModuleTransformer::walk_subtype, sts) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, sts))) => Ok(Some((t, GroupRecType(sts))))
      }
    }
  }
}

pub fn[T] ModuleTransformer::walk_subtype(
  self : ModuleTransformer[T],
  t : T,
  st : SubType,
) -> TransformerResult[T, SubType] {
  match self.on_subtype {
    Some(f) =>
      match f(t, st) {
        Err(e) => Err(e)
        Ok(None) => self.walk_subtype_default(t, st)
        ok => ok
      }
    None => self.walk_subtype_default(t, st)
  }
}

pub fn[T] ModuleTransformer::walk_subtype_default(
  self : ModuleTransformer[T],
  t : T,
  st : SubType,
) -> TransformerResult[T, SubType] {
  match st {
    SubType(f, supers, ct) => {
      let (t, supers) = match self.walk_array(
        t,
        ModuleTransformer::walk_typeidx,
        supers,
      ) {
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
    CompTypeSubType(ct) => {
      match self.walk_comptype(t, ct) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ct))) => Ok(Some((t, CompTypeSubType(ct))))
      }
    }
  }
}

pub fn[T] ModuleTransformer::walk_comptype(
  self : ModuleTransformer[T],
  t : T,
  ct : CompType,
) -> TransformerResult[T, CompType] {
  match self.on_comptype {
    Some(f) =>
      match f(t, ct) {
        Err(e) => Err(e)
        Ok(None) => self.walk_comptype_default(t, ct)
        ok => ok
      }
    None => self.walk_comptype_default(t, ct)
  }
}

pub fn[T] ModuleTransformer::walk_comptype_default(
  self : ModuleTransformer[T],
  t : T,
  ct : CompType,
) -> TransformerResult[T, CompType] {
  match ct {
    FuncCompType(params, results) => {
      let (t, params) = match self.walk_array(
        t,
        ModuleTransformer::walk_valtype,
        params,
      ) {
        Err(e) => return Err(e)
        Ok(None) => (t, params)
        Ok(Some((t, params))) => (t, params)
      }
      let (t, results) = match self.walk_array(
        t,
        ModuleTransformer::walk_valtype,
        results,
      ) {
        Err(e) => return Err(e)
        Ok(None) => (t, results)
        Ok(Some((t, results))) => (t, results)
      }
      Ok(Some((t, FuncCompType(params, results))))
    }
    StructCompType(fields) => {
      match self.walk_array(t, ModuleTransformer::walk_fieldtype, fields) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, fields))) => Ok(Some((t, StructCompType(fields))))
      }
    }
    ArrayCompType(ft) => {
      match self.walk_fieldtype(t, ft) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, ft))) => Ok(Some((t, ArrayCompType(ft))))
      }
    }
  }
}


pub fn[T] ModuleTransformer::walk_fieldtype(
  self : ModuleTransformer[T],
  t : T,
  ft : FieldType,
) -> TransformerResult[T, FieldType] {
  match self.on_fieldtype {
    Some(f) =>
      match f(t, ft) {
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
      match f(t, st) {
        Err(e) => Err(e)
        Ok(None) => self.walk_storagetype_default(t, st)
        ok => ok
      }
    None => self.walk_storagetype_default(t, st)
  }
}

pub fn[T] ModuleTransformer::walk_storagetype_default(
  self : ModuleTransformer[T],
  t : T,
  st : StorageType,
) -> TransformerResult[T, StorageType] {
  match st {
    ValTypeStorageType(vt) => {
      match self.walk_valtype(t, vt) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, vt))) => Ok(Some((t, ValTypeStorageType(vt))))
      }
    }
    PackTypeStorageType(_) => Ok(None)
  }
}

pub fn[T] ModuleTransformer::walk_globalsec(
  self : ModuleTransformer[T],
  t : T,
  gs : GlobalSec,
) -> TransformerResult[T, GlobalSec] {
  match self.on_globalsec {
    Some(f) =>
      match f(t, gs) {
        Err(e) => Err(e)
        Ok(None) => self.walk_globalsec_default(t, gs)
        ok => ok
      }
    None => self.walk_globalsec_default(t, gs)
  }
}

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

pub fn[T] ModuleTransformer::walk_global(
  self : ModuleTransformer[T],
  t : T,
  g : Global,
) -> TransformerResult[T, Global] {
  match self.on_global {
    Some(f) =>
      match f(t, g) {
        Err(e) => Err(e)
        Ok(None) => self.walk_global_default(t, g)
        ok => ok
      }
    None => self.walk_global_default(t, g)
  }
}

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

pub fn[T] ModuleTransformer::walk_globaltype(
  self : ModuleTransformer[T],
  t : T,
  gt : GlobalType,
) -> TransformerResult[T, GlobalType] {
  match self.on_globaltype {
    Some(f) =>
      match f(t, gt) {
        Err(e) => Err(e)
        Ok(None) => self.walk_globaltype_default(t, gt)
        ok => ok
      }
    None => self.walk_globaltype_default(t, gt)
  }
}
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

pub fn[T] ModuleTransformer::walk_elemkind(
  self : ModuleTransformer[T],
  t : T,
  ek : ElemKind,
) -> TransformerResult[T, ElemKind] {
  match self.on_elemkind {
    Some(f) =>
      match f(t, ek) {
        Err(e) => Err(e)
        Ok(None) => self.walk_elemkind_default(t, ek)
        ok => ok
      }
    None => self.walk_elemkind_default(t, ek)
  }
}

pub fn[T] ModuleTransformer::walk_elemkind_default(
  self : ModuleTransformer[T],
  t : T,
  kind : ElemKind,
) -> TransformerResult[T, ElemKind] {
  match kind {
    FuncsElemKind(idxs) => {
      match self.walk_array(t, ModuleTransformer::walk_funcidx, idxs) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, idxs))) => Ok(Some((t, FuncsElemKind(idxs))))
      }
    }
    FuncExprsElemKind(exprs) => {
      match self.walk_array(t, ModuleTransformer::walk_expr, exprs) {
        Err(e) => Err(e)
        Ok(None) => Ok(None)
        Ok(Some((t, exprs))) => Ok(Some((t, FuncExprsElemKind(exprs))))
      }
    }
    TypedExprsElemKind(rt, exprs) => {
      let (t, rt) = match self.walk_reftype(t, rt) {
        Err(e) => return Err(e)
        Ok(None) => (t, rt)
        Ok(Some((t, rt))) => (t, rt)
      }
      let (t, exprs) = match self.walk_array(t, ModuleTransformer::walk_expr, exprs) {
        Err(e) => return Err(e)
        Ok(None) => (t, exprs)
        Ok(Some((t, exprs))) => (t, exprs)
      }
      Ok(Some((t, TypedExprsElemKind(rt, exprs))))
    }
  }
}

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

pub fn[T] ModuleTransformer::walk_funcsec(
  self : ModuleTransformer[T],
  t : T,
  fs : FuncSec,
) -> TransformerResult[T, FuncSec] {
  match self.on_funcsec {
    Some(f) =>
      match f(t, fs) {
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
