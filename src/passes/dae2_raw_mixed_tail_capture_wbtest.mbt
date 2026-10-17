///|
fn dae2_raw_mixed_tail_fixture(
  producer : String,
  body_locals~ : Int32 = 5,
) -> @lib.Module {
  let tail = Array::make(body_locals - 3, "i32").join(" ")
  pass_test_module_from_wat(
    "(module (import \"e\" \"value\" (func $value (result i32))) (import \"e\" \"effect\" (func $effect)) (import \"e\" \"c32\" (func $c32 (param i32))) (import \"e\" \"c64\" (func $c64 (param i64))) (memory (export \"memory\") 1) (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) (local i32 i64 i64 \{tail}) call $value local.set 1 i64.const 7 local.set 2 i64.const 9 local.set 3 \{producer} local.get 0 if call $effect end local.set 4 local.get 1 call $c32 local.get 2 call $c64 local.get 3 call $c64 local.get 4 local.get 0 i32.const 3 i32.add call $h local.get 0 if call $effect end))",
  )
}

///|
test "DAE2 recursive replay keeps trailing i32 held results across controls with mixed prefix locals" {
  for producer in ["call $value", "local.get 0 i32.load"] {
    let input = dae2_raw_mixed_tail_fixture(producer)
    let expected = pass_test_module_from_wat(
        "(module (import \"e\" \"value\" (func $value (result i32))) (import \"e\" \"effect\" (func $effect)) (import \"e\" \"c32\" (func $c32 (param i32))) (import \"e\" \"c64\" (func $c64 (param i64))) (memory 1) (func $h (param i32) (result i32) local.get 0) (func (param i32) (result i32) (local i32 i32 i32 i64 i64) call $value local.set 1 i64.const 7 local.set 4 i64.const 9 local.set 5 \{producer} local.get 0 if call $effect end local.set 2 local.get 1 call $c32 local.get 4 call $c64 local.get 5 call $c64 local.get 2 call $h local.get 0 if call $effect end))",
      ).code_sec.unwrap().0[1]
    raw_structured_held_shape_compare(
      input,
      expected,
      "mixed-tail-i32",
      strict_gain=true,
      export_artifacts=true,
    )
  }
}

///|
test "DAE2 recursive replay groups an interior i64 held result without the former declaration size loss" {
  let input = pass_test_module_from_wat(
    "(module (import \"e\" \"p32\" (func $p32 (result i32))) (import \"e\" \"effect\" (func $effect)) (import \"e\" \"c32\" (func $c32 (param i32))) (import \"e\" \"c64\" (func $c64 (param i64))) (memory (export \"memory\") 1) (global $g (export \"g\") (mut i32) (i32.const 0)) (func $h (param i32 i32) local.get 0 global.set $g) (func (export \"run\") (param i32) (result i32) (local i32 i64 i32) call $p32 local.set 1 i32.const 0 i64.load local.get 0 if call $effect else call $effect end local.set 2 call $p32 local.set 3 local.get 1 call $c32 local.get 2 call $c64 local.get 3 call $c32 local.get 1 call $c32 local.get 2 call $c64 local.get 3 call $c32 local.get 1 i32.const 99 call $h local.get 3))",
  )
  let expected = pass_test_module_from_wat(
      "(module (import \"e\" \"p32\" (func $p32 (result i32))) (import \"e\" \"effect\" (func $effect)) (import \"e\" \"c32\" (func $c32 (param i32))) (import \"e\" \"c64\" (func $c64 (param i64))) (memory 1) (global $g (mut i32) (i32.const 0)) (func $h (param i32) local.get 0 global.set $g) (func (param i32) (result i32) (local i32 i32 i64) call $p32 local.set 1 i32.const 0 i64.load local.get 0 if call $effect else call $effect end local.set 3 call $p32 local.set 2 local.get 1 call $c32 local.get 3 call $c64 local.get 2 call $c32 local.get 1 call $c32 local.get 3 call $c64 local.get 2 call $c32 local.get 1 call $h local.get 2))",
    ).code_sec.unwrap().0[1]
  raw_structured_held_shape_compare(
    input,
    expected,
    "mixed-interior-i64",
    strict_gain=true,
    export_artifacts=true,
  )
}

///|
test "DAE2 recursive mixed control capture intentionally keeps HOT beyond the one byte local index boundary" {
  let tail = Array::make(126, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"e\" \"value\" (func $value (result i32))) (import \"e\" \"effect\" (func $effect)) (import \"e\" \"consume\" (func $consume (param i64))) (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) (local i32 i64 \{tail}) i64.const 7 local.set 2 call $value local.get 0 if call $effect end local.set 3 local.get 2 call $consume local.get 3 i32.const 99 call $h))",
  )
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      stack_suffix_rewrite=false,
      rewrite_lifts=Some(rewrite),
    ).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_true(rewrite[0] > 0)
    assert_eq(actual.code_sec, reference.code_sec)
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 small mixed local grouping composes the original local name map" {
  let original = dae2_raw_mixed_tail_fixture("call $value")
  let names = ["flag", "head", "wide", "wider", "tail", "unused"]
  let input = original.with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            5U,
            @lib.NameMap::new(
              Array::makei(names.length(), fn(index) {
                @lib.NameAssoc::new(
                  index.to_uint(),
                  @lib.Name::from_string(names[index]),
                )
              }),
            ),
          ),
        ]),
      ),
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false, stack_suffix_rewrite=false).unwrap()
  @validate.validate_module(output).unwrap()
  let names = ["flag", "head", "tail", "unused", "wide", "wider"]
  assert_eq(
    output.name_sec.unwrap().local_names,
    Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          5U,
          @lib.NameMap::new(
            Array::makei(names.length(), fn(index) {
              @lib.NameAssoc::new(
                index.to_uint(),
                @lib.Name::from_string(names[index]),
              )
            }),
          ),
        ),
      ]),
    ),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
