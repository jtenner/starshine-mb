///|
test "DAE2 imported tag count excludes other imports and defined tags" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "env" "tag" (tag $first))
      #|  (import "env" "func" (func))
      #|  (import "env" "table" (table 1 funcref))
      #|  (import "env" "tag" (tag $second))
      #|  (import "env" "memory" (memory 1))
      #|  (import "env" "global" (global i32))
      #|  (tag $local)
      #|  (func (export "local")
      #|    block $out
      #|      try_table (catch $first $out) (catch $second $out) (catch $local $out)
      #|        throw $local
      #|      end
      #|    end)
      #|  (func (export "first")
      #|    block $out
      #|      try_table (catch $second $out) (catch $first $out)
      #|        throw $first
      #|      end
      #|    end)
      #|  (func (export "second")
      #|    block $out
      #|      try_table (catch $first $out) (catch $second $out)
      #|        throw $second
      #|      end
      #|    end))
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let expected = dae2_fold_known_local_throws_reference(input)
  let output = dae2_fold_known_local_throws(input)
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  let before = input.code_sec.unwrap().0
  let after = output.code_sec.unwrap().0
  assert_false(physical_equal(before[0], after[0]))
  let @lib.Func(_, @lib.Expr(local_body)) = after[0]
  assert_false(dae2_body_has_exception_or_continuation(local_body))
  // Both imports can denote the same host tag, so neither throw may fold.
  assert_true(physical_equal(before[1], after[1]))
  assert_true(physical_equal(before[2], after[2]))
  @validate.validate_module(output).unwrap()
  for name in ["dae2", "dae2-optimizing"] {
    let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [name]).unwrap()
    @validate.validate_module(dispatched).unwrap()
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 imported tag count handles absent and empty import sections" {
  let base = pass_test_module_from_wat(
    "(module (tag $t) (func block $out try_table (catch $t $out) throw $t end end))",
  )
  for input in [base, base.with_import_sec(@lib.ImportSec::new([]))] {
    let saved = @binary.encode_module(input).unwrap()
    let expected = dae2_fold_known_local_throws_reference(input)
    let output = dae2_fold_known_local_throws(input)
    assert_eq(output, expected)
    assert_false(physical_equal(output, input))
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 imported tag count leaves unrelated declarations and nonfoldable catches unchanged" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type (func (param i32) (result i32)))
      #|  (import "env" "tag" (tag $imported))
      #|  (tag $local)
      #|  (table 1 funcref)
      #|  (memory 1)
      #|  (global i32 (i32.const 7))
      #|  (elem (i32.const 0) $keep)
      #|  (data (i32.const 0) "payload")
      #|  (func $keep (param i32) (result i32) local.get 0)
      #|  (func block $out try_table (catch $imported $out) throw $local end end))
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_fold_known_local_throws(input)
  assert_true(physical_equal(output, input))
  assert_eq(output, dae2_fold_known_local_throws_reference(input))
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 tag count leaves intentionally invalid function types for validation" {
  let base = pass_test_module_from_wat("(module (tag) (func))")
  let input = base.with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(99U)]))
  // Counting tags must not resolve unrelated function types. The direct helper
  // is not a validator; the invalid module must still fail module validation.
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_fold_known_local_throws(input)
  assert_true(physical_equal(output, input))
  assert_true(@validate.validate_module(output) is Err(_))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
