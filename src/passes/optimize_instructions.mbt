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
fn oi_is_power_of_2_i32(x : Int) -> Bool {
  x > 0 && (x & (x - 1)) == 0
}

///|
fn oi_is_power_of_2_i64(x : Int64) -> Bool {
  x > 0L && (x & (x - 1L)) == 0L
}

///|
fn oi_log2_i32(x : Int) -> Int {
  x.ctz()
}

///|
fn oi_log2_i64(x : Int64) -> Int64 {
  x.ctz().to_int64()
}

///|
fn oi_wrap_i32(x : Int) -> Int {
  (x.reinterpret_as_uint() & 0xffffffff).reinterpret_as_int()
}

///|
fn oi_wrap_i64(x : Int64) -> Int64 {
  x.reinterpret_as_uint64().reinterpret_as_int64()
}

///|
fn oi_const_i32(instr : TInstr) -> Int? {
  match instr.kind {
    TInstrKind::TI32Const(I32(v)) => Some(v)
    _ => None
  }
}

///|
fn oi_is_const(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_) => true
    _ => false
  }
}

///|
fn oi_instr_stmt(instr : TInstr, env : Env) -> TInstr {
  match lcs_infer_tinstr_type(instr, env) {
    Some(_) => TInstr::drop(instr)
    None => instr
  }
}

///|
fn oi_seq(stmts : Array[TInstr], result : TInstr, env : Env) -> TInstr {
  if stmts.is_empty() {
    result
  } else {
    let list = stmts.copy()
    list.push(result)
    let bt = match lcs_infer_tinstr_type(result, env) {
      Some(vt) => BlockType::val_type(vt)
      None => BlockType::void_()
    }
    TInstr::block(bt, TExpr::new(list))
  }
}

///|
priv struct OIEffectsSummary {
  locals_read : Set[LocalIdx]
  locals_written : Set[LocalIdx]
  reads_memory : Bool
  writes_memory : Bool
  reads_globals : Bool
  writes_globals : Bool
  calls : Bool
  branches : Bool
  traps : Bool
  throws : Bool
  has_side_effects : Bool
}

///|
fn OIEffectsSummary::transfers_control_flow(self : OIEffectsSummary) -> Bool {
  self.branches || self.throws
}

///|
fn OIEffectsSummary::invalidates(
  self : OIEffectsSummary,
  other : OIEffectsSummary,
) -> Bool {
  for local_idx in self.locals_written {
    if other.locals_read.contains(local_idx) ||
      other.locals_written.contains(local_idx) {
      return true
    }
  }
  for local_idx in self.locals_read {
    if other.locals_written.contains(local_idx) {
      return true
    }
  }
  if (self.reads_memory && other.writes_memory) ||
    (self.writes_memory && other.reads_memory) ||
    (self.writes_memory && other.writes_memory) {
    return true
  }
  if (self.reads_globals && other.writes_globals) ||
    (self.writes_globals && other.reads_globals) ||
    (self.writes_globals && other.writes_globals) {
    return true
  }
  if self.calls || other.calls {
    if self.reads_memory ||
      self.writes_memory ||
      other.reads_memory ||
      other.writes_memory ||
      self.reads_globals ||
      self.writes_globals ||
      other.reads_globals ||
      other.writes_globals {
      return true
    }
  }
  if self.transfers_control_flow() || other.transfers_control_flow() {
    return true
  }
  if (self.traps && other.has_side_effects) ||
    (other.traps && self.has_side_effects) {
    return true
  }
  false
}

///|
priv struct OIRewriteCache {
  effects_by_instr : Map[TInstr, OIEffectsSummary]
  instr_size_by_instr : Map[TInstr, Int]
  reorder_by_pair : Map[OIInstrPairKey, Bool]
  eq_by_pair : Map[OIInstrPairKey, Bool]
}

///|
priv struct OIInstrPairKey {
  low_hash : UInt64
  high_hash : UInt64
} derive(Eq, Hash)

///|
fn oi_instr_hash_u64(instr : TInstr) -> UInt64 {
  instr.hash().reinterpret_as_uint().to_uint64()
}

///|
fn oi_pair_key_from_hashes(
  left_hash : UInt64,
  right_hash : UInt64,
) -> OIInstrPairKey {
  let low_hash = if left_hash <= right_hash { left_hash } else { right_hash }
  let high_hash = if left_hash <= right_hash { right_hash } else { left_hash }
  OIInstrPairKey::{ low_hash, high_hash }
}

///|
fn oi_pair_key(left : TInstr, right : TInstr) -> OIInstrPairKey {
  oi_pair_key_from_hashes(oi_instr_hash_u64(left), oi_instr_hash_u64(right))
}

///|
fn oi_rewrite_cache_new() -> OIRewriteCache {
  OIRewriteCache::{
    effects_by_instr: Map::new(),
    instr_size_by_instr: Map::new(),
    reorder_by_pair: Map::new(),
    eq_by_pair: Map::new(),
  }
}

///|
fn oi_instr_size_cached(instr : TInstr, cache : OIRewriteCache) -> Int {
  match cache.instr_size_by_instr.get(instr) {
    Some(size) => size
    None => {
      let mut size = 1
      for child in eval_children(instr) {
        size += oi_instr_size_cached(child, cache)
      }
      cache.instr_size_by_instr[instr] = size
      size
    }
  }
}

///|
fn oi_texpr_size_cached(texpr : TExpr, cache : OIRewriteCache) -> Int {
  let mut size = 0
  for instr in texpr.instrs {
    size += oi_instr_size_cached(instr, cache)
  }
  size
}

///|
fn oi_effects_summary_cached(
  instr : TInstr,
  cache : OIRewriteCache,
) -> OIEffectsSummary {
  match cache.effects_by_instr.get(instr) {
    Some(summary) => summary
    None => {
      let shallow = lcs_collect_shallow_effects(instr)
      let locals_read = shallow.locals_read
      let locals_written = shallow.locals_written
      let mut reads_memory = shallow.reads_memory
      let mut writes_memory = shallow.writes_memory
      let mut reads_globals = shallow.reads_globals
      let mut writes_globals = shallow.writes_globals
      let mut calls = shallow.calls
      let mut branches = shallow.branches
      let mut traps = shallow.traps
      let mut throws = shallow.throws
      for child in eval_children(instr) {
        let child_summary = oi_effects_summary_cached(child, cache)
        for idx in child_summary.locals_read {
          locals_read.add(idx)
        }
        for idx in child_summary.locals_written {
          locals_written.add(idx)
        }
        reads_memory = reads_memory || child_summary.reads_memory
        writes_memory = writes_memory || child_summary.writes_memory
        reads_globals = reads_globals || child_summary.reads_globals
        writes_globals = writes_globals || child_summary.writes_globals
        calls = calls || child_summary.calls
        branches = branches || child_summary.branches
        traps = traps || child_summary.traps
        throws = throws || child_summary.throws
      }
      let summary = OIEffectsSummary::{
        locals_read,
        locals_written,
        reads_memory,
        writes_memory,
        reads_globals,
        writes_globals,
        calls,
        branches,
        traps,
        throws,
        has_side_effects: writes_memory ||
        writes_globals ||
        calls ||
        branches ||
        throws ||
        traps ||
        locals_written.length() > 0 ||
        reads_memory ||
        reads_globals,
      }
      cache.effects_by_instr[instr] = summary
      summary
    }
  }
}

///|
fn oi_can_reorder_cached(
  a : TInstr,
  b : TInstr,
  cache : OIRewriteCache,
) -> Bool {
  if oi_instr_size_cached(a, cache) > 512 ||
    oi_instr_size_cached(b, cache) > 512 {
    return false
  }
  let key = oi_pair_key(a, b)
  match cache.reorder_by_pair.get(key) {
    Some(value) => value
    None => {
      let ea = oi_effects_summary_cached(a, cache)
      let eb = oi_effects_summary_cached(b, cache)
      let value = !ea.invalidates(eb) && !eb.invalidates(ea)
      cache.reorder_by_pair[key] = value
      value
    }
  }
}

///|
fn oi_instr_eq_cached(
  left : TInstr,
  right : TInstr,
  cache : OIRewriteCache,
) -> Bool {
  match oi_instr_quick_eq_or_mismatch(left, right) {
    Some(value) => return value
    None => ()
  }
  if oi_instr_size_cached(left, cache) > 512 ||
    oi_instr_size_cached(right, cache) > 512 {
    return false
  }
  if physical_equal(left, right) {
    return true
  }
  if left.hash() != right.hash() {
    return false
  }
  let key = oi_pair_key(left, right)
  let reverse_key = oi_pair_key(right, left)
  match cache.eq_by_pair.get(key) {
    Some(value) => value
    None =>
      match cache.eq_by_pair.get(reverse_key) {
        Some(value) => value
        None => {
          let value = left == right
          cache.eq_by_pair[key] = value
          cache.eq_by_pair[reverse_key] = value
          value
        }
      }
  }
}

///|
fn oi_instr_eq_for_change(
  left : TInstr,
  right : TInstr,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
) -> Bool {
  match oi_instr_quick_eq_or_mismatch(left, right) {
    Some(value) => value
    None =>
      if allow_expensive_eq {
        oi_instr_eq_cached(left, right, cache)
      } else {
        let budget = 96
        if !oi_instr_within_eq_budget(left, budget, cache) ||
          !oi_instr_within_eq_budget(right, budget, cache) {
          false
        } else {
          left == right
        }
      }
  }
}

///|
fn oi_instr_quick_eq_or_mismatch(left : TInstr, right : TInstr) -> Bool? {
  match (left, right) {
    (
      { kind: TInstrKind::TLocalGet(l_idx), .. },
      { kind: TInstrKind::TLocalGet(r_idx), .. },
    ) => Some(l_idx == r_idx)
    ({ kind: TInstrKind::TLocalGet(_), .. }, _)
    | (_, { kind: TInstrKind::TLocalGet(_), .. }) => Some(false)
    (
      { kind: TInstrKind::TI32Const(lv), .. },
      { kind: TInstrKind::TI32Const(rv), .. },
    ) => Some(lv == rv)
    ({ kind: TInstrKind::TI32Const(_), .. }, _)
    | (_, { kind: TInstrKind::TI32Const(_), .. }) => Some(false)
    (
      { kind: TInstrKind::TI64Const(lv), .. },
      { kind: TInstrKind::TI64Const(rv), .. },
    ) => Some(lv == rv)
    ({ kind: TInstrKind::TI64Const(_), .. }, _)
    | (_, { kind: TInstrKind::TI64Const(_), .. }) => Some(false)
    (
      { kind: TInstrKind::TF32Const(lv), .. },
      { kind: TInstrKind::TF32Const(rv), .. },
    ) => Some(lv == rv)
    ({ kind: TInstrKind::TF32Const(_), .. }, _)
    | (_, { kind: TInstrKind::TF32Const(_), .. }) => Some(false)
    (
      { kind: TInstrKind::TF64Const(lv), .. },
      { kind: TInstrKind::TF64Const(rv), .. },
    ) => Some(lv == rv)
    ({ kind: TInstrKind::TF64Const(_), .. }, _)
    | (_, { kind: TInstrKind::TF64Const(_), .. }) => Some(false)
    _ => None
  }
}

///|
fn oi_instr_is_large_blockish(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBlock(_, texpr) | TInstrKind::TLoop(_, texpr) =>
      texpr.instrs.length() > 128
    TInstrKind::TIf(_, _, then_, Some(else_)) =>
      then_.instrs.length() > 128 || else_.instrs.length() > 128
    TInstrKind::TIf(_, _, then_, None) => then_.instrs.length() > 128
    _ => false
  }
}

///|
fn oi_instr_within_eq_budget(
  instr : TInstr,
  budget : Int,
  cache : OIRewriteCache,
) -> Bool {
  oi_instr_size_cached(instr, cache) <= budget
}

///|
fn oi_texpr_within_eq_budget(
  texpr : TExpr,
  budget : Int,
  cache : OIRewriteCache,
) -> Bool {
  oi_texpr_size_cached(texpr, cache) <= budget
}

///|
fn oi_instr_eq_budgeted(
  left : TInstr,
  right : TInstr,
  cache : OIRewriteCache,
  budget : Int,
) -> Bool {
  match oi_instr_quick_eq_or_mismatch(left, right) {
    Some(value) => return value
    None => ()
  }
  if !oi_instr_within_eq_budget(left, budget, cache) ||
    !oi_instr_within_eq_budget(right, budget, cache) {
    return false
  }
  oi_instr_eq_cached(left, right, cache)
}

///|
fn oi_texpr_eq_budgeted(
  left : TExpr,
  right : TExpr,
  cache : OIRewriteCache,
  budget : Int,
) -> Bool {
  if left.instrs.length() != right.instrs.length() {
    return false
  }
  if left.instrs.is_empty() {
    return true
  }
  if left.instrs.length() == 1 {
    match oi_instr_quick_eq_or_mismatch(left.instrs[0], right.instrs[0]) {
      Some(value) => return value
      None => ()
    }
  }
  if !oi_texpr_within_eq_budget(left, budget, cache) ||
    !oi_texpr_within_eq_budget(right, budget, cache) {
    return false
  }
  for i = 0; i < left.instrs.length(); i = i + 1 {
    let l = left.instrs[i]
    let r = right.instrs[i]
    match oi_instr_quick_eq_or_mismatch(l, r) {
      Some(value) => if !value { return false }
      None => if !oi_instr_eq_cached(l, r, cache) { return false }
    }
  }
  true
}

///|
fn oi_instr_equal_for_fold(
  left : TInstr,
  right : TInstr,
  cache : OIRewriteCache,
  budget : Int,
  allow_expensive_eq : Bool,
) -> Bool {
  match oi_instr_quick_eq_or_mismatch(left, right) {
    Some(value) => value
    None => {
      if !allow_expensive_eq ||
        oi_instr_is_large_blockish(left) ||
        oi_instr_is_large_blockish(right) {
        return false
      }
      oi_instr_eq_budgeted(left, right, cache, budget)
    }
  }
}

///|
fn oi_texpr_equal_for_fold(
  left : TExpr,
  right : TExpr,
  cache : OIRewriteCache,
  budget : Int,
  allow_expensive_eq : Bool,
) -> Bool {
  if left.instrs.length() != right.instrs.length() {
    return false
  }
  if left.instrs.is_empty() {
    return true
  }
  if left.instrs.length() == 1 {
    match oi_instr_quick_eq_or_mismatch(left.instrs[0], right.instrs[0]) {
      Some(value) => return value
      None => ()
    }
  }
  if !allow_expensive_eq {
    return false
  }
  if left.instrs.length() > 128 || right.instrs.length() > 128 {
    return false
  }
  oi_texpr_eq_budgeted(left, right, cache, budget)
}

///|
fn oi_can_reorder(a : TInstr, b : TInstr) -> Bool {
  let cache = oi_rewrite_cache_new()
  oi_can_reorder_cached(a, b, cache)
}

///|
fn oi_has_side_effects_cached(instr : TInstr, cache : OIRewriteCache) -> Bool {
  oi_effects_summary_cached(instr, cache).has_side_effects
}

///|
fn oi_precompute_cached_summaries(body : TExpr, cache : OIRewriteCache) -> Unit {
  for instr in body.instrs {
    ignore(oi_instr_size_cached(instr, cache))
    ignore(oi_effects_summary_cached(instr, cache))
  }
}

///|
fn oi_is_symmetric(op : BinaryOp) -> Bool {
  match op {
    I32EqOp
    | I32NeOp
    | I64EqOp
    | I64NeOp
    | F32EqOp
    | F32NeOp
    | F64EqOp
    | F64NeOp
    | I32AddOp
    | I32MulOp
    | I32AndOp
    | I32OrOp
    | I32XorOp
    | I64AddOp
    | I64MulOp
    | I64AndOp
    | I64OrOp
    | I64XorOp
    | F32AddOp
    | F32MulOp
    | F64AddOp
    | F64MulOp => true
    _ => false
  }
}

///|
fn oi_is_relational(op : BinaryOp) -> Bool {
  match op {
    I32EqOp
    | I32NeOp
    | I32LtSOp
    | I32LtUOp
    | I32GtSOp
    | I32GtUOp
    | I32LeSOp
    | I32LeUOp
    | I32GeSOp
    | I32GeUOp
    | I64EqOp
    | I64NeOp
    | I64LtSOp
    | I64LtUOp
    | I64GtSOp
    | I64GtUOp
    | I64LeSOp
    | I64LeUOp
    | I64GeSOp
    | I64GeUOp
    | F32EqOp
    | F32NeOp
    | F32LtOp
    | F32GtOp
    | F32LeOp
    | F32GeOp
    | F64EqOp
    | F64NeOp
    | F64LtOp
    | F64GtOp
    | F64LeOp
    | F64GeOp => true
    _ => false
  }
}

///|
fn oi_reverse_relational(op : BinaryOp) -> BinaryOp? {
  match op {
    I32EqOp => Some(BinaryOp::i32_eq())
    I32NeOp => Some(BinaryOp::i32_ne())
    I32LtSOp => Some(BinaryOp::i32_gt_s())
    I32LtUOp => Some(BinaryOp::i32_gt_u())
    I32LeSOp => Some(BinaryOp::i32_ge_s())
    I32LeUOp => Some(BinaryOp::i32_ge_u())
    I32GtSOp => Some(BinaryOp::i32_lt_s())
    I32GtUOp => Some(BinaryOp::i32_lt_u())
    I32GeSOp => Some(BinaryOp::i32_le_s())
    I32GeUOp => Some(BinaryOp::i32_le_u())
    I64EqOp => Some(BinaryOp::i64_eq())
    I64NeOp => Some(BinaryOp::i64_ne())
    I64LtSOp => Some(BinaryOp::i64_gt_s())
    I64LtUOp => Some(BinaryOp::i64_gt_u())
    I64LeSOp => Some(BinaryOp::i64_ge_s())
    I64LeUOp => Some(BinaryOp::i64_ge_u())
    I64GtSOp => Some(BinaryOp::i64_lt_s())
    I64GtUOp => Some(BinaryOp::i64_lt_u())
    I64GeSOp => Some(BinaryOp::i64_le_s())
    I64GeUOp => Some(BinaryOp::i64_le_u())
    F32EqOp => Some(BinaryOp::f32_eq())
    F32NeOp => Some(BinaryOp::f32_ne())
    F32LtOp => Some(BinaryOp::f32_gt())
    F32LeOp => Some(BinaryOp::f32_ge())
    F32GtOp => Some(BinaryOp::f32_lt())
    F32GeOp => Some(BinaryOp::f32_le())
    F64EqOp => Some(BinaryOp::f64_eq())
    F64NeOp => Some(BinaryOp::f64_ne())
    F64LtOp => Some(BinaryOp::f64_gt())
    F64LeOp => Some(BinaryOp::f64_ge())
    F64GtOp => Some(BinaryOp::f64_lt())
    F64GeOp => Some(BinaryOp::f64_le())
    _ => None
  }
}

///|
fn oi_invert_relational(op : BinaryOp) -> BinaryOp? {
  match op {
    I32EqOp => Some(BinaryOp::i32_ne())
    I32NeOp => Some(BinaryOp::i32_eq())
    I32LtSOp => Some(BinaryOp::i32_ge_s())
    I32LtUOp => Some(BinaryOp::i32_ge_u())
    I32LeSOp => Some(BinaryOp::i32_gt_s())
    I32LeUOp => Some(BinaryOp::i32_gt_u())
    I32GtSOp => Some(BinaryOp::i32_le_s())
    I32GtUOp => Some(BinaryOp::i32_le_u())
    I32GeSOp => Some(BinaryOp::i32_lt_s())
    I32GeUOp => Some(BinaryOp::i32_lt_u())
    I64EqOp => Some(BinaryOp::i64_ne())
    I64NeOp => Some(BinaryOp::i64_eq())
    I64LtSOp => Some(BinaryOp::i64_ge_s())
    I64LtUOp => Some(BinaryOp::i64_ge_u())
    I64LeSOp => Some(BinaryOp::i64_gt_s())
    I64LeUOp => Some(BinaryOp::i64_gt_u())
    I64GtSOp => Some(BinaryOp::i64_le_s())
    I64GtUOp => Some(BinaryOp::i64_le_u())
    I64GeSOp => Some(BinaryOp::i64_lt_s())
    I64GeUOp => Some(BinaryOp::i64_lt_u())
    F32EqOp => Some(BinaryOp::f32_ne())
    F32NeOp => Some(BinaryOp::f32_eq())
    F64EqOp => Some(BinaryOp::f64_ne())
    F64NeOp => Some(BinaryOp::f64_eq())
    _ => None
  }
}

///|
fn oi_is_shift(op : BinaryOp) -> Bool {
  match op {
    I32ShlOp
    | I32ShrSOp
    | I32ShrUOp
    | I32RotlOp
    | I32RotrOp
    | I64ShlOp
    | I64ShrSOp
    | I64ShrUOp
    | I64RotlOp
    | I64RotrOp => true
    _ => false
  }
}

///|
fn oi_is_i32_shift(op : BinaryOp) -> Bool {
  match op {
    I32ShlOp | I32ShrSOp | I32ShrUOp | I32RotlOp | I32RotrOp => true
    _ => false
  }
}

///|
fn oi_is_i64_shift(op : BinaryOp) -> Bool {
  match op {
    I64ShlOp | I64ShrSOp | I64ShrUOp | I64RotlOp | I64RotrOp => true
    _ => false
  }
}

///|
fn oi_binary_maybe_rewrite(op : BinaryOp) -> Bool {
  oi_is_shift(op) ||
  oi_is_relational(op) ||
  op == BinaryOp::i32_add() ||
  op == BinaryOp::i32_sub() ||
  op == BinaryOp::i32_mul() ||
  op == BinaryOp::i32_div_s() ||
  op == BinaryOp::i32_div_u() ||
  op == BinaryOp::i32_rem_s() ||
  op == BinaryOp::i32_rem_u() ||
  op == BinaryOp::i32_and() ||
  op == BinaryOp::i32_or() ||
  op == BinaryOp::i32_xor() ||
  op == BinaryOp::i64_add() ||
  op == BinaryOp::i64_sub() ||
  op == BinaryOp::i64_mul() ||
  op == BinaryOp::i64_div_s() ||
  op == BinaryOp::i64_div_u() ||
  op == BinaryOp::i64_rem_s() ||
  op == BinaryOp::i64_rem_u() ||
  op == BinaryOp::i64_and() ||
  op == BinaryOp::i64_or() ||
  op == BinaryOp::i64_xor() ||
  op == BinaryOp::f32_add() ||
  op == BinaryOp::f32_sub() ||
  op == BinaryOp::f32_mul() ||
  op == BinaryOp::f32_div() ||
  op == BinaryOp::f64_add() ||
  op == BinaryOp::f64_sub() ||
  op == BinaryOp::f64_mul() ||
  op == BinaryOp::f64_div()
}

///|
fn oi_binary_can_fold_equal_operands(op : BinaryOp) -> Bool {
  match op {
    I32SubOp
    | I32XorOp
    | I64SubOp
    | I64XorOp
    | I32AndOp
    | I32OrOp
    | I64AndOp
    | I64OrOp
    | I32EqOp
    | I32LeSOp
    | I32LeUOp
    | I32GeSOp
    | I32GeUOp
    | I64EqOp
    | I64LeSOp
    | I64LeUOp
    | I64GeSOp
    | I64GeUOp
    | I32NeOp
    | I32LtSOp
    | I32LtUOp
    | I32GtSOp
    | I32GtUOp
    | I64NeOp
    | I64LtSOp
    | I64LtUOp
    | I64GtSOp
    | I64GtUOp => true
    _ => false
  }
}

///|
fn oi_unary_maybe_rewrite(op : UnaryOp) -> Bool {
  op == UnaryOp::i32_eqz() ||
  op == UnaryOp::i64_eqz() ||
  op == UnaryOp::i32_wrap_i64() ||
  op == UnaryOp::i64_extend_i32s() ||
  op == UnaryOp::i64_extend_i32u() ||
  op == UnaryOp::i32_reinterpret_f32() ||
  op == UnaryOp::i64_reinterpret_f64() ||
  op == UnaryOp::f32_reinterpret_i32() ||
  op == UnaryOp::f64_reinterpret_i64() ||
  op == UnaryOp::f32_abs() ||
  op == UnaryOp::f32_neg() ||
  op == UnaryOp::f32_ceil() ||
  op == UnaryOp::f32_floor() ||
  op == UnaryOp::f32_trunc() ||
  op == UnaryOp::f32_nearest() ||
  op == UnaryOp::f64_abs() ||
  op == UnaryOp::f64_neg() ||
  op == UnaryOp::f64_ceil() ||
  op == UnaryOp::f64_floor() ||
  op == UnaryOp::f64_trunc() ||
  op == UnaryOp::f64_nearest() ||
  op == UnaryOp::i32_extend8s() ||
  op == UnaryOp::i32_extend16s() ||
  op == UnaryOp::i64_extend8s() ||
  op == UnaryOp::i64_extend16s() ||
  op == UnaryOp::i64_extend32s()
}

///|
fn oi_instr_is_rewrite_candidate(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBinary(op, _, _) => oi_binary_maybe_rewrite(op)
    TInstrKind::TUnary(op, _) => oi_unary_maybe_rewrite(op)
    TInstrKind::TSelect(_, _, _, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TGlobalSet(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TLoad(_, _, _)
    | TInstrKind::TStore(_, _, _, _)
    | TInstrKind::TMemoryCopy(_, _, _, _, _)
    | TInstrKind::TMemoryFill(_, _, _, _)
    | TInstrKind::TCallRef(_, _, _) => true
    _ => false
  }
}

///|
fn oi_rewrite_candidate_scan_budget(top_instrs : Int) -> Int {
  if top_instrs >= 10000 {
    20
  } else {
    10
  }
}

///|
fn oi_texpr_has_rewrite_candidate(body : TExpr, scan_budget : Int) -> Bool {
  let stack = body.instrs.copy()
  let mut scanned = 0
  while !stack.is_empty() && scanned < scan_budget {
    scanned += 1
    let curr = stack.pop().unwrap()
    if oi_instr_is_rewrite_candidate(curr) {
      return true
    }
    for child in eval_children(curr) {
      stack.push(child)
    }
  }
  false
}

///|
fn oi_negate_const(instr : TInstr) -> TInstr? {
  match instr.kind {
    TInstrKind::TI32Const(I32(v)) =>
      Some(TInstr::i32_const(I32(oi_wrap_i32(-v))))
    TInstrKind::TI64Const(I64(v)) =>
      Some(TInstr::i64_const(I64(oi_wrap_i64(-v))))
    TInstrKind::TF32Const(F32(v)) => Some(TInstr::f32_const(F32(-v)))
    TInstrKind::TF64Const(F64(v)) => Some(TInstr::f64_const(F64(-v)))
    _ => None
  }
}

///|
fn oi_make_binary(op : BinaryOp, left : TInstr, right : TInstr) -> TInstr {
  TInstr::binary(op, left, right)
}

///|
fn oi_optimize_boolean(
  cond : TInstr,
  _env : Env,
  _options : OptimizeOptions,
) -> TInstr {
  match cond.kind {
    TInstrKind::TUnary(
      I32EqzOp,
      { kind: TInstrKind::TUnary(I32EqzOp, value), .. }
    ) => value
    TInstrKind::TUnary(
      I32EqzOp,
      { kind: TInstrKind::TBinary(op, left, right), .. }
    ) =>
      match oi_invert_relational(op) {
        Some(inv) => TInstr::binary(inv, left, right)
        None => cond
      }
    TInstrKind::TUnary(I32EqzOp, value) =>
      match value.kind {
        TInstrKind::TI32Const(I32(v)) =>
          TInstr::i32_const(I32(if v == 0 { 1 } else { 0 }))
        _ => cond
      }
    TInstrKind::TBinary(
      I32NeOp,
      value,
      { kind: TInstrKind::TI32Const(I32(0)), .. }
    ) => value
    TInstrKind::TBinary(
      I32SubOp,
      { kind: TInstrKind::TI32Const(I32(0)), .. },
      value
    ) => value
    _ => cond
  }
}

///|
fn oi_optimize_with_const_right(
  op : BinaryOp,
  left : TInstr,
  right : TInstr,
  env : Env,
  options : OptimizeOptions,
) -> TInstr? {
  match (op, right) {
    (I32ShlOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32ShrSOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32ShrUOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32RotlOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32RotrOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I64ShlOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64ShrSOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64ShrUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64RotlOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64RotrOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I32OrOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32XorOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I64OrOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64XorOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I32AddOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I64AddOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I32SubOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I64SubOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) => Some(left)
    (I32AndOp, { kind: TInstrKind::TI32Const(I32(-1)), .. })
    | (I64AndOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) => Some(left)
    (I32AndOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64AndOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(0L)), env))
    (I32OrOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(-1)), env))
    (I64OrOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(-1L)), env))
    (I32EqOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(TInstr::unary(UnaryOp::i32_eqz(), left))
    (I64EqOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(TInstr::unary(UnaryOp::i64_eqz(), left))
    (I32MulOp, { kind: TInstrKind::TI32Const(I32(1)), .. })
    | (I64MulOp, { kind: TInstrKind::TI64Const(I64(1L)), .. })
    | (I32DivSOp, { kind: TInstrKind::TI32Const(I32(1)), .. })
    | (I32DivUOp, { kind: TInstrKind::TI32Const(I32(1)), .. })
    | (I64DivSOp, { kind: TInstrKind::TI64Const(I64(1L)), .. })
    | (I64DivUOp, { kind: TInstrKind::TI64Const(I64(1L)), .. }) => Some(left)
    (I32MulOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64MulOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(0L)), env))
    (I32RemSOp, { kind: TInstrKind::TI32Const(I32(1)), .. })
    | (I32RemUOp, { kind: TInstrKind::TI32Const(I32(1)), .. })
    | (I32RemSOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64RemSOp, { kind: TInstrKind::TI64Const(I64(1L)), .. })
    | (I64RemUOp, { kind: TInstrKind::TI64Const(I64(1L)), .. })
    | (I64RemSOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(0L)), env))
    (I32GeUOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I64GeUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I32LtUOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64LtUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I32LeUOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I64LeUOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I32GtUOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64GtUOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I32LtUOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_ne(), left, TInstr::i32_const(I32(-1))))
    (I64LtUOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(
        TInstr::binary(BinaryOp::i64_ne(), left, TInstr::i64_const(I64(-1L))),
      )
    (I32LeUOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_eq(), left, TInstr::i32_const(I32(0))))
    (I64LeUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(TInstr::binary(BinaryOp::i64_eq(), left, TInstr::i64_const(I64(0L))))
    (I32GtUOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_ne(), left, TInstr::i32_const(I32(0))))
    (I64GtUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(TInstr::binary(BinaryOp::i64_ne(), left, TInstr::i64_const(I64(0L))))
    (I32GeUOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_eq(), left, TInstr::i32_const(I32(-1))))
    (I64GeUOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(
        TInstr::binary(BinaryOp::i64_eq(), left, TInstr::i64_const(I64(-1L))),
      )
    (I32MulOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_sub(), TInstr::i32_const(I32(0)), left))
    (I64MulOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(
        TInstr::binary(BinaryOp::i64_sub(), TInstr::i64_const(I64(0L)), left),
      )
    (I32DivUOp, { kind: TInstrKind::TI32Const(I32(c)), .. }) =>
      if oi_is_power_of_2_i32(c) {
        Some(
          TInstr::binary(
            BinaryOp::i32_shr_u(),
            left,
            TInstr::i32_const(I32(oi_log2_i32(c))),
          ),
        )
      } else {
        None
      }
    (I64DivUOp, { kind: TInstrKind::TI64Const(I64(c)), .. }) =>
      if oi_is_power_of_2_i64(c) {
        Some(
          TInstr::binary(
            BinaryOp::i64_shr_u(),
            left,
            TInstr::i64_const(I64(oi_log2_i64(c))),
          ),
        )
      } else {
        None
      }
    (I32RemUOp, { kind: TInstrKind::TI32Const(I32(c)), .. }) =>
      if oi_is_power_of_2_i32(c) {
        Some(
          TInstr::binary(
            BinaryOp::i32_and(),
            left,
            TInstr::i32_const(I32(oi_wrap_i32(c - 1))),
          ),
        )
      } else {
        None
      }
    (I64RemUOp, { kind: TInstrKind::TI64Const(I64(c)), .. }) =>
      if oi_is_power_of_2_i64(c) {
        Some(
          TInstr::binary(
            BinaryOp::i64_and(),
            left,
            TInstr::i64_const(I64(oi_wrap_i64(c - 1L))),
          ),
        )
      } else {
        None
      }
    (I32MulOp, { kind: TInstrKind::TI32Const(I32(c)), .. }) =>
      if oi_is_power_of_2_i32(c) {
        Some(
          TInstr::binary(
            BinaryOp::i32_shl(),
            left,
            TInstr::i32_const(I32(oi_log2_i32(c))),
          ),
        )
      } else {
        None
      }
    (I64MulOp, { kind: TInstrKind::TI64Const(I64(c)), .. }) =>
      if oi_is_power_of_2_i64(c) {
        Some(
          TInstr::binary(
            BinaryOp::i64_shl(),
            left,
            TInstr::i64_const(I64(oi_log2_i64(c))),
          ),
        )
      } else {
        None
      }
    (F32MulOp, { kind: TInstrKind::TF32Const(F32(-1.0)), .. }) =>
      Some(TInstr::unary(UnaryOp::f32_neg(), left))
    (F64MulOp, { kind: TInstrKind::TF64Const(F64(-1.0)), .. }) =>
      Some(TInstr::unary(UnaryOp::f64_neg(), left))
    (F32AddOp, { kind: TInstrKind::TF32Const(F32(v)), .. }) =>
      if options.optimize_level > 0 && v == 0.0 {
        Some(left)
      } else {
        None
      }
    (F64AddOp, { kind: TInstrKind::TF64Const(F64(v)), .. }) =>
      if options.optimize_level > 0 && v == 0.0 {
        Some(left)
      } else {
        None
      }
    _ => None
  }
}

///|
fn oi_optimize_with_const_left(
  op : BinaryOp,
  left : TInstr,
  right : TInstr,
  _env : Env,
  cache : OIRewriteCache,
  allow_effect_queries : Bool,
) -> TInstr? {
  match (op, left) {
    (I32ShlOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32ShrSOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32ShrUOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I64ShlOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64ShrSOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64ShrUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      if allow_effect_queries && !oi_has_side_effects_cached(right, cache) {
        Some(left)
      } else {
        None
      }
    (I32ShrSOp, { kind: TInstrKind::TI32Const(I32(-1)), .. })
    | (I32RotlOp, { kind: TInstrKind::TI32Const(I32(-1)), .. })
    | (I32RotrOp, { kind: TInstrKind::TI32Const(I32(-1)), .. })
    | (I64ShrSOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. })
    | (I64RotlOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. })
    | (I64RotrOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      if allow_effect_queries && !oi_has_side_effects_cached(right, cache) {
        Some(left)
      } else {
        None
      }
    (I32SubOp, { kind: TInstrKind::TI32Const(I32(c1)), .. }) =>
      match right.kind {
        TInstrKind::TBinary(
          I32AddOp,
          x,
          { kind: TInstrKind::TI32Const(I32(c2)), .. }
        ) =>
          Some(
            TInstr::binary(
              BinaryOp::i32_sub(),
              TInstr::i32_const(I32(oi_wrap_i32(c1 - c2))),
              x,
            ),
          )
        TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(c2)), .. },
          x
        ) =>
          Some(
            TInstr::binary(
              BinaryOp::i32_add(),
              x,
              TInstr::i32_const(I32(oi_wrap_i32(c1 - c2))),
            ),
          )
        _ => None
      }
    (I64SubOp, { kind: TInstrKind::TI64Const(I64(c1)), .. }) =>
      match right.kind {
        TInstrKind::TBinary(
          I64AddOp,
          x,
          { kind: TInstrKind::TI64Const(I64(c2)), .. }
        ) =>
          Some(
            TInstr::binary(
              BinaryOp::i64_sub(),
              TInstr::i64_const(I64(oi_wrap_i64(c1 - c2))),
              x,
            ),
          )
        TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(c2)), .. },
          x
        ) =>
          Some(
            TInstr::binary(
              BinaryOp::i64_add(),
              x,
              TInstr::i64_const(I64(oi_wrap_i64(c1 - c2))),
            ),
          )
        _ => None
      }
    _ => None
  }
}

///|
fn oi_optimize_binary(
  op0 : BinaryOp,
  left0 : TInstr,
  right0 : TInstr,
  env : Env,
  options : OptimizeOptions,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
) -> TInstr? {
  let mut op = op0
  let mut left = left0
  let mut right = right0
  let mut changed = false
  if oi_is_symmetric(op) && oi_is_const(left) && !oi_is_const(right) {
    // Constants are always side-effect-free and cannot trap, so swapping is safe.
    let tmp = left
    left = right
    right = tmp
    changed = true
  }
  if oi_is_relational(op) && oi_is_const(left) && !oi_is_const(right) {
    match oi_reverse_relational(op) {
      Some(next) => {
        op = next
        let tmp = left
        left = right
        right = tmp
        changed = true
      }
      None => ()
    }
  }
  if (
      op == BinaryOp::i32_sub() ||
      op == BinaryOp::i64_sub() ||
      op == BinaryOp::f32_sub() ||
      op == BinaryOp::f64_sub()
    ) &&
    oi_is_const(right) {
    match oi_negate_const(right) {
      Some(neg_right) => {
        right = neg_right
        op = match op {
          I32SubOp => BinaryOp::i32_add()
          I64SubOp => BinaryOp::i64_add()
          F32SubOp => BinaryOp::f32_add()
          F64SubOp => BinaryOp::f64_add()
          _ => op
        }
        changed = true
      }
      None => ()
    }
  }
  if oi_is_shift(op) {
    match (op, right) {
      (op, { kind: TInstrKind::TI32Const(I32(v)), .. }) if oi_is_i32_shift(op) => {
        let eff = v & 31
        if eff != v {
          right = TInstr::i32_const(I32(eff))
          changed = true
        }
        if eff == 0 {
          return Some(left)
        }
      }
      (op, { kind: TInstrKind::TI64Const(I64(v)), .. }) if oi_is_i64_shift(op) => {
        let eff = v & 63L
        if eff != v {
          right = TInstr::i64_const(I64(eff))
          changed = true
        }
        if eff == 0L {
          return Some(left)
        }
      }
      (
        _,
        {
          kind: TInstrKind::TBinary(
            I32AndOp,
            y,
            { kind: TInstrKind::TI32Const(I32(mask)), .. }
          ),
          ..,
        },
      ) if oi_is_i32_shift(op) =>
        if (mask & 31) == 31 {
          right = y
          changed = true
        }
      (
        _,
        {
          kind: TInstrKind::TBinary(
            I64AndOp,
            y,
            { kind: TInstrKind::TI64Const(I64(mask)), .. }
          ),
          ..,
        },
      ) if oi_is_i64_shift(op) =>
        if (mask & 63L) == 63L {
          right = y
          changed = true
        }
      _ => ()
    }
  }
  if op == BinaryOp::i32_and() {
    match (left, right) {
      (
        { kind: TInstrKind::TUnary(I32EqzOp, x), .. },
        { kind: TInstrKind::TUnary(I32EqzOp, y), .. },
      ) =>
        return Some(
          TInstr::unary(
            UnaryOp::i32_eqz(),
            TInstr::binary(BinaryOp::i32_or(), x, y),
          ),
        )
      _ => ()
    }
  }
  match (op, left, right) {
    (F32AddOp, { kind: TInstrKind::TUnary(F32NegOp, x), .. }, y) =>
      if allow_expensive_eq && oi_can_reorder_cached(x, y, cache) {
        return Some(TInstr::binary(BinaryOp::f32_sub(), y, x))
      }
    (F64AddOp, { kind: TInstrKind::TUnary(F64NegOp, x), .. }, y) =>
      if allow_expensive_eq && oi_can_reorder_cached(x, y, cache) {
        return Some(TInstr::binary(BinaryOp::f64_sub(), y, x))
      }
    (F32AddOp, x, { kind: TInstrKind::TUnary(F32NegOp, y), .. }) =>
      return Some(TInstr::binary(BinaryOp::f32_sub(), x, y))
    (F64AddOp, x, { kind: TInstrKind::TUnary(F64NegOp, y), .. }) =>
      return Some(TInstr::binary(BinaryOp::f64_sub(), x, y))
    (F32SubOp, x, { kind: TInstrKind::TUnary(F32NegOp, y), .. }) =>
      return Some(TInstr::binary(BinaryOp::f32_add(), x, y))
    (F64SubOp, x, { kind: TInstrKind::TUnary(F64NegOp, y), .. }) =>
      return Some(TInstr::binary(BinaryOp::f64_add(), x, y))
    (
      I32MulOp,
      {
        kind: TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(0)), .. },
          x
        ),
        ..,
      },
      {
        kind: TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(0)), .. },
          y
        ),
        ..,
      },
    ) => return Some(TInstr::binary(BinaryOp::i32_mul(), x, y))
    (
      I64MulOp,
      {
        kind: TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(0L)), .. },
          x
        ),
        ..,
      },
      {
        kind: TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(0L)), .. },
          y
        ),
        ..,
      },
    ) => return Some(TInstr::binary(BinaryOp::i64_mul(), x, y))
    (
      I32MulOp,
      {
        kind: TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(0)), .. },
          x
        ),
        ..,
      },
      y,
    ) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i32_sub(),
            TInstr::i32_const(I32(0)),
            TInstr::binary(BinaryOp::i32_mul(), x, y),
          ),
        )
      }
    (
      I32MulOp,
      x,
      {
        kind: TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(0)), .. },
          y
        ),
        ..,
      },
    ) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i32_sub(),
            TInstr::i32_const(I32(0)),
            TInstr::binary(BinaryOp::i32_mul(), x, y),
          ),
        )
      }
    (
      I64MulOp,
      {
        kind: TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(0L)), .. },
          x
        ),
        ..,
      },
      y,
    ) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i64_sub(),
            TInstr::i64_const(I64(0L)),
            TInstr::binary(BinaryOp::i64_mul(), x, y),
          ),
        )
      }
    (
      I64MulOp,
      x,
      {
        kind: TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(0L)), .. },
          y
        ),
        ..,
      },
    ) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i64_sub(),
            TInstr::i64_const(I64(0L)),
            TInstr::binary(BinaryOp::i64_mul(), x, y),
          ),
        )
      }
    (
      F32MulOp,
      { kind: TInstrKind::TUnary(F32AbsOp, x), .. },
      { kind: TInstrKind::TUnary(F32AbsOp, y), .. },
    ) =>
      return Some(
        TInstr::unary(
          UnaryOp::f32_abs(),
          TInstr::binary(BinaryOp::f32_mul(), x, y),
        ),
      )
    (
      F64MulOp,
      { kind: TInstrKind::TUnary(F64AbsOp, x), .. },
      { kind: TInstrKind::TUnary(F64AbsOp, y), .. },
    ) =>
      return Some(
        TInstr::unary(
          UnaryOp::f64_abs(),
          TInstr::binary(BinaryOp::f64_mul(), x, y),
        ),
      )
    (
      F32DivOp,
      { kind: TInstrKind::TUnary(F32AbsOp, x), .. },
      { kind: TInstrKind::TUnary(F32AbsOp, y), .. },
    ) =>
      return Some(
        TInstr::unary(
          UnaryOp::f32_abs(),
          TInstr::binary(BinaryOp::f32_div(), x, y),
        ),
      )
    (
      F64DivOp,
      { kind: TInstrKind::TUnary(F64AbsOp, x), .. },
      { kind: TInstrKind::TUnary(F64AbsOp, y), .. },
    ) =>
      return Some(
        TInstr::unary(
          UnaryOp::f64_abs(),
          TInstr::binary(BinaryOp::f64_div(), x, y),
        ),
      )
    _ => ()
  }
  if oi_is_const(right) {
    match oi_optimize_with_const_right(op, left, right, env, options) {
      Some(rep) => return Some(rep)
      None => ()
    }
  }
  if oi_is_const(left) {
    match
      oi_optimize_with_const_left(
        op, left, right, env, cache, allow_expensive_eq,
      ) {
      Some(rep) => return Some(rep)
      None => ()
    }
  }
  match (op, left, right) {
    (
      I32EqOp,
      { kind: TInstrKind::TBinary(I32SubOp, x, y), .. },
      { kind: TInstrKind::TI32Const(I32(0)), .. },
    )
    | (
      I32NeOp,
      { kind: TInstrKind::TBinary(I32SubOp, x, y), .. },
      { kind: TInstrKind::TI32Const(I32(0)), .. },
    )
    | (
      I32GtUOp,
      { kind: TInstrKind::TBinary(I32SubOp, x, y), .. },
      { kind: TInstrKind::TI32Const(I32(0)), .. },
    )
    | (
      I32LeUOp,
      { kind: TInstrKind::TBinary(I32SubOp, x, y), .. },
      { kind: TInstrKind::TI32Const(I32(0)), .. },
    ) => {
      let new_op = match op {
        I32GtUOp => BinaryOp::i32_ne()
        I32LeUOp => BinaryOp::i32_eq()
        _ => op
      }
      return Some(TInstr::binary(new_op, x, y))
    }
    (
      I64EqOp,
      { kind: TInstrKind::TBinary(I64SubOp, x, y), .. },
      { kind: TInstrKind::TI64Const(I64(0L)), .. },
    )
    | (
      I64NeOp,
      { kind: TInstrKind::TBinary(I64SubOp, x, y), .. },
      { kind: TInstrKind::TI64Const(I64(0L)), .. },
    )
    | (
      I64GtUOp,
      { kind: TInstrKind::TBinary(I64SubOp, x, y), .. },
      { kind: TInstrKind::TI64Const(I64(0L)), .. },
    )
    | (
      I64LeUOp,
      { kind: TInstrKind::TBinary(I64SubOp, x, y), .. },
      { kind: TInstrKind::TI64Const(I64(0L)), .. },
    ) => {
      let new_op = match op {
        I64GtUOp => BinaryOp::i64_ne()
        I64LeUOp => BinaryOp::i64_eq()
        _ => op
      }
      return Some(TInstr::binary(new_op, x, y))
    }
    _ => ()
  }
  if oi_binary_can_fold_equal_operands(op) &&
    oi_instr_equal_for_fold(left, right, cache, 128, allow_expensive_eq) &&
    !oi_has_side_effects_cached(left, cache) {
    match op {
      I32SubOp | I32XorOp => return Some(TInstr::i32_const(I32(0)))
      I64SubOp | I64XorOp => return Some(TInstr::i64_const(I64(0L)))
      I32AndOp | I32OrOp | I64AndOp | I64OrOp => return Some(left)
      I32EqOp
      | I32LeSOp
      | I32LeUOp
      | I32GeSOp
      | I32GeUOp
      | I64EqOp
      | I64LeSOp
      | I64LeUOp
      | I64GeSOp
      | I64GeUOp => return Some(TInstr::i32_const(I32(1)))
      I32NeOp
      | I32LtSOp
      | I32LtUOp
      | I32GtSOp
      | I32GtUOp
      | I64NeOp
      | I64LtSOp
      | I64LtUOp
      | I64GtSOp
      | I64GtUOp => return Some(TInstr::i32_const(I32(0)))
      _ => ()
    }
  }
  if changed {
    Some(oi_make_binary(op, left, right))
  } else {
    None
  }
}

///|
fn oi_optimize_unary(
  op : UnaryOp,
  value : TInstr,
  _env : Env,
  options : OptimizeOptions,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
) -> TInstr? {
  match (op, value) {
    (I32EqzOp, { kind: TInstrKind::TBinary(I32SubOp, x, y), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_eq(), x, y))
    (I64EqzOp, { kind: TInstrKind::TBinary(I64SubOp, x, y), .. }) =>
      Some(TInstr::binary(BinaryOp::i64_eq(), x, y))
    (
      I32EqzOp,
      {
        kind: TInstrKind::TBinary(
          I32AddOp,
          x,
          { kind: TInstrKind::TI32Const(I32(c)), .. }
        ),
        ..,
      },
    ) =>
      Some(
        TInstr::binary(
          BinaryOp::i32_eq(),
          x,
          TInstr::i32_const(I32(oi_wrap_i32(-c))),
        ),
      )
    (
      I64EqzOp,
      {
        kind: TInstrKind::TBinary(
          I64AddOp,
          x,
          { kind: TInstrKind::TI64Const(I64(c)), .. }
        ),
        ..,
      },
    ) =>
      Some(
        TInstr::binary(
          BinaryOp::i64_eq(),
          x,
          TInstr::i64_const(I64(oi_wrap_i64(-c))),
        ),
      )
    (I32EqzOp, { kind: TInstrKind::TUnary(I32EqzOp, x), .. }) =>
      if options.shrink_level == 0 {
        Some(TInstr::binary(BinaryOp::i32_ne(), x, TInstr::i32_const(I32(0))))
      } else {
        None
      }
    (I32WrapI64Op, { kind: TInstrKind::TUnary(I64ExtendI32SOp, x), .. })
    | (I32WrapI64Op, { kind: TInstrKind::TUnary(I64ExtendI32UOp, x), .. }) =>
      Some(x)
    (I64ExtendI32SOp, { kind: TInstrKind::TUnary(I32WrapI64Op, x), .. }) =>
      Some(TInstr::unary(UnaryOp::i64_extend32s(), x))
    (
      I32ReinterpretF32Op,
      { kind: TInstrKind::TUnary(F32ReinterpretI32Op, x), .. },
    )
    | (
      I64ReinterpretF64Op,
      { kind: TInstrKind::TUnary(F64ReinterpretI64Op, x), .. },
    )
    | (
      F32ReinterpretI32Op,
      { kind: TInstrKind::TUnary(I32ReinterpretF32Op, x), .. },
    )
    | (
      F64ReinterpretI64Op,
      { kind: TInstrKind::TUnary(I64ReinterpretF64Op, x), .. },
    ) => Some(x)
    (
      I32ReinterpretF32Op,
      { kind: TInstrKind::TLoad(F32LoadOp, memarg, ptr), .. },
    ) => Some(TInstr::load(LoadOp::i32_load(), memarg, ptr))
    (
      F32ReinterpretI32Op,
      { kind: TInstrKind::TLoad(I32LoadOp, memarg, ptr), .. },
    ) => Some(TInstr::load(LoadOp::f32_load(), memarg, ptr))
    (
      I64ReinterpretF64Op,
      { kind: TInstrKind::TLoad(F64LoadOp, memarg, ptr), .. },
    ) => Some(TInstr::load(LoadOp::i64_load(), memarg, ptr))
    (
      F64ReinterpretI64Op,
      { kind: TInstrKind::TLoad(I64LoadOp, memarg, ptr), .. },
    ) => Some(TInstr::load(LoadOp::f64_load(), memarg, ptr))
    (F32AbsOp, { kind: TInstrKind::TUnary(F32NegOp, x), .. }) =>
      Some(TInstr::unary(UnaryOp::f32_abs(), x))
    (F64AbsOp, { kind: TInstrKind::TUnary(F64NegOp, x), .. }) =>
      Some(TInstr::unary(UnaryOp::f64_abs(), x))
    (F32AbsOp, { kind: TInstrKind::TBinary(F32MulOp, x, y), .. }) if allow_expensive_eq &&
      oi_instr_eq_budgeted(x, y, cache, 128) =>
      Some(TInstr::binary(BinaryOp::f32_mul(), x, y))
    (F64AbsOp, { kind: TInstrKind::TBinary(F64MulOp, x, y), .. }) if allow_expensive_eq &&
      oi_instr_eq_budgeted(x, y, cache, 128) =>
      Some(TInstr::binary(BinaryOp::f64_mul(), x, y))
    (F32AbsOp, { kind: TInstrKind::TBinary(F32DivOp, x, y), .. }) if allow_expensive_eq &&
      oi_instr_eq_budgeted(x, y, cache, 128) =>
      Some(TInstr::binary(BinaryOp::f32_div(), x, y))
    (F64AbsOp, { kind: TInstrKind::TBinary(F64DivOp, x, y), .. }) if allow_expensive_eq &&
      oi_instr_eq_budgeted(x, y, cache, 128) =>
      Some(TInstr::binary(BinaryOp::f64_div(), x, y))
    (_, { kind: TInstrKind::TUnary(inner_op, x), .. }) =>
      if inner_op == op {
        match op {
          F32AbsOp
          | F32CeilOp
          | F32FloorOp
          | F32TruncOp
          | F32NearestOp
          | F64AbsOp
          | F64CeilOp
          | F64FloorOp
          | F64TruncOp
          | F64NearestOp
          | I32Extend8SOp
          | I32Extend16SOp
          | I64Extend8SOp
          | I64Extend16SOp
          | I64Extend32SOp => Some(TInstr::unary(op, x))
          F32NegOp | F64NegOp => Some(x)
          _ => None
        }
      } else {
        None
      }
    (I32EqzOp, { kind: TInstrKind::TBinary(bin_op, x, y), .. }) =>
      match oi_invert_relational(bin_op) {
        Some(inv) => Some(TInstr::binary(inv, x, y))
        None => None
      }
    _ => None
  }
}

///|
fn oi_memory_is_64(mod : Module, memarg : MemArg) -> Bool {
  let MemArg(_, mem_idx, _) = memarg
  match mem_idx {
    Some(MemIdx(raw)) =>
      match mod.mem_sec {
        Some(MemSec(memories)) =>
          match memories.get(raw.reinterpret_as_int()) {
            Some(MemType(I64Limits(_, _))) => true
            _ => false
          }
        None => false
      }
    None =>
      match mod.mem_sec {
        Some(MemSec(memories)) =>
          match memories.get(0) {
            Some(MemType(I64Limits(_, _))) => true
            _ => false
          }
        None => false
      }
  }
}

///|
fn oi_fold_const_ptr_offset(
  ptr : TInstr,
  memarg : MemArg,
  mod : Module,
) -> (TInstr, MemArg) {
  let MemArg(align, mem, U64(offset)) = memarg
  if offset == 0UL {
    return (ptr, memarg)
  }
  match ptr.kind {
    TInstrKind::TI32Const(I32(v)) if !oi_memory_is_64(mod, memarg) => {
      let value64 = v.reinterpret_as_uint().to_uint64()
      let max32 = 0x7fffffffUL
      if value64 <= max32 && offset <= max32 && value64 + offset <= max32 {
        let total = value64 + offset
        let out = total.to_uint().reinterpret_as_int()
        (TInstr::i32_const(I32(out)), MemArg::new(align, mem, U64(0UL)))
      } else {
        (ptr, memarg)
      }
    }
    TInstrKind::TI64Const(I64(v)) if oi_memory_is_64(mod, memarg) => {
      let value64 = v.reinterpret_as_uint64()
      let total = value64 + offset
      if total >= value64 {
        (
          TInstr::i64_const(I64(total.reinterpret_as_int64())),
          MemArg::new(align, mem, U64(0UL)),
        )
      } else {
        (ptr, memarg)
      }
    }
    _ => (ptr, memarg)
  }
}

///|
fn oi_store_bytes(op : StoreOp) -> Int {
  match op {
    I32Store8Op | I64Store8Op | I32AtomicStore8Op | I64AtomicStore8Op => 1
    I32Store16Op | I64Store16Op | I32AtomicStore16Op | I64AtomicStore16Op => 2
    I32StoreOp
    | F32StoreOp
    | I64Store32Op
    | I32AtomicStoreOp
    | I64AtomicStore32Op => 4
    I64StoreOp | F64StoreOp | I64AtomicStoreOp => 8
    V128StoreOp => 16
  }
}

///|
fn oi_store_wrap_upgrade(op : StoreOp) -> StoreOp? {
  match op {
    I32StoreOp => Some(StoreOp::i64_store32())
    I32Store16Op => Some(StoreOp::i64_store16())
    I32Store8Op => Some(StoreOp::i64_store8())
    _ => None
  }
}

///|
fn oi_reinterpret_store(op : StoreOp, value : TInstr) -> (StoreOp, TInstr)? {
  match (op, value) {
    (F32StoreOp, { kind: TInstrKind::TUnary(F32ReinterpretI32Op, x), .. }) =>
      Some((StoreOp::i32_store(), x))
    (I32StoreOp, { kind: TInstrKind::TUnary(I32ReinterpretF32Op, x), .. }) =>
      Some((StoreOp::f32_store(), x))
    (F64StoreOp, { kind: TInstrKind::TUnary(F64ReinterpretI64Op, x), .. }) =>
      Some((StoreOp::i64_store(), x))
    (I64StoreOp, { kind: TInstrKind::TUnary(I64ReinterpretF64Op, x), .. }) =>
      Some((StoreOp::f64_store(), x))
    _ => None
  }
}

///|
fn oi_optimize_store_value(op : StoreOp, value : TInstr) -> (TInstr, Bool) {
  let bytes = oi_store_bytes(op)
  let mut changed = false
  let value = match value.kind {
    TInstrKind::TI32Const(I32(v)) if bytes < 4 => {
      let mask = match bytes {
        1 => 0xff
        2 => 0xffff
        _ => 0xffffffff
      }
      let next = oi_wrap_i32(v & mask)
      if next != v {
        changed = true
      }
      TInstr::i32_const(I32(next))
    }
    TInstrKind::TI64Const(I64(v)) if bytes < 8 => {
      let mask = match bytes {
        1 => 0xffL
        2 => 0xffffL
        4 => 0xffffffffL
        _ => -1L
      }
      let next = oi_wrap_i64(v & mask)
      if next != v {
        changed = true
      }
      TInstr::i64_const(I64(next))
    }
    _ => value
  }
  match value.kind {
    TInstrKind::TBinary(
      I32AndOp,
      x,
      { kind: TInstrKind::TI32Const(I32(mask)), .. }
    ) =>
      if (bytes == 1 && mask == 0xff) || (bytes == 2 && mask == 0xffff) {
        (x, true)
      } else {
        (value, changed)
      }
    TInstrKind::TBinary(
      I64AndOp,
      x,
      { kind: TInstrKind::TI64Const(I64(mask)), .. }
    ) =>
      if (bytes == 1 && mask == 0xffL) ||
        (bytes == 2 && mask == 0xffffL) ||
        (bytes == 4 && mask == 0xffffffffL) {
        (x, true)
      } else {
        (value, changed)
      }
    _ => (value, changed)
  }
}

///|
fn oi_optimize_memory_copy(
  dst_mem : MemIdx,
  src_mem : MemIdx,
  dest : TInstr,
  source : TInstr,
  size : TInstr,
  env : Env,
) -> TInstr? {
  match size.kind {
    TInstrKind::TI32Const(I32(0)) =>
      Some(
        TInstr::block(
          BlockType::void_(),
          TExpr::new([oi_instr_stmt(dest, env), oi_instr_stmt(source, env)]),
        ),
      )
    TInstrKind::TI32Const(I32(bytes)) =>
      match bytes {
        1 => {
          let load_memarg = MemArg::new(U32(1), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(1), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i32_store8(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i32_load8u(), load_memarg, source),
            ),
          )
        }
        2 => {
          let load_memarg = MemArg::new(U32(2), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(2), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i32_store16(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i32_load16u(), load_memarg, source),
            ),
          )
        }
        4 => {
          let load_memarg = MemArg::new(U32(4), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(4), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i32_store(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i32_load(), load_memarg, source),
            ),
          )
        }
        8 => {
          let load_memarg = MemArg::new(U32(8), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(8), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i64_store(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i64_load(), load_memarg, source),
            ),
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
fn oi_optimize_memory_fill(
  mem_idx : MemIdx,
  dest : TInstr,
  value : TInstr,
  size : TInstr,
  env : Env,
) -> TInstr? {
  match size.kind {
    TInstrKind::TI32Const(I32(0)) =>
      Some(
        TInstr::block(
          BlockType::void_(),
          TExpr::new([oi_instr_stmt(dest, env), oi_instr_stmt(value, env)]),
        ),
      )
    TInstrKind::TI32Const(I32(1)) =>
      Some(
        TInstr::store(
          StoreOp::i32_store8(),
          MemArg::new(U32(1), Some(mem_idx), U64(0UL)),
          dest,
          value,
        ),
      )
    TInstrKind::TI32Const(I32(bytes)) =>
      match (bytes, value) {
        (1, { kind: TInstrKind::TI32Const(I32(v)), .. }) =>
          Some(
            TInstr::store(
              StoreOp::i32_store8(),
              MemArg::new(U32(1), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i32_const(I32(v & 0xff)),
            ),
          )
        (2, { kind: TInstrKind::TI32Const(I32(v)), .. }) => {
          let x = v & 0xff
          Some(
            TInstr::store(
              StoreOp::i32_store16(),
              MemArg::new(U32(2), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i32_const(I32(oi_wrap_i32(x * 0x0101))),
            ),
          )
        }
        (4, { kind: TInstrKind::TI32Const(I32(v)), .. }) => {
          let x = v & 0xff
          Some(
            TInstr::store(
              StoreOp::i32_store(),
              MemArg::new(U32(4), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i32_const(I32(oi_wrap_i32(x * 0x01010101))),
            ),
          )
        }
        (8, { kind: TInstrKind::TI32Const(I32(v)), .. }) => {
          let x = (v & 0xff).to_int64()
          Some(
            TInstr::store(
              StoreOp::i64_store(),
              MemArg::new(U32(8), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i64_const(I64(oi_wrap_i64(x * 0x0101010101010101L))),
            ),
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
fn oi_optimize_select(
  _types : Array[ValType]?,
  cond : TInstr,
  if_true : TInstr,
  if_false : TInstr,
  env : Env,
  options : OptimizeOptions,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
) -> TInstr? {
  let cond = oi_optimize_boolean(cond, env, options)
  match cond.kind {
    TInstrKind::TI32Const(I32(v)) =>
      if v == 0 {
        Some(oi_seq([oi_instr_stmt(if_true, env)], if_false, env))
      } else {
        Some(oi_seq([oi_instr_stmt(if_false, env)], if_true, env))
      }
    _ =>
      if allow_expensive_eq &&
        oi_instr_equal_for_fold(
          if_true, if_false, cache, 128, allow_expensive_eq,
        ) {
        if oi_has_side_effects_cached(cond, cache) {
          Some(oi_seq([oi_instr_stmt(cond, env)], if_true, env))
        } else {
          Some(if_true)
        }
      } else {
        let max_bits = match (oi_const_i32(if_true), oi_const_i32(if_false)) {
          (Some(1), Some(0)) => true
          _ => false
        }
        if max_bits {
          Some(cond)
        } else {
          None
        }
      }
  }
}

///|
fn oi_optimize_if(
  bt : BlockType,
  cond : TInstr,
  then_ : TExpr,
  else_ : TExpr?,
  env : Env,
  options : OptimizeOptions,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
) -> TInstr? {
  let next_cond = oi_optimize_boolean(cond, env, options)
  match else_ {
    Some(else_expr) =>
      match next_cond.kind {
        TInstrKind::TUnary(I32EqzOp, value) =>
          Some(TInstr::if_(bt, value, else_expr, Some(then_)))
        _ =>
          if allow_expensive_eq &&
            then_.instrs.length() == else_expr.instrs.length() &&
            oi_texpr_equal_for_fold(
              then_, else_expr, cache, 256, allow_expensive_eq,
            ) {
            if oi_has_side_effects_cached(next_cond, cache) {
              let list = [oi_instr_stmt(next_cond, env)]
              for instr in then_.instrs {
                list.push(instr)
              }
              Some(TInstr::block(bt, TExpr::new(list)))
            } else {
              Some(TInstr::block(bt, then_))
            }
          } else if oi_instr_eq_for_change(
              next_cond, cond, cache, allow_expensive_eq,
            ) {
            None
          } else {
            Some(TInstr::if_(bt, next_cond, then_, Some(else_expr)))
          }
      }
    None =>
      if oi_instr_eq_for_change(next_cond, cond, cache, allow_expensive_eq) {
        None
      } else {
        Some(TInstr::if_(bt, next_cond, then_, None))
      }
  }
}

///|
fn oi_optimize_once(
  instr : TInstr,
  env : Env,
  options : OptimizeOptions,
  mod : Module,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBinary(op, left, right) =>
      match
        oi_optimize_binary(
          op, left, right, env, options, cache, allow_expensive_eq,
        ) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TUnary(op, value) =>
      match
        oi_optimize_unary(op, value, env, options, cache, allow_expensive_eq) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TSelect(types, cond, if_true, if_false) =>
      match
        oi_optimize_select(
          types, cond, if_true, if_false, env, options, cache, allow_expensive_eq,
        ) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TIf(bt, cond, then_, else_) =>
      match
        oi_optimize_if(
          bt, cond, then_, else_, env, options, cache, allow_expensive_eq,
        ) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TGlobalSet(idx, { kind: TInstrKind::TGlobalGet(get_idx), .. }) if idx ==
      get_idx => (TInstr::nop(), true)
    TInstrKind::TBrIf(label, cond, values) => {
      let next_cond = oi_optimize_boolean(cond, env, options)
      if oi_instr_eq_for_change(next_cond, cond, cache, allow_expensive_eq) {
        (instr, false)
      } else {
        (TInstr::br_if(label, next_cond, values), true)
      }
    }
    TInstrKind::TLoad(op, memarg, ptr) => {
      let (next_ptr, next_memarg) = oi_fold_const_ptr_offset(ptr, memarg, mod)
      if next_ptr == ptr && next_memarg == memarg {
        (instr, false)
      } else {
        (TInstr::load(op, next_memarg, next_ptr), true)
      }
    }
    TInstrKind::TStore(op, memarg, ptr, value) => {
      let (next_ptr, next_memarg) = oi_fold_const_ptr_offset(ptr, memarg, mod)
      let mut changed = next_ptr != ptr || next_memarg != memarg
      let mut next_op = op
      let (store_value, value_changed) = oi_optimize_store_value(op, value)
      let mut next_value = store_value
      if value_changed {
        changed = true
      }
      match next_value.kind {
        TInstrKind::TUnary(I32WrapI64Op, inner) =>
          match oi_store_wrap_upgrade(next_op) {
            Some(upgraded) => {
              next_op = upgraded
              next_value = inner
              changed = true
            }
            None => ()
          }
        _ => ()
      }
      match oi_reinterpret_store(next_op, next_value) {
        Some((rewritten_op, rewritten_value)) => {
          next_op = rewritten_op
          next_value = rewritten_value
          changed = true
        }
        None => ()
      }
      if changed {
        (TInstr::store(next_op, next_memarg, next_ptr, next_value), true)
      } else {
        (instr, false)
      }
    }
    TInstrKind::TMemoryCopy(dst_mem, src_mem, dest, source, size) =>
      match oi_optimize_memory_copy(dst_mem, src_mem, dest, source, size, env) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TMemoryFill(mem_idx, dest, value, size) =>
      match oi_optimize_memory_fill(mem_idx, dest, value, size, env) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TCallRef(type_idx, args, target) =>
      match target.kind {
        TInstrKind::TRefFunc(func_idx) => (TInstr::call(func_idx, args), true)
        TInstrKind::TTableGet(table_idx, index) =>
          (TInstr::call_indirect(type_idx, table_idx, args, index), true)
        _ => (instr, false)
      }
    _ => (instr, false)
  }
}

///|
fn oi_optimize_fixpoint(
  instr : TInstr,
  env : Env,
  options : OptimizeOptions,
  mod : Module,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
) -> (TInstr, Int, Bool) {
  let mut curr = instr
  let mut rounds = 0
  let mut changed = false
  while rounds < 2 {
    rounds += 1
    let (next, step_changed) = oi_optimize_once(
      curr, env, options, mod, cache, allow_expensive_eq,
    )
    if !step_changed {
      break
    }
    changed = true
    curr = next
    if !oi_instr_is_rewrite_candidate(curr) {
      break
    }
  }
  (curr, rounds, changed)
}

///|
priv struct OITransformStats {
  top_instrs : Int
  skipped_no_candidates : Bool
  did_change : Bool
  visited_instrs : Int
  candidate_instrs : Int
  rewritten_instrs : Int
  max_rounds : Int
}

///|
fn oi_transform_stats_new(top_instrs : Int) -> OITransformStats {
  OITransformStats::{
    top_instrs,
    skipped_no_candidates: false,
    did_change: false,
    visited_instrs: 0,
    candidate_instrs: 0,
    rewritten_instrs: 0,
    max_rounds: 0,
  }
}

///|
fn oi_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn oi_trace_now_ms() -> UInt64 {
  @env.now()
}

///|
fn oi_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  let end_ms = oi_trace_now_ms()
  if end_ms >= start_ms {
    end_ms - start_ms
  } else {
    0UL
  }
}

///|
fn optimize_instructions_on_func(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
) -> (Func, OITransformStats) {
  match func {
    TFunc(locals, body) => {
      let top_instrs = body.instrs.length()
      if top_instrs > 30000 {
        return (
          func,
          OITransformStats::{
            top_instrs,
            skipped_no_candidates: true,
            did_change: false,
            visited_instrs: 0,
            candidate_instrs: 0,
            rewritten_instrs: 0,
            max_rounds: 0,
          },
        )
      }
      let scan_budget = oi_rewrite_candidate_scan_budget(top_instrs)
      if !oi_texpr_has_rewrite_candidate(body, scan_budget) {
        return (
          func,
          OITransformStats::{
            top_instrs,
            skipped_no_candidates: true,
            did_change: false,
            visited_instrs: 0,
            candidate_instrs: 0,
            rewritten_instrs: 0,
            max_rounds: 0,
          },
        )
      }
      let env = Env::new().with_module(mod).with_locals(locals)
      let cache = oi_rewrite_cache_new()
      oi_precompute_cached_summaries(body, cache)
      let mut visited_instrs = 0
      let mut candidate_instrs = 0
      let mut rewritten_instrs = 0
      let mut max_rounds = 0
      let mut did_change = false
      let visited_instr_budget = if top_instrs / 2 < 2000 {
        2000
      } else if top_instrs / 2 < 80000 {
        top_instrs / 2
      } else {
        80000
      }
      let candidate_size_budget = if top_instrs > 8000 { 64 } else { 256 }
      let allow_expensive_eq = top_instrs <= 4000
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        curr,
      ) {
        if visited_instrs >= visited_instr_budget {
          // Cap work on very large functions: leave the remaining subtree
          // unchanged and skip descending further.
          return change((), curr)
        }
        if eval_children(curr).is_empty() {
          visited_instrs += 1
          if !oi_instr_is_rewrite_candidate(curr) {
            // Returning `unchanged()` here would trigger
            // `walk_tinstruction_default` and traverse this subtree again.
            return change((), curr)
          }
          if allow_expensive_eq &&
            !oi_instr_within_eq_budget(curr, candidate_size_budget, cache) {
            return change((), curr)
          }
          candidate_instrs += 1
          let (rewritten, rounds, rewritten_here) = oi_optimize_fixpoint(
            curr, env, options, mod, cache, allow_expensive_eq,
          )
          if rounds > max_rounds {
            max_rounds = rounds
          }
          if rewritten_here {
            rewritten_instrs += 1
            did_change = true
          }
          return change((), rewritten)
        }
        let walked = match self.walk_tinstruction_default((), curr) {
          Ok(Some((_, updated))) => updated
          Ok(None) => curr
          Err(e) => return Err(e)
        }
        visited_instrs += 1
        if !oi_instr_is_rewrite_candidate(walked) {
          // Returning `unchanged()` here would trigger
          // `walk_tinstruction_default` and traverse this subtree again.
          return change((), walked)
        }
        if allow_expensive_eq &&
          !oi_instr_within_eq_budget(walked, candidate_size_budget, cache) {
          return change((), walked)
        }
        candidate_instrs += 1
        let (rewritten, rounds, rewritten_here) = oi_optimize_fixpoint(
          walked, env, options, mod, cache, allow_expensive_eq,
        )
        if rounds > max_rounds {
          max_rounds = rounds
        }
        if rewritten_here {
          rewritten_instrs += 1
          did_change = true
        }
        change((), rewritten)
      })
      let new_body = match walker.walk_texpr((), body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(_) => body
      }
      (
        if did_change {
          Func::t_func(locals, new_body)
        } else {
          func
        },
        OITransformStats::{
          top_instrs,
          skipped_no_candidates: false,
          did_change,
          visited_instrs,
          candidate_instrs,
          rewritten_instrs,
          max_rounds,
        },
      )
    }
    _ => (func, oi_transform_stats_new(0))
  }
}

///|
fn optimize_instructions_ir_pass(
  mod : Module,
  options : OptimizeOptions,
  trace? : (String) -> Unit = oi_trace_noop,
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext] {
  let mut seen_funcs = 0
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    seen_funcs += 1
    let ordinal = seen_funcs
    let log_func = trace_all_funcs || ordinal <= 5 || ordinal % 50 == 0
    let top_instrs = match func {
      TFunc(_, body) => body.instrs.length()
      _ => 0
    }
    if log_func {
      trace("func[\{ordinal}] start top_instrs=\{top_instrs}")
    }
    let start_ms = oi_trace_now_ms()
    let (next, stats) = optimize_instructions_on_func(func, mod, options)
    let elapsed = oi_trace_elapsed_ms(start_ms)
    let log_heavy_func = stats.visited_instrs >= 20000 ||
      stats.candidate_instrs >= 5000
    if log_func || log_heavy_func || elapsed >= 1000 {
      trace(
        "func[\{ordinal}] done elapsed_ms=\{elapsed} changed=\{stats.did_change} skipped=\{stats.skipped_no_candidates} top_instrs=\{stats.top_instrs} visited=\{stats.visited_instrs} candidates=\{stats.candidate_instrs} rewritten=\{stats.rewritten_instrs} max_rounds=\{stats.max_rounds}",
      )
    }
    // Returning `unchanged()` here would trigger `walk_func_default`,
    // causing a second traversal of this function.
    change(ctx, next)
  })
}

///|
fn oi_run_func(
  body : Array[TInstr],
  locals? : Array[ValType] = [],
  options? : OptimizeOptions = OptimizeOptions::new(),
  with_memory? : Bool = false,
) -> TExpr {
  let mut mod_ = Module::new().with_code_sec(
    CodeSec::new([Func::t_func(locals, TExpr::new(body))]),
  )
  if with_memory {
    mod_ = mod_.with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
  }
  let out = optimize_module_with_options(
    mod_,
    [ModulePass::OptimizeInstructions],
    options,
  ).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, out_body)])) => out_body
    _ => abort("expected one transformed function")
  }
}

///|
test "optimize instructions eqz(sub) to eq" {
  let body = oi_run_func(
    [
      TInstr::unary(
        UnaryOp::i32_eqz(),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32EqOp,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. },
            { kind: TInstrKind::TLocalGet(LocalIdx(j)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => {
      assert_eq(i.reinterpret_as_int(), 0)
      assert_eq(j.reinterpret_as_int(), 1)
    }
    _ => fail("expected i32.eq")
  }
}

///|
test "optimize instructions eqz(add const) to eq neg const" {
  let body = oi_run_func(
    [
      TInstr::unary(
        UnaryOp::i32_eqz(),
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(5)),
        ),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32EqOp,
            { kind: TInstrKind::TLocalGet(_), .. },
            { kind: TInstrKind::TI32Const(I32(v)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => assert_eq(v, -5)
    _ => fail("expected i32.eq with negated constant")
  }
}

///|
test "optimize instructions de-morgan eqz and" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_and(),
        TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
        TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(1))),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TUnary(
            I32EqzOp,
            { kind: TInstrKind::TBinary(I32OrOp, _, _), .. }
          ),
          ..,
        },
      ],
      ..,
    } => ()
    _ => fail("expected eqz(or)")
  }
}

///|
test "optimize instructions masks shift constants and removes zero shifts" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_shl(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(32)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [{ kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }], .. } =>
      assert_eq(i.reinterpret_as_int(), 0)
    _ => fail("expected shift-by-32 to collapse to lhs")
  }
}

///|
test "optimize instructions removes rhs mask in shifts" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_shl(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::binary(
          BinaryOp::i32_and(),
          TInstr::local_get(LocalIdx::new(1)),
          TInstr::i32_const(I32(31)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32ShlOp,
            _,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => assert_eq(i.reinterpret_as_int(), 1)
    _ => fail("expected shift rhs to be simplified to local.get")
  }
}

///|
test "optimize instructions float add neg rhs to sub" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::f32_add(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::unary(UnaryOp::f32_neg(), TInstr::local_get(LocalIdx::new(1))),
      ),
    ],
    locals=[ValType::f32(), ValType::f32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            F32SubOp,
            _,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => assert_eq(i.reinterpret_as_int(), 1)
    _ => fail("expected f32.sub")
  }
}

///|
test "optimize instructions int neg multiply patterns" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::i32_const(I32(0)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::i32_const(I32(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32MulOp,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. },
            { kind: TInstrKind::TLocalGet(LocalIdx(j)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => {
      assert_eq(i.reinterpret_as_int(), 0)
      assert_eq(j.reinterpret_as_int(), 1)
    }
    _ => fail("expected -x * -y => x * y")
  }
}

///|
test "optimize instructions unsigned compare constants" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_ge_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::binary(
        BinaryOp::i32_lt_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [_, _], .. } => ()
    _ => fail("expected two instructions")
  }
  match body {
    { instrs: [first, second], .. } => {
      match first.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TDrop({ kind: TInstrKind::TLocalGet(_), .. }),
                ..,
              },
              { kind: TInstrKind::TI32Const(I32(v)), .. },
            ],
            ..,
          }
        ) => assert_eq(v, 1)
        _ => fail("expected ge_u 0 => 1 preserving lhs")
      }
      match second.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TDrop({ kind: TInstrKind::TLocalGet(_), .. }),
                ..,
              },
              { kind: TInstrKind::TI32Const(I32(v)), .. },
            ],
            ..,
          }
        ) => assert_eq(v, 0)
        _ => fail("expected lt_u 0 => 0 preserving lhs")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions power-of-two integer arithmetic" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(8)),
      ),
      TInstr::binary(
        BinaryOp::i32_div_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(8)),
      ),
      TInstr::binary(
        BinaryOp::i32_rem_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(8)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [mul_i, div_i, rem_i], .. } => {
      match mul_i.kind {
        TInstrKind::TBinary(
          I32ShlOp,
          _,
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => assert_eq(v, 3)
        _ => fail("expected mul by 8 => shl 3")
      }
      match div_i.kind {
        TInstrKind::TBinary(
          I32ShrUOp,
          _,
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => assert_eq(v, 3)
        _ => fail("expected div_u by 8 => shr_u 3")
      }
      match rem_i.kind {
        TInstrKind::TBinary(
          I32AndOp,
          _,
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => assert_eq(v, 7)
        _ => fail("expected rem_u by 8 => and 7")
      }
    }
    _ => fail("expected three rewritten instructions")
  }
}

///|
test "optimize instructions arithmetic trivial constants" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_and(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(-1)),
      ),
      TInstr::binary(
        BinaryOp::i32_or(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(-1)),
      ),
      TInstr::binary(
        BinaryOp::i32_eq(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(-1)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [a0, a1, a2, a3], .. } => {
      match a0.kind {
        TInstrKind::TLocalGet(_) => ()
        _ => fail("expected and -1 => x")
      }
      match a1.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TDrop(_), .. },
              { kind: TInstrKind::TI32Const(I32(-1)), .. },
            ],
            ..,
          }
        ) => ()
        _ => fail("expected or -1 => -1 with drop")
      }
      match a2.kind {
        TInstrKind::TUnary(I32EqzOp, _) => ()
        _ => fail("expected eq 0 => eqz")
      }
      match a3.kind {
        TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(0)), .. },
          _
        ) => ()
        _ => fail("expected mul -1 => 0 - x")
      }
    }
    _ => fail("expected four rewritten instructions")
  }
}

///|
test "optimize instructions constant-left subtraction patterns" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_sub(),
        TInstr::i32_const(I32(10)),
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(4)),
        ),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32SubOp,
            { kind: TInstrKind::TI32Const(I32(c)), .. },
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => {
      assert_eq(c, 6)
      assert_eq(i.reinterpret_as_int(), 0)
    }
    _ => fail("expected C1 - (x + C2) rewrite")
  }
}

///|
test "optimize instructions relational x-y compare to zero" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_eq(),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
        TInstr::i32_const(I32(0)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32EqOp,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. },
            { kind: TInstrKind::TLocalGet(LocalIdx(j)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => {
      assert_eq(i.reinterpret_as_int(), 0)
      assert_eq(j.reinterpret_as_int(), 1)
    }
    _ => fail("expected x-y==0 => x==y")
  }
}

///|
test "optimize instructions deduplicate equal binary children" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_xor(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
      TInstr::binary(
        BinaryOp::i32_eq(),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::local_get(LocalIdx::new(1)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    { instrs: [a0, a1], .. } => {
      match a0.kind {
        TInstrKind::TI32Const(I32(0)) => ()
        _ => fail("expected x xor x => 0")
      }
      match a1.kind {
        TInstrKind::TI32Const(I32(1)) => ()
        _ => fail("expected x eq x => 1")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions reinterpret chains and load reinterpret" {
  let body = oi_run_func(
    [
      TInstr::unary(
        UnaryOp::i32_reinterpret_f32(),
        TInstr::unary(
          UnaryOp::f32_reinterpret_i32(),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
      TInstr::unary(
        UnaryOp::i32_reinterpret_f32(),
        TInstr::load(
          LoadOp::f32_load(),
          MemArg::new(U32(4), None, U64(0UL)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    { instrs: [a0, a1], .. } => {
      match a0.kind {
        TInstrKind::TLocalGet(LocalIdx(i)) =>
          assert_eq(i.reinterpret_as_int(), 0)
        _ => fail("expected reinterpret(reinterpret(x)) => x")
      }
      match a1.kind {
        TInstrKind::TLoad(I32LoadOp, _, _) => ()
        _ => fail("expected reinterpret(f32.load) => i32.load")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions if eqz arm flip and fold identical arms" {
  let body = oi_run_func(
    [
      TInstr::if_(
        BlockType::void_(),
        TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
        TExpr::new([TInstr::i32_const(I32(1))]),
        Some(TExpr::new([TInstr::i32_const(I32(2))])),
      ),
      TInstr::if_(
        BlockType::val_type(ValType::i32()),
        TInstr::local_get(LocalIdx::new(0)),
        TExpr::new([TInstr::i32_const(I32(7))]),
        Some(TExpr::new([TInstr::i32_const(I32(7))])),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [a0, a1], .. } => {
      match a0.kind {
        TInstrKind::TIf(
          _,
          { kind: TInstrKind::TLocalGet(_), .. },
          { instrs: [{ kind: TInstrKind::TI32Const(I32(2)), .. }], .. },
          Some({ instrs: [{ kind: TInstrKind::TI32Const(I32(1)), .. }], .. })
        ) => ()
        _ => fail("expected if eqz flip")
      }
      match a1.kind {
        TInstrKind::TBlock(
          _,
          { instrs: [{ kind: TInstrKind::TI32Const(I32(7)), .. }], .. }
        ) => ()
        _ => fail("expected identical-arm if fold")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions global.set same global.get becomes nop" {
  let body = oi_run_func([
    TInstr::global_set(GlobalIdx::new(0), TInstr::global_get(GlobalIdx::new(0))),
  ])
  match body {
    { instrs: [{ kind: TInstrKind::TNop, .. }], .. } => ()
    _ => fail("expected global.set g (global.get g) => nop")
  }
}

///|
test "optimize instructions memory access folds const pointer into offset" {
  let body = oi_run_func(
    [
      TInstr::load(
        LoadOp::i32_load(),
        MemArg::new(U32(4), None, U64(8UL)),
        TInstr::i32_const(I32(10)),
      ),
      TInstr::store(
        StoreOp::i32_store(),
        MemArg::new(U32(4), None, U64(6UL)),
        TInstr::i32_const(I32(4)),
        TInstr::i32_const(I32(1)),
      ),
    ],
    with_memory=true,
  )
  match body {
    { instrs: [l0, s0], .. } => {
      match l0.kind {
        TInstrKind::TLoad(
          _,
          MemArg(_, _, U64(off)),
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => {
          assert_eq(off, 0UL)
          assert_eq(v, 18)
        }
        _ => fail("expected folded load pointer")
      }
      match s0.kind {
        TInstrKind::TStore(
          _,
          MemArg(_, _, U64(off)),
          { kind: TInstrKind::TI32Const(I32(v)), .. },
          _
        ) => {
          assert_eq(off, 0UL)
          assert_eq(v, 10)
        }
        _ => fail("expected folded store pointer")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions store value truncation and wrap upgrade" {
  let body = oi_run_func(
    [
      TInstr::store(
        StoreOp::i32_store8(),
        MemArg::new(U32(1), None, U64(0UL)),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0x1234)),
      ),
      TInstr::store(
        StoreOp::i32_store(),
        MemArg::new(U32(4), None, U64(0UL)),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::unary(
          UnaryOp::i32_wrap_i64(),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i64()],
    with_memory=true,
  )
  match body {
    { instrs: [s0, s1], .. } => {
      match s0.kind {
        TInstrKind::TStore(
          I32Store8Op,
          _,
          _,
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => assert_eq(v, 0x34)
        _ => fail("expected store8 const truncation")
      }
      match s1.kind {
        TInstrKind::TStore(
          I64Store32Op,
          _,
          _,
          { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
        ) => assert_eq(i.reinterpret_as_int(), 1)
        _ => fail("expected wrap_i64 store upgrade to i64.store32")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions reinterpret store rewrites value type" {
  let body = oi_run_func(
    [
      TInstr::store(
        StoreOp::f32_store(),
        MemArg::new(U32(4), None, U64(0UL)),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::unary(
          UnaryOp::f32_reinterpret_i32(),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TStore(
            I32StoreOp,
            _,
            _,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => assert_eq(i.reinterpret_as_int(), 1)
    _ => fail("expected f32.store(reinterpret_i32) => i32.store")
  }
}

///|
test "optimize instructions memory.copy rewrites constants" {
  let body = oi_run_func(
    [
      TInstr::memory_copy(
        MemIdx::new(0),
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::memory_copy(
        MemIdx::new(0),
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(4)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    { instrs: [c0, c1], .. } => {
      match c0.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TDrop(_), .. },
              { kind: TInstrKind::TDrop(_), .. },
            ],
            ..,
          }
        ) => ()
        _ => fail("expected memory.copy size 0 rewrite")
      }
      match c1.kind {
        TInstrKind::TStore(
          I32StoreOp,
          _,
          _,
          { kind: TInstrKind::TLoad(I32LoadOp, _, _), .. }
        ) => ()
        _ => fail("expected memory.copy size 4 => store(load)")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions memory.fill rewrites constants" {
  let body = oi_run_func(
    [
      TInstr::memory_fill(
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::memory_fill(
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(1)),
      ),
      TInstr::memory_fill(
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0xaa)),
        TInstr::i32_const(I32(4)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    { instrs: [f0, f1, f2], .. } => {
      match f0.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TDrop(_), .. },
              { kind: TInstrKind::TDrop(_), .. },
            ],
            ..,
          }
        ) => ()
        _ => fail("expected memory.fill size 0 rewrite")
      }
      match f1.kind {
        TInstrKind::TStore(I32Store8Op, _, _, _) => ()
        _ => fail("expected memory.fill size 1 => store8")
      }
      match f2.kind {
        TInstrKind::TStore(
          I32StoreOp,
          _,
          _,
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => assert_eq(v, 0xaaaaaaaa)
        _ =>
          fail("expected memory.fill const size 4 => i32.store const pattern")
      }
    }
    _ => fail("expected three rewritten instructions")
  }
}

///|
test "optimize instructions select constant condition and equal arms" {
  let body = oi_run_func(
    [
      TInstr::select(
        None,
        TInstr::i32_const(I32(0)),
        TInstr::i32_const(I32(1)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
      TInstr::select(
        Some([ValType::i32()]),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(7)),
        TInstr::i32_const(I32(7)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [s0, s1], .. } => {
      match s0.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TDrop(
                  { kind: TInstrKind::TI32Const(I32(1)), .. }
                ),
                ..,
              },
              { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. },
            ],
            ..,
          }
        ) => assert_eq(i.reinterpret_as_int(), 0)
        _ => fail("expected select cond=0 rewrite")
      }
      match s1.kind {
        TInstrKind::TI32Const(I32(7)) => ()
        _ => fail("expected select equal arms fold")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions call_ref direct simplifications" {
  let type_sec = TypeSec::new([
    single_rec_type(comp_type_sub_type(func_comp_type([], [ValType::i32()]))),
  ])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let code_sec = CodeSec::new([
    Func::t_func(
      [],
      TExpr::new([
        TInstr::call_ref(TypeIdx::new(0), [], TInstr::ref_func(FuncIdx::new(0))),
      ]),
    ),
  ])
  let mod_ = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
  let out = optimize_module(mod_, [ModulePass::OptimizeInstructions]).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            { instrs: [{ kind: TInstrKind::TCall(FuncIdx(raw), _), .. }], .. }
          ),
        ]
      )
    ) => assert_eq(raw.reinterpret_as_int(), 0)
    _ => fail("expected call_ref(ref.func) => call")
  }
}

///|
test "optimize instructions helper arithmetic and relational utilities cover i64 and negative paths" {
  assert_true(oi_is_power_of_2_i64(8L))
  assert_false(oi_is_power_of_2_i64(0L))
  assert_eq(oi_log2_i64(8L), 3L)
  assert_eq(oi_wrap_i64(-1L), -1L)

  assert_eq(oi_const_i32(TInstr::i32_const(I32(11))), Some(11))
  assert_eq(oi_const_i32(TInstr::i64_const(I64(11L))), None)

  assert_eq(
    oi_reverse_relational(BinaryOp::i32_lt_s()),
    Some(BinaryOp::i32_gt_s()),
  )
  assert_eq(oi_invert_relational(BinaryOp::i32_eq()), Some(BinaryOp::i32_ne()))
  assert_eq(oi_invert_relational(BinaryOp::i32_add()), None)

  assert_true(oi_is_i64_shift(BinaryOp::i64_shl()))
  assert_false(oi_is_i32_shift(BinaryOp::i64_shl()))
  assert_true(oi_negate_const(TInstr::i64_const(I64(5L))) is Some(_))
}

///|
test "optimize instructions helper sequencing boolean and reorder checks" {
  let env = Env::new()
  assert_eq(oi_instr_stmt(TInstr::nop(), env), TInstr::nop())
  assert_eq(oi_seq([], TInstr::nop(), env), TInstr::nop())
  match oi_seq([TInstr::i32_const(I32(1))], TInstr::nop(), env).kind {
    TInstrKind::TBlock(
      VoidBlockType,
      { instrs: [_, { kind: TInstrKind::TNop, .. }], .. }
    ) => ()
    _ => fail("expected oi_seq to emit block for non-empty statements")
  }

  assert_true(
    oi_can_reorder(TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))),
  )
  assert_false(
    oi_can_reorder(
      TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(1))),
      TInstr::global_get(GlobalIdx::new(0)),
    ),
  )

  let eqz_eqz = oi_optimize_boolean(
    TInstr::unary(
      UnaryOp::i32_eqz(),
      TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
    ),
    env,
    OptimizeOptions::new(),
  )
  assert_eq(eqz_eqz, TInstr::local_get(LocalIdx::new(0)))

  let eqz_const = oi_optimize_boolean(
    TInstr::unary(UnaryOp::i32_eqz(), TInstr::i32_const(I32(0))),
    env,
    OptimizeOptions::new(),
  )
  assert_eq(eqz_const, TInstr::i32_const(I32(1)))
}

///|
test "optimize instructions i64 constant-right simplifications mirror i32 coverage" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i64_div_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(8L)),
      ),
      TInstr::binary(
        BinaryOp::i64_rem_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(8L)),
      ),
      TInstr::binary(
        BinaryOp::i64_ge_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(0L)),
      ),
      TInstr::binary(
        BinaryOp::i64_lt_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(-1L)),
      ),
      TInstr::binary(
        BinaryOp::i64_mul(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(-1L)),
      ),
    ],
    locals=[ValType::i64()],
  )
  match body {
    { instrs: [a0, a1, a2, a3, a4], .. } => {
      match a0.kind {
        TInstrKind::TBinary(
          I64ShrUOp,
          _,
          { kind: TInstrKind::TI64Const(I64(v)), .. }
        ) => assert_eq(v, 3L)
        _ => fail("expected i64.div_u by pow2 => shr_u")
      }
      match a1.kind {
        TInstrKind::TBinary(
          I64AndOp,
          _,
          { kind: TInstrKind::TI64Const(I64(v)), .. }
        ) => assert_eq(v, 7L)
        _ => fail("expected i64.rem_u by pow2 => and")
      }
      match a2.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TDrop(_), .. },
              { kind: TInstrKind::TI32Const(I32(v)), .. },
            ],
            ..,
          }
        ) => assert_eq(v, 1)
        _ => fail("expected i64.ge_u 0 => true with dropped lhs")
      }
      match a3.kind {
        TInstrKind::TBinary(
          I64NeOp,
          _,
          { kind: TInstrKind::TI64Const(I64(v)), .. }
        ) => assert_eq(v, -1L)
        _ => fail("expected i64.lt_u -1 => ne -1")
      }
      match a4.kind {
        TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(0L)), .. },
          _
        ) => ()
        _ => fail("expected i64.mul -1 => 0 - x")
      }
    }
    _ => fail("expected five rewritten i64 instructions")
  }
}

///|
test "optimize instructions candidate pre-scan reaches deeper nested candidates" {
  let body = oi_run_func(
    [
      TInstr::drop(
        TInstr::drop(
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::i32_const(I32(0)),
          ),
        ),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TDrop(
            {
              kind: TInstrKind::TDrop(
                { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
              ),
              ..,
            }
          ),
          ..,
        },
      ],
      ..,
    } => assert_eq(i.reinterpret_as_int(), 0)
    _ =>
      fail("expected nested i32.add with const zero to simplify to local.get")
  }
}
