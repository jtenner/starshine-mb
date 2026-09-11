///|
test "Binaryen 132 precompute variants fold relaxed reads of fresh immutable unshared structs" {
  for pass in ["precompute", "precompute-propagate"] {
    let source =
      #|(module
      #|  (type (struct (field i32)))
      #|  (func (result i32)
      #|    (struct.atomic.get relaxed 0 0
      #|      (struct.new 0 (i32.const 42)))))
    let optimized = match pass_test_run_pipeline(source, [pass]) {
      Ok(value) => value
      Err(err) => fail("expected relaxed read precompute: \{err}")
    }
    let body = match optimized.code_sec {
      Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
      _ => fail("expected one function")
    }
    @debug.assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(42))])
  }
}

///|
test "Binaryen 132 precompute retains intentionally nonconstant mutable relaxed reads" {
  // v132's constant evaluator does not read mutable fields, even when unshared.
  for pass in ["precompute", "precompute-propagate"] {
    let source =
      #|(module
      #|  (type (struct (field (mut i32))))
      #|  (func (result i32)
      #|    (struct.atomic.get relaxed 0 0
      #|      (struct.new 0 (i32.const 42)))))
    let original = pass_test_module_from_wat(source)
    let optimized = match pass_test_run_pipeline(source, [pass]) {
      Ok(value) => value
      Err(err) => fail("expected retained mutable atomic read: \{err}")
    }
    @debug.assert_eq(optimized.code_sec, original.code_sec)
  }
}

///|
test "Binaryen 132 precompute struct and array order mutability and sharedness guards" {
  for is_array in [false, true] {
    for shared in [false, true] {
      for mutable in [false, true] {
        for
          order in [
            @lib.AtomicOrder::seq_cst(),
            @lib.AtomicOrder::acq_rel(),
            @lib.AtomicOrder::relaxed(),
          ] {
          let field = @lib.FieldType::new(
            @lib.StorageType::val_type(@lib.ValType::i32()),
            if mutable {
              @lib.Mut::var_()
            } else {
              @lib.Mut::const_()
            },
          )
          let aggregate = if is_array {
            @lib.CompType::array(field)
          } else {
            @lib.CompType::struct_([field])
          }
          let idx = @lib.TypeIdx::new(0U)
          let body = if is_array {
            [
              @lib.Instruction::i32_const(@lib.I32(42)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::array_new(idx),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::array_atomic_get(order, idx),
            ]
          } else {
            [
              @lib.Instruction::i32_const(@lib.I32(42)),
              @lib.Instruction::struct_new(idx),
              @lib.Instruction::struct_atomic_get(order, idx, @lib.U32(0U)),
            ]
          }
          let original = @lib.Module::new()
            .with_type_sec(
              @lib.TypeSec::new([
                @lib.RecType::new(
                  @lib.SubType::comp_type(
                    aggregate,
                    metadata=@lib.TypeMetadata::new(shared~),
                  ),
                ),
                @lib.RecType::new(
                  @lib.SubType::comp_type(
                    @lib.CompType::func([], [@lib.ValType::i32()]),
                  ),
                ),
              ]),
            )
            .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
            .with_code_sec(
              @lib.CodeSec::new([
                @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
              ]),
            )
          match @validate.validate_module(original) {
            Ok(_) => ()
            Err(err) => fail("invalid atomic read fixture: \{err}")
          }
          for pass in ["precompute", "precompute-propagate"] {
            let optimized = match
              run_hot_pipeline(original, HotPipelineOptions::new(), [pass]) {
              Ok(value) => value
              Err(err) => fail("expected atomic guard pipeline: \{err}")
            }
            let expected = if !shared &&
              !mutable &&
              order != @lib.AtomicOrder::seq_cst() {
              [@lib.Instruction::i32_const(@lib.I32(42))]
            } else {
              // Required nonconstant read: mutability, synchronization or sharedness.
              body
            }
            match optimized.code_sec {
              Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(actual))])) =>
                @debug.assert_eq(actual, expected)
              _ => fail("expected one atomic read function")
            }
            match @validate.validate_module(optimized) {
              Ok(_) => ()
              Err(err) => fail("invalid lowered atomic read: \{err}")
            }
          }
        }
      }
    }
  }
}
