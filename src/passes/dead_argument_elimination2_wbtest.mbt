///|
fn dae2_test_signature(mod_ : @lib.Module, index : Int) -> @lib.FuncType {
  match
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(mod_),
      @lib.FuncIdx::new(index.reinterpret_as_uint()),
    ) {
    Some(sig) => sig
    None => abort("missing DAE2 test signature")
  }
}

///|
fn dae2_test_run(source : String, pass : String) -> @lib.Module raise {
  match pass_test_run_pipeline(source, [pass]) {
    Ok(mod_) => {
      match @validate.validate_module(mod_) {
        Ok(_) => ()
        Err(err) => fail("DAE2 produced invalid module: \{err}")
      }
      mod_
    }
    Err(err) => fail("DAE2 pipeline failed: \{err}")
  }
}

///|
test "dae2 declaration-only references allow private signature pruning" {
  for
    declaration in [
      "(elem declare func $target)", "(elem declare funcref (ref.func $target))",
    ] {
    let input = match
      @wast.wast_to_binary_module(
        "(module (func $target (param i32) (result i32) (local.get 0)) \{declaration} (func (export \"run\") (result i32) (i32.const 42)))",
      ) {
      Ok(input) => input
      Err(err) => fail("declaration parse \{declaration}: \{err}")
    }
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_))
    @debug.assert_eq(dae2_test_signature(output, 0), @lib.FuncType::new([], []))
  }
}

///|
test "dae2 capture cleanup preserves values without accumulating scratch locals" {
  let source =
    #|(module (memory 1)
    #| (func $source (param i32) (result i32) (local i32)
    #|   (local.tee 1 (memory.size))
    #|   (i32.load (i32.const 0)) (local.get 1) i32.add i32.add)
    #| (func $sink (param i32 i32) (result i32) (local.get 0))
    #| (func (export "run") (result i32)
    #|   (call $source (i32.const 7)) (i32.const 8) (call $sink)))
  let once = dae2_test_run(source, "dae2-optimizing")
  let @lib.Func(locals, _) = once.code_sec.unwrap().0[0]
  assert_true(locals.length() <= 2)
  let twice = run_hot_pipeline(once, HotPipelineOptions::new(), [
    "dae2-optimizing",
  ]).unwrap()
  let @lib.Func(next_locals, _) = twice.code_sec.unwrap().0[0]
  assert_true(next_locals.length() <= locals.length())
  assert_true(@validate.validate_module(twice) is Ok(_))
}

///|
test "dae2 optimizing flattens a tuple forwarding block without cloning its producer" {
  let source =
    #|(module
    #| (import "env" "source" (func $source (result i32 i32 i32)))
    #| (import "env" "sink" (func $sink (param i32 i32 i32) (result i32)))
    #| (func (export "run") (result i32) (local i32 i32 i32)
    #|  call $source local.set 2 local.set 1 local.set 0
    #|  block (result i32 i32 i32) local.get 0 local.get 1 local.get 2 end
    #|  local.set 2 local.set 1 local.set 0
    #|  local.get 0 local.get 2 local.get 1 call $sink))
  let output = dae2_test_run(source, "dae2-optimizing")
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_false(body.any(fn(instr) { instr is @lib.Block(_, _) }))
  @debug.assert_eq(
    body.filter(fn(instr) { instr is @lib.Call(@lib.FuncIdx(0U)) }).length(),
    1,
  )
  @debug.assert_eq(
    body.filter(fn(instr) { instr is @lib.Call(@lib.FuncIdx(1U)) }).length(),
    1,
  )
}

///|
test "dae2 tuple cleanup drops stale labels only from changed functions" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i64) (result i32 i64) (block (result i32 i64) (local.get 0) (local.get 1))) (func (param i32) (result i32) (block (result i32) (local.get 0))))",
  )
  let entry = fn(index : UInt, name : String) {
    @lib.IndirectNameAssoc::new(
      index,
      @lib.NameMap::new([@lib.NameAssoc::new(0U, @lib.Name::from_string(name))]),
    )
  }
  let module_name = @lib.Name::from_string("tuple-names")
  let input = input.with_name_sec(
    @lib.NameSec::new(
      module_name=Some(module_name),
      label_names=Some(
        @lib.IndirectNameMap::new([
          entry(0U, "removed-forwarder"),
          entry(1U, "retained-scalar"),
        ]),
      ),
    ),
  )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("invalid named tuple input: \{err}")
  }
  let output = dae2_cleanup_captures(input)
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(err) => fail("invalid named tuple cleanup: \{err}")
  }
  let names = output.name_sec.unwrap()
  @debug.assert_eq(names.module_name, Some(module_name))
  @debug.assert_eq(
    names.label_names,
    Some(@lib.IndirectNameMap::new([entry(1U, "retained-scalar")])),
  )
}

///|
test "dae2 generated named tuples retain valid metadata through cleanup passes" {
  let profile = @validate.gen_valid_profile_by_name("dae2-tuple-results").unwrap()
  for seed in [24UL, 25UL] {
    let input = @validate.gen_valid_module_from_seed(
        seed,
        @validate.GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    assert_true(input.name_sec is Some(_))
    for
      pass in [
        "dae2", "dae2-optimizing", "tuple-optimization", "optimize-instructions",
      ] {
      let output = match
        run_hot_pipeline(input, HotPipelineOptions::new(), [pass]) {
        Ok(output) => output
        Err(err) => fail("named tuple \{seed}/\{pass}: \{err}")
      }
      match @validate.validate_module(output) {
        Ok(_) => ()
        Err(err) => fail("named tuple output \{seed}/\{pass}: \{err}")
      }
    }
  }
}

///|
test "dae2 avoids exception reference captures when legacy handlers never rethrow" {
  let output = dae2_test_run(
    (
      #|(module (tag $tag (param i32)) (global $effects (mut i32) (i32.const 0))
      #| (func $source (param i32) (result i32)
      #|  (global.set $effects (i32.add (global.get $effects) (i32.const 1))) (local.get 0))
      #| (func $sink (param i32)
      #|  (global.set $effects (i32.add (global.get $effects) (i32.const 2))))
      #| (func (export "run") (result i32)
      #|  (try (result i32) (do (throw $tag (i32.const 7)))
      #|   (catch $tag (call $source) (call $sink) (i32.const 7))
      #|   (catch_all (i32.const 6)))))
    ),
    "dae2",
  )
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[2]
  for local_type in locals {
    assert_false(local_type is @lib.RefTypeValType(_))
  }
  @debug.assert_eq(dae2_test_signature(output, 0), @lib.FuncType::new([], []))
  @debug.assert_eq(dae2_test_signature(output, 1), @lib.FuncType::new([], []))
}

///|
test "dae2 solves result to unused parameter dependencies in one graph" {
  for pass in ["dae2", "dae2-optimizing"] {
    let mod_ = dae2_test_run(
      (
        #|(module
        #|  (func $source (param i32) (result i32) (local.get 0))
        #|  (func $sink (param i32))
        #|  (func (export "run") (param i32)
        #|    (call $sink (call $source (local.get 0)))))
      ),
      pass,
    )
    @debug.assert_eq(dae2_test_signature(mod_, 0), @lib.FuncType::new([], []))
    @debug.assert_eq(dae2_test_signature(mod_, 1), @lib.FuncType::new([], []))
    @debug.assert_eq(
      dae2_test_signature(mod_, 2),
      @lib.FuncType::new([@lib.ValType::i32()], []),
    )
  }
}

///|
test "dae2 removes mutually recursive forwarded parameters and result tuples" {
  let mod_ = dae2_test_run(
    (
      #|(module
      #|  (func $a (param i32 i64) (result i32 i64)
      #|    (call $b (i32.add (local.get 0) (i32.const 1)) (local.get 1)))
      #|  (func $b (param i32 i64) (result i32 i64)
      #|    (call $a (local.get 0) (local.get 1)))
      #|  (func (export "run")
      #|    (call $a (i32.const 4) (i64.const 5)) drop drop))
    ),
    "dae2",
  )
  for index in [0, 1] {
    @debug.assert_eq(
      dae2_test_signature(mod_, index),
      @lib.FuncType::new([], []),
    )
  }
}

///|
test "dae2 propagates observable usage through a result and parameter cycle" {
  let source =
    #|(module
    #|  (func $a (param i32) (result i32) (call $b (local.get 0)))
    #|  (func $b (param i32) (result i32)
    #|    (if (result i32) (local.get 0)
    #|      (then (call $a (i32.sub (local.get 0) (i32.const 1))))
    #|      (else (i32.const 7))))
    #|  (func (export "run") (param i32) (result i32)
    #|    (call $a (local.get 0))))
  let mod_ = dae2_test_run(source, "dae2")
  for index in [0, 1, 2] {
    @debug.assert_eq(
      dae2_test_signature(mod_, index),
      @lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()]),
    )
  }
}

///|
test "dae2 keeps an open world indirect tail caller result per post release 8994" {
  let mod_ = dae2_test_run(
    (
      #|(module
      #|  (type $sig (func (result i32)))
      #|  (import "env" "table" (table 1 funcref))
      #|  (func $tail (result i32)
      #|    (return_call_indirect (type $sig) (i32.const 0)))
      #|  (func (export "run") (drop (call $tail))))
    ),
    "dae2",
  )
  @debug.assert_eq(
    dae2_test_signature(mod_, 0),
    @lib.FuncType::new([], [@lib.ValType::i32()]),
  )
}

///|
test "dae2 retains a whole result tuple when any slot is observed" {
  let mod_ = dae2_test_run(
    (
      #|(module
      #|  (func $pair (result i32 i64) (i32.const 4) (i64.const 5))
      #|  (func (export "run") (result i32) (call $pair) drop))
    ),
    "dae2",
  )
  @debug.assert_eq(
    dae2_test_signature(mod_, 0),
    @lib.FuncType::new([], [@lib.ValType::i32(), @lib.ValType::i64()]),
  )
}

///|
test "dae2 removes unused results while retaining division traps and operands" {
  let source =
    #|(module
    #|  (func $divide (param i32 i32) (result i32)
    #|    (i32.div_s (local.get 0) (local.get 1)))
    #|  (func (export "run") (drop (call $divide (i32.const 1) (i32.const 0)))))
  let mod_ = dae2_test_run(source, "dae2")
  @debug.assert_eq(
    dae2_test_signature(mod_, 0),
    @lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], []),
  )
  let hot = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  assert_true(
    (
      @ir.effects_for_region(hot, @ir.HotRegionRef::root()) &
      @ir.EFFECT_MASK_TRAP
    ) !=
    0U,
  )
}

///|
test "dae2 removes overwritten incoming parameters but preserves subsequent reads" {
  let source =
    #|(module
    #|  (func $callee (param i32) (result i32)
    #|    (local.set 0 (i32.const 9)) (local.get 0))
    #|  (func (export "run") (result i32) (call $callee (i32.const 4))))
  let mod_ = dae2_test_run(source, "dae2")
  @debug.assert_eq(
    dae2_test_signature(mod_, 0),
    @lib.FuncType::new([], [@lib.ValType::i32()]),
  )
}

///|
test "dae2 removes nonnullable forwarded parameters without inventing an initial value" {
  let source =
    #|(module
    #|  (type $s (struct (field i32)))
    #|  (func $sink (param (ref $s)))
    #|  (func $forward (param (ref $s)) (call $sink (local.get 0)))
    #|  (func (export "run") (call $forward (struct.new $s (i32.const 7)))))
  let mod_ = dae2_test_run(source, "dae2")
  for index in [0, 1] {
    @debug.assert_eq(
      dae2_test_signature(mod_, index),
      @lib.FuncType::new([], []),
    )
  }
}

///|
test "dae2 accepts and validates every dedicated GenValid family" {
  for
    name in [
      "dae2-forwarded-results", "dae2-cycles", "dae2-control-flow", "dae2-effectful-arguments",
      "dae2-tuple-results", "dae2-tail-calls", "dae2-indirect", "dae2-open-world",
      "dae2-reference-types", "dae2-locals", "dae2-continuations", "dae2-exceptions",
      "dae2-call-ref", "dae2-intrinsics",
    ] {
    let profile = match @validate.gen_valid_profile_by_name(name) {
      Ok(profile) => profile
      Err(err) => fail(err)
    }
    for seed in [0UL, 1UL, 0x5eedUL, 0xffffffffffffffffUL] {
      let input = match
        @validate.gen_valid_module_from_seed(
          seed,
          @validate.GenValidConfig::for_profile(profile),
        ) {
        Ok(generated) => generated.wasm_module
        Err(err) => fail(err.validation_error_message)
      }
      for closed_world in [false, true] {
        match
          run_hot_pipeline(input, HotPipelineOptions::new(closed_world~), [
            "dae2",
          ]) {
          Ok(output) =>
            match @validate.validate_module(output) {
              Ok(_) => ()
              Err(err) => fail("\{name} seed \{seed}: \{err}")
            }
          Err(err) => fail("\{name} seed \{seed}: \{err}")
        }
      }
    }
  }
}

///|
test "dae2 closed world rewrites referenced signatures and keeps direct siblings separate" {
  let source =
    #|(module
    #|  (type $sig (func (param i32) (result i32)))
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) $target)
    #|  (func $target (type $sig) (param i32) (result i32) (local.get 0))
    #|  (func $direct (type $sig) (param i32) (result i32) (local.get 0))
    #|  (func (export "run") (result i32)
    #|    (drop (call_indirect (type $sig) (i32.const 42) (i32.const 0)))
    #|    (drop (call_ref (type $sig) (i32.const 43) (ref.func $target)))
    #|    (call $direct (i32.const 9))))
  let input = match @wast.wast_to_binary_module(source) {
    Ok(mod_) => mod_
    Err(err) => fail("closed world fixture: \{err}")
  }
  let mod_ = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), ["dae2"]) {
    Ok(mod_) => mod_
    Err(err) => fail(err)
  }
  @debug.assert_eq(dae2_test_signature(mod_, 0), @lib.FuncType::new([], []))
  @debug.assert_eq(
    dae2_test_signature(mod_, 1),
    @lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()]),
  )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => fail("invalid referenced signature rewrite: \{err}")
  }
}

///|
test "dae2 closed world keeps block signatures separate from rewritten call signatures" {
  let source =
    #|(module
    #|  (type $sig (func (result i32 i64)))
    #|  (table 1 funcref) (elem (i32.const 0) $target)
    #|  (func $target (type $sig) (result i32 i64) (i32.const 1) (i64.const 2))
    #|  (func (export "run") (param i32) (result i32 i64)
    #|    (call_indirect (type $sig) (i32.const 0)) drop drop
    #|    (block (type $sig) (i32.const 3) (i64.const 4))))
  let mod_ = match
    pass_test_run_pipeline(
      source,
      ["dae2"],
      options=HotPipelineOptions::new(closed_world=true),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail(err)
  }
  @debug.assert_eq(dae2_test_signature(mod_, 0), @lib.FuncType::new([], []))
  @debug.assert_eq(
    dae2_test_signature(mod_, 1),
    @lib.FuncType::new([@lib.ValType::i32()], [
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ]),
  )
}

///|
test "dae2 closed world pins a signature reachable from an exported typed table" {
  let source =
    #|(module
    #|  (type $sig (func (param i32) (result i32)))
    #|  (table (export "table") 1 (ref null $sig)) (elem declare func $target)
    #|  (func $target (type $sig) (param i32) (result i32) (local.get 0))
    #|  (func (export "run") (drop (ref.func $target)) (drop (call $target (i32.const 3)))))
  let mod_ = match
    pass_test_run_pipeline(
      source,
      ["dae2"],
      options=HotPipelineOptions::new(closed_world=true),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail(err)
  }
  @debug.assert_eq(
    dae2_test_signature(mod_, 0),
    @lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()]),
  )
}

///|
test "dae2 remaps retained local names and removes names for pruned parameters" {
  let source =
    #|(module
    #|  (type $object (struct (field i32)))
    #|  (func $callee (param i32 i32) (result i32) (local i32)
    #|    (local.set 2 (local.get 1)) (local.get 2))
    #|  (func (export "run") (param i32) (result i32)
    #|    (call $callee (i32.const 0) (local.get 0))))
  let input = match @wast.wast_to_binary_module(source) {
    Ok(input) => input
    Err(err) => fail("\{err}")
  }
  let input = input.with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            0U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("unused")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("argument")),
              @lib.NameAssoc::new(2U, @lib.Name::from_string("saved")),
            ]),
          ),
        ]),
      ),
    ),
  )
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]) {
    Ok(output) => output
    Err(err) => fail(err)
  }
  let names = match output.name_sec {
    Some(sec) => sec.local_names
    None => None
  }
  @debug.assert_eq(
    names,
    Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          0U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("argument")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("saved")),
          ]),
        ),
      ]),
    ),
  )
}

///|
test "dae2 removes a whole tuple result without duplicating its effectful producer" {
  let source =
    #|(module (global $count (mut i32) (i32.const 0))
    #| (func $producer (param i32) (result i32 i64)
    #|  (global.set $count (i32.add (global.get $count) (i32.const 1)))
    #|  (local.get 0) (i64.const 9))
    #| (func $sink (param i32 i64))
    #| (func (export "run") (result i32)
    #|  (i32.const 4) (call $producer) (call $sink) (global.get $count)))
  let output = dae2_test_run(source, "dae2")
  let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(2U))
  let mut producers = 0
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    let data = @ir.hot_node_get(hot, node)
    if data.op is @ir.Call && data.imm0 == 0 {
      producers += 1
    }
  }
  @debug.assert_eq(producers, 1)
  @debug.assert_eq(dae2_test_signature(output, 0), @lib.FuncType::new([], []))
}

///|
test "dae2 retains effectful legacy handlers and the throw that selects them" {
  let source =
    #|(module (global $count (mut i32) (i32.const 0)) (tag $t (param i32))
    #| (func $producer (param i32) (result i32)
    #|  (global.set $count (i32.add (global.get $count) (i32.const 1))) (local.get 0))
    #| (func $sink (param i32)
    #|  (global.set $count (i32.add (global.get $count) (i32.const 2))))
    #| (func (export "run") (result i32)
    #|  (try (do (throw $t (i32.const 7)))
    #|   (catch $t (call $producer) (call $sink))
    #|   (catch_all (global.set $count (i32.const 99))))
    #|  (global.get $count)))
  let input = match @wast.wast_to_binary_module(source) {
    Ok(input) => input
    Err(err) => fail("\{err}")
  }
  let prepared = match dae2_prepare_legacy_handlers(input) {
    Ok(prepared) => prepared
    Err(err) => fail(err)
  }
  let prepared_funcs = match prepared.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("missing prepared code")
  }
  let @lib.Func(_, @lib.Expr(prepared_body)) = prepared_funcs[2]
  @debug.assert_eq(
    dae2_test_count_calls(prepared_body),
    2,
    msg="legacy preparation retains calls",
  )
  let prepared_hot = @ir.hot_lift_func(prepared, @lib.FuncIdx::new(2U))
  let @lib.Func(_, @lib.Expr(roundtrip_body)) = @ir.hot_lower_func_unverified(
    prepared_hot,
  )
  @debug.assert_eq(
    dae2_test_count_calls(roundtrip_body),
    2,
    msg="legacy HOT roundtrip retains calls",
  )
  let output = dae2_test_run(source, "dae2")
  let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(2U))
  let mut calls = 0
  let mut throws = 0
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    match @ir.hot_node_get(hot, node).op {
      @ir.Call => calls += 1
      @ir.Throw => throws += 1
      _ => ()
    }
  }
  @debug.assert_eq(calls, 2)
  @debug.assert_eq(throws, 1)
}

///|
fn dae2_test_count_calls(body : Array[@lib.Instruction]) -> Int {
  let mut calls = 0
  for instr in body {
    match instr {
      @lib.Instruction::Call(_) => calls += 1
      @lib.Instruction::Block(_, @lib.Expr(nested))
      | @lib.Instruction::Loop(_, @lib.Expr(nested))
      | @lib.Instruction::TryTable(_, _, @lib.Expr(nested)) =>
        calls += dae2_test_count_calls(nested)
      @lib.Instruction::If(_, yes, no) => {
        calls += dae2_test_count_calls(yes)
        if no is Some(no) {
          calls += dae2_test_count_calls(no)
        }
      }
      _ => ()
    }
  }
  calls
}

///|
test "dae2 keeps a used tuple lane while discarding its sibling once" {
  let source =
    #|(module (global $count (mut i32) (i32.const 0))
    #| (func $producer (param i32) (result i32 i64)
    #|  (global.set $count (i32.add (global.get $count) (i32.const 1)))
    #|  (local.get 0) (i64.const 9))
    #| (func $sink (param i32 i64) (result i64) (local.get 1))
    #| (func (export "run") (result i64)
    #|  (i32.const 4) (call $producer) (call $sink)))
  let output = dae2_test_run(source, "dae2")
  let bodies = match output.code_sec {
    Some(@lib.CodeSec(bodies)) => bodies
    None => fail("missing code")
  }
  let @lib.Func(_, @lib.Expr(body)) = bodies[2]
  @debug.assert_eq(dae2_test_count_calls(body), 2)
  @debug.assert_eq(
    dae2_test_signature(output, 1),
    @lib.FuncType::new([@lib.ValType::i64()], [@lib.ValType::i64()]),
  )
}

///|
test "dae2 keeps exception target reachability through an intervening if and loop" {
  for wrapper in ["(if (i32.const 1) (then BODY))", "(loop BODY)"] {
    let source =
      #|(module (tag $t (param i32))
      #| (func $sink (param i32))
      #| (func (export "run") (result i32)
      #|  (block $caught (result i32)
      #|   WRAPPER
      #|   (unreachable))
      #|  (call $sink) (i32.const 7)))
    let body = "(try_table (catch $t $caught) (throw $t (i32.const 42)))"
    let source = source.replace(
      old="WRAPPER",
      new=wrapper.replace(old="BODY", new=body),
    )
    let output = dae2_test_run(source, "dae2")
    let bodies = match output.code_sec {
      Some(@lib.CodeSec(bodies)) => bodies
      None => fail("missing code")
    }
    let @lib.Func(_, @lib.Expr(body)) = bodies[1]
    @debug.assert_eq(dae2_test_count_calls(body), 1)
  }
}

///|
fn dae2_test_flat_opcodes(
  body : Array[@lib.Instruction],
  out : Array[@lib.Instruction],
) -> Unit {
  for instr in body {
    match instr {
      @lib.Instruction::Block(_, @lib.Expr(nested))
      | @lib.Instruction::Loop(_, @lib.Expr(nested)) =>
        dae2_test_flat_opcodes(nested, out)
      @lib.Instruction::If(_, yes, no) => {
        dae2_test_flat_opcodes(yes, out)
        if no is Some(no) {
          dae2_test_flat_opcodes(no, out)
        }
      }
      _ => out.push(instr)
    }
  }
}

///|
test "new analyses preserve a pending memory read before a later clobbering call" {
  let source =
    #|(module (memory (export "memory") 1)
    #| (func $clobber (param i32) (i32.store (local.get 0) (i32.const 99)))
    #| (func $sink (param i32 i32) (result i32) (local.get 0))
    #| (func (export "run") (param i32) (result i32)
    #|  (drop (i32.eq (local.get 0) (local.get 0)))
    #|  (i32.const 0) (i32.load)
    #|  (local.get 0) (call $clobber)
    #|  (i32.const 7) (call $sink)))
  for pass in ["dae2", "constraint-analysis"] {
    let output = dae2_test_run(source, pass)
    let bodies = match output.code_sec {
      Some(@lib.CodeSec(bodies)) => bodies
      None => fail("missing code")
    }
    let @lib.Func(_, @lib.Expr(body)) = bodies[2]
    let ops : Array[@lib.Instruction] = []
    dae2_test_flat_opcodes(body, ops)
    let mut load = -1
    let mut clobber = -1
    for index = 0; index < ops.length(); index = index + 1 {
      match ops[index] {
        @lib.Instruction::I32Load(_) => load = index
        @lib.Instruction::Call(@lib.FuncIdx(0U)) => clobber = index
        _ => ()
      }
    }
    @debug.assert_eq(load >= 0 && clobber > load, true, msg=pass)
  }
}

///|
test "dae2 preserves local writes inside a value producing if operand" {
  let source =
    #|(module (func (export "run") (param i32) (result i32) (local i32 i32)
    #| local.get 0 if (result i32)
    #|  i32.const 13 local.set 1 i32.const 0
    #| else i32.const 27 local.set 1 i32.const 1 end
    #| local.set 2 local.get 1))
  let output = dae2_test_run(source, "dae2")
  @debug.assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    ),
    2,
  )
}

///|
test "dae2 pending captures define scratch locals before their first read" {
  let source =
    #|(module (memory 1) (func (export "run") (result i32) (local i32)
    #| memory.size local.tee 0 i32.const 0 i32.load local.get 0 i32.add i32.add))
  let output = dae2_test_run(source, "dae2")
  let @lib.CodeSec(bodies) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = bodies[0]
  let initialized : Array[UInt] = []
  fn visit(body : Array[@lib.Instruction]) -> Unit raise {
    for instr in body {
      match instr {
        @lib.LocalSet(@lib.LocalIdx(index))
        | @lib.LocalTee(@lib.LocalIdx(index)) => initialized.push(index)
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          @debug.assert_eq(initialized.contains(index), true)
        @lib.Block(_, @lib.Expr(nested)) => visit(nested)
        _ => ()
      }
    }
  }
  visit(body)
}

///|
test "dae2 type liveness retains a struct wait annotation without a typed receiver" {
  let used = [false, false, false]
  dae_collect_used_type_idx_instrs(
    [@lib.Instruction::struct_wait(@lib.TypeIdx::new(2U), @lib.U32(0U))],
    used,
  )
  @debug.assert_eq(used, [false, false, true])
}

///|
test "dae2 preserves tuple bodies when every parameter and result remains used" {
  let source =
    #|(module (func (export "run") (param i32) (result i32 i64) (local i32)
    #| (if (result i32 i64) (local.get 0)
    #|   (then (local.get 1) (local.set 1 (i32.const 9)) (i64.const 2))
    #|   (else (local.get 0) (i64.const 3)))))
  let original = @wast.wast_to_binary_module(source).unwrap()
  let output = dae2_test_run(source, "dae2")
  @debug.assert_eq(output.code_sec, original.code_sec)
}

///|
test "dae2 keeps an unaffected tuple producer compact while rewriting its consumer" {
  let source =
    #|(module
    #| (func $pair (param i32) (result i32 i64) (local i32)
    #|   (if (result i32 i64) (local.get 0)
    #|     (then (local.get 1) (local.set 1 (i32.const 9)) (i64.const 2))
    #|     (else (local.get 0) (i64.const 3))))
    #| (func $first (param i32 i64) (result i32) (local.get 0))
    #| (func (export "run") (result i32) (call $pair (i32.const 1)) (call $first)))
  let output = dae2_test_run(source, "dae2")
  @debug.assert_eq(
    dae2_test_signature(output, 1),
    @lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()]),
  )
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.length(), 1)
}

///|
test "dae2 preserves outer exception identity for nested legacy rethrow" {
  let input = pass_test_module_from_wat(
    (
      #|(module (tag $outer (param i32)) (tag $inner)
      #| (func (export "run") (result i32)
      #|  (try (result i32) (do (throw $outer (i32.const 7)))
      #|   (catch $outer drop
      #|    (try (result i32) (do (throw $inner))
      #|     (catch $inner (rethrow 1))
      #|     (catch_all (i32.const 3))))
      #|   (catch_all (i32.const 4)))))
    ),
  )
  let prepared = match dae2_prepare_legacy_handlers(input) {
    Ok(output) => output
    Err(err) => fail(err)
  }
  match @validate.validate_module(prepared) {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }
  let @lib.Func(locals, _) = prepared.code_sec.unwrap().0[0]
  assert_true(locals.iter().any(fn(ty) { ty == @lib.ValType::ref_null_exn() }))
  let hot = @ir.hot_lift_func(prepared, @lib.FuncIdx::new(0U))
  let mut throw_refs = 0
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    if @ir.hot_node_get(hot, node).op is @ir.ThrowRef {
      throw_refs += 1
    }
  }
  assert_eq(throw_refs, 1)
}

///|
test "dae2 optimizing evaluates overlapping private tuple results once" {
  let source =
    #|(module (global (export "effects") (mut i32) (i32.const 0)) (func (param i32) (result i32 i32 i32) global.get 0 i32.const 1 i32.add global.set 0 i32.const 42 i32.const 101 i32.const 202) (func (param i32 i32 i32) (result i32) local.get 0 local.get 1 i32.const 31 i32.mul i32.add local.get 2 i32.const 997 i32.mul i32.add) (func (export "run") (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 6 local.set 10 local.set 9 local.get 9 local.get 10 local.get 6 call 1))
  for pass in ["dae2", "dae2-optimizing"] {
    let output = dae2_test_run(source, pass)
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
    @debug.assert_eq(dae2_test_count_calls(body), 2)
    @debug.assert_eq(
      dae2_test_signature(output, 0),
      @lib.FuncType::new([], [
        @lib.ValType::i32(),
        @lib.ValType::i32(),
        @lib.ValType::i32(),
      ]),
    )
  }
}

///|
test "dae2 optimizing accepts a valid explicit empty code section" {
  let input = @lib.Module::new().with_code_sec(@lib.CodeSec::new([]))
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2-optimizing"]) {
    Ok(output) => output
    Err(err) => fail("empty code section: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "dae2 reuses an existing identical pruned function signature" {
  let source =
    #|(module
    #| (func (export "identity") (param i32) (result i32) local.get 0)
    #| (func (param i32 i32) (result i32) local.get 0)
    #| (func (export "run") (param i32) (result i32)
    #|  local.get 0 i32.const 7 call 1))
  for pass in ["dae2", "dae2-optimizing"] {
    let output = dae2_test_run(source, pass)
    let @lib.FuncSec(indices) = output.func_sec.unwrap()
    @debug.assert_eq(indices[1], indices[0])
  }
}

///|
test "dae2 observes implicit function exits and preserves their payloads" {
  let zero = @lib.LabelIdx::new(0U)
  let one = @lib.LabelIdx::new(1U)
  let value = @lib.Instruction::i32_const(@lib.I32(42))
  let bodies = [
    [value, @lib.Instruction::br(zero)],
    [
      value,
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::br_if(zero),
    ],
    [
      value,
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::br_if(zero),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          value,
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::br_table([one], zero),
        ]),
      ),
    ],
    [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          value,
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::br_table([zero], one),
        ]),
      ),
    ],
  ]
  for body in bodies {
    // Construct label immediates directly: the WAT frontend currently rejects
    // numeric references to the implicit function label.
    let base = pass_test_module_from_wat(
      "(module (func $exit (result i32) i32.const 42) (func (export \"run\") call $exit drop))",
    )
    let functions = base.code_sec.unwrap().0.copy()
    functions[0] = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
    let input = base.with_code_sec(@lib.CodeSec::new(functions))
    assert_true(@validate.validate_module(input) is Ok(_))
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_))
    @debug.assert_eq(
      dae2_test_signature(output, 0),
      @lib.FuncType::new([], [@lib.ValType::i32()]),
    )
  }
}
