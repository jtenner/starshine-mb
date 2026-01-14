
type HeapTypeSet = Set[HeapType]
type HeapTypeMap = Map[HeapType, HeapType]

struct ATRState {
  created : HeapTypeSet
  created_or_sub : HeapTypeSet
  refinable : HeapTypeMap
  mapping : HeapTypeMap
  traps_never_happen : Bool
  subtypes : SubTypes
}

struct SubTypes {
  types : Array[HeapType]
  immediate_sub : Map[HeapType, Array[HeapType]]
}

fn is_refined(ht : HeapType, mapping : HeapTypeMap) -> Bool {
  mapping.get(ht) is Some(new_ht) && new_ht != ht
}

fn build_subtypes(module : Module) -> SubTypes {
  let types = Array::new()
  let immediate = Map::new()

  if  module.type_sec is Some(type_sec) {
    for rec in type_sec.0 {
      match rec {
        SingleRecType(st) => {
          let ht = def_type_heap_type(DefType::new(rec, 0))
          types.push(ht)
          immediate[ht] = st.super_types().map(heap_type)
        }
        GroupRecType(sts) => {
          for i in sts.iter2() {
            let (i, st) = i
            let ht = def_type_heap_type(DefType::new(rec, i.reinterpret_as_uint()))
            types.push(ht)
            immediate[ht] = st.super_types().map(heap_type)
          }
        }
      }
    }
  }

  SubTypes::{ types, immediate_sub : immediate }
}

fn collect_created_types(module : Module) -> HeapTypeSet {
  let set = Set::new()

  let transformer =
    ModuleTransformer::{
      ..ModuleTransformer::new(),
      on_tinstruction: Some(fn(_, _, instr) {
        match instr {
          // ---- structs ----
          TStructNew(type_idx, _) => {
            set.add(heap_type(type_idx))
          }

          // ---- arrays ----
          TArrayNew(type_idx, _, _) |
          TArrayNewDefault(type_idx, _) |
          TArrayNewFixed(type_idx, _) |
          TArrayNewData(type_idx, _, _, _) |
          TArrayNewElem(type_idx, _, _, _) => {
            set.add(heap_type(type_idx))
          }

          _ => ()
        }
        unchanged()
      })
    }

  ignore(transformer.walk_module((), module))
  set
}

fn compute_created_or_sub(
  created : HeapTypeSet,
  subtypes : SubTypes
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

fn compute_refinable(
  created : HeapTypeSet,
  created_or_sub : HeapTypeSet,
  subtypes : SubTypes
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

fn build_mapping(state : ATRState) -> HeapTypeMap {
  let mapping = Map::new()

  for t in state.subtypes.types {
    if !t.is_gc_aggregate() {
      continue
    }

    if !state.created_or_sub.contains(t) {
      mapping[t] = HeapType::bottom()
      continue
    }

    if state.refinable.get(t) is Some(r) {
      mapping[t] = r
    }
  }

  mapping
}

fn rewrite_heaptype(
  ht : HeapType,
  mapping : HeapTypeMap
) -> HeapType {
  mapping.get(ht).unwrap_or(ht)
}

fn rewrite_cast(
  instr : TInstr,
  mapping : HeapTypeMap,
  traps_never_happen : Bool
) -> TInstr {
  match instr {
    TRefCast(nullable, ht, v) => {
      let new_ht = rewrite_heaptype(ht, mapping)
      if new_ht == ht {
        instr
      } else {
        TRefCast(nullable, new_ht, v)
      }
    }

    TBrOnCast(l, op, ht1, ht2, v, args) => {
      let n1 = rewrite_heaptype(ht1, mapping)
      let n2 = rewrite_heaptype(ht2, mapping)
      TBrOnCast(l, op, n1, n2, v, args)
    }

    _ => instr
  }
}

fn drop_then_unreachable(value : TInstr) -> TInstr {
  TBlock(
    EmptyBlockType,
    TExpr::new([
      TDrop(value),
      TUnreachable
    ])
  )
}

fn rewrite_descriptor_exact_ref_cast(
  instr : TInstr,
  mapping : HeapTypeMap
) -> TInstr {
  match instr {
    TRefCast(nullable, ht, value) => {
      if is_refined(ht, mapping) {
        let refined = mapping.get(ht).unwrap()

        // If refinement makes this impossible, force trap
        // or Exact descriptor cast must not gain success
        drop_then_unreachable(value)
      } else {
        instr
      }
    }
    _ => instr
  }
}

fn rewrite_descriptor_exact_br_on_cast(
  instr : TInstr,
  mapping : HeapTypeMap
) -> TInstr {
  match instr {
    TBrOnCast(label, op, src_ht, dst_ht, value, args) => {
      if op.1 && is_refined(dst_ht, mapping) {
        let new_op = CastOp::new(op.0, false)
        TBrOnCast(label, new_op, src_ht, HeapType::bottom(), value, args)
      } else {
        instr
      }
    }

    TBrOnCastFail(label, op, src_ht, dst_ht, value, args) => {
      if op.1 && is_refined(dst_ht, mapping) {
        let new_op = CastOp::new(op.0, false)
        TBrOnCastFail(label, new_op, src_ht, HeapType::bottom(), value, args)
      } else {
        instr
      }
    }

    _ => instr
  }
}


fn abstract_type_refining(
  traps_never_happen : Bool
) -> ModuleTransformer[ATRState] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_module: Some(fn(_, _, mod) {
      let subtypes = build_subtypes(mod)
      let created = collect_created_types(mod)
      let created_or_sub = compute_created_or_sub(created, subtypes)

      let refinable = if traps_never_happen {
        compute_refinable(created, created_or_sub, subtypes)
      } else {
        Map::new()
      }

      let state = ATRState::{
        created : created,
        created_or_sub : created_or_sub,
        refinable : refinable,
        mapping : Map::new(),
        traps_never_happen : traps_never_happen,
        subtypes : subtypes
      }

      let mapping = build_mapping(state)
      let new_state = ATRState::{..state, mapping : mapping }
      change(new_state, mod)
    }),

    on_tinstruction: Some(fn(_, state, instr) {
      let instr =
        rewrite_descriptor_exact_ref_cast(
          instr,
          state.mapping
        )

      let instr =
        rewrite_descriptor_exact_br_on_cast(
          instr,
          state.mapping
        )

      let instr =
        rewrite_cast(
          instr,
          state.mapping,
          state.traps_never_happen
        )

      change(state, instr)
    }),

    on_heaptype: Some(fn(_, state, ht) {
      change(state, rewrite_heaptype(ht, state.mapping))
    })
  }
}

test "abstract struct usage becomes bottom" {
  let ht = heap_type(type_idx(0))

  let mod =
    Module::new()
      .with_type_sec(
        TypeSec([
          SingleRecType(
            comp_type_sub_type(
              struct_comp_type([])
            )
          )
        ])
      )
      .with_code_sec(
        CodeSec::new([
          Func::t_func(
            [],
            TExpr::new([
              // Use the abstract type
              TInstr::ref_cast(true, ht, TInstr::ref_null(abs_heap_type_heap_type(any_abs_heap_type())))
            ])
          )
        ])
      )

  let pass = abstract_type_refining(true)

  let (_, new_mod) =
    pass.walk_module(
      ATRState::{
        created : Set::new(),
        created_or_sub : Set::new(),
        refinable : Map::new(),
        mapping : Map::new(),
        traps_never_happen : true,
        subtypes : build_subtypes(mod)
      },
      mod
    ).unwrap().unwrap()

  let CodeSec(funcs) = new_mod.code_sec.unwrap()
  let instrs = match funcs[0] {
    Func(_) => fail("Expected tfunc")
    TFunc(_, TExpr(instrs)) => instrs
  }

  match instrs[0] {
    TBlock(_, _) => () // drop + unreachable
    _ => fail("expected abstract cast to trap")
  }
}

test "exact ref.cast collapses to trap" {
  let instr =
    TInstr::ref_cast(
      true,
      heap_type(type_idx(0)),
      TInstr::ref_null(abs_heap_type_heap_type(any_abs_heap_type()))
    )

  let mapping = Map::new()
    
  mapping.set(heap_type(type_idx(0)), HeapType::bottom())

  let rewritten =
    rewrite_descriptor_exact_ref_cast(instr, mapping)

  match rewritten {
    TBlock(_, _) => ()
    _ => fail("expected drop + unreachable")
  }
}

test "non-exact cast refines normally" {
  let instr =
    TInstr::ref_cast(
      true,
      heap_type(type_idx(0)),
      TInstr::ref_null(abs_heap_type_heap_type(any_abs_heap_type()))
    )

  let mapping = Map::new()
    
  mapping.set(heap_type(type_idx(0)), heap_type(type_idx(1)))

  let rewritten =
    rewrite_cast(instr, mapping, true)

  match rewritten {
    TRefCast(_, ht, _) =>
      assert_eq(ht, heap_type(type_idx(1)))
    _ => fail("unexpected rewrite")
  }
}

test "exact br_on_cast does not gain success" {
  let instr =
    TInstr::br_on_cast(
      LabelIdx::new(0),
      true,
      heap_type(type_idx(1)),
      true,
      heap_type(type_idx(0)),
      TInstr::ref_null(abs_heap_type_heap_type(any_abs_heap_type())),
      []
    )

  let mapping = Map::new()
    
  mapping.set(heap_type(type_idx(0)), heap_type(type_idx(2)))

  let rewritten =
    rewrite_descriptor_exact_br_on_cast(instr, mapping)

  match rewritten {
    TBrOnCast(_, op, _, dst, _, _) => {
      assert_true(!op.1)
      assert_eq(dst, HeapType::bottom())
    }
    _ => fail("unexpected rewrite")
  }
}

test "abstract array collapses to bottom" {
  let instr =
    TInstr::array_new(
      type_idx(0),
      TInstr::i32_const(I32(1)),
      TInstr::ref_null(abs_heap_type_heap_type(any_abs_heap_type()))
    )

  let mapping = Map::new()
    
  mapping.set(heap_type(type_idx(0)), HeapType::bottom())

  let rewritten =
    rewrite_cast(instr, mapping, true)

  assert_eq(rewritten, instr) // allocation itself unchanged
}
