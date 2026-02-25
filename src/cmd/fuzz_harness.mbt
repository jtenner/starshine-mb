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
  differential_adapters? : DifferentialAdapters? = None,
  differential_every? : Int = 0,
) -> Result[WasmSmithFuzzStats, String] {
  if valid_target < 0 {
    return Err("valid_target must be non-negative")
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
      Ok(_) => pipeline_validated += 1
      Err(e) =>
        return Err(
          "decoded module failed validation at attempt #\{attempts}: \{e}",
        )
    }

    let optimized = match
      optimize_module_with_options(
        decoded,
        optimize_passes,
        OptimizeOptions::new(),
      ) {
      Ok(v) => v
      Err(e) => return Err("optimize failed at attempt #\{attempts}: \{e}")
    }
    optimized_count += 1

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
      Ok(_) => roundtripped += 1
      Err(e) =>
        return Err(
          "roundtripped module failed validation at attempt #\{attempts}: \{e}",
        )
    }

    generated_valid += 1

    if differential_every > 0 && generated_valid % differential_every == 0 {
      let adapters = match differential_adapters {
        Some(v) => v
        None => default_differential_adapters()
      }
      match differential_validate_wasm(roundtrip_bytes, adapters~) {
        Ok(_) => differential_checked += 1
        Err(e) =>
          return Err(
            "differential validation failed at module #\{generated_valid}: \{e}",
          )
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
