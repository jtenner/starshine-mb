///|
/// Increment all indices of a specific type to cause out-of-bounds errors
fn make_funcidx_oob_transformer(offset : UInt) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_funcidx: Some(fn(idx : FuncIdx) -> FuncIdx? {
      let FuncIdx(i) = idx
      // Use a very large number to guarantee OOB
      Some(FuncIdx(i + offset + 0x7FFFFFFF))
    }),
  }
}

///|
fn make_typeidx_oob_transformer(offset : UInt) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_typeidx: Some(fn(idx : TypeIdx) -> TypeIdx? {
      match idx {
        TypeIdx(i) => Some(TypeIdx(i + offset + 0x7FFFFFFF))
        RecIdx(i) => Some(RecIdx(i + offset + 0x7FFFFFFF))
      }
    }),
  }
}

///|
fn make_localidx_oob_transformer(offset : UInt) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_localidx: Some(fn(idx : LocalIdx) -> LocalIdx? {
      let LocalIdx(i) = idx
      Some(LocalIdx(i + offset + 0x7FFFFFFF))
    }),
  }
}

///|
fn make_globalidx_oob_transformer(offset : UInt) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_globalidx: Some(fn(idx : GlobalIdx) -> GlobalIdx? {
      let GlobalIdx(i) = idx
      Some(GlobalIdx(i + offset + 0x7FFFFFFF))
    }),
  }
}

///|
fn make_labelidx_oob_transformer(offset : UInt) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_labelidx: Some(fn(idx : LabelIdx) -> LabelIdx? {
      let LabelIdx(i) = idx
      Some(LabelIdx(i + offset + 0x7FFFFFFF))
    }),
  }
}

///|
fn make_tableidx_oob_transformer(offset : UInt) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_tableidx: Some(fn(idx : TableIdx) -> TableIdx? {
      let TableIdx(i) = idx
      Some(TableIdx(i + offset + 0x7FFFFFFF))
    }),
  }
}

///|
fn make_memidx_oob_transformer(offset : UInt) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_memidx: Some(fn(idx : MemIdx) -> MemIdx? {
      let MemIdx(i) = idx
      Some(MemIdx(i + offset + 0x7FFFFFFF))
    }),
  }
}

///|
fn make_dataidx_oob_transformer(offset : UInt) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_dataidx: Some(fn(idx : DataIdx) -> DataIdx? {
      let DataIdx(i) = idx
      Some(DataIdx(i + offset + 0x7FFFFFFF))
    }),
  }
}

///|
fn make_elemidx_oob_transformer(offset : UInt) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_elemidx: Some(fn(idx : ElemIdx) -> ElemIdx? {
      let ElemIdx(i) = idx
      Some(ElemIdx(i + offset + 0x7FFFFFFF))
    }),
  }
}

///|
fn make_tagidx_oob_transformer(offset : UInt) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_tagidx: Some(fn(idx : TagIdx) -> TagIdx? {
      let TagIdx(i) = idx
      Some(TagIdx(i + offset + 0x7FFFFFFF))
    }),
  }
}

///|
fn make_type_corruption_transformer() -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_expr: Some(fn(expr : Expr) -> Expr? {
      let Expr(instrs) = expr
      if instrs.length() == 0 {
        return None
      }
      // Insert i32.const followed by i64.add - guaranteed type error
      let new_instrs = [I32Const(I32(42)), I64Add]
      for i in instrs {
        new_instrs.push(i)
      }
      Some(Expr(new_instrs))
    }),
  }
}

///|
/// Replace all ref types with definitely incompatible ones
fn make_reftype_corruption_transformer() -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_reftype: Some(fn(rt : RefType) -> RefType? {
      // Replace any ref type with non-null noextern - very restrictive
      match rt {
        HeapTypeRefType(true, _) =>
          // If nullable, make it non-null bottom type
          Some(HeapTypeRefType(false, AbsHeapTypeHeapType(NoExternAbsHeapType)))
        HeapTypeRefType(false, AbsHeapTypeHeapType(NoExternAbsHeapType)) =>
          // Already our target, swap to something else
          Some(HeapTypeRefType(false, AbsHeapTypeHeapType(NoFuncAbsHeapType)))
        _ =>
          Some(HeapTypeRefType(false, AbsHeapTypeHeapType(NoExternAbsHeapType)))
      }
    }),
  }
}

///|
/// Swap numeric types to cause type mismatches
fn make_numtype_swap_transformer() -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_valtype: Some(fn(vt : ValType) -> ValType? {
      match vt {
        NumTypeValType(I32NumType) => Some(NumTypeValType(I64NumType))
        NumTypeValType(I64NumType) => Some(NumTypeValType(I32NumType))
        NumTypeValType(F32NumType) => Some(NumTypeValType(F64NumType))
        NumTypeValType(F64NumType) => Some(NumTypeValType(F32NumType))
        _ => None // Use default recursion for ref types
      }
    }),
  }
}

///|
/// Replace all numeric types with a specific type
fn make_numtype_replace_transformer(target : NumType) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_valtype: Some(fn(vt : ValType) -> ValType? {
      match vt {
        NumTypeValType(_) => Some(NumTypeValType(target))
        _ => None
      }
    }),
  }
}

///|
/// Flip nullability on reference types
fn make_nullability_flip_transformer() -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_reftype: Some(fn(rt : RefType) -> RefType? {
      match rt {
        HeapTypeRefType(nullable, ht) =>
          Some(HeapTypeRefType(not(nullable), ht))
        AbsHeapTypeRefType(_) => None
      }
    }),
  }
}

///|
/// Replace concrete heap types with incompatible abstract ones
fn make_heaptype_abstract_transformer(
  target : AbsHeapType,
) -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_heaptype: Some(fn(ht : HeapType) -> HeapType? {
      match ht {
        HeapType(_) => Some(AbsHeapTypeHeapType(target))
        _ => None
      }
    }),
  }
}

///|
/// Swap func/extern heap types (causes major type errors)
fn make_heaptype_swap_transformer() -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_heaptype: Some(fn(ht) {
      match ht {
        AbsHeapTypeHeapType(FuncAbsHeapType) =>
          Some(AbsHeapTypeHeapType(ExternAbsHeapType))
        AbsHeapTypeHeapType(ExternAbsHeapType) =>
          Some(AbsHeapTypeHeapType(FuncAbsHeapType))
        AbsHeapTypeHeapType(AnyAbsHeapType) =>
          Some(AbsHeapTypeHeapType(FuncAbsHeapType))
        _ => None
      }
    }),
  }
}

///|
/// Replace instructions with type-incompatible variants
fn make_instruction_type_mismatch_transformer() -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_instruction: Some(fn(instr : Instruction) -> Instruction? {
      match instr {
        // Swap 32/64-bit variants
        I32Const(v) => Some(I64Const(I64(v.0.to_int64())))
        I64Const(v) => Some(I32Const(I32(v.0.to_int())))
        F32Const(_) => Some(I32Const(I32(0)))
        F64Const(_) => Some(I64Const(I64(0L)))

        // Swap load/store sizes
        I32Load(m) => Some(I64Load(m))
        I64Load(m) => Some(I32Load(m))

        // Swap local operations with global (likely wrong index space)
        LocalGet(LocalIdx(i)) => Some(GlobalGet(GlobalIdx(i)))
        GlobalGet(GlobalIdx(i)) => Some(LocalGet(LocalIdx(i)))
        _ => None
      }
    }),
  }
}

///|
/// Insert stack-underflow-causing transformations
fn make_drop_insertion_transformer() -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_instruction: Some(fn(instr) {
      match instr {
        // Add extra drop before operations that need values
        I32Add => Some(Drop)
        I64Add => Some(Drop)
        Call(_) => Some(Drop)
        _ => None
      }
    }),
  }
}

///|
/// Remove block ends / corrupt block structure
fn make_block_corruption_transformer() -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_expr: Some(fn(expr : Expr) -> Expr? {
      let Expr(instrs) = expr
      if instrs.length() > 0 {
        // Remove last instruction (often corrupts block structure)
        Some(Expr(instrs.iter().take(instrs.length() - 1).collect()))
      } else {
        None
      }
    }),
  }
}

///|
fn make_blocktype_mismatch_transformer() -> ModuleTransformer {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_blocktype: Some(fn(bt) -> BlockType? {
      match bt {
        EmptyBlockType => Some(ValTypeBlockType(NumTypeValType(I32NumType)))
        ValTypeBlockType(NumTypeValType(I32NumType)) =>
          Some(ValTypeBlockType(NumTypeValType(I64NumType)))
        ValTypeBlockType(_) => Some(EmptyBlockType)
        TypeIdxBlockType(TypeIdx(i)) => Some(TypeIdxBlockType(TypeIdx(i + 1)))
        TypeIdxBlockType(RecIdx(i)) => Some(TypeIdxBlockType(RecIdx(i + 1)))
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
}

///|
fn get_transformer(strategy : InvalidationStrategy) -> ModuleTransformer {
  match strategy {
    FuncIdxOOB(n) => make_funcidx_oob_transformer(n)
    TypeIdxOOB(n) => make_typeidx_oob_transformer(n)
    LocalIdxOOB(n) => make_localidx_oob_transformer(n)
    GlobalIdxOOB(n) => make_globalidx_oob_transformer(n)
    LabelIdxOOB(n) => make_labelidx_oob_transformer(n)
    TableIdxOOB(n) => make_tableidx_oob_transformer(n)
    MemIdxOOB(n) => make_memidx_oob_transformer(n)
    DataIdxOOB(n) => make_dataidx_oob_transformer(n)
    ElemIdxOOB(n) => make_elemidx_oob_transformer(n)
    TagIdxOOB(n) => make_tagidx_oob_transformer(n)
    NumTypeSwap => make_numtype_swap_transformer()
    NullabilityFlip => make_nullability_flip_transformer()
    HeapTypeSwap => make_reftype_corruption_transformer() // Use stronger version
    InstructionTypeMismatch => make_type_corruption_transformer() // Use stronger version
    BlockTypeMismatch => make_blocktype_mismatch_transformer()
    DropInsertion => make_type_corruption_transformer() // Use stronger version
    BlockCorruption => make_block_corruption_transformer()
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
  }
}

///|
/// Run invalidation fuzzing on a valid module
fn fuzz_invalid_module(
  valid_module : Module,
  strategy : InvalidationStrategy,
) -> Result[Unit, String] {
  let transformer = get_transformer(strategy)
  let invalid_module = transformer.walk_module(valid_module)

  // The validation should FAIL - if it passes, that's a bug!
  match validate_module(invalid_module) {
    Ok(_) =>
      Err(
        "Validator accepted invalid module with strategy: " +
        strategy.to_string(),
      )
    Err(_) => Ok(()) // Expected - validation correctly rejected
  }
}

///|
/// Result of testing a single strategy: (strategy_name, was_actually_tested, validation_correctly_rejected)
fn fuzz_invalid_module_with_coverage(
  valid_module : Module,
  strategy : InvalidationStrategy,
) -> (String, Bool, Bool) {
  let strategy_name = strategy.to_string()
  let transformer = get_transformer(strategy)
  let invalid_module = transformer.walk_module(valid_module)

  // If the transformation didn't actually change anything, skip this test.
  if invalid_module == valid_module {
    return (strategy_name, false, true) // Not tested, but not a failure
  }

  // The validation should FAIL - if it passes, that's a bug!
  match validate_module(invalid_module) {
    Ok(_) => (strategy_name, true, false) // Tested, but validation incorrectly accepted
    Err(_) => (strategy_name, true, true) // Tested and correctly rejected
  }
}

///|
/// Run all invalidation strategies on a module with coverage tracking
/// Returns array of (strategy_name, was_tested, passed)
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
  ]
  let results : Array[(String, Bool, Bool)] = []
  for strategy in strategies {
    results.push(fuzz_invalid_module_with_coverage(valid_module, strategy))
  }
  results
}

///|
test "invalidation fuzzing with coverage" {
  let rnd = @quickcheck/splitmix.new()

  // Track statistics per strategy
  let tested_count : Map[String, Int] = {}
  let rejected_count : Map[String, Int] = {} // validator correctly rejected
  let strategy_names = [
    "FuncIdxOOB", "TypeIdxOOB", "LocalIdxOOB", "GlobalIdxOOB", "LabelIdxOOB", "TableIdxOOB",
    "MemIdxOOB", "DataIdxOOB", "ElemIdxOOB", "TagIdxOOB", "NumTypeSwap", "NullabilityFlip",
    "HeapTypeSwap", "InstructionTypeMismatch", "BlockTypeMismatch", "DropInsertion",
    "BlockCorruption",
  ]
  for s in strategy_names {
    tested_count[s] = 0
    rejected_count[s] = 0
  }

  // Run multiple iterations
  for _ in 0..<100 {
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
        let base_name = normalize_strategy_name(strategy_name)
        tested_count[base_name] = tested_count.get(base_name).or(0) + 1
        if passed {
          rejected_count[base_name] = rejected_count.get(base_name).or(0) + 1
        }
      }
    }
  }

  // Check results - strategies should reject most of the time when tested
  let problems : Array[String] = []
  for s in strategy_names {
    let tested = tested_count.get(s).or(0)
    let rejected = rejected_count.get(s).or(0)
    if tested >= 10 {
      // If tested enough times, should reject at least 80% of the time
      let reject_rate = rejected * 100 / tested
      if reject_rate < 80 {
        problems.push(
          s +
          ": only " +
          reject_rate.to_string() +
          "% rejected (" +
          rejected.to_string() +
          "/" +
          tested.to_string() +
          ")",
        )
      }
    }
  }
  if problems.length() > 0 {
    fail(
      "Strategies with low rejection rate (potential validator bugs):\n  " +
      problems
      .iter()
      .fold(init="", fn(acc, s) { if acc == "" { s } else { acc + "\n  " + s } }),
    )
  }
}

///|
/// Normalize strategy names by removing offset numbers
fn normalize_strategy_name(name : String) -> String {
  // The OOB strategies all end with "OOB" - we want to track them together
  if name.contains("OOB") {
    // Find the base name without the offset parameter
    for
      base in [
        "FuncIdxOOB", "TypeIdxOOB", "LocalIdxOOB", "GlobalIdxOOB", "LabelIdxOOB",
        "TableIdxOOB", "MemIdxOOB", "DataIdxOOB", "ElemIdxOOB", "TagIdxOOB",
      ] {
      if name.contains(base.substring(end=base.length() - 3)) {
        return base
      }
    }
  }
  name
}
