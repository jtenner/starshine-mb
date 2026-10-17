///|
fn dae_table_cmd_fixture(pruned : Bool, with_table : Bool) -> @lib.Module {
  let i32_ = @lib.ValType::i32()
  let run_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([i32_], [i32_])),
  )
  let table_func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let types = if pruned {
    if with_table {
      [table_func_type, run_type]
    } else {
      [run_type]
    }
  } else {
    [
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([i32_, @lib.ValType::i64()], [i32_]),
        ),
      ),
      table_func_type,
      run_type,
    ]
  }
  let helper_type = if pruned { if with_table { 1U } else { 0U } } else { 0U }
  let caller_type = if pruned { helper_type } else { 2U }
  let caller = if pruned {
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ]
  } else {
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i64_const(@lib.I64(9L)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ]
  }
  let module_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(types))
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(helper_type),
        @lib.TypeIdx::new(caller_type),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(caller)),
      ]),
    )
  if with_table {
    let index = if pruned { 0U } else { 1U }
    let ref_ = @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(index)),
    )
    module_.with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(ref_, @lib.Limits::i32(1U, None)),
          Some(@lib.Expr::new([@lib.Instruction::ref_null_type(ref_)])),
        ),
      ]),
    )
  } else {
    module_
  }
}

///|
fn dae_table_cmd_dispatch(
  input : @lib.Module,
  pass : String,
) -> @lib.Module raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let writes : Array[Bytes] = []
  let io = CmdIO::new(
    list_candidates=fn() { ["typed-table.wasm"] },
    file_exists=fn(path) { path == "typed-table.wasm" },
    read_file=fn(_) { Ok(saved) },
    write_file=fn(_, bytes) {
      writes.push(bytes)
      Ok(())
    },
  )
  let result = run_cmd_with_adapter(
    ["--" + pass, "typed-table.wasm", "-o", "out.wasm"],
    io,
  )
  // Check the source even if the old command rejects an invalid prune result.
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(
    result is Ok(_),
    msg=if input.table_sec is Some(_) {
      pass + " must produce valid output for the typed table initializer"
    } else {
      pass + " productive control without a table must succeed"
    },
  )
  let summary = result.unwrap()
  assert_eq(summary.resolved_passes, [pass])
  assert_eq(writes.length(), 1)
  @binary.decode_module(writes[0]).unwrap()
}

///|
fn dae_table_cmd_checked(pass : String) -> Unit raise {
  // Independent productive public control first: same parameter-removal and
  // existing-signature reuse opportunity, without the table initializer.
  let control = dae_table_cmd_fixture(false, false)
  let expected_control = dae_table_cmd_fixture(true, false)
  @validate.validate_module(expected_control).unwrap()
  let optimized_control = dae_table_cmd_dispatch(control, pass)
  @validate.validate_module(optimized_control).unwrap()
  assert_eq(
    @binary.encode_module(optimized_control).unwrap(),
    @binary.encode_module(expected_control).unwrap(),
  )
  let input = dae_table_cmd_fixture(false, true)
  let expected = dae_table_cmd_fixture(true, true)
  @validate.validate_module(input).unwrap()
  @validate.validate_module(expected).unwrap()
  let source = @binary.encode_module(input).unwrap()
  assert_eq(input.type_sec.unwrap().0.length(), 3)
  assert_eq(
    @validate.Env::new()
    .with_module(input)
    .get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
    Some(
      @lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i64()], [
        @lib.ValType::i32(),
      ]),
    ),
  )
  let output = dae_table_cmd_dispatch(input, pass)
  // A valid no-op or fallback is NOT the required behavior: prune the unused
  // helper argument and its now-unused old signature while keeping table use.
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_eq(output.type_sec, expected.type_sec)
  assert_eq(output.func_sec.unwrap().0, [
    @lib.TypeIdx::new(1U),
    @lib.TypeIdx::new(1U),
  ])
  let env = @validate.Env::new().with_module(output)
  for index in [0U, 1U] {
    assert_eq(
      env.get_functype_by_funcidx(@lib.FuncIdx::new(index)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
  }
  let @lib.Func(helper_locals, @lib.Expr(helper)) = output.code_sec.unwrap().0[0]
  let @lib.Func(caller_locals, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(helper_locals.length(), 0)
  assert_eq(caller_locals.length(), 0)
  assert_eq(helper, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
  ])
  assert_eq(caller, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  assert_eq(output.table_sec, expected.table_sec)
  let @lib.Table(table_type, initializer) = output.table_sec.unwrap().0[0]
  let retained_ref = @lib.RefType::new(
    true,
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  assert_eq(
    table_type,
    @lib.TableType::new(retained_ref, @lib.Limits::i32(1U, None)),
  )
  assert_eq(
    initializer,
    Some(@lib.Expr::new([@lib.Instruction::ref_null_type(retained_ref)])),
  )
  assert_eq(output.export_sec, input.export_sec)
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_true(@binary.encode_module(output).unwrap().length() < source.length())
  assert_eq(@binary.encode_module(input).unwrap(), source)
}

///|
test "command dae prunes arguments and remaps typed null table initialization" {
  dae_table_cmd_checked("dae")
}

///|
test "command dae optimizing prunes arguments and remaps typed null table initialization" {
  dae_table_cmd_checked("dae-optimizing")
}
