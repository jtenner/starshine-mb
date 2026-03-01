///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
priv enum SGConstValue {
  SGI32(I32)
  SGI64(I64)
  SGF32(F32)
  SGF64(F64)
  SGRefNull(HeapType)
  SGRefFunc(FuncIdx)
} derive(Eq)

///|
priv struct SGInfo {
  imported : Array[Bool]
  exported : Array[Bool]
  written : Array[Int]
  read : Array[Int]
  non_init_written : Array[Bool]
  read_only_to_write : Array[Int]
}

///|
fn SGInfo::new(total_globals : Int) -> SGInfo {
  {
    imported: Array::make(total_globals, false),
    exported: Array::make(total_globals, false),
    written: Array::make(total_globals, 0),
    read: Array::make(total_globals, 0),
    non_init_written: Array::make(total_globals, false),
    read_only_to_write: Array::make(total_globals, 0),
  }
}

///|
priv struct SGConstSlots {
  values : Array[SGConstValue?]
  epochs : Array[Int]
  mut current_epoch : Int
}

///|
fn SGConstSlots::new(total_globals : Int) -> SGConstSlots {
  {
    values: Array::make(total_globals, None),
    epochs: Array::make(total_globals, 0),
    current_epoch: 1,
  }
}

///|
fn SGConstSlots::index(self : SGConstSlots, idx : GlobalIdx) -> Int? {
  let raw = sg_globalidx_to_int(idx)
  if raw < 0 || raw >= self.values.length() {
    None
  } else {
    Some(raw)
  }
}

///|
fn SGConstSlots::get(self : SGConstSlots, idx : GlobalIdx) -> SGConstValue? {
  match self.index(idx) {
    Some(raw) =>
      if self.epochs[raw] == self.current_epoch {
        self.values[raw]
      } else {
        None
      }
    None => None
  }
}

///|
fn SGConstSlots::set(
  self : SGConstSlots,
  idx : GlobalIdx,
  value : SGConstValue,
) -> Unit {
  match self.index(idx) {
    Some(raw) => {
      self.values[raw] = Some(value)
      self.epochs[raw] = self.current_epoch
    }
    None => ()
  }
}

///|
fn SGConstSlots::remove(self : SGConstSlots, idx : GlobalIdx) -> Bool {
  match self.index(idx) {
    Some(raw) =>
      if self.epochs[raw] == self.current_epoch {
        self.values[raw] = None
        self.epochs[raw] = 0
        true
      } else {
        false
      }
    None => false
  }
}

///|
fn SGConstSlots::clear(self : SGConstSlots) -> Unit {
  self.current_epoch += 1
  if self.current_epoch > 0 {
    return
  }
  self.current_epoch = 1
  for i = 0; i < self.epochs.length(); i = i + 1 {
    self.epochs[i] = 0
    self.values[i] = None
  }
}

///|
priv struct SGRewriteSummary {
  changed : Bool
  has_call : Bool
  writes_global : Bool
}

///|
fn sg_rewrite_summary(
  changed? : Bool = false,
  has_call? : Bool = false,
  writes_global? : Bool = false,
) -> SGRewriteSummary {
  { changed, has_call, writes_global }
}

///|
fn sg_merge_rewrite_summary(
  left : SGRewriteSummary,
  right : SGRewriteSummary,
) -> SGRewriteSummary {
  {
    changed: left.changed || right.changed,
    has_call: left.has_call || right.has_call,
    writes_global: left.writes_global || right.writes_global,
  }
}

///|
priv struct SGFunctionTraceStats {
  top_instrs : Int
  mut visited_instrs : Int
  mut replaced_gets : Int
  mut boundary_resets : Int
  mut call_resets : Int
  mut global_kills : Int
  mut const_sets : Int
  mut nested_write_resets : Int
}

///|
fn SGFunctionTraceStats::new(top_instrs : Int) -> SGFunctionTraceStats {
  {
    top_instrs,
    visited_instrs: 0,
    replaced_gets: 0,
    boundary_resets: 0,
    call_resets: 0,
    global_kills: 0,
    const_sets: 0,
    nested_write_resets: 0,
  }
}

///|
fn sg_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn sg_trace_normalize_env_now_ms(raw : UInt64) -> UInt64 {
  if raw >= 100000000000000000UL {
    raw / 1000000UL
  } else if raw >= 100000000000000UL {
    raw / 1000UL
  } else {
    raw
  }
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn sg_trace_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn sg_trace_read_u64_le(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
fn sg_trace_now_ms() -> UInt64 {
  let tv = Bytes::new(16)
  if sg_trace_native_gettimeofday(tv, 0UL) != 0 {
    return sg_trace_normalize_env_now_ms(@env.now())
  }
  let sec = sg_trace_read_u64_le(tv, 0)
  let usec = sg_trace_read_u64_le(tv, 8)
  sec * 1000UL + usec / 1000UL
}

///|
#cfg(target="wasm-gc")
fn sg_trace_now_ms() -> UInt64 {
  sg_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="wasm")
fn sg_trace_now_ms() -> UInt64 {
  sg_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="js")
fn sg_trace_now_ms() -> UInt64 {
  sg_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="llvm")
fn sg_trace_now_ms() -> UInt64 {
  sg_trace_normalize_env_now_ms(@env.now())
}

///|
fn sg_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  let end_ms = sg_trace_now_ms()
  if end_ms >= start_ms {
    end_ms - start_ms
  } else {
    0UL
  }
}

///|
fn sg_globalidx_to_int(idx : GlobalIdx) -> Int {
  let GlobalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn sg_globalidx_from_int(idx : Int) -> GlobalIdx {
  GlobalIdx::new(idx.reinterpret_as_uint())
}

///|
fn sg_count_imported_globals(mod : Module) -> Int {
  let mut n = 0
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
fn sg_collect_global_types(mod : Module) -> Array[GlobalType] {
  let out : Array[GlobalType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(gt)) => out.push(gt)
          _ => ()
        }
      }
    None => ()
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(gt, _) = global
        out.push(gt)
      }
    None => ()
  }
  out
}

///|
fn sg_defined_index(
  imported_globals : Int,
  defined_count : Int,
  idx : GlobalIdx,
) -> Int? {
  let raw = sg_globalidx_to_int(idx)
  let def = raw - imported_globals
  if def >= 0 && def < defined_count {
    Some(def)
  } else {
    None
  }
}

///|
fn sg_const_value_from_instruction(instr : Instruction) -> SGConstValue? {
  match instr {
    I32Const(v) => Some(SGConstValue::SGI32(v))
    I64Const(v) => Some(SGConstValue::SGI64(v))
    F32Const(v) => Some(SGConstValue::SGF32(v))
    F64Const(v) => Some(SGConstValue::SGF64(v))
    RefNull(ht) => Some(SGConstValue::SGRefNull(ht))
    RefFunc(idx) => Some(SGConstValue::SGRefFunc(idx))
    _ => None
  }
}

///|
fn sg_const_value_from_tinstr(instr : TInstr) -> SGConstValue? {
  match instr.kind {
    TInstrKind::TI32Const(v) => Some(SGConstValue::SGI32(v))
    TInstrKind::TI64Const(v) => Some(SGConstValue::SGI64(v))
    TInstrKind::TF32Const(v) => Some(SGConstValue::SGF32(v))
    TInstrKind::TF64Const(v) => Some(SGConstValue::SGF64(v))
    TInstrKind::TRefNull(ht) => Some(SGConstValue::SGRefNull(ht))
    TInstrKind::TRefFunc(idx) => Some(SGConstValue::SGRefFunc(idx))
    _ => None
  }
}

///|
fn sg_const_value_from_expr(expr : Expr) -> SGConstValue? {
  match expr {
    Expr([instr]) => sg_const_value_from_instruction(instr)
    _ => None
  }
}

///|
fn sg_const_value_to_instruction(value : SGConstValue) -> Instruction {
  match value {
    SGI32(v) => Instruction::i32_const(v)
    SGI64(v) => Instruction::i64_const(v)
    SGF32(v) => Instruction::f32_const(v)
    SGF64(v) => Instruction::f64_const(v)
    SGRefNull(ht) => Instruction::ref_null(ht)
    SGRefFunc(idx) => Instruction::ref_func(idx)
  }
}

///|
fn sg_const_value_to_tinstr(value : SGConstValue) -> TInstr {
  match value {
    SGI32(v) => TInstr::i32_const(v)
    SGI64(v) => TInstr::i64_const(v)
    SGF32(v) => TInstr::f32_const(v)
    SGF64(v) => TInstr::f64_const(v)
    SGRefNull(ht) => TInstr::ref_null(ht)
    SGRefFunc(idx) => TInstr::ref_func(idx)
  }
}

///|
fn sg_instr_is_call(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TCall(_, _)
    | TInstrKind::TCallIndirect(_, _, _, _)
    | TInstrKind::TCallRef(_, _, _)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _) => true
    _ => false
  }
}

///|
fn sg_instr_has_non_global_unremovable_side_effects(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TLocalSet(_, _) | TInstrKind::TLocalTee(_, _) => true
    TInstrKind::TLoad(_, _, _) | TInstrKind::TStore(_, _, _, _) => true
    TInstrKind::TMemoryGrow(_, _)
    | TInstrKind::TMemorySize(_)
    | TInstrKind::TMemoryCopy(_, _, _, _, _)
    | TInstrKind::TMemoryFill(_, _, _, _)
    | TInstrKind::TMemoryInit(_, _, _, _, _)
    | TInstrKind::TDataDrop(_)
    | TInstrKind::TTableGet(_, _)
    | TInstrKind::TTableSet(_, _, _)
    | TInstrKind::TTableGrow(_, _, _)
    | TInstrKind::TTableSize(_)
    | TInstrKind::TTableFill(_, _, _, _)
    | TInstrKind::TTableCopy(_, _, _, _, _)
    | TInstrKind::TTableInit(_, _, _, _, _)
    | TInstrKind::TElemDrop(_) => true
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TBrOnNull(_, _, _)
    | TInstrKind::TBrOnNonNull(_, _, _)
    | TInstrKind::TBrOnCast(_, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(_, _, _, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_) => true
    TInstrKind::TUnreachable
    | TInstrKind::TRefAsNonNull(_)
    | TInstrKind::TRefCast(_, _, _) => true
    TInstrKind::TStructGet(_, _, _)
    | TInstrKind::TStructGetS(_, _, _)
    | TInstrKind::TStructGetU(_, _, _)
    | TInstrKind::TStructSet(_, _, _, _)
    | TInstrKind::TStructNew(_, _)
    | TInstrKind::TStructNewDefault(_)
    | TInstrKind::TArrayNew(_, _, _)
    | TInstrKind::TArrayNewDefault(_, _)
    | TInstrKind::TArrayNewFixed(_, _)
    | TInstrKind::TArrayNewData(_, _, _, _)
    | TInstrKind::TArrayNewElem(_, _, _, _)
    | TInstrKind::TArrayGet(_, _, _)
    | TInstrKind::TArrayGetS(_, _, _)
    | TInstrKind::TArrayGetU(_, _, _)
    | TInstrKind::TArraySet(_, _, _, _)
    | TInstrKind::TArrayLen(_)
    | TInstrKind::TArrayFill(_, _, _, _, _)
    | TInstrKind::TArrayCopy(_, _, _, _, _, _, _)
    | TInstrKind::TArrayInitData(_, _, _, _, _, _)
    | TInstrKind::TArrayInitElem(_, _, _, _, _, _)
    | TInstrKind::TI31GetS(_)
    | TInstrKind::TI31GetU(_)
    | TInstrKind::TRefI31(_) => true
    TInstrKind::TBinary(op, _, _) =>
      match op {
        I32DivSOp
        | I32DivUOp
        | I32RemSOp
        | I32RemUOp
        | I64DivSOp
        | I64DivUOp
        | I64RemSOp
        | I64RemUOp => true
        _ => false
      }
    TInstrKind::TUnary(op, _) =>
      match op {
        I32TruncF32SOp
        | I32TruncF32UOp
        | I32TruncF64SOp
        | I32TruncF64UOp
        | I64TruncF32SOp
        | I64TruncF32UOp
        | I64TruncF64SOp
        | I64TruncF64UOp => true
        _ => false
      }
    _ => false
  }
}

///|
priv struct SGWriteOnlyBodyScan {
  mut failed : Bool
  mut written : GlobalIdx?
}

///|
fn SGWriteOnlyBodyScan::new() -> SGWriteOnlyBodyScan {
  { failed: false, written: None }
}

///|
fn SGWriteOnlyBodyScan::note_write(
  self : SGWriteOnlyBodyScan,
  idx : GlobalIdx,
) -> Unit {
  match self.written {
    Some(prev) if prev != idx => self.failed = true
    None => self.written = Some(idx)
    _ => ()
  }
}

///|
priv struct SGConditionScan {
  target : GlobalIdx
  mut reads_target : Bool
  mut failed : Bool
}

///|
fn SGConditionScan::new(target : GlobalIdx) -> SGConditionScan {
  { target, reads_target: false, failed: false }
}

///|
fn sg_scan_write_only_body(body : TExpr, scan : SGWriteOnlyBodyScan) -> Unit {
  for instr in body.instrs {
    if scan.failed {
      break
    }
    sg_scan_write_only_body_instr(instr, scan)
  }
}

///|
fn sg_scan_write_only_body_instr(
  instr : TInstr,
  scan : SGWriteOnlyBodyScan,
) -> Unit {
  if scan.failed {
    return
  }
  match instr.kind {
    TInstrKind::TGlobalGet(_) => scan.failed = true
    TInstrKind::TGlobalSet(idx, value) => {
      scan.note_write(idx)
      if !scan.failed {
        sg_scan_write_only_body_instr(value, scan)
      }
    }
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => sg_scan_write_only_body(body, scan)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      sg_scan_write_only_body_instr(cond, scan)
      if scan.failed {
        return
      }
      sg_scan_write_only_body(then_body, scan)
      match else_body {
        Some(other) => sg_scan_write_only_body(other, scan)
        None => ()
      }
    }
    _ =>
      if sg_instr_is_call(instr) ||
        sg_instr_has_non_global_unremovable_side_effects(instr) {
        scan.failed = true
      } else {
        for child in eval_children(instr) {
          sg_scan_write_only_body_instr(child, scan)
          if scan.failed {
            break
          }
        }
      }
  }
}

///|
fn sg_scan_condition_instr(instr : TInstr, scan : SGConditionScan) -> Unit {
  if scan.failed {
    return
  }
  match instr.kind {
    TInstrKind::TGlobalGet(idx) =>
      if idx == scan.target {
        scan.reads_target = true
      }
    TInstrKind::TGlobalSet(_, _) => scan.failed = true
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) =>
      for item in body.instrs {
        sg_scan_condition_instr(item, scan)
        if scan.failed {
          break
        }
      }
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      sg_scan_condition_instr(cond, scan)
      if scan.failed {
        return
      }
      for item in then_body.instrs {
        sg_scan_condition_instr(item, scan)
        if scan.failed {
          break
        }
      }
      match else_body {
        Some(other) =>
          if !scan.failed {
            for item in other.instrs {
              sg_scan_condition_instr(item, scan)
              if scan.failed {
                break
              }
            }
          }
        None => ()
      }
    }
    _ =>
      if sg_instr_is_call(instr) ||
        sg_instr_has_non_global_unremovable_side_effects(instr) {
        scan.failed = true
      } else {
        for child in eval_children(instr) {
          sg_scan_condition_instr(child, scan)
          if scan.failed {
            break
          }
        }
      }
  }
}

///|
fn sg_reads_global_only_to_write_it(
  condition : TInstr,
  code : TExpr,
) -> GlobalIdx? {
  let body_scan = SGWriteOnlyBodyScan::new()
  sg_scan_write_only_body(code, body_scan)
  let written = match body_scan.written {
    Some(idx) if !body_scan.failed => idx
    _ => return None
  }

  let cond_scan = SGConditionScan::new(written)
  sg_scan_condition_instr(condition, cond_scan)
  if cond_scan.failed || !cond_scan.reads_target {
    return None
  }
  Some(written)
}

///|
fn sg_analyze(mod : Module) -> Result[(SGInfo, Module, Bool), String] {
  let imported_globals = sg_count_imported_globals(mod)
  let defined_globals = match mod.global_sec {
    Some(GlobalSec(globals)) => globals
    None => []
  }
  let total_globals = imported_globals + defined_globals.length()
  let info = SGInfo::new(total_globals)

  for i = 0; i < imported_globals; i = i + 1 {
    info.imported[i] = true
  }
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for ex in exports {
        match ex {
          Export(_, GlobalExternIdx(idx)) => {
            let raw = sg_globalidx_to_int(idx)
            if raw >= 0 && raw < total_globals {
              info.exported[raw] = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }

  let scanner = ModuleTransformer::new()
    .on_tinstruction_evt(fn(self, _, instr) {
      match instr.kind {
        TInstrKind::TGlobalSet(idx, value) => {
          let raw = sg_globalidx_to_int(idx)
          if raw >= 0 && raw < total_globals {
            info.written[raw] = info.written[raw] + 1
            if info.imported[raw] {
              info.non_init_written[raw] = true
            } else {
              match
                sg_defined_index(
                  imported_globals,
                  defined_globals.length(),
                  idx,
                ) {
                Some(def_idx) => {
                  let Global(_, init) = defined_globals[def_idx]
                  match
                    (
                      sg_const_value_from_tinstr(value),
                      sg_const_value_from_expr(init),
                    ) {
                    (Some(written_v), Some(init_v)) =>
                      if written_v != init_v {
                        info.non_init_written[raw] = true
                      }
                    _ => info.non_init_written[raw] = true
                  }
                }
                None => info.non_init_written[raw] = true
              }
            }
          }
        }
        TInstrKind::TGlobalGet(idx) => {
          let raw = sg_globalidx_to_int(idx)
          if raw >= 0 && raw < total_globals {
            info.read[raw] = info.read[raw] + 1
          }
        }
        TInstrKind::TIf(_, cond, then_body, None) =>
          match sg_reads_global_only_to_write_it(cond, then_body) {
            Some(idx) => {
              let raw = sg_globalidx_to_int(idx)
              if raw >= 0 && raw < total_globals {
                info.read_only_to_write[raw] = info.read_only_to_write[raw] + 1
              }
            }
            None => ()
          }
        _ => ()
      }
      self.walk_tinstruction_default((), instr)
    })
    .on_instruction_evt(fn(self, _, instr) {
      match instr {
        GlobalGet(idx) => {
          let raw = sg_globalidx_to_int(idx)
          if raw >= 0 && raw < total_globals {
            info.read[raw] = info.read[raw] + 1
          }
        }
        GlobalSet(idx) => {
          let raw = sg_globalidx_to_int(idx)
          if raw >= 0 && raw < total_globals {
            info.written[raw] = info.written[raw] + 1
            info.non_init_written[raw] = true
          }
        }
        _ => ()
      }
      self.walk_instruction_default((), instr)
    })
    .on_func_evt(fn(self, _, func) {
      match func {
        TFunc(_, { instrs, .. }) if instrs.length() == 2 =>
          match instrs[0].kind {
            TInstrKind::TIf(
              _,
              cond,
              { instrs: [{ kind: TInstrKind::TReturn(values), .. }], .. },
              None
            ) if values.length() == 0 =>
              match
                sg_reads_global_only_to_write_it(cond, TExpr::new([instrs[1]])) {
                Some(idx) => {
                  let raw = sg_globalidx_to_int(idx)
                  if raw >= 0 && raw < total_globals {
                    info.read_only_to_write[raw] = info.read_only_to_write[raw] +
                      1
                  }
                }
                None => ()
              }
            _ => ()
          }
        _ => ()
      }
      self.walk_func_default((), func)
    })
  match scanner.walk_module((), mod) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  let mut changed = false
  let next_mod = match mod.global_sec {
    Some(GlobalSec(globals)) => {
      let rewritten = globals.copy()
      for i = 0; i < rewritten.length(); i = i + 1 {
        let abs = imported_globals + i
        let Global(GlobalType(vt, is_mut), init) = rewritten[i]
        if is_mut &&
          !info.imported[abs] &&
          !info.exported[abs] &&
          info.written[abs] == 0 {
          rewritten[i] = Global::new(GlobalType::new(vt, false), init)
          changed = true
        }
      }
      if changed {
        mod.with_global_sec(GlobalSec::new(rewritten))
      } else {
        mod
      }
    }
    None => mod
  }

  Ok((info, next_mod, changed))
}

///|
fn sg_init_single_instruction(
  globals : Array[Global],
  imported_globals : Int,
  idx : GlobalIdx,
) -> Instruction? {
  match sg_defined_index(imported_globals, globals.length(), idx) {
    Some(def_idx) =>
      match globals[def_idx] {
        Global(_, Expr([instr])) => Some(instr)
        _ => None
      }
    None => None
  }
}

///|
fn sg_fold_single_uses(mod : Module, info : SGInfo) -> (Module, Bool) {
  let globals = match mod.global_sec {
    Some(GlobalSec(globals)) => globals
    None => return (mod, false)
  }
  let imported_globals = sg_count_imported_globals(mod)
  let rewritten = globals.copy()
  let mut changed = false
  for i = 0; i < rewritten.length(); i = i + 1 {
    let Global(gt, Expr(instrs)) = rewritten[i]
    let next_instrs : Array[Instruction] = []
    let mut local_changed = false
    for instr in instrs {
      match instr {
        GlobalGet(idx) => {
          let raw = sg_globalidx_to_int(idx)
          if raw >= 0 &&
            raw < info.read.length() &&
            info.written[raw] == 0 &&
            info.read[raw] == 1 &&
            !info.exported[raw] {
            match sg_init_single_instruction(globals, imported_globals, idx) {
              Some(rep) => {
                next_instrs.push(rep)
                local_changed = true
              }
              None => next_instrs.push(instr)
            }
          } else {
            next_instrs.push(instr)
          }
        }
        _ => next_instrs.push(instr)
      }
    }
    if local_changed {
      rewritten[i] = Global::new(gt, Expr::new(next_instrs))
      changed = true
    }
  }
  if changed {
    (mod.with_global_sec(GlobalSec::new(rewritten)), true)
  } else {
    (mod, false)
  }
}

///|
fn sg_remove_unneeded_writes(
  mod : Module,
  info : SGInfo,
) -> Result[(Module, Bool, Bool), String] {
  let globals = match mod.global_sec {
    Some(GlobalSec(globals)) => globals
    None => return Ok((mod, false, false))
  }
  let imported_globals = sg_count_imported_globals(mod)
  let to_remove : Set[GlobalIdx] = Set::new()
  let rewritten_globals = globals.copy()
  let mut changed_globals = false
  let mut more = false

  for i = 0; i < rewritten_globals.length(); i = i + 1 {
    let abs = imported_globals + i
    if abs < 0 || abs >= info.written.length() {
      continue
    }
    if info.written[abs] == 0 {
      continue
    }
    if info.imported[abs] || info.exported[abs] {
      continue
    }
    let only_read_only = info.read[abs] == info.read_only_to_write[abs]
    if info.read[abs] == 0 || !info.non_init_written[abs] || only_read_only {
      to_remove.add(sg_globalidx_from_int(abs))
      if only_read_only {
        more = true
      }
      let Global(GlobalType(vt, is_mut), init) = rewritten_globals[i]
      if is_mut {
        rewritten_globals[i] = Global::new(GlobalType::new(vt, false), init)
        changed_globals = true
      }
    }
  }

  let mut next_mod = if changed_globals {
    mod.with_global_sec(GlobalSec::new(rewritten_globals))
  } else {
    mod
  }
  if to_remove.is_empty() {
    return Ok((next_mod, changed_globals, more))
  }

  let remover = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    instr,
  ) {
    match instr.kind {
      TInstrKind::TGlobalSet(idx, value) =>
        if to_remove.contains(idx) {
          change((), TInstr::drop(value))
        } else {
          self.walk_tinstruction_default((), instr)
        }
      _ => self.walk_tinstruction_default((), instr)
    }
  })
  match remover.walk_module((), next_mod) {
    Ok(Some((_, out))) => {
      next_mod = out
      Ok((next_mod, true, more))
    }
    Ok(None) => Ok((next_mod, changed_globals, more))
    Err(e) => Err(e)
  }
}

///|
fn sg_global_is_mutable(
  global_types : Array[GlobalType],
  idx : GlobalIdx,
) -> Bool {
  let raw = sg_globalidx_to_int(idx)
  if raw < 0 || raw >= global_types.length() {
    return true
  }
  let GlobalType(_, is_mut) = global_types[raw]
  is_mut
}

///|
fn sg_same_global_val_type(
  global_types : Array[GlobalType],
  a : GlobalIdx,
  b : GlobalIdx,
) -> Bool {
  let ia = sg_globalidx_to_int(a)
  let ib = sg_globalidx_to_int(b)
  if ia < 0 ||
    ib < 0 ||
    ia >= global_types.length() ||
    ib >= global_types.length() {
    return false
  }
  let GlobalType(va, _) = global_types[ia]
  let GlobalType(vb, _) = global_types[ib]
  va == vb
}

///|
fn sg_prefer_earlier_imports(mod : Module) -> Result[(Module, Bool), String] {
  let globals = match mod.global_sec {
    Some(GlobalSec(globals)) => globals
    None => return Ok((mod, false))
  }
  let imported_globals = sg_count_imported_globals(mod)
  let global_types = sg_collect_global_types(mod)
  let copied_parent_map : Map[GlobalIdx, GlobalIdx] = Map::new()

  for i = 0; i < globals.length(); i = i + 1 {
    let child = sg_globalidx_from_int(imported_globals + i)
    let Global(GlobalType(_, is_mut), init) = globals[i]
    if is_mut {
      continue
    }
    match init {
      Expr([GlobalGet(parent)]) =>
        if !sg_global_is_mutable(global_types, parent) {
          copied_parent_map[child] = parent
        }
      _ => ()
    }
  }
  if copied_parent_map.is_empty() {
    return Ok((mod, false))
  }

  let keys : Array[GlobalIdx] = []
  for entry in copied_parent_map {
    let (child, _) = entry
    keys.push(child)
  }
  for child in keys {
    let mut curr = copied_parent_map.get(child).unwrap_or(child)
    while true {
      match copied_parent_map.get(curr) {
        Some(next) => curr = next
        None => break
      }
    }
    copied_parent_map[child] = curr
  }

  let rewriter = ModuleTransformer::new()
    .on_tinstruction_evt(fn(self, _, instr) {
      match instr.kind {
        TInstrKind::TGlobalGet(idx) =>
          match copied_parent_map.get(idx) {
            Some(parent) =>
              if sg_same_global_val_type(global_types, idx, parent) {
                change((), TInstr::global_get(parent))
              } else {
                unchanged()
              }
            None => unchanged()
          }
        _ => self.walk_tinstruction_default((), instr)
      }
    })
    .on_instruction_evt(fn(self, _, instr) {
      match instr {
        GlobalGet(idx) =>
          match copied_parent_map.get(idx) {
            Some(parent) =>
              if sg_same_global_val_type(global_types, idx, parent) {
                change((), Instruction::global_get(parent))
              } else {
                unchanged()
              }
            None => unchanged()
          }
        _ => self.walk_instruction_default((), instr)
      }
    })
  match rewriter.walk_module((), mod) {
    Ok(Some((_, out))) => Ok((out, true))
    Ok(None) => Ok((mod, false))
    Err(e) => Err(e)
  }
}

///|
fn sg_apply_const_globals_in_expr(
  expr : Expr,
  constants : SGConstSlots,
) -> (Expr, Bool) {
  let Expr(instrs) = expr
  let out : Array[Instruction] = []
  let mut changed = false
  for instr in instrs {
    match instr {
      GlobalGet(idx) =>
        match constants.get(idx) {
          Some(value) => {
            out.push(sg_const_value_to_instruction(value))
            changed = true
          }
          None => out.push(instr)
        }
      _ => out.push(instr)
    }
  }
  (Expr::new(out), changed)
}

///|
fn sg_propagate_constants_to_globals(mod : Module) -> (Module, Bool) {
  let imported_globals = sg_count_imported_globals(mod)
  let defined_globals = match mod.global_sec {
    Some(GlobalSec(globals)) => globals.length()
    None => 0
  }
  let mut changed = false
  let mut out_mod = mod
  let constants = SGConstSlots::new(imported_globals + defined_globals)

  match out_mod.global_sec {
    Some(GlobalSec(globals)) => {
      let rewritten = globals.copy()
      for i = 0; i < rewritten.length(); i = i + 1 {
        let idx = sg_globalidx_from_int(imported_globals + i)
        let Global(gt, init) = rewritten[i]
        let (next_init, init_changed) = sg_apply_const_globals_in_expr(
          init, constants,
        )
        if init_changed {
          changed = true
        }
        rewritten[i] = Global::new(gt, next_init)
        match sg_const_value_from_expr(next_init) {
          Some(value) => constants.set(idx, value)
          None => ()
        }
      }
      out_mod = out_mod.with_global_sec(GlobalSec::new(rewritten))
    }
    None => ()
  }

  match out_mod.elem_sec {
    Some(ElemSec(elems)) => {
      let rewritten : Array[Elem] = []
      let mut local_changed = false
      for elem in elems {
        match elem {
          Elem(Active(table_idx, offset), kind) => {
            let (next_offset, offset_changed) = sg_apply_const_globals_in_expr(
              offset, constants,
            )
            if offset_changed {
              local_changed = true
            }
            rewritten.push(
              Elem::new(ElemMode::active(table_idx, next_offset), kind),
            )
          }
          _ => rewritten.push(elem)
        }
      }
      if local_changed {
        changed = true
        out_mod = out_mod.with_elem_sec(ElemSec::new(rewritten))
      }
    }
    None => ()
  }

  match out_mod.data_sec {
    Some(DataSec(datas)) => {
      let rewritten : Array[Data] = []
      let mut local_changed = false
      for data in datas {
        match data {
          Data(Active(mem_idx, offset), bytes) => {
            let (next_offset, offset_changed) = sg_apply_const_globals_in_expr(
              offset, constants,
            )
            if offset_changed {
              local_changed = true
            }
            rewritten.push(
              Data::new(DataMode::active(mem_idx, next_offset), bytes),
            )
          }
          _ => rewritten.push(data)
        }
      }
      if local_changed {
        changed = true
        out_mod = out_mod.with_data_sec(DataSec::new(rewritten))
      }
    }
    None => ()
  }

  (out_mod, changed)
}

///|
fn sg_replace_gets_in_tinstr(
  instr : TInstr,
  trace_constants : SGConstSlots,
  constant_globals : SGConstSlots,
  stats : SGFunctionTraceStats,
) -> (TInstr, SGRewriteSummary) {
  stats.visited_instrs += 1
  match instr.kind {
    TInstrKind::TGlobalGet(idx) =>
      match constant_globals.get(idx) {
        Some(value) => {
          stats.replaced_gets += 1
          (sg_const_value_to_tinstr(value), sg_rewrite_summary(changed=true))
        }
        None =>
          match trace_constants.get(idx) {
            Some(value) => {
              stats.replaced_gets += 1
              (
                sg_const_value_to_tinstr(value),
                sg_rewrite_summary(changed=true),
              )
            }
            None => (instr, sg_rewrite_summary())
          }
      }
    TInstrKind::TBlock(bt, body) => {
      let (next_body, summary) = sg_replace_gets_in_texpr(
        body, trace_constants, constant_globals, stats,
      )
      if summary.changed {
        (TInstr::block(bt, next_body), summary)
      } else {
        (instr, summary)
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let (next_body, summary) = sg_replace_gets_in_texpr(
        body, trace_constants, constant_globals, stats,
      )
      if summary.changed {
        (TInstr::loop_(bt, next_body), summary)
      } else {
        (instr, summary)
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let (next_cond, cond_summary) = sg_replace_gets_in_tinstr(
        cond, trace_constants, constant_globals, stats,
      )
      let (next_then, then_summary) = sg_replace_gets_in_texpr(
        then_body, trace_constants, constant_globals, stats,
      )
      let (next_else, else_summary) = match else_body {
        Some(other) => {
          let (rewritten, summary) = sg_replace_gets_in_texpr(
            other, trace_constants, constant_globals, stats,
          )
          (Some(rewritten), summary)
        }
        None => (None, sg_rewrite_summary())
      }
      let summary = sg_merge_rewrite_summary(
        cond_summary,
        sg_merge_rewrite_summary(then_summary, else_summary),
      )
      (
        if summary.changed {
          TInstr::if_(bt, next_cond, next_then, next_else)
        } else {
          instr
        },
        summary,
      )
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let (next_body, summary) = sg_replace_gets_in_texpr(
        body, trace_constants, constant_globals, stats,
      )
      if summary.changed {
        (TInstr::try_table(bt, catches, next_body), summary)
      } else {
        (instr, summary)
      }
    }
    _ => {
      let children = eval_children(instr)
      if children.is_empty() {
        (
          instr,
          sg_rewrite_summary(
            has_call=sg_instr_is_call(instr),
            writes_global=instr.kind is TInstrKind::TGlobalSet(_, _),
          ),
        )
      } else {
        let rewritten_children : Array[TInstr] = []
        let mut summary = sg_rewrite_summary(
          has_call=sg_instr_is_call(instr),
          writes_global=instr.kind is TInstrKind::TGlobalSet(_, _),
        )
        for child in children {
          let (next_child, child_summary) = sg_replace_gets_in_tinstr(
            child, trace_constants, constant_globals, stats,
          )
          rewritten_children.push(next_child)
          summary = sg_merge_rewrite_summary(summary, child_summary)
        }
        if summary.changed {
          (lcs_rebuild_non_control(instr, rewritten_children), summary)
        } else {
          (instr, summary)
        }
      }
    }
  }
}

///|
fn sg_replace_gets_in_texpr(
  body : TExpr,
  trace_constants : SGConstSlots,
  constant_globals : SGConstSlots,
  stats : SGFunctionTraceStats,
) -> (TExpr, SGRewriteSummary) {
  let out : Array[TInstr] = []
  let mut summary = sg_rewrite_summary()
  for instr in body.instrs {
    let (next_instr, instr_summary) = sg_replace_gets_in_tinstr(
      instr, trace_constants, constant_globals, stats,
    )
    out.push(next_instr)
    summary = sg_merge_rewrite_summary(summary, instr_summary)
  }
  if summary.changed {
    (TExpr::new(out), summary)
  } else {
    (body, summary)
  }
}

///|
fn sg_apply_constants_in_body(
  body : TExpr,
  constant_globals : SGConstSlots,
  stats : SGFunctionTraceStats,
) -> (TExpr, Bool) {
  let curr_constants = SGConstSlots::new(constant_globals.values.length())
  let out : Array[TInstr] = []
  let mut changed = false
  for instr in body.instrs {
    if lcs_is_non_linear_boundary(instr) {
      curr_constants.clear()
      stats.boundary_resets += 1
    }
    let (rewritten, summary) = sg_replace_gets_in_tinstr(
      instr, curr_constants, constant_globals, stats,
    )
    out.push(rewritten)
    if summary.changed {
      changed = true
    }

    if lcs_is_non_linear_boundary(rewritten) {
      curr_constants.clear()
      stats.boundary_resets += 1
      continue
    }

    if summary.has_call {
      curr_constants.clear()
      stats.call_resets += 1
      continue
    }
    match rewritten.kind {
      TInstrKind::TGlobalSet(idx, value) => {
        if curr_constants.remove(idx) {
          stats.global_kills += 1
        }
        match sg_const_value_from_tinstr(value) {
          Some(constant) => {
            curr_constants.set(idx, constant)
            stats.const_sets += 1
          }
          None => ()
        }
      }
      _ =>
        if summary.writes_global {
          curr_constants.clear()
          stats.nested_write_resets += 1
        }
    }
  }
  (TExpr::new(out), changed)
}

///|
fn sg_propagate_constants_to_code(
  mod : Module,
  trace? : (String) -> Unit = sg_trace_noop,
  trace_all_funcs? : Bool = false,
) -> (Module, Bool) {
  let imported_globals = sg_count_imported_globals(mod)
  let globals = match mod.global_sec {
    Some(GlobalSec(globals)) => globals
    None => []
  }
  let constant_globals = SGConstSlots::new(imported_globals + globals.length())
  for i = 0; i < globals.length(); i = i + 1 {
    let idx = sg_globalidx_from_int(imported_globals + i)
    let Global(GlobalType(_, is_mut), init) = globals[i]
    if !is_mut {
      match sg_const_value_from_expr(init) {
        Some(value) => constant_globals.set(idx, value)
        None => ()
      }
    }
  }
  let mut changed = false
  let mut out_mod = mod
  match out_mod.code_sec {
    Some(CodeSec(funcs)) => {
      let mut seen_funcs = 0
      let rewritten : Array[Func] = []
      for func in funcs {
        seen_funcs += 1
        let ordinal = seen_funcs
        let log_func = trace_all_funcs || ordinal <= 5 || ordinal % 500 == 0
        match func {
          TFunc(locals, body) => {
            if log_func {
              trace(
                "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{body.instrs.length()}",
              )
            }
            let func_start_ms = sg_trace_now_ms()
            let stats = SGFunctionTraceStats::new(body.instrs.length())
            let (next_body, body_changed) = sg_apply_constants_in_body(
              body, constant_globals, stats,
            )
            if body_changed {
              changed = true
            }
            let elapsed_ms = sg_trace_elapsed_ms(func_start_ms)
            let log_hot_func = elapsed_ms >= 50UL ||
              stats.visited_instrs >= 10000 ||
              stats.replaced_gets >= 500
            if log_func || log_hot_func {
              trace(
                "func[\{ordinal}] done elapsed_ms=\{elapsed_ms} changed=\{body_changed} top_instrs=\{stats.top_instrs}->\{next_body.instrs.length()} visited=\{stats.visited_instrs} replaced_gets=\{stats.replaced_gets} boundary_resets=\{stats.boundary_resets} call_resets=\{stats.call_resets} global_kills=\{stats.global_kills} const_sets=\{stats.const_sets} nested_write_resets=\{stats.nested_write_resets}",
              )
            }
            rewritten.push(Func::t_func(locals, next_body))
          }
          _ => {
            if log_func {
              trace("func[\{ordinal}] skip non-typed-func")
            }
            rewritten.push(func)
          }
        }
      }
      if changed {
        out_mod = out_mod.with_code_sec(CodeSec::new(rewritten))
      }
    }
    None => ()
  }
  (out_mod, changed)
}

///|
fn sg_run_cleanup(
  mod : Module,
  trace? : (String) -> Unit = sg_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Result[(Module, Bool), String] {
  let start_profile = optimize_cleanup_cost_profile(mod)
  if optimize_should_skip_expensive_cleanup(start_profile) {
    trace(
      "cleanup:skip reason=module_size funcs=\{start_profile.func_count} top_instrs=\{start_profile.top_instr_sum}",
    )
    return Ok((mod, false))
  }

  let options = OptimizeOptions::new()
  let cleanup_ctx = IRContext::new()
  cleanup_ctx.set_mod(mod)
  trace(
    "cleanup:optimize_instructions:start funcs=\{start_profile.func_count} top_instrs=\{start_profile.top_instr_sum}",
  )
  let after_oi = match
    apply_ir_transformer_pass(
      cleanup_ctx,
      mod,
      optimize_instructions_ir_pass(
        mod,
        options,
        trace=fn(msg) { trace("cleanup:optimize_instructions:\{msg}") },
        trace_all_funcs~,
      ),
    ) {
    Ok(new_mod) => {
      let profile = optimize_cleanup_cost_profile(new_mod)
      trace(
        "cleanup:optimize_instructions:done funcs=\{profile.func_count} top_instrs=\{profile.top_instr_sum}",
      )
      new_mod
    }
    Err(e) => return Err(e)
  }

  trace("cleanup:dead_code_elimination:start")
  let after_dce = match
    apply_unit_transformer_pass(after_oi, dead_code_elimination_pass()) {
    Ok(new_mod) => {
      let profile = optimize_cleanup_cost_profile(new_mod)
      trace(
        "cleanup:dead_code_elimination:done funcs=\{profile.func_count} top_instrs=\{profile.top_instr_sum}",
      )
      new_mod
    }
    Err(e) => return Err(e)
  }

  cleanup_ctx.set_mod(after_dce)
  let code_folding_profile = optimize_cleanup_cost_profile(after_dce)
  trace(
    "cleanup:code_folding:start funcs=\{code_folding_profile.func_count} top_instrs=\{code_folding_profile.top_instr_sum}",
  )
  match
    apply_ir_transformer_pass(
      cleanup_ctx,
      after_dce,
      code_folding_ir_pass_with_trace(
        after_dce,
        trace=fn(msg) { trace("cleanup:code_folding:\{msg}") },
        trace_all_funcs~,
      ),
    ) {
    Ok(new_mod) => {
      let profile = optimize_cleanup_cost_profile(new_mod)
      trace(
        "cleanup:code_folding:done funcs=\{profile.func_count} top_instrs=\{profile.top_instr_sum}",
      )
      Ok((new_mod, new_mod != mod))
    }
    Err(e) => Err(e)
  }
}

///|
fn sg_simplify_globals_impl(
  mod : Module,
  optimize : Bool,
  trace? : (String) -> Unit = sg_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Result[(Module, Bool), String] {
  let mut curr = mod
  let mut changed = false
  let mut rerun = true
  let mut cleanup_needed = false
  let mut rounds = 0
  while rerun {
    rounds += 1
    rerun = false
    let round_start_ms = sg_trace_now_ms()

    let (info0, analyzed0, analyze_changed0) = match sg_analyze(curr) {
      Ok(res) => res
      Err(e) => return Err(e)
    }
    curr = analyzed0
    changed = changed || analyze_changed0

    let (folded, fold_changed) = sg_fold_single_uses(curr, info0)
    curr = folded
    changed = changed || fold_changed

    let mut info1 = info0
    let mut analyze_changed1 = false
    let mut reanalyzed = false
    if fold_changed {
      let (next_info, analyzed1, changed1) = match sg_analyze(curr) {
        Ok(res) => res
        Err(e) => return Err(e)
      }
      info1 = next_info
      curr = analyzed1
      analyze_changed1 = changed1
      changed = changed || analyze_changed1
      reanalyzed = true
    }

    let (removed, remove_changed, need_more) = match
      sg_remove_unneeded_writes(curr, info1) {
      Ok(res) => res
      Err(e) => return Err(e)
    }
    curr = removed
    changed = changed || remove_changed
    if need_more {
      rerun = true
    }

    let (preferred, prefer_changed) = match sg_prefer_earlier_imports(curr) {
      Ok(res) => res
      Err(e) => return Err(e)
    }
    curr = preferred
    changed = changed || prefer_changed

    let (globals_propagated, globals_changed) = sg_propagate_constants_to_globals(
      curr,
    )
    curr = globals_propagated
    changed = changed || globals_changed

    let (code_propagated, code_changed) = sg_propagate_constants_to_code(
      curr,
      trace=fn(msg) { trace("propagate_code:\{msg}") },
      trace_all_funcs~,
    )
    curr = code_propagated
    changed = changed || code_changed
    cleanup_needed = cleanup_needed || code_changed
    trace(
      "round[\{rounds}] done elapsed_ms=\{sg_trace_elapsed_ms(round_start_ms)} analyze_changed=\{analyze_changed0} fold_changed=\{fold_changed} reanalyzed=\{reanalyzed} reanalyze_changed=\{analyze_changed1} remove_changed=\{remove_changed} need_more=\{need_more} prefer_changed=\{prefer_changed} globals_changed=\{globals_changed} code_changed=\{code_changed}",
    )
  }

  if optimize && cleanup_needed {
    let cleanup_start_ms = sg_trace_now_ms()
    trace("cleanup:start")
    match sg_run_cleanup(curr, trace~, trace_all_funcs~) {
      Ok((next, cleanup_changed)) => {
        curr = next
        changed = changed || cleanup_changed
        trace(
          "cleanup:done elapsed_ms=\{sg_trace_elapsed_ms(cleanup_start_ms)} changed=\{cleanup_changed}",
        )
      }
      Err(e) => {
        trace(
          "cleanup:error elapsed_ms=\{sg_trace_elapsed_ms(cleanup_start_ms)} \{e}",
        )
        return Err(e)
      }
    }
  }

  Ok((curr, changed))
}

///|
fn simplify_globals_ir_pass(
  _mod : Module,
  optimize : Bool,
  trace? : (String) -> Unit = sg_trace_noop,
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_module_evt(fn(_, ctx, curr) {
    match sg_simplify_globals_impl(curr, optimize, trace~, trace_all_funcs~) {
      Ok((next, _)) =>
        if next == curr {
          unchanged()
        } else {
          change(ctx, next)
        }
      Err(e) => Err(e)
    }
  })
}

///|
fn propagate_globals_globally_ir_pass(
  _mod : Module,
) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_module_evt(fn(_, ctx, curr) {
    let (next, _) = sg_propagate_constants_to_globals(curr)
    if next == curr {
      unchanged()
    } else {
      change(ctx, next)
    }
  })
}

///|
fn sg_run_simplify_globals(mod : Module, optimize : Bool) -> Module {
  let pass = simplify_globals_ir_pass(mod, optimize)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("simplify_globals pass failed: \{e}")
  }
}

///|
fn sg_run_propagate_globals_globally(mod : Module) -> Module {
  let pass = propagate_globals_globally_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("propagate_globals_globally pass failed: \{e}")
  }
}

///|
fn sg_count_tinstr(body : TExpr, pred : (TInstr) -> Bool) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    if pred(instr) {
      count += 1
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
test "simplify_globals trace reports per-function propagation lifecycle" {
  let trace_logs : Array[String] = []
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::i32_const(I32(5))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([TInstr::drop(TInstr::global_get(GlobalIdx::new(0)))]),
        ),
      ]),
    )
  let pass = simplify_globals_ir_pass(
    mod,
    false,
    trace=fn(msg) { trace_logs.push(msg) },
    trace_all_funcs=true,
  )
  match pass.walk_module(IRContext::new(), mod) {
    Ok(_) => ()
    Err(e) => fail("unexpected simplify_globals trace error: \{e}")
  }
  let mut saw_func_start = false
  let mut saw_func_done = false
  let mut saw_round_done = false
  for msg in trace_logs {
    if msg.contains("propagate_code:func[1] start") {
      saw_func_start = true
    }
    if msg.contains("propagate_code:func[1] done") {
      saw_func_done = true
    }
    if msg.contains("round[1] done") {
      saw_round_done = true
    }
  }
  assert_true(saw_func_start)
  assert_true(saw_func_done)
  assert_true(saw_round_done)
}

///|
test "simplify_globals optimizing cleanup traces direct cleanup stages" {
  let trace_logs : Array[String] = []
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), true),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(7))),
            TInstr::drop(TInstr::global_get(GlobalIdx::new(0))),
          ]),
        ),
      ]),
    )
  let pass = simplify_globals_ir_pass(
    mod,
    true,
    trace=fn(msg) { trace_logs.push(msg) },
    trace_all_funcs=true,
  )
  match pass.walk_module(IRContext::new(), mod) {
    Ok(_) => ()
    Err(e) => fail("unexpected simplify_globals optimizing trace error: \{e}")
  }
  let mut saw_cleanup_start = false
  let mut saw_optimize_instructions = false
  let mut saw_cleanup_done = false
  for msg in trace_logs {
    if msg.contains("cleanup:start") {
      saw_cleanup_start = true
    }
    if msg.contains("cleanup:optimize_instructions:start") {
      saw_optimize_instructions = true
    }
    if msg.contains("cleanup:done") {
      saw_cleanup_done = true
    }
  }
  assert_true(saw_cleanup_start)
  assert_true(saw_optimize_instructions)
  assert_true(saw_cleanup_done)
}

///|
test "simplify_globals optimizing cleanup skips expensive modules" {
  let funcs : Array[Func] = []
  for i = 0; i < 1200; i = i + 1 {
    funcs.push(
      Func::t_func(
        [],
        TExpr::new([TInstr::drop(TInstr::global_get(GlobalIdx::new(0)))]),
      ),
    )
  }
  let trace_logs : Array[String] = []
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::i32_const(I32(5))]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new(funcs))
  let pass = simplify_globals_ir_pass(mod, true, trace=fn(msg) {
    trace_logs.push(msg)
  })
  match pass.walk_module(IRContext::new(), mod) {
    Ok(_) => ()
    Err(e) => fail("unexpected simplify_globals cleanup skip trace error: \{e}")
  }
  let mut saw_skip = false
  let mut saw_done = false
  for msg in trace_logs {
    if msg.contains("cleanup:skip reason=module_size") {
      saw_skip = true
    }
    if msg.contains("cleanup:done") {
      saw_done = true
    }
  }
  assert_true(saw_skip)
  assert_true(saw_done)
}

///|
test "simplify_globals removes unread global.set writes and makes global immutable" {
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), true),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(9))),
          ]),
        ),
      ]),
    )
  let out = sg_run_simplify_globals(mod, false)
  match out.global_sec {
    Some(GlobalSec([Global(GlobalType(_, is_mut), _)])) => assert_false(is_mut)
    _ => fail("expected one rewritten global")
  }
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TI32Const(I32(v)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => assert_eq(v, 9)
    _ => fail("expected global.set to be rewritten into drop(value)")
  }
}

///|
test "simplify_globals propagates immutable constant globals into code and copied globals" {
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::i32_const(I32(5))]),
        ),
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::global_get(GlobalIdx::new(0))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([TInstr::drop(TInstr::global_get(GlobalIdx::new(1)))]),
        ),
      ]),
    )
  let out = sg_run_simplify_globals(mod, false)
  match out.global_sec {
    Some(GlobalSec([_, Global(_, Expr([I32Const(I32(v))]))])) => assert_eq(v, 5)
    _ => fail("expected copied immutable global to become i32.const 5")
  }
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TI32Const(I32(v)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => assert_eq(v, 5)
    _ => fail("expected global.get of copied immutable global to become const")
  }
}

///|
test "simplify_globals propagates linear known value from preceding global.set" {
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), true),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(7))),
            TInstr::drop(TInstr::global_get(GlobalIdx::new(0))),
          ]),
        ),
      ]),
    )
  let out = sg_run_simplify_globals(mod, false)
  match out.code_sec {
    Some(CodeSec([TFunc(_, rewritten)])) => {
      assert_eq(
        sg_count_tinstr(rewritten, fn(i) {
          match i.kind {
            TInstrKind::TGlobalGet(GlobalIdx(raw)) => raw == 0U
            _ => false
          }
        }),
        0,
      )
      assert_true(
        sg_count_tinstr(rewritten, fn(i) {
          i.kind
          is TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(7)), .. })
        }) >
        0,
      )
    }
    _ => fail("expected rewritten body with propagated global value")
  }
}

///|
test "simplify_globals removes writes in read-only-to-write if pattern" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::global_get(GlobalIdx::new(0)),
      TExpr::new([
        TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(1))),
      ]),
      None,
    ),
  ])
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), true),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = sg_run_simplify_globals(mod, false)
  match out.code_sec {
    Some(CodeSec([TFunc(_, rewritten)])) =>
      assert_eq(
        sg_count_tinstr(rewritten, fn(i) {
          i.kind is TInstrKind::TGlobalSet(_, _)
        }),
        0,
      )
    _ => fail("expected rewritten function body")
  }
}

///|
test "propagate_globals_globally applies constants to global and data offsets" {
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::i32_const(I32(3))]),
        ),
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::global_get(GlobalIdx::new(0))]),
        ),
      ]),
    )
    .with_data_sec(
      DataSec::new([
        Data::new(
          DataMode::active(
            MemIdx::new(0),
            Expr::new([Instruction::global_get(GlobalIdx::new(1))]),
          ),
          b"\x01\x02",
        ),
      ]),
    )
  let out = sg_run_propagate_globals_globally(mod)
  match out.global_sec {
    Some(GlobalSec([_, Global(_, Expr([I32Const(I32(v))]))])) => assert_eq(v, 3)
    _ => fail("expected propagated i32.const in second global init")
  }
  match out.data_sec {
    Some(DataSec([Data(Active(_, Expr([I32Const(I32(v))])), _)])) =>
      assert_eq(v, 3)
    _ => fail("expected propagated i32.const data offset")
  }
}
