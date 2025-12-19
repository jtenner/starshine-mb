pub struct TcState {
  env: Env
  stack: Array[ValType]
  reachable: Bool
}

pub type TcResult = Result[TcState, String]

pub trait Typecheck {
  typecheck(Self, TcState) -> Result[TcState, String]
}

fn TcState::with_stack(st: TcState, stack: Array[ValType]) -> TcState {
  TcState::{ env: st.env, stack: stack, reachable: st.reachable }
}

fn TcState::set_unreachable(st: TcState) -> TcState {
  TcState::{ env: st.env, stack: st.stack, reachable: false }
}

fn TcState::push1(st: TcState, vt: ValType) -> TcState {
  let s = st.stack.copy()
  s.push(vt)
  st.with_stack(s)
}

fn TcState::check_branch_args_present(st: TcState, l: LabelIdx) -> Result[Array[ValType], String] {
  match st.env.get_label_types(l) {
    None => Err("invalid label index")
    Some(ts) => Ok(ts)
  }
}

fn TcState::pop1(st: TcState) -> Result[(TcState, ValType), String] {
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

fn TcState::pop_expect(st: TcState, expected: ValType) -> TcResult {
  match st.pop1() {
    Err(e) => Err(e)
    Ok((st2, actual)) => {
      if !st.reachable { return Ok(st2) }
      if actual.matches(expected, st.env) {
        Ok(st2)
      } else {
        Err("type mismatch")
      }
    }
  }
}

fn typecheck_drop(st: TcState) -> TcResult {
  match st.pop1() {
    Err(e) => Err(e)
    Ok((st2, _)) => Ok(st2)
  }
}

fn TcState::push_types(st: TcState, ts: Array[ValType]) -> TcState {
  let mut out = st
  for t in ts {
    out = out.push1(t)
  }
  out
}

fn TcState::pop_types(st: TcState, ts: Array[ValType]) -> TcResult {
  // Pop in reverse because LIFO
  let n = ts.length()
  if n == 0 { return Ok(st) }

  let mut cur = st
  for i in (n - 1).until(0, step=-1) {
    cur =
      match cur.pop_expect(ts[i]) {
        Err(e) => return Err(e)
        Ok(s) => s
      }
  }

  Ok(cur)
}

fn expect_ref_null_heaptype(v: ValType) -> Result[HeapType, String] {
  match v {
    RefTypeValType(rt) =>
      match rt {
        HeapTypeRefType(true, ht) => Ok(ht)
        HeapTypeRefType(false, _) => Err("expected (ref null ht), got non-null ref")
        AbsHeapTypeRefType(_) => Err("expected (ref null ht), got abstract ref type")
      }

    _ => Err("expected reference type")
  }
}

fn pop_types_rev(st: TcState, ts: Array[ValType]) -> TcResult {
  let n = ts.length()
  if n == 0 { return Ok(st) }
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

fn typecheck_select_typed(st: TcState, ts: Array[ValType]) -> TcResult {
  if !Validate::validate(ts, st.env) {
    return Err("invalid select type annotation")
    }

  // condition
  let st1 =
    match st.pop_expect(NumTypeValType(I32NumType)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  let st2 =
    match pop_types_rev(st1, ts) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  let st3 =
    match pop_types_rev(st2, ts) {
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

fn typecheck_select_untyped(st: TcState) -> TcResult {
  // pop condition (i32)
  let st1 =
    match st.pop_expect(NumTypeValType(I32NumType)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // pop second operand
  let (st2, t2) =
    match st1.pop1() {
      Err(e) => return Err(e)
      Ok(pair) => pair
    }

  // pop first operand
  let (st3, t1) =
    match st2.pop1() {
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

fn typecheck_local_get(st: TcState, idx: LocalIdx) -> TcResult {
  match st.env.get_local_type(idx) {
    None => Err("invalid local index")
    Some(vt) => Ok(st.push1(vt))
  }
}

fn typecheck_local_set(st: TcState, idx: LocalIdx) -> TcResult {
  match st.env.get_local_type(idx) {
    None => Err("invalid local index")
    Some(vt) => st.pop_expect(vt)
  }
}

fn typecheck_local_tee(st: TcState, idx: LocalIdx) -> TcResult {
  match st.env.get_local_type(idx) {
    None => Err("invalid local index")
    Some(vt) => {
      // tee pops vt then pushes vt
      match st.pop_expect(vt) {
        Err(e) => Err(e)
        Ok(st2) => Ok(st2.push1(vt))
      }
    }
  }
}

fn typecheck_global_get(st: TcState, idx: GlobalIdx) -> TcResult {
  match st.env.get_global_type(idx) {
    None => Err("invalid global index")
    Some(GlobalType(vt, _mut)) => Ok(st.push1(vt))
  }
}

fn typecheck_global_set(st: TcState, idx: GlobalIdx) -> TcResult {
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
fn typecheck_table_get(st: TcState, idx: TableIdx) -> TcResult {
  let TableType(rt, _) =
    match st.env.get_table_type(idx) {
      None => return Err("invalid table index")
      Some(tt) => tt
    }

  let st1 =
    match st.pop_expect(i32_valtype()) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st1.push1(ref_valtype(rt)))
}

// table.set x : [i32, t] -> []
fn typecheck_table_set(st: TcState, idx: TableIdx) -> TcResult {
  let TableType(rt, _) =
    match st.env.get_table_type(idx) {
      None => return Err("invalid table index")
      Some(tt) => tt
    }

  // pop value (t)
  let st1 =
    match st.pop_expect(ref_valtype(rt)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // pop index (i32)
  let st2 =
    match st1.pop_expect(i32_valtype()) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st2)
}

// table.size x : [] -> [i32]
fn typecheck_table_size(st: TcState, idx: TableIdx) -> TcResult {
  match st.env.get_table_type(idx) {
    None => Err("invalid table index")
    Some(_) => Ok(st.push1(i32_valtype()))
  }
}

// table.grow x : [t, i32] -> [i32]
fn typecheck_table_grow(st: TcState, idx: TableIdx) -> TcResult {
  let TableType(rt, _) =
    match st.env.get_table_type(idx) {
      None => return Err("invalid table index")
      Some(tt) => tt
    }

  // pop delta (i32) — top of stack
  let st1 =
    match st.pop_expect(i32_valtype()) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // pop init value (t)
  let st2 =
    match st1.pop_expect(ref_valtype(rt)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st2.push1(i32_valtype()))
}

fn typecheck_br(st: TcState, l: LabelIdx) -> TcResult {
  let ts =
    match st.env.get_label_types(l) {
      None => return Err("invalid label index")
      Some(x) => x
    }

  let st1 =
    match st.pop_types(ts) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st1.set_unreachable())
}

fn typecheck_block(st: TcState, bt: BlockType, body: Expr) -> TcResult {
  let (params, results) =
    match st.env.expand_blocktype(bt) {
      Err(e) => return Err(e)
      Ok(x) => x
    }

  // Entry stack height after consuming params
  let st1 =
    match st.pop_types(params) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
  let base_len = st1.stack.length()

  // Typecheck body with label = results
  let env2 = st1.env.with_label(results)
  let st_body0 = TcState::{ env: env2, stack: st1.stack, reachable: st1.reachable }

  let st_body =
    match body.typecheck(st_body0) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // If reachable, enforce results on top
  let st2 =
    if st_body.reachable {
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
    reachable: st.reachable, // reachability after block is same as entry unless you model merges
  }

  Ok(out.push_types(results))
}

fn typecheck_if(
  st: TcState,
  bt: BlockType,
  then_instrs: Array[Instruction],
  else_instrs_opt: Array[Instruction]?,
) -> TcResult {
  let (params, results) =
    match st.env.expand_blocktype(bt) {
      Err(e) => return Err(e)
      Ok(x) => x
    }

  // pop condition
  let st0 =
    match st.pop_expect(NumTypeValType(I32NumType)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // pop params
  let st1 =
    match st0.pop_types(params) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
  let base_len = st1.stack.length()

  let else_instrs =
    match else_instrs_opt {
      None => []
      Some(xs) => xs
    }

  // typecheck then branch
  let env_branch = st1.env.with_label(results)
  let st_then0 = TcState::{ env: env_branch, stack: st1.stack, reachable: st1.reachable }
  let st_then =
    match Expr(then_instrs).typecheck(st_then0) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // typecheck else branch (same starting state!)
  let st_else0 = TcState::{ env: env_branch, stack: st1.stack, reachable: st1.reachable }
  let st_else =
    match Expr(else_instrs).typecheck(st_else0) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // For each reachable branch: enforce results on top and truncate to base_len.
  let norm_branch =
    fn (sb: TcState) -> Result[(Bool, Array[ValType]), String] {
      let sb2 =
        if sb.reachable {
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

  let (then_reach, then_stack) =
    match norm_branch(st_then) {
      Err(e) => return Err(e)
      Ok(x) => x
    }

  let (else_reach, else_stack) =
    match norm_branch(st_else) {
      Err(e) => return Err(e)
      Ok(x) => x
    }

  // Merge rule: if both reachable, stacks must be identical at merge point.
  // If one unreachable, take the other.
  let merged_stack =
    match (then_reach, else_reach) {
      (true, true) => {
        if then_stack != else_stack { return Err("if branch stack mismatch") }
        then_stack
      }
      (true, false) => then_stack
      (false, true) => else_stack
      (false, false) => st1.stack.copy() // both unreachable, base is fine
    }

  let merged_reachable = then_reach || else_reach

  let out = TcState::{ env: st.env, stack: merged_stack, reachable: merged_reachable }
  Ok(out.push_types(results))
}

fn typecheck_br_if(st: TcState, l: LabelIdx) -> TcResult {
  let ts =
    match st.env.get_label_types(l) {
      None => return Err("invalid label index")
      Some(x) => x
    }

  // Pop condition first
  let st1 =
    match st.pop_expect(NumTypeValType(I32NumType)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // If unreachable, the stack is polymorphic; br_if is fine
  if !st.reachable {
    return Ok(st1)
  }

  // Check that branch arguments are present.
  // Important: do NOT keep the popped state; this is only a type check.
  let _ =
    match st1.pop_types(ts) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }

  // Not-taken path continues with the stack after popping only the condition
  Ok(st1)
}

fn typecheck_br_table(st: TcState, ls: Array[LabelIdx], ldef: LabelIdx) -> TcResult {
  // pop selector
  let st1 =
    match st.pop_expect(NumTypeValType(I32NumType)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // If unreachable, polymorphic stack: only need label indices to be valid.
  // But we still must ensure label types are consistent to avoid invalid modules.
  // We'll keep checking label types even if unreachable.
  let ts =
    match st.env.get_label_types(ldef) {
      None => return Err("invalid default label index")
      Some(x) => x
    }

  // Every label in the table must have the same types as the default
  for l in ls {
    let ts_l =
      match st.env.get_label_types(l) {
        None => return Err("invalid label index in br_table")
        Some(x) => x
      }

    // Require invariance (same in both directions). For label result types,
    // exact equality is the usual requirement; mutual match is safer with your
    // subtyping machinery.
    let same = Match::matches(ts_l, ts, st.env) && Match::matches(ts, ts_l, st.env)
    if !same {
      return Err("br_table target labels have different argument types")
    }
  }

  // If reachable, ensure the arguments are present on the stack (below selector).
  if st.reachable {
    let _ =
      match st1.pop_types(ts) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
  }

  // Not-taken path continues (like br_if): only selector is consumed.
  Ok(st1)
}

fn typecheck_return(st: TcState) -> TcResult {
  let ts =
    match st.env.return_type {
      None => return Err("return used with no function return type in context")
      Some(t) => t
    }

  let st1 =
    match st.pop_types(ts) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st1.set_unreachable())
}

fn typecheck_call(st: TcState, fidx: FuncIdx) -> TcResult {
  let FuncType(params, results) =
    match st.env.get_functype_by_funcidx(fidx) {
      None => return Err("invalid function index")
      Some(ft) => ft
    }

  let st1 =
    match st.pop_types(params) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st1.push_types(results))
}

fn typecheck_call_indirect(st: TcState, tidx: TypeIdx, tid: TableIdx) -> TcResult {
  // Resolve the function type from the type index
  let FuncType(params, results) =
    match st.env.resolve_functype(tidx) {
      None => return Err("call_indirect type index is not a function type")
      Some(ft) => ft
    }

  // Table must exist and have element type compatible with funcref
  let TableType(elem_rt, _) =
    match st.env.get_table_type(tid) {
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
  let st1 =
    match st.pop_expect(NumTypeValType(I32NumType)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // Pop params
  let st2 =
    match st1.pop_types(params) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st2.push_types(results))
}

fn typecheck_call_ref(st: TcState, tidx: TypeIdx) -> TcResult {
  let FuncType(params, results) =
    match st.env.resolve_functype(tidx) {
      None => return Err("call_ref type index is not a function type")
      Some(ft) => ft
    }

  // Pop funcref of type (ref null tidx)
  // Your representation: HeapTypeRefType(nullable, HeapType(TypeIdx))
  let fref = RefTypeValType(HeapTypeRefType(true, HeapType(tidx)))

  let st1 =
    match st.pop_expect(fref) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // Pop params
  let st2 =
    match st1.pop_types(params) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st2.push_types(results))
}

fn require_return_results(st: TcState, results: Array[ValType]) -> Result[Unit, String] {
  match st.env.return_type {
    None => Err("return_call used with no function return type in context")
    Some(rt) =>
      if equals(results, rt) { Ok(()) } else { Err("tail call result mismatch") }
  }
}

fn typecheck_return_call(st: TcState, fidx: FuncIdx) -> TcResult {
  let FuncType(params, results) =
    match st.env.get_functype_by_funcidx(fidx) {
      None => return Err("invalid function index")
      Some(ft) => ft
    }

  match require_return_results(st, results) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }

  let st1 =
    match st.pop_types(params) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st1.set_unreachable())
}

fn typecheck_return_call_indirect(st: TcState, tidx: TypeIdx, t: TableIdx) -> TcResult {
  let FuncType(params, results) =
    match st.env.resolve_functype(tidx) {
      None => return Err("return_call_indirect type index is not a function type")
      Some(ft) => ft
    }

  match require_return_results(st, results) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }

  let TableType(elem_rt, _) =
    match st.env.get_table_type(t) {
      None => return Err("invalid table index")
      Some(tt) => tt
    }

  // elem_rt <: funcref
  let fr = RefTypeValType(AbsHeapTypeRefType(FuncAbsHeapType))
  let elem_vt = RefTypeValType(elem_rt)
  if !Match::matches(elem_vt, fr, st.env) {
    return Err("return_call_indirect table element type is not funcref-compatible")
  }

  let st1 =
    match st.pop_expect(NumTypeValType(I32NumType)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  let st2 =
    match st1.pop_types(params) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st2.set_unreachable())
}

fn typecheck_return_call_ref(st: TcState, tidx: TypeIdx) -> TcResult {
  let FuncType(params, results) =
    match st.env.resolve_functype(tidx) {
      None => return Err("return_call_ref type index is not a function type")
      Some(ft) => ft
    }

  match require_return_results(st, results) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }

  let fref = RefTypeValType(HeapTypeRefType(true, HeapType(tidx)))

  let st1 =
    match st.pop_expect(fref) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  let st2 =
    match st1.pop_types(params) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st2.set_unreachable())
}

fn expect_nullable_ref(v: ValType) -> Result[(HeapType, RefType), String] {
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
fn typecheck_br_on_null(st: TcState, l: LabelIdx) -> TcResult {
  let ts =
    match st.env.get_label_types(l) {
      None => return Err("invalid label index")
      Some(x) => x
    }

  // Pop operand: must be exactly (ref null ht)
  let (st1, v) =
    match st.pop1() {
      Err(e) => return Err(e)
      Ok(pair) => pair
    }

  let ht =
    match expect_ref_null_heaptype(v) {
      Err(e) => return Err(e)
      Ok(x) => x
    }

  if !ht.validate(st.env) {
    return Err("invalid heap type in br_on_null operand")
  }

  // Branch target label has type t*
  if st.reachable {
    let _ =
      match st1.pop_types(ts) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
  }

  // Fallthrough refines to non-null (ref ht)
  Ok(st1.push1(RefTypeValType(HeapTypeRefType(false, ht))))
}

fn typecheck_br_on_non_null(st: TcState, l: LabelIdx) -> TcResult {
  let label_ts =
    match st.env.get_label_types(l) {
      None => return Err("invalid label index")
      Some(x) => x
    }

  // pop the reference value (must be nullable ref)
  let (st1, v) =
    match st.pop1() {
      Err(e) => return Err(e)
      Ok(pair) => pair
    }

  let (ht, rt_in) =
    match expect_nullable_ref(v) {
      Err(e) => return Err(e)
      Ok(x) => x
    }

  if !ht.validate(st.env) {
    return Err("invalid heap type in br_on_non_null operand")
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
    let _ =
      match st1.pop_types(prefix.to_array()) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
  }

  // Fallthrough type is t* (ref is consumed)
  Ok(st1)
}

fn typecheck_br_on_cast(
  st: TcState,
  l: LabelIdx,
  op: CastOp,
  ht1: HeapType,
  ht2: HeapType,
) -> TcResult {
  let CastOp(n1, n2) = op
  let rt1 = HeapTypeRefType(n1, ht1)
  let rt2 = HeapTypeRefType(n2, ht2)

  if !rt1.validate(st.env) { return Err("invalid rt1") }
  if !rt2.validate(st.env) { return Err("invalid rt2") }

  let label_ts =
    match st.check_branch_args_present(l) {
      Err(e) => return Err(e)
      Ok(x) => x
    }
  if label_ts.length() == 0 { return Err("br_on_cast label type too short") }

  let rt_label =
    match label_ts[label_ts.length() - 1] {
      RefTypeValType(r) => r
      _ => return Err("br_on_cast label must end with a reftype")
    }

  // rt2 <: rt1 and rt2 <: rt_label
  if !Match::matches(rt2, rt1, st.env) { return Err("rt2 does not match rt1") }
  if !Match::matches(rt2, rt_label, st.env) { return Err("rt2 does not match label rt") }

  // pop rt1
  let st1 =
    match st.pop_expect(RefTypeValType(rt1)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  if st.reachable {
    // Check label args excluding rt_label (because branch keeps rt2 / rt_label)
    // Per spec, label is t* rt, so the remaining stack must have t*
    let prefix = label_ts.sub(start=0, end=label_ts.length() - 1) // adjust if no slice
    let _ =
      match st1.pop_types(prefix.to_array()) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
  }

  // push (rt1 \ rt2)
  let rt_out =
    match diff(rt1, rt2) {
      Err(e) => return Err(e)
      Ok(x) => x
    }

  Ok(st1.push1(RefTypeValType(rt_out)))
}

fn typecheck_br_on_cast_fail(
  st: TcState,
  l: LabelIdx,
  op: CastOp,
  ht1: HeapType,
  ht2: HeapType,
) -> TcResult {
  let CastOp(n1, n2) = op
  let rt1 = HeapTypeRefType(n1, ht1)
  let rt2 = HeapTypeRefType(n2, ht2)

  if !rt1.validate(st.env) { return Err("invalid rt1") }
  if !rt2.validate(st.env) { return Err("invalid rt2") }

  let label_ts =
    match st.check_branch_args_present(l) {
      Err(e) => return Err(e)
      Ok(x) => x
    }
  if label_ts.length() == 0 { return Err("br_on_cast_fail label type too short") }

  let rt_label =
    match label_ts[label_ts.length() - 1] {
      RefTypeValType(r) => r
      _ => return Err("br_on_cast_fail label must end with a reftype")
    }

  if !Match::matches(rt2, rt1, st.env) { return Err("rt2 does not match rt1") }

  let rt_diff =
    match diff(rt1, rt2) {
      Err(e) => return Err(e)
      Ok(x) => x
    }

  if !Match::matches(rt_diff, rt_label, st.env) {
    return Err("rt1 \\ rt2 does not match label rt")
  }

  // pop rt1
  let st1 =
    match st.pop_expect(RefTypeValType(rt1)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  if st.reachable {
    let prefix = label_ts.sub(start=0, end=label_ts.length() - 1)
    let _ =
      match st1.pop_types(prefix.to_array()) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
  }

  Ok(st1.push1(RefTypeValType(rt2)))
}

fn typecheck_throw(st: TcState, idx: TagIdx) -> TcResult {
  let payload =
    match st.env.get_tag_payload(idx) {
      Err(e) => return Err(e)
      Ok(ts) => ts
    }

  // Pop payload values (in reverse order via pop_types)
  let st1 =
    match st.pop_types(payload) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // throw is stack-polymorphic: continuation is unreachable
  Ok(st1.set_unreachable())
}

fn typecheck_throw_ref(st: TcState) -> TcResult {
  let st1 =
    match st.pop_expect(ref_null_exn_valtype()) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st1.set_unreachable())
}

fn typecheck_catch_clause(st: TcState, c: Catch) -> Result[Unit, String] {
  match c {
    // catch x l: payload t* matches label
    Catch(tag, lab) => {
      let payload =
        match st.env.get_tag_payload(tag) {
          Err(e) => return Err(e)
          Ok(ts) => ts
        }

      let label_ts =
        match st.env.get_label_types(lab) {
          None => return Err("invalid label index in catch")
          Some(ts) => ts
        }

      if !Match::matches(payload, label_ts, st.env) {
        return Err("catch payload types do not match label types")
      }

      Ok(())
    }

    // catch_ref x l: payload t* plus (ref exn) matches label
    CatchRef(tag, lab) => {
      let payload =
        match st.env.get_tag_payload(tag) {
          Err(e) => return Err(e)
          Ok(ts) => ts
        }

      let want = append_valtype(payload, ref_exn_valtype())

      let label_ts =
        match st.env.get_label_types(lab) {
          None => return Err("invalid label index in catch_ref")
          Some(ts) => ts
        }

      if !Match::matches(want, label_ts, st.env) {
        return Err("catch_ref types (payload + ref exn) do not match label types")
      }

      Ok(())
    }

    // catch_all l: ε matches label  (i.e. empty vector ≤ label)
    CatchAll(lab) => {
      let label_ts =
        match st.env.get_label_types(lab) {
          None => return Err("invalid label index in catch_all")
          Some(ts) => ts
        }

      if !Match::matches([], label_ts, st.env) {
        return Err("catch_all requires empty result type to match label")
      }

      Ok(())
    }

    // catch_all_ref l: (ref exn) matches label
    CatchAllRef(lab) => {
      let label_ts =
        match st.env.get_label_types(lab) {
          None => return Err("invalid label index in catch_all_ref")
          Some(ts) => ts
        }

      let want = [ref_exn_valtype()]
      if !Match::matches(want, label_ts, st.env) {
        return Err("catch_all_ref requires (ref exn) to match label")
      }

      Ok(())
    }
  }
}

fn typecheck_try_table(st: TcState, bt: BlockType, catches: Array[Catch], body: Expr) -> TcResult {
  let (params, results) =
    match st.env.expand_blocktype(bt) { // assuming you made it a method
      Err(e) => return Err(e)
      Ok(x) => x
    }

  // consume params
  let st1 =
    match st.pop_types(params) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
  let base_len = st1.stack.length()

  // extend context with innermost label = results
  let env2 = st1.env.with_label(results)
  let st_body0 = TcState::{ env: env2, stack: st1.stack, reachable: st1.reachable }

  // body must typecheck under extended env
  let st_body =
    match body.typecheck(st_body0) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // validate all catch clauses under the SAME extended env (spec: C')
  let st_catch_ctx = TcState::{ env: env2, stack: st1.stack, reachable: st1.reachable }
  for c in catches {
    match typecheck_catch_clause(st_catch_ctx, c) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }

  // if reachable, enforce results on stack top
  let st2 =
    if st_body.reachable {
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

fn typecheck_table_copy(st: TcState, x: TableIdx, y: TableIdx) -> TcResult {
  let TableType(rt1, l1) =
    match st.env.get_table_type(x) {
      None => return Err("invalid dest table index")
      Some(tt) => tt
    }

  let TableType(rt2, l2) =
    match st.env.get_table_type(y) {
      None => return Err("invalid src table index")
      Some(tt) => tt
    }

  // require rt2 <: rt1
  if !Match::matches(rt2, rt1, st.env) {
    return Err("table.copy source elem type does not match dest elem type")
  }

  let at_len = min_addr(l1, l2)

  // Pop len, src, dst (LIFO), with types at_len, at2, at1
  let st1 =
    match st.pop_expect(addr_valtype(at_len)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  let st2 =
    match st1.pop_expect(addr_valtype(l2)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  let st3 =
    match st2.pop_expect(addr_valtype(l1)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st3)
}

fn typecheck_table_init(st: TcState, y: ElemIdx, x: TableIdx) -> TcResult {
  let TableType(rt1, l) =
    match st.env.get_table_type(x) {
      None => return Err("invalid table index")
      Some(tt) => tt
    }

  let elem =
    match st.env.get_elem(y) {
      None => return Err("invalid elem segment index")
      Some(e) => e
    }

  let rt2 = elem_reftype(elem)

  if !Match::matches(rt2, rt1, st.env) {
    return Err("table.init elem segment type does not match table element type")
  }

  // Pop: len:i32, src:i32, dst:at  (LIFO order)
  let st1 =
    match st.pop_expect(NumTypeValType(I32NumType)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  let st2 =
    match st1.pop_expect(NumTypeValType(I32NumType)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  let st3 =
    match st2.pop_expect(addr_valtype(l)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st3)
}

fn typecheck_table_fill(st: TcState, x: TableIdx) -> TcResult {
  let TableType(rt, lim) =
    match st.env.get_table_type(x) {
      None => return Err("invalid table index")
      Some(tt) => tt
    }

  // pop len : i32
  let st1 =
    match st.pop_expect(NumTypeValType(I32NumType)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // pop val : rt
  let st2 =
    match st1.pop_expect(RefTypeValType(rt)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  // pop start : at (derived from limits)
  let st3 =
    match st2.pop_expect(addr_valtype(lim)) {
      Err(e) => return Err(e)
      Ok(s) => s
    }

  Ok(st3)
}

fn typecheck_elem_drop(st: TcState, y: ElemIdx) -> TcResult {
  match st.env.get_elem(y) {
    None => Err("invalid elem segment index")
    Some(_) => Ok(st)
  }
}

pub impl Typecheck for Instruction with typecheck(self, st) {
  match self {
    Unreachable => Ok(TcState::{ env: st.env, stack: st.stack, reachable: false })
    Nop => Ok(st)

    I32Const(_) => Ok(st.push1(NumTypeValType(I32NumType)))
    I64Const(_) => Ok(st.push1(NumTypeValType(I64NumType)))
    F32Const(_) => Ok(st.push1(NumTypeValType(F32NumType)))
    F64Const(_) => Ok(st.push1(NumTypeValType(F64NumType)))

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
    
    Br(l) => typecheck_br(st, l)
    Block(bt, e) => typecheck_block(st, bt, e)
    If(bt, th, el) => typecheck_if(st, bt, th, el)
    BrIf(l) => typecheck_br_if(st, l)
    BrTable(ls, ldef) => typecheck_br_table(st, ls, ldef)
    BrOnNull(l) => typecheck_br_on_null(st, l)
    BrOnNonNull(l) => typecheck_br_on_non_null(st, l)
    BrOnCast(l, op, ht1, ht2) => typecheck_br_on_cast(st, l, op, ht1, ht2)
    BrOnCastFail(l, op, ht1, ht2) => typecheck_br_on_cast_fail(st, l, op, ht1, ht2)

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

    _ => Err("unimplemented")
  }
}
