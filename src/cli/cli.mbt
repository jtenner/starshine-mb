///|
pub const DEFAULT_CONFIG_PATH : String = "starshine.config.json"

///|
pub enum CliInputFormat {
  Wasm
  Wat
  Wast
} derive(Eq, Show, Debug)

///|
pub fn CliInputFormat::wasm() -> CliInputFormat {
  Wasm
}

///|
pub fn CliInputFormat::wat() -> CliInputFormat {
  Wat
}

///|
pub fn CliInputFormat::wast() -> CliInputFormat {
  Wast
}

///|
pub enum CliOutputTarget {
  StdoutOutput
  FileOutput(String)
  DirOutput(String)
} derive(Eq, Show, Debug)

///|
pub fn CliOutputTarget::stdout() -> CliOutputTarget {
  StdoutOutput
}

///|
pub fn CliOutputTarget::file(path : String) -> CliOutputTarget {
  FileOutput(path)
}

///|
pub fn CliOutputTarget::dir(path : String) -> CliOutputTarget {
  DirOutput(path)
}

///|
pub enum CliOptimizationFlag {
  OptimizePreset
  ShrinkPreset
  OLevel(Int, Bool)
} derive(Eq, Show, Debug)

///|
pub fn CliOptimizationFlag::optimize() -> CliOptimizationFlag {
  OptimizePreset
}

///|
pub fn CliOptimizationFlag::shrink() -> CliOptimizationFlag {
  ShrinkPreset
}

///|
pub fn CliOptimizationFlag::olevel(
  level : Int,
  size_bias : Bool,
) -> CliOptimizationFlag {
  OLevel(level, size_bias)
}

///|
pub enum TrapMode {
  Allow
  Never
} derive(Eq, Show, Debug)

///|
pub fn TrapMode::allow() -> TrapMode {
  Allow
}

///|
pub fn TrapMode::never() -> TrapMode {
  Never
}

///|
pub enum CliTracingLevel {
  Pass
  Phase
  Helper
} derive(Eq, Show, Debug)

///|
pub fn CliTracingLevel::pass() -> CliTracingLevel {
  Pass
}

///|
pub fn CliTracingLevel::phase() -> CliTracingLevel {
  Phase
}

///|
pub fn CliTracingLevel::helper() -> CliTracingLevel {
  Helper
}

///|
pub enum CliParseError {
  MissingFlagValue(String)
  InvalidInputFormat(String)
  StdinNeedsFormat
  UnknownShortFlag(Char)
  InvalidLongFlag(String)
  UnexpectedFlagValue(String)
  InvalidDumpPath(String)
  InvalidOptimizationFlag(String)
  InvalidTrapMode(String)
  InvalidTracingLevel(String)
} derive(Eq, Show, Debug)

///|
pub fn CliParseError::missing_flag_value(flag : String) -> CliParseError {
  MissingFlagValue(flag)
}

///|
pub fn CliParseError::invalid_input_format(format : String) -> CliParseError {
  InvalidInputFormat(format)
}

///|
pub fn CliParseError::stdin_needs_format() -> CliParseError {
  StdinNeedsFormat
}

///|
pub fn CliParseError::unknown_short_flag(flag : Char) -> CliParseError {
  UnknownShortFlag(flag)
}

///|
pub fn CliParseError::invalid_long_flag(flag : String) -> CliParseError {
  InvalidLongFlag(flag)
}

///|
pub fn CliParseError::unexpected_flag_value(flag : String) -> CliParseError {
  UnexpectedFlagValue(flag)
}

///|
pub fn CliParseError::invalid_dump_path(path : String) -> CliParseError {
  InvalidDumpPath(path)
}

///|
pub fn CliParseError::invalid_optimization_flag(flag : String) -> CliParseError {
  InvalidOptimizationFlag(flag)
}

///|
pub fn CliParseError::invalid_trap_mode(mode : String) -> CliParseError {
  InvalidTrapMode(mode)
}

///|
pub fn CliParseError::invalid_tracing_level(level : String) -> CliParseError {
  InvalidTracingLevel(level)
}

///|
pub struct CliParseResult {
  mut config_path : String?
  input_globs : Array[String]
  mut glob_enabled : Bool
  mut help_requested : Bool
  mut version_requested : Bool
  mut debug_serial_passes : Bool
  mut read_stdin : Bool
  mut input_format : CliInputFormat?
  output_targets : Array[CliOutputTarget]
  pass_flags : Array[String]
  optimize_flags : Array[CliOptimizationFlag]
  mut trap_mode : TrapMode?
  mut monomorphize_min_benefit : Int?
  mut low_memory_unused : Bool?
  mut low_memory_bound : UInt64?
  mut closed_world : Bool?
  mut tracing : CliTracingLevel?
} derive(Eq, Show, Debug)

///|
pub fn CliParseResult::new(
  config_path? : String? = None,
  input_globs? : Array[String] = [],
  glob_enabled? : Bool = false,
  help_requested? : Bool = false,
  version_requested? : Bool = false,
  debug_serial_passes? : Bool = false,
  read_stdin? : Bool = false,
  input_format? : CliInputFormat? = None,
  output_targets? : Array[CliOutputTarget] = [],
  pass_flags? : Array[String] = [],
  optimize_flags? : Array[CliOptimizationFlag] = [],
  trap_mode? : TrapMode? = None,
  monomorphize_min_benefit? : Int? = None,
  low_memory_unused? : Bool? = None,
  low_memory_bound? : UInt64? = None,
  closed_world? : Bool? = None,
  tracing? : CliTracingLevel? = None,
) -> CliParseResult {
  {
    config_path,
    input_globs,
    glob_enabled,
    help_requested,
    version_requested,
    debug_serial_passes,
    read_stdin,
    input_format,
    output_targets,
    pass_flags,
    optimize_flags,
    trap_mode,
    monomorphize_min_benefit,
    low_memory_unused,
    low_memory_bound,
    closed_world,
    tracing,
  }
}

///|
fn is_ascii_space(c : UInt16) -> Bool {
  c == ' '.to_int().to_uint16() ||
  c == '\t'.to_int().to_uint16() ||
  c == '\n'.to_int().to_uint16() ||
  c == '\r'.to_int().to_uint16()
}

///|
fn ascii_lower_u16(c : UInt16) -> UInt16 {
  if c >= 'A'.to_int().to_uint16() && c <= 'Z'.to_int().to_uint16() {
    (c.to_int() + 32).to_uint16()
  } else {
    c
  }
}

///|
fn trimmed_bounds(input : String) -> (Int, Int) {
  let mut start = 0
  let mut end = input.length()
  while start < end && is_ascii_space(input[start]) {
    start += 1
  }
  while end > start && is_ascii_space(input[end - 1]) {
    end -= 1
  }
  (start, end)
}

///|
fn trimmed_ascii_eq_ignore_case(input : String, expected : String) -> Bool {
  let (start, end) = trimmed_bounds(input)
  if end - start != expected.length() {
    return false
  }
  let mut i = 0
  while i < expected.length() {
    if ascii_lower_u16(input[start + i]) != expected[i] {
      return false
    }
    i += 1
  }
  true
}

///|
fn parse_input_format(raw : String) -> CliInputFormat? {
  if trimmed_ascii_eq_ignore_case(raw, "wasm") {
    Some(CliInputFormat::wasm())
  } else if trimmed_ascii_eq_ignore_case(raw, "wat") {
    Some(CliInputFormat::wat())
  } else if trimmed_ascii_eq_ignore_case(raw, "wast") {
    Some(CliInputFormat::wast())
  } else {
    None
  }
}

///|
fn parse_trap_mode(raw : String) -> TrapMode? {
  if trimmed_ascii_eq_ignore_case(raw, "allow") ||
    trimmed_ascii_eq_ignore_case(raw, "traps-may-happen") {
    Some(TrapMode::allow())
  } else if trimmed_ascii_eq_ignore_case(raw, "never") ||
    trimmed_ascii_eq_ignore_case(raw, "traps-never-happen") {
    Some(TrapMode::never())
  } else {
    None
  }
}

///|
fn parse_tracing_level(raw : String) -> CliTracingLevel? {
  if trimmed_ascii_eq_ignore_case(raw, "pass") {
    Some(CliTracingLevel::pass())
  } else if trimmed_ascii_eq_ignore_case(raw, "phase") {
    Some(CliTracingLevel::phase())
  } else if trimmed_ascii_eq_ignore_case(raw, "helper") {
    Some(CliTracingLevel::helper())
  } else {
    None
  }
}

///|
fn append_input_glob(out : Array[String], raw : String) -> Unit {
  let trimmed = raw.trim().to_string()
  if trimmed.length() == 0 {
    return
  }
  out.push(normalize_cli_path(trimmed))
}

///|
fn looks_like_option_token(token : String) -> Bool {
  token.length() > 1 && token[0] == '-'
}

///|
fn path_has_ascii_suffix_ignore_case(path : String, suffix : String) -> Bool {
  if path.length() < suffix.length() {
    return false
  }
  let start = path.length() - suffix.length()
  let mut i = 0
  while i < suffix.length() {
    if ascii_lower_u16(path[start + i]) != suffix[i] {
      return false
    }
    i += 1
  }
  true
}

///|
fn parse_dump_pass_value(raw : String) -> Result[String, CliParseError] {
  let value = raw.trim().to_string()
  if value.length() == 0 {
    return Err(CliParseError::missing_flag_value("--dump"))
  }
  if path_has_ascii_suffix_ignore_case(value, ".wasm") ||
    path_has_ascii_suffix_ignore_case(value, ".wat") {
    return Ok("dump=\{value}")
  }
  Err(CliParseError::invalid_dump_path(value))
}

///|
fn parse_print_pass_value(
  flag_name : String,
  raw : String,
) -> Result[String, CliParseError] {
  let value = raw.trim().to_string()
  if value.length() == 0 {
    return Err(CliParseError::missing_flag_value(long_flag_name(flag_name)))
  }
  Ok("\{flag_name}=\{value}")
}

///|
fn push_unique_output_target(
  targets : Array[CliOutputTarget],
  target : CliOutputTarget,
) -> Unit {
  for existing in targets {
    if existing == target {
      return
    }
  }
  targets.push(target)
}

///|
fn is_kebab_case_flag_name(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  if name[0] == '-' || name[name.length() - 1] == '-' {
    return false
  }
  let mut prev_dash = false
  for c in name {
    let is_ok = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-'
    if !is_ok {
      return false
    }
    if c == '-' && prev_dash {
      return false
    }
    prev_dash = c == '-'
  }
  true
}

///|
fn split_long_flag_token(token : String) -> (String, String?) {
  let mut i = 2
  while i < token.length() {
    if token[i] == '=' {
      let name = token.sub(start=2, end=i).to_string()
      let value = token.sub(start=i + 1).to_string()
      return (name, Some(value))
    }
    i += 1
  }
  (token.sub(start=2).to_string(), None)
}

///|
fn long_flag_name(name : String) -> String {
  "--" + name
}

///|
fn parse_opt_level_flag(
  flag : String,
) -> Result[CliOptimizationFlag, CliParseError] {
  if flag.length() < 2 || flag[0] != '-' || flag[1] != 'O' {
    return Err(CliParseError::invalid_optimization_flag(flag))
  }
  let mut i = 2
  let mut saw_digit = false
  let mut level = 2
  while i < flag.length() {
    let c = flag[i]
    if c >= '0' && c <= '9' {
      if !saw_digit {
        saw_digit = true
        level = 0
      }
      level = level * 10 + (c.to_int() - '0'.to_int())
      i += 1
      continue
    }
    break
  }
  let mut size_bias = false
  if i < flag.length() {
    if flag[i] == 'z' {
      size_bias = true
      i += 1
    } else {
      return Err(CliParseError::invalid_optimization_flag(flag))
    }
  }
  if i != flag.length() {
    return Err(CliParseError::invalid_optimization_flag(flag))
  }
  Ok(CliOptimizationFlag::olevel(level, size_bias))
}

///|
fn parse_non_negative_decimal(raw : String) -> Int? {
  let (start, end) = trimmed_bounds(raw)
  if start == end {
    return None
  }
  let mut value = 0
  let mut i = start
  while i < end {
    let c = raw[i]
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i += 1
  }
  Some(value)
}

///|
fn parse_short_option_cluster(
  args : Array[String],
  index : Int,
  parsed : CliParseResult,
) -> Result[Int, CliParseError] {
  let token = args[index]
  let mut i = 1
  while i < token.length() {
    let flag = token[i]
    match flag {
      'h' => {
        parsed.help_requested = true
        i += 1
      }
      'V' => {
        parsed.version_requested = true
        i += 1
      }
      'g' => {
        parsed.glob_enabled = true
        i += 1
      }
      's' => {
        push_unique_output_target(
          parsed.output_targets,
          CliOutputTarget::stdout(),
        )
        i += 1
      }
      'c' => {
        let attached = token.sub(start=i + 1).to_string()
        if attached.length() > 0 {
          parsed.config_path = Some(attached)
          return Ok(index + 1)
        }
        if index + 1 < args.length() &&
          !looks_like_option_token(args[index + 1]) {
          parsed.config_path = Some(args[index + 1])
          return Ok(index + 2)
        }
        parsed.config_path = Some(DEFAULT_CONFIG_PATH)
        return Ok(index + 1)
      }
      'o' => {
        let attached = token.sub(start=i + 1).to_string()
        if attached.length() > 0 {
          push_unique_output_target(
            parsed.output_targets,
            CliOutputTarget::file(attached),
          )
          return Ok(index + 1)
        }
        if index + 1 < args.length() &&
          !looks_like_option_token(args[index + 1]) {
          push_unique_output_target(
            parsed.output_targets,
            CliOutputTarget::file(args[index + 1]),
          )
          return Ok(index + 2)
        }
        return Err(CliParseError::missing_flag_value("-o"))
      }
      'd' => {
        let attached = token.sub(start=i + 1).to_string()
        if attached.length() > 0 {
          push_unique_output_target(
            parsed.output_targets,
            CliOutputTarget::dir(attached),
          )
          return Ok(index + 1)
        }
        if index + 1 < args.length() &&
          !looks_like_option_token(args[index + 1]) {
          push_unique_output_target(
            parsed.output_targets,
            CliOutputTarget::dir(args[index + 1]),
          )
          return Ok(index + 2)
        }
        return Err(CliParseError::missing_flag_value("-d"))
      }
      _ => return Err(CliParseError::unknown_short_flag(flag.unsafe_to_char()))
    }
  }
  Ok(index + 1)
}

///|
pub fn parse_starshine_input_env(raw : String?) -> Array[String] {
  let out = Array::new()
  match raw {
    Some(text) =>
      for part in text.split(",") {
        append_input_glob(out, part.to_string())
      }
    None => ()
  }
  out
}

///|
pub fn infer_input_format(path : String) -> CliInputFormat? {
  let normalized = normalize_cli_path(path)
  let mut last_dot = -1
  let mut last_sep = -1
  let mut i = 0
  while i < normalized.length() {
    if normalized[i] == '.' {
      last_dot = i
    } else if normalized[i] == '/' {
      last_sep = i
    }
    i += 1
  }
  if last_dot < 0 || last_dot <= last_sep || last_dot + 1 >= normalized.length() {
    return None
  }
  let ext = normalized.sub(start=last_dot + 1).to_string()
  parse_input_format(ext)
}

///|
pub fn cli_config_schema_json() -> String {
  let schema =
    #|{
    #|  "schemaVersion": 1,
    #|  "inputs": {
    #|    "globs": ["**/*.wasm"],
    #|    "stdin": false,
    #|    "format": "wasm"
    #|  },
    #|  "outputs": {
    #|    "stdout": false,
    #|    "out": null,
    #|    "outDir": null
    #|  },
    #|  "passes": ["validate"],
    #|  "tracing": "phase",
    #|  "optimize": {
    #|    "preset": "optimize",
    #|    "olevel": "O2",
    #|    "trapMode": "allow"
    #|  },
    #|  "options": {
    #|    "trapsNeverHappen": false,
    #|    "monomorphizeMinBenefit": 5,
    #|    "lowMemoryUnused": false,
    #|    "lowMemoryBound": 1024,
    #|    "closedWorld": false
    #|  }
    #|}
  schema
}

///|
pub fn parse_cli_args(
  args : Array[String],
  starshine_input? : String? = None,
) -> Result[CliParseResult, CliParseError] {
  let parsed = CliParseResult::new()
  let mut index = 0
  let mut positional_only = false
  while index < args.length() {
    let arg = args[index]
    if positional_only {
      append_input_glob(parsed.input_globs, arg)
      index += 1
      continue
    }
    if arg == "--" {
      positional_only = true
      index += 1
      continue
    }
    if arg.length() > 1 && arg[0] == '-' {
      if arg.length() >= 2 && arg[1] == 'O' {
        match parse_opt_level_flag(arg) {
          Ok(flag) => parsed.optimize_flags.push(flag)
          Err(e) => return Err(e)
        }
        index += 1
        continue
      }
      if arg.length() > 2 && arg[1] == '-' {
        let (name, inline_value) = split_long_flag_token(arg)
        match name {
          "help" => {
            if inline_value is Some(_) {
              return Err(CliParseError::unexpected_flag_value("--help"))
            }
            parsed.help_requested = true
            index += 1
          }
          "version" => {
            if inline_value is Some(_) {
              return Err(CliParseError::unexpected_flag_value("--version"))
            }
            parsed.version_requested = true
            index += 1
          }
          "glob" => {
            if inline_value is Some(_) {
              return Err(CliParseError::unexpected_flag_value("--glob"))
            }
            parsed.glob_enabled = true
            index += 1
          }
          "stdin" => {
            if inline_value is Some(_) {
              return Err(CliParseError::unexpected_flag_value("--stdin"))
            }
            parsed.read_stdin = true
            index += 1
          }
          "format" => {
            let (value, consumed_next) = match inline_value {
              Some(v) if v.length() > 0 => (v, false)
              Some(_) =>
                return Err(CliParseError::missing_flag_value("--format"))
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  (args[index + 1], true)
                } else {
                  return Err(CliParseError::missing_flag_value("--format"))
                }
            }
            match parse_input_format(value) {
              Some(format) => parsed.input_format = Some(format)
              None => return Err(CliParseError::invalid_input_format(value))
            }
            index += if consumed_next { 2 } else { 1 }
          }
          "config" => {
            match inline_value {
              Some(v) if v.length() > 0 => parsed.config_path = Some(v)
              Some(_) => parsed.config_path = Some(DEFAULT_CONFIG_PATH)
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  parsed.config_path = Some(args[index + 1])
                  index += 1
                } else {
                  parsed.config_path = Some(DEFAULT_CONFIG_PATH)
                }
            }
            index += 1
          }
          "stdout" => {
            if inline_value is Some(_) {
              return Err(CliParseError::unexpected_flag_value("--stdout"))
            }
            push_unique_output_target(
              parsed.output_targets,
              CliOutputTarget::stdout(),
            )
            index += 1
          }
          "out" => {
            let (value, consumed_next) = match inline_value {
              Some(v) if v.length() > 0 => (v, false)
              Some(_) => return Err(CliParseError::missing_flag_value("--out"))
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  (args[index + 1], true)
                } else {
                  return Err(CliParseError::missing_flag_value("--out"))
                }
            }
            push_unique_output_target(
              parsed.output_targets,
              CliOutputTarget::file(value),
            )
            index += if consumed_next { 2 } else { 1 }
          }
          "out-dir" => {
            let (value, consumed_next) = match inline_value {
              Some(v) if v.length() > 0 => (v, false)
              Some(_) =>
                return Err(CliParseError::missing_flag_value("--out-dir"))
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  (args[index + 1], true)
                } else {
                  return Err(CliParseError::missing_flag_value("--out-dir"))
                }
            }
            push_unique_output_target(
              parsed.output_targets,
              CliOutputTarget::dir(value),
            )
            index += if consumed_next { 2 } else { 1 }
          }
          "dump" => {
            let raw_value = match inline_value {
              Some(v) if v.length() > 0 => v
              Some(_) => return Err(CliParseError::missing_flag_value("--dump"))
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  args[index + 1]
                } else {
                  return Err(CliParseError::missing_flag_value("--dump"))
                }
            }
            let dump_flag = match parse_dump_pass_value(raw_value) {
              Ok(flag) => flag
              Err(err) => return Err(err)
            }
            parsed.pass_flags.push(dump_flag)
            index += if inline_value is None { 2 } else { 1 }
          }
          "optimize" => {
            if inline_value is Some(_) {
              return Err(CliParseError::unexpected_flag_value("--optimize"))
            }
            parsed.optimize_flags.push(CliOptimizationFlag::optimize())
            parsed.pass_flags.push("optimize")
            index += 1
          }
          "shrink" => {
            if inline_value is Some(_) {
              return Err(CliParseError::unexpected_flag_value("--shrink"))
            }
            parsed.optimize_flags.push(CliOptimizationFlag::shrink())
            parsed.pass_flags.push("shrink")
            index += 1
          }
          "optimize-level" => {
            let (value, consumed_next) = match inline_value {
              Some(v) if v.length() > 0 => (v, false)
              Some(_) =>
                return Err(
                  CliParseError::missing_flag_value("--optimize-level"),
                )
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  (args[index + 1], true)
                } else {
                  return Err(
                    CliParseError::missing_flag_value("--optimize-level"),
                  )
                }
            }
            match parse_non_negative_decimal(value) {
              Some(level) =>
                parsed.optimize_flags.push(
                  CliOptimizationFlag::olevel(level, false),
                )
              None =>
                return Err(
                  CliParseError::invalid_optimization_flag("--optimize-level"),
                )
            }
            index += if consumed_next { 2 } else { 1 }
          }
          "shrink-level" => {
            let (value, consumed_next) = match inline_value {
              Some(v) if v.length() > 0 => (v, false)
              Some(_) =>
                return Err(CliParseError::missing_flag_value("--shrink-level"))
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  (args[index + 1], true)
                } else {
                  return Err(
                    CliParseError::missing_flag_value("--shrink-level"),
                  )
                }
            }
            match parse_non_negative_decimal(value) {
              Some(level) =>
                parsed.optimize_flags.push(
                  CliOptimizationFlag::olevel(level, true),
                )
              None =>
                return Err(
                  CliParseError::invalid_optimization_flag("--shrink-level"),
                )
            }
            index += if consumed_next { 2 } else { 1 }
          }
          "monomorphize-min-benefit" => {
            let (value, consumed_next) = match inline_value {
              Some(v) if v.length() > 0 => (v, false)
              Some(_) =>
                return Err(
                  CliParseError::missing_flag_value(
                    "--monomorphize-min-benefit",
                  ),
                )
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  (args[index + 1], true)
                } else {
                  return Err(
                    CliParseError::missing_flag_value(
                      "--monomorphize-min-benefit",
                    ),
                  )
                }
            }
            match parse_non_negative_decimal(value) {
              Some(parsed_value) =>
                parsed.monomorphize_min_benefit = Some(parsed_value)
              None =>
                return Err(
                  CliParseError::invalid_optimization_flag(
                    "--monomorphize-min-benefit",
                  ),
                )
            }
            index += if consumed_next { 2 } else { 1 }
          }
          "low-memory-unused" => {
            if inline_value is Some(_) {
              return Err(
                CliParseError::unexpected_flag_value("--low-memory-unused"),
              )
            }
            parsed.low_memory_unused = Some(true)
            index += 1
          }
          "no-low-memory-unused" => {
            if inline_value is Some(_) {
              return Err(
                CliParseError::unexpected_flag_value("--no-low-memory-unused"),
              )
            }
            parsed.low_memory_unused = Some(false)
            index += 1
          }
          "low-memory-bound" => {
            let (value, consumed_next) = match inline_value {
              Some(v) if v.length() > 0 => (v, false)
              Some(_) =>
                return Err(
                  CliParseError::missing_flag_value("--low-memory-bound"),
                )
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  (args[index + 1], true)
                } else {
                  return Err(
                    CliParseError::missing_flag_value("--low-memory-bound"),
                  )
                }
            }
            match parse_non_negative_decimal(value) {
              Some(parsed_value) =>
                parsed.low_memory_bound = Some(parsed_value.to_uint64())
              None =>
                return Err(
                  CliParseError::invalid_optimization_flag("--low-memory-bound"),
                )
            }
            index += if consumed_next { 2 } else { 1 }
          }
          "closed-world" => {
            if inline_value is Some(_) {
              return Err(CliParseError::unexpected_flag_value("--closed-world"))
            }
            parsed.closed_world = Some(true)
            index += 1
          }
          "no-closed-world" => {
            if inline_value is Some(_) {
              return Err(
                CliParseError::unexpected_flag_value("--no-closed-world"),
              )
            }
            parsed.closed_world = Some(false)
            index += 1
          }
          "trap-mode" => {
            let (value, consumed_next) = match inline_value {
              Some(v) if v.length() > 0 => (v, false)
              Some(_) =>
                return Err(CliParseError::missing_flag_value("--trap-mode"))
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  (args[index + 1], true)
                } else {
                  return Err(CliParseError::missing_flag_value("--trap-mode"))
                }
            }
            match parse_trap_mode(value) {
              Some(mode) => parsed.trap_mode = Some(mode)
              None => return Err(CliParseError::invalid_trap_mode(value))
            }
            index += if consumed_next { 2 } else { 1 }
          }
          "traps-never-happen" => {
            if inline_value is Some(_) {
              return Err(
                CliParseError::unexpected_flag_value("--traps-never-happen"),
              )
            }
            parsed.trap_mode = Some(TrapMode::never())
            index += 1
          }
          "traps-may-happen" => {
            if inline_value is Some(_) {
              return Err(
                CliParseError::unexpected_flag_value("--traps-may-happen"),
              )
            }
            parsed.trap_mode = Some(TrapMode::allow())
            index += 1
          }
          "tracing" => {
            let (value, consumed_next) = match inline_value {
              Some(v) if v.length() > 0 => (v, false)
              Some(_) =>
                return Err(CliParseError::missing_flag_value("--tracing"))
              None =>
                if index + 1 < args.length() &&
                  !looks_like_option_token(args[index + 1]) {
                  (args[index + 1], true)
                } else {
                  return Err(CliParseError::missing_flag_value("--tracing"))
                }
            }
            match parse_tracing_level(value) {
              Some(level) => parsed.tracing = Some(level)
              None => return Err(CliParseError::invalid_tracing_level(value))
            }
            index += if consumed_next { 2 } else { 1 }
          }
          "debug-serial-passes" => {
            if inline_value is Some(_) {
              return Err(
                CliParseError::unexpected_flag_value("--debug-serial-passes"),
              )
            }
            parsed.debug_serial_passes = true
            index += 1
          }
          _ => {
            if !is_kebab_case_flag_name(name) {
              return Err(CliParseError::invalid_long_flag(name))
            }
            if name.has_prefix("print-") {
              let (value, consumed_next) = match inline_value {
                Some(v) if v.length() > 0 => (v, false)
                Some(_) =>
                  return Err(
                    CliParseError::missing_flag_value(long_flag_name(name)),
                  )
                None =>
                  if index + 1 < args.length() &&
                    !looks_like_option_token(args[index + 1]) {
                    (args[index + 1], true)
                  } else {
                    return Err(
                      CliParseError::missing_flag_value(long_flag_name(name)),
                    )
                  }
              }
              let print_flag = match parse_print_pass_value(name, value) {
                Ok(flag) => flag
                Err(err) => return Err(err)
              }
              parsed.pass_flags.push(print_flag)
              index += if consumed_next { 2 } else { 1 }
              continue
            }
            if inline_value is Some(_) {
              return Err(
                CliParseError::unexpected_flag_value(long_flag_name(name)),
              )
            }
            parsed.pass_flags.push(name)
            index += 1
          }
        }
        continue
      }
      match parse_short_option_cluster(args, index, parsed) {
        Ok(next_index) => index = next_index
        Err(e) => return Err(e)
      }
      continue
    }
    append_input_glob(parsed.input_globs, arg)
    index += 1
  }
  for env_glob in parse_starshine_input_env(starshine_input) {
    parsed.input_globs.push(env_glob)
  }
  if !parsed.help_requested &&
    !parsed.version_requested &&
    parsed.read_stdin &&
    parsed.input_format is None {
    return Err(CliParseError::stdin_needs_format())
  }
  Ok(parsed)
}

///|
pub fn resolve_pass_flags(parsed : CliParseResult) -> Array[String] {
  let resolved = Array::new()
  for flag in parsed.pass_flags {
    resolved.push(flag)
  }
  resolved
}

///|
pub fn resolve_traps_never_happen(
  parsed : CliParseResult,
  default? : Bool = false,
) -> Bool {
  match parsed.trap_mode {
    Some(Never) => true
    Some(Allow) => false
    None => default
  }
}

///|
pub fn resolve_closed_world(
  parsed : CliParseResult,
  default? : Bool = false,
) -> Bool {
  match parsed.closed_world {
    Some(value) => value
    None => default
  }
}
