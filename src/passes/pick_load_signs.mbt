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
const PLS_TRACE_PROGRESS_INTERVAL : Int = 4096

///|
const PLS_TRACE_PROGRESS_INTERVAL_MS : UInt64 = 250UL

///|
priv struct PLSUsage {
  mut signed_usages : Int
  mut signed_bits : Int
  mut unsigned_usages : Int
  mut unsigned_bits : Int
  mut total_usages : Int
}

///|
fn PLSUsage::new() -> PLSUsage {
  {
    signed_usages: 0,
    signed_bits: 0,
    unsigned_usages: 0,
    unsigned_bits: 0,
    total_usages: 0,
  }
}

///|
priv struct PLSCandidateLoad {
  local_idx : Int
  load_bits : Int
  current_signed : Bool
}

///|
priv struct PLSAnalysis {
  usage_by_local : Map[Int, PLSUsage]
  candidates : Array[PLSCandidateLoad]
}

///|
fn pls_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn pls_trace_should_log_func(ordinal : Int, trace_all_funcs : Bool) -> Bool {
  trace_all_funcs || ordinal <= 5 || ordinal % 250 == 0
}

///|
fn pls_instr_kind_name(instr : TInstr) -> String {
  match instr.kind {
    TInstrKind::TLoad(_, _, _) => "load"
    TInstrKind::TLocalGet(_) => "local.get"
    TInstrKind::TLocalSet(_, _) => "local.set"
    TInstrKind::TLocalTee(_, _) => "local.tee"
    TInstrKind::TUnary(_, _) => "unary"
    TInstrKind::TBinary(_, _, _) => "binary"
    TInstrKind::TBlock(_, _) => "block"
    TInstrKind::TLoop(_, _) => "loop"
    TInstrKind::TIf(_, _, _, _) => "if"
    TInstrKind::TDrop(_) => "drop"
    _ => "other"
  }
}

///|
fn pls_trace_maybe_progress(
  log_func : Bool,
  trace : (String) -> Unit,
  ordinal : Int,
  phase : String,
  func_start_ms : UInt64,
  phase_start_ms : UInt64,
  last_progress_ms : Ref[UInt64],
  instr_visits : Int,
  local_gets : Int,
  candidates : Int,
  rewrites : Int,
  curr : TInstr,
) -> Unit {
  if !log_func {
    return
  }
  let now_ms = sl_trace_now_ms()
  let should_trace_progress = (instr_visits <= 1024 && instr_visits % 256 == 0) ||
    instr_visits % PLS_TRACE_PROGRESS_INTERVAL == 0 ||
    now_ms >= last_progress_ms.val + PLS_TRACE_PROGRESS_INTERVAL_MS
  if should_trace_progress {
    last_progress_ms.val = now_ms
    trace(
      "func[\{ordinal}] phase=\{phase} progress elapsed_ms=\{sl_trace_elapsed_ms(func_start_ms)} phase_ms=\{sl_trace_elapsed_ms(phase_start_ms)} instrs=\{instr_visits} local_gets=\{local_gets} candidates=\{candidates} rewrites=\{rewrites} current=\{pls_instr_kind_name(curr)}",
    )
  }
}

///|
fn pls_local_idx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn pls_get_usage(usages : Map[Int, PLSUsage], local_idx : Int) -> PLSUsage {
  usages.get(local_idx).unwrap_or(PLSUsage::new())
}

///|
fn pls_record_signed_usage(
  usages : Map[Int, PLSUsage],
  local_idx : Int,
  bits : Int,
) -> Unit {
  let usage = pls_get_usage(usages, local_idx)
  if usage.signed_usages == 0 {
    usage.signed_bits = bits
  } else if usage.signed_bits != bits {
    usage.signed_bits = 0
  }
  usage.signed_usages += 1
  usages[local_idx] = usage
}

///|
fn pls_record_unsigned_usage(
  usages : Map[Int, PLSUsage],
  local_idx : Int,
  bits : Int,
) -> Unit {
  let usage = pls_get_usage(usages, local_idx)
  if usage.unsigned_usages == 0 {
    usage.unsigned_bits = bits
  } else if usage.unsigned_bits != bits {
    usage.unsigned_bits = 0
  }
  usage.unsigned_usages += 1
  usages[local_idx] = usage
}

///|
fn pls_sign_relevant_load_info(op : LoadOp) -> (Bool, Int)? {
  match op {
    I32Load8SOp => Some((true, 8))
    I32Load8UOp => Some((false, 8))
    I32Load16SOp => Some((true, 16))
    I32Load16UOp => Some((false, 16))
    I64Load8SOp => Some((true, 8))
    I64Load8UOp => Some((false, 8))
    I64Load16SOp => Some((true, 16))
    I64Load16UOp => Some((false, 16))
    I64Load32SOp => Some((true, 32))
    I64Load32UOp => Some((false, 32))
    _ => None
  }
}

///|
fn pls_load_with_signedness(op : LoadOp, signed : Bool) -> LoadOp? {
  match op {
    I32Load8SOp | I32Load8UOp =>
      if signed {
        Some(LoadOp::i32_load8s())
      } else {
        Some(LoadOp::i32_load8u())
      }
    I32Load16SOp | I32Load16UOp =>
      if signed {
        Some(LoadOp::i32_load16s())
      } else {
        Some(LoadOp::i32_load16u())
      }
    I64Load8SOp | I64Load8UOp =>
      if signed {
        Some(LoadOp::i64_load8s())
      } else {
        Some(LoadOp::i64_load8u())
      }
    I64Load16SOp | I64Load16UOp =>
      if signed {
        Some(LoadOp::i64_load16s())
      } else {
        Some(LoadOp::i64_load16u())
      }
    I64Load32SOp | I64Load32UOp =>
      if signed {
        Some(LoadOp::i64_load32s())
      } else {
        Some(LoadOp::i64_load32u())
      }
    _ => None
  }
}

///|
fn pls_i32_const(instr : TInstr) -> Int? {
  match instr.kind {
    TInstrKind::TI32Const(I32(v)) => Some(v)
    _ => None
  }
}

///|
fn pls_i64_const(instr : TInstr) -> Int64? {
  match instr.kind {
    TInstrKind::TI64Const(I64(v)) => Some(v)
    _ => None
  }
}

///|
fn pls_i32_low_mask_bits(mask : Int) -> Int? {
  let mut bits = 0
  let mut value = mask.reinterpret_as_uint()
  while bits < 32 && (value & 1U) == 1U {
    bits += 1
    value = value >> 1
  }
  if bits > 0 && value == 0U {
    Some(bits)
  } else {
    None
  }
}

///|
fn pls_i64_low_mask_bits(mask : Int64) -> Int? {
  let mut bits = 0
  let mut value = mask.reinterpret_as_uint64()
  while bits < 64 && (value & 1UL) == 1UL {
    bits += 1
    value = value >> 1
  }
  if bits > 0 && value == 0UL {
    Some(bits)
  } else {
    None
  }
}

///|
fn pls_i32_shift_ext_bits(shift : Int) -> Int {
  let effective = shift.reinterpret_as_uint() & 31U
  32 - effective.reinterpret_as_int()
}

///|
fn pls_i64_shift_ext_bits(shift : Int64) -> Int {
  let effective = shift.reinterpret_as_uint64() & 63UL
  64 - effective.reinterpret_as_int64().to_int()
}

///|
fn pls_sign_ext_bits(parent : TInstr, value : TInstr) -> Int? {
  match parent.kind {
    TInstrKind::TUnary(I32Extend8SOp, child) if child == value => Some(8)
    TInstrKind::TUnary(I32Extend16SOp, child) if child == value => Some(16)
    TInstrKind::TUnary(I64Extend8SOp, child) if child == value => Some(8)
    TInstrKind::TUnary(I64Extend16SOp, child) if child == value => Some(16)
    TInstrKind::TUnary(I64Extend32SOp, child) if child == value => Some(32)
    TInstrKind::TUnary(I64ExtendI32SOp, child) if child == value => Some(32)
    TInstrKind::TBinary(I32ShrSOp, lhs, rhs_shift) =>
      match lhs.kind {
        TInstrKind::TBinary(I32ShlOp, inner, lhs_shift) =>
          if inner == value {
            match (pls_i32_const(lhs_shift), pls_i32_const(rhs_shift)) {
              (Some(a), Some(b)) if a == b => Some(pls_i32_shift_ext_bits(a))
              _ => None
            }
          } else {
            None
          }
        _ => None
      }
    TInstrKind::TBinary(I64ShrSOp, lhs, rhs_shift) =>
      match lhs.kind {
        TInstrKind::TBinary(I64ShlOp, inner, lhs_shift) =>
          if inner == value {
            match (pls_i64_const(lhs_shift), pls_i64_const(rhs_shift)) {
              (Some(a), Some(b)) if a == b => Some(pls_i64_shift_ext_bits(a))
              _ => None
            }
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn pls_zero_ext_bits(parent : TInstr, value : TInstr) -> Int? {
  match parent.kind {
    TInstrKind::TUnary(I64ExtendI32UOp, child) if child == value => Some(32)
    TInstrKind::TBinary(I32AndOp, left, right) if left == value =>
      match pls_i32_const(right) {
        Some(mask) => pls_i32_low_mask_bits(mask)
        None => None
      }
    TInstrKind::TBinary(I32AndOp, left, right) if right == value =>
      match pls_i32_const(left) {
        Some(mask) => pls_i32_low_mask_bits(mask)
        None => None
      }
    TInstrKind::TBinary(I64AndOp, left, right) if left == value =>
      match pls_i64_const(right) {
        Some(mask) => pls_i64_low_mask_bits(mask)
        None => None
      }
    TInstrKind::TBinary(I64AndOp, left, right) if right == value =>
      match pls_i64_const(left) {
        Some(mask) => pls_i64_low_mask_bits(mask)
        None => None
      }
    TInstrKind::TBinary(I32ShrUOp, lhs, rhs_shift) =>
      match lhs.kind {
        TInstrKind::TBinary(I32ShlOp, inner, lhs_shift) =>
          if inner == value {
            match (pls_i32_const(lhs_shift), pls_i32_const(rhs_shift)) {
              (Some(a), Some(b)) if a == b => Some(pls_i32_shift_ext_bits(a))
              _ => None
            }
          } else {
            None
          }
        _ => None
      }
    TInstrKind::TBinary(I64ShrUOp, lhs, rhs_shift) =>
      match lhs.kind {
        TInstrKind::TBinary(I64ShlOp, inner, lhs_shift) =>
          if inner == value {
            match (pls_i64_const(lhs_shift), pls_i64_const(rhs_shift)) {
              (Some(a), Some(b)) if a == b => Some(pls_i64_shift_ext_bits(a))
              _ => None
            }
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn pls_get_parent_from_end(
  parent_stack : Array[TInstr],
  from_end : Int,
) -> TInstr? {
  if parent_stack.length() < from_end {
    None
  } else {
    Some(parent_stack[parent_stack.length() - from_end])
  }
}

///|
fn pls_candidate_load(
  curr : TInstr,
  parent_stack : Array[TInstr],
) -> PLSCandidateLoad? {
  match curr.kind {
    TInstrKind::TLoad(op, _, _) =>
      match pls_sign_relevant_load_info(op) {
        Some((current_signed, load_bits)) =>
          match parent_stack.last() {
            Some({ kind: TInstrKind::TLocalSet(local_idx, _), .. }) =>
              Some({
                local_idx: pls_local_idx_to_int(local_idx),
                load_bits,
                current_signed,
              })
            _ => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn pls_analyze_body(body : TExpr) -> Result[PLSAnalysis, String] {
  pls_analyze_body_with_trace(body, pls_trace_noop, 0, false, 0UL)
}

///|
fn pls_analyze_body_with_trace(
  body : TExpr,
  trace : (String) -> Unit,
  ordinal : Int,
  log_func : Bool,
  func_start_ms : UInt64,
) -> Result[PLSAnalysis, String] {
  let phase_start_ms = sl_trace_now_ms()
  let usage_by_local : Map[Int, PLSUsage] = Map::new()
  let candidates : Array[PLSCandidateLoad] = []
  let parent_stack : Array[TInstr] = []
  let last_progress_ms = Ref::new(phase_start_ms)
  let instr_visits = Ref::new(0)
  let local_gets = Ref::new(0)
  let candidate_count = Ref::new(0)
  if log_func {
    trace(
      "func[\{ordinal}] phase=analyze start top_instrs=\{body.instrs.length()}",
    )
  }
  let scanner = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    instr_visits.update(fn(n) { n + 1 })
    match pls_candidate_load(curr, parent_stack) {
      Some(candidate) => {
        candidates.push(candidate)
        candidate_count.update(fn(n) { n + 1 })
      }
      None => ()
    }
    match curr.kind {
      TInstrKind::TLocalGet(local_idx) => {
        local_gets.update(fn(n) { n + 1 })
        let local_int = pls_local_idx_to_int(local_idx)
        let usage = pls_get_usage(usage_by_local, local_int)
        usage.total_usages += 1
        usage_by_local[local_int] = usage
        for depth in [1, 2] {
          match pls_get_parent_from_end(parent_stack, depth) {
            Some(parent) =>
              match pls_zero_ext_bits(parent, curr) {
                Some(bits) =>
                  pls_record_unsigned_usage(usage_by_local, local_int, bits)
                None =>
                  match pls_sign_ext_bits(parent, curr) {
                    Some(bits) =>
                      pls_record_signed_usage(usage_by_local, local_int, bits)
                    None => ()
                  }
              }
            None => ()
          }
        }
      }
      _ => ()
    }
    pls_trace_maybe_progress(
      log_func,
      trace,
      ordinal,
      "analyze",
      func_start_ms,
      phase_start_ms,
      last_progress_ms,
      instr_visits.val,
      local_gets.val,
      candidate_count.val,
      0,
      curr,
    )
    parent_stack.push(curr)
    let out = self.walk_tinstruction_default((), curr)
    ignore(parent_stack.pop())
    from_walk(out)
  })
  match scanner.walk_texpr((), body) {
    Ok(_) => {
      if log_func {
        trace(
          "func[\{ordinal}] phase=analyze done elapsed_ms=\{sl_trace_elapsed_ms(phase_start_ms)} instrs=\{instr_visits.val} local_gets=\{local_gets.val} candidates=\{candidate_count.val} usage_locals=\{usage_by_local.length()}",
        )
      }
      Ok({ usage_by_local, candidates })
    }
    Err(e) => {
      if log_func {
        trace(
          "func[\{ordinal}] phase=analyze error elapsed_ms=\{sl_trace_elapsed_ms(phase_start_ms)} instrs=\{instr_visits.val} local_gets=\{local_gets.val} candidates=\{candidate_count.val} \{e}",
        )
      }
      Err(e)
    }
  }
}

///|
fn pls_target_signedness(
  candidate : PLSCandidateLoad,
  usage_by_local : Map[Int, PLSUsage],
) -> Bool {
  let usage = usage_by_local.get(candidate.local_idx).unwrap_or(PLSUsage::new())
  if usage.total_usages == 0 ||
    usage.signed_usages + usage.unsigned_usages != usage.total_usages ||
    (usage.signed_usages != 0 && usage.signed_bits != candidate.load_bits) ||
    (usage.unsigned_usages != 0 && usage.unsigned_bits != candidate.load_bits) {
    candidate.current_signed
  } else {
    usage.signed_usages * 2 >= usage.unsigned_usages
  }
}

///|
fn pls_rewrite_body_with_trace(
  body : TExpr,
  analysis : PLSAnalysis,
  trace : (String) -> Unit,
  ordinal : Int,
  log_func : Bool,
  func_start_ms : UInt64,
) -> Result[TExpr, String] {
  let phase_start_ms = sl_trace_now_ms()
  if analysis.candidates.is_empty() {
    if log_func {
      trace(
        "func[\{ordinal}] phase=rewrite skip elapsed_ms=\{sl_trace_elapsed_ms(phase_start_ms)} reason=no_candidates",
      )
    }
    return Ok(body)
  }
  let parent_stack : Array[TInstr] = []
  let last_progress_ms = Ref::new(phase_start_ms)
  let instr_visits = Ref::new(0)
  let rewrite_count = Ref::new(0)
  if log_func {
    trace(
      "func[\{ordinal}] phase=rewrite start top_instrs=\{body.instrs.length()} candidates=\{analysis.candidates.length()}",
    )
  }
  let rewriter = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    curr,
  ) {
    instr_visits.update(fn(n) { n + 1 })
    let candidate = pls_candidate_load(curr, parent_stack)
    parent_stack.push(curr)
    let walked = match self.walk_tinstruction_default((), curr) {
      Ok((out, _)) => out
      Ok(_) => curr
      Err(e) => return error(e)
    }
    ignore(parent_stack.pop())
    let output = match candidate {
      Some(candidate) => {
        let target_signed = pls_target_signedness(
          candidate,
          analysis.usage_by_local,
        )
        match walked.kind {
          TInstrKind::TLoad(op, memarg, ptr) =>
            match pls_load_with_signedness(op, target_signed) {
              Some(new_op) => TInstr::load(new_op, memarg, ptr)
              None => walked
            }
          _ => walked
        }
      }
      None => walked
    }
    if output != curr {
      rewrite_count.update(fn(n) { n + 1 })
    }
    pls_trace_maybe_progress(
      log_func,
      trace,
      ordinal,
      "rewrite",
      func_start_ms,
      phase_start_ms,
      last_progress_ms,
      instr_visits.val,
      0,
      analysis.candidates.length(),
      rewrite_count.val,
      curr,
    )
    if output == curr {
      change((), walked)
    } else {
      change((), output)
    }
  })
  match rewriter.walk_texpr((), body) {
    Ok((rewritten, _)) => {
      if log_func {
        trace(
          "func[\{ordinal}] phase=rewrite done elapsed_ms=\{sl_trace_elapsed_ms(phase_start_ms)} instrs=\{instr_visits.val} rewrites=\{rewrite_count.val} changed=\{rewritten != body} top_instrs=\{body.instrs.length()}->\{rewritten.instrs.length()}",
        )
      }
      Ok(rewritten)
    }
    Ok(_) => {
      if log_func {
        trace(
          "func[\{ordinal}] phase=rewrite done elapsed_ms=\{sl_trace_elapsed_ms(phase_start_ms)} instrs=\{instr_visits.val} rewrites=\{rewrite_count.val} changed=false top_instrs=\{body.instrs.length()}->\{body.instrs.length()}",
        )
      }
      Ok(body)
    }
    Err(e) => {
      if log_func {
        trace(
          "func[\{ordinal}] phase=rewrite error elapsed_ms=\{sl_trace_elapsed_ms(phase_start_ms)} instrs=\{instr_visits.val} rewrites=\{rewrite_count.val} \{e}",
        )
      }
      Err(e)
    }
  }
}

///|
fn pick_load_signs_on_func(
  ordinal : Int,
  func : Func,
  trace : (String) -> Unit,
  trace_all_funcs : Bool,
) -> Result[Func, String] {
  let log_func = pls_trace_should_log_func(ordinal, trace_all_funcs)
  let func_start_ms = sl_trace_now_ms()
  match func {
    Func(_) => {
      if log_func {
        trace(
          "func[\{ordinal}] skip non-typed-func elapsed_ms=\{sl_trace_elapsed_ms(func_start_ms)}",
        )
      }
      Ok(func)
    }
    TFunc(params, locals, body) => {
      let candidate_count = Ref::new(0)
      if log_func {
        trace(
          "func[\{ordinal}] start locals=\{locals.length()} top_instrs=\{body.instrs.length()}",
        )
      }
      let analysis = match
        pls_analyze_body_with_trace(
          body, trace, ordinal, log_func, func_start_ms,
        ) {
        Ok(a) => a
        Err(e) => return Err(e)
      }
      candidate_count.val = analysis.candidates.length()
      let rewritten = match
        pls_rewrite_body_with_trace(
          body, analysis, trace, ordinal, log_func, func_start_ms,
        ) {
        Ok(out) => out
        Err(e) => return Err(e)
      }
      if log_func {
        trace(
          "func[\{ordinal}] done elapsed_ms=\{sl_trace_elapsed_ms(func_start_ms)} changed=\{rewritten != body} top_instrs=\{body.instrs.length()}->\{rewritten.instrs.length()} locals=\{locals.length()} candidates=\{candidate_count.val}",
        )
      }
      Ok(Func::t_func(params, locals, rewritten))
    }
  }
}

///|
fn pick_load_signs_ir_pass_with_trace(
  _mod : Module,
  trace? : (String) -> Unit = pls_trace_noop,
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext, String] {
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, state, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let ordinal = def_idx + 1
    match pick_load_signs_on_func(ordinal, func, trace, trace_all_funcs) {
      Ok(updated) =>
        if updated == func {
          unchanged()
        } else {
          change(state, updated)
        }
      Err(e) => error(e)
    }
  })
}

///|
fn pick_load_signs_ir_pass(
  mod : Module,
) -> ModuleTransformer[IRContext, String] {
  pick_load_signs_ir_pass_with_trace(mod)
}

///|
fn pls_run_func(func : Func) -> Func {
  let pass = pick_load_signs_ir_pass(Module::new())
  let state = IRContext::new()
  match pass.walk_func(state, func) {
    Ok((out, _)) => out
    Ok(_) => func
    Err(e) => abort("pick_load_signs pass error: \{e}")
  }
}

///|
fn pls_i32_const_instr(v : Int) -> TInstr {
  TInstr::i32_const(I32(v))
}

///|
fn pls_i64_const_instr(v : Int64) -> TInstr {
  TInstr::i64_const(I64(v))
}

///|
test "pick_load_signs picks unsigned for i32.load8 when unsigned dominates" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i32_load8s(),
          MemArg::new(0, None, 0),
          pls_i32_const_instr(0),
        ),
      ),
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_and(),
          TInstr::local_get(loc),
          pls_i32_const_instr(255),
        ),
      ),
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_and(),
          TInstr::local_get(loc),
          pls_i32_const_instr(255),
        ),
      ),
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TLoad(I32Load8UOp, _, _), .. }
            ),
            ..,
          },
          _,
          _,
        ],
        ..,
      }
    ) => ()
    _ => fail("expected i32.load8_s to become i32.load8_u")
  }
}

///|
test "pick_load_signs picks signed when signed uses are weighted higher" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i32_load8u(),
          MemArg::new(0, None, 0),
          pls_i32_const_instr(0),
        ),
      ),
      TInstr::drop(
        TInstr::unary(UnaryOp::i32_extend8s(), TInstr::local_get(loc)),
      ),
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_and(),
          TInstr::local_get(loc),
          pls_i32_const_instr(255),
        ),
      ),
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TLoad(I32Load8SOp, _, _), .. }
            ),
            ..,
          },
          _,
          _,
        ],
        ..,
      }
    ) => ()
    _ => fail("expected i32.load8_u to become i32.load8_s")
  }
}

///|
test "pick_load_signs requires all loc.get uses to be sign-or-zero extensions" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i32_load8s(),
          MemArg::new(0, None, 0),
          pls_i32_const_instr(0),
        ),
      ),
      TInstr::drop(TInstr::local_get(loc)),
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_and(),
          TInstr::local_get(loc),
          pls_i32_const_instr(255),
        ),
      ),
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TLoad(I32Load8SOp, _, _), .. }
            ),
            ..,
          },
          _,
          _,
        ],
        ..,
      }
    ) => ()
    _ => fail("expected load op to stay signed due non-extension use")
  }
}

///|
test "pick_load_signs requires extension bits to match load bits" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i32_load8u(),
          MemArg::new(0, None, 0),
          pls_i32_const_instr(0),
        ),
      ),
      TInstr::drop(
        TInstr::unary(UnaryOp::i32_extend16s(), TInstr::local_get(loc)),
      ),
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TLoad(I32Load8UOp, _, _), .. }
            ),
            ..,
          },
          _,
        ],
        ..,
      }
    ) => ()
    _ => fail("expected no rewrite when sign extension width mismatches")
  }
}

///|
test "pick_load_signs rejects inconsistent signed extension widths" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i32_load8s(),
          MemArg::new(0, None, 0),
          pls_i32_const_instr(0),
        ),
      ),
      TInstr::drop(
        TInstr::unary(UnaryOp::i32_extend8s(), TInstr::local_get(loc)),
      ),
      TInstr::drop(
        TInstr::unary(UnaryOp::i32_extend16s(), TInstr::local_get(loc)),
      ),
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TLoad(I32Load8SOp, _, _), .. }
            ),
            ..,
          },
          _,
          _,
        ],
        ..,
      }
    ) => ()
    _ => fail("expected no rewrite with inconsistent signed widths")
  }
}

///|
test "pick_load_signs recognizes nested shift-based zero extension on grandparent" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i32_load16s(),
          MemArg::new(0, None, 0),
          pls_i32_const_instr(0),
        ),
      ),
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_shr_u(),
          TInstr::binary(
            BinaryOp::i32_shl(),
            TInstr::local_get(loc),
            pls_i32_const_instr(16),
          ),
          pls_i32_const_instr(16),
        ),
      ),
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TLoad(I32Load16UOp, _, _), .. }
            ),
            ..,
          },
          _,
        ],
        ..,
      }
    ) => ()
    _ => fail("expected i32.load16_s to become i32.load16_u")
  }
}

///|
test "pick_load_signs ignores loc.tee load producers" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::drop(
        TInstr::local_tee(
          loc,
          TInstr::load(
            LoadOp::i32_load8s(),
            MemArg::new(0, None, 0),
            pls_i32_const_instr(0),
          ),
        ),
      ),
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_and(),
          TInstr::local_get(loc),
          pls_i32_const_instr(255),
        ),
      ),
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TDrop(
              {
                kind: TInstrKind::TLocalTee(
                  _,
                  { kind: TInstrKind::TLoad(I32Load8SOp, _, _), .. }
                ),
                ..,
              }
            ),
            ..,
          },
          _,
        ],
        ..,
      }
    ) => ()
    _ => fail("expected tee load to remain unchanged")
  }
}

///|
test "pick_load_signs skips loads with no loc.get usages" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i32_load8s(),
          MemArg::new(0, None, 0),
          pls_i32_const_instr(0),
        ),
      ),
      TInstr::nop(),
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TLoad(I32Load8SOp, _, _), .. }
            ),
            ..,
          },
          _,
        ],
        ..,
      }
    ) => ()
    _ => fail("expected no rewrite with zero usages")
  }
}

///|
test "pick_load_signs rewrites i64.load32 based on i64.extend32_s usage" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i64()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i64_load32u(),
          MemArg::new(0, None, 0),
          pls_i32_const_instr(0),
        ),
      ),
      TInstr::drop(
        TInstr::unary(UnaryOp::i64_extend32s(), TInstr::local_get(loc)),
      ),
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TLoad(I64Load32SOp, _, _), .. }
            ),
            ..,
          },
          _,
        ],
        ..,
      }
    ) => ()
    _ => fail("expected i64.load32_u to become i64.load32_s")
  }
}

///|
test "pick_load_signs rewrites i64.load32 to unsigned for i64.and mask usage" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i64()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i64_load32s(),
          MemArg::new(0, None, 0),
          pls_i32_const_instr(0),
        ),
      ),
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i64_and(),
          TInstr::local_get(loc),
          pls_i64_const_instr(0xffffffffL),
        ),
      ),
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TLoad(I64Load32UOp, _, _), .. }
            ),
            ..,
          },
          _,
        ],
        ..,
      }
    ) => ()
    _ => fail("expected i64.load32_s to become i64.load32_u")
  }
}

///|
test "pick_load_signs rewrites all candidate loads mapped to the same loc" {
  let loc = LocalIdx::new(0)
  let body = TExpr::new([
    TInstr::local_set(
      loc,
      TInstr::load(
        LoadOp::i32_load8s(),
        MemArg::new(0, None, 0),
        pls_i32_const_instr(0),
      ),
    ),
    TInstr::drop(
      TInstr::binary(
        BinaryOp::i32_and(),
        TInstr::local_get(loc),
        pls_i32_const_instr(255),
      ),
    ),
    TInstr::local_set(
      loc,
      TInstr::load(
        LoadOp::i32_load8s(),
        MemArg::new(0, None, 4),
        pls_i32_const_instr(0),
      ),
    ),
    TInstr::drop(
      TInstr::binary(
        BinaryOp::i32_and(),
        TInstr::local_get(loc),
        pls_i32_const_instr(255),
      ),
    ),
  ])
  let analysis = match pls_analyze_body(body) {
    Ok(a) => a
    Err(e) => fail("unexpected analysis error: \{e}")
  }
  assert_eq(analysis.candidates.length(), 2)
  let func = Func::t_func([], [ValType::i32()], body)
  let out = pls_run_func(func)
  match out {
    TFunc(_, _, { instrs, .. }) => {
      let mut signed_count = 0
      let mut unsigned_count = 0
      for instr in instrs {
        match instr.kind {
          TInstrKind::TLocalSet(
            _,
            { kind: TInstrKind::TLoad(I32Load8SOp, _, _), .. }
          ) => signed_count += 1
          TInstrKind::TLocalSet(
            _,
            { kind: TInstrKind::TLoad(I32Load8UOp, _, _), .. }
          ) => unsigned_count += 1
          _ => ()
        }
      }
      assert_eq(unsigned_count, 2)
      assert_eq(signed_count, 0)
    }
    _ => fail("expected transformed function")
  }
}

///|
test "pick_load_signs trace covers function phases" {
  let logs : Array[String] = []
  let loc = LocalIdx::new(0)
  ignore(
    match
      pick_load_signs_ir_pass_with_trace(
        Module::new(),
        trace=fn(msg) { logs.push(msg) },
        trace_all_funcs=true,
      ).walk_func(
        IRContext::new(),
        Func::t_func(
          [],
          [ValType::i32()],
          TExpr::new([
            TInstr::local_set(
              loc,
              TInstr::load(
                LoadOp::i32_load8s(),
                MemArg::new(0, None, 0),
                pls_i32_const_instr(0),
              ),
            ),
            TInstr::drop(
              TInstr::binary(
                BinaryOp::i32_and(),
                TInstr::local_get(loc),
                pls_i32_const_instr(255),
              ),
            ),
          ]),
        ),
      ) {
      Ok(_) => ()
      Err(e) => fail("unexpected pick_load_signs trace error: \{e}")
    },
  )
  let mut saw_start = false
  let mut saw_analyze_start = false
  let mut saw_analyze_done = false
  let mut saw_rewrite_start = false
  let mut saw_rewrite_done = false
  let mut saw_done = false
  for msg in logs {
    if msg.contains("func[1] start") {
      saw_start = true
    }
    if msg.contains("func[1] phase=analyze start") {
      saw_analyze_start = true
    }
    if msg.contains("func[1] phase=analyze done") {
      saw_analyze_done = true
    }
    if msg.contains("func[1] phase=rewrite start") {
      saw_rewrite_start = true
    }
    if msg.contains("func[1] phase=rewrite done") {
      saw_rewrite_done = true
    }
    if msg.contains("func[1] done") {
      saw_done = true
    }
  }
  assert_true(saw_start)
  assert_true(saw_analyze_start)
  assert_true(saw_analyze_done)
  assert_true(saw_rewrite_start)
  assert_true(saw_rewrite_done)
  assert_true(saw_done)
}

///|
test "pick_load_signs is idempotent" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        loc,
        TInstr::load(
          LoadOp::i32_load16s(),
          MemArg::new(0, None, 0),
          pls_i32_const_instr(0),
        ),
      ),
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_and(),
          TInstr::local_get(loc),
          pls_i32_const_instr(65535),
        ),
      ),
    ]),
  )
  let once = pls_run_func(func)
  let twice = pls_run_func(once)
  assert_eq(once, twice)
}
