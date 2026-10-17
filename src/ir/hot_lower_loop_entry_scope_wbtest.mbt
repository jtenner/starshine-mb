///|
fn loop_entry_scope_local_reads(
  body : Array[@lib.Instruction],
  local_id : UInt32,
) -> Int32 {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) if raw == local_id => count += 1
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        count += loop_entry_scope_local_reads(child, local_id)
      _ => ()
    }
  }
  count
}

///|
test "lowering preserves a carried loop entry when a transform adds an ordered result scope" {
  let input = @wast.wast_to_binary_module(
    "(module (type $in (func (param i32) (result i32))) (func (export \"run\") (param i32) (result i32) (local i32) local.get 0 loop $again (type $in) i32.const 1 i32.add local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for capture in [false, true] {
    let hot = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      hot_module_context_from_module(input),
      capture_stack_locals=capture,
      materialize_multi_values=true,
    ).unwrap()
    let count = hot_node_count(hot)
    let mut value = -1
    for node in 0..<count {
      if hot_node_exact_instr(hot, node) is Some(@lib.I32Add) {
        value = node
        break
      }
    }
    assert_true(value >= 0)
    // This ordered scope models a call-argument rewrite: its first store
    // consumes the already evaluated loop entry, not a new local.get 0.
    let store = hot_build_local_set(hot, 1, value)
    let read = hot_build_local_get(hot, 1)
    let scope = hot_build_block(
      hot,
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [store, read],
    )
    for node in 0..<count {
      for slot in 0..<hot_child_count(hot, node) {
        if hot_child_get(hot, node, slot) == value {
          hot_child_set(hot, node, slot, scope)
        }
      }
    }
    hot_verify_all_or_abort(hot)
    let lowered = hot_lower_func(hot)
    let output = input.with_code_sec(@lib.CodeSec::new([lowered]))
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = lowered
    assert_eq(loop_entry_scope_local_reads(body, 0U), 2)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
fn loop_entry_scope_boundary_counts(
  body : Array[@lib.Instruction],
  depth : Int32,
  counts : Array[Int32],
) -> Unit raise {
  for instr in body {
    match instr {
      @lib.Block(header, @lib.Expr(child)) => {
        counts[0] += 1
        if header is @lib.TypeIdxBlockType(_) {
          counts[1] += 1
        }
        loop_entry_scope_boundary_counts(child, depth + 1, counts)
      }
      @lib.Loop(_, @lib.Expr(child)) =>
        loop_entry_scope_boundary_counts(child, depth + 1, counts)
      @lib.If(_, yes, no) => {
        loop_entry_scope_boundary_counts(yes, depth + 1, counts)
        if no is Some(child) {
          loop_entry_scope_boundary_counts(child, depth + 1, counts)
        }
      }
      @lib.BrIf(@lib.LabelIdx(label)) => {
        counts[2] += 1
        // Each branch in these fixtures targets the outer source block.
        assert_eq(label.reinterpret_as_int(), depth - 1)
      }
      @lib.TryTable(_, catches, @lib.Expr(child)) => {
        counts[3] += 1
        counts[4] += catches.length()
        loop_entry_scope_boundary_counts(child, depth + 1, counts)
      }
      @lib.Try(_, @lib.Expr(child), catches, _) => {
        counts[3] += 1
        loop_entry_scope_boundary_counts(child, depth + 1, counts)
        for handler in catches {
          counts[4] += 1
          let handler_body = match handler {
            @lib.LegacyCatch(_, @lib.Expr(child)) => child
            @lib.LegacyCatchAll(@lib.Expr(child)) => child
          }
          loop_entry_scope_boundary_counts(handler_body, depth + 1, counts)
        }
      }
      @lib.Throw(_) => counts[5] += 1
      _ => ()
    }
  }
}

///|
fn loop_entry_scope_lower_boundaries(source : String) -> Array[Int32] raise {
  let input = @wast.wast_to_binary_module(source).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let counts = [0, 0, 0, 0, 0, 0]
  for capture in [false, true] {
    let hot = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      hot_module_context_from_module(input),
      capture_stack_locals=capture,
      materialize_multi_values=true,
    ).unwrap()
    let lowered = hot_lower_func(hot)
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = lowered
    let current = [0, 0, 0, 0, 0, 0]
    loop_entry_scope_boundary_counts(body, 0, current)
    if capture {
      assert_eq(current, counts)
    } else {
      for index in 0..<counts.length() {
        counts[index] = current[index]
      }
    }
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  counts
}

///|
test "ordered scope omission preserves used labels and rebases outer forward branches" {
  for
    source in [
      "(module (func (param i32) (result i32) local.get 0 block $out (result i32) i32.const 7 local.get 0 br_if $out drop i32.const 9 end i32.add))",
      "(module (func (param i32) (result i32) local.get 0 block $outer (result i32) i32.const 3 block $inner (result i32) i32.const 7 local.get 0 br_if $outer drop i32.const 9 end i32.add end i32.add))",
    ] {
    let counts = loop_entry_scope_lower_boundaries(source)
    assert_true(counts[0] >= 1)
    assert_eq(counts[2], 1)
  }
}

///|
test "ordered scope omission keeps parameter normalization and tuple result boundaries" {
  for
    (source, blocks, indexed) in [
      (
        "(module (type $in (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 block (type $in) i32.const 1 i32.add end))",
        0, 0,
      ),
      (
        "(module (type $pair (func (result i32 i32))) (func (param i32 i32) (result i32 i32 i32) i32.const 10 block (type $pair) local.get 0 local.get 1 end))",
        1, 1,
      ),
    ] {
    let counts = loop_entry_scope_lower_boundaries(source)
    // The established transparent-parameter path emits the body directly.
    // Dynamic tuple results retain their indexed block header.
    assert_eq(counts[0], blocks)
    assert_eq(counts[1], indexed)
  }
}

///|
test "ordered scope omission preserves exception and catch boundaries" {
  let counts = loop_entry_scope_lower_boundaries(
    "(module (tag $e) (func (param i32) (result i32) local.get 0 block (result i32) i32.const 7 block $handler try_table (catch $e $handler) local.get 0 if throw $e end end end end i32.add))",
  )
  assert_eq(counts[3], 1)
  assert_eq(counts[4], 1)
  assert_eq(counts[5], 1)
}
