///|
fn gr_count_imported_globals(mod : Module) -> UInt {
  let mut n : UInt = 0
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
fn gr_collect_exported_globals(mod : Module) -> Set[GlobalIdx] {
  let out : Set[GlobalIdx] = Set::new()
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          Export(_, GlobalExternIdx(idx)) => out.add(idx)
          _ => ()
        }
      }
    None => ()
  }
  out
}

///|
fn gr_collect_func_type_idx_by_func(mod : Module) -> Map[FuncIdx, TypeIdx] {
  let out : Map[FuncIdx, TypeIdx] = Map::new()
  let mut next_idx : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) => {
            out[FuncIdx::new(next_idx)] = type_idx
            next_idx += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        out[FuncIdx::new(next_idx)] = type_idx
        next_idx += 1
      }
    None => ()
  }
  out
}

///|
fn gr_is_public_heap_type(ht : HeapType) -> Bool {
  match ht {
    AbsHeapTypeHeapType(_) => true
    HeapType(TypeIdx(_)) => true
    HeapType(RecIdx(_)) => false
    DefTypeHeapType(_) => false
  }
}

///|
fn gr_is_public_ref_type(rt : RefType) -> Bool {
  match rt {
    AbsHeapTypeRefType(_) => true
    HeapTypeRefType(_, ht) => gr_is_public_heap_type(ht)
  }
}

///|
fn gr_is_public_val_type(vt : ValType) -> Bool {
  match vt {
    RefTypeValType(rt) => gr_is_public_ref_type(rt)
    _ => true
  }
}

///|
fn gr_common_ref_heap_supertype(
  a : HeapType,
  b : HeapType,
  env : Env,
) -> HeapType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  let candidates = [
    AbsHeapType::i31(),
    AbsHeapType::struct_(),
    AbsHeapType::array(),
    AbsHeapType::eq(),
    AbsHeapType::func(),
    AbsHeapType::extern_(),
    AbsHeapType::exn(),
    AbsHeapType::any(),
  ]
  for abs in candidates {
    let super_ht = HeapType::abs(abs)
    if Match::matches(a, super_ht, env) && Match::matches(b, super_ht, env) {
      return Some(super_ht)
    }
  }
  None
}

///|
fn gr_common_ref_type_supertype(
  a : RefType,
  b : RefType,
  env : Env,
) -> RefType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  match
    gr_common_ref_heap_supertype(a.get_heap_type(), b.get_heap_type(), env) {
    Some(ht) => Some(RefType::new(a.is_nullable() || b.is_nullable(), ht))
    None => None
  }
}

///|
fn gr_lub_for_refining(
  a : ValType,
  b : ValType,
  old_type : ValType,
  env : Env,
) -> ValType {
  if Match::matches(a, b, env) {
    return b
  }
  if Match::matches(b, a, env) {
    return a
  }
  match (a, b) {
    (RefTypeValType(r0), RefTypeValType(r1)) =>
      match gr_common_ref_type_supertype(r0, r1, env) {
        Some(rt) => {
          let candidate = ValType::ref_type(rt)
          if Match::matches(candidate, old_type, env) {
            candidate
          } else {
            old_type
          }
        }
        None => old_type
      }
    _ => old_type
  }
}

///|
fn gr_note_observed_type(
  candidates : Map[GlobalIdx, ValType],
  idx : GlobalIdx,
  observed : ValType,
  old_type : ValType,
  env : Env,
) -> Unit {
  let merged = match candidates.get(idx) {
    Some(prev) => gr_lub_for_refining(prev, observed, old_type, env)
    None => observed
  }
  candidates[idx] = merged
}

///|
fn gr_infer_tinstr_type(
  instr : TInstr,
  env : Env,
  func_type_idx_by_func : Map[FuncIdx, TypeIdx],
) -> ValType? {
  match instr {
    TI32Const(_) => Some(ValType::i32())
    TI64Const(_) => Some(ValType::i64())
    TF32Const(_) => Some(ValType::f32())
    TF64Const(_) => Some(ValType::f64())
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(ValType::v128())
    TRefNull(ht) => Some(ValType::ref_type(RefType::new(true, ht)))
    TRefFunc(fi) =>
      match func_type_idx_by_func.get(fi) {
        Some(type_idx) =>
          Some(ValType::ref_type(RefType::new(false, HeapType::new(type_idx))))
        None => Some(ValType::ref_type(RefType::abs(AbsHeapType::func())))
      }
    TLocalGet(idx) => env.get_local_type(idx)
    TGlobalGet(idx) =>
      match env.get_global_type(idx) {
        Some(GlobalType(vt, _)) => Some(vt)
        None => None
      }
    TLocalTee(_, value) =>
      gr_infer_tinstr_type(value, env, func_type_idx_by_func)
    TRefAsNonNull(value) =>
      match gr_infer_tinstr_type(value, env, func_type_idx_by_func) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    TRefCast(nullable, ht, _) =>
      Some(ValType::ref_type(RefType::new(nullable, ht)))
    TSelect(Some(types), _, _, _) if types.length() == 1 => Some(types[0])
    TCall(target, _) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TBlock(bt, _) | TLoop(bt, _) | TIf(bt, _, _, _) | TTryTable(bt, _, _) =>
      match env.expand_blocktype(bt) {
        Ok((_, [vt])) => Some(vt)
        _ => None
      }
    _ => None
  }
}

///|
fn gr_infer_expr_type(
  expr : Expr,
  env : Env,
  func_type_idx_by_func : Map[FuncIdx, TypeIdx],
) -> ValType? {
  match to_texpr(expr, env) {
    Ok(TExpr(instrs)) if !instrs.is_empty() =>
      gr_infer_tinstr_type(
        instrs[instrs.length() - 1],
        env,
        func_type_idx_by_func,
      )
    _ => None
  }
}

///|
fn global_refining(mod : Module) -> Result[Module, String] {
  let globals = match mod.global_sec {
    Some(GlobalSec(globals)) => globals
    None => return Ok(mod)
  }
  if globals.is_empty() {
    return Ok(mod)
  }
  let env = Env::new().with_module(mod)
  let imported_globals = gr_count_imported_globals(mod)
  let exported_globals = gr_collect_exported_globals(mod)
  let func_type_idx_by_func = gr_collect_func_type_idx_by_func(mod)
  let optimizable : Set[GlobalIdx] = Set::new()
  for i = 0; i < globals.length(); i = i + 1 {
    let idx = GlobalIdx::new(imported_globals + i.reinterpret_as_uint())
    let Global(GlobalType(_, is_mut), _) = globals[i]
    if exported_globals.contains(idx) && is_mut {
      continue
    }
    optimizable.add(idx)
  }
  let candidates : Map[GlobalIdx, ValType] = Map::new()
  let set_walker = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    env : Env,
    instr,
  ) {
    match instr {
      TGlobalSet(idx, value) =>
        if optimizable.contains(idx) {
          match env.get_global_type(idx) {
            Some(GlobalType(old_type, _)) => {
              let observed = match
                gr_infer_tinstr_type(value, env, func_type_idx_by_func) {
                Some(vt) if Match::matches(vt, old_type, env) => vt
                _ => old_type
              }
              gr_note_observed_type(candidates, idx, observed, old_type, env)
            }
            None => ()
          }
        }
      _ => ()
    }
    self.walk_tinstruction_default(env, instr)
  })
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        match func {
          TFunc(locals, body) => {
            let local_env = env.with_locals(locals)
            ignore(set_walker.walk_texpr(local_env, body))
          }
          Func(_, _) => return Err("global_refining: expected TFunc")
        }
      }
    None => ()
  }
  for i = 0; i < globals.length(); i = i + 1 {
    let idx = GlobalIdx::new(imported_globals + i.reinterpret_as_uint())
    if !optimizable.contains(idx) {
      continue
    }
    let Global(GlobalType(old_type, _), init) = globals[i]
    let observed = match gr_infer_expr_type(init, env, func_type_idx_by_func) {
      Some(vt) if Match::matches(vt, old_type, env) => vt
      _ => old_type
    }
    gr_note_observed_type(candidates, idx, observed, old_type, env)
  }
  let new_globals = globals.copy()
  let mut optimized = false
  for i = 0; i < new_globals.length(); i = i + 1 {
    let idx = GlobalIdx::new(imported_globals + i.reinterpret_as_uint())
    if !optimizable.contains(idx) {
      continue
    }
    match candidates.get(idx) {
      Some(new_type) => {
        let Global(GlobalType(old_type, is_mut), init) = new_globals[i]
        if new_type == old_type || !Match::matches(new_type, old_type, env) {
          continue
        }
        if exported_globals.contains(idx) && !gr_is_public_val_type(new_type) {
          continue
        }
        new_globals[i] = Global::new(GlobalType::new(new_type, is_mut), init)
        optimized = true
      }
      None => ()
    }
  }
  if optimized {
    Ok(mod.with_global_sec(GlobalSec::new(new_globals)))
  } else {
    Ok(mod)
  }
}

///|
test "global refining narrows non-exported mutable global type from sets and init" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::anyref(), true),
          Expr::new([Instruction::ref_func(FuncIdx::new(0))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(
              GlobalIdx::new(0),
              TInstr::ref_func(FuncIdx::new(0)),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match global_refining(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected global_refining error: \{e}")
  }
  match optimized.global_sec {
    Some(GlobalSec([Global(GlobalType(vt, is_mut), _)])) => {
      assert_true(is_mut)
      assert_eq(
        vt,
        ValType::ref_type(RefType::new(false, HeapType::new(TypeIdx::new(0)))),
      )
    }
    _ => fail("expected one refined global")
  }
}

///|
test "global refining does not refine exported mutable globals" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::anyref(), true),
          Expr::new([Instruction::ref_func(FuncIdx::new(0))]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("g"), ExternIdx::global(GlobalIdx::new(0))),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(
              GlobalIdx::new(0),
              TInstr::ref_func(FuncIdx::new(0)),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match global_refining(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected global_refining error: \{e}")
  }
  match optimized.global_sec {
    Some(GlobalSec([Global(GlobalType(vt, is_mut), _)])) => {
      assert_true(is_mut)
      assert_eq(vt, ValType::anyref())
    }
    _ => fail("expected one global")
  }
}

///|
test "global refining refines exported immutable globals when refined type is public" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::anyref(), false),
          Expr::new([Instruction::ref_func(FuncIdx::new(0))]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("g"), ExternIdx::global(GlobalIdx::new(0))),
      ]),
    )
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
    )
  let optimized = match global_refining(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected global_refining error: \{e}")
  }
  match optimized.global_sec {
    Some(GlobalSec([Global(GlobalType(vt, is_mut), _)])) => {
      assert_false(is_mut)
      assert_eq(
        vt,
        ValType::ref_type(RefType::new(false, HeapType::new(TypeIdx::new(0)))),
      )
    }
    _ => fail("expected one refined global")
  }
}
