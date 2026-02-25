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
    return Ok((st, ValType::bottom()))
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
      if Match::matches(actual, expected, st.env) {
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
fn tc_stack_from_types(ts : Array[ValType]) -> Array[ValType] {
  let out : Array[ValType] = []
  for t in ts {
    out.push(t)
  }
  out
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
    match Typecheck::typecheck(ins, st) {
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
  let st1 = match st.pop_expect(ValType::i32()) {
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
  let st1 = match st.pop_expect(ValType::i32()) {
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
    return Ok(st3.push1(ValType::bottom()))
  }

  // reachable: operands must have the same type (mutual match)
  let same = Match::matches(t1, t2, st.env) && Match::matches(t2, t1, st.env)
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
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ValType::ref_type(rt)))
}

// table.set x : [i32, t] -> []

///|
fn typecheck_table_set(st : TcState, idx : TableIdx) -> TcResult {
  let TableType(rt, _) = match st.env.get_table_type(idx) {
    None => return Err("invalid table index")
    Some(tt) => tt
  }

  // pop value (t)
  let st1 = match st.pop_expect(ValType::ref_type(rt)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop index (i32)
  let st2 = match st1.pop_expect(ValType::i32()) {
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
    Some(_) => Ok(st.push1(ValType::i32()))
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
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop init value (t)
  let st2 = match st1.pop_expect(ValType::ref_type(rt)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ValType::i32()))
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

  // Consume params from the outer stack.
  let st1 = match st.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // Body instructions only see block params above their label boundary.
  let body_stack = tc_stack_from_types(params)
  let env2 = st1.env.with_label(results)
  let st_body0 = TcState::{
    env: env2,
    stack: body_stack,
    reachable: st1.reachable,
  }
  let st_body = match Typecheck::typecheck(body, st_body0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // If reachable, body must leave exactly the declared result tuple.
  if st_body.reachable {
    let st_after_results = match st_body.pop_types(results) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
    if st_after_results.stack.length() != 0 {
      return Err("type mismatch")
    }
  }

  let out = TcState::{
    env: st.env,
    stack: st1.stack.copy(),
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
  let st0 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop params
  let st1 = match st0.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let else_instrs = match else_instrs_opt {
    None => []
    Some(xs) => xs
  }

  // typecheck then branch
  let branch_stack = tc_stack_from_types(params)
  let env_branch = st1.env.with_label(results)
  let st_then0 = TcState::{
    env: env_branch,
    stack: branch_stack,
    reachable: st1.reachable,
  }
  let st_then = match Typecheck::typecheck(Expr::new(then_instrs), st_then0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // typecheck else branch (same starting state!)
  let st_else0 = TcState::{
    env: env_branch,
    stack: tc_stack_from_types(params),
    reachable: st1.reachable,
  }
  let st_else = match Typecheck::typecheck(Expr::new(else_instrs), st_else0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // For each reachable branch: enforce results and ensure no extra values.
  let norm_branch = fn(sb : TcState) -> Result[(Bool, Array[ValType]), String] {
    let sb2 = if sb.reachable {
      let st_after_results = match sb.pop_types(results) {
        Err(e) => return Err(e)
        Ok(s) => s
      }
      if st_after_results.stack.length() != 0 {
        return Err("type mismatch")
      }
      st_after_results
    } else {
      sb
    }
    Ok((sb2.reachable, sb2.stack.copy()))
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
    (false, false) => [] // both unreachable, branch stack shape is irrelevant
  }
  let merged_reachable = then_reach || else_reach
  if merged_stack.length() != 0 {
    return Err("if branch stack mismatch")
  }
  let out = TcState::{
    env: st.env,
    stack: st1.stack.copy(),
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
  let st1 = match st.pop_expect(ValType::i32()) {
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
  let st1 = match st.pop_expect(ValType::i32()) {
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
  let fr = ValType::funcref()
  let elem_vt = ValType::ref_type(elem_rt)
  if !Match::matches(elem_vt, fr, st.env) {
    return Err("call_indirect table element type is not funcref-compatible")
  }

  // Pop table element index (i32)
  let st1 = match st.pop_expect(ValType::i32()) {
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
  let fref = ValType::ref_type(RefType::new(true, HeapType::new(tidx)))
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
  let fr = ValType::ref_type(RefType::abs(AbsHeapType::func()))
  let elem_vt = ValType::ref_type(elem_rt)
  if !Match::matches(elem_vt, fr, st.env) {
    return Err(
      "return_call_indirect table element type is not funcref-compatible",
    )
  }
  let st1 = match st.pop_expect(ValType::i32()) {
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
  let fref = ValType::ref_type(RefType::new(true, HeapType::new(tidx)))
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
  if Validate::validate(ht, st.env) is Err(t) {
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
  Ok(st1.push1(ValType::ref_type(RefType::new(false, ht))))
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
  if Validate::validate(ht, st.env) is Err(t) {
    return Err("Invalid heap type in br_on_non_null operand: " + t)
  }
  if label_ts.length() == 0 {
    return Err("br_on_non_null label type too short")
  }

  // Label must end with NON-NULLABLE ref of same heap type
  let non_null_rt = RefType::new(false, ht)
  let want_last = ValType::ref_type(non_null_rt)
  let last = label_ts[label_ts.length() - 1]
  if not(Match::matches(last, want_last, st.env)) {
    return Err("br_on_non_null label must end with non-nullable ref type")
  }
  if st.reachable {
    let end = label_ts.length() - 1
    let prefix = label_ts[0:end].to_array()
    if st1.pop_types(prefix) is Err(t) {
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
  let rt1 = RefType::new(n1, ht1)
  let rt2 = RefType::new(n2, ht2)
  if Validate::validate(rt1, st.env) is Err(t) {
    return Err("Invalid BrOnCast: " + t)
  }
  if Validate::validate(rt2, st.env) is Err(t) {
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
  let st1 = match st.pop_expect(ValType::ref_type(rt1)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  if st.reachable {
    // Check label args excluding rt_label (because branch keeps rt2 / rt_label)
    // Per spec, label is t* rt, so the remaining stack must have t*
    let end = label_ts.length() - 1
    let prefix = label_ts[0:end].to_array()
    let _ = match st1.pop_types(prefix) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }

  // push (rt1 \ rt2)
  let rt_out = match diff(rt1, rt2) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  Ok(st1.push1(ValType::ref_type(rt_out)))
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
  let rt1 = RefType::new(n1, ht1)
  let rt2 = RefType::new(n2, ht2)
  if Validate::validate(rt1, st.env) is Err(t) {
    return Err("Invalid RefType on BrOnCastFail: " + t)
  }
  if Validate::validate(rt2, st.env) is Err(t) {
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
  let st1 = match st.pop_expect(ValType::ref_type(rt1)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  if st.reachable {
    let end = label_ts.length() - 1
    let prefix = label_ts[0:end].to_array()
    let _ = match st1.pop_types(prefix) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  Ok(st1.push1(ValType::ref_type(rt2)))
}

///|
fn typecheck_throw(st : TcState, tag : TagIdx) -> TcResult {
  // validate tag index
  if Validate::validate(tag, st.env) is Err(e) {
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
  let st1 = match st.pop_expect(ValType::ref_null_exn()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.set_unreachable())
}

///|
fn tag_payload_types(env : Env, tag : TagIdx) -> Array[ValType] {
  let idx = tag.0
  // Guard against overflow - if idx >= 2^31, it would become negative when cast to Int
  if idx > 0x7FFFFFFF {
    return []
  }
  match env.tags.get(idx.reinterpret_as_int()) {
    Some(TagType(tidx)) =>
      match env.resolve_functype(tidx) {
        Some(FuncType(params, _)) => params
        None => []
      }
    None => []
  }
}

///|
fn typecheck_catch_clause(st : TcState, c : Catch) -> TcResult {
  match c {
    Catch(tag, lbl) => {
      if Validate::validate(tag, st.env) is Err(e) {
        return Err(e)
      }
      // label must expect tag's payload types
      let label_types = match st.env.get_catch_label_types(lbl) {
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
      if Validate::validate(tag, st.env) is Err(e) {
        return Err(e)
      }
      // label must expect tag's payload types + exnref
      let label_types = match st.env.get_catch_label_types(lbl) {
        Some(label_types) => label_types
        None => return Err("Invalid catch label index")
      }
      let payload = tag_payload_types(st.env, tag)
      let expected = payload.copy()
      expected.push(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::exn())),
        ),
      )
      if not(Match::matches(expected, label_types, st.env)) {
        return Err(
          "catch_ref types (payload + exnref) do not match label types",
        )
      }
      Ok(st)
    }
    CatchAll(lbl) => {
      // label must expect empty
      let label_types = match st.env.get_catch_label_types(lbl) {
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
      let label_types = match st.env.get_catch_label_types(lbl) {
        Some(label_types) => label_types
        None => return Err("Invalid catch label index")
      }
      let expected = [
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::exn())),
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

  // extend context with innermost label = results
  let env2 = st1.env.with_label(results)
  let st_body0 = TcState::{
    env: env2,
    stack: tc_stack_from_types(params),
    reachable: st1.reachable,
  }

  // body must typecheck under extended env
  let st_body = match Typecheck::typecheck(body, st_body0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // Catch branch targets are resolved in the enclosing label space, not the
  // try_table's temporary body label.
  let st_catch_ctx = st1
  for c in catches {
    match typecheck_catch_clause(st_catch_ctx, c) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }

  // if reachable, enforce results on stack top
  let st2 = if st_body.reachable {
    let st_after_results = match st_body.pop_types(results) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
    if st_after_results.stack.length() != 0 {
      return Err("type mismatch")
    }
    st_after_results
  } else {
    st_body
  }

  // restore outer env (pop the try_table label scope)
  let out = TcState::{
    env: st.env,
    stack: st1.stack.copy(),
    reachable: st2.reachable,
  }
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
  let rt2 = elem.reftype()
  if !Match::matches(rt2, rt1, st.env) {
    return Err("table.init elem segment type does not match table element type")
  }

  // Pop: len:i32, src:i32, dst:at  (LIFO order)
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::i32()) {
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
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop val : rt
  let st2 = match st1.pop_expect(ValType::ref_type(rt)) {
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
  let (_mem, lim) = match memarg_check(st, ma, MemIdx::new(0), nbits) {
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
  let (_mem, lim) = match memarg_check(st, ma, MemIdx::new(0), nbits) {
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
fn typecheck_atomic_notify(st : TcState, ma : MemArg) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx::new(0), 32) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ValType::i32()))
}

///|
fn typecheck_atomic_wait(
  st : TcState,
  ma : MemArg,
  nbits : Int,
  expected : ValType,
) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx::new(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()
  let st1 = match st.pop_expect(ValType::i64()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(expected) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3.push1(ValType::i32()))
}

///|
fn typecheck_atomic_rmw(
  st : TcState,
  ma : MemArg,
  nbits : Int,
  ty : ValType,
) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx::new(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()
  let st1 = match st.pop_expect(ty) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ty))
}

///|
fn typecheck_atomic_cmpxchg(
  st : TcState,
  ma : MemArg,
  nbits : Int,
  ty : ValType,
) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx::new(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()
  let st1 = match st.pop_expect(ty) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ty) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3.push1(ty))
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

  // loop label is params (not results)
  let env2 = st1.env.with_label(params)
  let st_body0 = TcState::{
    env: env2,
    stack: tc_stack_from_types(params),
    reachable: st1.reachable,
  }
  let st_body = match Typecheck::typecheck(body, st_body0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // if reachable, enforce results on top
  let st2 = if st_body.reachable {
    let st_after_results = match st_body.pop_types(results) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
    if st_after_results.stack.length() != 0 {
      return Err("type mismatch")
    }
    st_after_results
  } else {
    st_body
  }

  // restore outer env (pop label scope)
  let out = TcState::{
    env: st.env,
    stack: st1.stack.copy(),
    reachable: st2.reachable,
  }
  Ok(out.push_types(results))
}

///|
fn typecheck_ref_null(st : TcState, ht : HeapType) -> TcResult {
  if Validate::validate(ht, st.env) is Err(t) {
    return Err(t)
  }
  Ok(st.push1(ValType::ref_null(ht)))
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
      Ok(st1.push1(ValType::i32()))
    }
    _ => Err("ref.is_null expects a reference type")
  }
}

///|
fn inferred_ref_func_heap_type(env : Env, f : FuncIdx) -> HeapType {
  match env.get_functypeidx_by_funcidx(f) {
    Some(tidx) => return HeapType::new(tidx)
    None => ()
  }
  let ft = match env.get_functype_by_funcidx(f) {
    Some(ft) => ft
    None => return HeapType::abs(AbsHeapType::func())
  }
  let mut inferred : TypeIdx? = None
  for i in 0..<env.global_types.length() {
    match env.global_types[i].get_comptype() {
      FuncCompType(params, results) => {
        if FuncType::new(params, results) == ft {
          let next = TypeIdx::new(i.reinterpret_as_uint())
          match inferred {
            None => inferred = Some(next)
            Some(_) => return HeapType::abs(AbsHeapType::func())
          }
        }
      }
      _ => ()
    }
  }
  match inferred {
    Some(tidx) => HeapType::new(tidx)
    None => HeapType::abs(AbsHeapType::func())
  }
}

///|
fn typecheck_ref_func(st : TcState, f : FuncIdx) -> TcResult {
  if !st.env.has_func(f) {
    return Err("invalid function index")
  }
  let heap_type = inferred_ref_func_heap_type(st.env, f)
  Ok(
    st.push1(
      ValType::ref_type(RefType::new(false, heap_type)),
    ),
  )
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
          Ok(st1.push1(ValType::ref_type(RefType::new(false, ht))))
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
  let st1 = match st.pop_expect(ValType::eqref_null()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop first operand
  let st2 = match st1.pop_expect(ValType::eqref_null()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ValType::i32()))
}

///|
fn typecheck_ref_get_desc(st : TcState) -> TcResult {
  let (st1, rt_in_opt) = match st.pop_ref_or_bot() {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  match rt_in_opt {
    None => return Ok(st1.push1(st.env.descriptor_result_type()))
    Some(rt_in) =>
      if rt_in.is_nullable() {
        return Err("ref.get_desc expects a non-null reference operand")
      }
  }
  Ok(st1.push1(st.env.descriptor_result_type()))
}

///|
fn typecheck_ref_test(st : TcState, nullable : Bool, ht : HeapType) -> TcResult {
  let rt = RefType::new(nullable, ht)
  if Validate::validate(rt, st.env) is Err(t) {
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
  Ok(st1.push1(ValType::i32()))
}

///|
fn typecheck_ref_cast(st : TcState, nullable : Bool, ht : HeapType) -> TcResult {
  let rt = RefType::new(nullable, ht)
  if Validate::validate(rt, st.env) is Err(t) {
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
  Ok(st1.push1(ValType::ref_type(rt)))
}

///|
fn typecheck_ref_test_desc(
  st : TcState,
  nullable : Bool,
  ht : HeapType,
) -> TcResult {
  let rt = match st.env.resolve_descriptor_target_ref_type(nullable, ht) {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let (st1, v) = match st.pop1() {
    Err(e) => return Err(e)
    Ok(pair) => pair
  }
  let rt_in = match v {
    RefTypeValType(r) => r
    _ => return Err("ref.test_desc expects a reference operand")
  }
  if !descriptor_compatible(rt, rt_in, st.env) {
    return Err("ref.test_desc target does not match operand type")
  }
  Ok(st1.push1(ValType::i32()))
}

///|
fn typecheck_ref_cast_desc_eq(
  st : TcState,
  nullable : Bool,
  ht : HeapType,
) -> TcResult {
  let rt = match st.env.resolve_descriptor_target_ref_type(nullable, ht) {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let (st1, rt_in_opt) = match st.pop_ref_or_bot() {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  match rt_in_opt {
    None => ()
    Some(rt_in) =>
      if !descriptor_compatible(rt, rt_in, st.env) {
        return Err("ref.cast_desc_eq target does not match operand type")
      }
  }
  Ok(st1.push1(ValType::ref_type(rt)))
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
    args.push(stor.unpack())
  }
  let st1 = match st.pop_types(args) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // push (ref x)
  Ok(st1.push1(ValType::ref_type(RefType::new(false, HeapType::new(x)))))
}

///|
fn typecheck_struct_new_default(st : TcState, x : TypeIdx) -> TcResult {
  let fields = match st.env.resolve_struct_fields(x) {
    Err(e) => return Err(e)
    Ok(fs) => fs
  }
  for f in fields {
    let FieldType(stor, _) = f
    let vt = stor.unpack()
    if !has_default(vt) {
      return Err("struct.new_default: no default for a non-null field type")
    }
  }
  Ok(st.push1(ValType::ref_type(RefType::new(false, HeapType::new(x)))))
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
  if stor.is_packed() {
    return Err(
      "struct.get used on packed field; use struct.get_s or struct.get_u",
    )
  }
  let st1 = match
    st.pop_expect(ValType::ref_type(RefType::new(true, HeapType::new(x)))) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(stor.unpack()))
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
  if !stor.is_packed() {
    return Err("struct.get_s requires packed field")
  }
  let st1 = match
    st.pop_expect(ValType::ref_type(RefType::new(true, HeapType::new(x)))) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ValType::i32()))
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
  if !ft.is_mutable() {
    return Err("struct.set on immutable field")
  }
  let FieldType(stor, _) = ft
  let val_ty = stor.unpack()

  // pop value then ref
  let st1 = match st.pop_expect(val_ty) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match
    st1.pop_expect(ValType::ref_type(RefType::new(true, HeapType::new(x)))) {
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
  let st1 = match st.pop_expect(ValType::v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(ValType::v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3.push1(ValType::v128()))
}

///|
fn typecheck_compare(st : TcState, t : ValType) -> TcResult {
  typecheck_binary(st, t, ValType::i32())
}

///|
fn typecheck_v128_unary(st : TcState) -> TcResult {
  typecheck_unary(st, ValType::v128(), ValType::v128())
}

///|
fn typecheck_v128_binary(st : TcState) -> TcResult {
  typecheck_binary(st, ValType::v128(), ValType::v128())
}

///|
fn typecheck_v128_compare(st : TcState) -> TcResult {
  // v128 v128 -> v128 (SIMD comparisons produce v128 masks)
  typecheck_v128_binary(st)
}

///|
fn typecheck_v128_shift(st : TcState) -> TcResult {
  // v128 i32 -> v128 (shift count is i32)
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ValType::v128()))
}

///|
fn typecheck_lane_extract(st : TcState, out : ValType) -> TcResult {
  // v128 -> out (lane index is an immediate, not on stack)
  let st1 = match st.pop_expect(ValType::v128()) {
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
  let st2 = match st1.pop_expect(ValType::v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ValType::v128()))
}

///|
fn typecheck_splat(st : TcState, in_v : ValType) -> TcResult {
  // in_v -> v128
  typecheck_unary(st, in_v, ValType::v128())
}

///|
fn typecheck_v128_const(st : TcState) -> TcResult {
  Ok(st.push1(ValType::v128()))
}

///|
fn typecheck_v128_mem_load(st : TcState, ma : MemArg, nbits : Int) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx::new(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()
  let st1 = match st.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ValType::v128()))
}

///|
fn typecheck_v128_mem_store(st : TcState, ma : MemArg, nbits : Int) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx::new(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()

  // pop value first
  let st1 = match st.pop_expect(ValType::v128()) {
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
  let (_mem, lim) = match memarg_check(st, ma, MemIdx::new(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()

  // pop existing vector (top of stack)
  let st1 = match st.pop_expect(ValType::v128()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop address
  let st2 = match st1.pop_expect(at) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ValType::v128()))
}

///|
fn typecheck_v128_store_lane(
  st : TcState,
  ma : MemArg,
  nbits : Int,
) -> TcResult {
  let (_mem, lim) = match memarg_check(st, ma, MemIdx::new(0), nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  let at = lim.addr_valtype()

  // pop vector (top of stack)
  let st1 = match st.pop_expect(ValType::v128()) {
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
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::i32()) {
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
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::i32()) {
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
  let st1 = match st.pop_expect(ValType::externref()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ValType::anyref()))
}

///|
fn typecheck_extern_convert_any(st : TcState) -> TcResult {
  let st1 = match st.pop_expect(ValType::anyref()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ValType::externref()))
}

///|
fn typecheck_ref_i31(st : TcState) -> TcResult {
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ValType::i31ref()))
}

///|
fn typecheck_i31_get(st : TcState) -> TcResult {
  let st1 = match st.pop_expect(ValType::i31ref_nullable()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ValType::i32()))
}

///|
fn typecheck_array_new(st : TcState, x : TypeIdx) -> TcResult {
  let FieldType(sto, _) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  let elem_vt = sto.unpack()

  // pop length : i32
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop init value : elem_vt
  let st2 = match st1.pop_expect(elem_vt) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ValType::ref_array_nonnull(x)))
}

///|
fn typecheck_array_new_default(st : TcState, x : TypeIdx) -> TcResult {
  let FieldType(sto, _) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  let elem_vt = sto.unpack()
  if !has_default(elem_vt) {
    return Err("array.new_default: no default for element type")
  }
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ValType::ref_array_nonnull(x)))
}

///|
fn typecheck_array_new_fixed(st : TcState, x : TypeIdx, n : U32) -> TcResult {
  let FieldType(sto, _) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  let elem_vt = sto.unpack()
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
  Ok(cur.push1(ValType::ref_array_nonnull(x)))
}

///|
fn typecheck_array_get(st : TcState, x : TypeIdx) -> TcResult {
  let FieldType(sto, _) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  if sto.is_packed() {
    return Err(
      "array.get used on packed element; use array.get_s or array.get_u",
    )
  }
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::ref_array_nullable(x)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(sto.unpack()))
}

///|
fn typecheck_array_get_s(st : TcState, x : TypeIdx) -> TcResult {
  let FieldType(sto, _) = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(ft) => ft
  }
  if !sto.is_packed() {
    return Err("array.get_s requires packed element type")
  }
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::ref_array_nullable(x)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ValType::i32()))
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
  if !ft.is_mutable() {
    return Err("array.set on immutable array element type")
  }
  let FieldType(sto, _) = ft
  let elem_vt = sto.unpack()

  // pop value
  let st1 = match st.pop_expect(elem_vt) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop index
  let st2 = match st1.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop array ref
  let st3 = match st2.pop_expect(ValType::ref_array_nullable(x)) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st3)
}

///|
fn typecheck_array_len(st : TcState) -> TcResult {
  let want = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::array())),
  )
  let st1 = match st.pop_expect(want) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st1.push1(ValType::i32()))
}

///|
fn typecheck_array_fill(st : TcState, x : TypeIdx) -> TcResult {
  let ft = match st.env.resolve_array_field(x) {
    Err(e) => return Err(e)
    Ok(f) => f
  }
  if !ft.is_mutable() {
    return Err("array.fill on immutable array element type")
  }
  let FieldType(sto, _) = ft
  let elem_vt = sto.unpack()

  // pop len
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop value
  let st2 = match st1.pop_expect(elem_vt) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop start
  let st3 = match st2.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop array ref
  let st4 = match st3.pop_expect(ValType::ref_null_array_of(x)) {
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
  if !ft_x.is_mutable() {
    return Err("array.copy requires destination array to be mutable")
  }
  let FieldType(sto_x, _) = ft_x
  let FieldType(sto_y, _) = ft_y
  let vx = sto_x.unpack()
  let vy = sto_y.unpack()
  if !Match::matches(vy, vx, st.env) {
    return Err(
      "array.copy source element type does not match destination element type",
    )
  }

  // pop len
  let st = match st.pop_expect(ValType::i32()) {
    Err(t) => return Err(t)
    Ok(t) => t
  }

  // pop src index
  let st = match st.pop_expect(ValType::i32()) {
    Err(t) => return Err(t)
    Ok(t) => t
  }

  // pop src array
  let st = match st.pop_expect(ValType::ref_null_array_of(y)) {
    Err(t) => return Err(t)
    Ok(t) => t
  }

  // pop dst index
  let st = match st.pop_expect(ValType::i32()) {
    Err(t) => return Err(t)
    Ok(t) => t
  }

  // pop dst array
  let st = match st.pop_expect(ValType::ref_null_array_of(x)) {
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
  if !ft.is_mutable() {
    return Err("array.init_data requires array element to be mutable")
  }
  let FieldType(sto, _) = ft
  let vt = sto.unpack()
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
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop array ref
  let st4 = match st3.pop_expect(ValType::ref_null_array_of(x)) {
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
  if !ft.is_mutable() {
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
  let rt_seg = elem.reftype()
  if !Match::matches(rt_seg, rt_array, st.env) {
    return Err(
      "array.init_elem elem segment type does not match array storage type",
    )
  }

  // Stack: (ref null x) i32 i32 i32 -> ε
  // pop len, src, dst
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st3 = match st2.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop array ref
  let st4 = match st3.pop_expect(ValType::ref_null_array_of(x)) {
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
  let rt_seg = elem.reftype()
  if !Match::matches(rt_seg, rt_array, st.env) {
    return Err(
      "array.new_elem elem segment type does not match array element reftype",
    )
  }

  // Stack: i32 i32 -> (ref x)
  // (the two i32 are typically src and len; order doesn't matter for typing as both are i32)
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ValType::ref_array_nonnull(x)))
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
  let vt = sto.unpack()
  match vt {
    NumTypeValType(_) => ()
    VecTypeValType => ()
    _ =>
      return Err(
        "array.new_data requires unpack(element) to be numtype or vectype",
      )
  }

  // Stack: i32 i32 -> (ref x)
  let st1 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let st2 = match st1.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  Ok(st2.push1(ValType::ref_array_nonnull(x)))
}

///|
pub impl Typecheck for Instruction with typecheck(self, st) {
  match self {
    Unreachable => Ok(TcState::{ ..st, reachable: false })
    Nop => Ok(st)
    I32Const(_) => Ok(st.push1(ValType::i32()))
    I64Const(_) => Ok(st.push1(ValType::i64()))
    F32Const(_) => Ok(st.push1(ValType::f32()))
    F64Const(_) => Ok(st.push1(ValType::f64()))
    I32Load(ma) => typecheck_load(st, ma, 32, ValType::i32())
    I64Load(ma) => typecheck_load(st, ma, 64, ValType::i64())
    F32Load(ma) => typecheck_load(st, ma, 32, ValType::f32())
    F64Load(ma) => typecheck_load(st, ma, 64, ValType::f64())
    I32Load8S(ma) => typecheck_load(st, ma, 8, ValType::i32())
    I32Load8U(ma) => typecheck_load(st, ma, 8, ValType::i32())
    I32Load16S(ma) => typecheck_load(st, ma, 16, ValType::i32())
    I32Load16U(ma) => typecheck_load(st, ma, 16, ValType::i32())
    I64Load8S(ma) => typecheck_load(st, ma, 8, ValType::i64())
    I64Load8U(ma) => typecheck_load(st, ma, 8, ValType::i64())
    I64Load16S(ma) => typecheck_load(st, ma, 16, ValType::i64())
    I64Load16U(ma) => typecheck_load(st, ma, 16, ValType::i64())
    I64Load32S(ma) => typecheck_load(st, ma, 32, ValType::i64())
    I64Load32U(ma) => typecheck_load(st, ma, 32, ValType::i64())
    I32AtomicLoad(ma) => typecheck_load(st, ma, 32, ValType::i32())
    I64AtomicLoad(ma) => typecheck_load(st, ma, 64, ValType::i64())
    I32AtomicLoad8U(ma) => typecheck_load(st, ma, 8, ValType::i32())
    I32AtomicLoad16U(ma) => typecheck_load(st, ma, 16, ValType::i32())
    I64AtomicLoad8U(ma) => typecheck_load(st, ma, 8, ValType::i64())
    I64AtomicLoad16U(ma) => typecheck_load(st, ma, 16, ValType::i64())
    I64AtomicLoad32U(ma) => typecheck_load(st, ma, 32, ValType::i64())
    I32Store(ma) => typecheck_store(st, ma, 32, ValType::i32())
    I64Store(ma) => typecheck_store(st, ma, 64, ValType::i64())
    F32Store(ma) => typecheck_store(st, ma, 32, ValType::f32())
    F64Store(ma) => typecheck_store(st, ma, 64, ValType::f64())
    I32Store8(ma) => typecheck_store(st, ma, 8, ValType::i32())
    I32Store16(ma) => typecheck_store(st, ma, 16, ValType::i32())
    I64Store8(ma) => typecheck_store(st, ma, 8, ValType::i64())
    I64Store16(ma) => typecheck_store(st, ma, 16, ValType::i64())
    I64Store32(ma) => typecheck_store(st, ma, 32, ValType::i64())
    I32AtomicStore(ma) => typecheck_store(st, ma, 32, ValType::i32())
    I64AtomicStore(ma) => typecheck_store(st, ma, 64, ValType::i64())
    I32AtomicStore8(ma) => typecheck_store(st, ma, 8, ValType::i32())
    I32AtomicStore16(ma) => typecheck_store(st, ma, 16, ValType::i32())
    I64AtomicStore8(ma) => typecheck_store(st, ma, 8, ValType::i64())
    I64AtomicStore16(ma) => typecheck_store(st, ma, 16, ValType::i64())
    I64AtomicStore32(ma) => typecheck_store(st, ma, 32, ValType::i64())
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
    MemoryAtomicNotify(ma) => typecheck_atomic_notify(st, ma)
    MemoryAtomicWait32(ma) => typecheck_atomic_wait(st, ma, 32, ValType::i32())
    MemoryAtomicWait64(ma) => typecheck_atomic_wait(st, ma, 64, ValType::i64())
    AtomicFence => Ok(st)
    MemoryInit(d, m) => typecheck_memory_init(st, d, m)
    DataDrop(d) => typecheck_data_drop(st, d)
    MemoryCopy(d, s) => typecheck_memory_copy(st, d, s)
    MemoryFill(m) => typecheck_memory_fill(st, m)
    AtomicRmw(op, ma) =>
      match op {
        I32AtomicRmwAddOp => typecheck_atomic_rmw(st, ma, 32, ValType::i32())
        I64AtomicRmwAddOp => typecheck_atomic_rmw(st, ma, 64, ValType::i64())
        I32AtomicRmw8AddUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i32())
        I32AtomicRmw16AddUOp => typecheck_atomic_rmw(st, ma, 16, ValType::i32())
        I64AtomicRmw8AddUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i64())
        I64AtomicRmw16AddUOp => typecheck_atomic_rmw(st, ma, 16, ValType::i64())
        I64AtomicRmw32AddUOp => typecheck_atomic_rmw(st, ma, 32, ValType::i64())
        I32AtomicRmwSubOp => typecheck_atomic_rmw(st, ma, 32, ValType::i32())
        I64AtomicRmwSubOp => typecheck_atomic_rmw(st, ma, 64, ValType::i64())
        I32AtomicRmw8SubUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i32())
        I32AtomicRmw16SubUOp => typecheck_atomic_rmw(st, ma, 16, ValType::i32())
        I64AtomicRmw8SubUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i64())
        I64AtomicRmw16SubUOp => typecheck_atomic_rmw(st, ma, 16, ValType::i64())
        I64AtomicRmw32SubUOp => typecheck_atomic_rmw(st, ma, 32, ValType::i64())
        I32AtomicRmwAndOp => typecheck_atomic_rmw(st, ma, 32, ValType::i32())
        I64AtomicRmwAndOp => typecheck_atomic_rmw(st, ma, 64, ValType::i64())
        I32AtomicRmw8AndUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i32())
        I32AtomicRmw16AndUOp => typecheck_atomic_rmw(st, ma, 16, ValType::i32())
        I64AtomicRmw8AndUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i64())
        I64AtomicRmw16AndUOp => typecheck_atomic_rmw(st, ma, 16, ValType::i64())
        I64AtomicRmw32AndUOp => typecheck_atomic_rmw(st, ma, 32, ValType::i64())
        I32AtomicRmwOrOp => typecheck_atomic_rmw(st, ma, 32, ValType::i32())
        I64AtomicRmwOrOp => typecheck_atomic_rmw(st, ma, 64, ValType::i64())
        I32AtomicRmw8OrUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i32())
        I32AtomicRmw16OrUOp => typecheck_atomic_rmw(st, ma, 16, ValType::i32())
        I64AtomicRmw8OrUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i64())
        I64AtomicRmw16OrUOp => typecheck_atomic_rmw(st, ma, 16, ValType::i64())
        I64AtomicRmw32OrUOp => typecheck_atomic_rmw(st, ma, 32, ValType::i64())
        I32AtomicRmwXorOp => typecheck_atomic_rmw(st, ma, 32, ValType::i32())
        I64AtomicRmwXorOp => typecheck_atomic_rmw(st, ma, 64, ValType::i64())
        I32AtomicRmw8XorUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i32())
        I32AtomicRmw16XorUOp => typecheck_atomic_rmw(st, ma, 16, ValType::i32())
        I64AtomicRmw8XorUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i64())
        I64AtomicRmw16XorUOp => typecheck_atomic_rmw(st, ma, 16, ValType::i64())
        I64AtomicRmw32XorUOp => typecheck_atomic_rmw(st, ma, 32, ValType::i64())
        I32AtomicRmwXchgOp => typecheck_atomic_rmw(st, ma, 32, ValType::i32())
        I64AtomicRmwXchgOp => typecheck_atomic_rmw(st, ma, 64, ValType::i64())
        I32AtomicRmw8XchgUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i32())
        I32AtomicRmw16XchgUOp =>
          typecheck_atomic_rmw(st, ma, 16, ValType::i32())
        I64AtomicRmw8XchgUOp => typecheck_atomic_rmw(st, ma, 8, ValType::i64())
        I64AtomicRmw16XchgUOp =>
          typecheck_atomic_rmw(st, ma, 16, ValType::i64())
        I64AtomicRmw32XchgUOp =>
          typecheck_atomic_rmw(st, ma, 32, ValType::i64())
      }
    AtomicCmpxchg(op, ma) =>
      match op {
        I32AtomicRmwCmpxchgOp =>
          typecheck_atomic_cmpxchg(st, ma, 32, ValType::i32())
        I64AtomicRmwCmpxchgOp =>
          typecheck_atomic_cmpxchg(st, ma, 64, ValType::i64())
        I32AtomicRmw8CmpxchgUOp =>
          typecheck_atomic_cmpxchg(st, ma, 8, ValType::i32())
        I32AtomicRmw16CmpxchgUOp =>
          typecheck_atomic_cmpxchg(st, ma, 16, ValType::i32())
        I64AtomicRmw8CmpxchgUOp =>
          typecheck_atomic_cmpxchg(st, ma, 8, ValType::i64())
        I64AtomicRmw16CmpxchgUOp =>
          typecheck_atomic_cmpxchg(st, ma, 16, ValType::i64())
        I64AtomicRmw32CmpxchgUOp =>
          typecheck_atomic_cmpxchg(st, ma, 32, ValType::i64())
      }
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
    RefGetDesc => typecheck_ref_get_desc(st)
    RefTest(nullable, ht) => typecheck_ref_test(st, nullable, ht)
    RefCast(nullable, ht) => typecheck_ref_cast(st, nullable, ht)
    RefTestDesc(nullable, ht) => typecheck_ref_test_desc(st, nullable, ht)
    RefCastDescEq(nullable, ht) => typecheck_ref_cast_desc_eq(st, nullable, ht)
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
    I32Eqz => typecheck_unary(st, ValType::i32(), ValType::i32())
    I32Eq => typecheck_compare(st, ValType::i32())
    I32Ne => typecheck_compare(st, ValType::i32())
    I32LtS => typecheck_compare(st, ValType::i32())
    I32LtU => typecheck_compare(st, ValType::i32())
    I32GtS => typecheck_compare(st, ValType::i32())
    I32GtU => typecheck_compare(st, ValType::i32())
    I32LeS => typecheck_compare(st, ValType::i32())
    I32LeU => typecheck_compare(st, ValType::i32())
    I32GeS => typecheck_compare(st, ValType::i32())
    I32GeU => typecheck_compare(st, ValType::i32())

    // ===== i64 relational =====
    I64Eqz => typecheck_unary(st, ValType::i64(), ValType::i32())
    I64Eq => typecheck_compare(st, ValType::i64())
    I64Ne => typecheck_compare(st, ValType::i64())
    I64LtS => typecheck_compare(st, ValType::i64())
    I64LtU => typecheck_compare(st, ValType::i64())
    I64GtS => typecheck_compare(st, ValType::i64())
    I64GtU => typecheck_compare(st, ValType::i64())
    I64LeS => typecheck_compare(st, ValType::i64())
    I64LeU => typecheck_compare(st, ValType::i64())
    I64GeS => typecheck_compare(st, ValType::i64())
    I64GeU => typecheck_compare(st, ValType::i64())

    // ===== f32 relational =====
    F32Eq => typecheck_compare(st, ValType::f32())
    F32Ne => typecheck_compare(st, ValType::f32())
    F32Lt => typecheck_compare(st, ValType::f32())
    F32Gt => typecheck_compare(st, ValType::f32())
    F32Le => typecheck_compare(st, ValType::f32())
    F32Ge => typecheck_compare(st, ValType::f32())

    // ===== f64 relational =====
    F64Eq => typecheck_compare(st, ValType::f64())
    F64Ne => typecheck_compare(st, ValType::f64())
    F64Lt => typecheck_compare(st, ValType::f64())
    F64Gt => typecheck_compare(st, ValType::f64())
    F64Le => typecheck_compare(st, ValType::f64())
    F64Ge => typecheck_compare(st, ValType::f64())

    // ===== i32 unary =====
    I32Clz => typecheck_unary(st, ValType::i32(), ValType::i32())
    I32Ctz => typecheck_unary(st, ValType::i32(), ValType::i32())
    I32Popcnt => typecheck_unary(st, ValType::i32(), ValType::i32())

    // ===== i64 unary =====
    I64Clz => typecheck_unary(st, ValType::i64(), ValType::i64())
    I64Ctz => typecheck_unary(st, ValType::i64(), ValType::i64())
    I64Popcnt => typecheck_unary(st, ValType::i64(), ValType::i64())

    // ===== i32 binary =====
    I32Add => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32Sub => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32Mul => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32DivS => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32DivU => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32RemS => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32RemU => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32And => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32Or => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32Xor => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32Shl => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32ShrS => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32ShrU => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32Rotl => typecheck_binary(st, ValType::i32(), ValType::i32())
    I32Rotr => typecheck_binary(st, ValType::i32(), ValType::i32())

    // ===== i64 binary =====
    I64Add => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64Sub => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64Mul => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64DivS => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64DivU => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64RemS => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64RemU => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64And => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64Or => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64Xor => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64Shl => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64ShrS => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64ShrU => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64Rotl => typecheck_binary(st, ValType::i64(), ValType::i64())
    I64Rotr => typecheck_binary(st, ValType::i64(), ValType::i64())

    // ===== f32 unary =====
    F32Abs => typecheck_unary(st, ValType::f32(), ValType::f32())
    F32Neg => typecheck_unary(st, ValType::f32(), ValType::f32())
    F32Ceil => typecheck_unary(st, ValType::f32(), ValType::f32())
    F32Floor => typecheck_unary(st, ValType::f32(), ValType::f32())
    F32Trunc => typecheck_unary(st, ValType::f32(), ValType::f32())
    F32Nearest => typecheck_unary(st, ValType::f32(), ValType::f32())
    F32Sqrt => typecheck_unary(st, ValType::f32(), ValType::f32())

    // ===== f32 binary =====
    F32Add => typecheck_binary(st, ValType::f32(), ValType::f32())
    F32Sub => typecheck_binary(st, ValType::f32(), ValType::f32())
    F32Mul => typecheck_binary(st, ValType::f32(), ValType::f32())
    F32Div => typecheck_binary(st, ValType::f32(), ValType::f32())
    F32Min => typecheck_binary(st, ValType::f32(), ValType::f32())
    F32Max => typecheck_binary(st, ValType::f32(), ValType::f32())
    F32Copysign => typecheck_binary(st, ValType::f32(), ValType::f32())

    // ===== f64 unary =====
    F64Abs => typecheck_unary(st, ValType::f64(), ValType::f64())
    F64Neg => typecheck_unary(st, ValType::f64(), ValType::f64())
    F64Ceil => typecheck_unary(st, ValType::f64(), ValType::f64())
    F64Floor => typecheck_unary(st, ValType::f64(), ValType::f64())
    F64Trunc => typecheck_unary(st, ValType::f64(), ValType::f64())
    F64Nearest => typecheck_unary(st, ValType::f64(), ValType::f64())
    F64Sqrt => typecheck_unary(st, ValType::f64(), ValType::f64())

    // ===== f64 binary =====
    F64Add => typecheck_binary(st, ValType::f64(), ValType::f64())
    F64Sub => typecheck_binary(st, ValType::f64(), ValType::f64())
    F64Mul => typecheck_binary(st, ValType::f64(), ValType::f64())
    F64Div => typecheck_binary(st, ValType::f64(), ValType::f64())
    F64Min => typecheck_binary(st, ValType::f64(), ValType::f64())
    F64Max => typecheck_binary(st, ValType::f64(), ValType::f64())
    F64Copysign => typecheck_binary(st, ValType::f64(), ValType::f64())

    // ===== conversions / reinterprets =====

    // i32.wrap_i64 : i64 -> i32
    I32WrapI64 => typecheck_unary(st, ValType::i64(), ValType::i32())

    // i32.trunc_f32/f64_{s,u} : f32/f64 -> i32
    I32TruncF32S => typecheck_unary(st, ValType::f32(), ValType::i32())
    I32TruncF32U => typecheck_unary(st, ValType::f32(), ValType::i32())
    I32TruncF64S => typecheck_unary(st, ValType::f64(), ValType::i32())
    I32TruncF64U => typecheck_unary(st, ValType::f64(), ValType::i32())

    // i64.extend_i32_{s,u} : i32 -> i64
    I64ExtendI32S => typecheck_unary(st, ValType::i32(), ValType::i64())
    I64ExtendI32U => typecheck_unary(st, ValType::i32(), ValType::i64())

    // i64.trunc_f32/f64_{s,u} : f32/f64 -> i64
    I64TruncF32S => typecheck_unary(st, ValType::f32(), ValType::i64())
    I64TruncF32U => typecheck_unary(st, ValType::f32(), ValType::i64())
    I64TruncF64S => typecheck_unary(st, ValType::f64(), ValType::i64())
    I64TruncF64U => typecheck_unary(st, ValType::f64(), ValType::i64())

    // f32.convert_i32/i64_{s,u} : i32/i64 -> f32
    F32ConvertI32S => typecheck_unary(st, ValType::i32(), ValType::f32())
    F32ConvertI32U => typecheck_unary(st, ValType::i32(), ValType::f32())
    F32ConvertI64S => typecheck_unary(st, ValType::i64(), ValType::f32())
    F32ConvertI64U => typecheck_unary(st, ValType::i64(), ValType::f32())

    // f32.demote_f64 : f64 -> f32
    F32DemoteF64 => typecheck_unary(st, ValType::f64(), ValType::f32())

    // f64.convert_i32/i64_{s,u} : i32/i64 -> f64
    F64ConvertI32S => typecheck_unary(st, ValType::i32(), ValType::f64())
    F64ConvertI32U => typecheck_unary(st, ValType::i32(), ValType::f64())
    F64ConvertI64S => typecheck_unary(st, ValType::i64(), ValType::f64())
    F64ConvertI64U => typecheck_unary(st, ValType::i64(), ValType::f64())

    // f64.promote_f32 : f32 -> f64
    F64PromoteF32 => typecheck_unary(st, ValType::f32(), ValType::f64())

    // reinterprets
    I32ReinterpretF32 => typecheck_unary(st, ValType::f32(), ValType::i32())
    I64ReinterpretF64 => typecheck_unary(st, ValType::f64(), ValType::i64())
    F32ReinterpretI32 => typecheck_unary(st, ValType::i32(), ValType::f32())
    F64ReinterpretI64 => typecheck_unary(st, ValType::i64(), ValType::f64())

    // sign-extension (unary)
    I32Extend8S => typecheck_unary(st, ValType::i32(), ValType::i32())
    I32Extend16S => typecheck_unary(st, ValType::i32(), ValType::i32())
    I64Extend8S => typecheck_unary(st, ValType::i64(), ValType::i64())
    I64Extend16S => typecheck_unary(st, ValType::i64(), ValType::i64())
    I64Extend32S => typecheck_unary(st, ValType::i64(), ValType::i64())

    // saturating trunc (same typing as trunc)
    I32TruncSatF32S => typecheck_unary(st, ValType::f32(), ValType::i32())
    I32TruncSatF32U => typecheck_unary(st, ValType::f32(), ValType::i32())
    I32TruncSatF64S => typecheck_unary(st, ValType::f64(), ValType::i32())
    I32TruncSatF64U => typecheck_unary(st, ValType::f64(), ValType::i32())
    I64TruncSatF32S => typecheck_unary(st, ValType::f32(), ValType::i64())
    I64TruncSatF32U => typecheck_unary(st, ValType::f32(), ValType::i64())
    I64TruncSatF64S => typecheck_unary(st, ValType::f64(), ValType::i64())
    I64TruncSatF64U => typecheck_unary(st, ValType::f64(), ValType::i64())
    V128Not => typecheck_v128_unary(st)
    V128And => typecheck_v128_binary(st)
    V128Andnot => typecheck_v128_binary(st)
    V128Or => typecheck_v128_binary(st)
    V128Xor => typecheck_v128_binary(st)
    V128Bitselect => typecheck_v128_ternary(st)
    V128AnyTrue => typecheck_unary(st, ValType::v128(), ValType::i32())

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
    I8x16Splat => typecheck_splat(st, ValType::i32()) // i32 -> v128 (only low 8 bits used)
    I16x8Splat => typecheck_splat(st, ValType::i32()) // i32 -> v128
    I32x4Splat => typecheck_splat(st, ValType::i32()) // i32 -> v128
    I64x2Splat => typecheck_splat(st, ValType::i64()) // i64 -> v128
    F32x4Splat => typecheck_splat(st, ValType::f32()) // f32 -> v128
    F64x2Splat => typecheck_splat(st, ValType::f64()) // f64 -> v128
    I8x16ExtractLaneS(_) => typecheck_lane_extract(st, ValType::i32())
    I8x16ExtractLaneU(_) => typecheck_lane_extract(st, ValType::i32())
    I16x8ExtractLaneS(_) => typecheck_lane_extract(st, ValType::i32())
    I16x8ExtractLaneU(_) => typecheck_lane_extract(st, ValType::i32())
    I32x4ExtractLane(_) => typecheck_lane_extract(st, ValType::i32())
    I64x2ExtractLane(_) => typecheck_lane_extract(st, ValType::i64())
    F32x4ExtractLane(_) => typecheck_lane_extract(st, ValType::f32())
    F64x2ExtractLane(_) => typecheck_lane_extract(st, ValType::f64())
    I8x16ReplaceLane(_) => typecheck_lane_replace(st, ValType::i32())
    I16x8ReplaceLane(_) => typecheck_lane_replace(st, ValType::i32())
    I32x4ReplaceLane(_) => typecheck_lane_replace(st, ValType::i32())
    I64x2ReplaceLane(_) => typecheck_lane_replace(st, ValType::i64())
    F32x4ReplaceLane(_) => typecheck_lane_replace(st, ValType::f32())
    F64x2ReplaceLane(_) => typecheck_lane_replace(st, ValType::f64())
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
    I8x16AllTrue => typecheck_unary(st, ValType::v128(), ValType::i32())
    I8x16Bitmask => typecheck_unary(st, ValType::v128(), ValType::i32())
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
    I16x8AllTrue => typecheck_unary(st, ValType::v128(), ValType::i32())
    I16x8Bitmask => typecheck_unary(st, ValType::v128(), ValType::i32())
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
    I32x4AllTrue => typecheck_unary(st, ValType::v128(), ValType::i32())
    I32x4Bitmask => typecheck_unary(st, ValType::v128(), ValType::i32())
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
    I64x2AllTrue => typecheck_unary(st, ValType::v128(), ValType::i32())
    I64x2Bitmask => typecheck_unary(st, ValType::v128(), ValType::i32())
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

///|
pub impl Typecheck for TInstr with typecheck(self, st) {
  match self {
    // === Constants ===
    TI32Const(_) => Ok(st.push1(ValType::i32()))
    TI64Const(_) => Ok(st.push1(ValType::i64()))
    TF32Const(_) => Ok(st.push1(ValType::f32()))
    TF64Const(_) => Ok(st.push1(ValType::f64()))
    TRefNull(ht) => typecheck_ref_null(st, ht)
    TRefFunc(f) => typecheck_ref_func(st, f)
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      typecheck_v128_const(st)

    // === Nullary ===
    TUnreachable => Ok(TcState::{ ..st, reachable: false })
    TNop => Ok(st)
    TLocalGet(i) => typecheck_local_get(st, i)
    TGlobalGet(i) => typecheck_global_get(st, i)
    TMemorySize(m) => typecheck_memory_size(st, m)
    TTableSize(t) => typecheck_table_size(st, t)

    // === Unary ===
    TUnary(op, child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      match op {
        // Scalar
        I32EqzOp => typecheck_unary(st1, ValType::i32(), ValType::i32())
        I64EqzOp => typecheck_unary(st1, ValType::i64(), ValType::i32())
        I32ClzOp => typecheck_unary(st1, ValType::i32(), ValType::i32())
        I32CtzOp => typecheck_unary(st1, ValType::i32(), ValType::i32())
        I32PopcntOp => typecheck_unary(st1, ValType::i32(), ValType::i32())
        I64ClzOp => typecheck_unary(st1, ValType::i64(), ValType::i64())
        I64CtzOp => typecheck_unary(st1, ValType::i64(), ValType::i64())
        I64PopcntOp => typecheck_unary(st1, ValType::i64(), ValType::i64())
        F32AbsOp => typecheck_unary(st1, ValType::f32(), ValType::f32())
        F32NegOp => typecheck_unary(st1, ValType::f32(), ValType::f32())
        F32CeilOp => typecheck_unary(st1, ValType::f32(), ValType::f32())
        F32FloorOp => typecheck_unary(st1, ValType::f32(), ValType::f32())
        F32TruncOp => typecheck_unary(st1, ValType::f32(), ValType::f32())
        F32NearestOp => typecheck_unary(st1, ValType::f32(), ValType::f32())
        F32SqrtOp => typecheck_unary(st1, ValType::f32(), ValType::f32())
        F64AbsOp => typecheck_unary(st1, ValType::f64(), ValType::f64())
        F64NegOp => typecheck_unary(st1, ValType::f64(), ValType::f64())
        F64CeilOp => typecheck_unary(st1, ValType::f64(), ValType::f64())
        F64FloorOp => typecheck_unary(st1, ValType::f64(), ValType::f64())
        F64TruncOp => typecheck_unary(st1, ValType::f64(), ValType::f64())
        F64NearestOp => typecheck_unary(st1, ValType::f64(), ValType::f64())
        F64SqrtOp => typecheck_unary(st1, ValType::f64(), ValType::f64())
        I32WrapI64Op => typecheck_unary(st1, ValType::i64(), ValType::i32())
        I32TruncF32SOp => typecheck_unary(st1, ValType::f32(), ValType::i32())
        I32TruncF32UOp => typecheck_unary(st1, ValType::f32(), ValType::i32())
        I32TruncF64SOp => typecheck_unary(st1, ValType::f64(), ValType::i32())
        I32TruncF64UOp => typecheck_unary(st1, ValType::f64(), ValType::i32())
        I64ExtendI32SOp => typecheck_unary(st1, ValType::i32(), ValType::i64())
        I64ExtendI32UOp => typecheck_unary(st1, ValType::i32(), ValType::i64())
        I64TruncF32SOp => typecheck_unary(st1, ValType::f32(), ValType::i64())
        I64TruncF32UOp => typecheck_unary(st1, ValType::f32(), ValType::i64())
        I64TruncF64SOp => typecheck_unary(st1, ValType::f64(), ValType::i64())
        I64TruncF64UOp => typecheck_unary(st1, ValType::f64(), ValType::i64())
        F32ConvertI32SOp => typecheck_unary(st1, ValType::i32(), ValType::f32())
        F32ConvertI32UOp => typecheck_unary(st1, ValType::i32(), ValType::f32())
        F32ConvertI64SOp => typecheck_unary(st1, ValType::i64(), ValType::f32())
        F32ConvertI64UOp => typecheck_unary(st1, ValType::i64(), ValType::f32())
        F32DemoteF64Op => typecheck_unary(st1, ValType::f64(), ValType::f32())
        F64ConvertI32SOp => typecheck_unary(st1, ValType::i32(), ValType::f64())
        F64ConvertI32UOp => typecheck_unary(st1, ValType::i32(), ValType::f64())
        F64ConvertI64SOp => typecheck_unary(st1, ValType::i64(), ValType::f64())
        F64ConvertI64UOp => typecheck_unary(st1, ValType::i64(), ValType::f64())
        F64PromoteF32Op => typecheck_unary(st1, ValType::f32(), ValType::f64())
        I32ReinterpretF32Op =>
          typecheck_unary(st1, ValType::f32(), ValType::i32())
        I64ReinterpretF64Op =>
          typecheck_unary(st1, ValType::f64(), ValType::i64())
        F32ReinterpretI32Op =>
          typecheck_unary(st1, ValType::i32(), ValType::f32())
        F64ReinterpretI64Op =>
          typecheck_unary(st1, ValType::i64(), ValType::f64())
        I32Extend8SOp => typecheck_unary(st1, ValType::i32(), ValType::i32())
        I32Extend16SOp => typecheck_unary(st1, ValType::i32(), ValType::i32())
        I64Extend8SOp => typecheck_unary(st1, ValType::i64(), ValType::i64())
        I64Extend16SOp => typecheck_unary(st1, ValType::i64(), ValType::i64())
        I64Extend32SOp => typecheck_unary(st1, ValType::i64(), ValType::i64())
        I32TruncSatF32SOp =>
          typecheck_unary(st1, ValType::f32(), ValType::i32())
        I32TruncSatF32UOp =>
          typecheck_unary(st1, ValType::f32(), ValType::i32())
        I32TruncSatF64SOp =>
          typecheck_unary(st1, ValType::f64(), ValType::i32())
        I32TruncSatF64UOp =>
          typecheck_unary(st1, ValType::f64(), ValType::i32())
        I64TruncSatF32SOp =>
          typecheck_unary(st1, ValType::f32(), ValType::i64())
        I64TruncSatF32UOp =>
          typecheck_unary(st1, ValType::f32(), ValType::i64())
        I64TruncSatF64SOp =>
          typecheck_unary(st1, ValType::f64(), ValType::i64())
        I64TruncSatF64UOp =>
          typecheck_unary(st1, ValType::f64(), ValType::i64())

        // SIMD: Unary
        V128NotOp => typecheck_v128_unary(st1)
        I8x16AbsOp => typecheck_v128_unary(st1)
        I8x16NegOp => typecheck_v128_unary(st1)
        I8x16PopcntOp => typecheck_v128_unary(st1)
        I16x8AbsOp => typecheck_v128_unary(st1)
        I16x8NegOp => typecheck_v128_unary(st1)
        I32x4AbsOp => typecheck_v128_unary(st1)
        I32x4NegOp => typecheck_v128_unary(st1)
        I64x2AbsOp => typecheck_v128_unary(st1)
        I64x2NegOp => typecheck_v128_unary(st1)
        F32x4AbsOp => typecheck_v128_unary(st1)
        F32x4NegOp => typecheck_v128_unary(st1)
        F32x4SqrtOp => typecheck_v128_unary(st1)
        F32x4CeilOp => typecheck_v128_unary(st1)
        F32x4FloorOp => typecheck_v128_unary(st1)
        F32x4TruncOp => typecheck_v128_unary(st1)
        F32x4NearestOp => typecheck_v128_unary(st1)
        F64x2AbsOp => typecheck_v128_unary(st1)
        F64x2NegOp => typecheck_v128_unary(st1)
        F64x2SqrtOp => typecheck_v128_unary(st1)
        F64x2CeilOp => typecheck_v128_unary(st1)
        F64x2FloorOp => typecheck_v128_unary(st1)
        F64x2TruncOp => typecheck_v128_unary(st1)
        F64x2NearestOp => typecheck_v128_unary(st1)

        // SIMD: Unary (v128 -> i32)
        V128AnyTrueOp => typecheck_unary(st1, ValType::v128(), ValType::i32())
        I8x16AllTrueOp => typecheck_unary(st1, ValType::v128(), ValType::i32())
        I8x16BitmaskOp => typecheck_unary(st1, ValType::v128(), ValType::i32())
        I16x8AllTrueOp => typecheck_unary(st1, ValType::v128(), ValType::i32())
        I16x8BitmaskOp => typecheck_unary(st1, ValType::v128(), ValType::i32())
        I32x4AllTrueOp => typecheck_unary(st1, ValType::v128(), ValType::i32())
        I32x4BitmaskOp => typecheck_unary(st1, ValType::v128(), ValType::i32())
        I64x2AllTrueOp => typecheck_unary(st1, ValType::v128(), ValType::i32())
        I64x2BitmaskOp => typecheck_unary(st1, ValType::v128(), ValType::i32())

        // SIMD: Extend/narrow/pairwise
        I16x8ExtendLowI8x16SOp => typecheck_v128_unary(st1)
        I16x8ExtendHighI8x16SOp => typecheck_v128_unary(st1)
        I16x8ExtendLowI8x16UOp => typecheck_v128_unary(st1)
        I16x8ExtendHighI8x16UOp => typecheck_v128_unary(st1)
        I32x4ExtendLowI16x8SOp => typecheck_v128_unary(st1)
        I32x4ExtendHighI16x8SOp => typecheck_v128_unary(st1)
        I32x4ExtendLowI16x8UOp => typecheck_v128_unary(st1)
        I32x4ExtendHighI16x8UOp => typecheck_v128_unary(st1)
        I64x2ExtendLowI32x4SOp => typecheck_v128_unary(st1)
        I64x2ExtendHighI32x4SOp => typecheck_v128_unary(st1)
        I64x2ExtendLowI32x4UOp => typecheck_v128_unary(st1)
        I64x2ExtendHighI32x4UOp => typecheck_v128_unary(st1)
        I16x8ExtaddPairwiseI8x16SOp => typecheck_v128_unary(st1)
        I16x8ExtaddPairwiseI8x16UOp => typecheck_v128_unary(st1)
        I32x4ExtaddPairwiseI16x8SOp => typecheck_v128_unary(st1)
        I32x4ExtaddPairwiseI16x8UOp => typecheck_v128_unary(st1)

        // SIMD: Conversions
        F32x4DemoteF64x2ZeroOp => typecheck_v128_unary(st1)
        F64x2PromoteLowF32x4Op => typecheck_v128_unary(st1)
        I32x4TruncSatF32x4SOp => typecheck_v128_unary(st1)
        I32x4TruncSatF32x4UOp => typecheck_v128_unary(st1)
        F32x4ConvertI32x4SOp => typecheck_v128_unary(st1)
        F32x4ConvertI32x4UOp => typecheck_v128_unary(st1)
        I32x4TruncSatF64x2SZeroOp => typecheck_v128_unary(st1)
        I32x4TruncSatF64x2UZeroOp => typecheck_v128_unary(st1)
        F64x2ConvertLowI32x4SOp => typecheck_v128_unary(st1)
        F64x2ConvertLowI32x4UOp => typecheck_v128_unary(st1)

        // SIMD: Relaxed
        I32x4RelaxedTruncF32x4SOp => typecheck_v128_unary(st1)
        I32x4RelaxedTruncF32x4UOp => typecheck_v128_unary(st1)
        I32x4RelaxedTruncZeroF64x2SOp => typecheck_v128_unary(st1)
        I32x4RelaxedTruncZeroF64x2UOp => typecheck_v128_unary(st1)
      }
    }
    TDrop(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_drop(st1)
    }
    TLocalSet(i, child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_local_set(st1, i)
    }
    TLocalTee(i, child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_local_tee(st1, i)
    }
    TGlobalSet(i, child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_global_set(st1, i)
    }
    TRefIsNull(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_ref_is_null(st1)
    }
    TRefAsNonNull(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_ref_as_non_null(st1)
    }
    TI31GetS(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_i31_get(st1)
    }
    TI31GetU(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_i31_get(st1)
    }
    TRefI31(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_ref_i31(st1)
    }
    TArrayLen(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_array_len(st1)
    }
    TAnyConvertExtern(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_any_convert_extern(st1)
    }
    TExternConvertAny(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_extern_convert_any(st1)
    }
    TThrowRef(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      typecheck_throw_ref(st1)
    }

    // === Binary ===
    TBinary(op, left, right) => {
      let st1 = match Typecheck::typecheck(left, st) {
        Ok(st1) => st1
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(right, st1) {
        Ok(st2) => st2
        Err(t) => return Err(t)
      }
      match op {
        // Scalar Comparisons
        I32EqOp => typecheck_compare(st2, ValType::i32())
        I32NeOp => typecheck_compare(st2, ValType::i32())
        I32LtSOp => typecheck_compare(st2, ValType::i32())
        I32LtUOp => typecheck_compare(st2, ValType::i32())
        I32GtSOp => typecheck_compare(st2, ValType::i32())
        I32GtUOp => typecheck_compare(st2, ValType::i32())
        I32LeSOp => typecheck_compare(st2, ValType::i32())
        I32LeUOp => typecheck_compare(st2, ValType::i32())
        I32GeSOp => typecheck_compare(st2, ValType::i32())
        I32GeUOp => typecheck_compare(st2, ValType::i32())
        I64EqOp => typecheck_compare(st2, ValType::i64())
        I64NeOp => typecheck_compare(st2, ValType::i64())
        I64LtSOp => typecheck_compare(st2, ValType::i64())
        I64LtUOp => typecheck_compare(st2, ValType::i64())
        I64GtSOp => typecheck_compare(st2, ValType::i64())
        I64GtUOp => typecheck_compare(st2, ValType::i64())
        I64LeSOp => typecheck_compare(st2, ValType::i64())
        I64LeUOp => typecheck_compare(st2, ValType::i64())
        I64GeSOp => typecheck_compare(st2, ValType::i64())
        I64GeUOp => typecheck_compare(st2, ValType::i64())
        F32EqOp => typecheck_compare(st2, ValType::f32())
        F32NeOp => typecheck_compare(st2, ValType::f32())
        F32LtOp => typecheck_compare(st2, ValType::f32())
        F32GtOp => typecheck_compare(st2, ValType::f32())
        F32LeOp => typecheck_compare(st2, ValType::f32())
        F32GeOp => typecheck_compare(st2, ValType::f32())
        F64EqOp => typecheck_compare(st2, ValType::f64())
        F64NeOp => typecheck_compare(st2, ValType::f64())
        F64LtOp => typecheck_compare(st2, ValType::f64())
        F64GtOp => typecheck_compare(st2, ValType::f64())
        F64LeOp => typecheck_compare(st2, ValType::f64())
        F64GeOp => typecheck_compare(st2, ValType::f64())

        // Scalar Arithmetic
        I32AddOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32SubOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32MulOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32DivSOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32DivUOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32RemSOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32RemUOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32AndOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32OrOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32XorOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32ShlOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32ShrSOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32ShrUOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32RotlOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I32RotrOp => typecheck_binary(st2, ValType::i32(), ValType::i32())
        I64AddOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64SubOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64MulOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64DivSOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64DivUOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64RemSOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64RemUOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64AndOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64OrOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64XorOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64ShlOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64ShrSOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64ShrUOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64RotlOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        I64RotrOp => typecheck_binary(st2, ValType::i64(), ValType::i64())
        F32AddOp => typecheck_binary(st2, ValType::f32(), ValType::f32())
        F32SubOp => typecheck_binary(st2, ValType::f32(), ValType::f32())
        F32MulOp => typecheck_binary(st2, ValType::f32(), ValType::f32())
        F32DivOp => typecheck_binary(st2, ValType::f32(), ValType::f32())
        F32MinOp => typecheck_binary(st2, ValType::f32(), ValType::f32())
        F32MaxOp => typecheck_binary(st2, ValType::f32(), ValType::f32())
        F32CopysignOp => typecheck_binary(st2, ValType::f32(), ValType::f32())
        F64AddOp => typecheck_binary(st2, ValType::f64(), ValType::f64())
        F64SubOp => typecheck_binary(st2, ValType::f64(), ValType::f64())
        F64MulOp => typecheck_binary(st2, ValType::f64(), ValType::f64())
        F64DivOp => typecheck_binary(st2, ValType::f64(), ValType::f64())
        F64MinOp => typecheck_binary(st2, ValType::f64(), ValType::f64())
        F64MaxOp => typecheck_binary(st2, ValType::f64(), ValType::f64())
        F64CopysignOp => typecheck_binary(st2, ValType::f64(), ValType::f64())

        // SIMD Binary
        V128AndOp => typecheck_v128_binary(st2)
        V128AndnotOp => typecheck_v128_binary(st2)
        V128OrOp => typecheck_v128_binary(st2)
        V128XorOp => typecheck_v128_binary(st2)
        I8x16EqOp => typecheck_v128_compare(st2)
        I8x16NeOp => typecheck_v128_compare(st2)
        I8x16LtSOp => typecheck_v128_compare(st2)
        I8x16LtUOp => typecheck_v128_compare(st2)
        I8x16GtSOp => typecheck_v128_compare(st2)
        I8x16GtUOp => typecheck_v128_compare(st2)
        I8x16LeSOp => typecheck_v128_compare(st2)
        I8x16LeUOp => typecheck_v128_compare(st2)
        I8x16GeSOp => typecheck_v128_compare(st2)
        I8x16GeUOp => typecheck_v128_compare(st2)
        I16x8EqOp => typecheck_v128_compare(st2)
        I16x8NeOp => typecheck_v128_compare(st2)
        I16x8LtSOp => typecheck_v128_compare(st2)
        I16x8LtUOp => typecheck_v128_compare(st2)
        I16x8GtSOp => typecheck_v128_compare(st2)
        I16x8GtUOp => typecheck_v128_compare(st2)
        I16x8LeSOp => typecheck_v128_compare(st2)
        I16x8LeUOp => typecheck_v128_compare(st2)
        I16x8GeSOp => typecheck_v128_compare(st2)
        I16x8GeUOp => typecheck_v128_compare(st2)
        I32x4EqOp => typecheck_v128_compare(st2)
        I32x4NeOp => typecheck_v128_compare(st2)
        I32x4LtSOp => typecheck_v128_compare(st2)
        I32x4LtUOp => typecheck_v128_compare(st2)
        I32x4GtSOp => typecheck_v128_compare(st2)
        I32x4GtUOp => typecheck_v128_compare(st2)
        I32x4LeSOp => typecheck_v128_compare(st2)
        I32x4LeUOp => typecheck_v128_compare(st2)
        I32x4GeSOp => typecheck_v128_compare(st2)
        I32x4GeUOp => typecheck_v128_compare(st2)
        I64x2EqOp => typecheck_v128_compare(st2)
        I64x2NeOp => typecheck_v128_compare(st2)
        I64x2LtSOp => typecheck_v128_compare(st2)
        I64x2GtSOp => typecheck_v128_compare(st2)
        I64x2LeSOp => typecheck_v128_compare(st2)
        I64x2GeSOp => typecheck_v128_compare(st2)
        F32x4EqOp => typecheck_v128_compare(st2)
        F32x4NeOp => typecheck_v128_compare(st2)
        F32x4LtOp => typecheck_v128_compare(st2)
        F32x4GtOp => typecheck_v128_compare(st2)
        F32x4LeOp => typecheck_v128_compare(st2)
        F32x4GeOp => typecheck_v128_compare(st2)
        F64x2EqOp => typecheck_v128_compare(st2)
        F64x2NeOp => typecheck_v128_compare(st2)
        F64x2LtOp => typecheck_v128_compare(st2)
        F64x2GtOp => typecheck_v128_compare(st2)
        F64x2LeOp => typecheck_v128_compare(st2)
        F64x2GeOp => typecheck_v128_compare(st2)
        I8x16AddOp => typecheck_v128_binary(st2)
        I8x16AddSatSOp => typecheck_v128_binary(st2)
        I8x16AddSatUOp => typecheck_v128_binary(st2)
        I8x16SubOp => typecheck_v128_binary(st2)
        I8x16SubSatSOp => typecheck_v128_binary(st2)
        I8x16SubSatUOp => typecheck_v128_binary(st2)
        I8x16MinSOp => typecheck_v128_binary(st2)
        I8x16MinUOp => typecheck_v128_binary(st2)
        I8x16MaxSOp => typecheck_v128_binary(st2)
        I8x16MaxUOp => typecheck_v128_binary(st2)
        I8x16AvgrUOp => typecheck_v128_binary(st2)
        I8x16NarrowI16x8SOp => typecheck_v128_binary(st2)
        I8x16NarrowI16x8UOp => typecheck_v128_binary(st2)
        I16x8AddOp => typecheck_v128_binary(st2)
        I16x8AddSatSOp => typecheck_v128_binary(st2)
        I16x8AddSatUOp => typecheck_v128_binary(st2)
        I16x8SubOp => typecheck_v128_binary(st2)
        I16x8SubSatSOp => typecheck_v128_binary(st2)
        I16x8SubSatUOp => typecheck_v128_binary(st2)
        I16x8MulOp => typecheck_v128_binary(st2)
        I16x8MinSOp => typecheck_v128_binary(st2)
        I16x8MinUOp => typecheck_v128_binary(st2)
        I16x8MaxSOp => typecheck_v128_binary(st2)
        I16x8MaxUOp => typecheck_v128_binary(st2)
        I16x8AvgrUOp => typecheck_v128_binary(st2)
        I16x8Q15mulrSatSOp => typecheck_v128_binary(st2)
        I16x8NarrowI32x4SOp => typecheck_v128_binary(st2)
        I16x8NarrowI32x4UOp => typecheck_v128_binary(st2)
        I16x8ExtmulLowI8x16SOp => typecheck_v128_binary(st2)
        I16x8ExtmulHighI8x16SOp => typecheck_v128_binary(st2)
        I16x8ExtmulLowI8x16UOp => typecheck_v128_binary(st2)
        I16x8ExtmulHighI8x16UOp => typecheck_v128_binary(st2)
        I32x4AddOp => typecheck_v128_binary(st2)
        I32x4SubOp => typecheck_v128_binary(st2)
        I32x4MulOp => typecheck_v128_binary(st2)
        I32x4MinSOp => typecheck_v128_binary(st2)
        I32x4MinUOp => typecheck_v128_binary(st2)
        I32x4MaxSOp => typecheck_v128_binary(st2)
        I32x4MaxUOp => typecheck_v128_binary(st2)
        I32x4DotI16x8SOp => typecheck_v128_binary(st2)
        I32x4ExtmulLowI16x8SOp => typecheck_v128_binary(st2)
        I32x4ExtmulHighI16x8SOp => typecheck_v128_binary(st2)
        I32x4ExtmulLowI16x8UOp => typecheck_v128_binary(st2)
        I32x4ExtmulHighI16x8UOp => typecheck_v128_binary(st2)
        I64x2AddOp => typecheck_v128_binary(st2)
        I64x2SubOp => typecheck_v128_binary(st2)
        I64x2MulOp => typecheck_v128_binary(st2)
        I64x2ExtmulLowI32x4SOp => typecheck_v128_binary(st2)
        I64x2ExtmulHighI32x4SOp => typecheck_v128_binary(st2)
        I64x2ExtmulLowI32x4UOp => typecheck_v128_binary(st2)
        I64x2ExtmulHighI32x4UOp => typecheck_v128_binary(st2)
        F32x4AddOp => typecheck_v128_binary(st2)
        F32x4SubOp => typecheck_v128_binary(st2)
        F32x4MulOp => typecheck_v128_binary(st2)
        F32x4DivOp => typecheck_v128_binary(st2)
        F32x4MinOp => typecheck_v128_binary(st2)
        F32x4MaxOp => typecheck_v128_binary(st2)
        F32x4PminOp => typecheck_v128_binary(st2)
        F32x4PmaxOp => typecheck_v128_binary(st2)
        F64x2AddOp => typecheck_v128_binary(st2)
        F64x2SubOp => typecheck_v128_binary(st2)
        F64x2MulOp => typecheck_v128_binary(st2)
        F64x2DivOp => typecheck_v128_binary(st2)
        F64x2MinOp => typecheck_v128_binary(st2)
        F64x2MaxOp => typecheck_v128_binary(st2)
        F64x2PminOp => typecheck_v128_binary(st2)
        F64x2PmaxOp => typecheck_v128_binary(st2)
        F32x4RelaxedMinOp => typecheck_v128_binary(st2)
        F32x4RelaxedMaxOp => typecheck_v128_binary(st2)
        F64x2RelaxedMinOp => typecheck_v128_binary(st2)
        F64x2RelaxedMaxOp => typecheck_v128_binary(st2)
        I16x8RelaxedQ15mulrSOp => typecheck_v128_binary(st2)
        I16x8RelaxedDotI8x16I7x16SOp => typecheck_v128_binary(st2)
      }
    }
    TRefEq(left, right) => {
      let st1 = match Typecheck::typecheck(left, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(right, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_ref_eq(st2)
    }
    TStore(op, ma, addr, val) => {
      let st1 = match Typecheck::typecheck(addr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(val, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      match op {
        I32StoreOp => typecheck_store(st2, ma, 32, ValType::i32())
        I64StoreOp => typecheck_store(st2, ma, 64, ValType::i64())
        F32StoreOp => typecheck_store(st2, ma, 32, ValType::f32())
        F64StoreOp => typecheck_store(st2, ma, 64, ValType::f64())
        I32Store8Op => typecheck_store(st2, ma, 8, ValType::i32())
        I32Store16Op => typecheck_store(st2, ma, 16, ValType::i32())
        I64Store8Op => typecheck_store(st2, ma, 8, ValType::i64())
        I64Store16Op => typecheck_store(st2, ma, 16, ValType::i64())
        I64Store32Op => typecheck_store(st2, ma, 32, ValType::i64())
        I32AtomicStoreOp => typecheck_store(st2, ma, 32, ValType::i32())
        I64AtomicStoreOp => typecheck_store(st2, ma, 64, ValType::i64())
        I32AtomicStore8Op => typecheck_store(st2, ma, 8, ValType::i32())
        I32AtomicStore16Op => typecheck_store(st2, ma, 16, ValType::i32())
        I64AtomicStore8Op => typecheck_store(st2, ma, 8, ValType::i64())
        I64AtomicStore16Op => typecheck_store(st2, ma, 16, ValType::i64())
        I64AtomicStore32Op => typecheck_store(st2, ma, 32, ValType::i64())
        V128StoreOp => typecheck_v128_mem_store(st2, ma, 128)
      }
    }

    // === Load ===
    TLoad(op, ma, addr) => {
      let st1 = match Typecheck::typecheck(addr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      match op {
        I32LoadOp => typecheck_load(st1, ma, 32, ValType::i32())
        I64LoadOp => typecheck_load(st1, ma, 64, ValType::i64())
        F32LoadOp => typecheck_load(st1, ma, 32, ValType::f32())
        F64LoadOp => typecheck_load(st1, ma, 64, ValType::f64())
        I32Load8SOp => typecheck_load(st1, ma, 8, ValType::i32())
        I32Load8UOp => typecheck_load(st1, ma, 8, ValType::i32())
        I32Load16SOp => typecheck_load(st1, ma, 16, ValType::i32())
        I32Load16UOp => typecheck_load(st1, ma, 16, ValType::i32())
        I64Load8SOp => typecheck_load(st1, ma, 8, ValType::i64())
        I64Load8UOp => typecheck_load(st1, ma, 8, ValType::i64())
        I64Load16SOp => typecheck_load(st1, ma, 16, ValType::i64())
        I64Load16UOp => typecheck_load(st1, ma, 16, ValType::i64())
        I64Load32SOp => typecheck_load(st1, ma, 32, ValType::i64())
        I64Load32UOp => typecheck_load(st1, ma, 32, ValType::i64())
        I32AtomicLoadOp => typecheck_load(st1, ma, 32, ValType::i32())
        I64AtomicLoadOp => typecheck_load(st1, ma, 64, ValType::i64())
        I32AtomicLoad8UOp => typecheck_load(st1, ma, 8, ValType::i32())
        I32AtomicLoad16UOp => typecheck_load(st1, ma, 16, ValType::i32())
        I64AtomicLoad8UOp => typecheck_load(st1, ma, 8, ValType::i64())
        I64AtomicLoad16UOp => typecheck_load(st1, ma, 16, ValType::i64())
        I64AtomicLoad32UOp => typecheck_load(st1, ma, 32, ValType::i64())
        V128LoadOp => typecheck_v128_mem_load(st1, ma, 128)
        V128Load8x8SOp => typecheck_v128_mem_load_extend64(st1, ma)
        V128Load8x8UOp => typecheck_v128_mem_load_extend64(st1, ma)
        V128Load16x4SOp => typecheck_v128_mem_load_extend64(st1, ma)
        V128Load16x4UOp => typecheck_v128_mem_load_extend64(st1, ma)
        V128Load32x2SOp => typecheck_v128_mem_load_extend64(st1, ma)
        V128Load32x2UOp => typecheck_v128_mem_load_extend64(st1, ma)
        V128Load8SplatOp => typecheck_v128_mem_load_splat(st1, ma, 8)
        V128Load16SplatOp => typecheck_v128_mem_load_splat(st1, ma, 16)
        V128Load32SplatOp => typecheck_v128_mem_load_splat(st1, ma, 32)
        V128Load64SplatOp => typecheck_v128_mem_load_splat(st1, ma, 64)
        V128Load32ZeroOp => typecheck_v128_mem_load_zero(st1, ma, 32)
        V128Load64ZeroOp => typecheck_v128_mem_load_zero(st1, ma, 64)
      }
    }

    // === Memory ops ===
    TMemoryGrow(m, delta) => {
      let st1 = match Typecheck::typecheck(delta, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_memory_grow(st1, m)
    }
    TMemoryFill(m, dst, val, len) => {
      let st1 = match Typecheck::typecheck(dst, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(val, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(len, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_memory_fill(st3, m)
    }
    TMemoryCopy(mi0, mi1, dst, src, len) => {
      let st1 = match Typecheck::typecheck(dst, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(src, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(len, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_memory_copy(st3, mi0, mi1)
    }
    TMemoryInit(d, m, dst, src, len) => {
      let st1 = match Typecheck::typecheck(dst, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(src, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(len, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_memory_init(st3, d, m)
    }
    TDataDrop(d) => typecheck_data_drop(st, d)
    TMemoryAtomicNotify(ma, addr, count) => {
      let st1 = match Typecheck::typecheck(addr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(count, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_atomic_notify(st2, ma)
    }
    TMemoryAtomicWait32(ma, addr, expected, timeout) => {
      let st1 = match Typecheck::typecheck(addr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(expected, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(timeout, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_atomic_wait(st3, ma, 32, ValType::i32())
    }
    TMemoryAtomicWait64(ma, addr, expected, timeout) => {
      let st1 = match Typecheck::typecheck(addr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(expected, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(timeout, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_atomic_wait(st3, ma, 64, ValType::i64())
    }
    TAtomicFence => Ok(st)
    TAtomicRmw(op, ma, addr, value) => {
      let st1 = match Typecheck::typecheck(addr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(value, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      match op {
        I32AtomicRmwAddOp => typecheck_atomic_rmw(st2, ma, 32, ValType::i32())
        I64AtomicRmwAddOp => typecheck_atomic_rmw(st2, ma, 64, ValType::i64())
        I32AtomicRmw8AddUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i32())
        I32AtomicRmw16AddUOp =>
          typecheck_atomic_rmw(st2, ma, 16, ValType::i32())
        I64AtomicRmw8AddUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i64())
        I64AtomicRmw16AddUOp =>
          typecheck_atomic_rmw(st2, ma, 16, ValType::i64())
        I64AtomicRmw32AddUOp =>
          typecheck_atomic_rmw(st2, ma, 32, ValType::i64())
        I32AtomicRmwSubOp => typecheck_atomic_rmw(st2, ma, 32, ValType::i32())
        I64AtomicRmwSubOp => typecheck_atomic_rmw(st2, ma, 64, ValType::i64())
        I32AtomicRmw8SubUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i32())
        I32AtomicRmw16SubUOp =>
          typecheck_atomic_rmw(st2, ma, 16, ValType::i32())
        I64AtomicRmw8SubUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i64())
        I64AtomicRmw16SubUOp =>
          typecheck_atomic_rmw(st2, ma, 16, ValType::i64())
        I64AtomicRmw32SubUOp =>
          typecheck_atomic_rmw(st2, ma, 32, ValType::i64())
        I32AtomicRmwAndOp => typecheck_atomic_rmw(st2, ma, 32, ValType::i32())
        I64AtomicRmwAndOp => typecheck_atomic_rmw(st2, ma, 64, ValType::i64())
        I32AtomicRmw8AndUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i32())
        I32AtomicRmw16AndUOp =>
          typecheck_atomic_rmw(st2, ma, 16, ValType::i32())
        I64AtomicRmw8AndUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i64())
        I64AtomicRmw16AndUOp =>
          typecheck_atomic_rmw(st2, ma, 16, ValType::i64())
        I64AtomicRmw32AndUOp =>
          typecheck_atomic_rmw(st2, ma, 32, ValType::i64())
        I32AtomicRmwOrOp => typecheck_atomic_rmw(st2, ma, 32, ValType::i32())
        I64AtomicRmwOrOp => typecheck_atomic_rmw(st2, ma, 64, ValType::i64())
        I32AtomicRmw8OrUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i32())
        I32AtomicRmw16OrUOp => typecheck_atomic_rmw(st2, ma, 16, ValType::i32())
        I64AtomicRmw8OrUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i64())
        I64AtomicRmw16OrUOp => typecheck_atomic_rmw(st2, ma, 16, ValType::i64())
        I64AtomicRmw32OrUOp => typecheck_atomic_rmw(st2, ma, 32, ValType::i64())
        I32AtomicRmwXorOp => typecheck_atomic_rmw(st2, ma, 32, ValType::i32())
        I64AtomicRmwXorOp => typecheck_atomic_rmw(st2, ma, 64, ValType::i64())
        I32AtomicRmw8XorUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i32())
        I32AtomicRmw16XorUOp =>
          typecheck_atomic_rmw(st2, ma, 16, ValType::i32())
        I64AtomicRmw8XorUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i64())
        I64AtomicRmw16XorUOp =>
          typecheck_atomic_rmw(st2, ma, 16, ValType::i64())
        I64AtomicRmw32XorUOp =>
          typecheck_atomic_rmw(st2, ma, 32, ValType::i64())
        I32AtomicRmwXchgOp => typecheck_atomic_rmw(st2, ma, 32, ValType::i32())
        I64AtomicRmwXchgOp => typecheck_atomic_rmw(st2, ma, 64, ValType::i64())
        I32AtomicRmw8XchgUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i32())
        I32AtomicRmw16XchgUOp =>
          typecheck_atomic_rmw(st2, ma, 16, ValType::i32())
        I64AtomicRmw8XchgUOp => typecheck_atomic_rmw(st2, ma, 8, ValType::i64())
        I64AtomicRmw16XchgUOp =>
          typecheck_atomic_rmw(st2, ma, 16, ValType::i64())
        I64AtomicRmw32XchgUOp =>
          typecheck_atomic_rmw(st2, ma, 32, ValType::i64())
      }
    }
    TAtomicCmpxchg(op, ma, addr, expected, replacement) => {
      let st1 = match Typecheck::typecheck(addr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(expected, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(replacement, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      match op {
        I32AtomicRmwCmpxchgOp =>
          typecheck_atomic_cmpxchg(st3, ma, 32, ValType::i32())
        I64AtomicRmwCmpxchgOp =>
          typecheck_atomic_cmpxchg(st3, ma, 64, ValType::i64())
        I32AtomicRmw8CmpxchgUOp =>
          typecheck_atomic_cmpxchg(st3, ma, 8, ValType::i32())
        I32AtomicRmw16CmpxchgUOp =>
          typecheck_atomic_cmpxchg(st3, ma, 16, ValType::i32())
        I64AtomicRmw8CmpxchgUOp =>
          typecheck_atomic_cmpxchg(st3, ma, 8, ValType::i64())
        I64AtomicRmw16CmpxchgUOp =>
          typecheck_atomic_cmpxchg(st3, ma, 16, ValType::i64())
        I64AtomicRmw32CmpxchgUOp =>
          typecheck_atomic_cmpxchg(st3, ma, 32, ValType::i64())
      }
    }

    // === Table ops ===
    TTableGet(t, idx) => {
      let st1 = match Typecheck::typecheck(idx, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_table_get(st1, t)
    }
    TTableSet(t, idx, val) => {
      let st1 = match Typecheck::typecheck(idx, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(val, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_table_set(st2, t)
    }
    TTableGrow(t, init, delta) => {
      let st1 = match Typecheck::typecheck(init, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(delta, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_table_grow(st2, t)
    }
    TTableFill(t, idx, val, len) => {
      let st1 = match Typecheck::typecheck(idx, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(val, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(len, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_table_fill(st3, t)
    }
    TTableCopy(t0, t1, dst, src, len) => {
      let st1 = match Typecheck::typecheck(dst, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(src, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(len, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_table_copy(st3, t0, t1)
    }
    TTableInit(e, t, dst, src, len) => {
      let st1 = match Typecheck::typecheck(dst, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(src, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(len, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_table_init(st3, e, t)
    }
    TElemDrop(e) => typecheck_elem_drop(st, e)

    // === Calls ===
    TCall(f, args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      typecheck_call(st_acc, f)
    }
    TCallIndirect(tidx, t, args, tab_expr) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      let st_final = match Typecheck::typecheck(tab_expr, st_acc) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_call_indirect(st_final, tidx, t)
    }
    TCallRef(tidx, args, funcref) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      let st_final = match Typecheck::typecheck(funcref, st_acc) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_call_ref(st_final, tidx)
    }
    TReturnCall(f, args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      typecheck_return_call(st_acc, f)
    }
    TReturnCallIndirect(tidx, t, args, tab_expr) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      let st_final = match Typecheck::typecheck(tab_expr, st_acc) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_return_call_indirect(st_final, tidx, t)
    }
    TReturnCallRef(tidx, args, funcref) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      let st_final = match Typecheck::typecheck(funcref, st_acc) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_return_call_ref(st_final, tidx)
    }

    // === Control Flow ===
    TBlock(bt, body) => {
      let (_params, results) = match st.env.expand_blocktype(bt) {
        Err(e) => return Err(e)
        Ok(x) => x
      }
      let env2 = st.env.with_label(results)
      let mut st_body = TcState::{
        env: env2,
        stack: [],
        reachable: st.reachable,
      }
      let TExpr(body) = body
      for instr in body {
        st_body = match Typecheck::typecheck(instr, st_body) {
          Err(e) => return Err(e)
          Ok(s) => s
        }
      }
      if st_body.reachable {
        let st_after_results = match st_body.pop_types(results) {
          Err(e) => return Err(e)
          Ok(s) => s
        }
        if st_after_results.stack.length() != 0 {
          return Err("type mismatch")
        }
      }
      let out = TcState::{
        env: st.env,
        stack: st.stack.copy(),
        reachable: st.reachable,
      }
      Ok(out.push_types(results))
    }
    TLoop(bt, body) => {
      let (params, results) = match st.env.expand_blocktype(bt) {
        Err(e) => return Err(e)
        Ok(x) => x
      }
      let env2 = st.env.with_label(params)
      let mut st_body = TcState::{
        env: env2,
        stack: [],
        reachable: st.reachable,
      }
      let TExpr(body) = body
      for instr in body {
        st_body = match Typecheck::typecheck(instr, st_body) {
          Err(e) => return Err(e)
          Ok(s) => s
        }
      }
      let st2 = if st_body.reachable {
        let st_after_results = match st_body.pop_types(results) {
          Err(e) => return Err(e)
          Ok(s) => s
        }
        if st_after_results.stack.length() != 0 {
          return Err("type mismatch")
        }
        st_after_results
      } else {
        st_body
      }
      let out = TcState::{
        env: st.env,
        stack: st.stack.copy(),
        reachable: st2.reachable,
      }
      Ok(out.push_types(results))
    }
    TIf(bt, cond, then_instrs, else_instrs_opt) => {
      let (_params, results) = match st.env.expand_blocktype(bt) {
        Err(e) => return Err(e)
        Ok(x) => x
      }
      let st0 = match Typecheck::typecheck(cond, st) {
        Err(e) => return Err(e)
        Ok(s) => s
      }
      let st0 = match st0.pop_expect(ValType::i32()) {
        Err(e) => return Err(e)
        Ok(s) => s
      }
      let st1 = st0
      let else_instrs = match else_instrs_opt {
        None => []
        Some(TExpr(xs)) => xs
      }
      let env_branch = st1.env.with_label(results)
      let st_then0 = TcState::{
        env: env_branch,
        stack: [],
        reachable: st1.reachable,
      }
      let mut st_then = st_then0
      let TExpr(then_instrs) = then_instrs
      for instr in then_instrs {
        st_then = match Typecheck::typecheck(instr, st_then) {
          Err(e) => return Err(e)
          Ok(s) => s
        }
      }
      let st_else0 = TcState::{
        env: env_branch,
        stack: [],
        reachable: st1.reachable,
      }
      let mut st_else = st_else0
      for instr in else_instrs {
        st_else = match Typecheck::typecheck(instr, st_else) {
          Err(e) => return Err(e)
          Ok(s) => s
        }
      }
      let norm_branch = fn(
        sb : TcState,
      ) -> Result[(Bool, Array[ValType]), String] {
        let sb2 = if sb.reachable {
          let st_after_results = match sb.pop_types(results) {
            Err(e) => return Err(e)
            Ok(s) => s
          }
          if st_after_results.stack.length() != 0 {
            return Err("type mismatch")
          }
          st_after_results
        } else {
          sb
        }
        Ok((sb2.reachable, sb2.stack.copy()))
      }
      let (then_reach, then_stack) = match norm_branch(st_then) {
        Err(e) => return Err(e)
        Ok(x) => x
      }
      let (else_reach, else_stack) = match norm_branch(st_else) {
        Err(e) => return Err(e)
        Ok(x) => x
      }
      let merged_stack = match (then_reach, else_reach) {
        (true, true) => {
          if then_stack != else_stack {
            return Err("if branch stack mismatch")
          }
          then_stack
        }
        (true, false) => then_stack
        (false, true) => else_stack
        (false, false) => []
      }
      let merged_reachable = then_reach || else_reach
      if merged_stack.length() != 0 {
        return Err("if branch stack mismatch")
      }
      let out = TcState::{
        env: st.env,
        stack: st1.stack.copy(),
        reachable: merged_reachable,
      }
      Ok(out.push_types(results))
    }
    TTryTable(bt, catches, body) => {
      let (_params, results) = match st.env.expand_blocktype(bt) {
        Err(e) => return Err(e)
        Ok(x) => x
      }
      let st1 = st
      let env2 = st.env.with_label(results)
      let st_body0 = TcState::{
        env: env2,
        stack: [],
        reachable: st1.reachable,
      }
      let mut st_body = st_body0
      let TExpr(body) = body
      for instr in body {
        st_body = match Typecheck::typecheck(instr, st_body) {
          Err(e) => return Err(e)
          Ok(s) => s
        }
      }
      let st_catch_ctx = TcState::{ ..st1, env: env2 }
      for c in catches {
        match typecheck_catch_clause(st_catch_ctx, c) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      }
      let st2 = if st_body.reachable {
        let st_after_results = match st_body.pop_types(results) {
          Err(e) => return Err(e)
          Ok(s) => s
        }
        if st_after_results.stack.length() != 0 {
          return Err("type mismatch")
        }
        st_after_results
      } else {
        st_body
      }
      let out = TcState::{
        env: st.env,
        stack: st1.stack.copy(),
        reachable: st2.reachable,
      }
      Ok(out.push_types(results))
    }
    TThrow(tag, args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      typecheck_throw(st_acc, tag)
    }

    // === Branches ===
    TBr(l, args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      typecheck_br(st_acc, l)
    }
    TBrIf(l, cond, args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      let st_cond = match Typecheck::typecheck(cond, st_acc) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_br_if(st_cond, l)
    }
    TBrTable(ls, ldef, index, args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      let st_idx = match Typecheck::typecheck(index, st_acc) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_br_table(st_idx, ls, ldef)
    }
    TBrOnNull(l, r, args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      let st_ref = match Typecheck::typecheck(r, st_acc) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_br_on_null(st_ref, l)
    }
    TBrOnNonNull(l, r, args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      let st_ref = match Typecheck::typecheck(r, st_acc) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_br_on_non_null(st_ref, l)
    }
    TBrOnCast(l, op, ht1, ht2, r, args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      let st_ref = match Typecheck::typecheck(r, st_acc) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_br_on_cast(st_ref, l, op, ht1, ht2)
    }
    TBrOnCastFail(l, op, ht1, ht2, r, args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      let st_ref = match Typecheck::typecheck(r, st_acc) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_br_on_cast_fail(st_ref, l, op, ht1, ht2)
    }
    TReturn(args) => {
      let mut st_acc = st
      for arg in args {
        st_acc = match Typecheck::typecheck(arg, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      typecheck_return(st_acc)
    }

    // === Select ===
    TSelect(ty_opt, cond, t, f) => {
      let st_f = match Typecheck::typecheck(f, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st_t = match Typecheck::typecheck(t, st_f) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st_cond = match Typecheck::typecheck(cond, st_t) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      match ty_opt {
        None => typecheck_select_untyped(st_cond)
        Some(ts) => typecheck_select_typed(st_cond, ts)
      }
    }

    // === Structs ===
    TStructNew(x, fields) => {
      let mut st_acc = st
      for f in fields {
        st_acc = match Typecheck::typecheck(f, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      typecheck_struct_new(st_acc, x)
    }
    TStructNewDefault(x) => typecheck_struct_new_default(st, x)
    TStructGet(x, i, s) => {
      let st1 = match Typecheck::typecheck(s, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_struct_get(st1, x, i)
    }
    TStructGetS(x, i, s) => {
      let st1 = match Typecheck::typecheck(s, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_struct_get_s(st1, x, i)
    }
    TStructGetU(x, i, s) => {
      let st1 = match Typecheck::typecheck(s, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_struct_get_u(st1, x, i)
    }
    TStructSet(x, i, s, val) => {
      let st1 = match Typecheck::typecheck(s, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(val, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_struct_set(st2, x, i)
    }

    // === Arrays ===
    TArrayNew(x, init, len) => {
      let st1 = match Typecheck::typecheck(init, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(len, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_new(st2, x)
    }
    TArrayNewDefault(x, len) => {
      let st1 = match Typecheck::typecheck(len, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_new_default(st1, x)
    }
    TArrayNewFixed(x, fields) => {
      let mut st_acc = st
      for f in fields {
        st_acc = match Typecheck::typecheck(f, st_acc) {
          Ok(st) => st
          Err(t) => return Err(t)
        }
      }
      typecheck_array_new_fixed(
        st_acc,
        x,
        fields.length().reinterpret_as_uint(),
      )
    }
    TArrayNewData(x, y, offset, len) => {
      let st1 = match Typecheck::typecheck(offset, st) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(len, st1) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      typecheck_array_new_data(st2, x, y)
    }
    TArrayNewElem(x, y, offset, len) => {
      let st1 = match Typecheck::typecheck(offset, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(len, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_new_elem(st2, x, y)
    }
    TArrayGet(x, arr, idx) => {
      let st1 = match Typecheck::typecheck(arr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(idx, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_get(st2, x)
    }
    TArrayGetS(x, arr, idx) => {
      let st1 = match Typecheck::typecheck(arr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(idx, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_get_s(st2, x)
    }
    TArrayGetU(x, arr, idx) => {
      let st1 = match Typecheck::typecheck(arr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(idx, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_get_u(st2, x)
    }
    TArraySet(x, arr, idx, val) => {
      let st1 = match Typecheck::typecheck(arr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(idx, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(val, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_set(st3, x)
    }
    TArrayFill(x, arr, offset, val, len) => {
      let st1 = match Typecheck::typecheck(arr, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(offset, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(val, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st4 = match Typecheck::typecheck(len, st3) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_fill(st4, x)
    }
    TArrayCopy(x, y, arr2, idx2, arr1, idx1, len) => {
      let st1 = match Typecheck::typecheck(arr2, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(idx2, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(arr1, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st4 = match Typecheck::typecheck(idx1, st3) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st5 = match Typecheck::typecheck(len, st4) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_copy(st5, x, y)
    }
    TArrayInitData(x, y, i0, i1, i2, i3) => {
      let st1 = match Typecheck::typecheck(i0, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(i1, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(i2, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st4 = match Typecheck::typecheck(i3, st3) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_init_data(st4, x, y)
    }
    TArrayInitElem(x, y, i0, i1, i2, i3) => {
      let st1 = match Typecheck::typecheck(i0, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(i1, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(i2, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st4 = match Typecheck::typecheck(i3, st3) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_array_init_elem(st4, x, y)
    }

    // === GC: Casts ===
    TRefGetDesc(child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_ref_get_desc(st1)
    }
    TRefTest(nullable, ht, child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_ref_test(st1, nullable, ht)
    }
    TRefCast(nullable, ht, child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_ref_cast(st1, nullable, ht)
    }
    TRefTestDesc(nullable, ht, child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_ref_test_desc(st1, nullable, ht)
    }
    TRefCastDescEq(nullable, ht, child) => {
      let st1 = match Typecheck::typecheck(child, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_ref_cast_desc_eq(st1, nullable, ht)
    }

    // === SIMD: Splat ===
    TI8x16Splat(x) => {
      let st1 = match Typecheck::typecheck(x, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_splat(st1, ValType::i32())
    }
    TI16x8Splat(x) => {
      let st1 = match Typecheck::typecheck(x, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_splat(st1, ValType::i32())
    }
    TI32x4Splat(x) => {
      let st1 = match Typecheck::typecheck(x, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_splat(st1, ValType::i32())
    }
    TI64x2Splat(x) => {
      let st1 = match Typecheck::typecheck(x, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_splat(st1, ValType::i64())
    }
    TF32x4Splat(x) => {
      let st1 = match Typecheck::typecheck(x, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_splat(st1, ValType::f32())
    }
    TF64x2Splat(x) => {
      let st1 = match Typecheck::typecheck(x, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_splat(st1, ValType::f64())
    }

    // === SIMD: Extract lane ===
    TExtractLane(op, _, vec) => {
      let st1 = match Typecheck::typecheck(vec, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      match op {
        I8x16ExtractLaneSOp => typecheck_lane_extract(st1, ValType::i32())
        I8x16ExtractLaneUOp => typecheck_lane_extract(st1, ValType::i32())
        I16x8ExtractLaneSOp => typecheck_lane_extract(st1, ValType::i32())
        I16x8ExtractLaneUOp => typecheck_lane_extract(st1, ValType::i32())
        I32x4ExtractLaneOp => typecheck_lane_extract(st1, ValType::i32())
        I64x2ExtractLaneOp => typecheck_lane_extract(st1, ValType::i64())
        F32x4ExtractLaneOp => typecheck_lane_extract(st1, ValType::f32())
        F64x2ExtractLaneOp => typecheck_lane_extract(st1, ValType::f64())
      }
    }

    // === SIMD: Replace lane ===
    TReplaceLane(op, _, vec, val) => {
      let st1 = match Typecheck::typecheck(vec, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(val, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      match op {
        I8x16ReplaceLaneOp => typecheck_lane_replace(st2, ValType::i32())
        I16x8ReplaceLaneOp => typecheck_lane_replace(st2, ValType::i32())
        I32x4ReplaceLaneOp => typecheck_lane_replace(st2, ValType::i32())
        I64x2ReplaceLaneOp => typecheck_lane_replace(st2, ValType::i64())
        F32x4ReplaceLaneOp => typecheck_lane_replace(st2, ValType::f32())
        F64x2ReplaceLaneOp => typecheck_lane_replace(st2, ValType::f64())
      }
    }

    // === SIMD: Shuffle ===
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, v1, v2) => {
      let st1 = match Typecheck::typecheck(v1, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(v2, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_v128_binary(st2)
    }
    TI8x16Swizzle(v1, v2) => {
      let st1 = match Typecheck::typecheck(v1, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(v2, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_v128_binary(st2)
    }
    TI8x16RelaxedSwizzle(v1, v2) => {
      let st1 = match Typecheck::typecheck(v1, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(v2, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_v128_binary(st2)
    }

    // === SIMD: Shift ===
    TV128Shift(_, vec, shift) => {
      let st1 = match Typecheck::typecheck(vec, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(shift, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_v128_shift(st2)
    }

    // === SIMD: Ternary ===
    TV128Ternary(_, c, v1, v2) => {
      let st1 = match Typecheck::typecheck(c, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(v1, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st3 = match Typecheck::typecheck(v2, st2) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      typecheck_v128_ternary(st3)
    }

    // === SIMD: Lane load/store ===
    TV128LoadLane(op, ma, _, vec, addr) => {
      let st1 = match Typecheck::typecheck(vec, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(addr, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      match op {
        V128Load8LaneOp => typecheck_v128_load_lane(st2, ma, 8)
        V128Load16LaneOp => typecheck_v128_load_lane(st2, ma, 16)
        V128Load32LaneOp => typecheck_v128_load_lane(st2, ma, 32)
        V128Load64LaneOp => typecheck_v128_load_lane(st2, ma, 64)
      }
    }
    TV128StoreLane(op, ma, _, vec, addr) => {
      let st1 = match Typecheck::typecheck(vec, st) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      let st2 = match Typecheck::typecheck(addr, st1) {
        Ok(st) => st
        Err(t) => return Err(t)
      }
      match op {
        V128Store8LaneOp => typecheck_v128_store_lane(st2, ma, 8)
        V128Store16LaneOp => typecheck_v128_store_lane(st2, ma, 16)
        V128Store32LaneOp => typecheck_v128_store_lane(st2, ma, 32)
        V128Store64LaneOp => typecheck_v128_store_lane(st2, ma, 64)
      }
    }
  }
}

///|
pub impl Typecheck for TExpr with typecheck(self, st0) {
  let TExpr(instrs) = self
  let mut st = st0
  for instr in instrs {
    match Typecheck::typecheck(instr, st) {
      Ok(s) => st = s
      Err(e) => return Err(e)
    }
  }
  Ok(st)
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
fn anyref_type() -> ValType {
  ValType::ref_type(RefType::abs(AbsHeapType::any()))
}

///|
fn eqref_type() -> ValType {
  ValType::ref_type(RefType::abs(AbsHeapType::eq()))
}

///|
fn i31ref_type() -> ValType {
  ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::i31())))
}

///|
fn nullable_funcref() -> ValType {
  ValType::ref_type(RefType::new(true, HeapType::abs(AbsHeapType::func())))
}

///|
fn nullable_externref() -> ValType {
  ValType::ref_type(RefType::new(true, HeapType::abs(AbsHeapType::extern_())))
}

///|
fn non_nullable_funcref() -> ValType {
  ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func())))
}

///|
fn non_nullable_externref() -> ValType {
  ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::extern_())))
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
  let t = Instruction::unreachable_()
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck Nop" {
  let state = make_state(empty_env(), [ValType::i32()])
  let t = Instruction::nop()
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck Block empty" {
  let env = empty_env()
  let state = make_state(env, [])
  let block = Instruction::block(BlockType::void_(), Expr::new([]))
  let new_state = assert_ok(Typecheck::typecheck(block, state))
  assert_stack(new_state, [])
}

///|
test "Typecheck Block with result" {
  let env = empty_env()
  let state = make_state(env, [])
  let block = Instruction::block(
    BlockType::val_type(ValType::i32()),
    Expr::new([Instruction::i32_const(I32(42))]),
  )
  let new_state = assert_ok(Typecheck::typecheck(block, state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck Block preserves outer stack" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64()])
  let block = Instruction::block(
    BlockType::val_type(ValType::i32()),
    Expr::new([Instruction::i32_const(I32(1))]),
  )
  let new_state = assert_ok(Typecheck::typecheck(block, state))
  assert_stack(new_state, [ValType::i64(), ValType::i32()])
}

///|
test "Typecheck Loop empty" {
  let env = empty_env()
  let state = make_state(env, [])
  let loop_instr = Instruction::loop_(BlockType::void_(), Expr::new([]))
  let new_state = assert_ok(Typecheck::typecheck(loop_instr, state))
  assert_stack(new_state, [])
}

///|
test "Typecheck If without else" {
  let env = empty_env()
  let state = make_state(env, [ValType::i32()])
  let if_instr = Instruction::if_(
    BlockType::void_(),
    [Instruction::nop()],
    None,
  )
  let new_state = assert_ok(Typecheck::typecheck(if_instr, state))
  assert_stack(new_state, [])
}

///|
test "Typecheck If with else" {
  let env = empty_env()
  let state = make_state(env, [ValType::i32()])
  let if_instr = Instruction::if_(
    BlockType::val_type(ValType::i32()),
    [Instruction::i32_const(I32(1))],
    Some([Instruction::i32_const(I32(2))]),
  )
  let new_state = assert_ok(Typecheck::typecheck(if_instr, state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck If fails without condition" {
  let env = empty_env()
  let state = make_state(env, [])
  let if_instr = Instruction::if_(
    BlockType::void_(),
    [Instruction::nop()],
    None,
  )
  assert_err(Typecheck::typecheck(if_instr, state))
}

///|
test "Typecheck Br" {
  let env = empty_env().with_labels([[]])
  let state = make_state(env, [])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::br(LabelIdx::new(0)), state),
  )
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck Br with values" {
  let env = empty_env().with_labels([[ValType::i32()]])
  let state = make_state(env, [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::br(LabelIdx::new(0)), state),
  )
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck Br invalid label" {
  let env = empty_env().with_labels([])
  let state = make_state(env, [])
  let t = Instruction::br(LabelIdx::new(0))
  assert_err(Typecheck::typecheck(t, state))
}

///|
test "Typecheck BrIf" {
  let env = empty_env().with_labels([[]])
  let state = make_state(env, [ValType::i32()])
  let t = Instruction::br_if(LabelIdx::new(0))
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [])
}

///|
test "Typecheck BrIf with values" {
  let env = empty_env().with_labels([[ValType::i32()]])
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let t = Instruction::br_if(LabelIdx::new(0))
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck BrTable" {
  let env = empty_env().with_labels([[], []])
  let state = make_state(env, [ValType::i32()])
  let br_table = Instruction::br_table([LabelIdx::new(0)], LabelIdx::new(1))
  let new_state = assert_ok(Typecheck::typecheck(br_table, state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck BrTable with values" {
  // Labels expect an i32 value to be passed
  let env = empty_env().with_labels([[ValType::i32()], [ValType::i32()]])
  // Stack: [i32 (branch value), i32 (selector)]
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let br_table = Instruction::br_table([LabelIdx::new(0)], LabelIdx::new(1))
  let new_state = assert_ok(Typecheck::typecheck(br_table, state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck BrTable with multiple values" {
  // Labels expect i32, i64 to be passed
  let env = empty_env().with_labels([
    [ValType::i32(), ValType::i64()],
    [ValType::i32(), ValType::i64()],
  ])
  // Stack: [i32, i64 (branch values), i32 (selector)]
  let state = make_state(env, [ValType::i32(), ValType::i64(), ValType::i32()])
  let br_table = Instruction::br_table([LabelIdx::new(0)], LabelIdx::new(1))
  let new_state = assert_ok(Typecheck::typecheck(br_table, state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck BrTable multiple targets" {
  let env = empty_env().with_labels([[], [], [], []])
  let state = make_state(env, [ValType::i32()])
  // Jump table with 3 entries plus default
  let br_table = Instruction::br_table(
    [LabelIdx::new(0), LabelIdx::new(1), LabelIdx::new(2)],
    LabelIdx::new(3),
  )
  let new_state = assert_ok(Typecheck::typecheck(br_table, state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck BrTable invalid default label" {
  let env = empty_env().with_labels([[]])
  let state = make_state(env, [ValType::i32()])
  let br_table = Instruction::br_table([LabelIdx::new(0)], LabelIdx::new(5)) // invalid default
  assert_err(Typecheck::typecheck(br_table, state))
}

///|
test "Typecheck BrTable invalid table label" {
  let env = empty_env().with_labels([[]])
  let state = make_state(env, [ValType::i32()])
  let br_table = Instruction::br_table(
    [LabelIdx::new(0), LabelIdx::new(99)],
    LabelIdx::new(0),
  ) // invalid in table
  assert_err(Typecheck::typecheck(br_table, state))
}

///|
test "Typecheck BrTable mismatched label types" {
  // Labels have different arities - this is invalid
  let env = empty_env().with_labels([[ValType::i32()], []])
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let br_table = Instruction::br_table([LabelIdx::new(0)], LabelIdx::new(1))
  assert_err(Typecheck::typecheck(br_table, state))
}

///|
test "Typecheck BrTable mismatched label value types" {
  // Labels have same arity but different types
  let env = empty_env().with_labels([[ValType::i32()], [ValType::i64()]])
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let br_table = Instruction::br_table([LabelIdx::new(0)], LabelIdx::new(1))
  assert_err(Typecheck::typecheck(br_table, state))
}

///|
test "Typecheck BrTable missing selector" {
  let env = empty_env().with_labels([[], []])
  let state = make_state(env, []) // empty stack - no selector
  let br_table = Instruction::br_table([LabelIdx::new(0)], LabelIdx::new(1))
  assert_err(Typecheck::typecheck(br_table, state))
}

///|
test "Typecheck BrTable missing branch values" {
  // Labels expect an i32 but stack only has the selector
  let env = empty_env().with_labels([[ValType::i32()], [ValType::i32()]])
  let state = make_state(env, [ValType::i32()]) // only selector, no branch value
  let br_table = Instruction::br_table([LabelIdx::new(0)], LabelIdx::new(1))
  assert_err(Typecheck::typecheck(br_table, state))
}

///|
test "Typecheck BrTable wrong selector type" {
  let env = empty_env().with_labels([[], []])
  let state = make_state(env, [ValType::i64()]) // wrong type for selector
  let br_table = Instruction::br_table([LabelIdx::new(0)], LabelIdx::new(1))
  assert_err(Typecheck::typecheck(br_table, state))
}

///|
test "Typecheck Return" {
  let env = empty_env().with_return_type(Some([]))
  let state = make_state(env, [])
  let t = Instruction::return_()
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_eq(new_state.reachable, false)
}

///|
test "Typecheck Return with value" {
  let env = empty_env().with_return_type(Some([ValType::i32()]))
  let state = make_state(env, [ValType::i32()])
  let t = Instruction::return_()
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_eq(new_state.reachable, false)
}

// =============================================================================
// PARAMETRIC INSTRUCTIONS
// =============================================================================

///|
test "Typecheck Drop i32" {
  let state = make_state(empty_env(), [ValType::i32()])
  let t = Instruction::drop()
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [])
}

///|
test "Typecheck Drop i64" {
  let state = make_state(empty_env(), [ValType::i64()])
  let t = Instruction::drop()
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [])
}

///|
test "Typecheck Drop fails empty stack" {
  let state = make_state(empty_env(), [])
  let t = Instruction::drop()
  assert_err(Typecheck::typecheck(t, state))
}

///|
test "Typecheck Select without annotation" {
  let state = make_state(empty_env(), [
    ValType::i32(),
    ValType::i32(),
    ValType::i32(),
  ])
  let t = Instruction::select(types=None)
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck Select with annotation" {
  let state = make_state(empty_env(), [
    ValType::i32(),
    ValType::i32(),
    ValType::i32(),
  ])
  let t = Instruction::select(types=Some([ValType::i32()]))
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck Select type mismatch fails" {
  let state = make_state(empty_env(), [
    ValType::i32(),
    ValType::i64(),
    ValType::i32(),
  ])
  let t = Instruction::select(types=None)
  assert_err(Typecheck::typecheck(t, state))
}

// =============================================================================
// VARIABLE INSTRUCTIONS
// =============================================================================

///|
test "Typecheck LocalGet" {
  let env : Env = { ..empty_env(), locals: [ValType::i32()] }
  let state = make_state(env, [])
  let t = Instruction::local_get(LocalIdx::new(0))
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck LocalGet invalid index" {
  let env : Env = { ..empty_env(), locals: [] }
  let state = make_state(env, [])
  let t = Instruction::local_get(LocalIdx::new(0))
  assert_err(Typecheck::typecheck(t, state))
}

///|
test "Typecheck LocalSet" {
  let env : Env = { ..empty_env(), locals: [ValType::i32()] }
  let state = make_state(env, [ValType::i32()])
  let t = Instruction::local_set(LocalIdx::new(0))
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [])
}

///|
test "Typecheck LocalSet type mismatch" {
  let env = Env::{ ..empty_env(), locals: [ValType::i32()] }
  let state = make_state(env, [ValType::i64()])
  let t = Instruction::local_set(LocalIdx::new(0))
  assert_err(Typecheck::typecheck(t, state))
}

///|
test "Typecheck LocalTee" {
  let env : Env = { ..empty_env(), locals: [ValType::i32()] }
  let state = make_state(env, [ValType::i32()])
  let t = Instruction::local_tee(LocalIdx::new(0))
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck GlobalGet" {
  let env : Env = {
    ..empty_env(),
    globals: [GlobalType::new(ValType::i32(), false)],
  }
  let state = make_state(env, [])
  let t = Instruction::global_get(GlobalIdx::new(0))
  let new_state = assert_ok(Typecheck::typecheck(t, state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck GlobalSet mutable" {
  let env : Env = {
    ..empty_env(),
    globals: [GlobalType::new(ValType::i32(), true)],
  }
  let state = make_state(env, [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::global_set(GlobalIdx::new(0)), state),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck GlobalSet immutable fails" {
  let env : Env = {
    ..empty_env(),
    globals: [GlobalType::new(ValType::i32(), false)],
  }
  let state = make_state(env, [ValType::i32()])
  assert_err(
    Typecheck::typecheck(Instruction::global_set(GlobalIdx::new(0)), state),
  )
}

// =============================================================================
// TABLE INSTRUCTIONS
// =============================================================================

///|
test "Typecheck TableGet" {
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type] }
  let state = make_state(env, [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::table_get(TableIdx::new(0)), state),
  )
  assert_stack(new_state, [nullable_funcref()])
}

///|
test "Typecheck TableSet" {
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type] }
  let state = make_state(env, [ValType::i32(), nullable_funcref()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::table_set(TableIdx::new(0)), state),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck TableSize" {
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type] }
  let state = make_state(env, [])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::table_size(TableIdx::new(0)), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck TableGrow" {
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type] }
  let state = make_state(env, [nullable_funcref(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::table_grow(TableIdx::new(0)), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck TableFill" {
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type] }
  let state = make_state(env, [
    ValType::i32(),
    nullable_funcref(),
    ValType::i32(),
  ])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::table_fill(TableIdx::new(0)), state),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck TableCopy" {
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(0, None),
  )
  let env : Env = { ..empty_env(), tables: [table_type, table_type] }
  let state = make_state(env, [ValType::i32(), ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::table_copy(TableIdx::new(0), TableIdx::new(1)),
      state,
    ),
  )
  assert_stack(new_state, [])
}

// =============================================================================
// MEMORY INSTRUCTIONS
// =============================================================================

///|
test "Typecheck I32Load" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_load(mem_arg), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64Load" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_load(mem_arg), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck F32Load" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_load(mem_arg), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F64Load" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f64_load(mem_arg), state),
  )
  assert_stack(new_state, [ValType::f64()])
}

///|
test "Typecheck I32Load8S" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_load8s(mem_arg), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Load8U" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_load8u(mem_arg), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Load16S" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_load16s(mem_arg), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Load16U" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_load16u(mem_arg), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64Load8S" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_load8s(mem_arg), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I64Load32S" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_load32s(mem_arg), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I32Store" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_store(mem_arg), state),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck I64Store" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::i64()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_store(mem_arg), state),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck F32Store" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::f32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_store(mem_arg), state),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck F64Store" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::f64()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f64_store(mem_arg), state),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck I32Store8" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_store8(mem_arg), state),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck I64Store32" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::i64()])
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_store32(mem_arg), state),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck MemorySize" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::memory_size(MemIdx::new(0)), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck MemoryGrow" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::memory_grow(MemIdx::new(0)), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck MemoryCopy" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::memory_copy(MemIdx::new(0), MemIdx::new(0)),
      state,
    ),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck MemoryFill" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::memory_fill(MemIdx::new(0)), state),
  )
  assert_stack(new_state, [])
}

// =============================================================================
// NUMERIC CONSTANTS
// =============================================================================

///|
test "Typecheck I32Const" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_const(I32(42)), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64Const" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_const(I64(42L)), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck F32Const" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_const(F32(3.14)), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F64Const" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f64_const(F64(3.14)), state),
  )
  assert_stack(new_state, [ValType::f64()])
}

// =============================================================================
// I32 COMPARISON OPERATIONS
// =============================================================================

///|
test "Typecheck I32Eqz" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_eqz(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Eq" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_eq(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Ne" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_ne(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32LtS" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_lt_s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32LtU" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_lt_u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32GtS" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_gt_s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32GtU" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_gt_u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32LeS" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_le_s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32LeU" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_le_u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32GeS" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_ge_s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32GeU" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_ge_u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

// =============================================================================
// I64 COMPARISON OPERATIONS
// =============================================================================

///|
test "Typecheck I64Eqz" {
  let state = make_state(empty_env(), [ValType::i64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i64_eqz(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64Eq" {
  let state = make_state(empty_env(), [ValType::i64(), ValType::i64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i64_eq(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64Ne" {
  let state = make_state(empty_env(), [ValType::i64(), ValType::i64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i64_ne(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64LtS" {
  let state = make_state(empty_env(), [ValType::i64(), ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_lt_s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64GtU" {
  let state = make_state(empty_env(), [ValType::i64(), ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_gt_u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

// =============================================================================
// F32 COMPARISON OPERATIONS
// =============================================================================

///|
test "Typecheck F32Eq" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_eq(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck F32Ne" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_ne(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck F32Lt" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_lt(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck F32Gt" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_gt(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck F32Le" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_le(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck F32Ge" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_ge(), state))
  assert_stack(new_state, [ValType::i32()])
}

// =============================================================================
// F64 COMPARISON OPERATIONS
// =============================================================================

///|
test "Typecheck F64Eq" {
  let state = make_state(empty_env(), [ValType::f64(), ValType::f64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f64_eq(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck F64Lt" {
  let state = make_state(empty_env(), [ValType::f64(), ValType::f64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f64_lt(), state))
  assert_stack(new_state, [ValType::i32()])
}

// =============================================================================
// I32 ARITHMETIC OPERATIONS
// =============================================================================

///|
test "Typecheck I32Clz" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_clz(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Ctz" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_ctz(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Popcnt" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_popcnt(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Add" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_add(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Sub" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_sub(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Mul" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_mul(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32DivS" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_div_s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32DivU" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_div_u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32RemS" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_rem_s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32RemU" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_rem_u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32And" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_and(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Or" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_or(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Xor" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_xor(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Shl" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i32_shl(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32ShrS" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_shr_s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32ShrU" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_shr_u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Rotl" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_rotl(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Rotr" {
  let state = make_state(empty_env(), [ValType::i32(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_rotr(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

// =============================================================================
// I64 ARITHMETIC OPERATIONS
// =============================================================================

///|
test "Typecheck I64Clz" {
  let state = make_state(empty_env(), [ValType::i64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i64_clz(), state))
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I64Add" {
  let state = make_state(empty_env(), [ValType::i64(), ValType::i64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i64_add(), state))
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I64Sub" {
  let state = make_state(empty_env(), [ValType::i64(), ValType::i64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i64_sub(), state))
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I64Mul" {
  let state = make_state(empty_env(), [ValType::i64(), ValType::i64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::i64_mul(), state))
  assert_stack(new_state, [ValType::i64()])
}

// =============================================================================
// F32 ARITHMETIC OPERATIONS
// =============================================================================

///|
test "Typecheck F32Abs" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_abs(), state))
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Neg" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_neg(), state))
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Ceil" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_ceil(), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Floor" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_floor(), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Sqrt" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_sqrt(), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Add" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_add(), state))
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Sub" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_sub(), state))
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Mul" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_mul(), state))
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Div" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_div(), state))
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Min" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_min(), state))
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Max" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f32_max(), state))
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32Copysign" {
  let state = make_state(empty_env(), [ValType::f32(), ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_copysign(), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

// =============================================================================
// F64 ARITHMETIC OPERATIONS
// =============================================================================

///|
test "Typecheck F64Abs" {
  let state = make_state(empty_env(), [ValType::f64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f64_abs(), state))
  assert_stack(new_state, [ValType::f64()])
}

///|
test "Typecheck F64Neg" {
  let state = make_state(empty_env(), [ValType::f64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f64_neg(), state))
  assert_stack(new_state, [ValType::f64()])
}

///|
test "Typecheck F64Add" {
  let state = make_state(empty_env(), [ValType::f64(), ValType::f64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f64_add(), state))
  assert_stack(new_state, [ValType::f64()])
}

///|
test "Typecheck F64Sub" {
  let state = make_state(empty_env(), [ValType::f64(), ValType::f64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f64_sub(), state))
  assert_stack(new_state, [ValType::f64()])
}

///|
test "Typecheck F64Mul" {
  let state = make_state(empty_env(), [ValType::f64(), ValType::f64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f64_mul(), state))
  assert_stack(new_state, [ValType::f64()])
}

///|
test "Typecheck F64Div" {
  let state = make_state(empty_env(), [ValType::f64(), ValType::f64()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::f64_div(), state))
  assert_stack(new_state, [ValType::f64()])
}

// =============================================================================
// CONVERSION OPERATIONS
// =============================================================================

///|
test "Typecheck I32WrapI64" {
  let state = make_state(empty_env(), [ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_wrap_i64(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32TruncF32S" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_trunc_f32s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32TruncF32U" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_trunc_f32u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32TruncF64S" {
  let state = make_state(empty_env(), [ValType::f64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_trunc_f64s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32TruncF64U" {
  let state = make_state(empty_env(), [ValType::f64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_trunc_f64u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64ExtendI32S" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_extend_i32s(), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I64ExtendI32U" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_extend_i32u(), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I64TruncF32S" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_trunc_f32s(), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I64TruncF64S" {
  let state = make_state(empty_env(), [ValType::f64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_trunc_f64s(), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck F32ConvertI32S" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_convert_i32s(), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32ConvertI32U" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_convert_i32u(), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32ConvertI64S" {
  let state = make_state(empty_env(), [ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_convert_i64s(), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F32DemoteF64" {
  let state = make_state(empty_env(), [ValType::f64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_demote_f64(), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F64ConvertI32S" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f64_convert_i32s(), state),
  )
  assert_stack(new_state, [ValType::f64()])
}

///|
test "Typecheck F64ConvertI64S" {
  let state = make_state(empty_env(), [ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f64_convert_i64s(), state),
  )
  assert_stack(new_state, [ValType::f64()])
}

///|
test "Typecheck F64PromoteF32" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f64_promote_f32(), state),
  )
  assert_stack(new_state, [ValType::f64()])
}

///|
test "Typecheck I32ReinterpretF32" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_reinterpret_f32(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64ReinterpretF64" {
  let state = make_state(empty_env(), [ValType::f64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_reinterpret_f64(), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck F32ReinterpretI32" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32_reinterpret_i32(), state),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F64ReinterpretI64" {
  let state = make_state(empty_env(), [ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f64_reinterpret_i64(), state),
  )
  assert_stack(new_state, [ValType::f64()])
}

// =============================================================================
// SIGN EXTENSION OPERATIONS
// =============================================================================

///|
test "Typecheck I32Extend8S" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_extend8s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32Extend16S" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_extend16s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64Extend8S" {
  let state = make_state(empty_env(), [ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_extend8s(), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I64Extend16S" {
  let state = make_state(empty_env(), [ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_extend16s(), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I64Extend32S" {
  let state = make_state(empty_env(), [ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_extend32s(), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

// =============================================================================
// SATURATING TRUNCATION
// =============================================================================

///|
test "Typecheck I32TruncSatF32S" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_trunc_sat_f32s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32TruncSatF32U" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_trunc_sat_f32u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32TruncSatF64S" {
  let state = make_state(empty_env(), [ValType::f64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32_trunc_sat_f64s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64TruncSatF32S" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_trunc_sat_f32s(), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck I64TruncSatF64S" {
  let state = make_state(empty_env(), [ValType::f64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64_trunc_sat_f64s(), state),
  )
  assert_stack(new_state, [ValType::i64()])
}

// =============================================================================
// REFERENCE INSTRUCTIONS
// =============================================================================

///|
test "Typecheck RefNull func" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
      state,
    ),
  )
  assert_stack(new_state, [nullable_funcref()])
}

///|
test "Typecheck RefNull extern" {
  let state = make_state(empty_env(), [])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::ref_null(HeapType::abs(AbsHeapType::extern_())),
      state,
    ),
  )
  assert_stack(new_state, [nullable_externref()])
}

///|
test "Typecheck RefIsNull" {
  let state = make_state(empty_env(), [nullable_funcref()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::ref_is_null(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck RefEq" {
  let eq_ref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::eq())),
  )
  let state = make_state(empty_env(), [eq_ref, eq_ref])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::ref_eq(), state))
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck RefAsNonNull" {
  let state = make_state(empty_env(), [nullable_funcref()])
  let result = Typecheck::typecheck(Instruction::ref_as_non_null(), state)
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
  let result = Typecheck::typecheck(
    Instruction::br_on_non_null(LabelIdx::new(0)),
    state,
  )
  let new_state = assert_ok(result)
  assert_stack(new_state, [])
}

///|
test "Typecheck BrOnNonNull with prefix types" {
  let env = empty_env().with_labels([[ValType::i32(), non_nullable_funcref()]])
  let state = make_state(env, [ValType::i32(), nullable_funcref()])
  let result = Typecheck::typecheck(
    Instruction::br_on_non_null(LabelIdx::new(0)),
    state,
  )
  let new_state = assert_ok(result)
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck BrOnNonNull with externref" {
  let env = empty_env().with_labels([[non_nullable_externref()]])
  let state = make_state(env, [nullable_externref()])
  let result = Typecheck::typecheck(
    Instruction::br_on_non_null(LabelIdx::new(0)),
    state,
  )
  let new_state = assert_ok(result)
  assert_stack(new_state, [])
}

///|
test "Typecheck BrOnNonNull fails with wrong label type" {
  let env = empty_env().with_labels([[ValType::i32()]])
  let state = make_state(env, [nullable_funcref()])
  let result = Typecheck::typecheck(
    Instruction::br_on_non_null(LabelIdx::new(0)),
    state,
  )
  assert_true(result is Err(_))
}

// BrOnNull tests

///|
test "Typecheck BrOnNull basic" {
  let env = empty_env().with_labels([[]]) // label takes no values
  let state = make_state(env, [nullable_funcref()])
  let result = Typecheck::typecheck(
    Instruction::br_on_null(LabelIdx::new(0)),
    state,
  )
  let new_state = assert_ok(result)
  // Fallthrough pushes non-nullable ref
  assert_stack(new_state, [non_nullable_funcref()])
}

///|
test "Typecheck BrOnNull with prefix types" {
  let env = empty_env().with_labels([[ValType::i32()]])
  let state = make_state(env, [ValType::i32(), nullable_funcref()])
  let result = Typecheck::typecheck(
    Instruction::br_on_null(LabelIdx::new(0)),
    state,
  )
  let new_state = assert_ok(result)
  assert_stack(new_state, [ValType::i32(), non_nullable_funcref()])
}

///|
test "Typecheck BrOnNull with externref" {
  let env = empty_env().with_labels([[]])
  let state = make_state(env, [nullable_externref()])
  let result = Typecheck::typecheck(
    Instruction::br_on_null(LabelIdx::new(0)),
    state,
  )
  let new_state = assert_ok(result)
  assert_stack(new_state, [non_nullable_externref()])
}

///|
test "Typecheck RefI31" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(Typecheck::typecheck(Instruction::ref_i31(), state))
  assert_eq(new_state.stack.length(), 1)
}

///|
test "Typecheck I31GetS" {
  let state = make_state(empty_env(), [i31ref_type()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i31_get_s(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I31GetU" {
  let state = make_state(empty_env(), [i31ref_type()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i31_get_u(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck AnyConvertExtern" {
  let state = make_state(empty_env(), [nullable_externref()])
  let result = Typecheck::typecheck(Instruction::any_convert_extern(), state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack.length(), 1)
    Err(_) => ()
  }
}

///|
test "Typecheck ExternConvertAny" {
  let any_ref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::any())),
  )
  let state = make_state(empty_env(), [any_ref])
  let result = Typecheck::typecheck(Instruction::extern_convert_any(), state)
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
  let result = Typecheck::typecheck(Instruction::i32_const(I32(42)), state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [ValType::i32()])
    Err(e) => fail("I32Const should typecheck: \{e}")
  }
}

///|
test "Typecheck I32Add consumes two i32s and produces one" {
  let env = empty_env()
  let state : TcState = {
    env,
    stack: [ValType::i32(), ValType::i32()],
    reachable: true,
  }
  let result = Typecheck::typecheck(Instruction::i32_add(), state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [ValType::i32()])
    Err(e) => fail("I32Add should typecheck: \{e}")
  }
}

///|
test "Typecheck I32Add fails with insufficient stack" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let result = Typecheck::typecheck(Instruction::i32_add(), state)
  match result {
    Ok(_) => fail("I32Add should fail with empty stack")
    Err(_) => ()
  }
}

///|
test "Typecheck Drop removes top of stack" {
  let env = empty_env()
  let state : TcState = { env, stack: [ValType::i32()], reachable: true }
  let result = Typecheck::typecheck(Instruction::drop(), state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [])
    Err(e) => fail("Drop should typecheck: \{e}")
  }
}

///|
test "Typecheck Unreachable makes state unreachable" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let result = Typecheck::typecheck(Instruction::unreachable_(), state)
  match result {
    Ok(new_state) => assert_eq(new_state.reachable, false)
    Err(e) => fail("Unreachable should typecheck: \{e}")
  }
}

///|
test "Typecheck empty Expr" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let expr = Expr::new([])
  let result = Typecheck::typecheck(expr, state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [])
    Err(e) => fail("Empty Expr should typecheck: \{e}")
  }
}

///|
test "Typecheck Expr sequence" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let expr = Expr::new([
    Instruction::i32_const(I32(1)),
    Instruction::i32_const(I32(2)),
    Instruction::i32_add(),
  ])
  let result = Typecheck::typecheck(expr, state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [ValType::i32()])
    Err(e) => fail("Expr sequence should typecheck: \{e}")
  }
}

///|
test "Typecheck I64Const pushes i64" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: true }
  let result = Typecheck::typecheck(Instruction::i64_const(I64(100L)), state)
  match result {
    Ok(new_state) => assert_eq(new_state.stack, [ValType::i64()])
    Err(e) => fail("I64Const should typecheck: \{e}")
  }
}

///|
test "Typecheck type mismatch fails" {
  let env = empty_env()
  let state : TcState = {
    env,
    stack: [ValType::i64(), ValType::i32()],
    reachable: true,
  }
  let result = Typecheck::typecheck(Instruction::i32_add(), state)
  match result {
    Ok(_) => fail("I32Add should fail with mismatched types")
    Err(_) => ()
  }
}

///|
test "Typecheck V128Const" {
  let state = make_state(empty_env(), [])
  let instr = Instruction::v128_const(
    b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
    b'\x09', b'\x0a', b'\x0b', b'\x0c', b'\x0d', b'\x0e', b'\x0f',
  )
  let new_state = assert_ok(Typecheck::typecheck(instr, state))
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck V128Load" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32()])
  let arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::v128_load(arg), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck V128Store" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::v128()])
  let arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::v128_store(arg), state),
  )
  assert_stack(new_state, [])
}

///|
test "Typecheck I8x16Splat" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i8x16_splat(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I16x8Splat" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i16x8_splat(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I32x4Splat" {
  let state = make_state(empty_env(), [ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32x4_splat(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I64x2Splat" {
  let state = make_state(empty_env(), [ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i64x2_splat(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck F32x4Splat" {
  let state = make_state(empty_env(), [ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32x4_splat(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck F64x2Splat" {
  let state = make_state(empty_env(), [ValType::f64()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f64x2_splat(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I8x16ExtractLaneS" {
  let state = make_state(empty_env(), [ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::i8x16_extract_lane_s(LaneIdx::new(0)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I16x8ExtractLaneU" {
  let state = make_state(empty_env(), [ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::i16x8_extract_lane_u(LaneIdx::new(3)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I32x4ExtractLane" {
  let state = make_state(empty_env(), [ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::i32x4_extract_lane(LaneIdx::new(1)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck I64x2ExtractLane" {
  let state = make_state(empty_env(), [ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::i64x2_extract_lane(LaneIdx::new(0)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::i64()])
}

///|
test "Typecheck F32x4ExtractLane" {
  let state = make_state(empty_env(), [ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::f32x4_extract_lane(LaneIdx::new(2)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::f32()])
}

///|
test "Typecheck F64x2ExtractLane" {
  let state = make_state(empty_env(), [ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::f64x2_extract_lane(LaneIdx::new(1)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::f64()])
}

///|
test "Typecheck I8x16ReplaceLane" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::i8x16_replace_lane(LaneIdx::new(0)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I16x8ReplaceLane" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::i16x8_replace_lane(LaneIdx::new(2)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I32x4ReplaceLane" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::i32()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::i32x4_replace_lane(LaneIdx::new(1)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I64x2ReplaceLane" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::i64()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::i64x2_replace_lane(LaneIdx::new(0)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck F32x4ReplaceLane" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::f32()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::f32x4_replace_lane(LaneIdx::new(3)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck F64x2ReplaceLane" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::f64()])
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::f64x2_replace_lane(LaneIdx::new(1)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck V128Not" {
  let state = make_state(empty_env(), [ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::v128_not(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I8x16Abs" {
  let state = make_state(empty_env(), [ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i8x16_abs(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I16x8Neg" {
  let state = make_state(empty_env(), [ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i16x8_neg(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I32x4AllTrue" {
  let state = make_state(empty_env(), [ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32x4_all_true(), state),
  )
  assert_stack(new_state, [ValType::i32()])
}

///|
test "Typecheck V128And" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::v128_and(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I8x16Add" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i8x16_add(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I16x8Mul" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i16x8_mul(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I32x4Sub" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32x4_sub(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck F32x4Div" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32x4_div(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I8x16Eq" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i8x16_eq(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I16x8LtS" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i16x8_lt_s(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck I32x4GtU" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::i32x4_gt_u(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck F32x4Le" {
  let state = make_state(empty_env(), [ValType::v128(), ValType::v128()])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::f32x4_le(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck V128Bitselect" {
  let state = make_state(empty_env(), [
    ValType::v128(),
    ValType::v128(),
    ValType::v128(),
  ])
  let new_state = assert_ok(
    Typecheck::typecheck(Instruction::v128_bitselect(), state),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck V128Load8Lane" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::v128()])
  let arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::v128_load8_lane(arg, LaneIdx::new(0)),
      state,
    ),
  )
  assert_stack(new_state, [ValType::v128()])
}

///|
test "Typecheck V128Store16Lane" {
  let env : Env = { ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
  let state = make_state(env, [ValType::i32(), ValType::v128()])
  let arg = MemArg::new(U32(0), None, U64(0))
  let new_state = assert_ok(
    Typecheck::typecheck(
      Instruction::v128_store16_lane(arg, LaneIdx::new(2)),
      state,
    ),
  )
  assert_stack(new_state, [])
}

// =============================================================================
// CALL INSTRUCTIONS
// =============================================================================

///|
test "Typecheck Call" {
  let func_type = FuncType::new([ValType::i32()], [ValType::i64()])
  let env = empty_env().push_func(func_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(Instruction::call(FuncIdx::new(0)), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck Call no args no results" {
  let func_type = FuncType::new([], [])
  let env = empty_env().push_func(func_type)
  let state = make_state(env, [])
  let result = Typecheck::typecheck(Instruction::call(FuncIdx::new(0)), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck Call invalid func index" {
  let env = empty_env()
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(Instruction::call(FuncIdx::new(0)), state)
  assert_err(result)
}

///|
test "Typecheck Call type mismatch" {
  let func_type = FuncType::new([ValType::i32()], [])
  let env = empty_env().push_func(func_type)
  let state = make_state(env, [ValType::i64()])
  let result = Typecheck::typecheck(Instruction::call(FuncIdx::new(0)), state)
  assert_err(result)
}

///|
test "Typecheck CallIndirect" {
  let func_subtype = SubType::comp_type(
    CompType::func([ValType::i32()], [ValType::i64()]),
  )
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(1, None),
  )
  let env = { ..empty_env(), global_types: [func_subtype] }.push_table(
    table_type,
  )
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::call_indirect(TypeIdx::new(0), TableIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck ReturnCall" {
  let func_type = FuncType::new([ValType::i32()], [ValType::i64()])
  let env = empty_env()
    .push_func(func_type)
    .with_return_type(Some([ValType::i64()]))
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::return_call(FuncIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.reachable, false)
}

///|
test "Typecheck ReturnCallIndirect" {
  let func_subtype = SubType::comp_type(
    CompType::func([ValType::i32()], [ValType::i64()]),
  )
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(1, None),
  )
  let env = { ..empty_env(), global_types: [func_subtype] }
    .push_table(table_type)
    .with_return_type(Some([ValType::i64()]))
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::return_call_indirect(TypeIdx::new(0), TableIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.reachable, false)
}

///|
test "Typecheck CallRef" {
  let func_subtype = SubType::comp_type(
    CompType::func([ValType::i32()], [ValType::i64()]),
  )
  let env = { ..empty_env(), global_types: [func_subtype] }
  let ref_type = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [ValType::i32(), ref_type])
  let result = Typecheck::typecheck(
    Instruction::call_ref(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck ReturnCallRef" {
  let func_subtype = SubType::comp_type(
    CompType::func([ValType::i32()], [ValType::i64()]),
  )
  let env = { ..empty_env(), global_types: [func_subtype] }.with_return_type(
    Some([ValType::i64()]),
  )
  let ref_type = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [ValType::i32(), ref_type])
  let result = Typecheck::typecheck(
    Instruction::return_call_ref(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.reachable, false)
}

// =============================================================================
// REFERENCE INSTRUCTIONS
// =============================================================================

///|
test "Typecheck RefFunc" {
  let func_type = FuncType::new([], [])
  let env = empty_env().push_func(func_type)
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::ref_func(FuncIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck RefFunc infers concrete function heap type when unique" {
  let ft = FuncType::new([], [])
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st]).push_func(ft)
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::ref_func(FuncIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(
    final_state,
    [ValType::ref_type(RefType::new(false, HeapType::new(TypeIdx::new(0))))],
  )
}

///|
test "Typecheck RefFunc prefers declared function type index when available" {
  let ft = FuncType::new([], [])
  let st0 = SubType::comp_type(CompType::func([], []))
  let st1 = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st0, st1]).push_func_with_typeidx(
    ft,
    Some(TypeIdx::new(1)),
  )
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::ref_func(FuncIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(
    final_state,
    [ValType::ref_type(RefType::new(false, HeapType::new(TypeIdx::new(1))))],
  )
}

///|
test "Typecheck RefFunc invalid index" {
  let env = empty_env()
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::ref_func(FuncIdx::new(0)),
    state,
  )
  assert_err(result)
}

///|
test "Typecheck RefTest non-nullable" {
  let env = empty_env()
  let state = make_state(env, [anyref_type()])
  let result = Typecheck::typecheck(
    Instruction::ref_test(false, HeapType::abs(AbsHeapType::i31())),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck RefTest eq from any" {
  let env = empty_env()
  let state = make_state(env, [anyref_type()])
  let result = Typecheck::typecheck(
    Instruction::ref_test(true, HeapType::abs(AbsHeapType::eq())),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck RefTest struct from eq" {
  let env = empty_env()
  let state = make_state(env, [eqref_type()])
  let result = Typecheck::typecheck(
    Instruction::ref_test(true, HeapType::abs(AbsHeapType::struct_())),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck RefTest fails when target not subtype of operand" {
  let env = empty_env()
  // i31ref on stack, testing for funcref - these are incompatible hierarchies
  let state = make_state(env, [i31ref_type()])
  let result = Typecheck::typecheck(
    Instruction::ref_test(true, HeapType::abs(AbsHeapType::func())),
    state,
  )
  assert_true(result is Err(_))
}

///|
test "Typecheck RefTest with concrete type recursive" {
  let struct_subtype = SubType::comp_type(CompType::struct_([]))
  let env = empty_env().with_rectype(RecType::new(struct_subtype))
  let state = make_state(env, [anyref_type()])
  let result = Typecheck::typecheck(
    Instruction::ref_test(true, HeapType::new(TypeIdx::rec(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck RefTest with concrete type in global types" {
  let struct_subtype = SubType::comp_type(CompType::struct_([]))
  let env : Env = { ..empty_env(), global_types: [struct_subtype] }
  let state = make_state(env, [anyref_type()])
  let result = Typecheck::typecheck(
    Instruction::ref_test(true, HeapType::new(TypeIdx::new(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck RefCast non-nullable" {
  let env = empty_env()
  let state = make_state(env, [anyref_type()])
  let result = Typecheck::typecheck(
    Instruction::ref_cast(false, HeapType::abs(AbsHeapType::i31())),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck RefGetDesc stack effect" {
  let env = empty_env()
  let state = make_state(env, [
    ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::i31()))),
  ])
  let result = Typecheck::typecheck(Instruction::ref_get_desc(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck RefTestDesc stack effect" {
  let env = empty_env()
  let state = make_state(env, [anyref_type()])
  let result = Typecheck::typecheck(
    Instruction::ref_test_desc(true, HeapType::abs(AbsHeapType::eq())),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck RefCastDescEq stack effect" {
  let env = empty_env()
  let state = make_state(env, [anyref_type()])
  let result = Typecheck::typecheck(
    Instruction::ref_cast_desc_eq(true, HeapType::abs(AbsHeapType::eq())),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck BrOnCast" {
  let nullable_i31 = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::i31())),
  )
  let env = empty_env().with_labels([[nullable_i31]])
  let state = make_state(env, [anyref_type()])
  let cast_op = CastOp::new(true, true)
  let t = Instruction::br_on_cast(
    LabelIdx::new(0),
    cast_op.0,
    HeapType::abs(AbsHeapType::any()),
    cast_op.1,
    HeapType::abs(AbsHeapType::i31()),
  )
  let result = Typecheck::typecheck(t, state)
  ignore(assert_ok(result))
}

///|
test "Typecheck BrOnCastFail" {
  let env = empty_env().with_labels([[anyref_type()]])
  let state = make_state(env, [anyref_type()])
  let cast_op = CastOp::new(true, true)
  let t = Instruction::br_on_cast_fail(
    LabelIdx::new(0),
    cast_op.0,
    HeapType::abs(AbsHeapType::any()),
    cast_op.1,
    HeapType::abs(AbsHeapType::i31()),
  )
  let result = Typecheck::typecheck(t, state)
  ignore(assert_ok(result))
}

// =============================================================================
// EXCEPTION HANDLING INSTRUCTIONS
// =============================================================================

///|
test "Typecheck Throw" {
  let tag_subtype = SubType::comp_type(CompType::func([ValType::i32()], []))
  let env = { ..empty_env(), global_types: [tag_subtype] }.push_tag(
    TagType::new(TypeIdx::new(0)),
  )
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(Instruction::throw_(TagIdx::new(0)), state)
  let final_state = assert_ok(result)
  assert_eq(final_state.reachable, false)
}

///|
test "Typecheck Throw invalid tag" {
  let env = empty_env()
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(Instruction::throw_(TagIdx::new(0)), state)
  assert_err(result)
}

///|
test "Typecheck ThrowRef" {
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let env = empty_env()
  let state = make_state(env, [exnref])
  let result = Typecheck::typecheck(Instruction::throw_ref(), state)
  let final_state = assert_ok(result)
  assert_eq(final_state.reachable, false)
}

///|
test "Typecheck TryTable empty" {
  let env = empty_env()
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::try_table(BlockType::void_(), [], Expr::new([])),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck TryTable with result" {
  let env = empty_env()
  let state = make_state(env, [])
  let block_type = BlockType::val_type(ValType::i32())
  let result = Typecheck::typecheck(
    Instruction::try_table(
      block_type,
      [],
      Expr::new([Instruction::i32_const(I32(42))]),
    ),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck TryTable with param input" {
  let env = empty_env().with_rectype(
    RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
  )
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::try_table(
      BlockType::type_idx(TypeIdx::new(0)),
      [],
      Expr::new([Instruction::drop()]),
    ),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck TryTable catch rejects invalid tag index" {
  let tag_sig = SubType::comp_type(CompType::func([], []))
  let env = { ..empty_env(), global_types: [tag_sig] }.push_tag(
    TagType::new(TypeIdx::new(0)),
  )
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::try_table(
      BlockType::void_(),
      [Catch::new(TagIdx::new(1), LabelIdx::new(0))],
      Expr::new([Instruction::nop()]),
    ),
    state,
  )
  assert_err(result)
}

///|
test "Typecheck TryTable catch_ref rejects invalid tag index" {
  let tag_sig = SubType::comp_type(CompType::func([], []))
  let env = { ..empty_env(), global_types: [tag_sig] }.push_tag(
    TagType::new(TypeIdx::new(0)),
  )
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::try_table(
      BlockType::void_(),
      [Catch::ref_(TagIdx::new(1), LabelIdx::new(0))],
      Expr::new([Instruction::nop()]),
    ),
    state,
  )
  assert_err(result)
}

///|
test "Typecheck TryTable catch label 0 uses outer depth semantics" {
  let tag_sig = SubType::comp_type(CompType::func([ValType::i64()], []))
  let env = { ..empty_env(), global_types: [tag_sig] }
    .push_tag(TagType::new(TypeIdx::new(0)))
    .with_labels([[ValType::i64()]])
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::try_table(
      BlockType::val_type(ValType::i32()),
      [Catch::new(TagIdx::new(0), LabelIdx::new(0))],
      Expr::new([Instruction::i32_const(I32(7))]),
    ),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck TryTable catch label 1 uses outer depth semantics" {
  let tag_sig = SubType::comp_type(CompType::func([ValType::i64()], []))
  let env = { ..empty_env(), global_types: [tag_sig] }
    .push_tag(TagType::new(TypeIdx::new(0)))
    .with_labels([[ValType::i64()], [ValType::i32()]])
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::try_table(
      BlockType::val_type(ValType::i32()),
      [Catch::new(TagIdx::new(0), LabelIdx::new(1))],
      Expr::new([Instruction::i32_const(I32(9))]),
    ),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

// =============================================================================
// STRUCT INSTRUCTIONS
// =============================================================================

///|
test "Typecheck StructNew" {
  let struct_type = SubType::comp_type(
    CompType::struct_([
      FieldType::new(StorageType::val_type(ValType::i32()), Var),
    ]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::struct_new(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck StructNewDefault" {
  let struct_type = SubType::comp_type(
    CompType::struct_([
      FieldType::new(StorageType::val_type(ValType::i32()), Var),
    ]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::struct_new_default(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck StructGet" {
  let struct_type = SubType::comp_type(
    CompType::struct_([
      FieldType::new(StorageType::val_type(ValType::i32()), Var),
    ]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let struct_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [struct_ref])
  let result = Typecheck::typecheck(
    Instruction::struct_get(TypeIdx::new(0), U32(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck StructGetS" {
  let struct_type = SubType::comp_type(
    CompType::struct_([
      FieldType::new(StorageType::pack_type(PackType::i8()), Var),
    ]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let struct_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [struct_ref])
  let result = Typecheck::typecheck(
    Instruction::struct_get_s(TypeIdx::new(0), U32(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck StructGetU" {
  let struct_type = SubType::comp_type(
    CompType::struct_([
      FieldType::new(StorageType::pack_type(PackType::i16()), Var),
    ]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let struct_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [struct_ref])
  let result = Typecheck::typecheck(
    Instruction::struct_get_u(TypeIdx::new(0), U32(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck StructSet" {
  let struct_type = SubType::comp_type(
    CompType::struct_([
      FieldType::new(StorageType::val_type(ValType::i32()), Var),
    ]),
  )
  let env = { ..empty_env(), global_types: [struct_type] }
  let struct_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [struct_ref, ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::struct_set(TypeIdx::new(0), U32(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

// =============================================================================
// ARRAY INSTRUCTIONS
// =============================================================================

///|
test "Typecheck ArrayNew" {
  let array_type = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::array_new(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck ArrayNewDefault" {
  let array_type = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::array_new_default(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck ArrayNewFixed" {
  let array_type = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let state = make_state(env, [ValType::i32(), ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::array_new_fixed(TypeIdx::new(0), U32(3)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck ArrayNewData" {
  let array_type = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  let data = Data::new(DataMode::passive(), b"")
  let env = { ..empty_env(), global_types: [array_type] }.push_data(data)
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::array_new_data(TypeIdx::new(0), DataIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck ArrayNewElem" {
  let funcref = RefType::abs(AbsHeapType::func())
  let array_type = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::val_type(ValType::ref_type(funcref)), Var),
    ),
  )
  let elem = Elem::new(ElemMode::passive(), ElemKind::funcs([]))
  let env = { ..empty_env(), global_types: [array_type] }.push_elem(elem)
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::array_new_elem(TypeIdx::new(0), ElemIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_eq(final_state.stack.length(), 1)
}

///|
test "Typecheck ArrayGet" {
  let array_type = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [array_ref, ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::array_get(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck ArrayGetS" {
  let array_type = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::pack_type(PackType::i8()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [array_ref, ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::array_get_s(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck ArrayGetU" {
  let array_type = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::pack_type(PackType::i16()), Var),
    ),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [array_ref, ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::array_get_u(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck ArraySet" {
  let array_type = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [array_ref, ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::array_set(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ArrayLen" {
  let array_ref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::array())),
  )
  let env = empty_env()
  let state = make_state(env, [array_ref])
  let result = Typecheck::typecheck(Instruction::array_len(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck ArrayFill" {
  let array_type = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [
    array_ref,
    ValType::i32(),
    ValType::i32(),
    ValType::i32(),
  ])
  let result = Typecheck::typecheck(
    Instruction::array_fill(TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ArrayCopy" {
  let array_type = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  let env = { ..empty_env(), global_types: [array_type] }
  let array_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [
    array_ref,
    ValType::i32(),
    array_ref,
    ValType::i32(),
    ValType::i32(),
  ])
  let result = Typecheck::typecheck(
    Instruction::array_copy(TypeIdx::new(0), TypeIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ArrayInitData" {
  let array_type = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  let data = Data::new(DataMode::passive(), b"")
  let env = { ..empty_env(), global_types: [array_type] }.push_data(data)
  let array_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [
    array_ref,
    ValType::i32(),
    ValType::i32(),
    ValType::i32(),
  ])
  let result = Typecheck::typecheck(
    Instruction::array_init_data(TypeIdx::new(0), DataIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ArrayInitElem" {
  let funcref = RefType::abs(AbsHeapType::func())
  let array_type = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::val_type(ValType::ref_type(funcref)), Var),
    ),
  )
  let elem = Elem::new(ElemMode::passive(), ElemKind::funcs([]))
  let env = { ..empty_env(), global_types: [array_type] }.push_elem(elem)
  let array_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let state = make_state(env, [
    array_ref,
    ValType::i32(),
    ValType::i32(),
    ValType::i32(),
  ])
  let result = Typecheck::typecheck(
    Instruction::array_init_elem(TypeIdx::new(0), ElemIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

// =============================================================================
// MEMORY INIT/DATA INSTRUCTIONS
// =============================================================================

///|
test "Typecheck MemoryInit" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let data = Data::new(DataMode::passive(), b"")
  let env = empty_env().push_mem(mem_type).push_data(data)
  let state = make_state(env, [ValType::i32(), ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::memory_init(DataIdx::new(0), MemIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck DataDrop" {
  let data = Data::new(DataMode::passive(), b"")
  let env = empty_env().push_data(data)
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::data_drop(DataIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck DataDrop invalid index" {
  let env = empty_env()
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::data_drop(DataIdx::new(0)),
    state,
  )
  assert_err(result)
}

// =============================================================================
// TABLE INIT/ELEM INSTRUCTIONS
// =============================================================================

///|
test "Typecheck TableInit" {
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(1, None),
  )
  let elem = Elem::new(ElemMode::passive(), ElemKind::funcs([]))
  let env = empty_env().push_table(table_type).push_elem(elem)
  let state = make_state(env, [ValType::i32(), ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::table_init(ElemIdx::new(0), TableIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ElemDrop" {
  let elem = Elem::new(ElemMode::passive(), ElemKind::funcs([]))
  let env = empty_env().push_elem(elem)
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::elem_drop(ElemIdx::new(0)),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck ElemDrop invalid index" {
  let env = empty_env()
  let state = make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::elem_drop(ElemIdx::new(0)),
    state,
  )
  assert_err(result)
}

// =============================================================================
// ADDITIONAL NUMERIC INSTRUCTIONS (missing from original tests)
// =============================================================================

///|
test "Typecheck I64LtU" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_lt_u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I64GtS" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_gt_s(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I64LeS" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_le_s(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I64LeU" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_le_u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I64GeS" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_ge_s(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I64GeU" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_ge_u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I64Ctz" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_ctz(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64Popcnt" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_popcnt(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64DivS" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_div_s(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64DivU" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_div_u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64RemS" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_rem_s(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64RemU" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_rem_u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64And" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_and(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64Or" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_or(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64Xor" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_xor(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64Shl" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_shl(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64ShrS" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_shr_s(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64ShrU" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_shr_u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64Rotl" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_rotl(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64Rotr" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::i64_rotr(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck F64Ne" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64(), ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_ne(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck F64Gt" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64(), ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_gt(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck F64Le" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64(), ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_le(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck F64Ge" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64(), ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_ge(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck F64Ceil" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_ceil(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f64()])
}

///|
test "Typecheck F64Floor" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_floor(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f64()])
}

///|
test "Typecheck F64Trunc" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_trunc(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f64()])
}

///|
test "Typecheck F64Nearest" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_nearest(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f64()])
}

///|
test "Typecheck F64Sqrt" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_sqrt(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f64()])
}

///|
test "Typecheck F64Min" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64(), ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_min(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f64()])
}

///|
test "Typecheck F64Max" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64(), ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_max(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f64()])
}

///|
test "Typecheck F64Copysign" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64(), ValType::f64()])
  let result = Typecheck::typecheck(Instruction::f64_copysign(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f64()])
}

///|
test "Typecheck F32Trunc" {
  let env = empty_env()
  let state = make_state(env, [ValType::f32()])
  let result = Typecheck::typecheck(Instruction::f32_trunc(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f32()])
}

///|
test "Typecheck F32Nearest" {
  let env = empty_env()
  let state = make_state(env, [ValType::f32()])
  let result = Typecheck::typecheck(Instruction::f32_nearest(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f32()])
}

///|
test "Typecheck I64TruncF32U" {
  let env = empty_env()
  let state = make_state(env, [ValType::f32()])
  let result = Typecheck::typecheck(Instruction::i64_trunc_f32u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64TruncF64U" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64()])
  let result = Typecheck::typecheck(Instruction::i64_trunc_f64u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck F32ConvertI64U" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64()])
  let result = Typecheck::typecheck(Instruction::f32_convert_i64u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f32()])
}

///|
test "Typecheck F64ConvertI32U" {
  let env = empty_env()
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(Instruction::f64_convert_i32u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f64()])
}

///|
test "Typecheck F64ConvertI64U" {
  let env = empty_env()
  let state = make_state(env, [ValType::i64()])
  let result = Typecheck::typecheck(Instruction::f64_convert_i64u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::f64()])
}

///|
test "Typecheck I32TruncSatF64U" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64()])
  let result = Typecheck::typecheck(Instruction::i32_trunc_sat_f64u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I64TruncSatF32U" {
  let env = empty_env()
  let state = make_state(env, [ValType::f32()])
  let result = Typecheck::typecheck(Instruction::i64_trunc_sat_f32u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64TruncSatF64U" {
  let env = empty_env()
  let state = make_state(env, [ValType::f64()])
  let result = Typecheck::typecheck(Instruction::i64_trunc_sat_f64u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

// =============================================================================
// ADDITIONAL LOAD/STORE INSTRUCTIONS
// =============================================================================

///|
test "Typecheck I64Load8U" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::i64_load8u(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64Load16S" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::i64_load16s(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64Load16U" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::i64_load16u(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I64Load32U" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::i64_load32u(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i64()])
}

///|
test "Typecheck I32Store16" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::i32_store16(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck I64Store8" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32(), ValType::i64()])
  let result = Typecheck::typecheck(
    Instruction::i64_store8(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

///|
test "Typecheck I64Store16" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32(), ValType::i64()])
  let result = Typecheck::typecheck(
    Instruction::i64_store16(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [])
}

// =============================================================================
// ADDITIONAL SIMD INSTRUCTIONS
// =============================================================================

///|
test "Typecheck I8x16Shuffle" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let t = Instruction::i8x16_shuffle(
    LaneIdx::new(0),
    LaneIdx::new(1),
    LaneIdx::new(2),
    LaneIdx::new(3),
    LaneIdx::new(4),
    LaneIdx::new(5),
    LaneIdx::new(6),
    LaneIdx::new(7),
    LaneIdx::new(8),
    LaneIdx::new(9),
    LaneIdx::new(10),
    LaneIdx::new(11),
    LaneIdx::new(12),
    LaneIdx::new(13),
    LaneIdx::new(14),
    LaneIdx::new(15),
  )
  let result = Typecheck::typecheck(t, state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck I8x16Swizzle" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_swizzle(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128AnyTrue" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::v128_any_true(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I8x16AllTrue" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_all_true(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I8x16Bitmask" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_bitmask(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I16x8Bitmask" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_bitmask(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I32x4Bitmask" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i32x4_bitmask(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck I64x2Bitmask" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_bitmask(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::i32()])
}

///|
test "Typecheck V128Or" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::v128_or(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Xor" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::v128_xor(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Andnot" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::v128_andnot(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck I8x16Neg" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_neg(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck I8x16Popcnt" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_popcnt(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck I8x16Sub" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_sub(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck I8x16AddSatS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_add_sat_s(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck I8x16AddSatU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_add_sat_u(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck I64x2Add" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_add(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck I64x2Sub" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_sub(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck I64x2Mul" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_mul(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F32x4Add" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_add(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F32x4Sub" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_sub(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F32x4Mul" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_mul(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F64x2Add" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_add(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F64x2Sub" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_sub(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F64x2Mul" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_mul(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F64x2Div" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_div(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F32x4Abs" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_abs(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F32x4Neg" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_neg(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F32x4Sqrt" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_sqrt(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F64x2Abs" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_abs(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F64x2Neg" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_neg(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck F64x2Sqrt" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_sqrt(), state)
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Load32Zero" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load32_zero(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Load64Zero" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load64_zero(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Load8x8S" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load8x8s(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Load8x8U" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load8x8u(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Load16x4S" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load16x4s(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Load16x4U" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load16x4u(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Load32x2S" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load32x2s(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Load32x2U" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load32x2u(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Load8Splat" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load8_splat(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

///|
test "Typecheck V128Load16Splat" {
  let mem_type = MemType::new(Limits::i32(1, None))
  let env = empty_env().push_mem(mem_type)
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load16_splat(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let final_state = assert_ok(result)
  assert_stack(final_state, [ValType::v128()])
}

// =============================================================================
// SIMD LOAD TESTS (Missing)
// =============================================================================

///|
test "Typecheck V128Load32Splat" {
  let env = empty_env().push_mem(MemType::new(Limits::i32(1, None)))
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load32_splat(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck V128Load64Splat" {
  let env = empty_env().push_mem(MemType::new(Limits::i32(1, None)))
  let state = make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::v128_load64_splat(MemArg::new(U32(0), None, U64(0))),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck V128Load32Lane" {
  let env = empty_env().push_mem(MemType::new(Limits::i32(1, None)))
  let state = make_state(env, [ValType::i32(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::v128_load32_lane(
      MemArg::new(U32(0), None, U64(0)),
      LaneIdx::new(0),
    ),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck V128Load64Lane" {
  let env = empty_env().push_mem(MemType::new(Limits::i32(1, None)))
  let state = make_state(env, [ValType::i32(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::v128_load64_lane(
      MemArg::new(U32(0), None, U64(0)),
      LaneIdx::new(0),
    ),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

// =============================================================================
// SIMD STORE TESTS (Missing)
// =============================================================================

///|
test "Typecheck V128Store8Lane" {
  let env = empty_env().push_mem(MemType::new(Limits::i32(1, None)))
  let state = make_state(env, [ValType::i32(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::v128_store8_lane(
      MemArg::new(U32(0), None, U64(0)),
      LaneIdx::new(0),
    ),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [])
}

///|
test "Typecheck V128Store32Lane" {
  let env = empty_env().push_mem(MemType::new(Limits::i32(1, None)))
  let state = make_state(env, [ValType::i32(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::v128_store32_lane(
      MemArg::new(U32(0), None, U64(0)),
      LaneIdx::new(0),
    ),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [])
}

///|
test "Typecheck V128Store64Lane" {
  let env = empty_env().push_mem(MemType::new(Limits::i32(1, None)))
  let state = make_state(env, [ValType::i32(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::v128_store64_lane(
      MemArg::new(U32(0), None, U64(0)),
      LaneIdx::new(0),
    ),
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
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::f32x4_demote_f64x2_zero(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2PromoteLowF32x4" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::f64x2_promote_low_f32x4(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4TruncSatF32x4S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_trunc_sat_f32x4s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4TruncSatF32x4U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_trunc_sat_f32x4u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4ConvertI32x4S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_convert_i32x4s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4ConvertI32x4U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_convert_i32x4u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4TruncSatF64x2SZero" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_trunc_sat_f64x2s_zero(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4TruncSatF64x2UZero" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_trunc_sat_f64x2u_zero(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2ConvertLowI32x4S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::f64x2_convert_low_i32x4s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2ConvertLowI32x4U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::f64x2_convert_low_i32x4u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

// =============================================================================
// SIMD i8x16 TESTS (Missing)
// =============================================================================

///|
test "Typecheck I8x16NarrowI16x8S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_narrow_i16x8s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16NarrowI16x8U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_narrow_i16x8u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16Shl" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i8x16_shl(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16ShrS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i8x16_shr_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16ShrU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i8x16_shr_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16SubSatS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_sub_sat_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16SubSatU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_sub_sat_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16MinS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_min_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16MinU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_min_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16MaxS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_max_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16MaxU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_max_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16AvgrU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_avgr_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

// =============================================================================
// SIMD i16x8 TESTS (Missing)
// =============================================================================

///|
test "Typecheck I16x8Abs" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_abs(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8AllTrue" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_all_true(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::i32()])
}

///|
test "Typecheck I16x8Q15mulrSatS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8q15mulr_sat_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8NarrowI32x4S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_narrow_i32x4s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8NarrowI32x4U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_narrow_i32x4u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ExtendLowI8x16S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_extend_low_i8x16s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ExtendHighI8x16S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_extend_high_i8x16s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ExtendLowI8x16U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_extend_low_i8x16u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ExtendHighI8x16U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_extend_high_i8x16u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8Shl" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i16x8_shl(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ShrS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i16x8_shr_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ShrU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i16x8_shr_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8Add" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_add(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8AddSatS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_add_sat_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8AddSatU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_add_sat_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8Sub" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_sub(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8SubSatS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_sub_sat_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8SubSatU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_sub_sat_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8MinS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_min_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8MinU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_min_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8MaxS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_max_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8MaxU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_max_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8AvgrU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i16x8_avgr_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ExtmulLowI8x16S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_extmul_low_i8x16s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ExtmulHighI8x16S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_extmul_high_i8x16s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ExtmulLowI8x16U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_extmul_low_i8x16u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ExtmulHighI8x16U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_extmul_high_i8x16u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ExtaddPairwiseI8x16S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_extadd_pairwise_i8x16s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8ExtaddPairwiseI8x16U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_extadd_pairwise_i8x16u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

// =============================================================================
// SIMD i32x4 TESTS (Missing)
// =============================================================================

///|
test "Typecheck I32x4Abs" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i32x4_abs(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4Neg" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i32x4_neg(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ExtendLowI16x8S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_extend_low_i16x8s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ExtendHighI16x8S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_extend_high_i16x8s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ExtendLowI16x8U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_extend_low_i16x8u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ExtendHighI16x8U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_extend_high_i16x8u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4Shl" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i32x4_shl(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ShrS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i32x4_shr_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ShrU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i32x4_shr_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4Add" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i32x4_add(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4Mul" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i32x4_mul(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4MinS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i32x4_min_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4MinU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i32x4_min_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4MaxS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i32x4_max_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4MaxU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i32x4_max_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4DotI16x8S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i32x4_dot_i16x8s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ExtmulLowI16x8S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_extmul_low_i16x8s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ExtmulHighI16x8S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_extmul_high_i16x8s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ExtmulLowI16x8U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_extmul_low_i16x8u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ExtmulHighI16x8U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_extmul_high_i16x8u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ExtaddPairwiseI16x8S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_extadd_pairwise_i16x8s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4ExtaddPairwiseI16x8U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_extadd_pairwise_i16x8u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

// =============================================================================
// SIMD i64x2 TESTS (Missing)
// =============================================================================

///|
test "Typecheck I64x2Abs" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_abs(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2Neg" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_neg(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2AllTrue" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_all_true(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::i32()])
}

///|
test "Typecheck I64x2ExtendLowI32x4S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i64x2_extend_low_i32x4s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2ExtendHighI32x4S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i64x2_extend_high_i32x4s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2ExtendLowI32x4U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i64x2_extend_low_i32x4u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2ExtendHighI32x4U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i64x2_extend_high_i32x4u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2Shl" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i64x2_shl(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2ShrS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i64x2_shr_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2ShrU" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::i32()])
  let result = Typecheck::typecheck(Instruction::i64x2_shr_u(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2Eq" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_eq(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2Ne" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_ne(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2LtS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_lt_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2GtS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_gt_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2LeS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_le_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2GeS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i64x2_ge_s(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2ExtmulLowI32x4S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i64x2_extmul_low_i32x4s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2ExtmulHighI32x4S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i64x2_extmul_high_i32x4s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2ExtmulLowI32x4U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i64x2_extmul_low_i32x4u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2ExtmulHighI32x4U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i64x2_extmul_high_i32x4u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

// =============================================================================
// SIMD f32x4 TESTS (Missing)
// =============================================================================

///|
test "Typecheck F32x4Ceil" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_ceil(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4Floor" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_floor(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4Trunc" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_trunc(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4Nearest" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_nearest(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4Min" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_min(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4Max" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_max(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4Pmin" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_pmin(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4Pmax" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_pmax(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

// =============================================================================
// SIMD f64x2 TESTS (Missing)
// =============================================================================

///|
test "Typecheck F64x2Ceil" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_ceil(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2Floor" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_floor(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2Trunc" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_trunc(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2Nearest" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_nearest(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2Min" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_min(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2Max" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_max(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2Pmin" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_pmin(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2Pmax" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_pmax(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

// =============================================================================
// SIMD RELAXED TESTS
// =============================================================================

///|
test "Typecheck I8x16RelaxedSwizzle" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::i8x16_relaxed_swizzle(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4RelaxedTruncF32x4S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_relaxed_trunc_f32x4s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4RelaxedTruncF32x4U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_relaxed_trunc_f32x4u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4RelaxedTruncZeroF64x2S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_relaxed_trunc_zero_f64x2s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4RelaxedTruncZeroF64x2U" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i32x4_relaxed_trunc_zero_f64x2u(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4RelaxedMadd" {
  let env = empty_env()
  let state = make_state(env, [
    ValType::v128(),
    ValType::v128(),
    ValType::v128(),
  ])
  let result = Typecheck::typecheck(Instruction::f32x4_relaxed_madd(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4RelaxedNmadd" {
  let env = empty_env()
  let state = make_state(env, [
    ValType::v128(),
    ValType::v128(),
    ValType::v128(),
  ])
  let result = Typecheck::typecheck(Instruction::f32x4_relaxed_nmadd(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2RelaxedMadd" {
  let env = empty_env()
  let state = make_state(env, [
    ValType::v128(),
    ValType::v128(),
    ValType::v128(),
  ])
  let result = Typecheck::typecheck(Instruction::f64x2_relaxed_madd(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2RelaxedNmadd" {
  let env = empty_env()
  let state = make_state(env, [
    ValType::v128(),
    ValType::v128(),
    ValType::v128(),
  ])
  let result = Typecheck::typecheck(Instruction::f64x2_relaxed_nmadd(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I8x16RelaxedLaneselect" {
  let env = empty_env()
  let state = make_state(env, [
    ValType::v128(),
    ValType::v128(),
    ValType::v128(),
  ])
  let result = Typecheck::typecheck(
    Instruction::i8x16_relaxed_laneselect(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8RelaxedLaneselect" {
  let env = empty_env()
  let state = make_state(env, [
    ValType::v128(),
    ValType::v128(),
    ValType::v128(),
  ])
  let result = Typecheck::typecheck(
    Instruction::i16x8_relaxed_laneselect(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4RelaxedLaneselect" {
  let env = empty_env()
  let state = make_state(env, [
    ValType::v128(),
    ValType::v128(),
    ValType::v128(),
  ])
  let result = Typecheck::typecheck(
    Instruction::i32x4_relaxed_laneselect(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I64x2RelaxedLaneselect" {
  let env = empty_env()
  let state = make_state(env, [
    ValType::v128(),
    ValType::v128(),
    ValType::v128(),
  ])
  let result = Typecheck::typecheck(
    Instruction::i64x2_relaxed_laneselect(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4RelaxedMin" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_relaxed_min(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F32x4RelaxedMax" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f32x4_relaxed_max(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2RelaxedMin" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_relaxed_min(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck F64x2RelaxedMax" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(Instruction::f64x2_relaxed_max(), state)
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8RelaxedQ15mulrS" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_relaxed_q15mulr_s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I16x8RelaxedDotI8x16I7x16S" {
  let env = empty_env()
  let state = make_state(env, [ValType::v128(), ValType::v128()])
  let result = Typecheck::typecheck(
    Instruction::i16x8_relaxed_dot_i8x16i7x16s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}

///|
test "Typecheck I32x4RelaxedDotI8x16I7x16AddS" {
  let env = empty_env()
  let state = make_state(env, [
    ValType::v128(),
    ValType::v128(),
    ValType::v128(),
  ])
  let result = Typecheck::typecheck(
    Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s(),
    state,
  )
  let state = assert_ok(result)
  assert_stack(state, [ValType::v128()])
}
