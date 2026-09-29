///|
test "DAE transaction commits beside unchanged owned NaN global initializers" {
  let input = pass_test_module_from_wat(
    "(module (global (export \"nan\") f32 (f32.const nan)) (func $h (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let local_use = dae_local_use_for_callee(graph.snapshot.funcs[0], 2, 0, 2)
  let plan = dae_build_scalar_unused_param_rewrite_plan(
    input,
    original,
    graph,
    0,
    [true, false],
    local_use,
    1,
    [1],
  ).unwrap()
  let application = dae_apply_rewrite_plan(input, graph, plan)
  assert_true(application.applied)
  let output = application.result.mod_out
  @validate.validate_module(output).unwrap()
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(caller, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  let @lib.Global(_, @lib.Expr(before)) = input.global_sec.unwrap().0[0]
  let @lib.Global(_, @lib.Expr(after)) = output.global_sec.unwrap().0[0]
  assert_true(pass_const_instruction_bits_equal(before[0], after[0]))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE owned section snapshots preserve shared NaNs and still reject changed globals and exports" {
  let source = pass_test_module_from_wat(
    "(module (global f32 (f32.const nan)) (func))",
  )
  let copy = source.with_code_sec(
    @lib.CodeSec::new(source.code_sec.unwrap().0.copy()),
  )
  assert_true(dae_snapshot_module_unchanged(source, copy))
  let changed = pass_test_module_from_wat(
    "(module (global f32 (f32.const 7)) (func))",
  )
  assert_false(dae_snapshot_module_unchanged(source, changed))
  assert_false(
    dae_snapshot_module_unchanged(
      source,
      copy.with_global_sec(@lib.GlobalSec::new([])),
    ),
  )
  let exported = copy.with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("g"),
        @lib.ExternIdx::global(@lib.GlobalIdx::new(0U)),
      ),
    ]),
  )
  assert_false(dae_snapshot_module_unchanged(source, exported))
}
