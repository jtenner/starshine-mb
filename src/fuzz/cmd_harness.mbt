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
fn run_fuzz_cmd_harness(
  valid_target : Int,
  seed : UInt64,
  optimize_passes? : Array[String] = [],
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
    let mod = gen_valid_module(rnd)
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
    match validate_module(roundtrip_mod) {
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
fn run_fuzz_cmd_harness_profile(
  profile : String,
  seed : UInt64,
) -> Result[Int, String] {
  let normalized = fuzz_cmd_harness_ascii_lower(profile.trim().to_owned())
  let valid_target = match normalized {
    "smoke" => 128
    "ci" => 4096
    "stress" => 100000
    _ =>
      return Err(
        "unknown cmd-harness fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  run_fuzz_cmd_harness(valid_target, seed, optimize_passes=[])
}
