///|
test "merge-similar-functions accepted merge preserves the name section" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (global (mut i32) (i32.const 0))
      #|  (func $left (result i32)
      #|    global.get 0 i32.const 1 i32.add global.set 0
      #|    global.get 0 i32.const 1 i32.add global.set 0
      #|    global.get 0 i32.const 1 i32.add global.set 0
      #|    global.get 0 i32.const 1 i32.add global.set 0
      #|    i32.const 42)
      #|  (func $right (result i32)
      #|    global.get 0 i32.const 1 i32.add global.set 0
      #|    global.get 0 i32.const 1 i32.add global.set 0
      #|    global.get 0 i32.const 1 i32.add global.set 0
      #|    global.get 0 i32.const 1 i32.add global.set 0
      #|    i32.const 43))
    ),
  ).with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("left")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("right")),
        ]),
      ),
    ),
  )
  assert_true(input.name_sec is Some(_))
  @debug.assert_eq(input.code_sec.unwrap().0.length(), 2)
  let output = merge_similar_functions_run_module_pass(input)
  // A third function proves that sharing was accepted, rather than a no-op.
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 3)
  assert_true(@validate.validate_module(output) is Ok(_))
  @debug.assert_eq(output.name_sec, input.name_sec)
}

///|
fn msf_names_test_map(entries : Array[(UInt32, String)]) -> @lib.NameMap {
  @lib.NameMap::new(
    entries.map(fn(entry) {
      @lib.NameAssoc::new(entry.0, @lib.Name::from_string(entry.1))
    }),
  )
}

///|
fn msf_names_test_indirect(
  entries : Array[(UInt32, Array[(UInt32, String)])],
) -> @lib.IndirectNameMap {
  @lib.IndirectNameMap::new(
    entries.map(fn(entry) {
      @lib.IndirectNameAssoc::new(entry.0, msf_names_test_map(entry.1))
    }),
  )
}

///|
test "merge-similar-functions remaps body names and preserves other name subsections" {
  let names = @lib.NameSec::new(
    module_name=Some(@lib.Name::from_string("named-module")),
    func_names=Some(
      msf_names_test_map([
        (0U, "imported"),
        (1U, "left"),
        (2U, "right"),
        (3U, "untouched"),
      ]),
    ),
    local_names=Some(
      msf_names_test_indirect([
        (0U, [(0U, "import-param")]),
        (1U, [(0U, "x"), (1U, "y"), (2U, "scratch")]),
        (2U, [(0U, "a"), (1U, "b"), (2U, "temporary")]),
        (3U, [(0U, "unchanged")]),
      ]),
    ),
    label_names=Some(
      msf_names_test_indirect([
        (1U, [(0U, "left-block")]),
        (2U, [(0U, "right-block")]),
        (3U, [(0U, "unchanged-block")]),
      ]),
    ),
    type_names=Some(msf_names_test_map([(0U, "signature")])),
    table_names=Some(msf_names_test_map([(0U, "table")])),
    memory_names=Some(msf_names_test_map([(0U, "memory")])),
    global_names=Some(msf_names_test_map([(0U, "global")])),
    elem_names=Some(msf_names_test_map([(0U, "element")])),
    data_names=Some(msf_names_test_map([(0U, "data")])),
    field_names=Some(msf_names_test_indirect([(0U, [(0U, "field")])])),
    tag_names=Some(msf_names_test_map([(0U, "tag")])),
  )
  let source = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "env" "imported" (func (param i32)))
      #|  (func (param i32 i32) (result i32) (local i32)
      #|    block
      #|      nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|      nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|      nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    end
      #|    i32.const 42 local.get 0 i32.add local.get 2 i32.add)
      #|  (func (param i32 i32) (result i32) (local i32)
      #|    block
      #|      nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|      nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|      nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|    end
      #|    i32.const 43 local.get 0 i32.add local.get 2 i32.add)
      #|  (func (param i32) block nop end))
    ),
  ).with_name_sec(names)
  // Decode first so the input has a cached raw name payload as well.
  let input = @binary.decode_module(@binary.encode_module(source).unwrap()).unwrap()
  assert_true(input.raw_name_sec_payload is Some(_))
  for dispatched in [false, true] {
    let output = if dispatched {
      run_hot_pipeline(input, HotPipelineOptions::new(), [
        "merge-similar-functions",
      ]).unwrap()
    } else {
      merge_similar_functions_run_module_pass(input)
    }
    @debug.assert_eq(output.code_sec.unwrap().0.length(), 4)
    let expected = @lib.NameSec::new(
      module_name=names.module_name,
      func_names=names.func_names,
      local_names=Some(
        msf_names_test_indirect([
          (0U, [(0U, "import-param")]),
          (1U, [(0U, "x"), (1U, "y")]),
          (2U, [(0U, "a"), (1U, "b")]),
          (3U, [(0U, "unchanged")]),
          (4U, [(0U, "x"), (1U, "y"), (3U, "scratch")]),
        ]),
      ),
      label_names=Some(
        msf_names_test_indirect([
          (3U, [(0U, "unchanged-block")]),
          (4U, [(0U, "left-block")]),
        ]),
      ),
      type_names=names.type_names,
      table_names=names.table_names,
      memory_names=names.memory_names,
      global_names=names.global_names,
      elem_names=names.elem_names,
      data_names=names.data_names,
      field_names=names.field_names,
      tag_names=names.tag_names,
    )
    @debug.assert_eq(output.name_sec, Some(expected))
    @debug.assert_eq(output.raw_name_sec_payload, None)
    assert_true(@validate.validate_module(output) is Ok(_))
    let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
    @debug.assert_eq(decoded.name_sec, output.name_sec)
    assert_true(@validate.validate_module(decoded) is Ok(_))
    assert_true(
      @binary.encode_module(output).unwrap().length() <=
      @binary.encode_module(input).unwrap().length(),
    )
  }
}

///|
test "merge-similar-functions rejected merge preserves cached names" {
  let source = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 42) (func (result i32) i32.const 43))",
  ).with_name_sec(
    @lib.NameSec::new(func_names=Some(msf_names_test_map([(0U, "left")]))),
  )
  let input = @binary.decode_module(@binary.encode_module(source).unwrap()).unwrap()
  let output = merge_similar_functions_run_module_pass(input)
  @debug.assert_eq(output, input)
  @debug.assert_eq(output.raw_name_sec_payload, input.raw_name_sec_payload)
}
