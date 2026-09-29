///|
fn offset_metadata_test_custom_sec() -> @lib.CustomSec {
  @lib.CustomSec::new(
    @lib.Name::from_string("reloc.CODE"),
    b"opaque-code-offsets",
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
