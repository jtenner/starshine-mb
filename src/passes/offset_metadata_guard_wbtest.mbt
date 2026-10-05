///|
fn offset_metadata_test_custom_sec() -> @lib.CustomSec {
  @lib.CustomSec::new(
    @lib.Name::from_string("reloc.CODE"),
    b"opaque-code-offsets",
  )
}

///|
fn offset_metadata_test_named_custom_sec(name : String) -> @lib.CustomSec {
  @lib.CustomSec::new(
    @lib.Name::from_string(name),
    b"opaque-offset-sensitive-metadata",
  )
}

///|
test "string-gathering leaves offset-sensitive custom metadata unchanged" {
  let input = pass_test_module_from_wat(
    "(module (func (result stringref) (string.const \"gather\")))",
  ).with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(string_gathering_run_module_pass(input), input)
  let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "string-gathering",
  ]).unwrap()
  @debug.assert_eq(dispatched, input)
}

///|
test "string-gathering guards relocation and linking object metadata" {
  let base = pass_test_module_from_wat(
    "(module (func (result stringref) (string.const \"gather\")))",
  )
  for section_name in ["reloc.DATA", "linking"] {
    let input = base.with_custom_secs([
      offset_metadata_test_named_custom_sec(section_name),
    ])
    @debug.assert_eq(string_gathering_run_module_pass(input), input)
    let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "string-gathering",
    ]).unwrap()
    @debug.assert_eq(dispatched, input)
  }
}

///|
fn offset_metadata_test_reorder_module() -> @lib.Module {
  let globals : Array[@lib.Global] = []
  for idx = 0; idx < 129; idx = idx + 1 {
    globals.push(
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(idx))]),
      ),
    )
  }
  let body : Array[@lib.Instruction] = []
  for rep = 0; rep < 4; rep = rep + 1 {
    ignore(rep)
    body.push(@lib.Instruction::global_get(@lib.GlobalIdx::new(128U)))
    body.push(@lib.Instruction::drop())
  }
  @lib.Module::new(
    type_sec=Some(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    ),
    func_sec=Some(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])),
    global_sec=Some(@lib.GlobalSec::new(globals)),
    code_sec=Some(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      ]),
    ),
    custom_secs=[offset_metadata_test_custom_sec()],
  )
}

///|
test "reorder-globals leaves offset-sensitive custom metadata unchanged" {
  let input = offset_metadata_test_reorder_module()
  @debug.assert_eq(reorder_globals_run_module_pass_always(input), input)
  let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "reorder-globals",
  ]).unwrap()
  @debug.assert_eq(dispatched, input)
}

///|
test "duplicate-function-elimination leaves offset-sensitive custom metadata unchanged" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func $left (export "left") (result i32) i32.const 1)
      #|   (func $right (export "right") (result i32) i32.const 1))
      #|
    ),
  ).with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(dfe_run_module_pass(input), input)
  let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "duplicate-function-elimination",
  ]).unwrap()
  @debug.assert_eq(dispatched, input)
}

///|
test "global-refining leaves offset-sensitive custom metadata unchanged" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (type $base (sub (struct)))
      #|   (type $child (sub $base (struct)))
      #|   (global $g (mut (ref null $base)) (ref.null $child))
      #|   (func (export "set")
      #|     ref.null $child
      #|     global.set $g)
      #|   (func (export "get") (result (ref null $base))
      #|     global.get $g))
      #|
    ),
  ).with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(global_refining_run_module_pass(input), input)
  let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "global-refining",
  ]).unwrap()
  @debug.assert_eq(dispatched, input)
}

///|
test "inlining leaves offset-sensitive custom metadata unchanged" {
  let base = pass_test_module_from_wat(
    "(module (func $callee (result i32) i32.const 7) (func (export \"run\") (result i32) call $callee))",
  )
  assert_true(inlining_run_module_pass(base) != base)
  let input = base.with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(inlining_run_module_pass(input), input)
}

///|
test "inline-main leaves offset-sensitive custom metadata unchanged" {
  let base = pass_test_module_from_wat(
    "(module (func $__original_main (result i32) i32.const 7) (func $main (export \"main\") (result i32) call $__original_main))",
  )
  assert_true(inline_main_run_module_pass(base) != base)
  let input = base.with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(inline_main_run_module_pass(input), input)
}

///|
test "directize leaves offset-sensitive custom metadata unchanged" {
  let base = pass_test_module_from_wat(
    (
      #| (module
      #|   (type (func (result i32)))
      #|   (table 1 funcref)
      #|   (func $callee (type 0) (result i32) i32.const 7)
      #|   (elem (i32.const 0) $callee)
      #|   (func (export "run") (result i32)
      #|     i32.const 0
      #|     call_indirect (type 0)))
      #|
    ),
  )
  assert_true(directize_run_module_pass(base) != base)
  let input = base.with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(directize_run_module_pass(input), input)
}

///|
test "merge-similar-functions leaves offset-sensitive custom metadata unchanged" {
  let base = pass_test_module_from_wat(
    (
      #| (module
      #|   (func (result i32)
      #|     nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|     i32.const 42)
      #|   (func (result i32)
      #|     nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|     i32.const 43))
      #|
    ),
  )
  assert_true(merge_similar_functions_run_module_pass(base) != base)
  let input = base.with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(merge_similar_functions_run_module_pass(input), input)
}

///|
test "remove-unused-module-elements leaves offset-sensitive custom metadata unchanged" {
  let base = pass_test_module_from_wat(
    "(module (func) (func (export \"live\")))",
  )
  assert_true(rume_run_module_pass(base) != base)
  let input = base.with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(rume_run_module_pass(input), input)
  @debug.assert_eq(rume_run_nonfunction_module_pass(input), input)
}

///|
test "stable duplicate-import elimination leaves offset-sensitive custom metadata unchanged" {
  let base = pass_test_module_from_wat(
    (
      #| (module
      #|   (import "env" "f" (func $a))
      #|   (import "env" "f" (func $b))
      #|   (func (export "run") call $a call $b))
      #|
    ),
  )
  assert_true(die_run_module_pass_assume_stable_bindings(base) != base)
  let input = base.with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(die_run_module_pass_assume_stable_bindings(input), input)
}

///|
test "simplify-globals-optimizing leaves offset-sensitive custom metadata unchanged" {
  let base = pass_test_module_from_wat(
    "(module (global $g i32 (i32.const 7)) (func (export \"run\") (result i32) global.get $g))",
  )
  assert_true(sgo_run_core(base, fn(_) { () }).mod_out != base)
  let input = base.with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(sgo_run_core(input, fn(_) { () }).mod_out, input)
}

///|
test "propagate-globals-globally leaves offset-sensitive custom metadata unchanged" {
  let base = pass_test_module_from_wat(
    "(module (global $a i32 (i32.const 7)) (global i32 (global.get $a)))",
  )
  assert_true(propagate_globals_globally_run_module_pass(base) != base)
  let input = base.with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(propagate_globals_globally_run_module_pass(input), input)
}

///|
test "global-effects leaves offset-sensitive custom metadata unchanged" {
  let base = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x02, 0x60, 0x00,
        0x00, 0x5d, 0x00, 0x03, 0x03, 0x02, 0x00, 0x00, 0x07, 0x07, 0x01, 0x03, 0x72,
        0x75, 0x6e, 0x00, 0x01, 0x09, 0x05, 0x01, 0x03, 0x00, 0x01, 0x00, 0x0a, 0x0f,
        0x02, 0x03, 0x00, 0x01, 0x0b, 0x09, 0x00, 0xd2, 0x00, 0xe0, 0x01, 0xe3, 0x01,
        0x00, 0x0b,
      ]),
    ) {
    Ok(module_) => module_
    Err(err) => fail("continuation fixture cannot decode: \{err}")
  }
  assert_true(global_effects_run_module_pass(base) != base)
  let input = base.with_custom_secs([offset_metadata_test_custom_sec()])
  @debug.assert_eq(global_effects_run_module_pass(input), input)
}

///|
fn offset_metadata_test_dae_module() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #| (module
      #|   (func $callee (param i32))
      #|   (func (export "caller")
      #|     i32.const 7
      #|     call $callee))
      #|
    ),
  ).with_custom_secs([offset_metadata_test_custom_sec()])
}

///|
test "dead-argument-elimination leaves offset-sensitive metadata unchanged" {
  let input = offset_metadata_test_dae_module()
  @debug.assert_eq(dae_run_module_pass(input), input)
}

///|
test "dead-argument-elimination2 leaves offset-sensitive metadata unchanged" {
  let input = offset_metadata_test_dae_module()
  @debug.assert_eq(dae2_run_module_pass(input, false).unwrap(), input)
}

///|
test "central dispatch leaves offset-sensitive code unchanged" {
  let input = pass_test_module_from_wat(
    "(module (func (nop) (drop (i32.const 1))))",
  ).with_custom_secs([offset_metadata_test_custom_sec()])
  for pass in ["vacuum", "optimize-instructions", "tail-call"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    @debug.assert_eq(output, input)
  }
}

///|
test "central dispatch still applies metadata-safe no-inline policy" {
  let input = pass_test_module_from_wat(
    "(module (func $target (export \"target\")))",
  ).with_custom_secs([offset_metadata_test_custom_sec()])
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "no-inline=target",
  ]).unwrap()
  @debug.assert_eq(output.custom_secs, input.custom_secs)
  @debug.assert_eq(output.code_sec, input.code_sec)
  match output.func_annotation_sec {
    Some(@lib.FuncAnnotationSec([@lib.FuncAnnotationAssoc(0U, annotations)])) => {
      assert_true(
        annotations.any(fn(annotation) {
          annotation.name == "starshine.no-full-inline"
        }),
      )
      assert_true(
        annotations.any(fn(annotation) {
          annotation.name == "starshine.no-partial-inline"
        }),
      )
    }
    other => fail("expected no-inline policy annotations, got \{other}")
  }
}
