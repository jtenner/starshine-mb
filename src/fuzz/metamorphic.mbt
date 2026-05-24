///|
pub enum MetamorphicValidTransform {
  AddNonNameCustomSection
  AddModuleNameSection
} derive(Eq, Debug)

///|
pub fn metamorphic_valid_transform_id(
  transform : MetamorphicValidTransform,
) -> String {
  match transform {
    AddNonNameCustomSection => "add-non-name-custom-section"
    AddModuleNameSection => "add-module-name-section"
  }
}

///|
pub struct MetamorphicValidTransformResult {
  transform_id : String
  wasm_module : @lib.Module
} derive(Eq, Debug)

///|
pub struct ValidateValidMetamorphicFuzzStats {
  profile : String
  attempts : Int
  generated : Int
  transformed : Int
  validated : Int
  transform_ids : Array[String]
} derive(Eq, Debug)

///|
fn metamorphic_add_non_name_custom_section(mod : @lib.Module) -> @lib.Module {
  let custom_secs = []
  for sec in mod.custom_secs {
    custom_secs.push(sec)
  }
  custom_secs.push(
    @lib.CustomSec::new(
      @lib.Name::from_string(
        "starshine.metamorphic.add-non-name-custom-section",
      ),
      b"semantics-preserving custom payload",
    ),
  )
  mod.with_custom_secs(custom_secs)
}

///|
fn metamorphic_add_module_name_section(mod : @lib.Module) -> @lib.Module {
  mod.with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("starshine.metamorphic.module")),
    ),
  )
}

///|
fn metamorphic_valid_transforms() -> Array[MetamorphicValidTransform] {
  [AddNonNameCustomSection, AddModuleNameSection]
}

///|
pub fn metamorphic_apply_transform(
  mod : @lib.Module,
  transform : MetamorphicValidTransform,
) -> Result[MetamorphicValidTransformResult, String] {
  let transformed = match transform {
    AddNonNameCustomSection => metamorphic_add_non_name_custom_section(mod)
    AddModuleNameSection => metamorphic_add_module_name_section(mod)
  }
  match validate_module(transformed) {
    Ok(_) =>
      Ok({
        transform_id: metamorphic_valid_transform_id(transform),
        wasm_module: transformed,
      })
    Err(err) =>
      Err(
        "metamorphic transform \{metamorphic_valid_transform_id(transform)} produced invalid module: \{validation_error_message(err)}",
      )
  }
}

///|
fn metamorphic_profile_config(
  profile : String,
) -> Result[GenValidConfig, String] {
  match profile {
    "smoke" | "ci" | "stress" => Ok(GenValidConfig::natural_default())
    _ => Err("unknown validate-valid-metamorphic profile: \{profile}")
  }
}

///|
fn metamorphic_profile_case_count(profile : String) -> Result[Int, String] {
  match profile {
    "smoke" => Ok(1)
    "ci" => Ok(10)
    "stress" => Ok(100)
    _ => Err("unknown validate-valid-metamorphic profile: \{profile}")
  }
}

///|
pub fn run_validate_valid_metamorphic_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[ValidateValidMetamorphicFuzzStats, String] {
  let config = match metamorphic_profile_config(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let case_count = match metamorphic_profile_case_count(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let transforms = metamorphic_valid_transforms()
  let transform_ids = transforms.map(metamorphic_valid_transform_id)
  let mut attempts = 0
  let mut generated_count = 0
  let mut transformed_count = 0
  let mut validated_count = 0
  let mut i = 0
  while i < case_count {
    let generated = match
      gen_valid_module_result_from_seed(seed ^ i.to_uint64(), config) {
      Ok(v) => v
      Err(e) =>
        return Err("GenValid source failed: \{e.validation_error_message}")
    }
    attempts += generated.attempts
    generated_count += 1
    for transform in transforms {
      match metamorphic_apply_transform(generated.wasm_module, transform) {
        Ok(_) => {
          transformed_count += 1
          validated_count += 1
        }
        Err(msg) => return Err(msg)
      }
    }
    i += 1
  }
  Ok({
    profile,
    attempts,
    generated: generated_count,
    transformed: transformed_count,
    validated: validated_count,
    transform_ids,
  })
}
