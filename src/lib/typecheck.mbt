///|
pub struct TcState {
  env : Env
  stack : Array[ValType]
  reachable : Bool
}

///|
pub impl Show for TcState with output(self, logger) {
  logger.write_string("TcState {\n")
  logger.write_string("  env : ")
  self.env.output(logger)
  logger.write_string("\n  stack : ")
  self.stack.output(logger)
  logger.write_string("\n  reachable : ")
  self.reachable.output(logger)
  logger.write_string("\n}")
}

///|
pub type TcResult = Result[TcState, String]

///|
pub trait Typecheck {
  typecheck(Self, TcState) -> Result[TcState, String]
}

///|
fn TcState::with_stack(st : TcState, stack : Array[ValType]) -> TcState {
  TcState::{ ..st, stack, }
}

///|
fn TcState::set_unreachable(st : TcState) -> TcState {
  TcState::{ ..st, reachable: false }
}

///|
fn TcState::push1(st : TcState, vt : ValType) -> TcState {
  let s = st.stack.copy()
  s.push(vt)
  st.with_stack(s)
}

///|
fn TcState::pop_ref_or_bot(st : TcState) -> Result[(TcState, RefType?), String] {
  match st.pop1() {
    Err(e) => Err(e)
    Ok((st1, v)) =>
      match v {
        BotValType => Ok((st1, None)) // unknown ref type, but acceptable
        RefTypeValType(rt) => Ok((st1, Some(rt)))
        _ => Err("expected a reference operand")
      }
  }
}

///|
fn TcState::check_branch_args_present(
  st : TcState,
  l : LabelIdx,
) -> Result[Array[ValType], String] {
  match st.env.get_label_types(l) {
    None => Err("invalid label index")
    Some(ts) => Ok(ts)
  }
}

///|
fn TcState::pop1(st : TcState) -> Result[(TcState, ValType), String] {
  if !st.reachable {
    // polymorphic stack when unreachable (spec “bot” behavior)
    return Ok((st, BotValType))
  }
  let s = st.stack.copy()
  match s.pop() {
    None => Err("stack underflow")
    Some(v) => Ok((st.with_stack(s), v))
  }
}

///|
fn TcState::pop_expect(st : TcState, expected : ValType) -> TcResult {
  match st.pop1() {
    Err(e) => Err(e)
    Ok((st2, actual)) => {
      if !st.reachable {
        return Ok(st2)
      }
      if actual.matches(expected, st.env) {
        Ok(st2)
      } else {
        Err("type mismatch")
      }
    }
  }
}

///|
fn typecheck_drop(st : TcState) -> TcResult {
  match st.pop1() {
    Err(e) => Err(e)
    Ok((st2, _)) => Ok(st2)
  }
}

///|
fn TcState::push_types(st : TcState, ts : Array[ValType]) -> TcState {
  let mut out = st
  for t in ts {
    out = out.push1(t)
  }
  out
}

///|
fn TcState::pop_types(st : TcState, ts : Array[ValType]) -> TcResult {
  let mut cur = st
  for t in ts.rev_iter() {
    cur = match cur.pop_expect(t) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
  }
  Ok(cur)
}

///|
fn TcState::mem_at_of(st : TcState, mem : MemIdx) -> Result[ValType, String] {
  match st.env.get_memtype(mem) {
    None => Err("invalid memory index")
    Some(MemType(lim)) => Ok(lim.addr_valtype())
  }
}

///|
fn expect_ref_null_heaptype(v : ValType) -> Result[HeapType, String] {
  match v {
    RefTypeValType(rt) =>
      match rt {
        HeapTypeRefType(true, ht) => Ok(ht)
        HeapTypeRefType(false, _) =>
          Err("expected (ref null ht), got non-null ref")
        AbsHeapTypeRefType(_) =>
          Err("expected (ref null ht), got abstract ref type")
      }
    _ => Err("expected reference type")
  }
}

///|
fn pop_types_rev(st : TcState, ts : Array[ValType]) -> TcResult {
  let mut st = st
  for t in ts.rev_iter() {
    st = match st.pop_expect(t) {
      Err(t) => return Err(t)
      Ok(t) => t
    }
  }
  Ok(st)
}

///|
pub impl Typecheck for Expr with typecheck(self, st0) {
  let Expr(instrs) = self
  let mut st = st0
  for ins in instrs {
    match ins.typecheck(st) {
      Ok(stp) => st = stp
      Err(err) => return Err(err)
    }
  }
  Ok(st)
}

///|
fn typecheck_select_typed(st : TcState, ts : Array[ValType]) -> TcResult {
  if Validate::validate(ts, st.env) is Err(t) {
    return Err("invalid select type annotation: " + t)
  }

  // condition
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match pop_types_rev(st1, ts) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match pop_types_rev(st2, ts) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // push ts
  let mut out = st3
  for t in ts {
    out = out.push1(t)
  }
  Ok(out)
}

///|
fn typecheck_select_untyped(st : TcState) -> TcResult {
  // pop condition (i32)
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop second operand
  let (st2, t2) = match st1.pop1() {
    Err(e) => return Err(e)
    Ok(pair) => pair
  }

  // pop first operand
  let (st3, t1) = match st2.pop1() {
    Err(e) => return Err(e)
    Ok(pair) => pair
  }

  // unreachable: stack is polymorphic, result type can be bot
  if !st.reachable {
    return Ok(st3.push1(BotValType))
  }

  // reachable: operands must have the same type (mutual match)
  let same = t1.matches(t2, st.env) && t2.matches(t1, st.env)
  if !same {
    return Err("select requires both operands to have the same type")
  }
  Ok(st3.push1(t1))
}

///|
fn typecheck_local_get(st : TcState, idx : LocalIdx) -> TcResult {
  match st.env.get_local_type(idx) {
    None => Err("invalid local index")
    Some(vt) => Ok(st.push1(vt))
  }
}

///|
fn typecheck_local_set(st : TcState, idx : LocalIdx) -> TcResult {
  match st.env.get_local_type(idx) {
    None => Err("invalid local index")
    Some(vt) => st.pop_expect(vt)
  }
}

///|
fn typecheck_local_tee(st : TcState, idx : LocalIdx) -> TcResult {
  match st.env.get_local_type(idx) {
    None => Err("invalid local index")
    Some(vt) =>
      // tee pops vt then pushes vt
      match st.pop_expect(vt) {
        Err(e) => Err(e)
        Ok(st2) => Ok(st2.push1(vt))
      }
  }
}

///|
fn typecheck_global_get(st : TcState, idx : GlobalIdx) -> TcResult {
  match st.env.get_global_type(idx) {
    None => Err("invalid global index")
    Some(GlobalType(vt, _mut)) => Ok(st.push1(vt))
  }
}

///|
fn typecheck_global_set(st : TcState, idx : GlobalIdx) -> TcResult {
  match st.env.get_global_type(idx) {
    None => Err("invalid global index")
    Some(GlobalType(vt, is_mut)) => {
      if !is_mut {
        return Err("global.set on immutable global")
      }
      st.pop_expect(vt)
    }
  }
}

// table.get x : [i32] -> [t]

///|
fn typecheck_table_get(st : TcState, idx : TableIdx) -> TcResult {
  let TableType(rt, _) = match st.env.get_table_type(idx) {
    None => return Err("invalid table index")
    Some(tt) => tt
  }
  let st1 = match st.pop_expect(i32_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ref_valtype(rt)))
}

// table.set x : [i32, t] -> []

///|
fn typecheck_table_set(st : TcState, idx : TableIdx) -> TcResult {
  let TableType(rt, _) = match st.env.get_table_type(idx) {
    None => return Err("invalid table index")
    Some(tt) => tt
  }

  // pop value (t)
  let st1 = match st.pop_expect(ref_valtype(rt)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop index (i32)
  let st2 = match st1.pop_expect(i32_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2)
}

// table.size x : [] -> [i32]

///|
fn typecheck_table_size(st : TcState, idx : TableIdx) -> TcResult {
  match st.env.get_table_type(idx) {
    None => Err("invalid table index")
    Some(_) => Ok(st.push1(i32_valtype()))
  }
}

// table.grow x : [t, i32] -> [i32]

///|
fn typecheck_table_grow(st : TcState, idx : TableIdx) -> TcResult {
  let TableType(rt, _) = match st.env.get_table_type(idx) {
    None => return Err("invalid table index")
    Some(tt) => tt
  }

  // pop delta (i32) — top of stack
  let st1 = match st.pop_expect(i32_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop init value (t)
  let st2 = match st1.pop_expect(ref_valtype(rt)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(i32_valtype()))
}

///|
fn typecheck_br(st : TcState, l : LabelIdx) -> TcResult {
  let ts = match st.env.get_label_types(l) {
    None => return Err("invalid label index")
    Some(x) => x
  }
  let st1 = match st.pop_types(ts) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.set_unreachable())
}

///|
fn typecheck_block(st : TcState, bt : BlockType, body : Expr) -> TcResult {
  let (params, results) = match st.env.expand_blocktype(bt) {
    Err(e) => return Err(e)
    Ok(x) => x
  }

  // Entry stack height after consuming params
  let st1 = match st.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let base_len = st1.stack.length()

  // Typecheck body with label = results
  let env2 = st1.env.with_label(results)
  let st_body0 = TcState::{ ..st1, env: env2 }
  let st_body = match body.typecheck(st_body0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // If reachable, enforce results on top
  let st2 = if st_body.reachable {
    match st_body.pop_types(results) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
  } else {
    st_body
  }

  // Now drop any extra stack above base_len (polymorphic details omitted for now)
  let s = st2.stack.copy()
  while s.length() > base_len {
    // safe and ignorable because > base_len
    ignore(s.pop())
  }
  let out = TcState::{ ..st, stack: s }
  Ok( // reachability after block is same as entry unless you model merges
    out.push_types(results),
  )
}

///|
fn typecheck_if(
  st : TcState,
  bt : BlockType,
  then_instrs : Array[Instruction],
  else_instrs_opt : Array[Instruction]?,
) -> TcResult {
  let (params, results) = match st.env.expand_blocktype(bt) {
    Err(e) => return Err(e)
    Ok(x) => x
  }

  // pop condition
  let st0 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop params
  let st1 = match st0.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let base_len = st1.stack.length()
  let else_instrs = match else_instrs_opt {
    None => []
    Some(xs) => xs
  }

  // typecheck then branch
  let env_branch = st1.env.with_label(results)
  let st_then0 = TcState::{ ..st1, env: env_branch }
  let st_then = match Expr(then_instrs).typecheck(st_then0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // typecheck else branch (same starting state!)
  let st_else0 = TcState::{ ..st1, env: env_branch }
  let st_else = match Expr(else_instrs).typecheck(st_else0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // For each reachable branch: enforce results on top and truncate to base_len.
  let norm_branch = fn(sb : TcState) -> Result[(Bool, Array[ValType]), String] {
    let sb2 = if sb.reachable {
      match sb.pop_types(results) {
        Err(e) => return Err(e)
        Ok(s) => s
      }
    } else {
      sb
    }
    let stack2 = sb2.stack.copy()
    while stack2.length() > base_len {
      ignore(stack2.pop())
    }
    Ok((sb2.reachable, stack2))
  }
  let (then_reach, then_stack) = match norm_branch(st_then) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let (else_reach, else_stack) = match norm_branch(st_else) {
    Err(e) => return Err(e)
    Ok(x) => x
  }

  // Merge rule: if both reachable, stacks must be identical at merge point.
  // If one unreachable, take the other.
  let merged_stack = match (then_reach, else_reach) {
    (true, true) => {
      if then_stack != else_stack {
        return Err("if branch stack mismatch")
      }
      then_stack
    }
    (true, false) => then_stack
    (false, true) => else_stack
    (false, false) => st1.stack.copy() // both unreachable, base is fine
  }
  let merged_reachable = then_reach || else_reach
  let out = TcState::{
    env: st.env,
    stack: merged_stack,
    reachable: merged_reachable,
  }
  Ok(out.push_types(results))
}

///|
fn typecheck_br_if(st : TcState, l : LabelIdx) -> TcResult {
  let ts = match st.env.get_label_types(l) {
    None => return Err("invalid label index")
    Some(x) => x
  }

  // Pop condition first
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // If unreachable, the stack is polymorphic; br_if is fine
  if !st.reachable {
    return Ok(st1)
  }

  // Check that branch arguments are present.
  // Important: do NOT keep the popped state; this is only a type check.
  let _ = match st1.pop_types(ts) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }

  // Not-taken path continues with the stack after popping only the condition
  Ok(st1)
}

///|
fn typecheck_br_table(
  st : TcState,
  ls : Array[LabelIdx],
  ldef : LabelIdx,
) -> TcResult {
  // pop selector
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let ts = match st.env.get_label_types(ldef) {
    None => return Err("invalid default label index")
    Some(x) => x
  }

  // Every label in the table must have the same types as the default
  for l in ls {
    let ts_l = match st.env.get_label_types(l) {
      None => return Err("invalid label index in br_table")
      Some(x) => x
    }
    let same = Match::matches(ts_l, ts, st.env) &&
      Match::matches(ts, ts_l, st.env)
    if !same {
      return Err("br_table target labels have different argument types")
    }
  }

  // Pop the branch arguments (values that will be passed to the target label)
  let st2 = match st1.pop_types(ts) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // br_table always branches - code after is unreachable
  Ok({ ..st2, reachable: false })
}

///|
fn typecheck_return(st : TcState) -> TcResult {
  let ts = match st.env.return_type {
    None => return Err("return used with no function return type in context")
    Some(t) => t
  }
  let st1 = match st.pop_types(ts) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.set_unreachable())
}

///|
fn typecheck_call(st : TcState, fidx : FuncIdx) -> TcResult {
  let FuncType(params, results) = match st.env.get_functype_by_funcidx(fidx) {
    None => return Err("invalid function index")
    Some(ft) => ft
  }
  let st1 = match st.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push_types(results))
}

///|
fn typecheck_call_indirect(
  st : TcState,
  tidx : TypeIdx,
  tid : TableIdx,
) -> TcResult {
  // Resolve the function type from the type index
  let FuncType(params, results) = match st.env.resolve_functype(tidx) {
    None => return Err("call_indirect type index is not a function type")
    Some(ft) => ft
  }

  // Table must exist and have element type compatible with funcref
  let TableType(elem_rt, _) = match st.env.get_table_type(tid) {
    None => return Err("invalid table index")
    Some(tt) => tt
  }

  // Require elem_rt <: funcref (spec requires the table contains functions)
  let fr = funcref_valtype()
  let elem_vt = RefTypeValType(elem_rt)
  if !Match::matches(elem_vt, fr, st.env) {
    return Err("call_indirect table element type is not funcref-compatible")
  }

  // Pop table element index (i32)
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // Pop params
  let st2 = match st1.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push_types(results))
}

///|
fn typecheck_call_ref(st : TcState, tidx : TypeIdx) -> TcResult {
  let FuncType(params, results) = match st.env.resolve_functype(tidx) {
    None => return Err("call_ref type index is not a function type")
    Some(ft) => ft
  }

  // Pop funcref of type (ref null tidx)
  // Your representation: HeapTypeRefType(nullable, HeapType(TypeIdx))
  let fref = RefTypeValType(HeapTypeRefType(true, HeapType(tidx)))
  let st1 = match st.pop_expect(fref) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // Pop params
  let st2 = match st1.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push_types(results))
}

///|
fn require_return_results(
  st : TcState,
  results : Array[ValType],
) -> Result[Unit, String] {
  match st.env.return_type {
    None => Err("return_call used with no function return type in context")
    Some(rt) =>
      if equals(results, rt) {
        Ok(())
      } else {
        Err("tail call result mismatch")
      }
  }
}

///|
fn typecheck_return_call(st : TcState, fidx : FuncIdx) -> TcResult {
  let FuncType(params, results) = match st.env.get_functype_by_funcidx(fidx) {
    None => return Err("invalid function index")
    Some(ft) => ft
  }
  match require_return_results(st, results) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let st1 = match st.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.set_unreachable())
}

///|
fn typecheck_return_call_indirect(
  st : TcState,
  tidx : TypeIdx,
  t : TableIdx,
) -> TcResult {
  let FuncType(params, results) = match st.env.resolve_functype(tidx) {
    None => return Err("return_call_indirect type index is not a function type")
    Some(ft) => ft
  }
  match require_return_results(st, results) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let TableType(elem_rt, _) = match st.env.get_table_type(t) {
    None => return Err("invalid table index")
    Some(tt) => tt
  }

  // elem_rt <: funcref
  let fr = RefTypeValType(AbsHeapTypeRefType(FuncAbsHeapType))
  let elem_vt = RefTypeValType(elem_rt)
  if !Match::matches(elem_vt, fr, st.env) {
    return Err(
      "return_call_indirect table element type is not funcref-compatible",
    )
  }
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.set_unreachable())
}

///|
fn typecheck_return_call_ref(st : TcState, tidx : TypeIdx) -> TcResult {
  let FuncType(params, results) = match st.env.resolve_functype(tidx) {
    None => return Err("return_call_ref type index is not a function type")
    Some(ft) => ft
  }
  match require_return_results(st, results) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let fref = RefTypeValType(HeapTypeRefType(true, HeapType(tidx)))
  let st1 = match st.pop_expect(fref) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.set_unreachable())
}

///|
fn expect_nullable_ref(v : ValType) -> Result[(HeapType, RefType), String] {
  match v {
    RefTypeValType(rt) => {
      if !rt.is_nullable() {
        return Err("expected a nullable reference type")
      }
      Ok((rt.get_heap_type(), rt))
    }
    _ => Err("expected a reference type")
  }
}

///|
fn typecheck_br_on_null(st : TcState, l : LabelIdx) -> TcResult {
  let ts = match st.env.get_label_types(l) {
    None => return Err("invalid label index")
    Some(x) => x
  }

  // Pop operand: must be exactly (ref null ht)
  let (st1, v) = match st.pop1() {
    Err(e) => return Err(e)
    Ok(pair) => pair
  }
  let ht = match expect_ref_null_heaptype(v) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  if ht.validate(st.env) is Err(t) {
    return Err("Invalid heap type in br_on_null operand: " + t)
  }

  // Branch target label has type t*
  if st.reachable {
    let _ = match st1.pop_types(ts) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }

  }

  // Fallthrough refines to non-null (ref ht)
  Ok(st1.push1(RefTypeValType(HeapTypeRefType(false, ht))))
}

///|
fn typecheck_br_on_non_null(st : TcState, l : LabelIdx) -> TcResult {
  let label_ts = match st.env.get_label_types(l) {
    None => return Err("invalid label index")
    Some(x) => x
  }
  let (st1, v) = match st.pop1() {
    Err(e) => return Err(e)
    Ok(pair) => pair
  }
  let (ht, _rt_in) = match expect_nullable_ref(v) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  if ht.validate(st.env) is Err(t) {
    return Err("Invalid heap type in br_on_non_null operand: " + t)
  }
  if label_ts.length() == 0 {
    return Err("br_on_non_null label type too short")
  }

  // Label must end with NON-NULLABLE ref of same heap type
  let non_null_rt = HeapTypeRefType(false, ht)
  let want_last = RefTypeValType(non_null_rt)
  let last = label_ts[label_ts.length() - 1]
  if not(last.matches(want_last, st.env)) {
    return Err("br_on_non_null label must end with non-nullable ref type")
  }
  if st.reachable {
    let prefix = label_ts.sub(start=0, end=label_ts.length() - 1)
    if st1.pop_types(prefix.to_array()) is Err(t) {
      return Err(t)
    }
  }
  Ok(st1)
}

///|
fn typecheck_br_on_cast(
  st : TcState,
  l : LabelIdx,
  op : CastOp,
  ht1 : HeapType,
  ht2 : HeapType,
) -> TcResult {
  let CastOp(n1, n2) = op
  let rt1 = HeapTypeRefType(n1, ht1)
  let rt2 = HeapTypeRefType(n2, ht2)
  if rt1.validate(st.env) is Err(t) {
    return Err("Invalid BrOnCast: " + t)
  }
  if rt2.validate(st.env) is Err(t) {
    return Err("Invalid BrOnCast: " + t)
  }
  let label_ts = match st.check_branch_args_present(l) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  if label_ts.length() == 0 {
    return Err("br_on_cast label type too short")
  }
  let rt_label = match label_ts[label_ts.length() - 1] {
    RefTypeValType(r) => r
    _ => return Err("br_on_cast label must end with a reftype")
  }

  // rt2 <: rt1 and rt2 <: rt_label
  if !Match::matches(rt2, rt1, st.env) {
    return Err("rt2 does not match rt1")
  }
  if !Match::matches(rt2, rt_label, st.env) {
    return Err("rt2 does not match label rt")
  }

  // pop rt1
  let st1 = match st.pop_expect(RefTypeValType(rt1)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  if st.reachable {
    // Check label args excluding rt_label (because branch keeps rt2 / rt_label)
    // Per spec, label is t* rt, so the remaining stack must have t*
    let prefix = label_ts.sub(start=0, end=label_ts.length() - 1) // adjust if no slice
    let _ = match st1.pop_types(prefix.to_array()) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }

  }

  // push (rt1 \ rt2)
  let rt_out = match diff(rt1, rt2) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  Ok(st1.push1(RefTypeValType(rt_out)))
}

///|
fn typecheck_br_on_cast_fail(
  st : TcState,
  l : LabelIdx,
  op : CastOp,
  ht1 : HeapType,
  ht2 : HeapType,
) -> TcResult {
  let CastOp(n1, n2) = op
  let rt1 = HeapTypeRefType(n1, ht1)
  let rt2 = HeapTypeRefType(n2, ht2)
  if rt1.validate(st.env) is Err(t) {
    return Err("Invalid RefType on BrOnCastFail: " + t)
  }
  if rt2.validate(st.env) is Err(t) {
    return Err("Invalid RefType on BrOnCastFail: " + t)
  }
  let label_ts = match st.check_branch_args_present(l) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  if label_ts.length() == 0 {
    return Err("br_on_cast_fail label type too short")
  }
  let rt_label = match label_ts[label_ts.length() - 1] {
    RefTypeValType(r) => r
    _ => return Err("br_on_cast_fail label must end with a reftype")
  }
  if !Match::matches(rt2, rt1, st.env) {
    return Err("rt2 does not match rt1")
  }
  let rt_diff = match diff(rt1, rt2) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  if !Match::matches(rt_diff, rt_label, st.env) {
    return Err("rt1 \\ rt2 does not match label rt")
  }

  // pop rt1
  let st1 = match st.pop_expect(RefTypeValType(rt1)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  if st.reachable {
    let prefix = label_ts.sub(start=0, end=label_ts.length() - 1)
    let _ = match st1.pop_types(prefix.to_array()) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }

  }
  Ok(st1.push1(RefTypeValType(rt2)))
}

///|
fn typecheck_throw(st : TcState, tag : TagIdx) -> TcResult {
  // validate tag index
  if tag.validate(st.env) is Err(e) {
    return Err(e)
  }

  // get payload params
  let TagType(tidx) = st.env.tags[tag.0.reinterpret_as_int()]
  let params = match st.env.resolve_functype(tidx) {
    Some(FuncType(ps, _)) => ps
    None => return Err("throw: invalid tag type")
  }

  // pop payload
  let st1 = match st.pop_types(params) {
    Ok(s) => s
    Err(e) => return Err(e)
  }

  // throw always makes execution unreachable
  Ok(st1.set_unreachable())
}

///|
fn typecheck_throw_ref(st : TcState) -> TcResult {
  let st1 = match st.pop_expect(ref_null_exn_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.set_unreachable())
}

///|
fn typecheck_catch_clause(st : TcState, c : Catch) -> TcResult {
  match c {
    Catch(tag, lbl) => {
      // label must expect tag's payload types
      let label_idx = lbl.0.reinterpret_as_int()
      let label_types = match st.env.labels.get(label_idx) {
        Some(label_types) => label_types
        None => return Err("Invalid catch label index")
      }
      let payload = tag_payload_types(st.env, tag)
      if not(Match::matches(payload, label_types, st.env)) {
        return Err("catch types (payload) do not match label types")
      }
      Ok(st)
    }
    CatchRef(tag, lbl) => {
      // label must expect tag's payload types + exnref
      let label_idx = lbl.0.reinterpret_as_int()
      let label_types = match st.env.labels.get(label_idx) {
        Some(label_types) => label_types
        None => return Err("Invalid catch label index")
      }
      let payload = tag_payload_types(st.env, tag)
      let expected = payload.copy()
      expected.push(
        RefTypeValType(
          HeapTypeRefType(false, AbsHeapTypeHeapType(ExnAbsHeapType)),
        ),
      )
      if not(Match::matches(payload, label_types, st.env)) {
        return Err(
          "catch_ref types (payload + exnref) do not match label types",
        )
      }
      Ok(st)
    }
    CatchAll(lbl) => {
      // label must expect empty
      let label_idx = lbl.0.reinterpret_as_int()
      let label_types = match st.env.labels.get(label_idx) {
        Some(label_types) => label_types
        None => return Err("Invalid catch label index")
      }
      if label_types.length() != 0 {
        return Err("catch_all label must expect no values")
      }
      Ok(st)
    }
    CatchAllRef(lbl) => {
      // label must expect just exnref
      let label_idx = lbl.0.reinterpret_as_int()
      let label_types = match st.env.labels.get(label_idx) {
        Some(label_types) => label_types
        None => return Err("Invalid catch label index")
      }
      let expected = [
        RefTypeValType(
          HeapTypeRefType(false, AbsHeapTypeHeapType(ExnAbsHeapType)),
        ),
      ]
      if not(Match::matches(expected, label_types, st.env)) {
        return Err("catch_all_ref label must expect exnref")
      }
      Ok(st)
    }
  }
}

///|
fn typecheck_try_table(
  st : TcState,
  bt : BlockType,
  catches : Array[Catch],
  body : Expr,
) -> TcResult {
  let (params, results) = match st.env.expand_blocktype(bt) { // assuming you made it a method
    Err(e) => return Err(e)
    Ok(x) => x
  }

  // consume params
  let st1 = match st.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let base_len = st1.stack.length()

  // extend context with innermost label = results
  let env2 = st1.env.with_label(results)
  let st_body0 = TcState::{ ..st1, env: env2 }

  // body must typecheck under extended env
  let st_body = match body.typecheck(st_body0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // validate all catch clauses under the SAME extended env (spec: C')
  let st_catch_ctx = TcState::{ ..st1, env: env2 }
  for c in catches {
    match typecheck_catch_clause(st_catch_ctx, c) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }

  // if reachable, enforce results on stack top
  let st2 = if st_body.reachable {
    match st_body.pop_types(results) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
  } else {
    st_body
  }

  // truncate back to base_len
  let stack2 = st2.stack.copy()
  while stack2.length() > base_len {
    ignore(stack2.pop())
  }

  // restore outer env (pop the try_table label scope)
  let out = TcState::{ env: st.env, stack: stack2, reachable: st2.reachable }
  Ok(out.push_types(results))
}

///|
fn typecheck_table_copy(st : TcState, x : TableIdx, y : TableIdx) -> TcResult {
  let TableType(rt1, l1) = match st.env.get_table_type(x) {
    None => return Err("invalid dest table index")
    Some(tt) => tt
  }
  let TableType(rt2, l2) = match st.env.get_table_type(y) {
    None => return Err("invalid src table index")
    Some(tt) => tt
  }

  // require rt2 <: rt1
  if !Match::matches(rt2, rt1, st.env) {
    return Err("table.copy source elem type does not match dest elem type")
  }
  let at_len = min_addr(l1, l2)

  // Pop len, src, dst (LIFO), with types at_len, at2, at1
  let st1 = match st.pop_expect(at_len.addr_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(l2.addr_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(l1.addr_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3)
}

///|
fn typecheck_table_init(st : TcState, y : ElemIdx, x : TableIdx) -> TcResult {
  let TableType(rt1, l) = match st.env.get_table_type(x) {
    None => return Err("invalid table index")
    Some(tt) => tt
  }
  let elem = match st.env.get_elem(y) {
    None => return Err("invalid elem segment index")
    Some(e) => e
  }
  let rt2 = elem_reftype(elem)
  if !Match::matches(rt2, rt1, st.env) {
    return Err("table.init elem segment type does not match table element type")
  }

  // Pop: len:i32, src:i32, dst:at  (LIFO order)
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(l.addr_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3)
}

///|
fn typecheck_table_fill(st : TcState, x : TableIdx) -> TcResult {
  let TableType(rt, lim) = match st.env.get_table_type(x) {
    None => return Err("invalid table index")
    Some(tt) => tt
  }

  // pop len : i32
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop val : rt
  let st2 = match st1.pop_expect(RefTypeValType(rt)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop start : at (derived from limits)
  let st3 = match st2.pop_expect(lim.addr_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3)
}

///|
fn typecheck_elem_drop(st : TcState, y : ElemIdx) -> TcResult {
  match st.env.get_elem(y) {
    None => Err("invalid elem segment index")
    Some(_) => Ok(st)
  }
}

// validates memarg and returns the chosen memory + its limits

///|
fn memarg_check(
  st : TcState,
  ma : MemArg,
  default_mem : MemIdx,
  nbits : Int,
) -> Result[(MemIdx, Limits), String] {
  let MemArg(U32(align_pow_u), mem_opt, U64(offset)) = ma
  let mem = match mem_opt {
    None => default_mem
    Some(m) => m
  }
  let MemType(lim) = match st.env.get_memtype(mem) {
    None => return Err("invalid memory index in memarg")
    Some(mt) => mt
  }

  // (1) alignment: 2^n <= N/8
  let max_align_bytes = nbits / 8
  if max_align_bytes <= 0 {
    return Err("invalid access width")
  }
  let align_pow = align_pow_u.reinterpret_as_int()
  if align_pow < 0 {
    return Err("negative alignment power")
  }
  if align_pow >= 64 {
    return Err("alignment too large")
  }
  let align_bytes : UInt64 = 1 << align_pow
  if align_bytes > max_align_bytes.to_uint64() {
    return Err("memarg alignment too large for access width")
  }

  // (2) offset: m < 2^|at|
  let bits = lim.mem_addr_bits()
  if bits == 32 {
    if offset >= 1 << 32 {
      return Err("memarg offset out of range for i32 memory")
    }
  } else {
    // i64 memory: offset is UInt64 so always < 2^64
    ()
  }
  Ok((mem, lim))
}

///|
fn typecheck_load(
  st : TcState,
  ma : MemArg,
  nbits : Int,
  result : ValType,
) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()
  let st1 = match st.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(result))
}

///|
fn typecheck_store(
  st : TcState,
  ma : MemArg,
  nbits : Int,
  value : ValType,
) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()

  // pop value first (top of stack)
  let st1 = match st.pop_expect(value) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop address
  let st2 = match st1.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2)
}

///|
fn typecheck_loop(st : TcState, bt : BlockType, body : Expr) -> TcResult {
  let (params, results) = match st.env.expand_blocktype(bt) {
    Err(e) => return Err(e)
    Ok(x) => x
  }

  // consume params
  let st1 = match st.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let base_len = st1.stack.length()

  // loop label is params (not results)
  let env2 = st1.env.with_label(params)
  let st_body0 = TcState::{ ..st1, env: env2 }
  let st_body = match body.typecheck(st_body0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // if reachable, enforce results on top
  let st2 = if st_body.reachable {
    match st_body.pop_types(results) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
  } else {
    st_body
  }

  // truncate back to base_len
  let stack2 = st2.stack.copy()
  while stack2.length() > base_len {
    ignore(stack2.pop())
  }

  // restore outer env (pop label scope)
  let out = TcState::{ env: st.env, stack: stack2, reachable: st2.reachable }
  Ok(out.push_types(results))
}

///|
fn typecheck_ref_null(st : TcState, ht : HeapType) -> TcResult {
  if ht.validate(st.env) is Err(t) {
    return Err(t)
  }
  Ok(st.push1(ref_null_valtype(ht)))
}

///|
fn typecheck_ref_is_null(st : TcState) -> TcResult {
  let (st1, v) = match st.pop1() {
    Err(e) => return Err(e)
    Ok(pair) => pair
  }
  match v {
    RefTypeValType(rt) => {
      if !rt.is_nullable() {
        return Err("ref.is_null expects a nullable reference")
      }
      Ok(st1.push1(NumTypeValType(I32NumType)))
    }
    _ => Err("ref.is_null expects a reference type")
  }
}

///|
fn typecheck_ref_func(st : TcState, f : FuncIdx) -> TcResult {
  if !st.env.has_func(f) {
    return Err("invalid function index")
  }
  Ok(st.push1(funcref_valtype()))
}

///|
fn typecheck_ref_as_non_null(st : TcState) -> TcResult {
  let (st1, v) = match st.pop1() {
    Err(e) => return Err(e)
    Ok(pair) => pair
  }
  match v {
    RefTypeValType(rt) =>
      match rt {
        HeapTypeRefType(true, ht) =>
          Ok(st1.push1(RefTypeValType(HeapTypeRefType(false, ht))))
        HeapTypeRefType(false, _) =>
          Err("ref.as_non_null expects (ref null ht), got non-null ref")
        AbsHeapTypeRefType(_) =>
          Err("ref.as_non_null expects (ref null ht), got abstract ref type")
      }
    _ => Err("ref.as_non_null expects a reference type")
  }
}

///|
fn typecheck_ref_eq(st : TcState) -> TcResult {
  // pop second operand
  let st1 = match st.pop_expect(eqref_null_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop first operand
  let st2 = match st1.pop_expect(eqref_null_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(NumTypeValType(I32NumType)))
}

///|
fn typecheck_ref_test(st : TcState, nullable : Bool, ht : HeapType) -> TcResult {
  let rt = HeapTypeRefType(nullable, ht)
  if rt.validate(st.env) is Err(t) {
    return Err("invalid ref.test target reftype: " + t)
  }
  let (st1, v) = match st.pop1() {
    Err(e) => return Err(e)
    Ok(pair) => pair
  }
  let rt_in = match v {
    RefTypeValType(r) => r
    _ => return Err("ref.test expects a reference operand")
  }

  // Spec: rt <: rt_in OR rt_in <: rt (types must be in same hierarchy)
  if not(Match::matches(rt, rt_in, st.env) || Match::matches(rt_in, rt, st.env)) {
    return Err("ref.test target does not match operand type")
  }
  Ok(st1.push1(NumTypeValType(I32NumType)))
}

///|
fn typecheck_ref_cast(st : TcState, nullable : Bool, ht : HeapType) -> TcResult {
  let rt = HeapTypeRefType(nullable, ht)
  if rt.validate(st.env) is Err(t) {
    return Err("invalid ref.cast target reftype: " + t)
  }
  let (st1, rt_in_opt) = match st.pop_ref_or_bot() {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  match rt_in_opt {
    None => ()
    Some(rt_in) =>
      if !Match::matches(rt, rt_in, st.env) {
        return Err("ref.cast target does not match operand type")
      }
  }
  Ok(st1.push1(RefTypeValType(rt)))
}

///|
fn typecheck_struct_new(st : TcState, x : TypeIdx) -> TcResult {
  let fields = match st.env.resolve_struct_fields(x) {
    Err(e) => return Err(e)
    Ok(fs) => fs
  }

  // Compute expected argument types: unpack(storage) for each field, in order.
  let args : Array[ValType] = []
  for f in fields {
    let FieldType(stor, _) = f
    args.push(unpack_storage(stor))
  }
  let st1 = match st.pop_types(args) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // push (ref x)
  Ok(st1.push1(RefTypeValType(HeapTypeRefType(false, HeapType(x)))))
}

///|
fn typecheck_struct_new_default(st : TcState, x : TypeIdx) -> TcResult {
  let fields = match st.env.resolve_struct_fields(x) {
    Err(e) => return Err(e)
    Ok(fs) => fs
  }
  for f in fields {
    let FieldType(stor, _) = f
    let vt = unpack_storage(stor)
    if !has_default(vt) {
      return Err("struct.new_default: no default for a non-null field type")
    }
  }
  Ok(st.push1(RefTypeValType(HeapTypeRefType(false, HeapType(x)))))
}

///|
fn typecheck_struct_get(st : TcState, x : TypeIdx, i : U32) -> TcResult {
  let fields = match st.env.resolve_struct_fields(x) {
    Err(e) => return Err(e)
    Ok(fs) => fs
  }
  let FieldType(stor, _) = match get_struct_field(fields, i) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  if is_packed(stor) {
    return Err(
      "struct.get used on packed field; use struct.get_s or struct.get_u",
    )
  }
  let st1 = match
    st.pop_expect(RefTypeValType(HeapTypeRefType(true, HeapType(x)))) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(unpack_storage(stor)))
}

///|
fn typecheck_struct_get_s(st : TcState, x : TypeIdx, i : U32) -> TcResult {
  let fields = match st.env.resolve_struct_fields(x) {
    Err(e) => return Err(e)
    Ok(fs) => fs
  }
  let FieldType(stor, _) = match get_struct_field(fields, i) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  if !is_packed(stor) {
    return Err("struct.get_s requires packed field")
  }
  let st1 = match
    st.pop_expect(RefTypeValType(HeapTypeRefType(true, HeapType(x)))) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(NumTypeValType(I32NumType)))
}

///|
fn typecheck_struct_get_u(st : TcState, x : TypeIdx, i : U32) -> TcResult {
  // identical checks, only semantics differ at runtime
  typecheck_struct_get_s(st, x, i)
}

///|
fn typecheck_struct_set(st : TcState, x : TypeIdx, i : U32) -> TcResult {
  let fields = match st.env.resolve_struct_fields(x) {
    Err(e) => return Err(e)
    Ok(fs) => fs
  }
  let ft = match get_struct_field(fields, i) {
    Err(e) => return Err(e)
    Ok(f) => f
  }
  if !field_is_mutable(ft) {
    return Err("struct.set on immutable field")
  }
  let FieldType(stor, _) = ft
  let val_ty = unpack_storage(stor)

  // pop value then ref
  let st1 = match st.pop_expect(val_ty) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match
    st1.pop_expect(RefTypeValType(HeapTypeRefType(true, HeapType(x)))) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2)
}

///|
fn typecheck_unary(st : TcState, t_in : ValType, t_out : ValType) -> TcResult {
  let st1 = match st.pop_expect(t_in) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(t_out))
}

///|
fn typecheck_binary(st : TcState, t : ValType, out : ValType) -> TcResult {
  let st1 = match st.pop_expect(t) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(t) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(out))
}

///|
fn typecheck_v128_ternary(st : TcState) -> TcResult {
  // v128 v128 v128 -> v128
  let st1 = match st.pop_expect(vt_v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(vt_v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(vt_v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3.push1(vt_v128()))
}

///|
fn typecheck_compare(st : TcState, t : ValType) -> TcResult {
  typecheck_binary(st, t, NumTypeValType(I32NumType))
}

///|
fn typecheck_v128_unary(st : TcState) -> TcResult {
  typecheck_unary(st, vt_v128(), vt_v128())
}

///|
fn typecheck_v128_binary(st : TcState) -> TcResult {
  typecheck_binary(st, vt_v128(), vt_v128())
}

///|
fn typecheck_v128_compare(st : TcState) -> TcResult {
  // v128 v128 -> v128 (SIMD comparisons produce v128 masks)
  typecheck_v128_binary(st)
}

///|
fn typecheck_v128_shift(st : TcState) -> TcResult {
  // v128 i32 -> v128 (shift count is i32)
  let st1 = match st.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(vt_v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(vt_v128()))
}

///|
fn typecheck_lane_extract(st : TcState, out : ValType) -> TcResult {
  // v128 -> out (lane index is an immediate, not on stack)
  let st1 = match st.pop_expect(vt_v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(out))
}

///|
fn typecheck_lane_replace(st : TcState, in_v : ValType) -> TcResult {
  // v128, in_v -> v128
  let st1 = match st.pop_expect(in_v) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(vt_v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(vt_v128()))
}

///|
fn typecheck_splat(st : TcState, in_v : ValType) -> TcResult {
  // in_v -> v128
  typecheck_unary(st, in_v, vt_v128())
}

///|
fn typecheck_v128_const(st : TcState) -> TcResult {
  Ok(st.push1(vt_v128()))
}

///|
fn typecheck_v128_mem_load(st : TcState, ma : MemArg, nbits : Int) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()
  let st1 = match st.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(VecTypeValType))
}

///|
fn typecheck_v128_mem_store(st : TcState, ma : MemArg, nbits : Int) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()

  // pop value first
  let st1 = match st.pop_expect(VecTypeValType) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop address
  let st2 = match st1.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2)
}

///|
fn typecheck_v128_mem_load_zero(
  st : TcState,
  ma : MemArg,
  nbits : Int,
) -> TcResult {
  typecheck_v128_mem_load(st, ma, nbits)
}

///|
fn typecheck_v128_load_lane(st : TcState, ma : MemArg, nbits : Int) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()

  // pop existing vector (top of stack)
  let st1 = match st.pop_expect(VecTypeValType) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop address
  let st2 = match st1.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(VecTypeValType))
}

///|
fn typecheck_v128_store_lane(
  st : TcState,
  ma : MemArg,
  nbits : Int,
) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()

  // pop vector (top of stack)
  let st1 = match st.pop_expect(VecTypeValType) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop address
  let st2 = match st1.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2)
}

///|
fn typecheck_v128_mem_load_splat(
  st : TcState,
  ma : MemArg,
  nbits : Int,
) -> TcResult {
  typecheck_v128_mem_load(st, ma, nbits)
}

///|
fn typecheck_v128_mem_load_extend64(st : TcState, ma : MemArg) -> TcResult {
  typecheck_v128_mem_load(st, ma, 64)
}

///|
fn typecheck_memory_size(st : TcState, mem : MemIdx) -> TcResult {
  let at = match st.mem_at_of(mem) {
    Err(e) => return Err(e)
    Ok(t) => t
  }
  Ok(st.push1(at))
}

///|
fn typecheck_memory_grow(st : TcState, mem : MemIdx) -> TcResult {
  let at = match st.mem_at_of(mem) {
    Err(e) => return Err(e)
    Ok(t) => t
  }
  let st1 = match st.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(at))
}

///|
fn typecheck_memory_init(
  st : TcState,
  data : DataIdx,
  mem : MemIdx,
) -> TcResult {
  if !st.env.has_data(data) {
    return Err("invalid data segment index")
  }
  let at = match st.mem_at_of(mem) {
    Err(e) => return Err(e)
    Ok(t) => t
  }

  // pop len:i32, src:i32, dst:at
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3)
}

///|
fn typecheck_data_drop(st : TcState, data : DataIdx) -> TcResult {
  if !st.env.has_data(data) {
    return Err("invalid data segment index")
  }
  Ok(st)
}

///|
fn typecheck_memory_copy(st : TcState, dst : MemIdx, src : MemIdx) -> TcResult {
  let MemType(lim1) = match st.env.get_memtype(dst) {
    None => return Err("invalid dest memory index")
    Some(mt) => mt
  }
  let MemType(lim2) = match st.env.get_memtype(src) {
    None => return Err("invalid src memory index")
    Some(mt) => mt
  }
  let at1 = lim1.addr_valtype()
  let at2 = lim2.addr_valtype()
  let at_len = min_addr_valtype(lim1, lim2)

  // pop len, src, dst
  let st1 = match st.pop_expect(at_len) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(at2) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(at1) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3)
}

///|
fn typecheck_memory_fill(st : TcState, mem : MemIdx) -> TcResult {
  let at = match st.mem_at_of(mem) {
    Err(e) => return Err(e)
    Ok(t) => t
  }

  // pop len:i32, val:i32, dst:at
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3)
}

///|
fn typecheck_any_convert_extern(st : TcState) -> TcResult {
  let st1 = match st.pop_expect(externref_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(anyref_valtype()))
}

///|
fn typecheck_extern_convert_any(st : TcState) -> TcResult {
  let st1 = match st.pop_expect(anyref_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(externref_valtype()))
}

///|
fn typecheck_ref_i31(st : TcState) -> TcResult {
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(i31ref_valtype()))
}

///|
fn typecheck_i31_get(st : TcState) -> TcResult {
  let st1 = match st.pop_expect(i31ref_nullable_valtype()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(NumTypeValType(I32NumType)))
}

///|
fn typecheck_array_new(st : TcState, x : TypeIdx) -> TcResult {
  let FieldType(sto, _) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  let elem_vt = unpack_storage(sto)

  // pop length : i32
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop init value : elem_vt
  let st2 = match st1.pop_expect(elem_vt) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ref_array_nonnull(x)))
}

///|
fn typecheck_array_new_default(st : TcState, x : TypeIdx) -> TcResult {
  let FieldType(sto, _) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  let elem_vt = unpack_storage(sto)
  if !has_default(elem_vt) {
    return Err("array.new_default: no default for element type")
  }
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ref_array_nonnull(x)))
}

///|
fn typecheck_array_new_fixed(st : TcState, x : TypeIdx, n : U32) -> TcResult {
  let FieldType(sto, _) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  let elem_vt = unpack_storage(sto)
  let U32(nu) = n
  let count = nu.reinterpret_as_int()
  if count < 0 {
    return Err("array.new_fixed: negative length")
  }
  let mut cur = st
  // pop count times
  for _ in 0..<count {
    cur = match cur.pop_expect(elem_vt) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
  }
  Ok(cur.push1(ref_array_nonnull(x)))
}

///|
fn typecheck_array_get(st : TcState, x : TypeIdx) -> TcResult {
  let FieldType(sto, _) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  if is_packed(sto) {
    return Err(
      "array.get used on packed element; use array.get_s or array.get_u",
    )
  }
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ref_array_nullable(x)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(unpack_storage(sto)))
}

///|
fn typecheck_array_get_s(st : TcState, x : TypeIdx) -> TcResult {
  let FieldType(sto, _) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  if !is_packed(sto) {
    return Err("array.get_s requires packed element type")
  }
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ref_array_nullable(x)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(NumTypeValType(I32NumType)))
}

///|
fn typecheck_array_get_u(st : TcState, x : TypeIdx) -> TcResult {
  // same typing as get_s
  typecheck_array_get_s(st, x)
}

///|
fn typecheck_array_set(st : TcState, x : TypeIdx) -> TcResult {
  let ft = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(f) => f
  }
  if !field_is_mutable(ft) {
    return Err("array.set on immutable array element type")
  }
  let FieldType(sto, _) = ft
  let elem_vt = unpack_storage(sto)

  // pop value
  let st1 = match st.pop_expect(elem_vt) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop index
  let st2 = match st1.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop array ref
  let st3 = match st2.pop_expect(ref_array_nullable(x)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3)
}

///|
fn typecheck_array_len(st : TcState) -> TcResult {
  let want = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(ArrayAbsHeapType)),
  )
  let st1 = match st.pop_expect(want) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(NumTypeValType(I32NumType)))
}

///|
fn typecheck_array_fill(st : TcState, x : TypeIdx) -> TcResult {
  let ft = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(f) => f
  }
  if !field_is_mutable(ft) {
    return Err("array.fill on immutable array element type")
  }
  let FieldType(sto, _) = ft
  let elem_vt = unpack_storage(sto)

  // pop len
  let st1 = match st.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop value
  let st2 = match st1.pop_expect(elem_vt) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop start
  let st3 = match st2.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop array ref
  let st4 = match st3.pop_expect(ref_null_array_of(x)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st4)
}

///|
fn typecheck_array_copy(st : TcState, x : TypeIdx, y : TypeIdx) -> TcResult {
  let ft_x = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(f) => f
  }
  let ft_y = match st.env.resolve_array_field(y) {
    Err(e) => return Err(e)
    Ok(f) => f
  }
  if !field_is_mutable(ft_x) {
    return Err("array.copy requires destination array to be mutable")
  }
  let FieldType(sto_x, _) = ft_x
  let FieldType(sto_y, _) = ft_y
  let vx = unpack_storage(sto_x)
  let vy = unpack_storage(sto_y)
  if !Match::matches(vy, vx, st.env) {
    return Err(
      "array.copy source element type does not match destination element type",
    )
  }

  // pop len
  let st = match st.pop_expect(vt_i32()) {
    Err(t) => return Err(t)
    Ok(t) => t
  }

  // pop src index
  let st = match st.pop_expect(vt_i32()) {
    Err(t) => return Err(t)
    Ok(t) => t
  }

  // pop src array
  let st = match st.pop_expect(ref_null_array_of(y)) {
    Err(t) => return Err(t)
    Ok(t) => t
  }

  // pop dst index
  let st = match st.pop_expect(vt_i32()) {
    Err(t) => return Err(t)
    Ok(t) => t
  }

  // pop dst array
  let st = match st.pop_expect(ref_null_array_of(x)) {
    Err(t) => return Err(t)
    Ok(t) => t
  }
  Ok(st)
}

///|
fn typecheck_array_init_data(
  st : TcState,
  x : TypeIdx,
  y : DataIdx,
) -> TcResult {
  if !st.env.has_data(y) {
    return Err("invalid data segment index")
  }
  let ft = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(f) => f
  }
  if !field_is_mutable(ft) {
    return Err("array.init_data requires array element to be mutable")
  }
  let FieldType(sto, _) = ft
  let vt = unpack_storage(sto)
  match vt {
    NumTypeValType(_) => ()
    VecTypeValType => ()
    _ =>
      return Err(
        "array.init_data requires unpack(element) to be numtype or vectype",
      )
  }

  // Stack: (ref null x) i32 i32 i32 -> ε
  // pop len, src, dst
  let st1 = match st.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop array ref
  let st4 = match st3.pop_expect(ref_null_array_of(x)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st4)
}

///|
fn typecheck_array_init_elem(
  st : TcState,
  x : TypeIdx,
  y : ElemIdx,
) -> TcResult {
  let elem = match st.env.get_elem(y) {
    None => return Err("invalid elem segment index")
    Some(e) => e
  }
  let ft = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(f) => f
  }
  if !field_is_mutable(ft) {
    return Err("array.init_elem requires array element to be mutable")
  }
  let FieldType(sto, _) = ft

  // Spec: C.elems[y] ≤ zt (storage type), so storage type must be a ref valtype.
  let rt_array = match sto {
    ValTypeStorageType(RefTypeValType(rt)) => rt
    _ =>
      return Err(
        "array.init_elem requires array storage type to be a reference type",
      )
  }
  let rt_seg = elem_reftype(elem)
  if !Match::matches(rt_seg, rt_array, st.env) {
    return Err(
      "array.init_elem elem segment type does not match array storage type",
    )
  }

  // Stack: (ref null x) i32 i32 i32 -> ε
  // pop len, src, dst
  let st1 = match st.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop array ref
  let st4 = match st3.pop_expect(ref_null_array_of(x)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st4)
}

///|
fn typecheck_array_new_elem(st : TcState, x : TypeIdx, y : ElemIdx) -> TcResult {
  let elem = match st.env.get_elem(y) {
    None => return Err("invalid elem segment index")
    Some(e) => e
  }
  let FieldType(sto, _mut) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  let rt_array = match sto {
    ValTypeStorageType(RefTypeValType(rt)) => rt
    _ =>
      return Err(
        "array.new_elem requires array element storage type to be a reftype",
      )
  }
  let rt_seg = elem_reftype(elem)
  if !Match::matches(rt_seg, rt_array, st.env) {
    return Err(
      "array.new_elem elem segment type does not match array element reftype",
    )
  }

  // Stack: i32 i32 -> (ref x)
  // (the two i32 are typically src and len; order doesn't matter for typing as both are i32)
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ref_array_nonnull(x)))
}

///|
fn typecheck_array_new_data(st : TcState, x : TypeIdx, y : DataIdx) -> TcResult {
  if !st.env.has_data(y) {
    return Err("invalid data segment index")
  }
  let FieldType(sto, _mut) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  let vt = unpack_storage(sto)
  match vt {
    NumTypeValType(_) => ()
    VecTypeValType => ()
    _ =>
      return Err(
        "array.new_data requires unpack(element) to be numtype or vectype",
      )
  }

  // Stack: i32 i32 -> (ref x)
  let st1 = match st.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(NumTypeValType(I32NumType)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ref_array_nonnull(x)))
}

///|
pub impl Typecheck for Instruction with typecheck(self, st) {
  match self {
    Unreachable => Ok(TcState::{ ..st, reachable: false })
    Nop => Ok(st)
    I32Const(_) => Ok(st.push1(NumTypeValType(I32NumType)))
    I64Const(_) => Ok(st.push1(NumTypeValType(I64NumType)))
    F32Const(_) => Ok(st.push1(NumTypeValType(F32NumType)))
    F64Const(_) => Ok(st.push1(NumTypeValType(F64NumType)))
    I32Load(ma) => typecheck_load(st, ma, 32, NumTypeValType(I32NumType))
    I64Load(ma) => typecheck_load(st, ma, 64, NumTypeValType(I64NumType))
    F32Load(ma) => typecheck_load(st, ma, 32, NumTypeValType(F32NumType))
    F64Load(ma) => typecheck_load(st, ma, 64, NumTypeValType(F64NumType))
    I32Load8S(ma) => typecheck_load(st, ma, 8, NumTypeValType(I32NumType))
    I32Load8U(ma) => typecheck_load(st, ma, 8, NumTypeValType(I32NumType))
    I32Load16S(ma) => typecheck_load(st, ma, 16, NumTypeValType(I32NumType))
    I32Load16U(ma) => typecheck_load(st, ma, 16, NumTypeValType(I32NumType))
    I64Load8S(ma) => typecheck_load(st, ma, 8, NumTypeValType(I64NumType))
    I64Load8U(ma) => typecheck_load(st, ma, 8, NumTypeValType(I64NumType))
    I64Load16S(ma) => typecheck_load(st, ma, 16, NumTypeValType(I64NumType))
    I64Load16U(ma) => typecheck_load(st, ma, 16, NumTypeValType(I64NumType))
    I64Load32S(ma) => typecheck_load(st, ma, 32, NumTypeValType(I64NumType))
    I64Load32U(ma) => typecheck_load(st, ma, 32, NumTypeValType(I64NumType))
    I32Store(ma) => typecheck_store(st, ma, 32, NumTypeValType(I32NumType))
    I64Store(ma) => typecheck_store(st, ma, 64, NumTypeValType(I64NumType))
    F32Store(ma) => typecheck_store(st, ma, 32, NumTypeValType(F32NumType))
    F64Store(ma) => typecheck_store(st, ma, 64, NumTypeValType(F64NumType))
    I32Store8(ma) => typecheck_store(st, ma, 8, NumTypeValType(I32NumType))
    I32Store16(ma) => typecheck_store(st, ma, 16, NumTypeValType(I32NumType))
    I64Store8(ma) => typecheck_store(st, ma, 8, NumTypeValType(I64NumType))
    I64Store16(ma) => typecheck_store(st, ma, 16, NumTypeValType(I64NumType))
    I64Store32(ma) => typecheck_store(st, ma, 32, NumTypeValType(I64NumType))
    Drop => typecheck_drop(st)
    Select(None) => typecheck_select_untyped(st)
    Select(Some(ts)) => typecheck_select_typed(st, ts)
    LocalGet(i) => typecheck_local_get(st, i)
    LocalSet(i) => typecheck_local_set(st, i)
    LocalTee(i) => typecheck_local_tee(st, i)
    GlobalGet(i) => typecheck_global_get(st, i)
    GlobalSet(i) => typecheck_global_set(st, i)
    TableGet(i) => typecheck_table_get(st, i)
    TableSet(i) => typecheck_table_set(st, i)
    TableSize(i) => typecheck_table_size(st, i)
    TableGrow(i) => typecheck_table_grow(st, i)
    TableCopy(i0, i1) => typecheck_table_copy(st, i0, i1)
    TableInit(x, y) => typecheck_table_init(st, x, y)
    TableFill(x) => typecheck_table_fill(st, x)
    ElemDrop(y) => typecheck_elem_drop(st, y)
    MemorySize(m) => typecheck_memory_size(st, m)
    MemoryGrow(m) => typecheck_memory_grow(st, m)
    MemoryInit(d, m) => typecheck_memory_init(st, d, m)
    DataDrop(d) => typecheck_data_drop(st, d)
    MemoryCopy(d, s) => typecheck_memory_copy(st, d, s)
    MemoryFill(m) => typecheck_memory_fill(st, m)
    Br(l) => typecheck_br(st, l)
    Block(bt, e) => typecheck_block(st, bt, e)
    If(bt, th, el) => typecheck_if(st, bt, th, el)
    BrIf(l) => typecheck_br_if(st, l)
    BrTable(ls, ldef) => typecheck_br_table(st, ls, ldef)
    BrOnNull(l) => typecheck_br_on_null(st, l)
    BrOnNonNull(l) => typecheck_br_on_non_null(st, l)
    BrOnCast(l, op, ht1, ht2) => typecheck_br_on_cast(st, l, op, ht1, ht2)
    BrOnCastFail(l, op, ht1, ht2) =>
      typecheck_br_on_cast_fail(st, l, op, ht1, ht2)
    Return => typecheck_return(st)
    Call(f) => typecheck_call(st, f)
    CallIndirect(tidx, t) => typecheck_call_indirect(st, tidx, t)
    CallRef(tidx) => typecheck_call_ref(st, tidx)
    ReturnCall(fidx) => typecheck_return_call(st, fidx)
    ReturnCallIndirect(tidx, t) => typecheck_return_call_indirect(st, tidx, t)
    ReturnCallRef(tidx) => typecheck_return_call_ref(st, tidx)
    Throw(t) => typecheck_throw(st, t)
    ThrowRef => typecheck_throw_ref(st)
    TryTable(bt, cs, e) => typecheck_try_table(st, bt, cs, e)
    Loop(bt, e) => typecheck_loop(st, bt, e)
    RefNull(ht) => typecheck_ref_null(st, ht)
    RefIsNull => typecheck_ref_is_null(st)
    RefFunc(f) => typecheck_ref_func(st, f)
    RefAsNonNull => typecheck_ref_as_non_null(st)
    RefEq => typecheck_ref_eq(st)
    RefTest(nullable, ht) => typecheck_ref_test(st, nullable, ht)
    RefCast(nullable, ht) => typecheck_ref_cast(st, nullable, ht)
    AnyConvertExtern => typecheck_any_convert_extern(st)
    ExternConvertAny => typecheck_extern_convert_any(st)
    RefI31 => typecheck_ref_i31(st)
    I31GetS => typecheck_i31_get(st)
    I31GetU => typecheck_i31_get(st)
    StructNew(x) => typecheck_struct_new(st, x)
    StructNewDefault(x) => typecheck_struct_new_default(st, x)
    StructGet(x, i) => typecheck_struct_get(st, x, i)
    StructGetS(x, i) => typecheck_struct_get_s(st, x, i)
    StructGetU(x, i) => typecheck_struct_get_u(st, x, i)
    StructSet(x, i) => typecheck_struct_set(st, x, i)
    ArrayNew(x) => typecheck_array_new(st, x)
    ArrayNewDefault(x) => typecheck_array_new_default(st, x)
    ArrayNewFixed(x, n) => typecheck_array_new_fixed(st, x, n)
    ArrayGet(x) => typecheck_array_get(st, x)
    ArrayGetS(x) => typecheck_array_get_s(st, x)
    ArrayGetU(x) => typecheck_array_get_u(st, x)
    ArraySet(x) => typecheck_array_set(st, x)
    ArrayLen => typecheck_array_len(st)
    ArrayFill(x) => typecheck_array_fill(st, x)
    ArrayCopy(x, y) => typecheck_array_copy(st, x, y)
    ArrayInitData(x, y) => typecheck_array_init_data(st, x, y)
    ArrayInitElem(x, y) => typecheck_array_init_elem(st, x, y)
    ArrayNewElem(x, y) => typecheck_array_new_elem(st, x, y)
    ArrayNewData(x, y) => typecheck_array_new_data(st, x, y)

    // ===== i32 relational =====
    I32Eqz => typecheck_unary(st, vt_i32(), vt_i32())
    I32Eq => typecheck_compare(st, vt_i32())
    I32Ne => typecheck_compare(st, vt_i32())
    I32LtS => typecheck_compare(st, vt_i32())
    I32LtU => typecheck_compare(st, vt_i32())
    I32GtS => typecheck_compare(st, vt_i32())
    I32GtU => typecheck_compare(st, vt_i32())
    I32LeS => typecheck_compare(st, vt_i32())
    I32LeU => typecheck_compare(st, vt_i32())
    I32GeS => typecheck_compare(st, vt_i32())
    I32GeU => typecheck_compare(st, vt_i32())

    // ===== i64 relational =====
    I64Eqz => typecheck_unary(st, vt_i64(), vt_i32())
    I64Eq => typecheck_compare(st, vt_i64())
    I64Ne => typecheck_compare(st, vt_i64())
    I64LtS => typecheck_compare(st, vt_i64())
    I64LtU => typecheck_compare(st, vt_i64())
    I64GtS => typecheck_compare(st, vt_i64())
    I64GtU => typecheck_compare(st, vt_i64())
    I64LeS => typecheck_compare(st, vt_i64())
    I64LeU => typecheck_compare(st, vt_i64())
    I64GeS => typecheck_compare(st, vt_i64())
    I64GeU => typecheck_compare(st, vt_i64())

    // ===== f32 relational =====
    F32Eq => typecheck_compare(st, vt_f32())
    F32Ne => typecheck_compare(st, vt_f32())
    F32Lt => typecheck_compare(st, vt_f32())
    F32Gt => typecheck_compare(st, vt_f32())
    F32Le => typecheck_compare(st, vt_f32())
    F32Ge => typecheck_compare(st, vt_f32())

    // ===== f64 relational =====
    F64Eq => typecheck_compare(st, vt_f64())
    F64Ne => typecheck_compare(st, vt_f64())
    F64Lt => typecheck_compare(st, vt_f64())
    F64Gt => typecheck_compare(st, vt_f64())
    F64Le => typecheck_compare(st, vt_f64())
    F64Ge => typecheck_compare(st, vt_f64())

    // ===== i32 unary =====
    I32Clz => typecheck_unary(st, vt_i32(), vt_i32())
    I32Ctz => typecheck_unary(st, vt_i32(), vt_i32())
    I32Popcnt => typecheck_unary(st, vt_i32(), vt_i32())

    // ===== i64 unary =====
    I64Clz => typecheck_unary(st, vt_i64(), vt_i64())
    I64Ctz => typecheck_unary(st, vt_i64(), vt_i64())
    I64Popcnt => typecheck_unary(st, vt_i64(), vt_i64())

    // ===== i32 binary =====
    I32Add => typecheck_binary(st, vt_i32(), vt_i32())
    I32Sub => typecheck_binary(st, vt_i32(), vt_i32())
    I32Mul => typecheck_binary(st, vt_i32(), vt_i32())
    I32DivS => typecheck_binary(st, vt_i32(), vt_i32())
    I32DivU => typecheck_binary(st, vt_i32(), vt_i32())
    I32RemS => typecheck_binary(st, vt_i32(), vt_i32())
    I32RemU => typecheck_binary(st, vt_i32(), vt_i32())
    I32And => typecheck_binary(st, vt_i32(), vt_i32())
    I32Or => typecheck_binary(st, vt_i32(), vt_i32())
    I32Xor => typecheck_binary(st, vt_i32(), vt_i32())
    I32Shl => typecheck_binary(st, vt_i32(), vt_i32())
    I32ShrS => typecheck_binary(st, vt_i32(), vt_i32())
    I32ShrU => typecheck_binary(st, vt_i32(), vt_i32())
    I32Rotl => typecheck_binary(st, vt_i32(), vt_i32())
    I32Rotr => typecheck_binary(st, vt_i32(), vt_i32())

    // ===== i64 binary =====
    I64Add => typecheck_binary(st, vt_i64(), vt_i64())
    I64Sub => typecheck_binary(st, vt_i64(), vt_i64())
    I64Mul => typecheck_binary(st, vt_i64(), vt_i64())
    I64DivS => typecheck_binary(st, vt_i64(), vt_i64())
    I64DivU => typecheck_binary(st, vt_i64(), vt_i64())
    I64RemS => typecheck_binary(st, vt_i64(), vt_i64())
    I64RemU => typecheck_binary(st, vt_i64(), vt_i64())
    I64And => typecheck_binary(st, vt_i64(), vt_i64())
    I64Or => typecheck_binary(st, vt_i64(), vt_i64())
    I64Xor => typecheck_binary(st, vt_i64(), vt_i64())
    I64Shl => typecheck_binary(st, vt_i64(), vt_i64())
    I64ShrS => typecheck_binary(st, vt_i64(), vt_i64())
    I64ShrU => typecheck_binary(st, vt_i64(), vt_i64())
    I64Rotl => typecheck_binary(st, vt_i64(), vt_i64())
    I64Rotr => typecheck_binary(st, vt_i64(), vt_i64())

    // ===== f32 unary =====
    F32Abs => typecheck_unary(st, vt_f32(), vt_f32())
    F32Neg => typecheck_unary(st, vt_f32(), vt_f32())
    F32Ceil => typecheck_unary(st, vt_f32(), vt_f32())
    F32Floor => typecheck_unary(st, vt_f32(), vt_f32())
    F32Trunc => typecheck_unary(st, vt_f32(), vt_f32())
    F32Nearest => typecheck_unary(st, vt_f32(), vt_f32())
    F32Sqrt => typecheck_unary(st, vt_f32(), vt_f32())

    // ===== f32 binary =====
    F32Add => typecheck_binary(st, vt_f32(), vt_f32())
    F32Sub => typecheck_binary(st, vt_f32(), vt_f32())
    F32Mul => typecheck_binary(st, vt_f32(), vt_f32())
    F32Div => typecheck_binary(st, vt_f32(), vt_f32())
    F32Min => typecheck_binary(st, vt_f32(), vt_f32())
    F32Max => typecheck_binary(st, vt_f32(), vt_f32())
    F32Copysign => typecheck_binary(st, vt_f32(), vt_f32())

    // ===== f64 unary =====
    F64Abs => typecheck_unary(st, vt_f64(), vt_f64())
    F64Neg => typecheck_unary(st, vt_f64(), vt_f64())
    F64Ceil => typecheck_unary(st, vt_f64(), vt_f64())
    F64Floor => typecheck_unary(st, vt_f64(), vt_f64())
    F64Trunc => typecheck_unary(st, vt_f64(), vt_f64())
    F64Nearest => typecheck_unary(st, vt_f64(), vt_f64())
    F64Sqrt => typecheck_unary(st, vt_f64(), vt_f64())

    // ===== f64 binary =====
    F64Add => typecheck_binary(st, vt_f64(), vt_f64())
    F64Sub => typecheck_binary(st, vt_f64(), vt_f64())
    F64Mul => typecheck_binary(st, vt_f64(), vt_f64())
    F64Div => typecheck_binary(st, vt_f64(), vt_f64())
    F64Min => typecheck_binary(st, vt_f64(), vt_f64())
    F64Max => typecheck_binary(st, vt_f64(), vt_f64())
    F64Copysign => typecheck_binary(st, vt_f64(), vt_f64())

    // ===== conversions / reinterprets =====

    // i32.wrap_i64 : i64 -> i32
    I32WrapI64 => typecheck_unary(st, vt_i64(), vt_i32())

    // i32.trunc_f32/f64_{s,u} : f32/f64 -> i32
    I32TruncF32S => typecheck_unary(st, vt_f32(), vt_i32())
    I32TruncF32U => typecheck_unary(st, vt_f32(), vt_i32())
    I32TruncF64S => typecheck_unary(st, vt_f64(), vt_i32())
    I32TruncF64U => typecheck_unary(st, vt_f64(), vt_i32())

    // i64.extend_i32_{s,u} : i32 -> i64
    I64ExtendI32S => typecheck_unary(st, vt_i32(), vt_i64())
    I64ExtendI32U => typecheck_unary(st, vt_i32(), vt_i64())

    // i64.trunc_f32/f64_{s,u} : f32/f64 -> i64
    I64TruncF32S => typecheck_unary(st, vt_f32(), vt_i64())
    I64TruncF32U => typecheck_unary(st, vt_f32(), vt_i64())
    I64TruncF64S => typecheck_unary(st, vt_f64(), vt_i64())
    I64TruncF64U => typecheck_unary(st, vt_f64(), vt_i64())

    // f32.convert_i32/i64_{s,u} : i32/i64 -> f32
    F32ConvertI32S => typecheck_unary(st, vt_i32(), vt_f32())
    F32ConvertI32U => typecheck_unary(st, vt_i32(), vt_f32())
    F32ConvertI64S => typecheck_unary(st, vt_i64(), vt_f32())
    F32ConvertI64U => typecheck_unary(st, vt_i64(), vt_f32())

    // f32.demote_f64 : f64 -> f32
    F32DemoteF64 => typecheck_unary(st, vt_f64(), vt_f32())

    // f64.convert_i32/i64_{s,u} : i32/i64 -> f64
    F64ConvertI32S => typecheck_unary(st, vt_i32(), vt_f64())
    F64ConvertI32U => typecheck_unary(st, vt_i32(), vt_f64())
    F64ConvertI64S => typecheck_unary(st, vt_i64(), vt_f64())
    F64ConvertI64U => typecheck_unary(st, vt_i64(), vt_f64())

    // f64.promote_f32 : f32 -> f64
    F64PromoteF32 => typecheck_unary(st, vt_f32(), vt_f64())

    // reinterprets
    I32ReinterpretF32 => typecheck_unary(st, vt_f32(), vt_i32())
    I64ReinterpretF64 => typecheck_unary(st, vt_f64(), vt_i64())
    F32ReinterpretI32 => typecheck_unary(st, vt_i32(), vt_f32())
    F64ReinterpretI64 => typecheck_unary(st, vt_i64(), vt_f64())

    // sign-extension (unary)
    I32Extend8S => typecheck_unary(st, vt_i32(), vt_i32())
    I32Extend16S => typecheck_unary(st, vt_i32(), vt_i32())
    I64Extend8S => typecheck_unary(st, vt_i64(), vt_i64())
    I64Extend16S => typecheck_unary(st, vt_i64(), vt_i64())
    I64Extend32S => typecheck_unary(st, vt_i64(), vt_i64())

    // saturating trunc (same typing as trunc)
    I32TruncSatF32S => typecheck_unary(st, vt_f32(), vt_i32())
    I32TruncSatF32U => typecheck_unary(st, vt_f32(), vt_i32())
    I32TruncSatF64S => typecheck_unary(st, vt_f64(), vt_i32())
    I32TruncSatF64U => typecheck_unary(st, vt_f64(), vt_i32())
    I64TruncSatF32S => typecheck_unary(st, vt_f32(), vt_i64())
    I64TruncSatF32U => typecheck_unary(st, vt_f32(), vt_i64())
    I64TruncSatF64S => typecheck_unary(st, vt_f64(), vt_i64())
    I64TruncSatF64U => typecheck_unary(st, vt_f64(), vt_i64())
    V128Not => typecheck_v128_unary(st)
    V128And => typecheck_v128_binary(st)
    V128Andnot => typecheck_v128_binary(st)
    V128Or => typecheck_v128_binary(st)
    V128Xor => typecheck_v128_binary(st)
    V128Bitselect => typecheck_v128_ternary(st)
    V128AnyTrue => typecheck_unary(st, vt_v128(), vt_i32())

    // Plain v128 load/store
    V128Load(ma) => typecheck_v128_mem_load(st, ma, 128)
    V128Store(ma) => typecheck_v128_mem_store(st, ma, 128)

    // Load and extend (64-bit loads)
    V128Load8x8S(ma) => typecheck_v128_mem_load_extend64(st, ma)
    V128Load8x8U(ma) => typecheck_v128_mem_load_extend64(st, ma)
    V128Load16x4S(ma) => typecheck_v128_mem_load_extend64(st, ma)
    V128Load16x4U(ma) => typecheck_v128_mem_load_extend64(st, ma)
    V128Load32x2S(ma) => typecheck_v128_mem_load_extend64(st, ma)
    V128Load32x2U(ma) => typecheck_v128_mem_load_extend64(st, ma)

    // Splat loads
    V128Load8Splat(ma) => typecheck_v128_mem_load_splat(st, ma, 8)
    V128Load16Splat(ma) => typecheck_v128_mem_load_splat(st, ma, 16)
    V128Load32Splat(ma) => typecheck_v128_mem_load_splat(st, ma, 32)
    V128Load64Splat(ma) => typecheck_v128_mem_load_splat(st, ma, 64)

    // Lane loads
    V128Load8Lane(ma, _) => typecheck_v128_load_lane(st, ma, 8)
    V128Load16Lane(ma, _) => typecheck_v128_load_lane(st, ma, 16)
    V128Load32Lane(ma, _) => typecheck_v128_load_lane(st, ma, 32)
    V128Load64Lane(ma, _) => typecheck_v128_load_lane(st, ma, 64)

    // Lane stores
    V128Store8Lane(ma, _) => typecheck_v128_store_lane(st, ma, 8)
    V128Store16Lane(ma, _) => typecheck_v128_store_lane(st, ma, 16)
    V128Store32Lane(ma, _) => typecheck_v128_store_lane(st, ma, 32)
    V128Store64Lane(ma, _) => typecheck_v128_store_lane(st, ma, 64)

    // load*_zero
    V128Load32Zero(ma) => typecheck_v128_mem_load_zero(st, ma, 32)
    V128Load64Zero(ma) => typecheck_v128_mem_load_zero(st, ma, 64)
    V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      typecheck_v128_const(st)
    I8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      // v128 v128 -> v128
      typecheck_v128_binary(st)
    I8x16Swizzle => typecheck_v128_binary(st) // v128 v128 -> v128
    I8x16Splat => typecheck_splat(st, vt_i32()) // i32 -> v128 (only low 8 bits used)
    I16x8Splat => typecheck_splat(st, vt_i32()) // i32 -> v128
    I32x4Splat => typecheck_splat(st, vt_i32()) // i32 -> v128
    I64x2Splat => typecheck_splat(st, vt_i64()) // i64 -> v128
    F32x4Splat => typecheck_splat(st, vt_f32()) // f32 -> v128
    F64x2Splat => typecheck_splat(st, vt_f64()) // f64 -> v128
    I8x16ExtractLaneS(_) => typecheck_lane_extract(st, vt_i32())
    I8x16ExtractLaneU(_) => typecheck_lane_extract(st, vt_i32())
    I16x8ExtractLaneS(_) => typecheck_lane_extract(st, vt_i32())
    I16x8ExtractLaneU(_) => typecheck_lane_extract(st, vt_i32())
    I32x4ExtractLane(_) => typecheck_lane_extract(st, vt_i32())
    I64x2ExtractLane(_) => typecheck_lane_extract(st, vt_i64())
    F32x4ExtractLane(_) => typecheck_lane_extract(st, vt_f32())
    F64x2ExtractLane(_) => typecheck_lane_extract(st, vt_f64())
    I8x16ReplaceLane(_) => typecheck_lane_replace(st, vt_i32())
    I16x8ReplaceLane(_) => typecheck_lane_replace(st, vt_i32())
    I32x4ReplaceLane(_) => typecheck_lane_replace(st, vt_i32())
    I64x2ReplaceLane(_) => typecheck_lane_replace(st, vt_i64())
    F32x4ReplaceLane(_) => typecheck_lane_replace(st, vt_f32())
    F64x2ReplaceLane(_) => typecheck_lane_replace(st, vt_f64())
    I8x16Eq => typecheck_v128_compare(st)
    I8x16Ne => typecheck_v128_compare(st)
    I8x16LtS => typecheck_v128_compare(st)
    I8x16LtU => typecheck_v128_compare(st)
    I8x16GtS => typecheck_v128_compare(st)
    I8x16GtU => typecheck_v128_compare(st)
    I8x16LeS => typecheck_v128_compare(st)
    I8x16LeU => typecheck_v128_compare(st)
    I8x16GeS => typecheck_v128_compare(st)
    I8x16GeU => typecheck_v128_compare(st)
    I16x8Eq => typecheck_v128_compare(st)
    I16x8Ne => typecheck_v128_compare(st)
    I16x8LtS => typecheck_v128_compare(st)
    I16x8LtU => typecheck_v128_compare(st)
    I16x8GtS => typecheck_v128_compare(st)
    I16x8GtU => typecheck_v128_compare(st)
    I16x8LeS => typecheck_v128_compare(st)
    I16x8LeU => typecheck_v128_compare(st)
    I16x8GeS => typecheck_v128_compare(st)
    I16x8GeU => typecheck_v128_compare(st)
    I32x4Eq => typecheck_v128_compare(st)
    I32x4Ne => typecheck_v128_compare(st)
    I32x4LtS => typecheck_v128_compare(st)
    I32x4LtU => typecheck_v128_compare(st)
    I32x4GtS => typecheck_v128_compare(st)
    I32x4GtU => typecheck_v128_compare(st)
    I32x4LeS => typecheck_v128_compare(st)
    I32x4LeU => typecheck_v128_compare(st)
    I32x4GeS => typecheck_v128_compare(st)
    I32x4GeU => typecheck_v128_compare(st)
    F32x4Eq => typecheck_v128_compare(st)
    F32x4Ne => typecheck_v128_compare(st)
    F32x4Lt => typecheck_v128_compare(st)
    F32x4Gt => typecheck_v128_compare(st)
    F32x4Le => typecheck_v128_compare(st)
    F32x4Ge => typecheck_v128_compare(st)
    F64x2Eq => typecheck_v128_compare(st)
    F64x2Ne => typecheck_v128_compare(st)
    F64x2Lt => typecheck_v128_compare(st)
    F64x2Gt => typecheck_v128_compare(st)
    F64x2Le => typecheck_v128_compare(st)
    F64x2Ge => typecheck_v128_compare(st)
    I8x16Abs => typecheck_v128_unary(st)
    I8x16Neg => typecheck_v128_unary(st)
    I8x16Popcnt => typecheck_v128_unary(st)
    I8x16AllTrue => typecheck_unary(st, vt_v128(), vt_i32())
    I8x16Bitmask => typecheck_unary(st, vt_v128(), vt_i32())
    I8x16NarrowI16x8S => typecheck_v128_binary(st)
    I8x16NarrowI16x8U => typecheck_v128_binary(st)
    I8x16Shl => typecheck_v128_shift(st)
    I8x16ShrS => typecheck_v128_shift(st)
    I8x16ShrU => typecheck_v128_shift(st)
    I8x16Add => typecheck_v128_binary(st)
    I8x16AddSatS => typecheck_v128_binary(st)
    I8x16AddSatU => typecheck_v128_binary(st)
    I8x16Sub => typecheck_v128_binary(st)
    I8x16SubSatS => typecheck_v128_binary(st)
    I8x16SubSatU => typecheck_v128_binary(st)
    I8x16MinS => typecheck_v128_binary(st)
    I8x16MinU => typecheck_v128_binary(st)
    I8x16MaxS => typecheck_v128_binary(st)
    I8x16MaxU => typecheck_v128_binary(st)
    I8x16AvgrU => typecheck_v128_binary(st)
    I16x8Abs => typecheck_v128_unary(st)
    I16x8Neg => typecheck_v128_unary(st)
    I16x8Q15mulrSatS => typecheck_v128_binary(st)
    I16x8AllTrue => typecheck_unary(st, vt_v128(), vt_i32())
    I16x8Bitmask => typecheck_unary(st, vt_v128(), vt_i32())
    I16x8NarrowI32x4S => typecheck_v128_binary(st)
    I16x8NarrowI32x4U => typecheck_v128_binary(st)
    I16x8ExtendLowI8x16S => typecheck_v128_unary(st)
    I16x8ExtendHighI8x16S => typecheck_v128_unary(st)
    I16x8ExtendLowI8x16U => typecheck_v128_unary(st)
    I16x8ExtendHighI8x16U => typecheck_v128_unary(st)
    I16x8Shl => typecheck_v128_shift(st)
    I16x8ShrS => typecheck_v128_shift(st)
    I16x8ShrU => typecheck_v128_shift(st)
    I16x8Add => typecheck_v128_binary(st)
    I16x8AddSatS => typecheck_v128_binary(st)
    I16x8AddSatU => typecheck_v128_binary(st)
    I16x8Sub => typecheck_v128_binary(st)
    I16x8SubSatS => typecheck_v128_binary(st)
    I16x8SubSatU => typecheck_v128_binary(st)
    I16x8Mul => typecheck_v128_binary(st)
    I16x8MinS => typecheck_v128_binary(st)
    I16x8MinU => typecheck_v128_binary(st)
    I16x8MaxS => typecheck_v128_binary(st)
    I16x8MaxU => typecheck_v128_binary(st)
    I16x8AvgrU => typecheck_v128_binary(st)
    I32x4Abs => typecheck_v128_unary(st)
    I32x4Neg => typecheck_v128_unary(st)
    I32x4AllTrue => typecheck_unary(st, vt_v128(), vt_i32())
    I32x4Bitmask => typecheck_unary(st, vt_v128(), vt_i32())
    I32x4ExtendLowI16x8S => typecheck_v128_unary(st)
    I32x4ExtendHighI16x8S => typecheck_v128_unary(st)
    I32x4ExtendLowI16x8U => typecheck_v128_unary(st)
    I32x4ExtendHighI16x8U => typecheck_v128_unary(st)
    I32x4Shl => typecheck_v128_shift(st)
    I32x4ShrS => typecheck_v128_shift(st)
    I32x4ShrU => typecheck_v128_shift(st)
    I32x4Add => typecheck_v128_binary(st)
    I32x4Sub => typecheck_v128_binary(st)
    I32x4Mul => typecheck_v128_binary(st)
    I32x4MinS => typecheck_v128_binary(st)
    I32x4MinU => typecheck_v128_binary(st)
    I32x4MaxS => typecheck_v128_binary(st)
    I32x4MaxU => typecheck_v128_binary(st)
    I32x4DotI16x8S => typecheck_v128_binary(st)
    I64x2Abs => typecheck_v128_unary(st)
    I64x2Neg => typecheck_v128_unary(st)
    I64x2AllTrue => typecheck_unary(st, vt_v128(), vt_i32())
    I64x2Bitmask => typecheck_unary(st, vt_v128(), vt_i32())
    I64x2Shl => typecheck_v128_shift(st)
    I64x2ShrS => typecheck_v128_shift(st)
    I64x2ShrU => typecheck_v128_shift(st)
    I64x2Add => typecheck_v128_binary(st)
    I64x2Sub => typecheck_v128_binary(st)
    I64x2Mul => typecheck_v128_binary(st)
    I64x2Eq => typecheck_v128_compare(st)
    I64x2Ne => typecheck_v128_compare(st)
    I64x2LtS => typecheck_v128_compare(st)
    I64x2GtS => typecheck_v128_compare(st)
    I64x2LeS => typecheck_v128_compare(st)
    I64x2GeS => typecheck_v128_compare(st)
    F32x4Abs => typecheck_v128_unary(st)
    F32x4Neg => typecheck_v128_unary(st)
    F32x4Sqrt => typecheck_v128_unary(st)
    F32x4Add => typecheck_v128_binary(st)
    F32x4Sub => typecheck_v128_binary(st)
    F32x4Mul => typecheck_v128_binary(st)
    F32x4Div => typecheck_v128_binary(st)
    F32x4Min => typecheck_v128_binary(st)
    F32x4Max => typecheck_v128_binary(st)
    F32x4Pmin => typecheck_v128_binary(st)
    F32x4Pmax => typecheck_v128_binary(st)
    F32x4Ceil => typecheck_v128_unary(st)
    F32x4Floor => typecheck_v128_unary(st)
    F32x4Trunc => typecheck_v128_unary(st)
    F32x4Nearest => typecheck_v128_unary(st)
    F64x2Abs => typecheck_v128_unary(st)
    F64x2Neg => typecheck_v128_unary(st)
    F64x2Sqrt => typecheck_v128_unary(st)
    F64x2Add => typecheck_v128_binary(st)
    F64x2Sub => typecheck_v128_binary(st)
    F64x2Mul => typecheck_v128_binary(st)
    F64x2Div => typecheck_v128_binary(st)
    F64x2Min => typecheck_v128_binary(st)
    F64x2Max => typecheck_v128_binary(st)
    F64x2Pmin => typecheck_v128_binary(st)
    F64x2Pmax => typecheck_v128_binary(st)
    F64x2Ceil => typecheck_v128_unary(st)
    F64x2Floor => typecheck_v128_unary(st)
    F64x2Trunc => typecheck_v128_unary(st)
    F64x2Nearest => typecheck_v128_unary(st)
    I32x4TruncSatF32x4S => typecheck_v128_unary(st)
    I32x4TruncSatF32x4U => typecheck_v128_unary(st)
    F32x4ConvertI32x4S => typecheck_v128_unary(st)
    F32x4ConvertI32x4U => typecheck_v128_unary(st)
    I32x4TruncSatF64x2SZero => typecheck_v128_unary(st)
    I32x4TruncSatF64x2UZero => typecheck_v128_unary(st)
    F64x2ConvertLowI32x4S => typecheck_v128_unary(st)
    F64x2ConvertLowI32x4U => typecheck_v128_unary(st)
    F32x4DemoteF64x2Zero => typecheck_v128_unary(st)
    F64x2PromoteLowF32x4 => typecheck_v128_unary(st)
    I8x16RelaxedSwizzle => typecheck_v128_binary(st)
    I32x4RelaxedTruncF32x4S => typecheck_v128_unary(st)
    I32x4RelaxedTruncF32x4U => typecheck_v128_unary(st)
    I32x4RelaxedTruncZeroF64x2S => typecheck_v128_unary(st)
    I32x4RelaxedTruncZeroF64x2U => typecheck_v128_unary(st)
    F32x4RelaxedMadd => typecheck_v128_ternary(st)
    F32x4RelaxedNmadd => typecheck_v128_ternary(st)
    F64x2RelaxedMadd => typecheck_v128_ternary(st)
    F64x2RelaxedNmadd => typecheck_v128_ternary(st)
    I8x16RelaxedLaneselect => typecheck_v128_ternary(st)
    I16x8RelaxedLaneselect => typecheck_v128_ternary(st)
    I32x4RelaxedLaneselect => typecheck_v128_ternary(st)
    I64x2RelaxedLaneselect => typecheck_v128_ternary(st)
    F32x4RelaxedMin => typecheck_v128_binary(st)
    F32x4RelaxedMax => typecheck_v128_binary(st)
    F64x2RelaxedMin => typecheck_v128_binary(st)
    F64x2RelaxedMax => typecheck_v128_binary(st)
    I16x8RelaxedQ15mulrS => typecheck_v128_binary(st)
    I16x8RelaxedDotI8x16I7x16S => typecheck_v128_binary(st)
    I32x4RelaxedDotI8x16I7x16AddS => typecheck_v128_ternary(st)

    // ===== extadd pairwise (unary) =====
    I16x8ExtaddPairwiseI8x16S => typecheck_v128_unary(st)
    I16x8ExtaddPairwiseI8x16U => typecheck_v128_unary(st)
    I32x4ExtaddPairwiseI16x8S => typecheck_v128_unary(st)
    I32x4ExtaddPairwiseI16x8U => typecheck_v128_unary(st)

    // ===== extend (unary) =====
    I64x2ExtendLowI32x4S => typecheck_v128_unary(st)
    I64x2ExtendLowI32x4U => typecheck_v128_unary(st)
    I64x2ExtendHighI32x4S => typecheck_v128_unary(st)
    I64x2ExtendHighI32x4U => typecheck_v128_unary(st)

    // ===== extmul low/high (binary) =====
    I16x8ExtmulLowI8x16S => typecheck_v128_binary(st)
    I16x8ExtmulLowI8x16U => typecheck_v128_binary(st)
    I16x8ExtmulHighI8x16S => typecheck_v128_binary(st)
    I16x8ExtmulHighI8x16U => typecheck_v128_binary(st)
    I32x4ExtmulLowI16x8S => typecheck_v128_binary(st)
    I32x4ExtmulLowI16x8U => typecheck_v128_binary(st)
    I32x4ExtmulHighI16x8S => typecheck_v128_binary(st)
    I32x4ExtmulHighI16x8U => typecheck_v128_binary(st)
    I64x2ExtmulLowI32x4S => typecheck_v128_binary(st)
    I64x2ExtmulLowI32x4U => typecheck_v128_binary(st)
    I64x2ExtmulHighI32x4S => typecheck_v128_binary(st)
    I64x2ExtmulHighI32x4U => typecheck_v128_binary(st)

    // _ => Err("unimplemented")
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

///|
fn assert_stack(state : TcState, expected : Array[ValType]) -> Unit {
  if not(equals(state.stack, expected)) {
    abort("Stack mismatch: expected \{expected}, got \{state.stack}")
  }
}

///|
fn[T] assert_ok(result : Result[T, String]) -> T {
  match result {
    Ok(v) => v
    Err(e) => abort("Expected Ok, got Err: \{e}")
  }
}

///|
fn[T : Show] assert_err(result : Result[T, String]) -> Unit {
  match result {
    Ok(v) => abort("Expected Err, got Ok: \{v}")
    Err(_) => ()
  }
}

///|
fn i32_type() -> ValType {
  NumTypeValType(I32NumType)
}

///|
fn i64_type() -> ValType {
  NumTypeValType(I64NumType)
}

///|
fn f32_type() -> ValType {
  NumTypeValType(F32NumType)
}

///|
fn f64_type() -> ValType {
  NumTypeValType(F64NumType)
}

///|
fn v128_type() -> ValType {
  VecTypeValType
}

///|
fn anyref_type() -> ValType {
  RefTypeValType(AbsHeapTypeRefType(AnyAbsHeapType))
}

///|
fn eqref_type() -> ValType {
  RefTypeValType(AbsHeapTypeRefType(EqAbsHeapType))
}

///|
fn i31ref_type() -> ValType {
  RefTypeValType(HeapTypeRefType(false, AbsHeapTypeHeapType(I31AbsHeapType)))
}

///|
fn nullable_funcref() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)))
}

///|
fn nullable_externref() -> ValType {
  RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(ExternAbsHeapType)))
}

///|
fn non_nullable_funcref() -> ValType {
  RefTypeValType(HeapTypeRefType(false, AbsHeapTypeHeapType(FuncAbsHeapType)))
}

///|
fn non_nullable_externref() -> ValType {
  RefTypeValType(HeapTypeRefType(false, AbsHeapTypeHeapType(ExternAbsHeapType)))
}

///|
fn make_state(env : Env, stack : Array[ValType]) -> TcState {
  { env, stack, reachable: true }
}

// =============================================================================
// CONTROL INSTRUCTIONS
// =============================================================================

///|
test "Typecheck Unreachable" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(Unreachable.typecheck(state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck Nop" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(Nop.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck Block empty" {
  let env = empty_env()
  let state = make_state(env, [])
  let block = Block(EmptyBlockType, Expr([]))
  let new_state = assert_ok(block.typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck Block with result" {
  let env = empty_env()
  let state = make_state(env, [])
  let block = Block(ValTypeBlockType(i32_type()), Expr([I32Const(I32(42))]))
  let new_state = assert_ok(block.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck Block preserves outer stack" {
  let env = empty_env()
  let state = make_state(env, [i64_type()])
  let block = Block(ValTypeBlockType(i32_type()), Expr([I32Const(I32(1))]))
  let new_state = assert_ok(block.typecheck(state))
  assert_stack(new_state, [i64_type(), i32_type()])
}

///|
test "Typecheck Loop empty" {
  let env = empty_env()
  let state = make_state(env, [])
  let loop_instr = Loop(EmptyBlockType, Expr([]))
  let new_state = assert_ok(loop_instr.typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck If without else" {
  let env = empty_env()
  let state = make_state(env, [i32_type()])
  let if_instr = If(EmptyBlockType, [Nop], None)
  let new_state = assert_ok(if_instr.typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck If with else" {
  let env = empty_env()
  let state = make_state(env, [i32_type()])
  let if_instr = If(
    ValTypeBlockType(i32_type()),
    [I32Const(I32(1))],
    Some([I32Const(I32(2))]),
  )
  let new_state = assert_ok(if_instr.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck If fails without condition" {
  let env = empty_env()
  let state = make_state(env, [])
  let if_instr = If(EmptyBlockType, [Nop], None)
  assert_err(if_instr.typecheck(state))
}

///|
test "Typecheck Br" {
  let env = empty_env().with_labels([[]])
  let state = make_state(env, [])
  let new_state = assert_ok(Br(LabelIdx(0)).typecheck(state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck Br with values" {
  let env = empty_env().with_labels([[i32_type()]])
  let state = make_state(env, [i32_type()])
  let new_state = assert_ok(Br(LabelIdx(0)).typecheck(state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck Br invalid label" {
  let env = empty_env().with_labels([])
  let state = make_state(env, [])
  assert_err(Br(LabelIdx(0)).typecheck(state))
}

///|
test "Typecheck BrIf" {
  let env = empty_env().with_labels([[]])
  let state = make_state(env, [i32_type()])
  let new_state = assert_ok(BrIf(LabelIdx(0)).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck BrIf with values" {
  let env = empty_env().with_labels([[i32_type()]])
  let state = make_state(env, [i32_type(), i32_type()])
  let new_state = assert_ok(BrIf(LabelIdx(0)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck BrTable" {
  let env = empty_env().with_labels([[], []])
  let state = make_state(env, [i32_type()])
  let br_table = BrTable([LabelIdx(0)], LabelIdx(1))
  let new_state = assert_ok(br_table.typecheck(state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck BrTable with values" {
  // Labels expect an i32 value to be passed
  let env = empty_env().with_labels([[i32_type()], [i32_type()]])
  // Stack: [i32 (branch value), i32 (selector)]
  let state = make_state(env, [i32_type(), i32_type()])
  let br_table = BrTable([LabelIdx(0)], LabelIdx(1))
  let new_state = assert_ok(br_table.typecheck(state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck BrTable with multiple values" {
  // Labels expect i32, i64 to be passed
  let env = empty_env().with_labels([
    [i32_type(), i64_type()],
    [i32_type(), i64_type()],
  ])
  // Stack: [i32, i64 (branch values), i32 (selector)]
  let state = make_state(env, [i32_type(), i64_type(), i32_type()])
  let br_table = BrTable([LabelIdx(0)], LabelIdx(1))
  let new_state = assert_ok(br_table.typecheck(state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck BrTable multiple targets" {
  let env = empty_env().with_labels([[], [], [], []])
  let state = make_state(env, [i32_type()])
  // Jump table with 3 entries plus default
  let br_table = BrTable([LabelIdx(0), LabelIdx(1), LabelIdx(2)], LabelIdx(3))
  let new_state = assert_ok(br_table.typecheck(state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck BrTable invalid default label" {
  let env = empty_env().with_labels([[]])
  let state = make_state(env, [i32_type()])
  let br_table = BrTable([LabelIdx(0)], LabelIdx(5)) // invalid default
  assert_err(br_table.typecheck(state))
}

///|
test "Typecheck BrTable invalid table label" {
  let env = empty_env().with_labels([[]])
  let state = make_state(env, [i32_type()])
  let br_table = BrTable([LabelIdx(0), LabelIdx(99)], LabelIdx(0)) // invalid in table
  assert_err(br_table.typecheck(state))
}

///|
test "Typecheck BrTable mismatched label types" {
  // Labels have different arities - this is invalid
  let env = empty_env().with_labels([[i32_type()], []])
  let state = make_state(env, [i32_type(), i32_type()])
  let br_table = BrTable([LabelIdx(0)], LabelIdx(1))
  assert_err(br_table.typecheck(state))
}

///|
test "Typecheck BrTable mismatched label value types" {
  // Labels have same arity but different types
  let env = empty_env().with_labels([[i32_type()], [i64_type()]])
  let state = make_state(env, [i32_type(), i32_type()])
  let br_table = BrTable([LabelIdx(0)], LabelIdx(1))
  assert_err(br_table.typecheck(state))
}

///|
test "Typecheck BrTable missing selector" {
  let env = empty_env().with_labels([[], []])
  let state = make_state(env, []) // empty stack - no selector
  let br_table = BrTable([LabelIdx(0)], LabelIdx(1))
  assert_err(br_table.typecheck(state))
}

///|
test "Typecheck BrTable missing branch values" {
  // Labels expect an i32 but stack only has the selector
  let env = empty_env().with_labels([[i32_type()], [i32_type()]])
  let state = make_state(env, [i32_type()]) // only selector, no branch value
  let br_table = BrTable([LabelIdx(0)], LabelIdx(1))
  assert_err(br_table.typecheck(state))
}

///|
test "Typecheck BrTable wrong selector type" {
  let env = empty_env().with_labels([[], []])
  let state = make_state(env, [i64_type()]) // wrong type for selector
  let br_table = BrTable([LabelIdx(0)], LabelIdx(1))
  assert_err(br_table.typecheck(state))
}

///|
test "Typecheck Return" {
  let env = empty_env().with_return_type(Some([]))
  let state = make_state(env, [])
  let new_state = assert_ok(Return.typecheck(state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck Return with value" {
  let env = empty_env().with_return_type(Some([i32_type()]))
  let state = make_state(env, [i32_type()])
  let new_state = assert_ok(Return.typecheck(state))
  assert_eq(new_state.reachable, false)
}

// =============================================================================
// PARAMETRIC INSTRUCTIONS
// =============================================================================

///|
test "Typecheck Drop i32" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(Drop.typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck Drop i64" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(Drop.typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck Drop fails empty stack" {
  let state = make_state(empty_env(), [])
  assert_err(Drop.typecheck(state))
}

///|
test "Typecheck Select without annotation" {
  let state = make_state(empty_env(), [i32_type(), i32_type(), i32_type()])
  let new_state = assert_ok(Select(None).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck Select with annotation" {
  let state = make_state(empty_env(), [i32_type(), i32_type(), i32_type()])
  let new_state = assert_ok(Select(Some([i32_type()])).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck Select type mismatch fails" {
  let state = make_state(empty_env(), [i32_type(), i64_type(), i32_type()])
  assert_err(Select(None).typecheck(state))
}

// =============================================================================
// VARIABLE INSTRUCTIONS
// =============================================================================

///|
test "Typecheck LocalGet" {
  let env : Env = { ..empty_env(), locals: [i32_type()] }
  let state = make_state(env, [])
  let new_state = assert_ok(LocalGet(LocalIdx(0)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck LocalGet invalid index" {
  let env : Env = { ..empty_env(), locals: [] }
  let state = make_state(env, [])
  assert_err(LocalGet(LocalIdx(0)).typecheck(state))
}

///|
test "Typecheck LocalSet" {
  let env : Env = { ..empty_env(), locals: [i32_type()] }
  let state = make_state(env, [i32_type()])
  let new_state = assert_ok(LocalSet(LocalIdx(0)).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck LocalSet type mismatch" {
  let env : Env = { ..empty_env(), locals: [i32_type()] }
  let state = make_state(env, [i64_type()])
  assert_err(LocalSet(LocalIdx(0)).typecheck(state))
}

///|
test "Typecheck LocalTee" {
  let env : Env = { ..empty_env(), locals: [i32_type()] }
  let state = make_state(env, [i32_type()])
  let new_state = assert_ok(LocalTee(LocalIdx(0)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck GlobalGet" {
  let env : Env = { ..empty_env(), globals: [GlobalType(i32_type(), false)] }
  let state = make_state(env, [])
  let new_state = assert_ok(GlobalGet(GlobalIdx(0)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck GlobalSet mutable" {
  let env : Env = { ..empty_env(), globals: [GlobalType(i32_type(), true)] }
  let state = make_state(env, [i32_type()])
  let new_state = assert_ok(GlobalSet(GlobalIdx(0)).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck GlobalSet immutable fails" {
  let env : Env = { ..empty_env(), globals: [GlobalType(i32_type(), false)] }
  let state = make_state(env, [i32_type()])
  assert_err(GlobalSet(GlobalIdx(0)).typecheck(state))
}

// =============================================================================
// TABLE INSTRUCTIONS
// =============================================================================

///|
test "Typecheck TableGet" {
  let table_type = TableType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
    I32Limits(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type] }
  let state = make_state(env, [i32_type()])
  let new_state = assert_ok(TableGet(TableIdx(0)).typecheck(state))
  assert_stack(new_state, [nullable_funcref()])
}

///|
test "Typecheck TableSet" {
  let table_type = TableType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
    I32Limits(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type] }
  let state = make_state(env, [i32_type(), nullable_funcref()])
  let new_state = assert_ok(TableSet(TableIdx(0)).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck TableSize" {
  let table_type = TableType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
    I32Limits(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type] }
  let state = make_state(env, [])
  let new_state = assert_ok(TableSize(TableIdx(0)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck TableGrow" {
  let table_type = TableType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
    I32Limits(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type] }
  let state = make_state(env, [nullable_funcref(), i32_type()])
  let new_state = assert_ok(TableGrow(TableIdx(0)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck TableFill" {
  let table_type = TableType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
    I32Limits(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type] }
  let state = make_state(env, [i32_type(), nullable_funcref(), i32_type()])
  let new_state = assert_ok(TableFill(TableIdx(0)).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck TableCopy" {
  let table_type = TableType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType)),
    I32Limits(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type, table_type] }
  let state = make_state(env, [i32_type(), i32_type(), i32_type()])
  let new_state = assert_ok(
    TableCopy(TableIdx(0), TableIdx(1)).typecheck(state),
  )
  assert_stack(new_state, [])
}

// =============================================================================
// MEMORY INSTRUCTIONS
// =============================================================================

///|
test "Typecheck I32Load" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I32Load(mem_arg).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64Load" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I64Load(mem_arg).typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck F32Load" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(F32Load(mem_arg).typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F64Load" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(F64Load(mem_arg).typecheck(state))
  assert_stack(new_state, [f64_type()])
}

///|
test "Typecheck I32Load8S" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I32Load8S(mem_arg).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Load8U" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I32Load8U(mem_arg).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Load16S" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I32Load16S(mem_arg).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Load16U" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I32Load16U(mem_arg).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64Load8S" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I64Load8S(mem_arg).typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I64Load32S" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I64Load32S(mem_arg).typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I32Store" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I32Store(mem_arg).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck I64Store" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), i64_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I64Store(mem_arg).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck F32Store" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), f32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(F32Store(mem_arg).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck F64Store" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), f64_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(F64Store(mem_arg).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck I32Store8" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), i32_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I32Store8(mem_arg).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck I64Store32" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), i64_type()])
  let mem_arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(I64Store32(mem_arg).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck MemorySize" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [])
  let new_state = assert_ok(MemorySize(MemIdx(0)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck MemoryGrow" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let new_state = assert_ok(MemoryGrow(MemIdx(0)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck MemoryCopy" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), i32_type(), i32_type()])
  let new_state = assert_ok(MemoryCopy(MemIdx(0), MemIdx(0)).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck MemoryFill" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), i32_type(), i32_type()])
  let new_state = assert_ok(MemoryFill(MemIdx(0)).typecheck(state))
  assert_stack(new_state, [])
}

// =============================================================================
// NUMERIC CONSTANTS
// =============================================================================

///|
test "Typecheck I32Const" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(I32Const(I32(42)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64Const" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(I64Const(I64(42L)).typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck F32Const" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(F32Const(F32(3.14)).typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F64Const" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(F64Const(F64(3.14)).typecheck(state))
  assert_stack(new_state, [f64_type()])
}

// =============================================================================
// I32 COMPARISON OPERATIONS
// =============================================================================

///|
test "Typecheck I32Eqz" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I32Eqz.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Eq" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32Eq.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Ne" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32Ne.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32LtS" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32LtS.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32LtU" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32LtU.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32GtS" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32GtS.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32GtU" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32GtU.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32LeS" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32LeS.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32LeU" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32LeU.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32GeS" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32GeS.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32GeU" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32GeU.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

// =============================================================================
// I64 COMPARISON OPERATIONS
// =============================================================================

///|
test "Typecheck I64Eqz" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(I64Eqz.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64Eq" {
  let state = make_state(empty_env(), [i64_type(), i64_type()])
  let new_state = assert_ok(I64Eq.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64Ne" {
  let state = make_state(empty_env(), [i64_type(), i64_type()])
  let new_state = assert_ok(I64Ne.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64LtS" {
  let state = make_state(empty_env(), [i64_type(), i64_type()])
  let new_state = assert_ok(I64LtS.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64GtU" {
  let state = make_state(empty_env(), [i64_type(), i64_type()])
  let new_state = assert_ok(I64GtU.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

// =============================================================================
// F32 COMPARISON OPERATIONS
// =============================================================================

///|
test "Typecheck F32Eq" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Eq.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck F32Ne" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Ne.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck F32Lt" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Lt.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck F32Gt" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Gt.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck F32Le" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Le.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck F32Ge" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Ge.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

// =============================================================================
// F64 COMPARISON OPERATIONS
// =============================================================================

///|
test "Typecheck F64Eq" {
  let state = make_state(empty_env(), [f64_type(), f64_type()])
  let new_state = assert_ok(F64Eq.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck F64Lt" {
  let state = make_state(empty_env(), [f64_type(), f64_type()])
  let new_state = assert_ok(F64Lt.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

// =============================================================================
// I32 ARITHMETIC OPERATIONS
// =============================================================================

///|
test "Typecheck I32Clz" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I32Clz.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Ctz" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I32Ctz.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Popcnt" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I32Popcnt.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Add" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32Add.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Sub" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32Sub.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Mul" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32Mul.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32DivS" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32DivS.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32DivU" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32DivU.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32RemS" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32RemS.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32RemU" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32RemU.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32And" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32And.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Or" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32Or.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Xor" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32Xor.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Shl" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32Shl.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32ShrS" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32ShrS.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32ShrU" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32ShrU.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Rotl" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32Rotl.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Rotr" {
  let state = make_state(empty_env(), [i32_type(), i32_type()])
  let new_state = assert_ok(I32Rotr.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

// =============================================================================
// I64 ARITHMETIC OPERATIONS
// =============================================================================

///|
test "Typecheck I64Clz" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(I64Clz.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I64Add" {
  let state = make_state(empty_env(), [i64_type(), i64_type()])
  let new_state = assert_ok(I64Add.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I64Sub" {
  let state = make_state(empty_env(), [i64_type(), i64_type()])
  let new_state = assert_ok(I64Sub.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I64Mul" {
  let state = make_state(empty_env(), [i64_type(), i64_type()])
  let new_state = assert_ok(I64Mul.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

// =============================================================================
// F32 ARITHMETIC OPERATIONS
// =============================================================================

///|
test "Typecheck F32Abs" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(F32Abs.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Neg" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(F32Neg.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Ceil" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(F32Ceil.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Floor" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(F32Floor.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Sqrt" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(F32Sqrt.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Add" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Add.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Sub" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Sub.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Mul" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Mul.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Div" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Div.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Min" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Min.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Max" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Max.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32Copysign" {
  let state = make_state(empty_env(), [f32_type(), f32_type()])
  let new_state = assert_ok(F32Copysign.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

// =============================================================================
// F64 ARITHMETIC OPERATIONS
// =============================================================================

///|
test "Typecheck F64Abs" {
  let state = make_state(empty_env(), [f64_type()])
  let new_state = assert_ok(F64Abs.typecheck(state))
  assert_stack(new_state, [f64_type()])
}

///|
test "Typecheck F64Neg" {
  let state = make_state(empty_env(), [f64_type()])
  let new_state = assert_ok(F64Neg.typecheck(state))
  assert_stack(new_state, [f64_type()])
}

///|
test "Typecheck F64Add" {
  let state = make_state(empty_env(), [f64_type(), f64_type()])
  let new_state = assert_ok(F64Add.typecheck(state))
  assert_stack(new_state, [f64_type()])
}

///|
test "Typecheck F64Sub" {
  let state = make_state(empty_env(), [f64_type(), f64_type()])
  let new_state = assert_ok(F64Sub.typecheck(state))
  assert_stack(new_state, [f64_type()])
}

///|
test "Typecheck F64Mul" {
  let state = make_state(empty_env(), [f64_type(), f64_type()])
  let new_state = assert_ok(F64Mul.typecheck(state))
  assert_stack(new_state, [f64_type()])
}

///|
test "Typecheck F64Div" {
  let state = make_state(empty_env(), [f64_type(), f64_type()])
  let new_state = assert_ok(F64Div.typecheck(state))
  assert_stack(new_state, [f64_type()])
}

// =============================================================================
// CONVERSION OPERATIONS
// =============================================================================

///|
test "Typecheck I32WrapI64" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(I32WrapI64.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32TruncF32S" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(I32TruncF32S.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32TruncF32U" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(I32TruncF32U.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32TruncF64S" {
  let state = make_state(empty_env(), [f64_type()])
  let new_state = assert_ok(I32TruncF64S.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32TruncF64U" {
  let state = make_state(empty_env(), [f64_type()])
  let new_state = assert_ok(I32TruncF64U.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64ExtendI32S" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I64ExtendI32S.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I64ExtendI32U" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I64ExtendI32U.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I64TruncF32S" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(I64TruncF32S.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I64TruncF64S" {
  let state = make_state(empty_env(), [f64_type()])
  let new_state = assert_ok(I64TruncF64S.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck F32ConvertI32S" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(F32ConvertI32S.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32ConvertI32U" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(F32ConvertI32U.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32ConvertI64S" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(F32ConvertI64S.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F32DemoteF64" {
  let state = make_state(empty_env(), [f64_type()])
  let new_state = assert_ok(F32DemoteF64.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F64ConvertI32S" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(F64ConvertI32S.typecheck(state))
  assert_stack(new_state, [f64_type()])
}

///|
test "Typecheck F64ConvertI64S" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(F64ConvertI64S.typecheck(state))
  assert_stack(new_state, [f64_type()])
}

///|
test "Typecheck F64PromoteF32" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(F64PromoteF32.typecheck(state))
  assert_stack(new_state, [f64_type()])
}

///|
test "Typecheck I32ReinterpretF32" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(I32ReinterpretF32.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64ReinterpretF64" {
  let state = make_state(empty_env(), [f64_type()])
  let new_state = assert_ok(I64ReinterpretF64.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck F32ReinterpretI32" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(F32ReinterpretI32.typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F64ReinterpretI64" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(F64ReinterpretI64.typecheck(state))
  assert_stack(new_state, [f64_type()])
}

// =============================================================================
// SIGN EXTENSION OPERATIONS
// =============================================================================

///|
test "Typecheck I32Extend8S" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I32Extend8S.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32Extend16S" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I32Extend16S.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64Extend8S" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(I64Extend8S.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I64Extend16S" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(I64Extend16S.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I64Extend32S" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(I64Extend32S.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

// =============================================================================
// SATURATING TRUNCATION
// =============================================================================

///|
test "Typecheck I32TruncSatF32S" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(I32TruncSatF32S.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32TruncSatF32U" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(I32TruncSatF32U.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32TruncSatF64S" {
  let state = make_state(empty_env(), [f64_type()])
  let new_state = assert_ok(I32TruncSatF64S.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64TruncSatF32S" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(I64TruncSatF32S.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck I64TruncSatF64S" {
  let state = make_state(empty_env(), [f64_type()])
  let new_state = assert_ok(I64TruncSatF64S.typecheck(state))
  assert_stack(new_state, [i64_type()])
}

// =============================================================================
// REFERENCE INSTRUCTIONS
// =============================================================================

///|
test "Typecheck RefNull func" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(
    RefNull(AbsHeapTypeHeapType(FuncAbsHeapType)).typecheck(state),
  )
  assert_stack(new_state, [nullable_funcref()])
}

///|
test "Typecheck RefNull extern" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(
    RefNull(AbsHeapTypeHeapType(ExternAbsHeapType)).typecheck(state),
  )
  assert_stack(new_state, [nullable_externref()])
}

///|
test "Typecheck RefIsNull" {
  let state = make_state(empty_env(), [nullable_funcref()])
  let new_state = assert_ok(RefIsNull.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck RefEq" {
  let eq_ref = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType)),
  )
  let state = make_state(empty_env(), [eq_ref, eq_ref])
  let new_state = assert_ok(RefEq.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck RefAsNonNull" {
  let state = make_state(empty_env(), [nullable_funcref()])
  let result = RefAsNonNull.typecheck(state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack.length(), 1)
    Err(_) => ()
  }
}

// BrOnNonNull tests

///|
test "Typecheck BrOnNonNull basic" {
  let env = empty_env().with_labels([[non_nullable_funcref()]])
  let state = make_state(env, [nullable_funcref()])
  let result = BrOnNonNull(LabelIdx(0)).typecheck(state)
  let new_state = assert_ok(result)
  assert_stack(new_state, [])
}

///|
test "Typecheck BrOnNonNull with prefix types" {
  let env = empty_env().with_labels([[i32_type(), non_nullable_funcref()]])
  let state = make_state(env, [i32_type(), nullable_funcref()])
  let result = BrOnNonNull(LabelIdx(0)).typecheck(state)
  let new_state = assert_ok(result)
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck BrOnNonNull with externref" {
  let env = empty_env().with_labels([[non_nullable_externref()]])
  let state = make_state(env, [nullable_externref()])
  let result = BrOnNonNull(LabelIdx(0)).typecheck(state)
  let new_state = assert_ok(result)
  assert_stack(new_state, [])
}

///|
test "Typecheck BrOnNonNull fails with wrong label type" {
  let env = empty_env().with_labels([[i32_type()]])
  let state = make_state(env, [nullable_funcref()])
  let result = BrOnNonNull(LabelIdx(0)).typecheck(state)
  assert_true(result is Err(_))
}

// BrOnNull tests

///|
test "Typecheck BrOnNull basic" {
  let env = empty_env().with_labels([[]]) // label takes no values
  let state = make_state(env, [nullable_funcref()])
  let result = BrOnNull(LabelIdx(0)).typecheck(state)
  let new_state = assert_ok(result)
  // Fallthrough pushes non-nullable ref
  assert_stack(new_state, [non_nullable_funcref()])
}

///|
test "Typecheck BrOnNull with prefix types" {
  let env = empty_env().with_labels([[i32_type()]])
  let state = make_state(env, [i32_type(), nullable_funcref()])
  let result = BrOnNull(LabelIdx(0)).typecheck(state)
  let new_state = assert_ok(result)
  assert_stack(new_state, [i32_type(), non_nullable_funcref()])
}

///|
test "Typecheck BrOnNull with externref" {
  let env = empty_env().with_labels([[]])
  let state = make_state(env, [nullable_externref()])
  let result = BrOnNull(LabelIdx(0)).typecheck(state)
  let new_state = assert_ok(result)
  assert_stack(new_state, [non_nullable_externref()])
}

///|
test "Typecheck RefI31" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(RefI31.typecheck(state))
  assert_eq(new_state.stack.length(), 1)
}

///|
test "Typecheck I31GetS" {
  let state = make_state(empty_env(), [i31ref_type()])
  let new_state = assert_ok(I31GetS.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I31GetU" {
  let state = make_state(empty_env(), [i31ref_type()])
  let new_state = assert_ok(I31GetU.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck AnyConvertExtern" {
  let state = make_state(empty_env(), [nullable_externref()])
  let result = AnyConvertExtern.typecheck(state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack.length(), 1)
    Err(_) => ()
  }
}

///|
test "Typecheck ExternConvertAny" {
  let any_ref = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType)),
  )
  let state = make_state(empty_env(), [any_ref])
  let result = ExternConvertAny.typecheck(state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack.length(), 1)
    Err(_) => ()
  }
}

// =============================================================================
// VECTOR (SIMD) INSTRUCTIONS
// =============================================================================

///|
test "Typecheck I32Const pushes i32" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let result = I32Const(I32(42)).typecheck(state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [NumTypeValType(I32NumType)])
    Err(e) => fail("I32Const should typecheck: \{e}")
  }
}

///|
test "Typecheck I32Add consumes two i32s and produces one" {
  let env = empty_env()
  let state : TcState = {
    env,
    stack: [NumTypeValType(I32NumType), NumTypeValType(I32NumType)],
    reachable: true,
  }
  let result = I32Add.typecheck(state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [NumTypeValType(I32NumType)])
    Err(e) => fail("I32Add should typecheck: \{e}")
  }
}

///|
test "Typecheck I32Add fails with insufficient stack" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let result = I32Add.typecheck(state)
  match result {
    Ok(_) => fail("I32Add should fail with empty stack")
    Err(_) => ()
  }
}

///|
test "Typecheck Drop removes top of stack" {
  let env = empty_env()
  let state : TcState = {
    env,
    stack: [NumTypeValType(I32NumType)],
    reachable: true,
  }
  let result = Drop.typecheck(state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [])
    Err(e) => fail("Drop should typecheck: \{e}")
  }
}

///|
test "Typecheck Unreachable makes state unreachable" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let result = Unreachable.typecheck(state)
  match result {
    Ok(new_state) => assert_eq(new_state.reachable, false)
    Err(e) => fail("Unreachable should typecheck: \{e}")
  }
}

///|
test "Typecheck empty Expr" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let expr = Expr([])
  let result = expr.typecheck(state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [])
    Err(e) => fail("Empty Expr should typecheck: \{e}")
  }
}

///|
test "Typecheck Expr sequence" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let expr = Expr([I32Const(I32(1)), I32Const(I32(2)), I32Add])
  let result = expr.typecheck(state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [NumTypeValType(I32NumType)])
    Err(e) => fail("Expr sequence should typecheck: \{e}")
  }
}

///|
test "Typecheck I64Const pushes i64" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let result = I64Const(I64(100L)).typecheck(state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [NumTypeValType(I64NumType)])
    Err(e) => fail("I64Const should typecheck: \{e}")
  }
}

///|
test "Typecheck type mismatch fails" {
  let env = empty_env()
  let state : TcState = {
    env,
    stack: [NumTypeValType(I64NumType), NumTypeValType(I32NumType)],
    reachable: true,
  }
  let result = I32Add.typecheck(state)
  match result {
    Ok(_) => fail("I32Add should fail with mismatched types")
    Err(_) => ()
  }
}

///|
test "Typecheck V128Const" {
  let state = make_state(empty_env(), [])
  let instr = V128Const(
    b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
    b'\x09', b'\x0a', b'\x0b', b'\x0c', b'\x0d', b'\x0e', b'\x0f',
  )
  let new_state = assert_ok(instr.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck V128Load" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type()])
  let arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(V128Load(arg).typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck V128Store" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), v128_type()])
  let arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(V128Store(arg).typecheck(state))
  assert_stack(new_state, [])
}

///|
test "Typecheck I8x16Splat" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I8x16Splat.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I16x8Splat" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I16x8Splat.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I32x4Splat" {
  let state = make_state(empty_env(), [i32_type()])
  let new_state = assert_ok(I32x4Splat.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I64x2Splat" {
  let state = make_state(empty_env(), [i64_type()])
  let new_state = assert_ok(I64x2Splat.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck F32x4Splat" {
  let state = make_state(empty_env(), [f32_type()])
  let new_state = assert_ok(F32x4Splat.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck F64x2Splat" {
  let state = make_state(empty_env(), [f64_type()])
  let new_state = assert_ok(F64x2Splat.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I8x16ExtractLaneS" {
  let state = make_state(empty_env(), [v128_type()])
  let new_state = assert_ok(I8x16ExtractLaneS(LaneIdx(0)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I16x8ExtractLaneU" {
  let state = make_state(empty_env(), [v128_type()])
  let new_state = assert_ok(I16x8ExtractLaneU(LaneIdx(3)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I32x4ExtractLane" {
  let state = make_state(empty_env(), [v128_type()])
  let new_state = assert_ok(I32x4ExtractLane(LaneIdx(1)).typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck I64x2ExtractLane" {
  let state = make_state(empty_env(), [v128_type()])
  let new_state = assert_ok(I64x2ExtractLane(LaneIdx(0)).typecheck(state))
  assert_stack(new_state, [i64_type()])
}

///|
test "Typecheck F32x4ExtractLane" {
  let state = make_state(empty_env(), [v128_type()])
  let new_state = assert_ok(F32x4ExtractLane(LaneIdx(2)).typecheck(state))
  assert_stack(new_state, [f32_type()])
}

///|
test "Typecheck F64x2ExtractLane" {
  let state = make_state(empty_env(), [v128_type()])
  let new_state = assert_ok(F64x2ExtractLane(LaneIdx(1)).typecheck(state))
  assert_stack(new_state, [f64_type()])
}

///|
test "Typecheck I8x16ReplaceLane" {
  let state = make_state(empty_env(), [v128_type(), i32_type()])
  let new_state = assert_ok(I8x16ReplaceLane(LaneIdx(0)).typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I16x8ReplaceLane" {
  let state = make_state(empty_env(), [v128_type(), i32_type()])
  let new_state = assert_ok(I16x8ReplaceLane(LaneIdx(2)).typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I32x4ReplaceLane" {
  let state = make_state(empty_env(), [v128_type(), i32_type()])
  let new_state = assert_ok(I32x4ReplaceLane(LaneIdx(1)).typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I64x2ReplaceLane" {
  let state = make_state(empty_env(), [v128_type(), i64_type()])
  let new_state = assert_ok(I64x2ReplaceLane(LaneIdx(0)).typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck F32x4ReplaceLane" {
  let state = make_state(empty_env(), [v128_type(), f32_type()])
  let new_state = assert_ok(F32x4ReplaceLane(LaneIdx(3)).typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck F64x2ReplaceLane" {
  let state = make_state(empty_env(), [v128_type(), f64_type()])
  let new_state = assert_ok(F64x2ReplaceLane(LaneIdx(1)).typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck V128Not" {
  let state = make_state(empty_env(), [v128_type()])
  let new_state = assert_ok(V128Not.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I8x16Abs" {
  let state = make_state(empty_env(), [v128_type()])
  let new_state = assert_ok(I8x16Abs.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I16x8Neg" {
  let state = make_state(empty_env(), [v128_type()])
  let new_state = assert_ok(I16x8Neg.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I32x4AllTrue" {
  let state = make_state(empty_env(), [v128_type()])
  let new_state = assert_ok(I32x4AllTrue.typecheck(state))
  assert_stack(new_state, [i32_type()])
}

///|
test "Typecheck V128And" {
  let state = make_state(empty_env(), [v128_type(), v128_type()])
  let new_state = assert_ok(V128And.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I8x16Add" {
  let state = make_state(empty_env(), [v128_type(), v128_type()])
  let new_state = assert_ok(I8x16Add.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I16x8Mul" {
  let state = make_state(empty_env(), [v128_type(), v128_type()])
  let new_state = assert_ok(I16x8Mul.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I32x4Sub" {
  let state = make_state(empty_env(), [v128_type(), v128_type()])
  let new_state = assert_ok(I32x4Sub.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck F32x4Div" {
  let state = make_state(empty_env(), [v128_type(), v128_type()])
  let new_state = assert_ok(F32x4Div.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I8x16Eq" {
  let state = make_state(empty_env(), [v128_type(), v128_type()])
  let new_state = assert_ok(I8x16Eq.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I16x8LtS" {
  let state = make_state(empty_env(), [v128_type(), v128_type()])
  let new_state = assert_ok(I16x8LtS.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck I32x4GtU" {
  let state = make_state(empty_env(), [v128_type(), v128_type()])
  let new_state = assert_ok(I32x4GtU.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck F32x4Le" {
  let state = make_state(empty_env(), [v128_type(), v128_type()])
  let new_state = assert_ok(F32x4Le.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck V128Bitselect" {
  let state = make_state(empty_env(), [v128_type(), v128_type(), v128_type()])
  let new_state = assert_ok(V128Bitselect.typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck V128Load8Lane" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), v128_type()])
  let arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(V128Load8Lane(arg, LaneIdx(0)).typecheck(state))
  assert_stack(new_state, [v128_type()])
}

///|
test "Typecheck V128Store16Lane" {
  let env : Env = { ..empty_env(), mems: [MemType(I32Limits(1, None))] }
  let state = make_state(env, [i32_type(), v128_type()])
  let arg = MemArg(U32(0), None, U64(0))
  let new_state = assert_ok(V128Store16Lane(arg, LaneIdx(2)).typecheck(state))
  assert_stack(new_state, [])
}

// =============================================================================
// CALL INSTRUCTIONS
// =============================================================================

///|
test "Typecheck Call" {
  let func_type = FuncType([i32_type()], [i64_type()])
  let env = empty_env().push_func(func_type)
  let state = make_state(env, [i32_type()])
  let result = Call(FuncIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck Call no args no results" {
  let func_type = FuncType([], [])
  let env = empty_env().push_func(func_type)
  let state = make_state(env, [])
  let result = Call(FuncIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck Call invalid func index" {
  let env = empty_env()
  let state = make_state(env, [i32_type()])
  let result = Call(FuncIdx(0)).typecheck(state)
  assert_err(result)
}

///|
test "Typecheck Call type mismatch" {
  let func_type = FuncType([i32_type()], [])
  let env = empty_env().push_func(func_type)
  let state = make_state(env, [i64_type()])
  let result = Call(FuncIdx(0)).typecheck(state)
  assert_err(result)
}

///|
test "Typecheck CallIndirect" {
  let func_subtype = CompTypeSubType(FuncCompType([i32_type()], [i64_type()]))
  let table_type = TableType(
    AbsHeapTypeRefType(FuncAbsHeapType),
    I32Limits(1, None),
  )
  let env = { ..empty_env(), global_types: [func_subtype] }.push_table(
    table_type,
  )
  let state = make_state(env, [i32_type(), i32_type()])
  let result = CallIndirect(TypeIdx(0), TableIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck ReturnCall" {
  let func_type = FuncType([i32_type()], [i64_type()])
  let env = empty_env()
    .push_func(func_type)
    .with_return_type(Some([i64_type()]))
  let state = make_state(env, [i32_type()])
  let result = ReturnCall(FuncIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.reachable, false)
}

///|
test "Typecheck ReturnCallIndirect" {
  let func_subtype = CompTypeSubType(FuncCompType([i32_type()], [i64_type()]))
  let table_type = TableType(
    AbsHeapTypeRefType(FuncAbsHeapType),
    I32Limits(1, None),
  )
  let env = { ..empty_env(), global_types: [func_subtype] }
    .push_table(table_type)
    .with_return_type(Some([i64_type()]))
  let state = make_state(env, [i32_type(), i32_type()])
  let result = ReturnCallIndirect(TypeIdx(0), TableIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.reachable, false)
}

///|
test "Typecheck CallRef" {
  let func_subtype = CompTypeSubType(FuncCompType([i32_type()], [i64_type()]))
  let env = { ..empty_env(), global_types: [func_subtype] }
  let ref_type = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [i32_type(), ref_type])
  let result = CallRef(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck ReturnCallRef" {
  let func_subtype = CompTypeSubType(FuncCompType([i32_type()], [i64_type()]))
  let env = { ..empty_env(), global_types: [func_subtype] }.with_return_type(
    Some([i64_type()]),
  )
  let ref_type = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [i32_type(), ref_type])
  let result = ReturnCallRef(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.reachable, false)
}

// =============================================================================
// REFERENCE INSTRUCTIONS
// =============================================================================

///|
test "Typecheck RefFunc" {
  let func_type = FuncType([], [])
  let env = empty_env().push_func(func_type)
  let state = make_state(env, [])
  let result = RefFunc(FuncIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck RefFunc invalid index" {
  let env = empty_env()
  let state = make_state(env, [])
  let result = RefFunc(FuncIdx(0)).typecheck(state)
  assert_err(result)
}

///|
test "Typecheck RefTest non-nullable" {
  let env = empty_env()
  let state = make_state(env, [anyref_type()])
  let result = RefTest(false, AbsHeapTypeHeapType(I31AbsHeapType)).typecheck(
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck RefTest eq from any" {
  let env = empty_env()
  let state = make_state(env, [anyref_type()])
  let result = RefTest(true, AbsHeapTypeHeapType(EqAbsHeapType)).typecheck(
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck RefTest struct from eq" {
  let env = empty_env()
  let state = make_state(env, [eqref_type()])
  let result = RefTest(true, AbsHeapTypeHeapType(StructAbsHeapType)).typecheck(
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck RefTest fails when target not subtype of operand" {
  let env = empty_env()
  // i31ref on stack, testing for funcref - these are incompatible hierarchies
  let state = make_state(env, [i31ref_type()])
  let result = RefTest(true, AbsHeapTypeHeapType(FuncAbsHeapType)).typecheck(
    state,
  )
  assert_true(result is Err(_))
}

///|
test "Typecheck RefTest with concrete type recursive" {
  let struct_subtype = CompTypeSubType(StructCompType([]))
  let env = empty_env().with_rectype(SingleRecType(struct_subtype))
  let state = make_state(env, [anyref_type()])
  let result = RefTest(true, HeapType(RecIdx(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck RefTest with concrete type in global types" {
  let struct_subtype = CompTypeSubType(StructCompType([]))
  let env : Env = { ..empty_env(), global_types: [struct_subtype] }
  let state = make_state(env, [anyref_type()])
  let result = RefTest(true, HeapType(TypeIdx(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck RefCast non-nullable" {
  let env = empty_env()
  let state = make_state(env, [anyref_type()])
  let result = RefCast(false, AbsHeapTypeHeapType(I31AbsHeapType)).typecheck(
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck BrOnCast" {
  let nullable_i31 = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(I31AbsHeapType)),
  )
  let env = empty_env().with_labels([[nullable_i31]])
  let state = make_state(env, [anyref_type()])
  let cast_op = CastOp(true, true)
  let result = BrOnCast(
    LabelIdx(0),
    cast_op,
    AbsHeapTypeHeapType(AnyAbsHeapType),
    AbsHeapTypeHeapType(I31AbsHeapType),
  ).typecheck(state)
  ignore(assert_ok(result))
}

///|
test "Typecheck BrOnCastFail" {
  let env = empty_env().with_labels([[anyref_type()]])
  let state = make_state(env, [anyref_type()])
  let cast_op = CastOp(true, true)
  let result = BrOnCastFail(
    LabelIdx(0),
    cast_op,
    AbsHeapTypeHeapType(AnyAbsHeapType),
    AbsHeapTypeHeapType(I31AbsHeapType),
  ).typecheck(state)
  ignore(assert_ok(result))
}

// =============================================================================
// EXCEPTION HANDLING INSTRUCTIONS
// =============================================================================

///|
test "Typecheck Throw" {
  let tag_subtype = CompTypeSubType(FuncCompType([i32_type()], []))
  let env = { ..empty_env(), global_types: [tag_subtype] }.push_tag(
    TagType(TypeIdx(0)),
  )
  let state = make_state(env, [i32_type()])
  let result = Throw(TagIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.reachable, false)
}

///|
test "Typecheck Throw invalid tag" {
  let env = empty_env()
  let state = make_state(env, [i32_type()])
  let result = Throw(TagIdx(0)).typecheck(state)
  assert_err(result)
}

///|
test "Typecheck ThrowRef" {
  let exnref = RefTypeValType(
    HeapTypeRefType(false, AbsHeapTypeHeapType(ExnAbsHeapType)),
  )
  let env = empty_env()
  let state = make_state(env, [exnref])
  let result = ThrowRef.typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.reachable, false)
}

///|
test "Typecheck TryTable empty" {
  let env = empty_env()
  let state = make_state(env, [])
  let result = TryTable(EmptyBlockType, [], Expr([])).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck TryTable with result" {
  let env = empty_env()
  let state = make_state(env, [])
  let block_type = ValTypeBlockType(i32_type())
  let result = TryTable(block_type, [], Expr([I32Const(I32(42))])).typecheck(
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

// =============================================================================
// STRUCT INSTRUCTIONS
// =============================================================================

///|
test "Typecheck StructNew" {
  let struct_type = CompTypeSubType(
    StructCompType([FieldType(ValTypeStorageType(i32_type()), Var)]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let state = make_state(env, [i32_type()])
  let result = StructNew(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck StructNewDefault" {
  let struct_type = CompTypeSubType(
    StructCompType([FieldType(ValTypeStorageType(i32_type()), Var)]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let state = make_state(env, [])
  let result = StructNewDefault(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck StructGet" {
  let struct_type = CompTypeSubType(
    StructCompType([FieldType(ValTypeStorageType(i32_type()), Var)]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let struct_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [struct_ref])
  let result = StructGet(TypeIdx(0), U32(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck StructGetS" {
  let struct_type = CompTypeSubType(
    StructCompType([FieldType(PackTypeStorageType(I8PackType), Var)]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let struct_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [struct_ref])
  let result = StructGetS(TypeIdx(0), U32(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck StructGetU" {
  let struct_type = CompTypeSubType(
    StructCompType([FieldType(PackTypeStorageType(I16PackType), Var)]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let struct_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [struct_ref])
  let result = StructGetU(TypeIdx(0), U32(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck StructSet" {
  let struct_type = CompTypeSubType(
    StructCompType([FieldType(ValTypeStorageType(i32_type()), Var)]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let struct_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [struct_ref, i32_type()])
  let result = StructSet(TypeIdx(0), U32(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

// =============================================================================
// ARRAY INSTRUCTIONS
// =============================================================================

///|
test "Typecheck ArrayNew" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(i32_type()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let state = make_state(env, [i32_type(), i32_type()])
  let result = ArrayNew(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck ArrayNewDefault" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(i32_type()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let state = make_state(env, [i32_type()])
  let result = ArrayNewDefault(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck ArrayNewFixed" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(i32_type()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let state = make_state(env, [i32_type(), i32_type(), i32_type()])
  let result = ArrayNewFixed(TypeIdx(0), U32(3)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck ArrayNewData" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(i32_type()), Var)),
  )
  let data = Data(Passive, b"")
  let env = { ..empty_env(), global_types: [array_type] }.push_data(data)
  let state = make_state(env, [i32_type(), i32_type()])
  let result = ArrayNewData(TypeIdx(0), DataIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck ArrayNewElem" {
  let funcref = AbsHeapTypeRefType(FuncAbsHeapType)
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(RefTypeValType(funcref)), Var)),
  )
  let elem = Elem(Passive, FuncsElemKind([]))
  let env = { ..empty_env(), global_types: [array_type] }.push_elem(elem)
  let state = make_state(env, [i32_type(), i32_type()])
  let result = ArrayNewElem(TypeIdx(0), ElemIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck ArrayGet" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(i32_type()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [array_ref, i32_type()])
  let result = ArrayGet(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck ArrayGetS" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(PackTypeStorageType(I8PackType), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [array_ref, i32_type()])
  let result = ArrayGetS(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck ArrayGetU" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(PackTypeStorageType(I16PackType), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [array_ref, i32_type()])
  let result = ArrayGetU(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck ArraySet" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(i32_type()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [array_ref, i32_type(), i32_type()])
  let result = ArraySet(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ArrayLen" {
  let array_ref = RefTypeValType(
    HeapTypeRefType(false, AbsHeapTypeHeapType(ArrayAbsHeapType)),
  )
  let env = empty_env()
  let state = make_state(env, [array_ref])
  let result = ArrayLen.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck ArrayFill" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(i32_type()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [array_ref, i32_type(), i32_type(), i32_type()])
  let result = ArrayFill(TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ArrayCopy" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(i32_type()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [
    array_ref,
    i32_type(),
    array_ref,
    i32_type(),
    i32_type(),
  ])
  let result = ArrayCopy(TypeIdx(0), TypeIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ArrayInitData" {
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(i32_type()), Var)),
  )
  let data = Data(Passive, b"")
  let env = { ..empty_env(), global_types: [array_type] }.push_data(data)
  let array_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [array_ref, i32_type(), i32_type(), i32_type()])
  let result = ArrayInitData(TypeIdx(0), DataIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ArrayInitElem" {
  let funcref = AbsHeapTypeRefType(FuncAbsHeapType)
  let array_type = CompTypeSubType(
    ArrayCompType(FieldType(ValTypeStorageType(RefTypeValType(funcref)), Var)),
  )
  let elem = Elem(Passive, FuncsElemKind([]))
  let env = { ..empty_env(), global_types: [array_type] }.push_elem(elem)
  let array_ref = RefTypeValType(HeapTypeRefType(false, HeapType(TypeIdx(0))))
  let state = make_state(env, [array_ref, i32_type(), i32_type(), i32_type()])
  let result = ArrayInitElem(TypeIdx(0), ElemIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

// =============================================================================
// MEMORY INIT/DATA INSTRUCTIONS
// =============================================================================

///|
test "Typecheck MemoryInit" {
  let mem_type = MemType(I32Limits(1, None))
  let data = Data(Passive, b"")
  let env = empty_env().push_mem(mem_type).push_data(data)
  let state = make_state(env, [i32_type(), i32_type(), i32_type()])
  let result = MemoryInit(DataIdx(0), MemIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck DataDrop" {
  let data = Data(Passive, b"")
  let env = empty_env().push_data(data)
  let state = make_state(env, [])
  let result = DataDrop(DataIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck DataDrop invalid index" {
  let env = empty_env()
  let state = make_state(env, [])
  let result = DataDrop(DataIdx(0)).typecheck(state)
  assert_err(result)
}

// =============================================================================
// TABLE INIT/ELEM INSTRUCTIONS
// =============================================================================

///|
test "Typecheck TableInit" {
  let table_type = TableType(
    AbsHeapTypeRefType(FuncAbsHeapType),
    I32Limits(1, None),
  )
  let elem = Elem(Passive, FuncsElemKind([]))
  let env = empty_env().push_table(table_type).push_elem(elem)
  let state = make_state(env, [i32_type(), i32_type(), i32_type()])
  let result = TableInit(ElemIdx(0), TableIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ElemDrop" {
  let elem = Elem(Passive, FuncsElemKind([]))
  let env = empty_env().push_elem(elem)
  let state = make_state(env, [])
  let result = ElemDrop(ElemIdx(0)).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ElemDrop invalid index" {
  let env = empty_env()
  let state = make_state(env, [])
  let result = ElemDrop(ElemIdx(0)).typecheck(state)
  assert_err(result)
}

// =============================================================================
// ADDITIONAL NUMERIC INSTRUCTIONS (missing from original tests)
// =============================================================================

///|
test "Typecheck I64LtU" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64LtU.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I64GtS" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64GtS.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I64LeS" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64LeS.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I64LeU" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64LeU.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I64GeS" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64GeS.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I64GeU" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64GeU.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I64Ctz" {
  let env = empty_env()
  let state = make_state(env, [i64_type()])
  let result = I64Ctz.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64Popcnt" {
  let env = empty_env()
  let state = make_state(env, [i64_type()])
  let result = I64Popcnt.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64DivS" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64DivS.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64DivU" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64DivU.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64RemS" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64RemS.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64RemU" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64RemU.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64And" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64And.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64Or" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64Or.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64Xor" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64Xor.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64Shl" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64Shl.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64ShrS" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64ShrS.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64ShrU" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64ShrU.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64Rotl" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64Rotl.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64Rotr" {
  let env = empty_env()
  let state = make_state(env, [i64_type(), i64_type()])
  let result = I64Rotr.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck F64Ne" {
  let env = empty_env()
  let state = make_state(env, [f64_type(), f64_type()])
  let result = F64Ne.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck F64Gt" {
  let env = empty_env()
  let state = make_state(env, [f64_type(), f64_type()])
  let result = F64Gt.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck F64Le" {
  let env = empty_env()
  let state = make_state(env, [f64_type(), f64_type()])
  let result = F64Le.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck F64Ge" {
  let env = empty_env()
  let state = make_state(env, [f64_type(), f64_type()])
  let result = F64Ge.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck F64Ceil" {
  let env = empty_env()
  let state = make_state(env, [f64_type()])
  let result = F64Ceil.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f64_type()])
}

///|
test "Typecheck F64Floor" {
  let env = empty_env()
  let state = make_state(env, [f64_type()])
  let result = F64Floor.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f64_type()])
}

///|
test "Typecheck F64Trunc" {
  let env = empty_env()
  let state = make_state(env, [f64_type()])
  let result = F64Trunc.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f64_type()])
}

///|
test "Typecheck F64Nearest" {
  let env = empty_env()
  let state = make_state(env, [f64_type()])
  let result = F64Nearest.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f64_type()])
}

///|
test "Typecheck F64Sqrt" {
  let env = empty_env()
  let state = make_state(env, [f64_type()])
  let result = F64Sqrt.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f64_type()])
}

///|
test "Typecheck F64Min" {
  let env = empty_env()
  let state = make_state(env, [f64_type(), f64_type()])
  let result = F64Min.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f64_type()])
}

///|
test "Typecheck F64Max" {
  let env = empty_env()
  let state = make_state(env, [f64_type(), f64_type()])
  let result = F64Max.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f64_type()])
}

///|
test "Typecheck F64Copysign" {
  let env = empty_env()
  let state = make_state(env, [f64_type(), f64_type()])
  let result = F64Copysign.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f64_type()])
}

///|
test "Typecheck F32Trunc" {
  let env = empty_env()
  let state = make_state(env, [f32_type()])
  let result = F32Trunc.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f32_type()])
}

///|
test "Typecheck F32Nearest" {
  let env = empty_env()
  let state = make_state(env, [f32_type()])
  let result = F32Nearest.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f32_type()])
}

///|
test "Typecheck I64TruncF32U" {
  let env = empty_env()
  let state = make_state(env, [f32_type()])
  let result = I64TruncF32U.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64TruncF64U" {
  let env = empty_env()
  let state = make_state(env, [f64_type()])
  let result = I64TruncF64U.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck F32ConvertI64U" {
  let env = empty_env()
  let state = make_state(env, [i64_type()])
  let result = F32ConvertI64U.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f32_type()])
}

///|
test "Typecheck F64ConvertI32U" {
  let env = empty_env()
  let state = make_state(env, [i32_type()])
  let result = F64ConvertI32U.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f64_type()])
}

///|
test "Typecheck F64ConvertI64U" {
  let env = empty_env()
  let state = make_state(env, [i64_type()])
  let result = F64ConvertI64U.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [f64_type()])
}

///|
test "Typecheck I32TruncSatF64U" {
  let env = empty_env()
  let state = make_state(env, [f64_type()])
  let result = I32TruncSatF64U.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I64TruncSatF32U" {
  let env = empty_env()
  let state = make_state(env, [f32_type()])
  let result = I64TruncSatF32U.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64TruncSatF64U" {
  let env = empty_env()
  let state = make_state(env, [f64_type()])
  let result = I64TruncSatF64U.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

// =============================================================================
// ADDITIONAL LOAD/STORE INSTRUCTIONS
// =============================================================================

///|
test "Typecheck I64Load8U" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = I64Load8U(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64Load16S" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = I64Load16S(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64Load16U" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = I64Load16U(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I64Load32U" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = I64Load32U(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i64_type()])
}

///|
test "Typecheck I32Store16" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type(), i32_type()])
  let result = I32Store16(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck I64Store8" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type(), i64_type()])
  let result = I64Store8(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck I64Store16" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type(), i64_type()])
  let result = I64Store16(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

// =============================================================================
// ADDITIONAL SIMD INSTRUCTIONS
// =============================================================================

///|
test "Typecheck I8x16Shuffle" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16Shuffle(
    LaneIdx(0),
    LaneIdx(1),
    LaneIdx(2),
    LaneIdx(3),
    LaneIdx(4),
    LaneIdx(5),
    LaneIdx(6),
    LaneIdx(7),
    LaneIdx(8),
    LaneIdx(9),
    LaneIdx(10),
    LaneIdx(11),
    LaneIdx(12),
    LaneIdx(13),
    LaneIdx(14),
    LaneIdx(15),
  ).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck I8x16Swizzle" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16Swizzle.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128AnyTrue" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = V128AnyTrue.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I8x16AllTrue" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I8x16AllTrue.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I8x16Bitmask" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I8x16Bitmask.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I16x8Bitmask" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I16x8Bitmask.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I32x4Bitmask" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4Bitmask.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck I64x2Bitmask" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I64x2Bitmask.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [i32_type()])
}

///|
test "Typecheck V128Or" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = V128Or.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Xor" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = V128Xor.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Andnot" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = V128Andnot.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck I8x16Neg" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I8x16Neg.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck I8x16Popcnt" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I8x16Popcnt.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck I8x16Sub" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16Sub.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck I8x16AddSatS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16AddSatS.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck I8x16AddSatU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16AddSatU.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck I64x2Add" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2Add.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck I64x2Sub" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2Sub.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck I64x2Mul" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2Mul.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F32x4Add" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F32x4Add.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F32x4Sub" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F32x4Sub.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F32x4Mul" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F32x4Mul.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F64x2Add" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F64x2Add.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F64x2Sub" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F64x2Sub.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F64x2Mul" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F64x2Mul.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F64x2Div" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F64x2Div.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F32x4Abs" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F32x4Abs.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F32x4Neg" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F32x4Neg.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F32x4Sqrt" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F32x4Sqrt.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F64x2Abs" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F64x2Abs.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F64x2Neg" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F64x2Neg.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck F64x2Sqrt" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F64x2Sqrt.typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Load32Zero" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = V128Load32Zero(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Load64Zero" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = V128Load64Zero(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Load8x8S" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = V128Load8x8S(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Load8x8U" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = V128Load8x8U(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Load16x4S" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = V128Load16x4S(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Load16x4U" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = V128Load16x4U(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Load32x2S" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = V128Load32x2S(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Load32x2U" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = V128Load32x2U(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Load8Splat" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = V128Load8Splat(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

///|
test "Typecheck V128Load16Splat" {
  let mem_type = MemType(I32Limits(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [i32_type()])
  let result = V128Load16Splat(MemArg(U32(0), None, U64(0))).typecheck(state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [v128_type()])
}

// =============================================================================
// SIMD LOAD TESTS (Missing)
// =============================================================================

///|
test "Typecheck V128Load32Splat" {
  let env = empty_env().push_mem(MemType(I32Limits(1, None)))
  let state = make_state(env, [i32_type()])
  let result = V128Load32Splat(MemArg(U32(0), None, U64(0))).typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck V128Load64Splat" {
  let env = empty_env().push_mem(MemType(I32Limits(1, None)))
  let state = make_state(env, [i32_type()])
  let result = V128Load64Splat(MemArg(U32(0), None, U64(0))).typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck V128Load32Lane" {
  let env = empty_env().push_mem(MemType(I32Limits(1, None)))
  let state = make_state(env, [i32_type(), v128_type()])
  let result = V128Load32Lane(MemArg(U32(0), None, U64(0)), LaneIdx(0)).typecheck(
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck V128Load64Lane" {
  let env = empty_env().push_mem(MemType(I32Limits(1, None)))
  let state = make_state(env, [i32_type(), v128_type()])
  let result = V128Load64Lane(MemArg(U32(0), None, U64(0)), LaneIdx(0)).typecheck(
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

// =============================================================================
// SIMD STORE TESTS (Missing)
// =============================================================================

///|
test "Typecheck V128Store8Lane" {
  let env = empty_env().push_mem(MemType(I32Limits(1, None)))
  let state = make_state(env, [i32_type(), v128_type()])
  let result = V128Store8Lane(MemArg(U32(0), None, U64(0)), LaneIdx(0)).typecheck(
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [])
}

///|
test "Typecheck V128Store32Lane" {
  let env = empty_env().push_mem(MemType(I32Limits(1, None)))
  let state = make_state(env, [i32_type(), v128_type()])
  let result = V128Store32Lane(MemArg(U32(0), None, U64(0)), LaneIdx(0)).typecheck(
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [])
}

///|
test "Typecheck V128Store64Lane" {
  let env = empty_env().push_mem(MemType(I32Limits(1, None)))
  let state = make_state(env, [i32_type(), v128_type()])
  let result = V128Store64Lane(MemArg(U32(0), None, U64(0)), LaneIdx(0)).typecheck(
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [])
}

// =============================================================================
// SIMD CONVERSION TESTS
// =============================================================================

///|
test "Typecheck F32x4DemoteF64x2Zero" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F32x4DemoteF64x2Zero.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2PromoteLowF32x4" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F64x2PromoteLowF32x4.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4TruncSatF32x4S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4TruncSatF32x4S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4TruncSatF32x4U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4TruncSatF32x4U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4ConvertI32x4S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F32x4ConvertI32x4S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4ConvertI32x4U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F32x4ConvertI32x4U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4TruncSatF64x2SZero" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4TruncSatF64x2SZero.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4TruncSatF64x2UZero" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4TruncSatF64x2UZero.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2ConvertLowI32x4S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F64x2ConvertLowI32x4S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2ConvertLowI32x4U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F64x2ConvertLowI32x4U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

// =============================================================================
// SIMD i8x16 TESTS (Missing)
// =============================================================================

///|
test "Typecheck I8x16NarrowI16x8S" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16NarrowI16x8S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16NarrowI16x8U" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16NarrowI16x8U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16Shl" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I8x16Shl.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16ShrS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I8x16ShrS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16ShrU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I8x16ShrU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16SubSatS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16SubSatS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16SubSatU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16SubSatU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16MinS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16MinS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16MinU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16MinU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16MaxS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16MaxS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16MaxU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16MaxU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16AvgrU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16AvgrU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

// =============================================================================
// SIMD i16x8 TESTS (Missing)
// =============================================================================

///|
test "Typecheck I16x8Abs" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I16x8Abs.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8AllTrue" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I16x8AllTrue.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [i32_type()])
}

///|
test "Typecheck I16x8Q15mulrSatS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8Q15mulrSatS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8NarrowI32x4S" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8NarrowI32x4S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8NarrowI32x4U" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8NarrowI32x4U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ExtendLowI8x16S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I16x8ExtendLowI8x16S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ExtendHighI8x16S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I16x8ExtendHighI8x16S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ExtendLowI8x16U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I16x8ExtendLowI8x16U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ExtendHighI8x16U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I16x8ExtendHighI8x16U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8Shl" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I16x8Shl.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ShrS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I16x8ShrS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ShrU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I16x8ShrU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8Add" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8Add.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8AddSatS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8AddSatS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8AddSatU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8AddSatU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8Sub" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8Sub.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8SubSatS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8SubSatS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8SubSatU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8SubSatU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8MinS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8MinS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8MinU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8MinU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8MaxS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8MaxS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8MaxU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8MaxU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8AvgrU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8AvgrU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ExtmulLowI8x16S" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8ExtmulLowI8x16S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ExtmulHighI8x16S" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8ExtmulHighI8x16S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ExtmulLowI8x16U" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8ExtmulLowI8x16U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ExtmulHighI8x16U" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8ExtmulHighI8x16U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ExtaddPairwiseI8x16S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I16x8ExtaddPairwiseI8x16S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8ExtaddPairwiseI8x16U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I16x8ExtaddPairwiseI8x16U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

// =============================================================================
// SIMD i32x4 TESTS (Missing)
// =============================================================================

///|
test "Typecheck I32x4Abs" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4Abs.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4Neg" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4Neg.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ExtendLowI16x8S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4ExtendLowI16x8S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ExtendHighI16x8S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4ExtendHighI16x8S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ExtendLowI16x8U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4ExtendLowI16x8U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ExtendHighI16x8U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4ExtendHighI16x8U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4Shl" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I32x4Shl.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ShrS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I32x4ShrS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ShrU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I32x4ShrU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4Add" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4Add.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4Mul" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4Mul.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4MinS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4MinS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4MinU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4MinU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4MaxS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4MaxS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4MaxU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4MaxU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4DotI16x8S" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4DotI16x8S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ExtmulLowI16x8S" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4ExtmulLowI16x8S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ExtmulHighI16x8S" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4ExtmulHighI16x8S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ExtmulLowI16x8U" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4ExtmulLowI16x8U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ExtmulHighI16x8U" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I32x4ExtmulHighI16x8U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ExtaddPairwiseI16x8S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4ExtaddPairwiseI16x8S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4ExtaddPairwiseI16x8U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4ExtaddPairwiseI16x8U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

// =============================================================================
// SIMD i64x2 TESTS (Missing)
// =============================================================================

///|
test "Typecheck I64x2Abs" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I64x2Abs.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2Neg" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I64x2Neg.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2AllTrue" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I64x2AllTrue.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [i32_type()])
}

///|
test "Typecheck I64x2ExtendLowI32x4S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I64x2ExtendLowI32x4S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2ExtendHighI32x4S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I64x2ExtendHighI32x4S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2ExtendLowI32x4U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I64x2ExtendLowI32x4U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2ExtendHighI32x4U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I64x2ExtendHighI32x4U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2Shl" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I64x2Shl.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2ShrS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I64x2ShrS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2ShrU" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), i32_type()])
  let result = I64x2ShrU.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2Eq" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2Eq.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2Ne" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2Ne.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2LtS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2LtS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2GtS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2GtS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2LeS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2LeS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2GeS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2GeS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2ExtmulLowI32x4S" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2ExtmulLowI32x4S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2ExtmulHighI32x4S" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2ExtmulHighI32x4S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2ExtmulLowI32x4U" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2ExtmulLowI32x4U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2ExtmulHighI32x4U" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I64x2ExtmulHighI32x4U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

// =============================================================================
// SIMD f32x4 TESTS (Missing)
// =============================================================================

///|
test "Typecheck F32x4Ceil" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F32x4Ceil.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4Floor" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F32x4Floor.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4Trunc" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F32x4Trunc.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4Nearest" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F32x4Nearest.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4Min" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F32x4Min.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4Max" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F32x4Max.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4Pmin" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F32x4Pmin.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4Pmax" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F32x4Pmax.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

// =============================================================================
// SIMD f64x2 TESTS (Missing)
// =============================================================================

///|
test "Typecheck F64x2Ceil" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F64x2Ceil.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2Floor" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F64x2Floor.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2Trunc" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F64x2Trunc.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2Nearest" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = F64x2Nearest.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2Min" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F64x2Min.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2Max" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F64x2Max.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2Pmin" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F64x2Pmin.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2Pmax" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F64x2Pmax.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

// =============================================================================
// SIMD RELAXED TESTS
// =============================================================================

///|
test "Typecheck I8x16RelaxedSwizzle" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I8x16RelaxedSwizzle.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4RelaxedTruncF32x4S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4RelaxedTruncF32x4S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4RelaxedTruncF32x4U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4RelaxedTruncF32x4U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4RelaxedTruncZeroF64x2S" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4RelaxedTruncZeroF64x2S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4RelaxedTruncZeroF64x2U" {
  let env = empty_env()
  let state = make_state(env, [v128_type()])
  let result = I32x4RelaxedTruncZeroF64x2U.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4RelaxedMadd" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type(), v128_type()])
  let result = F32x4RelaxedMadd.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4RelaxedNmadd" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type(), v128_type()])
  let result = F32x4RelaxedNmadd.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2RelaxedMadd" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type(), v128_type()])
  let result = F64x2RelaxedMadd.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2RelaxedNmadd" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type(), v128_type()])
  let result = F64x2RelaxedNmadd.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I8x16RelaxedLaneselect" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type(), v128_type()])
  let result = I8x16RelaxedLaneselect.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8RelaxedLaneselect" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type(), v128_type()])
  let result = I16x8RelaxedLaneselect.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4RelaxedLaneselect" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type(), v128_type()])
  let result = I32x4RelaxedLaneselect.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I64x2RelaxedLaneselect" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type(), v128_type()])
  let result = I64x2RelaxedLaneselect.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4RelaxedMin" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F32x4RelaxedMin.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F32x4RelaxedMax" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F32x4RelaxedMax.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2RelaxedMin" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F64x2RelaxedMin.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck F64x2RelaxedMax" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = F64x2RelaxedMax.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8RelaxedQ15mulrS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8RelaxedQ15mulrS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I16x8RelaxedDotI8x16I7x16S" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type()])
  let result = I16x8RelaxedDotI8x16I7x16S.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}

///|
test "Typecheck I32x4RelaxedDotI8x16I7x16AddS" {
  let env = empty_env()
  let state = make_state(env, [v128_type(), v128_type(), v128_type()])
  let result = I32x4RelaxedDotI8x16I7x16AddS.typecheck(state)
  let state = assert_ok(result)
  assert_stack(state, [v128_type()])
}
