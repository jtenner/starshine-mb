///|
/// Increment all indices of a specific type to cause out-of-bounds errors
fn make_funcidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_funcidx: Some(fn(
      _ctx : Unit,
      idx : FuncIdx,
    ) -> TransformerResult[Unit, FuncIdx] {
      let FuncIdx(i) = idx
      // Make idempotent: if already large, don't transform again
      if i >= target {
        Ok(None)
      } else {
        Ok(Some(((), FuncIdx(i + target))))
      }
    }),
  }
}

///|
fn make_typeidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_typeidx: Some(fn(
      _ctx : Unit,
      idx : TypeIdx,
    ) -> TransformerResult[Unit, TypeIdx] {
      match idx {
        TypeIdx(i) =>
          if i >= target {
            Ok(None)
          } else {
            Ok(Some(((), TypeIdx(i + target))))
          }
        RecIdx(i) =>
          if i >= target {
            Ok(None)
          } else {
            Ok(Some(((), RecIdx(i + target))))
          }
      }
    }),
  }
}

///|
fn make_localidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_localidx: Some(fn(
      _ctx : Unit,
      idx : LocalIdx,
    ) -> TransformerResult[Unit, LocalIdx] {
      let LocalIdx(i) = idx
      if i >= target {
        Ok(None)
      } else {
        Ok(Some(((), LocalIdx(i + target))))
      }
    }),
  }
}

///|
fn make_globalidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_globalidx: Some(fn(
      _ctx : Unit,
      idx : GlobalIdx,
    ) -> TransformerResult[Unit, GlobalIdx] {
      let GlobalIdx(i) = idx
      if i >= target {
        Ok(None)
      } else {
        Ok(Some(((), GlobalIdx(i + target))))
      }
    }),
  }
}

///|
fn make_labelidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_labelidx: Some(fn(
      _ctx : Unit,
      idx : LabelIdx,
    ) -> TransformerResult[Unit, LabelIdx] {
      let LabelIdx(i) = idx
      if i >= target {
        Ok(None)
      } else {
        Ok(Some(((), LabelIdx(i + target))))
      }
    }),
  }
}

///|
fn make_tableidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_tableidx: Some(fn(
      _ctx : Unit,
      idx : TableIdx,
    ) -> TransformerResult[Unit, TableIdx] {
      let TableIdx(i) = idx
      if i >= target {
        Ok(None)
      } else {
        Ok(Some(((), TableIdx(i + target))))
      }
    }),
  }
}

///|
fn make_memidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_memidx: Some(fn(
      _ctx : Unit,
      idx : MemIdx,
    ) -> TransformerResult[Unit, MemIdx] {
      let MemIdx(i) = idx
      if i >= target {
        Ok(None)
      } else {
        Ok(Some(((), MemIdx(i + target))))
      }
    }),
  }
}

///|
fn make_dataidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_dataidx: Some(fn(
      _ctx : Unit,
      idx : DataIdx,
    ) -> TransformerResult[Unit, DataIdx] {
      let DataIdx(i) = idx
      if i >= target {
        Ok(None)
      } else {
        Ok(Some(((), DataIdx(i + target))))
      }
    }),
  }
}

///|
fn make_elemidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_elemidx: Some(fn(
      _ctx : Unit,
      idx : ElemIdx,
    ) -> TransformerResult[Unit, ElemIdx] {
      let ElemIdx(i) = idx
      if i >= target {
        Ok(None)
      } else {
        Ok(Some(((), ElemIdx(i + target))))
      }
    }),
  }
}

///|
fn make_tagidx_oob_transformer(offset : UInt) -> ModuleTransformer[Unit] {
  let target = offset + 0x7FFFFFFF
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_tagidx: Some(fn(
      _ctx : Unit,
      idx : TagIdx,
    ) -> TransformerResult[Unit, TagIdx] {
      let TagIdx(i) = idx
      if i >= target {
        Ok(None)
      } else {
        Ok(Some(((), TagIdx(i + target))))
      }
    }),
  }
}

///|
/// Use Bool context to track if we've already corrupted an expr
fn make_type_corruption_transformer() -> ModuleTransformer[Bool] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_expr: Some(fn(
      done : Bool,
      expr : Expr,
    ) -> TransformerResult[Bool, Expr] {
      if done {
        return Ok(None)
      }
      let Expr(instrs) = expr
      if instrs.length() == 0 {
        return Ok(None)
      }
      // Insert i32.const followed by i64.add - guaranteed type error
      let new_instrs = [I32Const(I32(42)), I64Add]
      for i in instrs {
        new_instrs.push(i)
      }
      Ok(Some((true, Expr(new_instrs))))
    }),
  }
}

///|
fn make_numtype_swap_transformer() -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new()
    // Only swap the VALUE TYPES, not the instructions
    // This creates mismatches between declared types and instruction semantics
    ,
    on_valtype: Some(fn(
      _ctx : Unit,
      vt : ValType,
    ) -> TransformerResult[Unit, ValType] {
      match vt {
        NumTypeValType(I32NumType) => Ok(Some(((), NumTypeValType(F64NumType))))
        NumTypeValType(I64NumType) => Ok(Some(((), NumTypeValType(F32NumType))))
        NumTypeValType(F32NumType) => Ok(Some(((), NumTypeValType(I64NumType))))
        NumTypeValType(F64NumType) => Ok(Some(((), NumTypeValType(I32NumType))))
        _ => Ok(None)
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
    on_reftype: Some(fn(
      _ctx : Unit,
      rt : RefType,
    ) -> TransformerResult[Unit, RefType] {
      match rt {
        // Force all ref types to be non-nullable
        HeapTypeRefType(true, ht) => Ok(Some(((), HeapTypeRefType(false, ht))))
        // Already non-nullable - convert to bottom type to cause more errors
        HeapTypeRefType(false, AbsHeapTypeHeapType(NoneAbsHeapType)) => Ok(None)
        HeapTypeRefType(false, AbsHeapTypeHeapType(NoFuncAbsHeapType)) =>
          Ok(None)
        HeapTypeRefType(false, AbsHeapTypeHeapType(NoExternAbsHeapType)) =>
          Ok(None)
        HeapTypeRefType(false, ht) =>
          // Change to bottom type of same hierarchy - very restrictive
          match ht {
            AbsHeapTypeHeapType(FuncAbsHeapType)
            | AbsHeapTypeHeapType(NoFuncAbsHeapType) =>
              Ok(
                Some(
                  (
                    (),
                    HeapTypeRefType(
                      false,
                      AbsHeapTypeHeapType(NoFuncAbsHeapType),
                    ),
                  ),
                ),
              )
            AbsHeapTypeHeapType(ExternAbsHeapType)
            | AbsHeapTypeHeapType(NoExternAbsHeapType) =>
              Ok(
                Some(
                  (
                    (),
                    HeapTypeRefType(
                      false,
                      AbsHeapTypeHeapType(NoExternAbsHeapType),
                    ),
                  ),
                ),
              )
            AbsHeapTypeHeapType(ExnAbsHeapType)
            | AbsHeapTypeHeapType(NoExnAbsHeapType) =>
              Ok(
                Some(
                  (
                    (),
                    HeapTypeRefType(
                      false,
                      AbsHeapTypeHeapType(NoExnAbsHeapType),
                    ),
                  ),
                ),
              )
            _ =>
              // For any/eq/struct/array/i31 hierarchy, use none
              Ok(
                Some(
                  (
                    (),
                    HeapTypeRefType(false, AbsHeapTypeHeapType(NoneAbsHeapType)),
                  ),
                ),
              )
          }
        AbsHeapTypeRefType(aht) =>
          // These shorthands are nullable, make them non-null with explicit form
          Ok(Some(((), HeapTypeRefType(false, AbsHeapTypeHeapType(aht)))))
      }
    }),
    // Also corrupt ref.null to create definite type errors
    on_instruction: Some(fn(
      _ctx : Unit,
      instr : Instruction,
    ) -> TransformerResult[Unit, Instruction] {
      match instr {
        // ref.null produces nullable ref, but if types expect non-null, this fails
        // Replace with something that definitely won't typecheck
        RefNull(_) => Ok(Some(((), I32Const(I32(0))))) // Completely wrong type
        RefFunc(_) => Ok(Some(((), I64Const(I64(0L))))) // Wrong type for funcref
        RefIsNull => Ok(Some(((), I64Const(I64(0L))))) // Expects ref, we removed it
        _ => Ok(None)
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
    on_comptype: Some(fn(
      _ctx : Unit,
      ct : CompType,
    ) -> TransformerResult[Unit, CompType] {
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
          Ok(Some(((), FuncCompType(new_params, new_results))))
        }
        StructCompType(fields) => {
          // Change field types
          let new_fields = fields.map(fn(ft) {
            let FieldType(st, mutability) = ft
            match st {
              ValTypeStorageType(NumTypeValType(I32NumType)) =>
                FieldType(
                  ValTypeStorageType(NumTypeValType(F64NumType)),
                  mutability,
                )
              ValTypeStorageType(NumTypeValType(I64NumType)) =>
                FieldType(
                  ValTypeStorageType(NumTypeValType(F32NumType)),
                  mutability,
                )
              _ => ft
            }
          })
          Ok(Some(((), StructCompType(new_fields))))
        }
        ArrayCompType(FieldType(st, mutability)) => {
          let new_st = match st {
            ValTypeStorageType(NumTypeValType(I32NumType)) =>
              ValTypeStorageType(NumTypeValType(F64NumType))
            ValTypeStorageType(NumTypeValType(I64NumType)) =>
              ValTypeStorageType(NumTypeValType(F32NumType))
            _ => st
          }
          Ok(Some(((), ArrayCompType(FieldType(new_st, mutability)))))
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
    on_global: Some(fn(
      _ctx : Unit,
      g : Global,
    ) -> TransformerResult[Unit, Global] {
      let Global(GlobalType(vt, mutable), _init) = g
      // Create an init expression with wrong type
      let wrong_init = match vt {
        NumTypeValType(I32NumType) => Expr([F64Const(F64(0.0))])
        NumTypeValType(I64NumType) => Expr([F32Const(F32(0.0))])
        NumTypeValType(F32NumType) => Expr([I64Const(I64(0L))])
        NumTypeValType(F64NumType) => Expr([I32Const(I32(0))])
        RefTypeValType(_) => Expr([I32Const(I32(0))]) // Definitely wrong
        VecTypeValType => Expr([I32Const(I32(0))])
        BotValType => return Ok(None)
      }
      Ok(Some(((), Global(GlobalType(vt, mutable), wrong_init))))
    }),
  }
}

///|
/// Strategy that corrupts table initializers
fn make_table_init_mismatch_transformer() -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_table: Some(fn(
      _ctx : Unit,
      t : Table,
    ) -> TransformerResult[Unit, Table] {
      let Table(tt, _init) = t
      // Set init to wrong type expression
      Ok(Some(((), Table(tt, Some(Expr([I32Const(I32(42))]))))))
    }),
  }
}

///|
/// More aggressive drop insertion - prepend Drop to cause stack underflow
fn make_drop_insertion_transformer() -> ModuleTransformer[Bool] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_expr: Some(fn(
      done : Bool,
      expr : Expr,
    ) -> TransformerResult[Bool, Expr] {
      if done {
        return Ok(None)
      }
      let Expr(instrs) = expr
      if instrs.length() == 0 {
        return Ok(None)
      }
      // Prepend Drop instructions to cause stack underflow
      let new_instrs : Array[Instruction] = [Drop, Drop, Drop]
      for i in instrs {
        new_instrs.push(i)
      }
      Ok(Some((true, Expr(new_instrs))))
    }),
  }
}

///|
/// Remove block ends / corrupt block structure - use Bool to do once
fn make_block_corruption_transformer() -> ModuleTransformer[Bool] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_expr: Some(fn(
      done : Bool,
      expr : Expr,
    ) -> TransformerResult[Bool, Expr] {
      if done {
        return Ok(None)
      }
      let Expr(instrs) = expr
      if instrs.length() > 0 {
        Ok(
          Some((true, Expr(instrs.iter().take(instrs.length() - 1).collect()))),
        )
      } else {
        Ok(None)
      }
    }),
  }
}
///|
fn corrupt_blocktype(bt : BlockType) -> BlockType {
  match bt {
    EmptyBlockType => ValTypeBlockType(NumTypeValType(I32NumType))
    ValTypeBlockType(NumTypeValType(I32NumType)) =>
      ValTypeBlockType(NumTypeValType(I64NumType))
    ValTypeBlockType(NumTypeValType(I64NumType)) =>
      ValTypeBlockType(NumTypeValType(I32NumType))
    ValTypeBlockType(_) => EmptyBlockType
    TypeIdxBlockType(TypeIdx(i)) => TypeIdxBlockType(TypeIdx(i + 1))
    TypeIdxBlockType(RecIdx(i)) => TypeIdxBlockType(RecIdx(i + 1))
  }
}

///|
/// Block type mismatch - insert blocks with wrong types or corrupt existing ones
fn make_blocktype_mismatch_transformer() -> ModuleTransformer[Bool] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_instruction: Some(
      fn(done : Bool, ins : Instruction) -> TransformerResult[Bool, Instruction] {
        if done {
          return Ok(None)
        }
        match ins {
          // Value-producing instructions: wrap in block claiming no result
          // Body produces value, block claims nothing -> mismatch
          I32Const(_) | I64Const(_) | F32Const(_) | F64Const(_) | V128Const(
            _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
            Ok(Some((true, Block(EmptyBlockType, [ins]))))

          // Nop/Drop: wrap in block claiming it produces i32
          // Body produces nothing, block claims i32 -> mismatch
          Nop | Drop =>
            Ok(
              Some(
                (true, Block(ValTypeBlockType(NumTypeValType(I32NumType)), [ins])),
              ),
            )

          // LocalGet produces a value - wrap in block claiming different type
          LocalGet(_) =>
            Ok(
              Some(
                (
                  true,
                  Block(ValTypeBlockType(NumTypeValType(I64NumType)), [ins]),
                ),
              ),
            )

          // GlobalGet produces a value - wrap in block claiming empty
          GlobalGet(_) => Ok(Some((true, Block(EmptyBlockType, [ins]))))

          // Existing control flow: corrupt their block type
          Block(bt, body) => Ok(Some((true, Block(corrupt_blocktype(bt), body))))
          Loop(bt, body) => Ok(Some((true, Loop(corrupt_blocktype(bt), body))))
          If(bt, then_body, else_body) =>
            Ok(Some((true, If(corrupt_blocktype(bt), then_body, else_body))))
          TryTable(bt, catches, body) =>
            Ok(Some((true, TryTable(corrupt_blocktype(bt), catches, body))))

          // RefNull produces a ref - wrap in block claiming i32
          RefNull(_) =>
            Ok(
              Some(
                (true, Block(ValTypeBlockType(NumTypeValType(I32NumType)), [ins])),
              ),
            )

          // RefFunc produces a ref - wrap in block claiming empty
          RefFunc(_) => Ok(Some((true, Block(EmptyBlockType, [ins]))))

          // StructNewDefault produces a ref - wrap in block claiming i32
          StructNewDefault(_) =>
            Ok(
              Some(
                (true, Block(ValTypeBlockType(NumTypeValType(I32NumType)), [ins])),
              ),
            )

          // ArrayNewDefault needs i32 on stack, produces ref
          // Can't easily wrap this one without also providing the i32

          _ => Ok(None)
        }
      },
    ),
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
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    TypeIdxOOB(n) =>
      match make_typeidx_oob_transformer(n).walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    LocalIdxOOB(n) =>
      match make_localidx_oob_transformer(n).walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    GlobalIdxOOB(n) =>
      match make_globalidx_oob_transformer(n).walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    LabelIdxOOB(n) =>
      match make_labelidx_oob_transformer(n).walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    TableIdxOOB(n) =>
      match make_tableidx_oob_transformer(n).walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    MemIdxOOB(n) =>
      match make_memidx_oob_transformer(n).walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    DataIdxOOB(n) =>
      match make_dataidx_oob_transformer(n).walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    ElemIdxOOB(n) =>
      match make_elemidx_oob_transformer(n).walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    TagIdxOOB(n) =>
      match make_tagidx_oob_transformer(n).walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    NumTypeSwap =>
      match make_numtype_swap_transformer().walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    NullabilityFlip =>
      match make_nullability_flip_transformer().walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    HeapTypeSwap =>
      match make_drop_insertion_transformer().walk_module(false, mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    InstructionTypeMismatch =>
      match make_type_corruption_transformer().walk_module(false, mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    BlockTypeMismatch =>
      match make_blocktype_mismatch_transformer().walk_module(false, mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    DropInsertion =>
      match make_drop_insertion_transformer().walk_module(false, mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    BlockCorruption =>
      match make_block_corruption_transformer().walk_module(false, mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    SignatureCorruption =>
      match make_signature_corruption_transformer().walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    GlobalInitMismatch =>
      match make_global_init_mismatch_transformer().walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
        _ => (false, mod_)
      }
    TableInitMismatch =>
      match make_table_init_mismatch_transformer().walk_module((), mod_) {
        Ok(Some((_, new_mod))) => (true, new_mod)
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
  strategies.map(fn(s) { fuzz_invalid_module_with_coverage(valid_module, s) })
}

///|
test "invalidation fuzzing with coverage" {
  let rnd = @quickcheck/splitmix.new()
  let tested_count : Map[String, Int] = {}
  let rejected_count : Map[String, Int] = {}
  let strategy_names = [
    "FuncIdxOOB", "TypeIdxOOB", "LocalIdxOOB", "GlobalIdxOOB", "LabelIdxOOB", "TableIdxOOB",
    "MemIdxOOB", "DataIdxOOB", "ElemIdxOOB", "TagIdxOOB", "NumTypeSwap", "NullabilityFlip",
    "HeapTypeSwap", "InstructionTypeMismatch", "BlockTypeMismatch", "DropInsertion",
    "BlockCorruption", "SignatureCorruption", "GlobalInitMismatch", "TableInitMismatch",
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
        tested_count[strategy_name] = tested_count
          .get(strategy_name)
          .unwrap_or(0) +
          1
        if passed {
          rejected_count[strategy_name] = rejected_count
            .get(strategy_name)
            .unwrap_or(0) +
            1
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
        problems.push(
          "\{s}: only \{reject_rate}% rejected (\{rejected}/\{tested})",
        )
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

///|
test "HeapTypeSwap transformer actually modifies heap types" {
  // Test that each swap produces a different heap type
  let swaps : Array[(HeapType, HeapType)] = [
    (
      AbsHeapTypeHeapType(FuncAbsHeapType),
      AbsHeapTypeHeapType(ExternAbsHeapType),
    ),
    (
      AbsHeapTypeHeapType(ExternAbsHeapType),
      AbsHeapTypeHeapType(FuncAbsHeapType),
    ),
    (AbsHeapTypeHeapType(AnyAbsHeapType), AbsHeapTypeHeapType(FuncAbsHeapType)),
    (AbsHeapTypeHeapType(EqAbsHeapType), AbsHeapTypeHeapType(ExternAbsHeapType)),
    (AbsHeapTypeHeapType(I31AbsHeapType), AbsHeapTypeHeapType(FuncAbsHeapType)),
    (
      AbsHeapTypeHeapType(StructAbsHeapType),
      AbsHeapTypeHeapType(ExternAbsHeapType),
    ),
    (
      AbsHeapTypeHeapType(ArrayAbsHeapType),
      AbsHeapTypeHeapType(FuncAbsHeapType),
    ),
    (AbsHeapTypeHeapType(ExnAbsHeapType), AbsHeapTypeHeapType(AnyAbsHeapType)),
  ]
  for pair in swaps {
    let (before, after) = pair
    assert_not_eq(before, after)
  }
}

///|
test "RefType AbsHeapTypeRefType swaps produce different values" {
  let swaps : Array[(RefType, RefType)] = [
    (AbsHeapTypeRefType(FuncAbsHeapType), AbsHeapTypeRefType(ExternAbsHeapType)),
    (AbsHeapTypeRefType(ExternAbsHeapType), AbsHeapTypeRefType(FuncAbsHeapType)),
    (AbsHeapTypeRefType(AnyAbsHeapType), AbsHeapTypeRefType(FuncAbsHeapType)),
    (AbsHeapTypeRefType(ExnAbsHeapType), AbsHeapTypeRefType(AnyAbsHeapType)),
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
    AbsHeapTypeRefType(ExnAbsHeapType),
    AbsHeapTypeRefType(AnyAbsHeapType),
  )
  assert_not_eq(
    AbsHeapTypeHeapType(ExnAbsHeapType),
    AbsHeapTypeHeapType(AnyAbsHeapType),
  )
}
