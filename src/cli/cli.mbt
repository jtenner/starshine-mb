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
pub enum CliParseError {
  MissingFlagValue(String)
  InvalidInputFormat(String)
  StdinNeedsFormat
  UnknownShortFlag(Char)
  InvalidLongFlag(String)
  UnexpectedFlagValue(String)
  InvalidOptimizationFlag(String)
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
pub fn CliParseError::invalid_optimization_flag(flag : String) -> CliParseError {
  InvalidOptimizationFlag(flag)
}

///|
pub struct CliParseResult {
  mut config_path : String?
  input_globs : Array[String]
  mut read_stdin : Bool
  mut input_format : CliInputFormat?
  output_targets : Array[CliOutputTarget]
  pass_flags : Array[String]
  optimize_flags : Array[CliOptimizationFlag]
} derive(Eq, Show, Debug)

///|
pub fn CliParseResult::new(
  config_path? : String? = None,
  input_globs? : Array[String] = [],
  read_stdin? : Bool = false,
  input_format? : CliInputFormat? = None,
  output_targets? : Array[CliOutputTarget] = [],
  pass_flags? : Array[String] = [],
  optimize_flags? : Array[CliOptimizationFlag] = [],
) -> CliParseResult {
  {
    config_path,
    input_globs,
    read_stdin,
    input_format,
    output_targets,
    pass_flags,
    optimize_flags,
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
fn parse_input_format(raw : String) -> CliInputFormat? {
  match ascii_lower(raw) {
    "wasm" => Some(CliInputFormat::wasm())
    "wat" => Some(CliInputFormat::wat())
    "wast" => Some(CliInputFormat::wast())
    _ => None
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
  let body = token.sub(start=2).to_string() catch { _ => "" }
  let mut i = 0
  while i < body.length() {
    if body[i] == '=' {
      let name = body.sub(end=i).to_string() catch { _ => body }
      let value = body.sub(start=i + 1).to_string() catch { _ => "" }
      return (name, Some(value))
    }
    i += 1
  }
  (body, None)
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
  let body = flag.sub(start=2).to_string() catch { _ => "" }
  let mut i = 0
  let mut saw_digit = false
  let mut level = 2
  while i < body.length() {
    let c = body[i]
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
  if i < body.length() {
    if body[i] == 'z' {
      size_bias = true
      i += 1
    } else {
      return Err(CliParseError::invalid_optimization_flag(flag))
    }
  }
  if i != body.length() {
    return Err(CliParseError::invalid_optimization_flag(flag))
  }
  Ok(CliOptimizationFlag::olevel(level, size_bias))
}

///|
fn parse_short_option_cluster(
  args : Array[String],
  index : Int,
  parsed : CliParseResult,
) -> Result[Int, CliParseError] {
  let cluster = args[index].sub(start=1).to_string() catch { _ => "" }
  let mut i = 0
  while i < cluster.length() {
    let flag = cluster[i]
    match flag {
      's' => {
        push_unique_output_target(
          parsed.output_targets,
          CliOutputTarget::stdout(),
        )
        i += 1
      }
      'c' => {
        let attached = cluster.sub(start=i + 1).to_string() catch { _ => "" }
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
        let attached = cluster.sub(start=i + 1).to_string() catch { _ => "" }
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
        let attached = cluster.sub(start=i + 1).to_string() catch { _ => "" }
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
  let ext = normalized.sub(start=last_dot + 1).to_string() catch { _ => "" }
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
    #|  "optimize": {
    #|    "preset": "optimize",
    #|    "olevel": "O2"
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
          "optimize" => {
            if inline_value is Some(_) {
              return Err(CliParseError::unexpected_flag_value("--optimize"))
            }
            parsed.optimize_flags.push(CliOptimizationFlag::optimize())
            index += 1
          }
          "shrink" => {
            if inline_value is Some(_) {
              return Err(CliParseError::unexpected_flag_value("--shrink"))
            }
            parsed.optimize_flags.push(CliOptimizationFlag::shrink())
            index += 1
          }
          _ => {
            if inline_value is Some(_) {
              return Err(
                CliParseError::unexpected_flag_value(long_flag_name(name)),
              )
            }
            if !is_kebab_case_flag_name(name) {
              return Err(CliParseError::invalid_long_flag(name))
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
  if parsed.read_stdin && parsed.input_format is None {
    return Err(CliParseError::stdin_needs_format())
  }
  Ok(parsed)
}
