///|
priv struct TupleLaneTypesFixture {
  module_ : @lib.Module
  func : HotFunc
  frames : HotLowerLabelFrames
  producer : NodeId
  seed : Array[HotLowerStackValue]
  prefix : Array[Instruction]
}

///|
fn tuple_lane_types_module(
  lane : String,
  covers : Array[String],
  rotated~ : Bool = false,
) -> @lib.Module {
  let mut params = lane + " "
  let mut cover_results = ""
  let mut reads = ""
  for index in 0..<covers.length() {
    params += covers[index] + " "
    cover_results += covers[index] + " "
    reads += "local.get " + (index + 1).to_string() + " "
  }
  let results = if rotated {
    "i32 " + cover_results + lane
  } else {
    "i32 " + lane + " " + cover_results
  }
  let body = if rotated {
    "unreachable"
  } else {
    "block (type $tuple) i32.const 17 local.get 0 end " + reads
  }
  @wast.wast_to_binary_module(
    "(module (type $tuple (func (result i32 " +
    lane +
    "))) " +
    "(func (param " +
    params +
    ") (result " +
    results +
    ") " +
    body +
    "))",
  ).unwrap()
}

///|
fn tuple_lane_types_fixture(
  lane : String,
  covers : Array[String],
) -> TupleLaneTypesFixture raise {
  let module_ = tuple_lane_types_module(lane, covers)
  ignore(@validate.validate_module(module_).unwrap())
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  hot_verify_all(func).unwrap()
  let producer = func.roots.filter(fn(root) {
      hot_node_op(func, root) == HotOp::Block
    })[0]
  let frames = hot_lower_impl_new_label_frames(func)
  let counts = hot_node_use_counts_build(func)
  let stack : Array[HotLowerStackValue] = []
  let prefix : Array[Instruction] = []
  let extras : Array[ValType] = []
  hot_lower_impl_emit_root(
    func,
    producer,
    counts,
    frames,
    -1,
    stack,
    prefix,
    extras,
    HotLowerOptions::new(),
  )
  for index in 0..<covers.length() {
    let cover = func.roots.filter(fn(root) {
        hot_node_op(func, root) == HotOp::LocalGet &&
        hot_node_get(func, root).imm0 == index + 1
      })[0]
    hot_lower_impl_emit_root(
      func,
      cover,
      counts,
      frames,
      -1,
      stack,
      prefix,
      extras,
      HotLowerOptions::new(),
    )
  }
  assert_eq(extras, [])
  assert_eq(stack.length(), 2 + covers.length())
  assert_eq(stack[0].node_id, producer)
  assert_eq(stack[1].node_id, producer)
  { module_, func, frames, producer, seed: stack, prefix, }
}

///|
// The generated rotation uses only typed local moves. Track distinct parameter
// tokens through those actual instructions, without coercing float/ref/SIMD bits.
fn tuple_lane_types_observe(
  body : Array[Instruction],
  params : Int32,
  extra_count : Int32,
) -> Array[Int32] raise {
  let locals = Array::makei(params + extra_count, fn(index) {
    if index < params {
      101 + index
    } else {
      -1
    }
  })
  let values : Array[Int32] = []
  fn execute(items : Array[Instruction]) -> Unit raise {
    for instr in items {
      match instr {
        Instruction::I32Const(@lib.I32(value)) => values.push(value)
        Instruction::LocalGet(@lib.LocalIdx(index)) =>
          values.push(locals[index.to_int()])
        Instruction::LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = values.pop().unwrap()
        Instruction::Drop => ignore(values.pop().unwrap())
        Instruction::Block(_, @lib.Expr(nested)) => execute(nested)
        _ => fail("unexpected tuple-lane instruction: \{instr}")
      }
    }
  }
  execute(body)
  values
}

///|
fn tuple_lane_types_validate(
  module_ : @lib.Module,
  body : Array[Instruction],
  extras : Array[ValType],
) -> Unit raise {
  let output = module_.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types(extras), @lib.Expr::new(body)),
    ]),
  )
  ignore(@validate.validate_module(output).unwrap())
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  ignore(@validate.validate_module(decoded).unwrap())
}

///|
fn tuple_lane_types_pair_ops(
  lane_local : UInt32,
  cover_local : UInt32,
) -> Array[Instruction] {
  [
    Instruction::local_set(@lib.LocalIdx::new(cover_local)),
    Instruction::local_set(@lib.LocalIdx::new(lane_local)),
    Instruction::local_get(@lib.LocalIdx::new(cover_local)),
    Instruction::local_get(@lib.LocalIdx::new(lane_local)),
  ]
}

///|
test "lower tuple lane rotation preserves all physical numeric SIMD and reference row types" {
  let types = [
    "i32", "i64", "f32", "f64", "v128", "(ref null extern)", "(ref func)",
  ]
  for index in 0..<types.length() {
    let lane = types[index]
    let cover = types[(index + 1) % types.length()]
    let fixture = tuple_lane_types_fixture(lane, [cover])
    let stack = fixture.seed.copy()
    let extras : Array[ValType] = []
    let out = fixture.prefix.copy()
    let start = out.length()
    // A generic full tuple request is intentionally unsupported by this
    // scalar helper. Only the explicit one-lane consumer may rotate it.
    assert_false(
      hot_lower_impl_reuse_buried_scalar(
        fixture.func,
        fixture.producer,
        stack,
        out,
        extras,
        label_frames=Some(fixture.frames),
      ),
    )
    assert_eq(out.length(), start)
    assert_eq(extras, [])
    assert_eq(
      stack.map(fn(row) { (row.node_id, row.val_type) }),
      fixture.seed.map(fn(row) { (row.node_id, row.val_type) }),
    )
    assert_true(
      hot_lower_impl_reuse_buried_scalar(
        fixture.func,
        fixture.producer,
        stack,
        out,
        extras,
        single_tuple_lane=true,
        label_frames=Some(fixture.frames),
      ),
    )
    assert_eq(out[start:].to_owned(), tuple_lane_types_pair_ops(2U, 3U))
    assert_eq(extras, [fixture.seed[1].val_type, fixture.seed[2].val_type])
    assert_eq(
      stack.map(fn(row) { (row.node_id, row.val_type) }),
      [fixture.seed[0], fixture.seed[2], fixture.seed[1]].map(fn(row) {
        (row.node_id, row.val_type)
      }),
    )
    assert_eq(tuple_lane_types_observe(out, 2, extras.length()), [17, 102, 101])
    tuple_lane_types_validate(
      tuple_lane_types_module(lane, [cover], rotated=true),
      out,
      extras,
    )
  }
}

///|
test "lower tuple lane multiple covering rows retain order and exact scratch types" {
  let fixture = tuple_lane_types_fixture("i64", ["f32", "(ref func)", "v128"])
  let stack = fixture.seed.copy()
  let extras : Array[ValType] = []
  let out = fixture.prefix.copy()
  let start = out.length()
  assert_true(
    hot_lower_impl_reuse_buried_scalar(
      fixture.func,
      fixture.producer,
      stack,
      out,
      extras,
      single_tuple_lane=true,
      label_frames=Some(fixture.frames),
    ),
  )
  assert_eq(extras, [
    fixture.seed[4].val_type,
    fixture.seed[3].val_type,
    fixture.seed[2].val_type,
    fixture.seed[1].val_type,
  ])
  assert_eq(out[start:].to_owned(), [
    Instruction::local_set(@lib.LocalIdx::new(4U)),
    Instruction::local_set(@lib.LocalIdx::new(5U)),
    Instruction::local_set(@lib.LocalIdx::new(6U)),
    Instruction::local_set(@lib.LocalIdx::new(7U)),
    Instruction::local_get(@lib.LocalIdx::new(6U)),
    Instruction::local_get(@lib.LocalIdx::new(5U)),
    Instruction::local_get(@lib.LocalIdx::new(4U)),
    Instruction::local_get(@lib.LocalIdx::new(7U)),
  ])
  assert_eq(
    stack.map(fn(row) { (row.node_id, row.val_type) }),
    [
      fixture.seed[0],
      fixture.seed[2],
      fixture.seed[3],
      fixture.seed[4],
      fixture.seed[1],
    ].map(fn(row) { (row.node_id, row.val_type) }),
  )
  assert_eq(tuple_lane_types_observe(out, 4, extras.length()), [
    17, 102, 103, 104, 101,
  ])
  assert_true(fixture.frames.tuple_lane_pairs is None)
  tuple_lane_types_validate(
    tuple_lane_types_module("i64", ["f32", "(ref func)", "v128"], rotated=true),
    out,
    extras,
  )
}

///|
test "lower tuple lane nonoverlapping typed pairs reuse only matching scratch slots" {
  let fixture = tuple_lane_types_fixture("i64", ["f32", "v128"])
  let extras : Array[ValType] = []
  let out : Array[Instruction] = []
  // Each rotation is consumed before another starts. Different cover types
  // need distinct slots, while the first pair can be reused after the second.
  for cover_index in [2, 3, 2, 3] {
    for instr in fixture.prefix[0:fixture.prefix.length() - 2] {
      out.push(instr)
    }
    out.push(
      Instruction::local_get(
        @lib.LocalIdx::new((cover_index - 1).reinterpret_as_uint()),
      ),
    )
    let stack = [fixture.seed[0], fixture.seed[1], fixture.seed[cover_index]]
    let start = out.length()
    assert_true(
      hot_lower_impl_reuse_buried_scalar(
        fixture.func,
        fixture.producer,
        stack,
        out,
        extras,
        single_tuple_lane=true,
        label_frames=Some(fixture.frames),
      ),
    )
    let lane_local = if cover_index == 2 { 3U } else { 5U }
    assert_eq(
      out[start:].to_owned(),
      tuple_lane_types_pair_ops(lane_local, lane_local + 1U),
    )
    assert_eq(tuple_lane_types_observe(out, 3, extras.length()), [
      17,
      100 + cover_index,
      101,
    ])
    for _ in 0..<3 {
      out.push(Instruction::drop())
    }
  }
  assert_eq(extras, [
    fixture.seed[1].val_type,
    fixture.seed[2].val_type,
    fixture.seed[1].val_type,
    fixture.seed[3].val_type,
  ])
  assert_eq(fixture.frames.tuple_lane_pairs.unwrap().pairs.length(), 2)
  for instr in fixture.prefix {
    out.push(instr)
  }
  assert_eq(tuple_lane_types_observe(out, 3, extras.length()), [
    17, 101, 102, 103,
  ])
  tuple_lane_types_validate(fixture.module_, out, extras)
}

///|
test "lower tuple lane scratch pair ownership resets for a different extra locals array" {
  let fixture = tuple_lane_types_fixture("i64", ["f32"])
  let first_extras : Array[ValType] = []
  let first_stack = fixture.seed.copy()
  let first_out = fixture.prefix.copy()
  assert_true(
    hot_lower_impl_reuse_buried_scalar(
      fixture.func,
      fixture.producer,
      first_stack,
      first_out,
      first_extras,
      single_tuple_lane=true,
      label_frames=Some(fixture.frames),
    ),
  )
  assert_eq(first_extras.length(), 2)
  let next_extras = [@lib.ValType::v128()]
  let next_stack = fixture.seed.copy()
  let next_out = fixture.prefix.copy()
  let start = next_out.length()
  assert_true(
    hot_lower_impl_reuse_buried_scalar(
      fixture.func,
      fixture.producer,
      next_stack,
      next_out,
      next_extras,
      single_tuple_lane=true,
      label_frames=Some(fixture.frames),
    ),
  )
  assert_eq(next_extras, [
    @lib.ValType::v128(),
    fixture.seed[1].val_type,
    fixture.seed[2].val_type,
  ])
  assert_eq(next_out[start:].to_owned(), tuple_lane_types_pair_ops(3U, 4U))
  assert_eq(first_extras, [fixture.seed[1].val_type, fixture.seed[2].val_type])
  assert_true(
    physical_equal(
      fixture.frames.tuple_lane_pairs.unwrap().extra_locals,
      next_extras,
    ),
  )
  assert_eq(tuple_lane_types_observe(next_out, 2, next_extras.length()), [
    17, 102, 101,
  ])
  tuple_lane_types_validate(
    tuple_lane_types_module("i64", ["f32"], rotated=true),
    next_out,
    next_extras,
  )
}
