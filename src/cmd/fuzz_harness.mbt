///|
pub struct DifferentialAdapters {
  wasm_tools_validate : (Bytes) -> Result[Bool, String]
  binaryen_validate : (Bytes) -> Result[Bool, String]
}

///|
pub fn DifferentialAdapters::new(
  wasm_tools_validate? : (Bytes) -> Result[Bool, String] = fn(_) {
    Err("wasm-tools differential validator unavailable")
  },
  binaryen_validate? : (Bytes) -> Result[Bool, String] = fn(_) {
    Err("binaryen differential validator unavailable")
  },
) -> DifferentialAdapters {
  { wasm_tools_validate, binaryen_validate }
}

///|
pub struct DifferentialValidationReport {
  internal_valid : Bool
  wasm_tools_valid : Bool?
  binaryen_valid : Bool?
} derive(Eq, Show, Debug)

///|
pub struct WasmSmithFuzzStats {
  attempts : Int
  generated_valid : Int
  generated_invalid : Int
  pipeline_validated : Int
  optimized : Int
  roundtripped : Int
  differential_checked : Int
} derive(Eq, Show, Debug)

///|
pub fn WasmSmithFuzzStats::new(
  attempts? : Int = 0,
  generated_valid? : Int = 0,
  generated_invalid? : Int = 0,
  pipeline_validated? : Int = 0,
  optimized? : Int = 0,
  roundtripped? : Int = 0,
  differential_checked? : Int = 0,
) -> WasmSmithFuzzStats {
  {
    attempts,
    generated_valid,
    generated_invalid,
    pipeline_validated,
    optimized,
    roundtripped,
    differential_checked,
  }
}

///|
pub struct FuzzFailureReport {
  seed : UInt64
  attempt : Int
  generated_valid : Int
  stage : String
  message : String
  optimize_passes : Array[String]
  minimized_passes : Array[String]
  wasm : Bytes?
} derive(Eq, Show, Debug)

///|
pub fn FuzzFailureReport::new(
  seed : UInt64,
  attempt : Int,
  generated_valid : Int,
  stage : String,
  message : String,
  optimize_passes? : Array[String] = [],
  minimized_passes? : Array[String] = [],
  wasm? : Bytes? = None,
) -> FuzzFailureReport {
  {
    seed,
    attempt,
    generated_valid,
    stage,
    message,
    optimize_passes,
    minimized_passes,
    wasm,
  }
}

///|
pub struct FuzzFailurePersistIO {
  ensure_dir : (String) -> Result[Unit, String]
  write_file : (String, Bytes) -> Result[Unit, String]
}

///|
pub fn FuzzFailurePersistIO::new(
  ensure_dir? : (String) -> Result[Unit, String] = fn(path) {
    Err("ensure_dir not configured: \{path}")
  },
  write_file? : (String, Bytes) -> Result[Unit, String] = fn(path, _) {
    Err("write_file not configured: \{path}")
  },
) -> FuzzFailurePersistIO {
  { ensure_dir, write_file }
}

///|
fn fuzz_clone_passes(values : Array[String]) -> Array[String] {
  let out = Array::new(capacity=values.length())
  for value in values {
    out.push(value)
  }
  out
}

///|
fn fuzz_without_pass_index(values : Array[String], skip : Int) -> Array[String] {
  let out = Array::new(capacity=values.length())
  let mut i = 0
  while i < values.length() {
    if i != skip {
      out.push(values[i])
    }
    i += 1
  }
  out
}

///|
pub fn minimize_fuzz_passes(
  passes : Array[String],
  reproduces : (Array[String]) -> Bool,
) -> Array[String] {
  if !reproduces(passes) {
    return fuzz_clone_passes(passes)
  }
  let mut current = fuzz_clone_passes(passes)
  let mut i = 0
  while i < current.length() {
    let candidate = fuzz_without_pass_index(current, i)
    if reproduces(candidate) {
      current = candidate
    } else {
      i += 1
    }
  }
  current
}

///|
fn fuzz_has_prefix(text : String, prefix : String) -> Bool {
  if text.length() < prefix.length() {
    return false
  }
  let head = text.sub(end=prefix.length()).to_string() catch { _ => "" }
  head == prefix
}

///|
fn fuzz_has_suffix(text : String, suffix : String) -> Bool {
  if text.length() < suffix.length() {
    return false
  }
  let start = text.length() - suffix.length()
  let tail = text.sub(start~).to_string() catch { _ => "" }
  tail == suffix
}

///|
fn fuzz_bytes_from_string(text : String) -> Bytes {
  let buf = @buffer.new(size_hint=text.length())
  for c in text {
    buf.write_byte(c.to_int().to_byte())
  }
  buf.to_bytes()
}

///|
fn fuzz_single_line(text : String) -> String {
  let out = StringBuilder::new()
  for c in text {
    if c == '\n' || c == '\r' {
      out.write_char(' ')
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn fuzz_join_csv(values : Array[String]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < values.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string(values[i])
    i += 1
  }
  out.to_string()
}

///|
fn fuzz_slug(value : String) -> String {
  let out = StringBuilder::new()
  let mut wrote_dash = false
  for c in value {
    let lower = if c >= 'A' && c <= 'Z' {
      (c.to_int() + 32).unsafe_to_char()
    } else {
      c
    }
    let is_alnum = (lower >= 'a' && lower <= 'z') ||
      (lower >= '0' && lower <= '9')
    if is_alnum {
      out.write_char(lower)
      wrote_dash = false
    } else if !wrote_dash {
      out.write_char('-')
      wrote_dash = true
    }
  }
  let raw = out.to_string()
  let trimmed = if fuzz_has_prefix(raw, "-") {
    raw.sub(start=1).to_string() catch {
      _ => raw
    }
  } else {
    raw
  }
  let cleaned = if fuzz_has_suffix(trimmed, "-") {
    trimmed.sub(end=trimmed.length() - 1).to_string() catch {
      _ => trimmed
    }
  } else {
    trimmed
  }
  if cleaned.length() == 0 {
    "unknown"
  } else {
    cleaned
  }
}

///|
fn fuzz_failure_meta_text(report : FuzzFailureReport) -> String {
  let out = StringBuilder::new()
  out.write_string("seed=\{report.seed}\n")
  out.write_string("attempt=\{report.attempt}\n")
  out.write_string("generated_valid=\{report.generated_valid}\n")
  out.write_string("stage=\{fuzz_single_line(report.stage)}\n")
  out.write_string("message=\{fuzz_single_line(report.message)}\n")
  out.write_string("optimize_passes=\{fuzz_join_csv(report.optimize_passes)}\n")
  out.write_string(
    "minimized_passes=\{fuzz_join_csv(report.minimized_passes)}\n",
  )
  out.to_string()
}

///|
pub fn persist_fuzz_failure_report(
  report : FuzzFailureReport,
  io : FuzzFailurePersistIO,
  corpus_dir? : String = "fuzz-corpus",
) -> Result[(String, String?), String] {
  let trimmed = corpus_dir.trim().to_string()
  let dir = if trimmed.length() == 0 { "fuzz-corpus" } else { trimmed }
  match (io.ensure_dir)(dir) {
    Ok(_) => ()
    Err(e) => return Err("failed to ensure corpus dir \{dir}: \{e}")
  }
  let slug = fuzz_slug(report.stage)
  let prefix = "\{dir}/seed-\{report.seed}-attempt-\{report.attempt}-valid-\{report.generated_valid}-\{slug}"
  let meta_path = "\{prefix}.meta.txt"
  let meta_bytes = fuzz_bytes_from_string(fuzz_failure_meta_text(report))
  match (io.write_file)(meta_path, meta_bytes) {
    Ok(_) => ()
    Err(e) => return Err("failed to write corpus metadata \{meta_path}: \{e}")
  }
  let wasm_path = match report.wasm {
    Some(bytes) => {
      let path = "\{prefix}.wasm"
      match (io.write_file)(path, bytes) {
        Ok(_) => Some(path)
        Err(e) => return Err("failed to write corpus wasm \{path}: \{e}")
      }
    }
    None => None
  }
  Ok((meta_path, wasm_path))
}

///|
fn fuzz_default_pass_names(
  optimize_passes : Array[ModulePass],
) -> Array[String] {
  let out = Array::new(capacity=optimize_passes.length())
  let mut i = 0
  while i < optimize_passes.length() {
    out.push("pass-\{i}")
    i += 1
  }
  out
}

///|
fn fuzz_finalize_failure(
  on_failure : ((FuzzFailureReport) -> Result[Unit, String])?,
  report : FuzzFailureReport,
  message : String,
) -> String {
  match on_failure {
    Some(cb) =>
      match cb(report) {
        Ok(_) => message
        Err(e) => "\{message}; failure callback error: \{e}"
      }
    None => message
  }
}

///|
fn decode_then_validate(bytes : Bytes) -> Result[Bool, String] {
  match decode_module(bytes) {
    Ok(mod) =>
      match validate_module(mod) {
        Ok(_) => Ok(true)
        Err(_) => Ok(false)
      }
    Err(_) => Ok(false)
  }
}

///|
pub fn differential_validate_wasm(
  bytes : Bytes,
  adapters? : DifferentialAdapters = default_differential_adapters(),
) -> Result[DifferentialValidationReport, String] {
  let internal_valid = match decode_then_validate(bytes) {
    Ok(v) => v
    Err(e) => return Err("internal validation execution failed: \{e}")
  }
  let wasm_tools_valid = match (adapters.wasm_tools_validate)(bytes) {
    Ok(v) => Some(v)
    Err(_) => None
  }
  let binaryen_valid = match (adapters.binaryen_validate)(bytes) {
    Ok(v) => Some(v)
    Err(_) => None
  }

  match wasm_tools_valid {
    Some(v) =>
      if v != internal_valid {
        return Err(
          "differential mismatch against wasm-tools: internal=\{internal_valid} wasm-tools=\{v}",
        )
      }
    None => ()
  }
  match binaryen_valid {
    Some(v) =>
      if v != internal_valid {
        return Err(
          "differential mismatch against binaryen: internal=\{internal_valid} binaryen=\{v}",
        )
      }
    None => ()
  }
  Ok(DifferentialValidationReport::{
    internal_valid,
    wasm_tools_valid,
    binaryen_valid,
  })
}

///|
pub fn run_wasm_smith_fuzz_harness(
  valid_target : Int,
  seed? : UInt64 = 0x5eedUL,
  optimize_passes? : Array[ModulePass] = [],
  optimize_pass_names? : Array[String]? = None,
  differential_adapters? : DifferentialAdapters? = None,
  differential_every? : Int = 0,
  on_failure? : ((FuzzFailureReport) -> Result[Unit, String])? = None,
) -> Result[WasmSmithFuzzStats, String] {
  let pass_names = match optimize_pass_names {
    Some(v) => fuzz_clone_passes(v)
    None => fuzz_default_pass_names(optimize_passes)
  }
  if valid_target < 0 {
    let report = FuzzFailureReport::new(
      seed,
      0,
      0,
      "config",
      "valid_target must be non-negative",
      optimize_passes=pass_names,
      minimized_passes=pass_names,
    )
    return Err(
      fuzz_finalize_failure(
        on_failure, report, "valid_target must be non-negative",
      ),
    )
  }
  let rnd = @splitmix.new(seed~)
  let mut attempts = 0
  let mut generated_valid = 0
  let mut generated_invalid = 0
  let mut pipeline_validated = 0
  let mut optimized_count = 0
  let mut roundtripped = 0
  let mut differential_checked = 0
  let max_attempts = if valid_target <= 0 { 0 } else { valid_target * 25 }

  while generated_valid < valid_target {
    if attempts >= max_attempts {
      let msg = "failed to reach valid target: target=\{valid_target} attempts=\{attempts} valid=\{generated_valid} invalid=\{generated_invalid}"
      let report = FuzzFailureReport::new(
        seed,
        attempts,
        generated_valid,
        "generation-target",
        msg,
        optimize_passes=pass_names,
        minimized_passes=pass_names,
      )
      return Err(fuzz_finalize_failure(on_failure, report, msg))
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
      Err(e) => {
        let msg = "decode failed at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "decode",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          wasm=Some(encoded),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }
    match validate_module(decoded) {
      Ok(_) => pipeline_validated += 1
      Err(e) => {
        let msg = "decoded module failed validation at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "post-decode-validate",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          wasm=Some(encoded),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }

    let optimized = match
      optimize_module_with_options(
        decoded,
        optimize_passes,
        OptimizeOptions::new(),
      ) {
      Ok(v) => v
      Err(e) => {
        let msg = "optimize failed at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "optimize",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          wasm=Some(encoded),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }
    optimized_count += 1

    let roundtrip_bytes = match encode_module(optimized) {
      Ok(bytes) => bytes
      Err(e) => {
        let msg = "post-opt encode failed at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "post-opt-encode",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          wasm=Some(encoded),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }
    let roundtrip_mod = match decode_module(roundtrip_bytes) {
      Ok(decoded_mod) => decoded_mod
      Err(e) => {
        let msg = "post-opt decode failed at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "post-opt-decode",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          wasm=Some(roundtrip_bytes),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }
    match validate_module(roundtrip_mod) {
      Ok(_) => roundtripped += 1
      Err(e) => {
        let msg = "roundtripped module failed validation at attempt #\{attempts}: \{e}"
        let report = FuzzFailureReport::new(
          seed,
          attempts,
          generated_valid,
          "post-opt-validate",
          "\{e}",
          optimize_passes=pass_names,
          minimized_passes=pass_names,
          wasm=Some(roundtrip_bytes),
        )
        return Err(fuzz_finalize_failure(on_failure, report, msg))
      }
    }

    generated_valid += 1

    if differential_every > 0 && generated_valid % differential_every == 0 {
      let adapters = match differential_adapters {
        Some(v) => v
        None => default_differential_adapters()
      }
      match differential_validate_wasm(roundtrip_bytes, adapters~) {
        Ok(_) => differential_checked += 1
        Err(e) => {
          let msg = "differential validation failed at module #\{generated_valid}: \{e}"
          let report = FuzzFailureReport::new(
            seed,
            attempts,
            generated_valid,
            "differential",
            "\{e}",
            optimize_passes=pass_names,
            minimized_passes=pass_names,
            wasm=Some(roundtrip_bytes),
          )
          return Err(fuzz_finalize_failure(on_failure, report, msg))
        }
      }
    }
  }
  Ok(
    WasmSmithFuzzStats::new(
      attempts~,
      generated_valid~,
      generated_invalid~,
      pipeline_validated~,
      optimized=optimized_count,
      roundtripped~,
      differential_checked~,
    ),
  )
}

///|
#cfg(target="native")
fn cmd_native_has_command(name : String) -> Bool {
  let command = "command -v \{cmd_native_shell_quote(name)} >/dev/null 2>&1"
  cmd_native_system(cmd_native_c_string(command)) == 0
}

///|
#cfg(target="native")
fn cmd_native_validate_wasm_with(
  executable : String,
  command : String,
  bytes : Bytes,
) -> Result[Bool, String] {
  if !cmd_native_has_command(executable) {
    return Err("\{executable} not available")
  }
  let path = cmd_native_tmp_path("differential", ".wasm")
  if cmd_native_write_file(path, bytes) is Err(e) {
    ignore(cmd_native_remove(cmd_native_c_string(path)))
    return Err("failed to stage wasm for \{command}: \{e}")
  }
  let run = "\{command} \{cmd_native_shell_quote(path)} >/dev/null 2>&1"
  let code = cmd_native_system(cmd_native_c_string(run))
  ignore(cmd_native_remove(cmd_native_c_string(path)))
  Ok(code == 0)
}

///|
#cfg(target="native")
pub fn native_differential_tools_available() -> (Bool, Bool) {
  (
    cmd_native_has_command("wasm-tools"),
    cmd_native_has_command("wasm-validate"),
  )
}

///|
#cfg(target="wasm-gc")
pub fn native_differential_tools_available() -> (Bool, Bool) {
  (false, false)
}

///|
#cfg(target="wasm")
pub fn native_differential_tools_available() -> (Bool, Bool) {
  (false, false)
}

///|
#cfg(target="js")
pub fn native_differential_tools_available() -> (Bool, Bool) {
  (false, false)
}

///|
#cfg(target="llvm")
pub fn native_differential_tools_available() -> (Bool, Bool) {
  (false, false)
}

///|
#cfg(target="native")
fn default_differential_adapters() -> DifferentialAdapters {
  DifferentialAdapters::new(
    wasm_tools_validate=fn(bytes) {
      cmd_native_validate_wasm_with("wasm-tools", "wasm-tools validate", bytes)
    },
    binaryen_validate=fn(bytes) {
      cmd_native_validate_wasm_with("wasm-validate", "wasm-validate", bytes)
    },
  )
}

///|
#cfg(target="wasm-gc")
fn default_differential_adapters() -> DifferentialAdapters {
  DifferentialAdapters::new()
}

///|
#cfg(target="wasm")
fn default_differential_adapters() -> DifferentialAdapters {
  DifferentialAdapters::new()
}

///|
#cfg(target="js")
fn default_differential_adapters() -> DifferentialAdapters {
  DifferentialAdapters::new()
}

///|
#cfg(target="llvm")
fn default_differential_adapters() -> DifferentialAdapters {
  DifferentialAdapters::new()
}
