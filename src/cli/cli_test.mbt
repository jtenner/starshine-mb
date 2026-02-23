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
test "parse_cli_args collects positional globs and pass flags in order" {
  let parsed = parse_ok([
    "inputs/**/*.wat", "--validate", "--souperfy", "extra/*.wasm",
  ])
  assert_eq(parsed.input_globs, ["inputs/**/*.wat", "extra/*.wasm"])
  assert_eq(parsed.pass_flags, ["validate", "souperfy"])
}

///|
test "parse_cli_args handles short output flags and values" {
  let parsed = parse_ok(["-s", "-o", "out.wasm", "-d", "dist"])
  assert_eq(parsed.output_targets, [
    CliOutputTarget::stdout(),
    CliOutputTarget::file("out.wasm"),
    CliOutputTarget::dir("dist"),
  ])
}

///|
test "parse_cli_args supports clustered short flags with attached values" {
  let parsed = parse_ok(["-soout.wasm", "-dtmp"])
  assert_eq(parsed.output_targets, [
    CliOutputTarget::stdout(),
    CliOutputTarget::file("out.wasm"),
    CliOutputTarget::dir("tmp"),
  ])
}

///|
test "parse_cli_args requires explicit format for stdin" {
  assert_eq(parse_err(["--stdin"]), CliParseError::stdin_needs_format())
}

///|
test "parse_cli_args accepts stdin when format is provided" {
  let parsed = parse_ok(["--stdin", "--format", "wat"])
  assert_true(parsed.read_stdin)
  assert_eq(parsed.input_format, Some(CliInputFormat::wat()))
}

///|
test "parse_cli_args rejects unknown format" {
  assert_eq(
    parse_err(["--stdin", "--format", "txt"]),
    CliParseError::invalid_input_format("txt"),
  )
}

///|
test "parse_cli_args uses default config path when --config has no value" {
  let parsed = parse_ok(["--config", "--stdout"])
  assert_eq(parsed.config_path, Some(DEFAULT_CONFIG_PATH))
  assert_eq(parsed.output_targets, [CliOutputTarget::stdout()])
}

///|
test "parse_cli_args reads explicit config path from -c" {
  let parsed = parse_ok(["-c", "local.json"])
  assert_eq(parsed.config_path, Some("local.json"))
}

///|
test "parse_starshine_input_env splits comma-separated globs" {
  assert_eq(
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
  assert_eq(parsed.input_globs, ["cli.wasm", "env/*.wat", "env/*.wast"])
}

///|
test "parse_cli_args allows multiple output targets and deduplicates identical targets" {
  let parsed = parse_ok([
    "--stdout", "-s", "--out", "a.wasm", "-o", "a.wasm", "--out-dir", "dist", "-d",
    "dist",
  ])
  assert_eq(parsed.output_targets, [
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
  assert_eq(parsed.pass_flags, [
    "validate", "abstract-type-refining", "code-folding",
  ])
}

///|
test "parse_cli_args rejects invalid long flag spelling" {
  assert_eq(
    parse_err(["--BadFlag"]),
    CliParseError::invalid_long_flag("BadFlag"),
  )
}

///|
test "parse_cli_args parses optimize presets and -O flags" {
  let parsed = parse_ok(["--optimize", "--shrink", "-O3z", "-O0"])
  assert_eq(parsed.optimize_flags, [
    CliOptimizationFlag::optimize(),
    CliOptimizationFlag::shrink(),
    CliOptimizationFlag::olevel(3, true),
    CliOptimizationFlag::olevel(0, false),
  ])
}

///|
test "parse_cli_args rejects invalid -O flag" {
  assert_eq(
    parse_err(["-Ozz"]),
    CliParseError::invalid_optimization_flag("-Ozz"),
  )
}

///|
test "parse_cli_args treats args after -- as positionals" {
  let parsed = parse_ok(["--stdout", "--", "--validate", "-s", "file.wasm"])
  assert_eq(parsed.output_targets, [CliOutputTarget::stdout()])
  assert_eq(parsed.pass_flags, [])
  assert_eq(parsed.input_globs, ["--validate", "-s", "file.wasm"])
}

///|
test "parse_cli_args rejects unknown short flag" {
  assert_eq(parse_err(["-x"]), CliParseError::unknown_short_flag('x'))
}

///|
test "parse_cli_args reports missing output value" {
  assert_eq(parse_err(["--out"]), CliParseError::missing_flag_value("--out"))
}

///|
test "parse_cli_args rejects unexpected pass flag values" {
  assert_eq(
    parse_err(["--validate=yes"]),
    CliParseError::unexpected_flag_value("--validate"),
  )
}

///|
test "infer_input_format handles wasm wat and wast extensions case-insensitively" {
  assert_eq(infer_input_format("a.wasm"), Some(CliInputFormat::wasm()))
  assert_eq(infer_input_format("A.WAT"), Some(CliInputFormat::wat()))
  assert_eq(
    infer_input_format("nested/file.WAST"),
    Some(CliInputFormat::wast()),
  )
  assert_eq(infer_input_format("a.txt"), None)
}

///|
test "cli_config_schema_json exposes public schema fields" {
  let schema = cli_config_schema_json()
  assert_true(schema.contains("\"schemaVersion\""))
  assert_true(schema.contains("\"inputs\""))
  assert_true(schema.contains("\"outputs\""))
  assert_true(schema.contains("\"passes\""))
  assert_true(schema.contains("\"format\""))
}
