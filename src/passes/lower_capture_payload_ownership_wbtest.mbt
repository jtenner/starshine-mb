///|
fn payload_ownership_compact_checked(
  input : @lib.Module,
  effects~ : Bool = false,
  aliases~ : Bool = false,
) -> @lib.Module raise {
  let saved = @binary.encode_module(input).unwrap()
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let func = input.code_sec.unwrap().0[0]
  let params = rl_defined_func_param_cache(input)[0]
  let context = @ir.hot_module_context_from_module(input)
  let query = if effects {
    Some(fn(instr) { dae2_capture_stack_effect(instr, input, context) })
  } else {
    None
  }
  let actual = pass_lower_compact_captures_with_map(
    func,
    original,
    params,
    stack_effects=query,
    propagate_parameter_aliases=aliases,
    reorder_body_locals=aliases,
  )
  let expected = payload_ownership_reference_pass_lower_compact_captures_with_map(
    func,
    original,
    params,
    stack_effects=query,
    propagate_parameter_aliases=aliases,
    reorder_body_locals=aliases,
  )
  assert_eq(actual, expected)
  let output = input.with_code_sec(@lib.CodeSec::new([actual.0]))
  let reference = input.with_code_sec(@lib.CodeSec::new([expected.0]))
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  output
}

///|
fn payload_ownership_find_select(
  body : Array[@lib.Instruction],
) -> Array[@lib.ValType]? {
  for instr in body {
    match instr {
      @lib.Select(Some(types)) => return Some(types)
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        match payload_ownership_find_select(child) {
          Some(types) => return Some(types)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn payload_ownership_find_table(
  body : Array[@lib.Instruction],
) -> Array[@lib.LabelIdx]? {
  for instr in body {
    match instr {
      @lib.BrTable(targets, _) => return Some(targets)
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        match payload_ownership_find_table(child) {
          Some(targets) => return Some(targets)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
test "capture payload behavior preserves productive leaf effect and alias plans" {
  for
    source in [
      "(module (func (export \"run\") (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 i32.const 32 i32.ctz local.set 2 local.get 1 local.get 2 i32.add))",
      "(module (import \"m\" \"produce\" (func $produce (result i32))) (import \"m\" \"consume\" (func $consume (param i32))) (func (export \"run\") (result i32) (local i32) call $produce local.set 0 i32.const 7 call $consume local.get 0))",
      "(module (func (export \"run\") (param f64) (result f64) (local f64) local.get 0 local.set 1 local.get 1 drop local.get 1))",
      "(module (func (export \"run\") (param i32 i32) (result i32) (local i32) local.get 0 if local.get 1 local.set 2 local.get 2 drop else local.get 2 drop end local.get 2))",
    ] {
    for effects in [false, true] {
      for aliases in [false, true] {
        ignore(
          payload_ownership_compact_checked(
            pass_test_module_from_wat(source),
            effects~,
            aliases~,
          ),
        )
      }
    }
  }
}

///|
test "capture payload behavior preserves nested handler counts and parameter prefix" {
  for
    source in [
      "(module (tag $t) (func (export \"run\") (param i32) (local i32 i32) block local.get 0 local.set 1 end loop local.get 1 local.tee 2 drop i32.const 0 br_if 0 end local.get 0 if local.get 1 drop else local.get 2 drop end (try (do (local.set 1 (local.get 0))) (catch $t (local.get 2) drop))))",
      "(module (func (export \"run\") (param i32) (local i32) block try_table (catch_all 0) local.get 0 local.set 1 end end local.get 0 if else end))",
    ] {
    let input = pass_test_module_from_wat(source)
    for effects in [false, true] {
      ignore(payload_ownership_compact_checked(input, effects~, aliases=true))
    }
  }
}

///|
test "capture payload behavior preserves productive public DAE2 optimizing bytes" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) (local i32) local.get 0 i32.const 9 call $h local.set 1 local.get 1))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let core = dae2_run_module_pass(input, false).unwrap()
  assert_eq(rl_defined_func_param_cache(core)[0].length(), 1)
  let cleaned = run_hot_pipeline(core, HotPipelineOptions::new(), [
    "simplify-locals", "vacuum",
  ]).unwrap()
  let expected = payload_ownership_reference_dae2_cleanup_captures(cleaned)
  let actual = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "dae2-optimizing",
  ]).unwrap()
  assert_eq(actual.code_sec, expected.code_sec)
  assert_eq(actual.type_sec, expected.type_sec)
  assert_eq(actual.name_sec, expected.name_sec)
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  @validate.validate_module(actual).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "capture payload behavior owns changed nested body storage" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) (local i32 i32) block local.get 0 local.set 1 local.get 1 drop local.get 1 drop end local.get 0))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = payload_ownership_compact_checked(input)
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  let child = match body[0] {
    @lib.Block(_, @lib.Expr(child)) => child
    _ => fail("missing retained block")
  }
  child.push(@lib.Instruction::nop())
  body.push(@lib.Instruction::nop())
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
fn payload_ownership_find_try_table(
  body : Array[@lib.Instruction],
) -> Array[@lib.Catch]? {
  for instr in body {
    match instr {
      @lib.TryTable(_, catches, _) => return Some(catches)
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        match payload_ownership_find_try_table(child) {
          Some(catches) => return Some(catches)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn payload_ownership_mutation_checked(
  kind : String,
  aliases : Bool,
) -> Unit raise {
  let middle = match kind {
    "select" => "i32.const 1 i32.const 2 i32.const 0 select (result i32) drop"
    "table" => "block i32.const 0 br_table 0 0 end"
    "catch" => "block try_table (catch_all 0) local.get 1 drop end end"
    _ => fail("unknown payload fixture")
  }
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 \{middle} local.get 1))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = payload_ownership_compact_checked(input, aliases~)
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), if aliases { 0 } else { 1 })
  // Full exact maps/IR/params/types/module bytes/validity/input gates in the
  // checker run before a change to the newly returned output vector.
  match kind {
    "select" => {
      let types = payload_ownership_find_select(body).unwrap()
      assert_eq(types, [@lib.ValType::i32()])
      types[0] = @lib.ValType::i64()
    }
    "table" => {
      let targets = payload_ownership_find_table(body).unwrap()
      assert_eq(targets, [@lib.LabelIdx::new(0U)])
      targets[0] = @lib.LabelIdx::new(1U)
    }
    "catch" => {
      let catches = payload_ownership_find_try_table(body).unwrap()
      assert_eq(catches, [@lib.Catch::all(@lib.LabelIdx::new(0U))])
      catches[0] = @lib.Catch::all(@lib.LabelIdx::new(1U))
    }
    _ => fail("unknown payload mutation")
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "ordinary compact output owns typed Select vector" {
  payload_ownership_mutation_checked("select", false)
}

///|
test "alias compact output owns typed Select vector" {
  payload_ownership_mutation_checked("select", true)
}

///|
test "ordinary compact output owns BrTable target vector" {
  payload_ownership_mutation_checked("table", false)
}

///|
test "alias compact output owns BrTable target vector" {
  payload_ownership_mutation_checked("table", true)
}

///|
test "ordinary compact output owns TryTable Catch vector" {
  payload_ownership_mutation_checked("catch", false)
}

///|
test "alias compact output owns TryTable Catch vector" {
  payload_ownership_mutation_checked("catch", true)
}

///|
fn payload_ownership_mutate_nested(
  body : Array[@lib.Instruction],
  kind : String,
) -> Int32 raise {
  let mut mutated = 0
  for instr in body {
    match instr {
      @lib.Select(Some(types)) if kind == "select" => {
        assert_eq(types, [@lib.ValType::i32()])
        types[0] = @lib.ValType::i64()
        mutated += 1
      }
      @lib.BrTable(targets, _) if kind == "table" => {
        assert_eq(targets, [@lib.LabelIdx::new(0U)])
        targets[0] = @lib.LabelIdx::new(1U)
        mutated += 1
      }
      @lib.TryTable(_, catches, @lib.Expr(child)) => {
        if kind == "catch" {
          assert_eq(catches, [@lib.Catch::all(@lib.LabelIdx::new(0U))])
          catches[0] = @lib.Catch::all(@lib.LabelIdx::new(1U))
          mutated += 1
        }
        mutated += payload_ownership_mutate_nested(child, kind)
      }
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        mutated += payload_ownership_mutate_nested(child, kind)
      @lib.If(_, yes, no) => {
        mutated += payload_ownership_mutate_nested(yes, kind)
        match no {
          Some(child) => mutated += payload_ownership_mutate_nested(child, kind)
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(child), catches, _) => {
        mutated += payload_ownership_mutate_nested(child, kind)
        for handler in catches {
          let child = match handler {
            @lib.LegacyCatch(_, @lib.Expr(child))
            | @lib.LegacyCatchAll(@lib.Expr(child)) => child
          }
          mutated += payload_ownership_mutate_nested(child, kind)
        }
      }
      _ => ()
    }
  }
  mutated
}

///|
fn payload_ownership_nested_checked(
  context : String,
  kind : String,
  aliases : Bool,
) -> Unit raise {
  let middle = match kind {
    "select" => "i32.const 1 i32.const 2 i32.const 0 select (result i32) drop"
    "table" => "block i32.const 0 br_table 0 0 end"
    "catch" => "block try_table (catch_all 0) local.get 1 drop end end"
    _ => fail("unknown nested payload fixture")
  }
  let nested = if context == "if" {
    "local.get 0 if \{middle} else \{middle} end"
  } else {
    "(try (do \{middle}) (catch $t \{middle}) (catch_all \{middle}))"
  }
  let input = pass_test_module_from_wat(
    "(module (tag $t) (func (export \"run\") (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 \{nested} local.get 1))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = payload_ownership_compact_checked(input, effects=true, aliases~)
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), if aliases { 0 } else { 1 })
  // Check actual vectors in both If arms or Try body/tagged/all handlers.
  // Input bytes and full old-reference IR/maps/encoding/validation passed first.
  assert_eq(
    payload_ownership_mutate_nested(body, kind),
    if context == "if" {
      2
    } else {
      3
    },
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "ordinary output owns typed Select vectors in If then and else" {
  payload_ownership_nested_checked("if", "select", false)
}

///|
test "alias output owns typed Select vectors in If then and else" {
  payload_ownership_nested_checked("if", "select", true)
}

///|
test "ordinary output owns BrTable vectors in If then and else" {
  payload_ownership_nested_checked("if", "table", false)
}

///|
test "alias output owns BrTable vectors in If then and else" {
  payload_ownership_nested_checked("if", "table", true)
}

///|
test "ordinary output owns TryTable vectors in If then and else" {
  payload_ownership_nested_checked("if", "catch", false)
}

///|
test "alias output owns TryTable vectors in If then and else" {
  payload_ownership_nested_checked("if", "catch", true)
}

///|
test "ordinary output owns typed Select vectors in legacy Try body and handlers" {
  payload_ownership_nested_checked("legacy", "select", false)
}

///|
test "alias output owns typed Select vectors in legacy Try body and handlers" {
  payload_ownership_nested_checked("legacy", "select", true)
}

///|
test "ordinary output owns BrTable vectors in legacy Try body and handlers" {
  payload_ownership_nested_checked("legacy", "table", false)
}

///|
test "alias output owns BrTable vectors in legacy Try body and handlers" {
  payload_ownership_nested_checked("legacy", "table", true)
}

///|
test "ordinary output owns TryTable vectors in legacy Try body and handlers" {
  payload_ownership_nested_checked("legacy", "catch", false)
}

///|
test "alias output owns TryTable vectors in legacy Try body and handlers" {
  payload_ownership_nested_checked("legacy", "catch", true)
}
