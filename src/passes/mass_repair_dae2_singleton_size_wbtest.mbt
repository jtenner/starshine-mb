///|
fn mass_repair_dae2_singleton_size_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
  )
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
          @lib.Limits::i32(1U, None),
        ),
        None,
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
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
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(9)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
fn mass_repair_dae2_singleton_size_contract(mod_ : @lib.Module) -> Unit raise {
  let context = @ir.hot_module_context_from_module(mod_)
  let @lib.FuncSec(indices) = mod_.func_sec.unwrap()
  assert_eq(indices.length(), 2)
  for index = 0; index < indices.length(); index = index + 1 {
    assert_eq(
      @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new(index.to_uint()),
      ),
      Some(@lib.FuncType::new([], [])),
    )
  }
  guard indices[0] is @lib.TypeIdx(target) else {
    abort("expected module type index")
  }
  guard indices[1] is @lib.TypeIdx(caller) else {
    abort("expected module type index")
  }
  let identities = dae2_identity_partition(mod_.type_sec.unwrap())
  assert_true(identities[target.to_int()] != identities[caller.to_int()])
}

///|
fn mass_repair_dae2_singleton_size_check(pass_name : String) -> Unit raise {
  let input = mass_repair_dae2_singleton_size_fixture()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input.without_name_sec()).unwrap()
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    [pass_name],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  mass_repair_dae2_singleton_size_contract(output)
  // Names must not hide the cost of an unused identity witness signature.
  // Vacuum retains one nop in the optimizing mode; it must not grow the input.
  let encoded = @binary.encode_module(output.without_name_sec()).unwrap()
  assert_true(
    if pass_name == "dae2" {
      encoded.length() < saved.length()
    } else {
      encoded.length() <= saved.length()
    },
    msg="\{pass_name}: output \{encoded.length()}, input \{saved.length()}, types \{output.type_sec}, code \{output.code_sec}".view(),
  )
  let context = @ir.hot_module_context_from_module(output)
  let @lib.FuncSec(indices) = output.func_sec.unwrap()
  guard indices[0] is @lib.TypeIdx(target) else {
    abort("expected module type index")
  }
  assert_eq(
    context.subtypes[target.to_int()],
    @lib.SubType::new(false, [], @lib.CompType::func([], [])),
  )
  let decoded = @binary.decode_module(encoded).unwrap()
  @validate.validate_module(decoded).unwrap()
  mass_repair_dae2_singleton_size_contract(decoded)
  assert_eq(@binary.encode_module(input.without_name_sec()).unwrap(), saved)
}

///|
test "mass repair dae2 singleton pruning reduces nameless encoded bytes" {
  mass_repair_dae2_singleton_size_check("dae2")
}

///|
test "mass repair dae2 optimizing singleton pruning removes witness without size growth" {
  mass_repair_dae2_singleton_size_check("dae2-optimizing")
}
