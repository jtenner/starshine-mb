///|
// Module roots and retained type dependencies share one monotone work queue.
// A type enters the queue exactly once; source arrays are never rewritten here.
priv struct DfeTypeRefs {
  live : Array[Bool]
  pending : Array[Int]
}

///|
fn dfe_type_refs_mark_type_idx(idx : @lib.TypeIdx, used : DfeTypeRefs) -> Unit {
  match idx {
    @lib.TypeIdx(raw) => {
      let slot = raw.reinterpret_as_int()
      if slot >= 0 && slot < used.live.length() && !used.live[slot] {
        used.live[slot] = true
        used.pending.push(slot)
      }
    }
    @lib.RecIdx(_) => ()
  }
}

///|
fn dfe_type_refs_mark_heap_type(ht : @lib.HeapType, used : DfeTypeRefs) -> Unit {
  match ht {
    @lib.HeapType(type_idx) => dfe_type_refs_mark_type_idx(type_idx, used)
    @lib.DefTypeHeapType(@lib.DefType(rec_type, _)) =>
      dfe_type_refs_rec_type(rec_type, used)
    _ => ()
  }
}

///|
fn dfe_type_refs_mark_ref_type(rt : @lib.RefType, used : DfeTypeRefs) -> Unit {
  match rt {
    @lib.HeapTypeRefType(_, _, ht) => dfe_type_refs_mark_heap_type(ht, used)
    _ => ()
  }
}

///|
fn dfe_type_refs_mark_val_type(vt : @lib.ValType, used : DfeTypeRefs) -> Unit {
  match vt {
    @lib.RefTypeValType(rt) => dfe_type_refs_mark_ref_type(rt, used)
    _ => ()
  }
}

///|
fn dfe_type_refs_mark_table_type(
  tt : @lib.TableType,
  used : DfeTypeRefs,
) -> Unit {
  let @lib.TableType(rt, _) = tt
  dfe_type_refs_mark_ref_type(rt, used)
}

///|
fn dfe_type_refs_mark_global_type(
  gt : @lib.GlobalType,
  used : DfeTypeRefs,
) -> Unit {
  let @lib.GlobalType(vt, _) = gt
  dfe_type_refs_mark_val_type(vt, used)
}

///|
fn dfe_type_refs_mark_block_type(
  bt : @lib.BlockType,
  used : DfeTypeRefs,
) -> Unit {
  match bt {
    @lib.TypeIdxBlockType(type_idx) =>
      dfe_type_refs_mark_type_idx(type_idx, used)
    @lib.ValTypeBlockType(val_type) =>
      dfe_type_refs_mark_val_type(val_type, used)
    _ => ()
  }
}

///|
fn dfe_type_refs_instrs(
  instrs : Array[@lib.Instruction],
  used : DfeTypeRefs,
) -> Unit {
  // Match the reference-bearing forms handled by DFE's existing remapper.
  // Any expansion of that surface must update collection and rewriting together.
  for instr in instrs {
    match instr {
      @lib.Block(block_type, @lib.Expr(body))
      | @lib.Loop(block_type, @lib.Expr(body))
      | @lib.TryTable(block_type, _, @lib.Expr(body)) => {
        dfe_type_refs_mark_block_type(block_type, used)
        dfe_type_refs_instrs(body, used)
      }
      @lib.Try(block_type, @lib.Expr(body), catches, _) => {
        dfe_type_refs_mark_block_type(block_type, used)
        dfe_type_refs_instrs(body, used)
        for catch_ in catches {
          let @lib.Expr(catch_body) = match catch_ {
            @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
              catch_body
          }
          dfe_type_refs_instrs(catch_body, used)
        }
      }
      @lib.If(block_type, then_body, else_body) => {
        dfe_type_refs_mark_block_type(block_type, used)
        dfe_type_refs_instrs(then_body, used)
        match else_body {
          Some(body) => dfe_type_refs_instrs(body, used)
          None => ()
        }
      }
      @lib.CallIndirect(type_idx, _)
      | @lib.ReturnCallIndirect(type_idx, _)
      | @lib.CallRef(type_idx)
      | @lib.ReturnCallRef(type_idx)
      | @lib.StructNew(type_idx)
      | @lib.StructNewDefault(type_idx)
      | @lib.StructNewDesc(type_idx)
      | @lib.StructNewDefaultDesc(type_idx)
      | @lib.ArrayNew(type_idx)
      | @lib.ArrayNewDefault(type_idx)
      | @lib.ArrayNewFixed(type_idx, _)
      | @lib.ArrayNewData(type_idx, _)
      | @lib.ArrayNewElem(type_idx, _)
      | @lib.ArrayGet(type_idx)
      | @lib.ArrayGetS(type_idx)
      | @lib.ArrayGetU(type_idx)
      | @lib.ArraySet(type_idx)
      | @lib.ArrayFill(type_idx)
      | @lib.ArrayInitData(type_idx, _)
      | @lib.ArrayInitElem(type_idx, _)
      | @lib.RefGetDesc(type_idx)
      | @lib.StructGet(type_idx, _)
      | @lib.StructGetS(type_idx, _)
      | @lib.StructGetU(type_idx, _)
      | @lib.StructAtomicSet(_, type_idx, _)
      | @lib.ArrayAtomicSet(_, type_idx)
      | @lib.StructAtomicGet(_, type_idx, _)
      | @lib.StructAtomicGetS(_, type_idx, _)
      | @lib.StructAtomicGetU(_, type_idx, _)
      | @lib.StructAtomicRmw(_, _, type_idx, _)
      | @lib.StructAtomicCmpxchg(_, type_idx, _)
      | @lib.StructSet(type_idx, _)
      | @lib.ArrayAtomicGet(_, type_idx)
      | @lib.ArrayAtomicGetS(_, type_idx)
      | @lib.ArrayAtomicGetU(_, type_idx)
      | @lib.ArrayAtomicRmw(_, _, type_idx)
      | @lib.ArrayAtomicCmpxchg(_, type_idx) =>
        dfe_type_refs_mark_type_idx(type_idx, used)
      @lib.ArrayCopy(source_type, target_type) => {
        dfe_type_refs_mark_type_idx(source_type, used)
        dfe_type_refs_mark_type_idx(target_type, used)
      }
      @lib.Select(Some(types)) =>
        for val_type in types {
          dfe_type_refs_mark_val_type(val_type, used)
        }
      @lib.RefNull(rt) => dfe_type_refs_mark_ref_type(rt, used)
      @lib.RefTest(_, _, ht)
      | @lib.RefCast(_, _, ht)
      | @lib.RefTestDesc(_, ht)
      | @lib.RefCastDescEq(_, _, ht) => dfe_type_refs_mark_heap_type(ht, used)
      @lib.BrOnCast(_, _, source_ht, target_ht)
      | @lib.BrOnCastFail(_, _, source_ht, target_ht) => {
        dfe_type_refs_mark_heap_type(source_ht, used)
        dfe_type_refs_mark_heap_type(target_ht, used)
      }
      _ => ()
    }
  }
}

///|
fn dfe_type_refs_field(field : @lib.FieldType, used : DfeTypeRefs) -> Unit {
  let @lib.FieldType(storage, _) = field
  match storage {
    @lib.ValTypeStorageType(value) => dfe_type_refs_mark_val_type(value, used)
    @lib.PackTypeStorageType(_) => ()
  }
}

///|
fn dfe_type_refs_subtype(subtype : @lib.SubType, used : DfeTypeRefs) -> Unit {
  for super_type in subtype.super_types() {
    dfe_type_refs_mark_type_idx(super_type, used)
  }
  match subtype.describes_type() {
    Some(idx) => dfe_type_refs_mark_type_idx(idx, used)
    None => ()
  }
  match subtype.descriptor_type() {
    Some(idx) => dfe_type_refs_mark_type_idx(idx, used)
    None => ()
  }
  match subtype.get_comptype() {
    @lib.FuncCompType(params, results) => {
      for value in params {
        dfe_type_refs_mark_val_type(value, used)
      }
      for value in results {
        dfe_type_refs_mark_val_type(value, used)
      }
    }
    @lib.ArrayCompType(field) => dfe_type_refs_field(field, used)
    @lib.StructCompType(fields) =>
      for field in fields {
        dfe_type_refs_field(field, used)
      }
    @lib.ContCompType(idx) => dfe_type_refs_mark_type_idx(idx, used)
  }
}

///|
fn dfe_type_refs_rec_type(rec_type : @lib.RecType, used : DfeTypeRefs) -> Unit {
  match rec_type {
    @lib.SingleRecType(subtype) => dfe_type_refs_subtype(subtype, used)
    @lib.GroupRecType(subtypes) =>
      for subtype in subtypes {
        dfe_type_refs_subtype(subtype, used)
      }
  }
}

///|
fn dfe_type_refs_expr(expr : @lib.Expr, used : DfeTypeRefs) -> Unit {
  let @lib.Expr(body) = expr
  dfe_type_refs_instrs(body, used)
}

///|
fn dfe_type_refs_module_roots(mod_ : @lib.Module, used : DfeTypeRefs) -> Unit {
  // Definitions are visited only after they become live. All executable and
  // declared roots, including initializer and offset expressions, are scanned.
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        let @lib.Import(_, _, extern_type) = import_
        match extern_type {
          @lib.FuncExternType(idx) | @lib.TagExternType(@lib.TagType(idx)) =>
            dfe_type_refs_mark_type_idx(idx, used)
          @lib.TableExternType(table_type) =>
            dfe_type_refs_mark_table_type(table_type, used)
          @lib.GlobalExternType(global_type) =>
            dfe_type_refs_mark_global_type(global_type, used)
          @lib.MemExternType(_) => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(indices)) =>
      for idx in indices {
        dfe_type_refs_mark_type_idx(idx, used)
      }
    None => ()
  }
  match mod_.tag_sec {
    Some(@lib.TagSec(tags)) =>
      for tag in tags {
        let @lib.TagType(idx) = tag
        dfe_type_refs_mark_type_idx(idx, used)
      }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        let @lib.Table(table_type, init) = table
        dfe_type_refs_mark_table_type(table_type, used)
        match init {
          Some(expr) => dfe_type_refs_expr(expr, used)
          None => ()
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(global_type, init) = global
        dfe_type_refs_mark_global_type(global_type, used)
        dfe_type_refs_expr(init, used)
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        match mode {
          @lib.Active(_, expr) => dfe_type_refs_expr(expr, used)
          _ => ()
        }
        match kind {
          @lib.TypedExprsElemKind(ref_type, exprs) => {
            dfe_type_refs_mark_ref_type(ref_type, used)
            for expr in exprs {
              dfe_type_refs_expr(expr, used)
            }
          }
          @lib.FuncExprsElemKind(exprs) =>
            for expr in exprs {
              dfe_type_refs_expr(expr, used)
            }
          @lib.FuncsElemKind(_) => ()
        }
      }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, body) = func
        for run in locals.runs() {
          dfe_type_refs_mark_val_type(run.val_type(), used)
        }
        dfe_type_refs_expr(body, used)
      }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) =>
      for data in datas {
        let @lib.Data(mode, _) = data
        match mode {
          @lib.Active(_, expr) => dfe_type_refs_expr(expr, used)
          @lib.Passive => ()
        }
      }
    None => ()
  }
}
