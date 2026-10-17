///|
fn dae2_suffix_shape_optimizing(
  input : @lib.Module,
  raw : Bool,
) -> @lib.Module raise {
  let next = dae2_run_module_pass(input, false, raw_rewrite=raw).unwrap()
  let cleaned = run_hot_pipeline(next, HotPipelineOptions::new(), [
    "simplify-locals", "vacuum",
  ]).unwrap()
  dae2_cleanup_captures(cleaned)
}

///|
fn dae2_suffix_shape_effects(
  instrs : Array[@lib.Instruction],
  out : Array[@lib.Instruction],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Call(_) | @lib.GlobalSet(_) | @lib.I32Load8U(_) | @lib.I64Load(_) =>
        out.push(instr)
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        dae2_suffix_shape_effects(body, out)
      @lib.If(_, yes, no) => {
        dae2_suffix_shape_effects(yes, out)
        match no {
          Some(body) => dae2_suffix_shape_effects(body, out)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn dae2_suffix_shape_compare(input : @lib.Module) -> @lib.Module raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_suffix_shape_optimizing(input, true)
  let reference = dae2_suffix_shape_optimizing(input, false)
  @validate.validate_module(output).unwrap()
  @validate.validate_module(reference).unwrap()
  let actual_bytes = @binary.encode_module(output).unwrap()
  let expected_bytes = @binary.encode_module(reference).unwrap()
  assert_true(
    actual_bytes.length() <= expected_bytes.length(),
    msg="raw suffix replay increased optimized encoded size",
  )
  let funcs = output.code_sec.unwrap().0
  let expected_funcs = reference.code_sec.unwrap().0
  assert_eq(funcs.length(), expected_funcs.length())
  for index in 0..<funcs.length() {
    let @lib.Func(locals, @lib.Expr(body)) = funcs[index]
    let @lib.Func(expected_locals, @lib.Expr(expected_body)) = expected_funcs[index]
    assert_eq(locals.length(), expected_locals.length())
    assert_eq(locals.runs(), expected_locals.runs())
    let effects = []
    let expected_effects = []
    dae2_suffix_shape_effects(body, effects)
    dae2_suffix_shape_effects(expected_body, expected_effects)
    assert_eq(effects, expected_effects)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  output
}

///|
test "DAE2 suffix optimizing removes held immutable aliases in indexed loop branches" {
  // This is the +4 byte artifact family. The loop runs at most three times.
  // The pointer read is held under the iterator copy before both local.sets.
  let input = pass_test_module_from_wat(
    "(module (type $entry (func (param i32))) (import \"e\" \"consume\" (func $consume (param i32))) (import \"e\" \"length\" (func $length (param i32) (result i32))) (import \"e\" \"check\" (func $check (param i32 i32 i32))) (memory 1) (global $g (mut i32) (i32.const 0)) (func $sink (param i32 i32) local.get 0 global.set $g) (func (export \"run\") (param i32 i32) (local i32 i32 i32) local.get 1 i32.const 3 i32.and loop (type $entry) local.set 2 local.get 2 i32.const 99 call $sink local.get 2 if local.get 0 local.get 2 local.set 3 local.set 4 local.get 3 i32.const 0 local.get 4 call $length i32.const 1 i32.sub call $check local.get 4 local.get 3 i32.add i32.load8_u call $consume end local.get 2 i32.const 1 i32.sub local.tee 2 i32.const 0 i32.gt_s if local.get 2 br 1 end end))",
  )
  let output = dae2_suffix_shape_compare(input)
  let reference = dae2_suffix_shape_optimizing(input, false)
  // Removing the immutable pointer copy also restores the exact HOT body.
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(locals.length(), 2)
  let effects = []
  dae2_suffix_shape_effects(body, effects)
  assert_eq(effects.filter(fn(instr) { instr is @lib.Call(_) }).length(), 4)
  assert_eq(
    effects.filter(fn(instr) { instr is @lib.I32Load8U(_) }).length(),
    1,
  )
}

///|
test "DAE2 suffix optimizing preserves compact mixed local declarations across held branch values" {
  // This is the +2 byte artifact family. One i64 load stays live across an
  // effectful branch; the bounded loop keeps both surrounding i32 locals live.
  let input = pass_test_module_from_wat(
    "(module (type $entry (func (param i32))) (import \"e\" \"p32\" (func $p32 (result i32))) (import \"e\" \"effect\" (func $effect)) (import \"e\" \"c32\" (func $c32 (param i32))) (import \"e\" \"c64\" (func $c64 (param i64))) (memory 1) (global $g (mut i32) (i32.const 0)) (func $sink (param i32 i32) local.get 0 global.set $g) (func (export \"run\") (param i32) (local i32 i64 i32) local.get 0 i32.const 3 i32.and loop (type $entry) local.set 1 i32.const 0 i64.load local.get 0 if call $effect else call $effect end local.set 2 call $p32 local.set 3 local.get 1 call $c32 local.get 2 call $c64 local.get 3 call $c32 local.get 1 call $c32 local.get 2 call $c64 local.get 3 call $c32 local.get 1 i32.const 99 call $sink local.get 1 i32.const 1 i32.sub local.tee 1 i32.const 0 i32.gt_s if local.get 1 br 1 end end))",
  )
  let output = dae2_suffix_shape_compare(input)
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(locals.runs(), [
    @lib.LocalRun::new(2U, @lib.ValType::i32()),
    @lib.LocalRun::new(1U, @lib.ValType::i64()),
  ])
  let effects = []
  dae2_suffix_shape_effects(body, effects)
  assert_eq(effects.filter(fn(instr) { instr is @lib.I64Load(_) }).length(), 1)
  assert_eq(effects.filter(fn(instr) { instr is @lib.Call(_) }).length(), 10)
}

///|
test "DAE2 held immutable alias cleanup removes nested copies without moving effectful calls" {
  let input = pass_test_module_from_wat(
    "(module (import \"e\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32 i32) (local i32 i32) local.get 0 local.get 1 local.set 2 local.set 3 local.get 3 call $consume local.get 2 call $consume local.get 3 call $consume local.get 2 call $consume))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_eq(body, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 held alias cleanup intentionally retains snapshots when a source is written" {
  for middle in ["i32.const 9", "local.get 1"] {
    let input = pass_test_module_from_wat(
      "(module (import \"e\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32 i32) (local i32) local.get 0 \{middle} local.set 0 local.set 2 local.get 2 call $consume local.get 0 call $consume local.get 2 call $consume))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let output = dae2_cleanup_captures(input)
    @validate.validate_module(output).unwrap()
    assert_eq(output.code_sec, input.code_sec)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
