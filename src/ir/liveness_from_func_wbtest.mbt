///|
fn block_liveness_assert_equivalent(func : HotFunc, cfg : HotCfg) -> Unit raise {
  let revision = hot_revision_current(func)
  let full = use_def_build(func, cfg=Some(cfg))
  for exceptional in [false, true] {
    let reference = liveness_build(
      cfg,
      full,
      include_exceptional_edges=exceptional,
    )
    let selected = liveness_build_from_func(
      func,
      cfg,
      include_exceptional_edges=exceptional,
    )
    assert_eq(selected, reference)
  }
  hot_verify_all_or_abort(func)
  cfg_verify(cfg)
  assert_eq(hot_revision_current(func), revision)
}

///|
test "block-only liveness matches full use-def for nested control loops GC and no-op bodies" {
  for
    wat in [
      "(module (func))", "(module (func (param i32) (local i32) local.get 0 if i32.const 7 local.set 1 else nop end local.get 1 drop))",
      "(module (func (param i32) (local i32) block loop local.get 1 local.get 0 i32.add local.set 1 local.get 1 br_if 0 end end local.get 1 drop))",
      "(module (type (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 block (type 0) i32.const 7 i32.add end))",
      "(module (type $s (struct (field i32))) (func (param (ref null $s)) (result i32) (local (ref null $s)) local.get 0 local.set 1 local.get 1 struct.get $s 0))",
      "(module (tag $e) (func (param i32) (local i32) block $exit block $catch try_table (catch $e $catch) local.get 0 local.set 1 throw $e end br $exit end local.get 1 drop end))",
    ] {
    let mod_ = @wast.wast_to_binary_module(wat).unwrap()
    @validate.validate_module(mod_).unwrap()
    let func = hot_lift_func(mod_, @lib.FuncIdx::new(0U))
    for expanded in [false, true] {
      block_liveness_assert_equivalent(
        func,
        cfg_build(func, expand_operand_control=expanded),
      )
    }
  }
}

///|
test "block-only liveness preserves wide local words shared operands and entry values" {
  let func = HotFunc::new(
    locals=HotLocals::new(
      params=[@lib.ValType::i32()],
      locals=Array::make(95, @lib.ValType::i32()),
    ),
  )
  for local_id in [1, 63, 64, 95] {
    let read = hot_build_local_get(func, local_id)
    let add = hot_build_binary(func, @lib.ValType::i32(), read, read)
    hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
    hot_root_append(func, hot_build_drop(func, add))
  }
  let cfg = cfg_build(func, expand_operand_control=true)
  block_liveness_assert_equivalent(func, cfg)
  let selected = liveness_build_from_func(func, cfg)
  for local_id in [1, 63, 64, 95] {
    assert_true(local_live_in(selected, cfg_entry_block(cfg), local_id))
  }
  assert_false(local_live_in(selected, cfg_entry_block(cfg), 0))
}

///|
test "block-only liveness rebuilds changed roots without mutating published facts" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  hot_root_append(func, hot_build_drop(func, hot_build_local_get(func, 0)))
  let old_cfg = cfg_build(func, expand_operand_control=true)
  let old = liveness_build_from_func(func, old_cfg)
  assert_true(local_live_in(old, cfg_entry_block(old_cfg), 0))
  hot_root_set(func, 0, hot_build_nop(func))
  let fresh_cfg = cfg_build(func, expand_operand_control=true)
  block_liveness_assert_equivalent(func, fresh_cfg)
  let fresh = liveness_build_from_func(func, fresh_cfg)
  assert_false(local_live_in(fresh, cfg_entry_block(fresh_cfg), 0))
  assert_true(local_live_in(old, cfg_entry_block(old_cfg), 0))
}
