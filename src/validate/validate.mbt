///|
pub fn diff(rt1 : RefType, rt2 : RefType) -> Result[RefType, String] {
  let ht1 = rt1.get_heap_type()
  let n1 = rt1.is_nullable()
  let n2 = rt2.is_nullable()

  // Result nullability: nullable only if rt1 was nullable AND rt2 was not
  let null_out = n1 && !n2
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
  }
}

///|
fn validate_func_trace_top_instrs(func : Func) -> Int {
  match func {
    Func(_, Expr(instrs)) => instrs.length()
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
      group_relative_absolute_index(base, group_len, rel)
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
  match group_member_relative_index(base, sts.length(), target_abs) {
    Some(rel_idx) => return sts.get(rel_idx)
    None => ()
  }
  env.resolve_subtype(target)
}

///|
fn validate_descriptor_metadata_group(
  sts : Array[SubType],
  env : Env,
) -> Result[Unit, String] {
  // When the current rectype is already appended to `env`, recover its suffix
  // start. Standalone `RecType` validation can also call this before append, in
  // which case the current group starts immediately after the existing types.
  let base = match suffix_start_index(env.global_types.length(), sts.length()) {
    Some(base) => base
    None => env.global_types.length()
  }
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
  let MemType(lim, shared) = self
  if shared {
    match lim {
      I32Limits(_, Some(_)) | I64Limits(_, Some(_)) => ()
      _ => return Err("shared memories require a max")
    }
  }
  let max_pages = match lim {
    I32Limits(_, _) => 65536UL
    I64Limits(_, _) => 18446744073709551615UL
  }
  ValidateMax::validate_max(lim, env, max_pages)
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
    StringConst(_) => Ok(())
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
    I32Eqz
    | I32Eq
    | I32Ne
    | I32LtS
    | I32LtU
    | I32GtS
    | I32GtU
    | I32LeS
    | I32LeU
    | I32GeS
    | I32GeU
    | I64Eqz
    | I64Eq
    | I64Ne
    | I64LtS
    | I64LtU
    | I64GtS
    | I64GtU
    | I64LeS
    | I64LeU
    | I64GeS
    | I64GeU
    | F32Eq
    | F32Ne
    | F32Lt
    | F32Gt
    | F32Le
    | F32Ge
    | F64Eq
    | F64Ne
    | F64Lt
    | F64Gt
    | F64Le
    | F64Ge
    | I32Clz
    | I32Ctz
    | I32Popcnt
    | I32Add
    | I32Sub
    | I32Mul
    | I32DivS
    | I32DivU
    | I32RemS
    | I32RemU
    | I32And
    | I32Or
    | I32Xor
    | I32Shl
    | I32ShrS
    | I32ShrU
    | I32Rotl
    | I32Rotr
    | I64Clz
    | I64Ctz
    | I64Popcnt
    | I64Add
    | I64Sub
    | I64Mul
    | I64DivS
    | I64DivU
    | I64RemS
    | I64RemU
    | I64And
    | I64Or
    | I64Xor
    | I64Shl
    | I64ShrS
    | I64ShrU
    | I64Rotl
    | I64Rotr
    | F32Abs
    | F32Neg
    | F32Ceil
    | F32Floor
    | F32Trunc
    | F32Nearest
    | F32Sqrt
    | F32Add
    | F32Sub
    | F32Mul
    | F32Div
    | F32Min
    | F32Max
    | F32Copysign
    | F64Abs
    | F64Neg
    | F64Ceil
    | F64Floor
    | F64Trunc
    | F64Nearest
    | F64Sqrt
    | F64Add
    | F64Sub
    | F64Mul
    | F64Div
    | F64Min
    | F64Max
    | F64Copysign
    | I32WrapI64
    | I32TruncF32S
    | I32TruncF32U
    | I32TruncF64S
    | I32TruncF64U
    | I64ExtendI32S
    | I64ExtendI32U
    | I64TruncF32S
    | I64TruncF32U
    | I64TruncF64S
    | I64TruncF64U
    | F32ConvertI32S
    | F32ConvertI32U
    | F32ConvertI64S
    | F32ConvertI64U
    | F32DemoteF64
    | F64ConvertI32S
    | F64ConvertI32U
    | F64ConvertI64S
    | F64ConvertI64U
    | F64PromoteF32
    | I32ReinterpretF32
    | I64ReinterpretF64
    | F32ReinterpretI32
    | F64ReinterpretI64
    | I32Extend8S
    | I32Extend16S
    | I64Extend8S
    | I64Extend16S
    | I64Extend32S
    | RefIsNull
    | RefEq
    | RefAsNonNull
    | AnyConvertExtern
    | ExternConvertAny
    | RefI31
    | I31GetS
    | I31GetU
    | I32TruncSatF32S
    | I32TruncSatF32U
    | I32TruncSatF64S
    | I32TruncSatF64U
    | I64TruncSatF32S
    | I64TruncSatF32U
    | I64TruncSatF64S
    | I64TruncSatF64U => Ok(())
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
    labels: LabelStack::new(),
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
        .with_label(results)
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
      let n_imported = match suffix_start_index(n_total, n_defined) {
        Some(n_imported) => n_imported
        None =>
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
        let func_abs = defined_func_absolute_index(n_imported, i)
        let func_idx = FuncIdx::new(func_abs.reinterpret_as_uint())
        let ft = match env.funcs.get(func_abs) {
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
fn validate_env_before_codesec(m : Module) -> Result[Env, String] {
  let mut env = Env::new()
  env = match validate_typesec(m.type_sec, env) {
    Ok(env) => env
    Err(err) => return Err(err)
  }
  env = match validate_importsec(m.import_sec, env) {
    Ok(env) => env
    Err(err) => return Err(err)
  }
  env = match validate_funcsec(m.func_sec, env) {
    Ok(env) => env
    Err(err) => return Err(err)
  }
  env = match validate_tablesec(m.table_sec, env) {
    Ok(env) => env
    Err(err) => return Err(err)
  }
  env = match validate_memsec(m.mem_sec, env) {
    Ok(env) => env
    Err(err) => return Err(err)
  }
  env = match validate_tagsec(m.tag_sec, env) {
    Ok(env) => env
    Err(err) => return Err(err)
  }
  env = match validate_globalsec(m.global_sec, env) {
    Ok(env) => env
    Err(err) => return Err(err)
  }
  env = match validate_elemsec(m.elem_sec, env) {
    Ok(env) => env
    Err(err) => return Err(err)
  }
  env = match validate_datasec(m.data_sec, env) {
    Ok(env) => env
    Err(err) => return Err(err)
  }
  Ok(env)
}

///|
pub fn validate_defined_func_against_module(
  m : Module,
  func_idx : FuncIdx,
  f : Func,
) -> Result[Unit, String] {
  let env = match validate_env_before_codesec(m) {
    Ok(env) => env
    Err(err) => return Err(err)
  }
  let ft = match env.get_functype_by_funcidx(func_idx) {
    Some(ft) => ft
    None => return Err("missing functype for defined function")
  }
  validate_func_body_against_functype(env, ft, f)
}

///|
pub impl Validate for DataMode with validate(self, env) {
  match self {
    Passive => Ok(())
    Active(memidx, offset_expr) => {
      // memory must exist
      let MemType(lim, _) = match env.get_memtype(memidx) {
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
fn normalize_rectype_typeidx_for_global_env(
  idx : TypeIdx,
  base : Int,
  group_len : Int,
) -> TypeIdx {
  match idx {
    TypeIdx(_) => idx
    RecIdx(rel_u) =>
      match
        group_relative_absolute_index(
          base,
          group_len,
          rel_u.reinterpret_as_int(),
        ) {
        Some(abs) => TypeIdx::new(abs.reinterpret_as_uint())
        None => idx
      }
  }
}

///|
fn normalize_subtype_for_global_env(
  st : SubType,
  base : Int,
  group_len : Int,
) -> SubType {
  let metadata = st.metadata()
  let normalized_metadata = TypeMetadata::new(
    describes=metadata.describes.map(fn(idx) {
      normalize_rectype_typeidx_for_global_env(idx, base, group_len)
    }),
    descriptor=metadata.descriptor.map(fn(idx) {
      normalize_rectype_typeidx_for_global_env(idx, base, group_len)
    }),
  )
  let normalized_supers = st
    .super_types()
    .map(fn(idx) {
      normalize_rectype_typeidx_for_global_env(idx, base, group_len)
    })
  match st {
    SubType(is_final, _, _, comp) =>
      SubType::new(
        is_final,
        normalized_supers,
        comp,
        metadata=normalized_metadata,
      )
    CompTypeSubType(_, comp) =>
      SubType::comp_type(comp, metadata=normalized_metadata)
  }
}

///|
fn normalize_rectype_for_global_env(rt : RecType, base : Int) -> RecType {
  match rt {
    SingleRecType(st) =>
      RecType::new(normalize_subtype_for_global_env(st, base, 1))
    GroupRecType(sts) => {
      let normalized : Array[SubType] = []
      let group_len = sts.length()
      for st in sts {
        normalized.push(normalize_subtype_for_global_env(st, base, group_len))
      }
      RecType::group(normalized)
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

  // If ok, append its defined subtypes to env.global_types in normalized absolute form.
  let normalized = normalize_rectype_for_global_env(
    rt,
    env.global_types.length(),
  )
  Ok(env.append_rectype_types(normalized))
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
          let func_idx = match
            defined_body_func_index(imported_func_count, funcs.length(), i) {
            Some(func_abs) => FuncIdx::new(func_abs.reinterpret_as_uint())
            None => FuncIdx::new(i.reinterpret_as_uint())
          }
          return Err(
            ValidationDiagnostic::new(
              ValidationIssue::FunctionBody("data count section required"),
              func_idx=Some(func_idx),
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
  match defined_func_body_index(imported_func_count, func_idx_int) {
    None => Some(params_len)
    Some(defined_idx) =>
      match m.code_sec {
        None => None
        Some(CodeSec(funcs)) =>
          match funcs.get(defined_idx) {
            Some(Func(locals, _)) => Some(params_len + locals.length())
            None => None
          }
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
  match defined_func_body_index(imported_func_count, func_idx_int) {
    None => Some(0)
    Some(defined_idx) =>
      match m.code_sec {
        None => None
        Some(CodeSec(funcs)) =>
          match funcs.get(defined_idx) {
            Some(Func(_, expr)) =>
              Some(validate_name_sec_expr_label_count(expr))
            None => None
          }
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
        match bounded_index(env.funcs.length(), func_idx.reinterpret_as_int()) {
          Some(_) => ()
          None =>
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
          match bounded_index(total_locals, local_idx.reinterpret_as_int()) {
            Some(_) => ()
            None =>
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
          match bounded_index(total_labels, label_idx.reinterpret_as_int()) {
            Some(_) => ()
            None =>
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
        match
          bounded_index(
            env.global_types.length(),
            type_idx.reinterpret_as_int(),
          ) {
          Some(_) => ()
          None =>
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
        match
          bounded_index(env.tables.length(), table_idx.reinterpret_as_int()) {
          Some(_) => ()
          None =>
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
        match bounded_index(env.mems.length(), mem_idx.reinterpret_as_int()) {
          Some(_) => ()
          None =>
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
        match
          bounded_index(env.globals.length(), global_idx.reinterpret_as_int()) {
          Some(_) => ()
          None =>
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
        match bounded_index(env.elems.length(), elem_idx.reinterpret_as_int()) {
          Some(_) => ()
          None =>
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
        match bounded_index(env.datas.length(), data_idx.reinterpret_as_int()) {
          Some(_) => ()
          None =>
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
        match
          bounded_index(
            env.global_types.length(),
            type_idx.reinterpret_as_int(),
          ) {
          Some(_) => ()
          None =>
            return Err(
              "field name type index out of range: type=\{type_idx} total_types=\{env.global_types.length()}",
            )
        }
        let fields = match env.resolve_comptype(TypeIdx::new(type_idx)) {
          Some(StructCompType(fields)) => fields
          Some(_) =>
            return Err("field names require struct type: type=\{type_idx}")
          None =>
            return Err("field names require struct type: type=\{type_idx}")
        }
        for field_entry in field_entries {
          let NameAssoc(field_idx, _) = field_entry
          match bounded_index(fields.length(), field_idx.reinterpret_as_int()) {
            Some(_) => ()
            None =>
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
        match bounded_index(env.tags.length(), tag_idx.reinterpret_as_int()) {
          Some(_) => ()
          None =>
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
fn mark_declared_func(declared : @bitset.BitSet, f : FuncIdx) -> Unit {
  let FuncIdx(i) = f
  match bounded_index(declared.length(), i.reinterpret_as_int()) {
    Some(ii) => declared[ii] = true
    None => ()
  }
}

///|
fn mark_declared_ref_funcs_in_instr(
  instr : Instruction,
  declared : @bitset.BitSet,
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
fn mark_declared_ref_funcs_in_expr(
  expr : Expr,
  declared : @bitset.BitSet,
) -> Unit {
  let Expr(instrs) = expr
  for instr in instrs {
    mark_declared_ref_funcs_in_instr(instr, declared)
  }
}

///|
fn collect_declared_funcs_bitmap(mod : Module, env : Env) -> @bitset.BitSet {
  let declared = @bitset.BitSet::new(env.funcs.length())

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
fn is_declared_ref_func(declared : @bitset.BitSet, f : FuncIdx) -> Bool {
  let FuncIdx(i) = f
  match bounded_index(declared.length(), i.reinterpret_as_int()) {
    Some(ii) => declared[ii]
    None => false
  }
}

///|
fn validate_ref_func_declarations_in_instr(
  instr : Instruction,
  env : Env,
  declared : @bitset.BitSet,
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
  declared : @bitset.BitSet,
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
  declared : @bitset.BitSet,
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
        let func_idx = match
          defined_body_func_index(imported_func_count, bodies.length(), i) {
          Some(func_abs) => FuncIdx::new(func_abs.reinterpret_as_uint())
          None => FuncIdx::new(i.reinterpret_as_uint())
        }
        let body_expr = match bodies[i] {
          Func(_, expr) => expr
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
pub struct ValidateValidRunConfig {
  profile : String
  attempts : Int
  generator_config : GenValidConfig
  feature_floors : Array[ValidateValidFeatureFloor]
} derive(Eq, Debug)

///|
pub enum ValidateValidFeatureKey {
  Imports
  FuncExports
  TableExports
  MemExports
  GlobalExports
  TagExports
  Starts
  LacksStart
  Tables
  Mems
  Globals
  Tags
  Elems
  Datas
  DataCount
  RefTypes
  V128
  Calls
  CallIndirect
  BranchHeavyControl
  NumericFullOps
  BrTable
  StandaloneUnreachable
  LocalTee
  TypedSelect
  TailCalls
  ScalarMemoryWidths
  NonzeroMemarg
  MemoryLimitVariants
  TableLimitVariants
  ConstExprVariants
  BasicRefInstructions
  I31ExternConversions
  GcConstructors
  GcAccessors
  StringOps
  ExceptionTryTableMatrix
  SimdPhase1
  SimdPhase2
  SimdPhase3
  Atomics
  SubtypingTopology
  RichGcFieldPlans
  ImportExportTopology
  ElementSegmentRange
  DataSegmentRange
  NameCustomSections
  InvalidAstStrategies
  InvalidBinaryStrategies
  WastArbitraryParity
} derive(Eq, Debug)

///|
pub impl Show for ValidateValidFeatureKey with output(self, logger) {
  match self {
    Imports => logger.write_string("Imports")
    FuncExports => logger.write_string("FuncExports")
    TableExports => logger.write_string("TableExports")
    MemExports => logger.write_string("MemExports")
    GlobalExports => logger.write_string("GlobalExports")
    TagExports => logger.write_string("TagExports")
    Starts => logger.write_string("Starts")
    LacksStart => logger.write_string("LacksStart")
    Tables => logger.write_string("Tables")
    Mems => logger.write_string("Mems")
    Globals => logger.write_string("Globals")
    Tags => logger.write_string("Tags")
    Elems => logger.write_string("Elems")
    Datas => logger.write_string("Datas")
    DataCount => logger.write_string("DataCount")
    RefTypes => logger.write_string("RefTypes")
    V128 => logger.write_string("V128")
    Calls => logger.write_string("Calls")
    CallIndirect => logger.write_string("CallIndirect")
    BranchHeavyControl => logger.write_string("BranchHeavyControl")
    NumericFullOps => logger.write_string("NumericFullOps")
    BrTable => logger.write_string("BrTable")
    StandaloneUnreachable => logger.write_string("StandaloneUnreachable")
    LocalTee => logger.write_string("LocalTee")
    TypedSelect => logger.write_string("TypedSelect")
    TailCalls => logger.write_string("TailCalls")
    ScalarMemoryWidths => logger.write_string("ScalarMemoryWidths")
    NonzeroMemarg => logger.write_string("NonzeroMemarg")
    MemoryLimitVariants => logger.write_string("MemoryLimitVariants")
    TableLimitVariants => logger.write_string("TableLimitVariants")
    ConstExprVariants => logger.write_string("ConstExprVariants")
    BasicRefInstructions => logger.write_string("BasicRefInstructions")
    I31ExternConversions => logger.write_string("I31ExternConversions")
    GcConstructors => logger.write_string("GcConstructors")
    GcAccessors => logger.write_string("GcAccessors")
    StringOps => logger.write_string("StringOps")
    ExceptionTryTableMatrix => logger.write_string("ExceptionTryTableMatrix")
    SimdPhase1 => logger.write_string("SimdPhase1")
    SimdPhase2 => logger.write_string("SimdPhase2")
    SimdPhase3 => logger.write_string("SimdPhase3")
    Atomics => logger.write_string("Atomics")
    SubtypingTopology => logger.write_string("SubtypingTopology")
    RichGcFieldPlans => logger.write_string("RichGcFieldPlans")
    ImportExportTopology => logger.write_string("ImportExportTopology")
    ElementSegmentRange => logger.write_string("ElementSegmentRange")
    DataSegmentRange => logger.write_string("DataSegmentRange")
    NameCustomSections => logger.write_string("NameCustomSections")
    InvalidAstStrategies => logger.write_string("InvalidAstStrategies")
    InvalidBinaryStrategies => logger.write_string("InvalidBinaryStrategies")
    WastArbitraryParity => logger.write_string("WastArbitraryParity")
  }
}

///|
pub struct ValidateValidFeatureFloor {
  key : ValidateValidFeatureKey
  min_count : Int
} derive(Eq, Debug)

///|
pub impl Show for ValidateValidFeatureFloor with output(self, logger) {
  logger.write_string("ValidateValidFeatureFloor { key: ")
  self.key.output(logger)
  logger.write_string(", min_count: ")
  self.min_count.output(logger)
  logger.write_char('}')
}

///|
pub struct ValidateValidFeatureFloorFailure {
  key : ValidateValidFeatureKey
  min_count : Int
  actual_count : Int
} derive(Eq, Debug)

///|
pub enum ValidateValidFeatureLedgerStatus {
  Covered
  MissingOptional
  MissingRequired
} derive(Eq, Debug)

///|
pub impl Show for ValidateValidFeatureLedgerStatus with output(self, logger) {
  match self {
    Covered => logger.write_string("Covered")
    MissingOptional => logger.write_string("MissingOptional")
    MissingRequired => logger.write_string("MissingRequired")
  }
}

///|
pub struct ValidateValidFeatureLedgerEntry {
  key : ValidateValidFeatureKey
  label : String
  actual_count : Int
  required_min : Int
  status : ValidateValidFeatureLedgerStatus
} derive(Eq, Debug)

///|
pub impl Show for ValidateValidFeatureFloorFailure with output(self, logger) {
  logger.write_string("ValidateValidFeatureFloorFailure { key: ")
  self.key.output(logger)
  logger.write_string(", min_count: ")
  self.min_count.output(logger)
  logger.write_string(", actual_count: ")
  self.actual_count.output(logger)
  logger.write_char('}')
}

///|
pub struct ValidateValidFuzzStats {
  profile : String
  seed : UInt64
  attempts : Int
  validated : Int
  generator_config : GenValidConfig
  feature_stats : GenValidFeatureStats
  feature_floors : Array[ValidateValidFeatureFloor]
} derive(Eq, Debug)

///|
pub impl Show for ValidateValidFuzzStats with output(self, logger) {
  logger.write_string("ValidateValidFuzzStats {profile: ")
  self.profile.output(logger)
  logger.write_string(", seed: ")
  self.seed.output(logger)
  logger.write_string(", attempts: ")
  self.attempts.output(logger)
  logger.write_string(", validated: ")
  self.validated.output(logger)
  logger.write_string(", generator_config: ")
  self.generator_config.output(logger)
  logger.write_string(", feature_stats: ")
  self.feature_stats.output(logger)
  logger.write_string(", feature_floors: ")
  self.feature_floors.output(logger)
  logger.write_char('}')
}

///|
fn validate_valid_feature_floor(
  key : ValidateValidFeatureKey,
  min_count : Int,
) -> ValidateValidFeatureFloor {
  { key, min_count }
}

///|
pub fn validate_valid_feature_actual_count(
  stats : GenValidFeatureStats,
  key : ValidateValidFeatureKey,
) -> Int {
  match key {
    Imports => stats.imports
    FuncExports => stats.func_exports
    TableExports => stats.table_exports
    MemExports => stats.mem_exports
    GlobalExports => stats.global_exports
    TagExports => stats.tag_exports
    Starts => stats.starts
    LacksStart => stats.lacks_start
    Tables => stats.tables
    Mems => stats.mems
    Globals => stats.globals
    Tags => stats.tags
    Elems => stats.elems
    Datas => stats.datas
    DataCount => stats.data_count
    RefTypes => stats.ref_types
    V128 => stats.v128
    Calls => stats.calls
    CallIndirect => stats.call_indirect
    BranchHeavyControl => stats.branch_heavy_control
    NumericFullOps => stats.numeric_full_ops
    BrTable => stats.br_table
    StandaloneUnreachable => stats.standalone_unreachable
    LocalTee => stats.local_tee
    TypedSelect => stats.typed_select
    TailCalls => stats.tail_calls
    ScalarMemoryWidths => stats.scalar_memory_widths
    NonzeroMemarg => stats.nonzero_memarg
    MemoryLimitVariants => stats.memory_limit_variants
    TableLimitVariants => stats.table_limit_variants
    ConstExprVariants => stats.const_expr_variants
    BasicRefInstructions => 0
    I31ExternConversions => 0
    GcConstructors => 0
    GcAccessors => 0
    StringOps => 0
    ExceptionTryTableMatrix => 0
    SimdPhase1 => 0
    SimdPhase2 => 0
    SimdPhase3 => 0
    Atomics => 0
    SubtypingTopology => 0
    RichGcFieldPlans => 0
    ImportExportTopology => 0
    ElementSegmentRange => 0
    DataSegmentRange => 0
    NameCustomSections => 0
    InvalidAstStrategies => 0
    InvalidBinaryStrategies => 0
    WastArbitraryParity => 0
  }
}

///|
fn validate_valid_feature_ledger_keys() -> Array[ValidateValidFeatureKey] {
  [
    Imports,
    FuncExports,
    TableExports,
    MemExports,
    GlobalExports,
    TagExports,
    Starts,
    LacksStart,
    Tables,
    Mems,
    Globals,
    Tags,
    Elems,
    Datas,
    DataCount,
    RefTypes,
    V128,
    Calls,
    CallIndirect,
    BranchHeavyControl,
    NumericFullOps,
    BrTable,
    StandaloneUnreachable,
    LocalTee,
    TypedSelect,
    TailCalls,
    ScalarMemoryWidths,
    NonzeroMemarg,
    MemoryLimitVariants,
    TableLimitVariants,
    ConstExprVariants,
    BasicRefInstructions,
    I31ExternConversions,
    GcConstructors,
    GcAccessors,
    StringOps,
    ExceptionTryTableMatrix,
    SimdPhase1,
    SimdPhase2,
    SimdPhase3,
    Atomics,
    SubtypingTopology,
    RichGcFieldPlans,
    ImportExportTopology,
    ElementSegmentRange,
    DataSegmentRange,
    NameCustomSections,
    InvalidAstStrategies,
    InvalidBinaryStrategies,
    WastArbitraryParity,
  ]
}

///|
fn validate_valid_feature_required_min(
  key : ValidateValidFeatureKey,
  floors : Array[ValidateValidFeatureFloor],
) -> Int {
  for floor in floors {
    if floor.key == key {
      return floor.min_count
    }
  }
  0
}

///|
pub fn validate_valid_feature_ledger(
  stats : GenValidFeatureStats,
  floors : Array[ValidateValidFeatureFloor],
) -> Array[ValidateValidFeatureLedgerEntry] {
  let entries : Array[ValidateValidFeatureLedgerEntry] = []
  for key in validate_valid_feature_ledger_keys() {
    let actual_count = validate_valid_feature_actual_count(stats, key)
    let required_min = validate_valid_feature_required_min(key, floors)
    let status = if actual_count < required_min {
      MissingRequired
    } else if actual_count > 0 {
      Covered
    } else {
      MissingOptional
    }
    entries.push({
      key,
      label: validate_valid_feature_key_label(key),
      actual_count,
      required_min,
      status,
    })
  }
  entries
}

///|
pub fn check_validate_valid_feature_floors(
  stats : GenValidFeatureStats,
  floors : Array[ValidateValidFeatureFloor],
) -> Array[ValidateValidFeatureFloorFailure] {
  let failures : Array[ValidateValidFeatureFloorFailure] = []
  for floor in floors {
    let actual_count = validate_valid_feature_actual_count(stats, floor.key)
    if actual_count < floor.min_count {
      failures.push({ key: floor.key, min_count: floor.min_count, actual_count })
    }
  }
  failures
}

///|
fn validate_valid_feature_key_label(key : ValidateValidFeatureKey) -> String {
  match key {
    Imports => "imports"
    FuncExports => "func_exports"
    TableExports => "table_exports"
    MemExports => "mem_exports"
    GlobalExports => "global_exports"
    TagExports => "tag_exports"
    Starts => "starts"
    LacksStart => "lacks_start"
    Tables => "tables"
    Mems => "mems"
    Globals => "globals"
    Tags => "tags"
    Elems => "elems"
    Datas => "datas"
    DataCount => "data_count"
    RefTypes => "ref_types"
    V128 => "v128"
    Calls => "calls"
    CallIndirect => "call_indirect"
    BranchHeavyControl => "branch_heavy_control"
    NumericFullOps => "numeric_full_ops"
    BrTable => "br_table"
    StandaloneUnreachable => "standalone_unreachable"
    LocalTee => "local_tee"
    TypedSelect => "typed_select"
    TailCalls => "tail_calls"
    ScalarMemoryWidths => "scalar_memory_widths"
    NonzeroMemarg => "nonzero_memarg"
    MemoryLimitVariants => "memory_limit_variants"
    TableLimitVariants => "table_limit_variants"
    ConstExprVariants => "const_expr_variants"
    BasicRefInstructions => "basic_ref_instructions"
    I31ExternConversions => "i31_extern_conversions"
    GcConstructors => "gc_constructors"
    GcAccessors => "gc_accessors"
    StringOps => "string_ops"
    ExceptionTryTableMatrix => "exception_try_table_matrix"
    SimdPhase1 => "simd_phase1"
    SimdPhase2 => "simd_phase2"
    SimdPhase3 => "simd_phase3"
    Atomics => "atomics"
    SubtypingTopology => "subtyping_topology"
    RichGcFieldPlans => "rich_gc_field_plans"
    ImportExportTopology => "import_export_topology"
    ElementSegmentRange => "element_segment_range"
    DataSegmentRange => "data_segment_range"
    NameCustomSections => "name_custom_sections"
    InvalidAstStrategies => "invalid_ast_strategies"
    InvalidBinaryStrategies => "invalid_binary_strategies"
    WastArbitraryParity => "wast_arbitrary_parity"
  }
}

///|
fn validate_valid_feature_floor_failures_message(
  failures : Array[ValidateValidFeatureFloorFailure],
) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < failures.length() {
    if i > 0 {
      out.write_string(", ")
    }
    let failure = failures[i]
    out.write_string(
      "\{validate_valid_feature_key_label(failure.key)} actual=\{failure.actual_count} min=\{failure.min_count}",
    )
    i += 1
  }
  out.to_string()
}

///|
fn validate_valid_feature_floors_for_profile(
  normalized : String,
) -> Array[ValidateValidFeatureFloor] {
  match normalized {
    "smoke" =>
      [
        validate_valid_feature_floor(Imports, 1),
        validate_valid_feature_floor(Starts, 1),
        validate_valid_feature_floor(LacksStart, 1),
        validate_valid_feature_floor(Tables, 1),
        validate_valid_feature_floor(Mems, 1),
        validate_valid_feature_floor(RefTypes, 1),
        validate_valid_feature_floor(V128, 1),
        validate_valid_feature_floor(Calls, 1),
        validate_valid_feature_floor(CallIndirect, 1),
        validate_valid_feature_floor(BranchHeavyControl, 1),
      ]
    "ci" =>
      [
        validate_valid_feature_floor(Imports, 100),
        validate_valid_feature_floor(TableExports, 100),
        validate_valid_feature_floor(MemExports, 100),
        validate_valid_feature_floor(GlobalExports, 250),
        validate_valid_feature_floor(TagExports, 50),
        validate_valid_feature_floor(Starts, 50),
        validate_valid_feature_floor(LacksStart, 500),
        validate_valid_feature_floor(Tables, 100),
        validate_valid_feature_floor(Mems, 100),
        validate_valid_feature_floor(Globals, 250),
        validate_valid_feature_floor(Tags, 50),
        validate_valid_feature_floor(Elems, 25),
        validate_valid_feature_floor(Datas, 25),
        validate_valid_feature_floor(DataCount, 25),
        validate_valid_feature_floor(RefTypes, 500),
        validate_valid_feature_floor(V128, 500),
        validate_valid_feature_floor(Calls, 500),
        validate_valid_feature_floor(CallIndirect, 100),
        validate_valid_feature_floor(BranchHeavyControl, 250),
      ]
    "stress" =>
      [
        validate_valid_feature_floor(Imports, 2000),
        validate_valid_feature_floor(TableExports, 2000),
        validate_valid_feature_floor(MemExports, 2000),
        validate_valid_feature_floor(GlobalExports, 5000),
        validate_valid_feature_floor(TagExports, 1000),
        validate_valid_feature_floor(Starts, 1000),
        validate_valid_feature_floor(LacksStart, 10000),
        validate_valid_feature_floor(Tables, 2000),
        validate_valid_feature_floor(Mems, 2000),
        validate_valid_feature_floor(Globals, 5000),
        validate_valid_feature_floor(Tags, 1000),
        validate_valid_feature_floor(Elems, 500),
        validate_valid_feature_floor(Datas, 500),
        validate_valid_feature_floor(DataCount, 500),
        validate_valid_feature_floor(RefTypes, 10000),
        validate_valid_feature_floor(V128, 10000),
        validate_valid_feature_floor(Calls, 10000),
        validate_valid_feature_floor(CallIndirect, 2000),
        validate_valid_feature_floor(BranchHeavyControl, 5000),
      ]
    _ => abort("unreachable validate-valid profile")
  }
}

///|
pub fn validate_valid_run_config(
  profile : String,
) -> Result[ValidateValidRunConfig, String] {
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
  let generator_config = match normalized {
    "smoke" => default_gen_valid_config()
    "ci" =>
      GenValidConfig::{
        ..default_gen_valid_config(),
        max_defined_funcs: 5,
        max_globals: 3,
        max_body_statements: 8,
        max_locals: 4,
      }
    "stress" =>
      GenValidConfig::{
        ..default_gen_valid_config(),
        max_type_defs: 6,
        max_defined_funcs: 6,
        max_globals: 4,
        max_params: 3,
        max_results: 2,
        max_locals: 5,
        max_body_statements: 10,
        max_body_depth: 3,
      }
    _ => abort("unreachable validate-valid profile")
  }
  let feature_floors = validate_valid_feature_floors_for_profile(normalized)
  Ok(ValidateValidRunConfig::{
    profile: normalized,
    attempts,
    generator_config,
    feature_floors,
  })
}

///|
pub fn run_validate_valid_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[ValidateValidFuzzStats, String] {
  let run_config = match validate_valid_run_config(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let normalized = run_config.profile
  let attempts = run_config.attempts
  let generator_config = run_config.generator_config
  let feature_floors = run_config.feature_floors
  let rnd = @splitmix.new(seed~)
  let mut validated = 0
  let mut iteration = 0
  let mut feature_stats = GenValidFeatureStats::empty(generator_config.mode)
  let mut remaining_attempts = attempts
  while remaining_attempts > 0 {
    iteration += 1
    let mod = gen_valid_module_with_config(rnd, generator_config)
    feature_stats = feature_stats.record(
      gen_valid_feature_facts(mod, generator_config.mode),
    )
    match validate_module(mod) {
      Ok(_) => validated += 1
      Err(err) =>
        return Err(
          "validate-valid fuzz failed: profile=\{normalized} seed=\{seed} iteration=\{iteration} error=\{validation_error_message(err)}",
        )
    }
    remaining_attempts -= 1
  }
  let floor_failures = check_validate_valid_feature_floors(
    feature_stats, feature_floors,
  )
  if !floor_failures.is_empty() {
    return Err(
      "validate-valid fuzz feature floors failed: profile=\{normalized} seed=\{seed} \{validate_valid_feature_floor_failures_message(floor_failures)}",
    )
  }
  Ok(ValidateValidFuzzStats::{
    profile: normalized,
    seed,
    attempts,
    validated,
    generator_config,
    feature_stats,
    feature_floors,
  })
}

///|
priv struct GenValidBodySurfaceFacts {
  has_block : Bool
  has_loop : Bool
  has_if : Bool
  has_br : Bool
  has_br_if : Bool
  has_memory_op : Bool
  has_table_op : Bool
}

///|
fn gen_valid_body_surface_facts_empty() -> GenValidBodySurfaceFacts {
  {
    has_block: false,
    has_loop: false,
    has_if: false,
    has_br: false,
    has_br_if: false,
    has_memory_op: false,
    has_table_op: false,
  }
}

///|
fn gen_valid_body_surface_facts_merge(
  left : GenValidBodySurfaceFacts,
  right : GenValidBodySurfaceFacts,
) -> GenValidBodySurfaceFacts {
  {
    has_block: left.has_block || right.has_block,
    has_loop: left.has_loop || right.has_loop,
    has_if: left.has_if || right.has_if,
    has_br: left.has_br || right.has_br,
    has_br_if: left.has_br_if || right.has_br_if,
    has_memory_op: left.has_memory_op || right.has_memory_op,
    has_table_op: left.has_table_op || right.has_table_op,
  }
}

///|
fn gen_valid_body_surface_facts_expr(expr : Expr) -> GenValidBodySurfaceFacts {
  let Expr(instrs) = expr
  let mut facts = gen_valid_body_surface_facts_empty()
  for instr in instrs {
    facts = gen_valid_body_surface_facts_merge(
      facts,
      gen_valid_body_surface_facts_instr(instr),
    )
  }
  facts
}

///|
fn gen_valid_body_surface_facts_instr(
  instr : Instruction,
) -> GenValidBodySurfaceFacts {
  match instr {
    Block(_, body) =>
      GenValidBodySurfaceFacts::{
        ..gen_valid_body_surface_facts_expr(body),
        has_block: true,
      }
    Loop(_, body) =>
      GenValidBodySurfaceFacts::{
        ..gen_valid_body_surface_facts_expr(body),
        has_loop: true,
      }
    If(_, then_body, else_body) => {
      let mut facts = GenValidBodySurfaceFacts::{
        ..gen_valid_body_surface_facts_empty(),
        has_if: true,
      }
      facts = gen_valid_body_surface_facts_merge(
        facts,
        gen_valid_body_surface_facts_expr(Expr::new(then_body)),
      )
      match else_body {
        Some(branch) =>
          facts = gen_valid_body_surface_facts_merge(
            facts,
            gen_valid_body_surface_facts_expr(Expr::new(branch)),
          )
        None => ()
      }
      facts
    }
    Br(_) =>
      GenValidBodySurfaceFacts::{
        ..gen_valid_body_surface_facts_empty(),
        has_br: true,
      }
    BrIf(_) =>
      GenValidBodySurfaceFacts::{
        ..gen_valid_body_surface_facts_empty(),
        has_br_if: true,
      }
    I32Load(_)
    | I64Load(_)
    | F32Load(_)
    | F64Load(_)
    | I32Load8S(_)
    | I32Load8U(_)
    | I32Load16S(_)
    | I32Load16U(_)
    | I64Load8S(_)
    | I64Load8U(_)
    | I64Load16S(_)
    | I64Load16U(_)
    | I64Load32S(_)
    | I64Load32U(_)
    | I32Store(_)
    | I64Store(_)
    | F32Store(_)
    | F64Store(_)
    | I32Store8(_)
    | I32Store16(_)
    | I64Store8(_)
    | I64Store16(_)
    | I64Store32(_)
    | MemorySize(_)
    | MemoryGrow(_)
    | MemoryFill(_)
    | MemoryCopy(_, _) =>
      GenValidBodySurfaceFacts::{
        ..gen_valid_body_surface_facts_empty(),
        has_memory_op: true,
      }
    TableGet(_)
    | TableSet(_)
    | TableSize(_)
    | TableGrow(_)
    | TableFill(_)
    | TableCopy(_, _)
    | TableInit(_, _) =>
      GenValidBodySurfaceFacts::{
        ..gen_valid_body_surface_facts_empty(),
        has_table_op: true,
      }
    _ => gen_valid_body_surface_facts_empty()
  }
}

///|
fn gen_valid_body_surface_facts_module(
  mod : Module,
) -> GenValidBodySurfaceFacts {
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      let mut facts = gen_valid_body_surface_facts_empty()
      for func in funcs {
        let Func(_, body) = func
        facts = gen_valid_body_surface_facts_merge(
          facts,
          gen_valid_body_surface_facts_expr(body),
        )
      }
      facts
    }
    None => gen_valid_body_surface_facts_empty()
  }
}

///|
priv struct GenValidCoverageSurfaceFacts {
  import_funcs : Int
  import_tables : Int
  import_mems : Int
  import_globals : Int
  import_tags : Int
  passive_elems : Int
  declarative_elems : Int
  passive_datas : Int
  has_memory_init : Bool
  has_data_drop : Bool
  has_memory_copy : Bool
  has_memory_fill : Bool
  has_table_init : Bool
  has_elem_drop : Bool
  has_table_copy : Bool
  has_table_fill : Bool
}

///|
fn gen_valid_coverage_surface_facts_empty() -> GenValidCoverageSurfaceFacts {
  {
    import_funcs: 0,
    import_tables: 0,
    import_mems: 0,
    import_globals: 0,
    import_tags: 0,
    passive_elems: 0,
    declarative_elems: 0,
    passive_datas: 0,
    has_memory_init: false,
    has_data_drop: false,
    has_memory_copy: false,
    has_memory_fill: false,
    has_table_init: false,
    has_elem_drop: false,
    has_table_copy: false,
    has_table_fill: false,
  }
}

///|
fn gen_valid_coverage_surface_facts_merge(
  left : GenValidCoverageSurfaceFacts,
  right : GenValidCoverageSurfaceFacts,
) -> GenValidCoverageSurfaceFacts {
  {
    import_funcs: left.import_funcs + right.import_funcs,
    import_tables: left.import_tables + right.import_tables,
    import_mems: left.import_mems + right.import_mems,
    import_globals: left.import_globals + right.import_globals,
    import_tags: left.import_tags + right.import_tags,
    passive_elems: left.passive_elems + right.passive_elems,
    declarative_elems: left.declarative_elems + right.declarative_elems,
    passive_datas: left.passive_datas + right.passive_datas,
    has_memory_init: left.has_memory_init || right.has_memory_init,
    has_data_drop: left.has_data_drop || right.has_data_drop,
    has_memory_copy: left.has_memory_copy || right.has_memory_copy,
    has_memory_fill: left.has_memory_fill || right.has_memory_fill,
    has_table_init: left.has_table_init || right.has_table_init,
    has_elem_drop: left.has_elem_drop || right.has_elem_drop,
    has_table_copy: left.has_table_copy || right.has_table_copy,
    has_table_fill: left.has_table_fill || right.has_table_fill,
  }
}

///|
fn gen_valid_coverage_surface_facts_instr(
  instr : Instruction,
) -> GenValidCoverageSurfaceFacts {
  match instr {
    Block(_, body) | Loop(_, body) =>
      gen_valid_coverage_surface_facts_expr(body)
    If(_, then_body, else_body) => {
      let mut facts = gen_valid_coverage_surface_facts_expr(
        Expr::new(then_body),
      )
      match else_body {
        Some(branch) =>
          facts = gen_valid_coverage_surface_facts_merge(
            facts,
            gen_valid_coverage_surface_facts_expr(Expr::new(branch)),
          )
        None => ()
      }
      facts
    }
    MemoryInit(_, _) =>
      { ..gen_valid_coverage_surface_facts_empty(), has_memory_init: true }
    DataDrop(_) =>
      { ..gen_valid_coverage_surface_facts_empty(), has_data_drop: true }
    MemoryCopy(_, _) =>
      { ..gen_valid_coverage_surface_facts_empty(), has_memory_copy: true }
    MemoryFill(_) =>
      { ..gen_valid_coverage_surface_facts_empty(), has_memory_fill: true }
    TableInit(_, _) =>
      { ..gen_valid_coverage_surface_facts_empty(), has_table_init: true }
    ElemDrop(_) =>
      { ..gen_valid_coverage_surface_facts_empty(), has_elem_drop: true }
    TableCopy(_, _) =>
      { ..gen_valid_coverage_surface_facts_empty(), has_table_copy: true }
    TableFill(_) =>
      { ..gen_valid_coverage_surface_facts_empty(), has_table_fill: true }
    _ => gen_valid_coverage_surface_facts_empty()
  }
}

///|
fn gen_valid_coverage_surface_facts_expr(
  expr : Expr,
) -> GenValidCoverageSurfaceFacts {
  let Expr(instrs) = expr
  let mut facts = gen_valid_coverage_surface_facts_empty()
  for instr in instrs {
    facts = gen_valid_coverage_surface_facts_merge(
      facts,
      gen_valid_coverage_surface_facts_instr(instr),
    )
  }
  facts
}

///|
fn gen_valid_coverage_surface_facts_module(
  mod : Module,
) -> GenValidCoverageSurfaceFacts {
  let mut facts = gen_valid_coverage_surface_facts_empty()
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for imp in imports {
        let Import(_, _, extern_type) = imp
        facts = gen_valid_coverage_surface_facts_merge(
          facts,
          match extern_type {
            FuncExternType(_) =>
              { ..gen_valid_coverage_surface_facts_empty(), import_funcs: 1 }
            TableExternType(_) =>
              { ..gen_valid_coverage_surface_facts_empty(), import_tables: 1 }
            MemExternType(_) =>
              { ..gen_valid_coverage_surface_facts_empty(), import_mems: 1 }
            GlobalExternType(_) =>
              { ..gen_valid_coverage_surface_facts_empty(), import_globals: 1 }
            TagExternType(_) =>
              { ..gen_valid_coverage_surface_facts_empty(), import_tags: 1 }
          },
        )
      }
    None => ()
  }
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(mode, _) = elem
        facts = gen_valid_coverage_surface_facts_merge(
          facts,
          match mode {
            Passive =>
              { ..gen_valid_coverage_surface_facts_empty(), passive_elems: 1 }
            Declarative =>
              {
                ..gen_valid_coverage_surface_facts_empty(),
                declarative_elems: 1,
              }
            Active(_, expr) => gen_valid_coverage_surface_facts_expr(expr)
          },
        )
      }
    None => ()
  }
  match mod.data_sec {
    Some(DataSec(datas)) =>
      for data in datas {
        let Data(mode, _) = data
        facts = gen_valid_coverage_surface_facts_merge(
          facts,
          match mode {
            Passive =>
              { ..gen_valid_coverage_surface_facts_empty(), passive_datas: 1 }
            Active(_, expr) => gen_valid_coverage_surface_facts_expr(expr)
          },
        )
      }
    None => ()
  }
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, body) = func
        facts = gen_valid_coverage_surface_facts_merge(
          facts,
          gen_valid_coverage_surface_facts_expr(body),
        )
      }
    None => ()
  }
  facts
}

///|
priv struct GenValidGcSurfaceFacts {
  struct_types : Int
  array_types : Int
  descriptor_types : Int
  rec_groups : Int
  typed_ref_globals : Int
  typed_ref_tables : Int
  typed_ref_locals : Int
  exact_typed_ref_globals : Int
  exact_typed_ref_locals : Int
  exact_typed_ref_results : Int
  has_struct_new : Bool
  has_struct_get : Bool
  has_struct_set : Bool
  has_array_new : Bool
  has_array_new_data : Bool
  has_array_new_elem : Bool
  has_array_get : Bool
  has_array_set : Bool
  has_array_init_data : Bool
  has_array_init_elem : Bool
  has_array_len : Bool
  has_string_const : Bool
  has_string_new : Bool
  has_string_encode : Bool
  has_ref_get_desc : Bool
  has_ref_test : Bool
  has_ref_test_desc : Bool
  has_ref_cast : Bool
  has_ref_cast_desc_eq : Bool
  has_ref_eq : Bool
  has_ref_as_non_null : Bool
  has_exact_ref_null : Bool
  has_call_ref : Bool
  has_br_on_null : Bool
  has_br_on_non_null : Bool
  has_br_on_cast : Bool
  has_br_on_cast_fail : Bool
  has_mixed_catch_try_table : Bool
  has_branchy_mixed_catch_try_table : Bool
  has_try_table : Bool
  has_throw : Bool
  has_throw_ref : Bool
}

///|
fn gen_valid_gc_surface_facts_empty() -> GenValidGcSurfaceFacts {
  {
    struct_types: 0,
    array_types: 0,
    descriptor_types: 0,
    rec_groups: 0,
    typed_ref_globals: 0,
    typed_ref_tables: 0,
    typed_ref_locals: 0,
    exact_typed_ref_globals: 0,
    exact_typed_ref_locals: 0,
    exact_typed_ref_results: 0,
    has_struct_new: false,
    has_struct_get: false,
    has_struct_set: false,
    has_array_new: false,
    has_array_new_data: false,
    has_array_new_elem: false,
    has_array_get: false,
    has_array_set: false,
    has_array_init_data: false,
    has_array_init_elem: false,
    has_array_len: false,
    has_string_const: false,
    has_string_new: false,
    has_string_encode: false,
    has_ref_get_desc: false,
    has_ref_test: false,
    has_ref_test_desc: false,
    has_ref_cast: false,
    has_ref_cast_desc_eq: false,
    has_ref_eq: false,
    has_ref_as_non_null: false,
    has_exact_ref_null: false,
    has_call_ref: false,
    has_br_on_null: false,
    has_br_on_non_null: false,
    has_br_on_cast: false,
    has_br_on_cast_fail: false,
    has_mixed_catch_try_table: false,
    has_branchy_mixed_catch_try_table: false,
    has_try_table: false,
    has_throw: false,
    has_throw_ref: false,
  }
}

///|
fn gen_valid_gc_surface_facts_merge(
  left : GenValidGcSurfaceFacts,
  right : GenValidGcSurfaceFacts,
) -> GenValidGcSurfaceFacts {
  {
    struct_types: left.struct_types + right.struct_types,
    array_types: left.array_types + right.array_types,
    descriptor_types: left.descriptor_types + right.descriptor_types,
    rec_groups: left.rec_groups + right.rec_groups,
    typed_ref_globals: left.typed_ref_globals + right.typed_ref_globals,
    typed_ref_tables: left.typed_ref_tables + right.typed_ref_tables,
    typed_ref_locals: left.typed_ref_locals + right.typed_ref_locals,
    exact_typed_ref_globals: left.exact_typed_ref_globals +
    right.exact_typed_ref_globals,
    exact_typed_ref_locals: left.exact_typed_ref_locals +
    right.exact_typed_ref_locals,
    exact_typed_ref_results: left.exact_typed_ref_results +
    right.exact_typed_ref_results,
    has_struct_new: left.has_struct_new || right.has_struct_new,
    has_struct_get: left.has_struct_get || right.has_struct_get,
    has_struct_set: left.has_struct_set || right.has_struct_set,
    has_array_new: left.has_array_new || right.has_array_new,
    has_array_new_data: left.has_array_new_data || right.has_array_new_data,
    has_array_new_elem: left.has_array_new_elem || right.has_array_new_elem,
    has_array_get: left.has_array_get || right.has_array_get,
    has_array_set: left.has_array_set || right.has_array_set,
    has_array_init_data: left.has_array_init_data || right.has_array_init_data,
    has_array_init_elem: left.has_array_init_elem || right.has_array_init_elem,
    has_array_len: left.has_array_len || right.has_array_len,
    has_string_const: left.has_string_const || right.has_string_const,
    has_string_new: left.has_string_new || right.has_string_new,
    has_string_encode: left.has_string_encode || right.has_string_encode,
    has_ref_get_desc: left.has_ref_get_desc || right.has_ref_get_desc,
    has_ref_test: left.has_ref_test || right.has_ref_test,
    has_ref_test_desc: left.has_ref_test_desc || right.has_ref_test_desc,
    has_ref_cast: left.has_ref_cast || right.has_ref_cast,
    has_ref_cast_desc_eq: left.has_ref_cast_desc_eq ||
    right.has_ref_cast_desc_eq,
    has_ref_eq: left.has_ref_eq || right.has_ref_eq,
    has_ref_as_non_null: left.has_ref_as_non_null || right.has_ref_as_non_null,
    has_exact_ref_null: left.has_exact_ref_null || right.has_exact_ref_null,
    has_call_ref: left.has_call_ref || right.has_call_ref,
    has_br_on_null: left.has_br_on_null || right.has_br_on_null,
    has_br_on_non_null: left.has_br_on_non_null || right.has_br_on_non_null,
    has_br_on_cast: left.has_br_on_cast || right.has_br_on_cast,
    has_br_on_cast_fail: left.has_br_on_cast_fail || right.has_br_on_cast_fail,
    has_mixed_catch_try_table: left.has_mixed_catch_try_table ||
    right.has_mixed_catch_try_table,
    has_branchy_mixed_catch_try_table: left.has_branchy_mixed_catch_try_table ||
    right.has_branchy_mixed_catch_try_table,
    has_try_table: left.has_try_table || right.has_try_table,
    has_throw: left.has_throw || right.has_throw,
    has_throw_ref: left.has_throw_ref || right.has_throw_ref,
  }
}

///|
fn gen_valid_gc_surface_ref_score(rt : RefType) -> Int {
  match rt.get_heap_type() {
    HeapType(_) => 1
    AbsHeapTypeHeapType(abs) =>
      if abs == AbsHeapType::any() ||
        abs == AbsHeapType::eq() ||
        abs == AbsHeapType::i31() ||
        abs == AbsHeapType::struct_() ||
        abs == AbsHeapType::array() ||
        abs == AbsHeapType::string_() ||
        abs == AbsHeapType::exn() {
        1
      } else {
        0
      }
    _ => 0
  }
}

///|
fn gen_valid_gc_surface_val_score(vt : ValType) -> Int {
  match vt {
    RefTypeValType(rt) => gen_valid_gc_surface_ref_score(rt)
    _ => 0
  }
}

///|
fn gen_valid_gc_surface_exact_val_score(vt : ValType) -> Int {
  match vt {
    RefTypeValType(rt) =>
      if rt.is_exact() {
        gen_valid_gc_surface_ref_score(rt)
      } else {
        0
      }
    _ => 0
  }
}

///|
fn gen_valid_gc_surface_has_mixed_catches(catches : Array[Catch]) -> Bool {
  let mut has_catch = false
  let mut has_catch_ref = false
  let mut has_catch_all = false
  let mut has_catch_all_ref = false
  for catch_ in catches {
    match catch_ {
      Catch(_, _) => has_catch = true
      CatchRef(_, _) => has_catch_ref = true
      CatchAll(_) => has_catch_all = true
      CatchAllRef(_) => has_catch_all_ref = true
    }
  }
  let mut kinds = 0
  if has_catch {
    kinds += 1
  }
  if has_catch_ref {
    kinds += 1
  }
  if has_catch_all {
    kinds += 1
  }
  if has_catch_all_ref {
    kinds += 1
  }
  catches.length() > 1 && kinds > 1
}

///|
fn gen_valid_gc_surface_has_branchy_control(
  facts : GenValidBodySurfaceFacts,
) -> Bool {
  facts.has_block ||
  facts.has_loop ||
  facts.has_if ||
  facts.has_br ||
  facts.has_br_if
}

///|
fn gen_valid_gc_surface_facts_sub_type(
  subtype : SubType,
) -> GenValidGcSurfaceFacts {
  let descriptor_types = if subtype.descriptor_type() is Some(_) ||
    subtype.describes_type() is Some(_) {
    1
  } else {
    0
  }
  match subtype.get_comptype() {
    StructCompType(_) =>
      {
        ..gen_valid_gc_surface_facts_empty(),
        struct_types: 1,
        descriptor_types,
      }
    ArrayCompType(_) =>
      { ..gen_valid_gc_surface_facts_empty(), array_types: 1, descriptor_types }
    _ => { ..gen_valid_gc_surface_facts_empty(), descriptor_types, }
  }
}

///|
fn gen_valid_gc_surface_facts_rec_type(
  rec_type : RecType,
) -> GenValidGcSurfaceFacts {
  match rec_type {
    SingleRecType(subtype) => gen_valid_gc_surface_facts_sub_type(subtype)
    GroupRecType(group) => {
      let mut facts = { ..gen_valid_gc_surface_facts_empty(), rec_groups: 1 }
      for subtype in group {
        facts = gen_valid_gc_surface_facts_merge(
          facts,
          gen_valid_gc_surface_facts_sub_type(subtype),
        )
      }
      facts
    }
  }
}

///|
fn gen_valid_gc_surface_facts_instr(
  instr : Instruction,
) -> GenValidGcSurfaceFacts {
  match instr {
    Block(_, body) | Loop(_, body) => gen_valid_gc_surface_facts_expr(body)
    If(_, then_body, else_body) => {
      let mut facts = gen_valid_gc_surface_facts_expr(Expr::new(then_body))
      match else_body {
        Some(branch) =>
          facts = gen_valid_gc_surface_facts_merge(
            facts,
            gen_valid_gc_surface_facts_expr(Expr::new(branch)),
          )
        None => ()
      }
      facts
    }
    TryTable(_, catches, body) => {
      let body_facts = gen_valid_gc_surface_facts_expr(body)
      let mixed_catches = gen_valid_gc_surface_has_mixed_catches(catches)
      {
        ..body_facts,
        has_mixed_catch_try_table: mixed_catches,
        has_branchy_mixed_catch_try_table: mixed_catches &&
        gen_valid_gc_surface_has_branchy_control(
          gen_valid_body_surface_facts_expr(body),
        ),
        has_try_table: true,
      }
    }
    Throw(_) => { ..gen_valid_gc_surface_facts_empty(), has_throw: true }
    ThrowRef => { ..gen_valid_gc_surface_facts_empty(), has_throw_ref: true }
    StructNew(_)
    | StructNewDefault(_)
    | StructNewDesc(_)
    | StructNewDefaultDesc(_) =>
      { ..gen_valid_gc_surface_facts_empty(), has_struct_new: true }
    StructGet(_, _) | StructGetS(_, _) | StructGetU(_, _) =>
      { ..gen_valid_gc_surface_facts_empty(), has_struct_get: true }
    StructSet(_, _) =>
      { ..gen_valid_gc_surface_facts_empty(), has_struct_set: true }
    ArrayNew(_) | ArrayNewDefault(_) | ArrayNewFixed(_, _) =>
      { ..gen_valid_gc_surface_facts_empty(), has_array_new: true }
    ArrayNewData(_, _) =>
      {
        ..gen_valid_gc_surface_facts_empty(),
        has_array_new: true,
        has_array_new_data: true,
      }
    ArrayNewElem(_, _) =>
      {
        ..gen_valid_gc_surface_facts_empty(),
        has_array_new: true,
        has_array_new_elem: true,
      }
    StringNewUtf8Array
    | StringNewWtf16Array
    | StringNewLossyUtf8Array
    | StringNewWtf8Array =>
      {
        ..gen_valid_gc_surface_facts_empty(),
        has_array_new: true,
        has_string_new: true,
      }
    ArrayGet(_) | ArrayGetS(_) | ArrayGetU(_) =>
      { ..gen_valid_gc_surface_facts_empty(), has_array_get: true }
    ArraySet(_) | ArrayFill(_) | ArrayCopy(_, _) =>
      { ..gen_valid_gc_surface_facts_empty(), has_array_set: true }
    ArrayInitData(_, _) =>
      {
        ..gen_valid_gc_surface_facts_empty(),
        has_array_set: true,
        has_array_init_data: true,
      }
    ArrayInitElem(_, _) =>
      {
        ..gen_valid_gc_surface_facts_empty(),
        has_array_set: true,
        has_array_init_elem: true,
      }
    StringEncodeUtf8Array
    | StringEncodeWtf16Array
    | StringEncodeLossyUtf8Array
    | StringEncodeWtf8Array =>
      {
        ..gen_valid_gc_surface_facts_empty(),
        has_array_set: true,
        has_string_encode: true,
      }
    ArrayLen => { ..gen_valid_gc_surface_facts_empty(), has_array_len: true }
    RefNull(rt) =>
      {
        ..gen_valid_gc_surface_facts_empty(),
        has_exact_ref_null: rt.is_exact(),
      }
    StringConst(_) =>
      { ..gen_valid_gc_surface_facts_empty(), has_string_const: true }
    RefGetDesc(_) =>
      { ..gen_valid_gc_surface_facts_empty(), has_ref_get_desc: true }
    RefTest(_, _) =>
      { ..gen_valid_gc_surface_facts_empty(), has_ref_test: true }
    RefTestDesc(_, _) =>
      {
        ..gen_valid_gc_surface_facts_empty(),
        has_ref_test: true,
        has_ref_test_desc: true,
      }
    RefCast(_, _) =>
      { ..gen_valid_gc_surface_facts_empty(), has_ref_cast: true }
    RefCastDescEq(_, _) =>
      {
        ..gen_valid_gc_surface_facts_empty(),
        has_ref_cast: true,
        has_ref_cast_desc_eq: true,
      }
    RefEq => { ..gen_valid_gc_surface_facts_empty(), has_ref_eq: true }
    RefAsNonNull =>
      { ..gen_valid_gc_surface_facts_empty(), has_ref_as_non_null: true }
    CallRef(_) | ReturnCallRef(_) =>
      { ..gen_valid_gc_surface_facts_empty(), has_call_ref: true }
    BrOnNull(_) =>
      { ..gen_valid_gc_surface_facts_empty(), has_br_on_null: true }
    BrOnNonNull(_) =>
      { ..gen_valid_gc_surface_facts_empty(), has_br_on_non_null: true }
    BrOnCast(_, _, _, _) =>
      { ..gen_valid_gc_surface_facts_empty(), has_br_on_cast: true }
    BrOnCastFail(_, _, _, _) =>
      { ..gen_valid_gc_surface_facts_empty(), has_br_on_cast_fail: true }
    _ => gen_valid_gc_surface_facts_empty()
  }
}

///|
fn gen_valid_gc_surface_facts_expr(expr : Expr) -> GenValidGcSurfaceFacts {
  let Expr(instrs) = expr
  let mut facts = gen_valid_gc_surface_facts_empty()
  for instr in instrs {
    facts = gen_valid_gc_surface_facts_merge(
      facts,
      gen_valid_gc_surface_facts_instr(instr),
    )
  }
  facts
}

///|
fn gen_valid_gc_surface_facts_module(mod : Module) -> GenValidGcSurfaceFacts {
  let mut facts = gen_valid_gc_surface_facts_empty()
  match mod.type_sec {
    Some(TypeSec(type_defs)) =>
      for rec_type in type_defs {
        facts = gen_valid_gc_surface_facts_merge(
          facts,
          gen_valid_gc_surface_facts_rec_type(rec_type),
        )
        match rec_type {
          SingleRecType(subtype) =>
            match subtype.get_comptype() {
              FuncCompType(_, results) =>
                for vt in results {
                  facts = gen_valid_gc_surface_facts_merge(facts, {
                    ..gen_valid_gc_surface_facts_empty(),
                    exact_typed_ref_results: gen_valid_gc_surface_exact_val_score(
                      vt,
                    ),
                  })
                }
              _ => ()
            }
          GroupRecType(group) =>
            for subtype in group {
              match subtype.get_comptype() {
                FuncCompType(_, results) =>
                  for vt in results {
                    facts = gen_valid_gc_surface_facts_merge(facts, {
                      ..gen_valid_gc_surface_facts_empty(),
                      exact_typed_ref_results: gen_valid_gc_surface_exact_val_score(
                        vt,
                      ),
                    })
                  }
                _ => ()
              }
            }
        }
      }
    None => ()
  }
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for imp in imports {
        let Import(_, _, extern_type) = imp
        facts = gen_valid_gc_surface_facts_merge(
          facts,
          match extern_type {
            TableExternType(TableType(rt, _)) =>
              {
                ..gen_valid_gc_surface_facts_empty(),
                typed_ref_tables: gen_valid_gc_surface_ref_score(rt),
              }
            GlobalExternType(GlobalType(vt, _)) =>
              {
                ..gen_valid_gc_surface_facts_empty(),
                typed_ref_globals: gen_valid_gc_surface_val_score(vt),
                exact_typed_ref_globals: gen_valid_gc_surface_exact_val_score(
                  vt,
                ),
              }
            _ => gen_valid_gc_surface_facts_empty()
          },
        )
      }
    None => ()
  }
  match mod.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(TableType(rt, _), _) = table
        facts = gen_valid_gc_surface_facts_merge(facts, {
          ..gen_valid_gc_surface_facts_empty(),
          typed_ref_tables: gen_valid_gc_surface_ref_score(rt),
        })
      }
    None => ()
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(GlobalType(vt, _), _) = global
        facts = gen_valid_gc_surface_facts_merge(facts, {
          ..gen_valid_gc_surface_facts_empty(),
          typed_ref_globals: gen_valid_gc_surface_val_score(vt),
          exact_typed_ref_globals: gen_valid_gc_surface_exact_val_score(vt),
        })
      }
    None => ()
  }
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(locals, body) = func
        for run in locals.runs() {
          let { count, vt } = run
          ignore(count)
          facts = gen_valid_gc_surface_facts_merge(facts, {
            ..gen_valid_gc_surface_facts_empty(),
            typed_ref_locals: gen_valid_gc_surface_val_score(vt),
            exact_typed_ref_locals: gen_valid_gc_surface_exact_val_score(vt),
          })
        }
        facts = gen_valid_gc_surface_facts_merge(
          facts,
          gen_valid_gc_surface_facts_expr(body),
        )
      }
    None => ()
  }
  facts
}

///|
test "validate_valid_run_config returns profile attempts and generator config" {
  let smoke = match validate_valid_run_config("smoke") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let ci = match validate_valid_run_config("ci") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let stress = match validate_valid_run_config("stress") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_eq(smoke.profile, "smoke")
  assert_eq(smoke.attempts, 128)
  assert_eq(ci.attempts, 5000)
  assert_eq(stress.attempts, 100000)
  assert_eq(smoke.generator_config.mode, Natural)
  assert_true(
    ci.generator_config.max_defined_funcs >=
    smoke.generator_config.max_defined_funcs,
  )
  assert_true(
    stress.generator_config.max_body_statements >=
    ci.generator_config.max_body_statements,
  )
  assert_true(smoke.feature_floors.length() > 0)
  assert_true(ci.feature_floors.length() >= smoke.feature_floors.length())
  assert_true(stress.feature_floors.length() >= ci.feature_floors.length())
}

///|
test "check_validate_valid_feature_floors reports unmet minimums" {
  let floors = [
    { key: Imports, min_count: 2 },
    { key: FuncExports, min_count: 4 },
    { key: Calls, min_count: 1 },
    { key: BranchHeavyControl, min_count: 3 },
  ]
  let stats = {
    ..GenValidFeatureStats::empty(Natural),
    modules: 4,
    imports: 1,
    func_exports: 4,
    calls: 1,
    branch_heavy_control: 0,
  }
  assert_eq(check_validate_valid_feature_floors(stats, floors), [
    { key: Imports, min_count: 2, actual_count: 1 },
    { key: BranchHeavyControl, min_count: 3, actual_count: 0 },
  ])
}

///|
test "validate_valid_feature_ledger reports optional missing FZG surfaces" {
  let stats = { ..GenValidFeatureStats::empty(Natural), modules: 2, imports: 1 }
  let ledger = validate_valid_feature_ledger(stats, [])
  let mut saw_imports = false
  let mut saw_numeric_full_ops = false
  let mut saw_name_custom_sections = false
  for entry in ledger {
    if entry.key == Imports {
      saw_imports = true
      assert_eq(entry.actual_count, 1)
      assert_eq(entry.required_min, 0)
      assert_eq(entry.status, Covered)
    }
    if entry.key == NumericFullOps {
      saw_numeric_full_ops = true
      assert_eq(entry.actual_count, 0)
      assert_eq(entry.required_min, 0)
      assert_eq(entry.status, MissingOptional)
    }
    if entry.key == NameCustomSections {
      saw_name_custom_sections = true
      assert_eq(entry.actual_count, 0)
      assert_eq(entry.required_min, 0)
      assert_eq(entry.status, MissingOptional)
    }
  }
  assert_true(saw_imports)
  assert_true(saw_numeric_full_ops)
  assert_true(saw_name_custom_sections)
}

///|
test "check_validate_valid_feature_floors fails future FZG surfaces only when required" {
  let stats = GenValidFeatureStats::empty(Natural)
  assert_eq(check_validate_valid_feature_floors(stats, []), [])
  assert_eq(
    check_validate_valid_feature_floors(stats, [
      { key: NumericFullOps, min_count: 1 },
    ]),
    [{ key: NumericFullOps, min_count: 1, actual_count: 0 }],
  )
}

///|
test "gen_valid coverage-forced emits expanded scalar numeric surface" {
  let config = GenValidConfig::coverage_forced_default()
  let mod = gen_valid_module_with_config(@splitmix.new(seed=0xf26002UL), config)
  match validate_module(mod) {
    Ok(_) => ()
    Err(msg) =>
      fail("expected coverage-forced gen-valid module to validate, got \{msg}")
  }
  let facts = gen_valid_feature_facts(mod, config.mode)
  let stats = GenValidFeatureStats::empty(config.mode).record(facts)
  assert_true(validate_valid_feature_actual_count(stats, NumericFullOps) > 0)
  assert_eq(
    check_validate_valid_feature_floors(stats, [
      { key: NumericFullOps, min_count: 1 },
    ]),
    [],
  )
}

///|
test "gen_valid coverage-forced emits core control surface" {
  let config = GenValidConfig::coverage_forced_default()
  let mod = gen_valid_module_with_config(@splitmix.new(seed=0xf26003UL), config)
  match validate_module(mod) {
    Ok(_) => ()
    Err(msg) =>
      fail("expected coverage-forced gen-valid module to validate, got \{msg}")
  }
  let facts = gen_valid_feature_facts(mod, config.mode)
  let stats = GenValidFeatureStats::empty(config.mode).record(facts)
  assert_true(validate_valid_feature_actual_count(stats, BrTable) > 0)
  assert_true(
    validate_valid_feature_actual_count(stats, StandaloneUnreachable) > 0,
  )
  assert_true(validate_valid_feature_actual_count(stats, LocalTee) > 0)
  assert_true(validate_valid_feature_actual_count(stats, TypedSelect) > 0)
  assert_eq(
    check_validate_valid_feature_floors(stats, [
      { key: BrTable, min_count: 1 },
      { key: StandaloneUnreachable, min_count: 1 },
      { key: LocalTee, min_count: 1 },
      { key: TypedSelect, min_count: 1 },
    ]),
    [],
  )
}

///|
fn validate_test_tail_call_forms_merge(
  left : (Bool, Bool, Bool),
  right : (Bool, Bool, Bool),
) -> (Bool, Bool, Bool) {
  let (left_direct, left_indirect, left_ref) = left
  let (right_direct, right_indirect, right_ref) = right
  (
    left_direct || right_direct,
    left_indirect || right_indirect,
    left_ref || right_ref,
  )
}

///|
fn validate_test_tail_call_forms_expr(expr : Expr) -> (Bool, Bool, Bool) {
  let Expr(instrs) = expr
  let mut forms = (false, false, false)
  for instr in instrs {
    forms = validate_test_tail_call_forms_merge(
      forms,
      validate_test_tail_call_forms_instr(instr),
    )
  }
  forms
}

///|
fn validate_test_tail_call_forms_instr(
  instr : Instruction,
) -> (Bool, Bool, Bool) {
  match instr {
    ReturnCall(_) => (true, false, false)
    ReturnCallIndirect(_, _) => (false, true, false)
    ReturnCallRef(_) => (false, false, true)
    Block(_, body) | Loop(_, body) => validate_test_tail_call_forms_expr(body)
    If(_, then_body, else_body) => {
      let mut forms = validate_test_tail_call_forms_expr(Expr::new(then_body))
      match else_body {
        Some(branch) =>
          forms = validate_test_tail_call_forms_merge(
            forms,
            validate_test_tail_call_forms_expr(Expr::new(branch)),
          )
        None => ()
      }
      forms
    }
    TryTable(_, _, body) => validate_test_tail_call_forms_expr(body)
    _ => (false, false, false)
  }
}

///|
fn validate_test_tail_call_forms_module(mod : Module) -> (Bool, Bool, Bool) {
  let mut forms = (false, false, false)
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, body) = func
        forms = validate_test_tail_call_forms_merge(
          forms,
          validate_test_tail_call_forms_expr(body),
        )
      }
    None => ()
  }
  forms
}

///|
test "gen_valid coverage-forced emits tail-call surface" {
  let config = GenValidConfig::coverage_forced_default()
  let mod = gen_valid_module_with_config(@splitmix.new(seed=0xf26004UL), config)
  match validate_module(mod) {
    Ok(_) => ()
    Err(msg) =>
      fail("expected coverage-forced gen-valid module to validate, got \{msg}")
  }
  let (has_return_call, has_return_call_indirect, has_return_call_ref) = validate_test_tail_call_forms_module(
    mod,
  )
  assert_true(has_return_call)
  assert_true(has_return_call_indirect)
  assert_true(has_return_call_ref)
  let facts = gen_valid_feature_facts(mod, config.mode)
  let stats = GenValidFeatureStats::empty(config.mode).record(facts)
  assert_true(validate_valid_feature_actual_count(stats, TailCalls) > 0)
  assert_eq(
    check_validate_valid_feature_floors(stats, [
      { key: TailCalls, min_count: 1 },
    ]),
    [],
  )
}

///|
priv struct ValidateTestMemoryForms {
  i32_load : Bool
  i64_load : Bool
  f32_load : Bool
  f64_load : Bool
  i32_load8s : Bool
  i32_load8u : Bool
  i32_load16s : Bool
  i32_load16u : Bool
  i64_load8s : Bool
  i64_load8u : Bool
  i64_load16s : Bool
  i64_load16u : Bool
  i64_load32s : Bool
  i64_load32u : Bool
  i32_store : Bool
  i64_store : Bool
  f32_store : Bool
  f64_store : Bool
  i32_store8 : Bool
  i32_store16 : Bool
  i64_store8 : Bool
  i64_store16 : Bool
  i64_store32 : Bool
  nonzero_memarg : Bool
}

///|
fn validate_test_memory_forms_empty() -> ValidateTestMemoryForms {
  {
    i32_load: false,
    i64_load: false,
    f32_load: false,
    f64_load: false,
    i32_load8s: false,
    i32_load8u: false,
    i32_load16s: false,
    i32_load16u: false,
    i64_load8s: false,
    i64_load8u: false,
    i64_load16s: false,
    i64_load16u: false,
    i64_load32s: false,
    i64_load32u: false,
    i32_store: false,
    i64_store: false,
    f32_store: false,
    f64_store: false,
    i32_store8: false,
    i32_store16: false,
    i64_store8: false,
    i64_store16: false,
    i64_store32: false,
    nonzero_memarg: false,
  }
}

///|
fn validate_test_memory_forms_merge(
  left : ValidateTestMemoryForms,
  right : ValidateTestMemoryForms,
) -> ValidateTestMemoryForms {
  {
    i32_load: left.i32_load || right.i32_load,
    i64_load: left.i64_load || right.i64_load,
    f32_load: left.f32_load || right.f32_load,
    f64_load: left.f64_load || right.f64_load,
    i32_load8s: left.i32_load8s || right.i32_load8s,
    i32_load8u: left.i32_load8u || right.i32_load8u,
    i32_load16s: left.i32_load16s || right.i32_load16s,
    i32_load16u: left.i32_load16u || right.i32_load16u,
    i64_load8s: left.i64_load8s || right.i64_load8s,
    i64_load8u: left.i64_load8u || right.i64_load8u,
    i64_load16s: left.i64_load16s || right.i64_load16s,
    i64_load16u: left.i64_load16u || right.i64_load16u,
    i64_load32s: left.i64_load32s || right.i64_load32s,
    i64_load32u: left.i64_load32u || right.i64_load32u,
    i32_store: left.i32_store || right.i32_store,
    i64_store: left.i64_store || right.i64_store,
    f32_store: left.f32_store || right.f32_store,
    f64_store: left.f64_store || right.f64_store,
    i32_store8: left.i32_store8 || right.i32_store8,
    i32_store16: left.i32_store16 || right.i32_store16,
    i64_store8: left.i64_store8 || right.i64_store8,
    i64_store16: left.i64_store16 || right.i64_store16,
    i64_store32: left.i64_store32 || right.i64_store32,
    nonzero_memarg: left.nonzero_memarg || right.nonzero_memarg,
  }
}

///|
fn validate_test_memarg_nonzero(ma : MemArg) -> Bool {
  let MemArg(U32(align_pow), _, U64(offset)) = ma
  align_pow.reinterpret_as_int() > 0 || offset > 0
}

///|
fn validate_test_memory_forms_expr(expr : Expr) -> ValidateTestMemoryForms {
  let Expr(instrs) = expr
  let mut forms = validate_test_memory_forms_empty()
  for instr in instrs {
    forms = validate_test_memory_forms_merge(
      forms,
      validate_test_memory_forms_instr(instr),
    )
  }
  forms
}

///|
fn validate_test_memory_forms_instr(
  instr : Instruction,
) -> ValidateTestMemoryForms {
  match instr {
    I32Load(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i32_load: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Load(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_load: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    F32Load(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        f32_load: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    F64Load(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        f64_load: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I32Load8S(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i32_load8s: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I32Load8U(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i32_load8u: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I32Load16S(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i32_load16s: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I32Load16U(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i32_load16u: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Load8S(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_load8s: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Load8U(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_load8u: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Load16S(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_load16s: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Load16U(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_load16u: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Load32S(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_load32s: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Load32U(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_load32u: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I32Store(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i32_store: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Store(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_store: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    F32Store(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        f32_store: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    F64Store(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        f64_store: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I32Store8(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i32_store8: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I32Store16(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i32_store16: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Store8(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_store8: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Store16(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_store16: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    I64Store32(ma) =>
      {
        ..validate_test_memory_forms_empty(),
        i64_store32: true,
        nonzero_memarg: validate_test_memarg_nonzero(ma),
      }
    Block(_, body) | Loop(_, body) => validate_test_memory_forms_expr(body)
    If(_, then_body, else_body) => {
      let mut forms = validate_test_memory_forms_expr(Expr::new(then_body))
      match else_body {
        Some(branch) =>
          forms = validate_test_memory_forms_merge(
            forms,
            validate_test_memory_forms_expr(Expr::new(branch)),
          )
        None => ()
      }
      forms
    }
    TryTable(_, _, body) => validate_test_memory_forms_expr(body)
    _ => validate_test_memory_forms_empty()
  }
}

///|
fn validate_test_memory_forms_module(mod : Module) -> ValidateTestMemoryForms {
  let mut forms = validate_test_memory_forms_empty()
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, body) = func
        forms = validate_test_memory_forms_merge(
          forms,
          validate_test_memory_forms_expr(body),
        )
      }
    None => ()
  }
  forms
}

///|
test "gen_valid coverage-forced emits scalar memory widths and memarg variation" {
  let config = GenValidConfig::coverage_forced_default()
  let mod = gen_valid_module_with_config(@splitmix.new(seed=0xf26005UL), config)
  match validate_module(mod) {
    Ok(_) => ()
    Err(msg) =>
      fail("expected coverage-forced gen-valid module to validate, got \{msg}")
  }
  let forms = validate_test_memory_forms_module(mod)
  assert_true(forms.i32_load)
  assert_true(forms.i64_load)
  assert_true(forms.f32_load)
  assert_true(forms.f64_load)
  assert_true(forms.i32_load8s)
  assert_true(forms.i32_load8u)
  assert_true(forms.i32_load16s)
  assert_true(forms.i32_load16u)
  assert_true(forms.i64_load8s)
  assert_true(forms.i64_load8u)
  assert_true(forms.i64_load16s)
  assert_true(forms.i64_load16u)
  assert_true(forms.i64_load32s)
  assert_true(forms.i64_load32u)
  assert_true(forms.i32_store)
  assert_true(forms.i64_store)
  assert_true(forms.f32_store)
  assert_true(forms.f64_store)
  assert_true(forms.i32_store8)
  assert_true(forms.i32_store16)
  assert_true(forms.i64_store8)
  assert_true(forms.i64_store16)
  assert_true(forms.i64_store32)
  assert_true(forms.nonzero_memarg)
  let facts = gen_valid_feature_facts(mod, config.mode)
  let stats = GenValidFeatureStats::empty(config.mode).record(facts)
  assert_true(
    validate_valid_feature_actual_count(stats, ScalarMemoryWidths) > 0,
  )
  assert_true(validate_valid_feature_actual_count(stats, NonzeroMemarg) > 0)
  assert_eq(
    check_validate_valid_feature_floors(stats, [
      { key: ScalarMemoryWidths, min_count: 1 },
      { key: NonzeroMemarg, min_count: 1 },
    ]),
    [],
  )
}

///|
priv struct ValidateTestMemoryLimitForms {
  zero_min : Bool
  unbounded : Bool
  shared : Bool
  memory64 : Bool
  shared_without_max : Bool
}

///|
fn validate_test_memory_limit_forms_empty() -> ValidateTestMemoryLimitForms {
  {
    zero_min: false,
    unbounded: false,
    shared: false,
    memory64: false,
    shared_without_max: false,
  }
}

///|
fn validate_test_memory_limit_forms_mem(
  forms : ValidateTestMemoryLimitForms,
  mt : MemType,
) -> ValidateTestMemoryLimitForms {
  let MemType(lim, shared) = mt
  let (zero_min, unbounded, memory64) = match lim {
    I32Limits(min, max) => (min == 0, max is None, false)
    I64Limits(min, max) => (min == 0UL, max is None, true)
  }
  {
    zero_min: forms.zero_min || zero_min,
    unbounded: forms.unbounded || unbounded,
    shared: forms.shared || shared,
    memory64: forms.memory64 || memory64,
    shared_without_max: forms.shared_without_max || (shared && unbounded),
  }
}

///|
fn validate_test_memory_limit_forms_module(
  mod : Module,
) -> ValidateTestMemoryLimitForms {
  let mut forms = validate_test_memory_limit_forms_empty()
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for imp in imports {
        let Import(_, _, extern_type) = imp
        match extern_type {
          MemExternType(mt) =>
            forms = validate_test_memory_limit_forms_mem(forms, mt)
          _ => ()
        }
      }
    None => ()
  }
  match mod.mem_sec {
    Some(MemSec(mems)) =>
      for mt in mems {
        forms = validate_test_memory_limit_forms_mem(forms, mt)
      }
    None => ()
  }
  forms
}

///|
test "gen_valid coverage-forced emits memory limit and proposal variants" {
  let config = GenValidConfig::coverage_forced_default()
  let mod = gen_valid_module_with_config(@splitmix.new(seed=0xf26006UL), config)
  match validate_module(mod) {
    Ok(_) => ()
    Err(msg) =>
      fail("expected coverage-forced gen-valid module to validate, got \{msg}")
  }
  let forms = validate_test_memory_limit_forms_module(mod)
  assert_true(forms.zero_min)
  assert_true(forms.unbounded)
  assert_true(forms.shared)
  assert_true(forms.memory64)
  assert_false(forms.shared_without_max)
  let facts = gen_valid_feature_facts(mod, config.mode)
  let stats = GenValidFeatureStats::empty(config.mode).record(facts)
  assert_true(
    validate_valid_feature_actual_count(stats, MemoryLimitVariants) > 0,
  )
  assert_eq(
    check_validate_valid_feature_floors(stats, [
      { key: MemoryLimitVariants, min_count: 1 },
    ]),
    [],
  )
}

///|
test "gen_valid memory limit variants obey proposal toggles" {
  let base = GenValidConfig::coverage_forced_default()
  let config = GenValidConfig::{
    ..base,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_memory_limit_variants: false,
      allow_shared_memories: false,
      allow_memory64: false,
    },
  }
  let mod = gen_valid_module_with_config(@splitmix.new(seed=0xf26007UL), config)
  match validate_module(mod) {
    Ok(_) => ()
    Err(msg) =>
      fail("expected toggled gen-valid module to validate, got \{msg}")
  }
  let forms = validate_test_memory_limit_forms_module(mod)
  assert_false(forms.zero_min)
  assert_false(forms.unbounded)
  assert_false(forms.shared)
  assert_false(forms.memory64)
  let facts = gen_valid_feature_facts(mod, config.mode)
  let stats = GenValidFeatureStats::empty(config.mode).record(facts)
  assert_eq(validate_valid_feature_actual_count(stats, MemoryLimitVariants), 0)
}

///|
priv struct ValidateTestTableLimitForms {
  zero_min : Bool
  unbounded : Bool
  externref_table : Bool
  gc_table : Bool
  init_expr : Bool
}

///|
fn validate_test_table_limit_forms_empty() -> ValidateTestTableLimitForms {
  {
    zero_min: false,
    unbounded: false,
    externref_table: false,
    gc_table: false,
    init_expr: false,
  }
}

///|
fn validate_test_table_limit_forms_ref(rt : RefType) -> (Bool, Bool) {
  let vt = ValType::ref_type(rt)
  (
    vt == ValType::externref(),
    vt != ValType::funcref() && vt != ValType::externref(),
  )
}

///|
fn validate_test_table_limit_forms_table(
  forms : ValidateTestTableLimitForms,
  table : Table,
) -> ValidateTestTableLimitForms {
  let Table(TableType(rt, lim), init_opt) = table
  let (zero_min, unbounded) = match lim {
    I32Limits(min, max) => (min == 0U, max is None)
    I64Limits(min, max) => (min == 0UL, max is None)
  }
  let (externref_table, gc_table) = validate_test_table_limit_forms_ref(rt)
  {
    zero_min: forms.zero_min || zero_min,
    unbounded: forms.unbounded || unbounded,
    externref_table: forms.externref_table || externref_table,
    gc_table: forms.gc_table || gc_table,
    init_expr: forms.init_expr || init_opt is Some(_),
  }
}

///|
fn validate_test_table_limit_forms_module(
  mod : Module,
) -> ValidateTestTableLimitForms {
  let mut forms = validate_test_table_limit_forms_empty()
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for imp in imports {
        let Import(_, _, extern_type) = imp
        match extern_type {
          TableExternType(table_type) =>
            forms = validate_test_table_limit_forms_table(
              forms,
              Table::new(table_type, None),
            )
          _ => ()
        }
      }
    None => ()
  }
  match mod.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        forms = validate_test_table_limit_forms_table(forms, table)
      }
    None => ()
  }
  forms
}

///|
test "gen_valid coverage-forced emits table limit and initializer variants" {
  let config = GenValidConfig::coverage_forced_default()
  let mod = gen_valid_module_with_config(@splitmix.new(seed=0xf26008UL), config)
  match validate_module(mod) {
    Ok(_) => ()
    Err(msg) =>
      fail("expected coverage-forced gen-valid module to validate, got \{msg}")
  }
  let forms = validate_test_table_limit_forms_module(mod)
  assert_true(forms.zero_min)
  assert_true(forms.unbounded)
  assert_true(forms.externref_table)
  assert_true(forms.gc_table)
  assert_true(forms.init_expr)
  let facts = gen_valid_feature_facts(mod, config.mode)
  let stats = GenValidFeatureStats::empty(config.mode).record(facts)
  assert_true(
    validate_valid_feature_actual_count(stats, TableLimitVariants) > 0,
  )
  assert_eq(
    check_validate_valid_feature_floors(stats, [
      { key: TableLimitVariants, min_count: 1 },
    ]),
    [],
  )
}

///|
test "gen_valid table limit variants obey toggle" {
  let base = GenValidConfig::coverage_forced_default()
  let config = GenValidConfig::{
    ..base,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_table_limit_variants: false,
    },
  }
  let mod = gen_valid_module_with_config(@splitmix.new(seed=0xf26009UL), config)
  match validate_module(mod) {
    Ok(_) => ()
    Err(msg) =>
      fail("expected toggled gen-valid module to validate, got \{msg}")
  }
  let forms = validate_test_table_limit_forms_module(mod)
  assert_false(forms.zero_min)
  assert_false(forms.unbounded)
  assert_false(forms.init_expr)
  let facts = gen_valid_feature_facts(mod, config.mode)
  let stats = GenValidFeatureStats::empty(config.mode).record(facts)
  assert_eq(validate_valid_feature_actual_count(stats, TableLimitVariants), 0)
}

///|
priv struct ValidateTestConstExprForms {
  global_get_in_global : Bool
  prior_global_get_in_global : Bool
  ref_func_in_global : Bool
  gc_ref_in_global : Bool
  global_get_in_table_init : Bool
  global_get_in_elem_offset : Bool
  global_get_in_data_offset : Bool
}

///|
fn validate_test_const_expr_forms_empty() -> ValidateTestConstExprForms {
  {
    global_get_in_global: false,
    prior_global_get_in_global: false,
    ref_func_in_global: false,
    gc_ref_in_global: false,
    global_get_in_table_init: false,
    global_get_in_elem_offset: false,
    global_get_in_data_offset: false,
  }
}

///|
fn validate_test_expr_has_global_get(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      GlobalGet(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn validate_test_expr_has_ref_func(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      RefFunc(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn validate_test_expr_has_gc_const(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      StructNew(_)
      | StructNewDefault(_)
      | StructNewDesc(_)
      | StructNewDefaultDesc(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn validate_test_imported_global_count(mod : Module) -> Int {
  match mod.import_sec {
    Some(ImportSec(imports)) => {
      let mut count = 0
      for imp in imports {
        let Import(_, _, extern_type) = imp
        match extern_type {
          GlobalExternType(_) => count += 1
          _ => ()
        }
      }
      count
    }
    None => 0
  }
}

///|
fn validate_test_expr_has_prior_global_get(
  expr : Expr,
  upper_bound : Int,
) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      GlobalGet(idx) => {
        let GlobalIdx(idx_u) = idx
        if idx_u.reinterpret_as_int() < upper_bound {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn validate_test_const_expr_forms_module(
  mod : Module,
) -> ValidateTestConstExprForms {
  let mut forms = validate_test_const_expr_forms_empty()
  let imported_global_count = validate_test_imported_global_count(mod)
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for i = 0; i < globals.length(); i = i + 1 {
        let Global(_, init) = globals[i]
        forms = {
          ..forms,
          global_get_in_global: forms.global_get_in_global ||
          validate_test_expr_has_global_get(init),
          prior_global_get_in_global: forms.prior_global_get_in_global ||
          validate_test_expr_has_prior_global_get(
            init,
            imported_global_count + i,
          ),
          ref_func_in_global: forms.ref_func_in_global ||
          validate_test_expr_has_ref_func(init),
          gc_ref_in_global: forms.gc_ref_in_global ||
          validate_test_expr_has_gc_const(init),
        }
      }
    None => ()
  }
  match mod.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(_, init_opt) = table
        match init_opt {
          Some(init) =>
            forms = {
              ..forms,
              global_get_in_table_init: forms.global_get_in_table_init ||
              validate_test_expr_has_global_get(init),
            }
          None => ()
        }
      }
    None => ()
  }
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(mode, _) = elem
        match mode {
          Active(_, offset) =>
            forms = {
              ..forms,
              global_get_in_elem_offset: forms.global_get_in_elem_offset ||
              validate_test_expr_has_global_get(offset),
            }
          _ => ()
        }
      }
    None => ()
  }
  match mod.data_sec {
    Some(DataSec(datas)) =>
      for data in datas {
        let Data(mode, _) = data
        match mode {
          Active(_, offset) =>
            forms = {
              ..forms,
              global_get_in_data_offset: forms.global_get_in_data_offset ||
              validate_test_expr_has_global_get(offset),
            }
          Passive => ()
        }
      }
    None => ()
  }
  forms
}

///|
test "gen_valid coverage-forced emits const-expression variants" {
  let config = GenValidConfig::coverage_forced_default()
  let mod = gen_valid_module_with_config(@splitmix.new(seed=0xf2600aUL), config)
  match validate_module(mod) {
    Ok(_) => ()
    Err(msg) =>
      fail("expected coverage-forced gen-valid module to validate, got \{msg}")
  }
  let forms = validate_test_const_expr_forms_module(mod)
  assert_true(forms.global_get_in_global)
  assert_true(forms.prior_global_get_in_global)
  assert_true(forms.ref_func_in_global)
  assert_true(forms.gc_ref_in_global)
  assert_true(forms.global_get_in_table_init)
  assert_true(forms.global_get_in_elem_offset)
  assert_true(forms.global_get_in_data_offset)
  let facts = gen_valid_feature_facts(mod, config.mode)
  let stats = GenValidFeatureStats::empty(config.mode).record(facts)
  assert_true(validate_valid_feature_actual_count(stats, ConstExprVariants) > 0)
  assert_eq(
    check_validate_valid_feature_floors(stats, [
      { key: ConstExprVariants, min_count: 1 },
    ]),
    [],
  )
}

///|
test "run_validate_valid_fuzz rejects unknown profile" {
  match run_validate_valid_fuzz("not-a-profile", 0x5eedUL) {
    Ok(_) => fail("expected unknown profile error")
    Err(msg) => assert_true(msg.contains("unknown validate-valid fuzz profile"))
  }
}

///|
test "run_validate_valid_fuzz returns deterministic stats for a fixed seed" {
  let first = match run_validate_valid_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let second = match run_validate_valid_fuzz("smoke", 0x5eedUL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  assert_eq(first, second)
  assert_eq(first.attempts, 128)
  assert_eq(first.validated, 128)
  assert_eq(first.generator_config.mode, Natural)
  assert_eq(first.feature_stats.mode, Natural)
  assert_eq(
    first.feature_floors,
    match validate_valid_run_config("smoke") {
      Ok(v) => v.feature_floors
      Err(msg) => fail(msg)
    },
  )
  assert_eq(first.feature_stats.modules, 128)
  assert_eq(first.feature_stats.func_exports, 128)
  assert_true(first.feature_stats.imports > 0)
  assert_true(first.feature_stats.tables > 0)
  assert_true(first.feature_stats.mems > 0)
  assert_true(first.feature_stats.globals > 0)
  assert_true(first.feature_stats.tags > 0)
  assert_true(first.feature_stats.elems > 0)
  assert_true(first.feature_stats.datas > 0)
  assert_true(first.feature_stats.starts > 0)
  assert_true(first.feature_stats.lacks_start > 0)
  assert_true(first.feature_stats.ref_types > 0)
  assert_true(first.feature_stats.v128 > 0)
  assert_true(first.feature_stats.calls > 0)
  assert_true(first.feature_stats.call_indirect > 0)
  assert_true(first.feature_stats.branch_heavy_control > 0)
}

///|
test "gen_valid natural mode organically reaches descriptor/string/exn/cast gc surfaces" {
  let rnd = @splitmix.new(seed=0x5eedUL)
  let config = default_gen_valid_config()
  let mut combined = gen_valid_gc_surface_facts_empty()
  for _ in 0..<256 {
    let mod = gen_valid_module_with_config(rnd, config)
    match validate_module(mod) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected natural gen-valid module to validate, got \{validation_error_message(err)} func=\{validation_error_func_idx(err)} mod=\{mod}",
        )
    }
    combined = gen_valid_gc_surface_facts_merge(
      combined,
      gen_valid_gc_surface_facts_module(mod),
    )
  }
  assert_true(combined.struct_types > 0)
  assert_true(combined.array_types > 0)
  assert_true(combined.descriptor_types > 0)
  assert_true(combined.has_string_new)
  assert_true(combined.has_string_encode)
  assert_true(combined.has_br_on_cast)
  assert_true(combined.has_br_on_cast_fail)
  assert_true(combined.has_try_table)
  assert_true(combined.has_throw)
  assert_true(combined.has_throw_ref)
}

///|
test "gen_valid natural mode reaches exact ref globals locals bulk array ops and mixed catch try_tables" {
  let rnd = @splitmix.new(seed=0x51eedUL)
  let config = GenValidConfig::{
    ..GenValidConfig::natural_default(),
    max_type_defs: 10,
    max_tables: 3,
    max_mems: 2,
    max_tags: 2,
    max_elems: 4,
    max_datas: 4,
    max_body_depth: 3,
    section_bias: GenValidSectionBias::{
      ..GenValidSectionBias::natural_default(),
      tables_percent: 100,
      mems_percent: 100,
      tags_percent: 100,
      elems_percent: 100,
      datas_percent: 100,
    },
  }
  let mut combined = gen_valid_gc_surface_facts_empty()
  for _ in 0..<384 {
    let mod = gen_valid_module_with_config(rnd, config)
    match validate_module(mod) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected widened natural gen-valid module to validate, got \{validation_error_message(err)} func=\{validation_error_func_idx(err)} mod=\{mod}",
        )
    }
    combined = gen_valid_gc_surface_facts_merge(
      combined,
      gen_valid_gc_surface_facts_module(mod),
    )
  }
  assert_true(combined.has_exact_ref_null)
  assert_true(combined.exact_typed_ref_globals > 0)
  assert_true(combined.exact_typed_ref_locals > 0)
  ignore(combined.exact_typed_ref_results)
  assert_true(combined.has_array_new_data)
  assert_true(combined.has_array_new_elem)
  assert_true(combined.has_array_init_data)
  assert_true(combined.has_array_init_elem)
  assert_true(combined.has_mixed_catch_try_table)
  assert_true(combined.has_branchy_mixed_catch_try_table)
}

///|
test "gen_valid_tfunc returns exact refs through a real natural local flow" {
  let described_idx = TypeIdx::new(0U)
  let exact_vt = ValType::ref_type(
    RefType::new(true, HeapType::new(described_idx), exact=true),
  )
  let descriptor_pair = RecType::group([
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(descriptor=Some(TypeIdx::rec(1))),
    ),
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(describes=Some(TypeIdx::rec(0))),
    ),
  ])
  let func_type = RecType::new(
    SubType::comp_type(CompType::func([], [exact_vt])),
  )
  let rnd = @splitmix.new(seed=0x5eed5eedUL)
  let ctx = GenValidContext::new(rnd, GenValidConfig::natural_default())
  let func = gen_valid_tfunc(ctx, [], [exact_vt])
  let Func(locals, Expr(instrs)) = func
  let mut has_exact_local = false
  for run in locals.runs() {
    let { count, vt } = run
    ignore(count)
    if vt == exact_vt {
      has_exact_local = true
    }
  }
  assert_true(has_exact_local)
  match instrs.last() {
    Some(LocalGet(_)) => ()
    _ => fail("expected exact natural return flow to end with local.get")
  }
  let mod = Module::new()
    .with_type_sec(TypeSec::new([descriptor_pair, func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(2U)]))
    .with_code_sec(CodeSec::new([func]))
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact-result natural tfunc module to validate, got \{validation_error_message(err)} func=\{validation_error_func_idx(err)} mod=\{mod}",
      )
  }
}

///|
test "gen_valid_build_func reuses an exact param for natural exact-result returns" {
  let described_idx = TypeIdx::new(0U)
  let exact_rt = RefType::new(true, HeapType::new(described_idx), exact=true)
  let exact_vt = ValType::ref_type(exact_rt)
  let descriptor_pair = RecType::group([
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(descriptor=Some(TypeIdx::rec(1))),
    ),
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(describes=Some(TypeIdx::rec(0))),
    ),
  ])
  let func_type = RecType::new(
    SubType::comp_type(CompType::func([exact_vt], [exact_vt])),
  )
  let rnd = @splitmix.new(seed=0x5eedca5aUL)
  let ctx = GenValidContext::new(rnd, GenValidConfig::natural_default())
  let func = gen_valid_build_func(
    ctx,
    [exact_vt],
    [exact_vt],
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
  let Func(locals, Expr(instrs)) = func
  for run in locals.runs() {
    let { count, vt } = run
    ignore(count)
    assert_false(vt == exact_vt)
  }
  match instrs.last() {
    Some(LocalGet(idx)) => assert_eq(idx, LocalIdx::new(0U))
    _ =>
      fail("expected exact natural param return flow to end with local.get 0")
  }
  let mod = Module::new()
    .with_type_sec(TypeSec::new([descriptor_pair, func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(2U)]))
    .with_code_sec(CodeSec::new([func]))
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact-result natural param module to validate, got \{validation_error_message(err)} func=\{validation_error_func_idx(err)} mod=\{mod}",
      )
  }
}

///|
test "gen_valid_build_func can return exact refs through a natural direct call path" {
  let described_idx = TypeIdx::new(0U)
  let exact_rt = RefType::new(true, HeapType::new(described_idx), exact=true)
  let exact_vt = ValType::ref_type(exact_rt)
  let descriptor_pair = RecType::group([
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(descriptor=Some(TypeIdx::rec(1))),
    ),
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(describes=Some(TypeIdx::rec(0))),
    ),
  ])
  let func_type = RecType::new(
    SubType::comp_type(CompType::func([], [exact_vt])),
  )
  let helper_sig = {
    idx: FuncIdx::new(0U),
    type_idx: TypeIdx::new(2U),
    params: [],
    results: [exact_vt],
  }
  let rnd = @splitmix.new(seed=0x5eedc411UL)
  let ctx = GenValidContext::new(rnd, GenValidConfig::natural_default())
  let func = gen_valid_build_func(
    ctx,
    [],
    [exact_vt],
    [],
    [],
    [],
    [],
    [helper_sig],
    [],
    [],
    [],
    None,
    gen_valid_gc_type_plan_empty(),
    None,
  )
  let Func(locals, Expr(instrs)) = func
  for run in locals.runs() {
    let { count, vt } = run
    ignore(count)
    assert_false(vt == exact_vt)
  }
  match instrs.last() {
    Some(Call(idx)) => assert_eq(idx, FuncIdx::new(0U))
    _ => fail("expected exact natural return flow to end with call")
  }
  let mod = Module::new()
    .with_type_sec(TypeSec::new([descriptor_pair, func_type]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("helper"),
          ExternType::func(TypeIdx::new(2U)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(2U)]))
    .with_code_sec(CodeSec::new([func]))
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact-result natural direct-call module to validate, got \{validation_error_message(err)} func=\{validation_error_func_idx(err)} mod=\{mod}",
      )
  }
}

///|
test "gen_valid_build_func can return exact refs through a natural call_ref path" {
  let described_idx = TypeIdx::new(0U)
  let exact_rt = RefType::new(true, HeapType::new(described_idx), exact=true)
  let exact_vt = ValType::ref_type(exact_rt)
  let descriptor_pair = RecType::group([
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(descriptor=Some(TypeIdx::rec(1))),
    ),
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(describes=Some(TypeIdx::rec(0))),
    ),
  ])
  let func_type = RecType::new(
    SubType::comp_type(CompType::func([], [exact_vt])),
  )
  let helper_sig = {
    idx: FuncIdx::new(0U),
    type_idx: TypeIdx::new(2U),
    params: [],
    results: [exact_vt],
  }
  let config = GenValidConfig::{
    ..GenValidConfig::natural_default(),
    features: GenValidFeatureToggles::{
      ..GenValidFeatureToggles::natural_default(),
      allow_calls: false,
    },
  }
  let rnd = @splitmix.new(seed=0x5eedca11UL)
  let ctx = GenValidContext::new(rnd, config)
  let caller = gen_valid_build_func(
    ctx,
    [],
    [exact_vt],
    [],
    [],
    [],
    [],
    [helper_sig],
    [],
    [],
    [],
    None,
    gen_valid_gc_type_plan_empty(),
    Some(FuncIdx::new(0U)),
  )
  let Func(locals, Expr(instrs)) = caller
  for run in locals.runs() {
    let { count, vt } = run
    ignore(count)
    assert_false(vt == exact_vt)
  }
  match instrs.length() {
    n if n >= 2 => {
      assert_eq(instrs[n - 2], Instruction::ref_func(FuncIdx::new(0U)))
      assert_eq(instrs[n - 1], Instruction::call_ref(TypeIdx::new(2U)))
    }
    _ =>
      fail(
        "expected exact natural call_ref return flow to emit ref.func + call_ref",
      )
  }
  let helper = Func::new(
    Locals::empty(),
    Expr::new([Instruction::ref_null_type(exact_rt)]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([descriptor_pair, func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(2U), TypeIdx::new(2U)]))
    .with_code_sec(CodeSec::new([helper, caller]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("helper"), ExternIdx::func(FuncIdx::new(0U))),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact-result natural call_ref module to validate, got \{validation_error_message(err)} func=\{validation_error_func_idx(err)} mod=\{mod}",
      )
  }
}

///|
test "gen_valid coverage-forced mode emits widened topology and shared type pool" {
  let rnd = @splitmix.new(seed=0x5eedUL)
  let config = GenValidConfig::coverage_forced_default()
  let mut feature_stats = GenValidFeatureStats::empty(CoverageForced)
  let mut body_surface = gen_valid_body_surface_facts_empty()
  let mut coverage_surface = gen_valid_coverage_surface_facts_empty()
  let mut gc_surface = gen_valid_gc_surface_facts_empty()
  let mut has_gc_table = false
  let mut has_shared_type_pool = false

  for _ in 0..<64 {
    let mod = gen_valid_module_with_config(rnd, config)
    match validate_module(mod) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected coverage-forced module to validate, got \{validation_error_message(err)} func=\{validation_error_func_idx(err)} mod=\{mod}",
        )
    }
    feature_stats = feature_stats.record(
      gen_valid_feature_facts(mod, CoverageForced),
    )
    body_surface = gen_valid_body_surface_facts_merge(
      body_surface,
      gen_valid_body_surface_facts_module(mod),
    )
    coverage_surface = gen_valid_coverage_surface_facts_merge(
      coverage_surface,
      gen_valid_coverage_surface_facts_module(mod),
    )
    gc_surface = gen_valid_gc_surface_facts_merge(
      gc_surface,
      gen_valid_gc_surface_facts_module(mod),
    )

    match mod.table_sec {
      Some(TableSec(tables)) =>
        for table in tables {
          let Table(TableType(rt, _), _) = table
          if gen_valid_gc_surface_ref_score(rt) > 0 &&
            rt != RefType::abs(AbsHeapType::func()) {
            has_gc_table = true
          }
        }
      None => ()
    }
    let import_func_count = match mod.import_sec {
      Some(ImportSec(imports)) => {
        let mut count = 0
        for imp in imports {
          let Import(_, _, extern_type) = imp
          match extern_type {
            FuncExternType(_) => count += 1
            _ => ()
          }
        }
        count
      }
      None => 0
    }
    let defined_func_count = match mod.func_sec {
      Some(FuncSec(type_idxs)) => type_idxs.length()
      None => 0
    }
    let tag_count = match mod.tag_sec {
      Some(TagSec(tags)) => tags.length()
      None => 0
    }
    let func_type_def_count = match mod.type_sec {
      Some(TypeSec(types)) => {
        let mut count = 0
        for rec_type in types {
          match rec_type {
            SingleRecType(subtype) =>
              if subtype.get_comptype() is FuncCompType(_, _) {
                count += 1
              }
            GroupRecType(group) =>
              for subtype in group {
                if subtype.get_comptype() is FuncCompType(_, _) {
                  count += 1
                }
              }
          }
        }
        count
      }
      None => 0
    }
    if import_func_count > 0 &&
      defined_func_count > 0 &&
      tag_count > 0 &&
      func_type_def_count < import_func_count + defined_func_count + tag_count {
      has_shared_type_pool = true
    }
  }

  assert_true(feature_stats.imports > 0)
  assert_true(feature_stats.func_exports > 0)
  assert_true(feature_stats.table_exports > 0)
  assert_true(feature_stats.mem_exports > 0)
  assert_true(feature_stats.global_exports > 0)
  assert_true(feature_stats.tag_exports > 0)
  assert_true(feature_stats.starts > 0)
  assert_true(feature_stats.tables > 0)
  assert_true(feature_stats.mems > 0)
  assert_true(feature_stats.globals > 0)
  assert_true(feature_stats.tags > 0)
  assert_true(feature_stats.elems > 0)
  assert_true(feature_stats.datas > 0)
  assert_true(feature_stats.data_count > 0)
  assert_true(feature_stats.ref_types > 0)
  assert_true(feature_stats.v128 > 0)
  assert_true(feature_stats.calls > 0)
  assert_true(feature_stats.call_indirect > 0)
  assert_true(feature_stats.branch_heavy_control > 0)

  assert_true(body_surface.has_block)
  assert_true(body_surface.has_loop)
  assert_true(body_surface.has_if)
  assert_true(body_surface.has_br)
  assert_true(body_surface.has_br_if)
  assert_true(body_surface.has_memory_op)
  assert_true(body_surface.has_table_op)

  assert_true(coverage_surface.import_funcs > 0)
  assert_true(coverage_surface.import_tables > 0)
  assert_true(coverage_surface.import_mems > 0)
  assert_true(coverage_surface.import_globals > 0)
  assert_true(coverage_surface.import_tags > 0)
  assert_true(coverage_surface.passive_elems > 0)
  assert_true(coverage_surface.declarative_elems > 0)
  assert_true(coverage_surface.passive_datas > 0)
  assert_true(coverage_surface.has_memory_init)
  assert_true(coverage_surface.has_data_drop)
  assert_true(coverage_surface.has_memory_copy)
  assert_true(coverage_surface.has_memory_fill)
  assert_true(coverage_surface.has_table_init)
  assert_true(coverage_surface.has_elem_drop)
  assert_true(coverage_surface.has_table_copy)
  assert_true(coverage_surface.has_table_fill)

  assert_true(gc_surface.struct_types > 0)
  assert_true(gc_surface.array_types > 0)
  assert_true(gc_surface.descriptor_types > 0)
  assert_true(gc_surface.rec_groups > 0)
  assert_true(gc_surface.typed_ref_globals > 0)
  assert_true(gc_surface.typed_ref_tables > 0)
  assert_true(gc_surface.typed_ref_locals > 0)
  assert_true(gc_surface.exact_typed_ref_globals > 0)
  assert_true(gc_surface.exact_typed_ref_locals > 0)
  ignore(gc_surface.exact_typed_ref_results)
  assert_true(has_gc_table)
  assert_true(gc_surface.has_struct_new)
  assert_true(gc_surface.has_struct_get)
  assert_true(gc_surface.has_struct_set)
  assert_true(gc_surface.has_array_new)
  assert_true(gc_surface.has_array_get)
  assert_true(gc_surface.has_array_set)
  assert_true(gc_surface.has_array_len)
  assert_true(gc_surface.has_string_const)
  assert_true(gc_surface.has_string_new)
  assert_true(gc_surface.has_string_encode)
  assert_true(gc_surface.has_ref_get_desc)
  assert_true(gc_surface.has_ref_test)
  assert_true(gc_surface.has_ref_test_desc)
  assert_true(gc_surface.has_ref_cast)
  assert_true(gc_surface.has_ref_cast_desc_eq)
  assert_true(gc_surface.has_ref_eq)
  assert_true(gc_surface.has_ref_as_non_null)
  assert_true(gc_surface.has_call_ref)
  assert_true(gc_surface.has_br_on_null)
  assert_true(gc_surface.has_br_on_non_null)
  assert_true(gc_surface.has_br_on_cast)
  assert_true(gc_surface.has_br_on_cast_fail)
  assert_true(gc_surface.has_try_table)
  assert_true(gc_surface.has_throw)
  assert_true(gc_surface.has_throw_ref)
  assert_true(has_shared_type_pool)
}

///|
test "gen_valid_feature_facts record imports sections exports and instruction families" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("callee"),
          ExternType::func(TypeIdx::new(0U)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_table_sec(
      TableSec::new([
        Table::new(
          TableType::new(
            RefType::abs(AbsHeapType::func()),
            Limits::i32(1U, Some(1U)),
          ),
          None,
        ),
      ]),
    )
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, Some(1U)))]))
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0U))]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::v128(), false),
          Expr::new([
            Instruction::v128_const(
              b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
              b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
            ),
          ]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(1U))),
        Export::new(Name::new("table"), ExternIdx::table(TableIdx::new(0U))),
        Export::new(Name::new("memory"), ExternIdx::mem(MemIdx::new(0U))),
        Export::new(Name::new("global"), ExternIdx::global(GlobalIdx::new(0U))),
        Export::new(Name::new("tag"), ExternIdx::tag(TagIdx::new(0U))),
      ]),
    )
    .with_start_sec(StartSec::new(FuncIdx::new(1U)))
    .with_elem_sec(
      ElemSec::new([
        Elem::new(
          ElemMode::active(
            TableIdx::new(0U),
            Expr::new([Instruction::i32_const(I32(0))]),
          ),
          ElemKind::funcs([FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_data_cnt_sec(DataCntSec::new(U32(1U)))
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
            Instruction::call(FuncIdx::new(0U)),
            Instruction::i32_const(I32(0)),
            Instruction::call_indirect(TypeIdx::new(0U), TableIdx::new(0U)),
            Instruction::block(BlockType::void_(), Expr::new([])),
            Instruction::loop_(BlockType::void_(), Expr::new([])),
            Instruction::i32_const(I32(1)),
            Instruction::if_(
              BlockType::void_(),
              [Instruction::nop()],
              Some([Instruction::nop()]),
            ),
          ]),
        ),
      ]),
    )
  let facts = gen_valid_feature_facts(mod, CoverageForced)
  assert_eq(facts.mode, CoverageForced)
  assert_true(facts.has_imports)
  assert_true(facts.has_func_exports)
  assert_true(facts.has_table_exports)
  assert_true(facts.has_mem_exports)
  assert_true(facts.has_global_exports)
  assert_true(facts.has_tag_exports)
  assert_true(facts.has_start)
  assert_false(facts.lacks_start)
  assert_true(facts.has_tables)
  assert_true(facts.has_mems)
  assert_true(facts.has_tags)
  assert_true(facts.has_globals)
  assert_true(facts.has_elems)
  assert_true(facts.has_datas)
  assert_true(facts.has_data_count)
  assert_true(facts.uses_ref_types)
  assert_true(facts.uses_v128)
  assert_true(facts.has_call)
  assert_true(facts.has_call_indirect)
  assert_true(facts.has_branch_heavy_control)
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
test "validate_module reports imported-prefix func idx for missing data count" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mem = MemType::new(Limits::i32(1U, Some(1U)))
  let data = Data::new(DataMode::passive(), b"x")
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("f"),
          ExternType::func(TypeIdx::new(0U)),
        ),
      ]),
    )
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

  match validate_module(mod) {
    Ok(_) => fail("expected memory.init without datacount to fail")
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(1U)))
      assert_true(
        validation_error_message(err).contains("data count section required"),
      )
    }
  }
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
test "validate_module reports imported-prefix func idx for undeclared ref.func in body" {
  let sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("f"),
          ExternType::func(TypeIdx::new(0U)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::ref_func(FuncIdx::new(1U)),
            Instruction::drop(),
          ]),
        ),
      ]),
    )

  match validate_module(mod) {
    Ok(_) => fail("expected undeclared function reference to fail validation")
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(1U)))
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
test "validate_module accepts arithmetic in const expressions" {
  let mod = Module::new()
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([
            Instruction::i32_const(I32(-877605212)),
            Instruction::i32_const(I32(1580649160)),
            Instruction::i32_sub(),
          ]),
        ),
      ]),
    )
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
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected arithmetic const expressions to validate: \{validation_error_message(err)}",
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
            Expr::new([Instruction::i32_const(I32(1)), Instruction::drop()]),
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
test "validate_module accepts descriptor metadata that uses RecIdx targets" {
  let descriptor_group = RecType::group([
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(descriptor=Some(TypeIdx::rec(1))),
    ),
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(describes=Some(TypeIdx::rec(0))),
    ),
  ])
  let mod = Module::new().with_type_sec(TypeSec::new([descriptor_group]))
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected RecIdx descriptor metadata to validate: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module rejects RecIdx descriptor targets outside the current group" {
  let bad_group = RecType::group([
    SubType::comp_type(CompType::struct_([])),
    SubType::comp_type(
      CompType::struct_([]),
      metadata=TypeMetadata::new(describes=Some(TypeIdx::rec(2))),
    ),
  ])
  let mod = Module::new().with_type_sec(TypeSec::new([bad_group]))
  match validate_module(mod) {
    Ok(_) =>
      fail("expected out-of-range RecIdx describes target to fail validation")
    Err(err) =>
      assert_true(
        validation_error_message(err).contains("must be a valid type"),
      )
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
          Expr::new([Instruction::loop_(BlockType::void_(), Expr::new([]))]),
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
test "validate_module rejects typed if branch result mismatch hidden behind terminal block after br_if" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::if_(
              BlockType::val_type(ValType::i64()),
              [
                Instruction::block(
                  BlockType::void_(),
                  Expr::new([
                    Instruction::loop_(
                      BlockType::void_(),
                      Expr::new([
                        Instruction::i32_const(I32(0)),
                        Instruction::br_if(LabelIdx::new(1U)),
                      ]),
                    ),
                    Instruction::unreachable_(),
                  ]),
                ),
                Instruction::i32_const(I32(1)),
              ],
              Some([Instruction::i64_const(@lib.I64::new(0L))]),
            ),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) =>
      fail(
        "expected typed if branch result mismatch after conditional block escape to fail validation",
      )
    Err(err) => {
      assert_eq(validation_error_func_idx(err), Some(FuncIdx::new(0U)))
      let msg = validation_error_message(err)
      assert_true(msg.contains("type mismatch"), msg~)
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
                Instruction::loop_(BlockType::void_(), Expr::new([])),
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
test "validate_module accepts outer if when nested outer-label branches skip the merge" {
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
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested outer-label branches to skip the outer if merge cleanly: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module accepts nested result if ladder when deeper branches skip later returns" {
  let sig = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i64()])),
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
                Instruction::block(
                  BlockType::void_(),
                  Expr::new([
                    Instruction::local_get(LocalIdx::new(0U)),
                    Instruction::if_(
                      BlockType::val_type(ValType::i64()),
                      [
                        Instruction::local_get(LocalIdx::new(0U)),
                        Instruction::drop(),
                        Instruction::br(LabelIdx::new(1U)),
                      ],
                      Some([
                        Instruction::local_get(LocalIdx::new(0U)),
                        Instruction::if_(
                          BlockType::val_type(ValType::i64()),
                          [
                            Instruction::local_get(LocalIdx::new(0U)),
                            Instruction::drop(),
                            Instruction::br(LabelIdx::new(2U)),
                          ],
                          Some([
                            Instruction::local_get(LocalIdx::new(0U)),
                            Instruction::if_(
                              BlockType::val_type(ValType::i64()),
                              [
                                Instruction::local_get(LocalIdx::new(0U)),
                                Instruction::drop(),
                                Instruction::br(LabelIdx::new(4U)),
                              ],
                              Some([
                                Instruction::local_get(LocalIdx::new(0U)),
                                Instruction::if_(
                                  BlockType::val_type(ValType::i64()),
                                  [
                                    Instruction::local_get(LocalIdx::new(0U)),
                                    Instruction::drop(),
                                    Instruction::br(LabelIdx::new(5U)),
                                  ],
                                  Some([
                                    Instruction::i64_const(I64(4294967296L)),
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                    Instruction::return_(),
                  ]),
                ),
                Instruction::i64_const(I64(0L)),
                Instruction::return_(),
              ]),
            ),
            Instruction::i64_const(I64(1L)),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested branch ladder to skip later returns cleanly: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module accepts result if that can either return or escape to later continuation" {
  let ret_sig = RecType::new(
    SubType::comp_type(
      CompType::func([ValType::i32(), ValType::i32()], [ValType::i32()]),
    ),
  )
  let join_sig = RecType::new(
    SubType::comp_type(
      CompType::func([ValType::i32(), ValType::i32()], [ValType::i32()]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ret_sig, join_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::local_get(LocalIdx::new(1U)),
            Instruction::i32_add(),
          ]),
        ),
        Func::new(
          Locals::from_types([ValType::i32()]),
          Expr::new([
            Instruction::block(
              BlockType::void_(),
              Expr::new([
                Instruction::local_get(LocalIdx::new(0U)),
                Instruction::if_(
                  BlockType::val_type(ValType::i32()),
                  [Instruction::i32_const(I32(0))],
                  Some([
                    Instruction::local_get(LocalIdx::new(0U)),
                    Instruction::if_(
                      BlockType::val_type(ValType::i32()),
                      [
                        Instruction::i32_const(I32(7)),
                        Instruction::local_set(LocalIdx::new(2U)),
                        Instruction::br(LabelIdx::new(2U)),
                      ],
                      Some([
                        Instruction::i32_const(I32(8)),
                        Instruction::local_set(LocalIdx::new(2U)),
                        Instruction::br(LabelIdx::new(2U)),
                      ]),
                    ),
                  ]),
                ),
                Instruction::return_(),
              ]),
            ),
            Instruction::local_get(LocalIdx::new(2U)),
            Instruction::local_get(LocalIdx::new(1U)),
            Instruction::call(FuncIdx::new(0U)),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected mixed return-or-escape if fixture to validate: \{validation_error_message(err)}",
      )
  }
}

///|
test "validate_module accepts result if that can either branch to current block or return" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::block(
              BlockType::val_type(ValType::i32()),
              Expr::new([
                Instruction::i32_const(I32(1)),
                Instruction::if_(
                  BlockType::val_type(ValType::i32()),
                  [
                    Instruction::i32_const(I32(7)),
                    Instruction::br(LabelIdx::new(1U)),
                  ],
                  Some([Instruction::i32_const(I32(8)), Instruction::return_()]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected branch-or-return result if fixture to validate: \{validation_error_message(err)}",
      )
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
test "shared MemType validates with valid max" {
  let env = empty_env()
  let mt = MemType::new(Limits::i32(0, Some(100)), shared=true)
  assert_eq(Validate::validate(mt, env), Ok(()))
}

///|
test "memory64 MemType validates with large max" {
  let env = empty_env()
  let mt = MemType::new(Limits::i64(5250UL, Some(7098475342658UL)))
  assert_eq(Validate::validate(mt, env), Ok(()))
}

///|
test "shared MemType fails without max" {
  let env = empty_env()
  let mt = MemType::new(Limits::i32(0, None), shared=true)
  assert_eq(Validate::validate(mt, env), Err("shared memories require a max"))
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

///|
test "validate_module accepts raw type-index loop with terminal return continuation" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(
          SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
        ),
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i64()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::i32_const(@lib.I32::new(0)),
            Instruction::loop_(
              BlockType::type_idx(TypeIdx::new(0U)),
              Expr::new([Instruction::unreachable_()]),
            ),
            Instruction::i64_const(@lib.I64::new(1L)),
            Instruction::return_(),
            Instruction::unreachable_(),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected raw type-index loop terminal-return fixture to validate, got \{validation_error_message(e)}",
      )
  }
}

///|
test "validate_module accepts raw type-index loop branch-payload bypass with terminal return" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
        RecType::new(
          SubType::comp_type(CompType::func([ValType::i32()], [ValType::i64()])),
        ),
        RecType::new(
          SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::drop(),
          ]),
        ),
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::i32_const(@lib.I32::new(0)),
            Instruction::loop_(
              BlockType::type_idx(TypeIdx::new(2U)),
              Expr::new([
                Instruction::block(
                  BlockType::val_type(ValType::i32()),
                  Expr::new([
                    Instruction::block(
                      BlockType::void_(),
                      Expr::new([
                        Instruction::i32_const(@lib.I32::new(1)),
                        Instruction::if_(
                          BlockType::val_type(ValType::i32()),
                          [
                            Instruction::i32_const(@lib.I32::new(0)),
                            Instruction::if_(
                              BlockType::val_type(ValType::i32()),
                              [Instruction::local_get(LocalIdx::new(0U))],
                              Some([
                                Instruction::local_get(LocalIdx::new(0U)),
                                Instruction::call(FuncIdx::new(0U)),
                                Instruction::br(LabelIdx::new(2U)),
                              ]),
                            ),
                          ],
                          Some([
                            Instruction::local_get(LocalIdx::new(0U)),
                            Instruction::call(FuncIdx::new(0U)),
                            Instruction::br(LabelIdx::new(1U)),
                          ]),
                        ),
                        Instruction::br(LabelIdx::new(1U)),
                      ]),
                    ),
                    Instruction::unreachable_(),
                  ]),
                ),
                Instruction::unreachable_(),
              ]),
            ),
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::call(FuncIdx::new(0U)),
            Instruction::i64_const(@lib.I64::new(1L)),
            Instruction::return_(),
            Instruction::unreachable_(),
          ]),
        ),
      ]),
    )
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected raw type-index loop branch-payload bypass fixture to validate, got \{validation_error_message(e)}",
      )
  }
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
fn validate_import_name_section_fixture_module() -> Module {
  let func_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([func_type]))
  .with_import_sec(
    ImportSec::new([
      Import::new(
        Name::new("env"),
        Name::new("f"),
        ExternType::func(TypeIdx::new(0U)),
      ),
    ]),
  )
}

///|
test "validate_module accepts structured name section" {
  let mod = validate_name_section_fixture_module()
  assert_eq(validate_module(mod), Ok(()))
}

///|
test "validate_module rejects out-of-range function name index in name section" {
  let mod = validate_name_section_fixture_module().with_name_sec(
    NameSec::new(
      func_names=Some(NameMap::new([NameAssoc::new(1U, Name::new("bad"))])),
    ),
  )

  match validate_module(mod) {
    Ok(_) => fail("expected invalid function name section validation failure")
    Err(err) => {
      assert_true(
        validation_error_message(err).contains(
          "function name index out of range",
        ),
      )
      assert_eq(
        validation_error_diagnostic(err).issue,
        ValidationIssue::NameSection(
          "function name index out of range: func=1 total_funcs=1",
        ),
      )
    }
  }
}

///|
test "validate_module rejects out-of-range type name index in name section" {
  let mod = validate_name_section_fixture_module().with_name_sec(
    NameSec::new(
      type_names=Some(NameMap::new([NameAssoc::new(3U, Name::new("bad"))])),
    ),
  )

  match validate_module(mod) {
    Ok(_) => fail("expected invalid type name section validation failure")
    Err(err) => {
      assert_true(
        validation_error_message(err).contains("type name index out of range"),
      )
      assert_eq(
        validation_error_diagnostic(err).issue,
        ValidationIssue::NameSection(
          "type name index out of range: type=3 total_types=3",
        ),
      )
    }
  }
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
test "validate_module accepts imported function local names for params" {
  let mod = validate_import_name_section_fixture_module().with_name_sec(
    NameSec::new(
      local_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([NameAssoc::new(0U, Name::new("x"))]),
          ),
        ]),
      ),
    ),
  )

  match validate_module(mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected imported function local names to validate: \{validation_error_message(err)}",
      )
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
test "validate_module rejects imported function label names because imports have no body labels" {
  let mod = validate_import_name_section_fixture_module().with_name_sec(
    NameSec::new(
      label_names=Some(
        IndirectNameMap::new([
          IndirectNameAssoc::new(
            0U,
            NameMap::new([NameAssoc::new(0U, Name::new("entry"))]),
          ),
        ]),
      ),
    ),
  )

  match validate_module(mod) {
    Ok(_) =>
      fail("expected invalid imported-function label name section failure")
    Err(err) => {
      assert_true(
        validation_error_message(err).contains("label name index out of range"),
      )
      assert_eq(
        validation_error_diagnostic(err).issue,
        ValidationIssue::NameSection(
          "label name index out of range: func=0 label=0 total_labels=0",
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
