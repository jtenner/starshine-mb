///|
fn ca_test_run(source : String) -> @lib.Module raise {
  let input = match @wast.wast_to_binary_module(source) {
    Ok(input) => input
    Err(err) => fail("constraint fixture parse: \{err}")
  }
  match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["constraint-analysis"]) {
    Ok(output) => {
      match @validate.validate_module(output) {
        Ok(_) => ()
        Err(err) => fail("constraint analysis invalid output: \{err}")
      }
      output
    }
    Err(err) => fail("constraint analysis pipeline: \{err}")
  }
}

///|
test "shared lowering keeps throwing call values on the stack across balanced captures" {
  for pass in ["constraint-analysis", "optimize-instructions"] {
    let output = pass_test_run_pipeline(
      (
        #|(module
        #| (tag $e)
        #| (func $f (param i32 i32) (result i32)
        #|   (if (local.get 0) (then (throw $e))) (i32.const 7))
        #| (func (export "run") (param i32) (result i32) (local i32)
        #|   i32.const 10 local.set 1
        #|   (try (result i32) (do
        #|     local.get 0 i32.const 19 call $f
        #|     local.get 1 i32.const 11 local.set 1 i32.add)
        #|    (catch_all local.get 1))
        #|   local.get 1 local.get 1 i32.eq i32.add))
      ),
      [pass],
    ).unwrap()
    let @lib.Func(locals, _) = output.code_sec.unwrap().0[1]
    // The call and the old local value remain evaluated before the overwrite.
    // No additional local is needed for a balanced stack prefix.
    assert_eq(locals.length(), 1)
    assert_eq(
      ca_test_opcode_count(
        output,
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ),
      1,
    )
    assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_eq()), 0)
  }
}

///|
test "constraint analysis keeps an old local read before a tee without an extra local" {
  let output = ca_test_run(
    (
      #|(module (func (export "run") (param i32) (result i32)
      #| (if (result i32) (i32.eq (local.get 0) (local.tee 0 (i32.const 1)))
      #|  (then (i32.eq (local.get 0) (i32.const 1)))
      #|  (else (i32.ne (local.get 0) (i32.const 0))))))
    ),
  )
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
}

///|
test "constraint analysis avoids capturing nonexistent results of terminating tuple loops" {
  // Preserve the original stack form from GenValid case 19, seed 0x5eed. Text
  // lowering already repairs some bottom-typed control, hiding this carrier.
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0c, 0x02, 0x60, 0x00,
        0x02, 0x7f, 0x7c, 0x60, 0x01, 0x7f, 0x02, 0x7f, 0x7c, 0x03, 0x02, 0x01, 0x01,
        0x07, 0x07, 0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x0a, 0x4b, 0x01, 0x49,
        0x01, 0x02, 0x7f, 0x03, 0x00, 0x20, 0x00, 0x22, 0x02, 0x41, 0xfb, 0xae, 0xb7,
        0xee, 0x00, 0x46, 0x04, 0x00, 0x20, 0x02, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0xf4, 0x3f, 0x0f, 0x05, 0x20, 0x01, 0x41, 0x06, 0x49, 0x04, 0x7f, 0x20,
        0x01, 0x41, 0x01, 0x6a, 0x22, 0x01, 0x1a, 0x41, 0x01, 0x05, 0x41, 0x00, 0x0b,
        0x04, 0x00, 0x0c, 0x02, 0x05, 0x20, 0x02, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x04, 0x40, 0x0f, 0x0b, 0x0b, 0x0b, 0x0b,
      ]),
    ) {
    Ok(input) => input
    Err(err) => fail("decode: \{err}")
  }
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["constraint-analysis"]) {
    Ok(output) => output
    Err(err) => fail(err)
  }
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(err) => fail("invalid: \{err}")
  }
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_true(locals.length() <= 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let loop_body = match body[0] {
    @lib.Loop(_, @lib.Expr(body)) => body
    _ => fail("expected loop")
  }
  let mut found = false
  for instr in loop_body {
    if instr is @lib.If(bt, _, _) {
      found = true
      @debug.assert_eq(bt, @lib.BlockType::void_())
    }
  }
  assert_true(found)
}

///|
fn ca_test_opcode_count(mod_ : @lib.Module, opcode : @lib.Instruction) -> Int {
  let mut count = 0
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => []
  }
  for index = 0; index < funcs.length(); index = index + 1 {
    let hot = @ir.hot_lift_func(
      mod_,
      @lib.FuncIdx::new(
        (dae_imported_func_count(mod_) + index).reinterpret_as_uint(),
      ),
    )
    for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
      let data = @ir.hot_node_get(hot, node)
      let matches = match opcode {
        @lib.Instruction::Call(@lib.FuncIdx(index)) =>
          data.op is @ir.Call && data.imm0 == index.to_int()
        @lib.Instruction::ReturnCall(@lib.FuncIdx(index)) =>
          data.op is @ir.ReturnCall && data.imm0 == index.to_int()
        @lib.Instruction::RefIsNull => data.op is @ir.RefIsNull
        @lib.Instruction::LocalTee(@lib.LocalIdx(index)) =>
          data.op is @ir.LocalTee && data.imm0 == index.to_int()
        @lib.Instruction::LocalSet(@lib.LocalIdx(index)) =>
          data.op is @ir.LocalSet && data.imm0 == index.to_int()
        _ => @ir.hot_node_exact_instr(hot, node) == Some(opcode)
      }
      if matches {
        count += 1
      }
    }
  }
  count
}

///|
test "constraint analysis proves a nested comparison from an incoming equality" {
  let source =
    #|(module (func (export "run") (param i32) (result i32)
    #| (if (result i32) (i32.eq (local.get 0) (i32.const 10))
    #|  (then (i32.ne (local.get 0) (i32.const 0)))
    #|  (else (i32.const 7)))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_ne()),
    0,
  )
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_eq()),
    1,
  )
}

///|
test "constraint analysis joins alternative paths without strengthening facts" {
  let source =
    #|(module (func (export "run") (param i32) (result i32) (local i32)
    #| (if (local.get 0)
    #|  (then (local.set 1 (i32.const 3)))
    #|  (else (local.set 1 (i32.const 5))))
    #| (i32.add (i32.gt_u (local.get 1) (i32.const 0))
    #|          (i32.eq (local.get 1) (i32.const 3)))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_gt_u()),
    0,
  )
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_eq()),
    1,
  )
}

///|
test "constraint analysis reads i64 operand width rather than the i32 Boolean result width" {
  let source =
    #|(module (func (export "run") (param i64) (result i32)
    #| (if (result i32) (i64.eq (local.get 0) (i64.const 1099511627776))
    #|  (then (i64.gt_u (local.get 0) (i64.const 4294967295)))
    #|  (else (i32.const 0)))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i64_gt_u()),
    0,
  )
}

///|
test "constraint analysis transfers increments with fixed width wrapping" {
  let source =
    #|(module (func (export "run") (param i32) (result i32)
    #| (if (result i32) (i32.eq (local.get 0) (i32.const -1))
    #|  (then
    #|   (local.set 0 (i32.add (local.get 0) (i32.const 1)))
    #|   (i32.eqz (local.get 0)))
    #|  (else (i32.const 2)))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_eqz()),
    0,
  )
}

///|
test "constraint analysis distinguishes mixed signedness and preserves unconstrained negatives" {
  let source =
    #|(module (func (export "run") (param i32) (result i32)
    #| (if (result i32) (i32.lt_s (local.get 0) (i32.const 5))
    #|  (then (i32.lt_u (local.get 0) (i32.const 5)))
    #|  (else (i32.const 2)))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_lt_u()),
    1,
  )
}

///|
test "constraint analysis accounts for local tee writes before applying branch facts" {
  let source =
    #|(module (func (export "run") (param i32) (result i32)
    #| (if (result i32) (i32.eq (local.tee 0 (i32.const 10)) (i32.const 10))
    #|  (then (i32.ne (local.get 0) (i32.const 0)))
    #|  (else (i32.const 2)))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_ne()),
    0,
  )
  // The consumed tee result can become a set; its write must execute once.
  @debug.assert_eq(
    ca_test_opcode_count(
      optimized,
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    ) +
    ca_test_opcode_count(
      optimized,
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    ),
    1,
  )
}

///|
test "constraint analysis leaves floating point logical assumptions disabled" {
  let source =
    #|(module (func (export "run") (param f64) (result i32)
    #| (if (result i32) (f64.ne (local.get 0) (f64.const 1))
    #|  (then (f64.eq (local.get 0) (local.get 0)))
    #|  (else (i32.const 2)))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::f64_eq()),
    1,
  )
}

///|
test "constraint analysis proves reference nullness on both branch edges" {
  let source =
    #|(module (func (export "run") (param externref) (result i32)
    #| (if (result i32) (ref.is_null (local.get 0))
    #|  (then (ref.is_null (local.get 0)))
    #|  (else (ref.is_null (local.get 0))))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::ref_is_null()),
    1,
  )
}

///|
test "constraint analysis keeps branch joins and widening sound in a bounded loop" {
  let source =
    #|(module (func (export "run") (param i32) (result i32) (local i32)
    #| (block $done
    #|  (loop $again
    #|   (br_if $done (i32.ge_u (local.get 1) (i32.const 100)))
    #|   (local.set 1 (i32.add (local.get 1) (i32.const 1)))
    #|   (br $again)))
    #| (i32.ge_u (local.get 1) (i32.const 100))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_ge_u()),
    1,
  )
}

///|
test "constraint analysis does not refine an old local get after a later tee" {
  let optimized = ca_test_run(
    (
      #|(module (func (export "run") (param i32) (result i32)
      #| (if (result i32) (i32.eq (local.get 0) (local.tee 0 (i32.const 3)))
      #|  (then (i32.eq (local.get 0) (i32.const 3)))
      #|  (else (i32.eq (local.get 0) (i32.const 3))))))
    ),
  )
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_eq()),
    1,
  )
}

///|
test "constraint analysis double eqz and AND preserve both incoming facts" {
  let optimized = ca_test_run(
    (
      #|(module (func (export "run") (param i32) (result i32)
      #| (if (result i32)
      #|  (i32.eqz (i32.eqz (i32.and (i32.ge_u (local.get 0) (i32.const 10))
      #|                            (i32.le_u (local.get 0) (i32.const 20)))))
      #|  (then (i32.eqz (local.get 0))) (else (i32.const 2)))))
    ),
  )
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_eqz()),
    2,
  )
}

///|
test "constraint analysis unreachable predecessors do not dilute or manufacture facts" {
  let optimized = ca_test_run(
    (
      #|(module (func (export "run") (param i32) (result i32) (local i32)
      #| (if (local.get 0) (then (return (i32.const 7)))
      #|  (else (local.set 1 (i32.const 10))))
      #| (i32.eq (local.get 1) (i32.const 10))))
    ),
  )
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_eq()),
    0,
  )
}

///|
test "constraint analysis relates local operands independently of insertion order" {
  let optimized = ca_test_run(
    (
      #|(module (func (export "run") (param i32 i32) (result i32)
      #| (if (result i32) (i32.lt_s (local.get 0) (local.get 1))
      #|  (then (i32.gt_s (local.get 1) (local.get 0)))
      #|  (else (i32.const 2)))))
    ),
  )
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_gt_s()),
    0,
  )
}

///|
test "constraint analysis validates every dedicated GenValid family after rewriting" {
  for
    name in [
      "constraint-integer", "constraint-joins", "constraint-loops", "constraint-tees",
      "constraint-wraparound", "constraint-i64", "constraint-logical", "constraint-references",
      "constraint-unreachable", "constraint-relations", "constraint-effects", "constraint-float-boundary",
    ] {
    let profile = match @validate.gen_valid_profile_by_name(name) {
      Ok(profile) => profile
      Err(err) => fail(err)
    }
    for seed in [0UL, 1UL, 0x5eedUL, 0xffffffffffffffffUL] {
      let generated = match
        @validate.gen_valid_module_from_seed(
          seed,
          @validate.GenValidConfig::for_profile(profile),
        ) {
        Ok(generated) => generated.wasm_module
        Err(err) => fail(err.validation_error_message)
      }
      let optimized = match
        run_hot_pipeline(generated, HotPipelineOptions::new(), [
          "constraint-analysis",
        ]) {
        Ok(optimized) => optimized
        Err(err) => fail("\{name} seed \{seed}: \{err}")
      }
      match @validate.validate_module(optimized) {
        Ok(_) => ()
        Err(err) => fail("\{name}: \{err}")
      }
    }
  }
}

///|
test "constraint analysis removes pure predicate operands without dead local reads" {
  let source =
    #|(module (func (export "run") (param i32) (result i32)
    #| (if (result i32) (i32.eq (local.get 0) (i32.const 10))
    #|  (then (i32.ne (local.get 0) (i32.const 0))) (else (i32.const 2)))))
  let optimized = ca_test_run(source)
  let hot = @ir.hot_lift_func(optimized, @lib.FuncIdx::new(0U))
  let mut drops = 0
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    if @ir.hot_node_get(hot, node).op is @ir.Drop {
      drops += 1
    }
  }
  @debug.assert_eq(drops, 0)
}

///|
test "constraint analysis proves reference equality against a known null" {
  let source =
    #|(module (func (export "run") (param eqref) (result i32)
    #| (if (result i32) (ref.is_null (local.get 0))
    #|  (then (ref.eq (local.get 0) (ref.null eq))) (else (i32.const 2)))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::ref_eq()),
    0,
  )
}

///|
test "constraint analysis follows dropped reference branches through the shared CFG" {
  let source =
    #|(module (func (export "run") (param anyref) (result i32)
    #| (block $null
    #|  (drop (br_on_null $null (local.get 0)))
    #|  (return (ref.is_null (local.get 0))))
    #| (ref.is_null (local.get 0))))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::ref_is_null()),
    0,
  )
}

///|
test "constraint analysis preserves a stack-held local value across a later write" {
  let source =
    #|(module (func (export "run") (param i32) (result i32)
    #| local.get 0
    #| i32.const 1
    #| local.set 0
    #| i32.eqz))
  let optimized = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(optimized, @lib.Instruction::i32_eqz()),
    1,
  )
}

///|
test "constraint analysis retains equalities through local copies" {
  let source =
    #|(module (func (export "run") (param i32 i32 i32) (result i32)
    #| (local.set 0 (local.get 1))
    #| (local.set 2 (local.get 0))
    #| (if (result i32) (i32.eq (local.get 0) (local.get 2))
    #|   (then (i32.ne (local.get 0) (local.get 1)))
    #|   (else (i32.const 7)))))
  let output = ca_test_run(source)
  @debug.assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_eq()), 0)
  @debug.assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_ne()), 0)
}

///|
test "constraint analysis invalidates a copied equality when its source changes" {
  let source =
    #|(module (func (export "run") (param i32 i32) (result i32)
    #| (local.set 0 (local.get 1))
    #| (local.set 1 (i32.const 9))
    #| (i32.eq (local.get 0) (local.get 1))))
  let output = ca_test_run(source)
  @debug.assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_eq()), 1)
}

///|
test "constraint analysis propagates equality transitively between local operands" {
  let source =
    #|(module (func (export "run") (param i32 i32 i32) (result i32)
    #| (if (result i32) (i32.eq (local.get 0) (local.get 1))
    #|  (then (if (result i32) (i32.eq (local.get 1) (local.get 2))
    #|    (then (i32.ne (local.get 0) (local.get 2))) (else (i32.const 8))))
    #|  (else (i32.const 9)))))
  let output = ca_test_run(source)
  @debug.assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_ne()), 0)
}

///|
test "constraint analysis replaces proved unreachable effects with unreachable control" {
  let source =
    #|(module (global (mut i32) (i32.const 0))
    #| (func (export "run") (param i32)
    #|  (if (i32.eq (local.get 0) (i32.const 0))
    #|   (then (if (i32.ne (local.get 0) (i32.const 0))
    #|    (then (global.set 0 (i32.const 7))))))))
  let output = ca_test_run(source)
  let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
  let mut stores = 0
  let mut traps = 0
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    match @ir.hot_node_get(hot, node).op {
      @ir.GlobalSet => stores += 1
      @ir.Unreachable => traps += 1
      _ => ()
    }
  }
  @debug.assert_eq(stores, 0)
  @debug.assert_eq(traps > 0, true)
}

///|
test "constraint analysis preserves facts on exception edges before a later expression write" {
  let source =
    #|(module (tag $t)
    #| (func $thrower (param i32) (if (local.get 0) (then (throw $t))))
    #| (func (export "run") (param i32) (result i32) (local i32)
    #|  (local.set 1 (i32.const 3))
    #|  (block $caught
    #|   (drop (i32.add
    #|    (try_table (result i32) (catch_all $caught)
    #|      (call $thrower (local.get 0)) (i32.const 9))
    #|    (local.tee 1 (i32.const 8)))))
    #|  (i32.eq (local.get 1) (i32.const 3))))
  let output = ca_test_run(source)
  @debug.assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_eq()), 1)
}

///|
test "constraint analysis rewrites shared tuple control regions only once" {
  let source =
    #|(module (func (export "run") (param i32) (result i32 i32)
    #| (block (result i32 i32)
    #|  (if (i32.eq (local.get 0) (local.get 0))
    #|   (then (nop)) (else (nop) (nop) (nop)))
    #|  (i32.const 1) (i32.const 2))))
  let output = ca_test_run(source)
  @debug.assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_eq()), 0)
}

///|
test "constraint analysis merges reachability across duplicated tuple CFG slices" {
  let source =
    #|(module (import "env" "peek" (func (param i32) (result i32)))
    #|(import "env" "read" (func (param i32 i32 i32) (result i32 f64)))
    #|(memory 1)
    #|  (func (export "run") (param i32 i32) (result i32 f64)
    #|    (local i32 i32 i32 i32 i32 i32 i32)
    #|    loop (result i32 f64) ;; label = @1
    #|      local.get 0
    #|      call 0
    #|      local.tee 2
    #|      i32.const -1
    #|      i32.eq
    #|      if (result i32 f64) ;; label = @2
    #|        local.get 0
    #|        i32.load align=1
    #|        local.set 5
    #|        local.get 0
    #|        local.get 1
    #|        local.get 5
    #|        call 1
    #|        return
    #|      else
    #|        local.get 2
    #|        local.tee 3
    #|        local.tee 4
    #|        i32.const 48
    #|        i32.ge_s
    #|        if (result i32) ;; label = @3
    #|          local.get 4
    #|          i32.const 57
    #|          i32.le_s
    #|        else
    #|          i32.const 0
    #|        end
    #|        if (result i32 f64) ;; label = @3
    #|          br 2 (;@1;)
    #|        else
    #|          local.get 0
    #|          i32.load align=1
    #|          local.tee 7
    #|          i32.const 1
    #|          i32.sub
    #|          local.set 6
    #|          local.get 0
    #|          local.get 6
    #|          i32.store align=1
    #|          local.get 0
    #|          i32.load align=1
    #|          local.set 8
    #|          local.get 0
    #|          local.get 1
    #|          local.get 8
    #|          call 1
    #|          return
    #|        end
    #|      end
    #|    end
    #|  )
    #|
    #|)
  let output = ca_test_run(source)
  @debug.assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_eq()), 1)
}

///|
test "constraint analysis preserves a pending call before later conditional effects" {
  let source =
    #|(module (global (mut i32) (i32.const 5))
    #| (func $read (result i32) global.get 0)
    #| (func $clobber i32.const 9 global.set 0)
    #| (func (export "run") (result i32) (local i32 i32)
    #|  i32.const 0 local.set 0 call $read
    #|  local.get 0 if call $clobber end
    #|  i32.const 1 if call $clobber end
    #|  local.set 1 local.get 1))
  let output = ca_test_run(source)
  let @lib.CodeSec(bodies) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = bodies[2]
  let ops : Array[@lib.Instruction] = []
  dae2_test_flat_opcodes(body, ops)
  let mut read = -1
  let mut clobber = -1
  for index = 0; index < ops.length(); index = index + 1 {
    match ops[index] {
      @lib.Call(@lib.FuncIdx(0U)) => read = index
      @lib.Call(@lib.FuncIdx(1U)) => clobber = index
      _ => ()
    }
  }
  @debug.assert_eq(read >= 0 && clobber > read, true)
}

///|
test "constraint analysis uses carried loop parameters after the first iteration" {
  let source =
    #|(module (func (export "run") (result i32) (local i32)
    #| (i32.const 0)
    #| (loop (param i32)
    #|   (local.tee 0)
    #|   (i32.const 6)
    #|   (i32.lt_s)
    #|   (if (then (local.get 0) (i32.const 1) (i32.add) (br 1))))
    #| (local.get 0)))
  let output = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(output, @lib.Instruction::i32_lt_s()),
    1,
  )
}

///|
test "constraint analysis distinguishes nested carried parameters sharing an initial producer" {
  let source =
    #|(module (func (export "run") (result i32) (local i32)
    #| (i32.const 0)
    #| (loop (param i32)
    #|   (loop (param i32)
    #|     (local.tee 0) (i32.const 3) (i32.lt_u)
    #|     (if (then (local.get 0) (i32.const 1) (i32.add) (br 1)))))
    #| (local.get 0)))
  let output = ca_test_run(source)
  @debug.assert_eq(
    ca_test_opcode_count(output, @lib.Instruction::i32_lt_u()),
    1,
  )
}

///|
test "constraint lowering keeps a result supplied by a branch to the if label" {
  let output = ca_test_run(
    (
      #|(module (func (export "run") (param i32) (result i32)
      #| (if (local.get 0) (then (drop (i32.eq (local.get 0) (i32.const 0)))))
      #| (if (result i32) (local.get 0)
      #|  (then (br 0 (i32.const 7)))
      #|  (else (return (i32.const 8))))
      #| drop unreachable))
    ),
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let mut retained = false
  for instr in body {
    if instr is @lib.If(bt, _, _) &&
      bt == @lib.BlockType::val_type(@lib.ValType::i32()) {
      retained = true
    }
  }
  assert_true(retained)
}

///|
test "constraint analysis stores only predicate relevant locals including transitive copy sources" {
  let source =
    #|(module (func (param i32) (result i32) (local i64 f64 i32 i32)
    #| (local.set 1 (i64.const 99))
    #| (local.set 2 (f64.const 1.5))
    #| (local.set 3 (local.get 0))
    #| (local.set 4 (local.get 3))
    #| (if (result i32) (i32.lt_u (local.get 4) (i32.const 9))
    #|  (then (i32.lt_u (local.get 0) (i32.const 10)))
    #|  (else (i32.const 0)))))
  let input = @wast.wast_to_binary_module(source).unwrap()
  let hot = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let cfg = @ir.cache_get_or_build_cfg(@ir.HotAnalysisCache::new(), hot)
  let state = ca_initial_state(hot, ca_loop_plan(hot, cfg))
  // Per-block state must not grow with unrelated integer/float locals.
  assert_eq(state.locals.length(), 3)
  let output = ca_test_run(source)
  assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_lt_u()), 1)
}

///|
test "constraint relevant local traversal handles an absent else inside a copied producer" {
  // Reduced from the compiler-module native abort: absent HOT region children
  // use a negative sentinel and must not index the traversal's node bitmap.
  let source =
    #|(module (func (param i32) (result i32) (local i32)
    #| (local.set 1 (block (result i32)
    #|   (if (local.get 0) (then (nop))) (i32.const 0)))
    #| (i32.eqz (local.get 1))))
  let input = @wast.wast_to_binary_module(source).unwrap()
  let hot = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  @debug.assert_eq(ca_relevant_locals(hot), [0, 1])
  let output = ca_test_run(source)
  assert_true(@validate.validate_module(output) is Ok(_))
}
