///|
enum CmdOptimizerReportMode {
  Thresholds
  ExpandedPassQueue
  RuntimeInterface
} derive(Eq, Debug)

///|
fn cmd_optimizer_report_flag_mode(flag : String) -> CmdOptimizerReportMode? {
  match flag {
    "--emit-optimizer-thresholds-json" => Some(Thresholds)
    "--emit-expanded-pass-queue-json" => Some(ExpandedPassQueue)
    "--emit-runtime-interface-json" => Some(RuntimeInterface)
    _ => None
  }
}

///|
fn cmd_extract_optimizer_report_mode(
  args : Array[String],
) -> Result[(Array[String], CmdOptimizerReportMode?), CmdError] {
  let filtered : Array[String] = []
  let mut report_mode : CmdOptimizerReportMode? = None
  for arg in args {
    match cmd_optimizer_report_flag_mode(arg) {
      Some(mode) =>
        match report_mode {
          Some(existing) if existing != mode =>
            return Err(
              CmdError::OptimizeFailed(
                "optimizer JSON report flags are mutually exclusive",
              ),
            )
          _ => report_mode = Some(mode)
        }
      None => filtered.push(arg)
    }
  }
  Ok((filtered, report_mode))
}

///|
fn cmd_write_optimizer_report_stdout(
  io : CmdIO,
  report : String,
) -> Result[Unit, CmdError] {
  match (io.write_stdout)(string_to_bytes("\{report}\n")) {
    Ok(_) => Ok(())
    Err(err) =>
      Err(CmdError::OutputWriteFailed("optimizer JSON report: \{err}"))
  }
}

///|
fn cmd_optimizer_json_escape(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text {
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn cmd_optimizer_json_string(text : String) -> String {
  "\"\{cmd_optimizer_json_escape(text)}\""
}

///|
fn cmd_optimizer_json_string_array(values : Array[String]) -> String {
  let out = StringBuilder::new()
  out.write_char('[')
  for idx, value in values {
    if idx > 0 {
      out.write_char(',')
    }
    out.write_string(cmd_optimizer_json_string(value))
  }
  out.write_char(']')
  out.to_string()
}

///|
fn cmd_optimizer_hash_hex_digit(value : UInt64) -> Char {
  let nibble = value.to_int()
  if nibble < 10 {
    (48 + nibble).unsafe_to_char()
  } else {
    (87 + nibble).unsafe_to_char()
  }
}

///|
fn cmd_optimizer_hash_bytes(bytes : Bytes) -> String {
  let mut hash = 1469598103934665603UL
  let prime = 1099511628211UL
  for byte in bytes {
    hash = (hash ^ byte.to_uint64()) * prime
  }
  let out = StringBuilder::new()
  let mut shift = 60
  while shift >= 0 {
    out.write_char(cmd_optimizer_hash_hex_digit((hash >> shift) & 0xFUL))
    shift -= 4
  }
  "fnv1a64:\{out}"
}

///|
fn cmd_optimizer_hash_text(text : String) -> String {
  cmd_optimizer_hash_bytes(string_to_bytes_lossy(text))
}

///|
fn cmd_optimizer_threshold_entry(
  name : String,
  value : String,
  source : String,
) -> String {
  "{\"schema\":\"starshine.optimizer-threshold.v1\",\"name\":\{cmd_optimizer_json_string(name)},\"value\":\{value},\"source\":\{cmd_optimizer_json_string(source)}}"
}

///|
fn cmd_optimizer_threshold_report_json(options : OptimizeOptions) -> String {
  let source = "src/cmd/cmd.mbt:resolved OptimizeOptions"
  let entries = [
    cmd_optimizer_threshold_entry(
      "always-inline-max-function-size",
      options.inlining.always_inline_max_size.to_string(),
      source,
    ),
    cmd_optimizer_threshold_entry(
      "one-caller-inline-max-function-size",
      options.inlining.one_caller_inline_max_size.to_string(),
      source,
    ),
    cmd_optimizer_threshold_entry(
      "flexible-inline-max-function-size",
      options.inlining.flexible_inline_max_size.to_string(),
      source,
    ),
    cmd_optimizer_threshold_entry(
      "inline-max-combined-binary-size",
      options.inlining.max_combined_binary_size.to_string(),
      source,
    ),
    cmd_optimizer_threshold_entry(
      "partial-inlining-ifs",
      options.inlining.partial_inlining_ifs.to_string(),
      source,
    ),
    cmd_optimizer_threshold_entry(
      "monomorphize-min-benefit",
      options.monomorphize_min_benefit.to_string(),
      source,
    ),
    cmd_optimizer_threshold_entry(
      "low-memory-bound",
      options.low_memory_bound.to_string(),
      source,
    ),
  ]
  "{\"schema\":\"starshine.optimizer-threshold-registry.v1\",\"source\":\"moonbit-resolved-options\",\"thresholds\":[\{entries.join(",")}]}"
}

///|
fn cmd_optimizer_pass_queue_report_json(
  mod_ : Module,
  options : OptimizeOptions,
  requested_passes : Array[String],
) -> Result[String, String] {
  let expanded = match
    @passes.pass_registry_expanded_names_for_module(
      mod_,
      optimize_options_to_hot_pipeline_options(options),
      requested_passes,
    ) {
    Ok(names) => names
    Err(err) => return Err(err)
  }
  let entries : Array[String] = []
  for ordinal, name in expanded {
    entries.push(
      "{\"ordinal\":\{ordinal},\"name\":\{cmd_optimizer_json_string(name)}}",
    )
  }
  Ok(
    "{\"schema\":\"starshine.optimizer-expanded-pass-queue.v1\",\"requested\":\{cmd_optimizer_json_string_array(requested_passes)},\"optimizeLevel\":\{options.optimize_level},\"shrinkLevel\":\{options.shrink_level},\"passes\":[\{entries.join(",")}]}",
  )
}

///|
fn cmd_optimizer_val_type_name(value_type : @lib.ValType) -> String {
  match value_type {
    @lib.NumTypeValType(@lib.I32NumType) => "i32"
    @lib.NumTypeValType(@lib.I64NumType) => "i64"
    @lib.NumTypeValType(@lib.F32NumType) => "f32"
    @lib.NumTypeValType(@lib.F64NumType) => "f64"
    @lib.VecTypeValType => "v128"
    @lib.RefTypeValType(ref_type) => cmd_optimizer_ref_type_name(ref_type)
    @lib.BotValType => "bottom"
  }
}

///|
fn cmd_optimizer_abs_heap_type_name(heap_type : @lib.AbsHeapType) -> String {
  match heap_type {
    @lib.FuncAbsHeapType | @lib.NoFuncAbsHeapType => "func"
    @lib.ExternAbsHeapType | @lib.NoExternAbsHeapType => "extern"
    @lib.AnyAbsHeapType | @lib.NoneAbsHeapType => "any"
    @lib.EqAbsHeapType => "eq"
    @lib.I31AbsHeapType => "i31"
    @lib.StructAbsHeapType => "struct"
    @lib.ArrayAbsHeapType => "array"
    @lib.ExnAbsHeapType | @lib.NoExnAbsHeapType => "exn"
    @lib.ContAbsHeapType | @lib.NoContAbsHeapType => "cont"
    @lib.StringAbsHeapType => "string"
  }
}

///|
fn cmd_optimizer_heap_type_name(heap_type : @lib.HeapType) -> String {
  match heap_type {
    @lib.AbsHeapTypeHeapType(abs) => cmd_optimizer_abs_heap_type_name(abs)
    @lib.SharedAbsHeapTypeHeapType(abs) =>
      "shared \{cmd_optimizer_abs_heap_type_name(abs)}"
    @lib.HeapType(@lib.TypeIdx(index)) => "type[\{index}]"
    @lib.HeapType(@lib.RecIdx(index)) => "rec[\{index}]"
    @lib.DefTypeHeapType(_) => "defined"
  }
}

///|
fn cmd_optimizer_ref_type_name(ref_type : @lib.RefType) -> String {
  match ref_type {
    @lib.AbsHeapTypeRefType(abs) =>
      match abs {
        @lib.FuncAbsHeapType => "funcref"
        @lib.ExternAbsHeapType => "externref"
        @lib.AnyAbsHeapType => "anyref"
        @lib.EqAbsHeapType => "eqref"
        @lib.I31AbsHeapType => "i31ref"
        @lib.StructAbsHeapType => "structref"
        @lib.ArrayAbsHeapType => "arrayref"
        @lib.ExnAbsHeapType => "exnref"
        @lib.ContAbsHeapType => "contref"
        _ => "(ref null \{cmd_optimizer_abs_heap_type_name(abs)})"
      }
    @lib.HeapTypeRefType(nullable, _, heap_type) => {
      let null_text = if nullable { " null" } else { "" }
      "(ref\{null_text} \{cmd_optimizer_heap_type_name(heap_type)})"
    }
  }
}

///|
fn cmd_optimizer_ref_type_nullable(ref_type : @lib.RefType) -> Bool {
  match ref_type {
    @lib.AbsHeapTypeRefType(_) => true
    @lib.HeapTypeRefType(nullable, _, _) => nullable
  }
}

///|
fn cmd_optimizer_value_type_support(value_type : String) -> String {
  match value_type {
    "i32" | "i64" | "f32" | "f64" => "directly-constructible"
    "v128" => "scalar-adapter"
    "funcref"
    | "externref"
    | "anyref"
    | "eqref"
    | "i31ref"
    | "structref"
    | "arrayref" => "retained-fixture"
    _ =>
      if value_type.contains("ref null") {
        "retained-fixture"
      } else {
        "unsupported"
      }
  }
}

///|
fn cmd_optimizer_signature_support(
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> String {
  let mut has_ref = false
  for value_type in params + results {
    let name = cmd_optimizer_val_type_name(value_type)
    if name == "v128" {
      return "scalar-adapter"
    }
    let support = cmd_optimizer_value_type_support(name)
    if support == "unsupported" {
      return "unsupported"
    }
    if support == "retained-fixture" {
      has_ref = true
    }
  }
  if has_ref {
    "retained-fixture"
  } else {
    "directly-constructible"
  }
}

///|
fn cmd_optimizer_val_type_array_json(values : Array[@lib.ValType]) -> String {
  let names : Array[String] = []
  for value in values {
    names.push(cmd_optimizer_val_type_name(value))
  }
  cmd_optimizer_json_string_array(names)
}

///|
fn cmd_optimizer_signature_json(func_type : @lib.FuncType?) -> String {
  match func_type {
    Some(@lib.FuncType(params, results)) =>
      "{\"params\":\{cmd_optimizer_val_type_array_json(params)},\"results\":\{cmd_optimizer_val_type_array_json(results)}}"
    None => "{\"params\":[],\"results\":[]}"
  }
}

///|
fn cmd_optimizer_signature_support_for_type(
  func_type : @lib.FuncType?,
) -> String {
  match func_type {
    Some(@lib.FuncType(params, results)) =>
      cmd_optimizer_signature_support(params, results)
    None => "unsupported"
  }
}

///|
fn cmd_optimizer_limits_parts(
  limits : @lib.Limits,
) -> (String, String, String, Bool) {
  match limits {
    @lib.I32Limits(minimum, maximum) =>
      (
        "i32",
        minimum.to_string(),
        match maximum {
          Some(value) => cmd_optimizer_json_string(value.to_string())
          None => "null"
        },
        false,
      )
    @lib.I64Limits(minimum, maximum) =>
      (
        "i64",
        minimum.to_string(),
        match maximum {
          Some(value) => cmd_optimizer_json_string(value.to_string())
          None => "null"
        },
        true,
      )
  }
}

///|
fn cmd_optimizer_memory_json(
  module_name : String,
  field_name : String,
  index : Int,
  memory_type : @lib.MemType,
) -> String {
  let @lib.MemType(limits, shared) = memory_type
  let (index_type, minimum, maximum, memory64) = cmd_optimizer_limits_parts(
    limits,
  )
  let support = if memory64 { "unsupported" } else { "directly-constructible" }
  "{\"module\":\{cmd_optimizer_json_string(module_name)},\"field\":\{cmd_optimizer_json_string(field_name)},\"kind\":\"memory\",\"index\":\{index},\"indexType\":\{cmd_optimizer_json_string(index_type)},\"minimum\":\{cmd_optimizer_json_string(minimum)},\"maximum\":\{maximum},\"shared\":\{shared},\"memory64\":\{memory64},\"support\":\{cmd_optimizer_json_string(support)}}"
}

///|
fn cmd_optimizer_table_json(
  module_name : String,
  field_name : String,
  index : Int,
  table_type : @lib.TableType,
) -> String {
  let @lib.TableType(ref_type, limits) = table_type
  let (_, minimum, maximum, _) = cmd_optimizer_limits_parts(limits)
  let element_type = cmd_optimizer_ref_type_name(ref_type)
  let support = if element_type == "funcref" || element_type == "externref" {
    "directly-constructible"
  } else {
    "unsupported"
  }
  "{\"module\":\{cmd_optimizer_json_string(module_name)},\"field\":\{cmd_optimizer_json_string(field_name)},\"kind\":\"table\",\"index\":\{index},\"elementType\":\{cmd_optimizer_json_string(element_type)},\"nullable\":\{cmd_optimizer_ref_type_nullable(ref_type)},\"minimum\":\{cmd_optimizer_json_string(minimum)},\"maximum\":\{maximum},\"support\":\{cmd_optimizer_json_string(support)}}"
}

///|
fn cmd_optimizer_runtime_interface_report_json(mod_ : Module) -> String {
  let env = @validate.Env::new().with_module(mod_)
  let function_types : Array[@lib.TypeIdx] = []
  let global_types : Array[@lib.GlobalType] = []
  let memory_types : Array[@lib.MemType] = []
  let table_types : Array[@lib.TableType] = []
  let tag_types : Array[@lib.TagType] = []
  let import_functions : Array[String] = []
  let import_globals : Array[String] = []
  let import_memories : Array[String] = []
  let import_tables : Array[String] = []
  let import_tags : Array[String] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        let @lib.Import(module_name_raw, field_name_raw, extern_type) = import_
        let module_name = cmd_name_to_string(module_name_raw)
        let field_name = cmd_name_to_string(field_name_raw)
        match extern_type {
          @lib.FuncExternType(type_idx) => {
            let index = function_types.length()
            function_types.push(type_idx)
            let func_type = env.resolve_functype(type_idx)
            import_functions.push(
              "{\"module\":\{cmd_optimizer_json_string(module_name)},\"field\":\{cmd_optimizer_json_string(field_name)},\"kind\":\"function\",\"index\":\{index},\"signature\":\{cmd_optimizer_signature_json(func_type)},\"support\":\{cmd_optimizer_json_string(cmd_optimizer_signature_support_for_type(func_type))}}",
            )
          }
          @lib.GlobalExternType(global_type) => {
            let index = global_types.length()
            global_types.push(global_type)
            let @lib.GlobalType(value_type, mutable) = global_type
            let value_name = cmd_optimizer_val_type_name(value_type)
            import_globals.push(
              "{\"module\":\{cmd_optimizer_json_string(module_name)},\"field\":\{cmd_optimizer_json_string(field_name)},\"kind\":\"global\",\"index\":\{index},\"valueType\":\{cmd_optimizer_json_string(value_name)},\"mutable\":\{mutable},\"support\":\{cmd_optimizer_json_string(cmd_optimizer_value_type_support(value_name))}}",
            )
          }
          @lib.MemExternType(memory_type) => {
            let index = memory_types.length()
            memory_types.push(memory_type)
            import_memories.push(
              cmd_optimizer_memory_json(
                module_name, field_name, index, memory_type,
              ),
            )
          }
          @lib.TableExternType(table_type) => {
            let index = table_types.length()
            table_types.push(table_type)
            import_tables.push(
              cmd_optimizer_table_json(
                module_name, field_name, index, table_type,
              ),
            )
          }
          @lib.TagExternType(tag_type) => {
            let index = tag_types.length()
            tag_types.push(tag_type)
            let @lib.TagType(type_idx) = tag_type
            let func_type = env.resolve_functype(type_idx)
            import_tags.push(
              "{\"module\":\{cmd_optimizer_json_string(module_name)},\"field\":\{cmd_optimizer_json_string(field_name)},\"kind\":\"tag\",\"index\":\{index},\"signature\":\{cmd_optimizer_signature_json(func_type)},\"support\":\"unsupported\"}",
            )
          }
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(types)) =>
      for type_idx in types {
        function_types.push(type_idx)
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(global_type, _) = global
        global_types.push(global_type)
      }
    None => ()
  }
  match mod_.mem_sec {
    Some(@lib.MemSec(memories)) => memory_types.append(memories)
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        let @lib.Table(table_type, _) = table
        table_types.push(table_type)
      }
    None => ()
  }
  match mod_.tag_sec {
    Some(@lib.TagSec(tags)) => tag_types.append(tags)
    None => ()
  }
  let exports : Array[String] = []
  match mod_.export_sec {
    Some(@lib.ExportSec(entries)) =>
      for export_ in entries {
        let @lib.Export(name_raw, extern_idx) = export_
        let name = cmd_name_to_string(name_raw)
        let record = match extern_idx {
          @lib.FuncExternIdx(@lib.FuncIdx(index)) => {
            let func_type = if index.to_int() < function_types.length() {
              env.resolve_functype(function_types[index.to_int()])
            } else {
              None
            }
            "{\"name\":\{cmd_optimizer_json_string(name)},\"kind\":\"function\",\"index\":\{index},\"signature\":\{cmd_optimizer_signature_json(func_type)},\"support\":\{cmd_optimizer_json_string(cmd_optimizer_signature_support_for_type(func_type))}}"
          }
          @lib.GlobalExternIdx(@lib.GlobalIdx(index)) =>
            if index.to_int() < global_types.length() {
              let @lib.GlobalType(value_type, mutable) = global_types[index.to_int()]
              let value_name = cmd_optimizer_val_type_name(value_type)
              "{\"name\":\{cmd_optimizer_json_string(name)},\"kind\":\"global\",\"index\":\{index},\"globalType\":{\"valueType\":\{cmd_optimizer_json_string(value_name)},\"mutable\":\{mutable}},\"support\":\{cmd_optimizer_json_string(cmd_optimizer_value_type_support(value_name))}}"
            } else {
              "{\"name\":\{cmd_optimizer_json_string(name)},\"kind\":\"global\",\"index\":\{index},\"support\":\"unsupported\"}"
            }
          @lib.MemExternIdx(@lib.MemIdx(index)) => {
            let support = if index.to_int() < memory_types.length() {
              let @lib.MemType(limits, _) = memory_types[index.to_int()]
              let (_, _, _, memory64) = cmd_optimizer_limits_parts(limits)
              if memory64 {
                "unsupported"
              } else {
                "directly-constructible"
              }
            } else {
              "unsupported"
            }
            "{\"name\":\{cmd_optimizer_json_string(name)},\"kind\":\"memory\",\"index\":\{index},\"support\":\{cmd_optimizer_json_string(support)}}"
          }
          @lib.TableExternIdx(@lib.TableIdx(index)) => {
            let support = if index.to_int() < table_types.length() {
              let @lib.TableType(ref_type, _) = table_types[index.to_int()]
              let element_type = cmd_optimizer_ref_type_name(ref_type)
              if element_type == "funcref" || element_type == "externref" {
                "directly-constructible"
              } else {
                "unsupported"
              }
            } else {
              "unsupported"
            }
            "{\"name\":\{cmd_optimizer_json_string(name)},\"kind\":\"table\",\"index\":\{index},\"support\":\{cmd_optimizer_json_string(support)}}"
          }
          @lib.TagExternIdx(@lib.TagIdx(index)) =>
            "{\"name\":\{cmd_optimizer_json_string(name)},\"kind\":\"tag\",\"index\":\{index},\"support\":\"unsupported\"}"
        }
        exports.push(record)
      }
    None => ()
  }
  let features : Array[String] = []
  if mod_.start_sec is Some(_) {
    features.push("start")
  }
  if memory_types.length() > 1 {
    features.push("multi-memory")
  }
  if table_types.length() > 1 {
    features.push("multi-table")
  }
  for memory_type in memory_types {
    let @lib.MemType(limits, shared) = memory_type
    if shared && !features.contains("threads") {
      features.push("threads")
    }
    if limits is @lib.I64Limits(_, _) && !features.contains("memory64") {
      features.push("memory64")
    }
  }
  let function_imports_json = import_functions.join(",")
  let global_imports_json = import_globals.join(",")
  let memory_imports_json = import_memories.join(",")
  let table_imports_json = import_tables.join(",")
  let tag_imports_json = import_tags.join(",")
  let exports_json = exports.join(",")
  let has_start = mod_.start_sec is Some(_)
  let imports_json = "{\"functions\":[\{function_imports_json}],\"globals\":[\{global_imports_json}],\"memories\":[\{memory_imports_json}],\"tables\":[\{table_imports_json}],\"tags\":[\{tag_imports_json}]}"
  let body = "\"features\":\{cmd_optimizer_json_string_array(features)},\"hasStart\":\{has_start},\"imports\":\{imports_json},\"exports\":[\{exports_json}]"
  let module_hash = match encode_module(mod_) {
    Ok(bytes) => cmd_optimizer_hash_bytes(bytes)
    Err(_) => "unavailable"
  }
  "{\"schema\":\"starshine.optimizer-runtime-interface.v1\",\"moduleHash\":\{cmd_optimizer_json_string(module_hash)},\"interfaceHash\":\{cmd_optimizer_json_string(cmd_optimizer_hash_text(body))},\{body}}"
}
