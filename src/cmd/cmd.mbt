///|
pub enum CmdError {
  CliParse(CliParseError)
  UnknownPassFlag(String)
  InvalidConfig(String)
  ConfigNotFound(String)
  ConfigReadFailed(String)
  InputReadFailed(String)
  TextLoweringFailed(String)
  DecodeFailed(String, DecodeError)
  OptimizeFailed(String)
  EncodeFailed(String, CmdEncodeError)
  OutputWriteFailed(String)
  AmbiguousOutputFile(String)
  NoInputFiles
} derive(Eq, Show, Debug)

///|
pub suberror CmdEncodeError {
  Encode(EncodeError)
  Adapter(String)
} derive(Eq, Show, Debug)

///|
pub fn CmdEncodeError::encode(err : EncodeError) -> CmdEncodeError {
  Encode(err)
}

///|
pub fn CmdEncodeError::adapter(msg : String) -> CmdEncodeError {
  Adapter(msg)
}

///|
pub fn CmdError::unknown_pass_flag(flag : String) -> CmdError {
  UnknownPassFlag(flag)
}

///|
pub fn CmdError::ambiguous_output_file(path : String) -> CmdError {
  AmbiguousOutputFile(path)
}

///|
pub struct CmdIO {
  get_env : (String) -> String?
  file_exists : (String) -> Bool
  read_file : (String) -> Result[Bytes, String]
  encode_module : (Module) -> Result[Bytes, CmdEncodeError]
  write_file : (String, Bytes) -> Result[Unit, String]
  write_stdout : (Bytes) -> Result[Unit, String]
  list_candidates : () -> Array[String]
  lower_text_module : (String, CliInputFormat, Bytes) -> Result[Bytes, String]
}

///|
pub fn CmdIO::new(
  get_env? : (String) -> String? = fn(_) { None },
  file_exists? : (String) -> Bool = fn(_) { false },
  read_file? : (String) -> Result[Bytes, String] = fn(_) {
    Err("read_file not configured")
  },
  encode_module? : (Module) -> Result[Bytes, CmdEncodeError] = fn(mod) {
    match encode_module(mod) {
      Ok(bytes) => Ok(bytes)
      Err(err) => Err(CmdEncodeError::encode(err))
    }
  },
  write_file? : (String, Bytes) -> Result[Unit, String] = fn(_, _) {
    Err("write_file not configured")
  },
  write_stdout? : (Bytes) -> Result[Unit, String] = fn(_) { Ok(()) },
  list_candidates? : () -> Array[String] = fn() { [] },
  lower_text_module? : (String, CliInputFormat, Bytes) -> Result[Bytes, String] = fn(
    path,
    format,
    _,
  ) {
    Err("text lowering not configured for \{path} (\{format})")
  },
) -> CmdIO {
  {
    get_env,
    file_exists,
    read_file,
    encode_module,
    write_file,
    write_stdout,
    list_candidates,
    lower_text_module,
  }
}

///|
pub struct CmdRunSummary {
  input_files : Array[String]
  output_files : Array[String]
  resolved_passes : Array[String]
  optimize_level : Int
  shrink_level : Int
  traps_never_happen : Bool
  monomorphize_min_benefit : Int
  low_memory_unused : Bool
  low_memory_bound : UInt64
} derive(Eq, Show, Debug)

///|
pub fn CmdRunSummary::new(
  input_files? : Array[String] = [],
  output_files? : Array[String] = [],
  resolved_passes? : Array[String] = [],
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
  traps_never_happen? : Bool = false,
  monomorphize_min_benefit? : Int = 5,
  low_memory_unused? : Bool = false,
  low_memory_bound? : UInt64 = 1024UL,
) -> CmdRunSummary {
  {
    input_files,
    output_files,
    resolved_passes,
    optimize_level,
    shrink_level,
    traps_never_happen,
    monomorphize_min_benefit,
    low_memory_unused,
    low_memory_bound,
  }
}

///|
fn ascii_lower(input : String) -> String {
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
fn parse_bool_string(raw : String) -> Bool? {
  match ascii_lower(raw.trim().to_string()) {
    "1" | "true" | "yes" | "on" => Some(true)
    "0" | "false" | "no" | "off" => Some(false)
    _ => None
  }
}

///|
fn parse_input_format_name(raw : String) -> CliInputFormat? {
  match ascii_lower(raw.trim().to_string()) {
    "wasm" => Some(CliInputFormat::wasm())
    "wat" => Some(CliInputFormat::wat())
    "wast" => Some(CliInputFormat::wast())
    _ => None
  }
}

///|
fn parse_trap_mode_name(raw : String) -> TrapMode? {
  match ascii_lower(raw.trim().to_string()) {
    "allow" | "traps-may-happen" => Some(TrapMode::allow())
    "never" | "traps-never-happen" => Some(TrapMode::never())
    _ => None
  }
}

///|
fn append_unique_string(out : Array[String], value : String) -> Unit {
  if !out.contains(value) {
    out.push(value)
  }
}

///|
fn push_unique_output_target_local(
  out : Array[CliOutputTarget],
  target : CliOutputTarget,
) -> Unit {
  for existing in out {
    if existing == target {
      return
    }
  }
  out.push(target)
}

///|
fn has_glob_wildcard(pattern : String) -> Bool {
  pattern.contains("*") || pattern.contains("?")
}

///|
fn basename_of_path(path : String) -> String {
  let normalized = normalize_cli_path(path)
  let mut last_sep = -1
  let mut i = 0
  while i < normalized.length() {
    if normalized[i] == '/' {
      last_sep = i
    }
    i += 1
  }
  if last_sep < 0 {
    return normalized
  }
  normalized.sub(start=last_sep + 1).to_string() catch {
    _ => normalized
  }
}

///|
fn path_with_wasm_extension(path : String) -> String {
  let normalized = normalize_cli_path(path)
  let mut last_dot = -1
  let mut i = 0
  while i < normalized.length() {
    if normalized[i] == '/' {
      last_dot = -1
    } else if normalized[i] == '.' {
      last_dot = i
    }
    i += 1
  }
  if last_dot >= 0 {
    let stem = normalized.sub(end=last_dot).to_string() catch {
        _ => normalized
      }
    "\{stem}.wasm"
  } else {
    "\{normalized}.wasm"
  }
}

///|
fn output_basename_for_input(path : String, format : CliInputFormat) -> String {
  let base = basename_of_path(path)
  match format {
    Wasm => base
    Wat | Wast => path_with_wasm_extension(base)
  }
}

///|
fn join_cli_path(dir : String, file : String) -> String {
  let normalized_dir = normalize_cli_path(dir)
  if normalized_dir.length() == 0 || normalized_dir == "." {
    file
  } else if normalized_dir[normalized_dir.length() - 1] == '/' {
    "\{normalized_dir}\{file}"
  } else {
    "\{normalized_dir}/\{file}"
  }
}

///|
fn bytes_to_string_lossy(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  for b in bytes {
    let i = b.to_int()
    if i >= 0 && i <= 127 {
      out.write_char(i.unsafe_to_char())
    } else {
      out.write_char('?')
    }
  }
  out.to_string()
}

///|
fn parse_olevel_text(raw : String) -> CliOptimizationFlag? {
  let trimmed = raw.trim().to_string()
  if trimmed.length() == 0 {
    return None
  }
  let flag = if trimmed.length() >= 2 && trimmed[0] == '-' && trimmed[1] == 'O' {
    trimmed
  } else if trimmed.length() >= 1 && trimmed[0] == 'O' {
    "-\{trimmed}"
  } else {
    ""
  }
  if flag.length() == 0 {
    return None
  }
  match parse_cli_args([flag]) {
    Ok(parsed) =>
      if parsed.optimize_flags.length() == 1 {
        Some(parsed.optimize_flags[0])
      } else {
        None
      }
    Err(_) => None
  }
}

///|
fn parse_pass_list(raw : String) -> Array[String] {
  let out = Array::new()
  for part in raw.split(",") {
    let trimmed = ascii_lower(part.to_string().trim().to_string())
    if trimmed.length() > 0 {
      out.push(trimmed)
    }
  }
  out
}

///|
fn parse_non_negative_decimal(raw : String) -> Int? {
  let text = raw.trim().to_string()
  if text.length() == 0 {
    return None
  }
  let mut value = 0
  for c in text {
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
fn parse_json_non_negative_int(value : Json) -> Int? {
  match value {
    Number(n, ..) => {
      let int_value = n.to_int()
      if int_value < 0 || int_value.to_double() != n {
        None
      } else {
        Some(int_value)
      }
    }
    String(raw) => parse_non_negative_decimal(raw)
    _ => None
  }
}

///|
fn parse_json_bool(value : Json) -> Bool? {
  match value {
    True => Some(true)
    False => Some(false)
    String(raw) => parse_bool_string(raw)
    _ => None
  }
}

///|
fn parse_config_json(text : String) -> Result[CliParseResult, CmdError] {
  let root = parse(text) catch {
    e => return Err(CmdError::InvalidConfig("invalid config json: \{e}"))
  }
  let input_globs : Array[String] = []
  let mut read_stdin = false
  let mut input_format : CliInputFormat? = None
  let output_targets : Array[CliOutputTarget] = []
  let pass_flags : Array[String] = []
  let optimize_flags : Array[CliOptimizationFlag] = []
  let mut trap_mode : TrapMode? = None
  let mut monomorphize_min_benefit : Int? = None
  let mut low_memory_unused : Bool? = None
  let mut low_memory_bound : UInt64? = None
  let root_obj = match root {
    Object(obj) => obj
    _ => return Err(CmdError::InvalidConfig("config root must be an object"))
  }

  match root_obj.get("inputs") {
    Some(Object(inputs)) => {
      match inputs.get("globs") {
        Some(Array(globs)) =>
          for glob in globs {
            match glob {
              String(raw) => {
                let normalized = normalize_cli_path(raw.trim().to_string())
                if normalized.length() > 0 {
                  append_unique_string(input_globs, normalized)
                }
              }
              _ => ()
            }
          }
        _ => ()
      }
      match inputs.get("stdin") {
        Some(True) => read_stdin = true
        Some(False) => read_stdin = false
        _ => ()
      }
      match inputs.get("format") {
        Some(String(raw)) =>
          match parse_input_format_name(raw) {
            Some(format) => input_format = Some(format)
            None => ()
          }
        _ => ()
      }
    }
    _ => ()
  }

  match root_obj.get("outputs") {
    Some(Object(outputs)) => {
      match outputs.get("stdout") {
        Some(True) =>
          push_unique_output_target_local(
            output_targets,
            CliOutputTarget::stdout(),
          )
        _ => ()
      }
      match outputs.get("out") {
        Some(String(raw)) => {
          let trimmed = raw.trim().to_string()
          if trimmed.length() > 0 {
            push_unique_output_target_local(
              output_targets,
              CliOutputTarget::file(normalize_cli_path(trimmed)),
            )
          }
        }
        _ => ()
      }
      match outputs.get("outDir") {
        Some(String(raw)) => {
          let trimmed = raw.trim().to_string()
          if trimmed.length() > 0 {
            push_unique_output_target_local(
              output_targets,
              CliOutputTarget::dir(normalize_cli_path(trimmed)),
            )
          }
        }
        _ => ()
      }
      match outputs.get("out-dir") {
        Some(String(raw)) => {
          let trimmed = raw.trim().to_string()
          if trimmed.length() > 0 {
            push_unique_output_target_local(
              output_targets,
              CliOutputTarget::dir(normalize_cli_path(trimmed)),
            )
          }
        }
        _ => ()
      }
    }
    _ => ()
  }

  match root_obj.get("passes") {
    Some(Array(passes)) =>
      for pass in passes {
        match pass {
          String(raw) => {
            let trimmed = ascii_lower(raw.trim().to_string())
            if trimmed.length() > 0 {
              pass_flags.push(trimmed)
              match trimmed {
                "optimize" =>
                  optimize_flags.push(CliOptimizationFlag::optimize())
                "shrink" => optimize_flags.push(CliOptimizationFlag::shrink())
                _ => ()
              }
            }
          }
          _ => ()
        }
      }
    _ => ()
  }

  match root_obj.get("optimize") {
    Some(Object(optimize)) => {
      match optimize.get("preset") {
        Some(String(raw)) =>
          match ascii_lower(raw.trim().to_string()) {
            "optimize" => {
              pass_flags.push("optimize")
              optimize_flags.push(CliOptimizationFlag::optimize())
            }
            "shrink" => {
              pass_flags.push("shrink")
              optimize_flags.push(CliOptimizationFlag::shrink())
            }
            _ => ()
          }
        _ => ()
      }
      let olevel_value = match optimize.get("olevel") {
        Some(v) => Some(v)
        None => optimize.get("optimizeLevel")
      }
      match olevel_value {
        Some(String(raw)) =>
          match parse_olevel_text(raw) {
            Some(flag) => optimize_flags.push(flag)
            None => ()
          }
        Some(value) =>
          match parse_json_non_negative_int(value) {
            Some(level) =>
              optimize_flags.push(CliOptimizationFlag::olevel(level, false))
            None => ()
          }
        _ => ()
      }
      let shrink_level_value = match optimize.get("shrinkLevel") {
        Some(v) => Some(v)
        None => optimize.get("shrink-level")
      }
      match shrink_level_value {
        Some(value) =>
          match parse_json_non_negative_int(value) {
            Some(level) =>
              optimize_flags.push(CliOptimizationFlag::olevel(level, true))
            None => ()
          }
        None => ()
      }
      let trap_value = match optimize.get("trapMode") {
        Some(v) => Some(v)
        None => optimize.get("trap-mode")
      }
      match trap_value {
        Some(String(raw)) =>
          match parse_trap_mode_name(raw) {
            Some(mode) => trap_mode = Some(mode)
            None => ()
          }
        _ => ()
      }
    }
    _ => ()
  }
  match root_obj.get("options") {
    Some(Object(options)) => {
      let traps_value = match options.get("trapsNeverHappen") {
        Some(v) => Some(v)
        None => options.get("traps-never-happen")
      }
      match traps_value {
        Some(value) =>
          match parse_json_bool(value) {
            Some(true) => trap_mode = Some(TrapMode::never())
            Some(false) => trap_mode = Some(TrapMode::allow())
            None => ()
          }
        None => ()
      }
      let optimize_level_value = match options.get("optimizeLevel") {
        Some(v) => Some(v)
        None => options.get("optimize-level")
      }
      match optimize_level_value {
        Some(value) =>
          match parse_json_non_negative_int(value) {
            Some(level) =>
              optimize_flags.push(CliOptimizationFlag::olevel(level, false))
            None => ()
          }
        None => ()
      }
      let shrink_level_value = match options.get("shrinkLevel") {
        Some(v) => Some(v)
        None => options.get("shrink-level")
      }
      match shrink_level_value {
        Some(value) =>
          match parse_json_non_negative_int(value) {
            Some(level) =>
              optimize_flags.push(CliOptimizationFlag::olevel(level, true))
            None => ()
          }
        None => ()
      }
      let monomorphize_value = match options.get("monomorphizeMinBenefit") {
        Some(v) => Some(v)
        None => options.get("monomorphize-min-benefit")
      }
      match monomorphize_value {
        Some(value) =>
          match parse_json_non_negative_int(value) {
            Some(parsed_value) => monomorphize_min_benefit = Some(parsed_value)
            None => ()
          }
        None => ()
      }
      let low_memory_unused_value = match options.get("lowMemoryUnused") {
        Some(v) => Some(v)
        None => options.get("low-memory-unused")
      }
      match low_memory_unused_value {
        Some(value) =>
          match parse_json_bool(value) {
            Some(parsed_value) => low_memory_unused = Some(parsed_value)
            None => ()
          }
        None => ()
      }
      let low_memory_bound_value = match options.get("lowMemoryBound") {
        Some(v) => Some(v)
        None => options.get("low-memory-bound")
      }
      match low_memory_bound_value {
        Some(value) =>
          match parse_json_non_negative_int(value) {
            Some(parsed_value) =>
              low_memory_bound = Some(parsed_value.to_uint64())
            None => ()
          }
        None => ()
      }
    }
    _ => ()
  }
  Ok(
    CliParseResult::new(
      input_globs~,
      read_stdin~,
      input_format~,
      output_targets~,
      pass_flags~,
      optimize_flags~,
      trap_mode~,
      monomorphize_min_benefit~,
      low_memory_unused~,
      low_memory_bound~,
    ),
  )
}

///|
fn parse_env_overlay(io : CmdIO) -> CliParseResult {
  let mut input_format : CliInputFormat? = None
  let output_targets : Array[CliOutputTarget] = []
  let pass_flags : Array[String] = []
  let optimize_flags : Array[CliOptimizationFlag] = []
  let mut trap_mode : TrapMode? = None
  let mut monomorphize_min_benefit : Int? = None
  let mut low_memory_unused : Bool? = None
  let mut low_memory_bound : UInt64? = None

  match (io.get_env)("STARSHINE_FORMAT") {
    Some(raw) =>
      match parse_input_format_name(raw) {
        Some(format) => input_format = Some(format)
        None => ()
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_OUT") {
    Some(raw) => {
      let trimmed = raw.trim().to_string()
      if trimmed.length() > 0 {
        push_unique_output_target_local(
          output_targets,
          CliOutputTarget::file(normalize_cli_path(trimmed)),
        )
      }
    }
    None => ()
  }
  match (io.get_env)("STARSHINE_OUT_DIR") {
    Some(raw) => {
      let trimmed = raw.trim().to_string()
      if trimmed.length() > 0 {
        push_unique_output_target_local(
          output_targets,
          CliOutputTarget::dir(normalize_cli_path(trimmed)),
        )
      }
    }
    None => ()
  }
  match (io.get_env)("STARSHINE_STDOUT") {
    Some(raw) =>
      match parse_bool_string(raw) {
        Some(true) =>
          push_unique_output_target_local(
            output_targets,
            CliOutputTarget::stdout(),
          )
        _ => ()
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_PASSES") {
    Some(raw) =>
      for pass in parse_pass_list(raw) {
        pass_flags.push(pass)
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_TRAP_MODE") {
    Some(raw) =>
      match parse_trap_mode_name(raw) {
        Some(mode) => trap_mode = Some(mode)
        None => ()
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_OPTIMIZE") {
    Some(raw) =>
      for part in parse_pass_list(raw) {
        match part {
          "optimize" => {
            pass_flags.push("optimize")
            optimize_flags.push(CliOptimizationFlag::optimize())
          }
          "shrink" => {
            pass_flags.push("shrink")
            optimize_flags.push(CliOptimizationFlag::shrink())
          }
          _ => ()
        }
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_PRESET") {
    Some(raw) =>
      for part in parse_pass_list(raw) {
        match part {
          "optimize" => {
            pass_flags.push("optimize")
            optimize_flags.push(CliOptimizationFlag::optimize())
          }
          "shrink" => {
            pass_flags.push("shrink")
            optimize_flags.push(CliOptimizationFlag::shrink())
          }
          _ => ()
        }
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_OLEVEL") {
    Some(raw) =>
      match parse_olevel_text(raw) {
        Some(flag) => optimize_flags.push(flag)
        None => ()
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_MONOMORPHIZE_MIN_BENEFIT") {
    Some(raw) =>
      match parse_non_negative_decimal(raw) {
        Some(parsed_value) => monomorphize_min_benefit = Some(parsed_value)
        None => ()
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_LOW_MEMORY_UNUSED") {
    Some(raw) =>
      match parse_bool_string(raw) {
        Some(parsed_value) => low_memory_unused = Some(parsed_value)
        None => ()
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_LOW_MEMORY_BOUND") {
    Some(raw) =>
      match parse_non_negative_decimal(raw) {
        Some(parsed_value) => low_memory_bound = Some(parsed_value.to_uint64())
        None => ()
      }
    None => ()
  }
  CliParseResult::new(
    input_format~,
    output_targets~,
    pass_flags~,
    optimize_flags~,
    trap_mode~,
    monomorphize_min_benefit~,
    low_memory_unused~,
    low_memory_bound~,
  )
}

///|
fn merge_parse_results(
  config : CliParseResult,
  env : CliParseResult,
  cli : CliParseResult,
) -> CliParseResult {
  let input_globs : Array[String] = []

  for glob in config.input_globs {
    append_unique_string(input_globs, glob)
  }
  for glob in env.input_globs {
    append_unique_string(input_globs, glob)
  }
  for glob in cli.input_globs {
    append_unique_string(input_globs, glob)
  }

  let read_stdin = config.read_stdin || env.read_stdin || cli.read_stdin

  let input_format = match cli.input_format {
    Some(format) => Some(format)
    None =>
      match env.input_format {
        Some(format) => Some(format)
        None => config.input_format
      }
  }

  let output_targets : Array[CliOutputTarget] = []
  let chosen_outputs = if cli.output_targets.length() > 0 {
    cli.output_targets
  } else if env.output_targets.length() > 0 {
    env.output_targets
  } else {
    config.output_targets
  }
  for target in chosen_outputs {
    output_targets.push(target)
  }

  let pass_flags : Array[String] = []
  let selected_passes = if cli.pass_flags.length() > 0 {
    cli.pass_flags
  } else if config.pass_flags.length() > 0 {
    config.pass_flags
  } else {
    env.pass_flags
  }
  for pass in selected_passes {
    pass_flags.push(pass)
  }

  let optimize_flags : Array[CliOptimizationFlag] = []
  let selected_optimize_flags = if cli.optimize_flags.length() > 0 {
    cli.optimize_flags
  } else if env.optimize_flags.length() > 0 {
    env.optimize_flags
  } else {
    config.optimize_flags
  }
  for flag in selected_optimize_flags {
    optimize_flags.push(flag)
  }

  let trap_mode = match cli.trap_mode {
    Some(mode) => Some(mode)
    None =>
      match env.trap_mode {
        Some(mode) => Some(mode)
        None => config.trap_mode
      }
  }
  let config_path = match cli.config_path {
    Some(path) => Some(path)
    None =>
      match env.config_path {
        Some(path) => Some(path)
        None => config.config_path
      }
  }
  let monomorphize_min_benefit = match cli.monomorphize_min_benefit {
    Some(v) => Some(v)
    None =>
      match env.monomorphize_min_benefit {
        Some(v) => Some(v)
        None => config.monomorphize_min_benefit
      }
  }
  let low_memory_unused = match cli.low_memory_unused {
    Some(v) => Some(v)
    None =>
      match env.low_memory_unused {
        Some(v) => Some(v)
        None => config.low_memory_unused
      }
  }
  let low_memory_bound = match cli.low_memory_bound {
    Some(v) => Some(v)
    None =>
      match env.low_memory_bound {
        Some(v) => Some(v)
        None => config.low_memory_bound
      }
  }
  CliParseResult::new(
    config_path~,
    input_globs~,
    read_stdin~,
    input_format~,
    output_targets~,
    pass_flags~,
    optimize_flags~,
    trap_mode~,
    monomorphize_min_benefit~,
    low_memory_unused~,
    low_memory_bound~,
  )
}

///|
fn resolve_config_path(cli : CliParseResult, io : CmdIO) -> (String?, Bool) {
  match cli.config_path {
    Some(path) => return (Some(normalize_cli_path(path)), true)
    None => ()
  }
  match (io.get_env)("STARSHINE_CONFIG") {
    Some(raw) => {
      let trimmed = raw.trim().to_string()
      if trimmed.length() > 0 {
        return (Some(normalize_cli_path(trimmed)), true)
      }
    }
    None => ()
  }
  if (io.file_exists)(@cli.DEFAULT_CONFIG_PATH) {
    return (Some(@cli.DEFAULT_CONFIG_PATH), false)
  }
  (None, false)
}

///|
fn resolve_input_files(globs : Array[String], io : CmdIO) -> Array[String] {
  let literal = Array::new()
  let patterns = Array::new()
  for raw in globs {
    let normalized = normalize_cli_path(raw.trim().to_string())
    if normalized.length() == 0 {
      continue
    }
    if has_glob_wildcard(normalized) {
      append_unique_string(patterns, normalized)
    } else {
      append_unique_string(literal, normalized)
    }
  }
  let out = Array::new()
  for value in literal {
    append_unique_string(out, value)
  }
  if patterns.length() > 0 {
    for value in expand_globs_with_adapter(patterns, io.list_candidates) {
      append_unique_string(out, value)
    }
  }
  out
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn resolve_optimize_levels(flags : Array[CliOptimizationFlag]) -> (Int, Int) {
  let mut optimize_level = 0
  let mut shrink_level = 0
  for flag in flags {
    match flag {
      OLevel(level, size_bias) =>
        if size_bias {
          shrink_level = max_int(shrink_level, level)
        } else {
          optimize_level = max_int(optimize_level, level)
        }
      OptimizePreset => optimize_level = max_int(optimize_level, 2)
      ShrinkPreset => shrink_level = max_int(shrink_level, 2)
    }
  }
  (optimize_level, shrink_level)
}

///|
fn default_inlining_options() -> InliningOptions {
  InliningOptions::new()
}

///|
fn make_optimize_options(
  optimize_level : Int,
  shrink_level : Int,
  traps_never_happen : Bool,
  monomorphize_min_benefit : Int,
  low_memory_unused : Bool,
  low_memory_bound : UInt64,
) -> OptimizeOptions {
  OptimizeOptions::new(
    optimize_level~,
    shrink_level~,
    inlining=default_inlining_options(),
    monomorphize_min_benefit~,
    low_memory_unused~,
    low_memory_bound~,
    traps_never_happen~,
  )
}

///|
fn resolve_explicit_pass(flag : String) -> ModulePass? {
  match flag {
    "alignment-lowering" => Some(ModulePass::AlignmentLowering)
    "avoid-reinterprets" => Some(ModulePass::AvoidReinterprets)
    "coalesce-locals" => Some(ModulePass::CoalesceLocals)
    "code-folding" => Some(ModulePass::CodeFolding)
    "code-pushing" => Some(ModulePass::CodePushing)
    "const-hoisting" => Some(ModulePass::ConstHoisting)
    "constant-field-propagation" => Some(ModulePass::ConstantFieldPropagation)
    "dataflow-optimization" => Some(ModulePass::DataflowOptimization)
    "dead-code-elimination" => Some(ModulePass::DeadCodeElimination)
    "dead-argument-elimination" => Some(ModulePass::DeadArgumentElimination)
    "signature-pruning" => Some(ModulePass::SignaturePruning)
    "signature-refining" => Some(ModulePass::SignatureRefining)
    "duplicate-import-elimination" =>
      Some(ModulePass::DuplicateImportElimination)
    "global-refining" => Some(ModulePass::GlobalRefining)
    "global-struct-inference" => Some(ModulePass::GlobalStructInference)
    "global-struct-inference-desc-cast" =>
      Some(ModulePass::GlobalStructInferenceDescCast)
    "global-type-optimization" => Some(ModulePass::GlobalTypeOptimization)
    "simplify-globals" => Some(ModulePass::SimplifyGlobals)
    "simplify-globals-optimizing" => Some(ModulePass::SimplifyGlobalsOptimizing)
    "global-effects" => Some(ModulePass::GlobalEffects)
    "propagate-globals-globally" => Some(ModulePass::PropagateGlobalsGlobally)
    "type-refining" => Some(ModulePass::TypeRefining)
    "type-generalizing" => Some(ModulePass::TypeGeneralizing)
    "type-finalizing" => Some(ModulePass::TypeFinalizing)
    "type-un-finalizing" => Some(ModulePass::TypeUnFinalizing)
    "unsubtyping" => Some(ModulePass::Unsubtyping)
    "heap2local" => Some(ModulePass::Heap2Local)
    "heap-store-optimization" => Some(ModulePass::HeapStoreOptimization)
    "inlining" => Some(ModulePass::Inlining)
    "inlining-optimizing" => Some(ModulePass::InliningOptimizing)
    "inline-main" => Some(ModulePass::InlineMain)
    "local-cse" => Some(ModulePass::LocalCSE)
    "local-subtyping" => Some(ModulePass::LocalSubtyping)
    "loop-invariant-code-motion" => Some(ModulePass::LoopInvariantCodeMotion)
    "merge-locals" => Some(ModulePass::MergeLocals)
    "merge-similar-functions" => Some(ModulePass::MergeSimilarFunctions)
    "merge-blocks" => Some(ModulePass::MergeBlocks)
    "flatten" => Some(ModulePass::Flatten)
    "re-reloop" => Some(ModulePass::ReReloop)
    "tuple-optimization" => Some(ModulePass::TupleOptimization)
    "once-reduction" => Some(ModulePass::OnceReduction)
    "minimize-rec-groups" => Some(ModulePass::MinimizeRecGroups)
    "type-merging" => Some(ModulePass::TypeMerging)
    "monomorphize" => Some(ModulePass::Monomorphize)
    "monomorphize-always" => Some(ModulePass::MonomorphizeAlways)
    "optimize-added-constants" => Some(ModulePass::OptimizeAddedConstants)
    "optimize-added-constants-propagate" =>
      Some(ModulePass::OptimizeAddedConstantsPropagate)
    "optimize-instructions" => Some(ModulePass::OptimizeInstructions)
    "precompute" => Some(ModulePass::Precompute)
    "precompute-propagate" => Some(ModulePass::PrecomputePropagate)
    "redundant-set-elimination" => Some(ModulePass::RedundantSetElimination)
    "pick-load-signs" => Some(ModulePass::PickLoadSigns)
    "gufa" => Some(ModulePass::GUFA)
    "gufa-optimizing" => Some(ModulePass::GUFAOptimizing)
    "gufa-cast-all" => Some(ModulePass::GUFACastAll)
    "i64-to-i32-lowering" => Some(ModulePass::I64ToI32Lowering)
    "duplicate-function-elimination" =>
      Some(ModulePass::DuplicateFunctionElimination)
    "optimize-casts" => Some(ModulePass::OptimizeCasts)
    "de-nan" => Some(ModulePass::DeNaN)
    "remove-unused-brs" => Some(ModulePass::RemoveUnusedBrs)
    "remove-unused-names" => Some(ModulePass::RemoveUnusedNames)
    "simplify-locals" => Some(ModulePass::SimplifyLocals)
    "simplify-locals-no-tee" => Some(ModulePass::SimplifyLocalsNoTee)
    "simplify-locals-no-structure" =>
      Some(ModulePass::SimplifyLocalsNoStructure)
    "simplify-locals-no-tee-no-structure" =>
      Some(ModulePass::SimplifyLocalsNoTeeNoStructure)
    "simplify-locals-no-nesting" => Some(ModulePass::SimplifyLocalsNoNesting)
    "untee" => Some(ModulePass::Untee)
    "vacuum" => Some(ModulePass::Vacuum)
    "reorder-locals" => Some(ModulePass::ReorderLocals)
    "reorder-types" => Some(ModulePass::ReorderTypes)
    "reorder-globals" => Some(ModulePass::ReorderGlobals)
    "reorder-globals-always" => Some(ModulePass::ReorderGlobalsAlways)
    "reorder-functions" => Some(ModulePass::ReorderFunctions)
    "reorder-functions-by-name" => Some(ModulePass::ReorderFunctionsByName)
    "remove-unused-types" => Some(ModulePass::RemoveUnusedTypes)
    "remove-unused" => Some(ModulePass::RemoveUnused)
    "remove-unused-module-elements" =>
      Some(ModulePass::RemoveUnusedModuleElements)
    "remove-unused-non-function-elements" =>
      Some(ModulePass::RemoveUnusedNonFunctionElements)
    _ => None
  }
}

///|
fn expand_passes_for_module(
  pass_flags : Array[String],
  mod : Module,
  options : OptimizeOptions,
) -> Result[Array[ModulePass], CmdError] {
  let out : Array[ModulePass] = []
  for flag in pass_flags {
    match flag {
      "optimize" => {
        for pass in default_global_optimization_pre_passes(mod, options) {
          out.push(pass)
        }
        for pass in default_function_optimization_passes(mod, options) {
          out.push(pass)
        }
      }
      "shrink" => {
        let shrink_options = OptimizeOptions::new(
          optimize_level=options.optimize_level,
          shrink_level=max_int(options.shrink_level, 2),
          inlining=options.inlining,
          monomorphize_min_benefit=options.monomorphize_min_benefit,
          low_memory_unused=options.low_memory_unused,
          low_memory_bound=options.low_memory_bound,
          traps_never_happen=options.traps_never_happen,
        )
        for pass in default_global_optimization_pre_passes(mod, shrink_options) {
          out.push(pass)
        }
        for pass in default_function_optimization_passes(mod, shrink_options) {
          out.push(pass)
        }
      }
      _ =>
        match resolve_explicit_pass(flag) {
          Some(pass) => out.push(pass)
          None => return Err(CmdError::unknown_pass_flag(flag))
        }
    }
  }
  Ok(out)
}

///|
test "expand_passes_for_module preserves preset-plus-explicit multiplicity for overlapping passes" {
  let mod = Module::new()
  let expanded = match
    expand_passes_for_module(
      ["optimize", "vacuum"],
      mod,
      OptimizeOptions::new(),
    ) {
    Ok(v) => v
    Err(e) => fail("expected pass expansion success, got \{e}")
  }
  let mut vacuum_count = 0
  for pass in expanded {
    match pass {
      Vacuum => vacuum_count += 1
      _ => ()
    }
  }
  assert_true(vacuum_count >= 2)
}

///|
fn decode_module_for_pipeline(
  path : String,
  bytes : Bytes,
) -> Result[Module, CmdError] {
  match decode_module(bytes) {
    Ok(mod) => Ok(mod)
    Err(err) => Err(CmdError::DecodeFailed(path, err))
  }
}

///|
fn encode_module_for_pipeline(
  io : CmdIO,
  path : String,
  mod : Module,
) -> Result[Bytes, CmdError] {
  match (io.encode_module)(mod) {
    Ok(bytes) => Ok(bytes)
    Err(err) => Err(CmdError::EncodeFailed(path, err))
  }
}

///|
fn lower_text_module_in_process(
  path : String,
  format : CliInputFormat,
  bytes : Bytes,
) -> Result[Bytes, String] {
  match format {
    Wasm => return Err("expected wat/wast input format")
    Wat | Wast => ()
  }
  let source = bytes_to_string_lossy(bytes)
  let mod = match @wast.wast_to_binary_module(source, filename=path) {
    Ok(parsed) => parsed
    Err(e) => return Err("in-process text parse/lower failed: \{e}")
  }
  let buf = @buffer.new()
  match Encode::encode(mod, buf) {
    Ok(_) => Ok(buf.to_bytes())
    Err(e) => Err("in-process text encode failed: \{e}")
  }
}

///|
fn lower_text_module_for_pipeline(
  io : CmdIO,
  path : String,
  format : CliInputFormat,
  bytes : Bytes,
) -> Result[Bytes, CmdError] {
  match (io.lower_text_module)(path, format, bytes) {
    Ok(out) => Ok(out)
    Err(adapter_err) =>
      match lower_text_module_in_process(path, format, bytes) {
        Ok(out) => Ok(out)
        Err(in_process_err) =>
          Err(
            CmdError::TextLoweringFailed(
              "\{path}: \{adapter_err}; fallback failed: \{in_process_err}",
            ),
          )
      }
  }
}

///|
fn output_path_for_default_target(
  path : String,
  format : CliInputFormat,
) -> String {
  match format {
    Wasm => normalize_cli_path(path)
    Wat | Wast => path_with_wasm_extension(path)
  }
}

///|
pub fn run_cmd_with_adapter(
  args : Array[String],
  io : CmdIO,
  config_json? : String? = None,
) -> Result[CmdRunSummary, CmdError] {
  let starshine_input = (io.get_env)("STARSHINE_INPUT")
  let cli = match parse_cli_args(args, starshine_input~) {
    Ok(parsed) => parsed
    Err(e) => return Err(CmdError::CliParse(e))
  }

  let config = match config_json {
    Some(config_text) =>
      match parse_config_json(config_text) {
        Ok(parsed) => parsed
        Err(e) => return Err(e)
      }
    None => {
      let (maybe_config_path, config_required) = resolve_config_path(cli, io)
      match maybe_config_path {
        Some(config_path) =>
          if !(io.file_exists)(config_path) {
            if config_required {
              return Err(CmdError::ConfigNotFound(config_path))
            } else {
              CliParseResult::new()
            }
          } else {
            let config_bytes = match (io.read_file)(config_path) {
              Ok(bytes) => bytes
              Err(e) =>
                return Err(CmdError::ConfigReadFailed("\{config_path}: \{e}"))
            }
            let config_text = bytes_to_string_lossy(config_bytes)
            match parse_config_json(config_text) {
              Ok(parsed) => parsed
              Err(e) => return Err(e)
            }
          }
        None => CliParseResult::new()
      }
    }
  }

  let env = parse_env_overlay(io)
  let merged = merge_parse_results(config, env, cli)
  let input_files = resolve_input_files(merged.input_globs, io)
  if input_files.length() == 0 {
    return Err(CmdError::NoInputFiles)
  }

  let resolved_passes = resolve_pass_flags(merged)
  let traps_never_happen = resolve_traps_never_happen(merged)
  let (optimize_level, shrink_level) = resolve_optimize_levels(
    merged.optimize_flags,
  )
  let monomorphize_min_benefit = match merged.monomorphize_min_benefit {
    Some(v) => v
    None => 5
  }
  let low_memory_unused = match merged.low_memory_unused {
    Some(v) => v
    None => false
  }
  let low_memory_bound = match merged.low_memory_bound {
    Some(v) => v
    None => 1024UL
  }
  let options = make_optimize_options(
    optimize_level, shrink_level, traps_never_happen, monomorphize_min_benefit, low_memory_unused,
    low_memory_bound,
  )

  if input_files.length() > 1 {
    for target in merged.output_targets {
      match target {
        FileOutput(path) => return Err(CmdError::ambiguous_output_file(path))
        _ => ()
      }
    }
  }

  let output_files : Array[String] = []

  for input_path in input_files {
    let format = match merged.input_format {
      Some(format) => format
      None =>
        match infer_input_format(input_path) {
          Some(inferred) => inferred
          None => CliInputFormat::wasm()
        }
    }

    let raw_bytes = match (io.read_file)(input_path) {
      Ok(bytes) => bytes
      Err(e) => return Err(CmdError::InputReadFailed("\{input_path}: \{e}"))
    }

    let wasm_bytes = match format {
      Wasm => raw_bytes
      Wat | Wast =>
        match
          lower_text_module_for_pipeline(io, input_path, format, raw_bytes) {
          Ok(bytes) => bytes
          Err(e) => return Err(e)
        }
    }

    let mod = match decode_module_for_pipeline(input_path, wasm_bytes) {
      Ok(mod) => mod
      Err(e) => return Err(e)
    }

    let passes = match expand_passes_for_module(resolved_passes, mod, options) {
      Ok(passes) => passes
      Err(e) => return Err(e)
    }

    let optimized = match optimize_module_with_options(mod, passes, options) {
      Ok(out) => out
      Err(e) => return Err(CmdError::OptimizeFailed("\{input_path}: \{e}"))
    }

    let out_bytes = match
      encode_module_for_pipeline(io, input_path, optimized) {
      Ok(bytes) => bytes
      Err(e) => return Err(e)
    }

    if merged.output_targets.length() == 0 {
      let out_path = output_path_for_default_target(input_path, format)
      match (io.write_file)(out_path, out_bytes) {
        Ok(_) => output_files.push(out_path)
        Err(e) => return Err(CmdError::OutputWriteFailed("\{out_path}: \{e}"))
      }
      continue
    }

    for target in merged.output_targets {
      match target {
        StdoutOutput =>
          match (io.write_stdout)(out_bytes) {
            Ok(_) => ()
            Err(e) =>
              return Err(
                CmdError::OutputWriteFailed("stdout for \{input_path}: \{e}"),
              )
          }
        FileOutput(path) => {
          let out_path = normalize_cli_path(path)
          match (io.write_file)(out_path, out_bytes) {
            Ok(_) => output_files.push(out_path)
            Err(e) =>
              return Err(CmdError::OutputWriteFailed("\{out_path}: \{e}"))
          }
        }
        DirOutput(dir) => {
          let basename = output_basename_for_input(input_path, format)
          let out_path = join_cli_path(dir, basename)
          match (io.write_file)(out_path, out_bytes) {
            Ok(_) => output_files.push(out_path)
            Err(e) =>
              return Err(CmdError::OutputWriteFailed("\{out_path}: \{e}"))
          }
        }
      }
    }
  }

  Ok(
    CmdRunSummary::new(
      input_files~,
      output_files~,
      resolved_passes~,
      optimize_level~,
      shrink_level~,
      traps_never_happen~,
      monomorphize_min_benefit~,
      low_memory_unused~,
      low_memory_bound~,
    ),
  )
}

///|
#cfg(target="native")
fn cmd_native_c_string(text : String) -> Bytes {
  let out = @buffer.new(size_hint=text.length() + 1)
  for c in text {
    let code = c.to_int()
    if code >= 0 && code <= 255 {
      out.write_byte(code.to_byte())
    } else {
      out.write_byte('?'.to_int().to_byte())
    }
  }
  out.write_byte(0)
  out.to_bytes()
}

///|
#cfg(target="native")
#borrow(path, mode)
extern "c" fn cmd_native_fopen(path : Bytes, mode : Bytes) -> Int = "fopen"

///|
#cfg(target="native")
extern "c" fn cmd_native_fclose(stream : Int) -> Int = "fclose"

///|
#cfg(target="native")
extern "c" fn cmd_native_fseek(stream : Int, offset : Int, whence : Int) -> Int = "fseek"

///|
#cfg(target="native")
extern "c" fn cmd_native_ftell(stream : Int) -> Int = "ftell"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn cmd_native_fread(
  ptr : Bytes,
  size : Int,
  count : Int,
  stream : Int,
) -> Int = "fread"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn cmd_native_fwrite(
  ptr : Bytes,
  size : Int,
  count : Int,
  stream : Int,
) -> Int = "fwrite"

///|
#cfg(target="native")
#borrow(path)
extern "c" fn cmd_native_access(path : Bytes, mode : Int) -> Int = "access"

///|
#cfg(target="native")
#borrow(path)
extern "c" fn cmd_native_getenv(path : Bytes) -> Int = "getenv"

///|
#cfg(target="native")
#borrow(command, mode)
extern "c" fn cmd_native_popen(command : Bytes, mode : Bytes) -> Int = "popen"

///|
#cfg(target="native")
extern "c" fn cmd_native_pclose(stream : Int) -> Int = "pclose"

///|
#cfg(target="native")
#borrow(command)
extern "c" fn cmd_native_system(command : Bytes) -> Int = "system"

///|
#cfg(target="native")
#borrow(path)
extern "c" fn cmd_native_remove(path : Bytes) -> Int = "remove"

///|
#cfg(target="native")
extern "c" fn cmd_native_getpid() -> Int = "getpid"

///|
#cfg(target="native")
extern "c" fn cmd_native_strlen(ptr : Int) -> Int = "strlen"

///|
#cfg(target="native")
#borrow(dst)
extern "c" fn cmd_native_memcpy(dst : Bytes, src : Int, size : Int) -> Int = "memcpy"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn cmd_native_write(fd : Int, ptr : Bytes, count : Int) -> Int = "write"

///|
#cfg(target="native")
fn cmd_native_file_exists(path : String) -> Bool {
  cmd_native_access(cmd_native_c_string(path), 0) == 0
}

///|
#cfg(target="native")
fn cmd_native_read_file(path : String) -> Result[Bytes, String] {
  let file = cmd_native_fopen(
    cmd_native_c_string(path),
    cmd_native_c_string("rb"),
  )
  if file == 0 {
    return Err("open failed")
  }
  if cmd_native_fseek(file, 0, 2) != 0 {
    ignore(cmd_native_fclose(file))
    return Err("seek end failed")
  }
  let size = cmd_native_ftell(file)
  if size < 0 {
    ignore(cmd_native_fclose(file))
    return Err("tell failed")
  }
  if cmd_native_fseek(file, 0, 0) != 0 {
    ignore(cmd_native_fclose(file))
    return Err("seek start failed")
  }
  let out = Bytes::new(size)
  if size > 0 {
    let read = cmd_native_fread(out, 1, size, file)
    if read != size {
      ignore(cmd_native_fclose(file))
      return Err("read failed")
    }
  }
  if cmd_native_fclose(file) != 0 {
    return Err("close failed")
  }
  Ok(out)
}

///|
#cfg(target="native")
fn cmd_native_write_file(path : String, bytes : Bytes) -> Result[Unit, String] {
  let file = cmd_native_fopen(
    cmd_native_c_string(path),
    cmd_native_c_string("wb"),
  )
  if file == 0 {
    return Err("open failed")
  }
  let expected = bytes.length()
  if expected > 0 {
    let wrote = cmd_native_fwrite(bytes, 1, expected, file)
    if wrote != expected {
      ignore(cmd_native_fclose(file))
      return Err("write failed")
    }
  }
  if cmd_native_fclose(file) != 0 {
    return Err("close failed")
  }
  Ok(())
}

///|
#cfg(target="native")
fn cmd_native_write_stdout(bytes : Bytes) -> Result[Unit, String] {
  if bytes.length() == 0 {
    return Ok(())
  }
  let wrote = cmd_native_write(1, bytes, bytes.length())
  if wrote < 0 {
    return Err("write failed")
  }
  if wrote != bytes.length() {
    return Err("short write: \{wrote}/\{bytes.length()}")
  }
  Ok(())
}

///|
#cfg(target="native")
fn cmd_native_get_env(name : String) -> String? {
  let ptr = cmd_native_getenv(cmd_native_c_string(name))
  if ptr == 0 {
    return None
  }
  let len = cmd_native_strlen(ptr)
  if len < 0 {
    return None
  }
  let out = Bytes::new(len)
  if len > 0 {
    ignore(cmd_native_memcpy(out, ptr, len))
  }
  Some(bytes_to_string_lossy(out))
}

///|
#cfg(target="native")
fn cmd_native_shell_quote(text : String) -> String {
  let escaped = text.replace(old="'", new="'\"'\"'")
  "'\{escaped}'"
}

///|
#cfg(target="native")
fn cmd_native_tmp_path(prefix : String, suffix : String) -> String {
  "/tmp/starshine-cmd-\{prefix}-\{cmd_native_getpid()}-\{@env.now()}\{suffix}"
}

///|
#cfg(target="native")
fn cmd_native_list_candidates() -> Array[String] {
  let pipe = cmd_native_popen(
    cmd_native_c_string("find . -type f -print"),
    cmd_native_c_string("r"),
  )
  if pipe == 0 {
    return []
  }

  let buf = Bytes::new(4096)
  let output = StringBuilder::new()
  while true {
    let read = cmd_native_fread(buf, 1, buf.length(), pipe)
    if read <= 0 {
      break
    }
    let mut i = 0
    while i < read {
      let b = buf[i].to_int()
      if b >= 0 && b <= 127 {
        output.write_char(b.unsafe_to_char())
      } else {
        output.write_char('?')
      }
      i += 1
    }
  }
  ignore(cmd_native_pclose(pipe))

  let out : Array[String] = []
  for line in output.to_string().split("\n") {
    let raw = line.to_string().trim().to_string()
    if raw.length() == 0 {
      continue
    }
    let normalized = normalize_cli_path(raw)
    if normalized.length() == 0 || normalized == "." {
      continue
    }
    let candidate = if normalized.length() >= 2 &&
      normalized[0] == '.' &&
      normalized[1] == '/' {
      normalized.sub(start=2).to_string() catch {
        _ => normalized
      }
    } else {
      normalized
    }
    if candidate.length() > 0 && candidate != "." {
      out.push(candidate)
    }
  }
  out
}

///|
#cfg(target="native")
fn cmd_native_lower_text_module(
  path : String,
  format : CliInputFormat,
  bytes : Bytes,
) -> Result[Bytes, String] {
  match format {
    Wasm => return Err("expected wat/wast input format")
    Wat | Wast => ()
  }

  let in_suffix = match format {
    Wat => ".wat"
    Wast => ".wast"
    Wasm => ".wat"
  }
  let in_path = cmd_native_tmp_path("text-in", in_suffix)
  let out_path = cmd_native_tmp_path("text-out", ".wasm")

  if cmd_native_write_file(in_path, bytes) is Err(e) {
    ignore(cmd_native_remove(cmd_native_c_string(in_path)))
    ignore(cmd_native_remove(cmd_native_c_string(out_path)))
    return Err("failed to stage text input for \{path}: \{e}")
  }

  let in_q = cmd_native_shell_quote(in_path)
  let out_q = cmd_native_shell_quote(out_path)
  let commands = [
    "wat2wasm \{in_q} -o \{out_q}",
    "wasm-tools parse \{in_q} -o \{out_q}",
  ]
  let mut lowered = false
  for command in commands {
    let code = cmd_native_system(cmd_native_c_string(command))
    if code == 0 && cmd_native_file_exists(out_path) {
      lowered = true
      break
    }
  }

  let result = if lowered {
    match cmd_native_read_file(out_path) {
      Ok(out) => Ok(out)
      Err(e) => Err("failed to read lowered wasm for \{path}: \{e}")
    }
  } else {
    Err(
      "failed to lower \{path}: expected native `wat2wasm` or `wasm-tools parse` to be available",
    )
  }

  ignore(cmd_native_remove(cmd_native_c_string(in_path)))
  ignore(cmd_native_remove(cmd_native_c_string(out_path)))
  result
}

///|
#cfg(target="native")
fn default_cmd_io() -> CmdIO {
  CmdIO::new(
    get_env=cmd_native_get_env,
    file_exists=cmd_native_file_exists,
    read_file=cmd_native_read_file,
    write_file=cmd_native_write_file,
    write_stdout=cmd_native_write_stdout,
    list_candidates=cmd_native_list_candidates,
    lower_text_module=cmd_native_lower_text_module,
  )
}

///|
#cfg(target="wasm-gc")
fn default_cmd_io() -> CmdIO {
  CmdIO::new()
}

///|
#cfg(target="wasm")
fn default_cmd_io() -> CmdIO {
  CmdIO::new()
}

///|
#cfg(target="js")
fn default_cmd_io() -> CmdIO {
  CmdIO::new()
}

///|
#cfg(target="llvm")
fn default_cmd_io() -> CmdIO {
  CmdIO::new()
}

///|
pub fn run_cmd(args : Array[String]) -> Result[CmdRunSummary, CmdError] {
  run_cmd_with_adapter(args, default_cmd_io())
}

///|
#cfg(target="native")
fn trim_program_name(argv : Array[String]) -> Array[String] {
  if argv.length() == 0 {
    return []
  }
  let out = Array::new(capacity=argv.length() - 1)
  let mut i = 1
  while i < argv.length() {
    out.push(argv[i])
    i += 1
  }
  out
}

///|
#cfg(target="wasm-gc")
fn main {
  ()
}

///|
#cfg(target="native")
fn main {
  let args = trim_program_name(@env.args())
  ignore(run_cmd(args))
}
