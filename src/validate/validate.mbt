///|
pub fn diff(rt1 : RefType, rt2 : RefType) -> Result[RefType, String] {
  let ht1 = rt1.get_heap_type()
  let n1 = rt1.is_nullable()
  let n2 = rt2.is_nullable()

  // Result nullability: nullable only if rt1 was nullable AND rt2 was not
  let null_out = n1 && not(n2)
  Ok(RefType::new(null_out, ht1))
}

///|
pub enum ValidationIssue {
  TypeSection(String)
  ImportSection(String)
  FunctionSection(String)
  TableSection(String)
  MemorySection(String)
  TagSection(String)
  GlobalSection(String)
  ElementSection(String)
  DataSection(String)
  DataCountSection(String)
  StartSection(String)
  ExportSection(String)
  CodeSection(String)
  NameSection(String)
  FunctionBody(String)
} derive(Eq, Debug)

///|
pub struct ValidationDiagnostic {
  issue : ValidationIssue
  func_idx : FuncIdx?
} derive(Eq, Debug)

///|
pub fn ValidationDiagnostic::new(
  issue : ValidationIssue,
  func_idx? : FuncIdx? = None,
) -> ValidationDiagnostic {
  ValidationDiagnostic::{ issue, func_idx }
}

///|
pub fn validation_issue_message(issue : ValidationIssue) -> String {
  match issue {
    TypeSection(msg)
    | ImportSection(msg)
    | FunctionSection(msg)
    | TableSection(msg)
    | MemorySection(msg)
    | TagSection(msg)
    | GlobalSection(msg)
    | ElementSection(msg)
    | DataSection(msg)
    | DataCountSection(msg)
    | StartSection(msg)
    | ExportSection(msg)
    | NameSection(msg)
    | CodeSection(msg)
    | FunctionBody(msg) => msg
  }
}

///|
pub impl Show for ValidationIssue with output(self, logger) {
  logger.write_string(validation_issue_message(self))
}

///|
pub impl Show for ValidationDiagnostic with output(self, logger) {
  match self.func_idx {
    Some(FuncIdx(i)) => {
      logger.write_string("func[")
      i.output(logger)
      logger.write_string("]: ")
    }
    None => ()
  }
  logger.write_string(validation_issue_message(self.issue))
}

///|
pub suberror ValidationError {
  Validation(ValidationDiagnostic)
} derive(Eq, Debug)

///|
pub impl Show for ValidationError with output(self, logger) {
  match self {
    Validation(diag) => diag.output(logger)
  }
}

///|
pub fn validation_error_diagnostic(
  err : ValidationError,
) -> ValidationDiagnostic {
  match err {
    Validation(diag) => diag
  }
}

///|
pub fn validation_error_message(err : ValidationError) -> String {
  let diag = validation_error_diagnostic(err)
  validation_issue_message(diag.issue)
}

///|
pub fn validation_error_func_idx(err : ValidationError) -> FuncIdx? {
  let diag = validation_error_diagnostic(err)
  diag.func_idx
}

///|
priv struct ValidateHelperTimingSnapshot {
  validate_func_body_us : UInt64
  validate_func_body_calls : Int
}

///|
priv struct ValidateHotspotEntry {
  ordinal : Int
  body_ticks : UInt64
  locals : Int
  top_instrs : Int
}

///|
const VALIDATE_HOTSPOT_SUMMARY_LIMIT : Int = 8

///|
const VALIDATE_REF_FUNC_DECL_TRACE_HEARTBEAT : Int = 256

///|
let validate_helper_timing_validate_func_body_us : Ref[UInt64] = Ref::new(0UL)

///|
let validate_helper_timing_validate_func_body_calls : Ref[Int] = Ref::new(0)

///|
let validate_hotspot_entries : Ref[Array[ValidateHotspotEntry]] = Ref::new([])

///|
let validate_phase_totals_ms : Ref[Map[String, UInt64]] = Ref::new(Map::new())

///|
let validate_phase_totals_calls : Ref[Map[String, Int]] = Ref::new(Map::new())

///|
fn validate_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn validate_trace_now_us() -> UInt64 {
  trace_now_us()
}

///|
fn validate_trace_now_ms() -> UInt64 {
  trace_now_ms()
}

///|
fn validate_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  trace_elapsed_ms(start_ms)
}

///|
fn validate_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  trace_elapsed_us_since(start_us)
}

///|
fn validate_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  trace_delta_us_to_ms(delta_us)
}

///|
fn validate_trace_log_enabled(ordinal : Int, trace_all_funcs : Bool) -> Bool {
  ignore(ordinal)
  trace_all_funcs
}

///|
fn validate_trace_phase_start(
  trace : (String) -> Unit,
  phase : String,
  enabled : Bool,
) -> UInt64 {
  if !enabled {
    return 0UL
  }
  let start_ms = validate_trace_now_ms()
  trace("phase=\{phase}:start")
  start_ms
}

///|
fn validate_trace_phase_done(
  trace : (String) -> Unit,
  phase : String,
  start_ms : UInt64,
  enabled : Bool,
) -> Unit {
  if !enabled {
    return
  }
  let elapsed_ms = validate_trace_elapsed_ms(start_ms)
  validate_phase_timing_commit(phase, elapsed_ms)
  trace("phase=\{phase}:done elapsed_ms=\{elapsed_ms}")
}

///|
fn validate_phase_timing_reset() -> Unit {
  validate_phase_totals_ms.val = Map::new()
  validate_phase_totals_calls.val = Map::new()
}

///|
fn validate_phase_timing_commit(phase : String, elapsed_ms : UInt64) -> Unit {
  let totals_ms = validate_phase_totals_ms.val
  let totals_calls = validate_phase_totals_calls.val
  let current_ms = totals_ms.get(phase).unwrap_or(0UL)
  let current_calls = totals_calls.get(phase).unwrap_or(0)
  totals_ms.set(phase, current_ms + elapsed_ms)
  totals_calls.set(phase, current_calls + 1)
}

///|
fn validate_phase_timing_total_ms(phase : String) -> UInt64 {
  validate_phase_totals_ms.val.get(phase).unwrap_or(0UL)
}

///|
fn validate_phase_timing_total_calls(phase : String) -> Int {
  validate_phase_totals_calls.val.get(phase).unwrap_or(0)
}

///|
fn validate_phase_totals_line() -> String {
  let phases = [
    "typesec", "importsec", "funcsec", "tablesec", "memsec", "tagsec", "globalsec",
    "elemsec", "datasec", "datacnt", "datacnt_requirement", "startsec", "exportsec",
    "ref_func_declarations", "codesec", "namesec",
  ]
  let out = StringBuilder::new()
  out.write_string("phase_totals")
  for phase in phases {
    let calls = validate_phase_timing_total_calls(phase)
    if calls > 0 {
      out.write_string(
        " \{phase}_ms=\{validate_phase_timing_total_ms(phase)} \{phase}_calls=\{calls}",
      )
    }
  }
  out.to_string()
}

///|
fn validate_helper_timing_reset() -> Unit {
  validate_helper_timing_validate_func_body_us.val = 0UL
  validate_helper_timing_validate_func_body_calls.val = 0
}

///|
fn validate_helper_timing_commit(
  enabled : Bool,
  elapsed_us : Ref[UInt64],
  calls : Ref[Int],
  start_us : UInt64,
) -> Unit {
  if !enabled {
    return
  }
  elapsed_us.val = elapsed_us.val + validate_trace_elapsed_us_since(start_us)
  calls.val = calls.val + 1
}

///|
fn validate_helper_timing_snapshot() -> ValidateHelperTimingSnapshot {
  {
    validate_func_body_us: validate_helper_timing_validate_func_body_us.val,
    validate_func_body_calls: validate_helper_timing_validate_func_body_calls.val,
  }
}

///|
fn validate_helper_timing_zero() -> ValidateHelperTimingSnapshot {
  { validate_func_body_us: 0UL, validate_func_body_calls: 0 }
}

///|
fn validate_helper_timing_delta_u64(after : UInt64, before : UInt64) -> UInt64 {
  if after >= before {
    after - before
  } else {
    0UL
  }
}

///|
fn validate_helper_timing_diff(
  after : ValidateHelperTimingSnapshot,
  before : ValidateHelperTimingSnapshot,
) -> ValidateHelperTimingSnapshot {
  {
    validate_func_body_us: validate_helper_timing_delta_u64(
      after.validate_func_body_us,
      before.validate_func_body_us,
    ),
    validate_func_body_calls: after.validate_func_body_calls -
    before.validate_func_body_calls,
  }
}

///|
fn validate_helper_timing_has_nonzero(
  snapshot : ValidateHelperTimingSnapshot,
) -> Bool {
  snapshot.validate_func_body_calls > 0
}

///|
fn validate_trace_emit_helper_timing(
  trace : (String) -> Unit,
  ordinal : Int,
  timing : ValidateHelperTimingSnapshot,
) -> Unit {
  if !validate_helper_timing_has_nonzero(timing) {
    return
  }
  trace(
    "func[\{ordinal}] helper_timing body_ms=\{validate_trace_delta_us_to_ms(timing.validate_func_body_us)} body_calls=\{timing.validate_func_body_calls}",
  )
}

///|
fn validate_helper_totals_line() -> String {
  "helper_totals body_ms=\{validate_trace_delta_us_to_ms(validate_helper_timing_validate_func_body_us.val)} body_calls=\{validate_helper_timing_validate_func_body_calls.val}"
}

///|
fn validate_trace_emit_totals(trace : (String) -> Unit) -> Unit {
  trace(validate_phase_totals_line())
  trace(validate_helper_totals_line())
}

///|
fn validate_hotspot_reset() -> Unit {
  validate_hotspot_entries.val = []
}

///|
fn validate_hotspot_record(
  ordinal : Int,
  body_ticks : UInt64,
  locals : Int,
  top_instrs : Int,
) -> Unit {
  let entries = validate_hotspot_entries.val
  entries.push({ ordinal, body_ticks, locals, top_instrs })
  if entries.length() <= VALIDATE_HOTSPOT_SUMMARY_LIMIT {
    validate_hotspot_entries.val = entries
    return
  }
  let mut min_idx = 0
  let mut min_ticks = entries[0].body_ticks
  for i = 1; i < entries.length(); i = i + 1 {
    if entries[i].body_ticks < min_ticks {
      min_idx = i
      min_ticks = entries[i].body_ticks
    }
  }
  let trimmed : Array[ValidateHotspotEntry] = []
  for i = 0; i < entries.length(); i = i + 1 {
    if i != min_idx {
      trimmed.push(entries[i])
    }
  }
  validate_hotspot_entries.val = trimmed
}

///|
fn validate_hotspot_summary_line() -> String? {
  let entries = validate_hotspot_entries.val
  if entries.is_empty() {
    return None
  }
  let ordered = entries.copy()
  let mut i = 0
  while i < ordered.length() {
    let mut j = i + 1
    while j < ordered.length() {
      if ordered[j].body_ticks > ordered[i].body_ticks {
        let tmp = ordered[i]
        ordered[i] = ordered[j]
        ordered[j] = tmp
      }
      j += 1
    }
    i += 1
  }
  let out = StringBuilder::new()
  out.write_string("hotspots ")
  let mut idx = 0
  while idx < ordered.length() {
    if idx > 0 {
      out.write_string(" ")
    }
    let entry = ordered[idx]
    out.write_string(
      "f\{entry.ordinal}:body=\{entry.body_ticks}:locals=\{entry.locals}:top=\{entry.top_instrs}",
    )
    idx += 1
  }
  Some(out.to_string())
}

///|
fn validate_func_trace_locals_count(func : Func) -> Int {
  match func {
    Func(decls, _) => decls.length()
    TFunc(_, locals, _) => locals.length()
  }
}

///|
fn validate_func_trace_top_instrs(func : Func) -> Int {
  match func {
    Func(_, Expr(instrs)) => instrs.length()
    TFunc(_, _, body) => body.instrs.length()
  }
}

///|
pub trait Validate {
  validate(Self, Env) -> Result[Unit, String]
}

///|
pub trait ValidateMax {
  validate_max(Self, Env, UInt64) -> Result[Unit, String]
}

///|
pub impl Validate for NumType with validate(_, _) {
  Ok(())
}

///|
pub impl Validate for TypeIdx with validate(self, env) {
  if env.resolve_typeidx_subtype(self) is Some(_) {
    Ok(())
  } else {
    Err("No type exists for TypeIdx")
  }
}

///|
pub impl Validate for HeapType with validate(self, env) {
  match self {
    AbsHeapTypeHeapType(abs) => Validate::validate(abs, env)
    HeapType(tidx) => Validate::validate(tidx, env)
    DefTypeHeapType(dt) => Validate::validate(dt, env)
  }
}

///|
pub impl Validate for DefType with validate(self, env) {
  let DefType(rt, _) = self
  let env2 = env_with_rectype(env, rt)
  match self.project() {
    Some(st) => Validate::validate(st, env2)
    None => Err("Invalid SubType Index")
  }
}

///|
pub impl Validate for AbsHeapType with validate(_, _) {
  Ok(())
}

///|
pub impl Validate for ValType with validate(self, env) {
  match self {
    RefTypeValType(rt) => Validate::validate(rt, env)
    VecTypeValType => Ok(())
    NumTypeValType(nt) => Validate::validate(nt, env)
    BotValType => Ok(())
  }
}

///|
pub impl[T : Validate] Validate for Array[T] with validate(self, env) {
  for v in self {
    if Validate::validate(v, env) is Err(t) {
      return Err(t)
    }
  }
  Ok(())
}

///|
pub impl Validate for BlockType with validate(self, env) {
  match self {
    ValTypeBlockType(vt) => Validate::validate(vt, env)
    VoidBlockType => Ok(())
    TypeIdxBlockType(tidx) =>
      match env.resolve_typeidx_subtype(tidx) {
        Some(st) =>
          match st.get_comptype() {
            FuncCompType(_, _) => Ok(())
            _ => Err("Expected Func Type for block type")
          }
        None => Err("Invalid TypeIdx for block type")
      }
  }
}

///|
pub impl Validate for FuncType with validate(self, env) {
  let FuncType(t0, t1) = self
  match Validate::validate(t0, env) {
    Ok(_) => Validate::validate(t1, env)
    Err(t) => Err(t)
  }
}

///|
pub impl Validate for CompType with validate(self, env) {
  match self {
    StructCompType(fts) => Validate::validate(fts, env)
    ArrayCompType(ft) => Validate::validate(ft, env)
    FuncCompType(v0, v1) =>
      match Validate::validate(v0, env) {
        Ok(_) => Validate::validate(v1, env)
        Err(t) => Err(t)
      }
  }
}

///|
pub impl Validate for RefType with validate(self, env) {
  match self {
    HeapTypeRefType(_, exact, ht) =>
      if exact {
        match ht {
          HeapType(_) => Validate::validate(ht, env)
          _ => Err("exact refs require a defined heap type")
        }
      } else {
        Validate::validate(ht, env)
      }
    AbsHeapTypeRefType(abs) => Validate::validate(abs, env)
  }
}

///|
pub impl Validate for FieldType with validate(self, env) {
  let FieldType(st, _) = self
  Validate::validate(st, env)
}

///|
pub impl Validate for StorageType with validate(self, env) {
  match self {
    ValTypeStorageType(vt) => Validate::validate(vt, env)
    PackTypeStorageType(_) => Ok(())
  }
}

///|
pub impl Validate for RecType with validate(self, env) {
  let sts = match self {
    SingleRecType(st) => [st]
    GroupRecType(sts) => sts
  }
  if Validate::validate(sts, env) is Err(t) {
    return Err(t)
  }
  validate_descriptor_metadata_group(sts, env)
}

///|
fn descriptor_target_absolute_index(
  target : TypeIdx,
  base : Int,
  group_len : Int,
) -> Int? {
  match target {
    TypeIdx(idx) => Some(idx.reinterpret_as_int())
    RecIdx(idx) => {
      let rel = idx.reinterpret_as_int()
      if rel < 0 || rel >= group_len {
        None
      } else {
        Some(base + rel)
      }
    }
  }
}

///|
fn descriptor_target_lookup_subtype(
  target : TypeIdx,
  sts : Array[SubType],
  env : Env,
  base : Int,
) -> SubType? {
  let target_abs = match
    descriptor_target_absolute_index(target, base, sts.length()) {
    Some(target_abs) => target_abs
    None => return None
  }
  if target_abs >= base && target_abs < base + sts.length() {
    return sts.get(target_abs - base)
  }
  env.resolve_subtype(target)
}

///|
fn validate_descriptor_metadata_group(
  sts : Array[SubType],
  env : Env,
) -> Result[Unit, String] {
  // The rectype is already in `env`, so recover the starting absolute index of
  // the current group before comparing metadata targets against sibling types.
  let base = env.global_types.length() - sts.length()
  let mut i = 0
  while i < sts.length() {
    let st = sts[i]
    let ct = st.get_comptype()
    let meta = st.metadata()
    let self_abs = base + i

    if (meta.describes is Some(_) || meta.descriptor is Some(_)) &&
      !(ct is StructCompType(_)) {
      return Err("descriptor/describes clauses may only appear on struct types")
    }

    match meta.describes {
      Some(target) => {
        let target_abs = match
          descriptor_target_absolute_index(target, base, sts.length()) {
          Some(target_abs) => target_abs
          None => return Err("describes target must be a valid type")
        }
        if target_abs >= self_abs {
          return Err("describes target must be previously defined")
        }
        let target_st = match
          descriptor_target_lookup_subtype(target, sts, env, base) {
          Some(target_st) => target_st
          None => return Err("describes target must be a valid type")
        }
        if !(target_st.get_comptype() is StructCompType(_)) {
          return Err("describes target must be a struct type")
        }
        let target_descriptor_abs = match target_st.descriptor_type() {
          Some(target_descriptor) =>
            descriptor_target_absolute_index(
              target_descriptor,
              base,
              sts.length(),
            )
          None => None
        }
        if target_descriptor_abs != Some(self_abs) {
          return Err("descriptor/describes clauses must agree")
        }
      }
      None => ()
    }

    match meta.descriptor {
      Some(target) => {
        let target_st = match
          descriptor_target_lookup_subtype(target, sts, env, base) {
          Some(target_st) => target_st
          None => return Err("descriptor target must be a valid type")
        }
        if !(target_st.get_comptype() is StructCompType(_)) {
          return Err("descriptor target must be a struct type")
        }
        let target_describes_abs = match target_st.describes_type() {
          Some(target_describes) =>
            descriptor_target_absolute_index(
              target_describes,
              base,
              sts.length(),
            )
          None => None
        }
        if target_describes_abs != Some(self_abs) {
          return Err("descriptor/describes clauses must agree")
        }
      }
      None => ()
    }

    match st {
      SubType(_, supers, _, _) =>
        for super_idx in supers {
          let super_st = match env.resolve_subtype(super_idx) {
            Some(super_st) => super_st
            None => return Err("Invalid subtype")
          }
          let super_descriptor = super_st.descriptor_type()
          let super_describes = super_st.describes_type()
          match meta.descriptor {
            Some(desc_idx) =>
              match super_descriptor {
                Some(super_desc_idx) =>
                  if !Match::matches(
                      HeapType::new(desc_idx),
                      HeapType::new(super_desc_idx),
                      env,
                    ) {
                    return Err(
                      "descriptor clause is incompatible with supertype",
                    )
                  }
                None => ()
              }
            None =>
              if super_descriptor is Some(_) {
                return Err(
                  "descriptor-less subtype cannot extend descriptor-bearing supertype",
                )
              }
          }
          match meta.describes {
            Some(describes_idx) =>
              match super_describes {
                Some(super_describes_idx) =>
                  if !Match::matches(
                      HeapType::new(describes_idx),
                      HeapType::new(super_describes_idx),
                      env,
                    ) {
                    return Err(
                      "describes clause is incompatible with supertype",
                    )
                  }
                None =>
                  return Err(
                    "describing subtype must extend a describing supertype",
                  )
              }
            None =>
              if super_describes is Some(_) {
                return Err(
                  "non-describing subtype cannot extend describing supertype",
                )
              }
          }
        }
      _ => ()
    }
    i += 1
  }
  Ok(())
}

///|
pub impl Validate for SubType with validate(self, env) {
  match self {
    SubType(_, matches, _, ct) => {
      for m in matches {
        match Validate::validate(m, env) {
          Ok(_) if env.resolve_subtype(m) is Some(t) &&
            Match::matches(ct, t.get_comptype(), env) => ()
          Ok(_) => return Err("Invalid subtype")
          Err(t) => return Err(t)
        }
      }
      Ok(())
    }
    CompTypeSubType(_, ct) => Validate::validate(ct, env)
  }
}

///|
pub impl ValidateMax for Limits with validate_max(self, _, k) {
  match self {
    I32Limits(n, m) => {
      let n = n.to_uint64()
      if n <= k &&
        (
          m is None ||
          (m is Some(m) && n <= m.to_uint64() && m.to_uint64() <= k)
        ) {
        Ok(())
      } else {
        Err("Invalid range for limits")
      }
    }
    I64Limits(n, m) =>
      if n <= k && (m is None || (m is Some(m) && n <= m && m <= k)) {
        Ok(())
      } else {
        Err("Invalid range for limits")
      }
  }
}

///|
pub impl Validate for LabelIdx with validate(self, env) {
  let LabelIdx(i) = self
  if i < env.labels.length().reinterpret_as_uint() {
    Ok(())
  } else {
    Err("Invalid LabelIdx")
  }
}

///|
pub impl Validate for TagIdx with validate(self, env) {
  let TagIdx(i) = self
  if i < env.tags.length().reinterpret_as_uint() {
    Ok(())
  } else {
    Err("Invalid TagIdx")
  }
}

///|
pub impl Validate for TagType with validate(self, env) {
  let TagType(tidx) = self
  if Validate::validate(tidx, env) is Err(t) {
    return Err(t)
  }
  match env.resolve_comptype(tidx) {
    Some(FuncCompType(params, results)) => {
      if results.length() != 0 {
        return Err("Tag type must have empty result list")
      }
      Validate::validate(params, env)
    }
    _ => Err("TagType not found or not a function type")
  }
}

///|
pub impl Validate for TagSec with validate(self, env) {
  let TagSec(t) = self
  Validate::validate(t, env)
}

///|
pub impl Validate for Catch with validate(self, env) {
  match self {
    Catch(t, l) =>
      match Validate::validate(t, env) {
        Ok(_) =>
          match env.get_catch_label_types(l) {
            Some(_) => Ok(())
            None => Err("Invalid LabelIdx")
          }
        Err(t) => Err(t)
      }
    CatchRef(t, l) =>
      match Validate::validate(t, env) {
        Ok(_) =>
          match env.get_catch_label_types(l) {
            Some(_) => Ok(())
            None => Err("Invalid LabelIdx")
          }
        Err(t) => Err(t)
      }
    CatchAll(l) =>
      match env.get_catch_label_types(l) {
        Some(_) => Ok(())
        None => Err("Invalid LabelIdx")
      }
    CatchAllRef(l) =>
      match env.get_catch_label_types(l) {
        Some(_) => Ok(())
        None => Err("Invalid LabelIdx")
      }
  }
}

///|
pub impl Validate for GlobalType with validate(self, env) {
  let GlobalType(vt, _) = self
  Validate::validate(vt, env)
}

///|
pub impl Validate for MemType with validate(self, env) {
  let MemType(lim) = self
  ValidateMax::validate_max(lim, env, 65536)
}

///|
pub impl Validate for TableType with validate(self, env) {
  let TableType(rt, lim) = self
  match Validate::validate(rt, env) {
    Ok(_) => ValidateMax::validate_max(lim, env, 4294967295)
    Err(t) => Err(t)
  }
}

///|
pub impl Validate for ExternType with validate(self, env) {
  match self {
    TagExternType(tt) => Validate::validate(tt, env)
    GlobalExternType(gt) => Validate::validate(gt, env)
    MemExternType(mt) => Validate::validate(mt, env)
    TableExternType(tt) => Validate::validate(tt, env)
    FuncExternType(tidx) =>
      match env.resolve_functype(tidx) {
        Some(_) => Ok(())
        None => Err("Invalid ExternType: Func extern type not found")
      }
  }
}

///|
fn validate_const_instr(env : Env, ins : Instruction) -> Result[Unit, String] {
  match ins {
    I32Const(_) => Ok(())
    I64Const(_) => Ok(())
    F32Const(_) => Ok(())
    F64Const(_) => Ok(())
    V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => Ok(())
    RefNull(rt) => Validate::validate(rt, env)
    RefFunc(_) => Ok(())
    StructNew(type_idx)
    | StructNewDefault(type_idx)
    | StructNewDesc(type_idx)
    | StructNewDefaultDesc(type_idx) =>
      match env.resolve_struct_fields(type_idx) {
        Ok(_) => Ok(())
        Err(e) => Err(e)
      }
    GlobalGet(idx) =>
      match env.get_global_type(idx) {
        None => Err("constant expression references an unknown global")
        // This package uses extended-const global.get semantics, but only for
        // immutable globals (imported or previously-defined in module order).
        Some(GlobalType(_, is_mut)) =>
          if is_mut {
            Err("constant expression global.get requires immutable global")
          } else {
            Ok(())
          }
      }
    _ => Err("initializer expression is not constant")
  }
}

///|
fn validate_const_expr(
  env : Env,
  expr : Expr,
  want : ValType,
) -> Result[Unit, String] {
  let Expr(instrs) = expr

  // Explicit constant-expression gate: do not let general expression typing
  // admit instructions that are invalid in const contexts.
  for ins in instrs {
    if validate_const_instr(env, ins) is Err(e) {
      return Err(e)
    }
  }

  // typecheck it under an empty stack/locals/labels context
  // (but with access to env globals, funcs, etc)
  let env_tc = Env::{
    ..env,
    locals: Locals::empty(),
    labels: [],
    return_type: None,
  }
  let st0 = TcState::{
    env: env_tc,
    stack: [],
    reachable: true,
    escape: NoTcEscape,
  }
  let st1 = match Typecheck::typecheck(expr, st0) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  if !st1.reachable {
    return Err("const expr is unreachable")
  }
  if st1.stack.length() != 1 {
    return Err("const expr must leave exactly one value on the stack")
  }
  let actual = st1.stack[0]
  if Match::matches(actual, want, env_tc) {
    Ok(())
  } else {
    Err("const expr result type mismatch")
  }
}

///|
fn validate_global(env : Env, g : Global) -> Result[GlobalType, String] {
  let Global(gt, init) = g
  if Validate::validate(gt, env) is Err(t) {
    return Err(t) // checks vt validity
  }
  let GlobalType(vt, _mut) = gt
  match validate_const_expr(env, init, vt) {
    Ok(_) => Ok(gt)
    Err(t) => Err(t)
  }
}

///|
pub fn validate_globalsec(
  globalsec : GlobalSec?,
  env0 : Env,
) -> Result[Env, String] {
  match globalsec {
    None => Ok(env0)
    Some(GlobalSec(gs)) => {
      let mut env = env0
      let out = env.globals.copy()
      for g in gs {
        // Validate under env that includes *previous* globals only
        let gt = match validate_global(env, g) {
          Ok(gt) => gt
          Err(t) => return Err(t)
        }

        // Extend global index space
        out.push(gt)
        env = env.with_globals(out)
      }
      Ok(env)
    }
  }
}

///|
pub fn validate_tagsec(tagsec : TagSec?, env0 : Env) -> Result[Env, String] {
  match tagsec {
    None => Ok(env0)
    Some(TagSec(tags)) => {
      let mut env = env0
      let out = env.tags.copy()
      for t in tags {
        // validate tag type under current env
        if Validate::validate(t, env) is Err(t) {
          return Err(t)
        }

        // extend tag index space incrementally
        out.push(t)
        env = Env::{
          global_types: env.global_types,
          rec_stack: env.rec_stack,
          funcs: env.funcs,
          func_type_idxs: env.func_type_idxs,
          tables: env.tables,
          mems: env.mems,
          globals: env.globals,
          elems: env.elems,
          datas: env.datas,
          tags: out,
          locals: env.locals,
          labels: env.labels,
          return_type: env.return_type,
        }
      }
      Ok(env)
    }
  }
}

///|
pub fn validate_memsec(memsec : MemSec?, env0 : Env) -> Result[Env, String] {
  match memsec {
    None => Ok(env0)
    Some(MemSec(ms)) => {
      let mut env = env0
      let mems = env.mems.copy()
      for mt in ms {
        match Validate::validate(mt, env) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
        mems.push(mt)
        env = env.with_mems(mems)
      }
      Ok(env)
    }
  }
}

///|
fn validate_table(env : Env, t : Table) -> Result[TableType, String] {
  let Table(tt, init_opt) = t
  match Validate::validate(tt, env) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let TableType(rt, _lim) = tt
  match init_opt {
    None => Ok(tt)
    Some(init) => {
      // init expr must be const and produce value type rt
      let want = ValType::ref_type(rt)
      match validate_const_expr(env, init, want) {
        Ok(_) => Ok(tt)
        Err(e) => Err(e)
      }
    }
  }
}

///|
pub fn validate_tablesec(
  tablesec : TableSec?,
  env0 : Env,
) -> Result[Env, String] {
  match tablesec {
    None => Ok(env0)
    Some(TableSec(ts)) => {
      let mut env = env0
      let tables = env.tables.copy()
      for t in ts {
        let tt = match validate_table(env, t) {
          Ok(x) => x
          Err(e) => return Err(e)
        }
        tables.push(tt)
        env = env.with_tables(tables)
      }
      Ok(env)
    }
  }
}

///|
fn validate_locals_decls(env : Env, decls : Locals) -> Result[Unit, String] {
  for d in decls.runs() {
    let { count, vt } = d
    if Validate::validate(vt, env) is Err(e) {
      return Err(e)
    }
    let local_count = count.reinterpret_as_int()
    if local_count < 0 {
      return Err("locals: negative count")
    }
    if !has_default(vt) {
      return Err("locals: type has no default value")
    }
  }
  Ok(())
}

///|
fn validate_append_all_locals_from_decls(
  params : Array[ValType],
  decls : Locals,
) -> Locals {
  let all = Locals::from_types(params)
  all.append(decls)
  all
}

///|
fn validate_append_all_locals_from_typed(
  params : Array[ValType],
  local_vals : Locals,
) -> Locals {
  let all = Locals::from_types(params)
  all.append(local_vals)
  all
}

///|
fn validate_end_stack_shape_suffix(
  st : TcState,
  results : Array[ValType],
) -> String {
  "expected stack=\{results} actual stack=\{st.stack}"
}

///|
fn validate_end_stack_for_function_body(
  st : TcState,
  results : Array[ValType],
  subject : String,
) -> Result[Unit, String] {
  match check_pop_types_from_top(st, results, results.length()) {
    Err("stack underflow") =>
      Err(
        "\{subject} result stack underflow: \{validate_end_stack_shape_suffix(st, results)}",
      )
    Err("type mismatch") =>
      Err(
        "\{subject} result type mismatch: \{validate_end_stack_shape_suffix(st, results)}",
      )
    Err(e) => Err(e)
    Ok(top_after_results) =>
      if top_after_results != -1 {
        Err(
          "\{subject} leaves extra values on stack: \{validate_end_stack_shape_suffix(st, results)}",
        )
      } else {
        Ok(())
      }
  }
}

///|
fn validate_func_body_against_functype(
  env : Env,
  ft : FuncType,
  f : Func,
) -> Result[Unit, String] {
  let FuncType(params, results) = ft
  match f {
    Func(local_decls, body) => {
      // Validate local declarations
      if validate_locals_decls(env, local_decls) is Err(e) {
        return Err(e)
      }

      // Extend context:
      // - locals
      // - labels appended by results (function label)
      // - return appended by results
      let env1 = env
        .with_locals(validate_append_all_locals_from_decls(params, local_decls))
        .with_labels(
          {
            let ls = env.labels.copy()
            ls.push(results)
            ls
          },
        )
        .with_return_type(Some(results))
      let st0 = TcState::{
        env: env1,
        stack: [],
        reachable: true,
        escape: NoTcEscape,
      }
      let st1 = match Typecheck::typecheck(body, st0) {
        Ok(s) => s
        Err(e) => return Err(e)
      }
      match
        validate_end_stack_for_function_body(st1, results, "function body") {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
      Ok(())
    }
    TFunc(tfunc_params, local_vals, texpr) => {
      if tfunc_params != params {
        return Err(
          "typed function params must match declared signature exactly",
        )
      }
      let env1 = env
        .with_locals(validate_append_all_locals_from_typed(params, local_vals))
        .with_labels(
          {
            let ls = env.labels.copy()
            ls.push(results)
            ls
          },
        )
        .with_return_type(Some(results))
      let st0 = TcState::{
        env: env1,
        stack: [],
        reachable: true,
        escape: NoTcEscape,
      }
      let st1 = match Typecheck::typecheck(texpr, st0) {
        Ok(s) => s
        Err(e) => return Err("typed function " + e)
      }
      match
        validate_end_stack_for_function_body(
          st1, results, "typed function body",
        ) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
      Ok(())
    }
  }
}

///|
fn validate_codesec_diag(
  codesec : CodeSec?,
  funcsec : FuncSec?,
  env : Env,
  trace? : (String) -> Unit = validate_trace_noop,
  trace_all_funcs? : Bool = false,
  helper_timing_enabled? : Bool = false,
) -> Result[Unit, ValidationDiagnostic] {
  match (codesec, funcsec) {
    (None, None) => Ok(())
    (Some(CodeSec(bodies)), None) =>
      if bodies.length() == 0 {
        Ok(())
      } else {
        Err(
          ValidationDiagnostic::new(
            ValidationIssue::CodeSection("codesec present without funcsec"),
          ),
        )
      }
    (None, Some(FuncSec(ts))) =>
      if ts.length() == 0 {
        Ok(())
      } else {
        Err(
          ValidationDiagnostic::new(
            ValidationIssue::CodeSection("funcsec present without codesec"),
          ),
        )
      }
    (Some(CodeSec(bodies)), Some(FuncSec(type_idxs))) => {
      if bodies.length() != type_idxs.length() {
        return Err(
          ValidationDiagnostic::new(
            ValidationIssue::CodeSection(
              "codesec length does not match funcsec length",
            ),
          ),
        )
      }
      let n_defined = bodies.length()
      let n_total = env.funcs.length()
      let n_imported = n_total - n_defined
      if n_imported < 0 {
        return Err(
          ValidationDiagnostic::new(
            ValidationIssue::CodeSection(
              "internal: negative imported func count",
            ),
          ),
        )
      }
      for i in 0..<bodies.length() {
        let ordinal = i + 1
        let log_func = validate_trace_log_enabled(ordinal, trace_all_funcs)
        let func = bodies[i]
        let func_locals = if log_func {
          validate_func_trace_locals_count(func)
        } else {
          0
        }
        let func_top_instrs = if log_func {
          validate_func_trace_top_instrs(func)
        } else {
          0
        }
        let func_start_ms = if log_func { validate_trace_now_ms() } else { 0UL }
        let helper_timing_start = if log_func {
          validate_helper_timing_snapshot()
        } else {
          validate_helper_timing_zero()
        }
        if log_func {
          trace(
            "func[\{ordinal}] start locals=\{func_locals} top_instrs=\{func_top_instrs}",
          )
        }
        let func_idx = FuncIdx::new((n_imported + i).reinterpret_as_uint())
        let ft = match env.funcs.get(n_imported + i) {
          Some(x) => x
          None => {
            if log_func {
              trace(
                "func[\{ordinal}] done elapsed_ms=\{validate_trace_elapsed_ms(func_start_ms)} valid=false reason=missing_functype",
              )
            }
            return Err(
              ValidationDiagnostic::new(
                ValidationIssue::CodeSection(
                  "internal: missing functype for code body",
                ),
                func_idx=Some(func_idx),
              ),
            )
          }
        }
        let body_start_us = if helper_timing_enabled {
          validate_trace_now_us()
        } else {
          0UL
        }
        let body_result = validate_func_body_against_functype(env, ft, func)
        validate_helper_timing_commit(
          helper_timing_enabled, validate_helper_timing_validate_func_body_us, validate_helper_timing_validate_func_body_calls,
          body_start_us,
        )
        if log_func {
          let helper_timing_delta = validate_helper_timing_diff(
            validate_helper_timing_snapshot(),
            helper_timing_start,
          )
          validate_hotspot_record(
            ordinal,
            helper_timing_delta.validate_func_body_us,
            func_locals,
            func_top_instrs,
          )
          validate_trace_emit_helper_timing(trace, ordinal, helper_timing_delta)
        }
        if body_result is Err(e) {
          if log_func {
            trace(
              "func[\{ordinal}] done elapsed_ms=\{validate_trace_elapsed_ms(func_start_ms)} valid=false",
            )
          }
          return Err(
            ValidationDiagnostic::new(
              ValidationIssue::FunctionBody(e),
              func_idx=Some(func_idx),
            ),
          )
        }
        if log_func {
          trace(
            "func[\{ordinal}] done elapsed_ms=\{validate_trace_elapsed_ms(func_start_ms)} valid=true",
          )
        }
      }
      if trace_all_funcs {
        match validate_hotspot_summary_line() {
          Some(summary) => trace(summary)
          None => ()
        }
      }
      Ok(())
    }
  }
}

///|
pub fn validate_codesec(
  codesec : CodeSec?,
  funcsec : FuncSec?,
  env : Env,
) -> Result[Unit, String] {
  match validate_codesec_diag(codesec, funcsec, env) {
    Ok(_) => Ok(())
    Err(diag) => Err(validation_issue_message(diag.issue))
  }
}

///|
pub fn validate_funcsec(funcsec : FuncSec?, env0 : Env) -> Result[Env, String] {
  match funcsec {
    None => Ok(env0)
    Some(FuncSec(type_idxs)) => {
      let mut env = env0
      let funcs = env.funcs.copy()
      let func_type_idxs = env.func_type_idxs.copy()
      for tidx in type_idxs {
        // Each TypeIdx must resolve to a function type
        let ft = match env.resolve_functype(tidx) {
          Some(x) => x
          None => return Err("funcsec: typeidx does not resolve to functype")
        }
        funcs.push(ft)
        func_type_idxs.push(Some(tidx))
        env = Env::{ ..env, funcs, func_type_idxs }
      }
      Ok(env)
    }
  }
}

///|
pub impl Validate for DataMode with validate(self, env) {
  match self {
    Passive => Ok(())
    Active(memidx, offset_expr) => {
      // memory must exist
      let MemType(lim) = match env.get_memtype(memidx) {
        None => return Err("data.active: invalid memory index")
        Some(mt) => mt
      }

      // address type at depends on limits (i32 or i64)
      let at = lim.addr_valtype()

      // expr : at const
      validate_const_expr(env, offset_expr, at)
    }
  }
}

///|
pub impl Validate for Data with validate(self, env) {
  let Data(mode, _) = self
  Validate::validate(mode, env)
}

///|
pub fn validate_datasec(datasec : DataSec?, env0 : Env) -> Result[Env, String] {
  match datasec {
    None => Ok(env0)
    Some(DataSec(ds)) => {
      let mut env = env0
      let datas = env.datas.copy()
      for d in ds {
        // validate under env that includes previous data segments
        if Validate::validate(d, env) is Err(e) {
          return Err(e)
        }
        datas.push(d)
        env = Env::{ ..env, datas, }
      }
      Ok(env)
    }
  }
}

///|
fn validate_elem_mode(
  env : Env,
  mode : ElemMode,
  rt : RefType,
) -> Result[Unit, String] {
  match mode {
    Passive => Ok(())
    Declarative => Ok(())
    Active(tidx, offset_expr) => {
      // table must exist
      let TableType(rt_table, lim) = match env.get_table_type(tidx) {
        None => return Err("elem.active: invalid table index")
        Some(tt) => tt
      }

      // require rt ≤ rt_table
      // If your Match::matches works on RefType, use that.
      // Otherwise use ValType wrapper.
      let ok = Match::matches(
        ValType::ref_type(rt),
        ValType::ref_type(rt_table),
        env,
      )
      if !ok {
        return Err("elem.active: elem type does not match table element type")
      }

      // offset expr : at const
      let at = lim.addr_valtype()
      validate_const_expr(env, offset_expr, at)
    }
  }
}

///|
pub impl Validate for ElemKind with validate(self, env) {
  match self {
    // elemtype is funcref; initializers are function indices
    FuncsElemKind(fs) => {
      for f in fs {
        if !env.has_func(f) {
          return Err("elem.funcs: invalid function index")
        }
      }
      Ok(())
    }

    // legacy element expressions: elemtype is funcref; each expr must be const funcref
    FuncExprsElemKind(exprs) => {
      let want = ValType::funcref()
      for e in exprs {
        if validate_const_expr(env, e, want) is Err(t) {
          return Err(t)
        }
      }
      Ok(())
    }

    // typed element expressions: elemtype is provided; each expr must be const of that type
    TypedExprsElemKind(rt, exprs) => {
      if Validate::validate(rt, env) is Err(t) {
        return Err(t)
      }
      let want = ValType::ref_type(rt)
      for e in exprs {
        if validate_const_expr(env, e, want) is Err(t) {
          return Err(t)
        }
      }
      Ok(())
    }
  }
}

///|
pub impl Validate for Elem with validate(self, env) {
  let Elem(mode, kind) = self

  // kind validity (incl. elemtype and init exprs)
  if Validate::validate(kind, env) is Err(t) {
    return Err(t)
  }

  // derive elemtype from kind and validate it
  let rt = Elem::reftype(self)
  if Validate::validate(rt, env) is Err(t) {
    return Err(t)
  }

  // mode validity depends on elemtype
  validate_elem_mode(env, mode, rt)
}

///|
pub fn validate_elemsec(elemsec : ElemSec?, env0 : Env) -> Result[Env, String] {
  match elemsec {
    None => Ok(env0)
    Some(ElemSec(es)) => {
      let mut env = env0
      let elems = env.elems.copy()
      for e in es {
        if Validate::validate(e, env) is Err(t) {
          return Err(t)
        }
        elems.push(e)
        env = env.with_elems(elems)
      }
      Ok(env)
    }
  }
}

///|
pub impl Validate for Import with validate(self, env) {
  let Import(_, _, xt) = self
  Validate::validate(xt, env)
}

///|
pub fn validate_importsec(
  importsec : ImportSec?,
  env0 : Env,
) -> Result[Env, String] {
  match importsec {
    None => Ok(env0)
    Some(ImportSec(imps)) => {
      let mut env = env0
      let funcs = env.funcs.copy()
      let func_type_idxs = env.func_type_idxs.copy()
      let tables = env.tables.copy()
      let mems = env.mems.copy()
      let globals = env.globals.copy()
      let tags = env.tags.copy()
      for imp in imps {
        if Validate::validate(imp, env) is Err(e) {
          return Err(e)
        }
        let Import(_, _, et) = imp
        match et {
          FuncExternType(tidx) => {
            let ft = match env.resolve_functype(tidx) {
              Some(x) => x
              None => return Err("import func: type index is not a functype")
            }
            funcs.push(ft)
            func_type_idxs.push(Some(tidx))
          }
          TableExternType(tt) => tables.push(tt)
          MemExternType(mt) => mems.push(mt)
          GlobalExternType(gt) => globals.push(gt)
          TagExternType(tt) => tags.push(tt)
        }
        env = Env::{ ..env, funcs, func_type_idxs, tables, mems, globals, tags }
      }
      Ok(env)
    }
  }
}

///|
pub fn validate_startsec(
  startsec : StartSec?,
  env : Env,
) -> Result[Unit, String] {
  match startsec {
    None => Ok(())
    Some(StartSec(fidx)) => {
      let FuncType(params, results) = match env.get_functype_by_funcidx(fidx) {
        None => return Err("start: invalid function index")
        Some(ft) => ft
      }
      if params.length() != 0 {
        return Err("start function must have empty parameter list")
      }
      if results.length() != 0 {
        return Err("start function must have empty result list")
      }
      Ok(())
    }
  }
}

///|
pub impl Validate for FuncIdx with validate(self, env) {
  if env.has_func(self) {
    Ok(())
  } else {
    Err("invalid func index")
  }
}

///|
pub impl Validate for TableIdx with validate(self, env) {
  match env.get_table_type(self) {
    Some(_) => Ok(())
    None => Err("invalid table index")
  }
}

///|
pub impl Validate for MemIdx with validate(self, env) {
  let MemIdx(i) = self
  match env.get_memtype(MemIdx::new(i)) {
    Some(_) => Ok(())
    None => Err("invalid mem index")
  }
}

///|
pub impl Validate for GlobalIdx with validate(self, env) {
  let GlobalIdx(i) = self
  match env.get_global_type(GlobalIdx::new(i)) {
    Some(_) => Ok(())
    None => Err("invalid global index")
  }
}

///|
pub impl Validate for ExternIdx with validate(self, env) {
  match self {
    FuncExternIdx(i) => Validate::validate(i, env)
    TableExternIdx(i) => Validate::validate(i, env)
    MemExternIdx(i) => Validate::validate(i, env)
    GlobalExternIdx(i) => Validate::validate(i, env)
    TagExternIdx(i) => Validate::validate(i, env)
  }
}

///|
pub impl Validate for Export with validate(self, env) {
  let Export(_, exi) = self
  Validate::validate(exi, env)
}

///|
pub fn validate_exportsec(
  exportsec : ExportSec?,
  env : Env,
) -> Result[Unit, String] {
  match exportsec {
    None => Ok(())
    Some(ExportSec(es)) => Validate::validate(es, env)
  }
}

///|
/// Validates the type section incrementally and extends env.global_types.
pub fn validate_typesec(typesec : TypeSec?, env0 : Env) -> Result[Env, String] {
  match typesec {
    None => Ok(env0)
    Some(TypeSec(rts)) => {
      let mut env = env0
      for rt in rts {
        env = match validate_rectype_and_extend(env, rt) {
          Ok(e) => e
          Err(t) => return Err(t)
        }
      }
      Ok(env)
    }
  }
}

///|
fn validate_rectype_and_extend(env : Env, rt : RecType) -> Result[Env, String] {
  // Validate rectype under recursive context (for RecIdx references)
  let env_rec = env_with_rectype(env, rt)

  // Validate rectype itself under env_rec
  if Validate::validate(rt, env_rec) is Err(e) {
    return Err(e)
  }

  // If ok, append its defined subtypes to env.global_types
  Ok(env.append_rectype_types(rt))
}

///|
pub fn validate_datacnt(
  datacnt_opt : DataCntSec?,
  datasec_opt : DataSec?,
) -> Result[Unit, String] {
  match datacnt_opt {
    None => Ok(())
    Some(DataCntSec(U32(n))) => {
      let actual : UInt = match datasec_opt {
        None =>
          if n == 0U {
            0U
          } else {
            return Err("datacount section present but no data section")
          }
        Some(DataSec(ds)) => ds.length().reinterpret_as_uint()
      }
      if n == actual {
        Ok(())
      } else {
        Err("datacount does not match number of data segments")
      }
    }
  }
}

///|
fn expr_uses_bulk_memory_data_count(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for ins in instrs {
    if instr_uses_bulk_memory_data_count(ins) {
      return true
    }
  }
  false
}

///|
fn instr_uses_bulk_memory_data_count(ins : Instruction) -> Bool {
  match ins {
    MemoryInit(_, _) | DataDrop(_) => true
    Block(_, Expr(body)) | Loop(_, Expr(body)) => {
      for inner in body {
        if instr_uses_bulk_memory_data_count(inner) {
          return true
        }
      }
      false
    }
    If(_, then_body, else_body) => {
      for inner in then_body {
        if instr_uses_bulk_memory_data_count(inner) {
          return true
        }
      }
      match else_body {
        Some(branch) =>
          for inner in branch {
            if instr_uses_bulk_memory_data_count(inner) {
              return true
            }
          }
        None => ()
      }
      false
    }
    TryTable(_, _, Expr(body)) => {
      for inner in body {
        if instr_uses_bulk_memory_data_count(inner) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn func_uses_bulk_memory_data_count(func : Func) -> Bool {
  match func {
    Func(_, expr) => expr_uses_bulk_memory_data_count(expr)
    TFunc(_, _, texpr) =>
      expr_uses_bulk_memory_data_count(TExpr::to_expr(texpr))
  }
}

///|
fn validate_bulk_memory_data_count_requirement(
  codesec_opt : CodeSec?,
  datacnt_opt : DataCntSec?,
  imported_func_count : Int,
) -> Result[Unit, ValidationDiagnostic] {
  if datacnt_opt is Some(_) {
    return Ok(())
  }
  match codesec_opt {
    None => Ok(())
    Some(CodeSec(funcs)) => {
      for i in 0..<funcs.length() {
        let func = funcs[i]
        if func_uses_bulk_memory_data_count(func) {
          return Err(
            ValidationDiagnostic::new(
              ValidationIssue::FunctionBody("data count section required"),
              func_idx=Some(
                FuncIdx::new((imported_func_count + i).reinterpret_as_uint()),
              ),
            ),
          )
        }
      }
      Ok(())
    }
  }
}

///|
/// Validates exports including name uniqueness requirement.
fn validate_exportsec_unique(
  exportsec : ExportSec?,
  env : Env,
) -> Result[Unit, String] {
  match exportsec {
    None => Ok(())
    Some(ExportSec(es)) => {
      // First validate all exports
      if Validate::validate(es, env) is Err(t) {
        return Err(t)
      }
      // Check for duplicate export names
      let names : Array[Name] = []
      for e in es {
        let Export(name, _) = e
        for existing in names {
          if existing == name {
            return Err("duplicate export name: " + name.0.to_string())
          }
        }
        names.push(name)
      }
      Ok(())
    }
  }
}

///|
fn validate_name_sec_total_locals(
  m : Module,
  env : Env,
  imported_func_count : Int,
  func_idx : UInt,
) -> Int? {
  let func_idx_int = func_idx.reinterpret_as_int()
  let params_len = match env.get_functype_by_funcidx(FuncIdx::new(func_idx)) {
    Some(FuncType(params, _)) => params.length()
    None => return None
  }
  if func_idx_int < imported_func_count {
    return Some(params_len)
  }
  let defined_idx = func_idx_int - imported_func_count
  match m.code_sec {
    None => None
    Some(CodeSec(funcs)) =>
      match funcs.get(defined_idx) {
        Some(Func(locals, _)) => Some(params_len + locals.length())
        Some(TFunc(_, locals, _)) => Some(params_len + locals.length())
        None => None
      }
  }
}

///|
fn validate_name_sec_instrs_label_count(instrs : Array[Instruction]) -> Int {
  let mut total = 0
  for instr in instrs {
    total += validate_name_sec_instr_label_count(instr)
  }
  total
}

///|
fn validate_name_sec_instr_label_count(instr : Instruction) -> Int {
  match instr {
    Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
      1 + validate_name_sec_expr_label_count(body)
    If(_, then_instrs, else_instrs) => {
      let else_count = match else_instrs {
        Some(instrs) => validate_name_sec_instrs_label_count(instrs)
        None => 0
      }
      1 + validate_name_sec_instrs_label_count(then_instrs) + else_count
    }
    _ => 0
  }
}

///|
fn validate_name_sec_expr_label_count(expr : Expr) -> Int {
  let Expr(instrs) = expr
  validate_name_sec_instrs_label_count(instrs)
}

///|
fn validate_name_sec_tinstrs_label_count(instrs : Array[TInstr]) -> Int {
  let mut total = 0
  for instr in instrs {
    total += validate_name_sec_tinstr_label_count(instr)
  }
  total
}

///|
fn validate_name_sec_tinstr_label_count(instr : TInstr) -> Int {
  match instr.kind {
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      1 + validate_name_sec_texpr_label_count(body)
    TIf(_, _, then_instrs, else_instrs) => {
      let else_count = match else_instrs {
        Some(instrs) => validate_name_sec_texpr_label_count(instrs)
        None => 0
      }
      1 + validate_name_sec_texpr_label_count(then_instrs) + else_count
    }
    _ => 0
  }
}

///|
fn validate_name_sec_texpr_label_count(expr : TExpr) -> Int {
  validate_name_sec_tinstrs_label_count(expr.instrs)
}

///|
fn validate_name_sec_total_labels(
  m : Module,
  env : Env,
  imported_func_count : Int,
  func_idx : UInt,
) -> Int? {
  if !env.has_func(FuncIdx::new(func_idx)) {
    return None
  }
  let func_idx_int = func_idx.reinterpret_as_int()
  if func_idx_int < imported_func_count {
    return Some(0)
  }
  let defined_idx = func_idx_int - imported_func_count
  match m.code_sec {
    None => None
    Some(CodeSec(funcs)) =>
      match funcs.get(defined_idx) {
        Some(Func(_, expr)) => Some(validate_name_sec_expr_label_count(expr))
        Some(TFunc(_, _, expr)) =>
          Some(validate_name_sec_texpr_label_count(expr))
        None => None
      }
  }
}

///|
fn validate_name_sec(
  m : Module,
  env : Env,
  imported_func_count : Int,
) -> Result[Unit, String] {
  for custom in m.custom_secs {
    let CustomSec(name, _) = custom
    if name == Name::new("name") {
      return Err("raw name custom section is unsupported; use Module.name_sec")
    }
  }
  let name_sec = match m.name_sec {
    Some(sec) => sec
    None => return Ok(())
  }
  match name_sec.func_names {
    Some(NameMap(entries)) =>
      for entry in entries {
        let NameAssoc(func_idx, _) = entry
        if !env.has_func(FuncIdx::new(func_idx)) {
          return Err(
            "function name index out of range: func=\{func_idx} total_funcs=\{env.funcs.length()}",
          )
        }
      }
    None => ()
  }
  match name_sec.local_names {
    Some(IndirectNameMap(entries)) =>
      for entry in entries {
        let IndirectNameAssoc(func_idx, NameMap(local_entries)) = entry
        let total_locals = match
          validate_name_sec_total_locals(m, env, imported_func_count, func_idx) {
          Some(total) => total
          None =>
            return Err(
              "local names reference missing function: func=\{func_idx}",
            )
        }
        for local_entry in local_entries {
          let NameAssoc(local_idx, _) = local_entry
          if local_idx.reinterpret_as_int() >= total_locals {
            return Err(
              "local name index out of range: func=\{func_idx} local=\{local_idx} total_locals=\{total_locals}",
            )
          }
        }
      }
    None => ()
  }
  match name_sec.label_names {
    Some(IndirectNameMap(entries)) =>
      for entry in entries {
        let IndirectNameAssoc(func_idx, NameMap(label_entries)) = entry
        let total_labels = match
          validate_name_sec_total_labels(m, env, imported_func_count, func_idx) {
          Some(total) => total
          None =>
            return Err(
              "label names reference missing function: func=\{func_idx}",
            )
        }
        for label_entry in label_entries {
          let NameAssoc(label_idx, _) = label_entry
          if label_idx.reinterpret_as_int() >= total_labels {
            return Err(
              "label name index out of range: func=\{func_idx} label=\{label_idx} total_labels=\{total_labels}",
            )
          }
        }
      }
    None => ()
  }
  match name_sec.type_names {
    Some(NameMap(entries)) =>
      for entry in entries {
        let NameAssoc(type_idx, _) = entry
        if env.resolve_subtype(TypeIdx::new(type_idx)) is None {
          return Err(
            "type name index out of range: type=\{type_idx} total_types=\{env.global_types.length()}",
          )
        }
      }
    None => ()
  }
  match name_sec.table_names {
    Some(NameMap(entries)) =>
      for entry in entries {
        let NameAssoc(table_idx, _) = entry
        if env.get_table_type(TableIdx::new(table_idx)) is None {
          return Err(
            "table name index out of range: table=\{table_idx} total_tables=\{env.tables.length()}",
          )
        }
      }
    None => ()
  }
  match name_sec.memory_names {
    Some(NameMap(entries)) =>
      for entry in entries {
        let NameAssoc(mem_idx, _) = entry
        if env.get_memtype(MemIdx::new(mem_idx)) is None {
          return Err(
            "memory name index out of range: memory=\{mem_idx} total_memories=\{env.mems.length()}",
          )
        }
      }
    None => ()
  }
  match name_sec.global_names {
    Some(NameMap(entries)) =>
      for entry in entries {
        let NameAssoc(global_idx, _) = entry
        if env.get_global_type(GlobalIdx::new(global_idx)) is None {
          return Err(
            "global name index out of range: global=\{global_idx} total_globals=\{env.globals.length()}",
          )
        }
      }
    None => ()
  }
  match name_sec.elem_names {
    Some(NameMap(entries)) =>
      for entry in entries {
        let NameAssoc(elem_idx, _) = entry
        if env.get_elem(ElemIdx::new(elem_idx)) is None {
          return Err(
            "elem name index out of range: elem=\{elem_idx} total_elem=\{env.elems.length()}",
          )
        }
      }
    None => ()
  }
  match name_sec.data_names {
    Some(NameMap(entries)) =>
      for entry in entries {
        let NameAssoc(data_idx, _) = entry
        if !env.has_data(DataIdx::new(data_idx)) {
          return Err(
            "data name index out of range: data=\{data_idx} total_data=\{env.datas.length()}",
          )
        }
      }
    None => ()
  }
  match name_sec.field_names {
    Some(IndirectNameMap(entries)) =>
      for entry in entries {
        let IndirectNameAssoc(type_idx, NameMap(field_entries)) = entry
        let fields = match env.resolve_comptype(TypeIdx::new(type_idx)) {
          Some(StructCompType(fields)) => fields
          Some(_) =>
            return Err("field names require struct type: type=\{type_idx}")
          None =>
            return Err(
              "field name type index out of range: type=\{type_idx} total_types=\{env.global_types.length()}",
            )
        }
        for field_entry in field_entries {
          let NameAssoc(field_idx, _) = field_entry
          if field_idx.reinterpret_as_int() >= fields.length() {
            return Err(
              "field name index out of range: type=\{type_idx} field=\{field_idx} total_fields=\{fields.length()}",
            )
          }
        }
      }
    None => ()
  }
  match name_sec.tag_names {
    Some(NameMap(entries)) =>
      for entry in entries {
        let NameAssoc(tag_idx, _) = entry
        if env.get_tag(TagIdx::new(tag_idx)) is None {
          return Err(
            "tag name index out of range: tag=\{tag_idx} total_tags=\{env.tags.length()}",
          )
        }
      }
    None => ()
  }
  Ok(())
}

///|
fn mark_declared_func(declared : Array[Bool], f : FuncIdx) -> Unit {
  let FuncIdx(i) = f
  let ii = i.reinterpret_as_int()
  if ii >= 0 && ii < declared.length() {
    declared[ii] = true
  }
}

///|
fn mark_declared_ref_funcs_in_instr(
  instr : Instruction,
  declared : Array[Bool],
) -> Unit {
  match instr {
    RefFunc(f) => mark_declared_func(declared, f)
    Block(_, Expr(body)) | Loop(_, Expr(body)) =>
      for inner in body {
        mark_declared_ref_funcs_in_instr(inner, declared)
      }
    If(_, then_body, else_body) => {
      for inner in then_body {
        mark_declared_ref_funcs_in_instr(inner, declared)
      }
      match else_body {
        Some(branch) =>
          for inner in branch {
            mark_declared_ref_funcs_in_instr(inner, declared)
          }
        None => ()
      }
    }
    TryTable(_, _, Expr(body)) =>
      for inner in body {
        mark_declared_ref_funcs_in_instr(inner, declared)
      }
    _ => ()
  }
}

///|
fn mark_declared_ref_funcs_in_expr(expr : Expr, declared : Array[Bool]) -> Unit {
  let Expr(instrs) = expr
  for instr in instrs {
    mark_declared_ref_funcs_in_instr(instr, declared)
  }
}

///|
fn collect_declared_funcs_bitmap(mod : Module, env : Env) -> Array[Bool] {
  let declared = Array::make(env.funcs.length(), false)

  // Declaration sources are module sites outside function bodies, excluding
  // start. This includes exports, const-expression ref.funcs in globals/tables
  // and elem expressions, plus elem segments with raw function indices.
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for exp in exports {
        match exp {
          Export(_, FuncExternIdx(f)) => mark_declared_func(declared, f)
          _ => ()
        }
      }
    None => ()
  }

  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(_, init) = global
        mark_declared_ref_funcs_in_expr(init, declared)
      }
    None => ()
  }

  match mod.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(_, init_opt) = table
        match init_opt {
          Some(init) => mark_declared_ref_funcs_in_expr(init, declared)
          None => ()
        }
      }
    None => ()
  }

  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(_, kind) = elem
        match kind {
          FuncsElemKind(funcs) =>
            for f in funcs {
              mark_declared_func(declared, f)
            }
          FuncExprsElemKind(exprs) | TypedExprsElemKind(_, exprs) =>
            for expr in exprs {
              mark_declared_ref_funcs_in_expr(expr, declared)
            }
        }
      }
    None => ()
  }

  declared
}

///|
fn is_declared_ref_func(declared : Array[Bool], f : FuncIdx) -> Bool {
  let FuncIdx(i) = f
  let ii = i.reinterpret_as_int()
  ii >= 0 && ii < declared.length() && declared[ii]
}

///|
fn validate_ref_func_declarations_in_instr(
  instr : Instruction,
  env : Env,
  declared : Array[Bool],
) -> Result[Unit, String] {
  match instr {
    RefFunc(f) => {
      if env.has_func(f) && !is_declared_ref_func(declared, f) {
        return Err("undeclared function reference: \{f}")
      }
      Ok(())
    }
    Block(_, Expr(body)) | Loop(_, Expr(body)) => {
      for inner in body {
        if validate_ref_func_declarations_in_instr(inner, env, declared)
          is Err(e) {
          return Err(e)
        }
      }
      Ok(())
    }
    If(_, then_body, else_body) => {
      for inner in then_body {
        if validate_ref_func_declarations_in_instr(inner, env, declared)
          is Err(e) {
          return Err(e)
        }
      }
      match else_body {
        Some(branch) =>
          for inner in branch {
            if validate_ref_func_declarations_in_instr(inner, env, declared)
              is Err(e) {
              return Err(e)
            }
          }
        None => ()
      }
      Ok(())
    }
    TryTable(_, _, Expr(body)) => {
      for inner in body {
        if validate_ref_func_declarations_in_instr(inner, env, declared)
          is Err(e) {
          return Err(e)
        }
      }
      Ok(())
    }
    _ => Ok(())
  }
}

///|
fn validate_ref_func_declarations_in_expr(
  expr : Expr,
  env : Env,
  declared : Array[Bool],
) -> Result[Unit, String] {
  let Expr(instrs) = expr
  for instr in instrs {
    if validate_ref_func_declarations_in_instr(instr, env, declared) is Err(e) {
      return Err(e)
    }
  }
  Ok(())
}

///|
fn validate_ref_func_declarations_in_module(
  mod : Module,
  env : Env,
  imported_func_count : Int,
  declared : Array[Bool],
  trace? : (String) -> Unit = validate_trace_noop,
  trace_all_funcs? : Bool = false,
  trace_enabled? : Bool = false,
) -> Result[Unit, ValidationDiagnostic] {
  let globals_count = match mod.global_sec {
    Some(GlobalSec(globals)) => globals.length()
    None => 0
  }
  let globals_start_ms = if trace_enabled {
    trace("phase=ref_func_declarations:globals:start count=\{globals_count}")
    validate_trace_now_ms()
  } else {
    0UL
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(_, init) = global
        if validate_ref_func_declarations_in_expr(init, env, declared) is Err(e) {
          return Err(
            ValidationDiagnostic::new(ValidationIssue::GlobalSection(e)),
          )
        }
      }
    None => ()
  }
  if trace_enabled {
    trace(
      "phase=ref_func_declarations:globals:done elapsed_ms=\{validate_trace_elapsed_ms(globals_start_ms)}",
    )
  }

  let tables_count = match mod.table_sec {
    Some(TableSec(tables)) => tables.length()
    None => 0
  }
  let tables_start_ms = if trace_enabled {
    trace("phase=ref_func_declarations:tables:start count=\{tables_count}")
    validate_trace_now_ms()
  } else {
    0UL
  }
  match mod.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(_, init_opt) = table
        match init_opt {
          Some(init) =>
            if validate_ref_func_declarations_in_expr(init, env, declared)
              is Err(e) {
              return Err(
                ValidationDiagnostic::new(ValidationIssue::TableSection(e)),
              )
            }
          None => ()
        }
      }
    None => ()
  }
  if trace_enabled {
    trace(
      "phase=ref_func_declarations:tables:done elapsed_ms=\{validate_trace_elapsed_ms(tables_start_ms)}",
    )
  }

  let elems_count = match mod.elem_sec {
    Some(ElemSec(elems)) => elems.length()
    None => 0
  }
  let elems_start_ms = if trace_enabled {
    trace("phase=ref_func_declarations:elems:start count=\{elems_count}")
    validate_trace_now_ms()
  } else {
    0UL
  }
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(_, kind) = elem
        match kind {
          FuncsElemKind(_) => ()
          FuncExprsElemKind(exprs) | TypedExprsElemKind(_, exprs) =>
            for expr in exprs {
              if validate_ref_func_declarations_in_expr(expr, env, declared)
                is Err(e) {
                return Err(
                  ValidationDiagnostic::new(ValidationIssue::ElementSection(e)),
                )
              }
            }
        }
      }
    None => ()
  }
  if trace_enabled {
    trace(
      "phase=ref_func_declarations:elems:done elapsed_ms=\{validate_trace_elapsed_ms(elems_start_ms)}",
    )
  }

  let code_func_count = match mod.code_sec {
    Some(CodeSec(bodies)) => bodies.length()
    None => 0
  }
  let codesec_start_ms = if trace_enabled {
    trace("phase=ref_func_declarations:codesec:start funcs=\{code_func_count}")
    validate_trace_now_ms()
  } else {
    0UL
  }
  match (mod.code_sec, mod.func_sec) {
    (Some(CodeSec(bodies)), Some(FuncSec(type_idxs))) => {
      if bodies.length() != type_idxs.length() {
        return Ok(())
      }
      for i in 0..<bodies.length() {
        let ordinal = i + 1
        let log_func = if trace_enabled {
          validate_trace_log_enabled(ordinal, trace_all_funcs)
        } else {
          false
        }
        if log_func {
          trace("phase=ref_func_declarations:codesec func[\{ordinal}] start")
        }
        let func_idx = FuncIdx::new(
          (imported_func_count + i).reinterpret_as_uint(),
        )
        let body_expr = match bodies[i] {
          Func(_, expr) => expr
          TFunc(_, _, texpr) => TExpr::to_expr(texpr)
        }
        match validate_ref_func_declarations_in_expr(body_expr, env, declared) {
          Ok(_) => ()
          Err(t) =>
            return Err(
              ValidationDiagnostic::new(
                ValidationIssue::FunctionBody(t),
                func_idx=Some(func_idx),
              ),
            )
        }
        if log_func {
          trace("phase=ref_func_declarations:codesec func[\{ordinal}] done")
        }
        let scanned = i + 1
        if trace_enabled &&
          (
            scanned % VALIDATE_REF_FUNC_DECL_TRACE_HEARTBEAT == 0 ||
            scanned == bodies.length()
          ) {
          trace(
            "phase=ref_func_declarations:codesec:progress scanned=\{scanned} total=\{bodies.length()} elapsed_ms=\{validate_trace_elapsed_ms(codesec_start_ms)}",
          )
        }
      }
      if trace_enabled {
        trace(
          "phase=ref_func_declarations:codesec:done elapsed_ms=\{validate_trace_elapsed_ms(codesec_start_ms)}",
        )
      }
      Ok(())
    }
    _ => {
      if trace_enabled {
        trace(
          "phase=ref_func_declarations:codesec:done elapsed_ms=\{validate_trace_elapsed_ms(codesec_start_ms)}",
        )
      }
      Ok(())
    }
  }
}

///|
/// Validates a whole module from an empty context, building its Env incrementally.
fn validate_trace_module_error(
  trace : (String) -> Unit,
  validate_start_ms : UInt64,
  phase : String,
  phase_start_ms : UInt64,
  diag : ValidationDiagnostic,
  trace_enabled : Bool,
) -> Result[Unit, ValidationDiagnostic] {
  if !trace_enabled {
    return Err(diag)
  }
  let phase_elapsed_ms = validate_trace_elapsed_ms(phase_start_ms)
  validate_phase_timing_commit(phase, phase_elapsed_ms)
  trace("phase=\{phase}:error elapsed_ms=\{phase_elapsed_ms} \{diag}")
  validate_trace_emit_totals(trace)
  trace(
    "pass[validate_module]:error elapsed_ms=\{validate_trace_elapsed_ms(validate_start_ms)} \{diag}",
  )
  Err(diag)
}

///|
/// Validates a whole module from an empty context, building its Env incrementally.
fn validate_module_impl(
  m : Module,
  trace? : (String) -> Unit = validate_trace_noop,
  trace_all_funcs? : Bool = false,
  trace_enabled? : Bool = false,
) -> Result[Unit, ValidationDiagnostic] {
  if trace_enabled {
    validate_helper_timing_reset()
    validate_phase_timing_reset()
    validate_hotspot_reset()
  }
  let {
    type_sec: typesec_opt,
    import_sec: importsec_opt,
    func_sec: funcsec_opt,
    table_sec: tablesec_opt,
    mem_sec: memsec_opt,
    tag_sec: tagsec_opt,
    global_sec: globalsec_opt,
    export_sec: exportsec_opt,
    start_sec: startsec_opt,
    elem_sec: elemsec_opt,
    data_cnt_sec: datacntsec_opt,
    code_sec: codesec_opt,
    data_sec: datasec_opt,
    ..,
  } = m

  let declared_funcs = match funcsec_opt {
    Some(FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
  let code_bodies = match codesec_opt {
    Some(CodeSec(bodies)) => bodies.length()
    None => 0
  }
  let validate_start_ms = if trace_enabled {
    validate_trace_now_ms()
  } else {
    0UL
  }
  if trace_enabled {
    trace(
      "pass[validate_module]:start declared_funcs=\{declared_funcs} code_bodies=\{code_bodies}",
    )
  }

  // Start from empty env (module validation does not take an external env)
  let mut env = empty_env()

  // (1) Types: defines global type index space
  let typesec_start_ms = validate_trace_phase_start(
    trace, "typesec", trace_enabled,
  )
  env = match validate_typesec(typesec_opt, env) {
    Ok(e) => {
      validate_trace_phase_done(
        trace, "typesec", typesec_start_ms, trace_enabled,
      )
      e
    }
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "typesec",
        typesec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::TypeSection(t)),
        trace_enabled,
      )
  }

  // (2) Imports: extend funcs/tables/mems/globals/tags index spaces
  let importsec_start_ms = validate_trace_phase_start(
    trace, "importsec", trace_enabled,
  )
  env = match validate_importsec(importsec_opt, env) {
    Ok(e) => {
      validate_trace_phase_done(
        trace, "importsec", importsec_start_ms, trace_enabled,
      )
      e
    }
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "importsec",
        importsec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::ImportSection(t)),
        trace_enabled,
      )
  }
  let imported_func_count = env.funcs.length()

  // (3) Function declarations (defined funcs): extend env.funcs
  let funcsec_start_ms = validate_trace_phase_start(
    trace, "funcsec", trace_enabled,
  )
  env = match validate_funcsec(funcsec_opt, env) {
    Ok(e) => {
      validate_trace_phase_done(
        trace, "funcsec", funcsec_start_ms, trace_enabled,
      )
      e
    }
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "funcsec",
        funcsec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::FunctionSection(t)),
        trace_enabled,
      )
  }

  // (4) Tables / Memories / Tags / Globals: extend their index spaces
  let tablesec_start_ms = validate_trace_phase_start(
    trace, "tablesec", trace_enabled,
  )
  env = match validate_tablesec(tablesec_opt, env) {
    Ok(e) => {
      validate_trace_phase_done(
        trace, "tablesec", tablesec_start_ms, trace_enabled,
      )
      e
    }
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "tablesec",
        tablesec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::TableSection(t)),
        trace_enabled,
      )
  }
  let memsec_start_ms = validate_trace_phase_start(
    trace, "memsec", trace_enabled,
  )
  env = match validate_memsec(memsec_opt, env) {
    Ok(e) => {
      validate_trace_phase_done(trace, "memsec", memsec_start_ms, trace_enabled)
      e
    }
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "memsec",
        memsec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::MemorySection(t)),
        trace_enabled,
      )
  }
  let tagsec_start_ms = validate_trace_phase_start(
    trace, "tagsec", trace_enabled,
  )
  env = match validate_tagsec(tagsec_opt, env) {
    Ok(e) => {
      validate_trace_phase_done(trace, "tagsec", tagsec_start_ms, trace_enabled)
      e
    }
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "tagsec",
        tagsec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::TagSection(t)),
        trace_enabled,
      )
  }
  let globalsec_start_ms = validate_trace_phase_start(
    trace, "globalsec", trace_enabled,
  )
  env = match validate_globalsec(globalsec_opt, env) {
    Ok(e) => {
      validate_trace_phase_done(
        trace, "globalsec", globalsec_start_ms, trace_enabled,
      )
      e
    }
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "globalsec",
        globalsec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::GlobalSection(t)),
        trace_enabled,
      )
  }

  // (5) Elements / Data: extend elems/datas (needed by instructions)
  let elemsec_start_ms = validate_trace_phase_start(
    trace, "elemsec", trace_enabled,
  )
  env = match validate_elemsec(elemsec_opt, env) {
    Ok(e) => {
      validate_trace_phase_done(
        trace, "elemsec", elemsec_start_ms, trace_enabled,
      )
      e
    }
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "elemsec",
        elemsec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::ElementSection(t)),
        trace_enabled,
      )
  }
  let datasec_start_ms = validate_trace_phase_start(
    trace, "datasec", trace_enabled,
  )
  env = match validate_datasec(datasec_opt, env) {
    Ok(e) => {
      validate_trace_phase_done(
        trace, "datasec", datasec_start_ms, trace_enabled,
      )
      e
    }
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "datasec",
        datasec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::DataSection(t)),
        trace_enabled,
      )
  }

  // (6) DataCount section cross-check
  let datacnt_start_ms = validate_trace_phase_start(
    trace, "datacnt", trace_enabled,
  )
  match validate_datacnt(datacntsec_opt, datasec_opt) {
    Ok(_) =>
      validate_trace_phase_done(
        trace, "datacnt", datacnt_start_ms, trace_enabled,
      )
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "datacnt",
        datacnt_start_ms,
        ValidationDiagnostic::new(ValidationIssue::DataCountSection(t)),
        trace_enabled,
      )
  }
  let datacnt_required_start_ms = validate_trace_phase_start(
    trace, "datacnt_requirement", trace_enabled,
  )
  match
    validate_bulk_memory_data_count_requirement(
      codesec_opt, datacntsec_opt, imported_func_count,
    ) {
    Ok(_) =>
      validate_trace_phase_done(
        trace, "datacnt_requirement", datacnt_required_start_ms, trace_enabled,
      )
    Err(t) =>
      return validate_trace_module_error(
        trace, validate_start_ms, "datacnt_requirement", datacnt_required_start_ms,
        t, trace_enabled,
      )
  }

  // (7) Start function validation
  let start_func_idx = match startsec_opt {
    Some(StartSec(fidx)) => Some(fidx)
    None => None
  }
  let startsec_start_ms = validate_trace_phase_start(
    trace, "startsec", trace_enabled,
  )
  match validate_startsec(startsec_opt, env) {
    Ok(_) =>
      validate_trace_phase_done(
        trace, "startsec", startsec_start_ms, trace_enabled,
      )
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "startsec",
        startsec_start_ms,
        ValidationDiagnostic::new(
          ValidationIssue::StartSection(t),
          func_idx=start_func_idx,
        ),
        trace_enabled,
      )
  }

  // (8) Exports: validate indices and check name uniqueness
  let exportsec_start_ms = validate_trace_phase_start(
    trace, "exportsec", trace_enabled,
  )
  match validate_exportsec_unique(exportsec_opt, env) {
    Ok(_) =>
      validate_trace_phase_done(
        trace, "exportsec", exportsec_start_ms, trace_enabled,
      )
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "exportsec",
        exportsec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::ExportSection(t)),
        trace_enabled,
      )
  }

  let ref_func_decl_start_ms = validate_trace_phase_start(
    trace, "ref_func_declarations", trace_enabled,
  )
  let declared_funcs = collect_declared_funcs_bitmap(m, env)
  match
    validate_ref_func_declarations_in_module(
      m,
      env,
      imported_func_count,
      declared_funcs,
      trace~,
      trace_all_funcs~,
      trace_enabled~,
    ) {
    Ok(_) =>
      validate_trace_phase_done(
        trace, "ref_func_declarations", ref_func_decl_start_ms, trace_enabled,
      )
    Err(t) =>
      return validate_trace_module_error(
        trace, validate_start_ms, "ref_func_declarations", ref_func_decl_start_ms,
        t, trace_enabled,
      )
  }

  // (9) Code: typecheck each function body against env.funcs
  let codesec_start_ms = validate_trace_phase_start(
    trace, "codesec", trace_enabled,
  )
  match
    validate_codesec_diag(
      codesec_opt,
      funcsec_opt,
      env,
      trace~,
      trace_all_funcs~,
      helper_timing_enabled=trace_enabled,
    ) {
    Ok(_) =>
      validate_trace_phase_done(
        trace, "codesec", codesec_start_ms, trace_enabled,
      )
    Err(t) =>
      return validate_trace_module_error(
        trace, validate_start_ms, "codesec", codesec_start_ms, t, trace_enabled,
      )
  }
  let namesec_start_ms = validate_trace_phase_start(
    trace, "namesec", trace_enabled,
  )
  match validate_name_sec(m, env, imported_func_count) {
    Ok(_) =>
      validate_trace_phase_done(
        trace, "namesec", namesec_start_ms, trace_enabled,
      )
    Err(t) =>
      return validate_trace_module_error(
        trace,
        validate_start_ms,
        "namesec",
        namesec_start_ms,
        ValidationDiagnostic::new(ValidationIssue::NameSection(t)),
        trace_enabled,
      )
  }
  if trace_enabled {
    validate_trace_emit_totals(trace)
    trace(
      "pass[validate_module]:done elapsed_ms=\{validate_trace_elapsed_ms(validate_start_ms)}",
    )
  }
  Ok(())
}

///|
pub fn validate_module_with_trace(
  m : Module,
  trace : (String) -> Unit,
  trace_all_funcs? : Bool = false,
) -> Result[Unit, ValidationError] {
  match validate_module_impl(m, trace~, trace_all_funcs~, trace_enabled=true) {
    Ok(_) => Ok(())
    Err(diag) => Err(ValidationError::Validation(diag))
  }
}

///|
pub fn validate_module(m : Module) -> Result[Unit, ValidationError] {
  match validate_module_impl(m) {
    Ok(_) => Ok(())
    Err(diag) => Err(ValidationError::Validation(diag))
  }
}

///|
fn validate_fuzz_ascii_lower(input : String) -> String {
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
pub struct ValidateValidFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  validated : Int
} derive(Eq, Show, Debug)

///|
pub fn run_validate_valid_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[ValidateValidFuzzStats, String] {
  let normalized = validate_fuzz_ascii_lower(profile.trim().to_string())
  let attempts = match normalized {
    "smoke" => 128
    "ci" => 5000
    "stress" => 100000
    _ =>
      return Err(
        "unknown validate-valid fuzz profile '\{profile}'; expected smoke|ci|stress",
      )
  }
  let rnd = @splitmix.new(seed~)
  let mut validated = 0
  let mut iteration = 0
  loop attempts {
    0 => break ()
    n => {
      iteration += 1
      let mod = gen_valid_module(rnd)
      match validate_module(mod) {
        Ok(_) => validated += 1
        Err(err) =>
          return Err(
            "validate-valid fuzz failed: profile=\{normalized} seed=\{seed} iteration=\{iteration} error=\{validation_error_message(err)}",
          )
      }
      continue n - 1
    }
  }
  Ok(ValidateValidFuzzStats::{ profile: normalized, seed, attempts, validated })
}

///|
test "run_validate_valid_fuzz rejects unknown profile" {
  match run_validate_valid_fuzz("not-a-profile", 0x5eedUL) {
    Ok(_) => fail("expected unknown profile error")
    Err(msg) => assert_true(msg.contains("unknown validate-valid fuzz profile"))
  }
}

///|
test "validate_module reports typed ValidationError variant" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new([]))]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("dup"), ExternIdx::func(FuncIdx::new(0U))),
        Export::new(Name::new("dup"), ExternIdx::func(FuncIdx::new(0U))),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => fail("expected duplicate export validation failure")
    Err(err) => {
      let diag = validation_error_diagnostic(err)
      assert_eq(diag.func_idx, None)
      assert_true(
        validation_error_message(err).contains("duplicate export name"),
      )
    }
  }
}

///|
test "validate_module requires data count section for memory.init and data.drop" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mem = MemType::new(Limits::i32(1, None))
  let data = Data::new(DataMode::passive(), b"x")

  let mem_init_mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_mem_sec(MemSec::new([mem]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::i32_const(I32(0)),
            Instruction::i32_const(I32(0)),
            Instruction::i32_const(I32(0)),
            Instruction::memory_init(DataIdx::new(0), MemIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_data_sec(DataSec::new([data]))
  match validate_module(mem_init_mod) {
    Ok(_) => fail("expected memory.init without datacount to fail")
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      assert_true(
        validation_error_message(err).contains("data count section required"),
      )
    }
  }

  let data_drop_mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([Instruction::data_drop(DataIdx::new(0))]),
        ),
      ]),
    )
    .with_data_sec(DataSec::new([data]))
  match validate_module(data_drop_mod) {
    Ok(_) => fail("expected data.drop without datacount to fail")
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      assert_true(
        validation_error_message(err).contains("data count section required"),
      )
    }
  }
}

///|
test "validate_module rejects typed function with missing explicit params" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], Locals::from_types([ValType::i32()]), TExpr::new([])),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => fail("expected typed function params mismatch to fail validation")
    Err(err) =>
      assert_true(
        validation_error_message(err).contains(
          "typed function params must match declared signature exactly",
        ),
      )
  }
}

///|
test "validate_module rejects legacy typed locals that duplicate param prefix" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          Locals::from_types([ValType::i32(), ValType::i64()]),
          TExpr::new([
            TInstr::local_set(LocalIdx::new(1), TInstr::i64_const(I64(7))),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => fail("expected duplicated param-prefix locals to fail validation")
    Err(_) => ()
  }
}

///|
test "validate_module accepts typed try_table with param input" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          Locals::empty(),
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::try_table(
              BlockType::type_idx(TypeIdx::new(0U)),
              [],
              TExpr::new([TInstr::return_call(FuncIdx::new(1U), [])]),
            ),
          ]),
        ),
        Func::t_func(
          [ValType::i32()],
          Locals::empty(),
          TExpr::new([TInstr::drop(TInstr::local_get(LocalIdx::new(0)))]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "validate_module accepts typed block with control-flow input params" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          Locals::empty(),
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0U)),
            TInstr::block(BlockType::type_idx(TypeIdx::new(0U)), TExpr::new([])),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "validate_module accepts typed if with control-flow input params" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let func_sig = RecType::new(
    SubType::comp_type(
      CompType::func([ValType::i32(), ValType::i32()], [ValType::i32()]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig, func_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32(), ValType::i32()],
          Locals::empty(),
          TExpr::new([
            TInstr::local_get(LocalIdx::new(1U)),
            TInstr::if_(
              BlockType::type_idx(TypeIdx::new(0U)),
              TInstr::local_get(LocalIdx::new(0U)),
              TExpr::new([]),
              Some(TExpr::new([])),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "validate_module accepts typed loop with control-flow input params" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          Locals::empty(),
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0U)),
            TInstr::loop_(BlockType::type_idx(TypeIdx::new(0U)), TExpr::new([])),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "validate_module accepts typed nested outer-label branch if" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          Locals::empty(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::drop(
                  TInstr::if_(
                    BlockType::val_type(ValType::i32()),
                    TInstr::local_get(LocalIdx::new(0U)),
                    TExpr::new([TInstr::i32_const(I32(1000))]),
                    Some(
                      TExpr::new([
                        TInstr::if_(
                          BlockType::void_(),
                          TInstr::local_get(LocalIdx::new(0U)),
                          TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
                          Some(TExpr::new([TInstr::br(LabelIdx::new(2), [])])),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            TInstr::i32_const(I32(0)),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "validate_module accepts typed block result supplied by nested outer-label branch" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          Locals::empty(),
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(7))]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "validate_module rejects undeclared function reference in body" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::ref_func(FuncIdx::new(0U)),
            Instruction::drop(),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => fail("expected undeclared function reference to fail validation")
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      assert_true(
        validation_error_message(err).contains("undeclared function reference"),
      )
    }
  }
}

///|
test "validate_module does not treat start as a ref.func declaration source" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_start_sec(StartSec::new(FuncIdx::new(0U)))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::ref_func(FuncIdx::new(0U)),
            Instruction::drop(),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) =>
      fail(
        "expected start entry alone to be insufficient for ref.func declaration",
      )
    Err(err) =>
      assert_true(
        validation_error_message(err).contains("undeclared function reference"),
      )
  }
}

///|
test "validate_module accepts ref.func body when function is exported" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::ref_func(FuncIdx::new(0U)),
            Instruction::drop(),
          ]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("f"), ExternIdx::func(FuncIdx::new(0U))),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exported function to count as declared for ref.func: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module treats global initializer ref.func as declaration source" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::funcref(), false),
          Expr::new([Instruction::ref_func(FuncIdx::new(0U))]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new([]))]))
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected global initializer ref.func declaration source to validate: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module treats table initializer ref.func as declaration source" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(1, None),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_table_sec(
      TableSec::new([
        Table::new(
          table_type,
          Some(Expr::new([Instruction::ref_func(FuncIdx::new(0U))])),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new([]))]))
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected table initializer ref.func declaration source to validate: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module treats elem expression ref.func as declaration source" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let elem = Elem::new(
    ElemMode::passive(),
    ElemKind::typed_exprs(
      RefType::new(true, HeapType::abs(AbsHeapType::func())),
      [Expr::new([Instruction::ref_func(FuncIdx::new(0U))])],
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_elem_sec(ElemSec::new([elem]))
    .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new([]))]))
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected elem expression ref.func declaration source to validate: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module accepts ref.func in elem expression when elem.funcs declares the function" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let decls = Elem::new(
    ElemMode::declarative(),
    ElemKind::funcs([FuncIdx::new(0U)]),
  )
  let elem_expr = Elem::new(
    ElemMode::passive(),
    ElemKind::typed_exprs(
      RefType::new(true, HeapType::abs(AbsHeapType::func())),
      [Expr::new([Instruction::ref_func(FuncIdx::new(0U))])],
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_elem_sec(ElemSec::new([decls, elem_expr]))
    .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new([]))]))
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected elem expression ref.func to validate when declared by elem.funcs: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module accepts ref.func in global initializer when function is exported" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::funcref(), false),
          Expr::new([Instruction::ref_func(FuncIdx::new(0U))]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("f"), ExternIdx::func(FuncIdx::new(0U))),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new([]))]))
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exported function declaration source to allow global initializer ref.func: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module rejects mixed declared and undeclared ref.func uses in one body" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("declared"), ExternIdx::func(FuncIdx::new(0U))),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::new(Locals::empty(), Expr::new([])),
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::ref_func(FuncIdx::new(0U)),
            Instruction::drop(),
            Instruction::ref_func(FuncIdx::new(1U)),
            Instruction::drop(),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) =>
      fail(
        "expected mixed declared/undeclared ref.func uses to fail validation",
      )
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(1U)))
      assert_true(
        validation_error_message(err).contains("undeclared function reference"),
      )
    }
  }
}

///|
test "validate_module accepts global initializer global.get from earlier immutable module global" {
  let mod = Module::new().with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([Instruction::i32_const(I32(7))]),
      ),
      Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([Instruction::global_get(GlobalIdx::new(0U))]),
      ),
    ]),
  )
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected extended-const global.get from earlier immutable global to validate: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module accepts global initializer global.get from imported immutable global" {
  let mod = Module::new()
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("g"),
          ExternType::global(GlobalType::new(ValType::i32(), false)),
        ),
      ]),
    )
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::global_get(GlobalIdx::new(0U))]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected imported immutable global.get in const expression to validate: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module rejects global initializer global.get from imported mutable global" {
  let mod = Module::new()
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("g"),
          ExternType::global(GlobalType::new(ValType::i32(), true)),
        ),
      ]),
    )
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::global_get(GlobalIdx::new(0U))]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => fail("expected mutable imported global.get in const expr to fail")
    Err(err) => assert_true(validation_error_message(err).contains("constant"))
  }
}

///|
test "validate_module rejects global initializer global.get from earlier mutable module global" {
  let mod = Module::new().with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::i32(), true),
        Expr::new([Instruction::i32_const(I32(7))]),
      ),
      Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([Instruction::global_get(GlobalIdx::new(0U))]),
      ),
    ]),
  )
  match validate_module(mod) {
    Ok(_) =>
      fail("expected mutable module global.get in const expression to fail")
    Err(err) => assert_true(validation_error_message(err).contains("constant"))
  }
}

///|
test "validate_module accepts table initializer global.get from imported immutable ref global" {
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(2, None),
  )
  let mod = Module::new()
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("g"),
          ExternType::global(
            GlobalType::new(
              ValType::ref_type(
                RefType::new(true, HeapType::abs(AbsHeapType::func())),
              ),
              false,
            ),
          ),
        ),
      ]),
    )
    .with_table_sec(
      TableSec::new([
        Table::new(
          table_type,
          Some(Expr::new([Instruction::global_get(GlobalIdx::new(0U))])),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected table initializer global.get from immutable imported global to validate: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module rejects data offset with non-constant instruction sequence" {
  let mod = Module::new()
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_data_sec(
      DataSec::new([
        Data::new(
          DataMode::active(
            MemIdx::new(0U),
            Expr::new([
              Instruction::i32_const(I32(1)),
              Instruction::i32_const(I32(2)),
              Instruction::i32_add(),
            ]),
          ),
          b"x",
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => fail("expected non-constant data offset expression to fail")
    Err(err) => assert_true(validation_error_message(err).contains("constant"))
  }
}

///|
test "validate_module accepts ref.null in const global initializer" {
  let mod = Module::new().with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::funcref(), false),
        Expr::new([Instruction::ref_null(HeapType::abs(AbsHeapType::func()))]),
      ),
    ]),
  )
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected ref.null const global initializer to validate: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module accepts descriptor-bearing struct.new_default_desc const initializers" {
  let descriptor_group = RecType::group([
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(descriptor=Some(TypeIdx::new(1U))),
    ),
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(describes=Some(TypeIdx::new(0U))),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([descriptor_group]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("desc"),
          ExternType::global(
            GlobalType::new(
              ValType::ref_type(
                RefType::new(true, HeapType::new(TypeIdx::new(1U)), exact=true),
              ),
              false,
            ),
          ),
        ),
      ]),
    )
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(
            ValType::ref_type(
              RefType::new(false, HeapType::new(TypeIdx::new(0U)), exact=true),
            ),
            false,
          ),
          Expr::new([
            Instruction::global_get(GlobalIdx::new(0U)),
            Instruction::struct_new_default_desc(TypeIdx::new(0U)),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected descriptor-bearing const initializer to validate: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module rejects descriptor clauses on non-struct types" {
  let bad_group = RecType::new(
    SubType::comp_type(
      CompType::func([], []),
      metadata=TypeMetadata::new(descriptor=Some(TypeIdx::new(0U))),
    ),
  )
  let mod = Module::new().with_type_sec(TypeSec::new([bad_group]))
  match validate_module(mod) {
    Ok(_) => fail("expected non-struct descriptor metadata to fail validation")
    Err(err) =>
      assert_true(
        validation_error_message(err).contains("only appear on struct"),
      )
  }
}

///|
test "validate_module rejects describes targets that are not previously defined" {
  let bad_group = RecType::group([
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(describes=Some(TypeIdx::new(1U))),
    ),
    SubType::comp_type(CompType::struct_([])),
  ])
  let mod = Module::new().with_type_sec(TypeSec::new([bad_group]))
  match validate_module(mod) {
    Ok(_) => fail("expected forward describes target to fail validation")
    Err(err) =>
      assert_true(validation_error_message(err).contains("previously defined"))
  }
}

///|
test "validate_module rejects tail loop that leaves function result missing" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::loop_(
              BlockType::void_(),
              Expr::new([Instruction::br(LabelIdx::new(0))]),
            ),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) =>
      fail(
        "expected missing i32 function result after tail loop to fail validation",
      )
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      let msg = validation_error_message(err)
      assert_true(msg.contains("function body result stack underflow"))
      assert_true(msg.contains("expected stack="))
      assert_true(msg.contains("actual stack="))
      assert_true(msg.contains("I32"))
    }
  }
}

///|
test "validate_module reports end-of-body underflow with stack shape" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new([]))]))
  match validate_module(mod) {
    Ok(_) => fail("expected missing function result to fail validation")
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      let msg = validation_error_message(err)
      assert_true(msg.contains("function body result stack underflow"))
      assert_true(msg.contains("expected stack="))
      assert_true(msg.contains("actual stack="))
      assert_true(msg.contains("I32"))
    }
  }
}

///|
test "validate_module reports wrong end-of-body result type with stack shape" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(Locals::empty(), Expr::new([Instruction::f32_const(0.0)])),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => fail("expected wrong function result type to fail validation")
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      let msg = validation_error_message(err)
      assert_true(msg.contains("function body result type mismatch"))
      assert_true(msg.contains("expected stack="))
      assert_true(msg.contains("actual stack="))
      assert_true(msg.contains("I32"))
      assert_true(msg.contains("F32"))
    }
  }
}

///|
test "validate_module reports end-of-body extra values with stack shape" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(Locals::empty(), Expr::new([Instruction::i32_const(I32(1))])),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => fail("expected extra stack values to fail validation")
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      let msg = validation_error_message(err)
      assert_true(msg.contains("function body leaves extra values on stack"))
      assert_true(msg.contains("expected stack="))
      assert_true(msg.contains("actual stack="))
      assert_true(msg.contains("I32"))
    }
  }
}

///|
test "validate_module rejects concrete stack junk after return inside block" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::block(
              BlockType::void_(),
              Expr::new([Instruction::return_(), Instruction::i32_const(I32(1))]),
            ),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) =>
      fail("expected block to reject concrete stack values left after return")
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      assert_true(validation_error_message(err).length() > 0)
    }
  }
}

///|
test "validate_module rejects wrong concrete loop result after infinite inner loop" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::loop_(
              BlockType::val_type(ValType::i32()),
              Expr::new([
                Instruction::loop_(
                  BlockType::void_(),
                  Expr::new([Instruction::br(LabelIdx::new(0))]),
                ),
                Instruction::f32_const(0.0),
              ]),
            ),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) =>
      fail(
        "expected loop to reject wrong concrete result left after an infinite inner loop",
      )
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      assert_true(validation_error_message(err).length() > 0)
    }
  }
}

///|
test "validate_module rejects outer if result missing after inner current-label branches" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::block(
              BlockType::void_(),
              Expr::new([
                Instruction::local_get(LocalIdx::new(0U)),
                Instruction::i32_const(I32(0)),
                Instruction::i32_eq(),
                Instruction::if_(
                  BlockType::val_type(ValType::i32()),
                  [Instruction::i32_const(I32(1000))],
                  Some([
                    Instruction::local_get(LocalIdx::new(0U)),
                    Instruction::i32_const(I32(999)),
                    Instruction::i32_eq(),
                    Instruction::if_(
                      BlockType::void_(),
                      [Instruction::br(LabelIdx::new(0))],
                      Some([Instruction::br(LabelIdx::new(0))]),
                    ),
                  ]),
                ),
                Instruction::drop(),
              ]),
            ),
            Instruction::i32_const(I32(0)),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) =>
      fail(
        "expected missing outer if result after inner current-label branches to fail validation",
      )
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      assert_true(validation_error_message(err).length() > 0)
    }
  }
}

///|
test "validate_module rejects outer if result missing after nested outer-label branches" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::block(
              BlockType::void_(),
              Expr::new([
                Instruction::local_get(LocalIdx::new(0U)),
                Instruction::if_(
                  BlockType::val_type(ValType::i32()),
                  [Instruction::i32_const(I32(1000))],
                  Some([
                    Instruction::local_get(LocalIdx::new(0U)),
                    Instruction::i32_const(I32(999)),
                    Instruction::i32_eq(),
                    Instruction::if_(
                      BlockType::void_(),
                      [Instruction::br(LabelIdx::new(2))],
                      Some([Instruction::br(LabelIdx::new(2))]),
                    ),
                  ]),
                ),
                Instruction::drop(),
              ]),
            ),
            Instruction::i32_const(I32(0)),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) =>
      fail(
        "expected nested outer-label branches to leave the outer if result missing",
      )
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      assert_true(validation_error_message(err).length() > 0)
    }
  }
}

// ============ NumType Tests ============

///|
test "NumType validates successfully" {
  let env = empty_env()
  assert_eq(Validate::validate(NumType::f32(), env), Ok(()))
  assert_eq(Validate::validate(NumType::f64(), env), Ok(()))
  assert_eq(Validate::validate(NumType::i32(), env), Ok(()))
  assert_eq(Validate::validate(NumType::i64(), env), Ok(()))
}

// ============ AbsHeapType Tests ============

///|
test "AbsHeapType validates successfully" {
  let env = empty_env()
  assert_eq(Validate::validate(AbsHeapType::exn(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::array(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::struct_(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::i31(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::eq(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::any(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::extern_(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::func(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::none(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::no_extern(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::no_func(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::no_exn(), env), Ok(()))
}

// ============ HeapType Tests ============

///|
test "HeapType with AbsHeapType validates" {
  let env = empty_env()
  let ht = HeapType::abs(AbsHeapType::func())
  assert_eq(Validate::validate(ht, env), Ok(()))
}

///|
test "HeapType with invalid TypeIdx fails" {
  let env = empty_env()
  let ht = HeapType::new(TypeIdx::new(0))
  assert_eq(Validate::validate(ht, env), Err("No type exists for TypeIdx"))
}

///|
test "HeapType with valid TypeIdx succeeds" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st])
  let ht = HeapType::new(TypeIdx::new(0))
  assert_eq(Validate::validate(ht, env), Ok(()))
}

// ============ ValType Tests ============

///|
test "ValType NumType validates" {
  let env = empty_env()
  let vt = ValType::i32()
  assert_eq(Validate::validate(vt, env), Ok(()))
}

///|
test "ValType VecType validates" {
  let env = empty_env()
  let t = ValType::v128()
  assert_eq(Validate::validate(t, env), Ok(()))
}

///|
test "ValType BotType validates" {
  let env = empty_env()
  let t = ValType::bottom()
  assert_eq(Validate::validate(t, env), Ok(()))
}

///|
test "ValType RefType with AbsHeapType validates" {
  let env = empty_env()
  let rt = RefType::abs(AbsHeapType::func())
  let vt = ValType::ref_type(rt)
  assert_eq(Validate::validate(vt, env), Ok(()))
}

// ============ RefType Tests ============

///|
test "RefType HeapTypeRefType with valid AbsHeapType validates" {
  let env = empty_env()
  let rt = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  assert_eq(Validate::validate(rt, env), Ok(()))
}

///|
test "RefType HeapTypeRefType nullable and non-nullable validate" {
  let env = empty_env()
  let rt_null = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let rt_non_null = RefType::new(false, HeapType::abs(AbsHeapType::func()))
  assert_eq(Validate::validate(rt_null, env), Ok(()))
  assert_eq(Validate::validate(rt_non_null, env), Ok(()))
}

// ============ TypeIdx Tests ============

///|
test "TypeIdx validates when type exists" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st])
  let tidx = TypeIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Ok(()))
}

///|
test "TypeIdx fails when type does not exist" {
  let env = empty_env()
  let tidx = TypeIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Err("No type exists for TypeIdx"))
}

///|
test "TypeIdx fails with out of bounds index" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st])
  let tidx = TypeIdx::new(5)
  assert_eq(Validate::validate(tidx, env), Err("No type exists for TypeIdx"))
}

// ============ LabelIdx Tests ============

///|
test "LabelIdx validates when label exists" {
  let env = empty_env().with_labels([[]])
  let lidx = LabelIdx::new(0)
  assert_eq(Validate::validate(lidx, env), Ok(()))
}

///|
test "LabelIdx fails when label does not exist" {
  let env = empty_env()
  let lidx = LabelIdx::new(0)
  assert_eq(Validate::validate(lidx, env), Err("Invalid LabelIdx"))
}

///|
test "LabelIdx fails with out of bounds index" {
  let env = empty_env().with_labels([[]])
  let lidx = LabelIdx::new(5)
  assert_eq(Validate::validate(lidx, env), Err("Invalid LabelIdx"))
}

// ============ TagIdx Tests ============

///|
test "TagIdx validates when tag exists" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env()
    .with_types([st])
    .with_tags([TagType::new(TypeIdx::new(0))])
  let tidx = TagIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Ok(()))
}

///|
test "TagIdx fails when tag does not exist" {
  let env = empty_env()
  let tidx = TagIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Err("Invalid TagIdx"))
}

// ============ FuncIdx Tests ============

///|
test "FuncIdx validates when func exists" {
  let env = empty_env().with_funcs([FuncType::new([], [])])
  let fidx = FuncIdx::new(0)
  assert_eq(Validate::validate(fidx, env), Ok(()))
}

///|
test "FuncIdx fails when func does not exist" {
  let env = empty_env()
  let fidx = FuncIdx::new(0)
  assert_eq(Validate::validate(fidx, env), Err("invalid func index"))
}

// ============ TableIdx Tests ============

///|
test "TableIdx validates when table exists" {
  let rt = RefType::abs(AbsHeapType::func())
  let tt = TableType::new(rt, Limits::i32(0, None))
  let env = empty_env().with_tables([tt])
  let tidx = TableIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Ok(()))
}

///|
test "TableIdx fails when table does not exist" {
  let env = empty_env()
  let tidx = TableIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Err("invalid table index"))
}

// ============ MemIdx Tests ============

///|
test "MemIdx validates when memory exists" {
  let mt = MemType::new(Limits::i32(0, None))
  let env = empty_env().with_mems([mt])
  let midx = MemIdx::new(0)
  assert_eq(Validate::validate(midx, env), Ok(()))
}

///|
test "MemIdx fails when memory does not exist" {
  let env = empty_env()
  let midx = MemIdx::new(0)
  assert_eq(Validate::validate(midx, env), Err("invalid mem index"))
}

// ============ GlobalIdx Tests ============

///|
test "GlobalIdx validates when global exists" {
  let gt = GlobalType::new(ValType::i32(), false)
  let env = empty_env().with_globals([gt])
  let gidx = GlobalIdx::new(0)
  assert_eq(Validate::validate(gidx, env), Ok(()))
}

///|
test "GlobalIdx fails when global does not exist" {
  let env = empty_env()
  let gidx = GlobalIdx::new(0)
  assert_eq(Validate::validate(gidx, env), Err("invalid global index"))
}

// ============ Limits Tests (ValidateMax) ============

///|
test "I32Limits validates within max" {
  let env = empty_env()
  let lim = Limits::i32(10, Some(100))
  assert_eq(ValidateMax::validate_max(lim, env, 1000), Ok(()))
}

///|
test "I32Limits validates with no upper bound" {
  let env = empty_env()
  let lim = Limits::i32(10, None)
  assert_eq(ValidateMax::validate_max(lim, env, 1000), Ok(()))
}

///|
test "I32Limits fails when n exceeds k" {
  let env = empty_env()
  let lim = Limits::i32(2000, None)
  assert_eq(
    ValidateMax::validate_max(lim, env, 1000),
    Err("Invalid range for limits"),
  )
}

///|
test "I32Limits fails when m exceeds k" {
  let env = empty_env()
  let lim = Limits::i32(10, Some(2000))
  assert_eq(
    ValidateMax::validate_max(lim, env, 1000),
    Err("Invalid range for limits"),
  )
}

///|
test "I32Limits fails when n exceeds m" {
  let env = empty_env()
  let lim = Limits::i32(100, Some(10))
  assert_eq(
    ValidateMax::validate_max(lim, env, 1000),
    Err("Invalid range for limits"),
  )
}

///|
test "I64Limits validates within max" {
  let env = empty_env()
  let lim = Limits::i64(10, Some(100))
  assert_eq(ValidateMax::validate_max(lim, env, 1000), Ok(()))
}

// ============ MemType Tests ============

///|
test "MemType validates with valid limits" {
  let env = empty_env()
  let mt = MemType::new(Limits::i32(0, Some(100)))
  assert_eq(Validate::validate(mt, env), Ok(()))
}

///|
test "MemType fails when limits exceed 65536" {
  let env = empty_env()
  let mt = MemType::new(Limits::i32(0, Some(100000)))
  assert_eq(Validate::validate(mt, env), Err("Invalid range for limits"))
}

// ============ TableType Tests ============

///|
test "TableType validates with valid ref type and limits" {
  let env = empty_env()
  let rt = RefType::abs(AbsHeapType::func())
  let tt = TableType::new(rt, Limits::i32(0, Some(100)))
  assert_eq(Validate::validate(tt, env), Ok(()))
}

// ============ GlobalType Tests ============

///|
test "GlobalType validates with NumType" {
  let env = empty_env()
  let gt = GlobalType::new(ValType::i32(), false)
  assert_eq(Validate::validate(gt, env), Ok(()))
}

///|
test "GlobalType validates mutable" {
  let env = empty_env()
  let gt = GlobalType::new(ValType::i64(), true)
  assert_eq(Validate::validate(gt, env), Ok(()))
}

// ============ StorageType Tests ============

///|
test "StorageType ValType validates" {
  let env = empty_env()
  let st = StorageType::val_type(ValType::i32())
  assert_eq(Validate::validate(st, env), Ok(()))
}

///|
test "StorageType PackType validates" {
  let env = empty_env()
  let st = StorageType::pack_type(PackType::i8())
  assert_eq(Validate::validate(st, env), Ok(()))
}

// ============ FieldType Tests ============

///|
test "FieldType validates" {
  let env = empty_env()
  let ft = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  assert_eq(Validate::validate(ft, env), Ok(()))
}

// ============ FuncType Tests ============

///|
test "FuncType with empty params and results validates" {
  let env = empty_env()
  let ft = FuncType::new([], [])
  assert_eq(Validate::validate(ft, env), Ok(()))
}

///|
test "FuncType with params and results validates" {
  let env = empty_env()
  let ft = FuncType::new([ValType::i32()], [ValType::i64()])
  assert_eq(Validate::validate(ft, env), Ok(()))
}

// ============ CompType Tests ============

///|
test "CompType FuncCompType validates" {
  let env = empty_env()
  let ct = SubType::comp_type(CompType::func([], []))
  assert_eq(Validate::validate(ct, env), Ok(()))
}

///|
test "CompType ArrayCompType validates" {
  let env = empty_env()
  let ft = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ct = SubType::comp_type(CompType::array(ft))
  assert_eq(Validate::validate(ct, env), Ok(()))
}

///|
test "CompType StructCompType validates" {
  let env = empty_env()
  let ft = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ct = SubType::comp_type(CompType::struct_([ft]))
  assert_eq(Validate::validate(ct, env), Ok(()))
}

///|
test "CompType StructCompType empty validates" {
  let env = empty_env()
  let ct = SubType::comp_type(CompType::struct_([]))
  assert_eq(Validate::validate(ct, env), Ok(()))
}

// ============ SubType Tests ============

///|
test "SubType CompTypeSubType validates" {
  let env = empty_env()
  let st = SubType::comp_type(CompType::func([], []))
  assert_eq(Validate::validate(st, env), Ok(()))
}

// ============ RecType Tests ============

///|
test "RecType SingleRecType validates" {
  let env = empty_env()
  let st = SubType::comp_type(CompType::func([], []))
  let rt = RecType::new(st)
  assert_eq(Validate::validate(rt, env), Ok(()))
}

///|
test "RecType GroupRecType validates" {
  let env = empty_env()
  let st1 = SubType::comp_type(CompType::func([], []))
  let st2 = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::val_type(ValType::i32()), Const),
    ),
  )
  let rt = RecType::group([st1, st2])
  assert_eq(Validate::validate(rt, env), Ok(()))
}

// ============ Array[T] Validate Tests ============

///|
test "Array of ValType validates" {
  let env = empty_env()
  let arr : Array[ValType] = [ValType::i32(), ValType::i64()]
  assert_eq(Validate::validate(arr, env), Ok(()))
}

///|
test "Empty array validates" {
  let env = empty_env()
  let arr : Array[ValType] = []
  assert_eq(Validate::validate(arr, env), Ok(()))
}

// ============ BlockType Tests ============

///|
test "BlockType VoidBlockType validates" {
  let env = empty_env()
  assert_eq(Validate::validate(BlockType::void_(), env), Ok(()))
}

///|
test "BlockType ValTypeBlockType validates" {
  let env = empty_env()
  let bt = BlockType::val_type(ValType::i32())
  assert_eq(Validate::validate(bt, env), Ok(()))
}

///|
test "BlockType TypeIdxBlockType with valid func type validates" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st])
  let bt = BlockType::type_idx(TypeIdx::new(0))
  assert_eq(Validate::validate(bt, env), Ok(()))
}

///|
test "BlockType TypeIdxBlockType with invalid index fails" {
  let env = empty_env()
  let bt = BlockType::type_idx(TypeIdx::new(0))
  assert_eq(Validate::validate(bt, env), Err("Invalid TypeIdx for block type"))
}

///|
test "BlockType TypeIdxBlockType with non-func type fails" {
  let st = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::val_type(ValType::i32()), Const),
    ),
  )
  let env = empty_env().with_types([st])
  let bt = BlockType::type_idx(TypeIdx::new(0))
  assert_eq(
    Validate::validate(bt, env),
    Err("Expected Func Type for block type"),
  )
}

// ============ ExternType Tests ============

///|
test "ExternType GlobalExternType validates" {
  let env = empty_env()
  let gt = GlobalType::new(ValType::i32(), false)
  let et = ExternType::global(gt)
  assert_eq(Validate::validate(et, env), Ok(()))
}

///|
test "ExternType MemExternType validates" {
  let env = empty_env()
  let mt = MemType::new(Limits::i32(0, Some(10)))
  let et = ExternType::mem(mt)
  assert_eq(Validate::validate(et, env), Ok(()))
}

///|
test "ExternType TableExternType validates" {
  let env = empty_env()
  let rt = RefType::abs(AbsHeapType::func())
  let tt = TableType::new(rt, Limits::i32(0, Some(100)))
  let et = ExternType::table(tt)
  assert_eq(Validate::validate(et, env), Ok(()))
}

///|
test "ExternType FuncExternType validates when func type exists" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st])
  let et = ExternType::func(TypeIdx::new(0))
  assert_eq(Validate::validate(et, env), Ok(()))
}

///|
test "ExternType FuncExternType fails when func type missing" {
  let env = empty_env()
  let et = ExternType::func(TypeIdx::new(0))
  assert_eq(
    Validate::validate(et, env),
    Err("Invalid ExternType: Func extern type not found"),
  )
}

// ============ ExternIdx Tests ============

///|
test "ExternIdx FuncExternIdx validates" {
  let env = empty_env().with_funcs([FuncType::new([], [])])
  let ei = ExternIdx::func(FuncIdx::new(0))
  assert_eq(Validate::validate(ei, env), Ok(()))
}

///|
test "ExternIdx TableExternIdx validates" {
  let rt = RefType::abs(AbsHeapType::func())
  let tt = TableType::new(rt, Limits::i32(0, None))
  let env = empty_env().with_tables([tt])
  let ei = ExternIdx::table(TableIdx::new(0))
  assert_eq(Validate::validate(ei, env), Ok(()))
}

///|
test "ExternIdx MemExternIdx validates" {
  let mt = MemType::new(Limits::i32(0, None))
  let env = empty_env().with_mems([mt])
  let ei = ExternIdx::mem(MemIdx::new(0))
  assert_eq(Validate::validate(ei, env), Ok(()))
}

///|
test "ExternIdx GlobalExternIdx validates" {
  let gt = GlobalType::new(ValType::i32(), false)
  let env = empty_env().with_globals([gt])
  let ei = ExternIdx::global(GlobalIdx::new(0))
  assert_eq(Validate::validate(ei, env), Ok(()))
}

// ============ Export Tests ============

///|
test "Export with valid FuncExternIdx validates" {
  let env = empty_env().with_funcs([FuncType::new([], [])])
  let exp = Export::new(Name::new("test"), ExternIdx::func(FuncIdx::new(0)))
  assert_eq(Validate::validate(exp, env), Ok(()))
}

///|
test "Export with invalid index fails" {
  let env = empty_env()
  let exp = Export::new(Name::new("test"), ExternIdx::func(FuncIdx::new(0)))
  assert_eq(Validate::validate(exp, env), Err("invalid func index"))
}

// ============ Import Tests ============

///|
test "Import with valid GlobalExternType validates" {
  let env = empty_env()
  let gt = GlobalType::new(ValType::i32(), false)
  let imp = Import::new(
    Name::new("mod"),
    Name::new("name"),
    ExternType::global(gt),
  )
  assert_eq(Validate::validate(imp, env), Ok(()))
}

// ============ DataMode Tests ============

///|
test "DataMode Passive validates" {
  let env = empty_env()
  assert_eq(Validate::validate(DataMode::passive(), env), Ok(()))
}

// ============ Data Tests ============

///|
test "Data with Passive mode validates" {
  let env = empty_env()
  let d = Data::new(DataMode::passive(), b"hello")
  assert_eq(Validate::validate(d, env), Ok(()))
}

// ============ Catch Tests ============

///|
test "Catch CatchAll validates with valid label" {
  let env = empty_env().with_labels([[]])
  let c = Catch::all(LabelIdx::new(0))
  assert_eq(Validate::validate(c, env), Ok(()))
}

///|
test "Catch CatchAllRef validates with valid label" {
  let env = empty_env().with_labels([[]])
  let c = Catch::all_ref(LabelIdx::new(0))
  assert_eq(Validate::validate(c, env), Ok(()))
}

///|
test "Catch CatchAll fails with invalid label" {
  let env = empty_env()
  let c = Catch::all(LabelIdx::new(0))
  assert_eq(Validate::validate(c, env), Err("Invalid LabelIdx"))
}

///|
fn validate_name_section_fixture_module() -> Module {
  let struct_type = RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Const),
      ]),
    ),
  )
  let func_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let tag_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(1U, Some(1U)),
  )
  let name_sec = NameSec::new(
    module_name=Some(Name::new("fixture")),
    func_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("id"))])),
    local_names=Some(
      IndirectNameMap::new([
        IndirectNameAssoc::new(
          0U,
          NameMap::new([NameAssoc::new(0U, Name::new("x"))]),
        ),
      ]),
    ),
    label_names=Some(
      IndirectNameMap::new([
        IndirectNameAssoc::new(
          0U,
          NameMap::new([
            NameAssoc::new(0U, Name::new("entry")),
            NameAssoc::new(1U, Name::new("repeat")),
            NameAssoc::new(2U, Name::new("branch")),
          ]),
        ),
      ]),
    ),
    type_names=Some(
      NameMap::new([
        NameAssoc::new(0U, Name::new("Pair")),
        NameAssoc::new(1U, Name::new("IdSig")),
        NameAssoc::new(2U, Name::new("TagSig")),
      ]),
    ),
    table_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("dispatch"))])),
    memory_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("heap"))])),
    global_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("flag"))])),
    elem_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("targets"))])),
    data_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("blob"))])),
    field_names=Some(
      IndirectNameMap::new([
        IndirectNameAssoc::new(
          0U,
          NameMap::new([NameAssoc::new(0U, Name::new("value"))]),
        ),
      ]),
    ),
    tag_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("boom"))])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([struct_type, func_type, tag_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
  .with_table_sec(TableSec::new([Table::new(table_type, None)]))
  .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(2U))]))
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([Instruction::i32_const(I32(1))]),
      ),
    ]),
  )
  .with_elem_sec(
    ElemSec::new([
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_data_sec(
    DataSec::new([
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        b"fixture",
      ),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::block(BlockType::void_(), Expr::new([])),
          Instruction::loop_(BlockType::void_(), Expr::new([])),
          Instruction::i32_const(I32(1)),
          Instruction::if_(BlockType::void_(), [], Some([])),
          Instruction::local_get(LocalIdx::new(0U)),
        ]),
      ),
    ]),
  )
  .with_name_sec(name_sec)
}

///|
test "validate_module accepts structured name section" {
  let mod = validate_name_section_fixture_module()
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "validate_module rejects out-of-range local name index in name section" {
  let mod = validate_name_section_fixture_module().with_name_sec(
    NameSec::new(
      module_name=Some(Name::new("fixture")),
      func_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("id"))])),
      local_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([NameAssoc::new(1U, Name::new("bad"))]),
          ),
        ]),
      ),
      label_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([
              NameAssoc::new(0U, Name::new("entry")),
              NameAssoc::new(1U, Name::new("repeat")),
              NameAssoc::new(2U, Name::new("branch")),
            ]),
          ),
        ]),
      ),
      type_names=Some(
        NameMap::new([
          NameAssoc::new(0U, Name::new("Pair")),
          NameAssoc::new(1U, Name::new("IdSig")),
          NameAssoc::new(2U, Name::new("TagSig")),
        ]),
      ),
      table_names=Some(
        NameMap::new([NameAssoc::new(0U, Name::new("dispatch"))]),
      ),
      memory_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("heap"))])),
      global_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("flag"))])),
      elem_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("targets"))])),
      data_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("blob"))])),
      field_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([NameAssoc::new(0U, Name::new("value"))]),
          ),
        ]),
      ),
      tag_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("boom"))])),
    ),
  )

  match validate_module(mod) {
    Ok(_) => fail("expected invalid local name section validation failure")
    Err(err) => {
      assert_true(
        validation_error_message(err).contains("local name index out of range"),
      )
      assert_eq(
        validation_error_diagnostic(err).issue,
        ValidationIssue::NameSection(
          "local name index out of range: func=0 local=1 total_locals=1",
        ),
      )
    }
  }
}

///|
test "validate_module rejects out-of-range label name index in name section" {
  let mod = validate_name_section_fixture_module().with_name_sec(
    NameSec::new(
      module_name=Some(Name::new("fixture")),
      func_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("id"))])),
      local_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([NameAssoc::new(0U, Name::new("x"))]),
          ),
        ]),
      ),
      label_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([NameAssoc::new(3U, Name::new("too-far"))]),
          ),
        ]),
      ),
      type_names=Some(
        NameMap::new([
          NameAssoc::new(0U, Name::new("Pair")),
          NameAssoc::new(1U, Name::new("IdSig")),
          NameAssoc::new(2U, Name::new("TagSig")),
        ]),
      ),
      table_names=Some(
        NameMap::new([NameAssoc::new(0U, Name::new("dispatch"))]),
      ),
      memory_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("heap"))])),
      global_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("flag"))])),
      elem_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("targets"))])),
      data_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("blob"))])),
      field_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([NameAssoc::new(0U, Name::new("value"))]),
          ),
        ]),
      ),
      tag_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("boom"))])),
    ),
  )

  match validate_module(mod) {
    Ok(_) => fail("expected invalid label name section validation failure")
    Err(err) => {
      assert_true(
        validation_error_message(err).contains("label name index out of range"),
      )
      assert_eq(
        validation_error_diagnostic(err).issue,
        ValidationIssue::NameSection(
          "label name index out of range: func=0 label=3 total_labels=3",
        ),
      )
    }
  }
}

///|
test "validate_module rejects out-of-range data name index in name section" {
  let mod = validate_name_section_fixture_module().with_name_sec(
    NameSec::new(
      module_name=Some(Name::new("fixture")),
      func_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("id"))])),
      local_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([NameAssoc::new(0U, Name::new("x"))]),
          ),
        ]),
      ),
      label_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([
              NameAssoc::new(0U, Name::new("entry")),
              NameAssoc::new(1U, Name::new("repeat")),
              NameAssoc::new(2U, Name::new("branch")),
            ]),
          ),
        ]),
      ),
      type_names=Some(
        NameMap::new([
          NameAssoc::new(0U, Name::new("Pair")),
          NameAssoc::new(1U, Name::new("IdSig")),
          NameAssoc::new(2U, Name::new("TagSig")),
        ]),
      ),
      table_names=Some(
        NameMap::new([NameAssoc::new(0U, Name::new("dispatch"))]),
      ),
      memory_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("heap"))])),
      global_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("flag"))])),
      elem_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("targets"))])),
      data_names=Some(NameMap::new([NameAssoc::new(1U, Name::new("bad"))])),
      field_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([NameAssoc::new(0U, Name::new("value"))]),
          ),
        ]),
      ),
      tag_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("boom"))])),
    ),
  )

  match validate_module(mod) {
    Ok(_) => fail("expected invalid data name section validation failure")
    Err(err) => {
      assert_true(
        validation_error_message(err).contains("data name index out of range"),
      )
      assert_eq(
        validation_error_diagnostic(err).issue,
        ValidationIssue::NameSection(
          "data name index out of range: data=1 total_data=1",
        ),
      )
    }
  }
}
