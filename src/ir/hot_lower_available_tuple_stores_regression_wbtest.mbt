///|
fn lower_available_tuple_stores_fixture(
  width : Int32,
  interleaved_nops~ : Bool = false,
  fresh_read~ : Bool = false,
) -> @lib.Module {
  let row = "i32 ".repeat(width)
  let mut text = "(module (import \"env\" \"mark\" (func (param i32) (result i32))) " +
    "(type $wide (func (result " +
    row +
    "))) (func (result " +
    row +
    (if fresh_read { "i32 " } else { "" }) +
    ") (local " +
    row +
    ") block (type $wide) "
  for lane in 1..<=width {
    text += "i32.const " + lane.to_string() + " call 0 "
  }
  text += "end "
  for lane = width - 1; lane >= 0; lane = lane - 1 {
    text += "local.set " + lane.to_string() + " "
    if interleaved_nops {
      text += "nop "
    }
  }
  for lane in 0..<width {
    text += "local.get " + lane.to_string() + " "
  }
  if fresh_read {
    text += "local.get 0 "
  }
  @wast.wast_to_binary_module(text + "))").unwrap()
}

///|
test "lower available tuple stores preserve every value and event with bounded ordering work" {
  for width in [32, 48] {
    let input = lower_available_tuple_stores_fixture(width)
    ignore(@validate.validate_module(input).unwrap())
    let func = hot_lift_func(input, @lib.FuncIdx::new(1U))
    let revision = hot_revision_current(func)
    let counts = hot_node_use_counts_build(func)
    let frames = hot_lower_impl_new_label_frames(func)
    let plan = hot_lower_impl_future_dependencies(func, func.roots, frames)
    assert_true(plan.required)
    assert_true(plan.suffix_minima is Some(_))
    let visits = [0]
    let stack : Array[HotLowerStackValue] = []
    let out : Array[Instruction] = []
    let extras : Array[ValType] = []
    for index in 0..<func.roots.length() {
      let root = func.roots[index]
      hot_lower_impl_emit_preceding_future_dependencies(
        func,
        root,
        func.roots,
        index + 1,
        plan,
        counts,
        frames,
        -1,
        stack,
        out,
        extras,
        HotLowerOptions::new(),
        ordering_work=Some(visits),
      )
      hot_lower_impl_emit_root(
        func,
        root,
        counts,
        frames,
        -1,
        stack,
        out,
        extras,
        HotLowerOptions::new(),
      )
    }
    let arguments = Array::makei(width, fn(lane) { lane + 1 })
    assert_eq(
      lower_first_emission_observe(out, width),
      (arguments.map(fn(x) { 2 * x }), arguments),
    )
    assert_eq(extras, [])
    assert_eq(stack.length(), width)
    assert_eq(hot_revision_current(func), revision)
    let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
    ignore(
      @validate.validate_module(
        input.with_code_sec(
          @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(out))]),
        ),
      ).unwrap(),
    )
    assert_true(
      visits[0] <= 6 * width,
      msg="total admission and query work must stay linear for available tuple stores: \{visits[0]}",
    )
  }
}

///|
test "lower tuple store fallback preserves events without repeated stack suffix scans" {
  let width = 32
  let input = lower_available_tuple_stores_fixture(width, interleaved_nops=true)
  ignore(@validate.validate_module(input).unwrap())
  let func = hot_lift_func(input, @lib.FuncIdx::new(1U))
  assert_true(
    func.roots.any(fn(root) { hot_node_op(func, root) == HotOp::Nop }),
  )
  let counts = hot_node_use_counts_build(func)
  let frames = hot_lower_impl_new_label_frames(func)
  let plan = hot_lower_impl_future_dependencies(func, func.roots, frames)
  let facts = frames.source_order.unwrap()
  assert_true(plan.suffix_minima is Some(_))
  let work = [0]
  let stack : Array[HotLowerStackValue] = []
  let out : Array[Instruction] = []
  let extras : Array[ValType] = []
  let mut stores = 0
  for index in 0..<func.roots.length() {
    let root = func.roots[index]
    if hot_node_op(func, root) == HotOp::LocalSet {
      let admitted = hot_lower_impl_available_tuple_store_run(
        func,
        root,
        func.roots,
        index + 1,
        plan.suffix_minima,
        facts,
        stack,
        ordering_work=Some(work),
      )
      // Intervening NOPs intentionally require the general ordering fallback
      // while a later store still demands this producer.
      if stores < width - 1 {
        assert_false(admitted)
      }
      stores += 1
    }
    hot_lower_impl_emit_root(
      func,
      root,
      counts,
      frames,
      -1,
      stack,
      out,
      extras,
      HotLowerOptions::new(),
    )
  }
  assert_eq(stores, width)
  let arguments = Array::makei(width, fn(lane) { lane + 1 })
  assert_eq(
    lower_first_emission_observe(out, width),
    (arguments.map(fn(x) { 2 * x }), arguments),
  )
  assert_eq(extras, [])
  let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
  ignore(
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(out))]),
      ),
    ).unwrap(),
  )
  assert_true(
    work[0] <= 6 * width,
    msg="rejected short runs must not scan the full remaining tuple: \{work[0]}",
  )
}

///|
test "lower tuple store shortcut retains source-order fallback for earlier reads and wrappers" {
  for case in [(false, 0), (false, 15), (false, 31), (true, 0)] {
    let (retained_position, read_local) = case
    let width = 32
    let input = lower_available_tuple_stores_fixture(width, fresh_read=true)
    let func = hot_lift_func(input, @lib.FuncIdx::new(1U))
    let stores = func.roots.filter(fn(root) {
      hot_node_op(func, root) == HotOp::LocalSet
    })
    assert_eq(stores.length(), width)
    let producer = hot_child_get(func, stores[0], 0)
    if retained_position {
      // A rewritten store can retain its old producer's position. This is
      // intentionally outside the strict source-order shortcut proof.
      hot_preserve_replacement_position(func, stores[0], producer)
    } else {
      // Model a retained read from before the stores. The later return must
      // observe the original local zero, rather than the newly stored lane.
      let read = func.roots.filter(fn(root) {
          hot_node_op(func, root) == HotOp::LocalGet &&
          hot_node_get(func, root).imm0 == read_local
        })[0]
      hot_preserve_replacement_position(func, read, producer)
    }
    hot_verify_all(func).unwrap()
    let facts = HotSourceOrderFacts::new(func)
    let index = Some(HotSourceOrderRootIndex::new(func, func.roots, facts))
    let counts = hot_node_use_counts_build(func)
    let frames = hot_lower_impl_new_label_frames(func)
    let stack : Array[HotLowerStackValue] = []
    let out : Array[Instruction] = []
    let extras : Array[ValType] = []
    hot_lower_impl_emit_root(
      func,
      producer,
      counts,
      frames,
      -1,
      stack,
      out,
      extras,
      HotLowerOptions::new(),
    )
    let position = func.roots
      .find_index(fn(root) { root == stores[0] })
      .unwrap()
    assert_false(
      hot_lower_impl_available_tuple_store_run(
        func,
        stores[0],
        func.roots,
        position + 1,
        index,
        facts,
        stack,
      ),
    )
    let lowered = hot_lower_func(func)
    let @lib.Func(locals, @lib.Expr(body)) = lowered
    let expected = Array::makei(width + 1, fn(lane) {
      if lane == width {
        2
      } else if lane == read_local && !retained_position {
        0
      } else {
        2 * (lane + 1)
      }
    })
    assert_eq(
      lower_first_emission_observe(body, locals.length()),
      (expected, Array::makei(width, fn(lane) { lane + 1 })),
    )
    ignore(
      @validate.validate_module(
        input.with_code_sec(@lib.CodeSec::new([lowered])),
      ).unwrap(),
    )
  }
}

///|
test "lower repeated tuple lane moves reuse their immediate temporary pair" {
  let width = 32
  let input = lower_available_tuple_stores_fixture(width)
  let func = hot_lift_func(input, @lib.FuncIdx::new(1U))
  let stores = func.roots.filter(fn(root) {
    hot_node_op(func, root) == HotOp::LocalSet
  })
  let producer = hot_child_get(func, stores[0], 0)
  let reads = func.roots.filter(fn(root) {
    hot_node_op(func, root) == HotOp::LocalGet
  })
  let retained_local = width / 2 - 1
  let retained = reads[retained_local]
  hot_preserve_replacement_position(func, retained, producer)
  let retained_position = func.roots
    .find_index(fn(root) { root == retained })
    .unwrap()
  let first_result = func.roots
    .find_index(fn(root) { root == reads[0] })
    .unwrap()
  ignore(hot_root_remove(func, retained_position))
  hot_root_insert(func, first_result, retained)
  // Return the retained read first, so this fixture measures store movement
  // without a separate wide return-vector rearrangement.
  hot_verify_all(func).unwrap()
  let lowered = hot_lower_func(func)
  let @lib.Func(locals, @lib.Expr(body)) = lowered
  let expected = [0]
  for lane in 0..<width {
    if lane != retained_local {
      expected.push(2 * (lane + 1))
    }
  }
  assert_eq(
    lower_first_emission_observe(body, locals.length()),
    (expected, Array::makei(width, fn(lane) { lane + 1 })),
  )
  ignore(
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap(),
  )
  assert_true(
    locals.length() <= width + 2,
    msg="completed lane moves must not retain new scratch locals per store: \{locals.length() - width}",
  )
}

///|
test "lower tuple stores preserve multiple old reads and call order" {
  for retained_locals in [[7, 15], [0, 15], [15, 31]] {
    let width = 32
    let input = lower_available_tuple_stores_fixture(width)
    let func = hot_lift_func(input, @lib.FuncIdx::new(1U))
    let stores = func.roots.filter(fn(root) {
      hot_node_op(func, root) == HotOp::LocalSet
    })
    let producer = hot_child_get(func, stores[0], 0)
    let reads = func.roots.filter(fn(root) {
      hot_node_op(func, root) == HotOp::LocalGet
    })
    for local_id in retained_locals {
      hot_preserve_replacement_position(func, reads[local_id], producer)
      let position = func.roots
        .find_index(fn(root) { root == reads[local_id] })
        .unwrap()
      ignore(hot_root_remove(func, position))
    }
    let first_result = func.roots.length() - (width - retained_locals.length())
    for index in 0..<retained_locals.length() {
      hot_root_insert(func, first_result + index, reads[retained_locals[index]])
    }
    hot_verify_all(func).unwrap()
    let lowered = hot_lower_func(func)
    let @lib.Func(locals, @lib.Expr(body)) = lowered
    let expected = Array::make(retained_locals.length(), 0)
    for lane in 0..<width {
      if !retained_locals.contains(lane) {
        expected.push(2 * (lane + 1))
      }
    }
    assert_eq(
      lower_first_emission_observe(body, locals.length()),
      (expected, Array::makei(width, fn(lane) { lane + 1 })),
    )
    ignore(
      @validate.validate_module(
        input.with_code_sec(@lib.CodeSec::new([lowered])),
      ).unwrap(),
    )
  }
}
