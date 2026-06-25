///|
fn parse_ok(
  args : Array[String],
  starshine_input? : String? = None,
) -> CliParseResult {
  match parse_cli_args(args, starshine_input~) {
    Ok(parsed) => parsed
    Err(e) => abort("expected parser success but failed with \{e}")
  }
}

///|
fn parse_err(
  args : Array[String],
  starshine_input? : String? = None,
) -> CliParseError {
  match parse_cli_args(args, starshine_input~) {
    Ok(parsed) => abort("expected parser error but succeeded with \{parsed}")
    Err(e) => e
  }
}

///|
test "parse_cli_args collects positional inputs and pass flags in order" {
  let parsed = parse_ok([
    "inputs/**/*.wat", "--validate", "--souperfy", "extra/*.wasm",
  ])
  @debug.assert_eq(parsed.input_globs, ["inputs/**/*.wat", "extra/*.wasm"])
  @debug.assert_eq(parsed.pass_flags, ["validate", "souperfy"])
}

///|
test "parse_cli_args enables glob expansion for --glob and -g" {
  let long_flag = parse_ok(["--glob", "inputs/**/*.wat"])
  assert_true(long_flag.glob_enabled)
  @debug.assert_eq(long_flag.input_globs, ["inputs/**/*.wat"])

  let short_flag = parse_ok(["-g", "inputs/**/*.wat"])
  assert_true(short_flag.glob_enabled)
  @debug.assert_eq(short_flag.input_globs, ["inputs/**/*.wat"])
}

///|
test "parse_cli_args handles short output flags and values" {
  let parsed = parse_ok(["-s", "-o", "out.wasm", "-d", "dist"])
  @debug.assert_eq(parsed.output_targets, [
    CliOutputTarget::stdout(),
    CliOutputTarget::file("out.wasm"),
    CliOutputTarget::dir("dist"),
  ])
}

///|
test "parse_cli_args supports clustered short flags with attached values" {
  let parsed = parse_ok(["-soout.wasm", "-dtmp"])
  @debug.assert_eq(parsed.output_targets, [
    CliOutputTarget::stdout(),
    CliOutputTarget::file("out.wasm"),
    CliOutputTarget::dir("tmp"),
  ])
}

///|
test "parse_cli_args requires explicit format for stdin" {
  @debug.assert_eq(parse_err(["--stdin"]), CliParseError::stdin_needs_format())
}

///|
test "parse_cli_args accepts stdin when format is provided" {
  let parsed = parse_ok(["--stdin", "--format", "wat"])
  assert_true(parsed.read_stdin)
  @debug.assert_eq(parsed.input_format, Some(CliInputFormat::wat()))
}

///|
test "parse_cli_args rejects unknown format" {
  @debug.assert_eq(
    parse_err(["--stdin", "--format", "txt"]),
    CliParseError::invalid_input_format("txt"),
  )
}

///|
test "parse_cli_args marks help_requested for long and short help flags" {
  let long_help = parse_ok(["--help"])
  assert_true(long_help.help_requested)

  let short_help = parse_ok(["-h"])
  assert_true(short_help.help_requested)
}

///|
test "parse_cli_args marks version_requested for long and short version flags" {
  let long_version = parse_ok(["--version"])
  assert_true(long_version.version_requested)

  let short_version = parse_ok(["-V"])
  assert_true(short_version.version_requested)
}

///|
test "parse_cli_args allows --help to bypass stdin format requirement" {
  let parsed = parse_ok(["--help", "--stdin"])
  assert_true(parsed.help_requested)
  assert_true(parsed.read_stdin)
}

///|
test "parse_cli_args allows --version to bypass stdin format requirement" {
  let parsed = parse_ok(["--version", "--stdin"])
  assert_true(parsed.version_requested)
  assert_true(parsed.read_stdin)
}

///|
test "parse_cli_args uses default config path when --config has no value" {
  let parsed = parse_ok(["--config", "--stdout"])
  @debug.assert_eq(parsed.config_path, Some(DEFAULT_CONFIG_PATH))
  @debug.assert_eq(parsed.output_targets, [CliOutputTarget::stdout()])
}

///|
test "parse_cli_args reads explicit config path from -c" {
  let parsed = parse_ok(["-c", "local.json"])
  @debug.assert_eq(parsed.config_path, Some("local.json"))
}

///|
test "parse_starshine_input_env splits comma-separated globs" {
  @debug.assert_eq(
    parse_starshine_input_env(Some(" a/*.wasm, ,b/**/*.wat ,c.wast ")),
    ["a/*.wasm", "b/**/*.wat", "c.wast"],
  )
}

///|
test "parse_cli_args merges STARSHINE_INPUT globs after positionals" {
  let parsed = parse_ok(
    ["cli.wasm"],
    starshine_input=Some("env/*.wat,env/*.wast"),
  )
  @debug.assert_eq(parsed.input_globs, ["cli.wasm", "env/*.wat", "env/*.wast"])
}

///|
test "parse_cli_args allows multiple output targets and deduplicates identical targets" {
  let parsed = parse_ok([
    "--stdout", "-s", "--out", "a.wasm", "-o", "a.wasm", "--out-dir", "dist", "-d",
    "dist",
  ])
  @debug.assert_eq(parsed.output_targets, [
    CliOutputTarget::stdout(),
    CliOutputTarget::file("a.wasm"),
    CliOutputTarget::dir("dist"),
  ])
}

///|
test "parse_cli_args parses long-form kebab-case pass flags" {
  let parsed = parse_ok([
    "--validate", "--abstract-type-refining", "--code-folding",
  ])
  @debug.assert_eq(parsed.pass_flags, [
    "validate", "abstract-type-refining", "code-folding",
  ])
}

///|
test "parse_cli_args accepts no-inline wildcard pass values" {
  let parsed = parse_ok([
    "--no-inline=*maybe*", "--no-full-inline", "full-*", "--no-partial-inline=partial-*",
  ])
  @debug.assert_eq(parsed.pass_flags, [
    "no-inline=*maybe*", "no-full-inline=full-*", "no-partial-inline=partial-*",
  ])
}

///|
test "parse_cli_args accepts dump passes with separate and inline paths" {
  let parsed = parse_ok([
    "--dump", "before.wasm", "--ssa-nomerge", "--dump=after.wat", "--validate",
  ])
  @debug.assert_eq(parsed.pass_flags, [
    "dump=before.wasm", "ssa-nomerge", "dump=after.wat", "validate",
  ])
}

///|
test "parse_cli_args accepts print passes with named and indexed targets" {
  let parsed = parse_ok([
    "--print-func", "main", "--print-type=(0)", "--print-elem", "elist",
  ])
  @debug.assert_eq(parsed.pass_flags, [
    "print-func=main", "print-type=(0)", "print-elem=elist",
  ])
}

///|
test "parse_cli_args accepts extract-functions transform flags with separate and inline values" {
  let parsed = parse_ok([
    "--extract-functions", "4, 3", "--validate", "--extract-functions=0",
  ])
  @debug.assert_eq(parsed.pass_flags, [
    "extract-functions=4,3", "validate", "extract-functions=0",
  ])
}

///|
test "parse_cli_args rejects invalid extract-functions lists" {
  @debug.assert_eq(
    parse_err(["--extract-functions=1,x"]),
    CliParseError::invalid_function_index_list("1,x"),
  )
}

///|
test "parse_cli_args accepts global-effects pass flag" {
  let parsed = parse_ok(["--global-effects"])
  @debug.assert_eq(parsed.pass_flags, ["global-effects"])
}

///|
test "parse_cli_args accepts re-reloop pass flag" {
  let parsed = parse_ok(["--re-reloop"])
  @debug.assert_eq(parsed.pass_flags, ["re-reloop"])
}

///|
test "parse_cli_args rejects invalid long flag spelling" {
  @debug.assert_eq(
    parse_err(["--BadFlag"]),
    CliParseError::invalid_long_flag("BadFlag"),
  )
}

///|
test "parse_cli_args parses optimize presets and -O flags" {
  let parsed = parse_ok(["--optimize", "--shrink", "-O3z", "-O0"])
  @debug.assert_eq(parsed.pass_flags, ["optimize", "shrink"])
  @debug.assert_eq(parsed.optimize_flags, [
    CliOptimizationFlag::optimize(),
    CliOptimizationFlag::shrink(),
    CliOptimizationFlag::olevel(3, true),
    CliOptimizationFlag::olevel(0, false),
  ])
}

///|
test "parse_cli_args accepts trap-mode values and keeps them out of pass flags" {
  let parsed = parse_ok([
    "--trap-mode=never", "--trap-mode", "allow", "--validate",
  ])
  @debug.assert_eq(parsed.pass_flags, ["validate"])
}

///|
test "parse_cli_args accepts ignore-implicit-traps without treating it as a pass" {
  let parsed = parse_ok(["--ignore-implicit-traps", "--validate"])
  assert_true(parsed.ignore_implicit_traps)
  @debug.assert_eq(parsed.pass_flags, ["validate"])
  assert_true(!resolve_traps_never_happen(parsed))
}

///|
test "parse_cli_args accepts Binaryen -iit alias for ignore-implicit-traps" {
  let parsed = parse_ok(["-iit", "--code-pushing"])
  assert_true(parsed.ignore_implicit_traps)
  @debug.assert_eq(parsed.pass_flags, ["code-pushing"])
}

///|
test "parse_cli_args accepts mixed-case option values" {
  let parsed = parse_ok([
    "--format=WAT", "--trap-mode=TRAPS-NEVER-HAPPEN", "--tracing=HeLpEr",
  ])
  @debug.assert_eq(parsed.input_format, Some(CliInputFormat::wat()))
  @debug.assert_eq(parsed.trap_mode, Some(TrapMode::never()))
  @debug.assert_eq(parsed.tracing, Some(CliTracingLevel::helper()))
}

///|
test "parse_cli_args enables debug serial passes without treating it as a pass flag" {
  let parsed = parse_ok(["--debug-serial-passes", "--optimize", "--vacuum"])
  assert_true(parsed.debug_serial_passes)
  @debug.assert_eq(parsed.pass_flags, ["optimize", "vacuum"])
}

///|
test "parse_cli_args requires explicit trap-mode value" {
  @debug.assert_eq(
    parse_err(["--trap-mode"]),
    CliParseError::missing_flag_value("--trap-mode"),
  )
}

///|
test "parse_cli_args rejects invalid trap-mode value" {
  @debug.assert_eq(
    parse_err(["--trap-mode", "fast-and-loose"]),
    CliParseError::invalid_trap_mode("fast-and-loose"),
  )
}

///|
test "resolve_pass_flags omits trap-mode toggles from scheduled pass list" {
  let parsed = parse_ok([
    "--traps-never-happen", "--traps-may-happen", "--ignore-implicit-traps", "--flatten",
  ])
  @debug.assert_eq(resolve_pass_flags(parsed), ["flatten"])
}

///|
test "resolve_traps_never_happen applies trap-mode overrides with last flag winning" {
  let parsed_never = parse_ok(["--trap-mode=never"])
  assert_true(resolve_traps_never_happen(parsed_never))

  let parsed_allow = parse_ok(["--traps-never-happen", "--traps-may-happen"])
  assert_true(!resolve_traps_never_happen(parsed_allow))
}

///|
test "resolve_pass_flags preserves cli token order for presets and explicit passes" {
  let parsed = parse_ok([
    "--validate", "--code-folding", "--optimize", "--shrink", "--vacuum",
  ])
  @debug.assert_eq(resolve_pass_flags(parsed), [
    "validate", "code-folding", "optimize", "shrink", "vacuum",
  ])
}

///|
test "resolve_pass_flags keeps explicit pass order when no presets are set" {
  let parsed = parse_ok(["--vacuum", "--code-folding", "--validate"])
  @debug.assert_eq(resolve_pass_flags(parsed), [
    "vacuum", "code-folding", "validate",
  ])
}

///|
test "resolve_pass_flags ignores -O level flags for preset pass expansion" {
  let parsed = parse_ok(["-O3z", "--flatten"])
  @debug.assert_eq(resolve_pass_flags(parsed), ["flatten"])
}

///|
test "resolve_pass_flags preserves duplicate pass scheduling from repeated flags" {
  let parsed = parse_ok([
    "--vacuum", "--optimize", "--vacuum", "--shrink", "--vacuum",
  ])
  @debug.assert_eq(resolve_pass_flags(parsed), [
    "vacuum", "optimize", "vacuum", "shrink", "vacuum",
  ])
}

///|
test "parse_cli_args accepts named optimize and shrink level flags" {
  let parsed = parse_ok(["--optimize-level", "4", "--shrink-level=2"])
  @debug.assert_eq(parsed.optimize_flags, [
    CliOptimizationFlag::olevel(4, false),
    CliOptimizationFlag::olevel(2, true),
  ])
}

///|
test "parse_cli_args accepts inline long values for common option flags" {
  let parsed = parse_ok([
    "--config=local.json", "--format=wat", "--out=out.wasm", "--out-dir=dist", "--trap-mode=never",
    "--tracing=helper",
  ])
  @debug.assert_eq(parsed.config_path, Some("local.json"))
  @debug.assert_eq(parsed.input_format, Some(CliInputFormat::wat()))
  @debug.assert_eq(parsed.output_targets, [
    CliOutputTarget::file("out.wasm"),
    CliOutputTarget::dir("dist"),
  ])
  @debug.assert_eq(parsed.trap_mode, Some(TrapMode::never()))
  @debug.assert_eq(parsed.tracing, Some(CliTracingLevel::helper()))
}

///|
test "parse_cli_args accepts named optimization option flags" {
  let parsed = parse_ok([
    "--monomorphize-min-benefit", "9", "--low-memory-unused", "--low-memory-bound",
    "2048", "--no-low-memory-unused", "--closed-world", "--no-closed-world",
  ])
  @debug.assert_eq(parsed.monomorphize_min_benefit, Some(9))
  @debug.assert_eq(parsed.low_memory_bound, Some(2048UL))
  @debug.assert_eq(parsed.low_memory_unused, Some(false))
  @debug.assert_eq(parsed.closed_world, Some(false))
}

///|
test "parse_cli_args rejects invalid -O flag" {
  @debug.assert_eq(
    parse_err(["-Ozz"]),
    CliParseError::invalid_optimization_flag("-Ozz"),
  )
}

///|
test "parse_cli_args treats args after -- as positionals" {
  let parsed = parse_ok(["--stdout", "--", "--validate", "-s", "file.wasm"])
  @debug.assert_eq(parsed.output_targets, [CliOutputTarget::stdout()])
  @debug.assert_eq(parsed.pass_flags, [])
  @debug.assert_eq(parsed.input_globs, ["--validate", "-s", "file.wasm"])
}

///|
test "parse_cli_args rejects unknown short flag" {
  @debug.assert_eq(parse_err(["-x"]), CliParseError::unknown_short_flag('x'))
}

///|
test "parse_cli_args reports missing output value" {
  @debug.assert_eq(
    parse_err(["--out"]),
    CliParseError::missing_flag_value("--out"),
  )
}

///|
test "parse_cli_args rejects unexpected pass flag values" {
  @debug.assert_eq(
    parse_err(["--validate=yes"]),
    CliParseError::unexpected_flag_value("--validate"),
  )
}

///|
test "parse_cli_args reports missing dump path" {
  @debug.assert_eq(
    parse_err(["--dump"]),
    CliParseError::missing_flag_value("--dump"),
  )
}

///|
test "parse_cli_args reports missing print selector" {
  @debug.assert_eq(
    parse_err(["--print-func"]),
    CliParseError::missing_flag_value("--print-func"),
  )
}

///|
test "parse_cli_args rejects dump paths without wasm or wat extensions" {
  @debug.assert_eq(
    parse_err(["--dump", "snapshot.txt"]),
    CliParseError::invalid_dump_path("snapshot.txt"),
  )
}

///|
test "infer_input_format handles wasm wat and wast extensions case-insensitively" {
  @debug.assert_eq(infer_input_format("a.wasm"), Some(CliInputFormat::wasm()))
  @debug.assert_eq(infer_input_format("A.WAT"), Some(CliInputFormat::wat()))
  @debug.assert_eq(
    infer_input_format("nested/file.WAST"),
    Some(CliInputFormat::wast()),
  )
  @debug.assert_eq(infer_input_format("a.txt"), None)
}

///|
test "cli_config_schema_json exposes public schema fields" {
  let schema = cli_config_schema_json()
  assert_true(schema.contains("\"schemaVersion\""))
  assert_true(schema.contains("\"inputs\""))
  assert_true(schema.contains("\"outputs\""))
  assert_true(schema.contains("\"passes\""))
  assert_true(schema.contains("\"tracing\""))
  assert_true(schema.contains("\"format\""))
  assert_true(schema.contains("\"trapMode\""))
  assert_true(schema.contains("\"trapsNeverHappen\""))
  assert_true(schema.contains("\"ignoreImplicitTraps\""))
  assert_true(schema.contains("\"closedWorld\""))
}
