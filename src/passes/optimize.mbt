///|
pub enum HotPassRegistryCategory {
  HotPass
  ModulePass
  BoundaryOnly
  Removed
  Preset
} derive(Eq, Debug)

///|
pub impl Show for HotPassRegistryCategory with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

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
} derive(Eq, Debug)

///|
pub impl Show for HotPassRegistryEntry with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

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
    "constant-field-null-test-folding", "dead-argument-elimination", "signature-pruning",
    "signature-refining", "global-type-optimization", "simplify-globals", "global-effects",
    "propagate-globals-globally", "type-refining", "type-generalizing", "type-finalizing",
    "type-un-finalizing", "unsubtyping", "inline-main", "merge-similar-functions",
    "minimize-rec-groups", "type-merging", "monomorphize", "monomorphize-always",
    "gufa", "gufa-optimizing", "gufa-cast-all", "i64-to-i32-lowering", "reorder-types",
    "reorder-globals-always", "reorder-functions", "reorder-functions-by-name", "remove-unused-types",
    "remove-unused",
  ]
}

///|
fn pass_registry_removed_names() -> Array[String] {
  [
    "const-hoisting", "dataflow-optimization", "loop-invariant-code-motion", "flatten",
    "re-reloop", "optimize-added-constants", "optimize-added-constants-propagate",
    "precompute-propagate", "de-nan", "simplify-locals-no-tee", "simplify-locals-no-tee-no-structure",
    "simplify-locals-no-nesting",
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
    pass_registry_entry_hot("ssa", ssa_full_summary(), ssa_full_descriptor()),
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
      "remove-unused-names",
      remove_unused_names_summary(),
      remove_unused_names_descriptor(),
    ),
    pass_registry_entry_hot(
      "remove-unused-brs",
      remove_unused_brs_summary(),
      remove_unused_brs_descriptor(),
    ),
    pass_registry_entry_hot(
      "optimize-instructions",
      optimize_instructions_summary(),
      optimize_instructions_descriptor(),
    ),
    pass_registry_entry_hot(
      "heap-store-optimization",
      heap_store_optimization_summary(),
      heap_store_optimization_descriptor(),
    ),
    pass_registry_entry_hot(
      "heap2local",
      heap2local_summary(),
      heap2local_descriptor(),
    ),
    pass_registry_entry_hot(
      "optimize-casts",
      optimize_casts_summary(),
      optimize_casts_descriptor(),
    ),
    pass_registry_entry_hot(
      "pick-load-signs",
      pick_load_signs_summary(),
      pick_load_signs_descriptor(),
    ),
    pass_registry_entry_hot(
      "precompute",
      precompute_summary(),
      precompute_descriptor(),
    ),
    pass_registry_entry_hot(
      "code-pushing",
      code_pushing_summary(),
      code_pushing_descriptor(),
    ),
    pass_registry_entry_hot(
      "code-folding",
      code_folding_summary(),
      code_folding_descriptor(),
    ),
    pass_registry_entry_hot(
      "tuple-optimization",
      tuple_optimization_summary(),
      tuple_optimization_descriptor(),
    ),
    pass_registry_entry_hot(
      "simplify-locals",
      simplify_locals_summary(),
      simplify_locals_descriptor(),
    ),
    pass_registry_entry_hot(
      "simplify-locals-nostructure",
      simplify_locals_nostructure_summary(),
      simplify_locals_nostructure_descriptor(),
    ),
    pass_registry_entry_hot(
      "simplify-locals-no-structure",
      simplify_locals_nostructure_summary(),
      simplify_locals_nostructure_alias_descriptor(),
    ),
    pass_registry_entry_hot(
      "simplify-locals-notee-nostructure",
      simplify_locals_notee_nostructure_summary(),
      simplify_locals_notee_nostructure_descriptor(),
    ),
    pass_registry_entry_module("local-cse", local_cse_summary()),
    pass_registry_entry_module("merge-locals", merge_locals_summary()),
    pass_registry_entry_hot(
      "merge-blocks",
      merge_blocks_summary(),
      merge_blocks_descriptor(),
    ),
    pass_registry_entry_hot(
      "redundant-set-elimination",
      rse_summary(),
      rse_descriptor(),
    ),
    pass_registry_entry_module(
      "avoid-reinterprets",
      avoid_reinterprets_summary(),
    ),
    pass_registry_entry_module("untee", untee_summary()),
    pass_registry_entry_module("duplicate-function-elimination", dfe_summary()),
    pass_registry_entry_module("remove-unused-module-elements", rume_summary()),
    pass_registry_entry_module(
      "remove-unused-nonfunction-module-elements",
      rume_nonfunction_summary(),
    ),
    pass_registry_entry_module("memory-packing", memory_packing_summary()),
    pass_registry_entry_module("once-reduction", once_reduction_summary()),
    pass_registry_entry_module("global-refining", global_refining_summary()),
    pass_registry_entry_module(
      "global-struct-inference",
      global_struct_inference_summary(),
    ),
    pass_registry_entry_module(
      "global-struct-inference-desc-cast",
      global_struct_inference_desc_cast_summary(),
    ),
    pass_registry_entry_module("reorder-locals", reorder_locals_summary()),
    pass_registry_entry_module("local-subtyping", local_subtyping_summary()),
    pass_registry_entry_module("coalesce-locals", coalesce_locals_summary()),
    pass_registry_entry_module("duplicate-import-elimination", die_summary()),
    pass_registry_entry_module("strip-debug", strip_debug_summary()),
    pass_registry_entry_module(
      "simplify-globals-optimizing",
      simplify_globals_optimizing_summary(),
    ),
    pass_registry_entry_module("dae-optimizing", dae_optimizing_summary()),
    pass_registry_entry_module(
      "dead-argument-elimination-optimizing",
      dae_optimizing_summary(),
    ),
    pass_registry_entry_module("inlining", inlining_summary()),
    pass_registry_entry_module(
      "inlining-optimizing",
      inlining_optimizing_summary(),
    ),
    pass_registry_entry_module("no-inline", no_inline_summary()),
    pass_registry_entry_module("no-full-inline", no_full_inline_summary()),
    pass_registry_entry_module("no-partial-inline", no_partial_inline_summary()),
    pass_registry_entry_module("string-gathering", string_gathering_summary()),
    pass_registry_entry_module("reorder-globals", reorder_globals_summary()),
    pass_registry_entry_module("directize", directize_summary()),
    pass_registry_entry_preset(
      "optimize",
      "Run the default hot optimization preset.",
      [
        "duplicate-function-elimination", "remove-unused-module-elements", "memory-packing",
        "once-reduction", "global-refining", "global-struct-inference", "ssa-nomerge",
        "dead-code-elimination", "remove-unused-names", "remove-unused-brs", "remove-unused-names",
        "vacuum", "remove-unused-brs", "optimize-instructions", "heap-store-optimization",
        "pick-load-signs", "precompute", "code-pushing", "tuple-optimization", "simplify-locals-nostructure",
        "vacuum", "reorder-locals", "remove-unused-brs", "heap2local", "optimize-casts",
        "local-subtyping", "coalesce-locals", "local-cse", "simplify-locals", "merge-blocks",
        "remove-unused-brs", "remove-unused-names", "merge-blocks", "precompute",
        "optimize-instructions", "heap-store-optimization", "dae-optimizing", "inlining-optimizing",
        "duplicate-function-elimination", "duplicate-import-elimination", "simplify-globals-optimizing",
        "remove-unused-module-elements", "string-gathering", "reorder-globals", "directize",
      ],
    ),
    pass_registry_entry_preset(
      "shrink",
      "Run the default size-biased hot optimization preset.",
      [
        "duplicate-function-elimination", "remove-unused-module-elements", "memory-packing",
        "once-reduction", "global-refining", "global-struct-inference", "ssa-nomerge",
        "dead-code-elimination", "remove-unused-names", "remove-unused-brs", "remove-unused-names",
        "vacuum", "remove-unused-brs", "optimize-instructions", "heap-store-optimization",
        "pick-load-signs", "precompute", "code-pushing", "tuple-optimization", "simplify-locals-nostructure",
        "vacuum", "reorder-locals", "remove-unused-brs", "heap2local", "optimize-casts",
        "local-subtyping", "coalesce-locals", "local-cse", "simplify-locals", "merge-blocks",
        "remove-unused-brs", "remove-unused-names", "merge-blocks", "precompute",
        "optimize-instructions", "heap-store-optimization", "dae-optimizing", "inlining-optimizing",
        "duplicate-function-elimination", "duplicate-import-elimination", "simplify-globals-optimizing",
        "remove-unused-module-elements", "string-gathering", "reorder-globals", "directize",
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
priv struct HotPassRegistryCache {
  entries : Array[HotPassRegistryEntry]
  lookup : @hashmap.HashMap[String, Int]
  help_entries : Array[HotPassRegistryEntry]
}

///|
fn HotPassRegistryCache::new() -> HotPassRegistryCache {
  let entries = pass_registry_entries()
  let lookup : @hashmap.HashMap[String, Int] = @hashmap.new(
    capacity=entries.length() * 2 + 1,
  )
  let help_entries : Array[HotPassRegistryEntry] = []
  let mut idx = 0
  for entry in entries {
    lookup.set(entry.name, idx)
    match entry.category {
      HotPassRegistryCategory::HotPass | HotPassRegistryCategory::Preset =>
        help_entries.push(entry)
      _ => ()
    }
    idx += 1
  }
  { entries, lookup, help_entries }
}

///|
let pass_registry_cache : HotPassRegistryCache = HotPassRegistryCache::new()

///|
pub fn pass_registry_help_entries() -> Array[HotPassRegistryEntry] {
  pass_registry_cache.help_entries
}

///|
fn pass_registry_lookup_index(name : String) -> Int? {
  pass_registry_cache.lookup.get(name)
}

///|
fn pass_registry_lookup_cached(name : String) -> HotPassRegistryEntry? {
  match pass_registry_lookup_index(name) {
    Some(idx) => Some(pass_registry_cache.entries[idx])
    None => None
  }
}

///|
fn pass_registry_clone_descriptor(
  descriptor : @ir.HotPassDescriptor,
) -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    descriptor.name,
    requires=descriptor.requires.copy(),
    invalidates=descriptor.invalidates.copy(),
  )
}

///|
fn pass_registry_clone_entry(
  entry : HotPassRegistryEntry,
) -> HotPassRegistryEntry {
  {
    name: entry.name,
    summary: entry.summary,
    category: entry.category,
    descriptor: match entry.descriptor {
      Some(descriptor) => Some(pass_registry_clone_descriptor(descriptor))
      None => None
    },
    expanded_passes: entry.expanded_passes.copy(),
  }
}

///|
pub fn pass_registry_all() -> Array[HotPassRegistryEntry] {
  let entries : Array[HotPassRegistryEntry] = []
  for entry in pass_registry_cache.entries {
    entries.push(pass_registry_clone_entry(entry))
  }
  entries
}

///|
pub fn pass_registry_lookup(name : String) -> HotPassRegistryEntry? {
  match pass_registry_lookup_cached(name) {
    Some(entry) => Some(pass_registry_clone_entry(entry))
    None => None
  }
}

///|
pub fn pass_registry_category(name : String) -> HotPassRegistryCategory? {
  match pass_registry_lookup_index(name) {
    Some(idx) => Some(pass_registry_cache.entries[idx].category)
    None => None
  }
}

///|
pub fn tuple_optimization_exact_slot_prereqs_ready() -> Bool {
  pass_registry_category("code-pushing") ==
  Some(HotPassRegistryCategory::hot_pass()) &&
  pass_registry_category("simplify-locals-nostructure") ==
  Some(HotPassRegistryCategory::hot_pass())
}

///|
pub fn simplify_locals_notee_nostructure_exact_neighborhood_ready() -> Bool {
  pass_registry_category("flatten") == Some(HotPassRegistryCategory::hot_pass()) &&
  pass_registry_category("simplify-locals-notee-nostructure") ==
  Some(HotPassRegistryCategory::hot_pass()) &&
  pass_registry_category("local-cse") ==
  Some(HotPassRegistryCategory::hot_pass())
}

///|
pub fn simplify_locals_nostructure_exact_slot_passes() -> Array[String] {
  [
    "code-pushing", "tuple-optimization", "simplify-locals-nostructure", "vacuum",
    "reorder-locals", "remove-unused-brs",
  ]
}

///|
pub fn optimize_preset_passes(_options : HotPipelineOptions) -> Array[String] {
  // Keep the aggressive flatten -> simplify-locals-notee-nostructure ->
  // local-cse neighborhood off public presets until both neighbors are active.
  ignore(simplify_locals_notee_nostructure_exact_neighborhood_ready())
  [
    "duplicate-function-elimination", "remove-unused-module-elements", "memory-packing",
    "once-reduction", "global-refining", "global-struct-inference", "ssa-nomerge",
    "dead-code-elimination", "remove-unused-names", "remove-unused-brs", "remove-unused-names",
    "vacuum", "remove-unused-brs", "optimize-instructions", "heap-store-optimization",
    "pick-load-signs", "precompute", "code-pushing", "tuple-optimization", "simplify-locals-nostructure",
    "vacuum", "reorder-locals", "remove-unused-brs", "heap2local", "optimize-casts",
    "local-subtyping", "coalesce-locals", "local-cse", "simplify-locals", "merge-blocks",
    "remove-unused-brs", "remove-unused-names", "merge-blocks", "precompute", "optimize-instructions",
    "heap-store-optimization", "dae-optimizing", "inlining-optimizing", "duplicate-function-elimination",
    "duplicate-import-elimination", "simplify-globals-optimizing", "remove-unused-module-elements",
    "string-gathering", "reorder-globals", "directize",
  ]
}

///|
pub fn shrink_preset_passes(_options : HotPipelineOptions) -> Array[String] {
  ignore(simplify_locals_notee_nostructure_exact_neighborhood_ready())
  [
    "duplicate-function-elimination", "remove-unused-module-elements", "memory-packing",
    "once-reduction", "global-refining", "global-struct-inference", "ssa-nomerge",
    "dead-code-elimination", "remove-unused-names", "remove-unused-brs", "remove-unused-names",
    "vacuum", "remove-unused-brs", "optimize-instructions", "heap-store-optimization",
    "pick-load-signs", "precompute", "code-pushing", "tuple-optimization", "simplify-locals-nostructure",
    "vacuum", "reorder-locals", "remove-unused-brs", "heap2local", "optimize-casts",
    "local-subtyping", "coalesce-locals", "local-cse", "simplify-locals", "merge-blocks",
    "remove-unused-brs", "remove-unused-names", "merge-blocks", "precompute", "optimize-instructions",
    "heap-store-optimization", "dae-optimizing", "inlining-optimizing", "duplicate-function-elimination",
    "duplicate-import-elimination", "simplify-globals-optimizing", "remove-unused-module-elements",
    "string-gathering", "reorder-globals", "directize",
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
fn run_hot_pipeline_module_has_memory(mod_ : @lib.Module) -> Bool {
  let has_defined_memory = match mod_.mem_sec {
    Some(@lib.MemSec(mems)) => mems.length() > 0
    None => false
  }
  if has_defined_memory {
    return true
  }
  let mut has_imported_memory = false
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.MemExternType(_)) => has_imported_memory = true
          _ => ()
        }
      }
    None => ()
  }
  has_imported_memory
}

///|
fn run_hot_pipeline_expand_passes(
  options : HotPipelineOptions,
  requested_passes : Array[String],
) -> Result[Array[HotPassRegistryEntry], String] {
  let expanded : Array[HotPassRegistryEntry] = []
  for name in requested_passes {
    let lookup_name = match no_inline_pass_pattern(name) {
      Some((base, _)) => base
      None => name
    }
    let entry = match pass_registry_lookup_cached(lookup_name) {
      Some(entry) =>
        if lookup_name == name {
          entry
        } else {
          HotPassRegistryEntry::{ ..entry, name, }
        }
      None => return Err("unknown pass flag \{name}")
    }
    match entry.category {
      HotPassRegistryCategory::HotPass => expanded.push(entry)
      HotPassRegistryCategory::ModulePass => expanded.push(entry)
      HotPassRegistryCategory::BoundaryOnly =>
        return Err(
          "pass flag \{name} is boundary-only and is not implemented in the hot pipeline: \{entry.summary}",
        )
      HotPassRegistryCategory::Removed =>
        return Err(
          "pass flag \{name} is removed from the active hot pipeline registry: \{entry.summary}",
        )
      HotPassRegistryCategory::Preset => {
        let preset_passes = if name == "optimize" {
          optimize_preset_passes(options)
        } else {
          shrink_preset_passes(options)
        }
        for expanded_name in preset_passes {
          match pass_registry_lookup_cached(expanded_name) {
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
fn run_hot_pipeline_entry_can_stack(entry : HotPassRegistryEntry) -> Bool {
  match entry.descriptor {
    Some(descriptor) =>
      match descriptor.name {
        "remove-unused-names" => true
        _ => false
      }
    None => false
  }
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
fn run_hot_pipeline_dump_invalid_module(mod_ : @lib.Module) -> Unit {
  match @binary.encode_module(mod_) {
    Ok(bytes) => ignore(@sfs.write_file_bytes(".tmp/final-invalid.wasm", bytes))
    Err(_) => ()
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
  let pending_hot_passes : Array[HotPassRegistryEntry] = []
  let flush_hot_passes = fn() -> Result[Unit, String] {
    if pending_hot_passes.length() == 0 {
      return Ok(())
    }
    current = if options.stack_function_passes &&
      pending_hot_passes.length() > 1 {
      match
        run_hot_pipeline_apply_hot_pass_stack(
          current, pending_hot_passes, options,
        ) {
        Ok(next) => next
        Err(err) => return Err(err)
      }
    } else {
      let mut next_current = current
      for pending in pending_hot_passes {
        next_current = match
          run_hot_pipeline_apply_hot_pass(next_current, pending, options) {
          Ok(next) => next
          Err(err) => return Err(err)
        }
      }
      next_current
    }
    pending_hot_passes.clear()
    Ok(())
  }
  for entry in entries {
    match entry.category {
      HotPassRegistryCategory::HotPass =>
        if options.stack_function_passes &&
          run_hot_pipeline_entry_can_stack(entry) {
          pending_hot_passes.push(entry)
        } else {
          match flush_hot_passes() {
            Ok(_) => ()
            Err(err) => return Err(err)
          }
          current = match
            run_hot_pipeline_apply_hot_pass(current, entry, options) {
            Ok(next) => next
            Err(err) => return Err(err)
          }
        }
      HotPassRegistryCategory::ModulePass => {
        match flush_hot_passes() {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
        current = match
          run_hot_pipeline_apply_module_pass(current, entry, options) {
          Ok(next) => next
          Err(err) => return Err(err)
        }
      }
      _ => ()
    }
  }
  match flush_hot_passes() {
    Ok(_) => ()
    Err(err) => return Err(err)
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
        run_hot_pipeline_dump_invalid_module(current)
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
