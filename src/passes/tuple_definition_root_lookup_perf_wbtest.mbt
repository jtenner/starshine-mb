///|
// Test-owned pairing: use_def and revision are created from this exact func.
// No caller can supply a different func with a coincidentally equal revision.
priv struct TupleDefinitionLookupSnapshot {
  func : @ir.HotFunc
  use_def : @ir.HotUseDef
  revision : Int32
}

///|
fn TupleDefinitionLookupSnapshot::new(
  func : @ir.HotFunc,
) -> TupleDefinitionLookupSnapshot {
  let use_def = @ir.use_def_build(func)
  { func, use_def, revision: @ir.hot_revision_current(func), }
}

///|
fn tuple_definition_lookup_frozen_reference(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  defining_node : Int32,
  lane_idx : Int32,
) -> HotTupleOptimizationRootSlot? {
  let mut current = defining_node
  let mut remaining = @ir.hot_node_count(func)
  while remaining > 0 {
    remaining -= 1
    match
      tuple_optimization_find_root_slot_with_use_def(
        func, use_def, current, lane_idx,
      ) {
      Some(slot) => return Some(slot)
      None => ()
    }
    let sites = @ir.node_use_sites_borrowed(use_def, current)
    if sites.length() != 1 {
      return None
    }
    let site = sites[0]
    if !(site.kind is @ir.HotUseSlotKind::ChildUseSlot) || site.slot != 0 {
      return None
    }
    // Local/drop wrappers evaluate their sole operand first. A direct call
    // evaluates operand zero before its later operands and its call effect.
    match @ir.hot_node_get(func, site.user).op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee | @ir.HotOp::Drop =>
        if @ir.hot_child_count(func, site.user) != 1 {
          return None
        }
      @ir.HotOp::Call => ()
      _ => return None
    }
    current = site.user
  }
  None
}

///|
// Measurement candidate only. Revision mismatch must retain the full fallback.
// It is not used by production, whose split-local allocation also changes rev.
fn tuple_definition_lookup_fresh_candidate(
  snapshot : TupleDefinitionLookupSnapshot,
  target : Int32,
  lane : Int32,
) -> HotTupleOptimizationRootSlot? {
  let func = snapshot.func
  let use_def = snapshot.use_def
  if @ir.hot_revision_current(func) != snapshot.revision {
    return tuple_optimization_find_definition_root_slot(
      func, use_def, target, lane,
    )
  }
  let mut current = target
  let mut remaining = @ir.hot_node_count(func)
  while remaining > 0 {
    remaining -= 1
    let sites = @ir.node_use_sites_borrowed(use_def, current)
    for site in sites {
      if site.kind is @ir.HotUseSlotKind::RootUseSlot {
        return tuple_optimization_find_root_slot_with_use_def(
          func, use_def, current, lane,
        )
      }
    }
    if sites.length() != 1 {
      return None
    }
    let site = sites[0]
    if !(site.kind is @ir.HotUseSlotKind::ChildUseSlot) || site.slot != 0 {
      return None
    }
    match @ir.hot_node_get(func, site.user).op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee | @ir.HotOp::Drop =>
        if @ir.hot_child_count(func, site.user) != 1 {
          return None
        }
      @ir.HotOp::Call => ()
      _ => return None
    }
    current = site.user
  }
  None
}

///|
fn tuple_definition_lookup_fixture(
  roots : Int32,
  depth : Int32,
) -> (TupleDefinitionLookupSnapshot, Int32, Int32) {
  let func = @ir.HotFunc::new()
  let local = @ir.hot_append_body_local(func, @lib.ValType::i32())
  for _ in 0..<roots {
    @ir.hot_append_root(func, @ir.hot_build_nop(func))
  }
  let target = @ir.hot_build_local_tee(
    func,
    local,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let mut wrapper = target
  for _ in 1..<depth {
    wrapper = @ir.hot_build_local_tee(func, local, wrapper)
  }
  let root = @ir.hot_build_drop(func, wrapper)
  @ir.hot_append_root(func, root)
  (TupleDefinitionLookupSnapshot::new(func), target, root)
}

///|
fn tuple_definition_lookup_check(
  snapshot : TupleDefinitionLookupSnapshot,
  target : Int32,
  lane : Int32,
) -> HotTupleOptimizationRootSlot? raise {
  let expected = tuple_definition_lookup_frozen_reference(
    snapshot.func,
    snapshot.use_def,
    target,
    lane,
  )
  assert_eq(
    tuple_optimization_find_definition_root_slot(
      snapshot.func,
      snapshot.use_def,
      target,
      lane,
    ),
    expected,
  )
  assert_eq(
    tuple_definition_lookup_fresh_candidate(snapshot, target, lane),
    expected,
  )
  expected
}

///|
test "tuple definition root lookup matches its frozen reference with fresh owned use-def" {
  let (snapshot, target, root) = tuple_definition_lookup_fixture(4, 3)
  let revision = @ir.hot_revision_current(snapshot.func)
  let found = tuple_definition_lookup_check(snapshot, target, 2).unwrap()
  assert_eq(found.region_ref, @ir.HotRegionRef::root())
  assert_eq(found.slot, 4)
  assert_eq(found.lane_idx, 2)
  assert_eq(
    @ir.hot_region_get(snapshot.func, found.region_ref, found.slot),
    root,
  )
  assert_eq(@ir.hot_revision_current(snapshot.func), revision)
  @ir.hot_verify_core(snapshot.func).unwrap()
}

///|
test "tuple definition root lookup retains shifted-root fallback with stale use-def" {
  let (snapshot, target, root) = tuple_definition_lookup_fixture(4, 1)
  let func = snapshot.func
  @ir.hot_region_insert(func, @ir.HotRegionRef::root(), 0, [
    @ir.hot_build_nop(func),
  ])
  assert_true(@ir.hot_revision_current(func) != snapshot.revision)
  let found = tuple_definition_lookup_check(snapshot, target, 0).unwrap()
  assert_eq(found.slot, 5)
  let shifted = tuple_definition_lookup_check(snapshot, root, 1).unwrap()
  assert_eq(shifted.slot, 5)
  assert_eq(shifted.lane_idx, 1)
  @ir.hot_verify_core(func).unwrap()
}

///|
test "tuple definition root lookup treats split-local allocation as a stale revision" {
  let (snapshot, target, _) = tuple_definition_lookup_fixture(2, 1)
  let before = tuple_definition_lookup_check(snapshot, target, 0)
  ignore(@ir.hot_append_body_local(snapshot.func, @lib.ValType::i32()))
  assert_true(@ir.hot_revision_current(snapshot.func) != snapshot.revision)
  assert_eq(tuple_definition_lookup_check(snapshot, target, 0), before)
  @ir.hot_verify_core(snapshot.func).unwrap()
}

///|
fn tuple_definition_lookup_validate_i32(func : @ir.HotFunc) -> Unit raise {
  @ir.hot_verify_core(func).unwrap()
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)]))
  let decoded = @binary.decode_module(@binary.encode_module(mod_).unwrap()).unwrap()
  ignore(@validate.validate_module(decoded).unwrap())
  assert_eq(tuple_alias_capture_execute(decoded.code_sec.unwrap().0[0]), 7)
}

///|
test "tuple definition root lookup finds an original child extracted to a direct function root" {
  let (snapshot, target, _) = tuple_definition_lookup_fixture(2, 1)
  let func = snapshot.func
  let sites = @ir.node_use_sites_borrowed(snapshot.use_def, target)
  assert_eq(sites.length(), 1)
  assert_true(sites[0].kind is @ir.HotUseSlotKind::ChildUseSlot)
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  ignore(@ir.hot_region_set(func, @ir.HotRegionRef::root(), 2, target))
  let found = tuple_definition_lookup_check(snapshot, target, 0).unwrap()
  assert_eq(found.region_ref, @ir.HotRegionRef::root())
  assert_eq(found.slot, 2)
  tuple_definition_lookup_validate_i32(func)
}

///|
test "tuple definition root lookup finds an original root moved to another owner" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let local = @ir.hot_append_body_local(func, @lib.ValType::i32())
  let target = @ir.hot_build_local_tee(
    func,
    local,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let old_owner = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [target],
  )
  @ir.hot_append_root(func, old_owner)
  let snapshot = TupleDefinitionLookupSnapshot::new(func)
  let old_region = @ir.hot_region_body_ref(func, old_owner)
  ignore(
    @ir.hot_region_set(
      func,
      old_region,
      0,
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ),
  )
  let new_owner = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [target],
  )
  @ir.hot_root_set(func, 0, @ir.hot_build_drop(func, old_owner))
  @ir.hot_append_root(func, new_owner)
  let found = tuple_definition_lookup_check(snapshot, target, 0).unwrap()
  assert_eq(found.region_ref, @ir.hot_region_body_ref(func, new_owner))
  assert_eq(found.slot, 0)
  @ir.hot_region_insert(func, found.region_ref, 0, [@ir.hot_build_nop(func)])
  assert_eq(tuple_definition_lookup_check(snapshot, target, 0).unwrap().slot, 1)
  tuple_definition_lookup_validate_i32(func)
}

///|
test "tuple definition root lookup intentionally excludes a new control region below a value wrapper" {
  let (snapshot, target, _) = tuple_definition_lookup_fixture(2, 1)
  let func = snapshot.func
  let block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [target],
  )
  ignore(
    @ir.hot_region_set(
      func,
      @ir.HotRegionRef::root(),
      2,
      @ir.hot_build_drop(func, block),
    ),
  )
  @ir.hot_append_root(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  // This private finder walks control roots, not arbitrary operand subtrees.
  assert_eq(tuple_definition_lookup_check(snapshot, target, 0), None)
  tuple_definition_lookup_validate_i32(func)
}

///|
#skip("manual paired native-release definition-root lookup cost; no default stress")
test "tuple definition root lookup paired native raw samples" (it : @bench.T) {
  for roots in [64, 256, 1024] {
    for depth in [1, 4] {
      for stale in [false, true] {
        let (snapshot, target, _) = tuple_definition_lookup_fixture(
          roots, depth,
        )
        let func = snapshot.func
        if stale {
          @ir.hot_region_insert(func, @ir.HotRegionRef::root(), 0, [
            @ir.hot_build_nop(func),
          ])
        }
        let expected = tuple_definition_lookup_check(snapshot, target, 0)
        let revision = @ir.hot_revision_current(func)
        for sample in 0..<7 {
          for
            mode in (if sample % 2 == 0 { [0, 1, 2, 3] } else { [3, 2, 1, 0] }) {
            it.bench(
              fn() {
                for _ in 0..<1024 {
                  let result = match mode {
                    0 =>
                      tuple_optimization_find_definition_root_slot(
                        func,
                        snapshot.use_def,
                        target,
                        0,
                      )
                    1 =>
                      tuple_definition_lookup_frozen_reference(
                        func,
                        snapshot.use_def,
                        target,
                        0,
                      )
                    2 =>
                      tuple_definition_lookup_fresh_candidate(
                        snapshot, target, 0,
                      )
                    _ => expected
                  }
                  it.keep(result)
                }
              },
              name="roots=\{roots} depth=\{depth} stale=\{stale} mode=\{mode} raw=\{sample}",
              count=1,
            )
          }
        }
        assert_eq(@ir.hot_revision_current(func), revision)
        assert_eq(tuple_definition_lookup_check(snapshot, target, 0), expected)
        @ir.hot_verify_core(func).unwrap()
      }
    }
  }
}
