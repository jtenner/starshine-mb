///|
fn fuzz_cmd_harness_ascii_lower(input : String) -> String {
  let out = StringBuilder::new()
  for c in input {
    if c >= 'A' && c <= 'Z' {
      out.write_char((c.to_int() + 32).unsafe_to_char())
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn fuzz_cmd_harness_bytes_equal(lhs : Bytes, rhs : Bytes) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  let mut i = 0
  while i < lhs.length() {
    if lhs[i] != rhs[i] {
      return false
    }
    i += 1
  }
  true
}

///|
fn run_fuzz_cmd_harness(
  valid_target : Int,
  seed : UInt64,
  optimize_passes? : Array[String] = [],
  generator_config? : GenValidConfig = GenValidConfig::natural_default(),
  check_optimize_idempotence? : Bool = false,
  check_encode_decode_idempotence? : Bool = false,
) -> Result[Int, String] {
  if valid_target < 0 {
    return Err("valid_target must be non-negative")
  }
  let rnd = @splitmix.new(seed~)
  let mut attempts = 0
  let mut generated_valid = 0
  let mut generated_invalid = 0
  let max_attempts = if valid_target <= 0 { 0 } else { valid_target * 25 }

  while generated_valid < valid_target {
    if attempts >= max_attempts {
      return Err(
        "failed to reach valid target: target=\{valid_target} attempts=\{attempts} valid=\{generated_valid} invalid=\{generated_invalid}",
      )
    }
    attempts += 1
    let generated = match gen_valid_module_result(rnd, generator_config) {
      Ok(v) => v
      Err(_) => {
        generated_invalid += 1
        continue
      }
    }
    let mod = generated.wasm_module
    match validate_module(mod) {
      Ok(_) => ()
      Err(_) => {
        generated_invalid += 1
        continue
      }
    }
    let encoded = match encode_module(mod) {
      Ok(bytes) => bytes
      Err(_) => {
        generated_invalid += 1
        continue
      }
    }
    let decoded = match decode_module(encoded) {
      Ok(decoded_mod) => decoded_mod
      Err(e) => return Err("decode failed at attempt #\{attempts}: \{e}")
    }
    if check_encode_decode_idempotence {
      let recoded = match encode_module(decoded) {
        Ok(bytes) => bytes
        Err(e) =>
          return Err(
            "encode/decode idempotence encode failed at attempt #\{attempts}: \{e}",
          )
      }
      let recoded_mod = match decode_module(recoded) {
        Ok(v) => v
        Err(e) =>
          return Err(
            "encode/decode idempotence recode failed to decode at attempt #\{attempts}: \{e}",
          )
      }
      let recoded_again = match encode_module(recoded_mod) {
        Ok(bytes) => bytes
        Err(e) =>
          return Err(
            "encode/decode idempotence second encode failed at attempt #\{attempts}: \{e}",
          )
      }
      if !fuzz_cmd_harness_bytes_equal(recoded, recoded_again) {
        return Err(
          "encode/decode idempotence changed canonical bytes at attempt #\{attempts}",
        )
      }
    }
    match validate_module(decoded) {
      Ok(_) => ()
      Err(e) =>
        return Err(
          "decoded module failed validation at attempt #\{attempts}: \{e}",
        )
    }

    let optimized = match
      @passes.run_hot_pipeline(
        decoded,
        @passes.HotPipelineOptions::new(),
        optimize_passes,
      ) {
      Ok(v) => v
      Err(e) => return Err("optimize failed at attempt #\{attempts}: \{e}")
    }
    let roundtrip_bytes = match encode_module(optimized) {
      Ok(bytes) => bytes
      Err(e) =>
        return Err("post-opt encode failed at attempt #\{attempts}: \{e}")
    }
    let roundtrip_mod = match decode_module(roundtrip_bytes) {
      Ok(decoded_mod) => decoded_mod
      Err(e) =>
        return Err("post-opt decode failed at attempt #\{attempts}: \{e}")
    }
    if check_optimize_idempotence {
      let optimized_again = match
        @passes.run_hot_pipeline(
          roundtrip_mod,
          @passes.HotPipelineOptions::new(),
          optimize_passes,
        ) {
        Ok(v) => v
        Err(e) =>
          return Err(
            "optimize idempotence rerun failed at attempt #\{attempts}: \{e}",
          )
      }
      let optimized_again_bytes = match encode_module(optimized_again) {
        Ok(bytes) => bytes
        Err(e) =>
          return Err(
            "optimize idempotence encode failed at attempt #\{attempts}: \{e}",
          )
      }
      if !fuzz_cmd_harness_bytes_equal(roundtrip_bytes, optimized_again_bytes) {
        return Err("optimize idempotence changed bytes at attempt #\{attempts}")
      }
    }
    let roundtrip_validate_mod = match decode_module(roundtrip_bytes) {
      Ok(decoded_mod) => decoded_mod
      Err(e) =>
        return Err(
          "post-opt validation decode failed at attempt #\{attempts}: \{e}",
        )
    }
    match validate_module(roundtrip_validate_mod) {
      Ok(_) => generated_valid += 1
      Err(e) =>
        return Err(
          "roundtripped module failed validation at attempt #\{attempts}: \{e}",
        )
    }
  }
  Ok(attempts)
}

///|
fn fuzz_cmd_harness_has_prefix(text : String, prefix : String) -> Bool {
  if text.length() < prefix.length() {
    return false
  }
  text.sub(end=prefix.length()).to_owned() == prefix
}

///|
fn fuzz_cmd_harness_is_policy_pass(name : String) -> Bool {
  name == "no-inline" || name == "no-full-inline" || name == "no-partial-inline"
}

///|
fn fuzz_cmd_harness_each_pass_profile() -> Array[String] {
  let passes : Array[String] = []
  for entry in @passes.pass_registry_all() {
    match entry.category {
      @passes.HotPassRegistryCategory::HotPass
      | @passes.HotPassRegistryCategory::ModulePass =>
        if !fuzz_cmd_harness_is_policy_pass(entry.name) {
          passes.push(entry.name)
        }
      _ => ()
    }
  }
  passes
}

///|
fn fuzz_cmd_harness_default_pipeline_profile() -> Result[Array[String], String] {
  match @passes.pass_registry_lookup("optimize") {
    Some(entry) => Ok(entry.expanded_passes)
    None =>
      Err("cmd-harness default-pipeline profile could not find optimize preset")
  }
}

///|
fn fuzz_cmd_harness_common_cluster_profile() -> Array[String] {
  [
    "dead-code-elimination", "remove-unused-names", "remove-unused-brs", "vacuum",
    "merge-blocks", "remove-unused-brs", "vacuum",
  ]
}

///|
fn fuzz_cmd_harness_pass_profile(
  profile : String,
) -> Result[Array[String], String] {
  match profile {
    "none" => Ok([])
    "cleanup" => Ok(["vacuum", "remove-unused-brs"])
    "optimize-core" => Ok(["optimize-instructions", "precompute", "vacuum"])
    "each-pass" => Ok(fuzz_cmd_harness_each_pass_profile())
    "common-cluster" | "common-clusters" =>
      Ok(fuzz_cmd_harness_common_cluster_profile())
    "default-pipeline" => fuzz_cmd_harness_default_pipeline_profile()
    _ =>
      Err(
        "unknown cmd-harness pass profile '\{profile}'; expected none|cleanup|optimize-core|each-pass|common-clusters|default-pipeline",
      )
  }
}

///|
fn run_fuzz_cmd_harness_profile(
  profile : String,
  seed : UInt64,
) -> Result[Int, String] {
  let parts : Array[String] = []
  for part in profile.trim().to_owned().split("+") {
    parts.push(part.to_owned())
  }
  let normalized = if parts.length() == 0 ||
    parts[0].trim().to_owned().length() == 0 {
    "smoke"
  } else {
    fuzz_cmd_harness_ascii_lower(parts[0].trim().to_owned())
  }
  let valid_target = match normalized {
    "smoke" => 128
    "ci" => 4096
    "stress" => 100000
    _ =>
      return Err(
        "unknown cmd-harness fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  let mut generator_profile = "natural-wide"
  let mut pass_profile = "none"
  let mut check_optimize_idempotence = false
  let mut check_encode_decode_idempotence = false
  let mut i = 1
  while i < parts.length() {
    let part = fuzz_cmd_harness_ascii_lower(parts[i].trim().to_owned())
    if part.length() == 0 {
      ()
    } else if fuzz_cmd_harness_has_prefix(part, "gen=") {
      generator_profile = part.sub(start=4).to_owned()
    } else if fuzz_cmd_harness_has_prefix(part, "generator=") {
      generator_profile = part.sub(start=10).to_owned()
    } else if fuzz_cmd_harness_has_prefix(part, "passes=") {
      pass_profile = part.sub(start=7).to_owned()
    } else if part == "idempotence" || part == "opt-idempotence" {
      check_optimize_idempotence = true
    } else if part == "codec-idempotence" || part == "encode-decode-idempotence" {
      check_encode_decode_idempotence = true
    } else {
      return Err(
        "unknown cmd-harness profile modifier '\{parts[i]}' in '\{profile}'",
      )
    }
    i += 1
  }
  let generator_config = match GenValidConfig::profile(generator_profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let pass_profile = match pass_profile {
    "common-cluster" => "common-clusters"
    _ => pass_profile
  }
  let optimize_passes = match fuzz_cmd_harness_pass_profile(pass_profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  run_fuzz_cmd_harness(
    valid_target,
    seed,
    optimize_passes~,
    generator_config~,
    check_optimize_idempotence~,
    check_encode_decode_idempotence~,
  )
}
