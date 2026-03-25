///|
pub enum CmdError {
  CliParse(CliParseError)
  UnknownPassFlag(String)
  InvalidConfig(String)
  ConfigNotFound(String)
  ConfigReadFailed(String)
  InputReadFailed(String)
  SpecFailed(String)
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
  print_text_module : (Module) -> Result[Bytes, String]
  write_file : (String, Bytes) -> Result[Unit, String]
  write_stdout : (Bytes) -> Result[Unit, String]
  write_stderr : (Bytes) -> Result[Unit, String]
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
  print_text_module? : (Module) -> Result[Bytes, String] = fn(_) {
    Err("text module printing not configured")
  },
  write_file? : (String, Bytes) -> Result[Unit, String] = fn(_, _) {
    Err("write_file not configured")
  },
  write_stdout? : (Bytes) -> Result[Unit, String] = fn(_) { Ok(()) },
  write_stderr? : (Bytes) -> Result[Unit, String] = fn(_) { Ok(()) },
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
    print_text_module,
    write_file,
    write_stdout,
    write_stderr,
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
  closed_world : Bool
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
  closed_world? : Bool = false,
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
    closed_world,
    low_memory_unused,
    low_memory_bound,
  }
}

///|
pub enum OptimizeTracingLevel {
  Pass
  Phase
  Helper
} derive(Eq, Show, Debug)

///|
pub fn OptimizeTracingLevel::pass() -> OptimizeTracingLevel {
  Pass
}

///|
pub fn OptimizeTracingLevel::phase() -> OptimizeTracingLevel {
  Phase
}

///|
pub fn OptimizeTracingLevel::helper() -> OptimizeTracingLevel {
  Helper
}

///|
enum CmdPipelineDumpFormat {
  Wasm
  Wat
}

///|
enum CmdPipelinePrintSelector {
  Index(UInt)
  Name(String)
}

///|
enum CmdPipelineStep {
  PipelinePass(String)
  Dump(String, CmdPipelineDumpFormat)
  Print(String, CmdPipelinePrintSelector)
  Validate
}

///|
pub enum OptimizeValidationPolicy {
  FinalModuleOnly
  AfterSegment
} derive(Eq, Show, Debug)

///|
pub fn OptimizeValidationPolicy::final_module_only() -> OptimizeValidationPolicy {
  FinalModuleOnly
}

///|
pub fn OptimizeValidationPolicy::after_segment() -> OptimizeValidationPolicy {
  AfterSegment
}

///|
pub struct InliningOptions {
  no_op : Bool
} derive(Eq, Show, Debug)

///|
pub fn InliningOptions::new() -> InliningOptions {
  { no_op: true }
}

///|
pub struct OptimizeOptions {
  optimize_level : Int
  shrink_level : Int
  inlining : InliningOptions
  monomorphize_min_benefit : Int
  closed_world : Bool
  zero_filled_memory : Bool
  low_memory_unused : Bool
  low_memory_bound : UInt64
  traps_never_happen : Bool
  validation_policy : OptimizeValidationPolicy
  stack_function_passes : Bool
} derive(Eq, Show, Debug)

///|
pub fn OptimizeOptions::new(
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
  inlining? : InliningOptions = InliningOptions::new(),
  monomorphize_min_benefit? : Int = 5,
  closed_world? : Bool = false,
  zero_filled_memory? : Bool = false,
  low_memory_unused? : Bool = false,
  low_memory_bound? : UInt64 = 1024UL,
  traps_never_happen? : Bool = false,
  validation_policy? : OptimizeValidationPolicy = OptimizeValidationPolicy::final_module_only(),
  stack_function_passes? : Bool = true,
) -> OptimizeOptions {
  {
    optimize_level,
    shrink_level,
    inlining,
    monomorphize_min_benefit,
    closed_world,
    zero_filled_memory,
    low_memory_unused,
    low_memory_bound,
    traps_never_happen,
    validation_policy,
    stack_function_passes,
  }
}

///|
const CMD_VERSION : String = "v0.1.0"

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
fn parse_tracing_level_name(raw : String) -> CliTracingLevel? {
  match ascii_lower(raw.trim().to_string()) {
    "pass" => Some(CliTracingLevel::pass())
    "phase" => Some(CliTracingLevel::phase())
    "helper" => Some(CliTracingLevel::helper())
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
  normalized.sub(start=last_sep + 1).to_string()
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
    let stem = normalized.sub(end=last_dot).to_string()
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
fn string_to_bytes_lossy(text : String) -> Bytes {
  let out = @buffer.new(size_hint=text.length())
  for c in text {
    let code = c.to_int()
    if code >= 0 && code <= 255 {
      out.write_byte(code.to_byte())
    } else {
      out.write_byte('?'.to_int().to_byte())
    }
  }
  out.to_bytes()
}

///|
fn cmd_cli_parse_error_message(err : CliParseError) -> String {
  match err {
    MissingFlagValue(flag) => "missing value for flag \{flag}"
    InvalidInputFormat(format) => "invalid input format: \{format}"
    StdinNeedsFormat => "stdin requires --input-format <wasm|wat|wast>"
    UnknownShortFlag(flag) => "unknown short flag: -\{flag}"
    InvalidLongFlag(flag) => "invalid long flag: --\{flag}"
    UnexpectedFlagValue(flag) => "unexpected value for flag \{flag}"
    InvalidDumpPath(path) => "dump path must end with .wasm or .wat: \{path}"
    InvalidOptimizationFlag(flag) => "invalid optimization flag: \{flag}"
    InvalidTrapMode(mode) => "invalid trap mode: \{mode}"
    InvalidTracingLevel(level) => "invalid tracing level: \{level}"
  }
}

///|
fn cmd_encode_error_message(err : CmdEncodeError) -> String {
  match err {
    Encode(inner) => inner.to_string()
    Adapter(msg) => msg
  }
}

///|
fn cmd_error_message(err : CmdError) -> String {
  match err {
    CliParse(e) => cmd_cli_parse_error_message(e)
    UnknownPassFlag(flag) => "unknown pass flag: \{flag}"
    InvalidConfig(msg) => "invalid config: \{msg}"
    ConfigNotFound(path) => "config not found: \{path}"
    ConfigReadFailed(msg) => "config read failed: \{msg}"
    InputReadFailed(msg) => "input read failed: \{msg}"
    SpecFailed(msg) => "spec failed: \{msg}"
    TextLoweringFailed(msg) => "text lowering failed: \{msg}"
    DecodeFailed(path, err) => "decode failed for \{path}: \{err}"
    OptimizeFailed(msg) => msg
    EncodeFailed(path, err) =>
      "encode failed for \{path}: \{cmd_encode_error_message(err)}"
    OutputWriteFailed(msg) => "output write failed: \{msg}"
    AmbiguousOutputFile(path) =>
      "ambiguous output target for multiple inputs: \{path}"
    NoInputFiles => "no input files"
  }
}

///|
fn cmd_error_stderr_bytes(err : CmdError) -> Bytes {
  string_to_bytes_lossy("error: \{cmd_error_message(err)}\n")
}

///|
test "cmd_error_stderr_bytes preserves literal newlines for optimize errors" {
  let text = bytes_to_string_lossy(
    cmd_error_stderr_bytes(OptimizeFailed("line one\nline two")),
  )
  assert_true(text.contains("line one\nline two"), msg=text)
  assert_false(text.contains("\\n"), msg=text)
}

///|
test "cmd_error_stderr_bytes preserves literal newlines for adapter encode errors" {
  let text = bytes_to_string_lossy(
    cmd_error_stderr_bytes(
      EncodeFailed("a.wasm", CmdEncodeError::adapter("line one\nline two")),
    ),
  )
  assert_true(text.contains("line one\nline two"), msg=text)
  assert_false(text.contains("\\n"), msg=text)
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
/// Parse configuration JSON from a file or stdin string.
/// This parser is permissive by design: unknown keys are ignored, alias keys are
/// supported, and bad leaf values are dropped so that partial config can still be
/// combined with CLI/environment layers instead of aborting entirely.
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
  let mut closed_world : Bool? = None
  let mut tracing : CliTracingLevel? = None
  let mut debug_serial_passes = false
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

  match root_obj.get("tracing") {
    Some(String(raw)) =>
      match parse_tracing_level_name(raw) {
        Some(level) => tracing = Some(level)
        None => ()
      }
    _ => ()
  }
  match root_obj.get("debugSerialPasses") {
    Some(value) =>
      match parse_json_bool(value) {
        Some(parsed_value) => debug_serial_passes = parsed_value
        None => ()
      }
    None => ()
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
      let closed_world_value = match options.get("closedWorld") {
        Some(v) => Some(v)
        None => options.get("closed-world")
      }
      match closed_world_value {
        Some(value) =>
          match parse_json_bool(value) {
            Some(parsed_value) => closed_world = Some(parsed_value)
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
      closed_world~,
      tracing~,
      debug_serial_passes~,
    ),
  )
}

///|
/// Parse environment overlay variables into a parse result shape.
/// Environment values follow the same normalization rules as `parse_config_json`
/// (trimmed values, alias keys, permissive leaf handling), and they are merged
/// later with config+CLI using explicit precedence.
fn parse_env_overlay(io : CmdIO) -> CliParseResult {
  let mut input_format : CliInputFormat? = None
  let output_targets : Array[CliOutputTarget] = []
  let pass_flags : Array[String] = []
  let optimize_flags : Array[CliOptimizationFlag] = []
  let mut trap_mode : TrapMode? = None
  let mut monomorphize_min_benefit : Int? = None
  let mut low_memory_unused : Bool? = None
  let mut low_memory_bound : UInt64? = None
  let mut closed_world : Bool? = None
  let mut tracing : CliTracingLevel? = None
  let mut debug_serial_passes = false

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
  match (io.get_env)("STARSHINE_CLOSED_WORLD") {
    Some(raw) =>
      match parse_bool_string(raw) {
        Some(parsed_value) => closed_world = Some(parsed_value)
        None => ()
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_TRACING") {
    Some(raw) =>
      match parse_tracing_level_name(raw) {
        Some(level) => tracing = Some(level)
        None => ()
      }
    None => ()
  }
  match (io.get_env)("STARSHINE_DEBUG_SERIAL_PASSES") {
    Some(raw) =>
      match parse_bool_string(raw) {
        Some(parsed_value) => debug_serial_passes = parsed_value
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
    closed_world~,
    tracing~,
    debug_serial_passes~,
  )
}

///|
/// Merge config + env + cli parse layers with explicit precedence:
/// CLI overrides env, env overrides config for scalar fields and selected lists.
/// Input globs are concatenated with dedupe to preserve all sources while avoiding
/// duplicate entries from overlapping layers.
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
  let glob_enabled = cli.glob_enabled

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
  let closed_world = match cli.closed_world {
    Some(v) => Some(v)
    None =>
      match env.closed_world {
        Some(v) => Some(v)
        None => config.closed_world
      }
  }
  let tracing = match cli.tracing {
    Some(level) => Some(level)
    None =>
      match env.tracing {
        Some(level) => Some(level)
        None => config.tracing
      }
  }
  let debug_serial_passes = cli.debug_serial_passes ||
    env.debug_serial_passes ||
    config.debug_serial_passes
  CliParseResult::new(
    config_path~,
    input_globs~,
    glob_enabled~,
    debug_serial_passes~,
    read_stdin~,
    input_format~,
    output_targets~,
    pass_flags~,
    optimize_flags~,
    trap_mode~,
    monomorphize_min_benefit~,
    low_memory_unused~,
    low_memory_bound~,
    closed_world~,
    tracing~,
  )
}

///|
/// Config path resolution order: explicit CLI > STARSHINE_CONFIG env var > default
/// package config file. Returns whether a real config was selected versus default.
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
/// Split globs into literal paths vs wildcard patterns, dedupe early, expand only
/// patterns with the adapter when enabled, and preserve deterministic ordering.
fn resolve_input_files_with_glob(
  globs : Array[String],
  io : CmdIO,
  glob_enabled : Bool,
) -> Array[String] {
  let literal = Array::new()
  let patterns = Array::new()
  for raw in globs {
    let normalized = normalize_cli_path(raw.trim().to_string())
    if normalized.length() == 0 {
      continue
    }
    if glob_enabled && has_glob_wildcard(normalized) {
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
/// Compute effective optimize/shrink levels as maxima across explicit `-O` flags and
/// preset shortcuts, matching precedence rules used later by explicit pipeline flags.
fn resolve_optimize_levels(flags : Array[CliOptimizationFlag]) -> (Int, Int) {
  let mut optimize_level = 0
  let mut shrink_level = 0
  for flag in flags {
    match flag {
      OLevel(level, size_bias) => {
        optimize_level = max_int(optimize_level, level)
        if size_bias {
          shrink_level = max_int(shrink_level, level)
        }
      }
      OptimizePreset => optimize_level = max_int(optimize_level, 2)
      ShrinkPreset => shrink_level = max_int(shrink_level, 2)
    }
  }
  (optimize_level, shrink_level)
}

///|
/// If explicit CLI pass flags are absent, synthesize exactly one default pass name
/// (`shrink` preferred over `optimize`) from the highest requested levels.
fn resolve_effective_pass_flags(
  resolved_passes : Array[String],
  optimize_level : Int,
  shrink_level : Int,
) -> Array[String] {
  let out : Array[String] = []
  for pass in resolved_passes {
    out.push(pass)
  }
  if out.length() > 0 {
    return out
  }
  if shrink_level > 0 {
    out.push("shrink")
  } else if optimize_level > 0 {
    out.push("optimize")
  }
  out
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
  closed_world : Bool,
  low_memory_unused : Bool,
  low_memory_bound : UInt64,
  debug_serial_passes : Bool,
) -> OptimizeOptions {
  OptimizeOptions::new(
    optimize_level~,
    shrink_level~,
    inlining=default_inlining_options(),
    monomorphize_min_benefit~,
    closed_world~,
    low_memory_unused~,
    low_memory_bound~,
    traps_never_happen~,
    validation_policy=if debug_serial_passes {
      OptimizeValidationPolicy::after_segment()
    } else {
      OptimizeValidationPolicy::final_module_only()
    },
    stack_function_passes=!debug_serial_passes,
  )
}

///|
fn optimize_options_to_hot_pipeline_options(
  options : OptimizeOptions,
  validate_final_module? : Bool = true,
  trace? : ((String) -> Unit)? = None,
) -> @passes.HotPipelineOptions {
  @passes.HotPipelineOptions::new(
    verify_policy=match options.validation_policy {
      AfterSegment => @passes.HotPipelineVerifyPolicy::after_each_pass()
      FinalModuleOnly => @passes.HotPipelineVerifyPolicy::final_module_only()
    },
    validate_final_module~,
    closed_world=options.closed_world,
    trace~,
    perf=match trace {
      Some(cb) =>
        Some(
          @passes.HotPerfSession::new(
            trace=cb,
            trace_checkpoints=false,
            trace_counters=false,
          ),
        )
      None => None
    },
  )
}

///|
fn optimize_module_with_pass_flags(
  mod : Module,
  pass_flags : Array[String],
  options : OptimizeOptions,
  validate_final_module? : Bool = true,
) -> Result[Module, String] {
  @passes.run_hot_pipeline(
    mod,
    optimize_options_to_hot_pipeline_options(options, validate_final_module~),
    pass_flags,
  )
}

///|
fn optimize_module_with_pass_flags_trace(
  mod : Module,
  pass_flags : Array[String],
  options : OptimizeOptions,
  trace : (String) -> Unit,
  validate_final_module? : Bool = true,
  trace_level? : OptimizeTracingLevel = OptimizeTracingLevel::pass(),
) -> Result[Module, String] {
  let _ = trace_level
  @passes.run_hot_pipeline(
    mod,
    optimize_options_to_hot_pipeline_options(
      options,
      validate_final_module~,
      trace=Some(trace),
    ),
    pass_flags,
  )
}

///|
fn cmd_path_has_ascii_suffix_ignore_case(
  path : String,
  suffix : String,
) -> Bool {
  if path.length() < suffix.length() {
    return false
  }
  let start = path.length() - suffix.length()
  let mut i = 0
  while i < suffix.length() {
    if ascii_lower(path[start + i].to_string()) != suffix[i].to_string() {
      return false
    }
    i += 1
  }
  true
}

///|
fn cmd_dump_output_format(path : String) -> CmdPipelineDumpFormat? {
  if cmd_path_has_ascii_suffix_ignore_case(path, ".wasm") {
    Some(CmdPipelineDumpFormat::Wasm)
  } else if cmd_path_has_ascii_suffix_ignore_case(path, ".wat") {
    Some(CmdPipelineDumpFormat::Wat)
  } else {
    None
  }
}

///|
fn cmd_dump_pass_target(flag : String) -> String? {
  if flag.length() <= 5 || flag.sub(end=5).to_string() != "dump=" {
    return None
  }
  Some(flag.sub(start=5).to_string())
}

///|
fn cmd_print_pass_target(flag : String) -> (String, String)? {
  if !flag.has_prefix("print-") {
    return None
  }
  let mut i = 6
  while i < flag.length() {
    if flag[i] == '=' {
      let kind = flag.sub(start=6, end=i).to_string()
      let selector = flag.sub(start=i + 1).to_string()
      if kind.length() == 0 || selector.length() == 0 {
        return None
      }
      return Some((kind, selector))
    }
    i += 1
  }
  None
}

///|
fn cmd_is_supported_print_kind(kind : String) -> Bool {
  match kind {
    "type"
    | "func"
    | "import"
    | "table"
    | "memory"
    | "global"
    | "export"
    | "tag"
    | "elem"
    | "data" => true
    _ => false
  }
}

///|
fn cmd_parse_print_selector(raw : String) -> CmdPipelinePrintSelector? {
  let trimmed = raw.trim().to_string()
  if trimmed.length() == 0 {
    return None
  }
  if trimmed.length() >= 2 &&
    trimmed[0] == '(' &&
    trimmed[trimmed.length() - 1] == ')' {
    let inner = trimmed.sub(start=1, end=trimmed.length() - 1).to_string()
    match parse_non_negative_decimal(inner) {
      Some(idx) =>
        return Some(CmdPipelinePrintSelector::Index(idx.reinterpret_as_uint()))
      None => ()
    }
  }
  match parse_non_negative_decimal(trimmed) {
    Some(idx) =>
      Some(CmdPipelinePrintSelector::Index(idx.reinterpret_as_uint()))
    None => Some(CmdPipelinePrintSelector::Name(trimmed))
  }
}

///|
fn cmd_pipeline_step_optimize_count(steps : Array[CmdPipelineStep]) -> Int {
  let mut count = 0
  for step in steps {
    match step {
      PipelinePass(_) => count += 1
      _ => ()
    }
  }
  count
}

///|
fn cmd_resolve_pipeline_steps(
  pass_flags : Array[String],
) -> Result[Array[CmdPipelineStep], CmdError] {
  let out : Array[CmdPipelineStep] = []
  for flag in pass_flags {
    if flag == "validate" {
      out.push(CmdPipelineStep::Validate)
      continue
    }
    match cmd_dump_pass_target(flag) {
      Some(path) =>
        match cmd_dump_output_format(path) {
          Some(format) => {
            out.push(CmdPipelineStep::Dump(path, format))
            continue
          }
          None =>
            return Err(
              CmdError::CliParse(CliParseError::invalid_dump_path(path)),
            )
        }
      None => ()
    }
    match cmd_print_pass_target(flag) {
      Some((kind, raw_selector)) =>
        if !cmd_is_supported_print_kind(kind) {
          return Err(CmdError::unknown_pass_flag("print-\{kind}"))
        } else {
          match cmd_parse_print_selector(raw_selector) {
            Some(selector) => {
              out.push(CmdPipelineStep::Print(kind, selector))
              continue
            }
            None => return Err(CmdError::unknown_pass_flag(flag))
          }
        }
      None => ()
    }
    match @passes.pass_registry_lookup(flag) {
      Some(entry) =>
        match entry.category {
          @passes.HotPassRegistryCategory::HotPass
          | @passes.HotPassRegistryCategory::ModulePass
          | @passes.HotPassRegistryCategory::Preset =>
            out.push(CmdPipelineStep::PipelinePass(flag))
          _ => return Err(CmdError::unknown_pass_flag(flag))
        }
      None => return Err(CmdError::unknown_pass_flag(flag))
    }
  }
  Ok(out)
}

///|
fn string_to_bytes(text : String) -> Bytes {
  let buf = @buffer.new(size_hint=text.length())
  for c in text {
    buf.write_byte(c.to_int().to_byte())
  }
  buf.to_bytes()
}

///|
fn cmd_optimize_trace_level_to_string(level : CliTracingLevel) -> String {
  match level {
    Pass => "pass"
    Phase => "phase"
    Helper => "helper"
  }
}

///|
fn cmd_to_optimize_trace_level(level : CliTracingLevel) -> OptimizeTracingLevel {
  match level {
    Pass => OptimizeTracingLevel::pass()
    Phase => OptimizeTracingLevel::phase()
    Helper => OptimizeTracingLevel::helper()
  }
}

///|
fn cmd_trace_optimize_max_passes(io : CmdIO) -> Int? {
  match (io.get_env)("STARSHINE_OPTIMIZE_MAX_PASSES") {
    Some(raw) => parse_non_negative_decimal(raw)
    None => None
  }
}

///|
fn cmd_resolve_optimize_trace_level(
  level : CliTracingLevel?,
) -> OptimizeTracingLevel? {
  match level {
    Some(level) => Some(cmd_to_optimize_trace_level(level))
    None => None
  }
}

///|
fn limit_pass_flags_by_max_passes(
  pass_flags : Array[String],
  max_passes : Int?,
) -> (Array[String], Bool) {
  match max_passes {
    Some(limit) =>
      if limit < pass_flags.length() {
        let out : Array[String] = []
        let mut i = 0
        while i < limit {
          out.push(pass_flags[i])
          i += 1
        }
        (out, true)
      } else {
        (pass_flags, false)
      }
    None => (pass_flags, false)
  }
}

///|
fn cmd_trace_join_pass_flags(flags : Array[String]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < flags.length() {
    if i > 0 {
      out.write_string(",")
    }
    out.write_string(flags[i])
    i += 1
  }
  out.to_string()
}

///|
fn format_pipeline_validation_error(
  stage : String,
  mod : Module,
  err : ValidationError,
) -> String {
  let out = StringBuilder::new()
  out.write_string("\{stage}: \{validation_error_message(err)}")
  match validation_error_func_idx(err) {
    Some(func_idx) => {
      out.write_string("\n\nOffending function idx=\{func_idx}\n")
      out.write_string(mod.pretty_print_func(func_idx))
    }
    None => ()
  }
  out.to_string()
}

///|
fn validate_module_for_pipeline_step(
  mod : Module,
  stage : String,
) -> Result[Unit, CmdError] {
  match validate_module(mod) {
    Ok(_) => Ok(())
    Err(err) =>
      Err(
        CmdError::OptimizeFailed(
          format_pipeline_validation_error(stage, mod, err),
        ),
      )
  }
}

///|
fn write_pipeline_dump(
  io : CmdIO,
  mod : Module,
  path : String,
  format : CmdPipelineDumpFormat,
) -> Result[Unit, CmdError] {
  let bytes = match format {
    Wasm =>
      match (io.encode_module)(mod) {
        Ok(bytes) => bytes
        Err(err) => return Err(CmdError::EncodeFailed(path, err))
      }
    Wat =>
      match (io.print_text_module)(mod) {
        Ok(text) => text
        Err(err) => return Err(CmdError::OptimizeFailed("dump \{path}: \{err}"))
      }
  }
  match (io.write_file)(path, bytes) {
    Ok(_) => Ok(())
    Err(err) => Err(CmdError::OutputWriteFailed("\{path}: \{err}"))
  }
}

///|
fn cmd_name_to_string(name : @lib.Name) -> String {
  let @lib.Name(sv) = name
  sv.to_string()
}

///|
fn cmd_lookup_name_map_index(names : @lib.NameMap?, target : String) -> UInt? {
  match names {
    Some(@lib.NameMap(entries)) =>
      for entry in entries {
        let @lib.NameAssoc(idx, name) = entry
        if cmd_name_to_string(name) == target {
          return Some(idx)
        }
      }
    None => ()
  }
  None
}

///|
fn cmd_lookup_name_map_name(
  names : @lib.NameMap?,
  target_idx : UInt,
) -> String? {
  match names {
    Some(@lib.NameMap(entries)) =>
      for entry in entries {
        let @lib.NameAssoc(idx, name) = entry
        if idx == target_idx {
          return Some(cmd_name_to_string(name))
        }
      }
    None => ()
  }
  None
}

///|
fn cmd_flatten_type_sec(type_sec : @lib.TypeSec) -> Array[@lib.SubType] {
  let @lib.TypeSec(rec_types) = type_sec
  let subtypes : Array[@lib.SubType] = []
  for rec_type in rec_types {
    match rec_type {
      @lib.SingleRecType(sub_type) => subtypes.push(sub_type)
      @lib.GroupRecType(group) =>
        for sub_type in group {
          subtypes.push(sub_type)
        }
    }
  }
  subtypes
}

///|
fn cmd_print_val_type_list(types : Array[@lib.ValType]) -> String {
  let out = StringBuilder::new()
  out.write_char('[')
  let mut i = 0
  while i < types.length() {
    if i > 0 {
      out.write_char(' ')
    }
    out.write_string(types[i].pretty_print(PrettyPrintContext::new()))
    i += 1
  }
  out.write_char(']')
  out.to_string()
}

///|
fn cmd_print_type_idx_list(type_idxs : Array[@lib.TypeIdx]) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < type_idxs.length() {
    if i > 0 {
      out.write_char(' ')
    }
    out.write_string(type_idxs[i].pretty_print(PrettyPrintContext::new()))
    i += 1
  }
  out.to_string()
}

///|
fn cmd_print_comp_type(comp_type : @lib.CompType) -> String {
  match comp_type {
    @lib.FuncCompType(params, results) =>
      "(Func \{cmd_print_val_type_list(params)} \{cmd_print_val_type_list(results)})"
    _ => comp_type.pretty_print(PrettyPrintContext::new())
  }
}

///|
fn cmd_print_sub_type(sub_type : @lib.SubType) -> String {
  match sub_type {
    @lib.CompTypeSubType(_, comp_type) =>
      "(Sub Final \{cmd_print_comp_type(comp_type)})"
    @lib.SubType(is_final, super_types, _, comp_type) => {
      if super_types.is_empty() && !is_final {
        return cmd_print_comp_type(comp_type)
      }
      let prefix = if is_final { "(Sub Final " } else { "(Sub " }
      if super_types.is_empty() {
        prefix + cmd_print_comp_type(comp_type) + ")"
      } else {
        prefix +
        cmd_print_type_idx_list(super_types) +
        " " +
        cmd_print_comp_type(comp_type) +
        ")"
      }
    }
  }
}

///|
fn cmd_print_selector_text(selector : CmdPipelinePrintSelector) -> String {
  match selector {
    Index(idx) => "(\{idx})"
    Name(name) => "\"\{name}\""
  }
}

///|
fn cmd_print_lookup_failed(
  kind : String,
  selector : CmdPipelinePrintSelector,
) -> CmdError {
  CmdError::OptimizeFailed(
    "print \{kind}: no item matched selector \{cmd_print_selector_text(selector)}",
  )
}

///|
fn cmd_print_kind_label(kind : String) -> String {
  match kind {
    "type" => "Type"
    "func" => "Func"
    "import" => "Import"
    "table" => "Table"
    "memory" => "Memory"
    "global" => "Global"
    "export" => "Export"
    "tag" => "Tag"
    "elem" => "Elem"
    "data" => "Data"
    _ => kind
  }
}

///|
fn cmd_module_item_names(mod : Module, kind : String) -> @lib.NameMap? {
  match mod.name_sec {
    Some(name_sec) =>
      match kind {
        "type" => name_sec.type_names
        "func" => name_sec.func_names
        "table" => name_sec.table_names
        "memory" => name_sec.memory_names
        "global" => name_sec.global_names
        "tag" => name_sec.tag_names
        "elem" => name_sec.elem_names
        "data" => name_sec.data_names
        _ => None
      }
    None => None
  }
}

///|
fn cmd_print_label(kind : String, idx : UInt, name? : String? = None) -> String {
  match name {
    Some(name) if name.length() > 0 =>
      "\{cmd_print_kind_label(kind)}[\{idx} \{name}]"
    _ => "\{cmd_print_kind_label(kind)}[\{idx}]"
  }
}

///|
fn cmd_resolve_named_section_index(
  mod : Module,
  kind : String,
  selector : CmdPipelinePrintSelector,
  count : Int,
) -> Result[(UInt, String?), CmdError] {
  let names = cmd_module_item_names(mod, kind)
  match selector {
    Index(idx) => {
      if idx.reinterpret_as_int() >= count {
        return Err(cmd_print_lookup_failed(kind, selector))
      }
      Ok((idx, cmd_lookup_name_map_name(names, idx)))
    }
    Name(target) =>
      match cmd_lookup_name_map_index(names, target) {
        Some(idx) if idx.reinterpret_as_int() < count => Ok((idx, Some(target)))
        _ => Err(cmd_print_lookup_failed(kind, selector))
      }
  }
}

///|
fn cmd_lookup_import_index(
  imports : Array[@lib.Import],
  target : String,
) -> UInt? {
  let mut field_match : UInt? = None
  let mut i = 0
  while i < imports.length() {
    let @lib.Import(module_name, field_name, _) = imports[i]
    let module_text = cmd_name_to_string(module_name)
    let field_text = cmd_name_to_string(field_name)
    if target == "\{module_text}.\{field_text}" {
      return Some(i.reinterpret_as_uint())
    }
    if field_match is None && target == field_text {
      field_match = Some(i.reinterpret_as_uint())
    }
    i += 1
  }
  field_match
}

///|
fn cmd_lookup_export_index(
  exports : Array[@lib.Export],
  target : String,
) -> UInt? {
  let mut i = 0
  while i < exports.length() {
    let @lib.Export(name, _) = exports[i]
    if cmd_name_to_string(name) == target {
      return Some(i.reinterpret_as_uint())
    }
    i += 1
  }
  None
}

///|
fn cmd_resolve_import_index(
  selector : CmdPipelinePrintSelector,
  imports : Array[@lib.Import],
) -> Result[(UInt, String?), CmdError] {
  match selector {
    Index(idx) => {
      if idx.reinterpret_as_int() >= imports.length() {
        return Err(cmd_print_lookup_failed("import", selector))
      }
      let @lib.Import(module_name, field_name, _) = imports[idx.reinterpret_as_int()]
      Ok(
        (
          idx,
          Some(
            "\{cmd_name_to_string(module_name)}.\{cmd_name_to_string(field_name)}",
          ),
        ),
      )
    }
    Name(target) =>
      match cmd_lookup_import_index(imports, target) {
        Some(idx) => {
          let @lib.Import(module_name, field_name, _) = imports[idx.reinterpret_as_int()]
          Ok(
            (
              idx,
              Some(
                "\{cmd_name_to_string(module_name)}.\{cmd_name_to_string(field_name)}",
              ),
            ),
          )
        }
        None => Err(cmd_print_lookup_failed("import", selector))
      }
  }
}

///|
fn cmd_resolve_export_index(
  selector : CmdPipelinePrintSelector,
  exports : Array[@lib.Export],
) -> Result[(UInt, String?), CmdError] {
  match selector {
    Index(idx) => {
      if idx.reinterpret_as_int() >= exports.length() {
        return Err(cmd_print_lookup_failed("export", selector))
      }
      let @lib.Export(name, _) = exports[idx.reinterpret_as_int()]
      Ok((idx, Some(cmd_name_to_string(name))))
    }
    Name(target) =>
      match cmd_lookup_export_index(exports, target) {
        Some(idx) => Ok((idx, Some(target)))
        None => Err(cmd_print_lookup_failed("export", selector))
      }
  }
}

///|
fn cmd_indent_print_body(text : String) -> String {
  if text.length() == 0 {
    return "  <empty>\n"
  }
  let out = StringBuilder::new()
  let mut at_line_start = true
  for c in text {
    if at_line_start {
      out.write_string("  ")
      at_line_start = false
    }
    out.write_char(c)
    if c == '\n' {
      at_line_start = true
    }
  }
  if !at_line_start {
    out.write_char('\n')
  }
  out.to_string()
}

///|
fn cmd_write_pipeline_print_log(
  io : CmdIO,
  input_path : String,
  entry_idx : Int,
  label : String,
  body : String,
  write_header : Bool,
) -> Result[Unit, CmdError] {
  let out = StringBuilder::new()
  if write_header {
    out.write_string("Log: \{input_path}\n")
  }
  out.write_string("\{entry_idx}: \{label}\n")
  out.write_string(cmd_indent_print_body(body))
  match (io.write_stderr)(string_to_bytes(out.to_string())) {
    Ok(_) => Ok(())
    Err(err) =>
      Err(
        CmdError::OutputWriteFailed(
          "stderr print log for \{input_path}: \{err}",
        ),
      )
  }
}

///|
fn cmd_resolve_pipeline_print_entry(
  mod : Module,
  kind : String,
  selector : CmdPipelinePrintSelector,
) -> Result[(String, String), CmdError] {
  match kind {
    "type" =>
      match mod.type_sec {
        Some(type_sec) => {
          let subtypes = cmd_flatten_type_sec(type_sec)
          let (idx, name) = match
            cmd_resolve_named_section_index(
              mod,
              kind,
              selector,
              subtypes.length(),
            ) {
            Ok(found) => found
            Err(err) => return Err(err)
          }
          let body = match subtypes.get(idx.reinterpret_as_int()) {
            Some(sub_type) => cmd_print_sub_type(sub_type)
            None => return Err(cmd_print_lookup_failed(kind, selector))
          }
          Ok((cmd_print_label(kind, idx, name~), body))
        }
        None => Err(cmd_print_lookup_failed(kind, selector))
      }
    "func" => {
      let imported_funcs = match mod.import_sec {
        Some(@lib.ImportSec(imports)) => {
          let mut count = 0
          for import_entry in imports {
            match import_entry {
              @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
              _ => ()
            }
          }
          count
        }
        None => 0
      }
      let defined_funcs = match mod.func_sec {
        Some(@lib.FuncSec(type_idxs)) => type_idxs.length()
        None => 0
      }
      let total_funcs = imported_funcs + defined_funcs
      let (idx, name) = match
        cmd_resolve_named_section_index(mod, kind, selector, total_funcs) {
        Ok(found) => found
        Err(err) => return Err(err)
      }
      Ok(
        (
          cmd_print_label(kind, idx, name~),
          mod.pretty_print_func(@lib.FuncIdx::new(idx)),
        ),
      )
    }
    "import" =>
      match mod.import_sec {
        Some(@lib.ImportSec(imports)) => {
          let (idx, name) = match cmd_resolve_import_index(selector, imports) {
            Ok(found) => found
            Err(err) => return Err(err)
          }
          let body = match imports.get(idx.reinterpret_as_int()) {
            Some(import_entry) => import_entry.to_string()
            None => return Err(cmd_print_lookup_failed(kind, selector))
          }
          Ok((cmd_print_label(kind, idx, name~), body))
        }
        None => Err(cmd_print_lookup_failed(kind, selector))
      }
    "table" =>
      match mod.table_sec {
        Some(@lib.TableSec(tables)) => {
          let (idx, name) = match
            cmd_resolve_named_section_index(
              mod,
              kind,
              selector,
              tables.length(),
            ) {
            Ok(found) => found
            Err(err) => return Err(err)
          }
          let body = match tables.get(idx.reinterpret_as_int()) {
            Some(table) => table.to_string()
            None => return Err(cmd_print_lookup_failed(kind, selector))
          }
          Ok((cmd_print_label(kind, idx, name~), body))
        }
        None => Err(cmd_print_lookup_failed(kind, selector))
      }
    "memory" =>
      match mod.mem_sec {
        Some(@lib.MemSec(mems)) => {
          let (idx, name) = match
            cmd_resolve_named_section_index(mod, kind, selector, mems.length()) {
            Ok(found) => found
            Err(err) => return Err(err)
          }
          let body = match mems.get(idx.reinterpret_as_int()) {
            Some(mem) => mem.to_string()
            None => return Err(cmd_print_lookup_failed(kind, selector))
          }
          Ok((cmd_print_label(kind, idx, name~), body))
        }
        None => Err(cmd_print_lookup_failed(kind, selector))
      }
    "global" =>
      match mod.global_sec {
        Some(@lib.GlobalSec(globals)) => {
          let (idx, name) = match
            cmd_resolve_named_section_index(
              mod,
              kind,
              selector,
              globals.length(),
            ) {
            Ok(found) => found
            Err(err) => return Err(err)
          }
          let body = match globals.get(idx.reinterpret_as_int()) {
            Some(global) => global.to_string()
            None => return Err(cmd_print_lookup_failed(kind, selector))
          }
          Ok((cmd_print_label(kind, idx, name~), body))
        }
        None => Err(cmd_print_lookup_failed(kind, selector))
      }
    "export" =>
      match mod.export_sec {
        Some(@lib.ExportSec(exports)) => {
          let (idx, name) = match cmd_resolve_export_index(selector, exports) {
            Ok(found) => found
            Err(err) => return Err(err)
          }
          let body = match exports.get(idx.reinterpret_as_int()) {
            Some(export_entry) => export_entry.to_string()
            None => return Err(cmd_print_lookup_failed(kind, selector))
          }
          Ok((cmd_print_label(kind, idx, name~), body))
        }
        None => Err(cmd_print_lookup_failed(kind, selector))
      }
    "tag" =>
      match mod.tag_sec {
        Some(@lib.TagSec(tags)) => {
          let (idx, name) = match
            cmd_resolve_named_section_index(mod, kind, selector, tags.length()) {
            Ok(found) => found
            Err(err) => return Err(err)
          }
          let body = match tags.get(idx.reinterpret_as_int()) {
            Some(tag) => tag.to_string()
            None => return Err(cmd_print_lookup_failed(kind, selector))
          }
          Ok((cmd_print_label(kind, idx, name~), body))
        }
        None => Err(cmd_print_lookup_failed(kind, selector))
      }
    "elem" =>
      match mod.elem_sec {
        Some(@lib.ElemSec(elems)) => {
          let (idx, name) = match
            cmd_resolve_named_section_index(mod, kind, selector, elems.length()) {
            Ok(found) => found
            Err(err) => return Err(err)
          }
          let body = match elems.get(idx.reinterpret_as_int()) {
            Some(elem) => elem.to_string()
            None => return Err(cmd_print_lookup_failed(kind, selector))
          }
          Ok((cmd_print_label(kind, idx, name~), body))
        }
        None => Err(cmd_print_lookup_failed(kind, selector))
      }
    "data" =>
      match mod.data_sec {
        Some(@lib.DataSec(datas)) => {
          let (idx, name) = match
            cmd_resolve_named_section_index(mod, kind, selector, datas.length()) {
            Ok(found) => found
            Err(err) => return Err(err)
          }
          let body = match datas.get(idx.reinterpret_as_int()) {
            Some(data) => data.to_string()
            None => return Err(cmd_print_lookup_failed(kind, selector))
          }
          Ok((cmd_print_label(kind, idx, name~), body))
        }
        None => Err(cmd_print_lookup_failed(kind, selector))
      }
    _ => Err(CmdError::unknown_pass_flag("print-\{kind}"))
  }
}

///|
fn run_pipeline_pass_segment(
  io : CmdIO,
  input_path : String,
  mod : Module,
  pass_flags : Array[String],
  options : OptimizeOptions,
  trace_optimize : Bool,
  trace_level : OptimizeTracingLevel?,
) -> Result[Module, CmdError] {
  if pass_flags.length() == 0 {
    return Ok(mod)
  }
  if trace_optimize {
    let resolved_trace_level = match trace_level {
      Some(level) => level
      None => OptimizeTracingLevel::pass()
    }
    match
      optimize_module_with_pass_flags_trace(
        mod,
        pass_flags,
        options,
        fn(msg) { cmd_trace_emit(io, true, "input \{input_path}:opt \{msg}") },
        validate_final_module=false,
        trace_level=resolved_trace_level,
      ) {
      Ok(out) => Ok(out)
      Err(e) => Err(CmdError::OptimizeFailed("\{input_path}: \{e}"))
    }
  } else {
    match
      optimize_module_with_pass_flags(
        mod,
        pass_flags,
        options,
        validate_final_module=false,
      ) {
      Ok(out) => Ok(out)
      Err(e) => Err(CmdError::OptimizeFailed("\{input_path}: \{e}"))
    }
  }
}

///|
fn cmd_post_encode_repro_note(
  io : CmdIO,
  mod : Module,
  pass_flags : Array[String],
  options : OptimizeOptions,
  optimize_level : Int,
  shrink_level : Int,
  traps_never_happen : Bool,
  monomorphize_min_benefit : Int,
  closed_world : Bool,
  low_memory_unused : Bool,
  low_memory_bound : UInt64,
) -> String {
  let _ = io
  let _ = mod
  let _ = options
  let args = StringBuilder::new()
  let mut needs_space = false
  let write_arg = fn(text : String) {
    if needs_space {
      args.write_char(' ')
    }
    args.write_string(text)
    needs_space = true
  }
  for flag in pass_flags {
    write_arg("--\{flag}")
  }
  if optimize_level > 0 {
    write_arg("--optimize-level \{optimize_level}")
  }
  if shrink_level > 0 {
    write_arg("--shrink-level \{shrink_level}")
  }
  if traps_never_happen {
    write_arg("--traps-never-happen")
  }
  if monomorphize_min_benefit != 5 {
    write_arg("--monomorphize-min-benefit \{monomorphize_min_benefit}")
  }
  if closed_world {
    write_arg("--closed-world")
  }
  if low_memory_unused {
    write_arg("--low-memory-unused")
  }
  if low_memory_bound != 1024UL {
    write_arg("--low-memory-bound \{low_memory_bound}")
  }
  let args_text = args.to_string()
  let suffix = if args_text.length() > 0 { " \{args_text}" } else { "" }
  "\n\nRepro hint: rerun the active hot pipeline with `starshine --debug-serial-passes --tracing pass\{suffix} <input>`."
}

///|
test "cmd_post_encode_repro_note reflects active hot pipeline flags" {
  let note = cmd_post_encode_repro_note(
    CmdIO::new(),
    Module::new(),
    ["vacuum"],
    OptimizeOptions::new(),
    0,
    0,
    false,
    5,
    false,
    false,
    1024UL,
  )
  assert_true(note.contains("vacuum"))
  assert_false(note.contains("currently disabled"))
  assert_true(note.contains("--debug-serial-passes"))
}

///|
fn cmd_append_error_note(err : CmdError, note : String) -> CmdError {
  match err {
    EncodeFailed(path, inner) =>
      CmdError::EncodeFailed(
        path,
        CmdEncodeError::adapter(cmd_encode_error_message(inner) + note),
      )
    OptimizeFailed(msg) => CmdError::OptimizeFailed(msg + note)
    _ => err
  }
}

///|
fn cmd_trace_emit(io : CmdIO, enabled : Bool, msg : String) -> Unit {
  if !enabled {
    return
  }
  ignore((io.write_stderr)(string_to_bytes("[trace] \{msg}\n")))
}

///|
fn append_help_line(out : StringBuilder, flag : String, desc : String) -> Unit {
  for c in "  \{flag}\n      \{desc}\n" {
    out.write_char(c)
  }
}

///|
pub fn cmd_version_text() -> String {
  CMD_VERSION
}

///|
pub fn cmd_help_text() -> String {
  let out = StringBuilder::new()
  for
    c in "Starshine Wasm Binary Toolkit \{cmd_version_text()}\nFast parsing, validation, optimization, and rewriting for Wasm modules.\n\nUsage:\n  starshine [flags] [passes] <input...>\n  starshine spec <tests/spec/*.wast ...>\n\nFlags and options:\n" {
    out.write_char(c)
  }
  append_help_line(
    out, "spec <tests/spec/*.wast ...>", "Run the wast spec harness over one or more .wast files.",
  )
  append_help_line(out, "-h, --help", "Show this help text.")
  append_help_line(out, "-V, --version", "Show CLI version.")
  append_help_line(
    out, "--", "Stop option parsing; remaining args are input paths.",
  )
  append_help_line(
    out, "-c, --config[=PATH]", "Load config JSON, defaulting to starshine.config.json when no PATH is given.",
  )
  append_help_line(
    out, "-g, --glob", "Expand wildcard inputs via filesystem enumeration.",
  )
  append_help_line(out, "--stdin", "Read one module from stdin.")
  append_help_line(
    out, "--format <wasm|wat|wast>", "Set input format, required with --stdin.",
  )
  append_help_line(out, "-s, --stdout", "Write optimized wasm bytes to stdout.")
  append_help_line(
    out, "-o, --out <PATH>", "Write output to a single file path.",
  )
  append_help_line(
    out, "-d, --out-dir <DIR>", "Write outputs to a directory, preserving per-input basenames.",
  )
  append_help_line(
    out, "--dump <PATH>", "Write the current module state to a .wasm or .wat file at that point in the pass queue.",
  )
  append_help_line(
    out, "--validate", "Run module validation at that point in the pass queue.",
  )
  append_help_line(
    out, "--print-type <name|index>", "Log a type entry from the current module state to stderr at that point in the pass queue.",
  )
  append_help_line(
    out, "--print-func <name|index>", "Log a function entry from the current module state to stderr at that point in the pass queue.",
  )
  append_help_line(
    out, "--print-import <name|index>", "Log an import entry from the current module state to stderr at that point in the pass queue.",
  )
  append_help_line(
    out, "--print-table <name|index>", "Log a table entry from the current module state to stderr at that point in the pass queue.",
  )
  append_help_line(
    out, "--print-memory <name|index>", "Log a memory entry from the current module state to stderr at that point in the pass queue.",
  )
  append_help_line(
    out, "--print-global <name|index>", "Log a global entry from the current module state to stderr at that point in the pass queue.",
  )
  append_help_line(
    out, "--print-export <name|index>", "Log an export entry from the current module state to stderr at that point in the pass queue.",
  )
  append_help_line(
    out, "--print-tag <name|index>", "Log a tag entry from the current module state to stderr at that point in the pass queue.",
  )
  append_help_line(
    out, "--print-elem <name|index>", "Log an elem entry from the current module state to stderr at that point in the pass queue.",
  )
  append_help_line(
    out, "--print-data <name|index>", "Log a data entry from the current module state to stderr at that point in the pass queue.",
  )
  append_help_line(
    out, "--optimize", "Apply the default optimization preset pipeline.",
  )
  append_help_line(
    out, "--shrink", "Apply the default size-oriented shrink preset pipeline.",
  )
  append_help_line(
    out, "-O[level][z]", "Set optimization level; optional trailing z applies size bias.",
  )
  append_help_line(out, "--optimize-level <N>", "Set explicit optimize level.")
  append_help_line(out, "--shrink-level <N>", "Set explicit shrink level.")
  append_help_line(
    out, "--trap-mode <allow|never>", "Control whether optimizations assume traps may happen.",
  )
  append_help_line(out, "--traps-never-happen", "Alias for --trap-mode never.")
  append_help_line(out, "--traps-may-happen", "Alias for --trap-mode allow.")
  append_help_line(
    out, "--closed-world", "Allow passes to assume a closed-world module graph when required for whole-program GC rewrites.",
  )
  append_help_line(
    out, "--no-closed-world", "Disable closed-world-only optimizations.",
  )
  append_help_line(
    out, "--tracing <pass|phase|helper>", "Set optimization tracing level.",
  )
  append_help_line(
    out, "--debug-serial-passes", "Debug mode: run one pass per segment, validate after each pass, and revalidate encoded output.",
  )
  append_help_line(
    out, "--monomorphize-min-benefit <N>", "Set monomorphization benefit threshold.",
  )
  append_help_line(
    out, "--low-memory-unused", "Enable low-memory-unused optimization mode.",
  )
  append_help_line(
    out, "--no-low-memory-unused", "Disable low-memory-unused optimization mode.",
  )
  append_help_line(
    out, "--low-memory-bound <N>", "Set low-memory optimization bound in bytes.",
  )
  for c in "\nPasses (use as --<name>):\n" {
    out.write_char(c)
  }
  for entry in @passes.pass_registry_all() {
    match entry.category {
      @passes.HotPassRegistryCategory::HotPass
      | @passes.HotPassRegistryCategory::Preset =>
        append_help_line(out, "--\{entry.name}", entry.summary)
      _ => ()
    }
  }
  out.to_string()
}

///|
fn spec_cmd_help_text() -> String {
  "Usage:\n  starshine spec [-g|--glob] <tests/spec/*.wast ...>\n\nOptions:\n  -g, --glob\n      Expand wildcard inputs via filesystem enumeration.\n  -h, --help\n      Show spec subcommand help.\n"
}

///|
fn parse_spec_cmd_args(
  args : Array[String],
) -> Result[(Bool, Array[String], Bool), CmdError] {
  let mut glob_enabled = false
  let mut help_requested = false
  let mut positional_only = false
  let globs : Array[String] = []
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if positional_only {
      let normalized = normalize_cli_path(arg.trim().to_string())
      if normalized.length() > 0 {
        append_unique_string(globs, normalized)
      }
      index += 1
      continue
    }
    match arg {
      "--" => {
        positional_only = true
        index += 1
      }
      "-h" | "--help" => {
        help_requested = true
        index += 1
      }
      "-g" | "--glob" => {
        glob_enabled = true
        index += 1
      }
      _ => {
        if arg.length() > 0 && arg[0] == '-' {
          return Err(
            CmdError::CliParse(
              CliParseError::invalid_long_flag(arg.sub(start=1).to_string()),
            ),
          )
        }
        let normalized = normalize_cli_path(arg.trim().to_string())
        if normalized.length() > 0 {
          append_unique_string(globs, normalized)
        }
        index += 1
      }
    }
  }
  Ok((glob_enabled, globs, help_requested))
}

///|
fn spec_failed_preview(
  summary : @wast.WastSpecRunSummary,
  limit : Int,
) -> String {
  let out : Array[String] = []
  for report in summary.files {
    match report.status {
      @wast.WastSpecFileStatus::Failed(msg) =>
        out.push("\{report.path}: \{msg}")
      _ => ()
    }
  }
  let builder = StringBuilder::new()
  let mut i = 0
  while i < out.length() && i < limit {
    if i > 0 {
      builder.write_string(" | ")
    }
    builder.write_string(out[i])
    i += 1
  }
  builder.to_string()
}

///|
fn run_spec_cmd_with_adapter(
  args : Array[String],
  io : CmdIO,
) -> Result[CmdRunSummary, CmdError] {
  let (glob_enabled, globs, help_requested) = match parse_spec_cmd_args(args) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if globs.length() == 0 || help_requested {
    match (io.write_stdout)(string_to_bytes(spec_cmd_help_text())) {
      Ok(_) => return Ok(CmdRunSummary::new())
      Err(e) =>
        return Err(
          CmdError::OutputWriteFailed("stdout for spec help text: \{e}"),
        )
    }
  }

  let input_files = resolve_input_files_with_glob(globs, io, glob_enabled)
  if input_files.length() == 0 {
    return Err(CmdError::NoInputFiles)
  }

  let files : Array[(String, String)] = []
  for path in input_files {
    let bytes = match (io.read_file)(path) {
      Ok(v) => v
      Err(e) => return Err(CmdError::InputReadFailed("\{path}: \{e}"))
    }
    files.push((path, bytes_to_string_lossy(bytes)))
  }

  let summary = @wast.run_wast_spec_suite(files)
  let summary_line = "spec suite summary: total=\{summary.total_files} passed=\{summary.passed_files} skipped=\{summary.skipped_files} failed=\{summary.failed_files}\n"
  match (io.write_stdout)(string_to_bytes(summary_line)) {
    Ok(_) => ()
    Err(e) =>
      return Err(CmdError::OutputWriteFailed("stdout for spec summary: \{e}"))
  }

  if summary.failed_files > 0 {
    let preview = spec_failed_preview(summary, 20)
    let preview_line = "failed files preview: \{preview}\n"
    match (io.write_stdout)(string_to_bytes(preview_line)) {
      Ok(_) => ()
      Err(e) =>
        return Err(
          CmdError::OutputWriteFailed("stdout for spec failure preview: \{e}"),
        )
    }
    return Err(CmdError::SpecFailed(preview_line.trim().to_string()))
  }

  Ok(CmdRunSummary::new(input_files~, resolved_passes=["spec"]))
}

///|
test "limit_pass_flags_by_max_passes keeps all flags when max is absent" {
  let (limited, truncated) = limit_pass_flags_by_max_passes(
    ["optimize", "vacuum"],
    None,
  )
  assert_eq(limited.length(), 2)
  assert_eq(limited[0], "optimize")
  assert_eq(limited[1], "vacuum")
  assert_false(truncated)
}

///|
test "limit_pass_flags_by_max_passes supports zero as decode-encode baseline" {
  let (limited, truncated) = limit_pass_flags_by_max_passes(
    ["optimize", "vacuum"],
    Some(0),
  )
  assert_eq(limited.length(), 0)
  assert_true(truncated)
}

///|
test "limit_pass_flags_by_max_passes truncates to requested prefix length" {
  let (limited, truncated) = limit_pass_flags_by_max_passes(
    ["a", "b", "c"],
    Some(2),
  )
  assert_eq(limited.length(), 2)
  assert_eq(limited[0], "a")
  assert_eq(limited[1], "b")
  assert_true(truncated)
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
fn format_post_encode_validation_error(
  pre_encode_mod : Module,
  post_encode_mod : Module,
  err : ValidationError,
) -> String {
  let out = StringBuilder::new()
  out.write_string(validation_error_message(err))
  match validation_error_func_idx(err) {
    Some(func_idx) => {
      out.write_string("\n\nOffending function idx=\{func_idx}")
      let before_text = pre_encode_mod.pretty_print_func(func_idx)
      let after_text = post_encode_mod.pretty_print_func(func_idx)
      out.write_string(
        "\n\nOffending function diff (before encode -> after decode):\n",
      )
      out.write_string(render_line_diff(before_text, after_text))
    }
    None => ()
  }
  out.to_string()
}

///|
fn validate_encoded_module_for_pipeline(
  path : String,
  pre_encode_mod : Module,
  bytes : Bytes,
) -> Result[Unit, CmdError] {
  let encoded_mod = match decode_module(bytes) {
    Ok(mod) => mod
    Err(err) =>
      return Err(
        CmdError::EncodeFailed(
          path,
          CmdEncodeError::adapter("post-encode decode failed: \{err}"),
        ),
      )
  }
  match validate_module(encoded_mod) {
    Ok(_) => Ok(())
    Err(err) => {
      cmd_debug_dump_invalid_encoded_module(bytes)
      match validation_error_func_idx(err) {
        Some(func_idx) =>
          cmd_debug_dump_invalid_encoded_func_text(
            pre_encode_mod.pretty_print_func(func_idx),
            encoded_mod.pretty_print_func(func_idx),
          )
        None => ()
      }
      Err(
        CmdError::EncodeFailed(
          path,
          CmdEncodeError::adapter(
            "post-encode validation failed:\n" +
            format_post_encode_validation_error(
              pre_encode_mod, encoded_mod, err,
            ),
          ),
        ),
      )
    }
  }
}

///|
fn should_validate_encoded_module_after_encode(
  debug_serial_passes : Bool,
) -> Bool {
  debug_serial_passes
}

///|
fn should_reuse_input_wasm_bytes(
  format : CliInputFormat,
  pass_count : Int,
  debug_serial_passes : Bool,
  input_mod : Module,
  optimized_mod : Module,
) -> Bool {
  match format {
    Wasm =>
      pass_count > 0 &&
      !should_validate_encoded_module_after_encode(debug_serial_passes) &&
      optimized_mod == input_mod
    Wat | Wast => false
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
/// CLI entrypoint used by the Node runtime bridge and tests.
/// It builds a merged CLI/env/config view, constructs a scheduled pass list, then
/// routes requested pass names through the current compatibility execution layer.
pub fn run_cmd_with_adapter(
  args : Array[String],
  io : CmdIO,
  config_json? : String? = None,
) -> Result[CmdRunSummary, CmdError] {
  if args.length() > 0 {
    if args[0] == "spec" || args[0] == "spec-runner" {
      let spec_args = Array::new(capacity=args.length() - 1)
      let mut i = 1
      while i < args.length() {
        spec_args.push(args[i])
        i += 1
      }
      return run_spec_cmd_with_adapter(spec_args, io)
    }
  }

  let starshine_input = (io.get_env)("STARSHINE_INPUT")
  let cli = match parse_cli_args(args, starshine_input~) {
    Ok(parsed) => parsed
    Err(e) => return Err(CmdError::CliParse(e))
  }
  if cli.help_requested {
    let help = string_to_bytes(cmd_help_text())
    match (io.write_stdout)(help) {
      Ok(_) => return Ok(CmdRunSummary::new())
      Err(e) =>
        return Err(CmdError::OutputWriteFailed("stdout for --help: \{e}"))
    }
  }
  if cli.version_requested {
    let version = string_to_bytes("\{cmd_version_text()}\n")
    match (io.write_stdout)(version) {
      Ok(_) => return Ok(CmdRunSummary::new())
      Err(e) =>
        return Err(CmdError::OutputWriteFailed("stdout for --version: \{e}"))
    }
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
  let trace_level = cmd_resolve_optimize_trace_level(merged.tracing)
  let trace_optimize = trace_level is Some(_)
  let input_files = resolve_input_files_with_glob(
    merged.input_globs,
    io,
    merged.glob_enabled,
  )
  if input_files.length() == 0 {
    return Err(CmdError::NoInputFiles)
  }
  let traps_never_happen = resolve_traps_never_happen(merged)
  let closed_world = resolve_closed_world(merged)
  let (optimize_level, shrink_level) = resolve_optimize_levels(
    merged.optimize_flags,
  )
  let scheduled_pass_flags = resolve_effective_pass_flags(
    resolve_pass_flags(merged),
    optimize_level,
    shrink_level,
  )
  let max_passes = cmd_trace_optimize_max_passes(io)
  let (resolved_passes, pass_flags_truncated) = limit_pass_flags_by_max_passes(
    scheduled_pass_flags, max_passes,
  )
  cmd_trace_emit(
    io,
    trace_optimize,
    "run start inputs=\{input_files.length()} explicit_flags=\{merged.pass_flags.length()} optimize_flags=\{merged.optimize_flags.length()} scheduled_flags=\{scheduled_pass_flags.length()} effective_scheduled_flags=\{resolved_passes.length()}",
  )
  match max_passes {
    Some(limit) =>
      cmd_trace_emit(
        io,
        trace_optimize,
        "pass_limit max_passes=\{limit} scheduled_flag_truncated=\{pass_flags_truncated}",
      )
    None => ()
  }
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
    optimize_level,
    shrink_level,
    traps_never_happen,
    monomorphize_min_benefit,
    closed_world,
    low_memory_unused,
    low_memory_bound,
    merged.debug_serial_passes,
  )
  cmd_trace_emit(
    io,
    trace_optimize,
    "options o=\{optimize_level} z=\{shrink_level} traps_never=\{traps_never_happen} closed_world=\{closed_world}",
  )
  match merged.tracing {
    Some(level) =>
      cmd_trace_emit(
        io,
        true,
        "trace_mode=\{cmd_optimize_trace_level_to_string(level)}",
      )
    None => ()
  }
  if trace_optimize {
    cmd_trace_emit(
      io,
      true,
      "effective_pass_flags=\{cmd_trace_join_pass_flags(resolved_passes)}",
    )
  }

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
    cmd_trace_emit(io, trace_optimize, "input \{input_path}:start")
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
    cmd_trace_emit(
      io,
      trace_optimize,
      "input \{input_path}:read bytes=\{raw_bytes.length()}",
    )

    let wasm_bytes = match format {
      Wasm => raw_bytes
      Wat | Wast =>
        match
          lower_text_module_for_pipeline(io, input_path, format, raw_bytes) {
          Ok(bytes) => bytes
          Err(e) => return Err(e)
        }
    }
    cmd_trace_emit(
      io,
      trace_optimize,
      "input \{input_path}:lowered bytes=\{wasm_bytes.length()}",
    )

    let mod = match decode_module_for_pipeline(input_path, wasm_bytes) {
      Ok(mod) => mod
      Err(e) => return Err(e)
    }
    cmd_trace_emit(io, trace_optimize, "input \{input_path}:decode done")

    let pipeline_steps = match cmd_resolve_pipeline_steps(resolved_passes) {
      Ok(steps) => steps
      Err(err) => return Err(err)
    }
    let effective_pass_count = cmd_pipeline_step_optimize_count(pipeline_steps)
    match max_passes {
      Some(limit) =>
        cmd_trace_emit(
          io,
          trace_optimize,
          "input \{input_path}:pass_limit max_passes=\{limit} effective_pass_count=\{effective_pass_count}",
        )
      None => ()
    }
    cmd_trace_emit(
      io,
      trace_optimize,
      "input \{input_path}:pass_count=\{effective_pass_count} optimize:start",
    )

    let pending_passes : Array[String] = []
    let mut optimized = mod
    let mut print_log_entries = 0
    for step in pipeline_steps {
      match step {
        PipelinePass(flag) => pending_passes.push(flag)
        Dump(path, format) => {
          optimized = match
            run_pipeline_pass_segment(
              io, input_path, optimized, pending_passes, options, trace_optimize,
              trace_level,
            ) {
            Ok(out) => out
            Err(err) => return Err(err)
          }
          pending_passes.clear()
          cmd_trace_emit(
            io,
            trace_optimize,
            "input \{input_path}:dump:start path=\{path}",
          )
          match write_pipeline_dump(io, optimized, path, format) {
            Ok(_) => ()
            Err(err) => return Err(err)
          }
          cmd_trace_emit(
            io,
            trace_optimize,
            "input \{input_path}:dump:done path=\{path}",
          )
        }
        Print(kind, selector) => {
          optimized = match
            run_pipeline_pass_segment(
              io, input_path, optimized, pending_passes, options, trace_optimize,
              trace_level,
            ) {
            Ok(out) => out
            Err(err) => return Err(err)
          }
          pending_passes.clear()
          cmd_trace_emit(
            io,
            trace_optimize,
            "input \{input_path}:print:start kind=\{kind} selector=\{cmd_print_selector_text(selector)}",
          )
          let (label, body) = match
            cmd_resolve_pipeline_print_entry(optimized, kind, selector) {
            Ok(entry) => entry
            Err(err) => return Err(err)
          }
          match
            cmd_write_pipeline_print_log(
              io,
              input_path,
              print_log_entries,
              label,
              body,
              print_log_entries == 0,
            ) {
            Ok(_) => ()
            Err(err) => return Err(err)
          }
          print_log_entries += 1
          cmd_trace_emit(
            io,
            trace_optimize,
            "input \{input_path}:print:done kind=\{kind} selector=\{cmd_print_selector_text(selector)}",
          )
        }
        Validate => {
          optimized = match
            run_pipeline_pass_segment(
              io, input_path, optimized, pending_passes, options, trace_optimize,
              trace_level,
            ) {
            Ok(out) => out
            Err(err) => return Err(err)
          }
          pending_passes.clear()
          cmd_trace_emit(
            io,
            trace_optimize,
            "input \{input_path}:validate:start",
          )
          match validate_module_for_pipeline_step(optimized, "validate pass") {
            Ok(_) => ()
            Err(err) => return Err(err)
          }
          cmd_trace_emit(
            io,
            trace_optimize,
            "input \{input_path}:validate:done",
          )
        }
      }
    }
    optimized = match
      run_pipeline_pass_segment(
        io, input_path, optimized, pending_passes, options, trace_optimize, trace_level,
      ) {
      Ok(out) => out
      Err(err) => return Err(err)
    }
    cmd_trace_emit(
      io,
      trace_optimize,
      "input \{input_path}:final-validate:start",
    )
    match
      validate_module_for_pipeline_step(optimized, "final module validate") {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    cmd_trace_emit(
      io,
      trace_optimize,
      "input \{input_path}:final-validate:done",
    )
    cmd_trace_emit(io, trace_optimize, "input \{input_path}:optimize done")

    let out_bytes = if should_reuse_input_wasm_bytes(
        format,
        effective_pass_count,
        merged.debug_serial_passes,
        mod,
        optimized,
      ) {
      wasm_bytes
    } else {
      match encode_module_for_pipeline(io, input_path, optimized) {
        Ok(bytes) => bytes
        Err(e) => return Err(e)
      }
    }
    cmd_trace_emit(
      io,
      trace_optimize,
      "input \{input_path}:encode bytes=\{out_bytes.length()}",
    )
    if should_validate_encoded_module_after_encode(merged.debug_serial_passes) {
      cmd_trace_emit(
        io,
        trace_optimize,
        "input \{input_path}:post-encode-validate:start",
      )
      match
        validate_encoded_module_for_pipeline(input_path, optimized, out_bytes) {
        Ok(_) => ()
        Err(e) =>
          return Err(
            cmd_append_error_note(
              e,
              cmd_post_encode_repro_note(
                io, mod, resolved_passes, options, optimize_level, shrink_level,
                traps_never_happen, monomorphize_min_benefit, closed_world, low_memory_unused,
                low_memory_bound,
              ),
            ),
          )
      }
      cmd_trace_emit(
        io,
        trace_optimize,
        "input \{input_path}:post-encode-validate:done",
      )
    }

    if merged.output_targets.length() == 0 {
      let out_path = output_path_for_default_target(input_path, format)
      match (io.write_file)(out_path, out_bytes) {
        Ok(_) => output_files.push(out_path)
        Err(e) => return Err(CmdError::OutputWriteFailed("\{out_path}: \{e}"))
      }
      cmd_trace_emit(
        io,
        trace_optimize,
        "input \{input_path}:write default \{out_path}",
      )
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
          cmd_trace_emit(
            io,
            trace_optimize,
            "input \{input_path}:write file \{out_path}",
          )
        }
        DirOutput(dir) => {
          let basename = output_basename_for_input(input_path, format)
          let out_path = join_cli_path(dir, basename)
          match (io.write_file)(out_path, out_bytes) {
            Ok(_) => output_files.push(out_path)
            Err(e) =>
              return Err(CmdError::OutputWriteFailed("\{out_path}: \{e}"))
          }
          cmd_trace_emit(
            io,
            trace_optimize,
            "input \{input_path}:write dir \{out_path}",
          )
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
      closed_world~,
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
extern "c" fn cmd_native_fopen(path : Bytes, mode : Bytes) -> UInt64 = "fopen"

///|
#cfg(target="native")
extern "c" fn cmd_native_fclose(stream : UInt64) -> Int = "fclose"

///|
#cfg(target="native")
extern "c" fn cmd_native_fseek(
  stream : UInt64,
  offset : Int,
  whence : Int,
) -> Int = "fseek"

///|
#cfg(target="native")
extern "c" fn cmd_native_ftell(stream : UInt64) -> Int64 = "ftell"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn cmd_native_fread(
  ptr : Bytes,
  size : UInt64,
  count : UInt64,
  stream : UInt64,
) -> UInt64 = "fread"

///|
#cfg(target="native")
#borrow(path)
extern "c" fn cmd_native_access(path : Bytes, mode : Int) -> Int = "access"

///|
#cfg(target="native")
#borrow(command, mode)
extern "c" fn cmd_native_popen(command : Bytes, mode : Bytes) -> UInt64 = "popen"

///|
#cfg(target="native")
extern "c" fn cmd_native_pclose(stream : UInt64) -> Int = "pclose"

///|
#cfg(target="native")
#borrow(command)
extern "c" fn cmd_native_system(command : Bytes) -> Int = "system"

///|
#cfg(target="native")
extern "c" fn cmd_native_getpid() -> Int = "getpid"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn cmd_native_write(fd : Int, ptr : Bytes, count : UInt64) -> Int = "write"

///|
#cfg(target="native")
#borrow(buf)
extern "c" fn cmd_native_getrlimit(resource : Int, buf : Bytes) -> Int = "getrlimit"

///|
#cfg(target="native")
#borrow(buf)
extern "c" fn cmd_native_setrlimit(resource : Int, buf : Bytes) -> Int = "setrlimit"

///|
#cfg(target="native")
fn cmd_native_file_exists(path : String) -> Bool {
  let c_path = cmd_native_c_string(path)
  cmd_native_access(c_path, 0) == 0
}

///|
#cfg(target="native")
fn cmd_native_read_file(path : String) -> Result[Bytes, String] {
  let c_path = cmd_native_c_string(path)
  let c_mode = cmd_native_c_string("rb")
  let file = cmd_native_fopen(c_path, c_mode)
  if file == 0UL {
    return Err("open failed")
  }
  if cmd_native_fseek(file, 0, 2) != 0 {
    ignore(cmd_native_fclose(file))
    return Err("seek end failed")
  }
  let size_i64 = cmd_native_ftell(file)
  if size_i64 < 0L {
    ignore(cmd_native_fclose(file))
    return Err("tell failed")
  }
  let size_u = size_i64.reinterpret_as_uint64()
  if size_u > 2147483647UL {
    ignore(cmd_native_fclose(file))
    return Err("file too large")
  }
  let size = size_i64.to_int()
  if cmd_native_fseek(file, 0, 0) != 0 {
    ignore(cmd_native_fclose(file))
    return Err("seek start failed")
  }
  let out = Bytes::new(size)
  if size > 0 {
    let read = cmd_native_fread(out, 1UL, size_u, file)
    if read != size_u {
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
  @sfs.write_file_bytes(path, bytes)
}

///|
#cfg(target="native")
fn cmd_debug_dump_invalid_encoded_module(bytes : Bytes) -> Unit {
  ignore(cmd_native_write_file("/tmp/starshine-invalid-encoded.wasm", bytes))
}

///|
#cfg(target="native")
fn cmd_debug_dump_invalid_encoded_func_text(
  before_text : String,
  after_text : String,
) -> Unit {
  ignore(
    @sfs.write_file_bytes(
      "/tmp/starshine-invalid-before.txt",
      before_text.to_bytes(),
    ),
  )
  ignore(
    @sfs.write_file_bytes(
      "/tmp/starshine-invalid-after.txt",
      after_text.to_bytes(),
    ),
  )
}

///|
#cfg(target="js")
fn cmd_debug_dump_invalid_encoded_module(_bytes : Bytes) -> Unit {

}

///|
#cfg(target="js")
fn cmd_debug_dump_invalid_encoded_func_text(
  _before_text : String,
  _after_text : String,
) -> Unit {

}

///|
#cfg(target="llvm")
fn cmd_debug_dump_invalid_encoded_module(_bytes : Bytes) -> Unit {

}

///|
#cfg(target="llvm")
fn cmd_debug_dump_invalid_encoded_func_text(
  _before_text : String,
  _after_text : String,
) -> Unit {

}

///|
#cfg(target="wasm-gc")
fn cmd_debug_dump_invalid_encoded_module(_bytes : Bytes) -> Unit {

}

///|
#cfg(target="wasm-gc")
fn cmd_debug_dump_invalid_encoded_func_text(
  _before_text : String,
  _after_text : String,
) -> Unit {

}

///|
#cfg(target="wasm")
fn cmd_debug_dump_invalid_encoded_module(_bytes : Bytes) -> Unit {

}

///|
#cfg(target="wasm")
fn cmd_debug_dump_invalid_encoded_func_text(
  _before_text : String,
  _after_text : String,
) -> Unit {

}

///|
#cfg(target="native")
fn cmd_native_remove_file(path : String) -> Unit {
  ignore(@sfs.remove_file(path))
}

///|
#cfg(target="native")
fn cmd_native_write_stdout(bytes : Bytes) -> Result[Unit, String] {
  if bytes.length() == 0 {
    return Ok(())
  }
  let wrote = cmd_native_write(1, bytes, bytes.length().to_uint64())
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
fn cmd_native_write_stderr(bytes : Bytes) -> Result[Unit, String] {
  if bytes.length() == 0 {
    return Ok(())
  }
  let wrote = cmd_native_write(2, bytes, bytes.length().to_uint64())
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
fn cmd_native_read_u64_le(bytes : Bytes, start : Int) -> UInt64 {
  let mut out : UInt64 = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
fn cmd_native_raise_stack_soft_limit() -> Unit {
  // Linux/macOS RLIMIT_STACK constant.
  let rlimit_stack = 3
  // struct rlimit { rlim_t cur; rlim_t max; } with 64-bit rlim_t.
  let buf = Bytes::new(16)
  if cmd_native_getrlimit(rlimit_stack, buf) != 0 {
    return
  }
  let cur = cmd_native_read_u64_le(buf, 0)
  let max = cmd_native_read_u64_le(buf, 8)
  if cur >= max {
    return
  }
  let set_buf = @buffer.new(size_hint=16)
  let mut i = 0
  while i < 8 {
    set_buf.write_byte(((max >> (i * 8)) & 0xFFUL).to_byte())
    i += 1
  }
  i = 0
  while i < 8 {
    set_buf.write_byte(((max >> (i * 8)) & 0xFFUL).to_byte())
    i += 1
  }
  ignore(cmd_native_setrlimit(rlimit_stack, set_buf.to_bytes()))
}

///|
#cfg(target="native")
fn cmd_native_get_env(name : String) -> String? {
  let command = "printenv \{cmd_native_shell_quote(name)}"
  let c_command = cmd_native_c_string(command)
  let c_mode = cmd_native_c_string("r")
  let pipe = cmd_native_popen(c_command, c_mode)
  if pipe == 0UL {
    return None
  }

  let read_buf = Bytes::new(256)
  let out = @buffer.new()
  while true {
    let read = cmd_native_fread(
      read_buf,
      1UL,
      read_buf.length().to_uint64(),
      pipe,
    )
    if read == 0UL {
      break
    }
    let read_i = read.to_int()
    let mut i = 0
    while i < read_i {
      out.write_byte(read_buf[i])
      i += 1
    }
  }
  if cmd_native_pclose(pipe) != 0 {
    return None
  }

  let bytes = out.to_bytes()
  let trimmed = if bytes.length() > 0 &&
    bytes[bytes.length() - 1] == '\n'.to_int().to_byte() {
    let result = @buffer.new(size_hint=bytes.length() - 1)
    let mut i = 0
    while i < bytes.length() - 1 {
      result.write_byte(bytes[i])
      i += 1
    }
    result.to_bytes()
  } else {
    bytes
  }
  Some(bytes_to_string_lossy(trimmed))
}

///|
#cfg(target="native")
fn cmd_native_shell_quote(text : String) -> String {
  let escaped = text.replace(old="'", new="'\"'\"'")
  "'\{escaped}'"
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn cmd_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn cmd_native_read_u64_timeval(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
fn cmd_native_now_ms() -> UInt64 {
  let tv = Bytes::new(16)
  if cmd_native_gettimeofday(tv, 0UL) != 0 {
    return @env.now()
  }
  let sec = cmd_native_read_u64_timeval(tv, 0)
  let usec = cmd_native_read_u64_timeval(tv, 8)
  sec * 1000UL + usec / 1000UL
}

///|
#cfg(target="native")
fn cmd_native_tmp_path(prefix : String, suffix : String) -> String {
  "/tmp/starshine-cmd-\{prefix}-\{cmd_native_getpid()}-\{cmd_native_now_ms()}\{suffix}"
}

///|
fn cmd_default_list_candidates() -> Array[String] {
  match @sfs.list_files_recursive(".") {
    Ok(files) => files
    Err(_) => []
  }
}

///|
#cfg(target="native")
fn cmd_native_list_candidates() -> Array[String] {
  cmd_default_list_candidates()
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
    cmd_native_remove_file(in_path)
    cmd_native_remove_file(out_path)
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
    let c_command = cmd_native_c_string(command)
    let code = cmd_native_system(c_command)
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

  cmd_native_remove_file(in_path)
  cmd_native_remove_file(out_path)
  result
}

///|
#cfg(target="native")
fn cmd_native_print_text_module(mod : Module) -> Result[Bytes, String] {
  let wasm_bytes = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(err) => return Err("failed to encode module for wat dump: \{err}")
  }
  let in_path = cmd_native_tmp_path("print-in", ".wasm")
  let out_path = cmd_native_tmp_path("print-out", ".wat")
  if cmd_native_write_file(in_path, wasm_bytes) is Err(e) {
    cmd_native_remove_file(in_path)
    cmd_native_remove_file(out_path)
    return Err("failed to stage wat dump input: \{e}")
  }

  let in_q = cmd_native_shell_quote(in_path)
  let out_q = cmd_native_shell_quote(out_path)
  let commands = [
    "wasm-tools print \{in_q} -o \{out_q}",
    "wasm-tools print \{in_q} > \{out_q}",
    "wasm-dis \{in_q} -o \{out_q}",
  ]
  let mut printed = false
  for command in commands {
    let c_command = cmd_native_c_string(command)
    let code = cmd_native_system(c_command)
    if code == 0 && cmd_native_file_exists(out_path) {
      printed = true
      break
    }
  }

  let result = if printed {
    match cmd_native_read_file(out_path) {
      Ok(out) => Ok(out)
      Err(e) => Err("failed to read printed wat dump: \{e}")
    }
  } else {
    Err(
      "failed to print wat dump: expected native `wasm-tools print` or `wasm-dis` to be available",
    )
  }

  cmd_native_remove_file(in_path)
  cmd_native_remove_file(out_path)
  result
}

///|
#cfg(target="native")
fn default_cmd_io() -> CmdIO {
  CmdIO::new(
    get_env=cmd_native_get_env,
    file_exists=cmd_native_file_exists,
    read_file=cmd_native_read_file,
    print_text_module=cmd_native_print_text_module,
    write_file=cmd_native_write_file,
    write_stdout=cmd_native_write_stdout,
    write_stderr=cmd_native_write_stderr,
    list_candidates=cmd_native_list_candidates,
    lower_text_module=cmd_native_lower_text_module,
  )
}

///|
#cfg(target="js")
fn default_cmd_io() -> CmdIO {
  let _ = @sfs.remove_file
  let _ = cmd_default_list_candidates
  CmdIO::new()
}

///|
#cfg(target="llvm")
fn default_cmd_io() -> CmdIO {
  let _ = @sfs.remove_file
  let _ = cmd_default_list_candidates
  CmdIO::new()
}

///|
#cfg(target="wasm-gc")
fn default_cmd_io() -> CmdIO {
  let _ = @sfs.remove_file
  let _ = cmd_default_list_candidates
  CmdIO::new()
}

///|
pub fn run_cmd(args : Array[String]) -> Result[CmdRunSummary, CmdError] {
  run_cmd_with_adapter(args, default_cmd_io())
}

///|
pub fn run_cmd_exit_code_with_adapter(
  args : Array[String],
  io : CmdIO,
  config_json? : String? = None,
) -> Int {
  match run_cmd_with_adapter(args, io, config_json~) {
    Ok(_) => 0
    Err(err) => {
      ignore((io.write_stderr)(cmd_error_stderr_bytes(err)))
      1
    }
  }
}

///|
pub fn run_cmd_exit_code(args : Array[String]) -> Int {
  run_cmd_exit_code_with_adapter(args, default_cmd_io())
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
#cfg(target="wasm")
fn main {
  ignore(run_cmd_exit_code(@env.args()))
}

///|
#cfg(target="wasm-gc")
fn main {
  ignore(run_cmd_exit_code(@env.args()))
}

///|
#cfg(target="native")
extern "c" fn cmd_native_exit(code : Int) -> Unit = "quick_exit"

///|
#cfg(target="native")
fn main {
  cmd_native_raise_stack_soft_limit()
  let args = trim_program_name(@env.args())
  let exit_code = run_cmd_exit_code(args)
  if exit_code != 0 {
    cmd_native_exit(exit_code)
  }
}

///|
#cfg(target="js")
fn main {
  ()
}

///|

///|
#cfg(target="wasm")
#external
priv type CmdExternString

///|
#cfg(target="wasm")
#external
priv type CmdStringReadHandle

///|
#cfg(target="wasm")
fn cmd_wasm_begin_read_string(s : CmdExternString) -> CmdStringReadHandle = "__moonbit_fs_unstable" "begin_read_string"

///|
#cfg(target="wasm")
fn cmd_wasm_string_read_char(handle : CmdStringReadHandle) -> Int = "__moonbit_fs_unstable" "string_read_char"

///|
#cfg(target="wasm")
fn cmd_wasm_finish_read_string(handle : CmdStringReadHandle) = "__moonbit_fs_unstable" "finish_read_string"

///|
#cfg(target="wasm")
fn cmd_wasm_string_from_extern(extern_str : CmdExternString) -> String {
  let out = StringBuilder::new()
  let handle = cmd_wasm_begin_read_string(extern_str)
  while true {
    let ch = cmd_wasm_string_read_char(handle)
    if ch == -1 {
      break
    }
    out.write_char(ch.unsafe_to_char())
  }
  cmd_wasm_finish_read_string(handle)
  out.to_string()
}

///|
#cfg(target="wasm")
fn cmd_wasm_list_candidates() -> Array[String] {
  let _ = cmd_wasm_string_from_extern
  cmd_default_list_candidates()
}

///|
#cfg(target="wasm")
fn default_cmd_io() -> CmdIO {
  let _ = @sfs.remove_file
  CmdIO::new(list_candidates=cmd_wasm_list_candidates)
}
