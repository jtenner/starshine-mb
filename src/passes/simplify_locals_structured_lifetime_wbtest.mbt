///|
test "structured lifetime guard preserves flat call captures with bounded scans" {
  let body : Array[@lib.Instruction] = []
  for i = 0; i < 128; i = i + 1 {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  }
  let original = body.copy()
  let visits = [0]
  assert_false(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
      visits=Some(visits),
    ),
  )
  assert_eq(body, original)
  assert_true(visits[0] <= 384, msg="flat guard visits: \{visits[0]}")
}

///|
test "structured lifetime guard ignores call captures after the final structured root" {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::nop()]),
    ),
  ]
  for i = 0; i < 128; i = i + 1 {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  }
  let original = body.copy()
  let visits = [0]
  assert_false(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
      visits=Some(visits),
    ),
  )
  assert_eq(body, original)
  assert_true(
    visits[0] <= 520,
    msg="trailing captures guard visits: \{visits[0]}",
  )
}

///|
test "structured lifetime guard retains nested and per-arm conservative behavior" {
  let local_idx = @lib.LocalIdx::new(0U)
  let call = @lib.Instruction::call(@lib.FuncIdx::new(0U))
  let set = @lib.Instruction::local_set(local_idx)
  let get = @lib.Instruction::local_get(local_idx)
  let drop = @lib.Instruction::drop()
  let child = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([get, drop, call, drop]),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime([
      call, set, child,
    ]),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime([
      call,
      set,
      @lib.Instruction::i32_const(@lib.I32(7)),
      set,
      child,
    ]),
  )
  let split = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [get, drop],
    Some([call, drop]),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime([
      call, set, split,
    ]),
  )
  let wrapped = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([split]),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime([
      call, set, wrapped,
    ]),
  )
  let nested = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([call, set, child]),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime([
      nested,
    ]),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime([
      child, call, set,
    ]),
  )
}

///|
test "structured lifetime guard preserves call capture through active dispatchers" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "host" "read" (func $read (result i32)))
      #|  (func (export "run") (result i32) (local i32)
      #|    call $read local.set 0
      #|    block local.get 0 drop call $read drop end
      #|    local.get 0))
    ),
  )
  for pass_name in ["simplify-locals", "precompute-propagate"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.CodeSec(funcs) = output.code_sec.unwrap()
    let @lib.Func(_, @lib.Expr(body)) = funcs[0]
    let flat : Array[@lib.Instruction] = []
    for instr in body {
      match instr {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(child)) =>
          for item in child {
            flat.push(item)
          }
        _ => flat.push(instr)
      }
    }
    assert_eq(flat, [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ])
  }
}
