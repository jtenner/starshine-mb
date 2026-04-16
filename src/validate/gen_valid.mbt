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
    allow_ref_types: false,
    allow_v128: false,
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
    func_exports: self.func_exports + gen_valid_bool_count(facts.has_func_exports),
    table_exports: self.table_exports + gen_valid_bool_count(facts.has_table_exports),
    mem_exports: self.mem_exports + gen_valid_bool_count(facts.has_mem_exports),
    global_exports: self.global_exports + gen_valid_bool_count(facts.has_global_exports),
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
    call_indirect: self.call_indirect + gen_valid_bool_count(facts.has_call_indirect),
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
struct GenValidInstrFacts {
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
  if flag { 1 } else { 0 }
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
  if left < right { left } else { right }
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
  let count = ctx.random_int(gen_valid_clamp_non_negative(ctx.config.max_params) + 1)
  let params : Array[ValType] = []
  for _ in 0..<count {
    params.push(gen_valid_valtype(ctx))
  }
  params
}

///|
fn gen_local_types(ctx : GenValidContext) -> Array[ValType] {
  let count = ctx.random_int(gen_valid_clamp_non_negative(ctx.config.max_locals) + 1)
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
fn append_value_instrs(
  out : Array[Instruction],
  ctx : GenValidContext,
  vt : ValType,
  local_types : Array[ValType],
  prefer_local? : Bool = true,
) -> Unit {
  if prefer_local {
    match gen_matching_local_idx(local_types, vt) {
      Some(idx) => {
        out.push(Instruction::local_get(idx))
        return
      }
      None => ()
    }
  }
  out.push(gen_const_instr(ctx, vt))
}

///|
fn append_void_stmt(
  out : Array[Instruction],
  ctx : GenValidContext,
  local_types : Array[ValType],
  globals : Array[GlobalType],
) -> Unit {
  let branchy = ctx.config.features.allow_branch_heavy_control
  match ctx.random_int(if branchy { 6 } else { 4 }) {
    0 => out.push(Instruction::nop())
    1 => {
      let vt = gen_valid_valtype(ctx)
      append_value_instrs(out, ctx, vt, local_types, prefer_local=false)
      out.push(Instruction::drop())
    }
    2 =>
      if local_types.is_empty() {
        out.push(Instruction::nop())
      } else {
        let idx = ctx.random_int(local_types.length())
        let vt = local_types[idx]
        append_value_instrs(out, ctx, vt, local_types, prefer_local=false)
        out.push(
          Instruction::local_set(LocalIdx::new(idx.reinterpret_as_uint())),
        )
      }
    3 =>
      if local_types.is_empty() {
        out.push(Instruction::nop())
      } else {
        let idx = ctx.random_int(local_types.length())
        let vt = local_types[idx]
        append_value_instrs(out, ctx, vt, local_types, prefer_local=false)
        out.push(
          Instruction::local_tee(LocalIdx::new(idx.reinterpret_as_uint())),
        )
        out.push(Instruction::drop())
      }
    4 => {
      out.push(
        Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
      )
      out.push(
        Instruction::if_(
          BlockType::void_(),
          [Instruction::nop()],
          Some([Instruction::nop()]),
        ),
      )
    }
    _ =>
      if globals.is_empty() {
        out.push(
          Instruction::block(
            BlockType::void_(),
            Expr::new([Instruction::nop()]),
          ),
        )
      } else {
        let idx = ctx.random_int(globals.length())
        out.push(
          Instruction::global_get(GlobalIdx::new(idx.reinterpret_as_uint())),
        )
        out.push(Instruction::drop())
      }
  }
}

///|
pub fn gen_valid_tfunc(
  ctx : GenValidContext,
  accepts : Array[ValType],
  returns : Array[ValType],
) -> Func {
  let locals = gen_local_types(ctx)
  let all_local_types = gen_all_local_types(accepts, locals)
  let body_instrs : Array[Instruction] = []
  let stmt_count = 1 +
    ctx.random_int(gen_valid_clamp_non_negative(ctx.config.max_body_statements))
  for _ in 0..<stmt_count {
    append_void_stmt(body_instrs, ctx, all_local_types, [])
  }
  for ret in returns {
    append_value_instrs(body_instrs, ctx, ret, all_local_types)
  }
  Func::new(Locals::from_types(locals), Expr::new(body_instrs))
}

///|
pub fn gen_valid_module_with_config(
  rnd : RandomState,
  config : GenValidConfig,
) -> Module {
  let ctx = GenValidContext::new(rnd, config)
  let type_defs : Array[RecType] = []
  let func_type_idxs : Array[TypeIdx] = []
  let funcs : Array[Func] = []
  let globals : Array[Global] = []
  let max_funcs = gen_valid_min_int(
    gen_valid_clamp_non_negative(config.max_defined_funcs),
    gen_valid_clamp_non_negative(config.max_type_defs),
  )
  let func_count = if max_funcs <= 1 {
    1
  } else {
    1 + ctx.random_int(max_funcs)
  }
  let global_count = if !config.features.allow_globals || config.max_globals <= 0 {
    0
  } else if config.mode == CoverageForced {
    1 + ctx.random_int(gen_valid_clamp_non_negative(config.max_globals))
  } else if gen_valid_roll_percent(ctx, config.section_bias.globals_percent) {
    1 + ctx.random_int(gen_valid_clamp_non_negative(config.max_globals))
  } else {
    0
  }
  for _ in 0..<global_count {
    let vt = gen_valid_valtype(ctx)
    globals.push(
      Global::new(GlobalType::new(vt, false), gen_const_expr(ctx, vt)),
    )
  }
  let global_types = globals.map(fn(g) {
    let Global(gt, _) = g
    gt
  })
  for i = 0; i < func_count; i = i + 1 {
    let params = gen_param_types(ctx)
    let results = gen_result_types(ctx)
    type_defs.push(
      RecType::new(SubType::comp_type(CompType::func(params, results))),
    )
    func_type_idxs.push(TypeIdx::new(i.reinterpret_as_uint()))
    let local_types = gen_local_types(ctx)
    let all_local_types = gen_all_local_types(params, local_types)
    let body_instrs : Array[Instruction] = []
    let stmt_count = 1 +
      ctx.random_int(gen_valid_clamp_non_negative(config.max_body_statements))
    for _ in 0..<stmt_count {
      append_void_stmt(body_instrs, ctx, all_local_types, global_types)
    }
    for ret in results {
      append_value_instrs(body_instrs, ctx, ret, all_local_types)
    }
    funcs.push(
      Func::new(Locals::from_types(local_types), Expr::new(body_instrs)),
    )
  }
  let mod = Module::new()
    .with_type_sec(TypeSec::new(type_defs))
    .with_func_sec(FuncSec::new(func_type_idxs))
    .with_code_sec(CodeSec::new(funcs))
  let mod = if globals.is_empty() {
    mod
  } else {
    mod.with_global_sec(GlobalSec::new(globals))
  }
  mod.with_export_sec(
    ExportSec::new([
      Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
    ]),
  )
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
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        has_call: true,
      }
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
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        branch_ops: 1,
      }
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
      facts = gen_valid_merge_instr_facts(facts, gen_valid_scan_expr(Expr::new(then_body)))
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
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_v128: true,
      }
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
          uses_ref_types = uses_ref_types || has_ref || expr_facts.uses_ref_types
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
