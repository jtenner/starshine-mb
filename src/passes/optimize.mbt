///|
pub enum HotPassRegistryCategory {
  HotPass
  BoundaryOnly
  Removed
  Preset
} derive(Eq, Show, Debug)

///|
pub fn HotPassRegistryCategory::hot_pass() -> HotPassRegistryCategory {
  HotPass
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
    "global-refining", "global-struct-inference", "global-struct-inference-desc-cast",
    "global-type-optimization", "simplify-globals", "simplify-globals-optimizing",
    "global-effects", "propagate-globals-globally", "type-refining", "type-generalizing",
    "type-finalizing", "type-un-finalizing", "unsubtyping", "heap2local", "heap-store-optimization",
    "inlining", "inlining-optimizing", "inline-main", "merge-similar-functions",
    "once-reduction", "minimize-rec-groups", "type-merging", "monomorphize", "monomorphize-always",
    "memory-packing", "gufa", "gufa-optimizing", "gufa-cast-all", "i64-to-i32-lowering",
    "duplicate-function-elimination", "remove-unused-names", "reorder-locals", "reorder-types",
    "reorder-globals", "reorder-globals-always", "reorder-functions", "reorder-functions-by-name",
    "remove-unused-types", "remove-unused", "remove-unused-module-elements", "remove-unused-non-function-elements",
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
    "de-nan", "remove-unused-brs", "simplify-locals", "simplify-locals-no-tee", "simplify-locals-no-structure",
    "simplify-locals-no-tee-no-structure", "simplify-locals-no-nesting", "untee",
  ]
}

///|
fn pass_registry_entries() -> Array[HotPassRegistryEntry] {
  let entries = [
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
    pass_registry_entry_preset(
      "optimize",
      "Run the default hot optimization preset.",
      ["vacuum"],
    ),
    pass_registry_entry_preset(
      "shrink",
      "Run the default size-biased hot optimization preset.",
      ["vacuum"],
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
  ["vacuum"]
}

///|
pub fn shrink_preset_passes(_options : HotPipelineOptions) -> Array[String] {
  ["vacuum"]
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
fn run_hot_pipeline_func(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  entries : Array[HotPassRegistryEntry],
  options : HotPipelineOptions,
) -> Result[@lib.Func, String] {
  let lift_start_us = perf_start_timer_opt(options.perf, "lift")
  let func = @ir.hot_lift_func(mod_, func_idx)
  match options.perf {
    Some(perf) => {
      perf_count_hot_alloc_delta(
        perf,
        HotPerfHotSnapshot::empty(),
        perf_snapshot_hot_func(func),
      )
      perf_dump_hot_func(perf, func, "after-lift")
    }
    None => ()
  }
  perf_stop_timer_opt(options.perf, "lift", lift_start_us)
  match
    pipeline_verify_checkpoint_with_perf(
      options.perf,
      HotPipelineVerifyPolicy::AfterEachPass,
      "verify after lift",
      HotPipelineVerifyTarget::HotFuncTarget(func),
      "verify:after-lift",
    ) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let cache = @ir.HotAnalysisCache::new()
  for entry in entries {
    let descriptor = match entry.descriptor {
      Some(descriptor) => descriptor
      None => continue
    }
    let ctx = HotPassContext::new(
      descriptor,
      cache,
      options.verify_policy,
      options.trace,
      perf=options.perf,
    )
    match hot_pass_run(ctx, func) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  match
    pipeline_verify_checkpoint_with_perf(
      options.perf,
      HotPipelineVerifyPolicy::AfterEachPass,
      "verify before lower",
      HotPipelineVerifyTarget::HotFuncTarget(func),
      "verify:before-lower",
    ) {
    Ok(_) => {
      let lower_start_us = perf_start_timer_opt(options.perf, "lower")
      let lowered = @ir.hot_lower_func(func)
      perf_stop_timer_opt(options.perf, "lower", lower_start_us)
      Ok(lowered)
    }
    Err(err) => Err(err)
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
  let imported_func_count = run_hot_pipeline_imported_func_count(mod_)
  let next_code_sec = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let lowered : Array[@lib.Func] = []
      for code_idx = 0; code_idx < defs.length(); code_idx = code_idx + 1 {
        let func_idx = @lib.FuncIdx::new(
          (imported_func_count + code_idx).reinterpret_as_uint(),
        )
        let lowered_func = match
          run_hot_pipeline_func(mod_, func_idx, entries, options) {
          Ok(func) => func
          Err(err) => return Err("func[\{func_idx}]: \{err}")
        }
        lowered.push(lowered_func)
      }
      Some(@lib.CodeSec::new(lowered))
    }
    None => None
  }
  let out = match next_code_sec {
    Some(code_sec) => mod_.with_code_sec(code_sec)
    None => mod_
  }
  if options.validate_final_module {
    match
      pipeline_verify_checkpoint_with_perf(
        options.perf,
        HotPipelineVerifyPolicy::AfterEachPass,
        "final module validate",
        HotPipelineVerifyTarget::ModuleTarget(out),
        "validate:final-module",
      ) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  perf_emit_counters_opt(options.perf, "pipeline:done")
  (options.trace)("pipeline:done")
  Ok(out)
}
