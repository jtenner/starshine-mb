///|
fn binaryen132_atomic_store_sequence(
  instrs : Array[@lib.Instruction],
  out : Array[String],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.I32AtomicLoad(order, _) => out.push("load:\{order}")
      @lib.AtomicFence(order) => out.push("fence:\{order}")
      @lib.StructAtomicSet(order, _, _) => out.push("struct:\{order}")
      @lib.ArrayAtomicSet(order, _) => out.push("array:\{order}")
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        binaryen132_atomic_store_sequence(body, out)
      @lib.If(_, body, other) => {
        binaryen132_atomic_store_sequence(body, out)
        if other is Some(body) {
          binaryen132_atomic_store_sequence(body, out)
        }
      }
      _ => ()
    }
  }
}

///|
test "optimize instructions finishes unshared acquire release identity RMW read relaxation" {
  for order in ["seqcst", "acq_rel", "relaxed"] {
    for cmpxchg in [false, true] {
      for dropped in [false, true] {
        let operation = if cmpxchg {
          "struct.atomic.rmw.cmpxchg \{order} \{order} $S 0 (local.get 0) (i32.const 7) (i32.const 7)"
        } else {
          "struct.atomic.rmw.add \{order} \{order} $S 0 (local.get 0) (i32.const 0)"
        }
        let signature = if dropped { "" } else { "(result i32)" }
        let body = if dropped {
          "(drop (\{operation}))"
        } else {
          "(\{operation})"
        }
        let output = pass_test_run_pipeline(
          "(module (type $S (struct (field (mut i32)))) (func (param (ref null $S)) \{signature} \{body}))",
          ["optimize-instructions"],
        ).unwrap()
        let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
        let mut ordinary = 0
        let atomic_orders : Array[@lib.AtomicOrder] = []
        for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
          match @ir.hot_node_exact_instr(hot, node) {
            Some(@lib.StructGet(_, _)) => ordinary += 1
            Some(@lib.StructAtomicGet(order, _, _)) => atomic_orders.push(order)
            Some(@lib.StructAtomicRmw(_, _, _, _))
            | Some(@lib.StructAtomicCmpxchg(_, _, _)) =>
              fail("identity write remains")
            _ => ()
          }
        }
        assert_eq(ordinary, if order == "acq_rel" { 1 } else { 0 })
        @debug.assert_eq(
          atomic_orders,
          match order {
            "seqcst" => [@lib.AtomicOrder::seq_cst()]
            "relaxed" => [@lib.AtomicOrder::relaxed()]
            _ => []
          },
        )
        assert_true(@validate.validate_module(output) is Ok(_))
      }
    }
  }
}

///|
test "Binaryen 132 active passes preserve cross heap atomic load store ordering" {
  let source =
    #|(module
    #| (type $unused (func (param i64)))
    #| (type $S (shared (struct (field (mut i32)))))
    #| (type $A (shared (array (mut i32))))
    #| (memory 1 1 shared)
    #| (func (export "run") (param (ref $S) (ref $A)) (result i32) (local $before i32)
    #|  (local.set $before (i32.atomic.load relaxed (i32.const 0)))
    #|  (atomic.fence relaxed)
    #|  (struct.atomic.set relaxed $S 0 (local.get 0) (i32.const 7))
    #|  (array.atomic.set acqrel $A (local.get 1) (i32.const 0) (i32.const 9))
    #|  (local.get $before)))
  let input = pass_test_module_from_wat(source)
  let expected : Array[String] = []
  let @lib.Func(_, @lib.Expr(input_body)) = input.code_sec.unwrap().0[0]
  binaryen132_atomic_store_sequence(input_body, expected)
  for
    pass_name in [
      "local-subtyping", "vacuum", "precompute", "precompute-propagate", "optimize-instructions",
      "heap-store-optimization", "local-cse", "simplify-locals", "code-pushing",
      "code-folding", "dae2", "constraint-analysis", "remove-unused-module-elements",
      "duplicate-function-elimination",
    ] {
    let output = match
      run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]) {
      Ok(value) => value
      Err(err) => fail("\{pass_name}: \{err}")
    }
    match @validate.validate_module(output) {
      Ok(_) => ()
      Err(err) => fail("\{pass_name}: \{err}")
    }
    let actual : Array[String] = []
    for func in output.code_sec.unwrap().0 {
      let @lib.Func(_, @lib.Expr(body)) = func
      binaryen132_atomic_store_sequence(body, actual)
    }
    @debug.assert_eq(actual, expected)
  }
}

///|
test "Binaryen 132 DAE2 removes unused parameters in a function containing a fence" {
  for order in ["seqcst", "acq_rel", "relaxed"] {
    let input = pass_test_module_from_wat(
      "(module (func $target (param i32) (atomic.fence \{order})) (func (export \"run\") (call $target (i32.const 7))))",
    )
    let output = match
      run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]) {
      Ok(output) => output
      Err(err) => fail("fence DAE2: \{err}")
    }
    let context = @ir.hot_module_context_from_module(output)
    @debug.assert_eq(
      @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
      Some(@lib.FuncType::new([], [])),
    )
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_true(body.iter().any(fn(instr) { instr is @lib.AtomicFence(_) }))
    assert_true(@validate.validate_module(output) is Ok(_))
  }
}

///|
test "heap store optimization folds every atomic order into a fresh struct allocation" {
  for shared in [false, true] {
    let fields = "(struct (field (mut i32)) (field (mut i32)))"
    let type_body = if shared { "(shared \{fields})" } else { fields }
    for order in ["seqcst", "acq_rel", "relaxed"] {
      for tee in [false, true] {
        let receiver = if tee {
          "(local.tee 0 (struct.new_default $S))"
        } else {
          "(local.get 0)"
        }
        let prefix = if tee {
          ""
        } else {
          "(local.set 0 (struct.new_default $S))"
        }
        let source = "(module (type $S \{type_body}) (func (export \"run\") (result i32) (local (ref null $S)) \{prefix} (struct.atomic.set \{order} $S 1 \{receiver} (i32.const 7)) (struct.atomic.get \{order} $S 1 (local.get 0))))"
        let output = pass_test_run_pipeline(source, ["heap-store-optimization"]).unwrap()
        let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
        let mut allocations = 0
        for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
          match @ir.hot_node_exact_instr(hot, node) {
            Some(@lib.StructAtomicSet(_, _, _)) =>
              fail(
                "fresh allocation retains \{order} atomic store, shared=\{shared}, tee=\{tee}",
              )
            Some(@lib.StructNew(_)) => {
              allocations += 1
              let value = @ir.hot_child_get(hot, node, 1)
              @debug.assert_eq(
                @ir.hot_const_get(hot, @ir.hot_node_get(hot, value).imm0),
                @ir.HotConstPayload::i32_const(@lib.I32(7)),
              )
            }
            _ => ()
          }
        }
        assert_eq(allocations, 1)
        assert_true(@validate.validate_module(output) is Ok(_))
      }
    }
  }
}

///|
test "optimize instructions relaxes only acquire release stores to unshared structs" {
  for shared in [false, true] {
    let fields = "(struct (field (mut i32)))"
    let type_body = if shared { "(shared \{fields})" } else { fields }
    for order in ["seqcst", "acq_rel", "relaxed"] {
      let source = "(module (type $S \{type_body}) (func (export \"run\") (param (ref null $S) i32) (struct.atomic.set \{order} $S 0 (local.get 0) (local.get 1))))"
      let output = pass_test_run_pipeline(source, ["optimize-instructions"]).unwrap()
      let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
      let mut ordinary = 0
      let mut atomic_count = 0
      for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
        match @ir.hot_node_exact_instr(hot, node) {
          Some(@lib.StructAtomicSet(_, _, _)) => atomic_count += 1
          Some(@lib.StructSet(_, _)) => ordinary += 1
          _ => ()
        }
      }
      let relax = !shared && order == "acq_rel"
      assert_eq(ordinary, if relax { 1 } else { 0 })
      assert_eq(atomic_count, if relax { 0 } else { 1 })
      assert_true(@validate.validate_module(output) is Ok(_))
    }
  }
}

///|
test "optimize instructions preserves shared RMW writes and seqcst identity cmpxchg writes" {
  for order in ["seqcst", "acq_rel", "relaxed"] {
    for cmpxchg in [false, true] {
      for identity in [false, true] {
        let opcode = if cmpxchg {
          "struct.atomic.rmw.cmpxchg"
        } else {
          "struct.atomic.rmw.add"
        }
        let operands = if cmpxchg {
          if identity {
            "(i32.const 7) (i32.const 7)"
          } else {
            "(i32.const 7) (i32.const 8)"
          }
        } else if identity {
          "(i32.const 0)"
        } else {
          "(i32.const 7)"
        }
        let source = "(module (type $S (shared (struct (field (mut i32))))) (func (export \"run\") (param (ref null $S)) (result i32) (\{opcode} \{order} \{order} $S 0 (local.get 0) \{operands})))"
        let output = pass_test_run_pipeline(source, ["optimize-instructions"]).unwrap()
        let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
        let mut updates = 0
        let mut reads = 0
        for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
          match @ir.hot_node_exact_instr(hot, node) {
            Some(@lib.StructAtomicRmw(_, _, _, _))
            | Some(@lib.StructAtomicCmpxchg(_, _, _)) => updates += 1
            Some(@lib.StructAtomicGet(actual, _, _)) => {
              reads += 1
              let expected = if order == "acq_rel" {
                @lib.AtomicOrder::acq_rel()
              } else {
                @lib.AtomicOrder::relaxed()
              }
              @debug.assert_eq(actual, expected)
            }
            Some(@lib.StructGet(_, _)) | Some(@lib.StructSet(_, _)) =>
              fail("shared RMW became a non-atomic access")
            _ => ()
          }
        }
        let read_only = cmpxchg && identity && order != "seqcst"
        assert_eq(updates, if read_only { 0 } else { 1 })
        assert_eq(reads, if read_only { 1 } else { 0 })
        assert_true(@validate.validate_module(output) is Ok(_))
      }
    }
  }
}

///|
test "optimize instructions relaxes only acquire release reads from unshared structs" {
  for shared in [false, true] {
    let fields = "(struct (field (mut i32)))"
    let type_body = if shared { "(shared \{fields})" } else { fields }
    for order in ["seqcst", "acq_rel", "relaxed"] {
      let source = "(module (type $S \{type_body}) (func (export \"run\") (param (ref null $S)) (result i32) (struct.atomic.get \{order} $S 0 (local.get 0))))"
      let output = pass_test_run_pipeline(source, ["optimize-instructions"]).unwrap()
      let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
      let mut ordinary = 0
      for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
        if @ir.hot_node_exact_instr(hot, node) is Some(@lib.StructGet(_, _)) {
          ordinary += 1
        }
      }
      assert_eq(ordinary, if !shared && order == "acq_rel" { 1 } else { 0 })
      assert_true(@validate.validate_module(output) is Ok(_))
    }
  }
}

///|
test "optimize instructions lowers unshared compare exchange with a conditional store" {
  let source =
    #|(module (type $S (struct (field (mut i32))))
    #| (func (param (ref null $S) i32 i32) (result i32)
    #|  (struct.atomic.rmw.cmpxchg relaxed relaxed $S 0 (local.get 0) (local.get 1) (local.get 2))))
  let output = pass_test_run_pipeline(source, ["optimize-instructions"]).unwrap()
  let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
  let mut conditionals = 0
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    match @ir.hot_node_get(hot, node).op {
      @ir.HotOp::If => conditionals += 1
      @ir.HotOp::Select =>
        fail("cmpxchg must not retain an unconditional store/select")
      _ => ()
    }
  }
  assert_eq(conditionals, 1)
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "unshared atomic RMW lowering constructs arithmetic after temporary definitions" {
  for order in ["seqcst", "acqrel", "relaxed"] {
    let output = pass_test_run_pipeline(
      "(module (type $S (struct (field (mut i32)))) (func (param (ref null $S)) (result i32) (struct.atomic.rmw.add \{order} \{order} $S 0 (local.get 0) (i32.const 7))))",
      ["optimize-instructions"],
    ).unwrap()
    let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
    let mut additions = 0
    let mut stores = 0
    for node in 0..<@ir.hot_node_count(hot) {
      match @ir.hot_node_exact_instr(hot, node) {
        Some(@lib.I32Add) => additions += 1
        Some(@lib.StructSet(_, _)) => stores += 1
        _ => ()
      }
    }
    @debug.assert_eq(additions, 1)
    @debug.assert_eq(stores, 1)
    assert_true(@validate.validate_module(output) is Ok(_))
  }
}
