///|
fn cl_flat_hazard_module(
  body : Array[@lib.Instruction],
  count : Int32,
  param_count : Int32,
) -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(Array::make(param_count, @lib.ValType::i32()), []),
        ),
      ),
    ]),
  )
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("m"),
        @lib.Name::from_string("probe"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::single(
          (count - param_count).to_uint(),
          @lib.ValType::i32(),
        ),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn cl_flat_hazard_body() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
}

///|
fn cl_flat_hazard_check(
  body : Array[@lib.Instruction],
  count : Int32,
  param_count : Int32,
  seed~ : Bool = false,
  ineffective_first_write~ : Bool = false,
  productive~ : Bool = false,
  local_types~ : Array[@lib.ValType]? = None,
) -> (Int32, Int32) raise {
  let types = match local_types {
    Some(types) => types
    None => Array::make(count, @lib.ValType::i32())
  }
  assert_eq(types.length(), count)
  let locals : Array[@lib.ValType] = []
  for local in param_count..<count {
    locals.push(types[local])
  }
  let input = cl_flat_hazard_module(body, count, param_count).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(body)),
    ]),
  )
  @validate.validate_module(input).unwrap()
  let before = @binary.encode_module(input).unwrap()
  let original = input.code_sec.unwrap().0[0]
  let saved_body = body.copy()
  let params = Array::make(param_count, @lib.ValType::i32())
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, count)
  let effective = Array::make(actions.length(), true)
  if ineffective_first_write {
    for index in 0..<actions.length() {
      match actions[index].kind {
        CLActionKind::Set | CLActionKind::Tee => {
          effective[index] = false
          break
        }
        CLActionKind::Get => ()
      }
    }
  }
  let saved_effective = effective.copy()
  let expected = CLBitMatrix::new(count)
  let actual = CLBitMatrix::new(count)
  if seed {
    cl_add_interference(expected, 0, 2)
    cl_add_interference(actual, 0, 2)
  }
  cl_add_source_write_dest_read_interferences_reference(
    body, actions, effective, types, param_count, expected,
  )
  let rows = [0]
  let fallback = [0]
  cl_add_linear_source_write_dest_read_interferences(
    body,
    actions,
    effective,
    types,
    param_count,
    actual,
    candidate_visits=Some(rows),
    fallback_calls=Some(fallback),
  )
  for source in 0..<count {
    for dest in 0..<count {
      assert_eq(
        cl_bit_matrix_get(actual, source, dest),
        cl_bit_matrix_get(expected, source, dest),
      )
    }
  }
  let reference = cl_linear_hazard_reference_rewrite(original, params)
  let rewritten = cl_rewrite_func(original, params)
  assert_eq(rewritten.changed, reference.changed)
  assert_eq(rewritten.func, reference.func)
  let reference_module = input.with_code_sec(
    @lib.CodeSec::new([reference.func]),
  )
  let actual_module = input.with_code_sec(@lib.CodeSec::new([rewritten.func]))
  @validate.validate_module(reference_module).unwrap()
  @validate.validate_module(actual_module).unwrap()
  assert_eq(
    @binary.encode_module(actual_module).unwrap(),
    @binary.encode_module(reference_module).unwrap(),
  )
  let public_output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "coalesce-locals",
  ]).unwrap()
  @validate.validate_module(public_output).unwrap()
  let public_reference = cl_linear_hazard_reference_module(input)
  @validate.validate_module(public_reference).unwrap()
  assert_eq(
    public_output.code_sec.unwrap().0,
    public_reference.code_sec.unwrap().0,
  )
  assert_eq(
    @binary.encode_module(public_output).unwrap(),
    @binary.encode_module(public_reference).unwrap(),
  )
  if productive {
    assert_true(reference.changed)
    let @lib.Func(locals, @lib.Expr(out)) = rewritten.func
    assert_true(locals.length() < count - param_count)
    assert_true(out.contains(@lib.Instruction::call(@lib.FuncIdx::new(0U))))
    assert_true(cl_bit_matrix_get(actual, 0, 1))
  }
  assert_eq(body, saved_body)
  assert_eq(effective, saved_effective)
  assert_true(physical_equal(input.code_sec.unwrap().0[0], original))
  assert_eq(@binary.encode_module(input).unwrap(), before)
  (rows[0], fallback[0])
}

///|
test "coalesce straight-line hazards keep exact productive output and effects before removing destination scans" {
  let (rows, _) = cl_flat_hazard_check(
    cl_flat_hazard_body(),
    6,
    0,
    productive=true,
  )
  assert_eq(rows, 0)
}

///|
test "coalesce straight-line hazard epochs preserve empty, read timing, copy exemptions, multiple writes and resets" {
  let get = @lib.Instruction::local_get(@lib.LocalIdx::new(1U))
  let set = @lib.Instruction::local_set(@lib.LocalIdx::new(0U))
  let value = @lib.Instruction::i32_const(@lib.I32(7))
  let drop_ = @lib.Instruction::drop()
  let cases : Array[Array[@lib.Instruction]] = [
    [],
    [get, drop_],
    [get, drop_, value, set],
    [value, set, get, drop_],
    [get, set, get, drop_],
    [value, set, value, set, get, drop_],
    [get, set, get, set, get, drop_],
    [
      value,
      set,
      value,
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      get,
      drop_,
    ],
    [
      get,
      set,
      value,
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      get,
      drop_,
    ],
    [
      value,
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      drop_,
      get,
      drop_,
    ],
    [value, set, @lib.Instruction::return_(), get, drop_],
    [value, set, @lib.Instruction::br(@lib.LabelIdx::new(0U)), get, drop_],
    [
      value,
      set,
      get,
      drop_,
      value,
      set,
      @lib.Instruction::return_(),
      value,
      set,
      get,
      drop_,
    ],
  ]
  let mut rows = 0
  for body in cases {
    let (visits, _) = cl_flat_hazard_check(body, 4, 0)
    rows += visits
  }
  let mixed : Array[@lib.Instruction] = [
    value,
    set,
    @lib.Instruction::i64_const(@lib.I64(8L)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    drop_,
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    drop_,
  ]
  let (mixed_rows, _) = cl_flat_hazard_check(
    mixed,
    4,
    0,
    local_types=Some([
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ]),
  )
  assert_eq(rows + mixed_rows, 0)
}

///|
test "coalesce straight-line hazards preserve effective-write masks, parameter boundaries and existing edges" {
  let (first, _) = cl_flat_hazard_check(
    cl_flat_hazard_body(),
    6,
    0,
    seed=true,
    ineffective_first_write=true,
  )
  let (second, _) = cl_flat_hazard_check(cl_flat_hazard_body(), 6, 1, seed=true)
  assert_eq(first + second, 0)
}

///|
test "coalesce branch and barrier programs intentionally retain the old conservative hazard worker" {
  let suffix = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let prefix = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ]
  let controls : Array[Array[@lib.Instruction]] = [
    [
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::br_table(
        [@lib.LabelIdx::new(0U)],
        @lib.LabelIdx::new(0U),
      ),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
    ],
    [@lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([]))],
    [@lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([]))],
  ]
  for control in controls {
    let body = prefix.copy()
    body.append(control)
    body.append(suffix)
    let (_, fallback) = cl_flat_hazard_check(body, 4, 0)
    // The old reader index may reject all row candidates. The complete matrix
    // comparison above and actual fallback call establish the retained route.
    assert_eq(fallback, 1)
  }
}
