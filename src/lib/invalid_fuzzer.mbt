///|
/// Increment all indices of a specific type to cause out-of-bounds errors
fn make_funcidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_funcidx: Some(fn(_ctx : Unit, idx : FuncIdx) -> (Unit, FuncIdx)? {
      let FuncIdx(i) = idx
      // Make idempotent: if already large, don't transform again
      if i >= target {
        None
      } else {
        Some(((), FuncIdx(i + target)))
      }
    }),
  }
}

///|
fn make_typeidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_typeidx: Some(fn(_ctx : Unit, idx : TypeIdx) -> (Unit, TypeIdx)? {
      match idx {
        TypeIdx(i) => if i >= target { None } else { Some(((), TypeIdx(i + target))) }
        RecIdx(i) => if i >= target { None } else { Some(((), RecIdx(i + target))) }
      }
    }),
  }
}

///|
fn make_localidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_localidx: Some(fn(_ctx : Unit, idx : LocalIdx) -> (Unit, LocalIdx)? {
      let LocalIdx(i) = idx
      if i >= target { None } else { Some(((), LocalIdx(i + target))) }
    }),
  }
}

///|
fn make_globalidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_globalidx: Some(fn(_ctx : Unit, idx : GlobalIdx) -> (Unit, GlobalIdx)? {
      let GlobalIdx(i) = idx
      if i >= target { None } else { Some(((), GlobalIdx(i + target))) }
    }),
  }
}

///|
fn make_labelidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_labelidx: Some(fn(_ctx : Unit, idx : LabelIdx) -> (Unit, LabelIdx)? {
      let LabelIdx(i) = idx
      if i >= target { None } else { Some(((), LabelIdx(i + target))) }
    }),
  }
}

///|
fn make_tableidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_tableidx: Some(fn(_ctx : Unit, idx : TableIdx) -> (Unit, TableIdx)? {
      let TableIdx(i) = idx
      if i >= target { None } else { Some(((), TableIdx(i + target))) }
    }),
  }
}

///|
fn make_memidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_memidx: Some(fn(_ctx : Unit, idx : MemIdx) -> (Unit, MemIdx)? {
      let MemIdx(i) = idx
      if i >= target { None } else { Some(((), MemIdx(i + target))) }
    }),
  }
}

///|
fn make_dataidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_dataidx: Some(fn(_ctx : Unit, idx : DataIdx) -> (Unit, DataIdx)? {
      let DataIdx(i) = idx
      if i >= target { None } else { Some(((), DataIdx(i + target))) }
    }),
  }
}

///|
fn make_elemidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_elemidx: Some(fn(_ctx : Unit, idx : ElemIdx) -> (Unit, ElemIdx)? {
      let ElemIdx(i) = idx
      if i >= target { None } else { Some(((), ElemIdx(i + target))) }
    }),
  }
}

///|
fn make_tagidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_tagidx: Some(fn(_ctx : Unit, idx : TagIdx) -> (Unit, TagIdx)? {
      let TagIdx(i) = idx
      if i >= target { None } else { Some(((), TagIdx(i + target))) }
    }),
  }
}

///|
/// Use Bool context to track if we've already corrupted an expr
fn make_type_corruption_transformer() -> ModuleTransformer[Bool] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_expr: Some(fn(done : Bool, expr : Expr) -> (Bool, Expr)? {
      if done {
        return None
      }
      let Expr(instrs) = expr
      if instrs.length() == 0 {
        return None
      }
      // Insert i32.const followed by i64.add - guaranteed type error
      let new_instrs = [I32Const(I32(42)), I64Add]
      for i in instrs {
        new_instrs.push(i)
      }
      Some((true, Expr(new_instrs)))
    }),
  }
}

///|
fn make_numtype_swap_transformer() -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    // Only swap the VALUE TYPES, not the instructions
    // This creates mismatches between declared types and instruction semantics
    on_valtype: Some(fn(_ctx : Unit, vt : ValType) -> (Unit, ValType)? {
      match vt {
        NumTypeValType(I32NumType) => Some(((), NumTypeValType(F64NumType)))
        NumTypeValType(I64NumType) => Some(((), NumTypeValType(F32NumType)))
        NumTypeValType(F32NumType) => Some(((), NumTypeValType(I64NumType)))
        NumTypeValType(F64NumType) => Some(((), NumTypeValType(I32NumType)))
        _ => None
      }
    }),
  }
}

///|
/// Aggressive nullability flip - make ALL ref types non-nullable
/// This will fail if there's any ref.null, table without init, or nullable parameter
fn make_nullability_flip_transformer() -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_reftype: Some(fn(_ctx : Unit, rt : RefType) -> (Unit, RefType)? {
      match rt {
        // Force all ref types to be non-nullable
        HeapTypeRefType(true, ht) => Some(((), HeapTypeRefType(false, ht)))
        // Already non-nullable - convert to bottom type to cause more errors
        HeapTypeRefType(false, AbsHeapTypeHeapType(NoneAbsHeapType)) => None
        HeapTypeRefType(false, AbsHeapTypeHeapType(NoFuncAbsHeapType)) => None
        HeapTypeRefType(false, AbsHeapTypeHeapType(NoExternAbsHeapType)) => None
        HeapTypeRefType(false, ht) =>
          // Change to bottom type of same hierarchy - very restrictive
          match ht {
            AbsHeapTypeHeapType(FuncAbsHeapType) |
            AbsHeapTypeHeapType(NoFuncAbsHeapType) =>
              Some(((), HeapTypeRefType(false, AbsHeapTypeHeapType(NoFuncAbsHeapType))))
            AbsHeapTypeHeapType(ExternAbsHeapType) |
            AbsHeapTypeHeapType(NoExternAbsHeapType) =>
              Some(((), HeapTypeRefType(false, AbsHeapTypeHeapType(NoExternAbsHeapType))))
            AbsHeapTypeHeapType(ExnAbsHeapType) |
            AbsHeapTypeHeapType(NoExnAbsHeapType) =>
              Some(((), HeapTypeRefType(false, AbsHeapTypeHeapType(NoExnAbsHeapType))))
            _ =>
              // For any/eq/struct/array/i31 hierarchy, use none
              Some(((), HeapTypeRefType(false, AbsHeapTypeHeapType(NoneAbsHeapType))))
          }
        AbsHeapTypeRefType(aht) =>
          // These shorthands are nullable, make them non-null with explicit form
          Some(((), HeapTypeRefType(false, AbsHeapTypeHeapType(aht))))
      }
    }),
    // Also corrupt ref.null to create definite type errors
    on_instruction: Some(fn(_ctx : Unit, instr : Instruction) -> (Unit, Instruction)? {
      match instr {
        // ref.null produces nullable ref, but if types expect non-null, this fails
        // Replace with something that definitely won't typecheck
        RefNull(_) => Some(((), I32Const(I32(0)))) // Completely wrong type
        RefFunc(_) => Some(((), I64Const(I64(0L)))) // Wrong type for funcref
        RefIsNull => Some(((), I64Const(I64(0L)))) // Expects ref, we removed it
        _ => None
      }
    }),
  }
}

///|
/// Alternative strategy: corrupt ONLY type declarations, not code
/// This creates inconsistency between what's declared and what's executed
fn make_signature_corruption_transformer() -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_comptype: Some(fn(_ctx : Unit, ct : CompType) -> (Unit, CompType)? {
      match ct {
        FuncCompType(params, results) => {
          // Add extra parameters that callers won't provide
          let new_params = params.copy()
          new_params.push(NumTypeValType(I64NumType))
          new_params.push(NumTypeValType(F64NumType))
          // Change result types
          let new_results = results.map(fn(vt) {
            match vt {
              NumTypeValType(I32NumType) => NumTypeValType(F64NumType)
              NumTypeValType(I64NumType) => NumTypeValType(F32NumType)
              NumTypeValType(F32NumType) => NumTypeValType(I64NumType)
              NumTypeValType(F64NumType) => NumTypeValType(I32NumType)
              other => other
            }
          })
          Some(((), FuncCompType(new_params, new_results)))
        }
        StructCompType(fields) => {
          // Change field types
          let new_fields = fields.map(fn(ft) {
            let FieldType(st, mutability) = ft
            match st {
              ValTypeStorageType(NumTypeValType(I32NumType)) =>
                FieldType(ValTypeStorageType(NumTypeValType(F64NumType)), mutability)
              ValTypeStorageType(NumTypeValType(I64NumType)) =>
                FieldType(ValTypeStorageType(NumTypeValType(F32NumType)), mutability)
              _ => ft
            }
          })
          Some(((), StructCompType(new_fields)))
        }
        ArrayCompType(FieldType(st, mutability)) => {
          let new_st = match st {
            ValTypeStorageType(NumTypeValType(I32NumType)) =>
              ValTypeStorageType(NumTypeValType(F64NumType))
            ValTypeStorageType(NumTypeValType(I64NumType)) =>
              ValTypeStorageType(NumTypeValType(F32NumType))
            _ => st
          }
          Some(((), ArrayCompType(FieldType(new_st, mutability))))
        }
      }
    }),
  }
}

///|
/// Strategy that corrupts global initializers to not match declared types
fn make_global_init_mismatch_transformer() -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_global: Some(fn(_ctx : Unit, g : Global) -> (Unit, Global)? {
      let Global(GlobalType(vt, mutable), _init) = g
      // Create an init expression with wrong type
      let wrong_init = match vt {
        NumTypeValType(I32NumType) => Expr([F64Const(F64(0.0))])
        NumTypeValType(I64NumType) => Expr([F32Const(F32(0.0))])
        NumTypeValType(F32NumType) => Expr([I64Const(I64(0L))])
        NumTypeValType(F64NumType) => Expr([I32Const(I32(0))])
        RefTypeValType(_) => Expr([I32Const(I32(0))]) // Definitely wrong
        VecTypeValType => Expr([I32Const(I32(0))])
        BotValType => return None
      }
      Some(((), Global(GlobalType(vt, mutable), wrong_init)))
    }),
  }
}

///|
/// Strategy that corrupts table initializers
fn make_table_init_mismatch_transformer() -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_table: Some(fn(_ctx : Unit, t : Table) -> (Unit, Table)? {
      let Table(tt, _init) = t
      // Set init to wrong type expression
      Some(((), Table(tt, Some(Expr([I32Const(I32(42))])))))
    }),
  }
}

///|
/// Returns (was_modified, transformed_module)
fn make_heaptype_swap_transformer() -> ModuleTransformer[Bool] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_heaptype: Some(fn(modified : Bool, ht : HeapType) -> (Bool, HeapType)? {
      match ht {
        AbsHeapTypeHeapType(FuncAbsHeapType) =>
          Some((true, AbsHeapTypeHeapType(ExternAbsHeapType)))
        AbsHeapTypeHeapType(ExternAbsHeapType) =>
          Some((true, AbsHeapTypeHeapType(FuncAbsHeapType)))
        AbsHeapTypeHeapType(AnyAbsHeapType) =>
          Some((true, AbsHeapTypeHeapType(FuncAbsHeapType)))
        AbsHeapTypeHeapType(EqAbsHeapType) =>
          Some((true, AbsHeapTypeHeapType(ExternAbsHeapType)))
        AbsHeapTypeHeapType(I31AbsHeapType) =>
          Some((true, AbsHeapTypeHeapType(FuncAbsHeapType)))
        AbsHeapTypeHeapType(StructAbsHeapType) =>
          Some((true, AbsHeapTypeHeapType(ExternAbsHeapType)))
        AbsHeapTypeHeapType(ArrayAbsHeapType) =>
          Some((true, AbsHeapTypeHeapType(FuncAbsHeapType)))
        AbsHeapTypeHeapType(ExnAbsHeapType) =>
          Some((true, AbsHeapTypeHeapType(AnyAbsHeapType)))
        HeapType(TypeIdx(i)) => Some((true, HeapType(TypeIdx(i + 1000))))
        HeapType(RecIdx(i)) => Some((true, HeapType(RecIdx(i + 1000))))
        _ => Some((modified, ht)) // Keep tracking, no change
      }
    }),
  }
}

///|
/// More aggressive drop insertion - prepend Drop to cause stack underflow
fn make_drop_insertion_transformer() -> ModuleTransformer[Bool] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_expr: Some(fn(done : Bool, expr : Expr) -> (Bool, Expr)? {
      if done {
        return None
      }
      let Expr(instrs) = expr
      if instrs.length() == 0 {
        return None
      }
      // Prepend Drop instructions to cause stack underflow
      let new_instrs : Array[Instruction] = [Drop, Drop, Drop]
      for i in instrs {
        new_instrs.push(i)
      }
      Some((true, Expr(new_instrs)))
    }),
  }
}

///|
/// Remove block ends / corrupt block structure - use Bool to do once
fn make_block_corruption_transformer() -> ModuleTransformer[Bool] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_expr: Some(fn(done : Bool, expr : Expr) -> (Bool, Expr)? {
      if done {
        return None
      }
      let Expr(instrs) = expr
      if instrs.length() > 0 {
        Some((true, Expr(instrs.iter().take(instrs.length() - 1).collect())))
      } else {
        None
      }
    }),
  }
}

///|
/// Block type mismatch - use Bool to transform once
fn make_blocktype_mismatch_transformer() -> ModuleTransformer[Bool] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_blocktype: Some(fn(done : Bool, bt : BlockType) -> (Bool, BlockType)? {
      if done {
        return None
      }
      match bt {
        EmptyBlockType =>
          Some((true, ValTypeBlockType(NumTypeValType(I32NumType))))
        ValTypeBlockType(NumTypeValType(I32NumType)) =>
          Some((true, ValTypeBlockType(NumTypeValType(I64NumType))))
        ValTypeBlockType(_) => Some((true, EmptyBlockType))
        TypeIdxBlockType(TypeIdx(i)) =>
          Some((true, TypeIdxBlockType(TypeIdx(i + 1))))
        TypeIdxBlockType(RecIdx(i)) =>
          Some((true, TypeIdxBlockType(RecIdx(i + 1))))
      }
    }),
  }
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
} derive(Show)

///|
/// Apply strategy and return transformed module
///|
fn apply_strategy(strategy : InvalidationStrategy, mod_ : Module) -> (Bool, Module) {
  match strategy {
    FuncIdxOOB(n) => (true, make_funcidx_oob_transformer(n).walk_module((), mod_).1)
    TypeIdxOOB(n) => (true, make_typeidx_oob_transformer(n).walk_module((), mod_).1)
    LocalIdxOOB(n) => (true, make_localidx_oob_transformer(n).walk_module((), mod_).1)
    GlobalIdxOOB(n) => (true, make_globalidx_oob_transformer(n).walk_module((), mod_).1)
    LabelIdxOOB(n) => (true, make_labelidx_oob_transformer(n).walk_module((), mod_).1)
    TableIdxOOB(n) => (true, make_tableidx_oob_transformer(n).walk_module((), mod_).1)
    MemIdxOOB(n) => (true, make_memidx_oob_transformer(n).walk_module((), mod_).1)
    DataIdxOOB(n) => (true, make_dataidx_oob_transformer(n).walk_module((), mod_).1)
    ElemIdxOOB(n) => (true, make_elemidx_oob_transformer(n).walk_module((), mod_).1)
    TagIdxOOB(n) => (true, make_tagidx_oob_transformer(n).walk_module((), mod_).1)
    NumTypeSwap => (true, make_numtype_swap_transformer().walk_module((), mod_).1)
    NullabilityFlip => (true, make_nullability_flip_transformer().walk_module((), mod_).1)
    HeapTypeSwap => {
      let (modified, result) = make_heaptype_swap_transformer().walk_module(false, mod_)
      (modified, result)
    }
    InstructionTypeMismatch => (true, make_type_corruption_transformer().walk_module(false, mod_).1)
    BlockTypeMismatch => (true, make_blocktype_mismatch_transformer().walk_module(false, mod_).1)
    DropInsertion => (true, make_drop_insertion_transformer().walk_module(false, mod_).1)
    BlockCorruption => (true, make_block_corruption_transformer().walk_module(false, mod_).1)
    SignatureCorruption => (true, make_signature_corruption_transformer().walk_module((), mod_).1)
    GlobalInitMismatch => (true, make_global_init_mismatch_transformer().walk_module((), mod_).1)
    TableInitMismatch => (true, make_table_init_mismatch_transformer().walk_module((), mod_).1)
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
/// Result of testing a single strategy
fn fuzz_invalid_module_with_coverage(
  valid_module : Module,
  strategy : InvalidationStrategy,
) -> (String, Bool, Bool) {
  let strategy_name = strategy.to_string()
  let (was_modified, invalid_module) = apply_strategy(strategy, valid_module)

  // Not tested if no modification was made OR module unchanged
  if not(was_modified) || invalid_module == valid_module {
    return (strategy_name, false, true)
  }

  match validate_module(invalid_module) {
    Ok(_) => (strategy_name, true, false)
    Err(_) => (strategy_name, true, true)
  }
}

///|
fn fuzz_all_strategies_with_coverage(
  valid_module : Module,
) -> Array[(String, Bool, Bool)] {
  let strategies : Array[InvalidationStrategy] = [
    FuncIdxOOB(1), FuncIdxOOB(100), TypeIdxOOB(1), TypeIdxOOB(100),
    LocalIdxOOB(1), LocalIdxOOB(100), GlobalIdxOOB(1), LabelIdxOOB(1),
    TableIdxOOB(1), MemIdxOOB(1), DataIdxOOB(1), ElemIdxOOB(1), TagIdxOOB(1),
    NumTypeSwap, NullabilityFlip, HeapTypeSwap, InstructionTypeMismatch,
    BlockTypeMismatch, DropInsertion, BlockCorruption,
    SignatureCorruption, GlobalInitMismatch, TableInitMismatch,
  ]
  strategies.map(fn(s) { fuzz_invalid_module_with_coverage(valid_module, s) })
}


///|
test "invalidation fuzzing with coverage" {
  let rnd = @quickcheck/splitmix.new()
  let tested_count : Map[String, Int] = {}
  let rejected_count : Map[String, Int] = {}
  let strategy_names = [
    "FuncIdxOOB", "TypeIdxOOB", "LocalIdxOOB", "GlobalIdxOOB", "LabelIdxOOB",
    "TableIdxOOB", "MemIdxOOB", "DataIdxOOB", "ElemIdxOOB", "TagIdxOOB",
    "NumTypeSwap", "NullabilityFlip", "HeapTypeSwap", "InstructionTypeMismatch",
    "BlockTypeMismatch", "DropInsertion", "BlockCorruption",
    "SignatureCorruption", "GlobalInitMismatch", "TableInitMismatch",
  ]
  for s in strategy_names {
    tested_count[s] = 0
    rejected_count[s] = 0
  }

  for _ in 0..<200 {
    let ctx = gen_ctx_new(200, rnd=Some(rnd))
    let (_, valid_module) = match gen_module_valid_full(ctx) {
      Ok(t) => t
      Err(_) => continue
    }
    if validate_module(valid_module) is Err(_) {
      continue
    }
    let results = fuzz_all_strategies_with_coverage(valid_module)
    for result in results {
      let (strategy_name, was_tested, passed) = result
      if was_tested {
        tested_count[strategy_name] = tested_count.get(strategy_name).unwrap_or(0) + 1
        if passed {
          rejected_count[strategy_name] = rejected_count.get(strategy_name).unwrap_or(0) + 1
        }
      }
    }
  }

  let problems : Array[String] = []
  for s in strategy_names {
    let tested = tested_count.get(s).unwrap_or(0)
    let rejected = rejected_count.get(s).unwrap_or(0)
    if tested >= 10 {
      let reject_rate = rejected * 100 / tested
      if reject_rate < 80 {
        problems.push("\{s}: only \{reject_rate}% rejected (\{rejected}/\{tested})")
      }
    }
  }
  if problems.length() > 0 {
    fail(
      "Strategies with low rejection rate (potential validator bugs):\n  " +
      problems.iter().intersperse("\n  ").fold(init="", fn(a, b) { a + b }),
    )
  }
}
