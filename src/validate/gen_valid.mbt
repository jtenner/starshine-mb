///|
pub enum GenValidMode {
  Natural
  CoverageForced
} derive(Eq, Show, Debug)

///|
pub struct GenValidSectionBias {
  imports_percent : Int
  tables_percent : Int
  mems_percent : Int
  globals_percent : Int
  tags_percent : Int
  start_percent : Int
  elems_percent : Int
  datas_percent : Int
} derive(Eq, Show, Debug)

///|
pub fn GenValidSectionBias::natural_default() -> GenValidSectionBias {
  {
    imports_percent: 30,
    tables_percent: 30,
    mems_percent: 30,
    globals_percent: 67,
    tags_percent: 20,
    start_percent: 10,
    elems_percent: 20,
    datas_percent: 20,
  }
}

///|
pub fn GenValidSectionBias::coverage_forced_default() -> GenValidSectionBias {
  {
    imports_percent: 100,
    tables_percent: 100,
    mems_percent: 100,
    globals_percent: 100,
    tags_percent: 100,
    start_percent: 100,
    elems_percent: 100,
    datas_percent: 100,
  }
}

///|
pub struct GenValidFeatureToggles {
  allow_imports : Bool
  allow_tables : Bool
  allow_mems : Bool
  allow_globals : Bool
  allow_tags : Bool
  allow_start : Bool
  allow_elems : Bool
  allow_datas : Bool
  allow_ref_types : Bool
  allow_v128 : Bool
  allow_calls : Bool
  allow_call_indirect : Bool
  allow_branch_heavy_control : Bool
} derive(Eq, Show, Debug)

///|
pub fn GenValidFeatureToggles::natural_default() -> GenValidFeatureToggles {
  {
    allow_imports: true,
    allow_tables: true,
    allow_mems: true,
    allow_globals: true,
    allow_tags: true,
    allow_start: true,
    allow_elems: true,
    allow_datas: true,
    allow_ref_types: true,
    allow_v128: true,
    allow_calls: true,
    allow_call_indirect: true,
    allow_branch_heavy_control: true,
  }
}

///|
pub fn GenValidFeatureToggles::coverage_forced_default() -> GenValidFeatureToggles {
  GenValidFeatureToggles::{
    ..GenValidFeatureToggles::natural_default(),
    allow_calls: true,
    allow_call_indirect: true,
    allow_branch_heavy_control: true,
  }
}

///|
pub struct GenValidConfig {
  mode : GenValidMode
  max_type_defs : Int
  max_imports : Int
  max_defined_funcs : Int
  max_tables : Int
  max_mems : Int
  max_globals : Int
  max_tags : Int
  max_elems : Int
  max_datas : Int
  max_params : Int
  max_results : Int
  max_locals : Int
  max_body_statements : Int
  max_body_depth : Int
  section_bias : GenValidSectionBias
  features : GenValidFeatureToggles
} derive(Eq, Show, Debug)

///|
pub fn GenValidConfig::natural_default() -> GenValidConfig {
  {
    mode: Natural,
    max_type_defs: 4,
    max_imports: 1,
    max_defined_funcs: 4,
    max_tables: 1,
    max_mems: 1,
    max_globals: 2,
    max_tags: 1,
    max_elems: 1,
    max_datas: 1,
    max_params: 2,
    max_results: 1,
    max_locals: 3,
    max_body_statements: 6,
    max_body_depth: 2,
    section_bias: GenValidSectionBias::natural_default(),
    features: GenValidFeatureToggles::natural_default(),
  }
}

///|
pub fn GenValidConfig::coverage_forced_default() -> GenValidConfig {
  GenValidConfig::{
    ..GenValidConfig::natural_default(),
    mode: CoverageForced,
    max_globals: 2,
    section_bias: GenValidSectionBias::coverage_forced_default(),
    features: GenValidFeatureToggles::coverage_forced_default(),
  }
}

///|
pub fn default_gen_valid_config() -> GenValidConfig {
  GenValidConfig::natural_default()
}

///|
pub struct GenValidFeatureFacts {
  mode : GenValidMode
  has_imports : Bool
  has_func_exports : Bool
  has_table_exports : Bool
  has_mem_exports : Bool
  has_global_exports : Bool
  has_tag_exports : Bool
  has_start : Bool
  lacks_start : Bool
  has_tables : Bool
  has_mems : Bool
  has_globals : Bool
  has_tags : Bool
  has_elems : Bool
  has_datas : Bool
  has_data_count : Bool
  uses_ref_types : Bool
  uses_v128 : Bool
  has_call : Bool
  has_call_indirect : Bool
  has_branch_heavy_control : Bool
} derive(Eq, Show, Debug)

///|
pub struct GenValidFeatureStats {
  mode : GenValidMode
  modules : Int
  imports : Int
  func_exports : Int
  table_exports : Int
  mem_exports : Int
  global_exports : Int
  tag_exports : Int
  starts : Int
  lacks_start : Int
  tables : Int
  mems : Int
  globals : Int
  tags : Int
  elems : Int
  datas : Int
  data_count : Int
  ref_types : Int
  v128 : Int
  calls : Int
  call_indirect : Int
  branch_heavy_control : Int
} derive(Eq, Show, Debug)

///|
pub fn GenValidFeatureStats::empty(mode : GenValidMode) -> GenValidFeatureStats {
  {
    mode,
    modules: 0,
    imports: 0,
    func_exports: 0,
    table_exports: 0,
    mem_exports: 0,
    global_exports: 0,
    tag_exports: 0,
    starts: 0,
    lacks_start: 0,
    tables: 0,
    mems: 0,
    globals: 0,
    tags: 0,
    elems: 0,
    datas: 0,
    data_count: 0,
    ref_types: 0,
    v128: 0,
    calls: 0,
    call_indirect: 0,
    branch_heavy_control: 0,
  }
}

///|
pub fn GenValidFeatureStats::record(
  self : GenValidFeatureStats,
  facts : GenValidFeatureFacts,
) -> GenValidFeatureStats {
  GenValidFeatureStats::{
    ..self,
    modules: self.modules + 1,
    imports: self.imports + gen_valid_bool_count(facts.has_imports),
    func_exports: self.func_exports +
    gen_valid_bool_count(facts.has_func_exports),
    table_exports: self.table_exports +
    gen_valid_bool_count(facts.has_table_exports),
    mem_exports: self.mem_exports + gen_valid_bool_count(facts.has_mem_exports),
    global_exports: self.global_exports +
    gen_valid_bool_count(facts.has_global_exports),
    tag_exports: self.tag_exports + gen_valid_bool_count(facts.has_tag_exports),
    starts: self.starts + gen_valid_bool_count(facts.has_start),
    lacks_start: self.lacks_start + gen_valid_bool_count(facts.lacks_start),
    tables: self.tables + gen_valid_bool_count(facts.has_tables),
    mems: self.mems + gen_valid_bool_count(facts.has_mems),
    globals: self.globals + gen_valid_bool_count(facts.has_globals),
    tags: self.tags + gen_valid_bool_count(facts.has_tags),
    elems: self.elems + gen_valid_bool_count(facts.has_elems),
    datas: self.datas + gen_valid_bool_count(facts.has_datas),
    data_count: self.data_count + gen_valid_bool_count(facts.has_data_count),
    ref_types: self.ref_types + gen_valid_bool_count(facts.uses_ref_types),
    v128: self.v128 + gen_valid_bool_count(facts.uses_v128),
    calls: self.calls + gen_valid_bool_count(facts.has_call),
    call_indirect: self.call_indirect +
    gen_valid_bool_count(facts.has_call_indirect),
    branch_heavy_control: self.branch_heavy_control +
    gen_valid_bool_count(facts.has_branch_heavy_control),
  }
}

///|
struct GenValidContext {
  rnd : RandomState
  config : GenValidConfig
}

///|
priv struct GenValidInstrFacts {
  uses_ref_types : Bool
  uses_v128 : Bool
  has_call : Bool
  has_call_indirect : Bool
  control_nodes : Int
  branch_ops : Int
}

///|
fn GenValidContext::new(
  rnd : RandomState,
  config : GenValidConfig,
) -> GenValidContext {
  { rnd, config }
}

///|
fn GenValidInstrFacts::empty() -> GenValidInstrFacts {
  {
    uses_ref_types: false,
    uses_v128: false,
    has_call: false,
    has_call_indirect: false,
    control_nodes: 0,
    branch_ops: 0,
  }
}

///|
fn gen_valid_bool_count(flag : Bool) -> Int {
  if flag {
    1
  } else {
    0
  }
}

///|
fn gen_valid_clamp_non_negative(value : Int) -> Int {
  if value < 0 {
    0
  } else {
    value
  }
}

///|
fn gen_valid_min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn gen_valid_roll_percent(ctx : GenValidContext, percent : Int) -> Bool {
  let bounded = if percent < 0 {
    0
  } else if percent > 100 {
    100
  } else {
    percent
  }
  if bounded <= 0 {
    false
  } else if bounded >= 100 {
    true
  } else {
    ctx.random_int(100) < bounded
  }
}

///|
fn GenValidContext::random_int(self : GenValidContext, max : Int) -> Int {
  if max <= 0 {
    0
  } else {
    (self.rnd.next_int().reinterpret_as_uint() % max.reinterpret_as_uint()).reinterpret_as_int()
  }
}

///|
fn GenValidContext::random_bool(self : GenValidContext) -> Bool {
  self.random_int(2) == 0
}

///|
pub fn gen_valid_valtype(ctx : GenValidContext) -> ValType {
  let allow_v128 = ctx.config.features.allow_v128
  let allow_ref_types = ctx.config.features.allow_ref_types
  let choice_count = 4 +
    gen_valid_bool_count(allow_v128) +
    (if allow_ref_types { 2 } else { 0 })
  match ctx.random_int(choice_count) {
    0 => ValType::i32()
    1 => ValType::i64()
    2 => ValType::f32()
    3 => ValType::f64()
    4 => if allow_v128 { ValType::v128() } else { ValType::funcref() }
    _ => ValType::externref()
  }
}

///|
pub fn gen_valid_numtype(ctx : GenValidContext) -> NumType {
  match ctx.random_int(4) {
    0 => NumType::i32()
    1 => NumType::i64()
    2 => NumType::f32()
    _ => NumType::f64()
  }
}

///|
fn gen_const_expr(ctx : GenValidContext, vt : ValType) -> Expr {
  Expr::new([gen_const_instr(ctx, vt)])
}

///|
fn gen_const_instr(ctx : GenValidContext, vt : ValType) -> Instruction {
  match vt {
    NumTypeValType(I32NumType) =>
      Instruction::i32_const(I32(ctx.random_int(1000)))
    NumTypeValType(I64NumType) =>
      Instruction::i64_const(I64(ctx.random_int(1000).to_int64()))
    NumTypeValType(F32NumType) =>
      Instruction::f32_const(
        F32(Float::from_double(ctx.random_int(100).to_double())),
      )
    NumTypeValType(F64NumType) =>
      Instruction::f64_const(F64(ctx.random_int(100).to_double()))
    VecTypeValType =>
      Instruction::v128_const(
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      )
    RefTypeValType(rt) => Instruction::ref_null(rt.get_heap_type())
    BotValType => Instruction::unreachable_()
  }
}

///|
fn gen_result_types(ctx : GenValidContext) -> Array[ValType] {
  let max_results = gen_valid_clamp_non_negative(ctx.config.max_results)
  if max_results <= 0 || ctx.random_bool() {
    []
  } else {
    let result_count = 1 + ctx.random_int(max_results)
    let results : Array[ValType] = []
    for _ in 0..<result_count {
      results.push(gen_valid_valtype(ctx))
    }
    results
  }
}

///|
fn gen_param_types(ctx : GenValidContext) -> Array[ValType] {
  let count = ctx.random_int(
    gen_valid_clamp_non_negative(ctx.config.max_params) + 1,
  )
  let params : Array[ValType] = []
  for _ in 0..<count {
    params.push(gen_valid_valtype(ctx))
  }
  params
}

///|
fn gen_local_types(ctx : GenValidContext) -> Array[ValType] {
  let count = ctx.random_int(
    gen_valid_clamp_non_negative(ctx.config.max_locals) + 1,
  )
  let locals : Array[ValType] = []
  for _ in 0..<count {
    locals.push(gen_valid_valtype(ctx))
  }
  locals
}

///|
fn gen_all_local_types(
  params : Array[ValType],
  locals : Array[ValType],
) -> Array[ValType] {
  let out = params.copy()
  for local_ty in locals {
    out.push(local_ty)
  }
  out
}

///|
fn gen_matching_local_idx(
  local_types : Array[ValType],
  vt : ValType,
) -> LocalIdx? {
  for i = 0; i < local_types.length(); i = i + 1 {
    if local_types[i] == vt {
      return Some(LocalIdx::new(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
priv struct GenValidFuncSig {
  idx : FuncIdx
  type_idx : TypeIdx
  params : Array[ValType]
  results : Array[ValType]
}

///|
priv struct GenValidBodyEnv {
  local_types : Array[ValType]
  globals : Array[GlobalType]
  tables : Array[TableType]
  mems : Array[MemType]
  funcs : Array[GenValidFuncSig]
  declared_ref_func_idx : FuncIdx?
  depth_left : Int
  label_depth : Int
}

///|
fn gen_matching_global_idx(
  globals : Array[GlobalType],
  vt : ValType,
  mutable_only? : Bool = false,
) -> GlobalIdx? {
  for i = 0; i < globals.length(); i = i + 1 {
    let GlobalType(global_vt, is_mut) = globals[i]
    if global_vt == vt && (!mutable_only || is_mut) {
      return Some(GlobalIdx::new(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
fn gen_valid_memarg() -> MemArg {
  MemArg::new(U32(0), None, U64(0))
}

///|
fn gen_valid_body_env_child(
  env : GenValidBodyEnv,
  add_void_label? : Bool = false,
) -> GenValidBodyEnv {
  let next_label_depth = if add_void_label {
    env.label_depth + 1
  } else {
    env.label_depth
  }
  {
    ..env,
    depth_left: if env.depth_left > 0 {
      env.depth_left - 1
    } else {
      0
    },
    label_depth: next_label_depth,
  }
}

///|
fn gen_valid_body_stmt_count(ctx : GenValidContext, depth_left : Int) -> Int {
  let bounded = gen_valid_clamp_non_negative(ctx.config.max_body_statements)
  let capped = if depth_left <= 0 {
    gen_valid_min_int(2, bounded)
  } else {
    gen_valid_min_int(3, bounded)
  }
  1 + ctx.random_int(capped)
}

///|
fn gen_valid_append_call_args(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  params : Array[ValType],
) -> Unit {
  let child_env = gen_valid_body_env_child(env)
  for param in params {
    append_value_instrs(out, ctx, param, child_env, prefer_local=true)
  }
}

///|
fn gen_valid_append_call_result_drops(
  out : Array[Instruction],
  results : Array[ValType],
) -> Unit {
  for _ in results {
    out.push(Instruction::drop())
  }
}

///|
fn gen_valid_pick_callable_with_result(
  ctx : GenValidContext,
  funcs : Array[GenValidFuncSig],
  vt : ValType,
) -> GenValidFuncSig? {
  let matches : Array[GenValidFuncSig] = []
  for func in funcs {
    if func.results == [vt] {
      matches.push(func)
    }
  }
  if matches.is_empty() {
    None
  } else {
    Some(matches[ctx.random_int(matches.length())])
  }
}

///|
fn gen_valid_pick_callable(
  ctx : GenValidContext,
  funcs : Array[GenValidFuncSig],
) -> GenValidFuncSig? {
  if funcs.is_empty() {
    None
  } else {
    Some(funcs[ctx.random_int(funcs.length())])
  }
}

///|
fn gen_valid_append_table_ref_value(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  rt : RefType,
) -> Unit {
  append_value_instrs(
    out,
    ctx,
    ValType::ref_type(rt),
    gen_valid_body_env_child(env),
    prefer_local=false,
  )
}

///|
fn gen_valid_append_nested_void_instrs(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  let child = gen_valid_body_env_child(env, add_void_label=true)
  let stmt_count = gen_valid_body_stmt_count(ctx, child.depth_left)
  for _ in 0..<stmt_count {
    append_void_stmt(out, ctx, child)
  }
}

///|
fn append_value_instrs(
  out : Array[Instruction],
  ctx : GenValidContext,
  vt : ValType,
  env : GenValidBodyEnv,
  prefer_local? : Bool = true,
) -> Unit {
  if prefer_local && ctx.random_bool() {
    match gen_matching_local_idx(env.local_types, vt) {
      Some(idx) => {
        out.push(Instruction::local_get(idx))
        return
      }
      None => ()
    }
  }
  match gen_matching_global_idx(env.globals, vt) {
    Some(idx) if ctx.random_int(5) == 0 => {
      out.push(Instruction::global_get(idx))
      return
    }
    _ => ()
  }
  if env.depth_left > 0 {
    if ctx.config.features.allow_calls {
      match gen_valid_pick_callable_with_result(ctx, env.funcs, vt) {
        Some(target) if ctx.random_int(4) == 0 => {
          gen_valid_append_call_args(out, ctx, env, target.params)
          out.push(Instruction::call(target.idx))
          return
        }
        _ => ()
      }
    }
    if !env.mems.is_empty() && vt == ValType::i32() && ctx.random_int(5) == 0 {
      out.push(Instruction::memory_size(MemIdx::new(0U)))
      return
    }
    if ctx.config.features.allow_call_indirect && !env.tables.is_empty() {
      match gen_valid_pick_callable_with_result(ctx, env.funcs, vt) {
        Some(target) if ctx.random_int(4) == 0 => {
          gen_valid_append_call_args(out, ctx, env, target.params)
          out.push(Instruction::i32_const(I32(0)))
          out.push(
            Instruction::call_indirect(target.type_idx, TableIdx::new(0U)),
          )
          return
        }
        _ => ()
      }
    }
    if ctx.config.features.allow_branch_heavy_control && ctx.random_int(5) == 0 {
      let then_body : Array[Instruction] = []
      let else_body : Array[Instruction] = []
      let child = gen_valid_body_env_child(env)
      append_value_instrs(then_body, ctx, vt, child, prefer_local=false)
      append_value_instrs(else_body, ctx, vt, child, prefer_local=false)
      out.push(
        Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
      )
      out.push(
        Instruction::if_(BlockType::val_type(vt), then_body, Some(else_body)),
      )
      return
    }
    if ctx.config.features.allow_branch_heavy_control && ctx.random_int(5) == 0 {
      let child_body : Array[Instruction] = []
      append_value_instrs(
        child_body,
        ctx,
        vt,
        gen_valid_body_env_child(env),
        prefer_local=false,
      )
      out.push(
        Instruction::block(BlockType::val_type(vt), Expr::new(child_body)),
      )
      return
    }
    if !env.tables.is_empty() {
      let TableType(rt, _) = env.tables[0]
      if vt == ValType::ref_type(rt) && ctx.random_int(4) == 0 {
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::table_get(TableIdx::new(0U)))
        return
      }
    }
    if !env.mems.is_empty() {
      let memarg = gen_valid_memarg()
      match vt {
        NumTypeValType(I32NumType) if ctx.random_int(4) == 0 => {
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::i32_load(memarg))
          return
        }
        NumTypeValType(I64NumType) if ctx.random_int(4) == 0 => {
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::i64_load(memarg))
          return
        }
        NumTypeValType(F32NumType) if ctx.random_int(4) == 0 => {
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::f32_load(memarg))
          return
        }
        NumTypeValType(F64NumType) if ctx.random_int(4) == 0 => {
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::f64_load(memarg))
          return
        }
        _ => ()
      }
    }
    if !env.tables.is_empty() && vt == ValType::i32() && ctx.random_int(4) == 0 {
      out.push(Instruction::table_size(TableIdx::new(0U)))
      return
    }
  }
  match vt {
    RefTypeValType(rt) => {
      let heap_type = rt.get_heap_type()
      if ValType::ref_type(rt) == ValType::funcref() {
        match env.declared_ref_func_idx {
          Some(func_idx) if ctx.random_bool() => {
            out.push(Instruction::ref_func(func_idx))
            return
          }
          _ => ()
        }
      }
      out.push(Instruction::ref_null(heap_type))
    }
    _ => out.push(gen_const_instr(ctx, vt))
  }
}

///|
fn append_void_stmt(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  let branchy = ctx.config.features.allow_branch_heavy_control
  match ctx.random_int(if branchy { 12 } else { 8 }) {
    0 => out.push(Instruction::nop())
    1 => {
      let vt = gen_valid_valtype(ctx)
      append_value_instrs(out, ctx, vt, env, prefer_local=false)
      out.push(Instruction::drop())
    }
    2 =>
      if env.local_types.is_empty() {
        out.push(Instruction::nop())
      } else {
        let idx = ctx.random_int(env.local_types.length())
        let vt = env.local_types[idx]
        append_value_instrs(
          out,
          ctx,
          vt,
          gen_valid_body_env_child(env),
          prefer_local=false,
        )
        out.push(
          Instruction::local_set(LocalIdx::new(idx.reinterpret_as_uint())),
        )
      }
    3 =>
      match
        gen_matching_global_idx(
          env.globals,
          gen_valid_valtype(ctx),
          mutable_only=true,
        ) {
        Some(idx) => {
          let GlobalIdx(idx_u) = idx
          let GlobalType(vt, _) = env.globals[idx_u.reinterpret_as_int()]
          append_value_instrs(
            out,
            ctx,
            vt,
            gen_valid_body_env_child(env),
            prefer_local=false,
          )
          out.push(Instruction::global_set(idx))
        }
        None => out.push(Instruction::nop())
      }
    4 =>
      if ctx.config.features.allow_calls {
        match gen_valid_pick_callable(ctx, env.funcs) {
          Some(target) => {
            gen_valid_append_call_args(out, ctx, env, target.params)
            out.push(Instruction::call(target.idx))
            gen_valid_append_call_result_drops(out, target.results)
          }
          None => out.push(Instruction::nop())
        }
      } else {
        out.push(Instruction::nop())
      }
    5 =>
      if ctx.config.features.allow_call_indirect && !env.tables.is_empty() {
        match gen_valid_pick_callable(ctx, env.funcs) {
          Some(target) => {
            gen_valid_append_call_args(out, ctx, env, target.params)
            out.push(Instruction::i32_const(I32(0)))
            out.push(
              Instruction::call_indirect(target.type_idx, TableIdx::new(0U)),
            )
            gen_valid_append_call_result_drops(out, target.results)
          }
          None => out.push(Instruction::nop())
        }
      } else {
        out.push(Instruction::nop())
      }
    6 =>
      if !env.mems.is_empty() {
        let memarg = gen_valid_memarg()
        out.push(Instruction::memory_size(MemIdx::new(0U)))
        out.push(Instruction::drop())
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::i32_const(I32(1)))
        out.push(Instruction::i32_store(memarg))
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::i32_load(memarg))
        out.push(Instruction::drop())
      } else {
        out.push(Instruction::nop())
      }
    7 =>
      if !env.tables.is_empty() {
        let TableType(rt, _) = env.tables[0]
        out.push(Instruction::table_size(TableIdx::new(0U)))
        out.push(Instruction::drop())
        out.push(Instruction::i32_const(I32(0)))
        gen_valid_append_table_ref_value(out, ctx, env, rt)
        out.push(Instruction::table_set(TableIdx::new(0U)))
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::table_get(TableIdx::new(0U)))
        out.push(Instruction::drop())
      } else {
        out.push(Instruction::nop())
      }
    8 => {
      let body : Array[Instruction] = []
      gen_valid_append_nested_void_instrs(body, ctx, env)
      out.push(Instruction::block(BlockType::void_(), Expr::new(body)))
    }
    9 => {
      let body : Array[Instruction] = []
      gen_valid_append_nested_void_instrs(body, ctx, env)
      if branchy {
        body.push(
          Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
        )
        body.push(Instruction::br_if(LabelIdx::new(0U)))
      }
      out.push(Instruction::loop_(BlockType::void_(), Expr::new(body)))
    }
    10 => {
      let then_body : Array[Instruction] = []
      let else_body : Array[Instruction] = []
      let child = gen_valid_body_env_child(env)
      let branch_stmt_count = gen_valid_body_stmt_count(ctx, child.depth_left)
      for _ in 0..<branch_stmt_count {
        append_void_stmt(then_body, ctx, child)
        append_void_stmt(else_body, ctx, child)
      }
      out.push(
        Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
      )
      out.push(Instruction::if_(BlockType::void_(), then_body, Some(else_body)))
    }
    _ =>
      if branchy && env.label_depth > 0 {
        if ctx.random_bool() {
          out.push(
            Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
          )
          out.push(Instruction::br_if(LabelIdx::new(0U)))
        } else {
          out.push(Instruction::br(LabelIdx::new(0U)))
        }
      } else {
        out.push(Instruction::nop())
      }
  }
}

///|
fn gen_valid_append_coverage_prelude(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  if ctx.config.features.allow_v128 {
    out.push(
      Instruction::v128_const(
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      ),
    )
    out.push(Instruction::drop())
  }
  if ctx.config.features.allow_ref_types {
    append_value_instrs(
      out,
      ctx,
      ValType::funcref(),
      gen_valid_body_env_child(env),
      prefer_local=false,
    )
    out.push(Instruction::drop())
    append_value_instrs(
      out,
      ctx,
      ValType::externref(),
      gen_valid_body_env_child(env),
      prefer_local=false,
    )
    out.push(Instruction::drop())
  }
  if ctx.config.features.allow_calls {
    match gen_valid_pick_callable(ctx, env.funcs) {
      Some(target) => {
        gen_valid_append_call_args(out, ctx, env, target.params)
        out.push(Instruction::call(target.idx))
        gen_valid_append_call_result_drops(out, target.results)
      }
      None => ()
    }
  }
  if ctx.config.features.allow_call_indirect && !env.tables.is_empty() {
    match gen_valid_pick_callable(ctx, env.funcs) {
      Some(target) => {
        gen_valid_append_call_args(out, ctx, env, target.params)
        out.push(Instruction::i32_const(I32(0)))
        out.push(Instruction::call_indirect(target.type_idx, TableIdx::new(0U)))
        gen_valid_append_call_result_drops(out, target.results)
      }
      None => ()
    }
  }
  if !env.mems.is_empty() {
    let memarg = gen_valid_memarg()
    out.push(Instruction::memory_size(MemIdx::new(0U)))
    out.push(Instruction::drop())
    out.push(Instruction::i32_const(I32(1)))
    out.push(Instruction::memory_grow(MemIdx::new(0U)))
    out.push(Instruction::drop())
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(7)))
    out.push(Instruction::i32_store(memarg))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_load(memarg))
    out.push(Instruction::drop())
  }
  if !env.tables.is_empty() {
    let TableType(rt, _) = env.tables[0]
    out.push(Instruction::table_size(TableIdx::new(0U)))
    out.push(Instruction::drop())
    out.push(Instruction::i32_const(I32(0)))
    gen_valid_append_table_ref_value(out, ctx, env, rt)
    out.push(Instruction::table_set(TableIdx::new(0U)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::table_get(TableIdx::new(0U)))
    out.push(Instruction::drop())
    gen_valid_append_table_ref_value(out, ctx, env, rt)
    out.push(Instruction::i32_const(I32(1)))
    out.push(Instruction::table_grow(TableIdx::new(0U)))
    out.push(Instruction::drop())
  }
  if !env.globals.is_empty() {
    out.push(Instruction::global_get(GlobalIdx::new(0U)))
    out.push(Instruction::drop())
    let GlobalType(first_global_vt, _) = env.globals[0]
    match
      gen_matching_global_idx(env.globals, first_global_vt, mutable_only=true) {
      Some(idx) => {
        let GlobalIdx(idx_u) = idx
        let GlobalType(vt, _) = env.globals[idx_u.reinterpret_as_int()]
        append_value_instrs(
          out,
          ctx,
          vt,
          gen_valid_body_env_child(env),
          prefer_local=false,
        )
        out.push(Instruction::global_set(idx))
      }
      None => ()
    }
  }
  let branch_block_body = [
    Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
    Instruction::br_if(LabelIdx::new(0U)),
  ]
  out.push(Instruction::block(BlockType::void_(), Expr::new(branch_block_body)))
  out.push(
    Instruction::loop_(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
        Instruction::br_if(LabelIdx::new(0U)),
      ]),
    ),
  )
  out.push(Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::block(
          BlockType::void_(),
          Expr::new([Instruction::br(LabelIdx::new(0U))]),
        ),
      ],
      Some([Instruction::nop()]),
    ),
  )
}

///|
fn gen_valid_build_func(
  ctx : GenValidContext,
  accepts : Array[ValType],
  returns : Array[ValType],
  globals : Array[GlobalType],
  tables : Array[TableType],
  mems : Array[MemType],
  funcs : Array[GenValidFuncSig],
  declared_ref_func_idx : FuncIdx?,
) -> Func {
  let locals = gen_local_types(ctx)
  let all_local_types = gen_all_local_types(accepts, locals)
  let env : GenValidBodyEnv = {
    local_types: all_local_types,
    globals,
    tables,
    mems,
    funcs,
    declared_ref_func_idx,
    depth_left: gen_valid_clamp_non_negative(ctx.config.max_body_depth),
    label_depth: 0,
  }
  let body_instrs : Array[Instruction] = []
  if ctx.config.mode == CoverageForced {
    gen_valid_append_coverage_prelude(body_instrs, ctx, env)
  }
  let stmt_count = gen_valid_body_stmt_count(ctx, env.depth_left)
  for _ in 0..<stmt_count {
    append_void_stmt(body_instrs, ctx, env)
  }
  for ret in returns {
    append_value_instrs(body_instrs, ctx, ret, env)
  }
  Func::new(Locals::from_types(locals), Expr::new(body_instrs))
}

///|
pub fn gen_valid_tfunc(
  ctx : GenValidContext,
  accepts : Array[ValType],
  returns : Array[ValType],
) -> Func {
  gen_valid_build_func(ctx, accepts, returns, [], [], [], [], None)
}

///|
fn gen_valid_choose_optional_count(
  ctx : GenValidContext,
  allow : Bool,
  max_count : Int,
  percent : Int,
) -> Int {
  let bounded_max = gen_valid_clamp_non_negative(max_count)
  if !allow || bounded_max <= 0 {
    0
  } else if ctx.config.mode == CoverageForced ||
    gen_valid_roll_percent(ctx, percent) {
    1 + ctx.random_int(bounded_max)
  } else {
    0
  }
}

///|
fn gen_valid_choose_defined_func_count(ctx : GenValidContext) -> Int {
  let bounded_max = gen_valid_clamp_non_negative(ctx.config.max_defined_funcs)
  if bounded_max <= 1 {
    1
  } else if ctx.config.mode == CoverageForced {
    2 + ctx.random_int(bounded_max - 1)
  } else {
    1 + ctx.random_int(bounded_max)
  }
}

///|
fn gen_valid_active_i32_offset() -> Expr {
  Expr::new([Instruction::i32_const(I32(0))])
}

///|
fn gen_valid_pick_type_idx(ctx : GenValidContext, type_count : Int) -> TypeIdx {
  TypeIdx::new(ctx.random_int(type_count).reinterpret_as_uint())
}

///|
pub fn gen_valid_module_with_config(
  rnd : RandomState,
  config : GenValidConfig,
) -> Module {
  let ctx = GenValidContext::new(rnd, config)
  let import_func_count = gen_valid_choose_optional_count(
    ctx,
    config.features.allow_imports,
    config.max_imports,
    config.section_bias.imports_percent,
  )
  let defined_func_count = gen_valid_choose_defined_func_count(ctx)
  let table_count = gen_valid_choose_optional_count(
    ctx,
    config.features.allow_tables,
    config.max_tables,
    config.section_bias.tables_percent,
  )
  let mem_count = gen_valid_choose_optional_count(
    ctx,
    config.features.allow_mems,
    config.max_mems,
    config.section_bias.mems_percent,
  )
  let global_count = gen_valid_choose_optional_count(
    ctx,
    config.features.allow_globals,
    config.max_globals,
    config.section_bias.globals_percent,
  )
  let tag_count = gen_valid_choose_optional_count(
    ctx,
    config.features.allow_tags,
    config.max_tags,
    config.section_bias.tags_percent,
  )
  let elem_count = if table_count > 0 {
    gen_valid_choose_optional_count(
      ctx,
      config.features.allow_elems,
      config.max_elems,
      config.section_bias.elems_percent,
    )
  } else {
    0
  }
  let data_count = if mem_count > 0 {
    gen_valid_choose_optional_count(
      ctx,
      config.features.allow_datas,
      config.max_datas,
      config.section_bias.datas_percent,
    )
  } else {
    0
  }
  let has_start = config.features.allow_start &&
    (
      ctx.config.mode == CoverageForced ||
      gen_valid_roll_percent(ctx, config.section_bias.start_percent)
    )
  let total_type_users = import_func_count + defined_func_count + tag_count
  let max_type_defs = if gen_valid_clamp_non_negative(config.max_type_defs) <= 0 {
    1
  } else {
    gen_valid_clamp_non_negative(config.max_type_defs)
  }
  let type_count = if ctx.config.mode == CoverageForced && total_type_users > 1 {
    1 + ctx.random_int(gen_valid_min_int(max_type_defs, total_type_users - 1))
  } else {
    1 + ctx.random_int(max_type_defs)
  }

  let type_defs : Array[RecType] = []
  let type_params : Array[Array[ValType]] = []
  let type_results : Array[Array[ValType]] = []
  for i = 0; i < type_count; i = i + 1 {
    let params = if i == 0 && has_start { [] } else { gen_param_types(ctx) }
    let results = if i == 0 && (has_start || tag_count > 0) {
      []
    } else {
      gen_result_types(ctx)
    }
    type_params.push(params)
    type_results.push(results)
    type_defs.push(
      RecType::new(SubType::comp_type(CompType::func(params, results))),
    )
  }

  let imports : Array[Import] = []
  for i = 0; i < import_func_count; i = i + 1 {
    let type_idx = gen_valid_pick_type_idx(ctx, type_count)
    imports.push(
      Import::new(
        Name::new("env"),
        Name::new("imported_func_\{i}"),
        ExternType::func(type_idx),
      ),
    )
  }

  let globals : Array[Global] = []
  for _ in 0..<global_count {
    let vt = gen_valid_valtype(ctx)
    let is_mut = ctx.config.mode == CoverageForced || ctx.random_bool()
    globals.push(
      Global::new(GlobalType::new(vt, is_mut), gen_const_expr(ctx, vt)),
    )
  }
  let global_types = globals.map(fn(g) {
    let Global(gt, _) = g
    gt
  })

  let func_type_idxs : Array[TypeIdx] = []
  for i = 0; i < defined_func_count; i = i + 1 {
    func_type_idxs.push(
      if i == 0 && has_start {
        TypeIdx::new(0U)
      } else {
        gen_valid_pick_type_idx(ctx, type_count)
      },
    )
  }

  let first_defined_func_idx = FuncIdx::new(
    import_func_count.reinterpret_as_uint(),
  )

  let tables : Array[Table] = []
  for _ in 0..<table_count {
    tables.push(
      Table::new(
        TableType::new(
          RefType::new(true, HeapType::abs(AbsHeapType::func())),
          Limits::i32(1U, Some(4U)),
        ),
        None,
      ),
    )
  }
  let table_types = tables.map(fn(table) {
    let Table(table_type, _) = table
    table_type
  })

  let mems : Array[MemType] = []
  for _ in 0..<mem_count {
    mems.push(MemType::new(Limits::i32(1U, Some(4U))))
  }

  let func_sigs : Array[GenValidFuncSig] = []
  for i = 0; i < imports.length(); i = i + 1 {
    let Import(_, _, extern_type) = imports[i]
    match extern_type {
      FuncExternType(type_idx) => {
        let type_idx_i = match type_idx {
          TypeIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
          RecIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
        }
        func_sigs.push({
          idx: FuncIdx::new(i.reinterpret_as_uint()),
          type_idx,
          params: type_params[type_idx_i],
          results: type_results[type_idx_i],
        })
      }
      _ => ()
    }
  }
  for i = 0; i < func_type_idxs.length(); i = i + 1 {
    let type_idx = func_type_idxs[i]
    let type_idx_i = match type_idx {
      TypeIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
      RecIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
    }
    func_sigs.push({
      idx: FuncIdx::new((import_func_count + i).reinterpret_as_uint()),
      type_idx,
      params: type_params[type_idx_i],
      results: type_results[type_idx_i],
    })
  }

  let funcs : Array[Func] = []
  for type_idx in func_type_idxs {
    let type_idx_i = match type_idx {
      TypeIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
      RecIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
    }
    funcs.push(
      gen_valid_build_func(
        ctx,
        type_params[type_idx_i],
        type_results[type_idx_i],
        global_types,
        table_types,
        mems,
        func_sigs,
        Some(first_defined_func_idx),
      ),
    )
  }

  let tags : Array[TagType] = []
  for _ in 0..<tag_count {
    tags.push(TagType::new(TypeIdx::new(0U)))
  }

  let total_func_count = import_func_count + defined_func_count

  let elems : Array[Elem] = []
  if table_count > 0 && total_func_count > 0 {
    for _ in 0..<elem_count {
      elems.push(
        Elem::new(
          ElemMode::active(TableIdx::new(0U), gen_valid_active_i32_offset()),
          ElemKind::funcs([first_defined_func_idx]),
        ),
      )
    }
  }

  let datas : Array[Data] = []
  if mem_count > 0 {
    for _ in 0..<data_count {
      datas.push(
        Data::new(
          DataMode::active(MemIdx::new(0U), gen_valid_active_i32_offset()),
          b"gen-valid",
        ),
      )
    }
  }

  let exports : Array[Export] = [
    Export::new(Name::new("main"), ExternIdx::func(first_defined_func_idx)),
  ]
  if table_count > 0 {
    exports.push(
      Export::new(Name::new("table0"), ExternIdx::table(TableIdx::new(0U))),
    )
  }
  if mem_count > 0 {
    exports.push(
      Export::new(Name::new("memory0"), ExternIdx::mem(MemIdx::new(0U))),
    )
  }
  if global_count > 0 {
    exports.push(
      Export::new(Name::new("global0"), ExternIdx::global(GlobalIdx::new(0U))),
    )
  }
  if tag_count > 0 {
    exports.push(
      Export::new(Name::new("tag0"), ExternIdx::tag(TagIdx::new(0U))),
    )
  }

  let mut mod = Module::new().with_type_sec(TypeSec::new(type_defs))
  if !imports.is_empty() {
    mod = mod.with_import_sec(ImportSec::new(imports))
  }
  mod = mod.with_func_sec(FuncSec::new(func_type_idxs))
  if !tables.is_empty() {
    mod = mod.with_table_sec(TableSec::new(tables))
  }
  if !mems.is_empty() {
    mod = mod.with_mem_sec(MemSec::new(mems))
  }
  if !globals.is_empty() {
    mod = mod.with_global_sec(GlobalSec::new(globals))
  }
  if !tags.is_empty() {
    mod = mod.with_tag_sec(TagSec::new(tags))
  }
  if has_start {
    mod = mod.with_start_sec(StartSec::new(first_defined_func_idx))
  }
  if !elems.is_empty() {
    mod = mod.with_elem_sec(ElemSec::new(elems))
  }
  if !datas.is_empty() {
    mod = mod.with_data_cnt_sec(
      DataCntSec::new(U32(datas.length().reinterpret_as_uint())),
    )
  }
  mod = mod.with_code_sec(CodeSec::new(funcs))
  if !datas.is_empty() {
    mod = mod.with_data_sec(DataSec::new(datas))
  }
  mod.with_export_sec(ExportSec::new(exports))
}

///|
pub fn gen_valid_module(rnd : RandomState) -> Module {
  gen_valid_module_with_config(rnd, default_gen_valid_config())
}

///|
fn gen_valid_scan_storage_type(storage : StorageType) -> (Bool, Bool) {
  match storage {
    ValTypeStorageType(vt) => gen_valid_scan_val_type(vt)
    PackTypeStorageType(_) => (false, false)
  }
}

///|
fn gen_valid_scan_field_type(field : FieldType) -> (Bool, Bool) {
  let FieldType(storage, _) = field
  gen_valid_scan_storage_type(storage)
}

///|
fn gen_valid_scan_val_type(vt : ValType) -> (Bool, Bool) {
  match vt {
    VecTypeValType => (false, true)
    RefTypeValType(_) => (true, false)
    _ => (false, false)
  }
}

///|
fn gen_valid_scan_block_type(bt : BlockType) -> (Bool, Bool) {
  match bt {
    ValTypeBlockType(vt) => gen_valid_scan_val_type(vt)
    _ => (false, false)
  }
}

///|
fn gen_valid_scan_comp_type(comp : CompType) -> (Bool, Bool) {
  match comp {
    FuncCompType(params, results) => {
      let mut uses_ref_types = false
      let mut uses_v128 = false
      for vt in params {
        let (has_ref, has_v128) = gen_valid_scan_val_type(vt)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128
      }
      for vt in results {
        let (has_ref, has_v128) = gen_valid_scan_val_type(vt)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128
      }
      (uses_ref_types, uses_v128)
    }
    ArrayCompType(field) => gen_valid_scan_field_type(field)
    StructCompType(fields) => {
      let mut uses_ref_types = false
      let mut uses_v128 = false
      for field in fields {
        let (has_ref, has_v128) = gen_valid_scan_field_type(field)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128
      }
      (uses_ref_types, uses_v128)
    }
  }
}

///|
fn gen_valid_scan_sub_type(subtype : SubType) -> (Bool, Bool) {
  match subtype {
    SubType(_, _, _, comp) | CompTypeSubType(_, comp) =>
      gen_valid_scan_comp_type(comp)
  }
}

///|
fn gen_valid_scan_rec_type(rec_type : RecType) -> (Bool, Bool) {
  match rec_type {
    SingleRecType(subtype) => gen_valid_scan_sub_type(subtype)
    GroupRecType(group) => {
      let mut uses_ref_types = false
      let mut uses_v128 = false
      for subtype in group {
        let (has_ref, has_v128) = gen_valid_scan_sub_type(subtype)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128
      }
      (uses_ref_types, uses_v128)
    }
  }
}

///|
fn gen_valid_merge_instr_facts(
  left : GenValidInstrFacts,
  right : GenValidInstrFacts,
) -> GenValidInstrFacts {
  {
    uses_ref_types: left.uses_ref_types || right.uses_ref_types,
    uses_v128: left.uses_v128 || right.uses_v128,
    has_call: left.has_call || right.has_call,
    has_call_indirect: left.has_call_indirect || right.has_call_indirect,
    control_nodes: left.control_nodes + right.control_nodes,
    branch_ops: left.branch_ops + right.branch_ops,
  }
}

///|
fn gen_valid_scan_expr(expr : Expr) -> GenValidInstrFacts {
  let Expr(instrs) = expr
  let mut facts = GenValidInstrFacts::empty()
  for instr in instrs {
    facts = gen_valid_merge_instr_facts(facts, gen_valid_scan_instr(instr))
  }
  facts
}

///|
fn gen_valid_scan_instr(instr : Instruction) -> GenValidInstrFacts {
  match instr {
    Call(_) | ReturnCall(_) =>
      GenValidInstrFacts::{ ..GenValidInstrFacts::empty(), has_call: true }
    CallIndirect(_, _) | ReturnCallIndirect(_, _) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        has_call_indirect: true,
        branch_ops: 1,
      }
    CallRef(_) | ReturnCallRef(_) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
        has_call_indirect: true,
        branch_ops: 1,
      }
    Br(_) | BrIf(_) | BrTable(_, _) =>
      GenValidInstrFacts::{ ..GenValidInstrFacts::empty(), branch_ops: 1 }
    Block(bt, body) | Loop(bt, body) => {
      let (has_ref, has_v128) = gen_valid_scan_block_type(bt)
      let body_facts = gen_valid_scan_expr(body)
      GenValidInstrFacts::{
        ..body_facts,
        uses_ref_types: body_facts.uses_ref_types || has_ref,
        uses_v128: body_facts.uses_v128 || has_v128,
        control_nodes: body_facts.control_nodes + 1,
      }
    }
    If(bt, then_body, else_body) => {
      let (has_ref, has_v128) = gen_valid_scan_block_type(bt)
      let mut facts = GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: has_ref,
        uses_v128: has_v128,
        control_nodes: 1,
        branch_ops: 1,
      }
      facts = gen_valid_merge_instr_facts(
        facts,
        gen_valid_scan_expr(Expr::new(then_body)),
      )
      match else_body {
        Some(branch) =>
          facts = gen_valid_merge_instr_facts(
            facts,
            gen_valid_scan_expr(Expr::new(branch)),
          )
        None => ()
      }
      facts
    }
    TryTable(bt, _, body) => {
      let (has_ref, has_v128) = gen_valid_scan_block_type(bt)
      let body_facts = gen_valid_scan_expr(body)
      GenValidInstrFacts::{
        ..body_facts,
        uses_ref_types: body_facts.uses_ref_types || has_ref,
        uses_v128: body_facts.uses_v128 || has_v128,
        control_nodes: body_facts.control_nodes + 1,
        branch_ops: body_facts.branch_ops + 1,
      }
    }
    Select(Some(types)) => {
      let mut uses_ref_types = false
      let mut uses_v128 = false
      for vt in types {
        let (has_ref, has_v128) = gen_valid_scan_val_type(vt)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128
      }
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types,
        uses_v128,
      }
    }
    RefNull(_) | RefFunc(_) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
      }
    V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      GenValidInstrFacts::{ ..GenValidInstrFacts::empty(), uses_v128: true }
    _ => GenValidInstrFacts::empty()
  }
}

///|
pub fn gen_valid_feature_facts(
  mod : Module,
  mode : GenValidMode,
) -> GenValidFeatureFacts {
  let mut has_imports = false
  let mut has_func_exports = false
  let mut has_table_exports = false
  let mut has_mem_exports = false
  let mut has_global_exports = false
  let mut has_tag_exports = false
  let mut has_tables = false
  let mut has_mems = false
  let mut has_globals = false
  let mut has_tags = false
  let mut has_elems = false
  let mut has_datas = false
  let has_start = mod.start_sec is Some(_)
  let has_data_count = mod.data_cnt_sec is Some(_)
  let mut uses_ref_types = false
  let mut uses_v128 = false
  let mut has_call = false
  let mut has_call_indirect = false
  let mut control_nodes = 0
  let mut branch_ops = 0

  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        let (has_ref, has_v128_fact) = gen_valid_scan_rec_type(rec_type)
        uses_ref_types = uses_ref_types || has_ref
        uses_v128 = uses_v128 || has_v128_fact
      }
    None => ()
  }

  match mod.import_sec {
    Some(ImportSec(imports)) =>
      if !imports.is_empty() {
        has_imports = true
        for imp in imports {
          let Import(_, _, extern_type) = imp
          match extern_type {
            FuncExternType(_) => ()
            TableExternType(table_type) => {
              has_tables = true
              let TableType(ref_type, _) = table_type
              uses_ref_types = uses_ref_types || true
              uses_v128 = uses_v128 || false
              ignore(ref_type)
            }
            MemExternType(_) => has_mems = true
            GlobalExternType(global_type) => {
              has_globals = true
              let GlobalType(vt, _) = global_type
              let (has_ref, has_v128_fact) = gen_valid_scan_val_type(vt)
              uses_ref_types = uses_ref_types || has_ref
              uses_v128 = uses_v128 || has_v128_fact
            }
            TagExternType(_) => has_tags = true
          }
        }
      }
    None => ()
  }

  match mod.table_sec {
    Some(TableSec(tables)) if !tables.is_empty() => {
      has_tables = true
      uses_ref_types = true
    }
    _ => ()
  }
  match mod.mem_sec {
    Some(MemSec(mems)) if !mems.is_empty() => has_mems = true
    _ => ()
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      if !globals.is_empty() {
        has_globals = true
        for global in globals {
          let Global(global_type, expr) = global
          let GlobalType(vt, _) = global_type
          let (has_ref, has_v128_fact) = gen_valid_scan_val_type(vt)
          let expr_facts = gen_valid_scan_expr(expr)
          uses_ref_types = uses_ref_types ||
            has_ref ||
            expr_facts.uses_ref_types
          uses_v128 = uses_v128 || has_v128_fact || expr_facts.uses_v128
          has_call = has_call || expr_facts.has_call
          has_call_indirect = has_call_indirect || expr_facts.has_call_indirect
          control_nodes += expr_facts.control_nodes
          branch_ops += expr_facts.branch_ops
        }
      }
    None => ()
  }
  match mod.tag_sec {
    Some(TagSec(tags)) if !tags.is_empty() => has_tags = true
    _ => ()
  }
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export in exports {
        let Export(_, idx) = export
        match idx {
          FuncExternIdx(_) => has_func_exports = true
          TableExternIdx(_) => has_table_exports = true
          MemExternIdx(_) => has_mem_exports = true
          GlobalExternIdx(_) => has_global_exports = true
          TagExternIdx(_) => has_tag_exports = true
        }
      }
    None => ()
  }
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      if !elems.is_empty() {
        has_elems = true
        uses_ref_types = true
        for elem in elems {
          let Elem(mode, kind) = elem
          match mode {
            Active(_, expr) => {
              let facts = gen_valid_scan_expr(expr)
              uses_ref_types = uses_ref_types || facts.uses_ref_types
              uses_v128 = uses_v128 || facts.uses_v128
              has_call = has_call || facts.has_call
              has_call_indirect = has_call_indirect || facts.has_call_indirect
              control_nodes += facts.control_nodes
              branch_ops += facts.branch_ops
            }
            _ => ()
          }
          match kind {
            FuncsElemKind(_) => ()
            FuncExprsElemKind(exprs) =>
              for expr in exprs {
                let facts = gen_valid_scan_expr(expr)
                uses_ref_types = uses_ref_types || facts.uses_ref_types
                uses_v128 = uses_v128 || facts.uses_v128
                has_call = has_call || facts.has_call
                has_call_indirect = has_call_indirect || facts.has_call_indirect
                control_nodes += facts.control_nodes
                branch_ops += facts.branch_ops
              }
            TypedExprsElemKind(rt, exprs) => {
              ignore(rt)
              uses_ref_types = true
              for expr in exprs {
                let facts = gen_valid_scan_expr(expr)
                uses_ref_types = uses_ref_types || facts.uses_ref_types
                uses_v128 = uses_v128 || facts.uses_v128
                has_call = has_call || facts.has_call
                has_call_indirect = has_call_indirect || facts.has_call_indirect
                control_nodes += facts.control_nodes
                branch_ops += facts.branch_ops
              }
            }
          }
        }
      }
    None => ()
  }
  match mod.data_sec {
    Some(DataSec(datas)) =>
      if !datas.is_empty() {
        has_datas = true
        for data in datas {
          let Data(mode, _) = data
          match mode {
            Active(_, expr) => {
              let facts = gen_valid_scan_expr(expr)
              uses_ref_types = uses_ref_types || facts.uses_ref_types
              uses_v128 = uses_v128 || facts.uses_v128
              has_call = has_call || facts.has_call
              has_call_indirect = has_call_indirect || facts.has_call_indirect
              control_nodes += facts.control_nodes
              branch_ops += facts.branch_ops
            }
            Passive => ()
          }
        }
      }
    None => ()
  }
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(locals, expr) = func
        for local_vt in locals.iter() {
          let (has_ref, has_v128_fact) = gen_valid_scan_val_type(local_vt)
          uses_ref_types = uses_ref_types || has_ref
          uses_v128 = uses_v128 || has_v128_fact
        }
        let facts = gen_valid_scan_expr(expr)
        uses_ref_types = uses_ref_types || facts.uses_ref_types
        uses_v128 = uses_v128 || facts.uses_v128
        has_call = has_call || facts.has_call
        has_call_indirect = has_call_indirect || facts.has_call_indirect
        control_nodes += facts.control_nodes
        branch_ops += facts.branch_ops
      }
    None => ()
  }

  {
    mode,
    has_imports,
    has_func_exports,
    has_table_exports,
    has_mem_exports,
    has_global_exports,
    has_tag_exports,
    has_start,
    lacks_start: !has_start,
    has_tables,
    has_mems,
    has_globals,
    has_tags,
    has_elems,
    has_datas,
    has_data_count,
    uses_ref_types,
    uses_v128,
    has_call,
    has_call_indirect,
    has_branch_heavy_control: branch_ops > 0 || control_nodes >= 2,
  }
}
