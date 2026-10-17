///|
fn raw_removed_scalar_result_module(
  body : String,
  locals~ : String = "",
  caller~ : String = "",
) -> @lib.Module {
  let caller = if caller.is_empty() {
    "(func (export \"run\") (param i32 i32) local.get 0 local.get 1 i64.const 9 call $h drop)"
  } else {
    caller
  }
  pass_test_module_from_wat(
    "(module (type $entry (func (param i32))) (import \"e\" \"mark\" (func $mark (param i32))) (import \"e\" \"value\" (func $value (param i32) (result i32))) (memory (export \"memory\") 1) (func $h (param i32 i32 i64) (result i32) \{locals} \{body}) \{caller})",
  )
}

///|
fn raw_removed_scalar_result_compare(
  input : @lib.Module,
  result_removed~ : Bool = true,
  expected_rewrites~ : Int32 = 0,
  effectful_return_payload~ : String? = None,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let raw_writes = []
    let hot_writes = []
    let (raw_bits, admitted) = raw_conditional_boundary_bits(
      input,
      true,
      closed_world~,
      write_demands=Some(raw_writes),
    )
    let (hot_bits, _) = raw_conditional_boundary_bits(
      input,
      false,
      closed_world~,
      write_demands=Some(hot_writes),
    )
    assert_eq(raw_bits, hot_bits)
    assert_eq(raw_writes, hot_writes)
    assert_eq(admitted, input.code_sec.unwrap().0.length())
    let analysis = [0]
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      stack_suffix_rewrite=false,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
    ).unwrap()
    let expected = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(actual),
      @lib.FuncIdx::new(2U),
    ).unwrap()
    assert_true(params.length() < 3)
    assert_true(!params.contains(@lib.ValType::i64()))
    assert_eq(results.is_empty(), result_removed)
    assert_eq(actual.type_sec, expected.type_sec)
    assert_eq(actual.func_sec, expected.func_sec)
    match effectful_return_payload {
      Some(payload) => {
        let direct = pass_test_module_from_wat(
            "(module (import \"e\" \"mark\" (func $mark (param i32))) (import \"e\" \"value\" (func $value (param i32) (result i32))) (memory 1) (func (param i32 i32) local.get 0 if \{payload} drop return end local.get 1 call $mark))",
          ).code_sec.unwrap().0[0]
        let wrapped = pass_test_module_from_wat(
            "(module (import \"e\" \"mark\" (func $mark (param i32))) (import \"e\" \"value\" (func $value (param i32) (result i32))) (memory 1) (func (param i32 i32) local.get 0 if block \{payload} drop return end end local.get 1 call $mark))",
          ).code_sec.unwrap().0[0]
        assert_eq(actual.code_sec.unwrap().0[0], direct)
        assert_eq(expected.code_sec.unwrap().0[0], wrapped)
        // Only this exact branch-free wrapper differs. Actual raw artifacts
        // save three bytes; all 18 v133 canonical/downstream/O2 pairs match.
        // Original/raw/HOT/v133 also match 216 effect/trap/memory observations
        // in removed-scalar-result-census/return-shape-runtime.json.
        expected.code_sec.unwrap().0[0] = direct
      }
      None => ()
    }
    assert_eq(actual.code_sec, expected.code_sec)
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], expected_rewrites)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 raw replay removes unused own scalar fallthrough results after demanded conditional writes" {
  raw_removed_scalar_result_compare(
    raw_removed_scalar_result_module(
      "local.get 0 if local.get 1 local.set 3 else i32.const 7 local.set 3 end local.get 3 call $mark local.get 1",
      locals="(local i32)",
    ),
  )
}

///|
test "DAE2 raw replay removes unused own scalar results after demanded void loop backedges" {
  raw_removed_scalar_result_compare(
    raw_removed_scalar_result_module(
      "local.get 0 if loop $again local.get 1 call $mark local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end end local.get 1",
    ),
  )
}

///|
test "DAE2 raw replay removes unused own scalar results with retained indexed loop entries" {
  raw_removed_scalar_result_compare(
    raw_removed_scalar_result_module(
      "local.get 0 if local.get 1 loop $again (type $entry) local.set 3 local.get 3 call $mark local.get 3 local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again drop end end local.get 1",
      locals="(local i32)",
    ),
  )
}

///|
test "DAE2 raw replay removes unused pure Return payloads without changing later effects" {
  raw_removed_scalar_result_compare(
    raw_removed_scalar_result_module(
      "local.get 0 if local.get 1 i32.const 3 i32.add return end local.get 1 call $mark local.get 1",
    ),
  )
}

///|
test "DAE2 raw replay preserves demanded tee storage before an unused Return payload" {
  raw_removed_scalar_result_compare(
    raw_removed_scalar_result_module(
      "local.get 0 if local.get 1 local.tee 3 local.get 3 call $mark return end local.get 1 call $mark local.get 1",
      locals="(local i32)",
    ),
  )
}

///|
test "DAE2 raw replay retains imported result effects when an own Return payload disappears" {
  raw_removed_scalar_result_compare(
    raw_removed_scalar_result_module(
      "local.get 0 if local.get 1 call $value return end local.get 1 call $mark local.get 1",
    ),
    effectful_return_payload=Some("local.get 1 call $value"),
  )
}

///|
test "DAE2 raw replay retains trapping load and division Return payloads before later effects" {
  for payload in ["local.get 1 i32.load", "local.get 1 i32.const 0 i32.div_s"] {
    raw_removed_scalar_result_compare(
      raw_removed_scalar_result_module(
        "local.get 0 if \{payload} return end local.get 1 call $mark local.get 1",
      ),
      effectful_return_payload=Some(payload),
    )
  }
}

///|
test "DAE2 raw replay removes a trapping fallthrough result held across a demanded void block" {
  raw_removed_scalar_result_compare(
    raw_removed_scalar_result_module(
      "local.get 1 i32.load block local.get 0 call $mark end",
    ),
  )
}

///|
test "DAE2 raw replay removes unused scalar results through a private caller cascade" {
  let input = raw_removed_scalar_result_module(
    "local.get 0 if local.get 1 call $mark end local.get 1",
    caller="(func $middle (param i32 i32 i64) (result i32) local.get 0 local.get 1 local.get 2 call $h) (func (export \"run\") (param i32 i32) local.get 0 local.get 1 i64.const 9 call $middle drop)",
  )
  raw_removed_scalar_result_compare(input)
  let output = dae2_run_module_pass(input, false).unwrap()
  let @lib.FuncType(_, results) = @ir.hot_module_resolve_func_type(
    @ir.hot_module_context_from_module(output),
    @lib.FuncIdx::new(3U),
  ).unwrap()
  assert_eq(results, [])
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
  assert_eq(body.last(), Some(@lib.Instruction::call(@lib.FuncIdx::new(3U))))
}

///|
test "DAE2 raw replay preserves HOT discard shape for unused own memory and table size results" {
  raw_removed_scalar_result_compare(
    raw_removed_scalar_result_module(
      "local.get 0 if local.get 1 call $mark end memory.size",
    ),
  )
  raw_removed_scalar_result_compare(
    pass_test_module_from_wat(
      "(module (import \"e\" \"mark\" (func $mark (param i32))) (import \"e\" \"value\" (func $value (param i32) (result i32))) (table 1 funcref) (func $h (param i32 i32 i64) (result i32) local.get 0 if local.get 1 call $mark end table.size 0) (func (export \"run\") (param i32 i32) local.get 0 local.get 1 i64.const 9 call $h drop))",
    ),
  )
}

///|
test "DAE2 raw replay keeps function label branch result pins as an intentional retained result control" {
  raw_removed_scalar_result_compare(
    raw_removed_scalar_result_module(
      "local.get 1 local.get 0 br_if 0 drop local.get 0 call $mark local.get 1",
    ),
    result_removed=false,
  )
}

///|
test "DAE2 raw replay removes unused plain scalar control headers with own results and parameters" {
  raw_removed_scalar_result_compare(
    raw_removed_scalar_result_module(
      "local.get 0 if (result i32) local.get 1 else i32.const 7 end",
    ),
  )
}
