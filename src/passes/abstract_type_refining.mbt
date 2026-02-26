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
type HeapTypeSet = Set[HeapType]

///|
type HeapTypeMap = Map[HeapType, HeapType]

///|
pub(all) struct AbstractTypeRefiningPassProps {
  traps_never_happen : Bool
} derive(Show, Eq)

///|
priv struct ATRState {
  created_or_sub : HeapTypeSet
  refinable : HeapTypeMap
  mapping : HeapTypeMap
  traps_never_happen : Bool
  subtypes : SubTypes
}

///|
priv struct SubTypes {
  types : Array[HeapType]
  immediate_sub : Map[HeapType, Array[HeapType]]
}

///|
fn is_refined(ht : HeapType, mapping : HeapTypeMap) -> Bool {
  mapping.get(ht) is Some(new_ht) && new_ht != ht
}

///|
fn build_subtypes(mod : Module) -> SubTypes {
  let types = Array::new()
  let immediate = Map::new()
  let mut current_type_idx = 0
  if mod.type_sec is Some(type_sec) {
    for rec in type_sec.0 {
      match rec {
        SingleRecType(st) => {
          let ht = HeapType::new(
            TypeIdx::new(current_type_idx.reinterpret_as_uint()),
          )
          types.push(ht)
          immediate[ht] = st.super_types().map(HeapType::new)
          current_type_idx = current_type_idx + 1
        }
        GroupRecType(sts) =>
          for st in sts {
            let ht = HeapType::new(
              TypeIdx::new(current_type_idx.reinterpret_as_uint()),
            )
            types.push(ht)
            immediate[ht] = st.super_types().map(HeapType::new)
            current_type_idx = current_type_idx + 1
          }
      }
    }
  }
  SubTypes::{ types, immediate_sub: immediate }
}

///|
fn collect_created_types(mod : Module) -> HeapTypeSet {
  let set = Set::new()
  let transformer = ModuleTransformer::new().on_tinstruction_evt(fn(
    _,
    _,
    instr,
  ) {
    match instr {
      // ---- structs ----
      TStructNew(type_idx, _) => set.add(HeapType::new(type_idx))

      // ---- arrays ----
      TArrayNew(type_idx, _, _)
      | TArrayNewDefault(type_idx, _)
      | TArrayNewFixed(type_idx, _)
      | TArrayNewData(type_idx, _, _, _)
      | TArrayNewElem(type_idx, _, _, _) => set.add(HeapType::new(type_idx))
      _ => ()
    }
    unchanged()
  })
  ignore(transformer.walk_module((), mod))
  set
}

///|
fn compute_created_or_sub(
  created : HeapTypeSet,
  subtypes : SubTypes,
) -> HeapTypeSet {
  let result = created.copy()

  // bottom‑up traversal
  for t in subtypes.types {
    let subs = subtypes.immediate_sub.get(t).unwrap_or([])
    for s in subs {
      if result.contains(s) {
        result.add(t)
        break
      }
    }
  }
  result
}

///|
fn compute_refinable(
  created : HeapTypeSet,
  created_or_sub : HeapTypeSet,
  subtypes : SubTypes,
) -> HeapTypeMap {
  let refinable = Map::new()
  for t in subtypes.types {
    if created.contains(t) {
      continue
    }
    let subs = subtypes.immediate_sub.get(t).unwrap_or([])
    let mut candidate : HeapType? = None
    for s in subs {
      if created_or_sub.contains(s) {
        match candidate {
          None => candidate = Some(s)
          Some(_) => {
            candidate = None
            break
          }
        }
      }
    }
    if candidate is Some(c) {
      refinable[t] = refinable.get(c).unwrap_or(c)
    }
  }
  refinable
}

///|
fn build_mapping(state : ATRState) -> HeapTypeMap {
  let mapping = Map::new()
  for t in state.subtypes.types {
    if state.traps_never_happen && !state.created_or_sub.contains(t) {
      mapping[t] = HeapType::bottom()
      continue
    }
    if state.refinable.get(t) is Some(r) {
      mapping[t] = r
    }
  }
  mapping
}

///|
fn rewrite_heaptype(ht : HeapType, mapping : HeapTypeMap) -> HeapType {
  mapping.get(ht).unwrap_or(ht)
}

///|
fn rewrite_cast(instr : TInstr, mapping : HeapTypeMap) -> TInstr {
  match instr {
    TRefCast(nullable, ht, v) => {
      let new_ht = rewrite_heaptype(ht, mapping)
      if new_ht == ht {
        instr
      } else {
        TInstr::ref_cast(nullable, new_ht, v)
      }
    }
    TBrOnCast(l, op, ht1, ht2, v, args) => {
      let n1 = rewrite_heaptype(ht1, mapping)
      let n2 = rewrite_heaptype(ht2, mapping)
      TInstr::br_on_cast(l, op.0, n1, op.1, n2, v, args)
    }
    TBrOnCastFail(l, op, ht1, ht2, v, args) => {
      let n1 = rewrite_heaptype(ht1, mapping)
      let n2 = rewrite_heaptype(ht2, mapping)
      TInstr::br_on_cast_fail(l, op.0, n1, op.1, n2, v, args)
    }
    _ => instr
  }
}

///|
fn drop_then_unreachable_ref_cast(
  nullable : Bool,
  ht : HeapType,
  value : TInstr,
) -> TInstr {
  let result_ty = ValType::ref_type(RefType::new(nullable, ht))
  TInstr::block(
    BlockType::val_type(result_ty),
    TExpr::new([TInstr::drop(value), TInstr::unreachable_()]),
  )
}

///|
/// Computes the full abstract-type-refining analysis state.
/// Must be run before invoking `abstract_type_refining`.
fn compute_atr_state(mod : Module, traps_never_happen : Bool) -> ATRState {
  let subtypes = build_subtypes(mod)
  let created = collect_created_types(mod)
  let created_or_sub = compute_created_or_sub(created, subtypes)
  let refinable = if traps_never_happen {
    compute_refinable(created, created_or_sub, subtypes)
  } else {
    Map::new()
  }
  let tmp_state = ATRState::{
    created_or_sub,
    refinable,
    mapping: Map::new(),
    traps_never_happen,
    subtypes,
  }
  let mapping = build_mapping(tmp_state)
  ATRState::{ ..tmp_state, mapping, }
}

///| For exact descriptor casts, normalization must not introduce new successes.

///|
/// Nullability does not make bottom inhabitable, so it is ignored here.
fn rewrite_descriptor_exact_ref_cast(
  instr : TInstr,
  mapping : HeapTypeMap,
  traps_never_happen : Bool,
) -> TInstr {
  match instr {
    TRefCast(nullable, ht, value) =>
      // Exact casts must not gain success.
      // After normalization, this is impossible iff:
      //   - the type is bottom, or
      //   - the type was refined to something else.
      if traps_never_happen &&
        (ht == HeapType::bottom() || is_refined(ht, mapping)) {
        drop_then_unreachable_ref_cast(nullable, ht, value)
      } else {
        instr
      }
    _ => instr
  }
}

///|
fn rewrite_descriptor_exact_br_on_cast(
  instr : TInstr,
  mapping : HeapTypeMap,
  traps_never_happen : Bool,
) -> TInstr {
  let is_exact = fn(src_ht : HeapType, dst_ht : HeapType) { src_ht == dst_ht }
  match instr {
    TBrOnCast(label, op, src_ht, dst_ht, value, args) =>
      if traps_never_happen &&
        is_exact(src_ht, dst_ht) &&
        is_refined(dst_ht, mapping) {
        TInstr::br_on_cast(
          label,
          op.0,
          src_ht,
          false,
          HeapType::bottom(),
          value,
          args,
        )
      } else {
        instr
      }
    TBrOnCastFail(label, op, src_ht, dst_ht, value, args) =>
      if traps_never_happen &&
        is_exact(src_ht, dst_ht) &&
        is_refined(dst_ht, mapping) {
        TInstr::br_on_cast_fail(
          label,
          op.0,
          src_ht,
          false,
          HeapType::bottom(),
          value,
          args,
        )
      } else {
        instr
      }
    _ => instr
  }
}

///|
fn run_abstract_type_refining_pass(
  mod : Module,
  props : AbstractTypeRefiningPassProps,
) -> Result[Module, String] {
  let ctx = IRContext::new()
  let mut mod = mod
  ctx.set_mod(mod)
  let pass = abstract_type_refining(mod, props.traps_never_happen)
  match pass.walk_module(ctx, mod) {
    Ok(Some((_, final_mod))) => mod = final_mod
    Ok(None) => ()
    Err(e) => return Err(e)
  }
  Ok(mod)
}

///|
fn abstract_type_refining(
  mod : Module,
  traps_never_happen : Bool,
) -> ModuleTransformer[IRContext] {
  let state = compute_atr_state(mod, traps_never_happen)
  ModuleTransformer::new()
  .on_tinstruction_evt(fn(self, ctx : IRContext, instr) {
    let walked = match self.walk_tinstruction_default(ctx, instr) {
      Ok(Some((_, next))) => next
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    let rewritten = rewrite_cast(walked, state.mapping)
    let rewritten = rewrite_descriptor_exact_ref_cast(
      rewritten,
      state.mapping,
      state.traps_never_happen,
    )
    let rewritten = rewrite_descriptor_exact_br_on_cast(
      rewritten,
      state.mapping,
      state.traps_never_happen,
    )
    if rewritten == instr {
      unchanged()
    } else {
      change(ctx, rewritten)
    }
  })
  .on_heaptype_evt(fn(_, ctx, ht) {
    change(ctx, rewrite_heaptype(ht, state.mapping))
  })
}

///|
test "abstract struct usage becomes bottom" {
  let ht = HeapType::new(TypeIdx::new(0))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(comp_type_sub_type(struct_comp_type([])))]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::ref_cast(
              true,
              ht,
              TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
            ),
          ]),
        ),
      ]),
    )
  let new_mod = run_abstract_type_refining_pass(mod, {
    traps_never_happen: true,
  })
  let CodeSec(funcs) = new_mod.unwrap().code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("Expected tfunc")
    TFunc(_, TExpr(instrs)) => instrs
  }
  match instrs[0] {
    TBlock(_, _) => ()
    _ => fail("expected abstract cast to trap")
  }
}

///|
test "exact ref.cast collapses to trap" {
  let instr = TInstr::ref_cast(
    true,
    HeapType::new(TypeIdx::new(0)),
    TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
  )
  let mapping = Map::new()
  mapping.set(HeapType::new(TypeIdx::new(0)), HeapType::bottom())

  // Phase 1: normalize heap type
  let instr = rewrite_cast(instr, mapping)

  // Phase 2: exact-descriptor handling
  let rewritten = rewrite_descriptor_exact_ref_cast(instr, mapping, true)
  match rewritten {
    TBlock(_, _) => ()
    _ => fail("expected drop + unreachable")
  }
}

///|
test "exact ref.cast does not trap when traps may happen" {
  let instr = TInstr::ref_cast(
    true,
    HeapType::new(TypeIdx::new(0)),
    TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
  )
  let mapping = Map::new()
  mapping.set(HeapType::new(TypeIdx::new(0)), HeapType::bottom())
  let rewritten = rewrite_descriptor_exact_ref_cast(
    instr, mapping, false, // traps MAY happen
  )
  match rewritten {
    TRefCast(_, _, _) => ()
    _ => fail("exact cast must not collapse when traps may happen")
  }
}

///|
test "non-exact cast refines normally" {
  let instr = TInstr::ref_cast(
    true,
    HeapType::new(TypeIdx::new(0)),
    TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
  )
  let mapping = Map::new()
  mapping.set(HeapType::new(TypeIdx::new(0)), HeapType::new(TypeIdx::new(1)))
  let rewritten = rewrite_cast(instr, mapping)
  match rewritten {
    TRefCast(_, ht, _) => assert_eq(ht, HeapType::new(TypeIdx::new(1)))
    _ => fail("unexpected rewrite")
  }
}

///|
test "exact br_on_cast does not gain success" {
  let instr = TInstr::br_on_cast(
    LabelIdx::new(0),
    true,
    HeapType::new(TypeIdx::new(0)),
    true,
    HeapType::new(TypeIdx::new(0)),
    TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
    [],
  )
  let mapping = Map::new()
  mapping.set(HeapType::new(TypeIdx::new(0)), HeapType::new(TypeIdx::new(2)))
  let rewritten = rewrite_descriptor_exact_br_on_cast(
    instr, mapping, true, // traps_never_happen
  )
  match rewritten {
    TBrOnCast(_, op, _, dst, _, _) => {
      assert_true(!op.1) // success branch is forced to non-null bottom
      assert_eq(dst, HeapType::bottom()) // cannot gain success
    }
    _ => fail("unexpected rewrite")
  }
}

///|
test "exact br_on_cast preserved when traps may happen" {
  let instr = TInstr::br_on_cast(
    LabelIdx::new(0),
    true,
    HeapType::new(TypeIdx::new(0)),
    true,
    HeapType::new(TypeIdx::new(0)),
    TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
    [],
  )
  let mapping = Map::new()
  mapping.set(HeapType::new(TypeIdx::new(0)), HeapType::new(TypeIdx::new(2)))
  let rewritten = rewrite_descriptor_exact_br_on_cast(
    instr, mapping, false, // traps MAY happen
  )
  match rewritten {
    TBrOnCast(_, op, _, dst, _, _) => {
      assert_true(op.1) // target nullability is unchanged
      assert_eq(dst, HeapType::new(TypeIdx::new(0)))
    }
    _ => fail("unexpected rewrite")
  }
}

///|
test "abstract array collapses to bottom" {
  let instr = TInstr::array_new(
    TypeIdx::new(0),
    TInstr::i32_const(I32(1)),
    TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
  )
  let mapping = Map::new()
  mapping.set(HeapType::new(TypeIdx::new(0)), HeapType::bottom())
  let rewritten = rewrite_cast(instr, mapping)
  assert_eq(rewritten, instr) // allocation itself unchanged
}

///|
test "abstract struct does not trap when traps may happen" {
  let ht = HeapType::new(TypeIdx::new(0))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(comp_type_sub_type(struct_comp_type([])))]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::ref_cast(
              true,
              ht,
              TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
            ),
          ]),
        ),
      ]),
    )
  let new_mod = run_abstract_type_refining_pass(mod, {
    traps_never_happen: false,
  })
  let CodeSec(funcs) = new_mod.unwrap().code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("Expected tfunc")
    TFunc(_, TExpr(instrs)) => instrs
  }
  match instrs[0] {
    // Must stay a cast, not a trap
    TRefCast(_, _, _) => ()
    _ => fail("cast must not collapse when traps may happen")
  }
}

///|
test "non-bottom refinement allowed even when traps may happen" {
  let instr = TInstr::ref_cast(
    true,
    HeapType::new(TypeIdx::new(0)),
    TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
  )
  let mapping = Map::new()
  mapping.set(HeapType::new(TypeIdx::new(0)), HeapType::new(TypeIdx::new(1)))
  let rewritten = rewrite_cast(instr, mapping)
  match rewritten {
    TRefCast(_, ht, _) => assert_eq(ht, HeapType::new(TypeIdx::new(1)))
    _ => fail("expected safe refinement")
  }
}

///|
test "exact br_on_cast not rewritten when traps may happen" {
  let instr = TInstr::br_on_cast(
    LabelIdx::new(0),
    true,
    HeapType::new(TypeIdx::new(0)),
    true,
    HeapType::new(TypeIdx::new(0)),
    TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
    [],
  )
  let mapping = Map::new()
  mapping.set(HeapType::new(TypeIdx::new(0)), HeapType::new(TypeIdx::new(2)))
  let rewritten = rewrite_descriptor_exact_br_on_cast(instr, mapping, false)
  match rewritten {
    TBrOnCast(_, op, _, dst, _, _) => {
      assert_true(op.1) // target nullability is unchanged
      assert_eq(dst, HeapType::new(TypeIdx::new(0)))
    }
    _ => fail("unexpected rewrite")
  }
}

///|
test "mixed exact br_on_cast_fail does not gain success" {
  let exact_heap = HeapType::new(TypeIdx::new(0))
  let instr = TInstr::br_on_cast_fail(
    LabelIdx::new(0),
    true,
    exact_heap,
    false,
    exact_heap,
    TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
    [],
  )
  let mapping = Map::new()
  mapping.set(exact_heap, HeapType::new(TypeIdx::new(2)))
  let rewritten = rewrite_descriptor_exact_br_on_cast(instr, mapping, true)
  match rewritten {
    TBrOnCastFail(_, op, _, dst, _, _) => {
      assert_true(!op.1)
      assert_eq(dst, HeapType::bottom())
    }
    _ => fail("unexpected rewrite")
  }
}

///|
test "mixed exact br_on_cast_fail preserved when traps may happen" {
  let exact_heap = HeapType::new(TypeIdx::new(0))
  let instr = TInstr::br_on_cast_fail(
    LabelIdx::new(0),
    true,
    exact_heap,
    false,
    exact_heap,
    TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
    [],
  )
  let mapping = Map::new()
  mapping.set(exact_heap, HeapType::new(TypeIdx::new(2)))
  let rewritten = rewrite_descriptor_exact_br_on_cast(instr, mapping, false)
  match rewritten {
    TBrOnCastFail(_, op, _, dst, _, _) => {
      assert_true(!op.1)
      assert_eq(dst, exact_heap)
    }
    _ => fail("unexpected rewrite")
  }
}

///|
test "mixed non-exact br_on_cast_fail normalization mirrors br_on_cast" {
  let src = HeapType::new(TypeIdx::new(0))
  let dst = HeapType::new(TypeIdx::new(1))
  let rewritten_src = HeapType::new(TypeIdx::new(2))
  let rewritten_dst = HeapType::new(TypeIdx::new(3))
  let mapping = Map::new()
  mapping.set(src, rewritten_src)
  mapping.set(dst, rewritten_dst)

  let cast = rewrite_descriptor_exact_br_on_cast(
    rewrite_cast(
      TInstr::br_on_cast(
        LabelIdx::new(0),
        true,
        src,
        false,
        dst,
        TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
        [],
      ),
      mapping,
    ),
    mapping,
    true,
  )
  let cast_fail = rewrite_descriptor_exact_br_on_cast(
    rewrite_cast(
      TInstr::br_on_cast_fail(
        LabelIdx::new(0),
        true,
        src,
        false,
        dst,
        TInstr::ref_null(HeapType::abs(AbsHeapType::any())),
        [],
      ),
      mapping,
    ),
    mapping,
    true,
  )

  match cast {
    TBrOnCast(_, _, next_src, next_dst, _, _) => {
      assert_eq(next_src, rewritten_src)
      assert_eq(next_dst, rewritten_dst)
    }
    _ => fail("expected br_on_cast normalization result")
  }
  match cast_fail {
    TBrOnCastFail(_, _, next_src, next_dst, _, _) => {
      assert_eq(next_src, rewritten_src)
      assert_eq(next_dst, rewritten_dst)
    }
    _ => fail("expected br_on_cast_fail normalization result")
  }
}

///|
fn atr_mixed_branch_parity_module() -> Module {
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(comp_type_sub_type(struct_comp_type([])))]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::br_on_cast(
              LabelIdx::new(0),
              true,
              exact_ht,
              false,
              exact_ht,
              TInstr::ref_null(exact_ht),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast(
              LabelIdx::new(0),
              true,
              any_ht,
              false,
              exact_ht,
              TInstr::ref_null(any_ht),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast_fail(
              LabelIdx::new(0),
              true,
              exact_ht,
              false,
              exact_ht,
              TInstr::ref_null(exact_ht),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast_fail(
              LabelIdx::new(0),
              true,
              any_ht,
              false,
              exact_ht,
              TInstr::ref_null(any_ht),
              [],
            ),
          ),
        ]),
      ),
    ]),
  )
}

///|
test "full pass mixed branch parity under traps_never_happen" {
  let out = run_abstract_type_refining_pass(atr_mixed_branch_parity_module(), {
    traps_never_happen: true,
  })
  let CodeSec(funcs) = out.unwrap().code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("expected typed function")
    TFunc(_, TExpr(items)) => items
  }
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  match instrs {
    [
      TDrop(TBrOnCast(_, op_exact, src_exact, dst_exact, _, _)),
      TDrop(TBrOnCast(_, op_non_exact, src_non_exact, dst_non_exact, _, _)),
      TDrop(
        TBrOnCastFail(_, op_fail_exact, src_fail_exact, dst_fail_exact, _, _)
      ),
      TDrop(
        TBrOnCastFail(
          _,
          op_fail_non_exact,
          src_fail_non_exact,
          dst_fail_non_exact,
          _,
          _
        )
      ),
    ] => {
      assert_eq(src_exact, HeapType::bottom())
      assert_true(!op_exact.1)
      assert_eq(dst_exact, HeapType::bottom())

      assert_eq(src_non_exact, any_ht)
      assert_true(!op_non_exact.1)
      assert_eq(dst_non_exact, HeapType::bottom())

      assert_eq(src_fail_exact, HeapType::bottom())
      assert_true(!op_fail_exact.1)
      assert_eq(dst_fail_exact, HeapType::bottom())

      assert_eq(src_fail_non_exact, any_ht)
      assert_true(!op_fail_non_exact.1)
      assert_eq(dst_fail_non_exact, HeapType::bottom())
    }
    _ => fail("expected mixed branch parity fixture shape")
  }
  // Ensure exactness remained source/destination-type based, not nullability-based.
  assert_true(exact_ht != any_ht)
}

///|
test "full pass mixed branch parity when traps may happen" {
  let out = run_abstract_type_refining_pass(atr_mixed_branch_parity_module(), {
    traps_never_happen: false,
  })
  let CodeSec(funcs) = out.unwrap().code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("expected typed function")
    TFunc(_, TExpr(items)) => items
  }
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  match instrs {
    [
      TDrop(TBrOnCast(_, op_exact, src_exact, dst_exact, _, _)),
      TDrop(TBrOnCast(_, op_non_exact, src_non_exact, dst_non_exact, _, _)),
      TDrop(
        TBrOnCastFail(_, op_fail_exact, src_fail_exact, dst_fail_exact, _, _)
      ),
      TDrop(
        TBrOnCastFail(
          _,
          op_fail_non_exact,
          src_fail_non_exact,
          dst_fail_non_exact,
          _,
          _
        )
      ),
    ] => {
      assert_true(!op_exact.1)
      assert_eq(src_exact, exact_ht)
      assert_eq(dst_exact, exact_ht)

      assert_true(!op_non_exact.1)
      assert_eq(src_non_exact, any_ht)
      assert_eq(dst_non_exact, exact_ht)

      assert_true(!op_fail_exact.1)
      assert_eq(src_fail_exact, exact_ht)
      assert_eq(dst_fail_exact, exact_ht)

      assert_true(!op_fail_non_exact.1)
      assert_eq(src_fail_non_exact, any_ht)
      assert_eq(dst_fail_non_exact, exact_ht)
    }
    _ => fail("expected mixed branch parity fixture shape")
  }
}

///|
fn atr_nested_value_tree_module() -> Module {
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(comp_type_sub_type(struct_comp_type([])))]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::ref_type(RefType::new(true, any_ht))],
        TExpr::new([
          TInstr::local_set(
            LocalIdx::new(0),
            TInstr::br_on_cast(
              LabelIdx::new(0),
              true,
              exact_ht,
              false,
              exact_ht,
              TInstr::ref_null(exact_ht),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast_fail(
              LabelIdx::new(0),
              true,
              exact_ht,
              false,
              exact_ht,
              TInstr::ref_null(exact_ht),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast_fail(
              LabelIdx::new(0),
              true,
              any_ht,
              false,
              exact_ht,
              TInstr::ref_null(any_ht),
              [],
            ),
          ),
        ]),
      ),
    ]),
  )
}

///|
test "full pass rewrites nested branch casts in value trees under traps_never_happen" {
  let out = run_abstract_type_refining_pass(atr_nested_value_tree_module(), {
    traps_never_happen: true,
  })
  let CodeSec(funcs) = out.unwrap().code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("expected typed function")
    TFunc(_, TExpr(items)) => items
  }
  let any_ht = HeapType::abs(AbsHeapType::any())
  match instrs {
    [
      TLocalSet(_, TBrOnCast(_, op_cast, src_cast, dst_cast, _, _)),
      TDrop(TBrOnCastFail(_, op_exact, src_exact, dst_exact, _, _)),
      TDrop(TBrOnCastFail(_, op_non_exact, src_non_exact, dst_non_exact, _, _)),
    ] => {
      assert_eq(src_cast, HeapType::bottom())
      assert_true(!op_cast.1)
      assert_eq(dst_cast, HeapType::bottom())

      assert_eq(src_exact, HeapType::bottom())
      assert_true(!op_exact.1)
      assert_eq(dst_exact, HeapType::bottom())

      assert_eq(src_non_exact, any_ht)
      assert_true(!op_non_exact.1)
      assert_eq(dst_non_exact, HeapType::bottom())
    }
    _ => fail("expected nested value-tree branch-cast fixture shape")
  }
}

///|
test "full pass preserves nested branch casts in value trees when traps may happen" {
  let out = run_abstract_type_refining_pass(atr_nested_value_tree_module(), {
    traps_never_happen: false,
  })
  let CodeSec(funcs) = out.unwrap().code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("expected typed function")
    TFunc(_, TExpr(items)) => items
  }
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  match instrs {
    [
      TLocalSet(_, TBrOnCast(_, op_cast, src_cast, dst_cast, _, _)),
      TDrop(TBrOnCastFail(_, op_exact, src_exact, dst_exact, _, _)),
      TDrop(TBrOnCastFail(_, op_non_exact, src_non_exact, dst_non_exact, _, _)),
    ] => {
      assert_true(!op_cast.1)
      assert_eq(src_cast, exact_ht)
      assert_eq(dst_cast, exact_ht)

      assert_true(!op_exact.1)
      assert_eq(src_exact, exact_ht)
      assert_eq(dst_exact, exact_ht)

      assert_true(!op_non_exact.1)
      assert_eq(src_non_exact, any_ht)
      assert_eq(dst_non_exact, exact_ht)
    }
    _ => fail("expected nested value-tree branch-cast fixture shape")
  }
}

///|
fn atr_deep_nested_control_value_module() -> Module {
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(comp_type_sub_type(struct_comp_type([])))]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::if_(
              BlockType::val_type(ValType::ref_null(exact_ht)),
              TInstr::i32_const(I32(1)),
              TExpr::new([
                TInstr::block(
                  BlockType::val_type(ValType::ref_null(exact_ht)),
                  TExpr::new([
                    TInstr::try_table(
                      BlockType::val_type(ValType::ref_null(exact_ht)),
                      [],
                      TExpr::new([
                        TInstr::drop(
                          TInstr::br_on_cast(
                            LabelIdx::new(1),
                            true,
                            exact_ht,
                            false,
                            exact_ht,
                            TInstr::ref_null(exact_ht),
                            [],
                          ),
                        ),
                        TInstr::ref_null(exact_ht),
                      ]),
                    ),
                  ]),
                ),
              ]),
              Some(
                TExpr::new([
                  TInstr::block(
                    BlockType::val_type(ValType::ref_null(exact_ht)),
                    TExpr::new([
                      TInstr::try_table(
                        BlockType::val_type(ValType::ref_null(exact_ht)),
                        [],
                        TExpr::new([
                          TInstr::drop(
                            TInstr::br_on_cast_fail(
                              LabelIdx::new(1),
                              true,
                              any_ht,
                              false,
                              exact_ht,
                              TInstr::ref_null(any_ht),
                              [],
                            ),
                          ),
                          TInstr::ref_null(exact_ht),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    ]),
  )
}

///|
test "full pass rewrites deep if/block/try_table value trees under traps_never_happen" {
  let out = run_abstract_type_refining_pass(
    atr_deep_nested_control_value_module(),
    { traps_never_happen: true },
  )
  let CodeSec(funcs) = out.unwrap().code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("expected typed function")
    TFunc(_, TExpr(items)) => items
  }
  let any_ht = HeapType::abs(AbsHeapType::any())
  match instrs {
    [
      TDrop(
        TIf(
          _,
          _,
          TExpr(
            [
              TBlock(
                _,
                TExpr(
                  [
                    TTryTable(
                      _,
                      _,
                      TExpr(
                        [
                          TDrop(TBrOnCast(_, op_then, src_then, dst_then, _, _)),
                          _,
                        ]
                      )
                    ),
                  ]
                )
              ),
            ]
          ),
          Some(
            TExpr(
              [
                TBlock(
                  _,
                  TExpr(
                    [
                      TTryTable(
                        _,
                        _,
                        TExpr(
                          [
                            TDrop(
                              TBrOnCastFail(
                                _,
                                op_else,
                                src_else,
                                dst_else,
                                _,
                                _
                              )
                            ),
                            _,
                          ]
                        )
                      ),
                    ]
                  )
                ),
              ]
            )
          )
        )
      ),
    ] => {
      assert_eq(src_then, HeapType::bottom())
      assert_true(!op_then.1)
      assert_eq(dst_then, HeapType::bottom())

      assert_eq(src_else, any_ht)
      assert_true(!op_else.1)
      assert_eq(dst_else, HeapType::bottom())
    }
    _ => fail("expected deep nested control/value fixture shape")
  }
}

///|
test "full pass preserves deep if/block/try_table value trees when traps may happen" {
  let out = run_abstract_type_refining_pass(
    atr_deep_nested_control_value_module(),
    { traps_never_happen: false },
  )
  let CodeSec(funcs) = out.unwrap().code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("expected typed function")
    TFunc(_, TExpr(items)) => items
  }
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  match instrs {
    [
      TDrop(
        TIf(
          _,
          _,
          TExpr(
            [
              TBlock(
                _,
                TExpr(
                  [
                    TTryTable(
                      _,
                      _,
                      TExpr(
                        [
                          TDrop(TBrOnCast(_, op_then, src_then, dst_then, _, _)),
                          _,
                        ]
                      )
                    ),
                  ]
                )
              ),
            ]
          ),
          Some(
            TExpr(
              [
                TBlock(
                  _,
                  TExpr(
                    [
                      TTryTable(
                        _,
                        _,
                        TExpr(
                          [
                            TDrop(
                              TBrOnCastFail(
                                _,
                                op_else,
                                src_else,
                                dst_else,
                                _,
                                _
                              )
                            ),
                            _,
                          ]
                        )
                      ),
                    ]
                  )
                ),
              ]
            )
          )
        )
      ),
    ] => {
      assert_true(!op_then.1)
      assert_eq(src_then, exact_ht)
      assert_eq(dst_then, exact_ht)

      assert_true(!op_else.1)
      assert_eq(src_else, any_ht)
      assert_eq(dst_else, exact_ht)
    }
    _ => fail("expected deep nested control/value fixture shape")
  }
}

///|
fn atr_handler_nested_control_module() -> Module {
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(comp_type_sub_type(struct_comp_type([]))),
      t_void,
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::if_(
              BlockType::val_type(ValType::ref_null(exact_ht)),
              TInstr::i32_const(I32(1)),
              TExpr::new([
                TInstr::block(
                  BlockType::val_type(ValType::ref_null(exact_ht)),
                  TExpr::new([
                    TInstr::try_table(
                      BlockType::void_(),
                      [Catch::all(LabelIdx::new(0))],
                      TExpr::new([
                        TInstr::drop(
                          TInstr::br_on_cast(
                            LabelIdx::new(0),
                            true,
                            exact_ht,
                            false,
                            exact_ht,
                            TInstr::ref_null(exact_ht),
                            [],
                          ),
                        ),
                      ]),
                    ),
                    TInstr::ref_null(exact_ht),
                  ]),
                ),
              ]),
              Some(
                TExpr::new([
                  TInstr::block(
                    BlockType::val_type(ValType::ref_null(exact_ht)),
                    TExpr::new([
                      TInstr::try_table(
                        BlockType::void_(),
                        [Catch::all(LabelIdx::new(0))],
                        TExpr::new([
                          TInstr::drop(
                            TInstr::br_on_cast_fail(
                              LabelIdx::new(0),
                              true,
                              any_ht,
                              false,
                              exact_ht,
                              TInstr::ref_null(any_ht),
                              [],
                            ),
                          ),
                        ]),
                      ),
                      TInstr::ref_null(exact_ht),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    ]),
  )
}

///|
test "full pass rewrites deep handler-bearing nested casts under traps_never_happen" {
  let out = run_abstract_type_refining_pass(
    atr_handler_nested_control_module(),
    { traps_never_happen: true },
  )
  let optimized = out.unwrap()
  let CodeSec(funcs) = optimized.code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("expected typed function")
    TFunc(_, TExpr(items)) => items
  }
  let any_ht = HeapType::abs(AbsHeapType::any())
  match instrs {
    [
      TDrop(
        TIf(
          _,
          _,
          TExpr(
            [
              TBlock(
                _,
                TExpr(
                  [
                    TTryTable(
                      _,
                      catches_then,
                      TExpr(
                        [TDrop(TBrOnCast(_, op_then, src_then, dst_then, _, _))]
                      )
                    ),
                    _,
                  ]
                )
              ),
            ]
          ),
          Some(
            TExpr(
              [
                TBlock(
                  _,
                  TExpr(
                    [
                      TTryTable(
                        _,
                        catches_else,
                        TExpr(
                          [
                            TDrop(
                              TBrOnCastFail(
                                _,
                                op_else,
                                src_else,
                                dst_else,
                                _,
                                _
                              )
                            ),
                          ]
                        )
                      ),
                      _,
                    ]
                  )
                ),
              ]
            )
          )
        )
      ),
    ] => {
      match catches_then {
        [CatchAll(_)] => ()
        _ => fail("expected non-empty catch list in then try_table")
      }
      match catches_else {
        [CatchAll(_)] => ()
        _ => fail("expected non-empty catch list in else try_table")
      }
      assert_eq(src_then, HeapType::bottom())
      assert_true(!op_then.1)
      assert_eq(dst_then, HeapType::bottom())

      assert_eq(src_else, any_ht)
      assert_true(!op_else.1)
      assert_eq(dst_else, HeapType::bottom())
    }
    _ => fail("expected deep handler-bearing nested fixture shape")
  }
}

///|
test "full pass preserves deep handler-bearing nested casts when traps may happen" {
  let out = run_abstract_type_refining_pass(
    atr_handler_nested_control_module(),
    { traps_never_happen: false },
  )
  let optimized = out.unwrap()
  let CodeSec(funcs) = optimized.code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("expected typed function")
    TFunc(_, TExpr(items)) => items
  }
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  match instrs {
    [
      TDrop(
        TIf(
          _,
          _,
          TExpr(
            [
              TBlock(
                _,
                TExpr(
                  [
                    TTryTable(
                      _,
                      catches_then,
                      TExpr(
                        [TDrop(TBrOnCast(_, op_then, src_then, dst_then, _, _))]
                      )
                    ),
                    _,
                  ]
                )
              ),
            ]
          ),
          Some(
            TExpr(
              [
                TBlock(
                  _,
                  TExpr(
                    [
                      TTryTable(
                        _,
                        catches_else,
                        TExpr(
                          [
                            TDrop(
                              TBrOnCastFail(
                                _,
                                op_else,
                                src_else,
                                dst_else,
                                _,
                                _
                              )
                            ),
                          ]
                        )
                      ),
                      _,
                    ]
                  )
                ),
              ]
            )
          )
        )
      ),
    ] => {
      match catches_then {
        [CatchAll(_)] => ()
        _ => fail("expected non-empty catch list in then try_table")
      }
      match catches_else {
        [CatchAll(_)] => ()
        _ => fail("expected non-empty catch list in else try_table")
      }
      assert_true(!op_then.1)
      assert_eq(src_then, exact_ht)
      assert_eq(dst_then, exact_ht)

      assert_true(!op_else.1)
      assert_eq(src_else, any_ht)
      assert_eq(dst_else, exact_ht)
    }
    _ => fail("expected deep handler-bearing nested fixture shape")
  }
}

///|
fn atr_handler_throwing_validator_clean_module() -> Module {
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(comp_type_sub_type(struct_comp_type([]))),
      t_void,
    ]),
  )
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(1))]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::if_(
              BlockType::val_type(ValType::ref_null(exact_ht)),
              TInstr::i32_const(I32(1)),
              TExpr::new([
                TInstr::block(
                  BlockType::val_type(ValType::ref_null(exact_ht)),
                  TExpr::new([
                    TInstr::try_table(
                      BlockType::void_(),
                      [Catch::all(LabelIdx::new(0))],
                      TExpr::new([
                        TInstr::ref_cast(
                          true,
                          exact_ht,
                          TInstr::ref_null(any_ht),
                        ),
                        TInstr::throw_(TagIdx::new(0), []),
                      ]),
                    ),
                    TInstr::ref_null(exact_ht),
                  ]),
                ),
              ]),
              Some(
                TExpr::new([
                  TInstr::block(
                    BlockType::val_type(ValType::ref_null(exact_ht)),
                    TExpr::new([
                      TInstr::try_table(
                        BlockType::void_(),
                        [Catch::all(LabelIdx::new(0))],
                        TExpr::new([
                          TInstr::ref_cast(
                            true,
                            exact_ht,
                            TInstr::ref_null(any_ht),
                          ),
                          TInstr::throw_(TagIdx::new(0), []),
                        ]),
                      ),
                      TInstr::ref_null(exact_ht),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn atr_count_handler_try_tables(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TTryTable(_, catches, _) => if !catches.is_empty() { count += 1 }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
fn atr_count_throw_instrs(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TThrow(_, _) => count += 1
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
fn atr_count_ref_cast_instrs(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TRefCast(_, _, _) => count += 1
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
fn atr_count_catch_new(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TTryTable(_, catches, _) =>
        for c in catches {
          match c {
            Catch(_, _) => count += 1
            _ => ()
          }
        }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
fn atr_count_catch_ref(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TTryTable(_, catches, _) =>
        for c in catches {
          match c {
            CatchRef(_, _) => count += 1
            _ => ()
          }
        }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
fn atr_collect_throw_arg_counts(body : TExpr) -> Array[Int] {
  let out : Array[Int] = []
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TThrow(_, args) => out.push(args.length())
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  out
}

///|
fn atr_count_drop_void_block(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TDrop(TBlock(VoidBlockType, _)) => count += 1
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
fn atr_typed_payload_catch_module() -> Module {
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  let exn_ref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let t_tag_i32 = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [])),
  )
  let t_tag_i64 = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i64()], [])),
  )
  let t_i64_exn = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i64(), exn_ref])),
  )
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(comp_type_sub_type(struct_comp_type([]))),
      t_void,
      t_tag_i32,
      t_tag_i64,
      t_i64_exn,
    ]),
  )
  .with_tag_sec(
    TagSec::new([TagType::new(TypeIdx::new(2)), TagType::new(TypeIdx::new(3))]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(4)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::try_table(
              BlockType::val_type(ValType::i32()),
              [Catch::new(TagIdx::new(0), LabelIdx::new(0))],
              TExpr::new([
                TInstr::ref_cast(true, exact_ht, TInstr::ref_null(any_ht)),
                TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(7))]),
              ]),
            ),
          ),
        ]),
      ),
      Func::t_func(
        [],
        TExpr::new([
          TInstr::try_table(
            BlockType::type_idx(TypeIdx::new(4)),
            [Catch::ref_(TagIdx::new(1), LabelIdx::new(1))],
            TExpr::new([
              TInstr::ref_cast(true, exact_ht, TInstr::ref_null(any_ht)),
              TInstr::throw_(TagIdx::new(1), [TInstr::i64_const(I64(9L))]),
            ]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn atr_drop_ref_cast_module() -> Module {
  let exact_ht = HeapType::new(TypeIdx::new(0))
  let any_ht = HeapType::abs(AbsHeapType::any())
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(comp_type_sub_type(struct_comp_type([]))),
      t_void,
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::ref_cast(true, exact_ht, TInstr::ref_null(any_ht)),
          ),
        ]),
      ),
    ]),
  )
}

///|
test "full pass validator-clean deep handler-bearing fixture validates" {
  let tnh = run_abstract_type_refining_pass(
    atr_handler_throwing_validator_clean_module(),
    { traps_never_happen: true },
  )
  let default_mode = run_abstract_type_refining_pass(
    atr_handler_throwing_validator_clean_module(),
    { traps_never_happen: false },
  )
  let tnh_mod = tnh.unwrap()
  let default_mod = default_mode.unwrap()
  assert_eq(validate_module(tnh_mod), Ok(()))
  assert_eq(validate_module(default_mod), Ok(()))
}

///|
test "full pass handler-bearing throw paths preserve catches and stable cast rewrites" {
  let tnh = run_abstract_type_refining_pass(
    atr_handler_throwing_validator_clean_module(),
    { traps_never_happen: true },
  )
  let default_mode = run_abstract_type_refining_pass(
    atr_handler_throwing_validator_clean_module(),
    { traps_never_happen: false },
  )
  let tnh_body = match tnh.unwrap().code_sec.unwrap() {
    CodeSec([TFunc(_, body)]) => body
    _ => fail("expected transformed typed function body for traps_never_happen")
  }
  let default_body = match default_mode.unwrap().code_sec.unwrap() {
    CodeSec([TFunc(_, body)]) => body
    _ => fail("expected transformed typed function body for default trap mode")
  }
  assert_eq(atr_count_handler_try_tables(tnh_body), 2)
  assert_eq(atr_count_handler_try_tables(default_body), 2)
  assert_eq(atr_count_throw_instrs(tnh_body), 2)
  assert_eq(atr_count_throw_instrs(default_body), 2)
  assert_eq(atr_count_ref_cast_instrs(default_body), 2)
  assert_eq(atr_count_ref_cast_instrs(tnh_body), 0)
}

///|
test "full pass typed payload catches validate and keep catch signatures stable" {
  let tnh = run_abstract_type_refining_pass(atr_typed_payload_catch_module(), {
    traps_never_happen: true,
  })
  let default_mode = run_abstract_type_refining_pass(
    atr_typed_payload_catch_module(),
    { traps_never_happen: false },
  )
  let tnh_mod = tnh.unwrap()
  let default_mod = default_mode.unwrap()
  assert_eq(validate_module(tnh_mod), Ok(()))
  assert_eq(validate_module(default_mod), Ok(()))
  match tnh_mod.code_sec {
    Some(CodeSec([TFunc(_, body0), TFunc(_, body1)])) => {
      assert_eq(atr_count_catch_new(body0), 1)
      assert_eq(atr_count_catch_ref(body0), 0)
      assert_eq(atr_collect_throw_arg_counts(body0), [1])
      assert_eq(atr_count_catch_new(body1), 0)
      assert_eq(atr_count_catch_ref(body1), 1)
      assert_eq(atr_collect_throw_arg_counts(body1), [1])
      assert_eq(atr_count_ref_cast_instrs(body0), 0)
      assert_eq(atr_count_ref_cast_instrs(body1), 0)
    }
    _ =>
      fail("expected typed payload catch fixture bodies in traps-never-happen")
  }
  match default_mod.code_sec {
    Some(CodeSec([TFunc(_, body0), TFunc(_, body1)])) => {
      assert_eq(atr_count_catch_new(body0), 1)
      assert_eq(atr_count_catch_ref(body0), 0)
      assert_eq(atr_collect_throw_arg_counts(body0), [1])
      assert_eq(atr_count_catch_new(body1), 0)
      assert_eq(atr_count_catch_ref(body1), 1)
      assert_eq(atr_collect_throw_arg_counts(body1), [1])
      assert_eq(atr_count_ref_cast_instrs(body0), 1)
      assert_eq(atr_count_ref_cast_instrs(body1), 1)
    }
    _ =>
      fail("expected typed payload catch fixture bodies in default trap mode")
  }
}

///|
test "full pass exact ref_cast under drop remains validator-clean in traps_never_happen mode" {
  let tnh = run_abstract_type_refining_pass(atr_drop_ref_cast_module(), {
    traps_never_happen: true,
  })
  let tnh_mod = tnh.unwrap()
  assert_eq(validate_module(tnh_mod), Ok(()))
  match tnh_mod.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(atr_count_ref_cast_instrs(body), 0)
      assert_eq(atr_count_drop_void_block(body), 0)
    }
    _ => fail("expected drop-cast fixture body")
  }
}
