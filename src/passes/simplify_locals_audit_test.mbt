///|
test "audit simplify locals preserves dead-result string encoding writes" {
  let array = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::pack_type(@lib.PackType::i8()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [
                @lib.ValType::stringref(),
                @lib.ValType::ref_null(@lib.HeapType::new(array)),
              ],
              [],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_encode_utf8_array(),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let output = audit_run_module(input, "simplify-locals")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.StringEncodeUtf8Array }),
    1,
  )
}

///|
test "audit simplify-locals preserves dead-result i32.div_s trap" {
  let output = audit_run(
    "(module (func (param i32) (local i32) i32.const 1 local.get 0 i32.div_s local.set 1))",
    "simplify-locals",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32DivS }),
    1,
  )
}

///|
test "audit simplify-locals preserves dead-result i32.rem_s trap" {
  let output = audit_run(
    "(module (func (param i32) (local i32) i32.const 1 local.get 0 i32.rem_s local.set 1))",
    "simplify-locals",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32RemS }),
    1,
  )
}

///|
test "audit simplify-locals preserves dead-result i64.div_u trap" {
  let output = audit_run(
    "(module (func (param i64) (local i64) i64.const 1 local.get 0 i64.div_u local.set 1))",
    "simplify-locals",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I64DivU }),
    1,
  )
}

///|
test "audit simplify-locals preserves dead-result i32.trunc_f32_s trap" {
  let output = audit_run(
    "(module (func (param f32) (local i32) local.get 0 i32.trunc_f32_s local.set 1))",
    "simplify-locals",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32TruncF32S }),
    1,
  )
}

///|
test "audit simplify-locals preserves dead-result i64.trunc_f64_u trap" {
  let output = audit_run(
    "(module (func (param f64) (local i64) local.get 0 i64.trunc_f64_u local.set 1))",
    "simplify-locals",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I64TruncF64U }),
    1,
  )
}

///|
test "audit simplify-locals-notee preserves dead-result i32.div_s trap" {
  let output = audit_run(
    "(module (func (param i32) (local i32) i32.const 1 local.get 0 i32.div_s local.set 1))",
    "simplify-locals-notee",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32DivS }),
    1,
  )
}

///|
test "audit simplify-locals-notee preserves dead-result i32.rem_s trap" {
  let output = audit_run(
    "(module (func (param i32) (local i32) i32.const 1 local.get 0 i32.rem_s local.set 1))",
    "simplify-locals-notee",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32RemS }),
    1,
  )
}

///|
test "audit simplify-locals-notee preserves dead-result i64.div_u trap" {
  let output = audit_run(
    "(module (func (param i64) (local i64) i64.const 1 local.get 0 i64.div_u local.set 1))",
    "simplify-locals-notee",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I64DivU }),
    1,
  )
}

///|
test "audit simplify-locals-notee preserves dead-result i32.trunc_f32_s trap" {
  let output = audit_run(
    "(module (func (param f32) (local i32) local.get 0 i32.trunc_f32_s local.set 1))",
    "simplify-locals-notee",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32TruncF32S }),
    1,
  )
}

///|
test "audit simplify-locals-notee preserves dead-result i64.trunc_f64_u trap" {
  let output = audit_run(
    "(module (func (param f64) (local i64) local.get 0 i64.trunc_f64_u local.set 1))",
    "simplify-locals-notee",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I64TruncF64U }),
    1,
  )
}

///|
test "audit simplify-locals-nonesting preserves dead-result i32.div_s trap" {
  let output = audit_run(
    "(module (func (param i32) (local i32) i32.const 1 local.get 0 i32.div_s local.set 1))",
    "simplify-locals-nonesting",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32DivS }),
    1,
  )
}

///|
test "audit simplify-locals-nonesting preserves dead-result i32.rem_s trap" {
  let output = audit_run(
    "(module (func (param i32) (local i32) i32.const 1 local.get 0 i32.rem_s local.set 1))",
    "simplify-locals-nonesting",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32RemS }),
    1,
  )
}

///|
test "audit simplify-locals-nonesting preserves dead-result i64.div_u trap" {
  let output = audit_run(
    "(module (func (param i64) (local i64) i64.const 1 local.get 0 i64.div_u local.set 1))",
    "simplify-locals-nonesting",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I64DivU }),
    1,
  )
}

///|
test "audit simplify-locals-nonesting preserves dead-result i32.trunc_f32_s trap" {
  let output = audit_run(
    "(module (func (param f32) (local i32) local.get 0 i32.trunc_f32_s local.set 1))",
    "simplify-locals-nonesting",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32TruncF32S }),
    1,
  )
}

///|
test "audit simplify-locals-nonesting preserves dead-result i64.trunc_f64_u trap" {
  let output = audit_run(
    "(module (func (param f64) (local i64) local.get 0 i64.trunc_f64_u local.set 1))",
    "simplify-locals-nonesting",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I64TruncF64U }),
    1,
  )
}

///|
test "audit simplify-locals-nostructure preserves dead-result i32.div_s trap" {
  let output = audit_run(
    "(module (func (param i32) (local i32) i32.const 1 local.get 0 i32.div_s local.set 1))",
    "simplify-locals-nostructure",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32DivS }),
    1,
  )
}

///|
test "audit simplify-locals-nostructure preserves dead-result i32.rem_s trap" {
  let output = audit_run(
    "(module (func (param i32) (local i32) i32.const 1 local.get 0 i32.rem_s local.set 1))",
    "simplify-locals-nostructure",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32RemS }),
    1,
  )
}

///|
test "audit simplify-locals-nostructure preserves dead-result i64.div_u trap" {
  let output = audit_run(
    "(module (func (param i64) (local i64) i64.const 1 local.get 0 i64.div_u local.set 1))",
    "simplify-locals-nostructure",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I64DivU }),
    1,
  )
}

///|
test "audit simplify-locals-nostructure preserves dead-result i32.trunc_f32_s trap" {
  let output = audit_run(
    "(module (func (param f32) (local i32) local.get 0 i32.trunc_f32_s local.set 1))",
    "simplify-locals-nostructure",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32TruncF32S }),
    1,
  )
}

///|
test "audit simplify-locals-nostructure preserves dead-result i64.trunc_f64_u trap" {
  let output = audit_run(
    "(module (func (param f64) (local i64) local.get 0 i64.trunc_f64_u local.set 1))",
    "simplify-locals-nostructure",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I64TruncF64U }),
    1,
  )
}

///|
test "audit simplify-locals-notee-nostructure preserves dead-result i32.div_s trap" {
  let output = audit_run(
    "(module (func (param i32) (local i32) i32.const 1 local.get 0 i32.div_s local.set 1))",
    "simplify-locals-notee-nostructure",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32DivS }),
    1,
  )
}

///|
test "audit simplify-locals-notee-nostructure preserves dead-result i32.rem_s trap" {
  let output = audit_run(
    "(module (func (param i32) (local i32) i32.const 1 local.get 0 i32.rem_s local.set 1))",
    "simplify-locals-notee-nostructure",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32RemS }),
    1,
  )
}

///|
test "audit simplify-locals-notee-nostructure preserves dead-result i64.div_u trap" {
  let output = audit_run(
    "(module (func (param i64) (local i64) i64.const 1 local.get 0 i64.div_u local.set 1))",
    "simplify-locals-notee-nostructure",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I64DivU }),
    1,
  )
}

///|
test "audit simplify-locals-notee-nostructure preserves dead-result i32.trunc_f32_s trap" {
  let output = audit_run(
    "(module (func (param f32) (local i32) local.get 0 i32.trunc_f32_s local.set 1))",
    "simplify-locals-notee-nostructure",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I32TruncF32S }),
    1,
  )
}

///|
test "audit simplify-locals-notee-nostructure preserves dead-result i64.trunc_f64_u trap" {
  let output = audit_run(
    "(module (func (param f64) (local i64) local.get 0 i64.trunc_f64_u local.set 1))",
    "simplify-locals-notee-nostructure",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.I64TruncF64U }),
    1,
  )
}

///|
test "simplify locals global storage aliasing across every shared variant" {
  for
    pass in [
      "simplify-locals", "simplify-locals-notee", "simplify-locals-no-tee", "simplify-locals-nonesting",
      "simplify-locals-no-nesting", "simplify-locals-nostructure", "simplify-locals-no-structure",
      "simplify-locals-notee-nostructure",
    ] {
    for
      pair in [
        (
          "(import \"m\" \"a\" (global (mut i32))) (import \"m\" \"b\" (global (mut i32)))",
          1,
        ),
        ("(global (mut i32) (i32.const 1)) (global (mut i32) (i32.const 1))", 0),
        (
          "(import \"m\" \"a\" (global (mut i32))) (global (mut i32) (i32.const 1))",
          0,
        ),
      ] {
      let (globals, expected_sets) = pair
      let sets = if pass == "simplify-locals-nonesting" ||
        pass == "simplify-locals-no-nesting" {
        1
      } else {
        expected_sets
      }
      let output = audit_run(
        "(module " +
        globals +
        " (func (result i32) (local i32) global.get 0 local.set 0 i32.const 7 global.set 1 local.get 0))",
        pass,
      )
      assert_true(
        audit_count(audit_body(output), fn(i) { i is @lib.LocalSet(_) }) == sets,
        msg=pass + globals,
      )
    }
    let output = audit_run(
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1))",
      pass,
    )
    @debug.assert_eq(
      audit_count(audit_body(output), fn(i) { i is @lib.LocalSet(_) }),
      0,
    )
  }
}
