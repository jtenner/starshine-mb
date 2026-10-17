import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export function applyValidateInvalidAstStrategy(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_21_is_ok","unwrapOk":"__js_result_21_unwrap_ok","unwrapErr":"__js_result_21_unwrap_err"}, ok: { kind: "named", brand: "validate.ValidateInvalidAstMutation", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["validate__apply_validate_invalid_ast_strategy"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg1, wasm)), wasm);
}

export function buildValidateInvalidAstMinimalRepro(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_22_is_ok","unwrapOk":"__js_result_22_unwrap_ok","unwrapErr":"__js_result_22_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string", moonType: "String" } }, wasm["validate__build_validate_invalid_ast_minimal_repro"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm)), wasm);
}

export function buildValidateInvalidAstMinimalReproByStableId(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_22_is_ok","unwrapOk":"__js_result_22_unwrap_ok","unwrapErr":"__js_result_22_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string", moonType: "String" } }, wasm["validate__build_validate_invalid_ast_minimal_repro_by_stable_id"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function checkValidateValidFeatureFloors(arg0, arg1) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_44_new","push":"__js_array_44_push","length":"__js_array_44_length","get":"__js_array_44_get"}, item: { kind: "named", brand: "validate.ValidateValidFeatureFloorFailure", showExport: "__js_show_validate_ValidateValidFeatureFloorFailure" } }, wasm["validate__check_validate_valid_feature_floors"](lowerValue({ kind: "named", brand: "validate.GenValidFeatureStats", showExport: "__js_show_validate_GenValidFeatureStats" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_43_new","push":"__js_array_43_push","length":"__js_array_43_length","get":"__js_array_43_get"}, item: { kind: "named", brand: "validate.ValidateValidFeatureFloor", showExport: "__js_show_validate_ValidateValidFeatureFloor" } }, arg1, wasm)), wasm);
}

export function controlledProposalFeatures() {
  return liftValue({ kind: "array", helper: {"new":"__js_array_45_new","push":"__js_array_45_push","length":"__js_array_45_length","get":"__js_array_45_get"}, item: { kind: "named", brand: "validate.ProposalFeature", showExport: null } }, wasm["validate__controlled_proposal_features"](), wasm);
}

export function defaultGenValidConfig() {
  return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__default_gen_valid_config"](), wasm);
}

export function descriptorCompatible(arg0, arg1, arg2) {
  return liftValue({ kind: "bool", moonType: "Bool" }, wasm["validate__descriptor_compatible"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg1, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg2, wasm)), wasm);
}

export function diff(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_23_is_ok","unwrapOk":"__js_result_23_unwrap_ok","unwrapErr":"__js_result_23_unwrap_err"}, ok: { kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, err: { kind: "string", moonType: "String" } }, wasm["validate__diff"](lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, arg1, wasm)), wasm);
}

export function emptyEnv() {
  return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__empty_env"](), wasm);
}

export function genInvalidAstGenerate(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_24_is_ok","unwrapOk":"__js_result_24_unwrap_ok","unwrapErr":"__js_result_24_unwrap_err"}, ok: { kind: "named", brand: "validate.GenInvalidAstGenerated", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["validate__gen_invalid_ast_generate"](lowerValue({ kind: "opaque", brand: "@splitmix.RandomState" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, arg1, wasm)), wasm);
}

export function genInvalidAstGenerateFromSeed(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_24_is_ok","unwrapOk":"__js_result_24_unwrap_ok","unwrapErr":"__js_result_24_unwrap_err"}, ok: { kind: "named", brand: "validate.GenInvalidAstGenerated", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["validate__gen_invalid_ast_generate_from_seed"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, arg1, wasm)), wasm);
}

export function genInvalidAstParamsProfileName(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_invalid_ast_params_profile_name"](lowerValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, arg0, wasm)), wasm);
}

export function genInvalidAstSeedConfig(arg0) {
  return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__gen_invalid_ast_seed_config"](lowerValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, arg0, wasm)), wasm);
}

export function genInvalidAstSeedModule(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_22_is_ok","unwrapOk":"__js_result_22_unwrap_ok","unwrapErr":"__js_result_22_unwrap_err"}, ok: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, err: { kind: "string", moonType: "String" } }, wasm["validate__gen_invalid_ast_seed_module"](lowerValue({ kind: "opaque", brand: "@splitmix.RandomState" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, arg1, wasm)), wasm);
}

export function genInvalidAstStrategySeedPrerequisites(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_46_new","push":"__js_array_46_push","length":"__js_array_46_length","get":"__js_array_46_get"}, item: { kind: "named", brand: "validate.ValidateInvalidAstSeedPrerequisite", showExport: null } }, wasm["validate__gen_invalid_ast_strategy_seed_prerequisites"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm)), wasm);
}

export function genInvalidCoverageSeedGeneratorConfig() {
  return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__gen_invalid_coverage_seed_generator_config"](), wasm);
}

export function genInvalidNamedSeedProfileName(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_invalid_named_seed_profile_name"](lowerValue({ kind: "named", brand: "validate.GenInvalidNamedSeedProfile", showExport: null }, arg0, wasm)), wasm);
}

export function genInvalidRequireDefinedFuncGenValidConfig(arg0) {
  return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__gen_invalid_require_defined_func_gen_valid_config"](lowerValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, arg0, wasm)), wasm);
}

export function genInvalidRequireMemoryDataGenValidConfig(arg0) {
  return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__gen_invalid_require_memory_data_gen_valid_config"](lowerValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, arg0, wasm)), wasm);
}

export function genInvalidSeedModeName(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_invalid_seed_mode_name"](lowerValue({ kind: "named", brand: "validate.GenInvalidSeedMode", showExport: null }, arg0, wasm)), wasm);
}

export function genInvalidSmallGenValidConfig(arg0) {
  return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__gen_invalid_small_gen_valid_config"](lowerValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, arg0, wasm)), wasm);
}

export function genValidCaseSeed(arg0, arg1) {
  return liftValue({ kind: "bigint", moonType: "UInt64" }, wasm["validate__gen_valid_case_seed"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm)), wasm);
}

export function genValidCodeFoldingProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_code_folding_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidConfigLabel(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_config_label"](lowerValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, arg0, wasm)), wasm);
}

export function genValidConstExprAllowedOpMatrix() {
  return liftValue({ kind: "array", helper: {"new":"__js_array_47_new","push":"__js_array_47_push","length":"__js_array_47_length","get":"__js_array_47_get"}, item: { kind: "named", brand: "validate.GenValidConstExprAllowedOps", showExport: null } }, wasm["validate__gen_valid_const_expr_allowed_op_matrix"](), wasm);
}

export function genValidConstExprObservedOpMatrix(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_48_new","push":"__js_array_48_push","length":"__js_array_48_length","get":"__js_array_48_get"}, item: { kind: "named", brand: "validate.GenValidConstExprObservedOps", showExport: null } }, wasm["validate__gen_valid_const_expr_observed_op_matrix"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm)), wasm);
}

export function genValidCoverageTemplateSignature(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_coverage_template_signature"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm)), wasm);
}

export function genValidDaeOptimizingProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_dae_optimizing_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidDeadArgumentEliminationProfileConfig(arg0) {
  return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__gen_valid_dead_argument_elimination_profile_config"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm)), wasm);
}

export function genValidDeriveStreamSeed(arg0, arg1) {
  return liftValue({ kind: "bigint", moonType: "UInt64" }, wasm["validate__gen_valid_derive_stream_seed"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidRandomStreamLabel", showExport: null }, arg1, wasm)), wasm);
}

export function genValidDirectizeProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_directize_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidDuplicateImportEliminationProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_duplicate_import_elimination_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidEngineStateCrossInstanceSupportModule(arg0) {
  return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["validate__gen_valid_engine_state_cross_instance_support_module"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm)), wasm);
}

export function genValidEngineStateFailureFamily(arg0, arg1) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_engine_state_failure_family"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidEngineStateIndirectTrapFamily(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_engine_state_indirect_trap_family"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm)), wasm);
}

export function genValidEngineStateInstantiationFailureFamily(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_engine_state_instantiation_failure_family"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm)), wasm);
}

export function genValidEngineStateInvalidModuleFamily(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_engine_state_invalid_module_family"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm)), wasm);
}

export function genValidEngineStateLinkGraphSupportModules(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_49_new","push":"__js_array_49_push","length":"__js_array_49_length","get":"__js_array_49_get"}, item: { kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" } }, wasm["validate__gen_valid_engine_state_link_graph_support_modules"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm)), wasm);
}

export function genValidEngineStateMetamorphicComparisonModule(arg0) {
  return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["validate__gen_valid_engine_state_metamorphic_comparison_module"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm)), wasm);
}

export function genValidEngineStateOutcome(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_engine_state_outcome"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm)), wasm);
}

export function genValidEngineStateProfile() {
  return liftValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, wasm["validate__gen_valid_engine_state_profile"](), wasm);
}

export function genValidEngineStateStaticInstructionCount(arg0) {
  return liftValue({ kind: "number", moonType: "Int" }, wasm["validate__gen_valid_engine_state_static_instruction_count"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm)), wasm);
}

export function genValidEngineStateTrapCommitFamily(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_engine_state_trap_commit_family"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm)), wasm);
}

export function genValidEngineStateTrapFamily(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_engine_state_trap_family"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm)), wasm);
}

export function genValidEngineTieringProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_engine_tiering_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidFeatureFacts(arg0, arg1) {
  return liftValue({ kind: "named", brand: "validate.GenValidFeatureFacts", showExport: null }, wasm["validate__gen_valid_feature_facts"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidMode", showExport: "__js_show_validate_GenValidMode" }, arg1, wasm)), wasm);
}

export function genValidFlattenProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_flatten_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidHeapStoreOptimizationProfileCaseLabel(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_heap_store_optimization_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm)), wasm);
}

export function genValidInliningOptimizingProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_inlining_optimizing_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidMemoryPackingProfileCaseLabel(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_memory_packing_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm)), wasm);
}

export function genValidMergeBlocksProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_merge_blocks_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidMergeLocalsProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_merge_locals_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidMergeSsaFuncFacts(arg0, arg1) {
  return liftValue({ kind: "named", brand: "validate.GenValidSsaFuncFacts", showExport: null }, wasm["validate__gen_valid_merge_ssa_func_facts"](lowerValue({ kind: "named", brand: "validate.GenValidSsaFuncFacts", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidSsaFuncFacts", showExport: null }, arg1, wasm)), wasm);
}

export function genValidModule(arg0) {
  return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["validate__gen_valid_module"](lowerValue({ kind: "opaque", brand: "@splitmix.RandomState" }, arg0, wasm)), wasm);
}

export function genValidModuleFromSeed(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_25_is_ok","unwrapOk":"__js_result_25_unwrap_ok","unwrapErr":"__js_result_25_unwrap_err"}, ok: { kind: "named", brand: "validate.GenValidModuleGenerated", showExport: null }, err: { kind: "named", brand: "validate.GenValidFailure", showExport: null } }, wasm["validate__gen_valid_module_from_seed"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, arg1, wasm)), wasm);
}

export function genValidModuleResult(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_26_is_ok","unwrapOk":"__js_result_26_unwrap_ok","unwrapErr":"__js_result_26_unwrap_err"}, ok: { kind: "named", brand: "validate.GenValidGenerated", showExport: null }, err: { kind: "named", brand: "validate.GenValidFailure", showExport: null } }, wasm["validate__gen_valid_module_result"](lowerValue({ kind: "opaque", brand: "@splitmix.RandomState" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, arg1, wasm)), wasm);
}

export function genValidModuleResultFromSeed(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_26_is_ok","unwrapOk":"__js_result_26_unwrap_ok","unwrapErr":"__js_result_26_unwrap_err"}, ok: { kind: "named", brand: "validate.GenValidGenerated", showExport: null }, err: { kind: "named", brand: "validate.GenValidFailure", showExport: null } }, wasm["validate__gen_valid_module_result_from_seed"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, arg1, wasm)), wasm);
}

export function genValidModuleWithConfig(arg0, arg1) {
  return liftValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, wasm["validate__gen_valid_module_with_config"](lowerValue({ kind: "opaque", brand: "@splitmix.RandomState" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, arg1, wasm)), wasm);
}

export function genValidMsfProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_msf_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export const genValidNumtype = unsupportedExport("validate.genValidNumtype", "The FFI excludes this generic or inaccessible signature.");

export function genValidOiTriggerProfileCaseForSeed(arg0) {
  return liftValue({ kind: "number", moonType: "Int" }, wasm["validate__gen_valid_oi_trigger_profile_case_for_seed"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm)), wasm);
}

export function genValidOiTriggerProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_oi_trigger_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidProfileByName(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_27_is_ok","unwrapOk":"__js_result_27_unwrap_ok","unwrapErr":"__js_result_27_unwrap_err"}, ok: { kind: "named", brand: "validate.GenValidProfile", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_profile_by_name"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function genValidProfileIsComposite(arg0) {
  return liftValue({ kind: "bool", moonType: "Bool" }, wasm["validate__gen_valid_profile_is_composite"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm)), wasm);
}

export function genValidProfileLeafForCase(arg0, arg1, arg2) {
  return liftValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, wasm["validate__gen_valid_profile_leaf_for_case"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg2, wasm)), wasm);
}

export function genValidProfileMembers(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_50_new","push":"__js_array_50_push","length":"__js_array_50_length","get":"__js_array_50_get"}, item: { kind: "named", brand: "validate.GenValidProfileMember", showExport: null } }, wasm["validate__gen_valid_profile_members"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm)), wasm);
}

export function genValidProfileName(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_profile_name"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm)), wasm);
}

export function genValidProfileNames() {
  return liftValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_profile_names"](), wasm);
}

export function genValidProfiles() {
  return liftValue({ kind: "array", helper: {"new":"__js_array_51_new","push":"__js_array_51_push","length":"__js_array_51_length","get":"__js_array_51_get"}, item: { kind: "named", brand: "validate.GenValidProfile", showExport: null } }, wasm["validate__gen_valid_profiles"](), wasm);
}

export function genValidProposalFeatureEnabled(arg0, arg1) {
  return liftValue({ kind: "bool", moonType: "Bool" }, wasm["validate__gen_valid_proposal_feature_enabled"](lowerValue({ kind: "named", brand: "validate.GenValidFeatureToggles", showExport: "__js_show_validate_GenValidFeatureToggles" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidProposalFeature", showExport: null }, arg1, wasm)), wasm);
}

export function genValidProposalFeatureGateMatrix() {
  return liftValue({ kind: "array", helper: {"new":"__js_array_52_new","push":"__js_array_52_push","length":"__js_array_52_length","get":"__js_array_52_get"}, item: { kind: "named", brand: "validate.GenValidProposalFeatureGateRow", showExport: null } }, wasm["validate__gen_valid_proposal_feature_gate_matrix"](), wasm);
}

export function genValidProposalFeatureLabel(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_proposal_feature_label"](lowerValue({ kind: "named", brand: "validate.GenValidProposalFeature", showExport: null }, arg0, wasm)), wasm);
}

export function genValidProposalFeatures() {
  return liftValue({ kind: "array", helper: {"new":"__js_array_53_new","push":"__js_array_53_push","length":"__js_array_53_length","get":"__js_array_53_get"}, item: { kind: "named", brand: "validate.GenValidProposalFeature", showExport: null } }, wasm["validate__gen_valid_proposal_features"](), wasm);
}

export function genValidRandomStreamLabelName(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__gen_valid_random_stream_label_name"](lowerValue({ kind: "named", brand: "validate.GenValidRandomStreamLabel", showExport: null }, arg0, wasm)), wasm);
}

export function genValidRandomStreamLabels() {
  return liftValue({ kind: "array", helper: {"new":"__js_array_54_new","push":"__js_array_54_push","length":"__js_array_54_length","get":"__js_array_54_get"}, item: { kind: "named", brand: "validate.GenValidRandomStreamLabel", showExport: null } }, wasm["validate__gen_valid_random_stream_labels"](), wasm);
}

export function genValidReorderGlobalsProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_reorder_globals_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidRumeProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_rume_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidScanFuncSsaFacts(arg0, arg1, arg2) {
  return liftValue({ kind: "named", brand: "validate.GenValidSsaFuncFacts", showExport: null }, wasm["validate__gen_valid_scan_func_ssa_facts"](lowerValue({ kind: "number", moonType: "Int" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Locals", showExport: "__js_show_lib_Locals" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg2, wasm)), wasm);
}

export function genValidSsaFullProfileCaseLabel(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_ssa_full_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm)), wasm);
}

export function genValidStreamRandomState(arg0, arg1) {
  return liftValue({ kind: "opaque", brand: "@splitmix.RandomState" }, wasm["validate__gen_valid_stream_random_state"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidRandomStreamLabel", showExport: null }, arg1, wasm)), wasm);
}

export const genValidTfunc = unsupportedExport("validate.genValidTfunc", "The FFI excludes this generic or inaccessible signature.");

export function genValidTupleOptimizationTriggerProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_tuple_optimization_trigger_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function genValidUndersampledPassProfileCaseLabel(arg0, arg1) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, wasm["validate__gen_valid_undersampled_pass_profile_case_label"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export const genValidValtype = unsupportedExport("validate.genValidValtype", "The FFI excludes this generic or inaccessible signature.");

export const genValidValtypeWithExtraRefs = unsupportedExport("validate.genValidValtypeWithExtraRefs", "The FFI excludes this generic or inaccessible signature.");

export function makeState(arg0, arg1) {
  return liftValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, wasm["validate__make_state"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
}

export function makeStateOwned(arg0, arg1) {
  return liftValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, wasm["validate__make_state_owned"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
}

export function moduleProposalFeatures(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_45_new","push":"__js_array_45_push","length":"__js_array_45_length","get":"__js_array_45_get"}, item: { kind: "named", brand: "validate.ProposalFeature", showExport: null } }, wasm["validate__module_proposal_features"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm)), wasm);
}

export function proposalFeatureByName(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_85_none","some":"__js_option_85_some","isSome":"__js_option_85_is_some","unwrap":"__js_option_85_unwrap"}, item: { kind: "named", brand: "validate.ProposalFeature", showExport: null } }, wasm["validate__proposal_feature_by_name"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function proposalFeatureName(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__proposal_feature_name"](lowerValue({ kind: "named", brand: "validate.ProposalFeature", showExport: null }, arg0, wasm)), wasm);
}

export function runValidateInvalidAstFuzz(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_28_is_ok","unwrapOk":"__js_result_28_unwrap_ok","unwrapErr":"__js_result_28_unwrap_err"}, ok: { kind: "named", brand: "validate.ValidateInvalidAstFuzzStats", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["validate__run_validate_invalid_ast_fuzz"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function runValidateValidFuzz(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_29_is_ok","unwrapOk":"__js_result_29_unwrap_ok","unwrapErr":"__js_result_29_unwrap_err"}, ok: { kind: "named", brand: "validate.ValidateValidFuzzStats", showExport: "__js_show_validate_ValidateValidFuzzStats" }, err: { kind: "string", moonType: "String" } }, wasm["validate__run_validate_valid_fuzz"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function tcEscapeNone() {
  return liftValue({ kind: "named", brand: "validate.TcEscape", showExport: "__js_show_validate_TcEscape" }, wasm["validate__tc_escape_none"](), wasm);
}

export function tcEscapeTerminal() {
  return liftValue({ kind: "named", brand: "validate.TcEscape", showExport: "__js_show_validate_TcEscape" }, wasm["validate__tc_escape_terminal"](), wasm);
}

export function tcStateClone(arg0) {
  return liftValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, wasm["validate__tc_state_clone"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm)), wasm);
}

export function tcStateFinishBlock(arg0, arg1, arg2, arg3) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_30_is_ok","unwrapOk":"__js_result_30_unwrap_ok","unwrapErr":"__js_result_30_unwrap_err"}, ok: { kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, err: { kind: "string", moonType: "String" } }, wasm["validate__tc_state_finish_block"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg1, wasm), lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg2, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg3, wasm)), wasm);
}

export function tcStateFinishIf(arg0, arg1, arg2, arg3, arg4) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_30_is_ok","unwrapOk":"__js_result_30_unwrap_ok","unwrapErr":"__js_result_30_unwrap_err"}, ok: { kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, err: { kind: "string", moonType: "String" } }, wasm["validate__tc_state_finish_if"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg1, wasm), lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg2, wasm), lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg3, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg4, wasm)), wasm);
}

export function tcStateFinishLoop(arg0, arg1, arg2, arg3) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_30_is_ok","unwrapOk":"__js_result_30_unwrap_ok","unwrapErr":"__js_result_30_unwrap_err"}, ok: { kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, err: { kind: "string", moonType: "String" } }, wasm["validate__tc_state_finish_loop"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg1, wasm), lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg2, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg3, wasm)), wasm);
}

export function tcStateFinishTryTable(arg0, arg1, arg2, arg3, arg4) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_30_is_ok","unwrapOk":"__js_result_30_unwrap_ok","unwrapErr":"__js_result_30_unwrap_err"}, ok: { kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, err: { kind: "string", moonType: "String" } }, wasm["validate__tc_state_finish_try_table"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg1, wasm), lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg2, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg3, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_35_new","push":"__js_array_35_push","length":"__js_array_35_length","get":"__js_array_35_get"}, item: { kind: "named", brand: "lib.Catch", showExport: "__js_show_lib_Catch" } }, arg4, wasm)), wasm);
}

export function tcStateForkBody(arg0, arg1, arg2) {
  return liftValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, wasm["validate__tc_state_fork_body"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg2, wasm)), wasm);
}

export function tcStateMergeNonfallthroughIfExits(arg0, arg1) {
  return liftValue({ kind: "named", brand: "validate.TcEscape", showExport: "__js_show_validate_TcEscape" }, wasm["validate__tc_state_merge_nonfallthrough_if_exits"](lowerValue({ kind: "named", brand: "validate.TcEscape", showExport: "__js_show_validate_TcEscape" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.TcEscape", showExport: "__js_show_validate_TcEscape" }, arg1, wasm)), wasm);
}

export function tcStateNew(arg0, arg1, arg2, arg3) {
  return liftValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, wasm["validate__tc_state_new"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm), lowerValue({ kind: "bool", moonType: "Bool" }, arg2, wasm), lowerValue({ kind: "named", brand: "validate.TcEscape", showExport: "__js_show_validate_TcEscape" }, arg3, wasm)), wasm);
}

export function tcStateNormalizeUntypedBlockExit(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_31_is_ok","unwrapOk":"__js_result_31_unwrap_ok","unwrapErr":"__js_result_31_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_7_new","getters":["__js_tuple_7_get_0","__js_tuple_7_get_1"]}, items: [{ kind: "bool", moonType: "Bool" }, { kind: "named", brand: "validate.TcEscape", showExport: "__js_show_validate_TcEscape" }] }, err: { kind: "string", moonType: "String" } }, wasm["validate__tc_state_normalize_untyped_block_exit"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
}

export function tcStateNormalizeUntypedIfBranchExit(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_31_is_ok","unwrapOk":"__js_result_31_unwrap_ok","unwrapErr":"__js_result_31_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_7_new","getters":["__js_tuple_7_get_0","__js_tuple_7_get_1"]}, items: [{ kind: "bool", moonType: "Bool" }, { kind: "named", brand: "validate.TcEscape", showExport: "__js_show_validate_TcEscape" }] }, err: { kind: "string", moonType: "String" } }, wasm["validate__tc_state_normalize_untyped_if_branch_exit"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
}

export function tcStatePopExpect(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_30_is_ok","unwrapOk":"__js_result_30_unwrap_ok","unwrapErr":"__js_result_30_unwrap_err"}, ok: { kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, err: { kind: "string", moonType: "String" } }, wasm["validate__tc_state_pop_expect"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, arg1, wasm)), wasm);
}

export function tcStatePopTypes(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_30_is_ok","unwrapOk":"__js_result_30_unwrap_ok","unwrapErr":"__js_result_30_unwrap_err"}, ok: { kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, err: { kind: "string", moonType: "String" } }, wasm["validate__tc_state_pop_types"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
}

export function tcStatePushTypes(arg0, arg1) {
  return liftValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, wasm["validate__tc_state_push_types"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
}

export function tcStateTypecheckCatchClause(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "string", moonType: "String" } }, wasm["validate__tc_state_typecheck_catch_clause"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Catch", showExport: "__js_show_lib_Catch" }, arg1, wasm)), wasm);
}

export function tcStateValidateEndStack(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "string", moonType: "String" } }, wasm["validate__tc_state_validate_end_stack"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
}

export function tcStateWithOwnedStack(arg0, arg1) {
  return liftValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, wasm["validate__tc_state_with_owned_stack"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
}

export function tcStateWithStack(arg0, arg1) {
  return liftValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, wasm["validate__tc_state_with_stack"](lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
}

export function typecheckExprForProbe(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_30_is_ok","unwrapOk":"__js_result_30_unwrap_ok","unwrapErr":"__js_result_30_unwrap_err"}, ok: { kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, err: { kind: "string", moonType: "String" } }, wasm["validate__typecheck_expr_for_probe"](lowerValue({ kind: "named", brand: "lib.Expr", showExport: "__js_show_lib_Expr" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.TcState", showExport: "__js_show_validate_TcState" }, arg1, wasm)), wasm);
}

export function validateCodesec(arg0, arg1, arg2) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_codesec"](lowerValue({ kind: "option", helper: {"none":"__js_option_66_none","some":"__js_option_66_some","isSome":"__js_option_66_is_some","unwrap":"__js_option_66_unwrap"}, item: { kind: "named", brand: "lib.CodeSec", showExport: "__js_show_lib_CodeSec" } }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_48_none","some":"__js_option_48_some","isSome":"__js_option_48_is_some","unwrap":"__js_option_48_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, arg1, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg2, wasm)), wasm);
}

export function validateDatacnt(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_datacnt"](lowerValue({ kind: "option", helper: {"none":"__js_option_64_none","some":"__js_option_64_some","isSome":"__js_option_64_is_some","unwrap":"__js_option_64_unwrap"}, item: { kind: "named", brand: "lib.DataCntSec", showExport: "__js_show_lib_DataCntSec" } }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_68_none","some":"__js_option_68_some","isSome":"__js_option_68_is_some","unwrap":"__js_option_68_unwrap"}, item: { kind: "named", brand: "lib.DataSec", showExport: "__js_show_lib_DataSec" } }, arg1, wasm)), wasm);
}

export function validateDatasec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_32_is_ok","unwrapOk":"__js_result_32_unwrap_ok","unwrapErr":"__js_result_32_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_datasec"](lowerValue({ kind: "option", helper: {"none":"__js_option_68_none","some":"__js_option_68_some","isSome":"__js_option_68_is_some","unwrap":"__js_option_68_unwrap"}, item: { kind: "named", brand: "lib.DataSec", showExport: "__js_show_lib_DataSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateDefinedFuncAgainstModule(arg0, arg1, arg2) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_defined_func_against_module"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.Func", showExport: "__js_show_lib_Func" }, arg2, wasm)), wasm);
}

export function validateDefinedFuncsAgainstModule(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_33_is_ok","unwrapOk":"__js_result_33_unwrap_ok","unwrapErr":"__js_result_33_unwrap_err"}, ok: { kind: "array", helper: {"new":"__js_array_56_new","push":"__js_array_56_push","length":"__js_array_56_length","get":"__js_array_56_get"}, item: { kind: "tuple", helper: {"make":"__js_tuple_9_new","getters":["__js_tuple_9_get_0","__js_tuple_9_get_1"]}, items: [{ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, { kind: "string", moonType: "String" }] } }, err: { kind: "named", brand: "validate.ValidationError", showExport: "__js_show_validate_ValidationError" } }, wasm["validate__validate_defined_funcs_against_module"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_55_new","push":"__js_array_55_push","length":"__js_array_55_length","get":"__js_array_55_get"}, item: { kind: "tuple", helper: {"make":"__js_tuple_8_new","getters":["__js_tuple_8_get_0","__js_tuple_8_get_1"]}, items: [{ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, { kind: "named", brand: "lib.Func", showExport: "__js_show_lib_Func" }] } }, arg1, wasm)), wasm);
}

export function validateElemsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_32_is_ok","unwrapOk":"__js_result_32_unwrap_ok","unwrapErr":"__js_result_32_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_elemsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_62_none","some":"__js_option_62_some","isSome":"__js_option_62_is_some","unwrap":"__js_option_62_unwrap"}, item: { kind: "named", brand: "lib.ElemSec", showExport: "__js_show_lib_ElemSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateExportsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_exportsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_58_none","some":"__js_option_58_some","isSome":"__js_option_58_is_some","unwrap":"__js_option_58_unwrap"}, item: { kind: "named", brand: "lib.ExportSec", showExport: "__js_show_lib_ExportSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateFuncBodyAgainstFunctype(arg0, arg1, arg2) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_func_body_against_functype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.Func", showExport: "__js_show_lib_Func" }, arg2, wasm)), wasm);
}

export function validateFuncsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_32_is_ok","unwrapOk":"__js_result_32_unwrap_ok","unwrapErr":"__js_result_32_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_funcsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_48_none","some":"__js_option_48_some","isSome":"__js_option_48_is_some","unwrap":"__js_option_48_unwrap"}, item: { kind: "named", brand: "lib.FuncSec", showExport: "__js_show_lib_FuncSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateGlobalsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_32_is_ok","unwrapOk":"__js_result_32_unwrap_ok","unwrapErr":"__js_result_32_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_globalsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_56_none","some":"__js_option_56_some","isSome":"__js_option_56_is_some","unwrap":"__js_option_56_unwrap"}, item: { kind: "named", brand: "lib.GlobalSec", showExport: "__js_show_lib_GlobalSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateImportsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_32_is_ok","unwrapOk":"__js_result_32_unwrap_ok","unwrapErr":"__js_result_32_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_importsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_44_none","some":"__js_option_44_some","isSome":"__js_option_44_is_some","unwrap":"__js_option_44_unwrap"}, item: { kind: "named", brand: "lib.ImportSec", showExport: "__js_show_lib_ImportSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateInvalidAstAttemptSeedForProfile(arg0, arg1, arg2) {
  return liftValue({ kind: "bigint", moonType: "UInt64" }, wasm["validate__validate_invalid_ast_attempt_seed_for_profile"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm), lowerValue({ kind: "string", moonType: "String" }, arg2, wasm)), wasm);
}

export function validateInvalidAstRegistry() {
  return liftValue({ kind: "array", helper: {"new":"__js_array_57_new","push":"__js_array_57_push","length":"__js_array_57_length","get":"__js_array_57_get"}, item: { kind: "named", brand: "validate.ValidateInvalidAstStrategySpec", showExport: null } }, wasm["validate__validate_invalid_ast_registry"](), wasm);
}

export function validateInvalidAstRunConfig(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_34_is_ok","unwrapOk":"__js_result_34_unwrap_ok","unwrapErr":"__js_result_34_unwrap_err"}, ok: { kind: "named", brand: "validate.ValidateInvalidAstRunConfig", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_invalid_ast_run_config"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function validateInvalidAstStrategyByStableId(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_86_none","some":"__js_option_86_some","isSome":"__js_option_86_is_some","unwrap":"__js_option_86_unwrap"}, item: { kind: "named", brand: "validate.ValidateInvalidAstStrategySpec", showExport: null } }, wasm["validate__validate_invalid_ast_strategy_by_stable_id"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function validateInvalidAstStrategySpecById(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_86_none","some":"__js_option_86_some","isSome":"__js_option_86_is_some","unwrap":"__js_option_86_unwrap"}, item: { kind: "named", brand: "validate.ValidateInvalidAstStrategySpec", showExport: null } }, wasm["validate__validate_invalid_ast_strategy_spec_by_id"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm)), wasm);
}

export function validateMemsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_32_is_ok","unwrapOk":"__js_result_32_unwrap_ok","unwrapErr":"__js_result_32_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_memsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_52_none","some":"__js_option_52_some","isSome":"__js_option_52_is_some","unwrap":"__js_option_52_unwrap"}, item: { kind: "named", brand: "lib.MemSec", showExport: "__js_show_lib_MemSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateModule(arg0, disabledFeatures) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_35_is_ok","unwrapOk":"__js_result_35_unwrap_ok","unwrapErr":"__js_result_35_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "named", brand: "validate.ValidationError", showExport: "__js_show_validate_ValidationError" } }, wasm["validate__validate_module"](lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_87_none","some":"__js_option_87_some","isSome":"__js_option_87_is_some","unwrap":"__js_option_87_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_45_new","push":"__js_array_45_push","length":"__js_array_45_length","get":"__js_array_45_get"}, item: { kind: "named", brand: "validate.ProposalFeature", showExport: null } } }, disabledFeatures, wasm)), wasm);
}

export const validateModuleWithTrace = unsupportedExport("validate.validateModuleWithTrace", "Higher-order MoonBit callbacks require an explicit JavaScript adapter.");

export function validateStartsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_startsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_60_none","some":"__js_option_60_some","isSome":"__js_option_60_is_some","unwrap":"__js_option_60_unwrap"}, item: { kind: "named", brand: "lib.StartSec", showExport: "__js_show_lib_StartSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateTablesec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_32_is_ok","unwrapOk":"__js_result_32_unwrap_ok","unwrapErr":"__js_result_32_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_tablesec"](lowerValue({ kind: "option", helper: {"none":"__js_option_50_none","some":"__js_option_50_some","isSome":"__js_option_50_is_some","unwrap":"__js_option_50_unwrap"}, item: { kind: "named", brand: "lib.TableSec", showExport: "__js_show_lib_TableSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateTagsec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_32_is_ok","unwrapOk":"__js_result_32_unwrap_ok","unwrapErr":"__js_result_32_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_tagsec"](lowerValue({ kind: "option", helper: {"none":"__js_option_54_none","some":"__js_option_54_some","isSome":"__js_option_54_is_some","unwrap":"__js_option_54_unwrap"}, item: { kind: "named", brand: "lib.TagSec", showExport: "__js_show_lib_TagSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateTypesec(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_32_is_ok","unwrapOk":"__js_result_32_unwrap_ok","unwrapErr":"__js_result_32_unwrap_err"}, ok: { kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_typesec"](lowerValue({ kind: "option", helper: {"none":"__js_option_42_none","some":"__js_option_42_some","isSome":"__js_option_42_is_some","unwrap":"__js_option_42_unwrap"}, item: { kind: "named", brand: "lib.TypeSec", showExport: "__js_show_lib_TypeSec" } }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg1, wasm)), wasm);
}

export function validateValidFeatureActualCount(arg0, arg1) {
  return liftValue({ kind: "number", moonType: "Int" }, wasm["validate__validate_valid_feature_actual_count"](lowerValue({ kind: "named", brand: "validate.GenValidFeatureStats", showExport: "__js_show_validate_GenValidFeatureStats" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.ValidateValidFeatureKey", showExport: "__js_show_validate_ValidateValidFeatureKey" }, arg1, wasm)), wasm);
}

export function validateValidFeatureActualCountByLabel(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_36_is_ok","unwrapOk":"__js_result_36_unwrap_ok","unwrapErr":"__js_result_36_unwrap_err"}, ok: { kind: "number", moonType: "Int" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_valid_feature_actual_count_by_label"](lowerValue({ kind: "named", brand: "validate.GenValidFeatureStats", showExport: "__js_show_validate_GenValidFeatureStats" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
}

export function validateValidFeatureFloor(arg0, arg1) {
  return liftValue({ kind: "named", brand: "validate.ValidateValidFeatureFloor", showExport: "__js_show_validate_ValidateValidFeatureFloor" }, wasm["validate__validate_valid_feature_floor"](lowerValue({ kind: "named", brand: "validate.ValidateValidFeatureKey", showExport: "__js_show_validate_ValidateValidFeatureKey" }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm)), wasm);
}

export function validateValidFeatureFloorByLabel(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_37_is_ok","unwrapOk":"__js_result_37_unwrap_ok","unwrapErr":"__js_result_37_unwrap_err"}, ok: { kind: "named", brand: "validate.ValidateValidFeatureFloor", showExport: "__js_show_validate_ValidateValidFeatureFloor" }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_valid_feature_floor_by_label"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm)), wasm);
}

export function validateValidFeatureLedger(arg0, arg1) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_58_new","push":"__js_array_58_push","length":"__js_array_58_length","get":"__js_array_58_get"}, item: { kind: "named", brand: "validate.ValidateValidFeatureLedgerEntry", showExport: null } }, wasm["validate__validate_valid_feature_ledger"](lowerValue({ kind: "named", brand: "validate.GenValidFeatureStats", showExport: "__js_show_validate_GenValidFeatureStats" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_43_new","push":"__js_array_43_push","length":"__js_array_43_length","get":"__js_array_43_get"}, item: { kind: "named", brand: "validate.ValidateValidFeatureFloor", showExport: "__js_show_validate_ValidateValidFeatureFloor" } }, arg1, wasm)), wasm);
}

export function validateValidRunConfig(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_38_is_ok","unwrapOk":"__js_result_38_unwrap_ok","unwrapErr":"__js_result_38_unwrap_err"}, ok: { kind: "named", brand: "validate.ValidateValidRunConfig", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["validate__validate_valid_run_config"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function validationErrorDiagnostic(arg0) {
  return liftValue({ kind: "named", brand: "validate.ValidationDiagnostic", showExport: "__js_show_validate_ValidationDiagnostic" }, wasm["validate__validation_error_diagnostic"](lowerValue({ kind: "named", brand: "validate.ValidationError", showExport: "__js_show_validate_ValidationError" }, arg0, wasm)), wasm);
}

export function validationErrorFuncIdx(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_88_none","some":"__js_option_88_some","isSome":"__js_option_88_is_some","unwrap":"__js_option_88_unwrap"}, item: { kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" } }, wasm["validate__validation_error_func_idx"](lowerValue({ kind: "named", brand: "validate.ValidationError", showExport: "__js_show_validate_ValidationError" }, arg0, wasm)), wasm);
}

export function validationErrorMessage(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__validation_error_message"](lowerValue({ kind: "named", brand: "validate.ValidationError", showExport: "__js_show_validate_ValidationError" }, arg0, wasm)), wasm);
}

export function validationIssueFamily(arg0) {
  return liftValue({ kind: "named", brand: "validate.ValidationIssueFamily", showExport: null }, wasm["validate__validation_issue_family"](lowerValue({ kind: "named", brand: "validate.ValidationIssue", showExport: "__js_show_validate_ValidationIssue" }, arg0, wasm)), wasm);
}

export function validationIssueMessage(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["validate__validation_issue_message"](lowerValue({ kind: "named", brand: "validate.ValidationIssue", showExport: "__js_show_validate_ValidationIssue" }, arg0, wasm)), wasm);
}

export const Env = Object.freeze({
  appendRectypeTypes(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__append_rectype_types"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" }, arg1, wasm)), wasm);
  },
  descriptorResultType(arg0, arg1, arg2) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_39_is_ok","unwrapOk":"__js_result_39_unwrap_ok","unwrapErr":"__js_result_39_unwrap_err"}, ok: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" }, err: { kind: "string", moonType: "String" } }, wasm["validate__Env__descriptor_result_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_89_none","some":"__js_option_89_some","isSome":"__js_option_89_is_some","unwrap":"__js_option_89_unwrap"}, item: { kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" } }, arg2, wasm)), wasm);
  },
  expandBlocktype(arg0, arg1) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_40_is_ok","unwrapOk":"__js_result_40_unwrap_ok","unwrapErr":"__js_result_40_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_10_new","getters":["__js_tuple_10_get_0","__js_tuple_10_get_1"]}, items: [{ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, { kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }] }, err: { kind: "string", moonType: "String" } }, wasm["validate__Env__expand_blocktype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.BlockType", showExport: "__js_show_lib_BlockType" }, arg1, wasm)), wasm);
  },
  getCatchLabelTypes(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_35_none","some":"__js_option_35_some","isSome":"__js_option_35_is_some","unwrap":"__js_option_35_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, wasm["validate__Env__get_catch_label_types"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg1, wasm)), wasm);
  },
  getElem(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_90_none","some":"__js_option_90_some","isSome":"__js_option_90_is_some","unwrap":"__js_option_90_unwrap"}, item: { kind: "named", brand: "lib.Elem", showExport: "__js_show_lib_Elem" } }, wasm["validate__Env__get_elem"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.ElemIdx", showExport: "__js_show_lib_ElemIdx" }, arg1, wasm)), wasm);
  },
  getFunctypeByFuncidx(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_91_none","some":"__js_option_91_some","isSome":"__js_option_91_is_some","unwrap":"__js_option_91_unwrap"}, item: { kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" } }, wasm["validate__Env__get_functype_by_funcidx"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg1, wasm)), wasm);
  },
  getFunctypeidxByFuncidx(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_82_none","some":"__js_option_82_some","isSome":"__js_option_82_is_some","unwrap":"__js_option_82_unwrap"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } }, wasm["validate__Env__get_functypeidx_by_funcidx"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg1, wasm)), wasm);
  },
  getGlobalType(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_92_none","some":"__js_option_92_some","isSome":"__js_option_92_is_some","unwrap":"__js_option_92_unwrap"}, item: { kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" } }, wasm["validate__Env__get_global_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.GlobalIdx", showExport: "__js_show_lib_GlobalIdx" }, arg1, wasm)), wasm);
  },
  getLabel(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_35_none","some":"__js_option_35_some","isSome":"__js_option_35_is_some","unwrap":"__js_option_35_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, wasm["validate__Env__get_label"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg1, wasm)), wasm);
  },
  getLabelTypes(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_35_none","some":"__js_option_35_some","isSome":"__js_option_35_is_some","unwrap":"__js_option_35_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, wasm["validate__Env__get_label_types"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LabelIdx", showExport: "__js_show_lib_LabelIdx" }, arg1, wasm)), wasm);
  },
  getLocalType(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_30_none","some":"__js_option_30_some","isSome":"__js_option_30_is_some","unwrap":"__js_option_30_unwrap"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, wasm["validate__Env__get_local_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.LocalIdx", showExport: "__js_show_lib_LocalIdx" }, arg1, wasm)), wasm);
  },
  getMemtype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_93_none","some":"__js_option_93_some","isSome":"__js_option_93_is_some","unwrap":"__js_option_93_unwrap"}, item: { kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" } }, wasm["validate__Env__get_memtype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemIdx", showExport: "__js_show_lib_MemIdx" }, arg1, wasm)), wasm);
  },
  getTableType(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_94_none","some":"__js_option_94_some","isSome":"__js_option_94_is_some","unwrap":"__js_option_94_unwrap"}, item: { kind: "named", brand: "lib.TableType", showExport: "__js_show_lib_TableType" } }, wasm["validate__Env__get_table_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableIdx", showExport: "__js_show_lib_TableIdx" }, arg1, wasm)), wasm);
  },
  getTag(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_95_none","some":"__js_option_95_some","isSome":"__js_option_95_is_some","unwrap":"__js_option_95_unwrap"}, item: { kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" } }, wasm["validate__Env__get_tag"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg1, wasm)), wasm);
  },
  hasData(arg0, arg1) {
    return liftValue({ kind: "bool", moonType: "Bool" }, wasm["validate__Env__has_data"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.DataIdx", showExport: "__js_show_lib_DataIdx" }, arg1, wasm)), wasm);
  },
  hasFunc(arg0, arg1) {
    return liftValue({ kind: "bool", moonType: "Bool" }, wasm["validate__Env__has_func"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" }, arg1, wasm)), wasm);
  },
  legacyRethrowCatchOrdinal(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, wasm["validate__Env__legacy_rethrow_catch_ordinal"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "number", moonType: "UInt" }, arg1, wasm)), wasm);
  },
  new() {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__new"](), wasm);
  },
  pushData(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_data"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Data", showExport: "__js_show_lib_Data" }, arg1, wasm)), wasm);
  },
  pushElem(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_elem"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Elem", showExport: "__js_show_lib_Elem" }, arg1, wasm)), wasm);
  },
  pushFunc(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_func"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" }, arg1, wasm)), wasm);
  },
  pushFuncWithTypeidx(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_func_with_typeidx"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" }, arg1, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_82_none","some":"__js_option_82_some","isSome":"__js_option_82_is_some","unwrap":"__js_option_82_unwrap"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } }, arg2, wasm)), wasm);
  },
  pushGlobal(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_global"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" }, arg1, wasm)), wasm);
  },
  pushMem(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_mem"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" }, arg1, wasm)), wasm);
  },
  pushTable(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_table"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TableType", showExport: "__js_show_lib_TableType" }, arg1, wasm)), wasm);
  },
  pushTag(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__push_tag"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" }, arg1, wasm)), wasm);
  },
  resolveArrayField(arg0, arg1) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_19_is_ok","unwrapOk":"__js_result_19_unwrap_ok","unwrapErr":"__js_result_19_unwrap_err"}, ok: { kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" }, err: { kind: "string", moonType: "String" } }, wasm["validate__Env__resolve_array_field"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveComptype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_96_none","some":"__js_option_96_some","isSome":"__js_option_96_is_some","unwrap":"__js_option_96_unwrap"}, item: { kind: "named", brand: "lib.CompType", showExport: "__js_show_lib_CompType" } }, wasm["validate__Env__resolve_comptype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveContFunctype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_91_none","some":"__js_option_91_some","isSome":"__js_option_91_is_some","unwrap":"__js_option_91_unwrap"}, item: { kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" } }, wasm["validate__Env__resolve_cont_functype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveDescriptorTargetRefType(arg0, arg1, arg2) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_23_is_ok","unwrapOk":"__js_result_23_unwrap_ok","unwrapErr":"__js_result_23_unwrap_err"}, ok: { kind: "named", brand: "lib.RefType", showExport: "__js_show_lib_RefType" }, err: { kind: "string", moonType: "String" } }, wasm["validate__Env__resolve_descriptor_target_ref_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "bool", moonType: "Bool" }, arg1, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg2, wasm)), wasm);
  },
  resolveFunctype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_91_none","some":"__js_option_91_some","isSome":"__js_option_91_is_some","unwrap":"__js_option_91_unwrap"}, item: { kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" } }, wasm["validate__Env__resolve_functype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveHeaptypeSubtype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_29_none","some":"__js_option_29_some","isSome":"__js_option_29_is_some","unwrap":"__js_option_29_unwrap"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, wasm["validate__Env__resolve_heaptype_subtype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.HeapType", showExport: "__js_show_lib_HeapType" }, arg1, wasm)), wasm);
  },
  resolveStructDescriptorType(arg0, arg1) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_41_is_ok","unwrapOk":"__js_result_41_unwrap_ok","unwrapErr":"__js_result_41_unwrap_err"}, ok: { kind: "option", helper: {"none":"__js_option_82_none","some":"__js_option_82_some","isSome":"__js_option_82_is_some","unwrap":"__js_option_82_unwrap"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } }, err: { kind: "string", moonType: "String" } }, wasm["validate__Env__resolve_struct_descriptor_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveStructFields(arg0, arg1) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_42_is_ok","unwrapOk":"__js_result_42_unwrap_ok","unwrapErr":"__js_result_42_unwrap_err"}, ok: { kind: "array", helper: {"new":"__js_array_17_new","push":"__js_array_17_push","length":"__js_array_17_length","get":"__js_array_17_get"}, item: { kind: "named", brand: "lib.FieldType", showExport: "__js_show_lib_FieldType" } }, err: { kind: "string", moonType: "String" } }, wasm["validate__Env__resolve_struct_fields"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveStructSubtype(arg0, arg1) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_43_is_ok","unwrapOk":"__js_result_43_unwrap_ok","unwrapErr":"__js_result_43_unwrap_err"}, ok: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" }, err: { kind: "string", moonType: "String" } }, wasm["validate__Env__resolve_struct_subtype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveSubtype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_29_none","some":"__js_option_29_some","isSome":"__js_option_29_is_some","unwrap":"__js_option_29_unwrap"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, wasm["validate__Env__resolve_subtype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  resolveTagFunctype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_91_none","some":"__js_option_91_some","isSome":"__js_option_91_is_some","unwrap":"__js_option_91_unwrap"}, item: { kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" } }, wasm["validate__Env__resolve_tag_functype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TagIdx", showExport: "__js_show_lib_TagIdx" }, arg1, wasm)), wasm);
  },
  resolveTypeidxSubtype(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_29_none","some":"__js_option_29_some","isSome":"__js_option_29_is_some","unwrap":"__js_option_29_unwrap"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, wasm["validate__Env__resolve_typeidx_subtype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" }, arg1, wasm)), wasm);
  },
  withDatas(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_datas"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_21_new","push":"__js_array_21_push","length":"__js_array_21_length","get":"__js_array_21_get"}, item: { kind: "named", brand: "lib.Data", showExport: "__js_show_lib_Data" } }, arg1, wasm)), wasm);
  },
  withElems(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_elems"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_24_new","push":"__js_array_24_push","length":"__js_array_24_length","get":"__js_array_24_get"}, item: { kind: "named", brand: "lib.Elem", showExport: "__js_show_lib_Elem" } }, arg1, wasm)), wasm);
  },
  withExactReferenceInference(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_exact_reference_inference"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "bool", moonType: "Bool" }, arg1, wasm)), wasm);
  },
  withFuncs(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_funcs"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_59_new","push":"__js_array_59_push","length":"__js_array_59_length","get":"__js_array_59_get"}, item: { kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" } }, arg1, wasm)), wasm);
  },
  withFuncsAndTypeIdxs(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_funcs_and_type_idxs"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_59_new","push":"__js_array_59_push","length":"__js_array_59_length","get":"__js_array_59_get"}, item: { kind: "named", brand: "lib.FuncType", showExport: "__js_show_lib_FuncType" } }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_60_new","push":"__js_array_60_push","length":"__js_array_60_length","get":"__js_array_60_get"}, item: { kind: "option", helper: {"none":"__js_option_82_none","some":"__js_option_82_some","isSome":"__js_option_82_is_some","unwrap":"__js_option_82_unwrap"}, item: { kind: "named", brand: "lib.TypeIdx", showExport: "__js_show_lib_TypeIdx" } } }, arg2, wasm)), wasm);
  },
  withGlobals(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_globals"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_61_new","push":"__js_array_61_push","length":"__js_array_61_length","get":"__js_array_61_get"}, item: { kind: "named", brand: "lib.GlobalType", showExport: "__js_show_lib_GlobalType" } }, arg1, wasm)), wasm);
  },
  withLabel(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_label"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
  },
  withLabels(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_labels"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_62_new","push":"__js_array_62_push","length":"__js_array_62_length","get":"__js_array_62_get"}, item: { kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, arg1, wasm)), wasm);
  },
  withLegacyCatchDepth(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_legacy_catch_depth"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm)), wasm);
  },
  withLocals(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_locals"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Locals", showExport: "__js_show_lib_Locals" }, arg1, wasm)), wasm);
  },
  withMems(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_mems"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_37_new","push":"__js_array_37_push","length":"__js_array_37_length","get":"__js_array_37_get"}, item: { kind: "named", brand: "lib.MemType", showExport: "__js_show_lib_MemType" } }, arg1, wasm)), wasm);
  },
  withModule(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_module"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.Module", showExport: "__js_show_lib_Module" }, arg1, wasm)), wasm);
  },
  withRectype(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_rectype"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "named", brand: "lib.RecType", showExport: "__js_show_lib_RecType" }, arg1, wasm)), wasm);
  },
  withReturnType(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_return_type"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_35_none","some":"__js_option_35_some","isSome":"__js_option_35_is_some","unwrap":"__js_option_35_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, arg1, wasm)), wasm);
  },
  withTables(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_tables"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_63_new","push":"__js_array_63_push","length":"__js_array_63_length","get":"__js_array_63_get"}, item: { kind: "named", brand: "lib.TableType", showExport: "__js_show_lib_TableType" } }, arg1, wasm)), wasm);
  },
  withTags(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_tags"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_41_new","push":"__js_array_41_push","length":"__js_array_41_length","get":"__js_array_41_get"}, item: { kind: "named", brand: "lib.TagType", showExport: "__js_show_lib_TagType" } }, arg1, wasm)), wasm);
  },
  withTypes(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, wasm["validate__Env__with_types"](lowerValue({ kind: "named", brand: "validate.Env", showExport: "__js_show_validate_Env" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_18_new","push":"__js_array_18_push","length":"__js_array_18_length","get":"__js_array_18_get"}, item: { kind: "named", brand: "lib.SubType", showExport: "__js_show_lib_SubType" } }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_validate_Env"](lowerValue({ kind: "named", brand: "validate.Env" }, value, wasm));
  },
});

export const GenInvalidAstGenerated = Object.freeze({
});

export const GenInvalidAstParams = Object.freeze({
  coverageForcedSeed(arg0, generatorConfig, requireStrategyPrereqs) {
    return liftValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, wasm["validate__GenInvalidAstParams__coverage_forced_seed"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_97_none","some":"__js_option_97_some","isSome":"__js_option_97_is_some","unwrap":"__js_option_97_unwrap"}, item: { kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" } }, generatorConfig, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, requireStrategyPrereqs, wasm)), wasm);
  },
  minimalSeed(arg0, generatorConfig, requireStrategyPrereqs) {
    return liftValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, wasm["validate__GenInvalidAstParams__minimal_seed"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_97_none","some":"__js_option_97_some","isSome":"__js_option_97_is_some","unwrap":"__js_option_97_unwrap"}, item: { kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" } }, generatorConfig, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, requireStrategyPrereqs, wasm)), wasm);
  },
  naturalSeed(arg0, generatorConfig, requireStrategyPrereqs) {
    return liftValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, wasm["validate__GenInvalidAstParams__natural_seed"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_97_none","some":"__js_option_97_some","isSome":"__js_option_97_is_some","unwrap":"__js_option_97_unwrap"}, item: { kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" } }, generatorConfig, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, requireStrategyPrereqs, wasm)), wasm);
  },
  new(arg0, seedMode, generatorConfig, requireStrategyPrereqs) {
    return liftValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, wasm["validate__GenInvalidAstParams__new"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_98_none","some":"__js_option_98_some","isSome":"__js_option_98_is_some","unwrap":"__js_option_98_unwrap"}, item: { kind: "named", brand: "validate.GenInvalidSeedMode", showExport: null } }, seedMode, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_97_none","some":"__js_option_97_some","isSome":"__js_option_97_is_some","unwrap":"__js_option_97_unwrap"}, item: { kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" } }, generatorConfig, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, requireStrategyPrereqs, wasm)), wasm);
  },
  reproSeed(arg0, generatorConfig, requireStrategyPrereqs) {
    return liftValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, wasm["validate__GenInvalidAstParams__repro_seed"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_97_none","some":"__js_option_97_some","isSome":"__js_option_97_is_some","unwrap":"__js_option_97_unwrap"}, item: { kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" } }, generatorConfig, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, requireStrategyPrereqs, wasm)), wasm);
  },
  richSeed(arg0, generatorConfig, requireStrategyPrereqs) {
    return liftValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, wasm["validate__GenInvalidAstParams__rich_seed"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_97_none","some":"__js_option_97_some","isSome":"__js_option_97_is_some","unwrap":"__js_option_97_unwrap"}, item: { kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" } }, generatorConfig, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, requireStrategyPrereqs, wasm)), wasm);
  },
  smallCoverageForcedSeed(arg0, generatorConfig, requireStrategyPrereqs) {
    return liftValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, wasm["validate__GenInvalidAstParams__small_coverage_forced_seed"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_97_none","some":"__js_option_97_some","isSome":"__js_option_97_is_some","unwrap":"__js_option_97_unwrap"}, item: { kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" } }, generatorConfig, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, requireStrategyPrereqs, wasm)), wasm);
  },
  smallNaturalSeed(arg0, generatorConfig, requireStrategyPrereqs) {
    return liftValue({ kind: "named", brand: "validate.GenInvalidAstParams", showExport: null }, wasm["validate__GenInvalidAstParams__small_natural_seed"](lowerValue({ kind: "named", brand: "validate.ValidateInvalidAstStrategyId", showExport: null }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_97_none","some":"__js_option_97_some","isSome":"__js_option_97_is_some","unwrap":"__js_option_97_unwrap"}, item: { kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" } }, generatorConfig, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, requireStrategyPrereqs, wasm)), wasm);
  },
});

export const GenInvalidNamedSeedProfile = Object.freeze({
});

export const GenInvalidSeedMode = Object.freeze({
});

export const GenValidBudgetStop = Object.freeze({
});

export const GenValidConfig = Object.freeze({
  binaryenOracleCoverageForcedDefault() {
    return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__GenValidConfig__binaryen_oracle_coverage_forced_default"](), wasm);
  },
  coverageForcedDefault() {
    return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__GenValidConfig__coverage_forced_default"](), wasm);
  },
  forProfile(arg0) {
    return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__GenValidConfig__for_profile"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm)), wasm);
  },
  naturalDefault() {
    return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__GenValidConfig__natural_default"](), wasm);
  },
  portableCoverageForcedDefault() {
    return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__GenValidConfig__portable_coverage_forced_default"](), wasm);
  },
  profile(arg0) {
    return liftValue({ kind: "result", helper: {"isOk":"__js_result_44_is_ok","unwrapOk":"__js_result_44_unwrap_ok","unwrapErr":"__js_result_44_unwrap_err"}, ok: { kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, err: { kind: "string", moonType: "String" } }, wasm["validate__GenValidConfig__profile"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  watTextRoundtripDefault() {
    return liftValue({ kind: "named", brand: "validate.GenValidConfig", showExport: "__js_show_validate_GenValidConfig" }, wasm["validate__GenValidConfig__wat_text_roundtrip_default"](), wasm);
  },
  show(value) {
    return wasm["__js_show_validate_GenValidConfig"](lowerValue({ kind: "named", brand: "validate.GenValidConfig" }, value, wasm));
  },
});

export const GenValidConstExprAllowedOps = Object.freeze({
});

export const GenValidConstExprObservedOps = Object.freeze({
});

export const GenValidConstExprOpFamily = Object.freeze({
});

export const GenValidConstExprUse = Object.freeze({
});

export const GenValidContext = Object.freeze({
});

export const GenValidExactOpcodeCounts = Object.freeze({
  add(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.GenValidExactOpcodeCounts", showExport: "__js_show_validate_GenValidExactOpcodeCounts" }, wasm["validate__GenValidExactOpcodeCounts__add"](lowerValue({ kind: "named", brand: "validate.GenValidExactOpcodeCounts", showExport: "__js_show_validate_GenValidExactOpcodeCounts" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidExactOpcodeCounts", showExport: "__js_show_validate_GenValidExactOpcodeCounts" }, arg1, wasm)), wasm);
  },
  empty() {
    return liftValue({ kind: "named", brand: "validate.GenValidExactOpcodeCounts", showExport: "__js_show_validate_GenValidExactOpcodeCounts" }, wasm["validate__GenValidExactOpcodeCounts__empty"](), wasm);
  },
  show(value) {
    return wasm["__js_show_validate_GenValidExactOpcodeCounts"](lowerValue({ kind: "named", brand: "validate.GenValidExactOpcodeCounts" }, value, wasm));
  },
});

export const GenValidFailure = Object.freeze({
});

export const GenValidFeatureFacts = Object.freeze({
});

export const GenValidFeatureStats = Object.freeze({
  empty(arg0) {
    return liftValue({ kind: "named", brand: "validate.GenValidFeatureStats", showExport: "__js_show_validate_GenValidFeatureStats" }, wasm["validate__GenValidFeatureStats__empty"](lowerValue({ kind: "named", brand: "validate.GenValidMode", showExport: "__js_show_validate_GenValidMode" }, arg0, wasm)), wasm);
  },
  record(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.GenValidFeatureStats", showExport: "__js_show_validate_GenValidFeatureStats" }, wasm["validate__GenValidFeatureStats__record"](lowerValue({ kind: "named", brand: "validate.GenValidFeatureStats", showExport: "__js_show_validate_GenValidFeatureStats" }, arg0, wasm), lowerValue({ kind: "named", brand: "validate.GenValidFeatureFacts", showExport: null }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_validate_GenValidFeatureStats"](lowerValue({ kind: "named", brand: "validate.GenValidFeatureStats" }, value, wasm));
  },
});

export const GenValidFeatureToggles = Object.freeze({
  coverageForcedDefault() {
    return liftValue({ kind: "named", brand: "validate.GenValidFeatureToggles", showExport: "__js_show_validate_GenValidFeatureToggles" }, wasm["validate__GenValidFeatureToggles__coverage_forced_default"](), wasm);
  },
  naturalDefault() {
    return liftValue({ kind: "named", brand: "validate.GenValidFeatureToggles", showExport: "__js_show_validate_GenValidFeatureToggles" }, wasm["validate__GenValidFeatureToggles__natural_default"](), wasm);
  },
  show(value) {
    return wasm["__js_show_validate_GenValidFeatureToggles"](lowerValue({ kind: "named", brand: "validate.GenValidFeatureToggles" }, value, wasm));
  },
});

export const GenValidGenerated = Object.freeze({
});

export const GenValidMode = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_GenValidMode"](lowerValue({ kind: "named", brand: "validate.GenValidMode" }, value, wasm));
  },
});

export const GenValidModuleGenerated = Object.freeze({
});

export const GenValidProfile = Object.freeze({
});

export const GenValidProfileMember = Object.freeze({
  new(arg0, arg1) {
    return liftValue({ kind: "named", brand: "validate.GenValidProfileMember", showExport: null }, wasm["validate__GenValidProfileMember__new"](lowerValue({ kind: "named", brand: "validate.GenValidProfile", showExport: null }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm)), wasm);
  },
});

export const GenValidProposalFeature = Object.freeze({
});

export const GenValidProposalFeatureGateRow = Object.freeze({
});

export const GenValidRandomStreamLabel = Object.freeze({
});

export const GenValidSectionBias = Object.freeze({
  coverageForcedDefault() {
    return liftValue({ kind: "named", brand: "validate.GenValidSectionBias", showExport: "__js_show_validate_GenValidSectionBias" }, wasm["validate__GenValidSectionBias__coverage_forced_default"](), wasm);
  },
  naturalDefault() {
    return liftValue({ kind: "named", brand: "validate.GenValidSectionBias", showExport: "__js_show_validate_GenValidSectionBias" }, wasm["validate__GenValidSectionBias__natural_default"](), wasm);
  },
  show(value) {
    return wasm["__js_show_validate_GenValidSectionBias"](lowerValue({ kind: "named", brand: "validate.GenValidSectionBias" }, value, wasm));
  },
});

export const GenValidSsaFuncFacts = Object.freeze({
  empty() {
    return liftValue({ kind: "named", brand: "validate.GenValidSsaFuncFacts", showExport: null }, wasm["validate__GenValidSsaFuncFacts__empty"](), wasm);
  },
});

export const LabelStack = Object.freeze({
  copy(arg0) {
    return liftValue({ kind: "named", brand: "validate.LabelStack", showExport: "__js_show_validate_LabelStack" }, wasm["validate__LabelStack__copy"](lowerValue({ kind: "named", brand: "validate.LabelStack", showExport: "__js_show_validate_LabelStack" }, arg0, wasm)), wasm);
  },
  fromLabels(arg0) {
    return liftValue({ kind: "named", brand: "validate.LabelStack", showExport: "__js_show_validate_LabelStack" }, wasm["validate__LabelStack__from_labels"](lowerValue({ kind: "array", helper: {"new":"__js_array_62_new","push":"__js_array_62_push","length":"__js_array_62_length","get":"__js_array_62_get"}, item: { kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, arg0, wasm)), wasm);
  },
  get(arg0, arg1) {
    return liftValue({ kind: "option", helper: {"none":"__js_option_35_none","some":"__js_option_35_some","isSome":"__js_option_35_is_some","unwrap":"__js_option_35_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } } }, wasm["validate__LabelStack__get"](lowerValue({ kind: "named", brand: "validate.LabelStack", showExport: "__js_show_validate_LabelStack" }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm)), wasm);
  },
  length(arg0) {
    return liftValue({ kind: "number", moonType: "Int" }, wasm["validate__LabelStack__length"](lowerValue({ kind: "named", brand: "validate.LabelStack", showExport: "__js_show_validate_LabelStack" }, arg0, wasm)), wasm);
  },
  new() {
    return liftValue({ kind: "named", brand: "validate.LabelStack", showExport: "__js_show_validate_LabelStack" }, wasm["validate__LabelStack__new"](), wasm);
  },
  push(arg0, arg1) {
    return liftValue({ kind: "unit", moonType: "Unit" }, wasm["validate__LabelStack__push"](lowerValue({ kind: "named", brand: "validate.LabelStack", showExport: "__js_show_validate_LabelStack" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg1, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_validate_LabelStack"](lowerValue({ kind: "named", brand: "validate.LabelStack" }, value, wasm));
  },
});

export const LegacyCatchScope = Object.freeze({
});

export const ProposalFeature = Object.freeze({
});

export const TcEscape = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_TcEscape"](lowerValue({ kind: "named", brand: "validate.TcEscape" }, value, wasm));
  },
});

export const TcResult = Object.freeze({
});

export const TcState = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_TcState"](lowerValue({ kind: "named", brand: "validate.TcState" }, value, wasm));
  },
});

export const ValidateInvalidAstFuzzStats = Object.freeze({
});

export const ValidateInvalidAstMutation = Object.freeze({
});

export const ValidateInvalidAstRunConfig = Object.freeze({
});

export const ValidateInvalidAstSeedPrerequisite = Object.freeze({
});

export const ValidateInvalidAstStrategyId = Object.freeze({
});

export const ValidateInvalidAstStrategySpec = Object.freeze({
});

export const ValidateInvalidAstStrategyStats = Object.freeze({
});

export const ValidateValidFeatureFloor = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_ValidateValidFeatureFloor"](lowerValue({ kind: "named", brand: "validate.ValidateValidFeatureFloor" }, value, wasm));
  },
});

export const ValidateValidFeatureFloorFailure = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_ValidateValidFeatureFloorFailure"](lowerValue({ kind: "named", brand: "validate.ValidateValidFeatureFloorFailure" }, value, wasm));
  },
});

export const ValidateValidFeatureKey = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_ValidateValidFeatureKey"](lowerValue({ kind: "named", brand: "validate.ValidateValidFeatureKey" }, value, wasm));
  },
});

export const ValidateValidFeatureLedgerEntry = Object.freeze({
});

export const ValidateValidFeatureLedgerStatus = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_ValidateValidFeatureLedgerStatus"](lowerValue({ kind: "named", brand: "validate.ValidateValidFeatureLedgerStatus" }, value, wasm));
  },
});

export const ValidateValidFuzzStats = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_ValidateValidFuzzStats"](lowerValue({ kind: "named", brand: "validate.ValidateValidFuzzStats" }, value, wasm));
  },
});

export const ValidateValidRunConfig = Object.freeze({
});

export const ValidationDiagnostic = Object.freeze({
  new(arg0, funcIdx) {
    return liftValue({ kind: "named", brand: "validate.ValidationDiagnostic", showExport: "__js_show_validate_ValidationDiagnostic" }, wasm["validate__ValidationDiagnostic__new"](lowerValue({ kind: "named", brand: "validate.ValidationIssue", showExport: "__js_show_validate_ValidationIssue" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_99_none","some":"__js_option_99_some","isSome":"__js_option_99_is_some","unwrap":"__js_option_99_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_88_none","some":"__js_option_88_some","isSome":"__js_option_88_is_some","unwrap":"__js_option_88_unwrap"}, item: { kind: "named", brand: "lib.FuncIdx", showExport: "__js_show_lib_FuncIdx" } } }, funcIdx, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_validate_ValidationDiagnostic"](lowerValue({ kind: "named", brand: "validate.ValidationDiagnostic" }, value, wasm));
  },
});

export const ValidationError = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_ValidationError"](lowerValue({ kind: "named", brand: "validate.ValidationError" }, value, wasm));
  },
});

export const ValidationIssue = Object.freeze({
  show(value) {
    return wasm["__js_show_validate_ValidationIssue"](lowerValue({ kind: "named", brand: "validate.ValidationIssue" }, value, wasm));
  },
});

export const ValidationIssueFamily = Object.freeze({
});
