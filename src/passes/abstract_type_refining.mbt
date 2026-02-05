///|
type HeapTypeSet = Set[HeapType]

///|
type HeapTypeMap = Map[HeapType, HeapType]

pub (all) struct  AbstractTypeRefiningPassProps { traps_never_happen : Bool }

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
    _ => instr
  }
}

///|
fn drop_then_unreachable(value : TInstr) -> TInstr {
  TInstr::block(
    BlockType::void_(),
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
    TRefCast(_, ht, value) =>
      // Exact casts must not gain success.
      // After normalization, this is impossible iff:
      //   - the type is bottom, or
      //   - the type was refined to something else.
      if traps_never_happen &&
        (ht == HeapType::bottom() || is_refined(ht, mapping)) {
        drop_then_unreachable(value)
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
  match instr {
    TBrOnCast(label, op, src_ht, dst_ht, value, args) =>
      if traps_never_happen && op.1 && is_refined(dst_ht, mapping) {
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
      if traps_never_happen && op.1 && is_refined(dst_ht, mapping) {
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

fn run_abstract_type_refining_pass(
  mod : Module,
  props : AbstractTypeRefiningPassProps,
) -> Result[Module, String] {
  let ctx = IRContext::new()
  let mut mod = mod
  ctx.set_mod(mod)
  let pass = abstract_type_refining(mod, props.traps_never_happen)
  match pass.walk_module(ctx, mod) {
    Ok(Some((_, final_mod))) => {
      mod = final_mod
    }
    Ok(None) => ()
    Err(e) => return Err(e)
  }
  Ok(mod)
}

///|
fn abstract_type_refining(mod : Module, traps_never_happen : Bool) -> ModuleTransformer[IRContext] {
  let state = compute_atr_state(mod, traps_never_happen)
  ModuleTransformer::new()
  .on_tinstruction_evt(fn(_, ctx : IRContext, instr) {
    let instr = rewrite_cast(instr, state.mapping)
    let instr = rewrite_descriptor_exact_ref_cast(
      instr,
      state.mapping,
      state.traps_never_happen,
    )
    let instr = rewrite_descriptor_exact_br_on_cast(
      instr,
      state.mapping,
      state.traps_never_happen,
    )
    change(ctx, instr)
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
  let new_mod = run_abstract_type_refining_pass(mod, { traps_never_happen: true })
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
    HeapType::new(TypeIdx::new(1)),
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
      assert_true(!op.1) // exact → non-exact
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
    HeapType::new(TypeIdx::new(1)),
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
      assert_true(op.1) // still exact
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
  let new_mod = run_abstract_type_refining_pass(mod, { traps_never_happen: false })
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
    HeapType::new(TypeIdx::new(1)),
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
      assert_true(op.1) // still exact
      assert_eq(dst, HeapType::new(TypeIdx::new(0)))
    }
    _ => fail("unexpected rewrite")
  }
}
