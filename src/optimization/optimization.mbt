///|
pub(all) enum BinaryenPass {
  AbstractTypeRefining
  AlignmentLowering
  Asyncify
  AvoidReinterprets
  CoalesceLocals
  CodeFolding
  CodePushing
  ConstHoisting
  ConstantFieldPropagation
  DWARF
  DataFlowOpts
  DeAlign
  DeNaN
  DeadArgumentElimination
  DeadArgumentElimination2
  DeadCodeElimination
  DebugLocationPropagation
  Directize
  DuplicateFunctionElimination
  DuplicateImportElimination
  EncloseWorld
  ExtractFunction
  Flatten
  FuncCastEmulation
  GUFA
  GenerateDynCalls
  GlobalEffects
  GlobalRefining
  GlobalStructInference
  GlobalTypeOptimization
  Heap2Local
  HeapStoreOptimization
  I64ToI32Lowering
  Inlining
  InstrumentBranchHints
  InstrumentLocals
  InstrumentMemory
  Intrinsics
  J2CLItableMerging
  J2CLOpts
  LLVMMemoryCopyFillLowering
  LLVMNontrappingFPToIntLowering
  LegalizeJSInterface
  LimitSegments
  LocalCSE
  LocalSubtyping
  LogExecution
  LoopInvariantCodeMotion
  Memory64Lowering
  MemoryPacking
  MergeBlocks
  MergeLocals
  MergeSimilarFunctions
  Metrics
  MinifyImportsAndExports
  MinimizeRecGroups
  Monomorphize
  MultiMemoryLowering
  NameList
  NameTypes
  NoInline
  OptimizeAddedConstants
  OptimizeCasts
  OptimizeForJS
  OptimizeInstructions
  Outlining
  PickLoadSigns
  Poppify
  PostEmscripten
  Precompute
  Print
  PrintCallGraph
  PrintFeatures
  PrintFunctionMap
  RandomizeBranchHints
  ReReloop
  RedundantSetElimination
  RemoveImports
  RemoveMemoryInit
  RemoveNonJSOps
  RemoveRelaxedSIMD
  RemoveUnusedBrs
  RemoveUnusedModuleElements
  RemoveUnusedNames
  RemoveUnusedTypes
  ReorderFunctions
  ReorderGlobals
  ReorderLocals
  ReorderTypes
  RoundTrip
  SSAify
  SafeHeap
  SeparateDataSegments
  SetGlobals
  SignExtLowering
  SignaturePruning
  SignatureRefining
  SimplifyGlobals
  SimplifyLocals
  Souperify
  SpillPointers
  StackCheck
  StringLifting
  StringLowering
  Strip
  StripEH
  StripTargetFeatures
  StripToolchainAnnotations
  TraceCalls
  TranslateEH
  TrapMode
  TupleOptimization
  TypeFinalizing
  TypeGeneralizing
  TypeMerging
  TypeRefining
  TypeSSA
  Unsubtyping
  Untee
  Vacuum
} derive(Eq, Show, Debug)

///|
pub fn all_binaryen_passes() -> Array[BinaryenPass] {
  [
    BinaryenPass::AbstractTypeRefining,
    BinaryenPass::AlignmentLowering,
    BinaryenPass::Asyncify,
    BinaryenPass::AvoidReinterprets,
    BinaryenPass::CoalesceLocals,
    BinaryenPass::CodeFolding,
    BinaryenPass::CodePushing,
    BinaryenPass::ConstHoisting,
    BinaryenPass::ConstantFieldPropagation,
    BinaryenPass::DWARF,
    BinaryenPass::DataFlowOpts,
    BinaryenPass::DeAlign,
    BinaryenPass::DeNaN,
    BinaryenPass::DeadArgumentElimination,
    BinaryenPass::DeadArgumentElimination2,
    BinaryenPass::DeadCodeElimination,
    BinaryenPass::DebugLocationPropagation,
    BinaryenPass::Directize,
    BinaryenPass::DuplicateFunctionElimination,
    BinaryenPass::DuplicateImportElimination,
    BinaryenPass::EncloseWorld,
    BinaryenPass::ExtractFunction,
    BinaryenPass::Flatten,
    BinaryenPass::FuncCastEmulation,
    BinaryenPass::GUFA,
    BinaryenPass::GenerateDynCalls,
    BinaryenPass::GlobalEffects,
    BinaryenPass::GlobalRefining,
    BinaryenPass::GlobalStructInference,
    BinaryenPass::GlobalTypeOptimization,
    BinaryenPass::Heap2Local,
    BinaryenPass::HeapStoreOptimization,
    BinaryenPass::I64ToI32Lowering,
    BinaryenPass::Inlining,
    BinaryenPass::InstrumentBranchHints,
    BinaryenPass::InstrumentLocals,
    BinaryenPass::InstrumentMemory,
    BinaryenPass::Intrinsics,
    BinaryenPass::J2CLItableMerging,
    BinaryenPass::J2CLOpts,
    BinaryenPass::LLVMMemoryCopyFillLowering,
    BinaryenPass::LLVMNontrappingFPToIntLowering,
    BinaryenPass::LegalizeJSInterface,
    BinaryenPass::LimitSegments,
    BinaryenPass::LocalCSE,
    BinaryenPass::LocalSubtyping,
    BinaryenPass::LogExecution,
    BinaryenPass::LoopInvariantCodeMotion,
    BinaryenPass::Memory64Lowering,
    BinaryenPass::MemoryPacking,
    BinaryenPass::MergeBlocks,
    BinaryenPass::MergeLocals,
    BinaryenPass::MergeSimilarFunctions,
    BinaryenPass::Metrics,
    BinaryenPass::MinifyImportsAndExports,
    BinaryenPass::MinimizeRecGroups,
    BinaryenPass::Monomorphize,
    BinaryenPass::MultiMemoryLowering,
    BinaryenPass::NameList,
    BinaryenPass::NameTypes,
    BinaryenPass::NoInline,
    BinaryenPass::OptimizeAddedConstants,
    BinaryenPass::OptimizeCasts,
    BinaryenPass::OptimizeForJS,
    BinaryenPass::OptimizeInstructions,
    BinaryenPass::Outlining,
    BinaryenPass::PickLoadSigns,
    BinaryenPass::Poppify,
    BinaryenPass::PostEmscripten,
    BinaryenPass::Precompute,
    BinaryenPass::Print,
    BinaryenPass::PrintCallGraph,
    BinaryenPass::PrintFeatures,
    BinaryenPass::PrintFunctionMap,
    BinaryenPass::RandomizeBranchHints,
    BinaryenPass::ReReloop,
    BinaryenPass::RedundantSetElimination,
    BinaryenPass::RemoveImports,
    BinaryenPass::RemoveMemoryInit,
    BinaryenPass::RemoveNonJSOps,
    BinaryenPass::RemoveRelaxedSIMD,
    BinaryenPass::RemoveUnusedBrs,
    BinaryenPass::RemoveUnusedModuleElements,
    BinaryenPass::RemoveUnusedNames,
    BinaryenPass::RemoveUnusedTypes,
    BinaryenPass::ReorderFunctions,
    BinaryenPass::ReorderGlobals,
    BinaryenPass::ReorderLocals,
    BinaryenPass::ReorderTypes,
    BinaryenPass::RoundTrip,
    BinaryenPass::SSAify,
    BinaryenPass::SafeHeap,
    BinaryenPass::SeparateDataSegments,
    BinaryenPass::SetGlobals,
    BinaryenPass::SignExtLowering,
    BinaryenPass::SignaturePruning,
    BinaryenPass::SignatureRefining,
    BinaryenPass::SimplifyGlobals,
    BinaryenPass::SimplifyLocals,
    BinaryenPass::Souperify,
    BinaryenPass::SpillPointers,
    BinaryenPass::StackCheck,
    BinaryenPass::StringLifting,
    BinaryenPass::StringLowering,
    BinaryenPass::Strip,
    BinaryenPass::StripEH,
    BinaryenPass::StripTargetFeatures,
    BinaryenPass::StripToolchainAnnotations,
    BinaryenPass::TraceCalls,
    BinaryenPass::TranslateEH,
    BinaryenPass::TrapMode,
    BinaryenPass::TupleOptimization,
    BinaryenPass::TypeFinalizing,
    BinaryenPass::TypeGeneralizing,
    BinaryenPass::TypeMerging,
    BinaryenPass::TypeRefining,
    BinaryenPass::TypeSSA,
    BinaryenPass::Unsubtyping,
    BinaryenPass::Untee,
    BinaryenPass::Vacuum,
  ]
}

///|
pub(all) enum TraceLevel {
  Silent
  PassGroup
  PerFunc
  PerHelper
} derive(Eq, Show, Debug)

///|
pub fn TraceLevel::silent() -> TraceLevel {
  Silent
}

///|
pub fn TraceLevel::pass_group() -> TraceLevel {
  PassGroup
}

///|
pub fn TraceLevel::per_func() -> TraceLevel {
  PerFunc
}

///|
pub fn TraceLevel::per_helper() -> TraceLevel {
  PerHelper
}

///|
pub(all) enum ValidationKind {
  Unchecked
  Shape
  Full
} derive(Eq, Show, Debug)

///|
pub fn ValidationKind::unchecked() -> ValidationKind {
  Unchecked
}

///|
pub fn ValidationKind::shape() -> ValidationKind {
  Shape
}

///|
pub fn ValidationKind::full() -> ValidationKind {
  Full
}

///|
pub(all) struct PipelineGlobal {
  opt_level : Int
  shrink_level : Int
  validate : Bool
  trace : TraceLevel
  max_iterations : Int
} derive(Eq, Show, Debug)

///|
pub fn PipelineGlobal::new(
  opt_level? : Int = 0,
  shrink_level? : Int = 0,
  validate? : Bool = false,
  trace? : TraceLevel = TraceLevel::silent(),
  max_iterations? : Int = 1,
) -> PipelineGlobal {
  { opt_level, shrink_level, validate, trace, max_iterations }
}

///|
pub(all) struct PipelineScratch {
  mut changed : Bool
  mut func_idx : Int?
  mut funcs_visited : Int
  mut funcs_changed : Int
  mut module_shape_changed : Bool
  mut call_graph_dirty : Bool
  mut locals_dirty : Bool
} derive(Debug)

///|
pub fn PipelineScratch::new(
  changed? : Bool = false,
  func_idx? : Int? = None,
  funcs_visited? : Int = 0,
  funcs_changed? : Int = 0,
  module_shape_changed? : Bool = false,
  call_graph_dirty? : Bool = false,
  locals_dirty? : Bool = false,
) -> PipelineScratch {
  {
    changed,
    func_idx,
    funcs_visited,
    funcs_changed,
    module_shape_changed,
    call_graph_dirty,
    locals_dirty,
  }
}

///|
pub fn PipelineScratch::reset(self : PipelineScratch) -> Unit {
  self.changed = false
  self.func_idx = None
  self.funcs_visited = 0
  self.funcs_changed = 0
  self.module_shape_changed = false
  self.call_graph_dirty = false
  self.locals_dirty = false
}

///|
pub type EarlyPassFn = (Module, PipelineGlobal) -> (Module, PipelineGlobal)

///|
pub type FuncLocalPassFn = (Module, PipelineScratch) -> (
  Module,
  PipelineScratch,
)

///|
pub type ModuleWidePassFn = (Module, PipelineGlobal, PipelineFeatures) -> (
  Module,
  PipelineGlobal,
)

///|
pub(all) enum PassKind {
  Early(EarlyPassFn)
  FuncLocalGroup(Array[FuncLocalPassFn])
  ModuleWide(ModuleWidePassFn)
}

///|
pub fn PassKind::early(func : EarlyPassFn) -> PassKind {
  Early(func)
}

///|
pub fn PassKind::func_local_group(funcs : Array[FuncLocalPassFn]) -> PassKind {
  FuncLocalGroup(funcs)
}

///|
pub fn PassKind::module_wide(func : ModuleWidePassFn) -> PassKind {
  ModuleWide(func)
}

///|
pub(all) struct PassGroup(PassKind, ValidationKind)

///|
pub fn PassGroup::new(
  kind : PassKind,
  validation_kind : ValidationKind,
) -> PassGroup {
  PassGroup(kind, validation_kind)
}

///|
pub fn PassGroup::kind(self : PassGroup) -> PassKind {
  match self {
    PassGroup(kind, _) => kind
  }
}

///|
pub fn PassGroup::validation_kind(self : PassGroup) -> ValidationKind {
  match self {
    PassGroup(_, validation_kind) => validation_kind
  }
}

///|
pub(all) struct PipelineFeatures {
  has_gc : Bool
  has_multivalue : Bool
  has_strings : Bool
  closed_world : Bool
  zero_filled_memory : Bool
  low_memory_unused : Bool
  traps_never_happen : Bool
} derive(Eq, Show, Debug)

///|
pub fn PipelineFeatures::new(
  has_gc? : Bool = false,
  has_multivalue? : Bool = false,
  has_strings? : Bool = false,
  closed_world? : Bool = false,
  zero_filled_memory? : Bool = false,
  low_memory_unused? : Bool = false,
  traps_never_happen? : Bool = false,
) -> PipelineFeatures {
  {
    has_gc,
    has_multivalue,
    has_strings,
    closed_world,
    zero_filled_memory,
    low_memory_unused,
    traps_never_happen,
  }
}

///|
pub(all) enum OptimizePass {
  DuplicateFunctionElimination
  RemoveUnusedModuleElements
  MemoryPacking
  OnceReduction
  TypeRefining
  SignaturePruning
  SignatureRefining
  GlobalRefining
  GlobalTypeOptimization
  RemoveUnusedTypes
  ConstantFieldPropagation
  ConstantFieldPropagationRefTest
  GlobalStructInference
  AbstractTypeRefining
  Unsubtyping
  SSANoMerge
  Flatten
  SimplifyLocalsNoTeeNoStructure
  LocalCSE
  DeadCodeElimination
  RemoveUnusedNames
  RemoveUnusedBrs
  OptimizeInstructions
  HeapStoreOptimization
  PickLoadSigns
  Precompute
  PrecomputePropagate
  OptimizeAddedConstants
  OptimizeAddedConstantsPropagate
  CodePushing
  TupleOptimization
  SimplifyLocalsNoStructure
  Vacuum
  ReorderLocals
  Heap2Local
  MergeLocals
  OptimizeCasts
  LocalSubtyping
  CoalesceLocals
  SimplifyLocals
  CodeFolding
  MergeBlocks
  RedundantSetElimination
  DeadArgumentEliminationOptimizing
  InliningOptimizing
  DuplicateImportElimination
  MergeSimilarFunctions
  SimplifyGlobals
  SimplifyGlobalsOptimizing
  StringGathering
  ReorderGlobals
  Directize
} derive(Eq, Show, Debug)

///|
pub(all) struct PipelineEntry {
  passes : Array[OptimizePass]
  group : PassGroup
}

///|
pub fn PipelineEntry::new(
  passes : Array[OptimizePass],
  group : PassGroup,
) -> PipelineEntry {
  { passes, group }
}

///|
priv enum OptimizePassClass {
  FuncLocal
  ModuleWide
}

///|
fn noop_early_pass(
  mod : Module,
  global : PipelineGlobal,
) -> (Module, PipelineGlobal) {
  (mod, global)
}

///|
fn noop_func_local_pass(
  mod : Module,
  scratch : PipelineScratch,
) -> (Module, PipelineScratch) {
  (mod, scratch)
}

///|
fn noop_module_wide_pass(
  mod : Module,
  global : PipelineGlobal,
  features : PipelineFeatures,
) -> (Module, PipelineGlobal) {
  let _ = features
  (mod, global)
}

///|
pub fn run_dead_code_elimination(
  mod : Module,
  scratch : PipelineScratch,
) -> (Module, PipelineScratch) {
  let funcs = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs
    None => return (mod, scratch)
  }

  let rewritten_funcs : Array[Func] = []
  let mut changed = false
  let mut funcs_visited = scratch.funcs_visited
  let mut funcs_changed = scratch.funcs_changed
  for func in funcs {
    funcs_visited += 1
    let (rewritten, func_changed) = optimization_dead_code_elimination_func(
      func,
    )
    rewritten_funcs.push(rewritten)
    if func_changed {
      changed = true
      funcs_changed += 1
    }
  }

  let next_scratch = PipelineScratch::new(
    changed=scratch.changed || changed,
    func_idx=None,
    funcs_visited~,
    funcs_changed~,
    module_shape_changed=scratch.module_shape_changed,
    call_graph_dirty=scratch.call_graph_dirty,
    locals_dirty=scratch.locals_dirty,
  )
  if changed {
    (mod.with_code_sec(CodeSec::new(rewritten_funcs)), next_scratch)
  } else {
    (mod, next_scratch)
  }
}

///|
fn optimization_dead_code_elimination_func(func : Func) -> (Func, Bool) {
  match func {
    @lib.TFunc(params, locals, body) => {
      let transformer : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
        .on_texpr_evt(fn(self, _, expr) {
          let (rewritten, _) = self.walk_texpr_default((), expr).unwrap()
          change(
            (),
            @lib.TExpr::new(
              optimization_dead_code_elimination_truncate_after_first_unreachable(
                rewritten.inner(),
              ),
            ),
          )
        })
        .on_tinstruction_evt(fn(self, _, instr) {
          let (rewritten, _) = self
            .walk_tinstruction_default((), instr)
            .unwrap()
          change(
            (),
            optimization_dead_code_elimination_rewrite_instr(rewritten),
          )
        })
      match transformer.walk_texpr((), body) {
        Ok((rewritten_body, _)) =>
          if rewritten_body == body {
            (func, false)
          } else {
            (@lib.Func::t_func(params, locals, rewritten_body), true)
          }
        Err(_) => (func, false)
      }
    }
    _ => (func, false)
  }
}

///|
fn optimization_dead_code_elimination_rewrite_instr(
  instr : @lib.TInstr,
) -> @lib.TInstr {
  match instr.kind {
    @lib.TBlock(block_type, body) =>
      optimization_dead_code_elimination_rewrite_block(block_type, body)
    @lib.TLoop(block_type, body) =>
      optimization_dead_code_elimination_rewrite_loop(block_type, body)
    @lib.TTryTable(block_type, catches, body) =>
      optimization_dead_code_elimination_rewrite_try_table(
        block_type, catches, body,
      )
    @lib.TBr(label, values) =>
      optimization_dead_code_elimination_rewrite_unary(values, fn(args) {
        @lib.TInstr::br(label, args)
      })
    @lib.TBrIf(label, cond, values) =>
      optimization_dead_code_elimination_rewrite_branch_if(label, cond, values)
    @lib.TBrTable(labels, default_label, idx, values) =>
      optimization_dead_code_elimination_rewrite_branch_table(
        labels, default_label, idx, values,
      )
    @lib.TBrOnNull(label, ref_, values) =>
      optimization_dead_code_elimination_rewrite_branch_on_ref(values, ref_, fn(
        values,
        ref_,
      ) {
        @lib.TInstr::br_on_null(label, ref_, values)
      })
    @lib.TBrOnNonNull(label, ref_, values) =>
      optimization_dead_code_elimination_rewrite_branch_on_ref(values, ref_, fn(
        values,
        ref_,
      ) {
        @lib.TInstr::br_on_non_null(label, ref_, values)
      })
    @lib.TBrOnCast(label, cast_op, ht0, ht1, ref_, values) =>
      optimization_dead_code_elimination_rewrite_branch_on_ref(values, ref_, fn(
        values,
        ref_,
      ) {
        let @lib.CastOp(source_nullable, target_nullable) = cast_op
        @lib.TInstr::br_on_cast(
          label, source_nullable, ht0, target_nullable, ht1, ref_, values,
        )
      })
    @lib.TBrOnCastFail(label, cast_op, ht0, ht1, ref_, values) =>
      optimization_dead_code_elimination_rewrite_branch_on_ref(values, ref_, fn(
        values,
        ref_,
      ) {
        let @lib.CastOp(source_nullable, target_nullable) = cast_op
        @lib.TInstr::br_on_cast_fail(
          label, source_nullable, ht0, target_nullable, ht1, ref_, values,
        )
      })
    @lib.TIf(block_type, cond, then_body, else_body) =>
      optimization_dead_code_elimination_rewrite_if(
        block_type, cond, then_body, else_body,
      )
    @lib.TUnary(op, child) =>
      optimization_dead_code_elimination_rewrite_unary([child], fn(args) {
        @lib.TInstr::unary(op, args[0])
      })
    @lib.TDrop(child) =>
      optimization_dead_code_elimination_rewrite_unary([child], fn(args) {
        @lib.TInstr::drop(args[0])
      })
    @lib.TLocalSet(idx, child) =>
      optimization_dead_code_elimination_rewrite_unary([child], fn(args) {
        @lib.TInstr::local_set(idx, args[0])
      })
    @lib.TLocalTee(idx, child) =>
      optimization_dead_code_elimination_rewrite_unary([child], fn(args) {
        @lib.TInstr::local_tee(idx, args[0])
      })
    @lib.TGlobalSet(idx, child) =>
      optimization_dead_code_elimination_rewrite_unary([child], fn(args) {
        @lib.TInstr::global_set(idx, args[0])
      })
    @lib.TLoad(op, memarg, child) =>
      optimization_dead_code_elimination_rewrite_unary([child], fn(args) {
        @lib.TInstr::load(op, memarg, args[0])
      })
    @lib.TRefTest(nullable, ht, child) =>
      optimization_dead_code_elimination_rewrite_unary([child], fn(args) {
        @lib.TInstr::ref_test(nullable, ht, args[0])
      })
    @lib.TRefCast(nullable, ht, child) =>
      optimization_dead_code_elimination_rewrite_unary([child], fn(args) {
        @lib.TInstr::ref_cast(nullable, ht, args[0])
      })
    @lib.TRefTestDesc(nullable, ht, child) =>
      optimization_dead_code_elimination_rewrite_unary([child], fn(args) {
        @lib.TInstr::ref_test_desc(nullable, ht, args[0])
      })
    @lib.TRefCastDescEq(nullable, ht, child) =>
      optimization_dead_code_elimination_rewrite_unary([child], fn(args) {
        @lib.TInstr::ref_cast_desc_eq(nullable, ht, args[0])
      })
    @lib.TBinary(op, left, right) =>
      optimization_dead_code_elimination_rewrite_unary([left, right], fn(args) {
        @lib.TInstr::binary(op, args[0], args[1])
      })
    @lib.TRefEq(left, right) =>
      optimization_dead_code_elimination_rewrite_unary([left, right], fn(args) {
        @lib.TInstr::ref_eq(args[0], args[1])
      })
    @lib.TStore(op, memarg, addr, value) =>
      optimization_dead_code_elimination_rewrite_unary([addr, value], fn(args) {
        @lib.TInstr::store(op, memarg, args[0], args[1])
      })
    @lib.TCall(func_idx, args) =>
      optimization_dead_code_elimination_rewrite_unary(args, fn(args) {
        @lib.TInstr::call(func_idx, args)
      })
    @lib.TSelect(type_hint, cond, if_true, if_false) =>
      match
        optimization_dead_code_elimination_preserve_prefix_effects_then_unreachable([
            if_true, if_false, cond,
          ],
        ) {
        Some(rewritten) => rewritten
        None => @lib.TInstr::select(type_hint, cond, if_true, if_false)
      }
    _ => instr
  }
}

///|
fn optimization_dead_code_elimination_rewrite_branch_on_ref(
  values : Array[@lib.TInstr],
  ref_ : @lib.TInstr,
  rebuild : (Array[@lib.TInstr], @lib.TInstr) -> @lib.TInstr,
) -> @lib.TInstr {
  let children : Array[@lib.TInstr] = values.copy()
  children.push(ref_)
  match
    optimization_dead_code_elimination_preserve_prefix_effects_then_unreachable(
      children,
    ) {
    Some(rewritten) => rewritten
    None => rebuild(values, ref_)
  }
}

///|
fn optimization_dead_code_elimination_rewrite_branch_if(
  label : @lib.LabelIdx,
  cond : @lib.TInstr,
  values : Array[@lib.TInstr],
) -> @lib.TInstr {
  let children : Array[@lib.TInstr] = values.copy()
  children.push(cond)
  match
    optimization_dead_code_elimination_preserve_prefix_effects_then_unreachable(
      children,
    ) {
    Some(rewritten) => rewritten
    None => @lib.TInstr::br_if(label, cond, values)
  }
}

///|
fn optimization_dead_code_elimination_rewrite_branch_table(
  labels : Array[@lib.LabelIdx],
  default_label : @lib.LabelIdx,
  idx : @lib.TInstr,
  values : Array[@lib.TInstr],
) -> @lib.TInstr {
  let children : Array[@lib.TInstr] = values.copy()
  children.push(idx)
  match
    optimization_dead_code_elimination_preserve_prefix_effects_then_unreachable(
      children,
    ) {
    Some(rewritten) => rewritten
    None => @lib.TInstr::br_table(labels, default_label, idx, values)
  }
}

///|
fn optimization_dead_code_elimination_rewrite_try_table(
  block_type : @lib.BlockType,
  catches : Array[@lib.Catch],
  body : @lib.TExpr,
) -> @lib.TInstr {
  if optimization_dead_code_elimination_expr_is_unreachable(body) &&
    optimization_dead_code_elimination_block_type_is_concrete(block_type) {
    @lib.TInstr::try_table(@lib.BlockType::void_(), catches, body)
  } else {
    @lib.TInstr::try_table(block_type, catches, body)
  }
}

///|
fn optimization_dead_code_elimination_rewrite_loop(
  block_type : @lib.BlockType,
  body : @lib.TExpr,
) -> @lib.TInstr {
  match body.inner() {
    [child] =>
      match child.kind {
        @lib.TUnreachable => child
        _ => @lib.TInstr::loop_(block_type, body)
      }
    _ => @lib.TInstr::loop_(block_type, body)
  }
}

///|
fn optimization_dead_code_elimination_rewrite_if(
  block_type : @lib.BlockType,
  cond : @lib.TInstr,
  then_body : @lib.TExpr,
  else_body : @lib.TExpr?,
) -> @lib.TInstr {
  if optimization_dead_code_elimination_instr_is_unreachable(cond) {
    return cond
  }
  match else_body {
    Some(else_body) =>
      if optimization_dead_code_elimination_expr_is_unreachable(then_body) &&
        optimization_dead_code_elimination_expr_is_unreachable(else_body) {
        return @lib.TInstr::if_(
          if optimization_dead_code_elimination_block_type_is_concrete(
              block_type,
            ) {
            @lib.BlockType::void_()
          } else {
            block_type
          },
          cond,
          then_body,
          Some(else_body),
        )
      }
    None => ()
  }
  @lib.TInstr::if_(block_type, cond, then_body, else_body)
}

///|
fn optimization_dead_code_elimination_rewrite_block(
  block_type : @lib.BlockType,
  body : @lib.TExpr,
) -> @lib.TInstr {
  match body.inner() {
    [child] =>
      match child.kind {
        @lib.TUnreachable => return child
        _ => ()
      }
    _ => ()
  }
  if optimization_dead_code_elimination_block_escapes_parent(block_type, body) &&
    optimization_dead_code_elimination_block_type_is_concrete(block_type) {
    match body.inner() {
      [child] => child
      _ => @lib.TInstr::block(@lib.BlockType::void_(), body)
    }
  } else {
    @lib.TInstr::block(block_type, body)
  }
}

///|
fn optimization_dead_code_elimination_rewrite_unary(
  children : Array[@lib.TInstr],
  rebuild : (Array[@lib.TInstr]) -> @lib.TInstr,
) -> @lib.TInstr {
  match
    optimization_dead_code_elimination_preserve_prefix_effects_then_unreachable(
      children,
    ) {
    Some(rewritten) => rewritten
    None => rebuild(children)
  }
}

///|
fn optimization_dead_code_elimination_preserve_prefix_effects_then_unreachable(
  children : Array[@lib.TInstr],
) -> @lib.TInstr? {
  let kept : Array[@lib.TInstr] = []
  let mut found_unreachable = false
  for child in children {
    if found_unreachable {
      continue
    }
    if optimization_dead_code_elimination_instr_is_unreachable(child) {
      kept.push(child)
      found_unreachable = true
    } else {
      kept.push(@lib.TInstr::drop(child))
    }
  }
  if !found_unreachable {
    return None
  }
  if kept.length() == 1 {
    return Some(kept[0])
  }
  Some(@lib.TInstr::block(@lib.BlockType::void_(), @lib.TExpr::new(kept)))
}

///|
fn optimization_dead_code_elimination_expr_is_unreachable(
  expr : @lib.TExpr,
) -> Bool {
  match expr.inner() {
    [] => false
    instrs =>
      optimization_dead_code_elimination_instr_is_unreachable(
        instrs[instrs.length() - 1],
      )
  }
}

///|
fn optimization_dead_code_elimination_block_type_is_concrete(
  block_type : @lib.BlockType,
) -> Bool {
  match block_type {
    @lib.VoidBlockType => false
    _ => true
  }
}

///|
fn optimization_dead_code_elimination_if_is_unreachable(
  cond : @lib.TInstr,
  then_body : @lib.TExpr,
  else_body : @lib.TExpr?,
) -> Bool {
  if optimization_dead_code_elimination_instr_is_unreachable(cond) {
    return true
  }
  match else_body {
    Some(else_body) =>
      optimization_dead_code_elimination_expr_is_unreachable(then_body) &&
      optimization_dead_code_elimination_expr_is_unreachable(else_body)
    None => false
  }
}

///|
fn optimization_dead_code_elimination_try_table_is_unreachable(
  body : @lib.TExpr,
) -> Bool {
  optimization_dead_code_elimination_expr_is_unreachable(body)
}

///|
fn optimization_dead_code_elimination_block_escapes_parent(
  block_type : @lib.BlockType,
  body : @lib.TExpr,
) -> Bool {
  let body_instrs = body.inner()
  if body_instrs.length() == 0 {
    return false
  }
  if !optimization_dead_code_elimination_instr_escapes_enclosing_expr(
      body_instrs[body_instrs.length() - 1],
    ) {
    return false
  }
  if !optimization_dead_code_elimination_block_type_is_concrete(block_type) {
    return true
  }
  !optimization_dead_code_elimination_expr_has_live_break_to_label(body, 0)
}

///|
fn optimization_dead_code_elimination_expr_has_live_break_to_label(
  expr : @lib.TExpr,
  target_depth : Int,
) -> Bool {
  for instr in expr.inner() {
    if optimization_dead_code_elimination_instr_has_live_break_to_label(
        instr, target_depth,
      ) {
      return true
    }
  }
  false
}

///|
fn optimization_dead_code_elimination_instr_has_live_break_to_label(
  instr : @lib.TInstr,
  target_depth : Int,
) -> Bool {
  let target = target_depth.reinterpret_as_uint()
  match instr.kind {
    @lib.TUnary(_, child)
    | @lib.TDrop(child)
    | @lib.TLocalSet(_, child)
    | @lib.TLocalTee(_, child)
    | @lib.TGlobalSet(_, child)
    | @lib.TLoad(_, _, child)
    | @lib.TRefGetDesc(_, child)
    | @lib.TRefTest(_, _, child)
    | @lib.TRefCast(_, _, child)
    | @lib.TRefTestDesc(_, _, child)
    | @lib.TRefCastDescEq(_, _, child) =>
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        child, target_depth,
      )
    @lib.TBinary(_, left, right)
    | @lib.TRefEq(left, right)
    | @lib.TTableSet(_, left, right)
    | @lib.TTableGrow(_, left, right)
    | @lib.TArrayNew(_, left, right)
    | @lib.TArrayGet(_, left, right)
    | @lib.TArrayGetS(_, left, right)
    | @lib.TArrayGetU(_, left, right)
    | @lib.TReplaceLane(_, _, left, right)
    | @lib.TI8x16Swizzle(left, right)
    | @lib.TI8x16RelaxedSwizzle(left, right)
    | @lib.TV128Shift(_, left, right)
    | @lib.TV128LoadLane(_, _, _, left, right)
    | @lib.TV128StoreLane(_, _, _, left, right) =>
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        left, target_depth,
      ) ||
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        right, target_depth,
      )
    @lib.TExtractLane(_, _, child) =>
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        child, target_depth,
      )
    @lib.TStore(_, _, addr, value) | @lib.TStructSet(_, _, addr, value) =>
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        addr, target_depth,
      ) ||
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        value, target_depth,
      )
    @lib.TTableGet(_, child) | @lib.TArrayNewDefault(_, child) =>
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        child, target_depth,
      )
    @lib.TSelect(_, cond, if_true, if_false) =>
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        cond, target_depth,
      ) ||
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        if_true, target_depth,
      ) ||
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        if_false, target_depth,
      )
    @lib.TCall(_, args)
    | @lib.TReturnCall(_, args)
    | @lib.TThrow(_, args)
    | @lib.TStructNew(_, args)
    | @lib.TStructNewDesc(_, args)
    | @lib.TArrayNewFixed(_, args)
    | @lib.TReturn(args) =>
      optimization_dead_code_elimination_instrs_have_live_break_to_label(
        args, target_depth,
      )
    @lib.TCallIndirect(_, _, args, idx)
    | @lib.TReturnCallIndirect(_, _, args, idx) =>
      optimization_dead_code_elimination_instrs_have_live_break_to_label(
        args, target_depth,
      ) ||
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        idx, target_depth,
      )
    @lib.TCallRef(_, args, ref_) | @lib.TReturnCallRef(_, args, ref_) =>
      optimization_dead_code_elimination_instrs_have_live_break_to_label(
        args, target_depth,
      ) ||
      optimization_dead_code_elimination_instr_has_live_break_to_label(
        ref_, target_depth,
      )
    @lib.TBlock(_, body) | @lib.TLoop(_, body) | @lib.TTryTable(_, _, body) =>
      optimization_dead_code_elimination_expr_has_live_break_to_label(
        body,
        target_depth + 1,
      )
    @lib.TIf(_, cond, then_body, else_body) => {
      if optimization_dead_code_elimination_instr_has_live_break_to_label(
          cond, target_depth,
        ) {
        return true
      }
      if optimization_dead_code_elimination_expr_has_live_break_to_label(
          then_body, target_depth,
        ) {
        return true
      }
      match else_body {
        Some(else_body) =>
          optimization_dead_code_elimination_expr_has_live_break_to_label(
            else_body, target_depth,
          )
        None => false
      }
    }
    @lib.TBr(label, values) => {
      let LabelIdx(raw) = label
      if raw == target {
        return true
      }
      optimization_dead_code_elimination_instrs_have_live_break_to_label(
        values, target_depth,
      )
    }
    @lib.TBrIf(label, cond, values) => {
      let LabelIdx(raw) = label
      if raw == target {
        return true
      }
      if optimization_dead_code_elimination_instr_has_live_break_to_label(
          cond, target_depth,
        ) {
        return true
      }
      optimization_dead_code_elimination_instrs_have_live_break_to_label(
        values, target_depth,
      )
    }
    @lib.TBrTable(labels, default_label, idx, values) => {
      let LabelIdx(default_raw) = default_label
      if default_raw == target {
        return true
      }
      for label in labels {
        let LabelIdx(raw) = label
        if raw == target {
          return true
        }
      }
      if optimization_dead_code_elimination_instr_has_live_break_to_label(
          idx, target_depth,
        ) {
        return true
      }
      optimization_dead_code_elimination_instrs_have_live_break_to_label(
        values, target_depth,
      )
    }
    @lib.TBrOnNull(label, ref_, values)
    | @lib.TBrOnNonNull(label, ref_, values)
    | @lib.TBrOnCast(label, _, _, _, ref_, values)
    | @lib.TBrOnCastFail(label, _, _, _, ref_, values) => {
      let LabelIdx(raw) = label
      if raw == target {
        return true
      }
      if optimization_dead_code_elimination_instr_has_live_break_to_label(
          ref_, target_depth,
        ) {
        return true
      }
      optimization_dead_code_elimination_instrs_have_live_break_to_label(
        values, target_depth,
      )
    }
    _ => false
  }
}

///|
fn optimization_dead_code_elimination_instrs_have_live_break_to_label(
  instrs : Array[@lib.TInstr],
  target_depth : Int,
) -> Bool {
  for instr in instrs {
    if optimization_dead_code_elimination_instr_has_live_break_to_label(
        instr, target_depth,
      ) {
      return true
    }
  }
  false
}

///|
fn optimization_dead_code_elimination_truncate_after_first_unreachable(
  instrs : Array[@lib.TInstr],
) -> Array[@lib.TInstr] {
  let kept : Array[@lib.TInstr] = []
  for instr in instrs {
    kept.push(instr)
    if optimization_dead_code_elimination_instr_terminates_current_expr(instr) {
      break
    }
  }
  kept
}

///|
fn optimization_dead_code_elimination_instr_terminates_current_expr(
  instr : @lib.TInstr,
) -> Bool {
  match instr.kind {
    @lib.TUnreachable
    | @lib.TReturn(_)
    | @lib.TReturnCall(_, _)
    | @lib.TReturnCallIndirect(_, _, _, _)
    | @lib.TReturnCallRef(_, _, _)
    | @lib.TThrow(_, _)
    | @lib.TThrowRef(_)
    | @lib.TBr(_, _)
    | @lib.TBrTable(_, _, _, _) => true
    @lib.TTryTable(_, _, body) =>
      optimization_dead_code_elimination_try_table_is_unreachable(body)
    @lib.TIf(_, cond, then_body, else_body) =>
      optimization_dead_code_elimination_if_is_unreachable(
        cond, then_body, else_body,
      )
    @lib.TBlock(block_type, body) =>
      optimization_dead_code_elimination_block_escapes_parent(block_type, body)
    _ => false
  }
}

///|
fn optimization_dead_code_elimination_instr_escapes_enclosing_expr(
  instr : @lib.TInstr,
) -> Bool {
  match instr.kind {
    @lib.TUnreachable
    | @lib.TReturn(_)
    | @lib.TReturnCall(_, _)
    | @lib.TReturnCallIndirect(_, _, _, _)
    | @lib.TReturnCallRef(_, _, _)
    | @lib.TThrow(_, _)
    | @lib.TThrowRef(_) => true
    @lib.TTryTable(_, _, body) =>
      optimization_dead_code_elimination_try_table_is_unreachable(body)
    @lib.TIf(_, cond, then_body, else_body) =>
      optimization_dead_code_elimination_if_is_unreachable(
        cond, then_body, else_body,
      )
    @lib.TBlock(block_type, body) =>
      optimization_dead_code_elimination_block_escapes_parent(block_type, body)
    _ => false
  }
}

///|
fn optimization_dead_code_elimination_instr_is_unreachable(
  instr : @lib.TInstr,
) -> Bool {
  match instr.kind {
    @lib.TUnreachable
    | @lib.TReturn(_)
    | @lib.TReturnCall(_, _)
    | @lib.TReturnCallIndirect(_, _, _, _)
    | @lib.TReturnCallRef(_, _, _)
    | @lib.TThrow(_, _)
    | @lib.TThrowRef(_)
    | @lib.TBr(_, _)
    | @lib.TBrTable(_, _, _, _) => true
    @lib.TTryTable(_, _, body) =>
      optimization_dead_code_elimination_try_table_is_unreachable(body)
    @lib.TIf(_, cond, then_body, else_body) =>
      optimization_dead_code_elimination_if_is_unreachable(
        cond, then_body, else_body,
      )
    @lib.TBlock(block_type, body) =>
      optimization_dead_code_elimination_block_escapes_parent(block_type, body)
    _ => false
  }
}

///|
pub fn run_memory_packing(
  mod : Module,
  global : PipelineGlobal,
  features : PipelineFeatures,
) -> (Module, PipelineGlobal) {
  if !optimization_memory_packing_can_optimize(mod, features) {
    return (mod, global)
  }
  let prenormalized = optimization_memory_packing_prenormalize_segment_ops(mod)
  let referrers = optimization_memory_packing_collect_referrers(prenormalized)
  let dead_removed = optimization_memory_packing_remove_dead_passive_segments(
    prenormalized, referrers,
  )
  let remaining_referrers = optimization_memory_packing_collect_referrers(
    dead_removed,
  )
  let analyses = optimization_memory_packing_analyze_ranges(
    dead_removed, remaining_referrers, features,
  )
  let (materialized, replacements) = optimization_memory_packing_materialize_segments(
    dead_removed, analyses,
  )
  let (with_drop_globals, drop_globals) = optimization_memory_packing_add_drop_state_globals(
    materialized, analyses, remaining_referrers,
  )
  (
    optimization_memory_packing_apply_replacements(
      with_drop_globals, analyses, replacements, drop_globals,
    ),
    global,
  )
}

///|
priv enum MemoryPackingSegmentReferrer {
  MemoryInit(Bool)
  DataDrop
  ArrayNewData
  ArrayInitData
} derive(Eq, Show)

///|
priv struct MemoryPackingRange {
  is_zero : Bool
  start : Int
  end : Int
} derive(Eq, Show)

///|
fn MemoryPackingRange::new(
  is_zero : Bool,
  start : Int,
  end : Int,
) -> MemoryPackingRange {
  { is_zero, start, end }
}

///|
fn MemoryPackingRange::length(self : MemoryPackingRange) -> Int {
  self.end - self.start
}

///|
let optimization_memory_packing_memory_init_size = 10

///|
let optimization_memory_packing_memory_fill_size = 9

///|
let optimization_memory_packing_data_drop_size = 3

///|
let optimization_memory_packing_active_zero_threshold = 8

///|
let optimization_memory_packing_max_data_segments = 100000

///|
fn optimization_memory_packing_defined_mem_count(mod : Module) -> Int {
  match mod.mem_sec {
    Some(MemSec(mems)) => mems.length()
    None => 0
  }
}

///|
fn optimization_memory_packing_data_segments(mod : Module) -> Array[Data] {
  match mod.data_sec {
    Some(DataSec(datas)) => datas
    None => []
  }
}

///|
fn optimization_memory_packing_active_span(data : Data) -> (UInt64, UInt64)? {
  match data {
    Data(Active(_, offset_expr), bytes) =>
      match optimization_const_expr_u64(offset_expr) {
        Some(offset) => {
          let len = bytes.length().to_uint64()
          let end = offset + len
          if end < offset {
            None
          } else {
            Some((offset, end))
          }
        }
        None => None
      }
    _ => None
  }
}

///|
fn optimization_memory_packing_active_spans_overlap(
  lhs : (UInt64, UInt64),
  rhs : (UInt64, UInt64),
) -> Bool {
  let (lhs_start, lhs_end) = lhs
  let (rhs_start, rhs_end) = rhs
  lhs_start < rhs_end && rhs_start < lhs_end
}

///|
fn optimization_memory_packing_can_optimize(
  mod : Module,
  features : PipelineFeatures,
) -> Bool {
  let total_memories = optimization_imported_mem_count(mod) +
    optimization_memory_packing_defined_mem_count(mod)
  if total_memories != 1 {
    return false
  }
  if optimization_imported_mem_count(mod) > 0 && !features.zero_filled_memory {
    return false
  }
  let datas = optimization_memory_packing_data_segments(mod)
  if datas.length() <= 1 {
    return true
  }

  let active_spans : Array[(UInt64, UInt64)] = []
  for data in datas {
    match data {
      Data(Active(_, _), _) =>
        match optimization_memory_packing_active_span(data) {
          Some(span) => {
            for other in active_spans {
              if optimization_memory_packing_active_spans_overlap(other, span) {
                return false
              }
            }
            active_spans.push(span)
          }
          None => return false
        }
      _ => ()
    }
  }
  true
}

///|
fn optimization_memory_packing_all_mem_types(
  mod : Module,
) -> Array[@lib.MemType] {
  let mems : Array[@lib.MemType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, MemExternType(mem_type)) => mems.push(mem_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod.mem_sec {
    Some(MemSec(defined_mems)) =>
      for mem in defined_mems {
        mems.push(mem)
      }
    None => ()
  }
  mems
}

///|
fn optimization_memory_packing_mem_type(
  mod : Module,
  mem_idx : @lib.MemIdx,
) -> @lib.MemType? {
  let @lib.MemIdx(raw) = mem_idx
  optimization_memory_packing_all_mem_types(mod).get(raw.reinterpret_as_int())
}

///|
fn optimization_memory_packing_data(mod : Module, data_idx : DataIdx) -> Data? {
  let DataIdx(raw) = data_idx
  match mod.data_sec {
    Some(DataSec(datas)) => datas.get(raw.reinterpret_as_int())
    None => None
  }
}

///|
fn optimization_memory_packing_collect_referrers(
  mod : Module,
) -> Array[Array[MemoryPackingSegmentReferrer]] {
  let referrers : Array[Array[MemoryPackingSegmentReferrer]] = []
  for _ in optimization_memory_packing_data_segments(mod) {
    referrers.push([])
  }
  let transformer : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_instruction_evt(fn(_, _, instr) {
      match instr {
        @lib.MemoryInit(data_idx, _) =>
          optimization_memory_packing_note_referrer(
            referrers,
            data_idx,
            MemoryPackingSegmentReferrer::MemoryInit(false),
          )
        @lib.DataDrop(data_idx) =>
          optimization_memory_packing_note_referrer(
            referrers,
            data_idx,
            MemoryPackingSegmentReferrer::DataDrop,
          )
        @lib.ArrayNewData(_, data_idx) =>
          optimization_memory_packing_note_referrer(
            referrers,
            data_idx,
            MemoryPackingSegmentReferrer::ArrayNewData,
          )
        @lib.ArrayInitData(_, data_idx) =>
          optimization_memory_packing_note_referrer(
            referrers,
            data_idx,
            MemoryPackingSegmentReferrer::ArrayInitData,
          )
        _ => ()
      }
      unchanged()
    })
    .on_tinstruction_evt(fn(_, _, instr) {
      match instr.kind {
        @lib.TMemoryInit(data_idx, _, _, offset, size) =>
          optimization_memory_packing_note_referrer(
            referrers,
            data_idx,
            MemoryPackingSegmentReferrer::MemoryInit(
              optimization_memory_packing_tinstr_const_u64(offset) is Some(_) &&
              optimization_memory_packing_tinstr_const_u64(size) is Some(_),
            ),
          )
        @lib.TDataDrop(data_idx) =>
          optimization_memory_packing_note_referrer(
            referrers,
            data_idx,
            MemoryPackingSegmentReferrer::DataDrop,
          )
        @lib.TArrayNewData(_, data_idx, _, _) =>
          optimization_memory_packing_note_referrer(
            referrers,
            data_idx,
            MemoryPackingSegmentReferrer::ArrayNewData,
          )
        @lib.TArrayInitData(_, data_idx, _, _, _, _) =>
          optimization_memory_packing_note_referrer(
            referrers,
            data_idx,
            MemoryPackingSegmentReferrer::ArrayInitData,
          )
        _ => ()
      }
      unchanged()
    })
  ignore(transformer.walk_module((), mod))
  referrers
}

///|
fn optimization_memory_packing_note_referrer(
  referrers : Array[Array[MemoryPackingSegmentReferrer]],
  data_idx : DataIdx,
  referrer : MemoryPackingSegmentReferrer,
) -> Unit {
  let DataIdx(raw) = data_idx
  let idx = raw.reinterpret_as_int()
  if idx < 0 || idx >= referrers.length() {
    return
  }
  referrers[idx].push(referrer)
}

///|
fn optimization_memory_packing_all_referrers_are_data_drop(
  referrers : Array[MemoryPackingSegmentReferrer],
) -> Bool {
  if referrers.is_empty() {
    return false
  }
  for referrer in referrers {
    if referrer != MemoryPackingSegmentReferrer::DataDrop {
      return false
    }
  }
  true
}

///|
fn optimization_memory_packing_rewrite_removed_data_drops(
  mod : Module,
  removed_drop_only : Array[Bool],
) -> Module {
  let transformer : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_instruction_evt(fn(_, _, instr) {
      match instr {
        @lib.DataDrop(data_idx) =>
          if optimization_memory_packing_removed_data_idx(
              removed_drop_only, data_idx,
            ) {
            change((), @lib.Instruction::nop())
          } else {
            unchanged()
          }
        _ => unchanged()
      }
    })
    .on_tinstruction_evt(fn(_, _, instr) {
      match instr.kind {
        @lib.TDataDrop(data_idx) =>
          if optimization_memory_packing_removed_data_idx(
              removed_drop_only, data_idx,
            ) {
            change((), @lib.TInstr::nop())
          } else {
            unchanged()
          }
        _ => unchanged()
      }
    })
  match transformer.walk_module((), mod) {
    Ok((rewritten, _)) => rewritten
    Err(_) => mod
  }
}

///|
fn optimization_memory_packing_removed_data_idx(
  removed : Array[Bool],
  data_idx : DataIdx,
) -> Bool {
  let DataIdx(raw) = data_idx
  let idx = raw.reinterpret_as_int()
  if idx < 0 || idx >= removed.length() {
    return false
  }
  removed[idx]
}

///|
fn optimization_memory_packing_data_name(
  mod : Module,
  data_idx : DataIdx,
) -> @lib.Name? {
  let DataIdx(raw) = data_idx
  let target = raw
  match mod.name_sec {
    Some(name_sec) =>
      match name_sec.data_names {
        Some(@lib.NameMap(entries)) =>
          for entry in entries {
            let @lib.NameAssoc(idx, name) = entry
            if idx == target {
              return Some(name)
            }
          }
        None => ()
      }
    None => ()
  }
  None
}

///|
fn optimization_memory_packing_can_split_segment(
  mod : Module,
  data_idx : DataIdx,
  data : Data,
  referrers : Array[MemoryPackingSegmentReferrer],
) -> Bool {
  match optimization_memory_packing_data_name(mod, data_idx) {
    Some(name) => if name.0.has_prefix("__llvm") { return false }
    None => ()
  }
  let Data(_, bytes) = data
  if bytes.length() == 0 {
    return false
  }
  let passive = match data {
    Data(Passive, _) => true
    _ => false
  }
  for referrer in referrers {
    match referrer {
      MemoryPackingSegmentReferrer::MemoryInit(can_split_memory_init) =>
        if passive && !can_split_memory_init {
          return false
        }
      MemoryPackingSegmentReferrer::ArrayNewData
      | MemoryPackingSegmentReferrer::ArrayInitData => return false
      _ => ()
    }
  }
  match data {
    Data(Passive, _) => true
    Data(Active(_, offset_expr), _) =>
      optimization_const_expr_u64(offset_expr) is Some(_)
  }
}

///|
fn optimization_memory_packing_raw_ranges(
  bytes : Bytes,
) -> Array[MemoryPackingRange] {
  let ranges : Array[MemoryPackingRange] = []
  if bytes.length() == 0 {
    return ranges
  }
  let zero = (0).to_byte()
  let mut start = 0
  while start < bytes.length() {
    let mut end = start
    while end < bytes.length() && bytes[end] == zero {
      end += 1
    }
    if end > start {
      ranges.push(MemoryPackingRange::new(true, start, end))
      start = end
    }
    while end < bytes.length() && bytes[end] != zero {
      end += 1
    }
    if end > start {
      ranges.push(MemoryPackingRange::new(false, start, end))
      start = end
    }
  }
  ranges
}

///|
fn optimization_memory_packing_should_preserve_trap(
  mod : Module,
  data : Data,
  features : PipelineFeatures,
) -> Bool {
  if features.traps_never_happen {
    return false
  }
  match data {
    Data(Active(mem_idx, offset_expr), bytes) =>
      match
        (
          optimization_const_expr_u64(offset_expr),
          optimization_memory_packing_mem_type(mod, mem_idx),
        ) {
        (Some(start), Some(@lib.MemType(limits))) => {
          let size = bytes.length().to_uint64()
          let end = start + size
          let memory_size = optimization_limits_initial_length(limits) * 65536UL
          end < start || end > memory_size
        }
        _ => true
      }
    _ => false
  }
}

///|
fn optimization_memory_packing_calculate_ranges(
  mod : Module,
  data : Data,
  referrers : Array[MemoryPackingSegmentReferrer],
  features : PipelineFeatures,
) -> Array[MemoryPackingRange] {
  let Data(_, bytes) = data
  if bytes.length() == 0 {
    return []
  }
  let preserve_trap = optimization_memory_packing_should_preserve_trap(
    mod, data, features,
  )
  let ranges = optimization_memory_packing_raw_ranges(bytes)
  let mut threshold = 0
  match data {
    Data(Passive, _) => {
      threshold += 2
      let mut edge_threshold = 0
      for referrer in referrers {
        match referrer {
          MemoryPackingSegmentReferrer::MemoryInit(_) => {
            threshold += optimization_memory_packing_memory_fill_size +
              optimization_memory_packing_memory_init_size
            edge_threshold += optimization_memory_packing_memory_fill_size
          }
          _ => threshold += optimization_memory_packing_data_drop_size
        }
      }
      let trimmed_trailing : Array[MemoryPackingRange] = if ranges.length() >= 2 {
        let last = ranges[ranges.length() - 1]
        let penultimate = ranges[ranges.length() - 2]
        if last.is_zero && last.length() <= edge_threshold {
          let next : Array[MemoryPackingRange] = []
          let mut i = 0
          while i < ranges.length() - 2 {
            next.push(ranges[i])
            i += 1
          }
          next.push(
            MemoryPackingRange::new(
              penultimate.is_zero,
              penultimate.start,
              last.end,
            ),
          )
          next
        } else {
          ranges
        }
      } else {
        ranges
      }
      if trimmed_trailing.length() >= 2 {
        let first = trimmed_trailing[0]
        let second = trimmed_trailing[1]
        if first.is_zero && first.length() <= edge_threshold {
          let next : Array[MemoryPackingRange] = [
            MemoryPackingRange::new(second.is_zero, first.start, second.end),
          ]
          let mut i = 2
          while i < trimmed_trailing.length() {
            next.push(trimmed_trailing[i])
            i += 1
          }
          return optimization_memory_packing_merge_ranges(
            next,
            threshold,
            bytes.length(),
            preserve_trap,
          )
        }
      }
      optimization_memory_packing_merge_ranges(
        trimmed_trailing,
        threshold,
        bytes.length(),
        preserve_trap,
      )
    }
    _ =>
      optimization_memory_packing_merge_ranges(
        ranges,
        optimization_memory_packing_active_zero_threshold,
        bytes.length(),
        preserve_trap,
      )
  }
}

///|
fn optimization_memory_packing_merge_ranges(
  ranges : Array[MemoryPackingRange],
  threshold : Int,
  byte_len : Int,
  preserve_trap : Bool,
) -> Array[MemoryPackingRange] {
  if ranges.is_empty() {
    return ranges
  }
  let merged : Array[MemoryPackingRange] = [ranges[0]]
  let mut i = 1
  while i < ranges.length() - 1 {
    let left = merged[merged.length() - 1]
    let curr = ranges[i]
    let right = ranges[i + 1]
    if curr.is_zero && curr.length() <= threshold {
      merged[merged.length() - 1] = MemoryPackingRange::new(
        left.is_zero,
        left.start,
        right.end,
      )
      i += 2
    } else {
      merged.push(curr)
      i += 1
    }
  }
  if i < ranges.length() {
    merged.push(ranges[ranges.length() - 1])
  }
  if preserve_trap && !merged.is_empty() {
    let back = merged[merged.length() - 1]
    if back.is_zero {
      merged[merged.length() - 1] = MemoryPackingRange::new(
        true,
        back.start,
        back.end - 1,
      )
      let last_byte = byte_len - 1
      merged.push(MemoryPackingRange::new(false, last_byte, last_byte + 1))
    }
  }
  merged
}

///|
fn optimization_memory_packing_apply_segment_cap(
  ranges : Array[MemoryPackingRange],
  packed_count : Int,
  segments_remaining : Int,
  max_data_segments : Int,
) -> Array[MemoryPackingRange] {
  let mut adjusted = ranges
  let mut emitted = packed_count
  let mut i = 0
  while i < adjusted.length() {
    let range = adjusted[i]
    if !range.is_zero {
      if max_data_segments <= emitted + segments_remaining {
        let mut last_nonzero = adjusted.length() - 1
        if adjusted[last_nonzero].is_zero {
          last_nonzero -= 1
        }
        let compacted : Array[MemoryPackingRange] = []
        let mut j = 0
        while j < adjusted.length() {
          if j < i {
            compacted.push(adjusted[j])
          } else if j == i {
            compacted.push(
              MemoryPackingRange::new(
                false,
                range.start,
                adjusted[last_nonzero].end,
              ),
            )
          } else if j > last_nonzero {
            compacted.push(adjusted[j])
          }
          j += 1
        }
        adjusted = compacted
      }
      emitted += 1
    }
    i += 1
  }
  adjusted
}

///|
fn optimization_memory_packing_unsplit_ranges(
  data : Data,
) -> Array[MemoryPackingRange] {
  let Data(_, bytes) = data
  [MemoryPackingRange::new(false, 0, bytes.length())]
}

///|
fn optimization_memory_packing_count_nonzero_ranges(
  ranges : Array[MemoryPackingRange],
) -> Int {
  let mut count = 0
  for range in ranges {
    if !range.is_zero {
      count += 1
    }
  }
  count
}

///|
fn optimization_memory_packing_ranges_for_segment(
  mod : Module,
  data_idx : DataIdx,
  data : Data,
  referrers : Array[MemoryPackingSegmentReferrer],
  features : PipelineFeatures,
  packed_count : Int,
  segments_remaining : Int,
  max_data_segments : Int,
) -> Array[MemoryPackingRange] {
  if !optimization_memory_packing_can_split_segment(
      mod, data_idx, data, referrers,
    ) {
    return optimization_memory_packing_unsplit_ranges(data)
  }
  optimization_memory_packing_apply_segment_cap(
    optimization_memory_packing_calculate_ranges(mod, data, referrers, features),
    packed_count,
    segments_remaining,
    max_data_segments,
  )
}

///|
fn optimization_memory_packing_analyze_ranges(
  mod : Module,
  referrers : Array[Array[MemoryPackingSegmentReferrer]],
  features : PipelineFeatures,
) -> Array[Array[MemoryPackingRange]] {
  let datas = optimization_memory_packing_data_segments(mod)
  if datas.length() != referrers.length() {
    return []
  }
  let analyses : Array[Array[MemoryPackingRange]] = []
  let mut packed_count = 0
  let mut i = 0
  while i < datas.length() {
    let ranges = optimization_memory_packing_ranges_for_segment(
      mod,
      DataIdx::new(i.reinterpret_as_uint()),
      datas[i],
      referrers[i],
      features,
      packed_count,
      datas.length() - i,
      optimization_memory_packing_max_data_segments,
    )
    packed_count += optimization_memory_packing_count_nonzero_ranges(ranges)
    analyses.push(ranges)
    i += 1
  }
  analyses
}

///|
fn optimization_memory_packing_materialize_segments(
  mod : Module,
  analyses : Array[Array[MemoryPackingRange]],
) -> (Module, Array[Array[DataIdx]]) {
  let datas = optimization_memory_packing_data_segments(mod)
  if datas.length() != analyses.length() {
    return (mod, [])
  }
  let packed_datas : Array[Data] = []
  let packed_names : Array[@lib.NameAssoc] = []
  let replacements : Array[Array[DataIdx]] = []
  let mut i = 0
  while i < datas.length() {
    let data = datas[i]
    let data_idx = DataIdx::new(i.reinterpret_as_uint())
    let base_name = optimization_memory_packing_data_name(mod, data_idx)
    let replacement_data_idxs : Array[DataIdx] = []
    let mut emitted_name_count = 0
    for range in analyses[i] {
      if range.is_zero {
        continue
      }
      let next_data_idx = DataIdx::new(
        packed_datas.length().reinterpret_as_uint(),
      )
      replacement_data_idxs.push(next_data_idx)
      packed_datas.push(
        optimization_memory_packing_materialize_range(data, range),
      )
      match base_name {
        Some(name) =>
          packed_names.push(
            @lib.NameAssoc::new(
              next_data_idx.0,
              optimization_memory_packing_replacement_name(
                name, emitted_name_count,
              ),
            ),
          )
        None => ()
      }
      emitted_name_count += 1
    }
    replacements.push(replacement_data_idxs)
    i += 1
  }
  let mut materialized = mod.with_data_sec(DataSec::new(packed_datas))
  match mod.data_cnt_sec {
    Some(_) =>
      materialized = materialized.with_data_cnt_sec(
        DataCntSec::new(U32::new(packed_datas.length().reinterpret_as_uint())),
      )
    None => ()
  }
  materialized = optimization_memory_packing_with_data_names(
    materialized,
    if packed_names.is_empty() {
      None
    } else {
      Some(@lib.NameMap::new(packed_names))
    },
  )
  (materialized, replacements)
}

///|
fn optimization_memory_packing_add_drop_state_globals(
  mod : Module,
  analyses : Array[Array[MemoryPackingRange]],
  referrers : Array[Array[MemoryPackingSegmentReferrer]],
) -> (Module, Array[@lib.GlobalIdx?]) {
  if analyses.length() != referrers.length() {
    return (mod, [])
  }
  let globals = match mod.global_sec {
    Some(GlobalSec(globals)) => globals.copy()
    None => []
  }
  let drop_globals : Array[@lib.GlobalIdx?] = []
  let mut next_global_idx = (optimization_imported_global_count(mod) +
  globals.length()).reinterpret_as_uint()
  let mut changed = false
  let mut i = 0
  while i < analyses.length() {
    if optimization_memory_packing_segment_needs_drop_state(
        analyses[i],
        referrers[i],
      ) {
      let global_idx = @lib.GlobalIdx::new(next_global_idx)
      drop_globals.push(Some(global_idx))
      globals.push(
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), true),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
        ),
      )
      next_global_idx += 1U
      changed = true
    } else {
      drop_globals.push(None)
    }
    i += 1
  }
  if !changed {
    return (mod, drop_globals)
  }
  (mod.with_global_sec(GlobalSec::new(globals)), drop_globals)
}

///|
fn optimization_memory_packing_segment_needs_drop_state(
  ranges : Array[MemoryPackingRange],
  referrers : Array[MemoryPackingSegmentReferrer],
) -> Bool {
  if ranges.is_empty() || !ranges[0].is_zero {
    return false
  }
  let mut has_memory_init = false
  let mut has_data_drop = false
  for referrer in referrers {
    match referrer {
      MemoryPackingSegmentReferrer::MemoryInit(_) => has_memory_init = true
      MemoryPackingSegmentReferrer::DataDrop => has_data_drop = true
      _ => ()
    }
  }
  has_memory_init && has_data_drop
}

///|
fn optimization_memory_packing_apply_replacements(
  mod : Module,
  analyses : Array[Array[MemoryPackingRange]],
  replacements : Array[Array[DataIdx]],
  drop_globals : Array[@lib.GlobalIdx?],
) -> Module {
  let data_remap = optimization_memory_packing_first_replacement_remap(
    replacements,
  )
  optimization_memory_packing_rewrite_typed_segment_ops(
    optimization_memory_packing_rewrite_non_typed_segment_data_indices(
      mod, data_remap,
    ),
    analyses,
    replacements,
    drop_globals,
  )
}

///|
fn optimization_memory_packing_first_replacement_remap(
  replacements : Array[Array[DataIdx]],
) -> Map[UInt, UInt] {
  let remap : Map[UInt, UInt] = {}
  let mut i = 0
  while i < replacements.length() {
    if !replacements[i].is_empty() {
      let DataIdx(next_idx) = replacements[i][0]
      remap[i.reinterpret_as_uint()] = next_idx
    }
    i += 1
  }
  remap
}

///|
fn optimization_memory_packing_rewrite_non_typed_segment_data_indices(
  mod : Module,
  data_remap : Map[UInt, UInt],
) -> Module {
  let transformer : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_instruction_evt(fn(_, _, instr) {
      match instr {
        @lib.MemoryInit(data_idx, mem_idx) =>
          change(
            (),
            @lib.Instruction::memory_init(
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
              mem_idx,
            ),
          )
        @lib.DataDrop(data_idx) =>
          change(
            (),
            @lib.Instruction::data_drop(
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
            ),
          )
        @lib.ArrayNewData(type_idx, data_idx) =>
          change(
            (),
            @lib.Instruction::array_new_data(
              type_idx,
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
            ),
          )
        @lib.ArrayInitData(type_idx, data_idx) =>
          change(
            (),
            @lib.Instruction::array_init_data(
              type_idx,
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
            ),
          )
        _ => unchanged()
      }
    })
    .on_tinstruction_evt(fn(_, _, instr) {
      match instr.kind {
        @lib.TArrayNewData(type_idx, data_idx, offset, len) =>
          change(
            (),
            @lib.TInstr::array_new_data(
              type_idx,
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
              offset,
              len,
            ),
          )
        @lib.TArrayInitData(type_idx, data_idx, array, dst, src, len) =>
          change(
            (),
            @lib.TInstr::array_init_data(
              type_idx,
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
              array,
              dst,
              src,
              len,
            ),
          )
        _ => unchanged()
      }
    })
  match transformer.walk_module((), mod) {
    Ok((rewritten, _)) => rewritten
    Err(_) => mod
  }
}

///|
priv struct MemoryPackingTypedRewriteFuncState {
  locals : @lib.Locals
  mut next_local_idx : Int
}

///|
fn MemoryPackingTypedRewriteFuncState::new(
  param_count : Int,
  locals : @lib.Locals,
) -> MemoryPackingTypedRewriteFuncState {
  { locals, next_local_idx: param_count + locals.length() }
}

///|
fn optimization_memory_packing_rewrite_typed_segment_ops(
  mod : Module,
  analyses : Array[Array[MemoryPackingRange]],
  replacements : Array[Array[DataIdx]],
  drop_globals : Array[@lib.GlobalIdx?],
) -> Module {
  let funcs = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs
    None => return mod
  }
  let rewritten_funcs : Array[Func] = []
  for func in funcs {
    rewritten_funcs.push(
      optimization_memory_packing_rewrite_typed_segment_ops_func(
        mod, func, analyses, replacements, drop_globals,
      ),
    )
  }
  mod.with_code_sec(CodeSec::new(rewritten_funcs))
}

///|
fn optimization_memory_packing_rewrite_typed_segment_ops_func(
  mod : Module,
  func : Func,
  analyses : Array[Array[MemoryPackingRange]],
  replacements : Array[Array[DataIdx]],
  drop_globals : Array[@lib.GlobalIdx?],
) -> Func {
  match func {
    TFunc(params, locals, body) => {
      let transformer : ModuleTransformer[
        MemoryPackingTypedRewriteFuncState,
        Unit,
      ] = ModuleTransformer::new().on_tinstruction_evt(fn(self, state, instr) {
        match instr.kind {
          @lib.TMemoryInit(data_idx, mem_idx, dest, offset, size) => {
            let (dest, state) = self.walk_tinstruction(state, dest).unwrap()
            let (offset, state) = self.walk_tinstruction(state, offset).unwrap()
            let (size, state) = self.walk_tinstruction(state, size).unwrap()
            change(
              state,
              optimization_memory_packing_rewrite_typed_memory_init_instr(
                mod, analyses, replacements, drop_globals, state, data_idx, mem_idx,
                dest, offset, size,
              ),
            )
          }
          @lib.TDataDrop(data_idx) =>
            change(
              state,
              optimization_memory_packing_rewrite_typed_data_drop_instr(
                replacements, drop_globals, data_idx,
              ),
            )
          _ => {
            let (rewritten, state) = self
              .walk_tinstruction_default(state, instr)
              .unwrap()
            change(state, rewritten)
          }
        }
      })
      match
        transformer.walk_texpr(
          MemoryPackingTypedRewriteFuncState::new(
            params.length(),
            locals.copy(),
          ),
          body,
        ) {
        Ok((rewritten_body, state)) =>
          Func::t_func(params, state.locals, rewritten_body)
        Err(_) => func
      }
    }
    _ => func
  }
}

///|
fn optimization_memory_packing_rewrite_typed_memory_init_instr(
  mod : Module,
  analyses : Array[Array[MemoryPackingRange]],
  replacements : Array[Array[DataIdx]],
  drop_globals : Array[@lib.GlobalIdx?],
  state : MemoryPackingTypedRewriteFuncState,
  data_idx : DataIdx,
  mem_idx : @lib.MemIdx,
  dest : @lib.TInstr,
  offset : @lib.TInstr,
  size : @lib.TInstr,
) -> @lib.TInstr {
  let DataIdx(raw_idx) = data_idx
  let idx = raw_idx.reinterpret_as_int()
  if idx < 0 || idx >= analyses.length() || idx >= replacements.length() {
    return @lib.TInstr::memory_init(data_idx, mem_idx, dest, offset, size)
  }
  let ranges = analyses[idx]
  let segment_replacements = replacements[idx]
  if ranges.length() == 1 &&
    !ranges[0].is_zero &&
    segment_replacements.length() == 1 {
    return @lib.TInstr::memory_init(
      segment_replacements[0],
      mem_idx,
      dest,
      offset,
      size,
    )
  }
  let start = match optimization_memory_packing_tinstr_const_u64(offset) {
    Some(start) => start
    None =>
      return @lib.TInstr::memory_init(
        if segment_replacements.is_empty() {
          data_idx
        } else {
          segment_replacements[0]
        },
        mem_idx,
        dest,
        offset,
        size,
      )
  }
  let size_u64 = match optimization_memory_packing_tinstr_const_u64(size) {
    Some(size_u64) => size_u64
    None =>
      return @lib.TInstr::memory_init(
        if segment_replacements.is_empty() {
          data_idx
        } else {
          segment_replacements[0]
        },
        mem_idx,
        dest,
        offset,
        size,
      )
  }
  let end = start + size_u64
  if end < start {
    return optimization_memory_packing_trap_block(dest, offset, size)
  }

  let emitted : Array[@lib.TInstr] = []
  let overlap_count = optimization_memory_packing_overlap_count(
    ranges, start, end,
  )
  let base_dest = if optimization_memory_packing_tinstr_const_u64(dest)
    is Some(_) ||
    overlap_count <= 1 {
    dest
  } else {
    match optimization_memory_packing_alloc_dest_local(state, mod, mem_idx) {
      Some(local_idx) => {
        emitted.push(@lib.TInstr::local_set(local_idx, dest))
        @lib.TInstr::local_get(local_idx)
      }
      None => dest
    }
  }

  match drop_globals.get(idx) {
    Some(Some(global_idx)) =>
      emitted.push(optimization_memory_packing_drop_state_check(global_idx))
    _ => ()
  }

  let mut init_index = 0
  for range in ranges {
    if !range.is_zero && range.end.to_uint64() <= start {
      init_index += 1
    }
  }

  let mut bytes_written = 0UL
  for range in ranges {
    let range_start = range.start.to_uint64()
    let range_end = range.end.to_uint64()
    if range_end <= start {
      continue
    }
    if range_start >= end {
      break
    }
    let overlap_start = if start > range_start { start } else { range_start }
    let overlap_end = if end < range_end { end } else { range_end }
    let overlap_len = overlap_end - overlap_start
    if overlap_len == 0UL {
      if !range.is_zero {
        init_index += 1
      }
      continue
    }
    let chunk_dest = optimization_memory_packing_add_to_dest(
      mod, mem_idx, base_dest, bytes_written,
    )
    if range.is_zero {
      emitted.push(
        @lib.TInstr::memory_fill(
          mem_idx,
          chunk_dest,
          optimization_memory_packing_const_for_memory(mod, mem_idx, 0UL),
          optimization_memory_packing_const_for_memory(
            mod, mem_idx, overlap_len,
          ),
        ),
      )
    } else {
      let relative_offset = overlap_start - range_start
      emitted.push(
        @lib.TInstr::memory_init(
          segment_replacements[init_index],
          mem_idx,
          chunk_dest,
          optimization_memory_packing_const_for_memory(
            mod, mem_idx, relative_offset,
          ),
          optimization_memory_packing_const_for_memory(
            mod, mem_idx, overlap_len,
          ),
        ),
      )
      init_index += 1
    }
    bytes_written += overlap_len
  }
  optimization_memory_packing_block_or_single(emitted)
}

///|
fn optimization_memory_packing_rewrite_typed_data_drop_instr(
  replacements : Array[Array[DataIdx]],
  drop_globals : Array[@lib.GlobalIdx?],
  data_idx : DataIdx,
) -> @lib.TInstr {
  let DataIdx(raw_idx) = data_idx
  let idx = raw_idx.reinterpret_as_int()
  if idx < 0 || idx >= replacements.length() {
    return @lib.TInstr::data_drop(data_idx)
  }
  let emitted : Array[@lib.TInstr] = []
  match drop_globals.get(idx) {
    Some(Some(global_idx)) =>
      emitted.push(
        @lib.TInstr::global_set(
          global_idx,
          @lib.TInstr::i32_const(@lib.I32::new(1)),
        ),
      )
    _ => ()
  }
  for replacement in replacements[idx] {
    emitted.push(@lib.TInstr::data_drop(replacement))
  }
  if emitted.is_empty() {
    @lib.TInstr::nop()
  } else {
    optimization_memory_packing_block_or_single(emitted)
  }
}

///|
fn optimization_memory_packing_overlap_count(
  ranges : Array[MemoryPackingRange],
  start : UInt64,
  end : UInt64,
) -> Int {
  let mut count = 0
  for range in ranges {
    let range_start = range.start.to_uint64()
    let range_end = range.end.to_uint64()
    if range_end <= start {
      continue
    }
    if range_start >= end {
      break
    }
    count += 1
  }
  count
}

///|
fn optimization_memory_packing_alloc_dest_local(
  state : MemoryPackingTypedRewriteFuncState,
  mod : Module,
  mem_idx : @lib.MemIdx,
) -> @lib.LocalIdx? {
  match optimization_memory_packing_memory_index_valtype(mod, mem_idx) {
    Some(vt) => {
      let local_idx = @lib.LocalIdx::new(
        state.next_local_idx.reinterpret_as_uint(),
      )
      state.next_local_idx += 1
      state.locals.push(vt)
      Some(local_idx)
    }
    None => None
  }
}

///|
fn optimization_memory_packing_memory_index_valtype(
  mod : Module,
  mem_idx : @lib.MemIdx,
) -> @lib.ValType? {
  match optimization_memory_packing_mem_type(mod, mem_idx) {
    Some(@lib.MemType(@lib.I32Limits(_, _))) => Some(@lib.ValType::i32())
    Some(@lib.MemType(@lib.I64Limits(_, _))) => Some(@lib.ValType::i64())
    None => None
  }
}

///|
fn optimization_memory_packing_const_for_memory(
  mod : Module,
  mem_idx : @lib.MemIdx,
  value : UInt64,
) -> @lib.TInstr {
  match optimization_memory_packing_mem_type(mod, mem_idx) {
    Some(@lib.MemType(@lib.I64Limits(_, _))) =>
      @lib.TInstr::i64_const(@lib.I64::new(value.reinterpret_as_int64()))
    _ =>
      @lib.TInstr::i32_const(
        @lib.I32::new(value.to_uint().reinterpret_as_int()),
      )
  }
}

///|
fn optimization_memory_packing_add_to_dest(
  mod : Module,
  mem_idx : @lib.MemIdx,
  dest : @lib.TInstr,
  delta : UInt64,
) -> @lib.TInstr {
  if delta == 0UL {
    return dest
  }
  match optimization_memory_packing_mem_type(mod, mem_idx) {
    Some(@lib.MemType(@lib.I64Limits(_, _))) =>
      @lib.TInstr::binary(
        @lib.BinaryOp::i64_add(),
        dest,
        optimization_memory_packing_const_for_memory(mod, mem_idx, delta),
      )
    _ =>
      @lib.TInstr::binary(
        @lib.BinaryOp::i32_add(),
        dest,
        optimization_memory_packing_const_for_memory(mod, mem_idx, delta),
      )
  }
}

///|
fn optimization_memory_packing_drop_state_check(
  global_idx : @lib.GlobalIdx,
) -> @lib.TInstr {
  @lib.TInstr::if_(
    @lib.BlockType::void_(),
    @lib.TInstr::global_get(global_idx),
    @lib.TExpr::new([@lib.TInstr::unreachable_()]),
    None,
  )
}

///|
fn optimization_memory_packing_block_or_single(
  instrs : Array[@lib.TInstr],
) -> @lib.TInstr {
  match instrs {
    [instr] => instr
    _ => @lib.TInstr::block(@lib.BlockType::void_(), @lib.TExpr::new(instrs))
  }
}

///|
fn optimization_memory_packing_materialize_range(
  data : Data,
  range : MemoryPackingRange,
) -> Data {
  let Data(mode, bytes) = data
  let packed_bytes = bytes[range.start:range.end].to_bytes()
  match mode {
    @lib.Active(mem_idx, offset_expr) =>
      Data::new(
        @lib.DataMode::active(
          mem_idx,
          optimization_memory_packing_shift_active_offset(
            offset_expr,
            range.start.to_uint64(),
          ),
        ),
        packed_bytes,
      )
    @lib.Passive => Data::new(@lib.DataMode::passive(), packed_bytes)
  }
}

///|
fn optimization_memory_packing_shift_active_offset(
  offset_expr : @lib.Expr,
  delta : UInt64,
) -> @lib.Expr {
  match offset_expr {
    @lib.Expr([@lib.I32Const(@lib.I32(value))]) => {
      let base = value.reinterpret_as_uint().to_uint64()
      let next = optimization_memory_packing_saturating_add_u64(
        base, delta, 4294967295UL,
      )
      @lib.Expr::new([
        @lib.Instruction::i32_const(
          @lib.I32::new(next.to_uint().reinterpret_as_int()),
        ),
      ])
    }
    @lib.Expr([@lib.I64Const(@lib.I64(value))]) => {
      let base = value.reinterpret_as_uint64()
      let next = optimization_memory_packing_saturating_add_u64(
        base, delta, 18446744073709551615UL,
      )
      @lib.Expr::new([
        @lib.Instruction::i64_const(@lib.I64::new(next.reinterpret_as_int64())),
      ])
    }
    _ => offset_expr
  }
}

///|
fn optimization_memory_packing_saturating_add_u64(
  lhs : UInt64,
  rhs : UInt64,
  max_value : UInt64,
) -> UInt64 {
  if rhs > max_value - lhs {
    max_value
  } else {
    lhs + rhs
  }
}

///|
fn optimization_memory_packing_replacement_name(
  name : @lib.Name,
  emitted_idx : Int,
) -> @lib.Name {
  if emitted_idx == 0 {
    return name
  }
  @lib.Name::from_string("\{name.0.to_string()}.\{emitted_idx}")
}

///|
fn optimization_memory_packing_with_data_names(
  mod : Module,
  data_names : @lib.NameMap?,
) -> Module {
  match mod.name_sec {
    Some(name_sec) =>
      mod.with_name_sec(
        optimization_memory_packing_rewrite_data_name_sec(name_sec, data_names),
      )
    None =>
      match data_names {
        Some(names) => mod.with_name_sec(NameSec::new(data_names=Some(names)))
        None => mod
      }
  }
}

///|
fn optimization_memory_packing_rewrite_data_name_sec(
  name_sec : NameSec,
  data_names : @lib.NameMap?,
) -> NameSec {
  let {
    module_name,
    func_names,
    local_names,
    label_names,
    type_names,
    table_names,
    memory_names,
    global_names,
    elem_names,
    data_names: _,
    field_names,
    tag_names,
  } = name_sec
  NameSec::new(
    module_name~,
    func_names~,
    local_names~,
    label_names~,
    type_names~,
    table_names~,
    memory_names~,
    global_names~,
    elem_names~,
    data_names~,
    field_names~,
    tag_names~,
  )
}

///|
fn optimization_memory_packing_remove_dead_passive_segments(
  mod : Module,
  referrers : Array[Array[MemoryPackingSegmentReferrer]],
) -> Module {
  let datas = optimization_memory_packing_data_segments(mod)
  if datas.length() != referrers.length() {
    return mod
  }
  let keep_datas : Array[Bool] = []
  let removed_drop_only : Array[Bool] = []
  let mut changed = false
  let mut i = 0
  while i < datas.length() {
    let refs = referrers[i]
    let keep = match datas[i] {
      Data(Active(_, _), _) => true
      Data(Passive, _) =>
        !refs.is_empty() &&
        !optimization_memory_packing_all_referrers_are_data_drop(refs)
    }
    keep_datas.push(keep)
    let drop_only = !keep &&
      optimization_memory_packing_all_referrers_are_data_drop(refs)
    removed_drop_only.push(drop_only)
    if !keep {
      changed = true
    }
    i += 1
  }
  if !changed {
    return mod
  }
  let rewritten = optimization_memory_packing_rewrite_removed_data_drops(
    mod, removed_drop_only,
  )
  let (compacted, data_remap) = optimization_compact_data_sec(
    rewritten, datas, keep_datas,
  )
  optimization_memory_packing_rewrite_data_indices(
    optimization_memory_packing_rewrite_data_name_indices(compacted, data_remap),
    data_remap,
  )
}

///|
fn optimization_memory_packing_rewrite_data_name_indices(
  mod : Module,
  data_remap : Map[UInt, UInt],
) -> Module {
  match mod.name_sec {
    Some(name_sec) =>
      mod.with_name_sec(
        optimization_memory_packing_rewrite_data_name_sec(
          name_sec,
          match name_sec.data_names {
            Some(data_names) =>
              Some(
                optimization_rewrite_name_map_filtered(
                  data_names, data_remap, true,
                ),
              )
            None => None
          },
        ),
      )
    None => mod
  }
}

///|
fn optimization_memory_packing_rewrite_data_indices(
  mod : Module,
  data_remap : Map[UInt, UInt],
) -> Module {
  let transformer : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_instruction_evt(fn(_, _, instr) {
      match instr {
        @lib.MemoryInit(data_idx, mem_idx) =>
          change(
            (),
            @lib.Instruction::memory_init(
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
              mem_idx,
            ),
          )
        @lib.DataDrop(data_idx) =>
          change(
            (),
            @lib.Instruction::data_drop(
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
            ),
          )
        @lib.ArrayNewData(type_idx, data_idx) =>
          change(
            (),
            @lib.Instruction::array_new_data(
              type_idx,
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
            ),
          )
        @lib.ArrayInitData(type_idx, data_idx) =>
          change(
            (),
            @lib.Instruction::array_init_data(
              type_idx,
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
            ),
          )
        _ => unchanged()
      }
    })
    .on_tinstruction_evt(fn(_, _, instr) {
      match instr.kind {
        @lib.TMemoryInit(data_idx, mem_idx, dest, offset, size) =>
          change(
            (),
            @lib.TInstr::memory_init(
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
              mem_idx,
              dest,
              offset,
              size,
            ),
          )
        @lib.TDataDrop(data_idx) =>
          change(
            (),
            @lib.TInstr::data_drop(
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
            ),
          )
        @lib.TArrayNewData(type_idx, data_idx, offset, len) =>
          change(
            (),
            @lib.TInstr::array_new_data(
              type_idx,
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
              offset,
              len,
            ),
          )
        @lib.TArrayInitData(type_idx, data_idx, array, dst, src, len) =>
          change(
            (),
            @lib.TInstr::array_init_data(
              type_idx,
              optimization_memory_packing_remap_data_idx(data_remap, data_idx),
              array,
              dst,
              src,
              len,
            ),
          )
        _ => unchanged()
      }
    })
  match transformer.walk_module((), mod) {
    Ok((rewritten, _)) => rewritten
    Err(_) => mod
  }
}

///|
fn optimization_memory_packing_remap_data_idx(
  data_remap : Map[UInt, UInt],
  data_idx : DataIdx,
) -> DataIdx {
  let DataIdx(raw) = data_idx
  DataIdx::new(data_remap.get(raw).unwrap_or(raw))
}

///|
fn optimization_memory_packing_tinstr_const_u64(instr : @lib.TInstr) -> UInt64? {
  match instr.kind {
    @lib.TI32Const(@lib.I32(value)) =>
      Some(value.reinterpret_as_uint().to_uint64())
    @lib.TI64Const(@lib.I64(value)) => Some(value.reinterpret_as_uint64())
    _ => None
  }
}

///|
fn optimization_memory_packing_trap_block(
  dest : @lib.TInstr,
  offset : @lib.TInstr,
  size : @lib.TInstr,
) -> @lib.TInstr {
  @lib.TInstr::block(
    @lib.BlockType::void_(),
    @lib.TExpr::new([
      @lib.TInstr::drop(dest),
      @lib.TInstr::drop(offset),
      @lib.TInstr::drop(size),
      @lib.TInstr::unreachable_(),
    ]),
  )
}

///|
fn optimization_memory_packing_zero_length_bounds_check(
  mod : Module,
  mem_idx : @lib.MemIdx,
  dest : @lib.TInstr,
) -> @lib.TInstr? {
  match optimization_memory_packing_mem_type(mod, mem_idx) {
    Some(@lib.MemType(@lib.I32Limits(_, _))) =>
      Some(
        @lib.TInstr::if_(
          @lib.BlockType::void_(),
          @lib.TInstr::binary(
            @lib.BinaryOp::i32_gt_u(),
            dest,
            @lib.TInstr::binary(
              @lib.BinaryOp::i32_shl(),
              @lib.TInstr::memory_size(mem_idx),
              @lib.TInstr::i32_const(@lib.I32::new(16)),
            ),
          ),
          @lib.TExpr::new([@lib.TInstr::unreachable_()]),
          None,
        ),
      )
    Some(@lib.MemType(@lib.I64Limits(_, _))) =>
      Some(
        @lib.TInstr::if_(
          @lib.BlockType::void_(),
          @lib.TInstr::binary(
            @lib.BinaryOp::i64_gt_u(),
            dest,
            @lib.TInstr::binary(
              @lib.BinaryOp::i64_shl(),
              @lib.TInstr::memory_size(mem_idx),
              @lib.TInstr::i64_const(@lib.I64::new(16L)),
            ),
          ),
          @lib.TExpr::new([@lib.TInstr::unreachable_()]),
          None,
        ),
      )
    None => None
  }
}

///|
fn optimization_memory_packing_passive_init_traps(
  segment_len : UInt64,
  offset : UInt64,
  size : UInt64,
) -> Bool {
  if offset > segment_len || size > segment_len {
    return true
  }
  let end = offset + size
  end < offset || end > segment_len
}

///|
fn optimization_memory_packing_rewrite_tmemory_init(
  mod : Module,
  data_idx : DataIdx,
  mem_idx : @lib.MemIdx,
  dest : @lib.TInstr,
  offset : @lib.TInstr,
  size : @lib.TInstr,
) -> @lib.TInstr? {
  let offset_u64 = match optimization_memory_packing_tinstr_const_u64(offset) {
    Some(value) => value
    None => return None
  }
  let size_u64 = match optimization_memory_packing_tinstr_const_u64(size) {
    Some(value) => value
    None => return None
  }
  match optimization_memory_packing_data(mod, data_idx) {
    Some(Data(Active(_, _), _)) =>
      if offset_u64 == 0UL && size_u64 == 0UL {
        optimization_memory_packing_zero_length_bounds_check(mod, mem_idx, dest)
      } else {
        Some(optimization_memory_packing_trap_block(dest, offset, size))
      }
    Some(Data(Passive, bytes)) =>
      if offset_u64 == 0UL && size_u64 == 0UL {
        optimization_memory_packing_zero_length_bounds_check(mod, mem_idx, dest)
      } else if optimization_memory_packing_passive_init_traps(
          bytes.length().to_uint64(),
          offset_u64,
          size_u64,
        ) {
        Some(optimization_memory_packing_trap_block(dest, offset, size))
      } else {
        None
      }
    None => None
  }
}

///|
fn optimization_memory_packing_prenormalize_segment_ops(mod : Module) -> Module {
  let transformer : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      _,
      _,
      instr,
    ) {
      match instr.kind {
        @lib.TMemoryInit(data_idx, mem_idx, dest, offset, size) =>
          match
            optimization_memory_packing_rewrite_tmemory_init(
              mod, data_idx, mem_idx, dest, offset, size,
            ) {
            Some(rewritten) => change((), rewritten)
            None => unchanged()
          }
        @lib.TDataDrop(data_idx) =>
          match optimization_memory_packing_data(mod, data_idx) {
            Some(Data(Active(_, _), _)) => change((), @lib.TInstr::nop())
            _ => unchanged()
          }
        _ => unchanged()
      }
    },
  )
  match transformer.walk_module((), mod) {
    Ok((rewritten, _)) => rewritten
    Err(_) => mod
  }
}

///|
fn optimization_memory_packing_test_defined_memory(
  limits? : @lib.Limits = @lib.Limits::i32(1U, None),
) -> Module {
  Module::new().with_mem_sec(MemSec::new([@lib.MemType::new(limits)]))
}

///|
fn optimization_memory_packing_test_imported_memory(
  limits? : @lib.Limits = @lib.Limits::i32(1U, None),
) -> Module {
  Module::new().with_import_sec(
    ImportSec::new([
      Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("memory"),
        @lib.ExternType::mem(@lib.MemType::new(limits)),
      ),
    ]),
  )
}

///|
fn optimization_memory_packing_test_active_data(
  offset_expr : @lib.Expr,
  bytes : Bytes,
) -> Data {
  Data::new(@lib.DataMode::active(@lib.MemIdx::new(0U), offset_expr), bytes)
}

///|
fn optimization_memory_packing_test_typed_body(
  instrs : Array[@lib.TInstr],
) -> Array[@lib.TInstr] {
  let mod = optimization_memory_packing_test_defined_memory()
    .with_data_sec(
      DataSec::new([
        optimization_memory_packing_test_active_data(
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          b"abc",
        ),
      ]),
    )
    .with_type_sec(
      @lib.TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], @lib.Locals::empty(), @lib.TExpr::new(instrs)),
      ]),
    )
  let (optimized, _) = run_memory_packing(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => body.inner()
    _ => abort("expected rewritten typed function body")
  }
}

///|
fn optimization_memory_packing_test_passive_body(
  data_bytes : Bytes,
  instrs : Array[@lib.TInstr],
) -> Array[@lib.TInstr] {
  let mod = optimization_memory_packing_test_defined_memory()
    .with_data_sec(
      DataSec::new([Data::new(@lib.DataMode::passive(), data_bytes)]),
    )
    .with_type_sec(
      @lib.TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], @lib.Locals::empty(), @lib.TExpr::new(instrs)),
      ]),
    )
  let (optimized, _) = run_memory_packing(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => body.inner()
    _ => abort("expected rewritten typed function body")
  }
}

///|
fn optimization_memory_packing_test_run(mod : Module) -> Module {
  let (optimized, _) = run_memory_packing(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )
  optimized
}

///|
fn optimization_memory_packing_test_referrer_module(
  funcs : Array[Func],
) -> Module {
  let func_types : Array[TypeIdx] = []
  for _ in funcs {
    func_types.push(TypeIdx::new(0U))
  }
  optimization_memory_packing_test_defined_memory()
  .with_data_sec(
    DataSec::new([
      Data::new(@lib.DataMode::passive(), b"a"),
      Data::new(@lib.DataMode::passive(), b"b"),
      Data::new(@lib.DataMode::passive(), b"c"),
    ]),
  )
  .with_type_sec(
    @lib.TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  .with_func_sec(FuncSec::new(func_types))
  .with_code_sec(CodeSec::new(funcs))
}

///|
test "memory packing analysis rejects unsupported memory topologies" {
  assert_false(
    optimization_memory_packing_can_optimize(
      Module::new(),
      PipelineFeatures::new(),
    ),
  )
  assert_false(
    optimization_memory_packing_can_optimize(
      Module::new().with_mem_sec(
        MemSec::new([
          @lib.MemType::new(@lib.Limits::i32(1U, None)),
          @lib.MemType::new(@lib.Limits::i32(1U, None)),
        ]),
      ),
      PipelineFeatures::new(),
    ),
  )
}

///|
test "memory packing analysis rejects imported memory without zero-filled promise" {
  assert_false(
    optimization_memory_packing_can_optimize(
      optimization_memory_packing_test_imported_memory(),
      PipelineFeatures::new(),
    ),
  )
  assert_true(
    optimization_memory_packing_can_optimize(
      optimization_memory_packing_test_imported_memory(),
      PipelineFeatures::new(zero_filled_memory=true),
    ),
  )
}

///|
test "memory packing analysis allows single dynamic active segment but rejects it in multi-segment modules" {
  let dynamic = optimization_memory_packing_test_active_data(
    @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
    b"\x00",
  )
  let passive = Data::new(@lib.DataMode::passive(), b"abc")

  assert_true(
    optimization_memory_packing_can_optimize(
      optimization_memory_packing_test_defined_memory().with_data_sec(
        DataSec::new([dynamic]),
      ),
      PipelineFeatures::new(),
    ),
  )
  assert_false(
    optimization_memory_packing_can_optimize(
      optimization_memory_packing_test_defined_memory().with_data_sec(
        DataSec::new([dynamic, passive]),
      ),
      PipelineFeatures::new(),
    ),
  )
}

///|
test "memory packing analysis rejects overlapping active segments" {
  let mod = optimization_memory_packing_test_defined_memory().with_data_sec(
    DataSec::new([
      optimization_memory_packing_test_active_data(
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
        b"abc",
      ),
      optimization_memory_packing_test_active_data(
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(2))]),
        b"def",
      ),
    ]),
  )
  assert_false(
    optimization_memory_packing_can_optimize(mod, PipelineFeatures::new()),
  )
}

///|
test "memory packing analysis allows disjoint active segments" {
  let mod = optimization_memory_packing_test_defined_memory().with_data_sec(
    DataSec::new([
      optimization_memory_packing_test_active_data(
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
        b"abc",
      ),
      optimization_memory_packing_test_active_data(
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(3))]),
        b"def",
      ),
    ]),
  )
  assert_true(
    optimization_memory_packing_can_optimize(mod, PipelineFeatures::new()),
  )
}

///|
test "memory packing pre-normalizes active memory.init traps and active data.drop" {
  let body = optimization_memory_packing_test_typed_body([
    @lib.TInstr::memory_init(
      DataIdx::new(0U),
      @lib.MemIdx::new(0U),
      @lib.TInstr::i32_const(@lib.I32::new(42)),
      @lib.TInstr::i32_const(@lib.I32::new(13)),
      @lib.TInstr::i32_const(@lib.I32::new(0)),
    ),
    @lib.TInstr::data_drop(DataIdx::new(0U)),
  ])
  assert_eq(body, [
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(42))),
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(13))),
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(0))),
        @lib.TInstr::unreachable_(),
      ]),
    ),
    @lib.TInstr::nop(),
  ])
}

///|
test "memory packing pre-normalizes zero-length active memory.init to bounds check" {
  let body = optimization_memory_packing_test_typed_body([
    @lib.TInstr::memory_init(
      DataIdx::new(0U),
      @lib.MemIdx::new(0U),
      @lib.TInstr::i32_const(@lib.I32::new(42)),
      @lib.TInstr::i32_const(@lib.I32::new(0)),
      @lib.TInstr::i32_const(@lib.I32::new(0)),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::if_(
      @lib.BlockType::void_(),
      @lib.TInstr::binary(
        @lib.BinaryOp::i32_gt_u(),
        @lib.TInstr::i32_const(@lib.I32::new(42)),
        @lib.TInstr::binary(
          @lib.BinaryOp::i32_shl(),
          @lib.TInstr::memory_size(@lib.MemIdx::new(0U)),
          @lib.TInstr::i32_const(@lib.I32::new(16)),
        ),
      ),
      @lib.TExpr::new([@lib.TInstr::unreachable_()]),
      None,
    ),
  ])
}

///|
test "memory packing pre-normalizes passive memory.init proven traps" {
  let body = optimization_memory_packing_test_passive_body(b"abc", [
    @lib.TInstr::memory_init(
      DataIdx::new(0U),
      @lib.MemIdx::new(0U),
      @lib.TInstr::i32_const(@lib.I32::new(7)),
      @lib.TInstr::i32_const(@lib.I32::new(4)),
      @lib.TInstr::i32_const(@lib.I32::new(0)),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(7))),
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(4))),
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(0))),
        @lib.TInstr::unreachable_(),
      ]),
    ),
  ])
}

///|
test "memory packing pre-normalizes zero-length passive memory.init to bounds check" {
  let body = optimization_memory_packing_test_passive_body(b"abc", [
    @lib.TInstr::memory_init(
      DataIdx::new(0U),
      @lib.MemIdx::new(0U),
      @lib.TInstr::i32_const(@lib.I32::new(9)),
      @lib.TInstr::i32_const(@lib.I32::new(0)),
      @lib.TInstr::i32_const(@lib.I32::new(0)),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::if_(
      @lib.BlockType::void_(),
      @lib.TInstr::binary(
        @lib.BinaryOp::i32_gt_u(),
        @lib.TInstr::i32_const(@lib.I32::new(9)),
        @lib.TInstr::binary(
          @lib.BinaryOp::i32_shl(),
          @lib.TInstr::memory_size(@lib.MemIdx::new(0U)),
          @lib.TInstr::i32_const(@lib.I32::new(16)),
        ),
      ),
      @lib.TExpr::new([@lib.TInstr::unreachable_()]),
      None,
    ),
  ])
}

///|
test "memory packing collects typed segment referrers including GC consumers" {
  let mod = optimization_memory_packing_test_referrer_module([
    Func::t_func(
      [],
      @lib.Locals::empty(),
      @lib.TExpr::new([
        @lib.TInstr::memory_init(
          DataIdx::new(0U),
          @lib.MemIdx::new(0U),
          @lib.TInstr::i32_const(@lib.I32::new(11)),
          @lib.TInstr::i32_const(@lib.I32::new(0)),
          @lib.TInstr::i32_const(@lib.I32::new(1)),
        ),
        @lib.TInstr::array_new_data(
          TypeIdx::new(0U),
          DataIdx::new(1U),
          @lib.TInstr::i32_const(@lib.I32::new(2)),
          @lib.TInstr::i32_const(@lib.I32::new(3)),
        ),
        @lib.TInstr::array_init_data(
          TypeIdx::new(0U),
          DataIdx::new(1U),
          @lib.TInstr::i32_const(@lib.I32::new(4)),
          @lib.TInstr::i32_const(@lib.I32::new(5)),
          @lib.TInstr::i32_const(@lib.I32::new(6)),
          @lib.TInstr::i32_const(@lib.I32::new(7)),
        ),
        @lib.TInstr::data_drop(DataIdx::new(2U)),
      ]),
    ),
  ])
  assert_eq(optimization_memory_packing_collect_referrers(mod), [
    [MemoryPackingSegmentReferrer::MemoryInit(true)],
    [
      MemoryPackingSegmentReferrer::ArrayNewData,
      MemoryPackingSegmentReferrer::ArrayInitData,
    ],
    [MemoryPackingSegmentReferrer::DataDrop],
  ])
}

///|
test "memory packing collects untyped segment referrers including GC consumers" {
  let mod = optimization_memory_packing_test_referrer_module([
    Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32::new(0)),
        @lib.Instruction::i32_const(@lib.I32::new(1)),
        @lib.Instruction::i32_const(@lib.I32::new(2)),
        @lib.Instruction::memory_init(DataIdx::new(0U), @lib.MemIdx::new(0U)),
        @lib.Instruction::data_drop(DataIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32::new(3)),
        @lib.Instruction::i32_const(@lib.I32::new(4)),
        @lib.Instruction::array_new_data(TypeIdx::new(0U), DataIdx::new(2U)),
        @lib.Instruction::i32_const(@lib.I32::new(5)),
        @lib.Instruction::i32_const(@lib.I32::new(6)),
        @lib.Instruction::i32_const(@lib.I32::new(7)),
        @lib.Instruction::i32_const(@lib.I32::new(8)),
        @lib.Instruction::array_init_data(TypeIdx::new(0U), DataIdx::new(2U)),
      ]),
    ),
  ])
  assert_eq(optimization_memory_packing_collect_referrers(mod), [
    [
      MemoryPackingSegmentReferrer::MemoryInit(false),
      MemoryPackingSegmentReferrer::DataDrop,
    ],
    [],
    [
      MemoryPackingSegmentReferrer::ArrayNewData,
      MemoryPackingSegmentReferrer::ArrayInitData,
    ],
  ])
}

///|
test "memory packing computes raw alternating zero and nonzero ranges" {
  assert_eq(optimization_memory_packing_raw_ranges(b"ab\x00\x00cd\x00"), [
    MemoryPackingRange::new(false, 0, 2),
    MemoryPackingRange::new(true, 2, 4),
    MemoryPackingRange::new(false, 4, 6),
    MemoryPackingRange::new(true, 6, 7),
  ])
}

///|
test "memory packing range analysis merges small active zero runs" {
  let mod = optimization_memory_packing_test_defined_memory().with_data_sec(
    DataSec::new([
      optimization_memory_packing_test_active_data(
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
        b"ab\x00\x00\x00\x00\x00cd",
      ),
    ]),
  )
  assert_eq(
    optimization_memory_packing_ranges_for_segment(
      mod,
      DataIdx::new(0U),
      optimization_memory_packing_data(mod, DataIdx::new(0U)).unwrap(),
      [],
      PipelineFeatures::new(),
      0,
      1,
      optimization_memory_packing_max_data_segments,
    ),
    [MemoryPackingRange::new(false, 0, 9)],
  )
}

///|
test "memory packing range analysis keeps profitable passive edge zeroes for memory.init" {
  let mod = optimization_memory_packing_test_defined_memory()
    .with_data_sec(
      DataSec::new([
        Data::new(
          @lib.DataMode::passive(),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00HELLO\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
        ),
      ]),
    )
    .with_type_sec(
      @lib.TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::memory_init(
              DataIdx::new(0U),
              @lib.MemIdx::new(0U),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(25)),
            ),
          ]),
        ),
      ]),
    )
  let referrers = optimization_memory_packing_collect_referrers(mod)
  assert_eq(
    optimization_memory_packing_ranges_for_segment(
      mod,
      DataIdx::new(0U),
      optimization_memory_packing_data(mod, DataIdx::new(0U)).unwrap(),
      referrers[0],
      PipelineFeatures::new(),
      0,
      1,
      optimization_memory_packing_max_data_segments,
    ),
    [
      MemoryPackingRange::new(true, 0, 10),
      MemoryPackingRange::new(false, 10, 15),
      MemoryPackingRange::new(true, 15, 25),
    ],
  )
}

///|
test "memory packing range analysis preserves startup traps unless traps never happen" {
  let mod = optimization_memory_packing_test_defined_memory().with_data_sec(
    DataSec::new([
      optimization_memory_packing_test_active_data(
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(65536))]),
        b"\x00",
      ),
    ]),
  )
  let data = optimization_memory_packing_data(mod, DataIdx::new(0U)).unwrap()
  assert_eq(
    optimization_memory_packing_ranges_for_segment(
      mod,
      DataIdx::new(0U),
      data,
      [],
      PipelineFeatures::new(),
      0,
      1,
      optimization_memory_packing_max_data_segments,
    ),
    [MemoryPackingRange::new(true, 0, 0), MemoryPackingRange::new(false, 0, 1)],
  )
  assert_eq(
    optimization_memory_packing_ranges_for_segment(
      mod,
      DataIdx::new(0U),
      data,
      [],
      PipelineFeatures::new(traps_never_happen=true),
      0,
      1,
      optimization_memory_packing_max_data_segments,
    ),
    [MemoryPackingRange::new(true, 0, 1)],
  )
}

///|
test "memory packing range analysis refuses GC data consumers and llvm named segments" {
  let gc_mod = optimization_memory_packing_test_referrer_module([
    Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32::new(0)),
        @lib.Instruction::i32_const(@lib.I32::new(1)),
        @lib.Instruction::array_new_data(TypeIdx::new(0U), DataIdx::new(0U)),
      ]),
    ),
  ]).with_data_sec(
    DataSec::new([
      Data::new(
        @lib.DataMode::passive(),
        b"A\x00\x00\x00\x00\x00\x00\x00\x00\x00B",
      ),
    ]),
  )
  let gc_referrers = optimization_memory_packing_collect_referrers(gc_mod)
  assert_eq(
    optimization_memory_packing_ranges_for_segment(
      gc_mod,
      DataIdx::new(0U),
      optimization_memory_packing_data(gc_mod, DataIdx::new(0U)).unwrap(),
      gc_referrers[0],
      PipelineFeatures::new(),
      0,
      1,
      optimization_memory_packing_max_data_segments,
    ),
    [MemoryPackingRange::new(false, 0, 11)],
  )

  let llvm_mod = optimization_memory_packing_test_defined_memory()
    .with_data_sec(
      DataSec::new([
        Data::new(
          @lib.DataMode::passive(),
          b"A\x00\x00\x00\x00\x00\x00\x00\x00\x00B",
        ),
      ]),
    )
    .with_name_sec(
      NameSec::new(
        data_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("__llvm_covfun")),
          ]),
        ),
      ),
    )
  assert_eq(
    optimization_memory_packing_ranges_for_segment(
      llvm_mod,
      DataIdx::new(0U),
      optimization_memory_packing_data(llvm_mod, DataIdx::new(0U)).unwrap(),
      [],
      PipelineFeatures::new(),
      0,
      1,
      optimization_memory_packing_max_data_segments,
    ),
    [MemoryPackingRange::new(false, 0, 11)],
  )
}

///|
test "memory packing range analysis respects the segment-count cap" {
  let mod = optimization_memory_packing_test_defined_memory().with_data_sec(
    DataSec::new([
      optimization_memory_packing_test_active_data(
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
        b"A\x00\x00\x00\x00\x00\x00\x00\x00\x00B\x00\x00\x00\x00\x00\x00\x00\x00\x00C",
      ),
    ]),
  )
  assert_eq(
    optimization_memory_packing_ranges_for_segment(
      mod,
      DataIdx::new(0U),
      optimization_memory_packing_data(mod, DataIdx::new(0U)).unwrap(),
      [],
      PipelineFeatures::new(),
      2,
      1,
      4,
    ),
    [
      MemoryPackingRange::new(false, 0, 1),
      MemoryPackingRange::new(true, 1, 10),
      MemoryPackingRange::new(false, 10, 21),
    ],
  )
}

///|
test "memory packing removes unreferenced passive segments and remaps later data indices" {
  let mod = optimization_memory_packing_test_defined_memory()
    .with_data_sec(
      DataSec::new([
        Data::new(@lib.DataMode::passive(), b"dead"),
        optimization_memory_packing_test_active_data(
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          b"a",
        ),
        Data::new(@lib.DataMode::passive(), b"live"),
      ]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(3U)))
    .with_type_sec(
      @lib.TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::memory_init(
              DataIdx::new(2U),
              @lib.MemIdx::new(0U),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(1)),
            ),
          ]),
        ),
      ]),
    )
  let optimized = optimization_memory_packing_test_run(mod)
  match optimized.data_sec {
    Some(DataSec(datas)) =>
      assert_eq(datas, [
        optimization_memory_packing_test_active_data(
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          b"a",
        ),
        Data::new(@lib.DataMode::passive(), b"live"),
      ])
    _ => fail("expected compacted data section")
  }
  match optimized.data_cnt_sec {
    Some(@lib.DataCntSec(@lib.U32(count))) => assert_eq(count, 2U)
    _ => fail("expected rewritten data count")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      match body.inner() {
        [instr] =>
          match instr.kind {
            @lib.TMemoryInit(DataIdx(data_idx), @lib.MemIdx(mem_idx), _, _, _) => {
              assert_eq(data_idx, 1U)
              assert_eq(mem_idx, 0U)
            }
            _ => fail("expected remapped memory.init")
          }
        _ => fail("expected rewritten typed function body")
      }
    _ => fail("expected rewritten typed function body")
  }
}

///|
test "memory packing removes drop-only passive segments and rewrites data drops to nop" {
  let mod = optimization_memory_packing_test_referrer_module([
    Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::data_drop(DataIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32::new(3)),
        @lib.Instruction::i32_const(@lib.I32::new(4)),
        @lib.Instruction::array_new_data(TypeIdx::new(0U), DataIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32::new(5)),
        @lib.Instruction::i32_const(@lib.I32::new(6)),
        @lib.Instruction::i32_const(@lib.I32::new(7)),
        @lib.Instruction::i32_const(@lib.I32::new(8)),
        @lib.Instruction::array_init_data(TypeIdx::new(0U), DataIdx::new(1U)),
      ]),
    ),
  ]).with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(3U)))
  let optimized = optimization_memory_packing_test_run(mod)
  match optimized.data_sec {
    Some(DataSec(datas)) =>
      assert_eq(datas, [Data::new(@lib.DataMode::passive(), b"b")])
    _ => fail("expected compacted data section")
  }
  match optimized.data_cnt_sec {
    Some(@lib.DataCntSec(@lib.U32(count))) => assert_eq(count, 1U)
    _ => fail("expected rewritten data count")
  }
  match optimized.code_sec {
    Some(CodeSec([Func(_, @lib.Expr(instrs))])) => {
      assert_eq(instrs[0], @lib.Instruction::nop())
      assert_eq(
        instrs[3],
        @lib.Instruction::array_new_data(TypeIdx::new(0U), DataIdx::new(0U)),
      )
      assert_eq(
        instrs[8],
        @lib.Instruction::array_init_data(TypeIdx::new(0U), DataIdx::new(0U)),
      )
    }
    _ => fail("expected rewritten untyped function body")
  }
}

///|
test "memory packing materializes split active segments with shifted offsets and names" {
  let mod = optimization_memory_packing_test_defined_memory()
    .with_data_sec(
      DataSec::new([
        optimization_memory_packing_test_active_data(
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(10))]),
          b"AB\x00\x00CD",
        ),
      ]),
    )
    .with_name_sec(
      NameSec::new(
        data_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("blob")),
          ]),
        ),
      ),
    )
  let (materialized, replacements) = optimization_memory_packing_materialize_segments(
    mod,
    [
      [
        MemoryPackingRange::new(false, 0, 2),
        MemoryPackingRange::new(true, 2, 4),
        MemoryPackingRange::new(false, 4, 6),
      ],
    ],
  )
  assert_eq(replacements, [[DataIdx::new(0U), DataIdx::new(1U)]])
  match materialized.data_sec {
    Some(DataSec(datas)) =>
      assert_eq(datas, [
        optimization_memory_packing_test_active_data(
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(10))]),
          b"AB",
        ),
        optimization_memory_packing_test_active_data(
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(14))]),
          b"CD",
        ),
      ])
    _ => fail("expected materialized data section")
  }
  match materialized.name_sec {
    Some(name_sec) =>
      assert_eq(
        name_sec.data_names,
        Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("blob")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("blob.1")),
          ]),
        ),
      )
    None => fail("expected rewritten name section")
  }
}

///|
test "memory packing materialization saturates active i32 offsets instead of wrapping" {
  let mod = optimization_memory_packing_test_defined_memory().with_data_sec(
    DataSec::new([
      optimization_memory_packing_test_active_data(
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(-1))]),
        b"AB",
      ),
    ]),
  )
  let (materialized, replacements) = optimization_memory_packing_materialize_segments(
    mod,
    [
      [
        MemoryPackingRange::new(true, 0, 1),
        MemoryPackingRange::new(false, 1, 2),
      ],
    ],
  )
  assert_eq(replacements, [[DataIdx::new(0U)]])
  match materialized.data_sec {
    Some(DataSec([Data(@lib.Active(@lib.MemIdx(mem_idx), offset_expr), bytes)])) => {
      assert_eq(mem_idx, 0U)
      assert_eq(
        offset_expr,
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(-1))]),
      )
      assert_eq(bytes, b"B")
    }
    _ => fail("expected saturated active replacement")
  }
}

///|
test "memory packing rewrites split passive memory.init and data.drop with drop-state tracking" {
  let mod = optimization_memory_packing_test_defined_memory()
    .with_data_sec(
      DataSec::new([
        Data::new(
          @lib.DataMode::passive(),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00HELLO\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
        ),
      ]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(1U)))
    .with_type_sec(
      @lib.TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::memory_init(
              DataIdx::new(0U),
              @lib.MemIdx::new(0U),
              @lib.TInstr::i32_const(@lib.I32::new(100)),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(25)),
            ),
            @lib.TInstr::data_drop(DataIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = optimization_memory_packing_test_run(mod)
  match optimized.data_sec {
    Some(DataSec(datas)) =>
      assert_eq(datas, [Data::new(@lib.DataMode::passive(), b"HELLO")])
    _ => fail("expected split passive payload")
  }
  match optimized.global_sec {
    Some(
      GlobalSec(
        [
          Global(
            @lib.GlobalType(_, is_mutable),
            @lib.Expr([@lib.I32Const(@lib.I32(init))])
          ),
        ]
      )
    ) => {
      assert_true(is_mutable)
      assert_eq(init, 0)
    }
    _ => fail("expected drop-state global")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_eq(body.inner(), [
        @lib.TInstr::block(
          @lib.BlockType::void_(),
          @lib.TExpr::new([
            @lib.TInstr::if_(
              @lib.BlockType::void_(),
              @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
              @lib.TExpr::new([@lib.TInstr::unreachable_()]),
              None,
            ),
            @lib.TInstr::memory_fill(
              @lib.MemIdx::new(0U),
              @lib.TInstr::i32_const(@lib.I32::new(100)),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(10)),
            ),
            @lib.TInstr::memory_init(
              DataIdx::new(0U),
              @lib.MemIdx::new(0U),
              @lib.TInstr::binary(
                @lib.BinaryOp::i32_add(),
                @lib.TInstr::i32_const(@lib.I32::new(100)),
                @lib.TInstr::i32_const(@lib.I32::new(10)),
              ),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(5)),
            ),
            @lib.TInstr::memory_fill(
              @lib.MemIdx::new(0U),
              @lib.TInstr::binary(
                @lib.BinaryOp::i32_add(),
                @lib.TInstr::i32_const(@lib.I32::new(100)),
                @lib.TInstr::i32_const(@lib.I32::new(15)),
              ),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(10)),
            ),
          ]),
        ),
        @lib.TInstr::block(
          @lib.BlockType::void_(),
          @lib.TExpr::new([
            @lib.TInstr::global_set(
              @lib.GlobalIdx::new(0U),
              @lib.TInstr::i32_const(@lib.I32::new(1)),
            ),
            @lib.TInstr::data_drop(DataIdx::new(0U)),
          ]),
        ),
      ])
    _ => fail("expected rewritten typed body")
  }
}

///|
test "memory packing rewrites split passive memory.init with a fresh local for nonconstant destinations" {
  let mod = optimization_memory_packing_test_defined_memory()
    .with_data_sec(
      DataSec::new([
        Data::new(
          @lib.DataMode::passive(),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00HELLO\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
        ),
      ]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(1U)))
    .with_type_sec(
      @lib.TypeSec::new([
        RecType::new(
          SubType::comp_type(CompType::func([@lib.ValType::i32()], [])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [@lib.ValType::i32()],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::memory_init(
              DataIdx::new(0U),
              @lib.MemIdx::new(0U),
              @lib.TInstr::local_get(@lib.LocalIdx::new(0U)),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(25)),
            ),
          ]),
        ),
      ]),
    )
  let optimized = optimization_memory_packing_test_run(mod)
  match optimized.code_sec {
    Some(CodeSec([TFunc(params, locals, body)])) => {
      assert_eq(params, [@lib.ValType::i32()])
      assert_eq(locals, @lib.Locals::single(1U, @lib.ValType::i32()))
      assert_eq(body.inner(), [
        @lib.TInstr::block(
          @lib.BlockType::void_(),
          @lib.TExpr::new([
            @lib.TInstr::local_set(
              @lib.LocalIdx::new(1U),
              @lib.TInstr::local_get(@lib.LocalIdx::new(0U)),
            ),
            @lib.TInstr::memory_fill(
              @lib.MemIdx::new(0U),
              @lib.TInstr::local_get(@lib.LocalIdx::new(1U)),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(10)),
            ),
            @lib.TInstr::memory_init(
              DataIdx::new(0U),
              @lib.MemIdx::new(0U),
              @lib.TInstr::binary(
                @lib.BinaryOp::i32_add(),
                @lib.TInstr::local_get(@lib.LocalIdx::new(1U)),
                @lib.TInstr::i32_const(@lib.I32::new(10)),
              ),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(5)),
            ),
            @lib.TInstr::memory_fill(
              @lib.MemIdx::new(0U),
              @lib.TInstr::binary(
                @lib.BinaryOp::i32_add(),
                @lib.TInstr::local_get(@lib.LocalIdx::new(1U)),
                @lib.TInstr::i32_const(@lib.I32::new(15)),
              ),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(10)),
            ),
          ]),
        ),
      ])
    }
    _ => fail("expected rewritten typed function")
  }
}

///|
test "memory packing remaps array.new_data after earlier segment expansion changes data indices" {
  let mod = optimization_memory_packing_test_defined_memory()
    .with_data_sec(
      DataSec::new([
        optimization_memory_packing_test_active_data(
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          b"AA\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00BB",
        ),
        Data::new(@lib.DataMode::passive(), b"xy"),
      ]),
    )
    .with_type_sec(
      @lib.TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::i32_const(@lib.I32::new(2)),
            @lib.Instruction::array_new_data(TypeIdx::new(0U), DataIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = optimization_memory_packing_test_run(mod)
  match optimized.data_sec {
    Some(DataSec(datas)) =>
      assert_eq(datas, [
        optimization_memory_packing_test_active_data(
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          b"AA",
        ),
        optimization_memory_packing_test_active_data(
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(12))]),
          b"BB",
        ),
        Data::new(@lib.DataMode::passive(), b"xy"),
      ])
    _ => fail("expected expanded data section")
  }
  match optimized.code_sec {
    Some(CodeSec([Func(_, @lib.Expr(instrs))])) =>
      assert_eq(
        instrs[2],
        @lib.Instruction::array_new_data(TypeIdx::new(0U), DataIdx::new(2U)),
      )
    _ => fail("expected remapped array.new_data")
  }
}

///|
test "memory packing rewritten passive split output validates and is idempotent" {
  let mod = optimization_memory_packing_test_defined_memory()
    .with_data_sec(
      DataSec::new([
        Data::new(
          @lib.DataMode::passive(),
          b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00HELLO\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
        ),
      ]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(1U)))
    .with_type_sec(
      @lib.TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::memory_init(
              DataIdx::new(0U),
              @lib.MemIdx::new(0U),
              @lib.TInstr::i32_const(@lib.I32::new(100)),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TInstr::i32_const(@lib.I32::new(25)),
            ),
            @lib.TInstr::data_drop(DataIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = optimization_memory_packing_test_run(mod)
  assert_eq(validate_module(optimized), Ok(()))
  assert_eq(optimization_memory_packing_test_run(optimized), optimized)
}

///|
test "memory packing startup-trap-preserving output validates and is idempotent" {
  let mod = optimization_memory_packing_test_defined_memory().with_data_sec(
    DataSec::new([
      optimization_memory_packing_test_active_data(
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(65535))]),
        b"\x00\x00",
      ),
    ]),
  )
  let optimized = optimization_memory_packing_test_run(mod)
  match optimized.data_sec {
    Some(DataSec(datas)) =>
      assert_eq(datas, [
        optimization_memory_packing_test_active_data(
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(65536))]),
          b"\x00",
        ),
      ])
    _ => fail("expected trap-preserving active output")
  }
  assert_eq(validate_module(optimized), Ok(()))
  assert_eq(optimization_memory_packing_test_run(optimized), optimized)
}

///|
fn optimization_imported_func_count(mod : Module) -> Int {
  let mut count = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn optimization_imported_global_count(mod : Module) -> Int {
  let mut count = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn optimization_all_global_types(
  mod : Module,
  globals : Array[Global],
) -> Array[@lib.GlobalType] {
  let out : Array[@lib.GlobalType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(gt)) => out.push(gt)
          _ => ()
        }
      }
    None => ()
  }
  for global in globals {
    let Global(gt, _) = global
    out.push(gt)
  }
  out
}

///|
fn optimization_imported_table_count(mod : Module) -> Int {
  let mut count = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, TableExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn optimization_imported_mem_count(mod : Module) -> Int {
  let mut count = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, MemExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn optimization_imported_tag_count(mod : Module) -> Int {
  let mut count = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, TagExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn optimization_flatten_subtypes(mod : Module) -> Array[SubType] {
  let subtypes : Array[SubType] = []
  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(subtype) => subtypes.push(subtype)
          GroupRecType(group) =>
            for subtype in group {
              subtypes.push(subtype)
            }
        }
      }
    None => ()
  }
  subtypes
}

///|
fn optimization_resolve_func_type(
  subtypes : Array[SubType],
  type_idx : TypeIdx,
) -> FuncType? {
  match type_idx {
    TypeIdx(idx) =>
      match subtypes.get(idx.reinterpret_as_int()) {
        Some(subtype) =>
          match subtype.get_comptype() {
            FuncCompType(params, results) =>
              Some(FuncType::new(params, results))
            _ => None
          }
        None => None
      }
    RecIdx(_) => None
  }
}

///|
fn optimization_functions_equivalent(
  subtypes : Array[SubType],
  left_type : TypeIdx,
  left_func : Func,
  right_type : TypeIdx,
  right_func : Func,
) -> Bool {
  if left_func != right_func {
    return false
  }
  match
    (
      optimization_resolve_func_type(subtypes, left_type),
      optimization_resolve_func_type(subtypes, right_type),
    ) {
    (Some(left), Some(right)) => left == right
    _ => left_type == right_type
  }
}

///|
fn optimization_function_hash_key(
  subtypes : Array[SubType],
  type_idx : TypeIdx,
  func : Func,
) -> Int {
  let type_hash = match optimization_resolve_func_type(subtypes, type_idx) {
    Some(func_type) => func_type.hash()
    None => type_idx.hash()
  }
  func.hash() * 31 + type_hash
}

///|
fn optimization_canonical_local_idx(
  replacements : Map[Int, Int],
  local_idx : Int,
) -> Int {
  let mut current = local_idx
  while true {
    match replacements.get(current) {
      Some(next) => current = next
      None => return current
    }
  }
  current
}

///|
fn optimization_rewrite_func_indices(
  mod : Module,
  remap : Map[UInt, UInt],
) -> Module {
  let transformer : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_funcidx_evt(fn(
      _,
      _,
      idx : FuncIdx,
    ) {
      let FuncIdx(raw) = idx
      let next = remap.get(raw).unwrap_or(raw)
      change((), FuncIdx::new(next))
    },
  )
  match transformer.walk_module((), mod) {
    Ok((rewritten, _)) => rewritten
    Err(_) => mod
  }
}

///|
fn optimization_rewrite_name_map(
  names : NameMap,
  remap : Map[UInt, UInt],
) -> NameMap {
  let NameMap(entries) = names
  let rewritten : Array[NameAssoc] = []
  let mut last_idx : UInt? = None
  for entry in entries {
    let NameAssoc(idx, name) = entry
    let next_idx = remap.get(idx).unwrap_or(idx)
    if last_idx == Some(next_idx) {
      continue
    }
    rewritten.push(NameAssoc::new(next_idx, name))
    last_idx = Some(next_idx)
  }
  NameMap::new(rewritten)
}

///|
fn optimization_rewrite_name_map_filtered(
  names : NameMap,
  remap : Map[UInt, UInt],
  drop_unmapped : Bool,
) -> NameMap {
  let NameMap(entries) = names
  let rewritten : Array[NameAssoc] = []
  let mut last_idx : UInt? = None
  for entry in entries {
    let NameAssoc(idx, name) = entry
    match remap.get(idx) {
      Some(next_idx) => {
        if last_idx == Some(next_idx) {
          continue
        }
        rewritten.push(NameAssoc::new(next_idx, name))
        last_idx = Some(next_idx)
      }
      None =>
        if !drop_unmapped {
          if last_idx == Some(idx) {
            continue
          }
          rewritten.push(entry)
          last_idx = Some(idx)
        }
    }
  }
  NameMap::new(rewritten)
}

///|
fn optimization_rewrite_func_name_map(
  names : NameMap,
  remap : Map[UInt, UInt],
) -> NameMap {
  optimization_rewrite_name_map(names, remap)
}

///|
fn optimization_rewrite_func_name_map_filtered(
  names : NameMap,
  remap : Map[UInt, UInt],
  drop_unmapped : Bool,
) -> NameMap {
  optimization_rewrite_name_map_filtered(names, remap, drop_unmapped)
}

///|
fn optimization_rewrite_local_name_map(
  names : IndirectNameMap,
  remap : Map[UInt, UInt],
) -> IndirectNameMap {
  let IndirectNameMap(entries) = names
  let rewritten : Array[IndirectNameAssoc] = []
  let mut last_idx : UInt? = None
  for entry in entries {
    let IndirectNameAssoc(idx, local_names) = entry
    let next_idx = remap.get(idx).unwrap_or(idx)
    if last_idx == Some(next_idx) {
      continue
    }
    rewritten.push(IndirectNameAssoc::new(next_idx, local_names))
    last_idx = Some(next_idx)
  }
  IndirectNameMap::new(rewritten)
}

///|
fn optimization_rewrite_local_name_map_filtered(
  names : IndirectNameMap,
  remap : Map[UInt, UInt],
  drop_unmapped : Bool,
) -> IndirectNameMap {
  let IndirectNameMap(entries) = names
  let rewritten : Array[IndirectNameAssoc] = []
  let mut last_idx : UInt? = None
  for entry in entries {
    let IndirectNameAssoc(idx, local_names) = entry
    match remap.get(idx) {
      Some(next_idx) => {
        if last_idx == Some(next_idx) {
          continue
        }
        rewritten.push(IndirectNameAssoc::new(next_idx, local_names))
        last_idx = Some(next_idx)
      }
      None =>
        if !drop_unmapped {
          if last_idx == Some(idx) {
            continue
          }
          rewritten.push(entry)
          last_idx = Some(idx)
        }
    }
  }
  IndirectNameMap::new(rewritten)
}

///|
fn optimization_rewrite_name_sec(
  name_sec : NameSec,
  remap : Map[UInt, UInt],
) -> NameSec {
  let {
    module_name,
    func_names,
    local_names,
    label_names,
    type_names,
    table_names,
    memory_names,
    global_names,
    elem_names,
    data_names,
    field_names,
    tag_names,
  } = name_sec
  NameSec::new(
    module_name~,
    func_names=match func_names {
      Some(names) => Some(optimization_rewrite_func_name_map(names, remap))
      None => None
    },
    local_names=match local_names {
      Some(names) => Some(optimization_rewrite_local_name_map(names, remap))
      None => None
    },
    label_names~,
    type_names~,
    table_names~,
    memory_names~,
    global_names~,
    elem_names~,
    data_names~,
    field_names~,
    tag_names~,
  )
}

///|
fn optimization_rewrite_name_sec_filtered(
  name_sec : NameSec,
  remap : Map[UInt, UInt],
  drop_unmapped : Bool,
  table_remap : Map[UInt, UInt]?,
  memory_remap : Map[UInt, UInt]?,
  global_remap : Map[UInt, UInt]?,
  tag_remap : Map[UInt, UInt]?,
  elem_remap : Map[UInt, UInt]?,
  data_remap : Map[UInt, UInt]?,
) -> NameSec {
  let {
    module_name,
    func_names,
    local_names,
    label_names,
    type_names,
    table_names,
    memory_names,
    global_names,
    elem_names,
    data_names,
    field_names,
    tag_names,
  } = name_sec
  NameSec::new(
    module_name~,
    func_names=match func_names {
      Some(names) =>
        Some(
          optimization_rewrite_func_name_map_filtered(
            names, remap, drop_unmapped,
          ),
        )
      None => None
    },
    local_names=match local_names {
      Some(names) =>
        Some(
          optimization_rewrite_local_name_map_filtered(
            names, remap, drop_unmapped,
          ),
        )
      None => None
    },
    label_names~,
    type_names~,
    table_names=match (table_names, table_remap) {
      (Some(names), Some(remap)) =>
        Some(optimization_rewrite_name_map_filtered(names, remap, true))
      (Some(names), None) => Some(names)
      _ => None
    },
    memory_names=match (memory_names, memory_remap) {
      (Some(names), Some(remap)) =>
        Some(optimization_rewrite_name_map_filtered(names, remap, true))
      (Some(names), None) => Some(names)
      _ => None
    },
    global_names=match (global_names, global_remap) {
      (Some(names), Some(remap)) =>
        Some(optimization_rewrite_name_map_filtered(names, remap, true))
      (Some(names), None) => Some(names)
      _ => None
    },
    elem_names=match (elem_names, elem_remap) {
      (Some(names), Some(remap)) =>
        Some(optimization_rewrite_name_map_filtered(names, remap, true))
      (Some(names), None) => Some(names)
      _ => None
    },
    data_names=match (data_names, data_remap) {
      (Some(names), Some(remap)) =>
        Some(optimization_rewrite_name_map_filtered(names, remap, true))
      (Some(names), None) => Some(names)
      _ => None
    },
    field_names~,
    tag_names=match (tag_names, tag_remap) {
      (Some(names), Some(remap)) =>
        Some(optimization_rewrite_name_map_filtered(names, remap, true))
      (Some(names), None) => Some(names)
      _ => None
    },
  )
}

///|
fn optimization_note_used_func(
  used : Array[Bool],
  worklist : Array[Int],
  imported_count : Int,
  defined_count : Int,
  idx : FuncIdx,
) -> Unit {
  let FuncIdx(raw) = idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= used.length() {
    return
  }
  if used[abs_idx] {
    return
  }
  used[abs_idx] = true
  if abs_idx >= imported_count && abs_idx < imported_count + defined_count {
    worklist.push(abs_idx - imported_count)
  }
}

///|
fn optimization_note_used_global(
  used : Array[Bool],
  worklist : Array[Int],
  imported_count : Int,
  defined_count : Int,
  idx : GlobalIdx,
) -> Unit {
  let GlobalIdx(raw) = idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= used.length() {
    return
  }
  if used[abs_idx] {
    return
  }
  used[abs_idx] = true
  if abs_idx >= imported_count && abs_idx < imported_count + defined_count {
    worklist.push(abs_idx - imported_count)
  }
}

///|
fn optimization_note_referenced_global(
  referenced : Array[Bool],
  worklist : Array[Int],
  imported_count : Int,
  defined_count : Int,
  idx : GlobalIdx,
) -> Unit {
  let GlobalIdx(raw) = idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= referenced.length() {
    return
  }
  if referenced[abs_idx] {
    return
  }
  referenced[abs_idx] = true
  if abs_idx >= imported_count && abs_idx < imported_count + defined_count {
    worklist.push(abs_idx - imported_count)
  }
}

///|
fn optimization_note_used_table(
  used : Array[Bool],
  worklist : Array[Int],
  imported_count : Int,
  defined_count : Int,
  idx : TableIdx,
) -> Unit {
  let TableIdx(raw) = idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= used.length() {
    return
  }
  if used[abs_idx] {
    return
  }
  used[abs_idx] = true
  if abs_idx >= imported_count && abs_idx < imported_count + defined_count {
    worklist.push(abs_idx - imported_count)
  }
}

///|
fn optimization_note_observable_table(
  used : Array[Bool],
  observable : Array[Bool],
  worklist : Array[Int],
  imported_count : Int,
  defined_count : Int,
  idx : TableIdx,
) -> Unit {
  let TableIdx(raw) = idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= used.length() {
    return
  }
  let was_observable = observable[abs_idx]
  if !used[abs_idx] {
    used[abs_idx] = true
  }
  if was_observable {
    return
  }
  observable[abs_idx] = true
  if abs_idx >= imported_count && abs_idx < imported_count + defined_count {
    worklist.push(abs_idx - imported_count)
  }
}

///|
fn optimization_note_used_mem(
  used : Array[Bool],
  imported_count : Int,
  defined_count : Int,
  idx : MemIdx,
) -> Unit {
  let MemIdx(raw) = idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= used.length() {
    return
  }
  if used[abs_idx] {
    return
  }
  used[abs_idx] = true
  let _ = imported_count
  let _ = defined_count
}

///|
fn optimization_note_used_tag(
  used : Array[Bool],
  worklist : Array[Int],
  imported_count : Int,
  defined_count : Int,
  idx : TagIdx,
) -> Unit {
  let TagIdx(raw) = idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= used.length() {
    return
  }
  if used[abs_idx] {
    return
  }
  used[abs_idx] = true
  let _ = worklist
  let _ = imported_count
  let _ = defined_count
}

///|
fn optimization_note_used_elem(
  used : Array[Bool],
  worklist : Array[Int],
  idx : ElemIdx,
) -> Unit {
  let ElemIdx(raw) = idx
  let elem_idx = raw.reinterpret_as_int()
  if elem_idx < 0 || elem_idx >= used.length() {
    return
  }
  if used[elem_idx] {
    return
  }
  used[elem_idx] = true
  worklist.push(elem_idx)
}

///|
fn optimization_note_referenced_elem(
  referenced : Array[Bool],
  worklist : Array[Int],
  idx : ElemIdx,
) -> Unit {
  let ElemIdx(raw) = idx
  let elem_idx = raw.reinterpret_as_int()
  if elem_idx < 0 || elem_idx >= referenced.length() {
    return
  }
  if referenced[elem_idx] {
    return
  }
  referenced[elem_idx] = true
  worklist.push(elem_idx)
}

///|
fn optimization_note_used_data(
  used : Array[Bool],
  worklist : Array[Int],
  idx : DataIdx,
) -> Unit {
  let DataIdx(raw) = idx
  let data_idx = raw.reinterpret_as_int()
  if data_idx < 0 || data_idx >= used.length() {
    return
  }
  if used[data_idx] {
    return
  }
  used[data_idx] = true
  worklist.push(data_idx)
}

///|
fn optimization_collect_func_uses_in_expr(
  expr : @lib.Expr,
  features : PipelineFeatures,
  called_ref_types : Array[Bool],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  referenced_funcs : Array[Bool],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
  used_globals : Array[Bool],
  global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  used_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  used_mems : Array[Bool],
  imported_mem_count : Int,
  defined_mem_count : Int,
  used_tags : Array[Bool],
  tag_worklist : Array[Int],
  imported_tag_count : Int,
  defined_tag_count : Int,
) -> Unit {
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_instruction_evt(fn(_, _, instr) {
      match instr {
        @lib.RefFunc(idx) =>
          optimization_note_ref_func(
            idx, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count,
          )
        _ => ()
      }
      unchanged()
    })
    .on_globalidx_evt(fn(_, _, idx) {
      optimization_note_used_global(
        used_globals, global_worklist, imported_global_count, defined_global_count,
        idx,
      )
      unchanged()
    })
    .on_tableidx_evt(fn(_, _, idx) {
      optimization_note_used_table(
        used_tables, table_worklist, imported_table_count, defined_table_count, idx,
      )
      unchanged()
    })
    .on_memidx_evt(fn(_, _, idx) {
      optimization_note_used_mem(
        used_mems, imported_mem_count, defined_mem_count, idx,
      )
      unchanged()
    })
    .on_tagidx_evt(fn(_, _, idx) {
      optimization_note_used_tag(
        used_tags, tag_worklist, imported_tag_count, defined_tag_count, idx,
      )
      unchanged()
    })
  ignore(walker.walk_expr((), expr))
}

///|
fn optimization_collect_references_in_expr(
  expr : @lib.Expr,
  referenced_funcs : Array[Bool],
  referenced_globals : Array[Bool],
  referenced_global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
) -> Unit {
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_instruction_evt(fn(_, _, instr) {
      match instr {
        @lib.RefFunc(idx) =>
          optimization_note_referenced_func(referenced_funcs, idx)
        _ => ()
      }
      unchanged()
    })
    .on_globalidx_evt(fn(_, _, idx) {
      optimization_note_referenced_global(
        referenced_globals, referenced_global_worklist, imported_global_count, defined_global_count,
        idx,
      )
      unchanged()
    })
  ignore(walker.walk_expr((), expr))
}

///|
fn optimization_collect_references_in_tinstr(
  instr : @lib.TInstr,
  referenced_funcs : Array[Bool],
  referenced_globals : Array[Bool],
  referenced_global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
) -> Unit {
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_tinstruction_evt(fn(_, _, curr) {
      match curr.kind {
        @lib.TRefFunc(idx) => {
          optimization_note_referenced_func(referenced_funcs, idx)
          skip()
        }
        _ => unchanged()
      }
    })
    .on_globalidx_evt(fn(_, _, idx) {
      optimization_note_referenced_global(
        referenced_globals, referenced_global_worklist, imported_global_count, defined_global_count,
        idx,
      )
      unchanged()
    })
  ignore(walker.walk_tinstruction((), instr))
}

///|
fn optimization_collect_reference_identity_in_tinstr(
  instr : @lib.TInstr,
  referenced_funcs : Array[Bool],
  referenced_globals : Array[Bool],
  referenced_global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
) -> Unit {
  match instr.kind {
    @lib.TRefFunc(idx) =>
      optimization_note_referenced_func(referenced_funcs, idx)
    @lib.TGlobalGet(idx) =>
      optimization_note_referenced_global(
        referenced_globals, referenced_global_worklist, imported_global_count, defined_global_count,
        idx,
      )
    @lib.TStructNewDesc(_, operands) =>
      if operands.length() > 0 {
        optimization_collect_reference_identity_in_tinstr(
          operands[operands.length() - 1],
          referenced_funcs,
          referenced_globals,
          referenced_global_worklist,
          imported_global_count,
          defined_global_count,
        )
      }
    @lib.TStructNewDefaultDesc(_, descriptor)
    | @lib.TRefIsNull(descriptor)
    | @lib.TRefAsNonNull(descriptor)
    | @lib.TAnyConvertExtern(descriptor)
    | @lib.TExternConvertAny(descriptor)
    | @lib.TRefGetDesc(_, descriptor)
    | @lib.TRefTest(_, _, descriptor)
    | @lib.TRefCast(_, _, descriptor)
    | @lib.TRefTestDesc(_, _, descriptor)
    | @lib.TBrOnNull(_, descriptor, _)
    | @lib.TBrOnNonNull(_, descriptor, _)
    | @lib.TBrOnCast(_, _, _, _, descriptor, _)
    | @lib.TBrOnCastFail(_, _, _, _, descriptor, _) =>
      optimization_collect_reference_identity_in_tinstr(
        descriptor, referenced_funcs, referenced_globals, referenced_global_worklist,
        imported_global_count, defined_global_count,
      )
    @lib.TRefCastDescEq(_, _, descriptor) =>
      optimization_collect_reference_identity_in_tinstr(
        descriptor, referenced_funcs, referenced_globals, referenced_global_worklist,
        imported_global_count, defined_global_count,
      )
    @lib.TRefEq(left, right) => {
      optimization_collect_reference_identity_in_tinstr(
        left, referenced_funcs, referenced_globals, referenced_global_worklist, imported_global_count,
        defined_global_count,
      )
      optimization_collect_reference_identity_in_tinstr(
        right, referenced_funcs, referenced_globals, referenced_global_worklist,
        imported_global_count, defined_global_count,
      )
    }
    _ => ()
  }
}

///|
fn optimization_collect_references_in_global(
  global_ : Global,
  referenced_funcs : Array[Bool],
  referenced_globals : Array[Bool],
  referenced_global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
) -> Unit {
  match global_ {
    @lib.Global(_, init) =>
      optimization_collect_references_in_expr(
        init, referenced_funcs, referenced_globals, referenced_global_worklist, imported_global_count,
        defined_global_count,
      )
  }
}

///|
fn optimization_collect_references_in_elem(
  elem : Elem,
  referenced_funcs : Array[Bool],
  referenced_globals : Array[Bool],
  referenced_global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
) -> Unit {
  match elem {
    Elem(_, @lib.FuncsElemKind(funcs)) =>
      for func_idx in funcs {
        optimization_note_referenced_func(referenced_funcs, func_idx)
      }
    Elem(_, @lib.FuncExprsElemKind(exprs))
    | Elem(_, @lib.TypedExprsElemKind(_, exprs)) =>
      for expr in exprs {
        optimization_collect_references_in_expr(
          expr, referenced_funcs, referenced_globals, referenced_global_worklist,
          imported_global_count, defined_global_count,
        )
      }
  }
}

///|
fn optimization_imported_func_type_idxs(mod : Module) -> Array[TypeIdx] {
  let type_idxs : Array[TypeIdx] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) => type_idxs.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  type_idxs
}

///|
fn optimization_all_func_type_idxs(
  mod : Module,
  defined_type_idxs : Array[TypeIdx],
) -> Array[TypeIdx] {
  let type_idxs = optimization_imported_func_type_idxs(mod)
  for type_idx in defined_type_idxs {
    type_idxs.push(type_idx)
  }
  type_idxs
}

///|
fn optimization_note_referenced_func(
  referenced_funcs : Array[Bool],
  func_idx : FuncIdx,
) -> Unit {
  let FuncIdx(raw) = func_idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= referenced_funcs.length() {
    return
  }
  referenced_funcs[abs_idx] = true
}

///|
fn optimization_type_idx_bucket(type_idx : TypeIdx) -> Int? {
  match type_idx {
    TypeIdx(raw) | RecIdx(raw) => Some(raw.reinterpret_as_int())
  }
}

///|
fn optimization_called_ref_type_matches_func(
  called_ref_types : Array[Bool],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  func_idx : FuncIdx,
) -> Bool {
  let mut i = 0
  while i < called_ref_types.length() {
    if called_ref_types[i] &&
      optimization_func_matches_call_type(
        subtypes,
        func_type_idxs,
        func_idx,
        TypeIdx::new(i.reinterpret_as_uint()),
      ) {
      return true
    }
    i += 1
  }
  false
}

///|
fn optimization_note_called_ref_type(
  call_type_idx : TypeIdx,
  called_ref_types : Array[Bool],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
) -> Unit {
  match optimization_type_idx_bucket(call_type_idx) {
    Some(raw_idx) =>
      if raw_idx >= 0 && raw_idx < called_ref_types.length() {
        called_ref_types[raw_idx] = true
      }
    None => ()
  }
  let mut abs_func_idx = 0
  while abs_func_idx < call_ref_candidate_funcs.length() {
    if call_ref_candidate_funcs[abs_func_idx] &&
      optimization_func_matches_call_type(
        subtypes,
        func_type_idxs,
        FuncIdx::new(abs_func_idx.reinterpret_as_uint()),
        call_type_idx,
      ) {
      optimization_note_used_func(
        used_funcs,
        func_worklist,
        imported_func_count,
        defined_func_count,
        FuncIdx::new(abs_func_idx.reinterpret_as_uint()),
      )
    }
    abs_func_idx += 1
  }
}

///|
fn optimization_note_indirect_call_type_for_table(
  indirect_call_types_by_table : Array[Array[Bool]],
  table_idx : TableIdx,
  call_type_idx : TypeIdx,
) -> Unit {
  let TableIdx(raw_table_idx) = table_idx
  let abs_table_idx = raw_table_idx.reinterpret_as_int()
  if abs_table_idx < 0 || abs_table_idx >= indirect_call_types_by_table.length() {
    return
  }
  match optimization_type_idx_bucket(call_type_idx) {
    Some(type_idx) =>
      if type_idx >= 0 &&
        type_idx < indirect_call_types_by_table[abs_table_idx].length() {
        indirect_call_types_by_table[abs_table_idx][type_idx] = true
      }
    None => ()
  }
}

///|
fn optimization_promote_mutated_indirect_table_signatures(
  indirect_call_types_by_table : Array[Array[Bool]],
  table_idx : TableIdx,
  called_ref_types : Array[Bool],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
) -> Unit {
  let TableIdx(raw_table_idx) = table_idx
  let abs_table_idx = raw_table_idx.reinterpret_as_int()
  if abs_table_idx < 0 || abs_table_idx >= indirect_call_types_by_table.length() {
    return
  }
  let table_types = indirect_call_types_by_table[abs_table_idx]
  let mut type_idx = 0
  while type_idx < table_types.length() {
    if table_types[type_idx] {
      optimization_note_called_ref_type(
        TypeIdx::new(type_idx.reinterpret_as_uint()),
        called_ref_types,
        subtypes,
        func_type_idxs,
        call_ref_candidate_funcs,
        used_funcs,
        func_worklist,
        imported_func_count,
        defined_func_count,
      )
    }
    type_idx += 1
  }
}

///|
fn optimization_note_ref_func(
  func_idx : FuncIdx,
  features : PipelineFeatures,
  called_ref_types : Array[Bool],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  referenced_funcs : Array[Bool],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
) -> Unit {
  if !features.closed_world {
    optimization_note_used_func(
      used_funcs, func_worklist, imported_func_count, defined_func_count, func_idx,
    )
    return
  }
  optimization_note_referenced_func(referenced_funcs, func_idx)
  let FuncIdx(raw) = func_idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx >= 0 && abs_idx < call_ref_candidate_funcs.length() {
    call_ref_candidate_funcs[abs_idx] = true
  }
  if optimization_called_ref_type_matches_func(
      called_ref_types, subtypes, func_type_idxs, func_idx,
    ) {
    optimization_note_used_func(
      used_funcs, func_worklist, imported_func_count, defined_func_count, func_idx,
    )
  }
}

///|
fn optimization_func_matches_call_type(
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  func_idx : FuncIdx,
  call_type_idx : TypeIdx,
) -> Bool {
  let FuncIdx(raw) = func_idx
  match func_type_idxs.get(raw.reinterpret_as_int()) {
    Some(func_type_idx) =>
      match
        (
          optimization_resolve_func_type(subtypes, func_type_idx),
          optimization_resolve_func_type(subtypes, call_type_idx),
        ) {
        (Some(func_type), Some(call_type)) => func_type == call_type
        _ => func_type_idx == call_type_idx
      }
    None => false
  }
}

///|
fn optimization_expr_ref_func_idx(expr : @lib.Expr) -> FuncIdx? {
  match expr {
    Expr([@lib.RefFunc(func_idx)]) => Some(func_idx)
    _ => None
  }
}

///|
fn optimization_elem_matches_call_type(
  elem : Elem,
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  call_type_idx : TypeIdx,
) -> Bool {
  match elem {
    Elem(_, @lib.FuncsElemKind(funcs)) =>
      for func_idx in funcs {
        if optimization_func_matches_call_type(
            subtypes, func_type_idxs, func_idx, call_type_idx,
          ) {
          return true
        }
      }
    Elem(_, @lib.FuncExprsElemKind(exprs))
    | Elem(_, @lib.TypedExprsElemKind(_, exprs)) =>
      for expr in exprs {
        match optimization_expr_ref_func_idx(expr) {
          Some(func_idx) =>
            if optimization_func_matches_call_type(
                subtypes, func_type_idxs, func_idx, call_type_idx,
              ) {
              return true
            }
          None => ()
        }
      }
  }
  false
}

///|
fn optimization_active_elem_indices_by_table(
  elems : Array[Elem],
  total_table_count : Int,
) -> Array[Array[Int]] {
  let by_table : Array[Array[Int]] = []
  for _ in 0..<total_table_count {
    by_table.push([])
  }
  let mut i = 0
  while i < elems.length() {
    match elems[i] {
      Elem(@lib.Active(@lib.TableIdx(table_idx), _), _) => {
        let abs_table_idx = table_idx.reinterpret_as_int()
        if abs_table_idx >= 0 && abs_table_idx < by_table.length() {
          by_table[abs_table_idx].push(i)
        }
      }
      _ => ()
    }
    i += 1
  }
  by_table
}

///|
fn optimization_collect_indirect_call_elem_uses(
  table_idx : TableIdx,
  call_type_idx : TypeIdx,
  active_elem_indices_by_table : Array[Array[Int]],
  elems : Array[Elem],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  used_elems : Array[Bool],
  elem_worklist : Array[Int],
) -> Unit {
  let TableIdx(raw) = table_idx
  let abs_table_idx = raw.reinterpret_as_int()
  if abs_table_idx < 0 || abs_table_idx >= active_elem_indices_by_table.length() {
    return
  }
  for elem_idx in active_elem_indices_by_table[abs_table_idx] {
    if optimization_elem_matches_call_type(
        elems[elem_idx],
        subtypes,
        func_type_idxs,
        call_type_idx,
      ) {
      optimization_note_used_elem(
        used_elems,
        elem_worklist,
        ElemIdx::new(elem_idx.reinterpret_as_uint()),
      )
    }
  }
}

///|
fn optimization_mark_indirect_called_table(
  used_tables : Array[Bool],
  indirect_called_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  table_idx : TableIdx,
) -> Unit {
  optimization_note_used_table(
    used_tables, table_worklist, imported_table_count, defined_table_count, table_idx,
  )
  let TableIdx(raw) = table_idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= indirect_called_tables.length() {
    return
  }
  indirect_called_tables[abs_idx] = true
}

///|
fn optimization_mark_mutated_table(
  used_tables : Array[Bool],
  mutated_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  table_idx : TableIdx,
) -> Unit {
  optimization_note_used_table(
    used_tables, table_worklist, imported_table_count, defined_table_count, table_idx,
  )
  let TableIdx(raw) = table_idx
  let abs_idx = raw.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= mutated_tables.length() {
    return
  }
  mutated_tables[abs_idx] = true
}

///|
fn optimization_collect_module_element_uses_in_func(
  func : Func,
  features : PipelineFeatures,
  called_ref_types : Array[Bool],
  indirect_call_types_by_table : Array[Array[Bool]],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  referenced_funcs : Array[Bool],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
  used_globals : Array[Bool],
  global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  used_tables : Array[Bool],
  observable_tables : Array[Bool],
  indirect_called_tables : Array[Bool],
  mutated_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  used_mems : Array[Bool],
  imported_mem_count : Int,
  defined_mem_count : Int,
  used_tags : Array[Bool],
  tag_worklist : Array[Int],
  imported_tag_count : Int,
  defined_tag_count : Int,
  used_elems : Array[Bool],
  elem_worklist : Array[Int],
  used_datas : Array[Bool],
  data_worklist : Array[Int],
  elems : Array[Elem],
  active_elem_indices_by_table : Array[Array[Int]],
  struct_subtype_children : Array[Array[Int]],
  read_struct_fields : Array[Array[Bool]],
  unread_struct_field_payloads : Array[Array[Array[@lib.TInstr]]],
  read_array_contents : Array[Bool],
  unread_array_payloads : Array[Array[@lib.TInstr]],
  unread_array_elem_payloads : Array[Array[Int]],
  referenced_globals : Array[Bool],
  referenced_global_worklist : Array[Int],
  referenced_elems : Array[Bool],
  referenced_elem_worklist : Array[Int],
) -> Unit {
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_globalidx_evt(fn(_, _, idx) {
      optimization_note_used_global(
        used_globals, global_worklist, imported_global_count, defined_global_count,
        idx,
      )
      unchanged()
    })
    .on_memidx_evt(fn(_, _, idx) {
      optimization_note_used_mem(
        used_mems, imported_mem_count, defined_mem_count, idx,
      )
      unchanged()
    })
    .on_tagidx_evt(fn(_, _, idx) {
      optimization_note_used_tag(
        used_tags, tag_worklist, imported_tag_count, defined_tag_count, idx,
      )
      unchanged()
    })
    .on_elemidx_evt(fn(_, _, idx) {
      optimization_note_used_elem(used_elems, elem_worklist, idx)
      unchanged()
    })
    .on_dataidx_evt(fn(_, _, idx) {
      optimization_note_used_data(used_datas, data_worklist, idx)
      unchanged()
    })
    .on_instruction_evt(fn(_, _, instr) {
      match instr {
        @lib.Call(func_idx) | @lib.ReturnCall(func_idx) =>
          optimization_note_used_func(
            used_funcs, func_worklist, imported_func_count, defined_func_count, func_idx,
          )
        @lib.CallRef(type_idx) | @lib.ReturnCallRef(type_idx) =>
          optimization_note_called_ref_type(
            type_idx, called_ref_types, subtypes, func_type_idxs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count,
          )
        @lib.RefFunc(func_idx) =>
          optimization_note_ref_func(
            func_idx, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count,
          )
        @lib.CallIndirect(type_idx, table_idx)
        | @lib.ReturnCallIndirect(type_idx, table_idx) => {
          optimization_mark_indirect_called_table(
            used_tables, indirect_called_tables, table_worklist, imported_table_count,
            defined_table_count, table_idx,
          )
          optimization_note_indirect_call_type_for_table(
            indirect_call_types_by_table, table_idx, type_idx,
          )
          optimization_collect_indirect_call_elem_uses(
            table_idx, type_idx, active_elem_indices_by_table, elems, subtypes, func_type_idxs,
            used_elems, elem_worklist,
          )
          let TableIdx(raw_table_idx) = table_idx
          let abs_table_idx = raw_table_idx.reinterpret_as_int()
          if abs_table_idx >= 0 &&
            abs_table_idx < mutated_tables.length() &&
            mutated_tables[abs_table_idx] {
            optimization_promote_mutated_indirect_table_signatures(
              indirect_call_types_by_table, table_idx, called_ref_types, subtypes,
              func_type_idxs, call_ref_candidate_funcs, used_funcs, func_worklist,
              imported_func_count, defined_func_count,
            )
          }
        }
        @lib.TableGet(table_idx) =>
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, table_idx,
          )
        @lib.TableCopy(dst_idx, src_idx) => {
          optimization_note_used_table(
            used_tables, table_worklist, imported_table_count, defined_table_count,
            dst_idx,
          )
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, src_idx,
          )
        }
        @lib.TableSet(table_idx)
        | @lib.TableGrow(table_idx)
        | @lib.TableFill(table_idx)
        | @lib.TableInit(_, table_idx) => {
          optimization_mark_mutated_table(
            used_tables, mutated_tables, table_worklist, imported_table_count, defined_table_count,
            table_idx,
          )
          optimization_promote_mutated_indirect_table_signatures(
            indirect_call_types_by_table, table_idx, called_ref_types, subtypes,
            func_type_idxs, call_ref_candidate_funcs, used_funcs, func_worklist,
            imported_func_count, defined_func_count,
          )
        }
        @lib.TableSize(table_idx) =>
          optimization_note_used_table(
            used_tables, table_worklist, imported_table_count, defined_table_count,
            table_idx,
          )
        _ => ()
      }
      unchanged()
    })
  match func {
    @lib.Func(_, expr) => ignore(walker.walk_expr((), expr))
    @lib.TFunc(_, _, body) =>
      for instr in body.inner() {
        optimization_collect_module_element_uses_in_tinstr(
          instr, features, called_ref_types, indirect_call_types_by_table, subtypes,
          struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
          used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
          referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
          defined_global_count, used_tables, observable_tables, indirect_called_tables,
          mutated_tables, table_worklist, imported_table_count, defined_table_count,
          used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
          imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
          data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
          unread_struct_field_payloads, read_array_contents, unread_array_payloads,
          unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
        )
      }
  }
}

///|
fn optimization_seed_root_uses(
  mod : Module,
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
  used_globals : Array[Bool],
  global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  used_tables : Array[Bool],
  observable_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  used_mems : Array[Bool],
  imported_mem_count : Int,
  defined_mem_count : Int,
  used_tags : Array[Bool],
  tag_worklist : Array[Int],
  imported_tag_count : Int,
  defined_tag_count : Int,
) -> Unit {
  match mod.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          @lib.Export(_, FuncExternIdx(idx)) =>
            optimization_note_used_func(
              used_funcs, func_worklist, imported_func_count, defined_func_count,
              idx,
            )
          @lib.Export(_, GlobalExternIdx(idx)) =>
            optimization_note_used_global(
              used_globals, global_worklist, imported_global_count, defined_global_count,
              idx,
            )
          @lib.Export(_, TableExternIdx(idx)) =>
            optimization_note_observable_table(
              used_tables, observable_tables, table_worklist, imported_table_count,
              defined_table_count, idx,
            )
          @lib.Export(_, MemExternIdx(idx)) =>
            optimization_note_used_mem(
              used_mems, imported_mem_count, defined_mem_count, idx,
            )
          @lib.Export(_, TagExternIdx(idx)) =>
            optimization_note_used_tag(
              used_tags, tag_worklist, imported_tag_count, defined_tag_count, idx,
            )
        }
      }
    None => ()
  }
  match mod.start_sec {
    Some(@lib.StartSec(idx)) =>
      optimization_note_used_func(
        used_funcs, func_worklist, imported_func_count, defined_func_count, idx,
      )
    None => ()
  }
}

///|
priv enum OptimizationInitExprValueKind {
  Other
  MaybeNullRef
  NonNullRef
} derive(Eq)

///|
fn optimization_init_expr_struct_field_count(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> Int? {
  let idx = match type_idx {
    @lib.TypeIdx(idx) => idx.reinterpret_as_int()
    @lib.RecIdx(idx) => idx.reinterpret_as_int()
  }
  if idx < 0 || idx >= subtypes.length() {
    return None
  }
  match subtypes[idx].get_comptype() {
    @lib.StructCompType(fields) => Some(fields.length())
    _ => None
  }
}

///|
fn optimization_init_expr_push_global_get_kind(
  stack : Array[OptimizationInitExprValueKind],
  global_types : Array[@lib.GlobalType],
  idx : @lib.GlobalIdx,
) -> Bool {
  let @lib.GlobalIdx(idx) = idx
  let abs_idx = idx.reinterpret_as_int()
  if abs_idx < 0 || abs_idx >= global_types.length() {
    return false
  }
  let @lib.GlobalType(vt, _) = global_types[abs_idx]
  match vt {
    @lib.RefTypeValType(rt) =>
      if rt.is_nullable() {
        stack.push(MaybeNullRef)
      } else {
        stack.push(NonNullRef)
      }
    _ => stack.push(Other)
  }
  true
}

///|
fn optimization_init_expr_pop_fields(
  stack : Array[OptimizationInitExprValueKind],
  field_count : Int,
) -> Bool {
  let mut remaining = field_count
  while remaining > 0 {
    if stack.pop() is None {
      return false
    }
    remaining -= 1
  }
  true
}

///|
fn optimization_init_expr_maybe_traps(
  expr : @lib.Expr,
  global_types : Array[@lib.GlobalType],
  subtypes : Array[@lib.SubType],
) -> Bool {
  let @lib.Expr(instrs) = expr
  let stack : Array[OptimizationInitExprValueKind] = []
  for instr in instrs {
    match instr {
      @lib.I32Const(_)
      | @lib.I64Const(_)
      | @lib.F32Const(_)
      | @lib.F64Const(_)
      | @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
        stack.push(Other)
      @lib.RefNull(_) => stack.push(MaybeNullRef)
      @lib.RefFunc(_) => stack.push(NonNullRef)
      @lib.GlobalGet(idx) =>
        if !optimization_init_expr_push_global_get_kind(
            stack, global_types, idx,
          ) {
          return true
        }
      @lib.StructNew(type_idx) => {
        let field_count = match
          optimization_init_expr_struct_field_count(subtypes, type_idx) {
          Some(field_count) => field_count
          None => return true
        }
        if !optimization_init_expr_pop_fields(stack, field_count) {
          return true
        }
        stack.push(NonNullRef)
      }
      @lib.StructNewDefault(type_idx) =>
        match optimization_init_expr_struct_field_count(subtypes, type_idx) {
          Some(_) => stack.push(NonNullRef)
          None => return true
        }
      @lib.StructNewDesc(type_idx) => {
        let field_count = match
          optimization_init_expr_struct_field_count(subtypes, type_idx) {
          Some(field_count) => field_count
          None => return true
        }
        let descriptor = match stack.pop() {
          Some(descriptor) => descriptor
          None => return true
        }
        if !optimization_init_expr_pop_fields(stack, field_count) {
          return true
        }
        if descriptor != NonNullRef {
          return true
        }
        stack.push(NonNullRef)
      }
      @lib.StructNewDefaultDesc(type_idx) => {
        match optimization_init_expr_struct_field_count(subtypes, type_idx) {
          Some(_) => ()
          None => return true
        }
        let descriptor = match stack.pop() {
          Some(descriptor) => descriptor
          None => return true
        }
        if descriptor != NonNullRef {
          return true
        }
        stack.push(NonNullRef)
      }
      _ => stack.push(Other)
    }
  }
  false
}

///|
fn optimization_struct_subtype_children(
  subtypes : Array[SubType],
) -> Array[Array[Int]] {
  let children : Array[Array[Int]] = []
  for _ in 0..<subtypes.length() {
    children.push([])
  }
  let mut type_idx = 0
  while type_idx < subtypes.length() {
    for super_type_idx in subtypes[type_idx].super_types() {
      match optimization_type_idx_bucket(super_type_idx) {
        Some(super_idx) =>
          if super_idx >= 0 && super_idx < children.length() {
            children[super_idx].push(type_idx)
          }
        None => ()
      }
    }
    type_idx += 1
  }
  children
}

///|
fn optimization_init_read_struct_fields(
  subtypes : Array[SubType],
) -> Array[Array[Bool]] {
  let read_fields : Array[Array[Bool]] = []
  for subtype in subtypes {
    match subtype.get_comptype() {
      @lib.StructCompType(fields) => {
        let per_type : Array[Bool] = []
        for _ in fields {
          per_type.push(false)
        }
        read_fields.push(per_type)
      }
      _ => read_fields.push([])
    }
  }
  read_fields
}

///|
fn optimization_init_unread_struct_field_payloads(
  subtypes : Array[SubType],
) -> Array[Array[Array[@lib.TInstr]]] {
  let unread_payloads : Array[Array[Array[@lib.TInstr]]] = []
  for subtype in subtypes {
    match subtype.get_comptype() {
      @lib.StructCompType(fields) => {
        let per_type : Array[Array[@lib.TInstr]] = []
        for _ in fields {
          per_type.push([])
        }
        unread_payloads.push(per_type)
      }
      _ => unread_payloads.push([])
    }
  }
  unread_payloads
}

///|
fn optimization_array_ref_payload_type_idx(
  subtypes : Array[SubType],
  type_idx : TypeIdx,
) -> Int? {
  let abs_type_idx = match optimization_type_idx_bucket(type_idx) {
    Some(idx) => idx
    None => return None
  }
  if abs_type_idx < 0 || abs_type_idx >= subtypes.length() {
    return None
  }
  match subtypes[abs_type_idx].get_comptype() {
    @lib.ArrayCompType(field) =>
      if field.unpack().is_ref_type() {
        Some(abs_type_idx)
      } else {
        None
      }
    _ => None
  }
}

///|
fn optimization_init_read_array_contents(
  subtypes : Array[SubType],
) -> Array[Bool] {
  let read_contents : Array[Bool] = []
  for subtype in subtypes {
    match subtype.get_comptype() {
      @lib.ArrayCompType(field) =>
        read_contents.push(!field.unpack().is_ref_type())
      _ => read_contents.push(true)
    }
  }
  read_contents
}

///|
fn optimization_init_unread_array_payloads(
  subtypes : Array[SubType],
) -> Array[Array[@lib.TInstr]] {
  let unread_payloads : Array[Array[@lib.TInstr]] = []
  for subtype in subtypes {
    match subtype.get_comptype() {
      @lib.ArrayCompType(field) =>
        if field.unpack().is_ref_type() {
          unread_payloads.push([])
        } else {
          unread_payloads.push([])
        }
      _ => unread_payloads.push([])
    }
  }
  unread_payloads
}

///|
fn optimization_init_unread_array_elem_payloads(
  subtypes : Array[SubType],
) -> Array[Array[Int]] {
  let unread_payloads : Array[Array[Int]] = []
  for subtype in subtypes {
    match subtype.get_comptype() {
      @lib.ArrayCompType(field) =>
        if field.unpack().is_ref_type() {
          unread_payloads.push([])
        } else {
          unread_payloads.push([])
        }
      _ => unread_payloads.push([])
    }
  }
  unread_payloads
}

///|
fn optimization_tinstr_can_defer_struct_payload(instr : @lib.TInstr) -> Bool {
  match instr.kind {
    @lib.TNop
    | @lib.TLocalGet(_)
    | @lib.TGlobalGet(_)
    | @lib.TI32Const(_)
    | @lib.TI64Const(_)
    | @lib.TF32Const(_)
    | @lib.TF64Const(_)
    | @lib.TRefFunc(_)
    | @lib.TRefNull(_) => true
    @lib.TStructNew(_, fields) => {
      for field in fields {
        if !optimization_tinstr_can_defer_struct_payload(field) {
          return false
        }
      }
      true
    }
    @lib.TStructNewDefault(_) => true
    @lib.TStructNewDesc(_, operands) => {
      for operand in operands {
        if !optimization_tinstr_can_defer_struct_payload(operand) {
          return false
        }
      }
      true
    }
    @lib.TStructNewDefaultDesc(_, descriptor) =>
      optimization_tinstr_can_defer_struct_payload(descriptor)
    _ => false
  }
}

///|
fn optimization_const_expr_u64(expr : @lib.Expr) -> UInt64? {
  match expr {
    @lib.Expr([@lib.I32Const(@lib.I32(value))]) =>
      Some(value.reinterpret_as_uint().to_uint64())
    @lib.Expr([@lib.I64Const(@lib.I64(value))]) =>
      Some(value.reinterpret_as_uint64())
    _ => None
  }
}

///|
fn optimization_elem_item_count(elem : Elem) -> UInt64 {
  match elem {
    Elem(_, @lib.FuncsElemKind(funcs)) => funcs.length().to_uint64()
    Elem(_, @lib.FuncExprsElemKind(exprs)) => exprs.length().to_uint64()
    Elem(_, @lib.TypedExprsElemKind(_, exprs)) => exprs.length().to_uint64()
  }
}

///|
fn optimization_limits_initial_length(limits : @lib.Limits) -> UInt64 {
  match limits {
    @lib.I32Limits(min, _) => min.to_uint64()
    @lib.I64Limits(min, _) => min
  }
}

///|
fn optimization_maybe_trapping_active_write(
  offset : @lib.Expr,
  item_count : UInt64,
  initial_bound : UInt64,
) -> Bool {
  match optimization_const_expr_u64(offset) {
    Some(start) => {
      let end = start + item_count
      end < start || end > initial_bound
    }
    None => true
  }
}

///|
fn optimization_active_elem_maybe_traps(
  elem : Elem,
  tables : Array[Table],
  imported_table_count : Int,
) -> Bool {
  match elem {
    Elem(@lib.Active(@lib.TableIdx(table_idx), offset), _) => {
      let abs_table_idx = table_idx.reinterpret_as_int()
      if abs_table_idx < 0 || abs_table_idx < imported_table_count {
        return true
      }
      let local_idx = abs_table_idx - imported_table_count
      if local_idx < 0 || local_idx >= tables.length() {
        return true
      }
      let Table(@lib.TableType(_, limits), _) = tables[local_idx]
      optimization_maybe_trapping_active_write(
        offset,
        optimization_elem_item_count(elem),
        optimization_limits_initial_length(limits),
      )
    }
    _ => false
  }
}

///|
fn optimization_active_data_maybe_traps(
  data : Data,
  mems : Array[@lib.MemType],
  imported_mem_count : Int,
) -> Bool {
  match data {
    Data(@lib.Active(@lib.MemIdx(mem_idx), offset), bytes) => {
      let abs_mem_idx = mem_idx.reinterpret_as_int()
      if abs_mem_idx < 0 || abs_mem_idx < imported_mem_count {
        return true
      }
      let local_idx = abs_mem_idx - imported_mem_count
      if local_idx < 0 || local_idx >= mems.length() {
        return true
      }
      let @lib.MemType(limits) = mems[local_idx]
      optimization_maybe_trapping_active_write(
        offset,
        bytes.length().to_uint64(),
        optimization_limits_initial_length(limits) * 65536UL,
      )
    }
    _ => false
  }
}

///|
fn optimization_seed_trapping_active_segments(
  elems : Array[Elem],
  tables : Array[Table],
  imported_table_count : Int,
  used_elems : Array[Bool],
  elem_worklist : Array[Int],
  datas : Array[Data],
  mems : Array[@lib.MemType],
  imported_mem_count : Int,
  used_datas : Array[Bool],
  data_worklist : Array[Int],
) -> Unit {
  let mut i = 0
  while i < elems.length() {
    if optimization_active_elem_maybe_traps(
        elems[i],
        tables,
        imported_table_count,
      ) {
      optimization_note_used_elem(
        used_elems,
        elem_worklist,
        ElemIdx::new(i.reinterpret_as_uint()),
      )
    }
    i += 1
  }
  i = 0
  while i < datas.length() {
    if optimization_active_data_maybe_traps(datas[i], mems, imported_mem_count) {
      optimization_note_used_data(
        used_datas,
        data_worklist,
        DataIdx::new(i.reinterpret_as_uint()),
      )
    }
    i += 1
  }
}

///|
fn optimization_seed_trapping_constant_initializers(
  globals : Array[Global],
  global_types : Array[@lib.GlobalType],
  subtypes : Array[@lib.SubType],
  used_globals : Array[Bool],
  global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  elems : Array[Elem],
  used_elems : Array[Bool],
  elem_worklist : Array[Int],
) -> Unit {
  let mut global_idx = 0
  while global_idx < globals.length() {
    match globals[global_idx] {
      @lib.Global(_, init) =>
        if optimization_init_expr_maybe_traps(init, global_types, subtypes) {
          optimization_note_used_global(
            used_globals,
            global_worklist,
            imported_global_count,
            defined_global_count,
            GlobalIdx::new(
              (imported_global_count + global_idx).reinterpret_as_uint(),
            ),
          )
        }
    }
    global_idx += 1
  }
  let mut elem_idx = 0
  while elem_idx < elems.length() {
    let mut maybe_traps = false
    match elems[elem_idx] {
      Elem(_, @lib.FuncExprsElemKind(exprs))
      | Elem(_, @lib.TypedExprsElemKind(_, exprs)) =>
        for expr in exprs {
          if optimization_init_expr_maybe_traps(expr, global_types, subtypes) {
            maybe_traps = true
          }
        }
      _ => ()
    }
    if maybe_traps {
      optimization_note_used_elem(
        used_elems,
        elem_worklist,
        ElemIdx::new(elem_idx.reinterpret_as_uint()),
      )
    }
    elem_idx += 1
  }
}

///|
fn optimization_promote_live_active_segments(
  elems : Array[Elem],
  observable_tables : Array[Bool],
  imported_table_count : Int,
  used_elems : Array[Bool],
  elem_worklist : Array[Int],
  datas : Array[Data],
  used_mems : Array[Bool],
  imported_mem_count : Int,
  used_datas : Array[Bool],
  data_worklist : Array[Int],
) -> Unit {
  let mut i = 0
  while i < elems.length() {
    if !used_elems[i] {
      match elems[i] {
        Elem(@lib.Active(@lib.TableIdx(table_idx), _), _) => {
          let abs_table_idx = table_idx.reinterpret_as_int()
          if abs_table_idx < 0 ||
            abs_table_idx >= observable_tables.length() ||
            abs_table_idx < imported_table_count ||
            observable_tables[abs_table_idx] {
            optimization_note_used_elem(
              used_elems,
              elem_worklist,
              ElemIdx::new(i.reinterpret_as_uint()),
            )
          }
        }
        _ => ()
      }
    }
    i += 1
  }
  i = 0
  while i < datas.length() {
    if !used_datas[i] {
      match datas[i] {
        Data(@lib.Active(@lib.MemIdx(mem_idx), _), _) => {
          let abs_mem_idx = mem_idx.reinterpret_as_int()
          if abs_mem_idx < 0 ||
            abs_mem_idx >= used_mems.length() ||
            abs_mem_idx < imported_mem_count ||
            used_mems[abs_mem_idx] {
            optimization_note_used_data(
              used_datas,
              data_worklist,
              DataIdx::new(i.reinterpret_as_uint()),
            )
          }
        }
        _ => ()
      }
    }
    i += 1
  }
}

///|
fn optimization_collect_func_uses_in_elem(
  elem : Elem,
  features : PipelineFeatures,
  called_ref_types : Array[Bool],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  referenced_funcs : Array[Bool],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
  used_globals : Array[Bool],
  global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  used_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  used_mems : Array[Bool],
  imported_mem_count : Int,
  defined_mem_count : Int,
  used_tags : Array[Bool],
  tag_worklist : Array[Int],
  imported_tag_count : Int,
  defined_tag_count : Int,
) -> Unit {
  match elem {
    Elem(@lib.Active(table_idx, offset), kind) => {
      optimization_note_used_table(
        used_tables, table_worklist, imported_table_count, defined_table_count, table_idx,
      )
      optimization_collect_func_uses_in_expr(
        offset, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
        call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
        defined_func_count, used_globals, global_worklist, imported_global_count,
        defined_global_count, used_tables, table_worklist, imported_table_count,
        defined_table_count, used_mems, imported_mem_count, defined_mem_count, used_tags,
        tag_worklist, imported_tag_count, defined_tag_count,
      )
      match kind {
        @lib.FuncsElemKind(funcs) =>
          for idx in funcs {
            optimization_note_used_func(
              used_funcs, func_worklist, imported_func_count, defined_func_count,
              idx,
            )
          }
        @lib.FuncExprsElemKind(exprs) =>
          for expr in exprs {
            optimization_collect_func_uses_in_expr(
              expr, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
              call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
              defined_func_count, used_globals, global_worklist, imported_global_count,
              defined_global_count, used_tables, table_worklist, imported_table_count,
              defined_table_count, used_mems, imported_mem_count, defined_mem_count,
              used_tags, tag_worklist, imported_tag_count, defined_tag_count,
            )
          }
        @lib.TypedExprsElemKind(_, exprs) =>
          for expr in exprs {
            optimization_collect_func_uses_in_expr(
              expr, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
              call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
              defined_func_count, used_globals, global_worklist, imported_global_count,
              defined_global_count, used_tables, table_worklist, imported_table_count,
              defined_table_count, used_mems, imported_mem_count, defined_mem_count,
              used_tags, tag_worklist, imported_tag_count, defined_tag_count,
            )
          }
      }
    }
    Elem(_, kind) =>
      match kind {
        @lib.FuncsElemKind(funcs) =>
          for idx in funcs {
            optimization_note_used_func(
              used_funcs, func_worklist, imported_func_count, defined_func_count,
              idx,
            )
          }
        @lib.FuncExprsElemKind(exprs) =>
          for expr in exprs {
            optimization_collect_func_uses_in_expr(
              expr, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
              call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
              defined_func_count, used_globals, global_worklist, imported_global_count,
              defined_global_count, used_tables, table_worklist, imported_table_count,
              defined_table_count, used_mems, imported_mem_count, defined_mem_count,
              used_tags, tag_worklist, imported_tag_count, defined_tag_count,
            )
          }
        @lib.TypedExprsElemKind(_, exprs) =>
          for expr in exprs {
            optimization_collect_func_uses_in_expr(
              expr, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
              call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
              defined_func_count, used_globals, global_worklist, imported_global_count,
              defined_global_count, used_tables, table_worklist, imported_table_count,
              defined_table_count, used_mems, imported_mem_count, defined_mem_count,
              used_tags, tag_worklist, imported_tag_count, defined_tag_count,
            )
          }
      }
  }
}

///|
fn optimization_collect_func_uses_in_data(
  data : Data,
  features : PipelineFeatures,
  called_ref_types : Array[Bool],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  referenced_funcs : Array[Bool],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
  used_globals : Array[Bool],
  global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  used_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  used_mems : Array[Bool],
  imported_mem_count : Int,
  defined_mem_count : Int,
  used_tags : Array[Bool],
  tag_worklist : Array[Int],
  imported_tag_count : Int,
  defined_tag_count : Int,
) -> Unit {
  match data {
    Data(@lib.Active(mem_idx, offset), _) => {
      optimization_note_used_mem(
        used_mems, imported_mem_count, defined_mem_count, mem_idx,
      )
      optimization_collect_func_uses_in_expr(
        offset, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
        call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
        defined_func_count, used_globals, global_worklist, imported_global_count,
        defined_global_count, used_tables, table_worklist, imported_table_count,
        defined_table_count, used_mems, imported_mem_count, defined_mem_count, used_tags,
        tag_worklist, imported_tag_count, defined_tag_count,
      )
    }
    _ => ()
  }
}

///|
fn optimization_collect_uses_in_global(
  global_ : Global,
  features : PipelineFeatures,
  called_ref_types : Array[Bool],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  referenced_funcs : Array[Bool],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
  used_globals : Array[Bool],
  global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  used_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  used_mems : Array[Bool],
  imported_mem_count : Int,
  defined_mem_count : Int,
  used_tags : Array[Bool],
  tag_worklist : Array[Int],
  imported_tag_count : Int,
  defined_tag_count : Int,
) -> Unit {
  match global_ {
    @lib.Global(_, init) =>
      optimization_collect_func_uses_in_expr(
        init, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
        call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
        defined_func_count, used_globals, global_worklist, imported_global_count,
        defined_global_count, used_tables, table_worklist, imported_table_count,
        defined_table_count, used_mems, imported_mem_count, defined_mem_count, used_tags,
        tag_worklist, imported_tag_count, defined_tag_count,
      )
  }
}

///|
fn optimization_collect_module_element_uses_in_tinstr(
  instr : @lib.TInstr,
  features : PipelineFeatures,
  called_ref_types : Array[Bool],
  indirect_call_types_by_table : Array[Array[Bool]],
  subtypes : Array[SubType],
  struct_subtype_children : Array[Array[Int]],
  func_type_idxs : Array[TypeIdx],
  referenced_funcs : Array[Bool],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
  used_globals : Array[Bool],
  referenced_globals : Array[Bool],
  global_worklist : Array[Int],
  referenced_global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  used_tables : Array[Bool],
  observable_tables : Array[Bool],
  indirect_called_tables : Array[Bool],
  mutated_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  used_mems : Array[Bool],
  imported_mem_count : Int,
  defined_mem_count : Int,
  used_tags : Array[Bool],
  tag_worklist : Array[Int],
  imported_tag_count : Int,
  defined_tag_count : Int,
  used_elems : Array[Bool],
  elem_worklist : Array[Int],
  used_datas : Array[Bool],
  data_worklist : Array[Int],
  elems : Array[Elem],
  active_elem_indices_by_table : Array[Array[Int]],
  read_struct_fields : Array[Array[Bool]],
  unread_struct_field_payloads : Array[Array[Array[@lib.TInstr]]],
  read_array_contents : Array[Bool],
  unread_array_payloads : Array[Array[@lib.TInstr]],
  unread_array_elem_payloads : Array[Array[Int]],
  referenced_elems : Array[Bool],
  referenced_elem_worklist : Array[Int],
) -> Unit {
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_globalidx_evt(fn(_, _, idx) {
      optimization_note_used_global(
        used_globals, global_worklist, imported_global_count, defined_global_count,
        idx,
      )
      unchanged()
    })
    .on_memidx_evt(fn(_, _, idx) {
      optimization_note_used_mem(
        used_mems, imported_mem_count, defined_mem_count, idx,
      )
      unchanged()
    })
    .on_tagidx_evt(fn(_, _, idx) {
      optimization_note_used_tag(
        used_tags, tag_worklist, imported_tag_count, defined_tag_count, idx,
      )
      unchanged()
    })
    .on_elemidx_evt(fn(_, _, idx) {
      optimization_note_used_elem(used_elems, elem_worklist, idx)
      unchanged()
    })
    .on_dataidx_evt(fn(_, _, idx) {
      optimization_note_used_data(used_datas, data_worklist, idx)
      unchanged()
    })
    .on_tinstruction_evt(fn(_, _, curr) {
      match curr.kind {
        @lib.TDrop(child) => {
          if features.closed_world && features.has_gc {
            match child.kind {
              @lib.TGlobalGet(idx) => {
                optimization_note_referenced_global(
                  referenced_globals, referenced_global_worklist, imported_global_count,
                  defined_global_count, idx,
                )
                return skip()
              }
              _ => ()
            }
          }
          optimization_collect_module_element_uses_in_tinstr(
            child, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          skip()
        }
        @lib.TArrayLen(child) => {
          if features.closed_world && features.has_gc {
            match child.kind {
              @lib.TGlobalGet(idx) => {
                optimization_note_referenced_global(
                  referenced_globals, referenced_global_worklist, imported_global_count,
                  defined_global_count, idx,
                )
                return skip()
              }
              _ => ()
            }
          }
          optimization_collect_module_element_uses_in_tinstr(
            child, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          skip()
        }
        @lib.TStructGet(type_idx, field_idx, struct_ref)
        | @lib.TStructGetS(type_idx, field_idx, struct_ref)
        | @lib.TStructGetU(type_idx, field_idx, struct_ref) => {
          optimization_collect_module_element_uses_in_tinstr(
            struct_ref, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          optimization_mark_struct_field_read(
            type_idx, field_idx, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          skip()
        }
        @lib.TStructSet(type_idx, field_idx, struct_ref, value) => {
          optimization_collect_module_element_uses_in_tinstr(
            struct_ref, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          let abs_type_idx = optimization_type_idx_bucket(type_idx)
          let @lib.U32(raw_field_idx) = field_idx
          let field = raw_field_idx.reinterpret_as_int()
          match abs_type_idx {
            Some(abs_idx) =>
              if features.closed_world &&
                features.has_gc &&
                abs_idx >= 0 &&
                abs_idx < unread_struct_field_payloads.length() &&
                field >= 0 &&
                field < unread_struct_field_payloads[abs_idx].length() &&
                !read_struct_fields[abs_idx][field] &&
                optimization_tinstr_can_defer_struct_payload(value) {
                unread_struct_field_payloads[abs_idx][field].push(value)
                optimization_collect_references_in_tinstr(
                  value, referenced_funcs, referenced_globals, referenced_global_worklist,
                  imported_global_count, defined_global_count,
                )
                return skip()
              }
            None => ()
          }
          optimization_collect_module_element_uses_in_tinstr(
            value, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          skip()
        }
        @lib.TStructNew(type_idx, fields) => {
          let abs_type_idx = optimization_type_idx_bucket(type_idx)
          match abs_type_idx {
            Some(abs_idx) =>
              if features.closed_world &&
                features.has_gc &&
                abs_idx >= 0 &&
                abs_idx < unread_struct_field_payloads.length() &&
                unread_struct_field_payloads[abs_idx].length() ==
                fields.length() {
                let mut field_idx = 0
                while field_idx < fields.length() {
                  if read_struct_fields[abs_idx][field_idx] ||
                    !optimization_tinstr_can_defer_struct_payload(
                      fields[field_idx],
                    ) {
                    optimization_collect_module_element_uses_in_tinstr(
                      fields[field_idx],
                      features,
                      called_ref_types,
                      indirect_call_types_by_table,
                      subtypes,
                      struct_subtype_children,
                      func_type_idxs,
                      referenced_funcs,
                      call_ref_candidate_funcs,
                      used_funcs,
                      func_worklist,
                      imported_func_count,
                      defined_func_count,
                      used_globals,
                      referenced_globals,
                      global_worklist,
                      referenced_global_worklist,
                      imported_global_count,
                      defined_global_count,
                      used_tables,
                      observable_tables,
                      indirect_called_tables,
                      mutated_tables,
                      table_worklist,
                      imported_table_count,
                      defined_table_count,
                      used_mems,
                      imported_mem_count,
                      defined_mem_count,
                      used_tags,
                      tag_worklist,
                      imported_tag_count,
                      defined_tag_count,
                      used_elems,
                      elem_worklist,
                      used_datas,
                      data_worklist,
                      elems,
                      active_elem_indices_by_table,
                      read_struct_fields,
                      unread_struct_field_payloads,
                      read_array_contents,
                      unread_array_payloads,
                      unread_array_elem_payloads,
                      referenced_elems,
                      referenced_elem_worklist,
                    )
                  } else {
                    unread_struct_field_payloads[abs_idx][field_idx].push(
                      fields[field_idx],
                    )
                    optimization_collect_references_in_tinstr(
                      fields[field_idx],
                      referenced_funcs,
                      referenced_globals,
                      referenced_global_worklist,
                      imported_global_count,
                      defined_global_count,
                    )
                  }
                  field_idx += 1
                }
                return skip()
              }
            None => ()
          }
          unchanged()
        }
        @lib.TStructNewDesc(type_idx, operands) => {
          let abs_type_idx = optimization_type_idx_bucket(type_idx)
          match abs_type_idx {
            Some(abs_idx) =>
              if features.closed_world &&
                features.has_gc &&
                abs_idx >= 0 &&
                abs_idx < unread_struct_field_payloads.length() &&
                unread_struct_field_payloads[abs_idx].length() + 1 ==
                operands.length() {
                let field_count = unread_struct_field_payloads[abs_idx].length()
                let mut field_idx = 0
                while field_idx < field_count {
                  if read_struct_fields[abs_idx][field_idx] ||
                    !optimization_tinstr_can_defer_struct_payload(
                      operands[field_idx],
                    ) {
                    optimization_collect_module_element_uses_in_tinstr(
                      operands[field_idx],
                      features,
                      called_ref_types,
                      indirect_call_types_by_table,
                      subtypes,
                      struct_subtype_children,
                      func_type_idxs,
                      referenced_funcs,
                      call_ref_candidate_funcs,
                      used_funcs,
                      func_worklist,
                      imported_func_count,
                      defined_func_count,
                      used_globals,
                      referenced_globals,
                      global_worklist,
                      referenced_global_worklist,
                      imported_global_count,
                      defined_global_count,
                      used_tables,
                      observable_tables,
                      indirect_called_tables,
                      mutated_tables,
                      table_worklist,
                      imported_table_count,
                      defined_table_count,
                      used_mems,
                      imported_mem_count,
                      defined_mem_count,
                      used_tags,
                      tag_worklist,
                      imported_tag_count,
                      defined_tag_count,
                      used_elems,
                      elem_worklist,
                      used_datas,
                      data_worklist,
                      elems,
                      active_elem_indices_by_table,
                      read_struct_fields,
                      unread_struct_field_payloads,
                      read_array_contents,
                      unread_array_payloads,
                      unread_array_elem_payloads,
                      referenced_elems,
                      referenced_elem_worklist,
                    )
                  } else {
                    unread_struct_field_payloads[abs_idx][field_idx].push(
                      operands[field_idx],
                    )
                    optimization_collect_references_in_tinstr(
                      operands[field_idx],
                      referenced_funcs,
                      referenced_globals,
                      referenced_global_worklist,
                      imported_global_count,
                      defined_global_count,
                    )
                  }
                  field_idx += 1
                }
                if optimization_tinstr_can_defer_struct_payload(
                    operands[field_count],
                  ) {
                  optimization_collect_references_in_tinstr(
                    operands[field_count],
                    referenced_funcs,
                    referenced_globals,
                    referenced_global_worklist,
                    imported_global_count,
                    defined_global_count,
                  )
                } else {
                  optimization_collect_module_element_uses_in_tinstr(
                    operands[field_count],
                    features,
                    called_ref_types,
                    indirect_call_types_by_table,
                    subtypes,
                    struct_subtype_children,
                    func_type_idxs,
                    referenced_funcs,
                    call_ref_candidate_funcs,
                    used_funcs,
                    func_worklist,
                    imported_func_count,
                    defined_func_count,
                    used_globals,
                    referenced_globals,
                    global_worklist,
                    referenced_global_worklist,
                    imported_global_count,
                    defined_global_count,
                    used_tables,
                    observable_tables,
                    indirect_called_tables,
                    mutated_tables,
                    table_worklist,
                    imported_table_count,
                    defined_table_count,
                    used_mems,
                    imported_mem_count,
                    defined_mem_count,
                    used_tags,
                    tag_worklist,
                    imported_tag_count,
                    defined_tag_count,
                    used_elems,
                    elem_worklist,
                    used_datas,
                    data_worklist,
                    elems,
                    active_elem_indices_by_table,
                    read_struct_fields,
                    unread_struct_field_payloads,
                    read_array_contents,
                    unread_array_payloads,
                    unread_array_elem_payloads,
                    referenced_elems,
                    referenced_elem_worklist,
                  )
                }
                return skip()
              }
            None => ()
          }
          unchanged()
        }
        @lib.TStructNewDefaultDesc(_, descriptor) => {
          if features.closed_world &&
            features.has_gc &&
            optimization_tinstr_can_defer_struct_payload(descriptor) {
            optimization_collect_references_in_tinstr(
              descriptor, referenced_funcs, referenced_globals, referenced_global_worklist,
              imported_global_count, defined_global_count,
            )
            return skip()
          }
          optimization_collect_module_element_uses_in_tinstr(
            descriptor, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          skip()
        }
        @lib.TRefIsNull(child)
        | @lib.TRefAsNonNull(child)
        | @lib.TAnyConvertExtern(child)
        | @lib.TExternConvertAny(child)
        | @lib.TRefGetDesc(_, child)
        | @lib.TRefTest(_, _, child)
        | @lib.TRefCast(_, _, child)
        | @lib.TRefTestDesc(_, _, child) => {
          if features.closed_world && features.has_gc {
            optimization_collect_reference_identity_in_tinstr(
              child, referenced_funcs, referenced_globals, referenced_global_worklist,
              imported_global_count, defined_global_count,
            )
          } else {
            optimization_collect_module_element_uses_in_tinstr(
              child, features, called_ref_types, indirect_call_types_by_table, subtypes,
              struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
              used_funcs, func_worklist, imported_func_count, defined_func_count,
              used_globals, referenced_globals, global_worklist, referenced_global_worklist,
              imported_global_count, defined_global_count, used_tables, observable_tables,
              indirect_called_tables, mutated_tables, table_worklist, imported_table_count,
              defined_table_count, used_mems, imported_mem_count, defined_mem_count,
              used_tags, tag_worklist, imported_tag_count, defined_tag_count, used_elems,
              elem_worklist, used_datas, data_worklist, elems, active_elem_indices_by_table,
              read_struct_fields, unread_struct_field_payloads, read_array_contents,
              unread_array_payloads, unread_array_elem_payloads, referenced_elems,
              referenced_elem_worklist,
            )
          }
          skip()
        }
        @lib.TRefCastDescEq(_, _, child) => {
          if features.closed_world && features.has_gc {
            optimization_collect_reference_identity_in_tinstr(
              child, referenced_funcs, referenced_globals, referenced_global_worklist,
              imported_global_count, defined_global_count,
            )
          } else {
            optimization_collect_module_element_uses_in_tinstr(
              child, features, called_ref_types, indirect_call_types_by_table, subtypes,
              struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
              used_funcs, func_worklist, imported_func_count, defined_func_count,
              used_globals, referenced_globals, global_worklist, referenced_global_worklist,
              imported_global_count, defined_global_count, used_tables, observable_tables,
              indirect_called_tables, mutated_tables, table_worklist, imported_table_count,
              defined_table_count, used_mems, imported_mem_count, defined_mem_count,
              used_tags, tag_worklist, imported_tag_count, defined_tag_count, used_elems,
              elem_worklist, used_datas, data_worklist, elems, active_elem_indices_by_table,
              read_struct_fields, unread_struct_field_payloads, read_array_contents,
              unread_array_payloads, unread_array_elem_payloads, referenced_elems,
              referenced_elem_worklist,
            )
          }
          skip()
        }
        @lib.TRefEq(left, right) => {
          if features.closed_world && features.has_gc {
            optimization_collect_reference_identity_in_tinstr(
              left, referenced_funcs, referenced_globals, referenced_global_worklist,
              imported_global_count, defined_global_count,
            )
            optimization_collect_reference_identity_in_tinstr(
              right, referenced_funcs, referenced_globals, referenced_global_worklist,
              imported_global_count, defined_global_count,
            )
          } else {
            optimization_collect_module_element_uses_in_tinstr(
              left, features, called_ref_types, indirect_call_types_by_table, subtypes,
              struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
              used_funcs, func_worklist, imported_func_count, defined_func_count,
              used_globals, referenced_globals, global_worklist, referenced_global_worklist,
              imported_global_count, defined_global_count, used_tables, observable_tables,
              indirect_called_tables, mutated_tables, table_worklist, imported_table_count,
              defined_table_count, used_mems, imported_mem_count, defined_mem_count,
              used_tags, tag_worklist, imported_tag_count, defined_tag_count, used_elems,
              elem_worklist, used_datas, data_worklist, elems, active_elem_indices_by_table,
              read_struct_fields, unread_struct_field_payloads, read_array_contents,
              unread_array_payloads, unread_array_elem_payloads, referenced_elems,
              referenced_elem_worklist,
            )
            optimization_collect_module_element_uses_in_tinstr(
              right, features, called_ref_types, indirect_call_types_by_table, subtypes,
              struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
              used_funcs, func_worklist, imported_func_count, defined_func_count,
              used_globals, referenced_globals, global_worklist, referenced_global_worklist,
              imported_global_count, defined_global_count, used_tables, observable_tables,
              indirect_called_tables, mutated_tables, table_worklist, imported_table_count,
              defined_table_count, used_mems, imported_mem_count, defined_mem_count,
              used_tags, tag_worklist, imported_tag_count, defined_tag_count, used_elems,
              elem_worklist, used_datas, data_worklist, elems, active_elem_indices_by_table,
              read_struct_fields, unread_struct_field_payloads, read_array_contents,
              unread_array_payloads, unread_array_elem_payloads, referenced_elems,
              referenced_elem_worklist,
            )
          }
          skip()
        }
        @lib.TBrOnNull(_, child, values)
        | @lib.TBrOnNonNull(_, child, values)
        | @lib.TBrOnCast(_, _, _, _, child, values)
        | @lib.TBrOnCastFail(_, _, _, _, child, values) => {
          for value in values {
            optimization_collect_module_element_uses_in_tinstr(
              value, features, called_ref_types, indirect_call_types_by_table, subtypes,
              struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
              used_funcs, func_worklist, imported_func_count, defined_func_count,
              used_globals, referenced_globals, global_worklist, referenced_global_worklist,
              imported_global_count, defined_global_count, used_tables, observable_tables,
              indirect_called_tables, mutated_tables, table_worklist, imported_table_count,
              defined_table_count, used_mems, imported_mem_count, defined_mem_count,
              used_tags, tag_worklist, imported_tag_count, defined_tag_count, used_elems,
              elem_worklist, used_datas, data_worklist, elems, active_elem_indices_by_table,
              read_struct_fields, unread_struct_field_payloads, read_array_contents,
              unread_array_payloads, unread_array_elem_payloads, referenced_elems,
              referenced_elem_worklist,
            )
          }
          if features.closed_world && features.has_gc {
            optimization_collect_reference_identity_in_tinstr(
              child, referenced_funcs, referenced_globals, referenced_global_worklist,
              imported_global_count, defined_global_count,
            )
          } else {
            optimization_collect_module_element_uses_in_tinstr(
              child, features, called_ref_types, indirect_call_types_by_table, subtypes,
              struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
              used_funcs, func_worklist, imported_func_count, defined_func_count,
              used_globals, referenced_globals, global_worklist, referenced_global_worklist,
              imported_global_count, defined_global_count, used_tables, observable_tables,
              indirect_called_tables, mutated_tables, table_worklist, imported_table_count,
              defined_table_count, used_mems, imported_mem_count, defined_mem_count,
              used_tags, tag_worklist, imported_tag_count, defined_tag_count, used_elems,
              elem_worklist, used_datas, data_worklist, elems, active_elem_indices_by_table,
              read_struct_fields, unread_struct_field_payloads, read_array_contents,
              unread_array_payloads, unread_array_elem_payloads, referenced_elems,
              referenced_elem_worklist,
            )
          }
          skip()
        }
        @lib.TArrayGet(type_idx, array_ref, index)
        | @lib.TArrayGetS(type_idx, array_ref, index)
        | @lib.TArrayGetU(type_idx, array_ref, index) => {
          optimization_collect_module_element_uses_in_tinstr(
            array_ref, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            index, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          optimization_mark_array_content_read(
            type_idx, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          skip()
        }
        @lib.TArrayNew(type_idx, init, len) => {
          optimization_collect_module_element_uses_in_tinstr(
            len, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          match optimization_array_ref_payload_type_idx(subtypes, type_idx) {
            Some(abs_type_idx) =>
              if features.closed_world &&
                features.has_gc &&
                abs_type_idx >= 0 &&
                abs_type_idx < read_array_contents.length() &&
                !read_array_contents[abs_type_idx] &&
                optimization_tinstr_can_defer_struct_payload(init) {
                unread_array_payloads[abs_type_idx].push(init)
                optimization_collect_references_in_tinstr(
                  init, referenced_funcs, referenced_globals, referenced_global_worklist,
                  imported_global_count, defined_global_count,
                )
                return skip()
              }
            None => ()
          }
          optimization_collect_module_element_uses_in_tinstr(
            init, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          skip()
        }
        @lib.TArrayNewFixed(type_idx, payloads) => {
          match optimization_array_ref_payload_type_idx(subtypes, type_idx) {
            Some(abs_type_idx) =>
              if features.closed_world &&
                features.has_gc &&
                abs_type_idx >= 0 &&
                abs_type_idx < read_array_contents.length() &&
                !read_array_contents[abs_type_idx] {
                for payload in payloads {
                  if optimization_tinstr_can_defer_struct_payload(payload) {
                    unread_array_payloads[abs_type_idx].push(payload)
                    optimization_collect_references_in_tinstr(
                      payload, referenced_funcs, referenced_globals, referenced_global_worklist,
                      imported_global_count, defined_global_count,
                    )
                  } else {
                    optimization_collect_module_element_uses_in_tinstr(
                      payload, features, called_ref_types, indirect_call_types_by_table,
                      subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
                      call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
                      defined_func_count, used_globals, referenced_globals, global_worklist,
                      referenced_global_worklist, imported_global_count, defined_global_count,
                      used_tables, observable_tables, indirect_called_tables, mutated_tables,
                      table_worklist, imported_table_count, defined_table_count,
                      used_mems, imported_mem_count, defined_mem_count, used_tags,
                      tag_worklist, imported_tag_count, defined_tag_count, used_elems,
                      elem_worklist, used_datas, data_worklist, elems, active_elem_indices_by_table,
                      read_struct_fields, unread_struct_field_payloads, read_array_contents,
                      unread_array_payloads, unread_array_elem_payloads, referenced_elems,
                      referenced_elem_worklist,
                    )
                  }
                }
                return skip()
              }
            None => ()
          }
          unchanged()
        }
        @lib.TArrayNewElem(type_idx, elem_idx, offset, len) => {
          optimization_collect_module_element_uses_in_tinstr(
            offset, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            len, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          match optimization_array_ref_payload_type_idx(subtypes, type_idx) {
            Some(abs_type_idx) =>
              if features.closed_world &&
                features.has_gc &&
                abs_type_idx >= 0 &&
                abs_type_idx < read_array_contents.length() &&
                !read_array_contents[abs_type_idx] {
                optimization_note_referenced_elem(
                  referenced_elems, referenced_elem_worklist, elem_idx,
                )
                unread_array_elem_payloads[abs_type_idx].push(
                  match elem_idx {
                    @lib.ElemIdx(raw_idx) => raw_idx.reinterpret_as_int()
                  },
                )
                return skip()
              }
            None => ()
          }
          optimization_note_used_elem(used_elems, elem_worklist, elem_idx)
          skip()
        }
        @lib.TArraySet(type_idx, array_ref, index, value) => {
          optimization_collect_module_element_uses_in_tinstr(
            array_ref, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            index, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          match optimization_array_ref_payload_type_idx(subtypes, type_idx) {
            Some(abs_type_idx) =>
              if features.closed_world &&
                features.has_gc &&
                abs_type_idx >= 0 &&
                abs_type_idx < read_array_contents.length() &&
                !read_array_contents[abs_type_idx] &&
                optimization_tinstr_can_defer_struct_payload(value) {
                unread_array_payloads[abs_type_idx].push(value)
                optimization_collect_references_in_tinstr(
                  value, referenced_funcs, referenced_globals, referenced_global_worklist,
                  imported_global_count, defined_global_count,
                )
                return skip()
              }
            None => ()
          }
          optimization_collect_module_element_uses_in_tinstr(
            value, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          skip()
        }
        @lib.TArrayFill(type_idx, array_ref, offset, value, len) => {
          optimization_collect_module_element_uses_in_tinstr(
            array_ref, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            offset, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            len, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          match optimization_array_ref_payload_type_idx(subtypes, type_idx) {
            Some(abs_type_idx) =>
              if features.closed_world &&
                features.has_gc &&
                abs_type_idx >= 0 &&
                abs_type_idx < read_array_contents.length() &&
                !read_array_contents[abs_type_idx] &&
                optimization_tinstr_can_defer_struct_payload(value) {
                unread_array_payloads[abs_type_idx].push(value)
                optimization_collect_references_in_tinstr(
                  value, referenced_funcs, referenced_globals, referenced_global_worklist,
                  imported_global_count, defined_global_count,
                )
                return skip()
              }
            None => ()
          }
          optimization_collect_module_element_uses_in_tinstr(
            value, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          skip()
        }
        @lib.TArrayCopy(
          dst_type_idx,
          src_type_idx,
          dst_array,
          dst_index,
          src_array,
          src_index,
          len
        ) => {
          optimization_collect_module_element_uses_in_tinstr(
            dst_array, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            dst_index, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            src_array, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            src_index, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            len, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          match
            (
              optimization_array_ref_payload_type_idx(subtypes, src_type_idx),
              optimization_array_ref_payload_type_idx(subtypes, dst_type_idx),
            ) {
            (Some(src_abs_type_idx), Some(dst_abs_type_idx)) =>
              if read_array_contents[dst_abs_type_idx] {
                optimization_mark_array_content_read(
                  src_type_idx, features, called_ref_types, indirect_call_types_by_table,
                  subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
                  call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
                  defined_func_count, used_globals, referenced_globals, global_worklist,
                  referenced_global_worklist, imported_global_count, defined_global_count,
                  used_tables, observable_tables, indirect_called_tables, mutated_tables,
                  table_worklist, imported_table_count, defined_table_count, used_mems,
                  imported_mem_count, defined_mem_count, used_tags, tag_worklist,
                  imported_tag_count, defined_tag_count, used_elems, elem_worklist,
                  used_datas, data_worklist, elems, active_elem_indices_by_table,
                  read_struct_fields, unread_struct_field_payloads, read_array_contents,
                  unread_array_payloads, unread_array_elem_payloads, referenced_elems,
                  referenced_elem_worklist,
                )
              } else if src_abs_type_idx != dst_abs_type_idx {
                for payload in unread_array_payloads[src_abs_type_idx] {
                  unread_array_payloads[dst_abs_type_idx].push(payload)
                }
                for elem_idx in unread_array_elem_payloads[src_abs_type_idx] {
                  unread_array_elem_payloads[dst_abs_type_idx].push(elem_idx)
                }
              }
            _ => ()
          }
          skip()
        }
        @lib.TArrayInitElem(type_idx, elem_idx, array_ref, dst, src, len) => {
          optimization_collect_module_element_uses_in_tinstr(
            array_ref, features, called_ref_types, indirect_call_types_by_table,
            subtypes, struct_subtype_children, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count, used_globals, referenced_globals, global_worklist,
            referenced_global_worklist, imported_global_count, defined_global_count,
            used_tables, observable_tables, indirect_called_tables, mutated_tables,
            table_worklist, imported_table_count, defined_table_count, used_mems,
            imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
            defined_tag_count, used_elems, elem_worklist, used_datas, data_worklist,
            elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
            read_array_contents, unread_array_payloads, unread_array_elem_payloads,
            referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            dst, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            src, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          optimization_collect_module_element_uses_in_tinstr(
            len, features, called_ref_types, indirect_call_types_by_table, subtypes,
            struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
            referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
            defined_global_count, used_tables, observable_tables, indirect_called_tables,
            mutated_tables, table_worklist, imported_table_count, defined_table_count,
            used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
            imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
            data_worklist, elems, active_elem_indices_by_table, read_struct_fields,
            unread_struct_field_payloads, read_array_contents, unread_array_payloads,
            unread_array_elem_payloads, referenced_elems, referenced_elem_worklist,
          )
          match optimization_array_ref_payload_type_idx(subtypes, type_idx) {
            Some(abs_type_idx) =>
              if features.closed_world &&
                features.has_gc &&
                abs_type_idx >= 0 &&
                abs_type_idx < read_array_contents.length() &&
                !read_array_contents[abs_type_idx] {
                optimization_note_referenced_elem(
                  referenced_elems, referenced_elem_worklist, elem_idx,
                )
                unread_array_elem_payloads[abs_type_idx].push(
                  match elem_idx {
                    @lib.ElemIdx(raw_idx) => raw_idx.reinterpret_as_int()
                  },
                )
                return skip()
              }
            None => ()
          }
          optimization_note_used_elem(used_elems, elem_worklist, elem_idx)
          skip()
        }
        @lib.TCall(func_idx, _) | @lib.TReturnCall(func_idx, _) => {
          optimization_note_used_func(
            used_funcs, func_worklist, imported_func_count, defined_func_count, func_idx,
          )
          unchanged()
        }
        @lib.TCallIndirect(type_idx, table_idx, _, _)
        | @lib.TReturnCallIndirect(type_idx, table_idx, _, _) => {
          optimization_mark_indirect_called_table(
            used_tables, indirect_called_tables, table_worklist, imported_table_count,
            defined_table_count, table_idx,
          )
          optimization_note_indirect_call_type_for_table(
            indirect_call_types_by_table, table_idx, type_idx,
          )
          optimization_collect_indirect_call_elem_uses(
            table_idx, type_idx, active_elem_indices_by_table, elems, subtypes, func_type_idxs,
            used_elems, elem_worklist,
          )
          let @lib.TableIdx(raw_table_idx) = table_idx
          let abs_table_idx = raw_table_idx.reinterpret_as_int()
          if abs_table_idx >= 0 &&
            abs_table_idx < mutated_tables.length() &&
            mutated_tables[abs_table_idx] {
            optimization_promote_mutated_indirect_table_signatures(
              indirect_call_types_by_table, table_idx, called_ref_types, subtypes,
              func_type_idxs, call_ref_candidate_funcs, used_funcs, func_worklist,
              imported_func_count, defined_func_count,
            )
          }
          unchanged()
        }
        @lib.TCallRef(type_idx, _, _) | @lib.TReturnCallRef(type_idx, _, _) => {
          optimization_note_called_ref_type(
            type_idx, called_ref_types, subtypes, func_type_idxs, call_ref_candidate_funcs,
            used_funcs, func_worklist, imported_func_count, defined_func_count,
          )
          unchanged()
        }
        @lib.TRefFunc(func_idx) => {
          optimization_note_ref_func(
            func_idx, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
            call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
            defined_func_count,
          )
          unchanged()
        }
        @lib.TTableGet(table_idx, _) => {
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, table_idx,
          )
          unchanged()
        }
        @lib.TTableCopy(dst_idx, src_idx, _, _, _) => {
          optimization_note_used_table(
            used_tables, table_worklist, imported_table_count, defined_table_count,
            dst_idx,
          )
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, src_idx,
          )
          unchanged()
        }
        @lib.TTableSet(table_idx, _, _)
        | @lib.TTableGrow(table_idx, _, _)
        | @lib.TTableFill(table_idx, _, _, _)
        | @lib.TTableInit(_, table_idx, _, _, _) => {
          optimization_mark_mutated_table(
            used_tables, mutated_tables, table_worklist, imported_table_count, defined_table_count,
            table_idx,
          )
          optimization_promote_mutated_indirect_table_signatures(
            indirect_call_types_by_table, table_idx, called_ref_types, subtypes,
            func_type_idxs, call_ref_candidate_funcs, used_funcs, func_worklist,
            imported_func_count, defined_func_count,
          )
          unchanged()
        }
        @lib.TTableSize(table_idx) => {
          optimization_note_used_table(
            used_tables, table_worklist, imported_table_count, defined_table_count,
            table_idx,
          )
          unchanged()
        }
        _ => unchanged()
      }
    })
  ignore(walker.walk_tinstruction((), instr))
}

///|
fn optimization_mark_struct_field_read(
  type_idx : TypeIdx,
  field_idx : U32,
  features : PipelineFeatures,
  called_ref_types : Array[Bool],
  indirect_call_types_by_table : Array[Array[Bool]],
  subtypes : Array[SubType],
  struct_subtype_children : Array[Array[Int]],
  func_type_idxs : Array[TypeIdx],
  referenced_funcs : Array[Bool],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
  used_globals : Array[Bool],
  referenced_globals : Array[Bool],
  global_worklist : Array[Int],
  referenced_global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  used_tables : Array[Bool],
  observable_tables : Array[Bool],
  indirect_called_tables : Array[Bool],
  mutated_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  used_mems : Array[Bool],
  imported_mem_count : Int,
  defined_mem_count : Int,
  used_tags : Array[Bool],
  tag_worklist : Array[Int],
  imported_tag_count : Int,
  defined_tag_count : Int,
  used_elems : Array[Bool],
  elem_worklist : Array[Int],
  used_datas : Array[Bool],
  data_worklist : Array[Int],
  elems : Array[Elem],
  active_elem_indices_by_table : Array[Array[Int]],
  read_struct_fields : Array[Array[Bool]],
  unread_struct_field_payloads : Array[Array[Array[@lib.TInstr]]],
  read_array_contents : Array[Bool],
  unread_array_payloads : Array[Array[@lib.TInstr]],
  unread_array_elem_payloads : Array[Array[Int]],
  referenced_elems : Array[Bool],
  referenced_elem_worklist : Array[Int],
) -> Unit {
  let abs_type_idx = match optimization_type_idx_bucket(type_idx) {
    Some(idx) => idx
    None => return
  }
  let @lib.U32(raw_field_idx) = field_idx
  let field = raw_field_idx.reinterpret_as_int()
  if abs_type_idx < 0 || abs_type_idx >= read_struct_fields.length() {
    return
  }
  if field < 0 || field >= read_struct_fields[abs_type_idx].length() {
    return
  }
  if read_struct_fields[abs_type_idx][field] {
    return
  }
  read_struct_fields[abs_type_idx][field] = true
  let deferred = unread_struct_field_payloads[abs_type_idx][field]
  unread_struct_field_payloads[abs_type_idx][field] = []
  for payload in deferred {
    optimization_collect_module_element_uses_in_tinstr(
      payload, features, called_ref_types, indirect_call_types_by_table, subtypes,
      struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
      used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
      referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
      defined_global_count, used_tables, observable_tables, indirect_called_tables,
      mutated_tables, table_worklist, imported_table_count, defined_table_count,
      used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
      imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
      data_worklist, elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
      read_array_contents, unread_array_payloads, unread_array_elem_payloads, referenced_elems,
      referenced_elem_worklist,
    )
  }
  for child_type_idx in struct_subtype_children[abs_type_idx] {
    optimization_mark_struct_field_read(
      @lib.TypeIdx::new(child_type_idx.reinterpret_as_uint()),
      field_idx,
      features,
      called_ref_types,
      indirect_call_types_by_table,
      subtypes,
      struct_subtype_children,
      func_type_idxs,
      referenced_funcs,
      call_ref_candidate_funcs,
      used_funcs,
      func_worklist,
      imported_func_count,
      defined_func_count,
      used_globals,
      referenced_globals,
      global_worklist,
      referenced_global_worklist,
      imported_global_count,
      defined_global_count,
      used_tables,
      observable_tables,
      indirect_called_tables,
      mutated_tables,
      table_worklist,
      imported_table_count,
      defined_table_count,
      used_mems,
      imported_mem_count,
      defined_mem_count,
      used_tags,
      tag_worklist,
      imported_tag_count,
      defined_tag_count,
      used_elems,
      elem_worklist,
      used_datas,
      data_worklist,
      elems,
      active_elem_indices_by_table,
      read_struct_fields,
      unread_struct_field_payloads,
      read_array_contents,
      unread_array_payloads,
      unread_array_elem_payloads,
      referenced_elems,
      referenced_elem_worklist,
    )
  }
}

///|
fn optimization_mark_array_content_read(
  type_idx : TypeIdx,
  features : PipelineFeatures,
  called_ref_types : Array[Bool],
  indirect_call_types_by_table : Array[Array[Bool]],
  subtypes : Array[SubType],
  struct_subtype_children : Array[Array[Int]],
  func_type_idxs : Array[TypeIdx],
  referenced_funcs : Array[Bool],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
  used_globals : Array[Bool],
  referenced_globals : Array[Bool],
  global_worklist : Array[Int],
  referenced_global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  used_tables : Array[Bool],
  observable_tables : Array[Bool],
  indirect_called_tables : Array[Bool],
  mutated_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  used_mems : Array[Bool],
  imported_mem_count : Int,
  defined_mem_count : Int,
  used_tags : Array[Bool],
  tag_worklist : Array[Int],
  imported_tag_count : Int,
  defined_tag_count : Int,
  used_elems : Array[Bool],
  elem_worklist : Array[Int],
  used_datas : Array[Bool],
  data_worklist : Array[Int],
  elems : Array[Elem],
  active_elem_indices_by_table : Array[Array[Int]],
  read_struct_fields : Array[Array[Bool]],
  unread_struct_field_payloads : Array[Array[Array[@lib.TInstr]]],
  read_array_contents : Array[Bool],
  unread_array_payloads : Array[Array[@lib.TInstr]],
  unread_array_elem_payloads : Array[Array[Int]],
  referenced_elems : Array[Bool],
  referenced_elem_worklist : Array[Int],
) -> Unit {
  let abs_type_idx = match
    optimization_array_ref_payload_type_idx(subtypes, type_idx) {
    Some(idx) => idx
    None => return
  }
  if abs_type_idx < 0 || abs_type_idx >= read_array_contents.length() {
    return
  }
  if read_array_contents[abs_type_idx] {
    return
  }
  read_array_contents[abs_type_idx] = true
  let deferred_payloads = unread_array_payloads[abs_type_idx]
  unread_array_payloads[abs_type_idx] = []
  for payload in deferred_payloads {
    optimization_collect_module_element_uses_in_tinstr(
      payload, features, called_ref_types, indirect_call_types_by_table, subtypes,
      struct_subtype_children, func_type_idxs, referenced_funcs, call_ref_candidate_funcs,
      used_funcs, func_worklist, imported_func_count, defined_func_count, used_globals,
      referenced_globals, global_worklist, referenced_global_worklist, imported_global_count,
      defined_global_count, used_tables, observable_tables, indirect_called_tables,
      mutated_tables, table_worklist, imported_table_count, defined_table_count,
      used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
      imported_tag_count, defined_tag_count, used_elems, elem_worklist, used_datas,
      data_worklist, elems, active_elem_indices_by_table, read_struct_fields, unread_struct_field_payloads,
      read_array_contents, unread_array_payloads, unread_array_elem_payloads, referenced_elems,
      referenced_elem_worklist,
    )
  }
  let deferred_elem_idxs = unread_array_elem_payloads[abs_type_idx]
  unread_array_elem_payloads[abs_type_idx] = []
  for elem_idx in deferred_elem_idxs {
    optimization_note_used_elem(
      used_elems,
      elem_worklist,
      ElemIdx::new(elem_idx.reinterpret_as_uint()),
    )
  }
  for child_type_idx in struct_subtype_children[abs_type_idx] {
    optimization_mark_array_content_read(
      @lib.TypeIdx::new(child_type_idx.reinterpret_as_uint()),
      features,
      called_ref_types,
      indirect_call_types_by_table,
      subtypes,
      struct_subtype_children,
      func_type_idxs,
      referenced_funcs,
      call_ref_candidate_funcs,
      used_funcs,
      func_worklist,
      imported_func_count,
      defined_func_count,
      used_globals,
      referenced_globals,
      global_worklist,
      referenced_global_worklist,
      imported_global_count,
      defined_global_count,
      used_tables,
      observable_tables,
      indirect_called_tables,
      mutated_tables,
      table_worklist,
      imported_table_count,
      defined_table_count,
      used_mems,
      imported_mem_count,
      defined_mem_count,
      used_tags,
      tag_worklist,
      imported_tag_count,
      defined_tag_count,
      used_elems,
      elem_worklist,
      used_datas,
      data_worklist,
      elems,
      active_elem_indices_by_table,
      read_struct_fields,
      unread_struct_field_payloads,
      read_array_contents,
      unread_array_payloads,
      unread_array_elem_payloads,
      referenced_elems,
      referenced_elem_worklist,
    )
  }
}

///|
fn optimization_collect_uses_in_table(
  table : Table,
  table_local_idx : Int,
  features : PipelineFeatures,
  called_ref_types : Array[Bool],
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
  referenced_funcs : Array[Bool],
  call_ref_candidate_funcs : Array[Bool],
  used_funcs : Array[Bool],
  func_worklist : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
  used_globals : Array[Bool],
  global_worklist : Array[Int],
  imported_global_count : Int,
  defined_global_count : Int,
  used_tables : Array[Bool],
  observable_tables : Array[Bool],
  indirect_called_tables : Array[Bool],
  table_worklist : Array[Int],
  imported_table_count : Int,
  defined_table_count : Int,
  used_mems : Array[Bool],
  imported_mem_count : Int,
  defined_mem_count : Int,
  used_tags : Array[Bool],
  tag_worklist : Array[Int],
  imported_tag_count : Int,
  defined_tag_count : Int,
) -> Unit {
  let abs_table_idx = imported_table_count + table_local_idx
  if abs_table_idx < 0 || abs_table_idx >= used_tables.length() {
    return
  }
  if !observable_tables[abs_table_idx] && !indirect_called_tables[abs_table_idx] {
    return
  }
  match table {
    Table(_, Some(init)) =>
      optimization_collect_func_uses_in_expr(
        init, features, called_ref_types, subtypes, func_type_idxs, referenced_funcs,
        call_ref_candidate_funcs, used_funcs, func_worklist, imported_func_count,
        defined_func_count, used_globals, global_worklist, imported_global_count,
        defined_global_count, used_tables, table_worklist, imported_table_count,
        defined_table_count, used_mems, imported_mem_count, defined_mem_count, used_tags,
        tag_worklist, imported_tag_count, defined_tag_count,
      )
    _ => ()
  }
}

///|
fn optimization_compact_defined_functions(
  mod : Module,
  type_idxs : Array[TypeIdx],
  funcs : Array[Func],
  keep_defined : Array[Bool],
  shell_defined : Array[Bool],
) -> (Module, Map[UInt, UInt]) {
  let imported_count = optimization_imported_func_count(mod)
  let kept_types : Array[TypeIdx] = []
  let kept_funcs : Array[Func] = []
  let abs_remap : Map[UInt, UInt] = {}
  let mut import_idx = 0
  while import_idx < imported_count {
    let raw = import_idx.reinterpret_as_uint()
    abs_remap[raw] = raw
    import_idx += 1
  }
  let mut next_abs = imported_count.reinterpret_as_uint()
  let mut i = 0
  while i < funcs.length() {
    if keep_defined[i] {
      abs_remap[(imported_count + i).reinterpret_as_uint()] = next_abs
      kept_types.push(type_idxs[i])
      if shell_defined[i] {
        match funcs[i] {
          Func(locals, _) =>
            kept_funcs.push(
              Func::new(
                locals,
                @lib.Expr::new([@lib.Instruction::unreachable_()]),
              ),
            )
          TFunc(params, locals, _) =>
            kept_funcs.push(
              Func::t_func(
                params,
                locals,
                @lib.TExpr::new([@lib.TInstr::unreachable_()]),
              ),
            )
        }
      } else {
        kept_funcs.push(funcs[i])
      }
      next_abs += 1U
    }
    i += 1
  }
  let compacted = mod
    .with_func_sec(FuncSec::new(kept_types))
    .with_code_sec(CodeSec::new(kept_funcs))
  (compacted, abs_remap)
}

///|
fn optimization_rewrite_module_element_indices(
  mod : Module,
  func_remap : Map[UInt, UInt],
  table_remap : Map[UInt, UInt]?,
  memory_remap : Map[UInt, UInt]?,
  global_remap : Map[UInt, UInt]?,
  tag_remap : Map[UInt, UInt]?,
  elem_remap : Map[UInt, UInt]?,
  data_remap : Map[UInt, UInt]?,
) -> Module {
  let mut transformer : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_funcidx_evt(fn(
      _,
      _,
      idx : FuncIdx,
    ) {
      let FuncIdx(raw) = idx
      let next = func_remap.get(raw).unwrap_or(raw)
      change((), FuncIdx::new(next))
    },
  )
  match table_remap {
    Some(remap) =>
      transformer = transformer.on_tableidx_evt(fn(_, _, idx : TableIdx) {
        let TableIdx(raw) = idx
        let next = remap.get(raw).unwrap_or(raw)
        change((), TableIdx::new(next))
      })
    None => ()
  }
  match memory_remap {
    Some(remap) =>
      transformer = transformer.on_memidx_evt(fn(_, _, idx : MemIdx) {
        let MemIdx(raw) = idx
        let next = remap.get(raw).unwrap_or(raw)
        change((), MemIdx::new(next))
      })
    None => ()
  }
  match global_remap {
    Some(remap) =>
      transformer = transformer.on_globalidx_evt(fn(_, _, idx : GlobalIdx) {
        let GlobalIdx(raw) = idx
        let next = remap.get(raw).unwrap_or(raw)
        change((), GlobalIdx::new(next))
      })
    None => ()
  }
  match tag_remap {
    Some(remap) =>
      transformer = transformer.on_tagidx_evt(fn(_, _, idx : TagIdx) {
        let TagIdx(raw) = idx
        let next = remap.get(raw).unwrap_or(raw)
        change((), TagIdx::new(next))
      })
    None => ()
  }
  match elem_remap {
    Some(remap) =>
      transformer = transformer.on_elemidx_evt(fn(_, _, idx : ElemIdx) {
        let ElemIdx(raw) = idx
        let next = remap.get(raw).unwrap_or(raw)
        change((), ElemIdx::new(next))
      })
    None => ()
  }
  match data_remap {
    Some(remap) =>
      transformer = transformer.on_dataidx_evt(fn(_, _, idx : DataIdx) {
        let DataIdx(raw) = idx
        let next = remap.get(raw).unwrap_or(raw)
        change((), DataIdx::new(next))
      })
    None => ()
  }
  match transformer.walk_module((), mod) {
    Ok((rewritten, _)) => rewritten
    Err(_) => mod
  }
}

///|
fn optimization_compact_defined_tags(
  mod : Module,
  tags : Array[TagType],
  keep_defined : Array[Bool],
) -> (Module, Map[UInt, UInt]) {
  let imported_count = optimization_imported_tag_count(mod)
  let kept_tags : Array[TagType] = []
  let abs_remap : Map[UInt, UInt] = {}
  let mut import_idx = 0
  while import_idx < imported_count {
    let raw = import_idx.reinterpret_as_uint()
    abs_remap[raw] = raw
    import_idx += 1
  }
  let mut next_abs = imported_count.reinterpret_as_uint()
  let mut i = 0
  while i < tags.length() {
    if keep_defined[i] {
      abs_remap[(imported_count + i).reinterpret_as_uint()] = next_abs
      kept_tags.push(tags[i])
      next_abs += 1U
    }
    i += 1
  }
  (mod.with_tag_sec(TagSec::new(kept_tags)), abs_remap)
}

///|
fn optimization_compact_defined_tables(
  mod : Module,
  tables : Array[Table],
  keep_defined : Array[Bool],
) -> (Module, Map[UInt, UInt]) {
  let imported_count = optimization_imported_table_count(mod)
  let kept_tables : Array[Table] = []
  let abs_remap : Map[UInt, UInt] = {}
  let mut import_idx = 0
  while import_idx < imported_count {
    let raw = import_idx.reinterpret_as_uint()
    abs_remap[raw] = raw
    import_idx += 1
  }
  let mut next_abs = imported_count.reinterpret_as_uint()
  let mut i = 0
  while i < tables.length() {
    if keep_defined[i] {
      abs_remap[(imported_count + i).reinterpret_as_uint()] = next_abs
      kept_tables.push(tables[i])
      next_abs += 1U
    }
    i += 1
  }
  (mod.with_table_sec(TableSec::new(kept_tables)), abs_remap)
}

///|
fn optimization_compact_defined_mems(
  mod : Module,
  mems : Array[MemType],
  keep_defined : Array[Bool],
) -> (Module, Map[UInt, UInt]) {
  let imported_count = optimization_imported_mem_count(mod)
  let kept_mems : Array[MemType] = []
  let abs_remap : Map[UInt, UInt] = {}
  let mut import_idx = 0
  while import_idx < imported_count {
    let raw = import_idx.reinterpret_as_uint()
    abs_remap[raw] = raw
    import_idx += 1
  }
  let mut next_abs = imported_count.reinterpret_as_uint()
  let mut i = 0
  while i < mems.length() {
    if keep_defined[i] {
      abs_remap[(imported_count + i).reinterpret_as_uint()] = next_abs
      kept_mems.push(mems[i])
      next_abs += 1U
    }
    i += 1
  }
  (mod.with_mem_sec(MemSec::new(kept_mems)), abs_remap)
}

///|
fn optimization_compact_defined_globals(
  mod : Module,
  globals : Array[Global],
  keep_defined : Array[Bool],
) -> (Module, Map[UInt, UInt]) {
  let imported_count = optimization_imported_global_count(mod)
  let kept_globals : Array[Global] = []
  let abs_remap : Map[UInt, UInt] = {}
  let mut import_idx = 0
  while import_idx < imported_count {
    let raw = import_idx.reinterpret_as_uint()
    abs_remap[raw] = raw
    import_idx += 1
  }
  let mut next_abs = imported_count.reinterpret_as_uint()
  let mut i = 0
  while i < globals.length() {
    if keep_defined[i] {
      abs_remap[(imported_count + i).reinterpret_as_uint()] = next_abs
      kept_globals.push(globals[i])
      next_abs += 1U
    }
    i += 1
  }
  (mod.with_global_sec(GlobalSec::new(kept_globals)), abs_remap)
}

///|
fn optimization_compact_elem_sec(
  mod : Module,
  elems : Array[Elem],
  keep_elems : Array[Bool],
) -> (Module, Map[UInt, UInt]) {
  let kept_elems : Array[Elem] = []
  let elem_remap : Map[UInt, UInt] = {}
  let mut next_idx = 0U
  let mut i = 0
  while i < elems.length() {
    if keep_elems[i] {
      elem_remap[i.reinterpret_as_uint()] = next_idx
      kept_elems.push(elems[i])
      next_idx += 1U
    }
    i += 1
  }
  (mod.with_elem_sec(ElemSec::new(kept_elems)), elem_remap)
}

///|
fn optimization_compact_data_sec(
  mod : Module,
  datas : Array[Data],
  keep_datas : Array[Bool],
) -> (Module, Map[UInt, UInt]) {
  let kept_datas : Array[Data] = []
  let data_remap : Map[UInt, UInt] = {}
  let mut next_idx = 0U
  let mut i = 0
  while i < datas.length() {
    if keep_datas[i] {
      data_remap[i.reinterpret_as_uint()] = next_idx
      kept_datas.push(datas[i])
      next_idx += 1U
    }
    i += 1
  }
  let mut compacted = mod.with_data_sec(DataSec::new(kept_datas))
  match mod.data_cnt_sec {
    Some(_) =>
      compacted = compacted.with_data_cnt_sec(
        DataCntSec::new(U32::new(next_idx)),
      )
    None => ()
  }
  (compacted, data_remap)
}

///|
fn optimization_remove_unused_module_elements_iteration(
  mod : Module,
  features : PipelineFeatures,
) -> Module? {
  let subtypes = optimization_flatten_subtypes(mod)
  let (type_idxs, funcs) = match (mod.func_sec, mod.code_sec) {
    (Some(FuncSec(type_idxs)), Some(CodeSec(funcs))) => {
      if type_idxs.length() != funcs.length() {
        return None
      }
      (type_idxs, funcs)
    }
    _ => ([], [])
  }
  let elems = match mod.elem_sec {
    Some(ElemSec(elems)) => elems
    None => []
  }
  let tables = match mod.table_sec {
    Some(TableSec(tables)) => tables
    None => []
  }
  let mems = match mod.mem_sec {
    Some(MemSec(mems)) => mems
    None => []
  }
  let tags = match mod.tag_sec {
    Some(TagSec(tags)) => tags
    None => []
  }
  let globals = match mod.global_sec {
    Some(GlobalSec(globals)) => globals
    None => []
  }
  let datas = match mod.data_sec {
    Some(DataSec(datas)) => datas
    None => []
  }
  let global_types = optimization_all_global_types(mod, globals)

  let imported_func_count = optimization_imported_func_count(mod)
  let total_func_count = imported_func_count + funcs.length()
  let used_funcs : Array[Bool] = []
  let referenced_funcs : Array[Bool] = []
  let call_ref_candidate_funcs : Array[Bool] = []
  for _ in 0..<total_func_count {
    used_funcs.push(false)
    referenced_funcs.push(false)
    call_ref_candidate_funcs.push(false)
  }
  let imported_global_count = optimization_imported_global_count(mod)
  let total_global_count = imported_global_count + globals.length()
  let used_globals : Array[Bool] = []
  let referenced_globals : Array[Bool] = []
  for _ in 0..<total_global_count {
    used_globals.push(false)
    referenced_globals.push(false)
  }
  let imported_table_count = optimization_imported_table_count(mod)
  let total_table_count = imported_table_count + tables.length()
  let used_tables : Array[Bool] = []
  let observable_tables : Array[Bool] = []
  let indirect_called_tables : Array[Bool] = []
  let mutated_tables : Array[Bool] = []
  for _ in 0..<total_table_count {
    used_tables.push(false)
    observable_tables.push(false)
    indirect_called_tables.push(false)
    mutated_tables.push(false)
  }
  let imported_mem_count = optimization_imported_mem_count(mod)
  let total_mem_count = imported_mem_count + mems.length()
  let used_mems : Array[Bool] = []
  for _ in 0..<total_mem_count {
    used_mems.push(false)
  }
  let imported_tag_count = optimization_imported_tag_count(mod)
  let total_tag_count = imported_tag_count + tags.length()
  let used_tags : Array[Bool] = []
  for _ in 0..<total_tag_count {
    used_tags.push(false)
  }
  let used_elems : Array[Bool] = []
  let referenced_elems : Array[Bool] = []
  for _ in 0..<elems.length() {
    used_elems.push(false)
    referenced_elems.push(false)
  }
  let used_datas : Array[Bool] = []
  for _ in 0..<datas.length() {
    used_datas.push(false)
  }
  let func_worklist : Array[Int] = []
  let global_worklist : Array[Int] = []
  let referenced_global_worklist : Array[Int] = []
  let table_worklist : Array[Int] = []
  let tag_worklist : Array[Int] = []
  let elem_worklist : Array[Int] = []
  let referenced_elem_worklist : Array[Int] = []
  let data_worklist : Array[Int] = []
  let func_type_idxs = optimization_all_func_type_idxs(mod, type_idxs)
  let called_ref_types : Array[Bool] = []
  for _ in 0..<subtypes.length() {
    called_ref_types.push(false)
  }
  let indirect_call_types_by_table : Array[Array[Bool]] = []
  for _ in 0..<total_table_count {
    let row : Array[Bool] = []
    for _ in 0..<subtypes.length() {
      row.push(false)
    }
    indirect_call_types_by_table.push(row)
  }
  let active_elem_indices_by_table = optimization_active_elem_indices_by_table(
    elems, total_table_count,
  )
  let struct_subtype_children = optimization_struct_subtype_children(subtypes)
  let read_struct_fields = optimization_init_read_struct_fields(subtypes)
  let unread_struct_field_payloads = optimization_init_unread_struct_field_payloads(
    subtypes,
  )
  let read_array_contents = optimization_init_read_array_contents(subtypes)
  let unread_array_payloads = optimization_init_unread_array_payloads(subtypes)
  let unread_array_elem_payloads = optimization_init_unread_array_elem_payloads(
    subtypes,
  )
  optimization_seed_root_uses(
    mod,
    used_funcs,
    func_worklist,
    imported_func_count,
    funcs.length(),
    used_globals,
    global_worklist,
    imported_global_count,
    globals.length(),
    used_tables,
    observable_tables,
    table_worklist,
    imported_table_count,
    tables.length(),
    used_mems,
    imported_mem_count,
    mems.length(),
    used_tags,
    tag_worklist,
    imported_tag_count,
    tags.length(),
  )
  optimization_promote_live_active_segments(
    elems, observable_tables, imported_table_count, used_elems, elem_worklist, datas,
    used_mems, imported_mem_count, used_datas, data_worklist,
  )
  if !features.traps_never_happen {
    optimization_seed_trapping_active_segments(
      elems, tables, imported_table_count, used_elems, elem_worklist, datas, mems,
      imported_mem_count, used_datas, data_worklist,
    )
    optimization_seed_trapping_constant_initializers(
      globals,
      global_types,
      subtypes,
      used_globals,
      global_worklist,
      imported_global_count,
      globals.length(),
      elems,
      used_elems,
      elem_worklist,
    )
  }
  while func_worklist.length() > 0 ||
        global_worklist.length() > 0 ||
        table_worklist.length() > 0 ||
        tag_worklist.length() > 0 ||
        elem_worklist.length() > 0 ||
        data_worklist.length() > 0 {
    while func_worklist.length() > 0 {
      let local_idx = func_worklist.pop().unwrap()
      optimization_collect_module_element_uses_in_func(
        funcs[local_idx],
        features,
        called_ref_types,
        indirect_call_types_by_table,
        subtypes,
        func_type_idxs,
        referenced_funcs,
        call_ref_candidate_funcs,
        used_funcs,
        func_worklist,
        imported_func_count,
        funcs.length(),
        used_globals,
        global_worklist,
        imported_global_count,
        globals.length(),
        used_tables,
        observable_tables,
        indirect_called_tables,
        mutated_tables,
        table_worklist,
        imported_table_count,
        tables.length(),
        used_mems,
        imported_mem_count,
        mems.length(),
        used_tags,
        tag_worklist,
        imported_tag_count,
        tags.length(),
        used_elems,
        elem_worklist,
        used_datas,
        data_worklist,
        elems,
        active_elem_indices_by_table,
        struct_subtype_children,
        read_struct_fields,
        unread_struct_field_payloads,
        read_array_contents,
        unread_array_payloads,
        unread_array_elem_payloads,
        referenced_globals,
        referenced_global_worklist,
        referenced_elems,
        referenced_elem_worklist,
      )
    }
    while referenced_global_worklist.length() > 0 {
      let local_idx = referenced_global_worklist.pop().unwrap()
      if local_idx >= 0 &&
        local_idx < globals.length() &&
        !used_globals[imported_global_count + local_idx] {
        optimization_collect_references_in_global(
          globals[local_idx],
          referenced_funcs,
          referenced_globals,
          referenced_global_worklist,
          imported_global_count,
          globals.length(),
        )
      }
    }
    while global_worklist.length() > 0 {
      let local_idx = global_worklist.pop().unwrap()
      optimization_collect_uses_in_global(
        globals[local_idx],
        features,
        called_ref_types,
        subtypes,
        func_type_idxs,
        referenced_funcs,
        call_ref_candidate_funcs,
        used_funcs,
        func_worklist,
        imported_func_count,
        funcs.length(),
        used_globals,
        global_worklist,
        imported_global_count,
        globals.length(),
        used_tables,
        table_worklist,
        imported_table_count,
        tables.length(),
        used_mems,
        imported_mem_count,
        mems.length(),
        used_tags,
        tag_worklist,
        imported_tag_count,
        tags.length(),
      )
    }
    while referenced_elem_worklist.length() > 0 {
      let elem_idx = referenced_elem_worklist.pop().unwrap()
      if elem_idx >= 0 && elem_idx < elems.length() && !used_elems[elem_idx] {
        optimization_collect_references_in_elem(
          elems[elem_idx],
          referenced_funcs,
          referenced_globals,
          referenced_global_worklist,
          imported_global_count,
          globals.length(),
        )
      }
    }
    while table_worklist.length() > 0 {
      let local_idx = table_worklist.pop().unwrap()
      optimization_collect_uses_in_table(
        tables[local_idx],
        local_idx,
        features,
        called_ref_types,
        subtypes,
        func_type_idxs,
        referenced_funcs,
        call_ref_candidate_funcs,
        used_funcs,
        func_worklist,
        imported_func_count,
        funcs.length(),
        used_globals,
        global_worklist,
        imported_global_count,
        globals.length(),
        used_tables,
        observable_tables,
        indirect_called_tables,
        table_worklist,
        imported_table_count,
        tables.length(),
        used_mems,
        imported_mem_count,
        mems.length(),
        used_tags,
        tag_worklist,
        imported_tag_count,
        tags.length(),
      )
    }
    while tag_worklist.length() > 0 {
      ignore(tag_worklist.pop())
    }
    while elem_worklist.length() > 0 {
      let elem_idx = elem_worklist.pop().unwrap()
      optimization_collect_func_uses_in_elem(
        elems[elem_idx],
        features,
        called_ref_types,
        subtypes,
        func_type_idxs,
        referenced_funcs,
        call_ref_candidate_funcs,
        used_funcs,
        func_worklist,
        imported_func_count,
        funcs.length(),
        used_globals,
        global_worklist,
        imported_global_count,
        globals.length(),
        used_tables,
        table_worklist,
        imported_table_count,
        tables.length(),
        used_mems,
        imported_mem_count,
        mems.length(),
        used_tags,
        tag_worklist,
        imported_tag_count,
        tags.length(),
      )
    }
    while data_worklist.length() > 0 {
      let data_idx = data_worklist.pop().unwrap()
      optimization_collect_func_uses_in_data(
        datas[data_idx],
        features,
        called_ref_types,
        subtypes,
        func_type_idxs,
        referenced_funcs,
        call_ref_candidate_funcs,
        used_funcs,
        func_worklist,
        imported_func_count,
        funcs.length(),
        used_globals,
        global_worklist,
        imported_global_count,
        globals.length(),
        used_tables,
        table_worklist,
        imported_table_count,
        tables.length(),
        used_mems,
        imported_mem_count,
        mems.length(),
        used_tags,
        tag_worklist,
        imported_tag_count,
        tags.length(),
      )
    }
    optimization_promote_live_active_segments(
      elems, observable_tables, imported_table_count, used_elems, elem_worklist,
      datas, used_mems, imported_mem_count, used_datas, data_worklist,
    )
  }

  let keep_defined : Array[Bool] = []
  let shell_defined : Array[Bool] = []
  let mut changed = false
  let mut i = 0
  while i < funcs.length() {
    let abs_idx = imported_func_count + i
    let keep = used_funcs[abs_idx] || referenced_funcs[abs_idx]
    let shell = !used_funcs[abs_idx] && referenced_funcs[abs_idx]
    keep_defined.push(keep)
    shell_defined.push(shell)
    if !keep {
      changed = true
    } else if shell {
      changed = true
    }
    i += 1
  }
  let keep_defined_globals : Array[Bool] = []
  i = 0
  while i < globals.length() {
    let abs_idx = imported_global_count + i
    let keep = used_globals[abs_idx] || referenced_globals[abs_idx]
    keep_defined_globals.push(keep)
    if !keep {
      changed = true
    }
    i += 1
  }
  let keep_defined_tables : Array[Bool] = []
  i = 0
  while i < tables.length() {
    let keep = used_tables[imported_table_count + i]
    keep_defined_tables.push(keep)
    if !keep {
      changed = true
    }
    i += 1
  }
  let keep_defined_mems : Array[Bool] = []
  i = 0
  while i < mems.length() {
    let keep = used_mems[imported_mem_count + i]
    keep_defined_mems.push(keep)
    if !keep {
      changed = true
    }
    i += 1
  }
  let keep_defined_tags : Array[Bool] = []
  i = 0
  while i < tags.length() {
    let keep = used_tags[imported_tag_count + i]
    keep_defined_tags.push(keep)
    if !keep {
      changed = true
    }
    i += 1
  }
  let keep_elems : Array[Bool] = []
  i = 0
  while i < elems.length() {
    let keep = used_elems[i] || referenced_elems[i]
    keep_elems.push(keep)
    if !keep {
      changed = true
    }
    i += 1
  }
  let keep_datas : Array[Bool] = []
  i = 0
  while i < datas.length() {
    let keep = used_datas[i]
    keep_datas.push(keep)
    if !keep {
      changed = true
    }
    i += 1
  }
  if !changed {
    return None
  }

  let (initial_compacted, func_remap) = optimization_compact_defined_functions(
    mod, type_idxs, funcs, keep_defined, shell_defined,
  )
  let mut compacted = initial_compacted
  let mut table_remap : Map[UInt, UInt]? = None
  if mod.table_sec is Some(_) {
    let (next, remap) = optimization_compact_defined_tables(
      compacted, tables, keep_defined_tables,
    )
    compacted = next
    table_remap = Some(remap)
  }
  let mut memory_remap : Map[UInt, UInt]? = None
  if mod.mem_sec is Some(_) {
    let (next, remap) = optimization_compact_defined_mems(
      compacted, mems, keep_defined_mems,
    )
    compacted = next
    memory_remap = Some(remap)
  }
  let mut tag_remap : Map[UInt, UInt]? = None
  if mod.tag_sec is Some(_) {
    let (next, remap) = optimization_compact_defined_tags(
      compacted, tags, keep_defined_tags,
    )
    compacted = next
    tag_remap = Some(remap)
  }
  let mut global_remap : Map[UInt, UInt]? = None
  if mod.global_sec is Some(_) {
    let (next, remap) = optimization_compact_defined_globals(
      compacted, globals, keep_defined_globals,
    )
    compacted = next
    global_remap = Some(remap)
  }
  let mut elem_remap : Map[UInt, UInt]? = None
  if mod.elem_sec is Some(_) {
    let (next, remap) = optimization_compact_elem_sec(
      compacted, elems, keep_elems,
    )
    compacted = next
    elem_remap = Some(remap)
  }
  let mut data_remap : Map[UInt, UInt]? = None
  if mod.data_sec is Some(_) {
    let (next, remap) = optimization_compact_data_sec(
      compacted, datas, keep_datas,
    )
    compacted = next
    data_remap = Some(remap)
  }
  match mod.name_sec {
    Some(name_sec) =>
      compacted = compacted.with_name_sec(
        optimization_rewrite_name_sec_filtered(
          name_sec, func_remap, true, table_remap, memory_remap, global_remap, tag_remap,
          elem_remap, data_remap,
        ),
      )
    None => ()
  }
  Some(
    optimization_rewrite_module_element_indices(
      compacted, func_remap, table_remap, memory_remap, global_remap, tag_remap,
      elem_remap, data_remap,
    ),
  )
}

///|
pub fn run_remove_unused_module_elements(
  mod : Module,
  global : PipelineGlobal,
  features : PipelineFeatures,
) -> (Module, PipelineGlobal) {
  match optimization_remove_unused_module_elements_iteration(mod, features) {
    Some(next) => (next, global)
    None => (mod, global)
  }
}

///|
fn optimization_duplicate_function_iteration(mod : Module) -> Module? {
  match (mod.func_sec, mod.code_sec) {
    (Some(FuncSec(type_idxs)), Some(CodeSec(funcs))) => {
      if type_idxs.length() != funcs.length() {
        return None
      }

      let subtypes = optimization_flatten_subtypes(mod)
      let hash_groups : Map[Int, Array[Int]] = {}
      let mut local_idx = 0
      while local_idx < funcs.length() {
        let key = optimization_function_hash_key(
          subtypes,
          type_idxs[local_idx],
          funcs[local_idx],
        )
        hash_groups.get_or_init(key, fn() { [] }).push(local_idx)
        local_idx += 1
      }

      let replacements : Map[Int, Int] = {}
      let mut changed = false
      for group in hash_groups.values() {
        if group.length() <= 1 {
          continue
        }
        let mut i = 0
        while i < group.length() - 1 {
          let first = group[i]
          if replacements.get(first) is Some(_) {
            i += 1
            continue
          }
          let mut j = i + 1
          while j < group.length() {
            let second = group[j]
            if replacements.get(second) is Some(_) {
              j += 1
              continue
            }
            if optimization_functions_equivalent(
                subtypes,
                type_idxs[first],
                funcs[first],
                type_idxs[second],
                funcs[second],
              ) {
              replacements[second] = first
              changed = true
            }
            j += 1
          }
          i += 1
        }
      }

      if !changed {
        return None
      }

      let kept_types : Array[TypeIdx] = []
      let kept_funcs : Array[Func] = []
      let kept_abs : Map[Int, UInt] = {}
      let imported_count = optimization_imported_func_count(mod)
      let mut next_abs = imported_count.reinterpret_as_uint()
      let mut i = 0
      while i < funcs.length() {
        if replacements.get(i) is None {
          kept_abs[i] = next_abs
          kept_types.push(type_idxs[i])
          kept_funcs.push(funcs[i])
          next_abs += 1U
        }
        i += 1
      }

      let abs_remap : Map[UInt, UInt] = {}
      let mut import_idx = 0
      while import_idx < imported_count {
        let raw = import_idx.reinterpret_as_uint()
        abs_remap[raw] = raw
        import_idx += 1
      }

      i = 0
      while i < funcs.length() {
        let canonical = optimization_canonical_local_idx(replacements, i)
        match kept_abs.get(canonical) {
          Some(next) =>
            abs_remap[(imported_count + i).reinterpret_as_uint()] = next
          None => return None
        }
        i += 1
      }

      let mut compacted = mod
        .with_func_sec(FuncSec::new(kept_types))
        .with_code_sec(CodeSec::new(kept_funcs))
      match mod.name_sec {
        Some(name_sec) =>
          compacted = compacted.with_name_sec(
            optimization_rewrite_name_sec(name_sec, abs_remap),
          )
        None => ()
      }
      Some(optimization_rewrite_func_indices(compacted, abs_remap))
    }
    _ => None
  }
}

///|
pub fn run_duplicate_function_elimination(
  mod : Module,
  global : PipelineGlobal,
  features : PipelineFeatures,
) -> (Module, PipelineGlobal) {
  let _ = features
  let initial_count = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
  let mut remaining = if global.opt_level >= 3 || global.shrink_level >= 1 {
    initial_count
  } else if global.opt_level >= 2 {
    10
  } else {
    1
  }
  let mut current = mod
  while remaining > 0 {
    remaining -= 1
    match optimization_duplicate_function_iteration(current) {
      Some(next) => current = next
      None => break
    }
  }
  (current, global)
}

///|
fn optimize_pass_class(pass : OptimizePass) -> OptimizePassClass {
  match pass {
    SSANoMerge
    | Flatten
    | SimplifyLocalsNoTeeNoStructure
    | LocalCSE
    | DeadCodeElimination
    | RemoveUnusedNames
    | RemoveUnusedBrs
    | OptimizeInstructions
    | HeapStoreOptimization
    | PickLoadSigns
    | Precompute
    | PrecomputePropagate
    | OptimizeAddedConstants
    | OptimizeAddedConstantsPropagate
    | CodePushing
    | TupleOptimization
    | SimplifyLocalsNoStructure
    | Vacuum
    | ReorderLocals
    | Heap2Local
    | MergeLocals
    | OptimizeCasts
    | LocalSubtyping
    | CoalesceLocals
    | SimplifyLocals
    | CodeFolding
    | MergeBlocks
    | RedundantSetElimination => FuncLocal
    _ => ModuleWide
  }
}

///|
fn validation_rank(kind : ValidationKind) -> Int {
  match kind {
    Unchecked => 0
    Shape => 1
    Full => 2
  }
}

///|
fn merge_validation_kind(
  lhs : ValidationKind,
  rhs : ValidationKind,
) -> ValidationKind {
  if validation_rank(lhs) >= validation_rank(rhs) {
    lhs
  } else {
    rhs
  }
}

///|
fn make_entry_kind(pass : OptimizePass) -> PassKind {
  match pass {
    DuplicateFunctionElimination =>
      PassKind::module_wide(run_duplicate_function_elimination)
    RemoveUnusedModuleElements =>
      PassKind::module_wide(run_remove_unused_module_elements)
    MemoryPacking => PassKind::module_wide(run_memory_packing)
    DeadCodeElimination =>
      PassKind::func_local_group([run_dead_code_elimination])
    _ =>
      match optimize_pass_class(pass) {
        FuncLocal => PassKind::func_local_group([noop_func_local_pass])
        ModuleWide => PassKind::module_wide(noop_module_wide_pass)
      }
  }
}

///|
fn make_pipeline_entry(
  pass : OptimizePass,
  validation_kind : ValidationKind,
) -> PipelineEntry {
  PipelineEntry::new(
    [pass],
    PassGroup::new(make_entry_kind(pass), validation_kind),
  )
}

///|
pub fn add_pass_to_pipeline(
  pipeline : Array[PipelineEntry],
  pass : OptimizePass,
  validation_kind? : ValidationKind = ValidationKind::unchecked(),
) -> Unit {
  if optimize_pass_class(pass) is FuncLocal && pipeline.length() > 0 {
    let idx = pipeline.length() - 1
    let last = pipeline[idx]
    match last.group.kind() {
      FuncLocalGroup(funcs) => {
        let passes = last.passes
        passes.push(pass)
        funcs.push(noop_func_local_pass)
        let merged_validation = merge_validation_kind(
          last.group.validation_kind(),
          validation_kind,
        )
        pipeline[idx] = PipelineEntry::new(
          passes,
          PassGroup::new(PassKind::func_local_group(funcs), merged_validation),
        )
        return
      }
      _ => ()
    }
  }
  pipeline.push(make_pipeline_entry(pass, validation_kind))
}

///|
fn add_pipeline_pass(
  pipeline : Array[PipelineEntry],
  pass : OptimizePass,
  validation : ValidationKind,
) -> Unit {
  add_pass_to_pipeline(pipeline, pass, validation_kind=validation)
}

///|
fn default_pipeline_validation(global : PipelineGlobal) -> ValidationKind {
  if global.validate {
    ValidationKind::full()
  } else {
    ValidationKind::unchecked()
  }
}

///|
fn add_default_global_optimization_pre_passes(
  pipeline : Array[PipelineEntry],
  global : PipelineGlobal,
  features : PipelineFeatures,
) -> Unit {
  let validation = default_pipeline_validation(global)
  add_pipeline_pass(
    pipeline,
    OptimizePass::DuplicateFunctionElimination,
    validation,
  )
  if global.opt_level >= 2 {
    add_pipeline_pass(
      pipeline,
      OptimizePass::RemoveUnusedModuleElements,
      validation,
    )
  }
  add_pipeline_pass(pipeline, OptimizePass::MemoryPacking, validation)
  if global.opt_level >= 2 {
    add_pipeline_pass(pipeline, OptimizePass::OnceReduction, validation)
  }
  if features.has_gc && global.opt_level >= 2 {
    if features.closed_world {
      add_pipeline_pass(pipeline, OptimizePass::TypeRefining, validation)
      add_pipeline_pass(pipeline, OptimizePass::SignaturePruning, validation)
      add_pipeline_pass(pipeline, OptimizePass::SignatureRefining, validation)
    }
    add_pipeline_pass(pipeline, OptimizePass::GlobalRefining, validation)
    if features.closed_world {
      add_pipeline_pass(
        pipeline,
        OptimizePass::GlobalTypeOptimization,
        validation,
      )
    }
    add_pipeline_pass(
      pipeline,
      OptimizePass::RemoveUnusedModuleElements,
      validation,
    )
    if features.closed_world {
      add_pipeline_pass(pipeline, OptimizePass::RemoveUnusedTypes, validation)
      if global.opt_level >= 3 {
        add_pipeline_pass(
          pipeline,
          OptimizePass::ConstantFieldPropagationRefTest,
          validation,
        )
      } else {
        add_pipeline_pass(
          pipeline,
          OptimizePass::ConstantFieldPropagation,
          validation,
        )
      }
    }
    add_pipeline_pass(pipeline, OptimizePass::GlobalStructInference, validation)
    if features.closed_world {
      add_pipeline_pass(
        pipeline,
        OptimizePass::AbstractTypeRefining,
        validation,
      )
      add_pipeline_pass(pipeline, OptimizePass::Unsubtyping, validation)
    }
  }
}

///|
fn add_default_function_optimization_passes(
  pipeline : Array[PipelineEntry],
  global : PipelineGlobal,
  features : PipelineFeatures,
) -> Unit {
  let validation = default_pipeline_validation(global)
  if global.opt_level >= 3 || global.shrink_level >= 1 {
    add_pipeline_pass(pipeline, OptimizePass::SSANoMerge, validation)
  }
  if global.opt_level >= 4 {
    add_pipeline_pass(pipeline, OptimizePass::Flatten, validation)
    add_pipeline_pass(
      pipeline,
      OptimizePass::SimplifyLocalsNoTeeNoStructure,
      validation,
    )
    add_pipeline_pass(pipeline, OptimizePass::LocalCSE, validation)
  }
  add_pipeline_pass(pipeline, OptimizePass::DeadCodeElimination, validation)
  add_pipeline_pass(pipeline, OptimizePass::RemoveUnusedNames, validation)
  add_pipeline_pass(pipeline, OptimizePass::RemoveUnusedBrs, validation)
  add_pipeline_pass(pipeline, OptimizePass::RemoveUnusedNames, validation)
  add_pipeline_pass(pipeline, OptimizePass::OptimizeInstructions, validation)
  if features.has_gc {
    add_pipeline_pass(pipeline, OptimizePass::HeapStoreOptimization, validation)
  }
  if global.opt_level >= 2 || global.shrink_level >= 2 {
    add_pipeline_pass(pipeline, OptimizePass::PickLoadSigns, validation)
  }
  if global.opt_level >= 3 || global.shrink_level >= 2 {
    add_pipeline_pass(pipeline, OptimizePass::PrecomputePropagate, validation)
  } else {
    add_pipeline_pass(pipeline, OptimizePass::Precompute, validation)
  }
  if features.low_memory_unused {
    if global.opt_level >= 3 || global.shrink_level >= 1 {
      add_pipeline_pass(
        pipeline,
        OptimizePass::OptimizeAddedConstantsPropagate,
        validation,
      )
    } else {
      add_pipeline_pass(
        pipeline,
        OptimizePass::OptimizeAddedConstants,
        validation,
      )
    }
  }
  if global.opt_level >= 2 || global.shrink_level >= 2 {
    add_pipeline_pass(pipeline, OptimizePass::CodePushing, validation)
  }
  if features.has_multivalue {
    add_pipeline_pass(pipeline, OptimizePass::TupleOptimization, validation)
  }
  add_pipeline_pass(
    pipeline,
    OptimizePass::SimplifyLocalsNoStructure,
    validation,
  )
  add_pipeline_pass(pipeline, OptimizePass::Vacuum, validation)
  add_pipeline_pass(pipeline, OptimizePass::ReorderLocals, validation)
  add_pipeline_pass(pipeline, OptimizePass::RemoveUnusedBrs, validation)
  if global.opt_level > 1 && features.has_gc {
    add_pipeline_pass(pipeline, OptimizePass::Heap2Local, validation)
  }
  if global.opt_level >= 3 || global.shrink_level >= 2 {
    add_pipeline_pass(pipeline, OptimizePass::MergeLocals, validation)
  }
  if global.opt_level > 1 && features.has_gc {
    add_pipeline_pass(pipeline, OptimizePass::OptimizeCasts, validation)
    add_pipeline_pass(pipeline, OptimizePass::LocalSubtyping, validation)
  }
  add_pipeline_pass(pipeline, OptimizePass::CoalesceLocals, validation)
  if global.opt_level >= 3 || global.shrink_level >= 1 {
    add_pipeline_pass(pipeline, OptimizePass::LocalCSE, validation)
  }
  add_pipeline_pass(pipeline, OptimizePass::SimplifyLocals, validation)
  add_pipeline_pass(pipeline, OptimizePass::Vacuum, validation)
  add_pipeline_pass(pipeline, OptimizePass::ReorderLocals, validation)
  add_pipeline_pass(pipeline, OptimizePass::CoalesceLocals, validation)
  add_pipeline_pass(pipeline, OptimizePass::ReorderLocals, validation)
  add_pipeline_pass(pipeline, OptimizePass::Vacuum, validation)
  if global.opt_level >= 3 || global.shrink_level >= 1 {
    add_pipeline_pass(pipeline, OptimizePass::CodeFolding, validation)
  }
  add_pipeline_pass(pipeline, OptimizePass::MergeBlocks, validation)
  add_pipeline_pass(pipeline, OptimizePass::RemoveUnusedBrs, validation)
  add_pipeline_pass(pipeline, OptimizePass::RemoveUnusedNames, validation)
  add_pipeline_pass(pipeline, OptimizePass::MergeBlocks, validation)
  if global.opt_level >= 3 || global.shrink_level >= 2 {
    add_pipeline_pass(pipeline, OptimizePass::PrecomputePropagate, validation)
  } else {
    add_pipeline_pass(pipeline, OptimizePass::Precompute, validation)
  }
  add_pipeline_pass(pipeline, OptimizePass::OptimizeInstructions, validation)
  if features.has_gc {
    add_pipeline_pass(pipeline, OptimizePass::HeapStoreOptimization, validation)
  }
  if global.opt_level >= 2 || global.shrink_level >= 1 {
    add_pipeline_pass(
      pipeline,
      OptimizePass::RedundantSetElimination,
      validation,
    )
  }
  add_pipeline_pass(pipeline, OptimizePass::Vacuum, validation)
}

///|
fn add_default_global_optimization_post_passes(
  pipeline : Array[PipelineEntry],
  global : PipelineGlobal,
  features : PipelineFeatures,
) -> Unit {
  let validation = default_pipeline_validation(global)
  if global.opt_level >= 2 || global.shrink_level >= 1 {
    add_pipeline_pass(
      pipeline,
      OptimizePass::DeadArgumentEliminationOptimizing,
      validation,
    )
  }
  if global.opt_level >= 2 || global.shrink_level >= 2 {
    add_pipeline_pass(pipeline, OptimizePass::InliningOptimizing, validation)
  }
  add_pipeline_pass(
    pipeline,
    OptimizePass::DuplicateFunctionElimination,
    validation,
  )
  add_pipeline_pass(
    pipeline,
    OptimizePass::DuplicateImportElimination,
    validation,
  )
  if global.shrink_level >= 2 {
    add_pipeline_pass(pipeline, OptimizePass::MergeSimilarFunctions, validation)
  }
  if global.opt_level >= 2 || global.shrink_level >= 2 {
    add_pipeline_pass(
      pipeline,
      OptimizePass::SimplifyGlobalsOptimizing,
      validation,
    )
  } else {
    add_pipeline_pass(pipeline, OptimizePass::SimplifyGlobals, validation)
  }
  add_pipeline_pass(
    pipeline,
    OptimizePass::RemoveUnusedModuleElements,
    validation,
  )
  if global.opt_level >= 2 && features.has_strings {
    add_pipeline_pass(pipeline, OptimizePass::StringGathering, validation)
  }
  if global.opt_level >= 2 || global.shrink_level >= 1 {
    add_pipeline_pass(pipeline, OptimizePass::ReorderGlobals, validation)
  }
  add_pipeline_pass(pipeline, OptimizePass::Directize, validation)
}

///|
pub fn default_optimize_pipeline(
  global : PipelineGlobal,
  features? : PipelineFeatures = PipelineFeatures::new(),
) -> Array[PipelineEntry] {
  let pipeline : Array[PipelineEntry] = []
  let _ = noop_early_pass
  add_default_global_optimization_pre_passes(pipeline, global, features)
  add_default_function_optimization_passes(pipeline, global, features)
  add_default_global_optimization_post_passes(pipeline, global, features)
  pipeline
}
