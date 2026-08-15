///|
fn component_bytes(input : FixedArray[Byte]) -> Bytes {
  Bytes::from_iter(input.iter())
}

///|
fn component_diagnostic(
  stage : DiagnosticStage,
  message : String,
) -> Diagnostic {
  { stage, message }
}

///|
fn component_decode(input : FixedArray[Byte]) -> Result[@lib.Module, Diagnostic] {
  match @binary.decode_module(component_bytes(input)) {
    Ok(mod) => Ok(mod)
    Err(err) => Err(component_diagnostic(DECODE, "\{err}"))
  }
}

///|
fn component_validate(mod : @lib.Module) -> Result[Unit, Diagnostic] {
  match @validate.validate_module(mod) {
    Ok(_) => Ok(())
    Err(err) => Err(component_diagnostic(VALIDATE, "\{err}"))
  }
}

///|
fn component_encode(mod : @lib.Module) -> Result[FixedArray[Byte], Diagnostic] {
  match @binary.encode_module(mod) {
    Ok(bytes) => Ok(bytes.to_fixedarray())
    Err(err) => Err(component_diagnostic(ENCODE, "\{err}"))
  }
}

///|
pub fn available_generator_profiles() -> Array[String] {
  @validate.gen_valid_profile_names()
}

///|
pub fn generate_valid_wasm(
  options : GenerationOptions,
) -> Result[GeneratedModule, Diagnostic] {
  let requested_profile = match
    @validate.gen_valid_profile_by_name(options.profile) {
    Ok(profile) => profile
    Err(err) => return Err(component_diagnostic(GENERATE, err))
  }
  let case_index = ((options.seed % 2147483646UL) + 1UL).to_int()
  let resolved_profile = @validate.gen_valid_profile_leaf_for_case(
    requested_profile,
    options.seed,
    case_index,
  )
  let profile_name = @validate.gen_valid_profile_name(resolved_profile)
  let config = @validate.GenValidConfig::for_profile(resolved_profile)
  let generated = match
    @validate.gen_valid_module_from_seed(options.seed, config) {
    Ok(generated) => generated
    Err(failure) =>
      return Err(
        component_diagnostic(
          GENERATE,
          "profile \{profile_name} failed after \{failure.attempts} attempts: \{failure.validation_error_message}",
        ),
      )
  }
  match component_encode(generated.wasm_module) {
    Ok(wasm) =>
      Ok({
        wasm,
        profile: profile_name,
        attempts: generated.attempts.reinterpret_as_uint(),
      })
    Err(err) => Err(err)
  }
}

///|
pub fn available_passes() -> Array[PassInfo] {
  let result : Array[PassInfo] = []
  for entry in @passes.pass_registry_all() {
    let kind = match entry.category {
      @passes.HotPassRegistryCategory::HotPass => Some(FUNCTION_PASS)
      @passes.HotPassRegistryCategory::ModulePass => Some(MODULE_PASS)
      @passes.HotPassRegistryCategory::Preset => Some(PRESET)
      @passes.HotPassRegistryCategory::BoundaryOnly |
      @passes.HotPassRegistryCategory::Removed => None
    }
    match kind {
      Some(kind) => result.push({ name: entry.name, summary: entry.summary, kind })
      None => ()
    }
  }
  result
}

///|
pub fn validate_wasm(input : FixedArray[Byte]) -> Result[Unit, Diagnostic] {
  let mod = match component_decode(input) {
    Ok(mod) => mod
    Err(err) => return Err(err)
  }
  component_validate(mod)
}

///|
pub fn roundtrip_wasm(
  input : FixedArray[Byte],
) -> Result[FixedArray[Byte], Diagnostic] {
  let mod = match component_decode(input) {
    Ok(mod) => mod
    Err(err) => return Err(err)
  }
  match component_validate(mod) {
    Ok(_) => component_encode(mod)
    Err(err) => Err(err)
  }
}

///|
pub fn wat_to_wasm(source : String) -> Result[FixedArray[Byte], Diagnostic] {
  let mod = match @wast.wast_to_binary_module(
    source,
    filename="component-input.wat",
  ) {
    Ok(mod) => mod
    Err(err) => return Err(component_diagnostic(PARSE, err))
  }
  match component_validate(mod) {
    Ok(_) => component_encode(mod)
    Err(err) => Err(err)
  }
}

///|
pub fn optimize_wasm(
  input : FixedArray[Byte],
  options : OptimizeOptions,
) -> Result[FixedArray[Byte], Diagnostic] {
  let mod = match component_decode(input) {
    Ok(mod) => mod
    Err(err) => return Err(err)
  }
  match component_validate(mod) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }

  let pipeline_options = @passes.HotPipelineOptions::new(
    validate_final_module=true,
    closed_world=options.closed_world,
    traps_never_happen=options.traps_never_happen,
    ignore_implicit_traps=options.ignore_implicit_traps,
    zero_filled_memory=options.zero_filled_memory,
    optimize_level=options.optimize_level.to_int(),
    shrink_level=options.shrink_level.to_int(),
  )
  let pass_names : Array[String] = match options.preset {
    NONE => []
    OPTIMIZE => @passes.optimize_preset_passes(pipeline_options)
    SHRINK => @passes.shrink_preset_passes(pipeline_options)
  }
  for pass_name in options.additional_passes {
    pass_names.push(pass_name)
  }

  let optimized = match @passes.run_hot_pipeline(
    mod,
    pipeline_options,
    pass_names,
  ) {
    Ok(mod) => mod
    Err(err) => return Err(component_diagnostic(OPTIMIZE, err))
  }
  component_encode(optimized)
}
