///|
pub(all) struct AsyncifyPassProps {
  imports : Array[String]
  ignore_imports : Bool
  ignore_indirect : Bool
  asserts : Bool
  ignore_unwind_from_catch : Bool
  verbose : Bool
  memory : String?
  removelist : Array[String]
  addlist : Array[String]
  propagate_addlist : Bool
  onlylist : Array[String]
  import_globals : Bool
  export_globals : Bool
  in_secondary_memory : Bool
  secondary_memory_size : UInt64
}

///|
fn AsyncifyPassProps::new(
  imports? : Array[String] = [],
  ignore_imports? : Bool = false,
  ignore_indirect? : Bool = false,
  asserts? : Bool = false,
  ignore_unwind_from_catch? : Bool = false,
  verbose? : Bool = false,
  memory? : String? = None,
  removelist? : Array[String] = [],
  addlist? : Array[String] = [],
  propagate_addlist? : Bool = false,
  onlylist? : Array[String] = [],
  import_globals? : Bool = false,
  export_globals? : Bool = false,
  in_secondary_memory? : Bool = false,
  secondary_memory_size? : UInt64 = 1024UL,
) -> AsyncifyPassProps {
  {
    imports,
    ignore_imports,
    ignore_indirect,
    asserts,
    ignore_unwind_from_catch,
    verbose,
    memory,
    removelist,
    addlist,
    propagate_addlist,
    onlylist,
    import_globals,
    export_globals,
    in_secondary_memory,
    secondary_memory_size,
  }
}

///|
const AF_RUNTIME_START_UNWIND : String = "asyncify_start_unwind"

///|
const AF_RUNTIME_STOP_UNWIND : String = "asyncify_stop_unwind"

///|
const AF_RUNTIME_START_REWIND : String = "asyncify_start_rewind"

///|
const AF_RUNTIME_STOP_REWIND : String = "asyncify_stop_rewind"

///|
const AF_RUNTIME_GET_STATE : String = "asyncify_get_state"

///|
const AF_GLOBAL_STATE : String = "__asyncify_state"

///|
const AF_GLOBAL_DATA : String = "__asyncify_data"

///|
const AF_STATE_NORMAL : Int = 0

///|
const AF_STATE_UNWINDING : Int = 1

///|
const AF_STATE_REWINDING : Int = 2

///|
const AF_STACK_ALIGN : UInt = 4

///|
priv struct AFPatternMatcher {
  pattern : String
}

///|
fn AFPatternMatcher::new(pattern : String) -> AFPatternMatcher {
  { pattern, }
}

///|
fn af_wildcard_match(pattern : String, value : String) -> Bool {
  // Greedy '*' wildcard matcher.
  let mut pi = 0
  let mut vi = 0
  let mut star_pi = -1
  let mut star_vi = -1
  while vi < value.length() {
    if pi < pattern.length() && pattern[pi] == '*' {
      star_pi = pi
      pi += 1
      star_vi = vi
      continue
    }
    if pi < pattern.length() && pattern[pi] == value[vi] {
      pi += 1
      vi += 1
      continue
    }
    if star_pi >= 0 {
      pi = star_pi + 1
      star_vi += 1
      vi = star_vi
      continue
    }
    return false
  }
  while pi < pattern.length() && pattern[pi] == '*' {
    pi += 1
  }
  pi == pattern.length()
}

///|
fn AFPatternMatcher::matches(self : AFPatternMatcher, value : String) -> Bool {
  af_wildcard_match(self.pattern, value)
}

///|
fn af_name_to_string(n : Name) -> String {
  let Name(sv) = n
  sv.to_string()
}

///|
fn af_count_imported_funcs(mod : Module) -> UInt {
  let mut n : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn af_count_imported_globals(mod : Module) -> UInt {
  let mut n : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn af_split_csv(s : String) -> Array[String] {
  if s.is_empty() {
    return []
  }
  let out : Array[String] = []
  let mut part = StringBuilder::new()
  let mut has_part = false
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == ',' {
      if has_part {
        out.push(part.to_string())
        part = StringBuilder::new()
        has_part = false
      }
    } else {
      part.write_char(s[i].unsafe_to_char())
      has_part = true
    }
  }
  if has_part {
    out.push(part.to_string())
  }
  out
}

///|
fn af_suffix(s : String, start : Int) -> String {
  let out = StringBuilder::new()
  for i = start; i < s.length(); i = i + 1 {
    out.write_char(s[i].unsafe_to_char())
  }
  out.to_string()
}

///|
fn af_parse_nonneg_int_from(s : String, start : Int) -> UInt64? {
  if start >= s.length() {
    return None
  }
  let mut value : UInt64 = 0UL
  for i = start; i < s.length(); i = i + 1 {
    let code = s[i].to_int()
    if code < 0x30 || code > 0x39 {
      return None
    }
    value = value * 10UL + (code - 0x30).to_uint64()
  }
  Some(value)
}

///|
fn af_push_unique(values : Array[String], value : String) -> Unit {
  for curr in values {
    if curr == value {
      return
    }
  }
  values.push(value)
}

///|
fn af_parse_list_arg(arg : String, prefix : String) -> Array[String]? {
  if arg.length() < prefix.length() {
    return None
  }
  let mut matched = true
  for i = 0; i < prefix.length(); i = i + 1 {
    if arg[i] != prefix[i] {
      matched = false
      break
    }
  }
  if !matched {
    return None
  }
  Some(af_split_csv(af_suffix(arg, prefix.length())))
}

///|
fn asyncify_apply_arguments(
  props : AsyncifyPassProps,
  args : Array[String],
) -> Result[AsyncifyPassProps, String] {
  let imports = props.imports.copy()
  let removelist = props.removelist.copy()
  let addlist = props.addlist.copy()
  let onlylist = props.onlylist.copy()
  let mut ignore_imports = props.ignore_imports
  let mut ignore_indirect = props.ignore_indirect
  let mut asserts = props.asserts
  let mut ignore_unwind_from_catch = props.ignore_unwind_from_catch
  let mut verbose = props.verbose
  let mut memory = props.memory
  let mut propagate_addlist = props.propagate_addlist
  let mut import_globals = props.import_globals
  let mut export_globals = props.export_globals
  let mut in_secondary_memory = props.in_secondary_memory
  let mut secondary_memory_size = props.secondary_memory_size
  for arg in args {
    if arg == "asyncify-ignore-imports" {
      ignore_imports = true
      continue
    }
    if arg == "asyncify-ignore-indirect" {
      ignore_indirect = true
      continue
    }
    if arg == "asyncify-asserts" {
      asserts = true
      continue
    }
    if arg == "asyncify-ignore-unwind-from-catch" {
      ignore_unwind_from_catch = true
      continue
    }
    if arg == "asyncify-verbose" {
      verbose = true
      continue
    }
    if arg == "asyncify-propagate-addlist" {
      propagate_addlist = true
      continue
    }
    if arg == "asyncify-import-globals" || arg == "asyncify-relocatable" {
      import_globals = true
      continue
    }
    if arg == "asyncify-export-globals" {
      export_globals = true
      continue
    }
    if arg == "asyncify-in-secondary-memory" {
      in_secondary_memory = true
      continue
    }
    match af_parse_list_arg(arg, "asyncify-imports@") {
      Some(values) => {
        for value in values {
          af_push_unique(imports, value)
        }
        continue
      }
      None => ()
    }
    match af_parse_list_arg(arg, "asyncify-removelist@") {
      Some(values) => {
        for value in values {
          af_push_unique(removelist, value)
        }
        continue
      }
      None => ()
    }
    match af_parse_list_arg(arg, "asyncify-blacklist@") {
      Some(values) => {
        for value in values {
          af_push_unique(removelist, value)
        }
        continue
      }
      None => ()
    }
    match af_parse_list_arg(arg, "asyncify-addlist@") {
      Some(values) => {
        for value in values {
          af_push_unique(addlist, value)
        }
        continue
      }
      None => ()
    }
    match af_parse_list_arg(arg, "asyncify-onlylist@") {
      Some(values) => {
        for value in values {
          af_push_unique(onlylist, value)
        }
        continue
      }
      None => ()
    }
    match af_parse_list_arg(arg, "asyncify-whitelist@") {
      Some(values) => {
        for value in values {
          af_push_unique(onlylist, value)
        }
        continue
      }
      None => ()
    }
    match af_parse_list_arg(arg, "asyncify-memory@") {
      Some(values) =>
        match values {
          [name, ..] => memory = Some(name)
          _ => ()
        }
      None => ()
    }
    let sec_mem_prefix = "asyncify-secondary-memory-size@"
    if arg.length() >= sec_mem_prefix.length() {
      let mut matched = true
      for i = 0; i < sec_mem_prefix.length(); i = i + 1 {
        if arg[i] != sec_mem_prefix[i] {
          matched = false
          break
        }
      }
      if matched {
        match af_parse_nonneg_int_from(arg, sec_mem_prefix.length()) {
          Some(v) => secondary_memory_size = v
          None => ()
        }
      }
    }
  }
  if !onlylist.is_empty() && (!addlist.is_empty() || !removelist.is_empty()) {
    return Err("asyncify: onlylist cannot be combined with addlist/removelist")
  }
  Ok(
    AsyncifyPassProps::new(
      imports~,
      ignore_imports~,
      ignore_indirect~,
      asserts~,
      ignore_unwind_from_catch~,
      verbose~,
      memory~,
      removelist~,
      addlist~,
      propagate_addlist~,
      onlylist~,
      import_globals~,
      export_globals~,
      in_secondary_memory~,
      secondary_memory_size~,
    ),
  )
}

///|
fn af_eval_children(instr : TInstr) -> Array[TInstr] {
  match instr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TUnreachable
    | TNop
    | TLocalGet(_)
    | TGlobalGet(_)
    | TMemorySize(_)
    | TTableSize(_)
    | TDataDrop(_)
    | TElemDrop(_)
    | TStructNewDefault(_) => []
    TUnary(_, child)
    | TDrop(child)
    | TLocalSet(_, child)
    | TLocalTee(_, child)
    | TGlobalSet(_, child)
    | TRefIsNull(child)
    | TRefAsNonNull(child)
    | TI31GetS(child)
    | TI31GetU(child)
    | TRefI31(child)
    | TArrayLen(child)
    | TAnyConvertExtern(child)
    | TExternConvertAny(child)
    | TThrowRef(child)
    | TMemoryGrow(_, child)
    | TTableGet(_, child)
    | TLoad(_, _, child)
    | TArrayNewDefault(_, child)
    | TStructGet(_, _, child)
    | TStructGetS(_, _, child)
    | TStructGetU(_, _, child)
    | TI8x16Splat(child)
    | TI16x8Splat(child)
    | TI32x4Splat(child)
    | TI64x2Splat(child)
    | TF32x4Splat(child)
    | TF64x2Splat(child)
    | TExtractLane(_, _, child)
    | TRefTest(_, _, child)
    | TRefCast(_, _, child) => [child]
    TBinary(_, left, right)
    | TRefEq(left, right)
    | TStore(_, _, left, right)
    | TTableSet(_, left, right)
    | TTableGrow(_, left, right)
    | TStructSet(_, _, left, right)
    | TArrayNew(_, left, right)
    | TArrayNewData(_, _, left, right)
    | TArrayNewElem(_, _, left, right)
    | TArrayGet(_, left, right)
    | TArrayGetS(_, left, right)
    | TArrayGetU(_, left, right)
    | TReplaceLane(_, _, left, right)
    | TI8x16Swizzle(left, right)
    | TI8x16RelaxedSwizzle(left, right)
    | TV128Shift(_, left, right)
    | TV128LoadLane(_, _, _, left, right)
    | TV128StoreLane(_, _, _, left, right) => [left, right]
    TMemoryFill(_, a, b, c)
    | TMemoryCopy(_, _, a, b, c)
    | TMemoryInit(_, _, a, b, c)
    | TTableFill(_, a, b, c)
    | TTableCopy(_, _, a, b, c)
    | TTableInit(_, _, a, b, c)
    | TSelect(_, c, a, b)
    | TV128Ternary(_, a, b, c) => [a, b, c]
    TCall(_, args)
    | TReturnCall(_, args)
    | TThrow(_, args)
    | TBr(_, args)
    | TReturn(args)
    | TStructNew(_, args)
    | TArrayNewFixed(_, args) => args.copy()
    TCallIndirect(_, _, args, index) | TReturnCallIndirect(_, _, args, index) => {
      let out = args.copy()
      out.push(index)
      out
    }
    TCallRef(_, args, ref_) | TReturnCallRef(_, args, ref_) => {
      let out = args.copy()
      out.push(ref_)
      out
    }
    TBrIf(_, cond, values) => {
      let out = values.copy()
      out.push(cond)
      out
    }
    TBrTable(_, _, index, values) => {
      let out = values.copy()
      out.push(index)
      out
    }
    TBrOnNull(_, ref_, values)
    | TBrOnNonNull(_, ref_, values)
    | TBrOnCast(_, _, _, _, ref_, values)
    | TBrOnCastFail(_, _, _, _, ref_, values) => {
      let out = values.copy()
      out.push(ref_)
      out
    }
    TArraySet(_, a, b, c) => [a, b, c]
    TArrayFill(_, a, b, c, d) => [a, b, c, d]
    TArrayCopy(_, _, a, b, c, d, e) => [a, b, c, d, e]
    TArrayInitData(_, _, a, b, c, d) => [a, b, c, d]
    TArrayInitElem(_, _, a, b, c, d) => [a, b, c, d]
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, left, right) =>
      [left, right]
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => []
  }
}

///|
fn af_make_zero(vt : ValType) -> TInstr? {
  match vt {
    NumTypeValType(I32NumType) => Some(TInstr::i32_const(I32(0)))
    NumTypeValType(I64NumType) => Some(TInstr::i64_const(I64(0L)))
    NumTypeValType(F32NumType) => Some(TInstr::f32_const(F32(0.0)))
    NumTypeValType(F64NumType) => Some(TInstr::f64_const(F64(0.0)))
    VecTypeValType =>
      Some(TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    RefTypeValType(rt) =>
      if rt.is_nullable() {
        Some(TInstr::ref_null(rt.get_heap_type()))
      } else {
        None
      }
    BotValType => Some(TInstr::unreachable_())
  }
}

///|
fn af_flattened_type_count(recs : Array[RecType]) -> Int {
  let mut n = 0
  for rec in recs {
    match rec {
      SingleRecType(_) => n += 1
      GroupRecType(sts) => n += sts.length()
    }
  }
  n
}

///|
fn af_append_type_func(
  mod : Module,
  params : Array[ValType],
  results : Array[ValType],
) -> (Module, TypeIdx) {
  let recs = match mod.type_sec {
    Some(TypeSec(xs)) => xs.copy()
    None => []
  }
  let idx = TypeIdx::new(af_flattened_type_count(recs).reinterpret_as_uint())
  recs.push(
    single_rec_type(comp_type_sub_type(func_comp_type(params, results))),
  )
  (mod.with_type_sec(TypeSec::new(recs)), idx)
}

///|
fn af_append_function(
  mod : Module,
  params : Array[ValType],
  results : Array[ValType],
  locals : Array[ValType],
  body : TExpr,
) -> (Module, FuncIdx) {
  let imported = af_count_imported_funcs(mod)
  let (mod, type_idx) = af_append_type_func(mod, params, results)
  let type_idxs = match mod.func_sec {
    Some(FuncSec(xs)) => xs.copy()
    None => []
  }
  type_idxs.push(type_idx)
  let mod = mod.with_func_sec(FuncSec::new(type_idxs))
  let funcs = match mod.code_sec {
    Some(CodeSec(xs)) => xs.copy()
    None => []
  }
  let abs_idx = imported + funcs.length().reinterpret_as_uint()
  funcs.push(Func::t_func(locals, body))
  (mod.with_code_sec(CodeSec::new(funcs)), FuncIdx::new(abs_idx))
}

///|
fn af_append_exported_function(
  mod : Module,
  export_name : String,
  params : Array[ValType],
  results : Array[ValType],
  locals : Array[ValType],
  body : TExpr,
) -> (Module, FuncIdx) {
  let (mod, idx) = af_append_function(mod, params, results, locals, body)
  let exports = match mod.export_sec {
    Some(ExportSec(xs)) => xs.copy()
    None => []
  }
  exports.push(Export::new(Name::new(export_name), ExternIdx::func(idx)))
  (mod.with_export_sec(ExportSec::new(exports)), idx)
}

///|
fn af_append_global(
  mod : Module,
  ty : ValType,
  mutable : Bool,
  init : TInstr,
) -> (Module, GlobalIdx) {
  let imported = af_count_imported_globals(mod)
  let globals = match mod.global_sec {
    Some(GlobalSec(xs)) => xs.copy()
    None => []
  }
  let idx = GlobalIdx::new(imported + globals.length().reinterpret_as_uint())
  globals.push(
    Global::new(GlobalType::new(ty, mutable), TExpr::new([init]).to_expr()),
  )
  (mod.with_global_sec(GlobalSec::new(globals)), idx)
}

///|
fn af_append_export_global(
  mod : Module,
  name : String,
  idx : GlobalIdx,
) -> Module {
  let exports = match mod.export_sec {
    Some(ExportSec(xs)) => xs.copy()
    None => []
  }
  exports.push(Export::new(Name::new(name), ExternIdx::global(idx)))
  mod.with_export_sec(ExportSec::new(exports))
}

///|
priv struct AFMemoryChoice {
  mem_idx : MemIdx
  pointer_type : ValType
}

///|
fn af_first_memory_limits(mod : Module) -> Limits? {
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, MemExternType(MemType(limits))) => return Some(limits)
          _ => ()
        }
      }
    None => ()
  }
  match mod.mem_sec {
    Some(MemSec(mems)) =>
      match mems {
        [MemType(limits), ..] => Some(limits)
        _ => None
      }
    None => None
  }
}

///|
fn af_ensure_memory_exists(mod : Module) -> Module {
  match af_first_memory_limits(mod) {
    Some(_) => mod
    None => mod.with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
  }
}

///|
fn af_collect_memory_export_names(mod : Module) -> Map[MemIdx, String] {
  let out = Map::new()
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          Export(name, MemExternIdx(idx)) => out[idx] = af_name_to_string(name)
          _ => ()
        }
      }
    None => ()
  }
  out
}

///|
fn af_collect_memory_limits(mod : Module) -> Array[Limits] {
  let out : Array[Limits] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, MemExternType(MemType(limits))) => out.push(limits)
          _ => ()
        }
      }
    None => ()
  }
  match mod.mem_sec {
    Some(MemSec(mems)) =>
      for mem in mems {
        let MemType(limits) = mem
        out.push(limits)
      }
    None => ()
  }
  out
}

///|
fn af_is_memory64(limits : Limits) -> Bool {
  match limits {
    I64Limits(_, _) => true
    _ => false
  }
}

///|
fn af_memory_choice(
  mod : Module,
  props : AsyncifyPassProps,
) -> Result[(Module, AFMemoryChoice), String] {
  let mod = if props.in_secondary_memory {
    let mems = match mod.mem_sec {
      Some(MemSec(xs)) => xs.copy()
      None => []
    }
    mems.push(
      MemType::new(
        Limits::i32(
          props.secondary_memory_size.to_uint(),
          Some(props.secondary_memory_size.to_uint()),
        ),
      ),
    )
    mod.with_mem_sec(MemSec::new(mems))
  } else {
    af_ensure_memory_exists(mod)
  }
  let limits = af_collect_memory_limits(mod)
  if limits.is_empty() {
    return Err("asyncify: no memory available")
  }
  let chosen_idx = if props.in_secondary_memory {
    MemIdx::new((limits.length() - 1).reinterpret_as_uint())
  } else if limits.length() == 1 {
    MemIdx::new(0)
  } else {
    match props.memory {
      Some(name) => {
        let exports = af_collect_memory_export_names(mod)
        let mut matched : MemIdx? = None
        for entry in exports {
          let (idx, export_name) = entry
          if export_name == name {
            matched = Some(idx)
            break
          }
        }
        match matched {
          Some(idx) => idx
          None =>
            return Err(
              "asyncify: multiple memories present; set asyncify-memory@<export>",
            )
        }
      }
      None =>
        return Err(
          "asyncify: multiple memories present; set asyncify-memory@<export>",
        )
    }
  }
  let MemIdx(raw_idx) = chosen_idx
  let pointer_type = match limits.get(raw_idx.reinterpret_as_int()) {
    Some(lim) =>
      if af_is_memory64(lim) {
        ValType::i64()
      } else {
        ValType::i32()
      }
    None => ValType::i32()
  }
  Ok((mod, { mem_idx: chosen_idx, pointer_type }))
}

///|
priv struct AFApi {
  state_global : GlobalIdx
  data_global : GlobalIdx
  runtime_start_unwind : FuncIdx
  runtime_stop_unwind : FuncIdx
  runtime_start_rewind : FuncIdx
  runtime_stop_rewind : FuncIdx
  intr_unwind : FuncIdx
  intr_get_call_index : FuncIdx
  intr_check_call_index : FuncIdx
}

///|
fn af_ptr_const(ptr_ty : ValType, v : Int) -> TInstr {
  match ptr_ty {
    NumTypeValType(I64NumType) => TInstr::i64_const(I64(v.to_int64()))
    _ => TInstr::i32_const(I32(v))
  }
}

///|
fn af_ptr_add(ptr_ty : ValType, lhs : TInstr, rhs : TInstr) -> TInstr {
  match ptr_ty {
    NumTypeValType(I64NumType) => TInstr::binary(BinaryOp::i64_add(), lhs, rhs)
    _ => TInstr::binary(BinaryOp::i32_add(), lhs, rhs)
  }
}

///|
fn af_ptr_gt_u(ptr_ty : ValType, lhs : TInstr, rhs : TInstr) -> TInstr {
  match ptr_ty {
    NumTypeValType(I64NumType) => TInstr::binary(BinaryOp::i64_gt_u(), lhs, rhs)
    _ => TInstr::binary(BinaryOp::i32_gt_u(), lhs, rhs)
  }
}

///|
fn af_ptr_load_op(ptr_ty : ValType) -> LoadOp {
  match ptr_ty {
    NumTypeValType(I64NumType) => LoadOp::i64_load()
    _ => LoadOp::i32_load()
  }
}

///|
fn af_ptr_store_op(ptr_ty : ValType) -> StoreOp {
  match ptr_ty {
    NumTypeValType(I64NumType) => StoreOp::i64_store()
    _ => StoreOp::i32_store()
  }
}

///|
fn af_ptr_align(ptr_ty : ValType) -> Int {
  match ptr_ty {
    NumTypeValType(I64NumType) => 8
    _ => 4
  }
}

///|
fn af_ptr_size(ptr_ty : ValType) -> Int {
  match ptr_ty {
    NumTypeValType(I64NumType) => 8
    _ => 4
  }
}

///|
priv struct AsyncifyBuilder {
  pointer_type : ValType
  memory : MemIdx
  state_global : GlobalIdx
  data_global : GlobalIdx
}

///|
fn AsyncifyBuilder::new(
  pointer_type : ValType,
  memory : MemIdx,
  state_global : GlobalIdx,
  data_global : GlobalIdx,
) -> AsyncifyBuilder {
  { pointer_type, memory, state_global, data_global }
}

///|
fn AsyncifyBuilder::make_get_stack_pos(self : AsyncifyBuilder) -> TInstr {
  TInstr::load(
    af_ptr_load_op(self.pointer_type),
    MemArg::new(
      U32(af_ptr_align(self.pointer_type).reinterpret_as_uint()),
      Some(self.memory),
      U64(0UL),
    ),
    TInstr::global_get(self.data_global),
  )
}

///|
fn AsyncifyBuilder::make_inc_stack_pos(
  self : AsyncifyBuilder,
  by : Int,
) -> TInstr {
  TInstr::store(
    af_ptr_store_op(self.pointer_type),
    MemArg::new(
      U32(af_ptr_align(self.pointer_type).reinterpret_as_uint()),
      Some(self.memory),
      U64(0UL),
    ),
    TInstr::global_get(self.data_global),
    af_ptr_add(
      self.pointer_type,
      self.make_get_stack_pos(),
      af_ptr_const(self.pointer_type, by),
    ),
  )
}

///|
fn AsyncifyBuilder::make_state_check(
  self : AsyncifyBuilder,
  state : Int,
) -> TInstr {
  TInstr::binary(
    BinaryOp::i32_eq(),
    TInstr::global_get(self.state_global),
    TInstr::i32_const(I32(state)),
  )
}

///|
fn af_add_asyncify_api(
  mod : Module,
  pointer_type : ValType,
  memory : MemIdx,
  export_globals : Bool,
) -> Result[(Module, AFApi), String] {
  let (mod, state_global) = af_append_global(
    mod,
    ValType::i32(),
    true,
    TInstr::i32_const(I32(AF_STATE_NORMAL)),
  )
  let (mod, data_global) = match af_make_zero(pointer_type) {
    Some(zero) => af_append_global(mod, pointer_type, true, zero)
    None => return Err("asyncify: pointer type has no default value")
  }
  let mod = if export_globals {
    af_append_export_global(
      af_append_export_global(mod, AF_GLOBAL_STATE, state_global),
      AF_GLOBAL_DATA,
      data_global,
    )
  } else {
    mod
  }
  let builder = AsyncifyBuilder::new(
    pointer_type, memory, state_global, data_global,
  )
  let ptr_size = af_ptr_size(pointer_type)
  let stack_end_offset = ptr_size
  let start_check = TInstr::if_(
    BlockType::void_(),
    af_ptr_gt_u(
      pointer_type,
      TInstr::load(
        af_ptr_load_op(pointer_type),
        MemArg::new(
          U32(af_ptr_align(pointer_type).reinterpret_as_uint()),
          Some(memory),
          U64(stack_end_offset.reinterpret_as_uint().to_uint64()),
        ),
        TInstr::local_get(LocalIdx::new(0)),
      ),
      TInstr::load(
        af_ptr_load_op(pointer_type),
        MemArg::new(
          U32(af_ptr_align(pointer_type).reinterpret_as_uint()),
          Some(memory),
          U64(0UL),
        ),
        TInstr::local_get(LocalIdx::new(0)),
      ),
    ),
    TExpr::new([TInstr::unreachable_()]),
    None,
  )
  let start_unwind_body = TExpr::new([
    TInstr::global_set(data_global, TInstr::local_get(LocalIdx::new(0))),
    start_check,
    TInstr::global_set(state_global, TInstr::i32_const(I32(AF_STATE_UNWINDING))),
  ])
  let stop_unwind_body = TExpr::new([
    TInstr::global_set(state_global, TInstr::i32_const(I32(AF_STATE_NORMAL))),
  ])
  let start_rewind_body = TExpr::new([
    TInstr::global_set(data_global, TInstr::local_get(LocalIdx::new(0))),
    start_check,
    TInstr::global_set(state_global, TInstr::i32_const(I32(AF_STATE_REWINDING))),
  ])
  let stop_rewind_body = TExpr::new([
    TInstr::global_set(state_global, TInstr::i32_const(I32(AF_STATE_NORMAL))),
  ])
  let get_state_body = TExpr::new([TInstr::global_get(state_global)])
  let (mod, runtime_start_unwind) = af_append_exported_function(
    mod,
    AF_RUNTIME_START_UNWIND,
    [pointer_type],
    [],
    [],
    start_unwind_body,
  )
  let (mod, runtime_stop_unwind) = af_append_exported_function(
    mod,
    AF_RUNTIME_STOP_UNWIND,
    [],
    [],
    [],
    stop_unwind_body,
  )
  let (mod, runtime_start_rewind) = af_append_exported_function(
    mod,
    AF_RUNTIME_START_REWIND,
    [pointer_type],
    [],
    [],
    start_rewind_body,
  )
  let (mod, runtime_stop_rewind) = af_append_exported_function(
    mod,
    AF_RUNTIME_STOP_REWIND,
    [],
    [],
    [],
    stop_rewind_body,
  )
  let (mod, _runtime_get_state) = af_append_exported_function(
    mod,
    AF_RUNTIME_GET_STATE,
    [],
    [ValType::i32()],
    [],
    get_state_body,
  )
  // Internal intrinsic placeholders lowered later.
  let (mod, intr_unwind) = af_append_function(
    mod,
    [ValType::i32()],
    [],
    [],
    TExpr::new([TInstr::nop()]),
  )
  let (mod, intr_get_call_index) = af_append_function(
    mod,
    [],
    [],
    [],
    TExpr::new([builder.make_inc_stack_pos(-4), TInstr::nop()]),
  )
  let (mod, intr_check_call_index) = af_append_function(
    mod,
    [ValType::i32()],
    [ValType::i32()],
    [],
    TExpr::new([TInstr::i32_const(I32(0))]),
  )
  Ok(
    (
      mod,
      {
        state_global,
        data_global,
        runtime_start_unwind,
        runtime_stop_unwind,
        runtime_start_rewind,
        runtime_stop_rewind,
        intr_unwind,
        intr_get_call_index,
        intr_check_call_index,
      },
    ),
  )
}

///|
priv struct FakeGlobalHelper {
  global_by_type : Map[ValType, GlobalIdx]
  type_by_global : Map[GlobalIdx, ValType]
}

///|
fn FakeGlobalHelper::new(
  mod : Module,
  env : Env,
) -> Result[(Module, FakeGlobalHelper), String] {
  let global_by_type : Map[ValType, GlobalIdx] = Map::new()
  let type_by_global : Map[GlobalIdx, ValType] = Map::new()
  let mut next_mod = mod
  fn add_type(
    mod : Module,
    ty : ValType,
    by_type : Map[ValType, GlobalIdx],
    by_global : Map[GlobalIdx, ValType],
  ) -> Result[Module, String] {
    if by_type.contains(ty) {
      return Ok(mod)
    }
    let init = match af_make_zero(ty) {
      Some(v) => v
      None =>
        return Err("asyncify: fake global needs defaultable call result type")
    }
    let (next_mod, idx) = af_append_global(mod, ty, true, init)
    by_type[ty] = idx
    by_global[idx] = ty
    Ok(next_mod)
  }

  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TCall(target, _) | TReturnCall(target, _) =>
        match env.get_functype_by_funcidx(target) {
          Some(FuncType(_, [ret])) =>
            match add_type(next_mod, ret, global_by_type, type_by_global) {
              Ok(m) => next_mod = m
              Err(_) => ()
            }
          _ => ()
        }
      TCallIndirect(type_idx, _, _, _)
      | TReturnCallIndirect(type_idx, _, _, _)
      | TCallRef(type_idx, _, _)
      | TReturnCallRef(type_idx, _, _) =>
        match env.resolve_functype(type_idx) {
          Some(FuncType(_, [ret])) =>
            match add_type(next_mod, ret, global_by_type, type_by_global) {
              Ok(m) => next_mod = m
              Err(_) => ()
            }
          _ => ()
        }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_module((), mod))
  Ok((next_mod, { global_by_type, type_by_global }))
}

///|
fn FakeGlobalHelper::get_name(
  self : FakeGlobalHelper,
  ty : ValType,
) -> GlobalIdx? {
  self.global_by_type.get(ty)
}

///|
fn FakeGlobalHelper::get_type_or_none(
  self : FakeGlobalHelper,
  idx : GlobalIdx,
) -> ValType? {
  self.type_by_global.get(idx)
}

///|
priv struct AFModuleAnalyzer {
  env : Env
  can_indirect_change_state : Bool
  may_change_state : Array[Bool]
  bottom_most_runtime : Array[Bool]
  needs_instrumentation : Array[Bool]
  added_from_list : Array[Bool]
  runtime_start_unwind : FuncIdx
  runtime_stop_unwind : FuncIdx
  runtime_start_rewind : FuncIdx
  runtime_stop_rewind : FuncIdx
  intr_get_call_index : FuncIdx
  intr_check_call_index : FuncIdx
}

///|
fn af_func_idx_to_int(idx : FuncIdx) -> Int {
  let FuncIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn af_collect_function_names(mod : Module) -> Array[String] {
  let imported = af_count_imported_funcs(mod).reinterpret_as_int()
  let defined = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
  let total = imported + defined
  let names : Array[String] = []
  for i = 0; i < total; i = i + 1 {
    names.push("func:\{i}")
  }
  // Imports: module.base
  let mut fi = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(module_name, base_name, FuncExternType(_)) => {
            names[fi] = "\{af_name_to_string(module_name)}.\{af_name_to_string(base_name)}"
            fi += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  // Exports override human-readable names for defined functions.
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          Export(name, FuncExternIdx(idx)) => {
            let i = af_func_idx_to_int(idx)
            if i >= 0 && i < names.length() {
              names[i] = af_name_to_string(name)
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  names
}

///|
fn af_match_any_pattern(value : String, patterns : Array[String]) -> Bool {
  for pattern in patterns {
    if AFPatternMatcher::new(pattern).matches(value) {
      return true
    }
  }
  false
}

///|
fn af_collect_direct_edges(func : Func, out : Set[FuncIdx]) -> Unit {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TCall(target, _) | TReturnCall(target, _) => out.add(target)
      TReturnCallIndirect(_, _, _, _) | TReturnCallRef(_, _, _) => ()
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_func((), func))
}

///|
fn af_func_calls(func : Func, target : FuncIdx) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TCall(callee, _) | TReturnCall(callee, _) if callee == target =>
        found.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_func((), func))
  found.val
}

///|
fn AFModuleAnalyzer::new(
  mod : Module,
  props : AsyncifyPassProps,
  runtime : AFApi,
) -> AFModuleAnalyzer {
  let env = Env::new().with_module(mod)
  let total = env.funcs.length()
  let may_change_state = Array::make(total, false)
  let top_most_runtime = Array::make(total, false)
  let bottom_most_runtime = Array::make(total, false)
  let needs_instrumentation = Array::make(total, false)
  let added_from_list = Array::make(total, false)
  let function_names = af_collect_function_names(mod)
  let imported = af_count_imported_funcs(mod).reinterpret_as_int()
  // Imported function policy.
  let mut imp_idx = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(module_name, base_name, FuncExternType(_)) => {
            let name = "\{af_name_to_string(module_name)}.\{af_name_to_string(base_name)}"
            let mut can_change = !props.ignore_imports
            if !props.imports.is_empty() {
              can_change = af_match_any_pattern(name, props.imports)
            }
            if module_name == Name::new("asyncify") &&
              (
                base_name == Name::new("start_unwind") ||
                base_name == Name::new("stop_rewind")
              ) {
              can_change = true
            }
            may_change_state[imp_idx] = can_change
            imp_idx += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  // Build callgraph and runtime classifications.
  let callers : Array[Set[Int]] = Array::make(total, Set::new())
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for i = 0; i < funcs.length(); i = i + 1 {
        let abs = imported + i
        let fi = FuncIdx::new(abs.reinterpret_as_uint())
        if af_func_calls(funcs[i], runtime.runtime_start_unwind) ||
          af_func_calls(funcs[i], runtime.runtime_stop_rewind) {
          top_most_runtime[abs] = true
          may_change_state[abs] = true
        }
        if af_func_calls(funcs[i], runtime.runtime_stop_unwind) ||
          af_func_calls(funcs[i], runtime.runtime_start_rewind) {
          bottom_most_runtime[abs] = true
        }
        let edges = Set::new()
        af_collect_direct_edges(funcs[i], edges)
        for callee in edges {
          let ci = af_func_idx_to_int(callee)
          if ci >= 0 && ci < total {
            callers[ci].add(abs)
          }
        }
        ignore(fi)
      }
    None => ()
  }
  let work : Array[Int] = []
  for i = 0; i < total; i = i + 1 {
    if may_change_state[i] && !bottom_most_runtime[i] {
      work.push(i)
    }
  }
  while !work.is_empty() {
    let callee = work.pop().unwrap()
    for caller in callers[callee] {
      if !may_change_state[caller] && !bottom_most_runtime[callee] {
        may_change_state[caller] = true
        work.push(caller)
      }
    }
  }
  for i = 0; i < total; i = i + 1 {
    needs_instrumentation[i] = may_change_state[i] &&
      !top_most_runtime[i] &&
      !bottom_most_runtime[i]
  }
  if !props.onlylist.is_empty() {
    for i = 0; i < total; i = i + 1 {
      let matched = af_match_any_pattern(function_names[i], props.onlylist)
      needs_instrumentation[i] = matched
      added_from_list[i] = matched
    }
  } else {
    for i = 0; i < total; i = i + 1 {
      if af_match_any_pattern(function_names[i], props.removelist) {
        needs_instrumentation[i] = false
      }
      if af_match_any_pattern(function_names[i], props.addlist) {
        needs_instrumentation[i] = true
        added_from_list[i] = true
      }
    }
  }
  if props.propagate_addlist && !props.addlist.is_empty() {
    let queue : Array[Int] = []
    for i = 0; i < total; i = i + 1 {
      if added_from_list[i] {
        queue.push(i)
      }
    }
    while !queue.is_empty() {
      let callee = queue.pop().unwrap()
      for caller in callers[callee] {
        if !needs_instrumentation[caller] {
          needs_instrumentation[caller] = true
          queue.push(caller)
        }
      }
    }
  }
  if props.verbose {
    let logs : Array[String] = []
    for i = 0; i < total; i = i + 1 {
      if needs_instrumentation[i] {
        logs.push("asyncify instrument: \{function_names[i]}")
      }
    }
    logs.sort()
    for line in logs {
      println(line)
    }
  }
  {
    env,
    can_indirect_change_state: !props.ignore_indirect,
    may_change_state,
    bottom_most_runtime,
    needs_instrumentation,
    added_from_list,
    runtime_start_unwind: runtime.runtime_start_unwind,
    runtime_stop_unwind: runtime.runtime_stop_unwind,
    runtime_start_rewind: runtime.runtime_start_rewind,
    runtime_stop_rewind: runtime.runtime_stop_rewind,
    intr_get_call_index: runtime.intr_get_call_index,
    intr_check_call_index: runtime.intr_check_call_index,
  }
}

///|
fn AFModuleAnalyzer::needs_instrumentation_for(
  self : AFModuleAnalyzer,
  idx : FuncIdx,
) -> Bool {
  let i = af_func_idx_to_int(idx)
  if i < 0 || i >= self.needs_instrumentation.length() {
    false
  } else {
    self.needs_instrumentation[i]
  }
}

///|
fn AFModuleAnalyzer::can_change_state(
  self : AFModuleAnalyzer,
  instr : TInstr,
  curr_func : FuncIdx,
) -> Bool {
  match instr {
    TCall(target, _) | TReturnCall(target, _) => {
      if target == self.runtime_stop_unwind ||
        target == self.runtime_start_rewind {
        return false
      }
      if target == self.runtime_start_unwind ||
        target == self.runtime_stop_rewind ||
        target == self.intr_get_call_index ||
        target == self.intr_check_call_index {
        return true
      }
      let i = af_func_idx_to_int(target)
      if i < 0 || i >= self.may_change_state.length() {
        return false
      }
      if self.bottom_most_runtime[i] {
        return false
      }
      self.may_change_state[i]
    }
    TCallIndirect(_, _, _, _)
    | TCallRef(_, _, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _) =>
      if self.can_indirect_change_state {
        true
      } else {
        let ci = af_func_idx_to_int(curr_func)
        ci >= 0 &&
        ci < self.added_from_list.length() &&
        self.added_from_list[ci]
      }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) => {
      for item in body.0 {
        if self.can_change_state(item, curr_func) {
          return true
        }
      }
      false
    }
    TIf(_, cond, then_, else_) => {
      if self.can_change_state(cond, curr_func) {
        return true
      }
      for item in then_.0 {
        if self.can_change_state(item, curr_func) {
          return true
        }
      }
      match else_ {
        Some(other) =>
          for item in other.0 {
            if self.can_change_state(item, curr_func) {
              return true
            }
          }
        None => ()
      }
      false
    }
    _ => {
      for child in af_eval_children(instr) {
        if self.can_change_state(child, curr_func) {
          return true
        }
      }
      false
    }
  }
}

///|
fn af_or(lhs : TInstr, rhs : TInstr) -> TInstr {
  TInstr::binary(BinaryOp::i32_or(), lhs, rhs)
}

///|
fn af_eqz(v : TInstr) -> TInstr {
  TInstr::unary(UnaryOp::i32_eqz(), v)
}

///|
fn af_rewrite_if_for_rewinding(
  b : AsyncifyBuilder,
  then_ : TExpr,
  else_ : TExpr?,
  cond : TInstr,
) -> TInstr {
  let rewinding = b.make_state_check(AF_STATE_REWINDING)
  match else_ {
    Some(other) =>
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::if_(BlockType::void_(), af_or(rewinding, cond), then_, None),
          TInstr::if_(
            BlockType::void_(),
            af_or(b.make_state_check(AF_STATE_REWINDING), af_eqz(cond)),
            other,
            None,
          ),
        ]),
      )
    None => TInstr::if_(BlockType::void_(), af_or(rewinding, cond), then_, None)
  }
}

///|
priv struct AFRewriterCtx {
  analyzer : AFModuleAnalyzer
  builder : AsyncifyBuilder
  fake_globals : FakeGlobalHelper
  intr_unwind : FuncIdx
  intr_check_call_index : FuncIdx
  curr_func : FuncIdx
  mut next_call_index : Int
}

///|
fn af_is_call_like_none(instr : TInstr) -> Bool {
  match instr {
    TCall(_, _) | TCallIndirect(_, _, _, _) | TCallRef(_, _, _) => true
    TDrop(TCall(_, _))
    | TDrop(TCallIndirect(_, _, _, _))
    | TDrop(TCallRef(_, _, _)) => true
    TLocalSet(_, TCall(_, _))
    | TLocalSet(_, TCallIndirect(_, _, _, _))
    | TLocalSet(_, TCallRef(_, _, _)) => true
    _ => false
  }
}

///|
fn af_wrap_skippable(b : AsyncifyBuilder, instr : TInstr) -> TInstr {
  TInstr::if_(
    BlockType::void_(),
    b.make_state_check(AF_STATE_NORMAL),
    TExpr::new([instr]),
    None,
  )
}

///|
fn af_rewrite_call_like(
  ctx : AFRewriterCtx,
  instr : TInstr,
) -> Result[TInstr, String] {
  let call_index = ctx.next_call_index
  ctx.next_call_index += 1
  let wrapped_call = match instr {
    TReturnCall(_, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _) =>
      return Err("asyncify: tail calls are not supported")
    TLocalSet(idx, value) =>
      match value {
        TCall(target, args) =>
          match ctx.analyzer.env.get_functype_by_funcidx(target) {
            Some(FuncType(_, [ret])) =>
              match ctx.fake_globals.get_name(ret) {
                Some(fake_global) =>
                  TInstr::block(
                    BlockType::void_(),
                    TExpr::new([
                      TInstr::global_set(
                        fake_global,
                        TInstr::call(target, args),
                      ),
                      TInstr::local_set(idx, TInstr::global_get(fake_global)),
                    ]),
                  )
                None => instr
              }
            _ => instr
          }
        TCallIndirect(type_idx, table_idx, args, index) =>
          match ctx.analyzer.env.resolve_functype(type_idx) {
            Some(FuncType(_, [ret])) =>
              match ctx.fake_globals.get_name(ret) {
                Some(fake_global) =>
                  TInstr::block(
                    BlockType::void_(),
                    TExpr::new([
                      TInstr::global_set(
                        fake_global,
                        TInstr::call_indirect(type_idx, table_idx, args, index),
                      ),
                      TInstr::local_set(idx, TInstr::global_get(fake_global)),
                    ]),
                  )
                None => instr
              }
            _ => instr
          }
        TCallRef(type_idx, args, ref_) =>
          match ctx.analyzer.env.resolve_functype(type_idx) {
            Some(FuncType(_, [ret])) =>
              match ctx.fake_globals.get_name(ret) {
                Some(fake_global) =>
                  TInstr::block(
                    BlockType::void_(),
                    TExpr::new([
                      TInstr::global_set(
                        fake_global,
                        TInstr::call_ref(type_idx, args, ref_),
                      ),
                      TInstr::local_set(idx, TInstr::global_get(fake_global)),
                    ]),
                  )
                None => instr
              }
            _ => instr
          }
        _ => instr
      }
    _ => instr
  }
  let cond = af_or(
    ctx.builder.make_state_check(AF_STATE_NORMAL),
    TInstr::call(ctx.intr_check_call_index, [TInstr::i32_const(I32(call_index))]),
  )
  Ok(
    TInstr::if_(
      BlockType::void_(),
      cond,
      TExpr::new([
        wrapped_call,
        TInstr::if_(
          BlockType::void_(),
          ctx.builder.make_state_check(AF_STATE_UNWINDING),
          TExpr::new([
            TInstr::call(ctx.intr_unwind, [TInstr::i32_const(I32(call_index))]),
          ]),
          None,
        ),
      ]),
      None,
    ),
  )
}

///|
fn af_rewrite_instr(
  ctx : AFRewriterCtx,
  instr : TInstr,
) -> Result[TInstr, String] {
  match instr {
    TBlock(bt, body) => {
      let out : Array[TInstr] = []
      for item in body.0 {
        let rewritten = match af_rewrite_instr(ctx, item) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        if ctx.analyzer.can_change_state(rewritten, ctx.curr_func) {
          out.push(rewritten)
        } else {
          out.push(af_wrap_skippable(ctx.builder, rewritten))
        }
      }
      Ok(TInstr::block(bt, TExpr::new(out)))
    }
    TLoop(bt, body) => {
      let out : Array[TInstr] = []
      for item in body.0 {
        let rewritten = match af_rewrite_instr(ctx, item) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        if ctx.analyzer.can_change_state(rewritten, ctx.curr_func) {
          out.push(rewritten)
        } else {
          out.push(af_wrap_skippable(ctx.builder, rewritten))
        }
      }
      Ok(TInstr::loop_(bt, TExpr::new(out)))
    }
    TTryTable(bt, catches, body) => {
      let out : Array[TInstr] = []
      for item in body.0 {
        let rewritten = match af_rewrite_instr(ctx, item) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        out.push(rewritten)
      }
      Ok(TInstr::try_table(bt, catches, TExpr::new(out)))
    }
    TIf(bt, cond, then_, else_) => {
      let next_cond = match af_rewrite_instr(ctx, cond) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let next_then_instrs : Array[TInstr] = []
      for item in then_.0 {
        next_then_instrs.push(
          match af_rewrite_instr(ctx, item) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
        )
      }
      let next_else = match else_ {
        Some(other) => {
          let xs : Array[TInstr] = []
          for item in other.0 {
            xs.push(
              match af_rewrite_instr(ctx, item) {
                Ok(v) => v
                Err(e) => return Err(e)
              },
            )
          }
          Some(TExpr::new(xs))
        }
        None => None
      }
      let _ = bt
      Ok(
        af_rewrite_if_for_rewinding(
          ctx.builder,
          TExpr::new(next_then_instrs),
          next_else,
          next_cond,
        ),
      )
    }
    _ =>
      if af_is_call_like_none(instr) {
        af_rewrite_call_like(ctx, instr)
      } else {
        // Generic recursive rebuild for non-control instructions.
        let kids = af_eval_children(instr)
        if kids.is_empty() {
          Ok(instr)
        } else {
          let rebuilt_kids : Array[TInstr] = []
          for child in kids {
            rebuilt_kids.push(
              match af_rewrite_instr(ctx, child) {
                Ok(v) => v
                Err(e) => return Err(e)
              },
            )
          }
          match instr {
            TUnary(op, _) => Ok(TInstr::unary(op, rebuilt_kids[0]))
            TDrop(_) => Ok(TInstr::drop(rebuilt_kids[0]))
            TLocalSet(idx, _) => Ok(TInstr::local_set(idx, rebuilt_kids[0]))
            TLocalTee(idx, _) => Ok(TInstr::local_tee(idx, rebuilt_kids[0]))
            TGlobalSet(idx, _) => Ok(TInstr::global_set(idx, rebuilt_kids[0]))
            TRefIsNull(_) => Ok(TInstr::ref_is_null(rebuilt_kids[0]))
            TRefAsNonNull(_) => Ok(TInstr::ref_as_non_null(rebuilt_kids[0]))
            TI31GetS(_) => Ok(TInstr::i31_get_s(rebuilt_kids[0]))
            TI31GetU(_) => Ok(TInstr::i31_get_u(rebuilt_kids[0]))
            TRefI31(_) => Ok(TInstr::ref_i31(rebuilt_kids[0]))
            TArrayLen(_) => Ok(TInstr::array_len(rebuilt_kids[0]))
            TAnyConvertExtern(_) =>
              Ok(TInstr::any_convert_extern(rebuilt_kids[0]))
            TExternConvertAny(_) =>
              Ok(TInstr::extern_convert_any(rebuilt_kids[0]))
            TThrowRef(_) => Ok(TInstr::throw_ref(rebuilt_kids[0]))
            TMemoryGrow(mi, _) => Ok(TInstr::memory_grow(mi, rebuilt_kids[0]))
            TTableGet(ti, _) => Ok(TInstr::table_get(ti, rebuilt_kids[0]))
            TLoad(op, ma, _) => Ok(TInstr::load(op, ma, rebuilt_kids[0]))
            TBinary(op, _, _) =>
              Ok(TInstr::binary(op, rebuilt_kids[0], rebuilt_kids[1]))
            TRefEq(_, _) => Ok(TInstr::ref_eq(rebuilt_kids[0], rebuilt_kids[1]))
            TStore(op, ma, _, _) =>
              Ok(TInstr::store(op, ma, rebuilt_kids[0], rebuilt_kids[1]))
            TTableSet(ti, _, _) =>
              Ok(TInstr::table_set(ti, rebuilt_kids[0], rebuilt_kids[1]))
            TTableGrow(ti, _, _) =>
              Ok(TInstr::table_grow(ti, rebuilt_kids[0], rebuilt_kids[1]))
            TStructSet(ti, fi, _, _) =>
              Ok(TInstr::struct_set(ti, fi, rebuilt_kids[0], rebuilt_kids[1]))
            TArrayNew(ti, _, _) =>
              Ok(TInstr::array_new(ti, rebuilt_kids[0], rebuilt_kids[1]))
            TArrayNewData(ti, di, _, _) =>
              Ok(
                TInstr::array_new_data(ti, di, rebuilt_kids[0], rebuilt_kids[1]),
              )
            TArrayNewElem(ti, ei, _, _) =>
              Ok(
                TInstr::array_new_elem(ti, ei, rebuilt_kids[0], rebuilt_kids[1]),
              )
            TArrayGet(ti, _, _) =>
              Ok(TInstr::array_get(ti, rebuilt_kids[0], rebuilt_kids[1]))
            TArrayGetS(ti, _, _) =>
              Ok(TInstr::array_get_s(ti, rebuilt_kids[0], rebuilt_kids[1]))
            TArrayGetU(ti, _, _) =>
              Ok(TInstr::array_get_u(ti, rebuilt_kids[0], rebuilt_kids[1]))
            TReplaceLane(op, li, _, _) =>
              Ok(TInstr::replace_lane(op, li, rebuilt_kids[0], rebuilt_kids[1]))
            TI8x16Swizzle(_, _) =>
              Ok(TInstr::i8x16_swizzle(rebuilt_kids[0], rebuilt_kids[1]))
            TI8x16RelaxedSwizzle(_, _) =>
              Ok(
                TInstr::i8x16_relaxed_swizzle(rebuilt_kids[0], rebuilt_kids[1]),
              )
            TV128Shift(op, _, _) =>
              Ok(TInstr::v128_shift(op, rebuilt_kids[0], rebuilt_kids[1]))
            TV128LoadLane(op, ma, li, _, _) =>
              Ok(
                TInstr::v128_load_lane(
                  op,
                  ma,
                  li,
                  rebuilt_kids[0],
                  rebuilt_kids[1],
                ),
              )
            TV128StoreLane(op, ma, li, _, _) =>
              Ok(
                TInstr::v128_store_lane(
                  op,
                  ma,
                  li,
                  rebuilt_kids[0],
                  rebuilt_kids[1],
                ),
              )
            TMemoryFill(mi, _, _, _) =>
              Ok(
                TInstr::memory_fill(
                  mi,
                  rebuilt_kids[0],
                  rebuilt_kids[1],
                  rebuilt_kids[2],
                ),
              )
            TMemoryCopy(dst, src, _, _, _) =>
              Ok(
                TInstr::memory_copy(
                  dst,
                  src,
                  rebuilt_kids[0],
                  rebuilt_kids[1],
                  rebuilt_kids[2],
                ),
              )
            TMemoryInit(di, mi, _, _, _) =>
              Ok(
                TInstr::memory_init(
                  di,
                  mi,
                  rebuilt_kids[0],
                  rebuilt_kids[1],
                  rebuilt_kids[2],
                ),
              )
            TTableFill(ti, _, _, _) =>
              Ok(
                TInstr::table_fill(
                  ti,
                  rebuilt_kids[0],
                  rebuilt_kids[1],
                  rebuilt_kids[2],
                ),
              )
            TTableCopy(t0, t1, _, _, _) =>
              Ok(
                TInstr::table_copy(
                  t0,
                  t1,
                  rebuilt_kids[0],
                  rebuilt_kids[1],
                  rebuilt_kids[2],
                ),
              )
            TTableInit(ei, ti, _, _, _) =>
              Ok(
                TInstr::table_init(
                  ei,
                  ti,
                  rebuilt_kids[0],
                  rebuilt_kids[1],
                  rebuilt_kids[2],
                ),
              )
            TSelect(tys, _, _, _) =>
              Ok(
                TInstr::select(
                  tys,
                  rebuilt_kids[0],
                  rebuilt_kids[1],
                  rebuilt_kids[2],
                ),
              )
            TV128Ternary(op, _, _, _) =>
              Ok(
                TInstr::v128_ternary(
                  op,
                  rebuilt_kids[0],
                  rebuilt_kids[1],
                  rebuilt_kids[2],
                ),
              )
            _ => Ok(instr)
          }
        }
      }
  }
}

///|
fn af_instrument_flow_for_function(
  func : Func,
  func_idx : FuncIdx,
  analyzer : AFModuleAnalyzer,
  builder : AsyncifyBuilder,
  fake_globals : FakeGlobalHelper,
  runtime : AFApi,
) -> Result[Func, String] {
  match func {
    TFunc(locals, body) => {
      let ctx : AFRewriterCtx = {
        analyzer,
        builder,
        fake_globals,
        intr_unwind: runtime.intr_unwind,
        intr_check_call_index: runtime.intr_check_call_index,
        curr_func: func_idx,
        next_call_index: 0,
      }
      let rewritten_items : Array[TInstr] = []
      for instr in body.0 {
        rewritten_items.push(
          match af_rewrite_instr(ctx, instr) {
            Ok(v) => v
            Err(e) => return Err(e)
          },
        )
      }
      let prefix = TInstr::if_(
        BlockType::void_(),
        builder.make_state_check(AF_STATE_REWINDING),
        TExpr::new([TInstr::call(runtime.intr_get_call_index, [])]),
        None,
      )
      let wrapped : Array[TInstr] = [prefix]
      for instr in rewritten_items {
        wrapped.push(instr)
      }
      if !wrapped.is_empty() {
        let last = wrapped[wrapped.length() - 1]
        match last {
          TUnreachable => ()
          _ => ()
        }
      }
      Ok(
        Func::t_func(
          locals,
          TExpr::new([TInstr::block(BlockType::void_(), TExpr::new(wrapped))]),
        ),
      )
    }
    _ => Ok(func)
  }
}

///|
fn af_local_byte_size(vt : ValType) -> Int? {
  match vt {
    NumTypeValType(I32NumType) | NumTypeValType(F32NumType) => Some(4)
    NumTypeValType(I64NumType) | NumTypeValType(F64NumType) => Some(8)
    VecTypeValType => Some(16)
    RefTypeValType(_) => None
    BotValType => Some(4)
  }
}

///|
fn af_align_up(v : Int, align : Int) -> Int {
  if align <= 1 {
    return v
  }
  let r = v % align
  if r == 0 {
    v
  } else {
    v + (align - r)
  }
}

///|
fn af_collect_live_like_locals(body : TExpr) -> Set[LocalIdx] {
  // Conservative approximation: locals used in instrumented call wrappers.
  let out = Set::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TCall(_, args) =>
        for arg in args {
          let uses_ = uses(arg)
          for idx in uses_ {
            out.add(idx)
          }
        }
      TCallIndirect(_, _, args, idx_expr) => {
        for arg in args {
          let uses_ = uses(arg)
          for idx in uses_ {
            out.add(idx)
          }
        }
        let uses_idx = uses(idx_expr)
        for idx in uses_idx {
          out.add(idx)
        }
      }
      TCallRef(_, args, ref_) => {
        for arg in args {
          let uses_ = uses(arg)
          for idx in uses_ {
            out.add(idx)
          }
        }
        let uses_ref = uses(ref_)
        for idx in uses_ref {
          out.add(idx)
        }
      }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  out
}

///|
fn af_lower_intrinsics_and_locals(
  func : Func,
  builder : AsyncifyBuilder,
  runtime : AFApi,
  fake_globals : FakeGlobalHelper,
) -> Result[Func, String] {
  match func {
    TFunc(locals, body) => {
      let relevant = af_collect_live_like_locals(body)
      let stack_ptr_local = LocalIdx::new(locals.length().reinterpret_as_uint())
      let unwind_idx_local = LocalIdx::new(
        (locals.length() + 1).reinterpret_as_uint(),
      )
      let call_tmp_i32 = LocalIdx::new(
        (locals.length() + 2).reinterpret_as_uint(),
      )
      let extended_locals = locals.copy()
      extended_locals.push(builder.pointer_type)
      extended_locals.push(ValType::i32())
      extended_locals.push(ValType::i32())
      let load_seq : Array[TInstr] = []
      load_seq.push(
        TInstr::local_set(stack_ptr_local, builder.make_get_stack_pos()),
      )
      let mut cursor = 0
      for idx in relevant {
        let LocalIdx(raw) = idx
        let i = raw.reinterpret_as_int()
        if i < 0 || i >= locals.length() {
          continue
        }
        let ty = locals[i]
        let sz = match af_local_byte_size(ty) {
          Some(s) => s
          None =>
            return Err(
              "asyncify: local save/restore does not support ref locals",
            )
        }
        let aligned = af_align_up(cursor, AF_STACK_ALIGN.reinterpret_as_int())
        load_seq.push(
          TInstr::local_set(
            idx,
            TInstr::load(
              match ty {
                NumTypeValType(I32NumType) => LoadOp::i32_load()
                NumTypeValType(I64NumType) => LoadOp::i64_load()
                NumTypeValType(F32NumType) => LoadOp::f32_load()
                NumTypeValType(F64NumType) => LoadOp::f64_load()
                VecTypeValType => LoadOp::v128_load()
                BotValType => LoadOp::i32_load()
                RefTypeValType(_) => LoadOp::i32_load()
              },
              MemArg::new(
                U32(af_align_up(sz, 1).reinterpret_as_uint()),
                Some(builder.memory),
                U64(aligned.reinterpret_as_uint().to_uint64()),
              ),
              TInstr::local_get(stack_ptr_local),
            ),
          ),
        )
        cursor = aligned + sz
      }
      if cursor > 0 {
        load_seq.push(builder.make_inc_stack_pos(-cursor))
      }
      let save_seq : Array[TInstr] = []
      save_seq.push(
        TInstr::local_set(stack_ptr_local, builder.make_get_stack_pos()),
      )
      cursor = 0
      for idx in relevant {
        let LocalIdx(raw) = idx
        let i = raw.reinterpret_as_int()
        if i < 0 || i >= locals.length() {
          continue
        }
        let ty = locals[i]
        let sz = match af_local_byte_size(ty) {
          Some(s) => s
          None =>
            return Err(
              "asyncify: local save/restore does not support ref locals",
            )
        }
        let aligned = af_align_up(cursor, AF_STACK_ALIGN.reinterpret_as_int())
        save_seq.push(
          TInstr::store(
            match ty {
              NumTypeValType(I32NumType) => StoreOp::i32_store()
              NumTypeValType(I64NumType) => StoreOp::i64_store()
              NumTypeValType(F32NumType) => StoreOp::f32_store()
              NumTypeValType(F64NumType) => StoreOp::f64_store()
              VecTypeValType => StoreOp::v128_store()
              BotValType => StoreOp::i32_store()
              RefTypeValType(_) => StoreOp::i32_store()
            },
            MemArg::new(
              U32(af_align_up(sz, 1).reinterpret_as_uint()),
              Some(builder.memory),
              U64(aligned.reinterpret_as_uint().to_uint64()),
            ),
            TInstr::local_get(stack_ptr_local),
            TInstr::local_get(idx),
          ),
        )
        cursor = aligned + sz
      }
      if cursor > 0 {
        save_seq.push(builder.make_inc_stack_pos(cursor))
      }
      let lowered = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr,
      ) {
        match instr {
          TCall(target, [TI32Const(I32(ix))]) if target == runtime.intr_unwind =>
            change(
              (),
              TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(ix))]),
            )
          TCall(target, []) if target == runtime.intr_get_call_index =>
            change(
              (),
              TInstr::block(
                BlockType::void_(),
                TExpr::new([
                  builder.make_inc_stack_pos(-4),
                  TInstr::local_set(
                    unwind_idx_local,
                    TInstr::load(
                      LoadOp::i32_load(),
                      MemArg::new(U32(4), Some(builder.memory), U64(0UL)),
                      builder.make_get_stack_pos(),
                    ),
                  ),
                ]),
              ),
            )
          TCall(target, [arg]) if target == runtime.intr_check_call_index =>
            change(
              (),
              TInstr::binary(
                BinaryOp::i32_eq(),
                TInstr::local_get(unwind_idx_local),
                arg,
              ),
            )
          TGlobalSet(gidx, value) =>
            match fake_globals.get_type_or_none(gidx) {
              Some(vt) =>
                if vt == ValType::i32() {
                  change((), TInstr::local_set(call_tmp_i32, value))
                } else {
                  self.walk_tinstruction_default((), instr)
                }
              None => self.walk_tinstruction_default((), instr)
            }
          TGlobalGet(gidx) =>
            match fake_globals.get_type_or_none(gidx) {
              Some(vt) =>
                if vt == ValType::i32() {
                  change((), TInstr::local_get(call_tmp_i32))
                } else {
                  unchanged()
                }
              None => unchanged()
            }
          _ => self.walk_tinstruction_default((), instr)
        }
      })
      let lowered_body = match lowered.walk_texpr((), body) {
        Ok(Some((_, next))) => next
        Ok(None) => body
        Err(e) => return Err(e)
      }
      let final_instrs : Array[TInstr] = []
      final_instrs.push(
        TInstr::if_(
          BlockType::void_(),
          builder.make_state_check(AF_STATE_REWINDING),
          TExpr::new(load_seq),
          None,
        ),
      )
      final_instrs.push(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::block(BlockType::void_(), lowered_body),
            TInstr::i32_const(I32(0)),
          ]),
        ),
      )
      final_instrs.push(
        TInstr::if_(
          BlockType::void_(),
          builder.make_state_check(AF_STATE_UNWINDING),
          TExpr::new([
            TInstr::store(
              StoreOp::i32_store(),
              MemArg::new(U32(4), Some(builder.memory), U64(0UL)),
              builder.make_get_stack_pos(),
              TInstr::i32_const(I32(0)),
            ),
            TInstr::block(BlockType::void_(), TExpr::new(save_seq)),
          ]),
          None,
        ),
      )
      Ok(Func::t_func(extended_locals, TExpr::new(final_instrs)))
    }
    _ => Ok(func)
  }
}

///|
fn af_assert_non_instrumented(
  mod : Module,
  analyzer : AFModuleAnalyzer,
  runtime : AFApi,
) -> Module {
  let imported = af_count_imported_funcs(mod).reinterpret_as_int()
  let funcs = match mod.code_sec {
    Some(CodeSec(xs)) => xs.copy()
    None => return mod
  }
  let rewritten : Array[Func] = []
  for i = 0; i < funcs.length(); i = i + 1 {
    let abs = FuncIdx::new((imported + i).reinterpret_as_uint())
    if analyzer.needs_instrumentation_for(abs) {
      rewritten.push(funcs[i])
      continue
    }
    match funcs[i] {
      TFunc(locals, body) => {
        let state_local = LocalIdx::new(locals.length().reinterpret_as_uint())
        let next_locals = locals.copy()
        next_locals.push(ValType::i32())
        let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr,
        ) {
          match instr {
            TCall(_, _) | TCallIndirect(_, _, _, _) | TCallRef(_, _, _) =>
              change(
                (),
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    instr,
                    TInstr::if_(
                      BlockType::void_(),
                      TInstr::binary(
                        BinaryOp::i32_ne(),
                        TInstr::global_get(runtime.state_global),
                        TInstr::local_get(state_local),
                      ),
                      TExpr::new([TInstr::unreachable_()]),
                      None,
                    ),
                  ]),
                ),
              )
            _ => self.walk_tinstruction_default((), instr)
          }
        })
        let next_body = match walker.walk_texpr((), body) {
          Ok(Some((_, t))) => t
          _ => body
        }
        rewritten.push(
          Func::t_func(
            next_locals,
            TExpr::new([
              TInstr::local_set(
                state_local,
                TInstr::global_get(runtime.state_global),
              ),
              TInstr::block(BlockType::void_(), next_body),
            ]),
          ),
        )
      }
      _ => rewritten.push(funcs[i])
    }
  }
  mod.with_code_sec(CodeSec::new(rewritten))
}

///|
priv struct AFCatchAssertCtx {
  env : Env
  state_global : GlobalIdx
  mut try_depth : Int
  base_local_count : Int
  temp_by_type : Map[ValType, LocalIdx]
  extra_locals : Array[ValType]
}

///|
fn af_catch_alloc_temp_local(ctx : AFCatchAssertCtx, vt : ValType) -> LocalIdx {
  match ctx.temp_by_type.get(vt) {
    Some(idx) => idx
    None => {
      let idx = LocalIdx::new(
        (ctx.base_local_count + ctx.extra_locals.length()).reinterpret_as_uint(),
      )
      ctx.extra_locals.push(vt)
      ctx.temp_by_type[vt] = idx
      idx
    }
  }
}

///|
fn af_catch_call_result_type(instr : TInstr, env : Env) -> ValType? {
  match instr {
    TCall(target, _) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(_, [ret])) => Some(ret)
        _ => None
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(_, [ret])) => Some(ret)
        _ => None
      }
    _ => None
  }
}

///|
fn af_catch_make_guard(state_global : GlobalIdx) -> TInstr {
  TInstr::if_(
    BlockType::void_(),
    TInstr::binary(
      BinaryOp::i32_ne(),
      TInstr::global_get(state_global),
      TInstr::i32_const(I32(AF_STATE_NORMAL)),
    ),
    TExpr::new([TInstr::unreachable_()]),
    None,
  )
}

///|
fn af_catch_wrap_guarded_call(ctx : AFCatchAssertCtx, call : TInstr) -> TInstr {
  match af_catch_call_result_type(call, ctx.env) {
    Some(vt) => {
      let temp = af_catch_alloc_temp_local(ctx, vt)
      TInstr::block(
        BlockType::val_type(vt),
        TExpr::new([
          TInstr::local_set(temp, call),
          af_catch_make_guard(ctx.state_global),
          TInstr::local_get(temp),
        ]),
      )
    }
    None =>
      TInstr::block(
        BlockType::void_(),
        TExpr::new([call, af_catch_make_guard(ctx.state_global)]),
      )
  }
}

///|
fn af_assert_unwind_catch(mod : Module, runtime : AFApi) -> Module {
  let imported = af_count_imported_funcs(mod).reinterpret_as_int()
  let funcs = match mod.code_sec {
    Some(CodeSec(xs)) => xs.copy()
    None => return mod
  }
  let rewritten : Array[Func] = []
  for i = 0; i < funcs.length(); i = i + 1 {
    let abs_idx = FuncIdx::new((imported + i).reinterpret_as_uint())
    match funcs[i] {
      TFunc(locals, body) => {
        let func_locals = locals.copy()
        let mut full_env = Env::new().with_module(mod)
        let params = match full_env.get_functype_by_funcidx(abs_idx) {
          Some(FuncType(ps, _)) => ps
          None => []
        }
        let all_locals = params.copy()
        for vt in func_locals {
          all_locals.push(vt)
        }
        full_env = full_env.with_locals(all_locals)
        let ctx : AFCatchAssertCtx = {
          env: full_env,
          state_global: runtime.state_global,
          try_depth: 0,
          base_local_count: func_locals.length(),
          temp_by_type: Map::new(),
          extra_locals: [],
        }
        let rewriter = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          ctx : AFCatchAssertCtx,
          instr,
        ) {
          match instr {
            TTryTable(bt, catches, try_body) => {
              ctx.try_depth += 1
              let walked = match self.walk_texpr(ctx, try_body) {
                Ok(Some((_, out))) => out
                Ok(None) => try_body
                Err(e) => {
                  ctx.try_depth -= 1
                  return Err(e)
                }
              }
              ctx.try_depth -= 1
              let next = TInstr::try_table(bt, catches, walked)
              if next != instr {
                change(ctx, next)
              } else {
                unchanged()
              }
            }
            TReturnCall(_, _)
            | TReturnCallIndirect(_, _, _, _)
            | TReturnCallRef(_, _, _) => unchanged()
            TCall(_, _) | TCallIndirect(_, _, _, _) | TCallRef(_, _, _) =>
              if ctx.try_depth > 0 {
                let walked = match self.walk_tinstruction_default(ctx, instr) {
                  Ok(Some((_, out))) => out
                  Ok(None) => instr
                  Err(e) => return Err(e)
                }
                change(ctx, af_catch_wrap_guarded_call(ctx, walked))
              } else {
                self.walk_tinstruction_default(ctx, instr)
              }
            _ => self.walk_tinstruction_default(ctx, instr)
          }
        })
        let next_body = match rewriter.walk_texpr(ctx, body) {
          Ok(Some((_, out))) => out
          Ok(None) => body
          Err(_) => body
        }
        let next_locals = func_locals.copy()
        for vt in ctx.extra_locals {
          next_locals.push(vt)
        }
        rewritten.push(Func::t_func(next_locals, next_body))
      }
      _ => rewritten.push(funcs[i])
    }
  }
  mod.with_code_sec(CodeSec::new(rewritten))
}

///|
fn asyncify(
  mod : Module,
  props? : AsyncifyPassProps = AsyncifyPassProps::new(),
  optimize_level? : Int = 0,
) -> Result[Module, String] {
  if props.import_globals {
    return Err("asyncify: asyncify-import-globals is not supported in this IR")
  }
  let (mod, memory) = match af_memory_choice(mod, props) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (mod, runtime) = match
    af_add_asyncify_api(
      mod,
      memory.pointer_type,
      memory.mem_idx,
      props.export_globals,
    ) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let analyzer = AFModuleAnalyzer::new(mod, props, runtime)
  let env = Env::new().with_module(mod)
  let (mod, fake_globals) = match FakeGlobalHelper::new(mod, env) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let imported = af_count_imported_funcs(mod).reinterpret_as_int()
  let funcs = match mod.code_sec {
    Some(CodeSec(xs)) => xs.copy()
    None => []
  }
  let builder = AsyncifyBuilder::new(
    memory.pointer_type,
    memory.mem_idx,
    runtime.state_global,
    runtime.data_global,
  )
  let rewritten_funcs : Array[Func] = []
  for i = 0; i < funcs.length(); i = i + 1 {
    let abs = FuncIdx::new((imported + i).reinterpret_as_uint())
    let mut func = funcs[i]
    if analyzer.needs_instrumentation_for(abs) {
      func = match
        af_instrument_flow_for_function(
          func, abs, analyzer, builder, fake_globals, runtime,
        ) {
        Ok(f) => f
        Err(e) => return Err(e)
      }
      func = match
        af_lower_intrinsics_and_locals(func, builder, runtime, fake_globals) {
        Ok(f) => f
        Err(e) => return Err(e)
      }
    }
    rewritten_funcs.push(func)
  }
  let mut out = mod.with_code_sec(CodeSec::new(rewritten_funcs))
  if props.asserts {
    out = af_assert_non_instrumented(out, analyzer, runtime)
    if !props.ignore_unwind_from_catch {
      out = af_assert_unwind_catch(out, runtime)
    }
  }
  ignore(optimize_level)
  Ok(out)
}

///|
fn af_test_run(
  mod : Module,
  props? : AsyncifyPassProps = AsyncifyPassProps::new(),
) -> Result[Module, String] {
  asyncify(mod, props~)
}

///|
fn af_walk_instr(instr : TInstr, f : (TInstr) -> Unit) -> Unit {
  f(instr)
  match instr {
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      for item in body.0 {
        af_walk_instr(item, f)
      }
    TIf(_, cond, then_, else_) => {
      af_walk_instr(cond, f)
      for item in then_.0 {
        af_walk_instr(item, f)
      }
      match else_ {
        Some(other) =>
          for item in other.0 {
            af_walk_instr(item, f)
          }
        None => ()
      }
    }
    _ =>
      for child in af_eval_children(instr) {
        af_walk_instr(child, f)
      }
  }
}

///|
fn af_collect_br_indices(body : TExpr) -> Set[Int] {
  let out = Set::new()
  for instr in body.0 {
    af_walk_instr(instr, fn(curr) {
      match curr {
        TBr(LabelIdx(i), [TI32Const(I32(v))]) if i.reinterpret_as_int() == 0 =>
          out.add(v)
        _ => ()
      }
    })
  }
  out
}

///|
fn af_has_local_set_load(body : TExpr, idx : LocalIdx) -> Bool {
  let found = Ref::new(false)
  for instr in body.0 {
    af_walk_instr(instr, fn(curr) {
      match curr {
        TLocalSet(id, TLoad(_, _, _)) if id == idx =>
          found.update(fn(_) { true })
        _ => ()
      }
    })
  }
  found.val
}

///|
fn af_count_calls(body : TExpr, target : FuncIdx) -> Int {
  let count = Ref::new(0)
  for instr in body.0 {
    af_walk_instr(instr, fn(curr) {
      match curr {
        TCall(fi, _) if fi == target => count.update(fn(c) { c + 1 })
        _ => ()
      }
    })
  }
  count.val
}

///|
fn af_contains_call_indirect(body : TExpr) -> Bool {
  let found = Ref::new(false)
  for instr in body.0 {
    af_walk_instr(instr, fn(curr) {
      match curr {
        TCallIndirect(_, _, _, _) => found.update(fn(_) { true })
        _ => ()
      }
    })
  }
  found.val
}

///|
fn af_has_state_assert_guard(body : TExpr) -> Bool {
  let found = Ref::new(false)
  for instr in body.0 {
    af_walk_instr(instr, fn(curr) {
      match curr {
        TIf(
          _,
          TBinary(I32NeOp, TGlobalGet(_), TLocalGet(_)),
          TExpr([TUnreachable]),
          None
        ) => found.update(fn(_) { true })
        _ => ()
      }
    })
  }
  found.val
}

///|
test "asyncify_apply_arguments parses core flags" {
  let props = AsyncifyPassProps::new()
  let updated = match
    asyncify_apply_arguments(props, [
      "asyncify-ignore-imports", "asyncify-ignore-indirect", "asyncify-asserts",
      "asyncify-imports@env.sleep,mod.run", "asyncify-removelist@foo*", "asyncify-addlist@bar*",
      "asyncify-propagate-addlist", "asyncify-memory@heap",
    ]) {
    Ok(p) => p
    Err(e) => fail("unexpected asyncify arg parse error: \{e}")
  }
  assert_true(updated.ignore_imports)
  assert_true(updated.ignore_indirect)
  assert_true(updated.asserts)
  assert_eq(updated.imports.length(), 2)
  assert_eq(updated.removelist.length(), 1)
  assert_eq(updated.addlist.length(), 1)
  assert_true(updated.propagate_addlist)
  match updated.memory {
    Some(name) => assert_eq(name, "heap")
    None => fail("expected asyncify memory name")
  }
}

///|
test "asyncify creates runtime globals and exports" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
  )
  let out = match
    asyncify(mod, props=AsyncifyPassProps::new(export_globals=true)) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out.global_sec {
    Some(GlobalSec(globals)) => assert_true(globals.length() >= 2)
    _ => fail("expected globals")
  }
  let mut saw_start_unwind = false
  let mut saw_stop_unwind = false
  let mut saw_start_rewind = false
  let mut saw_stop_rewind = false
  let mut saw_get_state = false
  match out.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          Export(Name(name), FuncExternIdx(_)) => {
            let s = name.to_string()
            if s == AF_RUNTIME_START_UNWIND {
              saw_start_unwind = true
            }
            if s == AF_RUNTIME_STOP_UNWIND {
              saw_stop_unwind = true
            }
            if s == AF_RUNTIME_START_REWIND {
              saw_start_rewind = true
            }
            if s == AF_RUNTIME_STOP_REWIND {
              saw_stop_rewind = true
            }
            if s == AF_RUNTIME_GET_STATE {
              saw_get_state = true
            }
          }
          _ => ()
        }
      }
    _ => fail("expected exports")
  }
  assert_true(saw_start_unwind)
  assert_true(saw_stop_unwind)
  assert_true(saw_start_rewind)
  assert_true(saw_stop_rewind)
  assert_true(saw_get_state)
}

///|
test "asyncify instruments direct calls with unwind indices" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("sleep"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          TExpr::new([
            TInstr::call(FuncIdx::new(0), []),
            TInstr::call(FuncIdx::new(0), []),
          ]),
        ),
      ]),
    )
  let out = match af_test_run(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) => {
      let indices = af_collect_br_indices(body)
      assert_true(indices.contains(0))
      assert_true(indices.contains(1))
    }
    _ => fail("expected code section")
  }
}

///|
test "asyncify lowers call result local.set through locals temp" {
  let t_ret_i32 = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_ret_i32]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("get"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          TExpr::new([
            TInstr::local_set(
              LocalIdx::new(0),
              TInstr::call(FuncIdx::new(0), []),
            ),
          ]),
        ),
      ]),
    )
  let out = match af_test_run(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) => {
      let seen = Ref::new(false)
      for instr in body.0 {
        af_walk_instr(instr, fn(curr) {
          match curr {
            TLocalSet(_, TCall(FuncIdx(i), [])) if i == 0U =>
              seen.update(fn(_) { true })
            _ => ()
          }
        })
      }
      assert_true(seen.val)
    }
    _ => fail("expected transformed body")
  }
}

///|
test "asyncify ignore-imports keeps function non-instrumented" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("sleep"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(0), [])])),
      ]),
    )
  let out = match
    af_test_run(mod, props=AsyncifyPassProps::new(ignore_imports=true)) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) => {
      assert_eq(af_count_calls(body, FuncIdx::new(0)), 1)
      let indices = af_collect_br_indices(body)
      assert_false(indices.contains(0))
    }
    _ => fail("expected code section")
  }
}

///|
test "asyncify import allowlist controls state-changing imports" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("foo"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(0), [])])),
      ]),
    )
  let out = match
    af_test_run(mod, props=AsyncifyPassProps::new(imports=["env.sleep"])) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) => {
      let indices = af_collect_br_indices(body)
      assert_false(indices.contains(0))
    }
    _ => fail("expected code section")
  }
}

///|
test "asyncify ignore-indirect leaves indirect call unwrapped unless addlist" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("sleep"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(0), []),
            TInstr::drop(
              TInstr::call_indirect(
                TypeIdx::new(0),
                TableIdx::new(0),
                [],
                TInstr::i32_const(I32(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out_ignored = match
    af_test_run(mod, props=AsyncifyPassProps::new(ignore_indirect=true)) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out_ignored.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) =>
      assert_true(af_contains_call_indirect(body))
    _ => fail("expected code section")
  }
  let out_add = match
    af_test_run(
      mod,
      props=AsyncifyPassProps::new(ignore_indirect=true, addlist=["func:1"]),
    ) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out_add.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) => {
      let indices = af_collect_br_indices(body)
      assert_true(indices.contains(1))
    }
    _ => fail("expected code section")
  }
}

///|
test "asyncify lists onlylist/removelist/addlist propagation" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let caller = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(2), [])]))
  let callee = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(0), [])]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("sleep"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("caller"), ExternIdx::func(FuncIdx::new(1))),
        Export::new(Name::new("callee"), ExternIdx::func(FuncIdx::new(2))),
      ]),
    )
    .with_code_sec(CodeSec::new([caller, callee]))
  let out_only = match
    af_test_run(mod, props=AsyncifyPassProps::new(onlylist=["callee"])) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out_only.code_sec {
    Some(CodeSec([TFunc(_, caller_body), TFunc(_, callee_body), ..])) => {
      assert_false(af_collect_br_indices(caller_body).contains(0))
      assert_true(af_collect_br_indices(callee_body).contains(0))
    }
    _ => fail("expected code section")
  }
  let out_remove = match
    af_test_run(mod, props=AsyncifyPassProps::new(removelist=["callee"])) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out_remove.code_sec {
    Some(CodeSec([_, TFunc(_, callee_body), ..])) =>
      assert_false(af_collect_br_indices(callee_body).contains(0))
    _ => fail("expected code section")
  }
  let out_propagate = match
    af_test_run(
      mod,
      props=AsyncifyPassProps::new(addlist=["callee"], propagate_addlist=true),
    ) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out_propagate.code_sec {
    Some(CodeSec([TFunc(_, caller_body), TFunc(_, callee_body), ..])) => {
      assert_true(af_collect_br_indices(callee_body).contains(0))
      assert_true(af_collect_br_indices(caller_body).contains(0))
    }
    _ => fail("expected code section")
  }
}

///|
test "asyncify local save/restore tracks relevant locals" {
  let t1 = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t1]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("sleep"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::call(FuncIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
          ]),
        ),
      ]),
    )
  let out = match af_test_run(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) => {
      assert_true(af_has_local_set_load(body, LocalIdx::new(0)))
      assert_false(af_has_local_set_load(body, LocalIdx::new(1)))
    }
    _ => fail("expected code section")
  }
}

///|
test "asyncify asserts add non-instrumented state guard" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("sleep"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(0), [])])),
      ]),
    )
  let out = match
    af_test_run(
      mod,
      props=AsyncifyPassProps::new(ignore_imports=true, asserts=true),
    ) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) =>
      assert_true(af_has_state_assert_guard(body))
    _ => fail("expected code section")
  }
}

///|
test "asyncify asserts guard calls inside try_table when enabled" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("sleep"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::void_(),
              [Catch::all(LabelIdx::new(0))],
              TExpr::new([TInstr::call(FuncIdx::new(0), [])]),
            ),
          ]),
        ),
      ]),
    )
  let out = match af_test_run(mod, props=AsyncifyPassProps::new(asserts=true)) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) => {
      let saw_guard = Ref::new(false)
      for instr in body.0 {
        af_walk_instr(instr, fn(curr) {
          match curr {
            TIf(
              _,
              TBinary(I32NeOp, TGlobalGet(_), TI32Const(I32(v))),
              TExpr([TUnreachable]),
              None
            ) if v == AF_STATE_NORMAL => saw_guard.update(fn(_) { true })
            _ => ()
          }
        })
      }
      assert_true(saw_guard.val)
    }
    _ => fail("expected code section")
  }
}

///|
test "asyncify ignore-unwind-from-catch disables try_table call guard" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("sleep"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::try_table(
              BlockType::void_(),
              [Catch::all(LabelIdx::new(0))],
              TExpr::new([TInstr::call(FuncIdx::new(0), [])]),
            ),
          ]),
        ),
      ]),
    )
  let out = match
    af_test_run(
      mod,
      props=AsyncifyPassProps::new(asserts=true, ignore_unwind_from_catch=true),
    ) {
    Ok(m) => m
    Err(e) => fail("unexpected asyncify error: \{e}")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, body), ..])) => {
      let saw_guard = Ref::new(false)
      for instr in body.0 {
        af_walk_instr(instr, fn(curr) {
          match curr {
            TIf(
              _,
              TBinary(I32NeOp, TGlobalGet(_), TI32Const(I32(v))),
              TExpr([TUnreachable]),
              None
            ) if v == AF_STATE_NORMAL => saw_guard.update(fn(_) { true })
            _ => ()
          }
        })
      }
      assert_false(saw_guard.val)
    }
    _ => fail("expected code section")
  }
}
