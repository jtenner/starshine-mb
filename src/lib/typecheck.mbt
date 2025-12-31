///|
pub struct TcState {
  env : Env
  stack : Array[ValType]
  reachable : Bool
}

///|
pub type TcResult = Result[TcState, String]

///|
pub trait Typecheck {
  typecheck(Self, TcState) -> Result[TcState, String]
}

///|
fn TcState::with_stack(st : TcState, stack : Array[ValType]) -> TcState {
  TcState::{ env: st.env, stack, reachable: st.reachable }
}

///|
fn TcState::set_unreachable(st : TcState) -> TcState {
  TcState::{ env: st.env, stack: st.stack, reachable: false }
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
  // Pop in reverse because LIFO
  let n = ts.length()
  if n == 0 {
    return Ok(st)
  }
  let mut cur = st
  for i in (n - 1).until(0, step=-1) {
    cur = match cur.pop_expect(ts[i]) {
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
  let n = ts.length()
  if n == 0 {
    return Ok(st)
  }
  let mut st = st
  let range = (n - 1).until(0, step=-1)
  for i in range {
    match st.pop_expect(ts[i]) {
      Err(e) => return Err(e)
      Ok(st2) => st = st2
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
  let st_body0 = TcState::{
    env: env2,
    stack: st1.stack,
    reachable: st1.reachable,
  }
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
  let out = TcState::{
    env: st.env, // pop label scope by restoring original env
    stack: s,
    reachable: st.reachable,
  }
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
  let st_then0 = TcState::{
    env: env_branch,
    stack: st1.stack,
    reachable: st1.reachable,
  }
  let st_then = match Expr(then_instrs).typecheck(st_then0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // typecheck else branch (same starting state!)
  let st_else0 = TcState::{
    env: env_branch,
    stack: st1.stack,
    reachable: st1.reachable,
  }
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

  // If unreachable, polymorphic stack: only need label indices to be valid.
  // But we still must ensure label types are consistent to avoid invalid modules.
  // We'll keep checking label types even if unreachable.
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

    // Require invariance (same in both directions). For label result types,
    // exact equality is the usual requirement; mutual match is safer with your
    // subtyping machinery.
    let same = Match::matches(ts_l, ts, st.env) &&
      Match::matches(ts, ts_l, st.env)
    if !same {
      return Err("br_table target labels have different argument types")
    }
  }

  // If reachable, ensure the arguments are present on the stack (below selector).
  if st.reachable {
    let _ = match st1.pop_types(ts) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }

  }

  // Not-taken path continues (like br_if): only selector is consumed.
  Ok(st1)
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

  // pop the reference value (must be nullable ref)
  let (st1, v) = match st.pop1() {
    Err(e) => return Err(e)
    Ok(pair) => pair
  }
  let (ht, rt_in) = match expect_nullable_ref(v) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  if ht.validate(st.env) is Err(t) {
    return Err("Invalid heap type in br_on_non_null operand: " + t)
  }

  // Spec side condition: label has form t* (ref null? ht).
  // We'll enforce it strictly: label ends with exactly the popped ref type.
  if label_ts.length() == 0 {
    return Err("br_on_non_null label type too short")
  }
  let want_last = RefTypeValType(rt_in)
  let last = label_ts[label_ts.length() - 1]
  if last != want_last {
    return Err("br_on_non_null label must end with the same nullable ref type")
  }
  if st.reachable {
    // Check label prefix types are available beneath the popped ref.
    let prefix = label_ts.sub(start=0, end=label_ts.length() - 1)
    let _ = match st1.pop_types(prefix.to_array()) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }

  }

  // Fallthrough type is t* (ref is consumed)
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

fn typecheck_catch_clause(
  st : TcState,
  c : Catch,
) -> TcResult {
  match c {
    Catch(tag, lbl) => {
      // label must expect tag's payload types
      let label_types = st.env.labels[lbl.0.reinterpret_as_int()]
      let payload = tag_payload_types(st.env, tag)
      if not(Match::matches(payload, label_types, st.env)) {
        return Err("catch types (payload) do not match label types")
      }
      Ok(st)
    }
    CatchRef(tag, lbl) => {
      // label must expect tag's payload types + exnref
      let label_types = st.env.labels[lbl.0.reinterpret_as_int()]
      let payload = tag_payload_types(st.env, tag)
      let expected = payload.copy()
      expected.push(
        RefTypeValType(
          HeapTypeRefType(false, AbsHeapTypeHeapType(ExnAbsHeapType)),
        ),
      )
      if not(Match::matches(payload, label_types, st.env)) {
        return Err("catch_ref types (payload + exnref) do not match label types")
      }
      Ok(st)
    }
    CatchAll(lbl) => {
      // label must expect empty
      let label_types = st.env.labels[lbl.0.reinterpret_as_int()]
      if label_types.length() != 0 {
        return Err("catch_all label must expect no values")
      }
      Ok(st)
    }
    CatchAllRef(lbl) => {
      // label must expect just exnref
      let label_types = st.env.labels[lbl.0.reinterpret_as_int()]
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
  let st_body0 = TcState::{
    env: env2,
    stack: st1.stack,
    reachable: st1.reachable,
  }

  // body must typecheck under extended env
  let st_body = match body.typecheck(st_body0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // validate all catch clauses under the SAME extended env (spec: C')
  let st_catch_ctx = TcState::{
    env: env2,
    stack: st1.stack,
    reachable: st1.reachable,
  }
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
  let st_body0 = TcState::{
    env: env2,
    stack: st1.stack,
    reachable: st1.reachable,
  }
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

  // pop an input ref value
  let (st1, v) = match st.pop1() {
    Err(e) => return Err(e)
    Ok(pair) => pair
  }
  let rt_in = match v {
    RefTypeValType(r) => r
    _ => return Err("ref.test expects a reference operand")
  }

  // require rt ≤ rt_in  (target is subtype of input)
  if !Match::matches(rt, rt_in, st.env) {
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

  // pop address (top)
  let st1 = match st.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop existing vector
  let st2 = match st1.pop_expect(VecTypeValType) {
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

  // pop address (top)
  let st1 = match st.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop vector
  let st2 = match st1.pop_expect(VecTypeValType) {
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
  let st1 = match st.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop src index
  let st2 = match st1.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop dst index
  let st3 = match st2.pop_expect(vt_i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop src array
  let st4 = match st3.pop_expect(ref_null_array_of(y)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop dst array
  let st5 = match st4.pop_expect(ref_null_array_of(x)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st5)
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
    Unreachable =>
      Ok(TcState::{ env: st.env, stack: st.stack, reachable: false })
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
    I32x4RelaxedDotI8x16I7x16AddS => typecheck_v128_binary(st)

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
