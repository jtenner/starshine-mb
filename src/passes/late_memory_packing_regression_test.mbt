///|
fn lmp_test_passive_payload_bytes(mod_ : @lib.Module) -> Int32 {
  let mut bytes = 0
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) =>
      for data in datas {
        match data {
          @lib.Data(@lib.Passive, payload) => bytes += payload.length()
          _ => ()
        }
      }
    None => ()
  }
  bytes
}

///|
test "O4z packs passive ranges exposed by Directize finish inlining" {
  let payload = "A" + "\\00".repeat(128) + "B"
  let input = pass_test_module_from_wat(
    "(module (type $copy (func (param i32 i32 i32))) " +
    "(memory (export \"memory\") 1) (table 1 funcref) (elem (i32.const 0) $copy) " +
    "(data \"" +
    payload +
    "\") " +
    "(func $copy (type $copy) local.get 0 local.get 1 local.get 2 memory.init 0) " +
    "(func (export \"run\") i32.const 0 i32.const 0 i32.const 130 i32.const 0 call_indirect (type $copy)))",
  )
  ignore(@validate.validate_module(input).unwrap())
  let options = HotPipelineOptions::new(
    optimize_level=4,
    shrink_level=4,
    inlining_always_inline_max_size=64,
  )
  let early = memory_packing_run_module_pass(input)
  assert_eq(lmp_test_passive_payload_bytes(early), 130)
  let output = run_hot_pipeline(input, options, ["optimize"]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let explicit = run_hot_pipeline(output, options, ["memory-packing"]).unwrap()
  assert_eq(lmp_test_passive_payload_bytes(explicit), 2)
  assert_eq(lmp_test_passive_payload_bytes(output), 2)
  assert_true(
    @binary.encode_module(output).unwrap().length() <=
    @binary.encode_module(explicit).unwrap().length(),
  )
}

///|
test "O4z packs passive zero ranges exposed by helper inlining" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (memory (export "memory") 1)
      #|  (data "A\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00B")
      #|  (func $copy (param i32 i32 i32)
      #|    local.get 0 local.get 1 local.get 2 memory.init 0)
      #|  (func (export "run")
      #|    i32.const 0 i32.const 0 i32.const 130 call $copy))
    ),
  )
  // The first packing slot cannot split a segment whose helper's source and
  // length are still dynamic. The caller's constants become usable later.
  let early = memory_packing_run_module_pass(input)
  @debug.assert_eq(lmp_test_passive_payload_bytes(early), 130)
  let options = HotPipelineOptions::new(
    optimize_level=4,
    shrink_level=4,
    inlining_always_inline_max_size=64,
  )
  let optimized = run_hot_pipeline(input, options, ["optimize"]).unwrap()
  let finished = run_hot_pipeline(optimized, options, ["memory-packing"]).unwrap()
  assert_true(@validate.validate_module(optimized).is_ok())
  assert_true(@validate.validate_module(finished).is_ok())
  @debug.assert_eq(lmp_test_passive_payload_bytes(finished), 2)
  @debug.assert_eq(lmp_test_passive_payload_bytes(optimized), 2)
  let optimized_bytes = @binary.encode_module(optimized).unwrap()
  let finished_bytes = @binary.encode_module(finished).unwrap()
  assert_true(
    optimized_bytes.length() <= finished_bytes.length(),
    msg="full preset retains bytes removed by late passive segment packing",
  )
}

///|
test "O4z packs newly constant passive edge ranges below the interior threshold" {
  let options = HotPipelineOptions::new(
    optimize_level=4,
    shrink_level=4,
    inlining_always_inline_max_size=64,
  )
  for zero_count in [21] {
    let zeros = "\\00".repeat(zero_count)
    for leading in [true, false] {
      let payload = if leading { "\{zeros}A" } else { "A\{zeros}" }
      let length = zero_count + 1
      let input = pass_test_module_from_wat(
        "(module (memory (export \"memory\") 1) (data \"\{payload}\") (func $copy (param i32 i32 i32) local.get 0 local.get 1 local.get 2 memory.init 0) (func (export \"run\") i32.const 0 i32.const 0 i32.const \{length} call $copy))",
      )
      // Dynamic helper operands block the first packing slot. A single
      // memory.init has a nine-byte edge threshold, versus 21 internally.
      // Twenty-one edge bytes also produce a strict encoded-size reduction;
      // ten edge bytes do not satisfy this fixture's size control.
      let early = memory_packing_run_module_pass(input)
      @debug.assert_eq(lmp_test_passive_payload_bytes(early), length)
      let inlined = run_hot_pipeline(input, options, ["inlining-optimizing"]).unwrap()
      let late_control = run_hot_pipeline(inlined, options, ["memory-packing"]).unwrap()
      assert_true(@validate.validate_module(late_control).is_ok())
      @debug.assert_eq(lmp_test_passive_payload_bytes(late_control), 1)
      assert_true(
        @binary.encode_module(late_control).unwrap().length() <
        @binary.encode_module(inlined).unwrap().length(),
        msg="explicit packing must improve the \{zero_count}-byte edge fixture".view(),
      )
      let optimized = run_hot_pipeline(input, options, ["optimize"]).unwrap()
      assert_true(@validate.validate_module(optimized).is_ok())
      @debug.assert_eq(lmp_test_passive_payload_bytes(optimized), 1)
      let finished = run_hot_pipeline(optimized, options, ["memory-packing"]).unwrap()
      assert_true(
        @binary.encode_module(optimized).unwrap().length() <=
        @binary.encode_module(finished).unwrap().length(),
        msg="full preset retains profitable passive edge bytes",
      )
    }
  }
}

///|
test "O4z removes newly constant small all-zero passive payloads" {
  let options = HotPipelineOptions::new(
    optimize_level=4,
    shrink_level=4,
    inlining_always_inline_max_size=64,
  )
  for length in [2, 8] {
    let zeros = "\\00".repeat(length)
    let input = pass_test_module_from_wat(
      "(module (memory (export \"memory\") 1) (data \"\{zeros}\") (func $copy (param i32 i32 i32) local.get 0 local.get 1 local.get 2 memory.init 0) (func (export \"run\") i32.const 0 i32.const 0 i32.const \{length} call $copy))",
    )
    // One all-zero range needs no retained segment. Its dynamic helper still
    // blocks packing until the callsite constants replace its operands.
    let early = memory_packing_run_module_pass(input)
    @debug.assert_eq(lmp_test_passive_payload_bytes(early), length)
    let inlined = run_hot_pipeline(input, options, ["inlining-optimizing"]).unwrap()
    let late_control = run_hot_pipeline(inlined, options, ["memory-packing"]).unwrap()
    assert_true(@validate.validate_module(late_control).is_ok())
    @debug.assert_eq(lmp_test_passive_payload_bytes(late_control), 0)
    assert_true(
      @binary.encode_module(late_control).unwrap().length() <
      @binary.encode_module(inlined).unwrap().length(),
      msg="explicit packing must improve the \{length}-byte all-zero fixture".view(),
    )
    let optimized = run_hot_pipeline(input, options, ["optimize"]).unwrap()
    assert_true(@validate.validate_module(optimized).is_ok())
    @debug.assert_eq(lmp_test_passive_payload_bytes(optimized), 0)
    let finished = run_hot_pipeline(optimized, options, ["memory-packing"]).unwrap()
    assert_true(
      @binary.encode_module(optimized).unwrap().length() <=
      @binary.encode_module(finished).unwrap().length(),
      msg="full preset retains profitable all-zero passive bytes",
    )
  }
}
