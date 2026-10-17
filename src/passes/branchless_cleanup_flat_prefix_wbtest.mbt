///|
fn branchless_cleanup_flat_prefix_fixture(
  trailing : Bool,
  structured : Bool,
) -> @lib.Module {
  let leaves = "local.get 0 call $effect local.get 0 i32.load drop"
  let child = if structured { "loop \{leaves} end" } else { leaves }
  let result = if trailing { "(result i32)" } else { "" }
  let tail = if trailing { "local.get 0" } else { "" }
  pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func $effect (param i32))) (memory 1) (func (export \"run\") (param i32) \{result} block \{child} end \{tail}))",
  )
}

///|
test "branchless cleanup copies proved flat void prefixes without a recursive worker transaction" {
  for trailing in [false, true] {
    let input = branchless_cleanup_flat_prefix_fixture(trailing, false)
    let saved = @binary.encode_module(input).unwrap()
    let func = input.code_sec.unwrap().0[0]
    let @lib.Func(locals, @lib.Expr(body)) = func
    let child = match body[0] {
      @lib.Block(_, @lib.Expr(child)) => child
      _ => fail("expected a leading block")
    }
    let reference = branchless_cleanup_gate_reference(func, input)
    let work = [0]
    let (actual, changed) = pass_lower_cleanup_branchless_blocks(
      func,
      input,
      rewrite_work=Some(work),
    )
    assert_true(changed)
    assert_eq(actual, reference.0)
    let @lib.Func(next_locals, @lib.Expr(next_body)) = actual
    assert_eq(next_locals, locals)
    let expected = child.copy()
    if trailing {
      expected.push(body[1])
    }
    assert_eq(next_body, expected)
    assert_false(physical_equal(next_body, child))
    assert_false(physical_equal(next_body, body))
    let output = input.with_code_sec(@lib.CodeSec::new([actual]))
    @validate.validate_module(output).unwrap()
    assert_true(physical_equal(output.name_sec, input.name_sec))
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(
        input.with_code_sec(@lib.CodeSec::new([reference.0])),
      ).unwrap(),
    )
    // A caller can extend the output without changing the input child array.
    next_body.push(@lib.Instruction::nop())
    assert_eq(child.length(), 5)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_eq(work[0], 0)
  }
}

///|
test "branchless cleanup retains recursive output ownership for a structured child" {
  let input = branchless_cleanup_flat_prefix_fixture(true, true)
  let saved = @binary.encode_module(input).unwrap()
  let func = input.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(body)) = func
  let child = match body[0] {
    @lib.Block(_, @lib.Expr(child)) => child
    _ => fail("expected a leading block")
  }
  let original_loop = match child[0] {
    @lib.Loop(_, @lib.Expr(original_loop)) => original_loop
    _ => fail("expected a loop child")
  }
  let work = [0]
  let (actual, changed) = pass_lower_cleanup_branchless_blocks(
    func,
    input,
    rewrite_work=Some(work),
  )
  assert_true(changed)
  assert_eq(actual, branchless_cleanup_gate_reference(func, input).0)
  let output = input.with_code_sec(@lib.CodeSec::new([actual]))
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(next_body)) = actual
  let next_loop = match next_body[0] {
    @lib.Loop(_, @lib.Expr(next_loop)) => next_loop
    _ => fail("expected an output loop child")
  }
  assert_false(physical_equal(next_loop, original_loop))
  next_loop.push(@lib.Instruction::nop())
  assert_eq(original_loop.length(), 5)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(work[0], 1)
}

///|
test "branchless cleanup keeps branching and structured tails on the existing worker" {
  for structured in [false, true] {
    let tail = if structured { "loop nop end" } else { "return" }
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"effect\" (func $effect (param i32))) (memory 1) (func (export \"run\") (param i32) block local.get 0 call $effect local.get 0 i32.load drop end \{tail}))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let func = input.code_sec.unwrap().0[0]
    let reference = branchless_cleanup_gate_reference(func, input)
    let work = [0]
    let (actual, changed) = pass_lower_cleanup_branchless_blocks(
      func,
      input,
      rewrite_work=Some(work),
    )
    assert_true(changed)
    assert_eq(actual, reference.0)
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([actual]))).unwrap()
    if structured {
      let @lib.Func(_, @lib.Expr(before)) = func
      let original_tail = match before[1] {
        @lib.Loop(_, @lib.Expr(original_tail)) => original_tail
        _ => fail("expected a loop tail")
      }
      let @lib.Func(_, @lib.Expr(after)) = actual
      let next_tail = match after[5] {
        @lib.Loop(_, @lib.Expr(next_tail)) => next_tail
        _ => fail("expected an output loop tail")
      }
      assert_false(physical_equal(next_tail, original_tail))
      next_tail.push(@lib.Instruction::nop())
      assert_eq(original_tail.length(), 1)
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_eq(work[0], 1)
  }
}
