///|
fn h2l_control_owner_parse(text : String) -> @lib.Module raise {
  match @wast.wast_to_binary_module(text, filename="heap-control-owner.wat") {
    Ok(input) => input
    Err(error) => fail("ownership fixture parse error: \{error}")
  }
}

///|
fn h2l_variant_owner_invariant_func(tee : Bool) -> @ir.HotFunc raise {
  let text = if tee {
    "(module (type $S (struct (field i32) (field i32))) " +
    "(func (param $flag i32) (result i32 i32) (local $x (ref null $S)) " +
    "(struct.get $S 0 (local.tee $x (if (result (ref $S)) (local.get $flag) " +
    "(then (struct.new $S (i32.const 10) (i32.const 20))) " +
    "(else (struct.new $S (i32.const 11) (i32.const 21)))))) " +
    "(struct.get $S 1 (local.get $x))))"
  } else {
    "(module (type $S (struct (field i32) (field i32))) " +
    "(func (param $flag i32) (result i32 i32) (local $x (ref null $S)) " +
    "(local.set $x (if (result (ref $S)) (local.get $flag) " +
    "(then (struct.new $S (i32.const 10) (i32.const 20))) " +
    "(else (struct.new $S (i32.const 11) (i32.const 21))))) " +
    "(local.set $x (if (result (ref $S)) (local.get $flag) " +
    "(then (struct.new $S (i32.const 100) (struct.get $S 0 (local.get $x)))) " +
    "(else (struct.new $S (i32.const 100) (struct.get $S 0 (local.get $x)))))) " +
    "(struct.get $S 0 (local.get $x)) (struct.get $S 1 (local.get $x))))"
  }
  let input = h2l_control_owner_parse(text)
  ignore(@validate.validate_module(input).unwrap())
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    heap2local_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  assert_true(heap2local_run(ctx, func).changed)
  let reachable = simplify_locals_build_reachable_nodes(func)
  for node_id in 0..<@ir.hot_node_count(func) {
    if !reachable[node_id] || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_exact_instr(func, node_id) {
      Some(@lib.StructNew(_) | @lib.StructGet(_, _)) =>
        fail("variant must scalarize before owner/span checks")
      _ => ()
    }
  }
  func
}

///|
fn h2l_variant_assert_reachable_control_owners(
  func : @ir.HotFunc,
) -> Unit raise {
  let reachable = simplify_locals_build_reachable_nodes(func)
  for node_id in 0..<@ir.hot_node_count(func) {
    if !reachable[node_id] || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if @ir.hot_node_kind_is_control(func, node_id) {
      assert_eq(
        @ir.hot_label_owner(func, @ir.hot_control_node_label(func, node_id)),
        node_id,
      )
    }
  }
}

///|
fn h2l_variant_assert_unique_live_control_spans(
  func : @ir.HotFunc,
) -> Unit raise {
  // Unreachable builder wrappers are still live. Their body storage must not
  // alias a retained control node's child span, which later passes can mutate.
  let spans : Array[(Int32, Int32)] = []
  for node_id in 0..<@ir.hot_node_count(func) {
    if !@ir.hot_node_is_live(func, node_id) ||
      !@ir.hot_node_kind_is_control(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    if node.child_count == 0 {
      continue
    }
    let span = (node.child_base, node.child_count)
    assert_false(spans.contains(span))
    spans.push(span)
  }
}

///|
test "heap2local variant owner updates retain reachable control owners" {
  h2l_variant_assert_reachable_control_owners(
    h2l_variant_owner_invariant_func(false),
  )
}

///|
test "heap2local variant owner updates retain unique live control child spans" {
  h2l_variant_assert_unique_live_control_spans(
    h2l_variant_owner_invariant_func(false),
  )
}

///|
test "heap2local variant tees retain reachable control owners" {
  h2l_variant_assert_reachable_control_owners(
    h2l_variant_owner_invariant_func(true),
  )
}

///|
test "heap2local variant tees retain unique live control child spans" {
  h2l_variant_assert_unique_live_control_spans(
    h2l_variant_owner_invariant_func(true),
  )
}

///|
fn h2l_direct_control_owner_invariant(text : String) -> Unit raise {
  h2l_direct_control_owner_module_invariant(h2l_control_owner_parse(text))
}

///|
fn h2l_direct_control_owner_module_invariant(input : @lib.Module) -> Unit raise {
  ignore(@validate.validate_module(input).unwrap())
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    heap2local_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  assert_true(heap2local_run(ctx, func).changed)
  h2l_variant_assert_reachable_control_owners(func)
  h2l_variant_assert_unique_live_control_spans(func)
  ignore(@ir.hot_verify_core(func).unwrap())
  let output = input.with_code_sec(
    @lib.CodeSec::new([@ir.hot_lower_func(func)]),
  )
  ignore(@validate.validate_module(output).unwrap())
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  ignore(@validate.validate_module(decoded).unwrap())
}

///|
fn h2l_control_owner_gc_module(
  array : Bool,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          if array {
            @lib.CompType::array(field)
          } else {
            @lib.CompType::struct_([field])
          },
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
test "heap2local direct struct field controls retain their live owner" {
  h2l_direct_control_owner_invariant(
    "(module (type $S (struct (field i32))) (func (result i32) " +
    "(struct.get $S 0 (struct.new $S " +
    "(block $v (result i32) (br $v (i32.const 42)))))))",
  )
}

///|
test "heap2local direct array element controls retain their live owner" {
  h2l_direct_control_owner_module_invariant(
    h2l_control_owner_gc_module(true, [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(42)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
      @lib.Instruction::array_new_fixed(
        @lib.TypeIdx::new(0U),
        @lib.U32::new(1U),
      ),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::array_get(@lib.TypeIdx::new(0U)),
    ]),
  )
}

///|
test "heap2local drop-only owner blocks retain unique control ownership" {
  h2l_direct_control_owner_invariant(
    "(module (type $S (struct (field i32) (field i32))) " +
    "(func (local $x (ref null $S)) " +
    "(local.set $x (struct.new $S (i32.const 10) (i32.const 20))) " +
    "(drop (local.get $x))))",
  )
}

///|
test "heap2local direct ref equality blocks retain unique control ownership" {
  h2l_direct_control_owner_invariant(
    "(module (type $S (struct (field i32) (field i32))) (func (result i32) " +
    "(ref.eq (struct.new $S (i32.const 10) (i32.const 20)) (ref.null eq))))",
  )
}

///|
test "heap2local direct struct ref test blocks retain unique control ownership" {
  h2l_direct_control_owner_module_invariant(
    h2l_control_owner_gc_module(false, [
      @lib.Instruction::i32_const(@lib.I32(10)),
      @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
      @lib.Instruction::ref_test(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
}

///|
test "heap2local direct array ref test blocks retain unique control ownership" {
  h2l_direct_control_owner_module_invariant(
    h2l_control_owner_gc_module(true, [
      @lib.Instruction::i32_const(@lib.I32(10)),
      @lib.Instruction::array_new_fixed(
        @lib.TypeIdx::new(0U),
        @lib.U32::new(1U),
      ),
      @lib.Instruction::ref_test(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
}

///|
test "heap2local direct array bounds trap blocks retain unique control ownership" {
  h2l_direct_control_owner_module_invariant(
    h2l_control_owner_gc_module(true, [
      @lib.Instruction::i32_const(@lib.I32(10)),
      @lib.Instruction::array_new_fixed(
        @lib.TypeIdx::new(0U),
        @lib.U32::new(1U),
      ),
      @lib.Instruction::i32_const(@lib.I32(-1)),
      @lib.Instruction::array_get(@lib.TypeIdx::new(0U)),
    ]),
  )
}

///|
test "heap2local direct descriptor result blocks retain unique control ownership" {
  h2l_direct_control_owner_invariant(
    "(module (rec (type $S (descriptor $D) (struct (field i32))) " +
    "(type $D (describes $S) (struct))) " +
    "(func (drop (ref.get_desc $S " +
    "(struct.new_desc $S (i32.const 7) (struct.new $D))))))",
  )
}

///|
fn h2l_shared_control_donor_invariant(
  array : Bool,
  counter_result~ : Bool = false,
) -> Unit raise {
  let base = h2l_control_owner_parse(
    "(module " +
    (if array {
      "(type $T (array (mut i32))) "
    } else {
      "(type $T (struct (field i32))) "
    }) +
    "(global $effects (mut i32) (i32.const 0)) " +
    "(func (result i32) (i32.const 0)) " +
    "(func $mark (result i32) " +
    "(global.set $effects (i32.add (global.get $effects) (i32.const 1))) " +
    "(i32.const 42)))",
  )
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
  ]
  if array {
    body.append([
      @lib.Instruction::array_new_fixed(
        @lib.TypeIdx::new(0U),
        @lib.U32::new(1U),
      ),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::array_get(@lib.TypeIdx::new(0U)),
    ])
  } else {
    body.append([
      @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
      @lib.Instruction::struct_get(@lib.TypeIdx::new(0U), @lib.U32::new(0U)),
    ])
  }
  let original_code = base.code_sec.unwrap().0.copy()
  original_code[0] = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  if counter_result {
    let @lib.Func(locals, @lib.Expr(mark_body)) = original_code[1]
    let updated = mark_body.copy()
    updated[updated.length() - 1] = @lib.Instruction::global_get(
      @lib.GlobalIdx::new(0U),
    )
    original_code[1] = @lib.Func::new(locals, @lib.Expr::new(updated))
  }
  let input = base.with_code_sec(@lib.CodeSec::new(original_code))
  ignore(@validate.validate_module(input).unwrap())
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let read = @ir.hot_root_get(func, 0)
  let alloc = @ir.hot_child_get(func, read, 0)
  let donor = @ir.hot_child_get(func, alloc, 0)
  // A bare shared control node is not an explicit value capture. This graph
  // emits two executions before Heap2Local; retain that baseline behavior and
  // the borrowed donor's live ownership instead of assuming one execution.
  @ir.hot_root_append(func, @ir.hot_build_drop(func, donor))
  fn mark_calls(instrs : Array[@lib.Instruction]) -> Int32 {
    let mut count = 0
    for instr in instrs {
      match instr {
        @lib.Call(@lib.FuncIdx(1U)) => count += 1
        @lib.Block(_, @lib.Expr(nested)) => count += mark_calls(nested)
        _ => ()
      }
    }
    count
  }
  let before = @ir.hot_lower_func(func)
  let @lib.Func(_, @lib.Expr(before_body)) = before
  let original_mark_calls = mark_calls(before_body)
  assert_eq(original_mark_calls, 2)
  let before_code = input.code_sec.unwrap().0.copy()
  before_code[0] = before
  let before_module = input
    .with_code_sec(@lib.CodeSec::new(before_code))
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("effects"),
          @lib.ExternIdx::global(@lib.GlobalIdx::new(0U)),
        ),
      ]),
    )
  ignore(@validate.validate_module(before_module).unwrap())
  ignore(@binary.encode_module(before_module).unwrap())
  let ctx = HotPassContext::new(
    heap2local_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  assert_true(heap2local_run(ctx, func).changed)
  assert_true(@ir.hot_node_is_live(func, donor))
  h2l_variant_assert_reachable_control_owners(func)
  h2l_variant_assert_unique_live_control_spans(func)
  ignore(@ir.hot_verify_core(func).unwrap())
  let lowered = @ir.hot_lower_func(func)
  let @lib.Func(_, @lib.Expr(lowered_body)) = lowered
  assert_eq(mark_calls(lowered_body), original_mark_calls)
  let code = input.code_sec.unwrap().0.copy()
  code[0] = lowered
  let output = input.with_code_sec(@lib.CodeSec::new(code))
  ignore(@validate.validate_module(output).unwrap())
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  ignore(@validate.validate_module(decoded).unwrap())
  let original_observation = h2l_control_owner_observe(before_module)
  assert_eq(
    original_observation,
    (true, [if counter_result { 1 } else { 42 }], 2),
  )
  assert_eq(h2l_control_owner_observe(decoded), original_observation)
}

///|
test "heap2local direct struct folds retain shared control donors and original effect multiplicity" {
  h2l_shared_control_donor_invariant(false)
}

///|
test "heap2local direct array folds retain shared control donors and original effect multiplicity" {
  h2l_shared_control_donor_invariant(true)
}

///|
test "heap2local shared control forwarding preserves counter-valued result and effect order" {
  for array in [false, true] {
    h2l_shared_control_donor_invariant(array, counter_result=true)
  }
}

///|
test "heap2local intentionally trapping value controls retain result typing and trap position" {
  for array in [false, true] {
    let body = [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
      ),
    ]
    if array {
      body.append([
        @lib.Instruction::array_new_fixed(
          @lib.TypeIdx::new(0U),
          @lib.U32::new(1U),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::array_get(@lib.TypeIdx::new(0U)),
      ])
    } else {
      body.append([
        @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
        @lib.Instruction::struct_get(@lib.TypeIdx::new(0U), @lib.U32::new(0U)),
      ])
    }
    let input = h2l_control_owner_gc_module(array, body)
    ignore(@validate.validate_module(input).unwrap())
    let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
    let read = @ir.hot_root_get(func, 0)
    let alloc = @ir.hot_child_get(func, read, 0)
    let donor = @ir.hot_child_get(func, alloc, 0)
    // A valid result-i32 block keeps one declared result even when its body
    // cannot return. It must not become a zero-result donor in the new helper.
    assert_eq(@ir.hot_type_results(func, @ir.hot_node_type(func, donor)), [
      @lib.ValType::i32(),
    ])
    h2l_direct_control_owner_module_invariant(input)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "heap2local",
    ]).unwrap()
    assert_eq(h2l_control_owner_observe(input), (false, [], 0))
    assert_eq(h2l_control_owner_observe(output), (false, [], 0))
  }
}

///|
priv struct H2LControlOwnerExecutor {
  module_ : @lib.Module
  heap : Array[Array[Int32]]
  mut global_value : Int32
  mut fuel : Int32
}

///|
fn H2LControlOwnerExecutor::new(
  module_ : @lib.Module,
) -> H2LControlOwnerExecutor {
  { module_, heap: [[]], global_value: 0, fuel: 512, }
}

///|
// Only the bounded fixture surface is supported: no parameters, one numeric
// global, and one-field numeric aggregates. Flow is 0 for fallthrough, -1 for
// a trap, or branch depth + 1. Unknown instructions fail the test.
fn h2l_control_owner_execute(
  state : H2LControlOwnerExecutor,
  body : Array[@lib.Instruction],
  locals : Array[Int32],
  stack : Array[Int32],
  call_depth : Int32,
) -> Int32 raise {
  for instr in body {
    state.fuel -= 1
    assert_true(state.fuel > 0 && call_depth < 4)
    match instr {
      @lib.Nop => ()
      @lib.I32Const(@lib.I32(value)) => stack.push(value)
      @lib.LocalGet(@lib.LocalIdx(index)) => stack.push(locals[index.to_int()])
      @lib.LocalSet(@lib.LocalIdx(index)) =>
        locals[index.to_int()] = stack.pop().unwrap()
      @lib.LocalTee(@lib.LocalIdx(index)) =>
        locals[index.to_int()] = stack[stack.length() - 1]
      @lib.GlobalGet(@lib.GlobalIdx(0U)) => stack.push(state.global_value)
      @lib.GlobalSet(@lib.GlobalIdx(0U)) =>
        state.global_value = stack.pop().unwrap()
      @lib.I32Add => {
        let rhs = stack.pop().unwrap()
        stack.push(stack.pop().unwrap() + rhs)
      }
      @lib.Drop => ignore(stack.pop().unwrap())
      @lib.Call(@lib.FuncIdx(index)) => {
        assert_eq(index, 1U)
        let @lib.Func(callee_locals, @lib.Expr(callee_body)) = state.module_.code_sec.unwrap().0[index.to_int()]
        let values : Array[Int32] = []
        let flow = h2l_control_owner_execute(
          state,
          callee_body,
          Array::make(callee_locals.length(), 0),
          values,
          call_depth + 1,
        )
        if flow < 0 {
          return flow
        }
        assert_true(flow <= 1)
        assert_eq(values.length(), 1)
        stack.append(values)
      }
      @lib.Block(bt, @lib.Expr(nested)) => {
        let height = stack.length()
        let flow = h2l_control_owner_execute(
          state, nested, locals, stack, call_depth,
        )
        if flow < 0 {
          return flow
        }
        if flow > 1 {
          return flow - 1
        }
        let results = match bt {
          @lib.VoidBlockType => 0
          @lib.ValTypeBlockType(@lib.NumTypeValType(@lib.I32NumType)) => 1
          _ => fail("unsupported control owner fixture block type")
        }
        let value = if results == 1 { stack.pop().unwrap() } else { 0 }
        assert_true(stack.length() >= height)
        while stack.length() > height {
          ignore(stack.pop().unwrap())
        }
        if results == 1 {
          stack.push(value)
        }
      }
      @lib.Br(@lib.LabelIdx(depth)) => return depth.to_int() + 1
      @lib.StructNew(@lib.TypeIdx(0U)) => {
        state.heap.push([stack.pop().unwrap()])
        stack.push(state.heap.length() - 1)
      }
      @lib.ArrayNewFixed(@lib.TypeIdx(0U), @lib.U32(1U)) => {
        state.heap.push([stack.pop().unwrap()])
        stack.push(state.heap.length() - 1)
      }
      @lib.StructGet(@lib.TypeIdx(0U), @lib.U32(0U)) => {
        let reference = stack.pop().unwrap()
        if reference <= 0 || reference >= state.heap.length() {
          return -1
        }
        stack.push(state.heap[reference][0])
      }
      @lib.ArrayGet(@lib.TypeIdx(0U)) => {
        let index = stack.pop().unwrap()
        let reference = stack.pop().unwrap()
        if reference <= 0 || reference >= state.heap.length() || index != 0 {
          return -1
        }
        stack.push(state.heap[reference][0])
      }
      @lib.Unreachable => return -1
      _ => fail("unexpected control owner fixture instruction: \{instr}")
    }
  }
  0
}

///|
fn h2l_control_owner_observe(
  module_ : @lib.Module,
) -> (Bool, Array[Int32], Int32) raise {
  let state = H2LControlOwnerExecutor::new(module_)
  let @lib.Func(body_locals, @lib.Expr(body)) = module_.code_sec.unwrap().0[0]
  let stack : Array[Int32] = []
  let flow = h2l_control_owner_execute(
    state,
    body,
    Array::make(body_locals.length(), 0),
    stack,
    0,
  )
  assert_true(flow <= 1)
  (flow >= 0, if flow >= 0 { stack } else { [] }, state.global_value)
}
