///|
test "atomic store public flags must retain trap write and side effects" {
  let module_ = @wast.wast_to_binary_module(
    "(module (memory 1 1 shared) (func (i32.atomic.store (i32.const 0) (i32.const 1))))",
  ).unwrap()
  assert_true(@validate.validate_module(module_) is Ok(_))
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let store = hot_root_get(func, 0)
  assert_true(hot_node_get(func, store).op is HotOp::Atomic)
  let mask = effects_for_node(func, store)
  assert_true(effects_writes_memory(mask))
  assert_true((mask & EFFECT_MASK_TRAP) != 0U)
  assert_false(effects_is_pure(mask))
  // Required behavior: public flags must agree with the exact atomic effects.
  // Keep the observations together so a failure reports all three flags.
  @debug.assert_eq(
    (
      hot_may_trap(func, store),
      hot_has_side_effect(func, store),
      hot_node_has_flag(func, store, HOT_FLAG_STORE),
    ),
    (true, true, true),
  )
}

///|
fn check_atomic_public_flags(
  body : String,
  expected : UInt32,
  storage~ : String = "i32",
) -> Unit raise {
  let module_ = @wast.wast_to_binary_module(
    "(module (type $S (shared (struct (field (mut \{storage}))))) (type $A (shared (array (mut \{storage})))) (memory 1 1 shared) (func (param (ref $S) (ref $A)) \{body}))",
  ).unwrap()
  assert_true(@validate.validate_module(module_) is Ok(_))
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let mut count = 0
  for node = 0; node < hot_node_count(func); node = node + 1 {
    if hot_node_get(func, node).op is HotOp::Atomic {
      assert_eq(hot_node_flags(func, node), expected, msg=body)
      count += 1
    }
  }
  assert_eq(count, 1)
  hot_verify_core(func).unwrap()
}

///|
test "atomic linear memory public flags cover every width and operation kind" {
  let load_flags = HOT_FLAG_VALUE | HOT_FLAG_LOAD | HOT_FLAG_MAY_TRAP
  let store_flags = HOT_FLAG_STORE | HOT_FLAG_SIDE_EFFECT | HOT_FLAG_MAY_TRAP
  for
    (ty, suffix) in [
      ("i32", ""),
      ("i32", "8"),
      ("i32", "16"),
      ("i64", ""),
      ("i64", "8"),
      ("i64", "16"),
      ("i64", "32"),
    ] {
    let unsigned = if suffix == "" { "" } else { "_u" }
    check_atomic_public_flags(
      "(drop (\{ty}.atomic.load\{suffix}\{unsigned} (i32.const 0)))",
      load_flags,
    )
    check_atomic_public_flags(
      "(\{ty}.atomic.store\{suffix} (i32.const 0) (\{ty}.const 1))",
      store_flags,
    )
    for operation in ["add", "sub", "and", "or", "xor", "xchg", "cmpxchg"] {
      let expected = if operation == "cmpxchg" { "(\{ty}.const 2)" } else { "" }
      check_atomic_public_flags(
        "(drop (\{ty}.atomic.rmw\{suffix}.\{operation}\{unsigned} (i32.const 0) (\{ty}.const 1) \{expected}))",
        load_flags | store_flags,
      )
    }
  }
}

///|
test "atomic GC public flags distinguish reads stores and read modify writes" {
  let load_flags = HOT_FLAG_VALUE | HOT_FLAG_LOAD | HOT_FLAG_MAY_TRAP
  let store_flags = HOT_FLAG_STORE | HOT_FLAG_SIDE_EFFECT | HOT_FLAG_MAY_TRAP
  for order in ["seqcst", "acq_rel", "relaxed"] {
    for
      (kind, receiver) in [
        ("struct", "$S 0 (local.get 0)"),
        ("array", "$A (local.get 1) (i32.const 0)"),
      ] {
      check_atomic_public_flags(
        "(drop (\{kind}.atomic.get \{order} \{receiver}))",
        load_flags,
      )
      check_atomic_public_flags(
        "(\{kind}.atomic.set \{order} \{receiver} (i32.const 1))",
        store_flags,
      )
      check_atomic_public_flags(
        "(drop (\{kind}.atomic.rmw.add \{order} \{order} \{receiver} (i32.const 1)))",
        load_flags | store_flags,
      )
      check_atomic_public_flags(
        "(drop (\{kind}.atomic.rmw.cmpxchg \{order} \{order} \{receiver} (i32.const 1) (i32.const 2)))",
        load_flags | store_flags,
      )
    }
  }
}

///|
test "atomic packed GC reads retain load value and trap flags" {
  let flags = HOT_FLAG_VALUE | HOT_FLAG_LOAD | HOT_FLAG_MAY_TRAP
  for storage in ["i8", "i16"] {
    for sign in ["s", "u"] {
      check_atomic_public_flags(
        "(drop (struct.atomic.get_\{sign} $S 0 (local.get 0)))",
        flags,
        storage~,
      )
      check_atomic_public_flags(
        "(drop (array.atomic.get_\{sign} $A (local.get 1) (i32.const 0)))",
        flags,
        storage~,
      )
    }
  }
}

///|
test "atomic waits notify and fences expose synchronization flags" {
  let flags = HOT_FLAG_LOAD | HOT_FLAG_STORE | HOT_FLAG_SIDE_EFFECT
  for
    body in [
      "(drop (memory.atomic.wait32 (i32.const 0) (i32.const 0) (i64.const 0)))",
      "(drop (memory.atomic.wait64 (i32.const 0) (i64.const 0) (i64.const 0)))",
      "(drop (memory.atomic.notify (i32.const 0) (i32.const 1)))",
    ] {
    check_atomic_public_flags(body, flags | HOT_FLAG_VALUE | HOT_FLAG_MAY_TRAP)
  }
  for order in ["seqcst", "acq_rel", "relaxed"] {
    check_atomic_public_flags("(atomic.fence \{order})", flags)
  }
}

///|
test "atomic builders and node replacement use the exact payload in imm1" {
  let func = HotFunc::new()
  let fence = hot_build_atomic(func, [], @lib.Instruction::atomic_fence(), [])
  let ptr = hot_build_const_i32(func, @lib.I32(0))
  let value = hot_build_const_i32(func, @lib.I32(1))
  let memarg = @lib.MemArg::new(@lib.U32(2U), None, @lib.U64(0UL))
  assert_eq(hot_alloc_memarg(func, HotMemArg::new(memarg)), 0)
  let store = hot_build_atomic(
    func,
    [],
    @lib.Instruction::i32_atomic_store(memarg),
    [ptr, value],
  )
  let flags = HOT_FLAG_STORE | HOT_FLAG_SIDE_EFFECT | HOT_FLAG_MAY_TRAP
  assert_eq(hot_node_flags(func, store), flags)
  let replacement = hot_node_get(func, store)
  hot_node_set(func, fence, replacement)
  assert_eq(hot_node_flags(func, fence), flags)
  let nop = hot_build_nop(func)
  hot_replace_node(func, nop, replacement)
  assert_eq(hot_node_flags(func, nop), flags)
  // Exact-family setters permit staged operand edits. Flags must follow the
  // new opcode immediately, before the caller finishes changing operands.
  hot_node_exact_instr_set(func, store, @lib.Instruction::atomic_fence())
  assert_eq(
    hot_node_flags(func, store),
    HOT_FLAG_LOAD | HOT_FLAG_STORE | HOT_FLAG_SIDE_EFFECT,
  )
  hot_node_exact_instr_set(
    func,
    store,
    @lib.Instruction::i32_atomic_store(memarg),
  )
  assert_eq(hot_node_flags(func, store), flags)
  match hot_verify_core(func) {
    Ok(_) => ()
    Err(error) => fail("atomic builder verification: \{error}")
  }
}
