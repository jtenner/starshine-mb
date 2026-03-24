///|
pub struct ValidateTraceCliArgs {
  repeats : Int
  corpora : Array[String]
} derive(Eq, Show, Debug)

///|
pub enum ValidateTraceCliCommand {
  Run(ValidateTraceCliArgs)
  Help
  ListCorpora
} derive(Eq, Show, Debug)

///|
pub struct ValidateTraceBenchmarkResult {
  corpus : String
  repeats : Int
  elapsed_ms : UInt64
  phase_totals : String
  helper_totals : String
  hotspots : String?
} derive(Eq, Show, Debug)

///|
struct ValidateTraceCorpus {
  name : String
  mod : @lib.Module
}

///|
fn ValidateTraceCorpus::new(
  name : String,
  mod : @lib.Module,
) -> ValidateTraceCorpus {
  { name, mod }
}

///|
fn validate_trace_ascii_lower(input : String) -> String {
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
fn validate_trace_join(values : Array[String], sep : String) -> String {
  let out = StringBuilder::new()
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      out.write_string(sep)
    }
    out.write_string(values[i])
  }
  out.to_string()
}

///|
fn validate_trace_usage_text() -> String {
  let corpora = validate_trace_join(validate_trace_corpus_names(), ", ")
  "usage: moon run src/validate_trace -- [--repeat <n>] [--corpus <name> ...] [--list-corpora] [--help|-h]\ncorpora: \{corpora}"
}

///|
fn validate_trace_tail_string(input : String, start : Int) -> String {
  let out = StringBuilder::new()
  let mut i = start
  while i < input.length() {
    out.write_char(input[i].unsafe_to_char())
    i += 1
  }
  out.to_string()
}

///|
fn validate_trace_parse_positive_int(raw : String) -> Int {
  let text = raw.trim().to_string()
  if text.length() == 0 {
    abort("repeat must not be empty")
  }
  let mut value = 0
  for c in text {
    if c < '0' || c > '9' {
      abort("invalid repeat count '\{raw}'")
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  if value <= 0 {
    abort("repeat must be positive")
  }
  value
}

///|
fn validate_trace_has_repeat_equals_flag(arg : String) -> Bool {
  arg.length() >= 9 &&
  arg[0] == '-' &&
  arg[1] == '-' &&
  arg[2] == 'r' &&
  arg[3] == 'e' &&
  arg[4] == 'p' &&
  arg[5] == 'e' &&
  arg[6] == 'a' &&
  arg[7] == 't' &&
  arg[8] == '='
}

///|
fn validate_trace_trim_program_name(argv : Array[String]) -> Array[String] {
  if argv.length() == 0 {
    return []
  }
  let head = argv[0]
  let should_trim = head.contains("/") ||
    head.contains("\\") ||
    head.contains(".wasm") ||
    head.contains(".exe")
  if !should_trim {
    return argv
  }
  let out = Array::new(capacity=argv.length() - 1)
  for i = 1; i < argv.length(); i = i + 1 {
    out.push(argv[i])
  }
  out
}

///|
fn validate_trace_deep_control_module() -> @lib.Module {
  let depth = 24
  let mut body = [@lib.TypedInstr::local_get(@lib.LocalIdx::new(0))]
  for _ in 0..<depth {
    body = [
      @lib.TypedInstr::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        body,
      ),
    ]
  }
  let sig = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([sig]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([]),
        @lib.typed_instrs_to_expr(body),
      ),
    ]),
  )
}

///|
fn validate_trace_wide_locals_module() -> @lib.Module {
  let local_count = 384
  let locals = @lib.Locals::empty()
  for _ in 0..<local_count {
    locals.push(@lib.ValType::i32())
  }
  let body_instrs : Array[@lib.TypedInstr] = []
  for i = 0; i < local_count; i = i + 1 {
    body_instrs.push(
      @lib.TypedInstr::local_set(
        @lib.LocalIdx::new(i.reinterpret_as_uint()),
        @lib.TypedInstr::i32_const(@lib.I32(i)),
      ),
    )
  }
  for i = 0; i < local_count; i = i + 1 {
    body_instrs.push(
      @lib.TypedInstr::drop(
        @lib.TypedInstr::local_get(@lib.LocalIdx::new(i.reinterpret_as_uint())),
      ),
    )
  }
  let sig = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([sig]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(locals, @lib.typed_instrs_to_expr(body_instrs)),
    ]),
  )
}

///|
fn validate_trace_large_codesec_module() -> @lib.Module {
  let func_count = 160
  let sig = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let type_idxs : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  for i = 0; i < func_count; i = i + 1 {
    type_idxs.push(@lib.TypeIdx::new(0))
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.typed_instrs_to_expr([
          @lib.TypedInstr::drop(@lib.TypedInstr::i32_const(@lib.I32(i))),
          @lib.TypedInstr::drop(@lib.TypedInstr::i32_const(@lib.I32(i + 1))),
        ]),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([sig]))
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn validate_trace_ref_func_heavy_module() -> @lib.Module {
  let func_count = 48
  let sig = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let type_idxs : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  let declared_funcs : Array[@lib.FuncIdx] = []
  let init_exprs : Array[@lib.Expr] = []
  let globals : Array[@lib.Global] = []
  let exports : Array[@lib.Export] = []
  for i = 0; i < func_count; i = i + 1 {
    type_idxs.push(@lib.TypeIdx::new(0))
    let func_idx = @lib.FuncIdx::new(i.reinterpret_as_uint())
    declared_funcs.push(func_idx)
    if i < 16 {
      init_exprs.push(@lib.Expr::new([@lib.Instruction::ref_func(func_idx)]))
    }
    if i < 8 {
      globals.push(
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::funcref(), false),
          @lib.Expr::new([@lib.Instruction::ref_func(func_idx)]),
        ),
      )
      exports.push(
        @lib.Export::new(
          @lib.Name::new("rf\{i}"),
          @lib.ExternIdx::func(func_idx),
        ),
      )
    }
    let body_instrs : Array[@lib.TypedInstr] = []
    for j = 0; j < 12; j = j + 1 {
      let target = @lib.FuncIdx::new(
        ((i + j) % func_count).reinterpret_as_uint(),
      )
      body_instrs.push(@lib.TypedInstr::drop(@lib.TypedInstr::ref_func(target)))
    }
    funcs.push(
      @lib.Func::new(
        @lib.Locals::from_types([]),
        @lib.typed_instrs_to_expr(body_instrs),
      ),
    )
  }
  let elem_decls = @lib.Elem::new(
    @lib.ElemMode::declarative(),
    @lib.ElemKind::funcs(declared_funcs),
  )
  let elem_exprs = @lib.Elem::new(
    @lib.ElemMode::passive(),
    @lib.ElemKind::typed_exprs(
      @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
      init_exprs,
    ),
  )
  let table_type = @lib.TableType::new(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Limits::i32(func_count.reinterpret_as_uint(), None),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([sig]))
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        table_type,
        Some(@lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0))])),
      ),
    ]),
  )
  .with_global_sec(@lib.GlobalSec::new(globals))
  .with_export_sec(@lib.ExportSec::new(exports))
  .with_elem_sec(@lib.ElemSec::new([elem_decls, elem_exprs]))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn validate_trace_fixed_corpora() -> Array[ValidateTraceCorpus] {
  [
    ValidateTraceCorpus::new(
      "deep-control",
      validate_trace_deep_control_module(),
    ),
    ValidateTraceCorpus::new("wide-locals", validate_trace_wide_locals_module()),
    ValidateTraceCorpus::new(
      "large-codesec",
      validate_trace_large_codesec_module(),
    ),
    ValidateTraceCorpus::new(
      "ref-func-heavy",
      validate_trace_ref_func_heavy_module(),
    ),
  ]
}

///|
fn validate_trace_find_corpus(name : String) -> ValidateTraceCorpus? {
  for corpus in validate_trace_fixed_corpora() {
    if corpus.name == name {
      return Some(corpus)
    }
  }
  None
}

///|
fn validate_trace_find_last_prefix(
  lines : Array[String],
  prefix : String,
) -> String? {
  let mut i = lines.length() - 1
  while i >= 0 {
    if lines[i].has_prefix(prefix) {
      return Some(lines[i])
    }
    i -= 1
  }
  None
}

///|
fn validate_trace_run_one(
  corpus : ValidateTraceCorpus,
  repeats : Int,
) -> Result[ValidateTraceBenchmarkResult, String] {
  if repeats <= 0 {
    return Err("validate-trace repeat count must be positive")
  }
  let mut elapsed_ms = 0UL
  let mut phase_totals = ""
  let mut helper_totals = ""
  let mut hotspots : String? = None
  for _ in 0..<repeats {
    let lines : Array[String] = []
    let start_ms = @lib.trace_now_ms()
    match
      @validate.validate_module_with_trace(
        corpus.mod,
        fn(line) { lines.push(line) },
        trace_all_funcs=true,
      ) {
      Ok(_) => ()
      Err(err) =>
        return Err(
          "validate-trace corpus '\{corpus.name}' failed: \{@validate.validation_error_message(err)}",
        )
    }
    elapsed_ms = elapsed_ms + @lib.trace_elapsed_ms(start_ms)
    phase_totals = match
      validate_trace_find_last_prefix(lines, "phase_totals") {
      Some(line) => line
      None =>
        return Err(
          "validate-trace corpus '\{corpus.name}' did not emit phase_totals",
        )
    }
    helper_totals = match
      validate_trace_find_last_prefix(lines, "helper_totals") {
      Some(line) => line
      None =>
        return Err(
          "validate-trace corpus '\{corpus.name}' did not emit helper_totals",
        )
    }
    hotspots = validate_trace_find_last_prefix(lines, "hotspots ")
  }
  Ok({
    corpus: corpus.name,
    repeats,
    elapsed_ms,
    phase_totals,
    helper_totals,
    hotspots,
  })
}

///|
fn validate_trace_dedup_corpora(corpora : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for corpus in corpora {
    let mut seen = false
    for existing in out {
      if existing == corpus {
        seen = true
        break
      }
    }
    if !seen {
      out.push(corpus)
    }
  }
  out
}

///|
fn validate_trace_default_corpora() -> Array[String] {
  let out : Array[String] = []
  for corpus in validate_trace_fixed_corpora() {
    out.push(corpus.name)
  }
  out
}

///|
pub fn validate_trace_corpus_names() -> Array[String] {
  validate_trace_default_corpora()
}

///|
pub fn run_validate_trace_benchmark(
  corpora : Array[String],
  repeats : Int,
) -> Result[Array[ValidateTraceBenchmarkResult], String] {
  let selected = if corpora.length() == 0 {
    validate_trace_default_corpora()
  } else {
    validate_trace_dedup_corpora(corpora)
  }
  let results : Array[ValidateTraceBenchmarkResult] = []
  for name in selected {
    let corpus = match validate_trace_find_corpus(name) {
      Some(item) => item
      None => return Err("unknown validate-trace corpus '\{name}'")
    }
    match validate_trace_run_one(corpus, repeats) {
      Ok(result) => results.push(result)
      Err(e) => return Err(e)
    }
  }
  Ok(results)
}

///|
fn format_validate_trace_benchmark_result(
  result : ValidateTraceBenchmarkResult,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "corpus=\{result.corpus} repeats=\{result.repeats} elapsed_ms=\{result.elapsed_ms}\n",
  )
  out.write_string(result.phase_totals)
  out.write_char('\n')
  out.write_string(result.helper_totals)
  out.write_char('\n')
  match result.hotspots {
    Some(line) => out.write_string(line)
    None => out.write_string("hotspots none")
  }
  out.to_string()
}

///|
pub fn parse_validate_trace_cli_command(
  args : Array[String],
) -> ValidateTraceCliCommand {
  let mut repeats = 1
  let corpora : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i].trim().to_string()
    match validate_trace_ascii_lower(arg) {
      "--help" | "-h" => {
        if args.length() != 1 {
          abort("control flags must be provided alone")
        }
        return ValidateTraceCliCommand::Help
      }
      "--list-corpora" => {
        if args.length() != 1 {
          abort("control flags must be provided alone")
        }
        return ValidateTraceCliCommand::ListCorpora
      }
      "--repeat" => {
        if i + 1 >= args.length() {
          abort("missing value for --repeat")
        }
        repeats = validate_trace_parse_positive_int(args[i + 1])
        i += 2
        continue
      }
      "--corpus" => {
        if i + 1 >= args.length() {
          abort("missing value for --corpus")
        }
        corpora.push(validate_trace_ascii_lower(args[i + 1].trim().to_string()))
        i += 2
        continue
      }
      _ => ()
    }
    if validate_trace_has_repeat_equals_flag(arg) {
      repeats = validate_trace_parse_positive_int(
        validate_trace_tail_string(arg, 9),
      )
      i += 1
      continue
    }
    if arg.length() >= 2 && arg[0] == '-' && arg[1] == '-' {
      abort("unknown flag '\{arg}'")
    }
    abort(validate_trace_usage_text())
  }
  ValidateTraceCliCommand::Run({ repeats, corpora })
}

///|
fn main {
  let args = validate_trace_trim_program_name(@env.args())
  match parse_validate_trace_cli_command(args) {
    ValidateTraceCliCommand::Help => println(validate_trace_usage_text())
    ValidateTraceCliCommand::ListCorpora =>
      for corpus in validate_trace_corpus_names() {
        println(corpus)
      }
    ValidateTraceCliCommand::Run(parsed) =>
      match run_validate_trace_benchmark(parsed.corpora, parsed.repeats) {
        Ok(results) =>
          for i = 0; i < results.length(); i = i + 1 {
            if i > 0 {
              println("")
            }
            println(format_validate_trace_benchmark_result(results[i]))
          }
        Err(e) => abort(e)
      }
  }
}
