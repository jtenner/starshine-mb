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
pub struct AbstractTypeRefiningPassProps {
  traps_never_happen : Bool
} derive(Eq, Show, Debug)

///|
pub fn AbstractTypeRefiningPassProps::new(
  traps_never_happen? : Bool = false,
) -> AbstractTypeRefiningPassProps {
  { traps_never_happen, }
}

///|
pub struct MemoryPackingPassProps {
  zero_filled_memory : Bool
  traps_never_happen : Bool
} derive(Eq, Show, Debug)

///|
pub fn MemoryPackingPassProps::new(
  zero_filled_memory? : Bool = false,
  traps_never_happen? : Bool = false,
) -> MemoryPackingPassProps {
  { zero_filled_memory, traps_never_happen }
}

///|
pub enum ModulePass {
  NoOp(String)
  AbstractTypeRefining(AbstractTypeRefiningPassProps)
  AlignmentLowering
  AvoidReinterprets
  CoalesceLocals
  CodeFolding
  CodePushing
  ConstHoisting
  ConstantFieldPropagation
  ConstantFieldNullTestFolding
  DataflowOptimization
  DeadCodeElimination
  DeadArgumentElimination
  DeadArgumentEliminationOptimizing
  SignaturePruning
  SignatureRefining
  DuplicateImportElimination
  GlobalRefining
  GlobalStructInference
  GlobalStructInferenceDescCast
  GlobalTypeOptimization
  SimplifyGlobals
  SimplifyGlobalsOptimizing
  GlobalEffects
  PropagateGlobalsGlobally
  TypeRefining
  TypeGeneralizing
  TypeFinalizing
  TypeUnFinalizing
  Unsubtyping
  Heap2Local
  HeapStoreOptimization
  Inlining
  InliningOptimizing
  InlineMain
  LocalCSE
  LocalSubtyping
  LoopInvariantCodeMotion
  MergeLocals
  MergeSimilarFunctions
  MergeBlocks
  Flatten
  ReReloop
  TupleOptimization
  OnceReduction
  MinimizeRecGroups
  TypeMerging
  Monomorphize
  MonomorphizeAlways
  MemoryPacking(MemoryPackingPassProps)
  OptimizeAddedConstants
  OptimizeAddedConstantsPropagate
  OptimizeInstructions
  Precompute
  PrecomputePropagate
  RedundantSetElimination
  PickLoadSigns
  GUFA
  GUFAOptimizing
  GUFACastAll
  I64ToI32Lowering
  DuplicateFunctionElimination
  Directize(Bool)
  OptimizeCasts
  DeNaN
  RemoveUnusedBrs
  RemoveUnusedNames
  SimplifyLocals
  SimplifyLocalsNoTee
  SimplifyLocalsNoStructure
  SimplifyLocalsNoTeeNoStructure
  SimplifyLocalsNoNesting
  Untee
  Vacuum
  ReorderLocals
  ReorderTypes
  ReorderGlobals
  ReorderGlobalsAlways
  ReorderFunctions
  ReorderFunctionsByName
  RemoveUnusedTypes
  RemoveUnused
  RemoveUnusedModuleElements
  RemoveUnusedNonFunctionElements
} derive(Eq, Show, Debug)

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
      tracing~,
      debug_serial_passes~,
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
    tracing~,
    debug_serial_passes~,
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
    tracing~,
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
  low_memory_unused : Bool,
  low_memory_bound : UInt64,
  debug_serial_passes : Bool,
) -> OptimizeOptions {
  OptimizeOptions::new(
    optimize_level~,
    shrink_level~,
    inlining=default_inlining_options(),
    monomorphize_min_benefit~,
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
fn cmd_generated_pipeline_validation_kind(
  options : OptimizeOptions,
) -> ValidationKind {
  if options.validation_policy is AfterSegment {
    ValidationKind::full()
  } else {
    ValidationKind::unchecked()
  }
}

///|
fn cmd_generated_pipeline_global(options : OptimizeOptions) -> PipelineGlobal {
  PipelineGlobal::new(
    opt_level=options.optimize_level,
    shrink_level=options.shrink_level,
    validate=options.validation_policy is AfterSegment,
  )
}

///|
priv struct CmdGeneratedPipelineFeatureFacts {
  mut has_gc : Bool
  mut has_multivalue : Bool
  mut has_strings : Bool
}

///|
fn CmdGeneratedPipelineFeatureFacts::new() -> CmdGeneratedPipelineFeatureFacts {
  { has_gc: false, has_multivalue: false, has_strings: false }
}

///|
fn cmd_abs_heap_type_has_gc(abs : @lib.AbsHeapType) -> Bool {
  match abs {
    @lib.ArrayAbsHeapType
    | @lib.StructAbsHeapType
    | @lib.I31AbsHeapType
    | @lib.EqAbsHeapType
    | @lib.AnyAbsHeapType
    | @lib.NoneAbsHeapType => true
    _ => false
  }
}

///|
fn cmd_abs_heap_type_has_strings(abs : @lib.AbsHeapType) -> Bool {
  match abs {
    @lib.StringAbsHeapType => true
    _ => false
  }
}

///|
fn cmd_heap_type_has_gc(ht : @lib.HeapType) -> Bool {
  match ht {
    @lib.AbsHeapTypeHeapType(abs) => cmd_abs_heap_type_has_gc(abs)
    @lib.DefTypeHeapType(def) =>
      match def.project() {
        Some(subtype) =>
          match subtype.get_comptype() {
            @lib.ArrayCompType(_) | @lib.StructCompType(_) => true
            _ => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn cmd_instruction_has_gc(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.RefEq
    | @lib.StringNewUtf8Array
    | @lib.StringNewWtf16Array
    | @lib.StringEncodeUtf8Array
    | @lib.StringEncodeWtf16Array
    | @lib.StringNewLossyUtf8Array
    | @lib.StringNewWtf8Array
    | @lib.StringEncodeLossyUtf8Array
    | @lib.StringEncodeWtf8Array
    | @lib.StructNew(_)
    | @lib.StructNewDefault(_)
    | @lib.StructGet(_, _)
    | @lib.StructGetS(_, _)
    | @lib.StructGetU(_, _)
    | @lib.StructSet(_, _)
    | @lib.ArrayNew(_)
    | @lib.ArrayNewDefault(_)
    | @lib.ArrayNewFixed(_, _)
    | @lib.ArrayNewData(_, _)
    | @lib.ArrayNewElem(_, _)
    | @lib.ArrayGet(_)
    | @lib.ArrayGetS(_)
    | @lib.ArrayGetU(_)
    | @lib.ArraySet(_)
    | @lib.ArrayLen
    | @lib.ArrayFill(_)
    | @lib.ArrayCopy(_, _)
    | @lib.ArrayInitData(_, _)
    | @lib.ArrayInitElem(_, _)
    | @lib.RefGetDesc(_)
    | @lib.RefTest(_, _)
    | @lib.RefCast(_, _)
    | @lib.RefTestDesc(_, _)
    | @lib.RefCastDescEq(_, _)
    | @lib.BrOnCast(_, _, _, _)
    | @lib.BrOnCastFail(_, _, _, _)
    | @lib.AnyConvertExtern
    | @lib.ExternConvertAny
    | @lib.RefI31
    | @lib.I31GetS
    | @lib.I31GetU => true
    _ => false
  }
}

///|
fn cmd_tinstruction_has_gc(instr : @lib.TInstr) -> Bool {
  match instr.kind {
    @lib.TRefEq(_, _)
    | @lib.TStringNewUtf8Array(_, _, _)
    | @lib.TStringNewWtf16Array(_, _, _)
    | @lib.TStringEncodeUtf8Array(_, _, _)
    | @lib.TStringEncodeWtf16Array(_, _, _)
    | @lib.TStringNewLossyUtf8Array(_, _, _)
    | @lib.TStringNewWtf8Array(_, _, _)
    | @lib.TStringEncodeLossyUtf8Array(_, _, _)
    | @lib.TStringEncodeWtf8Array(_, _, _)
    | @lib.TStructNew(_, _)
    | @lib.TStructNewDefault(_)
    | @lib.TStructGet(_, _, _)
    | @lib.TStructGetS(_, _, _)
    | @lib.TStructGetU(_, _, _)
    | @lib.TStructSet(_, _, _, _)
    | @lib.TArrayNew(_, _, _)
    | @lib.TArrayNewDefault(_, _)
    | @lib.TArrayNewFixed(_, _)
    | @lib.TArrayNewData(_, _, _, _)
    | @lib.TArrayNewElem(_, _, _, _)
    | @lib.TArrayGet(_, _, _)
    | @lib.TArrayGetS(_, _, _)
    | @lib.TArrayGetU(_, _, _)
    | @lib.TArraySet(_, _, _, _)
    | @lib.TArrayLen(_)
    | @lib.TArrayFill(_, _, _, _, _)
    | @lib.TArrayCopy(_, _, _, _, _, _, _)
    | @lib.TArrayInitData(_, _, _, _, _, _)
    | @lib.TArrayInitElem(_, _, _, _, _, _)
    | @lib.TRefGetDesc(_)
    | @lib.TRefTest(_, _, _)
    | @lib.TRefCast(_, _, _)
    | @lib.TRefTestDesc(_, _, _)
    | @lib.TRefCastDescEq(_, _, _)
    | @lib.TBrOnCast(_, _, _, _, _, _)
    | @lib.TBrOnCastFail(_, _, _, _, _, _)
    | @lib.TAnyConvertExtern(_)
    | @lib.TExternConvertAny(_)
    | @lib.TRefI31(_)
    | @lib.TI31GetS(_)
    | @lib.TI31GetU(_) => true
    _ => false
  }
}

///|
fn cmd_generated_pipeline_feature_facts(
  mod : Module,
) -> CmdGeneratedPipelineFeatureFacts {
  let facts = CmdGeneratedPipelineFeatureFacts::new()
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new()
    .on_comptype_evt(fn(_, _, comp_type) {
      match comp_type {
        @lib.ArrayCompType(_) | @lib.StructCompType(_) => facts.has_gc = true
        @lib.FuncCompType(_, results) =>
          if results.length() > 1 {
            facts.has_multivalue = true
          }
      }
      unchanged()
    })
    .on_reftype_evt(fn(_, _, ref_type) {
      match ref_type {
        @lib.AbsHeapTypeRefType(abs) => {
          if cmd_abs_heap_type_has_gc(abs) {
            facts.has_gc = true
          }
          if cmd_abs_heap_type_has_strings(abs) {
            facts.has_strings = true
          }
        }
        _ => ()
      }
      unchanged()
    })
    .on_heaptype_evt(fn(_, _, heap_type) {
      if cmd_heap_type_has_gc(heap_type) {
        facts.has_gc = true
      }
      match heap_type {
        @lib.AbsHeapTypeHeapType(abs) =>
          if cmd_abs_heap_type_has_strings(abs) {
            facts.has_strings = true
          }
        _ => ()
      }
      unchanged()
    })
    .on_instruction_evt(fn(_, _, instr) {
      if cmd_instruction_has_gc(instr) {
        facts.has_gc = true
      }
      match instr {
        @lib.StringConst(_)
        | @lib.StringNewUtf8Array
        | @lib.StringNewWtf16Array
        | @lib.StringEncodeUtf8Array
        | @lib.StringEncodeWtf16Array
        | @lib.StringNewLossyUtf8Array
        | @lib.StringNewWtf8Array
        | @lib.StringEncodeLossyUtf8Array
        | @lib.StringEncodeWtf8Array => facts.has_strings = true
        _ => ()
      }
      match instr {
        @lib.Select(Some(types)) =>
          if types.length() > 1 {
            facts.has_multivalue = true
          }
        _ => ()
      }
      unchanged()
    })
    .on_tinstruction_evt(fn(_, _, instr) {
      if cmd_tinstruction_has_gc(instr) {
        facts.has_gc = true
      }
      match instr.kind {
        @lib.TStringConst(_)
        | @lib.TStringNewUtf8Array(_, _, _)
        | @lib.TStringNewWtf16Array(_, _, _)
        | @lib.TStringEncodeUtf8Array(_, _, _)
        | @lib.TStringEncodeWtf16Array(_, _, _)
        | @lib.TStringNewLossyUtf8Array(_, _, _)
        | @lib.TStringNewWtf8Array(_, _, _)
        | @lib.TStringEncodeLossyUtf8Array(_, _, _)
        | @lib.TStringEncodeWtf8Array(_, _, _) => facts.has_strings = true
        _ => ()
      }
      match instr.kind {
        @lib.TSelect(Some(types), _, _, _) =>
          if types.length() > 1 {
            facts.has_multivalue = true
          }
        _ => ()
      }
      unchanged()
    })
  ignore(walker.walk_module((), mod))
  facts
}

///|
fn cmd_generated_pipeline_features(
  mod : Module,
  options : OptimizeOptions,
) -> PipelineFeatures {
  let facts = cmd_generated_pipeline_feature_facts(mod)
  PipelineFeatures::new(
    has_gc=facts.has_gc,
    has_multivalue=facts.has_multivalue,
    has_strings=facts.has_strings,
    closed_world=options.closed_world,
    zero_filled_memory=options.zero_filled_memory,
    low_memory_unused=options.low_memory_unused,
    traps_never_happen=options.traps_never_happen,
  )
}

///|
fn cmd_append_generated_pipeline_entries(
  dst : Array[PipelineEntry],
  src : Array[PipelineEntry],
) -> Unit {
  for entry in src {
    dst.push(entry)
  }
}

///|
fn cmd_generated_pipeline_from_flags(
  mod : Module,
  pass_flags : Array[String],
  options : OptimizeOptions,
) -> Array[PipelineEntry] {
  let pipeline : Array[PipelineEntry] = []
  let global = cmd_generated_pipeline_global(options)
  let features = cmd_generated_pipeline_features(mod, options)
  let validation = cmd_generated_pipeline_validation_kind(options)
  for flag in pass_flags {
    match flag {
      "optimize" =>
        cmd_append_generated_pipeline_entries(
          pipeline,
          default_optimize_pipeline(global, features~),
        )
      "shrink" => {
        let shrink_global = PipelineGlobal::new(
          opt_level=options.optimize_level,
          shrink_level=max_int(options.shrink_level, 2),
          validate=global.validate,
        )
        cmd_append_generated_pipeline_entries(
          pipeline,
          default_optimize_pipeline(shrink_global, features~),
        )
      }
      "duplicate-function-elimination" =>
        add_pass_to_pipeline(
          pipeline,
          OptimizePass::DuplicateFunctionElimination,
          validation_kind=validation,
        )
      "remove-unused-module-elements" =>
        add_pass_to_pipeline(
          pipeline,
          OptimizePass::RemoveUnusedModuleElements,
          validation_kind=validation,
        )
      "memory-packing" =>
        add_pass_to_pipeline(
          pipeline,
          OptimizePass::MemoryPacking,
          validation_kind=validation,
        )
      "once-reduction" =>
        add_pass_to_pipeline(
          pipeline,
          OptimizePass::OnceReduction,
          validation_kind=validation,
        )
      "dead-code-elimination" =>
        add_pass_to_pipeline(
          pipeline,
          OptimizePass::DeadCodeElimination,
          validation_kind=validation,
        )
      "remove-unused-names" =>
        add_pass_to_pipeline(
          pipeline,
          OptimizePass::RemoveUnusedNames,
          validation_kind=validation,
        )
      _ => ()
    }
  }
  pipeline
}

///|
fn cmd_generated_pipeline_pass_count(pipeline : Array[PipelineEntry]) -> Int {
  let mut count = 0
  for entry in pipeline {
    count += entry.passes.length()
  }
  count
}

///|
fn cmd_generated_pipeline_all_locals(
  params : Array[@lib.ValType],
  local_decls : @lib.Locals,
) -> @lib.Locals {
  let all = @lib.Locals::from_types(params)
  all.append(local_decls)
  all
}

///|
fn cmd_generated_pipeline_type_lift_func(
  env : Env,
  type_idx : @lib.TypeIdx,
  func : @lib.Func,
  defined_idx : Int,
) -> Result[@lib.Func, String] {
  match func {
    @lib.TFunc(_, _, _) => Ok(func)
    @lib.Func(local_decls, expr) =>
      match env.resolve_functype(type_idx) {
        Some(@lib.FuncType(params, results)) => {
          let func_env = env
            .with_locals(cmd_generated_pipeline_all_locals(params, local_decls))
            .with_labels([results])
            .with_return_type(Some(results))
          match to_texpr(expr, func_env) {
            Ok(texpr) => Ok(@lib.Func::t_func(params, local_decls, texpr))
            Err(err) => Err("function[\{defined_idx}] pre-lift failed: \{err}")
          }
        }
        None => Err("function[\{defined_idx}] has unresolved type index")
      }
  }
}

///|
fn cmd_generated_pipeline_type_lift_module(
  mod : Module,
) -> Result[Module, String] {
  match (mod.func_sec, mod.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) =>
      if type_idxs.length() != funcs.length() {
        Err("generated pipeline pre-lift requires matching func/code lengths")
      } else {
        let env = Env::new().with_module(mod)
        let rewritten : Array[@lib.Func] = []
        let mut changed = false
        for i in 0..<funcs.length() {
          let next = match
            cmd_generated_pipeline_type_lift_func(
              env,
              type_idxs[i],
              funcs[i],
              i,
            ) {
            Ok(func) => func
            Err(err) => return Err(err)
          }
          if next != funcs[i] {
            changed = true
          }
          rewritten.push(next)
        }
        if changed {
          Ok(mod.with_code_sec(@lib.CodeSec::new(rewritten)))
        } else {
          Ok(mod)
        }
      }
    _ => Ok(mod)
  }
}

///|
fn cmd_truncate_generated_pipeline_entry(
  entry : PipelineEntry,
  keep : Int,
) -> PipelineEntry {
  if keep >= entry.passes.length() {
    return entry
  }
  let kept_passes : Array[OptimizePass] = []
  let mut i = 0
  while i < keep {
    kept_passes.push(entry.passes[i])
    i += 1
  }
  let group = match entry.group.kind() {
    FuncLocalGroup(funcs) => {
      let kept_funcs : Array[
        (Module, PipelineScratch) -> (Module, PipelineScratch),
      ] = []
      i = 0
      while i < keep {
        kept_funcs.push(funcs[i])
        i += 1
      }
      PassGroup::new(
        PassKind::func_local_group(kept_funcs),
        entry.group.validation_kind(),
      )
    }
    _ => entry.group
  }
  PipelineEntry::new(kept_passes, group)
}

///|
fn limit_generated_pipeline_by_max_passes(
  pipeline : Array[PipelineEntry],
  max_passes : Int?,
) -> (Array[PipelineEntry], Bool) {
  match max_passes {
    Some(limit) => {
      let out : Array[PipelineEntry] = []
      let mut remaining = limit
      let mut truncated = false
      for entry in pipeline {
        if remaining <= 0 {
          truncated = true
          break
        }
        if entry.passes.length() <= remaining {
          out.push(entry)
          remaining -= entry.passes.length()
        } else {
          out.push(cmd_truncate_generated_pipeline_entry(entry, remaining))
          truncated = true
          remaining = 0
        }
      }
      (out, truncated)
    }
    None => (pipeline, false)
  }
}

///|
fn expand_legacy_passes_for_module(
  pass_flags : Array[String],
  mod : Module,
  options : OptimizeOptions,
) -> Result[Array[ModulePass], CmdError] {
  let filtered : Array[String] = []
  for flag in pass_flags {
    match flag {
      "optimize"
      | "shrink"
      | "duplicate-function-elimination"
      | "remove-unused-module-elements"
      | "memory-packing"
      | "once-reduction"
      | "dead-code-elimination"
      | "remove-unused-names" => ()
      _ => filtered.push(flag)
    }
  }
  expand_passes_for_module(filtered, mod, options)
}

///|
fn cmd_validate_generated_pipeline_step(mod : Module) -> Result[Unit, String] {
  match validate_module(mod) {
    Ok(_) => Ok(())
    Err(err) => Err(validation_error_message(err))
  }
}

///|
fn run_generated_pipeline_with_options(
  mod : Module,
  pipeline : Array[PipelineEntry],
  options : OptimizeOptions,
) -> Result[Module, String] {
  let mut current = match cmd_generated_pipeline_type_lift_module(mod) {
    Ok(v) => v
    Err(err) => return Err("pipeline pre-lift failed: \{err}")
  }
  let mut global = cmd_generated_pipeline_global(options)
  let features = cmd_generated_pipeline_features(current, options)
  for entry in pipeline {
    match entry.group.kind() {
      Early(func) => {
        let (next, next_global) = func(current, global)
        current = next
        global = next_global
      }
      ModuleWide(func) => {
        let (next, next_global) = func(current, global, features)
        current = next
        global = next_global
      }
      FuncLocalGroup(funcs) => {
        let mut scratch = PipelineScratch::new()
        for func in funcs {
          let (next, next_scratch) = func(current, scratch)
          current = next
          scratch = next_scratch
        }
      }
    }
    if options.validation_policy is AfterSegment &&
      entry.group.validation_kind() != ValidationKind::unchecked() {
      match cmd_validate_generated_pipeline_step(current) {
        Ok(_) => ()
        Err(err) => return Err("pipeline validation failed: \{err}")
      }
    }
  }
  Ok(current)
}

///|
fn cmd_generated_pipeline_entry_trace_text(entry : PipelineEntry) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < entry.passes.length() {
    if i > 0 {
      out.write_string(",")
    }
    out.write_string(entry.passes[i].to_string())
    i += 1
  }
  out.to_string()
}

///|
fn run_generated_pipeline_with_options_trace(
  mod : Module,
  pipeline : Array[PipelineEntry],
  options : OptimizeOptions,
  trace : (String) -> Unit,
  trace_level? : OptimizeTracingLevel = OptimizeTracingLevel::pass(),
) -> Result[Module, String] {
  let _ = trace_level
  let mut current = match cmd_generated_pipeline_type_lift_module(mod) {
    Ok(v) => v
    Err(err) => return Err("pipeline pre-lift failed: \{err}")
  }
  let mut global = cmd_generated_pipeline_global(options)
  let features = cmd_generated_pipeline_features(current, options)
  for entry in pipeline {
    trace(
      "generated group start: \{cmd_generated_pipeline_entry_trace_text(entry)}",
    )
    match entry.group.kind() {
      Early(func) => {
        let (next, next_global) = func(current, global)
        current = next
        global = next_global
      }
      ModuleWide(func) => {
        let (next, next_global) = func(current, global, features)
        current = next
        global = next_global
      }
      FuncLocalGroup(funcs) => {
        let mut scratch = PipelineScratch::new()
        for func in funcs {
          let (next, next_scratch) = func(current, scratch)
          current = next
          scratch = next_scratch
        }
      }
    }
    if options.validation_policy is AfterSegment &&
      entry.group.validation_kind() != ValidationKind::unchecked() {
      match cmd_validate_generated_pipeline_step(current) {
        Ok(_) => trace("generated group validate ok")
        Err(err) => return Err("pipeline validation failed: \{err}")
      }
    }
    trace(
      "generated group done: \{cmd_generated_pipeline_entry_trace_text(entry)}",
    )
  }
  Ok(current)
}

///|
fn default_global_optimization_pre_passes(
  _mod : Module,
  _options : OptimizeOptions,
  closed_world? : Bool = true,
) -> Array[ModulePass] {
  let _ = closed_world
  []
}

///|
fn default_function_optimization_passes(
  _mod : Module,
  _options : OptimizeOptions,
) -> Array[ModulePass] {
  []
}

///|
fn default_global_optimization_post_passes(
  _mod : Module,
  _options : OptimizeOptions,
) -> Array[ModulePass] {
  []
}

///|
fn optimize_module_with_options(
  mod : Module,
  _passes : Array[ModulePass],
  _options : OptimizeOptions,
) -> Result[Module, String] {
  Ok(mod)
}

///|
fn optimize_module_with_options_trace(
  mod : Module,
  passes : Array[ModulePass],
  _options : OptimizeOptions,
  trace : (String) -> Unit,
  trace_level? : OptimizeTracingLevel = OptimizeTracingLevel::pass(),
) -> Result[Module, String] {
  let _ = trace_level
  if passes.length() > 0 {
    trace("legacy pass set is currently no-op: count=\{passes.length()}")
  }
  Ok(mod)
}

///|
fn explicit_pass_entries() -> Array[(String, String, ModulePass)] {
  [
    (
      "abstract-type-refining",
      "Refine abstract GC types using current trap assumptions.",
      ModulePass::AbstractTypeRefining(AbstractTypeRefiningPassProps::new()),
    ),
    (
      "alignment-lowering",
      "Lower alignment-heavy forms to simpler ops.",
      ModulePass::AlignmentLowering,
    ),
    (
      "avoid-reinterprets",
      "Reduce reinterpret traffic when equivalent forms exist.",
      ModulePass::AvoidReinterprets,
    ),
    (
      "coalesce-locals",
      "Pack local usage to reduce local count and churn.",
      ModulePass::CoalesceLocals,
    ),
    (
      "code-folding",
      "Fold structurally equivalent code fragments.",
      ModulePass::CodeFolding,
    ),
    (
      "code-pushing",
      "Push expressions toward optimal use sites.",
      ModulePass::CodePushing,
    ),
    (
      "const-hoisting",
      "Hoist duplicated constants for reuse.",
      ModulePass::ConstHoisting,
    ),
    (
      "constant-field-propagation",
      "Propagate known field constants across accesses.",
      ModulePass::ConstantFieldPropagation,
    ),
    (
      "constant-field-null-test-folding",
      "Fold ref.test/ref.test_desc on known-null constant fields.",
      ModulePass::ConstantFieldNullTestFolding,
    ),
    (
      "dataflow-optimization",
      "General dataflow simplification and cleanup.",
      ModulePass::DataflowOptimization,
    ),
    (
      "dead-code-elimination",
      "Remove instructions proven unreachable or unused.",
      ModulePass::DeadCodeElimination,
    ),
    (
      "dead-argument-elimination",
      "Drop function params that are never consumed.",
      ModulePass::DeadArgumentElimination,
    ),
    (
      "dead-argument-elimination-optimizing",
      "Run dead argument elimination with cleanup followup passes.",
      ModulePass::DeadArgumentEliminationOptimizing,
    ),
    (
      "signature-pruning",
      "Remove unneeded type signature details.",
      ModulePass::SignaturePruning,
    ),
    (
      "signature-refining",
      "Tighten function signatures based on observed use.",
      ModulePass::SignatureRefining,
    ),
    (
      "duplicate-import-elimination",
      "Merge duplicate imports with identical meaning.",
      ModulePass::DuplicateImportElimination,
    ),
    (
      "directize",
      "Turn immutable table call sites into direct calls.",
      ModulePass::Directize(true),
    ),
    (
      "global-refining",
      "Specialize globals using propagated facts.",
      ModulePass::GlobalRefining,
    ),
    (
      "global-struct-inference",
      "Infer stronger global struct value shapes.",
      ModulePass::GlobalStructInference,
    ),
    (
      "global-struct-inference-desc-cast",
      "Lower conservative global descriptor casts.",
      ModulePass::GlobalStructInferenceDescCast,
    ),
    (
      "global-type-optimization",
      "Optimize global type forms and annotations.",
      ModulePass::GlobalTypeOptimization,
    ),
    (
      "simplify-globals",
      "Simplify global initializers and access patterns.",
      ModulePass::SimplifyGlobals,
    ),
    (
      "simplify-globals-optimizing",
      "Run aggressive global simplification strategy.",
      ModulePass::SimplifyGlobalsOptimizing,
    ),
    (
      "global-effects",
      "Analyze and reduce cross-global side effects.",
      ModulePass::GlobalEffects,
    ),
    (
      "propagate-globals-globally",
      "Propagate global values across module scope.",
      ModulePass::PropagateGlobalsGlobally,
    ),
    (
      "type-refining",
      "Refine IR types toward more specific values.",
      ModulePass::TypeRefining,
    ),
    (
      "type-generalizing",
      "Generalize types where canonical forms help later passes.",
      ModulePass::TypeGeneralizing,
    ),
    (
      "type-finalizing",
      "Finalize type info for lowered output stages.",
      ModulePass::TypeFinalizing,
    ),
    (
      "type-un-finalizing",
      "Undo over-finalized type forms for rewrites.",
      ModulePass::TypeUnFinalizing,
    ),
    (
      "unsubtyping",
      "Replace subtype-heavy forms with simpler supertypes.",
      ModulePass::Unsubtyping,
    ),
    (
      "heap2local",
      "Sink eligible heap traffic into locals.",
      ModulePass::Heap2Local,
    ),
    (
      "heap-store-optimization",
      "Optimize heap store order and redundancy.",
      ModulePass::HeapStoreOptimization,
    ),
    ("inlining", "Inline eligible call sites.", ModulePass::Inlining),
    (
      "inlining-optimizing",
      "Inline with optimization-biased heuristics.",
      ModulePass::InliningOptimizing,
    ),
    (
      "inline-main",
      "Inline transitive calls from the primary entrypoint.",
      ModulePass::InlineMain,
    ),
    (
      "local-cse",
      "Eliminate repeated local computations.",
      ModulePass::LocalCSE,
    ),
    (
      "local-subtyping",
      "Improve local types using subtype relations.",
      ModulePass::LocalSubtyping,
    ),
    (
      "loop-invariant-code-motion",
      "Move loop-invariant work out of loops.",
      ModulePass::LoopInvariantCodeMotion,
    ),
    (
      "merge-locals",
      "Merge compatible locals to reduce state.",
      ModulePass::MergeLocals,
    ),
    (
      "merge-similar-functions",
      "Merge functions with equivalent structure.",
      ModulePass::MergeSimilarFunctions,
    ),
    (
      "merge-blocks",
      "Combine adjacent compatible blocks.",
      ModulePass::MergeBlocks,
    ),
    (
      "flatten",
      "Flatten nested control flow where possible.",
      ModulePass::Flatten,
    ),
    (
      "re-reloop",
      "Rebuild loop/branch structure into cleaner regions.",
      ModulePass::ReReloop,
    ),
    (
      "tuple-optimization",
      "Optimize tuple construction and projection.",
      ModulePass::TupleOptimization,
    ),
    (
      "once-reduction",
      "Remove redundant direct calls to provably run-once functions.",
      ModulePass::OnceReduction,
    ),
    (
      "minimize-rec-groups",
      "Shrink recursive type/function groups.",
      ModulePass::MinimizeRecGroups,
    ),
    (
      "type-merging",
      "Merge equivalent type definitions.",
      ModulePass::TypeMerging,
    ),
    (
      "monomorphize",
      "Specialize polymorphic call paths on demand.",
      ModulePass::Monomorphize,
    ),
    (
      "monomorphize-always",
      "Force broad monomorphization for all candidates.",
      ModulePass::MonomorphizeAlways,
    ),
    (
      "memory-packing",
      "Pack data segments and zero ranges into a denser memory layout.",
      ModulePass::MemoryPacking(MemoryPackingPassProps::new()),
    ),
    (
      "optimize-added-constants",
      "Combine and simplify additive constant math.",
      ModulePass::OptimizeAddedConstants,
    ),
    (
      "optimize-added-constants-propagate",
      "Propagate combined additive constants.",
      ModulePass::OptimizeAddedConstantsPropagate,
    ),
    (
      "optimize-instructions",
      "Local instruction peephole simplifications.",
      ModulePass::OptimizeInstructions,
    ),
    (
      "precompute",
      "Evaluate pure compile-time expressions early.",
      ModulePass::Precompute,
    ),
    (
      "precompute-propagate",
      "Propagate precomputed values through uses.",
      ModulePass::PrecomputePropagate,
    ),
    (
      "redundant-set-elimination",
      "Remove redundant set operations.",
      ModulePass::RedundantSetElimination,
    ),
    (
      "pick-load-signs",
      "Choose best signedness for load operations.",
      ModulePass::PickLoadSigns,
    ),
    (
      "gufa",
      "Run global unreferenced-function analysis cleanup.",
      ModulePass::GUFA,
    ),
    (
      "gufa-optimizing",
      "Run aggressive GUFA cleanup mode.",
      ModulePass::GUFAOptimizing,
    ),
    (
      "gufa-cast-all",
      "Apply GUFA-driven cast insertion broadly.",
      ModulePass::GUFACastAll,
    ),
    (
      "i64-to-i32-lowering",
      "Lower i64-heavy forms to i32-safe patterns.",
      ModulePass::I64ToI32Lowering,
    ),
    (
      "duplicate-function-elimination",
      "Deduplicate equivalent function bodies.",
      ModulePass::DuplicateFunctionElimination,
    ),
    (
      "optimize-casts",
      "Simplify and remove unnecessary casts.",
      ModulePass::OptimizeCasts,
    ),
    (
      "de-nan",
      "Canonicalize NaN behavior for optimization stability.",
      ModulePass::DeNaN,
    ),
    (
      "remove-unused-brs",
      "Remove never-targeted branch constructs.",
      ModulePass::RemoveUnusedBrs,
    ),
    (
      "remove-unused-names",
      "Strip unused debug and symbol names.",
      ModulePass::RemoveUnusedNames,
    ),
    (
      "simplify-locals",
      "General local get/set simplification.",
      ModulePass::SimplifyLocals,
    ),
    (
      "simplify-locals-no-tee",
      "Simplify locals without introducing tee_local.",
      ModulePass::SimplifyLocalsNoTee,
    ),
    (
      "simplify-locals-no-structure",
      "Simplify locals without structural rewrites.",
      ModulePass::SimplifyLocalsNoStructure,
    ),
    (
      "simplify-locals-no-tee-no-structure",
      "Simplify locals with both tee and structure disabled.",
      ModulePass::SimplifyLocalsNoTeeNoStructure,
    ),
    (
      "simplify-locals-no-nesting",
      "Simplify locals while avoiding nested expressions.",
      ModulePass::SimplifyLocalsNoNesting,
    ),
    ("untee", "Remove tee patterns into explicit locals.", ModulePass::Untee),
    (
      "vacuum",
      "Run final canonical cleanup and dead-node sweep.",
      ModulePass::Vacuum,
    ),
    (
      "reorder-locals",
      "Reorder locals for compact encoding.",
      ModulePass::ReorderLocals,
    ),
    ("reorder-types", "Reorder type section entries.", ModulePass::ReorderTypes),
    (
      "reorder-globals",
      "Reorder globals for deterministic layout.",
      ModulePass::ReorderGlobals,
    ),
    (
      "reorder-globals-always",
      "Force global reordering regardless of heuristics.",
      ModulePass::ReorderGlobalsAlways,
    ),
    (
      "reorder-functions",
      "Reorder functions for code quality goals.",
      ModulePass::ReorderFunctions,
    ),
    (
      "reorder-functions-by-name",
      "Reorder functions lexicographically by name.",
      ModulePass::ReorderFunctionsByName,
    ),
    (
      "remove-unused-types",
      "Drop type definitions with no remaining uses.",
      ModulePass::RemoveUnusedTypes,
    ),
    (
      "remove-unused",
      "Remove unused module items broadly.",
      ModulePass::RemoveUnused,
    ),
    (
      "remove-unused-module-elements",
      "Remove dead module-level elements.",
      ModulePass::RemoveUnusedModuleElements,
    ),
    (
      "remove-unused-non-function-elements",
      "Remove dead non-function module items.",
      ModulePass::RemoveUnusedNonFunctionElements,
    ),
  ]
}

///|
fn resolve_explicit_pass(flag : String) -> ModulePass? {
  for entry in explicit_pass_entries() {
    if entry.0 == flag {
      return Some(entry.2)
    }
  }
  None
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
fn limit_module_passes_by_max_passes(
  passes : Array[ModulePass],
  max_passes : Int?,
) -> (Array[ModulePass], Bool) {
  match max_passes {
    Some(limit) =>
      if limit < passes.length() {
        let out : Array[ModulePass] = []
        let mut i = 0
        while i < limit {
          out.push(passes[i])
          i += 1
        }
        (out, true)
      } else {
        (passes, false)
      }
    None => (passes, false)
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
fn cmd_post_encode_repro_note(
  io : CmdIO,
  mod : Module,
  passes : Array[ModulePass],
  options : OptimizeOptions,
  optimize_level : Int,
  shrink_level : Int,
  traps_never_happen : Bool,
  monomorphize_min_benefit : Int,
  low_memory_unused : Bool,
  low_memory_bound : UInt64,
) -> String {
  let _ = io
  let _ = mod
  let _ = passes
  let _ = options
  let _ = optimize_level
  let _ = shrink_level
  let _ = traps_never_happen
  let _ = monomorphize_min_benefit
  let _ = low_memory_unused
  let _ = low_memory_bound
  "\n\nRepro diagnosis unavailable: optimization pipeline is currently disabled."
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
    out, "--tracing <pass|phase|helper>", "Set optimization tracing level.",
  )
  append_help_line(
    out, "--debug-serial-passes", "Debug mode: run one pass per segment and validate after each pass.",
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
  for entry in explicit_pass_entries() {
    append_help_line(out, "--\{entry.0}", entry.1)
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
fn expand_passes_for_module(
  pass_flags : Array[String],
  mod : Module,
  options : OptimizeOptions,
) -> Result[Array[ModulePass], CmdError] {
  let max_vacuum_passes = 4
  let mut vacuum_passes = 0
  let out : Array[ModulePass] = []
  let push_pass = fn(pass : ModulePass) {
    match pass {
      Vacuum =>
        if vacuum_passes < max_vacuum_passes {
          out.push(pass)
          vacuum_passes += 1
        }
      _ => out.push(pass)
    }
  }
  for flag in pass_flags {
    match flag {
      "abstract-type-refining" =>
        push_pass(
          ModulePass::AbstractTypeRefining(
            AbstractTypeRefiningPassProps::new(
              traps_never_happen=options.traps_never_happen,
            ),
          ),
        )
      "memory-packing" =>
        push_pass(
          ModulePass::MemoryPacking(
            MemoryPackingPassProps::new(
              zero_filled_memory=options.zero_filled_memory,
              traps_never_happen=options.traps_never_happen,
            ),
          ),
        )
      "directize" => push_pass(ModulePass::Directize(true))
      "optimize" => {
        for pass in default_global_optimization_pre_passes(mod, options) {
          push_pass(pass)
        }
        for pass in default_function_optimization_passes(mod, options) {
          push_pass(pass)
        }
        for pass in default_global_optimization_post_passes(mod, options) {
          push_pass(pass)
        }
      }
      "shrink" => {
        let shrink_options = OptimizeOptions::new(
          optimize_level=options.optimize_level,
          shrink_level=max_int(options.shrink_level, 2),
          inlining=options.inlining,
          monomorphize_min_benefit=options.monomorphize_min_benefit,
          zero_filled_memory=options.zero_filled_memory,
          low_memory_unused=options.low_memory_unused,
          low_memory_bound=options.low_memory_bound,
          traps_never_happen=options.traps_never_happen,
        )
        for pass in default_global_optimization_pre_passes(mod, shrink_options) {
          push_pass(pass)
        }
        for pass in default_function_optimization_passes(mod, shrink_options) {
          push_pass(pass)
        }
        for pass in default_global_optimization_post_passes(mod, shrink_options) {
          push_pass(pass)
        }
      }
      _ =>
        match resolve_explicit_pass(flag) {
          Some(pass) => push_pass(pass)
          None => push_pass(ModulePass::NoOp(flag))
        }
    }
  }
  Ok(out)
}

///|
test "expand_passes_for_module leaves preset flags empty and keeps explicit no-op passes" {
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
  assert_eq(vacuum_count, 1)
}

///|
test "expand_passes_for_module caps vacuum passes to binaryen default bound" {
  let mod = Module::new()
  let expanded = match
    expand_passes_for_module(
      ["vacuum", "optimize", "vacuum", "shrink", "vacuum", "vacuum"],
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
  assert_eq(vacuum_count, 4)
}

///|
test "expand_passes_for_module turns unknown flags into explicit no-op markers" {
  let expanded = match
    expand_passes_for_module(
      ["not-a-real-pass"],
      Module::new(),
      OptimizeOptions::new(),
    ) {
    Ok(v) => v
    Err(e) => fail("expected unknown pass flag to expand as no-op, got \{e}")
  }
  assert_eq(expanded, [ModulePass::NoOp("not-a-real-pass")])
}

///|
test "expand_passes_for_module threads memory packing options from optimize options" {
  let expanded = match
    expand_passes_for_module(
      ["memory-packing"],
      Module::new(),
      OptimizeOptions::new(traps_never_happen=true, zero_filled_memory=true),
    ) {
    Ok(v) => v
    Err(e) => fail("expected memory-packing expansion success, got \{e}")
  }
  assert_eq(expanded, [
    ModulePass::MemoryPacking(
      MemoryPackingPassProps::new(
        traps_never_happen=true,
        zero_filled_memory=true,
      ),
    ),
  ])
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
    Err(err) =>
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
    low_memory_unused,
    low_memory_bound,
    merged.debug_serial_passes,
  )
  cmd_trace_emit(
    io,
    trace_optimize,
    "options o=\{optimize_level} z=\{shrink_level} traps_never=\{traps_never_happen}",
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

    let generated_expanded_pipeline = cmd_generated_pipeline_from_flags(
      mod, resolved_passes, options,
    )
    let generated_expanded_pass_count = cmd_generated_pipeline_pass_count(
      generated_expanded_pipeline,
    )
    let (generated_pipeline, generated_pipeline_truncated) = limit_generated_pipeline_by_max_passes(
      generated_expanded_pipeline, max_passes,
    )
    let generated_pass_count = cmd_generated_pipeline_pass_count(
      generated_pipeline,
    )
    let legacy_expanded_passes = match
      expand_legacy_passes_for_module(resolved_passes, mod, options) {
      Ok(passes) => passes
      Err(e) => return Err(e)
    }
    let legacy_max_passes = match max_passes {
      Some(limit) => Some(max_int(limit - generated_pass_count, 0))
      None => None
    }
    let (legacy_passes, legacy_passes_truncated) = limit_module_passes_by_max_passes(
      legacy_expanded_passes, legacy_max_passes,
    )
    let expanded_pass_count = generated_expanded_pass_count +
      legacy_expanded_passes.length()
    let effective_pass_count = generated_pass_count + legacy_passes.length()
    let expanded_passes_truncated = generated_pipeline_truncated ||
      legacy_passes_truncated ||
      expanded_pass_count != effective_pass_count
    match max_passes {
      Some(limit) =>
        cmd_trace_emit(
          io,
          trace_optimize,
          "input \{input_path}:pass_limit max_passes=\{limit} expanded_truncated=\{expanded_passes_truncated} expanded_pass_count=\{expanded_pass_count} effective_pass_count=\{effective_pass_count}",
        )
      None => ()
    }
    cmd_trace_emit(
      io,
      trace_optimize,
      "input \{input_path}:pass_count=\{effective_pass_count} optimize:start",
    )

    let optimized_after_generated = if trace_optimize {
      let resolved_trace_level = match trace_level {
        Some(level) => level
        None => OptimizeTracingLevel::pass()
      }
      match
        run_generated_pipeline_with_options_trace(
          mod,
          generated_pipeline,
          options,
          fn(msg) { cmd_trace_emit(io, true, "input \{input_path}:opt \{msg}") },
          trace_level=resolved_trace_level,
        ) {
        Ok(out) => out
        Err(e) => return Err(CmdError::OptimizeFailed("\{input_path}: \{e}"))
      }
    } else {
      match
        run_generated_pipeline_with_options(mod, generated_pipeline, options) {
        Ok(out) => out
        Err(e) => return Err(CmdError::OptimizeFailed("\{input_path}: \{e}"))
      }
    }
    let optimized = if trace_optimize && legacy_passes.length() > 0 {
      let resolved_trace_level = match trace_level {
        Some(level) => level
        None => OptimizeTracingLevel::pass()
      }
      match
        optimize_module_with_options_trace(
          optimized_after_generated,
          legacy_passes,
          options,
          fn(msg) { cmd_trace_emit(io, true, "input \{input_path}:opt \{msg}") },
          trace_level=resolved_trace_level,
        ) {
        Ok(out) => out
        Err(e) => return Err(CmdError::OptimizeFailed("\{input_path}: \{e}"))
      }
    } else {
      match
        optimize_module_with_options(
          optimized_after_generated, legacy_passes, options,
        ) {
        Ok(out) => out
        Err(e) => return Err(CmdError::OptimizeFailed("\{input_path}: \{e}"))
      }
    }
    cmd_trace_emit(io, trace_optimize, "input \{input_path}:optimize done")

    let out_bytes = match
      encode_module_for_pipeline(io, input_path, optimized) {
      Ok(bytes) => bytes
      Err(e) => return Err(e)
    }
    cmd_trace_emit(
      io,
      trace_optimize,
      "input \{input_path}:encode bytes=\{out_bytes.length()}",
    )
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
              io, mod, legacy_passes, options, optimize_level, shrink_level, traps_never_happen,
              monomorphize_min_benefit, low_memory_unused, low_memory_bound,
            ),
          ),
        )
    }
    cmd_trace_emit(
      io,
      trace_optimize,
      "input \{input_path}:post-encode-validate:done",
    )

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
fn default_cmd_io() -> CmdIO {
  CmdIO::new(
    get_env=cmd_native_get_env,
    file_exists=cmd_native_file_exists,
    read_file=cmd_native_read_file,
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
