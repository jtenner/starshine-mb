///|
test "reorder-locals compresses equal-frequency mixed declaration runs" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"f\") (result i32) (local i32 i64 i32 i64 i32 i64) i32.const 11 local.set 0 i64.const 22 local.set 1 i32.const 33 local.set 2 i64.const 44 local.set 3 i32.const 55 local.set 4 i64.const 66 local.set 5 local.get 0 local.get 1 i32.wrap_i64 i32.add local.get 2 i32.add local.get 3 i32.wrap_i64 i32.add local.get 4 i32.add local.get 5 i32.wrap_i64 i32.add))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(
      optimize_level=4,
      shrink_level=1,
      verify_policy=HotPipelineVerifyPolicy::after_each_pass(),
    ),
    ["reorder-locals"],
  ).unwrap()
  let @lib.CodeSec(funcs) = output.code_sec.unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = funcs[0]
  @debug.assert_eq(locals.runs().length(), 2)
  @debug.assert_eq(locals.runs()[0].count(), 3U)
  @debug.assert_eq(locals.runs()[1].count(), 3U)
  @debug.assert_eq(body[3], @lib.Instruction::local_set(@lib.LocalIdx::new(3U)))
  @debug.assert_eq(body[5], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  @debug.assert_eq(@binary.encode_module(input).unwrap().length(), 89)
  @debug.assert_eq(@binary.encode_module(output).unwrap().length(), 81)
  let @lib.CodeSec(original_funcs) = input.code_sec.unwrap()
  let @lib.Func(original_locals, @lib.Expr(original_body)) = original_funcs[0]
  @debug.assert_eq(original_locals.runs().length(), 6)
  @debug.assert_eq(
    original_body[3],
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  )
}

///|
fn rl_grouping_test_index_bytes(instrs : Array[@lib.Instruction]) -> Int {
  let mut total = 0
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw))
      | @lib.LocalSet(@lib.LocalIdx(raw))
      | @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let mut value = raw
        total += 1
        while value >= 128U {
          value = value / 128U
          total += 1
        }
      }
      _ => ()
    }
  }
  total
}

///|
test "reorder-locals equal-frequency grouping preserves index widths and parameters" {
  let params = Array::make(127, @lib.ValType::i32())
  let types : Array[@lib.ValType] = []
  let body : Array[@lib.Instruction] = []
  for index = 0; index < 129; index = index + 1 {
    types.push(
      if index % 2 == 0 {
        @lib.ValType::i32()
      } else {
        @lib.ValType::i64()
      },
    )
    body.push(
      @lib.Instruction::local_get(
        @lib.LocalIdx::new((index + 127).reinterpret_as_uint()),
      ),
    )
    body.push(@lib.Instruction::drop())
  }
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  body.push(@lib.Instruction::drop())
  let original = @lib.Func::new(
    @lib.Locals::from_types(types),
    @lib.Expr::new(body),
  )
  let result = rl_rewrite_func(original, params)
  assert_true(result.changed)
  let @lib.Func(locals, @lib.Expr(rewritten)) = result.func
  @debug.assert_eq(locals.runs().length(), 2)
  @debug.assert_eq(
    rl_grouping_test_index_bytes(body),
    rl_grouping_test_index_bytes(rewritten),
  )
  @debug.assert_eq(result.old_to_new[0], 0)
  @debug.assert_eq(result.old_to_new[126], 126)
  @debug.assert_eq(result.old_to_new[127], 127)
  @debug.assert_eq(result.old_to_new[128], 192)
  @debug.assert_eq(
    body[2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(128U)),
  )
}

///|
test "reorder-locals grouping normalizes abstract reference map keys only" {
  let sugar = @lib.ValType::funcref()
  let explicit = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
  )
  @debug.assert_eq(sugar, explicit)
  let types = [sugar, @lib.ValType::i32(), explicit, @lib.ValType::i32()]
  let body : Array[@lib.Instruction] = []
  for index = 0; index < types.length(); index = index + 1 {
    body.push(
      @lib.Instruction::local_get(
        @lib.LocalIdx::new(index.reinterpret_as_uint()),
      ),
    )
    body.push(@lib.Instruction::drop())
  }
  let original = @lib.Func::new(
    @lib.Locals::from_types(types),
    @lib.Expr::new(body),
  )
  let result = rl_rewrite_func(original, [])
  let @lib.Func(locals, _) = result.func
  @debug.assert_eq(locals.runs().length(), 2)
  let rewritten_types = rl_flatten_locals(locals, types.length())
  for index = 0; index < types.length(); index = index + 1 {
    @debug.assert_eq(rewritten_types[result.old_to_new[index]], types[index])
  }
}

///|
test "reorder-locals equal-size grouping preserves first-use ordering" {
  let types = [@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::i64()]
  let body : Array[@lib.Instruction] = []
  for index in [1, 2, 0] {
    body.push(
      @lib.Instruction::local_get(
        @lib.LocalIdx::new(index.reinterpret_as_uint()),
      ),
    )
    body.push(@lib.Instruction::drop())
  }
  let result = rl_rewrite_func(
    @lib.Func::new(@lib.Locals::from_types(types), @lib.Expr::new(body)),
    [],
  )
  @debug.assert_eq(result.old_to_new, [2, 0, 1])
  let @lib.Func(locals, _) = result.func
  @debug.assert_eq(locals.runs()[0].val_type(), @lib.ValType::i64())
  @debug.assert_eq(locals.runs()[1].val_type(), @lib.ValType::i32())
}

///|
test "reorder-locals grouping preserves concrete reference exact and nullable flags" {
  let target = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let nullable = @lib.ValType::ref_type(@lib.RefType::new(true, target))
  let exact_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, target, exact=true),
  )
  let nonnullable = @lib.ValType::ref_type(@lib.RefType::new(false, target))
  let types = [
    nullable, exact_nullable, nullable, nonnullable, exact_nullable, nonnullable,
  ]
  let params = types.copy()
  let body : Array[@lib.Instruction] = []
  for index = 0; index < types.length(); index = index + 1 {
    body.push(
      @lib.Instruction::local_get(
        @lib.LocalIdx::new(index.reinterpret_as_uint()),
      ),
    )
    body.push(
      @lib.Instruction::local_set(
        @lib.LocalIdx::new((index + types.length()).reinterpret_as_uint()),
      ),
    )
  }
  let result = rl_rewrite_func(
    @lib.Func::new(@lib.Locals::from_types(types), @lib.Expr::new(body)),
    params,
  )
  assert_true(result.changed)
  let @lib.Func(locals, @lib.Expr(rewritten)) = result.func
  @debug.assert_eq(locals.runs().length(), 3)
  let rewritten_types = rl_flatten_locals(locals, types.length())
  for index = 0; index < types.length(); index = index + 1 {
    @debug.assert_eq(result.old_to_new[index], index)
    @debug.assert_eq(
      rewritten_types[result.old_to_new[index + types.length()] - types.length()],
      types[index],
    )
    @debug.assert_eq(rewritten[index * 2], body[index * 2])
  }
}

///|
test "reorder-locals grouping repairs names with imported-function offsets" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"imp\" (func)) (func (export \"f\") (param i32) (result i32) (local i32 i64 i32 i64 i32 i64 f64) i32.const 11 local.set 1 i64.const 22 local.set 2 i32.const 33 local.set 3 i64.const 44 local.set 4 i32.const 55 local.set 5 i64.const 66 local.set 6 local.get 1 local.get 2 i32.wrap_i64 i32.add local.get 3 i32.add local.get 4 i32.wrap_i64 i32.add local.get 5 i32.add local.get 6 i32.wrap_i64 i32.add local.get 0 i32.add))",
  ).with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("parameter")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("first_i32")),
              @lib.NameAssoc::new(2U, @lib.Name::from_string("first_i64")),
              @lib.NameAssoc::new(3U, @lib.Name::from_string("second_i32")),
              @lib.NameAssoc::new(7U, @lib.Name::from_string("unused")),
            ]),
          ),
        ]),
      ),
    ),
  )
  let output = reorder_locals_run_module_pass(input)
  let @lib.IndirectNameMap(entries) = output.name_sec.unwrap().local_names.unwrap()
  let @lib.IndirectNameAssoc(function_index, @lib.NameMap(names)) = entries[0]
  @debug.assert_eq(function_index, 1U)
  @debug.assert_eq(names, [
    @lib.NameAssoc::new(0U, @lib.Name::from_string("parameter")),
    @lib.NameAssoc::new(1U, @lib.Name::from_string("first_i32")),
    @lib.NameAssoc::new(2U, @lib.Name::from_string("second_i32")),
    @lib.NameAssoc::new(4U, @lib.Name::from_string("first_i64")),
  ])
  let @lib.IndirectNameMap(original_entries) = input.name_sec.unwrap().local_names.unwrap()
  let @lib.IndirectNameAssoc(_, @lib.NameMap(original_names)) = original_entries[0]
  @debug.assert_eq(original_names.length(), 5)
  @debug.assert_eq(
    original_names[2],
    @lib.NameAssoc::new(2U, @lib.Name::from_string("first_i64")),
  )
}
