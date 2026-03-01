///|
pub fn __node_cli_parse_result_has_config_path(
  value : @cli.CliParseResult,
) -> Bool {
  match value.config_path {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_config_path(
  value : @cli.CliParseResult,
) -> String {
  match value.config_path {
    Some(path) => path
    None => abort("CliParseResult.config_path is None")
  }
}

///|
pub fn __node_cli_parse_result_input_globs_length(
  value : @cli.CliParseResult,
) -> Int {
  value.input_globs.length()
}

///|
pub fn __node_cli_parse_result_input_globs_get(
  value : @cli.CliParseResult,
  index : Int,
) -> String {
  value.input_globs[index]
}

///|
pub fn __node_cli_parse_result_help_requested(
  value : @cli.CliParseResult,
) -> Bool {
  value.help_requested
}

///|
pub fn __node_cli_parse_result_version_requested(
  value : @cli.CliParseResult,
) -> Bool {
  value.version_requested
}

///|
pub fn __node_cli_parse_result_read_stdin(value : @cli.CliParseResult) -> Bool {
  value.read_stdin
}

///|
pub fn __node_cli_parse_result_has_input_format(
  value : @cli.CliParseResult,
) -> Bool {
  match value.input_format {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_input_format(
  value : @cli.CliParseResult,
) -> @cli.CliInputFormat {
  match value.input_format {
    Some(format) => format
    None => abort("CliParseResult.input_format is None")
  }
}

///|
pub fn __node_cli_parse_result_output_targets_length(
  value : @cli.CliParseResult,
) -> Int {
  value.output_targets.length()
}

///|
pub fn __node_cli_parse_result_output_targets_get(
  value : @cli.CliParseResult,
  index : Int,
) -> @cli.CliOutputTarget {
  value.output_targets[index]
}

///|
pub fn __node_cli_parse_result_pass_flags_length(
  value : @cli.CliParseResult,
) -> Int {
  value.pass_flags.length()
}

///|
pub fn __node_cli_parse_result_pass_flags_get(
  value : @cli.CliParseResult,
  index : Int,
) -> String {
  value.pass_flags[index]
}

///|
pub fn __node_cli_parse_result_optimize_flags_length(
  value : @cli.CliParseResult,
) -> Int {
  value.optimize_flags.length()
}

///|
pub fn __node_cli_parse_result_optimize_flags_get(
  value : @cli.CliParseResult,
  index : Int,
) -> @cli.CliOptimizationFlag {
  value.optimize_flags[index]
}

///|
pub fn __node_cli_parse_result_has_trap_mode(
  value : @cli.CliParseResult,
) -> Bool {
  match value.trap_mode {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_trap_mode(
  value : @cli.CliParseResult,
) -> @cli.TrapMode {
  match value.trap_mode {
    Some(mode) => mode
    None => abort("CliParseResult.trap_mode is None")
  }
}

///|
pub fn __node_cli_parse_result_has_monomorphize_min_benefit(
  value : @cli.CliParseResult,
) -> Bool {
  match value.monomorphize_min_benefit {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_monomorphize_min_benefit(
  value : @cli.CliParseResult,
) -> Int {
  match value.monomorphize_min_benefit {
    Some(parsed_value) => parsed_value
    None => abort("CliParseResult.monomorphize_min_benefit is None")
  }
}

///|
pub fn __node_cli_parse_result_has_low_memory_unused(
  value : @cli.CliParseResult,
) -> Bool {
  match value.low_memory_unused {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_low_memory_unused(
  value : @cli.CliParseResult,
) -> Bool {
  match value.low_memory_unused {
    Some(parsed_value) => parsed_value
    None => abort("CliParseResult.low_memory_unused is None")
  }
}

///|
pub fn __node_cli_parse_result_has_low_memory_bound(
  value : @cli.CliParseResult,
) -> Bool {
  match value.low_memory_bound {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_low_memory_bound(
  value : @cli.CliParseResult,
) -> UInt64 {
  match value.low_memory_bound {
    Some(parsed_value) => parsed_value
    None => abort("CliParseResult.low_memory_bound is None")
  }
}

///|
pub fn __node_cli_input_format_name(value : @cli.CliInputFormat) -> String {
  match value {
    @cli.CliInputFormat::Wasm => "wasm"
    @cli.CliInputFormat::Wat => "wat"
    @cli.CliInputFormat::Wast => "wast"
  }
}

///|
pub fn __node_cli_output_target_kind(value : @cli.CliOutputTarget) -> String {
  match value {
    @cli.CliOutputTarget::StdoutOutput => "stdout"
    @cli.CliOutputTarget::FileOutput(_) => "file"
    @cli.CliOutputTarget::DirOutput(_) => "dir"
  }
}

///|
pub fn __node_cli_output_target_path(value : @cli.CliOutputTarget) -> String {
  match value {
    @cli.CliOutputTarget::StdoutOutput =>
      abort("CliOutputTarget.stdout has no path")
    @cli.CliOutputTarget::FileOutput(path) => path
    @cli.CliOutputTarget::DirOutput(path) => path
  }
}

///|
pub fn __node_cli_optimization_flag_kind(
  value : @cli.CliOptimizationFlag,
) -> String {
  match value {
    @cli.CliOptimizationFlag::OptimizePreset => "optimize"
    @cli.CliOptimizationFlag::ShrinkPreset => "shrink"
    @cli.CliOptimizationFlag::OLevel(_, _) => "olevel"
  }
}

///|
pub fn __node_cli_optimization_flag_level(
  value : @cli.CliOptimizationFlag,
) -> Int {
  match value {
    @cli.CliOptimizationFlag::OLevel(level, _) => level
    _ => abort("CliOptimizationFlag is not an OLevel variant")
  }
}

///|
pub fn __node_cli_optimization_flag_size_bias(
  value : @cli.CliOptimizationFlag,
) -> Bool {
  match value {
    @cli.CliOptimizationFlag::OLevel(_, size_bias) => size_bias
    _ => false
  }
}

///|
pub fn __node_cli_trap_mode_name(value : @cli.TrapMode) -> String {
  match value {
    @cli.TrapMode::Allow => "allow"
    @cli.TrapMode::Never => "never"
  }
}

///|
fn __node_cmd_effective_pass_flags(
  cli : @cli.CliParseResult,
  options : @passes.OptimizeOptions,
) -> Array[String] {
  let resolved = @cli.resolve_pass_flags(cli)
  let out : Array[String] = []
  for pass in resolved {
    out.push(pass)
  }
  if out.length() > 0 {
    return out
  }
  if options.shrink_level > 0 {
    out.push("shrink")
  } else if options.optimize_level > 0 {
    out.push("optimize")
  }
  out
}

///|
fn __node_cmd_max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn __node_cmd_shrink_options(
  options : @passes.OptimizeOptions,
) -> @passes.OptimizeOptions {
  @passes.OptimizeOptions::new(
    optimize_level=options.optimize_level,
    shrink_level=__node_cmd_max_int(options.shrink_level, 2),
    inlining=options.inlining,
    monomorphize_min_benefit=options.monomorphize_min_benefit,
    low_memory_unused=options.low_memory_unused,
    low_memory_bound=options.low_memory_bound,
    traps_never_happen=options.traps_never_happen,
  )
}

///|
fn __node_cmd_resolve_explicit_pass(flag : String) -> @passes.ModulePass? {
  match flag {
    "alignment-lowering" => Some(@passes.ModulePass::AlignmentLowering)
    "avoid-reinterprets" => Some(@passes.ModulePass::AvoidReinterprets)
    "coalesce-locals" => Some(@passes.ModulePass::CoalesceLocals)
    "code-folding" => Some(@passes.ModulePass::CodeFolding)
    "code-pushing" => Some(@passes.ModulePass::CodePushing)
    "const-hoisting" => Some(@passes.ModulePass::ConstHoisting)
    "constant-field-propagation" =>
      Some(@passes.ModulePass::ConstantFieldPropagation)
    "dataflow-optimization" => Some(@passes.ModulePass::DataflowOptimization)
    "dead-code-elimination" => Some(@passes.ModulePass::DeadCodeElimination)
    "dead-argument-elimination" =>
      Some(@passes.ModulePass::DeadArgumentElimination)
    "dead-argument-elimination-optimizing" =>
      Some(@passes.ModulePass::DeadArgumentEliminationOptimizing)
    "signature-pruning" => Some(@passes.ModulePass::SignaturePruning)
    "signature-refining" => Some(@passes.ModulePass::SignatureRefining)
    "duplicate-import-elimination" =>
      Some(@passes.ModulePass::DuplicateImportElimination)
    "global-refining" => Some(@passes.ModulePass::GlobalRefining)
    "global-struct-inference" => Some(@passes.ModulePass::GlobalStructInference)
    "global-struct-inference-desc-cast" =>
      Some(@passes.ModulePass::GlobalStructInferenceDescCast)
    "global-type-optimization" =>
      Some(@passes.ModulePass::GlobalTypeOptimization)
    "simplify-globals" => Some(@passes.ModulePass::SimplifyGlobals)
    "simplify-globals-optimizing" =>
      Some(@passes.ModulePass::SimplifyGlobalsOptimizing)
    "global-effects" => Some(@passes.ModulePass::GlobalEffects)
    "propagate-globals-globally" =>
      Some(@passes.ModulePass::PropagateGlobalsGlobally)
    "type-refining" => Some(@passes.ModulePass::TypeRefining)
    "type-generalizing" => Some(@passes.ModulePass::TypeGeneralizing)
    "type-finalizing" => Some(@passes.ModulePass::TypeFinalizing)
    "type-un-finalizing" => Some(@passes.ModulePass::TypeUnFinalizing)
    "unsubtyping" => Some(@passes.ModulePass::Unsubtyping)
    "heap2local" => Some(@passes.ModulePass::Heap2Local)
    "heap-store-optimization" => Some(@passes.ModulePass::HeapStoreOptimization)
    "inlining" => Some(@passes.ModulePass::Inlining)
    "inlining-optimizing" => Some(@passes.ModulePass::InliningOptimizing)
    "inline-main" => Some(@passes.ModulePass::InlineMain)
    "local-cse" => Some(@passes.ModulePass::LocalCSE)
    "local-subtyping" => Some(@passes.ModulePass::LocalSubtyping)
    "loop-invariant-code-motion" =>
      Some(@passes.ModulePass::LoopInvariantCodeMotion)
    "merge-locals" => Some(@passes.ModulePass::MergeLocals)
    "merge-similar-functions" => Some(@passes.ModulePass::MergeSimilarFunctions)
    "merge-blocks" => Some(@passes.ModulePass::MergeBlocks)
    "flatten" => Some(@passes.ModulePass::Flatten)
    "re-reloop" => Some(@passes.ModulePass::ReReloop)
    "tuple-optimization" => Some(@passes.ModulePass::TupleOptimization)
    "once-reduction" => Some(@passes.ModulePass::OnceReduction)
    "minimize-rec-groups" => Some(@passes.ModulePass::MinimizeRecGroups)
    "type-merging" => Some(@passes.ModulePass::TypeMerging)
    "monomorphize" => Some(@passes.ModulePass::Monomorphize)
    "monomorphize-always" => Some(@passes.ModulePass::MonomorphizeAlways)
    "optimize-added-constants" =>
      Some(@passes.ModulePass::OptimizeAddedConstants)
    "optimize-added-constants-propagate" =>
      Some(@passes.ModulePass::OptimizeAddedConstantsPropagate)
    "optimize-instructions" => Some(@passes.ModulePass::OptimizeInstructions)
    "precompute" => Some(@passes.ModulePass::Precompute)
    "precompute-propagate" => Some(@passes.ModulePass::PrecomputePropagate)
    "redundant-set-elimination" =>
      Some(@passes.ModulePass::RedundantSetElimination)
    "pick-load-signs" => Some(@passes.ModulePass::PickLoadSigns)
    "gufa" => Some(@passes.ModulePass::GUFA)
    "gufa-optimizing" => Some(@passes.ModulePass::GUFAOptimizing)
    "gufa-cast-all" => Some(@passes.ModulePass::GUFACastAll)
    "i64-to-i32-lowering" => Some(@passes.ModulePass::I64ToI32Lowering)
    "duplicate-function-elimination" =>
      Some(@passes.ModulePass::DuplicateFunctionElimination)
    "optimize-casts" => Some(@passes.ModulePass::OptimizeCasts)
    "de-nan" => Some(@passes.ModulePass::DeNaN)
    "remove-unused-brs" => Some(@passes.ModulePass::RemoveUnusedBrs)
    "remove-unused-names" => Some(@passes.ModulePass::RemoveUnusedNames)
    "simplify-locals" => Some(@passes.ModulePass::SimplifyLocals)
    "simplify-locals-no-tee" => Some(@passes.ModulePass::SimplifyLocalsNoTee)
    "simplify-locals-no-structure" =>
      Some(@passes.ModulePass::SimplifyLocalsNoStructure)
    "simplify-locals-no-tee-no-structure" =>
      Some(@passes.ModulePass::SimplifyLocalsNoTeeNoStructure)
    "simplify-locals-no-nesting" =>
      Some(@passes.ModulePass::SimplifyLocalsNoNesting)
    "untee" => Some(@passes.ModulePass::Untee)
    "vacuum" => Some(@passes.ModulePass::Vacuum)
    "reorder-locals" => Some(@passes.ModulePass::ReorderLocals)
    "reorder-types" => Some(@passes.ModulePass::ReorderTypes)
    "reorder-globals" => Some(@passes.ModulePass::ReorderGlobals)
    "reorder-globals-always" => Some(@passes.ModulePass::ReorderGlobalsAlways)
    "reorder-functions" => Some(@passes.ModulePass::ReorderFunctions)
    "reorder-functions-by-name" =>
      Some(@passes.ModulePass::ReorderFunctionsByName)
    "remove-unused-types" => Some(@passes.ModulePass::RemoveUnusedTypes)
    "remove-unused" => Some(@passes.ModulePass::RemoveUnused)
    "remove-unused-module-elements" =>
      Some(@passes.ModulePass::RemoveUnusedModuleElements)
    "remove-unused-non-function-elements" =>
      Some(@passes.ModulePass::RemoveUnusedNonFunctionElements)
    _ => None
  }
}

///|
pub fn __node_passes_can_resolve_module_pass(name : String) -> Bool {
  match __node_cmd_resolve_explicit_pass(name) {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_passes_resolve_module_pass_error(name : String) -> String {
  match __node_cmd_resolve_explicit_pass(name) {
    Some(_) => ""
    None => "unknown module pass: \{name}"
  }
}

///|
pub fn __node_passes_resolve_module_pass(name : String) -> @passes.ModulePass {
  match __node_cmd_resolve_explicit_pass(name) {
    Some(pass) => pass
    None => abort("unknown module pass: \{name}")
  }
}

///|
pub fn __node_passes_directize(always : Bool) -> @passes.ModulePass {
  @passes.ModulePass::Directize(always)
}

///|
pub fn __node_passes_optimize_module_with_options_trace_run(
  mod : @lib.Module,
  passes : Array[@passes.ModulePass],
  options : @passes.OptimizeOptions,
  trace_pass_details? : Bool = true,
  trace_module_stats? : Bool = true,
) -> (Result[@lib.Module, String], Array[String]) {
  let trace_logs : Array[String] = []
  let result = @passes.optimize_module_with_options_trace(
    mod,
    passes,
    options,
    fn(msg) { trace_logs.push(msg) },
    trace_pass_details~,
    trace_module_stats~,
  )
  (result, trace_logs)
}

///|
pub fn __node_passes_optimize_trace_run_logs_length(
  value : (Result[@lib.Module, String], Array[String]),
) -> Int {
  value.1.length()
}

///|
pub fn __node_passes_optimize_trace_run_logs_get(
  value : (Result[@lib.Module, String], Array[String]),
  index : Int,
) -> String {
  value.1[index]
}

///|
pub fn __node_passes_optimize_trace_run_result_is_ok(
  value : (Result[@lib.Module, String], Array[String]),
) -> Bool {
  match value.0 {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __node_passes_optimize_trace_run_result_value(
  value : (Result[@lib.Module, String], Array[String]),
) -> @lib.Module {
  match value.0 {
    Ok(mod) => mod
    Err(_) => abort("optimize trace run result is Err")
  }
}

///|
pub fn __node_passes_optimize_trace_run_result_error(
  value : (Result[@lib.Module, String], Array[String]),
) -> String {
  match value.0 {
    Ok(_) => abort("optimize trace run result is Ok")
    Err(err) => err
  }
}

///|
fn __node_cmd_expand_passes_for_cli_impl(
  cli : @cli.CliParseResult,
  mod : @lib.Module,
  options : @passes.OptimizeOptions,
) -> Result[Array[@passes.ModulePass], String] {
  let pass_flags = __node_cmd_effective_pass_flags(cli, options)
  let max_vacuum_passes = 4
  let mut vacuum_passes = 0
  let out : Array[@passes.ModulePass] = []
  let push_pass = fn(pass : @passes.ModulePass) {
    match pass {
      @passes.ModulePass::Vacuum =>
        if vacuum_passes < max_vacuum_passes {
          out.push(pass)
          vacuum_passes += 1
        }
      _ => out.push(pass)
    }
  }
  for flag in pass_flags {
    match flag {
      "optimize" => {
        for pass in @passes.default_global_optimization_pre_passes(mod, options) {
          push_pass(pass)
        }
        for pass in @passes.default_function_optimization_passes(mod, options) {
          push_pass(pass)
        }
        for
          pass in @passes.default_global_optimization_post_passes(mod, options) {
          push_pass(pass)
        }
      }
      "shrink" => {
        let shrink_options = __node_cmd_shrink_options(options)
        for
          pass in @passes.default_global_optimization_pre_passes(
            mod, shrink_options,
          ) {
          push_pass(pass)
        }
        for
          pass in @passes.default_function_optimization_passes(
            mod, shrink_options,
          ) {
          push_pass(pass)
        }
        for
          pass in @passes.default_global_optimization_post_passes(
            mod, shrink_options,
          ) {
          push_pass(pass)
        }
      }
      _ =>
        match __node_cmd_resolve_explicit_pass(flag) {
          Some(pass) => push_pass(pass)
          None => return Err("unknown pass flag: \{flag}")
        }
    }
  }
  Ok(out)
}

///|
pub fn __node_cmd_can_expand_passes_for_cli(
  cli : @cli.CliParseResult,
  mod : @lib.Module,
  options : @passes.OptimizeOptions,
) -> Bool {
  match __node_cmd_expand_passes_for_cli_impl(cli, mod, options) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __node_cmd_expand_passes_for_cli_error(
  cli : @cli.CliParseResult,
  mod : @lib.Module,
  options : @passes.OptimizeOptions,
) -> String {
  match __node_cmd_expand_passes_for_cli_impl(cli, mod, options) {
    Ok(_) => ""
    Err(err) => err
  }
}

///|
pub fn __node_cmd_expand_passes_for_cli_length(
  cli : @cli.CliParseResult,
  mod : @lib.Module,
  options : @passes.OptimizeOptions,
) -> Int {
  match __node_cmd_expand_passes_for_cli_impl(cli, mod, options) {
    Ok(passes) => passes.length()
    Err(_) => 0
  }
}

///|
pub fn __node_cmd_expand_passes_for_cli_get(
  cli : @cli.CliParseResult,
  mod : @lib.Module,
  options : @passes.OptimizeOptions,
  index : Int,
) -> @passes.ModulePass {
  match __node_cmd_expand_passes_for_cli_impl(cli, mod, options) {
    Ok(passes) => passes[index]
    Err(err) => abort(err)
  }
}

///|
pub fn __node_wast_spec_run_summary_total_files(
  value : @wast.WastSpecRunSummary,
) -> Int {
  value.total_files
}

///|
pub fn __node_wast_spec_run_summary_passed_files(
  value : @wast.WastSpecRunSummary,
) -> Int {
  value.passed_files
}

///|
pub fn __node_wast_spec_run_summary_skipped_files(
  value : @wast.WastSpecRunSummary,
) -> Int {
  value.skipped_files
}

///|
pub fn __node_wast_spec_run_summary_failed_files(
  value : @wast.WastSpecRunSummary,
) -> Int {
  value.failed_files
}

///|
pub fn __node_wast_spec_run_summary_files_length(
  value : @wast.WastSpecRunSummary,
) -> Int {
  value.files.length()
}

///|
pub fn __node_wast_spec_run_summary_files_get(
  value : @wast.WastSpecRunSummary,
  index : Int,
) -> @wast.WastSpecFileReport {
  value.files[index]
}

///|
pub fn __node_wast_spec_file_report_path(
  value : @wast.WastSpecFileReport,
) -> String {
  value.path
}

///|
pub fn __node_wast_spec_file_report_status(
  value : @wast.WastSpecFileReport,
) -> @wast.WastSpecFileStatus {
  value.status
}

///|
pub fn __node_wast_spec_file_status_kind(
  value : @wast.WastSpecFileStatus,
) -> String {
  match value {
    @wast.WastSpecFileStatus::Passed => "passed"
    @wast.WastSpecFileStatus::Skipped(_) => "skipped"
    @wast.WastSpecFileStatus::Failed(_) => "failed"
  }
}

///|
pub fn __node_wast_spec_file_status_message(
  value : @wast.WastSpecFileStatus,
) -> String {
  match value {
    @wast.WastSpecFileStatus::Passed => ""
    @wast.WastSpecFileStatus::Skipped(msg) => msg
    @wast.WastSpecFileStatus::Failed(msg) => msg
  }
}

///|
pub fn __node_splitmix_new(seed : UInt64) -> @splitmix.RandomState {
  @splitmix.new(seed~)
}
