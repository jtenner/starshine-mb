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
}

///|
priv struct PLSAnalysis {
  usage_by_local : Map[Int, PLSUsage]
  candidates_by_id : Map[Int, PLSCandidateLoad]
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
  match instr {
    TI32Const(I32(v)) => Some(v)
    _ => None
  }
}

///|
fn pls_i64_const(instr : TInstr) -> Int64? {
  match instr {
    TI64Const(I64(v)) => Some(v)
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
  match parent {
    TUnary(I32Extend8SOp, child) if child == value => Some(8)
    TUnary(I32Extend16SOp, child) if child == value => Some(16)
    TUnary(I64Extend8SOp, child) if child == value => Some(8)
    TUnary(I64Extend16SOp, child) if child == value => Some(16)
    TUnary(I64Extend32SOp, child) if child == value => Some(32)
    TUnary(I64ExtendI32SOp, child) if child == value => Some(32)
    TBinary(I32ShrSOp, lhs, rhs_shift) =>
      match lhs {
        TBinary(I32ShlOp, inner, lhs_shift) =>
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
    TBinary(I64ShrSOp, lhs, rhs_shift) =>
      match lhs {
        TBinary(I64ShlOp, inner, lhs_shift) =>
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
  match parent {
    TUnary(I64ExtendI32UOp, child) if child == value => Some(32)
    TBinary(I32AndOp, left, right) if left == value =>
      match pls_i32_const(right) {
        Some(mask) => pls_i32_low_mask_bits(mask)
        None => None
      }
    TBinary(I32AndOp, left, right) if right == value =>
      match pls_i32_const(left) {
        Some(mask) => pls_i32_low_mask_bits(mask)
        None => None
      }
    TBinary(I64AndOp, left, right) if left == value =>
      match pls_i64_const(right) {
        Some(mask) => pls_i64_low_mask_bits(mask)
        None => None
      }
    TBinary(I64AndOp, left, right) if right == value =>
      match pls_i64_const(left) {
        Some(mask) => pls_i64_low_mask_bits(mask)
        None => None
      }
    TBinary(I32ShrUOp, lhs, rhs_shift) =>
      match lhs {
        TBinary(I32ShlOp, inner, lhs_shift) =>
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
    TBinary(I64ShrUOp, lhs, rhs_shift) =>
      match lhs {
        TBinary(I64ShlOp, inner, lhs_shift) =>
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
fn pls_analyze_body(body : TExpr) -> Result[PLSAnalysis, String] {
  let usage_by_local : Map[Int, PLSUsage] = Map::new()
  let candidates_by_id : Map[Int, PLSCandidateLoad] = Map::new()
  let parent_stack : Array[TInstr] = []
  let mut next_id = 0
  let scanner = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    let curr_id = next_id
    next_id += 1
    match curr {
      TLoad(op, _, _) =>
        match pls_sign_relevant_load_info(op) {
          Some((_, load_bits)) =>
            match parent_stack.last() {
              Some(TLocalSet(local_idx, _)) =>
                candidates_by_id[curr_id] = {
                  local_idx: pls_local_idx_to_int(local_idx),
                  load_bits,
                }
              _ => ()
            }
          None => ()
        }
      TLocalGet(local_idx) => {
        let local_int = pls_local_idx_to_int(local_idx)
        let usage = pls_get_usage(usage_by_local, local_int)
        usage.total_usages += 1
        usage_by_local[local_int] = usage

        for depth in [1, 2] {
          match pls_get_parent_from_end(parent_stack, depth) {
            Some(parent) =>
              match pls_zero_ext_bits(parent, curr) {
                Some(bits) => pls_record_unsigned_usage(usage_by_local, local_int, bits)
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
    parent_stack.push(curr)
    let out = self.walk_tinstruction_default((), curr)
    ignore(parent_stack.pop())
    out
  })
  match scanner.walk_texpr((), body) {
    Ok(_) => Ok({ usage_by_local, candidates_by_id })
    Err(e) => Err(e)
  }
}

///|
fn pls_plan_rewrites(analysis : PLSAnalysis) -> Map[Int, Bool] {
  let decisions : Map[Int, Bool] = Map::new()
  for load_id, candidate in analysis.candidates_by_id {
    let usage = analysis.usage_by_local.get(candidate.local_idx).unwrap_or(
      PLSUsage::new(),
    )
    if usage.total_usages == 0 ||
      usage.signed_usages + usage.unsigned_usages != usage.total_usages ||
      (usage.signed_usages != 0 && usage.signed_bits != candidate.load_bits) ||
      (usage.unsigned_usages != 0 &&
      usage.unsigned_bits != candidate.load_bits) {
      continue
    }
    decisions[load_id] = usage.signed_usages * 2 >= usage.unsigned_usages
  }
  decisions
}

///|
fn pls_rewrite_body(
  body : TExpr,
  decisions : Map[Int, Bool],
) -> Result[TExpr, String] {
  if decisions.is_empty() {
    return Ok(body)
  }
  let mut next_id = 0
  let rewriter = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    let curr_id = next_id
    next_id += 1
    let walked = match self.walk_tinstruction_default((), curr) {
      Ok(Some((_, out))) => out
      Ok(None) => curr
      Err(e) => return Err(e)
    }
    let output = match decisions.get(curr_id) {
      Some(target_signed) =>
        match walked {
          TLoad(op, memarg, ptr) =>
            match pls_load_with_signedness(op, target_signed) {
              Some(new_op) => TInstr::load(new_op, memarg, ptr)
              None => walked
            }
          _ => walked
        }
      None => walked
    }
    if output == curr {
      unchanged()
    } else {
      change((), output)
    }
  })
  match rewriter.walk_texpr((), body) {
    Ok(Some((_, rewritten))) => Ok(rewritten)
    Ok(None) => Ok(body)
    Err(e) => Err(e)
  }
}

///|
fn pick_load_signs_on_func(func : Func) -> Result[Func, String] {
  match func {
    Func(_) => Ok(func)
    TFunc(locals, body) => {
      let analysis = match pls_analyze_body(body) {
        Ok(a) => a
        Err(e) => return Err(e)
      }
      let decisions = pls_plan_rewrites(analysis)
      let rewritten = match pls_rewrite_body(body, decisions) {
        Ok(out) => out
        Err(e) => return Err(e)
      }
      Ok(Func::t_func(locals, rewritten))
    }
  }
}

///|
fn pick_load_signs_ir_pass(_mod : Module) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_func_evt(fn(_, state, func) {
    match pick_load_signs_on_func(func) {
      Ok(updated) =>
        if updated == func {
          unchanged()
        } else {
          change(state, updated)
        }
      Err(e) => Err(e)
    }
  })
}

///|
fn pls_run_func(func : Func) -> Func {
  let pass = pick_load_signs_ir_pass(Module::new())
  let state = IRContext::new()
  match pass.walk_func(state, func) {
    Ok(Some((_, out))) => out
    Ok(None) => func
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
      _,
      TExpr([TLocalSet(_, TLoad(I32Load8UOp, _, _)), _, _]),
    ) => ()
    _ => fail("expected i32.load8_s to become i32.load8_u")
  }
}

///|
test "pick_load_signs picks signed when signed uses are weighted higher" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
      _,
      TExpr([TLocalSet(_, TLoad(I32Load8SOp, _, _)), _, _]),
    ) => ()
    _ => fail("expected i32.load8_u to become i32.load8_s")
  }
}

///|
test "pick_load_signs requires all loc.get uses to be sign-or-zero extensions" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
      _,
      TExpr([TLocalSet(_, TLoad(I32Load8SOp, _, _)), _, _]),
    ) => ()
    _ => fail("expected load op to stay signed due non-extension use")
  }
}

///|
test "pick_load_signs requires extension bits to match load bits" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
      _,
      TExpr([TLocalSet(_, TLoad(I32Load8UOp, _, _)), _]),
    ) => ()
    _ => fail("expected no rewrite when sign extension width mismatches")
  }
}

///|
test "pick_load_signs rejects inconsistent signed extension widths" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
      _,
      TExpr([TLocalSet(_, TLoad(I32Load8SOp, _, _)), _, _]),
    ) => ()
    _ => fail("expected no rewrite with inconsistent signed widths")
  }
}

///|
test "pick_load_signs recognizes nested shift-based zero extension on grandparent" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
      _,
      TExpr([TLocalSet(_, TLoad(I32Load16UOp, _, _)), _]),
    ) => ()
    _ => fail("expected i32.load16_s to become i32.load16_u")
  }
}

///|
test "pick_load_signs ignores loc.tee load producers" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
      _,
      TExpr([TDrop(TLocalTee(_, TLoad(I32Load8SOp, _, _))), _]),
    ) => ()
    _ => fail("expected tee load to remain unchanged")
  }
}

///|
test "pick_load_signs skips loads with no loc.get usages" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
      _,
      TExpr([TLocalSet(_, TLoad(I32Load8SOp, _, _)), _]),
    ) => ()
    _ => fail("expected no rewrite with zero usages")
  }
}

///|
test "pick_load_signs rewrites i64.load32 based on i64.extend32_s usage" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
      _,
      TExpr([TLocalSet(_, TLoad(I64Load32SOp, _, _)), _]),
    ) => ()
    _ => fail("expected i64.load32_u to become i64.load32_s")
  }
}

///|
test "pick_load_signs rewrites i64.load32 to unsigned for i64.and mask usage" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
      _,
      TExpr([TLocalSet(_, TLoad(I64Load32UOp, _, _)), _]),
    ) => ()
    _ => fail("expected i64.load32_s to become i64.load32_u")
  }
}

///|
test "pick_load_signs rewrites all candidate loads mapped to the same loc" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
    ]),
  )
  let out = pls_run_func(func)
  match out {
    TFunc(
      _,
      TExpr(
        [
          TLocalSet(_, TLoad(I32Load8UOp, _, _)),
          _,
          TLocalSet(_, TLoad(I32Load8UOp, _, _)),
          _,
        ]
      ),
    ) => ()
    _ => fail("expected both candidate loads to become i32.load8_u")
  }
}

///|
test "pick_load_signs is idempotent" {
  let loc = LocalIdx::new(0)
  let func = Func::t_func(
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
