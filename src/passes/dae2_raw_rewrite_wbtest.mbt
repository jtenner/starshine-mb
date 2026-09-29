///|
test "DAE2 rewrites scalar flat bodies without analysis or mutation HOT arenas" {
  for
    wat in [
      "(module (func $h (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (func $h (param i32 i32) (result i32) local.get 1 i32.const 7 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 11 i32.add call $h))",
      "(module (global $g (mut i32) (i32.const 0)) (func $h (param i32 i32) local.get 1 global.set $g) (func (export \"run\") (param i32) i32.const 9 local.get 0 call $h))",
      "(module (memory 1) (func $h (param i32 i32) (result i32) local.get 1 i32.load) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (type $s (struct (field i32))) (func $h (param i32 i32) (result i32) local.get 1 struct.new $s struct.get $s 0) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (import \"m\" \"value\" (func $v (result i32))) (func $h (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) call $v local.get 0 call $h))",
      "(module (func $h (param i32 i32) (result i32) local.get 1 local.set 0 local.get 0) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (func $h (param i32 i32) (result i32) i32.const 8 i32.const 2 i32.div_s local.get 1 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (func $h (param i32 i32) (result i32) local.get 1 i32.const 3 local.set 1 local.get 1 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (func $h (param i32 i32) (result i32) (local i32) local.get 1 local.set 2 local.get 2 local.set 0 local.get 0) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (func $h (param i32 i32) (result i32) local.get 1 return) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h return))",
      "(module (import \"m\" \"effect\" (func $e (result i32))) (func $h (param i32 i32) (result i32) call $e local.get 1 i32.add) (func (export \"run\") i32.const 9 i32.const 11 call $h drop))",
      "(module (memory 1) (func $h (param i32 i32) (result i32) local.get 1 i32.load) (func (export \"run\") (param i32) i32.const 9 local.get 0 call $h drop))",
      "(module (memory 1) (func $h (param i32 i32) (result i32) memory.size drop local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (table 1 funcref) (func $h (param i32 i32) (result i32) table.size drop local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (memory 1) (func $h (param i32 i32) local.get 1 i32.load drop) (func (export \"run\") (param i32) i32.const 9 local.get 0 call $h))",
      "(module (func $h (param i32 i32) local.get 1 i32.const 0 i32.div_s drop) (func (export \"run\") (param i32) i32.const 9 local.get 0 call $h))",
      "(module (func $h (param i32 i32) i32.const -2147483648 i32.const -1 i32.div_s drop local.get 1 drop) (func (export \"run\") i32.const 9 i32.const 11 call $h))",
      "(module (func $h (param i32 i32) (result i32) i32.const -2147483648 i32.const -1 i32.rem_s drop local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (func $h (param i32 i32) (result i32) i32.const 0 local.get 1 call $h) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
    ] {
    let input = pass_test_module_from_wat(wat)
    let saved = @binary.encode_module(input).unwrap()
    let analysis = [0]
    let rewrite = [0]
    let output = dae2_run_module_pass(
      input,
      false,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
    ).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], 0)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 raw scalar mutation projects tees and retains HOT fallback for tuple and indirect results" {
  for
    wat in [
      "(module (func $h (param i32 i32) (result i32 i32) local.get 1 local.get 1) (func (export \"run\") i32.const 7 i32.const 9 call $h drop drop))",
      "(module (func $h (param i32 i32) (result i32) local.get 1 local.tee 0 local.get 0 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (type $t (func (result i32))) (table 1 funcref) (func $h (param i32 i32) (result i32) local.get 1 call_indirect (type $t)) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
    ] {
    let input = pass_test_module_from_wat(wat)
    let rewrite = [0]
    let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(rewrite)).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    if wat.contains("local.tee") {
      assert_eq(rewrite[0], 0)
    } else {
      assert_true(rewrite[0] > 0)
    }
  }
}

///|
test "DAE2 raw scalar mutation preserves parameter slots beyond word-sized masks" {
  let params = StringBuilder::new()
  let args = StringBuilder::new()
  for i in 0..<130 {
    params.write_string(" i32")
    args.write_string(" i32.const \{i}")
  }
  let input = pass_test_module_from_wat(
    "(module (func $h (param\{params.to_string()}) (result i32) local.get 129) (func (export \"run\") (result i32)\{args.to_string()} call $h))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  assert_eq(lifts[0], 0)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 direct mutation preserves grouped locals and remaps retained local names" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param $dead i32) (param $live i32) (result i32) (local $a i32) (local $b i32) local.get 1 local.set 2 local.get 2 local.set 3 local.get 3) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
  )
  let funcs = input.code_sec.unwrap().0.copy()
  let @lib.Func(_, body) = funcs[0]
  funcs[0] = @lib.Func::new(
    @lib.Locals::from_decl_runs_preserving_groups([
      @lib.LocalRun::new(1U, @lib.ValType::i32()),
      @lib.LocalRun::new(1U, @lib.ValType::i32()),
    ]),
    body,
  )
  let input = input.with_code_sec(@lib.CodeSec::new(funcs))
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  assert_eq(output.name_sec, reference.name_sec)
  assert_eq(lifts[0], 0)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
