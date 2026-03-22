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
  low_memory_unused : Bool
  traps_never_happen : Bool
} derive(Eq, Show, Debug)

///|
pub fn PipelineFeatures::new(
  has_gc? : Bool = false,
  has_multivalue? : Bool = false,
  has_strings? : Bool = false,
  closed_world? : Bool = false,
  low_memory_unused? : Bool = false,
  traps_never_happen? : Bool = false,
) -> PipelineFeatures {
  {
    has_gc,
    has_multivalue,
    has_strings,
    closed_world,
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
    .on_funcidx_evt(fn(_, _, idx) {
      optimization_note_used_func(
        used_funcs, func_worklist, imported_func_count, defined_func_count, idx,
      )
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
fn optimization_collect_module_element_uses_in_func(
  func : Func,
  subtypes : Array[SubType],
  func_type_idxs : Array[TypeIdx],
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
  used_elems : Array[Bool],
  elem_worklist : Array[Int],
  used_datas : Array[Bool],
  data_worklist : Array[Int],
  elems : Array[Elem],
  active_elem_indices_by_table : Array[Array[Int]],
) -> Unit {
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_funcidx_evt(fn(_, _, idx) {
      optimization_note_used_func(
        used_funcs, func_worklist, imported_func_count, defined_func_count, idx,
      )
      unchanged()
    })
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
        @lib.CallIndirect(type_idx, table_idx)
        | @lib.ReturnCallIndirect(type_idx, table_idx) => {
          optimization_note_used_table(
            used_tables, table_worklist, imported_table_count, defined_table_count,
            table_idx,
          )
          optimization_collect_indirect_call_elem_uses(
            table_idx, type_idx, active_elem_indices_by_table, elems, subtypes, func_type_idxs,
            used_elems, elem_worklist,
          )
        }
        @lib.TableGet(table_idx)
        | @lib.TableSet(table_idx)
        | @lib.TableGrow(table_idx)
        | @lib.TableFill(table_idx)
        | @lib.TableInit(_, table_idx) =>
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, table_idx,
          )
        @lib.TableCopy(dst_idx, src_idx) => {
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, dst_idx,
          )
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, src_idx,
          )
        }
        @lib.TableSize(table_idx) =>
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, table_idx,
          )
        _ => ()
      }
      unchanged()
    })
    .on_tinstruction_evt(fn(_, _, instr) {
      match instr.kind {
        @lib.TCallIndirect(type_idx, table_idx, _, _)
        | @lib.TReturnCallIndirect(type_idx, table_idx, _, _) => {
          optimization_note_used_table(
            used_tables, table_worklist, imported_table_count, defined_table_count,
            table_idx,
          )
          optimization_collect_indirect_call_elem_uses(
            table_idx, type_idx, active_elem_indices_by_table, elems, subtypes, func_type_idxs,
            used_elems, elem_worklist,
          )
        }
        @lib.TTableGet(table_idx, _)
        | @lib.TTableSet(table_idx, _, _)
        | @lib.TTableGrow(table_idx, _, _)
        | @lib.TTableFill(table_idx, _, _, _)
        | @lib.TTableInit(_, table_idx, _, _, _) =>
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, table_idx,
          )
        @lib.TTableCopy(dst_idx, src_idx, _, _, _) => {
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, dst_idx,
          )
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, src_idx,
          )
        }
        @lib.TTableSize(table_idx) =>
          optimization_note_observable_table(
            used_tables, observable_tables, table_worklist, imported_table_count,
            defined_table_count, table_idx,
          )
        _ => ()
      }
      unchanged()
    })
  ignore(walker.walk_func((), func))
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
        offset, used_funcs, func_worklist, imported_func_count, defined_func_count,
        used_globals, global_worklist, imported_global_count, defined_global_count,
        used_tables, table_worklist, imported_table_count, defined_table_count, used_mems,
        imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
        defined_tag_count,
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
              expr, used_funcs, func_worklist, imported_func_count, defined_func_count,
              used_globals, global_worklist, imported_global_count, defined_global_count,
              used_tables, table_worklist, imported_table_count, defined_table_count,
              used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
              imported_tag_count, defined_tag_count,
            )
          }
        @lib.TypedExprsElemKind(_, exprs) =>
          for expr in exprs {
            optimization_collect_func_uses_in_expr(
              expr, used_funcs, func_worklist, imported_func_count, defined_func_count,
              used_globals, global_worklist, imported_global_count, defined_global_count,
              used_tables, table_worklist, imported_table_count, defined_table_count,
              used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
              imported_tag_count, defined_tag_count,
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
              expr, used_funcs, func_worklist, imported_func_count, defined_func_count,
              used_globals, global_worklist, imported_global_count, defined_global_count,
              used_tables, table_worklist, imported_table_count, defined_table_count,
              used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
              imported_tag_count, defined_tag_count,
            )
          }
        @lib.TypedExprsElemKind(_, exprs) =>
          for expr in exprs {
            optimization_collect_func_uses_in_expr(
              expr, used_funcs, func_worklist, imported_func_count, defined_func_count,
              used_globals, global_worklist, imported_global_count, defined_global_count,
              used_tables, table_worklist, imported_table_count, defined_table_count,
              used_mems, imported_mem_count, defined_mem_count, used_tags, tag_worklist,
              imported_tag_count, defined_tag_count,
            )
          }
      }
  }
}

///|
fn optimization_collect_func_uses_in_data(
  data : Data,
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
        offset, used_funcs, func_worklist, imported_func_count, defined_func_count,
        used_globals, global_worklist, imported_global_count, defined_global_count,
        used_tables, table_worklist, imported_table_count, defined_table_count, used_mems,
        imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
        defined_tag_count,
      )
    }
    _ => ()
  }
}

///|
fn optimization_collect_uses_in_global(
  global_ : Global,
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
        init, used_funcs, func_worklist, imported_func_count, defined_func_count,
        used_globals, global_worklist, imported_global_count, defined_global_count,
        used_tables, table_worklist, imported_table_count, defined_table_count, used_mems,
        imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
        defined_tag_count,
      )
  }
}

///|
fn optimization_collect_uses_in_table(
  table : Table,
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
  match table {
    Table(_, Some(init)) =>
      optimization_collect_func_uses_in_expr(
        init, used_funcs, func_worklist, imported_func_count, defined_func_count,
        used_globals, global_worklist, imported_global_count, defined_global_count,
        used_tables, table_worklist, imported_table_count, defined_table_count, used_mems,
        imported_mem_count, defined_mem_count, used_tags, tag_worklist, imported_tag_count,
        defined_tag_count,
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
      kept_funcs.push(funcs[i])
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

  let imported_func_count = optimization_imported_func_count(mod)
  let total_func_count = imported_func_count + funcs.length()
  let used_funcs : Array[Bool] = []
  for _ in 0..<total_func_count {
    used_funcs.push(false)
  }
  let imported_global_count = optimization_imported_global_count(mod)
  let total_global_count = imported_global_count + globals.length()
  let used_globals : Array[Bool] = []
  for _ in 0..<total_global_count {
    used_globals.push(false)
  }
  let imported_table_count = optimization_imported_table_count(mod)
  let total_table_count = imported_table_count + tables.length()
  let used_tables : Array[Bool] = []
  let observable_tables : Array[Bool] = []
  for _ in 0..<total_table_count {
    used_tables.push(false)
    observable_tables.push(false)
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
  for _ in 0..<elems.length() {
    used_elems.push(false)
  }
  let used_datas : Array[Bool] = []
  for _ in 0..<datas.length() {
    used_datas.push(false)
  }
  let func_worklist : Array[Int] = []
  let global_worklist : Array[Int] = []
  let table_worklist : Array[Int] = []
  let tag_worklist : Array[Int] = []
  let elem_worklist : Array[Int] = []
  let data_worklist : Array[Int] = []
  let func_type_idxs = optimization_all_func_type_idxs(mod, type_idxs)
  let active_elem_indices_by_table = optimization_active_elem_indices_by_table(
    elems, total_table_count,
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
        subtypes,
        func_type_idxs,
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
        used_elems,
        elem_worklist,
        used_datas,
        data_worklist,
        elems,
        active_elem_indices_by_table,
      )
    }
    while global_worklist.length() > 0 {
      let local_idx = global_worklist.pop().unwrap()
      optimization_collect_uses_in_global(
        globals[local_idx],
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
    while table_worklist.length() > 0 {
      let local_idx = table_worklist.pop().unwrap()
      optimization_collect_uses_in_table(
        tables[local_idx],
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
    while tag_worklist.length() > 0 {
      ignore(tag_worklist.pop())
    }
    while elem_worklist.length() > 0 {
      let elem_idx = elem_worklist.pop().unwrap()
      optimization_collect_func_uses_in_elem(
        elems[elem_idx],
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
  let mut changed = false
  let mut i = 0
  while i < funcs.length() {
    let keep = used_funcs[imported_func_count + i]
    keep_defined.push(keep)
    if !keep {
      changed = true
    }
    i += 1
  }
  let keep_defined_globals : Array[Bool] = []
  i = 0
  while i < globals.length() {
    let keep = used_globals[imported_global_count + i]
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
    let keep = used_elems[i]
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
    mod, type_idxs, funcs, keep_defined,
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
