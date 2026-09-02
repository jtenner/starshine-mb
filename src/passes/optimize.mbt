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
    "constant-field-null-test-folding", "signature-pruning", "signature-refining",
    "global-type-optimization", "simplify-globals", "global-effects", "propagate-globals-globally",
    "type-refining", "type-generalizing", "type-finalizing", "type-un-finalizing",
    "unsubtyping", "minimize-rec-groups", "type-merging", "monomorphize", "monomorphize-always",
    "gufa", "gufa-optimizing", "gufa-cast-all", "i64-to-i32-lowering", "reorder-types",
    "reorder-globals-always", "reorder-functions", "reorder-functions-by-name", "remove-unused-types",
    "remove-unused",
  ]
}

///|
fn pass_registry_removed_names() -> Array[String] {
  [
    "const-hoisting", "dataflow-optimization", "loop-invariant-code-motion", "re-reloop",
    "optimize-added-constants", "optimize-added-constants-propagate", "de-nan", "simplify-locals-no-tee-no-structure",
  ]
}

///|
fn pass_registry_entries() -> Array[HotPassRegistryEntry] {
  let entries = [
    pass_registry_entry_hot("flatten", flatten_summary(), flatten_descriptor()),
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
      "precompute-propagate",
      precompute_propagate_summary(),
      precompute_propagate_descriptor(),
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
      "simplify-locals-notee",
      simplify_locals_notee_summary(),
      simplify_locals_notee_descriptor(),
    ),
    pass_registry_entry_hot(
      "simplify-locals-no-tee",
      simplify_locals_notee_summary(),
      simplify_locals_notee_alias_descriptor(),
    ),
    pass_registry_entry_hot(
      "simplify-locals-nonesting",
      simplify_locals_nonesting_summary(),
      simplify_locals_nonesting_descriptor(),
    ),
    pass_registry_entry_hot(
      "simplify-locals-no-nesting",
      simplify_locals_nonesting_summary(),
      simplify_locals_nonesting_alias_descriptor(),
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
    pass_registry_entry_hot(
      "merge-locals",
      merge_locals_summary(),
      merge_locals_descriptor(),
    ),
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
    pass_registry_entry_module(
      "merge-similar-functions",
      merge_similar_functions_summary(),
    ),
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
    pass_registry_entry_module(
      "coalesce-locals-cfg", "Coalesce compatible loop locals with CFG liveness and validated rollback.",
    ),
    pass_registry_entry_module("duplicate-import-elimination", die_summary()),
    pass_registry_entry_module("strip-debug", strip_debug_summary()),
    pass_registry_entry_module(
      "simplify-globals-optimizing",
      simplify_globals_optimizing_summary(),
    ),
    pass_registry_entry_module("dead-argument-elimination", dae_summary()),
    pass_registry_entry_module("dae", dae_summary()),
    pass_registry_entry_module("dae-optimizing", dae_optimizing_summary()),
    pass_registry_entry_module(
      "dead-argument-elimination-optimizing",
      dae_optimizing_summary(),
    ),
    pass_registry_entry_module("inlining", inlining_summary()),
    pass_registry_entry_module("inline-main", inline_main_summary()),
    pass_registry_entry_module(
      "inlining-optimizing",
      inlining_optimizing_summary(),
    ),
    pass_registry_entry_module("no-inline", no_inline_summary()),
    pass_registry_entry_module("no-full-inline", no_full_inline_summary()),
    pass_registry_entry_module("no-partial-inline", no_partial_inline_summary()),
    pass_registry_entry_module("string-gathering", string_gathering_summary()),
    pass_registry_entry_module("reorder-globals", reorder_globals_summary()),
    pass_registry_entry_module(
      "apply-compiler-facts", "Materialize explicitly trusted frontend assertions into ordinary Wasm before optimization.",
    ),
    pass_registry_entry_module("directize", directize_summary()),
    pass_registry_entry_preset(
      "optimize",
      "Run the default hot optimization preset.",
      optimize_preset_passes(
        HotPipelineOptions::new(optimize_level=4, shrink_level=4),
      ),
    ),
    pass_registry_entry_preset(
      "shrink",
      "Run the default size-biased hot optimization preset.",
      shrink_preset_passes(
        HotPipelineOptions::new(optimize_level=4, shrink_level=4),
      ),
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
  { entries, lookup, help_entries, }
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
fn pass_registry_splitmix_word(seed : UInt64, ordinal : UInt64) -> UInt64 {
  let mut value = seed + 0x9e3779b97f4a7c15UL * (ordinal + 1UL)
  value = (value ^ (value >> 30)) * 0xbf58476d1ce4e5b9UL
  value = (value ^ (value >> 27)) * 0x94d049bb133111ebUL
  value ^ (value >> 31)
}

///|
pub fn pass_registry_fixed_point_cleanup_sequence() -> Array[String] {
  let compatible_names = ["merge-blocks"]
  let passes : Array[String] = []
  for name in compatible_names {
    match pass_registry_lookup(name) {
      Some(entry) if entry.category == HotPassRegistryCategory::HotPass =>
        passes.push(entry.name)
      _ => ()
    }
  }
  passes
}

///|
pub fn pass_registry_random_executable_sequence(
  profile : String,
  seed : UInt64,
) -> Array[String] {
  let compatible_names = [
    "remove-unused-names", "remove-unused-brs", "vacuum", "merge-blocks",
  ]
  let eligible : Array[String] = []
  for name in compatible_names {
    match pass_registry_lookup(name) {
      Some(entry) if entry.category == HotPassRegistryCategory::HotPass =>
        eligible.push(entry.name)
      _ => ()
    }
  }
  if eligible.length() == 0 {
    return []
  }
  let mut ordinal = 0UL
  let next = fn() {
    let value = pass_registry_splitmix_word(seed, ordinal)
    ordinal += 1UL
    value
  }
  let length = match profile {
    "random-short" => 1 + (next() % 5UL).to_int()
    "random-medium" => 2 + (next() % 11UL).to_int()
    "random-long" => 12 + (next() % 21UL).to_int()
    "random-mixed" => {
      let bucket = next() % 100UL
      if bucket < 55UL {
        1 + (next() % 5UL).to_int()
      } else if bucket < 90UL {
        6 + (next() % 7UL).to_int()
      } else {
        16 + (next() % 17UL).to_int()
      }
    }
    _ => 0
  }
  let passes : Array[String] = []
  for _ in 0..<length {
    let idx = (next() % eligible.length().to_uint64()).to_int()
    passes.push(eligible[idx])
  }
  passes
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
  Some(HotPassRegistryCategory::module_pass())
}

///|
pub fn simplify_locals_nostructure_exact_slot_passes() -> Array[String] {
  [
    "code-pushing", "tuple-optimization", "simplify-locals-nostructure", "vacuum",
    "reorder-locals", "remove-unused-brs",
  ]
}

///|
priv struct HotPipelineFeatureFacts {
  has_gc : Bool
  has_multivalue : Bool
  has_strings : Bool
  has_imported_functions : Bool
  retain_initial_flatten : Bool
  skip_initial_ssa : Bool
}

///|
fn HotPipelineFeatureFacts::all() -> HotPipelineFeatureFacts {
  {
    has_gc: true,
    has_multivalue: true,
    has_strings: true,
    has_imported_functions: true,
    retain_initial_flatten: true,
    skip_initial_ssa: false,
  }
}

///|
fn hot_pipeline_record_comp_type_features(
  comp_type : @lib.CompType,
  facts : HotPipelineFeatureFacts,
) -> HotPipelineFeatureFacts {
  match comp_type {
    @lib.ArrayCompType(_) | @lib.StructCompType(_) =>
      HotPipelineFeatureFacts::{ ..facts, has_gc: true, }
    @lib.FuncCompType(_, results) if results.length() > 1 =>
      HotPipelineFeatureFacts::{ ..facts, has_multivalue: true, }
    _ => facts
  }
}

///|
fn hot_pipeline_module_has_complex_memory_shape(mod_ : @lib.Module) -> Bool {
  let mut memory_count = 0
  let mut has_memory64 = false
  let mut has_zero_minimum = false
  let record_memory = fn(mem_type : @lib.MemType) -> Unit {
    memory_count += 1
    match mem_type {
      @lib.MemType(@lib.I32Limits(min, _), _) =>
        if min == 0U {
          has_zero_minimum = true
        }
      @lib.MemType(@lib.I64Limits(min, _), _) => {
        has_memory64 = true
        if min == 0UL {
          has_zero_minimum = true
        }
      }
    }
  }
  match mod_.mem_sec {
    Some(@lib.MemSec(mems)) =>
      for mem in mems {
        record_memory(mem)
      }
    None => ()
  }
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.MemExternType(mem_type)) =>
            record_memory(mem_type)
          _ => ()
        }
      }
    None => ()
  }
  memory_count > 1 || has_memory64 || has_zero_minimum
}

///|
priv struct InitialFlattenSimdFacts {
  mut const_count : Int
  mut xor_count : Int
  mut i64_mul_count : Int
  mut i64_div_s_count : Int
  mut total_instr_count : Int
  mut br_if_count : Int
  mut unreachable_count : Int
  mut has_unreachable : Bool
  mut has_table_copy : Bool
}

///|
fn hot_pipeline_record_initial_flatten_simd_facts(
  instrs : Array[@lib.Instruction],
  facts : InitialFlattenSimdFacts,
) -> Unit {
  for instr in instrs {
    facts.total_instr_count += 1
    match instr {
      @lib.Instruction::V128Const(
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _
      ) => facts.const_count += 1
      @lib.Instruction::V128Xor => facts.xor_count += 1
      @lib.Instruction::I64Mul => facts.i64_mul_count += 1
      @lib.Instruction::I64DivS => facts.i64_div_s_count += 1
      @lib.Instruction::BrIf(_) => facts.br_if_count += 1
      @lib.Instruction::Unreachable => {
        facts.unreachable_count += 1
        facts.has_unreachable = true
      }
      @lib.Instruction::TableCopy(_, _) => facts.has_table_copy = true
      @lib.Block(_, @lib.Expr(nested))
      | @lib.Loop(_, @lib.Expr(nested))
      | @lib.TryTable(_, _, @lib.Expr(nested)) =>
        hot_pipeline_record_initial_flatten_simd_facts(nested, facts)
      @lib.If(_, then_body, else_body) => {
        hot_pipeline_record_initial_flatten_simd_facts(then_body, facts)
        match else_body {
          Some(nested) =>
            hot_pipeline_record_initial_flatten_simd_facts(nested, facts)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn hot_pipeline_instrs_have_dense_v128_xor(
  instrs : Array[@lib.Instruction],
) -> Bool {
  let facts = InitialFlattenSimdFacts::{
    const_count: 0,
    xor_count: 0,
    i64_mul_count: 0,
    i64_div_s_count: 0,
    total_instr_count: 0,
    br_if_count: 0,
    unreachable_count: 0,
    has_unreachable: false,
    has_table_copy: false,
  }
  hot_pipeline_record_initial_flatten_simd_facts(instrs, facts)
  facts.const_count >= 64 && facts.xor_count >= 32
}

///|
fn hot_pipeline_module_requires_initial_flatten(mod_ : @lib.Module) -> Bool {
  if hot_pipeline_module_has_complex_memory_shape(mod_) {
    return true
  }
  let global_count = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals.length()
    None => 0
  }
  let has_table = match mod_.table_sec {
    Some(@lib.TableSec(tables)) => tables.length() > 0
    None => false
  }
  if global_count >= 4 && has_table {
    return true
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(instrs)) = func
        let extra_facts = InitialFlattenSimdFacts::{
          const_count: 0,
          xor_count: 0,
          i64_mul_count: 0,
          i64_div_s_count: 0,
          total_instr_count: 0,
          br_if_count: 0,
          unreachable_count: 0,
          has_unreachable: false,
          has_table_copy: false,
        }
        hot_pipeline_record_initial_flatten_simd_facts(instrs, extra_facts)
        if run_hot_pipeline_raw_simplify_locals_has_wago_expansion_hazard(
            instrs,
          ) ||
          hot_pipeline_instrs_have_dense_v128_xor(instrs) ||
          extra_facts.has_table_copy ||
          (funcs.length() <= 2 && extra_facts.i64_mul_count >= 8) ||
          (
            funcs.length() <= 2 &&
            extra_facts.i64_div_s_count >= 2 &&
            extra_facts.has_unreachable
          ) ||
          (
            funcs.length() == 1 &&
            global_count == 0 &&
            !has_table &&
            extra_facts.total_instr_count <= 8 &&
            extra_facts.br_if_count == 1 &&
            extra_facts.unreachable_count == 1
          ) ||
          (
            global_count > 0 &&
            extra_facts.const_count > 0 &&
            extra_facts.const_count <= 2 &&
            extra_facts.xor_count > 0
          ) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn hot_pipeline_module_feature_facts(
  mod_ : @lib.Module,
) -> HotPipelineFeatureFacts {
  let imported_function_count = run_hot_pipeline_imported_func_count(mod_)
  let mut facts = HotPipelineFeatureFacts::{
    has_gc: false,
    has_multivalue: false,
    has_strings: mod_.stringrefs_sec is Some(_),
    has_imported_functions: imported_function_count > 0,
    retain_initial_flatten: true,
    skip_initial_ssa: imported_function_count >= 2,
  }
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) =>
            facts = hot_pipeline_record_comp_type_features(
              subtype.get_comptype(),
              facts,
            )
          @lib.GroupRecType(subtypes) =>
            for subtype in subtypes {
              facts = hot_pipeline_record_comp_type_features(
                subtype.get_comptype(),
                facts,
              )
            }
        }
      }
    None => ()
  }
  HotPipelineFeatureFacts::{
    ..facts,
    retain_initial_flatten: facts.has_imported_functions ||
    facts.has_gc ||
    run_hot_pipeline_module_has_assemblyscript_startup_exported_memory(mod_) ||
    hot_pipeline_module_requires_initial_flatten(mod_),
  }
}

///|
fn default_function_optimization_passes_with_features(
  optimize_level : Int,
  shrink_level : Int,
  features : HotPipelineFeatureFacts,
) -> Array[String] {
  let passes : Array[String] = []
  if optimize_level >= 3 || shrink_level >= 1 {
    passes.push("ssa-nomerge")
  }
  if optimize_level >= 4 {
    passes.append(["flatten", "simplify-locals-notee-nostructure", "local-cse"])
  }
  passes.append([
    "dead-code-elimination", "remove-unused-names", "remove-unused-brs", "remove-unused-names",
    "optimize-instructions",
  ])
  if features.has_gc {
    passes.push("heap-store-optimization")
  }
  if optimize_level >= 2 || shrink_level >= 2 {
    passes.push("pick-load-signs")
  }
  if optimize_level >= 3 || shrink_level >= 2 {
    passes.push("precompute-propagate")
  } else {
    passes.push("precompute")
  }
  if optimize_level >= 2 || shrink_level >= 2 {
    passes.push("code-pushing")
  }
  if features.has_multivalue {
    passes.push("tuple-optimization")
  }
  passes.append([
    "simplify-locals-nostructure", "vacuum", "reorder-locals", "remove-unused-brs",
  ])
  if optimize_level > 1 && features.has_gc {
    passes.push("heap2local")
  }
  if optimize_level >= 3 || shrink_level >= 2 {
    passes.push("merge-locals")
  }
  if optimize_level > 1 && features.has_gc {
    passes.push("optimize-casts")
    passes.push("local-subtyping")
  }
  passes.push("coalesce-locals")
  if optimize_level >= 3 || shrink_level >= 1 {
    passes.push("local-cse")
  }
  passes.append([
    "simplify-locals", "vacuum", "reorder-locals", "coalesce-locals", "reorder-locals",
    "vacuum",
  ])
  if optimize_level >= 3 || shrink_level >= 1 {
    passes.push("code-folding")
  }
  passes.append([
    "merge-blocks", "remove-unused-brs", "remove-unused-names", "merge-blocks",
  ])
  if optimize_level >= 3 || shrink_level >= 2 {
    passes.push("precompute-propagate")
  } else {
    passes.push("precompute")
  }
  passes.push("optimize-instructions")
  if features.has_gc {
    passes.push("heap-store-optimization")
  }
  if optimize_level >= 2 || shrink_level >= 1 {
    passes.push("redundant-set-elimination")
  }
  passes.push("vacuum")
  passes
}

///|
pub fn default_function_optimization_passes(
  optimize_level : Int,
  shrink_level : Int,
) -> Array[String] {
  default_function_optimization_passes_with_features(
    optimize_level,
    shrink_level,
    HotPipelineFeatureFacts::all(),
  )
}

///|
pub fn default_function_optimization_passes_for_module(
  mod_ : @lib.Module,
  optimize_level : Int,
  shrink_level : Int,
) -> Array[String] {
  default_function_optimization_passes_with_features(
    optimize_level,
    shrink_level,
    hot_pipeline_module_feature_facts(mod_),
  )
}

///|
pub fn inlining_nested_function_pipeline_passes(
  optimize_level : Int,
  shrink_level : Int,
) -> Array[String] {
  default_function_optimization_passes(optimize_level, shrink_level)
}

///|
fn hot_pipeline_o4z_late_convergence_passes() -> Array[String] {
  [
    "simplify-locals-nostructure", "coalesce-locals-cfg", "reorder-locals", "vacuum",
    "simplify-locals-nostructure", "coalesce-locals-cfg", "reorder-locals", "vacuum",
    "ssa-nomerge", "simplify-locals-nostructure", "coalesce-locals-cfg", "reorder-locals",
    "vacuum", "ssa-nomerge", "simplify-locals-nostructure", "coalesce-locals-cfg",
    "reorder-locals", "vacuum",
  ]
}

///|
fn hot_pipeline_full_preset_passes_with_features(
  options : HotPipelineOptions,
  features : HotPipelineFeatureFacts,
) -> Array[String] {
  let optimize_level = options.optimize_level
  let shrink_level = options.shrink_level
  let passes = ["duplicate-function-elimination"]
  if optimize_level >= 2 {
    passes.push("remove-unused-module-elements")
  }
  passes.push("memory-packing")
  if optimize_level >= 2 {
    passes.push("once-reduction")
  }
  if features.has_gc && optimize_level >= 2 {
    passes.push("global-refining")
    passes.push("remove-unused-module-elements")
    passes.push("global-struct-inference")
  }
  let function_passes = default_function_optimization_passes_with_features(
    optimize_level, shrink_level, features,
  )
  let mut skipped_initial_flatten = false
  let mut skipped_initial_ssa = false
  for pass_name in function_passes {
    if !features.retain_initial_flatten &&
      !skipped_initial_flatten &&
      pass_name == "flatten" {
      skipped_initial_flatten = true
    } else if features.skip_initial_ssa &&
      !skipped_initial_ssa &&
      pass_name == "ssa-nomerge" {
      skipped_initial_ssa = true
    } else {
      passes.push(pass_name)
    }
  }
  if optimize_level >= 2 || shrink_level >= 1 {
    passes.push("dae-optimizing")
  }
  if optimize_level >= 2 || shrink_level >= 2 {
    passes.push("inlining-optimizing")
  }
  passes.push("duplicate-function-elimination")
  passes.push("duplicate-import-elimination")
  // Binaryen runs merge-similar-functions at shrink level 2+, but that pass is
  // still boundary-only in Starshine. Keep the preset runnable and leave the
  // unsupported owner explicit in the backlog instead of silently accepting a
  // requested no-op.
  if optimize_level >= 2 || shrink_level >= 2 {
    passes.push("simplify-globals-optimizing")
  }
  // Binaryen uses plain simplify-globals below the optimizing threshold. That
  // sibling remains boundary-only, so the implemented preset omits it.
  passes.push("remove-unused-module-elements")
  if optimize_level >= 2 && features.has_strings {
    passes.push("string-gathering")
  }
  if optimize_level >= 2 || shrink_level >= 1 {
    passes.push("reorder-globals")
  }
  passes.push("directize")
  // Starshine intentionally strips debug/name metadata after Binaryen v131's
  // public roster. This is an extension outside Binaryen's scheduler.
  passes.push("strip-debug")
  // Inlining and guarded SIMD simplification can expose fresh nonoverlapping
  // local ranges after the earlier function queue. Run the explicit O4z local
  // convergence extension after stripping stale local-name metadata. Two
  // bounded SSA-normalization waves then expose the measured residual copy
  // families and immediately clean the introduced locals.
  passes.append(hot_pipeline_o4z_late_convergence_passes())
  passes
}

///|
// Non-O4z public presets are intentionally wall-time-first. Production
// attribution found that the full function/module queue cost 81-162 seconds on
// the debug-WASI artifact while often increasing output size. Keep the two
// measured high-payoff tiers here; every omitted owner remains directly
// runnable, and O4z retains the full compatibility scheduler below.
fn hot_pipeline_fast_preset_passes(
  options : HotPipelineOptions,
) -> Array[String] {
  let optimize_level = options.optimize_level
  let shrink_level = options.shrink_level
  let passes = ["duplicate-function-elimination"]
  if optimize_level >= 3 || shrink_level >= 1 {
    passes.append(["vacuum", "reorder-locals"])
  }
  passes.push("strip-debug")
  passes
}

///|
// O4z is the locked Binaryen-v131 compatibility lane. Other public levels use
// the measured fast spine rather than paying the full compatibility roster.
fn hot_pipeline_preset_passes_with_features(
  options : HotPipelineOptions,
  features : HotPipelineFeatureFacts,
) -> Array[String] {
  if options.optimize_level >= 4 && options.shrink_level >= 4 {
    hot_pipeline_full_preset_passes_with_features(options, features)
  } else {
    hot_pipeline_fast_preset_passes(options)
  }
}

///|
pub fn optimize_preset_passes(options : HotPipelineOptions) -> Array[String] {
  hot_pipeline_preset_passes_with_features(
    options,
    HotPipelineFeatureFacts::all(),
  )
}

///|
pub fn shrink_preset_passes(options : HotPipelineOptions) -> Array[String] {
  hot_pipeline_preset_passes_with_features(
    options,
    HotPipelineFeatureFacts::all(),
  )
}

///|
fn optimize_preset_passes_for_module(
  options : HotPipelineOptions,
  mod_ : @lib.Module,
) -> Array[String] {
  hot_pipeline_preset_passes_with_features(
    options,
    hot_pipeline_module_feature_facts(mod_),
  )
}

///|
fn shrink_preset_passes_for_module(
  options : HotPipelineOptions,
  mod_ : @lib.Module,
) -> Array[String] {
  hot_pipeline_preset_passes_with_features(
    options,
    hot_pipeline_module_feature_facts(mod_),
  )
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
  mod_ : @lib.Module,
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
          optimize_preset_passes_for_module(options, mod_)
        } else {
          shrink_preset_passes_for_module(options, mod_)
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
pub fn pass_registry_expanded_names_for_module(
  mod_ : @lib.Module,
  options : HotPipelineOptions,
  requested_passes : Array[String],
) -> Result[Array[String], String] {
  let entries = match
    run_hot_pipeline_expand_passes(mod_, options, requested_passes) {
    Ok(entries) => entries
    Err(err) => return Err(err)
  }
  let names : Array[String] = []
  for entry in entries {
    names.push(entry.name)
  }
  Ok(names)
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
fn run_hot_pipeline_entries_match_names(
  entries : Array[HotPassRegistryEntry],
  start : Int,
  names : Array[String],
) -> Bool {
  if start < 0 || start + names.length() > entries.length() {
    return false
  }
  for idx = 0; idx < names.length(); idx = idx + 1 {
    if entries[start + idx].name != names[idx] {
      return false
    }
  }
  true
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
    run_hot_pipeline_expand_passes(mod_, options, requested_passes) {
    Ok(entries) => entries
    Err(err) => return Err(err)
  }
  (options.trace)("pipeline:start requested=\{requested_passes.length()}")
  let pipeline_start_us = perf_start_timer_opt(options.perf, "pipeline")
  let prepared = match
    apply_compiler_facts(mod_, options.compiler_fact_policy) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  if prepared.stats.fact_sections_seen > 0 {
    (options.trace)(
      "pass[apply-compiler-facts]:summary " +
      compiler_fact_stats_summary(prepared.stats),
    )
  }
  let mut current = prepared.module_
  let original_has_caught_try_table = run_hot_pipeline_module_has_caught_try_table(
    mod_,
  )
  let artifact_scale_o4z_preset = options.optimize_level >= 4 &&
    options.shrink_level >= 4 &&
    requested_passes.any(fn(name) { name == "optimize" || name == "shrink" })
  let mut ssa_wave = 0
  let mut skip_o4z_late_convergence_entries = 0
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
  for entry_idx, entry in entries {
    if skip_o4z_late_convergence_entries > 0 {
      (options.trace)(
        "pass[\{entry.name}]:skip reason=artifact-scale-late-convergence",
      )
      skip_o4z_late_convergence_entries -= 1
      continue
    }
    if entry.name == "remove-unused-brs" && artifact_scale_o4z_preset {
      let defined_func_count = dae_defined_func_count(current)
      if !run_hot_pipeline_o4z_remove_unused_brs_selected(defined_func_count) {
        match flush_hot_passes() {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
        (options.trace)(
          "pass[remove-unused-brs]:skip reason=artifact-scale-defined-functions count=\{defined_func_count}",
        )
        continue
      }
    }
    if entry.name == "precompute-propagate" && artifact_scale_o4z_preset {
      let defined_func_count = dae_defined_func_count(current)
      if !run_hot_pipeline_o4z_precompute_propagate_selected(defined_func_count) {
        match flush_hot_passes() {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
        (options.trace)(
          "pass[precompute-propagate]:skip reason=artifact-scale-defined-functions count=\{defined_func_count}",
        )
        continue
      }
    }
    if entry.name == "ssa-nomerge" {
      ssa_wave += 1
      let defined_func_count = dae_defined_func_count(current)
      if artifact_scale_o4z_preset &&
        !run_hot_pipeline_o4z_ssa_wave_selected(defined_func_count, ssa_wave) {
        match flush_hot_passes() {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
        (options.trace)(
          "pass[ssa-nomerge]:skip reason=artifact-scale-late-wave count=\{defined_func_count} wave=\{ssa_wave}",
        )
        continue
      }
    }
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
    if artifact_scale_o4z_preset && entry.name == "strip-debug" {
      let late_convergence = hot_pipeline_o4z_late_convergence_passes()
      let defined_func_count = dae_defined_func_count(current)
      let has_caught_try_table = original_has_caught_try_table
      if run_hot_pipeline_entries_match_names(
          entries,
          entry_idx + 1,
          late_convergence,
        ) &&
        (
          has_caught_try_table ||
          !run_hot_pipeline_o4z_late_convergence_selected(defined_func_count)
        ) {
        skip_o4z_late_convergence_entries = late_convergence.length()
        let reason = if has_caught_try_table {
          "caught-try-table"
        } else {
          "artifact-scale-defined-functions count=\{defined_func_count}"
        }
        (options.trace)(
          "pipeline:o4z-late-convergence:skip reason=\{reason} passes=\{skip_o4z_late_convergence_entries}",
        )
      }
    }
  }
  match flush_hot_passes() {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  if artifact_scale_o4z_preset && original_has_caught_try_table {
    (options.trace)("pipeline:o4z-transaction:rollback reason=caught-try-table")
    current = mod_
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
        perf_stop_timer_opt(options.perf, "pipeline", pipeline_start_us)
        run_hot_pipeline_dump_invalid_module(current)
        return Err(
          run_hot_pipeline_format_final_validate_error(mod_, current, err),
        )
      }
    }
  }
  perf_stop_timer_opt(options.perf, "pipeline", pipeline_start_us)
  perf_emit_counters_opt(options.perf, "pipeline:done")
  (options.trace)("pipeline:done")
  Ok(current)
}
