///|
/// Increment all indices of a specific type to cause out-of-bounds errors
fn make_funcidx_oob_transformer(
  offset : UInt,
) -> ModuleTransformer[Unit, String] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::new().on_funcidx_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    idx : FuncIdx,
  ) -> VisitAction[Unit, FuncIdx, String] {
    let FuncIdx(i) = idx
    // Make idempotent: if already large, don't transform again
    if i >= target {
      unchanged()
    } else {
      change((), FuncIdx::new(i + target))
    }
  })
}

///|
fn make_typeidx_oob_transformer(
  offset : UInt,
) -> ModuleTransformer[Unit, String] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::new().on_typeidx_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    idx : TypeIdx,
  ) -> VisitAction[Unit, TypeIdx, String] {
    match idx {
      TypeIdx(i) =>
        if i >= target {
          unchanged()
        } else {
          change((), TypeIdx::new(i + target))
        }
      RecIdx(i) =>
        if i >= target {
          unchanged()
        } else {
          change((), TypeIdx::rec(i + target))
        }
    }
  })
}

///|
fn make_localidx_oob_transformer(
  offset : UInt,
) -> ModuleTransformer[Unit, String] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::new().on_localidx_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    idx : LocalIdx,
  ) -> VisitAction[Unit, LocalIdx, String] {
    let LocalIdx(i) = idx
    if i >= target {
      unchanged()
    } else {
      change((), LocalIdx::new(i + target))
    }
  })
}

///|
fn make_globalidx_oob_transformer(
  offset : UInt,
) -> ModuleTransformer[Unit, String] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::new().on_globalidx_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    idx : GlobalIdx,
  ) -> VisitAction[Unit, GlobalIdx, String] {
    let GlobalIdx(i) = idx
    if i >= target {
      unchanged()
    } else {
      change((), GlobalIdx::new(i + target))
    }
  })
}

///|
fn make_labelidx_oob_transformer(
  offset : UInt,
) -> ModuleTransformer[Unit, String] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::new().on_labelidx_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    idx : LabelIdx,
  ) -> VisitAction[Unit, LabelIdx, String] {
    let LabelIdx(i) = idx
    if i >= target {
      unchanged()
    } else {
      change((), LabelIdx::new(i + target))
    }
  })
}

///|
fn make_tableidx_oob_transformer(
  offset : UInt,
) -> ModuleTransformer[Unit, String] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::new().on_tableidx_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    idx : TableIdx,
  ) -> VisitAction[Unit, TableIdx, String] {
    let TableIdx(i) = idx
    if i >= target {
      unchanged()
    } else {
      change((), TableIdx::new(i + target))
    }
  })
}

///|
fn make_memidx_oob_transformer(
  offset : UInt,
) -> ModuleTransformer[Unit, String] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::new().on_memidx_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    idx : MemIdx,
  ) -> VisitAction[Unit, MemIdx, String] {
    let MemIdx(i) = idx
    if i >= target {
      unchanged()
    } else {
      change((), MemIdx::new(i + target))
    }
  })
}

///|
fn make_dataidx_oob_transformer(
  offset : UInt,
) -> ModuleTransformer[Unit, String] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::new().on_dataidx_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    idx : DataIdx,
  ) -> VisitAction[Unit, DataIdx, String] {
    let DataIdx(i) = idx
    if i >= target {
      unchanged()
    } else {
      change((), DataIdx::new(i + target))
    }
  })
}

///|
fn make_elemidx_oob_transformer(
  offset : UInt,
) -> ModuleTransformer[Unit, String] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::new().on_elemidx_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    idx : ElemIdx,
  ) -> VisitAction[Unit, ElemIdx, String] {
    let ElemIdx(i) = idx
    if i >= target {
      unchanged()
    } else {
      change((), ElemIdx::new(i + target))
    }
  })
}

///|
fn make_tagidx_oob_transformer(
  offset : UInt,
) -> ModuleTransformer[Bool, String] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::new().on_tagidx_evt(fn(
    _ : ModuleTransformer[Bool, String],
    _ctx : Bool,
    idx : TagIdx,
  ) -> VisitAction[Bool, TagIdx, String] {
    let TagIdx(i) = idx
    if i >= target {
      unchanged()
    } else {
      change(true, TagIdx::new(i + target))
    }
  })
}

///|
/// Use Bool context to track if we've already corrupted an expr
fn make_type_corruption_transformer() -> ModuleTransformer[Bool, String] {
  ModuleTransformer::new().on_expr_evt(fn(
    _ : ModuleTransformer[Bool, String],
    done : Bool,
    expr : Expr,
  ) -> VisitAction[Bool, Expr, String] {
    if done {
      return unchanged()
    }
    let Expr(instrs) = expr
    if instrs.length() == 0 {
      return unchanged()
    }
    // Insert i32.const followed by i64.add - guaranteed type error
    let new_instrs = [Instruction::i32_const(I32(42)), Instruction::i64_add()]
    for i in instrs {
      new_instrs.push(i)
    }
    change(true, Expr::new(new_instrs))
  })
}

///|
fn make_numtype_swap_transformer() -> ModuleTransformer[Unit, String] {
  ModuleTransformer::new().on_valtype_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    vt : ValType,
  ) -> VisitAction[Unit, ValType, String] {
    match vt {
      NumTypeValType(I32NumType) => change((), ValType::f64())
      NumTypeValType(I64NumType) => change((), ValType::f32())
      NumTypeValType(F32NumType) => change((), ValType::i64())
      NumTypeValType(F64NumType) => change((), ValType::i32())
      _ => unchanged()
    }
  })
}

///|
fn make_heaptype_swap_transformer() -> ModuleTransformer[Unit, String] {
  let next_abs_heaptype = fn(ht : AbsHeapType) -> AbsHeapType {
    match ht {
      FuncAbsHeapType => AbsHeapType::extern_()
      ExternAbsHeapType => AbsHeapType::any()
      ExnAbsHeapType => AbsHeapType::func()
      AnyAbsHeapType => AbsHeapType::eq()
      EqAbsHeapType => AbsHeapType::i31()
      I31AbsHeapType => AbsHeapType::struct_()
      StructAbsHeapType => AbsHeapType::array()
      ArrayAbsHeapType => AbsHeapType::exn()
      NoneAbsHeapType => AbsHeapType::no_func()
      NoFuncAbsHeapType => AbsHeapType::func()
      NoExternAbsHeapType => AbsHeapType::extern_()
      NoExnAbsHeapType => AbsHeapType::any()
      StringAbsHeapType => AbsHeapType::func()
    }
  }
  ModuleTransformer::new().on_heaptype_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    ht : HeapType,
  ) -> VisitAction[Unit, HeapType, String] {
    let swapped = match ht {
      AbsHeapTypeHeapType(aht) => HeapType::abs(next_abs_heaptype(aht))
      HeapType(_) => HeapType::abs(AbsHeapType::func())
      DefTypeHeapType(_) => HeapType::abs(AbsHeapType::extern_())
    }
    if swapped == ht {
      unchanged()
    } else {
      change((), swapped)
    }
  })
}

///|
/// Aggressive nullability flip - make ALL ref types non-nullable
/// This will fail if there's any ref.null, table without init, or nullable parameter
fn make_nullability_flip_transformer() -> ModuleTransformer[Unit, String] {
  ModuleTransformer::new()
  .on_reftype_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    rt : RefType,
  ) -> VisitAction[Unit, RefType, String] {
    match rt {
      // Force all ref types to be non-nullable
      HeapTypeRefType(true, exact, ht) =>
        change((), RefType::new(false, ht, exact~))
      // Already non-nullable - convert to bottom type to cause more errors
      HeapTypeRefType(false, _, AbsHeapTypeHeapType(NoneAbsHeapType)) =>
        unchanged()
      HeapTypeRefType(false, _, AbsHeapTypeHeapType(NoFuncAbsHeapType)) =>
        unchanged()
      HeapTypeRefType(false, _, AbsHeapTypeHeapType(NoExternAbsHeapType)) =>
        unchanged()
      HeapTypeRefType(false, _, ht) =>
        // Change to bottom type of same hierarchy - very restrictive
        match ht {
          AbsHeapTypeHeapType(FuncAbsHeapType)
          | AbsHeapTypeHeapType(NoFuncAbsHeapType) =>
            change(
              (),
              RefType::new(false, HeapType::abs(AbsHeapType::no_func())),
            )
          AbsHeapTypeHeapType(ExternAbsHeapType)
          | AbsHeapTypeHeapType(NoExternAbsHeapType) =>
            change(
              (),
              RefType::new(false, HeapType::abs(AbsHeapType::no_extern())),
            )
          AbsHeapTypeHeapType(ExnAbsHeapType)
          | AbsHeapTypeHeapType(NoExnAbsHeapType) =>
            change(
              (),
              RefType::new(false, HeapType::abs(AbsHeapType::no_exn())),
            )
          _ =>
            // For any/eq/struct/array/i31 hierarchy, use none
            change((), RefType::new(false, HeapType::abs(AbsHeapType::none())))
        }
      AbsHeapTypeRefType(aht) =>
        // These shorthands are nullable, make them non-null with explicit form
        change((), RefType::new(false, HeapType::abs(aht)))
    }
  })
  .on_instruction_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    instr : Instruction,
  ) -> VisitAction[Unit, Instruction, String] {
    match instr {
      // ref.null produces nullable ref, but if types expect non-null, this fails
      // Replace with something that definitely won't typecheck
      RefNull(_) => change((), Instruction::i32_const(I32(0))) // Completely wrong type
      RefFunc(_) => change((), Instruction::i64_const(I64(0L))) // Wrong type for funcref
      RefIsNull => change((), Instruction::i64_const(I64(0L))) // Expects ref, we removed it
      _ => unchanged()
    }
  })
}

///|
/// Alternative strategy: corrupt ONLY type declarations, not code
/// This creates inconsistency between what's declared and what's executed
fn make_signature_corruption_transformer() -> ModuleTransformer[Unit, String] {
  ModuleTransformer::new().on_comptype_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    ct : CompType,
  ) -> VisitAction[Unit, CompType, String] {
    match ct {
      FuncCompType(params, results) => {
        // Add extra parameters that callers won't provide
        let new_params = params.copy()
        new_params.push(ValType::i64())
        new_params.push(ValType::f64())
        // Change result types
        let new_results = results.map(fn(vt) {
          match vt {
            NumTypeValType(I32NumType) => @lib.ValType::f64()
            NumTypeValType(I64NumType) => ValType::f32()
            NumTypeValType(F32NumType) => ValType::i64()
            NumTypeValType(F64NumType) => ValType::i32()
            other => other
          }
        })
        change((), CompType::func(new_params, new_results))
      }
      StructCompType(fields) => {
        // Change field types
        let new_fields = fields.map(fn(ft) {
          let FieldType(st, mutability) = ft
          match st {
            ValTypeStorageType(NumTypeValType(I32NumType)) =>
              FieldType::new(StorageType::val_type(ValType::f64()), mutability)
            ValTypeStorageType(NumTypeValType(I64NumType)) =>
              FieldType::new(StorageType::val_type(ValType::f32()), mutability)
            _ => ft
          }
        })
        change((), CompType::struct_(new_fields))
      }
      ArrayCompType(FieldType(st, mutability)) => {
        let new_st = match st {
          ValTypeStorageType(NumTypeValType(I32NumType)) =>
            StorageType::val_type(ValType::f64())
          ValTypeStorageType(NumTypeValType(I64NumType)) =>
            StorageType::val_type(ValType::f32())
          _ => st
        }
        change((), CompType::array(FieldType::new(new_st, mutability)))
      }
    }
  })
}

///|
/// Strategy that corrupts global initializers to not match declared types
fn make_global_init_mismatch_transformer() -> ModuleTransformer[Unit, String] {
  ModuleTransformer::new().on_global_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    g : Global,
  ) -> VisitAction[Unit, Global, String] {
    let Global(GlobalType(vt, mutable), _init) = g
    // Create an init expression with wrong type
    let wrong_init = match vt {
      NumTypeValType(I32NumType) =>
        Expr::new([Instruction::f64_const(F64(0.0))])
      NumTypeValType(I64NumType) =>
        Expr::new([Instruction::f32_const(F32(0.0))])
      NumTypeValType(F32NumType) => Expr::new([Instruction::i64_const(I64(0L))])
      NumTypeValType(F64NumType) => Expr::new([Instruction::i32_const(I32(0))])
      RefTypeValType(_) => Expr::new([Instruction::i32_const(I32(0))]) // Definitely wrong
      VecTypeValType => Expr::new([Instruction::i32_const(I32(0))])
      BotValType => return unchanged()
    }
    change((), Global::new(GlobalType::new(vt, mutable), wrong_init))
  })
}

///|
/// Strategy that corrupts table initializers
fn make_table_init_mismatch_transformer() -> ModuleTransformer[Unit, String] {
  ModuleTransformer::new().on_table_evt(fn(
    _ : ModuleTransformer[Unit, String],
    _ctx : Unit,
    t : Table,
  ) -> VisitAction[Unit, Table, String] {
    let Table(tt, _init) = t
    // Set init to wrong type expression
    change(
      (),
      Table::new(tt, Some(Expr::new([Instruction::i32_const(I32(42))]))),
    )
  })
}

///|
/// More aggressive drop insertion - prepend Drop to cause stack underflow
fn make_drop_insertion_transformer() -> ModuleTransformer[Bool, String] {
  ModuleTransformer::new().on_expr_evt(fn(
    _ : ModuleTransformer[Bool, String],
    done : Bool,
    expr : Expr,
  ) -> VisitAction[Bool, Expr, String] {
    if done {
      return unchanged()
    }
    let Expr(instrs) = expr
    if instrs.length() == 0 {
      return unchanged()
    }
    // Prepend Drop instructions to cause stack underflow
    let new_instrs : Array[Instruction] = [
      Instruction::drop(),
      Instruction::drop(),
      Instruction::drop(),
    ]
    for i in instrs {
      new_instrs.push(i)
    }
    change(true, Expr::new(new_instrs))
  })
}

///|
/// Remove block ends / corrupt block structure - use Bool to do once
fn make_block_corruption_transformer() -> ModuleTransformer[Bool, String] {
  ModuleTransformer::new().on_expr_evt(fn(
    _ : ModuleTransformer[Bool, String],
    done : Bool,
    expr : Expr,
  ) -> VisitAction[Bool, Expr, String] {
    if done {
      return unchanged()
    }
    let Expr(instrs) = expr
    if instrs.length() > 0 {
      change(true, Expr::new(instrs.iter().take(instrs.length() - 1).collect()))
    } else {
      unchanged()
    }
  })
}

///|
fn corrupt_blocktype(bt : BlockType) -> BlockType {
  match bt {
    VoidBlockType => BlockType::val_type(ValType::i32())
    ValTypeBlockType(NumTypeValType(I32NumType)) =>
      BlockType::val_type(ValType::i64())
    ValTypeBlockType(NumTypeValType(I64NumType)) =>
      BlockType::val_type(ValType::i32())
    ValTypeBlockType(_) => BlockType::void_()
    TypeIdxBlockType(TypeIdx(i)) => BlockType::type_idx(TypeIdx::new(i + 1))
    TypeIdxBlockType(RecIdx(i)) => BlockType::type_idx(TypeIdx::rec(i + 1))
  }
}

///|
/// Block type mismatch - insert blocks with wrong types or corrupt existing ones
fn make_blocktype_mismatch_transformer() -> ModuleTransformer[Bool, String] {
  ModuleTransformer::new().on_instruction_evt(fn(
    _ : ModuleTransformer[Bool, String],
    done : Bool,
    ins : Instruction,
  ) -> VisitAction[Bool, Instruction, String] {
    if done {
      return unchanged()
    }
    match ins {
      // Value-producing instructions: wrap in block claiming no result
      // Body produces value, block claims nothing -> mismatch
      I32Const(_)
      | I64Const(_)
      | F32Const(_)
      | F64Const(_)
      | V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
        change(true, Instruction::block(BlockType::void_(), Expr::new([ins])))

      // Nop/Drop: wrap in block claiming it produces i32
      // Body produces nothing, block claims i32 -> mismatch
      Nop | Drop =>
        change(
          true,
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([ins]),
          ),
        )

      // LocalGet produces a value - wrap in block claiming different type
      LocalGet(_) =>
        change(
          true,
          Instruction::block(
            BlockType::val_type(ValType::i64()),
            Expr::new([ins]),
          ),
        )

      // GlobalGet produces a value - wrap in block claiming empty
      GlobalGet(_) =>
        change(true, Instruction::block(BlockType::void_(), Expr::new([ins])))

      // Existing control flow: corrupt their block type
      Block(bt, body) =>
        change(true, Instruction::block(corrupt_blocktype(bt), body))
      Loop(bt, body) =>
        change(true, Instruction::loop_(corrupt_blocktype(bt), body))
      If(bt, then_body, else_body) =>
        change(
          true,
          Instruction::if_(corrupt_blocktype(bt), then_body, else_body),
        )
      TryTable(bt, catches, body) =>
        change(
          true,
          Instruction::try_table(corrupt_blocktype(bt), catches, body),
        )

      // RefNull produces a ref - wrap in block claiming i32
      RefNull(_) =>
        change(
          true,
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([ins]),
          ),
        )

      // RefFunc produces a ref - wrap in block claiming empty
      RefFunc(_) =>
        change(true, Instruction::block(BlockType::void_(), Expr::new([ins])))

      // StructNewDefault produces a ref - wrap in block claiming i32
      StructNewDefault(_) =>
        change(
          true,
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new([ins]),
          ),
        )

      // ArrayNewDefault needs i32 on stack, produces ref
      // Can't easily wrap this one without also providing the i32

      _ => unchanged()
    }
  })
}

///|
priv enum InvalidationStrategy {
  FuncIdxOOB(UInt)
  TypeIdxOOB(UInt)
  LocalIdxOOB(UInt)
  GlobalIdxOOB(UInt)
  LabelIdxOOB(UInt)
  TableIdxOOB(UInt)
  MemIdxOOB(UInt)
  DataIdxOOB(UInt)
  ElemIdxOOB(UInt)
  TagIdxOOB(UInt)
  StartIdxOOB(UInt)
  DuplicateExportName
  NumTypeSwap
  NullabilityFlip
  HeapTypeSwap
  InstructionTypeMismatch
  BlockTypeMismatch
  DropInsertion
  BlockCorruption
  SignatureCorruption
  GlobalInitMismatch
  TableInitMismatch
}

///|
/// Apply strategy and return transformed module
fn apply_strategy(
  strategy : InvalidationStrategy,
  mod_ : Module,
) -> (Bool, Module) {
  match strategy {
    FuncIdxOOB(n) =>
      match make_funcidx_oob_transformer(n).walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    TypeIdxOOB(n) =>
      match make_typeidx_oob_transformer(n).walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    LocalIdxOOB(n) =>
      match make_localidx_oob_transformer(n).walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    GlobalIdxOOB(n) =>
      match make_globalidx_oob_transformer(n).walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    LabelIdxOOB(n) =>
      match make_labelidx_oob_transformer(n).walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    TableIdxOOB(n) =>
      match make_tableidx_oob_transformer(n).walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    MemIdxOOB(n) =>
      match make_memidx_oob_transformer(n).walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    DataIdxOOB(n) =>
      match make_dataidx_oob_transformer(n).walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    ElemIdxOOB(n) =>
      match make_elemidx_oob_transformer(n).walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    TagIdxOOB(n) =>
      match make_tagidx_oob_transformer(n).walk_module(false, mod_) {
        Ok((new_mod, changed)) if changed => (true, new_mod)
        _ => (false, mod_)
      }
    StartIdxOOB(n) => {
      let target = n + 0x7FFFFFFF
      let invalid = mod_.with_start_sec(StartSec::new(FuncIdx::new(target)))
      (invalid != mod_, invalid)
    }
    DuplicateExportName =>
      match mod_.export_sec {
        Some(ExportSec(exports)) if exports.length() > 0 => {
          let dup = exports[0]
          let next = exports.copy()
          next.push(dup)
          let invalid = mod_.with_export_sec(ExportSec::new(next))
          (true, invalid)
        }
        _ => (false, mod_)
      }
    NumTypeSwap =>
      match make_numtype_swap_transformer().walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    NullabilityFlip =>
      match make_nullability_flip_transformer().walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    HeapTypeSwap =>
      match make_heaptype_swap_transformer().walk_module(false, mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    InstructionTypeMismatch =>
      match make_type_corruption_transformer().walk_module(false, mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    BlockTypeMismatch =>
      match make_blocktype_mismatch_transformer().walk_module(false, mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    DropInsertion =>
      match make_drop_insertion_transformer().walk_module(false, mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    BlockCorruption =>
      match make_block_corruption_transformer().walk_module(false, mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    SignatureCorruption =>
      match make_signature_corruption_transformer().walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    GlobalInitMismatch =>
      match make_global_init_mismatch_transformer().walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
    TableInitMismatch =>
      match make_table_init_mismatch_transformer().walk_module((), mod_) {
        Ok((new_mod, _)) => (new_mod != mod_, new_mod)
        _ => (false, mod_)
      }
  }
}

///|
fn InvalidationStrategy::to_string(self : InvalidationStrategy) -> String {
  match self {
    FuncIdxOOB(_) => "FuncIdxOOB"
    TypeIdxOOB(_) => "TypeIdxOOB"
    LocalIdxOOB(_) => "LocalIdxOOB"
    GlobalIdxOOB(_) => "GlobalIdxOOB"
    LabelIdxOOB(_) => "LabelIdxOOB"
    TableIdxOOB(_) => "TableIdxOOB"
    MemIdxOOB(_) => "MemIdxOOB"
    DataIdxOOB(_) => "DataIdxOOB"
    ElemIdxOOB(_) => "ElemIdxOOB"
    TagIdxOOB(_) => "TagIdxOOB"
    StartIdxOOB(_) => "StartIdxOOB"
    DuplicateExportName => "DuplicateExportName"
    NumTypeSwap => "NumTypeSwap"
    NullabilityFlip => "NullabilityFlip"
    HeapTypeSwap => "HeapTypeSwap"
    InstructionTypeMismatch => "InstructionTypeMismatch"
    BlockTypeMismatch => "BlockTypeMismatch"
    DropInsertion => "DropInsertion"
    BlockCorruption => "BlockCorruption"
    SignatureCorruption => "SignatureCorruption"
    GlobalInitMismatch => "GlobalInitMismatch"
    TableInitMismatch => "TableInitMismatch"
  }
}

///|
fn validate_invalid_fuzz_expected_issue(
  strategy : InvalidationStrategy,
  issue : ValidationIssue,
) -> Bool {
  match strategy {
    DuplicateExportName =>
      match issue {
        ExportSection(_) => true
        _ => false
      }
    NumTypeSwap =>
      match issue {
        FunctionSection(_) => true
        TypeSection(_) => true
        GlobalSection(_) => true
        FunctionBody(_) => true
        _ => false
      }
    NullabilityFlip =>
      match issue {
        FunctionSection(_) => true
        TypeSection(_) => true
        GlobalSection(_) => true
        FunctionBody(_) => true
        _ => false
      }
    HeapTypeSwap =>
      match issue {
        FunctionSection(_) => true
        TypeSection(_) => true
        FunctionBody(_) => true
        _ => false
      }
    InstructionTypeMismatch => match issue {
      FunctionBody(_) => true
      _ => false
    }
    BlockTypeMismatch => match issue {
      FunctionBody(_) => true
      _ => false
    }
    DropInsertion => match issue {
      FunctionBody(_) => true
      _ => false
    }
    BlockCorruption => match issue {
      FunctionBody(_) => true
      _ => false
    }
    SignatureCorruption =>
      match issue {
        TypeSection(_) => true
        FunctionSection(_) => true
        _ => false
      }
    GlobalInitMismatch =>
      match issue {
        GlobalSection(_) => true
        _ => false
      }
    TableInitMismatch =>
      match issue {
        TableSection(_) => true
        _ => false
      }
    FuncIdxOOB(_)
    | TypeIdxOOB(_)
    | LocalIdxOOB(_)
    | GlobalIdxOOB(_)
    | LabelIdxOOB(_)
    | TableIdxOOB(_)
    | MemIdxOOB(_)
    | DataIdxOOB(_)
    | ElemIdxOOB(_)
    | TagIdxOOB(_)
    | StartIdxOOB(_) =>
      match issue {
      FunctionSection(_) => true
      FunctionBody(_) => true
      TypeSection(_) => true
      GlobalSection(_) => true
      TableSection(_) => true
      TagSection(_) => true
      MemorySection(_) => true
      DataSection(_) => true
      DataCountSection(_) => true
      StartSection(_) => true
      ExportSection(_) => true
      _ => false
    }
  }
}

///|
fn validate_invalid_fuzz_expected_issue_family(
  strategy : InvalidationStrategy,
) -> String {
  match strategy {
    DuplicateExportName => "ExportSection"
    NumTypeSwap => "FunctionSection|TypeSection|GlobalSection|FunctionBody"
    NullabilityFlip => "FunctionSection|TypeSection|GlobalSection|FunctionBody"
    HeapTypeSwap => "FunctionSection|TypeSection|FunctionBody"
    InstructionTypeMismatch => "FunctionBody"
    BlockTypeMismatch => "FunctionBody"
    DropInsertion => "FunctionBody"
    BlockCorruption => "FunctionBody"
    SignatureCorruption => "TypeSection|FunctionSection"
    GlobalInitMismatch => "GlobalSection"
    TableInitMismatch => "TableSection"
    FuncIdxOOB(_)
    | TypeIdxOOB(_)
    | LocalIdxOOB(_)
    | GlobalIdxOOB(_)
    | LabelIdxOOB(_)
    | TableIdxOOB(_)
    | MemIdxOOB(_)
    | DataIdxOOB(_)
    | ElemIdxOOB(_)
    | TagIdxOOB(_)
    | StartIdxOOB(_) => "FunctionSection|FunctionBody|TypeSection|GlobalSection|TableSection|TagSection|MemorySection|DataSection|DataCountSection|StartSection|ExportSection|ImportSection"
  }
}

///|
/// Result of testing a single strategy
fn fuzz_invalid_module_with_coverage(
  valid_module : Module,
  strategy : InvalidationStrategy,
) -> (String, String, Int, Int, Int, Int, String?, ValidationIssue?) {
  let strategy_name = strategy.to_string()
  let expected_issue = validate_invalid_fuzz_expected_issue_family(strategy)
  let (was_modified, invalid_module) = apply_strategy(strategy, valid_module)

  // Not tested if no modification was made OR module unchanged
  if not(was_modified) || invalid_module == valid_module {
    return (strategy_name, expected_issue, 0, 0, 0, 0, None, None)
  }
  match validate_module(invalid_module) {
    Ok(_) => (
      strategy_name,
      expected_issue,
      1,
      1,
      0,
      0,
      None,
      None,
    )
    Err(err) => {
      let issue = validation_error_diagnostic(err).issue
      if validate_invalid_fuzz_expected_issue(strategy, issue) {
        (strategy_name, expected_issue, 1, 1, 1, 1, None, None)
      } else {
        (
          strategy_name,
          expected_issue,
          1,
          1,
          1,
          0,
          Some("\{invalid_module}"),
          Some(issue),
        )
      }
    }
  }
}

///|
fn fuzz_all_strategies_with_coverage(
  valid_module : Module,
) -> Array[(String, String, Int, Int, Int, Int, String?, ValidationIssue?)] {
  let strategies : Array[InvalidationStrategy] = validate_invalid_fuzz_strategies()
  strategies.map(fn(s) { fuzz_invalid_module_with_coverage(valid_module, s) })
}

///|
fn validate_invalid_fuzz_strategies() -> Array[InvalidationStrategy] {
  [
    FuncIdxOOB(1),
    FuncIdxOOB(100),
    TypeIdxOOB(1),
    TypeIdxOOB(100),
    LocalIdxOOB(1),
    LocalIdxOOB(100),
    GlobalIdxOOB(1),
    LabelIdxOOB(1),
    TableIdxOOB(1),
    MemIdxOOB(1),
    DataIdxOOB(1),
    ElemIdxOOB(1),
    TagIdxOOB(1),
    StartIdxOOB(1),
    DuplicateExportName,
    NumTypeSwap,
    NullabilityFlip,
    HeapTypeSwap,
    InstructionTypeMismatch,
    BlockTypeMismatch,
    DropInsertion,
    BlockCorruption,
    SignatureCorruption,
    GlobalInitMismatch,
    TableInitMismatch,
  ]
}

///|
fn validate_invalid_fuzz_ascii_lower(input : String) -> String {
  let out = StringBuilder::new()
  for c in input {
    if c >= 'A' && c <= 'Z' {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn validate_invalid_fuzz_strategy_names() -> Array[String] {
  validate_invalid_fuzz_strategies().map(fn(s) { s.to_string() })
}

///|
pub struct ValidateInvalidStrategyCounts {
  name : String
  attempted : Int
  mutated : Int
  rejected : Int
} derive(Eq, Show, Debug)

///|
pub struct ValidateInvalidFuzzStats {
  profile : String
  seed : UInt64
  module_attempts : Int
  modules_tested : Int
  strategy_counts : Array[ValidateInvalidStrategyCounts]
  strategies_with_low_rejection : Array[String]
} derive(Eq, Show, Debug)

///|
pub struct ValidateInvalidFuzzFailure {
  profile : String
  seed : UInt64
  module_attempt : Int
  strategy : String
  expected_issue : String
  actual_issue : String
  module_text : String
} derive(Eq, Show, Debug)

///|
fn validate_invalid_fuzz_profile_attempts(profile : String) -> Result[(String, Int), String] {
  let normalized = validate_invalid_fuzz_ascii_lower(profile.trim().to_string())
  let module_attempts = match normalized {
    "smoke" => 24
    "ci" => 200
    "stress" => 2000
    _ =>
      return Err(
        "unknown validate-invalid fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  Ok((normalized, module_attempts))
}

///|
fn run_validate_invalid_fuzz_with_modules(
  normalized : String,
  seed : UInt64,
  module_attempts : Int,
  pick_module : (Int, @splitmix.RandomState) -> @lib.Module?,
  on_failure? : ((ValidateInvalidFuzzFailure) -> Result[Unit, String])? = None,
) -> Result[ValidateInvalidFuzzStats, String] {
  let rnd = @splitmix.new(seed~)
  let strategy_names = validate_invalid_fuzz_strategy_names()
  let tested_count : Map[String, Int] = {}
  let mutated_count : Map[String, Int] = {}
  let rejected_count : Map[String, Int] = {}
  let matched_count : Map[String, Int] = {}
  for s in strategy_names {
    tested_count[s] = 0
    mutated_count[s] = 0
    rejected_count[s] = 0
    matched_count[s] = 0
  }
  let mut problems : Array[String] = []
  let mut modules_tested = 0
  let mut module_attempt = 0
  for _ in 0..<module_attempts {
    module_attempt += 1
    let valid_module = match pick_module(module_attempt, rnd) {
      Some(m) => m
      None => continue
    }
    modules_tested += 1
    let results = fuzz_all_strategies_with_coverage(valid_module)
    for result in results {
      let (
        strategy_name,
        expected_issue,
        attempted,
        mutated,
        rejected,
        matched,
        invalid_module_text,
        mismatch_issue,
      ) = result
      if matched == 0 {
        continue
      }
      match mismatch_issue {
        Some(mismatch_issue) => {
          let invalid_text = match invalid_module_text {
            Some(value) => value
            None => "\{valid_module}"
          }
          let failure = ValidateInvalidFuzzFailure::{
            profile: normalized,
            seed,
            module_attempt,
            strategy: strategy_name,
            expected_issue: expected_issue,
            actual_issue: validation_issue_message(mismatch_issue),
            module_text: invalid_text,
          }
          match on_failure {
            Some(handler) =>
              match handler(failure) {
                Ok(_) => ()
                Err(e) => {
                  return Err(
                    "validate-invalid fuzz failure callback failed to persist repro: \{e}",
                  )
                }
              }
            None => ()
          }
          problems.push(
            "\{strategy_name}: unexpected issue family \{validation_issue_message(mismatch_issue)}",
          )
        }
        None => ()
      }
      if attempted > 0 {
        tested_count[strategy_name] = tested_count
          .get(strategy_name)
          .unwrap_or(0) +
          attempted
      }
      if mutated > 0 {
        mutated_count[strategy_name] = mutated_count
          .get(strategy_name)
          .unwrap_or(0) +
          mutated
      }
      if rejected > 0 {
        rejected_count[strategy_name] = rejected_count
          .get(strategy_name)
          .unwrap_or(0) +
          rejected
      }
      if matched > 0 {
        matched_count[strategy_name] = matched_count
          .get(strategy_name)
          .unwrap_or(0) +
          matched
      }
    }
  }
  if modules_tested == 0 {
    return Err(
      "validate-invalid fuzz found zero valid modules: profile=\{normalized} seed=\{seed}",
    )
  }
  for s in strategy_names {
    let tested = tested_count.get(s).unwrap_or(0)
    let matched = matched_count.get(s).unwrap_or(0)
    if tested == 0 {
      problems.push("\{s}: not executed")
      continue
    }
    if tested < 2 {
      problems.push("\{s}: too few attempts (\{tested})")
      continue
    }
    let reject_rate = matched * 100 / tested
    if tested >= 2 && reject_rate < 80 {
      problems.push("\{s}: \{reject_rate}% expected rejections (\{matched}/\{tested})")
    }
  }
  let stats = ValidateInvalidFuzzStats::{
    profile: normalized,
    seed,
    module_attempts,
    modules_tested,
    strategy_counts: strategy_names.map(fn(name) {
      ValidateInvalidStrategyCounts::{
        name,
        attempted: tested_count.get(name).unwrap_or(0),
        mutated: mutated_count.get(name).unwrap_or(0),
        rejected: rejected_count.get(name).unwrap_or(0),
      }
    }),
    strategies_with_low_rejection: problems,
  }
  if problems.length() > 0 {
    return Err(
      "validate-invalid fuzz found low rejection strategies: \{problems}",
    )
  }
  Ok(stats)
}

///|
pub fn run_validate_invalid_fuzz_from_modules(
  profile : String,
  seed : UInt64,
  modules : Array[@lib.Module],
  on_failure? : ((ValidateInvalidFuzzFailure) -> Result[Unit, String])? = None,
) -> Result[ValidateInvalidFuzzStats, String] {
  let (normalized, module_attempts) = match validate_invalid_fuzz_profile_attempts(profile) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let module_count = modules.length()
  if module_count == 0 {
    return Err(
      "validate-invalid fuzz found zero valid modules: profile=\{normalized} seed=\{seed}",
    )
  }
  run_validate_invalid_fuzz_with_modules(
    normalized,
    seed,
    module_attempts,
    fn(module_attempt, _) {
      Some(modules[(module_attempt - 1) % module_count])
    },
    on_failure,
  )
}

///|
pub fn run_validate_invalid_fuzz(
  profile : String,
  seed : UInt64,
  on_failure? : ((ValidateInvalidFuzzFailure) -> Result[Unit, String])? = None,
) -> Result[ValidateInvalidFuzzStats, String] {
  let (normalized, module_attempts) = match validate_invalid_fuzz_profile_attempts(profile) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  run_validate_invalid_fuzz_with_modules(
    normalized,
    seed,
    module_attempts,
    fn(_, rnd) {
      while true {
        let valid_module = gen_valid_module(rnd)
        match validate_module(valid_module) {
          Ok(_) => return Some(valid_module)
          Err(_) => continue
        }
      }
      None
    },
    on_failure,
  )
}

///|
test "run_validate_invalid_fuzz rejects unknown profile" {
  match run_validate_invalid_fuzz("not-a-profile", 0x5eedUL) {
    Ok(_) => fail("expected unknown profile error")
    Err(msg) =>
      assert_true(msg.contains("unknown validate-invalid fuzz profile"))
  }
}

///|
test "run_validate_invalid_fuzz_from_modules rejects zero modules" {
  match run_validate_invalid_fuzz_from_modules("smoke", 0x5eedUL, []) {
    Ok(_) => fail("expected empty seed corpus error")
    Err(msg) =>
      assert_true(msg.contains("zero valid modules"))
  }
}

///|
test "HeapTypeSwap strategy mutates concrete heap types and rejects mutated module" {
  let table_ty = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(10, Some(10)),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], Locals::empty(), TExpr::new([TInstr::nop()])),
      ]),
    )
    .with_table_sec(
      TableSec::new([
        Table::new(
          table_ty,
          Some(
            Expr::new([Instruction::ref_func(FuncIdx::new(0U))]),
          ),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let (modified, invalid) = apply_strategy(HeapTypeSwap, mod)
  assert_true(modified)
  assert_not_eq(invalid, mod)
  match invalid.table_sec {
    Some(TableSec(tables)) if tables.length() > 0 =>
      match tables[0] {
        Table(TableType(mutated_elem_ty, _), _) =>
          assert_not_eq(
            mutated_elem_ty,
            RefType::new(true, HeapType::abs(AbsHeapType::func())),
          )
        _ => fail("expected a table in heaptype-swap invalid module")
      }
    _ => fail("expected table section in heaptype-swap invalid module")
  }
  match validate_module(invalid) {
    Ok(_) => fail("expected heaptype swap to produce invalid module")
    Err(_) => ()
  }
}

///|
test "RefType AbsHeapTypeRefType swaps produce different values" {
  let swaps : Array[(RefType, RefType)] = [
    (RefType::abs(AbsHeapType::func()), RefType::abs(AbsHeapType::extern_())),
    (RefType::abs(AbsHeapType::extern_()), RefType::abs(AbsHeapType::func())),
    (RefType::abs(AbsHeapType::any()), RefType::abs(AbsHeapType::func())),
    (RefType::abs(AbsHeapType::exn()), RefType::abs(AbsHeapType::any())),
  ]
  for pair in swaps {
    let (before, after) = pair
    assert_not_eq(before, after)
  }
}

///|
test "Exn to Any swap - verify these are actually different hierarchies" {
  // These should NOT be equal
  assert_not_eq(
    RefType::abs(AbsHeapType::exn()),
    RefType::abs(AbsHeapType::any()),
  )
  assert_not_eq(
    HeapType::abs(AbsHeapType::exn()),
    HeapType::abs(AbsHeapType::any()),
  )
}

///|
test "TagIdxOOB arithmetic produces a large index delta" {
  let target = 1U + 0x7FFFFFFF
  assert_true(target > 1000U)
}

///|
test "TagIdxOOB rejects a module with throw/catch tag uses" {
  let tag_sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let func_sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([tag_sig, func_sig]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          Locals::empty(),
          TExpr::new([
            TInstr::try_table(
              BlockType::void_(),
              [Catch::new(TagIdx::new(0), LabelIdx::new(1U))],
              TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
            ),
            TInstr::return_([]),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let (modified, invalid_mod) = apply_strategy(TagIdxOOB(1), mod)
  assert_true(modified)
  assert_not_eq(invalid_mod, mod)
  match validate_module(invalid_mod) {
    Ok(_) => fail("expected invalid module to be rejected")
    Err(_) => ()
  }
}

///|
test "StartIdxOOB strategy rejects module with valid start function" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], Locals::empty(), TExpr::new([TInstr::nop()])),
      ]),
    )
    .with_start_sec(StartSec::new(FuncIdx::new(0)))
  assert_eq(validate_module(mod), Ok(()))
  let (modified, invalid_mod) = apply_strategy(StartIdxOOB(1), mod)
  assert_true(modified)
  match validate_module(invalid_mod) {
    Ok(_) => fail("expected StartIdxOOB strategy to produce invalid module")
    Err(_) => ()
  }
}

///|
test "DuplicateExportName strategy rejects module with a single export" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], Locals::empty(), TExpr::new([TInstr::nop()])),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("f"), ExternIdx::func(FuncIdx::new(0))),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let (modified, invalid_mod) = apply_strategy(DuplicateExportName, mod)
  assert_true(modified)
  match validate_module(invalid_mod) {
    Ok(_) =>
      fail("expected DuplicateExportName strategy to produce invalid module")
    Err(err) =>
      assert_true(
        validation_error_message(err).contains("duplicate export name"),
      )
  }
}
