///|
pub struct FuzzCmdHarnessFailureReport {
  seed : UInt64
  attempt : Int
  generated_valid : Int
  stage : String
  message : String
  generator_profile : String
  pass_profile : String
  optimize_passes : Array[String]
  minimized_passes : Array[String]
  original_wasm : Bytes
  first_output : Bytes
  second_output : Bytes
} derive(Eq, Debug)

///|
pub fn FuzzCmdHarnessFailureReport::new(
  seed : UInt64,
  attempt : Int,
  generated_valid : Int,
  stage : String,
  message : String,
  generator_profile : String,
  pass_profile : String,
  optimize_passes : Array[String],
  original_wasm : Bytes,
  first_output : Bytes,
  second_output : Bytes,
  minimized_passes? : Array[String] = optimize_passes,
) -> FuzzCmdHarnessFailureReport {
  {
    seed,
    attempt,
    generated_valid,
    stage,
    message,
    generator_profile,
    pass_profile,
    optimize_passes,
    minimized_passes,
    original_wasm,
    first_output,
    second_output,
  }
}

///|
fn fuzz_cmd_harness_failure_message(
  on_failure : ((FuzzCmdHarnessFailureReport) -> Result[Unit, String])?,
  report : FuzzCmdHarnessFailureReport,
) -> String {
  match on_failure {
    Some(callback) =>
      match callback(report) {
        Ok(_) => report.message
        Err(msg) => "\{report.message}; failure callback error: \{msg}"
      }
    None => report.message
  }
}

///|
fn fuzz_cmd_harness_without_pass_range(
  passes : Array[String],
  start : Int,
  len : Int,
) -> Array[String] {
  let out : Array[String] = []
  let end = start + len
  let mut idx = 0
  while idx < passes.length() {
    if idx < start || idx >= end {
      out.push(passes[idx])
    }
    idx += 1
  }
  out
}

///|
fn fuzz_cmd_harness_minimize_passes(
  passes : Array[String],
  reproduces : (Array[String]) -> Bool,
) -> Array[String] {
  let mut current = passes.copy()
  let mut chunk = if current.length() <= 1 {
    1
  } else {
    (current.length() + 1) / 2
  }
  while chunk >= 1 && current.length() > 0 {
    let mut reduced = false
    let mut start = 0
    while start < current.length() {
      let len = if start + chunk > current.length() {
        current.length() - start
      } else {
        chunk
      }
      let candidate = fuzz_cmd_harness_without_pass_range(current, start, len)
      if reproduces(candidate) {
        current = candidate
        reduced = true
        break
      }
      start += chunk
    }
    if !reduced {
      if chunk == 1 {
        break
      }
      chunk = (chunk + 1) / 2
    }
  }
  current
}

///|
fn fuzz_cmd_harness_optimizer_outputs(
  original_wasm : Bytes,
  passes : Array[String],
) -> (Bytes, Bytes)? {
  let first_input = match decode_module(original_wasm) {
    Ok(mod_) => mod_
    Err(_) => return None
  }
  let first_mod = match
    @passes.run_hot_pipeline(
      first_input,
      @passes.HotPipelineOptions::new(stack_function_passes=true),
      passes,
    ) {
    Ok(mod_) => mod_
    Err(_) => return None
  }
  let first = match encode_module(first_mod) {
    Ok(bytes) => bytes
    Err(_) => return None
  }
  let second_input = match decode_module(first) {
    Ok(mod_) => mod_
    Err(_) => return None
  }
  let second_mod = match
    @passes.run_hot_pipeline(
      second_input,
      @passes.HotPipelineOptions::new(stack_function_passes=true),
      passes,
    ) {
    Ok(mod_) => mod_
    Err(_) => return None
  }
  let second = match encode_module(second_mod) {
    Ok(bytes) => bytes
    Err(_) => return None
  }
  Some((first, second))
}

///|
fn fuzz_cmd_harness_minimize_optimizer_idempotence(
  original_wasm : Bytes,
  passes : Array[String],
) -> Array[String] {
  fuzz_cmd_harness_minimize_passes(passes, fn(candidate) {
    match fuzz_cmd_harness_optimizer_outputs(original_wasm, candidate) {
      Some((first, second)) => !fuzz_cmd_harness_bytes_equal(first, second)
      None => false
    }
  })
}

///|
fn fuzz_cmd_harness_minimize_optimizer_nondeterminism(
  original_wasm : Bytes,
  passes : Array[String],
) -> Array[String] {
  fuzz_cmd_harness_minimize_passes(passes, fn(candidate) {
    let left_input = match decode_module(original_wasm) {
      Ok(mod_) => mod_
      Err(_) => return false
    }
    let right_input = match decode_module(original_wasm) {
      Ok(mod_) => mod_
      Err(_) => return false
    }
    let left = match
      @passes.run_hot_pipeline(
        left_input,
        @passes.HotPipelineOptions::new(stack_function_passes=true),
        candidate,
      ) {
      Ok(mod_) => mod_
      Err(_) => return false
    }
    let right = match
      @passes.run_hot_pipeline(
        right_input,
        @passes.HotPipelineOptions::new(stack_function_passes=true),
        candidate,
      ) {
      Ok(mod_) => mod_
      Err(_) => return false
    }
    match (encode_module(left), encode_module(right)) {
      (Ok(left_bytes), Ok(right_bytes)) =>
        !fuzz_cmd_harness_bytes_equal(left_bytes, right_bytes)
      _ => false
    }
  })
}

///|
fn fuzz_cmd_harness_pass_flags_json(passes : Array[String]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < passes.length() {
    if i > 0 {
      out.write_string(",")
    }
    out.write_string("\"--\{fuzz_json_escape(passes[i])}\"")
    i += 1
  }
  out.to_string()
}

///|
pub fn persist_fuzz_cmd_harness_failure(
  report : FuzzCmdHarnessFailureReport,
  out_dir : String,
  io : FuzzRunOutputIO,
) -> Result[Unit, String] {
  let dir = out_dir.trim().to_owned()
  if dir.length() == 0 {
    return Err("cmd-harness failure output dir must not be empty")
  }
  match (io.ensure_dir)(dir) {
    Ok(_) => ()
    Err(msg) =>
      return Err("failed to create cmd-harness failure dir \{dir}: \{msg}")
  }
  let replay_passes = report.minimized_passes
  let metadata = "{\"schema\":\"starshine.optimizer-failure.v1\",\"status\":\"property-failure\",\"propertyFailureClass\":\"\{fuzz_json_escape(report.stage)}\",\"seed\":\{report.seed},\"attempt\":\{report.attempt},\"generatedValid\":\{report.generated_valid},\"message\":\"\{fuzz_json_escape(report.message)}\",\"generatorProfile\":\"\{fuzz_json_escape(report.generator_profile)}\",\"passProfile\":\"\{fuzz_json_escape(report.pass_profile)}\",\"originalPassFlags\":[\{fuzz_cmd_harness_pass_flags_json(report.optimize_passes)}],\"minimizedPassFlags\":[\{fuzz_cmd_harness_pass_flags_json(report.minimized_passes)}],\"replay\":{\"input\":\"input.wasm\",\"passFlags\":[\{fuzz_cmd_harness_pass_flags_json(replay_passes)}]},\"propertyEvidence\":{\"firstOutput\":\"optimized-once.wasm\",\"secondOutput\":\"optimized-twice.wasm\",\"serialPasses\":false}}"
  let writes = [
    ("failure-metadata.json", fuzz_string_to_bytes(metadata)),
    ("input.wasm", report.original_wasm),
    ("optimized-once.wasm", report.first_output),
    ("optimized-twice.wasm", report.second_output),
  ]
  for write in writes {
    let path = fuzz_join_path(dir, write.0)
    match (io.write_file)(path, write.1) {
      Ok(_) => ()
      Err(msg) =>
        return Err("failed to write cmd-harness failure \{path}: \{msg}")
    }
  }
  Ok(())
}

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
  check_optimizer_determinism? : Bool = false,
  generator_profile? : String = "natural-wide",
  pass_profile? : String = "custom",
  on_failure? : ((FuzzCmdHarnessFailureReport) -> Result[Unit, String])? = None,
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
        @passes.HotPipelineOptions::new(stack_function_passes=true),
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
    if check_optimizer_determinism {
      let second_input = match decode_module(encoded) {
        Ok(decoded_mod) => decoded_mod
        Err(e) =>
          return Err(
            "optimizer determinism second decode failed at attempt #\{attempts}: \{e}",
          )
      }
      let second_optimized = match
        @passes.run_hot_pipeline(
          second_input,
          @passes.HotPipelineOptions::new(stack_function_passes=true),
          optimize_passes,
        ) {
        Ok(v) => v
        Err(e) =>
          return Err(
            "optimizer determinism second run failed at attempt #\{attempts}: \{e}",
          )
      }
      let second_bytes = match encode_module(second_optimized) {
        Ok(bytes) => bytes
        Err(e) =>
          return Err(
            "optimizer determinism second encode failed at attempt #\{attempts}: \{e}",
          )
      }
      if !fuzz_cmd_harness_bytes_equal(roundtrip_bytes, second_bytes) {
        let message = "optimizer-nondeterminism at attempt #\{attempts}: fresh executions changed bytes"
        let original_passes = optimize_passes.copy()
        let minimized_passes = fuzz_cmd_harness_minimize_optimizer_nondeterminism(
          encoded, original_passes,
        )
        let report = FuzzCmdHarnessFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "optimizer-nondeterminism",
          message,
          generator_profile,
          pass_profile,
          original_passes,
          encoded,
          roundtrip_bytes,
          second_bytes,
          minimized_passes~,
        )
        return Err(fuzz_cmd_harness_failure_message(on_failure, report))
      }
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
          @passes.HotPipelineOptions::new(stack_function_passes=true),
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
        let message = "optimize idempotence changed bytes at attempt #\{attempts}"
        let original_passes = optimize_passes.copy()
        let minimized_passes = fuzz_cmd_harness_minimize_optimizer_idempotence(
          encoded, original_passes,
        )
        let report = FuzzCmdHarnessFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "optimizer-idempotence",
          message,
          generator_profile,
          pass_profile,
          original_passes,
          encoded,
          roundtrip_bytes,
          optimized_again_bytes,
          minimized_passes~,
        )
        return Err(fuzz_cmd_harness_failure_message(on_failure, report))
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
    "fixed-point-cleanup" =>
      Ok(@passes.pass_registry_fixed_point_cleanup_sequence())
    "default-pipeline" => fuzz_cmd_harness_default_pipeline_profile()
    _ =>
      Err(
        "unknown cmd-harness pass profile '\{profile}'; expected none|cleanup|optimize-core|each-pass|common-clusters|fixed-point-cleanup|default-pipeline",
      )
  }
}

///|
fn run_fuzz_cmd_harness_profile(
  profile : String,
  seed : UInt64,
  on_failure? : ((FuzzCmdHarnessFailureReport) -> Result[Unit, String])? = None,
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
  let mut check_optimizer_determinism = false
  let mut i = 1
  while i < parts.length() {
    let part = fuzz_cmd_harness_ascii_lower(parts[i].trim().to_owned())
    if part.length() == 0 {
      ()
    } else if fuzz_cmd_harness_has_prefix(part, "gen=") {
      generator_profile = part.sub(start=4).to_owned()
    } else if fuzz_cmd_harness_has_prefix(part, "gen-valid=") {
      generator_profile = part.sub(start=10).to_owned()
    } else if fuzz_cmd_harness_has_prefix(part, "generator=") {
      generator_profile = part.sub(start=10).to_owned()
    } else if fuzz_cmd_harness_has_prefix(part, "passes=") {
      pass_profile = part.sub(start=7).to_owned()
    } else if part == "idempotence" || part == "opt-idempotence" {
      check_optimize_idempotence = true
    } else if part == "codec-idempotence" || part == "encode-decode-idempotence" {
      check_encode_decode_idempotence = true
    } else if part == "determinism" || part == "optimizer-determinism" {
      check_optimizer_determinism = true
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
  let optimize_passes = if fuzz_cmd_harness_has_prefix(pass_profile, "random-") {
    let resolved = @passes.pass_registry_random_executable_sequence(
      pass_profile, seed,
    )
    if resolved.length() == 0 {
      return Err("unknown cmd-harness random pass profile '\{pass_profile}'")
    }
    resolved
  } else {
    match fuzz_cmd_harness_pass_profile(pass_profile) {
      Ok(v) => v
      Err(msg) => return Err(msg)
    }
  }
  run_fuzz_cmd_harness(
    valid_target,
    seed,
    optimize_passes~,
    generator_config~,
    check_optimize_idempotence~,
    check_encode_decode_idempotence~,
    check_optimizer_determinism~,
    generator_profile~,
    pass_profile~,
    on_failure~,
  )
}
