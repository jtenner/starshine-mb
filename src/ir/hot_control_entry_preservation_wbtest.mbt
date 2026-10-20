///|
fn hot_control_entry_preservation_check(
  source : String,
  op : HotOp,
  entry_slot : Int32,
) -> Unit raise {
  let input = @wast.wast_to_binary_module(source).unwrap()
  @validate.validate_module(input).unwrap()
  for captures in [false, true] {
    let func = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(1U),
      hot_module_context_from_module(input),
      capture_stack_locals=captures,
      materialize_multi_values=captures,
    ).unwrap()
    let mut control = -1
    for id in 0..<hot_node_count(func) {
      if hot_node_get(func, id).op == op {
        control = id
      }
    }
    assert_true(control >= 0)
    assert_true(hot_child_count(func, control) > entry_slot)
    let entry = hot_child_get(func, control, entry_slot)
    assert_eq(hot_node_get(func, entry).op, HotOp::Call)
    assert_eq(hot_node_get(func, entry).imm0, 0)
    if op == HotOp::Block {
      assert_eq(hot_node_get(func, control).imm1, 1)
    }
    hot_verify_core(func).unwrap()
    hot_verify_control(func).unwrap()
    let cfg = cfg_build(
      func,
      conservative_exception_entries=false,
      expand_operand_control=true,
    )
    let entry_block = cfg_block_for_node(cfg, entry).unwrap()
    assert_false(
      cfg_successors(cfg, entry_block).any(fn(edge) {
        edge.kind is CfgEdgeKind::ExceptionalEdge
      }),
    )
    let lowered = hot_lower_func(func)
    // Exact instructions put the call before the protected frame and retain
    // the entry producer even when a branch discards its value.
    assert_eq(lowered, input.code_sec.unwrap().0[0])
    let output = input.with_code_sec(@lib.CodeSec::new([lowered]))
    @validate.validate_module(
      @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
    ).unwrap()
  }
}

///|
test "HOT scalar block retains an effectful entry discarded by a branch" {
  hot_control_entry_preservation_check(
    "(module (import \"env\" \"effect\" (func $effect (result i32))) (func (result i32) call $effect block (param i32) (result i32) i32.const 5 br 0 end))",
    HotOp::Block,
    0,
  )
}

///|
test "HOT legacy try evaluates its parameter before installing the catch" {
  hot_control_entry_preservation_check(
    "(module (import \"env\" \"effect\" (func $effect (result i32))) (tag $e) (func (result i32) call $effect (try (param i32) (result i32) (do i32.const 1 i32.add) (catch $e i32.const 7))))",
    HotOp::Try,
    2,
  )
}

///|
test "HOT try table evaluates its parameter before installing the catch" {
  hot_control_entry_preservation_check(
    "(module (import \"env\" \"effect\" (func $effect (result i32))) (tag $e) (func (result i32) block $caught call $effect try_table (param i32) (result i32) (catch $e $caught) i32.const 1 i32.add end return end i32.const 7))",
    HotOp::TryTable,
    2,
  )
}

///|
test "HOT EH entry initializes nondefaultable locals before the protected body" {
  for
    control in [
      "(try (param (ref 0)) (result i32) (do local.get 1 ref.is_null br 0) (catch_all i32.const 7))",
      "try_table (param (ref 0)) (result i32) local.get 1 ref.is_null br 0 end",
    ] {
    let input = @wast.wast_to_binary_module(
      "(module (type (struct (field i32))) (func (param (ref 0)) (result i32) (local (ref 0)) local.get 0 local.tee 1 " +
      control +
      "))",
    ).unwrap()
    match @validate.validate_module(input) {
      Ok(_) => ()
      Err(err) => fail("invalid entry-local input: \{control}: \{err}")
    }
    let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
    let mut control_id = -1
    for id in 0..<hot_node_count(func) {
      if hot_node_op(func, id) == HotOp::Try ||
        hot_node_op(func, id) == HotOp::TryTable {
        control_id = id
      }
    }
    assert_true(control_id >= 0)
    assert_eq(
      hot_node_op(func, hot_child_get(func, control_id, 2)),
      HotOp::LocalTee,
    )
    // The header itself owns the producer; a duplicate standalone anchor is
    // unnecessary and must not determine the scope repair result.
    ignore(
      hot_region_splice(func, HotRegionRef::root(), 0, hot_root_count(func), [
        control_id,
      ]),
    )
    let entry = hot_child_get(func, control_id, 2)
    let body_ref = hot_region_body_ref(func, control_id)
    let body_roots : Array[NodeId] = []
    for slot in 0..<hot_region_root_count(func, body_ref) {
      let root = hot_region_get(func, body_ref, slot)
      if root != entry {
        body_roots.push(root)
      }
    }
    ignore(
      hot_region_splice(
        func,
        body_ref,
        0,
        hot_region_root_count(func, body_ref),
        body_roots,
      ),
    )
    hot_verify_control(func).unwrap()
    assert_false(hot_repair_nondefaultable_local_scopes(func))
    let output = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(func)]))
    match @validate.validate_module(output) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "invalid entry-local output: \{control}: \{err}; \{output.code_sec}",
        )
    }
  }
}

///|
fn hot_entry_preservation_count_calls(
  instrs : Array[@lib.Instruction],
  inside_eh : Bool,
  counts : Array[Int32],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Call(_) => {
        counts[0] += 1
        if inside_eh {
          counts[1] += 1
        }
      }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        hot_entry_preservation_count_calls(body, inside_eh, counts)
      @lib.If(_, yes, no) => {
        hot_entry_preservation_count_calls(yes, inside_eh, counts)
        if no is Some(body) {
          hot_entry_preservation_count_calls(body, inside_eh, counts)
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        hot_entry_preservation_count_calls(body, true, counts)
        for catch_ in catches {
          match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) =>
              hot_entry_preservation_count_calls(body, true, counts)
          }
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        hot_entry_preservation_count_calls(body, true, counts)
      _ => ()
    }
  }
}

///|
test "HOT entry prefixes retain whole and partial tuple producers exactly once" {
  for
    body in [
      "call $pair block (param i32 i64) (result i32 i64) drop drop i32.const 7 i64.const 8 end",
      "call $pair block (param i32 i64) (result i32 i64) i32.const 7 i64.const 8 br 0 end",
      "call $pair (try (param i32 i64) (result i32 i64) (do drop drop i32.const 7 i64.const 8) (catch $e i32.const 7 i64.const 8))",
      "block $caught call $pair try_table (param i32 i64) (result i32 i64) (catch $e $caught) drop drop i32.const 7 i64.const 8 end return end i32.const 7 i64.const 8",
      "call $pair block (param i64) (result i64) i64.const 5 br 0 end", "call $pair (try (param i64) (result i64) (do i64.const 1 i64.add) (catch $e i64.const 7))",
      "call $pair (try (param i32 i64) (result i32 i64) (do i64.const 1 i64.add) (catch $e i32.const 7 i64.const 8))",
      "block $caught call $pair try_table (param i64) (result i64) (catch $e $caught) i64.const 1 i64.add end return end i32.const 7 i64.const 8",
      "block $caught call $pair try_table (param i32 i64) (result i32 i64) (catch $e $caught) i64.const 1 i64.add end return end i32.const 7 i64.const 8",
    ] {
    let input = @wast.wast_to_binary_module(
      "(module (import \"env\" \"pair\" (func $pair (result i32 i64))) (tag $e) (func (result i32 i64) " +
      body +
      "))",
    ).unwrap()
    @validate.validate_module(input).unwrap()
    for captures in [false, true] {
      let func = hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(1U),
        hot_module_context_from_module(input),
        capture_stack_locals=captures,
        materialize_multi_values=captures,
      ).unwrap()
      hot_verify_control(func).unwrap()
      let lowered = hot_lower_func(func)
      let @lib.Func(_, @lib.Expr(instrs)) = lowered
      let counts = [0, 0]
      hot_entry_preservation_count_calls(instrs, false, counts)
      assert_eq(counts, [1, 0])
      @validate.validate_module(
        input.with_code_sec(@lib.CodeSec::new([lowered])),
      ).unwrap()
    }
  }
}

///|
test "HOT lower tracks local hazards in legacy try bodies and catches" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i32) (local i32) (try (do local.get 0 local.set 1) (catch_all local.get 0 local.set 1))))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let counts = [0, 0]
  hot_lower_impl_count_local_gets_in_body(body, counts)
  assert_eq(counts, [2, 0])
  assert_true(
    hot_lower_impl_body_has_later_local_get(body, 0, @lib.LocalIdx::new(0U)),
  )
  assert_true(hot_lower_impl_body_writes_local(body, @lib.LocalIdx::new(1U)))
}

///|
test "HOT scalar block retains cast branch depths to an outer label" {
  for branch in ["br_on_cast", "br_on_cast_fail"] {
    // The text parser has no ordinary br_on_cast opcode. Build that one
    // instruction in an otherwise parsed typed-control fixture.
    let original = @wast.wast_to_binary_module(
      "(module (type $s (struct)) (func (param (ref null any)) (result i32) block $out (result (ref null any)) local.get 0 block (param (ref null any)) (result (ref null any)) nop end end ref.is_null))",
    ).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = original.code_sec.unwrap().0[0]
    let (outer_type, entry, inner_type) = match body[0] {
      @lib.Block(outer_type, @lib.Expr([entry, @lib.Block(inner_type, _)])) =>
        (outer_type, entry, inner_type)
      _ => fail("unexpected typed cast fixture")
    }
    let source = @lib.HeapType::abs(@lib.AbsHeapType::any())
    let target = @lib.HeapType::new(@lib.TypeIdx::new(0U))
    let cast = if branch == "br_on_cast" {
      @lib.Instruction::br_on_cast(
        @lib.LabelIdx::new(1U),
        true,
        source,
        false,
        target,
      )
    } else {
      @lib.Instruction::br_on_cast_fail(
        @lib.LabelIdx::new(1U),
        true,
        source,
        false,
        target,
      )
    }
    let next_body = body.copy()
    next_body[0] = @lib.Instruction::block(
      outer_type,
      @lib.Expr::new([
        entry,
        @lib.Instruction::block(inner_type, @lib.Expr::new([cast])),
      ]),
    )
    let input = original.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(next_body))]),
    )
    match @validate.validate_module(input) {
      Ok(_) => ()
      Err(err) => fail("cast fixture input: \{err}")
    }
    for captures in [false, true] {
      let func = hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(0U),
        hot_module_context_from_module(input),
        capture_stack_locals=captures,
        materialize_multi_values=captures,
      ).unwrap()
      let output = input.with_code_sec(
        @lib.CodeSec::new([hot_lower_func(func)]),
      )
      match @validate.validate_module(output) {
        Ok(_) => ()
        Err(err) =>
          fail("cast fixture output (\{branch}, capture=\{captures}): \{err}")
      }
    }
  }
}

///|
test "HOT scalar frame removal guards all cast and continuation label carriers" {
  let label = @lib.LabelIdx::new(1U)
  let heap = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let ref_type = @lib.RefType::new(true, heap)
  let type_idx = @lib.TypeIdx::new(0U)
  let tag = @lib.TagIdx::new(0U)
  let handlers = [@lib.ResumeHandler::on_label(tag, label)]
  for
    instr in [
      @lib.Instruction::br_on_cast(label, true, heap, false, heap),
      @lib.Instruction::br_on_cast_fail(label, true, heap, false, heap),
      @lib.Instruction::br_on_cast_desc_eq(label, ref_type, ref_type),
      @lib.Instruction::br_on_cast_desc_eq_fail(label, ref_type, ref_type),
      @lib.Instruction::resume_(type_idx, handlers),
      @lib.Instruction::resume_throw(type_idx, tag, handlers),
      @lib.Instruction::resume_throw_ref(type_idx, handlers),
    ] {
    assert_true(hot_lower_impl_has_control_transfer(instr))
  }
}

///|
fn hot_control_entry_resume_input(kind : Int32) -> @lib.Module {
  let original = @wast.wast_to_binary_module(
    "(module (type $s (func)) (type $c (func)) (tag $e) (tag $t) (func (param (ref null $c) (ref null exn)) (result i32) block (result (ref null $c)) i32.const 0 block (param i32) (result (ref null $c)) drop ref.null $c end end drop i32.const 1))",
  ).unwrap()
  let types = original.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let (locals, outer_type, prefix, inner_type, drop_, result) = match
    original.code_sec.unwrap().0[0] {
    @lib.Func(
      locals,
      @lib.Expr(
        [
          @lib.Block(outer_type, @lib.Expr([prefix, @lib.Block(inner_type, _)])),
          drop_,
          result,
        ]
      )
    ) => (locals, outer_type, prefix, inner_type, drop_, result)
    _ => abort("unexpected fixture")
  }
  let handlers = [
    @lib.ResumeHandler::on_label(@lib.TagIdx::new(0U), @lib.LabelIdx::new(1U)),
  ]
  let inner = [@lib.Instruction::drop()]
  if kind == 2 {
    inner.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  }
  inner.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  inner.push(
    match kind {
      0 => @lib.Instruction::resume_(@lib.TypeIdx::new(1U), handlers)
      1 =>
        @lib.Instruction::resume_throw(
          @lib.TypeIdx::new(1U),
          @lib.TagIdx::new(1U),
          handlers,
        )
      _ => @lib.Instruction::resume_throw_ref(@lib.TypeIdx::new(1U), handlers)
    },
  )
  inner.push(
    @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  original
  .with_type_sec(@lib.TypeSec::new(types))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        locals,
        @lib.Expr::new([
          @lib.Instruction::block(
            outer_type,
            @lib.Expr::new([
              prefix,
              @lib.Instruction::block(inner_type, @lib.Expr::new(inner)),
            ]),
          ),
          drop_,
          result,
        ]),
      ),
    ]),
  )
}

///|
fn hot_control_entry_resume_check(kind : Int32) -> Unit raise {
  let input = hot_control_entry_resume_input(kind)
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("input resume kind \{kind}: \{err}")
  }
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let lowered = hot_lower_func(func)
  match
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([lowered]))) {
    Ok(_) => ()
    Err(err) => fail("lowered resume kind \{kind}: \{err}")
  }
}

///|
test "HOT scalar block resume handler retains outer label" {
  hot_control_entry_resume_check(0)
}

///|
test "HOT scalar block resume throw handler retains outer label" {
  hot_control_entry_resume_check(1)
}

///|
test "HOT scalar block resume throw ref handler retains outer label" {
  hot_control_entry_resume_check(2)
}

///|
test "HOT partial tuple entry preserves its producer when an outer branch discards all lanes" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"pair\" (func $pair (result i32 i64))) (func (result i32) block $out (result i32) call $pair block (param i64) i32.const 9 br $out end drop i32.const 7 end))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  for captures in [false, true] {
    let func = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(1U),
      hot_module_context_from_module(input),
      capture_stack_locals=captures,
      materialize_multi_values=captures,
    ).unwrap()
    let lowered = hot_lower_func(func)
    let @lib.Func(_, @lib.Expr(body)) = lowered
    let calls = [0, 0]
    hot_entry_preservation_count_calls(body, false, calls)
    assert_eq(calls, [1, 0])
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
  }
}
