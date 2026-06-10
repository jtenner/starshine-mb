///|
pub struct GenValidSsaFuncFacts {
  has_ssa_straight_line_local_chain : Bool
  has_ssa_multi_def_same_local : Bool
  has_ssa_local_tee_def_use : Bool
  has_ssa_param_write : Bool
  has_ssa_dead_local_set : Bool
  has_ssa_dead_local_tee : Bool
  has_ssa_if_join_phi_candidate : Bool
  has_ssa_loop_backedge_phi_candidate : Bool
  has_ssa_br_table_phi_candidate : Bool
  has_ssa_parallel_copy_candidate : Bool
  has_ssa_parallel_copy_cycle_candidate : Bool
  has_ssa_default_local_merge : Bool
  has_ssa_unreachable_local_carrier : Bool
  has_ssa_dropped_increment_guard_shape : Bool
  has_ssa_dropped_increment_reversed_boundary : Bool
  has_ssa_exceptional_fail_closed_shape : Bool
  has_ssa_typed_loop_param_fail_closed_shape : Bool
  has_ssa_nested_cfg_fail_closed_shape : Bool
} derive(Eq, Debug)

///|
pub fn GenValidSsaFuncFacts::empty() -> GenValidSsaFuncFacts {
  {
    has_ssa_straight_line_local_chain: false,
    has_ssa_multi_def_same_local: false,
    has_ssa_local_tee_def_use: false,
    has_ssa_param_write: false,
    has_ssa_dead_local_set: false,
    has_ssa_dead_local_tee: false,
    has_ssa_if_join_phi_candidate: false,
    has_ssa_loop_backedge_phi_candidate: false,
    has_ssa_br_table_phi_candidate: false,
    has_ssa_parallel_copy_candidate: false,
    has_ssa_parallel_copy_cycle_candidate: false,
    has_ssa_default_local_merge: false,
    has_ssa_unreachable_local_carrier: false,
    has_ssa_dropped_increment_guard_shape: false,
    has_ssa_dropped_increment_reversed_boundary: false,
    has_ssa_exceptional_fail_closed_shape: false,
    has_ssa_typed_loop_param_fail_closed_shape: false,
    has_ssa_nested_cfg_fail_closed_shape: false,
  }
}

///|
pub fn gen_valid_merge_ssa_func_facts(
  left : GenValidSsaFuncFacts,
  right : GenValidSsaFuncFacts,
) -> GenValidSsaFuncFacts {
  {
    has_ssa_straight_line_local_chain: left.has_ssa_straight_line_local_chain ||
    right.has_ssa_straight_line_local_chain,
    has_ssa_multi_def_same_local: left.has_ssa_multi_def_same_local ||
    right.has_ssa_multi_def_same_local,
    has_ssa_local_tee_def_use: left.has_ssa_local_tee_def_use ||
    right.has_ssa_local_tee_def_use,
    has_ssa_param_write: left.has_ssa_param_write || right.has_ssa_param_write,
    has_ssa_dead_local_set: left.has_ssa_dead_local_set ||
    right.has_ssa_dead_local_set,
    has_ssa_dead_local_tee: left.has_ssa_dead_local_tee ||
    right.has_ssa_dead_local_tee,
    has_ssa_if_join_phi_candidate: left.has_ssa_if_join_phi_candidate ||
    right.has_ssa_if_join_phi_candidate,
    has_ssa_loop_backedge_phi_candidate: left.has_ssa_loop_backedge_phi_candidate ||
    right.has_ssa_loop_backedge_phi_candidate,
    has_ssa_br_table_phi_candidate: left.has_ssa_br_table_phi_candidate ||
    right.has_ssa_br_table_phi_candidate,
    has_ssa_parallel_copy_candidate: left.has_ssa_parallel_copy_candidate ||
    right.has_ssa_parallel_copy_candidate,
    has_ssa_parallel_copy_cycle_candidate: left.has_ssa_parallel_copy_cycle_candidate ||
    right.has_ssa_parallel_copy_cycle_candidate,
    has_ssa_default_local_merge: left.has_ssa_default_local_merge ||
    right.has_ssa_default_local_merge,
    has_ssa_unreachable_local_carrier: left.has_ssa_unreachable_local_carrier ||
    right.has_ssa_unreachable_local_carrier,
    has_ssa_dropped_increment_guard_shape: left.has_ssa_dropped_increment_guard_shape ||
    right.has_ssa_dropped_increment_guard_shape,
    has_ssa_dropped_increment_reversed_boundary: left.has_ssa_dropped_increment_reversed_boundary ||
    right.has_ssa_dropped_increment_reversed_boundary,
    has_ssa_exceptional_fail_closed_shape: left.has_ssa_exceptional_fail_closed_shape ||
    right.has_ssa_exceptional_fail_closed_shape,
    has_ssa_typed_loop_param_fail_closed_shape: left.has_ssa_typed_loop_param_fail_closed_shape ||
    right.has_ssa_typed_loop_param_fail_closed_shape,
    has_ssa_nested_cfg_fail_closed_shape: left.has_ssa_nested_cfg_fail_closed_shape ||
    right.has_ssa_nested_cfg_fail_closed_shape,
  }
}

///|
const GEN_VALID_SSA_LOCAL_CAP : Int = 32

///|
fn gen_valid_ssa_local_slot(idx : LocalIdx) -> Int? {
  let LocalIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= GEN_VALID_SSA_LOCAL_CAP {
    None
  } else {
    Some(slot)
  }
}

///|
fn gen_valid_ssa_func_has_local_write(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      LocalSet(_) | LocalTee(_) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_func_has_local_write(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_func_has_local_write(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_func_has_local_write(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_func_has_exceptional(instr : Instruction) -> Bool {
  match instr {
    TryTable(_, _, _) | Throw(_) | ThrowRef => true
    _ => false
  }
}

///|
fn gen_valid_ssa_expr_has_exceptional(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    if gen_valid_ssa_func_has_exceptional(instr) {
      return true
    }
    match instr {
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_exceptional(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_exceptional(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_exceptional(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_blocktype_is_typed_loop(bt : BlockType) -> Bool {
  match bt {
    TypeIdxBlockType(_) => true
    _ => false
  }
}

///|
fn gen_valid_ssa_tail_expr(instrs : Array[Instruction], start : Int) -> Expr {
  let tail_instrs : Array[Instruction] = []
  let mut j = start
  while j < instrs.length() {
    tail_instrs.push(instrs[j])
    j += 1
  }
  Expr::new(tail_instrs)
}

///|
fn gen_valid_ssa_scan_linear(
  param_count : Int,
  instrs : Array[Instruction],
  facts : GenValidSsaFuncFacts,
  def_counts : Array[Int],
  has_local_write_in : Bool,
  has_exceptional_in : Bool,
) -> GenValidSsaFuncFacts {
  let mut out = facts
  let mut has_local_write = has_local_write_in
  let mut has_exceptional = has_exceptional_in
  let last_tee : Array[Bool] = []
  let last_def : Array[Bool] = []
  for _ in 0..<GEN_VALID_SSA_LOCAL_CAP {
    last_tee.push(false)
    last_def.push(false)
  }
  let mut saw_unreachable_prefix = false
  let mut i = 0
  while i < instrs.length() {
    let instr = instrs[i]
    if gen_valid_ssa_func_has_exceptional(instr) {
      has_exceptional = true
    }
    match instr {
      Unreachable => saw_unreachable_prefix = true
      LocalSet(idx) | LocalTee(idx) => {
        has_local_write = true
        match gen_valid_ssa_local_slot(idx) {
          Some(slot) => {
            def_counts[slot] = def_counts[slot] + 1
            if def_counts[slot] >= 2 {
              out = { ..out, has_ssa_multi_def_same_local: true }
            }
            if slot < param_count {
              out = { ..out, has_ssa_param_write: true }
            }
            last_def[slot] = true
            if instr is LocalTee(_) {
              last_tee[slot] = true
            }
            if saw_unreachable_prefix {
              out = { ..out, has_ssa_unreachable_local_carrier: true }
            }
            if instr is LocalSet(_) {
              let tail = gen_valid_ssa_tail_expr(instrs, i + 1)
              if !gen_valid_expr_local_has_read(tail, idx) {
                out = { ..out, has_ssa_dead_local_set: true }
              }
            }
            if instr is LocalTee(_) {
              match instrs.get(i + 1) {
                Some(Drop) => {
                  let tail = gen_valid_ssa_tail_expr(instrs, i + 2)
                  if !gen_valid_expr_local_has_read(tail, idx) {
                    out = { ..out, has_ssa_dead_local_tee: true }
                  }
                }
                _ => ()
              }
            }
          }
          None => ()
        }
      }
      LocalGet(idx) =>
        match gen_valid_ssa_local_slot(idx) {
          Some(slot) => {
            if last_def[slot] {
              out = { ..out, has_ssa_straight_line_local_chain: true }
            }
            if last_tee[slot] {
              out = { ..out, has_ssa_local_tee_def_use: true }
            }
            if saw_unreachable_prefix {
              out = { ..out, has_ssa_unreachable_local_carrier: true }
            }
          }
          None => ()
        }
      Drop =>
        if i > 0 {
          match instrs[i - 1] {
            Block(ValTypeBlockType(_), body)
            | Block(TypeIdxBlockType(_), body) =>
              if gen_valid_ssa_func_has_local_write(body) {
                out = { ..out, has_ssa_nested_cfg_fail_closed_shape: true }
              }
            _ => ()
          }
        }
      Block(bt, body) => {
        out = gen_valid_ssa_scan_expr(
            param_count, body, out, def_counts, has_local_write, has_exceptional,
          ).0
        if gen_valid_ssa_expr_has_unreachable(body) {
          saw_unreachable_prefix = true
        }
      }
      Loop(bt, body) => {
        let loop_facts = gen_valid_ssa_scan_loop(
          param_count, bt, body, def_counts, has_local_write, has_exceptional,
        )
        out = gen_valid_merge_ssa_func_facts(out, loop_facts)
      }
      If(bt, then_body, else_body) => {
        let (then_facts, then_writes, then_exceptional) = gen_valid_ssa_scan_if_arm(
          param_count, then_body, def_counts, has_local_write, has_exceptional,
        )
        let (else_facts, else_writes, else_exceptional) = match else_body {
          Some(body) =>
            gen_valid_ssa_scan_if_arm(
              param_count, body, def_counts, has_local_write, has_exceptional,
            )
          None => (GenValidSsaFuncFacts::empty(), false, false)
        }
        out = gen_valid_merge_ssa_func_facts(out, then_facts)
        out = gen_valid_merge_ssa_func_facts(out, else_facts)
        if then_writes || else_writes || then_exceptional || else_exceptional {
          has_local_write = has_local_write || then_writes || else_writes
          has_exceptional = has_exceptional ||
            then_exceptional ||
            else_exceptional
        }
        let tail = gen_valid_ssa_tail_expr(instrs, i + 1)
        out = gen_valid_ssa_scan_if_join(
          param_count, then_body, else_body, tail, out,
        )
      }
      BrTable(_, _) => {
        let tail = gen_valid_ssa_tail_expr(instrs, i + 1)
        if has_local_write && gen_valid_ssa_expr_has_local_read(tail) {
          out = { ..out, has_ssa_br_table_phi_candidate: true }
        }
      }
      _ => ()
    }
    if has_local_write && i + 3 < instrs.length() {
      match (instrs[i], instrs[i + 1], instrs[i + 2], instrs[i + 3]) {
        (LocalGet(_), I32Const(_), I32Add, Drop) =>
          out = { ..out, has_ssa_dropped_increment_guard_shape: true }
        (I32Const(_), LocalGet(_), I32Add, Drop) =>
          out = { ..out, has_ssa_dropped_increment_reversed_boundary: true }
        _ => ()
      }
    }
    i += 1
  }
  if has_exceptional && has_local_write {
    out = { ..out, has_ssa_exceptional_fail_closed_shape: true }
  }
  out
}

///|
fn gen_valid_ssa_expr_has_local_read(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      LocalGet(_) | LocalTee(_) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_local_read(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_local_read(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_local_read(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_scan_if_arm(
  param_count : Int,
  body : Array[Instruction],
  def_counts : Array[Int],
  has_local_write : Bool,
  has_exceptional : Bool,
) -> (GenValidSsaFuncFacts, Bool, Bool) {
  let facts = gen_valid_ssa_scan_linear(
    param_count,
    body,
    GenValidSsaFuncFacts::empty(),
    def_counts,
    has_local_write,
    has_exceptional,
  )
  (
    facts,
    gen_valid_ssa_func_has_local_write(Expr::new(body)),
    gen_valid_ssa_expr_has_exceptional(Expr::new(body)),
  )
}

///|
fn gen_valid_ssa_if_arm_writes_local(body : Array[Instruction]) -> Array[Int] {
  let written : Array[Int] = []
  let Expr(instrs) = Expr::new(body)
  for instr in instrs {
    match instr {
      LocalSet(idx) | LocalTee(idx) =>
        match gen_valid_ssa_local_slot(idx) {
          Some(slot) => {
            let mut seen = false
            for existing in written {
              if existing == slot {
                seen = true
              }
            }
            if !seen {
              written.push(slot)
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  written
}

///|
fn gen_valid_ssa_scan_if_join(
  param_count : Int,
  then_body : Array[Instruction],
  else_body : Array[Instruction]?,
  tail : Expr,
  facts : GenValidSsaFuncFacts,
) -> GenValidSsaFuncFacts {
  let then_writes = gen_valid_ssa_if_arm_writes_local(then_body)
  let else_writes = match else_body {
    Some(body) => gen_valid_ssa_if_arm_writes_local(body)
    None => []
  }
  let mut out = facts
  let mut any_write = false
  let mut both_arms_write = false
  for slot in then_writes {
    any_write = true
    let idx = LocalIdx::new(slot.reinterpret_as_uint())
    if gen_valid_expr_local_has_read(tail, idx) {
      out = { ..out, has_ssa_if_join_phi_candidate: true }
    }
    for other in else_writes {
      if other == slot {
        both_arms_write = true
      }
    }
  }
  for slot in else_writes {
    any_write = true
    let idx = LocalIdx::new(slot.reinterpret_as_uint())
    if gen_valid_expr_local_has_read(tail, idx) {
      out = { ..out, has_ssa_if_join_phi_candidate: true }
    }
  }
  if any_write {
    for slot in then_writes {
      let idx = LocalIdx::new(slot.reinterpret_as_uint())
      let in_else = else_writes.any(fn(other) { other == slot })
      if !in_else && gen_valid_expr_local_has_read(tail, idx) {
        out = { ..out, has_ssa_default_local_merge: true }
      }
    }
    for slot in else_writes {
      let idx = LocalIdx::new(slot.reinterpret_as_uint())
      let in_then = then_writes.any(fn(other) { other == slot })
      if !in_then && gen_valid_expr_local_has_read(tail, idx) {
        out = { ..out, has_ssa_default_local_merge: true }
      }
    }
    if then_writes.length() >= 2 && else_writes.length() >= 2 {
      let mut read0 = false
      let mut read1 = false
      for slot in [then_writes[0], else_writes[0]] {
        let idx = LocalIdx::new(slot.reinterpret_as_uint())
        if gen_valid_expr_local_has_read(tail, idx) {
          read0 = true
        }
      }
      if then_writes.length() > 1 && else_writes.length() > 1 {
        for slot in [then_writes[1], else_writes[1]] {
          let idx = LocalIdx::new(slot.reinterpret_as_uint())
          if gen_valid_expr_local_has_read(tail, idx) {
            read1 = true
          }
        }
      }
      if read0 && read1 {
        out = { ..out, has_ssa_parallel_copy_candidate: true }
      }
    }
    if both_arms_write && then_writes.length() >= 2 && else_writes.length() >= 2 {
      out = { ..out, has_ssa_parallel_copy_cycle_candidate: true }
    }
  }
  ignore(param_count)
  out
}

///|
fn gen_valid_ssa_scan_loop(
  param_count : Int,
  bt : BlockType,
  body : Expr,
  def_counts : Array[Int],
  has_local_write : Bool,
  has_exceptional : Bool,
) -> GenValidSsaFuncFacts {
  let Expr(instrs) = body
  let mut out = gen_valid_ssa_scan_linear(
    param_count,
    instrs,
    GenValidSsaFuncFacts::empty(),
    def_counts,
    has_local_write,
    has_exceptional,
  )
  let has_backedge = gen_valid_ssa_loop_has_backedge(body)
  let has_local_traffic = gen_valid_ssa_func_has_local_write(body) ||
    gen_valid_ssa_expr_has_local_read(body)
  if has_backedge && has_local_traffic {
    out = { ..out, has_ssa_loop_backedge_phi_candidate: true }
  }
  if gen_valid_ssa_blocktype_is_typed_loop(bt) && has_local_traffic {
    out = { ..out, has_ssa_typed_loop_param_fail_closed_shape: true }
  }
  out
}

///|
fn gen_valid_ssa_loop_has_backedge(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      Br(LabelIdx(idx)) | BrIf(LabelIdx(idx)) if idx == 0U => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_loop_has_backedge(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_loop_has_backedge(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_loop_has_backedge(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_scan_expr(
  param_count : Int,
  expr : Expr,
  facts : GenValidSsaFuncFacts,
  def_counts : Array[Int],
  has_local_write : Bool,
  has_exceptional : Bool,
) -> (GenValidSsaFuncFacts, Bool, Bool) {
  let Expr(instrs) = expr
  let scanned = gen_valid_ssa_scan_linear(
    param_count, instrs, facts, def_counts, has_local_write, has_exceptional,
  )
  (
    scanned,
    has_local_write || gen_valid_ssa_func_has_local_write(expr),
    has_exceptional || gen_valid_ssa_expr_has_exceptional(expr),
  )
}

///|
fn gen_valid_ssa_expr_has_unreachable(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      Unreachable => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_unreachable(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_unreachable(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_unreachable(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_ssa_expr_has_br_table(expr : Expr) -> Bool {
  let Expr(instrs) = expr
  for instr in instrs {
    match instr {
      BrTable(_, _) => return true
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        if gen_valid_ssa_expr_has_br_table(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_ssa_expr_has_br_table(Expr::new(then_body)) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_ssa_expr_has_br_table(Expr::new(body)) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
pub fn gen_valid_scan_func_ssa_facts(
  param_count : Int,
  _locals : Locals,
  expr : Expr,
) -> GenValidSsaFuncFacts {
  let def_counts : Array[Int] = []
  for _ in 0..<GEN_VALID_SSA_LOCAL_CAP {
    def_counts.push(0)
  }
  let mut out = gen_valid_ssa_scan_linear(
    param_count,
    match expr {
      Expr(instrs) => instrs
    },
    GenValidSsaFuncFacts::empty(),
    def_counts,
    false,
    false,
  )
  if gen_valid_ssa_expr_has_br_table(expr) &&
    gen_valid_ssa_func_has_local_write(expr) &&
    gen_valid_ssa_expr_has_local_read(expr) {
    out = { ..out, has_ssa_br_table_phi_candidate: true }
  }
  if gen_valid_ssa_expr_has_unreachable(expr) &&
    gen_valid_ssa_func_has_local_write(expr) &&
    gen_valid_ssa_expr_has_local_read(expr) {
    out = { ..out, has_ssa_unreachable_local_carrier: true }
  }
  out
}

///|
fn gen_valid_ssa_body_local(param_count : Int, body_idx : Int) -> LocalIdx {
  LocalIdx::new((param_count + body_idx).reinterpret_as_uint())
}

///|
fn gen_valid_append_ssa_nomerge_body_slice(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  accepts : Array[ValType],
) -> Unit {
  if !ctx.config.features.allow_ssa_nomerge_body_generator {
    return
  }
  if gen_valid_is_ssa_nomerge_parity_config(ctx.config) {
    gen_valid_append_ssa_nomerge_parity_body_slice(out, ctx, env, accepts)
  } else {
    gen_valid_append_ssa_nomerge_coverage_body_slice(out, ctx, env, accepts)
  }
}

///|
fn gen_valid_append_ssa_nomerge_parity_body_slice(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  accepts : Array[ValType],
) -> Unit {
  let param_count = accepts.length()
  let l0 = gen_valid_ssa_body_local(param_count, 0)
  let l1 = gen_valid_ssa_body_local(param_count, 1)
  let p0 = LocalIdx::new(0U)
  // A. straight-line multi-def same local
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(2)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // B. local.tee def-use chain
  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::local_tee(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // C. parameter write when available
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::i32_const(I32(9)))
    out.push(Instruction::local_set(p0))
    out.push(Instruction::local_get(p0))
    out.push(Instruction::drop())
  }
  // D. if-join phi candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::i32_const(I32(1)), Instruction::local_set(l0)],
      Some([Instruction::i32_const(I32(2)), Instruction::local_set(l0)]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // E. one-arm default merge
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::i32_const(I32(7)), Instruction::local_set(l0)],
      None,
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // F. loop backedge phi candidate (no outer block wrapper)
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(
    Instruction::loop_(
      BlockType::void_(),
      Expr::new([
        Instruction::local_get(l0),
        Instruction::drop(),
        Instruction::i32_const(I32(1)),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
        Instruction::br_if(LabelIdx::new(0U)),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // G. br-to-outer-block copy candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(7)),
        Instruction::local_set(l0),
        Instruction::br(LabelIdx::new(0U)),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // H. br_table multi-predecessor candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(1)),
        Instruction::local_set(l0),
        Instruction::i32_const(I32(0)),
        Instruction::br_table([LabelIdx::new(0U)], LabelIdx::new(0U)),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // I. parallel-copy candidate
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::i32_const(I32(2)))
  out.push(Instruction::local_set(l1))
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::local_get(l1),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
        Instruction::local_set(l1),
      ],
      Some([
        Instruction::local_get(l0),
        Instruction::local_set(l1),
        Instruction::local_get(l1),
        Instruction::local_set(l0),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l1))
  out.push(Instruction::drop())
  ignore(ctx)
  ignore(env)
}

///|
fn gen_valid_append_ssa_nomerge_coverage_body_slice(
  out : Array[Instruction],
  ctx : GenValidContext,
  env : GenValidBodyEnv,
  accepts : Array[ValType],
) -> Unit {
  let param_count = accepts.length()
  let l0 = gen_valid_ssa_body_local(param_count, 0)
  let l1 = gen_valid_ssa_body_local(param_count, 1)
  let p0 = LocalIdx::new(0U)
  // A. straight-line multi-def same local
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  out.push(Instruction::i32_const(I32(2)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // B. local.tee def-use chain
  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::local_tee(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // C. parameter write when available
  if param_count > 0 && accepts[0] == ValType::i32() {
    out.push(Instruction::i32_const(I32(9)))
    out.push(Instruction::local_set(p0))
    out.push(Instruction::local_get(p0))
    out.push(Instruction::drop())
  }
  // D. if-join phi candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::i32_const(I32(1)), Instruction::local_set(l0)],
      Some([Instruction::i32_const(I32(2)), Instruction::local_set(l0)]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // E. one-arm default merge
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::i32_const(I32(7)), Instruction::local_set(l0)],
      None,
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // F. loop backedge phi candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::loop_(
          BlockType::void_(),
          Expr::new([
            Instruction::local_get(l0),
            Instruction::drop(),
            Instruction::i32_const(I32(1)),
            Instruction::local_set(l0),
            Instruction::local_get(l0),
            Instruction::br_if(LabelIdx::new(0U)),
          ]),
        ),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // G. br-to-outer-block copy candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(7)),
        Instruction::local_set(l0),
        Instruction::br(LabelIdx::new(0U)),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // H. br_table multi-predecessor candidate
  out.push(Instruction::i32_const(I32(0)))
  out.push(Instruction::local_set(l0))
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(1)),
        Instruction::local_set(l0),
        Instruction::i32_const(I32(0)),
        Instruction::br_table([LabelIdx::new(0U)], LabelIdx::new(0U)),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // I. parallel-copy candidate
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::i32_const(I32(2)))
  out.push(Instruction::local_set(l1))
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::local_get(l1),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
        Instruction::local_set(l1),
      ],
      Some([
        Instruction::local_get(l0),
        Instruction::local_set(l1),
        Instruction::local_get(l1),
        Instruction::local_set(l0),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l1))
  out.push(Instruction::drop())
  // J. parallel-copy cycle candidate (stricter swap)
  out.push(Instruction::i32_const(I32(3)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::i32_const(I32(4)))
  out.push(Instruction::local_set(l1))
  out.push(Instruction::local_get(l0))
  out.push(
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::local_get(l1),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
        Instruction::local_set(l1),
      ],
      Some([
        Instruction::local_get(l1),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
        Instruction::local_set(l1),
      ]),
    ),
  )
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l1))
  out.push(Instruction::drop())
  // K. unreachable local carrier
  out.push(
    Instruction::block(
      BlockType::void_(),
      Expr::new([Instruction::unreachable_()]),
    ),
  )
  out.push(Instruction::i32_const(I32(7)))
  out.push(Instruction::local_tee(l0))
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  // L. dropped increment guarded shape
  out.push(Instruction::i32_const(I32(10)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::i32_add())
  out.push(Instruction::drop())
  // M. dropped increment reversed boundary
  out.push(Instruction::i32_const(I32(10)))
  out.push(Instruction::local_set(l0))
  out.push(Instruction::i32_const(I32(1)))
  out.push(Instruction::local_get(l0))
  out.push(Instruction::i32_add())
  out.push(Instruction::drop())
  // N. nested CFG fail-closed shape
  out.push(
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new([
        Instruction::i32_const(I32(7)),
        Instruction::local_set(l0),
        Instruction::local_get(l0),
      ]),
    ),
  )
  out.push(Instruction::drop())
  out.push(Instruction::local_get(l0))
  out.push(Instruction::drop())
  ignore(env)
}
