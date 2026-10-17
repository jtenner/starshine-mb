///|
// Staged outside src. Baseline must fail rewrite_lifts before implementation.
fn raw_unused_control_module(
  region : String,
  prefix~ : String = "",
  suffix~ : String = "local.get 0",
) -> @lib.Module {
  pass_test_module_from_wat(
    "(module (import \"e\" \"value\" (func $value (result i32))) (import \"e\" \"mark\" (func $mark (param i32))) (memory (export \"memory\") 1) (global $g (export \"g\") (mut i32) (i32.const 0)) (func $h (param i32 i32) (result i32) local.get 0 global.set $g local.get 0) (func (export \"run\") (param i32 i32) (result i32) (local i32) \{prefix} \{region} drop \{suffix}))",
  )
}

///|
fn raw_unused_control_header_count(body : Array[@lib.Instruction]) -> Int32 {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.Block(bt, @lib.Expr(child)) | @lib.Loop(bt, @lib.Expr(child)) => {
        if bt is @lib.ValTypeBlockType(_) {
          count += 1
        }
        count += raw_unused_control_header_count(child)
      }
      @lib.If(bt, yes, no) => {
        if bt is @lib.ValTypeBlockType(_) {
          count += 1
        }
        count += raw_unused_control_header_count(yes)
        if no is Some(child) {
          count += raw_unused_control_header_count(child)
        }
      }
      _ => ()
    }
  }
  count
}

///|
fn raw_unused_control_compare(
  input : @lib.Module,
  expected_lifts~ : Int32 = 0,
  shrink~ : Bool = true,
) -> @lib.Module raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(source)) = input.code_sec.unwrap().0[1]
  assert_true(raw_unused_control_header_count(source) > 0)
  let mut result = input
  for closed_world in [false, true] {
    let raw_writes = []
    let hot_writes = []
    let (raw_bits, _) = raw_conditional_boundary_bits(
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
    @validate.validate_module(expected).unwrap()
    assert_eq(actual.type_sec, expected.type_sec)
    assert_eq(actual.func_sec, expected.func_sec)
    assert_eq(actual.code_sec, expected.code_sec)
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    if shrink {
      let @lib.Func(_, @lib.Expr(body)) = actual.code_sec.unwrap().0[1]
      assert_eq(raw_unused_control_header_count(body), 0)
    }
    // These counters follow the actual output and demand checks.
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], expected_lifts)
    result = actual
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  result
}

///|
test "DAE2 raw replay removes simple unused block if and loop scalar headers" {
  for
    region in [
      "block (result i32) local.get 0 local.get 1 call $h end", "local.get 0 if (result i32) local.get 0 local.get 1 call $h else local.get 1 local.get 0 call $h end",
      "loop (result i32) local.get 0 local.get 1 call $h end",
    ] {
    ignore(raw_unused_control_compare(raw_unused_control_module(region)))
  }
}

///|
test "DAE2 raw shrinking scalar controls with held prefixes intentionally keep exact HOT fallback" {
  for
    producer in [
      "local.get 1 i32.load", "local.get 1 i32.const 0 i32.div_s", "call $value",
    ] {
    let region = "local.get 0 if (result i32) local.get 0 local.get 1 call $h drop \{producer} local.tee 2 else local.get 1 local.get 0 call $h drop \{producer} local.tee 2 end"
    // The smaller raw body lost downstream cleanup size; retain exact HOT.
    ignore(
      raw_unused_control_compare(
        raw_unused_control_module(
          region,
          prefix="local.get 1 i32.load",
          suffix="local.get 2 i32.add",
        ),
        expected_lifts=1,
      ),
    )
  }
}

///|
test "DAE2 targeted scalar loop result intentionally keeps HOT header and fallback" {
  // HOT observes every ordinary target owner, even a loop with no entry params.
  // Keep exact existing output until a smaller alternative has measured proof.
  ignore(
    raw_unused_control_compare(
      raw_unused_control_module(
        "loop $again (result i32) local.get 0 local.get 1 call $h local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end",
      ),
      expected_lifts=1,
      shrink=false,
    ),
  )
}

///|
fn raw_unused_control_select_types(
  body : Array[@lib.Instruction],
) -> Array[@lib.ValType]? {
  for instr in body {
    match instr {
      @lib.Select(Some(types)) => return Some(types)
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        match raw_unused_control_select_types(child) {
          Some(types) => return Some(types)
          None => ()
        }
      @lib.If(_, yes, no) => {
        match raw_unused_control_select_types(yes) {
          Some(types) => return Some(types)
          None => ()
        }
        if no is Some(child) {
          match raw_unused_control_select_types(child) {
            Some(types) => return Some(types)
            None => ()
          }
        }
      }
      _ => ()
    }
  }
  None
}

///|
test "DAE2 raw unused scalar control output owns retained typed select arrays" {
  let input = raw_unused_control_module(
    "local.get 0 if (result i32) i32.const 3 i32.const 4 local.get 0 select (result i32) call $mark local.get 0 local.get 1 call $h else local.get 1 local.get 0 call $h end",
  )
  let saved = @binary.encode_module(input).unwrap()
  let actual = raw_unused_control_compare(input)
  let @lib.Func(_, @lib.Expr(body)) = actual.code_sec.unwrap().0[1]
  let types = raw_unused_control_select_types(body).unwrap()
  types[0] = @lib.ValType::i64()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 raw unused scalar label payload branches intentionally keep HOT fallback" {
  for
    region in [
      "block $out (result i32) local.get 0 local.get 1 call $h br $out end", "block $out (result i32) local.get 0 local.get 1 call $h local.get 0 br_if $out end",
      "block $out (result i32) local.get 0 local.get 1 call $h local.get 0 br_table $out end",
      "local.get 0 if $out (result i32) local.get 0 local.get 1 call $h br $out else local.get 1 local.get 0 call $h end",
    ] {
    ignore(
      raw_unused_control_compare(
        raw_unused_control_module(region),
        expected_lifts=1,
        shrink=false,
      ),
    )
  }
}

///|
test "DAE2 raw dead inner result with a demanded outer payload intentionally keeps HOT fallback" {
  let input = raw_unused_control_module(
    "block $outer (result i32) block (result i32) local.get 0 local.get 1 call $h local.get 0 br_if $outer end drop i32.const 8 end local.tee 2 global.set $g i32.const 0",
    suffix="local.get 2",
  )
  ignore(raw_unused_control_compare(input, expected_lifts=1, shrink=false))
}

///|
test "DAE2 raw nonfallthrough scalar headers intentionally keep HOT polymorphic results" {
  for
    body in [
      "block (result i32) local.get 0 return end", "local.get 0 if (result i32) local.get 1 return else local.get 2 return end",
      "block $out (result i32) local.get 0 if (result i32) unreachable else local.get 1 br $out end end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    for closed_world in [false, true] {
      let rewrite = [0]
      let actual = match
        dae2_run_module_pass(
          input,
          closed_world,
          stack_suffix_rewrite=false,
          rewrite_lifts=Some(rewrite),
        ) {
        Ok(output) => output
        Err(error) => fail("nonfallthrough scalar replay failed: \{error}")
      }
      let expected = dae2_run_module_pass(
        input,
        closed_world,
        raw_analysis=false,
        raw_rewrite=false,
      ).unwrap()
      @validate.validate_module(actual).unwrap()
      assert_eq(
        @binary.encode_module(actual).unwrap(),
        @binary.encode_module(expected).unwrap(),
      )
      assert_true(dae_wb_param_count(actual, 0) < dae_wb_param_count(input, 0))
      assert_eq(@binary.encode_module(input).unwrap(), saved)
      // An internal return/trap does not make an enclosing Void header
      // polymorphic. Keep the old lowering path for these result contexts.
      assert_true(rewrite[0] > 0)
    }
  }
}
