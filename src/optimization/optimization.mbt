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
pub type ModuleWidePassFn = (Module, PipelineGlobal) -> (Module, PipelineGlobal)

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
  low_memory_unused : Bool
} derive(Eq, Show, Debug)

///|
pub fn PipelineFeatures::new(
  has_gc? : Bool = false,
  has_multivalue? : Bool = false,
  has_strings? : Bool = false,
  closed_world? : Bool = false,
  low_memory_unused? : Bool = false,
) -> PipelineFeatures {
  { has_gc, has_multivalue, has_strings, closed_world, low_memory_unused }
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
) -> (Module, PipelineGlobal) {
  (mod, global)
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

      let compacted = mod
        .with_func_sec(FuncSec::new(kept_types))
        .with_code_sec(CodeSec::new(kept_funcs))
      Some(optimization_rewrite_func_indices(compacted, abs_remap))
    }
    _ => None
  }
}

///|
pub fn run_duplicate_function_elimination(
  mod : Module,
  global : PipelineGlobal,
) -> (Module, PipelineGlobal) {
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
