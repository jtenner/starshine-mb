///|
priv enum KnownRefValue {
  KRNull(HeapType)
  KRFunc(FuncIdx)
} derive(Eq)

///|
priv enum PossibleContents {
  PCUnknown
  PCUnreachable
  PCI32(Int)
  PCF32(F32)
  PCF64(F64)
  PCRef(KnownRefValue)
  PCRefType(RefType)
} derive(Eq)

///|
priv struct ContentOracle {}

///|
priv struct GUFAAnalysis {
  immutable_global_refs : Map[GlobalIdx, KnownRefValue]
  func_type_idx_by_func : Map[FuncIdx, TypeIdx]
}

///|
priv struct GUFAState {
  oracle : ContentOracle
  env : Env
  analysis : GUFAAnalysis
  cast_all : Bool
  local_contents : Map[LocalIdx, PossibleContents]
}

///|
fn imported_global_count(mod : Module) -> UInt {
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
fn collect_func_type_idx_by_func(mod : Module) -> Map[FuncIdx, TypeIdx] {
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
fn global_init_known_ref(expr : Expr) -> KnownRefValue? {
  let Expr(instrs) = expr
  match instrs {
    [RefNull(ht)] => Some(KRNull(ht))
    [RefFunc(fi)] => Some(KRFunc(fi))
    _ => None
  }
}

///|
fn collect_immutable_global_refs(mod : Module) -> Map[GlobalIdx, KnownRefValue] {
  let out : Map[GlobalIdx, KnownRefValue] = Map::new()
  let base = imported_global_count(mod)
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for i = 0; i < globals.length(); i = i + 1 {
        match globals[i] {
          Global(GlobalType(_, is_mut), init) =>
            if !is_mut {
              match global_init_known_ref(init) {
                Some(v) =>
                  out[GlobalIdx::new(base + i.reinterpret_as_uint())] = v
                None => ()
              }
            }
        }
      }
    None => ()
  }
  out
}

///|
fn build_gufa_analysis(mod : Module) -> GUFAAnalysis {
  {
    immutable_global_refs: collect_immutable_global_refs(mod),
    func_type_idx_by_func: collect_func_type_idx_by_func(mod),
  }
}

///|
fn known_ref_type(v : KnownRefValue, state : GUFAState) -> RefType {
  match v {
    KRNull(ht) => RefType::new(true, ht)
    KRFunc(fi) =>
      match state.analysis.func_type_idx_by_func.get(fi) {
        Some(type_idx) => RefType::new(false, HeapType::new(type_idx))
        None => RefType::new(false, HeapType::abs(AbsHeapType::func()))
      }
  }
}

///|
fn known_ref_to_contents(v : KnownRefValue) -> PossibleContents {
  PCRef(v)
}

///|
fn contents_make_expression(contents : PossibleContents) -> TInstr? {
  match contents {
    PCI32(v) => Some(TInstr::i32_const(I32(v)))
    PCF32(v) => Some(TInstr::f32_const(v))
    PCF64(v) => Some(TInstr::f64_const(v))
    PCRef(KRNull(ht)) => Some(TInstr::ref_null(ht))
    PCRef(KRFunc(fi)) => Some(TInstr::ref_func(fi))
    _ => None
  }
}

///|
fn contents_ref_type(
  contents : PossibleContents,
  state : GUFAState,
) -> RefType? {
  match contents {
    PCRef(v) => Some(known_ref_type(v, state))
    PCRefType(rt) => Some(rt)
    _ => None
  }
}

///|
fn contents_val_type(
  contents : PossibleContents,
  state : GUFAState,
) -> ValType? {
  match contents {
    PCI32(_) => Some(ValType::i32())
    PCF32(_) => Some(ValType::f32())
    PCF64(_) => Some(ValType::f64())
    PCRef(v) => Some(ValType::ref_type(known_ref_type(v, state)))
    PCRefType(rt) => Some(ValType::ref_type(rt))
    _ => None
  }
}

///|
fn ContentOracle::new() -> ContentOracle {
  ContentOracle::{  }
}

///|
fn ContentOracle::get_contents(
  _self : ContentOracle,
  instr : TInstr,
  state : GUFAState,
) -> PossibleContents {
  gufa_get_contents(instr, state)
}

///|
fn oracle_contents(instr : TInstr, state : GUFAState) -> PossibleContents {
  state.oracle.get_contents(instr, state)
}

///|
fn declared_ref_type(instr : TInstr, state : GUFAState) -> RefType? {
  match instr {
    TLocalGet(idx) =>
      match state.env.get_local_type(idx) {
        Some(RefTypeValType(rt)) => Some(rt)
        _ => None
      }
    TGlobalGet(idx) =>
      match state.env.get_global_type(idx) {
        Some(GlobalType(RefTypeValType(rt), _)) => Some(rt)
        _ => None
      }
    TRefNull(ht) => Some(RefType::new(true, ht))
    TRefFunc(_) => Some(RefType::abs(AbsHeapType::func()))
    TRefAsNonNull(value) =>
      match declared_ref_type(value, state) {
        Some(rt) => Some(RefType::new(false, rt.get_heap_type()))
        None => None
      }
    TRefCast(nullable, ht, _) => Some(RefType::new(nullable, ht))
    TCall(func_idx, _) =>
      match state.env.get_functype_by_funcidx(func_idx) {
        Some(FuncType(_, [RefTypeValType(rt)])) => Some(rt)
        _ => None
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match state.env.resolve_functype(type_idx) {
        Some(FuncType(_, [RefTypeValType(rt)])) => Some(rt)
        _ => None
      }
    _ => None
  }
}

///|
fn inferred_ref_type(instr : TInstr, state : GUFAState) -> RefType? {
  contents_ref_type(oracle_contents(instr, state), state)
}

///|
fn gufa_get_contents(instr : TInstr, state : GUFAState) -> PossibleContents {
  match instr {
    TUnreachable => PCUnreachable
    TI32Const(I32(v)) => PCI32(v)
    TI64Const(_) => PCUnknown
    TF32Const(v) => PCF32(v)
    TF64Const(v) => PCF64(v)
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => PCUnknown
    TRefNull(ht) => known_ref_to_contents(KRNull(ht))
    TRefFunc(fi) => known_ref_to_contents(KRFunc(fi))
    TLocalGet(idx) =>
      match state.local_contents.get(idx) {
        Some(c) => c
        None =>
          match state.env.get_local_type(idx) {
            Some(RefTypeValType(rt)) => PCRefType(rt)
            _ => PCUnknown
          }
      }
    TGlobalGet(idx) =>
      match state.analysis.immutable_global_refs.get(idx) {
        Some(v) => known_ref_to_contents(v)
        None =>
          match state.env.get_global_type(idx) {
            Some(GlobalType(RefTypeValType(rt), _)) => PCRefType(rt)
            _ => PCUnknown
          }
      }
    TLocalTee(_, value) => gufa_get_contents(value, state)
    TRefAsNonNull(value) =>
      match gufa_get_contents(value, state) {
        PCUnreachable => PCUnreachable
        PCRef(KRNull(_)) => PCUnreachable
        PCRef(KRFunc(fi)) => known_ref_to_contents(KRFunc(fi))
        PCRefType(rt) => PCRefType(RefType::new(false, rt.get_heap_type()))
        _ => PCUnknown
      }
    TRefIsNull(value) =>
      match gufa_get_contents(value, state) {
        PCUnreachable => PCUnreachable
        PCRef(KRNull(_)) => PCI32(1)
        PCRef(KRFunc(_)) => PCI32(0)
        PCRefType(rt) => if rt.is_nullable() { PCUnknown } else { PCI32(0) }
        _ => PCUnknown
      }
    TUnary(I32EqzOp, value) =>
      match gufa_get_contents(value, state) {
        PCUnreachable => PCUnreachable
        PCI32(v) => PCI32(if v == 0 { 1 } else { 0 })
        _ => PCUnknown
      }
    TSelect(_, cond, if_true, if_false) =>
      match gufa_get_contents(cond, state) {
        PCUnreachable => PCUnreachable
        PCI32(0) => gufa_get_contents(if_false, state)
        PCI32(_) => gufa_get_contents(if_true, state)
        _ => {
          let t = gufa_get_contents(if_true, state)
          let f = gufa_get_contents(if_false, state)
          if t == f {
            t
          } else {
            PCUnknown
          }
        }
      }
    TRefEq(left, right) =>
      match (gufa_get_contents(left, state), gufa_get_contents(right, state)) {
        (PCUnreachable, _) | (_, PCUnreachable) => PCUnreachable
        (PCRef(KRNull(_)), PCRef(KRNull(_))) => PCI32(1)
        (PCRef(KRNull(_)), PCRef(KRFunc(_)))
        | (PCRef(KRFunc(_)), PCRef(KRNull(_))) => PCI32(0)
        (PCRef(KRFunc(f0)), PCRef(KRFunc(f1))) =>
          PCI32(if f0 == f1 { 1 } else { 0 })
        _ => PCUnknown
      }
    TRefTest(nullable, target_ht, value) =>
      match gufa_get_contents(value, state) {
        PCUnreachable => PCUnreachable
        PCRef(v) =>
          if known_ref_fails_target(v, nullable, target_ht, state) {
            PCI32(0)
          } else if known_ref_passes_target(v, nullable, target_ht, state) {
            PCI32(1)
          } else {
            PCUnknown
          }
        PCRefType(rt) =>
          if Match::matches(rt, RefType::new(nullable, target_ht), state.env) {
            PCI32(1)
          } else {
            PCUnknown
          }
        _ => PCUnknown
      }
    TRefCast(nullable, target_ht, value) =>
      match gufa_get_contents(value, state) {
        PCUnreachable => PCUnreachable
        PCRef(v) =>
          if known_ref_fails_target(v, nullable, target_ht, state) {
            PCUnreachable
          } else if known_ref_passes_target(v, nullable, target_ht, state) {
            match v {
              KRNull(_) => known_ref_to_contents(KRNull(target_ht))
              KRFunc(fi) => known_ref_to_contents(KRFunc(fi))
            }
          } else {
            PCUnknown
          }
        PCRefType(rt) => {
          let target = RefType::new(nullable, target_ht)
          if Match::matches(rt, target, state.env) {
            if is_strict_ref_subtype(rt, target, state) {
              PCRefType(rt)
            } else {
              PCRefType(target)
            }
          } else {
            PCUnknown
          }
        }
        _ => PCUnknown
      }
    _ => PCUnknown
  }
}

///|
fn clear_local_contents(state : GUFAState) -> GUFAState {
  { ..state, local_contents: Map::new() }
}

///|
fn record_local_contents(
  state : GUFAState,
  idx : LocalIdx,
  value : PossibleContents,
) -> GUFAState {
  let next : Map[LocalIdx, PossibleContents] = Map::new()
  for entry in state.local_contents {
    let (k, v) = entry
    if k != idx {
      next[k] = v
    }
  }
  next[idx] = value
  { ..state, local_contents: next }
}

///|
fn state_for_nested_walk(instr : TInstr, state : GUFAState) -> GUFAState {
  match instr {
    // Avoid unsound branch/loop merging when tracking known locals.
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) =>
      clear_local_contents(state)
    _ => state
  }
}

///|
fn func_matches_target_heap(
  func_idx : FuncIdx,
  target_ht : HeapType,
  state : GUFAState,
) -> Bool {
  let func_ht = match state.analysis.func_type_idx_by_func.get(func_idx) {
    Some(type_idx) => HeapType::new(type_idx)
    None => HeapType::abs(AbsHeapType::func())
  }
  Match::matches(func_ht, target_ht, state.env)
}

///|
fn known_ref_passes_target(
  value : KnownRefValue,
  nullable : Bool,
  target_ht : HeapType,
  state : GUFAState,
) -> Bool {
  match value {
    KRNull(_) => nullable
    KRFunc(fi) => func_matches_target_heap(fi, target_ht, state)
  }
}

///|
fn known_ref_fails_target(
  value : KnownRefValue,
  nullable : Bool,
  target_ht : HeapType,
  state : GUFAState,
) -> Bool {
  match value {
    KRNull(_) => !nullable
    KRFunc(fi) => !func_matches_target_heap(fi, target_ht, state)
  }
}

///|
fn is_strict_ref_subtype(
  sub : RefType,
  sup : RefType,
  state : GUFAState,
) -> Bool {
  Match::matches(sub, sup, state.env) && !Match::matches(sup, sub, state.env)
}

///|
fn ref_block_type(nullable : Bool, ht : HeapType) -> BlockType {
  BlockType::val_type(ValType::ref_type(RefType::new(nullable, ht)))
}

///|
fn drop_children_and_append(
  children : Array[TInstr],
  last : TInstr,
  block_type : BlockType,
) -> TInstr {
  if children.is_empty() {
    return last
  }
  let seq : Array[TInstr] = []
  for child in children {
    seq.push(TInstr::drop(child))
  }
  seq.push(last)
  TInstr::block(block_type, TExpr::new(seq))
}

///|
fn optimize_ref_eq(left : TInstr, right : TInstr, state : GUFAState) -> TInstr? {
  let out_type = BlockType::val_type(ValType::i32())
  match (oracle_contents(left, state), oracle_contents(right, state)) {
    (PCUnreachable, _) | (_, PCUnreachable) =>
      Some(
        drop_children_and_append(
          [left, right],
          TInstr::unreachable_(),
          out_type,
        ),
      )
    (PCRef(KRNull(_)), PCRef(KRNull(_))) =>
      Some(
        drop_children_and_append(
          [left, right],
          TInstr::i32_const(I32(1)),
          out_type,
        ),
      )
    (PCRef(KRNull(_)), PCRef(KRFunc(_)))
    | (PCRef(KRFunc(_)), PCRef(KRNull(_))) =>
      Some(
        drop_children_and_append(
          [left, right],
          TInstr::i32_const(I32(0)),
          out_type,
        ),
      )
    (PCRef(KRFunc(f0)), PCRef(KRFunc(f1))) =>
      Some(
        drop_children_and_append(
          [left, right],
          TInstr::i32_const(I32(if f0 == f1 { 1 } else { 0 })),
          out_type,
        ),
      )
    _ => None
  }
}

///|
fn optimize_ref_test(
  nullable : Bool,
  target_ht : HeapType,
  value : TInstr,
  state : GUFAState,
) -> TInstr? {
  let out_type = BlockType::val_type(ValType::i32())
  match oracle_contents(value, state) {
    PCUnreachable =>
      Some(drop_children_and_append([value], TInstr::unreachable_(), out_type))
    PCRef(v) =>
      if known_ref_fails_target(v, nullable, target_ht, state) {
        Some(
          drop_children_and_append([value], TInstr::i32_const(I32(0)), out_type),
        )
      } else if known_ref_passes_target(v, nullable, target_ht, state) {
        Some(
          drop_children_and_append([value], TInstr::i32_const(I32(1)), out_type),
        )
      } else {
        None
      }
    PCRefType(rt) => {
      let target = RefType::new(nullable, target_ht)
      if Match::matches(rt, target, state.env) {
        Some(
          drop_children_and_append([value], TInstr::i32_const(I32(1)), out_type),
        )
      } else {
        None
      }
    }
    _ =>
      match declared_ref_type(value, state) {
        Some(rt) => {
          let target = RefType::new(nullable, target_ht)
          if Match::matches(rt, target, state.env) {
            Some(
              drop_children_and_append(
                [value],
                TInstr::i32_const(I32(1)),
                out_type,
              ),
            )
          } else {
            None
          }
        }
        None => None
      }
  }
}

///|
fn optimize_ref_cast(
  nullable : Bool,
  target_ht : HeapType,
  value : TInstr,
  state : GUFAState,
) -> TInstr? {
  let original_target = RefType::new(nullable, target_ht)
  let refined_target = match
    inferred_ref_type(TInstr::ref_cast(nullable, target_ht, value), state) {
    Some(rt) if is_strict_ref_subtype(rt, original_target, state) => rt
    _ => original_target
  }
  let out_type = ref_block_type(
    refined_target.is_nullable(),
    refined_target.get_heap_type(),
  )
  let rewritten_cast = TInstr::ref_cast(
    refined_target.is_nullable(),
    refined_target.get_heap_type(),
    value,
  )
  match oracle_contents(value, state) {
    PCUnreachable =>
      Some(drop_children_and_append([value], TInstr::unreachable_(), out_type))
    PCRef(v) =>
      if known_ref_fails_target(
          v,
          refined_target.is_nullable(),
          refined_target.get_heap_type(),
          state,
        ) {
        Some(
          drop_children_and_append([value], TInstr::unreachable_(), out_type),
        )
      } else if known_ref_passes_target(
          v,
          refined_target.is_nullable(),
          refined_target.get_heap_type(),
          state,
        ) {
        match v {
          KRNull(_) =>
            Some(
              drop_children_and_append(
                [value],
                TInstr::ref_null(refined_target.get_heap_type()),
                out_type,
              ),
            )
          KRFunc(_) =>
            match declared_ref_type(value, state) {
              Some(rt) =>
                if Match::matches(rt, refined_target, state.env) {
                  Some(value)
                } else if refined_target != original_target {
                  Some(rewritten_cast)
                } else {
                  None
                }
              None => None
            }
        }
      } else {
        None
      }
    PCRefType(rt) =>
      if Match::matches(rt, refined_target, state.env) {
        Some(value)
      } else if refined_target != original_target {
        Some(rewritten_cast)
      } else {
        None
      }
    _ =>
      match declared_ref_type(value, state) {
        Some(rt) =>
          if Match::matches(rt, refined_target, state.env) {
            Some(value)
          } else if refined_target != original_target {
            Some(rewritten_cast)
          } else {
            None
          }
        None =>
          if refined_target != original_target {
            Some(rewritten_cast)
          } else {
            None
          }
      }
  }
}

///|
fn optimize_ref_as_non_null(value : TInstr, state : GUFAState) -> TInstr? {
  match oracle_contents(value, state) {
    PCUnreachable => Some(value)
    PCRef(KRNull(ht)) =>
      Some(
        drop_children_and_append(
          [value],
          TInstr::unreachable_(),
          ref_block_type(false, ht),
        ),
      )
    PCRef(KRFunc(_)) => Some(value)
    PCRefType(rt) => if !rt.is_nullable() { Some(value) } else { None }
    _ =>
      match declared_ref_type(value, state) {
        Some(rt) => if !rt.is_nullable() { Some(value) } else { None }
        None => None
      }
  }
}

///|
fn optimize_ref_is_null(value : TInstr, state : GUFAState) -> TInstr? {
  let out_type = BlockType::val_type(ValType::i32())
  match oracle_contents(value, state) {
    PCUnreachable =>
      Some(drop_children_and_append([value], TInstr::unreachable_(), out_type))
    PCRef(KRNull(_)) =>
      Some(
        drop_children_and_append([value], TInstr::i32_const(I32(1)), out_type),
      )
    PCRef(KRFunc(_)) =>
      Some(
        drop_children_and_append([value], TInstr::i32_const(I32(0)), out_type),
      )
    PCRefType(rt) =>
      if rt.is_nullable() {
        None
      } else {
        Some(
          drop_children_and_append([value], TInstr::i32_const(I32(0)), out_type),
        )
      }
    _ => None
  }
}

///|
fn optimize_i32_eqz(value : TInstr, state : GUFAState) -> TInstr? {
  let out_type = BlockType::val_type(ValType::i32())
  match oracle_contents(value, state) {
    PCUnreachable =>
      Some(drop_children_and_append([value], TInstr::unreachable_(), out_type))
    PCI32(v) =>
      Some(
        drop_children_and_append(
          [value],
          TInstr::i32_const(I32(if v == 0 { 1 } else { 0 })),
          out_type,
        ),
      )
    _ => None
  }
}

///|
fn maybe_replace_leaf_with_known_contents(
  instr : TInstr,
  state : GUFAState,
) -> TInstr {
  match instr {
    TLocalGet(_) | TGlobalGet(_) =>
      match contents_make_expression(oracle_contents(instr, state)) {
        Some(replacement) => {
          let curr_type : ValType? = match instr {
            TLocalGet(idx) => state.env.get_local_type(idx)
            TGlobalGet(idx) =>
              match state.env.get_global_type(idx) {
                Some(GlobalType(vt, _)) => Some(vt)
                None => None
              }
            _ => None
          }
          let replacement_type = contents_val_type(
            oracle_contents(replacement, state),
            state,
          )
          match (curr_type, replacement_type) {
            (Some(curr_ty), Some(rep_ty)) =>
              if Match::matches(rep_ty, curr_ty, state.env) {
                replacement
              } else {
                instr
              }
            _ => instr
          }
        }
        None => instr
      }
    _ => instr
  }
}

///|
fn maybe_add_cast_all(instr : TInstr, state : GUFAState) -> TInstr {
  if !state.cast_all {
    return instr
  }
  match instr {
    // Existing casts are handled by ref.cast simplification/refinement.
    TRefCast(_, _, _) => return instr
    _ => ()
  }
  let declared = match declared_ref_type(instr, state) {
    Some(rt) => rt
    None => return instr
  }
  let inferred = match inferred_ref_type(instr, state) {
    Some(rt) => rt
    None => return instr
  }
  if is_strict_ref_subtype(inferred, declared, state) {
    TInstr::ref_cast(inferred.is_nullable(), inferred.get_heap_type(), instr)
  } else {
    instr
  }
}

///|
fn gufa_optimize_tinstr(instr : TInstr, state : GUFAState) -> TInstr {
  let optimized = match instr {
    TRefEq(left, right) =>
      match optimize_ref_eq(left, right, state) {
        Some(opt) => opt
        None => instr
      }
    TRefTest(nullable, target_ht, value) =>
      match optimize_ref_test(nullable, target_ht, value, state) {
        Some(opt) => opt
        None => instr
      }
    TRefCast(nullable, target_ht, value) =>
      match optimize_ref_cast(nullable, target_ht, value, state) {
        Some(opt) => opt
        None => instr
      }
    TRefAsNonNull(value) =>
      match optimize_ref_as_non_null(value, state) {
        Some(opt) => opt
        None => instr
      }
    TRefIsNull(value) =>
      match optimize_ref_is_null(value, state) {
        Some(opt) => opt
        None => instr
      }
    TUnary(I32EqzOp, value) =>
      match optimize_i32_eqz(value, state) {
        Some(opt) => opt
        None => instr
      }
    _ => instr
  }
  maybe_add_cast_all(
    maybe_replace_leaf_with_known_contents(optimized, state),
    state,
  )
}

///|
fn post_instr_state(state : GUFAState, instr : TInstr) -> (GUFAState, Bool) {
  match instr {
    TLocalSet(idx, value) =>
      (record_local_contents(state, idx, oracle_contents(value, state)), true)
    TLocalTee(idx, value) =>
      (record_local_contents(state, idx, oracle_contents(value, state)), true)
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) =>
      if state.local_contents.is_empty() {
        (state, false)
      } else {
        (clear_local_contents(state), true)
      }
    _ => (state, false)
  }
}

///|
fn gufa_transform_tinstr(
  transformer : ModuleTransformer[GUFAState],
  state : GUFAState,
  instr : TInstr,
) -> TransformerResult[GUFAState, TInstr] {
  let walk_state = state_for_nested_walk(instr, state)
  let (state, walked) = match
    transformer.walk_tinstruction_default(walk_state, instr) {
    Ok(None) => (walk_state, instr)
    Ok(Some((state, walked))) => (state, walked)
    Err(e) => return Err(e)
  }
  let optimized = gufa_optimize_tinstr(walked, state)
  let (next_state, state_changed) = post_instr_state(state, optimized)
  if optimized == instr && !state_changed {
    unchanged()
  } else {
    change(next_state, optimized)
  }
}

///|
fn gufa_transform_func(
  transformer : ModuleTransformer[GUFAState],
  state : GUFAState,
  func : Func,
) -> TransformerResult[GUFAState, Func] {
  match func {
    Func(_, _) => unchanged()
    TFunc(locals, body) => {
      let local_state = GUFAState::{
        ..state,
        env: state.env.with_locals(locals),
        local_contents: Map::new(),
      }
      match transformer.walk_texpr(local_state, body) {
        Ok(Some((_, new_body))) =>
          if new_body != body {
            change(state, Func::t_func(locals, new_body))
          } else {
            unchanged()
          }
        Ok(None) => unchanged()
        Err(e) => Err(e)
      }
    }
  }
}

///|
fn gufa_ir_pass(mod : Module, cast_all : Bool) -> ModuleTransformer[IRContext] {
  let base_state = {
    oracle: ContentOracle::new(),
    env: Env::new().with_module(mod),
    analysis: build_gufa_analysis(mod),
    cast_all,
    local_contents: Map::new(),
  }
  let pass = ModuleTransformer::new()
    .on_func_evt(gufa_transform_func)
    .on_tinstruction_evt(gufa_transform_tinstr)
  ModuleTransformer::new().on_func_evt(fn(_, ctx : IRContext, func : Func) {
    match pass.walk_func(base_state, func) {
      Ok(Some((_, new_func))) =>
        if new_func != func {
          change(ctx, new_func)
        } else {
          unchanged()
        }
      Ok(None) => unchanged()
      Err(e) => Err(e)
    }
  })
}

///|
fn run_gufa_module(
  mod : Module,
  cast_all? : Bool = false,
) -> Result[Module, String] {
  let ctx = IRContext::new()
  ctx.set_mod(mod)
  let pass = gufa_ir_pass(mod, cast_all)
  match pass.walk_module(ctx, mod) {
    Ok(Some((_, new_mod))) => Ok(new_mod)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
test "gufa ref.eq of distinct ref.func values becomes const false" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::ref_eq(
          TInstr::ref_func(FuncIdx::new(1)),
          TInstr::ref_func(FuncIdx::new(2)),
        ),
      ),
    ]),
  )
  let f1 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let f2 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(CodeSec::new([root, f1, f2]))
  let optimized = match run_gufa_module(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected gufa error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TBlock(_, TExpr(seq)))])), _, _])) =>
      match seq[seq.length() - 1] {
        TI32Const(I32(v)) => assert_eq(v, 0)
        _ => fail("expected ref.eq replacement to end with i32.const 0")
      }
    _ => fail("expected transformed root function")
  }
}

///|
test "gufa ref.test of null against non-null target becomes const false" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::ref_test(
        false,
        HeapType::abs(AbsHeapType::func()),
        TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
      ),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let optimized = match run_gufa_module(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected gufa error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TBlock(_, TExpr(seq)))]))])) =>
      match seq[seq.length() - 1] {
        TI32Const(I32(v)) => assert_eq(v, 0)
        _ => fail("expected ref.test replacement to end with i32.const 0")
      }
    _ => fail("expected transformed function body")
  }
}

///|
test "gufa impossible ref.cast becomes unreachable" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::ref_cast(
        false,
        HeapType::abs(AbsHeapType::func()),
        TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
      ),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let optimized = match run_gufa_module(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected gufa error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TBlock(_, TExpr(seq)))]))])) =>
      match seq[seq.length() - 1] {
        TUnreachable => ()
        _ => fail("expected impossible cast to become unreachable")
      }
    _ => fail("expected transformed function body")
  }
}

///|
test "gufa cast_all inserts cast for known immutable global ref.func" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body = TExpr::new([TInstr::drop(TInstr::global_get(GlobalIdx::new(0)))])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::funcref(), false),
          Expr::new([Instruction::ref_func(FuncIdx::new(0))]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let optimized = match run_gufa_module(mod, cast_all=true) {
    Ok(m) => m
    Err(e) => fail("unexpected gufa error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(instr)]))])) =>
      match instr {
        TRefCast(false, HeapType(TypeIdx(i)), TGlobalGet(GlobalIdx(g))) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(g.reinterpret_as_int(), 0)
        }
        TRefCast(false, HeapType(TypeIdx(i)), TRefFunc(FuncIdx(f))) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(f.reinterpret_as_int(), 0)
        }
        TRefFunc(FuncIdx(f)) => assert_eq(f.reinterpret_as_int(), 0)
        _ => fail("expected GUFA cast_all to insert cast around global.get")
      }
    _ => fail("expected transformed function body")
  }
}

///|
test "gufa cast_all propagates known local ref.func and inserts cast" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::ref_func(FuncIdx::new(0))),
    TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([ValType::funcref()], body)]))
  let optimized = match run_gufa_module(mod, cast_all=true) {
    Ok(m) => m
    Err(e) => fail("unexpected gufa error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([_, TDrop(instr)]))])) =>
      match instr {
        TRefCast(false, HeapType(TypeIdx(i)), TLocalGet(LocalIdx(local_i))) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(local_i.reinterpret_as_int(), 0)
        }
        TRefCast(false, HeapType(TypeIdx(i)), TRefFunc(FuncIdx(f))) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(f.reinterpret_as_int(), 0)
        }
        TRefFunc(FuncIdx(f)) => assert_eq(f.reinterpret_as_int(), 0)
        _ =>
          fail(
            "expected GUFA cast_all to insert cast around local.get after local.set",
          )
      }
    _ => fail("expected transformed function body")
  }
}

///|
test "gufa ref.cast refines target type when inferred type is stricter" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::ref_cast(
        true,
        HeapType::abs(AbsHeapType::func()),
        TInstr::global_get(GlobalIdx::new(0)),
      ),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::funcref(), false),
          Expr::new([Instruction::ref_func(FuncIdx::new(0))]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let optimized = match run_gufa_module(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected gufa error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(instr)]))])) =>
      match instr {
        TRefCast(false, HeapType(TypeIdx(i)), TGlobalGet(GlobalIdx(g))) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(g.reinterpret_as_int(), 0)
        }
        TRefCast(false, HeapType(TypeIdx(i)), TRefFunc(FuncIdx(f))) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(f.reinterpret_as_int(), 0)
        }
        TRefFunc(FuncIdx(f)) => assert_eq(f.reinterpret_as_int(), 0)
        _ => fail("expected ref.cast target to be refined to exact func type")
      }
    _ => fail("expected transformed function body")
  }
}

///|
test "gufa oracle propagates local i32 constant into i32.eqz" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(0))),
    TInstr::drop(
      TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([ValType::i32()], body)]))
  let optimized = match run_gufa_module(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected gufa error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([_, TDrop(TBlock(_, TExpr(seq)))]))])) =>
      match seq[seq.length() - 1] {
        TI32Const(I32(v)) => assert_eq(v, 1)
        _ => fail("expected i32.eqz(local.const 0) to fold to i32.const 1")
      }
    _ => fail("expected transformed function body")
  }
}

///|
test "gufa oracle propagates local ref.func into ref.is_null" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::ref_func(FuncIdx::new(0))),
    TInstr::drop(TInstr::ref_is_null(TInstr::local_get(LocalIdx::new(0)))),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([ValType::funcref()], body)]))
  let optimized = match run_gufa_module(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected gufa error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([_, TDrop(TBlock(_, TExpr(seq)))]))])) =>
      match seq[seq.length() - 1] {
        TI32Const(I32(v)) => assert_eq(v, 0)
        _ => fail("expected ref.is_null(ref.func) to fold to i32.const 0")
      }
    _ => fail("expected transformed function body")
  }
}
