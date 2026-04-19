///|
pub enum GenValidMode {
  Natural
  CoverageForced
} derive(Eq, Debug)

///|
pub impl Show for GenValidMode with output(self, logger) {
  match self {
    Natural => logger.write_string("Natural")
    CoverageForced => logger.write_string("CoverageForced")
  }
}

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
} derive(Eq, Debug)

///|
pub impl Show for GenValidSectionBias with output(self, logger) {
  logger.write_string("GenValidSectionBias {imports_percent: ")
  self.imports_percent.output(logger)
  logger.write_string(", tables_percent: ")
  self.tables_percent.output(logger)
  logger.write_string(", mems_percent: ")
  self.mems_percent.output(logger)
  logger.write_string(", globals_percent: ")
  self.globals_percent.output(logger)
  logger.write_string(", tags_percent: ")
  self.tags_percent.output(logger)
  logger.write_string(", start_percent: ")
  self.start_percent.output(logger)
  logger.write_string(", elems_percent: ")
  self.elems_percent.output(logger)
  logger.write_string(", datas_percent: ")
  self.datas_percent.output(logger)
  logger.write_char('}')
}

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
} derive(Eq, Debug)

///|
pub impl Show for GenValidFeatureToggles with output(self, logger) {
  logger.write_string(", allow_imports:")
  self.allow_imports.output(logger)
  logger.write_string(", allow_tables:")
  self.allow_tables.output(logger)
  logger.write_string(", allow_mems:")
  self.allow_mems.output(logger)
  logger.write_string(", allow_globals:")
  self.allow_globals.output(logger)
  logger.write_string(", allow_tags:")
  self.allow_tags.output(logger)
  logger.write_string(", allow_start:")
  self.allow_start.output(logger)
  logger.write_string(", allow_elems:")
  self.allow_elems.output(logger)
  logger.write_string(", allow_datas:")
  self.allow_datas.output(logger)
  logger.write_string(", allow_ref_types:")
  self.allow_ref_types.output(logger)
  logger.write_string(", allow_v128:")
  self.allow_v128.output(logger)
  logger.write_string(", allow_calls:")
  self.allow_calls.output(logger)
  logger.write_string(", allow_call_indirect:")
  self.allow_call_indirect.output(logger)
  logger.write_string(", allow_branch_heavy_control:")
  self.allow_branch_heavy_control.output(logger)
}

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
} derive(Eq, Debug)

///|
pub impl Show for GenValidConfig with output(self, logger) {
  logger.write_string("GenValidConfig {mode: ")
  self.mode.output(logger)
  logger.write_string(", max_type_defs: ")
  self.max_type_defs.output(logger)
  logger.write_string(", max_imports: ")
  self.max_imports.output(logger)
  logger.write_string(", max_defined_funcs: ")
  self.max_defined_funcs.output(logger)
  logger.write_string(", max_tables: ")
  self.max_tables.output(logger)
  logger.write_string(", max_mems: ")
  self.max_mems.output(logger)
  logger.write_string(", max_globals: ")
  self.max_globals.output(logger)
  logger.write_string(", max_tags: ")
  self.max_tags.output(logger)
  logger.write_string(", max_elems: ")
  self.max_elems.output(logger)
  logger.write_string(", max_datas: ")
  self.max_datas.output(logger)
  logger.write_string(", max_params: ")
  self.max_params.output(logger)
  logger.write_string(", max_results: ")
  self.max_results.output(logger)
  logger.write_string(", max_locals: ")
  self.max_locals.output(logger)
  logger.write_string(", max_body_statements: ")
  self.max_body_statements.output(logger)
  logger.write_string(", max_body_depth: ")
  self.max_body_depth.output(logger)
  logger.write_string(", section_bias: ")
  self.section_bias.output(logger)
  logger.write_string(", features: ")
  self.features.output(logger)
  logger.write_char('}')
}

///|
pub fn GenValidConfig::natural_default() -> GenValidConfig {
  {
    mode: Natural,
    max_type_defs: 8,
    max_imports: 5,
    max_defined_funcs: 4,
    max_tables: 3,
    max_mems: 2,
    max_globals: 4,
    max_tags: 2,
    max_elems: 3,
    max_datas: 3,
    max_params: 2,
    max_results: 1,
    max_locals: 5,
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
    max_type_defs: 14,
    max_imports: 6,
    max_tables: 3,
    max_mems: 2,
    max_globals: 4,
    max_tags: 2,
    max_elems: 3,
    max_datas: 2,
    max_locals: 6,
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
} derive(Eq, Debug)

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
} derive(Eq, Debug)

///|
pub impl Show for GenValidFeatureStats with output(self, logger) {
  logger.write_string("GenValidFeatureStats {mode: ")
  self.mode.output(logger)
  logger.write_string(", modules: ")
  self.modules.output(logger)
  logger.write_string(", imports: ")
  self.imports.output(logger)
  logger.write_string(", func_exports: ")
  self.func_exports.output(logger)
  logger.write_string(", table_exports: ")
  self.table_exports.output(logger)
  logger.write_string(", mem_exports: ")
  self.mem_exports.output(logger)
  logger.write_string(", global_exports: ")
  self.global_exports.output(logger)
  logger.write_string(", tag_exports: ")
  self.tag_exports.output(logger)
  logger.write_string(", starts: ")
  self.starts.output(logger)
  logger.write_string(", lacks_start: ")
  self.lacks_start.output(logger)
  logger.write_string(", tables: ")
  self.tables.output(logger)
  logger.write_string(", mems: ")
  self.mems.output(logger)
  logger.write_string(", globals: ")
  self.globals.output(logger)
  logger.write_string(", tags: ")
  self.tags.output(logger)
  logger.write_string(", elems: ")
  self.elems.output(logger)
  logger.write_string(", datas: ")
  self.datas.output(logger)
  logger.write_string(", data_count: ")
  self.data_count.output(logger)
  logger.write_string(", ref_types: ")
  self.ref_types.output(logger)
  logger.write_string(", v128: ")
  self.v128.output(logger)
  logger.write_string(", calls: ")
  self.calls.output(logger)
  logger.write_string(", call_indirect: ")
  self.call_indirect.output(logger)
  logger.write_string(", branch_heavy_control: ")
  self.branch_heavy_control.output(logger)
  logger.write_char('}')
}

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
fn gen_valid_ref_valtype_pool(
  extra_ref_types : Array[ValType],
) -> Array[ValType] {
  let refs : Array[ValType] = [
    ValType::funcref(),
    ValType::externref(),
    ValType::stringref(),
    ValType::ref_null_exn(),
    ValType::ref_type(RefType::abs(AbsHeapType::any())),
    ValType::ref_type(RefType::abs(AbsHeapType::eq())),
    ValType::ref_type(RefType::abs(AbsHeapType::i31())),
    ValType::ref_type(RefType::abs(AbsHeapType::struct_())),
    ValType::ref_type(RefType::abs(AbsHeapType::array())),
  ]
  for vt in extra_ref_types {
    refs.push(vt)
  }
  refs
}

///|
pub fn gen_valid_valtype_with_extra_refs(
  ctx : GenValidContext,
  extra_ref_types : Array[ValType],
) -> ValType {
  let scalar_choice_count = 4 +
    gen_valid_bool_count(ctx.config.features.allow_v128)
  let ref_pool = if ctx.config.features.allow_ref_types {
    gen_valid_ref_valtype_pool(extra_ref_types)
  } else {
    []
  }
  let choice = ctx.random_int(scalar_choice_count + ref_pool.length())
  if choice == 0 {
    ValType::i32()
  } else if choice == 1 {
    ValType::i64()
  } else if choice == 2 {
    ValType::f32()
  } else if choice == 3 {
    ValType::f64()
  } else if ctx.config.features.allow_v128 && choice == 4 {
    ValType::v128()
  } else if ref_pool.is_empty() {
    ValType::i32()
  } else {
    ref_pool[choice - scalar_choice_count]
  }
}

///|
pub fn gen_valid_valtype(ctx : GenValidContext) -> ValType {
  gen_valid_valtype_with_extra_refs(ctx, [])
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
    _ if vt == ValType::stringref() => Instruction::string_const(b"gen-valid")
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
fn gen_local_types(
  ctx : GenValidContext,
  extra_ref_types? : Array[ValType] = [],
) -> Array[ValType] {
  let count = ctx.random_int(
    gen_valid_clamp_non_negative(ctx.config.max_locals) + 1,
  )
  let locals : Array[ValType] = []
  for _ in 0..<count {
    locals.push(gen_valid_valtype_with_extra_refs(ctx, extra_ref_types))
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
fn gen_valid_gc_type_plan_empty() -> GenValidGcTypePlan {
  {
    struct_type_idxs: [],
    array_type_idxs: [],
    concrete_ref_types: [],
    bulk_data_array_idx: None,
    bulk_elem_array_idx: None,
    bulk_elem_ref_type: None,
    descriptor_struct_idx: None,
    descriptor_type_idx: None,
    string_wtf16_array_idx: None,
    string_utf8_array_idx: None,
    rec_group_count: 0,
  }
}

///|
fn gen_valid_gc_type_field_ref(type_idx : TypeIdx) -> ValType {
  ValType::ref_type(RefType::new(true, HeapType::new(type_idx)))
}

///|
fn gen_valid_gc_type_defs(
  ctx : GenValidContext,
  next_type_idx : Int,
  remaining_type_budget : Int,
) -> (Array[RecType], GenValidGcTypePlan) {
  if !ctx.config.features.allow_ref_types || remaining_type_budget <= 0 {
    return ([], gen_valid_gc_type_plan_empty())
  }
  if ctx.config.mode != CoverageForced && ctx.random_int(3) != 0 {
    return ([], gen_valid_gc_type_plan_empty())
  }

  let defs : Array[RecType] = []
  let mut plan = gen_valid_gc_type_plan_empty()
  plan.concrete_ref_types.push(ValType::stringref())
  plan.concrete_ref_types.push(ValType::ref_null_exn())
  let mut type_idx_cursor = next_type_idx

  let want_struct = ctx.config.mode == CoverageForced || ctx.random_int(4) != 0
  let want_array = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) != 0)
  let want_descriptor_group = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0)
  let want_elem_array = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0)
  let want_string_wtf16_array = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0)
  let want_string_utf8_array = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0)
  let want_group = remaining_type_budget - defs.length() > 0 &&
    (ctx.config.mode == CoverageForced || ctx.random_int(4) == 0)

  if want_struct && defs.length() < remaining_type_budget {
    let struct_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::struct_([
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
            FieldType::new(
              StorageType::val_type(
                ValType::ref_type(RefType::abs(AbsHeapType::eq())),
              ),
              Const,
            ),
          ]),
        ),
      ),
    )
    plan.struct_type_idxs.push(struct_idx)
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(struct_idx))
    type_idx_cursor += 1
  }

  if want_array && defs.length() < remaining_type_budget {
    let array_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
          ),
        ),
      ),
    )
    plan.array_type_idxs.push(array_idx)
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(array_idx))
    plan = { ..plan, bulk_data_array_idx: Some(array_idx) }
    type_idx_cursor += 1
  }

  if want_descriptor_group && defs.length() < remaining_type_budget {
    let described_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    let descriptor_idx = TypeIdx::new((type_idx_cursor + 1).reinterpret_as_uint())
    defs.push(
      RecType::group([
        SubType::comp_type(
          CompType::struct_([]),
          metadata=TypeMetadata::new(descriptor=Some(TypeIdx::rec(1))),
        ),
        SubType::comp_type(
          CompType::struct_([]),
          metadata=TypeMetadata::new(describes=Some(TypeIdx::rec(0))),
        ),
      ]),
    )
    plan = {
      ..plan,
      descriptor_struct_idx: Some(described_idx),
      descriptor_type_idx: Some(descriptor_idx),
      rec_group_count: plan.rec_group_count + 1,
    }
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(described_idx))
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(descriptor_idx))
    type_idx_cursor += 2
  }

  if want_elem_array && defs.length() < remaining_type_budget {
    let elem_array_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    let elem_ref_type = match plan.descriptor_type_idx {
      Some(descriptor_idx) => RefType::new(true, HeapType::new(descriptor_idx))
      None => RefType::abs(AbsHeapType::eq())
    }
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(
              StorageType::val_type(ValType::ref_type(elem_ref_type)),
              Var,
            ),
          ),
        ),
      ),
    )
    plan.array_type_idxs.push(elem_array_idx)
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(elem_array_idx))
    plan = {
      ..plan,
      bulk_elem_array_idx: Some(elem_array_idx),
      bulk_elem_ref_type: Some(elem_ref_type),
    }
    type_idx_cursor += 1
  }

  if want_string_wtf16_array && defs.length() < remaining_type_budget {
    let string_wtf16_array_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(
              StorageType::pack_type(PackType::i16()),
              Var,
            ),
          ),
        ),
      ),
    )
    plan = { ..plan, string_wtf16_array_idx: Some(string_wtf16_array_idx) }
    plan.array_type_idxs.push(string_wtf16_array_idx)
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(string_wtf16_array_idx))
    type_idx_cursor += 1
  }

  if want_string_utf8_array && defs.length() < remaining_type_budget {
    let string_utf8_array_idx = TypeIdx::new(type_idx_cursor.reinterpret_as_uint())
    defs.push(
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(
              StorageType::pack_type(PackType::i8()),
              Var,
            ),
          ),
        ),
      ),
    )
    plan = { ..plan, string_utf8_array_idx: Some(string_utf8_array_idx) }
    plan.array_type_idxs.push(string_utf8_array_idx)
    plan.concrete_ref_types.push(gen_valid_gc_type_field_ref(string_utf8_array_idx))
    type_idx_cursor += 1
  }

  if want_group && defs.length() < remaining_type_budget {
    defs.push(
      RecType::group([
        SubType::comp_type(
          CompType::struct_([
            FieldType::new(StorageType::val_type(ValType::i64()), Const),
          ]),
        ),
        SubType::comp_type(
          CompType::array(
            FieldType::new(StorageType::val_type(ValType::i32()), Var),
          ),
        ),
      ]),
    )
    plan = { ..plan, rec_group_count: plan.rec_group_count + 1 }
  }

  (defs, plan)
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
fn gen_valid_contains_type_idx(
  type_idxs : Array[TypeIdx],
  target : TypeIdx,
) -> Bool {
  for type_idx in type_idxs {
    if type_idx == target {
      return true
    }
  }
  false
}

///|
fn gen_valid_callable_by_idx(
  funcs : Array[GenValidFuncSig],
  func_idx : FuncIdx,
) -> GenValidFuncSig? {
  for func in funcs {
    if func.idx == func_idx {
      return Some(func)
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
priv struct GenValidImportPlan {
  func_count : Int
  table_count : Int
  mem_count : Int
  global_count : Int
  tag_count : Int
}

///|
priv struct GenValidGcTypePlan {
  struct_type_idxs : Array[TypeIdx]
  array_type_idxs : Array[TypeIdx]
  concrete_ref_types : Array[ValType]
  bulk_data_array_idx : TypeIdx?
  bulk_elem_array_idx : TypeIdx?
  bulk_elem_ref_type : RefType?
  descriptor_struct_idx : TypeIdx?
  descriptor_type_idx : TypeIdx?
  string_wtf16_array_idx : TypeIdx?
  string_utf8_array_idx : TypeIdx?
  rec_group_count : Int
}

///|
priv struct GenValidBodyEnv {
  local_types : Array[ValType]
  globals : Array[GlobalType]
  tables : Array[TableType]
  mems : Array[MemType]
  tags : Array[TagType]
  funcs : Array[GenValidFuncSig]
  data_idxs : Array[DataIdx]
  elem_idxs : Array[ElemIdx]
  passive_elem_idxs : Array[ElemIdx]
  bulk_elem_seed_idx : ElemIdx?
  gc_type_plan : GenValidGcTypePlan
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
fn gen_valid_pick_func_idx(
  ctx : GenValidContext,
  total_func_count : Int,
  preferred_idx : FuncIdx,
) -> FuncIdx {
  if total_func_count <= 0 {
    preferred_idx
  } else if ctx.config.mode == CoverageForced || ctx.random_int(3) == 0 {
    preferred_idx
  } else {
    FuncIdx::new(ctx.random_int(total_func_count).reinterpret_as_uint())
  }
}

///|
fn gen_valid_funcref_expr(ctx : GenValidContext, func_idx : FuncIdx) -> Expr {
  if ctx.config.mode == CoverageForced || ctx.random_int(4) != 0 {
    Expr::new([Instruction::ref_func(func_idx)])
  } else {
    Expr::new([
      Instruction::ref_null(RefType::abs(AbsHeapType::func()).get_heap_type()),
    ])
  }
}

///|
fn gen_valid_elem_ref_expr(
  ctx : GenValidContext,
  rt : RefType,
  func_idx? : FuncIdx = FuncIdx::new(0U),
) -> Expr {
  if ValType::ref_type(rt) == ValType::funcref() {
    gen_valid_funcref_expr(ctx, func_idx)
  } else {
    Expr::new([Instruction::ref_null(rt.get_heap_type())])
  }
}

///|
fn gen_valid_append_memory_bulk_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Bool {
  if env.mems.is_empty() {
    return false
  }
  let mem_idx = MemIdx::new(0U)
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::memory_copy(mem_idx, mem_idx))

  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::memory_fill(mem_idx))

  if !env.data_idxs.is_empty() {
    let data_idx = env.data_idxs[0]
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::memory_init(data_idx, mem_idx))
    out.push(Instruction::data_drop(data_idx))
  }
  ignore(ctx)
  true
}

///|
fn gen_valid_append_table_bulk_ops(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Bool {
  if env.tables.is_empty() {
    return false
  }
  let table_idx = TableIdx::new(0U)
  let TableType(rt, _) = env.tables[0]

  out.push(Instruction::i32_const(I32(0)))
  gen_valid_append_table_ref_value(out, ctx, env, rt)
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::table_fill(table_idx))

  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::table_copy(table_idx, table_idx))

  if !env.passive_elem_idxs.is_empty() {
    let elem_idx = env.passive_elem_idxs[0]
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::table_init(elem_idx, table_idx))
    out.push(Instruction::elem_drop(elem_idx))
  }
  true
}

///|
fn gen_valid_append_array_data_seed_instrs(
  out : Array[Instruction],
  env : GenValidBodyEnv,
) -> Bool {
  if env.data_idxs.is_empty() {
    return false
  }
  match env.gc_type_plan.bulk_data_array_idx {
    Some(array_idx) => {
      let data_idx = env.data_idxs[0]
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::array_new_data(array_idx, data_idx))
      true
    }
    None => false
  }
}

///|
fn gen_valid_append_array_elem_seed_instrs(
  out : Array[Instruction],
  env : GenValidBodyEnv,
) -> Bool {
  match (env.gc_type_plan.bulk_elem_array_idx, env.bulk_elem_seed_idx) {
    (Some(array_idx), Some(elem_idx)) => {
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::array_new_elem(array_idx, elem_idx))
      true
    }
    _ => false
  }
}

///|
fn gen_valid_append_array_data_init_instrs(
  out : Array[Instruction],
  env : GenValidBodyEnv,
) -> Bool {
  if env.data_idxs.is_empty() {
    return false
  }
  match env.gc_type_plan.bulk_data_array_idx {
    Some(array_idx) => {
      let data_idx = env.data_idxs[0]
      out.push(Instruction::i32_const(I32(1)))
      out.push(Instruction::array_new_default(array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::array_init_data(array_idx, data_idx))
      true
    }
    None => false
  }
}

///|
fn gen_valid_append_array_elem_init_instrs(
  out : Array[Instruction],
  env : GenValidBodyEnv,
) -> Bool {
  match (env.gc_type_plan.bulk_elem_array_idx, env.bulk_elem_seed_idx) {
    (Some(array_idx), Some(elem_idx)) => {
      out.push(Instruction::i32_const(I32(1)))
      out.push(Instruction::array_new_default(array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::array_init_elem(array_idx, elem_idx))
      true
    }
    _ => false
  }
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
      if vt == ValType::stringref() {
        match (
          env.gc_type_plan.string_wtf16_array_idx,
          env.gc_type_plan.string_utf8_array_idx,
        ) {
          (Some(string_wtf16_array_idx), _) if ctx.random_int(3) == 0 => {
            out.push(Instruction::i32_const(I32(4)))
            out.push(Instruction::array_new_default(string_wtf16_array_idx))
            out.push(Instruction::i32_const(I32(0)))
            out.push(Instruction::i32_const(I32(2)))
            out.push(Instruction::string_new_wtf16_array())
            return
          }
          (_, Some(string_utf8_array_idx)) if ctx.random_int(3) == 0 => {
            out.push(Instruction::i32_const(I32(16)))
            out.push(Instruction::array_new_default(string_utf8_array_idx))
            out.push(Instruction::i32_const(I32(0)))
            out.push(Instruction::i32_const(I32(4)))
            out.push(
              if ctx.random_bool() {
                Instruction::string_new_lossy_utf8_array()
              } else {
                Instruction::string_new_wtf8_array()
              },
            )
            return
          }
          _ => ()
        }
      }
      if vt == ValType::ref_null_exn() && !env.tags.is_empty() && ctx.random_int(3) == 0 {
        let tag_idx = TagIdx::new(0U)
        out.push(
          Instruction::try_table(
            BlockType::val_type(vt),
            [if ctx.random_bool() {
              Catch::ref_(tag_idx, LabelIdx::new(0U))
            } else {
              Catch::all_ref(LabelIdx::new(0U))
            }],
            Expr::new([Instruction::throw_(tag_idx)]),
          ),
        )
        return
      }
      match heap_type {
        HeapType(type_idx) => {
          match (
            env.gc_type_plan.descriptor_struct_idx,
            env.gc_type_plan.descriptor_type_idx,
          ) {
            (Some(described_idx), Some(descriptor_idx)) if type_idx == described_idx &&
              ctx.random_int(3) == 0 => {
              out.push(Instruction::struct_new_default(descriptor_idx))
              out.push(Instruction::struct_new_default_desc(described_idx))
              return
            }
            (Some(_described_idx), Some(descriptor_idx)) if type_idx == descriptor_idx &&
              ctx.random_int(3) == 0 => {
              out.push(Instruction::struct_new_default(descriptor_idx))
              return
            }
            _ => ()
          }
          if gen_valid_contains_type_idx(
              env.gc_type_plan.struct_type_idxs,
              type_idx,
            ) &&
            ctx.random_int(3) == 0 {
            out.push(Instruction::struct_new_default(type_idx))
            return
          }
          match env.gc_type_plan.bulk_data_array_idx {
            Some(array_idx) if type_idx == array_idx && ctx.random_int(4) == 0 &&
              gen_valid_append_array_data_seed_instrs(out, env) => return
            _ => ()
          }
          match env.gc_type_plan.bulk_elem_array_idx {
            Some(array_idx) if type_idx == array_idx && ctx.random_int(4) == 0 &&
              gen_valid_append_array_elem_seed_instrs(out, env) => return
            _ => ()
          }
          if gen_valid_contains_type_idx(
              env.gc_type_plan.array_type_idxs,
              type_idx,
            ) &&
            ctx.random_int(3) == 0 {
            out.push(Instruction::i32_const(I32(1)))
            out.push(Instruction::array_new_default(type_idx))
            return
          }
        }
        _ => ()
      }
      if env.depth_left > 0 {
        if !rt.is_nullable() && ctx.random_int(4) == 0 {
          out.push(
            Instruction::block(
              BlockType::val_type(ValType::ref_type(rt)),
              Expr::new([
                Instruction::ref_null(heap_type),
                Instruction::br_on_non_null(LabelIdx::new(0U)),
                Instruction::ref_as_non_null(),
              ]),
            ),
          )
          return
        }
        if rt == RefType::abs(AbsHeapType::any()) && ctx.random_int(5) == 0 {
          out.push(
            Instruction::block(
              BlockType::val_type(ValType::ref_type(rt)),
              Expr::new([
                Instruction::ref_null(heap_type),
                Instruction::br_on_cast(
                  LabelIdx::new(0U),
                  true,
                  HeapType::abs(AbsHeapType::any()),
                  true,
                  HeapType::abs(AbsHeapType::i31()),
                ),
              ]),
            ),
          )
          return
        }
        if rt == RefType::abs(AbsHeapType::any()) && ctx.random_int(5) == 0 {
          out.push(
            Instruction::block(
              BlockType::val_type(ValType::ref_type(rt)),
              Expr::new([
                Instruction::ref_null(heap_type),
                Instruction::br_on_cast_fail(
                  LabelIdx::new(0U),
                  true,
                  HeapType::abs(AbsHeapType::any()),
                  true,
                  HeapType::abs(AbsHeapType::i31()),
                ),
              ]),
            ),
          )
          return
        }
      }
      out.push(Instruction::ref_null(heap_type))
    }
    _ => out.push(gen_const_instr(ctx, vt))
  }
}

///|
fn gen_valid_append_natural_gc_stmt(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Bool {
  if ctx.config.mode != Natural || !ctx.config.features.allow_ref_types {
    return false
  }
  match ctx.random_int(7) {
    0 => {
      match (
        env.gc_type_plan.descriptor_struct_idx,
        env.gc_type_plan.descriptor_type_idx,
      ) {
        (Some(described_idx), Some(descriptor_idx)) => {
          out.push(Instruction::struct_new_default(descriptor_idx))
          out.push(Instruction::struct_new_default_desc(described_idx))
          out.push(Instruction::ref_get_desc(described_idx))
          out.push(Instruction::drop())
          true
        }
        _ => false
      }
    }
    1 => {
      match (
        env.gc_type_plan.descriptor_struct_idx,
        env.gc_type_plan.descriptor_type_idx,
      ) {
        (Some(described_idx), Some(descriptor_idx)) => {
          out.push(Instruction::struct_new_default(descriptor_idx))
          out.push(Instruction::struct_new_default_desc(described_idx))
          out.push(Instruction::ref_test_desc(true, HeapType::new(descriptor_idx)))
          out.push(Instruction::drop())
          out.push(Instruction::struct_new_default(descriptor_idx))
          out.push(Instruction::struct_new_default_desc(described_idx))
          out.push(Instruction::ref_cast_desc_eq(true, HeapType::new(descriptor_idx)))
          out.push(Instruction::drop())
          out.push(
            Instruction::block(
              BlockType::val_type(
                ValType::ref_type(
                  RefType::new(false, HeapType::new(descriptor_idx)),
                ),
              ),
              Expr::new([
                Instruction::ref_null(HeapType::new(descriptor_idx)),
                Instruction::br_on_non_null(LabelIdx::new(0U)),
                Instruction::unreachable_(),
              ]),
            ),
          )
          out.push(Instruction::drop())
          true
        }
        _ => false
      }
    }
    2 => {
      match env.gc_type_plan.string_wtf16_array_idx {
        Some(string_wtf16_array_idx) => {
          out.push(Instruction::i32_const(I32(4)))
          out.push(Instruction::array_new_default(string_wtf16_array_idx))
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::i32_const(I32(2)))
          out.push(Instruction::string_new_wtf16_array())
          out.push(Instruction::drop())
          true
        }
        None => false
      }
    }
    3 => {
      match env.gc_type_plan.string_utf8_array_idx {
        Some(string_utf8_array_idx) => {
          out.push(Instruction::string_const(b"gen-valid-string"))
          out.push(Instruction::i32_const(I32(16)))
          out.push(Instruction::array_new_default(string_utf8_array_idx))
          out.push(Instruction::i32_const(I32(0)))
          if ctx.random_bool() {
            out.push(Instruction::string_encode_utf8_array())
          } else if ctx.random_bool() {
            out.push(Instruction::string_encode_lossy_utf8_array())
          } else {
            out.push(Instruction::string_encode_wtf8_array())
          }
          out.push(Instruction::drop())

          out.push(Instruction::i32_const(I32(16)))
          out.push(Instruction::array_new_default(string_utf8_array_idx))
          out.push(Instruction::i32_const(I32(0)))
          out.push(Instruction::i32_const(I32(4)))
          if ctx.random_bool() {
            out.push(Instruction::string_new_lossy_utf8_array())
          } else {
            out.push(Instruction::string_new_wtf8_array())
          }
          out.push(Instruction::drop())
          true
        }
        None => false
      }
    }
    4 => {
      out.push(
        Instruction::block(
          BlockType::val_type(
            ValType::ref_type(RefType::abs(AbsHeapType::any())),
          ),
          Expr::new([
            Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
            Instruction::br_on_cast(
              LabelIdx::new(0U),
              true,
              HeapType::abs(AbsHeapType::any()),
              true,
              HeapType::abs(AbsHeapType::i31()),
            ),
          ]),
        ),
      )
      out.push(Instruction::drop())
      out.push(
        Instruction::block(
          BlockType::val_type(
            ValType::ref_type(RefType::abs(AbsHeapType::any())),
          ),
          Expr::new([
            Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
            Instruction::br_on_cast_fail(
              LabelIdx::new(0U),
              true,
              HeapType::abs(AbsHeapType::any()),
              true,
              HeapType::abs(AbsHeapType::i31()),
            ),
          ]),
        ),
      )
      out.push(Instruction::drop())
      true
    }
    5 => {
      if !env.tags.is_empty() {
        let tag_idx = TagIdx::new(0U)
        let exnref = ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::exn())),
        )
        out.push(
          Instruction::block(
            BlockType::void_(),
            Expr::new([
              Instruction::try_table(
                BlockType::void_(),
                [Catch::new(tag_idx, LabelIdx::new(0U))],
                Expr::new([Instruction::throw_(tag_idx)]),
              ),
            ]),
          ),
        )
        out.push(
          Instruction::block(
            BlockType::val_type(exnref),
            Expr::new([
              Instruction::try_table(
                BlockType::val_type(exnref),
                [Catch::ref_(tag_idx, LabelIdx::new(0U))],
                Expr::new([Instruction::throw_(tag_idx)]),
              ),
            ]),
          ),
        )
        out.push(Instruction::drop())
        out.push(
          Instruction::block(
            BlockType::val_type(exnref),
            Expr::new([
              Instruction::try_table(
                BlockType::val_type(exnref),
                [Catch::all_ref(LabelIdx::new(0U))],
                Expr::new([Instruction::throw_(tag_idx)]),
              ),
            ]),
          ),
        )
        out.push(Instruction::drop())
        true
      } else {
        false
      }
    }
    _ => {
      out.push(
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::try_table(
              BlockType::void_(),
              [Catch::all(LabelIdx::new(0U))],
              Expr::new([
                Instruction::ref_null(HeapType::abs(AbsHeapType::exn())),
                Instruction::throw_ref(),
              ]),
            ),
          ]),
        ),
      )
      true
    }
  }
}

///|
fn append_void_stmt(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  let branchy = ctx.config.features.allow_branch_heavy_control
  match ctx.random_int(if branchy { 14 } else { 10 }) {
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
        if ctx.config.mode == CoverageForced {
          out.push(gen_const_instr(ctx, vt))
        } else {
          append_value_instrs(
            out,
            ctx,
            vt,
            gen_valid_body_env_child(env),
            prefer_local=false,
          )
        }
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
          if ctx.config.mode == CoverageForced {
            out.push(gen_const_instr(ctx, vt))
          } else {
            append_value_instrs(
              out,
              ctx,
              vt,
              gen_valid_body_env_child(env),
              prefer_local=false,
            )
          }
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
    8 =>
      if !gen_valid_append_memory_bulk_ops(out, ctx, env) {
        out.push(Instruction::nop())
      }
    9 =>
      if !gen_valid_append_table_bulk_ops(out, ctx, env) {
        out.push(Instruction::nop())
      }
    10 => {
      let body : Array[Instruction] = []
      gen_valid_append_nested_void_instrs(body, ctx, env)
      out.push(Instruction::block(BlockType::void_(), Expr::new(body)))
    }
    11 => {
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
    12 => {
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
fn gen_valid_append_gc_prelude(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  ignore(ctx)
  if !env.gc_type_plan.struct_type_idxs.is_empty() {
    let struct_idx = env.gc_type_plan.struct_type_idxs[0]
    out.push(Instruction::struct_new_default(struct_idx))
    out.push(Instruction::struct_get(struct_idx, U32::new(0U)))
    out.push(Instruction::drop())

    out.push(Instruction::struct_new_default(struct_idx))
    out.push(Instruction::i32_const(I32(1)))
    out.push(Instruction::struct_set(struct_idx, U32::new(0U)))

    out.push(Instruction::ref_null(HeapType::abs(AbsHeapType::any())))
    out.push(Instruction::ref_test(true, HeapType::abs(AbsHeapType::eq())))
    out.push(Instruction::drop())

    out.push(Instruction::ref_null(HeapType::abs(AbsHeapType::any())))
    out.push(Instruction::ref_cast(true, HeapType::abs(AbsHeapType::eq())))
    out.push(Instruction::drop())

    out.push(Instruction::ref_null(HeapType::abs(AbsHeapType::any())))
    out.push(Instruction::ref_as_non_null())
    out.push(Instruction::drop())

    out.push(Instruction::struct_new_default(struct_idx))
    out.push(Instruction::struct_new_default(struct_idx))
    out.push(Instruction::ref_eq())
    out.push(Instruction::drop())

    out.push(
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::ref_null(HeapType::new(struct_idx)),
          Instruction::br_on_null(LabelIdx::new(0U)),
          Instruction::drop(),
        ]),
      ),
    )
  }

  match (
    env.gc_type_plan.descriptor_struct_idx,
    env.gc_type_plan.descriptor_type_idx,
  ) {
    (Some(described_idx), Some(descriptor_idx)) => {
      out.push(Instruction::struct_new_default(descriptor_idx))
      out.push(Instruction::struct_new_default_desc(described_idx))
      out.push(Instruction::ref_get_desc(described_idx))
      out.push(Instruction::drop())

      out.push(Instruction::struct_new_default(descriptor_idx))
      out.push(Instruction::struct_new_default_desc(described_idx))
      out.push(Instruction::ref_test_desc(true, HeapType::new(descriptor_idx)))
      out.push(Instruction::drop())

      out.push(Instruction::struct_new_default(descriptor_idx))
      out.push(Instruction::struct_new_default_desc(described_idx))
      out.push(Instruction::ref_cast_desc_eq(true, HeapType::new(descriptor_idx)))
      out.push(Instruction::drop())

      out.push(
        Instruction::block(
          BlockType::val_type(
            ValType::ref_type(RefType::new(false, HeapType::new(descriptor_idx))),
          ),
          Expr::new([
            Instruction::ref_null(HeapType::new(descriptor_idx)),
            Instruction::br_on_non_null(LabelIdx::new(0U)),
            Instruction::unreachable_(),
          ]),
        ),
      )
      out.push(Instruction::drop())
    }
    _ => ()
  }

  if !env.gc_type_plan.array_type_idxs.is_empty() {
    let array_idx = env.gc_type_plan.array_type_idxs[0]
    out.push(Instruction::i32_const(I32(2)))
    out.push(Instruction::array_new_default(array_idx))
    out.push(Instruction::array_len())
    out.push(Instruction::drop())

    out.push(Instruction::i32_const(I32(2)))
    out.push(Instruction::array_new_default(array_idx))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::array_get(array_idx))
    out.push(Instruction::drop())

    out.push(Instruction::i32_const(I32(2)))
    out.push(Instruction::array_new_default(array_idx))
    out.push(Instruction::i32_const(I32(0)))
    out.push(Instruction::i32_const(I32(7)))
    out.push(Instruction::array_set(array_idx))
  }

  match env.gc_type_plan.string_wtf16_array_idx {
    Some(string_wtf16_array_idx) => {
      out.push(Instruction::i32_const(I32(4)))
      out.push(Instruction::array_new_default(string_wtf16_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(2)))
      out.push(Instruction::string_new_wtf16_array())
      out.push(Instruction::drop())
    }
    None => ()
  }

  match env.gc_type_plan.string_utf8_array_idx {
    Some(string_utf8_array_idx) => {
      out.push(Instruction::string_const(b"gen-valid-string"))
      out.push(Instruction::i32_const(I32(16)))
      out.push(Instruction::array_new_default(string_utf8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::string_encode_utf8_array())
      out.push(Instruction::drop())

      out.push(Instruction::i32_const(I32(16)))
      out.push(Instruction::array_new_default(string_utf8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(4)))
      out.push(Instruction::string_new_lossy_utf8_array())
      out.push(Instruction::drop())

      out.push(Instruction::i32_const(I32(16)))
      out.push(Instruction::array_new_default(string_utf8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::i32_const(I32(4)))
      out.push(Instruction::string_new_wtf8_array())
      out.push(Instruction::drop())

      out.push(Instruction::string_const(b"gen-valid-string"))
      out.push(Instruction::i32_const(I32(16)))
      out.push(Instruction::array_new_default(string_utf8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::string_encode_lossy_utf8_array())
      out.push(Instruction::drop())

      out.push(Instruction::string_const(b"gen-valid-string"))
      out.push(Instruction::i32_const(I32(16)))
      out.push(Instruction::array_new_default(string_utf8_array_idx))
      out.push(Instruction::i32_const(I32(0)))
      out.push(Instruction::string_encode_wtf8_array())
      out.push(Instruction::drop())
    }
    None => ()
  }

  out.push(
    Instruction::block(
      BlockType::val_type(ValType::ref_type(RefType::abs(AbsHeapType::any()))),
      Expr::new([
        Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
        Instruction::br_on_cast(
          LabelIdx::new(0U),
          true,
          HeapType::abs(AbsHeapType::any()),
          true,
          HeapType::abs(AbsHeapType::i31()),
        ),
      ]),
    ),
  )
  out.push(Instruction::drop())

  out.push(
    Instruction::block(
      BlockType::val_type(ValType::ref_type(RefType::abs(AbsHeapType::any()))),
      Expr::new([
        Instruction::ref_null(HeapType::abs(AbsHeapType::any())),
        Instruction::br_on_cast_fail(
          LabelIdx::new(0U),
          true,
          HeapType::abs(AbsHeapType::any()),
          true,
          HeapType::abs(AbsHeapType::i31()),
        ),
      ]),
    ),
  )
  out.push(Instruction::drop())

  if !env.tags.is_empty() {
    let tag_idx = TagIdx::new(0U)
    let exnref = ValType::ref_type(
      RefType::new(false, HeapType::abs(AbsHeapType::exn())),
    )
    out.push(
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::try_table(
            BlockType::void_(),
            [Catch::new(tag_idx, LabelIdx::new(0U))],
            Expr::new([Instruction::throw_(tag_idx)]),
          ),
        ]),
      ),
    )

    out.push(
      Instruction::block(
        BlockType::val_type(exnref),
        Expr::new([
          Instruction::try_table(
            BlockType::val_type(exnref),
            [Catch::ref_(tag_idx, LabelIdx::new(0U))],
            Expr::new([Instruction::throw_(tag_idx)]),
          ),
        ]),
      ),
    )
    out.push(Instruction::drop())

    out.push(
      Instruction::block(
        BlockType::val_type(exnref),
        Expr::new([
          Instruction::try_table(
            BlockType::val_type(exnref),
            [Catch::all_ref(LabelIdx::new(0U))],
            Expr::new([Instruction::throw_(tag_idx)]),
          ),
        ]),
      ),
    )
    out.push(Instruction::drop())
  }

  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::try_table(
          BlockType::void_(),
          [Catch::all(LabelIdx::new(0U))],
          Expr::new([
            Instruction::ref_null(HeapType::abs(AbsHeapType::exn())),
            Instruction::throw_ref(),
          ]),
        ),
      ]),
    ),
  )

  match env.declared_ref_func_idx {
    Some(func_idx) =>
      match gen_valid_callable_by_idx(env.funcs, func_idx) {
        Some(target) => {
          gen_valid_append_call_args(out, ctx, env, target.params)
          out.push(Instruction::ref_func(func_idx))
          out.push(Instruction::call_ref(target.type_idx))
          gen_valid_append_call_result_drops(out, target.results)
        }
        None => ()
      }
    None => ()
  }
}

///|
fn gen_valid_append_coverage_prelude(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
) -> Unit {
  gen_valid_append_gc_prelude(out, ctx, env)
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
    ignore(gen_valid_append_memory_bulk_ops(out, ctx, env))
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
    ignore(gen_valid_append_table_bulk_ops(out, ctx, env))
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
  tags : Array[TagType],
  funcs : Array[GenValidFuncSig],
  data_idxs : Array[DataIdx],
  elem_idxs : Array[ElemIdx],
  passive_elem_idxs : Array[ElemIdx],
  bulk_elem_seed_idx : ElemIdx?,
  gc_type_plan : GenValidGcTypePlan,
  declared_ref_func_idx : FuncIdx?,
) -> Func {
  let locals = gen_local_types(
    ctx,
    extra_ref_types=gc_type_plan.concrete_ref_types,
  )
  if ctx.config.mode == CoverageForced {
    for vt in gc_type_plan.concrete_ref_types {
      locals.push(vt)
    }
  }
  let all_local_types = gen_all_local_types(accepts, locals)
  let env : GenValidBodyEnv = {
    local_types: all_local_types,
    globals,
    tables,
    mems,
    tags,
    funcs,
    data_idxs,
    elem_idxs,
    passive_elem_idxs,
    bulk_elem_seed_idx,
    gc_type_plan,
    declared_ref_func_idx,
    depth_left: gen_valid_clamp_non_negative(ctx.config.max_body_depth),
    label_depth: 0,
  }
  let body_instrs : Array[Instruction] = []
  if ctx.config.mode == CoverageForced {
    gen_valid_append_coverage_prelude(body_instrs, ctx, env)
  }
  let stmt_count = if ctx.config.mode == CoverageForced {
    0
  } else if ctx.config.mode == Natural && !gc_type_plan.concrete_ref_types.is_empty() {
    0
  } else {
    gen_valid_body_stmt_count(ctx, env.depth_left)
  }
  for _ in 0..<stmt_count {
    append_void_stmt(body_instrs, ctx, env)
  }
  if ctx.config.mode == Natural && ctx.config.features.allow_ref_types {
    let gc_stmt_count = 1 + ctx.random_int(2)
    for _ in 0..<gc_stmt_count {
      ignore(gen_valid_append_natural_gc_stmt(body_instrs, ctx, env))
    }
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
  gen_valid_build_func(
    ctx,
    accepts,
    returns,
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    None,
    gen_valid_gc_type_plan_empty(),
    None,
  )
}

///|
fn gen_valid_choose_optional_count_with_coverage_floor(
  ctx : GenValidContext,
  allow : Bool,
  max_count : Int,
  percent : Int,
  coverage_floor : Int,
) -> Int {
  let bounded_max = gen_valid_clamp_non_negative(max_count)
  if !allow || bounded_max <= 0 {
    0
  } else if ctx.config.mode == CoverageForced {
    let floor = gen_valid_min_int(
      bounded_max,
      gen_valid_clamp_non_negative(coverage_floor),
    )
    floor + ctx.random_int(bounded_max - floor + 1)
  } else if gen_valid_roll_percent(ctx, percent) {
    1 + ctx.random_int(bounded_max)
  } else {
    0
  }
}

///|
fn gen_valid_choose_optional_count(
  ctx : GenValidContext,
  allow : Bool,
  max_count : Int,
  percent : Int,
) -> Int {
  gen_valid_choose_optional_count_with_coverage_floor(
    ctx, allow, max_count, percent, 1,
  )
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
fn gen_valid_active_i32_offset(ctx : GenValidContext) -> Expr {
  Expr::new([Instruction::i32_const(I32(ctx.random_int(4)))])
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
  let import_budget = gen_valid_choose_optional_count_with_coverage_floor(
    ctx,
    config.features.allow_imports,
    config.max_imports,
    config.section_bias.imports_percent,
    5,
  )
  let mut import_plan : GenValidImportPlan = {
    func_count: 0,
    table_count: 0,
    mem_count: 0,
    global_count: 0,
    tag_count: 0,
  }
  let mut remaining_imports = import_budget
  if ctx.config.mode == CoverageForced && remaining_imports >= 5 {
    import_plan = {
      func_count: 1,
      table_count: 1,
      mem_count: 1,
      global_count: 1,
      tag_count: 1,
    }
    remaining_imports -= 5
  }
  while remaining_imports > 0 {
    match ctx.random_int(5) {
      0 =>
        import_plan = { ..import_plan, func_count: import_plan.func_count + 1 }
      1 =>
        import_plan = {
          ..import_plan,
          table_count: import_plan.table_count + 1,
        }
      2 => import_plan = { ..import_plan, mem_count: import_plan.mem_count + 1 }
      3 =>
        import_plan = {
          ..import_plan,
          global_count: import_plan.global_count + 1,
        }
      _ => import_plan = { ..import_plan, tag_count: import_plan.tag_count + 1 }
    }
    remaining_imports -= 1
  }

  let import_func_count = import_plan.func_count
  let import_table_count = import_plan.table_count
  let import_mem_count = import_plan.mem_count
  let import_global_count = import_plan.global_count
  let import_tag_count = import_plan.tag_count

  let defined_func_count = gen_valid_choose_defined_func_count(ctx)
  let defined_table_count = gen_valid_choose_optional_count(
    ctx,
    config.features.allow_tables,
    config.max_tables,
    config.section_bias.tables_percent,
  )
  let defined_mem_count = gen_valid_choose_optional_count(
    ctx,
    config.features.allow_mems,
    config.max_mems,
    config.section_bias.mems_percent,
  )
  let defined_global_count = gen_valid_choose_optional_count(
    ctx,
    config.features.allow_globals,
    config.max_globals,
    config.section_bias.globals_percent,
  )
  let defined_tag_count = gen_valid_choose_optional_count(
    ctx,
    config.features.allow_tags,
    config.max_tags,
    config.section_bias.tags_percent,
  )

  let total_table_count = import_table_count + defined_table_count
  let total_mem_count = import_mem_count + defined_mem_count
  let total_global_count = import_global_count + defined_global_count
  let total_tag_count = import_tag_count + defined_tag_count

  let elem_count = if total_table_count > 0 {
    gen_valid_choose_optional_count_with_coverage_floor(
      ctx,
      config.features.allow_elems,
      config.max_elems,
      config.section_bias.elems_percent,
      3,
    )
  } else {
    0
  }
  let data_count = if total_mem_count > 0 {
    gen_valid_choose_optional_count_with_coverage_floor(
      ctx,
      config.features.allow_datas,
      config.max_datas,
      config.section_bias.datas_percent,
      2,
    )
  } else {
    0
  }

  let has_start = config.features.allow_start &&
    (
      ctx.config.mode == CoverageForced ||
      gen_valid_roll_percent(ctx, config.section_bias.start_percent)
    )
  let total_type_users = import_func_count +
    defined_func_count +
    total_tag_count
  let max_type_defs = if gen_valid_clamp_non_negative(config.max_type_defs) <= 0 {
    1
  } else {
    gen_valid_clamp_non_negative(config.max_type_defs)
  }
  let func_type_count = if ctx.config.mode == CoverageForced &&
    total_type_users > 1 {
    1 + ctx.random_int(gen_valid_min_int(max_type_defs, total_type_users - 1))
  } else {
    1 + ctx.random_int(max_type_defs)
  }

  let type_defs : Array[RecType] = []
  let type_params : Array[Array[ValType]] = []
  let type_results : Array[Array[ValType]] = []
  for i = 0; i < func_type_count; i = i + 1 {
    let params = if i == 0 && (has_start || total_tag_count > 0) {
      []
    } else {
      gen_param_types(ctx)
    }
    let results = if i == 0 && (has_start || total_tag_count > 0) {
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
  let remaining_type_budget = max_type_defs - func_type_count
  let (gc_type_defs, gc_type_plan) = gen_valid_gc_type_defs(
    ctx, func_type_count, remaining_type_budget,
  )
  for rec_type in gc_type_defs {
    type_defs.push(rec_type)
  }

  let imports : Array[Import] = []
  for i = 0; i < import_func_count; i = i + 1 {
    let type_idx = gen_valid_pick_type_idx(ctx, func_type_count)
    imports.push(
      Import::new(
        Name::new("env"),
        Name::new("imported_func_\{i}"),
        ExternType::func(type_idx),
      ),
    )
  }
  let imported_tables : Array[TableType] = []
  for i = 0; i < import_table_count; i = i + 1 {
    let max = (1 + ctx.random_int(4)).reinterpret_as_uint()
    let table_ref_type = if i == 0 {
      RefType::new(true, HeapType::abs(AbsHeapType::func()))
    } else if !gc_type_plan.concrete_ref_types.is_empty() &&
      (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0) {
      match
        gc_type_plan.concrete_ref_types[ctx.random_int(
          gc_type_plan.concrete_ref_types.length(),
        )] {
        RefTypeValType(rt) => rt
        _ => RefType::new(true, HeapType::abs(AbsHeapType::eq()))
      }
    } else {
      RefType::new(true, HeapType::abs(AbsHeapType::eq()))
    }
    let table_type = TableType::new(table_ref_type, Limits::i32(1U, Some(max)))
    imported_tables.push(table_type)
    imports.push(
      Import::new(
        Name::new("env"),
        Name::new("imported_table_\{i}"),
        ExternType::table(table_type),
      ),
    )
  }
  let imported_mems : Array[MemType] = []
  for i = 0; i < import_mem_count; i = i + 1 {
    let max = (1 + ctx.random_int(4)).reinterpret_as_uint()
    let mem_type = MemType::new(Limits::i32(1U, Some(max)))
    imported_mems.push(mem_type)
    imports.push(
      Import::new(
        Name::new("env"),
        Name::new("imported_memory_\{i}"),
        ExternType::mem(mem_type),
      ),
    )
  }
  let imported_global_types : Array[GlobalType] = []
  for i = 0; i < import_global_count; i = i + 1 {
    let global_vt = if i == 0 &&
      !gc_type_plan.concrete_ref_types.is_empty() &&
      (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0) {
      gc_type_plan.concrete_ref_types[0]
    } else {
      gen_valid_valtype_with_extra_refs(ctx, gc_type_plan.concrete_ref_types)
    }
    let global_type = GlobalType::new(
      global_vt,
      ctx.config.mode == CoverageForced || ctx.random_bool(),
    )
    imported_global_types.push(global_type)
    imports.push(
      Import::new(
        Name::new("env"),
        Name::new("imported_global_\{i}"),
        ExternType::global(global_type),
      ),
    )
  }
  for i = 0; i < import_tag_count; i = i + 1 {
    imports.push(
      Import::new(
        Name::new("env"),
        Name::new("imported_tag_\{i}"),
        ExternType::tag(TagType::new(TypeIdx::new(0U))),
      ),
    )
  }

  let globals : Array[Global] = []
  for i = 0; i < defined_global_count; i = i + 1 {
    let vt = if i == 0 &&
      !gc_type_plan.concrete_ref_types.is_empty() &&
      (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0) {
      gc_type_plan.concrete_ref_types[0]
    } else {
      gen_valid_valtype_with_extra_refs(ctx, gc_type_plan.concrete_ref_types)
    }
    let is_mut = ctx.config.mode == CoverageForced || ctx.random_bool()
    globals.push(
      Global::new(GlobalType::new(vt, is_mut), gen_const_expr(ctx, vt)),
    )
  }
  let global_types = imported_global_types.copy()
  for global in globals {
    let Global(gt, _) = global
    global_types.push(gt)
  }

  let func_type_idxs : Array[TypeIdx] = []
  for i = 0; i < defined_func_count; i = i + 1 {
    func_type_idxs.push(
      if i == 0 && has_start {
        TypeIdx::new(0U)
      } else {
        gen_valid_pick_type_idx(ctx, func_type_count)
      },
    )
  }
  let first_defined_func_idx = FuncIdx::new(
    import_func_count.reinterpret_as_uint(),
  )

  let tables : Array[Table] = []
  for i = 0; i < defined_table_count; i = i + 1 {
    let max = (1 + ctx.random_int(4)).reinterpret_as_uint()
    let total_table_idx = import_table_count + i
    let table_ref_type = if total_table_idx == 0 {
      RefType::new(true, HeapType::abs(AbsHeapType::func()))
    } else if !gc_type_plan.concrete_ref_types.is_empty() &&
      (ctx.config.mode == CoverageForced || ctx.random_int(3) == 0) {
      match
        gc_type_plan.concrete_ref_types[ctx.random_int(
          gc_type_plan.concrete_ref_types.length(),
        )] {
        RefTypeValType(rt) => rt
        _ => RefType::new(true, HeapType::abs(AbsHeapType::eq()))
      }
    } else {
      RefType::new(true, HeapType::abs(AbsHeapType::eq()))
    }
    tables.push(
      Table::new(
        TableType::new(table_ref_type, Limits::i32(1U, Some(max))),
        None,
      ),
    )
  }
  let table_types = imported_tables.copy()
  for table in tables {
    let Table(table_type, _) = table
    table_types.push(table_type)
  }

  let mems : Array[MemType] = imported_mems.copy()
  let defined_mems : Array[MemType] = []
  for _ in 0..<defined_mem_count {
    let max = (1 + ctx.random_int(4)).reinterpret_as_uint()
    let mem_type = MemType::new(Limits::i32(1U, Some(max)))
    defined_mems.push(mem_type)
    mems.push(mem_type)
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

  let total_func_count = import_func_count + defined_func_count
  let tags : Array[TagType] = []
  for _ in 0..<defined_tag_count {
    tags.push(TagType::new(TypeIdx::new(0U)))
  }

  let elems : Array[Elem] = []
  if total_table_count > 0 && total_func_count > 0 {
    for i = 0; i < elem_count; i = i + 1 {
      let func_idx = gen_valid_pick_func_idx(
        ctx, total_func_count, first_defined_func_idx,
      )
      let gc_table_choice = if table_types.length() > 1 {
        Some(
          TableIdx::new(
            (1 + ctx.random_int(table_types.length() - 1)).reinterpret_as_uint(),
          ),
        )
      } else {
        None
      }
      let gc_table_ref_type = match gc_table_choice {
        Some(table_idx) => {
          let TableIdx(table_idx_u) = table_idx
          let TableType(rt, _) = table_types[table_idx_u.reinterpret_as_int()]
          Some(rt)
        }
        None => None
      }
      let elem = if ctx.config.mode == CoverageForced && i == 0 {
        Elem::new(
          ElemMode::active(TableIdx::new(0U), gen_valid_active_i32_offset(ctx)),
          ElemKind::funcs([func_idx]),
        )
      } else if ctx.config.mode == CoverageForced && i == 1 {
        Elem::new(
          ElemMode::passive(),
          ElemKind::typed_exprs(RefType::abs(AbsHeapType::func()), [
            gen_valid_funcref_expr(ctx, func_idx),
          ]),
        )
      } else if ctx.config.mode == CoverageForced && i == 2 {
        match gc_type_plan.bulk_elem_ref_type {
          Some(rt) =>
            Elem::new(
              ElemMode::passive(),
              ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
            )
          None =>
            match (gc_table_choice, gc_table_ref_type) {
              (Some(table_idx), Some(rt)) if ValType::ref_type(rt) != ValType::funcref() =>
                Elem::new(
                  ElemMode::active(table_idx, gen_valid_active_i32_offset(ctx)),
                  ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
                )
              _ =>
                Elem::new(
                  ElemMode::declarative(),
                  ElemKind::func_exprs([gen_valid_funcref_expr(ctx, func_idx)]),
                )
            }
        }
      } else if (match gc_type_plan.bulk_elem_ref_type {
        Some(_) => ctx.random_int(4) == 0
        None => false
      }) {
        match gc_type_plan.bulk_elem_ref_type {
          Some(rt) =>
            Elem::new(
              ElemMode::passive(),
              ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
            )
          None => Elem::new(ElemMode::passive(), ElemKind::funcs([func_idx]))
        }
      } else if (match gc_table_ref_type {
        Some(rt) => ValType::ref_type(rt) != ValType::funcref() && ctx.random_int(3) == 0
        None => false
      }) {
        match (gc_table_choice, gc_table_ref_type) {
          (Some(table_idx), Some(rt)) =>
            Elem::new(
              ElemMode::active(table_idx, gen_valid_active_i32_offset(ctx)),
              ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
            )
          _ => Elem::new(ElemMode::passive(), ElemKind::funcs([func_idx]))
        }
      } else {
        match ctx.random_int(7) {
          0 =>
            Elem::new(
              ElemMode::active(
                TableIdx::new(0U),
                gen_valid_active_i32_offset(ctx),
              ),
              ElemKind::funcs([func_idx]),
            )
          1 => Elem::new(ElemMode::passive(), ElemKind::funcs([func_idx]))
          2 => Elem::new(ElemMode::declarative(), ElemKind::funcs([func_idx]))
          3 =>
            Elem::new(
              ElemMode::passive(),
              ElemKind::typed_exprs(RefType::abs(AbsHeapType::func()), [
                gen_valid_funcref_expr(ctx, func_idx),
              ]),
            )
          4 =>
            Elem::new(
              ElemMode::active(
                TableIdx::new(0U),
                gen_valid_active_i32_offset(ctx),
              ),
              ElemKind::func_exprs([gen_valid_funcref_expr(ctx, func_idx)]),
            )
          5 =>
            match (gc_table_choice, gc_table_ref_type) {
              (Some(table_idx), Some(rt)) if ValType::ref_type(rt) != ValType::funcref() =>
                Elem::new(
                  ElemMode::active(table_idx, gen_valid_active_i32_offset(ctx)),
                  ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
                )
              _ => Elem::new(ElemMode::passive(), ElemKind::funcs([func_idx]))
            }
          _ =>
            match gc_table_ref_type {
              Some(rt) if ValType::ref_type(rt) != ValType::funcref() =>
                Elem::new(
                  ElemMode::passive(),
                  ElemKind::typed_exprs(rt, [gen_valid_elem_ref_expr(ctx, rt)]),
                )
              _ =>
                Elem::new(
                  ElemMode::declarative(),
                  ElemKind::func_exprs([gen_valid_funcref_expr(ctx, func_idx)]),
                )
            }
        }
      }
      elems.push(elem)
    }
  }
  let elem_idxs : Array[ElemIdx] = []
  let passive_elem_idxs : Array[ElemIdx] = []
  let mut bulk_elem_seed_idx : ElemIdx? = None
  for i = 0; i < elems.length(); i = i + 1 {
    let elem_idx = ElemIdx::new(i.reinterpret_as_uint())
    let Elem(mode, kind) = elems[i]
    match mode {
      Active(_, _) => ()
      Passive => {
        elem_idxs.push(elem_idx)
        passive_elem_idxs.push(elem_idx)
        match (bulk_elem_seed_idx, gc_type_plan.bulk_elem_ref_type, kind) {
          (None, Some(seed_rt), TypedExprsElemKind(rt, _)) if rt == seed_rt =>
            bulk_elem_seed_idx = Some(elem_idx)
          _ => ()
        }
      }
      Declarative => elem_idxs.push(elem_idx)
    }
  }

  let datas : Array[Data] = []
  if total_mem_count > 0 {
    for i = 0; i < data_count; i = i + 1 {
      let data = if ctx.config.mode == CoverageForced && i == 0 {
        Data::new(
          DataMode::active(MemIdx::new(0U), gen_valid_active_i32_offset(ctx)),
          b"gen-valid-active",
        )
      } else if ctx.config.mode == CoverageForced && i == 1 {
        Data::new(DataMode::passive(), b"gen-valid-passive")
      } else {
        let payload = match ctx.random_int(4) {
          0 => b""
          1 => b"gen-valid"
          2 => b"bulk-seed"
          _ => b"\x00\x01\x02"
        }
        if ctx.random_int(3) == 0 {
          Data::new(DataMode::passive(), payload)
        } else {
          Data::new(
            DataMode::active(MemIdx::new(0U), gen_valid_active_i32_offset(ctx)),
            payload,
          )
        }
      }
      datas.push(data)
    }
  }
  let data_idxs : Array[DataIdx] = []
  for i = 0; i < datas.length(); i = i + 1 {
    let Data(mode, _) = datas[i]
    match mode {
      Active(_, _) => ()
      Passive => data_idxs.push(DataIdx::new(i.reinterpret_as_uint()))
    }
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
        tags,
        func_sigs,
        data_idxs,
        elem_idxs,
        passive_elem_idxs,
        bulk_elem_seed_idx,
        gc_type_plan,
        Some(first_defined_func_idx),
      ),
    )
  }

  let exports : Array[Export] = [
    Export::new(Name::new("main"), ExternIdx::func(first_defined_func_idx)),
  ]
  if total_table_count > 0 {
    exports.push(
      Export::new(Name::new("table0"), ExternIdx::table(TableIdx::new(0U))),
    )
  }
  if total_mem_count > 0 {
    exports.push(
      Export::new(Name::new("memory0"), ExternIdx::mem(MemIdx::new(0U))),
    )
  }
  if total_global_count > 0 {
    exports.push(
      Export::new(Name::new("global0"), ExternIdx::global(GlobalIdx::new(0U))),
    )
  }
  if total_tag_count > 0 {
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
  if !defined_mems.is_empty() {
    mod = mod.with_mem_sec(MemSec::new(defined_mems))
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
    BrOnNull(_) | BrOnNonNull(_) | BrOnCast(_, _, _, _) | BrOnCastFail(_, _, _, _) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
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
    RefNull(_) | RefFunc(_) | StringConst(_) | ThrowRef | RefGetDesc(_) | RefTest(_, _) | RefCast(_, _) | RefTestDesc(_, _) | RefCastDescEq(_, _) =>
      GenValidInstrFacts::{
        ..GenValidInstrFacts::empty(),
        uses_ref_types: true,
      }
    Throw(_) => GenValidInstrFacts::{ ..GenValidInstrFacts::empty(), branch_ops: 1 }
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
      for export_ in exports {
        let Export(_, idx) = export_
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
