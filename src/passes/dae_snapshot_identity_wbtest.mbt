///|
test "dae unchanged snapshot keeps body epochs even with NaN constants" {
  let base = pass_test_module_from_wat(
    "(module (func (result f32) f32.const 0))",
  )
  let nan_module = fn(bits : UInt) {
    base.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::f32_const(
              @lib.F32(Float::reinterpret_from_uint(bits)),
            ),
          ]),
        ),
      ]),
    )
  }
  let original = nan_module(0x7fc00001U)
  let graph = dae_current_boundary_graph_new(original)
  let before = graph.function_epochs[0].body_epoch
  dae_current_boundary_graph_refresh(graph, original)
  assert_eq(graph.function_epochs[0].body_epoch, before)
  assert_true(dae_snapshot_module_unchanged(original, original))
  let changed = nan_module(0x7fc00002U)
  assert_false(dae_snapshot_module_unchanged(original, changed))
  dae_current_boundary_graph_refresh(graph, changed)
  assert_eq(graph.function_epochs[0].body_epoch, before + 1)
}

///|
test "dae snapshot identity falls back to structural comparison for distinct bodies" {
  let first = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 block (result i32) i32.const 7 end i32.add))",
  )
  let copy = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 block (result i32) i32.const 7 end i32.add))",
  )
  let changed = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 block (result i32) i32.const 8 end i32.add))",
  )
  assert_true(dae_snapshot_module_unchanged(first, copy))
  assert_false(dae_snapshot_module_unchanged(first, changed))
  assert_true(
    dae_snapshot_func_unchanged(
      first.code_sec.unwrap().0[0],
      copy.code_sec.unwrap().0[0],
    ),
  )
  assert_false(
    dae_snapshot_func_unchanged(
      first.code_sec.unwrap().0[0],
      changed.code_sec.unwrap().0[0],
    ),
  )
  let graph = dae_current_boundary_graph_new(first)
  let before = graph.function_epochs[0].body_epoch
  dae_current_boundary_graph_refresh(graph, copy)
  assert_eq(graph.function_epochs[0].body_epoch, before)
  dae_current_boundary_graph_refresh(graph, changed)
  assert_eq(graph.function_epochs[0].body_epoch, before + 1)
}

///|
test "dae snapshot function identity still detects changed local declarations" {
  let body = @lib.Expr::new([@lib.Instruction::nop()])
  let first = @lib.Func::new(@lib.Locals::empty(), body)
  let changed = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    body,
  )
  assert_false(dae_snapshot_func_unchanged(first, changed))
  assert_true(dae_snapshot_expr_unchanged(body, body))
}
