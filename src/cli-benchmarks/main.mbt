///|
pub struct CliBenchmarkArgs {
  iterations : Int
  warmup : Int
  jsonl : Bool
  target_args : Array[String]
} derive(Eq, Debug)

///|
pub fn CliBenchmarkArgs::new(
  iterations? : Int = 10000,
  warmup? : Int = 100,
  jsonl? : Bool = false,
  target_args? : Array[String] = [],
) -> CliBenchmarkArgs {
  {
    iterations,
    warmup,
    jsonl,
    target_args: if target_args.length() == 0 {
      cli_benchmark_default_target_args()
    } else {
      target_args
    },
  }
}

///|
pub enum CliBenchmarkCommand {
  Run(CliBenchmarkArgs)
  Help
} derive(Eq, Debug)

///|
pub struct CliBenchmarkResult {
  iterations : Int
  warmup : Int
  target_arg_count : Int
  parse_total_us : UInt64
  parse_avg_us : UInt64
  setup_total_us : UInt64
  setup_avg_us : UInt64
  parse_sink : Int
  setup_sink : Int
  optimize_level : Int
  shrink_level : Int
  effective_pass_count : Int
  resolved_passes : Array[String]
} derive(Eq, Debug)

///|
struct CliPipelineSetupSummary {
  input_files : Array[String]
  scheduled_passes : Array[String]
  resolved_passes : Array[String]
  optimize_level : Int
  shrink_level : Int
  effective_pass_count : Int
} derive(Eq, Debug)

///|
fn CliPipelineSetupSummary::new(
  input_files? : Array[String] = [],
  scheduled_passes? : Array[String] = [],
  resolved_passes? : Array[String] = [],
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
  effective_pass_count? : Int = 0,
) -> CliPipelineSetupSummary {
  {
    input_files,
    scheduled_passes,
    resolved_passes,
    optimize_level,
    shrink_level,
    effective_pass_count,
  }
}

///|
fn cli_benchmark_default_target_args() -> Array[String] {
  ["--optimize", "-O2", "bench-input.wasm"]
}

///|
fn cli_benchmark_usage_text() -> String {
  "usage: moon run src/cli-benchmarks -- [--iterations <n>] [--warmup <n>] [--jsonl] [--help|-h] [-- <starshine-cli-args...>]\nexample: moon run src/cli-benchmarks -- --iterations 50000 -- --optimize -O3 --closed-world input.wasm"
}

///|
fn cli_benchmark_tail_string(input : String, start : Int) -> String {
  let out = StringBuilder::new()
  let mut i = start
  while i < input.length() {
    out.write_char(input[i].unsafe_to_char())
    i += 1
  }
  out.to_string()
}

///|
fn cli_benchmark_parse_non_negative_int(raw : String, label : String) -> Int {
  let text = raw.trim().to_owned()
  if text.length() == 0 {
    abort("\{label} must not be empty")
  }
  let mut value = 0
  for c in text {
    if c < '0' || c > '9' {
      abort("invalid \{label} '\{raw}'")
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  value
}

///|
fn cli_benchmark_parse_positive_int(raw : String, label : String) -> Int {
  let value = cli_benchmark_parse_non_negative_int(raw, label)
  if value <= 0 {
    abort("\{label} must be positive")
  }
  value
}

///|
fn cli_benchmark_has_iterations_equals_flag(arg : String) -> Bool {
  arg.length() >= 13 &&
  arg[0] == '-' &&
  arg[1] == '-' &&
  arg[2] == 'i' &&
  arg[3] == 't' &&
  arg[4] == 'e' &&
  arg[5] == 'r' &&
  arg[6] == 'a' &&
  arg[7] == 't' &&
  arg[8] == 'i' &&
  arg[9] == 'o' &&
  arg[10] == 'n' &&
  arg[11] == 's' &&
  arg[12] == '='
}

///|
fn cli_benchmark_has_warmup_equals_flag(arg : String) -> Bool {
  arg.length() >= 9 &&
  arg[0] == '-' &&
  arg[1] == '-' &&
  arg[2] == 'w' &&
  arg[3] == 'a' &&
  arg[4] == 'r' &&
  arg[5] == 'm' &&
  arg[6] == 'u' &&
  arg[7] == 'p' &&
  arg[8] == '='
}

///|
fn cli_benchmark_trim_program_name(argv : Array[String]) -> Array[String] {
  if argv.length() == 0 {
    return []
  }
  let head = argv[0]
  let should_trim = head.contains("/") ||
    head.contains("\\") ||
    head.has_suffix("cli-benchmarks") ||
    head.has_suffix("cli-benchmarks.wasm")
  if !should_trim {
    return argv
  }
  let out : Array[String] = []
  let mut i = 1
  while i < argv.length() {
    out.push(argv[i])
    i += 1
  }
  out
}

///|
pub fn parse_cli_benchmark_command(args : Array[String]) -> CliBenchmarkCommand {
  let mut iterations = 10000
  let mut warmup = 100
  let mut jsonl = false
  let target_args : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--help" | "-h" => return CliBenchmarkCommand::Help
      "--jsonl" => {
        jsonl = true
        i += 1
        continue
      }
      "--iterations" | "--repeat" => {
        if i + 1 >= args.length() {
          abort("missing value for \{arg}")
        }
        iterations = cli_benchmark_parse_positive_int(args[i + 1], "iterations")
        i += 2
        continue
      }
      "--warmup" => {
        if i + 1 >= args.length() {
          abort("missing value for --warmup")
        }
        warmup = cli_benchmark_parse_non_negative_int(args[i + 1], "warmup")
        i += 2
        continue
      }
      "--" => {
        i += 1
        while i < args.length() {
          target_args.push(args[i])
          i += 1
        }
        break
      }
      _ => ()
    }
    if cli_benchmark_has_iterations_equals_flag(arg) {
      iterations = cli_benchmark_parse_positive_int(
        cli_benchmark_tail_string(arg, 13),
        "iterations",
      )
      i += 1
      continue
    }
    if cli_benchmark_has_warmup_equals_flag(arg) {
      warmup = cli_benchmark_parse_non_negative_int(
        cli_benchmark_tail_string(arg, 9),
        "warmup",
      )
      i += 1
      continue
    }
    if arg.length() >= 2 && arg[0] == '-' && arg[1] == '-' {
      abort(
        "unknown cli-benchmarks flag '\{arg}'\n\{cli_benchmark_usage_text()}",
      )
    }
    abort(cli_benchmark_usage_text())
  }
  CliBenchmarkCommand::Run(
    CliBenchmarkArgs::new(iterations~, warmup~, jsonl~, target_args~),
  )
}

///|
fn cli_benchmark_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn cli_benchmark_resolve_optimize_levels(
  flags : Array[@cli.CliOptimizationFlag],
) -> (Int, Int) {
  let mut optimize_level = 0
  let mut shrink_level = 0
  for flag in flags {
    match flag {
      @cli.OLevel(level, size_bias) => {
        optimize_level = cli_benchmark_max_int(optimize_level, level)
        if size_bias {
          shrink_level = cli_benchmark_max_int(shrink_level, level)
        }
      }
      @cli.OptimizePreset =>
        optimize_level = cli_benchmark_max_int(optimize_level, 2)
      @cli.ShrinkPreset => shrink_level = cli_benchmark_max_int(shrink_level, 2)
    }
  }
  (optimize_level, shrink_level)
}

///|
fn cli_benchmark_effective_pass_flags(
  pass_flags : Array[String],
  optimize_level : Int,
  shrink_level : Int,
) -> Array[String] {
  if pass_flags.length() > 0 {
    return pass_flags
  }
  let out : Array[String] = []
  if shrink_level > 0 {
    out.push("shrink")
  } else if optimize_level > 0 {
    out.push("optimize")
  }
  out
}

///|
fn cli_benchmark_is_pipeline_control_flag(flag : String) -> Bool {
  flag == "validate" ||
  flag.has_prefix("dump=") ||
  flag.has_prefix("extract-functions=") ||
  flag.has_prefix("print-")
}

///|
fn cli_benchmark_count_optimizer_passes(
  flags : Array[String],
) -> Result[Int, String] {
  let mut count = 0
  for flag in flags {
    if cli_benchmark_is_pipeline_control_flag(flag) {
      continue
    }
    let lookup = match @passes.no_inline_pass_pattern(flag) {
      Some((name, _)) => name
      None => flag
    }
    match @passes.pass_registry_category(lookup) {
      Some(category) if category == @passes.HotPassRegistryCategory::hot_pass() ||
        category == @passes.HotPassRegistryCategory::module_pass() ||
        category == @passes.HotPassRegistryCategory::preset() => count += 1
      Some(category) =>
        return Err(
          "pass flag \{flag} is not runnable in the hot pipeline (\{category})",
        )
      None => return Err("unknown pass flag \{flag}")
    }
  }
  Ok(count)
}

///|
fn cli_benchmark_setup_pipeline(
  target_args : Array[String],
) -> Result[CliPipelineSetupSummary, String] {
  let parsed = match @cli.parse_cli_args(target_args) {
    Ok(value) => value
    Err(e) => return Err("parse failed during setup: \{e}")
  }
  let input_files = parsed.input_globs.copy()
  if input_files.length() == 0 &&
    !parsed.help_requested &&
    !parsed.version_requested {
    return Err("no input files in benchmark target args")
  }
  let closed_world = @cli.resolve_closed_world(parsed)
  let (optimize_level, shrink_level) = cli_benchmark_resolve_optimize_levels(
    parsed.optimize_flags,
  )
  let scheduled_passes = cli_benchmark_effective_pass_flags(
    @cli.resolve_pass_flags(parsed),
    optimize_level,
    shrink_level,
  )
  ignore(
    @passes.HotPipelineOptions::new(
      closed_world~,
      optimize_level~,
      shrink_level~,
    ),
  )
  let effective_pass_count = match
    cli_benchmark_count_optimizer_passes(scheduled_passes) {
    Ok(value) => value
    Err(e) => return Err(e)
  }
  Ok(
    CliPipelineSetupSummary::new(
      input_files~,
      scheduled_passes~,
      resolved_passes=scheduled_passes,
      optimize_level~,
      shrink_level~,
      effective_pass_count~,
    ),
  )
}

///|
fn cli_benchmark_parse_sink(parsed : @cli.CliParseResult) -> Int {
  let mut sink = parsed.input_globs.length() +
    parsed.output_targets.length() +
    parsed.pass_flags.length() +
    parsed.optimize_flags.length()
  if parsed.glob_enabled {
    sink += 1
  }
  if parsed.read_stdin {
    sink += 1
  }
  if parsed.help_requested {
    sink += 1
  }
  if parsed.version_requested {
    sink += 1
  }
  sink
}

///|
fn cli_benchmark_setup_sink(summary : CliPipelineSetupSummary) -> Int {
  summary.input_files.length() +
  summary.scheduled_passes.length() +
  summary.resolved_passes.length() +
  summary.optimize_level +
  summary.shrink_level +
  summary.effective_pass_count
}

///|
fn cli_benchmark_avg_us(total_us : UInt64, iterations : Int) -> UInt64 {
  if iterations <= 0 {
    0UL
  } else {
    total_us / iterations.to_uint64()
  }
}

///|
pub fn run_cli_benchmark(
  args : CliBenchmarkArgs,
) -> Result[CliBenchmarkResult, String] {
  let mut warmup_i = 0
  while warmup_i < args.warmup {
    match @cli.parse_cli_args(args.target_args) {
      Ok(_) => ()
      Err(e) => return Err("parse warmup failed: \{e}")
    }
    match cli_benchmark_setup_pipeline(args.target_args) {
      Ok(_) => ()
      Err(e) => return Err("setup warmup failed: \{e}")
    }
    warmup_i += 1
  }

  let mut parse_sink = 0
  let parse_start_us = @lib.trace_now_us()
  let mut i = 0
  while i < args.iterations {
    match @cli.parse_cli_args(args.target_args) {
      Ok(parsed) => parse_sink += cli_benchmark_parse_sink(parsed)
      Err(e) => return Err("parse benchmark failed: \{e}")
    }
    i += 1
  }
  let parse_total_us = @lib.trace_elapsed_us_since(parse_start_us)

  let mut setup_sink = 0
  let mut last_summary = CliPipelineSetupSummary::new()
  let setup_start_us = @lib.trace_now_us()
  i = 0
  while i < args.iterations {
    match cli_benchmark_setup_pipeline(args.target_args) {
      Ok(summary) => {
        setup_sink += cli_benchmark_setup_sink(summary)
        last_summary = summary
      }
      Err(e) => return Err("setup benchmark failed: \{e}")
    }
    i += 1
  }
  let setup_total_us = @lib.trace_elapsed_us_since(setup_start_us)

  Ok({
    iterations: args.iterations,
    warmup: args.warmup,
    target_arg_count: args.target_args.length(),
    parse_total_us,
    parse_avg_us: cli_benchmark_avg_us(parse_total_us, args.iterations),
    setup_total_us,
    setup_avg_us: cli_benchmark_avg_us(setup_total_us, args.iterations),
    parse_sink,
    setup_sink,
    optimize_level: last_summary.optimize_level,
    shrink_level: last_summary.shrink_level,
    effective_pass_count: last_summary.effective_pass_count,
    resolved_passes: last_summary.resolved_passes,
  })
}

///|
fn cli_benchmark_join(values : Array[String], sep : String) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < values.length() {
    if i > 0 {
      out.write_string(sep)
    }
    out.write_string(values[i])
    i += 1
  }
  out.to_string()
}

///|
pub fn format_cli_benchmark_result(
  result : CliBenchmarkResult,
  jsonl : Bool,
) -> String {
  let passes = cli_benchmark_join(result.resolved_passes, ",")
  if jsonl {
    "{\"iterations\":\{result.iterations},\"warmup\":\{result.warmup},\"target_arg_count\":\{result.target_arg_count},\"parse_total_us\":\{result.parse_total_us},\"parse_avg_us\":\{result.parse_avg_us},\"setup_total_us\":\{result.setup_total_us},\"setup_avg_us\":\{result.setup_avg_us},\"optimize_level\":\{result.optimize_level},\"shrink_level\":\{result.shrink_level},\"effective_pass_count\":\{result.effective_pass_count},\"resolved_passes\":\"\{passes}\"}"
  } else {
    "cli_benchmark iterations=\{result.iterations} warmup=\{result.warmup} target_arg_count=\{result.target_arg_count} parse_total_us=\{result.parse_total_us} parse_avg_us=\{result.parse_avg_us} setup_total_us=\{result.setup_total_us} setup_avg_us=\{result.setup_avg_us} optimize_level=\{result.optimize_level} shrink_level=\{result.shrink_level} effective_pass_count=\{result.effective_pass_count} resolved_passes=\{passes}"
  }
}

///|
fn main {
  let argv = cli_benchmark_trim_program_name(@env.args())
  match parse_cli_benchmark_command(argv) {
    CliBenchmarkCommand::Help => println(cli_benchmark_usage_text())
    CliBenchmarkCommand::Run(args) =>
      match run_cli_benchmark(args) {
        Ok(result) => println(format_cli_benchmark_result(result, args.jsonl))
        Err(e) => abort(e)
      }
  }
}
