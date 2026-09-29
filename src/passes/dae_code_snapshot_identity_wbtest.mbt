///|
test "DAE code snapshots retain shared functions containing NaN constants" {
  let original = pass_test_module_from_wat(
    "(module (func (result f32) f32.const nan:0x400001))",
  )
  let graph = dae_current_boundary_graph_new(original)
  let funcs = original.code_sec.unwrap().0
  assert_true(dae_snapshot_funcs_unchanged(funcs, funcs))
  assert_true(dae_snapshot_funcs_unchanged(funcs, funcs.copy()))
  assert_true(dae_scalar_plan_code_snapshot_is_current(original, graph))
  let rewrapped = original.with_code_sec(@lib.CodeSec::new(funcs.copy()))
  assert_true(dae_scalar_plan_code_snapshot_is_current(rewrapped, graph))
  assert_true(dae_snapshot_module_unchanged(original, rewrapped))
  assert_eq(@binary.encode_module(rewrapped), @binary.encode_module(original))
  // The text reader currently canonicalizes these NaN payload spellings.
  // Construct distinct bits directly so the negative case proves a change.
  let changed = original.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f32_const(
            @lib.F32((0x7fc00002 : Int).reinterpret_as_float()),
          ),
        ]),
      ),
    ]),
  )
  assert_true(@binary.encode_module(changed) != @binary.encode_module(original))
  assert_false(dae_snapshot_funcs_unchanged(funcs, changed.code_sec.unwrap().0))
  assert_false(dae_scalar_plan_code_snapshot_is_current(changed, graph))
  let exported = original.with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("f"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
  assert_false(dae_snapshot_module_unchanged(original, exported))
}

///|
test "DAE code snapshot comparison still checks distinct bodies and declarations" {
  let source = pass_test_module_from_wat(
    "(module (func (local i32) i32.const 7 local.set 0))",
  )
  let equal_copy = pass_test_module_from_wat(
    "(module (func (local i32) i32.const 7 local.set 0))",
  )
  let changed_body = pass_test_module_from_wat(
    "(module (func (local i32) i32.const 8 local.set 0))",
  )
  let left = source.code_sec.unwrap().0
  assert_true(
    dae_snapshot_funcs_unchanged(left, equal_copy.code_sec.unwrap().0),
  )
  assert_false(
    dae_snapshot_funcs_unchanged(left, changed_body.code_sec.unwrap().0),
  )
  let @lib.Func(_, body) = left[0]
  let changed_declarations = [@lib.Func::new(@lib.Locals::empty(), body)]
  assert_false(dae_snapshot_funcs_unchanged(left, changed_declarations))
  assert_false(dae_snapshot_funcs_unchanged(left, []))
  let facts = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(),
  )
  let with_facts = source.with_compiler_fact_custom_section(facts)
  assert_false(dae_snapshot_module_unchanged(source, with_facts))
  assert_false(dae_snapshot_module_unchanged(with_facts, source))
}
