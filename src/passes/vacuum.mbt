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
priv struct VQFuncSig {
  params : Array[ValType]
  results : Array[ValType]
}

///|
fn VQFuncSig::new(
  params : Array[ValType],
  results : Array[ValType],
) -> VQFuncSig {
  { params, results }
}

///|
fn vq_collect_func_sigs(mod : Module) -> Array[VQFuncSig] {
  let out : Array[VQFuncSig] = []
  let env = Env::new().with_module(mod)
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for tidx in type_idxs {
        match env.resolve_functype(tidx) {
          Some(FuncType(params, results)) =>
            out.push(VQFuncSig::new(params, results))
          None => out.push(VQFuncSig::new([], []))
        }
      }
    None => ()
  }
  out
}

///|
fn vq_type_of(instr : TInstr, env : Env) -> ValType? {
  lcs_infer_tinstr_type(instr, env)
}

///|
fn vq_instr_hash_u64(instr : TInstr) -> UInt64 {
  instr.hash().reinterpret_as_uint().to_uint64()
}

///|
fn vq_type_of_cached(
  instr : TInstr,
  env : Env,
  type_cache : Map[UInt64, ValType?],
) -> ValType? {
  let h = vq_instr_hash_u64(instr)
  match type_cache.get(h) {
    Some(v) => v
    None => {
      let v = vq_type_of(instr, env)
      type_cache[h] = v
      v
    }
  }
}

///|
fn vq_has_unremovable_effects_cached(
  instr : TInstr,
  effect_cache : Map[UInt64, Bool],
) -> Bool {
  let h = vq_instr_hash_u64(instr)
  match effect_cache.get(h) {
    Some(v) => v
    None => {
      let v = lcs_collect_effects(instr).has_unremovable_side_effects()
      effect_cache[h] = v
      v
    }
  }
}

///|
fn vq_has_unremovable_shallow_effects_cached(
  instr : TInstr,
  shallow_effect_cache : Map[UInt64, Bool],
) -> Bool {
  let h = vq_instr_hash_u64(instr)
  match shallow_effect_cache.get(h) {
    Some(v) => v
    None => {
      let v = lcs_collect_shallow_effects(instr).has_unremovable_side_effects()
      shallow_effect_cache[h] = v
      v
    }
  }
}

///|
fn vq_same_type(a : ValType?, b : ValType?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => x == y
    (None, None) => true
    _ => false
  }
}

///|
fn vq_block_result_types(bt : BlockType, env : Env) -> Array[ValType] {
  match env.expand_blocktype(bt) {
    Ok((_, results)) => results
    Err(_) => []
  }
}

///|
fn vq_block_result_type(bt : BlockType, env : Env) -> ValType? {
  match vq_block_result_types(bt, env) {
    [vt] => Some(vt)
    _ => None
  }
}

///|
fn vq_label_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn vq_label_from_int(idx : Int) -> LabelIdx {
  LabelIdx::new(idx.reinterpret_as_uint())
}

///|
fn vq_adjust_label_for_collapsed_wrapper(
  label : LabelIdx,
  depth : Int,
) -> LabelIdx {
  let curr = vq_label_to_int(label)
  if curr >= depth {
    vq_label_from_int(curr - 1)
  } else {
    label
  }
}

///|
fn vq_walk_tinstruction_with_depth(
  transformer : ModuleTransformer[Int],
  depth : Int,
  instr : TInstr,
) -> TransformerResult[Int, TInstr] {
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(e) => return Err(e)
      }
      let next_instr = TInstr::block(bt, next_body)
      if next_instr == instr {
        unchanged()
      } else {
        change(depth, next_instr)
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(e) => return Err(e)
      }
      let next_instr = TInstr::loop_(bt, next_body)
      if next_instr == instr {
        unchanged()
      } else {
        change(depth, next_instr)
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = match transformer.walk_tinstruction(depth, cond) {
        Ok(Some((_, out))) => out
        Ok(None) => cond
        Err(e) => return Err(e)
      }
      let next_then = match transformer.walk_texpr(depth + 1, then_body) {
        Ok(Some((_, out))) => out
        Ok(None) => then_body
        Err(e) => return Err(e)
      }
      let next_else = match else_body {
        Some(other) =>
          match transformer.walk_texpr(depth + 1, other) {
            Ok(Some((_, out))) => Some(out)
            Ok(None) => Some(other)
            Err(e) => return Err(e)
          }
        None => None
      }
      let next_instr = TInstr::if_(bt, next_cond, next_then, next_else)
      if next_instr == instr {
        unchanged()
      } else {
        change(depth, next_instr)
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let next_catches = match
        transformer.walk_array(
          depth + 1,
          ModuleTransformer::walk_catch,
          catches,
        ) {
        Ok(Some((_, out))) => out
        Ok(None) => catches
        Err(e) => return Err(e)
      }
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(e) => return Err(e)
      }
      let next_instr = TInstr::try_table(bt, next_catches, next_body)
      if next_instr == instr {
        unchanged()
      } else {
        change(depth, next_instr)
      }
    }
    _ => transformer.walk_tinstruction_default(depth, instr)
  }
}

///|
fn vq_rebase_labels_for_collapsed_wrapper(instr : TInstr) -> TInstr {
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      let next = vq_adjust_label_for_collapsed_wrapper(label, depth)
      if next == label {
        unchanged()
      } else {
        change(depth, next)
      }
    })
    .on_tinstruction_evt(fn(self, depth, curr) {
      vq_walk_tinstruction_with_depth(self, depth, curr)
    })
  match pass.walk_tinstruction(0, instr) {
    Ok(Some((_, out))) => out
    Ok(None) => instr
    Err(e) => abort("vacuum label rebase failed: \{e}")
  }
}

///|
fn vq_texpr_result_type(
  expr : TExpr,
  env : Env,
  type_cache : Map[UInt64, ValType?],
) -> ValType? {
  let { instrs: items, .. } = expr
  if items.is_empty() {
    None
  } else {
    vq_type_of_cached(items[items.length() - 1], env, type_cache)
  }
}

///|
fn vq_is_nop_texpr(expr : TExpr) -> Bool {
  let { instrs: items, .. } = expr
  if items.is_empty() {
    return true
  }
  for item in items {
    match item.kind {
      TInstrKind::TNop => ()
      _ => return false
    }
  }
  true
}

///|
fn vq_texpr_is_unreachable(expr : TExpr) -> Bool {
  let { instrs: items, .. } = expr
  for item in items {
    if is_unreachable_instr(item) {
      return true
    }
  }
  false
}

///|
fn vq_is_explicit_unreachable_instr(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TUnreachable => true
    _ => false
  }
}

///|
fn vq_wrap_texpr(
  expr : TExpr,
  env : Env,
  type_cache : Map[UInt64, ValType?],
) -> TInstr {
  let { instrs: items, .. } = expr
  if items.length() == 0 {
    return TInstr::nop()
  }
  if items.length() == 1 {
    return items[0]
  }
  match vq_texpr_result_type(expr, env, type_cache) {
    Some(vt) => TInstr::block(BlockType::val_type(vt), expr)
    None => TInstr::block(BlockType::void_(), expr)
  }
}

///|
fn vq_drop_texpr_value(
  expr : TExpr,
  env : Env,
  type_cache : Map[UInt64, ValType?],
) -> TExpr {
  let wrapped = vq_wrap_texpr(expr, env, type_cache)
  match vq_type_of_cached(wrapped, env, type_cache) {
    Some(_) => TExpr::new([TInstr::drop(wrapped)])
    None => TExpr::new([wrapped])
  }
}

///|
fn vq_must_keep_unused_parent(
  curr : TInstr,
  shallow_effect_cache : Map[UInt64, Bool],
) -> Bool {
  vq_has_unremovable_shallow_effects_cached(curr, shallow_effect_cache)
}

///|
fn vq_children_with_effects(
  curr : TInstr,
  effect_cache : Map[UInt64, Bool],
) -> Array[TInstr] {
  let out : Array[TInstr] = []
  for child in eval_children(curr) {
    if vq_has_unremovable_effects_cached(child, effect_cache) {
      out.push(child)
    }
  }
  out
}

///|
fn vq_get_dropped_children_and_append(
  curr : TInstr,
  env : Env,
  dummy : TInstr,
  type_cache : Map[UInt64, ValType?],
  effect_cache : Map[UInt64, Bool],
) -> TInstr {
  let items : Array[TInstr] = []
  for child in vq_children_with_effects(curr, effect_cache) {
    match vq_type_of_cached(child, env, type_cache) {
      Some(_) => items.push(TInstr::drop(child))
      None => items.push(child)
    }
  }
  items.push(dummy)
  match vq_type_of_cached(dummy, env, type_cache) {
    Some(vt) => TInstr::block(BlockType::val_type(vt), TExpr::new(items))
    None => TInstr::block(BlockType::void_(), TExpr::new(items))
  }
}

///|
fn vq_take_budget(budget : Ref[Int]) -> Bool {
  let remaining = budget.val
  if remaining <= 0 {
    false
  } else {
    budget.update(fn(i) { i - 1 })
    true
  }
}

///|
fn vq_optimize(
  instr : TInstr,
  result_used : Bool,
  type_matters : Bool,
  env : Env,
  budget : Ref[Int],
  type_cache : Map[UInt64, ValType?],
  effect_cache : Map[UInt64, Bool],
  shallow_effect_cache : Map[UInt64, Bool],
) -> TInstr? {
  if !vq_take_budget(budget) {
    return Some(instr)
  }
  let initial_type = vq_type_of_cached(instr, env, type_cache)
  let mut type_matters = type_matters
  if initial_type is None {
    type_matters = true
  }
  if is_unreachable_instr(instr) {
    return Some(instr)
  }
  if result_used {
    return Some(instr)
  }

  let mut prev = instr
  let mut curr = instr
  for _ in 0..<64 {
    let curr_type = vq_type_of_cached(curr, env, type_cache)
    if type_matters && !vq_same_type(curr_type, initial_type) {
      return Some(prev)
    }
    prev = curr
    match curr.kind {
      TInstrKind::TDrop(_)
      | TInstrKind::TBlock(_, _)
      | TInstrKind::TIf(_, _, _, _)
      | TInstrKind::TLoop(_, _)
      | TInstrKind::TTryTable(_, _, _) => return Some(curr)
      _ => ()
    }
    if vq_must_keep_unused_parent(curr, shallow_effect_cache) {
      return Some(curr)
    }
    let children = vq_children_with_effects(curr, effect_cache)
    if children.is_empty() {
      return None
    }
    if children.length() == 1 {
      curr = children[0]
      if is_unreachable_instr(curr) {
        return Some(curr)
      }
      continue
    }
    match curr_type {
      Some(vt) =>
        match af_make_zero(vt) {
          Some(dummy) =>
            return Some(
              vq_get_dropped_children_and_append(
                curr, env, dummy, type_cache, effect_cache,
              ),
            )
          None => return Some(curr)
        }
      None => return Some(curr)
    }
  }
  Some(curr)
}

///|
priv struct VQSequenceResult {
  items : Array[TInstr]
  changed : Bool
}

///|
fn VQSequenceResult::new(
  items : Array[TInstr],
  changed : Bool,
) -> VQSequenceResult {
  { items, changed }
}

///|
priv struct VQStackSig {
  required : Int
  produced : Int
  reachable : Bool
}

///|
fn VQStackSig::new(
  required : Int,
  produced : Int,
  reachable : Bool,
) -> VQStackSig {
  { required, produced, reachable }
}

///|
fn vq_same_stack_sig(a : VQStackSig, b : VQStackSig) -> Bool {
  a.required == b.required &&
  a.produced == b.produced &&
  a.reachable == b.reachable
}

///|
fn vq_rewrite_preserves_type_and_stack_sig(
  before : TInstr,
  after : TInstr,
  env : Env,
) -> Bool {
  if !vq_same_type(vq_type_of(before, env), vq_type_of(after, env)) {
    return false
  }
  match (vq_stack_sig_instr(before, env), vq_stack_sig_instr(after, env)) {
    (Some(before_sig), Some(after_sig)) =>
      vq_same_stack_sig(before_sig, after_sig)
    _ => false
  }
}

///|
fn vq_rewrite_preserves_stack_sig(
  before : TInstr,
  after : TInstr,
  env : Env,
) -> Bool {
  match (vq_stack_sig_instr(before, env), vq_stack_sig_instr(after, env)) {
    (Some(before_sig), Some(after_sig)) =>
      vq_same_stack_sig(before_sig, after_sig)
    _ => true
  }
}

///|
fn vq_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn vq_nonneg_int(i : Int) -> Int {
  if i > 0 {
    i
  } else {
    0
  }
}

///|
fn vq_stack_need_before(effect : VQStackSig, need_after : Int) -> Int {
  if !effect.reachable {
    effect.required
  } else {
    vq_max_int(effect.required, vq_nonneg_int(need_after - effect.produced))
  }
}

///|
fn vq_stack_seq(a : VQStackSig, b : VQStackSig) -> VQStackSig {
  if !a.reachable {
    a
  } else {
    let required = vq_max_int(
      a.required,
      vq_nonneg_int(b.required - a.produced),
    )
    if !b.reachable {
      VQStackSig::new(required, 0, false)
    } else {
      VQStackSig::new(required, a.produced + b.produced, true)
    }
  }
}

///|
fn vq_stack_sig_pop_push(
  child_sig : VQStackSig,
  pop_count : Int,
  push_count : Int,
) -> VQStackSig {
  if !child_sig.reachable {
    child_sig
  } else {
    VQStackSig::new(
      vq_max_int(
        child_sig.required,
        vq_nonneg_int(pop_count - child_sig.produced),
      ),
      child_sig.produced - pop_count + push_count,
      true,
    )
  }
}

///|
fn vq_stack_sig_terminate(
  child_sig : VQStackSig,
  pop_count : Int,
) -> VQStackSig {
  if !child_sig.reachable {
    child_sig
  } else {
    VQStackSig::new(
      vq_max_int(
        child_sig.required,
        vq_nonneg_int(pop_count - child_sig.produced),
      ),
      0,
      false,
    )
  }
}

///|
fn vq_stack_sig_list(items : Array[TInstr], env : Env) -> VQStackSig? {
  let mut acc = VQStackSig::new(0, 0, true)
  for item in items {
    match vq_stack_sig_instr(item, env) {
      Some(sig) => {
        acc = vq_stack_seq(acc, sig)
        if !acc.reachable {
          break
        }
      }
      None => return None
    }
  }
  Some(acc)
}

///|
fn vq_stack_sig_if(
  cond_sig : VQStackSig,
  then_sig : VQStackSig,
  else_sig : VQStackSig,
) -> VQStackSig {
  if !cond_sig.reachable {
    return cond_sig
  }
  let branch_required = vq_max_int(then_sig.required, else_sig.required)
  let branch_reachable = then_sig.reachable || else_sig.reachable
  let branch_produced = if then_sig.reachable && else_sig.reachable {
    if then_sig.produced < else_sig.produced {
      then_sig.produced
    } else {
      else_sig.produced
    }
  } else if then_sig.reachable {
    then_sig.produced
  } else if else_sig.reachable {
    else_sig.produced
  } else {
    0
  }
  let need_after_cond = 1 + branch_required
  VQStackSig::new(
    vq_max_int(
      cond_sig.required,
      vq_nonneg_int(need_after_cond - cond_sig.produced),
    ),
    branch_produced,
    branch_reachable,
  )
}

///|
fn vq_stack_sig_instr(instr : TInstr, env : Env) -> VQStackSig? {
  match instr.kind {
    TInstrKind::TNop => Some(VQStackSig::new(0, 0, true))
    TInstrKind::TUnreachable => Some(VQStackSig::new(0, 0, false))
    TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_) => Some(VQStackSig::new(0, 1, true))
    TInstrKind::TDrop(value)
    | TInstrKind::TLocalSet(_, value)
    | TInstrKind::TGlobalSet(_, value) =>
      vq_stack_sig_instr(value, env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TLocalTee(_, value) =>
      vq_stack_sig_instr(value, env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 1)
      })
    TInstrKind::TUnary(_, value)
    | TInstrKind::TLoad(_, _, value)
    | TInstrKind::TRefIsNull(value)
    | TInstrKind::TRefAsNonNull(value)
    | TInstrKind::TAnyConvertExtern(value)
    | TInstrKind::TExternConvertAny(value)
    | TInstrKind::TI31GetS(value)
    | TInstrKind::TI31GetU(value)
    | TInstrKind::TArrayLen(value) =>
      vq_stack_sig_instr(value, env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 1)
      })
    TInstrKind::TBinary(_, left, right) | TInstrKind::TRefEq(left, right) =>
      vq_stack_sig_list([left, right], env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 2, 1)
      })
    TInstrKind::TStore(_, _, addr, value) =>
      vq_stack_sig_list([addr, value], env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 2, 0)
      })
    TInstrKind::TSelect(_, cond, if_true, if_false) =>
      vq_stack_sig_list([if_true, if_false, cond], env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 3, 1)
      })
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => vq_stack_sig_list(body.instrs, env)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      let else_sig = match else_body {
        Some(other) => vq_stack_sig_list(other.instrs, env)
        None => Some(VQStackSig::new(0, 0, true))
      }
      match
        (
          vq_stack_sig_instr(cond, env),
          vq_stack_sig_list(then_body.instrs, env),
          else_sig,
        ) {
        (Some(cond_sig), Some(then_sig), Some(other_sig)) =>
          Some(vq_stack_sig_if(cond_sig, then_sig, other_sig))
        _ => None
      }
    }
    TInstrKind::TCall(func_idx, args) =>
      match
        (vq_stack_sig_list(args, env), env.get_functype_by_funcidx(func_idx)) {
        (Some(sig), Some(FuncType(params, results))) =>
          Some(vq_stack_sig_pop_push(sig, params.length(), results.length()))
        _ => None
      }
    TInstrKind::TCallIndirect(type_idx, _, args, callee)
    | TInstrKind::TCallRef(type_idx, args, callee) =>
      match
        (
          vq_stack_sig_list(args + [callee], env),
          env.resolve_functype(type_idx),
        ) {
        (Some(sig), Some(FuncType(params, results))) =>
          Some(
            vq_stack_sig_pop_push(sig, params.length() + 1, results.length()),
          )
        _ => None
      }
    TInstrKind::TReturn(values) | TInstrKind::TThrow(_, values) =>
      vq_stack_sig_list(values, env).map(fn(sig) {
        vq_stack_sig_terminate(sig, 0)
      })
    TInstrKind::TThrowRef(value) =>
      vq_stack_sig_instr(value, env).map(fn(sig) {
        vq_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TBr(_, values) =>
      vq_stack_sig_list(values, env).map(fn(sig) {
        vq_stack_sig_terminate(sig, 0)
      })
    TInstrKind::TBrIf(_, cond, values) =>
      vq_stack_sig_list(values + [cond], env).map(fn(sig) {
        vq_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TBrTable(_, _, index, values) =>
      vq_stack_sig_list(values + [index], env).map(fn(sig) {
        vq_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TReturnCall(func_idx, args) =>
      match
        (vq_stack_sig_list(args, env), env.get_functype_by_funcidx(func_idx)) {
        (Some(sig), Some(FuncType(params, _))) =>
          Some(vq_stack_sig_terminate(sig, params.length()))
        _ => None
      }
    TInstrKind::TReturnCallIndirect(type_idx, _, args, callee)
    | TInstrKind::TReturnCallRef(type_idx, args, callee) =>
      match
        (
          vq_stack_sig_list(args + [callee], env),
          env.resolve_functype(type_idx),
        ) {
        (Some(sig), Some(FuncType(params, _))) =>
          Some(vq_stack_sig_terminate(sig, params.length() + 1))
        _ => None
      }
    _ => None
  }
}

///|
fn vq_required_prefixes(
  items : Array[TInstr],
  env : Env,
  terminal_need : Int,
) -> Array[Int?] {
  let size = items.length()
  let needs : Array[Int?] = []
  for _ in 0..<=size {
    needs.push(None)
  }
  needs[size] = Some(terminal_need)
  if size == 0 {
    return needs
  }
  for i = size - 1; i >= 0; i = i - 1 {
    match (vq_stack_sig_instr(items[i], env), needs[i + 1]) {
      (Some(sig), Some(need_after)) =>
        needs[i] = Some(vq_stack_need_before(sig, need_after))
      _ => needs[i] = None
    }
  }
  needs
}

///|
fn vq_has_ambient_stack_terminator(items : Array[TInstr]) -> Bool {
  for item in items {
    match item.kind {
      TInstrKind::TBr(_, _)
      | TInstrKind::TBrIf(_, _, _)
      | TInstrKind::TBrTable(_, _, _, _)
      | TInstrKind::TReturn(_)
      | TInstrKind::TThrow(_, _)
      | TInstrKind::TThrowRef(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn vq_optimize_sequence(
  items : Array[TInstr],
  env : Env,
  result_types : Array[ValType],
  result_used : Bool,
  budget : Ref[Int],
  type_cache : Map[UInt64, ValType?],
  effect_cache : Map[UInt64, Bool],
  shallow_effect_cache : Map[UInt64, Bool],
) -> VQSequenceResult {
  let out : Array[TInstr] = []
  let mut changed = false
  let mut preserve_next_unreachable = false
  let size = items.length()
  let multi_value_results = result_types.length() > 1
  let has_ambient_stack_terminator = vq_has_ambient_stack_terminator(items)
  let has_sequence_control_transfer = has_ambient_stack_terminator ||
    vq_texpr_has_control_transfer(TExpr::new(items))
  let prefix_needs = vq_required_prefixes(
    items,
    env,
    if result_used {
      result_types.length()
    } else {
      0
    },
  )
  for i = 0; i < size; i = i + 1 {
    let child = items[i]
    if preserve_next_unreachable {
      preserve_next_unreachable = false
      if vq_is_explicit_unreachable_instr(child) {
        out.push(child)
        if i + 1 < size {
          changed = true
        }
        break
      }
    }
    let keeps_sequence_result = i == size - 1 && result_types.length() > 0
    let used = if multi_value_results {
      true
    } else {
      i == size - 1 && result_used
    }
    let mut optimized = vq_process_instr(
      child, env, used, true, budget, type_cache, effect_cache, shallow_effect_cache,
    )
    if optimized is None {
      if multi_value_results {
        optimized = Some(child)
      } else if keeps_sequence_result {
        match result_types {
          [vt] =>
            match af_make_zero(vt) {
              Some(zero) => optimized = Some(zero)
              None => optimized = Some(child)
            }
          _ => ()
        }
      } else if is_unreachable_instr(child) {
        optimized = Some(child)
      }
    }
    match optimized {
      None =>
        if has_ambient_stack_terminator {
          match
            (
              vq_type_of_cached(child, env, type_cache),
              vq_stack_sig_instr(child, env),
            ) {
            (Some(_), _) => out.push(child)
            (_, Some(sig)) if !sig.reachable => out.push(child)
            _ => changed = true
          }
        } else {
          match
            (
              vq_stack_sig_instr(child, env),
              prefix_needs[i],
              prefix_needs[i + 1],
            ) {
            (Some(sig), Some(need_before), Some(need_after)) =>
              if !sig.reachable || need_before < need_after {
                out.push(child)
              } else {
                changed = true
              }
            _ =>
              match
                (
                  vq_type_of_cached(child, env, type_cache),
                  vq_stack_sig_instr(child, env),
                ) {
                (Some(_), _) => out.push(child)
                (_, Some(sig)) if !sig.reachable => out.push(child)
                _ => changed = true
              }
          }
        }
      Some(next) => {
        if next != child {
          if has_sequence_control_transfer &&
            child.kind is TInstrKind::TDrop(_) &&
            next.kind is TInstrKind::TNop {
            out.push(child)
            continue
          }
          if has_ambient_stack_terminator {
            let mut preserves_stack_shape = true
            match
              (vq_stack_sig_instr(child, env), vq_stack_sig_instr(next, env)) {
              (Some(before), Some(after)) =>
                if !vq_same_stack_sig(before, after) {
                  preserves_stack_shape = false
                }
              _ => ()
            }
            let preserves_type = vq_same_type(
              vq_type_of_cached(child, env, type_cache),
              vq_type_of_cached(next, env, type_cache),
            )
            if !preserves_stack_shape || !preserves_type {
              out.push(child)
              continue
            }
          }
          changed = true
        }
        out.push(next)
        if is_unreachable_instr(next) {
          if i + 1 < size && vq_is_explicit_unreachable_instr(items[i + 1]) {
            preserve_next_unreachable = true
            continue
          }
          if i + 1 < size {
            changed = true
          }
          break
        }
      }
    }
  }
  VQSequenceResult::new(out, changed)
}

///|
fn vq_optimize_texpr(
  expr : TExpr,
  env : Env,
  result_types : Array[ValType],
  result_used : Bool,
  budget : Ref[Int],
  type_cache : Map[UInt64, ValType?],
  effect_cache : Map[UInt64, Bool],
  shallow_effect_cache : Map[UInt64, Bool],
) -> TExpr {
  let { instrs: items, .. } = expr
  let sequence = vq_optimize_sequence(
    items, env, result_types, result_used, budget, type_cache, effect_cache, shallow_effect_cache,
  )
  TExpr::new(sequence.items)
}

///|
fn vq_simplify_block_to_contents(
  bt : BlockType,
  body : TExpr,
  env : Env,
  type_cache : Map[UInt64, ValType?],
) -> TInstr {
  let result_types = vq_block_result_types(bt, env)
  if has_break_to_depth_in_texpr(body, 0) {
    return TInstr::block(bt, body)
  }
  let { instrs: items, .. } = body
  if items.length() == 0 {
    if !result_types.is_empty() {
      return TInstr::block(bt, body)
    }
    return TInstr::nop()
  }
  if items.length() == 1 {
    let only = items[0]
    match result_types {
      [vt] =>
        match vq_type_of_cached(only, env, type_cache) {
          Some(t) if t == vt =>
            return vq_rebase_labels_for_collapsed_wrapper(only)
          _ => ()
        }
      [] =>
        if vq_type_of_cached(only, env, type_cache) is None ||
          is_unreachable_instr(only) {
          return vq_rebase_labels_for_collapsed_wrapper(only)
        }
      _ =>
        if is_unreachable_instr(only) {
          return vq_rebase_labels_for_collapsed_wrapper(only)
        }
    }
  }
  TInstr::block(bt, body)
}

///|
fn vq_texpr_throws(expr : TExpr) -> Bool {
  let mut throws = false
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr.kind {
      TInstrKind::TThrow(_, _)
      | TInstrKind::TThrowRef(_)
      | TInstrKind::TCall(_, _)
      | TInstrKind::TCallIndirect(_, _, _, _)
      | TInstrKind::TCallRef(_, _, _)
      | TInstrKind::TReturnCall(_, _)
      | TInstrKind::TReturnCallIndirect(_, _, _, _)
      | TInstrKind::TReturnCallRef(_, _, _) => throws = true
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), expr))
  throws
}

///|
fn vq_texpr_has_control_transfer(expr : TExpr) -> Bool {
  let mut has_control_transfer = false
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr.kind {
      TInstrKind::TBr(_, _)
      | TInstrKind::TBrIf(_, _, _)
      | TInstrKind::TBrTable(_, _, _, _)
      | TInstrKind::TReturn(_)
      | TInstrKind::TReturnCall(_, _)
      | TInstrKind::TReturnCallIndirect(_, _, _, _)
      | TInstrKind::TReturnCallRef(_, _, _)
      | TInstrKind::TThrow(_, _)
      | TInstrKind::TThrowRef(_)
      | TInstrKind::TUnreachable => has_control_transfer = true
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), expr))
  has_control_transfer
}

///|
fn vq_texpr_has_unremovable_side_effects(
  expr : TExpr,
  effect_cache : Map[UInt64, Bool],
) -> Bool {
  let { instrs: items, .. } = expr
  for item in items {
    if vq_has_unremovable_effects_cached(item, effect_cache) {
      return true
    }
  }
  false
}

///|
fn vq_process_child_preserving_stack_sig(
  child : TInstr,
  env : Env,
  budget : Ref[Int],
  type_cache : Map[UInt64, ValType?],
  effect_cache : Map[UInt64, Bool],
  shallow_effect_cache : Map[UInt64, Bool],
) -> TInstr {
  let next_child = match
    vq_process_instr(
      child, env, true, true, budget, type_cache, effect_cache, shallow_effect_cache,
    ) {
    Some(next) => next
    None => return child
  }
  if next_child == child {
    return child
  }
  match (vq_stack_sig_instr(child, env), vq_stack_sig_instr(next_child, env)) {
    (Some(before), Some(after)) if vq_same_stack_sig(before, after) =>
      next_child
    _ => child
  }
}

///|
fn vq_process_instr(
  instr : TInstr,
  env : Env,
  result_used : Bool,
  type_matters : Bool,
  budget : Ref[Int],
  type_cache : Map[UInt64, ValType?],
  effect_cache : Map[UInt64, Bool],
  shallow_effect_cache : Map[UInt64, Bool],
) -> TInstr? {
  if !vq_take_budget(budget) {
    return Some(instr)
  }
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let result_types = vq_block_result_types(bt, env)
      let next_body = vq_optimize_texpr(
        body,
        env,
        result_types,
        !result_types.is_empty(),
        budget,
        type_cache,
        effect_cache,
        shallow_effect_cache,
      )
      Some(vq_simplify_block_to_contents(bt, next_body, env, type_cache))
    }
    TInstrKind::TIf(bt, condition, then_body, else_body) => {
      let next_condition = vq_process_child_preserving_stack_sig(
        condition, env, budget, type_cache, effect_cache, shallow_effect_cache,
      )
      let arm_result_types = vq_block_result_types(bt, env)
      let next_then = vq_optimize_texpr(
        then_body,
        env,
        arm_result_types,
        !arm_result_types.is_empty(),
        budget,
        type_cache,
        effect_cache,
        shallow_effect_cache,
      )
      let next_else = match else_body {
        Some(other) =>
          Some(
            vq_optimize_texpr(
              other,
              env,
              arm_result_types,
              !arm_result_types.is_empty(),
              budget,
              type_cache,
              effect_cache,
              shallow_effect_cache,
            ),
          )
        None => None
      }

      match next_condition.kind {
        TInstrKind::TI32Const(I32(v)) =>
          if v != 0 {
            return Some(
              vq_simplify_block_to_contents(bt, next_then, env, type_cache),
            )
          } else {
            return Some(
              match next_else {
                Some(other) =>
                  vq_simplify_block_to_contents(bt, other, env, type_cache)
                None => TInstr::nop()
              },
            )
          }
        TInstrKind::TI64Const(I64(v)) =>
          if v != 0L {
            return Some(
              vq_simplify_block_to_contents(bt, next_then, env, type_cache),
            )
          } else {
            return Some(
              match next_else {
                Some(other) =>
                  vq_simplify_block_to_contents(bt, other, env, type_cache)
                None => TInstr::nop()
              },
            )
          }
        _ => ()
      }

      if is_unreachable_instr(next_condition) {
        return Some(next_condition)
      }

      match next_else {
        Some(other) => {
          if arm_result_types.is_empty() && vq_is_nop_texpr(other) {
            return Some(TInstr::if_(bt, next_condition, next_then, None))
          }
          if arm_result_types.is_empty() &&
            vq_is_nop_texpr(next_then) &&
            !vq_texpr_has_control_transfer(other) {
            let before = TInstr::if_(bt, next_condition, next_then, Some(other))
            match vq_type_of_cached(next_condition, env, type_cache) {
              Some(vt) if vt == ValType::i32() => {
                let after = TInstr::if_(
                  bt,
                  TInstr::unary(UnaryOp::i32_eqz(), next_condition),
                  other,
                  None,
                )
                if vq_rewrite_preserves_type_and_stack_sig(before, after, env) {
                  return Some(after)
                }
              }
              _ => ()
            }
            return Some(before)
          }
          match (next_then.instrs, other.instrs) {
            (
              [{ kind: TInstrKind::TDrop(left), .. }],
              [{ kind: TInstrKind::TDrop(right), .. }],
            ) =>
              match
                (
                  vq_type_of_cached(left, env, type_cache),
                  vq_type_of_cached(right, env, type_cache),
                ) {
                (Some(lt), Some(rt)) if lt == rt =>
                  Some(
                    TInstr::drop(
                      TInstr::if_(
                        BlockType::val_type(lt),
                        next_condition,
                        TExpr::new([left]),
                        Some(TExpr::new([right])),
                      ),
                    ),
                  )
                _ =>
                  Some(TInstr::if_(bt, next_condition, next_then, Some(other)))
              }
            _ => Some(TInstr::if_(bt, next_condition, next_then, Some(other)))
          }
        }
        None =>
          if vq_is_nop_texpr(next_then) {
            Some(TInstr::drop(next_condition))
          } else {
            Some(TInstr::if_(bt, next_condition, next_then, None))
          }
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let result_types = vq_block_result_types(bt, env)
      let next_body = vq_optimize_texpr(
        body,
        env,
        result_types,
        !result_types.is_empty(),
        budget,
        type_cache,
        effect_cache,
        shallow_effect_cache,
      )
      if result_types.is_empty() && vq_is_nop_texpr(next_body) {
        Some(TInstr::nop())
      } else {
        Some(TInstr::loop_(bt, next_body))
      }
    }
    TInstrKind::TDrop(value) => {
      let next_value = match
        vq_process_instr(
          value, env, false, false, budget, type_cache, effect_cache, shallow_effect_cache,
        ) {
        Some(v) => v
        None => return Some(TInstr::nop())
      }
      let dropped = TInstr::drop(next_value)
      if !vq_rewrite_preserves_stack_sig(instr, dropped, env) {
        return Some(instr)
      }
      match next_value.kind {
        TInstrKind::TDrop(inner) => return Some(TInstr::drop(inner))
        TInstrKind::TLocalTee(idx, inner) =>
          return Some(TInstr::local_set(idx, inner))
        _ => ()
      }
      if !vq_has_unremovable_effects_cached(dropped, effect_cache) {
        return Some(TInstr::nop())
      }

      match next_value.kind {
        TInstrKind::TBlock(bt, body) => {
          let { instrs: items, .. } = body
          if items.length() > 0 {
            let last = items[items.length() - 1]
            match
              (
                vq_block_result_type(bt, env),
                vq_type_of_cached(last, env, type_cache),
              ) {
              (Some(block_vt), Some(last_vt)) if block_vt == last_vt =>
                match
                  vq_optimize(
                    last, false, false, env, budget, type_cache, effect_cache, shallow_effect_cache,
                  ) {
                  None =>
                    if !has_break_to_depth_in_texpr(body, 0) {
                      let next_items = items.copy()
                      ignore(next_items.pop())
                      if next_items.length() > 1 {
                        return Some(
                          TInstr::block(
                            BlockType::void_(),
                            TExpr::new(next_items),
                          ),
                        )
                      }
                      if next_items.length() == 1 {
                        return Some(
                          vq_rebase_labels_for_collapsed_wrapper(next_items[0]),
                        )
                      }
                      return Some(TInstr::nop())
                    }
                  Some(_) => ()
                }
              _ => ()
            }
          }
        }
        _ => ()
      }

      match next_value.kind {
        TInstrKind::TIf(bt, cond, then_body, Some(other_body)) => {
          let if_type = vq_block_result_type(bt, env)
          match if_type {
            Some(_) =>
              if vq_texpr_is_unreachable(then_body) &&
                vq_texpr_result_type(other_body, env, type_cache) is Some(_) {
                return Some(
                  TInstr::if_(
                    BlockType::void_(),
                    cond,
                    then_body,
                    Some(vq_drop_texpr_value(other_body, env, type_cache)),
                  ),
                )
              } else if vq_texpr_is_unreachable(other_body) &&
                vq_texpr_result_type(then_body, env, type_cache) is Some(_) {
                return Some(
                  TInstr::if_(
                    BlockType::void_(),
                    cond,
                    vq_drop_texpr_value(then_body, env, type_cache),
                    Some(other_body),
                  ),
                )
              }
            None => ()
          }
        }
        _ => ()
      }
      Some(dropped)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let result_types = vq_block_result_types(bt, env)
      let next_body = vq_optimize_texpr(
        body,
        env,
        result_types,
        !result_types.is_empty(),
        budget,
        type_cache,
        effect_cache,
        shallow_effect_cache,
      )
      if !vq_texpr_throws(next_body) {
        Some(vq_simplify_block_to_contents(bt, next_body, env, type_cache))
      } else {
        Some(TInstr::try_table(bt, catches, next_body))
      }
    }
    _ => {
      let children = eval_children(instr)
      if children.is_empty() {
        return vq_optimize(
          instr, result_used, type_matters, env, budget, type_cache, effect_cache,
          shallow_effect_cache,
        )
      }
      let next_children : Array[TInstr] = []
      for child in children {
        next_children.push(
          vq_process_child_preserving_stack_sig(
            child, env, budget, type_cache, effect_cache, shallow_effect_cache,
          ),
        )
      }
      let rebuilt = mb_rebuild_non_control(instr, next_children)
      vq_optimize(
        rebuilt, result_used, type_matters, env, budget, type_cache, effect_cache,
        shallow_effect_cache,
      )
    }
  }
}

///|
fn vq_optimize_function(
  mod : Module,
  func : Func,
  sig : VQFuncSig,
  ordinal : Int,
  trace : (String) -> Unit,
  trace_all_funcs : Bool,
) -> (Func, Bool) {
  match func {
    Func(_) => {
      if trace_all_funcs {
        trace("func[\{ordinal}] vacuum skip non-typed-func")
      }
      (func, false)
    }
    TFunc(tfunc_params, locals, body) => {
      let function_locals = match
        FunctionLocals::from_typed_func_for_pass(
          sig.params,
          tfunc_params,
          locals,
        ) {
        Ok(ls) => ls
        Err(e) => abort("vacuum vq_optimize_function: \{e}")
      }
      let all_locals = function_locals.all_locals()
      let top_instrs = body.instrs.length()
      let num_locals = all_locals.length()

      if trace_all_funcs || ordinal <= 100 || ordinal % 300 == 0 {
        trace(
          "func[\{ordinal}] vacuum start instrs=\{top_instrs} locals=\{num_locals}",
        )
      }

      let env = Env::new().with_module(mod).with_locals(all_locals)

      let type_cache : Map[UInt64, ValType?] = Map::new()
      let effect_cache : Map[UInt64, Bool] = Map::new()
      let shallow_effect_cache : Map[UInt64, Bool] = Map::new()

      // Size-dependent budget — tiny functions get almost no budget
      let budget = Ref::new(if top_instrs > 200 { 80000 } else { 12000 })

      let sequence = vq_optimize_sequence(
        body.instrs,
        env,
        sig.results,
        sig.results.length() > 0,
        budget,
        type_cache,
        effect_cache,
        shallow_effect_cache,
      )

      let next_items = sequence.items
      if next_items.is_empty() {
        next_items.push(TInstr::nop())
      }
      let next_body = TExpr::new(next_items)

      let mut changed = sequence.changed
      if sig.results.length() == 0 &&
        !vq_texpr_has_unremovable_side_effects(next_body, effect_cache) {
        let nopped = Func::t_func(
          tfunc_params,
          locals,
          TExpr::new([TInstr::nop()]),
        )
        changed = true
        if trace_all_funcs || ordinal <= 100 || ordinal % 300 == 0 {
          trace("func[\{ordinal}] vacuum nopped=true budget_left=\{budget.val}")
        }
        (nopped, changed)
      } else {
        let next_func = Func::t_func(tfunc_params, locals, next_body)
        if trace_all_funcs || ordinal <= 100 || ordinal % 300 == 0 {
          trace(
            "func[\{ordinal}] vacuum done changed=\{changed} budget_left=\{budget.val}",
          )
        }
        (next_func, changed)
      }
    }
  }
}

///|
fn vacuum_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn vacuum_ir_pass_with_trace(
  mod : Module,
  trace : (String) -> Unit,
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext] {
  let sigs = vq_collect_func_sigs(mod)
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let ordinal = def_idx + 1
    let log_func = trace_all_funcs || ordinal <= 50 || ordinal % 500 == 0
    let start_instrs = match func {
      TFunc(_, _, body) => body.instrs.length()
      _ => 0
    }
    if log_func {
      trace("func[\{ordinal}] start instrs=\{start_instrs}")
    }
    let sig = sigs.get(def_idx).unwrap_or(VQFuncSig::new([], []))
    let (next_func, changed) = vq_optimize_function(
      mod, func, sig, ordinal, trace, trace_all_funcs,
    )
    let end_instrs = match next_func {
      TFunc(_, _, body) => body.instrs.length()
      _ => 0
    }
    if log_func {
      trace(
        "func[\{ordinal}] done changed=\{changed} instrs=\{start_instrs}->\{end_instrs}",
      )
    }
    if changed {
      change(ctx, next_func)
    } else {
      unchanged()
    }
  })
}

///|
fn vacuum_ir_pass(mod : Module) -> ModuleTransformer[IRContext] {
  vacuum_ir_pass_with_trace(mod, vacuum_trace_noop)
}

///|
fn run_vacuum(mod : Module) -> Module {
  let pass = vacuum_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("vacuum pass failed: \{e}")
  }
}

///|
fn vq_first_func_body(mod : Module) -> TExpr {
  match mod.code_sec {
    Some(CodeSec([TFunc(_, _, body), ..])) => body
    _ => abort("expected first typed function body")
  }
}

///|
test "vacuum rewrites drop(local.tee(...)) to local.set(...)" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
          ),
        ]),
      ),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TLocalSet(
          LocalIdx(i),
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ),
        ..,
      },
    ] => {
      assert_eq(i, 0U)
      assert_eq(v, 9)
    }
    _ => fail("expected drop(local.tee) to rewrite to local.set")
  }
}

///|
test "vacuum removes side-effect-free dropped value" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [],
        TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
      ),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TNop, .. }] => ()
    _ => fail("expected pure drop to be removed")
  }
}

///|
test "vacuum keeps ambient-consuming drop when child optimizes away" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::i64_const(I64(1)),
            TInstr::drop(TInstr::drop(TInstr::i32_const(I32(2)))),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail("expected ambient-consuming drop to survive vacuum validation: \{e}")
  }
}

///|
test "vacuum keeps ambient-consuming branch value drop with mixed stack types" {
  let t_i64 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i64]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i64()),
              TExpr::new([
                TInstr::i64_const(I64(1)),
                TInstr::i32_const(I32(2)),
                TInstr::br(LabelIdx::new(0), [
                  TInstr::drop(TInstr::drop(TInstr::i32_const(I32(3)))),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected ambient-consuming branch value drop to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum keeps ambient-consuming drop in br_if terminator sequences" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::i64_const(I64(1)),
                TInstr::drop(TInstr::drop(TInstr::i32_const(I32(2)))),
                TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(0)), []),
              ]),
            ),
            TInstr::i32_const(I32(9)),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected ambient-consuming drop in br_if sequence to survive vacuum validation: \{e}",
      )
  }
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          VoidBlockType,
          {
            instrs: [
              { kind: TInstrKind::TI64Const(I64(v0)), .. },
              {
                kind: TInstrKind::TDrop(
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TI32Const(I32(v1)), .. }
                    ),
                    ..,
                  }
                ),
                ..,
              },
              {
                kind: TInstrKind::TBrIf(
                  LabelIdx(label),
                  { kind: TInstrKind::TI32Const(I32(cond)), .. },
                  []
                ),
                ..,
              },
            ],
            ..,
          }
        ),
        ..,
      },
      { kind: TInstrKind::TI32Const(I32(v2)), .. },
    ] => {
      assert_eq(v0, 1L)
      assert_eq(v1, 2)
      assert_eq(label, 0U)
      assert_eq(cond, 0)
      assert_eq(v2, 9)
    }
    _ =>
      fail(
        "expected ambient-consuming dropped child to be preserved under br_if terminator sequence",
      )
  }
}

///|
test "vacuum keeps pure drop when sibling contains nested control transfer" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32()],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::br(LabelIdx::new(1), []),
                    TInstr::unreachable_(),
                  ]),
                ),
                TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          VoidBlockType,
          { instrs: [_, { kind: TInstrKind::TDrop(_), .. }], .. }
        ),
        ..,
      },
    ] => ()
    _ => fail("expected nested-control-transfer sibling to preserve pure drop")
  }
}

///|
test "vacuum simplifies dropped unary wrapper around call to dropped call" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::unary(
                UnaryOp::i32_eqz(),
                TInstr::call(FuncIdx::new(1), []),
              ),
            ),
          ]),
        ),
        Func::t_func([], [], TExpr::new([TInstr::nop()])),
      ]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TDrop({ kind: TInstrKind::TCall(FuncIdx(i), []), .. }),
        ..,
      },
    ] => assert_eq(i, 1U)
    _ => fail("expected drop(i32.eqz(call)) to become drop(call)")
  }
}

///|
test "vacuum replaces constant if(true) with then arm" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::val_type(ValType::i32()),
              TInstr::i32_const(I32(1)),
              TExpr::new([TInstr::i32_const(I32(7))]),
              Some(TExpr::new([TInstr::i32_const(I32(8))])),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TI32Const(I32(v)), .. }] => assert_eq(v, 7)
    _ => fail("expected constant-true if to fold to then arm")
  }
}

///|
test "vacuum replaces if with unreachable condition by the condition" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [],
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::unreachable_(),
            TExpr::new([TInstr::nop()]),
            None,
          ),
        ]),
      ),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => ()
    _ => fail("expected if(unreachable) to fold to unreachable")
  }
}

///|
test "vacuum removes if without else when then arm is nop by dropping condition" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32, t_void]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("cond"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::call(FuncIdx::new(0), []),
              TExpr::new([TInstr::nop()]),
              None,
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TDrop({ kind: TInstrKind::TCall(FuncIdx(i), []), .. }),
        ..,
      },
    ] => assert_eq(i, 0U)
    _ => fail("expected empty if body to become drop(condition)")
  }
}

///|
test "vacuum removes loops with nop body" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [],
        TExpr::new([
          TInstr::loop_(BlockType::void_(), TExpr::new([TInstr::nop()])),
        ]),
      ),
    ]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TNop, .. }] => ()
    _ => fail("expected loop with nop body to become nop")
  }
}

///|
test "vacuum removes trailing dead code after unreachable in block body" {
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([
      TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
      TInstr::unreachable_(),
      TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(2))),
    ]),
  )
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [ValType::i32()], TExpr::new([block]))]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TLocalSet(
                  _,
                  { kind: TInstrKind::TI32Const(I32(v)), .. }
                ),
                ..,
              },
              { kind: TInstrKind::TUnreachable, .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => assert_eq(v, 1)
    _ => fail("expected unreachable tail in block to be removed")
  }
}

///|
test "vacuum keeps explicit unreachable sentinel after br tail" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br(LabelIdx::new(0), []),
                TInstr::unreachable_(),
                TInstr::nop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          VoidBlockType,
          {
            instrs: [
              { kind: TInstrKind::TBr(LabelIdx(lbl), []), .. },
              { kind: TInstrKind::TUnreachable, .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => assert_eq(lbl, 0U)
    _ => fail("expected explicit unreachable sentinel after br to be preserved")
  }
}

///|
test "vacuum turns drop(if drop(..) else drop(..)) into drop(if value else value)" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let dropped_if = TInstr::drop(
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::drop(TInstr::call(FuncIdx::new(0), []))]),
      Some(TExpr::new([TInstr::drop(TInstr::call(FuncIdx::new(1), []))])),
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32, t_void]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("left"),
          ExternType::func(TypeIdx::new(0)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("right"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], [ValType::i32()], TExpr::new([dropped_if])),
      ]),
    )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TDrop(
          {
            kind: TInstrKind::TIf(
              ValTypeBlockType(NumTypeValType(I32NumType)),
              _,
              then_,
              Some(else_)
            ),
            ..,
          }
        ),
        ..,
      },
    ] =>
      match (then_.instrs, else_.instrs) {
        (
          [{ kind: TInstrKind::TCall(FuncIdx(a), []), .. }],
          [{ kind: TInstrKind::TCall(FuncIdx(b), []), .. }],
        ) => {
          assert_eq(a, 0U)
          assert_eq(b, 1U)
        }
        _ => fail("expected value arms")
      }
    _ => fail("expected dropped arms rewrite")
  }
}

///|
test "vacuum safely inverts if with nop then arm" {
  let t_void_with_param = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void_with_param]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::nop()]),
              Some(
                TExpr::new([
                  TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TIf(
          VoidBlockType,
          {
            kind: TInstrKind::TUnary(
              I32EqzOp,
              { kind: TInstrKind::TLocalGet(LocalIdx(idx)), .. }
            ),
            ..,
          },
          then_body,
          None
        ),
        ..,
      },
    ] => {
      assert_eq(idx, 0U)
      match then_body.instrs {
        [{ kind: TInstrKind::TLocalSet(LocalIdx(set_idx), _), .. }] =>
          assert_eq(set_idx, 0U)
        _ => fail("expected inverted then body to keep local.set side effect")
      }
    }
    _ => fail("expected if with nop then arm to invert into eqz form")
  }
}

///|
test "vacuum regression: inverts dropped-then if when else arm is simple" {
  // This is semantically safe and should still optimize.
  let t_void_with_param = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void_with_param]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [ValType::i32()],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::drop(TInstr::i32_const(I32(0)))]),
              Some(
                TExpr::new([
                  TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(7))),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TIf(
          VoidBlockType,
          {
            kind: TInstrKind::TUnary(
              I32EqzOp,
              { kind: TInstrKind::TLocalGet(LocalIdx(cond_idx)), .. }
            ),
            ..,
          },
          then_body,
          None
        ),
        ..,
      },
    ] => {
      assert_eq(cond_idx, 0U)
      match then_body.instrs {
        [{ kind: TInstrKind::TLocalSet(LocalIdx(set_idx), _), .. }] =>
          assert_eq(set_idx, 1U)
        _ =>
          fail("expected simple else side effects to become inverted then arm")
      }
    }
    _ => fail("expected dropped-then if with simple else arm to invert")
  }
}

///|
test "vacuum regression: avoids inversion when moved else has control transfer" {
  // Control-transfer heavy else arms are where local stack-signature checks can
  // miss context-sensitive constraints; keep conservative shape there.
  let t_i32_to_i32 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32_to_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::local_get(LocalIdx::new(0)),
                  TExpr::new([TInstr::drop(TInstr::i32_const(I32(0)))]),
                  Some(
                    TExpr::new([
                      TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(77))]),
                    ]),
                  ),
                ),
                TInstr::i32_const(I32(9)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  assert_eq(validate_module(out), Ok(()))
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          ValTypeBlockType(NumTypeValType(I32NumType)),
          body
        ),
        ..,
      },
    ] =>
      match body.instrs {
        [
          {
            kind: TInstrKind::TIf(
              VoidBlockType,
              { kind: TInstrKind::TLocalGet(LocalIdx(cond_idx)), .. },
              _,
              Some(_)
            ),
            ..,
          },
          _,
        ] => assert_eq(cond_idx, 0U)
        _ => fail("expected non-inverted if when else arm contains branch")
      }
    _ => fail("expected enclosing value block to stay intact")
  }
}

///|
test "vacuum removes try_table when body cannot throw" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let instr = TInstr::try_table(
    BlockType::val_type(ValType::i32()),
    [Catch::all(LabelIdx::new(0))],
    TExpr::new([TInstr::i32_const(I32(77))]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], [], TExpr::new([instr]))]))
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TI32Const(I32(v)), .. }] => assert_eq(v, 77)
    _ => fail("expected throw-free try_table to fold to body")
  }
}

///|
test "vacuum keeps non-removable try_table body that may throw" {
  let instr = TInstr::try_table(
    BlockType::void_(),
    [Catch::all(LabelIdx::new(0))],
    TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
    .with_code_sec(CodeSec::new([Func::t_func([], [], TExpr::new([instr]))]))
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TTryTable(_, _, _), .. }] => ()
    _ => fail("expected throwing try_table to remain")
  }
}

///|
test "vacuum nops side-effect-free none-returning function body" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(1))]))]),
  )
  let out = run_vacuum(mod)
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TNop, .. }] => ()
    _ => fail("expected side-effect-free function body to become nop")
  }
}

///|
test "vacuum removes dead leading value from result-returning function body and validates" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected vacuum output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TI32Const(I32(v)), .. }] => assert_eq(v, 2)
    _ => fail("expected dead leading value to be removed")
  }
}

///|
test "vacuum removes dead leading arm values in result if and validates" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::val_type(ValType::i32()),
              TInstr::i32_const(I32(1)),
              TExpr::new([
                TInstr::i32_const(I32(11)),
                TInstr::i32_const(I32(22)),
              ]),
              Some(
                TExpr::new([
                  TInstr::i32_const(I32(33)),
                  TInstr::i32_const(I32(44)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected vacuum result-if output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TI32Const(I32(v)), .. }] => assert_eq(v, 22)
    _ => fail("expected constant-folded if to keep only live arm result")
  }
}

///|
test "vacuum preserves only final value inside dropped result block and validates" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::block(
                BlockType::val_type(ValType::i32()),
                TExpr::new([
                  TInstr::i32_const(I32(5)),
                  TInstr::i32_const(I32(6)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected dropped result block output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [{ kind: TInstrKind::TNop, .. }] => ()
    _ => fail("expected dropped pure result block to become nop")
  }
}

///|
test "vacuum preserves multi-value function body results and validates" {
  let t_pair = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32(), ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_pair]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([TInstr::i32_const(I32(1)), TInstr::i64_const(I64(2L))]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected multi-value vacuum output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [
      { kind: TInstrKind::TI32Const(I32(a)), .. },
      { kind: TInstrKind::TI64Const(I64(b)), .. },
    ] => {
      assert_eq(a, 1)
      assert_eq(b, 2L)
    }
    _ => fail("expected multi-value function results to be preserved")
  }
}

///|
test "vacuum preserves constant-folded multi-value if results and validates" {
  let t_pair = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32(), ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_pair]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::type_idx(TypeIdx::new(0)),
              TInstr::i32_const(I32(1)),
              TExpr::new([TInstr::i32_const(I32(7)), TInstr::i64_const(I64(8L))]),
              Some(
                TExpr::new([
                  TInstr::i32_const(I32(9)),
                  TInstr::i64_const(I64(10L)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected multi-value if vacuum output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          TypeIdxBlockType(TypeIdx(idx)),
          {
            instrs: [
              { kind: TInstrKind::TI32Const(I32(a)), .. },
              { kind: TInstrKind::TI64Const(I64(b)), .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => {
      assert_eq(idx, 0U)
      assert_eq(a, 7)
      assert_eq(b, 8L)
    }
    _ =>
      fail("expected constant-folded multi-value if to preserve both results")
  }
}

///|
test "vacuum preserves multi-value block results and validates" {
  let t_pair = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32(), ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_pair]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::type_idx(TypeIdx::new(0)),
              TExpr::new([
                TInstr::i32_const(I32(11)),
                TInstr::i64_const(I64(12L)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected multi-value block vacuum output to validate: \{e}")
  }
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          TypeIdxBlockType(TypeIdx(idx)),
          {
            instrs: [
              { kind: TInstrKind::TI32Const(I32(a)), .. },
              { kind: TInstrKind::TI64Const(I64(b)), .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => {
      assert_eq(idx, 0U)
      assert_eq(a, 11)
      assert_eq(b, 12L)
    }
    _ => fail("expected multi-value block results to be preserved")
  }
}

///|
test "vacuum rebases branch labels when simplifying nested result blocks" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br(LabelIdx::new(1), [
                  TInstr::block(
                    BlockType::val_type(ValType::i32()),
                    TExpr::new([
                      TInstr::br(LabelIdx::new(2), [TInstr::i32_const(I32(42))]),
                    ]),
                  ),
                ]),
              ]),
            ),
            TInstr::i32_const(I32(5)),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)

  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected nested result block labels to stay valid after vacuum: \{e}",
      )
  }

  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBr(
          LabelIdx(depth0),
          [
            {
              kind: TInstrKind::TBlock(
                ValTypeBlockType(NumTypeValType(I32NumType)),
                {
                  instrs: [
                    {
                      kind: TInstrKind::TBr(
                        LabelIdx(depth1),
                        [{ kind: TInstrKind::TI32Const(I32(42)), .. }]
                      ),
                      ..,
                    },
                  ],
                  ..,
                }
              ),
              ..,
            },
          ]
        ),
        ..,
      },
    ] => {
      assert_eq(depth0, 0U)
      assert_eq(depth1, 1U)
    }
    _ =>
      fail(
        "expected vacuum to keep the nested result block valid after rebasing: \{vq_first_func_body(out)}",
      )
  }
}

///|
test "vacuum preserves nested break-to-wrapper inside branch value tree" {
  let t_i32 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::br(LabelIdx::new(1), [
                      TInstr::if_(
                        BlockType::val_type(ValType::i32()),
                        TInstr::local_get(LocalIdx::new(0)),
                        TExpr::new([TInstr::i32_const(I32(7))]),
                        Some(TExpr::new([TInstr::br(LabelIdx::new(1), [])])),
                      ),
                    ]),
                  ]),
                ),
                TInstr::i32_const(I32(9)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected nested break-to-wrapper branch value tree to survive vacuum: \{e}",
      )
  }
  match vq_first_func_body(out).instrs {
    [
      {
        kind: TInstrKind::TBlock(
          ValTypeBlockType(NumTypeValType(I32NumType)),
          {
            instrs: [
              { kind: TInstrKind::TBlock(VoidBlockType, _), .. },
              { kind: TInstrKind::TI32Const(I32(9)), .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => ()
    _ =>
      fail(
        "expected vacuum to keep wrapper block when nested branch-value path targets it",
      )
  }
}

///|
test "vacuum keeps stack-feeding sibling values in block bodies" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32(), ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::local_set(
                  LocalIdx::new(1),
                  TInstr::local_set(
                    LocalIdx::new(2),
                    TInstr::local_get(LocalIdx::new(3)),
                  ),
                ),
                TInstr::br(LabelIdx::new(0), []),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected stack-feeding sibling value to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum keeps mixed-type stack-feeding sibling values in block bodies" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i64(), ValType::i64(), ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::local_set(
                  LocalIdx::new(1),
                  TInstr::local_set(
                    LocalIdx::new(2),
                    TInstr::local_get(LocalIdx::new(3)),
                  ),
                ),
                TInstr::br(LabelIdx::new(0), []),
              ]),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected mixed-type stack-feeding sibling value to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum does not invert stack-fed if condition with non-i32 condition expression" {
  let t_void = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [ValType::i64(), ValType::i32()],
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::if_(
              BlockType::void_(),
              TInstr::drop(TInstr::local_get(LocalIdx::new(1))),
              TExpr::new([TInstr::nop()]),
              Some(
                TExpr::new([
                  TInstr::local_set(LocalIdx::new(2), TInstr::i32_const(I32(7))),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected stack-fed non-i32 if condition to survive vacuum validation: \{e}",
      )
  }
  match vq_first_func_body(out).instrs {
    [
      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
      {
        kind: TInstrKind::TIf(
          VoidBlockType,
          { kind: TInstrKind::TNop, .. },
          then_body,
          Some(other_body)
        ),
        ..,
      },
    ] => {
      match then_body.instrs {
        [] => ()
        [{ kind: TInstrKind::TNop, .. }] => ()
        _ => fail("expected stack-fed if then-arm to stay empty or nop")
      }
      match other_body.instrs {
        [
          {
            kind: TInstrKind::TLocalSet(
              LocalIdx(2U),
              { kind: TInstrKind::TI32Const(I32(7)), .. }
            ),
            ..,
          },
        ] => ()
        _ =>
          fail("expected stack-fed if else-arm to keep local.set side effect")
      }
    }
    _ =>
      fail(
        "expected stack-fed if to keep else-arm form instead of cond eqz inversion",
      )
  }
}

///|
test "vacuum preserves nested drop-drop under local.set with mixed ambient stack types" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32(), ValType::i64(), ValType::i32()],
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::local_get(LocalIdx::new(1)),
            TInstr::local_set(
              LocalIdx::new(2),
              TInstr::drop(TInstr::drop(TInstr::local_get(LocalIdx::new(0)))),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected nested drop-drop under local.set to survive vacuum validation: \{e}",
      )
  }
  match vq_first_func_body(out).instrs {
    [
      { kind: TInstrKind::TLocalGet(LocalIdx(0U)), .. },
      { kind: TInstrKind::TLocalGet(LocalIdx(1U)), .. },
      { kind: TInstrKind::TLocalSet(LocalIdx(2U), value), .. },
    ] =>
      match value.kind {
        TInstrKind::TNop =>
          fail("expected local.set value to keep ambient stack consumption")
        _ => ()
      }
    _ => fail("expected ambient-fed local.set shape to be preserved")
  }
}

///|
test "vacuum preserves child stack signatures under local.set" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::local_get(LocalIdx::new(1)),
            TInstr::local_set(
              LocalIdx::new(0),
              TInstr::drop(TInstr::drop(TInstr::i32_const(I32(7)))),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected local.set child stack signature to be preserved after vacuum: \{e}",
      )
  }
}

///|
test "vacuum keeps stack-feeding sibling values with unknown stack signatures" {
  let t_result = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let t_void = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_result, t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [ValType::i32()],
          TExpr::new([
            TInstr::memory_size(MemIdx::new(0)),
            TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(7))),
            TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
          ]),
        ),
        Func::t_func([ValType::i32()], [], TExpr::new([TInstr::nop()])),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected unknown-signature stack feeder to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum keeps typed params and declared locals separated" {
  let t_result = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_result]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [ValType::i32()],
          TExpr::new([
            TInstr::drop(TInstr::i32_const(I32(1))),
            TInstr::local_get(LocalIdx::new(1)),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(params, locals, _)])) => {
      assert_eq(params, [ValType::i32()])
      assert_eq(locals, [ValType::i32()])
    }
    _ => fail("expected single typed function in output module")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected vacuum output to validate: \{e}")
  }
}

///|
test "vacuum preserves stack-carried table.get result across trailing side effects" {
  let t_extern_result = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::externref()])),
  )
  let t_void_with_i32 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_extern_result, t_void_with_i32]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_table_sec(
      TableSec::new([
        Table::new(
          TableType::new(
            RefType::new(true, HeapType::abs(AbsHeapType::extern_())),
            Limits::i32(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::table_get(TableIdx::new(0), TInstr::i32_const(I32(0))),
            TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
          ]),
        ),
        Func::t_func([ValType::i32()], [], TExpr::new([TInstr::nop()])),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected stack-carried table.get result to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum is stable on nop-only function body across repeated runs" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], TExpr::new([TInstr::nop()]))]),
  )
  let once = run_vacuum(mod)
  let twice = run_vacuum(once)
  assert_eq(once, twice)
}

///|
test "vacuum keeps ambient-fed effectful child inside dropped binary" {
  let t_void = RecType::new(SubType::comp_type(CompType::func([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
          ],
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::local_get(LocalIdx::new(1)),
            TInstr::local_get(LocalIdx::new(2)),
            TInstr::drop(
              TInstr::binary(
                BinaryOp::i32_add(),
                TInstr::local_get(LocalIdx::new(3)),
                TInstr::local_set(
                  LocalIdx::new(4),
                  TInstr::drop(TInstr::drop(TInstr::i32_const(I32(9)))),
                ),
              ),
            ),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected ambient-fed effectful child under dropped binary to survive vacuum validation: \{e}",
      )
  }
}

///|
test "vacuum keeps stack-signature when dropping binary with ambient-fed call child" {
  let t_main = RecType::new(SubType::comp_type(CompType::func([], [])))
  let t_callee = RecType::new(
    SubType::comp_type(
      CompType::func([ValType::i32()], [ValType::i32(), ValType::i32()]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_main, t_callee]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::binary(
                BinaryOp::i32_add(),
                TInstr::i32_const(I32(7)),
                TInstr::call(FuncIdx::new(1), [
                  TInstr::drop(TInstr::i32_const(I32(1))),
                ]),
              ),
            ),
          ]),
        ),
        Func::t_func(
          [ValType::i32()],
          [],
          TExpr::new([
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::local_get(LocalIdx::new(0)),
          ]),
        ),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_vacuum(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected dropped-binary ambient-fed call child case to validate after vacuum: \{e}",
      )
  }
}
