///|
pub enum GenValidMode {
  Natural
  CoverageForced
} derive(Eq, Debug)

///|
pub impl Show for GenValidMode with output(self, logger) {
  match self {
    Natural => logger.write_string("Natural")
    CoverageForced => logger.write_string("CoverageForced")
  }
}

///|
pub struct GenValidSectionBias {
  imports_percent : Int
  tables_percent : Int
  mems_percent : Int
  globals_percent : Int
  tags_percent : Int
  start_percent : Int
  elems_percent : Int
  datas_percent : Int
} derive(Eq, Debug)

///|
pub impl Show for GenValidSectionBias with output(self, logger) {
  logger.write_string("GenValidSectionBias {imports_percent: ")
  self.imports_percent.output(logger)
  logger.write_string(", tables_percent: ")
  self.tables_percent.output(logger)
  logger.write_string(", mems_percent: ")
  self.mems_percent.output(logger)
  logger.write_string(", globals_percent: ")
  self.globals_percent.output(logger)
  logger.write_string(", tags_percent: ")
  self.tags_percent.output(logger)
  logger.write_string(", start_percent: ")
  self.start_percent.output(logger)
  logger.write_string(", elems_percent: ")
  self.elems_percent.output(logger)
  logger.write_string(", datas_percent: ")
  self.datas_percent.output(logger)
  logger.write_char('}')
}

///|
pub fn GenValidSectionBias::natural_default() -> GenValidSectionBias {
  {
    imports_percent: 30,
    tables_percent: 30,
    mems_percent: 30,
    globals_percent: 67,
    tags_percent: 20,
    start_percent: 10,
    elems_percent: 20,
    datas_percent: 20,
  }
}

///|
pub fn GenValidSectionBias::coverage_forced_default() -> GenValidSectionBias {
  {
    imports_percent: 100,
    tables_percent: 100,
    mems_percent: 100,
    globals_percent: 100,
    tags_percent: 100,
    start_percent: 100,
    elems_percent: 100,
    datas_percent: 100,
  }
}

///|
pub struct GenValidFeatureToggles {
  allow_imports : Bool
  allow_tables : Bool
  allow_mems : Bool
  allow_globals : Bool
  allow_tags : Bool
  allow_start : Bool
  allow_elems : Bool
  allow_datas : Bool
  allow_ref_types : Bool
  allow_v128 : Bool
  allow_relaxed_simd : Bool
  allow_calls : Bool
  allow_call_indirect : Bool
  allow_tail_calls : Bool
  allow_branch_heavy_control : Bool
  allow_memory_limit_variants : Bool
  allow_table_limit_variants : Bool
  allow_const_expr_variants : Bool
  allow_shared_memories : Bool
  allow_memory64 : Bool
  allow_atomics : Bool
  allow_subtyping_topology : Bool
  allow_name_custom_sections : Bool
  allow_typed_body_generator : Bool
} derive(Eq, Debug)

///|
pub impl Show for GenValidFeatureToggles with output(self, logger) {
  logger.write_string(", allow_imports:")
  self.allow_imports.output(logger)
  logger.write_string(", allow_tables:")
  self.allow_tables.output(logger)
  logger.write_string(", allow_mems:")
  self.allow_mems.output(logger)
  logger.write_string(", allow_globals:")
  self.allow_globals.output(logger)
  logger.write_string(", allow_tags:")
  self.allow_tags.output(logger)
  logger.write_string(", allow_start:")
  self.allow_start.output(logger)
  logger.write_string(", allow_elems:")
  self.allow_elems.output(logger)
  logger.write_string(", allow_datas:")
  self.allow_datas.output(logger)
  logger.write_string(", allow_ref_types:")
  self.allow_ref_types.output(logger)
  logger.write_string(", allow_v128:")
  self.allow_v128.output(logger)
  logger.write_string(", allow_relaxed_simd:")
  self.allow_relaxed_simd.output(logger)
  logger.write_string(", allow_calls:")
  self.allow_calls.output(logger)
  logger.write_string(", allow_call_indirect:")
  self.allow_call_indirect.output(logger)
  logger.write_string(", allow_tail_calls:")
  self.allow_tail_calls.output(logger)
  logger.write_string(", allow_branch_heavy_control:")
  self.allow_branch_heavy_control.output(logger)
  logger.write_string(", allow_memory_limit_variants:")
  self.allow_memory_limit_variants.output(logger)
  logger.write_string(", allow_table_limit_variants:")
  self.allow_table_limit_variants.output(logger)
  logger.write_string(", allow_const_expr_variants:")
  self.allow_const_expr_variants.output(logger)
  logger.write_string(", allow_shared_memories:")
  self.allow_shared_memories.output(logger)
  logger.write_string(", allow_memory64:")
  self.allow_memory64.output(logger)
  logger.write_string(", allow_atomics:")
  self.allow_atomics.output(logger)
  logger.write_string(", allow_subtyping_topology:")
  self.allow_subtyping_topology.output(logger)
  logger.write_string(", allow_name_custom_sections:")
  self.allow_name_custom_sections.output(logger)
  logger.write_string(", allow_typed_body_generator:")
  self.allow_typed_body_generator.output(logger)
}

///|
pub fn GenValidFeatureToggles::natural_default() -> GenValidFeatureToggles {
  {
    allow_imports: true,
    allow_tables: true,
    allow_mems: true,
    allow_globals: true,
    allow_tags: true,
    allow_start: true,
    allow_elems: true,
    allow_datas: true,
    allow_ref_types: true,
    allow_v128: true,
    allow_relaxed_simd: false,
    allow_calls: true,
    allow_call_indirect: true,
    allow_tail_calls: true,
    allow_branch_heavy_control: true,
    allow_memory_limit_variants: true,
    allow_table_limit_variants: true,
    allow_const_expr_variants: true,
    allow_shared_memories: true,
    allow_memory64: true,
    allow_atomics: true,
    allow_subtyping_topology: true,
    allow_name_custom_sections: true,
    allow_typed_body_generator: false,
  }
}

///|
pub fn GenValidFeatureToggles::coverage_forced_default() -> GenValidFeatureToggles {
  GenValidFeatureToggles::{
    ..GenValidFeatureToggles::natural_default(),
    allow_calls: true,
    allow_call_indirect: true,
    allow_tail_calls: true,
    allow_branch_heavy_control: true,
    allow_memory_limit_variants: true,
    allow_table_limit_variants: true,
    allow_const_expr_variants: true,
    allow_shared_memories: true,
    allow_memory64: true,
    allow_atomics: true,
    allow_subtyping_topology: true,
    allow_name_custom_sections: true,
  }
}

///|
pub struct GenValidConfig {
  mode : GenValidMode
  max_type_defs : Int
  max_imports : Int
  max_defined_funcs : Int
  max_tables : Int
  max_mems : Int
  max_globals : Int
  max_tags : Int
  max_elems : Int
  max_datas : Int
  max_params : Int
  max_results : Int
  max_locals : Int
  max_body_statements : Int
  max_body_depth : Int
  section_bias : GenValidSectionBias
  features : GenValidFeatureToggles
} derive(Eq, Debug)

///|
pub impl Show for GenValidConfig with output(self, logger) {
  logger.write_string("GenValidConfig {mode: ")
  self.mode.output(logger)
  logger.write_string(", max_type_defs: ")
  self.max_type_defs.output(logger)
  logger.write_string(", max_imports: ")
  self.max_imports.output(logger)
  logger.write_string(", max_defined_funcs: ")
  self.max_defined_funcs.output(logger)
  logger.write_string(", max_tables: ")
  self.max_tables.output(logger)
  logger.write_string(", max_mems: ")
  self.max_mems.output(logger)
  logger.write_string(", max_globals: ")
  self.max_globals.output(logger)
  logger.write_string(", max_tags: ")
  self.max_tags.output(logger)
  logger.write_string(", max_elems: ")
  self.max_elems.output(logger)
  logger.write_string(", max_datas: ")
  self.max_datas.output(logger)
  logger.write_string(", max_params: ")
  self.max_params.output(logger)
  logger.write_string(", max_results: ")
  self.max_results.output(logger)
  logger.write_string(", max_locals: ")
  self.max_locals.output(logger)
  logger.write_string(", max_body_statements: ")
  self.max_body_statements.output(logger)
  logger.write_string(", max_body_depth: ")
  self.max_body_depth.output(logger)
  logger.write_string(", section_bias: ")
  self.section_bias.output(logger)
  logger.write_string(", features: ")
  self.features.output(logger)
  logger.write_char('}')
}

///|
pub fn GenValidConfig::natural_default() -> GenValidConfig {
  {
    mode: Natural,
    max_type_defs: 8,
    max_imports: 5,
    max_defined_funcs: 4,
    max_tables: 3,
    max_mems: 2,
    max_globals: 4,
    max_tags: 2,
    max_elems: 3,
    max_datas: 3,
    max_params: 2,
    max_results: 1,
    max_locals: 5,
    max_body_statements: 6,
    max_body_depth: 2,
    section_bias: GenValidSectionBias::natural_default(),
    features: GenValidFeatureToggles::natural_default(),
  }
}

///|
pub fn GenValidConfig::coverage_forced_default() -> GenValidConfig {
  GenValidConfig::{
    ..GenValidConfig::natural_default(),
    mode: CoverageForced,
    max_type_defs: 18,
    max_imports: 6,
    max_tables: 4,
    max_mems: 2,
    max_globals: 5,
    max_tags: 2,
    max_elems: 4,
    max_datas: 4,
    max_locals: 6,
    section_bias: GenValidSectionBias::coverage_forced_default(),
    features: GenValidFeatureToggles::coverage_forced_default(),
  }
}

///|
pub fn GenValidConfig::portable_coverage_forced_default() -> GenValidConfig {
  let base = GenValidConfig::coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_tags: 0,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_ref_types: false,
      allow_tags: false,
    },
  }
}

///|
pub fn GenValidConfig::binaryen_oracle_coverage_forced_default() -> GenValidConfig {
  let base = GenValidConfig::portable_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_imports: 0,
    max_tables: 0,
    max_mems: 0,
    max_globals: 0,
    max_tags: 0,
    max_elems: 0,
    max_datas: 0,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: false,
      allow_tables: false,
      allow_mems: false,
      allow_globals: false,
      allow_tags: false,
      allow_start: false,
      allow_elems: false,
      allow_datas: false,
      allow_ref_types: false,
      allow_v128: false,
      allow_relaxed_simd: false,
      allow_call_indirect: false,
      allow_tail_calls: false,
      allow_memory_limit_variants: false,
      allow_table_limit_variants: false,
      allow_const_expr_variants: false,
      allow_shared_memories: false,
      allow_memory64: false,
      allow_atomics: false,
      allow_subtyping_topology: false,
    },
  }
}

///|
pub enum GenValidProfile {
  NaturalSmallProfile
  NaturalWideProfile
  NaturalDeepProfile
  CoverageForcedPortableProfile
  CoverageForcedAllFeaturesProfile
  BinaryenOraclePortableProfile
  MutationSeedSmallProfile
  MutationSeedRichProfile
  PassFuzzStressProfile
  ValidatorStressProfile
  NoImportsProfile
  ImportsHeavyProfile
  GcHeavyProfile
  SimdHeavyProfile
  RelaxedSimdProfile
  MemoryHeavyProfile
  ControlHeavyProfile
  TopologyHeavyProfile
} derive(Eq, Debug)

///|
pub fn gen_valid_profile_name(profile : GenValidProfile) -> String {
  match profile {
    NaturalSmallProfile => "natural-small"
    NaturalWideProfile => "natural-wide"
    NaturalDeepProfile => "natural-deep"
    CoverageForcedPortableProfile => "coverage-forced-portable"
    CoverageForcedAllFeaturesProfile => "coverage-forced-all-features"
    BinaryenOraclePortableProfile => "binaryen-oracle-portable"
    MutationSeedSmallProfile => "mutation-seed-small"
    MutationSeedRichProfile => "mutation-seed-rich"
    PassFuzzStressProfile => "pass-fuzz-stress"
    ValidatorStressProfile => "validator-stress"
    NoImportsProfile => "no-imports"
    ImportsHeavyProfile => "imports-heavy"
    GcHeavyProfile => "gc-heavy"
    SimdHeavyProfile => "simd-heavy"
    RelaxedSimdProfile => "relaxed-simd"
    MemoryHeavyProfile => "memory-heavy"
    ControlHeavyProfile => "control-heavy"
    TopologyHeavyProfile => "topology-heavy"
  }
}

///|
pub fn gen_valid_profiles() -> Array[GenValidProfile] {
  [
    NaturalSmallProfile,
    NaturalWideProfile,
    NaturalDeepProfile,
    CoverageForcedPortableProfile,
    CoverageForcedAllFeaturesProfile,
    BinaryenOraclePortableProfile,
    MutationSeedSmallProfile,
    MutationSeedRichProfile,
    PassFuzzStressProfile,
    ValidatorStressProfile,
    NoImportsProfile,
    ImportsHeavyProfile,
    GcHeavyProfile,
    SimdHeavyProfile,
    RelaxedSimdProfile,
    MemoryHeavyProfile,
    ControlHeavyProfile,
    TopologyHeavyProfile,
  ]
}

///|
pub fn gen_valid_profile_names() -> Array[String] {
  gen_valid_profiles().map(gen_valid_profile_name)
}

///|
fn gen_valid_join_profile_names(names : Array[String]) -> String {
  let out = StringBuilder::new()
  for i = 0; i < names.length(); i = i + 1 {
    if i > 0 {
      out.write_string("|")
    }
    out.write_string(names[i])
  }
  out.to_string()
}

///|
fn gen_valid_normalize_profile_name(input : String) -> String {
  let out = StringBuilder::new()
  for c in input {
    if c >= 'A' && c <= 'Z' {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else if c == '_' || c == ' ' {
      out.write_char('-')
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
pub fn gen_valid_profile_by_name(
  name : String,
) -> Result[GenValidProfile, String] {
  let normalized = gen_valid_normalize_profile_name(name.trim().to_owned())
  for profile in gen_valid_profiles() {
    if normalized == gen_valid_profile_name(profile) {
      return Ok(profile)
    }
  }
  match normalized {
    "natural" => Ok(NaturalWideProfile)
    "coverage-forced" => Ok(CoverageForcedAllFeaturesProfile)
    "portable-coverage-forced" => Ok(CoverageForcedPortableProfile)
    "binaryen-oracle-coverage-forced" => Ok(BinaryenOraclePortableProfile)
    _ =>
      Err(
        "unknown gen-valid profile '\{name}'; expected \{gen_valid_join_profile_names(gen_valid_profile_names())}",
      )
  }
}

///|
pub fn GenValidConfig::for_profile(profile : GenValidProfile) -> GenValidConfig {
  match profile {
    NaturalSmallProfile =>
      GenValidConfig::{
        ..GenValidConfig::natural_default(),
        max_type_defs: 4,
        max_imports: 2,
        max_defined_funcs: 2,
        max_tables: 1,
        max_mems: 1,
        max_globals: 2,
        max_tags: 1,
        max_elems: 1,
        max_datas: 1,
        max_params: 1,
        max_locals: 3,
        max_body_statements: 4,
      }
    NaturalWideProfile => GenValidConfig::natural_default()
    NaturalDeepProfile =>
      GenValidConfig::{
        ..GenValidConfig::natural_default(),
        max_defined_funcs: 8,
        max_params: 4,
        max_results: 2,
        max_locals: 8,
        max_body_statements: 16,
        max_body_depth: 4,
      }
    CoverageForcedPortableProfile =>
      GenValidConfig::portable_coverage_forced_default()
    CoverageForcedAllFeaturesProfile =>
      GenValidConfig::coverage_forced_default()
    BinaryenOraclePortableProfile =>
      GenValidConfig::binaryen_oracle_coverage_forced_default()
    MutationSeedSmallProfile =>
      GenValidConfig::{
        ..GenValidConfig::natural_default(),
        max_type_defs: 2,
        max_imports: 1,
        max_defined_funcs: 2,
        max_tables: 1,
        max_mems: 1,
        max_globals: 1,
        max_tags: 1,
        max_elems: 1,
        max_datas: 1,
        max_params: 1,
        max_results: 1,
        max_locals: 1,
        max_body_statements: 3,
        max_body_depth: 1,
      }
    MutationSeedRichProfile =>
      GenValidConfig::{
        ..GenValidConfig::coverage_forced_default(),
        max_type_defs: 6,
        max_tables: 2,
        max_globals: 3,
        max_locals: 4,
      }
    PassFuzzStressProfile =>
      GenValidConfig::binaryen_oracle_coverage_forced_default()
    ValidatorStressProfile =>
      GenValidConfig::{
        ..GenValidConfig::coverage_forced_default(),
        max_type_defs: 6,
        max_defined_funcs: 6,
        max_globals: 4,
        max_params: 3,
        max_results: 2,
        max_locals: 5,
        max_body_statements: 10,
        max_body_depth: 3,
      }
    NoImportsProfile => {
      let base = GenValidConfig::natural_default()
      GenValidConfig::{
        ..base,
        max_imports: 0,
        section_bias: GenValidSectionBias::{
          ..base.section_bias,
          imports_percent: 0,
        },
        features: GenValidFeatureToggles::{
          ..base.features,
          allow_imports: false,
        },
      }
    }
    ImportsHeavyProfile =>
      GenValidConfig::{
        ..GenValidConfig::natural_default(),
        max_imports: 12,
        section_bias: GenValidSectionBias::{
          ..GenValidSectionBias::natural_default(),
          imports_percent: 100,
        },
      }
    GcHeavyProfile =>
      GenValidConfig::{
        ..GenValidConfig::coverage_forced_default(),
        max_type_defs: 24,
        max_defined_funcs: 6,
      }
    SimdHeavyProfile =>
      GenValidConfig::{
        ..GenValidConfig::coverage_forced_default(),
        features: GenValidFeatureToggles::{
          ..GenValidFeatureToggles::coverage_forced_default(),
          allow_v128: true,
        },
      }
    RelaxedSimdProfile =>
      GenValidConfig::{
        ..GenValidConfig::coverage_forced_default(),
        features: GenValidFeatureToggles::{
          ..GenValidFeatureToggles::coverage_forced_default(),
          allow_v128: true,
          allow_relaxed_simd: true,
          allow_typed_body_generator: true,
        },
      }
    MemoryHeavyProfile =>
      GenValidConfig::{
        ..GenValidConfig::coverage_forced_default(),
        max_mems: 4,
        max_datas: 8,
      }
    ControlHeavyProfile =>
      GenValidConfig::{
        ..GenValidConfig::coverage_forced_default(),
        max_body_statements: 16,
        max_body_depth: 4,
        features: GenValidFeatureToggles::{
          ..GenValidFeatureToggles::coverage_forced_default(),
          allow_branch_heavy_control: true,
          allow_tail_calls: true,
          allow_typed_body_generator: true,
        },
      }
    TopologyHeavyProfile =>
      GenValidConfig::{
        ..GenValidConfig::coverage_forced_default(),
        max_type_defs: 24,
        max_imports: 12,
        max_defined_funcs: 18,
        max_tables: 5,
        max_mems: 4,
        max_globals: 8,
        max_tags: 4,
        max_elems: 6,
        max_datas: 6,
      }
  }
}

///|
pub fn GenValidConfig::profile(name : String) -> Result[GenValidConfig, String] {
  match gen_valid_profile_by_name(name) {
    Ok(profile) => Ok(GenValidConfig::for_profile(profile))
    Err(msg) => Err(msg)
  }
}

///|
fn gen_valid_is_topology_heavy_config(config : GenValidConfig) -> Bool {
  config == GenValidConfig::for_profile(TopologyHeavyProfile)
}

///|
pub fn default_gen_valid_config() -> GenValidConfig {
  GenValidConfig::natural_default()
}

///|
pub struct GenValidFeatureFacts {
  mode : GenValidMode
  has_imports : Bool
  has_func_exports : Bool
  has_table_exports : Bool
  has_mem_exports : Bool
  has_global_exports : Bool
  has_tag_exports : Bool
  has_start : Bool
  lacks_start : Bool
  has_tables : Bool
  has_mems : Bool
  has_globals : Bool
  has_tags : Bool
  has_elems : Bool
  has_datas : Bool
  has_data_count : Bool
  uses_ref_types : Bool
  uses_v128 : Bool
  has_call : Bool
  has_call_indirect : Bool
  has_branch_heavy_control : Bool
  has_payload_control_flow : Bool
  has_multivalue_control_flow : Bool
  has_numeric_full_ops : Bool
  has_br_table : Bool
  has_standalone_unreachable : Bool
  has_local_tee : Bool
  has_typed_select : Bool
  has_tail_calls : Bool
  has_scalar_memory_widths : Bool
  has_nonzero_memarg : Bool
  has_memory_limit_variants : Bool
  has_table_limit_variants : Bool
  has_const_expr_variants : Bool
  has_basic_ref_instructions : Bool
  has_i31_extern_conversions : Bool
  has_simd_phase1 : Bool
  has_simd_phase2 : Bool
  has_simd_phase3 : Bool
  has_atomics : Bool
  has_gc_constructors : Bool
  has_gc_accessors : Bool
  has_string_ops : Bool
  has_exception_try_table_matrix : Bool
  has_subtyping_topology : Bool
  has_rich_gc_field_plans : Bool
  has_import_export_topology : Bool
  has_element_segment_range : Bool
  has_data_segment_range : Bool
  has_name_custom_sections : Bool
  has_gc_exception_combo : Bool
  has_gc_tail_call_combo : Bool
  has_shared_memory_atomics : Bool
  has_imports_start_exports : Bool
  exact_opcode_counts : GenValidExactOpcodeCounts
} derive(Eq, Debug)

///|
pub struct GenValidGenerated {
  wasm_module : Module
  config : GenValidConfig
  config_label : String
  attempts : Int
  facts : GenValidFeatureFacts
} derive(Eq, Debug)

///|
pub struct GenValidFailure {
  last_candidate : Module
  config : GenValidConfig
  config_label : String
  attempts : Int
  validation_error_message : String
} derive(Eq, Debug)

///|
pub fn gen_valid_config_label(config : GenValidConfig) -> String {
  if config == GenValidConfig::binaryen_oracle_coverage_forced_default() {
    "binaryen-oracle-coverage-forced"
  } else if config == GenValidConfig::portable_coverage_forced_default() {
    "portable-coverage-forced"
  } else if config == GenValidConfig::coverage_forced_default() {
    "coverage-forced"
  } else if config == GenValidConfig::natural_default() {
    "natural"
  } else {
    for profile in gen_valid_profiles() {
      if config == GenValidConfig::for_profile(profile) {
        return gen_valid_profile_name(profile)
      }
    }
    match config.mode {
      Natural => "custom-natural"
      CoverageForced => "custom-coverage-forced"
    }
  }
}

///|
pub struct GenValidFeatureStats {
  mode : GenValidMode
  modules : Int
  imports : Int
  func_exports : Int
  table_exports : Int
  mem_exports : Int
  global_exports : Int
  tag_exports : Int
  starts : Int
  lacks_start : Int
  tables : Int
  mems : Int
  globals : Int
  tags : Int
  elems : Int
  datas : Int
  data_count : Int
  ref_types : Int
  v128 : Int
  calls : Int
  call_indirect : Int
  branch_heavy_control : Int
  payload_control_flow : Int
  multivalue_control_flow : Int
  numeric_full_ops : Int
  br_table : Int
  standalone_unreachable : Int
  local_tee : Int
  typed_select : Int
  tail_calls : Int
  scalar_memory_widths : Int
  nonzero_memarg : Int
  memory_limit_variants : Int
  table_limit_variants : Int
  const_expr_variants : Int
  basic_ref_instructions : Int
  i31_extern_conversions : Int
  simd_phase1 : Int
  simd_phase2 : Int
  simd_phase3 : Int
  atomics : Int
  gc_constructors : Int
  gc_accessors : Int
  string_ops : Int
  exception_try_table_matrix : Int
  subtyping_topology : Int
  rich_gc_field_plans : Int
  import_export_topology : Int
  element_segment_range : Int
  data_segment_range : Int
  name_custom_sections : Int
  gc_exception_combo : Int
  gc_tail_call_combo : Int
  shared_memory_atomics : Int
  imports_start_exports : Int
  exact_opcode_counts : GenValidExactOpcodeCounts
} derive(Eq, Debug)

///|
pub impl Show for GenValidFeatureStats with output(self, logger) {
  logger.write_string("GenValidFeatureStats {mode: ")
  self.mode.output(logger)
  logger.write_string(", modules: ")
  self.modules.output(logger)
  logger.write_string(", imports: ")
  self.imports.output(logger)
  logger.write_string(", func_exports: ")
  self.func_exports.output(logger)
  logger.write_string(", table_exports: ")
  self.table_exports.output(logger)
  logger.write_string(", mem_exports: ")
  self.mem_exports.output(logger)
  logger.write_string(", global_exports: ")
  self.global_exports.output(logger)
  logger.write_string(", tag_exports: ")
  self.tag_exports.output(logger)
  logger.write_string(", starts: ")
  self.starts.output(logger)
  logger.write_string(", lacks_start: ")
  self.lacks_start.output(logger)
  logger.write_string(", tables: ")
  self.tables.output(logger)
  logger.write_string(", mems: ")
  self.mems.output(logger)
  logger.write_string(", globals: ")
  self.globals.output(logger)
  logger.write_string(", tags: ")
  self.tags.output(logger)
  logger.write_string(", elems: ")
  self.elems.output(logger)
  logger.write_string(", datas: ")
  self.datas.output(logger)
  logger.write_string(", data_count: ")
  self.data_count.output(logger)
  logger.write_string(", ref_types: ")
  self.ref_types.output(logger)
  logger.write_string(", v128: ")
  self.v128.output(logger)
  logger.write_string(", calls: ")
  self.calls.output(logger)
  logger.write_string(", call_indirect: ")
  self.call_indirect.output(logger)
  logger.write_string(", branch_heavy_control: ")
  self.branch_heavy_control.output(logger)
  logger.write_string(", payload_control_flow: ")
  self.payload_control_flow.output(logger)
  logger.write_string(", multivalue_control_flow: ")
  self.multivalue_control_flow.output(logger)
  logger.write_string(", numeric_full_ops: ")
  self.numeric_full_ops.output(logger)
  logger.write_string(", br_table: ")
  self.br_table.output(logger)
  logger.write_string(", standalone_unreachable: ")
  self.standalone_unreachable.output(logger)
  logger.write_string(", local_tee: ")
  self.local_tee.output(logger)
  logger.write_string(", typed_select: ")
  self.typed_select.output(logger)
  logger.write_string(", tail_calls: ")
  self.tail_calls.output(logger)
  logger.write_string(", scalar_memory_widths: ")
  self.scalar_memory_widths.output(logger)
  logger.write_string(", nonzero_memarg: ")
  self.nonzero_memarg.output(logger)
  logger.write_string(", memory_limit_variants: ")
  self.memory_limit_variants.output(logger)
  logger.write_string(", table_limit_variants: ")
  self.table_limit_variants.output(logger)
  logger.write_string(", const_expr_variants: ")
  self.const_expr_variants.output(logger)
  logger.write_string(", basic_ref_instructions: ")
  self.basic_ref_instructions.output(logger)
  logger.write_string(", i31_extern_conversions: ")
  self.i31_extern_conversions.output(logger)
  logger.write_string(", simd_phase1: ")
  self.simd_phase1.output(logger)
  logger.write_string(", simd_phase2: ")
  self.simd_phase2.output(logger)
  logger.write_string(", simd_phase3: ")
  self.simd_phase3.output(logger)
  logger.write_string(", atomics: ")
  self.atomics.output(logger)
  logger.write_string(", gc_constructors: ")
  self.gc_constructors.output(logger)
  logger.write_string(", gc_accessors: ")
  self.gc_accessors.output(logger)
  logger.write_string(", string_ops: ")
  self.string_ops.output(logger)
  logger.write_string(", exception_try_table_matrix: ")
  self.exception_try_table_matrix.output(logger)
  logger.write_string(", subtyping_topology: ")
  self.subtyping_topology.output(logger)
  logger.write_string(", rich_gc_field_plans: ")
  self.rich_gc_field_plans.output(logger)
  logger.write_string(", import_export_topology: ")
  self.import_export_topology.output(logger)
  logger.write_string(", element_segment_range: ")
  self.element_segment_range.output(logger)
  logger.write_string(", data_segment_range: ")
  self.data_segment_range.output(logger)
  logger.write_string(", name_custom_sections: ")
  self.name_custom_sections.output(logger)
  logger.write_string(", gc_exception_combo: ")
  self.gc_exception_combo.output(logger)
  logger.write_string(", gc_tail_call_combo: ")
  self.gc_tail_call_combo.output(logger)
  logger.write_string(", shared_memory_atomics: ")
  self.shared_memory_atomics.output(logger)
  logger.write_string(", imports_start_exports: ")
  self.imports_start_exports.output(logger)
  logger.write_string(", exact_opcode_counts: ")
  self.exact_opcode_counts.output(logger)
  logger.write_char('}')
}

///|
pub fn GenValidFeatureStats::empty(mode : GenValidMode) -> GenValidFeatureStats {
  {
    mode,
    modules: 0,
    imports: 0,
    func_exports: 0,
    table_exports: 0,
    mem_exports: 0,
    global_exports: 0,
    tag_exports: 0,
    starts: 0,
    lacks_start: 0,
    tables: 0,
    mems: 0,
    globals: 0,
    tags: 0,
    elems: 0,
    datas: 0,
    data_count: 0,
    ref_types: 0,
    v128: 0,
    calls: 0,
    call_indirect: 0,
    branch_heavy_control: 0,
    payload_control_flow: 0,
    multivalue_control_flow: 0,
    numeric_full_ops: 0,
    br_table: 0,
    standalone_unreachable: 0,
    local_tee: 0,
    typed_select: 0,
    tail_calls: 0,
    scalar_memory_widths: 0,
    nonzero_memarg: 0,
    memory_limit_variants: 0,
    table_limit_variants: 0,
    const_expr_variants: 0,
    basic_ref_instructions: 0,
    i31_extern_conversions: 0,
    simd_phase1: 0,
    simd_phase2: 0,
    simd_phase3: 0,
    atomics: 0,
    gc_constructors: 0,
    gc_accessors: 0,
    string_ops: 0,
    exception_try_table_matrix: 0,
    subtyping_topology: 0,
    rich_gc_field_plans: 0,
    import_export_topology: 0,
    element_segment_range: 0,
    data_segment_range: 0,
    name_custom_sections: 0,
    gc_exception_combo: 0,
    gc_tail_call_combo: 0,
    shared_memory_atomics: 0,
    imports_start_exports: 0,
    exact_opcode_counts: GenValidExactOpcodeCounts::empty(),
  }
}

///|
pub fn GenValidFeatureStats::record(
  self : GenValidFeatureStats,
  facts : GenValidFeatureFacts,
) -> GenValidFeatureStats {
  GenValidFeatureStats::{
    ..self,
    modules: self.modules + 1,
    imports: self.imports + gen_valid_bool_count(facts.has_imports),
    func_exports: self.func_exports +
    gen_valid_bool_count(facts.has_func_exports),
    table_exports: self.table_exports +
    gen_valid_bool_count(facts.has_table_exports),
    mem_exports: self.mem_exports + gen_valid_bool_count(facts.has_mem_exports),
    global_exports: self.global_exports +
    gen_valid_bool_count(facts.has_global_exports),
    tag_exports: self.tag_exports + gen_valid_bool_count(facts.has_tag_exports),
    starts: self.starts + gen_valid_bool_count(facts.has_start),
    lacks_start: self.lacks_start + gen_valid_bool_count(facts.lacks_start),
    tables: self.tables + gen_valid_bool_count(facts.has_tables),
    mems: self.mems + gen_valid_bool_count(facts.has_mems),
    globals: self.globals + gen_valid_bool_count(facts.has_globals),
    tags: self.tags + gen_valid_bool_count(facts.has_tags),
    elems: self.elems + gen_valid_bool_count(facts.has_elems),
    datas: self.datas + gen_valid_bool_count(facts.has_datas),
    data_count: self.data_count + gen_valid_bool_count(facts.has_data_count),
    ref_types: self.ref_types + gen_valid_bool_count(facts.uses_ref_types),
    v128: self.v128 + gen_valid_bool_count(facts.uses_v128),
    calls: self.calls + gen_valid_bool_count(facts.has_call),
    call_indirect: self.call_indirect +
    gen_valid_bool_count(facts.has_call_indirect),
    branch_heavy_control: self.branch_heavy_control +
    gen_valid_bool_count(facts.has_branch_heavy_control),
    payload_control_flow: self.payload_control_flow +
    gen_valid_bool_count(facts.has_payload_control_flow),
    multivalue_control_flow: self.multivalue_control_flow +
    gen_valid_bool_count(facts.has_multivalue_control_flow),
    numeric_full_ops: self.numeric_full_ops +
    gen_valid_bool_count(facts.has_numeric_full_ops),
    br_table: self.br_table + gen_valid_bool_count(facts.has_br_table),
    standalone_unreachable: self.standalone_unreachable +
    gen_valid_bool_count(facts.has_standalone_unreachable),
    local_tee: self.local_tee + gen_valid_bool_count(facts.has_local_tee),
    typed_select: self.typed_select +
    gen_valid_bool_count(facts.has_typed_select),
    tail_calls: self.tail_calls + gen_valid_bool_count(facts.has_tail_calls),
    scalar_memory_widths: self.scalar_memory_widths +
    gen_valid_bool_count(facts.has_scalar_memory_widths),
    nonzero_memarg: self.nonzero_memarg +
    gen_valid_bool_count(facts.has_nonzero_memarg),
    memory_limit_variants: self.memory_limit_variants +
    gen_valid_bool_count(facts.has_memory_limit_variants),
    table_limit_variants: self.table_limit_variants +
    gen_valid_bool_count(facts.has_table_limit_variants),
    const_expr_variants: self.const_expr_variants +
    gen_valid_bool_count(facts.has_const_expr_variants),
    basic_ref_instructions: self.basic_ref_instructions +
    gen_valid_bool_count(facts.has_basic_ref_instructions),
    i31_extern_conversions: self.i31_extern_conversions +
    gen_valid_bool_count(facts.has_i31_extern_conversions),
    simd_phase1: self.simd_phase1 + gen_valid_bool_count(facts.has_simd_phase1),
    simd_phase2: self.simd_phase2 + gen_valid_bool_count(facts.has_simd_phase2),
    simd_phase3: self.simd_phase3 + gen_valid_bool_count(facts.has_simd_phase3),
    atomics: self.atomics + gen_valid_bool_count(facts.has_atomics),
    gc_constructors: self.gc_constructors +
    gen_valid_bool_count(facts.has_gc_constructors),
    gc_accessors: self.gc_accessors +
    gen_valid_bool_count(facts.has_gc_accessors),
    string_ops: self.string_ops + gen_valid_bool_count(facts.has_string_ops),
    exception_try_table_matrix: self.exception_try_table_matrix +
    gen_valid_bool_count(facts.has_exception_try_table_matrix),
    subtyping_topology: self.subtyping_topology +
    gen_valid_bool_count(facts.has_subtyping_topology),
    rich_gc_field_plans: self.rich_gc_field_plans +
    gen_valid_bool_count(facts.has_rich_gc_field_plans),
    import_export_topology: self.import_export_topology +
    gen_valid_bool_count(facts.has_import_export_topology),
    element_segment_range: self.element_segment_range +
    gen_valid_bool_count(facts.has_element_segment_range),
    data_segment_range: self.data_segment_range +
    gen_valid_bool_count(facts.has_data_segment_range),
    name_custom_sections: self.name_custom_sections +
    gen_valid_bool_count(facts.has_name_custom_sections),
    gc_exception_combo: self.gc_exception_combo +
    gen_valid_bool_count(facts.has_gc_exception_combo),
    gc_tail_call_combo: self.gc_tail_call_combo +
    gen_valid_bool_count(facts.has_gc_tail_call_combo),
    shared_memory_atomics: self.shared_memory_atomics +
    gen_valid_bool_count(facts.has_shared_memory_atomics),
    imports_start_exports: self.imports_start_exports +
    gen_valid_bool_count(facts.has_imports_start_exports),
    exact_opcode_counts: self.exact_opcode_counts.add(facts.exact_opcode_counts),
  }
}

///|
struct GenValidContext {
  rnd : RandomState
  config : GenValidConfig
}

///|
pub struct GenValidExactOpcodeCounts {
  i32_const : Int
  i64_const : Int
  f32_const : Int
  f64_const : Int
  i32_eqz : Int
  i64_eqz : Int
  i32_eq : Int
  i32_ne : Int
  i32_lt_s : Int
  i32_lt_u : Int
  i32_gt_s : Int
  i32_gt_u : Int
  i32_le_s : Int
  i32_le_u : Int
  i32_ge_s : Int
  i32_ge_u : Int
  i64_eq : Int
  i64_ne : Int
  i64_lt_s : Int
  i64_lt_u : Int
  i64_gt_s : Int
  i64_gt_u : Int
  i64_le_s : Int
  i64_le_u : Int
  i64_ge_s : Int
  i64_ge_u : Int
  f32_eq : Int
  f32_ne : Int
  f32_lt : Int
  f32_gt : Int
  f32_le : Int
  f32_ge : Int
  f64_eq : Int
  f64_ne : Int
  f64_lt : Int
  f64_gt : Int
  f64_le : Int
  f64_ge : Int
  i32_clz : Int
  i32_ctz : Int
  i32_popcnt : Int
  i32_add : Int
  i32_sub : Int
  i32_mul : Int
  i32_div_s : Int
  i32_div_u : Int
  i32_rem_s : Int
  i32_rem_u : Int
  i32_and : Int
  i32_or : Int
  i32_xor : Int
  i32_shl : Int
  i32_shr_s : Int
  i32_shr_u : Int
  i32_rotl : Int
  i32_rotr : Int
  i64_clz : Int
  i64_ctz : Int
  i64_popcnt : Int
  i64_add : Int
  i64_sub : Int
  i64_mul : Int
  i64_div_s : Int
  i64_div_u : Int
  i64_rem_s : Int
  i64_rem_u : Int
  i64_and : Int
  i64_or : Int
  i64_xor : Int
  i64_shl : Int
  i64_shr_s : Int
  i64_shr_u : Int
  i64_rotl : Int
  i64_rotr : Int
  f32_abs : Int
  f32_neg : Int
  f32_ceil : Int
  f32_floor : Int
  f32_trunc : Int
  f32_nearest : Int
  f32_sqrt : Int
  f32_add : Int
  f32_sub : Int
  f32_mul : Int
  f32_div : Int
  f32_min : Int
  f32_max : Int
  f32_copysign : Int
  f64_abs : Int
  f64_neg : Int
  f64_ceil : Int
  f64_floor : Int
  f64_trunc : Int
  f64_nearest : Int
  f64_sqrt : Int
  f64_add : Int
  f64_sub : Int
  f64_mul : Int
  f64_div : Int
  f64_min : Int
  f64_max : Int
  f64_copysign : Int
  i32_wrap_i64 : Int
  i32_trunc_f32s : Int
  i32_trunc_f32u : Int
  i32_trunc_f64s : Int
  i32_trunc_f64u : Int
  i64_extend_i32s : Int
  i64_extend_i32u : Int
  i64_trunc_f32s : Int
  i64_trunc_f32u : Int
  i64_trunc_f64s : Int
  i64_trunc_f64u : Int
  f32_convert_i32s : Int
  f32_convert_i32u : Int
  f32_convert_i64s : Int
  f32_convert_i64u : Int
  f32_demote_f64 : Int
  f64_convert_i32s : Int
  f64_convert_i32u : Int
  f64_convert_i64s : Int
  f64_convert_i64u : Int
  f64_promote_f32 : Int
  i32_extend8s : Int
  i32_extend16s : Int
  i64_extend8s : Int
  i64_extend16s : Int
  i64_extend32s : Int
  i32_trunc_sat_f32s : Int
  i32_trunc_sat_f32u : Int
  i32_trunc_sat_f64s : Int
  i32_trunc_sat_f64u : Int
  i64_trunc_sat_f32s : Int
  i64_trunc_sat_f32u : Int
  i64_trunc_sat_f64s : Int
  i64_trunc_sat_f64u : Int
  i32_reinterpret_f32 : Int
  i64_reinterpret_f64 : Int
  f32_reinterpret_i32 : Int
  f64_reinterpret_i64 : Int
  br_table : Int
  unreachable_opcode : Int
  local_tee : Int
  typed_select : Int
  return_call : Int
  return_call_indirect : Int
  return_call_ref : Int
  v128_const : Int
  i8x16_splat : Int
  i16x8_splat : Int
  i32x4_splat : Int
  i64x2_splat : Int
  f32x4_splat : Int
  f64x2_splat : Int
  i8x16_extract_lane_s : Int
  i8x16_extract_lane_u : Int
  i8x16_replace_lane : Int
  i16x8_extract_lane_s : Int
  i16x8_extract_lane_u : Int
  i16x8_replace_lane : Int
  i32x4_extract_lane : Int
  i32x4_replace_lane : Int
  i64x2_extract_lane : Int
  i64x2_replace_lane : Int
  f32x4_extract_lane : Int
  f32x4_replace_lane : Int
  f64x2_extract_lane : Int
  f64x2_replace_lane : Int
  v128_not : Int
  v128_and : Int
  v128_andnot : Int
  v128_or : Int
  v128_xor : Int
  v128_bitselect : Int
  v128_any_true : Int
  i8x16_eq : Int
  i16x8_lt_s : Int
  i32x4_gt_u : Int
  f32x4_lt : Int
  f64x2_ge : Int
  i8x16_all_true : Int
  i16x8_bitmask : Int
  i8x16_add : Int
  i8x16_add_sat_s : Int
  i16x8_mul : Int
  i64x2_ge_s : Int
  i32x4_all_true : Int
  i64x2_bitmask : Int
  i8x16_sub_sat_u : Int
  i8x16_min_s : Int
  i8x16_max_u : Int
  i8x16_avgr_u : Int
  i16x8_add_sat_u : Int
  i16x8_sub_sat_s : Int
  i16x8_min_u : Int
  i16x8_max_s : Int
  i16x8_avgr_u : Int
  i32x4_add : Int
  i32x4_mul : Int
  i32x4_min_s : Int
  i32x4_max_u : Int
  i64x2_add : Int
  i64x2_mul : Int
  f32x4_add : Int
  f32x4_div : Int
  f32x4_min : Int
  f32x4_max : Int
  f64x2_add : Int
  f64x2_div : Int
  f64x2_min : Int
  f64x2_max : Int
  f32x4_ceil : Int
  f32x4_floor : Int
  f32x4_trunc : Int
  f32x4_nearest : Int
  f64x2_ceil : Int
  f64x2_floor : Int
  f64x2_trunc : Int
  f64x2_nearest : Int
  v128_load8x8_s : Int
  v128_load8x8_u : Int
  v128_load16x4_s : Int
  v128_load16x4_u : Int
  v128_load32x2_s : Int
  v128_load32x2_u : Int
  v128_load8_splat : Int
  v128_load16_splat : Int
  v128_load32_splat : Int
  v128_load64_splat : Int
  v128_load8_lane : Int
  v128_load16_lane : Int
  v128_load32_lane : Int
  v128_load64_lane : Int
  v128_store8_lane : Int
  v128_store16_lane : Int
  v128_store32_lane : Int
  v128_store64_lane : Int
  v128_load32_zero : Int
  v128_load64_zero : Int
  i8x16_narrow_i16x8_u : Int
  i16x8_narrow_i32x4_s : Int
  i16x8_narrow_i32x4_u : Int
  i16x8_extadd_pairwise_i8x16_s : Int
  i16x8_extadd_pairwise_i8x16_u : Int
  i32x4_extadd_pairwise_i16x8_s : Int
  i32x4_extadd_pairwise_i16x8_u : Int
  f64x2_promote_low_f32x4 : Int
  v128_load : Int
  v128_store : Int
  i8x16_shuffle : Int
  i8x16_swizzle : Int
  i8x16_narrow_i16x8_s : Int
  i32x4_dot_i16x8_s : Int
  f32x4_demote_f64x2_zero : Int
  i8x16_relaxed_swizzle : Int
  i32x4_relaxed_trunc_f32x4_s : Int
  i32x4_relaxed_trunc_f32x4_u : Int
  i32x4_relaxed_trunc_zero_f64x2_s : Int
  i32x4_relaxed_trunc_zero_f64x2_u : Int
  f32x4_relaxed_madd : Int
  f32x4_relaxed_nmadd : Int
  f64x2_relaxed_madd : Int
  f64x2_relaxed_nmadd : Int
  i8x16_relaxed_laneselect : Int
  i16x8_relaxed_laneselect : Int
  i32x4_relaxed_laneselect : Int
  i64x2_relaxed_laneselect : Int
  f32x4_relaxed_min : Int
  f32x4_relaxed_max : Int
  f64x2_relaxed_min : Int
  f64x2_relaxed_max : Int
  i16x8_relaxed_q15mulr_s : Int
  i16x8_relaxed_dot_i8x16_i7x16_s : Int
  i32x4_relaxed_dot_i8x16_i7x16_add_s : Int
} derive(Eq, Debug)

///|
priv struct GenValidInstrFacts {
  uses_ref_types : Bool
  uses_v128 : Bool
  has_call : Bool
  has_call_indirect : Bool
  has_numeric_full_ops : Bool
  has_br_table : Bool
  has_payload_control_flow : Bool
  has_multivalue_control_flow : Bool
  has_standalone_unreachable : Bool
  has_local_tee : Bool
  has_typed_select : Bool
  has_tail_calls : Bool
  has_scalar_memory_widths : Bool
  has_nonzero_memarg : Bool
  has_memory_limit_variants : Bool
  has_basic_ref_instructions : Bool
  has_i31_extern_conversions : Bool
  has_simd_phase1 : Bool
  has_simd_phase2 : Bool
  has_simd_phase3 : Bool
  has_atomics : Bool
  has_gc_constructors : Bool
  has_gc_accessors : Bool
  has_string_ops : Bool
  has_exception_try_table_matrix : Bool
  has_subtyping_topology : Bool
  has_rich_gc_field_plans : Bool
  has_shared_memories : Bool
  exact_opcode_counts : GenValidExactOpcodeCounts
  control_nodes : Int
  branch_ops : Int
}

///|
fn GenValidContext::new(
  rnd : RandomState,
  config : GenValidConfig,
) -> GenValidContext {
  { rnd, config }
}

///|
pub fn GenValidExactOpcodeCounts::empty() -> GenValidExactOpcodeCounts {
  {
    i32_const: 0,
    i64_const: 0,
    f32_const: 0,
    f64_const: 0,
    i32_eqz: 0,
    i64_eqz: 0,
    i32_eq: 0,
    i32_ne: 0,
    i32_lt_s: 0,
    i32_lt_u: 0,
    i32_gt_s: 0,
    i32_gt_u: 0,
    i32_le_s: 0,
    i32_le_u: 0,
    i32_ge_s: 0,
    i32_ge_u: 0,
    i64_eq: 0,
    i64_ne: 0,
    i64_lt_s: 0,
    i64_lt_u: 0,
    i64_gt_s: 0,
    i64_gt_u: 0,
    i64_le_s: 0,
    i64_le_u: 0,
    i64_ge_s: 0,
    i64_ge_u: 0,
    f32_eq: 0,
    f32_ne: 0,
    f32_lt: 0,
    f32_gt: 0,
    f32_le: 0,
    f32_ge: 0,
    f64_eq: 0,
    f64_ne: 0,
    f64_lt: 0,
    f64_gt: 0,
    f64_le: 0,
    f64_ge: 0,
    i32_clz: 0,
    i32_ctz: 0,
    i32_popcnt: 0,
    i32_add: 0,
    i32_sub: 0,
    i32_mul: 0,
    i32_div_s: 0,
    i32_div_u: 0,
    i32_rem_s: 0,
    i32_rem_u: 0,
    i32_and: 0,
    i32_or: 0,
    i32_xor: 0,
    i32_shl: 0,
    i32_shr_s: 0,
    i32_shr_u: 0,
    i32_rotl: 0,
    i32_rotr: 0,
    i64_clz: 0,
    i64_ctz: 0,
    i64_popcnt: 0,
    i64_add: 0,
    i64_sub: 0,
    i64_mul: 0,
    i64_div_s: 0,
    i64_div_u: 0,
    i64_rem_s: 0,
    i64_rem_u: 0,
    i64_and: 0,
    i64_or: 0,
    i64_xor: 0,
    i64_shl: 0,
    i64_shr_s: 0,
    i64_shr_u: 0,
    i64_rotl: 0,
    i64_rotr: 0,
    f32_abs: 0,
    f32_neg: 0,
    f32_ceil: 0,
    f32_floor: 0,
    f32_trunc: 0,
    f32_nearest: 0,
    f32_sqrt: 0,
    f32_add: 0,
    f32_sub: 0,
    f32_mul: 0,
    f32_div: 0,
    f32_min: 0,
    f32_max: 0,
    f32_copysign: 0,
    f64_abs: 0,
    f64_neg: 0,
    f64_ceil: 0,
    f64_floor: 0,
    f64_trunc: 0,
    f64_nearest: 0,
    f64_sqrt: 0,
    f64_add: 0,
    f64_sub: 0,
    f64_mul: 0,
    f64_div: 0,
    f64_min: 0,
    f64_max: 0,
    f64_copysign: 0,
    i32_wrap_i64: 0,
    i32_trunc_f32s: 0,
    i32_trunc_f32u: 0,
    i32_trunc_f64s: 0,
    i32_trunc_f64u: 0,
    i64_extend_i32s: 0,
    i64_extend_i32u: 0,
    i64_trunc_f32s: 0,
    i64_trunc_f32u: 0,
    i64_trunc_f64s: 0,
    i64_trunc_f64u: 0,
    f32_convert_i32s: 0,
    f32_convert_i32u: 0,
    f32_convert_i64s: 0,
    f32_convert_i64u: 0,
    f32_demote_f64: 0,
    f64_convert_i32s: 0,
    f64_convert_i32u: 0,
    f64_convert_i64s: 0,
    f64_convert_i64u: 0,
    f64_promote_f32: 0,
    i32_extend8s: 0,
    i32_extend16s: 0,
    i64_extend8s: 0,
    i64_extend16s: 0,
    i64_extend32s: 0,
    i32_trunc_sat_f32s: 0,
    i32_trunc_sat_f32u: 0,
    i32_trunc_sat_f64s: 0,
    i32_trunc_sat_f64u: 0,
    i64_trunc_sat_f32s: 0,
    i64_trunc_sat_f32u: 0,
    i64_trunc_sat_f64s: 0,
    i64_trunc_sat_f64u: 0,
    i32_reinterpret_f32: 0,
    i64_reinterpret_f64: 0,
    f32_reinterpret_i32: 0,
    f64_reinterpret_i64: 0,
    br_table: 0,
    unreachable_opcode: 0,
    local_tee: 0,
    typed_select: 0,
    return_call: 0,
    return_call_indirect: 0,
    return_call_ref: 0,
    v128_const: 0,
    i8x16_splat: 0,
    i16x8_splat: 0,
    i32x4_splat: 0,
    i64x2_splat: 0,
    f32x4_splat: 0,
    f64x2_splat: 0,
    i8x16_extract_lane_s: 0,
    i8x16_extract_lane_u: 0,
    i8x16_replace_lane: 0,
    i16x8_extract_lane_s: 0,
    i16x8_extract_lane_u: 0,
    i16x8_replace_lane: 0,
    i32x4_extract_lane: 0,
    i32x4_replace_lane: 0,
    i64x2_extract_lane: 0,
    i64x2_replace_lane: 0,
    f32x4_extract_lane: 0,
    f32x4_replace_lane: 0,
    f64x2_extract_lane: 0,
    f64x2_replace_lane: 0,
    v128_not: 0,
    v128_and: 0,
    v128_andnot: 0,
    v128_or: 0,
    v128_xor: 0,
    v128_bitselect: 0,
    v128_any_true: 0,
    i8x16_eq: 0,
    i16x8_lt_s: 0,
    i32x4_gt_u: 0,
    f32x4_lt: 0,
    f64x2_ge: 0,
    i8x16_all_true: 0,
    i16x8_bitmask: 0,
    i8x16_add: 0,
    i8x16_add_sat_s: 0,
    i16x8_mul: 0,
    i64x2_ge_s: 0,
    i32x4_all_true: 0,
    i64x2_bitmask: 0,
    i8x16_sub_sat_u: 0,
    i8x16_min_s: 0,
    i8x16_max_u: 0,
    i8x16_avgr_u: 0,
    i16x8_add_sat_u: 0,
    i16x8_sub_sat_s: 0,
    i16x8_min_u: 0,
    i16x8_max_s: 0,
    i16x8_avgr_u: 0,
    i32x4_add: 0,
    i32x4_mul: 0,
    i32x4_min_s: 0,
    i32x4_max_u: 0,
    i64x2_add: 0,
    i64x2_mul: 0,
    f32x4_add: 0,
    f32x4_div: 0,
    f32x4_min: 0,
    f32x4_max: 0,
    f64x2_add: 0,
    f64x2_div: 0,
    f64x2_min: 0,
    f64x2_max: 0,
    f32x4_ceil: 0,
    f32x4_floor: 0,
    f32x4_trunc: 0,
    f32x4_nearest: 0,
    f64x2_ceil: 0,
    f64x2_floor: 0,
    f64x2_trunc: 0,
    f64x2_nearest: 0,
    v128_load8x8_s: 0,
    v128_load8x8_u: 0,
    v128_load16x4_s: 0,
    v128_load16x4_u: 0,
    v128_load32x2_s: 0,
    v128_load32x2_u: 0,
    v128_load8_splat: 0,
    v128_load16_splat: 0,
    v128_load32_splat: 0,
    v128_load64_splat: 0,
    v128_load8_lane: 0,
    v128_load16_lane: 0,
    v128_load32_lane: 0,
    v128_load64_lane: 0,
    v128_store8_lane: 0,
    v128_store16_lane: 0,
    v128_store32_lane: 0,
    v128_store64_lane: 0,
    v128_load32_zero: 0,
    v128_load64_zero: 0,
    i8x16_narrow_i16x8_u: 0,
    i16x8_narrow_i32x4_s: 0,
    i16x8_narrow_i32x4_u: 0,
    i16x8_extadd_pairwise_i8x16_s: 0,
    i16x8_extadd_pairwise_i8x16_u: 0,
    i32x4_extadd_pairwise_i16x8_s: 0,
    i32x4_extadd_pairwise_i16x8_u: 0,
    f64x2_promote_low_f32x4: 0,
    v128_load: 0,
    v128_store: 0,
    i8x16_shuffle: 0,
    i8x16_swizzle: 0,
    i8x16_narrow_i16x8_s: 0,
    i32x4_dot_i16x8_s: 0,
    f32x4_demote_f64x2_zero: 0,
    i8x16_relaxed_swizzle: 0,
    i32x4_relaxed_trunc_f32x4_s: 0,
    i32x4_relaxed_trunc_f32x4_u: 0,
    i32x4_relaxed_trunc_zero_f64x2_s: 0,
    i32x4_relaxed_trunc_zero_f64x2_u: 0,
    f32x4_relaxed_madd: 0,
    f32x4_relaxed_nmadd: 0,
    f64x2_relaxed_madd: 0,
    f64x2_relaxed_nmadd: 0,
    i8x16_relaxed_laneselect: 0,
    i16x8_relaxed_laneselect: 0,
    i32x4_relaxed_laneselect: 0,
    i64x2_relaxed_laneselect: 0,
    f32x4_relaxed_min: 0,
    f32x4_relaxed_max: 0,
    f64x2_relaxed_min: 0,
    f64x2_relaxed_max: 0,
    i16x8_relaxed_q15mulr_s: 0,
    i16x8_relaxed_dot_i8x16_i7x16_s: 0,
    i32x4_relaxed_dot_i8x16_i7x16_add_s: 0,
  }
}

///|
pub fn GenValidExactOpcodeCounts::add(
  self : GenValidExactOpcodeCounts,
  other : GenValidExactOpcodeCounts,
) -> GenValidExactOpcodeCounts {
  {
    i32_const: self.i32_const + other.i32_const,
    i64_const: self.i64_const + other.i64_const,
    f32_const: self.f32_const + other.f32_const,
    f64_const: self.f64_const + other.f64_const,
    i32_eqz: self.i32_eqz + other.i32_eqz,
    i64_eqz: self.i64_eqz + other.i64_eqz,
    i32_eq: self.i32_eq + other.i32_eq,
    i32_ne: self.i32_ne + other.i32_ne,
    i32_lt_s: self.i32_lt_s + other.i32_lt_s,
    i32_lt_u: self.i32_lt_u + other.i32_lt_u,
    i32_gt_s: self.i32_gt_s + other.i32_gt_s,
    i32_gt_u: self.i32_gt_u + other.i32_gt_u,
    i32_le_s: self.i32_le_s + other.i32_le_s,
    i32_le_u: self.i32_le_u + other.i32_le_u,
    i32_ge_s: self.i32_ge_s + other.i32_ge_s,
    i32_ge_u: self.i32_ge_u + other.i32_ge_u,
    i64_eq: self.i64_eq + other.i64_eq,
    i64_ne: self.i64_ne + other.i64_ne,
    i64_lt_s: self.i64_lt_s + other.i64_lt_s,
    i64_lt_u: self.i64_lt_u + other.i64_lt_u,
    i64_gt_s: self.i64_gt_s + other.i64_gt_s,
    i64_gt_u: self.i64_gt_u + other.i64_gt_u,
    i64_le_s: self.i64_le_s + other.i64_le_s,
    i64_le_u: self.i64_le_u + other.i64_le_u,
    i64_ge_s: self.i64_ge_s + other.i64_ge_s,
    i64_ge_u: self.i64_ge_u + other.i64_ge_u,
    f32_eq: self.f32_eq + other.f32_eq,
    f32_ne: self.f32_ne + other.f32_ne,
    f32_lt: self.f32_lt + other.f32_lt,
    f32_gt: self.f32_gt + other.f32_gt,
    f32_le: self.f32_le + other.f32_le,
    f32_ge: self.f32_ge + other.f32_ge,
    f64_eq: self.f64_eq + other.f64_eq,
    f64_ne: self.f64_ne + other.f64_ne,
    f64_lt: self.f64_lt + other.f64_lt,
    f64_gt: self.f64_gt + other.f64_gt,
    f64_le: self.f64_le + other.f64_le,
    f64_ge: self.f64_ge + other.f64_ge,
    i32_clz: self.i32_clz + other.i32_clz,
    i32_ctz: self.i32_ctz + other.i32_ctz,
    i32_popcnt: self.i32_popcnt + other.i32_popcnt,
    i32_add: self.i32_add + other.i32_add,
    i32_sub: self.i32_sub + other.i32_sub,
    i32_mul: self.i32_mul + other.i32_mul,
    i32_div_s: self.i32_div_s + other.i32_div_s,
    i32_div_u: self.i32_div_u + other.i32_div_u,
    i32_rem_s: self.i32_rem_s + other.i32_rem_s,
    i32_rem_u: self.i32_rem_u + other.i32_rem_u,
    i32_and: self.i32_and + other.i32_and,
    i32_or: self.i32_or + other.i32_or,
    i32_xor: self.i32_xor + other.i32_xor,
    i32_shl: self.i32_shl + other.i32_shl,
    i32_shr_s: self.i32_shr_s + other.i32_shr_s,
    i32_shr_u: self.i32_shr_u + other.i32_shr_u,
    i32_rotl: self.i32_rotl + other.i32_rotl,
    i32_rotr: self.i32_rotr + other.i32_rotr,
    i64_clz: self.i64_clz + other.i64_clz,
    i64_ctz: self.i64_ctz + other.i64_ctz,
    i64_popcnt: self.i64_popcnt + other.i64_popcnt,
    i64_add: self.i64_add + other.i64_add,
    i64_sub: self.i64_sub + other.i64_sub,
    i64_mul: self.i64_mul + other.i64_mul,
    i64_div_s: self.i64_div_s + other.i64_div_s,
    i64_div_u: self.i64_div_u + other.i64_div_u,
    i64_rem_s: self.i64_rem_s + other.i64_rem_s,
    i64_rem_u: self.i64_rem_u + other.i64_rem_u,
    i64_and: self.i64_and + other.i64_and,
    i64_or: self.i64_or + other.i64_or,
    i64_xor: self.i64_xor + other.i64_xor,
    i64_shl: self.i64_shl + other.i64_shl,
    i64_shr_s: self.i64_shr_s + other.i64_shr_s,
    i64_shr_u: self.i64_shr_u + other.i64_shr_u,
    i64_rotl: self.i64_rotl + other.i64_rotl,
    i64_rotr: self.i64_rotr + other.i64_rotr,
    f32_abs: self.f32_abs + other.f32_abs,
    f32_neg: self.f32_neg + other.f32_neg,
    f32_ceil: self.f32_ceil + other.f32_ceil,
    f32_floor: self.f32_floor + other.f32_floor,
    f32_trunc: self.f32_trunc + other.f32_trunc,
    f32_nearest: self.f32_nearest + other.f32_nearest,
    f32_sqrt: self.f32_sqrt + other.f32_sqrt,
    f32_add: self.f32_add + other.f32_add,
    f32_sub: self.f32_sub + other.f32_sub,
    f32_mul: self.f32_mul + other.f32_mul,
    f32_div: self.f32_div + other.f32_div,
    f32_min: self.f32_min + other.f32_min,
    f32_max: self.f32_max + other.f32_max,
    f32_copysign: self.f32_copysign + other.f32_copysign,
    f64_abs: self.f64_abs + other.f64_abs,
    f64_neg: self.f64_neg + other.f64_neg,
    f64_ceil: self.f64_ceil + other.f64_ceil,
    f64_floor: self.f64_floor + other.f64_floor,
    f64_trunc: self.f64_trunc + other.f64_trunc,
    f64_nearest: self.f64_nearest + other.f64_nearest,
    f64_sqrt: self.f64_sqrt + other.f64_sqrt,
    f64_add: self.f64_add + other.f64_add,
    f64_sub: self.f64_sub + other.f64_sub,
    f64_mul: self.f64_mul + other.f64_mul,
    f64_div: self.f64_div + other.f64_div,
    f64_min: self.f64_min + other.f64_min,
    f64_max: self.f64_max + other.f64_max,
    f64_copysign: self.f64_copysign + other.f64_copysign,
    i32_wrap_i64: self.i32_wrap_i64 + other.i32_wrap_i64,
    i32_trunc_f32s: self.i32_trunc_f32s + other.i32_trunc_f32s,
    i32_trunc_f32u: self.i32_trunc_f32u + other.i32_trunc_f32u,
    i32_trunc_f64s: self.i32_trunc_f64s + other.i32_trunc_f64s,
    i32_trunc_f64u: self.i32_trunc_f64u + other.i32_trunc_f64u,
    i64_extend_i32s: self.i64_extend_i32s + other.i64_extend_i32s,
    i64_extend_i32u: self.i64_extend_i32u + other.i64_extend_i32u,
    i64_trunc_f32s: self.i64_trunc_f32s + other.i64_trunc_f32s,
    i64_trunc_f32u: self.i64_trunc_f32u + other.i64_trunc_f32u,
    i64_trunc_f64s: self.i64_trunc_f64s + other.i64_trunc_f64s,
    i64_trunc_f64u: self.i64_trunc_f64u + other.i64_trunc_f64u,
    f32_convert_i32s: self.f32_convert_i32s + other.f32_convert_i32s,
    f32_convert_i32u: self.f32_convert_i32u + other.f32_convert_i32u,
    f32_convert_i64s: self.f32_convert_i64s + other.f32_convert_i64s,
    f32_convert_i64u: self.f32_convert_i64u + other.f32_convert_i64u,
    f32_demote_f64: self.f32_demote_f64 + other.f32_demote_f64,
    f64_convert_i32s: self.f64_convert_i32s + other.f64_convert_i32s,
    f64_convert_i32u: self.f64_convert_i32u + other.f64_convert_i32u,
    f64_convert_i64s: self.f64_convert_i64s + other.f64_convert_i64s,
    f64_convert_i64u: self.f64_convert_i64u + other.f64_convert_i64u,
    f64_promote_f32: self.f64_promote_f32 + other.f64_promote_f32,
    i32_extend8s: self.i32_extend8s + other.i32_extend8s,
    i32_extend16s: self.i32_extend16s + other.i32_extend16s,
    i64_extend8s: self.i64_extend8s + other.i64_extend8s,
    i64_extend16s: self.i64_extend16s + other.i64_extend16s,
    i64_extend32s: self.i64_extend32s + other.i64_extend32s,
    i32_trunc_sat_f32s: self.i32_trunc_sat_f32s + other.i32_trunc_sat_f32s,
    i32_trunc_sat_f32u: self.i32_trunc_sat_f32u + other.i32_trunc_sat_f32u,
    i32_trunc_sat_f64s: self.i32_trunc_sat_f64s + other.i32_trunc_sat_f64s,
    i32_trunc_sat_f64u: self.i32_trunc_sat_f64u + other.i32_trunc_sat_f64u,
    i64_trunc_sat_f32s: self.i64_trunc_sat_f32s + other.i64_trunc_sat_f32s,
    i64_trunc_sat_f32u: self.i64_trunc_sat_f32u + other.i64_trunc_sat_f32u,
    i64_trunc_sat_f64s: self.i64_trunc_sat_f64s + other.i64_trunc_sat_f64s,
    i64_trunc_sat_f64u: self.i64_trunc_sat_f64u + other.i64_trunc_sat_f64u,
    i32_reinterpret_f32: self.i32_reinterpret_f32 + other.i32_reinterpret_f32,
    i64_reinterpret_f64: self.i64_reinterpret_f64 + other.i64_reinterpret_f64,
    f32_reinterpret_i32: self.f32_reinterpret_i32 + other.f32_reinterpret_i32,
    f64_reinterpret_i64: self.f64_reinterpret_i64 + other.f64_reinterpret_i64,
    br_table: self.br_table + other.br_table,
    unreachable_opcode: self.unreachable_opcode + other.unreachable_opcode,
    local_tee: self.local_tee + other.local_tee,
    typed_select: self.typed_select + other.typed_select,
    return_call: self.return_call + other.return_call,
    return_call_indirect: self.return_call_indirect + other.return_call_indirect,
    return_call_ref: self.return_call_ref + other.return_call_ref,
    v128_const: self.v128_const + other.v128_const,
    i8x16_splat: self.i8x16_splat + other.i8x16_splat,
    i16x8_splat: self.i16x8_splat + other.i16x8_splat,
    i32x4_splat: self.i32x4_splat + other.i32x4_splat,
    i64x2_splat: self.i64x2_splat + other.i64x2_splat,
    f32x4_splat: self.f32x4_splat + other.f32x4_splat,
    f64x2_splat: self.f64x2_splat + other.f64x2_splat,
    i8x16_extract_lane_s: self.i8x16_extract_lane_s + other.i8x16_extract_lane_s,
    i8x16_extract_lane_u: self.i8x16_extract_lane_u + other.i8x16_extract_lane_u,
    i8x16_replace_lane: self.i8x16_replace_lane + other.i8x16_replace_lane,
    i16x8_extract_lane_s: self.i16x8_extract_lane_s + other.i16x8_extract_lane_s,
    i16x8_extract_lane_u: self.i16x8_extract_lane_u + other.i16x8_extract_lane_u,
    i16x8_replace_lane: self.i16x8_replace_lane + other.i16x8_replace_lane,
    i32x4_extract_lane: self.i32x4_extract_lane + other.i32x4_extract_lane,
    i32x4_replace_lane: self.i32x4_replace_lane + other.i32x4_replace_lane,
    i64x2_extract_lane: self.i64x2_extract_lane + other.i64x2_extract_lane,
    i64x2_replace_lane: self.i64x2_replace_lane + other.i64x2_replace_lane,
    f32x4_extract_lane: self.f32x4_extract_lane + other.f32x4_extract_lane,
    f32x4_replace_lane: self.f32x4_replace_lane + other.f32x4_replace_lane,
    f64x2_extract_lane: self.f64x2_extract_lane + other.f64x2_extract_lane,
    f64x2_replace_lane: self.f64x2_replace_lane + other.f64x2_replace_lane,
    v128_not: self.v128_not + other.v128_not,
    v128_and: self.v128_and + other.v128_and,
    v128_andnot: self.v128_andnot + other.v128_andnot,
    v128_or: self.v128_or + other.v128_or,
    v128_xor: self.v128_xor + other.v128_xor,
    v128_bitselect: self.v128_bitselect + other.v128_bitselect,
    v128_any_true: self.v128_any_true + other.v128_any_true,
    i8x16_eq: self.i8x16_eq + other.i8x16_eq,
    i16x8_lt_s: self.i16x8_lt_s + other.i16x8_lt_s,
    i32x4_gt_u: self.i32x4_gt_u + other.i32x4_gt_u,
    f32x4_lt: self.f32x4_lt + other.f32x4_lt,
    f64x2_ge: self.f64x2_ge + other.f64x2_ge,
    i8x16_all_true: self.i8x16_all_true + other.i8x16_all_true,
    i16x8_bitmask: self.i16x8_bitmask + other.i16x8_bitmask,
    i8x16_add: self.i8x16_add + other.i8x16_add,
    i8x16_add_sat_s: self.i8x16_add_sat_s + other.i8x16_add_sat_s,
    i16x8_mul: self.i16x8_mul + other.i16x8_mul,
    i64x2_ge_s: self.i64x2_ge_s + other.i64x2_ge_s,
    i32x4_all_true: self.i32x4_all_true + other.i32x4_all_true,
    i64x2_bitmask: self.i64x2_bitmask + other.i64x2_bitmask,
    i8x16_sub_sat_u: self.i8x16_sub_sat_u + other.i8x16_sub_sat_u,
    i8x16_min_s: self.i8x16_min_s + other.i8x16_min_s,
    i8x16_max_u: self.i8x16_max_u + other.i8x16_max_u,
    i8x16_avgr_u: self.i8x16_avgr_u + other.i8x16_avgr_u,
    i16x8_add_sat_u: self.i16x8_add_sat_u + other.i16x8_add_sat_u,
    i16x8_sub_sat_s: self.i16x8_sub_sat_s + other.i16x8_sub_sat_s,
    i16x8_min_u: self.i16x8_min_u + other.i16x8_min_u,
    i16x8_max_s: self.i16x8_max_s + other.i16x8_max_s,
    i16x8_avgr_u: self.i16x8_avgr_u + other.i16x8_avgr_u,
    i32x4_add: self.i32x4_add + other.i32x4_add,
    i32x4_mul: self.i32x4_mul + other.i32x4_mul,
    i32x4_min_s: self.i32x4_min_s + other.i32x4_min_s,
    i32x4_max_u: self.i32x4_max_u + other.i32x4_max_u,
    i64x2_add: self.i64x2_add + other.i64x2_add,
    i64x2_mul: self.i64x2_mul + other.i64x2_mul,
    f32x4_add: self.f32x4_add + other.f32x4_add,
    f32x4_div: self.f32x4_div + other.f32x4_div,
    f32x4_min: self.f32x4_min + other.f32x4_min,
    f32x4_max: self.f32x4_max + other.f32x4_max,
    f64x2_add: self.f64x2_add + other.f64x2_add,
    f64x2_div: self.f64x2_div + other.f64x2_div,
    f64x2_min: self.f64x2_min + other.f64x2_min,
    f64x2_max: self.f64x2_max + other.f64x2_max,
    f32x4_ceil: self.f32x4_ceil + other.f32x4_ceil,
    f32x4_floor: self.f32x4_floor + other.f32x4_floor,
    f32x4_trunc: self.f32x4_trunc + other.f32x4_trunc,
    f32x4_nearest: self.f32x4_nearest + other.f32x4_nearest,
    f64x2_ceil: self.f64x2_ceil + other.f64x2_ceil,
    f64x2_floor: self.f64x2_floor + other.f64x2_floor,
    f64x2_trunc: self.f64x2_trunc + other.f64x2_trunc,
    f64x2_nearest: self.f64x2_nearest + other.f64x2_nearest,
    v128_load8x8_s: self.v128_load8x8_s + other.v128_load8x8_s,
    v128_load8x8_u: self.v128_load8x8_u + other.v128_load8x8_u,
    v128_load16x4_s: self.v128_load16x4_s + other.v128_load16x4_s,
    v128_load16x4_u: self.v128_load16x4_u + other.v128_load16x4_u,
    v128_load32x2_s: self.v128_load32x2_s + other.v128_load32x2_s,
    v128_load32x2_u: self.v128_load32x2_u + other.v128_load32x2_u,
    v128_load8_splat: self.v128_load8_splat + other.v128_load8_splat,
    v128_load16_splat: self.v128_load16_splat + other.v128_load16_splat,
    v128_load32_splat: self.v128_load32_splat + other.v128_load32_splat,
    v128_load64_splat: self.v128_load64_splat + other.v128_load64_splat,
    v128_load8_lane: self.v128_load8_lane + other.v128_load8_lane,
    v128_load16_lane: self.v128_load16_lane + other.v128_load16_lane,
    v128_load32_lane: self.v128_load32_lane + other.v128_load32_lane,
    v128_load64_lane: self.v128_load64_lane + other.v128_load64_lane,
    v128_store8_lane: self.v128_store8_lane + other.v128_store8_lane,
    v128_store16_lane: self.v128_store16_lane + other.v128_store16_lane,
    v128_store32_lane: self.v128_store32_lane + other.v128_store32_lane,
    v128_store64_lane: self.v128_store64_lane + other.v128_store64_lane,
    v128_load32_zero: self.v128_load32_zero + other.v128_load32_zero,
    v128_load64_zero: self.v128_load64_zero + other.v128_load64_zero,
    i8x16_narrow_i16x8_u: self.i8x16_narrow_i16x8_u + other.i8x16_narrow_i16x8_u,
    i16x8_narrow_i32x4_s: self.i16x8_narrow_i32x4_s + other.i16x8_narrow_i32x4_s,
    i16x8_narrow_i32x4_u: self.i16x8_narrow_i32x4_u + other.i16x8_narrow_i32x4_u,
    i16x8_extadd_pairwise_i8x16_s: self.i16x8_extadd_pairwise_i8x16_s +
    other.i16x8_extadd_pairwise_i8x16_s,
    i16x8_extadd_pairwise_i8x16_u: self.i16x8_extadd_pairwise_i8x16_u +
    other.i16x8_extadd_pairwise_i8x16_u,
    i32x4_extadd_pairwise_i16x8_s: self.i32x4_extadd_pairwise_i16x8_s +
    other.i32x4_extadd_pairwise_i16x8_s,
    i32x4_extadd_pairwise_i16x8_u: self.i32x4_extadd_pairwise_i16x8_u +
    other.i32x4_extadd_pairwise_i16x8_u,
    f64x2_promote_low_f32x4: self.f64x2_promote_low_f32x4 +
    other.f64x2_promote_low_f32x4,
    v128_load: self.v128_load + other.v128_load,
    v128_store: self.v128_store + other.v128_store,
    i8x16_shuffle: self.i8x16_shuffle + other.i8x16_shuffle,
    i8x16_swizzle: self.i8x16_swizzle + other.i8x16_swizzle,
    i8x16_narrow_i16x8_s: self.i8x16_narrow_i16x8_s + other.i8x16_narrow_i16x8_s,
    i32x4_dot_i16x8_s: self.i32x4_dot_i16x8_s + other.i32x4_dot_i16x8_s,
    f32x4_demote_f64x2_zero: self.f32x4_demote_f64x2_zero +
    other.f32x4_demote_f64x2_zero,
    i8x16_relaxed_swizzle: self.i8x16_relaxed_swizzle +
    other.i8x16_relaxed_swizzle,
    i32x4_relaxed_trunc_f32x4_s: self.i32x4_relaxed_trunc_f32x4_s +
    other.i32x4_relaxed_trunc_f32x4_s,
    i32x4_relaxed_trunc_f32x4_u: self.i32x4_relaxed_trunc_f32x4_u +
    other.i32x4_relaxed_trunc_f32x4_u,
    i32x4_relaxed_trunc_zero_f64x2_s: self.i32x4_relaxed_trunc_zero_f64x2_s +
    other.i32x4_relaxed_trunc_zero_f64x2_s,
    i32x4_relaxed_trunc_zero_f64x2_u: self.i32x4_relaxed_trunc_zero_f64x2_u +
    other.i32x4_relaxed_trunc_zero_f64x2_u,
    f32x4_relaxed_madd: self.f32x4_relaxed_madd + other.f32x4_relaxed_madd,
    f32x4_relaxed_nmadd: self.f32x4_relaxed_nmadd + other.f32x4_relaxed_nmadd,
    f64x2_relaxed_madd: self.f64x2_relaxed_madd + other.f64x2_relaxed_madd,
    f64x2_relaxed_nmadd: self.f64x2_relaxed_nmadd + other.f64x2_relaxed_nmadd,
    i8x16_relaxed_laneselect: self.i8x16_relaxed_laneselect +
    other.i8x16_relaxed_laneselect,
    i16x8_relaxed_laneselect: self.i16x8_relaxed_laneselect +
    other.i16x8_relaxed_laneselect,
    i32x4_relaxed_laneselect: self.i32x4_relaxed_laneselect +
    other.i32x4_relaxed_laneselect,
    i64x2_relaxed_laneselect: self.i64x2_relaxed_laneselect +
    other.i64x2_relaxed_laneselect,
    f32x4_relaxed_min: self.f32x4_relaxed_min + other.f32x4_relaxed_min,
    f32x4_relaxed_max: self.f32x4_relaxed_max + other.f32x4_relaxed_max,
    f64x2_relaxed_min: self.f64x2_relaxed_min + other.f64x2_relaxed_min,
    f64x2_relaxed_max: self.f64x2_relaxed_max + other.f64x2_relaxed_max,
    i16x8_relaxed_q15mulr_s: self.i16x8_relaxed_q15mulr_s +
    other.i16x8_relaxed_q15mulr_s,
    i16x8_relaxed_dot_i8x16_i7x16_s: self.i16x8_relaxed_dot_i8x16_i7x16_s +
    other.i16x8_relaxed_dot_i8x16_i7x16_s,
    i32x4_relaxed_dot_i8x16_i7x16_add_s: self.i32x4_relaxed_dot_i8x16_i7x16_add_s +
    other.i32x4_relaxed_dot_i8x16_i7x16_add_s,
  }
}

///|
pub impl Show for GenValidExactOpcodeCounts with output(self, logger) {
  logger.write_string("GenValidExactOpcodeCounts {i32_const: ")
  self.i32_const.output(logger)
  logger.write_string(", i64_const: ")
  self.i64_const.output(logger)
  logger.write_string(", f32_const: ")
  self.f32_const.output(logger)
  logger.write_string(", f64_const: ")
  self.f64_const.output(logger)
  logger.write_string(", i32_add: ")
  self.i32_add.output(logger)
  logger.write_string(", i64_add: ")
  self.i64_add.output(logger)
  logger.write_string(", f32_add: ")
  self.f32_add.output(logger)
  logger.write_string(", f64_add: ")
  self.f64_add.output(logger)
  logger.write_string(", br_table: ")
  self.br_table.output(logger)
  logger.write_string(", unreachable_opcode: ")
  self.unreachable_opcode.output(logger)
  logger.write_string(", local_tee: ")
  self.local_tee.output(logger)
  logger.write_string(", typed_select: ")
  self.typed_select.output(logger)
  logger.write_string(", return_call: ")
  self.return_call.output(logger)
  logger.write_string(", return_call_indirect: ")
  self.return_call_indirect.output(logger)
  logger.write_string(", return_call_ref: ")
  self.return_call_ref.output(logger)
  logger.write_string(", v128_const: ")
  self.v128_const.output(logger)
  logger.write_string(", i8x16_splat: ")
  self.i8x16_splat.output(logger)
  logger.write_string(", i8x16_add: ")
  self.i8x16_add.output(logger)
  logger.write_string(", v128_load: ")
  self.v128_load.output(logger)
  logger.write_char('}')
}

///|
fn gen_valid_exact_opcode_counts_nonzero(
  counts : GenValidExactOpcodeCounts,
) -> Bool {
  counts != GenValidExactOpcodeCounts::empty()
}

///|
fn GenValidInstrFacts::empty() -> GenValidInstrFacts {
  {
    uses_ref_types: false,
    uses_v128: false,
    has_call: false,
    has_call_indirect: false,
    has_numeric_full_ops: false,
    has_br_table: false,
    has_payload_control_flow: false,
    has_multivalue_control_flow: false,
    has_standalone_unreachable: false,
    has_local_tee: false,
    has_typed_select: false,
    has_tail_calls: false,
    has_scalar_memory_widths: false,
    has_nonzero_memarg: false,
    has_memory_limit_variants: false,
    has_basic_ref_instructions: false,
    has_i31_extern_conversions: false,
    has_simd_phase1: false,
    has_simd_phase2: false,
    has_simd_phase3: false,
    has_atomics: false,
    has_gc_constructors: false,
    has_gc_accessors: false,
    has_string_ops: false,
    has_exception_try_table_matrix: false,
    has_subtyping_topology: false,
    has_rich_gc_field_plans: false,
    has_shared_memories: false,
    exact_opcode_counts: GenValidExactOpcodeCounts::empty(),
    control_nodes: 0,
    branch_ops: 0,
  }
}

///|
fn gen_valid_bool_count(flag : Bool) -> Int {
  if flag {
    1
  } else {
    0
  }
}

///|
fn gen_valid_clamp_non_negative(value : Int) -> Int {
  if value < 0 {
    0
  } else {
    value
  }
}

///|
fn gen_valid_min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn gen_valid_roll_percent(ctx : GenValidContext, percent : Int) -> Bool {
  let bounded = if percent < 0 {
    0
  } else if percent > 100 {
    100
  } else {
    percent
  }
  if bounded <= 0 {
    false
  } else if bounded >= 100 {
    true
  } else {
    ctx.random_int(100) < bounded
  }
}

///|
fn GenValidContext::random_int(self : GenValidContext, max : Int) -> Int {
  if max <= 0 {
    0
  } else {
    (self.rnd.next_int().reinterpret_as_uint() % max.reinterpret_as_uint()).reinterpret_as_int()
  }
}

///|
fn GenValidContext::random_bool(self : GenValidContext) -> Bool {
  self.random_int(2) == 0
}

///|
fn gen_valid_ref_valtype_pool(
  extra_ref_types : Array[ValType],
) -> Array[ValType] {
  let refs : Array[ValType] = [
    ValType::funcref(),
    ValType::externref(),
    ValType::stringref(),
    ValType::ref_null_exn(),
    ValType::ref_type(RefType::abs(AbsHeapType::any())),
    ValType::ref_type(RefType::abs(AbsHeapType::eq())),
    ValType::ref_type(RefType::abs(AbsHeapType::i31())),
    ValType::ref_type(RefType::abs(AbsHeapType::struct_())),
    ValType::ref_type(RefType::abs(AbsHeapType::array())),
  ]
  for vt in extra_ref_types {
    refs.push(vt)
  }
  refs
}

///|
pub fn gen_valid_valtype_with_extra_refs(
  ctx : GenValidContext,
  extra_ref_types : Array[ValType],
) -> ValType {
  let scalar_choice_count = 4 +
    gen_valid_bool_count(ctx.config.features.allow_v128)
  let ref_pool = if ctx.config.features.allow_ref_types {
    gen_valid_ref_valtype_pool(extra_ref_types)
  } else {
    []
  }
  let choice = ctx.random_int(scalar_choice_count + ref_pool.length())
  if choice == 0 {
    ValType::i32()
  } else if choice == 1 {
    ValType::i64()
  } else if choice == 2 {
    ValType::f32()
  } else if choice == 3 {
    ValType::f64()
  } else if ctx.config.features.allow_v128 && choice == 4 {
    ValType::v128()
  } else if ref_pool.is_empty() {
    ValType::i32()
  } else {
    ref_pool[choice - scalar_choice_count]
  }
}

///|
pub fn gen_valid_valtype(ctx : GenValidContext) -> ValType {
  gen_valid_valtype_with_extra_refs(ctx, [])
}

///|
pub fn gen_valid_numtype(ctx : GenValidContext) -> NumType {
  match ctx.random_int(4) {
    0 => NumType::i32()
    1 => NumType::i64()
    2 => NumType::f32()
    _ => NumType::f64()
  }
}

///|
fn gen_const_expr(ctx : GenValidContext, vt : ValType) -> Expr {
  Expr::new([gen_const_instr(ctx, vt)])
}

///|
fn gen_const_instr(ctx : GenValidContext, vt : ValType) -> Instruction {
  match vt {
    NumTypeValType(I32NumType) =>
      Instruction::i32_const(I32(ctx.random_int(1000)))
    NumTypeValType(I64NumType) =>
      Instruction::i64_const(I64(ctx.random_int(1000).to_int64()))
    NumTypeValType(F32NumType) =>
      Instruction::f32_const(
        F32(Float::from_double(ctx.random_int(100).to_double())),
      )
    NumTypeValType(F64NumType) =>
      Instruction::f64_const(F64(ctx.random_int(100).to_double()))
    VecTypeValType =>
      Instruction::v128_const(
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      )
    _ if vt == ValType::stringref() => Instruction::string_const(b"gen-valid")
    RefTypeValType(rt) =>
      if rt.is_exact() {
        Instruction::ref_null_type(rt)
      } else {
        Instruction::ref_null(rt.get_heap_type())
      }
    BotValType => Instruction::unreachable_()
  }
}

///|
fn gen_result_types(
  ctx : GenValidContext,
  extra_ref_types? : Array[ValType] = [],
) -> Array[ValType] {
  let max_results = gen_valid_clamp_non_negative(ctx.config.max_results)
  if max_results <= 0 || ctx.random_bool() {
    []
  } else {
    let result_count = 1 + ctx.random_int(max_results)
    let results : Array[ValType] = []
    for i = 0; i < result_count; i = i + 1 {
      if i == 0 &&
        !extra_ref_types.is_empty() &&
        (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0) {
        results.push(extra_ref_types[ctx.random_int(extra_ref_types.length())])
      } else {
        results.push(gen_valid_valtype_with_extra_refs(ctx, extra_ref_types))
      }
    }
    results
  }
}

///|
fn gen_param_types(ctx : GenValidContext) -> Array[ValType] {
  let count = ctx.random_int(
    gen_valid_clamp_non_negative(ctx.config.max_params) + 1,
  )
  let params : Array[ValType] = []
  for _ in 0..<count {
    params.push(gen_valid_valtype(ctx))
  }
  params
}

///|
fn gen_local_types(
  ctx : GenValidContext,
  extra_ref_types? : Array[ValType] = [],
) -> Array[ValType] {
  let count = ctx.random_int(
    gen_valid_clamp_non_negative(ctx.config.max_locals) + 1,
  )
  let locals : Array[ValType] = []
  for i = 0; i < count; i = i + 1 {
    if i == 0 && !extra_ref_types.is_empty() && ctx.random_int(4) == 0 {
      locals.push(extra_ref_types[ctx.random_int(extra_ref_types.length())])
    } else {
      locals.push(gen_valid_valtype_with_extra_refs(ctx, extra_ref_types))
    }
  }
  locals
}

///|
fn gen_all_local_types(
  params : Array[ValType],
  locals : Array[ValType],
) -> Array[ValType] {
  let out = params.copy()
  for local_ty in locals {
    out.push(local_ty)
  }
  out
}

///|
fn gen_valid_gc_type_plan_empty() -> GenValidGcTypePlan {
  {
    struct_type_idxs: [],
    array_type_idxs: [],
    concrete_ref_types: [],
    exact_ref_types: [],
    bulk_data_array_idx: None,
    bulk_elem_array_idx: None,
    bulk_elem_ref_type: None,
    packed_struct_idx: None,
    packed_i8_array_idx: None,
    packed_i16_array_idx: None,
    descriptor_struct_idx: None,
    descriptor_type_idx: None,
    string_wtf16_array_idx: None,
    string_utf8_array_idx: None,
    rec_group_count: 0,
  }
}

///|
fn gen_valid_gc_type_field_ref(type_idx : TypeIdx) -> ValType {
  ValType::ref_type(RefType::new(true, HeapType::new(type_idx)))
}

///|
fn gen_valid_gc_type_exact_ref(type_idx : TypeIdx) -> ValType {
  ValType::ref_type(RefType::new(true, HeapType::new(type_idx), exact=true))
}

///|
fn gen_valid_gc_type_defs(
  ctx : GenValidContext,
  next_type_idx : Int,
  remaining_type_budget : Int,
) -> (Array[RecType], GenValidGcTypePlan) {
  if !ctx.config.features.allow_ref_types || remaining_type_budget <= 0 {
    return ([], gen_valid_gc_type_plan_empty())
  }
  if ctx.config.mode != CoverageForced && ctx.random_int(3) != 0 {
    return ([], gen_valid_gc_type_plan_empty())
  }

  let defs : Array[RecType] = []
  let mut plan = gen_valid_gc_type_plan_empty()
  plan.concrete_ref_types.push(ValType::stringref())
  plan.concrete_ref_types.push(ValType::ref_null_exn())
  let mut type_idx_cursor = next_type_idx

  let want_struct = ctx.config.mode == CoverageForced || ctx.random_int(4) != 0
  let want_array = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) != 0)
  let want_packed_struct = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0)
  let want_packed_i8_array = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0)
  let want_packed_i16_array = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0)
  let want_descriptor_group = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0)
  let want_elem_array = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0)
  let want_string_wtf16_array = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_bool())
  let want_string_utf8_array = remaining_type_budget - defs.length() > 0 &&
    (
      ctx.config.mode == CoverageForced ||
      ctx.config.mode == Natural ||
      ctx.random_bool()
    )
  let want_group = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(4) == 0)
  if ctx.config.features.allow_subtyping_topology &&
    (ctx.config.mode == CoverageForced || ctx.random_int(5) == 0) &&
    remaining_type_budget - defs.length() >= 5 {
    let base_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    let child_idx = TypeIdx::new((type_idx_cursor + 1).reinterpret_as_uint())
    let grandchild_idx = TypeIdx::new(
      (type_idx_cursor + 2).reinterpret_as_uint(),
    )
    defs.push(
      RecType::group([
        SubType::new(true, [], CompType::struct_([])),
        SubType::new(false, [], CompType::struct_([])),
        SubType::new(false, [child_idx], CompType::struct_([])),
      ]),
    )
    type_idx_cursor += 3
    let cross_ref_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    defs.push(
      RecType::new(SubType::new(false, [grandchild_idx], CompType::struct_([]))),
    )
    type_idx_cursor += 1
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::struct_([
            FieldType::new(
              StorageType::val_type(gen_valid_gc_type_field_ref(cross_ref_idx)),
              Const,
            ),
          ]),
        ),
      ),
    )
    type_idx_cursor += 1
    plan = { ..plan, rec_group_count: plan.rec_group_count + 1 }
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(base_idx))
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(child_idx))
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(grandchild_idx))
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(cross_ref_idx))
  }

  if want_struct && defs.length() < remaining_type_budget {
    let struct_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::struct_([
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
            FieldType::new(
              StorageType::val_type(
                ValType::ref_type(RefType::abs(AbsHeapType::eq())),
              ),
              Const,
            ),
          ]),
        ),
      ),
    )
    plan.struct_type_idxs.push(struct_idx)
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(struct_idx))
    type_idx_cursor += 1
  }

  if want_packed_struct && defs.length() < remaining_type_budget {
    let packed_struct_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::struct_([
            FieldType::new(StorageType::pack_type(PackType::i8()), Const),
            FieldType::new(StorageType::pack_type(PackType::i16()), Const),
          ]),
        ),
      ),
    )
    plan = { ..plan, packed_struct_idx: Some(packed_struct_idx) }
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(packed_struct_idx))
    type_idx_cursor += 1
  }

  if want_array && defs.length() < remaining_type_budget {
    let array_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
          ),
        ),
      ),
    )
    plan.array_type_idxs.push(array_idx)
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(array_idx))
    plan = { ..plan, bulk_data_array_idx: Some(array_idx) }
    type_idx_cursor += 1
  }

  if want_packed_i8_array && defs.length() < remaining_type_budget {
    let packed_i8_array_idx = TypeIdx::new(
      type_idx_cursor.reinterpret_as_uint(),
    )
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(StorageType::pack_type(PackType::i8()), Var),
          ),
        ),
      ),
    )
    plan = { ..plan, packed_i8_array_idx: Some(packed_i8_array_idx) }
    plan.concrete_ref_types.push(
      gen_valid_gc_type_field_ref(packed_i8_array_idx),
    )
    type_idx_cursor += 1
  }

  if want_packed_i16_array && defs.length() < remaining_type_budget {
    let packed_i16_array_idx = TypeIdx::new(
      type_idx_cursor.reinterpret_as_uint(),
    )
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(StorageType::pack_type(PackType::i16()), Var),
          ),
        ),
      ),
    )
    plan = { ..plan, packed_i16_array_idx: Some(packed_i16_array_idx) }
    plan.concrete_ref_types.push(
      gen_valid_gc_type_field_ref(packed_i16_array_idx),
    )
    type_idx_cursor += 1
  }

  if want_descriptor_group &&
    remaining_type_budget - (type_idx_cursor - next_type_idx) >= 2 {
    let described_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    let descriptor_idx = TypeIdx::new(
      (type_idx_cursor + 1).reinterpret_as_uint(),
    )
    if remaining_type_budget - (type_idx_cursor - next_type_idx) >= 4 {
      let leaf_described_idx = TypeIdx::new(
        (type_idx_cursor + 2).reinterpret_as_uint(),
      )
      let leaf_descriptor_idx = TypeIdx::new(
        (type_idx_cursor + 3).reinterpret_as_uint(),
      )
      defs.push(
        RecType::group([
          SubType::new(
            false,
            [],
            CompType::struct_([]),
            metadata=TypeMetadata::new(descriptor=Some(descriptor_idx)),
          ),
          SubType::new(
            false,
            [],
            CompType::struct_([]),
            metadata=TypeMetadata::new(describes=Some(described_idx)),
          ),
          SubType::new(
            true,
            [described_idx],
            CompType::struct_([]),
            metadata=TypeMetadata::new(descriptor=Some(leaf_descriptor_idx)),
          ),
          SubType::new(
            true,
            [descriptor_idx],
            CompType::struct_([]),
            metadata=TypeMetadata::new(describes=Some(leaf_described_idx)),
          ),
        ]),
      )
      plan = {
        ..plan,
        descriptor_struct_idx: Some(described_idx),
        descriptor_type_idx: Some(descriptor_idx),
        rec_group_count: plan.rec_group_count + 1,
      }
      plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(described_idx))
      plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(descriptor_idx))
      plan.concrete_ref_types.push(
        gen_valid_gc_type_field_ref(leaf_described_idx),
      )
      plan.concrete_ref_types.push(
        gen_valid_gc_type_field_ref(leaf_descriptor_idx),
      )
      plan.exact_ref_types.push(gen_valid_gc_type_exact_ref(described_idx))
      plan.exact_ref_types.push(gen_valid_gc_type_exact_ref(descriptor_idx))
      plan.exact_ref_types.push(gen_valid_gc_type_exact_ref(leaf_described_idx))
      plan.exact_ref_types.push(
        gen_valid_gc_type_exact_ref(leaf_descriptor_idx),
      )
      type_idx_cursor += 4
    } else {
      defs.push(
        RecType::group([
          SubType::comp_type(
            CompType::struct_([]),
            metadata=TypeMetadata::new(descriptor=Some(descriptor_idx)),
          ),
          SubType::comp_type(
            CompType::struct_([]),
            metadata=TypeMetadata::new(describes=Some(described_idx)),
          ),
        ]),
      )
      plan = {
        ..plan,
        descriptor_struct_idx: Some(described_idx),
        descriptor_type_idx: Some(descriptor_idx),
        rec_group_count: plan.rec_group_count + 1,
      }
      plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(described_idx))
      plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(descriptor_idx))
      plan.exact_ref_types.push(gen_valid_gc_type_exact_ref(described_idx))
      plan.exact_ref_types.push(gen_valid_gc_type_exact_ref(descriptor_idx))
      type_idx_cursor += 2
    }
  }

  let want_mutual_struct_array_group = ctx.config.features.allow_subtyping_topology &&
    (ctx.config.mode == CoverageForced || ctx.random_int(4) == 0) &&
    remaining_type_budget - (type_idx_cursor - next_type_idx) >= 2
  if want_mutual_struct_array_group {
    let struct_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    let array_idx = TypeIdx::new((type_idx_cursor + 1).reinterpret_as_uint())
    defs.push(
      RecType::group([
        SubType::comp_type(
          CompType::struct_([
            FieldType::new(
              StorageType::val_type(
                ValType::ref_type(RefType::new(true, HeapType::new(array_idx))),
              ),
              Var,
            ),
          ]),
        ),
        SubType::comp_type(
          CompType::array(
            FieldType::new(
              StorageType::val_type(
                ValType::ref_type(RefType::new(true, HeapType::new(struct_idx))),
              ),
              Var,
            ),
          ),
        ),
      ]),
    )
    plan = { ..plan, rec_group_count: plan.rec_group_count + 1 }
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(struct_idx))
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(array_idx))
    plan.exact_ref_types.push(gen_valid_gc_type_exact_ref(struct_idx))
    plan.exact_ref_types.push(gen_valid_gc_type_exact_ref(array_idx))
    type_idx_cursor += 2
  }

  if want_elem_array && defs.length() < remaining_type_budget {
    let elem_array_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    let elem_ref_type = match plan.descriptor_type_idx {
      Some(descriptor_idx) => RefType::new(true, HeapType::new(descriptor_idx))
      None => RefType::abs(AbsHeapType::eq())
    }
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(
              StorageType::val_type(ValType::ref_type(elem_ref_type)),
              Var,
            ),
          ),
        ),
      ),
    )
    plan.array_type_idxs.push(elem_array_idx)
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(elem_array_idx))
    plan = {
      ..plan,
      bulk_elem_array_idx: Some(elem_array_idx),
      bulk_elem_ref_type: Some(elem_ref_type),
    }
    type_idx_cursor += 1
  }

  if want_string_wtf16_array && defs.length() < remaining_type_budget {
    let string_wtf16_array_idx = TypeIdx::new(
      type_idx_cursor.reinterpret_as_uint(),
    )
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(StorageType::pack_type(PackType::i16()), Var),
          ),
        ),
      ),
    )
    plan = { ..plan, string_wtf16_array_idx: Some(string_wtf16_array_idx) }
    plan.array_type_idxs.push(string_wtf16_array_idx)
    plan.concrete_ref_types.push(
      gen_valid_gc_type_field_ref(string_wtf16_array_idx),
    )
    type_idx_cursor += 1
  }

  if want_string_utf8_array && defs.length() < remaining_type_budget {
    let string_utf8_array_idx = TypeIdx::new(
      type_idx_cursor.reinterpret_as_uint(),
    )
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(StorageType::pack_type(PackType::i8()), Var),
          ),
        ),
      ),
    )
    plan = { ..plan, string_utf8_array_idx: Some(string_utf8_array_idx) }
    plan.array_type_idxs.push(string_utf8_array_idx)
    plan.concrete_ref_types.push(
      gen_valid_gc_type_field_ref(string_utf8_array_idx),
    )
    type_idx_cursor += 1
  }

  if want_group && defs.length() < remaining_type_budget {
    defs.push(
      RecType::group([
        SubType::comp_type(
          CompType::struct_([
            FieldType::new(StorageType::val_type(ValType::i64()), Const),
          ]),
        ),
        SubType::comp_type(
          CompType::array(
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
          ),
        ),
      ]),
    )
    type_idx_cursor += 2
    plan = { ..plan, rec_group_count: plan.rec_group_count + 1 }
  }

  (defs, plan)
}

///|
fn gen_matching_local_idx(
  local_types : Array[ValType],
  vt : ValType,
) -> LocalIdx? {
  for i = 0; i < local_types.length(); i = i + 1 {
    if local_types[i] == vt {
      return Some(LocalIdx::new(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
fn gen_valid_contains_type_idx(
  type_idxs : Array[TypeIdx],
  target : TypeIdx,
) -> Bool {
  for type_idx in type_idxs {
    if type_idx == target {
      return true
    }
  }
  false
}

///|
fn gen_valid_callable_by_idx(
  funcs : Array[GenValidFuncSig],
  func_idx : FuncIdx,
) -> GenValidFuncSig? {
  for func in funcs {
    if func.idx == func_idx {
      return Some(func)
    }
  }
  None
}

///|
priv struct GenValidFuncSig {
  idx : FuncIdx
  type_idx : TypeIdx
  params : Array[ValType]
  results : Array[ValType]
}

///|
priv struct GenValidImportPlan {
  func_count : Int
  table_count : Int
  mem_count : Int
  global_count : Int
  tag_count : Int
}

///|
priv struct GenValidGcTypePlan {
  struct_type_idxs : Array[TypeIdx]
  array_type_idxs : Array[TypeIdx]
  concrete_ref_types : Array[ValType]
  exact_ref_types : Array[ValType]
  bulk_data_array_idx : TypeIdx?
  bulk_elem_array_idx : TypeIdx?
  bulk_elem_ref_type : RefType?
  packed_struct_idx : TypeIdx?
  packed_i8_array_idx : TypeIdx?
  packed_i16_array_idx : TypeIdx?
  descriptor_struct_idx : TypeIdx?
  descriptor_type_idx : TypeIdx?
  string_wtf16_array_idx : TypeIdx?
  string_utf8_array_idx : TypeIdx?
  rec_group_count : Int
}

///|
priv struct GenValidBodyEnv {
  local_types : Array[ValType]
  globals : Array[GlobalType]
  tables : Array[TableType]
  mems : Array[MemType]
  tags : Array[TagType]
  funcs : Array[GenValidFuncSig]
  return_types : Array[ValType]
  data_idxs : Array[DataIdx]
  passive_elem_idxs : Array[ElemIdx]
  passive_elem_ref_types : Array[RefType]
  bulk_elem_seed_idx : ElemIdx?
  gc_type_plan : GenValidGcTypePlan
  declared_ref_func_idx : FuncIdx?
  current_func_idx : FuncIdx?
  depth_left : Int
  label_depth : Int
}

///|
fn gen_matching_global_idx(
  globals : Array[GlobalType],
  vt : ValType,
  mutable_only? : Bool = false,
) -> GlobalIdx? {
  for i = 0; i < globals.length(); i = i + 1 {
    let GlobalType(global_vt, is_mut) = globals[i]
    if global_vt == vt && (!mutable_only || is_mut) {
      return Some(GlobalIdx::new(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
fn gen_matching_immutable_global_idx(
  globals : Array[GlobalType],
  vt : ValType,
) -> GlobalIdx? {
  for i = 0; i < globals.length(); i = i + 1 {
    let GlobalType(global_vt, is_mut) = globals[i]
    if global_vt == vt && !is_mut {
      return Some(GlobalIdx::new(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
fn gen_valid_const_expr_for_global(
  ctx : GenValidContext,
  vt : ValType,
  prior_globals : Array[GlobalType],
  func_idx : FuncIdx,
  gc_type_plan : GenValidGcTypePlan,
) -> Expr {
  if ctx.config.features.allow_const_expr_variants {
    match gen_matching_immutable_global_idx(prior_globals, vt) {
      Some(idx) if vt == ValType::i32() &&
        (ctx.config.mode == CoverageForced || ctx.random_bool()) =>
        return Expr::new([Instruction::global_get(idx)])
      _ => ()
    }
    if vt == ValType::funcref() &&
      (ctx.config.mode == CoverageForced || ctx.random_int(4) == 0) {
      return Expr::new([Instruction::ref_func(func_idx)])
    }
    match vt {
      RefTypeValType(HeapTypeRefType(true, _, HeapType(type_idx))) =>
        if gen_valid_contains_type_idx(gc_type_plan.struct_type_idxs, type_idx) &&
          (ctx.config.mode == CoverageForced || ctx.random_int(4) == 0) {
          return Expr::new([Instruction::struct_new_default(type_idx)])
        }
      _ => ()
    }
  }
  gen_const_expr(ctx, vt)
}

///|
fn gen_valid_memarg() -> MemArg {
  MemArg::new(U32(0), None, U64(0))
}

///|
fn gen_valid_memarg_varied(align_pow : UInt, offset : UInt64) -> MemArg {
  MemArg::new(U32(align_pow), None, U64(offset))
}

///|
fn gen_valid_simd_memarg_varied(
  nonzero_mem_idx : MemIdx?,
  align_pow : UInt,
  offset : UInt64,
) -> MemArg {
  match nonzero_mem_idx {
    Some(mem_idx) => MemArg::new(U32(align_pow), Some(mem_idx), U64(offset))
    None => gen_valid_memarg_varied(align_pow, offset)
  }
}

///|
fn gen_valid_memarg_for_mem(
  mem_idx : MemIdx,
  align_pow : UInt,
  offset : UInt64,
) -> MemArg {
  MemArg::new(U32(align_pow), Some(mem_idx), U64(offset))
}

///|
fn gen_valid_body_env_child(
  env : GenValidBodyEnv,
  add_void_label? : Bool = false,
) -> GenValidBodyEnv {
  let next_label_depth = if add_void_label {
    env.label_depth + 1
  } else {
    env.label_depth
  }
  {
    ..env,
    depth_left: if env.depth_left > 0 {
      env.depth_left - 1
    } else {
      0
    },
    label_depth: next_label_depth,
  }
}

///|
fn gen_valid_body_stmt_count(ctx : GenValidContext, depth_left : Int) -> Int {
  let bounded = gen_valid_clamp_non_negative(ctx.config.max_body_statements)
  let capped = if depth_left <= 0 {
    gen_valid_min_int(2, bounded)
  } else {
    gen_valid_min_int(3, bounded)
  }
  1 + ctx.random_int(capped)
}

///|
fn gen_valid_append_call_args(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  params : Array[ValType],
) -> Unit {
  let child_env = gen_valid_body_env_child(env)
  for param in params {
    append_value_instrs(out, ctx, param, child_env, prefer_local=true)
  }
}

///|
fn gen_valid_append_call_result_drops(
  out : Array[Instruction],
  results : Array[ValType],
) -> Unit {
  for _ in results {
    out.push(Instruction::drop())
  }
}

///|
fn gen_valid_append_direct_call(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  target : GenValidFuncSig,
) -> Unit {
  gen_valid_append_call_args(out, ctx, env, target.params)
  out.push(Instruction::call(target.idx))
  gen_valid_append_call_result_drops(out, target.results)
}

///|
fn gen_valid_func_idx_to_int(idx : FuncIdx) -> Int {
  let FuncIdx(idx_u) = idx
  idx_u.reinterpret_as_int()
}

///|
fn gen_valid_func_type_idx_from_ref_type(rt : RefType) -> TypeIdx? {
  match rt {
    HeapTypeRefType(_, _, HeapType(type_idx)) => Some(type_idx)
    _ => None
  }
}

///|
fn gen_valid_has_callable_with_result(
  funcs : Array[GenValidFuncSig],
  vt : ValType,
) -> Bool {
  for func in funcs {
    if func.results == [vt] {
      return true
    }
  }
  false
}

///|
fn gen_valid_declared_ref_callable_with_result(
  funcs : Array[GenValidFuncSig],
  declared_ref_func_idx : FuncIdx?,
  vt : ValType,
) -> GenValidFuncSig? {
  match declared_ref_func_idx {
    Some(func_idx) =>
      match gen_valid_callable_by_idx(funcs, func_idx) {
        Some(target) if target.results == [vt] => Some(target)
        _ => None
      }
    None => None
  }
}

///|
fn gen_valid_declared_ref_callable_with_results(
  funcs : Array[GenValidFuncSig],
  declared_ref_func_idx : FuncIdx?,
  results : Array[ValType],
) -> GenValidFuncSig? {
  match declared_ref_func_idx {
    Some(func_idx) =>
      match gen_valid_callable_by_idx(funcs, func_idx) {
        Some(target) if target.results == results => Some(target)
        _ => None
      }
    None => None
  }
}

///|
fn gen_valid_pick_callable_with_results(
  ctx : GenValidContext,
  funcs : Array[GenValidFuncSig],
  results : Array[ValType],
) -> GenValidFuncSig? {
  let matches : Array[GenValidFuncSig] = []
  for func in funcs {
    if func.results == results {
      matches.push(func)
    }
  }
  if matches.is_empty() {
    None
  } else {
    Some(matches[ctx.random_int(matches.length())])
  }
}

///|
fn gen_valid_pick_callable_with_result(
  ctx : GenValidContext,
  funcs : Array[GenValidFuncSig],
  vt : ValType,
) -> GenValidFuncSig? {
  let matches : Array[GenValidFuncSig] = []
  for func in funcs {
    if func.results == [vt] {
      matches.push(func)
    }
  }
  if matches.is_empty() {
    None
  } else {
    Some(matches[ctx.random_int(matches.length())])
  }
}

///|
fn gen_valid_pick_callable(
  ctx : GenValidContext,
  funcs : Array[GenValidFuncSig],
) -> GenValidFuncSig? {
  if funcs.is_empty() {
    None
  } else {
    Some(funcs[ctx.random_int(funcs.length())])
  }
}

///|
fn gen_valid_append_table_ref_value(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  rt : RefType,
) -> Unit {
  append_value_instrs(
    out,
    ctx,
    ValType::ref_type(rt),
    gen_valid_body_env_child(env),
    prefer_local=false,
  )
}

///|
fn gen_valid_pick_func_idx(
  ctx : GenValidContext,
  total_func_count : Int,
  preferred_idx : FuncIdx,
) -> FuncIdx {
  if total_func_count <= 0 {
    preferred_idx
  } else if ctx.config.mode == CoverageForced || ctx.random_int(3) == 0 {
    preferred_idx
  } else {
    FuncIdx::new(ctx.random_int(total_func_count).reinterpret_as_uint())
  }
}

///|
fn gen_valid_funcref_expr(ctx : GenValidContext, func_idx : FuncIdx) -> Expr {
  if ctx.config.mode == CoverageForced || ctx.random_int(4) != 0 {
    Expr::new([Instruction::ref_func(func_idx)])
  } else {
    Expr::new([
      Instruction::ref_null(RefType::abs(AbsHeapType::func()).get_heap_type()),
    ])
  }
}

///|
fn gen_valid_elem_ref_expr(
  ctx : GenValidContext,
  rt : RefType,
  func_idx? : FuncIdx = FuncIdx::new(0U),
) -> Expr {
  if ValType::ref_type(rt) == ValType::funcref() {
    gen_valid_funcref_expr(ctx, func_idx)
  } else {
    Expr::new([Instruction::ref_null(rt.get_heap_type())])
  }
}

///|
fn gen_valid_mem_type_is_i32(mt : MemType) -> Bool {
  let MemType(lim, _) = mt
  match lim {
    I32Limits(_, _) => true
    I64Limits(_) => false
  }
}

///|
fn gen_valid_first_nonzero_i32_mem_idx(mems : Array[MemType]) -> MemIdx? {
  for i = 1; i < mems.length(); i = i + 1 {
    if gen_valid_mem_type_is_i32(mems[i]) {
      return Some(MemIdx::new(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
fn gen_valid_append_memory_bulk_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Bool {
  if env.mems.is_empty() {
    return false
  }
  let mem_idx = MemIdx::new(0U)
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::memory_copy(mem_idx, mem_idx))

  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::memory_fill(mem_idx))

  if !env.data_idxs.is_empty() {
    let data_idx = env.data_idxs[0]
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::memory_init(data_idx, mem_idx))
    out.push(Instruction::data_drop(data_idx))
  }
  match gen_valid_first_nonzero_i32_mem_idx(env.mems) {
    Some(nonzero_mem_idx) => {
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::memory_copy(nonzero_mem_idx, mem_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(7)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::memory_fill(nonzero_mem_idx))
      if !env.data_idxs.is_empty() {
        let data_idx = if env.data_idxs.length() > 1 {
          env.data_idxs[1]
        } else {
          env.data_idxs[0]
        }
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::memory_init(data_idx, nonzero_mem_idx))
        out.push(Instruction::data_drop(data_idx))
      }
    }
    None => ()
  }
  ignore(ctx)
  true
}

///|
fn gen_valid_append_scalar_memory_load_drop(
  out : Array[Instruction],
  load : Instruction,
) -> Unit {
  out.push(Instruction::i32_const(I32(0)))
  out.push(load)
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_scalar_memory_store(
  out : Array[Instruction],
  value : Instruction,
  store : Instruction,
) -> Unit {
  out.push(Instruction::i32_const(I32(0)))
  out.push(value)
  out.push(store)
}

///|
fn gen_valid_append_nonzero_scalar_memory_ops(
  out : Array[Instruction],
  mem_idx : MemIdx,
) -> Unit {
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i32_load(gen_valid_memarg_for_mem(mem_idx, 2U, 88UL)),
  )
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::i32_const(I32(10)),
    Instruction::i32_store(gen_valid_memarg_for_mem(mem_idx, 2U, 92UL)),
  )
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i64_load8u(gen_valid_memarg_for_mem(mem_idx, 0U, 96UL)),
  )
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::i64_const(I64(11L)),
    Instruction::i64_store16(gen_valid_memarg_for_mem(mem_idx, 1U, 98UL)),
  )
}

///|
fn gen_valid_append_scalar_memory_ops(out : Array[Instruction]) -> Unit {
  let i32_load_ma = gen_valid_memarg_varied(2U, 4UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i32_load(i32_load_ma),
  )
  let i64_load_ma = gen_valid_memarg_varied(3U, 8UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i64_load(i64_load_ma),
  )
  let f32_load_ma = gen_valid_memarg_varied(2U, 12UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::f32_load(f32_load_ma),
  )
  let f64_load_ma = gen_valid_memarg_varied(3U, 16UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::f64_load(f64_load_ma),
  )

  let i32_load8s_ma = gen_valid_memarg_varied(0U, 20UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i32_load8s(i32_load8s_ma),
  )
  let i32_load8u_ma = gen_valid_memarg_varied(0U, 21UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i32_load8u(i32_load8u_ma),
  )
  let i32_load16s_ma = gen_valid_memarg_varied(1U, 22UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i32_load16s(i32_load16s_ma),
  )
  let i32_load16u_ma = gen_valid_memarg_varied(1U, 24UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i32_load16u(i32_load16u_ma),
  )
  let i64_load8s_ma = gen_valid_memarg_varied(0U, 26UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i64_load8s(i64_load8s_ma),
  )
  let i64_load8u_ma = gen_valid_memarg_varied(0U, 27UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i64_load8u(i64_load8u_ma),
  )
  let i64_load16s_ma = gen_valid_memarg_varied(1U, 28UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i64_load16s(i64_load16s_ma),
  )
  let i64_load16u_ma = gen_valid_memarg_varied(1U, 30UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i64_load16u(i64_load16u_ma),
  )
  let i64_load32s_ma = gen_valid_memarg_varied(2U, 32UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i64_load32s(i64_load32s_ma),
  )
  let i64_load32u_ma = gen_valid_memarg_varied(2U, 36UL)
  gen_valid_append_scalar_memory_load_drop(
    out,
    Instruction::i64_load32u(i64_load32u_ma),
  )

  let i32_store_ma = gen_valid_memarg_varied(2U, 40UL)
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::i32_const(I32(1)),
    Instruction::i32_store(i32_store_ma),
  )
  let i64_store_ma = gen_valid_memarg_varied(3U, 48UL)
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::i64_const(I64(2L)),
    Instruction::i64_store(i64_store_ma),
  )
  let f32_store_ma = gen_valid_memarg_varied(2U, 56UL)
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::f32_const(F32(Float::from_double(3.0))),
    Instruction::f32_store(f32_store_ma),
  )
  let f64_store_ma = gen_valid_memarg_varied(3U, 64UL)
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::f64_const(F64(4.0)),
    Instruction::f64_store(f64_store_ma),
  )
  let i32_store8_ma = gen_valid_memarg_varied(0U, 72UL)
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::i32_const(I32(5)),
    Instruction::i32_store8(i32_store8_ma),
  )
  let i32_store16_ma = gen_valid_memarg_varied(1U, 74UL)
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::i32_const(I32(6)),
    Instruction::i32_store16(i32_store16_ma),
  )
  let i64_store8_ma = gen_valid_memarg_varied(0U, 76UL)
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::i64_const(I64(7L)),
    Instruction::i64_store8(i64_store8_ma),
  )
  let i64_store16_ma = gen_valid_memarg_varied(1U, 78UL)
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::i64_const(I64(8L)),
    Instruction::i64_store16(i64_store16_ma),
  )
  let i64_store32_ma = gen_valid_memarg_varied(2U, 80UL)
  gen_valid_append_scalar_memory_store(
    out,
    Instruction::i64_const(I64(9L)),
    Instruction::i64_store32(i64_store32_ma),
  )
}

///|
fn gen_valid_first_nonzero_table_idx(tables : Array[TableType]) -> TableIdx? {
  if tables.length() > 1 {
    Some(TableIdx::new(1U))
  } else {
    None
  }
}

///|
fn gen_valid_table_init_ref_types_compatible(
  elem_rt : RefType,
  table_rt : RefType,
) -> Bool {
  elem_rt == table_rt ||
  (
    elem_rt.is_nullable() == table_rt.is_nullable() &&
    elem_rt.get_heap_type() == table_rt.get_heap_type()
  )
}

///|
fn gen_valid_nonzero_table_init_pair(
  env : GenValidBodyEnv,
) -> (ElemIdx, TableIdx)? {
  if env.passive_elem_idxs.is_empty() {
    return None
  }
  for table_i = 1; table_i < env.tables.length(); table_i = table_i + 1 {
    let TableType(table_rt, _) = env.tables[table_i]
    for elem_i = 0; elem_i < env.passive_elem_idxs.length(); elem_i = elem_i + 1 {
      if gen_valid_table_init_ref_types_compatible(
          env.passive_elem_ref_types[elem_i],
          table_rt,
        ) {
        return Some(
          (
            env.passive_elem_idxs[elem_i],
            TableIdx::new(table_i.reinterpret_as_uint()),
          ),
        )
      }
    }
  }
  None
}

///|
fn gen_valid_append_nonzero_table_access_ops(
  out : Array[Instruction],
  env : GenValidBodyEnv,
  table_idx : TableIdx,
) -> Unit {
  let TableIdx(table_idx_u) = table_idx
  let TableType(rt, _) = env.tables[table_idx_u.reinterpret_as_int()]
  out.push(Instruction::table_size(table_idx))
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::ref_null(rt.get_heap_type()))
  out.push(Instruction::table_set(table_idx))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::table_get(table_idx))
  out.push(Instruction::drop())
  out.push(Instruction::ref_null(rt.get_heap_type()))
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::table_grow(table_idx))
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_table_bulk_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Bool {
  if env.tables.is_empty() {
    return false
  }
  let table_idx = TableIdx::new(0U)
  let TableType(rt, _) = env.tables[0]

  out.push(Instruction::i32_const(I32(0)))
  gen_valid_append_table_ref_value(out, ctx, env, rt)
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::table_fill(table_idx))

  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::table_copy(table_idx, table_idx))

  if !env.passive_elem_idxs.is_empty() {
    let elem_idx = env.passive_elem_idxs[0]
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::table_init(elem_idx, table_idx))
    out.push(Instruction::elem_drop(elem_idx))
  }
  match gen_valid_first_nonzero_table_idx(env.tables) {
    Some(nonzero_table_idx) => {
      let TableIdx(nonzero_table_idx_u) = nonzero_table_idx
      let TableType(nonzero_rt, _) = env.tables[nonzero_table_idx_u.reinterpret_as_int()]
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::ref_null(nonzero_rt.get_heap_type()))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::table_fill(nonzero_table_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::table_copy(nonzero_table_idx, nonzero_table_idx))
    }
    None => ()
  }
  match gen_valid_nonzero_table_init_pair(env) {
    Some((elem_idx, table_idx)) => {
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::table_init(elem_idx, table_idx))
      out.push(Instruction::elem_drop(elem_idx))
    }
    None => ()
  }
  true
}

///|
fn gen_valid_append_array_data_seed_instrs(
  out : Array[Instruction],
  env : GenValidBodyEnv,
) -> Bool {
  if env.data_idxs.is_empty() {
    return false
  }
  match env.gc_type_plan.bulk_data_array_idx {
    Some(array_idx) => {
      let data_idx = env.data_idxs[0]
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::array_new_data(array_idx, data_idx))
      true
    }
    None => false
  }
}

///|
fn gen_valid_append_array_elem_seed_instrs(
  out : Array[Instruction],
  env : GenValidBodyEnv,
) -> Bool {
  match (env.gc_type_plan.bulk_elem_array_idx, env.bulk_elem_seed_idx) {
    (Some(array_idx), Some(elem_idx)) => {
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::array_new_elem(array_idx, elem_idx))
      true
    }
    _ => false
  }
}

///|
fn gen_valid_append_array_data_init_instrs(
  out : Array[Instruction],
  env : GenValidBodyEnv,
) -> Bool {
  if env.data_idxs.is_empty() {
    return false
  }
  match env.gc_type_plan.bulk_data_array_idx {
    Some(array_idx) => {
      let data_idx = env.data_idxs[0]
      out.push(Instruction::i32_const(I32(1)))
      out.push(Instruction::array_new_default(array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::array_init_data(array_idx, data_idx))
      true
    }
    None => false
  }
}

///|
fn gen_valid_append_array_elem_init_instrs(
  out : Array[Instruction],
  env : GenValidBodyEnv,
) -> Bool {
  match (env.gc_type_plan.bulk_elem_array_idx, env.bulk_elem_seed_idx) {
    (Some(array_idx), Some(elem_idx)) => {
      out.push(Instruction::i32_const(I32(1)))
      out.push(Instruction::array_new_default(array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::array_init_elem(array_idx, elem_idx))
      true
    }
    _ => false
  }
}

///|
fn gen_valid_append_nested_void_instrs(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  let child = gen_valid_body_env_child(env, add_void_label=true)
  let stmt_count = gen_valid_body_stmt_count(ctx, child.depth_left)
  for _ in 0..<stmt_count {
    append_void_stmt(out, ctx, child)
  }
}

///|
priv struct GenValidTypedStack {
  values : Array[ValType]
}

///|
fn gen_valid_typed_stack_empty() -> GenValidTypedStack {
  { values: [] }
}

///|
fn gen_valid_typed_stack_push(
  stack : GenValidTypedStack,
  vt : ValType,
) -> GenValidTypedStack {
  let values = stack.values.copy()
  values.push(vt)
  { values, }
}

///|
fn gen_valid_typed_value(
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  vt : ValType,
) -> Array[Instruction] {
  if ctx.config.mode == CoverageForced {
    return [gen_const_instr(ctx, vt)]
  }
  let out : Array[Instruction] = []
  append_value_instrs(out, ctx, vt, env, prefer_local=true)
  out
}

///|
fn gen_valid_typed_pick_local_set_target(
  local_types : Array[ValType],
) -> (LocalIdx, ValType)? {
  for vt in [ValType::i64(), ValType::f32(), ValType::f64(), ValType::i32()] {
    match gen_matching_local_idx(local_types, vt) {
      Some(idx) => return Some((idx, vt))
      None => ()
    }
  }
  None
}

///|
fn gen_valid_typed_pick_multivalue_block_type(
  funcs : Array[GenValidFuncSig],
) -> (TypeIdx, Array[ValType])? {
  for func in funcs {
    if func.params.is_empty() && func.results.length() > 1 {
      return Some((func.type_idx, func.results))
    }
  }
  None
}

///|
fn gen_valid_typed_expr(
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  expected_results : Array[ValType],
  fuel : Int,
) -> Array[Instruction] {
  let out : Array[Instruction] = []
  let mut stack = gen_valid_typed_stack_empty()
  for vt in expected_results {
    let value_instrs = if fuel > 0 {
      gen_valid_typed_value(ctx, env, vt)
    } else {
      [gen_const_instr(ctx, vt)]
    }
    for instr in value_instrs {
      out.push(instr)
    }
    stack = gen_valid_typed_stack_push(stack, vt)
  }
  ignore(stack)
  out
}

///|
fn gen_valid_append_typed_payload_control_blocks(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  vt : ValType,
  fuel : Int,
) -> Unit {
  let child = gen_valid_body_env_child(env, add_void_label=true)
  let payload_br_body : Array[Instruction] = []
  for instr in gen_valid_typed_expr(ctx, child, [vt], fuel - 1) {
    payload_br_body.push(instr)
  }
  payload_br_body.push(Instruction::br(LabelIdx::new(0U)))
  payload_br_body.push(Instruction::unreachable_())
  out.push(
    Instruction::block(BlockType::val_type(vt), Expr::new(payload_br_body)),
  )
  out.push(Instruction::drop())

  let payload_br_if_body : Array[Instruction] = []
  for instr in gen_valid_typed_expr(ctx, child, [vt], fuel - 1) {
    payload_br_if_body.push(instr)
  }
  payload_br_if_body.push(
    Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
  )
  payload_br_if_body.push(Instruction::br_if(LabelIdx::new(0U)))
  out.push(
    Instruction::block(BlockType::val_type(vt), Expr::new(payload_br_if_body)),
  )
  out.push(Instruction::drop())

  let payload_br_table_body : Array[Instruction] = []
  for instr in gen_valid_typed_expr(ctx, child, [vt], fuel - 1) {
    payload_br_table_body.push(instr)
  }
  payload_br_table_body.push(Instruction::i32_const(I32(ctx.random_int(3))))
  payload_br_table_body.push(
    Instruction::br_table([LabelIdx::new(0U)], LabelIdx::new(0U)),
  )
  payload_br_table_body.push(Instruction::unreachable_())
  out.push(
    Instruction::block(
      BlockType::val_type(vt),
      Expr::new(payload_br_table_body),
    ),
  )
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_nested_payload_branch_block(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  vt : ValType,
  fuel : Int,
) -> Unit {
  let child = gen_valid_body_env_child(env, add_void_label=true)
  let inner_body : Array[Instruction] = []
  for instr in gen_valid_typed_expr(ctx, child, [vt], fuel - 1) {
    inner_body.push(instr)
  }
  let selector = ctx.random_int(3)
  if selector == 0 {
    inner_body.push(Instruction::br(LabelIdx::new(1U)))
  } else if selector == 1 {
    inner_body.push(
      Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
    )
    inner_body.push(Instruction::br_if(LabelIdx::new(1U)))
    inner_body.push(Instruction::br(LabelIdx::new(1U)))
  } else {
    inner_body.push(Instruction::i32_const(I32(ctx.random_int(3))))
    inner_body.push(
      Instruction::br_table([LabelIdx::new(1U)], LabelIdx::new(1U)),
    )
  }
  inner_body.push(Instruction::unreachable_())
  let outer_body = [
    Instruction::block(BlockType::void_(), Expr::new(inner_body)),
    Instruction::unreachable_(),
  ]
  out.push(Instruction::block(BlockType::val_type(vt), Expr::new(outer_body)))
  out.push(Instruction::drop())
}

///|
fn gen_valid_typed_stmt(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  fuel : Int,
) -> Unit {
  let child = gen_valid_body_env_child(env, add_void_label=true)
  match gen_valid_typed_pick_local_set_target(env.local_types) {
    Some((idx, vt)) => {
      for instr in gen_valid_typed_expr(ctx, env, [vt], fuel) {
        out.push(instr)
      }
      out.push(Instruction::local_set(idx))
    }
    None => ()
  }
  match gen_matching_local_idx(env.local_types, ValType::i32()) {
    Some(idx) => {
      for instr in gen_valid_typed_expr(ctx, env, [ValType::i32()], fuel) {
        out.push(instr)
      }
      out.push(Instruction::local_tee(idx))
      out.push(Instruction::drop())
    }
    None => ()
  }
  out.push(
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new(gen_valid_typed_expr(ctx, child, [ValType::i32()], fuel - 1)),
    ),
  )
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })))
  out.push(
    Instruction::if_(
      BlockType::val_type(ValType::i32()),
      gen_valid_typed_expr(ctx, child, [ValType::i32()], fuel - 1),
      Some(gen_valid_typed_expr(ctx, child, [ValType::i32()], fuel - 1)),
    ),
  )
  out.push(Instruction::drop())
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
        Instruction::br_if(LabelIdx::new(0U)),
      ]),
    ),
  )
  out.push(
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i32_const(I32(ctx.random_int(1000))),
        Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
        Instruction::br_if(LabelIdx::new(0U)),
      ]),
    ),
  )
  out.push(Instruction::drop())
  out.push(
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i32_const(I32(ctx.random_int(1000))),
        Instruction::i32_const(I32(ctx.random_int(3))),
        Instruction::br_table([LabelIdx::new(0U)], LabelIdx::new(0U)),
        Instruction::unreachable_(),
      ]),
    ),
  )
  out.push(Instruction::drop())
  out.push(
    Instruction::loop_(
      BlockType::val_type(ValType::i32()),
      Expr::new(gen_valid_typed_expr(ctx, child, [ValType::i32()], fuel - 1)),
    ),
  )
  out.push(Instruction::drop())
  match gen_valid_typed_pick_multivalue_block_type(env.funcs) {
    Some((type_idx, results)) => {
      let multivalue_body : Array[Instruction] = []
      for vt in results {
        multivalue_body.push(gen_const_instr(ctx, vt))
      }
      out.push(
        Instruction::block(
          BlockType::type_idx(type_idx),
          Expr::new(multivalue_body),
        ),
      )
      for _ in results {
        out.push(Instruction::drop())
      }
    }
    None => ()
  }
  for
    vt in [
      ValType::i32(),
      ValType::i64(),
      ValType::f32(),
      ValType::f64(),
      ValType::v128(),
      ValType::funcref(),
    ] {
    gen_valid_append_typed_payload_control_blocks(out, ctx, env, vt, fuel)
    gen_valid_append_nested_payload_branch_block(out, ctx, env, vt, fuel)
  }
  if !env.return_types.is_empty() {
    let return_block_body : Array[Instruction] = []
    for vt in env.return_types {
      for instr in gen_valid_typed_expr(ctx, env, [vt], fuel - 1) {
        return_block_body.push(instr)
      }
    }
    return_block_body.push(Instruction::return_())
    return_block_body.push(Instruction::unreachable_())
    out.push(
      Instruction::block(BlockType::void_(), Expr::new(return_block_body)),
    )
  }
}

///|
fn gen_valid_append_typed_body_generator_slice(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !ctx.config.features.allow_typed_body_generator {
    return
  }
  gen_valid_typed_stmt(out, ctx, env, env.depth_left)
}

///|
fn append_value_instrs(
  out : Array[Instruction],
  ctx : GenValidContext,
  vt : ValType,
  env : GenValidBodyEnv,
  prefer_local? : Bool = true,
) -> Unit {
  if prefer_local && ctx.random_bool() {
    match gen_matching_local_idx(env.local_types, vt) {
      Some(idx) => {
        out.push(Instruction::local_get(idx))
        return
      }
      None => ()
    }
  }
  match gen_matching_global_idx(env.globals, vt) {
    Some(idx) if ctx.random_int(5) == 0 => {
      out.push(Instruction::global_get(idx))
      return
    }
    _ => ()
  }
  if env.depth_left > 0 &&
    !(ctx.config.mode == Natural &&
    !env.gc_type_plan.concrete_ref_types.is_empty()) {
    if ctx.config.features.allow_calls {
      match gen_valid_pick_callable_with_result(ctx, env.funcs, vt) {
        Some(target) if ctx.random_int(4) == 0 => {
          gen_valid_append_call_args(out, ctx, env, target.params)
          out.push(Instruction::call(target.idx))
          return
        }
        _ => ()
      }
    }
    if !env.mems.is_empty() && vt == ValType::i32() && ctx.random_int(5) == 0 {
      out.push(Instruction::memory_size(MemIdx::new(0U)))
      return
    }
    if ctx.config.features.allow_call_indirect && !env.tables.is_empty() {
      match gen_valid_pick_callable_with_result(ctx, env.funcs, vt) {
        Some(target) if ctx.random_int(4) == 0 => {
          gen_valid_append_call_args(out, ctx, env, target.params)
          out.push(Instruction::i32_const(I32(0)))
          out.push(
            Instruction::call_indirect(target.type_idx, TableIdx::new(0U)),
          )
          return
        }
        _ => ()
      }
    }
    if ctx.config.features.allow_branch_heavy_control && ctx.random_int(5) == 0 {
      let then_body : Array[Instruction] = []
      let else_body : Array[Instruction] = []
      let child = gen_valid_body_env_child(env)
      append_value_instrs(then_body, ctx, vt, child, prefer_local=false)
      append_value_instrs(else_body, ctx, vt, child, prefer_local=false)
      out.push(
        Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
      )
      out.push(
        Instruction::if_(BlockType::val_type(vt), then_body, Some(else_body)),
      )
      return
    }
    if ctx.config.features.allow_branch_heavy_control && ctx.random_int(5) == 0 {
      let child_body : Array[Instruction] = []
      append_value_instrs(
        child_body,
        ctx,
        vt,
        gen_valid_body_env_child(env),
        prefer_local=false,
      )
      out.push(
        Instruction::block(BlockType::val_type(vt), Expr::new(child_body)),
      )
      return
    }
    if !env.tables.is_empty() {
      let TableType(rt, _) = env.tables[0]
      if vt == ValType::ref_type(rt) && ctx.random_int(4) == 0 {
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::table_get(TableIdx::new(0U)))
        return
      }
    }
    if !env.mems.is_empty() {
      let memarg = gen_valid_memarg()
      match vt {
        NumTypeValType(I32NumType) if ctx.random_int(4) == 0 => {
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::i32_load(memarg))
          return
        }
        NumTypeValType(I64NumType) if ctx.random_int(4) == 0 => {
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::i64_load(memarg))
          return
        }
        NumTypeValType(F32NumType) if ctx.random_int(4) == 0 => {
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::f32_load(memarg))
          return
        }
        NumTypeValType(F64NumType) if ctx.random_int(4) == 0 => {
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::f64_load(memarg))
          return
        }
        _ => ()
      }
    }
    if !env.tables.is_empty() && vt == ValType::i32() && ctx.random_int(4) == 0 {
      out.push(Instruction::table_size(TableIdx::new(0U)))
      return
    }
  }
  match vt {
    RefTypeValType(rt) => {
      let heap_type = rt.get_heap_type()
      if ValType::ref_type(rt) == ValType::funcref() {
        match env.declared_ref_func_idx {
          Some(func_idx) if ctx.random_bool() => {
            out.push(Instruction::ref_func(func_idx))
            return
          }
          _ => ()
        }
      }
      if vt == ValType::stringref() {
        match
          (
            env.gc_type_plan.string_wtf16_array_idx,
            env.gc_type_plan.string_utf8_array_idx,
          ) {
          (Some(string_wtf16_array_idx), _) if ctx.random_int(3) == 0 => {
            out.push(Instruction::i32_const(I32(4)))
            out.push(Instruction::array_new_default(string_wtf16_array_idx))
            out.push(Instruction::i32_const(I32(0)))
            out.push(Instruction::i32_const(I32(2)))
            out.push(Instruction::string_new_wtf16_array())
            return
          }
          (_, Some(string_utf8_array_idx)) if ctx.random_int(3) == 0 => {
            out.push(Instruction::i32_const(I32(16)))
            out.push(Instruction::array_new_default(string_utf8_array_idx))
            out.push(Instruction::i32_const(I32(0)))
            out.push(Instruction::i32_const(I32(4)))
            out.push(
              if ctx.random_bool() {
                Instruction::string_new_lossy_utf8_array()
              } else {
                Instruction::string_new_wtf8_array()
              },
            )
            return
          }
          _ => ()
        }
      }
      if vt == ValType::ref_null_exn() &&
        !env.tags.is_empty() &&
        ctx.random_int(3) == 0 {
        let tag_idx = TagIdx::new(0U)
        out.push(
          Instruction::try_table(
            BlockType::val_type(vt),
            [
              if ctx.random_bool() {
                Catch::ref_(tag_idx, LabelIdx::new(0U))
              } else {
                Catch::all_ref(LabelIdx::new(0U))
              },
            ],
            Expr::new([Instruction::throw_(tag_idx)]),
          ),
        )
        return
      }
      match heap_type {
        HeapType(type_idx) => {
          match
            (
              env.gc_type_plan.descriptor_struct_idx,
              env.gc_type_plan.descriptor_type_idx,
            ) {
            (Some(described_idx), Some(descriptor_idx)) if type_idx ==
              described_idx &&
              ctx.random_int(3) == 0 => {
              out.push(Instruction::struct_new_default(descriptor_idx))
              out.push(Instruction::struct_new_default_desc(described_idx))
              return
            }
            (Some(_described_idx), Some(descriptor_idx)) if type_idx ==
              descriptor_idx &&
              ctx.random_int(3) == 0 => {
              out.push(Instruction::struct_new_default(descriptor_idx))
              return
            }
            _ => ()
          }
          if gen_valid_contains_type_idx(
              env.gc_type_plan.struct_type_idxs,
              type_idx,
            ) &&
            ctx.random_int(3) == 0 {
            out.push(Instruction::struct_new_default(type_idx))
            return
          }
          match env.gc_type_plan.bulk_data_array_idx {
            Some(array_idx) if type_idx == array_idx &&
              ctx.random_int(4) == 0 &&
              gen_valid_append_array_data_seed_instrs(out, env) => return
            _ => ()
          }
          match env.gc_type_plan.bulk_elem_array_idx {
            Some(array_idx) if type_idx == array_idx &&
              ctx.random_int(4) == 0 &&
              gen_valid_append_array_elem_seed_instrs(out, env) => return
            _ => ()
          }
          if gen_valid_contains_type_idx(
              env.gc_type_plan.array_type_idxs,
              type_idx,
            ) &&
            ctx.random_int(3) == 0 {
            out.push(Instruction::i32_const(I32(1)))
            out.push(Instruction::array_new_default(type_idx))
            return
          }
        }
        _ => ()
      }
      if env.depth_left > 0 {
        if !rt.is_nullable() && ctx.random_int(4) == 0 {
          out.push(
            Instruction::block(
              BlockType::val_type(ValType::ref_type(rt)),
              Expr::new([
                Instruction::ref_null(heap_type),
                Instruction::br_on_non_null(LabelIdx::new(0U)),
                Instruction::ref_as_non_null(),
              ]),
            ),
          )
          return
        }
        if rt == RefType::abs(AbsHeapType::any()) && ctx.random_int(5) == 0 {
          out.push(
            Instruction::block(
              BlockType::val_type(ValType::ref_type(rt)),
              Expr::new([
                Instruction::ref_null(heap_type),
                Instruction::br_on_cast(
                  LabelIdx::new(0U),
                  true,
                  HeapType::abs(AbsHeapType::any()),
                  true,
                  HeapType::abs(AbsHeapType::i31()),
                ),
              ]),
            ),
          )
          return
        }
        if rt == RefType::abs(AbsHeapType::any()) && ctx.random_int(5) == 0 {
          out.push(
            Instruction::block(
              BlockType::val_type(ValType::ref_type(rt)),
              Expr::new([
                Instruction::ref_null(heap_type),
                Instruction::br_on_cast_fail(
                  LabelIdx::new(0U),
                  true,
                  HeapType::abs(AbsHeapType::any()),
                  true,
                  HeapType::abs(AbsHeapType::i31()),
                ),
              ]),
            ),
          )
          return
        }
      }
      out.push(
        if rt.is_exact() {
          Instruction::ref_null_type(rt)
        } else {
          Instruction::ref_null(heap_type)
        },
      )
    }
    _ => out.push(gen_const_instr(ctx, vt))
  }
}

///|
fn gen_valid_append_natural_exact_descriptor_stmt(
  out : Array[Instruction],
  env : GenValidBodyEnv,
) -> Bool {
  match
    (
      env.gc_type_plan.descriptor_struct_idx,
      env.gc_type_plan.descriptor_type_idx,
    ) {
    (Some(described_idx), Some(_descriptor_idx)) => {
      let exact_described = RefType::new(
        true,
        HeapType::new(described_idx),
        exact=true,
      )
      out.push(Instruction::ref_null_type(exact_described))
      out.push(Instruction::ref_get_desc(described_idx))
      out.push(Instruction::drop())
      out.push(Instruction::ref_null_type(exact_described))
      out.push(Instruction::ref_test_desc(true, HeapType::new(described_idx)))
      out.push(Instruction::drop())
      out.push(Instruction::ref_null_type(exact_described))
      out.push(
        Instruction::ref_cast_desc_eq(true, HeapType::new(described_idx)),
      )
      out.push(Instruction::drop())
      true
    }
    _ => false
  }
}

///|
fn gen_valid_append_natural_bulk_array_stmt(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Bool {
  match ctx.random_int(4) {
    0 =>
      if gen_valid_append_array_data_seed_instrs(out, env) {
        out.push(Instruction::drop())
        true
      } else if gen_valid_append_array_data_init_instrs(out, env) {
        true
      } else if gen_valid_append_array_elem_seed_instrs(out, env) {
        out.push(Instruction::drop())
        true
      } else if gen_valid_append_array_elem_init_instrs(out, env) {
        true
      } else {
        false
      }
    1 =>
      if gen_valid_append_array_elem_seed_instrs(out, env) {
        out.push(Instruction::drop())
        true
      } else if gen_valid_append_array_elem_init_instrs(out, env) {
        true
      } else if gen_valid_append_array_data_seed_instrs(out, env) {
        out.push(Instruction::drop())
        true
      } else if gen_valid_append_array_data_init_instrs(out, env) {
        true
      } else {
        false
      }
    2 =>
      if gen_valid_append_array_data_init_instrs(out, env) {
        true
      } else if gen_valid_append_array_data_seed_instrs(out, env) {
        out.push(Instruction::drop())
        true
      } else if gen_valid_append_array_elem_init_instrs(out, env) {
        true
      } else if gen_valid_append_array_elem_seed_instrs(out, env) {
        out.push(Instruction::drop())
        true
      } else {
        false
      }
    _ =>
      if gen_valid_append_array_elem_init_instrs(out, env) {
        true
      } else if gen_valid_append_array_elem_seed_instrs(out, env) {
        out.push(Instruction::drop())
        true
      } else if gen_valid_append_array_data_init_instrs(out, env) {
        true
      } else if gen_valid_append_array_data_seed_instrs(out, env) {
        out.push(Instruction::drop())
        true
      } else {
        false
      }
  }
}

///|
fn gen_valid_append_natural_mixed_catch_stmt(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Bool {
  if env.tags.is_empty() {
    return false
  }
  let tag_idx = TagIdx::new(0U)
  if ctx.random_bool() {
    out.push(
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::try_table(
            BlockType::void_(),
            [
              Catch::new(tag_idx, LabelIdx::new(0U)),
              Catch::all(LabelIdx::new(0U)),
            ],
            Expr::new([
              Instruction::i32_const(I32(1)),
              Instruction::if_(
                BlockType::void_(),
                [Instruction::throw_(tag_idx)],
                Some([
                  Instruction::ref_null(HeapType::abs(AbsHeapType::exn())),
                  Instruction::throw_ref(),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    )
    return true
  }
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  out.push(
    Instruction::block(
      BlockType::val_type(exnref),
      Expr::new([
        Instruction::try_table(
          BlockType::val_type(exnref),
          [
            Catch::ref_(tag_idx, LabelIdx::new(0U)),
            Catch::all_ref(LabelIdx::new(0U)),
          ],
          Expr::new([
            Instruction::block(
              BlockType::void_(),
              Expr::new([
                Instruction::i32_const(
                  I32(if ctx.random_bool() { 1 } else { 0 }),
                ),
                Instruction::br_if(LabelIdx::new(0U)),
              ]),
            ),
            Instruction::throw_(tag_idx),
          ]),
        ),
      ]),
    ),
  )
  out.push(Instruction::drop())
  true
}

///|
fn gen_valid_append_natural_gc_stmt(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Bool {
  if ctx.config.mode != Natural || !ctx.config.features.allow_ref_types {
    return false
  }
  match ctx.random_int(10) {
    0 =>
      match
        (
          env.gc_type_plan.descriptor_struct_idx,
          env.gc_type_plan.descriptor_type_idx,
        ) {
        (Some(described_idx), Some(descriptor_idx)) => {
          out.push(Instruction::struct_new_default(descriptor_idx))
          out.push(Instruction::struct_new_default_desc(described_idx))
          out.push(Instruction::ref_get_desc(described_idx))
          out.push(Instruction::drop())
          true
        }
        _ => false
      }
    1 => gen_valid_append_natural_exact_descriptor_stmt(out, env)
    2 =>
      match
        (
          env.gc_type_plan.descriptor_struct_idx,
          env.gc_type_plan.descriptor_type_idx,
        ) {
        (Some(described_idx), Some(descriptor_idx)) => {
          out.push(Instruction::struct_new_default(descriptor_idx))
          out.push(Instruction::struct_new_default_desc(described_idx))
          out.push(
            Instruction::ref_test_desc(true, HeapType::new(described_idx)),
          )
          out.push(Instruction::drop())
          out.push(Instruction::struct_new_default(descriptor_idx))
          out.push(Instruction::struct_new_default_desc(described_idx))
          out.push(
            Instruction::ref_cast_desc_eq(true, HeapType::new(described_idx)),
          )
          out.push(Instruction::drop())
          out.push(
            Instruction::block(
              BlockType::val_type(
                ValType::ref_type(
                  RefType::new(false, HeapType::new(descriptor_idx)),
                ),
              ),
              Expr::new([
                Instruction::ref_null(HeapType::new(descriptor_idx)),
                Instruction::br_on_non_null(LabelIdx::new(0U)),
                Instruction::unreachable_(),
              ]),
            ),
          )
          out.push(Instruction::drop())
          true
        }
        _ => false
      }
    3 =>
      match env.gc_type_plan.string_wtf16_array_idx {
        Some(string_wtf16_array_idx) => {
          out.push(Instruction::i32_const(I32(4)))
          out.push(Instruction::array_new_default(string_wtf16_array_idx))
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::i32_const(I32(2)))
          out.push(Instruction::string_new_wtf16_array())
          out.push(Instruction::drop())
          true
        }
        None => false
      }
    4 =>
      match env.gc_type_plan.string_utf8_array_idx {
        Some(string_utf8_array_idx) => {
          out.push(Instruction::string_const(b"gen-valid-string"))
          out.push(Instruction::i32_const(I32(16)))
          out.push(Instruction::array_new_default(string_utf8_array_idx))
          out.push(Instruction::i32_const(I32(0)))
          if ctx.random_bool() {
            out.push(Instruction::string_encode_utf8_array())
          } else if ctx.random_bool() {
            out.push(Instruction::string_encode_lossy_utf8_array())
          } else {
            out.push(Instruction::string_encode_wtf8_array())
          }
          out.push(Instruction::drop())

          out.push(Instruction::i32_const(I32(16)))
          out.push(Instruction::array_new_default(string_utf8_array_idx))
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::i32_const(I32(4)))
          if ctx.random_bool() {
            out.push(Instruction::string_new_lossy_utf8_array())
          } else {
            out.push(Instruction::string_new_wtf8_array())
          }
          out.push(Instruction::drop())
          true
        }
        None => false
      }
    5 => gen_valid_append_natural_bulk_array_stmt(out, ctx, env)
    6 => {
      out.push(
        Instruction::block(
          BlockType::val_type(
            ValType::ref_type(RefType::abs(AbsHeapType::any())),
          ),
          Expr::new([
            Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
            Instruction::br_on_cast(
              LabelIdx::new(0U),
              true,
              HeapType::abs(AbsHeapType::any()),
              true,
              HeapType::abs(AbsHeapType::i31()),
            ),
          ]),
        ),
      )
      out.push(Instruction::drop())
      out.push(
        Instruction::block(
          BlockType::val_type(
            ValType::ref_type(RefType::abs(AbsHeapType::any())),
          ),
          Expr::new([
            Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
            Instruction::br_on_cast_fail(
              LabelIdx::new(0U),
              true,
              HeapType::abs(AbsHeapType::any()),
              true,
              HeapType::abs(AbsHeapType::i31()),
            ),
          ]),
        ),
      )
      out.push(Instruction::drop())
      true
    }
    7 =>
      if !env.tags.is_empty() {
        let tag_idx = TagIdx::new(0U)
        let exnref = ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::exn())),
        )
        out.push(
          Instruction::block(
            BlockType::void_(),
            Expr::new([
              Instruction::try_table(
                BlockType::void_(),
                [Catch::new(tag_idx, LabelIdx::new(0U))],
                Expr::new([Instruction::throw_(tag_idx)]),
              ),
            ]),
          ),
        )
        out.push(
          Instruction::block(
            BlockType::val_type(exnref),
            Expr::new([
              Instruction::try_table(
                BlockType::val_type(exnref),
                [Catch::ref_(tag_idx, LabelIdx::new(0U))],
                Expr::new([Instruction::throw_(tag_idx)]),
              ),
            ]),
          ),
        )
        out.push(Instruction::drop())
        out.push(
          Instruction::block(
            BlockType::val_type(exnref),
            Expr::new([
              Instruction::try_table(
                BlockType::val_type(exnref),
                [Catch::all_ref(LabelIdx::new(0U))],
                Expr::new([Instruction::throw_(tag_idx)]),
              ),
            ]),
          ),
        )
        out.push(Instruction::drop())
        true
      } else {
        false
      }
    8 => gen_valid_append_natural_mixed_catch_stmt(out, ctx, env)
    _ => {
      out.push(
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::try_table(
              BlockType::void_(),
              [Catch::all(LabelIdx::new(0U))],
              Expr::new([
                Instruction::ref_null(HeapType::abs(AbsHeapType::exn())),
                Instruction::throw_ref(),
              ]),
            ),
          ]),
        ),
      )
      true
    }
  }
}

///|
fn append_void_stmt(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  let branchy = ctx.config.features.allow_branch_heavy_control
  match ctx.random_int(if branchy { 14 } else { 10 }) {
    0 => out.push(Instruction::nop())
    1 => {
      let vt = gen_valid_valtype(ctx)
      append_value_instrs(out, ctx, vt, env, prefer_local=false)
      out.push(Instruction::drop())
    }
    2 =>
      if env.local_types.is_empty() {
        out.push(Instruction::nop())
      } else {
        let idx = ctx.random_int(env.local_types.length())
        let vt = env.local_types[idx]
        if ctx.config.mode == CoverageForced {
          out.push(gen_const_instr(ctx, vt))
        } else {
          append_value_instrs(
            out,
            ctx,
            vt,
            gen_valid_body_env_child(env),
            prefer_local=false,
          )
        }
        out.push(
          Instruction::local_set(LocalIdx::new(idx.reinterpret_as_uint())),
        )
      }
    3 =>
      match
        gen_matching_global_idx(
          env.globals,
          gen_valid_valtype(ctx),
          mutable_only=true,
        ) {
        Some(idx) => {
          let GlobalIdx(idx_u) = idx
          let GlobalType(vt, _) = env.globals[idx_u.reinterpret_as_int()]
          if ctx.config.mode == CoverageForced {
            out.push(gen_const_instr(ctx, vt))
          } else {
            append_value_instrs(
              out,
              ctx,
              vt,
              gen_valid_body_env_child(env),
              prefer_local=false,
            )
          }
          out.push(Instruction::global_set(idx))
        }
        None => out.push(Instruction::nop())
      }
    4 =>
      if ctx.config.features.allow_calls {
        match gen_valid_pick_callable(ctx, env.funcs) {
          Some(target) => {
            gen_valid_append_call_args(out, ctx, env, target.params)
            out.push(Instruction::call(target.idx))
            gen_valid_append_call_result_drops(out, target.results)
          }
          None => out.push(Instruction::nop())
        }
      } else {
        out.push(Instruction::nop())
      }
    5 =>
      if ctx.config.features.allow_call_indirect && !env.tables.is_empty() {
        match gen_valid_pick_callable(ctx, env.funcs) {
          Some(target) => {
            gen_valid_append_call_args(out, ctx, env, target.params)
            out.push(Instruction::i32_const(I32(0)))
            out.push(
              Instruction::call_indirect(target.type_idx, TableIdx::new(0U)),
            )
            gen_valid_append_call_result_drops(out, target.results)
          }
          None => out.push(Instruction::nop())
        }
      } else {
        out.push(Instruction::nop())
      }
    6 =>
      if !env.mems.is_empty() {
        out.push(Instruction::memory_size(MemIdx::new(0U)))
        out.push(Instruction::drop())
        gen_valid_append_scalar_memory_ops(out)
      } else {
        out.push(Instruction::nop())
      }
    7 =>
      if !env.tables.is_empty() {
        let TableType(rt, _) = env.tables[0]
        out.push(Instruction::table_size(TableIdx::new(0U)))
        out.push(Instruction::drop())
        out.push(Instruction::i32_const(I32(0)))
        gen_valid_append_table_ref_value(out, ctx, env, rt)
        out.push(Instruction::table_set(TableIdx::new(0U)))
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::table_get(TableIdx::new(0U)))
        out.push(Instruction::drop())
      } else {
        out.push(Instruction::nop())
      }
    8 =>
      if !gen_valid_append_memory_bulk_ops(out, ctx, env) {
        out.push(Instruction::nop())
      }
    9 =>
      if !gen_valid_append_table_bulk_ops(out, ctx, env) {
        out.push(Instruction::nop())
      }
    10 => {
      let body : Array[Instruction] = []
      gen_valid_append_nested_void_instrs(body, ctx, env)
      out.push(Instruction::block(BlockType::void_(), Expr::new(body)))
    }
    11 => {
      let body : Array[Instruction] = []
      gen_valid_append_nested_void_instrs(body, ctx, env)
      if branchy {
        body.push(
          Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
        )
        body.push(Instruction::br_if(LabelIdx::new(0U)))
      }
      out.push(Instruction::loop_(BlockType::void_(), Expr::new(body)))
    }
    12 => {
      let then_body : Array[Instruction] = []
      let else_body : Array[Instruction] = []
      let child = gen_valid_body_env_child(env)
      let branch_stmt_count = gen_valid_body_stmt_count(ctx, child.depth_left)
      for _ in 0..<branch_stmt_count {
        append_void_stmt(then_body, ctx, child)
        append_void_stmt(else_body, ctx, child)
      }
      out.push(
        Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
      )
      out.push(Instruction::if_(BlockType::void_(), then_body, Some(else_body)))
    }
    _ =>
      if branchy && env.label_depth > 0 {
        if ctx.random_bool() {
          out.push(
            Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
          )
          out.push(Instruction::br_if(LabelIdx::new(0U)))
        } else {
          out.push(Instruction::br(LabelIdx::new(0U)))
        }
      } else {
        out.push(Instruction::nop())
      }
  }
}

///|
fn gen_valid_append_gc_prelude(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !ctx.config.features.allow_ref_types {
    return
  }
  if !env.gc_type_plan.struct_type_idxs.is_empty() {
    let struct_idx = env.gc_type_plan.struct_type_idxs[0]
    out.push(Instruction::i32_const(I32(42)))
    out.push(Instruction::ref_null(HeapType::abs(AbsHeapType::eq())))
    out.push(Instruction::struct_new(struct_idx))
    out.push(Instruction::struct_get(struct_idx, U32::new(0U)))
    out.push(Instruction::drop())

    out.push(Instruction::struct_new_default(struct_idx))
    out.push(Instruction::i32_const(I32(1)))
    out.push(Instruction::struct_set(struct_idx, U32::new(0U)))

    out.push(Instruction::ref_null(HeapType::abs(AbsHeapType::any())))
    out.push(Instruction::ref_test(true, HeapType::abs(AbsHeapType::eq())))
    out.push(Instruction::drop())

    out.push(Instruction::ref_null(HeapType::abs(AbsHeapType::any())))
    out.push(Instruction::ref_cast(true, HeapType::abs(AbsHeapType::eq())))
    out.push(Instruction::drop())

    out.push(Instruction::ref_null(HeapType::abs(AbsHeapType::any())))
    out.push(Instruction::ref_as_non_null())
    out.push(Instruction::drop())

    out.push(Instruction::struct_new_default(struct_idx))
    out.push(Instruction::struct_new_default(struct_idx))
    out.push(Instruction::ref_eq())
    out.push(Instruction::drop())

    out.push(
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::ref_null(HeapType::new(struct_idx)),
          Instruction::br_on_null(LabelIdx::new(0U)),
          Instruction::drop(),
        ]),
      ),
    )
  }

  match env.gc_type_plan.packed_struct_idx {
    Some(packed_struct_idx) => {
      out.push(Instruction::i32_const(I32(1)))
      out.push(Instruction::i32_const(I32(2)))
      out.push(Instruction::struct_new(packed_struct_idx))
      out.push(Instruction::struct_get_s(packed_struct_idx, U32::new(0U)))
      out.push(Instruction::drop())

      out.push(Instruction::i32_const(I32(3)))
      out.push(Instruction::i32_const(I32(4)))
      out.push(Instruction::struct_new(packed_struct_idx))
      out.push(Instruction::struct_get_u(packed_struct_idx, U32::new(1U)))
      out.push(Instruction::drop())
    }
    None => ()
  }

  match
    (
      env.gc_type_plan.descriptor_struct_idx,
      env.gc_type_plan.descriptor_type_idx,
    ) {
    (Some(described_idx), Some(descriptor_idx)) => {
      out.push(Instruction::struct_new_default(descriptor_idx))
      out.push(Instruction::struct_new_default_desc(described_idx))
      out.push(Instruction::ref_get_desc(described_idx))
      out.push(Instruction::drop())

      out.push(Instruction::struct_new_default(descriptor_idx))
      out.push(Instruction::struct_new_default_desc(described_idx))
      out.push(Instruction::ref_test_desc(true, HeapType::new(described_idx)))
      out.push(Instruction::drop())

      out.push(Instruction::struct_new_default(descriptor_idx))
      out.push(Instruction::struct_new_default_desc(described_idx))
      out.push(
        Instruction::ref_cast_desc_eq(true, HeapType::new(described_idx)),
      )
      out.push(Instruction::drop())

      out.push(
        Instruction::block(
          BlockType::val_type(
            ValType::ref_type(
              RefType::new(false, HeapType::new(descriptor_idx)),
            ),
          ),
          Expr::new([
            Instruction::ref_null(HeapType::new(descriptor_idx)),
            Instruction::br_on_non_null(LabelIdx::new(0U)),
            Instruction::unreachable_(),
          ]),
        ),
      )
      out.push(Instruction::drop())
    }
    _ => ()
  }

  if !env.gc_type_plan.array_type_idxs.is_empty() {
    let array_idx = env.gc_type_plan.array_type_idxs[0]
    out.push(Instruction::i32_const(I32(9)))
    out.push(Instruction::i32_const(I32(2)))
    out.push(Instruction::array_new(array_idx))
    out.push(Instruction::array_len())
    out.push(Instruction::drop())

    out.push(Instruction::i32_const(I32(5)))
    out.push(Instruction::i32_const(I32(6)))
    out.push(Instruction::array_new_fixed(array_idx, U32::new(2U)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::array_get(array_idx))
    out.push(Instruction::drop())

    out.push(Instruction::i32_const(I32(2)))
    out.push(Instruction::array_new_default(array_idx))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(7)))
    out.push(Instruction::array_set(array_idx))

    out.push(Instruction::i32_const(I32(2)))
    out.push(Instruction::array_new_default(array_idx))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(8)))
    out.push(Instruction::i32_const(I32(1)))
    out.push(Instruction::array_fill(array_idx))

    out.push(Instruction::i32_const(I32(2)))
    out.push(Instruction::array_new_default(array_idx))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(2)))
    out.push(Instruction::array_new_default(array_idx))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(1)))
    out.push(Instruction::array_copy(array_idx, array_idx))
  }

  match env.gc_type_plan.packed_i8_array_idx {
    Some(packed_i8_array_idx) => {
      out.push(Instruction::i32_const(I32(11)))
      out.push(Instruction::i32_const(I32(1)))
      out.push(Instruction::array_new(packed_i8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::array_get_s(packed_i8_array_idx))
      out.push(Instruction::drop())
    }
    None => ()
  }

  match env.gc_type_plan.packed_i16_array_idx {
    Some(packed_i16_array_idx) => {
      out.push(Instruction::i32_const(I32(12)))
      out.push(Instruction::i32_const(I32(1)))
      out.push(Instruction::array_new(packed_i16_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::array_get_u(packed_i16_array_idx))
      out.push(Instruction::drop())
    }
    None => ()
  }

  match env.gc_type_plan.string_wtf16_array_idx {
    Some(string_wtf16_array_idx) => {
      out.push(Instruction::i32_const(I32(4)))
      out.push(Instruction::array_new_default(string_wtf16_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(2)))
      out.push(Instruction::string_new_wtf16_array())
      out.push(Instruction::drop())
    }
    None => ()
  }

  match env.gc_type_plan.string_utf8_array_idx {
    Some(string_utf8_array_idx) => {
      out.push(Instruction::string_const(b"gen-valid-string"))
      out.push(Instruction::i32_const(I32(16)))
      out.push(Instruction::array_new_default(string_utf8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::string_encode_utf8_array())
      out.push(Instruction::drop())

      out.push(Instruction::i32_const(I32(16)))
      out.push(Instruction::array_new_default(string_utf8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(4)))
      out.push(Instruction::string_new_lossy_utf8_array())
      out.push(Instruction::drop())

      out.push(Instruction::i32_const(I32(16)))
      out.push(Instruction::array_new_default(string_utf8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(4)))
      out.push(Instruction::string_new_wtf8_array())
      out.push(Instruction::drop())

      out.push(Instruction::string_const(b"gen-valid-string"))
      out.push(Instruction::i32_const(I32(16)))
      out.push(Instruction::array_new_default(string_utf8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::string_encode_lossy_utf8_array())
      out.push(Instruction::drop())

      out.push(Instruction::string_const(b"gen-valid-string"))
      out.push(Instruction::i32_const(I32(16)))
      out.push(Instruction::array_new_default(string_utf8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::string_encode_wtf8_array())
      out.push(Instruction::drop())
    }
    None => ()
  }

  out.push(
    Instruction::block(
      BlockType::val_type(ValType::ref_type(RefType::abs(AbsHeapType::any()))),
      Expr::new([
        Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
        Instruction::br_on_cast(
          LabelIdx::new(0U),
          true,
          HeapType::abs(AbsHeapType::any()),
          true,
          HeapType::abs(AbsHeapType::i31()),
        ),
      ]),
    ),
  )
  out.push(Instruction::drop())

  out.push(
    Instruction::block(
      BlockType::val_type(ValType::ref_type(RefType::abs(AbsHeapType::any()))),
      Expr::new([
        Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
        Instruction::br_on_cast_fail(
          LabelIdx::new(0U),
          true,
          HeapType::abs(AbsHeapType::any()),
          true,
          HeapType::abs(AbsHeapType::i31()),
        ),
      ]),
    ),
  )
  out.push(Instruction::drop())

  if !env.tags.is_empty() {
    let tag_idx = TagIdx::new(0U)
    let exnref = ValType::ref_type(
      RefType::new(false, HeapType::abs(AbsHeapType::exn())),
    )
    out.push(
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::try_table(
            BlockType::void_(),
            [Catch::new(tag_idx, LabelIdx::new(0U))],
            Expr::new([Instruction::throw_(tag_idx)]),
          ),
        ]),
      ),
    )

    out.push(
      Instruction::block(
        BlockType::val_type(exnref),
        Expr::new([
          Instruction::try_table(
            BlockType::val_type(exnref),
            [Catch::ref_(tag_idx, LabelIdx::new(0U))],
            Expr::new([Instruction::throw_(tag_idx)]),
          ),
        ]),
      ),
    )
    out.push(Instruction::drop())

    out.push(
      Instruction::block(
        BlockType::val_type(exnref),
        Expr::new([
          Instruction::try_table(
            BlockType::val_type(exnref),
            [Catch::all_ref(LabelIdx::new(0U))],
            Expr::new([Instruction::throw_(tag_idx)]),
          ),
        ]),
      ),
    )
    out.push(Instruction::drop())
  }

  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::try_table(
          BlockType::void_(),
          [Catch::all(LabelIdx::new(0U))],
          Expr::new([
            Instruction::ref_null(HeapType::abs(AbsHeapType::exn())),
            Instruction::throw_ref(),
          ]),
        ),
      ]),
    ),
  )

  match env.declared_ref_func_idx {
    Some(func_idx) =>
      match gen_valid_callable_by_idx(env.funcs, func_idx) {
        Some(target) => {
          gen_valid_append_call_args(out, ctx, env, target.params)
          out.push(Instruction::ref_func(func_idx))
          out.push(Instruction::call_ref(target.type_idx))
          gen_valid_append_call_result_drops(out, target.results)
        }
        None => ()
      }
    None => ()
  }
}

///|
fn gen_valid_append_scalar_numeric_drop(
  out : Array[Instruction],
  instrs : Array[Instruction],
) -> Unit {
  for instr in instrs {
    out.push(instr)
  }
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_numeric_boundary_constants(
  out : Array[Instruction],
  ctx : GenValidContext,
) -> Unit {
  let i32_boundary_constants = [0, 1, -1, -2147483647 - 1, 2147483647, 1024]
  for value in i32_boundary_constants {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::i32_const(I32(value)),
    ])
  }
  let i64_boundary_constants = [
    0L,
    1L,
    -1L,
    -9223372036854775807L - 1L,
    9223372036854775807L,
    1099511627776L,
  ]
  for value in i64_boundary_constants {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::i64_const(I64(value)),
    ])
  }
  let f32_boundary_constants = [0x80000000U, 0x7f800000U, 0xff800000U]
  for bits in f32_boundary_constants {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::f32_const(F32(Float::reinterpret_from_uint(bits))),
    ])
  }
  let f64_boundary_constants = [
    0x8000000000000000UL, 0x7ff0000000000000UL, 0xfff0000000000000UL,
  ]
  for bits in f64_boundary_constants {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::f64_const(F64(bits.reinterpret_as_double())),
    ])
  }
  // NaN payloads intentionally stay out of the Binaryen-oracle compatibility
  // wrapper profile because MoonBit float equality treats NaNs as unequal,
  // which would make two byte-identical generated modules fail structural Eq.
  if ctx.config != GenValidConfig::binaryen_oracle_coverage_forced_default() {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::f32_const(F32(Float::reinterpret_from_uint(0x7fc00001U))),
    ])
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::f64_const(F64(0x7ff8000000000001UL.reinterpret_as_double())),
    ])
  }
}

///|
fn gen_valid_append_typed_select(
  out : Array[Instruction],
  ctx : GenValidContext,
  vt : ValType,
) -> Unit {
  out.push(gen_const_instr(ctx, vt))
  out.push(gen_const_instr(ctx, vt))
  out.push(Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })))
  out.push(Instruction::select(types=Some([vt])))
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_core_control_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !ctx.config.features.allow_branch_heavy_control {
    return
  }

  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(1)),
        Instruction::br_table([LabelIdx::new(0U)], LabelIdx::new(0U)),
      ]),
    ),
  )

  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([Instruction::unreachable_()]),
    ),
  )

  match gen_matching_local_idx(env.local_types, ValType::i32()) {
    Some(idx) => {
      out.push(Instruction::i32_const(I32(7)))
      out.push(Instruction::local_tee(idx))
      out.push(Instruction::drop())
    }
    None => ()
  }

  for
    vt in [
      ValType::i32(),
      ValType::i64(),
      ValType::f32(),
      ValType::f64(),
      ValType::v128(),
      ValType::funcref(),
    ] {
    gen_valid_append_typed_select(out, ctx, vt)
  }
}

///|
fn gen_valid_append_call_ref_source_variants(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !ctx.config.features.allow_ref_types {
    return
  }
  match env.declared_ref_func_idx {
    Some(func_idx) =>
      match gen_valid_callable_by_idx(env.funcs, func_idx) {
        Some(target) => {
          let fref = ValType::ref_type(
            RefType::new(true, HeapType::new(target.type_idx)),
          )
          match gen_matching_local_idx(env.local_types, fref) {
            Some(local_idx) => {
              gen_valid_append_call_args(out, ctx, env, target.params)
              out.push(Instruction::ref_func(target.idx))
              out.push(Instruction::local_set(local_idx))
              out.push(Instruction::local_get(local_idx))
              out.push(Instruction::call_ref(target.type_idx))
              gen_valid_append_call_result_drops(out, target.results)
            }
            None => ()
          }
          gen_valid_append_call_args(out, ctx, env, target.params)
          out.push(
            Instruction::block(
              BlockType::val_type(fref),
              Expr::new([Instruction::ref_func(target.idx)]),
            ),
          )
          out.push(Instruction::call_ref(target.type_idx))
          gen_valid_append_call_result_drops(out, target.results)
          match gen_matching_global_idx(env.globals, fref) {
            Some(global_idx) => {
              gen_valid_append_call_args(out, ctx, env, target.params)
              out.push(Instruction::global_get(global_idx))
              out.push(Instruction::call_ref(target.type_idx))
              gen_valid_append_call_result_drops(out, target.results)
            }
            None => ()
          }
        }
        None => ()
      }
    None => ()
  }
  for i = 0; i < env.tables.length(); i = i + 1 {
    let TableType(rt, _) = env.tables[i]
    match gen_valid_func_type_idx_from_ref_type(rt) {
      Some(type_idx) =>
        for target in env.funcs {
          if target.type_idx == type_idx {
            gen_valid_append_call_args(out, ctx, env, target.params)
            out.push(Instruction::i32_const(I32(0)))
            out.push(
              Instruction::table_get(TableIdx::new(i.reinterpret_as_uint())),
            )
            out.push(Instruction::call_ref(target.type_idx))
            gen_valid_append_call_result_drops(out, target.results)
            return
          }
        }
      None => ()
    }
  }
  match gen_valid_first_nonzero_funcref_table_idx(env.tables) {
    Some(table_idx) =>
      match gen_valid_pick_callable(ctx, env.funcs) {
        Some(target) => {
          gen_valid_append_call_args(out, ctx, env, target.params)
          out.push(Instruction::i32_const(I32(1)))
          out.push(Instruction::table_get(table_idx))
          out.push(Instruction::ref_cast(false, HeapType::new(target.type_idx)))
          out.push(Instruction::call_ref(target.type_idx))
          gen_valid_append_call_result_drops(out, target.results)
        }
        None => ()
      }
    None => ()
  }
}

///|
fn gen_valid_append_direct_call_graph_variants(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !ctx.config.features.allow_calls {
    return
  }
  match env.declared_ref_func_idx {
    Some(first_defined_idx) => {
      let first_defined_i = gen_valid_func_idx_to_int(first_defined_idx)
      for target in env.funcs {
        if gen_valid_func_idx_to_int(target.idx) < first_defined_i {
          gen_valid_append_direct_call(out, ctx, env, target)
          break
        }
      }
    }
    None => ()
  }
  match env.current_func_idx {
    Some(current_idx) => {
      match gen_valid_callable_by_idx(env.funcs, current_idx) {
        Some(target) => gen_valid_append_direct_call(out, ctx, env, target)
        None => ()
      }
      match env.declared_ref_func_idx {
        Some(first_defined_idx) => {
          let current_i = gen_valid_func_idx_to_int(current_idx)
          let first_defined_i = gen_valid_func_idx_to_int(first_defined_idx)
          if current_i == first_defined_i {
            let next_idx = FuncIdx::new((current_i + 1).reinterpret_as_uint())
            match gen_valid_callable_by_idx(env.funcs, next_idx) {
              Some(target) =>
                gen_valid_append_direct_call(out, ctx, env, target)
              None => ()
            }
          } else if current_i == first_defined_i + 1 {
            match gen_valid_callable_by_idx(env.funcs, first_defined_idx) {
              Some(target) =>
                gen_valid_append_direct_call(out, ctx, env, target)
              None => ()
            }
          }
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
fn gen_valid_funcref_table_indices(
  tables : Array[TableType],
) -> Array[TableIdx] {
  let result : Array[TableIdx] = []
  for i = 0; i < tables.length(); i = i + 1 {
    let TableType(rt, _) = tables[i]
    if ValType::ref_type(rt) == ValType::funcref() {
      result.push(TableIdx::new(i.reinterpret_as_uint()))
    }
  }
  result
}

///|
fn gen_valid_first_nonzero_funcref_table_idx(
  tables : Array[TableType],
) -> TableIdx? {
  for i = 1; i < tables.length(); i = i + 1 {
    let TableType(rt, _) = tables[i]
    if ValType::ref_type(rt) == ValType::funcref() {
      return Some(TableIdx::new(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
fn gen_valid_append_call_indirect_variants(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !ctx.config.features.allow_call_indirect || env.tables.is_empty() {
    return
  }
  let funcref_tables = gen_valid_funcref_table_indices(env.tables)
  if funcref_tables.is_empty() {
    return
  }
  let primary_table = funcref_tables[0]
  match gen_valid_pick_callable(ctx, env.funcs) {
    Some(target) => {
      gen_valid_append_call_args(out, ctx, env, target.params)
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::call_indirect(target.type_idx, primary_table))
      gen_valid_append_call_result_drops(out, target.results)
      gen_valid_append_call_args(out, ctx, env, target.params)
      out.push(Instruction::i32_const(I32(1)))
      out.push(Instruction::call_indirect(target.type_idx, primary_table))
      gen_valid_append_call_result_drops(out, target.results)
      match gen_valid_first_nonzero_funcref_table_idx(env.tables) {
        Some(nonzero_table) => {
          gen_valid_append_call_args(out, ctx, env, target.params)
          out.push(Instruction::i32_const(I32(1)))
          out.push(Instruction::call_indirect(target.type_idx, nonzero_table))
          gen_valid_append_call_result_drops(out, target.results)
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
fn gen_valid_append_nested_tail_call_variants(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  returns : Array[ValType],
) -> Unit {
  if !ctx.config.features.allow_tail_calls || !ctx.config.features.allow_calls {
    return
  }
  match gen_valid_pick_callable_with_results(ctx, env.funcs, returns) {
    Some(target) => {
      let nested : Array[Instruction] = []
      gen_valid_append_call_args(nested, ctx, env, target.params)
      nested.push(Instruction::return_call(target.idx))
      out.push(Instruction::block(BlockType::void_(), Expr::new(nested)))
      let then_tail : Array[Instruction] = []
      gen_valid_append_call_args(then_tail, ctx, env, target.params)
      then_tail.push(Instruction::return_call(target.idx))
      let else_tail : Array[Instruction] = []
      gen_valid_append_call_args(else_tail, ctx, env, target.params)
      else_tail.push(Instruction::return_call(target.idx))
      out.push(
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::if_(BlockType::void_(), then_tail, Some(else_tail)),
          ]),
        ),
      )
    }
    None => ()
  }
  if ctx.config.features.allow_call_indirect && !env.tables.is_empty() {
    let TableType(rt, _) = env.tables[0]
    if ValType::ref_type(rt) == ValType::funcref() {
      match gen_valid_pick_callable_with_results(ctx, env.funcs, returns) {
        Some(target) => {
          let nested : Array[Instruction] = []
          gen_valid_append_call_args(nested, ctx, env, target.params)
          nested.push(Instruction::i32_const(I32(1)))
          nested.push(
            Instruction::return_call_indirect(
              target.type_idx,
              TableIdx::new(0U),
            ),
          )
          out.push(Instruction::block(BlockType::void_(), Expr::new(nested)))
        }
        None => ()
      }
    }
  }
  if ctx.config.features.allow_ref_types {
    match
      gen_valid_declared_ref_callable_with_results(
        env.funcs,
        env.declared_ref_func_idx,
        returns,
      ) {
      Some(target) => {
        let fref = ValType::ref_type(
          RefType::new(true, HeapType::new(target.type_idx)),
        )
        let nested : Array[Instruction] = []
        gen_valid_append_call_args(nested, ctx, env, target.params)
        nested.push(
          Instruction::block(
            BlockType::val_type(fref),
            Expr::new([Instruction::ref_func(target.idx)]),
          ),
        )
        nested.push(Instruction::return_call_ref(target.type_idx))
        out.push(Instruction::block(BlockType::void_(), Expr::new(nested)))
      }
      None => ()
    }
  }
}

///|
fn gen_valid_append_tail_call_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  returns : Array[ValType],
) -> Unit {
  if !ctx.config.features.allow_tail_calls {
    return
  }
  match gen_valid_pick_callable_with_results(ctx, env.funcs, returns) {
    Some(target) if ctx.config.features.allow_calls => {
      gen_valid_append_call_args(out, ctx, env, target.params)
      out.push(Instruction::return_call(target.idx))
    }
    _ => ()
  }
  if ctx.config.features.allow_call_indirect && !env.tables.is_empty() {
    let TableType(rt, _) = env.tables[0]
    if ValType::ref_type(rt) == ValType::funcref() {
      match gen_valid_pick_callable_with_results(ctx, env.funcs, returns) {
        Some(target) => {
          gen_valid_append_call_args(out, ctx, env, target.params)
          out.push(Instruction::i32_const(I32(0)))
          out.push(
            Instruction::return_call_indirect(
              target.type_idx,
              TableIdx::new(0U),
            ),
          )
        }
        _ => ()
      }
    }
  }
  if ctx.config.features.allow_ref_types {
    match
      gen_valid_declared_ref_callable_with_results(
        env.funcs,
        env.declared_ref_func_idx,
        returns,
      ) {
      Some(target) => {
        gen_valid_append_call_args(out, ctx, env, target.params)
        out.push(Instruction::ref_func(target.idx))
        out.push(Instruction::return_call_ref(target.type_idx))
      }
      None => ()
    }
  }
}

///|
fn gen_valid_append_expanded_scalar_numeric_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
) -> Unit {
  gen_valid_append_numeric_boundary_constants(out, ctx)
  gen_valid_append_scalar_numeric_drop(out, [
    Instruction::i32_const(I32(0)),
    Instruction::i32_eqz(),
  ])
  let i32_unary_ops = [
    Instruction::i32_clz(),
    Instruction::i32_ctz(),
    Instruction::i32_popcnt(),
  ]
  for op in i32_unary_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::i32_const(I32(84)),
      op,
    ])
  }
  let i32_cmp_ops = [
    Instruction::i32_eq(),
    Instruction::i32_ne(),
    Instruction::i32_lt_s(),
    Instruction::i32_lt_u(),
    Instruction::i32_gt_s(),
    Instruction::i32_gt_u(),
    Instruction::i32_le_s(),
    Instruction::i32_le_u(),
    Instruction::i32_ge_s(),
    Instruction::i32_ge_u(),
  ]
  for op in i32_cmp_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::i32_const(I32(11)),
      Instruction::i32_const(I32(3)),
      op,
    ])
  }
  let i32_binary_ops = [
    Instruction::i32_add(),
    Instruction::i32_sub(),
    Instruction::i32_mul(),
    Instruction::i32_div_s(),
    Instruction::i32_div_u(),
    Instruction::i32_rem_s(),
    Instruction::i32_rem_u(),
    Instruction::i32_and(),
    Instruction::i32_or(),
    Instruction::i32_xor(),
    Instruction::i32_shl(),
    Instruction::i32_shr_s(),
    Instruction::i32_shr_u(),
    Instruction::i32_rotl(),
    Instruction::i32_rotr(),
  ]
  for op in i32_binary_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::i32_const(I32(84)),
      Instruction::i32_const(I32(3)),
      op,
    ])
  }

  gen_valid_append_scalar_numeric_drop(out, [
    Instruction::i64_const(I64(0L)),
    Instruction::i64_eqz(),
  ])
  let i64_unary_ops = [
    Instruction::i64_clz(),
    Instruction::i64_ctz(),
    Instruction::i64_popcnt(),
  ]
  for op in i64_unary_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::i64_const(I64(99L)),
      op,
    ])
  }
  let i64_cmp_ops = [
    Instruction::i64_eq(),
    Instruction::i64_ne(),
    Instruction::i64_lt_s(),
    Instruction::i64_lt_u(),
    Instruction::i64_gt_s(),
    Instruction::i64_gt_u(),
    Instruction::i64_le_s(),
    Instruction::i64_le_u(),
    Instruction::i64_ge_s(),
    Instruction::i64_ge_u(),
  ]
  for op in i64_cmp_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::i64_const(I64(99L)),
      Instruction::i64_const(I64(5L)),
      op,
    ])
  }
  let i64_int_ops = [
    Instruction::i64_add(),
    Instruction::i64_sub(),
    Instruction::i64_mul(),
    Instruction::i64_div_s(),
    Instruction::i64_div_u(),
    Instruction::i64_rem_s(),
    Instruction::i64_rem_u(),
    Instruction::i64_and(),
    Instruction::i64_or(),
    Instruction::i64_xor(),
  ]
  for op in i64_int_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::i64_const(I64(99L)),
      Instruction::i64_const(I64(5L)),
      op,
    ])
  }
  let i64_shift_ops = [
    Instruction::i64_shl(),
    Instruction::i64_shr_s(),
    Instruction::i64_shr_u(),
    Instruction::i64_rotl(),
    Instruction::i64_rotr(),
  ]
  for op in i64_shift_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::i64_const(I64(99L)),
      Instruction::i64_const(I64(5L)),
      op,
    ])
  }

  let f32_unary_ops = [
    Instruction::f32_abs(),
    Instruction::f32_neg(),
    Instruction::f32_ceil(),
    Instruction::f32_floor(),
    Instruction::f32_trunc(),
    Instruction::f32_nearest(),
    Instruction::f32_sqrt(),
  ]
  for op in f32_unary_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::f32_const(F32(Float::from_double(9.25))),
      op,
    ])
  }
  let f32_binary_ops = [
    Instruction::f32_add(),
    Instruction::f32_sub(),
    Instruction::f32_mul(),
    Instruction::f32_div(),
    Instruction::f32_min(),
    Instruction::f32_max(),
    Instruction::f32_copysign(),
  ]
  for op in f32_binary_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::f32_const(F32(Float::from_double(9.25))),
      Instruction::f32_const(F32(Float::from_double(2.5))),
      op,
    ])
  }
  let f32_cmp_ops = [
    Instruction::f32_eq(),
    Instruction::f32_ne(),
    Instruction::f32_lt(),
    Instruction::f32_gt(),
    Instruction::f32_le(),
    Instruction::f32_ge(),
  ]
  for op in f32_cmp_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::f32_const(F32(Float::from_double(9.25))),
      Instruction::f32_const(F32(Float::from_double(2.5))),
      op,
    ])
  }

  let f64_unary_ops = [
    Instruction::f64_abs(),
    Instruction::f64_neg(),
    Instruction::f64_ceil(),
    Instruction::f64_floor(),
    Instruction::f64_trunc(),
    Instruction::f64_nearest(),
    Instruction::f64_sqrt(),
  ]
  for op in f64_unary_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::f64_const(F64(16.75)),
      op,
    ])
  }
  let f64_binary_ops = [
    Instruction::f64_add(),
    Instruction::f64_sub(),
    Instruction::f64_mul(),
    Instruction::f64_div(),
    Instruction::f64_min(),
    Instruction::f64_max(),
    Instruction::f64_copysign(),
  ]
  for op in f64_binary_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::f64_const(F64(16.75)),
      Instruction::f64_const(F64(4.5)),
      op,
    ])
  }
  let f64_cmp_ops = [
    Instruction::f64_eq(),
    Instruction::f64_ne(),
    Instruction::f64_lt(),
    Instruction::f64_gt(),
    Instruction::f64_le(),
    Instruction::f64_ge(),
  ]
  for op in f64_cmp_ops {
    gen_valid_append_scalar_numeric_drop(out, [
      Instruction::f64_const(F64(16.75)),
      Instruction::f64_const(F64(4.5)),
      op,
    ])
  }

  let conversion_ops = [
    [Instruction::i64_const(I64(12L)), Instruction::i32_wrap_i64()],
    [
      Instruction::f32_const(F32(Float::from_double(12.0))),
      Instruction::i32_trunc_f32s(),
    ],
    [
      Instruction::f32_const(F32(Float::from_double(12.0))),
      Instruction::i32_trunc_f32u(),
    ],
    [Instruction::f64_const(F64(12.0)), Instruction::i32_trunc_f64s()],
    [Instruction::f64_const(F64(12.0)), Instruction::i32_trunc_f64u()],
    [Instruction::i32_const(I32(12)), Instruction::i64_extend_i32s()],
    [Instruction::i32_const(I32(12)), Instruction::i64_extend_i32u()],
    [
      Instruction::f32_const(F32(Float::from_double(12.0))),
      Instruction::i64_trunc_f32s(),
    ],
    [
      Instruction::f32_const(F32(Float::from_double(12.0))),
      Instruction::i64_trunc_f32u(),
    ],
    [Instruction::f64_const(F64(12.0)), Instruction::i64_trunc_f64s()],
    [Instruction::f64_const(F64(12.0)), Instruction::i64_trunc_f64u()],
    [Instruction::i32_const(I32(12)), Instruction::f32_convert_i32s()],
    [Instruction::i32_const(I32(12)), Instruction::f32_convert_i32u()],
    [Instruction::i64_const(I64(12L)), Instruction::f32_convert_i64s()],
    [Instruction::i64_const(I64(12L)), Instruction::f32_convert_i64u()],
    [Instruction::f64_const(F64(12.0)), Instruction::f32_demote_f64()],
    [Instruction::i32_const(I32(12)), Instruction::f64_convert_i32s()],
    [Instruction::i32_const(I32(12)), Instruction::f64_convert_i32u()],
    [Instruction::i64_const(I64(12L)), Instruction::f64_convert_i64s()],
    [Instruction::i64_const(I64(12L)), Instruction::f64_convert_i64u()],
    [
      Instruction::f32_const(F32(Float::from_double(12.0))),
      Instruction::f64_promote_f32(),
    ],
    [Instruction::i32_const(I32(0x7f)), Instruction::i32_extend8s()],
    [Instruction::i32_const(I32(0x7fff)), Instruction::i32_extend16s()],
    [Instruction::i64_const(I64(0x7fL)), Instruction::i64_extend8s()],
    [Instruction::i64_const(I64(0x7fffL)), Instruction::i64_extend16s()],
    [Instruction::i64_const(I64(0x7fffffffL)), Instruction::i64_extend32s()],
    [
      Instruction::f32_const(F32(Float::from_double(12.0))),
      Instruction::i32_trunc_sat_f32s(),
    ],
    [
      Instruction::f32_const(F32(Float::from_double(12.0))),
      Instruction::i32_trunc_sat_f32u(),
    ],
    [Instruction::f64_const(F64(12.0)), Instruction::i32_trunc_sat_f64s()],
    [Instruction::f64_const(F64(12.0)), Instruction::i32_trunc_sat_f64u()],
    [
      Instruction::f32_const(F32(Float::from_double(12.0))),
      Instruction::i64_trunc_sat_f32s(),
    ],
    [
      Instruction::f32_const(F32(Float::from_double(12.0))),
      Instruction::i64_trunc_sat_f32u(),
    ],
    [Instruction::f64_const(F64(12.0)), Instruction::i64_trunc_sat_f64s()],
    [Instruction::f64_const(F64(12.0)), Instruction::i64_trunc_sat_f64u()],
    [
      Instruction::f32_const(F32(Float::from_double(1.0))),
      Instruction::i32_reinterpret_f32(),
    ],
    [Instruction::f64_const(F64(1.0)), Instruction::i64_reinterpret_f64()],
    [
      Instruction::i32_const(I32(0x3f800000)),
      Instruction::f32_reinterpret_i32(),
    ],
    [
      Instruction::i64_const(I64(0x3ff0000000000000L)),
      Instruction::f64_reinterpret_i64(),
    ],
  ]
  for instrs in conversion_ops {
    gen_valid_append_scalar_numeric_drop(out, instrs)
  }
  gen_valid_append_scalar_numeric_drop(out, [
    Instruction::i32_const(I32(6)),
    Instruction::i32_const(I32(7)),
    Instruction::i32_add(),
    Instruction::i32_const(I32(3)),
    Instruction::i32_mul(),
  ])
  gen_valid_append_scalar_numeric_drop(out, [
    Instruction::f64_const(F64(6.5)),
    Instruction::f64_const(F64(2.0)),
    Instruction::f64_div(),
    Instruction::f64_const(F64(1.5)),
    Instruction::f64_sub(),
  ])
}

///|
fn gen_valid_append_basic_ref_is_null(
  out : Array[Instruction],
  ht : HeapType,
) -> Unit {
  out.push(Instruction::ref_null(ht))
  out.push(Instruction::ref_is_null())
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_basic_ref_test_cast_pair(
  out : Array[Instruction],
  source_ht : HeapType,
  target_ht : HeapType,
  target_nullable : Bool,
) -> Unit {
  out.push(Instruction::ref_null(source_ht))
  out.push(Instruction::ref_test(target_nullable, target_ht))
  out.push(Instruction::drop())

  out.push(Instruction::ref_null(source_ht))
  out.push(Instruction::ref_cast(target_nullable, target_ht))
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_basic_ref_br_on_cast_pair(
  out : Array[Instruction],
  source_nullable : Bool,
  target_nullable : Bool,
) -> Unit {
  let any = HeapType::abs(AbsHeapType::any())
  let i31 = HeapType::abs(AbsHeapType::i31())
  let block_ref = RefType::new(source_nullable, any)
  let source_instrs : Array[Instruction] = [Instruction::ref_null(any)]
  if !source_nullable {
    source_instrs.push(Instruction::ref_as_non_null())
  }
  source_instrs.push(
    Instruction::br_on_cast(
      LabelIdx::new(0U),
      source_nullable,
      any,
      target_nullable,
      i31,
    ),
  )
  out.push(
    Instruction::block(
      BlockType::val_type(ValType::ref_type(block_ref)),
      Expr::new(source_instrs),
    ),
  )
  out.push(Instruction::drop())

  let fail_instrs : Array[Instruction] = [Instruction::ref_null(any)]
  if !source_nullable {
    fail_instrs.push(Instruction::ref_as_non_null())
  }
  fail_instrs.push(
    Instruction::br_on_cast_fail(
      LabelIdx::new(0U),
      source_nullable,
      any,
      target_nullable,
      i31,
    ),
  )
  out.push(
    Instruction::block(
      BlockType::val_type(ValType::ref_type(block_ref)),
      Expr::new(fail_instrs),
    ),
  )
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_basic_ref_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
) -> Unit {
  if !ctx.config.features.allow_ref_types {
    return
  }
  let any = HeapType::abs(AbsHeapType::any())
  gen_valid_append_basic_ref_is_null(out, any)
  gen_valid_append_basic_ref_is_null(out, HeapType::abs(AbsHeapType::none()))
  gen_valid_append_basic_ref_is_null(out, HeapType::abs(AbsHeapType::no_func()))
  gen_valid_append_basic_ref_is_null(
    out,
    HeapType::abs(AbsHeapType::no_extern()),
  )
  gen_valid_append_basic_ref_test_cast_pair(out, any, any, true)
  gen_valid_append_basic_ref_test_cast_pair(out, any, any, false)
  gen_valid_append_basic_ref_br_on_cast_pair(out, true, true)
  gen_valid_append_basic_ref_br_on_cast_pair(out, true, false)
  gen_valid_append_basic_ref_br_on_cast_pair(out, false, false)
}

///|
fn gen_valid_append_i31_extern_conversion_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
) -> Unit {
  if !ctx.config.features.allow_ref_types {
    return
  }
  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::ref_i31())
  out.push(Instruction::drop())

  out.push(Instruction::i32_const(I32(8)))
  out.push(Instruction::ref_i31())
  out.push(Instruction::i31_get_s())
  out.push(Instruction::drop())

  out.push(Instruction::i32_const(I32(9)))
  out.push(Instruction::ref_i31())
  out.push(Instruction::i31_get_u())
  out.push(Instruction::drop())

  out.push(Instruction::ref_null(HeapType::abs(AbsHeapType::extern_())))
  out.push(Instruction::any_convert_extern())
  out.push(Instruction::extern_convert_any())
  out.push(Instruction::drop())
}

///|
fn gen_valid_try_table_has_exception_matrix(catches : Array[Catch]) -> Bool {
  let mut has_catch = false
  let mut has_catch_ref = false
  let mut has_catch_all = false
  let mut has_catch_all_ref = false
  for catch_ in catches {
    match catch_ {
      Catch(_, _) => has_catch = true
      CatchRef(_, _) => has_catch_ref = true
      CatchAll(_) => has_catch_all = true
      CatchAllRef(_) => has_catch_all_ref = true
    }
  }
  (has_catch && has_catch_all) || (has_catch_ref && has_catch_all_ref)
}

///|
fn gen_valid_first_payload_tag(tags : Array[TagType]) -> TagIdx? {
  for i = 0; i < tags.length(); i = i + 1 {
    let TagType(candidate) = tags[i]
    if candidate != TypeIdx::new(0U) {
      return Some(TagIdx::new(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
fn gen_valid_append_exception_try_table_matrix_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !ctx.config.features.allow_ref_types || env.tags.is_empty() {
    return
  }
  let tag_idx = TagIdx::new(0U)
  let payload_tag_idx = match gen_valid_first_payload_tag(env.tags) {
    Some(idx) => idx
    None => tag_idx
  }
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let exn_local = gen_matching_local_idx(
    env.local_types,
    ValType::ref_null_exn(),
  )
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::try_table(
          BlockType::void_(),
          [
            Catch::new(tag_idx, LabelIdx::new(0U)),
            Catch::all(LabelIdx::new(0U)),
          ],
          Expr::new([
            Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
            Instruction::if_(
              BlockType::void_(),
              [Instruction::throw_(tag_idx)],
              Some([
                Instruction::ref_null(HeapType::abs(AbsHeapType::exn())),
                Instruction::throw_ref(),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )
  out.push(
    Instruction::block(
      BlockType::val_type(exnref),
      Expr::new([
        Instruction::try_table(
          BlockType::val_type(exnref),
          [
            Catch::ref_(tag_idx, LabelIdx::new(0U)),
            Catch::all_ref(LabelIdx::new(0U)),
          ],
          Expr::new([Instruction::throw_(tag_idx)]),
        ),
      ]),
    ),
  )
  out.push(Instruction::drop())
  if payload_tag_idx != tag_idx {
    out.push(
      Instruction::block(
        BlockType::val_type(ValType::i32()),
        Expr::new([
          Instruction::try_table(
            BlockType::void_(),
            [Catch::new(payload_tag_idx, LabelIdx::new(0U))],
            Expr::new([
              Instruction::i32_const(I32(42)),
              Instruction::throw_(payload_tag_idx),
            ]),
          ),
        ]),
      ),
    )
    out.push(Instruction::drop())
    out.push(
      Instruction::block(
        BlockType::val_type(ValType::i32()),
        Expr::new([
          Instruction::block(
            BlockType::void_(),
            Expr::new([
              Instruction::try_table(
                BlockType::void_(),
                [
                  Catch::new(tag_idx, LabelIdx::new(0U)),
                  Catch::all(LabelIdx::new(0U)),
                  Catch::new(payload_tag_idx, LabelIdx::new(1U)),
                ],
                Expr::new([
                  Instruction::i32_const(I32(77)),
                  Instruction::throw_(payload_tag_idx),
                ]),
              ),
            ]),
          ),
          Instruction::i32_const(I32(0)),
        ]),
      ),
    )
    out.push(Instruction::drop())
  }
  out.push(
    Instruction::try_table(
      BlockType::val_type(ValType::i32()),
      [],
      Expr::new([Instruction::i32_const(I32(5))]),
    ),
  )
  out.push(Instruction::drop())
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::try_table(
          BlockType::void_(),
          [Catch::all(LabelIdx::new(0U))],
          Expr::new([
            Instruction::try_table(
              BlockType::void_(),
              [Catch::new(tag_idx, LabelIdx::new(0U))],
              Expr::new([Instruction::throw_(tag_idx)]),
            ),
          ]),
        ),
      ]),
    ),
  )
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::block(
          BlockType::val_type(ValType::ref_null_exn()),
          Expr::new([Instruction::ref_null(HeapType::abs(AbsHeapType::exn()))]),
        ),
        Instruction::throw_ref(),
      ]),
    ),
  )
  match exn_local {
    Some(local_idx) =>
      out.push(
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::ref_null(HeapType::abs(AbsHeapType::exn())),
            Instruction::local_set(local_idx),
            Instruction::local_get(local_idx),
            Instruction::throw_ref(),
          ]),
        ),
      )
    None => ()
  }
}

///|
fn gen_valid_append_v128_zero(out : Array[Instruction]) -> Unit {
  out.push(
    Instruction::v128_const(
      b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    ),
  )
}

///|
fn gen_valid_append_v128_binary_op(
  out : Array[Instruction],
  instr : Instruction,
) -> Unit {
  gen_valid_append_v128_zero(out)
  gen_valid_append_v128_zero(out)
  out.push(instr)
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_v128_unary_op(
  out : Array[Instruction],
  instr : Instruction,
) -> Unit {
  gen_valid_append_v128_zero(out)
  out.push(instr)
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_v128_ternary_op(
  out : Array[Instruction],
  instr : Instruction,
) -> Unit {
  gen_valid_append_v128_zero(out)
  gen_valid_append_v128_zero(out)
  gen_valid_append_v128_zero(out)
  out.push(instr)
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_relaxed_simd_ops(out : Array[Instruction]) -> Unit {
  gen_valid_append_v128_binary_op(out, Instruction::i8x16_relaxed_swizzle())
  gen_valid_append_v128_ternary_op(out, Instruction::i8x16_relaxed_laneselect())
  gen_valid_append_v128_ternary_op(out, Instruction::i16x8_relaxed_laneselect())
  gen_valid_append_v128_ternary_op(out, Instruction::i32x4_relaxed_laneselect())
  gen_valid_append_v128_ternary_op(out, Instruction::i64x2_relaxed_laneselect())
  gen_valid_append_v128_unary_op(out, Instruction::i32x4_relaxed_trunc_f32x4s())
  gen_valid_append_v128_unary_op(out, Instruction::i32x4_relaxed_trunc_f32x4u())
  gen_valid_append_v128_unary_op(
    out,
    Instruction::i32x4_relaxed_trunc_zero_f64x2s(),
  )
  gen_valid_append_v128_unary_op(
    out,
    Instruction::i32x4_relaxed_trunc_zero_f64x2u(),
  )
  gen_valid_append_v128_ternary_op(out, Instruction::f32x4_relaxed_madd())
  gen_valid_append_v128_ternary_op(out, Instruction::f32x4_relaxed_nmadd())
  gen_valid_append_v128_ternary_op(out, Instruction::f64x2_relaxed_madd())
  gen_valid_append_v128_ternary_op(out, Instruction::f64x2_relaxed_nmadd())
  gen_valid_append_v128_binary_op(out, Instruction::f32x4_relaxed_min())
  gen_valid_append_v128_binary_op(out, Instruction::f32x4_relaxed_max())
  gen_valid_append_v128_binary_op(out, Instruction::f64x2_relaxed_min())
  gen_valid_append_v128_binary_op(out, Instruction::f64x2_relaxed_max())
  gen_valid_append_v128_binary_op(out, Instruction::i16x8_relaxed_q15mulr_s())
  gen_valid_append_v128_binary_op(
    out,
    Instruction::i16x8_relaxed_dot_i8x16i7x16s(),
  )
  gen_valid_append_v128_ternary_op(
    out,
    Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s(),
  )
}

///|
fn gen_valid_append_simd_phase1_ops(out : Array[Instruction]) -> Unit {
  gen_valid_append_v128_zero(out)
  out.push(Instruction::drop())

  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::i8x16_splat())
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(300)))
  out.push(Instruction::i16x8_splat())
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(12345)))
  out.push(Instruction::i32x4_splat())
  out.push(Instruction::drop())
  out.push(Instruction::i64_const(I64(123456L)))
  out.push(Instruction::i64x2_splat())
  out.push(Instruction::drop())
  out.push(Instruction::f32_const(F32(Float::from_double(1.5))))
  out.push(Instruction::f32x4_splat())
  out.push(Instruction::drop())
  out.push(Instruction::f64_const(F64(2.5)))
  out.push(Instruction::f64x2_splat())
  out.push(Instruction::drop())

  gen_valid_append_v128_zero(out)
  out.push(Instruction::i8x16_extract_lane_s(LaneIdx::new(0)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::i8x16_extract_lane_u(LaneIdx::new(1)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::i32_const(I32(9)))
  out.push(Instruction::i8x16_replace_lane(LaneIdx::new(2)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::i16x8_extract_lane_s(LaneIdx::new(3)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::i16x8_extract_lane_u(LaneIdx::new(4)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::i32_const(I32(10)))
  out.push(Instruction::i16x8_replace_lane(LaneIdx::new(5)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::i32x4_extract_lane(LaneIdx::new(1)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::i32_const(I32(11)))
  out.push(Instruction::i32x4_replace_lane(LaneIdx::new(2)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::i64x2_extract_lane(LaneIdx::new(1)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::i64_const(I64(12L)))
  out.push(Instruction::i64x2_replace_lane(LaneIdx::new(0)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::f32x4_extract_lane(LaneIdx::new(2)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::f32_const(F32(Float::from_double(3.5))))
  out.push(Instruction::f32x4_replace_lane(LaneIdx::new(3)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::f64x2_extract_lane(LaneIdx::new(1)))
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::f64_const(F64(4.5)))
  out.push(Instruction::f64x2_replace_lane(LaneIdx::new(0)))
  out.push(Instruction::drop())

  gen_valid_append_v128_zero(out)
  out.push(Instruction::v128_not())
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  gen_valid_append_v128_zero(out)
  out.push(Instruction::v128_and())
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  gen_valid_append_v128_zero(out)
  out.push(Instruction::v128_andnot())
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  gen_valid_append_v128_zero(out)
  out.push(Instruction::v128_or())
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  gen_valid_append_v128_zero(out)
  out.push(Instruction::v128_xor())
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  gen_valid_append_v128_zero(out)
  gen_valid_append_v128_zero(out)
  out.push(Instruction::v128_bitselect())
  out.push(Instruction::drop())
  gen_valid_append_v128_zero(out)
  out.push(Instruction::v128_any_true())
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_simd_phase2_ops(out : Array[Instruction]) -> Unit {
  gen_valid_append_v128_binary_op(out, Instruction::i8x16_eq())
  gen_valid_append_v128_binary_op(out, Instruction::i16x8_lt_s())
  gen_valid_append_v128_binary_op(out, Instruction::i32x4_gt_u())
  gen_valid_append_v128_binary_op(out, Instruction::i64x2_ge_s())
  gen_valid_append_v128_binary_op(out, Instruction::f32x4_lt())
  gen_valid_append_v128_binary_op(out, Instruction::f64x2_ge())

  gen_valid_append_v128_unary_op(out, Instruction::i8x16_all_true())
  gen_valid_append_v128_unary_op(out, Instruction::i16x8_bitmask())
  gen_valid_append_v128_unary_op(out, Instruction::i32x4_all_true())
  gen_valid_append_v128_unary_op(out, Instruction::i64x2_bitmask())

  gen_valid_append_v128_binary_op(out, Instruction::i8x16_add())
  gen_valid_append_v128_binary_op(out, Instruction::i8x16_add_sat_s())
  gen_valid_append_v128_binary_op(out, Instruction::i8x16_sub_sat_u())
  gen_valid_append_v128_binary_op(out, Instruction::i8x16_min_s())
  gen_valid_append_v128_binary_op(out, Instruction::i8x16_max_u())
  gen_valid_append_v128_binary_op(out, Instruction::i8x16_avgr_u())
  gen_valid_append_v128_binary_op(out, Instruction::i16x8_mul())
  gen_valid_append_v128_binary_op(out, Instruction::i16x8_add_sat_u())
  gen_valid_append_v128_binary_op(out, Instruction::i16x8_sub_sat_s())
  gen_valid_append_v128_binary_op(out, Instruction::i16x8_min_u())
  gen_valid_append_v128_binary_op(out, Instruction::i16x8_max_s())
  gen_valid_append_v128_binary_op(out, Instruction::i16x8_avgr_u())
  gen_valid_append_v128_binary_op(out, Instruction::i32x4_add())
  gen_valid_append_v128_binary_op(out, Instruction::i32x4_mul())
  gen_valid_append_v128_binary_op(out, Instruction::i32x4_min_s())
  gen_valid_append_v128_binary_op(out, Instruction::i32x4_max_u())
  gen_valid_append_v128_binary_op(out, Instruction::i64x2_add())
  gen_valid_append_v128_binary_op(out, Instruction::i64x2_mul())
  gen_valid_append_v128_binary_op(out, Instruction::f32x4_add())
  gen_valid_append_v128_binary_op(out, Instruction::f32x4_div())
  gen_valid_append_v128_binary_op(out, Instruction::f32x4_min())
  gen_valid_append_v128_binary_op(out, Instruction::f32x4_max())
  gen_valid_append_v128_binary_op(out, Instruction::f64x2_add())
  gen_valid_append_v128_binary_op(out, Instruction::f64x2_div())
  gen_valid_append_v128_binary_op(out, Instruction::f64x2_min())
  gen_valid_append_v128_binary_op(out, Instruction::f64x2_max())

  gen_valid_append_v128_unary_op(out, Instruction::f32x4_ceil())
  gen_valid_append_v128_unary_op(out, Instruction::f32x4_floor())
  gen_valid_append_v128_unary_op(out, Instruction::f32x4_trunc())
  gen_valid_append_v128_unary_op(out, Instruction::f32x4_nearest())
  gen_valid_append_v128_unary_op(out, Instruction::f64x2_ceil())
  gen_valid_append_v128_unary_op(out, Instruction::f64x2_floor())
  gen_valid_append_v128_unary_op(out, Instruction::f64x2_trunc())
  gen_valid_append_v128_unary_op(out, Instruction::f64x2_nearest())
}

///|
fn gen_valid_append_simd_memory_load_drop(
  out : Array[Instruction],
  load : Instruction,
) -> Unit {
  out.push(Instruction::i32_const(I32(0)))
  out.push(load)
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_simd_memory_lane_load_drop(
  out : Array[Instruction],
  load : Instruction,
) -> Unit {
  out.push(Instruction::i32_const(I32(0)))
  gen_valid_append_v128_zero(out)
  out.push(load)
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_simd_memory_store(
  out : Array[Instruction],
  store : Instruction,
) -> Unit {
  out.push(Instruction::i32_const(I32(0)))
  gen_valid_append_v128_zero(out)
  out.push(store)
}

///|
fn gen_valid_append_atomic_load_drop(
  out : Array[Instruction],
  load : Instruction,
) -> Unit {
  out.push(Instruction::i32_const(I32(0)))
  out.push(load)
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_atomic_store(
  out : Array[Instruction],
  value64 : Bool,
  store : Instruction,
) -> Unit {
  out.push(Instruction::i32_const(I32(0)))
  if value64 {
    out.push(Instruction::i64_const(I64(0L)))
  } else {
    out.push(Instruction::i32_const(I32(0)))
  }
  out.push(store)
}

///|
fn gen_valid_append_atomic_rmw_drop(
  out : Array[Instruction],
  value64 : Bool,
  instr : Instruction,
) -> Unit {
  out.push(Instruction::i32_const(I32(0)))
  if value64 {
    out.push(Instruction::i64_const(I64(1L)))
  } else {
    out.push(Instruction::i32_const(I32(1)))
  }
  out.push(instr)
  out.push(Instruction::drop())
}

///|
fn gen_valid_append_atomic_cmpxchg_drop(
  out : Array[Instruction],
  value64 : Bool,
  instr : Instruction,
) -> Unit {
  out.push(Instruction::i32_const(I32(0)))
  if value64 {
    out.push(Instruction::i64_const(I64(1L)))
    out.push(Instruction::i64_const(I64(2L)))
  } else {
    out.push(Instruction::i32_const(I32(1)))
    out.push(Instruction::i32_const(I32(2)))
  }
  out.push(instr)
  out.push(Instruction::drop())
}

///|
fn gen_valid_atomic_shared_mem_idx(env : GenValidBodyEnv) -> MemIdx? {
  for i = 0; i < env.mems.length(); i = i + 1 {
    let MemType(_, shared) = env.mems[i]
    if shared {
      return Some(MemIdx::new(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
fn gen_valid_atomic_memarg(
  mem_idx : MemIdx,
  align_pow : UInt,
  offset : UInt64,
) -> MemArg {
  MemArg::new(U32(align_pow), Some(mem_idx), U64(offset))
}

///|
fn gen_valid_append_atomic_ops(
  out : Array[Instruction],
  mem_idx : MemIdx,
) -> Unit {
  gen_valid_append_atomic_load_drop(
    out,
    Instruction::i32_atomic_load(gen_valid_atomic_memarg(mem_idx, 2U, 240UL)),
  )
  gen_valid_append_atomic_load_drop(
    out,
    Instruction::i64_atomic_load(gen_valid_atomic_memarg(mem_idx, 3U, 248UL)),
  )
  gen_valid_append_atomic_load_drop(
    out,
    Instruction::i32_atomic_load8_u(gen_valid_atomic_memarg(mem_idx, 0U, 256UL)),
  )
  gen_valid_append_atomic_load_drop(
    out,
    Instruction::i64_atomic_load32_u(
      gen_valid_atomic_memarg(mem_idx, 2U, 264UL),
    ),
  )
  gen_valid_append_atomic_store(
    out,
    false,
    Instruction::i32_atomic_store(gen_valid_atomic_memarg(mem_idx, 2U, 272UL)),
  )
  gen_valid_append_atomic_store(
    out,
    true,
    Instruction::i64_atomic_store(gen_valid_atomic_memarg(mem_idx, 3U, 280UL)),
  )
  gen_valid_append_atomic_store(
    out,
    false,
    Instruction::i32_atomic_store8(gen_valid_atomic_memarg(mem_idx, 0U, 288UL)),
  )
  gen_valid_append_atomic_store(
    out,
    true,
    Instruction::i64_atomic_store32(gen_valid_atomic_memarg(mem_idx, 2U, 296UL)),
  )
  gen_valid_append_atomic_rmw_drop(
    out,
    false,
    Instruction::atomic_rmw(
      AtomicRmwOp::i32_add(),
      gen_valid_atomic_memarg(mem_idx, 2U, 304UL),
    ),
  )
  gen_valid_append_atomic_rmw_drop(
    out,
    true,
    Instruction::atomic_rmw(
      AtomicRmwOp::i64_xchg(),
      gen_valid_atomic_memarg(mem_idx, 3U, 312UL),
    ),
  )
  gen_valid_append_atomic_rmw_drop(
    out,
    false,
    Instruction::atomic_rmw(
      AtomicRmwOp::i32_8_or_u(),
      gen_valid_atomic_memarg(mem_idx, 0U, 320UL),
    ),
  )
  gen_valid_append_atomic_cmpxchg_drop(
    out,
    false,
    Instruction::atomic_cmpxchg(
      AtomicCmpxchgOp::i32(),
      gen_valid_atomic_memarg(mem_idx, 2U, 328UL),
    ),
  )
  gen_valid_append_atomic_cmpxchg_drop(
    out,
    true,
    Instruction::atomic_cmpxchg(
      AtomicCmpxchgOp::i64_32_u(),
      gen_valid_atomic_memarg(mem_idx, 2U, 336UL),
    ),
  )
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(1)))
  out.push(
    Instruction::memory_atomic_notify(
      gen_valid_atomic_memarg(mem_idx, 2U, 344UL),
    ),
  )
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i64_const(I64(0L)))
  out.push(
    Instruction::memory_atomic_wait32(
      gen_valid_atomic_memarg(mem_idx, 2U, 352UL),
    ),
  )
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i64_const(I64(0L)))
  out.push(Instruction::i64_const(I64(0L)))
  out.push(
    Instruction::memory_atomic_wait64(
      gen_valid_atomic_memarg(mem_idx, 3U, 360UL),
    ),
  )
  out.push(Instruction::drop())
  out.push(Instruction::atomic_fence())
}

///|
fn gen_valid_append_simd_phase3_ops(
  out : Array[Instruction],
  nonzero_mem_idx : MemIdx?,
) -> Unit {
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 4U, 96UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load8x8s(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 3U, 112UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load8x8u(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 3U, 120UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load16x4s(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 3U, 128UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load16x4u(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 3U, 136UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load32x2s(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 3U, 144UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load32x2u(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 3U, 152UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load8_splat(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 0U, 160UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load16_splat(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 1U, 162UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load32_splat(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 2U, 164UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load64_splat(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 3U, 168UL),
    ),
  )
  gen_valid_append_simd_memory_store(
    out,
    Instruction::v128_store(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 4U, 176UL),
    ),
  )
  gen_valid_append_simd_memory_lane_load_drop(
    out,
    Instruction::v128_load8_lane(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 0U, 192UL),
      LaneIdx::new(3),
    ),
  )
  gen_valid_append_simd_memory_lane_load_drop(
    out,
    Instruction::v128_load16_lane(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 1U, 194UL),
      LaneIdx::new(2),
    ),
  )
  gen_valid_append_simd_memory_lane_load_drop(
    out,
    Instruction::v128_load32_lane(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 2U, 196UL),
      LaneIdx::new(1),
    ),
  )
  gen_valid_append_simd_memory_lane_load_drop(
    out,
    Instruction::v128_load64_lane(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 3U, 200UL),
      LaneIdx::new(0),
    ),
  )
  gen_valid_append_simd_memory_store(
    out,
    Instruction::v128_store8_lane(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 0U, 208UL),
      LaneIdx::new(4),
    ),
  )
  gen_valid_append_simd_memory_store(
    out,
    Instruction::v128_store16_lane(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 1U, 210UL),
      LaneIdx::new(5),
    ),
  )
  gen_valid_append_simd_memory_store(
    out,
    Instruction::v128_store32_lane(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 2U, 212UL),
      LaneIdx::new(2),
    ),
  )
  gen_valid_append_simd_memory_store(
    out,
    Instruction::v128_store64_lane(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 3U, 216UL),
      LaneIdx::new(1),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load32_zero(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 2U, 224UL),
    ),
  )
  gen_valid_append_simd_memory_load_drop(
    out,
    Instruction::v128_load64_zero(
      gen_valid_simd_memarg_varied(nonzero_mem_idx, 3U, 232UL),
    ),
  )
  gen_valid_append_v128_binary_op(
    out,
    Instruction::i8x16_shuffle(
      LaneIdx::new(0),
      LaneIdx::new(17),
      LaneIdx::new(2),
      LaneIdx::new(19),
      LaneIdx::new(4),
      LaneIdx::new(21),
      LaneIdx::new(6),
      LaneIdx::new(23),
      LaneIdx::new(8),
      LaneIdx::new(25),
      LaneIdx::new(10),
      LaneIdx::new(27),
      LaneIdx::new(12),
      LaneIdx::new(29),
      LaneIdx::new(14),
      LaneIdx::new(31),
    ),
  )
  gen_valid_append_v128_binary_op(out, Instruction::i8x16_swizzle())
  gen_valid_append_v128_binary_op(out, Instruction::i8x16_narrow_i16x8s())
  gen_valid_append_v128_binary_op(out, Instruction::i8x16_narrow_i16x8u())
  gen_valid_append_v128_binary_op(out, Instruction::i16x8_narrow_i32x4s())
  gen_valid_append_v128_binary_op(out, Instruction::i16x8_narrow_i32x4u())
  gen_valid_append_v128_unary_op(
    out,
    Instruction::i16x8_extadd_pairwise_i8x16s(),
  )
  gen_valid_append_v128_unary_op(
    out,
    Instruction::i16x8_extadd_pairwise_i8x16u(),
  )
  gen_valid_append_v128_unary_op(
    out,
    Instruction::i32x4_extadd_pairwise_i16x8s(),
  )
  gen_valid_append_v128_unary_op(
    out,
    Instruction::i32x4_extadd_pairwise_i16x8u(),
  )
  gen_valid_append_v128_binary_op(out, Instruction::i32x4_dot_i16x8s())
  gen_valid_append_v128_unary_op(out, Instruction::f32x4_demote_f64x2_zero())
  gen_valid_append_v128_unary_op(out, Instruction::f64x2_promote_low_f32x4())
}

///|
fn gen_valid_append_exact_ref_local_flow(
  out : Array[Instruction],
  env : GenValidBodyEnv,
) -> Unit {
  for vt in env.gc_type_plan.exact_ref_types {
    match vt {
      RefTypeValType(rt) =>
        match gen_matching_local_idx(env.local_types, vt) {
          Some(idx) => {
            out.push(
              Instruction::block(
                BlockType::val_type(vt),
                Expr::new([
                  Instruction::ref_null_type(rt),
                  Instruction::local_set(idx),
                  Instruction::local_get(idx),
                ]),
              ),
            )
            out.push(Instruction::drop())
            return
          }
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn gen_valid_append_memory_template_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !env.mems.is_empty() {
    out.push(Instruction::memory_size(MemIdx::new(0U)))
    out.push(Instruction::drop())
    out.push(Instruction::i32_const(I32(1)))
    out.push(Instruction::memory_grow(MemIdx::new(0U)))
    out.push(Instruction::drop())
    gen_valid_append_scalar_memory_ops(out)
    match gen_valid_first_nonzero_i32_mem_idx(env.mems) {
      Some(nonzero_mem_idx) =>
        gen_valid_append_nonzero_scalar_memory_ops(out, nonzero_mem_idx)
      None => ()
    }
    ignore(gen_valid_append_memory_bulk_ops(out, ctx, env))
  }
}

///|
fn gen_valid_append_table_template_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !env.tables.is_empty() {
    let TableType(rt, _) = env.tables[0]
    out.push(Instruction::table_size(TableIdx::new(0U)))
    out.push(Instruction::drop())
    out.push(Instruction::i32_const(I32(0)))
    gen_valid_append_table_ref_value(out, ctx, env, rt)
    out.push(Instruction::table_set(TableIdx::new(0U)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::table_get(TableIdx::new(0U)))
    out.push(Instruction::drop())
    gen_valid_append_table_ref_value(out, ctx, env, rt)
    out.push(Instruction::i32_const(I32(1)))
    out.push(Instruction::table_grow(TableIdx::new(0U)))
    out.push(Instruction::drop())
    match gen_valid_first_nonzero_table_idx(env.tables) {
      Some(nonzero_table_idx) =>
        gen_valid_append_nonzero_table_access_ops(out, env, nonzero_table_idx)
      None => ()
    }
    ignore(gen_valid_append_table_bulk_ops(out, ctx, env))
  }
}

///|
fn gen_valid_append_global_template_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !env.globals.is_empty() {
    out.push(Instruction::global_get(GlobalIdx::new(0U)))
    out.push(Instruction::drop())
    let GlobalType(first_global_vt, _) = env.globals[0]
    match
      gen_matching_global_idx(env.globals, first_global_vt, mutable_only=true) {
      Some(idx) => {
        let GlobalIdx(idx_u) = idx
        let GlobalType(vt, _) = env.globals[idx_u.reinterpret_as_int()]
        append_value_instrs(
          out,
          ctx,
          vt,
          gen_valid_body_env_child(env),
          prefer_local=false,
        )
        out.push(Instruction::global_set(idx))
      }
      None => ()
    }
  }
}

///|
fn gen_valid_append_memory_table_global_template_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  let order_key = match env.current_func_idx {
    Some(func_idx) => gen_valid_func_idx_to_int(func_idx)
    None => env.local_types.length() + env.tables.length() + env.mems.length()
  }
  let table_first = order_key % 2 == 0
  if table_first {
    gen_valid_append_table_template_ops(out, ctx, env)
    gen_valid_append_memory_template_ops(out, ctx, env)
  } else {
    gen_valid_append_memory_template_ops(out, ctx, env)
    gen_valid_append_table_template_ops(out, ctx, env)
  }
  gen_valid_append_global_template_ops(out, ctx, env)
}

///|
fn gen_valid_append_simd_template_group(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if !ctx.config.features.allow_v128 {
    return
  }
  if ctx.config.features.allow_relaxed_simd {
    gen_valid_append_relaxed_simd_ops(out)
  }
  let has_memory_phase = !env.mems.is_empty()
  let simd_nonzero_mem_idx = gen_valid_first_nonzero_i32_mem_idx(env.mems)
  let order_key = match env.current_func_idx {
    Some(func_idx) => gen_valid_func_idx_to_int(func_idx)
    None => env.local_types.length() + env.tables.length() + env.mems.length()
  }
  let order_mod = if has_memory_phase { 6 } else { 2 }
  match order_key % order_mod {
    0 => {
      gen_valid_append_simd_phase1_ops(out)
      gen_valid_append_simd_phase2_ops(out)
      if has_memory_phase {
        gen_valid_append_simd_phase3_ops(out, simd_nonzero_mem_idx)
      }
    }
    1 => {
      gen_valid_append_simd_phase2_ops(out)
      gen_valid_append_simd_phase1_ops(out)
      if has_memory_phase {
        gen_valid_append_simd_phase3_ops(out, simd_nonzero_mem_idx)
      }
    }
    2 => {
      gen_valid_append_simd_phase1_ops(out)
      gen_valid_append_simd_phase3_ops(out, simd_nonzero_mem_idx)
      gen_valid_append_simd_phase2_ops(out)
    }
    3 => {
      gen_valid_append_simd_phase2_ops(out)
      gen_valid_append_simd_phase3_ops(out, simd_nonzero_mem_idx)
      gen_valid_append_simd_phase1_ops(out)
    }
    4 => {
      gen_valid_append_simd_phase3_ops(out, simd_nonzero_mem_idx)
      gen_valid_append_simd_phase1_ops(out)
      gen_valid_append_simd_phase2_ops(out)
    }
    _ => {
      gen_valid_append_simd_phase3_ops(out, simd_nonzero_mem_idx)
      gen_valid_append_simd_phase2_ops(out)
      gen_valid_append_simd_phase1_ops(out)
    }
  }
}

///|
fn gen_valid_append_call_template_group(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  returns : Array[ValType],
) -> Unit {
  let order_key = gen_valid_template_order_key(env)
  match order_key % 3 {
    0 => {
      gen_valid_append_direct_call_graph_variants(out, ctx, env)
      gen_valid_append_call_indirect_variants(out, ctx, env)
      gen_valid_append_call_ref_source_variants(out, ctx, env)
    }
    1 => {
      gen_valid_append_call_indirect_variants(out, ctx, env)
      gen_valid_append_direct_call_graph_variants(out, ctx, env)
      gen_valid_append_call_ref_source_variants(out, ctx, env)
    }
    _ => {
      gen_valid_append_call_ref_source_variants(out, ctx, env)
      gen_valid_append_direct_call_graph_variants(out, ctx, env)
      gen_valid_append_call_indirect_variants(out, ctx, env)
    }
  }
  gen_valid_append_nested_tail_call_variants(out, ctx, env, returns)
  gen_valid_append_tail_call_ops(out, ctx, env, returns)
}

///|
fn gen_valid_template_order_key(env : GenValidBodyEnv) -> Int {
  match env.current_func_idx {
    Some(func_idx) => gen_valid_func_idx_to_int(func_idx)
    None =>
      env.local_types.length() +
      env.tables.length() +
      env.mems.length() +
      env.funcs.length()
  }
}

///|
fn gen_valid_append_ref_template_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  gen_valid_append_exact_ref_local_flow(out, env)
  gen_valid_append_basic_ref_ops(out, ctx)
  gen_valid_append_i31_extern_conversion_ops(out, ctx)
}

///|
fn gen_valid_append_ref_gc_exception_template_group(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  let order_key = gen_valid_template_order_key(env)
  match order_key % 4 {
    0 => {
      gen_valid_append_gc_prelude(out, ctx, env)
      gen_valid_append_ref_template_ops(out, ctx, env)
      gen_valid_append_exception_try_table_matrix_ops(out, ctx, env)
    }
    1 => {
      gen_valid_append_ref_template_ops(out, ctx, env)
      gen_valid_append_gc_prelude(out, ctx, env)
      gen_valid_append_exception_try_table_matrix_ops(out, ctx, env)
    }
    2 => {
      gen_valid_append_exception_try_table_matrix_ops(out, ctx, env)
      gen_valid_append_gc_prelude(out, ctx, env)
      gen_valid_append_ref_template_ops(out, ctx, env)
    }
    _ => {
      gen_valid_append_exception_try_table_matrix_ops(out, ctx, env)
      gen_valid_append_ref_template_ops(out, ctx, env)
      gen_valid_append_gc_prelude(out, ctx, env)
    }
  }
}

///|
fn gen_valid_append_coverage_prelude(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  returns : Array[ValType],
) -> Unit {
  gen_valid_append_ref_gc_exception_template_group(out, ctx, env)
  gen_valid_append_expanded_scalar_numeric_ops(out, ctx)
  gen_valid_append_core_control_ops(out, ctx, env)
  gen_valid_append_call_template_group(out, ctx, env, returns)
  gen_valid_append_simd_template_group(out, ctx, env)
  if ctx.config.features.allow_atomics {
    match gen_valid_atomic_shared_mem_idx(env) {
      Some(mem_idx) => gen_valid_append_atomic_ops(out, mem_idx)
      None => ()
    }
  }
  if ctx.config.features.allow_ref_types {
    append_value_instrs(
      out,
      ctx,
      ValType::funcref(),
      gen_valid_body_env_child(env),
      prefer_local=false,
    )
    out.push(Instruction::drop())
    append_value_instrs(
      out,
      ctx,
      ValType::externref(),
      gen_valid_body_env_child(env),
      prefer_local=false,
    )
    out.push(Instruction::drop())
  }
  if ctx.config.features.allow_calls {
    match gen_valid_pick_callable(ctx, env.funcs) {
      Some(target) => {
        gen_valid_append_call_args(out, ctx, env, target.params)
        out.push(Instruction::call(target.idx))
        gen_valid_append_call_result_drops(out, target.results)
      }
      None => ()
    }
  }
  if ctx.config.features.allow_call_indirect && !env.tables.is_empty() {
    match gen_valid_pick_callable(ctx, env.funcs) {
      Some(target) => {
        gen_valid_append_call_args(out, ctx, env, target.params)
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::call_indirect(target.type_idx, TableIdx::new(0U)))
        gen_valid_append_call_result_drops(out, target.results)
      }
      None => ()
    }
  }
  gen_valid_append_memory_table_global_template_ops(out, ctx, env)
  let branch_first = ctx.random_bool()
  let branch_block_body = [
    Instruction::i32_const(I32(if branch_first { 1 } else { 0 })),
    Instruction::br_if(LabelIdx::new(0U)),
  ]
  let branch_loop = Instruction::loop_(
    BlockType::void_(),
    Expr::new([
      Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
      Instruction::br_if(LabelIdx::new(0U)),
    ]),
  )
  let branch_block = Instruction::block(
    BlockType::void_(),
    Expr::new(branch_block_body),
  )
  if branch_first {
    out.push(branch_block)
    out.push(branch_loop)
  } else {
    out.push(branch_loop)
    out.push(branch_block)
  }
  out.push(Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::block(
          BlockType::void_(),
          Expr::new([Instruction::br(LabelIdx::new(0U))]),
        ),
      ],
      Some([Instruction::nop()]),
    ),
  )
}

///|
fn gen_valid_append_return_value_instrs(
  out : Array[Instruction],
  ctx : GenValidContext,
  vt : ValType,
  env : GenValidBodyEnv,
) -> Unit {
  match vt {
    RefTypeValType(rt) if ctx.config.mode == Natural && rt.is_exact() => {
      match gen_matching_local_idx(env.local_types, vt) {
        Some(idx) => {
          out.push(Instruction::local_get(idx))
          return
        }
        None => ()
      }
      match gen_matching_global_idx(env.globals, vt) {
        Some(idx) => {
          out.push(Instruction::global_get(idx))
          return
        }
        None => ()
      }
      if ctx.config.features.allow_ref_types {
        match
          gen_valid_declared_ref_callable_with_result(
            env.funcs,
            env.declared_ref_func_idx,
            vt,
          ) {
          Some(target) if !ctx.config.features.allow_calls || ctx.random_bool() => {
            gen_valid_append_call_args(out, ctx, env, target.params)
            out.push(Instruction::ref_func(target.idx))
            out.push(Instruction::call_ref(target.type_idx))
            return
          }
          _ => ()
        }
      }
      if ctx.config.features.allow_calls {
        match gen_valid_pick_callable_with_result(ctx, env.funcs, vt) {
          Some(target) => {
            gen_valid_append_call_args(out, ctx, env, target.params)
            out.push(Instruction::call(target.idx))
            return
          }
          None => ()
        }
      }
      append_value_instrs(out, ctx, vt, env)
    }
    _ => append_value_instrs(out, ctx, vt, env)
  }
}

///|
fn gen_valid_build_func(
  ctx : GenValidContext,
  accepts : Array[ValType],
  returns : Array[ValType],
  globals : Array[GlobalType],
  tables : Array[TableType],
  mems : Array[MemType],
  tags : Array[TagType],
  funcs : Array[GenValidFuncSig],
  data_idxs : Array[DataIdx],
  _elem_idxs : Array[ElemIdx],
  passive_elem_idxs : Array[ElemIdx],
  passive_elem_ref_types : Array[RefType],
  bulk_elem_seed_idx : ElemIdx?,
  gc_type_plan : GenValidGcTypePlan,
  declared_ref_func_idx : FuncIdx?,
  current_func_idx? : FuncIdx? = None,
) -> Func {
  let local_ref_types = gc_type_plan.concrete_ref_types.copy()
  for vt in gc_type_plan.exact_ref_types {
    local_ref_types.push(vt)
  }
  let locals = gen_local_types(ctx, extra_ref_types=local_ref_types)
  if ctx.config.mode == CoverageForced {
    let mut has_i32_local = false
    for vt in accepts {
      if vt == ValType::i32() {
        has_i32_local = true
      }
    }
    for vt in locals {
      if vt == ValType::i32() {
        has_i32_local = true
      }
    }
    if !has_i32_local {
      locals.push(ValType::i32())
    }
    if ctx.config.features.allow_typed_body_generator &&
      gen_matching_local_idx(
        gen_all_local_types(accepts, locals),
        ValType::i64(),
      )
      is None {
      locals.push(ValType::i64())
    }
    if ctx.config.features.allow_ref_types {
      match declared_ref_func_idx {
        Some(func_idx) =>
          match gen_valid_callable_by_idx(funcs, func_idx) {
            Some(target) => {
              let fref = ValType::ref_type(
                RefType::new(true, HeapType::new(target.type_idx)),
              )
              if gen_matching_local_idx(
                  gen_all_local_types(accepts, locals),
                  fref,
                )
                is None {
                locals.push(fref)
              }
            }
            None => ()
          }
        None => ()
      }
    }
    if ctx.config.features.allow_ref_types &&
      !tags.is_empty() &&
      gen_matching_local_idx(
        gen_all_local_types(accepts, locals),
        ValType::ref_null_exn(),
      )
      is None {
      locals.push(ValType::ref_null_exn())
    }
  }
  if ctx.config.mode == Natural {
    for vt in returns {
      match vt {
        RefTypeValType(rt) if rt.is_exact() => {
          let has_existing_exact_route = gen_matching_local_idx(
              gen_all_local_types(accepts, locals),
              vt,
            )
            is Some(_) ||
            gen_matching_global_idx(globals, vt) is Some(_) ||
            (
              ctx.config.features.allow_calls &&
              gen_valid_has_callable_with_result(funcs, vt)
            ) ||
            (
              ctx.config.features.allow_ref_types &&
              gen_valid_declared_ref_callable_with_result(
                funcs, declared_ref_func_idx, vt,
              )
              is Some(_)
            )
          if !has_existing_exact_route {
            locals.push(vt)
          }
        }
        _ => ()
      }
    }
  }
  if ctx.config.mode == CoverageForced {
    for vt in gc_type_plan.concrete_ref_types {
      locals.push(vt)
    }
    for vt in gc_type_plan.exact_ref_types {
      locals.push(vt)
    }
  }
  let all_local_types = gen_all_local_types(accepts, locals)
  let env : GenValidBodyEnv = {
    local_types: all_local_types,
    globals,
    tables,
    mems,
    tags,
    funcs,
    return_types: returns,
    data_idxs,
    passive_elem_idxs,
    passive_elem_ref_types,
    bulk_elem_seed_idx,
    gc_type_plan,
    declared_ref_func_idx,
    current_func_idx,
    depth_left: gen_valid_clamp_non_negative(ctx.config.max_body_depth),
    label_depth: 0,
  }
  let body_instrs : Array[Instruction] = []
  if ctx.config.mode == CoverageForced {
    gen_valid_append_coverage_prelude(body_instrs, ctx, env, returns)
  }
  let stmt_count = if ctx.config.mode == CoverageForced {
    0
  } else if ctx.config.mode == Natural &&
    !gc_type_plan.concrete_ref_types.is_empty() {
    0
  } else {
    gen_valid_body_stmt_count(ctx, env.depth_left)
  }
  for _ in 0..<stmt_count {
    append_void_stmt(body_instrs, ctx, env)
  }
  gen_valid_append_typed_body_generator_slice(body_instrs, ctx, env)
  if ctx.config.mode == Natural && ctx.config.features.allow_ref_types {
    let gc_stmt_count = if gc_type_plan.concrete_ref_types.is_empty() {
      1 + ctx.random_int(2)
    } else {
      2 + ctx.random_int(2)
    }
    for _ in 0..<gc_stmt_count {
      ignore(gen_valid_append_natural_gc_stmt(body_instrs, ctx, env))
    }
  }
  for ret in returns {
    gen_valid_append_return_value_instrs(body_instrs, ctx, ret, env)
  }
  Func::new(Locals::from_types(locals), Expr::new(body_instrs))
}

///|
pub fn gen_valid_tfunc(
  ctx : GenValidContext,
  accepts : Array[ValType],
  returns : Array[ValType],
) -> Func {
  gen_valid_build_func(
    ctx,
    accepts,
    returns,
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    None,
    gen_valid_gc_type_plan_empty(),
    None,
  )
}

///|
fn gen_valid_choose_optional_count_with_coverage_floor(
  ctx : GenValidContext,
  allow : Bool,
  max_count : Int,
  percent : Int,
  coverage_floor : Int,
) -> Int {
  let bounded_max = gen_valid_clamp_non_negative(max_count)
  if !allow || bounded_max <= 0 {
    0
  } else if ctx.config.mode == CoverageForced {
    let floor = gen_valid_min_int(
      bounded_max,
      gen_valid_clamp_non_negative(coverage_floor),
    )
    floor + ctx.random_int(bounded_max - floor + 1)
  } else if gen_valid_roll_percent(ctx, percent) {
    1 + ctx.random_int(bounded_max)
  } else {
    0
  }
}

///|
fn gen_valid_choose_optional_count(
  ctx : GenValidContext,
  allow : Bool,
  max_count : Int,
  percent : Int,
) -> Int {
  gen_valid_choose_optional_count_with_coverage_floor(
    ctx, allow, max_count, percent, 1,
  )
}

///|
fn gen_valid_choose_defined_func_count(ctx : GenValidContext) -> Int {
  let bounded_max = gen_valid_clamp_non_negative(ctx.config.max_defined_funcs)
  if bounded_max <= 1 {
    1
  } else if gen_valid_is_topology_heavy_config(ctx.config) {
    let floor = gen_valid_min_int(10, bounded_max)
    floor + ctx.random_int(bounded_max - floor + 1)
  } else if ctx.config.mode == CoverageForced {
    2 + ctx.random_int(bounded_max - 1)
  } else {
    1 + ctx.random_int(bounded_max)
  }
}

///|
fn gen_valid_active_i32_offset(
  ctx : GenValidContext,
  global_idx? : GlobalIdx? = None,
) -> Expr {
  if ctx.config.features.allow_const_expr_variants &&
    (ctx.config.mode == CoverageForced || ctx.random_int(4) == 0) {
    match global_idx {
      Some(idx) => return Expr::new([Instruction::global_get(idx)])
      None => ()
    }
  }
  Expr::new([Instruction::i32_const(I32(ctx.random_int(4)))])
}

///|
fn gen_valid_memory_limits_i32(
  min : UInt,
  max : UInt?,
  shared : Bool,
) -> MemType {
  MemType::new(Limits::i32(min, max), shared~)
}

///|
fn gen_valid_memory_limits_i64(
  min : UInt64,
  max : UInt64?,
  shared : Bool,
) -> MemType {
  MemType::new(Limits::i64(min, max), shared~)
}

///|
fn gen_valid_mem_type(ctx : GenValidContext, total_mem_idx : Int) -> MemType {
  let variants = ctx.config.features.allow_memory_limit_variants
  let shared_enabled = ctx.config.features.allow_shared_memories
  let memory64_enabled = ctx.config.features.allow_memory64
  if total_mem_idx == 0 {
    if variants && ctx.config.mode == CoverageForced {
      gen_valid_memory_limits_i32(0U, None, false)
    } else {
      let min = if variants && ctx.random_int(5) == 0 { 0U } else { 1U }
      let max = if variants && ctx.random_int(4) == 0 {
        None
      } else {
        Some(min + 1U + ctx.random_int(4).reinterpret_as_uint())
      }
      gen_valid_memory_limits_i32(min, max, false)
    }
  } else if shared_enabled &&
    ctx.config.mode == CoverageForced &&
    total_mem_idx == 1 {
    gen_valid_memory_limits_i32(1U, Some(2U), true)
  } else if memory64_enabled &&
    ctx.config.mode == CoverageForced &&
    total_mem_idx == 2 {
    gen_valid_memory_limits_i64(1UL, Some(2UL), false)
  } else if shared_enabled && ctx.random_int(6) == 0 {
    let min = if variants && ctx.random_int(3) == 0 { 0U } else { 1U }
    let max = Some(min + 1U + ctx.random_int(4).reinterpret_as_uint())
    gen_valid_memory_limits_i32(min, max, true)
  } else if memory64_enabled && ctx.random_int(5) == 0 {
    let min = if variants && ctx.random_int(3) == 0 { 0UL } else { 1UL }
    let max = if variants && ctx.random_int(4) == 0 {
      None
    } else {
      Some(min + 1UL + ctx.random_int(4).to_uint64())
    }
    gen_valid_memory_limits_i64(min, max, false)
  } else {
    let min = if variants && ctx.random_int(5) == 0 { 0U } else { 1U }
    let max = if variants && ctx.random_int(4) == 0 {
      None
    } else {
      Some(min + 1U + ctx.random_int(4).reinterpret_as_uint())
    }
    gen_valid_memory_limits_i32(min, max, false)
  }
}

///|
fn gen_valid_table_limits_i32(
  ctx : GenValidContext,
  total_table_idx : Int,
) -> Limits {
  if ctx.config.features.allow_table_limit_variants &&
    ctx.config.mode == CoverageForced &&
    total_table_idx == 1 {
    Limits::i32(0U, Some(3U))
  } else if ctx.config.features.allow_table_limit_variants &&
    ctx.config.mode == CoverageForced &&
    total_table_idx == 2 {
    Limits::i32(1U, None)
  } else {
    let min = if ctx.config.features.allow_table_limit_variants &&
      ctx.random_int(5) == 0 {
      0U
    } else {
      1U
    }
    let max = if ctx.config.features.allow_table_limit_variants &&
      ctx.random_int(4) == 0 {
      None
    } else {
      Some(min + 1U + ctx.random_int(4).reinterpret_as_uint())
    }
    Limits::i32(min, max)
  }
}

///|
fn gen_valid_table_ref_type(
  ctx : GenValidContext,
  total_table_idx : Int,
  gc_type_plan : GenValidGcTypePlan,
) -> RefType {
  if total_table_idx == 0 ||
    !ctx.config.features.allow_ref_types ||
    !ctx.config.features.allow_table_limit_variants {
    RefType::new(true, HeapType::abs(AbsHeapType::func()))
  } else if ctx.config.features.allow_table_limit_variants &&
    ctx.config.mode == CoverageForced &&
    total_table_idx == 1 {
    RefType::new(true, HeapType::abs(AbsHeapType::extern_()))
  } else if ctx.config.features.allow_table_limit_variants &&
    ctx.config.mode == CoverageForced &&
    total_table_idx >= 2 &&
    total_table_idx < 4 {
    RefType::new(true, HeapType::new(TypeIdx::new(0U)))
  } else if ctx.config.features.allow_table_limit_variants &&
    ctx.config.mode == CoverageForced &&
    total_table_idx >= 4 {
    RefType::new(true, HeapType::abs(AbsHeapType::func()))
  } else if ctx.config.features.allow_table_limit_variants &&
    ctx.random_int(6) == 0 {
    RefType::new(true, HeapType::abs(AbsHeapType::extern_()))
  } else if !gc_type_plan.concrete_ref_types.is_empty() &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0) {
    match
      gc_type_plan.concrete_ref_types[ctx.random_int(
        gc_type_plan.concrete_ref_types.length(),
      )] {
      RefTypeValType(rt) => rt
      _ => RefType::new(true, HeapType::abs(AbsHeapType::eq()))
    }
  } else {
    RefType::new(true, HeapType::abs(AbsHeapType::eq()))
  }
}

///|
fn gen_valid_table_type(
  ctx : GenValidContext,
  total_table_idx : Int,
  gc_type_plan : GenValidGcTypePlan,
) -> TableType {
  TableType::new(
    gen_valid_table_ref_type(ctx, total_table_idx, gc_type_plan),
    gen_valid_table_limits_i32(ctx, total_table_idx),
  )
}

///|
fn gen_valid_table_init_expr(
  ctx : GenValidContext,
  total_table_idx : Int,
  rt : RefType,
  func_idx : FuncIdx,
  imported_global_types : Array[GlobalType],
) -> Expr? {
  if ctx.config.features.allow_const_expr_variants &&
    (ctx.config.mode == CoverageForced || ctx.random_int(4) == 0) {
    match
      gen_matching_immutable_global_idx(
        imported_global_types,
        ValType::ref_type(rt),
      ) {
      Some(idx) => return Some(Expr::new([Instruction::global_get(idx)]))
      None => ()
    }
  }
  if ctx.config.features.allow_table_limit_variants &&
    ctx.config.mode == CoverageForced &&
    total_table_idx > 0 {
    Some(gen_valid_elem_ref_expr(ctx, rt, func_idx~))
  } else if ctx.config.features.allow_table_limit_variants &&
    ctx.random_int(5) == 0 {
    Some(gen_valid_elem_ref_expr(ctx, rt, func_idx~))
  } else {
    None
  }
}

///|
fn gen_valid_rec_type_flat_count(rec_type : RecType) -> Int {
  match rec_type {
    SingleRecType(_) => 1
    GroupRecType(group) => group.length()
  }
}

///|
fn gen_valid_rec_types_flat_count(rec_types : Array[RecType]) -> Int {
  let mut count = 0
  for rec_type in rec_types {
    count += gen_valid_rec_type_flat_count(rec_type)
  }
  count
}

///|
fn gen_valid_pick_type_idx(ctx : GenValidContext, type_count : Int) -> TypeIdx {
  TypeIdx::new(ctx.random_int(type_count).reinterpret_as_uint())
}

///|
fn gen_valid_import_module_name(ctx : GenValidContext, index : Int) -> Name {
  if gen_valid_is_topology_heavy_config(ctx.config) {
    match index % 3 {
      0 => Name::new("env")
      1 => Name::new("fzg.topology.a")
      _ => Name::new("fzg.topology.b")
    }
  } else {
    Name::new("env")
  }
}

///|
fn gen_valid_module_once_with_config(
  rnd : RandomState,
  config : GenValidConfig,
) -> Module {
  let ctx = GenValidContext::new(rnd, config)
  let import_budget = gen_valid_choose_optional_count_with_coverage_floor(
    ctx,
    config.features.allow_imports,
    config.max_imports,
    config.section_bias.imports_percent,
    if config.features.allow_const_expr_variants &&
      config.features.allow_globals {
      6
    } else {
      5
    },
  )
  let mut import_plan : GenValidImportPlan = {
    func_count: 0,
    table_count: 0,
    mem_count: 0,
    global_count: 0,
    tag_count: 0,
  }
  let mut remaining_imports = import_budget
  if ctx.config.mode == CoverageForced {
    if remaining_imports > 0 {
      import_plan = { ..import_plan, func_count: 1 }
      remaining_imports -= 1
    }
    if config.features.allow_tables && remaining_imports > 0 {
      import_plan = { ..import_plan, table_count: 1 }
      remaining_imports -= 1
    }
    if config.features.allow_mems && remaining_imports > 0 {
      import_plan = { ..import_plan, mem_count: 1 }
      remaining_imports -= 1
    }
    if config.features.allow_globals && remaining_imports > 0 {
      import_plan = { ..import_plan, global_count: 1 }
      remaining_imports -= 1
    }
    if config.features.allow_tags && remaining_imports > 0 {
      import_plan = { ..import_plan, tag_count: 1 }
      remaining_imports -= 1
    }
    if config.features.allow_const_expr_variants &&
      config.features.allow_globals &&
      remaining_imports > 0 {
      import_plan = {
        ..import_plan,
        global_count: import_plan.global_count + 1,
      }
      remaining_imports -= 1
    }
  }
  let import_choice_count = 1 +
    gen_valid_bool_count(config.features.allow_tables) +
    gen_valid_bool_count(config.features.allow_mems) +
    gen_valid_bool_count(config.features.allow_globals) +
    gen_valid_bool_count(config.features.allow_tags)
  while remaining_imports > 0 {
    let mut choice = ctx.random_int(import_choice_count)
    if choice == 0 {
      import_plan = { ..import_plan, func_count: import_plan.func_count + 1 }
    } else {
      choice -= 1
      if config.features.allow_tables && choice == 0 {
        import_plan = {
          ..import_plan,
          table_count: import_plan.table_count + 1,
        }
      } else {
        if config.features.allow_tables {
          choice -= 1
        }
        if config.features.allow_mems && choice == 0 {
          import_plan = { ..import_plan, mem_count: import_plan.mem_count + 1 }
        } else {
          if config.features.allow_mems {
            choice -= 1
          }
          if config.features.allow_globals && choice == 0 {
            import_plan = {
              ..import_plan,
              global_count: import_plan.global_count + 1,
            }
          } else {
            import_plan = {
              ..import_plan,
              tag_count: import_plan.tag_count + 1,
            }
          }
        }
      }
    }
    remaining_imports -= 1
  }

  let import_func_count = import_plan.func_count
  let import_table_count = import_plan.table_count
  let import_mem_count = import_plan.mem_count
  let import_global_count = import_plan.global_count
  let import_tag_count = import_plan.tag_count

  let defined_func_count = gen_valid_choose_defined_func_count(ctx)
  let defined_table_count = gen_valid_choose_optional_count_with_coverage_floor(
    ctx,
    config.features.allow_tables,
    config.max_tables,
    config.section_bias.tables_percent,
    if config.features.allow_table_limit_variants &&
      config.features.allow_ref_types {
      4
    } else {
      1
    },
  )
  let defined_mem_count = gen_valid_choose_optional_count_with_coverage_floor(
    ctx,
    config.features.allow_mems,
    config.max_mems,
    config.section_bias.mems_percent,
    if config.features.allow_memory_limit_variants ||
      config.features.allow_shared_memories ||
      config.features.allow_memory64 {
      2
    } else {
      1
    },
  )
  let defined_global_count = gen_valid_choose_optional_count_with_coverage_floor(
    ctx,
    config.features.allow_globals,
    config.max_globals,
    config.section_bias.globals_percent,
    if config.features.allow_const_expr_variants {
      4
    } else {
      1
    },
  )
  let defined_tag_count = gen_valid_choose_optional_count(
    ctx,
    config.features.allow_tags,
    config.max_tags,
    config.section_bias.tags_percent,
  )

  let total_table_count = import_table_count + defined_table_count
  let total_mem_count = import_mem_count + defined_mem_count
  let total_global_count = import_global_count + defined_global_count
  let total_tag_count = import_tag_count + defined_tag_count

  let elem_count = if total_table_count > 0 {
    gen_valid_choose_optional_count_with_coverage_floor(
      ctx,
      config.features.allow_elems,
      config.max_elems,
      config.section_bias.elems_percent,
      if ctx.config.mode == CoverageForced {
        4
      } else {
        3
      },
    )
  } else {
    0
  }
  let data_count = if total_mem_count > 0 {
    gen_valid_choose_optional_count_with_coverage_floor(
      ctx,
      config.features.allow_datas,
      config.max_datas,
      config.section_bias.datas_percent,
      2,
    )
  } else {
    0
  }

  let has_start = config.features.allow_start &&
    (
      ctx.config.mode == CoverageForced ||
      gen_valid_roll_percent(ctx, config.section_bias.start_percent)
    )
  let total_type_users = import_func_count +
    defined_func_count +
    total_tag_count
  let max_type_defs = if gen_valid_clamp_non_negative(config.max_type_defs) <= 0 {
    1
  } else {
    gen_valid_clamp_non_negative(config.max_type_defs)
  }
  let reserved_gc_slots = if ctx.config.mode == Natural &&
    config.features.allow_ref_types &&
    max_type_defs > 1 {
    gen_valid_min_int(3, max_type_defs - 1)
  } else {
    0
  }
  let func_type_cap = if max_type_defs - reserved_gc_slots > 1 {
    max_type_defs - reserved_gc_slots
  } else {
    1
  }
  let mut func_type_count = if ctx.config.mode == CoverageForced &&
    total_type_users > 1 {
    1 + ctx.random_int(gen_valid_min_int(func_type_cap, total_type_users - 1))
  } else {
    1 + ctx.random_int(func_type_cap)
  }
  if ctx.config.features.allow_typed_body_generator &&
    func_type_cap > 1 &&
    func_type_count < 2 {
    func_type_count = 2
  }

  let remaining_type_budget = max_type_defs - func_type_count
  let (gc_type_defs, gc_type_plan) = gen_valid_gc_type_defs(
    ctx, func_type_count, remaining_type_budget,
  )

  let payload_tag_type_idx = if ctx.config.mode == CoverageForced &&
    config.features.allow_tags &&
    total_tag_count > 1 {
    Some(
      TypeIdx::new(
        (func_type_count + gen_valid_rec_types_flat_count(gc_type_defs)).reinterpret_as_uint(),
      ),
    )
  } else {
    None
  }
  let type_defs : Array[RecType] = []
  let type_params : Array[Array[ValType]] = []
  let type_results : Array[Array[ValType]] = []
  let exact_result_slot = if gc_type_plan.exact_ref_types.is_empty() {
    None
  } else if has_start || total_tag_count > 0 {
    if func_type_count > 1 {
      Some(func_type_count - 1)
    } else {
      None
    }
  } else {
    Some(func_type_count - 1)
  }
  for i = 0; i < func_type_count; i = i + 1 {
    let params = if i == 0 && (has_start || total_tag_count > 0) {
      []
    } else if ctx.config.features.allow_typed_body_generator && i == 1 {
      []
    } else {
      gen_param_types(ctx)
    }
    let results = if i == 0 && (has_start || total_tag_count > 0) {
      []
    } else if ctx.config.features.allow_typed_body_generator && i == 1 {
      [ValType::i32(), ValType::i64()]
    } else if exact_result_slot == Some(i) {
      [
        gc_type_plan.exact_ref_types[ctx.random_int(
          gc_type_plan.exact_ref_types.length(),
        )],
      ]
    } else {
      gen_result_types(ctx, extra_ref_types=gc_type_plan.exact_ref_types)
    }
    type_params.push(params)
    type_results.push(results)
    type_defs.push(
      RecType::new(SubType::comp_type(CompType::func(params, results))),
    )
  }
  for rec_type in gc_type_defs {
    type_defs.push(rec_type)
  }
  match payload_tag_type_idx {
    Some(_) => {
      type_defs.push(
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      )
      type_params.push([ValType::i32()])
      type_results.push([])
    }
    None => ()
  }

  let imports : Array[Import] = []
  for i = 0; i < import_func_count; i = i + 1 {
    let type_idx = gen_valid_pick_type_idx(ctx, func_type_count)
    imports.push(
      Import::new(
        gen_valid_import_module_name(ctx, i),
        Name::new("imported_func_\{i}"),
        ExternType::func(type_idx),
      ),
    )
  }
  let imported_tables : Array[TableType] = []
  for i = 0; i < import_table_count; i = i + 1 {
    let table_type = gen_valid_table_type(ctx, i, gc_type_plan)
    imported_tables.push(table_type)
    imports.push(
      Import::new(
        gen_valid_import_module_name(ctx, import_func_count + i),
        Name::new("imported_table_\{i}"),
        ExternType::table(table_type),
      ),
    )
  }
  let imported_mems : Array[MemType] = []
  for i = 0; i < import_mem_count; i = i + 1 {
    let mem_type = gen_valid_mem_type(ctx, i)
    imported_mems.push(mem_type)
    imports.push(
      Import::new(
        gen_valid_import_module_name(
          ctx,
          import_func_count + import_table_count + i,
        ),
        Name::new("imported_memory_\{i}"),
        ExternType::mem(mem_type),
      ),
    )
  }
  let imported_global_types : Array[GlobalType] = []
  for i = 0; i < import_global_count; i = i + 1 {
    let global_vt = if ctx.config.features.allow_const_expr_variants &&
      ctx.config.mode == CoverageForced &&
      i == 0 {
      ValType::i32()
    } else if ctx.config.features.allow_const_expr_variants &&
      ctx.config.mode == CoverageForced &&
      i == 1 {
      ValType::externref()
    } else if i == 0 &&
      !gc_type_plan.exact_ref_types.is_empty() &&
      (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0) {
      gc_type_plan.exact_ref_types[ctx.random_int(
        gc_type_plan.exact_ref_types.length(),
      )]
    } else if i == 0 &&
      !gc_type_plan.concrete_ref_types.is_empty() &&
      (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0) {
      gc_type_plan.concrete_ref_types[0]
    } else {
      let global_ref_types = gc_type_plan.concrete_ref_types.copy()
      for vt in gc_type_plan.exact_ref_types {
        global_ref_types.push(vt)
      }
      gen_valid_valtype_with_extra_refs(ctx, global_ref_types)
    }
    let is_mut = if ctx.config.features.allow_const_expr_variants &&
      ctx.config.mode == CoverageForced &&
      i <= 1 {
      false
    } else {
      ctx.config.mode == CoverageForced || ctx.random_bool()
    }
    let global_type = GlobalType::new(global_vt, is_mut)
    imported_global_types.push(global_type)
    imports.push(
      Import::new(
        gen_valid_import_module_name(
          ctx,
          import_func_count + import_table_count + import_mem_count + i,
        ),
        Name::new("imported_global_\{i}"),
        ExternType::global(global_type),
      ),
    )
  }
  let imported_tag_types : Array[TagType] = []
  for i = 0; i < import_tag_count; i = i + 1 {
    let tag_type = TagType::new(
      match payload_tag_type_idx {
        Some(payload_idx) if i == 1 => payload_idx
        _ => TypeIdx::new(0U)
      },
    )
    imported_tag_types.push(tag_type)
    imports.push(
      Import::new(
        gen_valid_import_module_name(
          ctx,
          import_func_count +
          import_table_count +
          import_mem_count +
          import_global_count +
          i,
        ),
        Name::new("imported_tag_\{i}"),
        ExternType::tag(tag_type),
      ),
    )
  }

  let first_defined_func_idx = FuncIdx::new(
    import_func_count.reinterpret_as_uint(),
  )

  let globals : Array[Global] = []
  let global_types_for_inits = imported_global_types.copy()
  for i = 0; i < defined_global_count; i = i + 1 {
    let vt = if ctx.config.features.allow_const_expr_variants &&
      ctx.config.mode == CoverageForced &&
      i <= 1 {
      ValType::i32()
    } else if ctx.config.features.allow_const_expr_variants &&
      ctx.config.mode == CoverageForced &&
      i == 2 {
      ValType::funcref()
    } else if ctx.config.features.allow_const_expr_variants &&
      ctx.config.mode == CoverageForced &&
      i == 3 &&
      !gc_type_plan.struct_type_idxs.is_empty() {
      ValType::ref_type(
        RefType::new(
          true,
          HeapType::new(gc_type_plan.struct_type_idxs[0]),
          exact=true,
        ),
      )
    } else if ctx.config.features.allow_const_expr_variants &&
      ctx.config.mode == CoverageForced &&
      i == 4 {
      ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::new(0U))))
    } else if i == 0 &&
      !gc_type_plan.exact_ref_types.is_empty() &&
      (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0) {
      gc_type_plan.exact_ref_types[ctx.random_int(
        gc_type_plan.exact_ref_types.length(),
      )]
    } else if i == 0 &&
      !gc_type_plan.concrete_ref_types.is_empty() &&
      (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0) {
      gc_type_plan.concrete_ref_types[0]
    } else {
      let global_ref_types = gc_type_plan.concrete_ref_types.copy()
      for exact_vt in gc_type_plan.exact_ref_types {
        global_ref_types.push(exact_vt)
      }
      gen_valid_valtype_with_extra_refs(ctx, global_ref_types)
    }
    let is_mut = if ctx.config.features.allow_const_expr_variants &&
      ctx.config.mode == CoverageForced &&
      i <= 1 {
      false
    } else {
      ctx.config.mode == CoverageForced || ctx.random_bool()
    }
    let global_type = GlobalType::new(vt, is_mut)
    globals.push(
      Global::new(
        global_type,
        gen_valid_const_expr_for_global(
          ctx, vt, global_types_for_inits, first_defined_func_idx, gc_type_plan,
        ),
      ),
    )
    global_types_for_inits.push(global_type)
  }
  let global_types = global_types_for_inits

  let func_type_idxs : Array[TypeIdx] = []
  for i = 0; i < defined_func_count; i = i + 1 {
    func_type_idxs.push(
      if i == 0 && (has_start || ctx.config.mode == CoverageForced) {
        TypeIdx::new(0U)
      } else if ctx.config.features.allow_typed_body_generator &&
        i == 1 &&
        func_type_count > 1 {
        TypeIdx::new(1U)
      } else {
        gen_valid_pick_type_idx(ctx, func_type_count)
      },
    )
  }
  let tables : Array[Table] = []
  for i = 0; i < defined_table_count; i = i + 1 {
    let total_table_idx = import_table_count + i
    let table_type = gen_valid_table_type(ctx, total_table_idx, gc_type_plan)
    let TableType(table_ref_type, _) = table_type
    tables.push(
      Table::new(
        table_type,
        gen_valid_table_init_expr(
          ctx, total_table_idx, table_ref_type, first_defined_func_idx, imported_global_types,
        ),
      ),
    )
  }
  let table_types = imported_tables.copy()
  for table in tables {
    let Table(table_type, _) = table
    table_types.push(table_type)
  }

  let mems : Array[MemType] = imported_mems.copy()
  let defined_mems : Array[MemType] = []
  for i = 0; i < defined_mem_count; i = i + 1 {
    let mem_type = gen_valid_mem_type(ctx, import_mem_count + i)
    defined_mems.push(mem_type)
    mems.push(mem_type)
  }

  let func_sigs : Array[GenValidFuncSig] = []
  for i = 0; i < imports.length(); i = i + 1 {
    let Import(_, _, extern_type) = imports[i]
    match extern_type {
      FuncExternType(type_idx) => {
        let type_idx_i = match type_idx {
          TypeIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
          RecIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
        }
        func_sigs.push({
          idx: FuncIdx::new(i.reinterpret_as_uint()),
          type_idx,
          params: type_params[type_idx_i],
          results: type_results[type_idx_i],
        })
      }
      _ => ()
    }
  }
  for i = 0; i < func_type_idxs.length(); i = i + 1 {
    let type_idx = func_type_idxs[i]
    let type_idx_i = match type_idx {
      TypeIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
      RecIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
    }
    func_sigs.push({
      idx: FuncIdx::new((import_func_count + i).reinterpret_as_uint()),
      type_idx,
      params: type_params[type_idx_i],
      results: type_results[type_idx_i],
    })
  }

  let total_func_count = import_func_count + defined_func_count
  let const_i32_global_idx = if ctx.config.features.allow_const_expr_variants {
    gen_matching_immutable_global_idx(global_types, ValType::i32())
  } else {
    None
  }
  let tags : Array[TagType] = []
  for i = 0; i < defined_tag_count; i = i + 1 {
    tags.push(
      TagType::new(
        match payload_tag_type_idx {
          Some(payload_idx) if i == 1 => payload_idx
          _ => TypeIdx::new(0U)
        },
      ),
    )
  }
  let all_tags = imported_tag_types.copy()
  for tag in tags {
    all_tags.push(tag)
  }

  let elems : Array[Elem] = []
  if total_table_count > 0 && total_func_count > 0 {
    for i = 0; i < elem_count; i = i + 1 {
      let func_idx = gen_valid_pick_func_idx(
        ctx, total_func_count, first_defined_func_idx,
      )
      let FuncIdx(func_idx_u) = func_idx
      let second_func_idx_u = ((func_idx_u.reinterpret_as_int() + 1) %
      total_func_count).reinterpret_as_uint()
      let second_func_idx = FuncIdx::new(second_func_idx_u)
      let gc_table_choice = if table_types.length() > 1 {
        Some(
          TableIdx::new(
            (1 + ctx.random_int(table_types.length() - 1)).reinterpret_as_uint(),
          ),
        )
      } else {
        None
      }
      let gc_table_ref_type = match gc_table_choice {
        Some(table_idx) => {
          let TableIdx(table_idx_u) = table_idx
          let TableType(rt, _) = table_types[table_idx_u.reinterpret_as_int()]
          Some(rt)
        }
        None => None
      }
      let elem = if ctx.config.mode == CoverageForced && i == 0 {
        Elem::new(
          ElemMode::active(
            TableIdx::new(0U),
            gen_valid_active_i32_offset(ctx, global_idx=const_i32_global_idx),
          ),
          ElemKind::funcs([func_idx, second_func_idx]),
        )
      } else if ctx.config.mode == CoverageForced && i == 1 {
        Elem::new(
          ElemMode::passive(),
          ElemKind::typed_exprs(RefType::abs(AbsHeapType::func()), [
            gen_valid_funcref_expr(ctx, func_idx),
          ]),
        )
      } else if ctx.config.mode == CoverageForced && i == 2 {
        Elem::new(
          ElemMode::declarative(),
          ElemKind::func_exprs([gen_valid_funcref_expr(ctx, func_idx)]),
        )
      } else if ctx.config.mode == CoverageForced && i == 3 {
        match gen_valid_first_nonzero_funcref_table_idx(table_types) {
          Some(table_idx) =>
            Elem::new(
              ElemMode::active(
                table_idx,
                gen_valid_active_i32_offset(
                  ctx,
                  global_idx=const_i32_global_idx,
                ),
              ),
              ElemKind::funcs([func_idx, second_func_idx]),
            )
          None =>
            match (gc_table_choice, gc_table_ref_type) {
              (Some(table_idx), Some(rt)) if ValType::ref_type(rt) !=
                ValType::funcref() =>
                Elem::new(
                  ElemMode::active(
                    table_idx,
                    gen_valid_active_i32_offset(
                      ctx,
                      global_idx=const_i32_global_idx,
                    ),
                  ),
                  ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
                )
              _ =>
                match gc_type_plan.bulk_elem_ref_type {
                  Some(rt) =>
                    Elem::new(
                      ElemMode::passive(),
                      ElemKind::typed_exprs(rt, [
                        gen_valid_elem_ref_expr(ctx, rt),
                        gen_valid_elem_ref_expr(ctx, rt),
                      ]),
                    )
                  None =>
                    Elem::new(ElemMode::passive(), ElemKind::funcs([func_idx]))
                }
            }
        }
      } else if (match gc_type_plan.bulk_elem_ref_type {
          Some(_) => ctx.random_int(4) == 0
          None => false
        }) {
        match gc_type_plan.bulk_elem_ref_type {
          Some(rt) =>
            Elem::new(
              ElemMode::passive(),
              ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
            )
          None => Elem::new(ElemMode::passive(), ElemKind::funcs([func_idx]))
        }
      } else if (match gc_table_ref_type {
          Some(rt) =>
            ValType::ref_type(rt) != ValType::funcref() &&
            ctx.random_int(3) == 0
          None => false
        }) {
        match (gc_table_choice, gc_table_ref_type) {
          (Some(table_idx), Some(rt)) =>
            Elem::new(
              ElemMode::active(
                table_idx,
                gen_valid_active_i32_offset(
                  ctx,
                  global_idx=const_i32_global_idx,
                ),
              ),
              ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
            )
          _ => Elem::new(ElemMode::passive(), ElemKind::funcs([func_idx]))
        }
      } else {
        match ctx.random_int(7) {
          0 =>
            Elem::new(
              ElemMode::active(
                TableIdx::new(0U),
                gen_valid_active_i32_offset(
                  ctx,
                  global_idx=const_i32_global_idx,
                ),
              ),
              ElemKind::funcs([func_idx]),
            )
          1 => Elem::new(ElemMode::passive(), ElemKind::funcs([func_idx]))
          2 => Elem::new(ElemMode::declarative(), ElemKind::funcs([func_idx]))
          3 =>
            Elem::new(
              ElemMode::passive(),
              ElemKind::typed_exprs(RefType::abs(AbsHeapType::func()), [
                gen_valid_funcref_expr(ctx, func_idx),
              ]),
            )
          4 =>
            Elem::new(
              ElemMode::active(
                TableIdx::new(0U),
                gen_valid_active_i32_offset(
                  ctx,
                  global_idx=const_i32_global_idx,
                ),
              ),
              ElemKind::func_exprs([gen_valid_funcref_expr(ctx, func_idx)]),
            )
          5 =>
            match (gc_table_choice, gc_table_ref_type) {
              (Some(table_idx), Some(rt)) if ValType::ref_type(rt) !=
                ValType::funcref() =>
                Elem::new(
                  ElemMode::active(
                    table_idx,
                    gen_valid_active_i32_offset(
                      ctx,
                      global_idx=const_i32_global_idx,
                    ),
                  ),
                  ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
                )
              _ => Elem::new(ElemMode::passive(), ElemKind::funcs([func_idx]))
            }
          _ =>
            match gc_table_ref_type {
              Some(rt) if ValType::ref_type(rt) != ValType::funcref() =>
                Elem::new(
                  ElemMode::passive(),
                  ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
                )
              _ =>
                Elem::new(
                  ElemMode::declarative(),
                  ElemKind::func_exprs([gen_valid_funcref_expr(ctx, func_idx)]),
                )
            }
        }
      }
      elems.push(elem)
    }
  }
  let elem_idxs : Array[ElemIdx] = []
  let passive_elem_idxs : Array[ElemIdx] = []
  let passive_elem_ref_types : Array[RefType] = []
  let mut bulk_elem_seed_idx : ElemIdx? = None
  for i = 0; i < elems.length(); i = i + 1 {
    let elem_idx = ElemIdx::new(i.reinterpret_as_uint())
    let Elem(mode, kind) = elems[i]
    match mode {
      Active(_, _) => ()
      Passive => {
        elem_idxs.push(elem_idx)
        passive_elem_idxs.push(elem_idx)
        passive_elem_ref_types.push(elems[i].reftype())
        match (bulk_elem_seed_idx, gc_type_plan.bulk_elem_ref_type, kind) {
          (None, Some(seed_rt), TypedExprsElemKind(rt, _)) if rt == seed_rt =>
            bulk_elem_seed_idx = Some(elem_idx)
          _ => ()
        }
      }
      Declarative => elem_idxs.push(elem_idx)
    }
  }

  let datas : Array[Data] = []
  if total_mem_count > 0 {
    for i = 0; i < data_count; i = i + 1 {
      let data = if ctx.config.mode == CoverageForced && i == 0 {
        Data::new(
          DataMode::active(
            if total_mem_count > 1 {
              MemIdx::new(1U)
            } else {
              MemIdx::new(0U)
            },
            gen_valid_active_i32_offset(ctx, global_idx=const_i32_global_idx),
          ),
          b"gen-valid-active-with-a-larger-payload",
        )
      } else if ctx.config.mode == CoverageForced && i == 1 {
        Data::new(DataMode::passive(), b"")
      } else if ctx.config.mode == CoverageForced && i == 2 {
        Data::new(
          DataMode::active(
            MemIdx::new(0U),
            Expr::new([Instruction::i32_const(0)]),
          ),
          b"",
        )
      } else if ctx.config.mode == CoverageForced && i == 3 {
        Data::new(DataMode::passive(), b"\x00\x01\x02\x03\x04\x05\x06\x07")
      } else {
        let payload = match ctx.random_int(4) {
          0 => b""
          1 => b"gen-valid"
          2 => b"bulk-seed"
          _ => b"\x00\x01\x02"
        }
        if ctx.random_int(3) == 0 {
          Data::new(DataMode::passive(), payload)
        } else {
          let mem_idx = if total_mem_count > 1 && ctx.random_int(4) == 0 {
            MemIdx::new(1U)
          } else {
            MemIdx::new(0U)
          }
          let offset = if ctx.random_int(3) == 0 {
            Expr::new([Instruction::i32_const(ctx.random_int(4))])
          } else {
            gen_valid_active_i32_offset(ctx, global_idx=const_i32_global_idx)
          }
          Data::new(DataMode::active(mem_idx, offset), payload)
        }
      }
      datas.push(data)
    }
  }
  let data_idxs : Array[DataIdx] = []
  for i = 0; i < datas.length(); i = i + 1 {
    let Data(mode, _) = datas[i]
    match mode {
      Active(_, _) => ()
      Passive => data_idxs.push(DataIdx::new(i.reinterpret_as_uint()))
    }
  }

  let funcs : Array[Func] = []
  for i = 0; i < func_type_idxs.length(); i = i + 1 {
    let type_idx = func_type_idxs[i]
    let type_idx_i = match type_idx {
      TypeIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
      RecIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
    }
    funcs.push(
      gen_valid_build_func(
        ctx,
        type_params[type_idx_i],
        type_results[type_idx_i],
        global_types,
        table_types,
        mems,
        all_tags,
        func_sigs,
        data_idxs,
        elem_idxs,
        passive_elem_idxs,
        passive_elem_ref_types,
        bulk_elem_seed_idx,
        gc_type_plan,
        Some(first_defined_func_idx),
        current_func_idx=Some(
          FuncIdx::new((import_func_count + i).reinterpret_as_uint()),
        ),
      ),
    )
  }

  let topology_export_mode = if gen_valid_is_topology_heavy_config(config) {
    ctx.random_int(8)
  } else {
    7
  }
  let exports : Array[Export] = []
  if topology_export_mode != 0 {
    let primary_func_export_name = if topology_export_mode == 1 {
      "entry"
    } else {
      "main"
    }
    let alias_func_export_name = if topology_export_mode == 1 {
      "entry.alias"
    } else {
      "main.alias"
    }
    exports.push(
      Export::new(
        Name::new(primary_func_export_name),
        ExternIdx::func(first_defined_func_idx),
      ),
    )
    if gen_valid_is_topology_heavy_config(config) {
      exports.push(
        Export::new(
          Name::new(alias_func_export_name),
          ExternIdx::func(first_defined_func_idx),
        ),
      )
      if import_func_count > 0 {
        exports.push(
          Export::new(
            Name::new("imported_func_0.reexport"),
            ExternIdx::func(FuncIdx::new(0U)),
          ),
        )
      }
    }
    if total_table_count > 0 {
      exports.push(
        Export::new(Name::new("table0"), ExternIdx::table(TableIdx::new(0U))),
      )
      if gen_valid_is_topology_heavy_config(config) && total_table_count > 1 {
        exports.push(
          Export::new(Name::new("table1"), ExternIdx::table(TableIdx::new(1U))),
        )
      }
    }
    if total_mem_count > 0 {
      exports.push(
        Export::new(Name::new("memory0"), ExternIdx::mem(MemIdx::new(0U))),
      )
      if gen_valid_is_topology_heavy_config(config) && total_mem_count > 1 {
        exports.push(
          Export::new(Name::new("memory1"), ExternIdx::mem(MemIdx::new(1U))),
        )
      }
    }
    if total_global_count > 0 {
      exports.push(
        Export::new(Name::new("global0"), ExternIdx::global(GlobalIdx::new(0U))),
      )
      if gen_valid_is_topology_heavy_config(config) && total_global_count > 1 {
        exports.push(
          Export::new(
            Name::new("global1"),
            ExternIdx::global(GlobalIdx::new(1U)),
          ),
        )
      }
    }
    if total_tag_count > 0 {
      exports.push(
        Export::new(Name::new("tag0"), ExternIdx::tag(TagIdx::new(0U))),
      )
      if gen_valid_is_topology_heavy_config(config) && total_tag_count > 1 {
        exports.push(
          Export::new(Name::new("tag1"), ExternIdx::tag(TagIdx::new(1U))),
        )
      }
    }
  }

  let mut mod = Module::new().with_type_sec(TypeSec::new(type_defs))
  if !imports.is_empty() {
    mod = mod.with_import_sec(ImportSec::new(imports))
  }
  mod = mod.with_func_sec(FuncSec::new(func_type_idxs))
  if !tables.is_empty() {
    mod = mod.with_table_sec(TableSec::new(tables))
  }
  if !defined_mems.is_empty() {
    mod = mod.with_mem_sec(MemSec::new(defined_mems))
  }
  if !globals.is_empty() {
    mod = mod.with_global_sec(GlobalSec::new(globals))
  }
  if !tags.is_empty() {
    mod = mod.with_tag_sec(TagSec::new(tags))
  }
  if has_start {
    mod = mod.with_start_sec(StartSec::new(first_defined_func_idx))
  }
  if !elems.is_empty() {
    mod = mod.with_elem_sec(ElemSec::new(elems))
  }
  if !datas.is_empty() {
    mod = mod.with_data_cnt_sec(
      DataCntSec::new(U32(datas.length().reinterpret_as_uint())),
    )
  }
  mod = mod.with_code_sec(CodeSec::new(funcs))
  if !datas.is_empty() {
    mod = mod.with_data_sec(DataSec::new(datas))
  }
  if config.features.allow_name_custom_sections &&
    (config.mode == CoverageForced || ctx.random_int(3) == 0) {
    let func_name_entries : Array[NameAssoc] = []
    if !funcs.is_empty() {
      func_name_entries.push(NameAssoc::new(0U, Name::new("fzg_func0")))
    }
    let type_name_entries : Array[NameAssoc] = []
    if !type_defs.is_empty() {
      type_name_entries.push(NameAssoc::new(0U, Name::new("fzg_type0")))
    }
    let table_name_entries : Array[NameAssoc] = []
    if total_table_count > 0 {
      table_name_entries.push(NameAssoc::new(0U, Name::new("fzg_table0")))
    }
    let memory_name_entries : Array[NameAssoc] = []
    if total_mem_count > 0 {
      memory_name_entries.push(NameAssoc::new(0U, Name::new("fzg_memory0")))
    }
    let global_name_entries : Array[NameAssoc] = []
    if total_global_count > 0 {
      global_name_entries.push(NameAssoc::new(0U, Name::new("fzg_global0")))
    }
    let elem_name_entries : Array[NameAssoc] = []
    if !elems.is_empty() {
      elem_name_entries.push(NameAssoc::new(0U, Name::new("fzg_elem0")))
    }
    let data_name_entries : Array[NameAssoc] = []
    if !datas.is_empty() {
      data_name_entries.push(NameAssoc::new(0U, Name::new("fzg_data0")))
    }
    let tag_name_entries : Array[NameAssoc] = []
    if total_tag_count > 0 {
      tag_name_entries.push(NameAssoc::new(0U, Name::new("fzg_tag0")))
    }
    let name_sec = NameSec::new(
      module_name=Some(Name::new("fzg_module")),
      func_names=if func_name_entries.is_empty() {
        None
      } else {
        Some(NameMap::new(func_name_entries))
      },
      type_names=if type_name_entries.is_empty() {
        None
      } else {
        Some(NameMap::new(type_name_entries))
      },
      table_names=if table_name_entries.is_empty() {
        None
      } else {
        Some(NameMap::new(table_name_entries))
      },
      memory_names=if memory_name_entries.is_empty() {
        None
      } else {
        Some(NameMap::new(memory_name_entries))
      },
      global_names=if global_name_entries.is_empty() {
        None
      } else {
        Some(NameMap::new(global_name_entries))
      },
      elem_names=if elem_name_entries.is_empty() {
        None
      } else {
        Some(NameMap::new(elem_name_entries))
      },
      data_names=if data_name_entries.is_empty() {
        None
      } else {
        Some(NameMap::new(data_name_entries))
      },
      tag_names=if tag_name_entries.is_empty() {
        None
      } else {
        Some(NameMap::new(tag_name_entries))
      },
    )
    mod = mod.with_name_sec(name_sec)
    let custom_secs = if gen_valid_is_topology_heavy_config(config) {
      [
        @lib.CustomSec::new(
          Name::new("fzg.custom.leading"),
          b"valid-fzg-custom-leading",
        ),
        @lib.CustomSec::new(
          Name::new("fzg.custom.topology"),
          b"valid-fzg-custom-topology",
        ),
      ]
    } else {
      [@lib.CustomSec::new(Name::new("fzg.custom"), b"valid-fzg-custom")]
    }
    mod = mod.with_custom_secs(custom_secs)
  }
  if exports.is_empty() {
    mod
  } else {
    mod.with_export_sec(ExportSec::new(exports))
  }
}

///|
pub fn gen_valid_module_result(
  rnd : RandomState,
  config : GenValidConfig,
) -> Result[GenValidGenerated, GenValidFailure] {
  let max_attempts = if config.mode == CoverageForced { 512 } else { 64 }
  let config_label = gen_valid_config_label(config)
  let mut attempt = 1
  let mut last = gen_valid_module_once_with_config(rnd, config)
  let mut last_error_message = ""
  while attempt <= max_attempts {
    match validate_module(last) {
      Ok(_) =>
        return Ok({
          wasm_module: last,
          config,
          config_label,
          attempts: attempt,
          facts: gen_valid_feature_facts(last, config.mode),
        })
      Err(err) => last_error_message = validation_error_message(err)
    }
    if attempt < max_attempts {
      last = gen_valid_module_once_with_config(rnd, config)
    }
    attempt += 1
  }
  Err({
    last_candidate: last,
    config,
    config_label,
    attempts: max_attempts,
    validation_error_message: last_error_message,
  })
}

///|
pub fn gen_valid_module_with_config(
  rnd : RandomState,
  config : GenValidConfig,
) -> Module {
  match gen_valid_module_result(rnd, config) {
    Ok(generated) => generated.wasm_module
    Err(failure) => failure.last_candidate
  }
}

///|
pub fn gen_valid_module(rnd : RandomState) -> Module {
  gen_valid_module_with_config(rnd, default_gen_valid_config())
}

///|
fn gen_valid_scan_storage_type(storage : StorageType) -> (Bool, Bool) {
  match storage {
    ValTypeStorageType(vt) => gen_valid_scan_val_type(vt)
    PackTypeStorageType(_) => (false, false)
  }
}

///|
fn gen_valid_scan_field_type(field : FieldType) -> (Bool, Bool) {
  let FieldType(storage, _) = field
  gen_valid_scan_storage_type(storage)
}

///|
fn gen_valid_scan_val_type(vt : ValType) -> (Bool, Bool) {
  match vt {
    VecTypeValType => (false, true)
    RefTypeValType(_) => (true, false)
    _ => (false, false)
  }
}

///|
fn gen_valid_scan_block_type(bt : BlockType) -> (Bool, Bool) {
  match bt {
    ValTypeBlockType(vt) => gen_valid_scan_val_type(vt)
    _ => (false, false)
  }
}

///|
fn gen_valid_scan_comp_type(comp : CompType) -> (Bool, Bool) {
  match comp {
    FuncCompType(params, results) => {
      let mut uses_ref_types = false
      let mut uses_v128 = false
      for vt in params {
        let (has_ref, has_v128) = gen_valid_scan_val_type(vt)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128
      }
      for vt in results {
        let (has_ref, has_v128) = gen_valid_scan_val_type(vt)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128
      }
      (uses_ref_types, uses_v128)
    }
    ArrayCompType(field) => gen_valid_scan_field_type(field)
    StructCompType(fields) => {
      let mut uses_ref_types = false
      let mut uses_v128 = false
      for field in fields {
        let (has_ref, has_v128) = gen_valid_scan_field_type(field)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128
      }
      (uses_ref_types, uses_v128)
    }
  }
}

///|
fn gen_valid_scan_sub_type(subtype : SubType) -> (Bool, Bool) {
  match subtype {
    SubType(_, _, _, comp) | CompTypeSubType(_, comp) =>
      gen_valid_scan_comp_type(comp)
  }
}

///|
fn gen_valid_scan_sub_type_topology(subtype : SubType) -> Bool {
  match subtype {
    SubType(is_final, supers, _, _) => is_final || !supers.is_empty()
    CompTypeSubType(_, _) => false
  }
}

///|
fn gen_valid_scan_rec_type_topology(rec_type : RecType) -> Bool {
  match rec_type {
    SingleRecType(subtype) => gen_valid_scan_sub_type_topology(subtype)
    GroupRecType(group) => {
      if group.length() >= 3 {
        return true
      }
      for subtype in group {
        if gen_valid_scan_sub_type_topology(subtype) {
          return true
        }
      }
      false
    }
  }
}

///|
fn gen_valid_scan_field_plan_rich(fields : Array[FieldType]) -> Bool {
  let mut has_packed = false
  let mut has_ref = false
  let mut has_nonnullable_typed_ref = false
  let mut has_const = false
  let mut has_var = false
  for field in fields {
    let FieldType(storage, mut_) = field
    match mut_ {
      Const => has_const = true
      Var => has_var = true
    }
    match storage {
      PackTypeStorageType(_) => has_packed = true
      ValTypeStorageType(RefTypeValType(HeapTypeRefType(false, _, HeapType(_)))) => {
        has_ref = true
        has_nonnullable_typed_ref = true
      }
      ValTypeStorageType(RefTypeValType(_)) => has_ref = true
      _ => ()
    }
  }
  fields.length() >= 4 &&
  has_packed &&
  has_ref &&
  has_nonnullable_typed_ref &&
  has_const &&
  has_var
}

///|
fn gen_valid_scan_rec_type_rich_gc_field_plan(rec_type : RecType) -> Bool {
  fn scan_subtype(subtype : SubType) -> Bool {
    match subtype {
      SubType(_, _, _, StructCompType(fields))
      | CompTypeSubType(_, StructCompType(fields)) =>
        gen_valid_scan_field_plan_rich(fields) || fields.length() >= 2
      SubType(_, _, _, ArrayCompType(FieldType(PackTypeStorageType(_), _)))
      | CompTypeSubType(_, ArrayCompType(FieldType(PackTypeStorageType(_), _)))
      | SubType(
        _,
        _,
        _,
        ArrayCompType(FieldType(ValTypeStorageType(RefTypeValType(_)), Var))
      )
      | CompTypeSubType(
        _,
        ArrayCompType(FieldType(ValTypeStorageType(RefTypeValType(_)), Var))
      ) => true
      _ => false
    }
  }
  match rec_type {
    SingleRecType(subtype) => scan_subtype(subtype)
    GroupRecType(group) => {
      for subtype in group {
        if scan_subtype(subtype) {
          return true
        }
      }
      false
    }
  }
}

///|
fn gen_valid_scan_rec_type(rec_type : RecType) -> (Bool, Bool) {
  match rec_type {
    SingleRecType(subtype) => gen_valid_scan_sub_type(subtype)
    GroupRecType(group) => {
      let mut uses_ref_types = false
      let mut uses_v128 = false
      for subtype in group {
        let (has_ref, has_v128) = gen_valid_scan_sub_type(subtype)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128
      }
      (uses_ref_types, uses_v128)
    }
  }
}

///|
fn gen_valid_merge_instr_facts(
  left : GenValidInstrFacts,
  right : GenValidInstrFacts,
) -> GenValidInstrFacts {
  {
    uses_ref_types: left.uses_ref_types || right.uses_ref_types,
    uses_v128: left.uses_v128 || right.uses_v128,
    has_call: left.has_call || right.has_call,
    has_call_indirect: left.has_call_indirect || right.has_call_indirect,
    has_numeric_full_ops: left.has_numeric_full_ops ||
    right.has_numeric_full_ops,
    has_br_table: left.has_br_table || right.has_br_table,
    has_payload_control_flow: left.has_payload_control_flow ||
    right.has_payload_control_flow,
    has_multivalue_control_flow: left.has_multivalue_control_flow ||
    right.has_multivalue_control_flow,
    has_standalone_unreachable: left.has_standalone_unreachable ||
    right.has_standalone_unreachable,
    has_local_tee: left.has_local_tee || right.has_local_tee,
    has_typed_select: left.has_typed_select || right.has_typed_select,
    has_tail_calls: left.has_tail_calls || right.has_tail_calls,
    has_scalar_memory_widths: left.has_scalar_memory_widths ||
    right.has_scalar_memory_widths,
    has_nonzero_memarg: left.has_nonzero_memarg || right.has_nonzero_memarg,
    has_memory_limit_variants: left.has_memory_limit_variants ||
    right.has_memory_limit_variants,
    has_basic_ref_instructions: left.has_basic_ref_instructions ||
    right.has_basic_ref_instructions,
    has_i31_extern_conversions: left.has_i31_extern_conversions ||
    right.has_i31_extern_conversions,
    has_simd_phase1: left.has_simd_phase1 || right.has_simd_phase1,
    has_simd_phase2: left.has_simd_phase2 || right.has_simd_phase2,
    has_simd_phase3: left.has_simd_phase3 || right.has_simd_phase3,
    has_atomics: left.has_atomics || right.has_atomics,
    has_gc_constructors: left.has_gc_constructors || right.has_gc_constructors,
    has_gc_accessors: left.has_gc_accessors || right.has_gc_accessors,
    has_string_ops: left.has_string_ops || right.has_string_ops,
    has_exception_try_table_matrix: left.has_exception_try_table_matrix ||
    right.has_exception_try_table_matrix,
    has_subtyping_topology: left.has_subtyping_topology ||
    right.has_subtyping_topology,
    has_rich_gc_field_plans: left.has_rich_gc_field_plans ||
    right.has_rich_gc_field_plans,
    has_shared_memories: left.has_shared_memories || right.has_shared_memories,
    exact_opcode_counts: left.exact_opcode_counts.add(right.exact_opcode_counts),
    control_nodes: left.control_nodes + right.control_nodes,
    branch_ops: left.branch_ops + right.branch_ops,
  }
}

///|
fn gen_valid_block_type_can_produce_values(bt : BlockType) -> Bool {
  match bt {
    VoidBlockType => false
    ValTypeBlockType(_) | TypeIdxBlockType(_) => true
  }
}

///|
fn gen_valid_instr_array_has_top_level_branch(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Br(_) | BrIf(_) | BrTable(_, _) => return true
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_expr_has_top_level_branch(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  gen_valid_instr_array_has_top_level_branch(instrs)
}

///|
fn gen_valid_exact_opcode_counts_for_instr(
  instr : Instruction,
) -> GenValidExactOpcodeCounts {
  let zero = GenValidExactOpcodeCounts::empty()
  match instr {
    I32Const(_) => GenValidExactOpcodeCounts::{ ..zero, i32_const: 1 }
    I64Const(_) => GenValidExactOpcodeCounts::{ ..zero, i64_const: 1 }
    F32Const(_) => GenValidExactOpcodeCounts::{ ..zero, f32_const: 1 }
    F64Const(_) => GenValidExactOpcodeCounts::{ ..zero, f64_const: 1 }
    I32Eqz => GenValidExactOpcodeCounts::{ ..zero, i32_eqz: 1 }
    I64Eqz => GenValidExactOpcodeCounts::{ ..zero, i64_eqz: 1 }
    I32Eq => GenValidExactOpcodeCounts::{ ..zero, i32_eq: 1 }
    I32Ne => GenValidExactOpcodeCounts::{ ..zero, i32_ne: 1 }
    I32LtS => GenValidExactOpcodeCounts::{ ..zero, i32_lt_s: 1 }
    I32LtU => GenValidExactOpcodeCounts::{ ..zero, i32_lt_u: 1 }
    I32GtS => GenValidExactOpcodeCounts::{ ..zero, i32_gt_s: 1 }
    I32GtU => GenValidExactOpcodeCounts::{ ..zero, i32_gt_u: 1 }
    I32LeS => GenValidExactOpcodeCounts::{ ..zero, i32_le_s: 1 }
    I32LeU => GenValidExactOpcodeCounts::{ ..zero, i32_le_u: 1 }
    I32GeS => GenValidExactOpcodeCounts::{ ..zero, i32_ge_s: 1 }
    I32GeU => GenValidExactOpcodeCounts::{ ..zero, i32_ge_u: 1 }
    I64Eq => GenValidExactOpcodeCounts::{ ..zero, i64_eq: 1 }
    I64Ne => GenValidExactOpcodeCounts::{ ..zero, i64_ne: 1 }
    I64LtS => GenValidExactOpcodeCounts::{ ..zero, i64_lt_s: 1 }
    I64LtU => GenValidExactOpcodeCounts::{ ..zero, i64_lt_u: 1 }
    I64GtS => GenValidExactOpcodeCounts::{ ..zero, i64_gt_s: 1 }
    I64GtU => GenValidExactOpcodeCounts::{ ..zero, i64_gt_u: 1 }
    I64LeS => GenValidExactOpcodeCounts::{ ..zero, i64_le_s: 1 }
    I64LeU => GenValidExactOpcodeCounts::{ ..zero, i64_le_u: 1 }
    I64GeS => GenValidExactOpcodeCounts::{ ..zero, i64_ge_s: 1 }
    I64GeU => GenValidExactOpcodeCounts::{ ..zero, i64_ge_u: 1 }
    F32Eq => GenValidExactOpcodeCounts::{ ..zero, f32_eq: 1 }
    F32Ne => GenValidExactOpcodeCounts::{ ..zero, f32_ne: 1 }
    F32Lt => GenValidExactOpcodeCounts::{ ..zero, f32_lt: 1 }
    F32Gt => GenValidExactOpcodeCounts::{ ..zero, f32_gt: 1 }
    F32Le => GenValidExactOpcodeCounts::{ ..zero, f32_le: 1 }
    F32Ge => GenValidExactOpcodeCounts::{ ..zero, f32_ge: 1 }
    F64Eq => GenValidExactOpcodeCounts::{ ..zero, f64_eq: 1 }
    F64Ne => GenValidExactOpcodeCounts::{ ..zero, f64_ne: 1 }
    F64Lt => GenValidExactOpcodeCounts::{ ..zero, f64_lt: 1 }
    F64Gt => GenValidExactOpcodeCounts::{ ..zero, f64_gt: 1 }
    F64Le => GenValidExactOpcodeCounts::{ ..zero, f64_le: 1 }
    F64Ge => GenValidExactOpcodeCounts::{ ..zero, f64_ge: 1 }
    I32Clz => GenValidExactOpcodeCounts::{ ..zero, i32_clz: 1 }
    I32Ctz => GenValidExactOpcodeCounts::{ ..zero, i32_ctz: 1 }
    I32Popcnt => GenValidExactOpcodeCounts::{ ..zero, i32_popcnt: 1 }
    I32Add => GenValidExactOpcodeCounts::{ ..zero, i32_add: 1 }
    I32Sub => GenValidExactOpcodeCounts::{ ..zero, i32_sub: 1 }
    I32Mul => GenValidExactOpcodeCounts::{ ..zero, i32_mul: 1 }
    I32DivS => GenValidExactOpcodeCounts::{ ..zero, i32_div_s: 1 }
    I32DivU => GenValidExactOpcodeCounts::{ ..zero, i32_div_u: 1 }
    I32RemS => GenValidExactOpcodeCounts::{ ..zero, i32_rem_s: 1 }
    I32RemU => GenValidExactOpcodeCounts::{ ..zero, i32_rem_u: 1 }
    I32And => GenValidExactOpcodeCounts::{ ..zero, i32_and: 1 }
    I32Or => GenValidExactOpcodeCounts::{ ..zero, i32_or: 1 }
    I32Xor => GenValidExactOpcodeCounts::{ ..zero, i32_xor: 1 }
    I32Shl => GenValidExactOpcodeCounts::{ ..zero, i32_shl: 1 }
    I32ShrS => GenValidExactOpcodeCounts::{ ..zero, i32_shr_s: 1 }
    I32ShrU => GenValidExactOpcodeCounts::{ ..zero, i32_shr_u: 1 }
    I32Rotl => GenValidExactOpcodeCounts::{ ..zero, i32_rotl: 1 }
    I32Rotr => GenValidExactOpcodeCounts::{ ..zero, i32_rotr: 1 }
    I64Clz => GenValidExactOpcodeCounts::{ ..zero, i64_clz: 1 }
    I64Ctz => GenValidExactOpcodeCounts::{ ..zero, i64_ctz: 1 }
    I64Popcnt => GenValidExactOpcodeCounts::{ ..zero, i64_popcnt: 1 }
    I64Add => GenValidExactOpcodeCounts::{ ..zero, i64_add: 1 }
    I64Sub => GenValidExactOpcodeCounts::{ ..zero, i64_sub: 1 }
    I64Mul => GenValidExactOpcodeCounts::{ ..zero, i64_mul: 1 }
    I64DivS => GenValidExactOpcodeCounts::{ ..zero, i64_div_s: 1 }
    I64DivU => GenValidExactOpcodeCounts::{ ..zero, i64_div_u: 1 }
    I64RemS => GenValidExactOpcodeCounts::{ ..zero, i64_rem_s: 1 }
    I64RemU => GenValidExactOpcodeCounts::{ ..zero, i64_rem_u: 1 }
    I64And => GenValidExactOpcodeCounts::{ ..zero, i64_and: 1 }
    I64Or => GenValidExactOpcodeCounts::{ ..zero, i64_or: 1 }
    I64Xor => GenValidExactOpcodeCounts::{ ..zero, i64_xor: 1 }
    I64Shl => GenValidExactOpcodeCounts::{ ..zero, i64_shl: 1 }
    I64ShrS => GenValidExactOpcodeCounts::{ ..zero, i64_shr_s: 1 }
    I64ShrU => GenValidExactOpcodeCounts::{ ..zero, i64_shr_u: 1 }
    I64Rotl => GenValidExactOpcodeCounts::{ ..zero, i64_rotl: 1 }
    I64Rotr => GenValidExactOpcodeCounts::{ ..zero, i64_rotr: 1 }
    F32Abs => GenValidExactOpcodeCounts::{ ..zero, f32_abs: 1 }
    F32Neg => GenValidExactOpcodeCounts::{ ..zero, f32_neg: 1 }
    F32Ceil => GenValidExactOpcodeCounts::{ ..zero, f32_ceil: 1 }
    F32Floor => GenValidExactOpcodeCounts::{ ..zero, f32_floor: 1 }
    F32Trunc => GenValidExactOpcodeCounts::{ ..zero, f32_trunc: 1 }
    F32Nearest => GenValidExactOpcodeCounts::{ ..zero, f32_nearest: 1 }
    F32Sqrt => GenValidExactOpcodeCounts::{ ..zero, f32_sqrt: 1 }
    F32Add => GenValidExactOpcodeCounts::{ ..zero, f32_add: 1 }
    F32Sub => GenValidExactOpcodeCounts::{ ..zero, f32_sub: 1 }
    F32Mul => GenValidExactOpcodeCounts::{ ..zero, f32_mul: 1 }
    F32Div => GenValidExactOpcodeCounts::{ ..zero, f32_div: 1 }
    F32Min => GenValidExactOpcodeCounts::{ ..zero, f32_min: 1 }
    F32Max => GenValidExactOpcodeCounts::{ ..zero, f32_max: 1 }
    F32Copysign => GenValidExactOpcodeCounts::{ ..zero, f32_copysign: 1 }
    F64Abs => GenValidExactOpcodeCounts::{ ..zero, f64_abs: 1 }
    F64Neg => GenValidExactOpcodeCounts::{ ..zero, f64_neg: 1 }
    F64Ceil => GenValidExactOpcodeCounts::{ ..zero, f64_ceil: 1 }
    F64Floor => GenValidExactOpcodeCounts::{ ..zero, f64_floor: 1 }
    F64Trunc => GenValidExactOpcodeCounts::{ ..zero, f64_trunc: 1 }
    F64Nearest => GenValidExactOpcodeCounts::{ ..zero, f64_nearest: 1 }
    F64Sqrt => GenValidExactOpcodeCounts::{ ..zero, f64_sqrt: 1 }
    F64Add => GenValidExactOpcodeCounts::{ ..zero, f64_add: 1 }
    F64Sub => GenValidExactOpcodeCounts::{ ..zero, f64_sub: 1 }
    F64Mul => GenValidExactOpcodeCounts::{ ..zero, f64_mul: 1 }
    F64Div => GenValidExactOpcodeCounts::{ ..zero, f64_div: 1 }
    F64Min => GenValidExactOpcodeCounts::{ ..zero, f64_min: 1 }
    F64Max => GenValidExactOpcodeCounts::{ ..zero, f64_max: 1 }
    F64Copysign => GenValidExactOpcodeCounts::{ ..zero, f64_copysign: 1 }
    I32WrapI64 => GenValidExactOpcodeCounts::{ ..zero, i32_wrap_i64: 1 }
    I32TruncF32S => GenValidExactOpcodeCounts::{ ..zero, i32_trunc_f32s: 1 }
    I32TruncF32U => GenValidExactOpcodeCounts::{ ..zero, i32_trunc_f32u: 1 }
    I32TruncF64S => GenValidExactOpcodeCounts::{ ..zero, i32_trunc_f64s: 1 }
    I32TruncF64U => GenValidExactOpcodeCounts::{ ..zero, i32_trunc_f64u: 1 }
    I64ExtendI32S => GenValidExactOpcodeCounts::{ ..zero, i64_extend_i32s: 1 }
    I64ExtendI32U => GenValidExactOpcodeCounts::{ ..zero, i64_extend_i32u: 1 }
    I64TruncF32S => GenValidExactOpcodeCounts::{ ..zero, i64_trunc_f32s: 1 }
    I64TruncF32U => GenValidExactOpcodeCounts::{ ..zero, i64_trunc_f32u: 1 }
    I64TruncF64S => GenValidExactOpcodeCounts::{ ..zero, i64_trunc_f64s: 1 }
    I64TruncF64U => GenValidExactOpcodeCounts::{ ..zero, i64_trunc_f64u: 1 }
    F32ConvertI32S => GenValidExactOpcodeCounts::{ ..zero, f32_convert_i32s: 1 }
    F32ConvertI32U => GenValidExactOpcodeCounts::{ ..zero, f32_convert_i32u: 1 }
    F32ConvertI64S => GenValidExactOpcodeCounts::{ ..zero, f32_convert_i64s: 1 }
    F32ConvertI64U => GenValidExactOpcodeCounts::{ ..zero, f32_convert_i64u: 1 }
    F32DemoteF64 => GenValidExactOpcodeCounts::{ ..zero, f32_demote_f64: 1 }
    F64ConvertI32S => GenValidExactOpcodeCounts::{ ..zero, f64_convert_i32s: 1 }
    F64ConvertI32U => GenValidExactOpcodeCounts::{ ..zero, f64_convert_i32u: 1 }
    F64ConvertI64S => GenValidExactOpcodeCounts::{ ..zero, f64_convert_i64s: 1 }
    F64ConvertI64U => GenValidExactOpcodeCounts::{ ..zero, f64_convert_i64u: 1 }
    F64PromoteF32 => GenValidExactOpcodeCounts::{ ..zero, f64_promote_f32: 1 }
    I32Extend8S => GenValidExactOpcodeCounts::{ ..zero, i32_extend8s: 1 }
    I32Extend16S => GenValidExactOpcodeCounts::{ ..zero, i32_extend16s: 1 }
    I64Extend8S => GenValidExactOpcodeCounts::{ ..zero, i64_extend8s: 1 }
    I64Extend16S => GenValidExactOpcodeCounts::{ ..zero, i64_extend16s: 1 }
    I64Extend32S => GenValidExactOpcodeCounts::{ ..zero, i64_extend32s: 1 }
    I32TruncSatF32S =>
      GenValidExactOpcodeCounts::{ ..zero, i32_trunc_sat_f32s: 1 }
    I32TruncSatF32U =>
      GenValidExactOpcodeCounts::{ ..zero, i32_trunc_sat_f32u: 1 }
    I32TruncSatF64S =>
      GenValidExactOpcodeCounts::{ ..zero, i32_trunc_sat_f64s: 1 }
    I32TruncSatF64U =>
      GenValidExactOpcodeCounts::{ ..zero, i32_trunc_sat_f64u: 1 }
    I64TruncSatF32S =>
      GenValidExactOpcodeCounts::{ ..zero, i64_trunc_sat_f32s: 1 }
    I64TruncSatF32U =>
      GenValidExactOpcodeCounts::{ ..zero, i64_trunc_sat_f32u: 1 }
    I64TruncSatF64S =>
      GenValidExactOpcodeCounts::{ ..zero, i64_trunc_sat_f64s: 1 }
    I64TruncSatF64U =>
      GenValidExactOpcodeCounts::{ ..zero, i64_trunc_sat_f64u: 1 }
    I32ReinterpretF32 =>
      GenValidExactOpcodeCounts::{ ..zero, i32_reinterpret_f32: 1 }
    I64ReinterpretF64 =>
      GenValidExactOpcodeCounts::{ ..zero, i64_reinterpret_f64: 1 }
    F32ReinterpretI32 =>
      GenValidExactOpcodeCounts::{ ..zero, f32_reinterpret_i32: 1 }
    F64ReinterpretI64 =>
      GenValidExactOpcodeCounts::{ ..zero, f64_reinterpret_i64: 1 }
    BrTable(_, _) => GenValidExactOpcodeCounts::{ ..zero, br_table: 1 }
    Unreachable => GenValidExactOpcodeCounts::{ ..zero, unreachable_opcode: 1 }
    LocalTee(_) => GenValidExactOpcodeCounts::{ ..zero, local_tee: 1 }
    Select(Some(_)) => GenValidExactOpcodeCounts::{ ..zero, typed_select: 1 }
    ReturnCall(_) => GenValidExactOpcodeCounts::{ ..zero, return_call: 1 }
    ReturnCallIndirect(_, _) =>
      GenValidExactOpcodeCounts::{ ..zero, return_call_indirect: 1 }
    ReturnCallRef(_) =>
      GenValidExactOpcodeCounts::{ ..zero, return_call_ref: 1 }
    V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_const: 1 }
    I8x16Splat => GenValidExactOpcodeCounts::{ ..zero, i8x16_splat: 1 }
    I16x8Splat => GenValidExactOpcodeCounts::{ ..zero, i16x8_splat: 1 }
    I32x4Splat => GenValidExactOpcodeCounts::{ ..zero, i32x4_splat: 1 }
    I64x2Splat => GenValidExactOpcodeCounts::{ ..zero, i64x2_splat: 1 }
    F32x4Splat => GenValidExactOpcodeCounts::{ ..zero, f32x4_splat: 1 }
    F64x2Splat => GenValidExactOpcodeCounts::{ ..zero, f64x2_splat: 1 }
    I8x16ExtractLaneS(_) =>
      GenValidExactOpcodeCounts::{ ..zero, i8x16_extract_lane_s: 1 }
    I8x16ExtractLaneU(_) =>
      GenValidExactOpcodeCounts::{ ..zero, i8x16_extract_lane_u: 1 }
    I8x16ReplaceLane(_) =>
      GenValidExactOpcodeCounts::{ ..zero, i8x16_replace_lane: 1 }
    I16x8ExtractLaneS(_) =>
      GenValidExactOpcodeCounts::{ ..zero, i16x8_extract_lane_s: 1 }
    I16x8ExtractLaneU(_) =>
      GenValidExactOpcodeCounts::{ ..zero, i16x8_extract_lane_u: 1 }
    I16x8ReplaceLane(_) =>
      GenValidExactOpcodeCounts::{ ..zero, i16x8_replace_lane: 1 }
    I32x4ExtractLane(_) =>
      GenValidExactOpcodeCounts::{ ..zero, i32x4_extract_lane: 1 }
    I32x4ReplaceLane(_) =>
      GenValidExactOpcodeCounts::{ ..zero, i32x4_replace_lane: 1 }
    I64x2ExtractLane(_) =>
      GenValidExactOpcodeCounts::{ ..zero, i64x2_extract_lane: 1 }
    I64x2ReplaceLane(_) =>
      GenValidExactOpcodeCounts::{ ..zero, i64x2_replace_lane: 1 }
    F32x4ExtractLane(_) =>
      GenValidExactOpcodeCounts::{ ..zero, f32x4_extract_lane: 1 }
    F32x4ReplaceLane(_) =>
      GenValidExactOpcodeCounts::{ ..zero, f32x4_replace_lane: 1 }
    F64x2ExtractLane(_) =>
      GenValidExactOpcodeCounts::{ ..zero, f64x2_extract_lane: 1 }
    F64x2ReplaceLane(_) =>
      GenValidExactOpcodeCounts::{ ..zero, f64x2_replace_lane: 1 }
    V128Not => GenValidExactOpcodeCounts::{ ..zero, v128_not: 1 }
    V128And => GenValidExactOpcodeCounts::{ ..zero, v128_and: 1 }
    V128Andnot => GenValidExactOpcodeCounts::{ ..zero, v128_andnot: 1 }
    V128Or => GenValidExactOpcodeCounts::{ ..zero, v128_or: 1 }
    V128Xor => GenValidExactOpcodeCounts::{ ..zero, v128_xor: 1 }
    V128Bitselect => GenValidExactOpcodeCounts::{ ..zero, v128_bitselect: 1 }
    V128AnyTrue => GenValidExactOpcodeCounts::{ ..zero, v128_any_true: 1 }
    I8x16Eq => GenValidExactOpcodeCounts::{ ..zero, i8x16_eq: 1 }
    I16x8LtS => GenValidExactOpcodeCounts::{ ..zero, i16x8_lt_s: 1 }
    I32x4GtU => GenValidExactOpcodeCounts::{ ..zero, i32x4_gt_u: 1 }
    F32x4Lt => GenValidExactOpcodeCounts::{ ..zero, f32x4_lt: 1 }
    F64x2Ge => GenValidExactOpcodeCounts::{ ..zero, f64x2_ge: 1 }
    I8x16AllTrue => GenValidExactOpcodeCounts::{ ..zero, i8x16_all_true: 1 }
    I16x8Bitmask => GenValidExactOpcodeCounts::{ ..zero, i16x8_bitmask: 1 }
    I8x16Add => GenValidExactOpcodeCounts::{ ..zero, i8x16_add: 1 }
    I8x16AddSatS => GenValidExactOpcodeCounts::{ ..zero, i8x16_add_sat_s: 1 }
    I16x8Mul => GenValidExactOpcodeCounts::{ ..zero, i16x8_mul: 1 }
    I64x2GeS => GenValidExactOpcodeCounts::{ ..zero, i64x2_ge_s: 1 }
    I32x4AllTrue => GenValidExactOpcodeCounts::{ ..zero, i32x4_all_true: 1 }
    I64x2Bitmask => GenValidExactOpcodeCounts::{ ..zero, i64x2_bitmask: 1 }
    I8x16SubSatU => GenValidExactOpcodeCounts::{ ..zero, i8x16_sub_sat_u: 1 }
    I8x16MinS => GenValidExactOpcodeCounts::{ ..zero, i8x16_min_s: 1 }
    I8x16MaxU => GenValidExactOpcodeCounts::{ ..zero, i8x16_max_u: 1 }
    I8x16AvgrU => GenValidExactOpcodeCounts::{ ..zero, i8x16_avgr_u: 1 }
    I16x8AddSatU => GenValidExactOpcodeCounts::{ ..zero, i16x8_add_sat_u: 1 }
    I16x8SubSatS => GenValidExactOpcodeCounts::{ ..zero, i16x8_sub_sat_s: 1 }
    I16x8MinU => GenValidExactOpcodeCounts::{ ..zero, i16x8_min_u: 1 }
    I16x8MaxS => GenValidExactOpcodeCounts::{ ..zero, i16x8_max_s: 1 }
    I16x8AvgrU => GenValidExactOpcodeCounts::{ ..zero, i16x8_avgr_u: 1 }
    I32x4Add => GenValidExactOpcodeCounts::{ ..zero, i32x4_add: 1 }
    I32x4Mul => GenValidExactOpcodeCounts::{ ..zero, i32x4_mul: 1 }
    I32x4MinS => GenValidExactOpcodeCounts::{ ..zero, i32x4_min_s: 1 }
    I32x4MaxU => GenValidExactOpcodeCounts::{ ..zero, i32x4_max_u: 1 }
    I64x2Add => GenValidExactOpcodeCounts::{ ..zero, i64x2_add: 1 }
    I64x2Mul => GenValidExactOpcodeCounts::{ ..zero, i64x2_mul: 1 }
    F32x4Add => GenValidExactOpcodeCounts::{ ..zero, f32x4_add: 1 }
    F32x4Div => GenValidExactOpcodeCounts::{ ..zero, f32x4_div: 1 }
    F32x4Min => GenValidExactOpcodeCounts::{ ..zero, f32x4_min: 1 }
    F32x4Max => GenValidExactOpcodeCounts::{ ..zero, f32x4_max: 1 }
    F64x2Add => GenValidExactOpcodeCounts::{ ..zero, f64x2_add: 1 }
    F64x2Div => GenValidExactOpcodeCounts::{ ..zero, f64x2_div: 1 }
    F64x2Min => GenValidExactOpcodeCounts::{ ..zero, f64x2_min: 1 }
    F64x2Max => GenValidExactOpcodeCounts::{ ..zero, f64x2_max: 1 }
    F32x4Ceil => GenValidExactOpcodeCounts::{ ..zero, f32x4_ceil: 1 }
    F32x4Floor => GenValidExactOpcodeCounts::{ ..zero, f32x4_floor: 1 }
    F32x4Trunc => GenValidExactOpcodeCounts::{ ..zero, f32x4_trunc: 1 }
    F32x4Nearest => GenValidExactOpcodeCounts::{ ..zero, f32x4_nearest: 1 }
    F64x2Ceil => GenValidExactOpcodeCounts::{ ..zero, f64x2_ceil: 1 }
    F64x2Floor => GenValidExactOpcodeCounts::{ ..zero, f64x2_floor: 1 }
    F64x2Trunc => GenValidExactOpcodeCounts::{ ..zero, f64x2_trunc: 1 }
    F64x2Nearest => GenValidExactOpcodeCounts::{ ..zero, f64x2_nearest: 1 }
    V128Load8x8S(_) => GenValidExactOpcodeCounts::{ ..zero, v128_load8x8_s: 1 }
    V128Load8x8U(_) => GenValidExactOpcodeCounts::{ ..zero, v128_load8x8_u: 1 }
    V128Load16x4S(_) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load16x4_s: 1 }
    V128Load16x4U(_) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load16x4_u: 1 }
    V128Load32x2S(_) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load32x2_s: 1 }
    V128Load32x2U(_) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load32x2_u: 1 }
    V128Load8Splat(_) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load8_splat: 1 }
    V128Load16Splat(_) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load16_splat: 1 }
    V128Load32Splat(_) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load32_splat: 1 }
    V128Load64Splat(_) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load64_splat: 1 }
    V128Load8Lane(_, _) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load8_lane: 1 }
    V128Load16Lane(_, _) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load16_lane: 1 }
    V128Load32Lane(_, _) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load32_lane: 1 }
    V128Load64Lane(_, _) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load64_lane: 1 }
    V128Store8Lane(_, _) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_store8_lane: 1 }
    V128Store16Lane(_, _) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_store16_lane: 1 }
    V128Store32Lane(_, _) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_store32_lane: 1 }
    V128Store64Lane(_, _) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_store64_lane: 1 }
    V128Load32Zero(_) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load32_zero: 1 }
    V128Load64Zero(_) =>
      GenValidExactOpcodeCounts::{ ..zero, v128_load64_zero: 1 }
    I8x16NarrowI16x8U =>
      GenValidExactOpcodeCounts::{ ..zero, i8x16_narrow_i16x8_u: 1 }
    I16x8NarrowI32x4S =>
      GenValidExactOpcodeCounts::{ ..zero, i16x8_narrow_i32x4_s: 1 }
    I16x8NarrowI32x4U =>
      GenValidExactOpcodeCounts::{ ..zero, i16x8_narrow_i32x4_u: 1 }
    I16x8ExtaddPairwiseI8x16S =>
      GenValidExactOpcodeCounts::{ ..zero, i16x8_extadd_pairwise_i8x16_s: 1 }
    I16x8ExtaddPairwiseI8x16U =>
      GenValidExactOpcodeCounts::{ ..zero, i16x8_extadd_pairwise_i8x16_u: 1 }
    I32x4ExtaddPairwiseI16x8S =>
      GenValidExactOpcodeCounts::{ ..zero, i32x4_extadd_pairwise_i16x8_s: 1 }
    I32x4ExtaddPairwiseI16x8U =>
      GenValidExactOpcodeCounts::{ ..zero, i32x4_extadd_pairwise_i16x8_u: 1 }
    F64x2PromoteLowF32x4 =>
      GenValidExactOpcodeCounts::{ ..zero, f64x2_promote_low_f32x4: 1 }
    V128Load(_) => GenValidExactOpcodeCounts::{ ..zero, v128_load: 1 }
    V128Store(_) => GenValidExactOpcodeCounts::{ ..zero, v128_store: 1 }
    I8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      GenValidExactOpcodeCounts::{ ..zero, i8x16_shuffle: 1 }
    I8x16Swizzle => GenValidExactOpcodeCounts::{ ..zero, i8x16_swizzle: 1 }
    I8x16NarrowI16x8S =>
      GenValidExactOpcodeCounts::{ ..zero, i8x16_narrow_i16x8_s: 1 }
    I32x4DotI16x8S =>
      GenValidExactOpcodeCounts::{ ..zero, i32x4_dot_i16x8_s: 1 }
    F32x4DemoteF64x2Zero =>
      GenValidExactOpcodeCounts::{ ..zero, f32x4_demote_f64x2_zero: 1 }
    I8x16RelaxedSwizzle =>
      GenValidExactOpcodeCounts::{ ..zero, i8x16_relaxed_swizzle: 1 }
    I32x4RelaxedTruncF32x4S =>
      GenValidExactOpcodeCounts::{ ..zero, i32x4_relaxed_trunc_f32x4_s: 1 }
    I32x4RelaxedTruncF32x4U =>
      GenValidExactOpcodeCounts::{ ..zero, i32x4_relaxed_trunc_f32x4_u: 1 }
    I32x4RelaxedTruncZeroF64x2S =>
      GenValidExactOpcodeCounts::{ ..zero, i32x4_relaxed_trunc_zero_f64x2_s: 1 }
    I32x4RelaxedTruncZeroF64x2U =>
      GenValidExactOpcodeCounts::{ ..zero, i32x4_relaxed_trunc_zero_f64x2_u: 1 }
    F32x4RelaxedMadd =>
      GenValidExactOpcodeCounts::{ ..zero, f32x4_relaxed_madd: 1 }
    F32x4RelaxedNmadd =>
      GenValidExactOpcodeCounts::{ ..zero, f32x4_relaxed_nmadd: 1 }
    F64x2RelaxedMadd =>
      GenValidExactOpcodeCounts::{ ..zero, f64x2_relaxed_madd: 1 }
    F64x2RelaxedNmadd =>
      GenValidExactOpcodeCounts::{ ..zero, f64x2_relaxed_nmadd: 1 }
    I8x16RelaxedLaneselect =>
      GenValidExactOpcodeCounts::{ ..zero, i8x16_relaxed_laneselect: 1 }
    I16x8RelaxedLaneselect =>
      GenValidExactOpcodeCounts::{ ..zero, i16x8_relaxed_laneselect: 1 }
    I32x4RelaxedLaneselect =>
      GenValidExactOpcodeCounts::{ ..zero, i32x4_relaxed_laneselect: 1 }
    I64x2RelaxedLaneselect =>
      GenValidExactOpcodeCounts::{ ..zero, i64x2_relaxed_laneselect: 1 }
    F32x4RelaxedMin =>
      GenValidExactOpcodeCounts::{ ..zero, f32x4_relaxed_min: 1 }
    F32x4RelaxedMax =>
      GenValidExactOpcodeCounts::{ ..zero, f32x4_relaxed_max: 1 }
    F64x2RelaxedMin =>
      GenValidExactOpcodeCounts::{ ..zero, f64x2_relaxed_min: 1 }
    F64x2RelaxedMax =>
      GenValidExactOpcodeCounts::{ ..zero, f64x2_relaxed_max: 1 }
    I16x8RelaxedQ15mulrS =>
      GenValidExactOpcodeCounts::{ ..zero, i16x8_relaxed_q15mulr_s: 1 }
    I16x8RelaxedDotI8x16I7x16S =>
      GenValidExactOpcodeCounts::{ ..zero, i16x8_relaxed_dot_i8x16_i7x16_s: 1 }
    I32x4RelaxedDotI8x16I7x16AddS =>
      GenValidExactOpcodeCounts::{
        ..zero,
        i32x4_relaxed_dot_i8x16_i7x16_add_s: 1,
      }
    _ => zero
  }
}

///|
fn gen_valid_scan_expr(expr : Expr) -> GenValidInstrFacts {
  let Expr(instrs) = expr
  let mut facts = GenValidInstrFacts::empty()
  for instr in instrs {
    facts = gen_valid_merge_instr_facts(facts, gen_valid_scan_instr(instr))
  }
  facts
}

///|
fn gen_valid_instr_is_simd_phase1(instr : Instruction) -> Bool {
  match instr {
    V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | I8x16Splat
    | I16x8Splat
    | I32x4Splat
    | I64x2Splat
    | F32x4Splat
    | F64x2Splat
    | I8x16ExtractLaneS(_)
    | I8x16ExtractLaneU(_)
    | I8x16ReplaceLane(_)
    | I16x8ExtractLaneS(_)
    | I16x8ExtractLaneU(_)
    | I16x8ReplaceLane(_)
    | I32x4ExtractLane(_)
    | I32x4ReplaceLane(_)
    | I64x2ExtractLane(_)
    | I64x2ReplaceLane(_)
    | F32x4ExtractLane(_)
    | F32x4ReplaceLane(_)
    | F64x2ExtractLane(_)
    | F64x2ReplaceLane(_)
    | V128Not
    | V128And
    | V128Andnot
    | V128Or
    | V128Xor
    | V128Bitselect
    | V128AnyTrue => true
    _ => false
  }
}

///|
fn gen_valid_instr_is_simd_phase2(instr : Instruction) -> Bool {
  match instr {
    I8x16Eq
    | I16x8LtS
    | I32x4GtU
    | I64x2GeS
    | F32x4Lt
    | F64x2Ge
    | I8x16AllTrue
    | I16x8Bitmask
    | I32x4AllTrue
    | I64x2Bitmask
    | I8x16Add
    | I8x16AddSatS
    | I8x16SubSatU
    | I8x16MinS
    | I8x16MaxU
    | I8x16AvgrU
    | I16x8Mul
    | I16x8AddSatU
    | I16x8SubSatS
    | I16x8MinU
    | I16x8MaxS
    | I16x8AvgrU
    | I32x4Add
    | I32x4Mul
    | I32x4MinS
    | I32x4MaxU
    | I64x2Add
    | I64x2Mul
    | F32x4Add
    | F32x4Div
    | F32x4Min
    | F32x4Max
    | F64x2Add
    | F64x2Div
    | F64x2Min
    | F64x2Max
    | F32x4Ceil
    | F32x4Floor
    | F32x4Trunc
    | F32x4Nearest
    | F64x2Ceil
    | F64x2Floor
    | F64x2Trunc
    | F64x2Nearest => true
    _ => false
  }
}

///|
fn gen_valid_instr_is_expanded_scalar_numeric(instr : Instruction) -> Bool {
  match instr {
    I32Eqz
    | I32Eq
    | I32Ne
    | I32LtS
    | I32LtU
    | I32GtS
    | I32GtU
    | I32LeS
    | I32LeU
    | I32GeS
    | I32GeU
    | I64Eqz
    | I64Eq
    | I64Ne
    | I64LtS
    | I64LtU
    | I64GtS
    | I64GtU
    | I64LeS
    | I64LeU
    | I64GeS
    | I64GeU
    | F32Eq
    | F32Ne
    | F32Lt
    | F32Gt
    | F32Le
    | F32Ge
    | F64Eq
    | F64Ne
    | F64Lt
    | F64Gt
    | F64Le
    | F64Ge
    | I32DivS
    | I32DivU
    | I32RemS
    | I32RemU
    | I32Shl
    | I32ShrS
    | I32ShrU
    | I32Rotl
    | I32Rotr
    | I64DivS
    | I64DivU
    | I64RemS
    | I64RemU
    | I64Shl
    | I64ShrS
    | I64ShrU
    | I64Rotl
    | I64Rotr
    | F32Ceil
    | F32Floor
    | F32Trunc
    | F32Nearest
    | F32Sqrt
    | F32Min
    | F32Max
    | F32Copysign
    | F64Ceil
    | F64Floor
    | F64Trunc
    | F64Nearest
    | F64Sqrt
    | F64Min
    | F64Max
    | F64Copysign
    | I32TruncF32U
    | I32TruncF64U
    | I64ExtendI32U
    | I64TruncF32U
    | I64TruncF64U
    | F32ConvertI32U
    | F32ConvertI64U
    | F64ConvertI32U
    | F64ConvertI64U
    | I32Extend8S
    | I32Extend16S
    | I64Extend8S
    | I64Extend16S
    | I64Extend32S
    | I32TruncSatF32S
    | I32TruncSatF32U
    | I32TruncSatF64S
    | I32TruncSatF64U
    | I64TruncSatF32S
    | I64TruncSatF32U
    | I64TruncSatF64S
    | I64TruncSatF64U => true
    _ => false
  }
}

///|
fn gen_valid_instr_is_simd_phase3(instr : Instruction) -> Bool {
  match instr {
    V128Load(_)
    | V128Load8x8S(_)
    | V128Load8x8U(_)
    | V128Load16x4S(_)
    | V128Load16x4U(_)
    | V128Load32x2S(_)
    | V128Load32x2U(_)
    | V128Load8Splat(_)
    | V128Load16Splat(_)
    | V128Load32Splat(_)
    | V128Load64Splat(_)
    | V128Store(_)
    | V128Load8Lane(_, _)
    | V128Load16Lane(_, _)
    | V128Load32Lane(_, _)
    | V128Load64Lane(_, _)
    | V128Store8Lane(_, _)
    | V128Store16Lane(_, _)
    | V128Store32Lane(_, _)
    | V128Store64Lane(_, _)
    | V128Load32Zero(_)
    | V128Load64Zero(_)
    | I8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | I8x16Swizzle
    | I8x16NarrowI16x8S
    | I8x16NarrowI16x8U
    | I16x8NarrowI32x4S
    | I16x8NarrowI32x4U
    | I16x8ExtaddPairwiseI8x16S
    | I16x8ExtaddPairwiseI8x16U
    | I32x4ExtaddPairwiseI16x8S
    | I32x4ExtaddPairwiseI16x8U
    | I32x4DotI16x8S
    | F32x4DemoteF64x2Zero
    | F64x2PromoteLowF32x4 => true
    _ => false
  }
}

///|
fn gen_valid_instr_is_atomic(instr : Instruction) -> Bool {
  match instr {
    MemoryAtomicNotify(_)
    | MemoryAtomicWait32(_)
    | MemoryAtomicWait64(_)
    | AtomicFence
    | I32AtomicLoad(_)
    | I64AtomicLoad(_)
    | I32AtomicLoad8U(_)
    | I32AtomicLoad16U(_)
    | I64AtomicLoad8U(_)
    | I64AtomicLoad16U(_)
    | I64AtomicLoad32U(_)
    | I32AtomicStore(_)
    | I64AtomicStore(_)
    | I32AtomicStore8(_)
    | I32AtomicStore16(_)
    | I64AtomicStore8(_)
    | I64AtomicStore16(_)
    | I64AtomicStore32(_)
    | AtomicRmw(_, _)
    | AtomicCmpxchg(_, _) => true
    _ => false
  }
}

///|
fn gen_valid_memarg_is_nonzero(ma : MemArg) -> Bool {
  let MemArg(U32(align_pow), _, U64(offset)) = ma
  align_pow.reinterpret_as_int() > 0 || offset > 0
}

///|
fn gen_valid_scan_scalar_memory_instr(
  ma : MemArg,
  narrow : Bool,
) -> GenValidInstrFacts {
  GenValidInstrFacts::{
    ..GenValidInstrFacts::empty(),
    has_scalar_memory_widths: narrow,
    has_nonzero_memarg: gen_valid_memarg_is_nonzero(ma),
  }
}

///|
fn gen_valid_mem_type_has_limit_variant(mt : MemType) -> Bool {
  let MemType(lim, shared) = mt
  match lim {
    I32Limits(min, max) => min == 0 || max is None || shared
    I64Limits(_) => true
  }
}

///|
fn gen_valid_mem_type_is_shared(mt : MemType) -> Bool {
  let MemType(_, shared) = mt
  shared
}

///|
fn gen_valid_table_type_has_limit_variant(
  table_type : TableType,
  init_opt : Expr?,
) -> Bool {
  let TableType(rt, lim) = table_type
  let limit_variant = match lim {
    I32Limits(min, max) => min == 0 || max is None
    I64Limits(min, max) => min == 0UL || max is None
  }
  limit_variant ||
  ValType::ref_type(rt) != ValType::funcref() ||
  init_opt is Some(_)
}

///|
fn gen_valid_const_expr_has_variant(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      GlobalGet(_)
      | RefFunc(_)
      | StructNew(_)
      | StructNewDefault(_)
      | StructNewDesc(_)
      | StructNewDefaultDesc(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_instr_is_gc_constructor(instr : Instruction) -> Bool {
  match instr {
    StructNew(_)
    | StructNewDefault(_)
    | StructNewDesc(_)
    | StructNewDefaultDesc(_)
    | ArrayNew(_)
    | ArrayNewDefault(_)
    | ArrayNewFixed(_, _)
    | ArrayNewData(_, _)
    | ArrayNewElem(_, _) => true
    _ => false
  }
}

///|
fn gen_valid_instr_is_gc_accessor(instr : Instruction) -> Bool {
  match instr {
    StructGet(_, _)
    | StructGetS(_, _)
    | StructGetU(_, _)
    | StructSet(_, _)
    | ArrayGet(_)
    | ArrayGetS(_)
    | ArrayGetU(_)
    | ArraySet(_)
    | ArrayLen
    | ArrayFill(_)
    | ArrayCopy(_, _)
    | ArrayInitData(_, _)
    | ArrayInitElem(_, _) => true
    _ => false
  }
}

///|
fn gen_valid_instr_is_basic_ref_instruction(instr : Instruction) -> Bool {
  match instr {
    RefNull(rt) =>
      match rt.get_heap_type() {
        AbsHeapTypeHeapType(NoneAbsHeapType)
        | AbsHeapTypeHeapType(NoFuncAbsHeapType)
        | AbsHeapTypeHeapType(NoExternAbsHeapType) => true
        _ => false
      }
    RefIsNull
    | RefTest(_, _)
    | RefCast(_, _)
    | BrOnCast(_, _, _, _)
    | BrOnCastFail(_, _, _, _) => true
    _ => false
  }
}

///|
fn gen_valid_scan_instr(instr : Instruction) -> GenValidInstrFacts {
  let exact_opcode_counts = gen_valid_exact_opcode_counts_for_instr(instr)
  if gen_valid_exact_opcode_counts_nonzero(exact_opcode_counts) {
    return GenValidInstrFacts::{
      ..GenValidInstrFacts::empty(),
      has_numeric_full_ops: gen_valid_instr_is_expanded_scalar_numeric(instr),
      has_br_table: instr is BrTable(_, _),
      has_standalone_unreachable: instr is Unreachable,
      has_local_tee: instr is LocalTee(_),
      has_typed_select: instr is Select(Some(_)),
      has_tail_calls: match instr {
        ReturnCall(_) | ReturnCallIndirect(_, _) | ReturnCallRef(_) => true
        _ => false
      },
      uses_v128: gen_valid_instr_is_simd_phase1(instr) ||
      gen_valid_instr_is_simd_phase2(instr) ||
      gen_valid_instr_is_simd_phase3(instr),
      has_simd_phase1: gen_valid_instr_is_simd_phase1(instr),
      has_simd_phase2: gen_valid_instr_is_simd_phase2(instr),
      has_simd_phase3: gen_valid_instr_is_simd_phase3(instr),
      exact_opcode_counts,
    }
  }
  if gen_valid_instr_is_simd_phase1(instr) {
    return GenValidInstrFacts::{
      ..GenValidInstrFacts::empty(),
      uses_v128: true,
      has_simd_phase1: true,
    }
  }
  if gen_valid_instr_is_simd_phase2(instr) {
    return GenValidInstrFacts::{
      ..GenValidInstrFacts::empty(),
      uses_v128: true,
      has_simd_phase2: true,
    }
  }
  if gen_valid_instr_is_simd_phase3(instr) {
    return GenValidInstrFacts::{
      ..GenValidInstrFacts::empty(),
      uses_v128: true,
      has_simd_phase3: true,
    }
  }
  if gen_valid_instr_is_atomic(instr) {
    return GenValidInstrFacts::{
      ..GenValidInstrFacts::empty(),
      has_atomics: true,
    }
  }
  if gen_valid_instr_is_expanded_scalar_numeric(instr) {
    return GenValidInstrFacts::{
      ..GenValidInstrFacts::empty(),
      has_numeric_full_ops: true,
    }
  }
  if gen_valid_instr_is_gc_constructor(instr) {
    return GenValidInstrFacts::{
      ..GenValidInstrFacts::empty(),
      uses_ref_types: true,
      has_gc_constructors: true,
    }
  }
  if gen_valid_instr_is_gc_accessor(instr) {
    return GenValidInstrFacts::{
      ..GenValidInstrFacts::empty(),
      uses_ref_types: true,
      has_gc_accessors: true,
    }
  }
  match instr {
    Call(_) =>
      GenValidInstrFacts::{ ..GenValidInstrFacts::empty(), has_call: true }
    ReturnCall(_) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        has_call: true,
        has_tail_calls: true,
        branch_ops: 1,
      }
    CallIndirect(_, _) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        has_call_indirect: true,
        branch_ops: 1,
      }
    ReturnCallIndirect(_, _) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        has_call_indirect: true,
        has_tail_calls: true,
        branch_ops: 1,
      }
    CallRef(_) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
        has_call_indirect: true,
        branch_ops: 1,
      }
    ReturnCallRef(_) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
        has_call_indirect: true,
        has_tail_calls: true,
        branch_ops: 1,
      }
    Br(_) | BrIf(_) =>
      GenValidInstrFacts::{ ..GenValidInstrFacts::empty(), branch_ops: 1 }
    BrTable(_, _) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        has_br_table: true,
        branch_ops: 1,
      }
    I32Load(ma)
    | I64Load(ma)
    | F32Load(ma)
    | F64Load(ma)
    | I32Store(ma)
    | I64Store(ma)
    | F32Store(ma)
    | F64Store(ma) => gen_valid_scan_scalar_memory_instr(ma, false)
    I32Load8S(ma)
    | I32Load8U(ma)
    | I32Load16S(ma)
    | I32Load16U(ma)
    | I64Load8S(ma)
    | I64Load8U(ma)
    | I64Load16S(ma)
    | I64Load16U(ma)
    | I64Load32S(ma)
    | I64Load32U(ma)
    | I32Store8(ma)
    | I32Store16(ma)
    | I64Store8(ma)
    | I64Store16(ma)
    | I64Store32(ma) => gen_valid_scan_scalar_memory_instr(ma, true)
    BrOnNull(_) | BrOnNonNull(_) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
        branch_ops: 1,
      }
    BrOnCast(_, _, _, _) | BrOnCastFail(_, _, _, _) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
        has_basic_ref_instructions: true,
        branch_ops: 1,
      }
    Block(bt, body) | Loop(bt, body) => {
      let (has_ref, has_v128) = gen_valid_scan_block_type(bt)
      let body_facts = gen_valid_scan_expr(body)
      GenValidInstrFacts::{
        ..body_facts,
        uses_ref_types: body_facts.uses_ref_types || has_ref,
        uses_v128: body_facts.uses_v128 || has_v128,
        has_payload_control_flow: body_facts.has_payload_control_flow ||
        (
          gen_valid_block_type_can_produce_values(bt) &&
          gen_valid_expr_has_top_level_branch(body)
        ),
        has_multivalue_control_flow: body_facts.has_multivalue_control_flow,
        control_nodes: body_facts.control_nodes + 1,
      }
    }
    If(bt, then_body, else_body) => {
      let (has_ref, has_v128) = gen_valid_scan_block_type(bt)
      let mut facts = GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: has_ref,
        uses_v128: has_v128,
        has_payload_control_flow: false,
        has_multivalue_control_flow: false,
        control_nodes: 1,
        branch_ops: 1,
      }
      facts = gen_valid_merge_instr_facts(
        facts,
        gen_valid_scan_expr(Expr::new(then_body)),
      )
      match else_body {
        Some(branch) =>
          facts = gen_valid_merge_instr_facts(
            facts,
            gen_valid_scan_expr(Expr::new(branch)),
          )
        None => ()
      }
      let else_has_top_level_branch = match else_body {
        Some(body) => gen_valid_instr_array_has_top_level_branch(body)
        None => false
      }
      if gen_valid_block_type_can_produce_values(bt) &&
        (
          gen_valid_instr_array_has_top_level_branch(then_body) ||
          else_has_top_level_branch
        ) {
        facts = GenValidInstrFacts::{ ..facts, has_payload_control_flow: true }
      }
      facts
    }
    TryTable(bt, catches, body) => {
      let (has_ref, has_v128) = gen_valid_scan_block_type(bt)
      let body_facts = gen_valid_scan_expr(body)
      GenValidInstrFacts::{
        ..body_facts,
        uses_ref_types: body_facts.uses_ref_types || has_ref,
        uses_v128: body_facts.uses_v128 || has_v128,
        has_payload_control_flow: body_facts.has_payload_control_flow ||
        (
          gen_valid_block_type_can_produce_values(bt) &&
          gen_valid_expr_has_top_level_branch(body)
        ),
        has_multivalue_control_flow: body_facts.has_multivalue_control_flow,
        has_exception_try_table_matrix: body_facts.has_exception_try_table_matrix ||
        gen_valid_try_table_has_exception_matrix(catches),
        control_nodes: body_facts.control_nodes + 1,
        branch_ops: body_facts.branch_ops + 1,
      }
    }
    Select(Some(types)) => {
      let mut uses_ref_types = false
      let mut uses_v128 = false
      for vt in types {
        let (has_ref, has_v128) = gen_valid_scan_val_type(vt)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128
      }
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types,
        uses_v128,
        has_typed_select: true,
      }
    }
    RefNull(_) | RefIsNull | RefTest(_, _) | RefCast(_, _) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
        has_basic_ref_instructions: gen_valid_instr_is_basic_ref_instruction(
          instr,
        ),
      }
    RefI31 | I31GetS | I31GetU | AnyConvertExtern | ExternConvertAny =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
        has_i31_extern_conversions: true,
      }
    StringConst(_)
    | StringNewUtf8Array
    | StringNewWtf16Array
    | StringEncodeUtf8Array
    | StringEncodeWtf16Array
    | StringNewLossyUtf8Array
    | StringNewWtf8Array
    | StringEncodeLossyUtf8Array
    | StringEncodeWtf8Array =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
        has_string_ops: true,
      }
    RefFunc(_)
    | ThrowRef
    | RefGetDesc(_)
    | RefTestDesc(_, _)
    | RefCastDescEq(_, _) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
      }
    Throw(_) =>
      GenValidInstrFacts::{ ..GenValidInstrFacts::empty(), branch_ops: 1 }
    Unreachable =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        has_standalone_unreachable: true,
      }
    LocalTee(_) =>
      GenValidInstrFacts::{ ..GenValidInstrFacts::empty(), has_local_tee: true }
    _ => GenValidInstrFacts::empty()
  }
}

///|
fn gen_valid_module_typeidx_has_multiple_results(
  mod : Module,
  wanted : TypeIdx,
) -> Bool {
  match mod.type_sec {
    Some(TypeSec(rec_types)) => {
      let mut cursor = 0U
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(sub_type) => {
            match sub_type {
              CompTypeSubType(_, FuncCompType(_, results)) if TypeIdx::new(
                  cursor,
                ) ==
                wanted => return results.length() > 1
              _ => ()
            }
            cursor += 1
          }
          GroupRecType(group) =>
            for sub_type in group {
              match sub_type {
                CompTypeSubType(_, FuncCompType(_, results)) if TypeIdx::new(
                    cursor,
                  ) ==
                  wanted => return results.length() > 1
                _ => ()
              }
              cursor += 1
            }
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_expr_has_multivalue_control_flow(
  mod : Module,
  expr : Expr,
) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      Block(TypeIdxBlockType(type_idx), body)
      | Loop(TypeIdxBlockType(type_idx), body)
      | TryTable(TypeIdxBlockType(type_idx), _, body) => {
        if gen_valid_module_typeidx_has_multiple_results(mod, type_idx) {
          return true
        }
        if gen_valid_expr_has_multivalue_control_flow(mod, body) {
          return true
        }
      }
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_expr_has_multivalue_control_flow(mod, body) {
          return true
        }
      If(TypeIdxBlockType(type_idx), then_body, else_body) => {
        if gen_valid_module_typeidx_has_multiple_results(mod, type_idx) {
          return true
        }
        if gen_valid_expr_has_multivalue_control_flow(mod, Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_expr_has_multivalue_control_flow(
              mod,
              Expr::new(body),
            ) => return true
          _ => ()
        }
      }
      If(_, then_body, else_body) => {
        if gen_valid_expr_has_multivalue_control_flow(mod, Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_expr_has_multivalue_control_flow(
              mod,
              Expr::new(body),
            ) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_template_signature_push(
  seen : Array[String],
  label : String,
) -> Unit {
  if label.length() > 0 {
    seen.push(label)
  }
}

///|
fn gen_valid_instr_template_signature_label(instr : Instruction) -> String {
  if gen_valid_instr_is_expanded_scalar_numeric(instr) {
    return "numeric"
  }
  if gen_valid_instr_is_gc_constructor(instr) ||
    gen_valid_instr_is_gc_accessor(instr) {
    return "gc"
  }
  if gen_valid_instr_is_simd_phase1(instr) {
    return "simd1"
  }
  if gen_valid_instr_is_simd_phase2(instr) {
    return "simd2"
  }
  if gen_valid_instr_is_simd_phase3(instr) {
    return "simd3"
  }
  if gen_valid_instr_is_atomic(instr) {
    return "atomic"
  }
  match instr {
    Block(_, _) => "block"
    Loop(_, _) => "loop"
    If(_, _, _) => "if"
    TryTable(_, _, _) => "try_table"
    Br(_) | BrIf(_) | BrTable(_, _) => "branch"
    Call(_) => "direct_call"
    CallIndirect(_, _) => "call_indirect"
    CallRef(_) => "call_ref"
    ReturnCall(_) | ReturnCallIndirect(_, _) | ReturnCallRef(_) => "tail_call"
    RefI31 | I31GetS | I31GetU | AnyConvertExtern | ExternConvertAny => "i31"
    RefNull(_)
    | RefIsNull
    | RefFunc(_)
    | RefTest(_, _)
    | RefCast(_, _)
    | BrOnCast(_, _, _, _)
    | BrOnCastFail(_, _, _, _) => "ref"
    MemorySize(_)
    | MemoryGrow(_)
    | MemoryInit(_, _)
    | DataDrop(_)
    | MemoryCopy(_, _)
    | MemoryFill(_)
    | I32Load(_)
    | I64Load(_)
    | F32Load(_)
    | F64Load(_)
    | I32Store(_)
    | I64Store(_)
    | F32Store(_)
    | F64Store(_)
    | I32Load8S(_)
    | I32Load8U(_)
    | I32Load16S(_)
    | I32Load16U(_)
    | I64Load8S(_)
    | I64Load8U(_)
    | I64Load16S(_)
    | I64Load16U(_)
    | I64Load32S(_)
    | I64Load32U(_)
    | I32Store8(_)
    | I32Store16(_)
    | I64Store8(_)
    | I64Store16(_)
    | I64Store32(_) => "memory"
    TableSize(_)
    | TableGet(_)
    | TableSet(_)
    | TableGrow(_)
    | TableFill(_)
    | TableCopy(_, _)
    | TableInit(_, _)
    | ElemDrop(_) => "table"
    GlobalGet(_) | GlobalSet(_) => "global"
    _ => ""
  }
}

///|
fn gen_valid_collect_template_signature_instr(
  seen : Array[String],
  instr : Instruction,
) -> Unit {
  gen_valid_template_signature_push(
    seen,
    gen_valid_instr_template_signature_label(instr),
  )
  match instr {
    Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
      gen_valid_collect_template_signature_expr(seen, body)
    If(_, then_body, else_body) => {
      gen_valid_collect_template_signature_instrs(seen, then_body)
      match else_body {
        Some(body) => gen_valid_collect_template_signature_instrs(seen, body)
        None => ()
      }
    }
    _ => ()
  }
}

///|
fn gen_valid_collect_template_signature_instrs(
  seen : Array[String],
  instrs : Array[Instruction],
) -> Unit {
  for instr in instrs {
    gen_valid_collect_template_signature_instr(seen, instr)
  }
}

///|
fn gen_valid_collect_template_signature_expr(
  seen : Array[String],
  expr : Expr,
) -> Unit {
  let Expr(instrs) = expr
  gen_valid_collect_template_signature_instrs(seen, instrs)
}

///|
fn gen_valid_join_template_signature(seen : Array[String]) -> String {
  let out = StringBuilder::new()
  let mut first = true
  for label in seen {
    if first {
      first = false
    } else {
      out.write_string("|")
    }
    out.write_string(label)
  }
  out.to_string()
}

///|
pub fn gen_valid_coverage_template_signature(mod : Module) -> String {
  let seen : Array[String] = []
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, expr) = func
        gen_valid_collect_template_signature_expr(seen, expr)
      }
    None => ()
  }
  gen_valid_join_template_signature(seen)
}

///|
pub fn gen_valid_feature_facts(
  mod : Module,
  mode : GenValidMode,
) -> GenValidFeatureFacts {
  let mut has_imports = false
  let mut has_func_exports = false
  let mut has_table_exports = false
  let mut has_mem_exports = false
  let mut has_global_exports = false
  let mut has_tag_exports = false
  let mut has_tables = false
  let mut has_mems = false
  let mut has_globals = false
  let mut has_tags = false
  let mut has_elems = false
  let mut has_datas = false
  let has_start = mod.start_sec is Some(_)
  let has_data_count = mod.data_cnt_sec is Some(_)
  let mut uses_ref_types = false
  let mut uses_v128 = false
  let mut has_call = false
  let mut has_call_indirect = false
  let mut has_numeric_full_ops = false
  let mut has_br_table = false
  let mut has_payload_control_flow = false
  let mut has_multivalue_control_flow = false
  let mut has_standalone_unreachable = false
  let mut has_local_tee = false
  let mut has_typed_select = false
  let mut has_tail_calls = false
  let mut has_scalar_memory_widths = false
  let mut has_nonzero_memarg = false
  let mut has_memory_limit_variants = false
  let mut has_table_limit_variants = false
  let mut has_const_expr_variants = false
  let mut has_basic_ref_instructions = false
  let mut has_i31_extern_conversions = false
  let mut has_simd_phase1 = false
  let mut has_simd_phase2 = false
  let mut has_simd_phase3 = false
  let mut has_atomics = false
  let mut has_gc_constructors = false
  let mut has_gc_accessors = false
  let mut has_string_ops = false
  let mut has_exception_try_table_matrix = false
  let mut has_subtyping_topology = false
  let mut has_rich_gc_field_plans = false
  let mut has_import_export_topology = false
  let mut has_element_segment_range = false
  let mut has_data_segment_range = false
  let mut has_name_custom_sections = false
  let mut has_shared_memories = false
  let mut exact_opcode_counts = GenValidExactOpcodeCounts::empty()
  let mut control_nodes = 0
  let mut branch_ops = 0

  for custom in mod.custom_secs {
    let @lib.CustomSec(name, _) = custom
    if name != Name::new("name") {
      has_name_custom_sections = true
    }
  }
  if mod.name_sec is Some(_) {
    has_name_custom_sections = true
  }

  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        let (has_ref, has_v128_fact) = gen_valid_scan_rec_type(rec_type)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128_fact
        has_subtyping_topology = has_subtyping_topology ||
          gen_valid_scan_rec_type_topology(rec_type)
        has_rich_gc_field_plans = has_rich_gc_field_plans ||
          gen_valid_scan_rec_type_rich_gc_field_plan(rec_type)
      }
    None => ()
  }

  let import_modules : Array[Name] = []
  let import_names : Array[Name] = []
  let mut imported_func_count = 0
  let mut imported_table_count = 0
  let mut imported_mem_count = 0
  let mut imported_global_count = 0
  let mut imported_tag_count = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      if !imports.is_empty() {
        has_imports = true
        for imp in imports {
          let Import(module_name, import_name, extern_type) = imp
          let mut saw_module = false
          for existing in import_modules {
            if existing == module_name {
              saw_module = true
            }
          }
          if !saw_module {
            import_modules.push(module_name)
          }
          import_names.push(import_name)
          match extern_type {
            FuncExternType(_) => imported_func_count += 1
            TableExternType(table_type) => {
              imported_table_count += 1
              has_tables = true
              let TableType(ref_type, _) = table_type
              uses_ref_types = uses_ref_types || true
              uses_v128 = uses_v128 || false
              has_table_limit_variants = has_table_limit_variants ||
                gen_valid_table_type_has_limit_variant(table_type, None)
              ignore(ref_type)
            }
            MemExternType(mt) => {
              imported_mem_count += 1
              has_mems = true
              has_memory_limit_variants = has_memory_limit_variants ||
                gen_valid_mem_type_has_limit_variant(mt)
              has_shared_memories = has_shared_memories ||
                gen_valid_mem_type_is_shared(mt)
            }
            GlobalExternType(global_type) => {
              imported_global_count += 1
              has_globals = true
              let GlobalType(vt, _) = global_type
              let (has_ref, has_v128_fact) = gen_valid_scan_val_type(vt)
              uses_ref_types = uses_ref_types || has_ref
              uses_v128 = uses_v128 || has_v128_fact
            }
            TagExternType(_) => {
              imported_tag_count += 1
              has_tags = true
            }
          }
        }
      }
    None => ()
  }

  match mod.table_sec {
    Some(TableSec(tables)) if !tables.is_empty() => {
      has_tables = true
      uses_ref_types = true
      for table in tables {
        let Table(table_type, init_opt) = table
        has_table_limit_variants = has_table_limit_variants ||
          gen_valid_table_type_has_limit_variant(table_type, init_opt)
        match init_opt {
          Some(init) =>
            has_const_expr_variants = has_const_expr_variants ||
              gen_valid_const_expr_has_variant(init)
          None => ()
        }
      }
    }
    _ => ()
  }
  match mod.mem_sec {
    Some(MemSec(mems)) if !mems.is_empty() => {
      has_mems = true
      for mt in mems {
        has_memory_limit_variants = has_memory_limit_variants ||
          gen_valid_mem_type_has_limit_variant(mt)
        has_shared_memories = has_shared_memories ||
          gen_valid_mem_type_is_shared(mt)
      }
    }
    _ => ()
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      if !globals.is_empty() {
        has_globals = true
        for global in globals {
          let Global(global_type, expr) = global
          let GlobalType(vt, _) = global_type
          let (has_ref, has_v128_fact) = gen_valid_scan_val_type(vt)
          has_const_expr_variants = has_const_expr_variants ||
            gen_valid_const_expr_has_variant(expr)
          let expr_facts = gen_valid_scan_expr(expr)
          uses_ref_types = uses_ref_types ||
            has_ref ||
            expr_facts.uses_ref_types
          uses_v128 = uses_v128 || has_v128_fact || expr_facts.uses_v128
          has_call = has_call || expr_facts.has_call
          has_call_indirect = has_call_indirect || expr_facts.has_call_indirect
          has_numeric_full_ops = has_numeric_full_ops ||
            expr_facts.has_numeric_full_ops
          has_br_table = has_br_table || expr_facts.has_br_table
          has_standalone_unreachable = has_standalone_unreachable ||
            expr_facts.has_standalone_unreachable
          has_local_tee = has_local_tee || expr_facts.has_local_tee
          has_typed_select = has_typed_select || expr_facts.has_typed_select
          has_tail_calls = has_tail_calls || expr_facts.has_tail_calls
          has_scalar_memory_widths = has_scalar_memory_widths ||
            expr_facts.has_scalar_memory_widths
          has_nonzero_memarg = has_nonzero_memarg ||
            expr_facts.has_nonzero_memarg
          has_basic_ref_instructions = has_basic_ref_instructions ||
            expr_facts.has_basic_ref_instructions
          has_i31_extern_conversions = has_i31_extern_conversions ||
            expr_facts.has_i31_extern_conversions
          has_simd_phase1 = has_simd_phase1 || expr_facts.has_simd_phase1
          has_simd_phase2 = has_simd_phase2 || expr_facts.has_simd_phase2
          has_simd_phase3 = has_simd_phase3 || expr_facts.has_simd_phase3
          has_atomics = has_atomics || expr_facts.has_atomics
          has_gc_constructors = has_gc_constructors ||
            expr_facts.has_gc_constructors
          has_gc_accessors = has_gc_accessors || expr_facts.has_gc_accessors
          has_string_ops = has_string_ops || expr_facts.has_string_ops
          has_exception_try_table_matrix = has_exception_try_table_matrix ||
            expr_facts.has_exception_try_table_matrix
          exact_opcode_counts = exact_opcode_counts.add(
            expr_facts.exact_opcode_counts,
          )
          control_nodes += expr_facts.control_nodes
          branch_ops += expr_facts.branch_ops
        }
      }
    None => ()
  }
  match mod.tag_sec {
    Some(TagSec(tags)) if !tags.is_empty() => has_tags = true
    _ => ()
  }
  match mod.export_sec {
    Some(ExportSec(exports)) => {
      let export_idxs : Array[ExternIdx] = []
      for export_ in exports {
        let Export(export_name, idx) = export_
        for import_name in import_names {
          if import_name == export_name {
            has_import_export_topology = true
          }
        }
        for prior_idx in export_idxs {
          if prior_idx == idx {
            has_import_export_topology = true
          }
        }
        export_idxs.push(idx)
        match idx {
          FuncExternIdx(FuncIdx(func_idx)) => {
            has_func_exports = true
            has_import_export_topology = has_import_export_topology ||
              func_idx.reinterpret_as_int() < imported_func_count
          }
          TableExternIdx(TableIdx(table_idx)) => {
            has_table_exports = true
            has_import_export_topology = has_import_export_topology ||
              table_idx.reinterpret_as_int() < imported_table_count
          }
          MemExternIdx(MemIdx(mem_idx)) => {
            has_mem_exports = true
            has_import_export_topology = has_import_export_topology ||
              mem_idx.reinterpret_as_int() < imported_mem_count
          }
          GlobalExternIdx(GlobalIdx(global_idx)) => {
            has_global_exports = true
            has_import_export_topology = has_import_export_topology ||
              global_idx.reinterpret_as_int() < imported_global_count
          }
          TagExternIdx(TagIdx(tag_idx)) => {
            has_tag_exports = true
            has_import_export_topology = has_import_export_topology ||
              tag_idx.reinterpret_as_int() < imported_tag_count
          }
        }
      }
    }
    None => ()
  }
  has_import_export_topology = has_import_export_topology ||
    (
      has_imports &&
      (
        has_func_exports ||
        has_table_exports ||
        has_mem_exports ||
        has_global_exports ||
        has_tag_exports
      )
    ) ||
    import_modules.length() > 1 ||
    (match mod.start_sec {
      Some(StartSec(FuncIdx(func_idx))) =>
        func_idx.reinterpret_as_int() < imported_func_count
      None => false
    })
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      if !elems.is_empty() {
        has_elems = true
        uses_ref_types = true
        for elem in elems {
          let Elem(mode, kind) = elem
          match mode {
            Active(table_idx, expr) => {
              let TableIdx(table_idx_u) = table_idx
              has_element_segment_range = has_element_segment_range ||
                table_idx_u.reinterpret_as_int() > 0

              has_const_expr_variants = has_const_expr_variants ||
                gen_valid_const_expr_has_variant(expr)
              let facts = gen_valid_scan_expr(expr)
              uses_ref_types = uses_ref_types || facts.uses_ref_types
              uses_v128 = uses_v128 || facts.uses_v128
              has_call = has_call || facts.has_call
              has_call_indirect = has_call_indirect || facts.has_call_indirect
              has_numeric_full_ops = has_numeric_full_ops ||
                facts.has_numeric_full_ops
              has_br_table = has_br_table || facts.has_br_table
              has_standalone_unreachable = has_standalone_unreachable ||
                facts.has_standalone_unreachable
              has_local_tee = has_local_tee || facts.has_local_tee
              has_typed_select = has_typed_select || facts.has_typed_select
              has_tail_calls = has_tail_calls || facts.has_tail_calls
              has_scalar_memory_widths = has_scalar_memory_widths ||
                facts.has_scalar_memory_widths
              has_nonzero_memarg = has_nonzero_memarg ||
                facts.has_nonzero_memarg
              has_basic_ref_instructions = has_basic_ref_instructions ||
                facts.has_basic_ref_instructions
              has_i31_extern_conversions = has_i31_extern_conversions ||
                facts.has_i31_extern_conversions
              has_simd_phase1 = has_simd_phase1 || facts.has_simd_phase1
              has_simd_phase2 = has_simd_phase2 || facts.has_simd_phase2
              has_simd_phase3 = has_simd_phase3 || facts.has_simd_phase3
              has_atomics = has_atomics || facts.has_atomics
              has_gc_constructors = has_gc_constructors ||
                facts.has_gc_constructors
              has_gc_accessors = has_gc_accessors || facts.has_gc_accessors
              has_string_ops = has_string_ops || facts.has_string_ops
              has_exception_try_table_matrix = has_exception_try_table_matrix ||
                facts.has_exception_try_table_matrix
              exact_opcode_counts = exact_opcode_counts.add(
                facts.exact_opcode_counts,
              )
              control_nodes += facts.control_nodes
              branch_ops += facts.branch_ops
            }
            _ => ()
          }
          match kind {
            FuncsElemKind(funcs) =>
              has_element_segment_range = has_element_segment_range ||
                funcs.length() > 1
            FuncExprsElemKind(exprs) => {
              has_element_segment_range = has_element_segment_range ||
                exprs.length() > 1
              for expr in exprs {
                has_const_expr_variants = has_const_expr_variants ||
                  gen_valid_const_expr_has_variant(expr)
                let facts = gen_valid_scan_expr(expr)
                uses_ref_types = uses_ref_types || facts.uses_ref_types
                uses_v128 = uses_v128 || facts.uses_v128
                has_call = has_call || facts.has_call
                has_call_indirect = has_call_indirect || facts.has_call_indirect
                has_numeric_full_ops = has_numeric_full_ops ||
                  facts.has_numeric_full_ops
                has_br_table = has_br_table || facts.has_br_table
                has_standalone_unreachable = has_standalone_unreachable ||
                  facts.has_standalone_unreachable
                has_local_tee = has_local_tee || facts.has_local_tee
                has_typed_select = has_typed_select || facts.has_typed_select
                has_tail_calls = has_tail_calls || facts.has_tail_calls
                has_scalar_memory_widths = has_scalar_memory_widths ||
                  facts.has_scalar_memory_widths
                has_nonzero_memarg = has_nonzero_memarg ||
                  facts.has_nonzero_memarg
                has_basic_ref_instructions = has_basic_ref_instructions ||
                  facts.has_basic_ref_instructions
                has_i31_extern_conversions = has_i31_extern_conversions ||
                  facts.has_i31_extern_conversions
                has_simd_phase1 = has_simd_phase1 || facts.has_simd_phase1
                has_simd_phase2 = has_simd_phase2 || facts.has_simd_phase2
                has_simd_phase3 = has_simd_phase3 || facts.has_simd_phase3
                has_atomics = has_atomics || facts.has_atomics
                has_gc_constructors = has_gc_constructors ||
                  facts.has_gc_constructors
                has_gc_accessors = has_gc_accessors || facts.has_gc_accessors
                has_string_ops = has_string_ops || facts.has_string_ops
                has_exception_try_table_matrix = has_exception_try_table_matrix ||
                  facts.has_exception_try_table_matrix
                exact_opcode_counts = exact_opcode_counts.add(
                  facts.exact_opcode_counts,
                )
                control_nodes += facts.control_nodes
                branch_ops += facts.branch_ops
              }
            }
            TypedExprsElemKind(rt, exprs) => {
              has_element_segment_range = has_element_segment_range ||
                exprs.length() > 1 ||
                ValType::ref_type(rt) != ValType::funcref()
              uses_ref_types = true
              for expr in exprs {
                has_const_expr_variants = has_const_expr_variants ||
                  gen_valid_const_expr_has_variant(expr)
                let facts = gen_valid_scan_expr(expr)
                uses_ref_types = uses_ref_types || facts.uses_ref_types
                uses_v128 = uses_v128 || facts.uses_v128
                has_call = has_call || facts.has_call
                has_call_indirect = has_call_indirect || facts.has_call_indirect
                has_numeric_full_ops = has_numeric_full_ops ||
                  facts.has_numeric_full_ops
                has_br_table = has_br_table || facts.has_br_table
                has_standalone_unreachable = has_standalone_unreachable ||
                  facts.has_standalone_unreachable
                has_local_tee = has_local_tee || facts.has_local_tee
                has_typed_select = has_typed_select || facts.has_typed_select
                has_tail_calls = has_tail_calls || facts.has_tail_calls
                has_scalar_memory_widths = has_scalar_memory_widths ||
                  facts.has_scalar_memory_widths
                has_nonzero_memarg = has_nonzero_memarg ||
                  facts.has_nonzero_memarg
                has_basic_ref_instructions = has_basic_ref_instructions ||
                  facts.has_basic_ref_instructions
                has_i31_extern_conversions = has_i31_extern_conversions ||
                  facts.has_i31_extern_conversions
                has_simd_phase1 = has_simd_phase1 || facts.has_simd_phase1
                has_simd_phase2 = has_simd_phase2 || facts.has_simd_phase2
                has_simd_phase3 = has_simd_phase3 || facts.has_simd_phase3
                has_atomics = has_atomics || facts.has_atomics
                has_gc_constructors = has_gc_constructors ||
                  facts.has_gc_constructors
                has_gc_accessors = has_gc_accessors || facts.has_gc_accessors
                has_string_ops = has_string_ops || facts.has_string_ops
                has_exception_try_table_matrix = has_exception_try_table_matrix ||
                  facts.has_exception_try_table_matrix
                exact_opcode_counts = exact_opcode_counts.add(
                  facts.exact_opcode_counts,
                )
                control_nodes += facts.control_nodes
                branch_ops += facts.branch_ops
              }
            }
          }
        }
      }
    None => ()
  }
  match mod.data_sec {
    Some(DataSec(datas)) =>
      if !datas.is_empty() {
        has_datas = true
        let mut saw_zero_length_data = false
        let mut saw_large_data = false
        let mut saw_nonzero_memory_data = false
        let mut saw_passive_data = false
        let mut saw_active_data = false
        for data in datas {
          let Data(mode, payload) = data
          saw_zero_length_data = saw_zero_length_data || payload.length() == 0
          saw_large_data = saw_large_data || payload.length() > 16
          match mode {
            Active(mem_idx, expr) => {
              saw_active_data = true
              let MemIdx(mem_idx_u) = mem_idx
              saw_nonzero_memory_data = saw_nonzero_memory_data ||
                mem_idx_u.reinterpret_as_int() > 0
              has_const_expr_variants = has_const_expr_variants ||
                gen_valid_const_expr_has_variant(expr)
              let facts = gen_valid_scan_expr(expr)
              uses_ref_types = uses_ref_types || facts.uses_ref_types
              uses_v128 = uses_v128 || facts.uses_v128
              has_call = has_call || facts.has_call
              has_call_indirect = has_call_indirect || facts.has_call_indirect
              has_numeric_full_ops = has_numeric_full_ops ||
                facts.has_numeric_full_ops
              has_br_table = has_br_table || facts.has_br_table
              has_standalone_unreachable = has_standalone_unreachable ||
                facts.has_standalone_unreachable
              has_local_tee = has_local_tee || facts.has_local_tee
              has_typed_select = has_typed_select || facts.has_typed_select
              has_tail_calls = has_tail_calls || facts.has_tail_calls
              has_scalar_memory_widths = has_scalar_memory_widths ||
                facts.has_scalar_memory_widths
              has_nonzero_memarg = has_nonzero_memarg ||
                facts.has_nonzero_memarg
              has_basic_ref_instructions = has_basic_ref_instructions ||
                facts.has_basic_ref_instructions
              has_i31_extern_conversions = has_i31_extern_conversions ||
                facts.has_i31_extern_conversions
              has_simd_phase1 = has_simd_phase1 || facts.has_simd_phase1
              has_simd_phase2 = has_simd_phase2 || facts.has_simd_phase2
              has_simd_phase3 = has_simd_phase3 || facts.has_simd_phase3
              has_atomics = has_atomics || facts.has_atomics
              has_gc_constructors = has_gc_constructors ||
                facts.has_gc_constructors
              has_gc_accessors = has_gc_accessors || facts.has_gc_accessors
              has_string_ops = has_string_ops || facts.has_string_ops
              has_exception_try_table_matrix = has_exception_try_table_matrix ||
                facts.has_exception_try_table_matrix
              exact_opcode_counts = exact_opcode_counts.add(
                facts.exact_opcode_counts,
              )
              control_nodes += facts.control_nodes
              branch_ops += facts.branch_ops
            }
            Passive => saw_passive_data = true
          }
        }
        has_data_segment_range = saw_large_data ||
          saw_nonzero_memory_data ||
          (saw_zero_length_data && saw_active_data && saw_passive_data)
      }
    None => ()
  }
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(locals, expr) = func
        for local_vt in locals.iter() {
          let (has_ref, has_v128_fact) = gen_valid_scan_val_type(local_vt)
          uses_ref_types = uses_ref_types || has_ref
          uses_v128 = uses_v128 || has_v128_fact
        }
        let facts = gen_valid_scan_expr(expr)
        uses_ref_types = uses_ref_types || facts.uses_ref_types
        uses_v128 = uses_v128 || facts.uses_v128
        has_call = has_call || facts.has_call
        has_call_indirect = has_call_indirect || facts.has_call_indirect
        has_numeric_full_ops = has_numeric_full_ops ||
          facts.has_numeric_full_ops
        has_br_table = has_br_table || facts.has_br_table
        has_payload_control_flow = has_payload_control_flow ||
          facts.has_payload_control_flow
        has_multivalue_control_flow = has_multivalue_control_flow ||
          facts.has_multivalue_control_flow ||
          gen_valid_expr_has_multivalue_control_flow(mod, expr)
        has_standalone_unreachable = has_standalone_unreachable ||
          facts.has_standalone_unreachable
        has_local_tee = has_local_tee || facts.has_local_tee
        has_typed_select = has_typed_select || facts.has_typed_select
        has_tail_calls = has_tail_calls || facts.has_tail_calls
        has_scalar_memory_widths = has_scalar_memory_widths ||
          facts.has_scalar_memory_widths
        has_nonzero_memarg = has_nonzero_memarg || facts.has_nonzero_memarg
        has_basic_ref_instructions = has_basic_ref_instructions ||
          facts.has_basic_ref_instructions
        has_i31_extern_conversions = has_i31_extern_conversions ||
          facts.has_i31_extern_conversions
        has_simd_phase1 = has_simd_phase1 || facts.has_simd_phase1
        has_simd_phase2 = has_simd_phase2 || facts.has_simd_phase2
        has_simd_phase3 = has_simd_phase3 || facts.has_simd_phase3
        has_atomics = has_atomics || facts.has_atomics
        has_gc_constructors = has_gc_constructors || facts.has_gc_constructors
        has_gc_accessors = has_gc_accessors || facts.has_gc_accessors
        has_string_ops = has_string_ops || facts.has_string_ops
        has_exception_try_table_matrix = has_exception_try_table_matrix ||
          facts.has_exception_try_table_matrix
        exact_opcode_counts = exact_opcode_counts.add(facts.exact_opcode_counts)
        control_nodes += facts.control_nodes
        branch_ops += facts.branch_ops
      }
    None => ()
  }

  let has_gc_feature = has_gc_constructors ||
    has_gc_accessors ||
    has_subtyping_topology ||
    has_rich_gc_field_plans
  let has_any_export = has_func_exports ||
    has_table_exports ||
    has_mem_exports ||
    has_global_exports ||
    has_tag_exports
  {
    mode,
    has_imports,
    has_func_exports,
    has_table_exports,
    has_mem_exports,
    has_global_exports,
    has_tag_exports,
    has_start,
    lacks_start: !has_start,
    has_tables,
    has_mems,
    has_globals,
    has_tags,
    has_elems,
    has_datas,
    has_data_count,
    uses_ref_types,
    uses_v128,
    has_call,
    has_call_indirect,
    has_branch_heavy_control: branch_ops > 0 || control_nodes >= 2,
    has_payload_control_flow,
    has_multivalue_control_flow,
    has_numeric_full_ops,
    has_br_table,
    has_standalone_unreachable,
    has_local_tee,
    has_typed_select,
    has_tail_calls,
    has_scalar_memory_widths,
    has_nonzero_memarg,
    has_memory_limit_variants,
    has_table_limit_variants,
    has_const_expr_variants,
    has_basic_ref_instructions,
    has_i31_extern_conversions,
    has_simd_phase1,
    has_simd_phase2,
    has_simd_phase3,
    has_atomics,
    has_gc_constructors,
    has_gc_accessors,
    has_string_ops,
    has_exception_try_table_matrix,
    has_subtyping_topology,
    has_rich_gc_field_plans,
    has_import_export_topology,
    has_element_segment_range,
    has_data_segment_range,
    has_name_custom_sections,
    has_gc_exception_combo: has_gc_feature && has_exception_try_table_matrix,
    has_gc_tail_call_combo: has_gc_feature && has_tail_calls,
    has_shared_memory_atomics: has_shared_memories && has_atomics,
    has_imports_start_exports: has_imports && has_start && has_any_export,
    exact_opcode_counts,
  }
}
