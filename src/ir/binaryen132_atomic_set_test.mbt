///|
test "Binaryen 132 GC atomic stores retain operands orders write effects and roundtrip" {
  let skeleton = @wast.wast_to_binary_module(
    "(module (type (struct (field (mut i32)))) (type (array (mut i32))) (func (param (ref null 0) (ref null 1))))",
  ).unwrap()
  for
    order in [
      @lib.AtomicOrder::seq_cst(),
      @lib.AtomicOrder::acq_rel(),
      @lib.AtomicOrder::relaxed(),
    ] {
    let body = @lib.Func::new(
      @lib.Locals::new([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_atomic_set(order, @lib.TypeIdx::new(0U), 0U),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::array_atomic_set(order, @lib.TypeIdx::new(1U)),
      ]),
    )
    let input = skeleton.with_code_sec(@lib.CodeSec::new([body]))
    assert_true(@validate.validate_module(input) is Ok(_))
    let hot = hot_lift_func(input, @lib.FuncIdx::new(0U))
    assert_true(hot_verify_core(hot) is Ok(_))
    let mut stores = 0
    for node = 0; node < hot_node_count(hot); node = node + 1 {
      let arity = match hot_node_exact_instr(hot, node) {
        Some(@lib.StructAtomicSet(actual, _, _)) => {
          @debug.assert_eq(actual, order)
          2
        }
        Some(@lib.ArrayAtomicSet(actual, _)) => {
          @debug.assert_eq(actual, order)
          3
        }
        _ => continue
      }
      assert_eq(hot_child_span(hot, node).length(), arity)
      let mask = effects_for_node(hot, node)
      assert_true(effects_writes_memory(mask))
      assert_false(effects_is_pure(mask))
      let ordering = effects_atomic_order_mask(order, read=false, write=true)
      assert_eq(mask & ordering, ordering)
      stores += 1
    }
    assert_eq(stores, 2)
    @debug.assert_eq(hot_lower_func_unverified(hot), body)
  }
}

///|
test "common atomic wait and notify effects preserve waiter-list synchronization" {
  for
    operation in [
      "memory.atomic.wait32 (i32.const 0) (i32.const 0) (i64.const 0)", "memory.atomic.wait64 (i32.const 0) (i64.const 0) (i64.const 0)",
      "memory.atomic.notify (i32.const 0) (i32.const 1)",
    ] {
    let module_ = @wast.wast_to_binary_module(
      "(module (memory 1 1 shared) (func (drop (\{operation}))))",
    ).unwrap()
    assert_true(@validate.validate_module(module_) is Ok(_))
    let hot = hot_lift_func(module_, @lib.FuncIdx::new(0U))
    let mask = effects_for_node(hot, hot_root_get(hot, 0))
    assert_true(effects_reads_memory(mask))
    assert_true(effects_writes_memory(mask))
    assert_true((mask & EFFECT_MASK_ATOMIC_READ) != 0U)
    assert_true((mask & EFFECT_MASK_ATOMIC_WRITE) != 0U)
    assert_true((mask & EFFECT_MASK_SEQ_CST) != 0U)
  }
}

///|
test "Binaryen 132 common effect summaries retain linear and GC atomic orders" {
  for
    entry in [
      ("seqcst", @lib.AtomicOrder::seq_cst()),
      ("acq_rel", @lib.AtomicOrder::acq_rel()),
      ("relaxed", @lib.AtomicOrder::relaxed()),
    ] {
    let (order_text, order) = entry
    let rows : Array[(String, Bool, Bool)] = [
      ("(drop (i32.atomic.load \{order_text} (i32.const 0)))", true, false),
      (
        "(i32.atomic.store \{order_text} (i32.const 0) (i32.const 1))",
        false,
        true,
      ),
      (
        "(drop (i32.atomic.rmw.add \{order_text} (i32.const 0) (i32.const 1)))",
        true,
        true,
      ),
      (
        "(drop (i32.atomic.rmw.cmpxchg \{order_text} (i32.const 0) (i32.const 1) (i32.const 2)))",
        true,
        true,
      ),
      (
        "(drop (struct.atomic.get \{order_text} $S 0 (local.get 0)))",
        true,
        false,
      ),
      (
        "(drop (struct.atomic.rmw.add \{order_text} \{order_text} $S 0 (local.get 0) (i32.const 1)))",
        true,
        true,
      ),
      (
        "(drop (struct.atomic.rmw.cmpxchg \{order_text} \{order_text} $S 0 (local.get 0) (i32.const 1) (i32.const 2)))",
        true,
        true,
      ),
      (
        "(drop (array.atomic.get \{order_text} $A (local.get 1) (i32.const 0)))",
        true,
        false,
      ),
      (
        "(drop (array.atomic.rmw.add \{order_text} \{order_text} $A (local.get 1) (i32.const 0) (i32.const 1)))",
        true,
        true,
      ),
      (
        "(drop (array.atomic.rmw.cmpxchg \{order_text} \{order_text} $A (local.get 1) (i32.const 0) (i32.const 1) (i32.const 2)))",
        true,
        true,
      ),
    ]
    for row in rows {
      let (body, read, write) = row
      let module_ = @wast.wast_to_binary_module(
        "(module (type $S (shared (struct (field (mut i32))))) (type $A (shared (array (mut i32)))) (memory 1 1 shared) (func (param (ref $S) (ref $A)) \{body}))",
      ).unwrap()
      assert_true(@validate.validate_module(module_) is Ok(_))
      let hot = hot_lift_func(module_, @lib.FuncIdx::new(0U))
      let mut found = false
      for node = 0; node < hot_node_count(hot); node = node + 1 {
        if hot_node_get(hot, node).op is HotOp::Atomic {
          found = true
          let mask = effects_for_node(hot, node)
          let ordering = effects_atomic_order_mask(order, read~, write~)
          assert_eq(mask & ordering, ordering)
        }
      }
      assert_true(found)
    }
  }
}

///|
test "Binaryen 132 every fence order has a zero operand HOT carrier and ordering effects" {
  for
    order in [
      @lib.AtomicOrder::seq_cst(),
      @lib.AtomicOrder::acq_rel(),
      @lib.AtomicOrder::relaxed(),
    ] {
    let instr = @lib.Instruction::atomic_fence(order~)
    let input = @lib.Expr::new([instr])
    let hot = match hot_lift_body_result(input, HotLocals::new()) {
      Ok(hot) => hot
      Err(err) => fail("fence HOT lift: \{err}")
    }
    assert_true(hot_verify_core(hot) is Ok(_))
    let node = hot_root_get(hot, 0)
    assert_eq(hot_child_span(hot, node).length(), 0)
    @debug.assert_eq(hot_node_exact_instr(hot, node), Some(instr))
    let mask = effects_for_node(hot, node)
    assert_true((mask & EFFECT_MASK_ATOMIC_READ) != 0U)
    assert_true((mask & EFFECT_MASK_ATOMIC_WRITE) != 0U)
    let @lib.Func(_, body) = hot_lower_func_unverified(hot)
    @debug.assert_eq(body, input)
  }
}
