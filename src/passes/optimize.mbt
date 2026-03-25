///|
pub enum HotPassRegistryCategory {
  HotPass
  ModulePass
  BoundaryOnly
  Removed
  Preset
} derive(Eq, Show, Debug)

///|
pub fn HotPassRegistryCategory::hot_pass() -> HotPassRegistryCategory {
  HotPass
}

///|
pub fn HotPassRegistryCategory::module_pass() -> HotPassRegistryCategory {
  ModulePass
}

///|
pub fn HotPassRegistryCategory::boundary_only() -> HotPassRegistryCategory {
  BoundaryOnly
}

///|
pub fn HotPassRegistryCategory::removed() -> HotPassRegistryCategory {
  Removed
}

///|
pub fn HotPassRegistryCategory::preset() -> HotPassRegistryCategory {
  Preset
}

///|
pub struct HotPassRegistryEntry {
  name : String
  summary : String
  category : HotPassRegistryCategory
  descriptor : @ir.HotPassDescriptor?
  expanded_passes : Array[String]
} derive(Eq, Show, Debug)

///|
fn pass_registry_entry_hot(
  name : String,
  summary : String,
  descriptor : @ir.HotPassDescriptor,
) -> HotPassRegistryEntry {
  {
    name,
    summary,
    category: HotPassRegistryCategory::HotPass,
    descriptor: Some(descriptor),
    expanded_passes: [],
  }
}

///|
fn pass_registry_entry_module(
  name : String,
  summary : String,
) -> HotPassRegistryEntry {
  {
    name,
    summary,
    category: HotPassRegistryCategory::module_pass(),
    descriptor: None,
    expanded_passes: [],
  }
}

///|
fn pass_registry_entry_boundary_only(
  name : String,
  summary? : String = "Legacy boundary-only pass; not available in the hot pipeline.",
) -> HotPassRegistryEntry {
  {
    name,
    summary,
    category: HotPassRegistryCategory::boundary_only(),
    descriptor: None,
    expanded_passes: [],
  }
}

///|
fn pass_registry_entry_removed(
  name : String,
  summary? : String = "Legacy pass removed from the active hot pipeline until its IR2 port lands.",
) -> HotPassRegistryEntry {
  {
    name,
    summary,
    category: HotPassRegistryCategory::removed(),
    descriptor: None,
    expanded_passes: [],
  }
}

///|
fn pass_registry_entry_preset(
  name : String,
  summary : String,
  expanded_passes : Array[String],
) -> HotPassRegistryEntry {
  {
    name,
    summary,
    category: HotPassRegistryCategory::Preset,
    descriptor: None,
    expanded_passes,
  }
}

///|
fn pass_registry_boundary_only_names() -> Array[String] {
  [
    "abstract-type-refining", "alignment-lowering", "constant-field-propagation",
    "constant-field-null-test-folding", "dead-argument-elimination", "dead-argument-elimination-optimizing",
    "signature-pruning", "signature-refining", "duplicate-import-elimination", "directize",
    "global-struct-inference-desc-cast", "global-type-optimization", "simplify-globals",
    "simplify-globals-optimizing", "global-effects", "propagate-globals-globally",
    "type-refining", "type-generalizing", "type-finalizing", "type-un-finalizing",
    "unsubtyping", "heap2local", "heap-store-optimization", "inlining", "inlining-optimizing",
    "inline-main", "merge-similar-functions", "minimize-rec-groups", "type-merging",
    "monomorphize", "monomorphize-always", "gufa", "gufa-optimizing", "gufa-cast-all",
    "i64-to-i32-lowering", "remove-unused-names", "reorder-locals", "reorder-types",
    "reorder-globals", "reorder-globals-always", "reorder-functions", "reorder-functions-by-name",
    "remove-unused-types", "remove-unused", "remove-unused-non-function-elements",
  ]
}

///|
fn pass_registry_removed_names() -> Array[String] {
  [
    "avoid-reinterprets", "coalesce-locals", "code-folding", "code-pushing", "const-hoisting",
    "dataflow-optimization", "local-cse", "local-subtyping", "loop-invariant-code-motion",
    "merge-locals", "merge-blocks", "flatten", "re-reloop", "tuple-optimization",
    "optimize-added-constants", "optimize-added-constants-propagate", "precompute",
    "precompute-propagate", "redundant-set-elimination", "pick-load-signs", "optimize-casts",
    "de-nan", "remove-unused-brs", "simplify-locals-no-tee", "simplify-locals-no-structure",
    "simplify-locals-no-tee-no-structure", "simplify-locals-no-nesting", "untee",
  ]
}

///|
fn pass_registry_entries() -> Array[HotPassRegistryEntry] {
  let entries = [
    pass_registry_entry_hot(
      "ssa-nomerge",
      ssa_nomerge_summary(),
      ssa_nomerge_descriptor(),
    ),
    pass_registry_entry_hot(
      "vacuum",
      "Remove `nop` roots and region entries through hot IR cleanup.",
      @ir.HotPassDescriptor::new("vacuum", invalidates=[
        @ir.HotAnalysis::cfg(),
        @ir.HotAnalysis::dominance(),
        @ir.HotAnalysis::liveness(),
        @ir.HotAnalysis::use_def(),
        @ir.HotAnalysis::effects(),
        @ir.HotAnalysis::loop_info(),
        @ir.HotAnalysis::ssa(),
      ]),
    ),
    pass_registry_entry_hot(
      "dead-code-elimination",
      dead_code_elimination_summary(),
      dead_code_elimination_descriptor(),
    ),
    pass_registry_entry_hot(
      "optimize-instructions",
      optimize_instructions_summary(),
      optimize_instructions_descriptor(),
    ),
    pass_registry_entry_hot(
      "simplify-locals",
      simplify_locals_summary(),
      simplify_locals_descriptor(),
    ),
    pass_registry_entry_module("duplicate-function-elimination", dfe_summary()),
    pass_registry_entry_module("remove-unused-module-elements", rume_summary()),
    pass_registry_entry_module("memory-packing", memory_packing_summary()),
    pass_registry_entry_module("once-reduction", once_reduction_summary()),
    pass_registry_entry_module("global-refining", global_refining_summary()),
    pass_registry_entry_module(
      "global-struct-inference",
      global_struct_inference_summary(),
    ),
    pass_registry_entry_preset(
      "optimize",
      "Run the default hot optimization preset.",
      [
        "memory-packing", "once-reduction", "global-refining", "global-struct-inference",
        "ssa-nomerge", "dead-code-elimination", "vacuum", "optimize-instructions",
        "simplify-locals",
      ],
    ),
    pass_registry_entry_preset(
      "shrink",
      "Run the default size-biased hot optimization preset.",
      [
        "memory-packing", "once-reduction", "global-refining", "global-struct-inference",
        "ssa-nomerge", "dead-code-elimination", "vacuum", "optimize-instructions",
        "simplify-locals",
      ],
    ),
  ]
  for name in pass_registry_boundary_only_names() {
    entries.push(pass_registry_entry_boundary_only(name))
  }
  for name in pass_registry_removed_names() {
    entries.push(pass_registry_entry_removed(name))
  }
  entries
}

///|
pub fn pass_registry_all() -> Array[HotPassRegistryEntry] {
  pass_registry_entries()
}

///|
pub fn pass_registry_lookup(name : String) -> HotPassRegistryEntry? {
  for entry in pass_registry_entries() {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
pub fn pass_registry_category(name : String) -> HotPassRegistryCategory? {
  match pass_registry_lookup(name) {
    Some(entry) => Some(entry.category)
    None => None
  }
}

///|
pub fn optimize_preset_passes(_options : HotPipelineOptions) -> Array[String] {
  [
    "memory-packing", "once-reduction", "global-refining", "global-struct-inference",
    "ssa-nomerge", "dead-code-elimination", "vacuum", "optimize-instructions", "simplify-locals",
  ]
}

///|
pub fn shrink_preset_passes(_options : HotPipelineOptions) -> Array[String] {
  [
    "memory-packing", "once-reduction", "global-refining", "global-struct-inference",
    "ssa-nomerge", "dead-code-elimination", "vacuum", "optimize-instructions", "simplify-locals",
  ]
}

///|
fn run_hot_pipeline_imported_func_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn run_hot_pipeline_expand_passes(
  options : HotPipelineOptions,
  requested_passes : Array[String],
) -> Result[Array[HotPassRegistryEntry], String] {
  let expanded : Array[HotPassRegistryEntry] = []
  for name in requested_passes {
    let entry = match pass_registry_lookup(name) {
      Some(entry) => entry
      None => return Err("unknown pass flag \{name}")
    }
    match entry.category {
      HotPassRegistryCategory::HotPass => expanded.push(entry)
      HotPassRegistryCategory::ModulePass => expanded.push(entry)
      HotPassRegistryCategory::BoundaryOnly =>
        return Err(
          "pass flag \{name} is boundary-only and is not implemented in the hot pipeline",
        )
      HotPassRegistryCategory::Removed =>
        return Err(
          "pass flag \{name} is removed from the active hot pipeline registry",
        )
      HotPassRegistryCategory::Preset => {
        let preset_passes = if name == "optimize" {
          optimize_preset_passes(options)
        } else {
          shrink_preset_passes(options)
        }
        for expanded_name in preset_passes {
          match pass_registry_lookup(expanded_name) {
            Some(pass_entry) => expanded.push(pass_entry)
            None =>
              return Err(
                "preset \{name} expanded to unknown pass \{expanded_name}",
              )
          }
        }
      }
    }
  }
  Ok(expanded)
}

///|
fn run_hot_pipeline_format_final_validate_error(
  before_mod : @lib.Module,
  mod_ : @lib.Module,
  err : @validate.ValidationError,
) -> String {
  match @validate.validation_error_func_idx(err) {
    Some(func_idx) =>
      "final module validate: \{err}\n\nOriginal function:\n\{before_mod.pretty_print_func(func_idx)}\n\nOptimized function:\n\{mod_.pretty_print_func(func_idx)}"
    None => "final module validate: \{err}"
  }
}

///|
pub fn run_hot_pipeline(
  mod_ : @lib.Module,
  options : HotPipelineOptions,
  requested_passes : Array[String],
) -> Result[@lib.Module, String] {
  let entries = match
    run_hot_pipeline_expand_passes(options, requested_passes) {
    Ok(entries) => entries
    Err(err) => return Err(err)
  }
  (options.trace)("pipeline:start requested=\{requested_passes.length()}")
  let mut current = mod_
  for entry in entries {
    current = match entry.category {
      HotPassRegistryCategory::HotPass =>
        match run_hot_pipeline_apply_hot_pass(current, entry, options) {
          Ok(next) => next
          Err(err) => return Err(err)
        }
      HotPassRegistryCategory::ModulePass =>
        match run_hot_pipeline_apply_module_pass(current, entry, options) {
          Ok(next) => next
          Err(err) => return Err(err)
        }
      _ => current
    }
  }
  if options.validate_final_module {
    let validate_start_us = perf_start_timer_opt(
      options.perf,
      "validate:final-module",
    )
    match @validate.validate_module(current) {
      Ok(_) => {
        perf_stop_timer_opt(
          options.perf,
          "validate:final-module",
          validate_start_us,
        )
        perf_validation_checkpoint_opt(options.perf, "final module validate")
      }
      Err(err) => {
        perf_stop_timer_opt(
          options.perf,
          "validate:final-module",
          validate_start_us,
        )
        return Err(
          run_hot_pipeline_format_final_validate_error(mod_, current, err),
        )
      }
    }
  }
  perf_emit_counters_opt(options.perf, "pipeline:done")
  (options.trace)("pipeline:done")
  Ok(current)
}
